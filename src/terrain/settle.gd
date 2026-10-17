extends RefCounted
## Phase 137 — loose ground settles. A pure column settler and the host's queue of dirty columns.
##
## A column is its solid runs bottom → top (`{ bottom, top, material }`, the shape `VoxelSlice` resolves).
## `settle_column` drops each granular run that has air below it onto the next solid run, keeping its
## material and volume; a rock run over air does not move. Only runs with an explicit material can be
## granular: the natural base run (material "") starts at the world floor, so it is its own support.
##
## `SettleQueue` holds the columns waiting to settle. The host enqueues the edited column and its four
## neighbours; `take` hands out at most `budget` columns per call in a deterministic order, so a big
## collapse spreads over several ticks. A column whose chunk is not loaded waits in `pending` and is
## released by `release_chunk` when the chunk loads, never dropped.

## A fall deeper than this clears the trees around it, the Phase 116 rule (`TreeSlice.CLEAR_DEPTH_M`).
const TREE_CLEAR_DROP_M := 4.0

const EPS := 0.000001

## Sort the runs bottom → top and walk them once: each entry is `{ bottom, top, material, to_bottom }`
## where `to_bottom` is where the run rests (its own bottom unless it is granular with air below it).
## `settle_column` and `moves` both read this one walk, so they cannot drift apart.
static func _walk(spans: Array, granular: Callable, floor_y: float) -> Array:
	var sorted: Array = []
	for run in spans:
		sorted.append({ "bottom": float(run["bottom"]), "top": float(run["top"]), "material": str(run.get("material", "")) })
	sorted.sort_custom(func(a, b): return float(a["bottom"]) < float(b["bottom"]))
	var support := floor_y
	for run in sorted:
		var bottom: float = run["bottom"]
		var material: String = run["material"]
		var to_bottom := bottom
		if material != "" and bool(granular.call(material)) and bottom > support + EPS:
			to_bottom = support
		run["to_bottom"] = to_bottom
		support = maxf(support, float(run["top"]) - (bottom - to_bottom))
	return sorted

## Runs after settling. `granular` is a Callable(material: String) -> bool. `floor_y` is the world floor
## a run with nothing below it lands on. Input runs may be unsorted; the result is sorted bottom → top
## with touching runs of the same material merged. Settling a settled column returns it unchanged.
static func settle_column(spans: Array, granular: Callable, floor_y: float = -96.0) -> Array:
	var out: Array = []
	for run in _walk(spans, granular, floor_y):
		var drop: float = float(run["bottom"]) - float(run["to_bottom"])
		var bottom: float = run["to_bottom"]
		var top: float = float(run["top"]) - drop
		var material: String = run["material"]
		if not out.is_empty():
			var prev: Dictionary = out[-1]
			if str(prev["material"]) == material and bottom <= float(prev["top"]) + EPS:
				prev["top"] = maxf(float(prev["top"]), top)
				continue
		out.append({ "bottom": bottom, "top": top, "material": material })
	return out

## The moves between a column and its settled form: one `{ material, from_bottom, from_top, to_bottom }`
## per run that fell. Empty when the column is already settled.
static func moves(spans: Array, granular: Callable, floor_y: float = -96.0) -> Array:
	var out: Array = []
	for run in _walk(spans, granular, floor_y):
		if float(run["to_bottom"]) < float(run["bottom"]):
			out.append({ "material": run["material"], "from_bottom": run["bottom"], "from_top": run["top"], "to_bottom": run["to_bottom"] })
	return out


class SettleQueue extends RefCounted:
	## "x,z" tile key -> Vector2i, insertion ordered; `take` sorts, so the order is deterministic.
	var _queue: Dictionary = {}
	## chunk key -> { "x,z" tile key -> Vector2i } of columns whose chunk was not loaded when they came up.
	var pending: Dictionary = {}

	func size() -> int:
		return _queue.size()

	func pending_size() -> int:
		var n := 0
		for k in pending:
			n += (pending[k] as Dictionary).size()
		return n

	func is_empty() -> bool:
		return _queue.is_empty() and pending.is_empty()

	func push(tile: Vector2i) -> void:
		_queue["%d,%d" % [tile.x, tile.y]] = tile

	## The edited column and its four neighbours.
	func push_edit(tile: Vector2i) -> void:
		for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			push(tile + d)

	## Up to `budget` columns, in (z, x) order, removed from the queue.
	func take(budget: int) -> Array:
		var tiles: Array = _queue.values()
		tiles.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y or (a.y == b.y and a.x < b.x))
		var out: Array = tiles.slice(0, maxi(budget, 0))
		for t in out:
			_queue.erase("%d,%d" % [t.x, t.y])
		return out

	## Park a column until its chunk loads.
	func defer(chunk_key: String, tile: Vector2i) -> void:
		if not pending.has(chunk_key):
			pending[chunk_key] = {}
		pending[chunk_key]["%d,%d" % [tile.x, tile.y]] = tile

	## Move a loaded chunk's parked columns back into the queue; returns how many.
	func release_chunk(chunk_key: String) -> int:
		if not pending.has(chunk_key):
			return 0
		var parked: Dictionary = pending[chunk_key]
		pending.erase(chunk_key)
		for k in parked:
			_queue[k] = parked[k]
		return parked.size()

	func clear() -> void:
		_queue.clear()
		pending.clear()
