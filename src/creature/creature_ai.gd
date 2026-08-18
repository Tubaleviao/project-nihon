extends Node
## Creature AI — per-frame state machine driver for all live creature instances.
##
## Reads instance data from creature_slice and moves bodies toward their
## patrol/chase targets using kinematic stepping (direct vector math; no
## NavigationAgent3D scene-tree dependency required for this prototype).
##
## Per-creature alert/attack radii and flee threshold are read from
## GameData.CREATURES so the fabric is the single source of truth.
##
## State machine per creature:
##   idle        — patrol waypoints around spawn position
##   alert       — face player; aggro if player enters attackRadius
##   aggressive  — chase + attack cycle every ATTACK_INTERVAL seconds
##   fleeing     — run away from player until safe distance or dead
##   dead        — static; CreatureSlice handles respawn
##   respawning  — CreatureSlice brings instance back to idle
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : creature_died(entity_id, position, killer_id)
##         creature_respawned(instance_id, creature_id)
##         player_damaged(damage, attacker_id)   — ignored (bus parity)
##   OUT : creature_alert(instance_id)
##         creature_aggressive(instance_id)
##         creature_fleeing(instance_id)
##         combat_round_requested(attacker_id, defender_id)
##
## Public API:
##   get_state(instance_id) -> String
##   force_state(instance_id, state)   -- test helper

## Seconds between creature melee strikes while aggressive.
const ATTACK_INTERVAL  := 1.5
## Patrol waypoint spread around the spawn origin.
const PATROL_RADIUS    := 6.0
## Patrol waypoint reached tolerance.
const PATROL_TOLERANCE := 1.2
## Movement speeds (m/s).
const SPEED_IDLE       := 1.2
const SPEED_ALERT      := 0.0   # alert = stationary, watching
const SPEED_AGGRESSIVE := 3.5
const SPEED_FLEE       := 4.5

## Per-instance AI state: { "state", "attack_timer", "patrol_target", "spawn_pos" }
var _ai: Dictionary = {}

## References wired by game_root before _ready.
var creature_slice: Node = null
var player_slice:   Node = null
var battle_slice:   Node = null

func _ready() -> void:
	GameBus.creature_died.connect(_on_creature_died)
	GameBus.creature_respawned.connect(_on_creature_respawned)
	GameBus.creature_spawned.connect(_on_creature_spawned)

func _process(delta: float) -> void:
	if creature_slice == null or player_slice == null:
		return
	var player_pos: Vector3 = player_slice.get_position()
	var instances: Array = creature_slice.get_all_instances()
	for inst in instances:
		var iid: String = inst["instance_id"]
		var c_state: String = inst["state"]
		if c_state == "dead" or c_state == "respawning":
			continue
		_ensure_ai_record(iid, inst["position"])
		_tick_instance(iid, inst, player_pos, delta)

# ---------------------------------------------------------------------------
# Per-instance tick
# ---------------------------------------------------------------------------

func _tick_instance(iid: String, inst: Dictionary, player_pos: Vector3, delta: float) -> void:
	var ai: Dictionary     = _ai[iid]
	var pos: Vector3       = inst["position"]
	var ai_state: String   = ai["state"]
	var dist: float        = pos.distance_to(player_pos)
	# Read combat HP from battle_slice so the flee threshold reflects actual damage
	# taken; inst["hp"] is only written at spawn/death and stays at max during combat.
	var _combat_hp: float = battle_slice.get_hp(iid) if battle_slice != null else -1.0
	var hp: float = _combat_hp if _combat_hp >= 0.0 else inst["hp"]
	var res: Resource      = GameData.CREATURES.get(inst["creature_id"], null)
	var max_hp: float      = float(res.get("baseHp")) if res else 100.0
	# Per-creature AI parameters from the fabric (GameData.CREATURES).
	var alert_r: float     = float(res.get("alertRadius")) if res else 12.0
	var attack_r: float    = float(res.get("attackRadius")) if res else 3.0
	var flee_thr: float    = float(res.get("fleeThreshold")) if res else 0.20
	var safe_r: float      = alert_r * 1.5

	match ai_state:
		"idle":
			if dist <= alert_r:
				_transition(iid, "alert")
				return
			_patrol(iid, inst, delta)

		"alert":
			if dist <= attack_r:
				_transition(iid, "aggressive")
				return
			if dist > alert_r:
				_transition(iid, "idle")
				return

		"aggressive":
			if flee_thr > 0.0 and hp / max_hp < flee_thr:
				_transition(iid, "fleeing")
				return
			if dist > safe_r:
				_transition(iid, "idle")
				return
			_chase(iid, inst, player_pos, delta)
			ai["attack_timer"] += delta
			if ai["attack_timer"] >= ATTACK_INTERVAL:
				if dist <= attack_r:
					ai["attack_timer"] = 0.0
					GameBus.combat_round_requested.emit(iid, "player")

		"fleeing":
			if hp <= 0.0:
				_transition(iid, "dead")
				return
			if dist > safe_r:
				_transition(iid, "idle")
				return
			_flee(iid, inst, player_pos, delta)

# ---------------------------------------------------------------------------
# Movement helpers
# ---------------------------------------------------------------------------

func _patrol(iid: String, inst: Dictionary, delta: float) -> void:
	var ai: Dictionary = _ai[iid]
	var pos: Vector3   = inst["position"]
	var target: Vector3 = ai["patrol_target"]

	if pos.distance_to(target) < PATROL_TOLERANCE:
		ai["patrol_target"] = _random_waypoint(ai["spawn_pos"])

	_move_instance(iid, inst, target, SPEED_IDLE, delta)

func _chase(iid: String, inst: Dictionary, player_pos: Vector3, delta: float) -> void:
	_move_instance(iid, inst, player_pos, SPEED_AGGRESSIVE, delta)

func _flee(iid: String, inst: Dictionary, player_pos: Vector3, delta: float) -> void:
	var away: Vector3 = (inst["position"] - player_pos).normalized()
	var target: Vector3 = inst["position"] + away
	_move_instance(iid, inst, target, SPEED_FLEE, delta)

func _move_instance(iid: String, inst: Dictionary, target: Vector3, speed: float, delta: float) -> void:
	var pos: Vector3 = inst["position"]
	var dir: Vector3 = (target - pos)
	if dir.length_squared() < 0.001:
		return
	dir = dir.normalized()
	var new_pos: Vector3 = pos + dir * speed * delta
	creature_slice.set_instance_position(iid, new_pos)

# ---------------------------------------------------------------------------
# State transition
# ---------------------------------------------------------------------------

func _transition(iid: String, new_state: String) -> void:
	var old_state: String = _ai[iid]["state"]
	if old_state == new_state:
		return
	_ai[iid]["state"] = new_state
	_ai[iid]["attack_timer"] = 0.0
	match new_state:
		"alert":
			GameBus.creature_alert.emit(iid)
		"aggressive":
			GameBus.creature_aggressive.emit(iid)
		"fleeing":
			GameBus.creature_fleeing.emit(iid)
		"idle":
			# Reset patrol waypoint toward spawn when calming down.
			_ai[iid]["patrol_target"] = _random_waypoint(_ai[iid]["spawn_pos"])

# ---------------------------------------------------------------------------
# Public API (test helper)
# ---------------------------------------------------------------------------

func get_state(instance_id: String) -> String:
	if not _ai.has(instance_id):
		return ""
	return _ai[instance_id]["state"]

func force_state(instance_id: String, state: String) -> void:
	_ensure_ai_record(instance_id, Vector3.ZERO)
	_ai[instance_id]["state"] = state

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _ensure_ai_record(iid: String, spawn_pos: Vector3) -> void:
	if not _ai.has(iid):
		_ai[iid] = {
			"state":         "idle",
			"attack_timer":  0.0,
			"spawn_pos":     spawn_pos,
			"patrol_target": _random_waypoint(spawn_pos),
		}

func _random_waypoint(origin: Vector3) -> Vector3:
	var angle := randf_range(0.0, TAU)
	var r     := randf_range(PATROL_RADIUS * 0.4, PATROL_RADIUS)
	return origin + Vector3(cos(angle) * r, 0.0, sin(angle) * r)

func _on_creature_spawned(instance_id: String, _creature_id: String, position: Vector3) -> void:
	_ensure_ai_record(instance_id, position)

func _on_creature_died(entity_id: String, _position: Vector3, _killer_id: String) -> void:
	if _ai.has(entity_id):
		_ai[entity_id]["state"] = "dead"

func _on_creature_respawned(instance_id: String, _creature_id: String) -> void:
	if _ai.has(instance_id):
		_transition(instance_id, "idle")
