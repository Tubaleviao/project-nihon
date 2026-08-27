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
var _ui:          UiSlice

## Network role (Phase 18). HOST = authoritative simulation (default, matches
## single-player); CLIENT = receives world state from a host. Derived from
## command-line user args: `godot -- --client <addr>` joins, otherwise host.
var _is_client: bool = false
var _host_address: String = "127.0.0.1"
var _snapshot_pending: bool = false

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
	_ui          = UiSlice.new()

	# CreatureSlice needs the terrain to place spawns on the surface; wire it
	# before the slices enter the tree so its _ready() can use it.
	_creature.terrain_slice = _terrain

	# CreatureAI needs creature_slice, player_slice, and battle_slice for queries.
	_creature_ai.creature_slice = _creature
	_creature_ai.player_slice   = _player
	_creature_ai.battle_slice   = _battle

	# Wire crafting + station cross-references before add_child so their _ready()
	# methods see the correct dependencies if they ever emit signals during init.
	_crafting.station_slice    = _station
	_station.player_slice      = _player

	for s in [_terrain, _voxel, _chunk_manager, _battle, _creature, _creature_ai, _networking, _persistence, _player, _loot, _inventory, _character, _crafting, _technology, _station, _ui]:
		s.name = s.get_script().resource_path.get_file().get_basename()
		add_child(s)

	# Cross-slice wiring: direct references where the bus cannot carry context.
	_inventory.loot_slice      = _loot
	_player.creature_slice     = _creature
	_player.voxel_slice        = _voxel
	_battle.creature_slice     = _creature
	_loot.creature_slice       = _creature
	_crafting.inventory_slice  = _inventory
	_crafting.technology_slice = _technology
	_player.station_slice = _station
	_technology.inventory_slice = _inventory
	_voxel.terrain_slice      = _terrain
	_voxel.inventory_slice    = _inventory
	_ui.inventory_slice       = _inventory
	_ui.crafting_slice        = _crafting
	_ui.technology_slice      = _technology
	_ui.refresh_all()

	# Authority mode (Phase 18): a client never owns world state — it forwards
	# edits to the host and applies authoritative deltas. The host (and offline
	# single-player) keeps full simulation authority.
	_voxel.is_authoritative     = not _is_client
	_creature.is_authoritative  = not _is_client
	_creature_ai.is_authoritative = not _is_client

	# Chunk streaming (Phase 17) — wire the manager to its collaborators.
	_chunk_manager.terrain_slice  = _terrain
	_chunk_manager.voxel_slice    = _voxel
	_chunk_manager.player_slice   = _player
	_chunk_manager.creature_slice = _creature

	# Minimap overlay (Phase 17) — top-right, biome-coloured chunk view.
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
	GameBus.creature_alert.connect(func(iid): print("[AI] %s → alert" % iid))
	GameBus.creature_aggressive.connect(func(iid): print("[AI] %s → aggressive" % iid))
	GameBus.creature_fleeing.connect(func(iid): print("[AI] %s → fleeing" % iid))
	GameBus.station_placed.connect(func(id, type, pos): print("[Station] %s [%s] placed at %s" % [type, id, pos]))
	GameBus.item_broke.connect(func(iid): print("[Item] %s broke!" % iid))
	GameBus.chunk_loaded.connect(func(pos): print("[Chunk] loaded %s" % pos))
	GameBus.chunk_unloaded.connect(func(pos): print("[Chunk] unloaded %s" % pos))
	GameBus.peer_connected.connect(_on_peer_connected)
	GameBus.world_snapshot_received.connect(_on_world_snapshot_received)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	# Lighting — a directional "sun" plus soft ambient sky fill.
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
## sequence in _boot_world(). False keeps boot output minimal in production.
const DEBUG := false

func _boot_world() -> void:
	print("\n=== Project Nihon — world boot ===")

	if _is_client:
		_boot_client()
		return

	# Place the player on top of the terrain at the spawn point so it doesn't
	# spawn embedded in (and fall through) the collision mesh.
	var spawn_xz := Vector2(16.0, 16.0)
	var ground_h := _terrain.get_height_at(spawn_xz)
	_player.spawn_at(Vector3(spawn_xz.x, ground_h + 1.0, spawn_xz.y))
	print("[Player] spawning on terrain at (%.1f, %.1f, %.1f)" % [spawn_xz.x, ground_h + 1.0, spawn_xz.y])

	# Chunk streaming (Phase 17) — load the window of chunks around the player
	# instead of a single fixed origin chunk. VoxelSlice builds the mesh on
	# chunk_ready and CreatureSlice spawns each chunk's budget.
	print("\n[Terrain] Streaming chunks around player (view distance %d)…" % _chunk_manager.view_distance)
	_chunk_manager.start()
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
		print("\n[Creatures] %d creatures spawned; first: %s [%s] at %s" % [
			instances.size(),
			first["creature_id"],
			first["instance_id"],
			first["position"],
		])
		# Request one combat round against the first spawned creature via the bus
		# (the real trigger comes from player left-click; this validates the pipeline).
		GameBus.combat_round_requested.emit("player", first["instance_id"])

	# Mining & building — mine a surface block (biome material → inventory) and
	# place one back, proving the voxel edit API and material flow end to end.
	print("\n[Mining] Mining a surface block near spawn…")
	var mine_spot := Vector3(spawn_xz.x + 6.0, ground_h, spawn_xz.y + 2.0)
	var mined := _voxel.mine_block(mine_spot)
	if mined.get("success", false):
		print("[Mining] mined %s ×%d" % [mined["material"], mined["quantity"]])
	_inventory.add_item("Ashite", 4)
	_voxel.set_place_material("Ashite")
	var placed := _voxel.place_block(Vector3(spawn_xz.x + 10.0, ground_h, spawn_xz.y + 2.0), Vector3.UP)
	print("[Building] placed Ashite block: %s" % ("ok" if placed else "blocked"))

	if DEBUG:
		# Technology + crafting demo (DEBUG only): exercises the research and
		# station gates with expected-fail craft attempts and console output.
		print("\n[Technology] Seeding materials + demonstrating research gates…")
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
	print("\n[Persistence] Saving initial world snapshot to slot 0…")
	var snapshot := {
		"version":   1,
		"timestamp": Time.get_ticks_msec(),
		"player":    {
			"name":     "Traveller",
			"position": [_player.get_position().x, _player.get_position().y, _player.get_position().z],
			"hp":       _player.get_hp(),
		},
		"inventory": _inventory.get_contents(),
		"world":     {
			"chunks":       _voxel.get_chunk_manifest(),
			"dirty_chunks": _voxel.get_dirty_chunk_keys(),
		},
		"technology": _technology.get_statuses(),
	}
	GameBus.save_requested.emit(0, snapshot)
	GameBus.load_requested.emit(0)

	# Networking — open local host so peers can connect.
	print("\n[Networking] Starting local host on port %d…" % _networking.DEFAULT_PORT)
	_networking.host(_networking.DEFAULT_PORT, 1)

	print("\n=== World boot complete — LMB/F attack · RMB mine · MMB place · R cycle ===\n")

## Client boot path (Phase 18): do NOT run the authoritative simulation. Join
## the host and wait for the world snapshot before showing anything.
func _boot_client() -> void:
	print("[Networking] Client mode — joining %s:%d, awaiting world snapshot…" % [_host_address, _networking.DEFAULT_PORT])
	var err: Error = _networking.join(_host_address, _networking.DEFAULT_PORT)
	if err != OK:
		push_error("[Networking] client failed to connect to %s — %s" % [_host_address, error_string(err)])
		_snapshot_pending = false
		return
	_snapshot_pending = true
	_snapshot_elapsed = 0.0

func _on_peer_connected(peer_id: int) -> void:
	if _is_client:
		return
	# Host: ship the authoritative world snapshot to the newly connected client.
	print("[Networking] peer %d connected — sending world snapshot" % peer_id)
	_networking.send_snapshot(peer_id, _build_snapshot())

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
## (_boot_world), so this is a no-op on clients until one exists.
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

## Host-side: serialize authoritative world state for a connecting client.
func _build_snapshot() -> Dictionary:
	var players := {}
	players[str(multiplayer.get_unique_id())] = _player.get_position()
	# Phase 19 — include last-known remote player states so a rejoining client
	# resumes from its last authoritative position after a disconnect.
	var last_known := _networking.get_last_known_states()
	for pid in last_known:
		var last_pos: Vector3 = last_known[pid]
		players[str(pid)] = [last_pos.x, last_pos.y, last_pos.z]
	return {
		"version":   1,
		"heightmaps": _voxel.get_heightmaps(),
		"edits":     _voxel.get_chunk_manifest(),
		"creatures": _creature.get_snapshot_creatures(),
		"inventory": _inventory.get_contents(),
		"players":   players,
	}

## Client-side: apply the host's world snapshot and begin rendering.
func _on_world_snapshot_received(data: Dictionary) -> void:
	if not _is_client:
		return
	print("[Networking] world snapshot received — applying state")
	if data.has("heightmaps") and data["heightmaps"] is Dictionary:
		_voxel.apply_heightmaps(data["heightmaps"])
	if data.has("edits") and data["edits"] is Dictionary:
		_voxel.apply_chunk_manifest(data["edits"])
	if data.has("creatures") and data["creatures"] is Array:
		_creature.apply_snapshot_creatures(data["creatures"])
	if data.has("inventory") and data["inventory"] is Dictionary:
		_inventory.replace_contents(data["inventory"])
	if data.has("players") and data["players"] is Dictionary:
		for pid in data["players"]:
			var pos = data["players"][pid]
			if pos is Array and pos.size() >= 3:
				GameBus.remote_player_state.emit(int(pid), Vector3(float(pos[0]), float(pos[1]), float(pos[2])))
	_snapshot_pending = false

# ---------------------------------------------------------------------------
# Bus listeners
# ---------------------------------------------------------------------------

func _on_chunk_ready(chunk_pos: Vector2i, heightmap: Array) -> void:
	var sample: float = heightmap[0] if heightmap.size() > 0 else 0.0
	print("[Terrain] chunk_ready pos=%s  height[0]=%.2f" % [chunk_pos, sample])

func _on_combat_resolved(result: Dictionary) -> void:
	print("[Battle] %s → %s : %s  dmg=%.1f  defender_hp=%.1f" % [
		result.get("attacker", "?"),
		result.get("defender", "?"),
		result.get("outcome",  "?"),
		result.get("damage",   0.0),
		result.get("defender_hp_remaining", 0.0),
	])

## Drive the player avatar's attack animation whenever the player attacks.
func _on_combat_round_requested(attacker_id: String, defender_id: String) -> void:
	if attacker_id == "player" and _character.get_player_character() != "":
		GameBus.character_attack_requested.emit(_character.get_player_character())

func _on_creature_died(entity_id: String, position: Vector3, killer_id: String) -> void:
	print("[Death] %s died at %s  killer=%s" % [entity_id, position, killer_id])

func _on_creature_spawned(instance_id: String, creature_id: String, position: Vector3) -> void:
	print("[Creature] %s [%s] spawned at %s" % [creature_id, instance_id, position])

func _on_loot_dropped(pickup_id: String, item_id: String, position: Vector3, quantity: int) -> void:
	print("[Loot] pickup=%s  item=%s ×%d  at %s" % [pickup_id, item_id, quantity, position])

func _on_item_picked_up(item_id: String, quantity: int) -> void:
	print("[Inventory] picked up %s ×%d" % [item_id, quantity])
	print("[Inventory] contents: %s" % str(_inventory.get_contents()))

func _on_player_state_changed(payload: Dictionary) -> void:
	pass   # logged by PlayerSlice; suppress repetitive output here

func _on_inventory_full() -> void:
	print("[Inventory] FULL — pickups will be rejected")

func _on_character_spawned(instance_id: String, skeleton_id: String, position: Vector3) -> void:
	print("[Character] %s [%s] assembled at %s" % [skeleton_id, instance_id, position])

func _on_craft_resolved(result: Dictionary) -> void:
	if result.get("success", false):
		print("[Crafting] %s → %s" % [result.get("recipe_id", "?"), str(result.get("outputs", []))])
	else:
		print("[Crafting] %s FAILED — %s" % [result.get("recipe_id", "?"), result.get("reason", "?")])
	print("[Inventory] contents: %s" % str(_inventory.get_contents()))

func _on_research_resolved(result: Dictionary) -> void:
	if result.get("success", false):
		print("[Technology] %s → %s" % [result.get("tech_id", "?"), result.get("status", "?")])
	else:
		print("[Technology] %s FAILED — %s" % [result.get("tech_id", "?"), result.get("reason", "?")])

func _on_technology_unlocked(tech_id: String) -> void:
	print("[Technology] unlocked %s" % tech_id)

func _on_block_mined(material: String, quantity: int, position: Vector3) -> void:
	print("[Mining] %s ×%d at %s" % [material, quantity, position])

func _on_block_placed(material: String, position: Vector3) -> void:
	print("[Building] %s placed at %s" % [material, position])

func _on_player_damaged(damage: float, attacker_id: String) -> void:
	print("[Player] took %.1f dmg from %s  hp=%.1f" % [damage, attacker_id, _player.get_hp()])

func _on_player_died(position: Vector3, killer_id: String) -> void:
	print("[Player] died at %s  killer=%s" % [position, killer_id])
	if _character.get_player_character() != "":
		GameBus.character_death_requested.emit(_character.get_player_character())

func _on_player_respawned(position: Vector3) -> void:
	print("[Player] respawned at %s" % position)

func _on_save_completed(slot: int) -> void:
	print("[Persistence] save_completed slot=%d" % slot)
	# The snapshot is on disk; reset dirty-chunk tracking so the next save only
	# re-serializes chunks edited after this point.
	_voxel.clear_dirty_chunks()

func _on_load_completed(slot: int, data: Dictionary) -> void:
	print("[Persistence] load_completed slot=%d  keys=%s" % [slot, data.keys()])
	var world: Dictionary = data.get("world", {})
	if world.has("chunks"):
		_voxel.apply_chunk_manifest(world["chunks"])
		var edit_count := 0
		for ckey in world["chunks"]:
			edit_count += world["chunks"][ckey].get("edits", {}).size()
		print("[Persistence] restored %d voxel edits across %d chunks" % [edit_count, world["chunks"].size()])
	elif world.has("voxel_edits"):
		_voxel.apply_edits(world["voxel_edits"], world.get("voxel_materials", {}))
		print("[Persistence] restored %d voxel edits" % world["voxel_edits"].size())
	if data.has("technology"):
		_technology.apply_statuses(data["technology"])
		print("[Persistence] restored technology statuses: %s" % str(data["technology"]))

# ---------------------------------------------------------------------------
# GameData smoke test
# ---------------------------------------------------------------------------

func _check_game_data() -> void:
	print("\n=== GameData registry check ===")
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
			else:
				print("%s → %s OK" % [reg_name, key])
