extends Node
## Writing slice (Phase 209) — research shared by writing. A player who knows a technology writes a book about it,
## and one who knows a station recipe or a settlement project draws a blueprint of it, at the writing's station
## for its material cost (`WritingRules`). Reading a book or blueprint in the pack teaches the reader
## (`TechnologySlice.learn`) and keeps it, so it can be read again, lent, traded or left in a chest. Nothing is
## shared through a clan.
##
## The host decides everything. Who acts is the intent's bound player; the station is found from the host's own
## view of where that player stands.
##
## Plug contract (GameBus):
##   IN  : writing_intent(action, item_id, player_id)
##   OUT : writing_resolved(player_id, action, item_id, ok, reason)

const WritingRules := preload("res://src/technology/writing_rules.gd")

## Refusal codes; each has a `writing.refused.<code>` key in locale/ui.csv.
const REASONS := ["unknown_writing", "not_known", "station_required", "missing_materials", "pack_full", "not_held",
	"already_known", "prerequisite_locked", "rate"]
## Metres from the player a writing's station must stand (CraftingSlice.STATION_RADIUS).
const STATION_RADIUS := 8.0
## Milliseconds between one player's writing intents on the host.
const GAP_MS := 250

var is_host: bool = true
var technology: Node = null
## (player_id) -> the player's inventory node, or null.
var inventory_for: Callable
## (player_id) -> the player's scene position (Vector3), or null.
var position_of: Callable
## (pos, type, radius) -> the nearest station id of `type`, or "".
var nearest_station: Callable
var now_ms: Callable = func() -> int: return Time.get_ticks_msec()

var _last_ms: Dictionary = {}

func _ready() -> void:
	GameBus.writing_intent.connect(_on_intent)

func _on_intent(action: String, item_id: String, player_id: String) -> void:
	if not is_host:
		return
	resolve(action, item_id, player_id)

## Resolve one intent and announce it. Returns "" on success, else a REASONS code.
func resolve(action: String, item_id: String, player_id: String) -> String:
	if technology != null:
		player_id = str(technology.resolve_player(player_id))
	var why := "unknown_writing"
	var now := int(now_ms.call())
	if _last_ms.has(player_id) and now - int(_last_ms[player_id]) < GAP_MS:
		why = "rate"
	else:
		_last_ms[player_id] = now
		match action:
			"write":
				why = write(player_id, item_id)
			"read":
				why = read(player_id, item_id)
	GameBus.writing_resolved.emit(player_id, action, item_id, why == "", why)
	return why

## Write one `item_id` for `player_id`: refused unless they know what it teaches, stand at its station and carry
## its cost, and their pack has room for it.
func write(player_id: String, item_id: String) -> String:
	var w := WritingRules.of(item_id)
	if w.is_empty() or technology == null:
		return "unknown_writing"
	if not bool(technology.knows(str(w["kind"]), str(w["teaches"]), player_id)):
		return "not_known"
	var station := WritingRules.station(str(w["writing"]))
	if station != "" and not _near_station(player_id, station):
		return "station_required"
	var inv: Node = inventory_for.call(player_id) if inventory_for.is_valid() else null
	if inv == null:
		return "missing_materials"
	var cost := WritingRules.cost(str(w["writing"]))
	for item: String in cost:
		if int(inv.get_item_count(item)) < int(cost[item]):
			return "missing_materials"
	if not inv.consume_items(cost):
		return "missing_materials"
	if not inv.add_item(item_id, 1):
		# Give the cost back: the pack had room for it a moment ago.
		for item: String in cost:
			inv.add_item(item, int(cost[item]))
		return "pack_full"
	return ""

## Read `item_id` from `player_id`'s pack: they learn what it teaches, and it stays in the pack.
func read(player_id: String, item_id: String) -> String:
	var w := WritingRules.of(item_id)
	if w.is_empty() or technology == null:
		return "unknown_writing"
	var inv: Node = inventory_for.call(player_id) if inventory_for.is_valid() else null
	if inv == null or int(inv.get_item_count(item_id)) < 1:
		return "not_held"
	var why := str(technology.learn(str(w["kind"]), str(w["teaches"]), player_id))
	if why.begins_with("prerequisite_locked"):
		return "prerequisite_locked"
	return "unknown_writing" if why == "unknown" else why

func _near_station(player_id: String, type: String) -> bool:
	var here: Variant = position_of.call(player_id) if position_of.is_valid() else null
	if not (here is Vector3) or not nearest_station.is_valid():
		return false
	return str(nearest_station.call(here, type, STATION_RADIUS)) != ""
