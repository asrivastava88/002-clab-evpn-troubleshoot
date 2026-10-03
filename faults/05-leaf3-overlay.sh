#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
eos dc1-leaf3 <<'CFG'
configure
interface Loopback1
   description vtep-anycast-reserved
   ip address 10.0.1.3/32
!
interface Vxlan1
   vxlan source-interface Loopback1
exit
end
write memory
CFG
echo "[inject] 05 applied"
