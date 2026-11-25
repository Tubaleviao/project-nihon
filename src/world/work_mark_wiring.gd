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

func _connect_all() -> void:
	connect_bus(GameBus.work_mark_changed, on_mark_changed)
	connect_bus(GameBus.work_mark_synced, on_mark_synced)

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
