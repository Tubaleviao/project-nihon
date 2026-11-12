extends RefCounted
## Phase 240 — smooth natural ground: a surface-nets mesher over the resolved runs, the GDScript
## reference of the native port (`native/src/native_smooth.cpp`). PURE and worker-safe like
## `voxel_mesh.gd`: everything it reads arrives as an argument, and it returns the same dictionary
## `VoxelMesh.build_chunk_arrays` does.
##
## The density is sampled at tile centres in X and Z (0.5 m) and every 0.5 m in Y. A sample's value is
## the signed VERTICAL distance to the nearest natural run boundary of its column (negative inside),
## clamped to ±`CLAMP`. Vertical distance is linear across a boundary, so a crossing on a vertical edge
## lands on the run's exact top, and on a plane of runs (a ramp) every crossing lies on the plane.
##
## Surface nets put one vertex in each cell (eight samples) the surface crosses, at the mean of the
## crossings on the cell's edges, and one quad across each sample edge the surface crosses. A quad
## across a VERTICAL edge (a column top or an underside) is a fan around one more vertex, at the
## column's centre and the run's exact top, so the ground stands where the runs say it does.
##
## Natural runs only: a placed block (a run with a material) reads as air here and is meshed by the
## block mesher (`VoxelMesh.build_chunk_arrays_gd(..., placed_only = true)`), so walls stay square. Its
## walls reach `PLACED_SKIRT` below a block resting on natural ground, or down to the neighbour's natural
## top when that is lower, so the smooth ground, which slopes between tile centres, never shows a gap
## under a block's face.
##
## Phase 241 — coarse chunks (`VoxelCoarse`, 2× and 4× cells) run the same mesher on a downsampled
## density: one column per cell, every spacing and the clamp scaled by the step (`mesh_coarse_columns`).
## Its shared vertices are pinned to the cell corners, as high as the tallest cell round each, so the
## ground over a cell (a fan from its top in the middle) never dips under a true tile: the coarse
## collision stays conservative. The columns past the chunk's edge repeat its edge columns, so the
## surface runs to the edge plane, and every mesh edge lying on that plane drops a skirt to bedrock. A
## corner on the edge plane is also as high as the neighbours' tiles beside it (`edge_tops`, the ring one
## tile past the edge): a full neighbour owns no wall on its west and north edges, so its border vertex,
## a blend of its own tile and ours, may stand above our cells, and the skirt must reach it. So a full
## neighbour's ground meets the skirt whatever order the two were built in. Every level of a corner is the
## same point, so a coarse cell has one vertex (keyed without its level) and a cliff's upright quads, which
## would have no area, are never made.
##
## Normals are the density gradient (central differences) at each cell corner, interpolated to the
## vertex, not the mean of the triangles: both chunks at a border sample the same corners, so the
## shading has no seam. The chunk reads columns two tiles past its edge (`PAD`), which `build_runs`
## resolves when the gathered input asks for `pad` 2 (`VoxelMesh.terrain_pad`).
##
## The corner-gradient normals and the sample padding follow godot_voxel's Transvoxel mesher
## (meshers/transvoxel/transvoxel.cpp, commit dfb0f81c7fd766f68d78715b2138f4e336cd9737). The algorithm
## is ported, not the code; its notice:
##
##   MIT License. Copyright (c) 2016-2024 Marc Gilleron.
##   Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
##   associated documentation files (the "Software"), to deal in the Software without restriction,
##   including without limitation the rights to use, copy, modify, merge, publish, distribute,
##   sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
##   furnished to do so, subject to the following conditions: The above copyright notice and this
##   permission notice shall be included in all copies or substantial portions of the Software.
##   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED.

const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")
const MeshUtil := preload("res://src/core/mesh_util.gd")
const NativeBuilder := preload("res://src/terrain/native_builder.gd")
const CHUNK_SIZE := VoxelConsts.CHUNK_SIZE
const TILE_SIZE := VoxelConsts.TILE_SIZE
const BEDROCK_DEPTH := VoxelConsts.BEDROCK_DEPTH
const FALLBACK_TERRAIN_COLOR := VoxelConsts.FALLBACK_TERRAIN_COLOR

## The vertical sample spacing (m). The horizontal one is TILE_SIZE, which is the same 0.5 m.
const GRID := 0.5
## The density's clamp (m): past this a sample reads plain "deep inside" or "far outside".
const CLAMP := 1.5
## The least an inside sample reads, so a sample on a run's bottom is still negative (inside).
const INSIDE_MIN := 0.0001
## Columns read past the chunk's edge: one cell of vertices below, and the gradient's neighbours.
const PAD := 2
const SPAN := CHUNK_SIZE + 2 * PAD
## How far a placed block's walls reach below it when it rests on natural ground (m).
const PLACED_SKIRT := 0.5
## A vertex within this of a run's top wears the run's top colour (the biome's surface tint).
const TOP_BAND := 0.3
## Offsets a cell's level into a non-negative vertex key (BEDROCK_DEPTH / GRID is -192).
const LEVEL_OFFSET := 1024

## `voxel_mesh.gd` preloads this script, so it cannot be a `const` here. Resolved once on the main thread
## (`warm`, from `VoxelSlice._ready`), so the worker hot path never goes back to the ResourceLoader.
static var _voxel_mesh_script: GDScript = null

static func warm() -> void:
	_voxel_mesh()

static func _voxel_mesh() -> GDScript:
	if _voxel_mesh_script == null:
		_voxel_mesh_script = load("res://src/terrain/voxel_mesh.gd")
	return _voxel_mesh_script

## The smooth natural ground plus the placed blocks' square faces, as one result in the shape of
## `VoxelMesh.build_chunk_arrays`: vertices, normals, colours, indices, the collision triangle soup
## (the same triangles), counts and the deposit boxes.
static func build_smooth_arrays(chunk_pos: Vector2i, heightmap: Array, resolved: Dictionary, local: bool = false) -> Dictionary:
	var VoxelMesh: GDScript = _voxel_mesh()
	var placed: Dictionary = VoxelMesh.build_chunk_arrays_gd(chunk_pos, heightmap, resolved, local, true) \
		if _has_placed(resolved) else _deposits_only(resolved, local)
	var smooth := build_natural_arrays(chunk_pos, heightmap, resolved, local)
	var vertices: PackedVector3Array = smooth["vertices"]
	var normals: PackedVector3Array = smooth["normals"]
	var colors: PackedColorArray = smooth["colors"]
	var indices: PackedInt32Array = smooth["indices"]
	var collision: PackedVector3Array = smooth["collision"]
	var base := vertices.size()
	vertices.append_array(placed["vertices"])
	normals.append_array(placed["normals"])
	colors.append_array(placed["colors"])
	for i in (placed["indices"] as PackedInt32Array):
		indices.append(base + i)
	collision.append_array(placed["collision"])
	return {
		"vertices": vertices, "normals": normals, "colors": colors, "indices": indices,
		"collision": collision,
		"quad_count": int(smooth["quad_count"]) + int(placed["quad_count"]),
		"cell_count": int(smooth["cell_count"]) + int(placed["cell_count"]),
		"smooth_quads": int(smooth["quad_count"]),
		"smooth_vertex_count": base,
		"deposit_vertices": placed["deposit_vertices"], "deposit_normals": placed["deposit_normals"],
		"deposit_colors": placed["deposit_colors"], "deposit_indices": placed["deposit_indices"],
		"local": local,
	}

## Whether any resolved column holds a placed run: most chunks hold none, and then the block pass only
## has the deposit boxes to emit (an empty table falls back to natural columns, which it skips).
static func _has_placed(resolved: Dictionary) -> bool:
	for column in (resolved.get("runs", {}) as Dictionary).values():
		for run in column:
			if str(run.get("material", "")) != "":
				return true
	return false

## The block pass's result for a chunk with no placed run: no faces, only the deposit boxes.
static func _deposits_only(resolved: Dictionary, local: bool) -> Dictionary:
	var dv := PackedVector3Array()
	var dn := PackedVector3Array()
	var dc := PackedColorArray()
	var di := PackedInt32Array()
	for deposit in resolved.get("deposits", []):
		MeshUtil.add_box_arrays(dv, dn, dc, di, deposit["local_position"] if local else deposit["position"], deposit["size"], deposit["color"])
	return {
		"vertices": PackedVector3Array(), "normals": PackedVector3Array(), "colors": PackedColorArray(),
		"indices": PackedInt32Array(), "collision": PackedVector3Array(), "quad_count": 0, "cell_count": 0,
		"deposit_vertices": dv, "deposit_normals": dn, "deposit_colors": dc, "deposit_indices": di,
	}

## The smooth half alone: the natural runs' surface. `quad_count` counts sample edges crossed.
static func build_natural_arrays(chunk_pos: Vector2i, heightmap: Array, resolved: Dictionary, local: bool = false) -> Dictionary:
	if NativeBuilder.use_native("build_smooth_arrays"):   # the same arrays, built in C++
		var VoxelMesh: GDScript = _voxel_mesh()
		var native := NativeBuilder.builder().call("build_smooth_arrays", chunk_pos, heightmap, resolved, local, VoxelMesh.native_arrays_cfg()) as Dictionary
		if native.has("vertices"):   # a rejected input comes back empty: use the reference
			return native
	return build_natural_arrays_gd(chunk_pos, heightmap, resolved, local)

## The GDScript reference of `build_natural_arrays`: the fallback and the parity test's baseline.
static func build_natural_arrays_gd(chunk_pos: Vector2i, heightmap: Array, resolved: Dictionary, local: bool = false) -> Dictionary:
	var m := _Mesher.new(chunk_pos, local, 1)
	m.load_tiles(heightmap, resolved.get("runs", {}), _voxel_mesh())
	m.build()
	return {
		"vertices": m.vertices, "normals": m.normals, "colors": m.colors, "indices": m.indices,
		"collision": m.collision, "quad_count": m.quads, "cell_count": m.cells.size(), "local": local,
	}

## Phase 241 — a coarse chunk's mesh: `cols` (from `VoxelCoarse.coarse_columns`, one column per cell of
## `step`×`step` tiles) meshed smooth on the scaled grid, with a skirt to bedrock under every edge.
## The collision is the same triangles, skirts included.
static func mesh_coarse_columns(chunk_pos: Vector2i, cols: Dictionary, step: int, local: bool) -> Dictionary:
	var m := _Mesher.new(chunk_pos, local, step)
	m.skirted = true
	m.load_columns(cols)
	m.build()
	var skirts := m.add_skirts()
	return {
		"vertices": m.vertices, "normals": m.normals, "colors": m.colors, "indices": m.indices,
		"collision": m.collision, "quad_count": m.quads, "cell_count": m.cells.size(),
		"skirt_quads": skirts, "local": local, "lod": step,
	}

## One chunk's build state. A RefCounted made and dropped inside one call, so a worker owns it alone.
class _Mesher extends RefCounted:
	var chunk_pos: Vector2i
	var origin_x := 0.0
	var origin_z := 0.0
	## The grid: `n` columns a side, `span` with the padding, `cell` metres apart, levels `grid` apart, the
	## density clamped to ±`clamp_d`. A full build is step 1 (one column per tile); a coarse one scales all four.
	var n := CHUNK_SIZE
	var span := SPAN
	var cell := TILE_SIZE
	var grid := GRID
	var clamp_d := CLAMP
	## Per column, indexed `(tz + PAD) * span + (tx + PAD)`: its natural runs, whether it is known (an
	## empty list is the streamed world's unknown column, read as air), the first sampled level and
	## the samples. Past either end of its samples a column's density is constant.
	var col_runs: Array = []
	var col_known := PackedByteArray()
	var col_lo := PackedInt32Array()
	var col_vals: Array = []
	var cells: Dictionary = {}   # cell key → vertex index
	var grads: Dictionary = {}   # sample key → density gradient
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var collision := PackedVector3Array()
	## Coarse builds only (`skirted`): per vertex, the chunk-edge planes it lies on (`SIDE_*` bits); a run's
	## own top vertex lies on none. A full build fills none of it.
	var skirted := false
	var sides := PackedByteArray()
	## Coarse builds only: per padding column one tile past the edge, the highest true tile beside it
	## (`VoxelCoarse.coarse_columns`' `edge_tops`); -INF where none is known.
	var pad_caps := PackedFloat64Array()
	var quads := 0

	const SIDE_WEST := 1
	const SIDE_EAST := 2
	const SIDE_NORTH := 4
	const SIDE_SOUTH := 8

	func _init(p_chunk: Vector2i, local: bool, step: int = 1) -> void:
		chunk_pos = p_chunk
		if not local:
			origin_x = chunk_pos.x * CHUNK_SIZE * TILE_SIZE
			origin_z = chunk_pos.y * CHUNK_SIZE * TILE_SIZE
		@warning_ignore("integer_division")
		n = CHUNK_SIZE / step
		span = n + 2 * PAD
		cell = TILE_SIZE * step
		grid = GRID * step
		clamp_d = CLAMP * step
		col_runs.resize(span * span)
		col_vals.resize(span * span)
		col_known.resize(span * span)
		col_lo.resize(span * span)

	## A full build's columns: every tile's natural runs, two tiles past the edge from the gathered ring.
	func load_tiles(heightmap: Array, runs: Dictionary, VoxelMesh: GDScript = null) -> void:
		if VoxelMesh == null:   # a test building one directly
			VoxelMesh = load("res://src/terrain/voxel_mesh.gd")
		for tz in range(-PAD, n + PAD):
			for tx in range(-PAD, n + PAD):
				var ci := (tz + PAD) * span + (tx + PAD)
				var column: Array = VoxelMesh._column_for_tile(chunk_pos, heightmap, runs, tx, tz)
				var natural: Array = []
				for run in column:
					if str(run.get("material", "")) == "":
						natural.append(run)
				col_runs[ci] = natural
				col_known[ci] = 1 if not column.is_empty() else 0
				_sample_column(ci, natural)

	## A coarse build's columns: one run from bedrock to each cell's top, in that cell's colours (a cell at
	## or below bedrock holds none). The padding repeats the nearest edge column; `edge_tops`, when given
	## ((n + 2)² row-major, the ring one cell out), caps the corners on the edge plane (`pad_caps`).
	func load_columns(cols: Dictionary) -> void:
		var tops: PackedFloat64Array = cols["tops"]
		var c_colors: PackedColorArray = cols["colors"]
		var top_colors: PackedColorArray = cols["top_colors"]
		var soil_colors: PackedColorArray = cols["soil_colors"]
		var soil_depths: PackedFloat64Array = cols["soil_depths"]
		for tz in range(n):
			for tx in range(n):
				var i := tz * n + tx
				var ci := (tz + PAD) * span + (tx + PAD)
				var runs: Array = []
				if tops[i] > BEDROCK_DEPTH:
					runs.append({ "bottom": BEDROCK_DEPTH, "top": tops[i], "color": c_colors[i],
						"top_color": top_colors[i], "soil_color": soil_colors[i], "soil_depth": soil_depths[i] })
				col_runs[ci] = runs
				col_known[ci] = 1
				_sample_column(ci, runs)
		for tz in range(-PAD, n + PAD):
			for tx in range(-PAD, n + PAD):
				if tx >= 0 and tx < n and tz >= 0 and tz < n:
					continue
				var ci := (tz + PAD) * span + (tx + PAD)
				var src := (clampi(tz, 0, n - 1) + PAD) * span + (clampi(tx, 0, n - 1) + PAD)
				col_runs[ci] = col_runs[src]
				col_known[ci] = col_known[src]
				col_lo[ci] = col_lo[src]
				col_vals[ci] = col_vals[src]
		pad_caps.resize(span * span)
		pad_caps.fill(-INF)
		var edge_tops: PackedFloat64Array = cols.get("edge_tops", PackedFloat64Array())
		if edge_tops.size() == (n + 2) * (n + 2):
			for tz in range(-1, n + 1):
				for tx in range(-1, n + 1):
					pad_caps[(tz + PAD) * span + (tx + PAD)] = edge_tops[(tz + 1) * (n + 2) + (tx + 1)]

	## Sample one column from `clamp_d` + one level below its lowest boundary to as far above its highest.
	func _sample_column(ci: int, runs: Array) -> void:
		var lo_y := INF
		var hi_y := -INF
		for run in runs:
			var top := float(run["top"])
			var bottom := float(run["bottom"])
			lo_y = minf(lo_y, top)
			hi_y = maxf(hi_y, top)
			if bottom > BEDROCK_DEPTH:
				lo_y = minf(lo_y, bottom)
				hi_y = maxf(hi_y, bottom)
		var vals := PackedFloat32Array()
		if lo_y == INF:   # no natural ground: air all the way (or an unknown column)
			col_lo[ci] = 0
			vals.append(clamp_d)
			col_vals[ci] = vals
			return
		var lo := floori((lo_y - clamp_d) / grid) - 1
		var hi := ceili((hi_y + clamp_d) / grid) + 1
		col_lo[ci] = lo
		vals.resize(hi - lo + 1)
		for j in range(lo, hi + 1):
			vals[j - lo] = density(runs, j * grid, clamp_d)
		col_vals[ci] = vals

	## The clamped signed vertical distance from `y` to the column's nearest natural boundary
	## (negative inside). The world's floor is not a boundary.
	static func density(runs: Array, y: float, limit: float = CLAMP) -> float:
		var best := limit
		for run in runs:
			var top := float(run["top"])
			var bottom := float(run["bottom"])
			var floor_open := bottom > BEDROCK_DEPTH
			# Inside is [bottom, top): a sample on a run's bottom is solid and one on its top is air, so a
			# 0.5 m slab or a 0.5 m gap always holds a sample of its own, wherever it sits on the grid.
			if y < top and (y >= bottom or not floor_open):
				var d := top - y
				if floor_open:
					d = minf(d, y - bottom)
				return -clampf(d, INSIDE_MIN, limit)
			if y >= top:
				best = minf(best, y - top)
			elif floor_open and y < bottom:
				best = minf(best, bottom - y)
		return best

	func _s(tx: int, tz: int, j: int) -> float:
		var ci := (tz + PAD) * span + (tx + PAD)
		var vals: PackedFloat32Array = col_vals[ci]
		return vals[clampi(j - col_lo[ci], 0, vals.size() - 1)]

	## Levels where a column's density can change: its sampled range (an unknown column has none).
	func _range(ci: int) -> Vector2i:
		if col_known[ci] == 0:
			return Vector2i(1, 0)
		return Vector2i(col_lo[ci], col_lo[ci] + (col_vals[ci] as PackedFloat32Array).size() - 1)

	func build() -> void:
		for tz in range(n):
			for tx in range(n):
				var ci := (tz + PAD) * span + (tx + PAD)
				var own := _range(ci)
				var vals: PackedFloat32Array = col_vals[ci]
				var lo := col_lo[ci]
				# Vertical edges: tops and undersides.
				for j in range(own.x, own.y):
					if (vals[j - lo] < 0.0) != (vals[j + 1 - lo] < 0.0):
						_y_quad(tx, tz, j)
				# Edges to the +X and +Z sample: walls and slopes steeper than a cell. A coarse build's ends
				# all land on the same corners (`_vertex`), so its upright quads would have no area.
				if skirted:
					continue
				_side_edges(tx, tz, ci, ci + 1, own, 0)
				_side_edges(tx, tz, ci, ci + span, own, 1)

	## The horizontal edges from column `ci` to its +X (`axis` 0) or +Z (1) neighbour `ni`, over the levels
	## either column's density changes on. Past both ranges they are constant, so nothing crosses there
	## that does not cross at the nearer end.
	func _side_edges(tx: int, tz: int, ci: int, ni: int, own: Vector2i, axis: int) -> void:
		var other := _range(ni)
		var lo := own.x
		var hi := own.y
		if other.x <= other.y:
			lo = mini(lo, other.x) if own.x <= own.y else other.x
			hi = maxi(hi, other.y) if own.x <= own.y else other.y
		if lo > hi:
			return
		var a_vals: PackedFloat32Array = col_vals[ci]
		var a_lo := col_lo[ci]
		var a_n := a_vals.size() - 1
		var b_vals: PackedFloat32Array = col_vals[ni]
		var b_lo := col_lo[ni]
		var b_n := b_vals.size() - 1
		for j in range(lo, hi + 1):
			var a := a_vals[clampi(j - a_lo, 0, a_n)]
			if (a < 0.0) != (b_vals[clampi(j - b_lo, 0, b_n)] < 0.0):
				if axis == 0:
					_x_quad(tx, tz, j, a < 0.0)
				else:
					_z_quad(tx, tz, j, a < 0.0)

	func _pos(sx: int, sz: int, j: int) -> Vector3:
		return Vector3((sx + 0.5) * cell, j * grid, (sz + 0.5) * cell)

	## The density's central-difference gradient at sample (sx, sz, j), memoised: a sample is a corner of
	## up to eight cells.
	func _gradient(sx: int, sz: int, j: int) -> Vector3:
		var key := ((j + LEVEL_OFFSET) * span + (sz + PAD)) * span + (sx + PAD)
		var found: Variant = grads.get(key)
		if found != null:
			return found
		var ci := (sz + PAD) * span + (sx + PAD)
		var vals: PackedFloat32Array = col_vals[ci]
		var lo := col_lo[ci]
		var last := vals.size() - 1
		var g := Vector3(
			_s(sx + 1, sz, j) - _s(sx - 1, sz, j),
			vals[clampi(j + 1 - lo, 0, last)] - vals[clampi(j - 1 - lo, 0, last)],
			_s(sx, sz + 1, j) - _s(sx, sz - 1, j))
		grads[key] = g
		return g

	## The vertex of cell (cx, cz, j), whose corners are samples cx..cx+1, cz..cz+1, j..j+1. Made on
	## first use: every cell a quad names holds a crossing, so it always has one. A coarse build pins every
	## level of a cell to one corner, so its key leaves the level out.
	func _vertex(cx: int, cz: int, j: int) -> int:
		var key := ((0 if skirted else j + LEVEL_OFFSET) * span + (cz + PAD)) * span + (cx + PAD)
		var found: Variant = cells.get(key)
		if found != null:
			return int(found)
		var v := PackedFloat32Array()
		v.resize(8)
		for k in 8:
			v[k] = _s(cx + (k & 1), cz + ((k >> 2) & 1), j + ((k >> 1) & 1))
		var sum := Vector3.ZERO
		var count := 0
		for e in _EDGES:
			var a: int = e[0]
			var b: int = e[1]
			if (v[a] < 0.0) == (v[b] < 0.0):
				continue
			var t := v[a] / (v[a] - v[b])
			sum += _corner(a).lerp(_corner(b), t)
			count += 1
		var u := sum / float(count) if count > 0 else Vector3(0.5, 0.5, 0.5)
		var p := _pos(cx, cz, j) + Vector3(u.x * cell, u.y * grid, u.z * cell)
		if skirted:
			# Coarse: the vertex sits on the corner the four cells share, as high as the tallest of them (and,
			# on the edge plane, the neighbours' tiles beside it), at every level. A cell is its tiles'
			# highest, so the fan over each cell (its own top in the middle, corners at or above it) never
			# dips under a true tile.
			var cap := p.y
			for k in 4:
				var ci := (cz + (k >> 1) + PAD) * span + (cx + (k & 1) + PAD)
				cap = maxf(cap, pad_caps[ci])
				for run in col_runs[ci]:
					cap = maxf(cap, float(run["top"]))
			p = Vector3((cx + 1) * cell, cap, (cz + 1) * cell)
		# Trilinear blend of the eight corners' gradients at the vertex.
		var g := Vector3.ZERO
		for k in 8:
			var dx := k & 1
			var dy := (k >> 1) & 1
			var dz := (k >> 2) & 1
			var w := (u.x if dx == 1 else 1.0 - u.x) * (u.y if dy == 1 else 1.0 - u.y) * (u.z if dz == 1 else 1.0 - u.z)
			if w > 0.0:
				g += _gradient(cx + dx, cz + dz, j + dy) * w
		var color := _cell_color(cx, cz, p, u)
		var side := 0
		if skirted:
			if cx == -1:
				side |= SIDE_WEST
			elif cx == n - 1:
				side |= SIDE_EAST
			if cz == -1:
				side |= SIDE_NORTH
			elif cz == n - 1:
				side |= SIDE_SOUTH
		var idx := _add_vertex(p, g, color, side)
		cells[key] = idx
		return idx

	## A unit-cube corner (x, y, z each 0 or 1) from its bit index: bit 0 x, bit 1 y, bit 2 z.
	static func _corner(k: int) -> Vector3:
		return Vector3(k & 1, (k >> 1) & 1, (k >> 2) & 1)

	func _add_vertex(p: Vector3, g: Vector3, color: Color, side: int = 0) -> int:
		vertices.append(Vector3(p.x + origin_x, p.y, p.z + origin_z))
		normals.append(g.normalized() if g.length_squared() > 1e-12 else Vector3.UP)
		colors.append(color)
		if skirted:
			sides.append(side)
		return vertices.size() - 1

	## The colour of the natural column nearest the vertex, at the vertex's height.
	func _cell_color(cx: int, cz: int, p: Vector3, u: Vector3) -> Color:
		var order := [Vector2i(roundi(u.x), roundi(u.z)), Vector2i(roundi(u.x), 1 - roundi(u.z)),
			Vector2i(1 - roundi(u.x), roundi(u.z)), Vector2i(1 - roundi(u.x), 1 - roundi(u.z))]
		for o in order:
			var runs: Array = col_runs[(cz + o.y + PAD) * span + (cx + o.x + PAD)]
			if not runs.is_empty():
				return color_at(runs, p.y)
		return FALLBACK_TERRAIN_COLOR

	## A run's colour at height `y`: the top tint near its top, then soil, then rock.
	static func color_at(runs: Array, y: float) -> Color:
		var best: Dictionary = runs[0]
		var best_d := INF
		for run in runs:
			var d := maxf(maxf(float(run["bottom"]) - y, y - float(run["top"])), 0.0)
			if d < best_d:
				best_d = d
				best = run
		var color: Color = best.get("color", FALLBACK_TERRAIN_COLOR)
		var top := float(best["top"])
		if y >= top - TOP_BAND:
			return best.get("top_color", color)
		if y >= top - float(best.get("soil_depth", 0.0)):
			return best.get("soil_color", color)
		return color

	## A vertical edge crossed between levels j and j+1 of column (tx, tz): a fan of four triangles
	## around the column's own vertex, at the run's exact boundary, over the four cells round the edge.
	func _y_quad(tx: int, tz: int, j: int) -> void:
		var below := _s(tx, tz, j)
		var above := _s(tx, tz, j + 1)
		var up := below < 0.0   # solid below: a top facing up
		var runs: Array = col_runs[(tz + PAD) * span + (tx + PAD)]
		var y0 := j * grid
		var y := y0 + grid * (below / (below - above))
		var color := FALLBACK_TERRAIN_COLOR
		var found := 0
		for run in runs:
			var b := float(run["top"]) if up else float(run["bottom"])
			if b > y0 and b <= y0 + grid and (up or b > BEDROCK_DEPTH):
				found += 1
				y = b
				var c: Color = run.get("color", FALLBACK_TERRAIN_COLOR)
				color = run.get("top_color", c) if up else c
		if found != 1:
			color = color_at(runs, y) if not runs.is_empty() else FALLBACK_TERRAIN_COLOR
		var t := clampf((y - y0) / grid, 0.0, 1.0)
		var g := _gradient(tx, tz, j).lerp(_gradient(tx, tz, j + 1), t)
		var centre := _add_vertex(Vector3((tx + 0.5) * cell, y, (tz + 0.5) * cell), g, color)
		# Round the edge: (-x,-z) → (+x,-z) → (+x,+z) → (-x,+z) winds facing down.
		var ring := [_vertex(tx - 1, tz - 1, j), _vertex(tx, tz - 1, j), _vertex(tx, tz, j), _vertex(tx - 1, tz, j)]
		if up:
			ring.reverse()
		for k in 4:
			_tri(centre, ring[k], ring[(k + 1) % 4])
		quads += 1

	## The edge from sample (tx, tz, j) to (tx+1, tz, j). `solid_first`: the -X sample is the solid one,
	## so the face looks +X.
	func _x_quad(tx: int, tz: int, j: int, solid_first: bool) -> void:
		# (z-, y-) → (z+, y-) → (z+, y+) → (z-, y+) winds facing -X.
		var ring := [_vertex(tx, tz - 1, j - 1), _vertex(tx, tz, j - 1), _vertex(tx, tz, j), _vertex(tx, tz - 1, j)]
		if solid_first:
			ring.reverse()
		_quad(ring)

	## The edge from sample (tx, tz, j) to (tx, tz+1, j); `solid_first` makes it face +Z.
	func _z_quad(tx: int, tz: int, j: int, solid_first: bool) -> void:
		# (x-, y-) → (x+, y-) → (x+, y+) → (x-, y+) winds facing +Z.
		var ring := [_vertex(tx - 1, tz, j - 1), _vertex(tx, tz, j - 1), _vertex(tx, tz, j), _vertex(tx - 1, tz, j)]
		if not solid_first:
			ring.reverse()
		_quad(ring)

	func _quad(ring: Array) -> void:
		_tri(ring[0], ring[1], ring[2])
		_tri(ring[0], ring[2], ring[3])
		quads += 1

	## One triangle, wound so `(b - a) × (c - a)` faces out (the block mesher's convention).
	func _tri(a: int, b: int, c: int) -> void:
		indices.append(a)
		indices.append(b)
		indices.append(c)
		collision.append(vertices[a])
		collision.append(vertices[b])
		collision.append(vertices[c])

	## Phase 241 — a skirt under every triangle edge that lies along a chunk-edge plane: a quad from the
	## edge down to bedrock, facing out of the chunk, in the upper end's colour. An edge standing upright on
	## the plane has no width and drops none. The edge's ends stand on cell corners as high as the tallest
	## column round them and the neighbours' edge tiles beside them (`_vertex`, `pad_caps`), so a full
	## neighbour's border ground, which blends its first tile with ours, never stands above the skirt.
	## Returns the skirt quads made.
	func add_skirts() -> int:
		var made := 0
		var seen: Dictionary = {}
		var tri_end := indices.size()
		var vcount := vertices.size()
		for t in range(0, tri_end, 3):
			for e in 3:
				var a := indices[t + e]
				var b := indices[t + (e + 1) % 3]
				var common := sides[a] & sides[b]
				if common == 0:
					continue
				for side: int in [SIDE_WEST, SIDE_EAST, SIDE_NORTH, SIDE_SOUTH]:
					if common & side == 0:
						continue
					var key := (mini(a, b) * vcount + maxi(a, b)) * 16 + side
					if seen.has(key):
						continue
					seen[key] = true
					if _skirt(a, b, side):
						made += 1
		return made

	func _skirt(a: int, b: int, side: int) -> bool:
		var pa := vertices[a]
		var pb := vertices[b]
		var along := (pb.z - pa.z) if side == SIDE_WEST or side == SIDE_EAST else (pb.x - pa.x)
		if absf(along) < 1e-6:
			return false
		# (a, b, b↓, a↓) faces +X when b is further along +Z, -Z when b is further along +X.
		var flip := along < 0.0
		if side == SIDE_WEST or side == SIDE_SOUTH:
			flip = not flip
		if flip:
			var swap := pa
			pa = pb
			pb = swap
			var ia := a
			a = b
			b = ia
		var normal := Vector3(-1, 0, 0) if side == SIDE_WEST else (Vector3(1, 0, 0) if side == SIDE_EAST
			else (Vector3(0, 0, -1) if side == SIDE_NORTH else Vector3(0, 0, 1)))
		if pa.y <= BEDROCK_DEPTH and pb.y <= BEDROCK_DEPTH:
			return false   # nothing above the floor to cover
		var color := colors[a] if pa.y >= pb.y else colors[b]
		var base := vertices.size()
		for p in [pa, pb, Vector3(pb.x, BEDROCK_DEPTH, pb.z), Vector3(pa.x, BEDROCK_DEPTH, pa.z)]:
			vertices.append(p)
			normals.append(normal)
			colors.append(color)
			sides.append(0)
		# A skirt with one end on the floor is one triangle (the other would have no area).
		if pb.y > BEDROCK_DEPTH:
			_tri(base, base + 1, base + 2)
		if pa.y > BEDROCK_DEPTH:
			_tri(base, base + 2, base + 3)
		quads += 1
		return true

## The twelve edges of a cell as pairs of corner bits (bit 0 x, bit 1 y, bit 2 z).
const _EDGES := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]
