extends Node
## Entry point — delegates to game_root which owns all vertical slices.

const GameRoot := preload("res://src/core/game_root.gd")

func _ready() -> void:
	_spawn_root("")

## Phase 223 — a join started from the main menu failed: the root that tried it (its slices are built
## for a client) is dropped and a fresh one opens the menu with the reason. The new root takes the same
## name, because the RPC paths are `/root/Node/GameRoot/...`.
func _spawn_root(notice_key: String) -> void:
	var root := GameRoot.new()
	root.name = "GameRoot"
	root._menu_wiring.notice = notice_key
	root.menu_return_requested.connect(func(reason_key: String) -> void:
		_back_to_menu.call_deferred(root, reason_key))
	add_child(root)

func _back_to_menu(old: Node, reason_key: String) -> void:
	if is_instance_valid(old):
		old._menu_wiring.close()
		remove_child(old)
		old.queue_free()
	_spawn_root(reason_key)
