#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
eos dc1-spine1 <<'CFG'
configure
ip access-list ACL-FABRIC-IN
   10 deny udp any any eq 4789
   20 permit ip any any
!
interface Ethernet3
   ip access-group ACL-FABRIC-IN in
end
write memory
CFG
echo "[inject] 02 applied"
