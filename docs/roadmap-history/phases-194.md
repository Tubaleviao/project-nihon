# Roadmap history — Phase 194

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 194 — Follow-up debt burn II: terrain streaming and the near ring (#504, #509, #512) ✅ Done

**Goal:** the fast-flight PRs (#503, #507, #510) left 24 review items in three issues. Some are
real bugs: a cached chunk can outlive a neighbour's edit, a cache hit skips apply pacing, and an
aborted playtest step leaves the bot flying. The rest are per-frame allocations and housekeeping.
Phase 193 reworked the collision ring after these issues were filed, so some items may be gone.

**Newel dependency:** NO.

**Depends on:** Phase 193.

**Deliverables:**
- Re-check every item of #504, #509 and #512 against `main`. Close each one that Phase 193 (or a
  later PR) already fixed with a pointer to the change.
- Correctness (#512, #504):
  - the chunk cache signature changes when a neighbour is dug or built (`_edit_rev` is bumped by
    dig/place edits too, not only by `request_rebuild`);
  - a cache hit attaches through the same apply order and pacing as a fresh build;
  - `ChunkCache.approx_bytes` counts collision shape faces and Variant arrays, so the 192 MB cap
    means what it says;
  - a parked collision shape lives in one store, not in both `_parked_shapes` and stand-in meta;
  - turning the near ring off flushes `_waiting` at the toggle instead of releasing it in one
    burst, and ring 1 skips the pump budget like the body's own chunk does;
  - `queue_priority` / `_lane_order` re-sort when the flyer stops, and order diagonal and peer
    chunks by distance from the nearest player, not after the whole lane.
- Coarse chunks (#509). Decision: trees and creatures on a coarse chunk wait for its full upgrade,
  so none sit buried under a coarse cell top. After a fast-flight landing, the chunk under the body
  goes first in the upgrade queue.
- Playtest and CI (#504, #512): `_step_flight` restores flying, the near ring and the TickProbe in
  an always-run path. `FLIGHT_MAX_SHARE` is defined once and the local verdict enforces it. An
  unknown `--playtest-only` name exits 1. `_flight_speed` reads the command line once. The
  slow-machine CI step restores `playtest/report.json` before any upload.
- Per-frame work: `set_unbuilt(unbuilt_window_chunks())`, `_attach_near_collision`'s parked scan
  and `distant_terrain.rebuild`'s `bands.update` (#444) run only when their inputs change.
- Housekeeping: the misplaced `is_chunk_built` docstring, `refs_has` duplication, the garbled
  `near_ring.gd` header, the stale Phase 42 comment and `sl.`-prefixed access in
  `drain_load_queue`. `native_coarse.cpp` sorts each group once and takes packed arrays by const
  reference. A note in `docs/roadmap-history/phases-189.md` on the walking collision radius as
  shipped.

**Acceptance criteria:**
- [x] #504, #509 and #512 are closed: every item is fixed by this phase's PR or closed with a reason in the
  issue (the table below; the issues close when the PR merges).
- [x] Suite: digging or placing in a neighbour invalidates a cached chunk; the cache never returns
  a mesh older than a neighbour's last edit.
- [x] Suite: `approx_bytes` of a fixture chunk with collision is at least the byte size of its mesh
  arrays plus its collision faces.
- [x] Suite: no key is in both `_parked_shapes` and stand-in meta after a build/park/attach cycle.
- [x] Suite: no tree or creature spawns on a coarse chunk before its upgrade, and after a landing
  the chunk under the body is first in the upgrade queue.
- [x] Playtest: a flight step forced to fail leaves flying off, the near ring on and no TickProbe;
  `--playtest-only nosuch` exits 1.
- [x] Playtest budget gate green (median of 3), with walk and flight at or under the current
  baseline in `docs/perf/playtest-baseline.md` (CI's gate on this PR).
- [x] Suite green on both boot paths, harness green (CI).

**Measured** (local, native builder, `--playtest-only flight`, one run): ground under the body 100% of 42
samples; collision and contents 0.8 ms per attached chunk (27.3 ms with the near ring off, limit half);
worker 31 ms per crossing (185 ms with coarse chunks off, limit a third).

**Items and how each was settled:**

| Issue | Item | Outcome |
|---|---|---|
| #504 | aim/build rays without collision at radius 0 | Already fixed: Phase 193's `VoxelRay` reads the voxel columns, not collision. |
| #504 | a far chunk's rebuild re-parks a shape that was attached | Closed, intended: out of every ring a chunk needs no collision; the new shape parks and attaches on re-entry. |
| #504 | `FLIGHT_MAX_SHARE` duplicated, not enforced locally | Fixed: `check_playtest_budget.py` reads both shares from the bot (`bot_const`); a budgeted run fails on them (`flight_share_failures`). |
| #504 | `sl.`-prefixed access in `drain_load_queue`; stale Phase 42 comment | Comment fixed. The prefix stays: it is how every method of the delegate module reads its owner, and the method moved out to keep `chunk_manager.gd` under the 1,500-line cap. |
| #504 | parked list rescanned every frame | Fixed: the scan is skipped while its bodies and `parked_rev` (bumped by every parked shape) are those of a scan that found nothing due. |
| #504 | ring 1 waits on the pump budget | Closed, not changed: the chunk the body steps into becomes its own chunk and attaches unbudgeted on that tick, so the lag cannot drop the body. Exempting ring 1 puts up to eight chunks of Jolt shapes (~70 ms) into one frame on a landing, and three on every walk across a chunk line, which Phase 183's stagger exists to avoid. |
| #504 | parked shape in two stores | Fixed: `_parked_shapes` is the one store; the stand-in meta only carries a shape across a fold (`carry_parked_shapes` → `adopt_standins`); a freed stand-in takes its shape along. |
| #504 | `_step_flight` state not restored on abort | Fixed: the runner calls the step's `_step_restore` whether or not the step returns, then fails a step that left flying, the near ring or the TickProbe changed (`state_leaks`). |
| #504 | waiting contents released in one burst with the ring off | Fixed: `NearRing.set_enabled(false)` spawns them at the toggle. |
| #504 | garbled `near_ring.gd` header; Phase 189 radius note | Fixed (note added to `phases-189.md`). |
| #504 | unrelated moves mixed into the feature commit | Closed: history; nothing to change. |
| #509 | trees and creatures buried under a coarse chunk | Fixed (decision: hide until upgrade): a coarse chunk's contents wait for its full build, except in a peer's window (the host's coarse mesh is its own view). |
| #509 | `native_coarse.cpp` sorts twice, copies packed arrays | Fixed: one sort per group (`merge_rects` sorts in place, counted after); the packed arrays are `const`, so `operator[]` no longer goes through `ptrw()`. |
| #509 | landing upgrade not prioritised | Fixed: with the pool full, the upgrade of the chunk under the body goes to (or moves to) the head of `_rebuild_queue`. |
| #512 | `queue_priority` lane scores the rest after the lane; stale when the flyer stops | Fixed: only the lane goes first, everything else by Chebyshev distance from the nearest centre; a lane-sorted queue is re-sorted when the flyer slows. |
| #512 | `_lane_order` ignores diagonals and peers | Fixed: the same rule for finished builds, peer centres included. |
| #512 | `set_unbuilt(unbuilt_window_chunks())` every frame | Fixed: read only when `unbuilt_window_key` (`built_rev`, centre, radius) changes or patches are still owed; `bands.update` only when band 0's cell, the ring, the seed or the world changed (#444). |
| #512 | a cache hit waits for a worker slot and attaches outside apply order | Fixed: a hit joins `_builds` under a negative id, already done, and attaches in `apply_order` under the frame's pacing; it takes no worker slot (`worker_builds`). |
| #512 | `approx_bytes` undercounts | Fixed: collision shapes' faces and a Variant slot per Array value count. |
| #512 | neighbour `_edit_rev` not bumped by dig/place | Fixed: `_append_edit` bumps it. |
| #512 | misplaced `is_chunk_built` docstring; `refs_has` duplicate | Fixed; `refs_has` replaced by the canonical chunk key. |
| #512 | slow-machine CI step restores the report at the end | Fixed: the main report is restored before any check, the slow run's kept as `report-slow.json`. |
| #512 | `_flight_speed` re-parses the command line; unknown `--playtest-only` runs all | Fixed: read once; an unknown name exits 1. |

**Implementation notes:**
- `chunk_manager.gd` and `voxel_slice.gd` stay under the 1,500-line source cap: the new helpers live in
  `chunk_part_1.gd` (`worker_builds`, `nearest_ring`, `resort_queue`, `take_cache_hit`) and `voxel_build.gd`
  (`_park_shape`, `parked_rev`, `free_standin`).
- `--playtest-abort flight` is a check of the bot, never a gated run: the flight step hangs in its record flight.
- `terrain: a new record schedules exactly one ring rebuild` fails locally on `main` too when the ring build takes
  over its 500 ms debounce on a loaded machine; it is not touched here.

