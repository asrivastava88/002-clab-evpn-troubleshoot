# Fault set #3 — same fabric, BGP-weighted set

Topology, addressing and design intent unchanged. See `README.md`.
Baseline reference stays `verify/expected-state.md`.

## Arm it

```
bash faults-r2/restore.sh     # clear round 2 first
bash faults-r3/inject.sh
```

Disarm:

```
bash faults-r3/restore.sh
```

## Five faults, not six, and why

This topology is close to exhausted for genuinely new architect-grade faults.
Twelve IDs are burned. Of what remains in the library, a large share cannot be
expressed here at all:

- EVPN-07, EVPN-08, EVPN-09 need ESI-LAG multihoming. There is no multihomed
  host in this design.
- BGP-01, BGP-02, BGP-03 need a route reflector. The overlay is an eBGP full
  mesh with no RR.
- All nine OSPF faults need OSPF. The underlay is eBGP.
- All five DCI faults need a second site.
- The RoCE domain needs a QoS and PFC baseline this fabric does not have, and a
  rail-optimised design it is not.

Padding to six would have meant re-serving a burned mechanism under a new label,
which the uniqueness rules forbid. Five real faults beats six with one recycled.

This is the last rearm worth running on this topology. The next step is `NEWLAB`
with a different shape. Given your stated direction, the highest-value next build
is a rail-optimised AI fabric with rail leaves and a spine tier, carrying a real
DSCP/PFC/ECN baseline, which unlocks the entire RoCE domain as
config-consistency and classification-path faults.

## What this set is weighted toward

BGP mechanics, four of five. Direction, binding point, sequence order, and TTL:
the four ways a policy that reads correctly does the wrong thing. None of these
are typos. Every value in every config is defensible when read in isolation.

## Rules of engagement

- Do not open `ANSWERS-R3.md`.
- Do not `diff` `configs/` against running config.
- Do not read `faults-r3/`.
- Fix on the device, via the CLI.
- Submit a finding before you fix it. A fix with no detection path scores as not
  found.
- Log time-to-detect per fault.

## Reported symptoms (NOC handoff, 09:15, business hours)

> Not an outage. Capacity planning and the maintenance team both raised tickets
> this morning and they may be related.
>
> - Monitoring flagged a BGP peer down between leaf1 and leaf4 overnight. No
>   users complained. Nobody can tell us whether it matters.
> - leaf3 is running everything over one uplink. Its other uplink is up, no
>   errors, carrying almost nothing. Capacity planning wants to know if they
>   need to order more optics.
> - Maintenance is scheduled to pull leaf4's spine2 optics this afternoon. They
>   asked us to confirm the uplink is drained before they start. Please confirm.
> - Egress to 192.168.200.0/24 is split across both firewalls again for some
>   users. We fixed this two nights ago. It is back.
> - Server team is asking why one of our gateways answers with a different MAC
>   than the others. They noticed while building a VM migration runbook.

Note the last two. One is a repeat symptom with a different cause; the fix you
applied two rounds ago is still in place and still correct. The other has no
traffic impact today and will cause an outage the first time a VM moves.

And the third item is a direct question from a team about to pull a cable. It
has a yes or no answer and the answer is in the fabric right now.
