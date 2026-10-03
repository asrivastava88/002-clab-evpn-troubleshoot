#!/usr/bin/env bash
# Applies the full fault set in order. Idempotent: safe to re-run.
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
for f in 01-underlay-paths 02-spine1-policy 03-spine2-link \
         04-leaf1-macvrf 05-leaf3-overlay 06-leaf3-policy; do
  echo "== ${f}"
  bash "${D}/${f}.sh"
done
echo
echo "6 faults injected. Allow 60-90s for BGP/EVPN reconvergence before you start."
