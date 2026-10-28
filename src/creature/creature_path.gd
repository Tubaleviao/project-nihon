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
##   max_usec     wall-clock cap in µs, checked between expansions (default 0: none); a capped search
##                returns its best partial path, like the expansion cap
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
## expansions: int, window: bool }.
##
## Phase 183 — a goal beyond `radius` cannot be reached inside the window, and the search used to spend
## its whole expansion cap (~20 ms) proving it. It aims at the point where the straight line to the goal
## leaves the window instead; `window` is true when the path ends there (reached stays false: the goal is
## further), so the caller plans again from there at once.
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
	var info := { "path": [], "reached": goal == Vector2i.ZERO, "capped": false, "expansions": 0, "window": false }
	if goal == Vector2i.ZERO:
		return info
	var far := maxi(absi(goal.x), absi(goal.y))
	var aim := goal
	if far > radius:
		aim = Vector2i(_round_div(goal.x * radius, far), _round_div(goal.y * radius, far))
	var max_usec := int(rules.get("max_usec", 0))
	var t0 := Time.get_ticks_usec()

	var heights := {}   # offset -> float (NAN = not walkable)
	var start_h := _height(Vector2i.ZERO, from_tile, lap, surface, sea, can_swim, heights)
	if is_nan(start_h):
		return info
	# Phase 183 — the straight line first. It has min(|dx|, |dy|) diagonal steps and the rest straight,
	# which is an octile-shortest path, so when every step of it is one A* could take it is as good as the
	# search's answer at a fraction of the cost (most patrol legs cross open ground).
	var line := _straight_line(aim, from_tile, lap, surface, sea, can_swim, max_step, heights)
	if not line.is_empty():
		info["path"] = line
		info["reached"] = aim == goal
		info["window"] = aim != goal
		return info
	var g := { Vector2i.ZERO: 0.0 }
	var parent := {}
	var closed := {}
	var heap: Array = []   # [f, h, serial, offset] ordered by f, then h, then insertion
	var serial := 0
	_push(heap, [_octile(Vector2i.ZERO, aim), _octile(Vector2i.ZERO, aim), serial, Vector2i.ZERO])
	var best := Vector2i.ZERO
	var best_h := _octile(Vector2i.ZERO, aim)
	var expansions := 0

	while not heap.is_empty():
		var top: Array = _pop(heap)
		var cur: Vector2i = top[3]
		if closed.has(cur):
			continue
		closed[cur] = true
		if cur == aim:
			best = cur
			info["reached"] = aim == goal
			info["window"] = aim != goal
			break
		var hcur := _octile(cur, aim)
		if hcur < best_h or (is_equal_approx(hcur, best_h) and float(g[cur]) < float(g[best])):
			best = cur
			best_h = hcur
		if expansions >= cap or (max_usec > 0 and Time.get_ticks_usec() - t0 >= max_usec):
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
				var hh := _octile(nxt, aim)
				_push(heap, [ng + hh, hh, serial, nxt])
	info["expansions"] = expansions

	var path: Array = []
	var at := best
	while at != Vector2i.ZERO:
		path.push_front(from_tile + at)
		at = parent[at]
	info["path"] = path
	return info

## The tiles from the start to `goal` (an offset) along the rounded straight line, as world tiles, or empty
## when a step of it is not walkable under the same rules the search applies (ledge, water, unknown,
## a cut corner).
static func _straight_line(goal: Vector2i, from_tile: Vector2i, lap: int, surface: Callable, sea: float, can_swim: bool, max_step: float, heights: Dictionary) -> Array:
	var n := maxi(absi(goal.x), absi(goal.y))
	var out: Array = []
	var cur := Vector2i.ZERO
	var cur_h: float = heights[cur]
	for k in range(1, n + 1):
		var nxt := Vector2i(_round_div(goal.x * k, n), _round_div(goal.y * k, n))
		var d := nxt - cur
		var nh := _height(nxt, from_tile, lap, surface, sea, can_swim, heights)
		if is_nan(nh) or absf(nh - cur_h) > max_step:
			return []
		if d.x != 0 and d.y != 0:
			var ha := _height(cur + Vector2i(d.x, 0), from_tile, lap, surface, sea, can_swim, heights)
			var hb := _height(cur + Vector2i(0, d.y), from_tile, lap, surface, sea, can_swim, heights)
			if is_nan(ha) or is_nan(hb) or absf(ha - cur_h) > max_step or absf(hb - cur_h) > max_step:
				return []
		out.append(from_tile + nxt)
		cur = nxt
		cur_h = nh
	return out

## `a / n` rounded half away from zero (n > 0).
static func _round_div(a: int, n: int) -> int:
	@warning_ignore("integer_division")
	var q := (absi(a) * 2 + n) / (2 * n)
	return q if a >= 0 else -q

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
