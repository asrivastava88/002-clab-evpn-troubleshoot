#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
MAC="$(h1_mac)"

eos dc1-leaf1 <<'CFG'
configure
interface Vxlan1
   vxlan vrf TENANT-A vni 50001
!
router bgp 65101
   address-family ipv4
      no neighbor SPINE route-map RM-UNDERLAY-IN in
exit
!
no route-map RM-UNDERLAY-IN
no ip prefix-list PL-TRANSIT
end
write memory
CFG

eos dc1-leaf2 <<CFG
configure
router bgp 65102
   address-family ipv4
      no neighbor 10.1.0.2 route-map RM-LOOPBACK-OUT out
exit
!
no route-map RM-LOOPBACK-OUT
no ip prefix-list PL-SELF-LOOPBACK
no mac address-table static ${MAC} vlan 10 interface Ethernet3
end
clear ip bgp 10.1.0.2 soft out
write memory
CFG

eos dc1-spine1 <<'CFG'
configure
interface Ethernet3
   no ip access-group ACL-FABRIC-IN in
!
no ip access-list ACL-FABRIC-IN
end
write memory
CFG

eos dc1-leaf3 <<'CFG'
configure
router bgp 65103
   no neighbor 10.0.0.1 maximum-routes
   neighbor 10.0.0.1 maximum-routes 12000
exit
end
clear bgp 10.0.0.1
write memory
CFG

eos dc1-leaf4 <<'CFG'
configure
interface Vxlan1
   no vxlan vlan 20 vni 10021
   vxlan vlan 20 vni 10020
end
write memory
CFG

echo "Round 2 faults removed. Baseline restored."
