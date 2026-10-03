#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
eos dc1-leaf1 <<'CFG'
configure
router bgp 65101
   vlan 10
      no route-target both 9000:10010
      route-target import 9000:10010
      route-target export 9000:10011
exit
end
write memory
CFG
echo "[inject] 04 applied"
