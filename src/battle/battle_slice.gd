extends Node
## Battle slice — one-round combat resolution using fabric data from GameData.
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : combat_round_requested(attacker_id, defender_id)
##   OUT : combat_round_resolved(result)
##
## Public API:
##   resolve_round(attacker_id, defender_id) -> Dictionary
##   reset_hp(entity_id)                     -> void

## Running HP for each combatant, keyed by entity_id.
## Populated on first hit; reset via reset_hp().
var _hp_state: Dictionary = {}

func _ready() -> void:
	GameBus.combat_round_requested.connect(_on_combat_round_requested)

## Resolve a single combat round synchronously and emit the result.
func resolve_round(attacker_id: String, defender_id: String) -> Dictionary:
	var attacker_res := _lookup(attacker_id)
	var defender_res := _lookup(defender_id)

	var base_dmg: float = _field(attacker_res, "baseDamage", 10.0)
	var max_hp:   float = _field(defender_res, "baseHp",     100.0)

	# Initialise running HP on first encounter.
	if not _hp_state.has(defender_id):
		_hp_state[defender_id] = max_hp

	# Hit roll: base 80 % hit rate, modified by tier difference
	var hit_roll := randf()
	var outcome: String
	var damage := 0.0

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

	_hp_state[defender_id] = maxf(_hp_state[defender_id] - damage, 0.0)
	var hp_remaining: float = _hp_state[defender_id]

	if hp_remaining <= 0.0 and outcome != "miss":
		outcome = "kill"
		GameBus.creature_died.emit(defender_id, Vector3.ZERO, attacker_id)

	var result := {
		"attacker": attacker_id,
		"defender": defender_id,
		"damage":   snappedf(damage, 0.1),
		"outcome":  outcome,
		"defender_hp_remaining": hp_remaining,
	}
	GameBus.combat_round_resolved.emit(result)
	return result

## Reset a combatant's tracked HP back to its base value (e.g. on respawn).
func reset_hp(entity_id: String) -> void:
	_hp_state.erase(entity_id)

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _on_combat_round_requested(attacker_id: String, defender_id: String) -> void:
	resolve_round(attacker_id, defender_id)

func _lookup(entity_id: String) -> Resource:
	if entity_id == "player":
		push_warning("BattleSlice: 'player' entity has no GameData resource — using stat fallbacks")
		return null
	if GameData.CREATURES.has(entity_id):
		return GameData.CREATURES[entity_id]
	return null

func _field(res: Resource, field: String, fallback: float) -> float:
	if res == null:
		return fallback
	if field in res:
		var v = res.get(field)
		if v is float or v is int:
			return float(v)
	return fallback
