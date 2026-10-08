# Roadmap history — Phases 60–74

Completed phases, archived unchanged from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 60 — Host-authoritative equip ✅ Done

**Goal:** close the one hole Phase 48 left open: a client reported a whole worn set, so a
modified client could report `worn = {}` while holding a weapon and pass the bare-hands taming
rule (#88, with #63-#65 and #70). The host must decide what is in the hand.

**Newel dependency:** NO.

**Closes:** #88, #63, #64, #65, #70, #71 (with Phase 55) and the minimap/station notes in #107 and #68.

**Deliverables:**
- `src/core/bus.gd` — `equip_intent(player_id, slot, item_key)` replaces `equipment_intent`
  (`item_key` "" unequips). A client emits one action per differing slot; there is no whole-set
  report, so there is nothing to leave gear out of.
- `src/persistence/player_registry.gd` — `_on_equip_intent` validates the action (the fabric
  says the item fits the slot, the player's bag holds it) and changes ONE slot of the host's
  own record through `record_equipment`; a refused action sends the owner the authoritative set
  (`equipment_revoked`) so its optimistic avatar falls back. `has_equipment_report` is gone:
  the record is always the truth, a peer with an empty record is bare-handed.
- `src/networking/networking_slice.gd` — the `equip_intent` packet carries `{slot, item}`;
  the join-time equipment send skips pairs already sent (a join-intent retry no longer repeats it).
- `src/core/game_root.gd` — a client shows exactly the host's record on join (an empty one
  strips recipe gear the host never granted) and diffs its avatar into actions
  (`EquipmentRules.diff_actions`).
- `tame_intent` lost its dead `unarmed` argument; `ui_slice` lost a redundant refresh and an
  anonymous lambda; `Minimap.biome_color` caches per biome.

**Acceptance criteria:**
- [x] A wrong-slot item, an unknown item, an unknown slot and an unowned item change nothing;
  an unequip clears only its slot (suite).
- [x] A refused equip tells the owner the host's set (suite).
- [x] A bare-handed record reads as unarmed and a recorded sword as armed, with no payload
  claim on the wire (suite).
- [x] `net-harness` still reports every step agreed, `equipment_recorded` driving the new
  actions over a real socket.

---

## Phase 61 — Region storage correctness ✅ Done

**Goal:** Close the Medium items left open by the Phase 52 review passes (#143, #144, #145,
#146): an evicted chunk must not resurrect a vein, one bad region file must not stop the whole
save, and a failed region read must not be marked resident.

**Newel dependency:** NO.

**Closes:** the persistence/eviction items of #144 and #146 (items 1, 2, 3, 6), #143 item 2.

**Deliverables:**
- `src/terrain/voxel_slice.gd` — `evict_clean_chunks` keeps vein depletion totals for veins
  that still have a resident tile: `_vein_taken` is no longer rebuilt only from resident edits,
  or a released chunk's deplete ops are retained in a per-vein carry table until the vein has no
  resident tile and its region is on disk. `edited_chunk_keys()` is built once per `sync`.
- `src/persistence/persistence_slice.gd` — a failing `region_store.write_chunks` no longer
  returns before `world.json` and player records are written; every region that can be saved is
  saved, and the first error is returned after the rest of the save completes.
- `src/persistence/region_streamer.gd` — `sync()` uses the status-returning region read; a
  region whose read fails is not marked resident and is retried on the next sync.
- `src/persistence/region_store.gd` — `read_region` validates `edits` (Dictionary of Arrays)
  and `materials` types per chunk entry; a malformed chunk entry is skipped with one warning.
- `src/core/game_root.gd` — legacy (pre-Phase-41) chunks from a failed migration are applied
  after the world seed is restored, not before.

**Acceptance criteria:**
- [x] Suite: a vein spanning two chunks, depleted from a tile in chunk A, stays depleted in
  chunk B after A is evicted (`OreField.is_live` false), and after A is re-read.
- [x] Suite: with one region file made unreadable, a save still writes the other regions,
  `world.json` and player records, and returns a non-OK status.
- [x] Suite: a region whose read fails is absent from the resident set and is read again on the
  next `sync`.
- [x] Suite: a region file whose chunk carries `edits: 5` or `materials: "x"` loads the other
  chunks and logs one warning.
- [x] Suite green on both boot paths; `tools/net_harness.sh` agrees on every step.

---

## Phase 62 — Peer streaming window limits ✅ Done

**Goal:** A peer's streaming window follows the position its client reports, with no bound
on distance or rate (#143 item 1, #145, #146 items 4, 5, 10). A modified client can make the
host read regions and build chunks on the main thread as fast as it can send packets. Bound
it, and fix the snapshot ordering on a teleport.

**Newel dependency:** NO.

**Closes:** #143 item 1, #146 items 4, 5 and 10, the matching lines of #144 and #145.

**Deliverables:**
- `src/terrain/chunk_manager.gd` — `set_peer_center` rate-limits recentring per peer (at most one
  move per `PEER_RECENTER_INTERVAL`) and caps how far a window may move per accepted update
  unless the host itself moved the peer (respawn, spawn placement). Rejected moves are counted
  (`peer_recenter_refused`).
- `src/core/game_root.gd` — `_on_remote_player_state` re-centres the peer window and refreshes
  regions BEFORE building the AOI re-scope snapshot, as the join path already does.
  `_sync_peer_windows` iterates the peer map instead of a per-player linear lookup.
- `src/terrain/chunk_manager.gd` — `_chunk_refs` is either read by production code or removed.

**Acceptance criteria:**
- [x] Suite: a peer reporting 100 positions 10 km apart within one interval moves its window at
  most once, and the refusal counter rises.
- [x] Suite: a host-driven respawn far away recentres the window immediately.
- [x] Suite: after a teleport into a region with stored edits, the re-scope snapshot carries
  those edits.
- [x] Suite green on both boot paths; `tools/net_harness.sh` agrees on every step.

---

## Phase 63 — Planet coordinates wiring ✅ Done

**Goal:** Phase 50 passed its criteria with wiring still open (#136, also #120–#127). Finish the
parts a headless suite can prove: canonical chunk keys at the east-west seam, `{chunk, local}`
on the wire, and the client rebase driver.

**Newel dependency:** NO.

**Closes:** #136 and the duplicate remainder issues #120, #121, #122, #123, #124, #125, #126,
#127 (except the manual far walk, #134).

**Deliverables:**
- `ChunkManager` and `VoxelSlice` key chunks through `TerrainSlice.wrap_chunk`, so chunk
  `(C/2, z)` and `(-C/2, z)` are one key; the player's X wraps when it crosses the seam.
- The join snapshot, edit RPCs, AOI centres, creature and station positions carry
  `{chunk, local}` (the `WorldPos` form player records already use); old float payloads are still
  accepted on read.
- A client-side driver calls `VoxelSlice.shift_scene` and shifts trees, creatures, stations and the
  player body in the same frame when `WorldPos.needs_rebase` fires.
- Terrain noise sampled from chunk-relative coordinates (integer lattice plus local offset), so
  heights at chunk 312,500 match the shape at the origin to the 0.125 m step.
- A `/where` chat command printing `TerrainSlice.where_text`.

**Acceptance criteria:**
- [x] Suite: an edit made at chunk `(C/2, z)` is found when reading chunk `(-C/2, z)`.
- [x] Suite: after a forced rebase, the player, one tree, one creature and one station keep their
  `{chunk, local}`, and their scene positions shift by the same offset.
- [x] Suite: heights sampled in a chunk at index 312,500 quantise to 0.125 m steps with no
  terracing (no two adjacent samples differ by a float32 rounding artefact).
- [x] `tools/net_harness.sh` agrees on every step with `{chunk, local}` on the wire.
- [x] Suite green on both boot paths.

---

## Phase 64 — Biome blend consistency ✅ Done

**Goal:** The 4-tile biome dither band shows one biome and yields another, the minimap leaks
unexplored biomes across fog, and the dither hash exists twice with different thresholds
(#113–#118).

**Newel dependency:** NO.

**Closes:** the biome-blend items of #113, #114, #115, #116, #117, #118.

**Deliverables:**
- One shared dither helper (in `ClimateField` or a new `BiomeBlend`) used by
  `VoxelSlice.blended_biome` and `minimap.gd`, with one falloff rule.
- `voxel_slice.gd` `_natural_yield` uses the blended biome of the tile, so the yield matches the
  surface drawn; `topsoilDepth` reads are null-guarded.
- `minimap.gd` border dither only borrows a neighbour's colour when that neighbour is revealed and
  inside the world; a chunk whose neighbours share its biome draws one rect.
- `climate_field.gd` — `biome_for_chunk` never calls `warm()` lazily from a worker; warming is
  explicit on the main thread with a `_warmed` flag; `_envelope_of` tolerates partial envelopes;
  the header describes the envelope model.
- `ore_field.gd` — the biome lookup moves after the cheap surface-vein hash cull.

**Acceptance criteria:**
- [x] Suite: for every tile in a border band, the biome used for yield equals the biome used for
  the surface style.
- [x] Suite: the minimap colour of a revealed border cell next to an unrevealed chunk never uses
  the unrevealed chunk's biome.
- [x] Suite: a partial envelope dict does not error in `warm()` and the other envelopes load.
- [x] Suite green on both boot paths.

---

## Phase 65 — World clock and season follow-ups ✅ Done

**Goal:** Phase 54 shipped `WorldClock.biome_daylight` with no runtime caller, and the season
tint repaints every loaded chunk with the biome underfoot (#150).

**Newel dependency:** NO.

**Closes:** #150 items 1 and 2.

**Deliverables:**
- `src/core/game_root.gd` — `_apply_sun` passes the daylight through `WorldClock.biome_daylight`
  with the `dayNightSpeed` of the biome the player is in (TwilightGrove stays at dusk).
- Season tint applied per chunk (per-chunk material override or vertex colour from the chunk's
  own biome), so a freezing biome turns its own chunks white and not its neighbours.

**Acceptance criteria:**
- [x] Suite: with the player in a biome whose `dayNightSpeed` is 0, the applied sun energy equals
  `biome_daylight(d, 0)` at midnight and noon.
- [x] Suite: with the player in a freezing biome, a loaded chunk of a temperate biome keeps its
  non-snow tint.
- [x] Suite green on both boot paths.

---

## Phase 66 — Spawn point and colonization follow-ups ✅ Done

**Goal:** A returning player respawns at the legacy (16, y, 16) default instead of their own
spawn point, and the colonization map over-counts after a restart (#148).

**Newel dependency:** NO.

**Closes:** #148 items 1 and 2.

**Deliverables:**
- `src/persistence/player_registry.gd` — the player record stores the original spawn point
  (`{chunk, local}`) at placement; `game_root` restores `respawn_point` from it for a returning
  host and client. Records without the field fall back to the saved position.
- `src/world/colonization_map.gd` — `to_data`/`from_data` persist the counted-chunk set (or a
  per-region counted list), so re-editing an already-counted chunk after a restart does not
  raise its region's count.

**Acceptance criteria:**
- [x] Suite: a host placed at spawn S, moved away and reloaded respawns at S.
- [x] Suite: a client reconnecting after moving away respawns at its original spawn point.
- [x] Suite: edit chunk K, save, reload, edit K again — the region's edit count is unchanged.
- [x] Suite green on both boot paths.

---

## Phase 67 — Network test seam cleanup ✅ Done

**Goal:** `NetworkingSlice` broadcasts still call `multiplayer.get_peers()` directly, so the
`_test_peers` seam is bypassed on two paths, and the seam can be set outside the suite
(#153, #155).

**Newel dependency:** NO.

**Closes:** #153 and #155 (the code items).

**Deliverables:**
- `src/networking/networking_slice.gd` — `_broadcast_aoi` and `_broadcast` go through
  `_connected_peers()`; setting `_test_peers`/`_test_outbox` outside a `--run-tests` boot asserts
  and is ignored.
- `src/tests/test_suite.gd` — `_test_equipment_host_and_aoi_transitions` comment rewritten, and
  its evict assertion names which viewers receive the evicts.
- `UiSlice._save_layout` removes the `.tmp` file when the rename fails; the `?` hotkey matches
  on unicode only (#129).

**Acceptance criteria:**
- [x] `grep -n "multiplayer.get_peers()" src/networking/networking_slice.gd` matches only inside
  `_connected_peers`.
- [x] Suite: a broadcast with `_test_peers` set reaches exactly those peers through both
  `_broadcast` and `_broadcast_aoi`.
- [x] Suite: a failed layout rename leaves no `.tmp` file.
- [x] Suite green on both boot paths — `Results: 14058/14058 passed (0 failed)`, harness 15/15 steps.

---

## Phase 68 — Distant terrain off the main thread ✅ Done

**Goal:** `DistantTerrain.rebuild` evaluates a 65×65 lattice on the main thread every time the
player crosses a ring cell, and the terrain corner cache is unsynchronised shared state
(#139, #140, #141, #145).

**Newel dependency:** NO.

**Closes:** the distant-terrain and corner-cache items of #139, #140, #141, #145.

**Deliverables:**
- `src/terrain/distant_terrain.gd` — the lattice build runs on `WorkerThreadPool`; the main
  thread only swaps in the finished mesh. The per-frame string key in `_process` becomes cached
  integer fields.
- `src/terrain/terrain_slice.gd` — the `_shape_at` corner cache is per-thread (or replaced by a
  pure function), keyed on seed and width.
- `WorldShape.SPAWN_CENTER`/`SPAWN_HEIGHT` reference the `TerrainSlice` constants instead of
  duplicating them. (Audit: `TerrainSlice` holds no copy of either; they live only in `WorldShape`
  and nothing else duplicates them, so there is nothing to change.)

**Acceptance criteria:**
- [x] Suite: `rebuild` returns without building the mesh synchronously (a counter of main-thread
  lattice evaluations stays 0), and the finished mesh equals a synchronous build for the same
  centre.
- [x] Suite: heights sampled concurrently from several worker tasks equal single-threaded samples.
- [x] Suite green on both boot paths — `Results: 13968/13968 passed (0 failed)` with `[Server] listening on port 7777` on the server boot.

---

## Phase 69 — Neighbour seam rebuilds that match the edits ✅ Done

**Goal:** `ChunkManager._rebuild_guessing_neighbours` runs only when an edited chunk enters the
streamed set, and then rebuilds all 8 built neighbours even when no edit touches a border or the
only edits are vein depletions that never change a height. A client whose edits arrive by network
sync after the chunk loaded never rebuilds the neighbours, so their seams keep the generated
guess (#113, #114, #115, #116, #118).

**Newel dependency:** NO.

**Closes:** the `_rebuild_guessing_neighbours` items of #113, #114, #115, #116 and #118.

**Deliverables:**
- `src/terrain/voxel_slice.gd` — a helper reports, per chunk, which borders carry a
  height-changing edit within one tile of the edge (deplete-only ops do not count).
- `src/terrain/chunk_manager.gd` — `_rebuild_guessing_neighbours` rebuilds only the built
  neighbours across those borders (plus the diagonal at a corner edit), at most once per chunk
  per edit revision.
- The same rebuild runs when edits for an already-loaded chunk arrive later (the client sync
  path through `apply_edits` / `_commit_edits`), not only at `load_chunk`.

**Acceptance criteria:**
- [x] Suite: a chunk whose only edits are vein-deplete ops streams in with zero neighbour
  rebuilds requested.
- [x] Suite: a chunk with one height edit on its east border streams in and requests a rebuild
  of the east neighbour only.
- [x] Suite: edits applied through `apply_edits` to an already-loaded chunk with a built
  neighbour across the edited border request that neighbour's rebuild.
- [x] Suite green on both boot paths — `Results: 13966/13966 passed (0 failed)` with `[Server] listening on port 7777` on the server boot.

---

## Phase 70 — Equip intent ordering and refusal cost ✅ Done

**Goal:** Phase 60 made the host the author of the worn set, but three paths still misbehave
(#116): `revalidate_equipment` runs after `resolve_identity` has already emitted
`player_joined`, so the handshake can carry a stale set; a refused equip revokes with the
host's current set and can wipe a later valid equip still in flight; and every refused intent
costs a `Diag.warn`, a revoke and a state send with no rate limit.

**Newel dependency:** NO.

**Closes:** the equipment items of #116.

**Deliverables:**
- `src/persistence/player_registry.gd` — the joining player's equipment is revalidated before
  `player_joined` is emitted; the comment says so truthfully.
- `equip_intent` carries a per-player sequence number; `equipment_revoked` carries the sequence
  it answers, and the client ignores a revoke older than its newest accepted action.
- Refused intents are rate-limited per player (one warn and one revoke per interval; further
  refusals in the interval are counted in `equip_refused_suppressed`).

**Acceptance criteria:**
- [x] Suite: a returning player whose bag no longer holds a worn item joins with that slot
  already empty in the `player_joined` payload.
- [x] Suite: refused intent N followed by valid intent N+1 leaves the client showing N+1's item
  after both replies are delivered in order.
- [x] Suite: 100 refused intents in one interval produce one warn and one revoke.
- [x] Suite green on both boot paths; `tools/net_harness.sh` agrees on every step — `Results: 14009/14009 passed (0 failed)`, harness 15/15 steps.

---

## Phase 71 — World-generation version stamp ✅ Done

**Goal:** the world record has a format `version` but nothing records which generator produced
the terrain and biome layout. A save from before a generator change (Phase 49 biomes, Phase 51
continents) loads its edits and deplete records over a different layout with no warning (#114).

**Newel dependency:** NO.

**Closes:** the "no world-generation version" item of #114.

**Deliverables:**
- `src/terrain/terrain_slice.gd` — a `WORLDGEN_VERSION` constant, with a comment listing the
  phases that changed generation output.
- `src/persistence/persistence_slice.gd` — `world.json` stores `worldgenVersion`; a record
  without it reads as version 0.
- On load, a record whose `worldgenVersion` differs from the running one logs one warning
  naming both versions and surfaces it in the diagnostics overlay; the record is re-saved with
  its ORIGINAL stamp until a new world is created (the mismatch stays visible).
- `ROADMAP.md` / docs: any later phase that changes generation output bumps the constant.

**Acceptance criteria:**
- [x] Suite: a new world saves `worldgenVersion == WORLDGEN_VERSION`.
- [x] Suite: a record with no stamp, or an older stamp, loads with every edit intact and emits
  exactly one mismatch warning; re-saving keeps its original stamp.
- [x] Suite green on both boot paths — `Results: 14031/14031 passed (0 failed)`.

---

## Phase 72 — Stable, low-frequency rare-biome niches ✅ Done

**Goal:** `ClimateField.niche_value` is salted by biome INDEX, so adding or reordering a biome
re-rolls every rare biome's placement, and it is white noise per 10-chunk cell where the fabric
rarity docs promise a low-frequency field, so rare biomes appear as confetti patches. The
Voronoi fallback also hands out Ocean/Beach/Alpine when no envelopes are loaded (#139, #141,
#113, #117).

**Newel dependency:** NO.

**Closes:** the `climate_field.gd` niche, fallback and lattice items of #113, #117, #139, #141.

**Depends on:** Phase 71 (this phase changes generation output and bumps `WORLDGEN_VERSION`).

**Deliverables:**
- `src/terrain/climate_field.gd` — the niche salt is derived from a hash of the biome KEY;
  `niche_value` samples smooth value noise (several niche cells per feature) instead of one
  hash per cell, keeping each rare biome's covered share equal to its `rarity` within tolerance.
- The Voronoi fallback picks only from the original land biomes.
- The lattice draw uses one modulus/divisor pair (`% 10000 / 10000.0` or equivalent) everywhere;
  `temperature_at` computes the latitude term once; the unused `temperature()` and
  `biome_for_climate` either gain a production caller or move into the suite.
- `WORLDGEN_VERSION` bumped.

**Acceptance criteria:**
- [x] Suite: inserting a dummy biome into the key list leaves every other rare biome's niche
  value unchanged at 1,000 sampled chunks.
- [x] Suite: over a 400×400-chunk sample, each rare biome's niche covers its `rarity` share
  ±20 %, and the mean run length along a row exceeds one niche cell.
- [x] Suite: with no envelopes loaded, the fallback never returns Ocean, Beach or Alpine.
- [x] Suite green on both boot paths — `Results: 14672/14672 passed (0 failed)`, harness 15/15 steps.

---

## Phase 73 — Swimming and the distant ring follow the real ground ✅ Done

**Goal:** `PlayerSlice._swimming_now` reads the natural heightmap, so ground a player built up
out of the sea still counts as water and a pit dug below sea level on land does not; and the
distant ring draws its overlap with the voxel window as an opaque sheet at max(h, sea) − 1 m,
up to 6 m below the voxel ground, hiding the shallow sea near the window edge (#139, #140,
#141).

**Newel dependency:** NO.

**Closes:** the swimming and ring-overlap items of #139, #140, #141.

**Deliverables:**
- `src/player/player_slice.gd` — `_swimming_now` takes the column top from
  `VoxelSlice.get_column_runs_at` (edits included) when the voxel slice is wired, falling back to
  the generated height in an isolated rig.
- `src/terrain/distant_terrain.gd` — the ring does not emit faces inside the loaded voxel window
  (a hole matching `window_half_m`, with a skirt dropping below the voxel ground at the edge),
  and its land heights include the same detail noise the voxel ground uses, or the gap is
  bounded and documented.

**Acceptance criteria:**
- [x] Suite: a body standing on an ocean column the player filled up to sea level + 1 m does
  not swim; a body in a land pit dug below sea level with no water does not swim.
- [x] Suite: no vertex of the ring mesh lies strictly inside the voxel window rectangle.
- [x] Suite: at 64 sampled points on the window edge, the ring height is within 1 m of the
  voxel-ground height.
- [x] Suite green on both boot paths — `Results: 34629/34629 passed (0 failed)`, harness 15/15 steps.

---

## Phase 74 — Minimap redraw cost and first-apply layout clamp ✅ Done

**Goal:** the minimap recomputes every chunk's biome (a `WorldShape.height` evaluation each) on
every redraw because the memo lives for one draw, and at `ZOOM_MAX` it issues ~14 `draw_rect`
calls per chunk even when a sub-cell is smaller than a pixel. Separately, `UiSlice._apply_layout`
clamps panels with `custom_minimum_size.max(size)` before the first layout pass, so a saved
position off-screen is only fixed on a later re-apply (#116, #117, #129, #140).

**Newel dependency:** NO.

**Closes:** the minimap cost items of #116, #117, #140 and the `_apply_layout` item of #129.

**Depends on:** Phase 64 (shared dither helper) for the border-cell code it touches.

**Deliverables:**
- `src/ui/minimap.gd` — a persistent, bounded (LRU or region-pruned) chunk → biome cache keyed
  on world seed; cleared when the seed or `GameData.BIOMES` changes, as is `_biome_color_cache`.
- When a sub-cell would be under 2 px, the chunk draws as one rect.
- `src/ui/ui_slice.gd` — `_apply_layout` re-clamps once after the panels' first layout
  (deferred call or `resized`), so a saved position past the viewport edge lands inside on the
  first frame it is visible.

**Acceptance criteria:**
- [x] Suite: two consecutive redraws of the same view call the biome lookup zero times on the
  second.
- [x] Suite: at a zoom where cells are under 2 px, the draw issues one rect per revealed chunk.
- [x] Suite: a layout entry at x = 10,000 places the panel fully inside an 800×600 viewport
  after the first apply plus one frame.
- [x] Suite green on both boot paths — `Results: 34640/34640 passed (0 failed)`, harness 15/15 steps.
