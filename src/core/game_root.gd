extends Node
## Game root — integration layer that owns all slices and wires them together.
##
## Slices communicate exclusively through GameBus signals. This script
## instantiates slices, sets cross-slice references that cannot travel the bus,
## and drives the startup sequence (tests → GameData check → terrain boot).
const WorldPos := preload("res://src/terrain/world_pos.gd")
const RebaseDriver := preload("res://src/terrain/rebase_driver.gd")
const EquipmentRules := preload("res://src/character/equipment_rules.gd")
const Diag := preload("res://src/core/diag.gd")
const LocaleSettings := preload("res://src/core/locale_settings.gd")

const TerrainSlice     := preload("res://src/terrain/terrain_slice.gd")
const WorldShape       := preload("res://src/terrain/world_shape.gd")
const VoxelSlice       := preload("res://src/terrain/voxel_slice.gd")
const ChunkManager     := preload("res://src/terrain/chunk_manager.gd")
const ChunkRecordSync  := preload("res://src/terrain/chunk_record_sync.gd")
const ChunkRecords     := preload("res://src/terrain/chunk_records.gd")
const RegionStreamer   := preload("res://src/persistence/region_streamer.gd")
const DistantTerrain   := preload("res://src/terrain/distant_terrain.gd")
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
const TamingSlice      := preload("res://src/creature/taming_slice.gd")
const ProfessionSlice  := preload("res://src/crafting/profession_slice.gd")
const StationSlice     := preload("res://src/world/station_slice.gd")
const TreeSlice        := preload("res://src/world/tree_slice.gd")
const MarketSlice      := preload("res://src/world/market_slice.gd")
const TradeSlice       := preload("res://src/trade/trade_slice.gd")
const ProposalSlice    := preload("res://src/governance/proposal_slice.gd")
const UiSlice          := preload("res://src/ui/ui_slice.gd")
const ChatSlice        := preload("res://src/chat/chat_slice.gd")
const WaystoneSlice    := preload("res://src/world/waystone_slice.gd")
const WeatherSlice     := preload("res://src/world/weather_slice.gd")
const StatusEffects    := preload("res://src/battle/status_effects.gd")
const Minimap          := preload("res://src/ui/minimap.gd")
const LoadingScreen    := preload("res://src/ui/loading_screen.gd")
const WaypointHorizon  := preload("res://src/ui/waypoint_horizon.gd")
const TestSuite        := preload("res://src/tests/test_suite.gd")
const NetHarness       := preload("res://src/tests/net_harness.gd")
const SpawnFinder      := preload("res://src/world/spawn_finder.gd")
const ColonizationMap  := preload("res://src/world/colonization_map.gd")
const WorldClock       := preload("res://src/world/world_clock.gd")
const BootWiring := preload("res://src/core/boot_wiring.gd")
const CombatWiring := preload("res://src/battle/combat_wiring.gd")
const WeatherWiring := preload("res://src/world/weather_wiring.gd")
const WaystoneWiring := preload("res://src/world/waystone_wiring.gd")
const SettlementWiring := preload("res://src/settlement/settlement_wiring.gd")
const CraftingWiring := preload("res://src/crafting/crafting_wiring.gd")
const CharacterWiring := preload("res://src/character/character_wiring.gd")
const PeerWiring := preload("res://src/networking/peer_wiring.gd")
const SnapshotWiring := preload("res://src/persistence/snapshot_wiring.gd")
const PersistenceWiring := preload("res://src/persistence/persistence_wiring.gd")

## Phase 132 — per-system wiring modules (see `src/core/wiring.gd`), wired in this fixed order.
var _wirings: Array = []
var _boot_wiring := BootWiring.new()
var _combat_wiring := CombatWiring.new()
var _weather_wiring := WeatherWiring.new()
var _waystone_wiring := WaystoneWiring.new()
var _settlement_wiring := SettlementWiring.new()
var _crafting_wiring := CraftingWiring.new()
var _character_wiring := CharacterWiring.new()
var _peer_wiring := PeerWiring.new()
var _snapshot_wiring := SnapshotWiring.new()
var _persistence_wiring := PersistenceWiring.new()

var _terrain:     TerrainSlice
var _voxel:       VoxelSlice
var _chunk_manager: ChunkManager
var _minimap:     Minimap
var _distant:     Node   # Phase 51 — render-only coarse ring outside the voxel window
var _loading_screen: LoadingScreen
var _battle:      BattleSlice
var _creature:    CreatureSlice
var _creature_ai: CreatureAI
## Phase 71 — the worldgen version stamped into every world record this process writes.
var _worldgen_stamp: int = TerrainSlice.WORLDGEN_VERSION
## Phase 106 — the fingerprint the next save writes; resolved when a record loads.
var _worldgen_fp_stamp: int = -1
## Every worldgen fingerprint this world was saved under, oldest first (see `PersistenceSlice.fingerprint_history`).
var _worldgen_fp_history: Array = []
var _networking:  NetworkingSlice
var _persistence: PersistenceSlice
var _registry:    PlayerRegistry
var _player:      PlayerSlice
var _loot:        LootSlice
var _inventory:   InventorySlice
var _character:   CharacterSlice
var _crafting:    CraftingSlice
var _technology:  TechnologySlice
var _taming:      TamingSlice
var _professions: ProfessionSlice
var _station:     StationSlice
var _tree:        TreeSlice
## Phase 63: the origin-rebase driver (see rebase_driver.gd); built once the slices exist.
var _rebase: RebaseDriver = null
var _market:      MarketSlice
var _trade:       TradeSlice
var _proposal:    ProposalSlice
var _ui:          UiSlice
var _chat:        ChatSlice
var _waystones:   WaystoneSlice
var _settlements: Node
var _weather:     WeatherSlice
## Phase 129 — the host's status effects, ticked from the clock tick; null on a client.
var _status:      StatusEffects
## Test hook: fixed seconds in place of the engine clock.
var status_clock: Callable = Callable()

## Network role (Phase 18/27). HOST = authoritative simulation (default, matches
## single-player); CLIENT = receives world state from a host; SERVER = headless
## dedicated authoritative host (no rendering, no local player). Derived from
## command-line user args: `godot -- --client <addr>` joins, `--server` boots a
## headless server, otherwise host.
var _is_client: bool = false
var _is_server: bool = false
var _host_address: String = "127.0.0.1"
var _snapshot_pending: bool = false

## Phase 42 — true while the host boot is waiting for the first ring of chunks to
## finish building on the worker (see _boot_host / _finish_host_boot). Polled in
## `_process`, which is the only place a worker result can be applied on time.
var _pending_host_boot: bool = false

## Phase 42 review — true while a CLIENT join is waiting for the same first ring (see
## `_snapshot_wiring.on_world_snapshot_received` / `_finish_client_boot`). The client has no boot tail to
## run, so it is a separate flag rather than a mode on the host one: all it holds is the
## loading screen and the movement freeze, and all it does at the end is release both.
var _pending_client_boot: bool = false

## Phase 42 review pass 11 — true once this join's FIRST snapshot has released the player.
## The host also sends a re-scope snapshot on every area-of-interest crossing, through the
## same handler; those must not raise the loading screen (and freeze the body) mid-game.
## Reset when a new connection starts, so a reconnect waits for its ring again.
var _client_boot_done: bool = false

## Phase 42 — how long the host boot will wait for its first ring before placing the
## player anyway. The gate is a BUILD ON A WORKER, and a stalled or dead task must not
## hang the boot for good with the loading screen up and no player: past this the tail
## runs regardless and the warning says the ring was incomplete. Mirrors SNAPSHOT_TIMEOUT
## on the client side, which is the same shape for the same reason.
const FIRST_RING_TIMEOUT := 15.0

## Host-side global cap on live creature instances (Phase 44); see CreatureSlice.set_population_cap.
const CREATURE_POPULATION_CAP := 512

## Phase 42 review pass 3 — the wait is accumulated PER GATE. `_pending_host_boot` and
## `_pending_client_boot` are mutually exclusive today (the roles are), so one shared
## accumulator only ever counted one of them — but a single variable read by two different
## deadlines is a coupling waiting for the day both are set: whichever gate ticked second
## would inherit the other's elapsed time and skip its own wait. Two variables, no
## coupling, and each gate's timeout is now readable on its own.
var _host_boot_wait_elapsed: float = 0.0
var _client_boot_wait_elapsed: float = 0.0

## Phase 39 — which side of the two-client network harness this boot drives ("" for a
## normal boot). Set by `_boot_wiring.parse_network_args`; see `_run_net_harness`.
var _net_harness_role: String = ""

## Phase 53 — how settled each region is; new-player spawns keep away from the settled ones.
var _colonization := ColonizationMap.new()
## Phase 54 — the world clock. The host advances and saves it and ticks it to clients; a client
## advances locally and slews to each tick.
var _clock := WorldClock.new()
## Seconds between host ticks (the net harness shortens it); `clock_ticks_sent` counts them.
var clock_tick_seconds: float = WorldClock.TICK_SECONDS
var clock_ticks_sent: int = 0
var clock_ticks_received: int = 0
var _last_clock_text: String = ""
## Phase 53 — a friend's handle given on the command line (`--friend p_…`), "" for none.
var _friend_code_arg: String = ""
## Phase 53 — where the LOCAL player (host or offline) was placed on a first boot, or null.
var _local_spawn: Variant = null
## Phase 53 — client: the respawn point was taken from the first snapshot's own position.
var _client_respawn_point_set: bool = false
## Phase 87 — how many times `_persistence_wiring.saved_local_position` has run; a test reads it to prove a placement
## reads the record once.
var _saved_position_reads: int = 0
## True when the local player's record carried a saved position at boot (a returning player).
var _local_player_returning := false

## Phase 29 — the AOI grid cell each connected peer last reported, so a client
## moving into a new region triggers a re-scoped snapshot (host side only).
var _peer_aoi_regions: Dictionary = {}

## Phase 109 — a re-scope snapshot carries generation records at most this often per peer (the join
## snapshot always does). `_peer_records_msec` is the last time each peer was sent them.
const RECORDS_RESCOPE_INTERVAL_MSEC := 250
var _peer_records_msec: Dictionary = {}

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

## Phase 132 — wiring modules know their root from construction (the suite builds roots without `_ready`).
func _init() -> void:
	_wirings = [_boot_wiring, _combat_wiring, _weather_wiring, _waystone_wiring, _settlement_wiring, _crafting_wiring, _character_wiring, _peer_wiring, _snapshot_wiring, _persistence_wiring]
	for w in _wirings:
		w.root = self

func _ready() -> void:
	# Phase 36 — the role flags are read FIRST, because they decide whether the
	# automated suite runs on this boot (see should_run_tests).
	_boot_wiring.parse_network_args()
	# Phase 131 — saved language, else the OS locale, else English.
	LocaleSettings.apply_startup()
	# Phase 42 review pass 3 — and whether this boot quits itself once its world is up
	# (`--quit-after-boot`; see QUIT_AFTER_BOOT_ARG).
	_quit_after_boot = should_quit_after_boot(OS.get_cmdline_user_args())

	# Run the automated tests before any production slice enters the tree — when
	# this boot runs them at all. The suite emits signals on the shared GameBus
	# (creature_died, chunk_ready, combat, loot…). Running it first keeps those
	# emissions from leaking into production state — previously the test
	# creature_died calls were marking every freshly spawned creature dead and
	# hiding its body on world boot.
	#
	# Phase 39 — a harness boot skips the suite: the two are separate CI jobs, and the
	# suite's own GameBus emissions would arrive at the harness's slices before the
	# scenario started.
	if _net_harness_role == "" and should_run_tests(OS.get_cmdline_user_args(), OS.is_debug_build()):
		_run_tests()

	# Phase 33 — intercept the quit so records are written first.
	_boot_wiring.install_quit_guard()

	_terrain     = TerrainSlice.new()
	_voxel       = VoxelSlice.new()
	_chunk_manager = ChunkManager.new()
	_minimap     = Minimap.new()
	# Phase 42 — the first-ring loading screen. Presentation only, added to the tree
	# behind the same `not _is_server` guard the minimap uses; it owns the boot's
	# world-input freeze (see LoadingScreen and GameBus.world_input_frozen).
	_loading_screen = LoadingScreen.new()
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
	_taming      = TamingSlice.new()
	_professions = ProfessionSlice.new()
	_station     = StationSlice.new()
	_tree        = TreeSlice.new()
	_market      = MarketSlice.new()
	_trade       = TradeSlice.new()
	_proposal    = ProposalSlice.new()
	_ui          = UiSlice.new()
	_chat        = ChatSlice.new()
	_waystones   = WaystoneSlice.new()
	_settlements = _settlement_wiring.make_slice(self)
	_weather     = WeatherSlice.new()
	# Phase 129 — status effects live on the host; the battle slice rolls them and the AI honours them.
	_status = StatusEffects.new()
	_battle.status_effects = _status
	_battle.now_fn = _combat_wiring.status_now
	_battle.attacker_pos_fn = _combat_wiring.death_attacker_pos
	_battle.walkable_fn = _combat_wiring.death_walkable
	_battle.ground_fn = _combat_wiring.death_ground
	_player.death_landing_fn = _combat_wiring.player_death_landing
	_creature_ai.status_effects = _status
	_creature_ai.now_fn = _combat_wiring.status_now
	# Phase 128 — weather is a pure function of the seed, the biome and the clock.
	_weather.clock    = _clock
	_weather.seed_of  = _terrain.get_world_seed
	# The generator's biome, not the record-aware one: records are host-local, weather must match on every peer.
	_weather.biome_of = func(chunk: Vector2i) -> String: return TerrainSlice.generated_biome_for_chunk(chunk, _terrain.get_world_seed())

	# CreatureSlice stands spawns and walkers on the terrain and voxel surface; wire it before it enters the tree.
	_creature.terrain_slice = _terrain
	_creature.use_surface(_voxel, _chunk_manager.is_chunk_built)
	_creature.world_clock = _clock
	# TreeSlice likewise stands its trees on the terrain surface.
	_tree.terrain_slice = _terrain
	_tree.world_clock = _clock

	# CreatureAI needs creature_slice, player_slice, and battle_slice for queries.
	_creature_ai.creature_slice = _creature
	_creature_ai.player_slice   = _player
	_creature_ai.battle_slice   = _battle
	# Phase 36 — creature AI targets the nearest of ALL players, so it needs the
	# targets this integration layer alone can assemble: the local body plus every
	# connected peer's last recorded position (see _peer_wiring.player_targets).
	_creature_ai.player_targets = _peer_wiring.player_targets

	# Wire crafting + station cross-references before add_child so their _ready()
	# methods see the correct dependencies if they ever emit signals during init.
	_crafting.station_slice    = _station
	_station.player_slice      = _player

	# Headless server (Phase 27): creature + player presentation is skipped so
	# the authoritative simulation runs with no visual nodes. Set BEFORE the
	# slices enter the tree so their _ready() skips body/pool construction.
	for presenter in [_creature, _player, _tree, _chat, _character]:
		presenter.render_visuals = not _is_server

	# The UI (Phase 14) is presentation only, so a headless dedicated server
	# (Phase 27) keeps it out of the tree — its _ready() would otherwise build
	# windows nothing can render or click.
	var slices: Array = [_terrain, _voxel, _chunk_manager, _battle, _creature, _creature_ai, _networking, _persistence, _registry, _player, _loot, _inventory, _character, _crafting, _technology, _taming, _professions, _station, _tree, _market, _trade, _proposal, _chat, _waystones, _settlements, _weather]
	if not _is_server:
		slices.append(_ui)
	if not _is_server:
		_rebase = RebaseDriver.new([_voxel, _tree, _creature, _station, _player, _loot, _character])
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
	# Phase 118 — the void-burst chain: flags live on the taming slice, the profession
	# gate and unlock on the profession slice, the burst's HP and seed on the player and terrain.
	_crafting.flag_store        = _taming
	_crafting.profession_slice  = _professions
	_crafting.player_slice      = _player
	_crafting.terrain_slice     = _terrain
	_professions.crafting_slice = _crafting
	_professions.flag_store     = _taming
	_professions.player_registry = _registry
	_player.station_slice = _station
	_player.inventory_slice = _inventory
	_technology.inventory_slice = _inventory
	# Phase 34 — research consumes the RESEARCHER's own materials and moves that
	# player's tree only, so the slice needs the registry that owns one inventory
	# per player (see TechnologySlice).
	_technology.player_registry = _registry
	# Phase 35 — taming is per-player too: the granted flag, the companion binding
	# and the consumed offering all belong to one player's record and inventory, so
	# the slice needs the registry, the creature population, the skill table and
	# the character (for the bare-hands rule).
	_taming.creature_slice   = _creature
	_taming.creature_ai      = _creature_ai
	_taming.player_slice     = _player
	_taming.player_registry  = _registry
	_taming.crafting_slice   = _crafting
	_taming.character_slice  = _character
	_taming.inventory_slice  = _inventory
	_creature_ai.taming_slice = _taming
	_voxel.terrain_slice      = _terrain
	_voxel.inventory_slice    = _inventory
	# Phase 42 review — the registry, so an edit the host resolves for a REMOTE peer
	# charges and credits THAT peer's own pack instead of the host's (and pushes the
	# result back to its client). Same collaborator CraftingSlice got in Phase 37.
	_voxel.player_registry    = _registry
	_tree.inventory_slice     = _inventory
	_tree.player_registry     = _registry
	_tree.voxel_slice         = _voxel
	_tree.station_slice       = _station
	_tree.record_writer       = _chunk_manager.update_record
	_tree.frontier_ready      = _chunk_manager.can_record_now
	# Phase 36 — the wire is policed with evidence the bus cannot carry: a tree chop
	# intent names only a tree id (its position for the reach check comes from the tree
	# slice) and a trade invite names a counterparty (resolved against the registry's
	# online set). Both checks fail closed when unwired.
	_networking.tree_slice      = _tree
	_networking.player_registry = _registry
	_networking.peer_held = _peer_wiring.peer_is_held
	# Phase 85 — chat and admin commands act on the registry's players, the local body and pack,
	# and reach a remote player through the networking slice's host → peer doors. A headless
	# server builds no box.
	_chat.player_registry  = _registry
	_chat.player_slice     = _player
	_chat.inventory_slice  = _inventory
	_chat.networking       = _networking
	_chat.weather_slice    = _weather
	_player.weather_slice  = _weather
	_waystone_wiring.attach()   # Phase 125 — waystone travel reuses the exact admin teleport door
	if not _is_server:
		_ui.inventory_slice       = _inventory
		_ui.character_slice       = _character
		_ui.crafting_slice        = _crafting
		_ui.technology_slice      = _technology
		_ui.market_slice          = _market
		_ui.proposal_slice        = _proposal
		_ui.trade_slice           = _trade
		_ui.voxel_slice           = _voxel
		_ui.player_slice          = _player
		_ui.map_window.minimap       = _minimap
		_ui.map_window.terrain_slice = _terrain
		_ui.map_window.player_slice  = _player
		_ui.map_window.waystone_slice = _waystones
		_ui.drops_enabled         = not _is_client
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
		# Phase 37 — the merchant's inventory answers to "merchant" and to nothing
		# else: unstamped it looked like the LOCAL bucket, so any sync addressed to this
		# machine's own player would have overwritten the merchant's stock.
		merchant_inv.owner_id = "merchant"
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
	if not _is_client:
		_creature.set_population_cap(CREATURE_POPULATION_CAP)
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
	_inventory.is_authoritative = not _is_client
	# Phase 34 — same rule for the technology tree: a client owns no records, so it
	# forwards a research intent instead of resolving one against its synced copy.
	_technology.is_authoritative = not _is_client
	# Phase 35 — same rule for taming: the flag and the companion binding live on a
	# player record the host owns, so a client forwards a tame intent instead of
	# resolving one against its synced world.
	_taming.is_authoritative = not _is_client
	# Phase 118 — same rule for professions: the host resolves an unlock, a client mirrors it.
	_professions.is_authoritative = not _is_client

	# Chunk streaming (Phase 17) — wire the manager to its collaborators.
	_chunk_manager.terrain_slice  = _terrain
	_chunk_manager.voxel_slice    = _voxel
	_chunk_manager.player_slice   = _player
	_chunk_manager.creature_slice = _creature
	_chunk_manager.tree_slice     = _tree
	# Phase 42 review — and back the other way, so an edit DISPATCHES its rebuild instead
	# of building up to three chunks synchronously in the frame that placed the block.
	# A voxel slice with no manager (an isolated rig) keeps the synchronous build.
	_voxel.chunk_manager = _chunk_manager

	# Minimap overlay (Phase 17) — top-right, biome-coloured chunk view. Pure
	# presentation, so a headless dedicated server (Phase 27) skips it entirely,
	# the same way the lighting block below does.
	if not _is_server:
		_distant = DistantTerrain.new()
		_distant.name = "DistantTerrain"
		_distant.circumference_m = float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
		add_child(_distant)
		if _rebase != null:
			_rebase.targets.append(_distant)
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
		# Phase 111 — the explored set persists per world, and a click on the minimap opens the Map window.
		_minimap.revealed_dir = "user://saves/client"
		_minimap.open_requested.connect(func() -> void: _ui.open_window(UiSlice.WINDOW_MAP))
		# Waypoints on the horizon of the game view, under the minimap and the windows.
		var horizon_layer := CanvasLayer.new()
		horizon_layer.name = "WaypointHorizonLayer"
		horizon_layer.layer = 10
		add_child(horizon_layer)
		var horizon := WaypointHorizon.new()
		horizon.minimap = _minimap
		horizon_layer.add_child(horizon)

		# Phase 42 — the first-ring loading screen, at its own layer ABOVE the minimap.
		# Host-only like the minimap (a dedicated server has no body to place and no
		# screen to show), and it starts hidden: the boot path shows it (see _boot_host)
		# for as long as the ground under the spawn point is being built.
		#
		# Phase 42 review — no second `not _is_server` guard here: this block is already
		# inside one (the minimap's), so the nested copy was dead.
		add_child(_loading_screen)

	# Bus listeners for integration-layer logging.
	for w in _wirings:
		w.wire(self)


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
		# Phase 164 — a sky whose horizon is the haze colour, with distance fog over the far ring.
		env.environment = WeatherWiring.make_environment()
		add_child(env)

	# Verify GameData entries load cleanly.
	_boot_wiring.check_game_data()

	# Boot terrain — creatures are spawned by CreatureSlice._ready() via GameData.
	# Phase 39 — the two-client network harness boots in place of the world boot: it is
	# an `await`-driven scenario over a real socket, so it drives the role's OWN boot
	# half itself (see `_run_net_harness`) and nothing after it in `_ready()` may run.
	if _net_harness_role != "":
		await _run_net_harness(_net_harness_role)
		return

	_boot_world()
	_boot_wiring.start_playtest_bot()

## Phase 39 — run the two-client network harness and let it end this process.
##
## Placed here, after every slice is built and wired and BEFORE the role boot, for the
## same reason the suite is: the slices have to exist for the scenario to drive them, and
## the boot half the role needs is the one the harness itself invokes (`_boot_server()` /
## `join()`) so what runs is the shipped boot path, not a harness-only arrangement. The
## scenario quits the process when it finishes, which is what makes the driver's "did
## this side exit cleanly" check mean something.
func _run_net_harness(role: String) -> void:
	var harness := NetHarness.new()
	harness.name = "NetHarness"
	add_child(harness)
	await harness.run(self, role)
	harness.queue_free()

# ---------------------------------------------------------------------------
# Automated tests
# ---------------------------------------------------------------------------

func _run_tests() -> void:
	var suite := TestSuite.new()
	suite.name = "TestSuite"
	add_child(suite)
	suite.run()
	suite.queue_free()

## Phase 36 — the user arg that asks for the suite explicitly.
const RUN_TESTS_ARG := "--run-tests"

## Phase 39 — the user arg that asks for the two-client network harness, and which side
## of it this process drives (`host` or `client`).
const NET_HARNESS_ARG := "--net-harness"

## Phase 42 review pass 3 — the user arg that asks a boot to QUIT itself once its world boot has
## finished. A boot's first ring is built on `WorkerThreadPool` tasks, so what it waits on is
## WALL-CLOCK time, while `--quit-after N` counts FRAMES: a fast headless frame loop can burn
## the whole frame budget before the worker tasks land, and the CI job then reads a log with no
## first-ring marker — a FAILURE for a boot that was working. With this arg the BOOT decides
## when it is done; `--quit-after` stays only as the outer net for a boot that never finishes.
const QUIT_AFTER_BOOT_ARG := "--quit-after-boot"

## Phase 42 review pass 3 — see QUIT_AFTER_BOOT_ARG. Read in `_ready()`.
var _quit_after_boot: bool = false

## Phase 36 — should THIS boot run the automated suite?
##
## It used to run unconditionally, so every boot of every build executed a
## 7000-assertion suite inside `_ready()` — a production boot paid for the whole
## development harness on every launch, and the world boot had to be sequenced
## around its GameBus emissions. The suite is a development and CI tool, not a
## boot step, so it now runs when either:
##
##   • `--run-tests` is passed on the user-args command line — and only then.
##
## A debug build (editor F5) used to run it too; the suite takes minutes, so every
## editor launch waited on it before the world could boot. `is_debug_build` is kept in
## the signature for callers, but no longer decides anything.
##
## Static and argument-driven on purpose: the rule is a pure predicate the suite
## can assert directly, rather than something that can only be observed by booting
## twice. See `_test_boot_suite_is_gated`.
static func should_run_tests(args: Array, _is_debug_build: bool) -> bool:
	return RUN_TESTS_ARG in args

## Phase 42 review pass 3 — is this boot asked to quit itself once its world boot is done?
## Static and argument-driven for the same reason `should_run_tests` is: the rule is a pure
## predicate the suite can assert directly. See QUIT_AFTER_BOOT_ARG for why a FRAME budget
## is the wrong instrument for a boot whose wait is on worker time.
static func should_quit_after_boot(args: Array) -> bool:
	return QUIT_AFTER_BOOT_ARG in args

## Phase 39 — which side of the network harness this boot drives, or "" for a normal
## boot. Static and argument-driven for the same reason `should_run_tests` is: the rule
## is a pure predicate the suite can assert directly rather than something only a pair of
## booted processes could show. An unrecognised or missing role is "" (a normal boot)
## rather than a guess: the wrong side of this scenario would still boot a working game.
static func net_harness_role(args: Array) -> String:
	var i := args.find(NET_HARNESS_ARG)
	if i < 0 or i + 1 >= args.size():
		return ""
	var role := str(args[i + 1])
	return role if role == "host" or role == "client" else ""

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("[Server] window close requested — saving before quit")
		if _minimap != null and _minimap.revealed_dir != "" and _minimap.is_revealed_loaded():
			_minimap.save_revealed()
		_persistence_wiring.save_everything(true)
		# The write is threaded, so quitting here would race it: block until it lands.
		_persistence_wiring.flush_save()
		get_tree().quit()
	elif what == NOTIFICATION_PREDELETE:
		# Wired once in `_ready`: unwire at free time, so a reparent keeps the handlers.
		for w in _wirings:
			w.unwire()

## Set true to enable verbose craft-fail logging and the demo station/craft
## sequence in _boot_host(). False keeps boot output minimal in production.
const DEBUG := false

## Role dispatch (Phase 32): client → `_boot_client()`, dedicated server →
## `_boot_server()`, otherwise the listen host → `_boot_host()`. No boot logic
## lives here any more — the host path used to be inlined at this point.
##
## Phase 42 review pass 4 — the DEDICATED SERVER branch ends its boot here, so this is
## where `--quit-after-boot` fires for it: a `--server` boot has no deferred tail (that is
## the LISTEN host's, see `_boot_host`), and without this call the flag was silently a
## no-op on a dedicated server — a `--server --quit-after-boot` boot never quit itself and
## fell through to the engine's `--quit-after` net.
func _boot_world() -> void:
	if _is_client:
		_boot_client()
		return

	if _is_server:
		_boot_server()
		_quit_after_boot_if_asked("server")
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
##
## Phase 42 — the tail is no longer run in this frame. The terrain build is on a
## worker now, so the first ring is NOT ready when `_boot_server()` returns and the
## body would be placed on ground that does not exist yet. So the host boot shows the
## loading screen, freezes world input, and lets `_process` call `_finish_host_boot()`
## the moment `is_first_ring_ready()` opens — which is also the frame the player body
## first exists. A ring that is somehow already built completes immediately.
func _boot_host() -> void:
	_boot_server()

	_loading_screen.begin()
	# Phase 42 review pass 11 — `_boot_server` armed the ring around the PRE-SPAWN body,
	# which is the origin chunk. A host who logged off elsewhere is moved there by
	# `_persistence_wiring.restore_local_player` only in the tail, AFTER the gate opened, onto chunks nobody
	# had dispatched. Place the (now frozen) body at the saved position first and re-arm
	# the ring and the window around it; the origin chunks still queued fall outside the
	# window and are dropped by the drain.
	var saved_pos: Variant = _persistence_wiring.saved_local_position()
	if saved_pos == null:
		# Phase 53 — a first boot: the same placement a joining peer gets.
		saved_pos = _peer_wiring.first_boot_spawn()
	if saved_pos != null:
		_persistence_wiring.place_local_player(saved_pos)
		_persistence_wiring.lift_out_of_ground()
		_chunk_manager.build_first_ring(_chunk_manager.player_chunk())
		_chunk_manager.refresh()
	_host_boot_wait_elapsed = 0.0
	if _chunk_manager.is_first_ring_ready():
		_finish_host_boot()
		return
	_pending_host_boot = true

## Phase 42 — drive the waiting host boot: while `_pending_host_boot` is set, keep the
## loading bar in step with the first ring's build progress and run the host tail as
## soon as every ring chunk's ground exists. A no-op once the boot has completed.
##
## Phase 42 review — and it TIMES OUT. A ring that never opens (a stalled build, a pool
## that never runs the task) used to hold the boot forever: loading screen up, no player,
## no UI, nothing logged. Past FIRST_RING_TIMEOUT the tail runs anyway and the warning
## names what was missing, so a broken build is a slow boot that says so rather than a
## hang with no evidence.
func _tick_pending_host_boot(delta: float) -> void:
	if not _pending_host_boot:
		return
	_loading_screen.set_progress(_chunk_manager.first_ring_progress())
	_host_boot_wait_elapsed += delta
	if not host_boot_may_proceed(_chunk_manager.is_first_ring_ready(), _host_boot_wait_elapsed):
		return
	if not _chunk_manager.is_first_ring_ready():
		Diag.warn("GameRoot: first ring still incomplete after %.1fs (%d of %d chunks built) — placing the player anyway" % [
			_host_boot_wait_elapsed, int(round(_chunk_manager.first_ring_progress() * float(_chunk_manager.first_ring_size()))),
			_chunk_manager.first_ring_size()])
	_finish_host_boot()

## The boot gate's decision, as a pure predicate so it is assertable without a boot:
## the tail may run once the ring is built, or once the wait has run past the timeout.
## An UNARMED ring is "ready" (see ChunkManager.is_first_ring_ready), so a boot with no
## gate to wait for completes on the first tick.
static func host_boot_may_proceed(ring_ready: bool, elapsed: float) -> bool:
	return ring_ready or elapsed >= FIRST_RING_TIMEOUT

## Phase 42 review pass 3 — leave the process the moment the world boot has finished, when this
## boot was asked to (QUIT_AFTER_BOOT_ARG). Called at the END of both boot tails — the host's
## after its save, the client's after it releases the player — because the tail IS the boot's
## definition of "done". The alternative, `--quit-after N`, is a FRAME budget for a wait that
## is measured in worker time, so it can expire first; see QUIT_AFTER_BOOT_ARG.
func _quit_after_boot_if_asked(role: String) -> void:
	if not _quit_after_boot:
		return
	print("[World] %s boot complete — quitting (%s)" % [role, QUIT_AFTER_BOOT_ARG])
	get_tree().quit()

## Phase 42 review — the CLIENT's first-ring gate (see `_snapshot_wiring.on_world_snapshot_received`).
## The client has no boot tail: its body already holds the snapshot position, so the only
## work is to drop the loading screen and release the movement freeze that stopped the
## body falling through ground that had not been built yet. Same timeout rule as the host,
## so a stalled build cannot leave a client frozen forever.
func _finish_client_boot() -> void:
	_pending_client_boot = false
	_client_boot_done = true
	# Phase 42 review pass 3 — this runs on BOTH paths: the waiting one (which showed the
	# screen) and the ALREADY-READY early return in `_snapshot_wiring.on_world_snapshot_received` (which
	# did not). Only the first one ever held the player, so ask the screen whether
	# anything was actually shown instead of announcing a release that never happened —
	# a client whose ring was built before the snapshot arrived saw no bar and was never
	# frozen, and the line claimed it was "releasing the player" regardless.
	var was_shown := _loading_screen.is_active()
	_loading_screen.finish()
	if was_shown:
		print("[World] client first ring built (%d chunks) — releasing the player" % _chunk_manager.first_ring_size())
	else:
		print("[World] client first ring already built (%d chunks) — no loading screen to release" % _chunk_manager.first_ring_size())
	_quit_after_boot_if_asked("client")

## Phase 42 review pass 3 — drive the waiting client join: keep the loading bar in step with the
## first ring's build progress and release the player the moment the ring's ground exists.
## A no-op once the join has completed (or when this is not a client at all).
func _tick_pending_client_boot(delta: float) -> void:
	if not _pending_client_boot:
		return
	_loading_screen.set_progress(_chunk_manager.first_ring_progress())
	_client_boot_wait_elapsed += delta
	if not host_boot_may_proceed(_chunk_manager.is_first_ring_ready(), _client_boot_wait_elapsed):
		return
	if not _chunk_manager.is_first_ring_ready():
		Diag.warn("GameRoot: client first ring still incomplete after %.1fs (%d of %d chunks built) — releasing the player anyway" % [
			_client_boot_wait_elapsed, int(round(_chunk_manager.first_ring_progress() * float(_chunk_manager.first_ring_size()))),
			_chunk_manager.first_ring_size()])
	_finish_client_boot()

## The host tail, run once the first ring's ground exists: player spawn, avatar,
## lighting/UI demos, and the legacy slot save. Split out of `_boot_host()` by
## Phase 42 so it can run on a LATER frame (see there); it is still the same code in
## the same order, and it is idempotent by way of `_pending_host_boot`.
func _finish_host_boot() -> void:
	_pending_host_boot = false
	_loading_screen.finish()
	print("[World] first ring built (%d chunks) — placing the player, %.2fs after boot" % [
		_chunk_manager.first_ring_size(), float(Time.get_ticks_msec()) / 1000.0])

	# Player spawn — above the terrain surface so it doesn't spawn embedded in
	# (and fall through) the collision mesh.
	# Phase 53 — a first boot lands on habitable land away from colonized regions (see
	# `_peer_wiring.first_boot_spawn`); a saved player is put back by `_persistence_wiring.restore_local_player` below.
	var first_spawn: Variant = _peer_wiring.first_boot_spawn()
	var spawn_pos: Vector3 = first_spawn if first_spawn != null else TerrainSlice.spawn_point(_terrain.get_height_at(WorldShape.SPAWN_CENTER) + 1.0)
	var spawn_xz := Vector2(spawn_pos.x, spawn_pos.z)
	var ground_h := spawn_pos.y - 1.0
	_player.spawn_at(spawn_pos)
	_player.respawn_point = spawn_pos
	_player.respawn_world_pos = {}

	# Phase 33 — the local player's own record (position / HP / technologies) is
	# restored on top of the spawn point, so a restart puts the player back where
	# they logged off instead of at the world origin.
	_persistence_wiring.restore_local_player()

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
	var player_char := _persistence_wiring.restore_or_create_player_character(_player.get_position())
	_character.create_character("BoarRider", Vector3(spawn_xz.x - 3.0, ground_h + 1.0, spawn_xz.y))
	_character.set_player_character(player_char)
	# Phase 59 — the avatar wears the rig when the manifest lists one; otherwise (or when
	# the scene fails to load) the procedural body stays. A dedicated server renders nothing,
	# so it never loads the glTF scene.
	if not _is_server:
		_character.attach_default_rig(player_char)
	# Phase 47 — the avatar exists only now, so the recorded worn set is applied here
	# (the restore above runs before there is a character to wear it).
	_character_wiring.apply_local_equipment(_registry.get_record(_registry.local_player_id).get("equipment", {}) if not _registry.local_player_id.is_empty() else {})
	if _ui != null and not _registry.local_player_id.is_empty():
		_ui.set_own_handle(_registry.public_handle(_registry.local_player_id))

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
	# Only for a new player: these go into the saved pack and the world's edit log, so running
	# them on every boot added 4 Ashite and a Soil per launch until the pack hit its weight limit
	# and every pickup and mining yield was refused.
	_voxel.set_place_material("Ashite")
	if not _local_player_returning:
		var mine_spot := Vector3(spawn_xz.x + 6.0, ground_h, spawn_xz.y + 2.0)
		_voxel.mine_block(mine_spot)
		_inventory.add_item("Ashite", 4)
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
		_station.try_place_station("forge", ppos + Vector3(2.0, 0.0, 0.0))
		_station.try_place_station("carpentry bench", ppos + Vector3(-2.0, 0.0, 0.0))

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
	_persistence_wiring.save_everything(false)

	# Phase 42 review pass 3 — the tail is the boot's own definition of "done" (see
	# QUIT_AFTER_BOOT_ARG). A CI boot asks to exit HERE rather than being cut off by a
	# FRAME budget: the wait above is on worker time, and `--quit-after N` counts frames.
	_quit_after_boot_if_asked("host")

## Client boot path (Phase 18): do NOT run the authoritative simulation. Join
## the host and wait for the world snapshot before showing anything.
##
## Phase 33 — the client presents the id it cached from a previous session, so
## the host can re-bind it to the same record. The record itself never leaves the
## host; the client only ever holds the id.
func _boot_client() -> void:
	_networking.claimed_player_id = _persistence.load_client_identity()
	_networking.friend_code = _friend_code_arg
	var err: Error = _networking.join(_host_address, _networking.DEFAULT_PORT)
	if err != OK:
		Diag.error("[Networking] client failed to connect to %s — %s" % [_host_address, error_string(err)])
		_snapshot_pending = false
		return
	_snapshot_pending = true
	_client_boot_done = false
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
	_persistence_wiring.load_world_records()
	# Phase 52 — voxel edits stream in by region around every window (the local player's
	# and each connected peer's) instead of loading from the world record up front.
	_chunk_manager.region_streamer = RegionStreamer.new(_persistence.region_store, _voxel, true)   # Phase 142: regions read on a worker
	# Phase 108 — the host records each chunk it first streams in; never while a save is writing regions.
	_chunk_manager.record_store = _persistence.region_store
	_chunk_manager.records_flush_blocked = func() -> bool: return _save_thread != null
	_chunk_manager.start()
	# Phase 42 — arm the boot gate BEFORE the first refresh, and not after it. Both boot
	# paths inherit it here, which is what stops a gate wired into one of them from being a
	# hole in the others. The centre is the player's chunk: pre-spawn that is the origin
	# chunk, and the host's spawn point (16,16) lands in the same chunk (0,0).
	#
	# Phase 42 review — the ORDER matters, and the first pass had it wrong: `refresh()`
	# marks every in-range chunk `_pending`, so arming afterwards found the ring already
	# queued, moved nothing to the front, and the gate's head start was dead code. Arming
	# first puts the 9 ring chunks at the head of `_load_queue`, and the `refresh()` below
	# then appends the wider band behind them (it skips what is already `_pending`).
	_chunk_manager.build_first_ring(_chunk_manager.player_chunk())
	_chunk_manager.refresh()
	_persistence_wiring.apply_loaded_creature_state()
	_networking.host(_networking.DEFAULT_PORT, _networking.DEFAULT_MAX_CLIENTS)

## A remote avatar is dropped only once it is this far away, a margin PAST the host's AOI
## edge. The host stops reporting a peer at exactly AOI_RADIUS, so pruning at the same radius
## made an avatar standing on the edge flicker (dropped, re-created by the next report).
const REMOTE_AVATAR_PRUNE_RADIUS := NetworkingSlice.AOI_RADIUS + 16.0

## Phase 29 — a client's movement may carry it into a new area of interest.
## When the AOI grid cell changes, re-send a scoped snapshot so the client gains
## the entities now in range — including static creatures that were never
## "dirty" and therefore never re-broadcast as a delta.
## Coordinates beyond this are no position on the planet (circumference is ~40,000 km in X).
const MAX_CLAIMED_COORD := 1.0e8

static func _is_plausible_position(p: Vector3) -> bool:
	return is_finite(p.x) and is_finite(p.y) and is_finite(p.z) \
		and absf(p.x) <= MAX_CLAIMED_COORD and absf(p.y) <= MAX_CLAIMED_COORD and absf(p.z) <= MAX_CLAIMED_COORD

## Phase 52 — seconds between re-centring the connected peers' streaming windows.
const PEER_WINDOW_INTERVAL := 0.5
var _peer_window_elapsed := 0.0

## Phase 80 — the origin rebase runs at the START of the physics step (the root is earlier in
## the tree than the player body, so its `_physics_process` fires first): no slice's movement
## step reads a scene position that a later `_process` rebase then shifts under it.
func _physics_process(_delta: float) -> void:
	# Phase 63 — a client far from its scene origin shifts the whole scene back (float32 precision).
	if _rebase != null and _player != null and _player.has_method("get_scene_position"):
		var scene_pos: Vector3 = _player.get_scene_position()
		_rebase.tick(scene_pos, _player.get_world_pos()["chunk"])
		_peer_wiring.fold_local_player()

## Phase 91 — the planet is a globe: a player who walks over a pole or round the antimeridian is
## folded back onto the canonical planet (`TerrainSlice.fold_world_pos`), landing where the globe
## puts them. The streamed chunks were built for the pre-fold frame, so the window is re-streamed.
## Phase 120 — the fold is not seen: the old ground (voxel chunks and the distant ring) is carried
## across by the fold's scene transform (`TerrainSlice.fold_scene_transform`) and stands in until the
## folded window is rebuilt, so the body neither waits nor falls and the view does not change. The sun
## turns with a pole crossing as the view does. The body is held only when no stand-in is under it.
const FOLD_HOLD_MAX_MSEC := 5000   ## give the hold up after this long, so a failed build cannot pin the player
const FOLD_STANDIN_MAX_MSEC := 10000   ## stand-ins left this long after a fold are freed (a build that never landed)
var _fold_hold_since_msec := -1
var _fold_standins_since_msec := -1
## Flipped by every pole crossing of the local player: the sun's azimuth turns half a turn with it.
var _sun_turned := false

## Phase 119 — count of holds that timed out with the chunk still unbuilt (the window is re-queued first).
var fold_hold_retries := 0
var _fold_hold_extended := false

func _process(delta: float) -> void:
	# Phase 42 — complete a host boot whose first ring has finished building. It has
	# to run FIRST: the rest of this frame's work (the avatar sync, the LOD pass) is
	# written against a player body that only exists once the boot tail has run, and
	# the loading screen must come down in the same frame the body appears.
	_tick_pending_host_boot(delta)
	# Phase 42 review — and the client's identical gate (a no-op for every other role):
	# a joining client holds the loading screen until its own first ring's ground exists.
	_tick_pending_client_boot(delta)

	_weather_wiring.tick_world_clock(delta)
	if not _pending_host_boot:
		for w in _wirings:
			w.tick(delta)
	_peer_wiring.sync_player_avatar(delta)
	if _distant != null and _player != null and _chunk_manager != null:
		_distant.world_seed = _terrain.get_world_seed()
		var pp := _player.get_position()
		_distant.rebuild(Vector2(pp.x, pp.z), _chunk_manager.stream_radius())
		if _distant.outer_radius_m > 0.0 and not is_equal_approx(_player.view_far(), PlayerSlice.view_far_for(_distant.outer_radius_m)):
			_player.set_view_far(_distant.outer_radius_m)
	if _is_client:
		_peer_wiring.prune_remote_avatars()
	if not _is_client and _player != null:
		# Phase 48 — the host avatar's AOI membership drives peer-equipment sends.
		_networking.set_host_position(_player.get_position())
		_peer_wiring.sync_peer_windows(delta)
	# Distance-driven LOD (Phase 23) — evaluate each character's world distance
	# to the player each frame and swap fine detail / the impostor billboard in
	# and out. No-op until characters exist and on clients (no spawned visuals).
	_character.update_lod(_player.get_position())

	# Phase 33 — settle a COMPLETED save worker before the lifecycle tick can
	# start another one: a failed write is then reported within a frame instead of
	# at the start of the next autosave, and its dirty chunks go back immediately.
	_persistence_wiring.poll_save_completion()

	# Phase 33 — authoritative save lifecycle: the autosave interval plus the
	# shutdown-request poll (each on its own cadence). Must run before the
	# snapshot-pending early return.
	_persistence_wiring.tick_save_lifecycle(delta)

	if not _snapshot_pending:
		return
	_peer_wiring.tick_client_handshake(delta)

## Fog density at visibility factor 0 (Godot units: 0.02 is dense within ~100 m).
const WEATHER_FOG_DENSITY := 0.03

## Warmth the season tints were last computed for (NAN before the first apply).
var _season_warmth: float = NAN

## Worn set this client last matched against the host (what it has already sent actions for);
## an appearance change that leaves gear alone sends nothing.
var _last_sent_equipment: Dictionary = {}
## In-flight save worker, or null. Only one is ever pending: a new save reaps the
## previous one first, so two writers can never interleave on the same files.
var _save_thread: Thread = null
## What the in-flight write was given: the dirty chunk keys it serialized (so its
## completion can clear exactly those, or re-mark them when the write failed), plus
## the counts the completion line reports. Kept as a bundle because the completion
## happens later than the collection and must not read live slice state again.
var _save_summary: Dictionary = {}

## Which of a failed save's chunks go back into the dirty set: just the ones whose region could
## not be written. When no region failed (the global record or a player file did) the chunk
## files landed, but the record that points at them did not, so every chunk is kept in play.
static func _chunks_to_remark(dirty: Array, failed: Array) -> Array:
	if failed.is_empty():
		return dirty
	var out: Array = []
	for key in dirty:
		if failed.has(str(key)):
			out.append(key)
	return out

## A pending save must not be dropped when the process goes away (a `--quit` boot exits long
## before the autosave interval); the `Thread` must also be waited for before it is freed.
func _exit_tree() -> void:
	_persistence_wiring.flush_save()
	# The chunk manager's own exit stood down while the save thread ran; its records go out now.
	if _chunk_manager != null and is_instance_valid(_chunk_manager):
		_chunk_manager.flush_records_final()
		ChunkRecords.clear()

## Phase 66 — the respawn point a player RECORD implies, as an exact `{chunk, local}` (Phase 87): its
## original spawn, else (a record from before the field existed) its saved position, else null (a
## player never placed).
static func respawn_point_for(rec: Dictionary) -> Variant:
	var spawn: Variant = PlayerRegistry.spawn_from_record(rec)
	if spawn != null:
		return spawn
	var arr: Variant = rec.get("position", [])
	if arr is Array and (arr as Array).size() >= 3:
		return PlayerRegistry.world_pos_of(rec)
	return null

## Phase 66 — the respawn point of a client from its handshake `player` block, as an exact
## `{chunk, local}`: the host's recorded spawn when it sent a valid one, else where the body stands.
static func client_respawn_point(own: Dictionary, standing: Dictionary) -> Dictionary:
	var sp: Variant = own.get("spawn", null)
	if sp is Dictionary and WorldPos.is_wire(sp):
		return PlayerRegistry.canonical_world_pos(WorldPos.pos_from_wire(sp))
	if sp is Array and WorldPos.is_wire(sp):
		# A legacy `[x, y, z]` spawn: no exact chunk to keep.
		var v: Vector3 = WorldPos.from_wire(sp, Vector3.ZERO)
		return PlayerRegistry.canonical_world_pos(WorldPos.from_world(v.x, v.y, v.z))
	return standing

## A refused pickup or mining yield used to be silent, which read as "picking up is broken".
const PACK_FULL_NOTICE_MSEC := 3000   ## at most one notice this often, so a held click does not spam

## Seconds between status-effect ticks: damage over time arrives in 0.25 s slices, not one packet a frame.
const STATUS_TICK_SECONDS := 0.25
## Status effects keep a hit's shove this tall (m) when walking onto higher ground.
const KNOCKBACK_STEP_UP := 0.6
