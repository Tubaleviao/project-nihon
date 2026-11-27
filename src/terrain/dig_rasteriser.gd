class_name DigRasteriser
extends RefCounted
## Phase 300 — rasterises one dig brush into the run columns. Pure: it reads columns through `runs_at` and says
## which STEP_HEIGHT cells of which tiles the brush removes; it writes nothing, so the host, a predicting client
## and a replaying peer derive the identical cells from the same op over the same runs.
##
## A brush is `{ shape, centre: Vector3 (m), radius (m), k (m, smooth blend), half_height (m, cylinder) }`. The
## centre is snapped to the tile centre and the STEP_HEIGHT grid, all maths is integer millimetres (TerrainCsg).
## Only natural spans (run material "") are cut, so a placed block inside the bounds is untouched; cells under
## BEDROCK_DEPTH are never cut; `cut_ok.call(tile, bottom, top)` lets the caller refuse materials the tool cannot cut.

const Csg := preload("res://src/terrain/terrain_csg.gd")
const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")
const NativeLoaderScript := preload("res://src/core/native_loader.gd")

## The lowest step a cut reaches: BEDROCK_DEPTH in steps (-96 m / 0.125 m).
const MIN_N := -768
const TILE_MM := 500
const STEP_MM := 125
## The cell centres sample the shape coarsely (half-metre tiles); a brush reaches this much further so a 1 m sphere
## removes the volume of a half sphere, not a tenth less.
const REACH_BIAS_MM := 20
const SHAPES := ["sphere", "cylinder", "box"]

## The brush centre as the rasteriser sees it: x/z at a tile centre, y on the step grid (millimetres).
static func snap_centre(centre: Vector3) -> Vector3i:
	var tx := floori(centre.x * 1000.0 / TILE_MM)
	var tz := floori(centre.z * 1000.0 / TILE_MM)
	var ys := roundi(centre.y * 1000.0 / STEP_MM)
	return Vector3i(tx * TILE_MM + TILE_MM / 2, ys * STEP_MM, tz * TILE_MM + TILE_MM / 2)

## The centre a dig aims at: the ray hit pushed half a radius into the ground against the hit normal.
static func centre_from_hit(hit: Vector3, normal: Vector3, radius: float) -> Vector3:
	return hit - normal.normalized() * radius * 0.5

static func _distance(shape: int, p: Vector3i, c: Vector3i, r: int, hh: int) -> int:
	if shape == 1:
		return Csg.cylinder(p, c, r, hh)
	if shape == 2:
		return Csg.box3(p, c, Vector3i(r, r, r))
	return Csg.sphere(p, c, r)

## The brush as integer millimetres the geometry works on: `{ shape (0 sphere, 1 cylinder, 2 box), c, r, k, hh }`.
static func _params(brush: Dictionary) -> Dictionary:
	var shape: int = maxi(SHAPES.find(str(brush.get("shape", "sphere"))), 0)
	return {
		"shape": shape, "c": snap_centre(brush["centre"]),
		"r": roundi(float(brush["radius"]) * 1000.0) + REACH_BIAS_MM,
		"k": roundi(float(brush.get("k", 0.0)) * 1000.0),
		"hh": roundi(float(brush.get("half_height", brush["radius"])) * 1000.0),
	}

## The cells the brush shape covers, ignoring the ground: flat triples (tile x, step n, tile z), tile-major then
## bottom-up. Native when `NativeBake` is current, else the GDScript reference; the suite holds them equal.
static func geometry(brush: Dictionary) -> PackedInt32Array:
	var q := _params(brush)
	if NativeLoaderScript.use_native("NativeBake", "dig_cells"):
		return NativeLoaderScript.instance("NativeBake").call("dig_cells", q["shape"], q["c"], q["r"], q["k"], q["hh"], MIN_N)
	return geometry_gd(brush)

## The GDScript reference of `geometry`.
static func geometry_gd(brush: Dictionary) -> PackedInt32Array:
	var q := _params(brush)
	var c: Vector3i = q["c"]
	var r: int = q["r"]
	var k: int = q["k"]
	var hh: int = q["hh"]
	var out := PackedInt32Array()
	var reach_xz := r + k
	var reach_y := (hh if int(q["shape"]) == 1 else r) + k
	var tx0 := floori(float(c.x - reach_xz) / TILE_MM)
	var tx1 := floori(float(c.x + reach_xz) / TILE_MM)
	var tz0 := floori(float(c.z - reach_xz) / TILE_MM)
	var tz1 := floori(float(c.z + reach_xz) / TILE_MM)
	var n0 := floori(float(c.y - reach_y) / STEP_MM)
	var n1 := floori(float(c.y + reach_y) / STEP_MM)
	for tx in range(tx0, tx1 + 1):
		for tz in range(tz0, tz1 + 1):
			var px := tx * TILE_MM + TILE_MM / 2
			var pz := tz * TILE_MM + TILE_MM / 2
			for n in range(n0, n1 + 1):
				if n < MIN_N:
					continue
				var p := Vector3i(px, n * STEP_MM + STEP_MM / 2, pz)
				# The ground at the cell is inside (-half a step); the brush is subtracted from it, smoothly.
				if Csg.smooth_subtract(-STEP_MM / 2, _distance(int(q["shape"]), p, c, r, hh), k) > 0:
					out.append(tx)
					out.append(n)
					out.append(tz)
	return out

## Every cell the brush removes: `[{ tile: Vector2i, bottom: float, top: float }]`, tile-major, bottom-up.
static func rasterise(brush: Dictionary, runs_at: Callable, cut_ok: Callable = Callable()) -> Array:
	var out: Array = []
	var g := geometry(brush)
	var runs_cache := {}
	for i in range(0, g.size(), 3):
		var tile := Vector2i(g[i], g[i + 2])
		if not runs_cache.has(tile):
			runs_cache[tile] = runs_at.call(tile)
		var runs: Array = runs_cache[tile]
		if runs.is_empty():
			continue
		var bottom := float(g[i + 1]) * VoxelConsts.STEP_HEIGHT
		var top := bottom + VoxelConsts.STEP_HEIGHT
		if not _natural_cell(runs, bottom, top):
			continue
		if cut_ok.is_valid() and not bool(cut_ok.call(tile, bottom, top)):
			continue
		out.append({ "tile": tile, "bottom": bottom, "top": top })
	return out

static func _natural_cell(runs: Array, bottom: float, top: float) -> bool:
	for run in runs:
		if float(run["bottom"]) <= bottom + 0.000001 and float(run["top"]) >= top - 0.000001:
			return str(run.get("material", "")) == ""
	return false

## Contiguous cells of one tile merged into `[{ bottom, top }]` spans, for the op log.
static func merge_spans(cells: Array) -> Array:
	var spans: Array = []
	for cell in cells:
		if not spans.is_empty() and absf(float(spans[-1]["top"]) - float(cell["bottom"])) < 0.000001:
			spans[-1]["top"] = cell["top"]
		else:
			spans.append({ "bottom": cell["bottom"], "top": cell["top"] })
	return spans
