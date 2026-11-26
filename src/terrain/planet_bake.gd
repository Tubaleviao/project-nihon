class_name PlanetBake
extends RefCounted
## Phase 245 — the planet bake, GDScript reference. A deterministic, integer-only pass over a height grid
## (the 2 km planet grid in the game, a small grid in tests): depressions are filled by a priority flood
## from the sea and the grid edge, every cell drains to its steepest lower neighbour (D8, ties to the
## lowest index), flow accumulates from the top down, and cells whose flow reaches a threshold are river
## cells. Heights are integer millimetres, so every machine bakes the same bytes.
##
## Still to come on this base (Phase 245): erosion, the biome field, the native twin and the runtime read.

const NO_DIR := -1
const DX := [-1, 0, 1, -1, 1, -1, 0, 1]
const DZ := [-1, -1, -1, 0, 0, 1, 1, 1]

## `base`: row-major heights in mm, `w` x `h` cells. Cells at or below `sea_mm` are sea.
## Returns { w, h, sea_mm, height (filled, mm), dir, flow, river (id per cell, 0 = none) }.
static func bake(base: PackedInt32Array, w: int, h: int, sea_mm: int, river_flow: int) -> Dictionary:
	var n := w * h
	var filled := _fill(base, w, h, sea_mm)
	var dir := PackedInt32Array()
	dir.resize(n)
	for i in n:
		dir[i] = _steepest(filled, w, h, i, sea_mm)
	# Accumulate flow from the highest cell down: order by (filled height, index), descending.
	var order: Array = []
	order.resize(n)
	for i in n:
		order[i] = (filled[i] << 24) | i
	order.sort()
	var flow := PackedInt32Array()
	flow.resize(n)
	for i in n:
		flow[i] = 1
	for k in range(n - 1, -1, -1):
		var c: int = order[k] & 0xFFFFFF
		var d := dir[c]
		if d != NO_DIR:
			flow[d] += flow[c]
	# River ids: a river cell carries the id (cell index + 1) of the outlet it finally reaches.
	var river := PackedInt32Array()
	river.resize(n)
	for i in n:
		if flow[i] < river_flow or filled[i] <= sea_mm:
			continue
		var c := i
		while dir[c] != NO_DIR and filled[c] > sea_mm:
			c = dir[c]
		river[i] = c + 1
	return { "w": w, "h": h, "sea_mm": sea_mm, "height": filled, "dir": dir, "flow": flow, "river": river }


## Priority flood: raise every depression to its spill height (+1 mm per step so water keeps a gradient).
static func _fill(base: PackedInt32Array, w: int, h: int, sea_mm: int) -> PackedInt32Array:
	var n := w * h
	var out := base.duplicate()
	var done := PackedByteArray()
	done.resize(n)
	var heap: Array = []   # sorted insertion by (height << 24 | index); small grids only matter for the reference
	for i in n:
		var x := i % w
		var z := i / w
		if base[i] <= sea_mm or x == 0 or z == 0 or x == w - 1 or z == h - 1:
			done[i] = 1
			heap.append((maxi(base[i], sea_mm) << 24) | i if base[i] <= sea_mm else (base[i] << 24) | i)
	heap.sort()
	var head := 0
	while head < heap.size():
		var key: int = heap[head]
		head += 1
		var c := key & 0xFFFFFF
		var ch := key >> 24
		var cx := c % w
		var cz := c / w
		for k in 8:
			var nx: int = cx + DX[k]
			var nz: int = cz + DZ[k]
			if nx < 0 or nz < 0 or nx >= w or nz >= h:
				continue
			var j := nz * w + nx
			if done[j] == 1:
				continue
			done[j] = 1
			if out[j] <= ch:
				out[j] = ch + 1
			# Insert keeping the queue ordered (binary search from head).
			var nk: int = (out[j] << 24) | j
			var lo := head
			var hi := heap.size()
			while lo < hi:
				var mid := (lo + hi) >> 1
				if heap[mid] < nk:
					lo = mid + 1
				else:
					hi = mid
			heap.insert(lo, nk)
	return out


static func _steepest(f: PackedInt32Array, w: int, h: int, i: int, sea_mm: int) -> int:
	if f[i] <= sea_mm:
		return NO_DIR
	var x := i % w
	var z := i / w
	var best := NO_DIR
	var best_drop := 0
	for k in 8:
		var nx: int = x + DX[k]
		var nz: int = z + DZ[k]
		if nx < 0 or nz < 0 or nx >= w or nz >= h:
			continue
		var j := nz * w + nx
		# Diagonals are sqrt(2) further: compare drop * 1000 / distance (1000 or 1414).
		var drop := (f[i] - f[j]) * 1000 / (1414 if DX[k] != 0 and DZ[k] != 0 else 1000)
		if drop > best_drop:
			best_drop = drop
			best = j
	return best


## River width in mm from the flow: grows with the square root of the flow.
static func river_width_mm(flow: int) -> int:
	return 1000 * TerrainCsg.isqrt(maxi(flow, 0))


## The bake's bytes: header (w, h, sea) then height, flow and river per cell, little endian int32.
static func to_bytes(b: Dictionary) -> PackedByteArray:
	var out := PackedByteArray()
	var n: int = b.w * b.h
	out.resize(12 + n * 12)
	out.encode_s32(0, b.w)
	out.encode_s32(4, b.h)
	out.encode_s32(8, b.sea_mm)
	for i in n:
		out.encode_s32(12 + i * 12, b.height[i])
		out.encode_s32(16 + i * 12, b.flow[i])
		out.encode_s32(20 + i * 12, b.river[i])
	return out


static func hash_hex(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


## Parse bytes written by `to_bytes`, refusing them (empty result) when the SHA-256 differs from
## `expected_hash` or the size does not fit the header: a corrupt or tampered file is baked or fetched again.
static func from_bytes(bytes: PackedByteArray, expected_hash: String) -> Dictionary:
	if bytes.size() < 12 or hash_hex(bytes) != expected_hash:
		return {}
	var w := bytes.decode_s32(0)
	var h := bytes.decode_s32(4)
	if w <= 0 or h <= 0 or bytes.size() != 12 + w * h * 12:
		return {}
	var out := { "w": w, "h": h, "sea_mm": bytes.decode_s32(8) }
	var height := PackedInt32Array()
	var flow := PackedInt32Array()
	var river := PackedInt32Array()
	height.resize(w * h)
	flow.resize(w * h)
	river.resize(w * h)
	for i in w * h:
		height[i] = bytes.decode_s32(12 + i * 12)
		flow[i] = bytes.decode_s32(16 + i * 12)
		river[i] = bytes.decode_s32(20 + i * 12)
	out.height = height
	out.flow = flow
	out.river = river
	return out


## The ground height (mm) at `p` after carving the river segment a→b into `ground_mm`: a channel whose
## floor lies `depth_mm` under `water_mm`, half `width_mm` wide, with 45° banks blended by `k_mm`.
static func carved_height(ground_mm: int, p: Vector2i, a: Vector2i, b: Vector2i, width_mm: int, water_mm: int, depth_mm: int, k_mm: int) -> int:
	var d := TerrainCsg.capsule2(p, a, b, width_mm / 2)
	var cut := water_mm - depth_mm + maxi(d, 0)
	return TerrainCsg.smooth_union(ground_mm, cut, k_mm)
