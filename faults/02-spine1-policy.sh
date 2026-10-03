#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
eos dc1-spine1 <<'CFG'
configure
ip prefix-list PL-LEGACY-SUMMARY seq 10 permit 10.0.0.4/32
!
route-map RM-UNDERLAY-OUT deny 15
   match ip address prefix-list PL-LEGACY-SUMMARY
end
clear ip bgp * soft out
write memory
CFG
echo "[inject] 02 applied"
