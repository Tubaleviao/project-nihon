extends RefCounted
## Phase 207 — skills grow from work: the pure half. Which skill a kind of work grows and by how much, read
## from the fabric's `WorkSkills` world system (`GameData.WORLD_SYSTEMS["WorkSkills"]`): crafting per recipe
## domain, gathering per material family (`families`), carcasses, building, dismantling, repairing and picking
## locks. The host's own slices call `grant` at the point the work succeeds; the kind of work and the XP come
## from this table and the host's own state, never from a client message, and only the worker gains.
##
## Phase 207 review — a grant also raises the worker's tier in that skill (`tiers`: cumulative XP per tier),
## so the recipe skill guards and the specialty tiers follow the work; a tier is never lowered. A grant's
## attribute sync is batched (`PlayerRegistry.flush_attribute_syncs`) unless an attribute gained a point.

const SkillTiers := preload("res://src/core/skill_tiers.gd")

## Kinds of work with a single row.
const SINGLE_KINDS := ["build", "dismantle", "repair", "lockpick"]
## Rows of the table with no grant site yet, and why. The suite fails on any other row with no grant site
## and on an entry here that gained one, so wiring a row means removing it from this list.
const UNWIRED := {
	"gather.plant": "no runtime forage action exists yet",
	"lockpick": "Phase 208 adds locks",
}

static func _res() -> Resource:
	return GameData.WORLD_SYSTEMS.get("WorkSkills", null)

## The work table `{ craft {domain: row}, gather {family: row}, build, dismantle, repair, lockpick }` ({} when absent).
static func table() -> Dictionary:
	var res := _res()
	var r: Variant = res.get("rules") if res != null else null
	return r if r is Dictionary else {}

## `{ material: "metal" | "stone" | "wood" | "soil" }` ({} when absent).
static func families() -> Dictionary:
	var res := _res()
	var f: Variant = res.get("families") if res != null else null
	return f if f is Dictionary else {}

## A material's gather family, or "".
static func family_of(material: String) -> String:
	return str(families().get(material, ""))

## `{ skill, xp }` for crafting a recipe of `domain` ({} for a domain with no row).
static func craft_row(domain: String) -> Dictionary:
	return _row((table().get("craft", {}) as Dictionary).get(domain, null))

## `{ skill, xp }` for gathering `key`: a material (by its family), or `plant` / `carcass` ({} when unmapped).
static func gather_row(key: String) -> Dictionary:
	var gather: Dictionary = table().get("gather", {})
	var fam := family_of(key)
	return _row(gather.get(fam if fam != "" else key, null))

## `{ skill, xp }` for one of SINGLE_KINDS ({} otherwise).
static func row(kind: String) -> Dictionary:
	return _row(table().get(kind, null)) if SINGLE_KINDS.has(kind) else {}

## `{ tier: cumulative XP }` from the fabric's `tiers` ({} when absent).
static func tiers() -> Dictionary:
	var res := _res()
	var t: Variant = res.get("tiers") if res != null else null
	return t if t is Dictionary else {}

## The highest tier `xp` reaches ("novice" below every threshold or without a table).
static func tier_for_xp(xp: int) -> String:
	var t := tiers()
	var best := "novice"
	for tier: String in SkillTiers.TIER_ORDER:
		if t.has(tier) and xp >= int(t[tier]):
			best = tier
	return best

static func _row(v: Variant) -> Dictionary:
	if not (v is Dictionary) or str(v.get("skill", "")) == "" or int(v.get("xp", 0)) < 1:
		return {}
	return { "skill": str(v["skill"]), "xp": int(v["xp"]) }

## Host: grant `work_row`'s XP to the worker (`player_id`, "" = this machine's player) through `registry`,
## `times` over (the units a mine banked), and raise their tier in the skill when the new total reaches the
## next one. No-op on an empty row, a missing registry or a non-authoritative registry (`grant_skill_xp`
## refuses there).
static func grant(registry: Object, player_id: String, work_row: Dictionary, times: int = 1) -> void:
	var pid := _worker(registry, player_id, work_row)
	if pid == "" or times < 1 or not registry.has_method("grant_skill_xp") or not bool(registry.get("is_authoritative")):
		return
	var skill := str(work_row["skill"])
	registry.grant_skill_xp(pid, skill, int(work_row["xp"]) * times, true)
	_promote(registry, pid, skill)

## Host: take back what one `grant` of `work_row` gave (a block its own builder took apart again: an undo).
## The tier and the attribute growth stay; the skill's XP never drops below 0.
static func revoke(registry: Object, player_id: String, work_row: Dictionary) -> void:
	var pid := _worker(registry, player_id, work_row)
	if pid == "" or not registry.has_method("add_skill_xp") or not bool(registry.get("is_authoritative")):
		return
	registry.add_skill_xp(pid, str(work_row["skill"]), -int(work_row["xp"]))

static func _worker(registry: Object, player_id: String, work_row: Dictionary) -> String:
	if work_row.is_empty() or registry == null:
		return ""
	var pid := player_id
	if pid == "" and "local_player_id" in registry:
		pid = str(registry.local_player_id)
	return pid

## Record the tier `skill`'s XP has reached when it is above the recorded one (an unrecorded skill is novice),
## and announce it (`skill_tier_recorded`: specialties, the clan roster and professions recompute).
static func _promote(registry: Object, pid: String, skill: String) -> void:
	if not registry.has_method("get_skill_xp") or not registry.has_method("record_skill"):
		return
	var tier := tier_for_xp(int(registry.get_skill_xp(pid, skill)))
	var held := str(registry.get_skill_tier(pid, skill)) if registry.has_method("get_skill_tier") else ""
	if SkillTiers.rank(tier) <= (SkillTiers.rank(held) if SkillTiers.is_valid_tier(held) else 0):
		return
	registry.record_skill(pid, skill, tier)
	GameBus.skill_tier_recorded.emit(pid, skill, tier)
