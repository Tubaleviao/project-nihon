extends "res://src/core/wiring.gd"
## #629 — the work marks (crack on a worked block, shake on a chopped tree) replicated to every player in range.
##
## Host: `WorkHost` emits `work_mark_changed(player_id, key, duration)` when a session starts on a new target and when
## it ends. The host draws the mark itself (a listen host has a view) and sends `{ key, duration }` to the peers in
## range of the worker, the same AOI as the worker's work animation (`work_anim`). Client: `work_mark_synced` from
## that packet is validated by `WorkMarks` and drawn. A dedicated server draws nothing.

const WorkMarksView := preload("res://src/world/work_marks_view.gd")

## The view, made on the first mark this process draws (never on a dedicated server). Null until then.
var view: WorkMarksView = null
## Host: how many marks it sent to peers (the suite reads it).
var sent := 0
## #714 — peer -> the mark key that peer works, where this machine knows it: every hold on the host (from
## `work_mark_changed`), the local player's own on a client (from `work_started`). A strike takes that mark.
var peer_keys: Dictionary = {}

func _connect_all() -> void:
	connect_bus(GameBus.work_mark_changed, on_mark_changed)
	connect_bus(GameBus.work_mark_synced, on_mark_synced)
	connect_bus(GameBus.work_strike, on_work_strike)
	connect_bus(GameBus.work_started, _on_own_work_started)
	connect_bus(GameBus.peer_disconnected, func(peer: int) -> void: peer_keys.erase(peer))

func unwire() -> void:
	super.unwire()
	if view != null and is_instance_valid(view):
		if root != null and root._rebase != null:
			root._rebase.targets.erase(view)
		if view.get_parent() != null:
			view.get_parent().remove_child(view)
		view.free()
	view = null

## Host: a session on `key` started (`duration` > 0) or ended (0) for `player_id` ("" or the local id: this machine's
## player, peer 1).
func on_mark_changed(player_id: String, key: String, duration: float) -> void:
	if root._is_client:
		return
	_note_peer_key(_peer_of(player_id), key, duration)
	_draw(key, duration)
	if root._networking == null or not root._networking.is_host():
		return
	var at: Variant = _worker_position(player_id)
	if at == null:
		return
	root._networking._m2.send_work_mark(key, duration, at)
	sent += 1

## Client: the host's mark. Anything malformed is dropped by `WorkMarks`.
func on_mark_synced(key: String, duration: float) -> void:
	if not root._is_client:
		return
	_draw(key, duration)

## The local player's work answer names its target: its strikes take that mark.
func _on_own_work_started(key: String, duration: float, _action: String, _material: String) -> void:
	_note_peer_key(_local_peer(), key, duration)

func _note_peer_key(peer: int, key: String, duration: float) -> void:
	if peer <= 0:
		return
	if duration > 0.0:
		peer_keys[peer] = key
	elif str(peer_keys.get(peer, "")) == key:
		peer_keys.erase(peer)

func _local_peer() -> int:
	return root.multiplayer.get_unique_id() if root._is_client and root.is_inside_tree() else 1

## The peer of `player_id` on the host: 1 for this machine's own player, 0 when unknown.
func _peer_of(player_id: String) -> int:
	if player_id == "" or player_id == "player" or root._registry == null or player_id == root._registry.local_player_id:
		return 1
	return int(root._registry.get_peer_id(player_id))

## #714 — a body's work clip reached its impact marker: the mark nearest that body takes the beat (crack step,
## tree kick, chips). Nothing to do before this machine has drawn a mark.
func on_work_strike(peer: int, kind: String) -> void:
	if view == null or not is_instance_valid(view) or root._work_anim_wiring == null:
		return
	var at: Variant = root._work_anim_wiring.body_position(peer)
	if at is Vector3:
		view.strike(at, kind, str(peer_keys.get(peer, "")))

func _draw(key: String, duration: float) -> void:
	var v := ensure_view()
	if v != null:
		v.apply(key, duration)

## The view, made on first use; null on a dedicated server or before the root is in the tree.
func ensure_view() -> WorkMarksView:
	if view != null and is_instance_valid(view):
		return view
	if root._is_server or not root.is_inside_tree():
		return null
	view = WorkMarksView.new()
	view.name = "WorkMarks"
	view.tree_slice = root._tree
	root.add_child(view)
	if root._rebase != null:
		root._rebase.targets.append(view)
	return view

## Where the worker stands (the AOI centre), or null when the host has no position for it.
func _worker_position(player_id: String) -> Variant:
	if player_id == "" or player_id == "player" or player_id == root._registry.local_player_id:
		return root._player.get_position() if root._player != null else null
	var peer: int = root._registry.get_peer_id(player_id)
	if peer > 0 and root._networking.has_last_known_state(peer):
		return root._networking.get_last_known_state(peer)
	return null
