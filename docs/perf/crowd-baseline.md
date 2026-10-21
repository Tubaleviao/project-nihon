# Crowd baseline (Phase 163)

The Phase 162 stress report this phase started from, committed so later runs have a fixed comparison.
One desktop machine, `STRESS_MAX=64 STRESS_PROFILES=lan STRESS_SECONDS=15`, seed 1. A reference, not a
gate: the machine-readable floor is [`crowd-baseline.json`](crowd-baseline.json), checked by
`tools/check_crowd_baseline.py` in the CI `stress` job.

Budgets (`StressRules.BUDGETS`, the one table): host tick p95 ≤ 16 ms, ≤ 64 kbit/s down per peer,
watcher frame p95 ≤ 33 ms, relay lag ≤ 250 ms.

## lan/cluster

| Bots | Tick p50/p95/p99/max ms | Down kbit/s/peer p95 | Watcher frame p95 ms | Relay lag p95 ms | Budgets |
|---|---|---|---|---|---|
| 16 | 0.90 / 14.77 / 19.95 / 24.1 | 48.7 | 18.27 | 48 | pass |
| 32 | 1.87 / 13.82 / 23.34 / 29.8 | 75.3 | 18.69 | 56 | miss |
| 64 | 5.14 / 18.42 / 40.09 / 60.5 | 136.7 | 17.46 | 63 | miss |

## Ranked hot spots (budget share at 200 bots)

| Rank | Hot spot | Share | Detail |
|---|---|---|---|
| 1 | `remote_player_state` messages | 518% | +1.65 kbit/s per peer per bot |
| 2 | AOI relays and equipment pairs | 57% | +0.049 ms/tick per bot |
| 3 | `snapshot_chunk` messages | 22% | +0.019 kbit/s per peer per bot |
| 4 | join and AOI re-scope snapshots | 4% | +0.003 ms/tick per bot |
| 5 | networking poll | 3% | +0.002 ms/tick per bot |

Creature AI (1%), peer window moves (1%) and region streaming (0%) are far below the relay cost, so
this phase works the top two (position relays and the AOI relay fan-out) and leaves the
window, creature and watcher candidates for a later report that ranks them.

## Series sizes

Largest passing size per series is in `crowd-baseline.json` (cluster 16, cross 16, spread 16, pole 32,
churn 0, from the Phase 162 notes).

## After the first fixes (same machine, same command)

| Fix | Effect at `lan/cluster`, 64 bots |
|---|---|
| Equipment pairs: a move evaluates only pairs that show gear or hold a record to evict | `aoi_relay` phase 2258 → ~1000 ms over the run |
| `aoi_recipients` filters against a set, not a linear `in` | linear in the crowd |
| Relays: one binary `remote_player_states` packet per recipient per tick (24 bytes per entry) | down per peer 136.7 → 85.3 kbit/s (62% of baseline; target 60%) |
| Host tick p95 | 18.4 → 16.4 ms (target 9.2): the p95 is the `chunks` phase spiking on window streaming (about 14 ms even at 16 bots), not the relays |

Largest passing size, `lan/cluster`: 16 → 32.
