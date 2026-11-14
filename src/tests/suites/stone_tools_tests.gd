extends "res://src/tests/test_support.gd"
## Phase 260 — stone tools: an axe, a pick, a shovel and a knife made by hand from branches and loose stones,
## under an innate technology; the shovel digs soil fastest; felled trees drop branches and host rock knocks
## loose stones loose.

const StoneTools := preload("res://src/world/stone_tools.gd")
const WorkTime := preload("res://src/core/work_time.gd")

func register() -> void:
	_run_test("stone tools: each is craftable with no station from branches and loose stones on a fresh character", _test_craftable_fresh)
	_run_test("stone tools: the innate technology is unlocked from the start and no snapshot locks it", _test_innate)
	_run_test("stone tools: the shovel digs soil faster than the pick; the pick mines rock faster than the shovel", _test_shovel_vs_pick)
	_run_test("stone tools: digging soil wears a held shovel, mining rock wears the pick, host rock drops loose stones", _test_dig_wear_and_stones)
	_run_test("stone tools: a loose stone is decided by the span's position at the fabric chance", _test_loose_stone_rate)
	_run_test("stone tools: a felled tree drops branches beside its wood, bare-handed too", _test_fell_branches)
	_run_test("stone tools: with a stone pick and a ferrite pick held, the ferrite one is used", _test_fastest_tool)

func _recipe_for(item: String) -> String:
	for key in GameData.RECIPES:
		for o in (GameData.RECIPES[key].get("recipe") as Dictionary).get("outputs", []):
			if str(o["item"]) == item:
				return str(key)
	return ""

func _test_craftable_fresh() -> void:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.ensure_player("p1")
	var tech := TechnologySlice.new()
	add_child(tech)
	tech.player_registry = reg
	var stations := StationSlice.new()
	add_child(stations)
	var crafting := CraftingSlice.new()
	add_child(crafting)
	crafting.player_registry = reg
	crafting.technology_slice = tech
	crafting.station_slice = stations   # the station gate is live: no station is placed anywhere
	var inv: Node = reg.get_inventory("p1")
	var tools := StoneTools.tools()
	assert_eq(tools.size(), 4, "four stone tools")
	for tool in tools:
		var rid := _recipe_for(str(tool))
		assert_true(rid != "", "%s has a recipe" % tool)
		var recipe: Dictionary = GameData.RECIPES[rid].get("recipe")
		assert_eq(str(recipe.get("station", "")), "", "%s needs no station" % rid)
		var need: Dictionary = {}
		for i in recipe.get("inputs", []):
			assert_true(str(i["item"]) in [StoneTools.BRANCH, StoneTools.LOOSE_STONE], "%s takes only branches and stones" % rid)
			need[str(i["item"])] = int(i["quantity"])
		assert_true(tech.is_recipe_unlocked(rid, "p1"), "a fresh character knows %s" % rid)
		assert_false(bool(crafting.can_craft(rid, "p1").get("success", false)), "%s needs its inputs" % rid)
		for k in need:
			inv.add_item(k, need[k])
		var r: Dictionary = crafting.craft(rid, "p1")
		assert_true(bool(r.get("success", false)), "%s crafts with no station (%s)" % [rid, str(r.get("reason", ""))])
		assert_eq(inv.get_item_count(str(tool)), 1, "%s is in the pack" % tool)
		assert_eq([inv.get_item_count(StoneTools.BRANCH), inv.get_item_count(StoneTools.LOOSE_STONE)], [0, 0], "the inputs are spent")
	# A forged tool still waits for its technology and its station.
	assert_false(tech.is_recipe_unlocked("RecipeFerritePick", "p1"), "a fresh character does not know the ferrite pick")
	crafting.free()
	stations.free()
	tech.free()
	reg.free()

func _test_innate() -> void:
	var tech := TechnologySlice.new()
	add_child(tech)
	assert_true(TechnologySlice.is_innate("TechStoneTools"), "TechStoneTools is innate")
	assert_false(TechnologySlice.is_innate("TechBasicCarpentry"), "Basic Carpentry is researched")
	assert_true(tech.is_unlocked("TechStoneTools", "fresh"), "unlocked for a fresh player")
	assert_false(tech.is_unlocked("TechBasicCarpentry", "fresh"), "other technologies start locked")
	tech.apply_statuses({ "TechStoneTools": "locked" }, "fresh")
	assert_true(tech.is_unlocked("TechStoneTools", "fresh"), "a snapshot cannot lock an innate technology")
	assert_eq(str(tech.begin_research("TechStoneTools", "fresh").get("reason", "")), "already_unlocked", "nothing to research")
	assert_eq(str(tech.get_statuses("fresh").get("TechStoneTools", "")), "unlocked", "the snapshot records it unlocked")
	tech.free()

func _test_shovel_vs_pick() -> void:
	assert_eq(WorkTime.action_for_material("Soil"), "dig", "soil is dug")
	assert_eq(WorkTime.action_for_material("Ashite"), "mine", "host rock is mined")
	for soft in ["Soil", "Sand", "Grass"]:
		var dig := WorkTime.action_for_material(soft)
		assert_true(WorkTime.seconds(soft, dig, "StoneShovel") < WorkTime.seconds(soft, dig, "StonePick"), "the shovel digs %s faster than the pick" % soft)
		assert_true(WorkTime.seconds(soft, dig, "StoneShovel") < WorkTime.seconds(soft, dig, ""), "and faster than bare hands")
	for rock in ["Ashite", "Ferrite"]:
		assert_true(WorkTime.seconds(rock, "mine", "StonePick") < WorkTime.seconds(rock, "mine", "StoneShovel"), "the pick mines %s faster than the shovel" % rock)
	# Stone tools sit between bare hands and the forged tools.
	assert_true(WorkTime.seconds("Ashite", "mine", "StonePick") > WorkTime.seconds("Ashite", "mine", "FerritePick"), "a ferrite pick beats a stone one")
	assert_true(WorkTime.seconds("Thornwood", "chop", "StoneAxe") < WorkTime.seconds("Thornwood", "chop", ""), "a stone axe beats bare hands")
	assert_true(WorkTime.seconds("Thornwood", "chop", "StoneAxe") > WorkTime.seconds("Thornwood", "chop", "CarpenterAxe"), "the carpenter's axe beats a stone one")

func _test_dig_wear_and_stones() -> void:
	var v := _make_voxel()
	var inv := InventorySlice.new()
	add_child(inv)
	inv._max_weight = 1.0e9
	v.inventory_slice = inv
	inv.add_item("StoneShovel", 1)
	inv.add_item("StonePick", 1)
	var x := 16.0
	var z := 16.0
	var tile := Vector2i(floori(x / VoxelSlice.TILE_SIZE), floori(z / VoxelSlice.TILE_SIZE))
	var dug := 0
	var mined := 0
	var expected_stones := 0
	for _i in 48:
		var top := v.get_voxel_height_at(Vector2(x, z))
		var shovel_before := inv.get_durability("StoneShovel")
		var pick_before := inv.get_durability("StonePick")
		var r := v.mine_block(Vector3(x, top, z))
		if not bool(r.get("success", false)):
			break
		var mat := str(r["material"])
		if WorkTime.action_for_material(mat) == "dig":
			dug += 1
			assert_true(inv.get_durability("StoneShovel") < shovel_before, "digging %s wears the shovel" % mat)
			assert_eq(inv.get_durability("StonePick"), pick_before, "and not the pick")
		else:
			mined += 1
			assert_true(inv.get_durability("StonePick") < pick_before, "mining %s wears the pick" % mat)
			assert_eq(inv.get_durability("StoneShovel"), shovel_before, "and not the shovel")
			if StoneTools.loose_stone_at(tile, top - VoxelSlice.STEP_HEIGHT):
				expected_stones += 1
		if inv.get_durability("StonePick") <= 0.0 or inv.get_durability("StoneShovel") <= 0.0:
			break
	assert_true(dug > 0, "the column has soil on top (%d dug)" % dug)
	assert_true(mined > 0, "and rock below (%d mined)" % mined)
	assert_true(expected_stones > 0, "some host-rock span drops a stone (%d of %d)" % [expected_stones, mined])
	assert_eq(inv.get_item_count(StoneTools.LOOSE_STONE), expected_stones, "one loose stone per host-rock span the table picks")
	v.free()
	inv.free()

func _test_loose_stone_rate() -> void:
	var chance := StoneTools.loose_stone_chance()
	assert_true(chance > 0.0 and chance <= 1.0, "the fabric sets a chance")
	var hits := 0
	var n := 4000
	for i in n:
		var t := Vector2i(i % 64, i / 64)
		if StoneTools.loose_stone_at(t, -1.5):
			hits += 1
		assert_eq(StoneTools.loose_stone_at(t, -1.5), StoneTools.loose_stone_at(t, -1.5), "the same span always answers the same")
	assert_true(absf(float(hits) / n - chance) < 0.05, "the rate is the fabric chance (%d of %d)" % [hits, n])

func _test_fell_branches() -> void:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("host")
	reg.ensure_player("p1")
	reg.ensure_player("p2")
	var t := _make_tree_slice()
	t.player_registry = reg
	t.spawn_for_chunk(Vector2i(0, 0))
	var trees: Array = t.get_all_trees()
	assert_true(trees.size() >= 2, "the chunk has trees")
	reg.get_inventory("p1").add_item("StoneAxe", 1)
	var n := StoneTools.fell_branches()
	assert_true(n >= 1, "the fabric drops at least one branch")
	var c: Dictionary = t.chop_tree(str(trees[0]["tree_id"]), "p1")
	assert_true(bool(c["success"]), "a stone axe fells a tree (%s)" % str(c.get("reason", "")))
	assert_eq(reg.get_inventory("p1").get_item_count(StoneTools.BRANCH), n, "the felled tree drops its branches")
	assert_eq(reg.get_inventory("p1").get_item_count(str(c["wood"])), int(c["quantity"]), "beside its wood")
	var bare: Dictionary = t.chop_tree(str(trees[1]["tree_id"]), "p2")
	assert_true(bool(bare["success"]), "bare hands fell a tree too")
	assert_eq(reg.get_inventory("p2").get_item_count(StoneTools.BRANCH), n, "and get its branches")
	t.free()
	reg.free()

func _test_fastest_tool() -> void:
	var inv := InventorySlice.new()
	add_child(inv)
	inv.add_item("StonePick", 1)
	assert_eq(inv.find_tool("pick"), "StonePick", "the stone pick alone is used")
	inv.add_item("FerritePick", 1)
	assert_eq(inv.find_tool("pick"), "FerritePick", "the ferrite pick wins once it is in the pack")
	inv.add_item("StoneShovel", 1)
	assert_eq(inv.find_tool("shovel"), "StoneShovel", "the shovel is its own class")
	inv.free()
