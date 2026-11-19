extends RefCounted
## Phase 273 — titles as pure functions of the fabric's `Titles` table and a player's title record.
##
## A record is `{ "unlocked": { <TitleId>: true }, "chosen": <TitleId or ""> }` and lives on the player's registry
## record. Every character has the built-in `Newcomer` unlocked, and wears it until they choose again (a record
## with no `chosen` key wears it; `""` is the player's own choice of none). A title only ever shows: recipe gates
## check unlocked professions (`CraftingSlice._check_profession_gate`), never the chosen title.

const SkillTiers := preload("res://src/core/skill_tiers.gd")
const I18n := preload("res://src/core/i18n.gd")

static func _res() -> Resource:
	return GameData.WORLD_SYSTEMS.get("Titles", null)

## { TitleId: { source: { kind, id?, state?, tier? } } }.
static func table() -> Dictionary:
	var r := _res()
	var t = r.get("titles") if r != null else null
	return t if t is Dictionary else {}

static func builtin() -> String:
	var r := _res()
	return str(r.get("builtin")) if r != null else ""

static func is_title(id: String) -> bool:
	return id != "" and table().has(id)

## The titles a profession reaching `state` ("active" or "mastered") unlocks.
static func for_profession(profession: String, state: String) -> Array:
	var out: Array = []
	var t := table()
	for id in t:
		var s: Dictionary = t[id].get("source", {})
		if str(s.get("kind", "")) == "profession" and str(s.get("id", "")) == profession and str(s.get("state", "")) == state:
			out.append(str(id))
	return out

## The title a skill reaching its master tier unlocks, or "".
static func for_skill_master(skill: String) -> String:
	var t := table()
	for id in t:
		var s: Dictionary = t[id].get("source", {})
		if str(s.get("kind", "")) == "skill" and str(s.get("id", "")) == skill:
			return str(id)
	return ""

## The professions built from `skill` ({ profession: [skills] } from the fabric's skill wheel).
static func professions_of_skill(skill: String) -> Dictionary:
	var out := {}
	var r: Resource = GameData.WORLD_SYSTEMS.get("SkillWheel", null)
	var ps = r.get("professionSkills") if r != null else null
	if ps is Dictionary:
		for p in ps:
			if (ps[p] as Array).has(skill):
				out[str(p)] = (ps[p] as Array).duplicate()
	return out

## A record as storage or the wire carries it, reduced to known titles. Always holds the built-in title.
static func sanitize(raw: Variant) -> Dictionary:
	var src: Dictionary = raw if raw is Dictionary else {}
	var unlocked := {}
	var u = src.get("unlocked", {})
	if u is Dictionary:
		for id in u:
			if bool(u[id]) and is_title(str(id)):
				unlocked[str(id)] = true
	var b := builtin()
	if b != "":
		unlocked[b] = true
	var chosen := b
	if src.has("chosen") and src["chosen"] is String:
		var c: String = src["chosen"]
		chosen = c if c == "" or unlocked.has(c) else b
	return { "unlocked": unlocked, "chosen": chosen }

static func unlocked_ids(rec: Dictionary) -> Array:
	var ids: Array = sanitize(rec)["unlocked"].keys()
	ids.sort()
	return ids

static func chosen_of(rec: Dictionary) -> String:
	return str(sanitize(rec)["chosen"])

## Add `id` to a sanitized record. False when it is unknown or already held.
static func unlock(rec: Dictionary, id: String) -> bool:
	if not is_title(id) or (rec["unlocked"] as Dictionary).has(id):
		return false
	rec["unlocked"][id] = true
	return true

## Wear `id` ("" to wear none). Returns "" or a refusal code: `unknown_title`, `title_locked`.
static func choose(rec: Dictionary, id: String) -> String:
	if id != "":
		if not is_title(id):
			return "unknown_title"
		if not (rec["unlocked"] as Dictionary).has(id):
			return "title_locked"
	rec["chosen"] = id
	return ""

## The nameplate text: the name, and the title under it in the viewer's locale when one is worn.
static func nameplate(player_name: String, title: String) -> String:
	if title == "" or not is_title(title):
		return player_name
	return "%s\n%s" % [player_name, I18n.content("title", title)]
