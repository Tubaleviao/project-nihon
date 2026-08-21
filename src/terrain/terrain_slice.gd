extends Node
## Terrain slice — procedural chunk generation via FastNoiseLite.
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : none (generation is triggered by request_chunk())
##   OUT : chunk_ready(chunk_pos, heightmap)
##
## Public API:
##   request_chunk(pos: Vector2i) -> void   — kick off async generation
##   get_height_at(world_pos: Vector2) -> float — sample the last generated chunk

const CHUNK_SIZE := 32       # tiles per side
const HEIGHT_SCALE := 5.0    # world units peak-to-valley (gentle, even terrain)
const BIOME_SEED := 20260815 # fixed seed so biome assignment is deterministic

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

var _noise := FastNoiseLite.new()

func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.seed = randi()
	_noise.frequency = 0.05
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 3

## Generate a chunk and emit chunk_ready when done.
func request_chunk(pos: Vector2i) -> void:
	var heightmap := _generate(pos)
	GameBus.chunk_ready.emit(pos, heightmap)

## Sample height at an arbitrary world position (snaps to nearest chunk sample).
## Uses the same (raw+1)*0.5*HEIGHT_SCALE formula as _generate so values match the heightmap.
func get_height_at(world_pos: Vector2) -> float:
	var raw := _noise.get_noise_2d(world_pos.x, world_pos.y)
	return (raw + 1.0) * 0.5 * HEIGHT_SCALE

## Return the biome key for a world position. Phase 17: biome assignment is
## per-chunk — the whole chunk shares one biome, seeded by (cx, cz) so biome
## borders are stable across sessions (deterministic regardless of run).
func get_biome_at(world_pos: Vector2) -> String:
	return get_biome_at_chunk(world_to_chunk(world_pos))

## Return the biome key for a whole chunk, deterministically derived from the
## chunk coordinate and BIOME_SEED. Same (cx, cz) always yields the same biome.
func get_biome_at_chunk(chunk_pos: Vector2i) -> String:
	var h := str(BIOME_SEED).hash() ^ str(chunk_pos.x).hash() ^ (str(chunk_pos.y).hash() << 1)
	var idx := posmod(h, BIOME_KEYS.size())
	return str(BIOME_KEYS[idx])

## Convert a world XZ position to its containing chunk coordinate.
func world_to_chunk(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / CHUNK_SIZE), floori(world_pos.y / CHUNK_SIZE))

## Convert a chunk coordinate to the world XZ origin of that chunk (bottom-left
## corner in world units).
func chunk_to_world(chunk_pos: Vector2i) -> Vector2:
	return Vector2(chunk_pos.x * CHUNK_SIZE, chunk_pos.y * CHUNK_SIZE)

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _generate(pos: Vector2i) -> Array:
	var out: Array = []
	out.resize(CHUNK_SIZE * CHUNK_SIZE)
	var origin_x := pos.x * CHUNK_SIZE
	var origin_y := pos.y * CHUNK_SIZE
	for ty in range(CHUNK_SIZE):
		for tx in range(CHUNK_SIZE):
			var raw := _noise.get_noise_2d(origin_x + tx, origin_y + ty)
			out[ty * CHUNK_SIZE + tx] = (raw + 1.0) * 0.5 * HEIGHT_SCALE
	return out
