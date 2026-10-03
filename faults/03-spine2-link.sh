#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
eos dc1-spine2 <<'CFG'
configure
interface Ethernet1
   no mtu
end
write memory
CFG
echo "[inject] 03 applied"
