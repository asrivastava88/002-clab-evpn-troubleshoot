#!/usr/bin/env bash
set -euo pipefail
LAB="dc1-clos-evpn-a"
PFX="clab-${LAB}"
eos() { local node="$1"; shift; docker exec -i "${PFX}-${node}" Cli -p 15; }
