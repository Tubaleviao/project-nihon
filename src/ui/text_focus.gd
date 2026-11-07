extends RefCounted
## Phase 219 — the ONE query for "a text field has the keyboard" (exposed as `UiSlice.is_typing()`).
##
## True while any `LineEdit` or `TextEdit` in the game window holds focus: chat, clan, chest, settlement, map
## rename, market, proposal, creation name. While it is true no world input reaches the game (movement, jump,
## fly, hotbar keys, window shortcuts, mouse-look). Kept apart from `ui_slice.gd` so the player slice and the
## minimap can ask without preloading the whole UI.

## Reads the root viewport's focus only: a field inside an embedded Window or a SubViewport is not seen.
static func is_typing() -> bool:
	return _field() != null

## Esc leaves the field: releases the focused text field. True when there was one.
static func leave() -> bool:
	var f := _field()
	if f == null:
		return false
	f.release_focus()
	return true

static func _field() -> Control:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	var focus := tree.root.gui_get_focus_owner()
	return focus if (focus is LineEdit or focus is TextEdit) else null
