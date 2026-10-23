extends RefCounted
## The pure, thread-safe half of the terrain mesh build, extracted from `VoxelSlice` (Phase 154).
## `VoxelSlice.build_chunk_arrays` forwards here; nothing in this file touches node state.

const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")
const VoxelRuns := preload("res://src/terrain/voxel_runs.gd")
const MeshUtil := preload("res://src/core/mesh_util.gd")
const NativeBuilder := preload("res://src/terrain/native_builder.gd")
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const CHUNK_SIZE := VoxelConsts.CHUNK_SIZE
const TILE_SIZE := VoxelConsts.TILE_SIZE
const STEP_HEIGHT := VoxelConsts.STEP_HEIGHT
const BEDROCK_DEPTH := VoxelConsts.BEDROCK_DEPTH
const MAX_HEIGHT := VoxelConsts.MAX_HEIGHT
const FALLBACK_TERRAIN_COLOR := VoxelConsts.FALLBACK_TERRAIN_COLOR

## PURE chunk build — no node, no bus, no slice state, so it is legal to run on a
## worker thread. Everything it touches arrives as an argument.
##
##   chunk_pos : the chunk to build
##   heightmap : the chunk's own base heightmap
##   resolved  : the resolve result from `collect_build_runs`, i.e.
##               `{ "runs": <tile → runs table>, "deposits": [...] }`. A tile ABSENT from
##               the runs table falls back to the NATURAL column derived from `heightmap`,
##               which is what lets a caller holding only a map (the suite, a fresh probe)
##               build a chunk with no slice state at all; a PRESENT but EMPTY list is the
##               streamed world's UNKNOWN column. Phase 42 review pass 9 — the payload shape
##               is now REQUIRED rather than sniffed: the old fallback was
##               `resolved.get("runs", resolved)`, i.e. "does this dictionary happen to hold a
##               key called runs?", which silently reinterpreted a bare runs table as a
##               payload. Every caller in the tree passes a `collect_build_runs()` payload —
##               the only bare tables were the `{}`-for-natural probes, now `{ "runs": {} }` —
##               so the sniff is gone and an absent `runs` key reads as NO resolved columns,
##               which is the natural-column fallback (see `_column_for_cell`).
##
## Returns `{ vertices, normals, colors, indices, collision, quad_count, cell_count }`
## — the four arrays an ArrayMesh surface wants, plus the triangle soup the collision
## uses, built from the SAME quads so what the player sees and what they stand on
## cannot drift. `cell_count` is the faces a per-tile mesher would have emitted and
## `quad_count` is what the merge left, so the merge's effect is a number, not a claim.
##
## Phase 42 review pass 8 — and the rare-vein deposit BOXES are emitted here too, as
## `deposit_vertices` / `deposit_normals` / `deposit_colors` / `deposit_indices`. They are
## GEOMETRY ONLY: they never enter `collision`, because a deposit is decoration the player
## must not be able to stand on. Resolving the list is the main thread's job (it reads the
## edit log); turning it into triangles is not, so this is where the boxes are built.
##
## STATIC on purpose: the per-chunk faces are the same for every world, so the builder
## needs no instance state — and a worker task may hold no reference to a Node at all
## (a task that outlives the tree would otherwise call into a freed slice). Callers
## pass the script itself, not the wired slice (see ChunkManager.VoxelBuilder).
##
## The quads are GREEDY-MERGED: adjacent coplanar faces of one colour become a single
## rectangle, so a chunk whose surface is largely uniform emits a handful of quads
## instead of one per tile (4096 of them at TILE_SIZE 0.5). UVs are dropped with the
## merge — the terrain's material is per-vertex colour with no texture, and a merged
## rectangle has no per-tile UV mapping left to give.
##
## `local` builds every vertex relative to the chunk's own corner (the node is then placed at the corner,
## see `build_chunk`): float32 vertices in absolute metres snap to whole metres a few million metres out.
## The default keeps absolute coordinates, which is what the suite's seam probes read.
static func build_chunk_arrays(chunk_pos: Vector2i, heightmap: Array, resolved: Dictionary, local: bool = false) -> Dictionary:
	if NativeBuilder.use_native("build_chunk_arrays"):   # Phase 169: same arrays, built in C++
		var native := NativeBuilder.builder().call("build_chunk_arrays", chunk_pos, heightmap, resolved, local, native_arrays_cfg()) as Dictionary
		if native.has("vertices"):   # a rejected input (malformed table) comes back empty: use the reference
			return native
	return build_chunk_arrays_gd(chunk_pos, heightmap, resolved, local)

## What the native `build_chunk_arrays` cannot read itself. Not memoised: the circumference follows the
## world configuration, and the dictionary is two entries.
static func native_arrays_cfg() -> Dictionary:
	return { "circumference_chunks": TerrainSlice.circumference_chunks(), "fallback_color": FALLBACK_TERRAIN_COLOR }

## The GDScript reference of `build_chunk_arrays`: the fallback and the parity suite's baseline.
static func build_chunk_arrays_gd(chunk_pos: Vector2i, heightmap: Array, resolved: Dictionary, local: bool = false) -> Dictionary:
	var corner_x := chunk_pos.x * CHUNK_SIZE * TILE_SIZE
	var corner_z := chunk_pos.y * CHUNK_SIZE * TILE_SIZE
	var origin_x := 0.0 if local else corner_x
	var origin_z := 0.0 if local else corner_z
	var runs: Dictionary = resolved.get("runs", {})
	var deposits: Array = resolved.get("deposits", [])

	# dir → emit-key → the group of tile cells that would emit the IDENTICAL face: the
	# same direction, plane, vertical span and colour. Merging only ever happens INSIDE a
	# group, which is what makes the key exactly the set of attributes a merged quad has
	# to share (direction, geometry, material/colour). Nested per DIRECTION so the key
	# itself fits: see `group_cell` for why it is not one string any more.
	var groups: Dictionary = {}

	for tz in range(CHUNK_SIZE):
		for tx in range(CHUNK_SIZE):
			var col := _column_for_cell(chunk_pos, heightmap, runs, tx, tz)
			if col.is_empty():
				continue
			for run in col:
				var rbottom := float(run["bottom"])
				var rtop := float(run["top"])
				var color: Color = run.get("color", FALLBACK_TERRAIN_COLOR)

				# Top face — only where nothing is solid directly above this run, so the
				# natural ground under a placed block stays hidden (and a ledge under an
				# overhang still shows).
				if not VoxelRuns.runs_cover_y(col, rtop + STEP_HEIGHT * 0.5):
					group_cell(groups, "up", rtop, rtop, rtop, run.get("top_color", color), tx, tz)

				# Underside face — the CEILING of a tunnel, or an overhang. The span below
				# the run is empty per-column, which is the per-column reading of "a
				# neighbour run ends above the local run". The base run never emits one:
				# BEDROCK_DEPTH is the world's floor, not a gap.
				if rbottom > BEDROCK_DEPTH and not VoxelRuns.runs_cover_y(col, rbottom - STEP_HEIGHT * 0.5):
					group_cell(groups, "down", rbottom, rbottom, rbottom, color, tx, tz)

				# Side walls — every part of this run the neighbour does NOT fill.
				# Subtracting per neighbour is what keeps a higher neighbour's own wall
				# (it emits that one) from being drawn twice, and what lets a wall span a
				# tunnel's height in one piece.
				_wall_cells(groups, chunk_pos, heightmap, runs, tx, tz, run, color,
					run.get("soil_color", color), rtop - float(run.get("soil_depth", 0.0)))

	var vertices  := PackedVector3Array()
	var normals   := PackedVector3Array()
	var colors    := PackedColorArray()
	var indices   := PackedInt32Array()
	var collision := PackedVector3Array()
	var quad_count := 0
	# `cell_count` is the number of faces BEFORE the merge — i.e. exactly what the
	# per-tile mesher emitted, one quad per tile per face. Kept in the result so the
	# merge's effect is a number a test can assert and a reviewer can quote, rather
	# than a claim in a comment.
	var cell_count := 0
	for dir in groups:
		var buckets: Dictionary = groups[dir]
		for key in buckets:
			var g: Dictionary = buckets[key]
			cell_count += g["cells"].size()
			for rect in merge_rects(g["cells"]):
				quad_count += _emit_rect(vertices, normals, colors, indices, collision,
					g, rect, origin_x, origin_z, corner_x - origin_x, corner_z - origin_z)
	# The rare-vein deposit boxes (see the docstring): geometry only, never collision.
	# Off the resolved list, so this half of the build is the worker's.
	var deposit_vertices := PackedVector3Array()
	var deposit_normals  := PackedVector3Array()
	var deposit_colors   := PackedColorArray()
	var deposit_indices  := PackedInt32Array()
	for deposit in deposits:
		MeshUtil.add_box_arrays(deposit_vertices, deposit_normals, deposit_colors, deposit_indices,
			deposit["local_position"] if local else deposit["position"], deposit["size"], deposit["color"])
	return {
		"vertices":    vertices,
		"normals":     normals,
		"colors":      colors,
		"indices":     indices,
		"collision":   collision,
		"quad_count":  quad_count,
		"cell_count":  cell_count,
		"deposit_vertices": deposit_vertices,
		"deposit_normals":  deposit_normals,
		"deposit_colors":   deposit_colors,
		"deposit_indices":  deposit_indices,
		"local":       local,
	}

## Queue this run's exposed side walls against all four neighbours. The NEIGHBOUR
## column comes from the same table the builder was handed — an EMPTY list is the
## UNKNOWN neighbour, so this side emits its whole facing wall (see `_neighbour_runs`
## for why that is the order-independent choice).
static func _wall_cells(groups: Dictionary, chunk_pos: Vector2i, heightmap: Array, runs: Dictionary, tx: int, tz: int, run: Dictionary, color: Color, soil_color: Color = Color.BLACK, soil_line: float = INF) -> void:
	var dirs: Array = [
		{ "dir": "north", "ntx": tx,     "ntz": tz - 1 },
		{ "dir": "south", "ntx": tx,     "ntz": tz + 1 },
		{ "dir": "west",  "ntx": tx - 1, "ntz": tz     },
		{ "dir": "east",  "ntx": tx + 1, "ntz": tz     },
	]
	for d in dirs:
		var dir := str(d["dir"])
		var neighbour := _column_for_tile(chunk_pos, heightmap, runs, int(d["ntx"]), int(d["ntz"]))
		for seg in VoxelRuns.subtract_runs(run, neighbour):
			var bottom := float(seg["bottom"])
			var top := float(seg["top"])
			if top <= bottom:
				continue
			var plane := _wall_plane(chunk_pos, dir, tx, tz)
			# Soil above the soil line, rock below it (soil_line is INF with no topsoil, so
			# the whole wall is the run's colour).
			if soil_line == INF or top <= soil_line:
				group_cell(groups, dir, plane, bottom, top, color, tx, tz)
			elif bottom >= soil_line:
				group_cell(groups, dir, plane, bottom, top, soil_color, tx, tz)
			else:
				group_cell(groups, dir, plane, bottom, soil_line, color, tx, tz)
				group_cell(groups, dir, plane, soil_line, top, soil_color, tx, tz)

## The world coordinate a wall's plane sits at — its grouping coordinate, so two tiles'
## walls only ever merge when they are actually coplanar.
static func _wall_plane(chunk_pos: Vector2i, dir: String, tx: int, tz: int) -> float:
	match dir:
		"north": return chunk_pos.y * CHUNK_SIZE * TILE_SIZE + tz * TILE_SIZE
		"south": return chunk_pos.y * CHUNK_SIZE * TILE_SIZE + (tz + 1) * TILE_SIZE
		"west":  return chunk_pos.x * CHUNK_SIZE * TILE_SIZE + tx * TILE_SIZE
	return chunk_pos.x * CHUNK_SIZE * TILE_SIZE + (tx + 1) * TILE_SIZE

## Add one tile cell to the group of faces it would emit, inside its DIRECTION's bucket.
## The key carries everything a merged quad has to share: plane, vertical span and colour.
##
## Phase 42 review pass 8 — this used to build a STRING key (`"%s|%.4f|%.4f|%.4f|%s"` plus
## `Color.to_html`), i.e. three float formattings and a hex colour string per face cell —
## roughly 25k throwaway strings for one 64×64 chunk, on the builder's own (worker) budget
## and again on every edit rebuild. The key is now a `Vector4i` of the same four values
## QUANTISED to 1/10000, which is exactly the precision `%.4f` kept, so the grouping is
## identical — no span merges that did not merge before. The three GEOMETRY components fit
## int32 by a wide margin: a wall plane is a multiple of TILE_SIZE 0.5 and bounded by the
## world extent (|plane·10⁴| ≤ 4.1e7), and a run's span is bounded by
## BEDROCK_DEPTH..MAX_HEIGHT (|y·10⁴| ≤ 6.4e6).
##
## Phase 42 review pass 9 — the fourth component does NOT fit, and the old comment claimed it
## did ("`to_rgba32()` is an int32 by definition"): it is a packed uint32, so opaque white is
## `4294967295`, while `Vector4i` keeps an int32 per component — the high bit is kept as the
## SIGN (`-1` for that same white; measured on 4.7). The wrap is a BIJECTION (the component
## reads back as `& 0xFFFFFFFF` == the packed value), so two distinct colours can never land
## on one key and the grouping is exactly what the old string key grouped: what was wrong was
## the comment, not the key. `_test_voxel_group_key_colour_band` pins both halves of that.
##
## The DIRECTION is the outer key rather than a fifth component, because a Vec4 runs out of
## axes — and it must be in the key: an "up" face and a "down" face at the same plane and
## span would otherwise merge into one quad with one direction, which is a missing floor or
## a missing ceiling.
static func group_cell(groups: Dictionary, dir: String, plane: float, bottom: float, top: float, color: Color, tx: int, tz: int) -> void:
	var buckets: Dictionary = groups.get(dir, {})
	var key := Vector4i(roundi(plane * 10000.0), roundi(bottom * 10000.0),
		roundi(top * 10000.0), color.to_rgba32())
	var g: Dictionary = buckets.get(key, {})
	if g.is_empty():
		g = {
			"dir": dir, "plane": plane, "bottom": bottom, "top": top,
			"color": color, "cells": {},
		}
		buckets[key] = g
		groups[dir] = buckets
	g["cells"][tz * CHUNK_SIZE + tx] = true

## A column read from the resolve table, falling back to the NATURAL column off the
## chunk's own heightmap when the caller did not resolve it (see `build_chunk_arrays`).
static func _column_for_cell(chunk_pos: Vector2i, heightmap: Array, runs: Dictionary, tx: int, tz: int) -> Array:
	var key := VoxelConsts.tile_key(Vector2i(chunk_pos.x * CHUNK_SIZE + tx, chunk_pos.y * CHUNK_SIZE + tz))
	if runs.has(key):
		return runs[key]
	var top := VoxelConsts.voxel_height(float(heightmap[tz * CHUNK_SIZE + tx]))
	if top <= BEDROCK_DEPTH:
		return []
	return [{ "bottom": BEDROCK_DEPTH, "top": top, "material": "", "color": FALLBACK_TERRAIN_COLOR }]

## A column for an arbitrary tile: inside the chunk it is `_column_for_cell` (with the
## same natural fallback), outside it must be IN the table or it is the UNKNOWN
## neighbour — an empty list, never a guess.
static func _column_for_tile(chunk_pos: Vector2i, heightmap: Array, runs: Dictionary, tx: int, tz: int) -> Array:
	if tx >= 0 and tx < CHUNK_SIZE and tz >= 0 and tz < CHUNK_SIZE:
		return _column_for_cell(chunk_pos, heightmap, runs, tx, tz)
	var key := VoxelConsts.tile_key(Vector2i(chunk_pos.x * CHUNK_SIZE + tx, chunk_pos.y * CHUNK_SIZE + tz))
	if runs.has(key):
		return runs[key]
	return []

## Greedy-mesh one group's tile cells into the fewest rectangles: sweep the cells in
## row-major order, take the widest run of cells on the current row, then extend that
## strip downward while every cell below it still belongs to the group. Deterministic
## (the sweep order is the tile index), so a chunk's arrays are reproducible — which is
## what lets a test compare two builds of the same chunk.
static func merge_rects(cells: Dictionary) -> Array:
	var out: Array = []
	var used: Dictionary = {}
	var order: Array = cells.keys()
	order.sort()
	for idx in order:
		if used.has(idx):
			continue
		var tx: int = int(idx) % CHUNK_SIZE
		@warning_ignore("integer_division")
		var tz: int = (int(idx) - tx) / CHUNK_SIZE
		var w := 1
		while tx + w < CHUNK_SIZE and cells.has(tz * CHUNK_SIZE + tx + w) and not used.has(tz * CHUNK_SIZE + tx + w):
			w += 1
		var h := 1
		while tz + h < CHUNK_SIZE:
			var complete := true
			for dx in range(w):
				var probe := (tz + h) * CHUNK_SIZE + tx + dx
				if not cells.has(probe) or used.has(probe):
					complete = false
					break
			if not complete:
				break
			h += 1
		for dz in range(h):
			for dx in range(w):
				used[(tz + dz) * CHUNK_SIZE + tx + dx] = true
		out.append({ "tx": tx, "tz": tz, "w": w, "h": h })
	return out

## Emit one merged rectangle as two triangles, and the same two into the collision
## soup. The winding matches the per-tile quads the merge replaces, so a face's normal
## points where it always did (the material renders both faces regardless; this is for
## lighting). Returns the number of quads emitted (always 1) so the caller can count.
static func _emit_rect(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, collision: PackedVector3Array, g: Dictionary, rect: Dictionary, origin_x: float, origin_z: float, plane_dx: float = 0.0, plane_dz: float = 0.0) -> int:
	var bottom := float(g["bottom"])
	var top    := float(g["top"])
	# A wall's plane is an absolute coordinate; a chunk-local build moves it by the corner (in double
	# precision, so the result is small and exact) before it becomes a float32 vertex.
	var plane  := float(g["plane"])
	match str(g["dir"]):
		"north", "south": plane -= plane_dz
		"west", "east": plane -= plane_dx
	var color: Color = g["color"]
	var x0 := origin_x + int(rect["tx"]) * TILE_SIZE
	var x1 := x0 + int(rect["w"]) * TILE_SIZE
	var z0 := origin_z + int(rect["tz"]) * TILE_SIZE
	var z1 := z0 + int(rect["h"]) * TILE_SIZE

	var a := Vector3.ZERO
	var b := Vector3.ZERO
	var c := Vector3.ZERO
	var d := Vector3.ZERO
	var normal := Vector3.UP
	match str(g["dir"]):
		"up":   # horizontal: `plane` is the y both faces sit on
			a = Vector3(x0, plane, z0); b = Vector3(x0, plane, z1)
			c = Vector3(x1, plane, z1); d = Vector3(x1, plane, z0)
		"down":
			normal = Vector3.DOWN
			a = Vector3(x0, plane, z0); b = Vector3(x1, plane, z0)
			c = Vector3(x1, plane, z1); d = Vector3(x0, plane, z1)
		"north":   # vertical walls: `plane` is the fixed x/z of the wall
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
	vertices.append(a); normals.append(normal); colors.append(color)
	vertices.append(b); normals.append(normal); colors.append(color)
	vertices.append(c); normals.append(normal); colors.append(color)
	vertices.append(d); normals.append(normal); colors.append(color)
	indices.append(base); indices.append(base + 1); indices.append(base + 2)
	indices.append(base); indices.append(base + 2); indices.append(base + 3)
	collision.append(a); collision.append(b); collision.append(c)
	collision.append(a); collision.append(c); collision.append(d)
	return 1

## Turn a `build_chunk_arrays()` result into the ArrayMesh a chunk node shows. Static
## and pure: an empty result yields an empty mesh rather than a surface with no
## triangles, which is what `add_surface_from_arrays` refuses.
static func mesh_from_arrays(arrays: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if arrays.is_empty():
		return mesh
	var verts: PackedVector3Array = arrays.get("vertices", PackedVector3Array())
	if verts.is_empty():
		return mesh
	var surface: Array = []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = verts
	surface[Mesh.ARRAY_NORMAL] = arrays["normals"]
	surface[Mesh.ARRAY_COLOR]  = arrays["colors"]
	surface[Mesh.ARRAY_INDEX]  = arrays["indices"]
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	return mesh

