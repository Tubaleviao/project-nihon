extends "res://src/tests/test_support.gd"
## Phase 224 — the Esc menu: Esc leaves a field, then closes the top window, then opens the menu (Resume, Options,
## Exit to main menu, Quit game), and again closes it; world input holds while it is up. Exit to main menu on a
## listen host saves and swaps in a fresh root on the main menu (`RootSwap`, out of `main.gd`). And the #599 notes:
## one address rule, explored maps per world folder. The menu join over a socket is the net harness `menu_join`.

const WS := preload("res://src/ui/window_shortcuts.gd")
const GameRoot := preload("res://src/core/game_root.gd")
const RootSwap := preload("res://src/menu/root_swap.gd")
const MainMenu := preload("res://src/menu/main_menu.gd")
const MenuWiring := preload("res://src/menu/menu_wiring.gd")
const LocalWorlds := preload("res://src/menu/local_worlds.gd")
const RecentServers := preload("res://src/menu/recent_servers.gd")
const BootWiring := preload("res://src/core/boot_wiring.gd")
const PauseMenu := preload("res://src/ui/pause_menu.gd")
const I18n := preload("res://src/core/i18n.gd")

func register() -> void:
	_run_test("pause: Esc closes a window, then opens the menu, then closes it", _test_esc_sequence)
	_run_test("pause: Esc closes the top window only, the one opened last", _test_esc_top_window)
	_run_test("pause: while the menu is up world input holds and hotkeys stay quiet", _test_menu_freezes_input)
	_run_test("pause: Resume, Exit and Quit buttons; Options greyed until Phase 225", _test_buttons)
	_run_test("pause: Exit to main menu on a listen host saves and leaves only the main menu", _test_exit_on_listen_host)
	_run_test("pause: the root swap frees the old root and opens the menu on a fresh GameRoot", _test_root_swap)
	_run_test("pause: --client parsing and the Join form share one address rule", _test_one_address_rule)
	_run_test("pause: two local worlds with one seed keep separate explored maps", _test_explored_map_per_world)
	_run_test("pause: --menu-join opens the menu (it is not a skip flag)", _test_menu_join_arg)
	_run_test("pause: every Esc menu key is in both catalog columns", _test_catalog)

func _key(code: int, pressed: bool, unicode: int = 0, alt: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	e.unicode = unicode if pressed else 0
	e.alt_pressed = alt
	return e

func _send(e: InputEvent) -> void:
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func _tap(code: int, unicode: int = 0) -> void:
	_send(_key(code, true, unicode))
	_send(_key(code, false))

func _no_focus() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()

func _temp_dir(tag: String) -> String:
	var dir := "user://test_pause_%s_%d/" % [tag, randi()]
	DirAccess.make_dir_recursive_absolute(dir)
	return dir

func _remove(dir: String) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_remove(dir.path_join(sub))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)

func _test_esc_sequence() -> void:
	WS.clear_consumed()
	_no_focus()
	var ui := _new_hud_ui()
	ui.open_window(UiSlice.WINDOW_INVENTORY)
	assert_true(ui.is_window_open(UiSlice.WINDOW_INVENTORY), "a window is open")
	_tap(KEY_ESCAPE)
	assert_false(ui.is_window_open(UiSlice.WINDOW_INVENTORY), "Esc closes it")
	assert_false(ui.is_pause_menu_open(), "and opens no menu")
	_tap(KEY_ESCAPE)
	assert_true(ui.is_pause_menu_open(), "Esc again opens the menu")
	assert_true(ui.pause_menu.is_inside_tree() and ui.pause_menu.visible, "the menu is shown")
	_tap(KEY_ESCAPE)
	assert_false(ui.is_pause_menu_open(), "and Esc once more closes it")
	# A text field is left before anything else: the menu does not open while one had the keyboard.
	var field := LineEdit.new()
	ui.add_child(field)
	field.grab_focus()
	_tap(KEY_ESCAPE)
	assert_false(field.has_focus(), "Esc leaves the field")
	assert_false(ui.is_pause_menu_open(), "and does not open the menu")
	field.free()
	ui.free()

func _test_esc_top_window() -> void:
	WS.clear_consumed()
	_no_focus()
	var ui := _new_hud_ui()
	ui.open_window(UiSlice.WINDOW_INVENTORY)
	ui.open_window(UiSlice.WINDOW_CRAFTING)
	ui.open_window(UiSlice.WINDOW_SKILLS)
	ui.close_window(UiSlice.WINDOW_SKILLS)
	_tap(KEY_ESCAPE)
	assert_false(ui.is_window_open(UiSlice.WINDOW_CRAFTING), "Esc closes the window opened last that is still open")
	assert_true(ui.is_window_open(UiSlice.WINDOW_INVENTORY), "and leaves the one under it")
	ui.open_window(UiSlice.WINDOW_CRAFTING)
	ui.open_window(UiSlice.WINDOW_INVENTORY)   # re-opening brings it to the top
	_tap(KEY_ESCAPE)
	assert_false(ui.is_window_open(UiSlice.WINDOW_INVENTORY), "a window opened again is the top one")
	assert_true(ui.is_window_open(UiSlice.WINDOW_CRAFTING), "the other stays")
	_tap(KEY_ESCAPE)
	assert_false(ui.any_window_open(), "the last window closes")
	assert_false(ui.is_pause_menu_open(), "still no menu")
	ui.free()

func _test_menu_freezes_input() -> void:
	WS.clear_consumed()
	_no_focus()
	var ui := _new_hud_ui()
	var player := PlayerSlice.new()
	ui.player_slice = player
	var toggles: Array = []
	var on_toggle := func(open: bool) -> void: toggles.append(open)
	GameBus.pause_menu_toggled.connect(on_toggle)
	_tap(KEY_ESCAPE)
	assert_true(ui.is_pause_menu_open(), "the menu is open")
	assert_true(player.pause_hold, "the body holds")
	var slot_before: int = ui.hotbar.selected
	for k in [[KEY_W, 119], [KEY_A, 97], [KEY_S, 115], [KEY_D, 100], [KEY_SPACE, 32]]:
		_send(_key(k[0], true, k[1]))
	assert_true(Input.is_key_pressed(KEY_W), "W really is held")
	assert_eq(player.wish_direction(), Vector3.ZERO, "the wish direction stays zero")
	assert_false(player.jump_requested(), "no jump starts")
	assert_false(player.world_input_allowed(), "no world action (or mouse-look) starts")
	_tap(KEY_2, 50)
	assert_eq(ui.hotbar.selected, slot_before, "a hotbar digit picks no slot")
	_send(_key(KEY_ALT, true, 0, true))
	_send(_key(KEY_A, true, 0, true))
	_send(_key(KEY_A, false, 0, true))
	_send(_key(KEY_ALT, false))
	assert_false(ui.any_window_open(), "Alt+A opens no window")
	for k in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE]:
		_send(_key(k, false))
	WS.clear_consumed()
	_tap(KEY_ESCAPE)
	assert_false(ui.is_pause_menu_open(), "Esc closes the menu")
	assert_false(player.pause_hold, "the body is free again")
	assert_true(player.world_input_allowed(), "world actions resolve again")
	assert_eq(toggles, [true, false], "the bus heard it open and close")
	GameBus.pause_menu_toggled.disconnect(on_toggle)
	player.free()
	ui.free()

func _test_buttons() -> void:
	_no_focus()
	var ui := _new_hud_ui()
	var seen: Array = []
	var on_exit := func() -> void: seen.append("exit")
	var on_quit := func() -> void: seen.append("quit")
	GameBus.exit_to_menu_requested.connect(on_exit)
	GameBus.quit_game_requested.connect(on_quit)
	ui.open_pause_menu()
	var m: PauseMenu = ui.pause_menu
	assert_false(m.options_enabled(), "Options is greyed until Phase 225")
	m.button("resume").pressed.emit()
	assert_false(ui.is_pause_menu_open(), "Resume closes the menu")
	ui.open_pause_menu()
	m.button("exit_menu").pressed.emit()
	assert_false(ui.is_pause_menu_open(), "Exit closes the menu")
	ui.open_pause_menu()
	m.button("quit").pressed.emit()
	assert_eq(seen, ["exit", "quit"], "Exit and Quit ask through the bus")
	GameBus.exit_to_menu_requested.disconnect(on_exit)
	GameBus.quit_game_requested.disconnect(on_quit)
	ui.free()

## A listen host booted from the main menu on a temp world, then Exit to main menu: the world record is on disk
## and the parent holds one fresh GameRoot whose only child is the main menu.
func _test_exit_on_listen_host() -> void:
	var base := _temp_dir("exit")
	var made: Dictionary = LocalWorlds.create(base, "Exit", "4242")
	assert_true(bool(made["ok"]), "a temp world")
	var parent := Node.new()
	add_child(parent)
	var root: GameRoot = RootSwap.spawn_root(parent, "", true)
	for c in root.menu_return_requested.get_connections():   # no frames: the swap is driven by hand below
		root.menu_return_requested.disconnect(c["callable"])
	var asked: Array = []
	root.menu_return_requested.connect(func(k: String) -> void: asked.append(k))
	assert_true(root._menu_wiring.menu != null, "the main menu is up")
	var first_menu: Node = root._menu_wiring.menu
	root._menu_wiring.start({ "mode": "host", "dir": str(made["dir"]), "seed": int(made["seed"]) })
	if is_instance_valid(first_menu):
		first_menu.free()   # `start` queue_frees the menu that asked (it is still in its own signal); no frame comes here
	assert_true(root._persistence != null and not root._is_client, "a listen host world is built")
	assert_eq(root._persistence.server_save_dir, str(made["dir"]), "on the chosen world")
	var world_file: String = str(made["dir"]).path_join("world.json")
	DirAccess.remove_absolute(world_file)
	GameBus.exit_to_menu_requested.emit()
	assert_true(FileAccess.file_exists(world_file), "Exit to main menu wrote the world record")
	assert_eq(asked, [""], "and asked for the main menu, with no notice")
	GameBus.exit_to_menu_requested.emit()
	assert_eq(asked.size(), 1, "a second Exit does nothing")
	var fresh: GameRoot = RootSwap.back_to_menu(parent, root, "")
	assert_false(is_instance_valid(root), "the world's root is freed")
	assert_eq(parent.get_child_count(), 1, "one root is left")
	assert_eq(str(fresh.name), "GameRoot", "named GameRoot (the RPC path)")
	assert_true(fresh._menu_wiring.menu != null and fresh._menu_wiring.menu.is_inside_tree(), "the main menu is shown")
	assert_eq(fresh.get_child_count(), 1, "and it is the fresh root's only child: no world nodes left")
	assert_true(fresh._terrain == null and fresh._persistence == null, "no world slice is built")
	parent.free()
	_remove(base)

func _test_root_swap() -> void:
	var parent := Node.new()
	add_child(parent)
	var old: GameRoot = RootSwap.spawn_root(parent, "", true)
	for c in old.menu_return_requested.get_connections():
		old.menu_return_requested.disconnect(c["callable"])
	var fresh: GameRoot = RootSwap.back_to_menu(parent, old, "menu.join.fail_unreachable")
	assert_false(is_instance_valid(old), "the old root is freed")
	assert_eq(parent.get_children(), [fresh], "the fresh root replaces it")
	assert_eq(str(fresh.name), "GameRoot", "under the same name")
	assert_eq(fresh._menu_wiring.notice, "menu.join.fail_unreachable", "with the reason")
	var menu: MainMenu = fresh._menu_wiring.menu
	assert_true(menu != null, "on the main menu")
	if menu != null:
		assert_eq(menu.notice_text(), I18n.t("menu.join.fail_unreachable"), "which shows the reason")
	assert_eq(fresh.menu_return_requested.get_connections().size(), 1, "the fresh root can return to the menu too")
	# A returning root opens the menu whatever the process was launched with (a --client boot must not rejoin).
	assert_eq(fresh._menu_wiring.boot_args_override, [], "it boots as if with no args")
	parent.free()

func _test_one_address_rule() -> void:
	var was_quiet := Diag.quiet
	Diag.quiet = true
	var long_host := "a".repeat(RecentServers.ADDRESS_MAX + 1)
	for addr in ["127.0.0.1", "example.org", "::1", "host-1.local", "10.0.0.2:7777", "", "http://x", "a/b", "a b",
			"a\tb", "-lead", ".dot", long_host, "a".repeat(RecentServers.ADDRESS_MAX)]:
		var valid := RecentServers.valid_address(addr)
		assert_eq(BootWiring.client_address(addr) == addr, valid, "--client agrees on '%s'" % addr.left(20))
		assert_eq(bool(MainMenu.join_choice(addr, "")["ok"]), valid, "the Join form agrees on '%s'" % addr.left(20))
	assert_eq(BootWiring.client_address("http://x"), "127.0.0.1", "a bad --client address falls back to localhost")
	Diag.quiet = was_quiet
	var src := FileAccess.get_file_as_string("res://src/core/boot_wiring.gd")
	assert_false(src.contains("RegEx"), "boot_wiring keeps no address rule of its own")

func _test_explored_map_per_world() -> void:
	var base := _temp_dir("revealed")
	var a: Dictionary = LocalWorlds.create(base, "Alpha", "777")
	var b: Dictionary = LocalWorlds.create(base, "Beta", "777")
	assert_eq(int(a["seed"]), int(b["seed"]), "two worlds, one seed")
	var dirs: Array = []
	for w in [a, b]:
		var root: GameRoot = GameRoot.new()
		root._persistence = PersistenceSlice.new()
		root._terrain = TerrainSlice.new()
		root._minimap = Minimap.new()
		root._menu_wiring.world = { "dir": str(w["dir"]), "seed": int(w["seed"]) }
		root._menu_wiring.apply_world()
		dirs.append(root._minimap.revealed_dir)
		root._minimap.free()
		root._terrain.free()
		root._persistence.free()
		root.free()
	assert_true(dirs[0] != dirs[1], "each world has its own explored-map folder")
	assert_true(str(dirs[0]).begins_with(str(a["dir"]).trim_suffix("/")), "inside the world's folder")
	var seed_v := int(a["seed"])
	assert_true(_RevealedStore.save(_RevealedStore.path_for(dirs[0], seed_v), [Vector2i(1, 2), Vector2i(3, 4)], seed_v), "Alpha explores")
	assert_eq(_RevealedStore.load_file(_RevealedStore.path_for(dirs[0], seed_v), seed_v).size(), 2, "Alpha's map reloads")
	assert_eq(_RevealedStore.load_file(_RevealedStore.path_for(dirs[1], seed_v), seed_v), [], "Beta's map is still empty")
	assert_eq(MenuWiring.revealed_dir_for(PersistenceSlice.DEFAULT_SERVER_SAVE_DIR), MenuWiring.SHARED_REVEALED_DIR,
		"the pre-menu save keeps the shared folder")
	_remove(base)

func _test_menu_join_arg() -> void:
	assert_true(MenuWiring.should_show_main_menu([MenuWiring.MENU_JOIN_ARG, "127.0.0.1"]), "--menu-join boots the menu")
	assert_eq(MenuWiring.menu_join_address([MenuWiring.MENU_JOIN_ARG, "10.0.0.2"]), "10.0.0.2", "and reads its address")
	assert_eq(MenuWiring.menu_join_address([]), "", "no flag, no join")
	assert_eq(MenuWiring.menu_join_address([MenuWiring.MENU_JOIN_ARG]), "", "a flag with no address, no join")

func _test_catalog() -> void:
	var cats: Dictionary = I18n.parse_csv("res://locale/ui.csv")["catalog"]
	for key in ["pause.title", "pause.resume", "pause.options", "pause.exit_menu", "pause.quit", "menu.options_soon"]:
		for loc in ["en", "pt_BR"]:
			assert_true(cats.has(loc) and str((cats[loc] as Dictionary).get(key, "")) != "", "%s has %s" % [loc, key])
