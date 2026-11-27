class_name PlanetBake
extends RefCounted
## Phase 245 — the planet bake, GDScript reference. A deterministic, integer-only pass over a height grid
## (the 2 km planet grid in the game, a small grid in tests): depressions are filled by a priority flood
## from the sea and the grid edge, every cell drains to its steepest lower neighbour (D8, ties to the
## lowest index), flow accumulates from the top down, and cells whose flow reaches a threshold are river
## cells. Heights are integer millimetres, so every machine bakes the same bytes.
##
## Phase 302 added hydraulic erosion; the biome field is stored in the bake (`biome_field`); still to come: macro height from the bake, the progress screen and the host's copy.

const NativeLoaderScript := preload("res://src/core/native_loader.gd")
const WorldShape := preload("res://src/terrain/world_shape.gd")
const Csg := preload("res://src/terrain/terrain_csg.gd")
const NO_DIR := -1
const DX := [-1, 0, 1, -1, 1, -1, 0, 1]
const DZ := [-1, -1, -1, 0, 0, 1, 1, 1]
## The bake grid: cell size in metres, and the flow (cells draining through) that makes a river.
const CELL_M := 2000.0
const RIVER_FLOW := 40
## The largest grid a world bakes at creation (the 2,000 km planet is 500,000 cells).
const MAX_CELLS := 1000000
## Thermal erosion: passes, the steepest slope (mm of height per cell) a slope keeps, and the share
## (1/ERODE_SHARE) of the excess that slides down per pass.
## Phase 302: the talus is 500 m per 2 km cell, a 25% (14°) mean slope. Loose rock stands at 30–35° on a hillside,
## but averaged over 2 km even the steepest ranges on Earth (the Himalaya, the Andes) rarely exceed 25–30%, so
## only slopes steeper than real mountains relax. The old 2.4 m per cell (0.12%) flattened everything above a plain
## and took up to 1.3 km off the 8 km summits.
const ERODE_PASSES := 6
const ERODE_TALUS_MM := 500000
const ERODE_SHARE := 8
## Hydraulic erosion (Phase 302): passes, and the most a river cell is cut per pass (mm). A cell cuts
## `min(HYDRO_CUT_MM * flow / river_flow, ...)` down to one mm above its downstream neighbour.
const HYDRO_PASSES := 4
const HYDRO_CUT_MM := 600
const HYDRO_MAX_CUT_MM := 6000

## `base`: row-major heights in mm, `w` x `h` cells. Cells at or below `sea_mm` are sea.
## Returns { w, h, sea_mm, height (filled, mm), dir, flow, river (id per cell, 0 = none) }.
static func bake(base: PackedInt32Array, w: int, h: int, sea_mm: int, river_flow: int) -> Dictionary:
	if NativeLoaderScript.use_native("NativeBake", "bake"):   # same bytes, computed in C++
		return NativeLoaderScript.instance("NativeBake").call("bake", base, w, h, sea_mm, river_flow)
	return bake_gd(base, w, h, sea_mm, river_flow)


## The GDScript reference the native bake is held equal to.
static func bake_gd(base: PackedInt32Array, w: int, h: int, sea_mm: int, river_flow: int) -> Dictionary:
	var n := w * h
	var filled := _fill(hydraulic(erode(base, w, h, sea_mm), w, h, sea_mm, river_flow), w, h, sea_mm)
	var dir := PackedInt32Array()
	dir.resize(n)
	for i in n:
		dir[i] = _steepest(filled, w, h, i, sea_mm)
	# Accumulate flow from the highest cell down: order by (filled height, index), descending.
	var flow := _accumulate(filled, dir)
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


## Thermal erosion in integer maths: each pass, every land cell sheds `(drop - talus) / ERODE_SHARE` to
## each of its four lower land neighbours whose drop exceeds the talus. All moves of a pass are computed
## from the heights at its start and summed, so the result does not depend on visiting order. Sea cells
## and cells at or below the sea never change; mass is conserved among land cells.
static func erode(base: PackedInt32Array, w: int, h: int, sea_mm: int) -> PackedInt32Array:
	var cur := base.duplicate()
	var delta := PackedInt32Array()
	delta.resize(w * h)
	for _pass in ERODE_PASSES:
		delta.fill(0)
		for z in h:
			for x in w:
				var i := z * w + x
				if cur[i] <= sea_mm:
					continue
				for k in 4:
					var nx := x + (-1 if k == 0 else (1 if k == 1 else 0))
					var nz := z + (-1 if k == 2 else (1 if k == 3 else 0))
					if nx < 0 or nz < 0 or nx >= w or nz >= h:
						continue
					var j := nz * w + nx
					if cur[j] <= sea_mm:
						continue
					var drop := cur[i] - cur[j]
					if drop > ERODE_TALUS_MM:
						var amount := (drop - ERODE_TALUS_MM) / ERODE_SHARE
						delta[i] -= amount
						delta[j] += amount
		for i in w * h:
			cur[i] += delta[i]
	return cur


## Flow accumulation: every cell counts itself, then passes its count down its drain, highest cell first
## (order by height, then index).
static func _accumulate(f: PackedInt32Array, dir: PackedInt32Array) -> PackedInt32Array:
	var n := f.size()
	var order: Array = []
	order.resize(n)
	for i in n:
		order[i] = (f[i] << 24) | i
	order.sort()
	var flow := PackedInt32Array()
	flow.resize(n)
	flow.fill(1)
	for k in range(n - 1, -1, -1):
		var c: int = order[k] & 0xFFFFFF
		var d := dir[c]
		if d != NO_DIR:
			flow[d] += flow[c]
	return flow


## Hydraulic erosion in integer maths (Phase 302): each pass fills the depressions of the current heights,
## finds every cell's drain and flow, and cuts each river cell (flow of `river_flow` or more) by
## `HYDRO_CUT_MM * flow / river_flow` (at most HYDRO_MAX_CUT_MM), never below one mm above its drain's
## height at the start of the pass, nor to or below the sea. All cuts are computed from the heights at the
## start of the pass, so the result does not depend on visiting order; a cell stays above its drain after
## the pass (the drain only goes down too), so rivers keep reaching the sea or a lake.
static func hydraulic(base: PackedInt32Array, w: int, h: int, sea_mm: int, river_flow: int) -> PackedInt32Array:
	var n := w * h
	var cur := base.duplicate()
	for _pass in HYDRO_PASSES:
		var f := _fill(cur, w, h, sea_mm)
		var dir := PackedInt32Array()
		dir.resize(n)
		for i in n:
			dir[i] = _steepest(f, w, h, i, sea_mm)
		var flow := _accumulate(f, dir)
		var next := cur.duplicate()
		for i in n:
			var d := dir[i]
			if d == NO_DIR or flow[i] < river_flow or cur[i] <= sea_mm:
				continue
			# Only a cell that was not raised by the fill (its own ground is above its drain) is cut.
			var floor_mm := maxi(cur[d] + 1, sea_mm + 1)
			var cut := mini(HYDRO_CUT_MM * flow[i] / river_flow, HYDRO_MAX_CUT_MM)
			cut = mini(cut, cur[i] - floor_mm)
			if cut > 0:
				next[i] = cur[i] - cut
		cur = next
	return cur


## Priority flood: raise every depression to its spill height (+1 mm per step so water keeps a gradient).
static func _fill(base: PackedInt32Array, w: int, h: int, sea_mm: int) -> PackedInt32Array:
	var n := w * h
	var out := base.duplicate()
	var done := PackedByteArray()
	done.resize(n)
	var heap := PackedInt64Array()   # binary min-heap of (height << 24 | index); keys are unique, so the pop order is total
	for i in n:
		var x := i % w
		var z := i / w
		if base[i] <= sea_mm or x == 0 or z == 0 or x == w - 1 or z == h - 1:
			done[i] = 1
			_heap_push(heap, ((maxi(base[i], sea_mm) << 24) | i) if base[i] <= sea_mm else ((base[i] << 24) | i))
	while heap.size() > 0:
		var key := _heap_pop(heap)
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
			_heap_push(heap, (out[j] << 24) | j)
	return out


static func _heap_push(heap: PackedInt64Array, key: int) -> void:
	heap.append(key)
	var i := heap.size() - 1
	while i > 0:
		var parent := (i - 1) >> 1
		if heap[parent] <= key:
			break
		heap[i] = heap[parent]
		i = parent
	heap[i] = key


static func _heap_pop(heap: PackedInt64Array) -> int:
	var top := heap[0]
	var last := heap[heap.size() - 1]
	heap.resize(heap.size() - 1)
	var n := heap.size()
	if n > 0:
		var i := 0
		while true:
			var l := 2 * i + 1
			if l >= n:
				break
			var r := l + 1
			var m := r if r < n and heap[r] < heap[l] else l
			if heap[m] >= last:
				break
			heap[i] = heap[m]
			i = m
		heap[i] = last
	return top


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
		# Rounded up, so a 1 mm drop down a diagonal still counts as downhill.
		var den := 1414 if DX[k] != 0 and DZ[k] != 0 else 1000
		var drop := ((f[i] - f[j]) * 1000 + den - 1) / den if f[i] > f[j] else 0
		if drop > best_drop:
			best_drop = drop
			best = j
	return best


## River width in mm from the flow: grows with the square root of the flow.
static func river_width_mm(flow: int) -> int:
	return 1000 * Csg.isqrt(maxi(flow, 0))


## The bake's bytes: header (w, h, sea) then height, flow and river per cell, little endian int32.
static func to_bytes(b: Dictionary) -> PackedByteArray:
	var out := PackedByteArray()
	var n: int = b.w * b.h
	var biome: PackedByteArray = b.get("biome", PackedByteArray())
	out.resize(12 + n * 12 + (n if biome.size() == n else 0))
	out.encode_s32(0, b.w)
	out.encode_s32(4, b.h)
	out.encode_s32(8, b.sea_mm)
	for i in n:
		out.encode_s32(12 + i * 12, b.height[i])
		out.encode_s32(16 + i * 12, b.flow[i])
		out.encode_s32(20 + i * 12, b.river[i])
	if biome.size() == n:   # Phase 302: one biome byte per cell, after the cells
		for i in n:
			out[12 + n * 12 + i] = biome[i]
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
	if w <= 0 or h <= 0 or (bytes.size() != 12 + w * h * 12 and bytes.size() != 12 + w * h * 13):
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
	if bytes.size() == 12 + w * h * 13:
		out.biome = bytes.slice(12 + w * h * 12)
	out.height = height
	out.flow = flow
	out.river = river
	# `dir` is not stored: it is the steepest descent over the filled heights, so it is rebuilt here
	# exactly as `bake_gd` computes it (`Hydrology.baked_segs` reads it).
	var dir := PackedInt32Array()
	dir.resize(w * h)
	for i in w * h:
		dir[i] = _steepest(height, w, h, i, out.sea_mm)
	out.dir = dir
	return out


## The ground height (mm) at `p` after carving the river segment a→b into `ground_mm`: a channel whose
## floor lies `depth_mm` under `water_mm`, half `width_mm` wide, with 45° banks blended by `k_mm`.
static func carved_height(ground_mm: int, p: Vector2i, a: Vector2i, b: Vector2i, width_mm: int, water_mm: int, depth_mm: int, k_mm: int) -> int:
	var d := Csg.capsule2(p, a, b, width_mm / 2)
	var cut := water_mm - depth_mm + maxi(d, 0)
	return Csg.smooth_union(ground_mm, cut, k_mm)


## Phase 302 — the bake's macro height (m) at world (x, z): its cell heights (the filled, eroded ground, held at
## the cell centres as `base_grid` sampled them) interpolated bilinearly, so the field is continuous (C0) across
## every 2 km cell border and equals the baked height at each centre. `cell` is the cell width in metres; X wraps
## round the `w` cells, Z holds the first and last rows' heights past their centres (the poles). Pure.
static func sample_height(b: Dictionary, cell: float, x: float, z: float) -> float:
	var w: int = b["w"]
	var h: int = b["h"]
	var height: PackedInt32Array = b["height"]
	var gx := x / cell - 0.5
	var gz := (z + cell * float(h) * 0.5) / cell - 0.5
	var ix := floori(gx)
	var iz := floori(gz)
	var fx := gx - float(ix)
	var fz := gz - float(iz)
	var x0 := posmod(ix, w)
	var x1 := posmod(ix + 1, w)
	var z0 := clampi(iz, 0, h - 1) * w
	var z1 := clampi(iz + 1, 0, h - 1) * w
	var top := lerpf(float(height[z0 + x0]), float(height[z0 + x1]), fx)
	var bottom := lerpf(float(height[z1 + x0]), float(height[z1 + x1]), fx)
	return lerpf(top, bottom, fz) * 0.001


## The base height grid, in mm, sampled from `WorldShape.height` at the centre of each `cell_m` cell:
## `w` cells round the circumference `circumference_m` and `h` cells from pole to pole.
static func base_grid(seed_v: int, w: int, h: int, circumference_m: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(w * h)
	var cell := circumference_m / float(w)
	var half := cell * float(h) * 0.5
	for z in h:
		for x in w:
			var m: float = WorldShape.height(seed_v, (float(x) + 0.5) * cell, (float(z) + 0.5) * cell - half, circumference_m)
			out[z * w + x] = roundi(m * 1000.0)
	return out


## Bake the planet for `seed_v` on a `w` x `h` grid; `river_flow` is the flow that makes a river.
## The result carries the biome field (Phase 302), read from the eroded heights.
static func bake_planet(seed_v: int, w: int, h: int, circumference_m: float, river_flow: int) -> Dictionary:
	var b := bake(base_grid(seed_v, w, h, circumference_m), w, h, roundi(WorldShape.sea_level() * 1000.0), river_flow)
	b["biome"] = biome_field(b, seed_v, circumference_m, load("res://src/terrain/terrain_slice.gd").BIOME_KEYS)
	return b


## The biome of every cell (Phase 302): the climate rules (`ClimateField.biome_for_chunk`) read at the cell
## centre with the eroded height as the altitude above the sea, stored as the index into `keys`. Cells
## are `circumference_m / w` wide; the chunk read is the one holding the cell centre.
static func biome_field(b: Dictionary, seed_v: int, circumference_m: float, keys: Array) -> PackedByteArray:
	var ts: GDScript = load("res://src/terrain/terrain_slice.gd")   # loaded late: TerrainSlice preloads this file
	var cf: GDScript = load("res://src/terrain/climate_field.gd")
	var w: int = b.w
	var h: int = b.h
	var cell := circumference_m / float(w)
	var half := cell * float(h) * 0.5
	var circ_chunks := maxi(1, roundi(circumference_m / ts.CHUNK_METERS))
	var out := PackedByteArray()
	out.resize(w * h)
	for z in h:
		var cz := (float(z) + 0.5) * cell - half
		var chunk_z := floori(cz / ts.CHUNK_METERS)
		var lat: float = ts.latitude_of(chunk_z)
		for x in w:
			var chunk := Vector2i(floori((float(x) + 0.5) * cell / ts.CHUNK_METERS), chunk_z)
			var alt := float(int(b.height[z * w + x]) - int(b.sea_mm)) * 0.001
			out[z * w + x] = maxi(0, keys.find(cf.biome_for_chunk(seed_v, chunk, keys, lat, alt, circ_chunks)))
	return out


## Write the bake and its hash (`<path>` and `<path>.sha256`); false on an I/O error.
static func save(b: Dictionary, path: String) -> bool:
	var bytes := to_bytes(b)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(bytes)
	f.close()
	var hf := FileAccess.open(path + ".sha256", FileAccess.WRITE)
	if hf == null:
		return false
	hf.store_string(hash_hex(bytes))
	hf.close()
	return true


## Read a saved bake: empty when the file or hash is missing, or the hash does not match.
static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path) or not FileAccess.file_exists(path + ".sha256"):
		return {}
	return from_bytes(FileAccess.get_file_as_bytes(path), FileAccess.get_file_as_string(path + ".sha256").strip_edges())


## The bake file for a world: `<dir>/planet_<seed>_v<worldgen version>_<w>x<h>.bin`.
static func file_path(dir: String, seed_v: int, worldgen_version: int, w: int, h: int) -> String:
	return "%s/planet_%d_v%d_%dx%d.bin" % [dir, seed_v, worldgen_version, w, h]


## The bake at `path`, or a fresh one when the file is missing, damaged or (when `expected_hash` is given, as a
## client does with the host's hash) not the one the host announced; a fresh bake is saved to `path`.
## Returns { bake, hash, loaded } (`loaded`: read from the file, not baked now).
static func ensure(path: String, seed_v: int, w: int, h: int, circumference_m: float, river_flow: int, expected_hash: String = "") -> Dictionary:
	var b := load_file(path)
	if not b.is_empty():
		var hash_now := FileAccess.get_file_as_string(path + ".sha256").strip_edges()   # from_bytes already checked it
		if expected_hash == "" or hash_now == expected_hash:
			return { "bake": b, "hash": hash_now, "loaded": true }
	b = bake_planet(seed_v, w, h, circumference_m, river_flow)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	save(b, path)
	return { "bake": b, "hash": hash_hex(to_bytes(b)), "loaded": false }
