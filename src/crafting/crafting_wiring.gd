extends "res://src/core/wiring.gd"
## Crafting wiring (Phase 132) — Crafting, research, gathering, taming and item feedback.
## Moved out of game_root.gd; `root` is the GameRoot that owns the slices.


func _connect_all() -> void:
	connect_bus(GameBus.inventory_full, _on_inventory_full)
	connect_bus(GameBus.craft_resolved, _on_craft_resolved)
	connect_bus(GameBus.repair_resolved, _on_repair_resolved)
	connect_bus(GameBus.profession_unlocked, _on_profession_unlocked)
	connect_bus(GameBus.research_resolved, _on_research_resolved)
	connect_bus(GameBus.research_points_synced, _on_research_points_synced)
	connect_bus(GameBus.resource_gathered, _on_resource_gathered)
	connect_bus(GameBus.tame_resolved, _on_tame_resolved)

func _on_inventory_full() -> void:
	if root._is_server or root._registry == null or root._registry.local_player_id.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - root._pack_full_notice_msec < root.PACK_FULL_NOTICE_MSEC:
		return
	root._pack_full_notice_msec = now
	GameBus.system_message.emit("chat.pack_full", [], root._registry.local_player_id)

## Phase 34 — a craft the host resolved for a REMOTE peer changed that peer's own
## record. Its client only ever mirrors its own state from a snapshot, so without
## this push it would keep showing the pre-craft inventory until the next AOI
## re-scope or reconnect. Scoped to that peer; the local player is already live
## here. (Craft got the same fix as the two new actions: it had the identical gap.)
func _on_craft_resolved(result: Dictionary) -> void:
	# Phase 118 — a void burst FAILED the craft but consumed the input and may have set a
	# flag, so the crafter's record changed: push it like a success would.
	if result.get("reason", "") == "void_burst":
		root._peer_wiring.sync_peer_own_state(result, true)
		return
	root._peer_wiring.sync_peer_own_state(result)

## Phase 34 — the repair half of the same rule.
func _on_repair_resolved(result: Dictionary) -> void:
	root._peer_wiring.sync_peer_own_state(result)

## Phase 34 — research: fold the researcher's new statuses into its record first, so
## the durable copy and the copy pushed to its client cannot diverge, then push.
func _on_research_resolved(result: Dictionary) -> void:
	if root._is_client:
		return
	var pid := str(result.get("player_id", ""))
	if pid != "":
		root._registry.record_technology(pid, root._technology.get_statuses(pid))
	root._peer_wiring.sync_peer_own_state(result)

## Phase 124 — a research-point balance changed on the host. Fold it into the player's
## record (so a save carries it) and push it to the OWNER's peer alone: points are private
## to the player, so unlike a world delta this is never broadcast. The local player is live
## here already, and a client never reaches this (it only mirrors the balance).
func _on_research_points_synced(player_id: String, _points: int) -> void:
	if root._is_client or player_id == "":
		return
	root._registry.record_technology(player_id, root._technology.get_statuses(player_id))
	if player_id == root._registry.local_player_id:
		return
	var peer := root._registry.get_peer_id(player_id)
	if peer == 0:
		return
	root._networking.send_own_state(peer, { "technology": root._technology.get_statuses(player_id) })

## Phase 124 — the host resolved a gather: pay the fabric's `gather` research points.
func _on_resource_gathered(player_id: String, _material: String, quantity: int) -> void:
	if root._is_client:
		return
	var pid := player_id if player_id != "" else root._registry.local_player_id
	# Scaled by the quantity, then held by the balance ceiling and the per-window cap.
	root._technology.grant_points(pid, "gather", root._technology.points_for("gather") * clampi(quantity, 0, 64))

## Phase 118 — an unlock the host resolved for a REMOTE peer changed its record's
## professions; push the owner's copy (the local player is live here already).
func _on_profession_unlocked(player_id: String, _profession: String) -> void:
	root._peer_wiring.sync_peer_own_state({ "success": true, "player_id": player_id })

## Phase 35 — a tame the host resolved for a REMOTE peer granted that peer a flag
## (e.g. `wolfBondHolder`) and possibly bound a companion, both of which live on its
## record. Fold the new flags and companions into the record first, so the durable
## copy and the copy pushed to its client cannot diverge, then push.
func _on_tame_resolved(result: Dictionary) -> void:
	if root._is_client:
		return
	var pid := str(result.get("player_id", ""))
	if pid != "":
		root._taming.sync_record(pid)
	root._peer_wiring.sync_peer_own_state(result)

