extends RefCounted
## Phase 207 — skills grow from work: the pure half. Which skill a kind of work grows and by how much, read
## from the fabric's `WorkSkills` world system (`GameData.WORLD_SYSTEMS["WorkSkills"]`): crafting per recipe
## domain, gathering per material family (`families`), carcasses, building, dismantling, repairing and picking
## locks. The host's own slices call `grant` at the point the work succeeds; the kind of work and the XP come
## from this table and the host's own state, never from a client message, and only the worker gains.

## Kinds of work with a single row.
const SINGLE_KINDS := ["build", "dismantle", "repair", "lockpick"]

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

static func _row(v: Variant) -> Dictionary:
	if not (v is Dictionary) or str(v.get("skill", "")) == "" or int(v.get("xp", 0)) < 1:
		return {}
	return { "skill": str(v["skill"]), "xp": int(v["xp"]) }

## Host: grant `work_row`'s XP to the worker (`player_id`, "" = this machine's player) through `registry`.
## `times` scales it (a slice of several blocks). No-op on an empty row, a missing registry or a
## non-authoritative registry (`grant_skill_xp` refuses there).
static func grant(registry: Object, player_id: String, work_row: Dictionary, times: int = 1) -> void:
	if work_row.is_empty() or registry == null or not registry.has_method("grant_skill_xp") or times < 1:
		return
	var pid := player_id
	if pid == "" and "local_player_id" in registry:
		pid = str(registry.local_player_id)
	if pid == "":
		return
	registry.grant_skill_xp(pid, str(work_row["skill"]), int(work_row["xp"]) * times)
