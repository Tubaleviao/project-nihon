extends "res://src/core/wiring.gd"
## Settlement wiring (Phase 140) — founding at a placed hearth, the host tick, and per-peer view syncs.
## `root` is the GameRoot that owns the slices.

const SettlementSlice := preload("res://src/settlement/settlement_slice.gd")
const I18n := preload("res://src/core/i18n.gd")
const WorldPos := preload("res://src/terrain/world_pos.gd")

## Seconds between host sweeps (grow, abandon, decay, activity, view pushes).
const TICK_SEC := 0.5

var _elapsed: float = 0.0
var _dirty: bool = true
var _online: Array = []
var _ui_bound: bool = false

## Build the slice and hand it the host-side guards (mine, place, station placement, research).
func make_slice(ctx: GameRoot) -> Node:
	root = ctx
	var slice := SettlementSlice.new()
	slice.registry = root._registry
	slice.position_of = Callable(self, "player_xz")
	slice.is_host = not root._is_client
	root._voxel.claim_guard = Callable(slice, "edit_blocker")
	root._station.claim_guard = Callable(slice, "edit_blocker")
	root._tree.claim_guard = Callable(slice, "edit_blocker")
	root._station.settlement_slice = slice
	root._technology.settlement_slice = slice
	return slice

## The windows are built after the slices: bind them on the first frame they exist.
func _bind_ui() -> void:
	var ui: Node = root._ui
	if _ui_bound or ui == null or ui.map_window == null or ui.settlement_panel == null:
		return
	_ui_bound = true
	ui.map_window.settlement_slice = root._settlements
	ui.settlement_slice = root._settlements
	ui.settlement_panel.settlement_slice = root._settlements

func wire(ctx: GameRoot) -> void:
	root = ctx
	connect_bus(GameBus.settlements_changed, _on_changed)
	connect_bus(GameBus.settlement_resolved, _on_resolved)
	connect_bus(GameBus.station_placed, _on_station_placed)
	connect_bus(GameBus.block_changed, _on_block_changed)

func _on_changed() -> void:
	_dirty = true

## A block edit that passed the claim guard counts as activity for the local player's claim (remote
## players are covered by the standing-in-claim sweep in `tick`).
func _on_block_changed(_action: String, position: Vector3, _normal: Vector3, _material: String) -> void:
	if root._is_client or root._settlements == null:
		return
	root._settlements.note_edit(root._registry.local_player_id, Vector2(position.x, position.z))

## A hearth placed by the local player (host or listen host) founds a settlement there. The placement
## already took the Hearth item and `StationSlice` refused an occupied spot, so this only records it.
func _on_station_placed(station_id: String, type: String, position: Vector3) -> void:
	if root._is_client or root._settlements == null or type != str(root._settlements.rules()["hearthStation"]):
		return
	var pid: String = root._registry.local_player_id
	# The exact hearth position: the placer's exact position plus the small offset to the hearth, never the
	# float32 `Vector3` (as the waystone does).
	var exact: Dictionary = {}
	if root._player != null:
		var here: Dictionary = root._player.get_world_pos()
		exact = WorldPos.normalized({
			"chunk": here["chunk"],
			"local": (here["local"] as Vector3) + (position - root._player.get_position()),
		})
	var why: String = root._settlements.found(pid, I18n.t("settlement.default_name", [root._settlements.count() + 1]), Vector2(position.x, position.z), false, exact)
	if why != "" and root._station != null:
		root._station.remove_station(station_id)

## Tell the actor's peer how its intent went; the local player reads the bus directly.
func _on_resolved(player_id: String, action: String, ok: bool, reason: String) -> void:
	if root._is_client or player_id == "" or player_id == root._registry.local_player_id:
		return
	var peer: int = root._registry.get_peer_id(player_id)
	if peer != 0:
		root._networking.send_own_state(peer, { "settlement_result": { "action": action, "ok": ok, "reason": reason } })

## Host tick: advance lifecycle, mark activity, push views when something changed.
func tick(delta: float) -> void:
	_bind_ui()
	if root._is_client or root._settlements == null:
		return
	_elapsed += delta
	if _elapsed < TICK_SEC:
		return
	_elapsed = 0.0
	var online: Array = root._registry.get_online_player_ids()
	online.sort()
	if online != _online:   # a player who just connected has no view yet
		_online = online
		_dirty = true
	for pid: String in online:
		root._settlements.note_activity(pid)
	root._settlements.tick(float(root._settlements.now_sec.call()))
	if _dirty:
		_dirty = false
		_count_colonization()
		push_views()

## Send every online peer its own view (public claims plus its settlement's private part); the local
## player's view is applied in place.
func push_views() -> void:
	for pid: String in root._registry.get_online_player_ids():
		var view: Dictionary = root._settlements.private_view(pid)
		if pid == root._registry.local_player_id:
			root._settlements.apply_view(view)
			continue
		var peer: int = root._registry.get_peer_id(pid)
		if peer != 0 and root._networking != null and root._networking.is_host():
			root._networking.send_own_state(peer, { "settlement_view": view })

## Where the host believes a player stands, as ground metres (null when unknown).
func player_xz(player_id: String) -> Variant:
	if player_id == root._registry.local_player_id and root._player != null:
		return SettlementSlice.xz_of_exact(root._player.get_world_pos())
	var peer: int = root._registry.get_peer_id(player_id)
	if peer != 0:
		var pos: Dictionary = root._networking.get_last_known_exact(peer)
		if not pos.is_empty():
			return SettlementSlice.xz_of_exact(pos)
	return null

## Phase 140 — every settlement counts toward its region's colonization score.
func _count_colonization() -> void:
	var chunks: Array = []
	for id: String in root._settlements.ids():
		var s: Dictionary = root._settlements.get_settlement(id)
		chunks.append(Vector2i(floori(float(s["hx"]) / SettlementSlice.WorldPos.CHUNK_METERS), floori(float(s["hz"]) / SettlementSlice.WorldPos.CHUNK_METERS)))
	root._colonization.set_settlements(chunks)
