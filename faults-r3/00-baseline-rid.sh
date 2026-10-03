#!/usr/bin/env bash
# Not a fault. spine2 BGP router-id no longer matches its Loopback0. Correct as designed.
source "$(dirname "$0")/lib.sh"
eos dc1-spine2 <<'CFG'
configure
router bgp 65002
   router-id 10.0.0.202
exit
end
clear bgp *
write memory
CFG
echo "[inject] 00 applied"
