extends RefCounted
## Phase 285 — a GDScript mirror of the terrain shader's per-pixel layer blend (`terrain_material.gdshader`,
## `fragment()`), so the guards that keep natural ground from drawing black or NaN can be tested without a GPU:
## the blend height is a luminance clamped up to the layer's floor plus its weight, the layer with the largest
## weight is always drawn (even when every weight is at or under `WEIGHT_CUT`), both divisions are guarded and a
## cancelled normal falls back to the geometric one. `TerrainWeights` mirrors the vertex side.

const LAYERS := 8
## A layer weighing no more than this (of the vertex total) is not sampled, unless it is the heaviest.
const WEIGHT_CUT := 0.002
## A vertex whose weights total less than this is a placed block, drawn in its vertex colour.
const BLOCK_TOTAL := 0.01
const MIN_DEPTH := 0.01
const MIN_SUM := 1e-4
const MIN_NORMAL := 1e-4

## The blend height of a texel: its luminance, no lower than the layer's `height_floor`, plus its weight.
static func height_of(albedo: Vector3, weight: float, height_floor: float) -> float:
	return maxf(albedo.dot(Vector3(0.333, 0.333, 0.333)), height_floor) + weight

## Index of the heaviest layer (the first on a tie), 0 when every weight is zero.
static func heaviest(weights: Array) -> int:
	var best := 0
	for i in weights.size():
		if float(weights[i]) > float(weights[best]):
			best = i
	return best

## Blend one pixel. (Normalised weights sum to 1 so one is always above the cut; the heaviest-layer rule guards
## a vertex whose weights were rounded away, and `weight_cut` lets a test raise the cut to exercise it.) `weights`: the vertex weight of each layer (8), `albedos` / `normals`: each layer's sampled
## colour and (world-space) normal, `height_floors`: each layer's floor, `geo_normal`: the surface normal.
## Returns `{ weights: PackedFloat32Array (finite, sums to 1), albedo: Vector3, normal: Vector3 (unit),
## block: bool }`; `block` is true for a vertex under `BLOCK_TOTAL`, which the shader draws in the vertex
## colour (its weights are then one-hot on the heaviest layer, so they stay finite).
static func blend(weights: Array, albedos: Array, normals: Array, height_floors: Array, blend_depth: float,
		geo_normal: Vector3 = Vector3.UP, weight_cut: float = WEIGHT_CUT) -> Dictionary:
	var total := 0.0
	for w in weights:
		total += maxf(float(w), 0.0)
	var best := heaviest(weights)
	var out := PackedFloat32Array()
	out.resize(weights.size())
	var geo := geo_normal.normalized() if geo_normal.length() > MIN_NORMAL else Vector3.UP
	if total < BLOCK_TOTAL:
		out[best] = 1.0
		return { "weights": out, "albedo": Vector3.ZERO, "normal": geo, "block": true }
	var depth := maxf(blend_depth, MIN_DEPTH)
	var heights := PackedFloat32Array()
	heights.resize(weights.size())
	var hmax := -1.0
	for i in weights.size():
		var w: float = float(weights[i]) / total
		heights[i] = -1.0
		if w > weight_cut or i == best:
			heights[i] = height_of(albedos[i], w, float(height_floors[i]))
			hmax = maxf(hmax, heights[i])
	var col := Vector3.ZERO
	var nrm := Vector3.ZERO
	var sum := 0.0
	for i in weights.size():
		var b := maxf(heights[i] - (hmax - depth), 0.0)
		if b > 0.0:
			col += (albedos[i] as Vector3) * b
			nrm += (normals[i] as Vector3) * b
			out[i] = b
			sum += b
	sum = maxf(sum, MIN_SUM)
	for i in out.size():
		out[i] = out[i] / sum
	var n := nrm / sum
	return { "weights": out, "albedo": col / sum, "normal": n.normalized() if n.length() > MIN_NORMAL else geo, "block": false }
