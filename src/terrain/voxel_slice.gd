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
##   legacy_edit_ops(height, base_top, materials) -> Array   (static, pure)
##   runs_topping_at(runs, y)             -> Dictionary       (static, pure)
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

## CHUNK_SIZE is defined once on TerrainSlice and accessed via terrain_slice.CHUNK_SIZE.
## The local alias below keeps internal uses readable without duplicating the value.
const CHUNK_SIZE  := 64        # alias — authoritative copy lives in TerrainSlice
const TILE_SIZE   := 0.5       # world units per tile (XZ) — half the former 1.0 size
const STEP_HEIGHT := 0.125     # world units per quantised height step (smooth, walkable — no jumps)
const BLEND_TILES := 4.0     # width of the dithered biome border band, in tiles (Phase 49)
## Phase 41 — the world's FLOOR. It replaces the old `MIN_HEIGHT := 0.0`, which was
## "bedrock" only in the sense that mining stopped at zero: the ground has real
## thickness now, so a column is solid from BEDROCK_DEPTH up to its surface, a
## tunnel has room to exist underneath it, and mining descends one STEP_HEIGHT at
## a time until the floor refuses. MAX_HEIGHT stays the build cap.
const BEDROCK_DEPTH := -8.0    # cannot mine below this — the world's floor
const MAX_HEIGHT    := 16.0    # build cap — cannot place above this

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
const FALLBACK_TERRAIN_COLOR := Color(0.35, 0.60, 0.28)

## Small raised deposit geometry: purely VISUAL — a marker on a column whose top slice
## lies inside a LIVE vein (Phase 43; it was every tile a uniform roll called rare). The
## run's height and collision are unchanged.
const VEIN_DEPOSIT_HEIGHT := 0.22
## Inset from the tile edge, so adjacent deposits never touch and the tile grid
## stays readable.
const VEIN_DEPOSIT_INSET := 0.16

## Active chunk containers keyed by "x,y" string.
var _chunks: Dictionary = {}
## Base heightmaps keyed by "x,y" string (the unedited noise terrain).
var _heightmaps: Dictionary = {}
## Phase 49 — generated (not built) neighbour maps, see `_generated_heightmap`.
var _guess_heightmaps: Dictionary = {}
## The world seed the cached guesses were generated under; a different seed throws them all
## away (`_sync_guess_seed`), since the same chunk now has a different surface.
var _guess_seed: int = 0
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

## Set by game_root: terrain (biome + base height) and inventory (material flow).
var terrain_slice: Node = null
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

## The ONE terrain material every chunk mesh of this slice shares — the surface mesh and,
## on a chunk that carries a rare vein, the deposit overlay. Built once, in `_ready()` (and
## on first use for an isolated slice that never enters the tree), and reused for every
## rebuild: it used to be a fresh `StandardMaterial3D` per `_terrain_material()` call, i.e.
## twice per chunk build and two more on every edit rebuild, re-stream or self-heal, which
## is material churn proportional to the (streamed) rebuild count rather than to the slice.
var _terrain_mat: StandardMaterial3D = null

## Single world-level safety floor shared by all chunks (prevents the player from
## ever falling through the world). Created once in _ready(). It sits one unit
## BELOW BEDROCK_DEPTH: the terrain's own runs are the ground, and a floor slab
## higher than them would block a player mining down to the floor.
var _world_floor: StaticBody3D = null

func _ready() -> void:
	# One material for every terrain mesh this slice ever builds (see `_terrain_mat`).
	_terrain_mat = _make_terrain_material()
	# Phase 43 — fill the ore field's material band table HERE, on the main thread, before any
	# worker can exist. It replaces the Phase 42 per-biome roll table and inherits its contract:
	# a `static var` on a script a chunk-build task reaches (`build_runs` → `natural_color` →
	# `material_for_biome` → `OreField.vein_at` → `OreField.allows` → `OreField.band_of`), so it
	# is WRITTEN here, before the tree streams anything, and read-only afterwards. The bands
	# come off the generated fabric resources (`depthBand`, `leyGated`), which is why this
	# cannot be a `const`.
	OreField.warm()
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

## Build (or rebuild) the mesh and collision for one chunk.
##
## Phase 42 — `arrays` is the optional result of a `build_chunk_arrays()` call made
## on a WORKER, and `revision` is the `chunk_revision` it was dispatched at (see
## `chunk_revision`); omit both for the synchronous build, which resolves its own
## input and is what the bus path, the edit path and every isolated test use.
##
## Returns TRUE when a mesh was attached, FALSE when the call was a no-op. Two refusals:
## a worker result whose revision has moved on, and (Phase 42 review) a worker result that
## carried NOTHING — a failed task. The second one used to fall through to the synchronous
## branch below and rebuild the whole chunk on the main thread, which is exactly the stall
## the worker exists to remove, done SILENTLY. It is a refusal now, and the manager answers
## a refusal with a fresh dispatch (see `ChunkManager._apply_build_entry`). The 2-arg form
## is untouched: an empty `arrays` with no revision means "build it here", on purpose.
func build_chunk(chunk_pos: Vector2i, heightmap: Array, arrays: Dictionary = {}, revision: int = -1) -> bool:
	var key := _chunk_key(chunk_pos)
	if revision >= 0 and revision != chunk_revision(chunk_pos):
		return false   # stale worker result: this chunk was rebuilt while it was in flight
	if arrays.is_empty() and revision >= 0:
		return false   # a worker build that produced nothing: refuse, do not rebuild here
	_chunk_revision[key] = chunk_revision(chunk_pos) + 1

	# Remember the base heightmap so edits can be reapplied on rebuild.
	_heightmaps[key] = heightmap
	if _guess_heightmaps.has(key):
		if _guess_heightmaps[key] != heightmap:
			Diag.warn("VoxelSlice: chunk %s was built from a heightmap that differs from the guess its neighbours were built against; seams may show" % key)
		_guess_heightmaps.erase(key)

	# Remove any previous version of this chunk.
	if _chunks.has(key):
		_chunks[key].queue_free()
		_chunks.erase(key)

	var root := Node3D.new()
	root.name = "Chunk_%s" % key
	add_child(root)
	_chunks[key] = root

	# --- Visual mesh + collision from ONE triangle soup ---
	# The rare-vein deposits below are added AFTER this, deliberately: they are
	# decoration, and a box the player can see but not stand on is the correct
	# read for "a vein showing through the ground". Collision built from this
	# surface can therefore never inherit one.
	var built: Dictionary = arrays
	if built.is_empty():
		# Only the SYNCHRONOUS path reaches this now: a worker result that carried nothing
		# was refused above rather than quietly rebuilt here (Phase 42 review).
		built = build_chunk_arrays(chunk_pos, heightmap, collect_build_runs(chunk_pos, heightmap))
	var surface := _mesh_from_arrays(built)
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = surface
	mesh_inst.material_override = _terrain_material()
	root.add_child(mesh_inst)

	# --- Rare-vein deposits: a SECOND mesh, from arrays the build already carries. ---
	# Phase 42 review pass 8 — this used to call `vein_deposits()` HERE, on the main thread,
	# walking all 4096 of the chunk's columns a second time (run replay + a biome and
	# material roll per tile) after the worker had already finished. The list is resolved
	# by `collect_build_runs` now and the boxes are emitted by `build_chunk_arrays`, so the
	# main thread only attaches what it is handed. They stay a separate mesh with no
	# collision, deliberately: they are decoration, and a box the player can see but not
	# stand on is the correct read for "a vein showing through the ground".
	var deposit_vertices: PackedVector3Array = built.get("deposit_vertices", PackedVector3Array())
	if not deposit_vertices.is_empty():
		var deposit_inst := MeshInstance3D.new()
		deposit_inst.mesh = _mesh_from_arrays({
			"vertices": built["deposit_vertices"],
			"normals":  built["deposit_normals"],
			"colors":   built["deposit_colors"],
			"indices":  built["deposit_indices"],
		})
		deposit_inst.material_override = _terrain_material()
		root.add_child(deposit_inst)

	# --- Collision: ONE ConcavePolygonShape3D per chunk, from the same triangles
	# the mesh shows. The per-row run-merge this replaces existed because
	# TILE_SIZE 0.5 would otherwise emit 4096 boxes per chunk; a single trimesh is
	# smaller than a handful of boxes AND describes everything the boxes could
	# not (ceilings, overhangs, a span of solid material). A CharacterBody3D does
	# not stand ON a concave shape directly — it collides WITH the static body
	# carrying it, which is the supported direction. ---
	var static_body := StaticBody3D.new()
	static_body.collision_layer = TERRAIN_COLLISION_LAYER
	static_body.collision_mask = 0
	var col_shape := CollisionShape3D.new()
	var trimesh := ConcavePolygonShape3D.new()
	trimesh.set_faces(built["collision"])
	# Both sides of a wall collide, so a body inside a tunnel is held by the roof
	# from below as well as by the floor from above.
	trimesh.backface_collision = true
	col_shape.shape = trimesh
	static_body.add_child(col_shape)
	root.add_child(static_body)
	return true

## Resolve every column a chunk build must READ into a plain table the pure builder can
## consume — plus the chunk's rare-vein deposit list.
##
## Phase 42 review pass 9 — this is a two-line ACCESSOR now, over a split that makes the whole
## resolve worker-legal. The main thread only GATHERS the plain state it reads
## (`gather_build_input`: the chunk's own edits plus the ring's, the ring chunks' heightmaps,
## the ring chunks' biomes), and the STATIC `build_runs()` does the per-tile work from nothing
## but that payload — so `ChunkManager._dispatch_build` can run the resolve AND the build on the
## worker, and the main thread stops paying the ~43 ms per-tile resolve per dispatch (measured;
## see the split probe). This wrapper keeps the synchronous callers — the bus path, an isolated
## test — on the same code path, and the answer is identical because the payload carries exactly
## what the old body read off the slice.
##
## The table covers the chunk's own tiles AND its one-tile ring (the seam neighbours
## whose runs the wall subtraction reads), keyed by global tile ("gx,gz") → Array of
## run records carrying `bottom`, `top`, `material` and the resolved `color`. A ring
## tile whose chunk is not built reads as an EMPTY list, which is the documented
## UNKNOWN-column path: the side that HAS the material emits the facing wall.
##
## Returns `{ "runs": <that table>, "deposits": [ { position, size, color } ] }`.
##
## Phase 42 review pass 8 — three things that pass fixed in the resolve half, all three of them
## still true of `build_runs()`:
##   * the DEPOSITS are resolved here, not in `build_chunk`. `vein_deposits()` walked
##     all 4096 of the chunk's own columns a second time (its own run replay, plus a
##     biome lookup and a material roll per tile) on the MAIN thread, on every build —
##     including every build the worker had just finished, i.e. the stall the worker
##     exists to remove, paid on the main thread right after it. The pure builder emits
##     the deposit BOXES from the list resolved here, so the worker owns all the
##     geometry and `build_chunk` only attaches.
##   * the BIOME is resolved by CHUNK, from the gathered map (`biome_of`). Biome assignment is a
##     per-chunk property, so a 66×66 ring asks for a handful of chunks' worth of answers rather
##     than 4356 — and the terrain-slice call behind each one is a method lookup plus a
##     world→chunk conversion.
##   * the material → COLOUR map is memoised per call. A biome rolls a handful of
##     materials out of a 100-weight table, so the same few colours came back 4356
##     times, each resolution going through `material_for_biome` again.
func collect_build_runs(chunk_pos: Vector2i, heightmap: Array) -> Dictionary:
	return build_runs(chunk_pos, heightmap, gather_build_input(chunk_pos, heightmap))

## Phase 42 review pass 9 — copy the mutable slice state a chunk's resolve reads, as PLAIN data,
## on the MAIN thread. Everything here is a read that must not happen on a worker: `_edits` and
## `_heightmaps` are the main thread's to mutate, and the biome comes from the terrain slice.
##
## Three things are gathered, and the resolve's reads map onto them exactly:
##   * `edits` — the ops of every tile in the chunk PLUS its one-tile ring that HAS ops
##     (deep-copied, because the main thread can still append to an op list while the worker
##     reads it). An absent key means "no ops for this tile", which is what `_edits.get` said.
##   * `neighbour_heightmaps` — the ring's chunks' maps, for the tiles the ring reaches into.
##     MEMBERSHIP IS THE ANSWER: a chunk absent here is the UNKNOWN neighbour `_neighbour_runs`
##     reads as empty, so the payload carries that decision rather than re-deriving it later.
##   * `biomes` — the biome of every chunk the ring touches, keyed by chunk. A tile's biome is
##     its chunk's biome, so this is the host-rock half of the colour step.
##
## Phase 43 — and the ORE FIELD's two inputs, the other half of the colour step:
##   * `seed` — the world seed the field is a function of (`_world_seed`).
##   * `depleted` — vein id → units taken (`_vein_taken`, copied), so an exhausted vein
##     renders as host rock. It is the whole index, not a window: a vein's anchor tile can
##     sit outside the chunk's ring, and the index is one entry per vein ever mined.
func gather_build_input(chunk_pos: Vector2i, heightmap: Array) -> Dictionary:
	return {
		"edits":                _gather_edits(chunk_pos),
		"neighbour_heightmaps": _gather_neighbour_heightmaps(chunk_pos),
		"biomes":               gather_biomes_for(chunk_pos),
		"seed":                 _world_seed(),
		"depleted":             _vein_taken.duplicate(),
	}

## The edited tiles of the chunk + its one-tile ring, deep-copied. It walks the CHUNK INDEX
## (`_edits_by_chunk`) and not the whole `_edits` log, so it is proportional to how much has
## been edited around THIS chunk; a fresh world gathers nothing at all.
##
## Phase 42 review pass 10 — this used to iterate every key in `_edits` and `split(",")` its
## string to test it against the window bounds, i.e. one string split per edit in the WORLD
## per dispatch (the row's measurement), even when nothing near the chunk had been touched.
## The ring is at most 3×3 chunks (`_ring_chunks`), and every tile of the chunk+ring window
## belongs to one of those chunks, so reading their three buckets IS the window.
func _gather_edits(chunk_pos: Vector2i) -> Dictionary:
	var out: Dictionary = {}
	if _edits_by_chunk.is_empty():
		return out
	for chunk in _ring_chunks(chunk_pos):
		var bucket: Dictionary = _edits_by_chunk.get(_chunk_key(chunk), {})
		for key in bucket:
			out[key] = _edits[key].duplicate(true)
	return out

## True when any tile of `chunk_pos` carries an edit op.
func has_edits_in_chunk(chunk_pos: Vector2i) -> bool:
	return _edits_by_chunk.has(_chunk_key(chunk_pos))

## The heightmaps of the chunks the ring reads across, when they are KNOWN.
##
## Phase 42 review pass 10 — the maps are shared BY REFERENCE, deliberately, and this is the
## stated half of an asymmetry with `_gather_edits` (which DEEP-COPIES the op lists). The
## reason is which of the two the main thread ever mutates in place: an edit op list is
## APPENDED to (`_append_edit` does `ops.append` on the very array the worker may be reading),
## so it must be copied; a heightmap array is only ever REPLACED wholesale (`build_chunk`
## stores a freshly generated one, `_prune_heightmaps` erases the entry) and never mutated in
## place, so sharing it is safe — the worker only reads it, and a rebuild that regenerates the
## map hands the worker a NEW array rather than editing the array it holds. If a future change
## ever writes a heightmap IN PLACE, it must copy here too. The same holds for the cached
## GUESS maps (`_generated_heightmap`): they are shared by reference too, and a guess is
## assumed to equal the map the chunk's own build later stores — `build_chunk` warns when a
## caller hands it a different one (tests, a future structure-flattening pass).
func _gather_neighbour_heightmaps(chunk_pos: Vector2i) -> Dictionary:
	var out: Dictionary = {}
	for chunk in _ring_chunks(chunk_pos):
		var ckey := _chunk_key(chunk)
		if _heightmaps.has(ckey):
			out[ckey] = _heightmaps[ckey]
		else:
			var guess: Array = [] if chunk == chunk_pos else _generated_heightmap(chunk, ckey)
			if not guess.is_empty():
				out[ckey] = guess
	return out

## Phase 49 — an UNBUILT neighbour's heightmap, from the terrain's deterministic generator
## (identical to what its own build will store), so two chunks built from the same first
## ring each see the other's real surface instead of an empty column and neither emits a
## bedrock-to-top seam wall. Kept apart from `_heightmaps` (which means "built"): a guess
## is dropped when that chunk builds or leaves the ring. Empty when no generator is wired.
func _generated_heightmap(chunk: Vector2i, ckey: String) -> Array:
	_sync_guess_seed()
	if _guess_heightmaps.has(ckey):
		return _guess_heightmaps[ckey]
	if terrain_slice == null or not terrain_slice.has_method("generate_heightmap"):
		return []
	var hm: Array = terrain_slice.generate_heightmap(chunk)
	_guess_heightmaps[ckey] = hm
	while _guess_heightmaps.size() > GUESS_CACHE_MAX:
		_guess_heightmaps.erase(_guess_heightmaps.keys()[0])
	return hm

## The heightmap a chunk's own build should use: a guess already generated for it when one is
## cached (consumed, since `build_chunk` stores it as the real map), else a fresh one from the
## generator. Each chunk's surface is therefore generated ONCE, whether a neighbour's gather
## got to it first or its own dispatch did; the neighbour's guess used to be thrown away and
## the same noise recomputed on the main thread at dispatch.
## Callers that pass the result to `build_chunk` keep the guess == real-map invariant that the
## neighbours' seams rely on. Empty when no generator is wired.
func take_heightmap_for_build(chunk: Vector2i) -> Array:
	_sync_guess_seed()
	var ckey := _chunk_key(chunk)
	if _guess_heightmaps.has(ckey):
		var hm: Array = _guess_heightmaps[ckey]
		_guess_heightmaps.erase(ckey)
		return hm
	if terrain_slice == null or not terrain_slice.has_method("generate_heightmap"):
		return []
	return terrain_slice.generate_heightmap(chunk)

## Drop every cached guess when the world seed changed under them (`set_world_seed` runs
## before any chunk streams in production, but a re-seed mid-session must not serve a map
## of the old world).
func _sync_guess_seed() -> void:
	var seed_now := _world_seed()
	if seed_now != _guess_seed:
		_guess_seed = seed_now
		_guess_heightmaps.clear()

## The biome of every chunk the ring touches, keyed by chunk — what the colour step needs.
## The gather is ≤ 9 terrain-slice calls, against the 4356 a per-tile lookup would make.
func gather_biomes_for(chunk_pos: Vector2i) -> Dictionary:
	var out: Dictionary = {}
	for chunk in _ring_chunks(chunk_pos):
		out[_chunk_key(chunk)] = _biome_at(_chunk_world_center(chunk))
	return out

## The distinct chunks a chunk's tile+ring spans: at most 3×3, because the ring is one tile wide.
func _ring_chunks(chunk_pos: Vector2i) -> Array:
	var first := chunk_pos * CHUNK_SIZE + Vector2i(-1, -1)
	var last := chunk_pos * CHUNK_SIZE + Vector2i(CHUNK_SIZE, CHUNK_SIZE)
	var c0 := _tile_to_chunk(first)
	var c1 := _tile_to_chunk(last)
	var out: Array = []
	for cz in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			out.append(Vector2i(cx, cz))
	return out

## The world XZ centre of a chunk — a position `_biome_at` maps back to that same chunk.
static func _chunk_world_center(chunk_pos: Vector2i) -> Vector2:
	var extent := float(CHUNK_SIZE * TILE_SIZE)
	return Vector2((float(chunk_pos.x) + 0.5) * extent, (float(chunk_pos.y) + 0.5) * extent)

## PURE resolve — no node, no bus, no slice state, so it is legal on a worker thread. The only
## inputs are the chunk, its heightmap and the payload `gather_build_input` copied off the
## slice; `build_chunk_arrays` consumes what this returns.
static func build_runs(chunk_pos: Vector2i, heightmap: Array, input: Dictionary) -> Dictionary:
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
## biome's `surfaceMaterial` (e.g. Grass): nothing in the build consumes it yet — the
## Grass/Soil material entities and mining-yields-Soil are still open — but it is part of
## the style so that consumer has one place to read it, and a test pins that every biome
## declares one.
##
## Thread note: the worker half of the build calls this through `build_runs`. It only READS
## `GameData.BIOMES`, which is a fully preloaded constant table, so that is safe today; if
## `GameData` ever fills lazily, resolve the styles on the main thread and pass them in the
## gathered payload instead.
static func surface_style(biome: String) -> Dictionary:
	var b: Variant = GameData.BIOMES.get(biome, null)
	if b == null or b.get("surfaceTint") == null:
		return {}
	return {
		"top":      Color.from_string(str(b.get("surfaceTint")), FALLBACK_TERRAIN_COLOR),
		"soil":     Color.from_string(str(b.get("soilTint")), FALLBACK_TERRAIN_COLOR),
		"depth":    float(b.get("topsoilDepth")),
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
	entry["top_color"] = style["top"]
	entry["soil_color"] = style["soil"]
	entry["soil_depth"] = float(style["depth"])

## Phase 49 — the biome whose surface a tile WEARS. Within `BLEND_TILES` of a chunk border, a
## tile may show the biome across that border instead of its own: the chance falls from one half
## at the border to zero at the band's inner edge, and a coordinate hash (no RNG, no thread
## state) decides, so every build of the tile agrees and the border reads as a dithered band
## rather than a straight cut. Only the colour is blended; the ore field still reads `own`.
static func blended_biome(world_xz: Vector2, biomes: Dictionary, own: String) -> String:
	var extent := float(CHUNK_SIZE * TILE_SIZE)
	var cx := floori(world_xz.x / extent)
	var cz := floori(world_xz.y / extent)
	var lx := world_xz.x - cx * extent
	var lz := world_xz.y - cz * extent
	# Distance (in tiles) to the nearest border on each axis, and the chunk step across it.
	var dx := minf(lx, extent - lx) / TILE_SIZE
	var dz := minf(lz, extent - lz) / TILE_SIZE
	var across := Vector2i(cx, cz)
	var d := dx
	if dx <= dz:
		across.x += -1 if lx < extent - lx else 1
	else:
		d = dz
		across.y += -1 if lz < extent - lz else 1
	if d >= BLEND_TILES:
		return own
	var other := str(biomes.get(_chunk_key(across), own))
	if other == own:
		return own
	var gx := floori(world_xz.x / TILE_SIZE)
	var gz := floori(world_xz.y / TILE_SIZE)
	var roll := float(((gx * 73856093) ^ (gz * 19349663)) & 0xffff) / 65536.0
	return other if roll < 0.5 * (1.0 - d / BLEND_TILES) else own

## Phase 43 — the ore field's per-call input: the seed, the depletion record and a fresh
## vein memo. Static and plain, so the worker half builds it from its payload.
static func _field(seed: int, depleted: Dictionary) -> Dictionary:
	return { "seed": seed, "depleted": depleted, "veins": {} }

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

## PURE chunk build — no node, no bus, no slice state, so it is legal to run on a
## worker thread. Everything it touches arrives as an argument.
##
##   chunk_pos : the chunk to build
##   heightmap : the chunk's own base heightmap
##   resolved  : the resolve result from `collect_build_runs`, i.e.
##               `{ "runs": <tile → runs table>, "deposits": [...] }`. A tile ABSENT from
##               the runs table falls back to the NATURAL column derived from `heightmap`,
##               which is what lets a caller holding only a map (the suite, a fresh probe)
##               build a chunk with no slice state at all; a PRESENT but EMPTY list is the
##               streamed world's UNKNOWN column. Phase 42 review pass 9 — the payload shape
##               is now REQUIRED rather than sniffed: the old fallback was
##               `resolved.get("runs", resolved)`, i.e. "does this dictionary happen to hold a
##               key called runs?", which silently reinterpreted a bare runs table as a
##               payload. Every caller in the tree passes a `collect_build_runs()` payload —
##               the only bare tables were the `{}`-for-natural probes, now `{ "runs": {} }` —
##               so the sniff is gone and an absent `runs` key reads as NO resolved columns,
##               which is the natural-column fallback (see `_column_for_cell`).
##
## Returns `{ vertices, normals, colors, indices, collision, quad_count, cell_count }`
## — the four arrays an ArrayMesh surface wants, plus the triangle soup the collision
## uses, built from the SAME quads so what the player sees and what they stand on
## cannot drift. `cell_count` is the faces a per-tile mesher would have emitted and
## `quad_count` is what the merge left, so the merge's effect is a number, not a claim.
##
## Phase 42 review pass 8 — and the rare-vein deposit BOXES are emitted here too, as
## `deposit_vertices` / `deposit_normals` / `deposit_colors` / `deposit_indices`. They are
## GEOMETRY ONLY: they never enter `collision`, because a deposit is decoration the player
## must not be able to stand on. Resolving the list is the main thread's job (it reads the
## edit log); turning it into triangles is not, so this is where the boxes are built.
##
## STATIC on purpose: the per-chunk faces are the same for every world, so the builder
## needs no instance state — and a worker task may hold no reference to a Node at all
## (a task that outlives the tree would otherwise call into a freed slice). Callers
## pass the script itself, not the wired slice (see ChunkManager.VoxelBuilder).
##
## The quads are GREEDY-MERGED: adjacent coplanar faces of one colour become a single
## rectangle, so a chunk whose surface is largely uniform emits a handful of quads
## instead of one per tile (4096 of them at TILE_SIZE 0.5). UVs are dropped with the
## merge — the terrain's material is per-vertex colour with no texture, and a merged
## rectangle has no per-tile UV mapping left to give.
static func build_chunk_arrays(chunk_pos: Vector2i, heightmap: Array, resolved: Dictionary) -> Dictionary:
	var origin_x := chunk_pos.x * CHUNK_SIZE * TILE_SIZE
	var origin_z := chunk_pos.y * CHUNK_SIZE * TILE_SIZE
	var runs: Dictionary = resolved.get("runs", {})
	var deposits: Array = resolved.get("deposits", [])

	# dir → emit-key → the group of tile cells that would emit the IDENTICAL face: the
	# same direction, plane, vertical span and colour. Merging only ever happens INSIDE a
	# group, which is what makes the key exactly the set of attributes a merged quad has
	# to share (direction, geometry, material/colour). Nested per DIRECTION so the key
	# itself fits: see `_group_cell` for why it is not one string any more.
	var groups: Dictionary = {}

	for tz in range(CHUNK_SIZE):
		for tx in range(CHUNK_SIZE):
			var col := _column_for_cell(chunk_pos, heightmap, runs, tx, tz)
			if col.is_empty():
				continue
			for run in col:
				var rbottom := float(run["bottom"])
				var rtop := float(run["top"])
				var color: Color = run.get("color", FALLBACK_TERRAIN_COLOR)

				# Top face — only where nothing is solid directly above this run, so the
				# natural ground under a placed block stays hidden (and a ledge under an
				# overhang still shows).
				if not runs_cover_y(col, rtop + STEP_HEIGHT * 0.5):
					_group_cell(groups, "up", rtop, rtop, rtop, run.get("top_color", color), tx, tz)

				# Underside face — the CEILING of a tunnel, or an overhang. The span below
				# the run is empty per-column, which is the per-column reading of "a
				# neighbour run ends above the local run". The base run never emits one:
				# BEDROCK_DEPTH is the world's floor, not a gap.
				if rbottom > BEDROCK_DEPTH and not runs_cover_y(col, rbottom - STEP_HEIGHT * 0.5):
					_group_cell(groups, "down", rbottom, rbottom, rbottom, color, tx, tz)

				# Side walls — every part of this run the neighbour does NOT fill.
				# Subtracting per neighbour is what keeps a higher neighbour's own wall
				# (it emits that one) from being drawn twice, and what lets a wall span a
				# tunnel's height in one piece.
				_wall_cells(groups, chunk_pos, heightmap, runs, tx, tz, run, color,
					run.get("soil_color", color), rtop - float(run.get("soil_depth", 0.0)))

	var vertices  := PackedVector3Array()
	var normals   := PackedVector3Array()
	var colors    := PackedColorArray()
	var indices   := PackedInt32Array()
	var collision := PackedVector3Array()
	var quad_count := 0
	# `cell_count` is the number of faces BEFORE the merge — i.e. exactly what the
	# per-tile mesher emitted, one quad per tile per face. Kept in the result so the
	# merge's effect is a number a test can assert and a reviewer can quote, rather
	# than a claim in a comment.
	var cell_count := 0
	for dir in groups:
		var buckets: Dictionary = groups[dir]
		for key in buckets:
			var g: Dictionary = buckets[key]
			cell_count += g["cells"].size()
			for rect in _merge_rects(g["cells"]):
				quad_count += _emit_rect(vertices, normals, colors, indices, collision,
					g, rect, origin_x, origin_z)
	# The rare-vein deposit boxes (see the docstring): geometry only, never collision.
	# Off the resolved list, so this half of the build is the worker's.
	var deposit_vertices := PackedVector3Array()
	var deposit_normals  := PackedVector3Array()
	var deposit_colors   := PackedColorArray()
	var deposit_indices  := PackedInt32Array()
	for deposit in deposits:
		MeshUtil.add_box_arrays(deposit_vertices, deposit_normals, deposit_colors, deposit_indices,
			deposit["position"], deposit["size"], deposit["color"])
	return {
		"vertices":    vertices,
		"normals":     normals,
		"colors":      colors,
		"indices":     indices,
		"collision":   collision,
		"quad_count":  quad_count,
		"cell_count":  cell_count,
		"deposit_vertices": deposit_vertices,
		"deposit_normals":  deposit_normals,
		"deposit_colors":   deposit_colors,
		"deposit_indices":  deposit_indices,
	}

## Queue this run's exposed side walls against all four neighbours. The NEIGHBOUR
## column comes from the same table the builder was handed — an EMPTY list is the
## UNKNOWN neighbour, so this side emits its whole facing wall (see `_neighbour_runs`
## for why that is the order-independent choice).
static func _wall_cells(groups: Dictionary, chunk_pos: Vector2i, heightmap: Array, runs: Dictionary, tx: int, tz: int, run: Dictionary, color: Color, soil_color: Color = Color.BLACK, soil_line: float = INF) -> void:
	var dirs: Array = [
		{ "dir": "north", "ntx": tx,     "ntz": tz - 1 },
		{ "dir": "south", "ntx": tx,     "ntz": tz + 1 },
		{ "dir": "west",  "ntx": tx - 1, "ntz": tz     },
		{ "dir": "east",  "ntx": tx + 1, "ntz": tz     },
	]
	for d in dirs:
		var dir := str(d["dir"])
		var neighbour := _column_for_tile(chunk_pos, heightmap, runs, int(d["ntx"]), int(d["ntz"]))
		for seg in subtract_runs(run, neighbour):
			var bottom := float(seg["bottom"])
			var top := float(seg["top"])
			if top <= bottom:
				continue
			var plane := _wall_plane(chunk_pos, dir, tx, tz)
			# Soil above the soil line, rock below it (soil_line is INF with no topsoil, so
			# the whole wall is the run's colour).
			if soil_line == INF or top <= soil_line:
				_group_cell(groups, dir, plane, bottom, top, color, tx, tz)
			elif bottom >= soil_line:
				_group_cell(groups, dir, plane, bottom, top, soil_color, tx, tz)
			else:
				_group_cell(groups, dir, plane, bottom, soil_line, color, tx, tz)
				_group_cell(groups, dir, plane, soil_line, top, soil_color, tx, tz)

## The world coordinate a wall's plane sits at — its grouping coordinate, so two tiles'
## walls only ever merge when they are actually coplanar.
static func _wall_plane(chunk_pos: Vector2i, dir: String, tx: int, tz: int) -> float:
	match dir:
		"north": return chunk_pos.y * CHUNK_SIZE * TILE_SIZE + tz * TILE_SIZE
		"south": return chunk_pos.y * CHUNK_SIZE * TILE_SIZE + (tz + 1) * TILE_SIZE
		"west":  return chunk_pos.x * CHUNK_SIZE * TILE_SIZE + tx * TILE_SIZE
	return chunk_pos.x * CHUNK_SIZE * TILE_SIZE + (tx + 1) * TILE_SIZE

## Add one tile cell to the group of faces it would emit, inside its DIRECTION's bucket.
## The key carries everything a merged quad has to share: plane, vertical span and colour.
##
## Phase 42 review pass 8 — this used to build a STRING key (`"%s|%.4f|%.4f|%.4f|%s"` plus
## `Color.to_html`), i.e. three float formattings and a hex colour string per face cell —
## roughly 25k throwaway strings for one 64×64 chunk, on the builder's own (worker) budget
## and again on every edit rebuild. The key is now a `Vector4i` of the same four values
## QUANTISED to 1/10000, which is exactly the precision `%.4f` kept, so the grouping is
## identical — no span merges that did not merge before. The three GEOMETRY components fit
## int32 by a wide margin: a wall plane is a multiple of TILE_SIZE 0.5 and bounded by the
## world extent (|plane·10⁴| ≤ 4.1e7), and a run's span is bounded by
## BEDROCK_DEPTH..MAX_HEIGHT (|y·10⁴| ≤ 1.6e5).
##
## Phase 42 review pass 9 — the fourth component does NOT fit, and the old comment claimed it
## did ("`to_rgba32()` is an int32 by definition"): it is a packed uint32, so opaque white is
## `4294967295`, while `Vector4i` keeps an int32 per component — the high bit is kept as the
## SIGN (`-1` for that same white; measured on 4.7). The wrap is a BIJECTION (the component
## reads back as `& 0xFFFFFFFF` == the packed value), so two distinct colours can never land
## on one key and the grouping is exactly what the old string key grouped: what was wrong was
## the comment, not the key. `_test_voxel_group_key_colour_band` pins both halves of that.
##
## The DIRECTION is the outer key rather than a fifth component, because a Vec4 runs out of
## axes — and it must be in the key: an "up" face and a "down" face at the same plane and
## span would otherwise merge into one quad with one direction, which is a missing floor or
## a missing ceiling.
static func _group_cell(groups: Dictionary, dir: String, plane: float, bottom: float, top: float, color: Color, tx: int, tz: int) -> void:
	var buckets: Dictionary = groups.get(dir, {})
	var key := Vector4i(roundi(plane * 10000.0), roundi(bottom * 10000.0),
		roundi(top * 10000.0), color.to_rgba32())
	var g: Dictionary = buckets.get(key, {})
	if g.is_empty():
		g = {
			"dir": dir, "plane": plane, "bottom": bottom, "top": top,
			"color": color, "cells": {},
		}
		buckets[key] = g
		groups[dir] = buckets
	g["cells"][tz * CHUNK_SIZE + tx] = true

## A column read from the resolve table, falling back to the NATURAL column off the
## chunk's own heightmap when the caller did not resolve it (see `build_chunk_arrays`).
static func _column_for_cell(chunk_pos: Vector2i, heightmap: Array, runs: Dictionary, tx: int, tz: int) -> Array:
	var key := _tile_key(Vector2i(chunk_pos.x * CHUNK_SIZE + tx, chunk_pos.y * CHUNK_SIZE + tz))
	if runs.has(key):
		return runs[key]
	var top := _voxel_height(float(heightmap[tz * CHUNK_SIZE + tx]))
	if top <= BEDROCK_DEPTH:
		return []
	return [{ "bottom": BEDROCK_DEPTH, "top": top, "material": "", "color": FALLBACK_TERRAIN_COLOR }]

## A column for an arbitrary tile: inside the chunk it is `_column_for_cell` (with the
## same natural fallback), outside it must be IN the table or it is the UNKNOWN
## neighbour — an empty list, never a guess.
static func _column_for_tile(chunk_pos: Vector2i, heightmap: Array, runs: Dictionary, tx: int, tz: int) -> Array:
	if tx >= 0 and tx < CHUNK_SIZE and tz >= 0 and tz < CHUNK_SIZE:
		return _column_for_cell(chunk_pos, heightmap, runs, tx, tz)
	var key := _tile_key(Vector2i(chunk_pos.x * CHUNK_SIZE + tx, chunk_pos.y * CHUNK_SIZE + tz))
	if runs.has(key):
		return runs[key]
	return []

## Greedy-mesh one group's tile cells into the fewest rectangles: sweep the cells in
## row-major order, take the widest run of cells on the current row, then extend that
## strip downward while every cell below it still belongs to the group. Deterministic
## (the sweep order is the tile index), so a chunk's arrays are reproducible — which is
## what lets a test compare two builds of the same chunk.
static func _merge_rects(cells: Dictionary) -> Array:
	var out: Array = []
	var used: Dictionary = {}
	var order: Array = cells.keys()
	order.sort()
	for idx in order:
		if used.has(idx):
			continue
		var tx: int = int(idx) % CHUNK_SIZE
		var tz: int = (int(idx) - tx) / CHUNK_SIZE
		var w := 1
		while tx + w < CHUNK_SIZE and cells.has(tz * CHUNK_SIZE + tx + w) and not used.has(tz * CHUNK_SIZE + tx + w):
			w += 1
		var h := 1
		while tz + h < CHUNK_SIZE:
			var complete := true
			for dx in range(w):
				var probe := (tz + h) * CHUNK_SIZE + tx + dx
				if not cells.has(probe) or used.has(probe):
					complete = false
					break
			if not complete:
				break
			h += 1
		for dz in range(h):
			for dx in range(w):
				used[(tz + dz) * CHUNK_SIZE + tx + dx] = true
		out.append({ "tx": tx, "tz": tz, "w": w, "h": h })
	return out

## Emit one merged rectangle as two triangles, and the same two into the collision
## soup. The winding matches the per-tile quads the merge replaces, so a face's normal
## points where it always did (the material renders both faces regardless; this is for
## lighting). Returns the number of quads emitted (always 1) so the caller can count.
static func _emit_rect(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, collision: PackedVector3Array, g: Dictionary, rect: Dictionary, origin_x: float, origin_z: float) -> int:
	var bottom := float(g["bottom"])
	var top    := float(g["top"])
	var plane  := float(g["plane"])
	var color: Color = g["color"]
	var x0 := origin_x + int(rect["tx"]) * TILE_SIZE
	var x1 := x0 + int(rect["w"]) * TILE_SIZE
	var z0 := origin_z + int(rect["tz"]) * TILE_SIZE
	var z1 := z0 + int(rect["h"]) * TILE_SIZE

	var a := Vector3.ZERO
	var b := Vector3.ZERO
	var c := Vector3.ZERO
	var d := Vector3.ZERO
	var normal := Vector3.UP
	match str(g["dir"]):
		"up":   # horizontal: `plane` is the y both faces sit on
			a = Vector3(x0, plane, z0); b = Vector3(x0, plane, z1)
			c = Vector3(x1, plane, z1); d = Vector3(x1, plane, z0)
		"down":
			normal = Vector3.DOWN
			a = Vector3(x0, plane, z0); b = Vector3(x1, plane, z0)
			c = Vector3(x1, plane, z1); d = Vector3(x0, plane, z1)
		"north":   # vertical walls: `plane` is the fixed x/z of the wall
			normal = Vector3(0, 0, -1)
			a = Vector3(x0, top, plane); b = Vector3(x1, top, plane)
			c = Vector3(x1, bottom, plane); d = Vector3(x0, bottom, plane)
		"south":
			normal = Vector3(0, 0, 1)
			a = Vector3(x1, top, plane); b = Vector3(x0, top, plane)
			c = Vector3(x0, bottom, plane); d = Vector3(x1, bottom, plane)
		"west":
			normal = Vector3(-1, 0, 0)
			a = Vector3(plane, top, z1); b = Vector3(plane, top, z0)
			c = Vector3(plane, bottom, z0); d = Vector3(plane, bottom, z1)
		_:
			normal = Vector3(1, 0, 0)
			a = Vector3(plane, top, z0); b = Vector3(plane, top, z1)
			c = Vector3(plane, bottom, z1); d = Vector3(plane, bottom, z0)

	var base := vertices.size()
	vertices.append(a); normals.append(normal); colors.append(color)
	vertices.append(b); normals.append(normal); colors.append(color)
	vertices.append(c); normals.append(normal); colors.append(color)
	vertices.append(d); normals.append(normal); colors.append(color)
	indices.append(base); indices.append(base + 1); indices.append(base + 2)
	indices.append(base); indices.append(base + 2); indices.append(base + 3)
	collision.append(a); collision.append(b); collision.append(c)
	collision.append(a); collision.append(c); collision.append(d)
	return 1

## Turn a `build_chunk_arrays()` result into the ArrayMesh a chunk node shows. Static
## and pure: an empty result yields an empty mesh rather than a surface with no
## triangles, which is what `add_surface_from_arrays` refuses.
static func _mesh_from_arrays(arrays: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if arrays.is_empty():
		return mesh
	var verts: PackedVector3Array = arrays.get("vertices", PackedVector3Array())
	if verts.is_empty():
		return mesh
	var surface: Array = []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = verts
	surface[Mesh.ARRAY_NORMAL] = arrays["normals"]
	surface[Mesh.ARRAY_COLOR]  = arrays["colors"]
	surface[Mesh.ARRAY_INDEX]  = arrays["indices"]
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	return mesh

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

## Free a chunk's visual + collision nodes without touching its base heightmap
## or any voxel edits. The heightmap is cached in `_heightmaps` so a later
## build_chunk() re-applies edits and restores the column exactly. Used by
## ChunkManager to stream chunks out of view.
##
## The cached map is then PRUNED down to what a loaded chunk can still ask about
## (see `_prune_heightmaps`): session-long retention is the memory this streaming
## is meant to bound, and a chunk nobody can reach for reads as UNKNOWN, which the
## mesher already handles by construction.
func unload_chunk(chunk_pos: Vector2i) -> void:
	var key := _chunk_key(chunk_pos)
	if _chunks.has(key):
		_chunks[key].queue_free()
		_chunks.erase(key)
	_prune_heightmaps(chunk_pos)

## Drop the base heightmaps of chunks that are no longer worth remembering: one
## that is unloaded AND not edge-adjacent to any loaded chunk.
##
## `_heightmaps` used to grow for the whole session — every chunk ever streamed in
## kept its `CHUNK_SIZE²` floats so a streamed-out neighbour could still answer with
## its real runs — which means a long walk held the whole route in memory. The KEPT
## set is the loaded window plus its one-tile ring: exactly the set a visible chunk
## can ask a NEIGHBOUR about, so a loaded chunk still subtracts against its
## neighbour's real runs. A chunk outside that ring reads as UNKNOWN instead, which
## is the documented, order-independent empty-neighbour path (the side carrying the
## material emits the facing wall, and the pruned chunk rebuilds from its heightmap
## when it is streamed back). Nothing is lost with the map: edits are keyed by
## TILE, and a pruned chunk's natural run comes from the same height function the
## map was sampled from.
##
## Indexed by chunk: unloading one chunk can only change the keep verdict of that chunk
## and its four edge neighbours, so only those five are probed (each against its own
## four neighbours) instead of scanning every loaded chunk and every stored map. A
## crossing unloads a dozen chunks in one frame; the full scan made that quadratic.
##
## The candidates are the full 3x3 around the unloaded chunk, not just its plus ring: a build
## also guesses its DIAGONAL neighbours' maps (`_ring_chunks` is 3x3, for the corner tile),
## and those guesses must be dropped when the chunk that caused them unloads. The keep rule
## itself is unchanged (loaded or edge-adjacent to a loaded chunk).
func _prune_heightmaps(around: Vector2i) -> void:
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var candidate := Vector2i(around.x + dx, around.y + dz)
			var kept := false
			for probe in _plus_ring(candidate):
				if _chunks.has(_chunk_key(probe)):
					kept = true
					break
			if not kept:
				var ckey := _chunk_key(candidate)
				_heightmaps.erase(ckey)
				_guess_heightmaps.erase(ckey)

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
func mine_block(world_pos: Vector3, normal: Vector3 = Vector3.UP, player_id: String = "") -> Dictionary:
	# Resolve the span BEFORE spending tool durability, so a blocked mine never
	# consumes the held pick (the repo's standing atomic-refusal rule).
	var probe := _resolve_edit_tile("mine", world_pos, normal)
	var tile: Vector2i = probe["tile"]
	var span := _mine_span(get_runs_at_tile(tile), world_pos, normal)
	if span.is_empty():
		return { "success": false, "material": "", "quantity": 0, "position": world_pos, "player_id": player_id }

	# The ACTOR's own pack: the durability spent and the yield credited are the
	# acting player's, which for a remote mine is the peer the intent came from.
	var inventory := inventory_for(player_id)

	# Tool durability: mining consumes the held pick. A broken pick blocks the
	# mine; bare-handed (no pick) mining is still allowed.
	var pick := _held_pick(inventory)
	if pick != "" and inventory != null and inventory.has_method("use_item"):
		if not inventory.use_item(pick, "mine"):
			return { "success": false, "material": "", "quantity": 0, "position": world_pos, "player_id": player_id }

	# Phase 43 — a NATURAL span yields what the ore field holds there: a live vein's
	# material and per-slice quantity (capped by what is left of its reserve), else the
	# biome's host rock, one unit. Resolved BEFORE the remove is appended, because the
	# depth it reads is the span's, measured from the tile's natural surface.
	var material := str(span["material"])
	var quantity := 1
	var vein: Dictionary = {}
	if material == "":
		var yielded := _natural_yield(tile, span)
		material = str(yielded["material"])
		quantity = int(yielded["quantity"])
		vein = yielded["vein"]
	_append_edit(tile, { "op": "remove", "bottom": span["bottom"], "top": span["top"] })
	_mark_dirty(tile)
	if not vein.is_empty():
		_record_depletion(vein, quantity)
		_mark_dirty(vein["anchor"])
	_rebuild_chunk_at_tile(tile)

	if inventory != null and inventory.has_method("add_item"):
		inventory.add_item(material, quantity)
	_push_inventory(player_id)

	var pos := Vector3(world_pos.x, float(span["top"]), world_pos.z)
	GameBus.block_mined.emit(material, quantity, pos)
	GameBus.block_changed.emit("mine", world_pos, normal, material)
	return { "success": true, "material": material, "quantity": quantity, "position": pos, "player_id": player_id }

## Phase 43 — what mining a NATURAL span of `tile` yields, off the ore field:
## `{ material, quantity, vein }`. Inside a LIVE vein it is the vein's material and its
## per-slice `quantity`, capped by the reserve still left; anywhere else (no vein, or one
## mined out) the biome's host rock, one unit, with `vein` empty. Pure — the depletion it
## implies is recorded by the caller (`_record_depletion`).
func _natural_yield(tile: Vector2i, span: Dictionary) -> Dictionary:
	var xz := Vector2(tile.x * TILE_SIZE + TILE_SIZE * 0.5, tile.y * TILE_SIZE + TILE_SIZE * 0.5)
	var depth := _run_depth(span, _base_top_for_tile(tile))
	var vein := _live_vein_at(xz, depth, _world_seed(), _vein_taken, {})
	if vein.is_empty():
		var biome := _biome_at(xz)
		var b: Variant = GameData.BIOMES.get(biome, null)
		# Phase 49 — digging through a grass-covered biome's topsoil yields Soil, not rock.
		if b != null and b.get("surfaceMaterial") == "Grass" and depth < float(b.get("topsoilDepth")):
			return { "material": "Soil", "quantity": 1, "vein": {} }
		return { "material": OreField.host_material(biome), "quantity": 1, "vein": {} }
	var take := mini(int(vein["quantity"]), OreField.remaining(vein, _vein_taken))
	return { "material": str(vein["material"]), "quantity": take, "vein": vein }

## Record `take` more units mined out of `vein`, as ONE fact per vein on the edit path.
##
## The record is a `{ "op": "deplete", "vein": id, "taken": n }` op on the vein's ANCHOR
## tile (the tile its blob centre sits in), REPLACED in place on every mine — never appended
## — so a vein costs one op however many swings it took, and the save does not grow with
## every click. Riding the tile op log is what makes it persist and travel for free: the
## per-chunk manifest saves it, the join/re-scope snapshot carries it, and `apply_edits`
## re-derives `_vein_taken` from it. Depletion is per VEIN, not per tile: depleting tile by
## tile would turn a blob into a checkerboard.
##
## When the vein runs out, every chunk its blob can touch is rebuilt, so its tint and its
## surface markers give way to host rock.
func _record_depletion(vein: Dictionary, take: int) -> void:
	if take <= 0:
		return
	var id := str(vein["id"])
	var taken := int(_vein_taken.get(id, 0)) + take
	_vein_taken[id] = taken
	var key := _tile_key(vein["anchor"])
	var ops: Array = (_edits.get(key, []) as Array).duplicate()
	var replaced := false
	for i in range(ops.size()):
		var op: Dictionary = ops[i]
		if str(op.get("op", "")) == "deplete" and str(op.get("vein", "")) == id:
			ops[i] = { "op": "deplete", "vein": id, "taken": taken }
			replaced = true
			break
	if not replaced:
		ops.append({ "op": "deplete", "vein": id, "taken": taken })
	_set_edit_ops(key, ops)
	if not OreField.is_live(vein, _vein_taken):
		_rebuild_vein_chunks(vein)

## Rebuild every chunk a vein's blob can reach — its bounding box, widened by the blob's
## noise margin — by the same route an edit takes (`_rebuild_chunk`).
func _rebuild_vein_chunks(vein: Dictionary) -> void:
	var center: Vector3 = vein["center"]
	var reach := float(vein["radius"]) * (1.0 + OreField.SHAPE_NOISE) + 1.0
	var seen: Dictionary = {}
	for corner in [Vector2(-reach, -reach), Vector2(reach, -reach), Vector2(-reach, reach), Vector2(reach, reach)]:
		var tile := Vector2i(floori(center.x + corner.x), floori(center.z + corner.y))
		var chunk := _tile_to_chunk(tile)
		var ckey := _chunk_key(chunk)
		if seen.has(ckey):
			continue
		seen[ckey] = true
		_rebuild_chunk(chunk)

## The vein a depletion id names, re-derived from the field (the id IS its cell), or `{}`
## for an id that does not parse or names an empty cell.
func _vein_from_id(id: String) -> Dictionary:
	var parts := id.split(",")
	if parts.size() != 3:
		return {}
	var cell := Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
	var vein := OreField.vein_in_cell(_world_seed(), cell)
	return vein if not vein.is_empty() and str(vein["id"]) == id else {}

## Add one STEP_HEIGHT of the selected material on the column under world_pos.
## Consumes the material from the inventory. Returns true on success; false if no
## material is selected, the cell is already solid, or the build cap is reached.
##
## Phase 42 review — `material` is the ACTOR's selection and `player_id` the actor:
## `""` for either means "this machine's own" (its `_place_material`, its pack), and
## the host re-emits a client's intent with the identity bound to that connection
## plus the material the client named. Two rules keep a client-declared material
## from granting anything: it must be a real fabric material, and the debit lands on
## the actor's own pack — so a peer can only ever place what it actually holds. Both
## are checked BEFORE the debit and the edit (the atomic-refusal rule).
func place_block(world_pos: Vector3, normal: Vector3, material: String = "", player_id: String = "") -> bool:
	# `_place_material` is THIS machine's selection, so only the local actor may fall back
	# to it: a remote actor that named no material (a client with nothing selected) must
	# not place whatever the host happens to have selected.
	if material == "" and _is_remote_actor(player_id):
		return false
	var chosen := material if material != "" else _place_material
	if chosen == "" or not GameData.MATERIALS.has(chosen):
		return false

	# The placement is validated BEFORE anything is spent, so a refused placement
	# leaves no side effect to roll back.
	var probe := _resolve_edit_tile("place", world_pos, normal)
	var tile: Vector2i = probe["tile"]
	var span := _place_span(get_runs_at_tile(tile), world_pos, normal)
	if span.is_empty():
		return false

	var inventory := inventory_for(player_id)
	if inventory != null and inventory.has_method("drop_item"):
		if not inventory.drop_item(chosen, 1):
			return false

	_append_edit(tile, { "op": "add", "bottom": span["bottom"], "top": span["top"], "material": chosen })
	_mark_dirty(tile)
	_rebuild_chunk_at_tile(tile)
	_push_inventory(player_id)

	var pos := Vector3(probe["xz"].x, float(span["top"]), probe["xz"].y)
	GameBus.block_placed.emit(chosen, pos)
	GameBus.block_changed.emit("place", world_pos, normal, chosen)
	return true

## Top of the column at a world XZ position — the highest solid run's top, or
## BEDROCK_DEPTH when the column is mined out to the floor.
##
## This is the column's TOP, not the surface a body stands on: inside a tunnel the
## body's own Y decides which run holds it, which is what `sample_support_height_at`
## answers — and that is the read production uses for footing
## (`game_root._sync_player_avatar`). This accessor stays because it is how a
## column's SHAPE is asserted (the suite), and because the pre-ceiling footing read
## it used to be is still what a caller outside a tunnel means.
func get_voxel_height_at(world_pos: Vector2) -> float:
	return _column_top_at_tile(_world_to_tile(world_pos))

## The top of the highest run AT OR BELOW from_y, or BEDROCK_DEPTH when nothing
## solid lies below. Phase 41 — the footing sampler is a function of the body's
## own Y for exactly one reason: a column-top sampler is only correct in a world
## with no ceilings, and a body standing under a tunnel roof would otherwise be
## placed ON the roof. A tolerance of half a step lets a body standing exactly on
## a surface still find it.
func sample_support_height_at(world_pos: Vector2, from_y: float) -> float:
	var support := BEDROCK_DEPTH
	for run in get_column_runs_at(world_pos):
		var top := float(run["top"])
		if top <= from_y + STEP_HEIGHT * 0.5 and top > support:
			support = top
	return support

## The resolved solid runs of the column at a world XZ position, bottom → top.
func get_column_runs_at(world_xz: Vector2) -> Array:
	return get_runs_at_tile(_world_to_tile(world_xz))

## The resolved solid runs of one tile, bottom → top (see the class docstring).
func get_runs_at_tile(tile: Vector2i) -> Array:
	return apply_run_ops(_base_runs_for_tile(tile), _edits.get(_tile_key(tile), []))

## Dump voxel edits for persistence: { "gx,gz": [typed run edit, ...] }.
func get_edits() -> Dictionary:
	return _edits.duplicate(true)

## Restore voxel edits from a saved world snapshot and rebuild affected chunks.
##
## TOLERANT of both save shapes, deliberately: a value that is an Array is the
## Phase 41 typed run edits and is adopted as-is, while a bare number (or a string
## that parses as one) is a pre-Phase-41 absolute quantised height and is MIGRATED
## (see `legacy_edit_ops`) against the tile's natural run — never dropped, because
## a migration that "repairs" a world by discarding player work is worse than a
## refusal. `materials` maps "gx,gz" → Array of material keys, the other half of
## the legacy shape.
##
## A value that is NEITHER shape is not player work, it is unreadable: it is DROPPED
## with a warning (`_legacy_height_of`) rather than cast into a height, because the
## cast was not a refusal — `float()` answers 0.0 for an unparsable string, which
## migrates the column to the world floor.
##
## Only the chunks whose edits actually CHANGED are rebuilt, and only the ones
## that are LOADED. Both halves are load-path hygiene this method needs because
## it is also the RE-SCOPE path (`game_root._on_world_snapshot_received`): a
## snapshot re-sends the manifest a client already applied — or one that differs
## in a chunk or two — and rebuilding every held chunk for that is a whole-frame
## stall per scope change. And a chunk that was streamed out has no mesh to
## refresh: building it here would resurrect the node `ChunkManager` has already
## streamed away, which it will then never unload again.
##
## A changed TILE names the chunks whose mesh reads it (`_touched_chunks`), not just
## the chunk the tile sits in: a wall face is the difference against the NEIGHBOUR
## column, so an edit on a chunk's edge leaves the neighbour's old wall standing — a
## see-through slot or a ghost wall at the seam — until that chunk happens to
## restream. `_rebuild_chunk_at_tile` has closed this since the Phase 41 review; this
## is the same closure on the re-scope path, which was still rebuilding the tile's own
## chunk alone.
##
## Phase 42 review pass 8 — and the rebuild now takes the SAME route as an edit:
## `ChunkManager.request_rebuild` when a manager is wired, the synchronous `build_chunk`
## otherwise. It used to always build synchronously, which both paid the whole build on the
## main thread in the frame that applied a snapshot AND bumped the chunk's revision under
## an in-flight worker build.
func apply_edits(edits: Dictionary, materials: Dictionary = {}) -> void:
	_commit_edits(_normalise_edit_table(edits, materials))

## The normalising half of `apply_edits`: a typed op list is cleaned, a legacy height is
## migrated against the tile's natural run, anything unreadable is dropped with a warning.
func _normalise_edit_table(edits: Dictionary, materials: Dictionary) -> Dictionary:
	var next: Dictionary = {}
	for key in edits:
		var value: Variant = edits[key]
		if value is Array:
			next[key] = _normalise_ops(value)
			continue
		# The LEGACY half: a bare number (or a numeric string) is a pre-Phase-41
		# absolute quantised height, migrated against the tile's natural run. Any
		# OTHER shape is DROPPED with a warning rather than cast — `float()` answers
		# 0.0 for a string that is not a number, so a corrupt entry used to migrate
		# into a height AT THE WORLD FLOOR (the column carved away), and a dict raised
		# a runtime error on the load path. Dropping is the policy `_normalise_ops`
		# already applies to an op whose kind this version cannot read.
		var legacy_height := _legacy_height_of(value)
		if is_nan(legacy_height):
			Diag.warn("VoxelSlice.apply_edits: dropping an unrecognized edit for '%s' (%s)"
				% [str(key), type_string(typeof(value))])
			continue
		var tile := _key_to_tile(str(key))
		var stack: Array = materials.get(key, [])
		next[key] = legacy_edit_ops(legacy_height, _base_top_for_tile(tile), stack)
	return next

## The committing half of `apply_edits`: swap in `next` as the edit log and rebuild what
## changed. `diff_keys` limits the change detection to those tile keys (the scoped re-scope
## path knows nothing outside its disc moved); null compares the whole of both logs.
func _commit_edits(next: Dictionary, diff_keys: Variant = null) -> void:
	var previous: Dictionary = _edits
	# _dirty_chunks is NOT cleared here: dirty tracking is reset only by
	# clear_dirty_chunks() after a successful save (called from game_root._on_save_completed).
	# Restored on-disk edits are not dirty — they were already persisted.
	var touched: Dictionary = {}
	var keys: Array = (diff_keys as Array) if diff_keys is Array else _union_keys(previous, next)
	for key in keys:
		if next.has(key):
			if not _ops_equal(previous.get(key, null), next[key]):
				_mark_touched_tile(touched, _key_to_tile(str(key)))
		elif previous.has(key):
			_mark_touched_tile(touched, _key_to_tile(str(key)))
	var previous_taken: Dictionary = _vein_taken
	_edits = next
	# The read-side chunk index is re-derived with it (Phase 42 review pass 10): the log was
	# replaced in one assignment, so the index is rebuilt rather than diffed.
	_reindex_edits()
	# Phase 43 — a vein whose EXHAUSTION changed with the new log repaints across its whole
	# blob, which is wider than the anchor tile the deplete op sits on (the only tile the
	# diff above marks). A count that moved without crossing the reserve changes nothing
	# visible, so it rebuilds nothing.
	var vein_ids: Dictionary = previous_taken.duplicate()
	vein_ids.merge(_vein_taken)
	for id in vein_ids:
		var vein := _vein_from_id(str(id))
		if vein.is_empty():
			continue
		if OreField.is_live(vein, previous_taken) != OreField.is_live(vein, _vein_taken):
			_rebuild_vein_chunks(vein)
	# Phase 42 review pass 8 — this is the REBUILD half of the re-scope, and it goes through
	# the manager exactly like an edit does (`_rebuild_chunk_at_tile`): `request_rebuild`
	# dispatches the build to a WORKER (so a snapshot that changed a corner — three touched
	# chunks — no longer rebuilds them all synchronously in the frame that applied it) and,
	# more importantly, it SUPERSEDES a build already in flight for the chunk. The
	# synchronous `build_chunk` this used to call bumped the chunk's revision on the main
	# thread, which made an in-flight worker result stale (refused) while the worker's pool
	# task was left to be awaited by nobody but the frame path — the mesh that landed was
	# whichever one won the race. With no manager wired (the suite, a probe) the synchronous
	# build stays, and only for a chunk that is LOADED.
	#
	# Phase 42 review pass 11 — the manager path is NOT gated on `_chunks`: a chunk whose
	# FIRST build is still on a worker is in the manager's streamed set but not yet in
	# `_chunks`, and that build read the pre-snapshot edit log. Skipping it attached a mesh
	# without the snapshot's edits and nothing ever rebuilt it. `request_rebuild` supersedes
	# the in-flight build and is itself a no-op for a chunk outside the streamed set.
	for ckey in touched:
		# `ckey` is a CHUNK key ("cx,cz"); the same "x,y" parse as a tile key reads it.
		var chunk := _chunk_from_key(str(ckey))
		if chunk_manager != null and chunk_manager.has_method("request_rebuild"):
			chunk_manager.request_rebuild(chunk)
			continue
		if not _chunks.has(ckey) or not _heightmaps.has(ckey):
			continue   # nothing to refresh: unloaded chunks rebuild when streamed in
		build_chunk(chunk, _heightmaps[ckey])

static func _union_keys(a: Dictionary, b: Dictionary) -> Array:
	var keys: Array = b.keys()
	for key in a:
		if not b.has(key):
			keys.append(key)
	return keys

## Mark every chunk whose mesh reads `tile` — the tile's own chunk plus each
## edge-adjacent one it sits on the edge of (see `_touched_chunks`) — as needing a
## rebuild. The one place a tile-level change is turned into chunk-level work.
func _mark_touched_tile(touched: Dictionary, tile: Vector2i) -> void:
	for chunk in _touched_chunks(tile):
		touched[_chunk_key(chunk)] = true

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

## Group voxel edits by chunk into a persistence manifest:
##   { "cx,cz": { "edits": { "gx,gz": [typed run edit, ...] } } }
## Only chunks with edits appear. Used by the world save snapshot so edits are
## stored per-chunk and only dirty chunks need re-serialization.
func get_chunk_manifest() -> Dictionary:
	var manifest: Dictionary = {}
	for key in _edits:
		var chunk := _chunk_key(_tile_to_chunk(_key_to_tile(str(key))))
		if not manifest.has(chunk):
			manifest[chunk] = { "edits": {} }
		manifest[chunk]["edits"][key] = _edits[key].duplicate(true)
	return manifest

## True when chunk `chunk_pos`'s square overlaps the disc of `radius` around the world
## position `center` (XZ). Pure; the AOI scope of a re-scope snapshot's edits.
static func chunk_in_radius(chunk_pos: Vector2i, center: Vector3, radius: float) -> bool:
	var size := float(CHUNK_SIZE) * TILE_SIZE
	var min_corner := _chunk_world_center(chunk_pos) - Vector2(size, size) * 0.5
	var nx := clampf(center.x, min_corner.x, min_corner.x + size)
	var nz := clampf(center.z, min_corner.y, min_corner.y + size)
	return Vector2(center.x - nx, center.z - nz).length() <= radius

## Phase 49 — `get_chunk_manifest` restricted to chunks inside an area of interest, so a
## re-scope snapshot ships the edits a peer can see instead of the whole world's. Walks the
## chunk index (one parse per EDITED CHUNK, not per edit).
func get_chunk_manifest_in_radius(center: Vector3, radius: float) -> Dictionary:
	var manifest: Dictionary = {}
	for ckey in _edits_by_chunk:
		if not chunk_in_radius(_chunk_from_key(str(ckey)), center, radius):
			continue
		var edits: Dictionary = {}
		for key in _edits_by_chunk[ckey]:
			edits[key] = _edits[key].duplicate(true)
		manifest[ckey] = { "edits": edits }
	return manifest

## Phase 49 — apply a manifest produced by `get_chunk_manifest_in_radius`. It is
## authoritative only INSIDE its scope: edits this slice holds for chunks outside the
## disc are kept untouched, because the host did not (and could not) restate them. Only the
## in-scope buckets are replaced and only their tiles are diffed; the rest of the log is
## neither re-normalised nor compared.
func apply_scoped_chunk_manifest(manifest: Dictionary, center: Vector3, radius: float) -> void:
	var next: Dictionary = _edits.duplicate()   # shallow: the out-of-scope op lists are shared
	var diff_keys: Array = []
	for ckey in _edits_by_chunk:
		if chunk_in_radius(_chunk_from_key(str(ckey)), center, radius):
			for key in _edits_by_chunk[ckey]:
				next.erase(key)
				diff_keys.append(key)
	var edits: Dictionary = {}
	var materials: Dictionary = {}
	for ckey in manifest:
		var chunk_data: Dictionary = manifest[ckey]
		if chunk_data.has("edits"):
			for key in chunk_data["edits"]:
				edits[key] = chunk_data["edits"][key]
		if chunk_data.has("materials"):
			for key in chunk_data["materials"]:
				materials[key] = chunk_data["materials"][key]
	var incoming := _normalise_edit_table(edits, materials)
	for key in incoming:
		next[key] = incoming[key]
		diff_keys.append(key)
	_commit_edits(next, diff_keys)

## Parse a "cx,cz" chunk key — the same "x,y" form as a tile key (`_key_to_tile`), which is
## the one parser.
static func _chunk_from_key(ckey: String) -> Vector2i:
	return _parse_xy(ckey)

static func _parse_xy(key: String) -> Vector2i:
	var parts: PackedStringArray = key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

## Restore voxel edits from a chunk manifest (see get_chunk_manifest). Flattens
## the per-chunk grouping back into the global tile-keyed edit table. A manifest
## written before Phase 41 also carries a per-chunk "materials" map; it is read and
## handed to apply_edits for the legacy migration rather than ignored.
func apply_chunk_manifest(manifest: Dictionary) -> void:
	var edits: Dictionary = {}
	var materials: Dictionary = {}
	for ckey in manifest:
		var chunk_data: Dictionary = manifest[ckey]
		if chunk_data.has("edits"):
			for key in chunk_data["edits"]:
				edits[key] = chunk_data["edits"][key]
		if chunk_data.has("materials"):
			for key in chunk_data["materials"]:
				materials[key] = chunk_data["materials"][key]
	apply_edits(edits, materials)

## Return the "cx,cz" keys of chunks modified since the last save/clear.
func get_dirty_chunk_keys() -> Array:
	return _dirty_chunks.keys()

## Clear the dirty-chunk tracking (call after a successful save).
func clear_dirty_chunks() -> void:
	_dirty_chunks.clear()

## Remove exactly `keys` from the dirty set. The authoritative save runs the file
## write on a worker thread, so the clear happens when the payload is COLLECTED
## (main thread, atomically with reading it) rather than after the write lands. A
## keyed clear is what makes that safe: an edit made while the write is in flight
## marks its chunk dirty again and is carried by the next save, instead of being
## swallowed by a blanket clear.
func clear_dirty_chunk_keys(keys: Array) -> void:
	for key in keys:
		_dirty_chunks.erase(str(key))

## Re-mark `keys` dirty — the rollback for a save whose write failed, so a failed
## write cannot lose the chunks it claimed to persist.
func mark_dirty_chunks(keys: Array) -> void:
	for key in keys:
		_dirty_chunks[str(key)] = true

func set_place_material(material: String) -> void:
	_place_material = material

func get_place_material() -> String:
	return _place_material

## Advance to the next buildable material — only materials currently held in
## the inventory (sorted GameData.MATERIALS keys). Falls back to an empty
## selection when the inventory holds nothing buildable.
func cycle_place_material() -> String:
	var keys := _buildable_materials()
	if keys.is_empty():
		_place_material = ""
	else:
		var idx: int = keys.find(_place_material)
		idx = (idx + 1) % keys.size()
		_place_material = str(keys[idx])
	GameBus.block_place_material_changed.emit(_place_material)
	return _place_material

## Sorted material keys the player can actually place: every GameData.MATERIALS
## key held in the inventory. With no inventory wired, falls back to all keys.
func _buildable_materials() -> Array:
	var keys: Array = GameData.MATERIALS.keys()
	keys.sort()
	if inventory_slice == null or not inventory_slice.has_method("get_item_count"):
		return keys
	var out: Array = []
	for key in keys:
		if inventory_slice.get_item_count(str(key)) > 0:
			out.append(str(key))
	return out

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
static func material_for_biome(biome: String, world_xz: Vector2, depth: float = 0.0, seed: int = 0, depleted: Dictionary = {}, veins: Dictionary = {}) -> String:
	var vein := _live_vein_at(world_xz, depth, seed, depleted, veins)
	if not vein.is_empty():
		return str(vein["material"])
	return OreField.host_material(biome)

## The LIVE vein at a world position and depth, or `{}` (absent or mined out).
static func _live_vein_at(world_xz: Vector2, depth: float, seed: int, depleted: Dictionary, veins: Dictionary) -> Dictionary:
	var tile := _world_to_tile(world_xz)
	var chunk := _tile_to_chunk(tile)
	var vein := OreField.vein_at(seed, chunk, tile - chunk * CHUNK_SIZE, depth, veins)
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

## The seed the ore field is evaluated with: the world's (Phase 41), or 0 for a slice with no
## terrain wired (an isolated rig).
func _world_seed() -> int:
	if terrain_slice != null and terrain_slice.has_method("get_world_seed"):
		return int(terrain_slice.get_world_seed())
	return 0

## Small raised markers on the VEINS in one chunk, as
## `[{ "position": Vector3, "size": Vector3, "color": Color }]` — the geometry
## `build_chunk_arrays` emits on top of the ground. A natural column carries one when its
## top slice lies inside a LIVE vein (Phase 43): the marker marks a vein that is actually
## there, in the vein's own colour — a ferrite vein in ferrite rock included, since the
## marker is its only surface tell. A player-placed surface is never a vein, a column mined
## down OUT of a vein loses its marker, and an exhausted vein shows none. Pure, so the read
## is testable headlessly without a renderer.
##
## Phase 42 review pass 8 — this is the RESOLVE half's job, called from
## `collect_build_runs`, which hands it the memo it already filled (`cache`): the walk below
## asks the same question about the same columns, so the chunk's own runs are replayed once
## rather than twice. Called on its own (a test, a probe) it builds its own memo.
func vein_deposits(chunk_pos: Vector2i, heightmap: Array, cache: Dictionary = {}) -> Array:
	return vein_deposits_at(chunk_pos, heightmap, cache, _edits, gather_biomes_for(chunk_pos),
		_field(_world_seed(), _vein_taken))

## Phase 42 review pass 9 — the PURE half of the walk above: the edits, the biomes and (Phase 43)
## the ore field's inputs arrive as plain arguments (see `gather_build_input`), so a worker can
## run it. The chunk's own columns only, so the ring's heightmaps are not part of its input.
static func vein_deposits_at(chunk_pos: Vector2i, heightmap: Array, cache: Dictionary, edits: Dictionary, biomes: Dictionary, field: Dictionary = {}) -> Array:
	var out: Array = []
	var seed := int(field.get("seed", 0))
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
			var vein := _live_vein_at(world_xz, depth, seed, depleted, veins)
			if vein.is_empty():
				continue
			out.append({
				"position": Vector3(world_xz.x, h + VEIN_DEPOSIT_HEIGHT * 0.5, world_xz.y),
				"size":     deposit_size,
				"color":    _material_color(str(vein["material"])),
			})
	return out

# ---------------------------------------------------------------------------
# Run algebra — the column model (Phase 41)
# ---------------------------------------------------------------------------

## Replay a tile's typed run edits over its natural runs. Pure (no node state), so
## the column model is testable on its own — and it is the ONLY place edits turn
## into geometry, shared by the mesher, the collision soup, the footing sampler and
## the save manifest.
static func apply_run_ops(runs: Array, ops: Array) -> Array:
	var out: Array = []
	for run in runs:
		out.append({ "bottom": float(run["bottom"]), "top": float(run["top"]), "material": str(run.get("material", "")) })
	for op in ops:
		if not (op is Dictionary):
			continue
		var o: Dictionary = op
		var bottom := float(o.get("bottom", 0.0))
		var top := float(o.get("top", 0.0))
		if top <= bottom:
			continue
		var kind := str(o.get("op", ""))
		if kind == "add":
			out = add_span(out, bottom, top, str(o.get("material", "")))
		elif kind == "remove":
			out = remove_span(out, bottom, top)
		# An unknown kind is IGNORED, never treated as a remove: the two kinds are
		# not symmetric (one fills, one carves), and defaulting to the carving one
		# is how a corrupt edit list silently eats terrain (see `_normalise_ops`).
	return out

## Add a solid span, merging it with runs of the SAME material it touches or
## overlaps. Material is part of a run's identity: a placed block stays its own run
## above the natural ground, so the natural base keeps the biome's colour instead
## of being repainted by whatever the player stacked on it.
static func add_span(runs: Array, bottom: float, top: float, material: String) -> Array:
	var out: Array = []
	for run in runs:
		out.append({ "bottom": float(run["bottom"]), "top": float(run["top"]), "material": str(run.get("material", "")) })
	out.append({ "bottom": bottom, "top": top, "material": material })
	out.sort_custom(func(a, b): return float(a["bottom"]) < float(b["bottom"]))
	var merged: Array = []
	for run in out:
		if merged.is_empty():
			merged.append(run)
			continue
		var prev: Dictionary = merged[-1]
		var touches := float(run["bottom"]) <= float(prev["top"]) + 0.000001
		if touches and str(prev["material"]) == str(run["material"]):
			prev["top"] = maxf(float(prev["top"]), float(run["top"]))
		else:
			merged.append(run)
	return merged

## Carve a solid span OUT of the runs — the mining edit. Trims a run that
## partially overlaps, drops one fully covered, and SPLITS one the span sits
## strictly inside. That split is what a tunnel IS: a floor run and a roof run,
## and mining either of them leaves the other alone.
static func remove_span(runs: Array, bottom: float, top: float) -> Array:
	var out: Array = []
	for run in runs:
		var rbottom := float(run["bottom"])
		var rtop := float(run["top"])
		var material := str(run.get("material", ""))
		if top <= rbottom or bottom >= rtop:
			out.append({ "bottom": rbottom, "top": rtop, "material": material })
			continue
		if rbottom < bottom:
			out.append({ "bottom": rbottom, "top": bottom, "material": material })
		if rtop > top:
			out.append({ "bottom": top, "top": rtop, "material": material })
	return out

## The run whose TOP is the plane `y` (within half a step), or {} when no run tops
## there. Phase 41 — a top-face hit names the run it LANDED on, not the column's
## topmost one: a tunnel FLOOR keeps an exposed top face with the roof above it, so
## "the topmost run" answers with the roof and carves (or stacks on) the wrong span
## from a click on the floor. Falls back to the caller's reading when the y is not
## on any run boundary (the boot demo passes the spawn plain's height, not the
## target tile's), which is what keeps a misaligned y behaving as it did before.
## Pure, so the resolution rule is testable on its own.
static func runs_topping_at(runs: Array, y: float) -> Dictionary:
	var best: Dictionary = {}
	for run in runs:
		if absf(float(run["top"]) - y) > STEP_HEIGHT * 0.5:
			continue
		if best.is_empty() or float(run["top"]) > float(best["top"]):
			best = run
	return best

## True when any run covers the ordinate `y` (half-open [bottom, top]). The rule
## the mesher asks before emitting a top or an underside face.
static func runs_cover_y(runs: Array, y: float) -> bool:
	for run in runs:
		if float(run["bottom"]) - 0.000001 <= y and y < float(run["top"]) - 0.000001:
			return true
	return false

## The parts of `run` that `others` do NOT fill, as [{ "bottom", "top" }]. Used to
## build a wall face per neighbour from solidity difference, so a wall is emitted
## exactly where this column has material the neighbour has not.
static func subtract_runs(run: Dictionary, others: Array) -> Array:
	var segments: Array = [{ "bottom": float(run["bottom"]), "top": float(run["top"]) }]
	for other in others:
		var ob := float(other["bottom"])
		var ot := float(other["top"])
		var next: Array = []
		for seg in segments:
			if ot <= float(seg["bottom"]) or ob >= float(seg["top"]):
				next.append(seg)
				continue
			if float(seg["bottom"]) < ob:
				next.append({ "bottom": float(seg["bottom"]), "top": ob })
			if float(seg["top"]) > ot:
				next.append({ "bottom": ot, "top": float(seg["top"]) })
		segments = next
	return segments

## The typed run edits a pre-Phase-41 scalar height edit migrates to. An old edit
## was an absolute quantised column TOP and the column it described is the single
## run from BEDROCK_DEPTH up to that height — exactly what this pair of edits
## resolves to against the tile's own natural run. `materials` is the legacy
## per-tile stack of placed blocks: the natural run ends that many steps BELOW the
## edited top, and each placed block becomes its own `add` span above it. Pure, so
## the migration rule is testable on its own.
##
## The stack survives every case, including the re-rolled-seed one: an edit whose
## top reaches further than `placed` steps above the CURRENT base top means the
## ground itself moved under the save (a version-1 world re-rolls once), not that
## the stack vanished — so the natural span is re-added up to the stack's own base
## and the materials still sit on top of it, still theirs. Collapsing that case
## into one anonymous span (the pre-review behaviour) repaints a re-rolled world's
## player work as natural ground, which is the one thing this migration exists to
## refuse to do.
static func legacy_edit_ops(legacy_height: float, base_top: float, materials: Array = []) -> Array:
	var placed := materials.size()
	var natural_top := legacy_height - float(placed) * STEP_HEIGHT
	# Nothing can sit above the edited top, so a legacy height with nothing
	# stacked on it is one plain span (up to it, or down to it when the edit
	# carved): the common shape, and the one that has to stay a single op.
	if placed == 0:
		if legacy_height >= base_top:
			return [{ "op": "add", "bottom": base_top, "top": legacy_height, "material": "" }]
		return [{ "op": "remove", "bottom": legacy_height, "top": base_top }]
	var ops: Array = []
	if natural_top > base_top:
		ops.append({ "op": "add", "bottom": base_top, "top": natural_top, "material": "" })
	elif natural_top < base_top:
		ops.append({ "op": "remove", "bottom": natural_top, "top": base_top })
	for k in range(placed):
		ops.append({
			"op":       "add",
			"bottom":   natural_top + float(k) * STEP_HEIGHT,
			"top":      natural_top + float(k + 1) * STEP_HEIGHT,
			"material": str(materials[k]),
		})
	return ops

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

static func _voxel_height(raw_height: float) -> float:
	return floor(raw_height / STEP_HEIGHT) * STEP_HEIGHT

## A tile's natural (unedited) runs, from its chunk's heightmap when that chunk is
## built, else from the deterministic terrain sampler — the placeholder a tile
## needs BEFORE streaming has reached it, e.g. when a load-time migration runs
## first. Both answer the same height by construction (the heightmap is
## `get_height_at` sampled on the tile grid), so the migration is migration, not a
## guess.
func _base_runs_for_tile(tile: Vector2i) -> Array:
	var top := _base_top_for_tile(tile)
	if top <= BEDROCK_DEPTH:
		return []
	return [{ "bottom": BEDROCK_DEPTH, "top": top, "material": "" }]

func _base_top_for_tile(tile: Vector2i) -> float:
	var chunk := _tile_to_chunk(tile)
	var ckey := _chunk_key(chunk)
	if _heightmaps.has(ckey):
		var hm: Array = _heightmaps[ckey]
		var lx := tile.x - chunk.x * CHUNK_SIZE
		var lz := tile.y - chunk.y * CHUNK_SIZE
		return _voxel_height(float(hm[lz * CHUNK_SIZE + lx]))
	if terrain_slice != null and terrain_slice.has_method("get_height_at"):
		return _voxel_height(terrain_slice.get_height_at(Vector2(tile.x * TILE_SIZE, tile.y * TILE_SIZE)))
	return BEDROCK_DEPTH

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
	var runs := apply_run_ops(base, edits.get(key, []))
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

## The terrain material this slice's chunk meshes share — ONE instance for the lifetime of
## the slice (see `_terrain_mat`). The lazy branch is for an isolated rig that drives
## `build_chunk` without ever entering `_ready()`; in the game the material is already built.
func _terrain_material() -> StandardMaterial3D:
	if _terrain_mat == null:
		_terrain_mat = _make_terrain_material()
	return _terrain_mat

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

func _on_mine_requested(position: Vector3, normal: Vector3, player_id: String) -> void:
	if is_authoritative:
		mine_block(position, normal, player_id)
	else:
		GameBus.block_edit_intent.emit("mine", position, normal, "")

## The inventory an edit by `player_id` resolves against: that player's own pack from
## the registry when one is wired, else this slice's (`""` = this machine's own
## player, the Phase 34 `resolve_player` convention). The same resolve shape
## `CraftingSlice.inventory_for` uses, and for the same reason: one process holds one
## inventory per player, so a host resolving an action for a peer must reach THAT
## player's, never its own (see `mine_block`).
func inventory_for(player_id: String) -> Node:
	if player_id != "" and player_registry != null and player_registry.has_method("get_inventory"):
		var inv: Node = player_registry.get_inventory(player_id)
		if inv != null:
			return inv
	return inventory_slice

## Is `player_id` a player whose own client mirrors this inventory over the wire? False
## for `""` (this machine's own player) and for the local id, whose pack is live in this
## process and already in sync — the same test `game_root._sync_peer_own_state` makes
## before it sends. A slice with no registry (an isolated rig) answers true for any
## non-empty id: it cannot tell, and the sync signal is addressee-filtered anyway.
func _is_remote_actor(player_id: String) -> bool:
	if player_id == "":
		return false
	if player_registry != null and "local_player_id" in player_registry:
		return player_id != str(player_registry.local_player_id)
	return true

## Phase 42 review — an edit the host resolved for a REMOTE actor changed that player's
## pack, which lives HERE (the registry's copy) but is mirrored by the peer's own
## client. Without this the client keeps rendering its pre-edit inventory until the next
## snapshot — the client's half of the transfer the review found missing. The signal is
## addressed to its owner (Phase 37), so networking delivers it to that peer ALONE; it
## is the same mechanism the net harness's `inventory_owner` step pins.
func _push_inventory(player_id: String) -> void:
	if not _is_remote_actor(player_id):
		return
	var inv := inventory_for(player_id)
	if inv == null or not inv.has_method("get_contents"):
		return
	GameBus.inventory_synced.emit(player_id, inv.get_contents(), inv.get_durability_data())

## The held mining pick's item id, or "" when `inventory` holds none. Delegates to the
## inventory's fabric-driven tool lookup ("pick" → FerritePick/VeilsteelPick).
func _held_pick(inventory: Node) -> String:
	if inventory == null or not inventory.has_method("find_tool"):
		return ""
	return str(inventory.find_tool("pick"))

func _on_place_requested(position: Vector3, normal: Vector3, player_id: String, material: String) -> void:
	if is_authoritative:
		# `material` as received: `place_block` decides whether "" may fall back to this
		# machine's own selection (only for the local actor, never for a remote one).
		place_block(position, normal, material, player_id)
	else:
		var chosen := material if material != "" else _place_material
		GameBus.block_edit_intent.emit("place", position, normal, chosen)

func _on_cycle_requested() -> void:
	cycle_place_material()

## Apply an authoritative block edit received from the host. Re-runs the same
## tile-resolution and span math as mine_block/place_block, but does NOT touch
## the inventory or emit block_changed — the host already did both.
func _on_block_changed(action: String, position: Vector3, normal: Vector3, material: String) -> void:
	if is_authoritative:
		return   # host already applied this edit locally
	apply_block_change(action, position, normal, material)

## Client-side application of a host-authoritative block edit (see block_changed).
## Delegates to the shared _apply_edit helper so host and client derive the same
## tile and span from the same math.
func apply_block_change(action: String, position: Vector3, normal: Vector3, material: String) -> void:
	_apply_edit(action, position, normal, material)

## Resolve the target tile for a block edit from the hit position + face normal.
## A side-face hit lands on the boundary between two columns, so we step along
## the normal: back for mining (into the block aimed at), forward for placing
## (into the adjacent empty cell). Pure — performs no mutation.
func _resolve_edit_tile(action: String, position: Vector3, normal: Vector3) -> Dictionary:
	var xz := Vector2(position.x, position.z)
	if normal.y <= 0.5:
		var step := Vector2(normal.x, normal.z) * TILE_SIZE * 0.5
		xz = xz - step if action == "mine" else xz + step
	return { "tile": _world_to_tile(xz), "xz": xz }

## The span a mine removes, or {} when it is refused. A top-face hit takes the last
## step of the run whose top is the hit plane (see `runs_topping_at`) and refuses at
## BEDROCK_DEPTH; any other hit takes the STEP_HEIGHT block the ray is INSIDE, and
## falls back to the block below it — a y that lands exactly on a step boundary
## names the cell ABOVE it first, so aiming at the very top edge of a wall (where
## that cell is empty) still mines the wall instead of refusing.
func _mine_span(runs: Array, world_pos: Vector3, normal: Vector3) -> Dictionary:
	if runs.is_empty():
		return {}
	if normal.y > 0.5:
		var top_run: Dictionary = runs_topping_at(runs, world_pos.y)
		if top_run.is_empty():
			top_run = runs[-1]   # a y on no run boundary: the column's own surface
		var top := float(top_run["top"])
		var bottom := top - STEP_HEIGHT
		if bottom < BEDROCK_DEPTH:
			return {}   # bedrock: nothing below the floor to yield
		return { "bottom": bottom, "top": top, "material": str(top_run.get("material", "")) }
	var cell: float = floorf(world_pos.y / STEP_HEIGHT) * STEP_HEIGHT
	for cell_bottom in [cell, cell - STEP_HEIGHT]:
		var cb := float(cell_bottom)
		if cb < BEDROCK_DEPTH:
			continue
		var cell_top: float = cb + STEP_HEIGHT
		for run in runs:
			if float(run["bottom"]) <= cb + 0.000001 and float(run["top"]) >= cell_top - 0.000001:
				return { "bottom": cb, "top": cell_top, "material": str(run.get("material", "")) }
	return {}

## The span a place adds, or {} when it is refused (the cell is already solid, or
## the build cap would be passed). A top-face hit stacks on the run whose top is the
## hit plane (see `runs_topping_at` — a click on a tunnel FLOOR stacks on the floor,
## not on the roof above it); any other hit fills the STEP_HEIGHT cell the ray
## landed on, which is what lets a player lay a ceiling under a tunnel roof.
func _place_span(runs: Array, world_pos: Vector3, normal: Vector3) -> Dictionary:
	var bottom := BEDROCK_DEPTH
	if normal.y > 0.5:
		var top_run: Dictionary = runs_topping_at(runs, world_pos.y)
		if not top_run.is_empty():
			bottom = float(top_run["top"])
		elif not runs.is_empty():
			bottom = float(runs[-1]["top"])   # a y on no run boundary: the column's surface
	else:
		bottom = maxf(floorf(world_pos.y / STEP_HEIGHT) * STEP_HEIGHT, BEDROCK_DEPTH)
	var top := bottom + STEP_HEIGHT
	if top > MAX_HEIGHT:
		return {}
	if runs_cover_y(runs, bottom + STEP_HEIGHT * 0.5):
		return {}   # the cell already holds material
	return { "bottom": bottom, "top": top }

## Append one typed run edit to a tile's op list, and COMPACT the list once it
## outgrows the column it describes.
##
## The list is an append-only log by design — an edit says what the player DID, and
## the column is that log replayed over the natural run — but a log with no bound
## grows forever. Mine and rebuild the same block a few dozen times and every click
## adds a replay step to every column read (meshing, the collision soup, the footing
## sampler, the save manifest) for the rest of the session, in the save file too,
## and the replay is O(ops) per read, so an unbounded log is an unbounded per-frame
## cost on a tile the player is standing next to.
##
## So: keep appending, and past MAX_TILE_OPS rewrite the list as the minimal
## description of what the column IS (`_compact_ops`). The rewrite is exact — both
## shapes resolve to the same runs — and it is bounded by the column's run count
## (a plain column carrying one placed stack is one remove plus two adds), which
## bounds the log until the next compaction. A column that has been mined and put
## back is compacted to NOTHING, because it is its natural self again.
func _append_edit(tile: Vector2i, op: Dictionary) -> void:
	var key := _tile_key(tile)
	if not _edits.has(key):
		_edits[key] = []
		_index_edit(key)
	var ops: Array = _edits[key]
	ops.append(op)
	if ops.size() <= MAX_TILE_OPS:
		return
	var compacted := _compact_ops(tile)
	if compacted.is_empty():
		_set_edit_ops(key, [])   # back to natural: the whole log was cancelled work
	else:
		_edits[key] = compacted

## The ONE place a tile's op log is written, so the chunk index (`_edits_by_chunk`) cannot
## drift from `_edits` (Phase 42 review pass 10). An EMPTY list drops the tile: it is back to
## its natural self, and both the log entry and its index mark go.
func _set_edit_ops(tile_key: String, ops: Array) -> void:
	if ops.is_empty():
		_edits.erase(tile_key)
		_unindex_edit(tile_key)
		return
	_edits[tile_key] = ops
	_index_edit(tile_key)

## Record `tile_key` under its chunk in the read-side index (idempotent).
func _index_edit(tile_key: String) -> void:
	var ckey := _chunk_key(_tile_to_chunk(_key_to_tile(tile_key)))
	var bucket: Dictionary = _edits_by_chunk.get(ckey, {})
	bucket[tile_key] = true
	_edits_by_chunk[ckey] = bucket

## Drop `tile_key` from the read-side index, and the whole bucket with it when it empties.
func _unindex_edit(tile_key: String) -> void:
	var ckey := _chunk_key(_tile_to_chunk(_key_to_tile(tile_key)))
	var bucket: Dictionary = _edits_by_chunk.get(ckey, {})
	bucket.erase(tile_key)
	if bucket.is_empty():
		_edits_by_chunk.erase(ckey)
	else:
		_edits_by_chunk[ckey] = bucket

## Rebuild the chunk index from the log — the wholesale path (`apply_edits` replaces `_edits`
## in one assignment, so the index is re-derived rather than diffed).
##
## Phase 43 — the vein depletion index (`_vein_taken`) is re-derived in the same pass: it is
## read off the log's deplete ops, never stored beside it.
func _reindex_edits() -> void:
	_edits_by_chunk = {}
	_vein_taken = {}
	for key in _edits:
		_index_edit(str(key))
		for op in _edits[key]:
			if op is Dictionary and str(op.get("op", "")) == "deplete":
				_vein_taken[str(op["vein"])] = int(op["taken"])

## The minimal op list resolving a tile's natural runs to the runs it has NOW: the
## natural run(s) removed, then the resolved run(s) re-added. An EMPTY list means
## the column is its natural self again (the mined-then-rebuilt case, where the log
## would otherwise keep both halves of every cancelled pair forever).
##
## Phase 43 — a tile's vein DEPLETION ops are not run edits and are carried over verbatim:
## compaction rewrites what the column IS, and a depletion record is what a vein HAS LOST,
## which no replay of the runs can reconstruct.
func _compact_ops(tile: Vector2i) -> Array:
	var current: Array = _edits.get(_tile_key(tile), [])
	var base := _base_runs_for_tile(tile)
	var runs := apply_run_ops(base, current)
	var ops: Array = []
	if not _runs_equal(runs, base):
		for run in base:
			ops.append({ "op": "remove", "bottom": float(run["bottom"]), "top": float(run["top"]) })
		for run in runs:
			ops.append({ "op": "add", "bottom": float(run["bottom"]), "top": float(run["top"]), "material": str(run["material"]) })
	for op in current:
		if op is Dictionary and str(op.get("op", "")) == "deplete":
			ops.append(op)
	return ops

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
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			return float(value)
		TYPE_STRING, TYPE_STRING_NAME:
			var text := str(value)
			return text.to_float() if text.is_valid_float() else NAN
	return NAN

## Coerce a loaded edit list into plain { bottom, top, material } / op dicts with
## numeric fields — JSON hands back Variants, and the run algebra compares floats.
##
## An op whose kind is not one of the two known ones is DROPPED, and so is an entry
## that is not a dict at all. Never defaulted: `remove` CARVES and `add` FILLS, so
## defaulting an unrecognized or corrupt op to `remove` turns a damaged save into
## silent terrain damage, while a dropped op is inert — the only safe reading of an
## op this version does not understand.
func _normalise_ops(ops: Array) -> Array:
	var out: Array = []
	for op in ops:
		if not (op is Dictionary):
			continue
		var o: Dictionary = op
		var kind := str(o.get("op", ""))
		if kind == "deplete":
			# Phase 43 — a vein depletion record (see `_record_depletion`). Kept only when it
			# names a vein and a non-negative count; it never touches the runs.
			var vein_id := str(o.get("vein", ""))
			var taken := int(o.get("taken", -1))
			if vein_id != "" and taken >= 0:
				out.append({ "op": "deplete", "vein": vein_id, "taken": taken })
			continue
		if kind != "add" and kind != "remove":
			continue
		var entry := {
			"op":     kind,
			"bottom": float(o.get("bottom", 0.0)),
			"top":    float(o.get("top", 0.0)),
		}
		if kind == "add":
			entry["material"] = str(o.get("material", ""))
		out.append(entry)
	return out

## Apply a block edit's terrain mutation (tile resolution + run edit + chunk
## rebuild). Shared by the authoritative mine/place path and the client's
## apply_block_change so host and client derive the identical tile, span, and
## material from the same math. Returns { applied, tile, new_h, pos, material }.
## Dirty-chunk tracking is host-only and done by the callers
## (mine_block/place_block), never here.
func _apply_edit(action: String, position: Vector3, normal: Vector3, material: String) -> Dictionary:
	var r := _resolve_edit_tile(action, position, normal)
	var tile: Vector2i = r["tile"]
	var xz: Vector2 = r["xz"]
	if action == "mine":
		var span := _mine_span(get_runs_at_tile(tile), position, normal)
		if span.is_empty():
			return { "applied": false }
		# Phase 43 — the client records the SAME depletion the host did: both evaluate the
		# same field over the same log, so the vein's reserve agrees with nothing extra on
		# the wire (and a re-scope snapshot carries the deplete op if a change was missed).
		# The yield is resolved BEFORE the remove (its depth is the span's), but recorded
		# AFTER it — the host's order in `mine_block` — so an anchor tile's op log is
		# identical on both sides (`_ops_equal` compares positionally) and an exhaustion
		# rebuild never gathers the pre-mine column.
		var yielded: Dictionary = {}
		if str(span["material"]) == "":
			yielded = _natural_yield(tile, span)
		_append_edit(tile, { "op": "remove", "bottom": span["bottom"], "top": span["top"] })
		if not yielded.is_empty() and not (yielded["vein"] as Dictionary).is_empty():
			_record_depletion(yielded["vein"], int(yielded["quantity"]))
		_rebuild_chunk_at_tile(tile)
		return {
			"applied": true, "tile": tile, "new_h": _column_top_at_tile(tile),
			"pos": Vector3(position.x, float(span["top"]), position.z),
			"material": str(span["material"]),
		}
	if action == "place":
		var span := _place_span(get_runs_at_tile(tile), position, normal)
		if span.is_empty():
			return { "applied": false }
		_append_edit(tile, { "op": "add", "bottom": span["bottom"], "top": span["top"], "material": material })
		_rebuild_chunk_at_tile(tile)
		return {
			"applied": true, "tile": tile, "new_h": float(span["top"]),
			"pos": Vector3(xz.x, float(span["top"]), xz.y),
			"material": material,
		}
	return { "applied": false }

# --- Coordinate helpers ---

## Phase 42 review pass 9 — STATIC: it is arithmetic on its argument, so the worker half of a
## build may call it (`material_for_biome` does).
static func _world_to_tile(xz: Vector2) -> Vector2i:
	return Vector2i(floori(xz.x / TILE_SIZE), floori(xz.y / TILE_SIZE))

## Phase 42 review pass 9 — STATIC for the same reason (`_neighbour_runs` runs on the worker).
static func _tile_to_chunk(tile: Vector2i) -> Vector2i:
	return Vector2i(floori(float(tile.x) / float(CHUNK_SIZE)), floori(float(tile.y) / float(CHUNK_SIZE)))

static func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]

## Phase 42 review pass 9 — STATIC: the worker half of a build keys chunks too (`_neighbour_runs`).
static func _chunk_key(chunk_pos: Vector2i) -> String:
	return "%d,%d" % [chunk_pos.x, chunk_pos.y]

## Parse a "gx,gz" tile key back into a tile coordinate.
func _key_to_tile(key: String) -> Vector2i:
	return _parse_xy(str(key))

## Mark the chunk containing `tile` as dirty for persistence.
func _mark_dirty(tile: Vector2i) -> void:
	_dirty_chunks[_chunk_key(_tile_to_chunk(tile))] = true

## The biome a resolve falls back to when nothing asked a terrain slice — see the
## `DEFAULT_BIOME` constant (Phase 42 review pass 9).
func _biome_at(xz: Vector2) -> String:
	if terrain_slice != null and terrain_slice.has_method("get_biome_at"):
		return terrain_slice.get_biome_at(xz)
	return DEFAULT_BIOME

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
	return colours[material]

## The instance ACCESSOR form of `natural_color`: with no gathered map it asks the terrain slice
## for this position's biome, in exactly the shape `gather_biomes_for` builds.
func _natural_color(world_xz: Vector2, biomes: Dictionary = {}, colours: Dictionary = {}, depth: float = 0.0) -> Color:
	return natural_color(world_xz, _biomes_or_lookup(world_xz, biomes), colours, depth,
		_field(_world_seed(), _vein_taken))

## A caller with no gathered biome map (an isolated test, a direct call) gets the one answer the
## terrain slice owes for this world position.
##
## Phase 42 review pass 10 — the test is now a LOOKUP OF THIS POSITION'S CHUNK, not "is the map
## non-empty". The old form returned any non-empty map untouched, so a PARTIALLY populated one —
## the realistic case, since a caller that names one chunk does not necessarily name the one a
## stray position falls in — passed straight through, and `biome_of` then answered
## `DEFAULT_BIOME` for the missing chunk, silently tinting a real chunk as TemperateForest. A
## miss is now resolved from the terrain slice (the same read `_biome_at` makes) and folded into
## a COPY, so the caller's map is never mutated and the answer is the chunk's real biome.
func _biomes_or_lookup(world_xz: Vector2, biomes: Dictionary) -> Dictionary:
	var extent := float(CHUNK_SIZE * TILE_SIZE)
	var ckey := _chunk_key(Vector2i(floori(world_xz.x / extent), floori(world_xz.y / extent)))
	if biomes.has(ckey) or terrain_slice == null:
		return biomes
	var filled := biomes.duplicate()
	filled[ckey] = _biome_at(world_xz)
	return filled

## Resolve a material key to its terrain colour (falling back to green for
## unknown keys). Pure (a `const` lookup), so the worker half may call it.
static func _material_color(material: String) -> Color:
	return MATERIAL_COLORS.get(material, FALLBACK_TERRAIN_COLOR)

## Top of a tile's highest solid run, or BEDROCK_DEPTH when nothing is solid.
func _column_top_at_tile(tile: Vector2i) -> float:
	var runs := get_runs_at_tile(tile)
	if runs.is_empty():
		return BEDROCK_DEPTH
	return float(runs[-1]["top"])

## Rebuild the chunk holding `tile` — and every chunk whose mesh READS that tile.
##
## A wall face is emitted from the DIFFERENCE between a column's runs and its
## neighbour's, so a chunk's mesh depends on the columns just ACROSS its edge. A
## tile on a chunk boundary is a neighbour column to the next chunk's tiles, so
## editing it changes what THOSE emit: rebuild only the tile's own chunk and the
## neighbour keeps drawing the wall it had — a see-through slot where the seam
## terrain now differs (mine a tunnel into a seam tile and the mouth is open), and
## a ghost wall where it no longer does. Nothing else rebuilds a chunk when its
## neighbour changes, so the hole would stay for the session.
##
## Only the four edge-ADJACENT chunks can read the tile, and only when the tile is
## actually on that edge, so this is one chunk build in a chunk's interior and at
## most three at a corner (see `_touched_chunks`).
##
## Phase 42 REVIEW — the rebuild is DISPATCHED, not built here. `ChunkManager.request_rebuild`
## hands it to the worker like any other streamed chunk, which is the whole point of the
## phase: this method used to build up to three chunks SYNCHRONOUSLY in the frame that
## placed the block, the exact stall the worker exists to remove. Two cases it also fixes:
##
##   * a chunk whose build is still IN FLIGHT has no cached heightmap yet, so the old
##     `_heightmaps.has(ckey)` guard skipped it entirely and the edit was LOST — the
##     in-flight result then attached the pre-edit arrays. `request_rebuild` needs no
##     cached map: it supersedes the in-flight build and dispatches a fresh one.
##   * a chunk that is NOT in the streamed set is a no-op there, which is the existing
##     rule: it has no node to refresh, and it rebuilds from the current edit log when it
##     streams back in. Building it here would resurrect a chunk the manager has already
##     streamed away (see `apply_edits`).
##
## A slice with NO manager wired (the suite, a probe) keeps the synchronous build, and only
## for a chunk that is LOADED — the same rule `ChunkManager.request_rebuild` applies on the
## other path (`if not _loaded.has(key): return`), and the same rule `apply_edits` applies
## for a re-scope. The guard used to be `_heightmaps.has(ckey)`, and since the Phase 41
## review that map deliberately RETAINS the one-tile ring around the loaded window, so an
## unloaded neighbour that a loaded chunk can still ask about answered TRUE: an edit on a
## chunk edge rebuilt — and so RESURRECTED — a chunk `ChunkManager` had already streamed
## away and would never stream out again. A loaded chunk always has its cached map
## (`build_chunk` stores it and `_prune_heightmaps` keeps it), so `_chunks` is the guard.
func _rebuild_chunk_at_tile(tile: Vector2i) -> void:
	for chunk in _touched_chunks(tile):
		_rebuild_chunk(chunk)

## Rebuild ONE chunk by the route described above: dispatched through the manager when one is
## wired, else synchronously and only when the chunk is loaded.
func _rebuild_chunk(chunk: Vector2i) -> void:
	if chunk_manager != null and chunk_manager.has_method("request_rebuild"):
		chunk_manager.request_rebuild(chunk)
		return
	var ckey := _chunk_key(chunk)
	if _chunks.has(ckey):
		build_chunk(chunk, _heightmaps[ckey])

## The chunks whose mesh reads `tile`, deduplicated: the tile's own chunk plus each
## edge-adjacent one the tile sits on the edge of. A corner tile names three distinct
## chunks; an interior tile names one.
func _touched_chunks(tile: Vector2i) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for probe in [tile, Vector2i(tile.x - 1, tile.y), Vector2i(tile.x + 1, tile.y),
			Vector2i(tile.x, tile.y - 1), Vector2i(tile.x, tile.y + 1)]:
		var chunk := _tile_to_chunk(probe)
		var ckey := _chunk_key(chunk)
		if seen.has(ckey):
			continue
		seen[ckey] = true
		out.append(chunk)
	return out
