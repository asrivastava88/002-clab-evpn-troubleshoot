#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
eos dc1-leaf3 <<'CFG'
configure
router bgp 65103
   address-family evpn
      no neighbor OVERLAY route-map RM-EVPN-IN in
   !
   address-family ipv4
      neighbor SPINE route-map RM-EVPN-IN in
exit
end
clear bgp * soft in
write memory
CFG
echo "[inject] 04 applied"
