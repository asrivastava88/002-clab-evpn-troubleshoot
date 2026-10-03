#!/usr/bin/env bash
# shared helpers, round 2 fault set
set -euo pipefail
LAB="dc1-clos-evpn-a"
PFX="clab-${LAB}"
eos() { local node="$1"; shift; docker exec -i "${PFX}-${node}" Cli -p 15; }
# h1's MAC in EOS dotted notation, read from the container itself
h1_mac() {
  docker exec "${PFX}-h1" cat /sys/class/net/eth1/address \
    | tr -d ':' | sed -E 's/(.{4})(.{4})(.{4})/\1.\2.\3/'
}
