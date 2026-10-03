# ANSWERS — dc1-clos-evpn-a, round 2

DO NOT OPEN UNTIL THE DEBRIEF.

Fault set: BGP-09, SEC-04, EVPN-03, EVPN-05, EVPN-11, BGP-12.
Not a fault: leaf1 `RM-UNDERLAY-IN` transit-prefix guard (script 00).

---

### Fault 1 — BGP — NO_EXPORT on leaf2's loopback toward spine1
**ID:** BGP-09
**Injected on:** dc1-leaf2, `RM-LOOPBACK-OUT` applied outbound to neighbor
10.1.0.2, setting community `no-export` on 10.0.0.2/32.
**Symptom surface:** leaf1, leaf3, leaf4. Nothing looks wrong on leaf2 and
nothing looks wrong on spine1 either, which is the difficulty.
**Detection path:**
1. On leaf3: `show ip route 10.0.0.2` → one next hop via spine2. Other leaf
   loopbacks have two.
2. On spine1: `show ip route 10.0.0.2` → present. `show ip bgp 10.0.0.2/32
   detail` → community NO_EXPORT attached.
3. On spine1: `show ip bgp neighbors 10.1.0.5 advertised-routes` → absent.
4. There is no policy on spine1 doing this. Reading spine1's config for a deny
   is wasted time; the attribute arrived from leaf2.
5. On leaf2: `show ip bgp neighbors 10.1.0.2 advertised-routes detail` or
   `show running-config section route-map RM-LOOPBACK-OUT`.
**Root cause:** NO_EXPORT (RFC 1997) instructs a receiving speaker not to
re-advertise the route outside its own AS. spine1 honours it and drops the
route from every eBGP update, silently and correctly. The fault lives one AS
away from where it is visible, and the RIB on both leaf2 and spine1 looks
perfect. This is the mirror image of round 1's EVPN-12: same observable
symptom, opposite mechanism, and a config audit of spine1 finds nothing.
**Fix:**
```
router bgp 65102
   address-family ipv4
      no neighbor 10.1.0.2 route-map RM-LOOPBACK-OUT out
!
no route-map RM-LOOPBACK-OUT
no ip prefix-list PL-SELF-LOOPBACK
```
then `clear ip bgp 10.1.0.2 soft out`.
**Validation:** `show ip bgp neighbors 10.1.0.5 advertised-routes` on spine1
lists 10.0.0.2/32; leaf3 shows two next hops.
**Dependency:** **masks Fault 2 for all leaf3-to-leaf2 traffic.** While this is
broken, leaf3 can only reach leaf2 over spine2, which is not where the ACL is.
Fix this and a brand new intermittent symptom appears between leaf3 and leaf2.
Grade that reaction: an operator who assumes they broke something with their own
fix, instead of recognising an unmasked fault, has drawn the wrong conclusion.

---

### Fault 2 — Security — VXLAN dropped inbound on spine1's leaf3 port
**ID:** SEC-04
**Injected on:** dc1-spine1, `ACL-FABRIC-IN` applied `in` on Ethernet3,
denying UDP/4789 and permitting everything else.
**Symptom surface:** leaf3's hosts, in one direction only. Every routing and
EVPN command on every device is clean.
**Detection path:**
1. From h3: `ping 172.16.20.14` → roughly 50% loss. From h4 back to h3 → 0%
   loss. Unidirectional loss is the signature.
2. On leaf3: `show ip route 10.0.0.4` → two next hops, both valid. Underlay is
   fine, so stop looking at routing.
3. On leaf3: `show bgp evpn summary`, `show vxlan vtep`, `show vxlan
   address-table` → all correct. Control plane is fine, so stop looking there.
4. `tcpdump -ni eth1 udp port 4789` on the leaf3 container while pinging: frames
   leave leaf3. Same capture on spine1's Ethernet3: frames arrive.
5. On spine1: `show ip access-lists ACL-FABRIC-IN` → hit counters incrementing
   on the deny. `show running-config interfaces Ethernet3`.
**Root cause:** The ACL is applied ingress on the spine port facing leaf3, so it
drops encapsulated tenant traffic leaving leaf3 while leaving BGP (TCP/179),
ICMP to loopbacks, and everything else untouched. leaf3 ECMPs across both
spines, so only the half of the five-tuples hashing to spine1 die. Return
traffic enters spine1 on a different interface and is unaffected, which is why
the loss is one-way. Nothing in any routing or EVPN table can show this; the
only paths to it are counters and capture.
**Fix:**
```
interface Ethernet3
   no ip access-group ACL-FABRIC-IN in
!
no ip access-list ACL-FABRIC-IN
```
**Validation:** `ping -c 100` h3 to h4 → 0% loss; ACL removed from
`show ip access-lists`.
**Dependency:** partially masked by Fault 1 (see above).

---

### Fault 3 — EVPN/VXLAN — VLAN 20 mapped to the wrong VNI on leaf4
**ID:** EVPN-03
**Injected on:** dc1-leaf4, `interface Vxlan1`, VLAN 20 bound to VNI 10021
instead of 10020.
**Symptom surface:** every other leaf. Routes are received and accepted; they
simply do not program.
**Detection path:**
1. h5 (leaf1, VLAN 20) cannot reach h4 (leaf4, VLAN 20). h3 to h4 also fails
   for VLAN 20 while VLAN 10 between other leaves is unaffected.
2. On leaf1: `show bgp evpn route-type mac-ip vni 10020` → h4's MAC absent.
3. On leaf1: `show bgp evpn route-type mac-ip` unfiltered → h4's MAC **is**
   there, under VNI 10021. RT matched, so the route imported; the VNI did not.
4. On leaf1: `show vxlan address-table vlan 20` → no entry for h4.
5. On leaf4: `show vxlan vni` / `show interfaces Vxlan1` → VLAN 20 to VNI 10021.
**Root cause:** The route-target controls import; the VNI controls forwarding.
They are independent. leaf4 exports with the correct RT 9000:10020, so remote
leaves accept the route into the right MAC-VRF, but the VNI carried in the NLRI
has no local VLAN binding on the receiver, so nothing is programmed into the
VXLAN address table. The route is present in BGP and absent from the dataplane.
**Fix:**
```
interface Vxlan1
   no vxlan vlan 20 vni 10021
   vxlan vlan 20 vni 10020
```
**Validation:** `show vxlan address-table vlan 20` on leaf1 shows h4's MAC
against VTEP 10.0.0.4; h5 reaches h4.
**Dependency:** none.

---

### Fault 4 — EVPN/VXLAN — L3VNI removed from leaf1's VXLAN interface
**ID:** EVPN-05
**Injected on:** dc1-leaf1, `interface Vxlan1`, `no vxlan vrf TENANT-A vni 50001`.
**Symptom surface:** leaf1's hosts for inter-subnet traffic only. Intra-VLAN
bridging to and from leaf1 keeps working perfectly, which sends most operators
down the wrong path.
**Detection path:**
1. h1 (VLAN 10, leaf1) reaches h2 and h6 (VLAN 10, remote) fine.
2. h1 cannot reach h3 or h4 (VLAN 20, remote). h5 (VLAN 20, leaf1) cannot reach
   them either. Bridging works, routing does not: that split is the diagnosis.
3. h1 to 172.16.20.1 (its own local anycast gateway) works, so the SVI and VRF
   are fine locally.
4. On leaf1: `show ip route vrf TENANT-A` → remote host routes and prefixes are
   missing or unresolved.
5. On leaf1: `show vxlan vni` → no entry for VNI 50001. Compare with leaf3.
6. On leaf3: `show bgp evpn route-type ip-prefix ipv4 detail` → leaf1's Type-5
   routes carry no usable L3VNI label.
**Root cause:** Symmetric IRB routes between subnets by encapsulating into the
L3VNI. With the VRF-to-VNI binding removed from Vxlan1, leaf1 has no transit VNI
for routed traffic, so every inter-subnet flow crossing the fabric is dropped
while L2VNIs 10010 and 10020 continue bridging normally. The VRF, the SVIs, the
RTs and the BGP session all remain correct, so a config audit of the routing
stanza finds nothing.
**Fix:**
```
interface Vxlan1
   vxlan vrf TENANT-A vni 50001
```
**Validation:** `show vxlan vni` on leaf1 lists 50001; h1 reaches h3.
**Dependency:** none, but its symptom overlaps Fault 3. Discriminator: Fault 3
breaks one VLAN in both directions across the fabric; Fault 4 breaks one leaf
for all inter-VLAN traffic while leaving intra-VLAN intact.

---

### Fault 5 — EVPN/VXLAN — duplicate MAC advertised by leaf2
**ID:** EVPN-11
**Injected on:** dc1-leaf2, static MAC entry for h1's MAC in VLAN 10 pointing at
Ethernet3, while h1 actually lives on leaf1.
**Symptom surface:** leaf3 and leaf4, whose VLAN 10 forwarding for h1 flips
between two VTEPs. leaf1 and leaf2 both believe they are right.
**Detection path:**
1. h6 (leaf3, VLAN 10) reaches h1 intermittently, and the failure pattern does
   not follow packet size, so it is not MTU.
2. On leaf3: `show vxlan address-table vlan 10` run repeatedly → h1's MAC
   alternates between VTEP 10.0.0.1 and 10.0.0.2.
3. On leaf3: `show bgp evpn route-type mac-ip <h1-mac> detail` → two paths, RD
   10.0.0.1:10010 and RD 10.0.0.2:10010, with an incrementing MAC mobility
   sequence number.
4. `show logging | grep -i -E 'mac|mobility|duplicate'` on any leaf.
5. On leaf2: `show mac address-table vlan 10` → the entry is type static, not
   dynamic. A host that is not connected to leaf2 cannot be learned there.
**Root cause:** Two VTEPs advertising the same MAC in the same MAC-VRF triggers
EVPN MAC mobility. Each leaf increments the sequence number to claim the MAC,
the remote leaves reprogram their VXLAN address table on every update, and
traffic to h1 oscillates between the two VTEPs. The static entry never ages out,
so the fight never resolves. In production this is what a duplicated MAC on a
misconnected NIC or a loop through a downstream switch looks like.
**Honesty note:** cEOS duplicate-MAC detection and log verbosity are build
dependent. If the logs are quiet, the authoritative evidence is the pair of
Type-2 routes with two different RDs for one MAC, plus the static entry on
leaf2. Do not depend on a duplicate-MAC syslog message being present.
**Fix:**
```
no mac address-table static <h1-mac> vlan 10 interface Ethernet3
```
**Validation:** `show bgp evpn route-type mac-ip <h1-mac>` on leaf3 shows one
path only, RD 10.0.0.1:10010, and the VXLAN address table stops flipping.
**Dependency:** none.

---

### Fault 6 — BGP — per-neighbor prefix limit idling one overlay session
**ID:** BGP-12
**Injected on:** dc1-leaf3, `neighbor 10.0.0.1 maximum-routes 4`.
**Symptom surface:** leaf1 and leaf3 users, on a repeating cadence.
**Detection path:**
1. `show bgp evpn summary` on leaf3 caught at the right moment shows the session
   to 10.0.0.1 Idle; caught later it shows Established. The state changes on a
   timer, which is the tell.
2. `show logging | grep -i bgp` on leaf3 → repeated ADJCHANGE and a prefix limit
   message at a fixed interval.
3. `show bgp neighbors 10.0.0.1 | grep -i -E 'maximum|limit|idle'`.
4. `show running-config section bgp | grep maximum-routes` → 4 on one neighbor,
   12000 on the rest.
**Root cause:** The overlay carries well over four EVPN routes from leaf1, so
the limit trips on every session establishment. EOS idles the peer and restarts
it, producing a fixed-period flap. Anything sourced through that session is lost
for the duration of each outage, which users experience as a service that breaks
and heals on a clock.
**Fix:**
```
router bgp 65103
   no neighbor 10.0.0.1 maximum-routes
   neighbor 10.0.0.1 maximum-routes 12000
```
**Validation:** `show bgp evpn summary` stable Established for several minutes;
no further ADJCHANGE entries in the log.
**Dependency:** none. This is the entry point of the set. If it takes long to
find, the lesson is that logs should be read before show commands.

---

### Not a fault — leaf1 `RM-UNDERLAY-IN` transit guard

`route-map RM-UNDERLAY-IN deny 10` matching `PL-TRANSIT` (10.1.0.0/16 le 31),
applied inbound on leaf1's SPINE peer group, with `permit 20` behind it.

Correct as designed. The spines never advertise fabric /31s in the first place,
since nothing redistributes connected into the underlay BGP process, so the deny
never matches anything. It exists as a guard: if a leaf or spine is ever
misconfigured to leak transit links into the underlay, leaf1 will not install
them. The `permit 20` behind it means normal loopback advertisements are
unaffected.

The trap is that it is an inbound `deny` on a device with a real reachability
problem (Fault 4), sitting one screen away in the running config. Removing it
produces no change in behaviour, which is the evidence that it was never the
cause. Deleting it is marked wrong. A deny that matches nothing cannot break
anything, and the way to prove that in ten seconds is
`show route-map RM-UNDERLAY-IN` for the match counter, not deletion.
