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
##   tamed       — a companion (Phase 35): never aggros, follows its owner
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : creature_died(entity_id, position, killer_id)
##         creature_respawned(instance_id, creature_id)
##         player_damaged(damage, attacker_id, target_id) — ignored (bus parity)
##   OUT : creature_alert(instance_id)
##         creature_aggressive(instance_id)
##         creature_fleeing(instance_id)
##         combat_round_requested(attacker_id, defender_id)
##
## Public API:
##   get_state(instance_id) -> String
##   force_state(instance_id, state)   -- test helper
##   on_companion_tamed(instance_id, player_id)  -- Phase 35: enter the tamed state

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
## Companion (Phase 35): a tamed creature keeps pace with its owner and stops
## short of them instead of climbing inside the player's body.
const SPEED_COMPANION  := 4.0
const COMPANION_FOLLOW_STOP := 2.0
## AI state name for a tamed companion.
const STATE_TAMED := "tamed"

## Group coordination (pack/herd) — fabric `groupBehavior` enum values (Phase 30).
##   0 NONE — solitary; no cross-creature coordination
##   1 PACK — members share alert/aggressive (predators coordinate an attack)
##   2 HERD — members share flee (prey stampede together)
const GROUP_NONE := 0
const GROUP_PACK := 1
const GROUP_HERD := 2

## Per-instance AI state: { "state", "attack_timer", "patrol_target", "spawn_pos" }
var _ai: Dictionary = {}

## aggressionLevel from fabric drives the idle→next-state branch:
##   0 PASSIVE    — flee immediately when player enters alertRadius
##   1 NEUTRAL    — stop and watch (alert state), then chase if player closes further
##   2 AGGRESSIVE — chase immediately, no alert pause
##   3 TERRITORIAL — like AGGRESSIVE but alertRadius × 1.5

## References wired by game_root before _ready.
var creature_slice: Node = null
var player_slice:   Node = null
var battle_slice:   Node = null

## Set by game_root (Phase 35): resolves where a companion's owner is, so a tamed
## creature follows instead of patrolling. Left null in isolated tests — a
## companion then simply holds position.
var taming_slice:   Node = null

## Phase 36 — every player the host can place on THIS machine, as
## { target_id: Vector3 }: the local player's body under the id "player" (the
## defender id `combat_round_requested` has always used for it) plus each remote
## peer's last recorded position under its player id. Wired by game_root, which is
## the only place that knows both the networking slice's last-known states and the
## registry's peer → player mapping; unwired (an isolated test, or a client, where
## the local body is all there is) the local player alone is the target set.
var player_targets: Callable = Callable()

## Authority mode (Phase 18): creature AI runs on the host only. On a client
## the creature bodies are driven by host state broadcasts, never local AI.
var is_authoritative: bool = true

func _ready() -> void:
	GameBus.creature_died.connect(_on_creature_died)
	GameBus.creature_respawned.connect(_on_creature_respawned)
	GameBus.creature_spawned.connect(_on_creature_spawned)

func _process(delta: float) -> void:
	if not is_authoritative:
		return
	if creature_slice == null:
		return
	var targets := _player_targets()
	if targets.is_empty():
		return
	# Phase 37 — the cached READ-ONLY view, not `get_all_instances()`: the latter builds
	# a fresh dictionary per instance on every call, and this loop runs once per frame.
	# The view is rebuilt only when the population's membership changes (see
	# CreatureSlice.instances_view), and the records in it are the live ones.
	var instances: Array = creature_slice.instances_view()
	for inst in instances:
		var iid: String = inst["instance_id"]
		var c_state: String = inst["state"]
		if c_state == "dead" or c_state == "respawning":
			continue
		_ensure_ai_record(iid, inst["position"])
		if _is_companion(iid):
			_tick_companion(iid, inst, delta)
			continue
		# Phase 36 — the NEAREST of every player, not only the host's own body: a
		# creature used to stand still while a remote peer walked through its
		# territory, because the only position it ever looked at was this machine's.
		var target := _nearest_target(inst["position"], targets)
		_tick_instance(iid, inst, target["position"], delta, str(target["id"]))

## The player targets on this machine (see `player_targets`).
func _player_targets() -> Dictionary:
	if player_targets.is_valid():
		var provided = player_targets.call()
		if provided is Dictionary:
			return provided
	if player_slice == null:
		return {}
	return { "player": player_slice.get_position() }

## The target nearest to `from`, as { id, position }. A dictionary's iteration order
## is insertion order, so the strict `<` keeps the first target on a tie — which, for
## a tie between the local player and a peer, means the local one, the same
## preference an un-wired slice had.
func _nearest_target(from: Vector3, targets: Dictionary) -> Dictionary:
	var best := {}
	for id in targets:
		var pos: Vector3 = targets[id]
		var d: float = from.distance_to(pos)
		if best.is_empty() or d < float(best["distance"]):
			best = { "id": str(id), "position": pos, "distance": d }
	return best

# ---------------------------------------------------------------------------
# Companion (Phase 35)
# ---------------------------------------------------------------------------

## Called by TamingSlice the moment an instance becomes a player's companion.
## Idempotent, and the state is re-asserted every tick anyway (see _tick_companion)
## so a restore or a respawn cannot leave a companion in a hostile state.
func on_companion_tamed(instance_id: String, _player_id: String) -> void:
	var pos := Vector3.ZERO
	if creature_slice != null:
		pos = creature_slice.get_instance_position(instance_id)
	_ensure_ai_record(instance_id, pos)
	_ai[instance_id]["state"] = STATE_TAMED

## A companion never aggros, never attacks and never patrols: it walks toward its
## owner and stops just short of them. The owner's position comes from TamingSlice,
## which resolves the local player's body or a remote peer's recorded position;
## when neither is knowable the companion holds position rather than guessing.
func _tick_companion(iid: String, inst: Dictionary, delta: float) -> void:
	if _ai[iid]["state"] != STATE_TAMED:
		_transition(iid, STATE_TAMED, inst)
	if taming_slice == null or not taming_slice.has_method("companion_target"):
		return
	if creature_slice == null or not creature_slice.has_method("get_tamed_by"):
		return
	var owner := str(creature_slice.get_tamed_by(iid))
	if owner == "":
		return
	var target = taming_slice.companion_target(owner)
	if not (target is Vector3):
		return
	var tgt: Vector3 = target
	var pos: Vector3 = inst["position"]
	if pos.distance_to(tgt) <= COMPANION_FOLLOW_STOP:
		return
	_move_instance(iid, inst, tgt, SPEED_COMPANION, delta)

## Whether an instance is somebody's companion (CreatureSlice owns the binding).
func _is_companion(iid: String) -> bool:
	if creature_slice == null or not creature_slice.has_method("is_tamed"):
		return false
	return bool(creature_slice.is_tamed(iid))

# ---------------------------------------------------------------------------
# Per-instance tick
# ---------------------------------------------------------------------------

## `target_id` is the identity of the player `player_pos` belongs to: "player" for
## this machine's own (the defender id the bus has always carried for it), or a
## remote peer's player id (Phase 36). It defaults to "player" so a caller that only
## has a position — every isolated test — keeps the single-player behaviour.
func _tick_instance(iid: String, inst: Dictionary, player_pos: Vector3, delta: float, target_id: String = "player") -> void:
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
	# aggressionLevel: 0=PASSIVE, 1=NEUTRAL, 2=AGGRESSIVE, 3=TERRITORIAL
	var aggression: int    = int(res.get("aggressionLevel")) if res else 1
	var alert_r: float     = float(res.get("alertRadius")) if res else 12.0
	var attack_r: float    = float(res.get("attackRadius")) if res else 3.0
	var flee_thr: float    = float(res.get("fleeThreshold")) if res else 0.20
	# TERRITORIAL creatures claim a wider alert area than their base alertRadius.
	# safe_r is always alertRadius * 1.5, computed before the territorial scaling
	# so it doesn't compound to alertRadius * 2.25.
	var safe_r: float      = float(res.get("alertRadius")) * 1.5 if res else alert_r * 1.5
	if aggression == 3:
		alert_r *= 1.5

	match ai_state:
		"idle":
			if dist <= alert_r:
				match aggression:
					0: # PASSIVE — flee immediately, never attack
						_transition(iid, "fleeing", inst)
					1: # NEUTRAL — pause and watch before committing
						_transition(iid, "alert", inst)
					2, 3: # AGGRESSIVE / TERRITORIAL — attack without warning
						_transition(iid, "aggressive", inst)
				return
			_patrol(iid, inst, delta)

		"alert":
			if dist <= attack_r:
				_transition(iid, "aggressive", inst)
				return
			if dist > alert_r:
				_transition(iid, "idle", inst)
				return

		"aggressive":
			if flee_thr > 0.0 and hp / max_hp < flee_thr:
				_transition(iid, "fleeing", inst)
				return
			if dist > safe_r:
				_transition(iid, "idle", inst)
				return
			_chase(iid, inst, player_pos, delta)
			ai["attack_timer"] += delta
			if ai["attack_timer"] >= ATTACK_INTERVAL:
				ai["attack_timer"] = 0.0
				if dist <= attack_r:
					# Phase 37 — the round is routed by the TARGET the creature engaged,
					# remote peers included. Phase 36 chased a peer but opened no round
					# against it ("damage to a peer belongs to that peer's own client"),
					# which left a creature that had closed on a remote player swinging at
					# nothing at all. The id the round carries is the one the battle slice
					# routes on: the literal "player" for this machine's own body, or the
					# peer's player id, which the host forwards to that peer's own client as
					# a damage event (see GameRoot._on_player_damaged) — the machine that
					# simulates that body is the one that applies the hit, because the host
					# holds no verifiable HP for a peer (PlayerRegistry.record_hp).
					GameBus.combat_round_requested.emit(iid, target_id)

		"fleeing":
			if hp <= 0.0:
				_transition(iid, "dead", inst)
				return
			if dist > safe_r:
				_transition(iid, "idle", inst)
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

func _transition(iid: String, new_state: String, inst: Dictionary = {}, propagate: bool = true) -> void:
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
	# Pack/herd threat escalation: when a member enters a threat state, pull
	# nearby same-species members into the same state (non-recursive — see
	# _escalate_neighbor).
	if propagate and not inst.is_empty():
		_propagate_group_state(iid, inst, new_state)

# ---------------------------------------------------------------------------
# Pack / herd coordination (Phase 30)
# ---------------------------------------------------------------------------

## groupBehavior (enum int) for a creature resource; GROUP_NONE when the field
## is absent or the resource is null. Solitary creatures omit the field entirely.
func _group_behavior(res: Resource) -> int:
	if res == null:
		return GROUP_NONE
	var gb: Variant = res.get("groupBehavior")
	return int(gb) if gb != null else GROUP_NONE

## packRadius (metres) for a creature resource; 0.0 when absent or null.
func _pack_radius(res: Resource) -> float:
	if res == null:
		return 0.0
	var pr: Variant = res.get("packRadius")
	return float(pr) if pr != null else 0.0

## Propagate a threat-state transition to nearby same-species members. Only
## escalation spreads (alert/aggressive/fleeing); calm-down (idle) and death are
## per-creature. `pack` shares alert + aggressive; `herd` shares fleeing only.
func _propagate_group_state(iid: String, inst: Dictionary, new_state: String) -> void:
	if new_state != "alert" and new_state != "aggressive" and new_state != "fleeing":
		return
	var res: Resource = GameData.CREATURES.get(inst["creature_id"], null)
	var group_behavior: int = _group_behavior(res)
	if group_behavior == GROUP_NONE:
		return
	var pack_r: float = _pack_radius(res)
	if pack_r <= 0.0:
		return
	# pack shares alert + aggressive; herd shares fleeing only.
	if group_behavior == GROUP_PACK and new_state == "fleeing":
		return
	if group_behavior == GROUP_HERD and new_state != "fleeing":
		return
	var neighbors: Array = creature_slice.creatures_in_radius(inst["position"], pack_r)
	for nid in neighbors:
		if nid == iid:
			continue
		if creature_slice.get_instance_creature_id(nid) != inst["creature_id"]:
			continue
		_escalate_neighbor(nid, new_state)

## Escalate a same-species neighbour toward `new_state` without downgrading it.
## Propagated transitions never re-propagate (propagate=false), so a pack flood
## is bounded and longer chains resolve over subsequent frames as each member
## ticks its own state machine.
func _escalate_neighbor(nid: String, new_state: String) -> void:
	if not _ai.has(nid):
		return
	# A companion is not a pack member any more (Phase 35): a wolf that joined a
	# player must not be dragged into its former pack's alert or flee.
	if _is_companion(nid):
		return
	var cur: String = _ai[nid]["state"]
	if cur == "dead" or cur == "respawning":
		return
	match new_state:
		"fleeing":
			if cur != "fleeing":
				_transition(nid, "fleeing", {}, false)
		"aggressive":
			if cur == "idle" or cur == "alert":
				_transition(nid, "aggressive", {}, false)
		"alert":
			if cur == "idle":
				_transition(nid, "alert", {}, false)

# ---------------------------------------------------------------------------
# Public API (test helper)
# ---------------------------------------------------------------------------

func get_state(instance_id: String) -> String:
	if not _ai.has(instance_id):
		return ""
	return _ai[instance_id]["state"]

func force_state(instance_id: String, state: String) -> void:
	var spawn_pos := Vector3.ZERO
	if creature_slice != null:
		for inst in creature_slice.get_all_instances():
			if inst["instance_id"] == instance_id:
				spawn_pos = inst["position"]
				break
	_ensure_ai_record(instance_id, spawn_pos)
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
