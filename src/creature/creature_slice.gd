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
##   spawn_for_chunk(chunk_pos: Vector2i)               -> void     (Phase 17)
##   despawn_for_chunk(chunk_pos: Vector2i)             -> void     (Phase 17)

## Terrain chunk side length — must match TerrainSlice.CHUNK_SIZE. Creature
## spawning is chunk-scoped (Phase 17): each loaded chunk gets a budget of
## creatures matching that chunk's biome.
const CHUNK_SIZE := 32

## Maps fabric biome enum integer to the key returned by terrain_slice.get_biome_at_chunk().
## Order: 0=TemperateForest, 1=TemperateGrassland, 2=VolcanicBadlands, 3=TwilightGrove, 4=VoidRift
const BIOME_KEYS: Array = [
	"TemperateForest",
	"TemperateGrassland",
	"VolcanicBadlands",
	"TwilightGrove",
	"VoidRift",
]

## Instance record: { "creature_id", "position", "chunk", "state", "hp", "respawn_at", "body" }
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
			"chunk":       inst.get("chunk", Vector2i.ZERO),
		})
	return out

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

## Spawn the initial population into the origin chunk. When terrain_slice is not
## wired (isolated unit tests), spawn_for_chunk spawns every creature regardless
## of biome, preserving the pre-streaming behaviour those tests rely on.
func _spawn_initial_creatures() -> void:
	spawn_for_chunk(Vector2i(0, 0))

## Spawn the per-chunk creature budget: every creature whose biome matches this
## chunk's biome, at its spawnCount, placed at random positions inside the chunk.
func spawn_for_chunk(chunk_pos: Vector2i) -> void:
	var chunk_biome := _chunk_biome(chunk_pos)
	for creature_id in GameData.CREATURES:
		var res: Resource = GameData.CREATURES[creature_id]
		if res == null:
			continue
		var biome_idx: int = int(res.get("biome"))
		var biome_key: String = BIOME_KEYS[biome_idx] if biome_idx < BIOME_KEYS.size() else BIOME_KEYS[0]
		if chunk_biome != "" and biome_key != chunk_biome:
			continue
		var count: int = int(res.get("spawnCount")) if res != null else 1
		for i in range(count):
			_spawn(creature_id, chunk_pos)

## Despawn creatures belonging to `chunk_pos` that are not engaged in combat.
## Engaged (aggressive / fleeing) creatures are kept so an in-progress fight is
## not torn away; idle/alert/dead instances are removed and their bodies freed.
func despawn_for_chunk(chunk_pos: Vector2i) -> void:
	var to_erase: Array = []
	for iid in _instances:
		var inst: Dictionary = _instances[iid]
		if inst.get("chunk", Vector2i.ZERO) != chunk_pos:
			continue
		if inst["state"] == "aggressive" or inst["state"] == "fleeing":
			continue
		var body = inst.get("body", null)
		if body != null and is_instance_valid(body):
			body.queue_free()
		to_erase.append(iid)
	for iid in to_erase:
		_instances.erase(iid)
	if to_erase.size() > 0:
		print("CreatureSlice: despawned %d creatures from chunk %s" % [to_erase.size(), chunk_pos])

func _spawn(creature_id: String, chunk_pos: Vector2i) -> String:
	var res: Resource = GameData.CREATURES.get(creature_id, null)
	if res == null:
		push_error("CreatureSlice: unknown creature '%s' in GameData.CREATURES" % creature_id)
		return ""

	var hp: float = float(res.get("baseHp"))
	var xz: Vector2 = _random_chunk_position(chunk_pos)
	var pos: Vector3 = Vector3(xz.x, 0.0, xz.y)

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
		"chunk":       chunk_pos,
		"spawn_pos":   pos,
		"state":       "idle",
		"hp":          hp,
		"respawn_at":  -1.0,
		"body":        body,
	}

	GameBus.creature_spawned.emit(iid, creature_id, pos)
	print("CreatureSlice: spawned %s [%s] at %s  hp=%.0f" % [creature_id, iid, pos, hp])
	return iid

## Random world XZ inside the chunk footprint (inset one tile from the edge so
## creatures don't straddle a chunk boundary).
func _random_chunk_position(chunk_pos: Vector2i) -> Vector2:
	var origin_x := chunk_pos.x * CHUNK_SIZE
	var origin_z := chunk_pos.y * CHUNK_SIZE
	return Vector2(
		origin_x + randf_range(1.0, float(CHUNK_SIZE) - 1.0),
		origin_z + randf_range(1.0, float(CHUNK_SIZE) - 1.0)
	)

## The biome key for a chunk, or "" when no terrain_slice is wired (isolated tests).
func _chunk_biome(chunk_pos: Vector2i) -> String:
	if terrain_slice != null and terrain_slice.has_method("get_biome_at_chunk"):
		return str(terrain_slice.get_biome_at_chunk(chunk_pos))
	return ""

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
