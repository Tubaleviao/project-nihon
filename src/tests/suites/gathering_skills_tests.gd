extends "res://src/tests/test_support.gd"
## Phase 274 — gathering is its own skills: Mining (pick and shovel: stone, ore, soil), Woodcutting (axe: wood),
## Foraging (plants) and Skinning (carcasses) in the `gathering` category. Crafting skills grow only from
## crafting, Building only from building. A Mining or Woodcutting tier shortens the work as the fabric says, and
## XP a save earned in a crafting skill stays there.

const WorkSkills := preload("res://src/character/work_skills.gd")
const WorkTime := preload("res://src/core/work_time.gd")
const WorkHost := preload("res://src/core/work_host.gd")
const AttributeRules := preload("res://src/character/attribute_rules.gd")
const I18n := preload("res://src/core/i18n.gd")

const GATHERING_SKILLS := ["Mining", "Woodcutting", "Foraging", "Skinning"]

func register() -> void:
	_run_test("gathering skills: every gather row names a gathering skill, by the tool the work wants", _test_rows)
	_run_test("gathering skills: mining stone, ore and soil grants Mining and no Building or Smithing", _test_mining)
	_run_test("gathering skills: chopping grants Woodcutting, foraging Foraging, skinning Skinning", _test_chop_forage_skin)
	_run_test("gathering skills: crafting still grants its crafting skill and no gathering skill", _test_crafting)
	_run_test("gathering skills: each tier of Mining, Woodcutting and Foraging gives a bonus the fabric names", _test_tier_bonuses)
	_run_test("gathering skills: a Mining tier lowers mining time as the fabric says", _test_mining_tier_time)
	_run_test("gathering skills: the host times work by the worker's own recorded tier", _test_host_uses_tier)
	_run_test("gathering skills: a save with old Smithing XP loads with it unchanged", _test_old_save)
	_run_test("gathering skills: the forager specialty weighs Foraging", _test_forager_specialty)

func _registry() -> PlayerRegistry:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("host")
	for p in ["p1", "p2"]:
		reg.ensure_player(p)
	return reg

func _xp(reg: PlayerRegistry, pid: String) -> Dictionary:
	return (reg.get_record(pid).get("skill_xp", {}) as Dictionary).duplicate()

## `after` minus `before`, keeping only skills that moved.
func _gained(before: Dictionary, after: Dictionary) -> Dictionary:
	var out := {}
	for skill: String in after:
		var d := int(after[skill]) - int(before.get(skill, 0))
		if d != 0:
			out[skill] = d
	return out

func _test_rows() -> void:
	var gather: Dictionary = WorkSkills.table().get("gather", {})
	assert_true(gather.size() >= 6, "the gather table has its rows (%d)" % gather.size())
	for k: String in gather:
		var skill := str((gather[k] as Dictionary).get("skill", ""))
		assert_eq(AttributeRules.category_of_skill(skill), "gathering", "gather.%s grows a gathering skill (%s)" % [k, skill])
	assert_eq(str(gather["stone"]["skill"]), "Mining", "stone (pick) grows Mining")
	assert_eq(str(gather["metal"]["skill"]), "Mining", "ore (pick) grows Mining")
	assert_eq(str(gather["soil"]["skill"]), "Mining", "soil (shovel) grows Mining")
	assert_eq(str(gather["wood"]["skill"]), "Woodcutting", "wood (axe) grows Woodcutting")
	assert_eq(str(gather["plant"]["skill"]), "Foraging", "plants grow Foraging")
	assert_eq(str(gather["carcass"]["skill"]), "Skinning", "carcasses grow Skinning")
	assert_eq(WorkTime.tool_class(WorkTime.action_for_material("Ashite")), "pick", "stone is mined with a pick")
	assert_eq(WorkTime.tool_class(WorkTime.action_for_material("Ferrite")), "pick", "ore is mined with a pick")
	assert_eq(WorkTime.tool_class(WorkTime.action_for_material("Soil")), "shovel", "soil is dug with a shovel")
	assert_eq(WorkTime.tool_class(WorkTime.action_for_material("Thornwood")), "axe", "wood is chopped with an axe")
	for s: String in GATHERING_SKILLS:
		assert_true(GameData.SKILLS.has(s), "%s is a skill" % s)
		assert_true(I18n.has_content("skill", s), "%s has a name in the content catalog" % s)

func _test_mining() -> void:
	var reg := _registry()
	for m: String in ["Ashite", "Ferrite", "Soil"]:
		var before := _xp(reg, "p1")
		var row := WorkSkills.gather_row(m)
		WorkSkills.grant(reg, "p1", row, 3)
		assert_eq(_gained(before, _xp(reg, "p1")), { "Mining": 3 * int(row["xp"]) }, "mining 3 %s grants Mining and nothing else" % m)
	assert_eq(reg.get_skill_xp("p1", "Building"), 0, "no Building XP from mining")
	assert_eq(reg.get_skill_xp("p1", "Smithing"), 0, "no Smithing XP from mining ore")
	# The real mine on natural ground: whatever it banks grows Mining.
	var v := _make_voxel()
	v.is_authoritative = true
	v.player_registry = reg
	reg.get_inventory("p2").add_item("StonePick", 1)
	var before2 := _xp(reg, "p2")
	var res: Dictionary = v.mine_block(Vector3(10.25, 2.0, 1.25), Vector3.UP, "p2")
	assert_true(bool(res["success"]) and int(res["quantity"]) > 0, "p2 mines natural ground (%s)" % str(res.get("reason", "")))
	var gained := _gained(before2, _xp(reg, "p2"))
	assert_eq(gained.keys(), ["Mining"], "mining %s grew Mining only (%s)" % [res.get("material", ""), str(gained)])
	v.free()
	reg.free()

func _test_chop_forage_skin() -> void:
	var reg := _registry()
	var t := _make_tree_slice()
	t.player_registry = reg
	reg.get_inventory("p1").add_item("CarpenterAxe", 1)
	t.spawn_for_chunk(Vector2i(0, 0))
	var tid: String = str(t.get_all_trees()[0]["tree_id"])
	var before := _xp(reg, "p1")
	var c: Dictionary = t.chop_tree(tid, "p1")
	assert_true(bool(c["success"]), "p1 fells a tree (%s)" % str(c.get("reason", "")))
	var row := WorkSkills.gather_row(str(c["wood"]))
	assert_eq(_gained(before, _xp(reg, "p1")), { "Woodcutting": int(row["xp"]) * int(c["quantity"]) }, "chopping grows Woodcutting, not Carpentry")
	t.free()
	before = _xp(reg, "p2")
	WorkSkills.grant(reg, "p2", WorkSkills.gather_row("plant"))
	assert_eq(_gained(before, _xp(reg, "p2")), { "Foraging": int(WorkSkills.gather_row("plant")["xp"]) }, "foraging grows Foraging, not Alchemy")
	before = _xp(reg, "p2")
	WorkSkills.grant(reg, "p2", WorkSkills.gather_row("carcass"))
	assert_eq(_gained(before, _xp(reg, "p2")), { "Skinning": int(WorkSkills.gather_row("carcass")["xp"]) }, "skinning grows Skinning")
	reg.free()

func _test_crafting() -> void:
	assert_eq(str(WorkSkills.craft_row("smithing")["skill"]), "Smithing", "smithing recipes grow Smithing")
	assert_eq(str(WorkSkills.craft_row("carpentry")["skill"]), "Carpentry", "carpentry recipes grow Carpentry")
	assert_eq(str(WorkSkills.craft_row("alchemy")["skill"]), "Alchemy", "alchemy recipes grow Alchemy")
	for kind in ["build", "dismantle", "repair"]:
		assert_eq(str(WorkSkills.row(kind)["skill"]), "Building", "%s grows Building" % kind)
	var reg := _registry()
	var crafting := CraftingSlice.new()
	add_child(crafting)
	crafting.player_registry = reg
	reg.get_inventory("p1").add_item("Duskfiber", 4)
	var before := _xp(reg, "p1")
	var res: Dictionary = crafting.craft("RecipeNoviceTunic", "p1")
	assert_true(bool(res["success"]), "p1 sews a tunic (%s)" % str(res.get("reason", "")))
	assert_eq(_gained(before, _xp(reg, "p1")), { "Tailoring": int(WorkSkills.craft_row("tailoring")["xp"]) }, "crafting grows its crafting skill only")
	crafting.free()
	reg.free()

func _test_tier_bonuses() -> void:
	var tiers := ["novice", "apprentice", "journeyman", "expert", "master"]
	var expect := { "Mining": ["speed", ["mine", "dig"]], "Woodcutting": ["speed", ["chop"]], "Foraging": ["yield", ["forage"]] }
	for s: String in expect:
		var row: Dictionary = WorkSkills.bonuses().get(s, {})
		assert_eq(str(row.get("effect", "")), expect[s][0], "%s tiers give %s" % [s, expect[s][0]])
		for w: String in expect[s][1]:
			assert_eq(WorkSkills.bonus_skill(w, str(expect[s][0])), s, "%s's %s bonus applies to %s" % [s, expect[s][0], w])
		assert_eq(WorkSkills.bonus_factor(s, "novice"), 1.0, "%s novice gives no bonus yet" % s)
		var prev := 1.0
		for i in range(1, tiers.size()):
			var f := WorkSkills.bonus_factor(s, tiers[i])
			assert_true(f > prev, "%s %s gives more than the tier before (%.2f > %.2f)" % [s, tiers[i], f, prev])
			prev = f
	assert_eq(WorkSkills.bonus_skill("chop", "yield"), "", "no yield bonus on chopping")
	assert_eq(WorkSkills.bonus_factor("Smithing", "master"), 1.0, "a crafting skill has no gathering bonus")

func _test_mining_tier_time() -> void:
	var base := WorkTime.seconds("Ashite", "mine", "FerritePick")
	assert_true(base > 0.0, "mining Ashite with a pick takes time")
	assert_eq(WorkTime.seconds("Ashite", "mine", "FerritePick", "novice"), base, "a novice mines at the tool's speed")
	for tier: String in ["apprentice", "journeyman", "expert", "master"]:
		var f := WorkSkills.bonus_factor("Mining", tier)
		var t := WorkTime.seconds("Ashite", "mine", "FerritePick", tier)
		assert_true(absf(t - base / f) < 0.0001, "%s Mining: %.3f s = %.3f / %.2f" % [tier, t, base, f])
		assert_true(t < base, "%s Mining is faster than novice" % tier)
	# Digging is Mining too; on top of the tool: bare hands get the same factor.
	var dig := WorkTime.seconds("Soil", "dig", "")
	assert_true(absf(WorkTime.seconds("Soil", "dig", "", "master") - dig / WorkSkills.bonus_factor("Mining", "master")) < 0.0001, "a master digs faster, bare-handed too")
	# Mining tiers do not touch chopping.
	assert_eq(WorkTime.skill_speed("chop", "master"), WorkSkills.bonus_factor("Woodcutting", "master"), "chopping reads Woodcutting")
	assert_eq(WorkTime.duration("Ashite", "mine", "FerritePick", "master"), WorkTime.seconds("Ashite", "mine", "FerritePick", "master"), "the host's duration carries the tier")

func _test_host_uses_tier() -> void:
	var reg := _registry()
	var v := _make_voxel()
	v.is_authoritative = true
	v.player_registry = reg
	var host := WorkHost.new()
	host.voxel_slice = v
	var pos := Vector3(10.25, 2.0, 1.25)
	var novice := host.resolve("p1", "block", "", pos, Vector3.UP, {})
	assert_false(novice.is_empty(), "the host resolves a block to mine")
	reg.record_skill("p1", "Mining", "master")
	var master := host.resolve("p1", "block", "", pos, Vector3.UP, {})
	var f := WorkSkills.bonus_factor("Mining", "master")
	assert_true(absf(float(master["duration"]) - float(novice["duration"]) / f) < 0.0001,
		"a master miner's duration is the novice's over %.2f (%.3f vs %.3f)" % [f, float(master["duration"]), float(novice["duration"])])
	assert_eq(WorkTime.worker_tier(reg, "p2", "mine"), "novice", "another player's record is their own")
	assert_eq(WorkTime.worker_tier(null, "p1", "mine"), "novice", "no registry: novice")
	v.free()
	reg.free()

func _test_old_save() -> void:
	var reg := _registry()
	reg.apply_player_data("old", { "player_id": "old", "position": [0.0, 1.0, 0.0], "hp": 100.0,
		"skill_xp": { "Smithing": 950, "Building": 420, "Carpentry": 77 }, "skills": { "Smithing": "journeyman" } })
	assert_eq(reg.get_skill_xp("old", "Smithing"), 950, "Smithing XP earned mining before Phase 274 stays")
	assert_eq(reg.get_skill_xp("old", "Building"), 420, "so does Building")
	assert_eq(reg.get_skill_xp("old", "Carpentry"), 77, "and Carpentry")
	assert_eq(reg.get_skill_tier("old", "Smithing"), "journeyman", "the tier stays")
	assert_eq(reg.get_skill_xp("old", "Mining"), 0, "nothing is moved into Mining (no migration)")
	var round_trip: Dictionary = reg.get_record("old").get("skill_xp", {})
	assert_eq(round_trip, { "Smithing": 950, "Building": 420, "Carpentry": 77 }, "the record holds exactly the saved XP")
	reg.free()

func _test_forager_specialty() -> void:
	var tbl: Variant = GameData.WORLD_SYSTEMS["SettlementSpecialties"].get("rules")
	var forager: Dictionary = (tbl as Dictionary)["specialties"]["forager"]
	assert_eq((forager["skills"] as Dictionary).keys(), ["Foraging"], "the forager weighs Foraging alone")
