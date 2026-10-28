extends "res://src/core/wiring.gd"
## Phase 181 — character creation at runtime: the host intent, the owner's view of its own creation, the
## peers' looks and the offer of the creation screen.
##
## Host / offline: `character_creation_intent` (the local player's, or a peer's bound to its connection) goes to
## `PlayerRegistry.create_character` / `skip_creation`, which validate and record it. The local player's avatar
## is rebuilt in place; a remote owner is sent its new state and the result on the owner-only own-state channel
## (`creation`, `creation_result`), plus its record (the starting kit landed in its bag). Everyone in range
## learns the new look through `player_look_changed` (networking).
## Client: its own state arrives in the join snapshot and on the own-state channel; peers' looks arrive as
## `peer_look_synced` and dress their avatars.
## Any machine with a UI offers the screen once per session while its own state is "none", after the boot.

const CreationRules := preload("res://src/character/creation_rules.gd")

## This machine's own creation state as the host last told it (a client), or as the registry holds it (host).
var _own_state: Dictionary = { "state": CreationRules.STATE_NONE }
## A client knows its own state only once the join snapshot arrived.
var _own_known: bool = false
## The screen is offered at most once per session (it stays reachable from the character sheet).
var offered: bool = false

func _connect_all() -> void:
	connect_bus(GameBus.character_creation_intent, _on_creation_intent)
	connect_bus(GameBus.peer_look_synced, _on_peer_look_synced)

## This machine's own creation state.
func own_state() -> Dictionary:
	if root._is_client:
		return _own_state.duplicate()
	return root._registry.creation_of(root._registry.local_player_id)

## The name this machine's own player is shown by.
func own_display_name() -> String:
	var handle: String = root._networking.claimed_handle if root._is_client else root._registry.public_handle(root._registry.local_player_id)
	return CreationRules.display_name(own_state(), handle)

func tick(_delta: float) -> void:
	# The host's own player has no handshake to learn its handle from: the registry derives it.
	if not root._is_client and root._ui != null and root._ui.own_handle == "" and root._registry.local_player_id != "":
		root._ui.set_own_handle(root._registry.public_handle(root._registry.local_player_id))
		root._ui.set_creation_state(own_state())
	maybe_offer()

## Show the creation screen when this machine has one, its boot is over and its own state is still "none".
## Returns true when it was shown now.
func maybe_offer() -> bool:
	if offered or root._is_server or root._ui == null or not root._ui.is_inside_tree() or root._pending_host_boot:
		return false
	if root._is_client and (not _own_known or not root._client_boot_done):
		return false
	if root._loading_screen != null and root._loading_screen.is_active():
		return false
	if not CreationRules.should_offer(own_state()):
		return false
	offered = true
	root._ui.show_creation(own_state())
	return true

## Host: resolve a creation or skip for the local player ("") or a peer bound to its connection.
func _on_creation_intent(action: String, creation: Dictionary, player_id: String) -> void:
	if root._is_client:
		return   # forwarded by the networking slice
	var local: bool = player_id == "" or player_id == root._registry.local_player_id
	var pid: String = root._registry.local_player_id if local else player_id
	var reason := ""
	match action:
		"create":
			reason = root._registry.create_character(pid, creation)
		"skip":
			reason = root._registry.skip_creation(pid)
		_:
			return
	var state: Dictionary = root._registry.creation_of(pid)
	if local:
		if reason == "" and action == "create":
			_dress_own(state)
		GameBus.character_creation_resolved.emit(pid, action, reason, state)
		return
	var peer: int = root._registry.get_peer_id(pid)
	if peer == 0 or root._networking == null or not root._networking.is_host():
		return
	if reason == "" and action == "create":
		root._peer_wiring.sync_peer_own_state({ "success": true, "player_id": pid })
	root._networking.send_own_state(peer, { "creation": state, "creation_result": { "action": action, "reason": reason } })

## Client: the creation half of a join snapshot or an own-state message.
func apply_own(data: Dictionary) -> void:
	if not root._is_client:
		return
	if data.has("creation"):
		_own_known = true
		_own_state = CreationRules.sanitize_state(data["creation"])
		if CreationRules.is_created(_own_state):
			_dress_own(_own_state)
		if root._ui != null:
			root._ui.set_creation_state(_own_state)
	if data.get("creation_result", null) is Dictionary:
		var res: Dictionary = data["creation_result"]
		GameBus.character_creation_resolved.emit(root._registry.local_player_id, str(res.get("action", "")).left(8),
			str(res.get("reason", "")).left(32), _own_state.duplicate())

## Rebuild this machine's own avatar in a created look (no-op when it has none yet or already wears it).
func _dress_own(state: Dictionary) -> void:
	var iid: String = root._character.get_player_character()
	if iid == "" or not CreationRules.is_created(state):
		return
	var look := CreationRules.look(state, "")
	var key := JSON.stringify(look)
	if str(root._character._instances[iid].get("look_key", "")) == key:
		return
	root._character.apply_look(iid, look)
	root._character._instances[iid]["look_key"] = key
	if root._ui != null:
		root._ui.set_creation_state(state)

## The appearance recipe the local avatar starts in: the created look, else null (the caller keeps its own).
## `raw` is a creation state as a record or a snapshot carries it.
func boot_recipe(raw: Variant) -> Variant:
	var state := CreationRules.sanitize_state(raw)
	if not CreationRules.is_created(state):
		return null
	var recipe: Dictionary = root._character.creation_recipe(CreationRules.look(state, ""))
	return recipe if not recipe.is_empty() else null

func _on_peer_look_synced(peer_id: int, look: Dictionary) -> void:
	if not root._is_client or peer_id <= 0:
		return
	root._character.set_peer_look(peer_id, look)
