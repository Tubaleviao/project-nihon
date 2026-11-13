extends "res://src/core/wiring.gd"
## Phase 223 — the main menu's glue: whether a boot opens it, what its choice sets on the root, and the
## way back to it when a join started from it fails. `root` is the GameRoot that owns the slices.
##
## A boot with none of MENU_SKIP_ARGS (a player launching the game) opens the menu and builds no world;
## `GameRoot._build_and_boot` runs only once the menu asks for a world or a server. Every flag CI and
## the tools pass skips the menu, so those boots are what they were before it.

const GameSettings := preload("res://src/core/game_settings.gd")
const MainMenu := preload("res://src/menu/main_menu.gd")
const LocalWorlds := preload("res://src/menu/local_worlds.gd")
const NativeBuilder := preload("res://src/terrain/native_builder.gd")
const LocaleSettings := preload("res://src/core/locale_settings.gd")
const PersistenceSlice := preload("res://src/persistence/persistence_slice.gd")

## The explored map of a boot that is not a menu world (a client, the pre-menu save): one folder, per seed.
const SHARED_REVEALED_DIR := "user://saves/client"

## The boot user args that skip the main menu: every role and run flag CI and the tools pass.
const MENU_SKIP_ARGS := ["--server", "--client", "--run-tests", "--quit-after-boot", "--playtest-bot",
	"--net-harness", "--friend", "--stress-bots", "--stress-host", "--stress-watch"]

## Phase 224 (#599) — `--menu-join <addr>`: the net harness's third process. It is NOT a menu-skip flag: the
## boot opens the real main menu, then joins `addr` through the menu's own path (`MainMenu.join_choice` →
## `start`), prints MENU_JOINED_LINE once the world snapshot arrived and quits 0 a few seconds later (so the
## host sees it report a position); a join that fails or times out quits 1.
const MENU_JOIN_ARG := "--menu-join"
const MENU_JOINED_LINE := "[Menu] joined from the main menu"
const MENU_JOIN_TIMEOUT := 120.0
const MENU_JOIN_SETTLE := 6.0
var _menu_join_active: bool = false
var _menu_join_done: bool = false

## The user args the menu decision reads; the suite sets it to boot "with no args".
var boot_args_override: Variant = null
## A catalog key the menu shows on open (a failed join's reason), set by `main.gd`.
var notice: String = ""
var menu: MainMenu = null
## True once the menu started this boot: only then does a failed join return to it.
var from_menu: bool = false
## The local world the menu chose ({dir, seed}), applied before the world boot; {} otherwise.
var world: Dictionary = {}
## Phase 224 — set once Exit to main menu or Quit ran, so a second press does not save twice.
var leaving: bool = false

## Phase 224 — the Esc menu's choices (local intents from `UiSlice`).
func _connect_all() -> void:
	connect_bus(GameBus.exit_to_menu_requested, exit_to_menu)
	connect_bus(GameBus.quit_game_requested, quit_game)

static func should_show_main_menu(args: Array) -> bool:
	for a in args:
		if MENU_SKIP_ARGS.has(str(a)):
			return false
	return true

func boot_user_args() -> Array:
	if boot_args_override is Array:
		return boot_args_override
	return Array(OS.get_cmdline_user_args())

## Open the menu when this boot has no boot user args. True when it did (the caller then stops).
func open_if_no_boot_args() -> bool:
	if not should_show_main_menu(boot_user_args()):
		return false
	LocaleSettings.apply_startup()
	GameSettings.apply_startup()   # Phase 225 — saved sound, graphics and look options
	root.set_process(false)
	root.set_physics_process(false)
	menu = MainMenu.new()
	menu.name = "MainMenu"
	root.add_child(menu)
	menu.show_notice(notice)
	menu.start_requested.connect(start)
	print("[Menu] main menu open")
	var join_addr := menu_join_address(boot_user_args())
	if join_addr != "":
		_menu_join.call_deferred(join_addr)
	return true

static func menu_join_address(args: Array) -> String:
	var i := args.find(MENU_JOIN_ARG)
	return str(args[i + 1]) if i >= 0 and i + 1 < args.size() else ""

## `--menu-join`: what the Join form's Connect does, from the menu that is open now.
func _menu_join(addr: String) -> void:
	var choice := MainMenu.join_choice(addr, "")
	if not bool(choice["ok"]) or menu == null:
		print("[Menu] menu join refused: %s" % addr)
		root.get_tree().quit(1)
		return
	_menu_join_active = true
	var tree := root.get_tree()
	tree.create_timer(MENU_JOIN_TIMEOUT).timeout.connect(func() -> void:
		if not _menu_join_done:
			print("[Menu] menu join timed out")
			tree.quit(1))
	GameBus.world_snapshot_received.connect(func(_d: Dictionary) -> void:
		if _menu_join_done:
			return
		_menu_join_done = true
		print(MENU_JOINED_LINE)
		tree.create_timer(MENU_JOIN_SETTLE).timeout.connect(func() -> void: tree.quit(0)), CONNECT_ONE_SHOT)
	menu.start_requested.emit(choice)

## The menu's choice → the role fields the boot reads. Re-checked here: it is the player's own input,
## and a host save folder must be one under `user://`.
func apply_choice(choice: Dictionary) -> bool:
	var mode := str(choice.get("mode", ""))
	if mode == "join":
		var checked := MainMenu.join_choice(str(choice.get("address", "")), str(choice.get("friend", "")))
		if not bool(checked["ok"]):
			return false
		root._is_client = true
		root._is_server = false
		root._host_address = str(checked["address"])
		root._friend_code_arg = str(checked["friend"])
		world = {}
		return true
	if mode == "host":
		var dir := str(choice.get("dir", ""))
		if not dir.begins_with("user://") or dir.contains("..") or not dir.ends_with("/"):
			return false
		root._is_client = false
		root._is_server = false
		world = { "dir": dir, "seed": int(choice.get("seed", 0)) }
		return true
	return false

## The menu asked for a world or a server: close it and run the boot `_ready` would have run.
func start(choice: Dictionary) -> void:
	if menu == null or not apply_choice(choice):
		return
	from_menu = true
	root.remove_child(menu)
	menu.queue_free()
	menu = null
	NativeBuilder.init()
	root.set_process(true)
	root.set_physics_process(true)
	print("[Menu] starting %s" % str(choice.get("mode", "")))
	await root._build_and_boot()

## Point the authoritative save at the chosen world and adopt its seed before the world boot (a world
## record on disk still wins, see `PersistenceWiring.load_world_records`). A no-op for any other boot.
func apply_world() -> void:
	if world.is_empty():
		return
	var dir := str(world["dir"])
	root._persistence.server_save_dir = dir
	root._terrain.set_world_seed(int(world["seed"]))
	if root._minimap != null:
		root._minimap.revealed_dir = revealed_dir_for(dir)
	LocalWorlds.touch(dir)
	print("[Menu] local world %s" % dir)

## Phase 224 (#599) — where a local world keeps this machine's explored map: inside its own folder, so two worlds
## made with the same seed never share one, and deleting the world deletes its map. The pre-menu save keeps the
## shared folder it always used (its explored map is already there).
static func revealed_dir_for(world_dir: String) -> String:
	if world_dir == "" or world_dir == PersistenceSlice.DEFAULT_SERVER_SAVE_DIR:
		return SHARED_REVEALED_DIR
	return world_dir.trim_suffix("/")

## Phase 224 — Exit to main menu from the Esc menu. A listen host writes the world and the explored map first
## (the same save as closing the window); a client has no records to write. `main.gd` then drops this root
## (`close()` disconnects) and opens the main menu on a fresh one.
func exit_to_menu() -> void:
	if leaving:
		return
	leaving = true
	print("[Menu] exit to main menu")
	root.save_before_leave()
	root.menu_return_requested.emit("")

## Phase 224 — Quit game from the Esc menu: the window-close path (save, then quit).
func quit_game() -> void:
	if leaving:
		return
	leaving = true
	root.quit_game()

## A join the menu started failed, or lost its host: back to the menu with `reason_key`. A client
## booted with `--client` keeps the old behaviour (it logs and stays).
func join_failed(reason_key: String) -> void:
	if not from_menu or not root._is_client:
		return
	if _menu_join_active:   # the harness's menu client: a lost host after the join is its normal end
		print("[Menu] menu join ended — %s" % reason_key)
		root.get_tree().quit(0 if _menu_join_done else 1)
		return
	print("[Menu] join failed — %s" % reason_key)
	from_menu = false
	root.menu_return_requested.emit(reason_key)

## Before the root is freed for a fresh menu: drop the connection.
func close() -> void:
	root._snapshot_pending = false
	if root._networking != null:
		root._networking.disconnect_all()
