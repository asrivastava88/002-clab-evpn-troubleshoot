#!/usr/bin/env bash
# Returns every node to the clean designed baseline.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

eos dc1-leaf2 <<'CFG'
configure
router bgp 65102
   maximum-paths 4 ecmp 4
exit
end
write memory
CFG

eos dc1-spine1 <<'CFG'
configure
no route-map RM-UNDERLAY-OUT deny 15
no ip prefix-list PL-LEGACY-SUMMARY
end
clear ip bgp * soft out
write memory
CFG

eos dc1-spine2 <<'CFG'
configure
interface Ethernet1
   mtu 9214
end
write memory
CFG

eos dc1-leaf1 <<'CFG'
configure
router bgp 65101
   vlan 10
      no route-target import 9000:10010
      no route-target export 9000:10011
      route-target both 9000:10010
exit
end
write memory
CFG

eos dc1-leaf3 <<'CFG'
configure
interface Vxlan1
   vxlan source-interface Loopback0
!
no interface Loopback1
!
no ip community-list CL-EXT-PRIMARY
ip community-list CL-EXT-PRIMARY permit 65000:200
end
write memory
CFG

echo "Baseline restored on all nodes."
