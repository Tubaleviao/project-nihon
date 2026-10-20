extends "res://src/core/wiring.gd"
## Carcass wiring (Phase 161) — a kill leaves a body; a player works it with a tool or carries it home.
##
## Host / offline: `creature_died` creates the carcass (no pickups are rolled); `harvest_intent`,
## `carry_intent` and `carcass_drop_intent` (the local player's, or a peer's bound to its connection) are
## checked here against the host's own knowledge of range, tool, capacity and state. A harvest is a timed
## action cancelled by moving, damage, death or picking a body up; completion rolls the yield and grade from
## the player's Skinning level and the tool's efficiency, wears the tool, grants XP and puts the items in the
## bag (on the ground when it is full). Client: `peer_carcass_synced` / `peer_carcass_removed` keep the view.

const CarcassRules := preload("res://src/loot/carcass_rules.gd")
const PlayerRegistry := preload("res://src/persistence/player_registry.gd")

## How far a harvester may drift from where the action began before it is cancelled.
const MOVE_CANCEL_M := 0.6
## A carried body's position is re-sent at most this often (seconds).
const CARRY_SEND_INTERVAL := 0.2

## player id -> { carcass, remaining, origin: Vector3, category, item, efficiency }
var _actions: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _send_clock: float = 0.0
## Carriers hit this frame: checked for death on the next tick.
var _death_check: Array = []
## peer id -> { carcass id: true } the host already sent into that peer's AOI.
var _seen: Dictionary = {}
var _aoi_clock: float = 0.0
## How often the host looks for bodies newly inside a peer's AOI (seconds).
const AOI_SCAN_INTERVAL := 1.0

func _connect_all() -> void:
	if root._battle != null and not root._is_client:
		root._battle.attack_blocked = func(attacker_id: String) -> bool:
			return root._carcass != null and root._carcass.carried_by(_pid(attacker_id)) != ""
	connect_bus(GameBus.creature_died, _on_creature_died)
	connect_bus(GameBus.harvest_intent, _on_harvest_intent)
	connect_bus(GameBus.carry_intent, _on_carry_intent)
	connect_bus(GameBus.carcass_drop_intent, _on_drop_intent)
	connect_bus(GameBus.harvest_resolved, _on_resolved)
	connect_bus(GameBus.carcass_changed, _on_changed)
	connect_bus(GameBus.carcass_removed, _on_removed)
	connect_bus(GameBus.carcass_carrier_lost, _on_carrier_lost)
	connect_bus(GameBus.player_damaged, _on_player_damaged)
	connect_bus(GameBus.player_left, _on_player_left)
	connect_bus(GameBus.player_joined, _on_player_joined)
	connect_bus(GameBus.peer_carcass_synced, _on_view_synced)
	connect_bus(GameBus.peer_carcass_removed, _on_view_removed)
	connect_bus(GameBus.carry_state_synced, _on_carry_state)

# ---------------------------------------------------------------------------
# Players
# ---------------------------------------------------------------------------

func _local_id() -> String:
	return root._registry.local_player_id if not root._registry.local_player_id.is_empty() else "player"

func _is_local(player_id: String) -> bool:
	return player_id == "" or player_id == "player" or player_id == root._registry.local_player_id

func _pid(player_id: String) -> String:
	return _local_id() if _is_local(player_id) else player_id

func _peer_of(player_id: String) -> int:
	return 1 if _is_local(player_id) else root._registry.get_peer_id(player_id)

## Test hook: `(player_id) -> Vector3` replaces the position read. Invalid in play.
var position_probe: Callable = Callable()

func _position_of(player_id: String) -> Variant:
	if position_probe.is_valid():
		return position_probe.call(player_id)
	if _is_local(player_id):
		return root._player.get_position()
	var peer: int = root._registry.get_peer_id(player_id)
	if peer != 0 and root._networking.has_last_known_state(peer):
		return root._networking.get_last_known_state(peer)
	return null

func _alive(player_id: String) -> bool:
	if _is_local(player_id):
		return root._player == null or root._player.get_hp() > 0.0
	return not PlayerRegistry.is_downed(root._registry.get_hp(player_id))

func _inventory_of(player_id: String) -> Node:
	return root._inventory if _is_local(player_id) else root._registry.get_inventory(player_id)

func level_of(player_id: String) -> int:
	return CarcassRules.level_for_xp(root._registry.get_skill_xp(_pid(player_id), CarcassRules.SKILL))

## The tool the player works a body with: the worn main hand if it provides a category some remaining entry
## needs, else the best held item that does; `{}` means bare hands.
func tool_for(player_id: String, carcass_id: String) -> Dictionary:
	var inv := _inventory_of(player_id)
	var candidates: Array = []
	var worn: String = str(root._registry.get_equipment(_pid(player_id)).get("MainHand", ""))
	if worn != "":
		candidates.append(worn)
	if inv != null:
		for item in inv.get_contents():
			if not candidates.has(item):
				candidates.append(item)
		for item in inv.get_durability_data():
			if not candidates.has(item):
				candidates.append(item)
	var best := {}
	for item in candidates:
		var t := CarcassRules.tool_of(str(item))
		if t.is_empty() or not _usable(inv, str(item)):
			continue
		if not _needs_category(carcass_id, str(t["tool"])):
			continue
		var cand := { "item": str(item), "tool": t["tool"], "efficiency": t["efficiency"] }
		if best.is_empty() or float(cand["efficiency"]) > float(best["efficiency"]):
			best = cand
	return best

# ---------------------------------------------------------------------------
# Host: death, harvest, carry
# ---------------------------------------------------------------------------

func _on_creature_died(entity_id: String, position: Vector3, killer_id: String, landing: Vector3) -> void:
	if root._is_client or root._carcass == null or entity_id == "player":
		return
	var key := entity_id
	if root._creature != null:
		var resolved: String = root._creature.get_instance_creature_id(entity_id)
		if resolved != "":
			key = resolved
	root._carcass.create_for_death(key, position if landing == Vector3.ZERO else landing, killer_id)

func _refuse(player_id: String, carcass_id: String, reason: String) -> void:
	GameBus.harvest_resolved.emit(player_id, carcass_id, reason, [])

func _on_harvest_intent(carcass_id: String, player_id: String) -> void:
	if root._is_client or root._carcass == null:
		return
	var pid := _pid(player_id)
	var pos: Variant = _position_of(pid)
	if pos == null or not _alive(pid):
		return
	if _actions.has(pid):
		return   # one harvest at a time
	var tool := tool_for(pid, carcass_id)
	var why: String = root._carcass.check_harvest(carcass_id, pos, str(tool.get("tool", "")), pid)
	if why == "" and not tool.is_empty() and not _holds(pid, str(tool["item"])):
		why = "no_tool"
	if why != "":
		_refuse(pid, carcass_id, why)
		return
	_actions[pid] = { "carcass": carcass_id, "remaining": CarcassRules.rule_f("harvestSeconds", 4.0), "origin": pos,
		"category": str(tool.get("tool", "")), "item": str(tool.get("item", "")), "efficiency": float(tool.get("efficiency", 1.0)) }
	GameBus.harvest_started.emit(pid, carcass_id, float(_actions[pid]["remaining"]))

## A tool is usable while any copy still has durability (`use_item` wears the most-worn usable copy).
func _usable(inv: Node, item: String) -> bool:
	if inv == null or not inv.is_durable(item):
		return true
	for v in inv.get_durability_values(item):
		if float(v) > 0.0:
			return true
	return false

## True when some remaining entry needs exactly `category` (entries needing no tool are worked bare-handed, so
## a held tool never changes them).
func _needs_category(carcass_id: String, category: String) -> bool:
	for e in root._carcass.workable_entries(carcass_id, category):
		if str(e.get("tool", "none")) == category:
			return true
	return false

func _holds(player_id: String, item: String) -> bool:
	if str(root._registry.get_equipment(_pid(player_id)).get("MainHand", "")) == item:
		return true
	var inv := _inventory_of(player_id)
	return inv != null and inv.get_item_count(item) > 0

func _cancel(player_id: String, reason: String) -> void:
	if _actions.has(player_id):
		var cid: String = _actions[player_id]["carcass"]
		_actions.erase(player_id)
		GameBus.harvest_resolved.emit(player_id, cid, reason, [])

func _finish(player_id: String) -> void:
	var a: Dictionary = _actions[player_id]
	_actions.erase(player_id)
	var cid: String = a["carcass"]
	var pos: Variant = _position_of(player_id)
	var category: String = str(a["category"])
	if pos == null or not _alive(player_id):
		GameBus.harvest_resolved.emit(player_id, cid, "moved", [])
		return
	var why: String = root._carcass.check_harvest(cid, pos, category, player_id)
	if why == "" and category != "" and not (_holds(player_id, str(a["item"])) and _usable(_inventory_of(player_id), str(a["item"]))):
		why = "no_tool"
	if why != "":
		GameBus.harvest_resolved.emit(player_id, cid, why, [])
		return
	var items: Array = root._carcass.resolve_harvest(cid, category, float(a["efficiency"]), level_of(player_id), _rng)
	var inv := _inventory_of(player_id)
	for it in items:
		if inv == null or not inv.add_item(str(it["item"]), int(it["quantity"])):
			if root._loot != null:
				root._loot.spawn_pickup(str(it["item"]), int(it["quantity"]), pos)
	if str(a["item"]) != "" and inv != null:
		inv.use_item(str(a["item"]), "harvest")
	root._registry.add_skill_xp(player_id, CarcassRules.SKILL, int(CarcassRules.skill().get("xpPerHarvest")))
	GameBus.harvest_resolved.emit(player_id, cid, "", items)

## Tell the harvester how it went, as a key + args the client renders in its own locale.
func _on_resolved(player_id: String, _carcass_id: String, reason: String, items: Array) -> void:
	if root._is_client:
		return
	if reason != "":
		GameBus.system_message.emit("hud.carcass.refused." + reason, [], player_id)
		return
	if items.is_empty():
		GameBus.system_message.emit("hud.carcass.nothing", [], player_id)
		return
	for it in items:
		GameBus.system_message.emit("hud.carcass.done", [int(it["quantity"]), str(it["item"])], player_id)

func _on_carry_intent(carcass_id: String, player_id: String) -> void:
	if root._is_client or root._carcass == null:
		return
	var pid := _pid(player_id)
	var pos: Variant = _position_of(pid)
	if pos == null or not _alive(pid):
		return
	var why: String = root._carcass.carry(carcass_id, pid, pos, level_of(pid))
	if why != "":
		_refuse(pid, carcass_id, why)
		return
	_cancel(pid, "cancelled")
	_push_carry_state(pid)

func _on_drop_intent(player_id: String) -> void:
	if root._is_client or root._carcass == null:
		return
	var pid := _pid(player_id)
	var pos: Variant = _position_of(pid)
	if pos == null:
		return
	root._carcass.drop(pid, pos)
	_push_carry_state(pid)

func _on_player_damaged(_damage: float, _attacker_id: String, target_id: String) -> void:
	if root._is_client or root._carcass == null:
		return
	var pid := _pid(target_id)
	_cancel(pid, "damaged")
	# `player_damaged` fires before the hit is applied to the body's health, so the death check waits for
	# the next tick.
	if root._carcass.carried_by(pid) != "" and not _death_check.has(pid):
		_death_check.append(pid)

func _drop_where_standing(pid: String) -> void:
	var pos: Variant = _position_of(pid)
	if pos != null and root._carcass.drop(pid, pos) != "":
		_push_carry_state(pid)

func _on_player_left(player_id: String) -> void:
	if root._carcass == null or root._is_client:
		return
	_actions.erase(player_id)
	_death_check.erase(player_id)
	var id: String = root._carcass.carried_by(player_id)
	if id == "":
		return
	# The body stays where it last followed its carrier when the carrier's position is already gone.
	var pos: Variant = _position_of(player_id)
	if pos == null:
		pos = root._carcass.get_carcass(id).get("position", Vector3.ZERO)
	root._carcass.drop(player_id, pos)

func _on_carrier_lost(player_id: String) -> void:
	if root._is_client or root._carcass == null:
		return
	_push_carry_state(player_id)

## Tell the player what the body does to their walking (the host applies it to its own avatar directly).
func _push_carry_state(pid: String) -> void:
	var carrying: bool = root._carcass.carried_by(pid) != ""
	var factor: float = root._carcass.speed_multiplier(pid, level_of(pid))
	if _is_local(pid):
		_on_carry_state(carrying, factor)
	elif root._networking != null and root._networking.is_host():
		root._networking.send_carry_state(_peer_of(pid), carrying, factor)

func _on_carry_state(carrying: bool, factor: float) -> void:
	if root._player != null:
		root._player.carrying = carrying
		root._player.carry_speed_factor = factor

# ---------------------------------------------------------------------------
# Host: tick and sync
# ---------------------------------------------------------------------------

func tick(delta: float) -> void:
	if root._carcass == null or root._is_client:
		return
	for pid in _death_check:
		if not _alive(pid):
			_drop_where_standing(pid)
	_death_check.clear()
	root._carcass.advance(delta)
	for pid in _actions.keys():
		var a: Dictionary = _actions[pid]
		var pos: Variant = _position_of(pid)
		if pos == null or not _alive(pid):
			_cancel(pid, "moved")
		elif (pos as Vector3).distance_to(a["origin"]) > MOVE_CANCEL_M:
			_cancel(pid, "moved")
		elif not root._carcass.has_carcass(a["carcass"]):
			_cancel(pid, "unknown_carcass")
		else:
			a["remaining"] = float(a["remaining"]) - delta
			if float(a["remaining"]) <= 0.0:
				_finish(pid)
	_send_clock += delta
	for pid in root._carcass._carried.keys():
		var at: Variant = _position_of(pid)
		if at != null:
			root._carcass.follow(pid, at)
	_aoi_clock += delta
	if _aoi_clock >= AOI_SCAN_INTERVAL:
		_aoi_clock = 0.0
		_scan_aoi()
	if _send_clock >= CARRY_SEND_INTERVAL:
		_send_clock = 0.0
		for pid in root._carcass._carried.keys():
			_on_changed(root._carcass.carried_by(pid))

func _on_changed(carcass_id: String) -> void:
	if root._is_client or root._networking == null or not root._networking.is_host():
		return
	var view: Dictionary = root._carcass.view_of(carcass_id)
	if not view.is_empty():
		root._networking.send_carcass(view)

func _on_removed(carcass_id: String) -> void:
	if root._is_client or root._networking == null or not root._networking.is_host():
		return
	root._networking.send_carcass_removed(carcass_id)

## Send each connected peer the bodies that came inside its AOI since the last scan, and forget the ones that
## left so they are sent again on return. (A body that changes while in view is re-sent by `_on_changed`.)
func _scan_aoi() -> void:
	if root._networking == null or not root._networking.is_host():
		return
	var peers: Array = root._networking.connected_peers()
	for stale in _seen.keys():
		if not peers.has(stale):
			_seen.erase(stale)
	for peer in peers:
		var peer_id := int(peer)
		if not root._networking.has_last_known_state(peer_id):
			continue
		var seen: Dictionary = _seen.get(peer_id, {})
		var fresh: Array = []
		var now := {}
		for id in root._carcass.ids():
			if root._networking.in_aoi(peer_id, root._carcass.position_of(id)):
				now[id] = true
				if not seen.has(id):
					fresh.append(root._carcass.view_of(id))
		for id in seen:
			if not now.has(id):
				root._networking.send_carcass_removed(str(id), peer_id)   # the client forgets what left its AOI
		_seen[peer_id] = now
		if not fresh.is_empty():
			root._networking.send_carcasses_to(peer_id, fresh)

func _on_player_joined(peer_id: int, _player_id: String, _reconnected: bool) -> void:
	if root._is_client or root._carcass == null or root._networking == null or not root._networking.is_host():
		return
	var list: Array = []
	var sent := {}
	for id in root._carcass.ids():
		if root._networking.has_last_known_state(peer_id) and not root._networking.in_aoi(peer_id, root._carcass.position_of(id)):
			continue
		list.append(root._carcass.view_of(id))
		sent[id] = true
	_seen[peer_id] = sent   # replaces any set left by an earlier connection with the same peer id
	root._networking.send_carcasses_to(peer_id, list)

# ---------------------------------------------------------------------------
# Client
# ---------------------------------------------------------------------------

func _on_view_synced(record: Dictionary) -> void:
	if root._is_client and root._carcass != null:
		root._carcass.apply_view(record)

func _on_view_removed(carcass_id: String) -> void:
	if root._is_client and root._carcass != null:
		root._carcass.remove_view(carcass_id)

func unwire() -> void:
	if root != null and root._battle != null:
		root._battle.attack_blocked = Callable()
	super.unwire()
