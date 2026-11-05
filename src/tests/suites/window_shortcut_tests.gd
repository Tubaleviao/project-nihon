extends "res://src/tests/test_support.gd"
## Phase 214 — window shortcuts are Alt + a letter, from one table.

const WindowShortcuts := preload("res://src/ui/window_shortcuts.gd")
const _Dock := preload("res://src/ui/window_dock.gd")

func register() -> void:
	_run_test("shortcuts: every table row opens its window from Alt+key and a second press closes it; bare keys open nothing", _test_rows_toggle)
	_run_test("shortcuts: Alt+E is the inventory (no equipment toggle), Alt+Q is Equipment, Alt+G is the clan", _test_conflicts)
	_run_test("shortcuts: Ctrl+Alt and a focused text field open nothing, and an Option character still matches on keycode", _test_modifiers_and_focus)
	_run_test("shortcuts: no window letter outside the table; dock and controls rows come from it; one row per window", _test_audit)
	_run_test("shortcuts: a hotbar box takes a freed letter and refuses an Alt+letter", _test_hotbar)
	_run_test("shortcuts: Attributes lists every attribute and derived stat, Equipment every slot", _test_split_windows)

func _key(code: int, alt: bool, ctrl: bool = false, unicode: int = 0) -> InputEventKey:
	var e := InputEventKey.new()
	e.pressed = true
	e.keycode = code
	e.alt_pressed = alt
	e.ctrl_pressed = ctrl
	e.unicode = unicode
	return e

func _test_rows_toggle() -> void:
	var ui := _new_hud_ui()
	ui.is_admin = true
	for row: Dictionary in WindowShortcuts.TABLE:
		var w := str(row["window"])
		var code := int(row["keycode"])
		assert_true(UiSlice.WINDOW_KEYS.has(w), "%s is a window" % w)
		ui._input(_key(code, false))
		assert_false(ui.is_window_open(w), "the bare key opens no %s window" % w)
		ui._input(_key(code, true))
		assert_true(ui.is_window_open(w), "Alt+%s opens %s" % [OS.get_keycode_string(code), w])
		ui._input(_key(code, true))
		assert_false(ui.is_window_open(w), "a second press closes %s" % w)
	ui.free()

func _test_conflicts() -> void:
	var ui := _new_hud_ui()
	var toggles: Array = []
	var cb := func() -> void: toggles.append(1)
	GameBus.character_equipment_toggle_requested.connect(cb)
	ui._input(_key(KEY_E, true))
	assert_true(ui.is_window_open("inventory"), "Alt+E opens the inventory")
	assert_eq(toggles.size(), 0, "and does not strip the gear (the UI marks the event handled; PlayerSlice ignores Alt)")
	ui._input(_key(KEY_Q, true))
	assert_true(ui.is_window_open("equipment"), "Alt+Q opens Equipment")
	assert_false(ui.is_window_open("gestures"), "and not the gesture wheel")
	ui._input(_key(KEY_G, true))
	assert_true(ui.is_window_open("clan"), "Alt+G opens the clan window")
	GameBus.character_equipment_toggle_requested.disconnect(cb)
	var ps := PlayerSlice.new()
	var before := toggles.size()
	GameBus.character_equipment_toggle_requested.connect(cb)
	ps._unhandled_input(_key(KEY_E, true))
	assert_eq(toggles.size(), before, "PlayerSlice ignores Alt+E")
	ps._unhandled_input(_key(KEY_E, false))
	assert_eq(toggles.size(), before + 1, "and still toggles on a bare E")
	GameBus.character_equipment_toggle_requested.disconnect(cb)
	ps.free()
	ui.free()

func _test_modifiers_and_focus() -> void:
	var ui := _new_hud_ui()
	ui._input(_key(KEY_A, true, true))
	assert_false(ui.is_window_open("attributes"), "Ctrl+Alt+A opens nothing")
	ui._input(_key(KEY_A, true, false, 0x00E5))   # macOS Option+A types "å"
	assert_true(ui.is_window_open("attributes"), "an Option character still matches on keycode")
	ui._input(_key(KEY_A, true))
	assert_false(ui.is_window_open("attributes"), "closed again")
	if ui.is_inside_tree():
		var line := LineEdit.new()
		ui.add_child(line)
		line.grab_focus()
		if ui.get_viewport().gui_get_focus_owner() == line:
			ui._input(_key(KEY_S, true))
			assert_false(ui.is_window_open("skills"), "Alt+S while typing opens nothing")
		line.free()
	ui.free()

func _test_audit() -> void:
	var seen_keys := {}
	var seen_windows := {}
	for row: Dictionary in UiSlice.WINDOW_SHORTCUTS:
		assert_false(seen_keys.has(row["keycode"]), "no two rows share a key")
		assert_false(seen_windows.has(row["window"]), "one row per window: %s" % row["window"])
		seen_keys[row["keycode"]] = true
		seen_windows[row["window"]] = true
	for w in UiSlice.WINDOW_KEYS:
		if w in [UiSlice.WINDOW_CONTROLS, UiSlice.WINDOW_GESTURES, UiSlice.WINDOW_CHEST]:
			assert_false(seen_windows.has(w), "%s has no Alt row" % w)
		else:
			assert_true(seen_windows.has(w), "%s has a shortcut row" % w)
	for e in _Dock.entries():
		var key := str(e["key"])
		var want := WindowShortcuts.label_of(key)
		assert_eq(_Dock.chip(key), want if want != "" else "?", "the dock chip of %s comes from the table" % key)
	# the `?` row lists the table
	var windows_row := {}
	for r in UiSlice.controls_rows():
		if r["action"] == "windows":
			windows_row = r
	assert_eq(str(windows_row.get("keys", "")), WindowShortcuts.all_labels(), "the controls row is built from the table")
	# no window letter matched in the key handlers
	for path in ["res://src/ui/ui_slice.gd", "res://src/ui/window_dock.gd", "res://src/ui/ui_part_1.gd", "res://src/ui/ui_part_2.gd"]:
		var src := FileAccess.get_file_as_string(path)
		for row: Dictionary in UiSlice.WINDOW_SHORTCUTS:
			var name := "KEY_" + OS.get_keycode_string(int(row["keycode"]))
			var re := RegEx.create_from_string("\\b%s\\s*:" % name)
			assert_true(re.search(src) == null, "%s: no `match` arm on %s outside the table" % [path, name])
		assert_true(src.find("\"letter\"") == -1, "%s: no hard-coded dock letter" % path)

func _test_hotbar() -> void:
	var HB := preload("res://src/ui/hotbar.gd")
	for k in [KEY_I, KEY_K, KEY_C, KEY_H, KEY_M, KEY_P, KEY_L, KEY_O, KEY_J]:
		assert_true(HB.free_key(k), "freed letter %d" % k)
	for k in [KEY_W, KEY_R, KEY_B, KEY_E, KEY_G, KEY_Q]:
		assert_false(HB.free_key(k), "still reserved: %d" % k)
	var hb := HB.new()
	hb.begin_binding(HB.COLUMNS)
	assert_true(hb.handle_key(_key(KEY_A, true)), "an Alt+letter is swallowed while binding")
	assert_true(hb.is_binding(), "and binds nothing")
	assert_true(hb.handle_key(_key(KEY_I, false)), "a bare freed letter binds")
	assert_false(hb.is_binding(), "binding ended")
	assert_eq(hb.binds[HB.COLUMNS], KEY_I, "the first second-row box is I")
	hb.free()

func _test_split_windows() -> void:
	var ui := _new_hud_ui()
	ui.refresh_character()
	var rows: Array = ui.character_sheet_rows()
	var attrs := rows.filter(func(r): return str(r["section"]) == "attribute").size()
	assert_eq(attrs, 6, "Attributes lists the six attributes")
	assert_true(ui._panels[UiSlice.WINDOW_ATTRIBUTES].is_ancestor_of(ui._sheet_stats), "derived stats live in Attributes")
	assert_true(ui._panels[UiSlice.WINDOW_EQUIPMENT].is_ancestor_of(ui._sheet_doll), "the doll lives in Equipment")
	assert_true(ui._panels[UiSlice.WINDOW_EQUIPMENT].is_ancestor_of(ui._character_grid), "the slots live in Equipment")
	assert_false(ui._panels[UiSlice.WINDOW_ATTRIBUTES].is_ancestor_of(ui._sheet_doll), "and not in Attributes")
	ui.free()
