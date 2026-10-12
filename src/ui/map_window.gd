extends Control
## Map window — the whole world as a cube papercraft, from street level out to the whole planet.
##
## The planet is six equal square faces (`MapMath`, an equiangular cube, so tiles stay square at the
## poles too). Flat, the faces unfold into a net around the face in view: the band through it wraps
## round the planet, the faces above and below hang off it. With the Planet toggle on, the same faces
## fold into an orthographic globe that is dragged round. The picture is sampled bit by bit from the
## same fields the terrain is generated from (`MapTiles`), coarse first, on a worker thread.
##
## Unexplored land is one flat fog colour and is never sampled. Hovering shows the X/Y
## under the cursor; right-click adds a waypoint, or deletes the one under the cursor.
##
## Drawing needs a canvas and does not run headless; the maths it relies on is in MapMath/MapTiles.

const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const ChunkRecords := preload("res://src/terrain/chunk_records.gd")
const MapMath := preload("res://src/ui/map_math.gd")
const MapTiles := preload("res://src/ui/map_tiles.gd")
const WorldPos := preload("res://src/terrain/world_pos.gd")

const TILES_PER_FRAME := 48
const WHEEL_STEP := 0.25
const MAX_TILES_DRAWN := 6000
const RECORDS_REFRESH_MS := 1000   # at most one tile recompute per second while chunks keep arriving
## Cells either side of the home face the flat band may draw.
const NET_REACH := 8
## A coarse ancestor this many levels up is requested with each tile, so the picture fills in at once.
const COARSE_STEP := 3
## A waypoint within this many pixels of the cursor is the one a right-click deletes.
const PICK_PX := 10.0
## Samples across the view used to find which part of each face the globe shows.
const GLOBE_GRID := 20
const ZOOM_START := 6.5
## The globe tilts up to just short of a pole (straight over it, "up" has no direction).
const GLOBE_LAT_MAX := PI * 0.5 - 0.0001

const BG := Color(0.03, 0.04, 0.08)
const FOG := Color(0.22, 0.23, 0.27)
const SEAM := Color(0.0, 0.0, 0.0, 0.35)

var minimap: Node = null
var terrain_slice: Node = null
var player_slice: Node = null
## False: the flat net. True: the faces folded into a globe.
var planet: bool = false

var tiles := MapTiles.new()
var _zoom: float = ZOOM_START
var _home: Array = MapMath.placement_of(0)   # the placement the view centre is on
var _lx: float = 0.0   # the view centre, screen-local on `_home` (plain floats: double precision)
var _ly: float = 0.0
## The globe's camera: longitude and map latitude (radians) of the view centre. Kept in step with the
## net's centre; the globe turns by these so it stays pole-up wherever it is dragged.
var _glon: float = 0.0
var _glat: float = 0.0
var _dragging := false
var _thread: Thread = null
var _batch_seed: int = 0
var _batch_gen: int = 0   # tiles.generation when the running batch was taken
var _last_sig: Array = []
var _records_at_ms: int = 0
var _view_key: Array = []   # what the last tile request covered
var _records_rev: int = -1
var _reveal_rev: int = -1
var _reveal_l0: Dictionary = {}     # chunk -> Vector3i(face, i, j) of its finest tile
var _reveal_sets: Dictionary = {}   # level -> { Vector3i(face, i, j): true }
var _hover: Label = null
var _hover_at: Vector2 = Vector2(-1, -1)

func _init() -> void:
	name = "MapWindow"
	custom_minimum_size = Vector2(520, 460)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_hover = Label.new()
	_hover.name = "Hover"
	_hover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover.visible = false
	_hover.add_theme_font_size_override("font_size", 14)
	_hover.add_theme_color_override("font_outline_color", Color.BLACK)
	_hover.add_theme_constant_override("outline_size", 4)
	add_child(_hover)
	set_zoom(ZOOM_START)

func get_zoom() -> float:
	return _zoom

func set_zoom(z: float) -> void:
	var lo := MapMath.zoom_min(planet, _view_px())
	_zoom = clampf(z, lo, maxf(MapMath.zoom_max(planet), lo))
	queue_redraw()

## Fold the faces into a globe (true) or lay them out flat (false).
func set_planet(on: bool) -> void:
	planet = on
	if not on:   # the net picks up where the globe was, its face turned map-up
		var r := MapMath.upright(_home, _lx, _ly)
		_home = r[0]
		_lx = r[1]
		_ly = r[2]
	set_zoom(_zoom)
	_hide_hover()

## The view centre in (fractional) chunks.
func get_center() -> Vector2:
	var p := _center_xz()
	return Vector2(p[0], p[1])

func _center_xz() -> Array:
	var uv := MapMath.face_uv_of_local(_home, _lx, _ly)
	return MapMath.xz_of_face(MapMath.face_of(_home), uv[0], uv[1])

func center_dir() -> Vector3:
	return _frame()[0] if planet else MapMath.local_dir(_home, _lx, _ly)

## Centre the view on a chunk-space point, its face turned map-up.
func set_center(chunk: Vector2) -> void:
	set_center_xz(chunk.x, chunk.y)

func set_center_xz(x: float, z: float) -> void:
	_set_net_center(x, z)
	var c := float(TerrainSlice.circumference_chunks())
	_glon = x / c * TAU
	_glat = clampf(-z / (c * 0.25) * (PI * 0.5), -GLOBE_LAT_MAX, GLOBE_LAT_MAX)
	queue_redraw()

func _set_net_center(x: float, z: float) -> void:
	var fuv := MapMath.face_uv_xz(x, z)
	var r := MapMath.upright(MapMath.placement_of(fuv[0]), fuv[1], fuv[2])
	_home = r[0]
	_lx = r[1]
	_ly = r[2]

## Centre the view on the player, exactly (chunk + local offset, so far from the origin too).
func center_on_player() -> void:
	var p := _player_xz()
	if not p.is_empty():
		set_center_xz(p[0], p[1])
	queue_redraw()

## The player's position in (fractional) chunks [x, z], from the exact world position; [] when unknown.
func _player_xz() -> Array:
	if player_slice == null:
		return []
	if player_slice.has_method("get_world_pos"):
		var wp: Dictionary = player_slice.get_world_pos()
		if wp.has("chunk") and wp.has("local"):
			return _xz_of_pos(wp)
	if player_slice.has_method("get_position"):
		var p: Vector3 = player_slice.get_position()
		return [p.x / TerrainSlice.CHUNK_METERS, p.z / TerrainSlice.CHUNK_METERS]
	return []

## A `{chunk, local}` place in (fractional) chunks [x, z], in double precision.
static func _xz_of_pos(pos: Dictionary) -> Array:
	var c: Vector2i = pos["chunk"]
	var l: Vector3 = pos["local"]
	return [float(c.x) + l.x / TerrainSlice.CHUNK_METERS, float(c.y) + l.z / TerrainSlice.CHUNK_METERS]

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		center_on_player()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hide_hover()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			set_zoom(_zoom - WHEEL_STEP)
			_update_hover(event.position)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			set_zoom(_zoom + WHEEL_STEP)
			_update_hover(event.position)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			if not _dragging:   # a drag over a pole may leave the band upside down: turn it back
				var r := MapMath.upright(_home, _lx, _ly)
				_home = r[0]
				_lx = r[1]
				_ly = r[2]
				queue_redraw()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			right_click(event.position - size * 0.5)
			_update_hover(event.position)
			accept_event()
	elif event is InputEventMouseMotion:
		if _dragging:
			pan(event.relative)
			accept_event()
		_update_hover(event.position)

## Move the view by a screen drag of `rel` pixels: the flat net slides, the globe turns about its
## poles (east-west) and tilts (north-south).
func pan(rel: Vector2) -> void:
	if planet:
		var radius := maxf(_radius_px(), 0.000001)
		_glat = clampf(_glat + rel.y / radius, -GLOBE_LAT_MAX, GLOBE_LAT_MAX)
		_glon = wrapf(_glon - rel.x / (radius * maxf(cos(_glat), 0.2)), -PI, PI)
		var c := float(TerrainSlice.circumference_chunks())
		_set_net_center(_glon / TAU * c, -_glat / (PI * 0.5) * (c * 0.25))
		queue_redraw()
		return
	var k := maxf(_k(), 0.000001)
	var r := MapMath.wrap_local(_home, _lx - rel.x / k, _ly + rel.y / k)
	_home = r[0]
	_lx = r[1]
	_ly = r[2]
	var xz := _center_xz()
	var c := float(TerrainSlice.circumference_chunks())
	_glon = xz[0] / c * TAU
	_glat = clampf(-xz[1] / (c * 0.25) * (PI * 0.5), -GLOBE_LAT_MAX, GLOBE_LAT_MAX)
	queue_redraw()

## Right-click `offset` px from the window centre: delete the waypoint under it, else add one there.
func right_click(offset: Vector2) -> void:
	if minimap == null:
		return
	var hit := waypoint_at(offset)
	if hit >= 0:
		if minimap.has_method("remove_waypoint"):
			minimap.remove_waypoint(hit)
		return
	var pos := world_pos_at(offset)
	if not pos.is_empty() and minimap.has_method("add_waypoint"):
		minimap.add_waypoint("", pos)

## Index of the waypoint whose marker is within PICK_PX of `offset` (nearest first), or -1.
func waypoint_at(offset: Vector2) -> int:
	if minimap == null or not minimap.has_method("get_waypoints"):
		return -1
	var best := -1
	var best_d := PICK_PX
	var wps: Array = minimap.get_waypoints()
	for i in wps.size():
		var m := marker_for(wps[i]["pos"], size)
		if m.is_empty() or not m["inside"]:
			continue
		var d: float = (m["pos"] as Vector2).distance_to(offset)
		if d <= best_d:
			best_d = d
			best = i
	return best

## The corner label's text for a point `offset` px from the centre: its map X and Y in metres
## (world X and Z), plus the waypoint under the cursor. "" off the planet.
func hover_text(offset: Vector2) -> String:
	var at := place_at(offset)
	if at.is_empty():
		return ""
	var p := MapMath.xz_of_face(at[0], at[1], at[2])
	var text := coords_text(p[0] * TerrainSlice.CHUNK_METERS, p[1] * TerrainSlice.CHUNK_METERS)
	var hit := waypoint_at(offset)
	if hit >= 0:
		text = "%s (right-click to delete)\n%s" % [str(minimap.get_waypoints()[hit]["name"]), text]
	return text

## "X 1234  Y -567": whole metres (Y is the world Z axis).
static func coords_text(x_m: float, z_m: float) -> String:
	return TerrainSlice.xy_text(x_m, z_m)

## The label sits in the bottom-left corner; it shows what is under the cursor.
func _update_hover(pos: Vector2) -> void:
	_hover_at = pos
	var text := hover_text(pos - size * 0.5)
	if text == "":
		_hide_hover()
		return
	_hover.text = text
	_hover.reset_size()
	_hover.position = Vector2(8.0, size.y - _hover.size.y - 6.0)
	_hover.visible = true

func _hide_hover() -> void:
	_hover_at = Vector2(-1, -1)
	if _hover != null:
		_hover.visible = false

func _view_px() -> float:
	return minf(size.x, size.y)

## Pixels per face half-side.
func _k() -> float:
	return MapMath.px_per_unit(_zoom, _view_px())

## The globe's radius in pixels: a half-side is PI/4 of arc.
func _radius_px() -> float:
	return _k() * 4.0 / PI

func _frame() -> Array:
	return MapMath.globe_frame(_glon, _glat)

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
		if _hover.visible:   # a waypoint added or removed under the cursor
			_update_hover(_hover_at)

## What the picture depends on that changes by itself: the explored set, the player's PIXEL (not the
## player's exact position, which moves every frame), the records and the world. Unequal => redraw.
func redraw_signature() -> Array:
	var rev: int = minimap.revealed_revision() if minimap != null and minimap.has_method("revealed_revision") else 0
	return [rev, _player_pixel(), ChunkRecords.revision(), _world_seed()]

## The player's marker in whole pixels from the window centre; (-1 << 30) when it is not on screen or unknown.
func _player_pixel() -> Vector2i:
	var pxz := _player_xz()
	if pxz.is_empty():
		return Vector2i(-(1 << 30), 0)
	var s := screen_of_xz(pxz[0], pxz[1])
	if not s["visible"]:
		return Vector2i(-(1 << 30), 0)
	var off: Vector2 = s["pos"]
	return Vector2i(roundi(off.x), roundi(off.y))

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

# ---------------------------------------------------------------------------
# Fog: which tiles are explored
# ---------------------------------------------------------------------------

## Explored tiles at `level`: every tile holding an explored chunk's centre. Rebuilt per level when the
## explored set changes; each chunk's finest tile is worked out once.
func _revealed_set(level: int) -> Dictionary:
	if minimap == null or not minimap.has_method("get_revealed_chunks"):
		return {}
	var rev: int = minimap.revealed_revision() if minimap.has_method("revealed_revision") else 0
	if rev != _reveal_rev:
		_reveal_rev = rev
		_reveal_sets.clear()
		var chunks: Array = minimap.get_revealed_chunks()
		if _reveal_l0.size() > chunks.size() + 1000:   # chunks the explored set's cap dropped
			_reveal_l0.clear()
		for c in chunks:
			if not _reveal_l0.has(c):
				var fuv := MapMath.face_uv_xz(c.x + 0.5, c.y + 0.5)
				var t := MapMath.tile_index(fuv[1], fuv[2], 0)
				_reveal_l0[c] = Vector3i(fuv[0], t.x, t.y)
	if not _reveal_sets.has(level):
		var s: Dictionary = {}
		for c in _reveal_l0:
			var t: Vector3i = _reveal_l0[c]
			s[Vector3i(t.x, t.y >> level, t.z >> level)] = true
		_reveal_sets[level] = s
	return _reveal_sets[level]

## True when a tile shows its biome. A tile smaller than a couple of chunks is also explored when the
## chunk under its centre is (a big chunk can cover tiles no chunk centre falls in).
func tile_revealed(fog: Dictionary, f: int, level: int, i: int, j: int) -> bool:
	if fog.has(Vector3i(f, i, j)):
		return true
	if minimap == null or not minimap.has_method("is_revealed"):
		return false
	if MapMath.chunks_per_cell() * float(1 << level) >= 2.0:
		return false
	return minimap.is_revealed(MapMath.tile_center_chunk(f, level, i, j))

# ---------------------------------------------------------------------------
# Screen <-> sphere
# ---------------------------------------------------------------------------

## Net units (face half-sides, y up) to pixels from the window centre.
func _net_to_screen(nx: float, ny: float) -> Vector2:
	var k := _k()
	return Vector2((nx - _lx) * k, (_ly - ny) * k)

## The net cells that may be drawn: the band (at least the four faces round it) and the faces above and below.
func _cells() -> Array:
	var hx := size.x * 0.5 / maxf(_k(), 0.000001)
	var i0 := clampi(floori((_lx - hx + 1.0) * 0.5), -NET_REACH, -2)
	var i1 := clampi(floori((_lx + hx + 1.0) * 0.5), 2, NET_REACH)
	return MapMath.net_cells(_home, i0, i1)

## Where a chunk-space point lands: { pos: px from the centre, visible }. On the net, the nearest copy
## of its face; on the globe, `visible` is false on the far side.
func screen_of_xz(x: float, z: float) -> Dictionary:
	if planet:
		var q := MapMath.globe_project(_frame(), MapMath.dir_of_chunk(Vector2(x, z)))
		return { "pos": Vector2(q.x, q.y) * _radius_px(), "visible": q.z > 0.0 }
	var fuv := MapMath.face_uv_xz(x, z)
	var f: int = fuv[0]
	var best := Vector2(INF, INF)
	for cell in _cells():
		if MapMath.face_of(cell[1]) != f:
			continue
		var loc := MapMath.local_of_face_uv(cell[1], f, fuv[1], fuv[2])
		var off := _net_to_screen(2.0 * cell[0].x + loc[0], 2.0 * cell[0].y + loc[1])
		if off.length_squared() < best.length_squared():
			best = off
	return { "pos": best, "visible": best.x < INF }

## The face and local (u, v) under a point `offset` px from the centre: [face, u, v], or [] where
## there is no planet.
func place_at(offset: Vector2) -> Array:
	if planet:
		var d := MapMath.globe_unproject(_frame(), offset / maxf(_radius_px(), 0.000001))
		if d == Vector3.ZERO:
			return []
		var fuv := MapMath.face_uv(d)
		return [int(fuv.x), fuv.y, fuv.z]
	var k := maxf(_k(), 0.000001)
	var nx := _lx + offset.x / k
	var ny := _ly - offset.y / k
	var cell := Vector2i(roundi(nx * 0.5), roundi(ny * 0.5))
	if cell.y != 0 and (cell.x != 0 or absi(cell.y) > 1):
		return []
	if absi(cell.x) > NET_REACH:
		return []
	var pl := _home
	for i in absi(cell.x):
		pl = MapMath.step(pl, signi(cell.x), 0)
	if cell.y != 0:
		pl = MapMath.step(pl, 0, cell.y)
	var uv := MapMath.face_uv_of_local(pl, clampf(nx - 2.0 * cell.x, -1.0, 1.0), clampf(ny - 2.0 * cell.y, -1.0, 1.0))
	return [MapMath.face_of(pl), uv[0], uv[1]]

## The `{chunk, local}` place under a point `offset` px from the window centre, or {} off the planet.
func world_pos_at(offset: Vector2) -> Dictionary:
	var at := place_at(offset)
	if at.is_empty():
		return {}
	var p := MapMath.xz_of_face(at[0], at[1], at[2])
	var chunk := Vector2i(floori(p[0]), floori(p[1]))
	var local := Vector3((p[0] - chunk.x) * TerrainSlice.CHUNK_METERS, 0.0, (p[1] - chunk.y) * TerrainSlice.CHUNK_METERS)
	return WorldPos.normalized({ "chunk": TerrainSlice.wrap_chunk(chunk), "local": local })

# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	var sz := size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	_refresh_records()
	var lo := MapMath.zoom_min(planet, _view_px())
	_zoom = clampf(_zoom, lo, maxf(MapMath.zoom_max(planet), lo))   # the window may have been resized
	draw_rect(Rect2(Vector2.ZERO, sz), BG)
	if planet:
		_draw_globe(sz)
	else:
		_draw_net(sz)
	_draw_markers(sz)

## The flat net: each visible cell is filled with fog, explored tiles are drawn over it as squares.
## All in plain floats: at street zoom a pixel is below a Vector2's step.
func _draw_net(sz: Vector2) -> void:
	var origin := sz * 0.5
	var k := _k()
	var hx := sz.x * 0.5 / k
	var hy := sz.y * 0.5 / k
	var shown: Array = []   # [cell, placement, [x0, x1, y0, y1] screen-local, clipped to the face]
	for cell in _cells():
		var cx: float = 2.0 * cell[0].x
		var cy: float = 2.0 * cell[0].y
		var b := [maxf(-1.0, _lx - hx - cx), minf(1.0, _lx + hx - cx), maxf(-1.0, _ly - hy - cy), minf(1.0, _ly + hy - cy)]
		if b[0] < b[1] and b[2] < b[3]:
			shown.append([cell[0], cell[1], b])
	var level := MapMath.level_for(k)
	var ranges: Array = []
	while true:   # a coarser level until the visible tiles fit the draw budget
		ranges = []
		var count := 0
		for s in shown:
			var r := _tile_range(s[1], s[2], level)
			ranges.append(r)
			count += r.get_area()
		if count <= MAX_TILES_DRAWN or level >= MapMath.max_level():
			break
		level += 1
	var fog := _revealed_set(level)
	var faces: Array = []
	for s in shown:
		faces.append(MapMath.face_of(s[1]))
	_request(faces, ranges, level, fog)
	for n in shown.size():
		var cell: Vector2i = shown[n][0]
		var pl: Array = shown[n][1]
		var f: int = faces[n]
		var cx := 2.0 * cell.x
		var cy := 2.0 * cell.y
		var b: Array = shown[n][2]
		draw_rect(_screen_rect(origin, cx + b[0], cy + b[2], cx + b[1], cy + b[3]), FOG)
		var r: Rect2i = ranges[n]
		for j in range(r.position.y, r.end.y):
			for i in range(r.position.x, r.end.x):
				if not tile_revealed(fog, f, level, i, j):
					continue
				var biome := tiles.best_biome(f, level, i, j)
				if biome == "":
					continue
				var tr := MapMath.tile_rect(level, i, j)
				var a0 := MapMath.local_of_face_uv(pl, f, tr.position.x, tr.position.y)
				var a1 := MapMath.local_of_face_uv(pl, f, tr.end.x, tr.end.y)
				draw_rect(_screen_rect(origin, cx + a0[0], cy + a0[1], cx + a1[0], cy + a1[1]), _biome_color(biome))
		draw_rect(_screen_rect(origin, cx - 1.0, cy - 1.0, cx + 1.0, cy + 1.0), SEAM, false, 1.0)

## The screen rect between two net points, clipped a little past the window so a face far bigger
## than the screen stays in range.
func _screen_rect(origin: Vector2, ax: float, ay: float, bx: float, by: float) -> Rect2:
	var pa := origin + _net_to_screen(ax, ay)
	var pb := origin + _net_to_screen(bx, by)
	var lo := pa.min(pb).max(Vector2(-4, -4))
	var hi := pa.max(pb).min(size + Vector2(4, 4))
	return Rect2(lo, (hi - lo).max(Vector2.ZERO))

## The tiles of a face at `level` under screen-local bounds [x0, x1, y0, y1] of a placement.
func _tile_range(pl: Array, b: Array, level: int) -> Rect2i:
	var a := MapMath.face_uv_of_local(pl, b[0], b[2])
	var c := MapMath.face_uv_of_local(pl, b[1], b[3])
	var lo := MapMath.tile_index(minf(a[0], c[0]), minf(a[1], c[1]), level)
	var hi := MapMath.tile_index(maxf(a[0], c[0]), maxf(a[1], c[1]), level)
	return Rect2i(lo, hi - lo + Vector2i.ONE)

## The globe: a fog disc, explored tiles drawn over it as projected quads, the face seams on top.
func _draw_globe(sz: Vector2) -> void:
	var origin := sz * 0.5
	var radius := _radius_px()
	var frame := _frame()
	if radius < sz.length():
		draw_circle(origin, radius, FOG)
	else:
		draw_rect(Rect2(Vector2.ZERO, sz), FOG)
	var boxes := _globe_boxes(sz, frame, radius)
	var level := mini(MapMath.level_for(_k()), maxi(MapMath.max_level() - MapMath.GLOBE_MIN_SPLIT, 0))
	var faces: Array = []
	var ranges: Array = []
	while true:
		faces = []
		ranges = []
		var count := 0
		for f in boxes:
			var box: Rect2 = boxes[f]
			var lo := MapMath.tile_index(box.position.x, box.position.y, level)
			var hi := MapMath.tile_index(box.end.x, box.end.y, level)
			var r := Rect2i(lo, hi - lo + Vector2i.ONE)
			faces.append(f)
			ranges.append(r)
			count += r.get_area()
		if count <= MAX_TILES_DRAWN or level >= MapMath.max_level():
			break
		level += 1
	var fog := _revealed_set(level)
	_request(faces, ranges, level, fog)
	var uvs := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	for n in faces.size():
		var f: int = faces[n]
		var r: Rect2i = ranges[n]
		for j in range(r.position.y, r.end.y):
			for i in range(r.position.x, r.end.x):
				if not tile_revealed(fog, f, level, i, j):
					continue
				var biome := tiles.best_biome(f, level, i, j)
				if biome == "":
					continue
				var quad := _globe_quad(frame, origin, radius, f, MapMath.tile_rect(level, i, j))
				if quad.is_empty():
					continue
				var col := _biome_color(biome)
				draw_primitive(quad, PackedColorArray([col, col, col, col]), uvs)
	_draw_globe_seams(frame, origin, radius)

## A tile's four corners on screen, a corner behind the globe pushed to the rim; empty when the
## whole tile is behind.
func _globe_quad(frame: Array, origin: Vector2, radius: float, f: int, tr: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var front := false
	for corner in [tr.position, Vector2(tr.end.x, tr.position.y), tr.end, Vector2(tr.position.x, tr.end.y)]:
		var q := MapMath.globe_project(frame, MapMath.dir_of_face(f, corner.x, corner.y))
		var p := Vector2(q.x, q.y)
		if q.z > 0.0:
			front = true
		elif p.length_squared() > 0.0:
			p = p.normalized()
		pts.append(origin + p * radius)
	return pts if front else PackedVector2Array()

## Which part of each face the globe shows: { face: Rect2 of (u, v) }, from a grid over the view and
## points round the rim, padded by a grid step so nothing between samples is missed.
func _globe_boxes(sz: Vector2, frame: Array, radius: float) -> Dictionary:
	var samples: Array = []
	for gy in GLOBE_GRID + 1:
		for gx in GLOBE_GRID + 1:
			samples.append((Vector2(gx, gy) / float(GLOBE_GRID) - Vector2(0.5, 0.5)) * sz)
	if radius < sz.length():
		for a in 64:
			samples.append(Vector2.from_angle(a * TAU / 64.0) * radius * 0.999)
	var boxes: Dictionary = {}
	for s in samples:
		var d := MapMath.globe_unproject(frame, s / radius)
		if d == Vector3.ZERO:
			continue
		var fuv := MapMath.face_uv(d)
		var f := int(fuv.x)
		var p := Vector2(fuv.y, fuv.z)
		boxes[f] = (boxes[f] as Rect2).expand(p) if boxes.has(f) else Rect2(p, Vector2.ZERO)
	# A grid step in local units at the middle of the view, more toward the rim; the pad is generous.
	var pad := minf(2.0 * maxf(sz.x, sz.y) / float(GLOBE_GRID) / maxf(_k(), 0.000001), 2.0)
	var full := Rect2(-1, -1, 2, 2)
	for f in boxes.keys():
		boxes[f] = (boxes[f] as Rect2).grow(pad).intersection(full)
	return boxes

## The cube's edges on the globe, so the papercraft reads when folded too.
func _draw_globe_seams(frame: Array, origin: Vector2, radius: float) -> void:
	const SEGMENTS := 16
	for f in 6:
		for e in 4:
			var pts := PackedVector2Array()
			for s in SEGMENTS + 1:
				var t := -1.0 + 2.0 * s / float(SEGMENTS)
				var uv: Vector2 = [Vector2(t, -1), Vector2(1, t), Vector2(t, 1), Vector2(-1, t)][e]
				var q := MapMath.globe_project(frame, MapMath.dir_of_face(f, uv.x, uv.y))
				if q.z <= 0.0:
					if pts.size() >= 2:
						draw_polyline(pts, SEAM, 1.0)
					pts = PackedVector2Array()
					continue
				pts.append(origin + Vector2(q.x, q.y) * radius)
			if pts.size() >= 2:
				draw_polyline(pts, SEAM, 1.0)

## Queue the explored tiles in view and their coarse ancestors; tiles already cached or queued are
## skipped, queued tiles no longer in view are dropped. Fogged tiles are never sampled.
func _request(faces: Array, ranges: Array, level: int, fog: Dictionary) -> void:
	var view_key := [level, faces, ranges, tiles.generation, tiles.seed_v, _reveal_rev]
	if view_key == _view_key:
		return
	_view_key = view_key
	var coarse := mini(level + COARSE_STEP, MapMath.max_level())
	var shift := coarse - level
	var keep: Dictionary = {}
	for n in faces.size():
		var f: int = faces[n]
		var r: Rect2i = ranges[n]
		var fl := Vector2i(f, level)
		keep[fl] = (keep[fl] as Rect2i).merge(r) if keep.has(fl) else r
		var cr := Rect2i(r.position.x >> shift, r.position.y >> shift,
			((r.end.x - 1) >> shift) - (r.position.x >> shift) + 1, ((r.end.y - 1) >> shift) - (r.position.y >> shift) + 1)
		var fc := Vector2i(f, coarse)
		keep[fc] = (keep[fc] as Rect2i).merge(cr) if keep.has(fc) else cr
	tiles.retain_pending(keep)
	for n in faces.size():
		var f: int = faces[n]
		var r: Rect2i = ranges[n]
		for j in range(r.position.y, r.end.y):
			for i in range(r.position.x, r.end.x):
				if not tile_revealed(fog, f, level, i, j):
					continue
				if coarse > level:
					tiles.request(f, coarse, i >> shift, j >> shift)
				tiles.request(f, level, i, j)

func _biome_color(biome: String) -> Color:
	if minimap != null and minimap.has_method("biome_color"):
		return minimap.biome_color(biome)
	return Color(0.4, 0.4, 0.4)

# ---------------------------------------------------------------------------
# Markers
# ---------------------------------------------------------------------------

func _draw_markers(sz: Vector2) -> void:
	var origin := sz * 0.5
	var pxz := _player_xz()
	if not pxz.is_empty():
		var s := screen_of_xz(pxz[0], pxz[1])
		if s["visible"]:
			draw_circle(origin + s["pos"], 4.0, Color.WHITE)
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

## A `{chunk, local}` place as a marker for a window of `sz`: { inside, pos, distance, angle }. The
## distance is the great-circle arc from the view centre; a place off screen (or behind the globe)
## is an arrow at the edge toward it.
func marker_for(world: Dictionary, sz: Vector2) -> Dictionary:
	var p := _xz_of_pos(world)
	var d := MapMath.dir_of_chunk(Vector2(p[0], p[1]))
	var circ_m := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	var dist := MapMath.arc_m(center_dir(), d, circ_m)
	var s := screen_of_xz(p[0], p[1])
	var off: Vector2 = s["pos"]
	if not s["visible"]:   # behind the globe: an arrow at the rim toward it
		off = off.normalized() * maxf(sz.x, sz.y) if off.length_squared() > 0.0 else Vector2(0.0, -maxf(sz.x, sz.y))
	return MapMath.clamp_home(off, sz * 0.5, dist, 14.0)
