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
const CharacterSlice   := preload("res://src/character/character_slice.gd")
const CraftingSlice    := preload("res://src/crafting/crafting_slice.gd")
const TechnologySlice  := preload("res://src/technology/technology_slice.gd")
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
var _character:   CharacterSlice
var _crafting:    CraftingSlice
var _technology:  TechnologySlice

func _ready() -> void:
	# Run the automated tests before any production slice enters the tree.
	# The suite emits signals on the shared GameBus (creature_died, chunk_ready,
	# combat, loot…). Running it first keeps those emissions from leaking into
	# production state — previously the test creature_died calls were marking
	# every freshly spawned creature dead and hiding its body on world boot.
	_run_tests()

	_terrain     = TerrainSlice.new()
	_voxel       = VoxelSlice.new()
	_battle      = BattleSlice.new()
	_creature    = CreatureSlice.new()
	_networking  = NetworkingSlice.new()
	_persistence = PersistenceSlice.new()
	_player      = PlayerSlice.new()
	_loot        = LootSlice.new()
	_inventory   = InventorySlice.new()
	_character   = CharacterSlice.new()
	_crafting    = CraftingSlice.new()
	_technology  = TechnologySlice.new()

	# CreatureSlice needs the terrain to place spawns on the surface; wire it
	# before the slices enter the tree so its _ready() can use it.
	_creature.terrain_slice = _terrain

	for s in [_terrain, _voxel, _battle, _creature, _networking, _persistence, _player, _loot, _inventory, _character, _crafting, _technology]:
		s.name = s.get_script().resource_path.get_file().get_basename()
		add_child(s)

	# Cross-slice wiring: direct references where the bus cannot carry context.
	_inventory.loot_slice     = _loot
	_player.creature_slice    = _creature
	_player.voxel_slice       = _voxel
	_battle.creature_slice    = _creature
	_loot.creature_slice      = _creature
	_crafting.inventory_slice = _inventory
	_crafting.technology_slice = _technology
	_technology.inventory_slice = _inventory
	_voxel.terrain_slice      = _terrain
	_voxel.inventory_slice    = _inventory

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
	GameBus.character_spawned.connect(_on_character_spawned)
	GameBus.craft_resolved.connect(_on_craft_resolved)
	GameBus.research_resolved.connect(_on_research_resolved)
	GameBus.technology_unlocked.connect(_on_technology_unlocked)
	GameBus.block_mined.connect(_on_block_mined)
	GameBus.block_placed.connect(_on_block_placed)

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

	# Character system — spawn a demo humanoid and a non-humanoid (quadruped)
	# near the player to exercise the appearance pipeline end to end.
	_character.create_character("TravellerHuman", Vector3(spawn_xz.x + 3.0, ground_h + 1.0, spawn_xz.y))
	_character.create_character("BoarRider", Vector3(spawn_xz.x - 3.0, ground_h + 1.0, spawn_xz.y))

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

	# Technology + crafting — prove the Phase 13 gate: recipes stay locked until
	# their owning technology is researched. Seed materials, show a craft fail
	# while locked, research the two starter techs, then run the smithing chain.
	print("\n[Technology] Seeding materials + demonstrating research gates…")
	var starter_kit := { "Ferrite": 10, "Thornwood": 6 }
	for item_id in starter_kit:
		_inventory.add_item(item_id, starter_kit[item_id])
	_crafting.set_skill("Smithing", "journeyman")
	_crafting.set_skill("Carpentry", "apprentice")

	# Crafting before research must fail on the technology gate.
	GameBus.craft_requested.emit("RecipeFerriteIngot")      # FAIL: technology_locked

	# Research the two starter technologies (consume materials, then complete).
	GameBus.research_requested.emit("TechBasicSmithing")    # consumes Ferrite ×4
	_technology.complete_research("TechBasicSmithing")      # force-complete (demo)
	GameBus.research_requested.emit("TechBasicCarpentry")   # consumes Thornwood ×4
	_technology.complete_research("TechBasicCarpentry")

	# Now the smithing chain resolves through the bus.
	GameBus.craft_requested.emit("RecipeFerriteIngot")      # 2 Ferrite → 1 FerriteIngot
	GameBus.craft_requested.emit("RecipeFerriteIngot")      # 2 Ferrite → 1 FerriteIngot
	GameBus.craft_requested.emit("RecipeThornwoodPlank")    # 2 Thornwood → 3 ThornwoodPlank
	GameBus.craft_requested.emit("RecipeFerritePick")       # 2 ingot + 1 plank → pick
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
			"voxel_edits":     _voxel.get_edits(),
			"voxel_materials": _voxel.get_edit_materials(),
		},
		"technology": _technology.get_statuses(),
	}
	GameBus.save_requested.emit(0, snapshot)
	GameBus.load_requested.emit(0)

	# Networking — open local host so peers can connect.
	print("\n[Networking] Starting local host on port 7777…")
	_networking.host(7777, 1)

	print("\n=== World boot complete — LMB/F attack · RMB mine · MMB place · R cycle ===\n")

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

func _on_save_completed(slot: int) -> void:
	print("[Persistence] save_completed slot=%d" % slot)

func _on_load_completed(slot: int, data: Dictionary) -> void:
	print("[Persistence] load_completed slot=%d  keys=%s" % [slot, data.keys()])
	var world: Dictionary = data.get("world", {})
	if world.has("voxel_edits"):
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
