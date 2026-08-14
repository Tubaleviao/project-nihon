extends Node
## Battle slice — one-round combat resolution using fabric data from GameData.
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : combat_round_requested(attacker_id, defender_id)
##   OUT : combat_round_resolved(result)
##
## Public API:
##   resolve_round(attacker_id, defender_id) -> Dictionary

func _ready() -> void:
	GameBus.combat_round_requested.connect(_on_combat_round_requested)

## Resolve a single combat round synchronously and emit the result.
func resolve_round(attacker_id: String, defender_id: String) -> Dictionary:
	var attacker_res := _lookup(attacker_id)
	var defender_res := _lookup(defender_id)

	var base_dmg: float = _field(attacker_res, "baseDamage", 10.0)
	var def_hp:   float = _field(defender_res, "baseHp",     100.0)

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

	var result := {
		"attacker": attacker_id,
		"defender": defender_id,
		"damage":   snappedf(damage, 0.1),
		"outcome":  outcome,
		"defender_hp_remaining": maxf(def_hp - damage, 0.0),
	}
	GameBus.combat_round_resolved.emit(result)
	return result

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _on_combat_round_requested(attacker_id: String, defender_id: String) -> void:
	resolve_round(attacker_id, defender_id)

func _lookup(entity_id: String) -> Resource:
	if entity_id == "player":
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
