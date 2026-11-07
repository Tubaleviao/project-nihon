extends RefCounted
## Phase 219 — the ONE query for "a text field has the keyboard" (exposed as `UiSlice.is_typing()`).
##
## True while any `LineEdit` or `TextEdit` in the game window holds focus: chat, clan, chest, settlement, map
## rename, market, proposal, creation name. While it is true no world input reaches the game (movement, jump,
## fly, hotbar keys, window shortcuts, mouse-look). Kept apart from `ui_slice.gd` so the player slice and the
## minimap can ask without preloading the whole UI.

static func is_typing() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	var focus := tree.root.gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit
