extends "res://src/tests/test_support.gd"
## Phase 296 — work and combat by trait: what a held item can do follows from its category and traits by the fabric's
## `Equipment` tables, read through `EquipmentRules`; nothing in `src/` reads a tool type; a hit deals its item's trait
## damage by type and armour takes its share off each type; the tooltip names category, traits and works in both locales.

const WorkTime := preload("res://src/core/work_time.gd")
const I18n := preload("res://src/core/i18n.gd")
const ChestRules := preload("res://src/world/chest_rules.gd")
const CraftCatalog := preload("res://src/crafting/craft_catalog.gd")
const ComboChain := preload("res://src/battle/combo_chain.gd")
const RigTree := preload("res://src/character/rig_tree.gd")

## What each former tool did before Phase 295, with its speed (a save from then must still do it).
const FORMER_JOBS := {
	"StoneAxe": { "fell": 0.6 }, "CarpenterAxe": { "fell": 1.0, "cutBone": 0.5 },
	"StonePick": { "mine": 0.6 }, "FerritePick": { "mine": 1.0 }, "VeilsteelPick": { "mine": 1.5 },
	"StoneShovel": { "dig": 1.2 }, "StoneHammer": { "build": 1.0 }, "Lockpick": { "pickLock": 1.0 },
	"StoneKnife": { "dissect": 0.5 }, "SkinningKnife": { "dissect": 1.0 }, "BoneSaw": { "cutBone": 1.0 },
}

func register() -> void:
	_run_test("equipment traits: no file in src/ reads toolType or harvestTool", _test_no_tool_type_reads)
	_run_test("equipment traits: any axe fells; Sharp without Blunt (heavy) does not", _test_fell_rule)
	_run_test("equipment traits: a pick mines; Piercing without Blunt does not", _test_mine_rule)
	_run_test("equipment traits: any knife dissects; a sword does not unless it is a knife", _test_dissect_rule)
	_run_test("equipment traits: held-item lookups, work times and harvest go by work", _test_lookups_by_work)
	_run_test("equipment traits: the attack chain comes from the category", _test_clip_family)
	_run_test("equipment traits (host): a pick hits for less than any other category of its tier, blunt and piercing", _test_pick_weakest)
	_run_test("equipment traits (host): a held item's traits set the hit; armour with blunt protection cuts the blunt share", _test_host_damage_and_armour)
	_run_test("equipment traits: an inventory saved before the phase loads able to do what it did", _test_old_save)
	_run_test("equipment traits: tooltip lines in en and pt_BR; no UI string calls anything a tool", _test_tooltip_and_wording)

func _test_no_tool_type_reads() -> void:
	var hits: Array = []
	var stack: Array = ["res://src"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		if dir == "res://src/tests":
			continue
		for sub in DirAccess.get_directories_at(dir):
			stack.append(dir.path_join(sub))
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var text := FileAccess.get_file_as_string(dir.path_join(f))
			for word in ["toolType", "harvestTool"]:
				if text.contains(word):
					hits.append("%s: %s" % [dir.path_join(f), word])
	assert_eq(hits, [], "no runtime script names toolType or harvestTool")

func _test_fell_rule() -> void:
	var axes := 0
	for item in GameData.ITEMS:
		if EquipmentRules.category_of(str(item)) == "axe":
			axes += 1
			assert_true(EquipmentRules.can_do(str(item), "fell"), "%s (an axe) fells" % item)
	assert_true(axes >= 2, "the stone and carpenter axes are axes")
	var sharp_light := { "category": "sword", "traits": { "Sharp": { "strength": 1.0 }, "Blunt": { "strength": 1.0, "grade": "light" } }, "material": "" }
	assert_eq(EquipmentRules.spec_work_speed(sharp_light, "fell"), 0.0, "Sharp with light Blunt fells nothing")
	var sharp_only := { "category": "knife", "traits": { "Sharp": { "strength": 1.0 } }, "material": "" }
	assert_eq(EquipmentRules.spec_work_speed(sharp_only, "fell"), 0.0, "Sharp alone fells nothing")
	assert_true(EquipmentRules.bare_hands_can("fell"), "and it chops at bare-hands speed instead")
	assert_eq(WorkTime.speed("chop", "FerriteShortSword"), WorkTime.bare_hands_speed(), "a sword chops like bare hands")

func _test_mine_rule() -> void:
	for item in GameData.ITEMS:
		if EquipmentRules.category_of(str(item)) == "pick":
			assert_true(EquipmentRules.can_do(str(item), "mine"), "%s (a pick) mines" % item)
	var pierce_only := { "category": "spear", "traits": { "Piercing": { "strength": 1.0 } }, "material": "" }
	assert_eq(EquipmentRules.spec_work_speed(pierce_only, "mine"), 0.0, "Piercing without Blunt mines nothing")
	assert_false(EquipmentRules.can_do("SkinningKnife", "mine"), "a knife (Sharp, Piercing) does not mine")
	assert_eq(EquipmentRules.work_speed("VeilsteelPick", "mine"), 1.5, "veilsteel raises the pick to 1.5")

func _test_dissect_rule() -> void:
	for item in GameData.ITEMS:
		if EquipmentRules.category_of(str(item)) == "knife":
			assert_true(EquipmentRules.can_do(str(item), "dissect"), "%s (a knife) dissects" % item)
	assert_false(EquipmentRules.can_do("FerriteShortSword", "dissect"), "a sword does not dissect")
	assert_false(EquipmentRules.can_do("VeilsteelLongsword", "dissect"), "nor a greatsword")
	var sword_knife := { "category": "knife", "traits": { "Sharp": { "strength": 1.0 }, "Piercing": { "strength": 1.0 } }, "material": "" }
	assert_true(EquipmentRules.spec_work_speed(sword_knife, "dissect") > 0.0, "the same blade in the knife category does")
	assert_eq(EquipmentRules.harvest_work("knife"), "dissect", "knife entries need dissect")
	assert_eq(EquipmentRules.harvest_work("bonetool"), "cutBone", "bone entries need cutBone")

func _test_lookups_by_work() -> void:
	var inv := InventorySlice.new()
	add_child(inv)
	inv.add_item("FerriteShortSword", 1)
	assert_eq(inv.find_for_work("fell"), "", "a sword is not used to fell")
	inv.add_item("StoneAxe", 1)
	assert_eq(inv.find_for_work("fell"), "StoneAxe", "the stone axe fells")
	inv.add_item("CarpenterAxe", 1)
	assert_eq(inv.find_for_work("fell"), "CarpenterAxe", "the faster axe wins")
	assert_eq(inv.find_for_work("cutBone"), "CarpenterAxe", "the forged axe also cuts bone")
	inv.add_item("BoneSaw", 1)
	assert_eq(inv.find_for_work("cutBone"), "BoneSaw", "the saw cuts bone better")
	inv.add_item("Lockpick", 1)
	assert_eq(inv.find_for_work(ChestRules.lock_work()), "Lockpick", "a lock is picked with the lockpick")
	assert_eq(WorkTime.action_work("chop"), "fell", "chopping is the fell work")
	assert_eq(WorkTime.speed("chop", "CarpenterAxe"), 1.0, "the carpenter axe chops at 1.0")
	assert_eq(WorkTime.held_tool(inv, "chop"), "CarpenterAxe", "and is the one held for it")
	assert_eq(CarcassRules.tools_of("StoneKnife"), [{ "tool": "knife", "efficiency": 0.5 }], "the stone knife skins at 0.5")
	assert_eq(CarcassRules.tools_of("StoneAxe"), [], "the stone axe is no bone saw")
	assert_eq(CraftCatalog.category("RecipeStoneAxe"), "work_gear", "an axe is filed as work gear")
	assert_eq(CraftCatalog.category("RecipeFerriteShortSword"), "weapons", "a sword as a weapon")
	inv.free()

func _test_clip_family() -> void:
	assert_eq(ComboChain.weapon_class("", GameData.ITEMS), "unarmed", "empty hands punch")
	assert_eq(ComboChain.weapon_class("StonePick", GameData.ITEMS), "tool", "a pick swings the work chain")
	assert_eq(ComboChain.weapon_class("FerriteShortSword", GameData.ITEMS), "one_hand", "a sword one-handed")
	assert_eq(ComboChain.weapon_class("VeilsteelLongsword", GameData.ITEMS), "two_hand", "a greatsword with both hands")
	assert_eq(ComboChain.weapon_class("SkinningKnife", GameData.ITEMS), "one_hand", "a knife is a one-handed weapon")
	assert_eq(ComboChain.weapon_class("FerriteIngot", GameData.ITEMS), "one_hand", "a held non-equipment item swings one-handed")
	assert_eq(RigTree.attack_clip_for("CarpenterAxe", GameData.ITEMS), RigTree.ATTACK_TOOL, "an axe plays the work swing")
	assert_eq(RigTree.attack_clip_for("SkinningKnife", GameData.ITEMS), RigTree.ATTACK_ONE_HAND, "a knife the one-handed swing")

func _test_pick_weakest() -> void:
	var material_of := func(item: String) -> String: return str(EquipmentRules.spec_of(item).get("material", ""))
	for pick in GameData.ITEMS:
		if EquipmentRules.category_of(str(pick)) != "pick":
			continue
		var mine := float(EquipmentRules.player_hit(str(pick))["total"])
		var shares: Dictionary = EquipmentRules.player_hit(str(pick))["shares"]
		assert_true(float(shares.get("blunt", 0.0)) > 0.0 and float(shares.get("piercing", 0.0)) > 0.0 and not shares.has("slashing"),
			"%s deals blunt and piercing damage" % pick)
		var peers := 0
		for other in GameData.ITEMS:
			var cat := EquipmentRules.category_of(str(other))
			if cat == "" or cat == "pick" or material_of.call(str(other)) != material_of.call(str(pick)):
				continue
			peers += 1
			assert_true(float(EquipmentRules.player_hit(str(other))["total"]) > mine, "%s hits harder than %s" % [other, pick])
		assert_true(peers > 0, "%s has items of its tier to compare with" % pick)
	assert_true(float(EquipmentRules.player_hit("StonePick")["total"]) > float(EquipmentRules.player_hit("")["total"]), "even a stone pick beats a fist")

## Resolve one landed round with a fixed seed (re-seeded until it hits) so two rounds can be compared.
func _round(b: Node, attacker: String, defender: String, item: String, rng_seed: int) -> float:
	for s in range(rng_seed, rng_seed + 50):
		seed(s)
		b._damage_item = item
		var r: Dictionary = b.resolve_round(attacker, defender)
		b._damage_item = ""
		if str(r.get("outcome", "")) == "hit":
			seed(s)
			b._damage_item = item
			var again: Dictionary = b.resolve_round(attacker, defender)
			b._damage_item = ""
			return float(again["damage"])
	return -1.0

func _test_host_damage_and_armour() -> void:
	var b := BattleSlice.new()
	add_child(b)
	b.is_authoritative = true
	var creature: String = GameData.CREATURES.keys()[0]
	# Player → creature: the held item's traits set the hit.
	var sword := _round(b, "player", creature, "FerriteShortSword", 1000)
	b.reset_hp(creature)
	var pick := _round(b, "player", creature, "FerritePick", 1000)
	b.reset_hp(creature)
	var fist := _round(b, "player", creature, "", 1000)
	b.reset_hp(creature)
	assert_true(sword > 0.0 and pick > 0.0 and fist > 0.0, "every hit lands for something")
	assert_true(absf(sword / pick - float(EquipmentRules.player_hit("FerriteShortSword")["total"]) / float(EquipmentRules.player_hit("FerritePick")["total"])) < 0.05,
		"the same roll scales with the item's trait damage (sword %.1f, pick %.1f)" % [sword, pick])
	assert_true(pick < sword and fist < pick, "a fist < a pick < a sword")
	# Creature → player: armour with blunt protection takes its share off the blunt part only.
	var bare := _round(b, creature, "player", "", 2000)
	b.armour_fn = func(_id: String) -> Dictionary: return { "blunt": 0.5 }
	var armoured := _round(b, creature, "player", "", 2000)
	var shares: Dictionary = EquipmentRules.creature_hit(10.0)["shares"]
	var expect := 1.0 - 0.5 * float(shares.get("blunt", 0.0))
	assert_true(bare > 0.0 and absf(armoured / bare - expect) < 0.02, "blunt protection 0.5 keeps %.2f of the hit (%.1f of %.1f)" % [expect, armoured, bare])
	b.armour_fn = func(_id: String) -> Dictionary: return { "slashing": 0.5, "blunt": 0.5, "piercing": 0.5 }
	var full := _round(b, creature, "player", "", 2000)
	assert_true(absf(full / bare - 0.5) < 0.02, "half off every type halves the hit")
	# The worn set's protection combines its pieces per type.
	var worn := { "Head": "FerriteHelmet", "Chest": "VeilsteelChestplate" }
	var prot := EquipmentRules.protection(worn, GameData.ITEMS)
	assert_true(float(prot["blunt"]) > 0.4 and float(prot["blunt"]) < 0.95, "helmet and chestplate stack below the cap")
	assert_eq(EquipmentRules.protection({}, GameData.ITEMS), {}, "nothing worn, no protection")
	b.free()
	seed(Time.get_ticks_usec())

func _test_old_save() -> void:
	# A pack as a save wrote it (contents and per-instance durability), item ids as they were before the phase.
	var src := InventorySlice.new()
	add_child(src)
	for item in FORMER_JOBS:
		src.add_item(item, 1)
	var saved := { "player_id": "old", "position": [0.0, 1.0, 0.0], "hp": 100.0,
		"inventory": src.get_contents(), "inventory_durability": src.get_durability_data() }
	src.free()
	var reg := PlayerRegistry.new()
	add_child(reg)   # its packs build their durability tables when they enter the tree, as on a host
	reg.apply_player_data("old", JSON.parse_string(JSON.stringify(saved)))
	var inv = reg.get_inventory("old")
	assert_true(inv != null, "the saved pack loads")
	for item in FORMER_JOBS:
		assert_eq(int(inv.get_item_count(item)), 1, "%s is still in the pack" % item)
		for work in FORMER_JOBS[item]:
			assert_true(EquipmentRules.work_speed(item, work) >= float(FORMER_JOBS[item][work]), "%s still does %s at its old speed" % [item, work])
	for work in ["fell", "mine", "dig", "build", "pickLock", "dissect", "cutBone"]:
		assert_true(str(inv.find_for_work(work)) != "", "the old pack can still %s" % work)
	reg.free()

func _with_locale(locale: String, fn: Callable) -> void:
	var before := TranslationServer.get_locale()
	TranslationServer.set_locale(locale)
	fn.call()
	TranslationServer.set_locale(before)

func _test_tooltip_and_wording() -> void:
	for loc: String in ["en", "pt_BR"]:
		_with_locale(loc, func() -> void:
			for key in ["ui.tip_category", "ui.tip_traits", "ui.tip_trait_grade", "ui.tip_can_do"]:
				assert_true(I18n.has_key(key), "%s exists in %s" % [key, loc])
			var lines := ItemTooltip.equipment_lines("CarpenterAxe")
			assert_true(lines.contains(I18n.content("equipment", "axe")), "%s: the axe's tooltip names its category (%s)" % [loc, lines])
			assert_true(lines.contains(I18n.content("trait", "Sharp")) and lines.contains(I18n.content("grade", "heavy")), "%s: and its traits with grades" % loc)
			assert_true(lines.contains(I18n.content("work", "fell")) and lines.contains(I18n.content("work", "cutBone")), "%s: and what it can do" % loc)
			assert_false(lines.contains("⟨"), "%s: no missing key" % loc)
			assert_eq(ItemTooltip.equipment_lines("FerriteIngot"), "", "%s: an ingot has no equipment lines" % loc))
	var en_re := RegEx.create_from_string("(?i)\\btools?\\b")
	var pt_re := RegEx.create_from_string("(?i)\\bferramentas?\\b")
	var parsed := I18n.parse_csv(I18n.CATALOG_PATH)
	for key: String in parsed["catalog"]["en"]:
		assert_true(en_re.search(str(parsed["catalog"]["en"][key])) == null, "en %s does not call anything a tool" % key)
	for key: String in parsed["catalog"]["pt_BR"]:
		assert_true(pt_re.search(str(parsed["catalog"]["pt_BR"][key])) == null, "pt_BR %s does not call anything a ferramenta" % key)
