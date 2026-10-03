#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
eos dc1-leaf3 <<'CFG'
configure
no ip community-list CL-EXT-PRIMARY
ip community-list CL-EXT-PRIMARY permit 65000:20
end
write memory
CFG
echo "[inject] 06 applied"
