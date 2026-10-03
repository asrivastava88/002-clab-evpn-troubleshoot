#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
eos dc1-leaf1 <<'CFG'
configure
router bgp 65101
   neighbor 10.0.0.4 ebgp-multihop 1
exit
end
clear bgp 10.0.0.4
write memory
CFG
echo "[inject] 01 applied"
