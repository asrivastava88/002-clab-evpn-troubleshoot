# ANSWERS — dc1-clos-evpn-a

DO NOT OPEN UNTIL THE DEBRIEF.

Fault set: BGP-04, EVPN-12, EVPN-14, EVPN-01, EVPN-13, TE-01.
Red herring (not a fault): leaf4 `RM-SPINE2-OUT` AS-path prepend.

---

### Fault 1 — BGP — underlay multipath removed on leaf2
**ID:** BGP-04
**Injected on:** dc1-leaf2, `router bgp 65102`, `maximum-paths` deleted.
**Symptom surface:** leaf2's own FIB, and, indirectly, the *absence* of symptoms
for leaf2 users while leaf1 and leaf3 users complain.
**Detection path:**
1. `show ip route 10.0.0.1` on leaf2 → single next hop 10.1.0.2 (spine1).
   Compare with leaf3, which shows two.
2. `show ip bgp 10.0.0.1/32` on leaf2 → two paths received, one marked best,
   no `ECMP head`/`ECMP` flags.
3. `show running-config section bgp | include maximum-paths` → nothing.
**Root cause:** Without `maximum-paths 4 ecmp 4`, leaf2 installs a single best
path per underlay prefix. Both spine paths are otherwise equal, so the tiebreak
falls through to the lowest neighbour router-id and every prefix pins to spine1.
Half the uplink capacity is idle and reconvergence on a spine1 failure is a full
BGP event rather than a FIB ECMP member withdrawal. This also hides Fault 3 from
leaf2 entirely, which is why the leaf2 operator insisted nothing was wrong.
**Fix:**
```
router bgp 65102
   maximum-paths 4 ecmp 4
```
(`bgp bestpath as-path multipath-relax` is already present and is required here
because the two spines are in different ASNs.)
**Validation:** `show ip route 10.0.0.1` → 2 next hops, 10.1.0.2 and 10.1.1.2.
**Dependency:** masks Fault 3 for all leaf2-sourced traffic. Fixing this one
makes leaf2 users start reporting the intermittent symptom.

---

### Fault 2 — EVPN/VXLAN — leaf4 loopback suppressed by spine1 outbound policy
**ID:** EVPN-12
**Injected on:** dc1-spine1, `route-map RM-UNDERLAY-OUT deny 15` matching
`PL-LEGACY-SUMMARY` (10.0.0.4/32), inserted ahead of the `permit 20` sequence.
**Symptom surface:** leaf1, leaf2, leaf3 — all of which lose the spine1 path to
leaf4's VTEP. Nothing is wrong on leaf4 itself.
**Detection path:**
1. On leaf1: `show ip route 10.0.0.4` → one next hop, via spine2 only. Every
   other leaf loopback has two.
2. On leaf1: `show ip bgp neighbors 10.1.0.0 received-routes` → 10.0.0.4/32 is
   absent from what spine1 sends. leaf3's loopback is present.
3. On spine1: `show ip route 10.0.0.4` → present in the RIB, next hop Ethernet4.
   So the route exists; only the advertisement is missing.
4. On spine1: `show ip bgp neighbors 10.1.0.1 advertised-routes` → 10.0.0.4/32
   not listed.
5. `show running-config section route-map` on spine1 → sequence 15 denies it
   before sequence 20 can permit it.
**Root cause:** EOS evaluates route-map sequences in ascending numeric order and
stops at the first match. The injected deny at sequence 15 matches 10.0.0.4/32
and terminates evaluation, so the permit at sequence 20 never runs. The route is
in spine1's RIB, which means every "is the route there" check on spine1 passes;
only `advertised-routes` exposes it. The consequence is that all traffic to
leaf4's VTEP is forced onto spine2, which is where Fault 3 lives, turning an
intermittent MTU problem into a permanent blackhole for leaf3 to leaf4.
**Fix:**
```
configure
no route-map RM-UNDERLAY-OUT deny 15
no ip prefix-list PL-LEGACY-SUMMARY
end
clear ip bgp * soft out
```
**Validation:** `show ip bgp neighbors 10.1.0.5 advertised-routes` on spine1
lists 10.0.0.4/32; `show ip route 10.0.0.4` on leaf3 shows two next hops.
**Dependency:** masks nothing, but *aggravates* Fault 3. Fixing this alone
converts the leaf3 to leaf4 failure from permanent to intermittent, which is a
correct partial fix and should be graded as such.

---

### Fault 3 — EVPN/VXLAN — fabric MTU reverted to default on one spine2 link
**ID:** EVPN-14
**Injected on:** dc1-spine2, `interface Ethernet1`, `no mtu` (falls back to the
1500 default). Ethernet1 faces leaf1.
**Symptom surface:** leaf1 to everyone, flow-dependent. leaf3 to leaf4
permanently, via the Fault 2 interaction.
**Detection path:**
1. From h1: `ping -M do -s 8000 172.16.10.12` fails intermittently while
   `ping -c 100 172.16.10.12` at default size passes 100%.
2. On leaf1: `ping 10.0.0.2 source 10.0.0.1 size 8000 df-bit repeat 20` — run it
   several times. ECMP rehashing makes it pass over spine1 and fail over spine2.
3. On leaf1: `show interfaces Ethernet2 | include MTU` → 9214. Local side is fine,
   so the fault is not here.
4. On spine2: `show interfaces Ethernet1-4 | include Ethernet|MTU` → Ethernet1
   at 1500, the other three at 9214. That one line is the whole fault.
**Root cause:** VXLAN adds 50 bytes of outer encapsulation. A 9000-byte tenant
frame becomes ~9050 on the wire and is discarded by the 1500-byte MTU on
spine2's leaf1-facing interface. Because leaf1 ECMPs across both spines, roughly
half the five-tuples take the broken path, producing the classic "ping works,
file copy hangs" report. `no mtu` restores the platform default, so the interface
looks like one that was simply never configured rather than one that was changed
— which is exactly how this arrives in production after a config cleanup.
**Honesty note on evidence:** do not expect reliable giant/oversize counters from
`show interfaces Ethernet1 counters errors` in the cEOS virtual dataplane. The
authoritative evidence here is the MTU delta across the four spine2 interfaces
plus the df-bit ping result, not a drop counter.
**Fix:**
```
interface Ethernet1
   mtu 9214
```
**Validation:** `ping 10.0.0.2 source 10.0.0.1 size 8000 df-bit repeat 50` on
leaf1 → 0% loss across repeated runs; `ping -M do -s 8000` succeeds host to host.
**Dependency:** masked on leaf2 by Fault 1; made permanent for leaf3 to leaf4 by
Fault 2.

---

### Fault 4 — EVPN/VXLAN — MAC-VRF export route-target asymmetry on leaf1
**ID:** EVPN-01
**Injected on:** dc1-leaf1, `router bgp 65101 / vlan 10`, export RT changed from
9000:10010 to 9000:10011 (import left correct).
**Symptom surface:** leaf2 and leaf3 — neither imports leaf1's VLAN 10 MAC
routes. leaf1 itself has a complete table.
**Detection path:**
1. On leaf2: `show bgp evpn route-type mac-ip vni 10010` → h1's MAC is missing;
   h6's (leaf3) is present.
2. On leaf1: same command → h2 and h6 both present. Asymmetry is the tell.
3. On leaf2: `show bgp evpn route-type mac-ip 0022.aabb.0001 detail` returns
   nothing, so the route is not being filtered post-import — it never arrived
   with a matching RT.
4. `show bgp evpn rt-membership` / `show running-config section bgp | section vlan 10`
   on leaf1 → export 9000:10011, import 9000:10010.
**Root cause:** EVPN import is driven by the export RT of the originator matching
the import RT of the receiver. leaf1 exports a VLAN 10 RT that nobody imports, so
its Type-2 routes are dropped at the inbound RT-constrain filter on every remote
leaf. leaf1's own import is untouched, so it still learns remote MACs, producing
one-way MAC learning: ARP from h1 resolves (leaf1 has h2's MAC) but the return
flow relies on flood-and-learn that EVPN has suppressed.
**Fix:**
```
router bgp 65101
   vlan 10
      no route-target import 9000:10010
      no route-target export 9000:10011
      route-target both 9000:10010
```
**Validation:** `show bgp evpn route-type mac-ip vni 10010` on leaf2 lists h1's
MAC with next hop 10.0.0.1; `show vxlan address-table vlan 10` on leaf2 shows it
against VTEP 10.0.0.1.
**Dependency:** none.

---

### Fault 5 — EVPN/VXLAN — leaf3 VXLAN source-interface repointed to an unadvertised loopback
**ID:** EVPN-13
**Injected on:** dc1-leaf3, new `interface Loopback1 10.0.1.3/32`, and
`interface Vxlan1 / vxlan source-interface Loopback1`.
**Symptom surface:** leaf1, leaf2, leaf4 — remote VTEP tables and dataplane. All
BGP sessions stay Established and all EVPN routes are present everywhere, which
is what makes this one expensive.
**Detection path:**
1. `show bgp evpn summary` on every leaf → clean. Do not stop here.
2. On leaf1: `show vxlan vtep` → an entry outside 10.0.0.0/24, or a VTEP for
   leaf3 that does not resolve. `show vxlan vtep detail` shows the tunnel not
   established.
3. On leaf1: `show ip route 10.0.1.3` → no route. The underlay never carried it.
4. On leaf3: `show interfaces Vxlan1` → source interface Loopback1, address
   10.0.1.3, which is not in `network` statements under `address-family ipv4`.
5. `tcpdump -ni eth1 udp port 4789` on leaf3's fabric link confirms encapsulated
   frames leaving with an outer source of 10.0.1.3.
**Root cause:** The VTEP address must be the same loopback used for overlay
peering and must be advertised into the underlay. Loopback1 is neither. Remote
leaves either cannot resolve the tunnel destination or receive VXLAN from an
unrecognised VTEP and discard it. Either way the control plane looks perfect.
**Fix:**
```
interface Vxlan1
   vxlan source-interface Loopback0
!
no interface Loopback1
```
**Validation:** `show vxlan vtep` on leaf1 lists exactly 10.0.0.2, 10.0.0.3,
10.0.0.4; h1 reaches h6.
**Dependency:** none, but it overlaps in symptom space with Fault 2 (both look
like "leaf X is unreachable in the overlay"). The discriminator is that Fault 2
is visible in `show ip route`, Fault 5 is not.

---

### Fault 6 — TE — exit-steering community mismatch on leaf3
**ID:** TE-01
**Injected on:** dc1-leaf3, `ip community-list CL-EXT-PRIMARY` changed from
65000:200 to 65000:20.
**Symptom surface:** leaf3's VRF FIB, and the standby firewall behind leaf1
seeing sessions it should never see.
**Detection path:**
1. On leaf3: `show ip route vrf TENANT-A 192.168.200.0/24` → two next hops
   (10.0.0.1 and 10.0.0.2).
2. On leaf4: same command → one next hop, 10.0.0.2. Two leaves, same design,
   different result.
3. On leaf3: `show bgp evpn route-type ip-prefix 192.168.200.0/24 detail` →
   both paths at local-preference 100; leaf2's path carries community 65000:200
   and the local-pref was never raised.
4. `show ip community-list` on leaf3 vs leaf4 → 65000:20 vs 65000:200.
**Root cause:** The inbound EVPN route-map `RM-EVPN-IN` raises local-preference
to 200 only on a community match. With the community list mistyped, the match
never fires, both border paths sit at the default local-preference, and
`bgp bestpath as-path multipath-relax` (needed for underlay ECMP across two
spine ASNs) lets leaf3 install both exits as equal-cost. Traffic load-shares
across the primary and standby borders, and stateful inspection on the standby
drops the half of the flows it never saw the SYN for.
**Fix:**
```
no ip community-list CL-EXT-PRIMARY
ip community-list CL-EXT-PRIMARY permit 65000:200
clear ip bgp 10.0.0.2 soft in
```
**Validation:** `show ip route vrf TENANT-A 192.168.200.0/24` on leaf3 → single
next hop 10.0.0.2 at local-preference 200.
**Dependency:** none.

---

### Red herring — leaf4 AS-path prepend toward spine2

`route-map RM-SPINE2-OUT` prepends 65104 twice on leaf4's own loopback
advertisement to spine2 only. This is correct as designed and is the
"drained uplink" referred to in the README design intent. It makes 10.0.0.4/32
arrive at remote leaves with AS-path length 3 via spine2 and 2 via spine1, so
leaf4's VTEP traffic deliberately prefers spine1 while the spine2 optics are
replaced. Removing it is marked wrong.

The trap: Fault 2 removes the spine1 path for exactly that prefix, so during the
lab the prepend appears to be the reason leaf4 only has one path. It is not. The
prepend suppresses a path that is already being suppressed upstream. An operator
who deletes the route-map will see no change in behaviour, which is itself the
evidence they attacked the wrong object. The correct reasoning is: a prepend
cannot remove a path, only de-preference it, so a *missing* path is never
explained by a prepend.
