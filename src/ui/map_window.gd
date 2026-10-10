extends Control
## Map window (Phase 111) — the whole world, from street level out to a round planet.
##
## The picture is the real world sampled bit by bit from the same fields the terrain is generated
## from (`MapTiles`): a coarse level draws at once and finer levels fill in over the following frames
## on a worker thread. Close in it is the flat chunk map; further out the projection blends into an
## orthographic globe (`MapMath.blend`, a pure function of zoom) that can be dragged round.
## Unexplored land is dimmed unless the true-planet toggle is on; the player's home is marked, with an
## edge arrow and distance when it is off-screen.
##
## Drawing needs a canvas and does not run headless; the maths it relies on is in MapMath/MapTiles.

const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const MapMath := preload("res://src/ui/map_math.gd")
const MapTiles := preload("res://src/ui/map_tiles.gd")

const TILES_PER_FRAME := 48
const WHEEL_STEP := 0.25
const DIM := 0.35
const MAX_TILES_DRAWN := 6000

var minimap: Node = null
var terrain_slice: Node = null
var player_slice: Node = null
var show_true_planet: bool = false

var tiles := MapTiles.new()
var _zoom: float = 6.5
var _center: Vector2 = Vector2.ZERO   # view centre in chunks
var _dragging := false
var _thread: Thread = null
var _batch_seed: int = 0
var _reveal_tiles: Dictionary = {}
var _reveal_level: int = -1
var _reveal_count: int = -1

func _init() -> void:
	name = "MapWindow"
	custom_minimum_size = Vector2(520, 460)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true

func circumference() -> int:
	return TerrainSlice.circumference_chunks()

func get_zoom() -> float:
	return _zoom

func set_zoom(z: float) -> void:
	_zoom = clampf(z, MapMath.ZOOM_MIN, MapMath.zoom_max(circumference()))
	queue_redraw()

func get_center() -> Vector2:
	return _center

## Centre the view on the player and zoom to a few dozen chunks across.
func center_on_player() -> void:
	if player_slice != null and player_slice.has_method("get_position"):
		var p: Vector3 = player_slice.get_position()
		_center = Vector2(p.x, p.z) / TerrainSlice.CHUNK_METERS
		_clamp_center()
	queue_redraw()

func _clamp_center() -> void:
	var half := float(circumference()) / 2.0
	_center.x = fposmod(_center.x + half, float(circumference())) - half
	_center.y = clampf(_center.y, -float(TerrainSlice.pole_chunks()), float(TerrainSlice.pole_chunks()))

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		center_on_player()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			set_zoom(_zoom - WHEEL_STEP)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			set_zoom(_zoom + WHEEL_STEP)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var ppc := _px_per_chunk()
		# Dragging a globe turns it: the same pan, scaled by how much of the surface a pixel covers.
		_center -= event.relative / maxf(ppc, 0.000001)
		_clamp_center()
		queue_redraw()
		accept_event()

func _view_px() -> float:
	return minf(size.x, size.y)

func _t() -> float:
	return MapMath.blend(_zoom, MapMath.zoom_max(circumference()))

## Pixels per chunk of the flat picture at this zoom.
func _px_per_chunk() -> float:
	return _view_px() / pow(2.0, _zoom)

func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	_service_worker()
	if minimap != null and minimap.has_method("get_revealed_chunks"):
		queue_redraw()

## Collect a finished batch and start the next, a few tiles per frame, off the main thread.
func _service_worker() -> void:
	if _thread != null:
		if _thread.is_alive():
			return
		var done: Array = _thread.wait_to_finish()
		_thread = null
		if _batch_seed == tiles.seed_v:
			tiles.store(done)
		queue_redraw()
	if tiles.pending_count() == 0:
		return
	_batch_seed = tiles.seed_v
	var batch := tiles.take(TILES_PER_FRAME)
	_thread = Thread.new()
	_thread.start(MapTiles.compute.bind(_batch_seed, batch))

func _exit_tree() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null

func _world_seed() -> int:
	if terrain_slice != null and terrain_slice.has_method("get_world_seed"):
		return terrain_slice.get_world_seed()
	return 0

## Revealed tiles at `level`, rebuilt when the level or the explored set changes.
func _revealed_tiles(level: int) -> Dictionary:
	if minimap == null:
		return {}
	var chunks: Array = minimap.get_revealed_chunks()
	if level != _reveal_level or chunks.size() != _reveal_count:
		_reveal_tiles.clear()
		for c in chunks:
			var t := MapMath.tile_of(c, level)
			_reveal_tiles["%d,%d" % [t.x, t.y]] = true
		_reveal_level = level
		_reveal_count = chunks.size()
	return _reveal_tiles

func _draw() -> void:
	var sz := size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	var seed_v := _world_seed()
	if seed_v != tiles.seed_v:
		tiles.reset(seed_v)
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.03, 0.04, 0.08))
	var circ := circumference()
	var t := _t()
	var ppc := _px_per_chunk()
	var level := MapMath.level_for(ppc)
	var scale := MapMath.scale_px(_zoom, _view_px(), circ)
	var origin := sz * 0.5
	var center_ll := MapMath.lonlat(_center, circ)
	var tile_chunks := 1 << level
	var span := minf(float(circ) * 0.5, pow(2.0, _zoom) * 0.75 + tile_chunks)
	var pole := float(TerrainSlice.pole_chunks())
	var x0 := floori((_center.x - span) / tile_chunks)
	var x1 := ceili((_center.x + span) / tile_chunks)
	var z0 := floori(maxf(_center.y - span, -pole - 2.0) / tile_chunks)
	var z1 := ceili(minf(_center.y + span, pole + 2.0) / tile_chunks)
	if (x1 - x0 + 1) * (z1 - z0 + 1) > MAX_TILES_DRAWN:
		return
	if t >= 0.5:   # a lit disc behind the sphere
		draw_circle(origin, scale, Color(0.05, 0.07, 0.14))
	var fog := _revealed_tiles(level) if not show_true_planet else {}
	# Request coarse ancestors of what is on screen first: the picture is complete at once.
	var coarse := mini(level + 3, MapMath.MAX_LEVEL)
	for tz in range(z0, z1 + 1):
		for tx in range(x0, x1 + 1):
			if coarse > level:
				tiles.request(coarse, tx >> (coarse - level), tz >> (coarse - level))
			tiles.request(level, tx, tz)
	for tz in range(z0, z1 + 1):
		for tx in range(x0, x1 + 1):
			var biome := tiles.best_biome(level, tx, tz)
			if biome == "":
				continue
			var cx0 := float(tx * tile_chunks)
			var cz0 := float(tz * tile_chunks)
			var mid := MapMath.lonlat(Vector2(cx0 + tile_chunks * 0.5, cz0 + tile_chunks * 0.5), circ)
			if not MapMath.facing(mid, center_ll, t):
				continue
			var col := _biome_color(biome)
			if not show_true_planet and not fog.has("%d,%d" % [tx, tz]):
				col = col.darkened(1.0 - DIM)
			var pts := PackedVector2Array()
			for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				var ll := MapMath.lonlat(Vector2(cx0, cz0) + corner * float(tile_chunks), circ)
				pts.append(origin + MapMath.project(ll, center_ll, t) * scale)
			draw_colored_polygon(pts, col)
	_draw_markers(sz, origin, center_ll, t, scale, circ)

func _biome_color(biome: String) -> Color:
	if minimap != null and minimap.has_method("biome_color"):
		return minimap.biome_color(biome)
	return Color(0.4, 0.4, 0.4)

func _draw_markers(sz: Vector2, origin: Vector2, center_ll: Vector2, t: float, scale: float, circ: int) -> void:
	var font := ThemeDB.fallback_font
	if player_slice != null and player_slice.has_method("get_position"):
		var p: Vector3 = player_slice.get_position()
		var pll := MapMath.lonlat(Vector2(p.x, p.z) / TerrainSlice.CHUNK_METERS, circ)
		if MapMath.facing(pll, center_ll, t):
			draw_circle(origin + MapMath.project(pll, center_ll, t) * scale, 4.0, Color.WHITE)
	var home := home_marker(sz)
	if home.is_empty():
		return
	var pos: Vector2 = origin + home["pos"]
	if home["inside"]:
		draw_circle(pos, 6.0, Color(1.0, 0.8, 0.2))
		draw_string(font, pos + Vector2(8, 4), "Home", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.9, 0.5))
	else:
		var a: float = home["angle"]
		var dir := Vector2(cos(a), sin(a))
		var perp := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([pos + dir * 10.0, pos - dir * 6.0 + perp * 7.0, pos - dir * 6.0 - perp * 7.0]), Color(1.0, 0.8, 0.2))
		draw_string(font, pos - dir * 14.0 - Vector2(24, -4), MapMath.distance_text(home["distance"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.9, 0.5))

## The home marker for a window of `sz`: { inside, pos (px from the centre), distance, angle }, or {}
## when no respawn point is recorded.
func home_marker(sz: Vector2) -> Dictionary:
	if player_slice == null or not ("respawn_world_pos" in player_slice) or player_slice.respawn_world_pos.is_empty():
		return {}
	var circ := circumference()
	var hw: Dictionary = player_slice.respawn_world_pos
	var hc: Vector2i = hw["chunk"]
	var hl: Vector3 = hw["local"]
	var view_chunk := Vector2i(floori(_center.x), floori(_center.y))
	var view_local := (_center - Vector2(view_chunk)) * TerrainSlice.CHUNK_METERS
	var d := MapMath.delta_m(view_chunk, view_local, hc, Vector2(hl.x, hl.z))
	# The short way round the planet.
	var circ_m := float(circ) * TerrainSlice.CHUNK_METERS
	d.x = fposmod(d.x + circ_m * 0.5, circ_m) - circ_m * 0.5
	var hcenter := Vector2(hc) + Vector2(hl.x, hl.z) / TerrainSlice.CHUNK_METERS
	var center_ll := MapMath.lonlat(_center, circ)
	var hll := MapMath.lonlat(hcenter, circ)
	var t := _t()
	var off := MapMath.project(hll, center_ll, t) * MapMath.scale_px(_zoom, _view_px(), circ)
	if not MapMath.facing(hll, center_ll, t):
		off = d.normalized() * maxf(sz.x, sz.y)   # behind the globe: an arrow at the rim toward it
	return MapMath.clamp_home(off, sz * 0.5, d.length(), 14.0)
