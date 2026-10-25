# Roadmap history — Phase 187

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 187 — Fast flight I: high-priority builds, a heading-first queue and a flight step

**Goal:** with `/fly` and `/speed 10` (4.5 × 10 × 2 = 90 m/s, about 2.8 chunk crossings and 25 chunk
builds a second) the ground fell behind the player, and the chunk under the body was missing for
seconds at a time. Two scheduling faults were behind it, both cheap to fix.

**Newel dependency:** NO.

**Depends on:** Phase 141 (worker builds, the fold catch-up), Phase 169 (native builder), Phase 182 (`/speed`, `/fly`).

**Deliverables:**
- The local player's window (and the Phase 141 catch-up) is dispatched to the `WorkerThreadPool` at
  high priority (`ChunkManager.build_high_priority`). A low-priority task may use only
  `low_priority_thread_ratio` of the pool (0.3 by default): 11 builds sat in flight while three ran.
  `build_cap()` (all cores but one) still bounds them. A peer's window on a host stays low priority:
  with every build high, the crowd stress run failed its host tick budget at 16 bots in every pattern.
- Finished builds in the local player's 3×3 ring attach first (`_apply_order`), the rest in dispatch
  order (so a fold's catch-up cannot starve). A peer-only crossing keeps the old append-sorted queue:
  re-ranking a crowd's queue on each peer crossing took the stress pole pattern's host tick p95 from
  7 ms to 40–53 ms. The
  attach is the main-thread wall (an over-budget frame attaches one), so on a CI runner at about 8 fps
  the chunk under the body waited behind ring chunks dispatched before it (48% coverage on CI).
- The load queue is re-sorted as a whole when the local player crosses a chunk (`ChunkManager.queue_priority`): squared
  distance from the nearest window centre, less `HEADING_BIAS` (0.5) times the lead along the local
  player's heading (`heading_between`). The chunk under the body comes first, then the ring ahead.
  New chunks used to be appended behind what earlier crossings queued, so the chunk under a fast player
  waited behind ground it had already passed.
- Playtest bot `flight` step: carries the body east at `FLIGHT_SPEED_MPS` (walk speed × `/speed` cap ×
  flying factor = 90 m/s) for 12 s and samples the chunk under it and its 3×3 ring every 0.25 s after
  a 1.5 s warm-up. It records `flight` in `report.json` and returns the body to where it started.

**Acceptance criteria:**
- [x] Suite: the local window builds high and a peer window low; finished builds attach nearest first; the queue key orders under, ahead, beside, behind,
  and never lets the heading outrank a nearer ring; a crossing re-sorts the whole queue
  (`terrain_stream_tests`); the flight verdict (`runner_tests`).
- [x] Playtest bot (CI, native builder): `flight` keeps the ground under the body built in ≥ 90% of
  samples. The `--no-native` run reports it without gating (the GDScript builder is about 7× slower).
- [x] Suite green on both boot paths.

**Shipped:** measured locally on seed 42. Probe at 90 m/s for 30 s without a window:

| Machine | Before: under body / view ring | After: under body / view ring |
|---|---|---|
| 12 cores | worst 0% / mean 78% | worst 100% / mean 100% |
| 4 cores (`taskset`) | worst 0% / mean 62% | worst 100% / mean 97% |

Playtest bot under `xvfb` with llvmpipe on 4 cores (CI-like): the `flight` step had the ground under
the body built in 0% of samples before and 100% after, with a 3×3 ring mean of 61%.

After the CI fix (nearest-first attach, peer windows low), the same 4-core `xvfb` run: 95% and 100%
under the body in two runs (88% and 71% without the nearest-first attach).

The main thread is now the wall. Per attached chunk: collision 9.3 ms, dispatch and bookkeeping
5–6.5 ms, creature spawns 4.5–12 ms, render mesh 1.7 ms. Phases 189–191 take it from here.
