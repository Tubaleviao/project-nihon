extends Node
## Voxel slice — builds a visible, walkable terrain mesh from chunk heightmaps,
## and exposes an edit API for mining (remove a block → material) and building
## (place a block → consume material).
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
##   get_edits() / get_edit_materials()   -> Dictionary
##   apply_edits(edits, materials)        -> void
##   set_place_material / get_place_material / cycle_place_material
##   material_for_biome(biome, world_xz) -> String
##
## Terrain is a heightfield: each (x, z) column has a single quantised height.
## Mining lowers a column by one STEP; building raises it by one STEP. Edits are
## stored as absolute quantised heights keyed by global tile coordinate, so they
## survive chunk rebuilds and save/load.

## CHUNK_SIZE is defined once on TerrainSlice and accessed via terrain_slice.CHUNK_SIZE.
## The local alias below keeps internal uses readable without duplicating the value.
const CHUNK_SIZE  := 32        # alias — authoritative copy lives in TerrainSlice
const TILE_SIZE   := 1.0       # world units per tile (XZ)
const STEP_HEIGHT := 0.125     # world units per quantised height step (smooth, walkable — no jumps)
const MIN_HEIGHT  := 0.0       # bedrock — cannot mine below this
const MAX_HEIGHT  := 16.0      # build cap — cannot place above this

## Terrain collision lives on its own layer (layer 2 / bit 1) so the player's
## block ray can target terrain without hitting the player's own body.
const TERRAIN_COLLISION_LAYER := 2

## Biome → material keys mined from its surface. Values are fabric material
## entity keys (GameData.MATERIALS); the dominant material is listed first.
const BIOME_MATERIALS: Dictionary = {
	"TemperateForest":    ["Ferrite", "Thornwood"],
	"TemperateGrassland": ["Ferrite", "Thornwood"],
	"VolcanicBadlands":   ["Ashite", "Aethermite"],
	"TwilightGrove":      ["Duskfiber", "Lumenfite"],
	"VoidRift":           ["Voidite", "Aethermite"],
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

## Active chunk containers keyed by "x,y" string.
var _chunks: Dictionary = {}
## Base heightmaps keyed by "x,y" string (the unedited noise terrain).
var _heightmaps: Dictionary = {}
## Voxel edits keyed by "gx,gz" string → absolute quantised height.
var _edits: Dictionary = {}
## Player-placed materials on each edited tile, keyed by "gx,gz" string → Array
## of material keys (bottom → top). Drives column colour so a placed block keeps
## its own tint instead of inheriting the biome colour.
var _edit_materials: Dictionary = {}

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
## ever falling through the world). Created once in _ready().
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
	floor_shape.position = Vector3(0.0, -0.5, 0.0)
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

	var origin := Vector3(
		chunk_pos.x * CHUNK_SIZE * TILE_SIZE,
		0.0,
		chunk_pos.y * CHUNK_SIZE * TILE_SIZE
	)

	# --- Visual mesh (closed shell) ---
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for tz in range(CHUNK_SIZE):
		for tx in range(CHUNK_SIZE):
			var h := _column_height(heightmap, chunk_pos, tx, tz)
			if h <= 0.0:
				continue
			var bx := origin.x + tx * TILE_SIZE
			var bz := origin.z + tz * TILE_SIZE
			var layers := _column_layers(chunk_pos, heightmap, tx, tz)
			if layers.is_empty():
				continue
			var top_col: Color = layers[-1]["color"]

			# Top face.
			_add_face(st,
				Vector3(bx,              h, bz),
				Vector3(bx,              h, bz + TILE_SIZE),
				Vector3(bx + TILE_SIZE, h, bz + TILE_SIZE),
				Vector3(bx + TILE_SIZE, h, bz),
				Vector3.UP, top_col)

			# North wall.
			var hn := _neighbour_height(heightmap, chunk_pos, tx, tz - 1)
			if hn < h:
				_add_wall_column(st, Vector2(bx, bz), Vector2(bx + TILE_SIZE, bz), Vector3(0, 0, -1), layers, hn, h)

			# South wall.
			var hs := _neighbour_height(heightmap, chunk_pos, tx, tz + 1)
			if hs < h:
				_add_wall_column(st, Vector2(bx + TILE_SIZE, bz + TILE_SIZE), Vector2(bx, bz + TILE_SIZE), Vector3(0, 0, 1), layers, hs, h)

			# West wall.
			var hw := _neighbour_height(heightmap, chunk_pos, tx - 1, tz)
			if hw < h:
				_add_wall_column(st, Vector2(bx, bz + TILE_SIZE), Vector2(bx, bz), Vector3(-1, 0, 0), layers, hw, h)

			# East wall.
			var he := _neighbour_height(heightmap, chunk_pos, tx + 1, tz)
			if he < h:
				_add_wall_column(st, Vector2(bx + TILE_SIZE, bz), Vector2(bx + TILE_SIZE, bz + TILE_SIZE), Vector3(1, 0, 0), layers, he, h)

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = st.commit()

	# Per-column vertex colour (biome/material tint), no texture asset needed.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true
	mat.roughness    = 0.9
	# Render both faces so the terrain shell is never see-through regardless
	# of triangle winding (avoids backface-culled "transparent" hilltops).
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_inst.material_override = mat

	root.add_child(mesh_inst)

	# --- Collision: one solid box per column ---
	var static_body := StaticBody3D.new()
	static_body.collision_layer = TERRAIN_COLLISION_LAYER
	static_body.collision_mask = 0
	for tz in range(CHUNK_SIZE):
		for tx in range(CHUNK_SIZE):
			var h := _column_height(heightmap, chunk_pos, tx, tz)
			if h <= 0.0:
				continue
			var col_shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(TILE_SIZE, h, TILE_SIZE)
			col_shape.shape = box
			col_shape.position = Vector3(
				origin.x + tx * TILE_SIZE + TILE_SIZE * 0.5,
				h * 0.5,
				origin.z + tz * TILE_SIZE + TILE_SIZE * 0.5
			)
			static_body.add_child(col_shape)
	root.add_child(static_body)

	print("VoxelSlice: built chunk %s  tiles=%d" % [key, CHUNK_SIZE * CHUNK_SIZE])

## Free a chunk's visual + collision nodes without touching its base heightmap
## or any voxel edits. The heightmap is cached in `_heightmaps` so a later
## build_chunk() re-applies edits and restores the column exactly. Used by
## ChunkManager to stream chunks out of view.
func unload_chunk(chunk_pos: Vector2i) -> void:
	var key := _chunk_key(chunk_pos)
	if _chunks.has(key):
		_chunks[key].queue_free()
		_chunks.erase(key)
		print("VoxelSlice: unloaded chunk %s" % key)

## Return the set of chunks currently holding live mesh nodes.
func get_loaded_chunks() -> Array:
	var out: Array = []
	for key in _chunks:
		var parts: PackedStringArray = str(key).split(",")
		out.append(Vector2i(int(parts[0]), int(parts[1])))
	return out

## Dump the base heightmaps for all built chunks, keyed by "cx,cz" → Array.
## Used by the host to ship terrain to clients in the world snapshot.
func get_heightmaps() -> Dictionary:
	return _heightmaps.duplicate(true)

## Rebuild chunks from a host-sent heightmap map (client snapshot application).
func apply_heightmaps(heightmaps: Dictionary) -> void:
	for ckey in heightmaps:
		var parts: PackedStringArray = str(ckey).split(",")
		build_chunk(Vector2i(int(parts[0]), int(parts[1])), heightmaps[ckey])

# ---------------------------------------------------------------------------
# Edit API — mining and building
# ---------------------------------------------------------------------------

## Remove one voxel from the column under world_pos, yielding that biome's
## material into the inventory. Returns { success, material, quantity, position }.
## normal disambiguates side-face hits: the ray lands on the boundary between
## two columns, so we step back along the normal into the block being mined.
func mine_block(world_pos: Vector3, normal: Vector3 = Vector3.UP) -> Dictionary:
	# Validate at bedrock BEFORE spending tool durability, so a blocked mine
	# never consumes the held pick.
	var probe := _resolve_edit_tile("mine", world_pos, normal)
	if probe["current"] <= MIN_HEIGHT:
		return { "success": false, "material": "", "quantity": 0, "position": world_pos }

	# Tool durability: mining consumes the held pick. A broken pick blocks the
	# mine; bare-handed (no pick) mining is still allowed.
	var pick := _held_pick()
	if pick != "" and inventory_slice != null and inventory_slice.has_method("use_item"):
		if not inventory_slice.use_item(pick, "mine"):
			return { "success": false, "material": "", "quantity": 0, "position": world_pos }

	var result := _apply_edit("mine", world_pos, normal, "")
	var material: String = str(result["material"])
	var pos: Vector3 = result["pos"]
	var tile: Vector2i = result["tile"]
	var new_h: float = result["new_h"]
	_mark_dirty(tile)

	if inventory_slice != null and inventory_slice.has_method("add_item"):
		inventory_slice.add_item(material, 1)

	GameBus.block_mined.emit(material, 1, pos)
	GameBus.block_changed.emit("mine", world_pos, normal, material)
	print("VoxelSlice: mined %s at (%d,%d) → height %.1f" % [material, tile.x, tile.y, new_h])
	return { "success": true, "material": material, "quantity": 1, "position": pos }

## Place one voxel of the currently selected material on the column adjacent to
## the hit face (in the normal direction). Consumes the material from inventory.
## Returns true on success; false if no material or the build cap is reached.
func place_block(world_pos: Vector3, normal: Vector3) -> bool:
	var material := _place_material
	if material == "":
		return false

	# Consume first so a blocked placement never leaves terrain half-edited.
	if inventory_slice != null and inventory_slice.has_method("drop_item"):
		if not inventory_slice.drop_item(material, 1):
			return false

	var result := _apply_edit("place", world_pos, normal, material)
	if not result["applied"]:
		# Refund the material — placement is blocked at the build cap.
		if inventory_slice != null and inventory_slice.has_method("add_item"):
			inventory_slice.add_item(material, 1)
		return false

	var pos: Vector3 = result["pos"]
	var tile: Vector2i = result["tile"]
	var new_h: float = result["new_h"]
	_mark_dirty(tile)
	GameBus.block_placed.emit(material, pos)
	GameBus.block_changed.emit("place", world_pos, normal, material)
	print("VoxelSlice: placed %s at (%d,%d) → height %.1f" % [material, tile.x, tile.y, new_h])
	return true

## Current (edited) voxel height at a world XZ position, quantised to STEP.
func get_voxel_height_at(world_pos: Vector2) -> float:
	return _voxel_height_at_tile(_world_to_tile(world_pos))

## Dump voxel edits for persistence: { "gx,gz": height }.
func get_edits() -> Dictionary:
	return _edits.duplicate()

## Dump placed-material stacks for persistence: { "gx,gz": [material, ...] }.
func get_edit_materials() -> Dictionary:
	return _edit_materials.duplicate(true)

## Restore voxel edits (heights + placed materials) from a saved world snapshot
## and rebuild affected chunks. `materials` maps "gx,gz" → Array of material keys.
func apply_edits(edits: Dictionary, materials: Dictionary = {}) -> void:
	_edits.clear()
	_edit_materials.clear()
	# _dirty_chunks is NOT cleared here: dirty tracking is reset only by
	# clear_dirty_chunks() after a successful save (called from game_root._on_save_completed).
	# Restored on-disk edits are not dirty — they were already persisted.
	for key in edits:
		_edits[key] = float(edits[key])
	for key in materials:
		var stack: Array = materials[key]
		_edit_materials[key] = stack.duplicate()
	for ckey in _heightmaps:
		var parts: PackedStringArray = str(ckey).split(",")
		build_chunk(Vector2i(int(parts[0]), int(parts[1])), _heightmaps[ckey])

## Group voxel edits by chunk into a persistence manifest:
##   { "cx,cz": { "edits": { "gx,gz": height, ... }, "materials": { "gx,gz": [..] } } }
## Only chunks with edits appear. Used by the world save snapshot so edits are
## stored per-chunk and only dirty chunks need re-serialization.
func get_chunk_manifest() -> Dictionary:
	var manifest: Dictionary = {}
	for key in _edits:
		var chunk := _chunk_key(_tile_to_chunk(_key_to_tile(str(key))))
		if not manifest.has(chunk):
			manifest[chunk] = { "edits": {}, "materials": {} }
		manifest[chunk]["edits"][key] = _edits[key]
	for key in _edit_materials:
		var chunk := _chunk_key(_tile_to_chunk(_key_to_tile(str(key))))
		if not manifest.has(chunk):
			manifest[chunk] = { "edits": {}, "materials": {} }
		manifest[chunk]["materials"][key] = _edit_materials[key].duplicate()
	return manifest

## Restore voxel edits from a chunk manifest (see get_chunk_manifest). Flattens
## the per-chunk grouping back into the global tile-keyed edit tables.
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

## Material yielded by mining a tile in the given biome (deterministic per tile).
func material_for_biome(biome: String, world_xz: Vector2) -> String:
	var materials: Array = BIOME_MATERIALS.get(biome, ["Ferrite"])
	if materials.is_empty():
		return "Ferrite"
	var tile := _world_to_tile(world_xz)
	var idx := absi(tile.x * 73856093 + tile.y * 19349663) % materials.size()
	return str(materials[idx])

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _voxel_height(raw_height: float) -> float:
	return floor(raw_height / STEP_HEIGHT) * STEP_HEIGHT

## Height of the tile at (tx, tz) with edits applied, or 0.0 for out-of-chunk.
func _neighbour_height(heightmap: Array, chunk_pos: Vector2i, tx: int, tz: int) -> float:
	if tx < 0 or tx >= CHUNK_SIZE or tz < 0 or tz >= CHUNK_SIZE:
		return 0.0
	return _column_height(heightmap, chunk_pos, tx, tz)

## Effective height of a column = edit override if present, else quantised base.
func _column_height(heightmap: Array, chunk_pos: Vector2i, tx: int, tz: int) -> float:
	var gx := chunk_pos.x * CHUNK_SIZE + tx
	var gz := chunk_pos.y * CHUNK_SIZE + tz
	var key := _tile_key(Vector2i(gx, gz))
	if _edits.has(key):
		return float(_edits[key])
	return _voxel_height(heightmap[tz * CHUNK_SIZE + tx])

## Append a quad (two triangles) to the visual surface. a, b, c, d are in
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

## Emit the exposed side wall of a column, splitting the vertical span
## [bottom, top] into per-layer segments so each block layer keeps its own
## colour. e1/e2 are the two XZ positions of the wall's vertical edges.
func _add_wall_column(st: SurfaceTool, e1: Vector2, e2: Vector2, normal: Vector3, layers: Array, bottom: float, top: float) -> void:
	for layer in layers:
		var ltop: float = layer["top"]
		var lbottom: float = layer["bottom"]
		var seg_top := minf(ltop, top)
		var seg_bottom := maxf(lbottom, bottom)
		if seg_top <= seg_bottom:
			continue
		_add_face(st,
			Vector3(e1.x, seg_top,    e1.y),
			Vector3(e2.x, seg_top,    e2.y),
			Vector3(e2.x, seg_bottom, e2.y),
			Vector3(e1.x, seg_bottom, e1.y),
			normal, layer["color"])

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
## tile-resolution and height math as mine_block/place_block, but does NOT touch
## the inventory or emit block_changed — the host already did both.
func _on_block_changed(action: String, position: Vector3, normal: Vector3, material: String) -> void:
	if is_authoritative:
		return   # host already applied this edit locally
	apply_block_change(action, position, normal, material)

## Client-side application of a host-authoritative block edit (see block_changed).
## Delegates to the shared _apply_edit helper so host and client derive the same
## tile and height from the same math.
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
	var tile := _world_to_tile(xz)
	return { "tile": tile, "current": _voxel_height_at_tile(tile), "xz": xz }

## Apply a block edit's terrain mutation (tile resolution + height/material
## change + chunk rebuild). Shared by the authoritative mine/place path and the
## client's apply_block_change so host and client derive the identical tile,
## height, and material from the same math. Returns
## { applied, tile, new_h, pos, material }. Dirty-chunk tracking is host-only
## and done by the callers (mine_block/place_block), never here.
func _apply_edit(action: String, position: Vector3, normal: Vector3, material: String) -> Dictionary:
	var r := _resolve_edit_tile(action, position, normal)
	var tile: Vector2i = r["tile"]
	var current: float = r["current"]
	var xz: Vector2 = r["xz"]
	if action == "mine":
		if current <= MIN_HEIGHT:
			return { "applied": false }
		var new_h := maxf(current - STEP_HEIGHT, MIN_HEIGHT)
		_edits[_tile_key(tile)] = new_h
		var mined_material := _pop_placed_material(tile)
		if mined_material == "":
			mined_material = material_for_biome(_biome_at(xz), xz)
		_rebuild_chunk_at_tile(tile)
		return { "applied": true, "tile": tile, "new_h": new_h, "pos": Vector3(position.x, new_h, position.z), "material": mined_material }
	elif action == "place":
		if current >= MAX_HEIGHT:
			return { "applied": false }
		var new_h := current + STEP_HEIGHT
		_edits[_tile_key(tile)] = new_h
		_push_placed_material(tile, material)
		_rebuild_chunk_at_tile(tile)
		return { "applied": true, "tile": tile, "new_h": new_h, "pos": Vector3(xz.x, new_h, xz.y), "material": material }
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
	var material := _placed_material_at(world_xz)
	if material != "":
		return _material_color(material)
	return _natural_color(world_xz)

## Colour a natural (unplaced) terrain column at world_xz, from its biome.
func _natural_color(world_xz: Vector2) -> Color:
	return _material_color(material_for_biome(_biome_at(world_xz), world_xz))

## Resolve a material key to its terrain colour (falling back to green for
## unknown keys).
func _material_color(material: String) -> Color:
	return MATERIAL_COLORS.get(material, FALLBACK_TERRAIN_COLOR)

## Topmost player-placed material at world_xz, or "" when the column surface is
## natural terrain (biome-derived colour).
func _placed_material_at(world_xz: Vector2) -> String:
	var key := _tile_key(_world_to_tile(world_xz))
	if not _edit_materials.has(key):
		return ""
	var stack: Array = _edit_materials[key]
	if stack.is_empty():
		return ""
	return str(stack[-1])

## Record a newly placed block's material on top of a column's stack.
func _push_placed_material(tile: Vector2i, material: String) -> void:
	var key := _tile_key(tile)
	if not _edit_materials.has(key):
		_edit_materials[key] = []
	_edit_materials[key].append(material)

## Remove and return the topmost placed material on a column, or "" if the
## column surface is natural terrain.
func _pop_placed_material(tile: Vector2i) -> String:
	var key := _tile_key(tile)
	if not _edit_materials.has(key):
		return ""
	var stack: Array = _edit_materials[key]
	if stack.is_empty():
		_edit_materials.erase(key)
		return ""
	var material := str(stack.pop_back())
	if stack.is_empty():
		_edit_materials.erase(key)
	return material

## Vertical colour layers for a column, bottom → top. Each entry is
## { "bottom": float, "top": float, "color": Color }. The natural terrain is a
## single bottom slab tinted by biome colour; each player-placed block above it
## is its own slab tinted by its material (falling back to biome colour when a
## placed height has no recorded material).
func _column_layers(chunk_pos: Vector2i, heightmap: Array, tx: int, tz: int) -> Array:
	var gx := chunk_pos.x * CHUNK_SIZE + tx
	var gz := chunk_pos.y * CHUNK_SIZE + tz
	var key := _tile_key(Vector2i(gx, gz))
	var world_xz := Vector2(gx * TILE_SIZE + TILE_SIZE * 0.5, gz * TILE_SIZE + TILE_SIZE * 0.5)
	var natural_color := _natural_color(world_xz)
	var h := _column_height(heightmap, chunk_pos, tx, tz)

	var stack: Array = _edit_materials.get(key, [])
	# Natural terrain fills everything below the player-placed blocks, so its top
	# is the column height minus the placed blocks on top. Using the original
	# noise height here would mislabel a block placed after mining the natural
	# surface back down as "natural".
	var natural_top := maxf(h - float(stack.size()) * STEP_HEIGHT, 0.0)

	var layers: Array = []
	if natural_top > 0.0:
		layers.append({ "bottom": 0.0, "top": natural_top, "color": natural_color })

	var placed_bottom := natural_top
	for k in range(stack.size()):
		var placed_top := placed_bottom + STEP_HEIGHT
		var col := natural_color
		var mat := str(stack[k])
		if mat != "":
			col = _material_color(mat)
		layers.append({ "bottom": placed_bottom, "top": placed_top, "color": col })
		placed_bottom = placed_top
	return layers

func _voxel_height_at_tile(tile: Vector2i) -> float:
	var key := _tile_key(tile)
	if _edits.has(key):
		return float(_edits[key])
	var chunk := _tile_to_chunk(tile)
	var ckey := _chunk_key(chunk)
	if _heightmaps.has(ckey):
		var hm: Array = _heightmaps[ckey]
		var lx := tile.x - chunk.x * CHUNK_SIZE
		var lz := tile.y - chunk.y * CHUNK_SIZE
		return _voxel_height(hm[lz * CHUNK_SIZE + lx])
	if terrain_slice != null and terrain_slice.has_method("get_height_at"):
		return _voxel_height(terrain_slice.get_height_at(Vector2(tile.x * TILE_SIZE, tile.y * TILE_SIZE)))
	return 0.0

func _rebuild_chunk_at_tile(tile: Vector2i) -> void:
	var chunk := _tile_to_chunk(tile)
	var ckey := _chunk_key(chunk)
	if _heightmaps.has(ckey):
		build_chunk(chunk, _heightmaps[ckey])
