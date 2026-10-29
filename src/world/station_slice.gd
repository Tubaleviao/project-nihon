extends Node
## Station slice — tracks placed crafting stations as world entities with a
## minimal visual marker. Stations gate recipes whose `station` field names a
## required structure (forge, master forge, alchemy bench, …).
##
## The list of placeable station types is derived from the fabric: every
## distinct non-empty `station` value across GameData.RECIPES. No type is
## hardcoded here — add a recipe with a new `station` string and it becomes
## placeable.
##
## Plug contract (GameBus signals emitted):
##   OUT : station_placed(station_id, type, position)
##
## Public API:
##   place_station(type, position)      -> String    (station id; UNVALIDATED, trusted callers
##                                                    only — players go through try_place_station)
##   try_place_station(type, position)  -> String    (snaps to grid, refuses overlap; "" if refused)
##   placement_blocker(type, position)  -> String    ("" when placeable, else a reason code for I18n.reason_text)
##   snap_to_grid(position)             -> Vector3
##   show_preview(type, position) / hide_preview()   translucent placement ghost
##   remove_station(station_id)
##   get_station(station_id)            -> Dictionary
##   get_all_stations()                 -> Array
##   nearest_station(pos, type, radius) -> String    ("" if none in radius)
##   station_near_player(type, radius)  -> bool
##   placeable_station_types()          -> Array     (fabric-derived, sorted)
##   get_place_station_type()           -> String    (current placement selection)
##   cycle_station_type()               -> String    (advance the selection)

## Set by game_root so station_near_player can resolve the player's position.
const WorldPos := preload("res://src/terrain/world_pos.gd")

var player_slice: Node = null

## Placed stations keyed by station id.
var _stations: Dictionary = {}

## Phase 140 — settlement claim guard (`(player_id, xz) -> String`) and the slice that knows the hearth rule.
var claim_guard: Callable = Callable()
var settlement_slice: Node = null

## Phase 63: the scene-origin offset a client rebase has applied to every marker (see `shift_scene`).
const SceneOffset := preload("res://src/core/scene_offset.gd")
var _origin: SceneOffset = SceneOffset.new()

## Shift every placed marker by `shift`. Station records keep their world position untouched.
func shift_scene(shift: Vector3) -> void:
	_origin.value += shift
	for id in _markers:
		(_markers[id] as Node3D).position += shift
	if _preview != null:
		_preview.position += shift

func scene_offset() -> Vector3:
	return _origin.value
var _next_id: int = 0

## Phase 185 — set on a client: `(type, target) -> bool`, true when the host places that type on the
## client's behalf (the bed), so nothing is placed locally.
var remote_placer: Callable = Callable()

func place_remote(type: String, target: Vector3) -> bool:
	return remote_placer.is_valid() and bool(remote_placer.call(type, target))

## Visual markers keyed by station id (MeshInstance3D).
var _markers: Dictionary = {}

## Currently selected station type for placement (cycled via cycle_station_type).
var _place_type: String = ""

## Translucent placement ghost (lazily built; null until the first preview).
var _preview: MeshInstance3D = null

## Manual player-position override used when player_slice is null (tests).
var _player_position_override: Vector3 = Vector3.ZERO

func set_player_position(pos: Vector3) -> void:
	_player_position_override = pos

## Distinct non-empty `station` values across GameData.RECIPES AND item repair
## specs (GameData.ITEMS[*].repair), sorted. Both are the fabric's authoritative
## sources of station types: a recipe or a repair spec can name a station that
## the other never uses, and every named station must be placeable.
func placeable_station_types() -> Array:
	if _placeable_types_cache.is_empty():
		_placeable_types_cache = _compute_placeable_station_types()
	return _placeable_types_cache

## Cached result of `_compute_placeable_station_types` (fabric data is static, and
## the placement preview asks every frame). Empty means not computed yet.
var _placeable_types_cache: Array = []
## How many times the fabric scan ran (a counter for tests: the preview must not trigger one).
var placeable_scan_count: int = 0

func _compute_placeable_station_types() -> Array:
	placeable_scan_count += 1
	var types := {}
	for key in GameData.RECIPES:
		var res: Resource = GameData.RECIPES[key]
		if res == null:
			continue
		var recipe = res.get("recipe")
		if recipe is Dictionary:
			var station: String = str(recipe.get("station", ""))
			if station != "":
				types[station] = true
	for key in GameData.ITEMS:
		var res2: Resource = GameData.ITEMS[key]
		if res2 == null:
			continue
		var repair = res2.get("repair")
		if repair is Dictionary:
			var station: String = str(repair.get("station", ""))
			if station != "":
				types[station] = true
	# Phase 125 — the waystone is placeable although no recipe or repair names it as a station.
	var way: Resource = GameData.WORLD_SYSTEMS.get("WaystoneTravel", null)
	if way != null and way.get("rules") is Dictionary and str(way.get("rules").get("stationType", "")) != "":
		types[str(way.get("rules")["stationType"])] = true
	# Phase 140 — so is the settlement hearth (founding a settlement).
	var settle: Resource = GameData.WORLD_SYSTEMS.get("Settlement", null)
	if settle != null and settle.get("rules") is Dictionary and str(settle.get("rules").get("hearthStation", "")) != "":
		types[str(settle.get("rules")["hearthStation"])] = true
	# Phase 184 — and the bed (BedSpawn.stationType); Phase 185 makes it the owner's spawn point.
	var bed_type := str(_bed_rules().get("stationType", ""))
	if bed_type != "":
		types[bed_type] = true
	var out: Array = types.keys()
	out.sort()
	return out

## The fabric bed rule (`GameData.WORLD_SYSTEMS["BedSpawn"].rules`), or {} with no fabric.
static func _bed_rules() -> Dictionary:
	var res: Resource = GameData.WORLD_SYSTEMS.get("BedSpawn", null)
	if res == null or not (res.get("rules") is Dictionary):
		return {}
	return res.get("rules")

## The currently selected station type for placement, lazily initialised to the
## first fabric-derived type. Returns "" when no station type exists.
func get_place_station_type() -> String:
	if _place_type == "":
		var types := placeable_station_types()
		if not types.is_empty():
			_place_type = str(types[0])
	return _place_type

## Advance the placement selection to the next fabric-derived station type.
func cycle_station_type() -> String:
	var types := placeable_station_types()
	if types.is_empty():
		_place_type = ""
	else:
		var idx: int = types.find(_place_type)
		idx = (idx + 1) % types.size()
		_place_type = str(types[idx])
	return _place_type

## Place a station of `type` at `position`; returns its unique id.
func place_station(type: String, position: Vector3) -> String:
	var id := "station_%d" % _next_id
	_next_id += 1
	_insert_station(id, type, position)
	GameBus.station_placed.emit(id, type, position)
	return id

## Minimum centre-to-centre distance between two stations (the marker is 1 m wide,
## so anything closer would interpenetrate).
const MIN_STATION_SPACING: float = 1.0

## Snap a world position to the 1 m placement grid on x/z (cell centres); y is kept.
func snap_to_grid(position: Vector3) -> Vector3:
	return Vector3(floorf(position.x) + 0.5, position.y, floorf(position.z) + 0.5)

## "" when a station of `type` may be placed at `position`, otherwise a reason
## code (`reason.<code>` in the catalog, rendered by `I18n.reason_text`). Fails closed on an empty/unknown type and on overlap with any placed
## station. Used by try_place_station and by the placement preview.
func placement_blocker(type: String, position: Vector3, player_id: String = "") -> String:
	if type == "" or not placeable_station_types().has(type):
		return "unknown_station_type"
	# Phase 140 — a station inside someone else's claim, or a hearth too close to another settlement.
	if claim_guard.is_valid() and str(claim_guard.call(player_id, Vector2(position.x, position.z))) != "":
		return "inside_claim"
	if settlement_slice != null and type == str(settlement_slice.rules()["hearthStation"]) \
			and settlement_slice.founding_blocker(Vector2(position.x, position.z)) != "":
		return "too_close_settlement"
	if settlement_slice != null and type == str(settlement_slice.rules()["hearthStation"]) \
			and settlement_slice.settlement_of(player_id) != "":
		return "already_in_settlement"
	for id in _stations:
		var other: Vector3 = _stations[id]["position"]
		# Compare on the x/z plane: the same cell at another height still collides.
		if Vector2(other.x - position.x, other.z - position.z).length() < MIN_STATION_SPACING:
			return "too_close_station:%s" % id
	return ""

## Validated placement: snaps to the grid, refuses on overlap. Returns the new
## station id, or "" when refused (see placement_blocker).
func try_place_station(type: String, position: Vector3, inventory: Node = null, player_id: String = "") -> String:
	var pos := snap_to_grid(position)
	if placement_blocker(type, pos, player_id) != "":
		return ""
	# Phase 130 — a type whose fabric rule names a placement item consumes one from the placer; with no
	# inventory to pay from (or none in it) the placement is refused.
	var item := placement_item(type)
	if item != "":
		if inventory == null or not inventory.has_method("consume_items") or not inventory.consume_items({ item: 1 }):
			return ""
	return place_station(type, pos)

## The item one placement of a `type` station consumes, or "" for a free placement (the fabric's
## `WaystoneTravel.placementItem` for the waystone type, `BedSpawn.placementItem` for the bed; forges and
## benches stay free).
func placement_item(type: String) -> String:
	if settlement_slice != null and type == str(settlement_slice.rules()["hearthStation"]):
		return str(settlement_slice.rules()["hearthItem"])
	var bed := _bed_rules()
	if not bed.is_empty() and type == str(bed.get("stationType", "")):
		return str(bed.get("placementItem", ""))
	var res: Resource = GameData.WORLD_SYSTEMS.get("WaystoneTravel", null)
	if res == null or not (res.get("rules") is Dictionary):
		return ""
	var rules: Dictionary = res.get("rules")
	if str(rules.get("stationType", "")) != type:
		return ""
	return str(rules.get("placementItem", ""))

## The next station id number; saved with the world so a removed trailing id is never reused.
func next_id() -> int:
	return _next_id

## Raise the allocator to a saved `n` (never lowers it, never accepts a negative or absurd value).
func restore_next_id(n: int) -> void:
	if n > 0 and n < 1 << 40:
		_next_id = maxi(_next_id, n)

## Show (or move) the translucent placement ghost at the snapped `position`;
## green when placeable, red when blocked. No-op without a rendering context.
func show_preview(type: String, position: Vector3) -> void:
	var pos := snap_to_grid(position)
	var ok := placement_blocker(type, pos) == ""
	if _preview == null:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.0, 1.0, 1.0)
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_preview = MeshInstance3D.new()
		_preview.mesh = mesh
		_preview.material_override = mat
		_preview.name = "StationPreview"
		add_child(_preview)
	_preview.position = pos + _origin.value
	_preview.visible = true
	(_preview.material_override as StandardMaterial3D).albedo_color = \
		Color(0.2, 0.9, 0.3, 0.4) if ok else Color(0.95, 0.2, 0.2, 0.4)

func hide_preview() -> void:
	if _preview != null:
		_preview.visible = false

func is_preview_visible() -> bool:
	return _preview != null and _preview.visible

## Insert a station under a KNOWN id and keep the allocator above it. Used by
## apply_station_data so a restored station keeps its saved id rather than being
## renumbered by load order.
func _insert_station(id: String, type: String, position: Vector3) -> void:
	_stations[id] = { "id": id, "type": type, "position": position }
	var suffix := id.trim_prefix("station_")
	if suffix.is_valid_int():
		_next_id = maxi(_next_id, int(suffix) + 1)
	_add_marker(id, type, position)

# ---------------------------------------------------------------------------
# Phase 33 — world-record serialization
# ---------------------------------------------------------------------------

## Every placed station as a serializable list of
## { id, type, position:[x,y,z] }, ordered by id so the payload is stable.
func get_station_data() -> Array:
	var out: Array = []
	for id in _stations:
		var s: Dictionary = _stations[id]
		var pos: Vector3 = s["position"]
		out.append({
			"id":       str(s["id"]),
			"type":     str(s["type"]),
			"position": WorldPos.to_wire(pos),
		})
	out.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))
	return out

## Replace the placed set from a saved payload. The current stations (and their
## markers) are dropped first, so a load is authoritative rather than additive.
## Entries without a usable type or position are skipped, and each restored
## station keeps its saved id.
func apply_station_data(data: Array) -> void:
	for id in _stations.keys():
		_drop_station(str(id))
	for entry in data:
		if not entry is Dictionary:
			continue
		var stype := str(entry.get("type", ""))
		var arr = entry.get("position", [])
		if stype.is_empty() or not WorldPos.is_wire(arr):
			continue
		var pos := WorldPos.from_wire(arr)
		var id := str(entry.get("id", ""))
		if id.is_empty():
			id = "station_%d" % _next_id
			_next_id += 1
		_insert_station(id, stype, pos)

func remove_station(station_id: String) -> void:
	var existed := _stations.has(station_id)
	_drop_station(station_id)
	if existed:
		GameBus.station_removed.emit(station_id)

## Drop a station and its marker without telling anyone (a world reload replaces the whole set).
func _drop_station(station_id: String) -> void:
	if _markers.has(station_id):
		var m: Node = _markers[station_id]
		if is_instance_valid(m):
			m.queue_free()
		_markers.erase(station_id)
	_stations.erase(station_id)

func get_station(station_id: String) -> Dictionary:
	return _stations.get(station_id, {})

func get_all_stations() -> Array:
	return _stations.values()

## Return the id of the nearest station of exactly `type` within `radius` of
## `pos`, or "" when none match.
func nearest_station(pos: Vector3, type: String, radius: float) -> String:
	var best := ""
	var best_dist := radius
	for id in _stations:
		var s: Dictionary = _stations[id]
		if str(s["type"]) != type:
			continue
		var sp: Vector3 = s["position"]
		var d: float = sp.distance_to(pos)
		if d <= best_dist:
			best_dist = d
			best = str(id)
	return best

## Whether a station of `type` is within `radius` of the player.
func station_near_player(type: String, radius: float) -> bool:
	return nearest_station(_player_position(), type, radius) != ""

func _player_position() -> Vector3:
	if player_slice != null and player_slice.has_method("get_position"):
		return player_slice.get_position()
	return _player_position_override

## Spawn a small coloured box marker so a placed station is visible in-world.
## The colour is derived deterministically from the type string, so every
## station type gets a stable, distinct tint with no hardcoded palette.
func _add_marker(id: String, type: String, position: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 1.0, 1.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _station_color(type)
	mat.roughness = 0.5
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = position + _origin.value
	inst.name = "Station_%s" % id
	add_child(inst)
	_markers[id] = inst

func _station_color(type: String) -> Color:
	var hue := fmod(float(absi(hash(type))), 360.0) / 360.0
	return Color.from_hsv(hue, 0.65, 0.85)
