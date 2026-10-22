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
## walkable polar caps: frozen sea is an ice shelf from `ICE_SHELF_LAT`, and within a few km of
## each pole the ground eases into a snow field that depends on the distance to the pole alone,
## so the pole can be crossed; 6 = Phase 122 far detail noise: the triangle-wave fold that mirrored
## the world beyond `NOISE_SPAN` is replaced by a hashed per-cell offset blended across cell borders.
## Version 6 worlds also carry 24 m of extra ground below the old bedrock floor, so a chunk written
## before that change has a lower floor than one written after it. 7 = Phase 127 frontier corners are
## weighted by the blend itself, so unrecorded land beside a record eases into the generator differently.
## 8 = the pole's snow field is flat: its drifts ran along X as ridges whose voxel steps drew as lines.
const WORLDGEN_VERSION := 8

## Phase 106 — a hash of every fabric parameter world-gen reads that `WORLDGEN_VERSION` cannot see:
## the `WorldSystem` shape fields (`sea`, `min/max height`, `oceanShare`, `ridgeAmplitude`,
## `heightSpline`) and the warmed biome envelope table in sorted key order. FNV-1a over UTF-8
## (as `ClimateField.niche_salt`), not `String.hash()`, so it is stable across Godot versions.
## Editing a biome envelope or a shape field changes it with no code change.
static func worldgen_fingerprint() -> int:
	if _fingerprint_cache < 0:
		_fingerprint_cache = compute_worldgen_fingerprint()
	return _fingerprint_cache

static var _fingerprint_cache := -1

## Forget the cached fingerprint; whatever edits the shape or envelopes in place (a test standing in
## for a generator change) calls this before reading `worldgen_fingerprint()` again.
static func reset_fingerprint_cache() -> void:
	_fingerprint_cache = -1

static func compute_worldgen_fingerprint() -> int:
	var fields := WorldShape.fingerprint_fields()
	var parts: PackedStringArray = []
	for f in fields:
		if f is Array:
			var pts: PackedStringArray = []
			for pt in f:
				pts.append("%.6f:%.6f" % [float(pt[0]), float(pt[1])])
			parts.append("|".join(pts))
		else:
			parts.append("%.6f" % float(f))
	parts.append(ClimateField.envelope_signature())
	var h := 2166136261
	for b in "#".join(parts).to_utf8_buffer():
		h = ((h ^ b) * 16777619) & 0xffffffff
	return h

const BIOME_SEED := 20260815 # fixed seed so biome assignment is deterministic
const ClimateField := preload("res://src/terrain/climate_field.gd")
const I18n := preload("res://src/core/i18n.gd")
const WorldShape := preload("res://src/terrain/world_shape.gd")
const ChunkRecords := preload("res://src/terrain/chunk_records.gd")
const SeamWrap := preload("res://src/terrain/seam_wrap.gd")
const NativeBuilder := preload("res://src/terrain/native_builder.gd")

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
## (`sea level + ICE_SHELF_M`, rolling by up to `ICE_RELIEF_M`), so there is no liquid water under
## the ice to fall into. Land keeps its own relief (the snow is the colour, `VoxelSlice.icy`).
const ICE_SHELF_LAT := 80.0
const ICE_SHELF_M := 0.5
const ICE_RELIEF_M := 2.0
const ICE_RELIEF_CELL_M := 64.0
## Around each pole the ground eases (from `POLE_FIELD_OUTER_M` to `POLE_FIELD_INNER_M` from the
## pole) into a flat snow field (`pole_field`), the same everywhere around the pole. A pole crossing
## (`fold_world_pos`) lands at the same distance on the far meridian, so inside that radius both
## sides are the same ground; it also reaches past everything a player near the pole can see.
## (On a real globe that is what the map shows anyway: near a pole a metre of ground spans a
## huge stretch of longitude, so any feature there is drawn as a band along the map's X.)
const POLE_FIELD_INNER_M := 2500.0
const POLE_FIELD_OUTER_M := 5000.0
## Height of the flat snow field above the ice shelf: clear of the Beach band (altitude under 1.5 m),
## so the pole stays Tundra.
const POLE_SNOW_M := 3.0
## How far (in chunks) a player may stray past a pole or the antimeridian before their position is
## folded back onto the canonical planet. The slack means someone pacing back and forth over the
## line does not trigger a fold (and a re-stream of the window) on every step. The fold itself is
## not seen (Phase 120, `fold_scene_transform`): the ground is carried across it until the folded
## window has been rebuilt. That needs the snow field to cover the slack plus the distant ring.
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
	var ax := _axis_cells(x)
	var az := _axis_cells(z)
	var seed_v := n.seed
	var total := 0.0
	for i in range(2):
		var wx: float = ax[1] if i == 1 else 1.0 - ax[1]
		if wx <= 0.0:
			continue
		for j in range(2):
			var wz: float = az[1] if j == 1 else 1.0 - az[1]
			if wz <= 0.0:
				continue
			var cx: int = ax[2] if i == 1 else ax[0]
			var cz: int = az[2] if j == 1 else az[0]
			var lx: float = x - float(cx) * 2.0 * NOISE_SPAN
			var lz: float = z - float(cz) * 2.0 * NOISE_SPAN
			var off := cell_offset(seed_v, cx, cz)
			total += wx * wz * n.get_noise_2d(lx + off.x, lz + off.y)
	return (total + 1.0) * 0.5 * HEIGHT_SCALE

## Adopt `seed` as the world's identity. Called by game_root with the seed read
## off the world record (authoritative boot) or out of the host's join snapshot
## (client) BEFORE any chunk is requested, so every height in the session comes
## from the same noise field.
func set_world_seed(seed_v: int) -> void:
	_world_seed = seed_v
	_corner_mutex.lock()
	_corner_caches.clear()
	_corner_mutex.unlock()
	_noise.seed = seed_v

## The seed this world is generating from (see set_world_seed).
func get_world_seed() -> int:
	return _world_seed

## Phase 141 — a copy of the detail noise, for a worker task that calls `heightmap_for`: the task
## owns its copy, so it never shares this slice's noise object (or the node) with the main thread.
func detail_noise_copy() -> FastNoiseLite:
	return _noise.duplicate() as FastNoiseLite

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
##
## Phase 108 — a chunk with a generation record answers with the recorded biome: the record, not the
## generator, is what the world looked like when the chunk was first visited.
static func biome_for_chunk(chunk_pos: Vector2i, seed_v: int = BIOME_SEED) -> String:
	if not ChunkRecords.is_empty():
		var rec := ChunkRecords.get_record(wrap_chunk(chunk_pos))
		if not rec.is_empty():
			return str(rec["b"])
	return generated_biome_for_chunk(chunk_pos, seed_v)

## The biome the CURRENT generator picks for a chunk, ignoring any record. What a new record stores.
static func generated_biome_for_chunk(chunk_pos: Vector2i, seed_v: int = BIOME_SEED) -> String:
	var w := float(circumference_chunks()) * CHUNK_METERS
	var cx := (float(chunk_pos.x) + 0.5) * CHUNK_METERS
	var cz := (float(chunk_pos.y) + 0.5) * CHUNK_METERS
	return ClimateField.biome_for_chunk(seed_v, chunk_pos, BIOME_KEYS, latitude_of(chunk_pos.y),
		biome_altitude(seed_v, cx, cz, w), circumference_chunks())

## The altitude the biome pick reads: the large-scale shape plus the mean of the 0..HEIGHT_SCALE
## detail noise, so it matches the mean ground the heightmap actually lays down.
## The polar ice shelf counts too, so frozen sea is not picked as Ocean.
static func biome_altitude(seed_v: int, x: float, z: float, w: float) -> float:
	return polar_ground(seed_v, WorldShape.height(seed_v, x, z, w) + HEIGHT_SCALE * 0.5, x, z, w) - WorldShape.sea_level()

## The rounding step of a stored height (`RegionStore.GEN_HEIGHT_STEP` is this).
const GEN_HEIGHT_STEP := 0.0001

## The generator's height at lattice corner `p` (the north-west corner of chunk `p`), clamped to the
## `WorldShape` range, unrounded. Shared by `generation_record` and `Frontier`.
static func generated_corner_height(p: Vector2i, seed_v: int) -> float:
	var w := float(circumference_chunks()) * CHUNK_METERS
	var h := WorldShape.height(seed_v, float(p.x) * CHUNK_METERS, float(p.y) * CHUNK_METERS, w)
	return clampf(h, WorldShape.min_height(), WorldShape.max_height())

## Phase 108 — the generation record the CURRENT generator would write for `chunk` (canonical):
## `{ v, f, b, h }` with `h` the `WorldShape` heights at the cell's corners in the order
## (x0,z0) (x1,z0) (x0,z1) (x1,z1), rounded as `RegionStore.normalize_gen` stores them. Pure.
static func generation_record(chunk: Vector2i, seed_v: int) -> Dictionary:
	var hs: Array = []
	for c in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		hs.append(snappedf(generated_corner_height(chunk + c, seed_v), GEN_HEIGHT_STEP))
	return { "v": WORLDGEN_VERSION, "f": worldgen_fingerprint(), "b": generated_biome_for_chunk(chunk, seed_v), "h": hs }

## Phase 108 — `WorldShape.height` for a read that is not a chunk heightmap (the distant ring): inside a
## recorded chunk's cell the recorded corners are interpolated, as `_shape_at` does; elsewhere the
## generator answers. Pure; reads the record table only.
static func shape_height(seed_v: int, x: float, z: float, w: float) -> float:
	if not ChunkRecords.is_empty():
		var rec := ChunkRecords.get_record(wrap_chunk(Vector2i(floori(x / CHUNK_METERS), floori(z / CHUNK_METERS))))
		if not rec.is_empty():
			return _record_height(rec, x, z)
	return WorldShape.height(seed_v, x, z, w)

## The recorded corners of `rec` interpolated at world XZ.
static func _record_height(rec: Dictionary, x: float, z: float) -> float:
	var gx := x / CHUNK_METERS
	var gz := z / CHUNK_METERS
	var rh: Array = rec["h"]
	var fx := gx - floorf(gx)
	var fz := gz - floorf(gz)
	return lerpf(lerpf(float(rh[0]), float(rh[1]), fx), lerpf(float(rh[2]), float(rh[3]), fx), fz)

## Phase 120 — `shape_height` against an immutable snapshot (`ChunkRecords.snapshot_near`) instead of the
## live table, so a worker's whole build sees one set of records. An empty snapshot is the plain generator.
static func shape_height_in(snap: Dictionary, seed_v: int, x: float, z: float, w: float) -> float:
	if not snap.is_empty():
		var gx := x / CHUNK_METERS
		var gz := z / CHUNK_METERS
		var ix := floori(gx)
		var iz := floori(gz)
		var rec: Dictionary = snap.get(wrap_chunk(Vector2i(ix, iz)), {})
		if not rec.is_empty():
			var rh: Array = rec["h"]
			var fx := gx - float(ix)
			var fz := gz - float(iz)
			return lerpf(lerpf(float(rh[0]), float(rh[1]), fx), lerpf(float(rh[2]), float(rh[3]), fx), fz)
	return WorldShape.height(seed_v, x, z, w)

## Phase 120 — fill the static caches `polar_ground` reads (circumference, polar rows) on the calling
## (main) thread, so no worker is the first to resolve them.
static func warm_polar_caches() -> void:
	WorldShape.warm()
	circumference_chunks()
	polar_chunks()

## Test-visible: how many times a cache above was first filled off the main thread.
static var worker_cache_fills := 0

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
		if OS.get_thread_caller_id() != OS.get_main_thread_id():
			worker_cache_fills += 1
		# A multiple of 4: an even half (the seam sits on a chunk edge) and a whole pole_chunks quarter.
		_circumference_cache = maxi(4, roundi(_world_field("circumferenceKm", DEFAULT_CIRCUMFERENCE_KM) * 1000.0 / CHUNK_METERS / 4.0) * 4)
	return _circumference_cache

## Chunks from the equator to a pole (a quarter of the circumference).
static func pole_chunks() -> int:
	@warning_ignore("integer_division")
	return circumference_chunks() / 4

## |chunk z| of the polar line (the fabric's `polarLatitude`): rows past it lend no biome to their
## neighbours (`lends_biome`) and no new player is placed beyond it.
static func polar_chunks() -> int:
	if _polar_cache < 0:
		if OS.get_thread_caller_id() != OS.get_main_thread_id():
			worker_cache_fills += 1
		var deg := clampf(_world_field("polarLatitude", DEFAULT_POLAR_LATITUDE), 0.0, 90.0)
		_polar_cache = maxi(1, roundi(pole_chunks() * deg / 90.0))   # at least one walkable row
	return _polar_cache

## Canonical chunk: X wrapped into [-C/2, C/2) where C is the circumference; Z unchanged.
static func wrap_chunk(chunk_pos: Vector2i) -> Vector2i:
	var c := circumference_chunks()
	return Vector2i(SeamWrap.wrap_i(chunk_pos.x, c), chunk_pos.y)

## Latitude in degrees (north positive) of the middle of chunk row `chunk_z`. A row past a pole (a
## player within `FOLD_MARGIN_CHUNKS` of it) reads the latitude it really has on the far meridian.
static func latitude_of(chunk_z: int) -> float:
	return _fold_latitude((float(chunk_z) + 0.5) * 90.0 / float(pole_chunks()))

## Longitude in degrees, in [-180, 180), of the west edge of chunk column `chunk_x`.
static func longitude_of(chunk_x: int) -> float:
	var c := circumference_chunks()
	@warning_ignore("integer_division")
	return float(SeamWrap.wrap_i(chunk_x, c)) * 360.0 / float(c)

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
	return SeamWrap.wrap_f(world_x / CHUNK_METERS / float(circumference_chunks()) * 360.0, 360.0)

## What `/where` prints and the HUD shows: map X/Y and altitude of a world position.
static func where_text(world_pos: Vector3) -> String:
	return I18n.t("map.where", [xy_text(world_pos.x, world_pos.z), roundi(world_pos.y)])

## "X 1234  Y -567": a world X/Z in whole metres, the map's two axes (the Map window's hover reads this too).
static func xy_text(world_x: float, world_z: float) -> String:
	return I18n.t("map.xy", [roundi(world_x), roundi(world_z)])

## True when `chunk_pos` is ground a player can stand on: any longitude, any latitude up to the
## fold slack past each pole. The polar ice is walkable; walking over a pole folds the player onto the
## far meridian (`fold_world_pos`) before they can stray further. Streaming is NOT limited to this:
## rows past a pole are the pole's snow field (`polar_ground`), so a window over a pole shows snow.
func is_chunk_in_bounds(chunk_pos: Vector2i) -> bool:
	return absi(chunk_pos.y) < pole_chunks() + FOLD_MARGIN_CHUNKS

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

## The polar ice for ground height `h` at world (x, z) (metres), `w` the circumference: from
## `ICE_SHELF_LAT` (judged per chunk row, as the frozen-water test `VoxelSlice.is_frozen_chunk` is)
## the ground is never below the rolling ice shelf, and near each pole it eases into the pole's snow
## field (`pole_field`). Pure and static: the voxel ground, the distant ring and the biome pick all
## apply it.
##
## Phase 141 — two shortcuts that leave every value unchanged. The shelf noise lies in [0, 1], so
## ground already at or above the shelf's highest point skips it. And everything after the shelf
## (the latitude, the distance to the pole, the snow field) depends on `z` alone, so `row` — a memo
## from `new_polar_row`, owned by the caller's thread — keeps it for the last `z`: a heightmap row
## pays it once instead of 64 times. Pass `[]` for no memo.
static func polar_ground(seed_v: int, h: float, x: float, z: float, w: float, row: Array = []) -> float:
	var row_lat := absf(latitude_of(floori(z / CHUNK_METERS)))
	if row_lat < ICE_SHELF_LAT:
		return h
	var sea := WorldShape.sea_level()
	if h < sea + ICE_SHELF_M + ICE_RELIEF_M:
		var cells := maxi(1, roundi(w / ICE_RELIEF_CELL_M))
		var shelf := sea + ICE_SHELF_M + ICE_RELIEF_M * WorldShape._noise(seed_v, x, z, w, cells, 61)
		h = maxf(h, shelf)
	var t: float
	var field: float
	if not row.is_empty() and row[0] == z and row[1] == seed_v and row[2] == w:
		t = row[3]
		field = row[4]
	else:
		var lat := latitude_at(z)
		var from_pole := (90.0 - absf(lat)) * float(pole_chunks()) * CHUNK_METERS / 90.0
		t = 0.0
		field = 0.0
		if from_pole < POLE_FIELD_OUTER_M:
			t = 1.0 - smoothstep(POLE_FIELD_INNER_M, POLE_FIELD_OUTER_M, from_pole)
			field = pole_field()
		if not row.is_empty():
			row[0] = z
			row[1] = seed_v
			row[2] = w
			row[3] = t
			row[4] = field
	if t == 0.0:
		return h
	return lerpf(h, field, t)

## An empty polar-row memo for `polar_ground`, matching no row.
static func new_polar_row() -> Array:
	return [NAN, 0, 0.0, 0.0, 0.0]

## The snow field around a pole: a flat sheet `POLE_SNOW_M` above the ice shelf. It must not vary
## along X (a fold lands on the far meridian), so any relief would be a function of the distance to
## the pole alone, and on the map's grid that is a set of straight ridges along X: the 0.125 m voxel
## steps of those ridges drew as long parallel lines to the horizon (WORLDGEN_VERSION 8).
static func pole_field() -> float:
	return WorldShape.sea_level() + ICE_SHELF_M + POLE_SNOW_M

## Fold a world position `{chunk, local}` that has strayed more than `margin` chunks past a pole or
## the antimeridian back onto the canonical planet. Returns `{pos, folded, turned}`: `pos` the folded
## position (or `wp` itself), `folded` whether it moved, `turned` whether it went over a pole.
##
## Over a pole the planet is crossed as a globe is: the position comes back down the meridian 180
## degrees round, at the latitude it had past the pole (`z' = 2 * pole - z`), heading the other way
## (the caller turns the player's heading and velocity by half a turn). Around the antimeridian X
## moves by one lap. The ground near a pole is the flat snow field (`pole_field`), so both sides of the
## fold look the same.
static func fold_world_pos(wp: Dictionary, margin: int = FOLD_MARGIN_CHUNKS) -> Dictionary:
	var chunk: Vector2i = wp["chunk"]
	var local: Vector3 = wp["local"]
	var c := circumference_chunks()
	var pole := pole_chunks()
	var turned := false
	if chunk.y >= pole + margin or chunk.y < -pole - margin:
		# Mirror Z about the pole edge (+pole or -pole rows): row r, local l -> row 2p - r - 1, 32 - l.
		var p := pole if chunk.y > 0 else -pole
		@warning_ignore("integer_division")
		chunk = Vector2i(chunk.x + c / 2, 2 * p - chunk.y - 1)
		local = Vector3(local.x, local.y, CHUNK_METERS - local.z)
		turned = true
	@warning_ignore("integer_division")
	var folded := turned or chunk.x >= c / 2 + margin or chunk.x < -c / 2 - margin
	if not folded:
		return {"pos": wp, "folded": false, "turned": false}
	chunk = wrap_chunk(chunk)
	var pos := {"chunk": chunk, "local": local}
	# `CHUNK_METERS - 0` is a whole chunk: renormalise it into the next row.
	if local.z >= CHUNK_METERS:
		pos = {"chunk": chunk + Vector2i(0, 1), "local": Vector3(local.x, local.y, local.z - CHUNK_METERS)}
	return {"pos": pos, "folded": true, "turned": turned}

## Phase 145 — the same fold applied to a position that did not trigger it: what a creature or a tree
## held in the window becomes when the player's crossing re-keys the world. `turned` and `pole_sign`
## (+1 north, -1 south) come from the player's own fold (`fold_world_pos` plus the sign of the row they
## crossed from); `turned` false is the antimeridian lap. `wp` is a `{chunk, local}` position.
static func fold_world_pos_like(wp: Dictionary, turned: bool, pole_sign: int) -> Dictionary:
	var chunk: Vector2i = wp["chunk"]
	var local: Vector3 = wp["local"]
	if turned:
		var p := pole_chunks() if pole_sign >= 0 else -pole_chunks()
		@warning_ignore("integer_division")
		chunk = Vector2i(chunk.x + circumference_chunks() / 2, 2 * p - chunk.y - 1)
		local = Vector3(local.x, local.y, CHUNK_METERS - local.z)
	chunk = wrap_chunk(chunk)
	if local.z >= CHUNK_METERS:
		return {"chunk": chunk + Vector2i(0, 1), "local": Vector3(local.x, local.y, local.z - CHUNK_METERS)}
	return {"chunk": chunk, "local": local}

## `fold_world_pos_like` for a world position in metres (the frame creature and tree records use).
static func fold_world_vec_like(world: Vector3, turned: bool, pole_sign: int) -> Vector3:
	var wp := fold_world_pos_like({"chunk": Vector2i(floori(world.x / CHUNK_METERS), floori(world.z / CHUNK_METERS)),
			"local": Vector3(fposmod(world.x, CHUNK_METERS), world.y, fposmod(world.z, CHUNK_METERS))}, turned, pole_sign)
	var c: Vector2i = wp["chunk"]
	var l: Vector3 = wp["local"]
	return Vector3(c.x * CHUNK_METERS + l.x, l.y, c.y * CHUNK_METERS + l.z)

## Phase 120 — the scene transform of a fold: it carries what the player saw before it to where the
## player stands after it, so the view does not change. `before` and `after` are the body's scene
## positions either side of the fold. A pole fold turns the player half a turn (`PlayerSlice.fold_to`),
## so the scene turns with them about the body; the result is snapped onto the chunk grid (scene chunk
## corners are whole multiples of CHUNK_METERS), which moves the ground at most half a chunk along
## its row. Over a pole that ground is the pole's snow field, the same all along the row and the same
## on both sides of the pole, so the carried scene matches the one rebuilt in the folded frame.
static func fold_scene_transform(before: Vector3, after: Vector3, turned: bool) -> Transform3D:
	var turn := Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, -1.0)) if turned else Basis.IDENTITY
	var origin := after - turn * before
	origin.x = snappedf(origin.x, CHUNK_METERS)
	origin.z = snappedf(origin.z, CHUNK_METERS)
	return Transform3D(turn, origin)

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _generate(pos: Vector2i) -> Array:
	return heightmap_for(pos, _world_seed, _noise)

## Phase 141 — the heightmap of chunk `pos` with no terrain-slice node: what `generate_heightmap`
## returns, as a pure function of the chunk, the world seed and a detail noise configured for that
## seed (`configure_noise`). A chunk-build worker calls this with its own noise object, so the noise
## no longer runs on the main thread (it was 14 ms per chunk at the equator and 36 ms by a pole).
## Recorded corner heights are read from `ChunkRecords`, which locks its own table.
static func heightmap_for(pos: Vector2i, seed_v: int, noise: FastNoiseLite) -> Array:
	if NativeBuilder.use_native("heightmap_for"):   # Phase 167: same result, computed in C++
		return NativeBuilder.builder().call("heightmap_for", pos, seed_v, noise, _native_cfg(pos)) as Array
	return heightmap_for_gd(pos, seed_v, noise)

## Phase 167 — what the native `heightmap_for` cannot read itself: the fabric's shape parameters and
## the recorded corner heights of the (at most two) chunk cells the chunk's tiles sample, keyed by the
## un-wrapped cell the native code looks up (`records`: {Vector2i cell: PackedFloat64Array [h00, h10,
## h01, h11]}). The first cell is the chunk's own, the second the one a tile in the antimeridian
## blend band reads at `x - w`.
static func _native_cfg(pos: Vector2i) -> Dictionary:
	var c := circumference_chunks()
	var records := {}
	if not ChunkRecords.is_empty():
		var own := wrap_chunk(pos)
		for cell in [own, Vector2i(own.x - c, own.y)]:
			var rec := ChunkRecords.get_record(wrap_chunk(cell))
			if not rec.is_empty():
				var rh: Array = rec["h"]
				records[cell] = PackedFloat64Array([float(rh[0]), float(rh[1]), float(rh[2]), float(rh[3])])
	return {
		"circumference_chunks": c,
		"sea": WorldShape.sea_level(),
		"min_height": WorldShape.min_height(),
		"max_height": WorldShape.max_height(),
		"ridge_amplitude": WorldShape.ridge_amplitude(),
		"spline": WorldShape.spline(),
		"records": records,
	}

## The GDScript reference of `heightmap_for`: the fallback without the native extension, and what the
## suite compares the native result against.
static func heightmap_for_gd(pos: Vector2i, seed_v: int, noise: FastNoiseLite) -> Array:
	var out: Array = []
	out.resize(CHUNK_SIZE * CHUNK_SIZE)
	var origin_x := pos.x * CHUNK_SIZE * TILE_SIZE
	var origin_z := pos.y * CHUNK_SIZE * TILE_SIZE
	var w := float(circumference_chunks()) * CHUNK_METERS   # one fabric lookup per chunk, not per tile
	var cache := new_corner_cache()   # private to this call, so any thread may run it
	var row := new_polar_row()
	for ty in range(CHUNK_SIZE):
		for tx in range(CHUNK_SIZE):
			out[ty * CHUNK_SIZE + tx] = height_wrapped_in(seed_v, noise, origin_x + tx * TILE_SIZE, origin_z + ty * TILE_SIZE, w, cache, row)
	return out

## Phase 141 — only the edge of chunk `pos` that a neighbour's one-tile seam ring reads. `side`
## names the edge (each component in -1..1): side.x = -1 is the west column (x = 0), 1 the east one
## (x = CHUNK_SIZE - 1), 0 every column; side.y picks rows the same way, so a diagonal neighbour is
## one corner tile. The neighbour at offset `d` from a chunk reads this chunk's `-d` edge. The result
## has the full map's shape and indexing, with null in every tile the ring never reads: 64 noise
## samples instead of 4096. Pure.
static func heightmap_strip_for(pos: Vector2i, side: Vector2i, seed_v: int, noise: FastNoiseLite) -> Array:
	var out: Array = []
	out.resize(CHUNK_SIZE * CHUNK_SIZE)
	var origin_x := pos.x * CHUNK_SIZE * TILE_SIZE
	var origin_z := pos.y * CHUNK_SIZE * TILE_SIZE
	var w := float(circumference_chunks()) * CHUNK_METERS
	var cache := new_corner_cache()
	var row := new_polar_row()
	var xs: Array = range(CHUNK_SIZE) if side.x == 0 else [0 if side.x < 0 else CHUNK_SIZE - 1]
	var zs: Array = range(CHUNK_SIZE) if side.y == 0 else [0 if side.y < 0 else CHUNK_SIZE - 1]
	for ty in zs:
		for tx in xs:
			out[ty * CHUNK_SIZE + tx] = height_wrapped_in(seed_v, noise, origin_x + tx * TILE_SIZE, origin_z + ty * TILE_SIZE, w, cache, row)
	return out

## Continuous terrain height at a world XZ position: the large-scale shape plus the detail noise.
## Shared by _generate and get_height_at so
## the heightmap and direct samples always agree.
func _height_at(x: float, z: float) -> float:
	return _height_wrapped(x, z, float(circumference_chunks()) * CHUNK_METERS, _corner_cache())

## `_height_at` with the circumference `w` (metres) and this thread's corner `cache` already
## resolved, so a whole heightmap takes the cache lock once rather than once per tile.
func _height_wrapped(x: float, z: float, w: float, cache: Array) -> float:
	return height_wrapped_in(_world_seed, _noise, x, z, w, cache, [])

## The static form of `_height_wrapped`: `cache` a corner cache (`new_corner_cache`) owned by the
## calling thread, `row` an optional polar-row memo (`new_polar_row`, or `[]` for none).
static func height_wrapped_in(seed_v: int, noise: FastNoiseLite, x: float, z: float, w: float, cache: Array, row: Array) -> float:
	var half_w := w * 0.5
	var wx := SeamWrap.wrap_f(x, w)   # canonical X in [-w/2, w/2)
	var band := WRAP_BLEND_CHUNKS * CHUNK_METERS
	if wx > half_w - band:
		# East edge: ease into the west edge's heights, so x = +w/2 meets x = -w/2 exactly.
		var t := (wx - (half_w - band)) / band
		t = t * t * (3.0 - 2.0 * t)
		return lerpf(raw_height_in(seed_v, noise, wx, z, w, cache, row), raw_height_in(seed_v, noise, wx - w, z, w, cache, row), t)
	return raw_height_in(seed_v, noise, wx, z, w, cache, row)

## Phase 51 — the large-scale shape (`WorldShape`: ocean basins, coasts, mountains) plus the old
## small-scale noise as detail, never below the fabric's `minHeight` or above `maxHeight`.
##
## The shape has no feature finer than tens of kilometres, so it is sampled at the four corners of
## the 32 m chunk cell holding (x, z) and interpolated bilinearly: a corner is shared by the
## neighbouring cells, so the surface is continuous across chunk borders, and a 64×64 heightmap
## costs four shape evaluations instead of 4096.
func _raw_height_at(x: float, z: float, w: float, cache: Array) -> float:
	return raw_height_in(_world_seed, _noise, x, z, w, cache, [])

## The static form of `_raw_height_at` (see `height_wrapped_in`).
static func raw_height_in(seed_v: int, noise: FastNoiseLite, x: float, z: float, w: float, cache: Array, row: Array) -> float:
	var shape := shape_cached(seed_v, x, z, w, cache)
	var detail := detail_of(noise, x, z)
	var h := clampf(shape + detail, WorldShape.min_height(), WorldShape.max_height())
	return polar_ground(seed_v, h, x, z, w, row)

## Phase 122 — the spawn point at height `y`: the one place the spawn X/Z lives (`WorldShape.SPAWN_CENTER`,
## the centre of the spawn plain), for the player, the AOI default and the snapshot fallback.
static func spawn_point(y: float) -> Vector3:
	return Vector3(WorldShape.SPAWN_CENTER.x, y, WorldShape.SPAWN_CENTER.y)

## Phase 63 — half the span (m) of one detail-noise cell. FastNoiseLite takes float32, whose step is
## 1 m at 10 million metres and would terrace the 0.5 m tiles, so the noise is sampled at the
## coordinate local to a cell of 2·NOISE_SPAN (|local| <= NOISE_SPAN, exact to 1/128 m). Phase 122:
## cell (0, 0) is the identity, so ground near the origin is unchanged; every other cell adds a
## hashed offset (`cell_offset`) so the far world does not repeat or mirror, and the two cells either
## side of a border are blended over `NOISE_BLEND` m so the field is continuous.
const NOISE_SPAN := 65536.0

## Width (m) of the blend band inside a cell, next to each of its borders.
const NOISE_BLEND := 64.0

## Width (m) of the range a cell's noise offset is drawn from: each axis lies in
## [-NOISE_OFFSET_RANGE / 2, NOISE_OFFSET_RANGE / 2), as `cell_offset` computes it.
const NOISE_OFFSET_RANGE := 4096.0

## Per-axis cell data for a world coordinate: [cell, weight of the neighbouring cell, neighbour cell].
## The weight is 0 away from a border and rises to 0.5 at it, so both sides of a border agree.
static func _axis_cells(v: float) -> Array:
	var c := floori((v + NOISE_SPAN) / (2.0 * NOISE_SPAN))
	var local := v - float(c) * 2.0 * NOISE_SPAN
	if local > NOISE_SPAN - NOISE_BLEND:
		return [c, 0.5 * (local - (NOISE_SPAN - NOISE_BLEND)) / NOISE_BLEND, c + 1]
	if local < -NOISE_SPAN + NOISE_BLEND:
		return [c, 0.5 * (1.0 - (local + NOISE_SPAN) / NOISE_BLEND), c - 1]
	return [c, 0.0, c]

## The hashed noise offset (m, a multiple of 1/8) of detail cell (cx, cz) for `seed_v`; zero for the
## origin cell. Pure.
static func cell_offset(seed_v: int, cx: int, cz: int) -> Vector2:
	if cx == 0 and cz == 0:
		return Vector2.ZERO
	var h := (seed_v * 73856093) ^ (cx * 19349663) ^ (cz * 83492791)
	h = ((h ^ (h >> 15)) * 0x2c1b3c6d) & 0x7fffffff
	h = ((h ^ (h >> 12)) * 0x297a2d39) & 0x7fffffff
	h = h ^ (h >> 15)
	var span := int(NOISE_OFFSET_RANGE * 8.0)
	var ox := float((h & 0xffff) % span) / 8.0 - NOISE_OFFSET_RANGE * 0.5
	var oz := float(((h >> 15) & 0xffff) % span) / 8.0 - NOISE_OFFSET_RANGE * 0.5
	return Vector2(ox, oz)

## The detail noise term (0..HEIGHT_SCALE) at a world XZ; what `_raw_height_at` adds to the shape.
func detail_at(x: float, z: float) -> float:
	return detail_of(_noise, x, z)

## `WorldShape.height` interpolated between the corners of the chunk cell holding (x, z).
## Phase 68: the corner cache is per thread (chunk workers and the distant-ring worker all sample
## through this; the caller passes its own thread's `cache`, see `_corner_cache`), keyed on the cell, the seed and the circumference, so no thread ever reads
## another's half-written corners.
func _shape_at(x: float, z: float, w: float, cache: Array) -> float:
	return shape_cached(_world_seed, x, z, w, cache)

## The static form of `_shape_at`, for any thread that owns `cache`.
static func shape_cached(seed_v: int, x: float, z: float, w: float, cache: Array) -> float:
	var gx := x / CHUNK_METERS
	var gz := z / CHUNK_METERS
	var ix := floori(gx)
	var iz := floori(gz)
	if cache[0] != ix or cache[1] != iz or cache[2] != seed_v or cache[3] != w or cache[8] != ChunkRecords.revision():   # a heightmap walks one cell for 4096 tiles: reuse its corners
		var x0 := float(ix) * CHUNK_METERS
		var z0 := float(iz) * CHUNK_METERS
		cache[0] = ix
		cache[1] = iz
		cache[2] = seed_v
		cache[3] = w
		cache[8] = ChunkRecords.revision()
		var rec := ChunkRecords.get_record(wrap_chunk(Vector2i(ix, iz))) if not ChunkRecords.is_empty() else {}
		if not rec.is_empty():
			# Phase 108 — a recorded cell keeps the corner heights it was first seen with.
			var rh: Array = rec["h"]
			cache[4] = float(rh[0])
			cache[5] = float(rh[1])
			cache[6] = float(rh[2])
			cache[7] = float(rh[3])
		else:
			cache[4] = WorldShape.height(seed_v, x0, z0, w)
			cache[5] = WorldShape.height(seed_v, x0 + CHUNK_METERS, z0, w)
			cache[6] = WorldShape.height(seed_v, x0, z0 + CHUNK_METERS, w)
			cache[7] = WorldShape.height(seed_v, x0 + CHUNK_METERS, z0 + CHUNK_METERS, w)
	var fx := gx - float(ix)
	var fz := gz - float(iz)
	return lerpf(lerpf(cache[4], cache[5], fx), lerpf(cache[6], cache[7], fx), fz)

## This thread's corner cache: [ix, iz, seed, w, c00, c10, c01, c11, records revision]. The map is guarded; each
## entry is only ever touched by the thread that owns it.
var _corner_caches: Dictionary = {}
var _corner_mutex := Mutex.new()

func _corner_cache() -> Array:
	var tid := OS.get_thread_caller_id()
	_corner_mutex.lock()
	var cache: Array = _corner_caches.get(tid, [])
	if cache.is_empty():
		cache = new_corner_cache()
		_corner_caches[tid] = cache
	_corner_mutex.unlock()
	return cache

## An empty corner cache (layout in `_corner_cache`'s comment), matching no cell.
static func new_corner_cache() -> Array:
	return [2147483647, 2147483647, 0, 0.0, 0.0, 0.0, 0.0, 0.0, -1]
