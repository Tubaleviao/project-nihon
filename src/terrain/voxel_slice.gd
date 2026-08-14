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
## Each chunk is materialised as a GridMap-style MeshInstance3D with a matching
## StaticBody3D collision mesh so CharacterBody3D can walk on it.

const CHUNK_SIZE  := 32        # tiles per side — must match TerrainSlice.CHUNK_SIZE
const TILE_SIZE   := 1.0       # world units per tile (XZ)
const STEP_HEIGHT := 1.0       # world units per quantised height step

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

	var st  := SurfaceTool.new()
	var col := ConcavePolygonShape3D.new()
	var col_faces: PackedVector3Array

	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for tz in range(CHUNK_SIZE):
		for tx in range(CHUNK_SIZE):
			var idx := tz * CHUNK_SIZE + tx

			# Heightmap stores continuous height; quantise to voxel steps.
			var h := _voxel_height(heightmap[idx])

			var bx := origin.x + tx * TILE_SIZE
			var bz := origin.z + tz * TILE_SIZE

			# Top face of the voxel column.
			var v00 := Vector3(bx,           h, bz)
			var v10 := Vector3(bx + TILE_SIZE, h, bz)
			var v01 := Vector3(bx,           h, bz + TILE_SIZE)
			var v11 := Vector3(bx + TILE_SIZE, h, bz + TILE_SIZE)

			var uv00 := Vector2(float(tx) / CHUNK_SIZE,       float(tz) / CHUNK_SIZE)
			var uv10 := Vector2(float(tx + 1) / CHUNK_SIZE,   float(tz) / CHUNK_SIZE)
			var uv01 := Vector2(float(tx) / CHUNK_SIZE,       float(tz + 1) / CHUNK_SIZE)
			var uv11 := Vector2(float(tx + 1) / CHUNK_SIZE,   float(tz + 1) / CHUNK_SIZE)

			# Normal always up for the top face.
			st.set_normal(Vector3.UP)

			st.set_uv(uv00); st.add_vertex(v00)
			st.set_uv(uv10); st.add_vertex(v10)
			st.set_uv(uv11); st.add_vertex(v11)

			st.set_uv(uv00); st.add_vertex(v00)
			st.set_uv(uv11); st.add_vertex(v11)
			st.set_uv(uv01); st.add_vertex(v01)

			# Add both triangles to the collision face list.
			col_faces.append(v00); col_faces.append(v10); col_faces.append(v11)
			col_faces.append(v00); col_faces.append(v11); col_faces.append(v01)

			# South side wall (if neighbour is lower, or at chunk edge).
			if tz < CHUNK_SIZE - 1:
				var h_next := _voxel_height(heightmap[(tz + 1) * CHUNK_SIZE + tx])
				if h_next < h:
					var sw0 := Vector3(bx,           h_next, bz + TILE_SIZE)
					var sw1 := Vector3(bx + TILE_SIZE, h_next, bz + TILE_SIZE)
					st.set_normal(Vector3(0, 0, 1))
					st.set_uv(Vector2(0, 0)); st.add_vertex(v01)
					st.set_uv(Vector2(1, 0)); st.add_vertex(v11)
					st.set_uv(Vector2(1, 1)); st.add_vertex(sw1)

					st.set_uv(Vector2(0, 0)); st.add_vertex(v01)
					st.set_uv(Vector2(1, 1)); st.add_vertex(sw1)
					st.set_uv(Vector2(0, 1)); st.add_vertex(sw0)

					col_faces.append(v01);  col_faces.append(v11);  col_faces.append(sw1)
					col_faces.append(v01);  col_faces.append(sw1);  col_faces.append(sw0)

	st.generate_normals()
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = st.commit()

	# Simple grass-like vertex colour material (works without a texture asset).
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.6, 0.28)
	mat.roughness    = 0.9
	mesh_inst.material_override = mat

	root.add_child(mesh_inst)

	# Collision body.
	col.set_faces(col_faces)
	var static_body  := StaticBody3D.new()
	var col_shape    := CollisionShape3D.new()
	col_shape.shape  = col
	static_body.add_child(col_shape)
	root.add_child(static_body)

	print("VoxelSlice: built chunk %s  tiles=%d" % [key, CHUNK_SIZE * CHUNK_SIZE])

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _voxel_height(raw_height: float) -> float:
	return floor(raw_height / STEP_HEIGHT) * STEP_HEIGHT

func _on_chunk_ready(chunk_pos: Vector2i, heightmap: Array) -> void:
	build_chunk(chunk_pos, heightmap)
