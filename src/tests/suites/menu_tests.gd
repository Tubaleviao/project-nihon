extends "res://src/tests/test_support.gd"
## Phase 223 — the main menu: a boot with no boot user args opens it and builds no world, every CI flag
## skips it, local worlds are created, listed and deleted (with a confirmation), the Join form validates
## its input and remembers servers, and a join started from the menu that fails asks to return to it.
## The socket half (a client started from the menu's join path connects) is the net harness `menu_join`.

const GameRoot := preload("res://src/core/game_root.gd")
const MainMenu := preload("res://src/menu/main_menu.gd")
const MenuWiring := preload("res://src/menu/menu_wiring.gd")
const LocalWorlds := preload("res://src/menu/local_worlds.gd")
const RecentServers := preload("res://src/menu/recent_servers.gd")
const I18n := preload("res://src/core/i18n.gd")

const FRIEND := "p_0123456789abcdef"

func register() -> void:
	_run_test("menu: a boot with no args shows the main menu and builds no world", _test_no_args_boot_shows_menu)
	_run_test("menu: every CI boot flag skips the menu", _test_ci_flags_skip_menu)
	_run_test("menu: create, list and delete a local world in a temp folder", _test_local_worlds)
	_run_test("menu: the Play page creates, confirms a delete and plays a world", _test_play_page)
	_run_test("menu: the Join form validates and remembers recent servers", _test_join_form)
	_run_test("menu: a menu choice sets the boot role; a bad one is refused", _test_apply_choice)
	_run_test("menu: a failed join from the menu asks to return to it, a --client one does not", _test_join_failed_returns)
	_run_test("menu: every menu key is in both catalog columns", _test_catalog)
	_run_test("menu: the game version parses as major.minor.patch and shows in the corner", _test_version)

func _temp_dir(tag: String) -> String:
	var dir := "user://test_menu_%s_%d/" % [tag, randi()]
	DirAccess.make_dir_recursive_absolute(dir)
	return dir

func _remove(dir: String) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_remove(dir.path_join(sub))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)

func _test_no_args_boot_shows_menu() -> void:
	var locale := TranslationServer.get_locale()
	var root: GameRoot = GameRoot.new()
	root._menu_wiring.boot_args_override = []
	add_child(root)
	var menu: MainMenu = root._menu_wiring.menu
	assert_true(menu != null and menu.is_inside_tree(), "the main menu is shown")
	if menu != null:
		assert_eq(menu.page(), MainMenu.PAGE_HOME, "it opens on the home page")
		assert_true(not menu.options_enabled(), "Options is greyed until Phase 225")
	assert_true(root._terrain == null and root._chunk_manager == null and root._persistence == null and root._player == null,
		"no world slice is built")
	assert_eq(root.get_child_count(), 1, "the menu is the root's only child")
	assert_true(not root.is_processing() and not root.is_physics_processing(), "the root does not tick under the menu")
	root.free()
	TranslationServer.set_locale(locale)

func _test_ci_flags_skip_menu() -> void:
	assert_true(MenuWiring.should_show_main_menu([]), "no args → menu")
	assert_true(MenuWiring.should_show_main_menu(["--no-native"]), "a dev flag alone is not a boot flag")
	for flag in ["--server", "--client", "--run-tests", "--quit-after-boot", "--playtest-bot", "--net-harness", "--friend"]:
		assert_true(not MenuWiring.should_show_main_menu([flag]), "%s skips the menu" % flag)
	assert_true(not MenuWiring.should_show_main_menu(["--no-native", "--quit-after-boot"]), "a boot flag anywhere skips it")
	assert_true(not MenuWiring.should_show_main_menu(["--net-harness", "client"]), "the harness skips it")
	# This suite itself runs under `--run-tests`, so the real args never open a menu here.
	var w := MenuWiring.new()
	assert_true(not MenuWiring.should_show_main_menu(w.boot_user_args()), "the suite's own boot skips the menu")

func _test_local_worlds() -> void:
	var base := _temp_dir("worlds")
	var legacy := _temp_dir("legacy")
	var a := LocalWorlds.create(base, "  My World ", "42", 100)
	assert_true(bool(a["ok"]), "a world is created")
	assert_eq(str(a.get("id", "")), "my-world", "its folder is a slug of the name")
	assert_eq(int(a.get("seed", 0)), 42, "an integer seed is kept")
	var b := LocalWorlds.create(base, "My World", "nihon", 200)
	assert_eq(str(b.get("id", "")), "my-world-2", "a second world of the same name gets its own folder")
	assert_eq(int(b.get("seed", 0)), "nihon".hash() & LocalWorlds.SEED_MAX, "a text seed is a stable hash")
	assert_eq(str(LocalWorlds.create(base, "Big", "2147483648", 0).get("error", "")), "menu.world.error_seed", "a seed past int32 is refused")
	assert_eq(str(LocalWorlds.create(base, "Huge", "99999999999999999999", 0).get("error", "")), "menu.world.error_seed", "a seed past int64 is refused")
	assert_eq(int(LocalWorlds.create(base, "Low", "-2147483648", 0).get("seed", 0)), LocalWorlds.SEED_MIN, "int32's lowest seed is kept")
	assert_true(LocalWorlds.delete(base, "low"), "(fixture removed)")
	for i in 3:
		var r: Variant = LocalWorlds.parse_seed("")
		assert_eq(int(r), LocalWorlds.fabric_seed(), "a blank seed is the one fabric seed (Phase 238)")
	assert_eq(LocalWorlds.fabric_seed(), 238, "the fabric seed is WorldSystem.worldSeed")
	var w1 := LocalWorlds.create(base, "Same1", "", 0)
	var w2 := LocalWorlds.create(base, "Same2", "", 0)
	assert_eq(int(w1.get("seed", -1)), int(w2.get("seed", -2)), "two new worlds share the seed")
	LocalWorlds.delete(base, str(w1.get("id", "")))
	LocalWorlds.delete(base, str(w2.get("id", "")))
	assert_eq(str(LocalWorlds.create(base, "   ", "", 0).get("error", "")), "menu.world.error_name", "a blank name is refused")
	assert_eq(str(LocalWorlds.create(base, "x".repeat(LocalWorlds.NAME_MAX + 1), "", 0).get("error", "")), "menu.world.error_name", "an overlong name is refused")
	assert_eq(str(LocalWorlds.create(base, "Ok", "9".repeat(65), 0).get("error", "")), "menu.world.error_seed", "an overlong seed is refused")
	assert_eq(str(LocalWorlds.create(base, "a\nb", "", 0).get("error", "")), "menu.world.error_name", "a control character is refused")
	var list := LocalWorlds.list(base, "")
	assert_eq(list.size(), 2, "both worlds are listed")
	LocalWorlds.touch(str(a["dir"]), 500)
	list = LocalWorlds.list(base, "")
	assert_eq(str(list[0]["id"]), "my-world", "the world played last is first")
	assert_eq(str(list[0]["name"]), "My World", "the name is listed trimmed")
	assert_eq(int(list[0]["seed"]), 42, "the seed is listed")
	assert_eq(int(list[0]["last_played"]), 500, "last played is listed")
	assert_true(MainMenu.world_row_text(list[0]).contains("My World"), "the row reads the name")
	assert_eq(MainMenu.world_row_text(list[1]), I18n.t("menu.world.row_never", ["My World", str("nihon".hash() & LocalWorlds.SEED_MAX)]),
		"a world never played reads its own line, not a date")
	# A meta whose seed is not an int32 (a hand-edited file) is not listed.
	DirAccess.make_dir_recursive_absolute(base + "badseed")
	var bs := FileAccess.open(base + "badseed/meta.json", FileAccess.WRITE)
	bs.store_string(JSON.stringify({ "name": "Bad seed", "seed": 1.0e15, "last_played": 0 }))
	bs.close()
	assert_eq(LocalWorlds.list(base, "").size(), 2, "a world whose seed is past int32 is not listed")
	# A folder without a meta, or with a name that is not one, is not a world.
	DirAccess.make_dir_recursive_absolute(base + "stray")
	DirAccess.make_dir_recursive_absolute(base + "Bad Name")
	assert_eq(LocalWorlds.list(base, "").size(), 2, "a stray folder is not listed")
	# The pre-menu save is listed (read-only) when it holds a world record.
	var f := FileAccess.open(legacy + "world.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({ "seed": 7, "timestamp": 50 }))
	f.close()
	list = LocalWorlds.list(base, legacy)
	assert_eq(list.size(), 3, "the legacy save is listed")
	var legacy_rows := list.filter(func(e: Dictionary) -> bool: return bool(e["legacy"]))
	assert_true(legacy_rows.size() == 1 and int(legacy_rows[0]["seed"]) == 7, "with its recorded seed")
	assert_true(not LocalWorlds.delete(base, LocalWorlds.LEGACY_ID), "the legacy save cannot be deleted")
	assert_true(not LocalWorlds.delete(base, "../outside"), "a path outside the base is refused")
	assert_true(not LocalWorlds.delete(base, "stray"), "a folder that is not a world is refused")
	# Delete removes the folder and everything in it (a world's save sits beside its meta).
	DirAccess.make_dir_recursive_absolute(str(b["dir"]) + "regions")
	var r := FileAccess.open(str(b["dir"]) + "regions/r.0.0.json", FileAccess.WRITE)
	r.store_string("{}")
	r.close()
	assert_true(LocalWorlds.delete(base, "my-world-2"), "a world is deleted")
	assert_true(not DirAccess.dir_exists_absolute(base + "my-world-2"), "its folder is gone")
	list = LocalWorlds.list(base, "")
	assert_eq(list.size(), 1, "one world is left")
	assert_eq(str(list[0]["id"]), "my-world", "the other one")
	_remove(base)
	_remove(legacy)

func _test_play_page() -> void:
	var base := _temp_dir("play")
	var menu: MainMenu = MainMenu.new()
	menu.worlds_base = base
	menu.legacy_dir = ""
	add_child(menu)
	var chosen: Array = []
	menu.start_requested.connect(func(c: Dictionary) -> void: chosen.append(c))
	menu.show_page(MainMenu.PAGE_PLAY)
	assert_eq(menu._pages[MainMenu.PAGE_PLAY].find_children("*", "LineEdit", true, false).size(), 1, "the New world dialog has only a name field, no seed (Phase 238)")
	assert_true(bool(menu.create_world("Alpha", "11")["ok"]), "New world creates one")
	assert_true(not bool(menu.create_world("", "")["ok"]), "and refuses a blank name")
	assert_eq(menu.worlds().size(), 1, "the list shows it")
	menu.request_delete("alpha")
	assert_eq(menu.page(), MainMenu.PAGE_CONFIRM, "Delete asks for a confirmation first")
	assert_eq(menu.worlds().size(), 1, "nothing is removed before it is confirmed")
	menu.cancel_delete()
	assert_eq(menu.page(), MainMenu.PAGE_PLAY, "Cancel goes back to the list")
	assert_eq(menu.worlds().size(), 1, "and keeps the world")
	assert_true(menu.play_world("alpha"), "Play on a listed world")
	assert_eq(chosen.size(), 1, "asks the root to boot it")
	if chosen.size() == 1:
		assert_eq(str(chosen[0]["mode"]), "host", "as the listen host")
		assert_eq(str(chosen[0]["dir"]), base + "alpha/", "on that world's folder")
		assert_eq(int(chosen[0]["seed"]), 11, "with its seed")
	menu.request_delete("alpha")
	assert_true(menu.confirm_delete(), "a confirmed delete removes it")
	assert_eq(menu.worlds().size(), 0, "the list is empty")
	assert_true(not menu.play_world("alpha"), "a deleted world cannot be played")
	menu.free()
	_remove(base)

func _test_join_form() -> void:
	assert_eq(str(MainMenu.join_choice("", "").get("error", "")), "menu.join.error_address", "an empty address is refused")
	assert_eq(str(MainMenu.join_choice("http://host", "").get("error", "")), "menu.join.error_address", "a URL is refused")
	assert_eq(str(MainMenu.join_choice("a b", "").get("error", "")), "menu.join.error_address", "whitespace is refused")
	assert_eq(str(MainMenu.join_choice("127.0.0.1", "nope").get("error", "")), "menu.join.error_friend", "a malformed friend code is refused")
	var ok := MainMenu.join_choice(" 127.0.0.1 ", FRIEND)
	assert_true(bool(ok["ok"]) and str(ok["address"]) == "127.0.0.1" and str(ok["friend"]) == FRIEND, "a good address and code pass, trimmed")
	var dir := _temp_dir("recent")
	var path := dir + "recent.json"
	assert_eq(RecentServers.load_list(path), [], "no file → no recent servers")
	RecentServers.remember("a.example", "", path, 1)
	RecentServers.remember("b.example", FRIEND, path, 2)
	var list := RecentServers.remember("a.example", "", path, 3)
	assert_eq(list.size(), 2, "a server is remembered once")
	assert_eq(str(RecentServers.load_list(path)[0]["address"]), "a.example", "the latest is first")
	for i in 12:
		RecentServers.remember("h%d.example" % i, "", path, 10 + i)
	assert_eq(RecentServers.load_list(path).size(), RecentServers.MAX_ENTRIES, "the list is capped")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({ "servers": [{ "address": "ok.example" }, { "address": "bad/one" }, { "address": "x", "friend": "evil" }, 5] }))
	f.close()
	var read := RecentServers.load_list(path)
	assert_eq(read.size(), 1, "entries that would not pass the form are dropped on read")
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("not json")
	f.close()
	assert_eq(RecentServers.load_list(path), [], "a corrupt file reads as empty")
	# The menu's own form.
	var menu: MainMenu = MainMenu.new()
	menu.recent_path = path
	menu.legacy_dir = ""
	add_child(menu)
	var chosen: Array = []
	menu.start_requested.connect(func(c: Dictionary) -> void: chosen.append(c))
	assert_eq(menu.request_join("", ""), "menu.join.error_address", "the form shows the error")
	assert_eq(chosen.size(), 0, "and boots nothing")
	assert_eq(menu.request_join("10.0.0.5", ""), "", "a good address")
	assert_true(chosen.size() == 1 and str(chosen[0]["mode"]) == "join" and str(chosen[0]["address"]) == "10.0.0.5", "asks the root to join it")
	assert_eq(str(RecentServers.load_list(path)[0]["address"]), "10.0.0.5", "and remembers it")
	menu.free()
	_remove(dir)

func _test_apply_choice() -> void:
	var root: GameRoot = GameRoot.new()
	var w: MenuWiring = root._menu_wiring
	assert_true(w.apply_choice({ "mode": "join", "address": "10.0.0.2", "friend": FRIEND }), "a join choice is applied")
	assert_true(root._is_client and not root._is_server, "as a client")
	assert_eq(root._host_address, "10.0.0.2", "of that address")
	assert_eq(root._friend_code_arg, FRIEND, "with the friend code")
	root._is_client = false
	assert_true(not w.apply_choice({ "mode": "join", "address": "evil host" }), "a bad address is refused at the root too")
	assert_true(not root._is_client, "and changes nothing")
	assert_true(not w.apply_choice({ "mode": "host", "dir": "user://../outside/" }), "a host folder escaping user:// is refused")
	assert_true(not w.apply_choice({ "mode": "host", "dir": "res://fabric/" }), "a non-user:// folder is refused")
	assert_true(not w.apply_choice({ "mode": "other" }), "an unknown mode is refused")
	assert_true(w.apply_choice({ "mode": "host", "dir": "user://worlds/alpha/", "seed": 9 }), "a host choice is applied")
	assert_true(not root._is_client and not root._is_server, "as the listen host")
	assert_eq(w.world, { "dir": "user://worlds/alpha/", "seed": 9 }, "on that world")
	root.free()

func _test_join_failed_returns() -> void:
	var root: GameRoot = GameRoot.new()
	var w: MenuWiring = root._menu_wiring
	var seen: Array = []
	root.menu_return_requested.connect(func(k: String) -> void: seen.append(k))
	root._is_client = true
	w.join_failed("menu.join.fail_unreachable")
	assert_eq(seen, [], "a --client boot (not from the menu) stays where it is")
	w.from_menu = true
	w.join_failed("menu.join.fail_unreachable")
	assert_eq(seen, ["menu.join.fail_unreachable"], "a join from the menu returns to it with the reason")
	w.join_failed("menu.join.fail_disconnected")
	assert_eq(seen.size(), 1, "once")
	root.free()
	# The reason is shown on the fresh menu's home page.
	var menu: MainMenu = MainMenu.new()
	menu.legacy_dir = ""
	add_child(menu)
	menu.show_notice("menu.join.fail_unreachable")
	assert_eq(menu.notice_text(), I18n.t("menu.join.fail_unreachable"), "the menu shows the localized reason")
	menu.free()

func _test_catalog() -> void:
	var cats: Dictionary = I18n.parse_csv("res://locale/ui.csv")["catalog"]
	var keys := ["menu.title", "menu.play", "menu.join", "menu.options", "menu.quit", "menu.world.new",
		"menu.world.delete_confirm", "menu.world.error_name", "menu.world.error_seed", "menu.world.error_write",
		"menu.join.error_address", "menu.join.error_friend", "menu.join.fail_connect", "menu.join.fail_unreachable",
		"menu.join.fail_disconnected", "menu.join.fail_timeout", "menu.world.legacy_name", "menu.world.row", "menu.world.row_never", "menu.version"]
	for loc in ["en", "pt_BR"]:
		for k in keys:
			assert_true((cats.get(loc, {}) as Dictionary).has(k), "%s has %s" % [loc, k])

## Phase 255 — `application/config/version` parses as major.minor.patch and the menu shows it; with no version
## the label is hidden. The format rule is tools/check_changelog.sh's: the test reads the same pattern and
## fails if the script's copy drifts.
const SEMVER_RE := "^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$"

func _test_version() -> void:
	var v := MainMenu.game_version()
	var script := FileAccess.get_file_as_string("res://tools/check_changelog.sh")
	if script != "":   # an export does not carry tools/
		assert_true(script.contains(SEMVER_RE), "check_changelog.sh enforces the same major.minor.patch rule")
	var semver := RegEx.create_from_string(SEMVER_RE)
	assert_true(semver.search(v) != null, "application/config/version is major.minor.patch: %s" % v)
	for bad in ["", "1.0", "v0.1.0", "0.1.0-rc1", "01.0.0", "1.0.0.0"]:
		assert_true(semver.search(bad) == null, "%s is refused" % bad)
	assert_eq(MainMenu.version_label_text(""), "", "no version: no dangling label text")
	assert_true(MainMenu.version_label_text("9.8.7").contains("9.8.7"), "a version is named in the label")
	var menu: MainMenu = MainMenu.new()
	menu.worlds_base = _temp_dir("version")
	menu.legacy_dir = ""
	add_child(menu)
	assert_true(menu.version_text().contains(v), "the corner label names the version: %s" % menu.version_text())
	var base := menu.worlds_base
	menu.free()
	_remove(base)
