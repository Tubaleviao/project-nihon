extends Node
## Game root — integration layer that owns all slices and wires them together.
##
## Slices communicate exclusively through GameBus signals. This script
## instantiates slices, sets cross-slice references that cannot travel the bus,
## and drives the startup sequence (tests → GameData check → terrain boot).

const TerrainSlice     := preload("res://src/terrain/terrain_slice.gd")
const VoxelSlice       := preload("res://src/terrain/voxel_slice.gd")
const BattleSlice      := preload("res://src/battle/battle_slice.gd")
const CreatureSlice    := preload("res://src/creature/creature_slice.gd")
const NetworkingSlice  := preload("res://src/networking/networking_slice.gd")
const PersistenceSlice := preload("res://src/persistence/persistence_slice.gd")
const PlayerSlice      := preload("res://src/player/player_slice.gd")
const LootSlice        := preload("res://src/loot/loot_slice.gd")
const InventorySlice   := preload("res://src/inventory/inventory_slice.gd")
const TestSuite        := preload("res://src/tests/test_suite.gd")

var _terrain:     TerrainSlice
var _voxel:       VoxelSlice
var _battle:      BattleSlice
var _creature:    CreatureSlice
var _networking:  NetworkingSlice
var _persistence: PersistenceSlice
var _player:      PlayerSlice
var _loot:        LootSlice
var _inventory:   InventorySlice

func _ready() -> void:
	_terrain     = TerrainSlice.new()
	_voxel       = VoxelSlice.new()
	_battle      = BattleSlice.new()
	_creature    = CreatureSlice.new()
	_networking  = NetworkingSlice.new()
	_persistence = PersistenceSlice.new()
	_player      = PlayerSlice.new()
	_loot        = LootSlice.new()
	_inventory   = InventorySlice.new()

	for s in [_terrain, _voxel, _battle, _creature, _networking, _persistence, _player, _loot, _inventory]:
		s.name = s.get_script().resource_path.get_file().get_basename()
		add_child(s)

	# Cross-slice wiring: direct references where the bus cannot carry context.
	_inventory.loot_slice    = _loot
	_player.creature_slice   = _creature
	_battle.creature_slice   = _creature
	_loot.creature_slice     = _creature

	# Bus listeners for integration-layer logging.
	GameBus.chunk_ready.connect(_on_chunk_ready)
	GameBus.combat_round_resolved.connect(_on_combat_resolved)
	GameBus.save_completed.connect(_on_save_completed)
	GameBus.load_completed.connect(_on_load_completed)
	GameBus.creature_died.connect(_on_creature_died)
	GameBus.creature_spawned.connect(_on_creature_spawned)
	GameBus.loot_dropped.connect(_on_loot_dropped)
	GameBus.item_picked_up.connect(_on_item_picked_up)
	GameBus.player_state_changed.connect(_on_player_state_changed)
	GameBus.inventory_full.connect(_on_inventory_full)

	# Run automated tests before anything else so failures are visible early.
	_run_tests()

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

# ---------------------------------------------------------------------------
# World boot
# ---------------------------------------------------------------------------

func _boot_world() -> void:
	print("\n=== Project Nihon — world boot ===")

	# Terrain — request the origin chunk; VoxelSlice reacts to chunk_ready.
	print("\n[Terrain] Requesting origin chunk (0, 0)…")
	_terrain.request_chunk(Vector2i(0, 0))

	# Place the player on top of the terrain at the spawn point so it doesn't
	# spawn embedded in (and fall through) the collision mesh.
	var spawn_xz := Vector2(16.0, 16.0)
	var ground_h := _terrain.get_height_at(spawn_xz)
	_player.spawn_at(Vector3(spawn_xz.x, ground_h + 1.0, spawn_xz.y))
	print("[Player] spawning on terrain at (%.1f, %.1f, %.1f)" % [spawn_xz.x, ground_h + 1.0, spawn_xz.y])

	# Creature slice already spawned creatures from SPAWN_MANIFEST in _ready().
	# Trigger an initial creature awareness pass: the nearest ForestBoar
	# fires a detect signal through the bus so combat can start immediately.
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
	}
	GameBus.save_requested.emit(0, snapshot)
	GameBus.load_requested.emit(0)

	# Networking — open local host so peers can connect.
	print("\n[Networking] Starting local host on port 7777…")
	_networking.host(7777, 1)

	print("\n=== World boot complete — attack with left-click or F ===\n")

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

func _on_save_completed(slot: int) -> void:
	print("[Persistence] save_completed slot=%d" % slot)

func _on_load_completed(slot: int, data: Dictionary) -> void:
	print("[Persistence] load_completed slot=%d  keys=%s" % [slot, data.keys()])

# ---------------------------------------------------------------------------
# GameData smoke test
# ---------------------------------------------------------------------------

func _check_game_data() -> void:
	print("\n=== GameData registry check ===")
	var registries := {
		"BIOMES":       GameData.BIOMES,
		"CREATURES":    GameData.CREATURES,
		"DECISIONS":    GameData.DECISIONS,
		"ITEMS":        GameData.ITEMS,
		"MATERIALS":    GameData.MATERIALS,
		"PROFESSIONS":  GameData.PROFESSIONS,
		"RECIPES":      GameData.RECIPES,
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
