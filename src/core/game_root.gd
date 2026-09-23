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

## Client-side: seconds to wait for the host world snapshot before giving up.
const SNAPSHOT_TIMEOUT := 10.0
var _snapshot_elapsed: float = 0.0

func _ready() -> void:
	# Run the automated tests before any production slice enters the tree.
	# The suite emits signals on the shared GameBus (creature_died, chunk_ready,
	# combat, loot…). Running it first keeps those emissions from leaking into
	# production state — previously the test creature_died calls were marking
	# every freshly spawned creature dead and hiding its body on world boot.
	_run_tests()

	_parse_network_args()

	_terrain     = TerrainSlice.new()
	_voxel       = VoxelSlice.new()
	_chunk_manager = ChunkManager.new()
	_minimap     = Minimap.new()
	_battle      = BattleSlice.new()
	_creature    = CreatureSlice.new()
	_creature_ai = CreatureAI.new()
	_networking  = NetworkingSlice.new()
	_persistence = PersistenceSlice.new()
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
	var slices: Array = [_terrain, _voxel, _chunk_manager, _battle, _creature, _creature_ai, _networking, _persistence, _player, _loot, _inventory, _character, _crafting, _technology, _station, _tree, _market, _trade, _proposal]
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
	_player.station_slice = _station
	_technology.inventory_slice = _inventory
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
	GameBus.research_resolved.connect(_on_research_resolved)
	GameBus.technology_unlocked.connect(_on_technology_unlocked)
	GameBus.block_mined.connect(_on_block_mined)
	GameBus.block_placed.connect(_on_block_placed)
	GameBus.player_damaged.connect(_on_player_damaged)
	GameBus.player_died.connect(_on_player_died)
	GameBus.player_respawned.connect(_on_player_respawned)
	GameBus.trade_completed.connect(_on_trade_completed)
	GameBus.peer_connected.connect(_on_peer_connected)
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

	# Chunk streaming (Phase 17) — the authoritative half above streamed the
	# window around the origin, so re-centre it on the spawn point. VoxelSlice
	# builds the mesh on chunk_ready and CreatureSlice spawns each chunk's
	# budget. `refresh()` skips the diff when the player is still in the chunk
	# it last centred on, so this is a no-op when spawn sits in the origin chunk.
	_chunk_manager.refresh()

	# Character system — the player's own avatar spawns at the player's real
	# position (it is synced to the controller every frame from here on, in
	# _process); a non-humanoid (quadruped) demo spawns alongside it to
	# exercise the appearance pipeline end to end.
	var player_char := _character.create_character("TravellerHuman", _player.get_position())
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
		"technology": _technology.get_statuses(),
		"market": _market.get_market_data(),
		"governance": _proposal.get_governance_data(),
		"trade": _trade.get_trade_data(),
	}
	GameBus.save_requested.emit(0, snapshot)
	GameBus.load_requested.emit(0)

## Client boot path (Phase 18): do NOT run the authoritative simulation. Join
## the host and wait for the world snapshot before showing anything.
func _boot_client() -> void:
	var err: Error = _networking.join(_host_address, _networking.DEFAULT_PORT)
	if err != OK:
		push_error("[Networking] client failed to connect to %s — %s" % [_host_address, error_string(err)])
		_snapshot_pending = false
		return
	_snapshot_pending = true
	_snapshot_elapsed = 0.0

## Headless dedicated-server boot (Phase 27): run the authoritative simulation
## with no local player presentation. Streams the world around the origin and
## opens the host so clients can connect. No avatar, lighting, or demo.
func _boot_server() -> void:
	_chunk_manager.start()
	_chunk_manager.refresh()
	_networking.host(_networking.DEFAULT_PORT, _networking.DEFAULT_MAX_CLIENTS)

func _on_peer_connected(peer_id: int) -> void:
	if _is_client:
		return
	# Host: ship the authoritative, AOI-scoped world snapshot to the newly
	# connected client (Phase 29 — only entities in the peer's area of interest).
	_networking.send_snapshot(peer_id, _build_snapshot(peer_id))

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
	_networking.send_snapshot(peer_id, _build_snapshot(peer_id))

func _process(delta: float) -> void:
	_sync_player_avatar(delta)
	# Distance-driven LOD (Phase 23) — evaluate each character's world distance
	# to the player each frame and swap fine detail / the impostor billboard in
	# and out. No-op until characters exist and on clients (no spawned visuals).
	_character.update_lod(_player.get_position())

	if not _snapshot_pending:
		return
	_snapshot_elapsed += delta
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
func _build_snapshot(peer_id: int) -> Dictionary:
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
	return {
		"heightmaps": _voxel.get_heightmaps(),
		"edits":     _voxel.get_chunk_manifest(),
		"creatures": _scoped_creatures(peer_id),
		"inventory": _inventory.get_contents(),
		"inventory_durability": _inventory.get_durability_data(),
		"market":    _market.get_market_data(),
		"governance": _proposal.get_governance_data(),
		"trade":     _trade.get_trade_data(),
		"players":   players,
	}

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

func _on_craft_resolved(result: Dictionary) -> void:
	pass

func _on_research_resolved(result: Dictionary) -> void:
	pass

func _on_technology_unlocked(tech_id: String) -> void:
	pass

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
	# The snapshot is on disk; reset dirty-chunk tracking so the next save only
	# re-serializes chunks edited after this point.
	_voxel.clear_dirty_chunks()

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
		_technology.apply_statuses(data["technology"])
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
