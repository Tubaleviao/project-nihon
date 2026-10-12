extends Control
## Map window (Phase 111) — the whole world as a cube papercraft.
##
## The planet is six equal square faces, each a grid of tiles sampled from the biome field the terrain is
## generated from (`MapTiles`). The flat map shows them as the cube's net; the planet toggle folds them
## into a sphere. Close in both look flat around the centre. Undiscovered tiles are one fog colour and are
## never sampled, so no biome shows there. Hovering shows the latitude and longitude under the cursor;
## right-click adds a waypoint, or deletes the one under the cursor.
##
## Drawing needs a canvas and does not run headless; the maths it relies on is in MapMath/MapTiles.

const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const ChunkRecords := preload("res://src/terrain/chunk_records.gd")
const MapMath := preload("res://src/ui/map_math.gd")
const MapTiles := preload("res://src/ui/map_tiles.gd")
const WorldPos := preload("res://src/terrain/world_pos.gd")

const TILES_PER_FRAME := 48
const WHEEL_STEP := 0.25
const MAX_TILES_DRAWN := 3000
const RECORDS_REFRESH_MS := 1000   # at most one tile recompute per second while chunks keep arriving
## Screen sampling step as a share of a tile: fine enough to hit the smaller tiles at the cube's corners.
const SAMPLE_SHARE := 0.6
## Coarser ancestors requested above each visible discovered tile, so the picture is complete at once.
const COARSE_LEVELS := 3
const FOG_COLOR := Color(0.16, 0.18, 0.21)
const BACKGROUND := Color(0.03, 0.04, 0.08)
const DISC_COLOR := Color(0.05, 0.07, 0.14)
const WAYPOINT_PICK_PX := 10.0
const ZOOM_START := 6.5

var minimap: Node = null
var terrain_slice: Node = null
var player_slice: Node = null
## False: the flat cube net. True: the six faces folded into a planet.
var show_planet: bool = false

var tiles := MapTiles.new()
var _zoom: float = ZOOM_START
var _center: Vector2 = Vector2.ZERO   # view centre in chunks
var _dragging := false
var _thread: Thread = null
var _batch_seed: int = 0
var _batch_gen: int = 0   # tiles.generation when the running batch was taken
var _last_sig: Array = []
var _records_at_ms: int = 0
var _reveal_tiles: Dictionary = {}   # Vector4i tile -> true, discovered tiles at _reveal_level
var _reveal_level: int = -1
var _reveal_rev: int = -1
var _records_rev: int = -1
var _coords: Label = null

func _init() -> void:
	name = "MapWindow"
	custom_minimum_size = Vector2(520, 460)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	set_zoom(ZOOM_START)   # a small world's farthest zoom can be nearer than the default

func _ready() -> void:
	_coords = Label.new()
	_coords.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coords.visible = false
	add_child(_coords)

func circumference() -> int:
	return TerrainSlice.circumference_chunks()

func grid() -> int:
	return MapMath.face_grid(TerrainSlice.pole_chunks())

func get_zoom() -> float:
	return _zoom

func max_zoom() -> float:
	return maxf(MapMath.zoom_max(circumference(), show_planet), MapMath.ZOOM_MIN)

func set_zoom(z: float) -> void:
	_zoom = clampf(z, MapMath.ZOOM_MIN, max_zoom())
	queue_redraw()

## Switch between the flat net and the folded planet. The zoom range differs, so it is pulled into it.
func set_planet(on: bool) -> void:
	show_planet = on
	set_zoom(_zoom)

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
	elif what == NOTIFICATION_MOUSE_EXIT and _coords != null:
		_coords.visible = false

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
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_right_click(event.position - size * 0.5)
			accept_event()
	elif event is InputEventMouseMotion:
		if _dragging:
			_pan(event.relative)
			accept_event()
		else:
			_update_coords(event.position - size * 0.5)

## Drag: the flat net slides under the cursor; the planet turns (a pixel of east-west covers more
## longitude toward the poles, so it is scaled by cos latitude).
func _pan(rel: Vector2) -> void:
	var circ := circumference()
	if show_planet:
		var pan := rel / maxf(_ppc(), 0.000001)
		pan.x /= maxf(cos(MapMath.lonlat(_center, circ).y), 0.05)
		_center -= pan
	else:
		var f := MapMath.frac_of_chunk(_center, circ)
		var n := MapMath.net_of_frac(int(f.x), f.y, f.z)
		n = MapMath.clamp_net(n - rel / maxf(_face_px(), 0.000001))
		var nf := MapMath.frac_of_net(n)
		_center = MapMath.chunk_of_frac(int(nf.x), nf.y, nf.z, circ)
	_clamp_center()
	queue_redraw()

func _view_px() -> float:
	return maxf(minf(size.x, size.y), 1.0)

## Pixels per chunk (finest tile) at this zoom.
func _ppc() -> float:
	return _view_px() / pow(2.0, _zoom)

## Pixels across one face. A face is as wide as a quarter of the circumference: `pole_chunks` chunks.
func _face_px() -> float:
	return _ppc() * float(TerrainSlice.pole_chunks())

## Pixels per radian of the planet's sphere.
func _scale() -> float:
	return _ppc() * float(circumference()) / TAU

func _center_ll() -> Vector2:
	return MapMath.lonlat(_center, circumference())

## A face fraction as a screen offset (px from the window centre): x, y, and depth (> 0 when it faces
## the viewer; always 1 on the net).
func _to_px(face: int, fx: float, fy: float) -> Vector3:
	if show_planet:
		var p := MapMath.project_planet(MapMath.dir_of_frac(face, fx, fy), MapMath.planet_basis(_center_ll()))
		var s := _scale()
		return Vector3(p.x * s, p.y * s, p.z)
	var cf := MapMath.frac_of_chunk(_center, circumference())
	var cn := MapMath.net_of_frac(int(cf.x), cf.y, cf.z)
	var n := MapMath.net_of_frac(face, fx, fy)
	var dx := fposmod(n.x - cn.x + 2.0, 4.0) - 2.0   # the band wraps: the short way round
	return Vector3(dx * _face_px(), (n.y - cn.y) * _face_px(), 1.0)

## The face fraction under a screen offset (px from the window centre); face -1 when there is none.
func _frac_at(offset: Vector2) -> Vector3:
	if show_planet:
		var s := _scale()
		if s <= 0.0:
			return Vector3(-1, 0, 0)
		var d := MapMath.unproject_planet(offset / s, MapMath.planet_basis(_center_ll()))
		if d == Vector3.ZERO:
			return Vector3(-1, 0, 0)
		return MapMath.frac_of_dir(d)
	var f := _face_px()
	if f <= 0.0:
		return Vector3(-1, 0, 0)
	var cf := MapMath.frac_of_chunk(_center, circumference())
	var cn := MapMath.net_of_frac(int(cf.x), cf.y, cf.z)
	return MapMath.frac_of_net(cn + offset / f)

func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	_refresh_records()
	_service_worker()
	# Redraw only when something on screen can have changed: the explored set, the player, the records.
	var sig := redraw_signature()
	if sig != _last_sig:
		_last_sig = sig
		queue_redraw()

## What the picture depends on that changes by itself: the explored set, the player's PIXEL (not the
## player's exact position, which moves every frame), the records and the world. Unequal => redraw.
func redraw_signature() -> Array:
	var rev: int = minimap.revealed_revision() if minimap != null and minimap.has_method("revealed_revision") else 0
	return [rev, _player_pixel(), ChunkRecords.revision(), _world_seed()]

## The player's marker in whole pixels from the window centre; (-1 << 30) when it is not on screen or unknown.
func _player_pixel() -> Vector2i:
	var pcp := _player_chunk_pos()
	if pcp.x >= INF:
		return Vector2i(-(1 << 30), 0)
	var f := MapMath.frac_of_chunk(pcp, circumference())
	var p := _to_px(int(f.x), f.y, f.z)
	return Vector2i(roundi(p.x), roundi(p.y))

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
	_thread.start(MapTiles.compute.bind(_batch_seed, circumference(), grid(), batch))

func _exit_tree() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null

func _world_seed() -> int:
	if terrain_slice != null and terrain_slice.has_method("get_world_seed"):
		return terrain_slice.get_world_seed()
	return 0

## Discovered tiles at `level`, rebuilt when the level or the explored set changes.
func _revealed_tiles(level: int) -> Dictionary:
	if minimap == null:
		return {}
	var rev: int = minimap.revealed_revision() if minimap.has_method("revealed_revision") else 0
	if level != _reveal_level or rev != _reveal_rev:
		_reveal_tiles.clear()
		for c in minimap.get_revealed_chunks():
			_reveal_tiles[MapMath.tile_of_chunk(Vector2(c) + Vector2(0.5, 0.5), level, circumference(), grid())] = true
		_reveal_level = level
		_reveal_rev = rev
	return _reveal_tiles

## The tiles under the window at `level`, found by sampling the window on a grid finer than a tile. A
## point off the net's cross or behind the planet has no tile and is skipped.
func visible_tiles(level: int, sz: Vector2) -> Dictionary:
	var out := {}
	var step := maxf(MapMath.tile_px(level, _face_px(), grid()) * SAMPLE_SHARE, 1.0)
	var half := sz * 0.5
	var sy := -half.y + step * 0.5
	while sy < half.y:
		var sx := -half.x + step * 0.5
		while sx < half.x:
			var f := _frac_at(Vector2(sx, sy))
			if f.x >= 0.0:
				out[MapMath.tile_of_frac(level, int(f.x), f.y, f.z, grid())] = true
			sx += step
		sy += step
	return out

## The level to draw at: the finest that keeps a tile on screen, coarser while the window would hold
## more than MAX_TILES_DRAWN tiles.
func level_for_view(sz: Vector2) -> int:
	var g := grid()
	var level := MapMath.level_for(_face_px() / float(g), g)
	while level < MapMath.top_level(g) and sz.x * sz.y / pow(MapMath.tile_px(level, _face_px(), g), 2.0) > MAX_TILES_DRAWN:
		level += 1
	return level

## Queue what the picture needs. Only discovered tiles are requested: an undiscovered tile is drawn as fog
## and never sampled, so its biome is not in memory. Queued tiles from an older view are dropped.
func request_visible(seen: Dictionary, discovered: Dictionary) -> void:
	tiles.clear_pending()
	var top := MapMath.top_level(grid())
	for tile in seen:
		if not discovered.has(tile):
			continue
		tiles.request(tile)
		var anc: Vector4i = tile
		for i in COARSE_LEVELS:
			if anc.x >= top:
				break
			anc = Vector4i(anc.x + 1, anc.y, anc.z >> 1, anc.w >> 1)
			tiles.request(anc)

func _draw() -> void:
	var sz := size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	_refresh_records()
	draw_rect(Rect2(Vector2.ZERO, sz), BACKGROUND)
	var origin := sz * 0.5
	var g := grid()
	var level := level_for_view(sz)
	var seen := visible_tiles(level, sz)
	var discovered := _revealed_tiles(level)
	if show_planet:
		draw_circle(origin, _scale(), DISC_COLOR)
	request_visible(seen, discovered)
	var frac := 1.0 / float(g >> level)
	for tile in seen:
		var col := FOG_COLOR
		if discovered.has(tile):
			var biome := tiles.best_biome(tile)
			if biome != "":
				col = _biome_color(biome)
		var x0: float = tile.z * frac
		var y0: float = tile.w * frac
		var pts := _tile_polygon(tile.y, Rect2(x0, y0, frac, frac), origin)
		if pts.size() == 4:
			draw_colored_polygon(pts, col)
	_draw_markers(sz, origin)

## The four corners of a tile on screen, or nothing when the whole tile is behind the planet. On the
## planet a corner behind the rim is pulled onto it, so a tile at the edge still reads as a tile.
func _tile_polygon(face: int, r: Rect2, origin: Vector2) -> PackedVector2Array:
	var corners := [r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]
	var pts := PackedVector2Array()
	if show_planet:
		var behind := 0
		for c in corners:
			var p := _to_px(face, c.x, c.y)
			var xy := Vector2(p.x, p.y)
			if p.z < 0.0:
				behind += 1
				xy = xy.normalized() * _scale()
			pts.append(origin + xy)
		return pts if behind < 4 else PackedVector2Array()
	# A flat tile: its corners are offsets from its centre, in face units, so the band's wrap cannot tear it.
	var mid := r.get_center()
	var anchor := _to_px(face, mid.x, mid.y)
	var face_px := _face_px()
	for c in corners:
		pts.append(origin + Vector2(anchor.x, anchor.y) + (c - mid) * face_px)
	return pts

func _biome_color(biome: String) -> Color:
	if minimap != null and minimap.has_method("biome_color"):
		return minimap.biome_color(biome)
	return Color(0.4, 0.4, 0.4)

func _draw_markers(sz: Vector2, origin: Vector2) -> void:
	var pcp := _player_chunk_pos()
	if pcp.x < INF:
		var f := MapMath.frac_of_chunk(pcp, circumference())
		var p := _to_px(int(f.x), f.y, f.z)
		if p.z > 0.0:
			draw_circle(origin + Vector2(p.x, p.y), 4.0, Color.WHITE)
	var home := home_marker(sz)
	if not home.is_empty():
		_draw_marker(origin, home, "Home", Color(1.0, 0.8, 0.2), Color(1.0, 0.9, 0.5))
	if minimap != null and minimap.has_method("get_waypoints"):
		for w in minimap.get_waypoints():
			var m := marker_for(w["pos"], sz)
			if not m.is_empty():
				_draw_marker(origin, m, str(w["name"]), Color(0.4, 0.9, 1.0), Color(0.7, 0.95, 1.0))

func _draw_marker(origin: Vector2, m: Dictionary, label: String, fill: Color, text_col: Color) -> void:
	var font := ThemeDB.fallback_font
	var pos: Vector2 = origin + m["pos"]
	if m["inside"]:
		draw_circle(pos, 6.0, fill)
		draw_string(font, pos + Vector2(8, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, text_col)
	else:
		var a: float = m["angle"]
		var dir := Vector2(cos(a), sin(a))
		var perp := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([pos + dir * 10.0, pos - dir * 6.0 + perp * 7.0, pos - dir * 6.0 - perp * 7.0]), fill)
		draw_string(font, pos - dir * 14.0 - Vector2(24, -4), "%s %s" % [label, MapMath.distance_text(m["distance"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, text_col)

## The home marker for a window of `sz`: { inside, pos (px from the centre), distance, angle }, or {}
## when no respawn point is recorded.
func home_marker(sz: Vector2) -> Dictionary:
	if player_slice == null or not ("respawn_world_pos" in player_slice) or player_slice.respawn_world_pos.is_empty():
		return {}
	return marker_for(player_slice.respawn_world_pos, sz)

## A `{chunk, local}` place as a marker for a window of `sz`: { inside, pos, distance, angle }. Behind
## the planet it is an arrow at the rim toward it. The distance is the great-circle way round the planet.
func marker_for(world: Dictionary, sz: Vector2) -> Dictionary:
	var circ := circumference()
	var hc: Vector2i = world["chunk"]
	var hl: Vector3 = world["local"]
	var hcenter := Vector2(hc) + Vector2(hl.x, hl.z) / TerrainSlice.CHUNK_METERS
	var f := MapMath.frac_of_chunk(hcenter, circ)
	var p := _to_px(int(f.x), f.y, f.z)
	var off := Vector2(p.x, p.y)
	if p.z < 0.0:
		off = off.normalized() * maxf(sz.x, sz.y)
	var dist := MapMath.great_circle_m(_center_ll(), MapMath.lonlat(hcenter, circ), float(circ) * TerrainSlice.CHUNK_METERS)
	return MapMath.clamp_home(off, sz * 0.5, dist, 14.0)

## The `{chunk, local}` place under a point `offset` px from the window centre, or {} when there is none
## (off the planet, or outside the net's cross).
func world_pos_at(offset: Vector2) -> Dictionary:
	var f := _frac_at(offset)
	if f.x < 0.0:
		return {}
	var ll := MapMath.lonlat_of_dir(MapMath.dir_of_frac(int(f.x), f.y, f.z))
	return _pos_from_ll(ll, circumference())

## Right-click: delete the waypoint under the cursor, else add one there.
func _right_click(offset: Vector2) -> void:
	if minimap == null:
		return
	if minimap.has_method("get_waypoints") and minimap.has_method("remove_waypoint"):
		var waypoints: Array = minimap.get_waypoints()
		for i in waypoints.size():
			var m := marker_for(waypoints[i]["pos"], size)
			if not m.is_empty() and (m["pos"] as Vector2).distance_to(offset) <= WAYPOINT_PICK_PX:
				minimap.remove_waypoint(i)
				queue_redraw()
				return
	var pos := world_pos_at(offset)
	if not pos.is_empty() and minimap.has_method("add_waypoint"):
		minimap.add_waypoint("", pos)

## The latitude and longitude under the cursor, in the same terms as /where, in a small label by the
## cursor. Hidden off the planet.
func _update_coords(offset: Vector2) -> void:
	if _coords == null:
		return
	var f := _frac_at(offset)
	if f.x < 0.0:
		_coords.visible = false
		return
	var chunk := MapMath.chunk_of_frac(int(f.x), f.y, f.z, circumference())
	var lat := TerrainSlice.latitude_at(chunk.y * TerrainSlice.CHUNK_METERS)
	var lon := TerrainSlice.longitude_at(chunk.x * TerrainSlice.CHUNK_METERS)
	_coords.text = "%.2f°%s  %.2f°%s" % [absf(lat), "N" if lat >= 0.0 else "S", absf(lon), "E" if lon >= 0.0 else "W"]
	_coords.position = size * 0.5 + offset + Vector2(14, 14)
	_coords.visible = true

## The exact `{chunk, local}` of a lon/lat (radians); {} past a pole.
func _pos_from_ll(ll: Vector2, circ: int) -> Dictionary:
	if absf(ll.y) > PI * 0.5:
		return {}
	var c := MapMath.chunk_of_lonlat(ll, circ)
	var chunk := Vector2i(floori(c.x), floori(c.y))
	var local := Vector3((c.x - chunk.x) * TerrainSlice.CHUNK_METERS, 0.0, (c.y - chunk.y) * TerrainSlice.CHUNK_METERS)
	return WorldPos.normalized({ "chunk": TerrainSlice.wrap_chunk(chunk), "local": local })
