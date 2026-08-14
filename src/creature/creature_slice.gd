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

## Seconds before a dead creature's instance respawns (prototype fixed value).
## The fabric's respawn rule is per-creature; using a common prototype value here.
const RESPAWN_SECONDS := 300.0

## Which creature fabric keys to spawn and how many of each.
const SPAWN_MANIFEST: Dictionary = {
	"ForestBoar":  3,
	"GraywolfPack": 2,
}

## Spread around the player's starting position.
const SPAWN_ORIGIN := Vector3(16.0, 8.0, 16.0)
const SPAWN_RADIUS := 10.0

## Instance record: { "creature_id", "position", "state", "hp", "respawn_at" }
var _instances: Dictionary = {}
var _next_id: int = 0

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
	for creature_id in SPAWN_MANIFEST:
		var count: int = SPAWN_MANIFEST[creature_id]
		for i in range(count):
			_spawn(creature_id)

func _spawn(creature_id: String) -> String:
	var res: Resource = GameData.CREATURES.get(creature_id, null)
	if res == null:
		push_error("CreatureSlice: unknown creature '%s' in GameData.CREATURES" % creature_id)
		return ""

	var hp: float = float(res.get("baseHp") if "baseHp" in res else 100)
	var angle := randf_range(0.0, TAU)
	var r     := randf_range(2.0, SPAWN_RADIUS)
	var pos   := SPAWN_ORIGIN + Vector3(cos(angle) * r, 0.0, sin(angle) * r)

	var iid := "creature_%d" % _next_id
	_next_id += 1
	_instances[iid] = {
		"creature_id": creature_id,
		"position":    pos,
		"state":       "idle",
		"hp":          hp,
		"respawn_at":  -1.0,
	}

	GameBus.creature_spawned.emit(iid, creature_id, pos)
	print("CreatureSlice: spawned %s [%s] at %s  hp=%.0f" % [creature_id, iid, pos, hp])
	return iid

func _on_creature_died(entity_id: String, _position: Vector3, _killer_id: String) -> void:
	# entity_id may be either a fabric key or an instance_id.
	# Mark matching instance(s) dead and schedule respawn.
	for iid in _instances:
		var inst: Dictionary = _instances[iid]
		if inst["creature_id"] == entity_id or iid == entity_id:
			if inst["state"] != "dead":
				inst["state"]      = "dead"
				inst["hp"]         = 0.0
				inst["respawn_at"] = Time.get_ticks_msec() + RESPAWN_SECONDS * 1000.0

func _tick_respawn() -> void:
	var now := float(Time.get_ticks_msec())
	for iid in _instances:
		var inst: Dictionary = _instances[iid]
		if inst["state"] == "dead" and inst["respawn_at"] > 0.0 and now >= inst["respawn_at"]:
			var creature_id: String = inst["creature_id"]
			var res: Resource = GameData.CREATURES.get(creature_id, null)
			var max_hp: float = float(res.get("baseHp") if res and "baseHp" in res else 100)
			inst["state"]      = "idle"
			inst["hp"]         = max_hp
			inst["respawn_at"] = -1.0
			print("CreatureSlice: %s [%s] respawned" % [creature_id, iid])
