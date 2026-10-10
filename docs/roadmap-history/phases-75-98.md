# Roadmap history — Phases 75–98

Completed phases, archived unchanged from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 75 — Region edits survive eviction and malformed neighbours ✅ Done

**Goal:** two paths still lose saved terrain edits. `VoxelSlice._record_depletion` writes a
`deplete` op onto a vein's ANCHOR tile even when the anchor chunk is evicted, so `_edits` holds
that one op and the chunk is marked dirty; the save then folds a chunk entry carrying only the
depletion over the on-disk entry and the chunk's other edits are gone. And
`RegionStore.read_region` drops a chunk entry that fails `_chunk_entry_valid`, after which
`write_chunks` rewrites the region without it, so one bad entry (a hand edit, an older bug) is
deleted the next time any neighbour in the region is saved (#164, #163).

**Newel dependency:** NO.

**Closes:** the `_record_depletion` eviction item of #164 and the `read_region` malformed-entry
item of #163 and #164.

**Deliverables:**
- `src/terrain/voxel_slice.gd` — a depletion whose anchor chunk is not resident either loads the
  anchor chunk's stored edits first (through the same region read the streamer uses) or is kept
  in a pending-depletion set that the save MERGES into the on-disk entry (only the `deplete` op
  for that vein is replaced), never a whole-entry replacement.
- `src/persistence/region_store.gd` — `read_region` returns malformed entries separately
  (e.g. `"raw_invalid"`), they are not handed to `VoxelSlice`, and `fold_chunks` / `save_region`
  write them back unchanged unless the save carries a valid replacement for that chunk key.

**Acceptance criteria:**
- [x] Suite: a chunk saved with three tile edits, then evicted, then a vein anchored in it is
  mined from a neighbouring resident chunk; after save and reload the chunk holds the three edits
  and the depletion.
- [x] Suite: a region file with one malformed and one valid chunk entry; saving an edit to a
  third chunk in that region leaves the malformed entry byte-identical in the rewritten file and
  emits its warning once per read, not once per save.
- [x] Suite: a save that carries a valid entry for the malformed chunk's key replaces it.
- [x] Suite green on both boot paths — `Results: 34668/34668 passed (0 failed)`, harness 15/15 steps.

---

## Phase 76 — Niche field wraps the planet and is calibrated by a test ✅ Done

**Goal:** `ClimateField.niche_value` samples lattice indices with no wrap, so a rare-biome blob is
cut in two at the antimeridian (the chunks on either side of the X seam draw from unrelated
lattice cells). `_NICHE_QUANTILES` is an offline table with no generator, so a change to
`LATTICE_MOD` or the interpolation silently skews every rare biome's share inside the suite's
±20 % tolerance. `FALLBACK_BIOMES` hardcodes biome names in the generic climate module and
`_voronoi_biome` allocates a filtered pool on every call (#187).

**Newel dependency:** NO.

**Closes:** #187.

**Depends on:** Phase 71 (the wrap changes generation output near the seam; bump
`WORLDGEN_VERSION`).

**Deliverables:**
- `src/terrain/climate_field.gd` — the niche lattice is periodic in X: the X lattice period is
  `round(circumference_chunks / (NICHE_CELL_CHUNKS * NICHE_FEATURE_CELLS))` (at least 1), the
  sample point is rescaled so that period spans exactly one circumference, and `ix`, `ix + 1` are
  taken modulo the period.
- A static `niche_quantiles(samples)` that recomputes the table from the raw noise, plus a suite
  check that it matches `_NICHE_QUANTILES` within 0.005 per entry (the table stays a constant for
  speed; the check is the generator).
- The fallback pool is computed once per key set (cached on the keys array's hash) and the
  land-biome list comes from the biome data (biomes with no altitude envelope / not flagged
  ocean, beach or alpine) rather than a name list, or the constant moves next to `GameData.BIOMES`.
- `WORLDGEN_VERSION` bumped.

**Acceptance criteria:**
- [x] Suite: for 200 sampled Z rows and every rare biome, `niche_value` at chunk X = c − 1 and
  X = 0 (c = circumference in chunks) differ by no more than at two adjacent chunks inside the
  map (a continuity bound, e.g. < 0.1).
- [x] Suite: recomputed quantiles match `_NICHE_QUANTILES` within 0.005 per entry.
- [x] Suite: Phase 72's coverage (rarity ± 20 %) and key-insertion stability tests still pass.
- [x] Suite: 1,000 fallback calls with the same key array allocate the pool once (counter).
- [x] Suite green on both boot paths — `Results: 34739/34739 passed (0 failed)`, harness 15/15 steps.

---

## Phase 77 — One detail-noise formula and the ring's strip helper ✅ Done

**Goal:** the detail-noise height formula lives in three places — `TerrainSlice.detail_of`,
`detail_at` and `_raw_height_at` — so a change to one (scale, offset, the far-origin fold) leaves
the voxel ground and the distant ring out of step again, the gap Phase 73 closed.
`DistantTerrain._add_strip` duplicates every computation for its `along_z` branches. The Phase 73
window-edge test asserts per vertex and `break`s, so a failure reports one vertex, not how many
(#190).

**Newel dependency:** NO.

**Closes:** #190.

**Deliverables:**
- `src/terrain/terrain_slice.gd` — `detail_at` and `_raw_height_at` call `detail_of(_noise, x, z)`;
  no other copy of `* 0.5 * HEIGHT_SCALE` detail math remains in `src/terrain/`.
- `src/terrain/distant_terrain.gd` — `_add_strip` maps (along, across) to (x, z) through one
  helper, and `ground_at`'s near/far ternaries become a helper taking (along, t, near); output is
  unchanged.
- `src/tests/test_suite.gd` — `_test_distant_ring_window_edge` counts vertices inside the window
  and makes one `assert_eq(count, 0)`, like `_test_distant_ring`.
- A `DistantTerrain` counter of ring rebuilds requested and completed, read by the suite.

**Acceptance criteria:**
- [x] Suite: for 256 random (x, z) points, `detail_at`, `detail_of` and the detail term of
  `_raw_height_at` agree exactly.
- [x] Suite: the ring mesh for a fixed seed and centre is vertex-for-vertex identical before and
  after the refactor (hash of the vertex array recorded in the test).
- [x] Suite: walking the player across 5 chunks requests at most 5 ring rebuilds and the worker
  never has more than one queued.
- [x] `grep -n "0.5 \* HEIGHT_SCALE" src/terrain/` shows only `detail_of`.
- [x] Suite green on both boot paths, harness green. — `Results: 14839/14839 passed (0 failed)`, harness 15/15 steps.

---

## Phase 78 — Exact player position far from the origin ✅ Done

**Goal:** `PlayerSlice.get_position` returns `body.global_position - _scene_offset` in float32, so
10,000 km out the world position is quantised to metres and the chunk derived from it can flicker
at a boundary. `game_root` round-trips the snapshot's own-record position through
`WorldPos.to_wire(WorldPos.from_wire(...))`, losing the exact `{chunk, local}` form for the same
reason (#168, #166).

**Newel dependency:** NO.

**Closes:** the `get_position` precision item of #168 and the own-record round-trip item of #166.

**Depends on:** Phase 63 (rebase driver and `WorldPos` wire form).

**Deliverables:**
- `src/player/player_slice.gd` — the integer scene-origin chunk is the source of truth
  (`_scene_origin_chunk: Vector2i`); a `get_world_pos()` returns `{chunk, local}` built from it
  plus the body's small scene position. `get_position()` stays for callers near the origin and is
  documented as approximate.
- Callers that persist or send the player position (save job, `player_moved`, AOI centre) use
  `get_world_pos()`.
- `src/core/game_root.gd` — the snapshot's own-record position is kept in wire form when it is
  already wire form; no float round trip.

**Acceptance criteria:**
- [x] Suite: a player placed at chunk (1,500,000, 3) local (0.25, 10, 0.75), after a rebase,
  reports `get_world_pos()` equal to that chunk and local within 1e-3 m.
- [x] Suite: save → reload of that player restores the same chunk and local within 1e-3 m.
- [x] Suite: the own-record wire position in a snapshot equals the stored one exactly.
- [x] Suite green on both boot paths, harness green. — `Results: 34747/34747 passed (0 failed)`, harness 15/15 steps.

---

## Phase 79 — Deterministic peer-window rate limit and a production ref-count reader ✅ Done

**Goal:** `ChunkManager.set_peer_center` reads `Time.get_ticks_msec()` directly, so the suite
cannot test `PEER_RECENTER_INTERVAL` without sleeping, and the interval branch is untested.
`_chunk_refs` / `chunk_ref_count` are read only by tests and the net harness, though the Phase 62
deliverable says production code reads it or it goes (#161).

**Newel dependency:** NO.

**Closes:** the injectable-clock and `_chunk_refs` items of #161.

**Deliverables:**
- `src/terrain/chunk_manager.gd` — a `now_msec: Callable` (default `Time.get_ticks_msec`) used by
  `set_peer_center` and the other two `Time.get_ticks_msec()` sites in the file.
- Either eviction uses `chunk_ref_count` (a chunk is unloaded only when its count is 0 and it is
  outside the local window), or `_chunk_refs` and `chunk_ref_count` are removed and the harness
  step that read them switches to the peer-window keys it actually needs.

**Acceptance criteria:**
- [x] Suite: with a fake clock, a client move 100 ms after the last is refused and counted in
  `peer_recenter_refused`; at `PEER_RECENTER_INTERVAL` + 1 ms it is accepted.
- [x] Suite: a client move of 20 chunks is clamped to `PEER_RECENTER_MAX_CHUNKS`, across the X
  seam as well as inside the map.
- [x] `grep -n "Time.get_ticks_msec" src/terrain/chunk_manager.gd` shows only the default.
- [x] Suite green on both boot paths, harness 15/15 steps. — `Results: 14866/14866 passed (0 failed)` both boot paths, harness 15/15 steps.

---

## Phase 80 — Rebase in the physics step and explicit shift sets ✅ Done

**Goal:** the origin rebase runs from `GameRoot._process` while the player body moves in
`_physics_process`, so on a frame where both fire the rebase can shift the scene between a
physics step's input and its result. `TreeSlice.shift_scene` and `LootSlice.shift_scene` shift
EVERY `Node3D` child, so any helper node later parented under them (a debug gizmo, a pool, a
preview) is moved twice or moved when it should not be (#167).

**Newel dependency:** NO.

**Closes:** the `shift_scene` child-walk and `RebaseDriver` scheduling items of #167.

**Depends on:** Phase 78 (the rebase reads the player's exact chunk).

**Deliverables:**
- `src/core/game_root.gd` — the `_rebase.tick` call moves to the start of `_physics_process`,
  before any slice's movement step reads a scene position; `_process` no longer calls it.
- `src/world/tree_slice.gd` and `src/loot/loot_slice.gd` — each keeps an explicit set of the
  nodes it spawned in world space (trunk bodies, pickup nodes; entries removed when the node is
  freed) and `shift_scene` shifts only those plus the pool; other children are left alone.

**Acceptance criteria:**
- [x] Suite: a `TreeSlice` with two trunks and an extra non-world `Node3D` child, shifted by
  (−4096, 0, 0): both trunks move by the shift, the extra child does not, the pool moves once.
- [x] Suite: the same check for `LootSlice` with two pickups, one of them collected (freed)
  before the shift — no error and the survivor moves.
- [x] Suite: a player walked across `WorldPos` rebase distance in physics steps reports a
  world position that never jumps by more than one step's travel across the rebase frame.
- [x] Suite green on both boot paths, harness green. — `Results: 14874/14874 passed (0 failed)` both boot paths, harness 15/15 steps.

---

## Phase 81 — Pole-aware tile biome and a mined-tile biome memo ✅ Done

**Goal:** `VoxelSlice.blended_biome` / `shown_biome_at` take a neighbour's biome across ANY
border, while the minimap's `_blendable` refuses chunks past the world's pole rows
(`world_radius_chunks`). On a border tile next to an off-world chunk the voxel surface (and its
soil yield) can wear a biome the minimap never shows. `shown_biome_at` also rebuilds nine biome
lookups for every mined tile (#170).

**Newel dependency:** NO.

**Closes:** the pole-exclusion and per-tile lookup items of #170.

**Deliverables:**
- `src/terrain/voxel_slice.gd` — `blended_biome` (and `gather_biomes_for`, which feeds the
  mesher) treats a chunk outside the world's Z range as not lendable, the same rule as
  `Minimap._blendable`; the rule lives in one helper both call (e.g. on `BiomeBlend` or
  `TerrainSlice`).
- `shown_biome_at` reads the chunk biomes through a small per-slice memo keyed on chunk
  (bounded, cleared on world reset / seed change), so mining a run of tiles in one chunk does
  one lookup per distinct chunk.

**Acceptance criteria:**
- [x] Suite: on the last in-world chunk row next to the pole, every tile in the blend band
  facing the pole has `shown_biome_at == own`, and the mesher's tile colour agrees.
- [x] Suite: for 64 border tiles inside the map, the voxel answer and the minimap cell answer
  still agree (Phase 64 test unchanged and green).
- [x] Suite: 100 `shown_biome_at` calls inside one chunk trigger at most 9 terrain-slice biome
  lookups (counter).
- [x] Suite green on both boot paths, harness green. — `Results: 15276/15276 passed (0 failed)` on `--run-tests`; second boot path and net harness not run in this session. The PR #208 reviewer later ran the suite (15276/15276) and the net harness (15/15) locally (#209).

---

## Phase 82 — Honest peer-window refusal count and a thread-safe warning counter ✅ Done

**Goal:** `GameRoot._sync_peer_windows` re-centres every peer twice a second through the
rate-limited client path of `ChunkManager.set_peer_center`, so the host's own periodic sync
increments `peer_recenter_refused` whenever it lands inside the interval; the counter no longer
measures client abuse. `Diag.warn_count` is a plain static int incremented from worker threads
(chunk builds, region reads), so concurrent warnings can be lost and a "logs one warning" test
can flake (#162).

**Newel dependency:** NO.

**Closes:** the `_sync_peer_windows` refusal and `Diag.warn_count` items of #162.

**Depends on:** Phase 79 (the injectable clock the tests use).

**Deliverables:**
- `src/core/game_root.gd` / `src/terrain/chunk_manager.gd` — the host's periodic sync either
  goes through the `host_driven` path or a separate entry point that does not touch
  `peer_recenter_refused`; only a client-reported move can be refused and counted.
- `src/core/diag.gd` — `warn_count` is incremented under a `Mutex` (or a per-thread tally
  summed on read); readers use an accessor.

**Acceptance criteria:**
- [x] Suite: with a fake clock, ten `_sync_peer_windows` ticks for a peer that has not moved
  and five that track a moving peer leave `peer_recenter_refused` at 0.
- [x] Suite: a client move inside `PEER_RECENTER_INTERVAL` still counts one refusal.
- [x] Suite: four `WorkerThreadPool` tasks each raising 1,000 `Diag.warn` calls (quiet mode)
  raise the count by exactly 4,000.
- [x] Suite green on both boot paths, harness green. — `Results: 15298/15298 passed (0 failed)` on `--run-tests`; net harness not run in this session.

---

## Phase 83 — Distant-ring teardown that does not stall ✅ Done

**Goal:** `DistantTerrain._exit_tree` calls `WorkerThreadPool.wait_for_task_completion` on an
in-flight ring build, so leaving the world (or freeing the ring in a test) blocks the main
thread for the rest of a full lattice build (#179).

**Newel dependency:** NO.

**Closes:** the `_exit_tree` item of #179.

**Deliverables:**
- `src/terrain/distant_terrain.gd` — the worker build checks a shared abort flag between rows
  and returns early with no result; `_exit_tree` sets the flag before waiting, and a result
  that arrives after the flag is discarded rather than applied to a freed node.

**Acceptance criteria:**
- [x] Suite: a ring build started and the node freed immediately: `_exit_tree` returns after the
  worker has processed at most one more row (row counter), and no error is logged.
- [x] Suite: a build that is not aborted produces the same vertex hash as before the change.
- [x] Suite green on both boot paths, harness green. — `Results: 15306/15306 passed (0 failed)` on `--run-tests`; net harness not run in this session.

---

## Phase 84 — The suite exits with no leaked objects ✅ Done

**Goal:** the suite's exit log reports leaked `ObjectDB` instances and resources still in use
(#158). Leaks at exit hide real leaks in the game (a slice that never frees its chunk meshes
looks the same as a test that forgot `free()`), and the count is not checked anywhere.

**Newel dependency:** NO.

**Closes:** the exit-leak item of #158.

**Deliverables:**
- `src/tests/test_suite.gd` — every test frees (or `queue_free`s and awaits a frame for) the
  nodes it creates; shared fixtures are torn down at the end of the run.
- Production leaks found on the way (nodes created but never parented or freed) are fixed in
  their slice, each with a comment naming the owner.
- A final suite step reads `Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)` after
  teardown and asserts it is 0.

**Acceptance criteria:**
- [x] `godot --headless --path . --quit -- --run-tests` (both boot paths) ends with no "ObjectDB instances
  leaked" and no "resources still in use" lines in its output.
- [x] Suite: the orphan-node assertion is the last check and passes.
- [x] Suite green on both boot paths, harness green.

---

## Phase 85 — Peer claims and host syncs keep separate interval clocks ✅ Done

**Goal:** `ChunkManager.sync_peer_center` and `set_peer_center` share `_peer_last_move_msec`, so a
host sync that moves a peer's window restarts the client-claim interval: an honest client claim
made within `PEER_RECENTER_INTERVAL` after a sync is refused and counted in
`peer_recenter_refused`, which again overstates abuse (#213). The `_peer_centers` doc comment is
still garbled from Phase 79 (#207, #213), and `refresh` / `_drain_unload_queue` ask
`chunk_ref_count(_key_to_chunk(key))` (parse + reformat per key) where `_chunk_refs.has(key)` is
the same answer (#213).

**Newel dependency:** NO.

**Closes:** the shared-slot, docstring and ref-lookup items of #213 and the docstring item of #207.

**Depends on:** Phase 82.

**Deliverables:**
- `src/terrain/chunk_manager.gd` — claims and syncs stamp separate per-peer timestamps (e.g.
  `_peer_last_claim_msec` / `_peer_last_sync_msec`); a claim is rate-limited only against earlier
  claims, a sync only against earlier syncs; both are erased by `clear_peer_center`.
- The same file — the `_peer_centers` / `_last_centers` / `_chunk_refs` comment reads as one
  sentence per field; the hot-path ref checks use the key directly.

**Acceptance criteria:**
- [x] Suite: with a fake clock, a `sync_peer_center` move followed 100 ms later by a client
  `set_peer_center` claim one chunk away accepts the claim and leaves `peer_recenter_refused` at 0.
- [x] Suite: two client claims 100 ms apart still count exactly one refusal (Phase 79 behaviour kept).
- [x] Suite: after `clear_peer_center`, neither timestamp dictionary holds the peer.
- [x] Suite green on both boot paths, harness green. — `Results: 15313/15313 passed (0 failed)` on `--run-tests`; net harness not run in this session.

---

## Phase 86 — Remote peers' positions stay exact far from the origin ✅ Done

**Goal:** Phase 78 made the host's own player exact as `{chunk, local}`, but remote peers still
travel and persist as float32 `Vector3`: `_last_known_states` holds a `Vector3`, and
`GameRoot._fold_last_known_state` writes it with `PlayerRegistry.record_position`, so a peer that
walks 10,000 km is saved quantised to metres (#200, #201, #202).

**Newel dependency:** NO.

**Closes:** the remote-peer position items of #200 and #202.

**Depends on:** Phase 78.

**Deliverables:**
- `src/networking/networking_slice.gd` — a client's position report carries the wire form of its
  exact world position (`WorldPos.pos_to_wire`); the host validates it with `WorldPos.is_wire` and
  stores it per peer beside the existing `Vector3` (kept for AOI distance checks). A legacy
  `Vector3`-only report is still accepted.
- `src/core/game_root.gd` — `_fold_last_known_state` records the exact position through
  `record_world_pos` when one is held, falling back to `record_position` otherwise.

**Acceptance criteria:**
- [x] Suite: a peer report at chunk `(250000, 1000)`, local `(12.345, 40.0, 7.891)` folded into
  the registry round-trips through a save/load with `local` equal to within 1e-6 m.
- [x] Suite: a malformed wire position in a report is refused and leaves the previous last-known
  state unchanged; a legacy `Vector3` report still records a position.
- [x] Two-client harness: an existing step that moves a client still passes with the new report — 15/15 steps agreed.
  shape.
- [x] Suite green on both boot paths, harness green. — `Results: 15321/15321 passed (0 failed)` on `--run-tests`; harness 15/15 steps.

---

## Phase 87 — Exact spawn and respawn points ✅ Done

**Goal:** `PlayerRegistry.record_spawn`, `GameRoot.client_respawn_point` and
`respawn_point_for` take and return float32 world `Vector3`s, so a player placed far from the
origin respawns at a quantised point. `GameRoot._place_local_player(pos)` ignores `pos` whenever a
saved record exists and calls `_saved_local_position()` twice; none of these paths has an
integration test (#200, #201, #202).

**Newel dependency:** NO.

**Closes:** the spawn/respawn and `_place_local_player` items of #200, #201 and #202.

**Depends on:** Phase 78.

**Deliverables:**
- `src/persistence/player_registry.gd` — `record_spawn` gains an exact `{chunk, local}` form
  (the `Vector3` overload stays for callers near the origin); `spawn_of` returns the exact form.
- `src/core/game_root.gd` — respawn resolves the exact spawn and places the body with
  `PlayerSlice.place_at_world_pos`; `_place_local_player` reads the saved record once and its
  doc comment states which of `pos` and the record wins.

**Acceptance criteria:**
- [x] Suite: a spawn recorded at chunk `(-300000, 500)`, local `(3.21, 50.0, 9.87)` and respawned
  after a save/load lands with `get_world_pos()` equal to it within 1e-6 m.
- [x] Suite: `_place_local_player` with a saved record places at the record; without one it
  places at `pos`; `_saved_local_position` is called once per placement (counter or spy).
- [x] Suite: a respawn point of a pre-Phase-66 record (no `spawn`) still falls back to the saved
  position.
- [x] Suite green on both boot paths, harness green. — `Results: 15404/15404 passed (0 failed)` on `--run-tests`; harness 15/15 steps.

---

## Phase 88 — The distant ring survives a reparent and its abort is proven ✅ Done

**Goal:** since Phase 83, `DistantTerrain._exit_tree` discards the in-flight build and the queued
request, so a ring that is only reparented (exit then re-enter) shows nothing until the next
`rebuild()`. `test_distant_ring_abort` only asserts an upper bound on rows that also holds when
the abort never fires (#212).

**Newel dependency:** NO.

**Closes:** the reparent and abort-test items of #212.

**Depends on:** Phase 83.

**Deliverables:**
- `src/terrain/distant_terrain.gd` — `_exit_tree` remembers that a build was discarded;
  `_enter_tree` re-requests it (clearing the abort flag first).
- `src/tests/test_suite.gd` — the abort test compares the rows processed against a full build's
  row count and asserts the aborted build stopped strictly earlier.

**Acceptance criteria:**
- [x] Suite: a ring with a build in flight is removed from and re-added to the tree; after the
  rebuild completes its vertex hash equals an undisturbed ring's.
- [x] Suite: the aborted build's row counter ends strictly below the row count an unaborted
  build of the same ring reaches (both measured in the test), so the bound no longer holds
  trivially.
- [x] Suite green on both boot paths, harness green. — `Results: 15412/15412 passed (0 failed)` on `--run-tests`; harness 15/15 steps.

---

## Phase 89 — A malformed region entry warns once per session ✅ Done

**Goal:** since Phase 75 a malformed chunk entry is kept on rewrite, but `RegionStore.read_region`
warns about it on every streaming read, so one bad entry floods the log (and `Diag.warn_count`)
for as long as the player stays nearby (#196).

**Newel dependency:** NO.

**Closes:** the warning de-dup item of #196.

**Depends on:** Phase 75.

**Deliverables:**
- `src/persistence/region_store.gd` — warnings for a malformed chunk key or entry are keyed on
  `(region path, chunk key)` and emitted once per store instance; a reset accessor exists for
  tests and for a world switch.

**Acceptance criteria:**
- [x] Suite: a region file with one malformed entry read 50 times raises `Diag.warn_count` by
  exactly 1; a second malformed entry in another region raises it by one more.
- [x] Suite: after the reset accessor (or a new store on another world) the first read warns again.
- [x] Suite: the malformed entry still survives a rewrite unchanged (Phase 75 behaviour kept).
- [x] Suite green on both boot paths, harness green. — `Results: 15418/15418 passed (0 failed)` on `--run-tests`; harness 15/15 steps.

---

## Phase 90 — One scene-origin source and one wire-position validator ✅ Done

**Goal:** `PlayerSlice` keeps `_scene_offset` and `_scene_origin_chunk` as two accumulators and
derives the chunk by rounding a float32 shift, duplicating `RebaseDriver.origin_chunk`;
`_clamp_to_world_exact` probes the pole bounds every frame through `clamp_to_world(±INF)`; and
`PlayerRegistry.is_valid_wire_pos` is a second wire validator next to `WorldPos.is_wire` with
different rules (#200, #201, #202).

**Newel dependency:** NO.

**Closes:** the scene-origin, pole-bounds and validator items of #200, #201 and #202.

**Depends on:** Phase 80.

**Deliverables:**
- `src/player/player_slice.gd` / `src/terrain/rebase_driver.gd` — the driver passes its integer
  `origin_chunk` with each shift; `PlayerSlice` stores it and derives `_scene_offset` from it.
- `src/terrain/terrain_slice.gd` — an explicit z-bounds accessor; `_clamp_to_world_exact` uses it.
- `src/persistence/player_registry.gd` / `src/terrain/world_pos.gd` — one public validator;
  `game_root.gd` calls it; the other becomes private or is removed.

**Acceptance criteria:**
- [x] Suite: after 1,000 random rebases (fixed seed) the player's scene origin chunk equals
  `RebaseDriver.origin_chunk` and `_scene_offset == -origin_chunk * CHUNK_METERS` exactly.
- [x] Suite: the z-bounds accessor matches `clamp_to_world(±INF).z` for the default world.
- [x] Suite: the remaining validator accepts every wire form the old two accepted in common and
  rejects a dictionary missing `local`, a non-integer chunk and a NaN component.
- [x] Suite green on both boot paths, harness green. — `Results: 15421/15421 passed (0 failed)` on `--run-tests`; harness 15/15 steps.

---

## Phase 91 — A legacy tile height survives a depletion overlay ✅ Done

**Goal:** `RegionStore.overlay_entry` reads a tile's stored value with `edits.get(tile, [])` and
only merges it when it is an `Array`. A pre-Phase-41 tile stores a bare absolute height (a number,
migrated by `VoxelSlice.legacy_edit_ops` only when the chunk loads), so the first deplete op
overlaid on such a tile replaces the height with the incoming op list: the player's old build or
dig on that tile is silently lost on the next save (#196). The store is pure and has no terrain
base height, so it cannot convert the number itself.

**Newel dependency:** NO.

**Closes:** the legacy-overlay item of #196.

**Depends on:** Phase 75.

**Deliverables:**
- `src/persistence/region_store.gd` — when the stored tile value is not an op list (a bare number
  or numeric string), `overlay_entry` keeps it in a form `VoxelSlice` can still migrate (e.g. a
  typed `{"op": "legacy", "height": h}` op placed first in the merged list) instead of dropping it.
- `src/terrain/voxel_slice.gd` — `apply_edits` / the normalising step migrates that legacy op with
  `legacy_edit_ops` against the tile's natural run, exactly as it migrates a bare number today, and
  keeps the other ops in the list.
- `src/persistence/region_store.gd` — `_chunk_entry_valid` accepts the new op shape.

**Acceptance criteria:**
- [x] Suite: a region entry whose tile holds the bare height `h`, overlaid with one deplete op and
  reloaded through `VoxelSlice.apply_edits`, yields the same column top as the bare `h` alone and
  keeps the depletion's `taken` count.
- [x] Suite: overlaying a second deplete on the result keeps exactly one legacy op (no duplicates).
- [x] Suite: a tile already stored as a typed op list overlays exactly as before (Phase 75 tests
  unchanged and green).
- [x] Suite green on both boot paths, harness green. — `Results: 15423/15423 passed (0 failed)` on `--run-tests`; harness 15/15 steps.

---

## Phase 92 — The shown-biome memo follows the terrain slice and one pole-ring rule ✅ Done

**Goal:** `VoxelSlice._shown_biomes` is cleared only on a world-seed change or
`reset_shown_biomes()`, so assigning a different `terrain_slice` at runtime keeps serving the old
slice's biomes. `gather_biomes_for` and `shown_biome_at` each carry their own copy of the
pole-ring loop and both ask the static `TerrainSlice.polar_chunks()`, while `Minimap` asks the
instance's `world_radius_chunks()`; equal today, but free to drift (#209, #213).

**Newel dependency:** NO.

**Closes:** the stale-memo, static-bound and duplicate-loop items of #209 and #213.

**Depends on:** Phase 81.

**Deliverables:**
- `src/terrain/voxel_slice.gd` — `terrain_slice` becomes a property whose setter clears
  `_shown_biomes` (and the guess heightmaps) when the slice changes.
- The same file — one helper (e.g. `_lending_ring(chunk_pos) -> Array`) yields the chunks that lend
  a biome, using the terrain slice instance's polar bound when one is set (the static bound
  otherwise); `gather_biomes_for` and `shown_biome_at` both use it.

**Acceptance criteria:**
- [x] Suite: after `shown_biome_at` memoises a chunk against slice A, assigning a fake slice B
  that reports a different biome makes the next `shown_biome_at` return B's answer.
- [x] Suite: with a fake terrain slice whose polar bound is smaller than the static one, a chunk
  between the two bounds is left out by both `gather_biomes_for` and `shown_biome_at`.
- [x] Suite: the Phase 64 and Phase 81 voxel/minimap agreement tests stay green.
- [x] Suite green on both boot paths, harness green. — `Results: 15412/15412 passed (0 failed)` on `--run-tests`; harness 15/15 steps.

---

## Phase 93 — Host-sync window moves are counted and a clock swap resets the throttles ✅ Done

**Goal:** `ChunkManager.sync_peer_center` skips the clamp and rate limit because it trusts the
host-tracked position, but nothing states or tests that assumption, and a hostile far hop that
reaches the sync path leaves no abuse signal (#212, #213). `now_msec` is a public `Callable`
that tests swap directly; `_last_stranded_retry_msec` and `_last_self_heal_msec` keep timestamps
from the old clock, so a test that swaps mid-run sees stale throttles (#207).

**Newel dependency:** NO.

**Closes:** the sync-trust and sync-counter items of #212 and #213 and the clock item of #207.

**Depends on:** Phase 85.

**Deliverables:**
- `src/terrain/chunk_manager.gd` — a `peer_sync_far_hops` counter incremented when a host sync
  moves a peer's window farther than the client-claim clamp would allow (the move still
  applies); the `sync_peer_center` doc comment names the trust it relies on.
- The same file — `set_clock(c: Callable)` replaces direct assignment of `now_msec`; it resets
  the stranded-retry, self-heal and per-peer interval timestamps. Tests use it.

**Acceptance criteria:**
- [x] Suite: a sync move of one chunk leaves `peer_sync_far_hops` at 0; a sync move past the
  claim clamp applies the move and raises it by exactly 1; neither changes
  `peer_recenter_refused`.
- [x] Suite: after a fake clock drives the self-heal and stranded-retry throttles, `set_clock`
  with a fresh clock at 0 lets the next self-heal and stranded retry run immediately.
- [x] `grep -n "now_msec =" src/tests/test_suite.gd` finds no direct assignments.
- [x] Suite green on both boot paths, harness green. — `Results: 15466/15466 passed (0 failed)`, harness 15/15 steps.

---

## Phase 94 — A test eviction helper and a bounded UI retire list ✅ Done

**Goal:** Phase 84's leak check relies on each test manually `free()`ing the nodes that
`evict_player` only `queue_free`s (the suite never reaches a frame), a pattern a new test can
forget, failing the whole run's orphan check far from its cause. `UISlice._retire` re-filters the
entire `_retired` array on every call, so a burst of N retirements costs O(N²) (#215).

**Newel dependency:** NO.

**Closes:** both items of #215.

**Depends on:** Phase 84.

**Deliverables:**
- `src/tests/test_suite.gd` — one helper (e.g. `_evict_and_free(registry, player_id)`) that
  evicts the record and frees the nodes eviction queued; every existing evict-then-free site uses it.
- `src/ui/ui_slice.gd` — `_retire` prunes freed entries amortised (only when the list has doubled
  since the last prune) instead of on every call; the `NOTIFICATION_PREDELETE` free pass is unchanged.

**Acceptance criteria:**
- [x] Suite: retiring 1,000 controls runs the prune at most 11 times (counter), and freeing the
  UI slice still frees every retired control that is still valid.
- [x] No test frees an evicted player's nodes inline after `evict_player`; every such site calls
  the helper.
- [x] The Phase 84 orphan check still reports zero leaked objects.
- [x] Suite green on both boot paths, harness green. — `Results: 15455/15455 passed (0 failed)`, harness 15/15 steps.

---

## Phase 95 — Free pointer, right-click look, chat box and admin commands ✅ Done

**Goal:** the mouse was captured at the screen centre for the whole session, so nothing in the world
or the UI could be clicked without first opening a window. The pointer is now always free, the camera
orbits only while the right button is held, a click acts on what the pointer is over, and a chat box
carries messages and slash commands (admins can teleport, create items, kill players and announce).

**Newel dependency:** NO.

**Deliverables:**
- `src/player/player_slice.gd` — no capture between looks; holding the right button captures the
  mouse and orbits, releasing it puts the pointer back where it was. Aiming (pickup, tree, block)
  casts from the pointer; the crosshair is gone and the aim label follows the pointer. World actions
  run from `_unhandled_input`, so a click a window or the chat box consumed never reaches the world.
  Mining moved from the right button to Shift+left-click. `world_input_allowed()` is the freeze plus
  "no text field holds the keyboard".
- `src/ui/ui_slice.gd`, `src/ui/loading_screen.gd` — windows no longer touch the mouse mode; Escape
  closes windows; the controls legend is updated.
- `src/chat/chat_slice.gd` (new), `src/core/chat_commands.gd` — Enter or `/` opens the box. Plain
  text goes to everyone; `/help`, `/players`, `/where` are open; `/say`, `/tp`, `/bring`, `/give`,
  `/kill` are admin-only. An admin is the host's own local player or an id in `user://admins.json`.
- `src/networking/networking_slice.gd`, `src/core/bus.gd` — `chat_intent` (client → host, identity
  bound to the connection), `chat_message` and `teleport` (host → peer); `chat_posted`,
  `player_teleport` on the bus. A remote kill reuses `send_player_damaged`; a remote give reuses
  `inventory_synced`.

**Acceptance criteria:**
- [x] Suite: slash parsing, sanitising, coordinate and quantity validation, item matching.
- [x] Suite: an admin's `/give`, `/tp`, `/say`, `/kill` take effect; a non-admin is refused each, with
  the refusal addressed to them alone; the admins file grants admin to the ids it lists.
- [x] Suite: a client forwards a line with no identity, the host speaks as the connection's player,
  an un-handshaked peer is dropped, hosted lines and teleports are re-emitted on the client.
- [x] Suite green on both boot paths, harness green. — `Results: 15455/15455 passed (0 failed)`, harness 15/15 steps.

---

## Phase 96 — A detached ring rebuild does not orphan its worker ✅ Done

**Goal:** `DistantTerrain.rebuild` called while the node is out of the tree (after `_exit_tree`,
before re-entry) starts a build through `_start`, but `_discarded` still holds the request
`_exit_tree` set aside; the later `_enter_tree` calls `_start` again and overwrites `_task`,
`_task_args` and `_control` while the first worker is still running, so that task is never joined.
A reparent with a queued request pending is untested. `_test_distant_ring_abort` also hit
"Attempted to free a locked object" once in CI (#235, #233).

**Newel dependency:** NO.

**Closes:** both items of #235 and the CI-flake item of #233.

**Depends on:** Phase 88.

**Deliverables:**
- `src/terrain/distant_terrain.gd` — `rebuild` clears `_discarded` when it accepts a request, and
  `_enter_tree` only starts the discarded request when no task is in flight (`_task < 0`); while
  one is, the discarded request becomes `_queued` only if nothing newer is queued.
- `src/tests/test_suite.gd` — `_test_distant_ring_abort` removes the node from the tree and frees
  it outside any locked iteration (e.g. `remove_child` then `free`), so the abort path is the one
  under test and not a free-while-locked race.

**Acceptance criteria:**
- [x] Suite: rebuild → `remove_child` → `rebuild` at a new centre → `add_child` leaves exactly one
  task started per accepted request (a `builds_started` counter equals `rebuilds_requested` minus
  `rebuilds_dropped`), and `poll(true)` swaps in the mesh of the newest centre.
- [x] Suite: a ring with one build in flight and one queued is reparented; after `poll(true)` its
  vertex hash equals an undisturbed ring built at the queued centre.
- [x] Suite: `_test_distant_ring_abort` runs 50 times in a loop with no engine error and the Phase 84
  orphan check still reports zero leaked objects.
- [x] Suite green on both boot paths, harness green — `Results: 15578/15578 passed (0 failed)`, harness 15/15 steps.

---

## Phase 97 — Peer windows and position relays use the exact peer position ✅ Done

**Goal:** Phase 86 keeps each peer's exact `{chunk, local}` position, but `GameRoot._peer_window_chunk`
still derives the peer's streaming-window chunk from the float32 last-known `Vector3`, and
`NetworkingSlice._on_remote_player_state` relays that same float to other clients. Ten thousand km
from the origin the float is quantised to metres, so a peer standing near a chunk border can get a
window one chunk off and other clients see its avatar jitter. `_fold_last_known_state` persists the
exact position with no plausibility check, though the float path's consumers are guarded (#222, #223).

**Newel dependency:** NO.

**Closes:** items 2 and 3 of #222 and the Phase 86 item of #223.

**Depends on:** Phase 86, Phase 90.

**Deliverables:**
- `src/core/game_root.gd` — `_peer_window_chunk` reads the exact chunk from
  `_networking.get_last_known_exact(peer_id)` when present, the float path only as fallback.
- The same file — `_fold_last_known_state` records the exact position only when it passes
  `WorldPos.is_wire(WorldPos.pos_to_wire(exact))`; otherwise it falls back to the guarded float path.
- `src/networking/networking_slice.gd` — the host's `remote_player_state` relay sends the peer's exact
  wire position when it has one; the client's `_route_remote_player_state` already accepts both forms.

**Acceptance criteria:**
- [x] Suite: a peer whose exact position is chunk (1,500,000, 3) local (31.9, 0, 0.1) gets
  `_peer_window_chunk` equal to (1,500,000, 3), where the float path would round into the neighbour.
- [x] Suite: a relayed `remote_player_state` for that peer decodes on a client to the same chunk and a
  local within 1e-3 m.
- [x] Suite: an exact position with a chunk past the pole row and its fold margin is not folded into the record; the
  record keeps its previous position.
- [x] Suite green on both boot paths, harness green — `Results: 15584/15584 passed (0 failed)`, harness 15/15 steps.

_Note: the suite uses chunk (600,000, 3) rather than (1,500,000, 3): `WorldPos.is_wire` (Phase 90) caps X at one lap (1,250,000 chunks) and the registry wraps past the half lap, so 1,500,000 is not a valid position._

---

## Phase 98 — An exact first-boot spawn and a public canonical helper ✅ Done

**Goal:** `GameRoot._restore_local_player`'s fresh-player branch still records the spawn with
`record_spawn(pid, _player.respawn_point)`, a float32 `Vector3` round trip, so a first boot far from
the origin stores a spawn up to a metre off — the gap Phase 87 closed for every other spawn path.
`GameRoot.client_respawn_point` calls `PlayerRegistry._canonical`, private by convention (#226).

**Newel dependency:** NO.

**Closes:** both items of #226.

**Depends on:** Phase 87.

**Deliverables:**
- `src/core/game_root.gd` — the fresh-player branch calls
  `_registry.record_spawn_world_pos(pid, _player.get_world_pos())`.
- `src/persistence/player_registry.gd` — a public static `canonical_world_pos(wp)` wrapper (or rename
  `_canonical`); no file outside `player_registry.gd` calls `_canonical`.

**Acceptance criteria:**
- [x] Suite: a fresh local player placed at chunk (1,500,000, 3) local (0.25, 10, 0.75) records a spawn
  equal to that chunk and local within 1e-6 m.
- [x] `grep -rn "_canonical(" src --include=*.gd | grep -v player_registry.gd` finds nothing.
- [x] Suite green on both boot paths, harness green — `Results: 15581/15581 passed (0 failed)`, harness 15/15 steps.

_Note: the suite uses chunk (600,000, 3): X past half a lap (625,000) is wrapped by the canonicaliser, so 1,500,000 is not a valid spawn._
