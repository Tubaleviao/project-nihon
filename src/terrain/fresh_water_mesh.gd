extends RefCounted
## Phase 217 — the render mesh of a chunk's lake and river surfaces.
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")

## Phase 217 — the chunk's lake and river surfaces: `surfaces` (`Hydrology.surfaces_for_chunk`) holds each
## tile's water level or NAN. Runs of tiles in a row at one level merge into one quad. Coordinates as
## `VoxelSlice.water_mesh_for`. Render-only, like the sea. Null when the chunk holds no fresh water.
static func mesh_for(chunk_pos: Vector2i, surfaces: PackedFloat64Array, local: bool = false) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var chunk_x := 0.0 if local else float(chunk_pos.x * TerrainSlice.CHUNK_SIZE)
	var chunk_z := 0.0 if local else float(chunk_pos.y * TerrainSlice.CHUNK_SIZE)
	for tz in range(TerrainSlice.CHUNK_SIZE):
		var start := -1
		var level := 0.0
		for tx in range(TerrainSlice.CHUNK_SIZE + 1):
			var lv := NAN if tx >= TerrainSlice.CHUNK_SIZE else surfaces[tz * TerrainSlice.CHUNK_SIZE + tx]
			var wet := not is_nan(lv)
			if start >= 0 and (not wet or absf(lv - level) > 0.001):
				var z0 := (chunk_z + float(tz)) * TerrainSlice.TILE_SIZE
				var x0 := (chunk_x + float(start)) * TerrainSlice.TILE_SIZE
				var x1 := (chunk_x + float(tx)) * TerrainSlice.TILE_SIZE
				var base := vertices.size()
				vertices.append_array([Vector3(x0, level, z0), Vector3(x1, level, z0), Vector3(x1, level, z0 + TerrainSlice.TILE_SIZE), Vector3(x0, level, z0 + TerrainSlice.TILE_SIZE)])
				for _i in 4:
					normals.append(Vector3.UP)
				indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
				start = -1
			if wet and start < 0:
				start = tx
				level = lv
	if vertices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
