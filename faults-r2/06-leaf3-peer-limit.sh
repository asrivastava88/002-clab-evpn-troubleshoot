#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
eos dc1-leaf3 <<'CFG'
configure
router bgp 65103
   neighbor 10.0.0.1 maximum-routes 4
exit
end
write memory
CFG
echo "[inject] 06 applied"
