extends "res://src/tests/test_support.gd"
## Phase 177 — attributes in the fabric: GameData exposes the attribute set, the derivation table and the
## growth table, base 10 reproduces the constants the game used before attributes, and every attribute and
## derived stat has catalog entries. Pure data checks; the runtime is Phase 178.

const PlayerRules := preload("res://src/core/player_rules.gd")
const GestureRules := preload("res://src/character/gesture_rules.gd")
const AttributeRules := preload("res://src/character/attribute_rules.gd")
const ATTRIBUTES := ["strength", "vitality", "resistance", "agility", "intelligence", "perception"]
## fabric/gameplay/skills/shared.js SKILL_CATEGORIES (skill resources load the enum as an index).
const SKILL_CATEGORIES := ["combat", "crafting", "magic", "exploration", "social", "survival"]


func register() -> void:
	_run_test("attributes: GameData exposes the six attributes, their bounds, the derivation and the growth table", _test_gamedata_tables)
	_run_test("attributes: every attribute feeds a derived stat and every skill category has a growth row", _test_table_coverage)
	_run_test("attributes: base 10 reproduces today's carry capacity, max HP, regeneration and every neutral factor", _test_base_reproduces_today)
	_run_test("attributes: the player starts at base in every attribute and has no fixed carry capacity", _test_player_defaults)
	_run_test("attributes: every attribute and derived stat has a name in every locale", _test_catalog_keys)
	_run_test("attributes: AttributeRules.stat equals the fabric formula at the minimum, base and maximum of every row", _test_rules_match_formula)
	_run_test("attributes: growth follows the cost table, has diminishing returns and stops at the caps", _test_growth)
	_run_test("attributes: sanitize bounds a hostile or malformed table", _test_sanitize)
	_run_test("attributes: a pre-178 save loads at base with the same carry capacity and max HP", _test_legacy_save)
	_run_test("attributes: the registry persists attributes and grows them from skill XP on the host only", _test_registry_growth)
	_run_test("attributes: derived stats feed carry capacity, max HP, damage, dodge, status rolls and research", _test_consumers)
	_run_test("attributes: a client packet carrying attribute values is refused and counted", _test_claim_refused)


func _system() -> Resource:
	return GameData.ATTRIBUTES.get("AttributeSystem", null)


## The fabric formula (fabric/gameplay/attributes.js `derive`), for a value of the row's attribute.
func _derive(row: Dictionary, value: int, base: int) -> float:
	var d := value - base
	var slope := float(row["perPointBelow"]) if d < 0 else float(row["perPoint"])
	return clampf(float(row["base"]) + slope * d, float(row["min"]), float(row["max"]))


func _test_gamedata_tables() -> void:
	var s := _system()
	assert_true(s != null, "GameData.ATTRIBUTES has the AttributeSystem")
	if s == null:
		return
	assert_eq(Array(s.get("attributes")), ATTRIBUTES, "the six attributes in display order")
	assert_eq(int(s.get("base")), 10, "attributes start at 10")
	assert_eq(int(s.get("creationMin")), 5, "creation allows 5 at the lowest")
	assert_eq(int(s.get("creationMax")), 18, "creation allows 18 at the highest")
	assert_eq(int(s.get("hardCap")), 30, "growth stops at 30")
	var table: Dictionary = s.get("derivation")
	assert_true(table.size() >= ATTRIBUTES.size(), "the derivation table has rows (%d)" % table.size())
	for id in table:
		var row: Dictionary = table[id]
		for k in ["attribute", "kind", "base", "perPoint", "perPointBelow", "min", "max"]:
			assert_true(row.has(k), "%s has %s" % [id, k])
		assert_true(float(row["min"]) < float(row["max"]), "%s has a clamp" % id)
		var b := int(s.get("base"))
		for v in [int(s.get("creationMin")), int(s.get("hardCap"))]:
			var raw: float = float(row["base"]) + (float(row["perPointBelow"]) if v < b else float(row["perPoint"])) * (v - b)
			assert_true(raw >= float(row["min"]) - 0.000001 and raw <= float(row["max"]) + 0.000001, "%s at %d stays inside its clamp" % [id, v])
	var growth: Dictionary = s.get("growth")
	assert_true(int(growth.get("xpPerPoint", 0)) > 0, "a point costs XP")
	assert_true(float(growth.get("costStep", 0.0)) > 0.0, "each point costs more than the last")
	assert_true(int(growth.get("totalPointsCap", 0)) > 0, "growth has a total cap")


func _test_table_coverage() -> void:
	var s := _system()
	if s == null:
		assert_true(false, "AttributeSystem exists")
		return
	var fed: Dictionary = {}
	for id in s.get("derivation"):
		var a := str((s.get("derivation") as Dictionary)[id]["attribute"])
		assert_true(ATTRIBUTES.has(a), "%s is fed by a known attribute (%s)" % [id, a])
		fed[a] = true
	for a in ATTRIBUTES:
		assert_true(fed.has(a), "%s feeds a derived stat" % a)
	var rows: Dictionary = (s.get("growth") as Dictionary)["categories"]
	for c in SKILL_CATEGORIES:
		assert_true(rows.has(c), "skill category %s has a growth row" % c)
		var sum := 0.0
		for a in (rows.get(c, {}) as Dictionary):
			assert_true(ATTRIBUTES.has(a), "%s grows a known attribute (%s)" % [c, a])
			sum += float(rows[c][a])
		assert_true(absf(sum - 1.0) < 0.000001, "%s weights sum to 1" % c)
	for skill in GameData.SKILLS:
		var cat := int((GameData.SKILLS[skill] as Resource).get("category"))
		assert_true(cat >= 0 and cat < SKILL_CATEGORIES.size(), "%s has a category with a growth row" % skill)


func _test_base_reproduces_today() -> void:
	var s := _system()
	if s == null:
		assert_true(false, "AttributeSystem exists")
		return
	var base := int(s.get("base"))
	var table: Dictionary = s.get("derivation")
	assert_eq(_derive(table["carryCapacityKg"], base, base), 40.0, "carry capacity is 40 kg at base")
	assert_eq(_derive(table["carryCapacityKg"], base, base), CarcassRules.base_capacity_kg(), "the carcass rules read that base")
	assert_eq(_derive(table["maxHp"], base, base), PlayerRules.MAX_HP, "max HP is PlayerRules.MAX_HP at base")
	assert_eq(_derive(table["hpRegenPerSecond"], base, base), GestureRules.BASE_HP_REGEN_PER_S, "HP regeneration is the gesture baseline at base")
	for id in table:
		var row: Dictionary = table[id]
		var kind := str(row["kind"])
		if kind == "factor":
			assert_eq(_derive(row, base, base), 1.0, "%s is 1 at base" % id)
		elif kind == "chance" or kind == "bonus":
			assert_eq(_derive(row, base, base), 0.0, "%s is 0 at base" % id)
		assert_true(_derive(row, int(s.get("hardCap")), base) != _derive(row, base, base), "%s changes at the hard cap" % id)


func _test_player_defaults() -> void:
	var pc: Resource = GameData.PLAYERS["PlayerCharacter"]
	var attrs = pc.get("attributes")
	assert_true(attrs is Dictionary, "PlayerCharacter has attributes")
	if attrs is Dictionary:
		for a in ATTRIBUTES:
			assert_eq(int(attrs.get(a, -1)), 10, "%s starts at base" % a)
	assert_true(pc.get("carryCapacityKg") == null, "carry capacity is derived, not a fixed player field")


func _test_catalog_keys() -> void:
	var cats: Dictionary = I18nScript.parse_csv("res://locale/ui.csv")["catalog"]
	var s := _system()
	var stats: Array = (s.get("derivation") as Dictionary).keys() if s != null else []
	assert_true(cats.has("en") and cats.has("pt_BR"), "en and pt_BR catalogs exist")
	for loc in cats:
		var cat: Dictionary = cats[loc]
		for a in ATTRIBUTES:
			for k in ["attr.%s.name" % a, "attr.%s.desc" % a]:
				assert_true(str(cat.get(k, "")).strip_edges() != "", "%s has %s" % [loc, k])
		for id in stats:
			assert_true(str(cat.get("stat." + str(id), "")).strip_edges() != "", "%s has stat.%s" % [loc, id])


## The fabric formula (see `_derive`) against `AttributeRules.stat` at creation min, base and hard cap, for every row.
func _test_rules_match_formula() -> void:
	var s := _system()
	var table: Dictionary = s.get("derivation")
	for id in table:
		var row: Dictionary = table[id]
		for v in [int(s.get("creationMin")), int(s.get("base")), int(s.get("creationMax")), int(s.get("hardCap"))]:
			var attrs := AttributeRules.defaults()
			attrs[str(row["attribute"])] = v
			assert_eq(AttributeRules.stat(str(id), attrs), _derive(row, v, int(s.get("base"))), "%s at %d" % [id, v])
	var base := AttributeRules.defaults()
	assert_eq(AttributeRules.stat("carryCapacityKg", base), 40.0, "base carry capacity")
	assert_eq(AttributeRules.stat("maxHp", base), PlayerRules.MAX_HP, "base max HP")
	assert_eq(AttributeRules.stat("hpRegenPerSecond", base), GestureRules.BASE_HP_REGEN_PER_S, "base regeneration")
	assert_eq(AttributeRules.stat("nonsense", base), 0.0, "an unknown stat reads 0")
	assert_eq(AttributeRules.all_stats(base).size(), (s.get("derivation") as Dictionary).size(), "all_stats lists every row")


func _test_growth() -> void:
	var s := _system()
	var g: Dictionary = s.get("growth")
	var per := float(g["xpPerPoint"])
	var attrs := AttributeRules.defaults()
	var gr := AttributeRules.empty_growth()
	assert_eq(AttributeRules.grow(attrs, gr, "social", per - 1.0), [], "just under the cost grows nothing")
	assert_eq(int(attrs["perception"]), 10, "perception unchanged")
	assert_eq(AttributeRules.grow(attrs, gr, "social", 1.0), ["perception"], "the cost buys a point (social is all Perception)")
	assert_eq(int(attrs["perception"]), 11, "perception 11")
	# The second point costs more: xpPerPoint * (1 + costStep).
	var second := AttributeRules.cost_of_next(1)
	assert_true(second > per, "diminishing returns: the second point costs more (%.0f > %.0f)" % [second, per])
	assert_eq(AttributeRules.grow(attrs, gr, "social", second - 1.0), [], "short of the second cost grows nothing")
	assert_eq(AttributeRules.grow(attrs, gr, "social", 1.0), ["perception"], "the second cost buys it")
	# Weighted split: combat feeds Strength and Agility half each.
	var a2 := AttributeRules.defaults()
	var g2 := AttributeRules.empty_growth()
	assert_eq(AttributeRules.grow(a2, g2, "combat", per * 2.0).size(), 2, "combat grows both of its attributes")
	assert_eq(int(a2["strength"]), 11, "strength +1")
	assert_eq(int(a2["agility"]), 11, "agility +1")
	assert_eq(AttributeRules.grow(a2, g2, "nonsense", per * 10.0), [], "an unknown category grows nothing")
	assert_eq(AttributeRules.grow(a2, g2, "combat", -5.0), [], "negative XP grows nothing")
	assert_eq(AttributeRules.grow(a2, g2, "combat", NAN), [], "NaN XP grows nothing")
	# The hard cap: Perception stops at 30.
	var a3 := AttributeRules.defaults()
	var g3 := AttributeRules.empty_growth()
	for _i in 100:
		AttributeRules.grow(a3, g3, "social", AttributeRules.MAX_GRANT_XP)
	assert_eq(int(a3["perception"]), int(s.get("hardCap")), "growth stops at the hard cap")
	assert_true(float(g3["xp"]["perception"]) == 0.0, "nothing banks behind a cap")
	# The total cap across all six.
	var a4 := AttributeRules.defaults()
	var g4 := AttributeRules.empty_growth()
	for _i in 400:
		for c in AttributeRules.SKILL_CATEGORIES:
			AttributeRules.grow(a4, g4, c, AttributeRules.MAX_GRANT_XP)
	assert_eq(AttributeRules.total_points(g4), int(g["totalPointsCap"]), "growth stops at the total points cap")
	var sum := 0
	for a in AttributeRules.ids():
		assert_true(int(a4[a]) <= int(s.get("hardCap")), "%s within the hard cap" % a)
		sum += int(a4[a]) - 10
	assert_eq(sum, int(g["totalPointsCap"]), "attribute values add up to the grown points")
	# Every skill resolves to a category with a growth row.
	assert_eq(AttributeRules.category_of_skill("Skinning"), "survival", "Skinning is a survival skill")
	assert_eq(AttributeRules.category_of_skill("Nope"), "", "an unknown skill has no category")


func _test_sanitize() -> void:
	var clean := AttributeRules.sanitize({ "strength": 99, "vitality": -4, "agility": "x", "perception": 14.0, "junk": 1, "resistance": NAN })
	assert_eq(int(clean["strength"]), AttributeRules.hard_cap(), "above the cap clamps to it")
	assert_eq(int(clean["vitality"]), AttributeRules.creation_min(), "below the floor clamps to it")
	assert_eq(int(clean["agility"]), 10, "a non-number reads as base")
	assert_eq(int(clean["perception"]), 14, "a valid value is kept")
	assert_eq(int(clean["resistance"]), 10, "NaN reads as base")
	assert_false(clean.has("junk"), "unknown keys are dropped")
	assert_eq(AttributeRules.sanitize("garbage"), AttributeRules.defaults(), "a non-dictionary is base")
	var gr := AttributeRules.sanitize_growth({ "points": { "strength": 5000, "vitality": -1 }, "xp": { "strength": INF } })
	assert_eq(int(gr["points"]["strength"]), AttributeRules.hard_cap(), "grown points clamp")
	assert_eq(int(gr["points"]["vitality"]), 0, "negative points clamp to 0")
	assert_eq(float(gr["xp"]["strength"]), 0.0, "non-finite banked XP reads 0")


func _test_legacy_save() -> void:
	var reg := PlayerRegistry.new()
	# A pre-178 payload: no attributes key at all.
	reg.apply_player_data("old", { "player_id": "old", "position": [0.0, 1.0, 0.0], "hp": 100.0, "skill_xp": { "Skinning": 10 } })
	assert_eq(reg.get_attributes("old"), AttributeRules.defaults(), "a legacy record reads base 10 everywhere")
	assert_eq(reg.stat_of("old", "carryCapacityKg"), CarcassRules.base_capacity_kg(), "the same carry capacity as before")
	assert_eq(CarcassRules.capacity_kg(0, reg.stat_of("old", "carryCapacityKg")), CarcassRules.capacity_kg(0), "capacity with the derived base is unchanged")
	assert_eq(reg.max_hp_of("old"), PlayerRules.MAX_HP, "the same max HP as before")
	assert_eq(reg.get_hp("old"), 100.0, "HP restored")
	assert_eq(reg.get_skill_xp("old", "Skinning"), 10, "other progression kept")
	# A hostile payload is clamped on the way in.
	reg.apply_player_data("odd", { "player_id": "odd", "attributes": { "strength": 999, "agility": -9 } })
	assert_eq(int(reg.get_attributes("odd")["strength"]), AttributeRules.hard_cap(), "a saved value past the cap clamps")
	assert_eq(int(reg.get_attributes("odd")["agility"]), AttributeRules.creation_min(), "a saved value under the floor clamps")
	reg.free()


func _test_registry_growth() -> void:
	var reg := PlayerRegistry.new()
	reg.ensure_player("p")
	var seen := []
	var on_sync := func(pid: String, attrs: Dictionary) -> void: seen.append([pid, attrs.duplicate()])
	GameBus.attributes_synced.connect(on_sync)
	var cost := int(float((_system().get("growth") as Dictionary)["xpPerPoint"]) * 2.0)   # survival: half Vitality, half Perception
	assert_eq(reg.grant_skill_xp("p", "Skinning", cost - 2), [], "not enough XP gains nothing")
	assert_true(seen.is_empty(), "and nothing is synced")
	assert_eq(reg.get_skill_xp("p", "Skinning"), cost - 2, "the skill still gained its XP")
	var gained := reg.grant_skill_xp("p", "Skinning", 2)
	assert_eq(gained.size(), 2, "vitality and perception gain a point")
	assert_eq(seen.size(), 1, "one sync")
	assert_eq(seen[0][0], "p", "for the player")
	assert_eq(int(seen[0][1]["vitality"]), 11, "carrying the new table")
	assert_eq(reg.max_hp_of("p"), AttributeRules.stat("maxHp", reg.get_attributes("p")), "max HP follows Vitality")
	assert_true(reg.max_hp_of("p") > PlayerRules.MAX_HP, "and exceeds the base 100")
	# Round trip through the save.
	var data := reg.get_player_data("p")
	var reg2 := PlayerRegistry.new()
	reg2.apply_player_data("p", data)
	assert_eq(reg2.get_attributes("p"), reg.get_attributes("p"), "attributes survive a save")
	assert_eq(reg2.get_record("p")["attribute_growth"], reg.get_record("p")["attribute_growth"], "so does the banked growth")
	# A client machine never grows anything.
	reg2.is_authoritative = false
	assert_eq(reg2.grant_skill_xp("p", "Skinning", 100000), [], "a non-authoritative registry refuses growth")
	assert_eq(reg2.get_attributes("p"), reg.get_attributes("p"), "and keeps the table")
	GameBus.attributes_synced.disconnect(on_sync)
	reg2.free()
	reg.free()


func _test_consumers() -> void:
	var reg := PlayerRegistry.new()
	reg.ensure_player("strong")
	reg.get_record("strong")["attributes"] = AttributeRules.sanitize({ "strength": 18, "vitality": 18, "resistance": 18, "agility": 18, "intelligence": 18, "perception": 18 })
	# Carry capacity: Strength raises it, and the carcass rules take the player's base.
	var cap: float = reg.stat_of("strong", "carryCapacityKg")
	assert_eq(cap, 56.0, "Strength 18 carries 56 kg")
	assert_eq(CarcassRules.capacity_kg(2, cap), cap + CarcassRules.capacity_kg(2) - CarcassRules.base_capacity_kg(), "the Skinning bonus stacks on the player's base")
	# Battle: damage reduction, dodge, status rolls.
	var b := BattleSlice.new()
	add_child(b)
	b.player_stat_fn = func(_id: String, stat_id: String) -> float: return reg.stat_of("strong", stat_id)
	assert_eq(b._player_stat("x", "damageReduction", 0.0), reg.stat_of("strong", "damageReduction"), "BattleSlice reads the hook")
	assert_true(b._player_stat("x", "damageReduction", 0.0) > 0.0, "Resistance reduces damage")
	var unwired := BattleSlice.new()
	assert_eq(unwired._player_stat("x", "damageReduction", 0.0), 0.0, "unwired, a stat is neutral")
	assert_eq(unwired._player_stat("x", "statusChanceFactor", 1.0), 1.0, "unwired, a factor is 1")
	unwired.free()
	b.free()
	# Status rolls scale: chance and duration.
	var st := StatusEffectsScript.new()
	var row := { "effect": "burn", "chance": 1.0 }
	st.table_override = { "burn": { "durationSeconds": 10.0, "stacks": false } }
	var full := st.rolled_effects([row], 1, "a", "t", 1.0)
	var none := st.rolled_effects([row], 1, "a", "t", 0.0)
	assert_eq(full.size(), 1, "a chance of 1 lands")
	assert_eq(none.size(), 0, "a chance factor of 0 never lands")
	assert_true(st.apply("t", "burn", 0.0, 0.5), "applies at half duration")
	assert_eq(float(st.active("t", 0.0)[0]["remaining"]), 5.0, "half the length")
	# Research gain: Intelligence scales a grant.
	reg.ensure_player("sharp")
	reg.get_record("sharp")["attributes"] = AttributeRules.sanitize({ "intelligence": 18 })
	assert_true(reg.stat_of("sharp", "researchGainFactor") > 1.0, "Intelligence raises research gain")
	reg.free()


const StatusEffectsScript := preload("res://src/battle/status_effects.gd")


func _test_claim_refused() -> void:
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	assert_eq(n.attributes_refused, 0, "nothing refused yet")
	n._route_c2h(7, { "type": "attributes_intent", "attributes": { "strength": 30 } })
	assert_eq(n.attributes_refused, 1, "a dedicated attribute packet is refused and counted")
	n._route_c2h(7, { "type": "player_moved", "attributes": { "strength": 30 }, "position": [0, 0, 0] })
	assert_eq(n.attributes_refused, 2, "so is one smuggled beside another type")
	n._route_c2h(7, { "type": "player_moved", "attribute_growth": { "xp": { "strength": 1.0e9 } } })
	assert_eq(n.attributes_refused, 3, "and a growth claim")
	n.free()
