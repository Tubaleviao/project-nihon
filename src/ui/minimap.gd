extends Control
## Minimap (Phase 17) — a top-down 2D overlay showing the *explored* world with
## biome colour-coding and the player's position as a dot.
##
## Fog of war: only chunks the player has actually visited (plus a small reveal
## radius around them) are drawn, instead of every loaded chunk. As the player
## moves, chunks are permanently revealed behind them — the map is a record of
## where they have been, not a window onto the streaming world.
##
## Zoom: the map is zoomed in by default (a few chunks across) and the player
## can zoom out to survey more of the explored area, or back in. Scroll the
## wheel over the minimap, or press - / + (or =) keys.
##
## The visual is drawn in _draw() (which does not run headless); the data
## projections (world_to_chunk / get_player_cell / reveal tracking) are pure and
## are what the automated test suite asserts against.

const CHUNK_SIZE := 32                 # tiles per side — must match TerrainSlice

## Reveal this many chunks around the player's current chunk (Chebyshev radius).
## 1 reveals a 3×3 neighbourhood — enough to see where you are and where you
## just came from, without pre-revealing unvisited terrain.
const REVEAL_RADIUS := 1

## Zoom as "chunks visible across the minimap width". Small = zoomed in.
const ZOOM_DEFAULT := 9.0
const ZOOM_MIN     := 5.0
const ZOOM_MAX     := 65.0
const ZOOM_IN_STEP  := 0.75   # multiplier per zoom-in notch
const ZOOM_OUT_STEP := 1.35   # multiplier per zoom-out notch

## Biome → minimap colour. Falls back to grey for unknown keys.
const BIOME_COLORS: Dictionary = {
	"TemperateForest":    Color(0.30, 0.55, 0.28),
	"TemperateGrassland": Color(0.55, 0.70, 0.30),
	"VolcanicBadlands":   Color(0.55, 0.30, 0.20),
	"TwilightGrove":      Color(0.35, 0.25, 0.45),
	"VoidRift":           Color(0.25, 0.10, 0.35),
}

## Set by game_root: player position, terrain (biome + world bounds), and the
## chunk manager (kept for introspection; the minimap no longer reads it).
var chunk_manager: Node = null
var player_slice: Node = null
var terrain_slice: Node = null

## Explored chunks, keyed "cx,cz" -> true. Persistent for the session: once
## revealed, a chunk stays on the map even after it streams out of view.
var _revealed: Dictionary = {}

var _player_pos: Vector2 = Vector2.ZERO
var _player_chunk: Vector2i = Vector2i(-9999, -9999)
var _facing: Vector2 = Vector2(0.0, -1.0)   # world XZ facing, for the arrow
var _chunks_across: float = ZOOM_DEFAULT

func _process(_delta: float) -> void:
	if player_slice == null or not player_slice.has_method("get_position"):
		return
	var p: Vector3 = player_slice.get_position()
	_player_pos = Vector2(p.x, p.z)
	var facing := Vector2(0.0, -1.0)
	if player_slice.has_method("get_facing"):
		facing = player_slice.get_facing()
	var pc := world_to_chunk(_player_pos)
	var chunk_changed := pc != _player_chunk
	if chunk_changed:
		_player_chunk = pc
		_reveal_around(pc)
	# Redraw when the player enters a new chunk (fog-of-war reveal) or turns
	# (arrow orientation). Standing still with a steady heading costs nothing.
	if chunk_changed or not facing.is_equal_approx(_facing):
		_facing = facing
		queue_redraw()

func set_player_pos(pos: Vector2) -> void:
	_player_pos = pos
	var pc := world_to_chunk(pos)
	if pc != _player_chunk:
		_player_chunk = pc
		_reveal_around(pc)
	queue_redraw()

## Set the player's facing (world XZ) directly — test/debug hook mirroring
## what _process reads from the player slice.
func set_facing(facing: Vector2) -> void:
	_facing = facing
	queue_redraw()

## Reveal the chunk neighbourhood around `center` (fog-of-war). No-op beyond the
## finite world edge.
func _reveal_around(center: Vector2i) -> void:
	for dz in range(-REVEAL_RADIUS, REVEAL_RADIUS + 1):
		for dx in range(-REVEAL_RADIUS, REVEAL_RADIUS + 1):
			var c := center + Vector2i(dx, dz)
			if _in_world(c):
				_revealed[_chunk_key(c)] = true

## True when `chunk` lies inside the finite world, or when no terrain slice is
## wired (isolated unit tests treat the world as unbounded).
func _in_world(chunk: Vector2i) -> bool:
	if terrain_slice != null and terrain_slice.has_method("is_chunk_in_bounds"):
		return terrain_slice.is_chunk_in_bounds(chunk)
	return true

func is_revealed(chunk: Vector2i) -> bool:
	return _revealed.has(_chunk_key(chunk))

## All revealed chunk coords, for introspection/tests.
func get_revealed_chunks() -> Array:
	var out: Array = []
	for key in _revealed:
		out.append(_key_to_chunk(key))
	return out

## Chunk coordinate containing a world XZ position.
func world_to_chunk(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / CHUNK_SIZE), floori(world_pos.y / CHUNK_SIZE))

## Pure projection: which chunk the player dot falls in.
func get_player_cell() -> Dictionary:
	return { "chunk": world_to_chunk(_player_pos) }

## Resolve a biome key to its minimap colour.
func biome_color(biome: String) -> Color:
	return BIOME_COLORS.get(biome, Color(0.4, 0.4, 0.4))

# ---------------------------------------------------------------------------
# Zoom
# ---------------------------------------------------------------------------

func get_zoom() -> float:
	return _chunks_across

func set_zoom(chunks_across: float) -> void:
	_chunks_across = clampf(chunks_across, ZOOM_MIN, ZOOM_MAX)
	queue_redraw()

func zoom_in() -> void:
	set_zoom(_chunks_across * ZOOM_IN_STEP)

func zoom_out() -> void:
	set_zoom(_chunks_across * ZOOM_OUT_STEP)

## Scroll wheel over the minimap (works when the mouse is free), or the - / + / =
## keys (work even while the mouse is captured for gameplay).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out()
			accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_MINUS:
			zoom_out()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_EQUAL or event.keycode == KEY_PLUS:
			zoom_in()
			get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	var size := get_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if _player_chunk == Vector2i(-9999, -9999):
		return

	var cell_px := minf(size.x, size.y) / _chunks_across
	var half := _chunks_across / 2.0
	var min_cx := floori(_player_chunk.x - half)
	var max_cx := ceili(_player_chunk.x + half)
	var min_cz := floori(_player_chunk.y - half)
	var max_cz := ceili(_player_chunk.y + half)

	for cz in range(min_cz, max_cz):
		for cx in range(min_cx, max_cx):
			var c := Vector2i(cx, cz)
			if not _revealed.has(_chunk_key(c)):
				continue
			var col: Color = biome_color(_biome(c))
			var rx := size.x * 0.5 + (cx - _player_chunk.x) * cell_px - cell_px * 0.5
			var ry := size.y * 0.5 + (cz - _player_chunk.y) * cell_px - cell_px * 0.5
			var rect := Rect2(rx, ry, cell_px, cell_px)
			draw_rect(rect, col)
			draw_rect(rect, Color(0.1, 0.1, 0.1, 0.5), false, 1.0)

	# World boundary — a thin frame so the finite world's edge is visible when
	# the view reaches it.
	_draw_world_bounds(size, cell_px)

	# Player arrow — points in the player's facing direction.
	var dir := _facing_screen_dir(_facing)
	var angle := atan2(dir.y, dir.x)
	var center := Vector2(size.x * 0.5, size.y * 0.5)
	var arrow_len := cell_px * 0.55
	var half_w := arrow_len * 0.45
	var tip := center + Vector2(cos(angle), sin(angle)) * arrow_len
	var back := center - Vector2(cos(angle), sin(angle)) * arrow_len * 0.5
	var perp := Vector2(-sin(angle), cos(angle))
	var left := back + perp * half_w
	var right := back - perp * half_w
	draw_colored_polygon(PackedVector2Array([tip, left, right]), Color(1.0, 1.0, 1.0))

## Draw the finite world's boundary line where it falls inside the visible
## window. The playable chunks span [-R, R) on each axis.
func _draw_world_bounds(size: Vector2, cell_px: float) -> void:
	if terrain_slice == null or not terrain_slice.has_method("world_radius_chunks"):
		return
	var r: int = terrain_slice.world_radius_chunks()
	var edge_col := Color(0.0, 0.0, 0.0, 0.8)

	var left_x := size.x * 0.5 + (-r - _player_chunk.x) * cell_px
	var right_x := size.x * 0.5 + (r - _player_chunk.x) * cell_px
	var top_z := size.y * 0.5 + (-r - _player_chunk.y) * cell_px
	var bottom_z := size.y * 0.5 + (r - _player_chunk.y) * cell_px

	if left_x > 0.0 and left_x < size.x:
		draw_line(Vector2(left_x, 0.0), Vector2(left_x, size.y), edge_col, 2.0)
	if right_x > 0.0 and right_x < size.x:
		draw_line(Vector2(right_x, 0.0), Vector2(right_x, size.y), edge_col, 2.0)
	if top_z > 0.0 and top_z < size.y:
		draw_line(Vector2(0.0, top_z), Vector2(size.x, top_z), edge_col, 2.0)
	if bottom_z > 0.0 and bottom_z < size.y:
		draw_line(Vector2(0.0, bottom_z), Vector2(size.x, bottom_z), edge_col, 2.0)

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _biome(c: Vector2i) -> String:
	if terrain_slice != null and terrain_slice.has_method("get_biome_at_chunk"):
		return str(terrain_slice.get_biome_at_chunk(c))
	return "TemperateForest"

## Screen-space unit direction for the player arrow, given a world XZ facing.
## The minimap maps world +X → screen +X and world +Z → screen +Y (down), so the
## screen direction is the facing's (x, z) as-is. Returns "north" (up) when the
## facing is degenerate.
func _facing_screen_dir(facing: Vector2) -> Vector2:
	if facing.length_squared() < 0.0001:
		return Vector2(0.0, -1.0)
	return Vector2(facing.x, facing.y).normalized()

func _chunk_key(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]

func _key_to_chunk(key: String) -> Vector2i:
	var parts: PackedStringArray = str(key).split(",")
	return Vector2i(int(parts[0]), int(parts[1]))
