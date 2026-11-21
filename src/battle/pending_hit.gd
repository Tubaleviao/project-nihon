extends RefCounted
## Phase 287 — the host resolves a swing's hit at the clip's impact time, not at the click. This is the pure half:
## the queue of pending hits (one per attacker; a new action cancels the old), the re-check at impact with the
## state at impact, and the hit reaction (`hit` or `stagger`, and the knock-back direction away from the attacker).
## The damage a pending hit deals comes from the weapon and combo step the swing started with.

const ComboChain := preload("res://src/battle/combo_chain.gd")

## attacker id -> { attacker, target, weapon, item, step, due, damage_multiplier }
var _pending: Dictionary = {}

func size() -> int:
	return _pending.size()

func has_pending(attacker_id: String) -> bool:
	return _pending.has(attacker_id)

## Queue the hit of a swing that started at `now` with a clip of `clip_length` seconds. A new swing, or any other
## action, from the same attacker replaces (cancels) its previous pending hit.
func start(attacker_id: String, target_id: String, weapon: String, item: String, step: int, now: float, clip_length: float) -> Dictionary:
	var entry := {
		"attacker": attacker_id, "target": target_id, "weapon": weapon, "item": item, "step": step,
		"due": now + ComboChain.impact_seconds(weapon, step, clip_length),
		"damage_multiplier": ComboChain.damage_multiplier(weapon, step),
	}
	_pending[attacker_id] = entry
	return entry

## Cancel an attacker's pending hit (it died, was staggered, started another action): nothing is dealt.
func cancel(attacker_id: String) -> bool:
	return _pending.erase(attacker_id)

## Why a pending hit must not land with the state at impact; "" when it may. `state`: attacker_alive,
## attacker_staggered, attacker_item (the weapon in hand now), target_alive, gap (metres now), reach.
static func refusal(entry: Dictionary, state: Dictionary) -> String:
	if not bool(state.get("attacker_alive", false)):
		return "attacker_dead"
	if bool(state.get("attacker_staggered", false)):
		return "attacker_staggered"
	if str(state.get("attacker_item", "")) != str(entry.get("item", "")):
		return "weapon_switched"
	if not bool(state.get("target_alive", false)):
		return "target_dead"
	if float(state.get("gap", INF)) > float(state.get("reach", 0.0)):
		return "out_of_range"
	return ""

## The hits due by `now`, removed from the queue: `[{ entry, reason }]`, `reason` "" for one that lands and the
## refusal for one that is cancelled (which deals nothing and sends no hit sync). `state_of(entry) -> Dictionary`.
func resolve_due(now: float, state_of: Callable) -> Array:
	var out := []
	for attacker in _pending.keys():
		var entry: Dictionary = _pending[attacker]
		if float(entry["due"]) > now:
			continue
		_pending.erase(attacker)
		out.append({ "entry": entry, "reason": refusal(entry, state_of.call(entry)) })
	return out

## "stagger" for a hit of at least `share` of the target's max health, else "hit".
static func reaction(damage: float, max_hp: float, share: float) -> String:
	return "stagger" if max_hp > 0.0 and damage / max_hp >= share else "hit"

## The horizontal unit direction a struck target is pushed, away from the attacker (zero when they coincide).
static func knockback_direction(attacker_pos: Vector3, target_pos: Vector3) -> Vector3:
	var d := Vector3(target_pos.x - attacker_pos.x, 0.0, target_pos.z - attacker_pos.z)
	return d.normalized() if d.length() > 1e-6 else Vector3.ZERO
