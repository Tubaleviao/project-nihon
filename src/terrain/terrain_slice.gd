extends Node
## Terrain slice — procedural chunk generation via FastNoiseLite.
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : none (the streamed path calls `generate_heightmap` directly; `request_chunk`
##              is the test-only trigger for the `chunk_ready` synchronous path)
##   OUT : chunk_ready(chunk_pos, heightmap)
##
## Public API:
##   request_chunk(pos: Vector2i) -> void   — TEST ONLY: announce a chunk on the bus
##   generate_heightmap(pos: Vector2i) -> Array — the production entry point (no signal)
##   get_height_at(world_pos: Vector2) -> float — terrain height at world XZ
##   set_world_seed(seed: int) -> void      — the world's identity (Phase 41)
##   get_world_seed() -> int
##   biome_for_chunk(chunk_pos) -> String  — static, pure (Phase 43: the ore field's biome read)

const CHUNK_SIZE := 64       # tiles per side (64 × 0.5 = 32 world units per chunk)
const TILE_SIZE  := 0.5      # world units per tile (XZ) — each square is half its former 1.0 size
const HEIGHT_SCALE := 5.0    # world units peak-to-valley of the small-scale DETAIL noise (Phase 51: the large shape is WorldShape)
## Phase 71 — which generator produced the terrain and biome layout a world record was
## written against. Bump it in any phase that changes generation output (heights, biome
## placement, climate, continents), so an older save is flagged on load instead of silently
## meeting a different layout. History: 1 = pre-Phase-49 layout; 2 = Phase 49 biomes and
## Phase 51 continent shape (the layout this constant first shipped with); 3 = Phase 72
## stable, low-frequency rare-biome niches, the land-only Voronoi fallback, and one 10000
## lattice modulus for all climate noise (it was 9999 for temperature and moisture); 4 = Phase 76
## niche field that wraps at the antimeridian and a fallback pool read from the biome data; 5 = the
## walkable polar caps: frozen sea is an ice shelf from `ICE_SHELF_LAT`, and the ground flattens
## into one ice sheet at the polar line so the pole can be crossed.
const WORLDGEN_VERSION := 5
const BIOME_SEED := 20260815 # fixed seed so biome assignment is deterministic
const ClimateField := preload("res://src/terrain/climate_field.gd")
const WorldShape := preload("res://src/terrain/world_shape.gd")

## The starting area is flattened into a plain field so the player can walk
## freely from spawn without jumping. Spawn centre + radius + flat height below.
# Phase 53 — the flattened spawn disc is retired: a new player is placed by `SpawnFinder` on land
# the planet already made habitable, so no terrain is forced flat around a fixed point.

## The planet (Phase 50). Globe semantics on a flat chunk grid: X wraps around the
## circumference, Z is latitude. Walking over a pole comes back down the far meridian
## (`fold_world_pos`), so every direction leads round the planet. The sizes are fabric facts
## (`WorldSystem`: circumferenceKm, polarLatitude); these are the fallbacks for a rig without
## the generated resources.
const DEFAULT_CIRCUMFERENCE_KM := 40000.0
const DEFAULT_POLAR_LATITUDE := 85.0
const CHUNK_METERS := CHUNK_SIZE * TILE_SIZE
## Width of the east-edge band over which heights blend into the west edge's, so the wrap seam
## has no cliff (the noise is not periodic).
const WRAP_BLEND_CHUNKS := 8
## Polar ice. From `ICE_SHELF_LAT` the sea is frozen: the ground never lies below the ice shelf
## (`sea level + ICE_SHELF_M`), so there is no liquid water under the ice to fall into. Over the
## last `POLAR_FLATTEN_DEG` before the polar line the ground eases into that same flat sheet, and
## past the line it is exactly the sheet, so both sides of a pole look and feel the same.
const ICE_SHELF_LAT := 80.0
const ICE_SHELF_M := 0.5
const POLAR_FLATTEN_DEG := 3.0
## How far (in chunks) a player may stray past a pole or the antimeridian before their position is
## folded back onto the canonical planet. The slack means someone pacing back and forth over the
## line does not trigger a fold (and a reload of the streamed window) on every step.
const FOLD_MARGIN_CHUNKS := 16

## Canonical biome keys, in the same order as the fabric biome enum
## (mirrors creature_slice.BIOME_KEYS). Phase 17: biome assignment is per-chunk,
## keyed by (cx, cz) so biome borders are stable across sessions.
const BIOME_KEYS: Array = [
	"TemperateForest",
	"TemperateGrassland",
	"VolcanicBadlands",
	"TwilightGrove",
	"VoidRift",
	"Ocean",
	"Beach",
	"Desert",
	"Tundra",
	"Alpine",
	"Taiga",
	"Savanna",
]

## The world's seed. Phase 41 — this is the world's IDENTITY, not a per-boot
## random: the same seed plus the fixed BIOME_SEED reproduce every height in
## every chunk, so a host and a client (and a reload) generate the same ground
## instead of one side having to ship heightmaps to the other. It is persisted
## on the WORLD record (not on a player record — two players in one world must
## regenerate the same terrain) and travels in the join snapshot.
var _world_seed: int = 0

var _noise := FastNoiseLite.new()

func _ready() -> void:
	WorldShape.warm()   # main thread, before any chunk worker reads the shape
	ClimateField.warm()   # likewise the biome envelope table
	# A fresh world still gets a random seed — but it is remembered and saved,
	# so this is the LAST time the ground changes without a reason.
	_world_seed = randi()
	configure_noise(_noise, _world_seed)

## Phase 73 — the detail-noise settings, shared with the distant ring (which samples the same detail
## on its worker thread from its own noise object, so the ring's edge meets the voxel ground).
static func configure_noise(n: FastNoiseLite, seed_v: int) -> void:
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = seed_v
	n.frequency = 0.05
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 3

## The detail term (0..HEIGHT_SCALE) of `n` (see `configure_noise`) at a world XZ.
static func detail_of(n: FastNoiseLite, x: float, z: float) -> float:
	return (n.get_noise_2d(noise_coord(x), noise_coord(z)) + 1.0) * 0.5 * HEIGHT_SCALE

## Adopt `seed` as the world's identity. Called by game_root with the seed read
## off the world record (authoritative boot) or out of the host's join snapshot
## (client) BEFORE any chunk is requested, so every height in the session comes
## from the same noise field.
func set_world_seed(seed: int) -> void:
	_world_seed = seed
	_corner_mutex.lock()
	_corner_caches.clear()
	_corner_mutex.unlock()
	_noise.seed = seed

## The seed this world is generating from (see set_world_seed).
func get_world_seed() -> int:
	return _world_seed

## Generate a chunk and emit chunk_ready when done.
##
## Phase 42 review — this is a TEST-ONLY path now, and the docstring says so rather than
## leaving a reader to wonder. The streamed production path never announces a heightmap:
## `ChunkManager` asks `generate_heightmap` for the map directly and hands it to the
## worker, precisely so the `chunk_ready` signal does not also trigger VoxelSlice's
## SYNCHRONOUS build (which would build every streamed chunk twice). Nothing in
## `src/` outside `test_suite.gd` calls this; a new production caller should not.
func request_chunk(pos: Vector2i) -> void:
	var heightmap := _generate(pos)
	GameBus.chunk_ready.emit(pos, heightmap)

## Generate a chunk's heightmap WITHOUT announcing it on the bus.
##
## Phase 42 — the streaming manager needs the map in hand to resolve a chunk's
## column table and hand the build to a worker, and the `chunk_ready` signal is the
## trigger for the SYNCHRONOUS build (VoxelSlice listens to it). Emitting it here
## would build every streamed chunk twice: once on the main thread off the signal,
## and once on the worker. So the manager asks for the map directly.
func generate_heightmap(pos: Vector2i) -> Array:
	return _generate(pos)

## Sample height at an arbitrary world position (matches the heightmap formula,
## including spawn-area flattening). Uses the same (raw+1)*0.5*HEIGHT_SCALE
## formula as _generate so values match the heightmap.
func get_height_at(world_pos: Vector2) -> float:
	return _height_at(world_pos.x, world_pos.y)

## Return the biome key for a world position. Phase 17: biome assignment is
## per-chunk — the whole chunk shares one biome, seeded by (cx, cz) so biome
## borders are stable across sessions (deterministic regardless of run).
func get_biome_at(world_pos: Vector2) -> String:
	return get_biome_at_chunk(world_to_chunk(world_pos))

## Return the biome key for a whole chunk, deterministically derived from the
## chunk coordinate and the world seed, so two worlds lay their biome regions out differently.
## Uses integer multiply-mix (Knuth multiplicative hashing) for better distribution
## than converting integers to strings and calling .hash().
func get_biome_at_chunk(chunk_pos: Vector2i) -> String:
	return biome_for_chunk(chunk_pos, _world_seed)

## Phase 43 — the STATIC form of `get_biome_at_chunk`: a pure function of the chunk and the
## world seed (default `BIOME_SEED`), so the ore field (`src/terrain/ore_field.gd`) can ask a vein's biome on
## a worker thread without a terrain-slice reference.
##
## Phase 51 — the climate reads the chunk's latitude and its large-scale altitude (`WorldShape`),
## so poles and peaks are cold and a chunk below sea level is Ocean.
static func biome_for_chunk(chunk_pos: Vector2i, seed_v: int = BIOME_SEED) -> String:
	var w := float(circumference_chunks()) * CHUNK_METERS
	var cx := (float(chunk_pos.x) + 0.5) * CHUNK_METERS
	var cz := (float(chunk_pos.y) + 0.5) * CHUNK_METERS
	return ClimateField.biome_for_chunk(seed_v, chunk_pos, BIOME_KEYS, latitude_of(chunk_pos.y),
		biome_altitude(seed_v, cx, cz, w), circumference_chunks())

## The altitude the biome pick reads: the large-scale shape plus the mean of the 0..HEIGHT_SCALE
## detail noise, so it matches the mean ground the heightmap actually lays down.
## The polar ice shelf counts too, so frozen sea is not picked as Ocean.
static func biome_altitude(seed_v: int, x: float, z: float, w: float) -> float:
	return polar_ground(WorldShape.height(seed_v, x, z, w) + HEIGHT_SCALE * 0.5, z) - WorldShape.sea_level()

## Convert a world XZ position to its containing chunk coordinate.
func world_to_chunk(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / (CHUNK_SIZE * TILE_SIZE)), floori(world_pos.y / (CHUNK_SIZE * TILE_SIZE)))

## Convert a chunk coordinate to the world XZ origin of that chunk (bottom-left
## corner in world units).
func chunk_to_world(chunk_pos: Vector2i) -> Vector2:
	return Vector2(chunk_pos.x * CHUNK_SIZE * TILE_SIZE, chunk_pos.y * CHUNK_SIZE * TILE_SIZE)

static var _circumference_cache := -1
static var _polar_cache := -1

## Fabric value of the `WorldSystem` entity's `field`, or `fallback` without the resource.
static func _world_field(field: String, fallback: float) -> float:
	var ws: Variant = GameData.WORLD_SYSTEMS.get("WorldSystem", null)
	if ws == null:
		return fallback
	var v: Variant = ws.get(field)
	return float(v) if v != null else fallback

## Chunks around the equator; X wraps after this many (1,250,000 at 40,000 km).
static func circumference_chunks() -> int:
	if _circumference_cache < 0:   # the fabric value is fixed for the process; resolve it once
		# A multiple of 4: an even half (the seam sits on a chunk edge) and a whole pole_chunks quarter.
		_circumference_cache = maxi(4, roundi(_world_field("circumferenceKm", DEFAULT_CIRCUMFERENCE_KM) * 1000.0 / CHUNK_METERS / 4.0) * 4)
	return _circumference_cache

## Chunks from the equator to a pole (a quarter of the circumference).
static func pole_chunks() -> int:
	return circumference_chunks() / 4

## |chunk z| at which the polar ice sheet begins: flat ice from here to the pole (`polar_ground`).
static func polar_chunks() -> int:
	if _polar_cache < 0:
		var deg := clampf(_world_field("polarLatitude", DEFAULT_POLAR_LATITUDE), 0.0, 90.0)
		_polar_cache = maxi(1, roundi(pole_chunks() * deg / 90.0))   # at least one walkable row
	return _polar_cache

## Canonical chunk: X wrapped into [-C/2, C/2) where C is the circumference; Z unchanged.
static func wrap_chunk(chunk_pos: Vector2i) -> Vector2i:
	var c := circumference_chunks()
	return Vector2i(posmod(chunk_pos.x + c / 2, c) - c / 2, chunk_pos.y)

## Latitude in degrees (north positive) of the middle of chunk row `chunk_z`. A row past a pole (a
## player within `FOLD_MARGIN_CHUNKS` of it) reads the latitude it really has on the far meridian.
static func latitude_of(chunk_z: int) -> float:
	return _fold_latitude((float(chunk_z) + 0.5) * 90.0 / float(pole_chunks()))

## Longitude in degrees, in [-180, 180), of the west edge of chunk column `chunk_x`.
static func longitude_of(chunk_x: int) -> float:
	var c := circumference_chunks()
	return float(posmod(chunk_x + c / 2, c) - c / 2) * 360.0 / float(c)

## Latitude in degrees at a world Z (metres).
static func latitude_at(world_z: float) -> float:
	return _fold_latitude(world_z / CHUNK_METERS * 90.0 / float(pole_chunks()))

## A map latitude past a pole (over 90 degrees) mirrored back: 91 N is 89 N on the far meridian.
static func _fold_latitude(lat: float) -> float:
	if lat > 90.0:
		return 180.0 - lat
	if lat < -90.0:
		return -180.0 - lat
	return lat

## Longitude in degrees at a world X (metres), wrapped into [-180, 180).
static func longitude_at(world_x: float) -> float:
	return fposmod(world_x / CHUNK_METERS / float(circumference_chunks()) * 360.0 + 180.0, 360.0) - 180.0

## What `/where` prints and the HUD shows: latitude, longitude and altitude of a world position.
static func where_text(world_pos: Vector3) -> String:
	# Round first, then pick the hemisphere: 179.9996 prints as 180.000 (wrap it to -180.000 W),
	# and -0.0004 prints as 0.000 (not "0.000\u00b0W").
	var lat := snappedf(latitude_at(world_pos.z), 0.001)
	var lon := snappedf(longitude_at(world_pos.x), 0.001)
	if lon >= 180.0:
		lon -= 360.0
	return "%.3f\u00b0%s %.3f\u00b0%s  alt %d m" % [
		absf(lat), "N" if lat >= 0.0 else "S",
		absf(lon), "E" if lon >= 0.0 else "W",
		roundi(world_pos.y)]

## True when `chunk_pos` is ground a player can stand on: any longitude, any latitude up to the
## fold slack past each pole. The polar ice is walkable; walking over a pole folds the player onto the
## far meridian (`fold_world_pos`) before they can stray further.
func is_chunk_in_bounds(chunk_pos: Vector2i) -> bool:
	return absi(chunk_pos.y) < pole_chunks() + FOLD_MARGIN_CHUNKS

## True when `chunk_pos` may be streamed in and drawn: every chunk. Rows past a pole are the flat
## ice sheet (`polar_ground`), so a window that reaches over a pole shows ice, never an edge.
func is_chunk_loadable(_chunk_pos: Vector2i) -> bool:
	return true

## True when chunk `c` may lend its biome to a neighbour: its row is a walkable one, short of
## the polar ice at row `radius` (`world_radius_chunks`). One rule for the voxel surface and the minimap.
static func lends_biome(c: Vector2i, radius: int) -> bool:
	return absi(c.y) < radius

## The polar ice line in world units (the playable Z range is +-this).
func world_half_extent() -> float:
	return float(polar_chunks()) * CHUNK_METERS

## Chunk row at which the polar ice begins.
func world_radius_chunks() -> int:
	return polar_chunks()

## The polar ice for ground height `h` at world Z `z` (metres): from `ICE_SHELF_LAT` (judged per
## chunk row, as the frozen-water test `VoxelSlice.is_frozen_chunk` is) the ground is never below the
## ice shelf, and over the last `POLAR_FLATTEN_DEG` before the polar line it eases into the flat
## shelf, which it equals exactly from the line to the pole and past it. Pure and static: the voxel
## ground, the distant ring and the biome pick all apply it.
static func polar_ground(h: float, z: float) -> float:
	var row_lat := absf(latitude_of(floori(z / CHUNK_METERS)))
	if row_lat < ICE_SHELF_LAT:
		return h
	var shelf := WorldShape.sea_level() + ICE_SHELF_M
	h = maxf(h, shelf)
	var line := polar_latitude()
	return lerpf(h, shelf, smoothstep(line - POLAR_FLATTEN_DEG, line, absf(latitude_at(z))))

## The polar line in degrees: `polar_chunks` rows from the equator.
static func polar_latitude() -> float:
	return float(polar_chunks()) * 90.0 / float(pole_chunks())

## Fold a world position `{chunk, local}` that has strayed more than `margin` chunks past a pole or
## the antimeridian back onto the canonical planet. Returns `{pos, folded, turned}`: `pos` the folded
## position (or `wp` itself), `folded` whether it moved, `turned` whether it went over a pole.
##
## Over a pole the planet is crossed as a globe is: the position comes back down the meridian 180
## degrees round, at the latitude it had past the pole (`z' = 2 * pole - z`), heading the other way
## (the caller turns the player's heading and velocity by half a turn). Around the antimeridian X
## moves by one lap. The ground near the poles is a flat ice sheet, so both sides of the fold look
## the same.
static func fold_world_pos(wp: Dictionary, margin: int = FOLD_MARGIN_CHUNKS) -> Dictionary:
	var chunk: Vector2i = wp["chunk"]
	var local: Vector3 = wp["local"]
	var c := circumference_chunks()
	var pole := pole_chunks()
	var turned := false
	if chunk.y >= pole + margin or chunk.y < -pole - margin:
		# Mirror Z about the pole edge (+pole or -pole rows): row r, local l -> row 2p - r - 1, 32 - l.
		var p := pole if chunk.y > 0 else -pole
		chunk = Vector2i(chunk.x + c / 2, 2 * p - chunk.y - 1)
		local = Vector3(local.x, local.y, CHUNK_METERS - local.z)
		turned = true
	var folded := turned or chunk.x >= c / 2 + margin or chunk.x < -c / 2 - margin
	if not folded:
		return {"pos": wp, "folded": false, "turned": false}
	chunk = wrap_chunk(chunk)
	var pos := {"chunk": chunk, "local": local}
	# `CHUNK_METERS - 0` is a whole chunk: renormalise it into the next row.
	if local.z >= CHUNK_METERS:
		pos = {"chunk": chunk + Vector2i(0, 1), "local": Vector3(local.x, local.y, local.z - CHUNK_METERS)}
	return {"pos": pos, "folded": true, "turned": turned}

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _generate(pos: Vector2i) -> Array:
	var out: Array = []
	out.resize(CHUNK_SIZE * CHUNK_SIZE)
	var origin_x := pos.x * CHUNK_SIZE * TILE_SIZE
	var origin_z := pos.y * CHUNK_SIZE * TILE_SIZE
	var w := float(circumference_chunks()) * CHUNK_METERS   # one fabric lookup per chunk, not per tile
	var cache := _corner_cache()   # and one cache lock per chunk
	for ty in range(CHUNK_SIZE):
		for tx in range(CHUNK_SIZE):
			out[ty * CHUNK_SIZE + tx] = _height_wrapped(origin_x + tx * TILE_SIZE, origin_z + ty * TILE_SIZE, w, cache)
	return out

## Continuous terrain height at a world XZ position: the large-scale shape plus the detail noise.
## Shared by _generate and get_height_at so
## the heightmap and direct samples always agree.
func _height_at(x: float, z: float) -> float:
	return _height_wrapped(x, z, float(circumference_chunks()) * CHUNK_METERS, _corner_cache())

## `_height_at` with the circumference `w` (metres) and this thread's corner `cache` already
## resolved, so a whole heightmap takes the cache lock once rather than once per tile.
func _height_wrapped(x: float, z: float, w: float, cache: Array) -> float:
	var half_w := w * 0.5
	var wx := fposmod(x + half_w, w) - half_w   # canonical X in [-w/2, w/2)
	var band := WRAP_BLEND_CHUNKS * CHUNK_METERS
	if wx > half_w - band:
		# East edge: ease into the west edge's heights, so x = +w/2 meets x = -w/2 exactly.
		var t := (wx - (half_w - band)) / band
		t = t * t * (3.0 - 2.0 * t)
		return lerpf(_raw_height_at(wx, z, w, cache), _raw_height_at(wx - w, z, w, cache), t)
	return _raw_height_at(wx, z, w, cache)

## Phase 51 — the large-scale shape (`WorldShape`: ocean basins, coasts, mountains) plus the old
## small-scale noise as detail, never below the fabric's `minHeight` or above `maxHeight`.
##
## The shape has no feature finer than tens of kilometres, so it is sampled at the four corners of
## the 32 m chunk cell holding (x, z) and interpolated bilinearly: a corner is shared by the
## neighbouring cells, so the surface is continuous across chunk borders, and a 64×64 heightmap
## costs four shape evaluations instead of 4096.
func _raw_height_at(x: float, z: float, w: float, cache: Array) -> float:
	var shape := _shape_at(x, z, w, cache)
	var detail := detail_of(_noise, x, z)
	var h := clampf(shape + detail, WorldShape.min_height(), WorldShape.max_height())
	return polar_ground(h, z)

## Phase 63 — half the span (m) over which the detail noise is sampled directly. FastNoiseLite takes
## float32, whose step is 1 m at 10 million metres and would terrace the 0.5 m tiles, so the lattice
## index is folded into this range first (a triangle wave: continuous at the folds, and the identity
## for |coordinate| <= NOISE_SPAN, so ground near the origin is unchanged). 65,536 m keeps float32
## exact to 1/128 m, finer than the 0.125 m step.
const NOISE_SPAN := 65536.0

## The detail-noise coordinate for a world coordinate (double precision in, small and exact out).
static func noise_coord(v: float) -> float:
	var t := fposmod(v + NOISE_SPAN, 4.0 * NOISE_SPAN)
	return t - NOISE_SPAN if t < 2.0 * NOISE_SPAN else 3.0 * NOISE_SPAN - t

## The detail noise term (0..HEIGHT_SCALE) at a world XZ; what `_raw_height_at` adds to the shape.
func detail_at(x: float, z: float) -> float:
	return detail_of(_noise, x, z)

## `WorldShape.height` interpolated between the corners of the chunk cell holding (x, z).
## Phase 68: the corner cache is per thread (chunk workers and the distant-ring worker all sample
## through this; the caller passes its own thread's `cache`, see `_corner_cache`), keyed on the cell, the seed and the circumference, so no thread ever reads
## another's half-written corners.
func _shape_at(x: float, z: float, w: float, cache: Array) -> float:
	var gx := x / CHUNK_METERS
	var gz := z / CHUNK_METERS
	var ix := floori(gx)
	var iz := floori(gz)
	if cache[0] != ix or cache[1] != iz or cache[2] != _world_seed or cache[3] != w:   # a heightmap walks one cell for 4096 tiles: reuse its corners
		var x0 := float(ix) * CHUNK_METERS
		var z0 := float(iz) * CHUNK_METERS
		cache[0] = ix
		cache[1] = iz
		cache[2] = _world_seed
		cache[3] = w
		cache[4] = WorldShape.height(_world_seed, x0, z0, w)
		cache[5] = WorldShape.height(_world_seed, x0 + CHUNK_METERS, z0, w)
		cache[6] = WorldShape.height(_world_seed, x0, z0 + CHUNK_METERS, w)
		cache[7] = WorldShape.height(_world_seed, x0 + CHUNK_METERS, z0 + CHUNK_METERS, w)
	var fx := gx - float(ix)
	var fz := gz - float(iz)
	return lerpf(lerpf(cache[4], cache[5], fx), lerpf(cache[6], cache[7], fx), fz)

## This thread's corner cache: [ix, iz, seed, w, c00, c10, c01, c11]. The map is guarded; each
## entry is only ever touched by the thread that owns it.
var _corner_caches: Dictionary = {}
var _corner_mutex := Mutex.new()

func _corner_cache() -> Array:
	var tid := OS.get_thread_caller_id()
	_corner_mutex.lock()
	var cache: Array = _corner_caches.get(tid, [])
	if cache.is_empty():
		cache = [2147483647, 2147483647, 0, 0.0, 0.0, 0.0, 0.0, 0.0]
		_corner_caches[tid] = cache
	_corner_mutex.unlock()
	return cache
