#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
eos dc1-leaf2 <<'CFG'
configure
ip prefix-list PL-SELF-LOOPBACK seq 10 permit 10.0.0.2/32
!
route-map RM-LOOPBACK-OUT permit 10
   match ip address prefix-list PL-SELF-LOOPBACK
   set community no-export
!
route-map RM-LOOPBACK-OUT permit 20
!
router bgp 65102
   address-family ipv4
      neighbor 10.1.0.2 route-map RM-LOOPBACK-OUT out
exit
end
clear ip bgp 10.1.0.2 soft out
write memory
CFG
echo "[inject] 01 applied"
