extends "res://src/core/wiring.gd"
## Waystone wiring (Phase 132) — Waystone sync and travel.
## Moved out of game_root.gd; `root` is the GameRoot that owns the slices.

const WorldPos := preload("res://src/terrain/world_pos.gd")

func wire(ctx: GameRoot) -> void:
	root = ctx
	connect_bus(GameBus.waystone_travel_resolved, _on_waystone_travel_resolved)
	connect_bus(GameBus.station_placed, _on_station_placed_exact)
	connect_bus(GameBus.waystones_synced, _on_waystones_synced)

## Phase 125 — where the host believes a player stands, as an exact `{chunk, local}`: the live body for the
## local player, the peer's last reported position for a remote one. A peer that has not reported yet is
## nowhere: the saved record is where it logged out, not where it stands.
func _waystone_player_pos(player_id: String) -> Dictionary:
	if player_id == root._registry.local_player_id and root._player != null:
		return root._player.get_world_pos()
	var peer := root._registry.get_peer_id(player_id)
	if peer != 0:
		return root._networking.get_last_known_exact(peer)
	return {}

## Phase 125 — a player's attunements changed on the host: save them on the record and push them to
## the owner's peer alone. The local player is live here already.
func _on_waystones_synced(player_id: String, station_ids: Array) -> void:
	if root._is_client:
		return
	if player_id == root._registry.local_player_id or player_id == "":
		return
	var peer := root._registry.get_peer_id(player_id)
	if peer != 0:
		root._networking.send_own_state(peer, { "waystones": station_ids })

## Phase 125 — the host resolved a travel intent: tell the owner's peer, which shows a refusal.
func _on_waystone_travel_resolved(player_id: String, ok: bool, reason: String) -> void:
	if root._is_client or player_id == "" or player_id == root._registry.local_player_id:
		return
	var peer := root._registry.get_peer_id(player_id)
	if peer != 0:
		root._networking.send_own_state(peer, { "waystone_result": { "ok": ok, "reason": reason } })

## Phase 130 — record a waystone's exact `{chunk, local}` at placement: the placer's exact position plus
## the small offset to the stone, so a stone placed far from the origin is not a float32 `Vector3`.
func _on_station_placed_exact(station_id: String, type: String, position: Vector3) -> void:
	if root._is_client or root._waystones == null or root._player == null or type != root._waystones.station_type():
		return
	var here: Dictionary = root._player.get_world_pos()
	root._waystones.note_exact(station_id, WorldPos.normalized({
		"chunk": here["chunk"],
		"local": (here["local"] as Vector3) + (position - root._player.get_position()),
	}))
