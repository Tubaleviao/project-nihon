extends RefCounted
## Phase 136 — a bounded A* over voxel columns for creatures.
##
## Pure and static: the world is reached through a `surface` Callable, so the search runs the same on the
## host, in a test and far from the origin. Tiles are integer `Vector2i` (global tile coordinates), and the
## search works in OFFSETS from the start tile, so nothing loses precision however far the creature is from
## the origin, and the seam is crossed the short way round: the goal's offset is `SeamWrap.delta`, and the
## returned path is continuous with `from_tile` (its X may run past the seam; the surface callable receives
## the tile wrapped into the lap).
##
## rules (Dictionary, all optional):
##   max_step     tallest ledge climbed in one tile step, metres (default 0.75)
##   can_swim     water tiles (ground below `sea_level`) are walkable (default false)
##   radius       search window in tiles around the start (default 24)
##   sea_level    metres (default 0.0)
##   lap_tiles    tiles in one lap of the world; 0 = no seam (default 0)
##   max_expansions  node-expansion cap (default DEFAULT_MAX_EXPANSIONS)
##
## surface: Callable(tile: Vector2i) -> float, the walkable height of the column, or NAN when it is not
## known (an unloaded chunk). An unknown tile is not walkable.

const SeamWrap := preload("res://src/terrain/seam_wrap.gd")

const DEFAULT_MAX_STEP := 0.75
const DEFAULT_RADIUS := 24
const DEFAULT_MAX_EXPANSIONS := 600
const STRAIGHT_COST := 1.0
const DIAGONAL_COST := 1.4142136

const _DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

## The search result: { path: Array[Vector2i] (tiles after `from_tile`, empty when none is better than
## staying), reached: bool (the last tile is the goal), capped: bool (stopped at the expansion cap),
## expansions: int }.
static func search(from_tile: Vector2i, to_tile: Vector2i, rules: Dictionary, surface: Callable) -> Dictionary:
	var max_step := float(rules.get("max_step", DEFAULT_MAX_STEP))
	var can_swim := bool(rules.get("can_swim", false))
	var radius := maxi(int(rules.get("radius", DEFAULT_RADIUS)), 1)
	var sea := float(rules.get("sea_level", 0.0))
	var lap := int(rules.get("lap_tiles", 0))
	var cap := maxi(int(rules.get("max_expansions", DEFAULT_MAX_EXPANSIONS)), 1)

	var goal := Vector2i(to_tile.x - from_tile.x, to_tile.y - from_tile.y)
	if lap > 0:
		goal.x = SeamWrap.delta(to_tile.x, from_tile.x, lap)
	var info := { "path": [], "reached": goal == Vector2i.ZERO, "capped": false, "expansions": 0 }
	if goal == Vector2i.ZERO:
		return info

	var heights := {}   # offset -> float (NAN = not walkable)
	var start_h := _height(Vector2i.ZERO, from_tile, lap, surface, sea, can_swim, heights)
	if is_nan(start_h):
		return info
	var g := { Vector2i.ZERO: 0.0 }
	var parent := {}
	var closed := {}
	var heap: Array = []   # [f, h, serial, offset] ordered by f, then h, then insertion
	var serial := 0
	_push(heap, [_octile(Vector2i.ZERO, goal), _octile(Vector2i.ZERO, goal), serial, Vector2i.ZERO])
	var best := Vector2i.ZERO
	var best_h := _octile(Vector2i.ZERO, goal)
	var expansions := 0

	while not heap.is_empty():
		var top: Array = _pop(heap)
		var cur: Vector2i = top[3]
		if closed.has(cur):
			continue
		closed[cur] = true
		if cur == goal:
			best = cur
			info["reached"] = true
			break
		var hcur := _octile(cur, goal)
		if hcur < best_h or (is_equal_approx(hcur, best_h) and float(g[cur]) < float(g[best])):
			best = cur
			best_h = hcur
		if expansions >= cap:
			info["capped"] = true
			break
		expansions += 1
		var cur_h: float = heights[cur]
		for d in _DIRS:
			var nxt := cur + d
			if absi(nxt.x) > radius or absi(nxt.y) > radius or closed.has(nxt):
				continue
			var nh := _height(nxt, from_tile, lap, surface, sea, can_swim, heights)
			if is_nan(nh) or absf(nh - cur_h) > max_step:
				continue
			if d.x != 0 and d.y != 0:
				# No cutting a corner: both orthogonal neighbours must be steppable too.
				var a := cur + Vector2i(d.x, 0)
				var b := cur + Vector2i(0, d.y)
				var ha := _height(a, from_tile, lap, surface, sea, can_swim, heights)
				var hb := _height(b, from_tile, lap, surface, sea, can_swim, heights)
				if is_nan(ha) or is_nan(hb) or absf(ha - cur_h) > max_step or absf(hb - cur_h) > max_step:
					continue
			var ng: float = float(g[cur]) + (DIAGONAL_COST if d.x != 0 and d.y != 0 else STRAIGHT_COST)
			if not g.has(nxt) or ng < float(g[nxt]):
				g[nxt] = ng
				parent[nxt] = cur
				serial += 1
				var hh := _octile(nxt, goal)
				_push(heap, [ng + hh, hh, serial, nxt])
	info["expansions"] = expansions

	var path: Array = []
	var at := best
	while at != Vector2i.ZERO:
		path.push_front(from_tile + at)
		at = parent[at]
	info["path"] = path
	return info

## Convenience: just the tiles (see `search`).
static func find_path(from_tile: Vector2i, to_tile: Vector2i, rules: Dictionary, surface: Callable) -> Array:
	return search(from_tile, to_tile, rules, surface)["path"]

## The walkable height of the tile at `offset` from the start, NAN when not walkable. Cached per search.
## The start tile is always standable, so a creature already in the water can still leave it.
static func _height(offset: Vector2i, from_tile: Vector2i, lap: int, surface: Callable, sea: float, can_swim: bool, cache: Dictionary) -> float:
	if cache.has(offset):
		return cache[offset]
	var tile := from_tile + offset
	if lap > 0:
		tile.x = SeamWrap.wrap_i(tile.x, lap)
	var h := float(surface.call(tile))
	if not is_nan(h) and not can_swim and offset != Vector2i.ZERO and h < sea:
		h = NAN
	cache[offset] = h
	return h

static func _octile(a: Vector2i, b: Vector2i) -> float:
	var dx := absi(a.x - b.x)
	var dy := absi(a.y - b.y)
	return STRAIGHT_COST * float(maxi(dx, dy) - mini(dx, dy)) + DIAGONAL_COST * float(mini(dx, dy))

# --- a small binary min-heap on [f, h, serial, ...] -------------------------------------------------

static func _less(a: Array, b: Array) -> bool:
	if a[0] != b[0]:
		return a[0] < b[0]
	if a[1] != b[1]:
		return a[1] < b[1]
	return a[2] < b[2]

static func _push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		@warning_ignore("integer_division")
		var p := (i - 1) / 2
		if not _less(heap[i], heap[p]):
			break
		var t = heap[i]
		heap[i] = heap[p]
		heap[p] = t
		i = p

static func _pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if not heap.is_empty():
		heap[0] = last
		var i := 0
		var n := heap.size()
		while true:
			var l := 2 * i + 1
			var r := l + 1
			var m := i
			if l < n and _less(heap[l], heap[m]):
				m = l
			if r < n and _less(heap[r], heap[m]):
				m = r
			if m == i:
				break
			var t = heap[i]
			heap[i] = heap[m]
			heap[m] = t
			i = m
	return top
