extends "res://src/core/spatial_hash_base.gd"
## Phase 195 — `SpatialHash` over exact `{chunk, local}` positions (#464).
##
## The float hash buckets world metres, which a float32 holds only to a metre 10,000 km out, so a
## creature far from the origin was hashed and range-checked on that grid. Here a cell is an exact
## integer: the chunk index times the cells per chunk, plus the cell inside the chunk from the small
## `local`. A query measures from a snapshot taken at insert/update: each candidate's `local` re-expressed
## in its cell's chunk, plus the integer chunk step to the query's chunk (the same result as
## `WorldPos.offset_between`, with one lookup per candidate), so a query is as exact at chunk 312,500 as at the origin.
## Positions are copied on the way in; `position_of` returns the hash's own copy (read, never edit).
##
## Cells are XZ squares of `CELL_METERS`, which divides a chunk. X is not wrapped at the seam: the
## records it holds are in one frame (the slice's), as the float hash's were.

const WorldPos := preload("res://src/terrain/world_pos.gd")

const CELL_METERS := 8.0
const CELLS_PER_CHUNK := int(WorldPos.CHUNK_METERS / CELL_METERS)

## The exact position stored for `id` (empty when unknown). The hash's own record: read, never edit.
func position_of(id) -> Dictionary:
	return _positions.get(id, {})

## Add an entity at the exact `pos`. Replaces any existing entry under the same id.
func insert(id, pos: Dictionary) -> void:
	remove(id)
	var c := cell_of(pos)
	_id_to_cell[id] = c
	_positions[id] = pos.duplicate()   # a copy: the cell-local snapshot below must not drift if the caller edits `pos`
	if not _cells.has(c):
		_cells[c] = {}
	_cells[c][id] = _local_in_cell(pos, c)

## Move an entity, re-hashing only when its cell changed.
func update(id, pos: Dictionary) -> void:
	if not _positions.has(id):
		insert(id, pos)
		return
	var c := cell_of(pos)
	if c == _id_to_cell[id]:
		_positions[id] = pos.duplicate()
		_cells[c][id] = _local_in_cell(pos, c)
		return
	insert(id, pos)

## Every id within `radius` metres (3D) of the exact `pos`. The probed cells are the ones the query's XZ
## square overlaps (as in the float hash: one to four for a body-sized radius, not a fixed 3×3 block), and
## the distance is the exact offset (the integer chunk step of the candidate's cell, folded once per cell
## with the query's local, plus the candidate's local): this runs once per creature per frame in
## `separate_bodies`, so a candidate costs one lookup and one add, as in the float hash.
func query_radius(pos: Dictionary, radius: float) -> Array:
	var out: Array = []
	var r2 := radius * radius
	var chunk: Vector2i = pos["chunk"]
	var local: Vector3 = pos["local"]
	var base_x := chunk.x * CELLS_PER_CHUNK
	var base_z := chunk.y * CELLS_PER_CHUNK
	var min_x := base_x + floori((local.x - radius) / CELL_METERS)
	var max_x := base_x + floori((local.x + radius) / CELL_METERS)
	var min_z := base_z + floori((local.z - radius) / CELL_METERS)
	var max_z := base_z + floori((local.z + radius) / CELL_METERS)
	for cx in range(min_x, max_x + 1):
		# The cell's chunk step from the query's, folded with the query's own local into one shift.
		var shift_x := float(floori(float(cx) / CELLS_PER_CHUNK) - chunk.x) * WorldPos.CHUNK_METERS - local.x
		for cz in range(min_z, max_z + 1):
			probes += 1
			var ids: Variant = _cells.get(Vector2i(cx, cz))
			if ids == null:
				continue
			var shift := Vector3(shift_x, -local.y,
				float(floori(float(cz) / CELLS_PER_CHUNK) - chunk.y) * WorldPos.CHUNK_METERS - local.z)
			for id in ids:
				if ((ids[id] as Vector3) + shift).length_squared() <= r2:
					out.append(id)
	return out

## `pos`'s local re-expressed in the chunk holding cell `c` (the same as `local` for a normalised position;
## a record whose local runs past its chunk's edge is still placed exactly).
static func _local_in_cell(pos: Dictionary, c: Vector2i) -> Vector3:
	var chunk: Vector2i = pos["chunk"]
	var local: Vector3 = pos["local"]
	var dx := chunk.x - floori(float(c.x) / CELLS_PER_CHUNK)
	var dz := chunk.y - floori(float(c.y) / CELLS_PER_CHUNK)
	if dx == 0 and dz == 0:
		return local
	return Vector3(local.x + float(dx) * WorldPos.CHUNK_METERS, local.y, local.z + float(dz) * WorldPos.CHUNK_METERS)

## The exact cell of a `{chunk, local}` position: integer chunk arithmetic, no world metre in between.
static func cell_of(pos: Dictionary) -> Vector2i:
	var chunk: Vector2i = pos["chunk"]
	var local: Vector3 = pos["local"]
	return Vector2i(chunk.x * CELLS_PER_CHUNK + floori(local.x / CELL_METERS),
		chunk.y * CELLS_PER_CHUNK + floori(local.z / CELL_METERS))
