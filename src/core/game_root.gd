extends Node
## Game root — integration layer that owns all slices and runs a smoke-test
## sequence on startup to verify the bus, data loading, and each slice.
##
## Slices communicate exclusively through GameBus signals; this script only
## instantiates them and (for the prototype) drives the smoke-test sequence.

const TerrainSlice    := preload("res://src/terrain/terrain_slice.gd")
const BattleSlice     := preload("res://src/battle/battle_slice.gd")
const NetworkingSlice := preload("res://src/networking/networking_slice.gd")
const PersistenceSlice:= preload("res://src/persistence/persistence_slice.gd")

var _terrain:     TerrainSlice
var _battle:      BattleSlice
var _networking:  NetworkingSlice
var _persistence: PersistenceSlice

func _ready() -> void:
	_terrain     = TerrainSlice.new()
	_battle      = BattleSlice.new()
	_networking  = NetworkingSlice.new()
	_persistence = PersistenceSlice.new()

	for s in [_terrain, _battle, _networking, _persistence]:
		s.name = s.get_script().resource_path.get_file().get_basename()
		add_child(s)

	# Wire cross-slice reactions through the bus.
	GameBus.chunk_ready.connect(_on_chunk_ready)
	GameBus.combat_round_resolved.connect(_on_combat_resolved)
	GameBus.save_completed.connect(_on_save_completed)
	GameBus.load_completed.connect(_on_load_completed)

	# Verify GameData entries load cleanly (original main.gd smoke test).
	_check_game_data()

	# Prototype smoke test — exercises each slice.
	_smoke_test()

# ---------------------------------------------------------------------------
# Smoke test
# ---------------------------------------------------------------------------

func _smoke_test() -> void:
	print("\n=== Vertical slice smoke test ===")

	# --- Terrain ---
	print("\n[Terrain] Requesting chunk (0, 0)…")
	_terrain.request_chunk(Vector2i(0, 0))

	# --- Battle ---
	print("\n[Battle] Requesting combat round: ForestBoar vs GraywolfPack…")
	GameBus.combat_round_requested.emit("ForestBoar", "GraywolfPack")

	# --- Persistence ---
	print("\n[Persistence] Saving world snapshot to slot 0…")
	var snapshot := {
		"version":   1,
		"timestamp": Time.get_ticks_msec(),
		"player":    { "name": "Traveller", "position": [0.0, 0.0, 0.0] },
	}
	GameBus.save_requested.emit(0, snapshot)
	GameBus.load_requested.emit(0)

	# --- Networking (localhost self-connect to verify ENet init) ---
	print("\n[Networking] Starting local host on port 7777…")
	_networking.host(7777, 1)

	print("\n=== Smoke test dispatched — watch signals above ===\n")

# ---------------------------------------------------------------------------
# Bus listeners (cross-slice reactions go here)
# ---------------------------------------------------------------------------

func _on_chunk_ready(chunk_pos: Vector2i, heightmap: Array) -> void:
	var sample := heightmap[0] if heightmap.size() > 0 else 0.0
	print("[Terrain] chunk_ready pos=%s  height[0]=%.2f" % [chunk_pos, sample])

	# Persist the generated chunk origin as part of the world state.
	var chunk_data := { "chunk": { "x": chunk_pos.x, "y": chunk_pos.y, "samples": heightmap.size() } }
	# (In production this would merge into a full world dict.)
	_ = chunk_data  # suppress unused-variable warning

func _on_combat_resolved(result: Dictionary) -> void:
	print("[Battle] %s → %s : %s  dmg=%.1f  defender_hp=%.1f" % [
		result.get("attacker", "?"),
		result.get("defender", "?"),
		result.get("outcome",  "?"),
		result.get("damage",   0.0),
		result.get("defender_hp_remaining", 0.0),
	])

func _on_save_completed(slot: int) -> void:
	print("[Persistence] save_completed slot=%d" % slot)

func _on_load_completed(slot: int, data: Dictionary) -> void:
	print("[Persistence] load_completed slot=%d  keys=%s" % [slot, data.keys()])

# ---------------------------------------------------------------------------
# GameData smoke test (carried over from main.gd)
# ---------------------------------------------------------------------------

func _check_game_data() -> void:
	print("\n=== GameData registry check ===")
	var registries := {
		"BIOMES":      GameData.BIOMES,
		"CREATURES":   GameData.CREATURES,
		"DECISIONS":   GameData.DECISIONS,
		"ITEMS":       GameData.ITEMS,
		"MATERIALS":   GameData.MATERIALS,
		"PROFESSIONS": GameData.PROFESSIONS,
		"RECIPES":     GameData.RECIPES,
		"SKILLS":      GameData.SKILLS,
		"SYSTEMS":     GameData.SYSTEMS,
		"TECHNOLOGIES":GameData.TECHNOLOGIES,
		"WORLD_SYSTEMS":GameData.WORLD_SYSTEMS,
	}
	for reg_name in registries:
		var reg: Dictionary = registries[reg_name]
		for key in reg:
			if reg[key] == null:
				push_error("%s → %s FAILED" % [reg_name, key])
			else:
				print("%s → %s OK" % [reg_name, key])
