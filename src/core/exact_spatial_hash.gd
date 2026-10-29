extends RefCounted
## Phase 195 — `SpatialHash` over exact `{chunk, local}` positions (#464).
##
## The float hash buckets world metres, which a float32 holds only to a metre 10,000 km out, so a
## creature far from the origin was hashed and range-checked on that grid. Here a cell is an exact
## integer: the chunk index times the cells per chunk, plus the cell inside the chunk from the small
## `local`. Distances are `WorldPos.offset_between` (an integer chunk difference plus a small float
## remainder), so a query is as exact at chunk 312,500 as at the origin.
##
## Cells are XZ squares of `CELL_METERS`, which divides a chunk. X is not wrapped at the seam: the
## records it holds are in one frame (the slice's), as the float hash's were.

const WorldPos := preload("res://src/terrain/world_pos.gd")

const CELL_METERS := 8.0
const CELLS_PER_CHUNK := int(WorldPos.CHUNK_METERS / CELL_METERS)

## id → cell (Vector2i), id → exact position, cell → { id: true }.
var _id_to_cell: Dictionary = {}
var _positions: Dictionary = {}
var _cells: Dictionary = {}
## Cells probed by `query_radius` since construction (a test counter, as in `SpatialHash`).
var probes := 0

func size() -> int:
	return _positions.size()

func has(id) -> bool:
	return _positions.has(id)

## The exact position stored for `id` (empty when unknown). The hash's own record: read, never edit.
func position_of(id) -> Dictionary:
	return _positions.get(id, {})

## Add an entity at the exact `pos`. Replaces any existing entry under the same id.
func insert(id, pos: Dictionary) -> void:
	remove(id)
	var c := cell_of(pos)
	_id_to_cell[id] = c
	_positions[id] = pos
	if not _cells.has(c):
		_cells[c] = {}
	_cells[c][id] = true

func remove(id) -> void:
	if not _positions.has(id):
		return
	var c: Vector2i = _id_to_cell[id]
	_positions.erase(id)
	_id_to_cell.erase(id)
	if _cells.has(c):
		_cells[c].erase(id)
		if _cells[c].is_empty():
			_cells.erase(c)

## Move an entity, re-hashing only when its cell changed.
func update(id, pos: Dictionary) -> void:
	if not _positions.has(id):
		insert(id, pos)
		return
	var c := cell_of(pos)
	if c == _id_to_cell[id]:
		_positions[id] = pos
		return
	insert(id, pos)

## Every id within `radius` metres (3D) of the exact `pos`.
func query_radius(pos: Dictionary, radius: float) -> Array:
	var out: Array = []
	var r2 := radius * radius
	var center := cell_of(pos)
	var reach := ceili(radius / CELL_METERS)
	for cx in range(center.x - reach, center.x + reach + 1):
		for cz in range(center.y - reach, center.y + reach + 1):
			probes += 1
			var c := Vector2i(cx, cz)
			if not _cells.has(c):
				continue
			for id in _cells[c]:
				if WorldPos.offset_between(pos, _positions[id]).length_squared() <= r2:
					out.append(id)
	return out

## The exact cell of a `{chunk, local}` position: integer chunk arithmetic, no world metre in between.
static func cell_of(pos: Dictionary) -> Vector2i:
	var chunk: Vector2i = pos["chunk"]
	var local: Vector3 = pos["local"]
	return Vector2i(chunk.x * CELLS_PER_CHUNK + floori(local.x / CELL_METERS),
		chunk.y * CELLS_PER_CHUNK + floori(local.z / CELL_METERS))
