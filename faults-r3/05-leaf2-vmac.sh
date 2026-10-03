#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
eos dc1-leaf2 <<'CFG'
configure
ip virtual-router mac-address 00:1c:73:ba:be:02
end
write memory
CFG
echo "[inject] 05 applied"
