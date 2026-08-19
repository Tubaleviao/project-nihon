extends Node
## Creature slice — spawns and manages creature instances in the world.
##
## Stats (baseHp, baseDamage) come exclusively from GameData.CREATURES so the
## fabric is the single source of truth. Only ForestBoar is spawned in the
## playable demo area; the full roster is available via GameData.CREATURES.
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : creature_died(entity_id, position, killer_id)
##   OUT : creature_spawned(instance_id, creature_id, position)
##
## Public API:
##   nearest_creature(from_pos: Vector3, radius: float) -> String   (instance_id or "")
##   get_instance_creature_id(instance_id: String)      -> String   (fabric key)
##   get_all_instances()                                -> Array[Dictionary]

## Spread around each biome search origin.
const SPAWN_RADIUS := 10.0

## Maps fabric biome enum integer to the key returned by terrain_slice.get_biome_at().
## Order: 0=TemperateForest, 1=TemperateGrassland, 2=VolcanicBadlands, 3=Twilight, 4=VoidRift
const BIOME_KEYS: Array = [
	"TemperateForest",
	"TemperateGrassland",
	"VolcanicBadlands",
	"Twilight",
	"VoidRift",
]

## Approximate XZ search centres per biome index — seeds the get_biome_at() position search.
const BIOME_SEARCH_ORIGINS: Array = [
	Vector2(16.0, 16.0),  # TemperateForest
	Vector2(48.0, 32.0),  # TemperateGrassland
	Vector2(80.0, 16.0),  # VolcanicBadlands
	Vector2(16.0, 80.0),  # Twilight
	Vector2(80.0, 80.0),  # VoidRift
]

## Instance record: { "creature_id", "position", "state", "hp", "respawn_at", "body" }
var _instances: Dictionary = {}
var _next_id: int = 0

## Set by game_root before the slices enter the tree so creatures can spawn on
## the terrain surface instead of a fixed height.
var terrain_slice: Node = null

func _ready() -> void:
	GameBus.creature_died.connect(_on_creature_died)
	_spawn_initial_creatures()

func _process(_delta: float) -> void:
	_tick_respawn()

## Return the instance_id of the nearest live creature within radius, or "".
func nearest_creature(from_pos: Vector3, radius: float) -> String:
	var best_id := ""
	var best_dist := radius + 1.0
	for iid in _instances:
		var inst: Dictionary = _instances[iid]
		if inst["state"] == "dead":
			continue
		var d: float = inst["position"].distance_to(from_pos)
		if d < best_dist:
			best_dist = d
			best_id = iid
	return best_id

## Return the fabric creature key for an instance (e.g. "ForestBoar").
func get_instance_creature_id(instance_id: String) -> String:
	if not _instances.has(instance_id):
		return ""
	return _instances[instance_id]["creature_id"]

## Move an instance to a new world position, keeping body and record in sync.
func set_instance_position(instance_id: String, pos: Vector3) -> void:
	if not _instances.has(instance_id):
		return
	_instances[instance_id]["position"] = pos
	var body = _instances[instance_id].get("body", null)
	if body != null and is_instance_valid(body):
		body.position = pos

## Return a snapshot of all active instances (for HUD / minimap use).
func get_all_instances() -> Array:
	var out: Array = []
	for iid in _instances:
		var inst: Dictionary = _instances[iid]
		out.append({
			"instance_id": iid,
			"creature_id": inst["creature_id"],
			"position":    inst["position"],
			"state":       inst["state"],
			"hp":          inst["hp"],
		})
	return out

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _spawn_initial_creatures() -> void:
	for creature_id in GameData.CREATURES:
		var res: Resource = GameData.CREATURES[creature_id]
		var count: int = int(res.get("spawnCount")) if res.has_method("get") else 1
		for i in range(count):
			_spawn(creature_id)

func _spawn(creature_id: String) -> String:
	var res: Resource = GameData.CREATURES.get(creature_id, null)
	if res == null:
		push_error("CreatureSlice: unknown creature '%s' in GameData.CREATURES" % creature_id)
		return ""

	var hp: float = float(res.get("baseHp"))
	var angle  := randf_range(0.0, TAU)
	var r      := randf_range(2.0, SPAWN_RADIUS)
	var biome_idx: int = int(res.get("biome"))
	var biome_key: String = BIOME_KEYS[biome_idx] if biome_idx < BIOME_KEYS.size() else BIOME_KEYS[0]
	var search_origin: Vector2 = BIOME_SEARCH_ORIGINS[biome_idx] if biome_idx < BIOME_SEARCH_ORIGINS.size() else BIOME_SEARCH_ORIGINS[0]
	var xz: Vector2 = _find_biome_position(biome_key, search_origin)
	var pos: Vector3 = Vector3(xz.x + cos(angle) * r, 0.0, xz.y + sin(angle) * r)

	# Sit the creature on the terrain surface instead of a fixed height.
	if terrain_slice != null and terrain_slice.has_method("get_height_at"):
		pos.y = terrain_slice.get_height_at(Vector2(pos.x, pos.z))

	var iid := "creature_%d" % _next_id
	_next_id += 1

	# Build a visible body so the creature can be seen in the world.
	var body := _make_visual(creature_id, pos)
	add_child(body)

	_instances[iid] = {
		"creature_id": creature_id,
		"position":    pos,
		"spawn_pos":   pos,
		"state":       "idle",
		"hp":          hp,
		"respawn_at":  -1.0,
		"body":        body,
	}

	GameBus.creature_spawned.emit(iid, creature_id, pos)
	print("CreatureSlice: spawned %s [%s] at %s  hp=%.0f" % [creature_id, iid, pos, hp])
	return iid

## Probe outward from search_origin until terrain_slice.get_biome_at() returns the
## desired biome key, then return that XZ coordinate.  Falls back to search_origin
## after BIOME_SEARCH_STEPS attempts so spawning always succeeds even if the biome
## is not reachable from the seed position.
const BIOME_SEARCH_STEPS := 12
const BIOME_SEARCH_STEP_SIZE := 8.0

func _find_biome_position(biome_key: String, seed_xz: Vector2) -> Vector2:
	if terrain_slice == null or not terrain_slice.has_method("get_biome_at"):
		return seed_xz
	for step in range(BIOME_SEARCH_STEPS):
		var angle := randf_range(0.0, TAU)
		var dist  := BIOME_SEARCH_STEP_SIZE * (step + 1)
		var probe := seed_xz + Vector2(cos(angle) * dist, sin(angle) * dist)
		if terrain_slice.get_biome_at(probe) == biome_key:
			return probe
	return seed_xz

func _on_creature_died(entity_id: String, _position: Vector3, _killer_id: String) -> void:
	if entity_id == "player":
		return
	# entity_id may be either a fabric key or an instance_id.
	# Mark matching instance(s) dead and schedule respawn using per-creature respawnSeconds.
	for iid in _instances:
		var inst: Dictionary = _instances[iid]
		if inst["creature_id"] == entity_id or iid == entity_id:
			if inst["state"] != "dead":
				var cid: String = inst["creature_id"]
				var res: Resource = GameData.CREATURES.get(cid, null)
				var respawn_secs: float = float(res.get("respawnSeconds")) if res else 300.0
				inst["state"]      = "dead"
				inst["hp"]         = 0.0
				inst["respawn_at"] = Time.get_ticks_msec() + respawn_secs * 1000.0
				if inst.has("body") and inst["body"]:
					inst["body"].visible = false

func _tick_respawn() -> void:
	var now := float(Time.get_ticks_msec())
	for iid in _instances:
		var inst: Dictionary = _instances[iid]
		if inst["state"] == "dead" and inst["respawn_at"] > 0.0 and now >= inst["respawn_at"]:
			var creature_id: String = inst["creature_id"]
			var res: Resource = GameData.CREATURES.get(creature_id, null)
			var max_hp: float = float(res.get("baseHp"))
			inst["state"]      = "idle"
			inst["hp"]         = max_hp
			inst["respawn_at"] = -1.0
			inst["position"]   = inst["spawn_pos"]
			if inst.has("body") and inst["body"]:
				inst["body"].position = inst["spawn_pos"]
				inst["body"].visible  = true
			print("CreatureSlice: %s [%s] respawned" % [creature_id, iid])
			GameBus.creature_respawned.emit(iid, creature_id)

# ---------------------------------------------------------------------------
# Visuals
# ---------------------------------------------------------------------------

func _make_visual(creature_id: String, pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = creature_id
	node.position = pos

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.8, 1.0, 1.2)
	mesh.mesh = box
	# Centre the body so its base rests on the terrain surface.
	mesh.position = Vector3(0.0, 0.5, 0.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = _creature_color(creature_id)
	mesh.material_override = mat

	node.add_child(mesh)
	return node

func _creature_color(creature_id: String) -> Color:
	match creature_id:
		"ForestBoar":     return Color(0.55, 0.35, 0.20)
		"GraywolfPack":   return Color(0.42, 0.42, 0.48)
		"SteppeBison":    return Color(0.60, 0.45, 0.25)
		"RidgeHawk":      return Color(0.70, 0.55, 0.30)
		"LavaSlug":       return Color(0.85, 0.25, 0.10)
		"CinderGargoyle": return Color(0.30, 0.15, 0.10)
		"GlimmerFox":     return Color(0.90, 0.80, 0.40)
		"VeilStalker":    return Color(0.25, 0.20, 0.35)
		"VoidSerpent":    return Color(0.10, 0.05, 0.25)
		"RiftWarden":     return Color(0.50, 0.00, 0.50)
		_:                return Color(0.80, 0.80, 0.80)
