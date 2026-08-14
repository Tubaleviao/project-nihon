extends Node
## Game root — integration layer that owns all slices and runs a smoke-test
## sequence on startup to verify the bus, data loading, and each slice.
##
## Slices communicate exclusively through GameBus signals; this script only
## instantiates them and (for the prototype) drives the smoke-test sequence.

const TerrainSlice     := preload("res://src/terrain/terrain_slice.gd")
const VoxelSlice       := preload("res://src/terrain/voxel_slice.gd")
const BattleSlice      := preload("res://src/battle/battle_slice.gd")
const NetworkingSlice  := preload("res://src/networking/networking_slice.gd")
const PersistenceSlice := preload("res://src/persistence/persistence_slice.gd")
const PlayerSlice      := preload("res://src/player/player_slice.gd")
const LootSlice        := preload("res://src/loot/loot_slice.gd")
const InventorySlice   := preload("res://src/inventory/inventory_slice.gd")
const TestSuite        := preload("res://src/tests/test_suite.gd")

var _terrain:     TerrainSlice
var _voxel:       VoxelSlice
var _battle:      BattleSlice
var _networking:  NetworkingSlice
var _persistence: PersistenceSlice
var _player:      PlayerSlice
var _loot:        LootSlice
var _inventory:   InventorySlice

func _ready() -> void:
	_terrain     = TerrainSlice.new()
	_voxel       = VoxelSlice.new()
	_battle      = BattleSlice.new()
	_networking  = NetworkingSlice.new()
	_persistence = PersistenceSlice.new()
	_player      = PlayerSlice.new()
	_loot        = LootSlice.new()
	_inventory   = InventorySlice.new()

	for s in [_terrain, _voxel, _battle, _networking, _persistence, _player, _loot, _inventory]:
		s.name = s.get_script().resource_path.get_file().get_basename()
		add_child(s)

	# Cross-slice wiring that can't live on the bus (direct references needed).
	_inventory.loot_slice = _loot

	# Wire cross-slice reactions through the bus.
	GameBus.chunk_ready.connect(_on_chunk_ready)
	GameBus.combat_round_resolved.connect(_on_combat_resolved)
	GameBus.save_completed.connect(_on_save_completed)
	GameBus.load_completed.connect(_on_load_completed)
	GameBus.creature_died.connect(_on_creature_died)
	GameBus.loot_dropped.connect(_on_loot_dropped)
	GameBus.item_picked_up.connect(_on_item_picked_up)
	GameBus.player_state_changed.connect(_on_player_state_changed)
	GameBus.inventory_full.connect(_on_inventory_full)

	# Run automated tests before the smoke test so failures are visible early.
	_run_tests()

	# Verify GameData entries load cleanly.
	_check_game_data()

	# Prototype smoke test — exercises each slice.
	_smoke_test()

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
# Smoke test
# ---------------------------------------------------------------------------

func _smoke_test() -> void:
	print("\n=== Vertical slice smoke test ===")

	# --- Terrain + Voxel ---
	print("\n[Terrain] Requesting chunk (0, 0)…")
	_terrain.request_chunk(Vector2i(0, 0))
	# VoxelSlice automatically reacts to chunk_ready and builds the mesh.

	# --- Battle + Death signal ---
	print("\n[Battle] Requesting combat round: ForestBoar vs GraywolfPack…")
	GameBus.combat_round_requested.emit("ForestBoar", "GraywolfPack")

	# --- Simulate a creature death to test loot + inventory pipeline ---
	print("\n[Loot] Simulating ForestBoar death…")
	GameBus.creature_died.emit("ForestBoar", Vector3(16.0, 0.0, 16.0), "player")

	# --- Persistence ---
	print("\n[Persistence] Saving world snapshot to slot 0…")
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

	# --- Networking ---
	print("\n[Networking] Starting local host on port 7777…")
	_networking.host(7777, 1)

	print("\n=== Smoke test dispatched — watch signals above ===\n")

# ---------------------------------------------------------------------------
# Bus listeners
# ---------------------------------------------------------------------------

func _on_chunk_ready(chunk_pos: Vector2i, heightmap: Array) -> void:
	var sample := heightmap[0] if heightmap.size() > 0 else 0.0
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
