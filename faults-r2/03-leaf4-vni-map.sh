#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
eos dc1-leaf4 <<'CFG'
configure
interface Vxlan1
   no vxlan vlan 20 vni 10020
   vxlan vlan 20 vni 10021
end
write memory
CFG
echo "[inject] 03 applied"
