extends "res://src/core/wiring.gd"
## Character wiring (Phase 132) — Equipment and appearance.
## Moved out of game_root.gd; `root` is the GameRoot that owns the slices.

const EquipmentRules := preload("res://src/character/equipment_rules.gd")

## Phase 47 — true while the local avatar is put into a recorded set, so the restore does not echo
## back out as a fresh equip intent.
var _applying_equipment: bool = false

func _connect_all() -> void:
	connect_bus(GameBus.equipment_revoked, _on_equipment_revoked)
	connect_bus(GameBus.character_appearance_changed, _on_character_appearance_changed)
	connect_bus(GameBus.peer_equipment_synced, root._character.set_peer_equipment)
	connect_bus(GameBus.peer_equipment_evicted, root._character.evict_peer_equipment)

func apply_local_equipment(worn: Variant) -> void:
	var char_id: String = root._character.get_player_character()
	if char_id == "" or not (worn is Dictionary):
		return
	if root._is_client:
		# The host's record is the only worn set: the avatar shows exactly that, an empty
		# record included (gear an appearance recipe lists but the host never granted is not
		# worn). Nothing is reported back; the client only ever sends equip actions.
		apply_host_equipment(worn)
		return
	# An empty record (fresh player, or a pre-Phase-47 save with no worn set) carries no
	# information: the avatar keeps the gear its appearance recipe gave it, and that
	# set becomes the record instead of stripping the avatar bare.
	if not (worn as Dictionary).is_empty():
		_applying_equipment = true
		root._character.apply_equipment_set(char_id, worn)
		_applying_equipment = false
	elif not root._registry.local_player_id.is_empty():
		root._registry.record_equipment(root._registry.local_player_id, root._character.get_equipment_set(char_id))

## Phase 48 — the host force-cleared worn slots (an item left the bag). Unlike
## `apply_local_equipment` an EMPTY set is meaningful here and strips the avatar. The
## de-dup baseline is reset to the applied set so re-wearing the item is sent again.
func apply_host_equipment(worn: Dictionary) -> void:
	var char_id: String = root._character.get_player_character()
	if char_id == "":
		return
	_applying_equipment = true
	root._character.apply_equipment_set(char_id, worn)
	_applying_equipment = false
	root._last_sent_equipment = root._character.get_equipment_set(char_id).duplicate()

## Listen host: its own bag lost a worn item; the record is already cleared, the avatar
## is not. A remote owner is told by the networking slice instead.
func _on_equipment_revoked(player_id: String, worn: Dictionary) -> void:
	if root._is_client or player_id.is_empty() or player_id != root._registry.local_player_id:
		return
	apply_host_equipment(worn)

## Phase 47 — the local avatar's gear changed. A host records it; a client turns the change
## into one equip / unequip ACTION per differing slot (the host validates each against the
## fabric and the bag, applies it to its own record and replicates it to nearby peers).
func _on_character_appearance_changed(instance_id: String, _appearance: Dictionary) -> void:
	if _applying_equipment or instance_id != root._character.get_player_character():
		return
	var worn: Dictionary = root._character.get_equipment_set(instance_id)
	if root._is_client:
		for action in EquipmentRules.diff_actions(root._last_sent_equipment, worn):
			GameBus.equip_intent.emit("", str(action["slot"]), str(action["item"]))
		root._last_sent_equipment = worn.duplicate()
	elif not root._registry.local_player_id.is_empty():
		root._registry.record_equipment(root._registry.local_player_id, worn)

