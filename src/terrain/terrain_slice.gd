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
const HEIGHT_SCALE := 5.0    # world units peak-to-valley (gentle, even terrain)
const BIOME_SEED := 20260815 # fixed seed so biome assignment is deterministic
const ClimateField := preload("res://src/terrain/climate_field.gd")

## The starting area is flattened into a plain field so the player can walk
## freely from spawn without jumping. Spawn centre + radius + flat height below.
const SPAWN_CENTER := Vector2(16.0, 16.0)  # world XZ — matches the player spawn point
const SPAWN_FLATTEN_RADIUS := 20.0         # world units — a generous, walkable starting plain
const SPAWN_HEIGHT := 2.0                  # flat height of the starting plain

## The planet (Phase 50). Globe semantics on a flat chunk grid: X wraps around the
## circumference, Z is latitude and ends in impassable polar ice. The sizes are fabric facts
## (`WorldSystem`: circumferenceKm, polarLatitude); these are the fallbacks for a rig without
## the generated resources.
const DEFAULT_CIRCUMFERENCE_KM := 40000.0
const DEFAULT_POLAR_LATITUDE := 85.0
const CHUNK_METERS := CHUNK_SIZE * TILE_SIZE
## Width of the east-edge band over which heights blend into the west edge's, so the wrap seam
## has no cliff (the noise is not periodic).
const WRAP_BLEND_CHUNKS := 8

## Canonical biome keys, in the same order as the fabric biome enum
## (mirrors creature_slice.BIOME_KEYS). Phase 17: biome assignment is per-chunk,
## keyed by (cx, cz) so biome borders are stable across sessions.
const BIOME_KEYS: Array = [
	"TemperateForest",
	"TemperateGrassland",
	"VolcanicBadlands",
	"TwilightGrove",
	"VoidRift",
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
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	# A fresh world still gets a random seed — but it is remembered and saved,
	# so this is the LAST time the ground changes without a reason.
	_world_seed = randi()
	_noise.seed = _world_seed
	_noise.frequency = 0.05
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 3

## Adopt `seed` as the world's identity. Called by game_root with the seed read
## off the world record (authoritative boot) or out of the host's join snapshot
## (client) BEFORE any chunk is requested, so every height in the session comes
## from the same noise field.
func set_world_seed(seed: int) -> void:
	_world_seed = seed
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
static func biome_for_chunk(chunk_pos: Vector2i, seed_v: int = BIOME_SEED) -> String:
	return ClimateField.biome_for_chunk(seed_v, chunk_pos, BIOME_KEYS)

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

## |chunk z| at which the polar ice begins (the chunks beyond it are not walkable).
static func polar_chunks() -> int:
	if _polar_cache < 0:
		var deg := clampf(_world_field("polarLatitude", DEFAULT_POLAR_LATITUDE), 0.0, 90.0)
		_polar_cache = maxi(1, roundi(pole_chunks() * deg / 90.0))   # at least one walkable row
	return _polar_cache

## Canonical chunk: X wrapped into [-C/2, C/2) where C is the circumference; Z unchanged.
static func wrap_chunk(chunk_pos: Vector2i) -> Vector2i:
	var c := circumference_chunks()
	return Vector2i(posmod(chunk_pos.x + c / 2, c) - c / 2, chunk_pos.y)

## Latitude in degrees (north positive) of the middle of chunk row `chunk_z`.
static func latitude_of(chunk_z: int) -> float:
	return (float(chunk_z) + 0.5) * 90.0 / float(pole_chunks())

## Longitude in degrees, in [-180, 180), of the west edge of chunk column `chunk_x`.
static func longitude_of(chunk_x: int) -> float:
	var c := circumference_chunks()
	return float(posmod(chunk_x + c / 2, c) - c / 2) * 360.0 / float(c)

## Latitude in degrees at a world Z (metres).
static func latitude_at(world_z: float) -> float:
	return world_z / CHUNK_METERS * 90.0 / float(pole_chunks())

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

## True when `chunk_pos` is walkable ground: any longitude, short of the polar ice.
func is_chunk_in_bounds(chunk_pos: Vector2i) -> bool:
	return absi(chunk_pos.y) < polar_chunks()

## The polar ice line in world units (the playable Z range is +-this).
func world_half_extent() -> float:
	return float(polar_chunks()) * CHUNK_METERS

## Chunk row at which the polar ice begins.
func world_radius_chunks() -> int:
	return polar_chunks()

## Keep the player short of the polar ice. X is free: it wraps. Y is left untouched
## (gravity/terrain handle vertical). Insets the boundary by 2 m so the body stays on the
## final chunk's collision instead of straddling the exact edge.
func clamp_to_world(pos: Vector3) -> Vector3:
	# Walkable rows are |chunk z| < polar_chunks, i.e. z in [-(polar-1)*32, polar*32).
	var polar := polar_chunks()
	var north := float(polar) * CHUNK_METERS - 2.0
	var south := -float(polar - 1) * CHUNK_METERS + 2.0
	return Vector3(pos.x, pos.y, clampf(pos.z, minf(south, north), north))

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _generate(pos: Vector2i) -> Array:
	var out: Array = []
	out.resize(CHUNK_SIZE * CHUNK_SIZE)
	var origin_x := pos.x * CHUNK_SIZE * TILE_SIZE
	var origin_z := pos.y * CHUNK_SIZE * TILE_SIZE
	var w := float(circumference_chunks()) * CHUNK_METERS   # one fabric lookup per chunk, not per tile
	for ty in range(CHUNK_SIZE):
		for tx in range(CHUNK_SIZE):
			out[ty * CHUNK_SIZE + tx] = _height_wrapped(origin_x + tx * TILE_SIZE, origin_z + ty * TILE_SIZE, w)
	return out

## Continuous terrain height at a world XZ position: noise scaled by HEIGHT_SCALE,
## then flattened to a plain field inside SPAWN_FLATTEN_RADIUS of SPAWN_CENTER so
## the player starts on walkable ground. Shared by _generate and get_height_at so
## the heightmap and direct samples always agree.
func _height_at(x: float, z: float) -> float:
	return _height_wrapped(x, z, float(circumference_chunks()) * CHUNK_METERS)

## `_height_at` with the circumference `w` (metres) already resolved.
func _height_wrapped(x: float, z: float, w: float) -> float:
	var half_w := w * 0.5
	var wx := fposmod(x + half_w, w) - half_w   # canonical X in [-w/2, w/2)
	var band := WRAP_BLEND_CHUNKS * CHUNK_METERS
	if wx > half_w - band:
		# East edge: ease into the west edge's heights, so x = +w/2 meets x = -w/2 exactly.
		var t := (wx - (half_w - band)) / band
		t = t * t * (3.0 - 2.0 * t)
		return lerpf(_raw_height_at(wx, z), _raw_height_at(wx - w, z), t)
	return _raw_height_at(wx, z)

func _raw_height_at(x: float, z: float) -> float:
	var raw := _noise.get_noise_2d(x, z)
	var h := (raw + 1.0) * 0.5 * HEIGHT_SCALE
	var dx := x - SPAWN_CENTER.x
	var dz := z - SPAWN_CENTER.y
	var d := sqrt(dx * dx + dz * dz)
	if d < SPAWN_FLATTEN_RADIUS:
		var t := d / SPAWN_FLATTEN_RADIUS
		t = t * t * (3.0 - 2.0 * t)   # smoothstep: 0 at centre → 1 at edge
		h = lerp(SPAWN_HEIGHT, h, t)
	return h
