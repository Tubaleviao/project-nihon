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

## CHUNK_SIZE and BIOME_KEYS live in TerrainSlice (single source of truth).
## Spawning uses _chunk_biome() which delegates to terrain_slice, so no local
## copy of these constants is needed here.

## Instance record: { "creature_id", "position", "chunk", "state", "hp", "respawn_at", "body" }
var _instances: Dictionary = {}
var _next_id: int = 0

## Set by game_root before the slices enter the tree so creatures can spawn on
## the terrain surface instead of a fixed height.
var terrain_slice: Node = null

## Authority mode (Phase 18). When true (host / single-player), this slice owns
## the creature simulation (spawning, AI, respawn) and broadcasts state deltas.
## When false (client), spawn_for_chunk is a no-op and creature bodies are
## created/updated from host creature_state_changed broadcasts instead.
var is_authoritative: bool = true

## Seconds between host → client creature state broadcasts.
const CREATURE_SYNC_INTERVAL := 0.1
var _sync_accum: float = 0.0

func _ready() -> void:
	GameBus.creature_died.connect(_on_creature_died)
	GameBus.creature_state_changed.connect(_on_creature_state_changed)

func _process(delta: float) -> void:
	_tick_respawn()
	if is_authoritative:
		_sync_accum += delta
		if _sync_accum >= CREATURE_SYNC_INTERVAL:
			_sync_accum = 0.0
			_broadcast_creature_states()

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

## Serialize the live creature population for the world snapshot (host → client).
## Each entry is { instance_id, creature_id, state, position:[x,y,z] }.
func get_snapshot_creatures() -> Array:
	var out: Array = []
	for iid in _instances:
		var inst: Dictionary = _instances[iid]
		var pos: Vector3 = inst["position"]
		out.append({
			"instance_id": iid,
			"creature_id": inst["creature_id"],
			"state":       inst["state"],
			"position":    [pos.x, pos.y, pos.z],
		})
	return out

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

## Spawn the per-chunk creature budget: every creature whose biome matches this
## chunk's biome, at its spawnCount, placed at deterministic positions inside the chunk.
## When terrain_slice is not wired (isolated unit tests), chunk_biome is "" and
## every creature is spawned regardless of biome.
## Accounts for engaged (aggressive/fleeing) survivors from a previous despawn so that
## a chunk reload never exceeds the per-creature spawnCount budget.
func spawn_for_chunk(chunk_pos: Vector2i) -> void:
	if not is_authoritative:
		return   # clients receive creatures from host broadcasts
	var chunk_biome := _chunk_biome(chunk_pos)
	var biome_keys: Array = _biome_keys()
	for creature_id in GameData.CREATURES:
		var res: Resource = GameData.CREATURES[creature_id]
		if res == null:
			continue
		var biome_idx: int = int(res.get("biome"))
		var biome_key: String = biome_keys[biome_idx] if biome_idx < biome_keys.size() else biome_keys[0]
		if chunk_biome != "" and biome_key != chunk_biome:
			continue
		var budget: int = int(res.get("spawnCount"))
		# Count surviving instances (engaged creatures kept alive across a despawn).
		var surviving: int = 0
		for iid in _instances:
			var inst: Dictionary = _instances[iid]
			if inst.get("chunk") == chunk_pos and inst.get("creature_id") == creature_id:
				surviving += 1
		var to_spawn: int = budget - surviving
		for i in range(to_spawn):
			_spawn(creature_id, chunk_pos, surviving + i)

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

func _spawn(creature_id: String, chunk_pos: Vector2i, spawn_index: int = 0) -> String:
	var res: Resource = GameData.CREATURES.get(creature_id, null)
	if res == null:
		push_error("CreatureSlice: unknown creature '%s' in GameData.CREATURES" % creature_id)
		return ""

	var hp: float = float(res.get("baseHp"))
	var xz: Vector2 = _deterministic_chunk_position(chunk_pos, creature_id, spawn_index)
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

## Deterministic world XZ inside the chunk footprint (inset one tile from the edge).
## The position is derived from chunk_pos, creature_id, and spawn_index so the same
## creature always lands at the same spot regardless of frame rate or call order.
func _deterministic_chunk_position(chunk_pos: Vector2i, creature_id: String, spawn_index: int) -> Vector2:
	var cs: int = _chunk_size()
	var inner: int = cs - 2  # tiles available after 1-tile border inset
	var seed_x: int = (chunk_pos.x * 73856093) ^ (chunk_pos.y * 19349663) ^ (creature_id.hash() * 83492791) ^ (spawn_index * 1000003)
	var seed_z: int = (chunk_pos.x * 19349663) ^ (chunk_pos.y * 83492791) ^ (creature_id.hash() * 1000003) ^ (spawn_index * 73856093)
	var local_x: int = (abs(seed_x) % inner) + 1
	var local_z: int = (abs(seed_z) % inner) + 1
	return Vector2(
		float(chunk_pos.x * cs + local_x) + 0.5,
		float(chunk_pos.y * cs + local_z) + 0.5
	)

## The biome key for a chunk, or "" when no terrain_slice is wired (isolated tests).
func _chunk_biome(chunk_pos: Vector2i) -> String:
	if terrain_slice != null and terrain_slice.has_method("get_biome_at_chunk"):
		return str(terrain_slice.get_biome_at_chunk(chunk_pos))
	return ""

## Chunk side length from TerrainSlice; falls back to 32 when unwired (tests).
func _chunk_size() -> int:
	if terrain_slice != null and terrain_slice.has_method("world_to_chunk"):
		return terrain_slice.CHUNK_SIZE
	return 32

## Canonical biome key list from TerrainSlice; falls back to the hard list when unwired.
func _biome_keys() -> Array:
	if terrain_slice != null and "BIOME_KEYS" in terrain_slice:
		return terrain_slice.BIOME_KEYS
	return ["TemperateForest", "TemperateGrassland", "VolcanicBadlands", "TwilightGrove", "VoidRift"]

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

## Host → clients: emit a creature_state_changed delta for every live instance.
## The host's networking slice forwards these to clients.
func _broadcast_creature_states() -> void:
	for iid in _instances:
		var inst: Dictionary = _instances[iid]
		GameBus.creature_state_changed.emit(iid, inst["state"], inst["position"])

## Client-side application of a host-authoritative creature state delta. Creates
## the instance record (and a visual body) on first sight, then updates its
## state and position on subsequent updates.
func _on_creature_state_changed(instance_id: String, state: String, position: Vector3) -> void:
	if is_authoritative:
		return   # the host already owns this instance
	apply_creature_state(instance_id, state, position)

## Client-side application of a single authoritative creature state (see
## _on_creature_state_changed). Public so the snapshot loader can seed the
## world from the host's get_snapshot_creatures() output.
func apply_creature_state(instance_id: String, state: String, position: Vector3) -> void:
	if _instances.has(instance_id):
		var inst: Dictionary = _instances[instance_id]
		inst["state"]    = state
		inst["position"] = position
		var body = inst.get("body", null)
		if body != null and is_instance_valid(body):
			body.position = position
			body.visible = state != "dead"
		return
	# First sight: create a record + visual body without touching GameData counts.
	# instance_id doubles as the node name (non-empty); the colour lookup falls
	# through to the grey default since the client doesn't resolve creature_id.
	var body := _make_visual(instance_id, position)
	add_child(body)
	_instances[instance_id] = {
		"creature_id": "",
		"position":    position,
		"chunk":       Vector2i.ZERO,
		"spawn_pos":   position,
		"state":       state,
		"hp":          0.0,
		"respawn_at":  -1.0,
		"body":        body,
	}

## Seed the client's creature population from a host snapshot list
## (see get_snapshot_creatures).
func apply_snapshot_creatures(list: Array) -> void:
	for entry in list:
		if entry is not Dictionary:
			continue
		var pos := Vector3.ZERO
		var arr = entry.get("position", [])
		if arr is Array and arr.size() >= 3:
			pos = Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
		apply_creature_state(
			str(entry.get("instance_id", "")),
			str(entry.get("state", "idle")),
			pos
		)

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
