extends "res://src/tests/test_support.gd"
## Phase 220 — Enter never jumps: the `jump` action is Space (and a pad's south button) only, the player slice
## reads it instead of the GUI accept action, the controls legend shows its binding from the action map, and
## Enter on the floor opens chat without starting a jump while Space jumps.

const UiSliceScript := preload("res://src/ui/ui_slice.gd")
const InputLabels := preload("res://src/ui/input_labels.gd")
const PlayerSliceScript := preload("res://src/player/player_slice.gd")
const ChatSliceScript := preload("res://src/chat/chat_slice.gd")

func register() -> void:
	_run_test("jump: the jump action is Space only, never Enter, and the player slice reads it", _test_jump_action_binding)
	_run_test("jump: the controls legend shows the jump binding from the action map", _test_jump_controls_row)
	_run_test("jump: the jump key names come from the catalog (pt_BR reads Espaço)", _test_jump_key_names_localized)
	_run_test("jump: Enter on the floor opens chat and starts no jump; Space jumps", _test_enter_opens_chat_space_jumps)

func _key_event(code: Key, pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	return ev

## Feed a key to the Input singleton and apply it now (no frame elapses in the suite).
func _feed(code: Key, pressed: bool) -> InputEventKey:
	var ev := _key_event(code, pressed)
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	return ev

func _test_jump_action_binding() -> void:
	assert_true(InputMap.has_action("jump"), "project.godot declares a jump action")
	assert_eq(PlayerSliceScript.JUMP_ACTION, "jump", "the player slice reads the jump action")
	var has_space := false
	for ev in InputMap.action_get_events("jump"):
		if ev is InputEventKey:
			var code: Key = ev.keycode if ev.keycode != KEY_NONE else ev.physical_keycode
			has_space = has_space or code == KEY_SPACE
			assert_true(code != KEY_ENTER and code != KEY_KP_ENTER, "jump is not bound to Enter or Keypad Enter")
	assert_true(has_space, "jump is bound to Space")
	assert_true(InputMap.action_has_event("jump", _key_event(KEY_SPACE, true)), "a Space press matches jump")
	assert_false(InputMap.action_has_event("jump", _key_event(KEY_ENTER, true)), "an Enter press does not match jump")
	assert_false(InputMap.action_has_event("jump", _key_event(KEY_KP_ENTER, true)), "a Keypad Enter press does not match jump")
	var src := FileAccess.get_file_as_string("res://src/player/player_slice.gd")
	assert_true(src.length() > 0, "the player slice source is readable")
	assert_false(src.contains("ui_accept"), "player_slice.gd no longer reads ui_accept")

func _test_jump_controls_row() -> void:
	assert_eq(InputLabels.action_keys("jump"), "Space", "the jump action's key reads Space")
	assert_eq(InputLabels.action_keys("no_such_action"), "", "an unknown action has no keys")
	var found := false
	for row in UiSliceScript.controls_rows():
		if str(row["action"]) == "jump":
			found = true
			assert_eq(str(row["keys"]), InputLabels.action_keys("jump"), "the jump row shows the action map's binding")
	assert_true(found, "the legend has a jump row")

func _test_jump_key_names_localized() -> void:
	TranslationServer.set_locale("en")
	assert_eq(InputLabels.action_keys("jump", true), "Space · Pad A", "with the pad, jump reads Space and the south button")
	TranslationServer.set_locale("pt_BR")
	var row_keys := ""
	for row in UiSliceScript.controls_rows():
		if str(row["action"]) == "jump":
			row_keys = str(row["keys"])
	var pad := InputLabels.action_keys("jump", true)
	var other := InputLabels.key_name(KEY_F7)
	TranslationServer.set_locale("en")
	assert_eq(row_keys, "Espaço", "the pt_BR jump row reads Espaço")
	assert_eq(pad, "Espaço · Botão A do controle", "and the pad button is named in Portuguese")
	assert_eq(other, OS.get_keycode_string(KEY_F7), "a key with no catalog row falls back to the OS name")

## `PlayerSlice._move` starts a jump through `jump_starts`, so these calls exercise the live jump check.
func _test_enter_opens_chat_space_jumps() -> void:
	var chat := ChatSliceScript.new()
	add_child(chat)
	var focus := chat.get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()
	assert_false(chat.is_typing(), "no field is focused before Enter")

	# Enter: the key reaches the action system (the GUI accept action sees it) and chat, but no jump starts.
	var enter := _feed(KEY_ENTER, true)
	if not chat.is_typing():
		chat._input(enter)   # the suite has no window to route the event; deliver it as the viewport would
	assert_true(Input.is_action_pressed("ui_accept"), "Enter is delivered (it still drives GUI buttons)")
	assert_false(Input.is_action_pressed("jump"), "Enter does not press jump")
	assert_false(PlayerSliceScript.jump_starts(true, false, false, false), "Enter with the character on the floor starts no jump")
	assert_true(chat.is_typing(), "Enter gives the chat field focus")
	_feed(KEY_ENTER, false)
	chat._close_input()
	assert_false(chat.is_typing(), "chat closes")

	# Space with no field focused jumps.
	_feed(KEY_SPACE, true)
	assert_true(Input.is_action_pressed("jump"), "Space presses jump")
	assert_true(PlayerSliceScript.jump_starts(true, false, false, false), "Space with the character on the floor starts a jump")
	assert_false(PlayerSliceScript.jump_starts(false, false, false, false), "but not in the air")
	assert_false(PlayerSliceScript.jump_starts(true, true, false, false), "nor while flying")
	assert_false(PlayerSliceScript.jump_starts(true, false, true, false), "nor while swimming")
	assert_false(PlayerSliceScript.jump_starts(true, false, false, true), "nor held by the creation screen")
	_feed(KEY_SPACE, false)
	assert_false(Input.is_action_pressed("jump"), "releasing Space releases jump")
	chat.free()
