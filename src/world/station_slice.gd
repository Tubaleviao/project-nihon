extends Node
## Station slice — tracks placed crafting stations as world entities.
##
## Stations gate recipes whose `station` field names a required structure
## (forge, alchemy bench, carpentry bench, arcane forge, …). A recipe's
## `station` string must match a placed station's type exactly — a "master
## forge" is a distinct, higher-tier structure from a plain "forge".
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

## Canonical station types from fabric recipe `station` fields. The slice is
## type-agnostic (any string can be placed), but these document the known set.
const STATION_TYPES: Array = [
	"forge",
	"master forge",
	"arcane forge",
	"alchemy bench",
	"carpentry bench",
	"masonry bench",
	"void-shielded workshop",
]

## Set by game_root so station_near_player can resolve the player's position.
var player_slice: Node = null

## Placed stations keyed by station id.
var _stations: Dictionary = {}
var _next_id: int = 0

## Manual player-position override used when player_slice is null (tests).
var _player_position_override: Vector3 = Vector3.ZERO

func set_player_position(pos: Vector3) -> void:
	_player_position_override = pos

## Place a station of `type` at `position`; returns its unique id.
func place_station(type: String, position: Vector3) -> String:
	var id := "station_%d" % _next_id
	_next_id += 1
	_stations[id] = { "id": id, "type": type, "position": position }
	GameBus.station_placed.emit(id, type, position)
	return id

func remove_station(station_id: String) -> void:
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
