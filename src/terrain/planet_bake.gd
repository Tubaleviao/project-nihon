extends RefCounted
## Phase 245 — the planet bake (GDScript reference). A deterministic, integer-arithmetic bake of the whole
## planet on a coarse grid (2 km cells on the real planet): base height, then depression filling, flow
## accumulation, thermal and hydraulic erosion, river networks from source to sea, and a biome byte.
## Everything after the base height is integer-only, so every machine bakes the same bytes; the native
## bake (Phase 248 base) must match this one byte for byte (the parity test).
##
## Heights are int units of HEIGHT_UNIT_M (0.5 m). The grid wraps in x (the planet's circumference) and
## stops at the poles. Cell i = z * cols + x.

const FORMAT_VERSION := 1
const MAGIC := 0x4E424B31          # "NBK1"
const HEIGHT_UNIT_M := 0.5
const HEADER_BYTES := 48           # magic, version, seed (8), worldgen, cols, rows, cell_m, sea, river_min, hash (32 follows)
const CELL_BYTES := 8              # height i16, flow u16, river id u16, biome u8, flags u8
const FLAG_LAKE := 1
const FLAG_RIVER := 2
const FLAG_OCEAN := 4
const TALUS := 12                  # units (6 m per 2 km cell) a slope may keep before thermal erosion moves rock
const RIVER_MIN_FLOW := 24         # cells draining through a cell before it is a river
const ERODE_SHIFT := 4

## Neighbour offsets in a fixed order (the tie-break is the lowest index, so the order never decides a result).
const NEIGH := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]


## Bake. `base`: Callable(cell_x:int, cell_z:int) -> int height in units (the planet's `WorldShape` height,
## quantised, or a test's own). `biome`: Callable(cell_x, cell_z, height_units, flow) -> int 0..255, or invalid.
## Returns a Dictionary of PackedInt32Array fields plus the grid's meta.
static func bake(cols: int, rows: int, sea_units: int, base: Callable, biome: Callable = Callable(), erosion_passes: int = 2) -> Dictionary:
	var n := cols * rows
	var h := PackedInt32Array()
	h.resize(n)
	for z in rows:
		for x in cols:
			h[z * cols + x] = int(base.call(x, z))
	for _p in erosion_passes:
		_thermal(h, cols, rows, sea_units)
		var f := _fill(h, cols, rows, sea_units)
		var fl := _flow(f, cols, rows, sea_units)
		_hydraulic(h, fl["flow"], sea_units)
	var filled := _fill(h, cols, rows, sea_units)
	var fr := _flow(filled, cols, rows, sea_units)
	var flow: PackedInt32Array = fr["flow"]
	var down: PackedInt32Array = fr["down"]
	var river := _rivers(filled, flow, down, fr["order"], sea_units)
	var biomes := PackedInt32Array()
	biomes.resize(n)
	var flags := PackedInt32Array()
	flags.resize(n)
	for i in n:
		var fl_bits := 0
		if filled[i] <= sea_units:
			fl_bits |= FLAG_OCEAN
		elif filled[i] > h[i]:
			fl_bits |= FLAG_LAKE
		if river[i] != 0:
			fl_bits |= FLAG_RIVER
		flags[i] = fl_bits
		if biome.is_valid():
			biomes[i] = clampi(int(biome.call(i % cols, i / cols, filled[i], flow[i])), 0, 255)
	return { "cols": cols, "rows": rows, "sea": sea_units, "height": filled, "flow": flow, "down": down, "river": river, "biome": biomes, "flags": flags }

static func _nbr(i: int, k: int, cols: int, rows: int) -> int:
	var x := i % cols
	var z := i / cols
	var o: Vector2i = NEIGH[k]
	var nz := z + o.y
	if nz < 0 or nz >= rows:
		return -1
	return nz * cols + posmod(x + o.x, cols)

## Thermal erosion, one Jacobi pass: each cell sheds a share of its slope above TALUS onto its lowest neighbour.
static func _thermal(h: PackedInt32Array, cols: int, rows: int, sea: int) -> void:
	var delta := PackedInt32Array()
	delta.resize(h.size())
	for i in h.size():
		if h[i] <= sea:
			continue
		var best := -1
		for k in 8:
			var j := _nbr(i, k, cols, rows)
			if j >= 0 and (best < 0 or h[j] < h[best] or (h[j] == h[best] and j < best)):
				best = j
		if best >= 0 and h[i] - h[best] > TALUS:
			var t := (h[i] - h[best] - TALUS) >> 3
			delta[i] -= t
			delta[best] += t
	for i in h.size():
		h[i] = h[i] + delta[i] if h[i] <= sea else maxi(h[i] + delta[i], sea + 1)

## Hydraulic erosion: a land cell lowers by the square root of its flow (stream power), never into the sea.
static func _hydraulic(h: PackedInt32Array, flow: PackedInt32Array, sea: int) -> void:
	for i in h.size():
		if h[i] > sea and flow[i] > 1:
			h[i] = maxi(h[i] - (_isqrt(flow[i]) >> ERODE_SHIFT) - ((1 if flow[i] >= RIVER_MIN_FLOW else 0)), sea + 1)

static func _isqrt(v: int) -> int:
	if v <= 0:
		return 0
	var r := int(sqrt(float(v)))
	while r * r > v:
		r -= 1
	while (r + 1) * (r + 1) <= v:
		r += 1
	return r

## Priority-flood depression filling with a one-unit epsilon, so every land cell has a strictly lower neighbour:
## water always has a way down to the sea or ends in a lake cell the fill raised.
static func _fill(h: PackedInt32Array, cols: int, rows: int, sea: int) -> PackedInt32Array:
	var n := h.size()
	var f := PackedInt32Array()
	f.resize(n)
	var done := PackedByteArray()
	done.resize(n)
	var heap: Array = []
	var any := false
	for i in n:
		if h[i] <= sea:
			f[i] = h[i]
			done[i] = 1
			_push(heap, h[i], i)
			any = true
	if not any:
		var lo := 0
		for i in n:
			if h[i] < h[lo]:
				lo = i
		f[lo] = h[lo]
		done[lo] = 1
		_push(heap, h[lo], lo)
	while not heap.is_empty():
		var c := _pop(heap)
		for k in 8:
			var j := _nbr(c, k, cols, rows)
			if j < 0 or done[j] == 1:
				continue
			done[j] = 1
			f[j] = maxi(h[j], f[c] + 1)
			_push(heap, f[j], j)
	return f

const _KEY := 1 << 24
static func _push(heap: Array, height: int, idx: int) -> void:
	heap.append((height + 40000) * _KEY + idx)
	var i := heap.size() - 1
	while i > 0:
		var p := (i - 1) >> 1
		if heap[p] <= heap[i]:
			break
		var t = heap[p]
		heap[p] = heap[i]
		heap[i] = t
		i = p

static func _pop(heap: Array) -> int:
	var top: int = heap[0]
	var last: int = heap.pop_back()
	if not heap.is_empty():
		heap[0] = last
		var i := 0
		var m := heap.size()
		while true:
			var l := 2 * i + 1
			var r := l + 1
			var s := i
			if l < m and heap[l] < heap[s]:
				s = l
			if r < m and heap[r] < heap[s]:
				s = r
			if s == i:
				break
			var t = heap[s]
			heap[s] = heap[i]
			heap[i] = t
			i = s
	return top % _KEY

## Steepest descent (D8) and flow accumulation. `order`: cells from highest to lowest (ties: highest index first).
static func _flow(f: PackedInt32Array, cols: int, rows: int, sea: int) -> Dictionary:
	var n := f.size()
	var down := PackedInt32Array()
	down.resize(n)
	var flow := PackedInt32Array()
	flow.resize(n)
	for i in n:
		down[i] = -1
		flow[i] = 1
		if f[i] <= sea:
			continue
		var best := -1
		for k in 8:
			var j := _nbr(i, k, cols, rows)
			if j >= 0 and f[j] < f[i] and (best < 0 or f[j] < f[best] or (f[j] == f[best] and j < best)):
				best = j
		down[i] = best
	var keys: Array = []
	keys.resize(n)
	for i in n:
		keys[i] = (f[i] + 40000) * _KEY + i
	keys.sort()
	keys.reverse()
	var order := PackedInt32Array()
	order.resize(n)
	for q in n:
		var i: int = int(keys[q]) % _KEY
		order[q] = i
		if down[i] >= 0:
			flow[down[i]] += flow[i]
	return { "down": down, "flow": flow, "order": order }

## River ids: a cell draining RIVER_MIN_FLOW or more is river. The id is the source cell's index + 1 (mod 65535,
## never 0); a confluence keeps the id of the larger tributary, so a river is one id from source to sea or lake.
static func _rivers(f: PackedInt32Array, flow: PackedInt32Array, down: PackedInt32Array, order: PackedInt32Array, sea: int) -> PackedInt32Array:
	var id := PackedInt32Array()
	id.resize(f.size())
	var best := PackedInt32Array()
	best.resize(f.size())
	for q in order.size():
		var i := order[q]
		if f[i] <= sea or flow[i] < RIVER_MIN_FLOW:
			continue
		if id[i] == 0:
			id[i] = (i % 65535) + 1
		var d := down[i]
		if d >= 0 and f[d] > sea and flow[d] >= RIVER_MIN_FLOW and flow[i] > best[d]:
			best[d] = flow[i]
			id[d] = id[i]
	return id

## River width in metres at a cell: grows with the square root of the flow (a wide river carries more).
static func river_width_m(flow: int) -> float:
	return 0.0 if flow < RIVER_MIN_FLOW else 4.0 * sqrt(float(flow) / float(RIVER_MIN_FLOW))

# ---- file format: header, SHA-256 of the body, then the body (8 bytes a cell) ----

## The baked bytes for `seed_v` at `worldgen_version`, `cell_m` metres a cell.
static func serialize(b: Dictionary, seed_v: int, worldgen_version: int, cell_m: int) -> PackedByteArray:
	var n: int = int(b["cols"]) * int(b["rows"])
	var body := PackedByteArray()
	body.resize(n * CELL_BYTES)
	var hs: PackedInt32Array = b["height"]
	for i in n:
		var o := i * CELL_BYTES
		body.encode_s16(o, clampi(hs[i], -32768, 32767))
		body.encode_u16(o + 2, mini(int(b["flow"][i]), 65535))
		body.encode_u16(o + 4, int(b["river"][i]))
		body.encode_u8(o + 6, int(b["biome"][i]))
		body.encode_u8(o + 7, int(b["flags"][i]))
	var head := PackedByteArray()
	head.resize(HEADER_BYTES)
	head.encode_u32(0, MAGIC)
	head.encode_u32(4, FORMAT_VERSION)
	head.encode_s64(8, seed_v)
	head.encode_u32(16, worldgen_version)
	head.encode_u32(20, int(b["cols"]))
	head.encode_u32(24, int(b["rows"]))
	head.encode_u32(28, cell_m)
	head.encode_s32(32, int(b["sea"]))
	head.encode_u32(36, RIVER_MIN_FLOW)
	return head + body_hash(body) + body

static func body_hash(body: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(body)
	return ctx.finish()

## The hash a file would be published under (hex), of its body.
static func file_hash_hex(file: PackedByteArray) -> String:
	if file.size() < HEADER_BYTES + 32:
		return ""
	return body_hash(file.slice(HEADER_BYTES + 32)).hex_encode()

## Parse a baked file. `expected_hex` (the host's or the release's hash, empty to skip) and the file's own embedded
## hash must both match the body; a wrong length, magic, version, seed or worldgen version is refused too.
## Returns { ok, error (a catalog key), cols, rows, cells: PackedByteArray } .
static func parse(file: PackedByteArray, seed_v: int, worldgen_version: int, expected_hex: String = "") -> Dictionary:
	if file.size() < HEADER_BYTES + 32 or file.decode_u32(0) != MAGIC or file.decode_u32(4) != FORMAT_VERSION:
		return { "ok": false, "error": "bake.bad_header" }
	if file.decode_s64(8) != seed_v or file.decode_u32(16) != worldgen_version:
		return { "ok": false, "error": "bake.wrong_world" }
	var cols := file.decode_u32(20)
	var rows := file.decode_u32(24)
	var body := file.slice(HEADER_BYTES + 32)
	if cols == 0 or rows == 0 or body.size() != cols * rows * CELL_BYTES:
		return { "ok": false, "error": "bake.bad_size" }
	var h := body_hash(body)
	if h != file.slice(HEADER_BYTES, HEADER_BYTES + 32) or (expected_hex != "" and h.hex_encode() != expected_hex.to_lower()):
		return { "ok": false, "error": "bake.bad_hash" }
	return { "ok": true, "error": "", "cols": cols, "rows": rows, "cells": body, "sea": file.decode_s32(32) }

## The bake of a world: base height from `WorldShape.height` sampled at each cell's centre (rounded to units),
## the sea at `WorldShape.sea_level()`. The planet is `circumference_m` round and half that tall, centred on z = 0.
static func bake_world(seed_v: int, circumference_m: float, cell_m: float, erosion_passes: int = 2) -> Dictionary:
	var WorldShape := preload("res://src/terrain/world_shape.gd")
	var cols := maxi(4, roundi(circumference_m / cell_m))
	var rows := maxi(2, roundi(circumference_m * 0.5 / cell_m))
	var sea := roundi(WorldShape.sea_level() / HEIGHT_UNIT_M)
	var base := func(cx: int, cz: int) -> int:
		var x := (float(cx) + 0.5) * cell_m
		var z := (float(cz) + 0.5 - float(rows) * 0.5) * cell_m
		return roundi(WorldShape.height(seed_v, x, z, circumference_m) / HEIGHT_UNIT_M)
	return bake(cols, rows, sea, base, Callable(), erosion_passes)

## The path of a world's bake under `dir`: one file per world seed and worldgen version.
static func file_path(dir: String, seed_v: int, worldgen_version: int) -> String:
	return "%s/planet_%d_v%d.nbk" % [dir.trim_suffix("/"), seed_v, worldgen_version]

## Load the bake at `path` if it parses and matches `expected_hex` (empty: its own hash only); otherwise bake the
## world with `bake_world`, write the file and return that. `source` says which happened: "file" or "baked"
## (a refused file is replaced, never trusted). Returns { file: PackedByteArray, source, refused (error key or "") }.
static func load_or_bake(path: String, seed_v: int, worldgen_version: int, circumference_m: float, cell_m: float, expected_hex: String = "") -> Dictionary:
	var refused := ""
	if FileAccess.file_exists(path):
		var existing := FileAccess.get_file_as_bytes(path)
		var r := parse(existing, seed_v, worldgen_version, expected_hex)
		if bool(r["ok"]):
			return { "file": existing, "source": "file", "refused": "" }
		refused = str(r["error"])
	var file := serialize(bake_world(seed_v, circumference_m, cell_m), seed_v, worldgen_version, int(cell_m))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var out := FileAccess.open(path, FileAccess.WRITE)
	if out != null:
		out.store_buffer(file)
		out.close()
	return { "file": file, "source": "baked", "refused": refused }
