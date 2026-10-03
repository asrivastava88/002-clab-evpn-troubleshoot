#!/usr/bin/env bash
# Non-destructive sweep. Prints raw state; draws no conclusions.
LAB="dc1-clos-evpn-a"; PFX="clab-${LAB}"
c() { docker exec "${PFX}-$1" Cli -p 15 -c "$2"; }
hr() { printf '\n===== %s =====\n' "$1"; }

for n in dc1-spine1 dc1-spine2; do
  hr "${n} underlay"
  c "$n" "show ip bgp summary"
  hr "${n} advertised loopbacks"
  c "$n" "show ip route 10.0.0.0/24"
  hr "${n} fabric MTU"
  c "$n" "show interfaces Ethernet1-4 | include Ethernet|MTU"
done

for n in dc1-leaf1 dc1-leaf2 dc1-leaf3 dc1-leaf4; do
  hr "${n} underlay"
  c "$n" "show ip bgp summary"
  hr "${n} overlay"
  c "$n" "show bgp evpn summary"
  hr "${n} vtep"
  c "$n" "show vxlan vtep"
  hr "${n} loopback routes"
  c "$n" "show ip route 10.0.0.0/24"
  hr "${n} external prefix"
  c "$n" "show ip route vrf TENANT-A 192.168.200.0/24"
done

hr "host reachability 1500B"
for t in "h1 172.16.10.12" "h1 172.16.10.13" "h3 172.16.20.14" "h5 172.16.20.14" "h1 172.16.20.13"; do
  set -- $t; echo "--- $1 -> $2"; docker exec "${PFX}-$1" ping -c2 -W2 "$2"
done

hr "host reachability 8000B df"
for t in "h1 172.16.10.12" "h1 172.16.10.13" "h3 172.16.20.14" "h5 172.16.20.14"; do
  set -- $t; echo "--- $1 -> $2"; docker exec "${PFX}-$1" ping -c4 -W2 -M do -s 8000 "$2"
done
