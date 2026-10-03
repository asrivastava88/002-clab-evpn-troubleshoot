#!/usr/bin/env bash
# Not a fault. Adds an inbound transit-prefix guard on leaf1 that is correct as designed.
source "$(dirname "$0")/lib.sh"
eos dc1-leaf1 <<'CFG'
configure
ip prefix-list PL-TRANSIT seq 10 permit 10.1.0.0/16 le 31
!
route-map RM-UNDERLAY-IN deny 10
   match ip address prefix-list PL-TRANSIT
!
route-map RM-UNDERLAY-IN permit 20
!
router bgp 65101
   address-family ipv4
      neighbor SPINE route-map RM-UNDERLAY-IN in
exit
end
write memory
CFG
echo "[inject] 00 applied"
