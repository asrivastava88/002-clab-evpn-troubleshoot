#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
MAC="$(h1_mac)"
echo "[inject] 05 using MAC ${MAC}"
eos dc1-leaf2 <<CFG
configure
mac address-table static ${MAC} vlan 10 interface Ethernet3
end
write memory
CFG
echo "[inject] 05 applied"
