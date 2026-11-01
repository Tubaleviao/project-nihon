extends "res://src/core/wiring.gd"
## Chest wiring (Phase 208) — chests and doors: binds a placed chest or door station to its placer, places one
## for a client, ticks lock picks, tells each actor how their intent went, pushes the open chest's view to its
## player (the host's own window reads the slice), saves and loads them, and turns a migrated settlement's
## stockpile into clan chests (`Clan.migration.stockpile`). `ChestSlice` holds the host's rules.
##
## A door's station blocks the player's body (`StationSlice.blocking_types`). When the host lets a player pass
## (`use`), that player's machine opens the door's collision for DOOR_OPEN_SEC and shuts it once they are clear.
## Like every wall, the collision is the client's: the host decides who may pass, the body enforces it.

const ChestSlice := preload("res://src/world/chest_slice.gd")
const ChestRules := preload("res://src/world/chest_rules.gd")
const StationSlice := preload("res://src/world/station_slice.gd")
const WorldPos := preload("res://src/terrain/world_pos.gd")
const I18n := preload("res://src/core/i18n.gd")

## Metres from the placer a client may put a chest or door (the station reach of a bed).
const PLACE_REACH := 6.0
const PLACE_GAP_SEC := 0.5
## Seconds a door stays open on the machine of the player it let through, and the metres they must then be
## from it before it shuts (never on top of them).
const DOOR_OPEN_SEC := 3.0
const DOOR_CLEAR_M := 1.5

## Host: the player a `station_placed` of a chest or door belongs to while one is placed for a client.
var _placing_for: String = ""
var _migrating: bool = false
var _last_place: Dictionary = {}
## Host: pid -> the view last sent to that peer (sent again only when it changes).
var _sent: Dictionary = {}
## Client: the host's last view of what this player has open.
var _view: Dictionary = {}
## This machine: door station id -> seconds it stays open for this machine's player.
var _doors_open: Dictionary = {}

func make_slice(ctx: GameRoot) -> Node:
	root = ctx
	var slice := ChestSlice.new()
	slice.registry = root._registry
	slice.clans = root._clans
	slice.structures = root._structures
	slice.is_host = not root._is_client
	slice.position_of = self.player_pos
	slice.build_mode_of = func(pid: String) -> String: return str(root._structures.build_mode(pid)) if root._structures != null else "private"
	slice.tech_known = func(pid: String, tech: String) -> bool: return root._technology != null and bool(root._technology.is_unlocked(tech, pid))
	slice.spill = func(item: String, qty: int, pos: Vector3) -> void: root._loot.spawn_pickup(item, qty, pos)
	slice.remove_station = root._station.remove_station
	slice.place_for = self.place_for
	for t: String in ChestRules.station_types():
		if not ChestRules.holds_items(t):
			root._station.blocking_types.append(t)
	return slice

## After every slice exists: a client's chest or door placement goes to the host.
func attach() -> void:
	if root._is_client:
		var before: Callable = root._station.remote_placer
		root._station.remote_placer = func(type: String, target: Vector3) -> bool:
			return _place_remote(type, target) or (before.is_valid() and bool(before.call(type, target)))

func _connect_all() -> void:
	connect_bus(GameBus.station_placed, _on_station_placed)
	connect_bus(GameBus.station_removed, _on_station_removed)
	connect_bus(GameBus.chest_resolved, _on_resolved)
	connect_bus(GameBus.lock_pick_started, _on_pick_started)
	connect_bus(GameBus.lock_pick_resolved, _on_pick_resolved)
	connect_bus(GameBus.clan_disbanded, _on_clan_disbanded)

## The float world position of `player_id` (the host's own player, or a peer's last report), or null.
func player_pos(player_id: String) -> Variant:
	var here: Dictionary = root._waystone_wiring._waystone_player_pos(player_id)
	if here.is_empty():
		return null
	return WorldPos.to_scene(here, Vector2i.ZERO)

# --- placement -------------------------------------------------------------------------------------------

## Client: a chest or door goes to the host as a `place` intent; false lets other types go their own way.
func _place_remote(type: String, target: Vector3) -> bool:
	if not ChestRules.is_lock_type(type) or root._player == null:
		return false
	var off := target - root._player.get_position()
	GameBus.chest_intent.emit("place", { "type": type, "ox": off.x, "oy": off.y, "oz": off.z }, "")
	return true

## Host: place a chest or door of `type` at `offset` from `pid` for them. "" when placed, else a REASONS code.
func place_for(pid: String, type: String, offset: Vector3) -> String:
	if not ChestRules.is_lock_type(type) or not offset.is_finite():
		return "bad_args"
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_place.get(pid, -1.0e12)) < PLACE_GAP_SEC:
		return "rate"
	_last_place[pid] = now
	if offset.length() > PLACE_REACH:
		return "far"
	var here: Variant = player_pos(pid)
	if not (here is Vector3):
		return "far"
	var inv: Node = root._registry.get_inventory(pid)
	var item := ChestRules.placement_item(type)
	if inv == null or int(inv.get_item_count(item)) < 1:
		return "no_stock"
	var target: Vector3 = root._station.snap_to_grid((here as Vector3) + offset)
	if root._station.placement_blocker(type, target, pid) != "":
		return "blocked"
	if not inv.consume_items({ item: 1 }):
		return "no_stock"
	_placing_for = pid
	var id: String = root._station.place_station(type, target)
	_placing_for = ""
	if id == "" or not root._chests.has_lock(id):
		if id != "":
			root._station.remove_station(id)   # a refused chest or door never stays in the world unowned
		inv.add_item(item, 1)
		return "blocked"
	_push_inventory(pid)
	return ""

## Host: a chest or door station was placed, for a client (`place_for`) or by the host's own player.
func _on_station_placed(station_id: String, type: String, position: Vector3) -> void:
	if root._is_client or root._chests == null or _migrating or not ChestRules.is_lock_type(type):
		return
	var pid := _placing_for if _placing_for != "" else str(root._registry.local_player_id)
	if root._chests.register(station_id, type, position, pid) or _placing_for != "":
		return   # a refusal for a client is undone by `place_for`
	# The host's own placement (`try_place_station` already took the item): undo it and give the item back.
	root._station.remove_station(station_id)
	var inv: Node = root._registry.get_inventory(pid)
	if inv != null:
		inv.add_item(ChestRules.placement_item(type), 1)
	GameBus.system_message.emit("chest.refused.blocked", [], pid)

func _on_station_removed(station_id: String) -> void:
	if not root._is_client and root._chests != null:
		root._chests.forget(station_id)

## `/regen world` stood every station back on the new ground: each chest and door follows its station.
func world_regenerated() -> void:
	if root._chests != null:
		root._chests.world_moved(func(id: String) -> Variant:
			var st: Dictionary = root._station.get_station(id)
			return st["position"] if not st.is_empty() else null)

## Host: a disbanded clan's chests and doors go to its last member.
func _on_clan_disbanded(clan_id: String, heir: String) -> void:
	if not root._is_client and root._chests != null:
		root._chests.clan_disbanded(clan_id, heir)

# --- results and views -----------------------------------------------------------------------------------

func _on_resolved(player_id: String, action: String, ok: bool, reason: String) -> void:
	if root._is_client or player_id == "":
		return
	var key := ""
	if not ok and reason != "rate" and action != "close":
		key = "chest.refused." + reason
	elif ok and (action == "use" or action == "mode" or action == "place"):
		var open: bool = root._chests.open_of(player_id) != ""
		key = "chest.ok.%s" % action if action != "use" else ("chest.ok.open" if open else "chest.ok.pass")
	if key != "":
		GameBus.system_message.emit(key, [], player_id)
	if ok and action == "use":
		_let_through(player_id)
	push_view(player_id, ok and action == "use")

## Host: `player_id` was let through the door they used: open it on their machine.
func _let_through(player_id: String) -> void:
	var here: Variant = player_pos(player_id)
	var id: String = root._chests.nearest(here) if here is Vector3 else ""
	if id == "" or ChestRules.holds_items(str(root._chests.get_lock(id).get("type", ""))):
		return
	if player_id == str(root._registry.local_player_id):
		open_door_here(id)
		return
	var peer: int = root._registry.get_peer_id(player_id)
	if peer != 0:
		root._networking.send_own_state(peer, { "door_open": id })

## This machine: open the door `id` for its own player for DOOR_OPEN_SEC.
func open_door_here(id: String) -> void:
	if root._station.get_station(id).is_empty() or not root._station.blocking_types.has(str(root._station.get_station(id)["type"])):
		return
	if not _doors_open.has(id) and _doors_open.size() >= 64:
		return
	root._station.set_passable(id, true)
	_doors_open[id] = DOOR_OPEN_SEC

## This machine: shut each open door whose time is up once its player is clear of it.
func _tick_doors(delta: float) -> void:
	for id: String in _doors_open.keys():
		_doors_open[id] = float(_doors_open[id]) - delta
		var st: Dictionary = root._station.get_station(id)
		if st.is_empty():
			_doors_open.erase(id)
			continue
		if float(_doors_open[id]) > 0.0:
			continue
		var at: Vector3 = (st["position"] as Vector3) + root._station.scene_offset()
		if root._player != null and root._player.get_position().distance_to(at) < DOOR_CLEAR_M:
			continue
		root._station.set_passable(id, false)
		_doors_open.erase(id)

## How long a pick takes, to the picker.
func _on_pick_started(player_id: String, _station_id: String, seconds: float) -> void:
	if not root._is_client:
		GameBus.system_message.emit("lock.pick_started", [snappedf(seconds, 0.1)], player_id)

func _on_pick_resolved(player_id: String, _station_id: String, reason: String, broke: bool) -> void:
	if root._is_client:
		return
	var key := "lock.pick_opened" if reason == "" else ("lock.pick_broke" if broke else "lock.pick_lost")
	GameBus.system_message.emit(key, [], player_id)
	if broke:
		_push_inventory(player_id)

## Host: send `player_id` what they have open (a peer by own-state; the host's own window reads the slice),
## when it changed or `open_window`.
func push_view(player_id: String, open_window: bool = false) -> void:
	var view: Dictionary = root._chests.view(player_id)
	if player_id == str(root._registry.local_player_id):
		if open_window and not view.is_empty() and root._ui != null:
			root._ui.open_window("chest")
		return
	var peer: int = root._registry.get_peer_id(player_id)
	if peer == 0:
		_sent.erase(player_id)
		return
	if view == _sent.get(player_id, {}) and not open_window:
		return
	_sent[player_id] = view
	root._networking.send_own_state(peer, { "chest_view": view, "chest_open": open_window })
	_push_inventory(player_id)

## Host: a peer's pack changed here (a chest move, a placement, a broken lockpick): mirror it to that peer alone.
func _push_inventory(player_id: String) -> void:
	if player_id == "" or player_id == str(root._registry.local_player_id):
		return
	var inv: Node = root._registry.get_inventory(player_id)
	if inv != null and inv.has_method("get_contents"):
		GameBus.inventory_synced.emit(player_id, inv.get_contents(), inv.get_durability_data())

## What this machine's player has open: the host reads its slice, a client the last view it was sent.
func view() -> Dictionary:
	if root._is_client:
		return _view
	return root._chests.view("") if root._chests != null else {}

## Client: adopt the host's view; open the window when the host says the chest was just opened.
func apply_own_view(data: Dictionary) -> void:
	if data.get("door_open", null) is String:
		open_door_here(str(data["door_open"]).left(64))
	if not (data.get("chest_view", null) is Dictionary):
		return
	_view = _clean_view(data["chest_view"])
	if bool(data.get("chest_open", false)) and not _view.is_empty() and root._ui != null:
		root._ui.open_window("chest")

static func _clean_view(raw: Dictionary) -> Dictionary:
	if raw.is_empty() or not ChestRules.is_lock_type(str(raw.get("type", ""))):
		return {}
	var items := {}
	if raw.get("items", null) is Dictionary:
		for k: Variant in raw["items"]:
			var n: Variant = raw["items"][k]
			if (n is int or n is float) and items.size() < 256:
				items[str(k).left(64)] = int(n)
	var out := { "items": items }
	for k: String in ["id", "type", "kind", "mode"]:
		out[k] = str(raw.get(k, "")).left(64)
	for k: String in ["used", "capacity", "hp", "max_hp"]:
		out[k] = int(raw.get(k, 0)) if (raw.get(k, 0) is int or raw.get(k, 0) is float) else 0
	out["owner"] = bool(raw.get("owner", false))
	return out

func tick(delta: float) -> void:
	if root._ui != null and root._ui.chest_panel != null and not root._ui.chest_panel.source.is_valid():
		root._ui.chest_panel.source = self.view
	_tick_doors(delta)
	if root._is_client or root._chests == null:
		return
	root._chests.tick(delta)
	for pid: String in root._chests.take_dirty():
		push_view(pid)   # only players whose open chest changed, or who opened or closed one

# --- persistence -----------------------------------------------------------------------------------------

func to_data() -> Dictionary:
	return root._chests.to_data() if root._chests != null else {}

## Host load: the saved chests and doors whose station still stands. A record from before chests (no
## `chests` key) turns each migrated settlement's stockpile into a clan chest where its hearth stood.
func load_record(world: Dictionary) -> void:
	if root._chests == null:
		return
	if world.has("chests"):
		root._chests.from_data(world["chests"], func(id: String) -> bool: return root._station.get_station(id).size() > 0)
		return
	root._chests.from_data({})
	var made := migrate_stockpiles(world)
	if made > 0:
		print("[Server] %d settlement stockpiles became clan chests" % made)

## Each clan made from a settlement gets that settlement's stockpile as clan chests at the settlement's hearth:
## as many as it fills (`ChestSlice.split_stock`), on free cells around the hearth, every unit kept. All or
## nothing: a settlement whose chests cannot all be made (no hearth position, no room, the lock cap) keeps
## its stock. Returns how many chests were made.
func migrate_stockpiles(world: Dictionary) -> int:
	if root._clans == null or root._settlements == null:
		return 0
	var raw: Variant = (world.get("settlements", {}) as Dictionary).get("settlements", {}) if world.get("settlements", {}) is Dictionary else {}
	if not (raw is Dictionary):
		return 0
	var type := ""
	for t: String in ChestRules.station_types():
		if ChestRules.holds_items(t):
			type = t
	var made := 0
	for cid: String in root._clans.ids():
		var sid := str(root._clans.get_clan(cid).get("settlement", ""))
		var s: Variant = (raw as Dictionary).get(sid, null)
		if sid == "" or type == "" or not (s is Dictionary) or root._settlements.stock_of(sid).is_empty():
			continue
		var hearth: Variant = s.get("hearth", null)
		if not (hearth is Dictionary and WorldPos.is_wire(hearth)):
			continue
		var at: Vector3 = root._station.snap_to_grid(WorldPos.from_wire(hearth))
		var parts: Array = ChestSlice.split_stock(root._settlements.stock_of(sid), ChestRules.capacity_stacks(type))
		var placed: Array = []
		for part: Dictionary in parts:
			var cell: Variant = _free_cell(at)
			if not (cell is Vector3):
				break
			_migrating = true
			var id: String = root._station.place_station(type, cell)
			_migrating = false
			placed.append(id)
			if not root._chests.register_clan_chest(id, type, cell, cid, part):
				break
		if placed.size() == parts.size() and placed.all(func(id: String) -> bool: return root._chests.has_lock(id)):
			root._settlements.take_stock(sid)
			made += placed.size()
			continue
		for id: String in placed:
			root._chests.clear_lock(id)
			root._station.remove_station(id)
	return made

## The grid cell nearest `at` (rings of 1 m cells around it, out to 3 m) with no station on it, or null.
func _free_cell(at: Vector3) -> Variant:
	for r in 4:
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var cell := at + Vector3(dx, 0.0, dz)
				var taken := false
				for st: Dictionary in root._station.get_all_stations():
					if (st["position"] as Vector3).distance_to(cell) < StationSlice.MIN_STATION_SPACING:
						taken = true
						break
				if not taken:
					return cell
	return null
