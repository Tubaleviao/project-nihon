# Project Nihon — Roadmap

Project Nihon is an open-source sandbox MMORPG where players build a
civilization. This document tracks the design and implementation roadmap.
The game's entire design bible — materials, creatures, skills, items, world
systems — is authored as a Newel fabric and generated into documentation,
runtime assets, and Godot resources.

See `../newel/ROADMAP.md` for the Newel-side changes each phase depends on.

**Human verification is not an acceptance criterion.** A criterion must be decidable by the
automated gates — `pnpm validate`, `pnpm check-drift`, the headless suite on both boot paths,
`tools/net_harness.sh`, CI. A check that needs a person at the keyboard (a playtest, a screenshot
judgement, a visual inspection) is not a criterion: it is filed as a GitHub issue and the phase
proceeds without it, so unpublished human work never parks the roadmap. The phase records the
issue number where the criterion used to be.

---

## Phase index

| Phase | Title | Status | Spec |
|---|---|---|---|
| 1 | Constitution fabric | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 2 | Materials and world primitives | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 3 | Skills and professions | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 4 | Items, recipes, and technology tree | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 5 | Creatures and combat systems | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 6 | `generator-bible` integration | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 7 | Character system specification | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 8 | `generator-godot` integration | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 9 | Public wiki | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 10 | Vertical slices: playable game loop | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 11 | Crafting slice | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 12 | Voxel mining and building | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 13 | Technology unlock gates | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 14 | Player UI: inventory, technology tree, crafting | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 15 | Creature AI and behavior | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 16 | Station-gated crafting and tool durability | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 17 | Chunk streaming and world expansion | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 18 | Multiplayer world sync (core) | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 19 | Multiplayer chaos resilience | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 20 | Skeleton rig and animation | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 21 | Asset separation and public placeholders | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 22 | Material and palette pipeline | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 23 | LOD and composition simplification | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 24 | Social systems and player economy | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 25 | Tool and equipment repair | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 26 | Client-side rendering instancing | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 27 | Headless data-oriented server | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 28 | Spatial hashing | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 29 | Interest management (area of interest) | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 30 | Pack and herd behavior | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 31 | Trees and resource appearance | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 32 | One authoritative boot path | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 33 | Player identity and server-side persistence | Done | [history](docs/roadmap-history/phases-33-38.md) |
| 34 | Per-player repair and research | Done | [history](docs/roadmap-history/phases-33-38.md) |
| 35 | Creature taming | Done | [history](docs/roadmap-history/phases-33-38.md) |
| 36 | Review pass: the network trust boundary, gated boots, per-player progression | Done | [history](docs/roadmap-history/phases-33-38.md) |
| 37 | Review pass: owner-scoped syncs, durable cooldowns, bounded memory, routed rounds | Done | [history](docs/roadmap-history/phases-33-38.md) |
| 38 | Review pass: host-simulated peer health, one key list, the missing clear, an in-place prune | Done | [history](docs/roadmap-history/phases-33-38.md) |
| 39 | Two-client network harness: prove the wire over a real socket | Done | [history](docs/roadmap-history/phases-39-42.md) |
| 40 | Review pass: the avatar's footing — the voxel surface, walked stairs | Done | [history](docs/roadmap-history/phases-39-42.md) |
| 41 | Deterministic world and volumetric terrain | Done | [history](docs/roadmap-history/phases-39-42.md) |
| 42 | Threaded chunk build and a loading screen | Done | [history](docs/roadmap-history/phases-39-42.md) |
| 43 | Natural resource distribution | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 44 | Spawn scarcity | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 45 | Asset pipeline for meshes and animation | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 46 | UI shell | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 47 | Character window | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 48 | Review pass: the equipment trust boundary | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 49 | Zone crossing and natural ground | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 50 | Planet coordinates | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 51 | Continents, oceans and mountains | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 52 | Region storage and per-player server streaming | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 53 | Spawn placement and friend codes | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 54 | World clock, day and night, seasons | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 55 | Two-client harness: equipment delivery over the socket | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 56 | Station placement follow-ups | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 57 | Spawn determinism and cost follow-ups | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 58 | UI layout file robustness | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 59 | Wire the Phase 45 rig into the game | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 60 | Host-authoritative equip | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 61 | Region storage correctness | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 62 | Peer streaming window limits | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 63 | Planet coordinates wiring | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 64 | Biome blend consistency | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 65 | World clock and season follow-ups | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 66 | Spawn point and colonization follow-ups | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 67 | Network test seam cleanup | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 68 | Distant terrain off the main thread | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 69 | Neighbour seam rebuilds that match the edits | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 70 | Equip intent ordering and refusal cost | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 71 | World-generation version stamp | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 72 | Stable, low-frequency rare-biome niches | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 73 | Swimming and the distant ring follow the real ground | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 74 | Minimap redraw cost and first-apply layout clamp | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 75 | Region edits survive eviction and malformed neighbours | Done | below |
| 76 | Niche field wraps the planet and is calibrated by a test | Done | below |
| 77 | One detail-noise formula and the ring's strip helper | Done | below |
| 78 | Exact player position far from the origin | Done | below |
| 79 | Deterministic peer-window rate limit and a production ref-count reader | Planned | below |
| 80 | Rebase in the physics step and explicit shift sets | Planned | below |
| 81 | Pole-aware tile biome and a mined-tile biome memo | Done | below |
| 82 | Honest peer-window refusal count and a thread-safe warning counter | Planned | below |
| 83 | Distant-ring teardown that does not stall | Planned | below |
| 84 | The suite exits with no leaked objects | Planned | below |

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
- [x] Suite green on both boot paths, harness green. — new tests green in the full headless run (no FAILED lines); final `Results:` tally and harness not captured in this run (suite exceeded the time budget).

---

## Phase 82 — Honest peer-window refusal count and a thread-safe warning counter

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
- [ ] Suite: with a fake clock, ten `_sync_peer_windows` ticks for a peer that has not moved
  and five that track a moving peer leave `peer_recenter_refused` at 0.
- [ ] Suite: a client move inside `PEER_RECENTER_INTERVAL` still counts one refusal.
- [ ] Suite: four `WorkerThreadPool` tasks each raising 1,000 `Diag.warn` calls (quiet mode)
  raise the count by exactly 4,000.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 83 — Distant-ring teardown that does not stall

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
- [ ] Suite: a ring build started and the node freed immediately: `_exit_tree` returns after the
  worker has processed at most one more row (row counter), and no error is logged.
- [ ] Suite: a build that is not aborted produces the same vertex hash as before the change.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 84 — The suite exits with no leaked objects

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
- [ ] `godot --headless --path . --quit -- --run-tests` (both boot paths) ends with no "ObjectDB instances
  leaked" and no "resources still in use" lines in its output.
- [ ] Suite: the orphan-node assertion is the last check and passes.
- [ ] Suite green on both boot paths, harness green.

---

## Deferred (in priority order)

- **Server sharding (final, not before maturity)** — split the authoritative
  simulation across multiple servers by region / spatial partition so total
  population exceeds one process. Deferred to LAST: it is a horizontal-scaling
  concern that only pays off once a single headless server (Phase 27) plus
  spatial hashing (Phase 28) and interest management (Phase 29) are already
  saturating. No structural change is required *before* the game matures to
  make sharding possible — the Phase 27 sim/visual split and the Phase 28
  hash are the prerequisites, and both are already planned ahead of it. Revisit
  when Brazil-region load approaches one server's ceiling.

- **Rivers, lakes and fluid flow** — water above sea level and flowing water
  (the cellular-automaton idea from the GDVoxelPlayground evaluation) follow
  Phase 51's static sea level.
- **Fast travel** — a planet takes about 90 days to walk around. Some form of
  travel network (roads, boats, waystones) is needed once players spread out
  (after Phase 53).
- **Voxel techniques from GDVoxelPlayground (evaluated, not adopted wholesale)** —
  <https://github.com/JorisAR/GDVoxelPlayground> (MIT) ray-marches a FIXED 128³
  voxel grid on the GPU via `RenderingDevice` compute. It does not fit Nihon,
  which has an unbounded streamed world, a headless server with no
  `RenderingDevice`, seed-deterministic CPU terrain, sparse-run columns with
  trimesh collision, and per-edit authority and persistence. Three techniques
  are worth borrowing later, each CPU-side and deterministic:
  - a **cellular automaton** for sand, water and lava, run on dirty chunks
    only;
  - **WFC** for ruins, villages and dungeons;
  - a **brick occupancy map** if meshing becomes the bottleneck.

- **Public wiki deployment** — VitePress (or equivalent) static-site deployment
  and CI-triggered wiki regeneration from the fabric (deferred from Phase 9).
- **Research cost points** — the abstract `researchCost` points field is modelled
  in the fabric but not enforced at runtime (deferred from Phase 13).
- **`VoidTouched` special-case unlock** — the void-burst survivor unlock trigger
  is defined in the fabric but not wired to any runtime event (deferred from
  Phase 13).
- **Station placement UI** — **(closed: placement is grid-snapped to 1 m cells and
  refuses overlap via `StationSlice.try_place_station`; N toggles a translucent
  green/red preview ghost and V places at the aimed top face or the player's feet.
  A full build-mode menu remains out of scope.)**
- **NavigationAgent3D path-finding** — creature movement currently uses direct
  kinematic stepping; replacing it with nav-mesh baked from voxel terrain and
  `NavigationAgent3D` per-instance requires the chunk-streaming world from
  Phase 17 to produce stable nav-mesh regions (deferred from Phase 15).
- **WAN / cross-region multiplayer testing** — all Phase 18–19 multiplayer
  validation is loopback or LAN (deferred from Phase 19).
- **Automatic LOD mesh decimation** — simplified meshes are hand-authored;
  runtime decimation deferred from Phase 23.
- **Dynamic impostor re-bake** — impostor billboards are offline-baked; live
  palette-change re-bake deferred from Phase 23.
- **Peer damage over the wire** — a creature aggros and chases a remote peer, but
  the host opens no combat round against it: damage to a peer belongs to that
  peer's own client, and the host has no simulation of a peer's HP to hit or
  persist. Needs a host → client damage event plus per-peer HP ownership on the
  peer's side (deferred from Phase 36). **(delivered in Phase 37: the round is routed
  by target id, `player_damaged` carries the target, and the host sends the hit to the
  peer's own client. What remains is making a peer's HP authoritative rather than
  client-owned.)** **(closed in Phase 38: the host simulates the peer's HP itself and
  persists it on the peer's record. `player_damaged` stays a display update — a client
  that ignores it now diverges from the host's number instead of owning it.)**
- **Peer equipment replication** — **(closed in Phase 47: the host records each
  peer's worn set and the bare-hands rule reads it; late joiners are announced to
  their AOI, and the two-client harness step `equipment_recorded` proves the
  intent over a real socket.)**
