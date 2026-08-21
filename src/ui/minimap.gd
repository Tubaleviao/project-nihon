extends Control
## Minimap stub (Phase 17) — a top-down 2D overlay showing loaded chunks with
## biome colour-coding and the player's position as a dot.
##
## The visual is drawn in _draw() (which does not run headless); the data
## projections (get_chunk_cells / get_player_cell / world_to_chunk) are pure and
## are what the automated test suite asserts against.
##
## Set by game_root: chunk_manager (chunk source) and player_slice (position).
## Each frame it pulls the loaded-chunk list and player position, so it stays in
## sync with the streaming world without owning any chunk state itself.

const CHUNK_SIZE := 32                 # tiles per side — must match TerrainSlice

## Biome → minimap colour. Falls back to grey for unknown keys.
const BIOME_COLORS: Dictionary = {
	"TemperateForest":    Color(0.30, 0.55, 0.28),
	"TemperateGrassland": Color(0.55, 0.70, 0.30),
	"VolcanicBadlands":   Color(0.55, 0.30, 0.20),
	"TwilightGrove":      Color(0.35, 0.25, 0.45),
	"VoidRift":           Color(0.25, 0.10, 0.35),
}

var chunk_manager: Node = null
var player_slice: Node = null

var _chunks: Array = []                # [{ "chunk": Vector2i, "biome": String }]
var _player_pos: Vector2 = Vector2.ZERO

func _process(_delta: float) -> void:
	if chunk_manager != null and chunk_manager.has_method("get_loaded_chunks"):
		set_chunks(chunk_manager.get_loaded_chunks())
	if player_slice != null and player_slice.has_method("get_position"):
		var p: Vector3 = player_slice.get_position()
		set_player_pos(Vector2(p.x, p.z))

func set_chunks(chunks: Array) -> void:
	_chunks = chunks
	queue_redraw()

func set_player_pos(pos: Vector2) -> void:
	_player_pos = pos
	queue_redraw()

## Pure projection: the loaded chunks with their chunk coord and biome.
func get_chunk_cells() -> Array:
	return _chunks.duplicate()

## Pure projection: which chunk the player dot falls in.
func get_player_cell() -> Dictionary:
	return { "chunk": world_to_chunk(_player_pos) }

## Chunk coordinate containing a world XZ position.
func world_to_chunk(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / CHUNK_SIZE), floori(world_pos.y / CHUNK_SIZE))

## Resolve a biome key to its minimap colour.
func biome_color(biome: String) -> Color:
	return BIOME_COLORS.get(biome, Color(0.4, 0.4, 0.4))

func _draw() -> void:
	var size := get_rect().size
	if size.x <= 0.0 or size.y <= 0.0 or _chunks.is_empty():
		return
	# Fit all loaded chunks to the control bounds.
	var min_c: Vector2i = _chunks[0]["chunk"]
	var max_c: Vector2i = _chunks[0]["chunk"]
	for cell in _chunks:
		var c: Vector2i = cell["chunk"]
		min_c = Vector2i(mini(min_c.x, c.x), mini(min_c.y, c.y))
		max_c = Vector2i(maxi(max_c.x, c.x), maxi(max_c.y, c.y))
	var cols := max_c.x - min_c.x + 1
	var rows := max_c.y - min_c.y + 1
	var cell_px := minf(size.x / cols, size.y / rows)
	var origin := Vector2((size.x - cols * cell_px) * 0.5, (size.y - rows * cell_px) * 0.5)
	for cell in _chunks:
		var c: Vector2i = cell["chunk"]
		var col: Color = biome_color(str(cell["biome"]))
		var rect := Rect2(
			origin.x + (c.x - min_c.x) * cell_px,
			origin.y + (c.y - min_c.y) * cell_px,
			cell_px, cell_px
		)
		draw_rect(rect, col)
		draw_rect(rect, Color(0.1, 0.1, 0.1, 0.5), false, 1.0)
	# Player dot.
	var pc: Vector2i = world_to_chunk(_player_pos)
	var dot := Rect2(
		origin.x + (pc.x - min_c.x) * cell_px + cell_px * 0.25,
		origin.y + (pc.y - min_c.y) * cell_px + cell_px * 0.25,
		cell_px * 0.5, cell_px * 0.5
	)
	draw_rect(dot, Color(1.0, 1.0, 1.0))
