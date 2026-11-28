class_name DigBrush
extends RefCounted
## Phase 300 — a dig is one brush op, rasterised into the run columns. Pure and static: the host and every client
## run the same op over the same runs and so append identical `remove` spans, and a native twin can match it bit
## for bit because everything here is integer millimetres (the `TerrainCsg` maths of Phase 245).
##
## Units: millimetres everywhere, ints. A tile is `TILE_MM` wide, a step `STEP_MM` tall. A cell is one tile by one
## step, named by its tile `(tx, tz)` and its bottom `b` (a multiple of `STEP_MM`).
##
## Op (plain Dictionary): `{ "shape": "sphere" | "cylinder" | "box", "centre": [x, y, z] (mm), "radius": int (mm),
## "k": int (mm, smooth blend, 0 = sharp) }`. A sphere has radius `radius`; a vertical cylinder radius `radius` and
## half height `radius`; a box half extents `radius` on every axis.
##
## Columns (plain input): `{ Vector2i(tx, tz): PackedInt32Array([bottom0, top0, bottom1, top1, ...]) }`, the
## NATURAL runs of the tile in mm, ascending (placed runs are left out, so they are never cut).
##
## A cell is cut when its sample point `(tx*500+250, b+62, tz*500+250)` is inside the brush:
## `smooth_intersection(shape_sd, solid_sd, k) < 0`, where `solid_sd = -min(y - run_bottom, run_top - y)` is the
## (negative) vertical distance to the edge of the natural run the cell sits in, so the rim eases out where the
## brush meets a ground face. A cell below `BEDROCK_MM` is never cut.

const TerrainCsg := preload("res://src/terrain/terrain_csg.gd")
const NativeLoaderScript := preload("res://src/core/native_loader.gd")

const TILE_MM := 500
const STEP_MM := 125
const SAMPLE_Y := 62            # offset of the sample point above the cell's bottom (floor of half a step)
const BEDROCK_MM := -96000
const SHAPES := ["sphere", "cylinder", "box"]
const MAX_K_MM := 1000

## Build the op for a dig that hit the ground at `hit` (metres, `x`/`z` from the exact position when one is
## known) with surface normal `normal`: the centre is the hit pushed half a radius into the ground, along
## `-normal`, then quantised: `x`, `z` to the middle of their tile, `y` to the nearest step. Pure.
static func make_op(shape: String, hit: Vector3, normal: Vector3, radius_mm: int, k_mm: int) -> Dictionary:
	var n := normal.normalized() if normal.length() > 0.0001 else Vector3.UP
	var push := float(radius_mm) * 0.5
	var x := roundi(hit.x * 1000.0 - n.x * push)
	var y := roundi(hit.y * 1000.0 - n.y * push)
	var z := roundi(hit.z * 1000.0 - n.z * push)
	return {
		"shape": shape,
		"centre": [floori(float(x) / TILE_MM) * TILE_MM + TILE_MM / 2, roundi(float(y) / STEP_MM) * STEP_MM,
			floori(float(z) / TILE_MM) * TILE_MM + TILE_MM / 2],
		"radius": radius_mm,
		"k": k_mm,
	}

## A wire or saved op that is well formed and bounded, or the reason it is not ("" = fine). `max_radius_mm` is the
## fabric's cap in mm.
static func problem(op: Dictionary, max_radius_mm: int) -> String:
	if not SHAPES.has(op.get("shape", "")):
		return "shape"
	var c: Variant = op.get("centre", null)
	if not (c is Array) or (c as Array).size() != 3:
		return "centre"
	for v in c:
		if not (v is int) or absi(int(v)) > 100000000000:
			return "centre"
	var r: Variant = op.get("radius", 0)
	if not (r is int) or int(r) < 1 or int(r) > max_radius_mm:
		return "radius"
	var k: Variant = op.get("k", 0)
	if not (k is int) or int(k) < 0 or int(k) > MAX_K_MM:
		return "k"
	return ""

## The inclusive tile range the brush can touch: `[tx_min, tx_max, tz_min, tz_max]`.
static func bounds(op: Dictionary) -> Array:
	var c: Array = op["centre"]
	var r: int = op["radius"]
	return [floori(float(c[0] - r) / TILE_MM), floori(float(c[0] + r) / TILE_MM),
		floori(float(c[2] - r) / TILE_MM), floori(float(c[2] + r) / TILE_MM)]

## The signed distance (mm) of the sample point `(px, py, pz)` to the brush shape: negative inside.
static func shape_sd(op: Dictionary, px: int, py: int, pz: int) -> int:
	var c: Array = op["centre"]
	var r: int = op["radius"]
	var p := Vector3i(px, py, pz)
	var cv := Vector3i(c[0], c[1], c[2])
	match str(op["shape"]):
		"cylinder":
			return TerrainCsg.cylinder(p, cv, r, r)
		"box":
			return TerrainCsg.box3(p, cv, Vector3i(r, r, r))
	return TerrainCsg.sphere(p, cv, r)

## Step 1, geometry only: every cell of `columns` the brush cuts. Tiles are walked `tx` ascending then `tz`
## ascending; a tile's runs in the order given, a run's cells bottom to top. Returns
## `[[tx, tz, PackedInt32Array(cell bottoms ascending)], ...]` for the tiles with at least one cell.
static func cut_cells(op: Dictionary, columns: Dictionary) -> Array:
	if NativeLoaderScript.use_native("NativeBake", "cut_cells"):   # same cells, computed in C++
		return NativeLoaderScript.instance("NativeBake").call("cut_cells", op, columns)
	return cut_cells_ref(op, columns)


## The GDScript reference the native `cut_cells` is held equal to.
static func cut_cells_ref(op: Dictionary, columns: Dictionary) -> Array:
	var out: Array = []
	var b := bounds(op)
	var cy: int = op["centre"][1]
	var r: int = op["radius"]
	var k: int = op["k"]
	var y_lo := cy - r - STEP_MM
	var y_hi := cy + r
	for tx in range(b[0], b[1] + 1):
		var px := tx * TILE_MM + TILE_MM / 2
		for tz in range(b[2], b[3] + 1):
			var key := Vector2i(tx, tz)
			if not columns.has(key):
				continue
			var pz := tz * TILE_MM + TILE_MM / 2
			var runs: PackedInt32Array = columns[key]
			var cells := PackedInt32Array()
			for i in range(0, runs.size() - 1, 2):
				var rb: int = runs[i]
				var rt: int = runs[i + 1]
				var from := maxi(maxi(rb, BEDROCK_MM), y_lo)
				var to := mini(rt, y_hi)
				var cb := from - posmod(from, STEP_MM)
				if cb < from:
					cb += STEP_MM
				while cb + STEP_MM <= rt and cb < to:
					var py := cb + SAMPLE_Y
					var solid := -mini(py - rb, rt - py)
					if TerrainCsg.smooth_intersection(shape_sd(op, px, py, pz), solid, k) < 0:
						cells.append(cb)
					cb += STEP_MM
			if not cells.is_empty():
				out.append([tx, tz, cells])
	return out

## Merge ascending cell bottoms into `PackedInt32Array([bottom, top, bottom, top, ...])` spans.
static func spans_of(cells: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for cb in cells:
		var n := out.size()
		if n > 0 and out[n - 1] == cb:
			out[n - 1] = cb + STEP_MM
		else:
			out.append(cb)
			out.append(cb + STEP_MM)
	return out

## The whole rasteriser. `classify(tx, tz, cell_bottom_mm)` answers `{ "material": String, "vein": Dictionary }` (`vein`
## empty outside a live vein); `cuts` is `{ material: true }`, the materials the tool cuts. A cell of another
## material stays. Returns
## `{ "tiles": [[tx, tz, PackedInt32Array spans]], "volume": { material: cells }, "veins": { id: { "vein": Dictionary,
##   "cells": int } } }`, tiles in `cut_cells` order. `volume` counts the cells of ground that is not a vein's;
## a vein's cells are under `veins` (and its material is not in `volume`).
static func rasterise(op: Dictionary, columns: Dictionary, classify: Callable, cuts: Dictionary) -> Dictionary:
	var tiles: Array = []
	var volume: Dictionary = {}
	var veins: Dictionary = {}
	for entry in cut_cells(op, columns):
		var kept := PackedInt32Array()
		for cb in (entry[2] as PackedInt32Array):
			var c: Dictionary = classify.call(entry[0], entry[1], cb)
			var material := str(c.get("material", ""))
			if not cuts.has(material):
				continue
			kept.append(cb)
			var vein: Dictionary = c.get("vein", {})
			if vein.is_empty():
				volume[material] = int(volume.get(material, 0)) + 1
			else:
				var id := str(vein["id"])
				if not veins.has(id):
					veins[id] = { "vein": vein, "cells": 0 }
				veins[id]["cells"] = int(veins[id]["cells"]) + 1
		if not kept.is_empty():
			tiles.append([entry[0], entry[1], spans_of(kept)])
	return { "tiles": tiles, "volume": volume, "veins": veins }
