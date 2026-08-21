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

var _noise := FastNoiseLite.new()
var _biome_noise := FastNoiseLite.new()

func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.seed = randi()
	_noise.frequency = 0.05
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 3

	_biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_biome_noise.seed = BIOME_SEED
	_biome_noise.frequency = 0.02
	_biome_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_biome_noise.fractal_octaves = 2

## Generate a chunk and emit chunk_ready when done.
func request_chunk(pos: Vector2i) -> void:
	var heightmap := _generate(pos)
	GameBus.chunk_ready.emit(pos, heightmap)

## Sample height at an arbitrary world position (snaps to nearest chunk sample).
## Uses the same (raw+1)*0.5*HEIGHT_SCALE formula as _generate so values match the heightmap.
func get_height_at(world_pos: Vector2) -> float:
	var raw := _noise.get_noise_2d(world_pos.x, world_pos.y)
	return (raw + 1.0) * 0.5 * HEIGHT_SCALE

## Return the biome key for a world position. Uses a fixed-seed temperature
## noise channel (independent of the height noise) so biome assignment is
## deterministic across runs even though terrain height varies.
func get_biome_at(world_pos: Vector2) -> String:
	var temp := _biome_noise.get_noise_2d(world_pos.x, world_pos.y)
	if temp > 0.55:
		return "VoidRift"
	if temp > 0.25:
		return "VolcanicBadlands"
	if temp > 0.05:
		return "TemperateGrassland"
	if temp < -0.4:
		return "TwilightGrove"
	return "TemperateForest"

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
