extends RefCounted
## Shared state and bookkeeping of `SpatialHash` (float metres) and `ExactSpatialHash` (exact `{chunk, local}`):
## the id → cell and id → position maps, the cell buckets, the probe counter and the removal. The subclasses
## add their own `insert`, `update` and `query_radius`, which differ in how a position is bucketed and measured.

## id → cell coordinate (Vector2i), for O(1) removal / re-hash.
var _id_to_cell: Dictionary = {}
## id → position (a Vector3 in the float hash, a `{chunk, local}` dict in the exact one).
var _positions: Dictionary = {}
## cell coordinate (Vector2i) → { id: value } (an id set in the float hash, id → local in the exact one).
var _cells: Dictionary = {}
## Cells probed by `query_radius` since construction (the suite pins the query cost).
var probes := 0

## Number of live entities in the hash.
func size() -> int:
	return _positions.size()

func has(id) -> bool:
	return _positions.has(id)

## Drop an entity (no-op if unknown).
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
