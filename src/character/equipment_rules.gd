extends RefCounted
## Pure equipment rules (ROADMAP Phase 47): which slots the fabric defines, whether
## an item fits a slot, and the stat totals a worn set adds up to.
##
## Every number is a fabric field summed here (`defense` on the equippable item);
## nothing in this file authors a stat. Static and headless-testable, so the host's
## player registry can validate a peer's claimed set without a CharacterSlice.

const GameDataReader := preload("res://src/core/game_data_reader.gd")

## Fabric fields summed into the Character window's totals. Each is read with
## `GameDataReader.int_field`, so an item without the field contributes zero.
const SUMMED_FIELDS: Array = ["defense"]


## The slot an item equips into, or "" when the key is unknown / not equippable.
## `items` is the item table to read; pass `GameData.ITEMS` explicitly (an empty table
## is an empty fabric, not a request for the default).
static func slot_of(item_key: String, items: Dictionary) -> String:
	var res: Resource = items.get(item_key, null)
	if res == null:
		return ""
	return GameDataReader.str_field(res, "equipmentSlot", "")


## Every distinct `equipmentSlot` the fabric defines, in a stable (sorted) order.
## Computed once per item table and cached; the cache is keyed by the table instance,
## so a different table (a test's) is never answered from the fabric's.
static var _slots_cache: Array = []
static var _slots_cache_table: Dictionary = {}
static var _slots_cache_valid: bool = false

static func slots(items: Dictionary) -> Array:
	if _slots_cache_valid and is_same(_slots_cache_table, items):
		return _slots_cache.duplicate()
	var seen: Dictionary = {}
	for key in items:
		var slot := slot_of(str(key), items)
		if slot != "":
			seen[slot] = true
	var out: Array = seen.keys()
	out.sort()
	_slots_cache = out
	_slots_cache_table = items
	_slots_cache_valid = true
	return out.duplicate()


## Keep only entries of `claimed` ({slot: item_key}) whose item exists and fits that
## slot. A claim is evidence about nothing until it passes this: unknown slots,
## unknown items and items in the wrong slot are dropped.
static func sanitize(claimed: Variant, items: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if not (claimed is Dictionary):
		return out
	for slot in claimed:
		var item_key := str(claimed[slot])
		if item_key != "" and slot_of(item_key, items) == str(slot):
			out[str(slot)] = item_key
	return out


## Sum the fabric values of a worn set. An empty set reports every field as zero.
static func totals(worn: Dictionary, items: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for field in SUMMED_FIELDS:
		out[field] = 0
	for slot in worn:
		var res: Resource = items.get(str(worn[slot]), null)
		if res == null:
			continue
		for field in SUMMED_FIELDS:
			out[field] = int(out[field]) + GameDataReader.int_field(res, field, 0)
	return out


## Whether the MainHand holds something (the fabric's bare-hands rule reads this).
static func hands_free(worn: Dictionary) -> bool:
	return str(worn.get("MainHand", "")) == ""

## The equip actions that turn worn set `from` into `to`: one { slot, item } per slot whose
## item differs, `item` "" for a slot that was emptied. Sorted by slot so the order is stable.
static func diff_actions(from: Dictionary, to: Dictionary) -> Array:
	var all_slots: Array = []
	for slot in from:
		if not all_slots.has(slot):
			all_slots.append(slot)
	for slot in to:
		if not all_slots.has(slot):
			all_slots.append(slot)
	all_slots.sort()
	var out: Array = []
	for slot in all_slots:
		var was := str(from.get(slot, ""))
		var now := str(to.get(slot, ""))
		if was != now:
			out.append({ "slot": str(slot), "item": now })
	return out


# ─── Phase 296 — work and combat by trait ─────────────────────────────────────────────────────────────────────
## What a held item can do follows from its category and traits by the fabric's `Equipment` world system (Phase 295):
## `workTraits` says which category and traits each work (fell, mine, dig, build, pickLock, dissect, cutBone) needs,
## `materialTraits` raises the traits of the item's working part, and `categories` sets the combat multiplier and the
## attack chain. Nothing here reads a tool type. A "spec" is { category, traits, material } (what `spec_of` builds
## from an item), so the rules can be asked about an item that does not exist (tests, previews).

## The parts of a shape whose material is the item's working material (the same order as the fabric's).
const WORKING_PARTS: Array = ["head", "blade", "pin", "tip", "limb", "face"]

static func equipment_table() -> Dictionary:
	var res: Resource = GameData.WORLD_SYSTEMS.get("Equipment", null)
	if res == null:
		return {}
	var out: Dictionary = {}
	for k in ["traits", "categories", "materialTraits", "workTraits", "harvestWorks", "damageTypes", "unarmed", "creatureDamageShares"]:
		out[k] = GameDataReader.json_field(res, k, {} if k != "damageTypes" else [])
	out["combatScale"] = GameDataReader.float_field(res, "combatScale", 1.0)
	return out

static func _table_dict(d: Dictionary, key: String) -> Dictionary:
	var v: Variant = d.get(key, {})
	return v if v is Dictionary else {}

## { category, traits, material } of an item key ({} when the item is not equipment).
static func spec_of(item_key: String, items: Dictionary = {}) -> Dictionary:
	var table: Dictionary = items if not items.is_empty() else GameData.ITEMS
	var res: Resource = table.get(item_key, null)
	if res == null:
		return {}
	var cat := GameDataReader.str_field(res, "equipmentCategory", "")
	if cat == "":
		return {}
	var traits: Variant = GameDataReader.json_field(res, "traits", {})
	var shape: Variant = GameDataReader.json_field(res, "shape", {})
	var parts: Dictionary = (shape as Dictionary).get("parts", {}) if shape is Dictionary else {}
	var material := ""
	for p in WORKING_PARTS:
		if str(parts.get(p, "")) != "":
			material = str(parts[p])
			break
	return { "category": cat, "traits": traits if traits is Dictionary else {}, "material": material }

## The category of an item ("" when it is not equipment).
static func category_of(item_key: String) -> String:
	return str(spec_of(item_key).get("category", ""))

static func _grade_index(trait_id: String, grade: Variant, d: Dictionary) -> int:
	var t: Variant = _table_dict(d, "traits").get(trait_id, {})
	var grades: Variant = (t as Dictionary).get("grades", null) if t is Dictionary else null
	if not (grades is Dictionary):
		return 0
	return (grades as Dictionary).keys().find(str(grade))

## A spec's traits after its material raises or adds: { <Trait>: { strength, grade? } }.
static func effective_traits(spec: Dictionary, d: Dictionary = {}) -> Dictionary:
	var t: Dictionary = d if not d.is_empty() else equipment_table()
	var out: Dictionary = (spec.get("traits", {}) as Dictionary).duplicate(true)
	var m: Variant = _table_dict(t, "materialTraits").get(str(spec.get("material", "")), {})
	if m is Dictionary:
		var raise: Variant = (m as Dictionary).get("raise", {})
		if raise is Dictionary:
			for tr in raise:
				if out.has(tr):
					var row: Dictionary = (out[tr] as Dictionary).duplicate()
					row["strength"] = snappedf(float(row.get("strength", 0.0)) + float(raise[tr]), 0.001)
					out[tr] = row
		var add: Variant = (m as Dictionary).get("add", {})
		if add is Dictionary:
			for tr in add:
				if not out.has(tr):
					out[tr] = (add[tr] as Dictionary).duplicate()
	return out

static func _way_matches(way: Dictionary, spec: Dictionary, traits: Dictionary, d: Dictionary) -> bool:
	if way.has("category") and str(way["category"]) != str(spec.get("category", "")):
		return false
	var need: Dictionary = way.get("traits", {})
	for tr in need:
		if not traits.has(tr):
			return false
		var have: Dictionary = traits[tr]
		if not (float(have.get("strength", 0.0)) > 0.0):
			return false
		var want: Dictionary = need[tr] if need[tr] is Dictionary else {}
		if want.has("grade") and _grade_index(str(tr), have.get("grade", ""), d) < _grade_index(str(tr), want["grade"], d):
			return false
		if way.has("minStrength") and float(have.get("strength", 0.0)) < float(way["minStrength"]):
			return false
	return true

## The speed a spec does `work` at (1.0 = the baseline item), or 0 when it matches no way of the work.
static func spec_work_speed(spec: Dictionary, work: String, d: Dictionary = {}) -> float:
	var t: Dictionary = d if not d.is_empty() else equipment_table()
	var rule: Variant = _table_dict(t, "workTraits").get(work, null)
	if not (rule is Dictionary) or spec.is_empty():
		return 0.0
	var traits := effective_traits(spec, t)
	var best := 0.0
	for way in (rule as Dictionary).get("ways", []):
		if not (way is Dictionary) or not _way_matches(way, spec, traits, t):
			continue
		var need: Dictionary = (way as Dictionary).get("traits", {})
		var weakest := 1.0
		if not need.is_empty():
			weakest = INF
			for tr in need:
				weakest = minf(weakest, float((traits[tr] as Dictionary).get("strength", 0.0)))
		best = maxf(best, snappedf(float(way.get("speed", 0.0)) * weakest, 0.001))
	return best

## Whether item `item_key` can do `work` (fell, mine, dig, build, pickLock, dissect, cutBone).
static func can_do(item_key: String, work: String) -> bool:
	return work_speed(item_key, work) > 0.0

## The speed item `item_key` does `work` at, or 0 when it cannot.
static func work_speed(item_key: String, work: String) -> float:
	return spec_work_speed(spec_of(item_key), work)

## Whether bare hands (and an item matching no way) can do `work` at all, at WorkTimes.bareHandsSpeed.
static func bare_hands_can(work: String) -> bool:
	var rule: Variant = _table_dict(equipment_table(), "workTraits").get(work, {})
	return bool((rule as Dictionary).get("bareHands", false)) if rule is Dictionary else false

## Every work an item can do, in the fabric's order: [work, ...].
static func works_of(item_key: String) -> Array:
	var out: Array = []
	var spec := spec_of(item_key)
	if spec.is_empty():
		return out
	var t := equipment_table()
	for w in _table_dict(t, "workTraits"):
		if spec_work_speed(spec, str(w), t) > 0.0:
			out.append(str(w))
	return out

## The work a harvest entry's tool category stands for (`Equipment.harvestWorks`: knife → dissect, bonetool → cutBone).
static func harvest_work(tool_category: String) -> String:
	return str(_table_dict(equipment_table(), "harvestWorks").get(tool_category, ""))

## Combat damage per damage type of a spec: the category's multiplier × Σ trait strength × (grade's or trait's) damage.
static func spec_combat_damage(spec: Dictionary, d: Dictionary = {}) -> Dictionary:
	var t: Dictionary = d if not d.is_empty() else equipment_table()
	var out: Dictionary = {}
	var cat: Variant = _table_dict(t, "categories").get(str(spec.get("category", "")), null)
	if not (cat is Dictionary):
		return out
	var mult := float((cat as Dictionary).get("combatMultiplier", 1.0))
	var traits := effective_traits(spec, t)
	for tr in traits:
		var def: Variant = _table_dict(t, "traits").get(tr, null)
		if not (def is Dictionary):
			continue
		var per := float((def as Dictionary).get("damage", 0.0))
		var grades: Variant = (def as Dictionary).get("grades", null)
		if grades is Dictionary:
			per = float(((grades as Dictionary).get(str((traits[tr] as Dictionary).get("grade", "")), {}) as Dictionary).get("damage", 0.0))
		var dt := str((def as Dictionary).get("damageType", ""))
		out[dt] = snappedf(float(out.get(dt, 0.0)) + mult * float((traits[tr] as Dictionary).get("strength", 0.0)) * per, 0.001)
	return out

static func combat_damage(item_key: String) -> Dictionary:
	return spec_combat_damage(spec_of(item_key))

## The Phase 287 attack chain an item swings with: its category's `clipFamily` ("one_hand" for a held item that is not
## equipment, "unarmed" for an empty hand).
static func clip_family(item_key: String, items: Dictionary = {}) -> String:
	if item_key == "":
		return "unarmed"
	var cat: Variant = _table_dict(equipment_table(), "categories").get(str(spec_of(item_key, items).get("category", "")), null)
	return str((cat as Dictionary).get("clipFamily", "one_hand")) if cat is Dictionary else "one_hand"

## Phase 296 — what a player's hit with `item_key` ("" = empty hands) deals on the host: { total, shares }, `total`
## the item's combatDamage × `Equipment.combatScale` and `shares` its split by damage type (summing to 1). Empty hands
## and a held item that is not equipment deal `Equipment.unarmed`.
static func player_hit(item_key: String) -> Dictionary:
	var t := equipment_table()
	var by_type: Dictionary = {}
	var spec := spec_of(item_key) if item_key != "" else {}
	if not spec.is_empty():
		var scale := float(t.get("combatScale", 1.0))
		var dmg := spec_combat_damage(spec, t)
		for dt in dmg:
			by_type[dt] = float(dmg[dt]) * scale
	if _sum(by_type) <= 0.0:
		var u: Variant = t.get("unarmed", {})
		by_type = (u as Dictionary).duplicate() if u is Dictionary else {}
	return _profile(by_type)

## Phase 296 — a creature's hit of `base_damage`, split by `Equipment.creatureDamageShares`.
static func creature_hit(base_damage: float) -> Dictionary:
	var shares: Variant = equipment_table().get("creatureDamageShares", {})
	var by_type: Dictionary = {}
	if shares is Dictionary:
		for dt in shares:
			by_type[dt] = base_damage * float(shares[dt])
	var p := _profile(by_type)
	p["total"] = base_damage
	return p

static func _sum(d: Dictionary) -> float:
	var total := 0.0
	for k in d:
		total += float(d[k])
	return total

static func _profile(by_type: Dictionary) -> Dictionary:
	var total := _sum(by_type)
	var shares: Dictionary = {}
	if total > 0.0:
		for dt in by_type:
			shares[dt] = float(by_type[dt]) / total
	return { "total": total, "shares": shares }

## The factor a hit of `shares` keeps against `protection` ({ <type>: share taken off }): Σ share × (1 − protection).
## 1.0 when the hit has no typed shares (nothing for armour to work on).
static func armour_factor(shares: Dictionary, protection: Dictionary) -> float:
	if shares.is_empty():
		return 1.0
	var keep := 0.0
	for dt in shares:
		keep += float(shares[dt]) * (1.0 - clampf(float(protection.get(dt, 0.0)), 0.0, 0.95))
	return keep

## Share of each damage type a worn set takes off a hit: per type, 1 − Π(1 − piece share), capped below 1.
static func protection(worn: Dictionary, items: Dictionary) -> Dictionary:
	var keep: Dictionary = {}
	for slot in worn:
		var res: Resource = items.get(str(worn[slot]), null)
		if res == null:
			continue
		var p: Variant = GameDataReader.json_field(res, "protection", {})
		if not (p is Dictionary):
			continue
		for dt in p:
			var share := clampf(float(p[dt]), 0.0, 0.95)
			keep[dt] = float(keep.get(dt, 1.0)) * (1.0 - share)
	var out: Dictionary = {}
	for dt in keep:
		out[dt] = minf(0.95, snappedf(1.0 - float(keep[dt]), 0.001))
	return out
