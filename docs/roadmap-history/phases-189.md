# Roadmap history — Phase 189

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 189 — Fast flight II: collision and contents only near the body ✅ Done

**Goal:** after Phase 187 the build threads keep up at 90 m/s, but each attached chunk costs the main
thread about 17–30 ms. Most of that is ground no one touches: collision for a chunk four rings out, and
creatures spawned under a player who is gone a second later. Pay only for the ground that is reached.

**Newel dependency:** NO.

**Depends on:** Phase 187.

**Deliverables:**
- Collision is built only for chunks within Chebyshev 1 of a body (walking), and for the chunk below a
  flying body. A chunk entering that ring gets its collision then (from the worker's arrays, kept or
  rebuilt). A host keeps collision wherever a creature or peer needs it (dedicated server unchanged).
- Creatures and trees of a chunk spawn when its body slows below a threshold or the chunk enters the
  near ring, not at the moment its mesh attaches. Host authority and determinism are unchanged: the same
  ids and positions spawn, later.
- The playtest bot's `flight` step records main-thread ms per attached chunk (TickProbe phases).

**Acceptance criteria:**
- [x] Suite: a chunk outside the near ring has no collision shape, and gets one when it enters; a
  flying body's chunk below has one (`terrain_stream_tests`: `near: collision …`, including a peer's
  ring, the dedicated server and a fold stand-in).
- [x] Suite: a chunk's contents spawn once, with the same ids, whether they spawn on attach or on
  slowing down (`near: contents spawn once with the same ids …`, `near: deferred contents spawn when the
  chunk enters the near ring`).
- [x] Playtest bot (CI): `flight` main-thread ms per attached chunk at most half of Phase 187's record.
  The record is flown in the same run (see below) and gated on the median of the three CI runs.
- [x] Net harness green (peers' windows still have collision where their bodies are).
- [x] Suite green on both boot paths.

**As built:**
- `src/terrain/near_ring.gd` (owned by `ChunkManager` as `_near`) holds the policy. The bodies are the local
  player (Chebyshev 0 while it flies and `is_moving_fast()`, else 1) and every peer window's centre
  (Chebyshev 1). A process that draws nothing (`keeps_render()` false: the dedicated server) attaches
  collision everywhere, as before. Only the local player's body collides with terrain; creatures do not use
  terrain physics, so no creature needs a ring.
- `VoxelSlice.build_chunk(..., collide)`: the chunk manager's apply passes `wants_collision(chunk)`. A
  refused chunk keeps its worker-made `ConcavePolygonShape3D` parked (`_parked_shapes`), and
  `NearRing.tick()` (each frame, right after the applies) attaches it when the chunk enters a ring: the chunk
  under the local body at once, the rest under the frame's pump budget. A fold carries a root's parked shape
  onto its stand-in (`carry_parked_shapes`), so the stand-in under the body still gets its collision.
  Synchronous builds (the bus path, isolated tests) attach as before.
- Contents: while the local player is fast, a built chunk beyond its near ring and outside every peer's
  window waits (`spawn_or_wait`). It spawns when it enters the ring or the player slows (the Phase 187
  fast hold runs out), nearest first under the pump budget. The ids and positions are a pure function of
  (seed, chunk), so they are the same, later. A chunk that unloads while waiting never spawns.
- `ChunkManager.builds_attached` counts attaches. `set_near_ring_enabled(false)` restores the Phase 187
  behaviour; the playtest bot uses it for its record flight.
- Playtest bot `flight`: the body flies (`admin_moves_synced`, as `/fly` sends it). The step flies twice over
  the same ground: the gated flight, then a record flight with the near ring off. Each records
  `chunk_main_ms` (TickProbe `chunks` plus the nested `chunk_*` phases) per attached chunk after the warm-up.
  The record flies second, over warm ground, so the comparison does not favour the near ring.
  `tools/check_playtest_budget.py` fails CI when the median `main_ms_per_attach` of the three runs is over
  `FLIGHT_MAX_SHARE` (0.5) of the median `record_ms_per_attach`; `--self-test` proves the check.
- `_drain_load_queue` and `adopt_standins` moved verbatim into `chunk_part_1.gd` and `voxel_build.gd` (with
  forwarders) to keep `chunk_manager.gd` and `voxel_slice.gd` under the 1,500-line cap.
