extends "res://src/tests/test_support.gd"
## Phase 222 — the Character window (Attributes + Equipment, Phase 214) fits its frame, and the friend
## code and spawn notice live in the map window, which fits too.

const VIEWPORTS := [Vector2(1280, 720), UiSlice.MIN_VIEWPORT_SIZE]
const LOCALES := ["en", "pt_BR"]

func register() -> void:
	_run_test("character window: the minimum viewport is the project's base size", _test_min_viewport_is_project_size)
	_run_test("character window: at 1280x720 and the minimum size every control lies inside the window and viewport, or a scroll", _test_fits)
	_run_test("character window: the fit check flags a long label outside the scroll", _test_check_catches_overflow)
	_run_test("character window: the friend code, its Copy button and the spawn notice are in the map window, not the Character window", _test_friend_code_in_map)
	_run_test("character window: the map window, friend code, Copy and spawn notice lie inside the viewport at 1280x720 and the minimum size", _test_map_fits)
	_run_test("character window: attributes and the doll stay outside the scroll; respawn and build-as share one row", _test_layout_parts)

## Lay a container tree out now: no frames elapse in the suite, so the deferred sorts never run.
func _lay_out(c: Control) -> void:
	if c is Container:
		c.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in c.get_children():
		if child is Control:
			_lay_out(child)

## Open `key` the way the game does (which fits it on screen), then lay it out at its real size.
func _open_sized(ui: UiSlice, key: String, viewport: Vector2) -> Control:
	ui.viewport_size_override = viewport
	ui.refresh_character()
	ui.open_window(key)
	var panel: Control = ui._panels[key]
	_lay_out(panel)
	return panel

func _in_scroll(c: Control, panel: Control) -> bool:
	var p := c.get_parent()
	while p != null and p != panel:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false

## The visible controls of `panel`, outside every scroll container, whose rect leaves the part of the
## window that is on screen (the window's rect clipped to the viewport).
func _outside(panel: Control, viewport: Vector2) -> Array:
	var frame := panel.get_global_rect().intersection(Rect2(Vector2.ZERO, viewport)).grow(0.5)
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

func _on_screen(c: Control, viewport: Vector2) -> bool:
	return Rect2(Vector2.ZERO, viewport).grow(0.5).encloses(c.get_global_rect())

func _test_min_viewport_is_project_size() -> void:
	var base := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width", 1152),
		ProjectSettings.get_setting("display/window/size/viewport_height", 648))
	assert_eq(UiSlice.MIN_VIEWPORT_SIZE, base, "MIN_VIEWPORT_SIZE is the project's viewport size")

func _test_fits() -> void:
	for locale in LOCALES:
		TranslationServer.set_locale(locale)
		for viewport: Vector2 in VIEWPORTS:
			for key in [UiSlice.WINDOW_ATTRIBUTES, UiSlice.WINDOW_EQUIPMENT]:
				var ui := _new_hud_ui()
				var panel := _open_sized(ui, key, viewport)
				var where := "%s at %s (%s)" % [key, str(viewport), locale]
				assert_true(_on_screen(panel, viewport), "%s: the window %s lies inside the viewport" % [where, str(panel.get_global_rect())])
				var bad := _outside(panel, viewport)
				assert_true(bad.is_empty(), "%s: every child lies inside the window or a scroll, outside: %s" % [where, str(bad)])
				ui.free()
	TranslationServer.set_locale("en")

func _test_check_catches_overflow() -> void:
	var ui := _new_hud_ui()
	var long := Label.new()
	long.text = "x".repeat(400)
	ui._sheet_attributes.get_parent().add_child(long)   # beside the attributes, outside the scroll
	var panel := _open_sized(ui, UiSlice.WINDOW_ATTRIBUTES, UiSlice.MIN_VIEWPORT_SIZE)
	assert_false(_on_screen(panel, UiSlice.MIN_VIEWPORT_SIZE), "the window no longer fits the viewport")
	assert_false(_outside(panel, UiSlice.MIN_VIEWPORT_SIZE).is_empty(), "the check reports the label")
	ui.free()

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

func _test_map_fits() -> void:
	const Registry := preload("res://src/persistence/player_registry.gd")
	for locale in LOCALES:
		TranslationServer.set_locale(locale)
		for viewport: Vector2 in VIEWPORTS:
			for handle in ["", Registry.HANDLE_PREFIX + "0123456789abcdef".substr(0, Registry.HANDLE_HEX_CHARS)]:
				var ui := _new_hud_ui()
				ui.set_own_handle(handle)
				ui._on_spawn_notice(UiSlice.I18n.t("ui.friend_code", ["x".repeat(20)]).repeat(4))
				var panel := _open_sized(ui, UiSlice.WINDOW_MAP, viewport)
				var where := "map at %s (%s, handle '%s')" % [str(viewport), locale, handle]
				assert_true(_on_screen(panel, viewport), "%s: the window %s lies inside the viewport" % [where, str(panel.get_global_rect())])
				for c: Control in [ui._friend_code_label, ui._friend_code_copy, ui._spawn_notice_label]:
					assert_true(_on_screen(c, viewport), "%s: %s %s lies inside the viewport" % [where, c.get_class(), str(c.get_global_rect())])
				var bad := _outside(panel, viewport)
				assert_true(bad.is_empty(), "%s: every child lies inside the window, outside: %s" % [where, str(bad)])
				ui.free()
	TranslationServer.set_locale("en")

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
