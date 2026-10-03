#!/usr/bin/env bash
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
for f in 00-baseline-rid 01-leaf1-peer-ttl 02-leaf3-spine1-in \
         03-leaf4-spine2-out 04-leaf3-policy-bind 05-leaf2-vmac; do
  echo "== ${f}"
  bash "${D}/${f}.sh"
done
echo
echo "Round 3 armed: 5 faults. Allow 60s for reconvergence."
