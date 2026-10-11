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
const ChunkRecords := preload("res://src/terrain/chunk_records.gd")
const MapMath := preload("res://src/ui/map_math.gd")
const MapTiles := preload("res://src/ui/map_tiles.gd")

const TILES_PER_FRAME := 48
const WHEEL_STEP := 0.25
const DIM := 0.35
const MAX_TILES_DRAWN := 6000
const RECORDS_REFRESH_MS := 1000   # at most one tile recompute per second while chunks keep arriving

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
var _batch_gen: int = 0   # tiles.generation when the running batch was taken
var _last_sig: Array = []
var _records_at_ms: int = 0
var _reveal_tiles: Dictionary = {}
var _reveal_level: int = -1
var _reveal_rev: int = -1
var _records_rev: int = -1

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
	_zoom = clampf(z, MapMath.ZOOM_MIN, maxf(MapMath.zoom_max(circumference()), MapMath.ZOOM_MIN))
	queue_redraw()

func get_center() -> Vector2:
	return _center

## Centre the view on the player, exactly (chunk + local offset, so far from the origin too).
func center_on_player() -> void:
	var pc := _player_chunk_pos()
	if pc.x < INF:
		_center = pc
		_clamp_center()
	queue_redraw()

## The player's position in (fractional) chunks, from the exact world position; (INF, INF) when unknown.
func _player_chunk_pos() -> Vector2:
	if player_slice == null:
		return Vector2(INF, INF)
	if player_slice.has_method("get_world_pos"):
		var wp: Dictionary = player_slice.get_world_pos()
		if wp.has("chunk") and wp.has("local"):
			var c: Vector2i = wp["chunk"]
			var l: Vector3 = wp["local"]
			return Vector2(c) + Vector2(l.x, l.z) / TerrainSlice.CHUNK_METERS
	if player_slice.has_method("get_position"):
		var p: Vector3 = player_slice.get_position()
		return Vector2(p.x, p.z) / TerrainSlice.CHUNK_METERS
	return Vector2(INF, INF)

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
		var pan: Vector2 = event.relative / maxf(ppc, 0.000001)
		if _t() > 0.0:   # on the globe a pixel of east-west drag covers more longitude toward the poles
			var lat := MapMath.lonlat(_center, circumference()).y
			pan.x /= lerpf(1.0, maxf(cos(lat), 0.05), _t())
		_center -= pan
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
	_refresh_records()
	_service_worker()
	# Redraw only when something on screen can have changed: the explored set, the player, the records.
	var rev: int = minimap.revealed_revision() if minimap != null and minimap.has_method("revealed_revision") else 0
	var sig := [rev, _player_chunk_pos(), ChunkRecords.revision(), _world_seed()]
	if sig != _last_sig:
		_last_sig = sig
		queue_redraw()

## Tiles sample generation records too: a record adopted since they were cached may change a biome.
## Throttled; the revision stays pending until the throttle lets it through.
func _refresh_records() -> void:
	var seed_v := _world_seed()
	if seed_v != tiles.seed_v:
		tiles.reset(seed_v)
		_records_rev = ChunkRecords.revision()
	elif ChunkRecords.revision() != _records_rev and Time.get_ticks_msec() - _records_at_ms >= RECORDS_REFRESH_MS:
		_records_rev = ChunkRecords.revision()
		_records_at_ms = Time.get_ticks_msec()
		tiles.invalidate()
		queue_redraw()

## Collect a finished batch and start the next, a few tiles per frame, off the main thread.
func _service_worker() -> void:
	if _thread != null:
		if _thread.is_alive():
			return
		var done: Array = _thread.wait_to_finish()
		_thread = null
		if _batch_seed == tiles.seed_v and _batch_gen == tiles.generation:
			tiles.store(done)
		queue_redraw()
	if tiles.pending_count() == 0:
		return
	_batch_seed = tiles.seed_v
	_batch_gen = tiles.generation
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
	var rev: int = minimap.revealed_revision() if minimap.has_method("revealed_revision") else 0
	if level != _reveal_level or rev != _reveal_rev:
		_reveal_tiles.clear()
		for c in minimap.get_revealed_chunks():
			var t := MapMath.tile_of(c, level)
			_reveal_tiles["%d,%d" % [t.x, t.y]] = true
		_reveal_level = level
		_reveal_rev = rev
	return _reveal_tiles

func _draw() -> void:
	var sz := size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	_refresh_records()
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.03, 0.04, 0.08))
	var circ := circumference()
	var t := _t()
	var ppc := _px_per_chunk()
	var level := MapMath.level_for(ppc)
	var scale := MapMath.scale_px(_zoom, _view_px(), circ)
	var origin := sz * 0.5
	var center_ll := MapMath.lonlat(_center, circ)
	var pole := float(TerrainSlice.pole_chunks())
	var tile_chunks := 1 << level
	var x0 := 0
	var x1 := 0
	var z0 := 0
	var z1 := 0
	while true:   # a coarser level until the visible tiles fit the draw budget
		tile_chunks = 1 << level
		var span := minf(float(circ) * 0.5, pow(2.0, _zoom) * 0.75 * maxf(sz.x, sz.y) / maxf(_view_px(), 1.0) + tile_chunks)
		var span_x := span
		if t > 0.0 and absf(center_ll.y) > 0.6:   # near a pole the visible cap wraps every longitude
			span_x = float(circ) * 0.5
		x0 = floori((_center.x - span_x) / tile_chunks)
		x1 = ceili((_center.x + span_x) / tile_chunks)
		z0 = floori(maxf(_center.y - span, -pole - 2.0) / tile_chunks)
		z1 = ceili(minf(_center.y + span, pole + 2.0) / tile_chunks)
		if (x1 - x0 + 1) * (z1 - z0 + 1) <= MAX_TILES_DRAWN or level >= MapMath.MAX_LEVEL:
			break
		level += 1
	if t >= 0.5:   # a lit disc behind the sphere
		draw_circle(origin, scale, Color(0.05, 0.07, 0.14))
	var fog := _revealed_tiles(level) if not show_true_planet else {}
	# Request coarse ancestors of what is on screen first: the picture is complete at once.
	tiles.clear_pending()   # only what is on screen now is worth computing
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
			if not show_true_planet and not fog.has(_fog_key(tx, tz, tile_chunks, level)):
				col = col.darkened(1.0 - DIM)
			var pts := PackedVector2Array()
			var folded := false
			for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				var ll := MapMath.lonlat(Vector2(cx0, cz0) + corner * float(tile_chunks), circ)
				ll.y = clampf(ll.y, -PI * 0.5, PI * 0.5)   # a corner past a pole sits on it
				if not MapMath.facing(ll, center_ll, t):
					folded = true   # a corner over the limb would draw mirrored
					break
				pts.append(origin + MapMath.project(ll, center_ll, t) * scale)
			if folded:
				continue
			draw_colored_polygon(pts, col)
	_draw_markers(sz, origin, center_ll, t, scale, circ)

## The fog-set key of a tile: its centre chunk, seam-wrapped, as a tile at `level`.
func _fog_key(tx: int, tz: int, tile_chunks: int, level: int) -> String:
	var t := MapMath.tile_of(TerrainSlice.wrap_chunk(Vector2i(tx * tile_chunks + tile_chunks / 2, tz * tile_chunks + tile_chunks / 2)), level)
	return "%d,%d" % [t.x, t.y]

func _biome_color(biome: String) -> Color:
	if minimap != null and minimap.has_method("biome_color"):
		return minimap.biome_color(biome)
	return Color(0.4, 0.4, 0.4)

func _draw_markers(sz: Vector2, origin: Vector2, center_ll: Vector2, t: float, scale: float, circ: int) -> void:
	var font := ThemeDB.fallback_font
	var pcp := _player_chunk_pos()
	if pcp.x < INF:
		var pll := MapMath.lonlat(pcp, circ)
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
