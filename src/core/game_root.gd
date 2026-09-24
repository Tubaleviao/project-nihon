extends Node
## Game root — integration layer that owns all slices and wires them together.
##
## Slices communicate exclusively through GameBus signals. This script
## instantiates slices, sets cross-slice references that cannot travel the bus,
## and drives the startup sequence (tests → GameData check → terrain boot).

const TerrainSlice     := preload("res://src/terrain/terrain_slice.gd")
const VoxelSlice       := preload("res://src/terrain/voxel_slice.gd")
const ChunkManager     := preload("res://src/terrain/chunk_manager.gd")
const BattleSlice      := preload("res://src/battle/battle_slice.gd")
const CreatureSlice    := preload("res://src/creature/creature_slice.gd")
const CreatureAI       := preload("res://src/creature/creature_ai.gd")
const NetworkingSlice  := preload("res://src/networking/networking_slice.gd")
const PersistenceSlice := preload("res://src/persistence/persistence_slice.gd")
const PlayerRegistry   := preload("res://src/persistence/player_registry.gd")
const PlayerSlice      := preload("res://src/player/player_slice.gd")
const LootSlice        := preload("res://src/loot/loot_slice.gd")
const InventorySlice   := preload("res://src/inventory/inventory_slice.gd")
const CharacterSlice   := preload("res://src/character/character_slice.gd")
const CraftingSlice    := preload("res://src/crafting/crafting_slice.gd")
const TechnologySlice  := preload("res://src/technology/technology_slice.gd")
const StationSlice     := preload("res://src/world/station_slice.gd")
const TreeSlice        := preload("res://src/world/tree_slice.gd")
const MarketSlice      := preload("res://src/world/market_slice.gd")
const TradeSlice       := preload("res://src/trade/trade_slice.gd")
const ProposalSlice    := preload("res://src/governance/proposal_slice.gd")
const UiSlice          := preload("res://src/ui/ui_slice.gd")
const Minimap          := preload("res://src/ui/minimap.gd")
const TestSuite        := preload("res://src/tests/test_suite.gd")

var _terrain:     TerrainSlice
var _voxel:       VoxelSlice
var _chunk_manager: ChunkManager
var _minimap:     Minimap
var _battle:      BattleSlice
var _creature:    CreatureSlice
var _creature_ai: CreatureAI
var _networking:  NetworkingSlice
var _persistence: PersistenceSlice
var _registry:    PlayerRegistry
var _player:      PlayerSlice
var _loot:        LootSlice
var _inventory:   InventorySlice
var _character:   CharacterSlice
var _crafting:    CraftingSlice
var _technology:  TechnologySlice
var _station:     StationSlice
var _tree:        TreeSlice
var _market:      MarketSlice
var _trade:       TradeSlice
var _proposal:    ProposalSlice
var _ui:          UiSlice

## Network role (Phase 18/27). HOST = authoritative simulation (default, matches
## single-player); CLIENT = receives world state from a host; SERVER = headless
## dedicated authoritative host (no rendering, no local player). Derived from
## command-line user args: `godot -- --client <addr>` joins, `--server` boots a
## headless server, otherwise host.
var _is_client: bool = false
var _is_server: bool = false
var _host_address: String = "127.0.0.1"
var _snapshot_pending: bool = false

## Phase 29 — the AOI grid cell each connected peer last reported, so a client
## moving into a new region triggers a re-scoped snapshot (host side only).
var _peer_aoi_regions: Dictionary = {}

## Phase 33 — seconds accumulated since the last authoritative autosave.
var _autosave_elapsed: float = 0.0

## Phase 33 — seconds accumulated since the shutdown-request file was last polled.
## Kept SEPARATE from `_autosave_elapsed` (and paired with the fabric's own, much
## shorter cadence): a shutdown request answered only on the autosave tick made a
## restart wait up to a full 300 s, so an orchestrator that kills the process
## after a short grace period killed it before it ever saved — up to five minutes
## of edits lost on every restart.
var _shutdown_poll_elapsed: float = 0.0

## Phase 33 — the world record read at boot. It carries the local player id the
## previous process minted, and the creature state that has to be re-applied
## AFTER chunk streaming spawns the population.
var _loaded_world: Dictionary = {}

## Client-side: seconds to wait for the host world snapshot before giving up.
const SNAPSHOT_TIMEOUT := 10.0
var _snapshot_elapsed: float = 0.0

## Client-side: how long to wait for a snapshot before re-presenting the join
## intent, and how many times to do so. The handshake is the only route to an
## identity and a world, so a lost join_intent (or a lost snapshot) must be
## retried rather than ending in an empty client: retries are spaced so a slow
## host is not flooded, and the total budget stays inside SNAPSHOT_TIMEOUT.
const HANDSHAKE_RETRY_SECS := 3.0
const MAX_HANDSHAKE_RETRIES := 3
var _handshake_elapsed: float = 0.0
var _handshake_retries: int = 0

func _ready() -> void:
	# Run the automated tests before any production slice enters the tree.
	# The suite emits signals on the shared GameBus (creature_died, chunk_ready,
	# combat, loot…). Running it first keeps those emissions from leaking into
	# production state — previously the test creature_died calls were marking
	# every freshly spawned creature dead and hiding its body on world boot.
	_run_tests()

	_parse_network_args()
	# Phase 33 — intercept the quit so records are written first.
	_install_quit_guard()

	_terrain     = TerrainSlice.new()
	_voxel       = VoxelSlice.new()
	_chunk_manager = ChunkManager.new()
	_minimap     = Minimap.new()
	_battle      = BattleSlice.new()
	_creature    = CreatureSlice.new()
	_creature_ai = CreatureAI.new()
	_networking  = NetworkingSlice.new()
	_persistence = PersistenceSlice.new()
	_registry    = PlayerRegistry.new()
	_player      = PlayerSlice.new()
	_loot        = LootSlice.new()
	_inventory   = InventorySlice.new()
	_character   = CharacterSlice.new()
	_crafting    = CraftingSlice.new()
	_technology  = TechnologySlice.new()
	_station     = StationSlice.new()
	_tree        = TreeSlice.new()
	_market      = MarketSlice.new()
	_trade       = TradeSlice.new()
	_proposal    = ProposalSlice.new()
	_ui          = UiSlice.new()

	# CreatureSlice needs the terrain to place spawns on the surface; wire it
	# before the slices enter the tree so its _ready() can use it.
	_creature.terrain_slice = _terrain
	# TreeSlice likewise stands its trees on the terrain surface.
	_tree.terrain_slice = _terrain

	# CreatureAI needs creature_slice, player_slice, and battle_slice for queries.
	_creature_ai.creature_slice = _creature
	_creature_ai.player_slice   = _player
	_creature_ai.battle_slice   = _battle

	# Wire crafting + station cross-references before add_child so their _ready()
	# methods see the correct dependencies if they ever emit signals during init.
	_crafting.station_slice    = _station
	_station.player_slice      = _player

	# Headless server (Phase 27): creature + player presentation is skipped so
	# the authoritative simulation runs with no visual nodes. Set BEFORE the
	# slices enter the tree so their _ready() skips body/pool construction.
	_creature.render_visuals = not _is_server
	_player.render_visuals   = not _is_server
	_tree.render_visuals     = not _is_server

	# The UI (Phase 14) is presentation only, so a headless dedicated server
	# (Phase 27) keeps it out of the tree — its _ready() would otherwise build
	# windows nothing can render or click.
	var slices: Array = [_terrain, _voxel, _chunk_manager, _battle, _creature, _creature_ai, _networking, _persistence, _registry, _player, _loot, _inventory, _character, _crafting, _technology, _station, _tree, _market, _trade, _proposal]
	if not _is_server:
		slices.append(_ui)
	for s in slices:
		s.name = s.get_script().resource_path.get_file().get_basename()
		add_child(s)

	# Cross-slice wiring: direct references where the bus cannot carry context.
	_inventory.loot_slice      = _loot
	_player.creature_slice     = _creature
	_player.voxel_slice        = _voxel
	_player.terrain_slice      = _terrain
	_battle.creature_slice     = _creature
	_loot.creature_slice       = _creature
	_crafting.inventory_slice  = _inventory
	_crafting.technology_slice = _technology
	# Phase 33 — crafting resolves against the CRAFTER's own inventory, so the slice
	# needs the registry that owns one inventory per player (see CraftingSlice).
	_crafting.player_registry  = _registry
	_player.station_slice = _station
	_technology.inventory_slice = _inventory
	# Phase 34 — research consumes the RESEARCHER's own materials and moves that
	# player's tree only, so the slice needs the registry that owns one inventory
	# per player (see TechnologySlice).
	_technology.player_registry = _registry
	_voxel.terrain_slice      = _terrain
	_voxel.inventory_slice    = _inventory
	_tree.inventory_slice     = _inventory
	if not _is_server:
		_ui.inventory_slice       = _inventory
		_ui.crafting_slice        = _crafting
		_ui.technology_slice      = _technology
		_ui.market_slice          = _market
		_ui.proposal_slice        = _proposal
		_ui.trade_slice           = _trade
	_trade.inventory_slice    = _inventory
	_market.inventory_slice   = _inventory
	# Host-only, like the demo sequence in _boot_host(): the seeded counterparty
	# is single-player scaffolding and `_ui` is not in the tree on a server.
	if DEBUG and not _is_server:
		# Single-player social demo (DEBUG only): a seeded merchant counterparty
		# lets the trade window commit a real exchange, a merchant market listing
		# gives a solo player a non-self seller to buy from, and a couple of
		# other-authored proposals give them something to vote on. This is demo
		# scaffolding — it must not run in a production boot.
		var merchant_inv := InventorySlice.new()
		merchant_inv.name = "MerchantInventory"
		add_child(merchant_inv)
		merchant_inv.add_item("hawk_feather", 10)
		merchant_inv.add_item("wolf_fang", 3)
		_trade.set_party_inventory("merchant", merchant_inv)
		_market.set_party_inventory("merchant", merchant_inv)
		_market.list_item("merchant", "wolf_fang", 2, 15.0)
		_proposal.submit_proposal("merchant", "Open a northern trade route", "Connect the settlement to the northern passes.")
		_proposal.submit_proposal("elder", "Establish a community forge", "Build a shared forge for all smiths.")
	_ui.refresh_all()

	# Authority mode (Phase 18): a client never owns world state — it forwards
	# edits to the host and applies authoritative deltas. The host (and offline
	# single-player) keeps full simulation authority.
	_voxel.is_authoritative     = not _is_client
	_creature.is_authoritative  = not _is_client
	_creature_ai.is_authoritative = not _is_client
	_tree.is_authoritative      = not _is_client
	_market.is_authoritative    = not _is_client
	_trade.is_authoritative     = not _is_client
	_proposal.is_authoritative  = not _is_client
	# Phase 33 — a client owns no player records: the host mints ids, keeps the
	# records, and ships the client only its own state. Crafting follows the same
	# rule, because a craft mutates a player's persisted inventory.
	_registry.is_authoritative  = not _is_client
	_crafting.is_authoritative  = not _is_client
	# Phase 34 — same rule for the technology tree: a client owns no records, so it
	# forwards a research intent instead of resolving one against its synced copy.
	_technology.is_authoritative = not _is_client

	# Chunk streaming (Phase 17) — wire the manager to its collaborators.
	_chunk_manager.terrain_slice  = _terrain
	_chunk_manager.voxel_slice    = _voxel
	_chunk_manager.player_slice   = _player
	_chunk_manager.creature_slice = _creature
	_chunk_manager.tree_slice     = _tree

	# Minimap overlay (Phase 17) — top-right, biome-coloured chunk view. Pure
	# presentation, so a headless dedicated server (Phase 27) skips it entirely,
	# the same way the lighting block below does.
	if not _is_server:
		var minimap_layer := CanvasLayer.new()
		minimap_layer.name = "MinimapLayer"
		minimap_layer.layer = 20
		add_child(minimap_layer)
		_minimap.anchor_left = 1.0
		_minimap.anchor_right = 1.0
		_minimap.anchor_top = 0.0
		_minimap.anchor_bottom = 0.0
		_minimap.offset_left = -180.0
		_minimap.offset_right = -12.0
		_minimap.offset_top = 12.0
		_minimap.offset_bottom = 180.0
		_minimap.chunk_manager = _chunk_manager
		_minimap.player_slice = _player
		_minimap.terrain_slice = _terrain
		minimap_layer.add_child(_minimap)

	# Bus listeners for integration-layer logging.
	GameBus.chunk_ready.connect(_on_chunk_ready)
	GameBus.combat_round_resolved.connect(_on_combat_resolved)
	GameBus.combat_round_requested.connect(_on_combat_round_requested)
	GameBus.save_completed.connect(_on_save_completed)
	GameBus.load_completed.connect(_on_load_completed)
	GameBus.creature_died.connect(_on_creature_died)
	GameBus.creature_spawned.connect(_on_creature_spawned)
	GameBus.loot_dropped.connect(_on_loot_dropped)
	GameBus.item_picked_up.connect(_on_item_picked_up)
	GameBus.player_state_changed.connect(_on_player_state_changed)
	GameBus.inventory_full.connect(_on_inventory_full)
	GameBus.character_spawned.connect(_on_character_spawned)
	GameBus.craft_resolved.connect(_on_craft_resolved)
	GameBus.repair_resolved.connect(_on_repair_resolved)
	GameBus.research_resolved.connect(_on_research_resolved)
	GameBus.technology_unlocked.connect(_on_technology_unlocked)
	GameBus.own_state_synced.connect(_on_own_state_synced)
	GameBus.block_mined.connect(_on_block_mined)
	GameBus.block_placed.connect(_on_block_placed)
	GameBus.player_damaged.connect(_on_player_damaged)
	GameBus.player_died.connect(_on_player_died)
	GameBus.player_respawned.connect(_on_player_respawned)
	GameBus.trade_completed.connect(_on_trade_completed)
	GameBus.peer_connected.connect(_on_peer_connected)
	GameBus.peer_disconnected.connect(_on_peer_disconnected)
	GameBus.player_joined.connect(_on_player_joined)
	GameBus.player_identity_assigned.connect(_on_player_identity_assigned)
	GameBus.remote_player_state.connect(_on_remote_player_state)
	GameBus.world_snapshot_received.connect(_on_world_snapshot_received)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	# Lighting — a directional "sun" plus soft ambient sky fill. Skipped on a
	# headless server (no renderer to light).
	if not _is_server:
		var sun := DirectionalLight3D.new()
		sun.name = "Sun"
		sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
		sun.light_color = Color(1.0, 0.95, 0.85)
		sun.light_energy = 1.4
		sun.shadow_enabled = true
		add_child(sun)

		var env := WorldEnvironment.new()
		env.name = "Environment"
		var environment := Environment.new()
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color(0.45, 0.62, 0.85)
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color(0.55, 0.6, 0.7)
		environment.ambient_light_energy = 0.5
		env.environment = environment
		add_child(env)

	# Verify GameData entries load cleanly.
	_check_game_data()

	# Boot terrain — creatures are spawned by CreatureSlice._ready() via GameData.
	_boot_world()

# ---------------------------------------------------------------------------
# Automated tests
# ---------------------------------------------------------------------------

func _run_tests() -> void:
	var suite := TestSuite.new()
	suite.name = "TestSuite"
	add_child(suite)
	suite.run()
	suite.queue_free()

## Parse `--client [addr]` from OS user args to determine network role. Defaults
## to host (authoritative single-player) when no args are present. A malformed
## address is rejected with a warning and falls back to localhost.
func _parse_network_args() -> void:
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--server":
			_is_server = true
		if args[i] == "--client":
			_is_client = true
			if i + 1 < args.size() and not str(args[i + 1]).begins_with("--"):
				var addr := str(args[i + 1])
				if _valid_host_address(addr):
					_host_address = addr
				else:
					push_warning("[Networking] invalid --client address '%s' — using 127.0.0.1" % addr)
					_host_address = "127.0.0.1"

## Phase 33 — save-on-shutdown. `auto_accept_quit = false` turns the window
## manager's close request into a notification this node answers by writing the
## world + player records and only then quitting. Only the authoritative roles
## own state worth writing, so a client keeps the default behaviour.
##
## A headless server has no window, and Godot 4.7 delivers NO notification for
## SIGTERM — the process is simply killed (verified with a probe; see the Phase
## 33 implementation notes in ROADMAP.md). That case is covered by the autosave
## interval plus the shutdown-request file polled in _tick_save_lifecycle().
func _install_quit_guard() -> void:
	if not _is_client:
		get_tree().auto_accept_quit = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("[Server] window close requested — saving before quit")
		_save_everything(true)
		# The write is threaded, so quitting here would race it: block until it lands.
		_flush_save()
		get_tree().quit()

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

## Set true to enable verbose craft-fail logging and the demo station/craft
## sequence in _boot_host(). False keeps boot output minimal in production.
const DEBUG := false

## Role dispatch (Phase 32): client → `_boot_client()`, dedicated server →
## `_boot_server()`, otherwise the listen host → `_boot_host()`. No boot logic
## lives here any more — the host path used to be inlined at this point.
func _boot_world() -> void:
	if _is_client:
		_boot_client()
		return

	if _is_server:
		_boot_server()
		return

	_boot_host()

## Listen-host boot path (Phase 32): a superset of the server path. The
## authoritative half is exactly `_boot_server()` — the same
## `chunk_manager.start()` / `refresh()` and `networking.host()` calls a
## headless dedicated server runs — so a listen host and a dedicated server can
## never drift apart. Everything after it is the host-only tail: presentation
## (player spawn, avatars, lighting, UI) plus the boot demos and the save/load
## sample. Those demos and that save are not presentation — they mutate
## authoritative state (a mined and a placed block, 4 Ashite, one combat round,
## slot 0 written and reloaded) — so what the two boots share is the same
## authoritative calls, not the same world state.
##
## Lighting, the minimap and the UI are built in `_ready()` behind a
## `not _is_server` guard, so they are host-only and need no second path here.
## `render_visuals` on the creature/player/tree slices is likewise
## decided in `_ready()` — a host calling `_boot_server()` still renders.
func _boot_host() -> void:
	_boot_server()

	# Player spawn — above the terrain surface so it doesn't spawn embedded in
	# (and fall through) the collision mesh.
	var spawn_xz := Vector2(16.0, 16.0)
	var ground_h := _terrain.get_height_at(spawn_xz)
	_player.spawn_at(Vector3(spawn_xz.x, ground_h + 1.0, spawn_xz.y))

	# Phase 33 — the local player's own record (position / HP / technologies) is
	# restored on top of the spawn point, so a restart puts the player back where
	# they logged off instead of at the world origin.
	_restore_local_player()

	# Chunk streaming (Phase 17) — the authoritative half above streamed the
	# window around the origin, so re-centre it on the spawn point. VoxelSlice
	# builds the mesh on chunk_ready and CreatureSlice spawns each chunk's
	# budget. `refresh()` skips the diff when the player is still in the chunk
	# it last centred on, so this is a no-op when spawn sits in the origin chunk.
	_chunk_manager.refresh()

	# Character system — the player's own avatar spawns at the player's real
	# position (it is synced to the controller every frame from here on, in
	# _process); a non-humanoid (quadruped) demo spawns alongside it to
	# exercise the appearance pipeline end to end. Phase 33 — the avatar is
	# rebuilt from the appearance recipe in the loaded player record when there
	# is one, so a restart keeps the character you were playing, not a default.
	var player_char := _restore_or_create_player_character(_player.get_position())
	_character.create_character("BoarRider", Vector3(spawn_xz.x - 3.0, ground_h + 1.0, spawn_xz.y))
	_character.set_player_character(player_char)

	# CreatureSlice already spawned each chunk's budget via ChunkManager (Phase 17).
	# Fire one combat round against the first spawned creature through the bus to
	# validate the combat pipeline end to end.
	var instances := _creature.get_all_instances()
	if instances.size() > 0:
		var first: Dictionary = instances[0]
		# Request one combat round against the first spawned creature via the bus
		# (the real trigger comes from player left-click; this validates the pipeline).
		GameBus.combat_round_requested.emit("player", first["instance_id"])

	# Mining & building — mine a surface block (biome material → inventory) and
	# place one back, proving the voxel edit API and material flow end to end.
	var mine_spot := Vector3(spawn_xz.x + 6.0, ground_h, spawn_xz.y + 2.0)
	_voxel.mine_block(mine_spot)
	_inventory.add_item("Ashite", 4)
	_voxel.set_place_material("Ashite")
	_voxel.place_block(Vector3(spawn_xz.x + 10.0, ground_h, spawn_xz.y + 2.0), Vector3.UP)

	if DEBUG:
		# Technology + crafting demo (DEBUG only): exercises the research and
		# station gates with expected-fail craft attempts and console output.
		var starter_kit := { "Ferrite": 10, "Thornwood": 6 }
		for item_id in starter_kit:
			_inventory.add_item(item_id, starter_kit[item_id])
		_crafting.set_skill("Smithing", "journeyman")
		_crafting.set_skill("Carpentry", "apprentice")

		GameBus.craft_requested.emit("RecipeFerriteIngot")      # FAIL: technology_locked

		GameBus.research_requested.emit("TechBasicSmithing")
		_technology.complete_research("TechBasicSmithing")
		GameBus.research_requested.emit("TechBasicCarpentry")
		_technology.complete_research("TechBasicCarpentry")

		GameBus.craft_requested.emit("RecipeFerriteIngot")      # FAIL: station_required:forge

		var ppos: Vector3 = _player.get_position()
		_station.place_station("forge", ppos + Vector3(2.0, 0.0, 0.0))
		_station.place_station("carpentry bench", ppos + Vector3(-2.0, 0.0, 0.0))

		GameBus.craft_requested.emit("RecipeFerriteIngot")
		GameBus.craft_requested.emit("RecipeFerriteIngot")
		GameBus.craft_requested.emit("RecipeThornwoodPlank")
		GameBus.craft_requested.emit("RecipeFerritePick")
		GameBus.craft_requested.emit("RecipeVoidRuneTablet")    # FAIL (skill guard + tech gate)

	# Persistence — save the initial world snapshot via the bus.
	var snapshot := {
		"timestamp": Time.get_ticks_msec(),
		"player":    {
			"name":     "Traveller",
			"position": [_player.get_position().x, _player.get_position().y, _player.get_position().z],
			"hp":       _player.get_hp(),
		},
		"inventory": _inventory.get_contents(),
		"inventory_durability": _inventory.get_durability_data(),
		"world":     {
			"chunks":       _voxel.get_chunk_manifest(),
			"dirty_chunks": _voxel.get_dirty_chunk_keys(),
		},
		"technology": _technology.get_statuses(_registry.local_player_id),
		"market": _market.get_market_data(),
		"governance": _proposal.get_governance_data(),
		"trade": _trade.get_trade_data(),
	}
	GameBus.save_requested.emit(0, snapshot)
	GameBus.load_requested.emit(0)

	# Phase 33 — write the AUTHORITATIVE records (world + one record per player)
	# on top of the legacy slot file above. The slot file is the single-file
	# sample the client-side path and the older tests use; the server records are
	# what an authoritative boot loads.
	_save_everything(false)

## Client boot path (Phase 18): do NOT run the authoritative simulation. Join
## the host and wait for the world snapshot before showing anything.
##
## Phase 33 — the client presents the id it cached from a previous session, so
## the host can re-bind it to the same record. The record itself never leaves the
## host; the client only ever holds the id.
func _boot_client() -> void:
	_networking.claimed_player_id = _persistence.load_client_identity()
	var err: Error = _networking.join(_host_address, _networking.DEFAULT_PORT)
	if err != OK:
		push_error("[Networking] client failed to connect to %s — %s" % [_host_address, error_string(err)])
		_snapshot_pending = false
		return
	_snapshot_pending = true
	_snapshot_elapsed = 0.0
	_handshake_elapsed = 0.0
	_handshake_retries = 0

## Headless dedicated-server boot (Phase 27): run the authoritative simulation
## with no local player presentation. Streams the world around the origin and
## opens the host so clients can connect. No avatar, lighting, or demo.
##
## Phase 33 makes this the ONE place the world is loaded from disk. Every
## authoritative process (dedicated server and listen host alike) inherits it,
## because _boot_host() calls this first — the same "one authoritative boot"
## rule Phase 32 established. Order matters:
##
##   1. read the world record + player records off disk,
##   2. start/refresh chunk streaming (this is what SPAWNS the creature
##      population and builds the chunk manifests),
##   3. re-apply the recorded creature state on top of the fresh spawn — a
##      recorded death/respawn deadline is only meaningful once the instance
##      exists again,
##   4. open the host socket.
func _boot_server() -> void:
	_load_world_records()
	_chunk_manager.start()
	_chunk_manager.refresh()
	_apply_loaded_creature_state()
	_networking.host(_networking.DEFAULT_PORT, _networking.DEFAULT_MAX_CLIENTS)

## Phase 33 — host: an identity was bound (first join, or a reconnect). The peer's
## own inventory is now known, so register it as that peer's trade/market party (the
## party id the client's "player" self-reference resolves to) and send its world
## snapshot.
##
## The snapshot is sent HERE, on the handshake, and NOT also on `peer_connected`.
## It used to be sent twice — once on connect, once on join — so every reconnecting
## client paid for a full world snapshot twice, and the FIRST one was the worse of
## the two: it was built before the peer's identity was resolved, so it carried no
## own-record and was immediately replaced. One snapshot, with the identity in hand.
func _on_player_joined(peer_id: int, player_id: String, reconnected: bool) -> void:
	if _is_client:
		return
	var inv = _registry.get_inventory(player_id)
	if inv != null:
		_trade.set_party_inventory(player_id, inv)
		_market.set_party_inventory(player_id, inv)
	# Phase 34 — the peer's technology tree is part of its record, so hand it to the
	# slice before the snapshot goes out: a reconnecting peer resumes its own
	# "researching"/"unlocked" statuses (and the research timer for a status restored
	# mid-research), and a first join gets a seeded, all-locked tree.
	var tech: Variant = _registry.get_record(player_id).get("technology", {})
	if tech is Dictionary:
		_technology.apply_statuses(tech, player_id)
	print("[Server] %s player '%s' as %s" % ["reconnected" if reconnected else "joined", player_id, "peer_%d" % peer_id])
	_networking.send_snapshot(peer_id, _build_snapshot(peer_id))

## Phase 33 — host: a connection came up. There is deliberately nothing to send yet:
## the peer's identity has not been resolved, so a snapshot here would carry no
## own-record and would have to be replaced by the handshake snapshot (see
## _on_player_joined). Kept as the single place to note when a peer appears.
func _on_peer_connected(_peer_id: int) -> void:
	pass

## Phase 33 — client: the host told us which record we are. Cache the id so the
## next connection can claim it, and read our own state out of it.
func _on_player_identity_assigned(player_id: String) -> void:
	if not _is_client or player_id.is_empty():
		return
	_persistence.save_client_identity(player_id)
	print("[Client] identity assigned: %s" % player_id)

## Phase 33 — host: a connection dropped. Write the player's record before the
## transport mapping is discarded; the record stays on DISK (and is re-loaded
## lazily on the reconnect claim), so the same player_id reconnects to the same
## inventory, position, and HP.
##
## The in-memory record and the player's inventory node are then RELEASED
## (`evict_player`): keeping them was what made the registry grow with every peer
## that had ever connected. Order matters — fold, write, unbind, then evict — so
## the durable copy is complete before the only reference to the live one goes.
## The party bindings in trade/market are dropped with it: they hold a raw node
## reference, and a freed node is not null.
func _on_peer_disconnected(peer_id: int) -> void:
	if _is_client:
		return
	var player_id := _registry.get_player_id(peer_id)
	if player_id.is_empty():
		return
	_fold_last_known_state(peer_id, player_id)
	_persistence.save_player(player_id, _registry.get_player_data(player_id))
	_registry.unbind_peer(peer_id)
	# A stale AOI cell for a peer_id ENet may hand to the next connection would
	# suppress that peer's very first re-scoped snapshot.
	_peer_aoi_regions.erase(peer_id)
	_trade.clear_party_inventory(player_id)
	_market.clear_party_inventory(player_id)
	_registry.evict_player(player_id)
	GameBus.player_left.emit(player_id)

## Fold everything the host knows about a LIVE remote peer into its registry record:
## its last-reported position.
##
## Position is guarded by has_last_known_state() — get_last_known_state() answers
## Vector3.ZERO for BOTH "at the origin" and "never reported", so writing it
## unconditionally would reset a returning player's record to the world origin
## from a peer that connected but never sent a state packet.
##
## HP is deliberately NOT folded. The HP the host holds for a remote peer is the
## value that peer declared on the wire (`player_moved`), and the host has no
## simulation of that peer to check it against, so writing it into a durable
## record made a client-declared number survive a reconnect, a restart and every
## later save — a durable, restart-proof cheat. `PlayerRegistry.record_hp` refuses
## it at the choke point too; this call site is gone rather than left as a silent
## no-op. Only the LOCAL player's host-simulated HP is persisted.
func _fold_last_known_state(peer_id: int, player_id: String) -> void:
	if _networking.has_last_known_state(peer_id):
		_registry.record_position(player_id, _networking.get_last_known_state(peer_id))

## Phase 33 — fold every ONLINE remote peer's last-known position into its record.
## This runs on every autosave, not only at disconnect: a peer whose process
## is KILLED (or whose host is) never reaches _on_peer_disconnected, so the durable
## record would otherwise still hold whatever was loaded from disk — a returning
## player resurrected at the world origin. The autosave interval is now the bound
## on how much of a remote peer's live position a hard kill can lose. (Its HP is
## not folded at all — see _fold_last_known_state.)
func _snapshot_remote_players() -> void:
	for peer_id in _networking.get_last_known_states():
		var player_id := _registry.get_player_id(int(peer_id))
		if player_id.is_empty():
			continue
		_fold_last_known_state(int(peer_id), player_id)

## Phase 29 — a client's movement may carry it into a new area of interest.
## When the AOI grid cell changes, re-send a scoped snapshot so the client gains
## the entities now in range — including static creatures that were never
## "dirty" and therefore never re-broadcast as a delta.
func _on_remote_player_state(peer_id: int, position: Vector3) -> void:
	if _is_client:
		return
	var region: Vector2i = _networking.aoi_region(position)
	if _peer_aoi_regions.get(peer_id, null) == region:
		return
	_peer_aoi_regions[peer_id] = region
	# Phase 33 — world/entity data only: the peer's own record is NOT re-sent, or
	# the client would re-apply a stale position/HP/inventory on every region
	# crossing (the record is written at load and at disconnect, not per frame).
	_networking.send_snapshot(peer_id, _build_snapshot(peer_id, false))

func _process(delta: float) -> void:
	_sync_player_avatar(delta)
	# Distance-driven LOD (Phase 23) — evaluate each character's world distance
	# to the player each frame and swap fine detail / the impostor billboard in
	# and out. No-op until characters exist and on clients (no spawned visuals).
	_character.update_lod(_player.get_position())

	# Phase 33 — settle a COMPLETED save worker before the lifecycle tick can
	# start another one: a failed write is then reported within a frame instead of
	# at the start of the next autosave, and its dirty chunks go back immediately.
	_poll_save_completion()

	# Phase 33 — authoritative save lifecycle: the autosave interval plus the
	# shutdown-request poll (each on its own cadence). Must run before the
	# snapshot-pending early return.
	_tick_save_lifecycle(delta)

	if not _snapshot_pending:
		return
	_tick_client_handshake(delta)

## Client-side: wait for the host's world snapshot, re-presenting the join intent
## while it does not arrive. The handshake is the only route to an identity and a
## world, and it used to be fire-and-forget: one lost join_intent — or one lost
## snapshot — left a fully connected client with nothing and no way to ask again.
## Each retry re-sends the intent (a fresh seq, so the host's dedup passes it) and
## the host re-answers an already-bound peer (see
## PlayerRegistry.resolve_identity), so the retry re-delivers the snapshot.
func _tick_client_handshake(delta: float) -> void:
	_snapshot_elapsed += delta
	_handshake_elapsed += delta
	if _handshake_elapsed >= HANDSHAKE_RETRY_SECS and _handshake_retries < MAX_HANDSHAKE_RETRIES:
		_handshake_elapsed = 0.0
		_handshake_retries += 1
		push_warning("[Networking] no world snapshot after %.1fs — re-presenting join intent (retry %d/%d)" % [
			HANDSHAKE_RETRY_SECS, _handshake_retries, MAX_HANDSHAKE_RETRIES])
		_networking.request_handshake()
	if _snapshot_elapsed >= SNAPSHOT_TIMEOUT:
		push_error("[Networking] world snapshot timed out after %.1fs — giving up" % SNAPSHOT_TIMEOUT)
		_snapshot_pending = false

## Drive the player's visual avatar from the real player controller every
## frame — position/facing, locomotion state, and approximate foot IK
## (characters.md §37). Only the host currently spawns character visuals
## (_boot_host), so this is a no-op on clients until one exists.
func _sync_player_avatar(delta: float) -> void:
	var player_char: String = _character.get_player_character()
	if player_char == "":
		return
	var vel: Vector3 = _player.get_velocity()
	_character.sync_player_avatar(
		player_char,
		_player.get_position(),
		Vector3(vel.x, 0.0, vel.z),
		vel.y,
		_player.is_grounded(),
		delta,
		_terrain.get_height_at
	)

func _on_connection_failed() -> void:
	if not _is_client:
		return
	push_error("[Networking] connection to host failed")
	_snapshot_pending = false

func _on_server_disconnected() -> void:
	if not _is_client:
		return
	push_error("[Networking] disconnected from host")
	_snapshot_pending = false

## Host-side: serialize authoritative world state for a connecting client,
## AOI-scoped (Phase 29) — only entities within the peer's area of interest are
## sent, so the initial payload scales with local density, not world population.
##
## Phase 33 — the inventory half is the CONNECTING PEER's own record, not the
## host's: inventory is per-player now, and shipping the host's contents would
## hand every client the host's items.
##
## `include_own_record` is TRUE only for the join/reconnect snapshot. The record is
## a durability artifact, not a live feed (see
## PersistenceSlice.snapshot_carries_own_record), and the client applies whatever
## it receives as authoritative — so carrying a stale record on an AOI re-scope
## would teleport the client to its last-saved position and roll its inventory and
## technology back to that instant.
func _build_snapshot(peer_id: int, include_own_record: bool = true) -> Dictionary:
	var players := {}
	var host_pos := _player.get_position()
	if _networking.in_aoi(peer_id, host_pos):
		players[str(multiplayer.get_unique_id())] = [host_pos.x, host_pos.y, host_pos.z]
	# Phase 19 — include last-known remote player states so a rejoining client
	# resumes from its last authoritative position after a disconnect.
	var last_known := _networking.get_last_known_states()
	for pid in last_known:
		var last_pos: Vector3 = last_known[pid]
		if _networking.in_aoi(peer_id, last_pos):
			players[str(pid)] = [last_pos.x, last_pos.y, last_pos.z]
	var player_id := _registry.get_player_id(peer_id)
	var snapshot := {
		"heightmaps": _voxel.get_heightmaps(),
		"edits":     _voxel.get_chunk_manifest(),
		"creatures": _scoped_creatures(peer_id),
		"stations":  _station.get_station_data(),
		"market":    _market.get_market_data(),
		"governance": _proposal.get_governance_data(),
		"trade":     _trade.get_trade_data(),
		"players":   players,
	}
	# The peer's own record exists only once the host resolved its identity, and it
	# is shipped only on the handshake snapshot — an AOI re-scope omits the keys
	# entirely, so the client keeps the state it already holds.
	if PersistenceSlice.snapshot_carries_own_record(include_own_record, player_id):
		var own := _registry.get_player_data(player_id)
		snapshot["inventory"] = own.get("inventory", {})
		snapshot["inventory_durability"] = own.get("inventory_durability", {})
		snapshot["technology"] = own.get("technology", {})
		snapshot["player"] = { "position": own.get("position", []), "hp": own.get("hp", -1.0) }
	return snapshot

## Phase 29 — the creature subset of the snapshot, filtered to the joining
## peer's AOI so a client seeds only the population it can actually see.
func _scoped_creatures(peer_id: int) -> Array:
	var out: Array = []
	for c in _creature.get_snapshot_creatures():
		var arr = c.get("position", [0.0, 0.0, 0.0])
		var pos := Vector3.ZERO
		if arr is Array and arr.size() >= 3:
			pos = Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
		if _networking.in_aoi(peer_id, pos):
			out.append(c)
	return out

## Client-side: apply the host's world snapshot and begin rendering.
func _on_world_snapshot_received(data: Dictionary) -> void:
	if not _is_client:
		return
	if data.has("heightmaps") and data["heightmaps"] is Dictionary:
		var heightmaps: Dictionary = data["heightmaps"]
		_voxel.apply_heightmaps(heightmaps)
		# Trees are placed deterministically from the chunk coordinate, so a
		# client seeds its own rather than receiving them in the snapshot; only a
		# tree's chopped/standing STATE is replicated (tree_chopped /
		# tree_respawned). Mirrors the deterministic creature hash, which also
		# needs no per-entity placement payload.
		for ckey in heightmaps:
			_tree.spawn_for_chunk(_chunk_key_to_pos(str(ckey)))
	if data.has("edits") and data["edits"] is Dictionary:
		_voxel.apply_chunk_manifest(data["edits"])
	# Phase 33 — stations and the client's OWN record (position / HP /
	# technologies). Stations are world data, so a client mirrors the host's set.
	if data.has("stations") and data["stations"] is Array:
		_station.apply_station_data(data["stations"])
	if data.has("technology") and data["technology"] is Dictionary:
		# A client has no registry identity: its own tree is the only one it holds,
		# which is the "" bucket resolve_player() falls back to.
		_technology.apply_statuses(data["technology"], _registry.local_player_id)
	var own: Variant = data.get("player", {})
	if own is Dictionary:
		var arr = own.get("position", [])
		if arr is Array and (arr as Array).size() >= 3:
			_player.spawn_at(Vector3(float(arr[0]), float(arr[1]), float(arr[2])))
		var hp := float(own.get("hp", -1.0))
		if hp >= 0.0:
			_player.set_hp(hp)
	if data.has("creatures") and data["creatures"] is Array:
		_creature.apply_snapshot_creatures(data["creatures"])
	if data.has("inventory") and data["inventory"] is Dictionary:
		_inventory.replace_contents(data["inventory"], data.get("inventory_durability", {}))
	if data.has("market") and data["market"] is Dictionary:
		_market.apply_market_data(data["market"])
	if data.has("governance") and data["governance"] is Dictionary:
		_proposal.apply_governance_data(data["governance"])
	if data.has("trade") and data["trade"] is Dictionary:
		_trade.apply_trade_data(data["trade"])
	if data.has("players") and data["players"] is Dictionary:
		for pid in data["players"]:
			var pos = data["players"][pid]
			if pos is Array and pos.size() >= 3:
				GameBus.remote_player_state.emit(int(pid), Vector3(float(pos[0]), float(pos[1]), float(pos[2])))
	_snapshot_pending = false

# ---------------------------------------------------------------------------
# Phase 33 — authoritative persistence lifecycle
# ---------------------------------------------------------------------------

## Accumulate the autosave timer and honour a shutdown request. Authoritative
## roles only: a client neither loads a world nor writes one — its state arrives
## in the host's AOI-scoped snapshot (Phase 29).
##
## The shutdown-request file is polled on its OWN cadence (`shutdownPollSeconds`,
## seconds by default), NOT on the autosave tick: it used to be gated behind
## `autosaveIntervalSeconds` (300 s), so a restart request sat unread for up to
## five minutes. An orchestrator that writes the request and sigkills after a
## short grace period therefore killed the server before it saved, losing up to a
## full autosave interval per restart. It is still not a per-frame
## `FileAccess.file_exists()` (the file is written at most once), so the separate
## short cadence keeps the "don't stat every frame" fix while bounding the
## shutdown latency to `shutdownPollSeconds` instead of the autosave interval.
func _tick_save_lifecycle(delta: float) -> void:
	if _is_client:
		return
	_shutdown_poll_elapsed += delta
	if PersistenceSlice.poll_due(_shutdown_poll_elapsed, _persistence.shutdown_poll_interval):
		_shutdown_poll_elapsed = 0.0
		if FileAccess.file_exists(_persistence.shutdown_request_path):
			print("[Server] shutdown requested — saving before quit")
			_save_everything(true)
			_flush_save()
			DirAccess.remove_absolute(_persistence.shutdown_request_path)
			get_tree().quit()
			return
	_autosave_elapsed += delta
	if not PersistenceSlice.autosave_due(_autosave_elapsed, _persistence.autosave_interval):
		return
	_autosave_elapsed = 0.0
	_save_everything(true)

## Write the world record plus one record per player. `incremental` merges only the
## dirty chunk manifests into the record already on disk, so a periodic autosave does
## not re-serialize every loaded chunk.
##
## Authoritative roles only — this is the single choke point for every caller
## (boot, autosave, window close, shutdown request). A client owns no world and no
## records: it holds a cached player_id and receives its state from the host, so
## writing here would drop a client-side `world.json` into `user://saves/server/`
## that a later host boot would load as authoritative (client state, no world).
## `_notification()` runs on a client too — `auto_accept_quit` only decides whether
## the engine also quits, not whether the notification is delivered.
##
## The write itself runs on a worker thread (see _start_save_thread): this function
## only COLLECTS the payload, which is the part that reads live slice state and so
## has to happen on the main thread. Callers that must not outrun their write
## (shutdown) call _flush_save() afterwards.
func _save_everything(incremental: bool) -> void:
	if _is_client:
		return
	_reap_save_thread()
	_snapshot_local_player()
	_snapshot_remote_players()
	_start_save_thread(_collect_save_job(incremental))

## Fold the local player's LIVE state into its registry record before a write.
func _snapshot_local_player() -> void:
	var pid := _registry.local_player_id
	if pid.is_empty():
		return
	_registry.record_position(pid, _player.get_position())
	_registry.record_hp(pid, _player.get_hp())
	_registry.record_technology(pid, _technology.get_statuses(pid))
	# Appearance is part of the identity ("owning their inventory, HP, position,
	# and appearance"): the character's recipe is stored, not its visual nodes.
	var char_id := _character.get_player_character()
	if char_id != "":
		_registry.record_appearance(pid, _character.get_appearance(char_id))

# ---------------------------------------------------------------------------
# Phase 33 — the off-thread save
# ---------------------------------------------------------------------------
#
# Serializing the world record is expensive (every loaded chunk manifest, every
# creature, every station) and it used to run inline inside _process on the
# autosave tick, so one frame in every `autosaveIntervalSeconds` stalled on JSON
# encode + file write. The record is now written by a `Thread`.
#
# Only the WRITE moved. Building the payload still happens on the main thread,
# because that is the half that reads live slice state (voxel edits, stations,
# creatures, inventories) and touching nodes from a worker is not safe. What the
# worker gets is a deep copy of plain data, so nothing it reads can be mutated
# underneath it.

## In-flight save worker, or null. Only one is ever pending: a new save reaps the
## previous one first, so two writers can never interleave on the same files.
var _save_thread: Thread = null
## What the in-flight write was given: the dirty chunk keys it serialized (so its
## completion can clear exactly those, or re-mark them when the write failed), plus
## the counts the completion line reports. Kept as a bundle because the completion
## happens later than the collection and must not read live slice state again.
var _save_summary: Dictionary = {}

func _collect_save_job(incremental: bool) -> Dictionary:
	var manifest := _voxel.get_chunk_manifest()
	var dirty := _voxel.get_dirty_chunk_keys()
	# An incremental save carries ONLY the dirty chunk manifests; save_world() then
	# merges them into the record already on disk. The rest of the world (stations,
	# creatures) is small and always rewritten.
	if incremental:
		manifest = PersistenceSlice.dirty_chunk_subset(manifest, dirty)
	var creatures := _creature.get_snapshot_creatures()
	var stations := _station.get_station_data()
	var world := {
		"timestamp":       Time.get_unix_time_from_system(),
		"local_player_id": _registry.local_player_id,
		"chunks":          manifest,
		"stations":        stations,
		"creatures":       creatures,
	}
	# NOTE: no `dirty_chunks` key. It used to ride the record, but nothing ever read
	# it back — dirty tracking lives in memory (VoxelSlice) and is reset by the save
	# that consumed it, so writing the list to disk only made the record bigger.
	var players := {}
	# ONLINE players only (see PlayerRegistry.get_online_player_ids): an offline
	# player's record is already durable and cannot have changed since it was
	# written, so rewriting every long-gone player on every autosave was pure churn —
	# the write cost grew with the number of players who had EVER joined.
	for pid in _registry.get_online_player_ids():
		var player_id := str(pid)
		players[player_id] = _registry.get_player_data(player_id)
	# The clear happens HERE, on the main thread, in the same synchronous step that
	# read the dirty set: an edit made while the worker writes re-marks its chunk and
	# is carried by the next save. Clearing after the write landed would need a
	# second, racy bookkeeping pass; clearing before it but on failure re-marking is
	# exact in both directions.
	_voxel.clear_dirty_chunk_keys(dirty)
	_save_summary = {
		"dirty":       dirty,
		"incremental": incremental,
		"chunks":      manifest.size(),
		"creatures":   creatures.size(),
		"stations":    stations.size(),
		"players":     players.size(),
	}
	return { "world": world, "incremental": incremental, "players": players }

func _start_save_thread(job: Dictionary) -> void:
	# Deep-copied before it crosses the thread boundary: the payload holds references
	# into live records (positions, appearance, technology), and the worker must not
	# be able to read state the main thread is still writing.
	job = job.duplicate(true)
	_save_thread = Thread.new()
	var err := _save_thread.start(_persistence.write_job.bind(job))
	if err != OK:
		# No thread available (or the OS refused one). Fall back to writing inline:
		# a stalled frame beats a save that never happened.
		push_error("[Server] save thread failed to start (%s) — saving inline" % error_string(err))
		_save_thread = null
		_finish_save(_persistence.write_job(job))
		return
	print("[Server] world save started (threaded)")

## Wait for the in-flight write, report it, and settle the dirty-chunk bookkeeping.
## Exactly one place reads the worker's result, so the success and failure paths
## cannot drift. Runs on the main thread (Thread.wait_to_finish blocks, which is why
## only the shutdown paths call it directly).
func _reap_save_thread() -> void:
	if _save_thread == null:
		return
	_finish_save(int(_save_thread.wait_to_finish()))
	_save_thread = null

## Reap the save worker as soon as it has FINISHED, without blocking.
##
## Before this, the only reaper was `_reap_save_thread()` at the START of the next
## `_save_everything()`, so a failed write was discovered up to one whole autosave
## interval late — and the chunks it had serialized had already been cleared from
## the dirty set at collection time. In that window the edits looked saved and
## were not, and a process that died inside it lost them with no error reported.
## `Thread.is_alive()` is false the moment the worker returns, so this costs one
## bool per frame and reuses the same single reaper (no second result path).
func _poll_save_completion() -> void:
	if _save_thread == null or _save_thread.is_alive():
		return
	_reap_save_thread()

## Block until the in-flight write has landed. Shutdown (window close, the polled
## shutdown-request file, process exit) must not outrun its own save.
func _flush_save() -> void:
	_reap_save_thread()

func _finish_save(result: int) -> void:
	if result != OK:
		push_error("[Server] world save failed — %s" % error_string(result))
		GameBus.world_save_failed.emit(error_string(result))
		# The dirty set was cleared when the payload was collected, so a failed write
		# has to put its chunks back or the next save would skip them.
		_voxel.mark_dirty_chunks(_save_summary.get("dirty", []))
		_save_summary = {}
		return
	print("[Server] world saved (%s) — %d chunk manifest(s), %d creature(s), %d station(s), %d player record(s)" % [
		"incremental" if bool(_save_summary.get("incremental", false)) else "full",
		int(_save_summary.get("chunks", 0)),
		int(_save_summary.get("creatures", 0)),
		int(_save_summary.get("stations", 0)),
		int(_save_summary.get("players", 0)),
	])
	_save_summary = {}
	GameBus.world_saved.emit()

## A pending save must not be dropped when the process goes away (a `--quit` boot
## exits long before the autosave interval). `Thread` also has to be waited for
## before it is freed, so this is both the correctness and the lifecycle hook.
func _exit_tree() -> void:
	_flush_save()

## Bind the local (authoritative) player's identity and inventory. The id comes
## from the world record when a previous process minted one, so identity is as
## persistent as the world; otherwise a fresh id is minted here. Binding the
## game's own `_inventory` is what makes the local player's inventory per-player
## without touching any existing call site.
func _bind_local_identity() -> void:
	var pid := str(_loaded_world.get("local_player_id", ""))
	if pid.is_empty():
		pid = _registry.mint_player_id()
	_registry.set_local_player(pid, _inventory)

## Rebuild the local avatar from the appearance recipe in the saved player
## record, or create the default appearance when the record has none (a fresh
## world). Returns the character instance id.
func _restore_or_create_player_character(pos: Vector3) -> String:
	var pid := _registry.local_player_id
	var appearance: Variant = _registry.get_record(pid).get("appearance", {}) if not pid.is_empty() else {}
	if appearance is Dictionary and not (appearance as Dictionary).is_empty():
		var restored: String = _character.create_character_from_recipe(appearance, pos)
		if restored != "":
			return restored
	return _character.create_character("TravellerHuman", pos)

## Restore the local player's position, HP, and technologies from its record.
## Called AFTER the spawn point is set, so the record wins over the spawn.
func _restore_local_player() -> void:
	var pid := _registry.local_player_id
	if pid.is_empty():
		return
	var rec := _registry.get_record(pid)
	var arr = rec.get("position", [])
	if arr is Array and (arr as Array).size() >= 3:
		_player.spawn_at(Vector3(float(arr[0]), float(arr[1]), float(arr[2])))
	var hp := float(rec.get("hp", -1.0))
	if hp >= 0.0:
		_player.set_hp(hp)
	var tech: Variant = rec.get("technology", {})
	if tech is Dictionary and not (tech as Dictionary).is_empty():
		_technology.apply_statuses(tech, pid)

## Read the world record and the LOCAL player's record off disk. A missing world
## record is NOT an error — a server with no save boots a fresh world.
##
## Chunk manifests and stations are applied here (pure data). The creature state
## is applied by _apply_loaded_creature_state() AFTER chunk streaming, because
## spawn_for_chunk() builds fresh instance records.
##
## Only the local player's record is read at boot. Every OTHER record on disk used
## to be loaded here too, and the registry never evicts — so a server that had seen
## a thousand players held a thousand records, their inventories and all, in memory
## for the whole session, whether or not any of them ever came back. A record is now
## brought in on demand: the registry is given a reader (set_record_loader) and pulls
## one in the first time a peer CLAIMS it (a reconnect). That is the only moment a
## remote record is needed.
func _load_world_records() -> void:
	_loaded_world = _persistence.load_world()
	_bind_local_identity()
	# Lazy reader for every other player's record (see the docstring above).
	_registry.set_record_loader(_persistence.load_player)
	if _loaded_world.is_empty():
		print("[Server] no world record at %s — booting a fresh world" % _persistence.world_path())
	else:
		var chunks: Variant = _loaded_world.get("chunks", {})
		if chunks is Dictionary and not (chunks as Dictionary).is_empty():
			_voxel.apply_chunk_manifest(chunks)
		_station.apply_station_data(_loaded_world.get("stations", []))
		print("[Server] world loaded from %s" % _persistence.world_path())
	# The local player's record: position, HP, inventory (with per-instance
	# durability), and technology. It lands in the game's own slices because
	# _bind_local_identity() ran first.
	_load_local_player_record()

func _load_local_player_record() -> void:
	var pid := _registry.local_player_id
	if pid.is_empty():
		return
	var record := _persistence.load_player(pid)
	if record.is_empty():
		return
	_registry.apply_player_data(pid, record)
	print("[Server] restored the local player record '%s'" % pid)

## Re-apply the recorded creature state (state, HP, and the wall-clock respawn
## deadline) over the population chunk streaming just spawned. `apply_recorded_…`
## (not the client's `apply_snapshot_creatures`) so a record for a chunk outside
## the current view window is skipped instead of fabricating an instance.
func _apply_loaded_creature_state() -> void:
	var creatures: Variant = _loaded_world.get("creatures", [])
	if not (creatures is Array) or (creatures as Array).is_empty():
		return
	_creature.apply_recorded_creature_states(creatures)

# ---------------------------------------------------------------------------
# Bus listeners
# ---------------------------------------------------------------------------

## Parse a "cx,cz" chunk key (as used by the world snapshot's heightmap map)
## back into a chunk coordinate.
func _chunk_key_to_pos(key: String) -> Vector2i:
	var parts: PackedStringArray = key.split(",")
	if parts.size() < 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))

func _on_chunk_ready(chunk_pos: Vector2i, heightmap: Array) -> void:
	pass

func _on_combat_resolved(result: Dictionary) -> void:
	pass

## Drive the player avatar's attack animation whenever the player attacks.
func _on_combat_round_requested(attacker_id: String, defender_id: String) -> void:
	if attacker_id == "player" and _character.get_player_character() != "":
		GameBus.character_attack_requested.emit(_character.get_player_character())

func _on_creature_died(entity_id: String, position: Vector3, killer_id: String) -> void:
	pass

func _on_creature_spawned(instance_id: String, creature_id: String, position: Vector3) -> void:
	pass

func _on_loot_dropped(pickup_id: String, item_id: String, position: Vector3, quantity: int) -> void:
	pass

func _on_item_picked_up(item_id: String, quantity: int) -> void:
	pass

func _on_player_state_changed(payload: Dictionary) -> void:
	pass   # logged by PlayerSlice; suppress repetitive output here

func _on_inventory_full() -> void:
	pass

func _on_character_spawned(instance_id: String, skeleton_id: String, position: Vector3) -> void:
	pass

## Phase 34 — a craft the host resolved for a REMOTE peer changed that peer's own
## record. Its client only ever mirrors its own state from a snapshot, so without
## this push it would keep showing the pre-craft inventory until the next AOI
## re-scope or reconnect. Scoped to that peer; the local player is already live
## here. (Craft got the same fix as the two new actions: it had the identical gap.)
func _on_craft_resolved(result: Dictionary) -> void:
	_sync_peer_own_state(result)

## Phase 34 — the repair half of the same rule.
func _on_repair_resolved(result: Dictionary) -> void:
	_sync_peer_own_state(result)

## Phase 34 — research: fold the researcher's new statuses into its record first, so
## the durable copy and the copy pushed to its client cannot diverge, then push.
func _on_research_resolved(result: Dictionary) -> void:
	if _is_client:
		return
	var pid := str(result.get("player_id", ""))
	if pid != "":
		_registry.record_technology(pid, _technology.get_statuses(pid))
	_sync_peer_own_state(result)

func _on_technology_unlocked(_tech_id: String, _player_id: String) -> void:
	pass

## Host → the peer whose own record just changed. Nothing to do for a local player
## (its state is already live in this process) and nothing to send for a failed
## action (nothing changed).
func _sync_peer_own_state(result: Dictionary) -> void:
	if _is_client:
		return
	if not bool(result.get("success", false)):
		return
	var pid := str(result.get("player_id", ""))
	if pid == "" or pid == _registry.local_player_id:
		return
	var peer := _registry.get_peer_id(pid)
	if peer == 0:
		return
	_networking.send_own_state(peer, _own_state_payload(pid))

## The slice of `player_id`'s record its own client mirrors: inventory contents with
## per-instance durability, plus its technology statuses. Position and HP are
## deliberately absent — they are host-simulated and ride the normal player-state
## path, and re-sending a stored position here would teleport the peer back to it.
func _own_state_payload(player_id: String) -> Dictionary:
	var own := _registry.get_player_data(player_id)
	return {
		"inventory": own.get("inventory", {}),
		"inventory_durability": own.get("inventory_durability", {}),
		"technology": own.get("technology", {}),
	}

## Client-side: the host changed our own record while acting on our behalf (a craft,
## repair, or research we asked for). Applied exactly like the like-named keys of the
## join snapshot.
func _on_own_state_synced(data: Dictionary) -> void:
	if not _is_client:
		return
	if data.has("inventory") and data["inventory"] is Dictionary:
		_inventory.replace_contents(data["inventory"], data.get("inventory_durability", {}))
	if data.has("technology") and data["technology"] is Dictionary:
		_technology.apply_statuses(data["technology"], _registry.local_player_id)

func _on_trade_completed(trade: Dictionary) -> void:
	pass

func _on_block_mined(material: String, quantity: int, position: Vector3) -> void:
	pass

func _on_block_placed(material: String, position: Vector3) -> void:
	pass

func _on_player_damaged(damage: float, attacker_id: String) -> void:
	pass

func _on_player_died(position: Vector3, killer_id: String) -> void:
	if _character.get_player_character() != "":
		GameBus.character_death_requested.emit(_character.get_player_character())

func _on_player_respawned(position: Vector3) -> void:
	pass

func _on_save_completed(slot: int) -> void:
	# NOTHING to reset here. The legacy slot file is a single-file sample (the
	# boot/client record), not the authoritative world record, so writing it does
	# NOT make the chunk manifests durable — only an authoritative world save does,
	# and that save clears the keys it serialized itself (see `_collect_save_job`;
	# the clear has to happen where the payload is read, because the write is off
	# the main thread). Clearing here would silently drop the edits made before the
	# slot write from the next world save.
	pass

func _on_load_completed(slot: int, data: Dictionary) -> void:
	if data.has("inventory") and data["inventory"] is Dictionary:
		# A MISSING `inventory_durability` key is the intentional old-save signal:
		# saves written before per-instance durability carried no per-instance
		# wear, so `replace_contents` correctly grants fresh (pristine) durable
		# instances rather than resurrecting stale local wear.
		_inventory.replace_contents(data["inventory"], data.get("inventory_durability", {}))
	var world: Dictionary = data.get("world", {})
	if world.has("chunks"):
		_voxel.apply_chunk_manifest(world["chunks"])
	elif world.has("voxel_edits"):
		_voxel.apply_edits(world["voxel_edits"], world.get("voxel_materials", {}))
	if data.has("technology"):
		_technology.apply_statuses(data["technology"], _registry.local_player_id)
	# Phase 33 — the snapshot carries the player's own record: position is set
	# FIRST (spawn_at), then HP, so the restored body sits where the record says.
	var player_data: Variant = data.get("player", {})
	if player_data is Dictionary and not _is_client:
		var arr = player_data.get("position", [])
		if arr is Array and (arr as Array).size() >= 3:
			_player.spawn_at(Vector3(float(arr[0]), float(arr[1]), float(arr[2])))
		var hp := float(player_data.get("hp", -1.0))
		if hp >= 0.0:
			_player.set_hp(hp)
	if data.has("market"):
		_market.apply_market_data(data["market"])
	if data.has("governance"):
		var gov: Variant = data["governance"]
		if gov is Dictionary:
			_proposal.apply_governance_data(gov)
		elif gov is Array:
			# Backward compat: older saves stored only the decisions log.
			_proposal.apply_decisions_log(gov)
	if data.has("trade"):
		var tr: Variant = data["trade"]
		if tr is Dictionary:
			_trade.apply_trade_data(tr)

# ---------------------------------------------------------------------------
# GameData smoke test
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
				push_error("%s → %s FAILED" % [reg_name, key])
