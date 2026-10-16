extends "res://src/core/wiring.gd"
## Settlement wiring (Phase 140) — founding at a placed hearth, the host tick, and per-peer view syncs.
## `root` is the GameRoot that owns the slices.

const SettlementSlice := preload("res://src/settlement/settlement_slice.gd")

## Seconds between host sweeps (grow, abandon, decay, activity, view pushes).
const TICK_SEC := 0.5

var _elapsed: float = 0.0
var _dirty: bool = true

func wire(ctx: GameRoot) -> void:
	root = ctx
	connect_bus(GameBus.settlements_changed, _on_changed)
	connect_bus(GameBus.settlement_resolved, _on_resolved)
	connect_bus(GameBus.station_placed, _on_station_placed)

func _on_changed() -> void:
	_dirty = true

## A hearth placed by the local player (host or listen host) founds a settlement there. The placement
## already took the Hearth item and `StationSlice` refused an occupied spot, so this only records it.
func _on_station_placed(station_id: String, type: String, position: Vector3) -> void:
	if root._is_client or root._settlements == null or type != str(root._settlements.rules()["hearthStation"]):
		return
	var pid: String = root._registry.local_player_id
	var why: String = root._settlements.found(pid, "Settlement %d" % (root._settlements.count() + 1), Vector2(position.x, position.z), false)
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
	if root._is_client or root._settlements == null:
		return
	_elapsed += delta
	if _elapsed < TICK_SEC:
		return
	_elapsed = 0.0
	for pid: String in root._registry.get_online_player_ids():
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
