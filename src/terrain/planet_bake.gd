extends RefCounted
## Phase 245 — the planet bake, reference implementation: a deterministic, integer-only bake of a coarse height
## grid into filled heights, flow directions, flow accumulation and river cells. The grid wraps in x (the
## planet's circumference) and ends at the poles in z. Heights are fixed point (`TerrainCsg.ONE` units a metre).
##
## Steps: thermal erosion (talus relaxation), depression filling by priority flood from the sea (so every land
## cell drains to the sea and nothing flows uphill), steepest-descent flow (D8, ties to the lowest index), flow
## accumulation, stream-power erosion along the rivers, then the fill and flow again on the carved surface.
## Ties are broken by cell index everywhere, so every machine bakes the same bytes. The native twin (Phase 248
## base) must reproduce `to_bytes` exactly.

const TerrainCsg := preload("res://src/terrain/terrain_csg.gd")

const NO_DIR := -1
## Neighbour offsets (dx, dz), the order is part of the format (ties go to the lower index in this list).
const DX := [1, 1, 0, -1, -1, -1, 0, 1]
const DZ := [0, 1, 1, 1, 0, -1, -1, -1]

## Parameters of a bake (all integers).
static func default_params() -> Dictionary:
	return {
		"sea_level": 0,                 # fixed point: a cell at or under this is sea
		"thermal_iterations": 2,
		"talus": TerrainCsg.ONE * 4,    # fixed-point height difference per neighbour a slope keeps
		"river_flow": 12,               # accumulated cells at which a land cell is a river
		"stream_power_k": 8,            # fixed-point depth cut per isqrt(flow)
		"stream_depth_max": TerrainCsg.ONE * 20,
	}

## Bake `heights` (w * h fixed-point values, row-major, row = z) and return
## { w, h, height, filled, dir, flow, river } — `river` is 1 on a river cell, 0 elsewhere.
static func bake(w: int, h: int, heights: PackedInt32Array, params: Dictionary = {}) -> Dictionary:
	var p := default_params()
	p.merge(params, true)
	assert(heights.size() == w * h)
	var cur := heights.duplicate()
	for _i in int(p["thermal_iterations"]):
		cur = _thermal(w, h, cur, int(p["talus"]))
	var filled := fill(w, h, cur, int(p["sea_level"]))
	var dir := directions(w, h, filled, int(p["sea_level"]))
	var flow := accumulate(w, h, filled, dir)
	# Stream power: a river cuts the raw ground in proportion to the root of its flow.
	var carved := cur.duplicate()
	for i in w * h:
		if flow[i] >= int(p["river_flow"]) and filled[i] > int(p["sea_level"]):
			var cut := mini(TerrainCsg.isqrt(flow[i]) * int(p["stream_power_k"]), int(p["stream_depth_max"]))
			carved[i] = maxi(carved[i] - cut, int(p["sea_level"]) + 1)
	filled = fill(w, h, carved, int(p["sea_level"]))
	dir = directions(w, h, filled, int(p["sea_level"]))
	flow = accumulate(w, h, filled, dir)
	var river := PackedByteArray()
	river.resize(w * h)
	for i in w * h:
		river[i] = 1 if (flow[i] >= int(p["river_flow"]) and filled[i] > int(p["sea_level"])) else 0
	return { "w": w, "h": h, "height": carved, "filled": filled, "dir": dir, "flow": flow, "river": river }

static func _idx(w: int, x: int, z: int) -> int:
	return z * w + posmod(x, w)

## Neighbour of cell `i` in direction `d`, or -1 past a pole.
static func neighbour(w: int, h: int, i: int, d: int) -> int:
	var z := i / w + int(DZ[d])
	if z < 0 or z >= h:
		return -1
	return _idx(w, i % w + int(DX[d]), z)

## Thermal erosion: a cell higher than a neighbour by more than `talus` gives that neighbour a quarter of the excess
## over it (integer), in index order, so the result does not depend on iteration timing.
static func _thermal(w: int, h: int, src: PackedInt32Array, talus: int) -> PackedInt32Array:
	var out := src.duplicate()
	for i in w * h:
		for d in 8:
			var n := neighbour(w, h, i, d)
			if n < 0:
				continue
			var diff: int = src[i] - src[n]
			if diff > talus:
				var moved := (diff - talus) / 4
				out[i] -= moved
				out[n] += moved
	return out

## Priority-flood depression filling from the sea: every land cell ends at least one unit above the neighbour it
## drains to, so a strictly descending path to the sea exists. Cells at or under `sea` keep their height.
static func fill(w: int, h: int, src: PackedInt32Array, sea: int) -> PackedInt32Array:
	var n := w * h
	var out := src.duplicate()
	var done := PackedByteArray()
	done.resize(n)
	var heap := _Heap.new()
	var any_sea := false
	for i in n:
		if src[i] <= sea:
			done[i] = 1
			heap.push(src[i], i)
			any_sea = true
	if not any_sea:   # no ocean: the lowest cell (lowest index on a tie) is the outlet
		var lo := 0
		for i in n:
			if src[i] < src[lo]:
				lo = i
		done[lo] = 1
		heap.push(src[lo], lo)
	while not heap.is_empty():
		var top: Vector2i = heap.pop()
		var i := top.y
		for d in 8:
			var m := neighbour(w, h, i, d)
			if m < 0 or done[m] == 1:
				continue
			done[m] = 1
			out[m] = maxi(src[m], out[i] + 1)
			heap.push(out[m], m)
	return out

## Steepest descent per land cell (index of the direction in DX/DZ), NO_DIR for sea cells and outlets.
static func directions(w: int, h: int, filled: PackedInt32Array, sea: int) -> PackedInt32Array:
	var dir := PackedInt32Array()
	dir.resize(w * h)
	for i in w * h:
		dir[i] = NO_DIR
		if filled[i] <= sea:
			continue
		var best := 0
		var best_d := NO_DIR
		for d in 8:
			var m := neighbour(w, h, i, d)
			if m < 0:
				continue
			var drop: int = filled[i] - filled[m]
			if d % 2 == 1:   # a diagonal is longer: its slope is the drop over sqrt(2), compared as drop * 5 / 7
				drop = drop * 5 / 7
			if drop > best:
				best = drop
				best_d = d
		dir[i] = best_d
	return dir

## Flow accumulation: each cell counts itself plus everything draining through it. Processed from the highest
## cell down (ties by index), so a cell is complete before it hands its flow on.
static func accumulate(w: int, h: int, filled: PackedInt32Array, dir: PackedInt32Array) -> PackedInt32Array:
	var n := w * h
	var order: Array = []
	order.resize(n)
	for i in n:
		order[i] = i
	order.sort_custom(func(a: int, b: int) -> bool:
		return filled[a] > filled[b] or (filled[a] == filled[b] and a < b))
	var flow := PackedInt32Array()
	flow.resize(n)
	for i in n:
		flow[i] = 1
	for i in order:
		if dir[i] != NO_DIR:
			flow[neighbour(w, h, i, dir[i])] += flow[i]
	return flow

## The bake as bytes: per cell height, filled height, direction and flow as little-endian int32, then the river byte.
static func to_bytes(b: Dictionary) -> PackedByteArray:
	var n: int = int(b["w"]) * int(b["h"])
	var out := PackedByteArray()
	out.resize(n * 17 + 8)
	out.encode_s32(0, int(b["w"]))
	out.encode_s32(4, int(b["h"]))
	var o := 8
	for i in n:
		out.encode_s32(o, b["height"][i]); out.encode_s32(o + 4, b["filled"][i])
		out.encode_s32(o + 8, b["dir"][i]); out.encode_s32(o + 12, b["flow"][i])
		out[o + 16] = b["river"][i]
		o += 17
	return out

## SHA-256 of `to_bytes`, as hex: the file's identity (a client checks it against the host's).
static func hash_of(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()

## A binary min-heap of (key, index) pairs ordered by key then index.
class _Heap extends RefCounted:
	var _a: Array = []
	func is_empty() -> bool:
		return _a.is_empty()
	func _less(x: Vector2i, y: Vector2i) -> bool:
		return x.x < y.x or (x.x == y.x and x.y < y.y)
	func push(key: int, idx: int) -> void:
		_a.append(Vector2i(key, idx))
		var c := _a.size() - 1
		while c > 0:
			var pr := (c - 1) / 2
			if _less(_a[c], _a[pr]):
				var t: Vector2i = _a[c]; _a[c] = _a[pr]; _a[pr] = t
				c = pr
			else:
				break
	func pop() -> Vector2i:
		var top: Vector2i = _a[0]
		var last: Vector2i = _a.pop_back()
		if not _a.is_empty():
			_a[0] = last
			var c := 0
			while true:
				var l := 2 * c + 1
				var r := l + 1
				var m := c
				if l < _a.size() and _less(_a[l], _a[m]): m = l
				if r < _a.size() and _less(_a[r], _a[m]): m = r
				if m == c: break
				var t: Vector2i = _a[c]; _a[c] = _a[m]; _a[m] = t
				c = m
		return top

## True when `bytes` hash to `expected` (a client refuses a bake whose hash differs and bakes or downloads again).
static func accepts(bytes: PackedByteArray, expected: String) -> bool:
	return not bytes.is_empty() and hash_of(bytes) == expected

## Bytes back into the grids (empty when truncated or the size line disagrees).
static func from_bytes(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 8:
		return {}
	var w := bytes.decode_s32(0)
	var h := bytes.decode_s32(4)
	if w <= 0 or h <= 0 or bytes.size() != w * h * 17 + 8:
		return {}
	var b := { "w": w, "h": h, "height": PackedInt32Array(), "filled": PackedInt32Array(), "dir": PackedInt32Array(), "flow": PackedInt32Array(), "river": PackedByteArray() }
	for k in ["height", "filled", "dir", "flow", "river"]:
		b[k].resize(w * h)
	var o := 8
	for i in w * h:
		b["height"][i] = bytes.decode_s32(o); b["filled"][i] = bytes.decode_s32(o + 4)
		b["dir"][i] = bytes.decode_s32(o + 8); b["flow"][i] = bytes.decode_s32(o + 12)
		b["river"][i] = bytes[o + 16]
		o += 17
	return b
