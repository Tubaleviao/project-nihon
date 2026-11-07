extends "res://src/core/wiring.gd"
## Phase 223 — the main menu's glue: whether a boot opens it, what its choice sets on the root, and the
## way back to it when a join started from it fails. `root` is the GameRoot that owns the slices.
##
## A boot with none of MENU_SKIP_ARGS (a player launching the game) opens the menu and builds no world;
## `GameRoot._build_and_boot` runs only once the menu asks for a world or a server. Every flag CI and
## the tools pass skips the menu, so those boots are what they were before it.

const MainMenu := preload("res://src/menu/main_menu.gd")
const LocalWorlds := preload("res://src/menu/local_worlds.gd")
const NativeBuilder := preload("res://src/terrain/native_builder.gd")
const LocaleSettings := preload("res://src/core/locale_settings.gd")

## The boot user args that skip the main menu: every role and run flag CI and the tools pass.
const MENU_SKIP_ARGS := ["--server", "--client", "--run-tests", "--quit-after-boot", "--playtest-bot",
	"--net-harness", "--friend", "--stress-bots", "--stress-host", "--stress-watch"]

## The user args the menu decision reads; the suite sets it to boot "with no args".
var boot_args_override: Variant = null
## A catalog key the menu shows on open (a failed join's reason), set by `main.gd`.
var notice: String = ""
var menu: MainMenu = null
## True once the menu started this boot: only then does a failed join return to it.
var from_menu: bool = false
## The local world the menu chose ({dir, seed}), applied before the world boot; {} otherwise.
var world: Dictionary = {}

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
	root.set_process(false)
	root.set_physics_process(false)
	menu = MainMenu.new()
	menu.name = "MainMenu"
	root.add_child(menu)
	menu.show_notice(notice)
	menu.start_requested.connect(start)
	print("[Menu] main menu open")
	return true

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
	LocalWorlds.touch(dir)
	print("[Menu] local world %s" % dir)

## A join the menu started failed, or lost its host: back to the menu with `reason_key`. A client
## booted with `--client` keeps the old behaviour (it logs and stays).
func join_failed(reason_key: String) -> void:
	if not from_menu or not root._is_client:
		return
	print("[Menu] join failed — %s" % reason_key)
	from_menu = false
	root.menu_return_requested.emit(reason_key)

## Before the root is freed for a fresh menu: drop the connection.
func close() -> void:
	root._snapshot_pending = false
	if root._networking != null:
		root._networking.disconnect_all()
