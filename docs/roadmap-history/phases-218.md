# Roadmap history — Phase 218

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 218 — Follow-up cleanup sweep: exact creature positions, the spatial hash, relay and window shortcuts ✅ Done

**Closes:** #531, #537, #542, #558.

**Goal:** burn down every open `autopilot-followup` issue. Each item is fixed, or closed with a
one-line reason when the code it names is gone (for example #542's raider code, removed with raids,
and #537's settlement claim check, removed by Phase 205). Re-check each item against `main` first.

**Newel dependency:** NO.

**Deliverables:**
- #531: relay batch held-entry recipients refreshed; snapshot re-scope retried when dropped;
  `transport.peer_set` cached and read-only, test counters moved off the production base and out of
  `broadcast_aoi`; `ExactSpatialHash` and `SpatialHash` share a base; `creature_ai` passes the exact
  target into `_tick_instance` and steers patrol and companion targets from exact positions; carcass
  comment fixed; `creature_slice` position parameters typed and the `_exact_of` duplicates merged;
  playtest harvest step pins the carcass and retries `out_of_range`.
- #537: `ExactSpatialHash` copies stored position dicts and its header describes the cell-local
  snapshot; a randomized brute-force test of `query_radius` against `WorldPos.offset_between`; a test
  for `separate_bodies`' cross-chunk branch; the project footprint item fixed or closed.
- #542: raider reach judging fixed with exact positions, or closed if no raider code remains.
- #558: `FIRST_RING_TIMEOUT` change recorded in the Phase 214 history; window shortcuts stop walking
  when Alt is released while the letter is held, with an AltGr case tested; the controls rows note
  that Alt+G replaced J for the clan window.

**Acceptance criteria:**
- [x] #531: every item fixed or closed with a reason; suite tests cover the relay hold, the re-scope
  retry and exact patrol steering.
- [x] #537: the randomized `query_radius` test (Z edge, corner, negative chunks, same-cell update)
  and the cross-chunk separation test pass.
- [x] #542: fixed with a test, or closed with the reason recorded in the issue.
- [x] #558: a test releases Alt before the letter and asserts no walk resumes; an AltGr event opens
  no window.
- [x] All four issues closed; `tools/check_followups.sh` reports 0 open from this batch.
- [x] Suite green on both boot paths, harness green.

**Implementation notes:**
- #531: `RelayBatch.build` re-queries recipients every flush (a held entry no longer keeps its first audience); `PeerWiring.flush_rescopes` forgets a crossing whose snapshot was not sent whole, so the next state packet retries it; `Transport.peer_set()` is cached and read-only (the ENet transport invalidates it on `peer_connected`/`peer_disconnected`, others compare `peers()`), the rebuild counter lives in a test subclass; `broadcast_aoi` keeps no counter and the harness step `creature_far_delta` counts through a spy on the transport's raw sender; `ExactSpatialHash` and `SpatialHash` share `src/core/spatial_hash_base.gd`; `_tick_instance` takes the exact target as a parameter (`_exact_targets` is gone); a patrol waypoint carries its exact form (spawn's exact position plus the offset) and a companion steers to its owner's exact position; the two `_exact_of` helpers are `CreatureSlice._exact_of` (query points, Vector3 or exact, anything else is an error) and `CreatureSlice.exact_of_record`; the carcass comment is fixed; the playtest harvest step retries `out_of_range` after `_hold_still` (the kill already pins the entry chances and lets the body settle).
- #537: `ExactSpatialHash` copies the position it stores and its header describes the cell-local snapshot; the randomized brute-force test and the cross-seam `separate_bodies` test are in `creature_exact_tests.gd`. The footprint item is closed: Phase 205 removed the claim radius, so there is nothing to compare a footprint with.
- #542: closed, the raider code (`spawn_raider`, `raiders_of`, `_patrol` raider goals) was removed with raids (Phase 200 aborted).
- #558: see the Phase 214 history; `WindowShortcuts.consume` / `walk_held`, tests in `window_shortcut_tests.gd`.
