# Expected state — healthy dc1-clos-evpn-a

Use this as the reference for "what good looks like". It describes the designed
fabric, not the faulted one.

## Session counts

| Node | Underlay eBGP (IPv4) | Overlay eBGP (EVPN) |
|---|---|---|
| dc1-spine1 | 4 Established | 0 |
| dc1-spine2 | 4 Established | 0 |
| dc1-leaf1..4 | 2 Established | 3 Established |

Total: 8 underlay sessions, 6 overlay sessions (full mesh across 4 leaves).

## Underlay

- Every leaf holds 3 remote leaf loopbacks plus 2 spine loopbacks.
- Every remote leaf loopback is reachable over **2 ECMP next hops** (one per spine),
  except `10.0.0.4/32`, which is biased to spine1 by design (AS-path length 3 via
  spine2 vs 2 via spine1) and therefore installs **1** next hop.
- `show ip route 10.0.0.3` on leaf1 → 2 next hops (10.1.0.0, 10.1.1.0).
- `show ip route 10.0.0.4` on leaf1 → 1 next hop via spine1 (10.1.0.0).
- Spines: `show ip route 10.0.0.0/24` → 4 leaf /32s present in the RIB on both,
  and `show ip bgp neighbors <leaf-ip> advertised-routes` lists all four.

## MTU

- All fabric links on every node: `mtu 9214`. Nothing on the fabric runs at the
  1500 default.
- `ping 10.0.0.3 source 10.0.0.1 size 8000 df-bit repeat 20` from any leaf succeeds
  on every ECMP member.
- Host-to-host: `ping -M do -s 8000` between any two hosts in the same VLAN succeeds.

## Overlay

- `show bgp evpn summary` on every leaf: 3 peers Established.
- `show vxlan vtep` on every leaf: 3 remote VTEPs, all from 10.0.0.0/24
  (10.0.0.1 / .2 / .3 / .4 minus self). No VTEP outside that range.
- `show bgp evpn route-type mac-ip` next hops are always the remote leaf Loopback0.
- VLAN 10 MACs (h1, h2, h6) are learned on all three leaves that carry VLAN 10.
- VLAN 20 MACs (h3, h4, h5) are learned on all four leaves.

## Reachability matrix (all must pass, 1500B and 8000B)

| From | To | Type |
|---|---|---|
| h1 (l1,v10) | h2 (l2,v10) | intra-VLAN, VNI 10010 |
| h1 (l1,v10) | h6 (l3,v10) | intra-VLAN, VNI 10010 |
| h3 (l3,v20) | h4 (l4,v20) | intra-VLAN, VNI 10020 |
| h5 (l1,v20) | h4 (l4,v20) | intra-VLAN, VNI 10020 |
| h1 (v10) | h3 (v20) | inter-VLAN, L3VNI 50001 |
| h2 (v10) | h4 (v20) | inter-VLAN, L3VNI 50001 |

## External prefix steering

- `192.168.200.0/24` is originated by leaf1 (backup, community 65000:50) and
  leaf2 (primary, community 65000:200).
- On leaf3 and leaf4: `show ip route vrf TENANT-A 192.168.200.0/24` →
  **exactly one** next hop, VTEP 10.0.0.2 (leaf2), local-preference 200.
- Any leaf showing two next hops for that prefix, or a single next hop of
  10.0.0.1, is wrong.
