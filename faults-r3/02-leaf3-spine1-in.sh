#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
eos dc1-leaf3 <<'CFG'
configure
route-map RM-SPINE1-IN permit 10
   set as-path prepend 65103 65103 65103
!
router bgp 65103
   address-family ipv4
      neighbor 10.1.0.4 route-map RM-SPINE1-IN in
exit
end
clear ip bgp 10.1.0.4 soft in
write memory
CFG
echo "[inject] 02 applied"
