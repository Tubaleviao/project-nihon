extends Node
## Profession slice (Phase 118) — unlocks the professions whose fabric entity carries
## structured `unlock` data (`GameData.PROFESSIONS[key].unlock`): the skill tiers that
## must all be held and the player flag that must be set. `VoidTouched` is the first.
##
## The unlock is HOST-resolved and per-player, like the skill tiers and flags it reads:
## a client never evaluates it, it mirrors its own set from the owner-scoped own-state
## sync (`apply_record`). The set is durable (`PlayerRegistry.record_professions`).
##
## Public API:
##   unlock_spec(profession) -> Dictionary      — { skills: [{skill, tier}], requiresFlag }
##   can_unlock(player_id, profession) -> bool  — pure projection of the three conditions
##   is_unlocked(player_id, profession) -> bool
##   get_unlocked(player_id := "") -> Dictionary
##   evaluate(player_id := "") -> Array         — unlock whatever now qualifies (host only)
##   sync_record / apply_record / forget_player_id — persistence mirror, like TamingSlice
##   OUT : GameBus.profession_unlocked(player_id, profession)
const SkillTiers := preload("res://src/core/skill_tiers.gd")

## Set by game_root: tier source (`get_skill_for`), flag source (`has_flag`) and records.
var crafting_slice: Node = null
var flag_store: Node = null
var player_registry: Node = null

## False on a client: it owns no records and mirrors its own set from the host.
var is_authoritative: bool = true

## player_id -> { profession: true }.
var _unlocked: Dictionary = {}

## The fabric unlock data of a profession, or {} when it has none (most do not).
static func unlock_spec(profession: String) -> Dictionary:
	var res: Resource = GameData.PROFESSIONS.get(profession, null)
	if res == null:
		return {}
	var v = res.get("unlock")
	return (v as Dictionary).duplicate(true) if v is Dictionary else {}

func local_player_id() -> String:
	if player_registry != null and "local_player_id" in player_registry:
		return str(player_registry.local_player_id)
	return ""

func resolve_player(player_id: String) -> String:
	return player_id if player_id != "" else local_player_id()

## Whether every condition of `profession`'s unlock data holds for the player right
## now. A profession with no unlock data cannot be unlocked here (false). Fails closed
## when a source is not wired.
func can_unlock(player_id: String, profession: String) -> bool:
	var spec := unlock_spec(profession)
	if spec.is_empty() or crafting_slice == null:
		return false
	var pid := resolve_player(player_id)
	for entry in spec.get("skills", []):
		var need := str(entry.get("tier", "novice"))
		if SkillTiers.rank(crafting_slice.get_skill_for(pid, str(entry.get("skill", "")))) < SkillTiers.rank(need):
			return false
	var flag := str(spec.get("requiresFlag", ""))
	if flag != "":
		if flag_store == null or not flag_store.has_flag(pid, flag):
			return false
	return true

func is_unlocked(player_id: String, profession: String) -> bool:
	return _unlocked_for(resolve_player(player_id)).has(profession)

func get_unlocked(player_id: String = "") -> Dictionary:
	return _unlocked_for(resolve_player(player_id)).duplicate()

## Unlock every profession with unlock data that now qualifies. Host only. Returns the
## names unlocked by THIS call; each emits `profession_unlocked` once and the set is
## written to the record.
func evaluate(player_id: String = "") -> Array:
	var out: Array = []
	if not is_authoritative:
		return out
	var pid := resolve_player(player_id)
	for profession in GameData.PROFESSIONS:
		var key := str(profession)
		if _unlocked_for(pid).has(key) or not can_unlock(pid, key):
			continue
		_unlocked_for(pid)[key] = true
		out.append(key)
	if not out.is_empty():
		sync_record(pid)
		for key in out:
			GameBus.profession_unlocked.emit(pid, key)
	return out

func sync_record(player_id: String = "") -> void:
	var pid := resolve_player(player_id)
	if pid == "" or player_registry == null or not player_registry.has_method("record_professions"):
		return
	player_registry.record_professions(pid, get_unlocked(pid))

## Restore a player's set from their record (or an own-state payload). Only known
## professions are kept, so a stale or hostile payload cannot grow the table.
func apply_record(record: Dictionary, player_id: String = "") -> void:
	var pid := resolve_player(player_id)
	if pid == "":
		return
	var stored = record.get("professions", {})
	if not (stored is Dictionary):
		return
	var set := _unlocked_for(pid)
	for key in stored:
		if bool(stored[key]) and GameData.PROFESSIONS.has(str(key)):
			set[str(key)] = true

func forget_player_id(player_id: String) -> void:
	if player_id.is_empty() or player_id == local_player_id():
		return
	_unlocked.erase(player_id)

func _unlocked_for(player_id: String) -> Dictionary:
	if not _unlocked.has(player_id):
		_unlocked[player_id] = {}
	return _unlocked[player_id]
