# ANSWERS — dc1-clos-evpn-a, round 3

DO NOT OPEN UNTIL THE DEBRIEF.

Fault set: BGP-11, BGP-07, BGP-08, BGP-06, EVPN-06. Five, not six. See ROUND3.md
for why.
Not a fault: spine2 BGP router-id 10.0.0.202 (script 00).

---

### Fault 1 — BGP — eBGP multihop TTL too low on one overlay session
**ID:** BGP-11
**Injected on:** dc1-leaf1, `neighbor 10.0.0.4 ebgp-multihop 1`.
**Symptom surface:** leaf1 and leaf4 both show the session down. **Almost no
user-visible traffic impact**, which is the entire point of this fault.
**Detection path:**
1. `show bgp evpn summary` on leaf1 → 2 Established, 1 not. leaf4 the same.
2. `show bgp neighbors 10.0.0.4 | grep -i -E 'ttl|multihop|state'`.
3. `show running-config section bgp | grep -E 'ebgp-multihop'` → one neighbor at
   1, the peer group at 3.
**Root cause:** leaf1 and leaf4 peer over loopbacks, two IP hops apart through a
spine. TTL 1 means the packet expires at the spine and the session never leaves
Connect/Active. The peer group sets 3; the per-neighbor statement overrides it.
**Why it barely matters:** the overlay is a four-node eBGP full mesh. With the
direct session down, leaf1 still learns leaf4's EVPN routes because leaf2 and
leaf3 re-advertise them, with their own ASN prepended. The BGP next-hop is
unchanged, so forwarding stays direct leaf1 to leaf4 and users notice nothing.
You can see this in the AS paths: `65102 65104` or `65103 65104` instead of
`65104`.
**The trap:** this is the most visible thing in the fabric and the least
consequential. An operator who finds it, fixes it, reruns `show bgp evpn
summary`, sees all green and closes the incident has found 1 of 5 and fixed
nothing that users care about. Grade accordingly.
**Fix:**
```
router bgp 65101
   no neighbor 10.0.0.4 ebgp-multihop
   neighbor 10.0.0.4 peer group OVERLAY
```
**Validation:** 3 Established on leaf1; AS path to leaf4's routes becomes `65104`.
**Dependency:** **masks Fault 3.** While this session is down, leaf1 never sees
leaf4's loopback advertisement directly, so the AS-path evidence that the
intended spine2 prepend has stopped working is hidden behind re-advertised
paths. Fix this first and Fault 3 becomes legible. That ordering is deliberate.

---

### Fault 2 — BGP — AS-path prepend applied inbound on leaf3
**ID:** BGP-07
**Injected on:** dc1-leaf3, `RM-SPINE1-IN` setting `as-path prepend 65103 65103
65103`, applied **inbound** on neighbor 10.1.0.4 (spine1).
**Symptom surface:** leaf3's FIB and leaf3's uplink utilisation. Everything is
Established, every route is present, nothing is down.
**Detection path:**
1. On leaf3: `show ip route 10.0.0.1` → one next hop, via spine2. Every other
   leaf has two.
2. On leaf3: `show ip bgp 10.0.0.1/32` → two paths. The spine1 path shows AS
   path `65103 65103 65103 65001 65101`. **leaf3's own ASN appears in a route it
   received.** That is impossible from normal eBGP operation and is the tell.
3. `show running-config section route-map` plus the `in` keyword on the neighbor
   statement.
**Root cause:** Prepending is an outbound tool. Applied inbound it lengthens the
AS path of everything arriving from spine1, so every spine1 path loses best-path
selection to the equivalent spine2 path. leaf3 collapses to a single uplink for
all traffic, losing half its capacity and all of its fast reconvergence. The
config reads as a legitimate traffic-engineering intent; only the direction is
wrong. In production this is usually a copy-paste from a peering template.
**Fix:**
```
router bgp 65103
   address-family ipv4
      no neighbor 10.1.0.4 route-map RM-SPINE1-IN in
!
no route-map RM-SPINE1-IN
```
**Validation:** `show ip route 10.0.0.1` on leaf3 → two next hops; no local ASN
in any received AS path.
**Dependency:** none.

---

### Fault 3 — BGP — route-map sequence shadowing voids the intentional drain
**ID:** BGP-08
**Injected on:** dc1-leaf4, `route-map RM-SPINE2-OUT permit 5` created with no
match statement, ahead of the existing `permit 10`.
**Symptom surface:** every other leaf's path selection for 10.0.0.4. Nothing
breaks. Something that was supposed to be true silently stopped being true.
**Detection path:**
1. README design intent states one leaf uplink is drained in the control plane
   for optics replacement. Verify it is actually drained. Most operators never
   check design intent against running state, which is why this fault exists.
2. On leaf1 (after fixing Fault 1): `show ip bgp 10.0.0.4/32` → both paths at AS
   path length 2. The spine2 path should be length 4 with the double prepend.
3. On leaf4: `show ip bgp neighbors 10.1.1.6 advertised-routes detail` → no
   prepend on the outgoing advertisement.
4. On leaf4: `show route-map RM-SPINE2-OUT` → sequence 5 permits with no match
   criteria and terminates evaluation; sequence 10 never runs.
**Root cause:** A route-map sequence with no `match` matches everything. Placed
at a lower sequence number than the intended logic, it permits every prefix and
stops evaluation, so the prepend at sequence 10 is dead code. The map still
exists, still looks correct when read top to bottom by someone skimming, and the
only way to see it is the match counters or the advertised-routes output. Result:
traffic is now being pushed across an uplink that maintenance believes is
drained, which is how optics work turns into an outage.
**Fix:**
```
no route-map RM-SPINE2-OUT permit 5
```
**Validation:** `show ip bgp 10.0.0.4/32` on leaf1 → spine2 path carries
`65104 65104 65104`; spine1 path preferred.
**Dependency:** masked by Fault 1 until that session is restored.

---

### Fault 4 — BGP — inbound policy bound to the wrong address family
**ID:** BGP-06
**Injected on:** dc1-leaf3, `RM-EVPN-IN` removed from the OVERLAY peer group
under address-family evpn and applied to the SPINE peer group under
address-family ipv4.
**Symptom surface:** leaf3's egress selection for the external prefix. The
route-map still exists, is still referenced, and still appears in the config.
**Detection path:**
1. On leaf3: `show ip route vrf TENANT-A 192.168.200.0/24` → two next hops.
   On leaf4: one next hop, 10.0.0.2. Two leaves, same template, different result.
2. On leaf3: `show bgp evpn route-type ip-prefix ipv4 192.168.200.0/24 detail` →
   both border paths at local-preference 100. leaf2's path carries community
   65000:200 and was never promoted.
3. On leaf3: `show ip community-list CL-EXT-PRIMARY` → correct, 65000:200. So
   the value is right; the binding is wrong.
4. `show running-config section bgp` → the route-map is under address-family
   ipv4 on the SPINE group, not under address-family evpn on OVERLAY.
**Root cause:** Policy binding is per address family and per peer group. Applied
to the underlay IPv4 family, the community match runs against spine-learned
loopback routes that carry no such community, so it never fires and the local
preference is never raised. The EVPN family now has no inbound policy at all.
This is deliberately close to round 1's TE-01 in symptom and completely
different in cause: there the value was mistyped, here the value is perfect and
the attachment point is wrong. If your detection path stops at the
community-list, you will declare it fixed and change nothing.
**Fix:**
```
router bgp 65103
   address-family ipv4
      no neighbor SPINE route-map RM-EVPN-IN in
   !
   address-family evpn
      neighbor OVERLAY route-map RM-EVPN-IN in
```
**Validation:** single next hop 10.0.0.2 at local-preference 200 on leaf3.
**Dependency:** none.

---

### Fault 5 — EVPN/VXLAN — anycast gateway MAC inconsistent on leaf2
**ID:** EVPN-06
**Injected on:** dc1-leaf2, `ip virtual-router mac-address 00:1c:73:ba:be:02`.
**Symptom surface:** state comparison across leaves. **This is a
config-consistency fault, not a traffic fault, in this topology.**
**Honesty note, read this before grading yourself:** with static endpoints and
no host mobility, this will not reliably produce a user-visible outage in the
cEOS virtual dataplane. Each host ARPs its own local gateway and gets a working
answer. The damage is latent and shows up on VM move, on ARP cache expiry with
a relearn against a different leaf, and in any duplicate-gateway-MAC detection
your monitoring runs. Do not go looking for a ping failure; there may not be
one. Find it by comparing state across devices, which is the skill being trained.
**Detection path:**
1. `show ip virtual-router` on each leaf in turn → leaf2 differs.
2. On leaf1 or leaf3: `show bgp evpn route-type mac-ip vni 10010` → a second
   virtual MAC appears in the fabric, originated by leaf2's RD.
3. `show mac address-table vlan 10` on leaf3 → two gateway-looking MACs.
**Root cause:** Distributed anycast gateway requires every participating leaf to
present the identical virtual MAC for a given subnet, so a host keeps the same
next-hop MAC in its ARP cache regardless of which leaf it is attached to. One
leaf with a different value breaks that guarantee. A host that moves from leaf1
to leaf2 keeps the old MAC in cache and blackholes until the entry ages out,
which on a Linux guest is minutes, and on some appliances is much longer.
**Fix:**
```
ip virtual-router mac-address 00:1c:73:ba:be:01
```
**Validation:** `show ip virtual-router` identical on all four leaves; only one
virtual MAC present in `show bgp evpn route-type mac-ip`.
**Dependency:** none.

---

### Not a fault — spine2 BGP router-id 10.0.0.202

`router bgp 65002 / router-id 10.0.0.202` while Loopback0 remains 10.0.0.102.

Correct and harmless. A BGP router-id is a 32-bit identifier that must be unique
within the AS; it is not required to be a configured or reachable address on the
device. Sessions form, routes propagate, and nothing in path selection changes
here because spine1's 10.0.0.101 is still the lower value in any tiebreak
against spine2 either way.

It looks alarming because the router-id in `show bgp evpn summary` no longer
matches anything in the address plan, and because round 3 contains a genuine
path-selection fault, so an operator primed to suspect path selection will grab
it. Changing it back is scored as an error. The way to dismiss it in five
seconds is to note that the sessions are Established, which proves the router-id
is functioning as an identifier, and that no route in the fabric uses it as a
next hop.
