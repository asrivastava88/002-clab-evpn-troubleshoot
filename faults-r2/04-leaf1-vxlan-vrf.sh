#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
eos dc1-leaf1 <<'CFG'
configure
interface Vxlan1
   no vxlan vrf TENANT-A vni 50001
end
write memory
CFG
echo "[inject] 04 applied"
