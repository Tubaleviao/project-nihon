extends Node
## Battle slice — one-round combat resolution using fabric data from GameData.
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : combat_round_requested(attacker_id, defender_id)
##   OUT : combat_round_resolved(result)
##         player_damaged(damage, attacker_id, target_id)
##
## Public API:
##   resolve_round(attacker_id, defender_id) -> Dictionary
##   reset_hp(entity_id)                     -> void
##   is_player_target(entity_id)             -> bool   (static, Phase 37)

## Running HP for each combatant, keyed by entity_id.
## Populated on first hit; reset via reset_hp().
var _hp_state: Dictionary = {}

## Set by game_root so instance IDs can be resolved to fabric creature keys.
var creature_slice: Node = null

## Phase 129 — the host's status effects (a `StatusEffects`), and `() -> float` for the current time in
## seconds. Both are null/invalid outside a host, so a round there is plain damage.
var status_effects: RefCounted = null
var now_fn: Callable = Callable()
## Phase 157 — the host's death push: `(entity_id) -> Vector3` for an attacker's world position (null
## position vector = unknown) and `(Vector3) -> bool` for a walkable probe. Unset, a kill pushes nothing.
var attacker_pos_fn: Callable = Callable()
var walkable_fn: Callable = Callable()
## `(Vector3) -> float`: ground height under a landing spot, so the body lies on the terrain.
var ground_fn: Callable = Callable()
## Counts resolved rounds; the seed of the on-hit roll, so a replayed round rolls the same.
var _round_seq: int = 0

func _ready() -> void:
	GameBus.combat_round_requested.connect(_on_combat_round_requested)
	GameBus.creature_respawned.connect(_on_creature_respawned)

const DeathPush := preload("res://src/battle/death_push.gd")

## Phase 37 — the registry's id-SHAPE predicate, preloaded for the player/creature
## split: it is a pure static check on a string, so no registry needs to be in the tree
## for a defender id to be recognised as a player's.
const PlayerRegistry := preload("res://src/persistence/player_registry.gd")

## Phase 37 — is `defender_id` a PLAYER rather than a creature?
##
## The creature path tracks hit points and emits `creature_died` when they run out;
## a PLAYER's health is owned by the machine that simulates that body (PlayerSlice),
## so a round against a player forwards damage instead. Two shapes are players: the
## literal "player" (the local body's id, used by the bus since Phase 1) and a
## server-minted player id — the target a remote peer is named by in
## `combat_round_requested` (see CreatureAI._tick_instance). Pure and static, so the
## rule is testable on its own and every caller agrees on it.
static func is_player_target(defender_id: String) -> bool:
	return defender_id == "player" or PlayerRegistry.looks_like_player_id(defender_id)

## Resolve a single combat round synchronously and emit the result.
func resolve_round(attacker_id: String, defender_id: String) -> Dictionary:
	var attacker_res := _lookup(attacker_id)
	var defender_res := _lookup(defender_id)

	var base_dmg: float = _field(attacker_res, "baseDamage", 10.0)
	var max_hp:   float = _field(defender_res, "baseHp",     100.0)

	# Hit roll: base 80 % hit rate, modified by tier difference
	var hit_roll := randf()
	var outcome: String
	var damage := 0.0

	_round_seq += 1
	var now := _now()
	if hit_roll < 0.8:
		damage = base_dmg * randf_range(0.85, 1.15)
		var is_crit := randf() < 0.1
		if is_crit:
			damage *= 2.0
			outcome = "critical"
		else:
			outcome = "hit"
	else:
		outcome = "miss"

	# A player's HP is owned by that player's own simulation (PlayerSlice), so damage
	# is FORWARDED via the bus rather than tracked here, and the kill-check is skipped
	# (PlayerSlice handles death). Phase 37 — that rule is now keyed on the DEFENDER
	# SHAPE, not on the literal "player": a round routed by target id can name a remote
	# peer, whose body is simulated on its own client. The target rides the signal, so
	# the host can deliver it to that peer (CombatWiring._on_player_damaged).
	if is_player_target(defender_id):
		if outcome != "miss":
			# Phase 129 — a knocked-down body takes more; the hit may leave an effect on it.
			if status_effects != null:
				damage *= status_effects.damage_factor(defender_id, now)
				_roll_on_hit(attacker_res, attacker_id, defender_id, now)
			GameBus.player_damaged.emit(damage, attacker_id, defender_id)
		var result_player := {
			"attacker": attacker_id,
			"defender": defender_id,
			"damage":   snappedf(damage, 0.1),
			"outcome":  outcome,
			"defender_hp_remaining": -1.0,   # unknown — owned by PlayerSlice
		}
		GameBus.combat_round_resolved.emit(result_player)
		GameBus.combat_hit_resolved.emit(attacker_id, defender_id, outcome, damage)
		return result_player

	# A CREATURE defender: this slice owns its hit points, initialising them on first
	# encounter. (For a player defender they are never initialised — nothing here is
	# allowed to hold a number it cannot verify; see the branch above.)
	if not _hp_state.has(defender_id):
		_hp_state[defender_id] = max_hp

	if status_effects != null and outcome != "miss":
		damage *= status_effects.damage_factor(defender_id, now)
	_hp_state[defender_id] = maxf(_hp_state[defender_id] - damage, 0.0)
	var hp_remaining: float = _hp_state[defender_id]

	if hp_remaining <= 0.0 and outcome != "miss":
		outcome = "kill"
		# Resolve world position from creature_slice for loot drop placement.
		var death_pos := Vector3.ZERO
		var pos_found := false
		if creature_slice != null:
			for inst in creature_slice.get_all_instances():
				if inst["instance_id"] == defender_id or inst["creature_id"] == defender_id:
					death_pos = inst["position"]
					pos_found = true
					break
		# No resolved position, no push: a throw from the world origin would land somewhere unrelated.
		var landing := death_landing(death_pos, attacker_id, damage, max_hp, size_ratio(attacker_id, max_hp)) if pos_found else Vector3.ZERO
		GameBus.creature_died.emit(defender_id, death_pos, attacker_id, landing)

	var result := {
		"attacker": attacker_id,
		"defender": defender_id,
		"damage":   snappedf(damage, 0.1),
		"outcome":  outcome,
		"defender_hp_remaining": hp_remaining,
	}
	GameBus.combat_round_resolved.emit(result)
	GameBus.combat_hit_resolved.emit(attacker_id, defender_id, outcome, damage)
	return result

## Phase 157 — attacker/target size ratio for the death push. Creatures carry no size field, so the
## base hit points stand in for body volume (cube root); an unknown attacker reads as 1.0.
func size_ratio(attacker_id: String, target_hp: float) -> float:
	var attacker_res := _lookup(attacker_id)
	if attacker_res == null or target_hp <= 0.0:
		return 1.0
	var attacker_hp := float(_field(attacker_res, "baseHp", target_hp))
	return pow(maxf(attacker_hp, 0.001) / target_hp, 1.0 / 3.0)

## Phase 157 — where a killing blow leaves the body: pushed away from the attacker by `DeathPush`.
## Host-side only (BattleSlice never runs a client's number); `Vector3.ZERO` when the attacker's position
## is unknown, so the body stays where it fell.
func death_landing(pos: Vector3, attacker_id: String, damage: float, max_hp: float, ratio: float = 1.0) -> Vector3:
	if not attacker_pos_fn.is_valid():
		return Vector3.ZERO
	var src: Variant = attacker_pos_fn.call(attacker_id)
	if not (src is Vector3):
		return Vector3.ZERO
	var spot := DeathPush.landing(pos, src as Vector3, damage, max_hp, ratio, walkable_fn)
	if spot == pos:
		return Vector3.ZERO
	if ground_fn.is_valid():
		spot.y = float(ground_fn.call(spot))   # the body rests on the ground it lands on, uphill or down
	return spot

func _now() -> float:
	return float(now_fn.call()) if now_fn.is_valid() else 0.0

## Phase 129 — roll the attacker's `onHitEffects` against a landed hit on a player and apply the ones
## that land. A displacing effect (knockback) asks the host to move the body; the HUD set is pushed.
func _roll_on_hit(attacker_res: Resource, attacker_id: String, target_id: String, now: float) -> void:
	if attacker_res == null:
		return
	var landed: Array = status_effects.rolled_effects(attacker_res.get("onHitEffects"), _round_seq, attacker_id, target_id)
	for effect in landed:
		status_effects.apply(target_id, effect, now)
		var tiles := int(status_effects.row(effect).get("displaceTiles", 0))
		if tiles > 0:
			GameBus.knockback_requested.emit(target_id, attacker_id, tiles)

## Return the current tracked combat HP for an entity (-1.0 if not yet in combat).
func get_hp(entity_id: String) -> float:
	return _hp_state.get(entity_id, -1.0)

## Reset a combatant's tracked HP back to its base value (e.g. on respawn).
func reset_hp(entity_id: String) -> void:
	_hp_state.erase(entity_id)

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _on_combat_round_requested(attacker_id: String, defender_id: String) -> void:
	resolve_round(attacker_id, defender_id)

## Clear tracked HP when a creature respawns so it doesn't re-enter combat with
## a stale 0 HP (which would cause an instant re-kill on the next round).
func _on_creature_respawned(instance_id: String, _creature_id: String) -> void:
	reset_hp(instance_id)
	if status_effects != null:
		status_effects.clear(instance_id)

## Resolve a creature instance_id to its fabric key, then load from GameData.
func _lookup(entity_id: String) -> Resource:
	if entity_id == "player":
		# The player has no GameData resource by design; callers use stat fallbacks.
		return null
	# Direct fabric key lookup first.
	if GameData.CREATURES.has(entity_id):
		return GameData.CREATURES[entity_id]
	# Resolve creature instance_id → fabric key via creature_slice.
	if creature_slice != null:
		var creature_id: String = creature_slice.get_instance_creature_id(entity_id)
		if creature_id != "" and GameData.CREATURES.has(creature_id):
			return GameData.CREATURES[creature_id]
	return null

func _field(res: Resource, field: String, fallback: float) -> float:
	if res == null:
		return fallback
	return float(res.get(field))
