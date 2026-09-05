extends RefCounted
## SpatialHash — O(1) spatial queries over a population of positioned entities.
##
## Entities are keyed by id and bucketed into a uniform grid of `cell_size`
## squares (on the XZ plane). Radius and nearest queries scan only the cells
## that can possibly contain a match, so their cost is proportional to the
## query's footprint (~cells touched), not the total population — the structural
## prerequisite for interest management (Phase 29) and later sharding.
##
## The world is a heightfield, so cells are 2D (XZ); the Y coordinate is carried
## in each entity's position for exact distance checks but does not affect the
## bucketing. Queries filter on full 3D distance, so a match within a 3D radius
## is guaranteed to fall inside the same XZ radius (a strict superset).

## Cell side length in world units (XZ plane). Tune to roughly the typical query
## radius so a query touches a small, constant number of cells. 8 units covers
## the 3 m attack range and most AI alert radii in a single cell.
var cell_size: float = 8.0

## id → cell coordinate (Vector2i), for O(1) removal / re-hash.
var _id_to_cell: Dictionary = {}
## id → world position (Vector3), so queries need no external lookup.
var _positions: Dictionary = {}
## cell coordinate (Vector2i) → { id: true } (an id set).
var _cells: Dictionary = {}

func _init(p_cell_size: float = 8.0) -> void:
	cell_size = maxf(p_cell_size, 0.0001)

## Number of live entities in the hash.
func size() -> int:
	return _positions.size()

func has(id) -> bool:
	return _positions.has(id)

## Add an entity at `pos`. Replaces any existing entry under the same id.
func insert(id, pos: Vector3) -> void:
	remove(id)
	var c := _cell(pos)
	_id_to_cell[id] = c
	_positions[id] = pos
	if not _cells.has(c):
		_cells[c] = {}
	_cells[c][id] = true

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

## Move an entity to `pos`, re-hashing its cell only when the cell changed.
func update(id, pos: Vector3) -> void:
	if not _positions.has(id):
		insert(id, pos)
		return
	var new_c := _cell(pos)
	if new_c == _id_to_cell[id]:
		_positions[id] = pos
		return
	remove(id)
	insert(id, pos)

## Every entity id whose position is within `radius` (3D) of `pos`.
func query_radius(pos: Vector3, radius: float) -> Array:
	var out: Array = []
	var r2 := radius * radius
	var min_c := _cell(Vector3(pos.x - radius, pos.y, pos.z - radius))
	var max_c := _cell(Vector3(pos.x + radius, pos.y, pos.z + radius))
	for cx in range(min_c.x, max_c.x + 1):
		for cz in range(min_c.y, max_c.y + 1):
			var c := Vector2i(cx, cz)
			if not _cells.has(c):
				continue
			for id in _cells[c]:
				if _positions[id].distance_squared_to(pos) <= r2:
					out.append(id)
	return out

## The nearest entity id to `pos`, or null when the hash is empty. Doubles the
## probe radius until a candidate is found, so cost stays bounded by the local
## density; a linear fallback covers a pathologically sparse/far population.
func nearest(pos: Vector3) -> Variant:
	if _positions.is_empty():
		return null
	var radius := cell_size
	var candidates := query_radius(pos, radius)
	var guard := 0
	while candidates.is_empty() and guard < 64:
		radius *= 2.0
		candidates = query_radius(pos, radius)
		guard += 1
	if candidates.is_empty():
		candidates = _positions.keys()
	var best_id = null
	var best_dist := INF
	for id in candidates:
		var d: float = _positions[id].distance_to(pos)
		if d < best_dist:
			best_dist = d
			best_id = id
	return best_id

## Cell coordinate for a world position.
func _cell(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / cell_size), floori(pos.z / cell_size))
