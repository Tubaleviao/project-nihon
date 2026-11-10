extends RefCounted
## Phase 223/224 — the game's root swap, out of `main.gd` so the suite can drive it (#599).
##
## `main.gd` holds one `GameRoot`. When it asks to return to the main menu (a join started from the menu
## failed, or the player chose Exit to main menu, Phase 224), the old root is closed (its connection
## dropped), taken out of the tree and freed, and a fresh one opens the main menu with the reason.
## The fresh root takes the same name, because the RPC paths are `/root/Node/GameRoot/...`.

const GameRoot := preload("res://src/core/game_root.gd")

## Add a new `GameRoot` to `parent`. `to_menu` makes it open the main menu whatever the process was launched
## with (a `--client` boot that exits to the menu must not rejoin), and `notice_key` is shown there.
static func spawn_root(parent: Node, notice_key: String, to_menu: bool = false) -> GameRoot:
	var root := GameRoot.new()
	root.name = "GameRoot"
	root._menu_wiring.notice = notice_key
	if to_menu:
		root._menu_wiring.boot_args_override = []
	root.menu_return_requested.connect(func(reason_key: String) -> void:
		back_to_menu.call_deferred(parent, root, reason_key))
	parent.add_child(root)
	return root

## Drop `old` (closed, out of the tree, freed now: this runs deferred, never inside the old root's own call) and
## open the main menu on a fresh root under `parent`. Returns the fresh root.
static func back_to_menu(parent: Node, old: Node, reason_key: String) -> GameRoot:
	if is_instance_valid(old):
		old._menu_wiring.close()
		if old.get_parent() == parent:
			parent.remove_child(old)
		old.free()
	return spawn_root(parent, reason_key, true)
