extends "res://src/tests/test_support.gd"
## Phase 219 — a focused text field owns the keyboard: no reversed text, and no movement, jumps, hotbar keys or
## window shortcuts while a LineEdit / TextEdit has focus. Keys go through `Input` (so polled state is real) and
## are dispatched to the viewport like a real key, which also reaches the focused field.

const WS := preload("res://src/ui/window_shortcuts.gd")

func register() -> void:
	_run_test("text focus: a click at column 0 then 'hello' typed into chat reads hello, caret at 5", _test_chat_typing)
	_run_test("text focus: every text field swallows W/A/S/D, Space, a hotbar digit and Alt+A", _test_fields_swallow_keys)
	_run_test("text focus: with no field focused the same keys move, jump, pick a slot and open a window", _test_no_focus_regression)
	_run_test("text focus: movement held when a field takes focus stops and stays stopped until re-pressed", _test_held_movement_stops)

func _key(code: int, pressed: bool, unicode: int = 0, alt: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	e.unicode = unicode if pressed else 0
	e.alt_pressed = alt
	return e

## Feed one key through `Input` and dispatch it now (no frames elapse in the suite).
func _send(e: InputEvent) -> void:
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func _press(code: int, unicode: int = 0, alt: bool = false) -> void:
	_send(_key(code, true, unicode, alt))

func _release(code: int, alt: bool = false) -> void:
	_send(_key(code, false, 0, alt))

## W, A, S, D and Space held, then the digit 2 and Alt+A tapped.
func _feed_world_keys() -> void:
	for k in [[KEY_W, 119], [KEY_A, 97], [KEY_S, 115], [KEY_D, 100], [KEY_SPACE, 32]]:
		_press(k[0], k[1])
	_press(KEY_2, 50)
	_release(KEY_2)
	_press(KEY_ALT, 0, true)
	_press(KEY_A, 0, true)
	_release(KEY_A, true)
	_release(KEY_ALT)

func _release_all() -> void:
	for k in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_2, KEY_ALT]:
		_release(k)
	WS.clear_consumed()

func _windows(ui: UiSlice) -> Dictionary:
	var out := {}
	for w in UiSlice.WINDOW_KEYS:
		out[w] = ui.is_window_open(w)
	return out

func _new_chat() -> ChatSlice:
	var chat := ChatSlice.new()
	chat.admins_path = "user://does_not_exist_admins.json"
	add_child(chat)
	return chat

func _test_chat_typing() -> void:
	var chat := _new_chat()
	var f: LineEdit = chat._field
	assert_true(f != null and f.is_inside_tree(), "the chat field is built")
	# A left click at the field's left edge (column 0), in canvas coordinates.
	var rect := f.get_global_rect()
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = rect.position + Vector2(1.0, rect.size.y * 0.5)
		click.global_position = click.position
		get_viewport().push_input(click, true)
	assert_true(f.has_focus(), "the click gives the field the keyboard")
	assert_eq(f.caret_column, 0, "the caret is at column 0")
	assert_true(UiSlice.is_typing(), "UiSlice.is_typing() sees the focused field")
	for ch in "hello":
		var code := OS.find_keycode_from_string(ch.to_upper())
		get_viewport().push_input(_key(code, true, ch.unicode_at(0)), true)
		get_viewport().push_input(_key(code, false), true)
		# LineEdit emits text_changed deferred, after the key: with no frames, emit it here as the engine would.
		f.text_changed.emit(f.text)
	assert_eq(f.text, "hello", "the word reads forward")
	assert_eq(f.caret_column, 5, "the caret follows the typing")
	# The /msg limit switch (the one max_length change) keeps the caret too.
	f.text = "/msg bob hi"
	f.caret_column = 4
	f.text_changed.emit(f.text)
	assert_eq(f.max_length, ChatSlice.field_limit("/msg bob hi"), "a private line takes the longer limit")
	assert_eq(f.caret_column, 4, "and the caret stays where it was")
	# Esc still leaves the field.
	_press(KEY_ESCAPE)
	_release(KEY_ESCAPE)
	assert_false(f.has_focus(), "Esc leaves the field")
	assert_false(UiSlice.is_typing(), "and nothing is typing")
	chat.free()

## Every text field, focused in turn, with its window open: [label, window to open or "", field getter].
func _fields(ui: UiSlice, chat: ChatSlice) -> Array:
	return [
		["chat", "", func() -> Control: return chat._field],
		["clan", UiSlice.WINDOW_CLAN, func() -> Control: return ui.clan_panel._name_edit],
		["chest", UiSlice.WINDOW_CHEST, func() -> Control:
			# A chest that holds items shows its item row (no view hides it).
			ui.chest_panel.source = func() -> Dictionary: return { "type": "chest", "mode": "public", "owner": true, "items": {} }
			ui.chest_panel.refresh()
			return ui.chest_panel._item_edit],
		["settlement", UiSlice.WINDOW_SETTLEMENT, func() -> Control: return ui.settlement_panel._target_edit],
		["map rename", UiSlice.WINDOW_MAP, func() -> Control:
			var e: LineEdit = ui.map_window.rename_field()
			e.visible = true
			return e],
		["market qty", UiSlice.WINDOW_MARKET, func() -> Control: return ui._market_qty],
		["market price", UiSlice.WINDOW_MARKET, func() -> Control: return ui._market_price],
		["proposal title", UiSlice.WINDOW_PROPOSALS, func() -> Control: return ui._proposal_title],
		["proposal body", UiSlice.WINDOW_PROPOSALS, func() -> Control: return ui._proposal_body],
		["creation name", "creation", func() -> Control:
			ui.show_creation()
			return ui.creation_screen._name],
	]

func _test_fields_swallow_keys() -> void:
	WS.clear_consumed()
	var ui := _new_hud_ui()
	var chat := _new_chat()
	var player := PlayerSlice.new()
	for row in _fields(ui, chat):
		var label: String = row[0]
		var window: String = row[1]
		if window != "" and window != "creation":
			ui.open_window(window)
		var field: Control = (row[2] as Callable).call()
		assert_true(field != null, "%s: the field exists" % label)
		if field == null:
			continue
		assert_true(field.is_visible_in_tree(), "%s: the field is on screen" % label)
		field.grab_focus()
		assert_true(field.has_focus(), "%s: the field takes focus" % label)
		assert_true(UiSlice.is_typing(), "%s: UiSlice.is_typing()" % label)
		var windows_before := _windows(ui)
		var slot_before: int = ui.hotbar.selected
		_feed_world_keys()
		assert_true(Input.is_key_pressed(KEY_W), "%s: W really is held" % label)
		assert_eq(player.wish_direction(), Vector3.ZERO, "%s: the wish direction stays zero" % label)
		assert_false(player.jump_requested(), "%s: no jump starts" % label)
		assert_false(player.world_input_allowed(), "%s: no world action (or mouse-look) starts" % label)
		assert_eq(ui.hotbar.selected, slot_before, "%s: the hotbar slot is unchanged" % label)
		assert_eq(_windows(ui), windows_before, "%s: no window opens or closes" % label)
		_release_all()
		_press(KEY_ESCAPE)
		_release(KEY_ESCAPE)
		assert_false(field.has_focus(), "%s: Esc leaves the field" % label)
		assert_false(UiSlice.is_typing(), "%s: and nothing is typing" % label)
		field.release_focus()
		if window == "creation":
			ui.hide_creation()
		elif window != "":
			ui.close_window(window)
	assert_false(UiSlice.is_typing(), "no field is left focused")
	player.free()
	chat.free()
	ui.free()

func _test_no_focus_regression() -> void:
	WS.clear_consumed()
	var ui := _new_hud_ui()
	var player := PlayerSlice.new()
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()
	assert_false(UiSlice.is_typing(), "no field is focused")
	_press(KEY_W, 119)
	assert_eq(player.wish_direction(), Vector3(0, 0, -1), "W walks forward")
	_press(KEY_D, 100)
	assert_eq(player.wish_direction(), Vector3(1, 0, -1), "W+D walks diagonally")
	_press(KEY_SPACE, 32)
	assert_true(player.jump_requested(), "Space starts a jump")
	assert_true(player.world_input_allowed(), "world actions resolve")
	_press(KEY_2, 50)
	_release(KEY_2)
	assert_eq(ui.hotbar.selected, 1, "the digit 2 picks the second slot")
	_release_all()
	_press(KEY_ALT, 0, true)
	_press(KEY_A, 0, true)
	_release(KEY_A, true)
	_release(KEY_ALT)
	assert_true(ui.is_window_open(UiSlice.WINDOW_ATTRIBUTES), "Alt+A opens Attributes")
	_release_all()
	player.free()
	ui.free()

func _test_held_movement_stops() -> void:
	WS.clear_consumed()
	var chat := _new_chat()
	var player := PlayerSlice.new()
	_press(KEY_W, 119)
	assert_eq(player.wish_direction(), Vector3(0, 0, -1), "W held walks")
	chat.open_input()
	assert_true(UiSlice.is_typing(), "Enter's chat box has the keyboard")
	assert_eq(player.wish_direction(), Vector3.ZERO, "the walk stops the moment the field takes focus")
	chat._close_input()
	assert_false(UiSlice.is_typing(), "the field is closed")
	assert_eq(player.wish_direction(), Vector3.ZERO, "W still held from before the typing does not walk again")
	_release(KEY_W)
	assert_eq(player.wish_direction(), Vector3.ZERO, "W released")
	_press(KEY_W, 119)
	assert_eq(player.wish_direction(), Vector3(0, 0, -1), "a fresh W press walks")
	_release_all()
	player.free()
	chat.free()
