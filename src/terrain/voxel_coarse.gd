extends RefCounted
## Phase 190 — coarse chunk builds for the ground beyond the near ring.
##
## A full build resolves all 66×66 tiles of a chunk and its ring (edits, ore field, topsoil, biome dither)
## and greedy-meshes 64×64 columns of 0.5 m: about 21 ms of worker time per chunk with the native builder,
## of which the heightmap is under 1 ms. Most of the 9×9 window is ground the player only looks at, so it
## is built from one column per cell of `step`×`step` tiles: 32×32 cells of 1 m (`step` 2) or 16×16 cells
## of 2 m (`step` 4). The heightmap is still the full one (it is cheap, and every height query, neighbour
## seam and spawn reads it), but only one tile per cell is resolved and meshed.
##
## Rules, each one there for the seam with a neighbour built at another level:
##   * A cell stands at the HIGHEST of its tiles' natural tops, and wears that tile's biome colours: its host
##     rock (iced toward the poles) and the topsoil of the biome it shows (the dithered border band
##     included), as a full build colours an unveined tile. The ore field is not read: a rare vein showing
##     at the surface is a few tiles across, a single coarse cell would only flicker with it, and its lookup
##     was most of a coarse build's cost. Veins show once the chunk is upgraded. Coarse ground never dips below
##     the true surface: at a chunk edge it is at least as high as every true column on its side, which is
##     the height a full neighbour subtracts its own walls against.
##   * Every cell on the chunk's edge reads the chunk outside as UNKNOWN, so it emits its whole outward wall
##     from bedrock to its top: a skirt. A full neighbour's walls cover what is above the coarse side's true
##     edge, the skirt covers everything below the coarse top, and the two meet, so no gap opens between
##     levels whatever order they were built in. Two coarse neighbours both skirt.
##   * No deposits, no edits, and only a conservative collision: the same quads as a triangle soup, so a
##     body on coarse ground stands at or above the true surface, never inside it. It is parked like a full
##     chunk's (Phase 189) and attached only where the near ring wants collision before the full build lands
##     (in practice, under a fast flyer, whose chunk is not upgraded until it slows). A chunk with an edit
##     is always built at full detail (`NearRing.lod_for`), so a placed block never vanishes at a distance.
##
## Pure and static (no node state), so it runs on a worker. `build_coarse_arrays` routes the native port
## when the extension has it; `build_coarse_arrays_gd` is the reference the parity suite compares.

const VoxelSlice := preload("res://src/terrain/voxel_slice.gd")
const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")
const NativeBuilder := preload("res://src/terrain/native_builder.gd")
const OreField := preload("res://src/terrain/ore_field.gd")
const CHUNK_SIZE := VoxelConsts.CHUNK_SIZE
const TILE_SIZE := VoxelConsts.TILE_SIZE
const BEDROCK_DEPTH := VoxelConsts.BEDROCK_DEPTH
const FALLBACK_TERRAIN_COLOR := VoxelConsts.FALLBACK_TERRAIN_COLOR

## The level of a full build: one cell per tile.
const FULL := 1
## The coarse levels, in tiles per cell side: 32×32 cells of 1 m, then 16×16 cells of 2 m.
const STEPS: Array[int] = [2, 4]

## The chunk's coarse arrays at `step` (one of `STEPS`). `input` carries the build's `biomes` (edits,
## neighbour maps and the ore field's inputs are not read). `local` as in
## `VoxelMesh.build_chunk_arrays`.
static func build_coarse_arrays(chunk_pos: Vector2i, heightmap: Array, input: Dictionary, step: int, local: bool = true) -> Dictionary:
	if NativeBuilder.use_native("build_coarse_arrays"):
		var native := NativeBuilder.builder().call("build_coarse_arrays", chunk_pos, heightmap, input, step, local, VoxelSlice.native_runs_cfg()) as Dictionary
		if native.has("vertices"):   # a rejected input comes back empty: use the reference
			return native
	return build_coarse_arrays_gd(chunk_pos, heightmap, input, step, local)

## The GDScript reference of `build_coarse_arrays`.
static func build_coarse_arrays_gd(chunk_pos: Vector2i, heightmap: Array, input: Dictionary, step: int, local: bool = true) -> Dictionary:
	return mesh_columns(chunk_pos, coarse_columns(chunk_pos, heightmap, input, step), step, local)

## One resolved column per cell, row-major: `tops` (the highest natural top of the cell's tiles), and the
## `colors`, `top_colors`, `soil_colors` and `soil_depths` of that tile's biome (see the header). The first
## tile in row-major order wins a tie.
static func coarse_columns(chunk_pos: Vector2i, heightmap: Array, input: Dictionary, step: int) -> Dictionary:
	@warning_ignore("integer_division")
	var n := CHUNK_SIZE / step
	var biomes: Dictionary = input.get("biomes", {})
	var styles := {}
	var tops := PackedFloat64Array()
	var colors := PackedColorArray()
	var top_colors := PackedColorArray()
	var soil_colors := PackedColorArray()
	var soil_depths := PackedFloat64Array()
	for cz in range(n):
		for cx in range(n):
			var best := -INF
			var btx := 0
			var btz := 0
			for dz in range(step):
				for dx in range(step):
					var tx := cx * step + dx
					var tz := cz * step + dz
					var h := VoxelConsts.voxel_height(float(heightmap[tz * CHUNK_SIZE + tx]))
					if h > best:
						best = h
						btx = tx
						btz = tz
			tops.append(best)
			if best <= BEDROCK_DEPTH:
				colors.append(FALLBACK_TERRAIN_COLOR)
				top_colors.append(FALLBACK_TERRAIN_COLOR)
				soil_colors.append(FALLBACK_TERRAIN_COLOR)
				soil_depths.append(0.0)
				continue
			var gx := chunk_pos.x * CHUNK_SIZE + btx
			var gz := chunk_pos.y * CHUNK_SIZE + btz
			var world_xz := Vector2(gx * TILE_SIZE + TILE_SIZE * 0.5, gz * TILE_SIZE + TILE_SIZE * 0.5)
			var biome := VoxelSlice.biome_of(world_xz, biomes)
			var color := VoxelSlice.icy(VoxelSlice._material_color(OreField.host_material(biome)), world_xz.y)
			var shown := VoxelSlice.blended_biome(world_xz, biomes, biome)
			if not styles.has(shown):
				styles[shown] = VoxelSlice.surface_style(shown)
			var style: Dictionary = styles[shown]
			colors.append(color)
			if style.is_empty():
				top_colors.append(color)
				soil_colors.append(color)
				soil_depths.append(0.0)
			else:
				top_colors.append(VoxelSlice.icy(style["top"], world_xz.y))
				soil_colors.append(VoxelSlice.icy(style["soil"], world_xz.y))
				soil_depths.append(float(style["depth"]))
	return { "tops": tops, "colors": colors, "top_colors": top_colors, "soil_colors": soil_colors, "soil_depths": soil_depths }

const _DIRS := [["north", 0, -1], ["south", 0, 1], ["west", -1, 0], ["east", 1, 0]]

## Greedy-mesh `cols` (from `coarse_columns`) on its n×n grid: a top per cell, and walls where a cell
## stands above its neighbour, or a skirt down to bedrock on the chunk's edge (see the header).
## The faces are grouped and merged as `VoxelMesh` does (same key, same insertion order, same sweep), and
## emitted with the same winding, at the cell's size.
static func mesh_columns(chunk_pos: Vector2i, cols: Dictionary, step: int, local: bool) -> Dictionary:
	@warning_ignore("integer_division")
	var n := CHUNK_SIZE / step
	var cell := TILE_SIZE * step
	var origin_x := 0.0 if local else float(chunk_pos.x * CHUNK_SIZE) * TILE_SIZE
	var origin_z := 0.0 if local else float(chunk_pos.y * CHUNK_SIZE) * TILE_SIZE
	var tops: PackedFloat64Array = cols["tops"]
	var colors: PackedColorArray = cols["colors"]
	var soil_colors: PackedColorArray = cols["soil_colors"]
	var soil_depths: PackedFloat64Array = cols["soil_depths"]
	var top_colors: PackedColorArray = cols["top_colors"]
	var groups: Dictionary = {}
	for cz in range(n):
		for cx in range(n):
			var i := cz * n + cx
			var top := tops[i]
			if top <= BEDROCK_DEPTH:
				continue
			_group(groups, "up", top, top, top, top_colors[i], i)
			var soil_line := top - soil_depths[i]
			for d in _DIRS:
				var nx: int = cx + int(d[1])
				var nz: int = cz + int(d[2])
				var bottom := BEDROCK_DEPTH
				if nx >= 0 and nx < n and nz >= 0 and nz < n:
					bottom = maxf(BEDROCK_DEPTH, tops[nz * n + nx])
				if top <= bottom:
					continue
				var dir: String = d[0]
				var plane := _plane(dir, cx, cz, cell, origin_x, origin_z)
				if top <= soil_line:
					_group(groups, dir, plane, bottom, top, colors[i], i)
				elif bottom >= soil_line:
					_group(groups, dir, plane, bottom, top, soil_colors[i], i)
				else:
					_group(groups, dir, plane, bottom, soil_line, colors[i], i)
					_group(groups, dir, plane, soil_line, top, soil_colors[i], i)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var out_colors := PackedColorArray()
	var indices := PackedInt32Array()
	var collision := PackedVector3Array()
	var quad_count := 0
	var cell_count := 0
	for dir in groups:
		var buckets: Dictionary = groups[dir]
		for key in buckets:
			var g: Dictionary = buckets[key]
			cell_count += (g["cells"] as Dictionary).size()
			for rect in merge_rects(g["cells"], n):
				_emit(vertices, normals, out_colors, indices, collision, g, rect, cell, origin_x, origin_z)
				quad_count += 1
	return {
		"vertices":   vertices,
		"normals":    normals,
		"colors":     out_colors,
		"indices":    indices,
		"collision":  collision,
		"quad_count": quad_count,
		"cell_count": cell_count,
		"local":      local,
		"lod":        step,
	}

## The coordinate a coarse wall's plane sits at, in the build's own frame (chunk-local or absolute).
static func _plane(dir: String, cx: int, cz: int, cell: float, origin_x: float, origin_z: float) -> float:
	match dir:
		"north": return origin_z + cz * cell
		"south": return origin_z + (cz + 1) * cell
		"west":  return origin_x + cx * cell
	return origin_x + (cx + 1) * cell

## `VoxelMesh.group_cell`, on the coarse grid's cell index.
static func _group(groups: Dictionary, dir: String, plane: float, bottom: float, top: float, color: Color, idx: int) -> void:
	var buckets: Dictionary = groups.get(dir, {})
	var key := Vector4i(roundi(plane * 10000.0), roundi(bottom * 10000.0), roundi(top * 10000.0), color.to_rgba32())
	var g: Dictionary = buckets.get(key, {})
	if g.is_empty():
		g = { "dir": dir, "plane": plane, "bottom": bottom, "top": top, "color": color, "cells": {} }
		buckets[key] = g
		groups[dir] = buckets
	g["cells"][idx] = true

## `VoxelMesh.merge_rects` on an n×n grid.
static func merge_rects(cells: Dictionary, n: int) -> Array:
	var out: Array = []
	var used: Dictionary = {}
	var order: Array = cells.keys()
	order.sort()
	for idx in order:
		if used.has(idx):
			continue
		var tx: int = int(idx) % n
		@warning_ignore("integer_division")
		var tz: int = int(idx) / n
		var w := 1
		while tx + w < n and cells.has(tz * n + tx + w) and not used.has(tz * n + tx + w):
			w += 1
		var h := 1
		while tz + h < n:
			var complete := true
			for dx in range(w):
				var probe := (tz + h) * n + tx + dx
				if not cells.has(probe) or used.has(probe):
					complete = false
					break
			if not complete:
				break
			h += 1
		for dz in range(h):
			for dx in range(w):
				used[(tz + dz) * n + tx + dx] = true
		out.append({ "tx": tx, "tz": tz, "w": w, "h": h })
	return out

## `VoxelMesh._emit_rect` at the cell's size.
static func _emit(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, collision: PackedVector3Array, g: Dictionary, rect: Dictionary, cell: float, origin_x: float, origin_z: float) -> void:
	var bottom := float(g["bottom"])
	var top := float(g["top"])
	var plane := float(g["plane"])
	var x0 := origin_x + int(rect["tx"]) * cell
	var x1 := x0 + int(rect["w"]) * cell
	var z0 := origin_z + int(rect["tz"]) * cell
	var z1 := z0 + int(rect["h"]) * cell
	var a := Vector3.ZERO
	var b := Vector3.ZERO
	var c := Vector3.ZERO
	var d := Vector3.ZERO
	var normal := Vector3.UP
	match str(g["dir"]):
		"up":
			a = Vector3(x0, plane, z0); b = Vector3(x0, plane, z1)
			c = Vector3(x1, plane, z1); d = Vector3(x1, plane, z0)
		"north":
			normal = Vector3(0, 0, -1)
			a = Vector3(x0, top, plane); b = Vector3(x1, top, plane)
			c = Vector3(x1, bottom, plane); d = Vector3(x0, bottom, plane)
		"south":
			normal = Vector3(0, 0, 1)
			a = Vector3(x1, top, plane); b = Vector3(x0, top, plane)
			c = Vector3(x0, bottom, plane); d = Vector3(x1, bottom, plane)
		"west":
			normal = Vector3(-1, 0, 0)
			a = Vector3(plane, top, z1); b = Vector3(plane, top, z0)
			c = Vector3(plane, bottom, z0); d = Vector3(plane, bottom, z1)
		_:
			normal = Vector3(1, 0, 0)
			a = Vector3(plane, top, z0); b = Vector3(plane, top, z1)
			c = Vector3(plane, bottom, z1); d = Vector3(plane, bottom, z0)
	var base := vertices.size()
	var color: Color = g["color"]
	for v in [a, b, c, d]:
		vertices.append(v)
		normals.append(normal)
		colors.append(color)
	indices.append(base); indices.append(base + 1); indices.append(base + 2)
	indices.append(base); indices.append(base + 2); indices.append(base + 3)
	collision.append(a); collision.append(b); collision.append(c)
	collision.append(a); collision.append(c); collision.append(d)
