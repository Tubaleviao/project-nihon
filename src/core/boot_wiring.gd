extends "res://src/core/wiring.gd"
## Boot wiring (Phase 132) — Boot arguments and start-up data checks.
## Moved out of game_root.gd; `root` is the GameRoot that owns the slices.

const Diag := preload("res://src/core/diag.gd")
const NativeBuilder := preload("res://src/terrain/native_builder.gd")
const PLAYTEST_BOT_PATH := "res://src/tests/playtest_bot.gd"
const STRESS_BOTS_PATH := "res://src/tests/stress_bots.gd"
const STRESS_RECORDER_PATH := "res://src/tests/stress_recorder.gd"
const NetworkingSlice := preload("res://src/networking/networking_slice.gd")
const TestSuite := preload("res://src/tests/test_suite.gd")
const NetHarness := preload("res://src/tests/net_harness.gd")
const NetAddress := preload("res://src/networking/net_address.gd")
const ServerStatus := preload("res://src/networking/server_status.gd")
const RegistryWire := preload("res://src/networking/registry_wire.gd")
const RegistryList := preload("res://src/networking/registry_list.gd")
const RegistryServer := preload("res://src/networking/registry_server.gd")

## Phase 162 — the dedicated server's connection cap (a stress host raises it past the ladder's top).
var max_clients: int = NetworkingSlice.DEFAULT_MAX_CLIENTS
## Phase 297 — what a host listens on: `--port <n>` (the game port), `--bind <addr>` (default "*", dual-stack),
## `--status-port <n>` (default the game port + 1, 0 = off) and `--world-name <text>` (the status answer's name for a
## dedicated server; a menu world answers with its own name).
var host_port: int = NetworkingSlice.DEFAULT_PORT
var bind_address: String = "*"
var status_port: int = -1
var world_name: String = ""
## Phase 298 — `--public` (announce this dedicated server to the registries, `--registries a,b` or the saved list),
## `--region <tag>` (one of `RegistryWire.REGIONS`) and `--save-dir user://…/` (a second dedicated server on one
## machine keeps its own save).
var public: bool = false
var region: String = ""
var save_dir: String = ""

## Parse `--client [addr]` from OS user args to determine network role. Defaults
## to host (authoritative single-player) when no args are present. A malformed
## address is rejected with a warning and falls back to localhost. `args` is the OS user args unless the suite
## passes its own.
func parse_network_args(args: PackedStringArray = OS.get_cmdline_user_args()) -> void:
	NativeBuilder.init()   # Phase 166 — native chunk builder if its binary is present, else GDScript
	for i in range(args.size()):
		if args[i] == "--server":
			root._is_server = true
		if args[i] == "--client":
			root._is_client = true
			if i + 1 < args.size() and not str(args[i + 1]).begins_with("--"):
				root._host_address = client_address(str(args[i + 1]))
	for i in range(args.size()):
		if args[i] == "--friend" and i + 1 < args.size():
			root._friend_code_arg = str(args[i + 1])
	parse_host_args(args)
	# Phase 39 — the harness role decides the network role too: `--net-harness host` is
	# the dedicated server half of the pair and `--net-harness client` the joining half,
	# so the driver names one side rather than having to keep two arguments consistent.
	var harness_role := root.net_harness_role(args)
	if harness_role == "host":
		root._is_server = true
	elif harness_role == "client":
		root._is_client = true
	root._net_harness_role = harness_role
	# Phase 162 — a stress watcher is a harness CLIENT that runs the shipped client boot, not the scenario.
	if args.has("--stress-watch"):
		root._net_harness_role = ""

## Phase 33 — save-on-shutdown. `auto_accept_quit = false` turns the window
## manager's close request into a notification this node answers by writing the
## world + player records and only then quitting. Only the authoritative roles
## own state worth writing, so a client keeps the default behaviour.
##
## A headless server has no window, and Godot 4.7 delivers NO notification for
## SIGTERM — the process is simply killed (verified with a probe; see the Phase
## 33 implementation notes in docs/roadmap-history/phases-33-38.md). That case is covered by the autosave
## interval plus the shutdown-request file polled in PersistenceWiring.tick_save_lifecycle().
func install_quit_guard() -> void:
	if not root._is_client:
		root.get_tree().auto_accept_quit = false

## Phase 297 — `--port`, `--bind`, `--status-port`, `--world-name`. A malformed value warns and keeps the default.
func parse_host_args(args: PackedStringArray) -> void:
	for i in range(args.size() - 1):
		var v := str(args[i + 1])
		match str(args[i]):
			"--port":
				var p := NetAddress.port_of(v)
				if p > 0:
					host_port = p
				else:
					Diag.warn("[Networking] invalid --port '%s' — using %d" % [v, host_port])
			"--bind":
				if v == "*" or v.is_valid_ip_address():
					bind_address = v
				else:
					Diag.warn("[Networking] invalid --bind '%s' — binding every address" % v)
			"--status-port":
				var sp := NetAddress.port_of(v)
				if v == "0" or sp > 0:
					status_port = sp
				else:
					Diag.warn("[Networking] invalid --status-port '%s' — using the game port + 1" % v)
			"--world-name":
				world_name = ServerStatus.clean_text(v).left(64)
			"--region":
				region = RegistryWire.region_of(v)
				if region == "" and v != "":
					Diag.warn("[Networking] unknown --region '%s' — no region" % v)
			"--save-dir":
				if valid_save_dir(v):
					save_dir = v
				else:
					Diag.warn("[Networking] invalid --save-dir '%s' — it must be a folder under user:// ending in /" % v)
	public = args.has("--public")

## `--save-dir`: the authoritative save of a dedicated server or a CLI listen host goes there (a menu world keeps its
## own folder).
func apply_save_dir() -> void:
	if save_dir != "" and root._menu_wiring.world.is_empty() and not root._is_client:
		root._persistence.server_save_dir = save_dir
		print("[Server] save folder %s" % save_dir)

## A save folder a boot flag may name: under `user://`, no `..`, ending in `/`.
static func valid_save_dir(dir: String) -> bool:
	return dir.begins_with("user://") and not dir.contains("..") and dir.ends_with("/") and dir.length() > 8

## Phase 297 — the options `NetworkingSlice.host` takes for this boot. `menu_world` is the menu's choice ({name} on a
## listen host started from it); `dedicated` says no player plays in this process.
func host_options(menu_world: Dictionary, dedicated: bool) -> Dictionary:
	return {
		"bind": bind_address,
		"status_port": status_port if status_port >= 0 else ServerStatus.default_status_port(host_port),
		"world_name": str(menu_world.get("name", "")) if str(menu_world.get("name", "")) != "" else world_name,
		"local_players": 0 if dedicated else 1,
		"public": public if dedicated else bool(menu_world.get("public", false)),
		"registries": RegistryList.current(),
		"region": region,
	}

## Phase 298 — `--registry [port]`: this process is a registry and nothing else. The port, or 0 when the flag is
## absent (RegistryWire.DEFAULT_PORT when it names none); -1 for a malformed one.
static func registry_port(args: Array) -> int:
	var i := args.find("--registry")
	if i < 0:
		return 0
	if i + 1 >= args.size() or str(args[i + 1]).begins_with("--"):
		return RegistryWire.DEFAULT_PORT
	var p := NetAddress.port_of(str(args[i + 1]))
	return p if p > 0 else -1

## Start the registry role when asked. True when it took the boot (the caller builds no world); a port that will
## not open quits the process with 1.
func start_registry(args: Array = Array(OS.get_cmdline_user_args())) -> bool:
	var port := registry_port(args)
	if port == 0:
		return false
	root.set_process(false)
	root.set_physics_process(false)
	if port < 0:
		Diag.error("[Registry] invalid --registry port")
		root.get_tree().quit(1)
		return true
	var reg := RegistryServer.new()
	reg.name = "Registry"
	root.add_child(reg)
	var err: Error = reg.start(port, bind_address)
	if err != OK:
		Diag.error("[Registry] could not listen on port %d — %s" % [port, error_string(err)])
		root.get_tree().quit(1)
	return true

## The host a `--client <addr>` boot joins. The address rule is the main menu's Join form's
## (`NetAddress.parse`, one rule since Phase 224 / #599, with ports and IPv6 since Phase 297). A malformed value
## warns loudly and falls back to 127.0.0.1.
static func client_address(addr: String) -> String:
	if NetAddress.valid(addr):
		return addr
	Diag.warn("[Networking] invalid --client address '%s' — using 127.0.0.1" % addr)
	return "127.0.0.1"

# ---------------------------------------------------------------------------
# World boot
# ---------------------------------------------------------------------------

func check_game_data() -> void:
	var registries := {
		"APPEARANCES":  GameData.APPEARANCES,
		"BIOMES":       GameData.BIOMES,
		"CREATURES":    GameData.CREATURES,
		"DECISIONS":    GameData.DECISIONS,
		"ITEMS":        GameData.ITEMS,
		"LOOTS":        GameData.LOOTS,
		"MATERIALS":    GameData.MATERIALS,
		"PALETTES":     GameData.PALETTES,
		"PLAYERS":      GameData.PLAYERS,
		"PROFESSIONS":  GameData.PROFESSIONS,
		"RECIPES":      GameData.RECIPES,
		"SKELETONS":    GameData.SKELETONS,
		"SKILLS":       GameData.SKILLS,
		"SYSTEMS":      GameData.SYSTEMS,
		"TECHNOLOGIES": GameData.TECHNOLOGIES,
		"WORLD_SYSTEMS":GameData.WORLD_SYSTEMS,
	}
	for reg_name in registries:
		var reg: Dictionary = registries[reg_name]
		for key in reg:
			if reg[key] == null:
				Diag.error("%s → %s FAILED" % [reg_name, key])

## Phase 162 — `--stress-bots <n>`: this process is a crowd of bot clients and no game (debug builds
## only). True when it took the boot; the caller then builds nothing else.
func start_stress_bots() -> bool:
	if not OS.is_debug_build() or not OS.get_cmdline_user_args().has("--stress-bots"):
		return false
	var bots: Node = (load(STRESS_BOTS_PATH) as GDScript).new()
	bots.name = "StressBots"
	root.add_child(bots)
	root.set_process(false)   # no slices to tick
	root.set_physics_process(false)
	return true

## Phase 162 — the stress host's save directory and seed (before the world boot), then the recorder
## of a `--stress-host` / `--stress-watch` boot (after it). Debug builds only; no-ops otherwise.
func prepare_stress_role() -> void:
	if OS.is_debug_build():
		(load(STRESS_RECORDER_PATH) as GDScript).prepare(root)

func start_stress_recorder() -> void:
	if OS.is_debug_build():
		(load(STRESS_RECORDER_PATH) as GDScript).attach(root)

## Phase 248 — the bot runs in debug builds, and in a release build exported with the `playtest` feature
## (the "Linux Playtest" preset, which CI uses to measure the release build). A shipped release build has
## neither, so it ignores the flag.
static func playtest_allowed(is_debug_build: bool, has_playtest_feature: bool) -> bool:
	return is_debug_build or has_playtest_feature

static func _playtest_allowed() -> bool:
	return playtest_allowed(OS.is_debug_build(), OS.has_feature("playtest"))

## `--playtest-bot`: the bot's emptied save directory and pinned seed, before the world boot.
func prepare_playtest_bot() -> void:
	if _playtest_allowed():
		(load(PLAYTEST_BOT_PATH) as GDScript).prepare(root)

## Phase 134 — `--playtest-bot`: a scripted bot plays the rendered listen host, then quits the process.
## Debug builds and `playtest` exports only: it empties the pack and edits the world, so a shipped release
## build ignores the flag.
func start_playtest_bot() -> void:
	if not _playtest_allowed() or root._is_client or root._is_server:
		return
	# Loaded here, not preloaded: a release build never parses the bot.
	var PlaytestBot: GDScript = load(PLAYTEST_BOT_PATH)
	if not PlaytestBot.requested(OS.get_cmdline_user_args()):
		return
	var bot: Node = PlaytestBot.new()
	bot.name = "PlaytestBot"
	root.add_child(bot)
	bot.run(root)

## Phase 39 — run the two-client network harness and let it end this process.
##
## Called from GameRoot after every slice is built and wired and BEFORE the role boot, for the
## same reason the suite is: the slices have to exist for the scenario to drive them, and
## the boot half the role needs is the one the harness itself invokes (`_boot_server()` /
## `join()`) so what runs is the shipped boot path, not a harness-only arrangement. The
## scenario quits the process when it finishes, which is what makes the driver's "did
## this side exit cleanly" check mean something.
func run_net_harness(role: String) -> void:
	var harness := NetHarness.new()
	harness.name = "NetHarness"
	root.add_child(harness)
	await harness.run(root, role)
	harness.queue_free()

# ---------------------------------------------------------------------------
# Automated tests
# ---------------------------------------------------------------------------

func run_tests() -> void:
	var suite := TestSuite.new()
	suite.name = "TestSuite"
	root.add_child(suite)
	suite.run()
	suite.queue_free()
