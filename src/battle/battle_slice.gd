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

func _ready() -> void:
	GameBus.combat_round_requested.connect(_on_combat_round_requested)
	GameBus.creature_respawned.connect(_on_creature_respawned)

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
	# the host can deliver it to that peer (GameRoot._on_player_damaged).
	if is_player_target(defender_id):
		if outcome != "miss":
			GameBus.player_damaged.emit(damage, attacker_id, defender_id)
		var result_player := {
			"attacker": attacker_id,
			"defender": defender_id,
			"damage":   snappedf(damage, 0.1),
			"outcome":  outcome,
			"defender_hp_remaining": -1.0,   # unknown — owned by PlayerSlice
		}
		GameBus.combat_round_resolved.emit(result_player)
		return result_player

	# A CREATURE defender: this slice owns its hit points, initialising them on first
	# encounter. (For a player defender they are never initialised — nothing here is
	# allowed to hold a number it cannot verify; see the branch above.)
	if not _hp_state.has(defender_id):
		_hp_state[defender_id] = max_hp

	_hp_state[defender_id] = maxf(_hp_state[defender_id] - damage, 0.0)
	var hp_remaining: float = _hp_state[defender_id]

	if hp_remaining <= 0.0 and outcome != "miss":
		outcome = "kill"
		# Resolve world position from creature_slice for loot drop placement.
		var death_pos := Vector3.ZERO
		if creature_slice != null:
			for inst in creature_slice.get_all_instances():
				if inst["instance_id"] == defender_id or inst["creature_id"] == defender_id:
					death_pos = inst["position"]
					break
		GameBus.creature_died.emit(defender_id, death_pos, attacker_id)

	var result := {
		"attacker": attacker_id,
		"defender": defender_id,
		"damage":   snappedf(damage, 0.1),
		"outcome":  outcome,
		"defender_hp_remaining": hp_remaining,
	}
	GameBus.combat_round_resolved.emit(result)
	return result

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

## Resolve a creature instance_id to its fabric key, then load from GameData.
func _lookup(entity_id: String) -> Resource:
	if entity_id == "player":
		push_warning("BattleSlice: 'player' entity has no GameData resource — using stat fallbacks")
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
