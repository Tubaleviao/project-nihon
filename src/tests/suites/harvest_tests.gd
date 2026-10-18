extends "res://src/tests/test_support.gd"
## Phase 160 — harvesting in the fabric: harvest tables with tool and skill, the harvest tools, the Skinning
## tables and the carcass and carry data. Pure data checks; the runtime is Phase 161.

## Items each creature dropped before Phase 160 (the old drop tables); a harvest table must keep them all.
const OLD_DROPS := {
	"ForestBoar": ["raw_boar_meat", "boar_hide", "boar_tusk"],
	"GraywolfPack": ["wolf_pelt", "wolf_fang", "alpha_wolf_fang"],
	"SteppeBison": ["bison_meat", "bison_hide", "bison_bone", "bison_horn"],
	"RidgeHawk": ["hawk_feather", "hawk_talon"],
	"LavaSlug": ["slug_shell_shard", "superheated_slime_vial", "lava_core_organ"],
	"CinderGargoyle": ["gargoyle_wing_fragment", "petrified_binding_stone", "gargoyle_crest"],
	"GlimmerFox": ["glimmer_pelt", "luminescent_reagent"],
	"VeilStalker": ["veilstalker_venom_sac", "shadow_phase_membrane", "crystallised_phase_shard"],
	"VoidSerpent": ["void_scale", "void_serpent_fang", "phase_locked_core"],
	"RiftWarden": ["rift_shard", "void_core_crystal", "warden_sigil"],
}
const TOOLS := ["knife", "bonetool", "none"]
const QUALITIES := ["poor", "common", "fine", "prime"]
const CARRY_RULES := ["carry", "drag", "immovable"]


func register() -> void:
	_run_test("harvest: every creature lists its harvest entries with a tool and a skill and keeps its old items", _test_creature_tables)
	_run_test("harvest: every entry's tool category is provided by an item and its skill exists", _test_tools_provided)
	_run_test("harvest: SkinningKnife and BoneSaw exist, are craftable and are unlocked by research", _test_harvest_tools)
	_run_test("harvest: the Skinning yield, chance, quality and XP tables cover every level and never fall", _test_skinning_tables)
	_run_test("harvest: every creature has a carcass mass, a corpse time and a carry rule that fits the capacity", _test_carcass_data)
	_run_test("harvest: the carry rules and the player's capacity come from the fabric", _test_carry_rules)


func _drops(creature: String) -> Array:
	var raw = GameData.CREATURES[creature].get("drops")
	return raw if raw is Array else []


func _test_creature_tables() -> void:
	for creature: String in OLD_DROPS:
		assert_true(GameData.CREATURES.has(creature), "%s is a creature" % creature)
		var items: Array = []
		for e: Dictionary in _drops(creature):
			items.append(e["item"])
			assert_true(String(e["tool"]) in TOOLS, "%s %s names a known tool" % [creature, e["item"]])
			assert_eq(String(e["skill"]), "Skinning", "%s %s is scaled by Skinning" % [creature, e["item"]])
		for item: String in OLD_DROPS[creature]:
			assert_true(items.has(item), "%s keeps %s" % [creature, item])
	for creature: String in GameData.CREATURES:
		assert_true(OLD_DROPS.has(creature), "%s is covered by the old-drops fixture" % creature)


func _test_tools_provided() -> void:
	var provided := {"none": true}
	for id: String in GameData.ITEMS:
		var tool = GameData.ITEMS[id].get("harvestTool")
		if tool != null:
			provided[String(tool)] = true
			var eff := float(GameData.ITEMS[id].get("efficiency"))
			assert_true(eff > 0.0 and eff <= 1.0, "%s efficiency is in (0, 1]" % id)
	for creature: String in GameData.CREATURES:
		for e: Dictionary in _drops(creature):
			assert_true(provided.has(String(e["tool"])), "%s %s: some item provides %s" % [creature, e["item"], e["tool"]])
			assert_true(GameData.SKILLS.has(String(e["skill"])), "%s %s: skill %s exists" % [creature, e["item"], e["skill"]])
	assert_eq(str(GameData.ITEMS["CarpenterAxe"].get("harvestTool")), "bonetool", "an axe also works bone")
	assert_true(float(GameData.ITEMS["CarpenterAxe"].get("efficiency")) < 1.0, "as a poor bone tool")


func _test_harvest_tools() -> void:
	assert_eq(str(GameData.ITEMS["SkinningKnife"].get("harvestTool")), "knife", "SkinningKnife is a knife")
	assert_eq(str(GameData.ITEMS["BoneSaw"].get("harvestTool")), "bonetool", "BoneSaw is a bone tool")
	var tech: Array = GameData.TECHNOLOGIES["TechBasicSmithing"].tech["unlocks"]
	for pair in [["SkinningKnife", "RecipeSkinningKnife"], ["BoneSaw", "RecipeBoneSaw"]]:
		var recipe: Dictionary = GameData.RECIPES[pair[1]].recipe
		var outs: Array = recipe["outputs"].map(func(o): return o["item"])
		assert_true(outs.has(pair[0]), "%s crafts %s" % [pair[1], pair[0]])
		for input: Dictionary in recipe["inputs"]:
			assert_true(GameData.ITEMS.has(input["item"]), "%s input %s is an item" % [pair[1], input["item"]])
		assert_true(tech.has(pair[1]), "%s is unlocked by TechBasicSmithing" % pair[1])


func _test_skinning_tables() -> void:
	var s = GameData.SKILLS["Skinning"]
	var cap := int(s.get("levelCap"))
	assert_true(cap >= 1, "Skinning has levels")
	var yield_c: Array = s.get("yieldCurve")
	var chance_c: Array = s.get("chanceCurve")
	var quality_c: Array = s.get("qualityCurve")
	var xp_c: Array = s.get("xpToLevel")
	for table: Array in [yield_c, chance_c, quality_c, xp_c]:
		assert_eq(table.size(), cap + 1, "a table covers every level 0..%d" % cap)
	assert_eq(float(yield_c[0]), 0.0, "level 0 gives the table's minimum")
	assert_eq(float(yield_c[cap]), 1.0, "the cap gives the table's maximum")
	assert_eq(String(quality_c[0]), QUALITIES[0], "level 0 gives the lowest grade")
	assert_eq(String(quality_c[cap]), QUALITIES[QUALITIES.size() - 1], "the cap gives the highest grade")
	for l in range(1, cap + 1):
		assert_true(float(yield_c[l]) >= float(yield_c[l - 1]), "yield never falls at level %d" % l)
		assert_true(float(chance_c[l]) >= float(chance_c[l - 1]), "chance never falls at level %d" % l)
		assert_true(QUALITIES.has(String(quality_c[l])), "level %d has a known grade" % l)
		assert_true(QUALITIES.find(String(quality_c[l])) >= QUALITIES.find(String(quality_c[l - 1])), "quality never falls at level %d" % l)
		assert_true(float(xp_c[l]) > float(xp_c[l - 1]), "XP to level rises at level %d" % l)
	assert_true(int(s.get("xpPerHarvest")) > 0, "a harvest grants XP")


func _test_carcass_data() -> void:
	var rules = GameData.HARVESTS["HarvestRules"]
	var capacity := float(GameData.PLAYERS["PlayerCharacter"].get("carryCapacityKg"))
	assert_true(capacity > 0.0, "the player has a base carry capacity")
	for creature: String in GameData.CREATURES:
		var c = GameData.CREATURES[creature]
		var mass := float(c.get("carcassMassKg"))
		assert_true(mass > 0.0, "%s has a carcass mass" % creature)
		assert_true(int(c.get("corpseSeconds")) > 0, "%s has a corpse time" % creature)
		var rule_index := int(c.get("carryRule"))  # enum fields load as the value's index
		assert_true(rule_index >= 0 and rule_index < CARRY_RULES.size(), "%s has a carry rule" % creature)
		var rule: String = CARRY_RULES[rule_index]
		if rule == "carry":
			assert_true(mass <= capacity, "%s fits the base capacity" % creature)
		elif rule == "drag":
			assert_true(mass > capacity and mass <= capacity * float(rules.get("dragCapacityFactor")), "%s is draggable but not carriable" % creature)
	assert_eq(CARRY_RULES[int(GameData.CREATURES["SteppeBison"].get("carryRule"))], "immovable", "a bison cannot be moved")


func _test_carry_rules() -> void:
	var r = GameData.HARVESTS["HarvestRules"]
	assert_true(float(r.get("carrySlowAboveFraction")) == 0.5, "carrying over half the capacity slows walking")
	assert_true(float(r.get("carrySlowSpeedMultiplier")) < 1.0, "the slow-down is below full speed")
	assert_true(float(r.get("dragSpeedMultiplier")) < float(r.get("carrySlowSpeedMultiplier")), "dragging is slower than carrying")
	assert_true(int(r.get("maxCarcassesPerRegion")) >= 1, "a region keeps bodies")
