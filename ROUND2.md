# Fault set #2 — same fabric, new fault set

Topology, addressing, ASNs, VLAN/VNI/RT plan and design intent are unchanged.
Read the original `README.md` for all of that. `verify/expected-state.md` is
still the reference for what healthy looks like.

## Arm it

```
bash faults/restore.sh        # clear round 1, if you have not already
bash faults-r2/inject.sh
```

Wait 90 seconds before you start. One fault in this set only becomes visible as
a pattern over time, and you will misread it if you look once.

Disarm:

```
bash faults-r2/restore.sh
```

## Rules of engagement

Unchanged, with one addition.

- Do not open `ANSWERS-R2.md`.
- Do not `diff` `configs/` against running config. That is the cheat path.
- Do not read `faults-r2/`.
- Fix on the device, via the CLI.
- **Submit a finding before you fix it.** Symptom observed, hypothesis, command
  run, output, root cause, proposed fix. A fix with no detection path is scored
  as not found.
- Log time-to-detect per fault.

## Reported symptoms (NOC handoff, 03:40)

> Second call tonight. The overnight fixes helped some things and the board lit
> up again about forty minutes later.
>
> - VLAN 20 is a mess. Users on leaf1 and leaf3 can't reach the app on leaf4 at
>   all. VLAN 10 seems OK between those same leaves.
> - Separately, anyone on leaf1 who needs to cross subnets is dead in the water.
>   Same-subnet traffic from leaf1 is fine. This started at the same time as the
>   VLAN 20 complaints and may or may not be related.
> - leaf3 to leaf4 pings are dropping about half the packets. leaf4 to leaf3
>   pings are clean. Nobody can explain how that's possible.
> - One file server on leaf1 keeps dropping sessions from leaf3 users. It comes
>   back on its own after a minute or two, then goes again. Like clockwork.
> - Storage team says a host in VLAN 10 is "moving around" according to their
>   monitoring, but nothing has been physically touched.
> - Monitoring shows leaf2's uplinks are unbalanced again. Different pattern
>   from last night.

## Notes on evidence

Two faults in this set produce no visible symptom in any routing or EVPN
command. `show bgp evpn summary` and `show ip route` will be clean while traffic
is being discarded. If your process ends at show commands you will find four of
six and close the incident with the fabric still broken.

For those two, reach for interface counters, ACL counters, logs, and packet
capture inside the containers:

```
docker exec clab-dc1-clos-evpn-a-dc1-leaf3 bash -c "tcpdump -ni eth1 udp port 4789 -c 20"
docker exec clab-dc1-clos-evpn-a-dc1-spine1 Cli -p 15 -c "show ip access-lists"
docker exec clab-dc1-clos-evpn-a-dc1-leaf3 Cli -p 15 -c "show logging last 10 minutes"
```

One config in this fabric looks wrong and is correct. Removing it is scored as
an error, and the reason it is correct is the lesson.
