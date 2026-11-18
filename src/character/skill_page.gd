extends RefCounted
## Phase 272 — what a skill's own page shows, as a pure projection of the skill's tier and XP, the wheel table
## and the work table. The UI slice localizes it; nothing here is prose.

const SkillTiers := preload("res://src/core/skill_tiers.gd")
const WorkSkills := preload("res://src/character/work_skills.gd")
const SkillFocus := preload("res://src/character/skill_focus.gd")
const AttributeRules := preload("res://src/character/attribute_rules.gd")

## The local player's XP per skill as the host last told them ({ skill: xp }), or computed on the host itself.
static var local_xp: Dictionary = {}

## A synced XP table, bounded.
static func sanitize_xp(data: Variant) -> Dictionary:
	var out: Dictionary = {}
	if data is Dictionary:
		for skill in data:
			if out.size() < 64 and (data[skill] is int or data[skill] is float):
				out[str(skill)] = clampi(int(data[skill]), 0, 100000000)
	return out

## { skill, tier, xp, level_floor, next_floor (-1 at the last tier), progress (0..1, 1 at the last tier),
##   next_unlocks: [{ tier, kind, key }] for the tiers above the player's, trainers: [work kind],
##   professions: [id], focus_minutes, focus_bonus }.
static func page(skill: String, xp: int, focus_view: Dictionary, wheel: Resource) -> Dictionary:
	var order: Array = SkillTiers.TIER_ORDER
	var floors: Dictionary = WorkSkills.tiers()
	var tier := WorkSkills.tier_for_xp(xp)
	var idx := order.find(tier)
	var floor_xp := int(floors.get(tier, 0))
	var next_floor := -1
	if idx + 1 < order.size() and floors.has(order[idx + 1]):
		next_floor = int(floors[order[idx + 1]])
	var progress := 1.0
	if next_floor > floor_xp:
		progress = clampf(float(xp - floor_xp) / float(next_floor - floor_xp), 0.0, 1.0)
	var unlocks: Array = []
	var professions: Array = []
	if wheel != null:
		var nodes: Dictionary = wheel.get("nodes")
		for t in order.slice(idx + 1):
			var n: Variant = nodes.get("%s:%s" % [skill, t], null)
			if n is Dictionary:
				unlocks.append({"tier": str(t), "kind": str(n["unlock"]["kind"]), "key": str(n["unlock"]["key"])})
		var ps: Dictionary = wheel.get("professionSkills")
		for p in ps:
			if (ps[p] as Array).has(skill):
				professions.append(str(p))
		professions.sort()
	var minutes := int(focus_view.get(skill, 0))
	return {"skill": skill, "tier": tier, "xp": xp, "level_floor": floor_xp, "next_floor": next_floor,
		"progress": progress, "next_unlocks": unlocks, "trainers": trainers(skill), "professions": professions,
		"focus_minutes": minutes,
		"focus_bonus": SkillFocus.max_bonus() * float(minutes) / float(SkillFocus.window_minutes())}

## The work kinds whose XP row trains `skill`, sorted.
static func trainers(skill: String) -> Array:
	var out: Array = []
	var table := WorkSkills.table()
	for kind in table:
		var row: Variant = table[kind]
		if row is Dictionary:
			if str(row.get("skill", "")) == skill:
				out.append(str(kind))
			else:
				for sub in row:
					if row[sub] is Dictionary and str(row[sub].get("skill", "")) == skill:
						out.append("%s.%s" % [kind, sub])
	out.sort()
	return out

## Focus shares by category from a synced view: { category: share } (sums to 1, empty with no focus).
static func category_shares(focus_view: Dictionary) -> Dictionary:
	var total := 0
	for s in focus_view:
		total += int(focus_view[s])
	var out: Dictionary = {}
	for s in focus_view:
		var cat := AttributeRules.category_of_skill(str(s))
		if cat == "":
			cat = "other"
		out[cat] = float(out.get(cat, 0.0)) + float(focus_view[s]) / float(maxi(1, total))
	return out

## Focus by profession from a synced view: { profession: share of the window's active minutes } for the
## professions whose skills had focus. A shared skill counts for each profession it leads to.
static func profession_shares(focus_view: Dictionary, profession_skills: Dictionary) -> Dictionary:
	var total := 0
	for s in focus_view:
		total += int(focus_view[s])
	var out: Dictionary = {}
	if total <= 0:
		return out
	for p in profession_skills:
		var minutes := 0
		for s in (profession_skills[p] as Array):
			minutes += int(focus_view.get(str(s), 0))
		if minutes > 0:
			out[str(p)] = clampf(float(minutes) / float(total), 0.0, 1.0)
	return out
