extends Node
## Voxel slice — builds a visible, walkable terrain mesh from chunk heightmaps,
## and exposes an edit API for mining (carve a solid span → material) and
## building (add a solid span → consume material).
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : chunk_ready(chunk_pos, heightmap)
##         block_mine_requested(position, normal)
##         block_place_requested(position, normal)
##         block_cycle_material_requested()
##   OUT : block_mined(material, quantity, position)
##         block_placed(material, position)
##         block_place_material_changed(material)
##
## Public API:
##   build_chunk(chunk_pos, heightmap) -> void
##   mine_block(world_pos, normal)     -> Dictionary  { success, material, quantity, position }
##   place_block(world_pos, normal)    -> bool
##   get_voxel_height_at(world_pos)    -> float
##   sample_support_height_at(world_pos, from_y) -> float
##   get_column_runs_at(world_xz)      -> Array      (the column's solid runs)
##   collision_faces(chunk_pos, heightmap) -> PackedVector3Array
##   get_edits() / get_edit_materials()   -> Dictionary
##   apply_edits(edits, materials)        -> void
##   legacy_edit_ops(height, base_top, materials) -> Array   (static, pure)
##   set_place_material / get_place_material / cycle_place_material
##   material_for_biome(biome, world_xz) -> String
##   vein_deposits(chunk_pos, heightmap) -> Array   (rare-vein raised deposits)
##
## Phase 41 — a column is a SPARSE list of solid RUNS, bottom → top, not one top
## ordinate:
##
##   [{ "bottom": float, "top": float, "material": String }]
##
## `material` is "" for natural ground (tinted by the biome's material roll) and
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
##
## Mining a roof therefore does not touch the floor: each edit names the span it
## acted on, and resolving a column re-plays them over the tile's natural run. A
## pre-Phase-41 save stored a bare absolute height per tile; that shape still
## loads (see `legacy_edit_ops`) and is migrated to the same typed edits.

## Shared box authoring for the rare-vein deposits (Phase 31).
const MeshUtil := preload("res://src/core/mesh_util.gd")

## CHUNK_SIZE is defined once on TerrainSlice and accessed via terrain_slice.CHUNK_SIZE.
## The local alias below keeps internal uses readable without duplicating the value.
const CHUNK_SIZE  := 64        # alias — authoritative copy lives in TerrainSlice
const TILE_SIZE   := 0.5       # world units per tile (XZ) — half the former 1.0 size
const STEP_HEIGHT := 0.125     # world units per quantised height step (smooth, walkable — no jumps)
## Phase 41 — the world's FLOOR. It replaces the old `MIN_HEIGHT := 0.0`, which was
## "bedrock" only in the sense that mining stopped at zero: the ground has real
## thickness now, so a column is solid from BEDROCK_DEPTH up to its surface, a
## tunnel has room to exist underneath it, and mining descends one STEP_HEIGHT at
## a time until the floor refuses. MAX_HEIGHT stays the build cap.
const BEDROCK_DEPTH := -8.0    # cannot mine below this — the world's floor
const MAX_HEIGHT    := 16.0    # build cap — cannot place above this

## Terrain collision lives on its own layer (layer 2 / bit 1) so the player's
## block ray can target terrain without hitting the player's own body.
const TERRAIN_COLLISION_LAYER := 2

## Biome → weighted ground-material distribution (material key → weight out of
## 100). A faithful transcription of each biome's fabric `evaluateSpawn` prose
## (fabric/world/biomes/*.js), normalised to 100: the biome's dominant rock /
## metal / crystal is the bulk of the surface, and a rarer ore appears only
## where that biome's prose actually grants one (sparse veins). Wood materials
## (Thornwood / Duskfiber) are deliberately absent — their prose spawns them as
## trees, not as ground to mine, so trees (TreeSlice, Phase 31) are the only wood
## source. Aethermite is a deep ley-line ore (see the Aethermite
## entity: "deep underground near ley lines"), so it is granted only to the two
## biomes whose prose spawns it — VolcanicBadlands (0.2) and TwilightGrove
## (0.15) — and never invented for the temperate biomes.
const BIOME_MATERIALS: Dictionary = {
	# prose: ferrite outcrops 0.6; thornwood 0.8 is a tree, not ground
	"TemperateForest":    { "Ferrite": 100 },
	# prose: ferrite deposits 0.4; thornwood 0.1 is a tree, not ground
	"TemperateGrassland": { "Ferrite": 100 },
	# prose: ashite 0.9 / aethermite 0.2 / ferrite 0.1
	"VolcanicBadlands":   { "Ashite": 75, "Aethermite": 17, "Ferrite": 8 },
	# prose: lumenfite 0.5 / aethermite 0.15; duskfiber 0.9 is a tree, not ground
	"TwilightGrove":      { "Lumenfite": 77, "Aethermite": 23 },
	# prose: voidite 0.7 / ferrite 0.3
	"VoidRift":           { "Voidite": 70, "Ferrite": 30 },
}

## Terrain tint per material key — makes each ground material visually distinct
## (the whole terrain was previously one flat green). Keyed by the fabric
## material entity names in GameData.MATERIALS.
const MATERIAL_COLORS: Dictionary = {
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

## Materials that read as SPARSE VEINS rather than bulk ground: Aethermite is a
## deep ley-line ore, Lumenfite the twilight crystal, Voidite the rift ore. A
## rare vein is tinted AND given a small raised deposit so it is recognizable
## from a distance, while the common ground (Ferrite, Ashite) stays flat
## dirt/rock — the "mostly plain ground with sparse valuable veins" read Phase 31
## asks for.
const RARE_VEIN_MATERIALS: Array = ["Aethermite", "Lumenfite", "Voidite"]
## Small raised deposit geometry: purely VISUAL. The run's height and collision
## are unchanged, so mining a vein still yields exactly one STEP_HEIGHT slice.
const VEIN_DEPOSIT_HEIGHT := 0.22
## Inset from the tile edge, so adjacent deposits never touch and the tile grid
## stays readable.
const VEIN_DEPOSIT_INSET := 0.16

## Active chunk containers keyed by "x,y" string.
var _chunks: Dictionary = {}
## Base heightmaps keyed by "x,y" string (the unedited noise terrain).
var _heightmaps: Dictionary = {}
## Voxel edits keyed by "gx,gz" string → Array of typed run edits, in the order
## they were applied (see the class docstring). The column's runs are the tile's
## natural run with this list replayed over it, so an edit is a description of
## what the player DID, not a replacement of what the ground IS.
var _edits: Dictionary = {}

## Chunks touched by an edit since the last save, keyed by "cx,cz" string → true.
## Drives the per-chunk persistence manifest so only dirty chunks are re-serialized.
var _dirty_chunks: Dictionary = {}

## Set by game_root: terrain (biome + base height) and inventory (material flow).
var terrain_slice: Node = null
var inventory_slice: Node = null

## Authority mode (Phase 18). When true (host / single-player), this slice owns
## world edits: mine/place requests are validated and applied here, and their
## results are broadcast via block_changed. When false (client), edits are
## forwarded to the host via block_edit_intent and applied only when the host's
## authoritative block_changed arrives. Set by game_root before _ready().
var is_authoritative: bool = true

## Material used by place_block; cycled via cycle_place_material(). Empty until
## the player cycles onto a material they actually hold in inventory.
var _place_material: String = ""

## Single world-level safety floor shared by all chunks (prevents the player from
## ever falling through the world). Created once in _ready(). It sits one unit
## BELOW BEDROCK_DEPTH: the terrain's own runs are the ground, and a floor slab
## higher than them would block a player mining down to the floor.
var _world_floor: StaticBody3D = null

func _ready() -> void:
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
func build_chunk(chunk_pos: Vector2i, heightmap: Array) -> void:
	var key := _chunk_key(chunk_pos)

	# Remember the base heightmap so edits can be reapplied on rebuild.
	_heightmaps[key] = heightmap

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
	var surface := _build_terrain_surface(chunk_pos, heightmap)
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = surface
	mesh_inst.material_override = _terrain_material()
	root.add_child(mesh_inst)

	var deposits := vein_deposits(chunk_pos, heightmap)
	if not deposits.is_empty():
		var deposit_st := SurfaceTool.new()
		deposit_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for deposit in deposits:
			MeshUtil.add_box(deposit_st, deposit["position"], deposit["size"], deposit["color"])
		var deposit_inst := MeshInstance3D.new()
		deposit_inst.mesh = deposit_st.commit()
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
	trimesh.set_faces(_surface_vertices(surface))
	# Both sides of a wall collide, so a body inside a tunnel is held by the roof
	# from below as well as by the floor from above.
	trimesh.backface_collision = true
	col_shape.shape = trimesh
	static_body.add_child(col_shape)
	root.add_child(static_body)

## The terrain's visible AND collidable surface for one chunk — no rare-vein
## deposits, which are decoration. Built once per rebuild and shared by the
## MeshInstance3D and the trimesh, so what the player sees and what they stand on
## cannot drift apart.
func _build_terrain_surface(chunk_pos: Vector2i, heightmap: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var origin_x := chunk_pos.x * CHUNK_SIZE * TILE_SIZE
	var origin_z := chunk_pos.y * CHUNK_SIZE * TILE_SIZE

	for tz in range(CHUNK_SIZE):
		for tx in range(CHUNK_SIZE):
			var runs := _column_runs(heightmap, chunk_pos, tx, tz)
			if runs.is_empty():
				continue
			var bx := origin_x + tx * TILE_SIZE
			var bz := origin_z + tz * TILE_SIZE
			var world_xz := Vector2(bx + TILE_SIZE * 0.5, bz + TILE_SIZE * 0.5)
			for run in runs:
				var rbottom := float(run["bottom"])
				var rtop := float(run["top"])
				var color := _run_color(run, world_xz)

				# Top face — only where nothing is solid directly above this run, so
				# the natural ground under a placed block stays hidden (and a ledge
				# under an overhang still shows).
				if not runs_cover_y(runs, rtop + STEP_HEIGHT * 0.5):
					_add_face(st,
						Vector3(bx,              rtop, bz),
						Vector3(bx,              rtop, bz + TILE_SIZE),
						Vector3(bx + TILE_SIZE, rtop, bz + TILE_SIZE),
						Vector3(bx + TILE_SIZE, rtop, bz),
						Vector3.UP, color)

				# Underside face — the CEILING of a tunnel, or an overhang. The span
				# below the run is empty per-column, which is the per-column reading
				# of "a neighbour run ends above the local run". The base run never
				# emits one: BEDROCK_DEPTH is the world's floor, not a gap.
				if rbottom > BEDROCK_DEPTH and not runs_cover_y(runs, rbottom - STEP_HEIGHT * 0.5):
					_add_face(st,
						Vector3(bx,              rbottom, bz),
						Vector3(bx + TILE_SIZE, rbottom, bz),
						Vector3(bx + TILE_SIZE, rbottom, bz + TILE_SIZE),
						Vector3(bx,              rbottom, bz + TILE_SIZE),
						Vector3.DOWN, color)

				# Side walls — every part of this run the neighbour does NOT fill.
				# Subtracting per neighbour is what keeps a higher neighbour's own
				# wall (it emits that one) from being drawn twice, and what lets a
				# wall span a tunnel's height in one piece.
				_add_wall_faces(st, run, color, heightmap, chunk_pos, tx, tz - 1,
					Vector2(bx, bz), Vector2(bx + TILE_SIZE, bz), Vector3(0, 0, -1))
				_add_wall_faces(st, run, color, heightmap, chunk_pos, tx, tz + 1,
					Vector2(bx + TILE_SIZE, bz + TILE_SIZE), Vector2(bx, bz + TILE_SIZE), Vector3(0, 0, 1))
				_add_wall_faces(st, run, color, heightmap, chunk_pos, tx - 1, tz,
					Vector2(bx, bz + TILE_SIZE), Vector2(bx, bz), Vector3(-1, 0, 0))
				_add_wall_faces(st, run, color, heightmap, chunk_pos, tx + 1, tz,
					Vector2(bx + TILE_SIZE, bz), Vector2(bx + TILE_SIZE, bz + TILE_SIZE), Vector3(1, 0, 0))

	return st.commit()

## The collision triangle soup for one chunk: exactly the triangles
## `_build_terrain_surface` emits. `build_chunk` taps the surface it ALREADY built
## (one mesh per chunk, not two); this entry point exists so a caller that has no
## chunk node — the suite — can assert the trimesh's SHAPE headlessly. Physics
## itself is INERT inside the suite (`_run_tests()` runs synchronously in
## `GameRoot._ready()`, where a `move_and_slide()` never registers a collision,
## verified in ROADMAP §Phase 39), so "the trimesh stops a body" is exercised in
## GAME only and this proves the geometry it is built from.
func collision_faces(chunk_pos: Vector2i, heightmap: Array) -> PackedVector3Array:
	return _surface_vertices(_build_terrain_surface(chunk_pos, heightmap))

## The triangles of a committed terrain surface, in order. Static and pure.
static func _surface_vertices(mesh: ArrayMesh) -> PackedVector3Array:
	if mesh == null or mesh.get_surface_count() == 0:
		return PackedVector3Array()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	return verts

## Free a chunk's visual + collision nodes without touching its base heightmap
## or any voxel edits. The heightmap is cached in `_heightmaps` so a later
## build_chunk() re-applies edits and restores the column exactly. Used by
## ChunkManager to stream chunks out of view.
func unload_chunk(chunk_pos: Vector2i) -> void:
	var key := _chunk_key(chunk_pos)
	if _chunks.has(key):
		_chunks[key].queue_free()
		_chunks.erase(key)

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
## step": a top-face hit takes the topmost run's last step, any other hit takes
## the block the ray hit. That is what lets a tunnel ROOF be mined without taking
## the tunnel floor with it, and it is why mining is refused at BEDROCK_DEPTH —
## there is nothing below the floor to yield.
func mine_block(world_pos: Vector3, normal: Vector3 = Vector3.UP) -> Dictionary:
	# Resolve the span BEFORE spending tool durability, so a blocked mine never
	# consumes the held pick (the repo's standing atomic-refusal rule).
	var probe := _resolve_edit_tile("mine", world_pos, normal)
	var tile: Vector2i = probe["tile"]
	var span := _mine_span(get_runs_at_tile(tile), world_pos, normal)
	if span.is_empty():
		return { "success": false, "material": "", "quantity": 0, "position": world_pos }

	# Tool durability: mining consumes the held pick. A broken pick blocks the
	# mine; bare-handed (no pick) mining is still allowed.
	var pick := _held_pick()
	if pick != "" and inventory_slice != null and inventory_slice.has_method("use_item"):
		if not inventory_slice.use_item(pick, "mine"):
			return { "success": false, "material": "", "quantity": 0, "position": world_pos }

	_append_edit(tile, { "op": "remove", "bottom": span["bottom"], "top": span["top"] })
	var material := str(span["material"])
	if material == "":
		material = material_for_biome(_biome_at(probe["xz"]), probe["xz"])
	_mark_dirty(tile)
	_rebuild_chunk_at_tile(tile)

	if inventory_slice != null and inventory_slice.has_method("add_item"):
		inventory_slice.add_item(material, 1)

	var pos := Vector3(world_pos.x, float(span["top"]), world_pos.z)
	GameBus.block_mined.emit(material, 1, pos)
	GameBus.block_changed.emit("mine", world_pos, normal, material)
	return { "success": true, "material": material, "quantity": 1, "position": pos }

## Add one STEP_HEIGHT of the selected material on the column under world_pos.
## Consumes the material from the inventory. Returns true on success; false if no
## material is selected, the cell is already solid, or the build cap is reached.
func place_block(world_pos: Vector3, normal: Vector3) -> bool:
	var material := _place_material
	if material == "":
		return false

	# The placement is validated BEFORE anything is spent, so a refused placement
	# leaves no side effect to roll back.
	var probe := _resolve_edit_tile("place", world_pos, normal)
	var tile: Vector2i = probe["tile"]
	var span := _place_span(get_runs_at_tile(tile), world_pos, normal)
	if span.is_empty():
		return false

	if inventory_slice != null and inventory_slice.has_method("drop_item"):
		if not inventory_slice.drop_item(material, 1):
			return false

	_append_edit(tile, { "op": "add", "bottom": span["bottom"], "top": span["top"], "material": material })
	_mark_dirty(tile)
	_rebuild_chunk_at_tile(tile)

	var pos := Vector3(probe["xz"].x, float(span["top"]), probe["xz"].y)
	GameBus.block_placed.emit(material, pos)
	GameBus.block_changed.emit("place", world_pos, normal, material)
	return true

## Top of the column at a world XZ position — the highest solid run's top, or
## BEDROCK_DEPTH when the column is mined out to the floor. This is still the
## surface a WALKING body stands on. Inside a tunnel the body's own Y decides
## which run supports it, which is what `sample_support_height_at` answers.
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

## The player-placed materials each edited tile carries, bottom → top, derived
## from the tile's `add` ops. Kept as an accessor because the pre-Phase-41 save
## shape stored the material stacks BESIDE the heights; nothing writes them
## separately any more — the material travels inside the edit that placed it.
func get_edit_materials() -> Dictionary:
	var out: Dictionary = {}
	for key in _edits:
		var stack: Array = []
		for op in _edits[key]:
			if op is Dictionary and str(op.get("op", "")) == "add" and str(op.get("material", "")) != "":
				stack.append(str(op["material"]))
		if not stack.is_empty():
			out[key] = stack
	return out

## Restore voxel edits from a saved world snapshot and rebuild affected chunks.
##
## TOLERANT of both save shapes, deliberately: a value that is an Array is the
## Phase 41 typed run edits and is adopted as-is, while a bare number (or a string
## that parses as one) is a pre-Phase-41 absolute quantised height and is MIGRATED
## (see `legacy_edit_ops`) against the tile's natural run — never dropped, because
## a migration that "repairs" a world by discarding player work is worse than a
## refusal. `materials` maps "gx,gz" → Array of material keys, the other half of
## the legacy shape.
func apply_edits(edits: Dictionary, materials: Dictionary = {}) -> void:
	_edits.clear()
	for key in edits:
		var value: Variant = edits[key]
		if value is Array:
			_edits[key] = _normalise_ops(value)
			continue
		var tile := _key_to_tile(str(key))
		var stack: Array = materials.get(key, [])
		_edits[key] = legacy_edit_ops(float(value), _base_top_for_tile(tile), stack)
	# _dirty_chunks is NOT cleared here: dirty tracking is reset only by
	# clear_dirty_chunks() after a successful save (called from game_root._on_save_completed).
	# Restored on-disk edits are not dirty — they were already persisted.
	for ckey in _heightmaps:
		var parts: PackedStringArray = str(ckey).split(",")
		build_chunk(Vector2i(int(parts[0]), int(parts[1])), _heightmaps[ckey])

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

## Material yielded by mining a tile in the given biome (deterministic per tile,
## rarity-weighted). The common "rocky" material dominates; rarer ores appear as
## sparse veins. No wood materials — those come from trees, not the ground.
func material_for_biome(biome: String, world_xz: Vector2) -> String:
	var weights: Dictionary = BIOME_MATERIALS.get(biome, { "Ferrite": 1 })
	if weights.is_empty():
		return "Ferrite"
	var tile := _world_to_tile(world_xz)
	# Deterministic per-tile roll (stable across sessions, no randi()).
	var roll := posmod(tile.x * 73856093 + tile.y * 19349663, 100)
	var cumulative := 0
	for material in weights:
		cumulative += int(weights[material])
		if roll < cumulative:
			return str(material)
	return str(weights.keys()[0])

## Small raised deposits for the rare veins in one chunk, as
## `[{ "position": Vector3, "size": Vector3, "color": Color }]` — the geometry
## build_chunk adds on top of the flat ground. Only a NATURAL column qualifies: a
## player-placed block is never a vein. Mining does NOT remove a deposit — the
## mined block carries no placed material, so its material roll is unchanged and
## the deposit simply rides down to the lowered column top with it. Pure, so the
## rare-vein read is testable headlessly without a renderer.
func vein_deposits(chunk_pos: Vector2i, heightmap: Array) -> Array:
	var out: Array = []
	var deposit_size := Vector3(
		TILE_SIZE - VEIN_DEPOSIT_INSET * 2.0,
		VEIN_DEPOSIT_HEIGHT,
		TILE_SIZE - VEIN_DEPOSIT_INSET * 2.0)
	for tz in range(CHUNK_SIZE):
		for tx in range(CHUNK_SIZE):
			var runs := _column_runs(heightmap, chunk_pos, tx, tz)
			if runs.is_empty():
				continue
			var surface: Dictionary = runs[-1]
			if str(surface.get("material", "")) != "":
				continue   # a placed block is never a vein
			var h := float(surface["top"])
			var world_xz := Vector2(
				(chunk_pos.x * CHUNK_SIZE + tx) * TILE_SIZE + TILE_SIZE * 0.5,
				(chunk_pos.y * CHUNK_SIZE + tz) * TILE_SIZE + TILE_SIZE * 0.5)
			var material := material_for_biome(_biome_at(world_xz), world_xz)
			if not RARE_VEIN_MATERIALS.has(material):
				continue
			out.append({
				"position": Vector3(world_xz.x, h + VEIN_DEPOSIT_HEIGHT * 0.5, world_xz.y),
				"size":     deposit_size,
				"color":    _material_color(material),
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
		if str(o.get("op", "")) == "add":
			out = add_span(out, bottom, top, str(o.get("material", "")))
		else:
			out = remove_span(out, bottom, top)
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
static func legacy_edit_ops(legacy_height: float, base_top: float, materials: Array = []) -> Array:
	var placed := materials.size()
	var natural_top := legacy_height - float(placed) * STEP_HEIGHT
	# Nothing can sit above the edited top, so a legacy height above the natural
	# surface is one plain span up to it (the stacked-material reading degenerates
	# to this when the player only ever built UP from natural ground).
	if placed == 0 or natural_top > base_top:
		if legacy_height >= base_top:
			return [{ "op": "add", "bottom": base_top, "top": legacy_height, "material": "" }]
		return [{ "op": "remove", "bottom": legacy_height, "top": base_top }]
	var ops: Array = []
	if natural_top < base_top:
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

func _voxel_height(raw_height: float) -> float:
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
## which never touches the terrain sampler).
func _column_runs(heightmap: Array, chunk_pos: Vector2i, tx: int, tz: int) -> Array:
	var gx := chunk_pos.x * CHUNK_SIZE + tx
	var gz := chunk_pos.y * CHUNK_SIZE + tz
	var top := _voxel_height(float(heightmap[tz * CHUNK_SIZE + tx]))
	var base: Array = []
	if top > BEDROCK_DEPTH:
		base.append({ "bottom": BEDROCK_DEPTH, "top": top, "material": "" })
	return apply_run_ops(base, _edits.get(_tile_key(Vector2i(gx, gz)), []))

## A neighbour tile's runs, or `null` when they are UNKNOWN — across a chunk edge
## whose chunk is not built. Unknown means "no wall is invented": the outer edge of
## the streamed window is an open cross-section, and at a loaded chunk seam the
## side carrying the material emits the facing wall itself (its own subtraction
## sees the pit). Pure geometry, no node state.
func _neighbour_runs(heightmap: Array, chunk_pos: Vector2i, tx: int, tz: int) -> Variant:
	if tx >= 0 and tx < CHUNK_SIZE and tz >= 0 and tz < CHUNK_SIZE:
		return _column_runs(heightmap, chunk_pos, tx, tz)
	var gx := chunk_pos.x * CHUNK_SIZE + tx
	var gz := chunk_pos.y * CHUNK_SIZE + tz
	var chunk := _tile_to_chunk(Vector2i(gx, gz))
	var ckey := _chunk_key(chunk)
	if not _heightmaps.has(ckey):
		return null
	var hm: Array = _heightmaps[ckey]
	return _column_runs(hm, chunk, gx - chunk.x * CHUNK_SIZE, gz - chunk.y * CHUNK_SIZE)

## Angle a run's colour: a player-placed span takes its own material's colour, a
## natural one the biome material roll (which is also how a rare vein gets its
## tint and its deposit).
func _run_color(run: Dictionary, world_xz: Vector2) -> Color:
	var material := str(run.get("material", ""))
	if material != "":
		return _material_color(material)
	return _natural_color(world_xz)

## Append one quad (two triangles) to the visual surface. a, b, c, d are in
## counter-clockwise order seen from the normal side. color tints the face.
func _add_face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	st.set_normal(normal)
	st.set_color(color)
	st.set_uv(Vector2(0, 0)); st.add_vertex(a)
	st.set_uv(Vector2(1, 0)); st.add_vertex(b)
	st.set_uv(Vector2(1, 1)); st.add_vertex(c)
	st.set_uv(Vector2(0, 0)); st.add_vertex(a)
	st.set_uv(Vector2(1, 1)); st.add_vertex(c)
	st.set_uv(Vector2(0, 1)); st.add_vertex(d)

## Emit the exposed part of one run's side wall against one neighbour. e1/e2 are
## the wall's two vertical edges in XZ; the wall is drawn only where this run has
## material the neighbour does not (see subtract_runs).
func _add_wall_faces(st: SurfaceTool, run: Dictionary, color: Color, heightmap: Array, chunk_pos: Vector2i, ntx: int, ntz: int, e1: Vector2, e2: Vector2, normal: Vector3) -> void:
	var neighbour: Variant = _neighbour_runs(heightmap, chunk_pos, ntx, ntz)
	if neighbour == null:
		return   # unknown neighbour: invent no wall (see _neighbour_runs)
	for seg in subtract_runs(run, neighbour):
		var bottom := float(seg["bottom"])
		var top := float(seg["top"])
		if top <= bottom:
			continue
		_add_face(st,
			Vector3(e1.x, top,    e1.y),
			Vector3(e2.x, top,    e2.y),
			Vector3(e2.x, bottom, e2.y),
			Vector3(e1.x, bottom, e1.y),
			normal, color)

## The terrain's per-chunk material: per-column vertex colour, both faces
## rendered, so the shell is never see-through regardless of triangle winding.
func _terrain_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true
	mat.roughness    = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _on_chunk_ready(chunk_pos: Vector2i, heightmap: Array) -> void:
	build_chunk(chunk_pos, heightmap)

func _on_mine_requested(position: Vector3, normal: Vector3) -> void:
	if is_authoritative:
		mine_block(position, normal)
	else:
		GameBus.block_edit_intent.emit("mine", position, normal, "")

## The held mining pick's item_id, or "" when the player has none. Delegates to
## the inventory's fabric-driven tool lookup ("pick" → FerritePick/VeilsteelPick).
func _held_pick() -> String:
	if inventory_slice == null or not inventory_slice.has_method("find_tool"):
		return ""
	return str(inventory_slice.find_tool("pick"))

func _on_place_requested(position: Vector3, normal: Vector3) -> void:
	if is_authoritative:
		place_block(position, normal)
	else:
		GameBus.block_edit_intent.emit("place", position, normal, _place_material)

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

## The span a mine removes, or {} when it is refused. A top-face hit takes the
## topmost run's last step and refuses at BEDROCK_DEPTH; any other hit takes the
## STEP_HEIGHT block the ray landed on — preferring the block BELOW the hit plane
## when the ray lands exactly on a step boundary, so aiming at the very top edge of
## a wall still mines the wall instead of refusing.
func _mine_span(runs: Array, world_pos: Vector3, normal: Vector3) -> Dictionary:
	if runs.is_empty():
		return {}
	if normal.y > 0.5:
		var top_run: Dictionary = runs[-1]
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
## the build cap would be passed). A top-face hit stacks on the column's topmost
## run; any other hit fills the STEP_HEIGHT cell the ray landed on, which is what
## lets a player lay a ceiling under a tunnel roof.
func _place_span(runs: Array, world_pos: Vector3, normal: Vector3) -> Dictionary:
	var bottom := BEDROCK_DEPTH
	if normal.y > 0.5:
		if not runs.is_empty():
			bottom = float(runs[-1]["top"])
	else:
		bottom = maxf(floorf(world_pos.y / STEP_HEIGHT) * STEP_HEIGHT, BEDROCK_DEPTH)
	var top := bottom + STEP_HEIGHT
	if top > MAX_HEIGHT:
		return {}
	if runs_cover_y(runs, bottom + STEP_HEIGHT * 0.5):
		return {}   # the cell already holds material
	return { "bottom": bottom, "top": top }

## Append one typed run edit to a tile's op list.
func _append_edit(tile: Vector2i, op: Dictionary) -> void:
	var key := _tile_key(tile)
	if not _edits.has(key):
		_edits[key] = []
	_edits[key].append(op)

## Coerce a loaded edit list into plain { bottom, top, material } / op dicts with
## numeric fields — JSON hands back Variants, and the run algebra compares floats.
func _normalise_ops(ops: Array) -> Array:
	var out: Array = []
	for op in ops:
		if not (op is Dictionary):
			continue
		var o: Dictionary = op
		var entry := {
			"op":     str(o.get("op", "remove")),
			"bottom": float(o.get("bottom", 0.0)),
			"top":    float(o.get("top", 0.0)),
		}
		if entry["op"] == "add":
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
		_append_edit(tile, { "op": "remove", "bottom": span["bottom"], "top": span["top"] })
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

func _world_to_tile(xz: Vector2) -> Vector2i:
	return Vector2i(floori(xz.x / TILE_SIZE), floori(xz.y / TILE_SIZE))

func _tile_to_chunk(tile: Vector2i) -> Vector2i:
	return Vector2i(floori(float(tile.x) / float(CHUNK_SIZE)), floori(float(tile.y) / float(CHUNK_SIZE)))

func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]

func _chunk_key(chunk_pos: Vector2i) -> String:
	return "%d,%d" % [chunk_pos.x, chunk_pos.y]

## Parse a "gx,gz" tile key back into a tile coordinate.
func _key_to_tile(key: String) -> Vector2i:
	var parts: PackedStringArray = str(key).split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

## Mark the chunk containing `tile` as dirty for persistence.
func _mark_dirty(tile: Vector2i) -> void:
	_dirty_chunks[_chunk_key(_tile_to_chunk(tile))] = true

func _biome_at(xz: Vector2) -> String:
	if terrain_slice != null and terrain_slice.has_method("get_biome_at"):
		return terrain_slice.get_biome_at(xz)
	return "TemperateForest"

## Tint for a column's top face at world_xz: the topmost player-placed material
## if one is present, otherwise the biome material that mining it would yield.
func _column_color(world_xz: Vector2) -> Color:
	var runs := get_column_runs_at(world_xz)
	if runs.is_empty():
		return FALLBACK_TERRAIN_COLOR
	return _run_color(runs[-1], world_xz)

## Colour a natural (unplaced) terrain column at world_xz, from its biome.
func _natural_color(world_xz: Vector2) -> Color:
	return _material_color(material_for_biome(_biome_at(world_xz), world_xz))

## Resolve a material key to its terrain colour (falling back to green for
## unknown keys).
func _material_color(material: String) -> Color:
	return MATERIAL_COLORS.get(material, FALLBACK_TERRAIN_COLOR)

## Vertical colour layers for a column, bottom → top, one per solid RUN. Each entry
## is { "bottom": float, "top": float, "color": Color }: a natural run takes the
## biome's material colour, a player-placed run its own material's colour. A tunnel
## therefore renders as its floor colour, its gap, and its roof colour — the
## natural/placed split no longer has to be inferred from a block count.
func _column_layers(chunk_pos: Vector2i, heightmap: Array, tx: int, tz: int) -> Array:
	var gx := chunk_pos.x * CHUNK_SIZE + tx
	var gz := chunk_pos.y * CHUNK_SIZE + tz
	var world_xz := Vector2(gx * TILE_SIZE + TILE_SIZE * 0.5, gz * TILE_SIZE + TILE_SIZE * 0.5)
	var layers: Array = []
	for run in _column_runs(heightmap, chunk_pos, tx, tz):
		layers.append({
			"bottom": float(run["bottom"]),
			"top":    float(run["top"]),
			"color":  _run_color(run, world_xz),
		})
	return layers

## Top of a tile's highest solid run, or BEDROCK_DEPTH when nothing is solid.
func _column_top_at_tile(tile: Vector2i) -> float:
	var runs := get_runs_at_tile(tile)
	if runs.is_empty():
		return BEDROCK_DEPTH
	return float(runs[-1]["top"])

func _rebuild_chunk_at_tile(tile: Vector2i) -> void:
	var chunk := _tile_to_chunk(tile)
	var ckey := _chunk_key(chunk)
	if _heightmaps.has(ckey):
		build_chunk(chunk, _heightmaps[ckey])
