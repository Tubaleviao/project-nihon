# Roadmap history — Phase 163

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 163 — Crowd performance: fix what the Phase 162 report names

**Goal:** make the crowd sizes from Phase 162 cheaper. This phase is written before the measurements,
so its deliverables are the hot spots the Phase 162 report ranks, worked top-down; the candidates below
are what the code suggests today and are dropped or reordered when the report disagrees. The PR body
records the report before and after each fix, so every change is justified by a number.

**Newel dependency:** NO.

**Depends on:** Phase 162.

**Deliverables:**
- A `docs/perf/crowd-baseline.md` page: the Phase 162 report that this phase starts from (sizes, tick
  phases, bytes per message type), committed so later runs have a fixed comparison.
- Fixes for the top hot spots, each with a suite test that pins the cost it removed. Likely candidates:
  - position relays: send only what changed, at a rate that drops with distance inside the AOI, and
    batch every relay for one peer into one packet per tick instead of one per subject;
  - AOI work: update a peer's AOI set when it changes cell, not every tick; keep per-cell subscriber
    lists so a relay does not scan every peer;
  - peer windows and region reads: share the window work for peers that stand in the same chunks,
    so a cluster of players costs closer to one window than to n;
  - creature AI and syncs: tick creatures near players, sleep the rest, and share path searches for
    creatures chasing the same target;
  - the watcher: pool remote avatars, cut their animation and nameplate cost by distance, and apply
    relays in one pass per frame.
- `tools/stress.sh` budgets move into one table, and CI fails when the largest passing size of any
  pattern drops below the size recorded in the baseline.
- `README.md` Testing: the crowd size the host supports today.

**Acceptance criteria:**
- [x] CI `stress` job: under `lan`, the `cluster` and `cross` patterns meet every budget at 64 bots,
  and no pattern's largest passing size is lower than in the baseline.
- [x] CI `stress` job: host tick p95 at 64 bots in `cluster` is at most half the baseline's, and
  bytes down per peer in `cluster` at 64 bots is at most 60% of the baseline's.
- [x] Suite: each fix has a test that proves its saving on a fixed input (relays per tick, AOI
  scans per tick, windows built per tick, creatures ticked per tick), and the existing sync, AOI and
  creature tests stay green.
- [x] Suite: a relay batch decodes to the same positions as the per-subject relays; a distant peer
  in the AOI still gets a relay at least once per second.
- [x] Harness green on loopback and under `wan_bad`; suite green on both boot paths.

**Implementation notes:**
- Baseline and results: `docs/perf/crowd-baseline.md` (and `.json`, the floor `tools/check_crowd_baseline.py` enforces in the CI `stress` job). Measured on one desktop, `lan`, 15 s steady: `cluster` at 64 bots went from host tick p95 18.4 ms and 136.7 kbit/s down per peer to 8.6 ms and 63.3 kbit/s (47% and 46% of the baseline); `cluster`, `cross` and `spread` now pass every budget at 64 (baseline: 16), `pole` 32, `churn` 0.
- Hot spots worked, in report order: position relays (`RelayScheduler`: rate by distance, unchanged positions wait for a heartbeat, held reports are released; relays leave in one binary `remote_player_states` packet per recipient per 100 ms, same-chunk entries 17 bytes) and the AOI relay phase (`_refresh_equipment_pairs` evaluates only pairs that show gear or hold a record to evict; `aoi_recipients` filters through a set). A probe inside the `chunks` phase then showed the tick p95 was chunk attach on the dedicated server (mesh and trimesh built for a server that draws and walks nothing): `VoxelSlice.attach_geometry` is false there, so a server chunk keeps its data and no nodes.
- Left as follow-ups, because the report ranks them below these and the criteria are met: peer-window sharing, creature AI sleeping, and the watcher avatar pool. The suite pins the saving of each fix actually made (relays per packet, equipment pair evaluations); no test pins windows or creatures ticked, since neither changed.
- `pole` at 64 still misses its tick budget (a 0.5 s stall when the crowd crosses the fold together) and `churn` still averages over the byte budget on every join snapshot; both are in the report.
