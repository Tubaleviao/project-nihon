extends "res://src/core/wiring.gd"
## Writing wiring (Phase 209) — books and blueprints: builds the host's `WritingSlice` against the technology tree,
## the players' packs and the stations, tells the actor how their intent went, and mirrors a peer's pack after a
## write. What a reader learns reaches their record and their client through the research paths
## (`CraftingWiring._on_research_resolved` / `_on_research_points_synced`).

const WritingSlice := preload("res://src/technology/writing_slice.gd")
const WritingRules := preload("res://src/technology/writing_rules.gd")

func make_slice(ctx: GameRoot) -> Node:
	root = ctx
	var slice := WritingSlice.new()
	slice.is_host = not root._is_client
	slice.technology = root._technology
	slice.inventory_for = func(pid: String) -> Node: return root._technology.inventory_for(pid)
	slice.position_of = func(pid: String) -> Variant: return root._chest_wiring.player_pos(pid)
	slice.nearest_station = root._station.nearest_station
	return slice

func _connect_all() -> void:
	connect_bus(GameBus.writing_resolved, _on_resolved)

func _on_resolved(player_id: String, action: String, item_id: String, ok: bool, reason: String) -> void:
	if root._is_client or player_id == "":
		return
	if reason != "rate":
		# Keys and the taught key only: the item id is never shown as prose.
		var w := WritingRules.of(item_id)
		var key := "writing.refused." + reason
		if ok:
			key = "writing.ok.read" if action == "read" else "writing.ok.write_%s" % str(w.get("writing", "")).to_lower()
		GameBus.system_message.emit(key, [str(w.get("teaches", ""))], player_id)
	if ok and action == "write":
		root._chest_wiring._push_inventory(player_id)
