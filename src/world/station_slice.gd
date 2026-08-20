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
##   place_station(type, position)      -> String    (station id)
##   remove_station(station_id)
##   get_station(station_id)            -> Dictionary
##   get_all_stations()                 -> Array
##   nearest_station(pos, type, radius) -> String    ("" if none in radius)
##   station_near_player(type, radius)  -> bool
##   placeable_station_types()          -> Array     (fabric-derived, sorted)
##   get_place_station_type()           -> String    (current placement selection)
##   cycle_station_type()               -> String    (advance the selection)

## Set by game_root so station_near_player can resolve the player's position.
var player_slice: Node = null

## Placed stations keyed by station id.
var _stations: Dictionary = {}
var _next_id: int = 0

## Visual markers keyed by station id (MeshInstance3D).
var _markers: Dictionary = {}

## Currently selected station type for placement (cycled via cycle_station_type).
var _place_type: String = ""

## Manual player-position override used when player_slice is null (tests).
var _player_position_override: Vector3 = Vector3.ZERO

func set_player_position(pos: Vector3) -> void:
	_player_position_override = pos

## Distinct non-empty `station` values across GameData.RECIPES, sorted. This is
## the fabric's authoritative list of placeable station types.
func placeable_station_types() -> Array:
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
	var out: Array = types.keys()
	out.sort()
	return out

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
	_stations[id] = { "id": id, "type": type, "position": position }
	_add_marker(id, type, position)
	GameBus.station_placed.emit(id, type, position)
	return id

func remove_station(station_id: String) -> void:
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
	inst.position = position
	inst.name = "Station_%s" % id
	add_child(inst)
	_markers[id] = inst

func _station_color(type: String) -> Color:
	var hue := fmod(float(absi(hash(type))), 360.0) / 360.0
	return Color.from_hsv(hue, 0.65, 0.85)
