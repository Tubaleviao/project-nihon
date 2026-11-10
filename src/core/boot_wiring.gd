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
const RecentServers := preload("res://src/menu/recent_servers.gd")

## Phase 162 — the dedicated server's connection cap (a stress host raises it past the ladder's top).
var max_clients: int = NetworkingSlice.DEFAULT_MAX_CLIENTS

## Parse `--client [addr]` from OS user args to determine network role. Defaults
## to host (authoritative single-player) when no args are present. A malformed
## address is rejected with a warning and falls back to localhost.
func parse_network_args() -> void:
	NativeBuilder.init()   # Phase 166 — native chunk builder if its binary is present, else GDScript
	var args := OS.get_cmdline_user_args()
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

## The host a `--client <addr>` boot joins. The address rule is the main menu's Join form's
## (`RecentServers.valid_address`, one function since Phase 224 / #599): a literal IP or a plain hostname,
## no scheme, path or whitespace. A malformed value warns loudly and falls back to 127.0.0.1.
static func client_address(addr: String) -> String:
	if RecentServers.valid_address(addr):
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

## `--playtest-bot`: the bot's emptied save directory and pinned seed, before the world boot.
func prepare_playtest_bot() -> void:
	if OS.is_debug_build():
		(load(PLAYTEST_BOT_PATH) as GDScript).prepare(root)

## Phase 134 — `--playtest-bot`: a scripted bot plays the rendered listen host, then quits the process.
## Debug builds only: it empties the pack and edits the world, so a release build ignores the flag.
func start_playtest_bot() -> void:
	if not OS.is_debug_build() or root._is_client or root._is_server:
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
