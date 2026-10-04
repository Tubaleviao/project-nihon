extends RefCounted
## Ore field — where the ground's materials actually are (Phase 43).
##
## Before this phase every tile of a biome drew its material from the same weighted
## table (`VoxelSlice.BIOME_MATERIALS`), so Aethermite was 17/100 of every volcanic tile
## at every depth, forever, and the material's own prose ("deep underground near ley
## lines") described nothing the code did. This field replaces that draw with VEINS:
## blobs of neighbouring tiles at a depth, each with a material, a per-slice quantity and
## a finite reserve. Everything that is not inside a live vein is the biome's HOST rock —
## the dominant material of its `BIOME_BIAS` entry.
##
## Pure, static and object-free: every answer is a function of (seed, global tile, depth)
## and of the material bands read off the generated fabric resources. No node, no bus, no
## `FastNoiseLite` (the noise is hand-rolled lattice value noise over an integer hash), so a
## chunk-build worker may call it, and a host and a client evaluating it with the same
## seed see the same veins with nothing replicated.
##
## Public API (all static):
##   vein_at(seed, chunk_pos, tile, depth, cache = {}) -> Dictionary
##       `{ id, material, quantity, reserve, center, radius, half_height, anchor }` when
##       (tile, depth) is inside a vein, else `{}`. `tile` is chunk-LOCAL; `depth` is in
##       world units below the tile's natural surface.
##   vein_in_cell(seed, cell, cache = {}) -> Dictionary   — the cell's vein descriptor, or {}
##   cell_of(global_tile, depth) -> Vector3i
##   ley_line_value(seed, world_xz) -> float               — 1.0 on a ley line, → 0 away
##   near_ley_line(seed, world_xz) -> bool
##   is_live(vein, depleted) -> bool                       — reserve not yet mined out
##   remaining(vein, depleted) -> int
##   host_material(biome) -> String                        — the biome's bias rock
##   allows(material, depth, world_xz, seed) -> bool       — the fabric depth band + ley gate
##   band_of(material) -> Dictionary                       — `{ min, max, ley }`
##   warm() -> void                                        — fill the band table (main thread)
##
## SHAPE. Space is cut into cells CELL_TILES tiles wide and CELL_DEPTH units deep; a cell
## holds at most one vein, whose centre is placed far enough inside the cell that the blob
## — an ellipsoid whose surface is perturbed by 3D value noise — can never leave it. So a
## sample asks exactly ONE cell, never its neighbours, and a vein's IDENTITY is its cell
## (the hash of its blob origin the roadmap asks for). The XZ cell grid is offset by half a
## cell from the chunk grid, so cells — and the veins in them — straddle chunk borders: the
## field is evaluated per tile, so a blob crossing a border is continuous on both sides, and
## no chunk "owns" a vein.
##
## MATERIAL. A vein's material is picked ONCE, at its centre, from the centre's biome
## (`TerrainSlice.biome_for_chunk`, the same pure answer the terrain slice gives): a
## weighted draw over the biome's NON-host bias materials whose fabric band and ley gate
## admit the centre, falling back to the host itself (a rich pocket of the common rock)
## when none do — which is all a single-material biome like TemperateForest ever has. Each
## tile is then CLIPPED by the same gate, so a blob never pokes above its material's band
## or out from a ley line, and "Aethermite never appears above its band" holds per tile,
## not merely per vein centre.
##
## The noise CONSTANTS below stay GDScript (the roadmap's known simplification); the
## material's depth band and ley gate do not — they are fabric fields (`depthBand`,
## `leyGated` on `fabric/world/materials/*.js`), read here off `GameData.MATERIALS`.

const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")

## Mirrors of VoxelSlice's grid (authoritative copies live there and on TerrainSlice).
const CHUNK_SIZE := 64
const TILE_SIZE := 0.5

## Biome → weighted material bias (key → weight out of 100) — a faithful transcription of
## each biome's fabric `evaluateSpawn` prose (fabric/world/biomes/*.js), retired by Phase 43
## from THE distribution to a bias over it: the heaviest entry is the biome's HOST rock (what
## every tile outside a live vein yields), and the rest weight the draw for a vein's
## material. Woods (Thornwood / Duskfiber) stay absent — their prose spawns them as trees.
const BIOME_BIAS: Dictionary = {
	# prose: ferrite outcrops 0.6; thornwood 0.8 is a tree, not ground
	"TemperateForest":    { "Ferrite": 100 },
	# prose: ferrite deposits 0.4; thornwood 0.1 is a tree, not ground
	"TemperateGrassland": { "Ferrite": 100 },
	# prose: ashite 0.9 / aethermite 0.2 / ferrite 0.1
	"VolcanicBadlands":   { "Ashite": 75, "Aethermite": 17, "Ferrite": 8 },
	# prose: lumenfite 0.5 / aethermite 0.15; duskfiber 0.9 is a tree, not ground
	"TwilightGrove":      { "Lumenfite": 77, "Aethermite": 23 },
	# prose: voidite 0.7 / ferrite 0.3
	"VoidRift":           { "Voidite": 70, "Ferrite": 30 },
}

## The host a biome missing from BIOME_BIAS falls back to (no canonical biome is missing —
## pinned by the suite).
const FALLBACK_HOST := "Ferrite"

## Cell geometry. CELL_TILES divides CHUNK_SIZE, and CELL_OFFSET_TILES shifts the cell grid
## half a cell off the chunk grid, so every chunk border runs through the middle of a row
## of cells.
const CELL_TILES := 16
const CELL_OFFSET_TILES := 8
const CELL_DEPTH := 4.0

## The chance a cell holds a vein at all (before the material gate, which can still empty it).
const VEIN_CHANCE := 0.55

## Blob size: horizontal radius in TILES, vertical half-height in world units.
const RADIUS_MIN_TILES := 2.0
const RADIUS_MAX_TILES := 4.0
const HALF_HEIGHT_MIN := 0.5
const HALF_HEIGHT_MAX := 1.0

## How far the 3D noise pushes the blob's surface, as a fraction of its radius, and the
## noise wavelength (tiles horizontally, world units vertically). The cell margin is
## sized from (1 + SHAPE_NOISE), which is what keeps a blob inside its cell.
const SHAPE_NOISE := 0.3
const SHAPE_WAVELENGTH_TILES := 3.0
const SHAPE_WAVELENGTH_DEPTH := 1.0

## Units yielded per mined slice of a vein, and the vein's total reserve.
const QUANTITY_MIN := 2
const QUANTITY_MAX := 4
const RESERVE_MIN := 8
const RESERVE_MAX := 20

## The ley-line field: ridged 2D value noise (1 − |n|), so the lines are the noise's zero
## contours — long, thin, branching. A position is NEAR a ley line when its value is at or
## above LEY_THRESHOLD. LEY_WAVELENGTH is in world units.
const LEY_WAVELENGTH := 40.0
const LEY_THRESHOLD := 0.8

## Hash salts, one per independent draw, so no two draws share a stream.
const _SALT_PRESENT := 1
const _SALT_X := 2
const _SALT_Z := 3
const _SALT_DEPTH := 4
const _SALT_RADIUS := 5
const _SALT_HEIGHT := 6
const _SALT_MATERIAL := 7
const _SALT_QUANTITY := 8
const _SALT_RESERVE := 9
const _SALT_SHAPE := 10
const _SALT_LEY := 11

## material key → `{ "min": float, "max": float, "ley": bool }`, read off the generated
## fabric resources (`depthBand`, `leyGated`). Filled on the MAIN thread by `warm()` —
## VoxelSlice calls it from `_ready()`, before any chunk-build worker exists — and
## read-only afterwards: a worker reads it, never writes it. `band_of` fills it on first
## use for a caller that never warmed it (an isolated test), which is a main-thread call.
static var _bands: Dictionary = {}

## Fill the band table from `GameData.MATERIALS` (idempotent). Main thread only.
static func warm() -> void:
	if not _bands.is_empty():
		return
	for key in GameData.MATERIALS:
		var res: Resource = GameData.MATERIALS[key]
		var band: Variant = res.get("depthBand")
		var entry := { "min": 0.0, "max": 0.0, "ley": false }
		if band is Dictionary:
			entry["min"] = float((band as Dictionary).get("min", 0.0))
			entry["max"] = float((band as Dictionary).get("max", 0.0))
		entry["ley"] = bool(res.get("leyGated")) if res.get("leyGated") != null else false
		_bands[str(key)] = entry

## A material's fabric band and ley gate. An unknown material has an EMPTY band.
static func band_of(material: String) -> Dictionary:
	if _bands.is_empty():
		warm()
	return _bands.get(material, { "min": 0.0, "max": 0.0, "ley": false })

## True when the fabric admits `material` at this depth and position: inside its half-open
## depth band [min, max), and near a ley line if it is ley-gated.
static func allows(material: String, depth: float, world_xz: Vector2, seed: int) -> bool:
	var band := band_of(material)
	if depth < float(band["min"]) or depth >= float(band["max"]):
		return false
	if bool(band["ley"]) and not near_ley_line(seed, world_xz):
		return false
	return true

## The biome's host rock — the heaviest entry of its bias (first wins a tie, in the
## table's own order).
static func host_material(biome: String) -> String:
	var bias: Dictionary = BIOME_BIAS.get(biome, {})
	var best := FALLBACK_HOST
	var best_w := -1
	for material in bias:
		if int(bias[material]) > best_w:
			best_w = int(bias[material])
			best = str(material)
	return best

## The cell a (global tile, depth) sample falls in. Depth cells start at the natural
## surface (depth 0); a negative depth is above it, where no vein lives.
static func cell_of(global_tile: Vector2i, depth: float) -> Vector3i:
	return Vector3i(
		floori(float(global_tile.x + CELL_OFFSET_TILES) / float(CELL_TILES)),
		floori(depth / CELL_DEPTH),
		floori(float(global_tile.y + CELL_OFFSET_TILES) / float(CELL_TILES)))

## The vein a cell holds, or `{}`. Deterministic in (seed, cell); `cache` memoises the
## descriptor per cell for the caller's lifetime (a chunk build asks a few cells thousands
## of times). The returned dictionary is shared through the cache — read it, never write it.
static func vein_in_cell(seed: int, cell: Vector3i, cache: Dictionary = {}) -> Dictionary:
	if cache.has(cell):
		return cache[cell]
	var vein := _build_vein(seed, cell)
	cache[cell] = vein
	return vein

static func _build_vein(seed: int, cell: Vector3i) -> Dictionary:
	if cell.y < 0:
		return {}
	if _unit(_hash(seed, cell, _SALT_PRESENT)) >= VEIN_CHANCE:
		return {}
	var margin := RADIUS_MAX_TILES * (1.0 + SHAPE_NOISE)
	var vmargin := HALF_HEIGHT_MAX * (1.0 + SHAPE_NOISE)
	var origin_x := float(cell.x * CELL_TILES - CELL_OFFSET_TILES)
	var origin_z := float(cell.z * CELL_TILES - CELL_OFFSET_TILES)
	var span := float(CELL_TILES) - margin * 2.0
	var cx := origin_x + margin + _unit(_hash(seed, cell, _SALT_X)) * span
	var cz := origin_z + margin + _unit(_hash(seed, cell, _SALT_Z)) * span
	# The TOP depth cell has no cell above it (a negative depth is air, not ground), so its
	# veins may sit right up to the surface and break through it — that is what puts a
	# shallow vein, and its marker, where a player can see it from above.
	var top_margin := 0.0 if cell.y == 0 else vmargin
	var cd := float(cell.y) * CELL_DEPTH + top_margin + _unit(_hash(seed, cell, _SALT_DEPTH)) * (CELL_DEPTH - vmargin - top_margin)
	var anchor := Vector2i(floori(cx), floori(cz))
	var center_xz := Vector2(cx * TILE_SIZE, cz * TILE_SIZE)
	var biome := TerrainSlice.biome_for_chunk(Vector2i(
		floori(float(anchor.x) / float(CHUNK_SIZE)), floori(float(anchor.y) / float(CHUNK_SIZE))), seed)
	var material := _pick_material(seed, biome, cd, center_xz, _unit(_hash(seed, cell, _SALT_MATERIAL)))
	if material == "":
		return {}
	return {
		"id":          "%d,%d,%d" % [cell.x, cell.y, cell.z],
		"material":    material,
		"quantity":    QUANTITY_MIN + _hash(seed, cell, _SALT_QUANTITY) % (QUANTITY_MAX - QUANTITY_MIN + 1),
		"reserve":     RESERVE_MIN + _hash(seed, cell, _SALT_RESERVE) % (RESERVE_MAX - RESERVE_MIN + 1),
		"center":      Vector3(cx, cd, cz),
		"radius":      lerpf(RADIUS_MIN_TILES, RADIUS_MAX_TILES, _unit(_hash(seed, cell, _SALT_RADIUS))),
		"half_height": lerpf(HALF_HEIGHT_MIN, HALF_HEIGHT_MAX, _unit(_hash(seed, cell, _SALT_HEIGHT))),
		"anchor":      anchor,
		"biome":       biome,
	}

## The vein's material: a weighted draw over the biome's non-host bias materials the
## fabric admits at the centre, else the host when the fabric admits IT, else none.
static func _pick_material(seed: int, biome: String, depth: float, center_xz: Vector2, roll: float) -> String:
	var bias: Dictionary = BIOME_BIAS.get(biome, { FALLBACK_HOST: 1 })
	var host := host_material(biome)
	var candidates: Array = []
	var total := 0
	for material in bias:
		var key := str(material)
		if key == host or not allows(key, depth, center_xz, seed):
			continue
		total += int(bias[material])
		candidates.append([total, key])
	if candidates.is_empty():
		return host if allows(host, depth, center_xz, seed) else ""
	var pick := roll * float(total)
	for entry in candidates:
		if pick < float(entry[0]):
			return str(entry[1])
	return str(candidates[-1][1])

## The vein at a chunk-local `tile` and `depth` (world units below the tile's natural
## surface), or `{}`. See the class docstring for the shape and the per-tile clip.
static func vein_at(seed: int, chunk_pos: Vector2i, tile: Vector2i, depth: float, cache: Dictionary = {}) -> Dictionary:
	var g := chunk_pos * CHUNK_SIZE + tile
	var vein := vein_in_cell(seed, cell_of(g, depth), cache)
	if vein.is_empty():
		return {}
	var center: Vector3 = vein["center"]
	var px := float(g.x) + 0.5
	var pz := float(g.y) + 0.5
	var radius := float(vein["radius"])
	var dx := (px - center.x) / radius
	var dz := (pz - center.z) / radius
	var dy := (depth - center.y) / float(vein["half_height"])
	var d := sqrt(dx * dx + dy * dy + dz * dz)
	# The noise moves the surface by at most ±SHAPE_NOISE, so most samples are decided by the
	# ellipsoid alone and never pay for the 3D noise (eight corner hashes).
	if d >= 1.0 + SHAPE_NOISE:
		return {}
	if d > 1.0 - SHAPE_NOISE:
		var n := _value_noise_3d(_salted(seed, _SALT_SHAPE),
			px / SHAPE_WAVELENGTH_TILES, depth / SHAPE_WAVELENGTH_DEPTH, pz / SHAPE_WAVELENGTH_TILES)
		if d + n * SHAPE_NOISE >= 1.0:
			return {}
	if not allows(str(vein["material"]), depth, Vector2(px * TILE_SIZE, pz * TILE_SIZE), seed):
		return {}
	return vein

## How many units of `vein` are left, given the depletion record (vein id → units taken).
static func remaining(vein: Dictionary, depleted: Dictionary) -> int:
	if vein.is_empty():
		return 0
	return maxi(int(vein["reserve"]) - int(depleted.get(str(vein["id"]), 0)), 0)

## True when `vein` exists and still has units left.
static func is_live(vein: Dictionary, depleted: Dictionary) -> bool:
	return remaining(vein, depleted) > 0

## The ley-line field at a world position: 1.0 exactly on a line, falling toward 0 away
## from it (ridged value noise — see LEY_WAVELENGTH).
static func ley_line_value(seed: int, world_xz: Vector2) -> float:
	var n := _value_noise_2d(_salted(seed, _SALT_LEY), world_xz.x / LEY_WAVELENGTH, world_xz.y / LEY_WAVELENGTH)
	return 1.0 - absf(n)

static func near_ley_line(seed: int, world_xz: Vector2) -> bool:
	return ley_line_value(seed, world_xz) >= LEY_THRESHOLD

# ---------------------------------------------------------------------------
# Hashing and noise — integer-only, no objects, so it is worker-safe and identical on
# every machine.
# ---------------------------------------------------------------------------

## A non-negative 31-bit hash of (seed, cell, salt). GDScript ints are 64-bit and wrap on
## overflow, which the mix relies on; the final mask keeps the result non-negative.
static func _hash(seed: int, cell: Vector3i, salt: int) -> int:
	return _mix(seed, cell.x, cell.y, cell.z, salt)

static func _mix(seed: int, a: int, b: int, c: int, salt: int) -> int:
	var h: int = seed * 0x9E3779B1 + a * 0x85EBCA77 + b * 0xC2B2AE3D + c * 0x27D4EB2F + salt * 0x165667B1
	h = (h ^ (h >> 15)) * 0x2C1B3C6D
	h = (h ^ (h >> 12)) * 0x297A2D39
	h = h ^ (h >> 15)
	return h & 0x7FFFFFFF

static func _unit(h: int) -> float:
	return float(h) / 2147483648.0

static func _salted(seed: int, salt: int) -> int:
	return _mix(seed, salt, 0, 0, 0)

## The lattice value at an integer corner, in [-1, 1).
static func _corner(seed: int, x: int, y: int, z: int) -> float:
	return _unit(_mix(seed, x, y, z, 0)) * 2.0 - 1.0

static func _smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)

## Smoothly interpolated lattice value noise in [-1, 1].
static func _value_noise_2d(seed: int, x: float, z: float) -> float:
	var x0 := floori(x)
	var z0 := floori(z)
	var tx := _smooth(x - float(x0))
	var tz := _smooth(z - float(z0))
	var a := lerpf(_corner(seed, x0, 0, z0), _corner(seed, x0 + 1, 0, z0), tx)
	var b := lerpf(_corner(seed, x0, 0, z0 + 1), _corner(seed, x0 + 1, 0, z0 + 1), tx)
	return lerpf(a, b, tz)

static func _value_noise_3d(seed: int, x: float, y: float, z: float) -> float:
	var x0 := floori(x)
	var y0 := floori(y)
	var z0 := floori(z)
	var tx := _smooth(x - float(x0))
	var ty := _smooth(y - float(y0))
	var tz := _smooth(z - float(z0))
	var lo_a := lerpf(_corner(seed, x0, y0, z0), _corner(seed, x0 + 1, y0, z0), tx)
	var lo_b := lerpf(_corner(seed, x0, y0, z0 + 1), _corner(seed, x0 + 1, y0, z0 + 1), tx)
	var hi_a := lerpf(_corner(seed, x0, y0 + 1, z0), _corner(seed, x0 + 1, y0 + 1, z0), tx)
	var hi_b := lerpf(_corner(seed, x0, y0 + 1, z0 + 1), _corner(seed, x0 + 1, y0 + 1, z0 + 1), tx)
	return lerpf(lerpf(lo_a, lo_b, tz), lerpf(hi_a, hi_b, tz), ty)
