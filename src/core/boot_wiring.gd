extends "res://src/core/wiring.gd"
## Boot wiring (Phase 132) — Boot arguments and start-up data checks.
## Moved out of game_root.gd; `root` is the GameRoot that owns the slices.

const Diag := preload("res://src/core/diag.gd")
const PLAYTEST_BOT_PATH := "res://src/tests/playtest_bot.gd"

## Parse `--client [addr]` from OS user args to determine network role. Defaults
## to host (authoritative single-player) when no args are present. A malformed
## address is rejected with a warning and falls back to localhost.
func _parse_network_args() -> void:
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--server":
			root._is_server = true
		if args[i] == "--client":
			root._is_client = true
			if i + 1 < args.size() and not str(args[i + 1]).begins_with("--"):
				var addr := str(args[i + 1])
				if _valid_host_address(addr):
					root._host_address = addr
				else:
					Diag.warn("[Networking] invalid --client address '%s' — using 127.0.0.1" % addr)
					root._host_address = "127.0.0.1"
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

## Phase 33 — save-on-shutdown. `auto_accept_quit = false` turns the window
## manager's close request into a notification this node answers by writing the
## world + player records and only then quitting. Only the authoritative roles
## own state worth writing, so a client keeps the default behaviour.
##
## A headless server has no window, and Godot 4.7 delivers NO notification for
## SIGTERM — the process is simply killed (verified with a probe; see the Phase
## 33 implementation notes in docs/roadmap-history/phases-33-38.md). That case is covered by the autosave
## interval plus the shutdown-request file polled in _tick_save_lifecycle().
func _install_quit_guard() -> void:
	if not root._is_client:
		root.get_tree().auto_accept_quit = false

## True when `addr` is a literal IP or a plain hostname (no scheme, path, or
## whitespace). Rejects empty and obviously malformed values so a bad --client
## argument fails loudly instead of silently joining 127.0.0.1.
func _valid_host_address(addr: String) -> bool:
	if addr.is_empty():
		return false
	if addr.contains("://") or addr.contains("/") or addr.contains(" ") or addr.contains("	"):
		return false
	var re := RegEx.new()
	re.compile("^[A-Za-z0-9][A-Za-z0-9.:-]*$")
	return re.search(addr) != null

# ---------------------------------------------------------------------------
# World boot
# ---------------------------------------------------------------------------

func _check_game_data() -> void:
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

## Phase 134 — `--playtest-bot`: a scripted bot plays the rendered listen host, then quits the process.
## Debug builds only: it empties the pack and edits the world, so a release build ignores the flag.
func _start_playtest_bot() -> void:
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
