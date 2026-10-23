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
- [ ] CI `stress` job: under `lan`, the `cluster` and `cross` patterns meet every budget at 64 bots,
  and no pattern's largest passing size is lower than in the baseline. *`cluster` meets every budget
  at 64 and no pattern regressed; `cross` at 64 meets the byte, watcher and lag budgets but its host
  tick p95 is 16.9 ms against 16. The spikes are single-chunk attaches (`voxel_build.build_chunk`,
  ~16 ms of mesh and trimesh collision on the host's main thread), not crowd work: carried to
  [Phase 172](phases-172.md#phase-172--host-chunk-attach-off-the-main-thread).*
- [x] CI `stress` job: host tick p95 at 64 bots in `cluster` is at most half the baseline's, and
  bytes down per peer in `cluster` at 64 bots is at most 60% of the baseline's. *(8.66 ms against
  17.63 → 8.82 allowed; 51.0 kbit/s against 130.2 → 78.1 allowed.)*
- [x] Suite: each fix has a test that proves its saving on a fixed input (relays per tick, AOI
  scans per tick, windows built per tick, creatures ticked per tick), and the existing sync, AOI and
  creature tests stay green. *(Creatures were not changed: the report ranks creature AI at 2% and
  creature syncs at 0% of a budget.)*
- [x] Suite: a relay batch decodes to the same positions as the per-subject relays; a distant peer
  in the AOI still gets a relay at least once per second.
- [x] Harness green on loopback and under `wan_bad`; suite green on both boot paths. *(`wan_bad` is
  flaky on main too: 3 of 5 branch runs and 2 of 3 main runs green, the failures being the same
  timing-bound `chop_in_reach`/`tree_cleared` pair, plus one `settlement` deposit on the branch.)*

**Implementation notes:**
- **Relays (hot spot 1, `remote_player_state`).** `src/networking/relay_batch.gd`: a report is queued,
  and every `FLUSH_MS` (100 ms) the host sends each peer one `player_states` packet, a flat
  `[subject, pk, …]` list (split past 256 subjects). A pair is relayed by `RelayBatch.due`: every report
  within `NEAR_RADIUS` (24 m), at most one per `FAR_GAP_MS` (750 ms) beyond it, and an unchanged
  position only as a 1 s keepalive; the mover is never sent its own report. With the 0.5 s report
  interval a peer anywhere in the AOI still hears every neighbour at least once a second. The client
  refuses a malformed batch whole (odd length, over the cap, an id that is not a positive integer, a
  position text that is not a short string) and applies each entry through the single-relay path, so
  the jitter buffer and the stress watcher's lag join are unchanged. A per-frame flush sent batches of
  one or two (reports are spread over the frames), which is why the flush is paced.
- **AOI queries (hot spot 4).** The peer spatial hash had 8 m cells, so every AOI query (each relay
  and each creature sync) probed 25×25 cells; its cells are now one AOI radius wide (3×3 cells), and
  `aoi_recipients` checks membership against a set instead of scanning the peer array per candidate.
- **Window moves (hot spot 3).** A crossing is queued and `PeerWiring.flush_rescopes` serves the frame's
  crossings together: every window moves, the windows are refreshed once, then each snapshot is built.
  The refresh itself was mostly string keys: the desired set is now counted on canonical `Vector2i`
  and keyed once per distinct chunk, the load queue is sorted on a distance computed once per chunk,
  and `RegionStreamer.regions_for_chunks` collects regions as `Vector2i` (keyed once each), looks only
  edge chunks up in the record table and computes an edge chunk's three region rows and columns once.
  A test pins it to the old rule on windows near the seam and region edges. At the pole, a 32-bot
  refresh went from about 17 ms of region lookup to under 2 ms.
- **Re-scope snapshots (hot spot 2, `snapshot_chunk`).** A re-scope now carries only the generation
  records the peer does not already hold or that changed (`SnapshotWiring.records_sent`, key → record
  hash, mirroring the client table that `gen_scope` prunes); a join starts afresh. Join snapshots are
  unchanged, so `churn` (every join is a full snapshot) is still the series that misses its byte
  budget above 16.
- **Baseline gate.** `StressRules.BASELINE_LARGEST` holds the baseline's largest passing size per `lan`
  series; `tools/stress_report.gd` prints `STRESS_REGRESSION` and exits 1 when a series falls below
  it, and the report has a Baseline section. The budgets were already one table (`StressRules.BUDGETS`).
- The stress orphan audit also counts relay pairs and per-peer record tables after `churn`.
- After-run (same command and machine as the baseline, `STRESS_MAX=64 STRESS_PROFILES=lan`), largest
  passing size: `cluster` 16 → 64, `pole` 32 → 64, `cross` 16 → 32, `churn` 0 → 16, `spread` 16 → 16
  (its 32 run misses tick p95 by 0.02 ms). No hard failures, no baseline regression. The remaining
  host tick p95 floor (13–17 ms on `cross` and `spread`) is the chunk attach above.
- Not done, because the report ranks them low: creature AI sleeping and shared paths, the watcher's
  avatar pooling (watcher frame p95 stays at ~17.5 ms up to 64 bots).
