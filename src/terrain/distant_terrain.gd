extends Node3D
## Phase 51 — distant terrain: a coarse heightmap ring outside the voxel window, so coastlines and
## mountains are visible from afar. RENDER-ONLY: the mesh carries no collision body (the voxel
## window is the only ground a body can touch), and it leaves a hole where the voxel window is.
##
## The ring covers `RING_FACTOR` times the voxel window's half-extent around a centre, sampled from
## `WorldShape` (the large-scale shape: no detail noise, no edits) on a GRID × GRID lattice and
## re-centred whenever the player moves a whole cell.

const WorldShape := preload("res://src/terrain/world_shape.gd")
const CHUNK_METERS := 32.0   # TerrainSlice.CHUNK_SIZE * TILE_SIZE
const RING_FACTOR := 10      ## the ring reaches this many times the voxel window's extent
const GRID := 64             ## cells per side of the ring's lattice
const LAND_COLOR := Color(0.36, 0.5, 0.28)
const ROCK_COLOR := Color(0.5, 0.48, 0.45)
const SNOW_COLOR := Color(0.95, 0.97, 0.98)
const SEA_FLOOR_COLOR := Color(0.2, 0.32, 0.5)

var world_seed: int = 0
var circumference_m: float = 40000.0 * 1000.0
## Half-extent of the voxel window in metres, and the ring's own.
var window_half_m: float = 0.0
var ring_half_m: float = 0.0
var _cell_origin := Vector2i(-999999, -999999)
var _built_key := ""   # seed, radius and circumference the current mesh was built for
var _mesh_inst: MeshInstance3D = null

## Phase 63: the scene-origin offset a client rebase has applied (see `shift_scene`).
var _scene_offset: Vector3 = Vector3.ZERO

## Shift every ring node by `shift`; its world position is unchanged.
func shift_scene(shift: Vector3) -> void:
	_scene_offset += shift
	if _mesh_inst != null:
		_mesh_inst.position += shift

func scene_offset() -> Vector3:
	return _scene_offset

## Ring half-extent in metres for a voxel window of `radius_chunks` (Chebyshev radius).
static func ring_half_extent(radius_chunks: int) -> float:
	return float(RING_FACTOR) * (float(radius_chunks) + 0.5) * CHUNK_METERS

## Colour of the distant ground at altitude `alt` above sea level.
static func color_for(alt: float) -> Color:
	if alt < 0.0:
		return SEA_FLOOR_COLOR
	if alt > 300.0:
		return SNOW_COLOR
	if alt > 150.0:
		return ROCK_COLOR
	return LAND_COLOR

## Build (or re-centre) the ring around world XZ `center` for a voxel window of `radius_chunks`.
## Returns true when the mesh was rebuilt (the centre moved a whole cell, or first call).
func rebuild(center: Vector2, radius_chunks: int) -> bool:
	window_half_m = (float(radius_chunks) + 0.5) * CHUNK_METERS
	ring_half_m = ring_half_extent(radius_chunks)
	var cell := ring_half_m * 2.0 / float(GRID)
	var origin := Vector2i(floori(center.x / cell), floori(center.y / cell))
	var key := "%d:%d:%f" % [world_seed, radius_chunks, circumference_m]
	if origin == _cell_origin and _mesh_inst != null and key == _built_key:
		return false
	_cell_origin = origin
	_built_key = key
	var snapped := Vector2(float(origin.x) * cell, float(origin.y) * cell)
	if _mesh_inst != null:
		_mesh_inst.queue_free()
	var mesh := build_mesh(world_seed, circumference_m, snapped, ring_half_m, window_half_m, center)
	_mesh_inst = MeshInstance3D.new()
	_mesh_inst.name = "DistantRing"
	_mesh_inst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh_inst.material_override = mat
	_mesh_inst.position = _scene_offset
	add_child(_mesh_inst)
	return true

## The ring's mesh: GRID × GRID cells centred on `ring_center` spanning ±`half_m`, skipping any
## cell wholly inside the voxel window (`window_half_m` around `window_center`). The hole is
## shrunk by one ring cell plus one chunk, so the ring still covers the ground the window has left
## behind between rebuilds (the player moves up to a cell, the window snaps to chunks). Heights are the
## shape's, floored at the sea level so the ocean reads as a flat sheet.
static func build_mesh(seed_v: int, w: float, ring_center: Vector2, half_m: float, window_half_m: float, window_center: Vector2) -> ArrayMesh:
	var cell := half_m * 2.0 / float(GRID)
	var sea := WorldShape.sea_level()
	var heights := PackedFloat32Array()
	heights.resize((GRID + 1) * (GRID + 1))
	for j in GRID + 1:
		for i in GRID + 1:
			var x := ring_center.x - half_m + float(i) * cell
			var z := ring_center.y - half_m + float(j) * cell
			heights[j * (GRID + 1) + i] = WorldShape.height(seed_v, x, z, w)
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for j in GRID:
		for i in GRID:
			var x0 := ring_center.x - half_m + float(i) * cell
			var z0 := ring_center.y - half_m + float(j) * cell
			var cx := x0 + cell * 0.5
			var cz := z0 + cell * 0.5
			var hole_half := window_half_m - cell - CHUNK_METERS
			if absf(cx - window_center.x) + cell * 0.5 <= hole_half and absf(cz - window_center.y) + cell * 0.5 <= hole_half:
				continue   # wholly inside the voxel window: the voxel chunks draw it
			var base := vertices.size()
			for c in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var h := heights[(j + c.y) * (GRID + 1) + i + c.x]
				vertices.append(Vector3(x0 + float(c.x) * cell, maxf(h, sea) - 1.0, z0 + float(c.y) * cell))
				colors.append(color_for(h - sea))
			var n := (vertices[base + 2] - vertices[base]).cross(vertices[base + 1] - vertices[base]).normalized()
			if n.y < 0.0:
				n = -n
			for _k in 4:
				normals.append(n)
			indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## Number of collision bodies in this ring's subtree — always 0 (asserted by the suite).
func collision_body_count() -> int:
	return _count_collision(self)

static func _count_collision(n: Node) -> int:
	var c := 1 if n is CollisionObject3D or n is CollisionShape3D else 0
	for ch in n.get_children():
		c += _count_collision(ch)
	return c
