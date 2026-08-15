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
##   get_edits() / apply_edits(edits)  -> Dictionary / void
##   set_place_material / get_place_material / cycle_place_material
##   material_for_biome(biome, world_xz) -> String
##
## Terrain is a heightfield: each (x, z) column has a single quantised height.
## Mining lowers a column by one STEP; building raises it by one STEP. Edits are
## stored as absolute quantised heights keyed by global tile coordinate, so they
## survive chunk rebuilds and save/load.

const CHUNK_SIZE  := 32        # tiles per side — must match TerrainSlice.CHUNK_SIZE
const TILE_SIZE   := 1.0       # world units per tile (XZ)
const STEP_HEIGHT := 0.5       # world units per quantised height step
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
	"Twilight":           ["Duskfiber", "Lumenfite"],
	"VoidRift":           ["Voidite", "Aethermite"],
}

## Active chunk containers keyed by "x,y" string.
var _chunks: Dictionary = {}
## Base heightmaps keyed by "x,y" string (the unedited noise terrain).
var _heightmaps: Dictionary = {}
## Voxel edits keyed by "gx,gz" string → absolute quantised height.
var _edits: Dictionary = {}

## Set by game_root: terrain (biome + base height) and inventory (material flow).
var terrain_slice: Node = null
var inventory_slice: Node = null

## Material used by place_block; cycled via cycle_place_material().
var _place_material: String = "Ferrite"

func _ready() -> void:
	GameBus.chunk_ready.connect(_on_chunk_ready)
	GameBus.block_mine_requested.connect(_on_mine_requested)
	GameBus.block_place_requested.connect(_on_place_requested)
	GameBus.block_cycle_material_requested.connect(_on_cycle_requested)

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
			var bx := origin.x + tx * TILE_SIZE
			var bz := origin.z + tz * TILE_SIZE

			# Top face.
			_add_face(st,
				Vector3(bx,              h, bz),
				Vector3(bx,              h, bz + TILE_SIZE),
				Vector3(bx + TILE_SIZE, h, bz + TILE_SIZE),
				Vector3(bx + TILE_SIZE, h, bz),
				Vector3.UP)

			# North wall.
			var hn := _neighbour_height(heightmap, chunk_pos, tx, tz - 1)
			if hn < h:
				_add_face(st,
					Vector3(bx,              h,  bz),
					Vector3(bx + TILE_SIZE, h,  bz),
					Vector3(bx + TILE_SIZE, hn, bz),
					Vector3(bx,              hn, bz),
					Vector3(0, 0, -1))

			# South wall.
			var hs := _neighbour_height(heightmap, chunk_pos, tx, tz + 1)
			if hs < h:
				_add_face(st,
					Vector3(bx + TILE_SIZE, h,  bz + TILE_SIZE),
					Vector3(bx,              h,  bz + TILE_SIZE),
					Vector3(bx,              hs, bz + TILE_SIZE),
					Vector3(bx + TILE_SIZE, hs, bz + TILE_SIZE),
					Vector3(0, 0, 1))

			# West wall.
			var hw := _neighbour_height(heightmap, chunk_pos, tx - 1, tz)
			if hw < h:
				_add_face(st,
					Vector3(bx, h,  bz + TILE_SIZE),
					Vector3(bx, h,  bz),
					Vector3(bx, hw, bz),
					Vector3(bx, hw, bz + TILE_SIZE),
					Vector3(-1, 0, 0))

			# East wall.
			var he := _neighbour_height(heightmap, chunk_pos, tx + 1, tz)
			if he < h:
				_add_face(st,
					Vector3(bx + TILE_SIZE, h,  bz),
					Vector3(bx + TILE_SIZE, h,  bz + TILE_SIZE),
					Vector3(bx + TILE_SIZE, he, bz + TILE_SIZE),
					Vector3(bx + TILE_SIZE, he, bz),
					Vector3(1, 0, 0))

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = st.commit()

	# Simple grass-like material (works without a texture asset).
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.6, 0.28)
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

	# --- Safety floor so the player can never fall out of the world ---
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = TERRAIN_COLLISION_LAYER
	floor_body.collision_mask = 0
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(64.0, 1.0, 64.0)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(origin.x + 16.0, -0.5, origin.z + 16.0)
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)

	print("VoxelSlice: built chunk %s  tiles=%d" % [key, CHUNK_SIZE * CHUNK_SIZE])

# ---------------------------------------------------------------------------
# Edit API — mining and building
# ---------------------------------------------------------------------------

## Remove one voxel from the column under world_pos, yielding that biome's
## material into the inventory. Returns { success, material, quantity, position }.
## normal disambiguates side-face hits: the ray lands on the boundary between
## two columns, so we step back along the normal into the block being mined.
func mine_block(world_pos: Vector3, normal: Vector3 = Vector3.UP) -> Dictionary:
	var xz := Vector2(world_pos.x, world_pos.z)
	if normal.y <= 0.5:
		xz -= Vector2(normal.x, normal.z) * TILE_SIZE * 0.5
	var tile := _world_to_tile(xz)
	var current := _voxel_height_at_tile(tile)
	if current <= MIN_HEIGHT:
		return { "success": false, "material": "", "quantity": 0, "position": world_pos }

	var new_h := maxf(current - STEP_HEIGHT, MIN_HEIGHT)
	_edits[_tile_key(tile)] = new_h
	_rebuild_chunk_at_tile(tile)

	var material := material_for_biome(_biome_at(xz), xz)
	if inventory_slice != null and inventory_slice.has_method("add_item"):
		inventory_slice.add_item(material, 1)

	var pos := Vector3(world_pos.x, new_h, world_pos.z)
	GameBus.block_mined.emit(material, 1, pos)
	print("VoxelSlice: mined %s at (%d,%d) → height %.1f" % [material, tile.x, tile.y, new_h])
	return { "success": true, "material": material, "quantity": 1, "position": pos }

## Place one voxel of the currently selected material on the column adjacent to
## the hit face (in the normal direction). Consumes the material from inventory.
## Returns true on success; false if no material or the build cap is reached.
func place_block(world_pos: Vector3, normal: Vector3) -> bool:
	var material := _place_material

	# Consume first so a blocked placement never leaves terrain half-edited.
	if inventory_slice != null and inventory_slice.has_method("drop_item"):
		if not inventory_slice.drop_item(material, 1):
			return false

	var target_xz := Vector2(world_pos.x, world_pos.z)
	if normal.y <= 0.5:
		target_xz += Vector2(normal.x, normal.z) * TILE_SIZE * 0.5

	var tile := _world_to_tile(target_xz)
	var current := _voxel_height_at_tile(tile)
	if current >= MAX_HEIGHT:
		# Refund the material — placement is blocked at the build cap.
		if inventory_slice != null and inventory_slice.has_method("add_item"):
			inventory_slice.add_item(material, 1)
		return false

	var new_h := current + STEP_HEIGHT
	_edits[_tile_key(tile)] = new_h
	_rebuild_chunk_at_tile(tile)

	var pos := Vector3(target_xz.x, new_h, target_xz.y)
	GameBus.block_placed.emit(material, pos)
	print("VoxelSlice: placed %s at (%d,%d) → height %.1f" % [material, tile.x, tile.y, new_h])
	return true

## Current (edited) voxel height at a world XZ position, quantised to STEP.
func get_voxel_height_at(world_pos: Vector2) -> float:
	return _voxel_height_at_tile(_world_to_tile(world_pos))

## Dump voxel edits for persistence: { "gx,gz": height }.
func get_edits() -> Dictionary:
	return _edits.duplicate()

## Restore voxel edits from a saved world snapshot and rebuild affected chunks.
func apply_edits(edits: Dictionary) -> void:
	_edits.clear()
	for key in edits:
		_edits[key] = float(edits[key])
	for ckey in _heightmaps:
		var parts: PackedStringArray = str(ckey).split(",")
		build_chunk(Vector2i(int(parts[0]), int(parts[1])), _heightmaps[ckey])

func set_place_material(material: String) -> void:
	_place_material = material

func get_place_material() -> String:
	return _place_material

## Advance to the next buildable material (sorted GameData.MATERIALS keys).
func cycle_place_material() -> String:
	var keys: Array = GameData.MATERIALS.keys()
	keys.sort()
	if not keys.is_empty():
		var idx: int = keys.find(_place_material)
		idx = (idx + 1) % keys.size()
		_place_material = str(keys[idx])
	GameBus.block_place_material_changed.emit(_place_material)
	return _place_material

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
## counter-clockwise order seen from the normal side.
func _add_face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	st.set_normal(normal)
	st.set_uv(Vector2(0, 0)); st.add_vertex(a)
	st.set_uv(Vector2(1, 0)); st.add_vertex(b)
	st.set_uv(Vector2(1, 1)); st.add_vertex(c)
	st.set_uv(Vector2(0, 0)); st.add_vertex(a)
	st.set_uv(Vector2(1, 1)); st.add_vertex(c)
	st.set_uv(Vector2(0, 1)); st.add_vertex(d)

func _on_chunk_ready(chunk_pos: Vector2i, heightmap: Array) -> void:
	build_chunk(chunk_pos, heightmap)

func _on_mine_requested(position: Vector3, normal: Vector3) -> void:
	mine_block(position, normal)

func _on_place_requested(position: Vector3, normal: Vector3) -> void:
	place_block(position, normal)

func _on_cycle_requested() -> void:
	cycle_place_material()

# --- Coordinate helpers ---

func _world_to_tile(xz: Vector2) -> Vector2i:
	return Vector2i(floori(xz.x / TILE_SIZE), floori(xz.y / TILE_SIZE))

func _tile_to_chunk(tile: Vector2i) -> Vector2i:
	return Vector2i(floori(float(tile.x) / float(CHUNK_SIZE)), floori(float(tile.y) / float(CHUNK_SIZE)))

func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]

func _chunk_key(chunk_pos: Vector2i) -> String:
	return "%d,%d" % [chunk_pos.x, chunk_pos.y]

func _biome_at(xz: Vector2) -> String:
	if terrain_slice != null and terrain_slice.has_method("get_biome_at"):
		return terrain_slice.get_biome_at(xz)
	return "TemperateForest"

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
