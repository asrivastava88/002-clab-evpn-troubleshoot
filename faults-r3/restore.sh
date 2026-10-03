#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

eos dc1-spine2 <<'CFG'
configure
router bgp 65002
   router-id 10.0.0.102
exit
end
clear bgp *
write memory
CFG

eos dc1-leaf1 <<'CFG'
configure
router bgp 65101
   no neighbor 10.0.0.4 ebgp-multihop
   neighbor 10.0.0.4 peer group OVERLAY
exit
end
clear bgp 10.0.0.4
write memory
CFG

eos dc1-leaf3 <<'CFG'
configure
router bgp 65103
   address-family ipv4
      no neighbor 10.1.0.4 route-map RM-SPINE1-IN in
      no neighbor SPINE route-map RM-EVPN-IN in
   !
   address-family evpn
      neighbor OVERLAY route-map RM-EVPN-IN in
exit
!
no route-map RM-SPINE1-IN
end
clear bgp * soft
write memory
CFG

eos dc1-leaf4 <<'CFG'
configure
no route-map RM-SPINE2-OUT permit 5
end
clear ip bgp 10.1.1.6 soft out
write memory
CFG

eos dc1-leaf2 <<'CFG'
configure
ip virtual-router mac-address 00:1c:73:ba:be:01
end
write memory
CFG

echo "Round 3 faults removed. Baseline restored."
