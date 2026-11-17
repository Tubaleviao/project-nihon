extends "res://src/core/wiring.gd"
## Station wiring (Phase 268) — a station item placed from the hotbar and a placed station picked up again.
##
## Every placement and pick-up is a `station_intent` the host decides: the host's own player emits it here, a
## client's travels to the host (net_part_2 binds the sender), and the result is a `station_resolved` the host turns
## into a notice. A chest or door goes on through `ChestWiring.place_for`, a bed through the bed's own intent, and
## every other type is paid for here. The host then tells every client about the station (`station_added`,
## `station_gone`), so a placement shows on the other machines without waiting for a snapshot.
##
##   IN  : station_intent(action, args, player_id)    "place" {item, ox, oy, oz, rot}, "pick_up" {id}
##   OUT : station_resolved(player_id, action, ok, reason)

const StationRules := preload("res://src/world/station_rules.gd")
const ChestRules := preload("res://src/world/chest_rules.gd")
const ChestWiringScript := preload("res://src/world/chest_wiring.gd")
const WorldPos := preload("res://src/terrain/world_pos.gd")

## Placed stations one player may own at once, and in all: a client cannot grow the station list (and the O(n)
## blocker scan) without bound, even with the items to pay.
const MAX_STATIONS_PER_PLAYER := 64
const MAX_STATIONS := 4096
## Seconds between two pick-ups of one player.
const PICK_GAP_SEC := 0.25
## The reasons a notice exists for (`placing.refused.<reason>`); anything else is shown as `blocked`.
const REASONS := ["bad_args", "no_item", "far", "blocked", "cap", "not_owner", "no_station", "full"]

var _last_place: Dictionary = {}
var _last_pick: Dictionary = {}
## Host: true while a bed placement is resolving, whose own notice (`bed_resolved`) tells the player.
var _quiet: bool = false
## Host: `(pid) -> Vector3 or null`, where the host knows a player stands (default: ChestWiring.player_pos).
var position_of: Callable = Callable()

func _pos(pid: String) -> Variant:
	if position_of.is_valid():
		return position_of.call(pid)
	return root._chest_wiring.player_pos(pid)

## After every slice exists: the player's ghost judges a placement as the host judges this player.
func attach() -> void:
	if root._player != null and root._registry != null:
		root._player.local_player_id = str(root._registry.local_player_id)

func _connect_all() -> void:
	connect_bus(GameBus.station_intent, _on_intent)
	connect_bus(GameBus.station_resolved, _on_resolved)
	connect_bus(GameBus.station_placed, _on_station_placed)
	connect_bus(GameBus.station_removed, _on_station_removed)
	connect_bus(GameBus.station_synced, _on_station_synced)

# --- intents ---------------------------------------------------------------------------------------------

## A client forwards its own intent (the host binds who sent it); the host resolves its own player's and a peer's.
func _on_intent(action: String, args: Dictionary, player_id: String) -> void:
	if root._is_client:
		if player_id == "" and root._networking != null:
			root._networking._broadcast({ "type": "station_intent", "action": action.left(16), "args": args })
		return
	var pid := player_id if player_id != "" else str(root._registry.local_player_id)
	_quiet = false
	var why := resolve(action, args, pid)
	GameBus.station_resolved.emit(pid, action, why == "", why)

## The host's answer to one intent: "" when it was done, else a reason (REASONS).
func resolve(action: String, args: Dictionary, pid: String) -> String:
	if pid == "":
		return "bad_args"
	match action:
		"place":
			var off := Vector3.ZERO
			for i in 3:
				var v: Variant = args.get(["ox", "oy", "oz"][i], null)
				if not ((v is float or v is int) and is_finite(float(v))):
					return "bad_args"
				off[i] = float(v)
			return place_for(pid, str(args.get("item", "")).left(64), off, StationRules.clean_rotation(args.get("rot", 0)))
		"pick_up":
			return pick_up(pid, str(args.get("id", "")).left(32))
	return "bad_args"

## Host: place the station `item_id` places for `pid`, at `offset` from where the host knows them to stand,
## turned `rot` quarter turns. One item is consumed; without it the placement is refused.
func place_for(pid: String, item_id: String, offset: Vector3, rot: int) -> String:
	var type := StationRules.type_for_item(item_id)
	if type == "" or not offset.is_finite():
		return "bad_args"
	var inv: Node = root._registry.get_inventory(pid)
	if inv == null or int(inv.get_item_count(item_id)) < 1:
		return "no_item"
	if owned_count(pid) >= MAX_STATIONS_PER_PLAYER or root._station.get_all_stations().size() >= MAX_STATIONS:
		return "cap"
	var st: Node = root._station
	st.placing_owner = pid
	st.placing_rotation = rot
	var why := ""
	if root._bed != null and type == root._bed.station_type():
		_quiet = true   # the bed tells its own placer (`bed_resolved`)
		var before: int = st.next_id()
		GameBus.bed_place_intent.emit(offset, pid)
		why = "" if st.next_id() > before else "blocked"
	elif ChestRules.is_lock_type(type):
		why = _chest_reason(str(root._chest_wiring.place_for(pid, type, offset)))
	else:
		why = _place_paid(pid, type, item_id, offset, inv)
	st.placing_owner = ""
	st.placing_rotation = 0
	if why == "":
		_push_inventory(pid)
	return why

## A chest or door refusal (ChestWiring's codes) in this wiring's reasons.
static func _chest_reason(code: String) -> String:
	match code:
		"", "far", "bad_args", "cap":
			return code
		"rate":
			return "rate"
		"no_stock":
			return "no_item"
	return "blocked"

## Host: any station type that is not a chest, a door or a bed: the rate, reach and blocker checks, then one
## item paid and the station placed.
func _place_paid(pid: String, type: String, item_id: String, offset: Vector3, inv: Node) -> String:
	var here: Variant = _pos(pid)
	var why := ChestWiringScript.placement_check(_last_place, pid, offset, here, Time.get_ticks_msec() / 1000.0)
	if why != "":
		return why
	var target: Vector3 = root._station.snap_to_grid((here as Vector3) + offset)
	var refusal: String = root._station.place_refusal(type, target, inv, pid)
	if refusal != "":
		return "no_item" if refusal.begins_with("no_placement_item") else "blocked"
	if not inv.consume_items({ item_id: 1 }):
		return "no_item"
	if root._station.place_station(type, target) == "":
		inv.add_item(item_id, 1)
		return "blocked"
	return ""

## How many placed stations `pid` owns.
func owned_count(pid: String) -> int:
	var n := 0
	for s: Dictionary in root._station.get_all_stations():
		if str(s.get("owner", "")) == pid:
			n += 1
	return n

## Why `pid`, standing at `here` (null when unknown), may not pick up the station `st`: "" when they may.
static func pickup_refusal(st: Dictionary, pid: String, here: Variant, reach: float) -> String:
	if st.is_empty():
		return "no_station"
	var owner := str(st.get("owner", ""))
	if owner == "" or owner != pid:
		return "not_owner"
	if not (here is Vector3) or (here as Vector3).distance_to(st["position"]) > reach:
		return "far"
	return ""

## Host: the owner of `station_id`, within reach, takes it down and gets its item back. A chest spills what it
## holds (ChestsAndDoors' `spillsOnDestroy`: `station_removed` -> `ChestSlice.forget`).
func pick_up(pid: String, station_id: String) -> String:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_pick.get(pid, -1.0e12)) < PICK_GAP_SEC:
		return "rate"
	_last_pick[pid] = now
	if _last_pick.size() > 4096:
		_last_pick.clear()
	var st: Dictionary = root._station.get_station(station_id)
	var why := pickup_refusal(st, pid, _pos(pid), StationRules.pickup_reach())
	if why != "":
		return why
	var item: String = root._station.placement_item(str(st["type"]))
	var inv: Node = root._registry.get_inventory(pid)
	if item == "" or inv == null:
		return "bad_args"
	if not inv.can_add_items({ item: 1 }):
		return "full"
	root._station.remove_station(station_id)
	inv.add_item(item, 1)
	_push_inventory(pid)
	return ""

func _push_inventory(pid: String) -> void:
	if pid == "" or pid == str(root._registry.local_player_id):
		return
	var inv: Node = root._registry.get_inventory(pid)
	if inv != null and inv.has_method("get_contents"):
		GameBus.inventory_synced.emit(pid, inv.get_contents(), inv.get_durability_data())

## Host: the notice for a result (none for a rate refusal or a bed, which tells its own placer), and the placer's
## machine is told which station it placed (its tutorial counts it).
func _on_resolved(player_id: String, action: String, ok: bool, reason: String) -> void:
	if root._is_client or player_id == "":
		return
	if not (_quiet and action == "place") and reason != "rate":
		var key := "placing.ok.%s" % action if ok else "placing.refused.%s" % (reason if REASONS.has(reason) else "blocked")
		GameBus.system_message.emit(key, [], player_id)
	_quiet = false

# --- the stations on every machine -----------------------------------------------------------------------

## Host: a station stood up: every client gets it (without its owner: a client sees public handles only), and
## a remote placer's machine is told it was theirs.
func _on_station_placed(station_id: String, type: String, _position: Vector3) -> void:
	if root._is_client:
		return
	var owner := str(root._station.get_station(station_id).get("owner", ""))
	if owner != "" and owner == str(root._registry.local_player_id):
		GameBus.station_placed_by_me.emit(station_id, type)
	if root._networking == null or not root._networking.has_method("_broadcast"):
		return
	var entry: Dictionary = root._station.station_entry(station_id, false)
	if entry.is_empty():
		return
	root._networking._broadcast({ "type": "station_added", "station": entry })
	if owner != "" and owner != str(root._registry.local_player_id):
		var peer: int = root._registry.get_peer_id(owner)
		if peer != 0:
			root._networking.send_own_state(peer, { "station_placed": station_id })

func _on_station_removed(station_id: String) -> void:
	if root._is_client or root._networking == null or not root._networking.has_method("_broadcast"):
		return
	root._networking._broadcast({ "type": "station_gone", "id": station_id })

## Client: the host added (`entry` is a station's wire entry) or removed (`entry` is `{id}`) a station.
func _on_station_synced(action: String, entry: Dictionary) -> void:
	if not root._is_client:
		return
	if action == "add":
		root._station.apply_station_entry(entry)
	elif action == "remove":
		root._station.drop_synced(str(entry.get("id", "")).left(32))

## Client: the host's view of this player says it placed `station_placed`: the local tutorial hears of it.
func apply_own_view(data: Dictionary) -> void:
	var id := str(data.get("station_placed", "")).left(32)
	if id == "" or not root._is_client:
		return
	var st: Dictionary = root._station.get_station(id)
	if not st.is_empty():
		GameBus.station_placed_by_me.emit(id, str(st["type"]))
