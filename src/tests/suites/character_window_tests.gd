extends "res://src/tests/test_support.gd"
## Phase 222 — the Character window (Attributes + Equipment, Phase 214) fits its frame, and the friend
## code and spawn notice live in the map window.

func register() -> void:
	_run_test("character window: at 1280x720 and the minimum size every control lies inside the window or a scroll container", _test_fits)
	_run_test("character window: the friend code, its Copy button and the spawn notice are in the map window, not the Character window", _test_friend_code_in_map)
	_run_test("character window: attributes and the doll stay outside the scroll; respawn and build-as share one row", _test_layout_parts)

## Lay a container tree out now: no frames elapse in the suite, so the deferred sorts never run.
func _lay_out(c: Control) -> void:
	if c is Container:
		c.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in c.get_children():
		if child is Control:
			_lay_out(child)

func _open_sized(ui: UiSlice, key: String, viewport: Vector2) -> Control:
	ui.viewport_size_override = viewport
	ui.refresh_character()
	ui.open_window(key)
	var panel: Control = ui._panels[key]
	panel.reset_size()
	_lay_out(panel)
	return panel

func _in_scroll(c: Control, panel: Control) -> bool:
	var p := c.get_parent()
	while p != null and p != panel:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false

## The controls of `panel` whose rect leaves the window's rect, outside every scroll container.
func _outside(panel: Control) -> Array:
	var frame := panel.get_global_rect().grow(0.5)
	var out := []
	var stack: Array = panel.get_children()
	while not stack.is_empty():
		var c = stack.pop_back()
		if not (c is Control) or not c.visible:
			continue
		if _in_scroll(c, panel):
			continue
		if not frame.encloses(c.get_global_rect()):
			out.append("%s %s" % [c.get_class(), str(c.get_global_rect())])
		stack.append_array(c.get_children())
	return out

func _test_fits() -> void:
	for locale in ["en", "pt_BR"]:
		TranslationServer.set_locale(locale)
		for viewport: Vector2 in [Vector2(1280, 720), UiSlice.MIN_VIEWPORT_SIZE]:
			for key in [UiSlice.WINDOW_ATTRIBUTES, UiSlice.WINDOW_EQUIPMENT]:
				var ui := _new_hud_ui()
				var panel := _open_sized(ui, key, viewport)
				var where := "%s at %s (%s)" % [key, str(viewport), locale]
				assert_true(Rect2(Vector2.ZERO, viewport).encloses(panel.get_global_rect()),
					"%s: the window %s lies inside the viewport" % [where, str(panel.get_global_rect())])
				var bad := _outside(panel)
				assert_true(bad.is_empty(), "%s: every child lies inside the window or a scroll, outside: %s" % [where, str(bad)])
				ui.free()
	TranslationServer.set_locale("en")

func _test_friend_code_in_map() -> void:
	var ui := _new_hud_ui()
	var map: Control = ui._panels[UiSlice.WINDOW_MAP]
	var sheet: Control = ui._panels[UiSlice.WINDOW_ATTRIBUTES]
	var equipment: Control = ui._panels[UiSlice.WINDOW_EQUIPMENT]
	assert_true(ui._friend_code_label != null and map.is_ancestor_of(ui._friend_code_label), "the friend code is in the map window")
	assert_true(ui._friend_code_copy != null and map.is_ancestor_of(ui._friend_code_copy), "its Copy button is in the map window")
	assert_true(ui._spawn_notice_label != null and map.is_ancestor_of(ui._spawn_notice_label), "the spawn notice is in the map window")
	for window: Control in [sheet, equipment]:
		assert_false(window.is_ancestor_of(ui._friend_code_label), "the friend code is not in the Character window")
		assert_false(window.is_ancestor_of(ui._friend_code_copy), "nor its Copy button")
		assert_false(window.is_ancestor_of(ui._spawn_notice_label), "nor the spawn notice")
	ui.free()

func _test_layout_parts() -> void:
	var ui := _new_hud_ui()
	var panel := _open_sized(ui, UiSlice.WINDOW_ATTRIBUTES, Vector2(1280, 720))
	assert_true(ui._sheet_attributes.get_child_count() > 0, "the attributes are listed")
	assert_false(_in_scroll(ui._sheet_attributes, panel), "the attributes are not in the scroll")
	assert_true(_in_scroll(ui._sheet_stats, panel), "the derived stats are in the scroll")
	assert_true(_in_scroll(ui._sheet_specialty, panel), "the specialty is in the scroll")
	var row: Control = ui._sheet_own_row
	assert_eq(row.get_child_count(), 3, "respawn, build private and build clan")
	for b in row.get_children():
		assert_true(b is Button, "each is a button in the one row")
	var eq := _open_sized(ui, UiSlice.WINDOW_EQUIPMENT, Vector2(1280, 720))
	assert_false(_in_scroll(ui._sheet_doll, eq), "the doll is not in a scroll")
	assert_true(eq.get_global_rect().grow(0.5).encloses(ui._sheet_doll.get_global_rect()), "the doll is in view")
	ui.free()
