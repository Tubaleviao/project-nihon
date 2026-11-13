# Crowd baseline (Phase 163)

The Phase 162 crowd stress report that Phase 163 starts from, committed so every later run has a fixed
comparison. It was produced by the CI job's own command on one desktop machine
(`STRESS_MAX=64 STRESS_PROFILES=lan STRESS_SECONDS=20 tools/stress.sh`, seed 1, the Phase 162 branch on 2026-10-18), so the
absolute numbers are a reference, not a gate. The gate is the **largest passing size** per series:
`StressRules.BASELINE_LARGEST` holds the column below, and the `stress` job fails when a series drops under it.

The Phase 163 run that follows each fix is in the PR body; this page stays the starting point.

A run that misses a budget at or below its series' baseline size, with no hard failure, is run once more
and the rerun counts (`StressRules.needs_retry`; each missed try stays in the artifact as `<size>.miss1`, `<size>.miss2`).
On a shared CI runner the host tick p95 at 16 bots has ranged from 3 to 18 ms on the same code, so one
slow 20 s window should not fail main; a real regression misses the rerun as well.

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

## Phase 253 — the stress regression: a whole chunk's collision in one frame

The merge of Phase 243 (#618) recorded 0 for `lan/cluster`, `lan/cross` and `lan/spread`. It was not
runner noise: on this branch the same sizes missed on all three runs of the best-of-three rerun, and
every miss was `host_tick_p95_ms` alone (bandwidth, relay lag and the watcher's frame all passed).

- **The cost.** Host tick p50 ~1 ms but p95 ~18 ms, p99 ~21 ms, max ~27 ms, the same at 16 and 64
  bots: a periodic spike, not load. Of 327 slow host frames in the 16-bot runs, 315 had
  `chunk_attach_collision` as their largest phase, ~83% of the frame (17.3 ms of a 20.5 ms one).
- **The mechanism.** Jolt builds a `ConcavePolygonShape3D`'s mesh on the main thread when its body
  enters the world. A client staggers a smooth chunk's four quadrant shapes (Phase 183) over pump
  steps; the dedicated server never did (`NearRing.staggers_collision` was false without a render),
  so each streamed chunk cost ~17–20 ms in one frame.
- **Why #618.** It was there before: on Phase 242 (`f8a53c4`) the 16-bot runs already had ~45 slow
  frames of 1,200 (3.6%, so p95 stayed ~4 ms), each up to ~26 ms of collision. On #618 the host
  attached ~45% more collision in the window (0.77 s → 1.12 s in `lan/cross/16`) and ~69 frames
  went slow (5.75%), past the 5% that sets p95. Nothing in #618 runs on the server; the threshold
  was crossed by the margin, not by a new cost.
- **The fix.** The headless host now staggers every chunk: the build attaches one quadrant and the
  near ring's `_attach_server_collision` attaches the rest one a pump step, oldest chunk first, at
  least one a frame. Locally, 16 bots on `lan`: `cross` p95 15.7 → 8.0 ms, max 23.0 → 15.8 ms,
  frames over 16 ms 51 → 0; `spread` p95 14.7 → 8.2 ms, 25 → 0. Total collision time is unchanged.

The best-of-three rerun stays (a size at or below the baseline that misses a budget runs up to twice
more and keeps the first run that meets every budget): a real regression still misses all three.
