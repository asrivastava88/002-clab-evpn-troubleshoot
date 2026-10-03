#!/usr/bin/env bash
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
for f in 00-baseline-hygiene 01-leaf2-loopback-out 02-spine1-fabric-acl \
         03-leaf4-vni-map 04-leaf1-vxlan-vrf 05-leaf2-mac-entry 06-leaf3-peer-limit; do
  echo "== ${f}"
  bash "${D}/${f}.sh"
done
echo
echo "Round 2 armed. Allow 90s for reconvergence and for the flap cadence to become visible."
