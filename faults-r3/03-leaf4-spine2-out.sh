#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
eos dc1-leaf4 <<'CFG'
configure
route-map RM-SPINE2-OUT permit 5
end
clear ip bgp 10.1.1.6 soft out
write memory
CFG
echo "[inject] 03 applied"
