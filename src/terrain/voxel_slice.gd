extends Node
## Voxel slice — builds a visible, walkable terrain mesh from chunk heightmaps.
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : chunk_ready(chunk_pos, heightmap)
##   OUT : (none — renders directly into the scene tree)
##
## Public API:
##   build_chunk(chunk_pos: Vector2i, heightmap: Array) -> void
##
## Each chunk is rendered as a closed, hole-free shell (top face + a wall on
## each side where a lower neighbour or the chunk edge leaves it exposed).
## Collision uses one solid box per voxel column, which is far more reliable
## with CharacterBody3D than a single concave trimesh.

const CHUNK_SIZE  := 32        # tiles per side — must match TerrainSlice.CHUNK_SIZE
const TILE_SIZE   := 1.0       # world units per tile (XZ)
const STEP_HEIGHT := 0.5       # world units per quantised height step

## Active chunk containers keyed by "x,y" string.
var _chunks: Dictionary = {}

func _ready() -> void:
	GameBus.chunk_ready.connect(_on_chunk_ready)

## Build (or rebuild) the mesh and collision for one chunk.
func build_chunk(chunk_pos: Vector2i, heightmap: Array) -> void:
	var key := "%d,%d" % [chunk_pos.x, chunk_pos.y]

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
			var idx := tz * CHUNK_SIZE + tx
			var h := _voxel_height(heightmap[idx])
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
			var hn := _neighbour_height(heightmap, tx, tz - 1)
			if hn < h:
				_add_face(st,
					Vector3(bx,              h,  bz),
					Vector3(bx + TILE_SIZE, h,  bz),
					Vector3(bx + TILE_SIZE, hn, bz),
					Vector3(bx,              hn, bz),
					Vector3(0, 0, -1))

			# South wall.
			var hs := _neighbour_height(heightmap, tx, tz + 1)
			if hs < h:
				_add_face(st,
					Vector3(bx + TILE_SIZE, h,  bz + TILE_SIZE),
					Vector3(bx,              h,  bz + TILE_SIZE),
					Vector3(bx,              hs, bz + TILE_SIZE),
					Vector3(bx + TILE_SIZE, hs, bz + TILE_SIZE),
					Vector3(0, 0, 1))

			# West wall.
			var hw := _neighbour_height(heightmap, tx - 1, tz)
			if hw < h:
				_add_face(st,
					Vector3(bx, h,  bz + TILE_SIZE),
					Vector3(bx, h,  bz),
					Vector3(bx, hw, bz),
					Vector3(bx, hw, bz + TILE_SIZE),
					Vector3(-1, 0, 0))

			# East wall.
			var he := _neighbour_height(heightmap, tx + 1, tz)
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
	for tz in range(CHUNK_SIZE):
		for tx in range(CHUNK_SIZE):
			var idx := tz * CHUNK_SIZE + tx
			var h := _voxel_height(heightmap[idx])
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
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(64.0, 1.0, 64.0)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(origin.x + 16.0, -0.5, origin.z + 16.0)
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)

	print("VoxelSlice: built chunk %s  tiles=%d" % [key, CHUNK_SIZE * CHUNK_SIZE])

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _voxel_height(raw_height: float) -> float:
	return floor(raw_height / STEP_HEIGHT) * STEP_HEIGHT

## Height of the tile at (tx, tz), or 0.0 for out-of-chunk (chunk edge).
func _neighbour_height(heightmap: Array, tx: int, tz: int) -> float:
	if tx < 0 or tx >= CHUNK_SIZE or tz < 0 or tz >= CHUNK_SIZE:
		return 0.0
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
