extends "res://src/core/wiring.gd"
## Clan wiring (Phase 204) — the host tick, intent results and per-peer view syncs. A member's view carries
## the roster with every member's skills; the host sends it only to that clan's own peers, and a player who
## leaves gets a view without it on the next push. `root` is the GameRoot that owns the slices.

const ClanSlice := preload("res://src/clan/clan_slice.gd")

## Seconds between host sweeps (invite lapses, view pushes).
const TICK_SEC := 0.5

var _elapsed: float = 0.0
var _online: Array = []
var _ui_bound: bool = false

func make_slice(ctx: GameRoot) -> Node:
	root = ctx
	var slice := ClanSlice.new()
	slice.registry = root._registry
	slice.is_host = not root._is_client
	return slice

## The windows are built after the slices: bind them on the first frame they exist.
func _bind_ui() -> void:
	var ui: Node = root._ui
	if _ui_bound or ui == null or ui.clan_panel == null:
		return
	_ui_bound = true
	ui.clan_panel.clan_slice = root._clans

func _connect_all() -> void:
	connect_bus(GameBus.clan_resolved, _on_resolved)
	connect_bus(GameBus.attributes_synced, _on_attributes_synced)
	connect_bus(GameBus.skill_tier_recorded, _on_skill_tier_recorded)
	connect_bus(GameBus.player_joined, _on_player_joined)

## A session opened (a reconnect too, however fast): that player's new connection needs its view. The online
## diff in `tick` would miss a drop and rejoin between two sweeps.
func _on_player_joined(_peer_id: int, player_id: String, _reconnected: bool) -> void:
	if not root._is_client and root._clans != null and player_id != "":
		root._clans.note_session(player_id)

## A skill grant (which emits `attributes_synced`) or a new tier changed a member's record on the host: their
## clan's roster goes out again. Never read from a message: the roster is built from the host's records.
func _on_attributes_synced(player_id: String, _attributes: Dictionary) -> void:
	if not root._is_client and root._clans != null:
		root._clans.note_skills_changed(player_id)

func _on_skill_tier_recorded(player_id: String, _skill: String, _tier: String) -> void:
	_on_attributes_synced(player_id, {})

## Tell the actor's peer how its intent went; the local player reads the bus directly.
func _on_resolved(player_id: String, action: String, ok: bool, reason: String) -> void:
	if root._is_client or player_id == "" or player_id == root._registry.local_player_id:
		return
	var peer: int = root._registry.get_peer_id(player_id)
	if peer != 0:
		root._networking.send_own_state(peer, { "clan_result": { "action": action, "ok": ok, "reason": reason } })

func tick(delta: float) -> void:
	_bind_ui()
	if root._is_client or root._clans == null:
		return
	_elapsed += delta
	if _elapsed < TICK_SEC:
		return
	_elapsed = 0.0
	root._clans.tick(float(root._clans.now_sec.call()))
	var online: Array = root._registry.get_online_player_ids()
	online.sort()
	var targets: Array = root._clans.take_dirty()
	if online != _online:
		# A player who just connected has no view yet, and the others' rosters show who is online.
		for pid: String in online:
			if not _online.has(pid):
				targets.append(pid)
		for pid: String in online + _online:
			if online.has(pid) != _online.has(pid):
				root._clans.note_presence_changed(pid)
		_online = online
		targets.append_array(root._clans.take_dirty())
	push_views(targets)

## Send each of `players` that is online its own view; the local player's view is applied in place. Each clan's
## roster is built once per push and shared by its members' views.
func push_views(players: Array) -> void:
	var local: String = root._registry.local_player_id
	var seen := {}
	var rosters := {}
	for pid: String in players:
		if seen.has(pid):
			continue
		seen[pid] = true
		if pid == local:
			root._clans.apply_view(root._clans.private_view(pid, rosters))
			continue
		var peer: int = root._registry.get_peer_id(pid)
		if peer != 0 and root._networking != null and root._networking.is_host():
			root._networking.send_own_state(peer, { "clan_view": root._clans.private_view(pid, rosters) })
