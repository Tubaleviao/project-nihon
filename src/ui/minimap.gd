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

const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const BiomeBlend := preload("res://src/terrain/biome_blend.gd")
const CHUNK_SIZE := TerrainSlice.CHUNK_METERS   # world units per chunk

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

## Colour for a biome with neither a fabric tint nor a table entry.
const FALLBACK_COLOR := Color(0.4, 0.4, 0.4)

## Set by game_root: player position, terrain (biome + world bounds), and the
## chunk manager (kept for introspection; the minimap no longer reads it).
var chunk_manager: Node = null
var player_slice: Node = null
## Phase 54 — the HUD's time-of-day and season line, set by game_root when it changes.
var clock_text: String = ""
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
## Phase 49: the biome's fabric `surfaceTint` (the colour the ground actually shows) wins;
## the hard-coded table is the fallback when the biome resource is not loaded.
## Cached per biome: the tint string is parsed once, not per cell per draw (the fabric
## table is static for the life of the process).
func biome_color(biome: String) -> Color:
	_check_biome_table()
	if _biome_color_cache.has(biome):
		return _biome_color_cache[biome]
	var fallback: Color = BIOME_COLORS.get(biome, FALLBACK_COLOR)
	var out: Color = fallback
	var b: Variant = GameData.BIOMES.get(biome, null)
	if b != null and b.get("surfaceTint") != null:
		out = Color.from_string(str(b.get("surfaceTint")), fallback)
	_biome_color_cache[biome] = out
	return out

var _biome_color_cache: Dictionary = {}
var _biomes_seen: Dictionary = {}   # the GameData.BIOMES the colour cache was built from
var _biomes_seen_size: int = -1

## Drop the colour and biome caches when the fabric biome table is not the one they were built
## from (a hot reload, or a test swapping it).
func _check_biome_table() -> void:
	if is_same(_biomes_seen, GameData.BIOMES) and _biomes_seen_size == GameData.BIOMES.size():
		return
	_biomes_seen = GameData.BIOMES
	_biomes_seen_size = GameData.BIOMES.size()
	_biome_color_cache.clear()
	_biome_cache.clear()

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

	for item in _view_rects(size):
		if item[2]:
			draw_rect(item[0], item[1], true)
		else:
			draw_rect(item[0], item[1], false, item[3])

	# World boundary — a thin frame so the finite world's edge is visible when
	# the view reaches it.
	_draw_world_bounds(size, cell_px)

	if clock_text != "":
		draw_string(ThemeDB.fallback_font, Vector2(4.0, size.y - 17.0), clock_text,
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 8.0, 11, Color(1, 0.95, 0.7, 0.95))

	# Latitude, longitude and altitude (Phase 50).
	if player_slice != null and player_slice.has_method("get_position"):
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(4.0, size.y - 4.0), TerrainSlice.where_text(player_slice.get_position()),
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 8.0, 11, Color(1, 1, 1, 0.9))

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

## Draw the polar ice lines where they fall inside the visible window. The world wraps in X,
## so only the north and south limits are edges.
func _draw_world_bounds(size: Vector2, cell_px: float) -> void:
	if terrain_slice == null or not terrain_slice.has_method("world_radius_chunks"):
		return
	var r: int = terrain_slice.world_radius_chunks()
	var edge_col := Color(0.0, 0.0, 0.0, 0.8)

	var top_z := size.y * 0.5 + (-(r - 1) - _player_chunk.y) * cell_px
	var bottom_z := size.y * 0.5 + (r - _player_chunk.y) * cell_px

	if top_z > 0.0 and top_z < size.y:
		draw_line(Vector2(0.0, top_z), Vector2(size.x, top_z), edge_col, 2.0)
	if bottom_z > 0.0 and bottom_z < size.y:
		draw_line(Vector2(0.0, bottom_z), Vector2(size.x, bottom_z), edge_col, 2.0)

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Sub-cells per chunk edge in the minimap's per-tile surface colour.
const CELLS_PER_CHUNK := 4

## Biome lookups are persistent across redraws (a chunk's biome never changes for a seed), so a
## redraw of the same view asks the terrain nothing. Bounded: past BIOME_CACHE_MAX the entries
## outside the current view are dropped, and the whole cache if that is not enough.
const BIOME_CACHE_MAX := 8192   # above the largest view (ZOOM_MAX + 1)^2 chunks, so a full view never thrashes

## Below this cell size in pixels a chunk is one rect: sub-cells would be sub-pixel.
const MIN_CELL_PX := 2.0

const NEIGHBOUR_OFFSETS: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]

var _biome_cache: Dictionary = {}   # chunk key -> biome
var _biome_cache_seed: int = 0

## Everything the visible window draws, as [rect, colour, filled, width] items in draw order.
## Pure, so the suite can count them (`draw_*` only works inside `_draw`).
func _view_rects(size: Vector2) -> Array:
	var out: Array = []
	if _player_chunk == Vector2i(-9999, -9999):
		return out
	_check_biome_table()
	_check_seed()
	var cell_px := minf(size.x, size.y) / _chunks_across
	var half := _chunks_across / 2.0
	var min_cx := floori(_player_chunk.x - half)
	var max_cx := ceili(_player_chunk.x + half)
	var min_cz := floori(_player_chunk.y - half)
	var max_cz := ceili(_player_chunk.y + half)
	if _biome_cache.size() > BIOME_CACHE_MAX:
		_prune_biome_cache(min_cx, max_cx, min_cz, max_cz)
	for cz in range(min_cz, max_cz):
		for cx in range(min_cx, max_cx):
			var c := Vector2i(cx, cz)
			if not _revealed.has(_chunk_key(c)):
				continue
			var rx := size.x * 0.5 + (cx - _player_chunk.x) * cell_px - cell_px * 0.5
			var ry := size.y * 0.5 + (cz - _player_chunk.y) * cell_px - cell_px * 0.5
			var rect := Rect2(rx, ry, cell_px, cell_px)
			_chunk_cell_rects(c, rect, out)
			if cell_px / CELLS_PER_CHUNK >= MIN_CELL_PX:
				out.append([rect, Color(0.1, 0.1, 0.1, 0.5), false, 1.0])
	return out

## Forget every cached biome when the world seed changes.
func _check_seed() -> void:
	if terrain_slice == null or not terrain_slice.has_method("get_world_seed"):
		return
	var seed_v: int = terrain_slice.get_world_seed()
	if seed_v != _biome_cache_seed:
		_biome_cache_seed = seed_v
		_biome_cache.clear()

func _prune_biome_cache(min_cx: int, max_cx: int, min_cz: int, max_cz: int) -> void:
	for k in _biome_cache.keys():
		var c := _key_to_chunk(k)
		if c.x < min_cx - 1 or c.x > max_cx or c.y < min_cz - 1 or c.y > max_cz:
			_biome_cache.erase(k)
	if _biome_cache.size() > BIOME_CACHE_MAX:
		_biome_cache.clear()

## The biome of the chunk, memoised across redraws.
## Not cached when no terrain is wired: that fallback must not outlive the wiring.
func _biome_memo(c: Vector2i) -> String:
	var k := _chunk_key(c)
	if _biome_cache.has(k):
		return _biome_cache[k]
	var b := _biome(c)
	if terrain_slice != null and terrain_slice.has_method("get_biome_at_chunk"):
		_biome_cache[k] = b
	return b

## The fill rects of one chunk, appended to `out` as [rect, colour, true, 0.0]. The interior is
## one rect; only the border cells are drawn individually, and one may wear the biome across that
## border (`BiomeBlend`, the voxel surface's own dither rule, sampled at the cell's centre), so a
## biome edge reads as a ragged band, not a straight cut. Only REVEALED neighbours inside the
## world are blended toward, so the fog of war never leaks an unexplored biome. A chunk none of
## whose neighbours would blend, or whose sub-cells would be under MIN_CELL_PX, is one rect.
func _chunk_cell_rects(c: Vector2i, rect: Rect2, out: Array) -> void:
	var own := _biome_memo(c)
	var own_col := biome_color(own)
	var n := CELLS_PER_CHUNK
	if rect.size.x / n < MIN_CELL_PX or not _has_blend_neighbour(c, own):
		out.append([Rect2(rect.position, rect.size + Vector2(0.5, 0.5)), own_col, true, 0.0])
		return
	var cw := rect.size.x / n
	var ch := rect.size.y / n
	out.append([Rect2(rect.position.x + cw, rect.position.y + ch, cw * (n - 2) + 0.5, ch * (n - 2) + 0.5), own_col, true, 0.0])
	for j in n:
		for i in n:
			var edge_i := mini(i, n - 1 - i)
			var edge_j := mini(j, n - 1 - j)
			if mini(edge_i, edge_j) != 0 and n > 2:
				continue
			var col := biome_color(_cell_biome(c, i, j, own))
			out.append([Rect2(rect.position.x + i * cw, rect.position.y + j * ch, cw + 0.5, ch + 0.5), col, true, 0.0])

## The biome sub-cell (i, j) of chunk `c` wears: `own`, or a blendable neighbour's across the
## nearest border, per `BiomeBlend`. Never an unrevealed or off-world chunk's biome.
func _cell_biome(c: Vector2i, i: int, j: int, own: String) -> String:
	var n := CELLS_PER_CHUNK
	var across := c
	if mini(i, n - 1 - i) <= mini(j, n - 1 - j):
		across.x += -1 if i < n - 1 - i else 1
	else:
		across.y += -1 if j < n - 1 - j else 1
	if across == c or not _blendable(across):
		return own
	var other := _biome_memo(across)
	if other == own:
		return own
	# The voxel band scaled to one cell: the cell's centre is half a band in.
	var cell_tiles := float(TerrainSlice.CHUNK_SIZE) / n
	if BiomeBlend.wears_neighbour(c.x * n + i, c.y * n + j, cell_tiles * 0.5, cell_tiles):
		return other
	return own

## True when chunk `c` may lend its colour to a neighbour: revealed, and inside the world.
func _blendable(c: Vector2i) -> bool:
	if not _revealed.has(_chunk_key(c)):
		return false
	if terrain_slice != null and terrain_slice.has_method("world_radius_chunks"):
		var r: int = terrain_slice.world_radius_chunks()
		if not TerrainSlice.lends_biome(c, r):
			return false
	return true

## True when any of the four neighbours of `c` would lend a different biome's colour.
func _has_blend_neighbour(c: Vector2i, own: String) -> bool:
	for off in NEIGHBOUR_OFFSETS:
		var nb: Vector2i = c + off
		if _blendable(nb) and _biome_memo(nb) != own:
			return true
	return false

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
