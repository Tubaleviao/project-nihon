# The server's ceiling (Phase 250)

How many players one dedicated server holds. **Status: loopback numbers only.** The two-machine
run (server on one machine, bots on another, over a LAN and then `wan_br`) needs two machines, which
automation does not have; it is [issue #685](https://github.com/Tubaleviao/project-nihon/issues/685).
Until it is closed, this page records the split mode on one machine (both roles on the same CPU over
loopback, `STRESS_LOOPBACK_SPLIT=1`), which still shares the CPU between server and bots, so the
numbers are a floor for the server's real ceiling, not the ceiling.

## Repeat it

Two machines (the server's UDP 7777 and TCP 7778 reachable from the bots' machine):

```bash
# on the server machine
GODOT=/path/to/godot STRESS_ROLE=server tools/stress.sh
# on the bots' machine
GODOT=/path/to/godot STRESS_ROLE=bots STRESS_SERVER=<server address> \
  STRESS_MAX=200 STRESS_PROFILES="lan wan_br" tools/stress.sh
```

The bots' driver climbs the ladder (16, 32, 64, 128, 200) per pattern, asks the server for each run
over the control channel (`tools/stress_ctl.py`), and builds `stress/report.md` with the Machines
table of both roles. The server driver serves runs until the bots' driver says bye. One machine:
`STRESS_LOOPBACK_SPLIT=1 tools/stress.sh`.

## Loopback run (2026-11-19)

`STRESS_LOOPBACK_SPLIT=1 STRESS_MAX=64 STRESS_PROFILES=lan STRESS_SECONDS=15`, seed 1, shared CPU.

| Role | CPU | Cores | RAM (MB) | OS | Godot | Native | Build |
|---|---|---|---|---|---|---|---|
| bots and server (one machine) | AMD Ryzen 5 5600G | 12 | 31467 | Linux 6.12 (Debian 13) | 4.7 stable | on | release |

| Pattern | Largest crowd that met every budget (ladder capped at 64) |
|---|---|
| cluster | 64 |
| spread | 64 |
| cross | 64 |
| churn | 64 |
| pole | 32 |

First bottlenecks at the top of the ladder, as a share of the budget they take at 200 bots (from
the report's hot-spot table): `player_states` messages 45%, `snapshot_chunk` messages 41%,
AOI relays 38%, peer window moves 16%, join snapshots 13%. Every pattern is still under budget at
64 bots except `pole`, so the first failure is not yet found; the ladder has to run to 200 on two
machines to find it. Per-player CPU, memory and bandwidth are in each run's row of `report.json`.

## How many players one server holds

Not yet known with headroom for play: the loopback run did not reach a failing size for four of five
patterns. Until issue #685 is closed, the safe number is the one measured: **32 players crossing a
pole, 64 in every other pattern**.
