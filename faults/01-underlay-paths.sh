#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
eos dc1-leaf2 <<'CFG'
configure
router bgp 65102
   no maximum-paths
exit
end
write memory
CFG
echo "[inject] 01 applied"
