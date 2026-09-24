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
##   get_snapshot_creatures()                           -> Array    (Phase 33: + hp, respawn_at)
##   apply_snapshot_creatures(list)                     -> void     (Phase 33)
##   apply_recorded_creature_states(list)               -> void     (Phase 33, host: no new ids)
##   spawn_for_chunk(chunk_pos: Vector2i)               -> void     (Phase 17)
##   despawn_for_chunk(chunk_pos: Vector2i)             -> void     (Phase 17)
##   get_instance_position(instance_id)                 -> Vector3  (Phase 35)
##   mark_tamed(instance_id, player_id)                 -> bool     (Phase 35)
##   is_tamed(instance_id) / get_tamed_by(instance_id)  -> bool / String
##   companions_of(player_id)                           -> Array    (Phase 35)
##   has_defeated_species(creature_id)                  -> bool     (Phase 35, alpha-down gate)
##
## Respawn deadlines are WALL-CLOCK (Phase 33): `respawn_at` is a Unix-epoch
## second from Time.get_unix_time_from_system(), the same convention the market
## listings and tree regrowth use, so a deadline persisted in the world record
## still means what it says after a restart. (It used to be process uptime via
## Time.get_ticks_msec(), which is meaningless in a new process.)

## CHUNK_SIZE and BIOME_KEYS live in TerrainSlice (single source of truth).
## Spawning uses _chunk_biome() which delegates to terrain_slice, so no local
## copy of these constants is needed here.

## Instance record: { "creature_id", "position", "chunk", "state", "hp", "respawn_at", "mi" }.
## `mi` is an opaque MultiMesh instance index, never a live Node3D — a headless
## server keeps the same records with no rendering attached.
const MultimeshPool := preload("res://src/core/multimesh_pool.gd")
const SpatialHash    := preload("res://src/core/spatial_hash.gd")

var _instances: Dictionary = {}

## Death records for creatures that are NOT currently resident: instance_id →
## { creature_id, respawn_at, position }. A despawn erases the instance (and frees
## its body slot) but the death is the creature's STATE, not scenery: without this,
## walking out of a chunk and back respawned the creature alive, ignoring the
## recorded death entirely. Entries are consumed when the chunk streams again
## (`_spawn` re-applies the death) or dropped once the deadline has passed (it would
## respawn alive anyway). `get_snapshot_creatures()` carries them, so the world
## record holds a death for a chunk that is not in view.
var _dead_state: Dictionary = {}

## Spatial hash over the live population so nearest-creature / neighbour queries
## are O(radius²) cells, not an O(N) scan (Phase 28). Kept in lockstep with
## _instances: insert on spawn, update on move, remove on despawn.
var _spatial := SpatialHash.new()

## Shared MultiMesh pool for creature bodies; null when render_visuals is false
## (headless server) so the simulation runs with no visual nodes.
var _pool: Node = null
## When false (headless server), no pool is built and transform/colour writes
## are no-ops — the same data model drives a bare simulation.
var render_visuals: bool = true

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

## Last broadcast { state, position } per instance, so the sync tick ships only
## changed instances (dirty tracking) instead of the whole population every tick.
var _last_broadcast: Dictionary = {}

func _ready() -> void:
	GameBus.creature_died.connect(_on_creature_died)
	GameBus.creature_state_changed.connect(_on_creature_state_changed)
	if render_visuals:
		_build_pool()

func _process(delta: float) -> void:
	_tick_respawn()
	if is_authoritative:
		_sync_accum += delta
		if _sync_accum >= CREATURE_SYNC_INTERVAL:
			_sync_accum = 0.0
			_broadcast_creature_states()

## Return the instance_id of the nearest live creature within radius, or "".
## Routed through the spatial hash (Phase 28) so the scan is bounded by the
## query footprint, not the total population. TAMED instances are skipped
## (Phase 35): a companion is not a target, so an attack input aimed at the
## nearest creature must not swing at the player's own wolf.
func nearest_creature(from_pos: Vector3, radius: float) -> String:
	var best_id := ""
	var best_dist := radius + 1.0
	for iid in _spatial.query_radius(from_pos, radius):
		var inst: Dictionary = _instances[iid]
		if inst["state"] == "dead":
			continue
		if str(inst.get("tamed_by", "")) != "":
			continue
		var d: float = inst["position"].distance_to(from_pos)
		if d < best_dist:
			best_dist = d
			best_id = iid
	return best_id

## Instance ids within `radius` of `pos` (any state). The AI's neighbour /
## proximity queries route through the hash via this (Phase 28).
func creatures_in_radius(pos: Vector3, radius: float) -> Array:
	return _spatial.query_radius(pos, radius)

# ---------------------------------------------------------------------------
# Taming (Phase 35)
# ---------------------------------------------------------------------------

## Bind an instance to its owner. Returns false when the instance is unknown or
## already tamed by somebody else (a companion is not re-tameable — the taming
## slice's cooldown covers the yield case, this covers the companion case).
func mark_tamed(instance_id: String, player_id: String) -> bool:
	if not _instances.has(instance_id) or player_id == "":
		return false
	var cur: String = str(_instances[instance_id].get("tamed_by", ""))
	if cur != "" and cur != player_id:
		return false
	_instances[instance_id]["tamed_by"] = player_id
	return true

func is_tamed(instance_id: String) -> bool:
	return get_tamed_by(instance_id) != ""

## The owner of a tamed instance, or "" when it is wild (or unknown).
func get_tamed_by(instance_id: String) -> String:
	if not _instances.has(instance_id):
		return ""
	return str(_instances[instance_id].get("tamed_by", ""))

## Every instance currently tamed by `player_id`, ordered by instance id so the
## list is stable (it is persisted on the player record).
func companions_of(player_id: String) -> Array:
	var out: Array = []
	if player_id == "":
		return out
	for iid in _instances:
		if str(_instances[iid].get("tamed_by", "")) == player_id:
			out.append(str(iid))
	out.sort()
	return out

## True when an instance of `creature_id` is dead (or held dead) anywhere the
## slice knows about — live population, or a death retained for a chunk that is
## not streamed right now. This is the pack's alpha-down gate for taming: the
## fabric rule is "tame a surviving pup AFTER defeating the alpha wolf", and the
## runtime models a pack as N instances of one creature id, so "the alpha is
## down" is "one of them is dead".
func has_defeated_species(creature_id: String) -> bool:
	if creature_id == "":
		return false
	for iid in _instances:
		var inst: Dictionary = _instances[iid]
		if str(inst.get("creature_id", "")) == creature_id and inst["state"] == "dead":
			return true
	for iid in _dead_state:
		if str(_dead_state[iid].get("creature_id", "")) == creature_id:
			return true
	return false

## Whether a tamed instance of this creature is exempt from respawning — the
## fabric's `tame.suppressRespawn` ("pup does not respawn if tamed"). Read from
## GameData, never hardcoded, so the fabric stays the single source of truth.
func _suppresses_respawn(inst: Dictionary) -> bool:
	if str(inst.get("tamed_by", "")) == "":
		return false
	var res: Resource = GameData.CREATURES.get(str(inst.get("creature_id", "")), null)
	if res == null:
		return false
	var tame = res.get("tame")
	if tame is String and tame != "":
		tame = JSON.parse_string(tame)
	if not (tame is Dictionary):
		return false
	return bool(tame.get("suppressRespawn", false))

## Return the fabric creature key for an instance (e.g. "ForestBoar").
func get_instance_creature_id(instance_id: String) -> String:
	if not _instances.has(instance_id):
		return ""
	return str(_instances[instance_id]["creature_id"])

## The instance's current world position, or Vector3.ZERO when it is unknown.
## Public so per-player interactions (taming, Phase 35) can range-check a target.
func get_instance_position(instance_id: String) -> Vector3:
	if not _instances.has(instance_id):
		return Vector3.ZERO
	return _instances[instance_id]["position"]

## Move an instance to a new world position, keeping body and record in sync.
func set_instance_position(instance_id: String, pos: Vector3) -> void:
	if not _instances.has(instance_id):
		return
	_instances[instance_id]["position"] = pos
	_spatial.update(instance_id, pos)
	if _pool != null and _instances[instance_id].has("mi"):
		_pool.set_transform(int(_instances[instance_id]["mi"]), _visual_transform(pos))

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
			"tamed_by":    str(inst.get("tamed_by", "")),
		})
	return out

## Serialize the live creature population for the world snapshot (host → client)
## and for the world record (Phase 33). Each entry is
## { instance_id, creature_id, state, position:[x,y,z], hp, respawn_at }.
## `hp` and `respawn_at` are what make a death/respawn round-trip exact: a dead
## instance comes back dead, with the same wall-clock respawn deadline.
##
## Non-resident deaths (`_dead_state` — creatures whose chunk was despawned while
## they were dead) are carried TOO, at the position they will respawn at: the world
## record is the only thing that outlives the process, so a death in a chunk that is
## not in the view window has to be in it or it is lost on the next boot.
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
			"hp":          float(inst.get("hp", 0.0)),
			"respawn_at":  float(inst.get("respawn_at", -1.0)),
		})
	for iid in _dead_state:
		if _instances.has(iid):
			continue
		var dead: Dictionary = _dead_state[iid]
		var dead_pos: Variant = dead.get("position", [0.0, 0.0, 0.0])
		out.append({
			"instance_id": iid,
			"creature_id": str(dead.get("creature_id", "")),
			"state":       "dead",
			"position":    dead_pos,
			"hp":          0.0,
			"respawn_at":  float(dead.get("respawn_at", -1.0)),
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
## not torn away; idle/alert instances are removed and their bodies freed.
##
## A DEAD instance is erased too (its body slot is freed with it), but its death is
## retained in `_dead_state` first: the death and its wall-clock respawn deadline are
## the creature's persisted state, so dropping them meant walking out of a chunk and
## back respawned the creature ALIVE — the record was silently ignored.
func despawn_for_chunk(chunk_pos: Vector2i) -> void:
	var to_erase: Array = []
	for iid in _instances:
		var inst: Dictionary = _instances[iid]
		if inst.get("chunk", Vector2i.ZERO) != chunk_pos:
			continue
		if inst["state"] == "aggressive" or inst["state"] == "fleeing":
			continue
		if inst["state"] == "dead":
			_remember_death(iid, inst)
		if _pool != null and inst.has("mi") and int(inst["mi"]) >= 0:
			_pool.release(int(inst["mi"]))
		to_erase.append(iid)
	for iid in to_erase:
		_instances.erase(iid)
		_last_broadcast.erase(iid)
		_spatial.remove(iid)

## Keep a non-resident death record for `iid` from its live instance record. Only a
## still-pending death is worth keeping: a deadline that has already passed means the
## creature would come back alive, so remembering it would freeze a corpse forever.
func _remember_death(iid: String, inst: Dictionary) -> void:
	var deadline := float(inst.get("respawn_at", -1.0))
	if deadline <= Time.get_unix_time_from_system():
		_dead_state.erase(iid)
		return
	var pos: Vector3 = inst.get("position", Vector3.ZERO)
	_dead_state[iid] = {
		"creature_id": str(inst.get("creature_id", "")),
		"respawn_at":  deadline,
		"position":    [pos.x, pos.y, pos.z],
	}

func _spawn(creature_id: String, chunk_pos: Vector2i, spawn_index: int = 0) -> String:
	var res: Resource = GameData.CREATURES.get(creature_id, null)
	if res == null:
		push_error("CreatureSlice: unknown creature '%s' in GameData.CREATURES" % creature_id)
		return ""

	var hp: float = float(res.get("baseHp"))
	var xz: Vector2 = _deterministic_chunk_position(chunk_pos, creature_id, spawn_index)
	# Pack/herd members cluster around a single deterministic centre so their
	# group coordination (pack alert / herd flee) fires in practice instead of
	# being scattered out of packRadius. Solitary creatures keep the scattered
	# per-index spawn positions.
	if _is_group_creature(creature_id):
		var center: Vector2 = _deterministic_chunk_position(chunk_pos, creature_id, 0)
		xz = center + _pack_member_offset(spawn_index)
	var pos: Vector3 = Vector3(xz.x, 0.0, xz.y)

	# Sit the creature on the terrain surface instead of a fixed height.
	if terrain_slice != null and terrain_slice.has_method("get_height_at"):
		pos.y = terrain_slice.get_height_at(Vector2(pos.x, pos.z))

	var iid := _instance_id(chunk_pos, creature_id, spawn_index)

	# Build a visible body so the creature can be seen in the world. Headless
	# (no pool) allocates no visual — the record carries the instance index only.
	var mi := _alloc_visual(creature_id, pos)

	_instances[iid] = {
		"creature_id": creature_id,
		"position":    pos,
		"chunk":       chunk_pos,
		"spawn_pos":   pos,
		"state":       "idle",
		"hp":          hp,
		"respawn_at":  -1.0,
		"mi":          mi,
		"tamed_by":    "",
	}

	# A creature that died before its chunk was despawned (or before this process
	# ever streamed that chunk) comes back DEAD, with the same wall-clock deadline,
	# instead of respawning alive and ignoring the record. The record is consumed
	# here either way: a deadline already in the past means the respawn just happened.
	var pending: Variant = _dead_state.get(iid, null)
	if pending != null:
		_dead_state.erase(iid)
		if float(pending["respawn_at"]) > Time.get_unix_time_from_system():
			_instances[iid]["state"]      = "dead"
			_instances[iid]["hp"]         = 0.0
			_instances[iid]["respawn_at"] = float(pending["respawn_at"])
			if _pool != null and mi >= 0:
				_pool.hide(mi)

	_spatial.insert(iid, pos)

	GameBus.creature_spawned.emit(iid, creature_id, pos)
	return iid

## Deterministic instance id: derived from the chunk it belongs to, the creature
## it is, and its spawn index — the same inputs _deterministic_chunk_position()
## uses. A counter id was NOT stable: two peers that streamed chunks in a
## different order named the same creature differently, and every chunk
## unload/reload (which respawns the budget from scratch) renamed survivors.
## Since phase 33 persists and replicates creature state by instance id, the id
## has to be a property of the creature, not of the order it happened to spawn in.
##
## Caveat: spawn_for_chunk() keeps engaged (aggressive/fleeing) survivors across
## a despawn and indexes new spawns after them, so a chunk reloaded while one of
## its creatures is mid-fight can hand a fresh spawn the next index. The
## persisted state is still re-attachable for every unengaged creature, which is
## what the world record needs.
func _instance_id(chunk_pos: Vector2i, creature_id: String, spawn_index: int) -> String:
	return "creature_%d_%d_%s_%d" % [chunk_pos.x, chunk_pos.y, creature_id, spawn_index]

## Deterministic world XZ inside the chunk footprint (inset one tile from the edge).
## The position is derived from chunk_pos, creature_id, and spawn_index so the same
## creature always lands at the same spot regardless of frame rate or call order.
## Tile-aware: converts the global tile index to world units via TILE_SIZE (0.5).
func _deterministic_chunk_position(chunk_pos: Vector2i, creature_id: String, spawn_index: int) -> Vector2:
	var cs: int = _chunk_size()
	var ts: float = _tile_size()
	var inner: int = cs - 2  # tiles available after 1-tile border inset
	var seed_x: int = (chunk_pos.x * 73856093) ^ (chunk_pos.y * 19349663) ^ (creature_id.hash() * 83492791) ^ (spawn_index * 1000003)
	var seed_z: int = (chunk_pos.x * 19349663) ^ (chunk_pos.y * 83492791) ^ (creature_id.hash() * 1000003) ^ (spawn_index * 73856093)
	var local_x: int = (abs(seed_x) % inner) + 1
	var local_z: int = (abs(seed_z) % inner) + 1
	return Vector2(
		float(chunk_pos.x * cs + local_x) * ts + ts * 0.5,
		float(chunk_pos.y * cs + local_z) * ts + ts * 0.5
	)

## True when the creature is a pack/herd member (groupBehavior != none). Solitary
## creatures (and any resource without the field) return false and keep their
## per-index scattered spawn positions.
func _is_group_creature(creature_id: String) -> bool:
	var res: Resource = GameData.CREATURES.get(creature_id, null)
	if res == null:
		return false
	var gb: Variant = res.get("groupBehavior")
	return gb != null and int(gb) != 0

## Small deterministic offsets for pack/herd members around the pack centre. Kept
## well inside a typical packRadius (20 m) so every member stays in coordination
## range of every other member.
const PACK_MEMBER_OFFSETS: Array[Vector2] = [
	Vector2(0.0, 0.0),
	Vector2(2.5, 0.0),
	Vector2(-2.5, 0.0),
	Vector2(0.0, 2.5),
	Vector2(0.0, -2.5),
	Vector2(2.5, 2.5),
	Vector2(-2.5, -2.5),
	Vector2(-2.5, 2.5),
	Vector2(2.5, -2.5),
]

## The cluster offset for the Nth member of a pack/herd. Index wraps so a larger
## spawnCount than the offset table stays deterministic.
func _pack_member_offset(spawn_index: int) -> Vector2:
	var idx: int = spawn_index % PACK_MEMBER_OFFSETS.size()
	return PACK_MEMBER_OFFSETS[idx]

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

## Tile world size from TerrainSlice; falls back to 1.0 when unwired (tests).
func _tile_size() -> float:
	if terrain_slice != null and "TILE_SIZE" in terrain_slice:
		return float(terrain_slice.TILE_SIZE)
	return 1.0

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
				# WALL-CLOCK deadline (Phase 33) — a saved deadline must still mean
				# the same moment in a new process, so this is Unix-epoch seconds,
				# not process uptime.
				inst["respawn_at"] = Time.get_unix_time_from_system() + respawn_secs
				if _pool != null and inst.has("mi") and int(inst["mi"]) >= 0:
					_pool.hide(int(inst["mi"]))

func _tick_respawn() -> void:
	var now := Time.get_unix_time_from_system()
	for iid in _instances:
		var inst: Dictionary = _instances[iid]
		if inst["state"] == "dead" and float(inst["respawn_at"]) > 0.0 and now >= float(inst["respawn_at"]):
			# A TAMED companion whose fabric tame spec says it does not respawn
			# stays dead: the fabric rule is "pup does not respawn if tamed", and
			# bringing the wolf back would hand its owner a second body for the
			# same companion id (the tamed_by binding outlives the death).
			if _suppresses_respawn(inst):
				_dead_state.erase(iid)
				inst["respawn_at"] = -1.0
				continue
			_dead_state.erase(iid)
			var creature_id: String = inst["creature_id"]
			var res: Resource = GameData.CREATURES.get(creature_id, null)
			var max_hp: float = float(res.get("baseHp"))
			inst["state"]      = "idle"
			inst["hp"]         = max_hp
			inst["respawn_at"] = -1.0
			inst["position"]   = inst["spawn_pos"]
			_spatial.update(iid, inst["spawn_pos"])
			if _pool != null and inst.has("mi") and int(inst["mi"]) >= 0:
				_pool.set_transform(int(inst["mi"]), _visual_transform(inst["spawn_pos"]))
			GameBus.creature_respawned.emit(iid, creature_id)
	# Sweep non-resident death records whose deadline has passed: they no longer
	# describe anything (the creature is due alive), and keeping them would grow the
	# map without bound for chunks that are never streamed again.
	for iid in _dead_state.keys():
		if float(_dead_state[iid]["respawn_at"]) <= now:
			_dead_state.erase(iid)

## Host → clients: emit a creature_state_changed delta for instances whose
## state or position changed since the last broadcast. Unchanged instances are
## skipped so the sync tick ships only genuine deltas, not the whole population.
func _broadcast_creature_states() -> void:
	for iid in _instances:
		var inst: Dictionary = _instances[iid]
		var state: String = inst["state"]
		var pos: Vector3 = inst["position"]
		var prev = _last_broadcast.get(iid, null)
		if prev != null and prev["state"] == state and prev["position"] == pos:
			continue
		_last_broadcast[iid] = { "state": state, "position": pos }
		GameBus.creature_state_changed.emit(iid, inst["creature_id"], state, pos)

## Client-side application of a host-authoritative creature state delta. Creates
## the instance record (and a visual body) on first sight, then updates its
## state and position on subsequent updates.
func _on_creature_state_changed(instance_id: String, creature_id: String, state: String, position: Vector3) -> void:
	if is_authoritative:
		return   # the host already owns this instance
	apply_creature_state(instance_id, creature_id, state, position)

## Client-side application of a single authoritative creature state (see
## _on_creature_state_changed). Public so the snapshot loader can seed the
## world from the host's get_snapshot_creatures() output — including the `hp`
## and wall-clock `respawn_at` a dead instance carries (Phase 33).
##
## Both optional fields are SENTINELS, not defaults: `hp < 0` and `respawn_at < 0`
## each mean "unchanged", exactly as `hp` already did. A respawn deadline has no
## legitimate value at or below zero (it is Unix-epoch seconds), so a 4-argument
## caller — the per-tick state delta, which carries neither field — must leave the
## existing deadline alone. Assigning the -1.0 default unconditionally wiped a dead
## instance's respawn_at on every delta, so the creature never came back.
func apply_creature_state(instance_id: String, creature_id: String, state: String, position: Vector3, hp: float = -1.0, respawn_at: float = -1.0) -> void:
	if _instances.has(instance_id):
		var inst: Dictionary = _instances[instance_id]
		if creature_id != "":
			inst["creature_id"] = creature_id
		inst["state"]    = state
		inst["position"] = position
		if hp >= 0.0:
			inst["hp"] = hp
		if respawn_at >= 0.0:
			inst["respawn_at"] = respawn_at
		_spatial.update(instance_id, position)
		if _pool != null and inst.has("mi") and int(inst["mi"]) >= 0:
			if state == "dead":
				_pool.hide(int(inst["mi"]))
			else:
				_pool.set_transform(int(inst["mi"]), _visual_transform(position))
		return
	# First sight: create a record + visual body without touching GameData counts.
	# The creature_id is preserved from the host so the body gets the correct
	# colour; fall back to instance_id (still a non-empty node name) when absent.
	var visual_id: String = creature_id if creature_id != "" else instance_id
	var mi := _alloc_visual(visual_id, position)
	if state == "dead" and _pool != null and mi >= 0:
		_pool.hide(mi)
	_instances[instance_id] = {
		"creature_id": creature_id,
		"position":    position,
		"chunk":       Vector2i.ZERO,
		"spawn_pos":   position,
		"state":       state,
		"hp":          maxf(hp, 0.0),
		"respawn_at":  respawn_at,
		"mi":          mi,
		"tamed_by":    "",
	}
	_spatial.insert(instance_id, position)

## Seed the client's creature population from a host snapshot list
## (see get_snapshot_creatures), carrying hp and the wall-clock respawn deadline.
## CLIENT path: an unknown instance id is created on first sight.
func apply_snapshot_creatures(list: Array) -> void:
	_apply_creature_entries(list, true)

## Host path — re-apply the creature half of a saved world record over the
## population chunk streaming just spawned. Unlike the client path this NEVER
## creates an instance: an instance id absent from `_instances` belongs to a chunk
## that is not in the current view window, and creating it here would fabricate a
## record with no chunk (Vector2i.ZERO) whose visual body nothing ever releases —
## and whose id, being deterministic, would then be silently overwritten by the
## real spawn when that chunk streams, losing the restored state anyway. Skipping
## is also the safe answer to the spawn-index caveat in `_instance_id()`.
##
## A recorded DEATH for such an id is not skipped, though: it is held in
## `_dead_state` so the death survives until the chunk streams (see `_spawn`).
## Otherwise a death in a chunk outside the boot view window was lost outright and
## walking back respawned the creature alive.
func apply_recorded_creature_states(list: Array) -> void:
	_apply_creature_entries(list, false)

func _apply_creature_entries(list: Array, create_missing: bool) -> void:
	for entry in list:
		if entry is not Dictionary:
			continue
		var iid := str(entry.get("instance_id", ""))
		if not create_missing and not _instances.has(iid):
			_hold_death_record(iid, entry)
			continue
		var pos := Vector3.ZERO
		var arr = entry.get("position", [])
		if arr is Array and arr.size() >= 3:
			pos = Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
		apply_creature_state(
			iid,
			str(entry.get("creature_id", "")),
			str(entry.get("state", "idle")),
			pos,
			float(entry.get("hp", -1.0)),
			float(entry.get("respawn_at", -1.0))
		)

## Hold an unstreamed id's recorded death so it re-applies when its chunk streams
## (see _spawn). Only a pending death is held; a live entry, an entry whose deadline
## has passed, or a malformed one is ignored.
func _hold_death_record(iid: String, entry: Dictionary) -> void:
	if iid.is_empty() or str(entry.get("state", "")) != "dead":
		return
	var deadline := float(entry.get("respawn_at", -1.0))
	if deadline <= Time.get_unix_time_from_system():
		return
	var pos := Vector3.ZERO
	var arr = entry.get("position", [])
	if arr is Array and arr.size() >= 3:
		pos = Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
	_dead_state[iid] = {
		"creature_id": str(entry.get("creature_id", "")),
		"respawn_at":  deadline,
		"position":    [pos.x, pos.y, pos.z],
	}

# ---------------------------------------------------------------------------
# Visuals
# ---------------------------------------------------------------------------

## Build the shared MultiMesh pool for all creature bodies (one draw call).
## The box mesh is shared; the per-creature tint lives in the per-instance
## colour, and the 0.5 half-height offset is baked into each instance transform.
func _build_pool() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.8, 1.0, 1.2)
	_pool = MultimeshPool.new()
	_pool.name = "CreaturePool"
	_pool.setup(box, true)
	add_child(_pool)

## Allocate a visual instance for a creature, tinted by type. Returns the
## MultiMesh instance index, or -1 when headless (no pool).
func _alloc_visual(creature_id: String, pos: Vector3) -> int:
	if _pool == null:
		return -1
	var idx: int = _pool.alloc()
	_pool.set_color(idx, _creature_color(creature_id))
	_pool.set_transform(idx, _visual_transform(pos))
	return idx

## World surface position → instance transform, raised half a box so the base
## rests on the terrain.
func _visual_transform(pos: Vector3) -> Transform3D:
	return Transform3D(Basis(), pos + Vector3(0.0, 0.5, 0.0))

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
