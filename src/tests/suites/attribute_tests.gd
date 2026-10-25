extends "res://src/tests/test_support.gd"
## Phase 177 — attributes in the fabric: GameData exposes the attribute set, the derivation table and the
## growth table, base 10 reproduces the constants the game used before attributes, and every attribute and
## derived stat has catalog entries. Pure data checks; the runtime is Phase 178.

const PlayerRules := preload("res://src/core/player_rules.gd")
const GestureRules := preload("res://src/character/gesture_rules.gd")
const ATTRIBUTES := ["strength", "vitality", "resistance", "agility", "intelligence", "perception"]
## fabric/gameplay/skills/shared.js SKILL_CATEGORIES (skill resources load the enum as an index).
const SKILL_CATEGORIES := ["combat", "crafting", "magic", "exploration", "social", "survival"]


func register() -> void:
	_run_test("attributes: GameData exposes the six attributes, their bounds, the derivation and the growth table", _test_gamedata_tables)
	_run_test("attributes: every attribute feeds a derived stat and every skill category has a growth row", _test_table_coverage)
	_run_test("attributes: base 10 reproduces today's carry capacity, max HP, regeneration and every neutral factor", _test_base_reproduces_today)
	_run_test("attributes: the player starts at base in every attribute and has no fixed carry capacity", _test_player_defaults)
	_run_test("attributes: every attribute and derived stat has a name in every locale", _test_catalog_keys)


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
