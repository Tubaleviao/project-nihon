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

## Finite world extent: the playable area spans chunk coordinates
## [-WORLD_RADIUS_CHUNKS, WORLD_RADIUS_CHUNKS) on each axis — a
## (2*WORLD_RADIUS_CHUNKS)² chunk square (256² chunks at the default 128).
## Very large, but not infinite: the player and chunk streaming are both
## clamped to this so the world has a real edge.
const WORLD_RADIUS_CHUNKS := 128

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
## chunk coordinate and BIOME_SEED. Same (cx, cz) always yields the same biome.
## Uses integer multiply-mix (Knuth multiplicative hashing) for better distribution
## than converting integers to strings and calling .hash().
func get_biome_at_chunk(chunk_pos: Vector2i) -> String:
	return biome_for_chunk(chunk_pos)

## Phase 43 — the STATIC form of `get_biome_at_chunk`: a pure function of the chunk and the
## `BIOME_SEED` const, so the ore field (`src/terrain/ore_field.gd`) can ask a vein's biome on
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

## True when `chunk_pos` lies inside the finite world (see WORLD_RADIUS_CHUNKS).
func is_chunk_in_bounds(chunk_pos: Vector2i) -> bool:
	return absi(chunk_pos.x) < WORLD_RADIUS_CHUNKS and absi(chunk_pos.y) < WORLD_RADIUS_CHUNKS

## Half the world's extent in world units (the playable XZ range is ±this).
func world_half_extent() -> float:
	return float(WORLD_RADIUS_CHUNKS * CHUNK_SIZE * TILE_SIZE)

## The finite world's chunk-radius (see WORLD_RADIUS_CHUNKS).
func world_radius_chunks() -> int:
	return WORLD_RADIUS_CHUNKS

## Clamp a world position's X/Z so the player cannot walk past the world edge.
## Y is left untouched (gravity/terrain handle vertical). Insets the boundary by
## a hair so the body stays on the final chunk's collision instead of straddling
## the exact edge.
func clamp_to_world(pos: Vector3) -> Vector3:
	var half := world_half_extent() - 0.5
	return Vector3(
		clampf(pos.x, -half, half),
		pos.y,
		clampf(pos.z, -half, half)
	)

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _generate(pos: Vector2i) -> Array:
	var out: Array = []
	out.resize(CHUNK_SIZE * CHUNK_SIZE)
	var origin_x := pos.x * CHUNK_SIZE * TILE_SIZE
	var origin_z := pos.y * CHUNK_SIZE * TILE_SIZE
	for ty in range(CHUNK_SIZE):
		for tx in range(CHUNK_SIZE):
			out[ty * CHUNK_SIZE + tx] = _height_at(origin_x + tx * TILE_SIZE, origin_z + ty * TILE_SIZE)
	return out

## Continuous terrain height at a world XZ position: noise scaled by HEIGHT_SCALE,
## then flattened to a plain field inside SPAWN_FLATTEN_RADIUS of SPAWN_CENTER so
## the player starts on walkable ground. Shared by _generate and get_height_at so
## the heightmap and direct samples always agree.
func _height_at(x: float, z: float) -> float:
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
