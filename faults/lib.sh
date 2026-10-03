#!/usr/bin/env bash
# shared helpers for fault injection / restore  (all-Arista fabric)
set -euo pipefail

LAB="dc1-clos-evpn-a"
PFX="clab-${LAB}"

eos() {
  # eos <node-short-name> <<'CFG' ... CFG
  local node="$1"; shift
  docker exec -i "${PFX}-${node}" Cli -p 15
}
