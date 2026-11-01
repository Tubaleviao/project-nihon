extends Node
## Voxel slice — builds a visible, walkable terrain mesh from chunk heightmaps,
## and exposes an edit API for mining (carve a solid span → material) and
## building (add a solid span → consume material).
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : chunk_ready(chunk_pos, heightmap)
##         block_mine_requested(position, normal, player_id)
##         block_place_requested(position, normal, player_id, material)
##         block_cycle_material_requested()
##   OUT : block_mined(material, quantity, position)
##         block_placed(material, position)
##         block_place_material_changed(material)
##         inventory_synced(owner_id, contents, durabilities) — a REMOTE actor's
##           pack after an edit resolved for it (see `_push_inventory`)
##
## Public API:
##   build_chunk(chunk_pos, heightmap) -> void
##   mine_block(world_pos, normal, player_id)  -> Dictionary  { success, material, quantity, position, player_id }
##   place_block(world_pos, normal, material, player_id) -> bool
##   inventory_for(player_id)          -> Node       (the actor's own pack)
##   get_voxel_height_at(world_pos)    -> float      (the column's TOP, not the
##                                                   footing read — see the method)
##   sample_support_height_at(world_pos, from_y) -> float
##   get_column_runs_at(world_xz)      -> Array      (the column's solid runs)
##   collision_faces(chunk_pos, heightmap) -> PackedVector3Array
##   get_edits()                          -> Dictionary
##   apply_edits(edits, materials)        -> void
##   VoxelRuns.legacy_edit_ops(height, base_top, materials) -> Array   (static, pure)
##   VoxelRuns.runs_topping_at(runs, y)             -> Dictionary       (static, pure)
##   set_place_material / get_place_material / cycle_place_material
##   material_for_biome(biome, world_xz, depth, seed, depleted, veins) -> String
##   material_at(world_xz, depth)           -> String   (the ore field, this world)
##   vein_deposits(chunk_pos, heightmap, cache) -> Array   (raised markers on live veins)
##   get_vein_depletion()                 -> Dictionary  (vein id → units taken)
##   build_chunk_arrays(chunk_pos, heightmap, resolved) -> Dictionary  (PURE, worker-safe;
##     `resolved` is the `{ runs, deposits }` pair from `collect_build_runs`)
##   collect_build_runs(chunk_pos, heightmap) -> Dictionary  ({ runs, deposits })
##   chunk_revision(chunk_pos)                    -> int
##
## Phase 41 — a column is a SPARSE list of solid RUNS, bottom → top, not one top
## ordinate:
##
##   [{ "bottom": float, "top": float, "material": String }]
##
## `material` is "" for natural ground (tinted by the ore field — `OreField`, Phase 43) and
## the placed block's key for a player-placed span. A plain column is ONE run from
## BEDROCK_DEPTH up to its quantised surface; a tunnel is two — a floor and a roof
## — so a column can finally describe a CEILING. Only solid spans are stored, so a
## deep world costs nothing until a player actually digs: a column surfaced at 2.0
## over bedrock at -8.0 is one entry, not eighty.
##
## The mesher emits a face wherever a column's solidity differs from its
## neighbour's at some Y — including DOWNWARD, under a run whose span below is
## empty, which is the mirror of "a face exists where a neighbour is lower" and is
## what makes a tunnel roof an ordinary rendered surface rather than a hole.
## `cull_mode = CULL_DISABLED` stays, so the shell is never see-through whichever
## way a face winds. The collision is ONE `ConcavePolygonShape3D` per chunk built
## from the very triangles the mesher emits, so ceilings and overhangs collide;
## the per-row merged boxes it replaces could not describe a span of solid
## material at all.
##
## Edits are TYPED RUN EDITS appended to the tile's op list (bottom → top order of
## application), keyed by global tile coordinate, so they survive chunk rebuilds
## and save/load:
##
##   { "op": "remove", "bottom": float, "top": float }
##   { "op": "add", "bottom": float, "top": float, "material": String }
##   { "op": <LEGACY_OP>, "height": float } (Phase 91, `RegionStore.LEGACY_OP`: a bare pre-Phase-41
##       height carried through a depletion overlay; migrated on load. Older builds ignore it on load.)
##   (any other kind is IGNORED on load and on replay — see `_normalise_ops`)
##
## Mining a roof therefore does not touch the floor: each edit names the span it
## acted on, and resolving a column re-plays them over the tile's natural run. A
## pre-Phase-41 save stored a bare absolute height per tile; that shape still
## loads (see `legacy_edit_ops`) and is migrated to the same typed edits.
##
## Phase 42 — the build is a PURE FUNCTION of data the main thread hands it, so it
## can run on a `WorkerThreadPool` task. `gather_build_input()` is the main-thread
## half (it copies `_edits`, the ring's `_heightmaps` and the terrain slice's biome lookup into a
## plain payload), `build_runs()` is the worker half's RESOLVE (it reads only its three arguments
## — the payload included — and returns the `{ runs, deposits }` table), `build_chunk_arrays()` is
## the worker half's BUILD (plain arrays), and `build_chunk()` is the consumer that attaches the
## nodes. `collect_build_runs()` remains the synchronous convenience wrapper: gather + resolve.
## Phase 42 review pass 9 moved the resolve itself off the main thread — it was ~43 ms per
## dispatch there, against a 16.7 ms frame.
## Scene-tree mutation, resource saving and `GameBus` emission are all main-thread work
## in Godot, so the split is not a style choice — it is the only shape that is legal off
## the main thread, and the builder must never be given a slice reference to "help".
##
## The same pass GREEDY-MERGES the quads: coplanar faces of the same colour that
## are adjacent in the tile grid collapse into one rectangle (`_merge_rects`), so a
## chunk whose surface is largely uniform emits a handful of large quads instead of
## one per tile. That is what makes building on another thread affordable in the
## first place, and the merge key — material/colour — is exactly the attribute a
## merged quad has to share.
const Diag := preload("res://src/core/diag.gd")

## Shared box authoring for the vein deposits (Phase 31).
const MeshUtil := preload("res://src/core/mesh_util.gd")
## Phase 43 — the deterministic ore field: veins, their depth band and ley gate.
const OreField := preload("res://src/terrain/ore_field.gd")
const NativeBuilder := preload("res://src/terrain/native_builder.gd")
const BiomeBlend := preload("res://src/terrain/biome_blend.gd")
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const WorldShape := preload("res://src/terrain/world_shape.gd")
const SeamWrap := preload("res://src/terrain/seam_wrap.gd")
const Settle := preload("res://src/terrain/settle.gd")
const VoxelPersist := preload("res://src/terrain/voxel_persist.gd")
const VoxelEdit := preload("res://src/terrain/voxel_edit.gd")
const VoxelBuild := preload("res://src/terrain/voxel_build.gd")
const VoxelQuery := preload("res://src/terrain/voxel_query.gd")
const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")
const VoxelMesh := preload("res://src/terrain/voxel_mesh.gd")
const VoxelRuns := preload("res://src/terrain/voxel_runs.gd")
const RegionStore := preload("res://src/persistence/region_store.gd")

## CHUNK_SIZE is defined once on TerrainSlice and accessed via terrain_slice.CHUNK_SIZE.
## The local alias below keeps internal uses readable without duplicating the value.
const CHUNK_SIZE := VoxelConsts.CHUNK_SIZE
const TILE_SIZE := VoxelConsts.TILE_SIZE
const STEP_HEIGHT := VoxelConsts.STEP_HEIGHT
const BLEND_TILES := 4.0     # width of the dithered biome border band, in tiles (Phase 49)
## Phase 41 — the world's FLOOR. It replaces the old `MIN_HEIGHT := 0.0`, which was
## "bedrock" only in the sense that mining stopped at zero: the ground has real
## thickness now, so a column is solid from BEDROCK_DEPTH up to its surface, a
## tunnel has room to exist underneath it, and mining descends one STEP_HEIGHT at
## a time until the floor refuses. MAX_HEIGHT stays the build cap.
## Phase 51 — the surface now spans the fabric's −64..+512 m, so the floor sits a fixed 8 m below
## the lowest possible surface (`WorldShape` clamps heights at `minHeight`) and the build cap a
## little above the tallest peak. (A per-column bedrock that rides the surface is not needed: a
## column is one run from here up, so a deeper floor costs nothing.)
## Phase 122 — 32 m below the lowest possible surface (was 8), so even the deepest ocean column keeps
## the full authored vein depth (`depthBand` max 16) above the floor.
const BEDROCK_DEPTH := VoxelConsts.BEDROCK_DEPTH
const MAX_HEIGHT := VoxelConsts.MAX_HEIGHT

## A tile's op list is COMPACTED once it grows past this many ops (see
## `_append_edit` / `_compact_ops`). Ops are an append-only log by design, so a
## column mined and rebuilt in place would otherwise replay (and re-serialize)
## every click forever — the replay is O(ops) on every column read, which is the
## mesher, the collision soup, the footing sampler and the save manifest. Compaction
## rewrites the list as the minimal description of what the column IS, bounded by
## its run count (a tunnel is two adds and one remove), so the log is bounded too.
const MAX_TILE_OPS := 8

## Terrain collision lives on its own layer (layer 2 / bit 1) so the player's
## block ray can target terrain without hitting the player's own body.
const TERRAIN_COLLISION_LAYER := 2

## The biome a resolve falls back to when no gathered biome map has the answer and there is no
## terrain slice to ask — the same answer an unwired `_biome_at` gives (Phase 42 review pass 9).
const DEFAULT_BIOME := "TemperateForest"

## Phase 43 — biome → weighted material BIAS. It used to be `BIOME_MATERIALS`, the whole
## distribution: every tile of a biome rolled the same table, so a volcanic tile was 17/100
## Aethermite at every depth. It is now a bias over the ore field (`OreField`, where the
## authoritative copy lives): the heaviest entry is the biome's HOST rock — what a tile
## outside a live vein yields — and the rest weight the draw for a vein's material, which
## the material's fabric `depthBand` and `leyGated` then gate.
const BIOME_BIAS: Dictionary = OreField.BIOME_BIAS

## Terrain tint per material key — makes each ground material visually distinct
## (the whole terrain was previously one flat green). Keyed by the fabric
## material entity names in GameData.MATERIALS.
const MATERIAL_COLORS: Dictionary = {
	"Grass":      Color(0.31, 0.54, 0.23),  # turf green
	"Soil":       Color(0.42, 0.29, 0.18),  # earth brown
	"Ferrite":    Color(0.62, 0.62, 0.66),  # pale iron
	"Thornwood":  Color(0.45, 0.32, 0.20),  # wood brown
	"Ashite":     Color(0.28, 0.28, 0.31),  # charcoal
	"Aethermite": Color(0.25, 0.75, 0.80),  # teal
	"Duskfiber":  Color(0.55, 0.34, 0.68),  # purple
	"Lumenfite":  Color(0.92, 0.80, 0.30),  # gold
	"Voidite":    Color(0.38, 0.24, 0.50),  # deep violet
	"Veilsteel":  Color(0.30, 0.34, 0.42),  # blue-black alloy
}

## Colour used for any material without an explicit entry above.
const FALLBACK_TERRAIN_COLOR := VoxelConsts.FALLBACK_TERRAIN_COLOR

## Small raised deposit geometry: purely VISUAL — a marker on a column whose top slice
## lies inside a LIVE vein (Phase 43; it was every tile a uniform roll called rare). The
## run's height and collision are unchanged.
const VEIN_DEPOSIT_HEIGHT := 0.22
## Inset from the tile edge, so adjacent deposits never touch and the tile grid
## stays readable.
const VEIN_DEPOSIT_INSET := 0.16

var _persist := VoxelPersist.new(self)
var _edit := VoxelEdit.new(self)
var _build := VoxelBuild.new(self)
var _query := VoxelQuery.new(self)
## Active chunk containers keyed by "x,y" string.
var _chunks: Dictionary = {}
## Base heightmaps keyed by "x,y" string (the unedited noise terrain).
var _heightmaps: Dictionary = {}
## Phase 49 — generated (not built) neighbour maps, see `_generated_heightmap`.
var _guess_heightmaps: Dictionary = {}
## The world seed the cached guesses were generated under; a different seed throws them all
## away (`_sync_guess_seed`), since the same chunk now has a different surface.
var _guess_seed: int = 0

## `shown_biome_at`'s memo: chunk key -> that chunk's biome, so mining a run of tiles in one
## chunk does one terrain-slice lookup per distinct chunk. Bounded by `SHOWN_BIOME_CACHE_MAX`,
## cleared when the world seed changes (`_sync_guess_seed`) and on `reset_shown_biomes`.
var _shown_biomes: Dictionary = {}
const SHOWN_BIOME_CACHE_MAX := 64
## Terrain-slice biome reads made (`_biome_at`), for tests that count lookups.
var biome_lookups: int = 0
## Hard bound on the guess cache. Pruning on unload keeps it to the ring in steady state, but
## a guess whose requesting build was cancelled never gets an unload to sweep it; the oldest
## entries are evicted instead (dictionary insertion order), so the worst case is a fixed
## number of arrays, not a leak.
const GUESS_CACHE_MAX := 48
## Voxel edits keyed by "gx,gz" string → Array of typed run edits, in the order
## they were applied (see the class docstring), compacted past MAX_TILE_OPS. The
## column's runs are the tile's
## natural run with this list replayed over it, so an edit is a description of
## what the player DID, not a replacement of what the ground IS.
## Phase 137 — host only: columns whose loose ground may have lost its support, settled a few per tick.
var _settle := Settle.SettleQueue.new()
## Columns `settle_tick` processes per call; a bigger collapse spreads over several ticks.
const SETTLE_BUDGET := 32
## Settle edits applied so far (host); a test reads it, nothing else does.
var settle_edits: int = 0

var _edits: Dictionary = {}

## Phase 42 review pass 10 — `_edits` INDEXED BY CHUNK, so a build's gather reads only the
## chunks it can reach instead of scanning (and string-splitting) the WHOLE log on every
## dispatch. `_dirty_chunks` already keys by chunk for the write side; this is the read-side
## counterpart — `"cx,cz"` → `{ "gx,gz": true }` — kept in step by `_set_edit_ops` (the one
## place `_edits` is written), so `_gather_edits` is proportional to the edits a chunk and
## its one-tile ring actually hold rather than to every edit in the world.
var _edits_by_chunk: Dictionary = {}

## Chunks touched by an edit since the last save, keyed by "cx,cz" string → true.
## Drives the per-chunk persistence manifest so only dirty chunks are re-serialized.
var _dirty_chunks: Dictionary = {}
## Phase 52 — chunks whose edits a save has collected but whose write has not yet landed.
## They are no longer dirty, yet disk does not hold them: they must not be evicted (a failed
## write would then lose them) nor overwritten by a region re-read (it would be stale).
var _inflight_chunks: Dictionary = {}

## Phase 42 — how many times a chunk has been (re)built, keyed by "cx,cz" string.
## A build dispatched to a worker carries the revision it was dispatched AT, and
## `build_chunk` refuses the result when the revision has moved on: the arrays then
## describe a chunk that has already been rebuilt, and applying them would undo what
## that rebuild produced (see `chunk_revision`). The EDIT case is closed before it
## reaches here — `ChunkManager.request_rebuild` supersedes a build already in flight
## for an edited chunk — so this guard is what catches a chunk rebuilt under a build by
## any other route.
var _chunk_revision: Dictionary = {}

## Phase 43 — vein id → units mined out of it so far, DERIVED from the edit log: each
## mined vein carries ONE `{ "op": "deplete", "vein": id, "taken": n }` op on its anchor
## tile (see `_record_depletion`), so this index, like `_edits_by_chunk`, is re-derived when
## the log is replaced wholesale (`_reindex_edits`) and kept in step on the one write path.
## A vein is exhausted when `taken` reaches its reserve (`OreField.is_live`).
var _vein_taken: Dictionary = {}

## Phase 61 — vein id → units taken, for deplete ops whose anchor chunk was EVICTED
## (`evict_clean_chunks`). A vein's blob can span chunks while its one deplete op sits on the
## anchor tile's chunk; releasing that chunk must not make the vein live again in its
## neighbours. `_reindex_edits` folds this table into `_vein_taken`, and drops an entry once
## the op is resident again (the log then carries the count itself).
var _vein_carry: Dictionary = {}

## Phase 75 — chunks whose resident edits are PARTIAL: a depletion was written onto an anchor
## tile while the chunk held no edits in memory (never loaded, or evicted), so the log holds the
## depletion but not what the region file stores for the chunk. The save marks such an entry
## `merge` (see `get_save_manifest`) and the region fold overlays it on the stored entry instead
## of replacing it. Cleared when the chunk is evicted or the log is replaced wholesale.
var _partial_chunks: Dictionary = {}

## Set by game_root: terrain (biome + base height) and inventory (material flow).
## Phase 92 — assigning a different slice drops everything derived from the old one (the guessed
## heightmaps and the shown-biome memo), so a swap never serves the previous slice's answers.
var terrain_slice: Node = null:
	set(value):
		if value != terrain_slice:
			_guess_heightmaps.clear()
			_shown_biomes.clear()
		terrain_slice = value
var inventory_slice: Node = null

## Phase 42 review — the registry that owns one inventory PER PLAYER, so an edit the
## host resolves for a REMOTE actor spends and credits THAT player's pack instead of
## this machine's. Optional: an isolated rig (the suite, a probe) leaves it null and
## every player id falls back to `inventory_slice`, the local bucket (see
## `inventory_for`).
var player_registry: Node = null

## Phase 42 review — the chunk manager, so an edit can DISPATCH its rebuild instead of
## building up to three chunks synchronously on the main thread. Optional: a slice with
## no manager wired (the suite, a probe) keeps the synchronous build (see
## `_rebuild_chunk_at_tile`), which is what the isolated edit tests assert against.
var chunk_manager: Node = null

## Authority mode (Phase 18). When true (host / single-player), this slice owns
## world edits: mine/place requests are validated and applied here, and their
## results are broadcast via block_changed. When false (client), edits are
## forwarded to the host via block_edit_intent and applied only when the host's
## authoritative block_changed arrives. Set by game_root before _ready().
var is_authoritative: bool = true

## Material used by place_block; cycled via cycle_place_material(). Empty until
## the player cycles onto a material they actually hold in inventory.
var _place_material: String = ""

## Phase 65 — season tint per biome (`set_season_tints`) and the terrain material each biome's
## chunks wear. A chunk's surface and deposit overlay share its biome's instance; a biome with no
## tint yet is white until `set_season_tints` reaches it.
var _season_tints: Dictionary = {}
var _biome_mats: Dictionary = {}

## Single world-level safety floor shared by all chunks (prevents the player from
## ever falling through the world). Created once in _ready(). It sits one unit
## BELOW BEDROCK_DEPTH: the terrain's own runs are the ground, and a floor slab
## higher than them would block a player mining down to the floor.
var _world_floor: StaticBody3D = null

## Phase 50: the scene-origin offset applied to every chunk root. Chunk geometry is built in
## absolute chunk-index metres; a client rebase moves the roots (not the vertices) so the physics
## and render scene never see a large coordinate. Zero until the first rebase.
const SceneOffset := preload("res://src/core/scene_offset.gd")
var _origin: SceneOffset = SceneOffset.new()

## Shift every streamed chunk node, and the world floor, by `shift` in one call. Chunks built
## later pick the accumulated offset up, so a rebase never leaves a mix of frames.
func shift_scene(shift: Vector3) -> void:
	_origin.value += shift
	for key in _chunks:
		_chunks[key].position += shift
	if _world_floor != null:
		_world_floor.position += shift

func scene_offset() -> Vector3:
	return _origin.value

## Phase 120 — fold stand-ins. A fold over a pole or round the antimeridian re-streams the window in
## the folded frame (`ChunkManager.restream`). Until a chunk is rebuilt there, the root that stood in
## its place before the fold stands in for it, carried by the fold's scene transform
## (`TerrainSlice.fold_scene_transform`) with its mesh and collision, so the ground never vanishes
## and the body never waits for it. Round the antimeridian a stand-in is the very chunk that
## replaces it; over a pole the ground in reach is the pole's snow field, the same on both sides.
## Keyed by the folded-frame chunk each one covers; `build_chunk` frees the one it replaces.
## Phase 163 — false on a dedicated server: nothing draws there, so a chunk attaches no render mesh, water or deposits.
var attach_geometry := true
var attach_collision := true   # Phase 172: separate from the render mesh; its shape is built on the worker
## Phase 189 — shapes of built chunks whose collision waits for a body (`build_chunk(..., collide = false)`),
## attached by `attach_parked_collision` when the chunk manager's near ring reaches them.
var _parked_shapes: Dictionary = {}   # "cx,cz" -> Shape3D, or (Phase 183) an Array of quadrant shapes still to attach

func attach_parked_collision(chunk_pos: Vector2i, all: bool = true) -> bool:
	return _build.attach_parked_collision(chunk_pos, all)

func has_parked_collision(chunk_pos: Vector2i) -> bool:
	return _build.has_parked_collision(chunk_pos)

func has_collision(chunk_pos: Vector2i) -> bool:
	return _build.has_collision(chunk_pos)
## #437 — what a build hands `build_chunk` when `attach_geometry` is false: no mesh, collision or
## deposit arrays (the worker skips `build_runs` and `build_chunk_arrays`), only the chunk-local
## flag the root's position reads. Not empty, so a worker result carrying it is not refused.
## A fresh dictionary per call (#444): a shared const would error on the first write to `built`.
static func no_geometry_arrays() -> Dictionary:
	return { "local": true }
var _standins: Dictionary = {}   # "cx,cz" -> Node3D

## Take every streamed chunk root (and any stand-in still waiting) out of the slice, so a re-stream
## does not free them. They stay in the tree and keep drawing; hand them to `adopt_standins`.
func detach_standins() -> Array:
	var roots: Array = _chunks.values() + _standins.values()
	_build.carry_parked_shapes()   # Phase 189: a carried root keeps its parked collision
	_chunks.clear()
	_standins.clear()
	return roots

## Carry `roots` (from `detach_standins`) by the fold's transform `xform`, each the stand-in of its chunk.
func adopt_standins(roots: Array, xform: Transform3D) -> void:
	_build.adopt_standins(roots, xform)

## True while a stand-in covers `chunk_pos`.
func has_standin(chunk_pos: Vector2i) -> bool:
	return _standins.has(_chunk_key(chunk_pos))

func standin_count() -> int:
	return _standins.size()

## Free the stand-ins whose chunk `keep` (chunk -> bool) no longer wants: nothing will rebuild them.
func prune_standins(keep: Callable) -> void:
	for key in _standins.keys():
		var root: Node3D = _standins[key]
		if not is_instance_valid(root) or not bool(keep.call(root.get_meta("standin_chunk"))):
			_free_standin(key)

## Free every stand-in left (a build that never landed must not leave old ground behind for good).
func release_standins() -> void:
	for key in _standins.keys():
		_free_standin(key)

func _free_standin(key: String) -> void:
	_build.free_standin(key)

func _ready() -> void:
	# Phase 43 — fill the ore field's material band table HERE, on the main thread, before any
	# worker can exist. It replaces the Phase 42 per-biome roll table and inherits its contract:
	# a `static var` on a script a chunk-build task reaches (`build_runs` → `natural_color` →
	# `material_for_biome` → `OreField.vein_at` → `OreField.allows` → `OreField.band_of`), so it
	# is WRITTEN here, before the tree streams anything, and read-only afterwards. The bands
	# come off the generated fabric resources (`depthBand`, `leyGated`), which is why this
	# cannot be a `const`.
	OreField.warm()
	native_runs_cfg()   # Phase 168: snapshot the native build_runs tables on the main thread
	WorldShape.warm()
	_world_floor = StaticBody3D.new()
	_world_floor.name = "WorldFloor"
	_world_floor.collision_layer = TERRAIN_COLLISION_LAYER
	_world_floor.collision_mask = 0
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(65536.0, 1.0, 65536.0)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0.0, BEDROCK_DEPTH - 0.5, 0.0)
	_world_floor.add_child(floor_shape)
	add_child(_world_floor)

	GameBus.chunk_ready.connect(_on_chunk_ready)
	GameBus.block_mine_requested.connect(_on_mine_requested)
	GameBus.block_place_requested.connect(_on_place_requested)
	GameBus.block_cycle_material_requested.connect(_on_cycle_requested)
	GameBus.block_changed.connect(_on_block_changed)

func _process(_delta: float) -> void:
	if is_authoritative and not _settle.is_empty():
		settle_tick()

func build_chunk(chunk_pos: Vector2i, heightmap: Array, arrays: Dictionary = {}, revision: int = -1, collide: bool = true, stagger: bool = false) -> bool:
	return _build.build_chunk(chunk_pos, heightmap, arrays, revision, collide, stagger)

## Phase 51 — the static water level. Rows of tiles whose ground lies below the sea surface,
## merged into spans: each span is `Vector3i(tile_z, first_tile_x, last_tile_x + 1)`. Pure.
static func water_spans(heightmap: Array, sea_level: float) -> Array:
	var spans: Array = []
	for tz in range(CHUNK_SIZE):
		var start := -1
		for tx in range(CHUNK_SIZE + 1):
			var wet := tx < CHUNK_SIZE and float(heightmap[tz * CHUNK_SIZE + tx]) < sea_level
			if wet and start < 0:
				start = tx
			elif not wet and start >= 0:
				spans.append(Vector3i(tz, start, tx))
				start = -1
	return spans

## The chunk's water surface at the sea level (world coordinates, or relative to the chunk's corner when
## `local`, like the terrain mesh), or null on dry ground.
## Render-only: the mesh has no collision body, so the player sinks through it and swims.
static func water_mesh_for(chunk_pos: Vector2i, heightmap: Array, local: bool = false) -> ArrayMesh:
	var sea := WorldShape.sea_level()
	var spans := water_spans(heightmap, sea)
	if spans.is_empty():
		return null
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for sp in spans:
		var chunk_x := 0.0 if local else float(chunk_pos.x * CHUNK_SIZE)
		var chunk_z := 0.0 if local else float(chunk_pos.y * CHUNK_SIZE)
		var z0 := (chunk_z + float(sp.x)) * TILE_SIZE
		var z1 := z0 + TILE_SIZE
		var x0 := (chunk_x + float(sp.y)) * TILE_SIZE
		var x1 := (chunk_x + float(sp.z)) * TILE_SIZE
		var base := vertices.size()
		vertices.append_array([Vector3(x0, sea, z0), Vector3(x1, sea, z0), Vector3(x1, sea, z1), Vector3(x0, sea, z1)])
		for _i in 4:
			normals.append(Vector3.UP)
		indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

var _ice_mat: StandardMaterial3D = null
## Frozen sea: an opaque pale sheet at sea level (a polar chunk's water).
func _ice_material() -> StandardMaterial3D:
	if _ice_mat == null:
		_ice_mat = StandardMaterial3D.new()
		_ice_mat.albedo_color = ICE_COLOR
		_ice_mat.roughness = 0.35
	return _ice_mat

var _water_mat: StandardMaterial3D = null
func _water_material() -> StandardMaterial3D:
	if _water_mat == null:
		_water_mat = StandardMaterial3D.new()
		_water_mat.albedo_color = Color(0.15, 0.35, 0.6, 0.6)
		_water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_water_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _water_mat

func collect_build_runs(chunk_pos: Vector2i, heightmap: Array) -> Dictionary:
	return _build.collect_build_runs(chunk_pos, heightmap)

func gather_build_input(chunk_pos: Vector2i, _heightmap: Array) -> Dictionary:
	return _build.gather_build_input(chunk_pos, _heightmap)

func _gather_edits(chunk_pos: Vector2i) -> Dictionary:
	return _build._gather_edits(chunk_pos)

## Phase 69 — bumped whenever a chunk's edit bucket changes, so a consumer can do work "once per
## edit revision" (`ChunkManager` gates its seam rebuilds on it).
var _edit_rev: Dictionary = {}

func edit_revision(chunk_pos: Vector2i) -> int:
	return int(_edit_rev.get(_chunk_key(chunk_pos), 0))

func seam_borders(chunk_pos: Vector2i) -> Array:
	return _build.seam_borders(chunk_pos)

## Phase 69 — the neighbour offsets `tile` sits against: one per chunk edge it is on, plus the
## diagonal when it is on a corner (the one place that offset math lives).
static func _border_offsets(tile: Vector2i) -> Array:
	var lx := posmod(tile.x, CHUNK_SIZE)
	var lz := posmod(tile.y, CHUNK_SIZE)
	var dx := -1 if lx == 0 else (1 if lx == CHUNK_SIZE - 1 else 0)
	var dz := -1 if lz == 0 else (1 if lz == CHUNK_SIZE - 1 else 0)
	var out: Array = []
	if dx != 0:
		out.append(Vector2i(dx, 0))
	if dz != 0:
		out.append(Vector2i(0, dz))
	if dx != 0 and dz != 0:
		out.append(Vector2i(dx, dz))
	return out

func _gather_neighbour_heightmaps(chunk_pos: Vector2i) -> Dictionary:
	return _build._gather_neighbour_heightmaps(chunk_pos)

func _generated_heightmap(chunk: Vector2i, ckey: String) -> Array:
	return _build._generated_heightmap(chunk, ckey)

func take_heightmap_for_build(chunk: Vector2i) -> Array:
	return _build.take_heightmap_for_build(chunk)

func take_cached_heightmap(chunk: Vector2i) -> Array:
	return _build.take_cached_heightmap(chunk)

func gather_build_input_deferred(chunk_pos: Vector2i) -> Dictionary:
	return _build.gather_build_input_deferred(chunk_pos)

## Phase 141 — the worker half of `gather_build_input_deferred`: give every `missing_neighbours`
## chunk of `input` the edge strip `chunk_pos`'s ring reads (`TerrainSlice.heightmap_strip_for`),
## so `build_runs` sees the same seam heights a full guess map would give it. Pure; `noise` is the
## terrain's detail noise for `seed_v`, owned by the calling task.
static func fill_seam_strips(chunk_pos: Vector2i, input: Dictionary, seed_v: int, noise: FastNoiseLite) -> void:
	var known: Dictionary = input.get("neighbour_heightmaps", {})
	for chunk in input.get("missing_neighbours", []):
		var c: Vector2i = chunk
		known[_chunk_key(c)] = TerrainSlice.heightmap_strip_for(c, chunk_pos - c, seed_v, noise)
	input["neighbour_heightmaps"] = known

func _sync_guess_seed() -> void:
	_build._sync_guess_seed()

func gather_biomes_for(chunk_pos: Vector2i) -> Dictionary:
	return _build.gather_biomes_for(chunk_pos)

## Phase 92 — the polar row from which a chunk no longer lends its biome: the terrain slice's own
## bound when it reports one (as the minimap asks), else the static one.
func _polar_bound() -> int:
	if terrain_slice != null and terrain_slice.has_method("world_radius_chunks"):
		return int(terrain_slice.world_radius_chunks())
	return TerrainSlice.polar_chunks()

func _lending_ring(own: Vector2i, candidates: Array) -> Array:
	return _build._lending_ring(own, candidates)

func _ring_chunks(chunk_pos: Vector2i) -> Array:
	return _build._ring_chunks(chunk_pos)

## The world XZ centre of a chunk — a position `_biome_at` maps back to that same chunk.
static func _chunk_world_center(chunk_pos: Vector2i) -> Vector2:
	var extent := float(CHUNK_SIZE * TILE_SIZE)
	return Vector2((float(chunk_pos.x) + 0.5) * extent, (float(chunk_pos.y) + 0.5) * extent)

## PURE resolve — no node, no bus, no slice state, so it is legal on a worker thread. The only
## inputs are the chunk, its heightmap and the payload `gather_build_input` copied off the
## slice; `build_chunk_arrays` consumes what this returns.
static func build_runs(chunk_pos: Vector2i, heightmap: Array, input: Dictionary) -> Dictionary:
	if NativeBuilder.use_native("build_runs"):   # Phase 168: same result, computed in C++
		var native := NativeBuilder.builder().call("build_runs", chunk_pos, heightmap, input, native_runs_cfg()) as Dictionary
		if native.has("runs"):   # #452: a rejected input (heightmap size, vein callable) comes back empty
			return native
	return build_runs_gd(chunk_pos, heightmap, input)

## Phase 168 — what the native `build_runs` cannot read itself, snapshotted once (fabric tables are fixed
## after boot) and warmed from `_ready`; `NativeBuilder.memo` fills it under a lock for a worker that gets there first.
static func native_runs_cfg() -> Dictionary:
	return NativeBuilder.memo("build_runs", _make_native_runs_cfg)

static func _make_native_runs_cfg() -> Dictionary:
	OreField.warm()
	var host := {}
	for biome in BIOME_BIAS:
		host[str(biome)] = OreField.host_material(str(biome))
	var styles := {}
	for biome in GameData.BIOMES:
		var style := surface_style(str(biome))
		if not style.is_empty():
			styles[str(biome)] = style
	return {
		"circumference_chunks": TerrainSlice.circumference_chunks(),
		"colors": MATERIAL_COLORS,
		"fallback_color": FALLBACK_TERRAIN_COLOR,
		"ice_color": ICE_COLOR,
		"host": host,
		"styles": styles,
		"bands": OreField.bands(),
		"vein_cell": Callable(OreField, "vein_in_cell"),
	}

## The GDScript reference of `build_runs`: the fallback and the parity suite's baseline.
static func build_runs_gd(chunk_pos: Vector2i, heightmap: Array, input: Dictionary) -> Dictionary:
	var edits: Dictionary = input.get("edits", {})
	var neighbours: Dictionary = input.get("neighbour_heightmaps", {})
	var biomes: Dictionary = input.get("biomes", {})
	# Phase 43 — the ore field's inputs, plus a per-call vein memo (cell → descriptor): a
	# chunk asks the same few cells thousands of times.
	var field := _field(int(input.get("seed", 0)), input.get("depleted", {}))
	var out: Dictionary = {}
	# A memo private to this call, for the plain (uncoloured) resolution. It is
	# deliberately NOT the table handed out: a tile's runs are read by the tile itself
	# and by each neighbour's subtraction, and only the table carries colours.
	var plain: Dictionary = {}
	var colours: Dictionary = {}
	# Surface style per biome, resolved once per build: it is a function of the biome alone
	# and a chunk's ring touches at most four biomes, against ~4000 runs that each asked.
	var styles: Dictionary = {}
	for tz in range(-1, CHUNK_SIZE + 1):
		for tx in range(-1, CHUNK_SIZE + 1):
			var gx := chunk_pos.x * CHUNK_SIZE + tx
			var gz := chunk_pos.y * CHUNK_SIZE + tz
			var world_xz := Vector2(gx * TILE_SIZE + TILE_SIZE * 0.5, gz * TILE_SIZE + TILE_SIZE * 0.5)
			var coloured: Array = []
			var surface := _natural_top(heightmap, chunk_pos, tx, tz, neighbours)
			for run in _neighbour_runs(heightmap, chunk_pos, tx, tz, plain, edits, neighbours):
				var entry := {
					"bottom":   float(run["bottom"]),
					"top":      float(run["top"]),
					"material": str(run.get("material", "")),
					"color":    run_color(run, world_xz, biomes, colours, surface, field),
				}
				_apply_topsoil(entry, world_xz, biomes, surface, field, styles)
				coloured.append(entry)
			out[_tile_key(Vector2i(gx, gz))] = coloured
	# The deposits ride the SAME memo, so the chunk's own columns are not replayed twice:
	# `plain` holds exactly the runs `_column_runs` would return for a tile of this chunk.
	return { "runs": out, "deposits": vein_deposits_at(chunk_pos, heightmap, plain, edits, biomes, field) }

## Phase 49 — a surface style (`top`, `soil` colours and `depth`) from the biome's fabric
## fields (`surfaceTint`, `soilTint`, `topsoilDepth`); empty when the biome resource is not
## loaded (an isolated rig), which leaves the plain rock colouring. `material` is the
## biome's `surfaceMaterial` cover name (e.g. Grass): the mesher never reads it (colour is
## what it needs), and the yield it implies is the biome's own `soilMaterial`, read by
## `_natural_yield` — the style carries the cover so a consumer has one place to read it,
## and a test pins that every biome declares one.
##
## Thread note: the worker half of the build calls this through `build_runs`. It only READS
## `GameData.BIOMES`, which is a fully preloaded constant table, so that is safe today; if
## `GameData` ever fills lazily, resolve the styles on the main thread and pass them in the
## gathered payload instead.
static func surface_style(biome: String) -> Dictionary:
	var b: Variant = GameData.BIOMES.get(biome, null)
	if b == null or b.get("surfaceTint") == null:
		return {}
	var depth: Variant = b.get("topsoilDepth")
	return {
		"top":      Color.from_string(str(b.get("surfaceTint")), FALLBACK_TERRAIN_COLOR),
		"soil":     Color.from_string(str(b.get("soilTint")), FALLBACK_TERRAIN_COLOR),
		"depth":    float(depth if depth != null else 0.0),
		"material": str(b.get("surfaceMaterial")),
	}

## Phase 49 — topsoil. An UNEDITED natural run whose top is the tile's natural surface gets a
## `top_color` (the biome's surface tint) and a `soil_color` + `soil_depth`: its side walls wear
## soil down to the soil line and the run's own `color` (rock) below it. A column whose surface
## is a live vein keeps the vein's colour, and a placed block or a run cut below the natural
## surface keeps its own. The tint is flat per biome so the greedy merge still fuses the top.
## `styles` is the caller's per-build memo (biome -> `surface_style`); pass `{}` for a one-off.
static func _apply_topsoil(entry: Dictionary, world_xz: Vector2, biomes: Dictionary, surface: float, field: Dictionary, styles: Dictionary = {}) -> void:
	if entry["material"] != "" or is_nan(surface) or absf(float(entry["top"]) - surface) > STEP_HEIGHT * 0.25:
		return
	var biome := biome_of(world_xz, biomes)
	var shown := blended_biome(world_xz, biomes, biome)
	if not styles.has(shown):
		styles[shown] = surface_style(shown)
	var style: Dictionary = styles[shown]
	if style.is_empty():
		return
	if material_for_biome(biome, world_xz, 0.0, int(field.get("seed", 0)), field.get("depleted", {}),
			field.get("veins", {})) != OreField.host_material(biome):
		return
	# The biome's tint is snowed over toward the poles, as the rock is (`natural_color`).
	entry["top_color"] = icy(style["top"], world_xz.y)
	entry["soil_color"] = icy(style["soil"], world_xz.y)
	entry["soil_depth"] = float(style["depth"])

## Phase 49 — the biome whose surface a tile WEARS. Within `BLEND_TILES` of a chunk border, a
## tile may show the biome across that border instead of its own: the chance falls from one half
## at the border to zero at the band's inner edge, and a coordinate hash (no RNG, no thread
## state) decides, so every build of the tile agrees and the border reads as a dithered band
## rather than a straight cut (`BiomeBlend` holds the rule, shared with the minimap). The colour
## and the soil yield follow it (`_natural_yield`); the ore field still reads `own`.
static func blended_biome(world_xz: Vector2, biomes: Dictionary, own: String) -> String:
	var extent := float(CHUNK_SIZE * TILE_SIZE)
	var cx := floori(world_xz.x / extent)
	var cz := floori(world_xz.y / extent)
	var lx := world_xz.x - cx * extent
	var lz := world_xz.y - cz * extent
	# Phase 122 — corners and diagonals. Distance (in tiles) to the nearest border on each axis, and the
	# chunk step across it. The x-neighbour, the z-neighbour and (near a corner) the diagonal chunk each
	# get their own roll, and the two axes roll with the coordinates swapped, so the rule is symmetric
	# under swapping X and Z; where both axes would win, the nearer border wins and a tie takes the diagonal.
	var dx := minf(lx, extent - lx) / TILE_SIZE
	var dz := minf(lz, extent - lz) / TILE_SIZE
	if minf(dx, dz) >= BLEND_TILES:
		return own
	var sx := -1 if lx < extent - lx else 1
	var sz := -1 if lz < extent - lz else 1
	var gx := floori(world_xz.x / TILE_SIZE)
	var gz := floori(world_xz.y / TILE_SIZE)
	var bx := str(biomes.get(_chunk_key(Vector2i(cx + sx, cz)), own))
	var bz := str(biomes.get(_chunk_key(Vector2i(cx, cz + sz)), own))
	var bd := str(biomes.get(_chunk_key(Vector2i(cx + sx, cz + sz)), own))
	var dd := maxf(dx, dz)
	if dd < BLEND_TILES and bd != own and 0.5 * (BiomeBlend.roll(gx, gz) + BiomeBlend.roll(gz, gx)) < 0.5 * BiomeBlend.chance(dd, BLEND_TILES):
		return bd
	var wx := bx != own and BiomeBlend.wears_neighbour(gx, gz, dx, BLEND_TILES)
	var wz := bz != own and BiomeBlend.wears_neighbour(gz, gx, dz, BLEND_TILES)
	if wx and wz:
		if dx < dz:
			return bx
		if dz < dx:
			return bz
		return bd if bd != own else bx
	if wx:
		return bx
	if wz:
		return bz
	return own

## Phase 43 — the ore field's per-call input: the seed, the depletion record and a fresh
## vein memo. Static and plain, so the worker half builds it from its payload.
static func _field(seed_v: int, depleted: Dictionary) -> Dictionary:
	return { "seed": seed_v, "depleted": depleted, "veins": {} }

## The tile's NATURAL surface — its quantised heightmap top — read off the chunk's own map or
## a ring neighbour's, or NAN when the neighbour is unknown. It is the datum the ore field's
## depth is measured from, so a vein's depth is fixed by the world, not by what a player has
## mined above it.
static func _natural_top(heightmap: Array, chunk_pos: Vector2i, tx: int, tz: int, neighbours: Dictionary) -> float:
	if tx >= 0 and tx < CHUNK_SIZE and tz >= 0 and tz < CHUNK_SIZE:
		return _voxel_height(float(heightmap[tz * CHUNK_SIZE + tx]))
	var g := Vector2i(chunk_pos.x * CHUNK_SIZE + tx, chunk_pos.y * CHUNK_SIZE + tz)
	var chunk := _tile_to_chunk(g)
	var hm: Variant = neighbours.get(_chunk_key(chunk), null)
	if not (hm is Array):
		return NAN
	return _voxel_height(float((hm as Array)[(g.y - chunk.y * CHUNK_SIZE) * CHUNK_SIZE + (g.x - chunk.x * CHUNK_SIZE)]))

## The depth (below the natural surface) the ore field reads for a run: the CENTRE of its top
## STEP_HEIGHT slice — the slice the player sees on top and the one the next mine takes.
static func _run_depth(run: Dictionary, surface: float) -> float:
	return surface - (float(run["top"]) - STEP_HEIGHT * 0.5)

## The pure greedy-merged build; the code lives in `VoxelMesh` (Phase 154), the signature is unchanged.
static func build_chunk_arrays(chunk_pos: Vector2i, heightmap: Array, resolved: Dictionary, local: bool = false) -> Dictionary:
	return VoxelMesh.build_chunk_arrays(chunk_pos, heightmap, resolved, local)

static func _mesh_from_arrays(arrays: Dictionary) -> ArrayMesh:
	return VoxelMesh.mesh_from_arrays(arrays)

static func _merge_rects(cells: Dictionary) -> Array:
	return VoxelMesh.merge_rects(cells)

static func _group_cell(groups: Dictionary, dir: String, plane: float, bottom: float, top: float, color: Color, a: int, b: int) -> void:
	VoxelMesh.group_cell(groups, dir, plane, bottom, top, color, a, b)

## The collision triangle soup for one chunk: exactly the triangles the build emits.
## `build_chunk` taps the arrays it ALREADY has (one build per chunk, not two); this
## entry point exists so a caller that has no chunk node — the suite — can assert the
## trimesh's SHAPE headlessly. Physics itself is INERT inside the suite (`_run_tests()`
## runs synchronously in `GameRoot._ready()`, where a `move_and_slide()` never
## registers a collision, verified in ROADMAP §Phase 39), so "the trimesh stops a body"
## is exercised in GAME only and this proves the geometry it is built from.
func collision_faces(chunk_pos: Vector2i, heightmap: Array) -> PackedVector3Array:
	var built := build_chunk_arrays(chunk_pos, heightmap, collect_build_runs(chunk_pos, heightmap))
	var collision: PackedVector3Array = built["collision"]
	return collision

## How many times a chunk has been (re)built. A build dispatched to a worker carries
## the revision it was dispatched AT, and `build_chunk` refuses a result whose revision
## has moved on: a synchronous rebuild in the meantime (an edit) has already produced
## the correct mesh, and the in-flight arrays describe the terrain before that edit.
func chunk_revision(chunk_pos: Vector2i) -> int:
	return int(_chunk_revision.get(_chunk_key(chunk_pos), 0))

func unload_chunk(chunk_pos: Vector2i) -> void:
	_build.unload_chunk(chunk_pos)

func _prune_heightmaps(around: Vector2i) -> void:
	_build._prune_heightmaps(around)

## A chunk and its four edge neighbours.
func _plus_ring(c: Vector2i) -> Array:
	return [c, Vector2i(c.x - 1, c.y), Vector2i(c.x + 1, c.y),
			Vector2i(c.x, c.y - 1), Vector2i(c.x, c.y + 1)]

## Return the set of chunks currently holding live mesh nodes.
func get_loaded_chunks() -> Array:
	var out: Array = []
	for key in _chunks:
		var parts: PackedStringArray = str(key).split(",")
		out.append(Vector2i(int(parts[0]), int(parts[1])))
	return out

## Dump the base heightmaps for all built chunks, keyed by "cx,cz" → Array.
## Phase 41 — the host no longer ships these in the world snapshot (the client
## regenerates the terrain from the world seed); this is now for introspection and
## for the tests that prove the two sides agree chunk for chunk.
func get_heightmaps() -> Dictionary:
	return _heightmaps.duplicate(true)

# ---------------------------------------------------------------------------
# Edit API — mining and building
# ---------------------------------------------------------------------------

## Remove one STEP_HEIGHT of material from the column under world_pos, yielding
## that block's material into the inventory. Returns { success, material,
## quantity, position }.
##
## Phase 41 — the carve is the SPAN the ray landed on, not "lower the column by a
## step": a top-face hit takes the last step of the run whose top the ray landed
## on (`runs_topping_at` — a tunnel floor is aimable even with the roof above it),
## any other hit takes the block the ray hit. That is what lets a tunnel ROOF be
## mined without taking the tunnel floor with it, and it is why mining is refused
## at BEDROCK_DEPTH — there is nothing below the floor to yield.
##
## Phase 42 review — `player_id` names the actor whose pack is charged and paid:
## `""` is this machine's own player, and the host re-emits a client's intent with
## the identity bound to its connection (see `inventory_for`). Resolving against
## this slice's own `inventory_slice` for every actor was the silent transfer the
## review found: a client's mine filled the HOST's pack, and the client — whose own
## client mirrors only its own pack — saw nothing. The pick that wears is the
## actor's too.
## Phase 91 — `exact` is the aimed point as a `{chunk, local}` world record when the caller has it
## (the local player does): far from the origin `world_pos` is a float32 quantised to metres, too
## coarse to name a half-metre tile, so the tile is resolved from `exact` instead.
## Phase 205 — the host's structure index (`StructureSlice`): every mine and place on a block it holds asks
## it first (`plan_mine` / `plan_place`) and records the outcome once the edit succeeded (`commit_*`). Unset (a
## client, an isolated rig): no ownership, every edit is free.
var structures: Node = null

func mine_block(world_pos: Vector3, normal: Vector3 = Vector3.UP, player_id: String = "", exact: Dictionary = {}) -> Dictionary:
	return _edit.mine_block(world_pos, normal, player_id, exact)

func _natural_yield(tile: Vector2i, span: Dictionary) -> Dictionary:
	return _edit._natural_yield(tile, span)

func _record_depletion(vein: Dictionary, take: int) -> void:
	_edit._record_depletion(vein, take)

func _rebuild_vein_chunks(vein: Dictionary) -> void:
	_edit._rebuild_vein_chunks(vein)

func _vein_from_id(id: String) -> Dictionary:
	return _edit._vein_from_id(id)

func place_block(world_pos: Vector3, normal: Vector3, material: String = "", player_id: String = "", exact: Dictionary = {}) -> bool:
	return _edit.place_block(world_pos, normal, material, player_id, exact)

func place_structure_block(exact: Dictionary, material: String) -> bool:
	return _edit.place_structure_block(exact, material)

func remove_structure_block(tile: Vector2i, bottom: float, top: float) -> void:
	_edit.remove_structure_block(tile, bottom, top)

func get_voxel_height_at(world_pos: Vector2) -> float:
	return _query.get_voxel_height_at(world_pos)

func sample_support_height_at(world_pos: Vector2, from_y: float) -> float:
	return _query.sample_support_height_at(world_pos, from_y)

## The resolved solid runs of the column at a world XZ position, bottom → top.
func get_column_runs_at(world_xz: Vector2) -> Array:
	return get_runs_at_tile(_world_to_tile(world_xz))

## The resolved solid runs of one tile, bottom → top (see the class docstring).
func get_runs_at_tile(tile: Vector2i) -> Array:
	return VoxelRuns.apply_run_ops(_base_runs_for_tile(tile), _edits.get(_tile_key(tile), []))

func has_edit_near(tile: Vector2i, radius: int) -> bool:
	return _query.has_edit_near(tile, radius)

func has_edit_near_at(tile: Vector2i, radius: int, min_y: float) -> bool:
	return _query.has_edit_near_at(tile, radius, min_y)

func has_edits_near_chunk(chunk_pos: Vector2i, radius: int = 1) -> bool:
	return _query.has_edits_near_chunk(chunk_pos, radius)

func get_edits() -> Dictionary:
	return _persist.get_edits()

func apply_edits(edits: Dictionary, materials: Dictionary = {}) -> void:
	_persist.apply_edits(edits, materials)

func _normalise_edit_table(edits: Dictionary, materials: Dictionary) -> Dictionary:
	return _persist._normalise_edit_table(edits, materials)

func _normalise_tile_ops(key: Variant, value: Array, materials: Dictionary) -> Array:
	return _persist._normalise_tile_ops(key, value, materials)

func _commit_edits(next: Dictionary, diff_keys: Variant = null) -> void:
	_persist._commit_edits(next, diff_keys)

## Phase 122 — the one place the seam gate is decided: the neighbour offsets `tile` sits against, or
## none when neither op list (the old and the new one; `seam_borders` passes one) can change a height.
static func _shaped_border_offsets(tile: Vector2i, ops: Variant, other_ops: Variant = null) -> Array:
	if not (_ops_shape(ops) or _ops_shape(other_ops)):
		return []
	return _border_offsets(tile)

## True when `ops` holds an op that can change a height (anything but a deplete).
static func _ops_shape(ops: Variant) -> bool:
	if not ops is Array:
		return false
	for op in ops:
		if op is Dictionary and str(op.get("op", "")) != "deplete":
			return true
	return false

static func _union_keys(a: Dictionary, b: Dictionary) -> Array:
	var keys: Array = b.keys()
	for key in a:
		if not b.has(key):
			keys.append(key)
	return keys

func _mark_touched_tile(touched: Dictionary, tile: Vector2i) -> void:
	_persist._mark_touched_tile(touched, tile)

## True when two op lists describe exactly the same edits — the comparison a
## re-scope snapshot needs before it decides a chunk's mesh is already correct.
## Compared field by field rather than by container equality: both sides can come
## from JSON, where the same span may arrive as `int` or `float`.
static func _ops_equal(a: Variant, b: Variant) -> bool:
	if not (a is Array) or not (b is Array):
		return false
	var x: Array = a
	var y: Array = b
	if x.size() != y.size():
		return false
	for i in range(x.size()):
		if not (x[i] is Dictionary) or not (y[i] is Dictionary):
			return false
		var p: Dictionary = x[i]
		var q: Dictionary = y[i]
		if str(p.get("op", "")) != str(q.get("op", "")):
			return false
		if not is_equal_approx(float(p.get("bottom", 0.0)), float(q.get("bottom", 0.0))):
			return false
		if not is_equal_approx(float(p.get("top", 0.0)), float(q.get("top", 0.0))):
			return false
		if str(p.get("material", "")) != str(q.get("material", "")):
			return false
		if str(p.get("vein", "")) != str(q.get("vein", "")) or int(p.get("taken", 0)) != int(q.get("taken", 0)):
			return false
	return true

func get_chunk_manifest() -> Dictionary:
	return _persist.get_chunk_manifest()

func get_save_manifest() -> Dictionary:
	return _persist.get_save_manifest()

## True when chunk `chunk_pos`'s square overlaps the disc of `radius` around the world
## position `center` (XZ). Pure; the AOI scope of a re-scope snapshot's edits.
static func chunk_in_radius(chunk_pos: Vector2i, center: Vector3, radius: float) -> bool:
	var size := float(CHUNK_SIZE) * TILE_SIZE
	var min_corner := _chunk_world_center(chunk_pos) - Vector2(size, size) * 0.5
	var nx := clampf(center.x, min_corner.x, min_corner.x + size)
	var nz := clampf(center.z, min_corner.y, min_corner.y + size)
	return Vector2(center.x - nx, center.z - nz).length() <= radius

func get_chunk_manifest_in_radius(center: Vector3, radius: float) -> Dictionary:
	return _persist.get_chunk_manifest_in_radius(center, radius)

func apply_scoped_chunk_manifest(manifest: Dictionary, center: Vector3, radius: float) -> void:
	_persist.apply_scoped_chunk_manifest(manifest, center, radius)

## Parse a "cx,cz" chunk key — the same "x,y" form as a tile key (`_key_to_tile`), which is
## the one parser.
static func _chunk_from_key(ckey: String) -> Vector2i:
	return _parse_xy(ckey)

static func _parse_xy(key: String) -> Vector2i:
	var parts: PackedStringArray = key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

func apply_chunk_manifest(manifest: Dictionary) -> void:
	_persist.apply_chunk_manifest(manifest)

func apply_region_chunks(manifest: Dictionary) -> void:
	_persist.apply_region_chunks(manifest)

func evict_clean_chunks(chunk_keys: Array) -> int:
	return _persist.evict_clean_chunks(chunk_keys)

func edited_chunk_keys() -> Array:
	return _persist.edited_chunk_keys()

func get_dirty_chunk_keys() -> Array:
	return _persist.get_dirty_chunk_keys()

func clear_dirty_chunks() -> void:
	_persist.clear_dirty_chunks()

func clear_dirty_chunk_keys(keys: Array) -> void:
	_persist.clear_dirty_chunk_keys(keys)

func begin_inflight_chunks(keys: Array) -> void:
	_persist.begin_inflight_chunks(keys)

func end_inflight_chunks(keys: Array) -> void:
	_persist.end_inflight_chunks(keys)

func mark_dirty_chunks(keys: Array) -> void:
	_persist.mark_dirty_chunks(keys)

func set_place_material(material: String) -> void:
	_place_material = material

func get_place_material() -> String:
	return _place_material

func cycle_place_material() -> String:
	return _query.cycle_place_material()

func _buildable_materials() -> Array:
	return _query._buildable_materials()

## Material at a natural tile, read off the ORE FIELD (Phase 43): the vein's material when
## (tile, depth) is inside a LIVE vein, otherwise the biome's host rock (the heaviest
## `BIOME_BIAS` entry). No wood materials — those come from trees, not the ground.
##
##   depth    : world units below the tile's NATURAL surface (0 is the top of the ground)
##   seed     : the world seed (`_world_seed`)
##   depleted : vein id → units taken (`get_vein_depletion`); an exhausted vein is host rock
##   veins    : an optional per-caller vein memo (cell → descriptor)
##
## It used to be a per-tile roll of the biome's whole weighted table, the same at every depth
## — the uniform draw this phase retires. STATIC and pure, so the worker half of a build may
## call it (through `natural_color`).
static func material_for_biome(biome: String, world_xz: Vector2, depth: float = 0.0, seed_v: int = 0, depleted: Dictionary = {}, veins: Dictionary = {}) -> String:
	var vein := _live_vein_at(world_xz, depth, seed_v, depleted, veins)
	if not vein.is_empty():
		return str(vein["material"])
	return OreField.host_material(biome)

## The LIVE vein at a world position and depth, or `{}` (absent or mined out).
static func _live_vein_at(world_xz: Vector2, depth: float, seed_v: int, depleted: Dictionary, veins: Dictionary) -> Dictionary:
	var tile := _world_to_tile(world_xz)
	var chunk := _tile_to_chunk(tile)
	var vein := OreField.vein_at(seed_v, chunk, tile - chunk * CHUNK_SIZE, depth, veins)
	if vein.is_empty() or not OreField.is_live(vein, depleted):
		return {}
	return vein

## The ore field's answer for THIS world at a natural position and depth (the instance form
## of `material_for_biome`, with this slice's seed, biome and depletion record).
func material_at(world_xz: Vector2, depth: float) -> String:
	return material_for_biome(_biome_at(world_xz), world_xz, depth, _world_seed(), _vein_taken)

## Vein id → units mined out of it (a copy) — the depletion record the edit log carries.
func get_vein_depletion() -> Dictionary:
	return _vein_taken.duplicate()

func _world_seed() -> int:
	return _query._world_seed()

func vein_deposits(chunk_pos: Vector2i, heightmap: Array, cache: Dictionary = {}) -> Array:
	return _query.vein_deposits(chunk_pos, heightmap, cache)

## Phase 42 review pass 9 — the PURE half of the walk above: the edits, the biomes and (Phase 43)
## the ore field's inputs arrive as plain arguments (see `gather_build_input`), so a worker can
## run it. The chunk's own columns only, so the ring's heightmaps are not part of its input.
static func vein_deposits_at(chunk_pos: Vector2i, heightmap: Array, cache: Dictionary, edits: Dictionary, _biomes: Dictionary, field: Dictionary = {}) -> Array:
	var out: Array = []
	var seed_v := int(field.get("seed", 0))
	var depleted: Dictionary = field.get("depleted", {})
	var veins: Dictionary = field.get("veins", {})
	var deposit_size := Vector3(
		TILE_SIZE - VEIN_DEPOSIT_INSET * 2.0,
		VEIN_DEPOSIT_HEIGHT,
		TILE_SIZE - VEIN_DEPOSIT_INSET * 2.0)
	for tz in range(CHUNK_SIZE):
		for tx in range(CHUNK_SIZE):
			var runs := _column_runs(heightmap, chunk_pos, tx, tz, cache, edits)
			if runs.is_empty():
				continue
			var surface: Dictionary = runs[-1]
			if str(surface.get("material", "")) != "":
				continue   # a placed block is never a vein
			var h := float(surface["top"])
			var world_xz := Vector2(
				(chunk_pos.x * CHUNK_SIZE + tx) * TILE_SIZE + TILE_SIZE * 0.5,
				(chunk_pos.y * CHUNK_SIZE + tz) * TILE_SIZE + TILE_SIZE * 0.5)
			var depth := _run_depth(surface, _voxel_height(float(heightmap[tz * CHUNK_SIZE + tx])))
			var vein := _live_vein_at(world_xz, depth, seed_v, depleted, veins)
			if vein.is_empty():
				continue
			out.append({
				"position": Vector3(world_xz.x, h + VEIN_DEPOSIT_HEIGHT * 0.5, world_xz.y),
				# The same point relative to the chunk's corner: exact in float32 at any distance.
				"local_position": Vector3(
					(float(tx) + 0.5) * TILE_SIZE, h + VEIN_DEPOSIT_HEIGHT * 0.5, (float(tz) + 0.5) * TILE_SIZE),
				"size":     deposit_size,
				"color":    _material_color(str(vein["material"])),
			})
	return out

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

static func _voxel_height(raw_height: float) -> float:
	return floor(raw_height / STEP_HEIGHT) * STEP_HEIGHT

func _base_runs_for_tile(tile: Vector2i) -> Array:
	return _query._base_runs_for_tile(tile)

func _base_top_for_tile(tile: Vector2i) -> float:
	return _query._base_top_for_tile(tile)

## A tile's resolved runs straight off a chunk heightmap (the mesher's read path,
## which never touches the terrain sampler). `cache` memoises the answer by global
## tile key for the duration of ONE chunk build: a tile's runs are read by the tile
## itself and by each of its four neighbours, and the answer is a pure function of
## the heightmap plus the tile's edits, so a build's worth of reuse is exact (see
## `collect_build_runs`).
##
## Phase 42 review pass 9 — STATIC, and the edits arrive as the gathered map (`edits["gx,gz"]`,
## absent meaning none — see `gather_build_input`). The old body read `_edits` itself, which is
## exactly what made this half main-thread-only.
static func _column_runs(heightmap: Array, chunk_pos: Vector2i, tx: int, tz: int, cache: Dictionary, edits: Dictionary) -> Array:
	var gx := chunk_pos.x * CHUNK_SIZE + tx
	var gz := chunk_pos.y * CHUNK_SIZE + tz
	var key := _tile_key(Vector2i(gx, gz))
	if cache.has(key):
		return cache[key]
	var top := _voxel_height(float(heightmap[tz * CHUNK_SIZE + tx]))
	var base: Array = []
	if top > BEDROCK_DEPTH:
		base.append({ "bottom": BEDROCK_DEPTH, "top": top, "material": "" })
	var runs := VoxelRuns.apply_run_ops(base, edits.get(key, []))
	cache[key] = runs
	return runs

## A neighbour tile's runs, or an EMPTY list when they are UNKNOWN — a tile across a
## chunk edge whose chunk is not built.
##
## An unknown neighbour reads as "nothing is there", so the column that HAS the
## material emits the whole facing wall. That is what keeps the rendered shell
## independent of the ORDER the streamed chunks were built in. It used to answer
## `null` and emit no wall at all, which is not a guarantee a streamed world can
## make: chunks are built nearest-first, so the neighbour that is *waited for* is
## often the one built LATER — and nothing rebuilds a chunk when its neighbour
## arrives, so a chunk built before its higher neighbour left that seam face
## unemitted for good (a see-through slot at every such seam and around the
## streamed window). Assuming the unknown side is empty closes it whatever the
## order, and is duplicate-free either way: whichever side is built second
## subtracts the first side's runs and finds nothing left to emit, so each of the
## pair of facing walls is emitted exactly once — and a wall buried inside ground
## both sides fill is invisible. Pure geometry, no node state.
##
## Phase 42 review pass 9 — STATIC, and the ring's heightmaps arrive as the gathered
## `neighbours` map (`gather_build_input`). MEMBERSHIP IS THE UNKNOWN TEST: a chunk the gather
## did not carry is exactly the chunk `_heightmaps` did not hold at gather time.
static func _neighbour_runs(heightmap: Array, chunk_pos: Vector2i, tx: int, tz: int, cache: Dictionary, edits: Dictionary, neighbours: Dictionary) -> Array:
	if tx >= 0 and tx < CHUNK_SIZE and tz >= 0 and tz < CHUNK_SIZE:
		return _column_runs(heightmap, chunk_pos, tx, tz, cache, edits)
	var gx := chunk_pos.x * CHUNK_SIZE + tx
	var gz := chunk_pos.y * CHUNK_SIZE + tz
	var chunk := _tile_to_chunk(Vector2i(gx, gz))
	var ckey := _chunk_key(chunk)
	if not neighbours.has(ckey):
		return []   # unknown neighbour: read it as empty (see above)
	var hm: Array = neighbours[ckey]
	return _column_runs(hm, chunk, gx - chunk.x * CHUNK_SIZE, gz - chunk.y * CHUNK_SIZE, cache, edits)

## Angle a run's colour: a player-placed span takes its own material's colour, a
## natural one the ore field's material at its top slice (which is also how a vein gets its
## tint; its deposit marker reads the same field).
##
## Phase 42 review pass 8 — `biomes` and `colours` are the resolve pass's per-call memos
## (see `collect_build_runs`): a chunk build asks this 4356 times, and both the biome and
## the material → colour map answer the same handful of values each time.
##
## Phase 42 review pass 9 — the STATIC form is the resolved one (the worker's): the biome comes
## from the gathered `biomes` map. `_run_color` below is the instance ACCESSOR, which fills that
## map from the terrain slice when a caller (a test) passes none — the same accessor/resolved
## pair as `_within_stream` / `_within_stream_at` on ChunkManager.
##
## Phase 43 — a natural run's colour is the ORE FIELD's material at the run's top slice
## (`_run_depth` below `surface`, the tile's natural top), with `field` the resolve's
## `{ seed, depleted, veins }` (`_field`). A run is one colour top to bottom, so a vein shows
## where a column's top slice reaches it, not on the side walls of a deeper cut (a known
## simplification). An unknown `surface` (NAN) reads depth 0.
static func run_color(run: Dictionary, world_xz: Vector2, biomes: Dictionary, colours: Dictionary, surface: float = NAN, field: Dictionary = {}) -> Color:
	var material := str(run.get("material", ""))
	if material != "":
		return _material_color(material)
	var depth := 0.0 if is_nan(surface) else _run_depth(run, surface)
	return natural_color(world_xz, biomes, colours, depth, field)

func _run_color(run: Dictionary, world_xz: Vector2, biomes: Dictionary = {}, colours: Dictionary = {}) -> Color:
	return run_color(run, world_xz, _biomes_or_lookup(world_xz, biomes), colours,
		_base_top_for_tile(_world_to_tile(world_xz)), _field(_world_seed(), _vein_taken))

func set_season_tints(tints: Dictionary) -> void:
	_query.set_season_tints(tints)

func _terrain_material_for(biome: String) -> StandardMaterial3D:
	return _query._terrain_material_for(biome)

## The terrain's per-chunk material: per-column vertex colour, both faces
## rendered, so the shell is never see-through regardless of triangle winding.
func _make_terrain_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true
	mat.roughness    = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _on_chunk_ready(chunk_pos: Vector2i, heightmap: Array) -> void:
	build_chunk(chunk_pos, heightmap)

func _on_mine_requested(position: Vector3, normal: Vector3, player_id: String, exact: Dictionary = {}) -> void:
	_edit._on_mine_requested(position, normal, player_id, exact)

func inventory_for(player_id: String) -> Node:
	return _edit.inventory_for(player_id)

func _is_remote_actor(player_id: String) -> bool:
	return _edit._is_remote_actor(player_id)

func _push_inventory(player_id: String) -> void:
	_edit._push_inventory(player_id)

func _held_pick(inventory: Node) -> String:
	return _edit._held_pick(inventory)

func _on_place_requested(position: Vector3, normal: Vector3, player_id: String, material: String, exact: Dictionary = {}) -> void:
	_edit._on_place_requested(position, normal, player_id, material, exact)

func _on_cycle_requested() -> void:
	cycle_place_material()

## Apply an authoritative block edit received from the host. Re-runs the same
## tile-resolution and span math as mine_block/place_block, but does NOT touch
## the inventory or emit block_changed — the host already did both.
func _on_block_changed(action: String, position: Vector3, normal: Vector3, material: String) -> void:
	if is_authoritative:
		return   # host already applied this edit locally
	apply_block_change(action, position, normal, material)

func apply_block_change(action: String, position: Vector3, normal: Vector3, material: String) -> void:
	_edit.apply_block_change(action, position, normal, material)

func _resolve_edit_tile(action: String, position: Vector3, normal: Vector3, exact: Dictionary = {}) -> Dictionary:
	return _edit._resolve_edit_tile(action, position, normal, exact)

func _mine_span(runs: Array, world_pos: Vector3, normal: Vector3) -> Dictionary:
	return _edit._mine_span(runs, world_pos, normal)

func _place_span(runs: Array, world_pos: Vector3, normal: Vector3) -> Dictionary:
	return _edit._place_span(runs, world_pos, normal)

func _append_edit(tile: Vector2i, op: Dictionary) -> void:
	_edit._append_edit(tile, op)

func _set_edit_ops(tile_key: String, ops: Array) -> void:
	_edit._set_edit_ops(tile_key, ops)

func _bump_edit_rev(tile_key: String) -> void:
	_edit._bump_edit_rev(tile_key)

func _bump_chunk_rev(ckey: String) -> void:
	_edit._bump_chunk_rev(ckey)

func _index_edit(tile_key: String) -> void:
	_edit._index_edit(tile_key)

func _unindex_edit(tile_key: String) -> void:
	_edit._unindex_edit(tile_key)

func _reindex_edits() -> void:
	_edit._reindex_edits()

func _compact_ops(tile: Vector2i) -> Array:
	return _edit._compact_ops(tile)

## True when two run lists describe the same solid spans out of the same material.
## Static and pure — the comparison compaction needs, and the one its own rewrite
## is exact against.
static func _runs_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if not is_equal_approx(float(a[i]["bottom"]), float(b[i]["bottom"])):
			return false
		if not is_equal_approx(float(a[i]["top"]), float(b[i]["top"])):
			return false
		if str(a[i].get("material", "")) != str(b[i].get("material", "")):
			return false
	return true

## The height a pre-Phase-41 legacy edit stands for: a bare int or float, or a STRING
## that parses as one (a save that round-tripped through JSON can carry either).
## NAN means "not a legacy height at all", and `apply_edits` DROPS such an entry.
##
## Never defaulted to 0.0, for the reason `_normalise_ops` drops an op it cannot
## read: a value that is not a number casts silently (GDScript's `float()` answers
## 0.0 for a string like "not-a-height"), so defaulting turns a corrupt record into
## an absolute height at the world FLOOR — the column carved away — while a dict or
## an unsupported type raises. Both are worse than an inert dropped entry, which
## leaves the tile its natural ground.
static func _legacy_height_of(value: Variant) -> float:
	return RegionStore.legacy_height_of(value)

func _normalise_ops(ops: Array) -> Array:
	return _edit._normalise_ops(ops)

func _apply_edit(action: String, position: Vector3, normal: Vector3, material: String) -> Dictionary:
	return _edit._apply_edit(action, position, normal, material)

# --- Phase 137: loose ground settles ---

func _settle_note(tile: Vector2i) -> void:
	_edit._settle_note(tile)

func _settle_requeue_loaded(tile_keys: Array) -> void:
	_edit._settle_requeue_loaded(tile_keys)

## True when the fabric marks `material` granular (`granular` on the generated material resource).
static func is_granular(material: String) -> bool:
	var res: Variant = GameData.MATERIALS.get(material)
	return res != null and bool(res.get("granular"))

func settle_pending() -> int:
	return _edit.settle_pending()

func settle_tick(budget: int = SETTLE_BUDGET) -> int:
	return _edit.settle_tick(budget)

func _settle_tile(tile: Vector2i) -> bool:
	return _edit._settle_tile(tile)

func _apply_settle(position: Vector3, normal: Vector3, material: String) -> Dictionary:
	return _edit._apply_settle(position, normal, material)

# --- Coordinate helpers ---

## Phase 42 review pass 9 — STATIC: it is arithmetic on its argument, so the worker half of a
## build may call it (`material_for_biome` does).
static func _world_to_tile(xz: Vector2) -> Vector2i:
	return Vector2i(floori(xz.x / TILE_SIZE), floori(xz.y / TILE_SIZE))

## Phase 42 review pass 9 — STATIC for the same reason (`_neighbour_runs` runs on the worker).
static func _tile_to_chunk(tile: Vector2i) -> Vector2i:
	return Vector2i(floori(float(tile.x) / float(CHUNK_SIZE)), floori(float(tile.y) / float(CHUNK_SIZE)))

static func _tile_key(tile: Vector2i) -> String:
	return VoxelConsts.tile_key(tile)

## Tile X wrapped across the seam; the code lives in `VoxelConsts` (Phase 154).
static func canonical_tile(tile: Vector2i) -> Vector2i:
	return VoxelConsts.canonical_tile(tile)
func reset_world() -> void: _persist.reset_world()   # Phase 182 — `/regen world` (see VoxelPersist)

## Phase 42 review pass 9 — STATIC: the worker half of a build keys chunks too (`_neighbour_runs`).
static func _chunk_key(chunk_pos: Vector2i) -> String:
	# Phase 63: canonical key — chunk (C/2, z) and (-C/2, z) are the same chunk across the seam.
	var c := TerrainSlice.wrap_chunk(chunk_pos)
	return "%d,%d" % [c.x, c.y]

## Parse a "gx,gz" tile key back into a tile coordinate.
func _key_to_tile(key: String) -> Vector2i:
	return _parse_xy(str(key))

## Mark the chunk containing `tile` as dirty for persistence.
func _mark_dirty(tile: Vector2i) -> void:
	_dirty_chunks[_chunk_key(_tile_to_chunk(tile))] = true

## World XZ of a chunk's centre.
func _chunk_center_xz(chunk_pos: Vector2i) -> Vector2:
	var extent := float(CHUNK_SIZE * TILE_SIZE)
	return (Vector2(chunk_pos) + Vector2(0.5, 0.5)) * extent

func _biome_at(xz: Vector2) -> String:
	return _query._biome_at(xz)

## Phase 42 review pass 9 — the RESOLVED form of the biome read: it comes from the gathered map
## (`gather_biomes_for`), keyed by chunk, because a tile's biome IS its chunk's biome. No slice
## access, so the worker half may call it; the instance accessors below fill the map from the
## terrain slice for a caller that has none (an isolated test).
static func biome_of(world_xz: Vector2, biomes: Dictionary) -> String:
	var extent := float(CHUNK_SIZE * TILE_SIZE)
	var ckey := _chunk_key(Vector2i(floori(world_xz.x / extent), floori(world_xz.y / extent)))
	return str(biomes.get(ckey, DEFAULT_BIOME))

## Colour a natural (unplaced) terrain column at world_xz and `depth`, from the ore field and
## its biome's host rock — through the resolve pass's per-call colour memo when it has one
## (see `run_color`).
static func natural_color(world_xz: Vector2, biomes: Dictionary, colours: Dictionary, depth: float = 0.0, field: Dictionary = {}) -> Color:
	var material := material_for_biome(biome_of(world_xz, biomes), world_xz, depth,
		int(field.get("seed", 0)), field.get("depleted", {}), field.get("veins", {}))
	if not colours.has(material):
		colours[material] = _material_color(material)
	return icy(colours[material], world_xz.y)

## Polar ice: latitude (degrees) where the ground starts to whiten, and where it is fully ice.
const ICE_START_LAT := 72.0
const ICE_FULL_LAT := 80.0
const ICE_COLOR := Color(0.88, 0.94, 0.98)
## The ice blend is stepped in eighths so a latitude band merges into a few big quads, not one per tile.
const ICE_STEPS := 8.0

## `colour` of the ground at world Z `world_z` (metres), whitened toward ice by latitude: the poles of a
## planet like Earth are frozen. Pure of the world position, so every build agrees.
static func icy(colour: Color, world_z: float) -> Color:
	var lat := absf(TerrainSlice.latitude_at(world_z))
	if lat <= ICE_START_LAT:
		return colour
	var t := snappedf(smoothstep(ICE_START_LAT, ICE_FULL_LAT, lat), 1.0 / ICE_STEPS)
	return colour.lerp(ICE_COLOR, t)

## True when the chunk row sits in the frozen sea zone (water there is ice, not liquid).
static func is_frozen_chunk(chunk_pos: Vector2i) -> bool:
	return absf(TerrainSlice.latitude_of(chunk_pos.y)) >= ICE_FULL_LAT

func shown_biome_at(world_xz: Vector2) -> String:
	return _query.shown_biome_at(world_xz)

func _chunk_biome_memo(chunk: Vector2i) -> String:
	return _query._chunk_biome_memo(chunk)

## Drop the `shown_biome_at` memo (a world reset).
func reset_shown_biomes() -> void:
	_shown_biomes.clear()

## The instance ACCESSOR form of `natural_color`: with no gathered map it asks the terrain slice
## for this position's biome, in exactly the shape `gather_biomes_for` builds.
func _natural_color(world_xz: Vector2, biomes: Dictionary = {}, colours: Dictionary = {}, depth: float = 0.0) -> Color:
	return natural_color(world_xz, _biomes_or_lookup(world_xz, biomes), colours, depth,
		_field(_world_seed(), _vein_taken))

func _biomes_or_lookup(world_xz: Vector2, biomes: Dictionary) -> Dictionary:
	return _query._biomes_or_lookup(world_xz, biomes)

## Resolve a material key to its terrain colour (falling back to green for
## unknown keys). Pure (a `const` lookup), so the worker half may call it.
static func _material_color(material: String) -> Color:
	return MATERIAL_COLORS.get(material, FALLBACK_TERRAIN_COLOR)

func column_top_at_tile(tile: Vector2i) -> float:
	return _query.column_top_at_tile(tile)

func _rebuild_chunk_at_tile(tile: Vector2i) -> void:
	_build._rebuild_chunk_at_tile(tile)

func _rebuild_chunk(chunk: Vector2i) -> void:
	_build._rebuild_chunk(chunk)

func _touched_chunks(tile: Vector2i) -> Array:
	return _build._touched_chunks(tile)
