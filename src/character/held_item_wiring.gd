extends "res://src/core/wiring.gd"
## Held-item wiring (Phase 280) — the hotbar's selected item shows in the character's hand.
##
## Host / offline: `held_item_intent` (the local player's, or a peer's bound to its connection) is validated
## (a holdable item the player has at least one of, within the rate limit), kept per player, shown on the
## avatar and sent to the peers whose AOI holds the player (`held_item_synced`). The host re-checks on every
## inventory change: a held item that left the pack is cleared and synced empty. Client: `peer_held_item_synced`
## shows the item on the avatar it names (this machine's own body included); one for an avatar not built yet waits.

const HeldItem := preload("res://src/character/held_item.gd")

## Player id -> item id held (host). Absent = empty hands.
var _held: Dictionary = {}
## Player id -> msec stamps of recent changes (host, rate limit).
var _stamps: Dictionary = {}
## Peer id -> item id still to show on that peer's avatar (client, and a listen host's view of its clients).
var _pending: Dictionary = {}
## Peer id -> "instance|item" already on the avatar.
var _applied: Dictionary = {}

func _connect_all() -> void:
	connect_bus(GameBus.held_item_intent, _on_intent)
	connect_bus(GameBus.peer_held_item_synced, _on_peer_synced)
	connect_bus(GameBus.inventory_synced, _on_inventory_synced)
	connect_bus(GameBus.inventory_changed, _on_local_inventory_changed)
	connect_bus(GameBus.player_joined, _on_player_joined)
	connect_bus(GameBus.player_left, _on_player_left)
	connect_bus(GameBus.peer_disconnected, _forget_peer)
	connect_bus(GameBus.peer_equipment_evicted, _forget_peer)

func _local_id() -> String:
	return root._registry.local_player_id if not root._registry.local_player_id.is_empty() else "player"

func _is_local(player_id: String) -> bool:
	return player_id == "" or player_id == "player" or player_id == root._registry.local_player_id

func _peer_of(player_id: String) -> int:
	return 1 if _is_local(player_id) else root._registry.get_peer_id(player_id)

## What `player_id` holds in the pack, by the host's own record: item id -> count.
func _contents_of(player_id: String) -> Dictionary:
	if _is_local(player_id):
		return root._inventory.get_contents() if root._inventory != null else {}
	var inv: Node = root._registry.get_inventory(player_id) if root._registry.has_inventory(player_id) else null
	return inv.get_contents() if inv != null else {}

# ---------------------------------------------------------------------------
# Host
# ---------------------------------------------------------------------------

func _on_intent(item_id: String, player_id: String) -> void:
	if root._is_client:
		return   # a client's own intent is forwarded by the networking slice
	var pid := _local_id() if _is_local(player_id) else player_id
	if item_id == "":
		_hold(pid, "")   # empty hands need no evidence
		return
	if not HeldItem.holdable(item_id, GameData.ITEMS, GameData.MATERIALS):
		return
	if int(_contents_of(pid).get(item_id, 0)) < 1:
		return   # the player does not have it: nothing changes, nothing syncs
	var kept := HeldItem.admit(_stamps.get(pid, []), Time.get_ticks_msec())
	if kept.is_empty():
		return   # over the rate limit: dropped
	_stamps[pid] = kept
	_hold(pid, item_id)

func _hold(pid: String, item_id: String) -> void:
	if str(_held.get(pid, "")) == item_id:
		return
	if item_id == "":
		_held.erase(pid)
	else:
		_held[pid] = item_id
	GameBus.held_item_synced.emit(pid, item_id)
	var peer := _peer_of(pid)
	if peer == 0:
		return
	_show(peer, item_id)
	var net: Variant = root._networking
	if net != null and net.is_host():
		var at: Variant = _position_of(pid)
		if at != null:
			net.send_held_item(peer, item_id, at)

func _position_of(player_id: String) -> Variant:
	if _is_local(player_id):
		return root._player.get_position() if root._player != null else null
	var peer := root._registry.get_peer_id(player_id)
	if peer != 0 and root._networking.has_last_known_state(peer):
		return root._networking.get_last_known_state(peer)
	return null

## A pack changed: a held item that is no longer in it is cleared and synced empty.
func _recheck(pid: String) -> void:
	var item := str(_held.get(pid, ""))
	if item != "" and int(_contents_of(pid).get(item, 0)) < 1:
		_hold(pid, "")

func _on_inventory_synced(owner_id: String, contents: Dictionary, _durabilities: Dictionary = {}) -> void:
	if root._is_client:
		return
	var pid := _local_id() if _is_local(owner_id) else owner_id
	var item := str(_held.get(pid, ""))
	if item != "" and int(contents.get(item, 0)) < 1:
		_hold(pid, "")

func _on_local_inventory_changed() -> void:
	if not root._is_client:
		_recheck(_local_id())

## A late joiner learns what the players inside its AOI hold.
func _on_player_joined(peer_id: int, _player_id: String, _reconnected: bool) -> void:
	if root._is_client or root._networking == null:
		return
	var out := {}
	for pid in _held:
		var peer := _peer_of(str(pid))
		if peer != 0 and peer != peer_id:
			out[peer] = _held[pid]
	if not out.is_empty():
		root._networking.send_peer_held_to(peer_id, out)

func _on_player_left(player_id: String) -> void:
	_held.erase(player_id)
	_stamps.erase(player_id)

# ---------------------------------------------------------------------------
# Client (and the listen host's view of its clients)
# ---------------------------------------------------------------------------

func _on_peer_synced(peer_id: int, item_id: String) -> void:
	if not root._is_client:
		return
	_show(peer_id, item_id)

## Show `item_id` on peer `peer_id`'s avatar; the host's own body is peer 1 and a client's own body its unique id.
func _show(peer_id: int, item_id: String) -> void:
	if root._character == null:
		return
	_pending[peer_id] = item_id
	_apply_pending()

func _avatar_of(peer_id: int) -> String:
	var own: int = 1 if not root._is_client else (root.multiplayer.get_unique_id() if root.is_inside_tree() else 0)
	if peer_id == own:
		return root._character.get_player_character()
	return root._character.get_peer_character(peer_id)

func _apply_pending() -> void:
	for peer in _pending.keys():
		var iid := _avatar_of(int(peer))
		if iid == "":
			continue
		var stamp := "%s|%s" % [iid, _pending[peer]]
		if _applied.get(peer, "") != stamp:
			_applied[peer] = stamp
			root._character.set_held_item(iid, str(_pending[peer]))

func _forget_peer(peer_id: int) -> void:
	_pending.erase(peer_id)
	_applied.erase(peer_id)

func tick(_delta: float) -> void:
	if root._character != null and not _pending.is_empty():
		_apply_pending()
