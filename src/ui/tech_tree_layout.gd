extends RefCounted
## Phase 270 — the technology tree's layout as a pure function of the fabric's `requires` edges.
##
## A technology's column is the length of its longest prerequisite chain (a root is column 0), so every
## technology sits to the right of each of its prerequisites. Rows within a column start in id order and
## are then reordered by barycentre passes (each node moves toward the mean row of its neighbours in the
## columns before it, then after it) to reduce line crossings; the ordering with the fewest crossings
## seen is kept. Ties break on the current row, so the same input always gives the same layout, and
## `for_fabric()` caches the one built from `GameData.TECHNOLOGIES`.

## Barycentre sweeps (one down + one up each). Small trees settle in two or three.
const PASSES := 6

static var _fabric_cache: Dictionary = {}

## `requires`: { tech_id: Array of prerequisite ids }. A prerequisite that is not a key is ignored.
## Returns {
##   column: { id: int }, row: { id: int } (index within its column),
##   columns: Array of Arrays (ids per column, top to bottom),
##   edges: Array of [prerequisite, tech] (sorted, each `requires` entry once),
##   position: { id: Vector2 } (x = column, y = row centred on the column's middle, in grid units),
##   crossings: int }
static func layout(requires: Dictionary) -> Dictionary:
	var ids: Array = requires.keys().map(func(k): return str(k))
	ids.sort()
	var reqs: Dictionary = {}
	for id: String in ids:
		var list: Array = []
		for r in requires[id] if requires[id] is Array else []:
			var rid := str(r)
			if requires.has(rid) and rid != id and not list.has(rid):
				list.append(rid)
		list.sort()
		reqs[id] = list
	var column: Dictionary = {}
	for id: String in ids:
		_column_of(id, reqs, column, {})
	var depth := 0
	for id: String in ids:
		depth = maxi(depth, int(column[id]))
	var columns: Array = []
	for c in depth + 1:
		columns.append([])
	for id: String in ids:
		(columns[int(column[id])] as Array).append(id)  # ids are sorted: the starting order
	var edges: Array = []
	var dependents: Dictionary = {}
	for id: String in ids:
		dependents[id] = []
	for id: String in ids:
		for r: String in reqs[id]:
			edges.append([r, id])
			(dependents[r] as Array).append(id)
	var best: Array = _copy(columns)
	var best_cross := crossings(columns, edges)
	for p in PASSES:
		for c in range(1, columns.size()):
			_sweep(columns, c, reqs)
		var cross := crossings(columns, edges)
		if cross < best_cross:
			best_cross = cross
			best = _copy(columns)
		for c in range(columns.size() - 2, -1, -1):
			_sweep(columns, c, dependents)
		cross = crossings(columns, edges)
		if cross < best_cross:
			best_cross = cross
			best = _copy(columns)
	var row: Dictionary = {}
	var position: Dictionary = {}
	for c in best.size():
		var col: Array = best[c]
		for i in col.size():
			row[col[i]] = i
			position[col[i]] = Vector2(c, _centred(i, col.size()))
	return {"column": column, "row": row, "columns": best, "edges": edges, "position": position, "crossings": best_cross}

## The layout of the fabric's technology tree, built once.
static func for_fabric() -> Dictionary:
	if _fabric_cache.is_empty():
		_fabric_cache = layout(fabric_requires())
	return _fabric_cache

## { tech_id: requires } read from the generated `GameData.TECHNOLOGIES` resources.
static func fabric_requires() -> Dictionary:
	var out: Dictionary = {}
	for id in GameData.TECHNOLOGIES:
		var res: Resource = GameData.TECHNOLOGIES[id]
		var data = res.get("tech") if res != null else null
		if data is String and data != "":
			data = JSON.parse_string(data)
		out[str(id)] = (data as Dictionary).get("requires", []) if data is Dictionary else []
	return out

## Line crossings when each edge is a straight segment between its ends' centred positions.
static func crossings(columns: Array, edges: Array) -> int:
	var pos: Dictionary = {}
	for c in columns.size():
		var col: Array = columns[c]
		for i in col.size():
			pos[col[i]] = Vector2(c, _centred(i, col.size()))
	var n := 0
	for i in edges.size():
		for j in range(i + 1, edges.size()):
			var a: Array = edges[i]
			var b: Array = edges[j]
			if a[0] == b[0] or a[0] == b[1] or a[1] == b[0] or a[1] == b[1]:
				continue  # lines that share a node meet there; that is not a crossing
			if Geometry2D.segment_intersects_segment(pos[a[0]], pos[a[1]], pos[b[0]], pos[b[1]]) != null:
				n += 1
	return n

static func _column_of(id: String, reqs: Dictionary, column: Dictionary, visiting: Dictionary) -> int:
	if column.has(id):
		return int(column[id])
	if visiting.has(id):
		return 0  # a cycle (the fabric forbids them): break it rather than recurse forever
	visiting[id] = true
	var c := 0
	for r: String in reqs[id]:
		c = maxi(c, _column_of(r, reqs, column, visiting) + 1)
	visiting.erase(id)
	column[id] = c
	return c

## Reorder column `c` by the mean centred row of each node's `neighbours` (in any other column).
static func _sweep(columns: Array, c: int, neighbours: Dictionary) -> void:
	var where: Dictionary = {}
	for cc in columns.size():
		var col: Array = columns[cc]
		for i in col.size():
			where[col[i]] = _centred(i, col.size())
	var col: Array = columns[c]
	var keyed: Array = []
	for i in col.size():
		var id: String = col[i]
		var sum := 0.0
		var count := 0
		for nb: String in neighbours[id]:
			sum += float(where[nb])
			count += 1
		keyed.append([sum / count if count > 0 else float(where[id]), i, id])
	keyed.sort_custom(func(x: Array, y: Array) -> bool:
		if not is_equal_approx(float(x[0]), float(y[0])):
			return float(x[0]) < float(y[0])
		return int(x[1]) < int(y[1]))
	columns[c] = keyed.map(func(k: Array) -> String: return k[2])

static func _centred(i: int, n: int) -> float:
	return float(i) - float(n - 1) / 2.0

static func _copy(columns: Array) -> Array:
	return columns.map(func(col: Array) -> Array: return col.duplicate())
