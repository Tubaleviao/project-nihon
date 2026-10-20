# Crowd baseline (Phase 163)

The Phase 162 crowd stress report that Phase 163 starts from, committed so every later run has a fixed
comparison. It was produced by the CI job's own command on one desktop machine
(`STRESS_MAX=64 STRESS_PROFILES=lan STRESS_SECONDS=20 tools/stress.sh`, seed 1, the Phase 162 branch on 2026-10-18), so the
absolute numbers are a reference, not a gate. The gate is the **largest passing size** per series:
`StressRules.BASELINE_LARGEST` holds the column below, and the `stress` job fails when a series drops under it.

The Phase 163 run that follows each fix is in the PR body; this page stays the starting point.

---

## Report

Run: seconds=20, seed=1, max=64, profiles=lan

Budgets: host tick p95 ≤ 16.0 ms, ≤ 64.0 kbit/s down per peer, watcher frame p95 ≤ 33.0 ms, relay lag ≤ 250.0 ms.

### Largest passing size

| Series | Largest passing size | Ladder stopped at |
|---|---|---|
| lan/churn | 0 | — |
| lan/cluster | 16 | — |
| lan/cross | 16 | — |
| lan/pole | 32 | — |
| lan/spread | 16 | — |

### Hot spots

| Rank | Hot spot | Budget share at 200 bots | Detail |
|---|---|---|---|
| 1 | remote_player_state messages | 611% | +2.0130 kbit/s per peer per bot, 391.27 kbit/s per peer projected |
| 2 | snapshot_chunk messages | 229% | +0.6235 kbit/s per peer per bot, 146.46 kbit/s per peer projected |
| 3 | peer window moves on joins and AOI crossings | 149% | +0.1233 ms/tick per bot, 23.82 ms/tick projected |
| 4 | AOI relays and equipment pairs | 90% | +0.0779 ms/tick per bot, 14.36 ms/tick projected |
| 5 | join and AOI re-scope snapshots | 17% | +0.0139 ms/tick per bot, 2.66 ms/tick projected |
| 6 | chunk records and region streaming | 16% | +0.0044 ms/tick per bot, 2.64 ms/tick projected |
| 7 | own_state_synced messages | 5% | +0.0092 kbit/s per peer per bot, 3.13 kbit/s per peer projected |
| 8 | networking poll (inbound packets) | 5% | +0.0037 ms/tick per bot, 0.74 ms/tick projected |
| 9 | creature AI | 2% | +0.0013 ms/tick per bot, 0.29 ms/tick projected |
| 10 | identity_assigned messages | 0% | +0.0004 kbit/s per peer per bot, 0.20 kbit/s per peer projected |
| 11 | peer streaming windows (periodic re-centre) | 0% | +0.0001 ms/tick per bot, 0.03 ms/tick projected |
| 12 | world_clock messages | 0% | +0.0000 kbit/s per peer per bot, 0.10 kbit/s per peer projected |
| 13 | status_effects messages | 0% | +0.0001 kbit/s per peer per bot, 0.07 kbit/s per peer projected |
| 14 | creature syncs | 0% | +0.0000 ms/tick per bot, 0.01 ms/tick projected |
| 15 | save | 0% | -0.0000 ms/tick per bot, 0.01 ms/tick projected |

### lan/churn

| Bots | Tick p50/p95/p99/max ms | Down kbit/s/peer p95 | Watcher frame p95 ms | Relay lag p95 ms | Avatars seen | Peers per AOI cell | Budgets |
|---|---|---|---|---|---|---|---|
| 16 | 0.73 / 13.42 / 19.82 / 26.3 | 102.6 | 21.89 | 57 (447) | 46 | 15 | miss |
| 32 | 1.54 / 14.51 / 22.24 / 32.5 | 209.5 | 22.18 | 56 (900) | 96 | 26 | miss |
| 64 | 3.91 / 19.23 / 27.18 / 75.1 | 293.6 | 22.84 | 60 (1780) | 192 | 53 | miss |

### lan/cluster

| Bots | Tick p50/p95/p99/max ms | Down kbit/s/peer p95 | Watcher frame p95 ms | Relay lag p95 ms | Avatars seen | Peers per AOI cell | Budgets |
|---|---|---|---|---|---|---|---|
| 16 | 0.84 / 13.32 / 20.20 / 25.8 | 48.1 | 17.36 | 55 (638) | 17 | 15 | pass |
| 32 | 1.92 / 14.16 / 23.37 / 34.6 | 74.9 | 17.34 | 50 (1280) | 33 | 31 | miss |
| 64 | 5.54 / 17.63 / 35.07 / 58.6 | 130.2 | 17.52 | 58 (2561) | 65 | 59 | miss |

### lan/cross

| Bots | Tick p50/p95/p99/max ms | Down kbit/s/peer p95 | Watcher frame p95 ms | Relay lag p95 ms | Avatars seen | Peers per AOI cell | Budgets |
|---|---|---|---|---|---|---|---|
| 16 | 0.89 / 14.92 / 19.97 / 30.5 | 31.0 | 17.37 | 52 (622) | 17 | 10 | pass |
| 32 | 1.96 / 16.51 / 21.69 / 26.5 | 54.9 | 17.37 | 56 (1232) | 33 | 13 | miss |
| 64 | 5.10 / 22.10 / 29.28 / 41.1 | 103.7 | 17.76 | 56 (2432) | 65 | 25 | miss |

### lan/pole

| Bots | Tick p50/p95/p99/max ms | Down kbit/s/peer p95 | Watcher frame p95 ms | Relay lag p95 ms | Avatars seen | Peers per AOI cell | Budgets |
|---|---|---|---|---|---|---|---|
| 16 | 1.16 / 13.18 / 24.66 / 38.4 | 28.5 | 17.19 | 0 (0) | 0 | 15 | pass |
| 32 | 2.86 / 15.96 / 26.43 / 37.3 | 55.5 | 17.10 | 0 (0) | 0 | 31 | pass |
| 64 | 7.74 / 25.33 / 308.28 / 1121.9 | 128.3 | 17.06 | 0 (0) | 0 | 62 | miss |

### lan/spread

| Bots | Tick p50/p95/p99/max ms | Down kbit/s/peer p95 | Watcher frame p95 ms | Relay lag p95 ms | Avatars seen | Peers per AOI cell | Budgets |
|---|---|---|---|---|---|---|---|
| 16 | 0.89 / 15.68 / 20.08 / 28.2 | 35.1 | 17.40 | 55 (594) | 17 | 12 | pass |
| 32 | 1.88 / 16.83 / 23.24 / 28.4 | 55.2 | 17.69 | 57 (1182) | 33 | 21 | miss |
| 64 | 5.04 / 22.82 / 32.74 / 48.8 | 96.7 | 17.69 | 61 (2329) | 65 | 41 | miss |

### Hard failures

None.
