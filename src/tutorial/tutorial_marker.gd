extends Node3D
## Phase 290 — a tutorial step's target marker. A step may carry `marker: { kind, ...params }` (fabric
## `tutorial.js`, `MARKER_KINDS`); the client finds the spot round the player when such a step comes up and shows a
## beacon there with a label. It reads the voxel columns this machine already has and changes no game state.
##
## `ore_near_surface { item, maxDepthBlocks, radiusMetres }`: the nearest column within `radiusMetres` whose `item`
## lies at most `maxDepthBlocks` blocks under its surface (block 1 is the surface block). The topsoil of the newcomer
## grounds is metres deep, so `mine_stone` marks where a Ferrite vein comes that close to the surface instead.

const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")
const WorldPos := preload("res://src/terrain/world_pos.gd")
const I18n := preload("res://src/core/i18n.gd")

const TILE := VoxelConsts.TILE_SIZE
const STEP := VoxelConsts.STEP_HEIGHT
const CHUNK_TILES := int(WorldPos.CHUNK_METERS / VoxelConsts.TILE_SIZE)
const BEACON_HEIGHT := 6.0

## The first eligible step, in `eligible` order, that carries a marker (`{}` for none).
static func marker_step(eligible: Array) -> Dictionary:
	for s in eligible:
		var m: Variant = (s as Dictionary).get("marker", null)
		if m is Dictionary and not (m as Dictionary).is_empty():
			return s
	return {}

## The tile under a `{chunk, local}` world position (exact: integer chunk plus a small local).
static func tile_of(pos: Dictionary) -> Vector2i:
	var c: Vector2i = pos["chunk"]
	var l: Vector3 = pos["local"]
	return Vector2i(c.x * CHUNK_TILES + floori(l.x / TILE), c.y * CHUNK_TILES + floori(l.z / TILE))

## The centre of `tile`'s top at height `y` as a `{chunk, local}` world position.
static func tile_world_pos(tile: Vector2i, y: float) -> Dictionary:
	var c := Vector2i(floori(float(tile.x) / CHUNK_TILES), floori(float(tile.y) / CHUNK_TILES))
	return { "chunk": c, "local": Vector3((tile.x - c.x * CHUNK_TILES) * TILE + TILE * 0.5, y, (tile.y - c.y * CHUNK_TILES) * TILE + TILE * 0.5) }

## How many blocks down `item` first lies in `tile`'s column (1 = the surface block), or 0 when it is not within
## `max_blocks`. `runs` is the column's resolved runs (bottom → top); `yield_fn(tile, span) -> { material }` names
## what a natural span yields (`VoxelSlice.natural_yield`). A placed block is its own material.
static func depth_of(tile: Vector2i, runs: Array, item: String, max_blocks: int, yield_fn: Callable) -> int:
	if runs.is_empty():
		return 0
	var run: Dictionary = runs[-1]
	var top := float(run["top"])
	for i in range(1, max_blocks + 1):
		var span := { "bottom": top - i * STEP, "top": top - (i - 1) * STEP, "material": str(run.get("material", "")) }
		if float(span["bottom"]) < float(run["bottom"]) - 0.000001:
			return 0   # the column's top run is thinner than the search: an overhang, not the ground
		var material := str(span["material"])
		if material == "":
			material = str((yield_fn.call(tile, span) as Dictionary).get("material", ""))
		if material == item:
			return i
	return 0

## The tile offsets of a disc of `radius_tiles`, nearest first, as `Vector3i(d2, dx, dz)`; built once per radius.
## `coarse`: every other tile each way. A vein is at least 4 tiles across (`OreField.RADIUS_MIN_TILES`), so the grid
## lands on nearly every one at a quarter of the column reads (a natural span's yield is the costly read); where the
## surface cuts a vein to a strip 1-2 tiles wide it can miss, so a search that finds nothing on the grid goes on with
## the other tiles (`coarse` false: the disc's tiles the grid skipped).
static var _discs: Dictionary = {}
static func disc(radius_tiles: int, coarse: bool = true) -> Array:
	var key := Vector2i(radius_tiles, 1 if coarse else 0)
	if not _discs.has(key):
		var offsets: Array = []
		for dx in range(-radius_tiles, radius_tiles + 1):
			for dz in range(-radius_tiles, radius_tiles + 1):
				var d2 := dx * dx + dz * dz
				if d2 <= radius_tiles * radius_tiles and (dx % 2 == 0 and dz % 2 == 0) == coarse:
					offsets.append(Vector3i(d2, dx, dz))
		offsets.sort()
		_discs[key] = offsets
	return _discs[key]

## A search for an `ore_near_surface` spot that can run a slice at a time (`step`), so the client spreads the column
## reads over frames. Tiles are tried nearest first, so it stops at the first hit; `hit` is
## `{ tile, depth_blocks, max_blocks, top, distance }`, `{}` when nothing was found.
class Search:
	var origin: Vector2i
	var item := ""
	var max_blocks := 0
	var offsets: Array = []
	var runs_fn: Callable
	var yield_fn: Callable
	var depth_fn: Callable   ## `depth_of`
	var fine_offsets: Array = []   ## the tiles the coarse grid skipped, tried once it finds nothing
	var next := 0
	var hit: Dictionary = {}
	var done := false

	## Run until finished, or until `budget_usec` (< 0: no limit) has passed; true once finished.
	func step(budget_usec: int = -1) -> bool:
		var t0 := Time.get_ticks_usec()
		while not done:
			if next >= offsets.size():
				if fine_offsets.is_empty():
					done = true
					break
				offsets = fine_offsets
				fine_offsets = []
				next = 0
				continue
			var o: Vector3i = offsets[next]
			next += 1
			var tile := origin + Vector2i(o.y, o.z)
			var runs: Array = runs_fn.call(tile)
			var depth: int = depth_fn.call(tile, runs, item, max_blocks, yield_fn)
			if depth > 0:
				hit = { "tile": tile, "depth_blocks": depth, "max_blocks": max_blocks,
					"top": float((runs[-1] as Dictionary)["top"]), "distance": sqrt(float(o.x)) * TILE }
				done = true
			elif budget_usec >= 0 and Time.get_ticks_usec() - t0 >= budget_usec:
				break
		return done

## A search round `origin` (a tile) for the nearest column within `marker.radiusMetres` whose `marker.item` is at
## most `marker.maxDepthBlocks` down; `runs_fn(tile) -> Array` reads a column. Already done (no hit) for a bad marker.
static func ore_search(origin: Vector2i, marker: Dictionary, runs_fn: Callable, yield_fn: Callable) -> Search:
	var srch := Search.new()
	srch.origin = origin
	srch.item = str(marker.get("item", ""))
	srch.max_blocks = int(marker.get("maxDepthBlocks", 0))
	srch.runs_fn = runs_fn
	srch.yield_fn = yield_fn
	srch.depth_fn = depth_of
	var radius_tiles := int(floor(float(marker.get("radiusMetres", 0.0)) / TILE))
	if srch.item == "" or srch.max_blocks < 1 or radius_tiles < 0:
		srch.done = true
	else:
		srch.offsets = disc(radius_tiles)
		srch.fine_offsets = disc(radius_tiles, false)
	return srch

## `ore_near_surface` in one go: the hit of a finished `ore_search`.
static func find_ore_near_surface(origin: Vector2i, marker: Dictionary, runs_fn: Callable, yield_fn: Callable) -> Dictionary:
	var srch := ore_search(origin, marker, runs_fn, yield_fn)
	srch.step()
	return srch.hit

## A search for a step's marker round `origin` with the voxel slice's own columns; null for an unknown kind.
static func search(marker: Dictionary, origin: Vector2i, voxel: Object) -> Search:
	if voxel == null:
		return null
	match str(marker.get("kind", "")):
		"ore_near_surface":
			return ore_search(origin, marker,
				func(t: Vector2i) -> Array: return voxel.get_runs_at_tile(t),
				func(t: Vector2i, span: Dictionary) -> Dictionary: return voxel.natural_yield(t, span))
	return null

## Find a step's marker round `origin` in one go; `{}` for an unknown kind or no spot.
static func find(marker: Dictionary, origin: Vector2i, voxel: Object) -> Dictionary:
	var srch := search(marker, origin, voxel)
	if srch == null:
		return {}
	srch.step()
	return srch.hit

## The beacon's label for a found marker, `metres` away.
static func label_text(marker: Dictionary, metres: float) -> String:
	return I18n.t("tutorial.marker." + str(marker.get("kind", "")), [I18n.content("item", str(marker.get("item", ""))), int(round(metres))])

# --- The beacon -------------------------------------------------------------------------------------------------

var step_id := ""
var marker: Dictionary = {}
var found: Dictionary = {}
var world_pos: Dictionary = {}   ## the marked column's top centre, `{chunk, local}`
var _label: Label3D = null

func _init() -> void:
	name = "TutorialMarker"
	var pillar := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.06
	mesh.bottom_radius = 0.06
	mesh.height = BEACON_HEIGHT
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.3, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	pillar.mesh = mesh
	pillar.position = Vector3(0.0, BEACON_HEIGHT * 0.5, 0.0)
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pillar)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0015
	_label.outline_size = 6
	_label.position = Vector3(0.0, BEACON_HEIGHT + 0.4, 0.0)
	add_child(_label)

## Mark `hit` (from `find`) for `step`.
func set_target(step: Dictionary, hit: Dictionary) -> void:
	step_id = str(step.get("id", ""))
	marker = step.get("marker", {})
	found = hit
	world_pos = tile_world_pos(hit["tile"], float(hit["top"]))

## Place the beacon in the scene from the player's exact and scene positions (so a rebase never shifts it), and
## say how far it is.
func follow(player_world: Dictionary, player_scene: Vector3) -> void:
	if world_pos.is_empty():
		return
	var pc: Vector2i = player_world["chunk"]
	var pl: Vector3 = player_world["local"]
	var tc: Vector2i = world_pos["chunk"]
	var tl: Vector3 = world_pos["local"]
	var delta := Vector3(float(tc.x - pc.x) * WorldPos.CHUNK_METERS + (tl.x - pl.x), tl.y - pl.y,
		float(tc.y - pc.y) * WorldPos.CHUNK_METERS + (tl.z - pl.z))
	position = player_scene + delta
	_label.text = label_text(marker, Vector2(delta.x, delta.z).length())

## A `{chunk, local}` world record as a flat world Vector3 (float32: coarse far from the origin; the host resolves the
## tile from the record itself).
static func to_vector(pos: Dictionary) -> Vector3:
	var c: Vector2i = pos["chunk"]
	var l: Vector3 = pos["local"]
	return Vector3(float(c.x) * WorldPos.CHUNK_METERS + l.x, l.y, float(c.y) * WorldPos.CHUNK_METERS + l.z)

## The spot step `step_id` marks: `beacon`'s when it is up for that step, else the same search round `origin`.
static func spot_for(step_id: String, beacon: Object, origin: Vector2i, voxel: Object, table: Array) -> Dictionary:
	if beacon != null and is_instance_valid(beacon) and beacon.step_id == step_id:
		return beacon.found
	for st in table:
		if str(st["id"]) == step_id:
			return find(st.get("marker", {}), origin, voxel)
	return {}
