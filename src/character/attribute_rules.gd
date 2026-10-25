extends RefCounted
## Phase 178 — pure rules for character attributes: the fabric's derivation formula, sanitising a saved or
## wire value, and growth from skill XP. No state and no nodes; the host's `PlayerRegistry` keeps the numbers.
##
## Tables are `GameData.ATTRIBUTES["AttributeSystem"]` (see fabric/gameplay/attributes.js):
##   stat = clamp(statBase + (d < 0 ? perPointBelow : perPoint) * d, min, max), with d = value - base.
## Growth: XP in a skill category is split over its weighted attributes. An attribute that has grown `g` points
## needs `xpPerPoint * (1 + costStep * g)` weighted XP for the next one; growth stops at `hardCap` per attribute
## and `totalPointsCap` across all six.

## The skill-category enum as an index (fabric/gameplay/skills/shared.js SKILL_CATEGORIES).
const SKILL_CATEGORIES := ["combat", "crafting", "magic", "exploration", "social", "survival"]

## Largest XP grant a single call counts, so one absurd grant cannot jump several points through the cap check.
const MAX_GRANT_XP := 100000.0


static func system() -> Resource:
	return GameData.ATTRIBUTES.get("AttributeSystem", null)


static func ids() -> Array:
	var s := system()
	return Array(s.get("attributes")) if s != null else []


static func base() -> int:
	var s := system()
	return int(s.get("base")) if s != null else 10


static func hard_cap() -> int:
	var s := system()
	return int(s.get("hardCap")) if s != null else 30


static func creation_min() -> int:
	var s := system()
	return int(s.get("creationMin")) if s != null else 5


static func creation_max() -> int:
	var s := system()
	return int(s.get("creationMax")) if s != null else 18


static func derivation() -> Dictionary:
	var s := system()
	var d = s.get("derivation") if s != null else null
	return d if d is Dictionary else {}


## Every attribute at base: what a character saved before Phase 178 reads as.
static func defaults() -> Dictionary:
	var out := {}
	for a in ids():
		out[a] = base()
	return out


## `raw` as a complete { attribute: int } table: unknown keys dropped, missing or non-numeric ones at base,
## every value inside creation-min..hard-cap (a saved or wire value is never trusted past the fabric bounds).
static func sanitize(raw: Variant) -> Dictionary:
	var out := defaults()
	if raw is Dictionary:
		for a in out.keys():
			var v: Variant = (raw as Dictionary).get(a, null)
			if (v is int or v is float) and is_finite(float(v)):
				out[a] = clampi(int(v), creation_min(), hard_cap())
	return out


## One derived stat for an attribute table, per the fabric formula; 0.0 for a stat the table does not define.
static func stat(stat_id: String, attributes: Dictionary) -> float:
	var row: Variant = derivation().get(stat_id, null)
	if not row is Dictionary:
		return 0.0
	var r: Dictionary = row
	var value := int(attributes.get(str(r["attribute"]), base()))
	var d := value - base()
	var slope := float(r["perPointBelow"]) if d < 0 else float(r["perPoint"])
	return clampf(float(r["base"]) + slope * d, float(r["min"]), float(r["max"]))


## Every derived stat for a table, `{ stat_id: float }` (the character sheet's source, Phase 179).
static func all_stats(attributes: Dictionary) -> Dictionary:
	var out := {}
	for id in derivation():
		out[id] = stat(str(id), attributes)
	return out


static func category_name(index: int) -> String:
	return SKILL_CATEGORIES[index] if index >= 0 and index < SKILL_CATEGORIES.size() else ""


## The category name of a skill entity key ("" for an unknown skill).
static func category_of_skill(skill: String) -> String:
	var res: Variant = GameData.SKILLS.get(skill, null)
	return category_name(int((res as Resource).get("category"))) if res is Resource else ""


## An empty growth state: `points` grown per attribute and the weighted `xp` banked toward the next point.
static func empty_growth() -> Dictionary:
	var points := {}
	var xp := {}
	for a in ids():
		points[a] = 0
		xp[a] = 0.0
	return { "points": points, "xp": xp }


## `raw` as a complete growth state with clamped, finite numbers.
static func sanitize_growth(raw: Variant) -> Dictionary:
	var out := empty_growth()
	if raw is Dictionary:
		var p: Variant = (raw as Dictionary).get("points", {})
		var x: Variant = (raw as Dictionary).get("xp", {})
		for a in ids():
			if p is Dictionary and ((p as Dictionary).get(a, null) is int or (p as Dictionary).get(a, null) is float) and is_finite(float(p[a])):
				out["points"][a] = clampi(int(p[a]), 0, hard_cap())
			if x is Dictionary and ((x as Dictionary).get(a, null) is int or (x as Dictionary).get(a, null) is float) and is_finite(float(x[a])):
				out["xp"][a] = clampf(float(x[a]), 0.0, MAX_GRANT_XP)
	return out


static func total_points(growth: Dictionary) -> int:
	var n := 0
	for a in (growth.get("points", {}) as Dictionary):
		n += int(growth["points"][a])
	return n


## Weighted XP the next point of an attribute that has grown `grown` points costs.
static func cost_of_next(grown: int) -> float:
	var s := system()
	if s == null:
		return INF
	var g: Dictionary = s.get("growth")
	return float(g["xpPerPoint"]) * (1.0 + float(g["costStep"]) * float(grown))


## Whether `attribute` can still gain a point under `attributes` and `growth` (the hard cap and the total cap).
static func can_grow(attribute: String, attributes: Dictionary, growth: Dictionary) -> bool:
	var s := system()
	if s == null:
		return false
	return int(attributes.get(attribute, base())) < hard_cap() \
			and total_points(growth) < int((s.get("growth") as Dictionary)["totalPointsCap"])


## Feed `xp` skill-category XP into the weighted attributes. Mutates `attributes` and `growth` in place and
## returns the attributes that gained a point (empty when nothing changed). An attribute that cannot grow banks
## nothing, so XP never waits behind a cap.
static func grow(attributes: Dictionary, growth: Dictionary, category: String, xp: float) -> Array:
	var gained: Array = []
	var s := system()
	if s == null or not is_finite(xp) or xp <= 0.0:
		return gained
	var rows: Dictionary = (s.get("growth") as Dictionary)["categories"]
	if not rows.has(category):
		return gained
	xp = minf(xp, MAX_GRANT_XP)
	var weights: Dictionary = rows[category]
	for a in ids():
		var w := float(weights.get(a, 0.0))
		if w <= 0.0 or not can_grow(a, attributes, growth):
			continue
		var bank := float(growth["xp"][a]) + xp * w
		var points: int = int(growth["points"][a])
		var advanced := false
		while can_grow(a, attributes, growth) and bank >= cost_of_next(points):
			bank -= cost_of_next(points)
			points += 1
			attributes[a] = int(attributes[a]) + 1
			growth["points"][a] = points
			advanced = true
		growth["xp"][a] = bank if can_grow(a, attributes, growth) else 0.0
		if advanced:
			gained.append(a)
	return gained
