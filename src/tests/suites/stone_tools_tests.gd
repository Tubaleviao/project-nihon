extends "res://src/tests/test_support.gd"
## Phase 260 — stone tools: an axe, a pick, a shovel, a knife and a hammer made by hand from branches and loose
## stones, under a technology discovered by holding both; the shovel digs soil fastest; felled trees drop
## branches and host rock knocks loose stones loose; a block is placed only with a hammer in hand.

const StoneTools := preload("res://src/world/stone_tools.gd")
const WorkTime := preload("res://src/core/work_time.gd")
const VoxelEdit := preload("res://src/terrain/voxel_edit.gd")

func register() -> void:
	_run_test("stone tools: each is craftable with no station from branches and loose stones once both were held", _test_craftable_fresh)
	_run_test("stone tools: holding stones, dropping them, then a branch discovers the technology with a notice", _test_discovery)
	_run_test("stone tools: stones alone discover nothing; the held inputs survive a snapshot", _test_discovery_partial)
	_run_test("stone tools: a discovery notice is a toast for its player only", _test_discovery_toast)
	_run_test("stone tools: a dedicated server's unowned pack discovers nothing and broadcasts nothing", _test_discovery_no_local_player)
	_run_test("stone tools: a discovery leaves the technology panel label to the toast", _test_discovery_panel_quiet)
	_run_test("stone tools: placing a block needs a hammer in hand and does not wear it", _test_hammer_to_build)
	_run_test("stone tools: every other tool is crafted and repaired at a station", _test_others_need_bench)
	_run_test("stone tools: the shovel digs soil faster than the pick; the pick mines rock faster than the shovel", _test_shovel_vs_pick)
	_run_test("stone tools: the host digs a soil block with the stone shovel at Mining novice in at most 0.7 s; hands and pick unchanged (Phase 290)", _test_fast_shovel)
	_run_test("stone tools: the host resolves a chained dig to the block under (or behind) the one just mined (Phase 290)", _test_chained_dig_host)
	_run_test("stone tools: digging soil wears a held shovel, mining rock wears the pick, host rock drops loose stones", _test_dig_wear_and_stones)
	_run_test("stone tools: a loose stone is decided by the span's position at the fabric chance", _test_loose_stone_rate)
	_run_test("stone tools: a felled tree drops branches beside its wood, bare-handed too", _test_fell_branches)
	_run_test("stone tools: with a stone pick and a ferrite pick held, the ferrite one is used", _test_fastest_tool)
	_run_test("stone tools: a discovery technology cannot be researched, so holding its inputs still discovers it", _test_discovery_not_researched)

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
	assert_eq(tools.size(), 5, "five stone tools")
	assert_false(tech.is_unlocked("TechStoneTools", "p1"), "a fresh character has discovered nothing")
	inv.add_item(StoneTools.BRANCH, 1)
	inv.add_item(StoneTools.LOOSE_STONE, 1)
	assert_true(tech.is_unlocked("TechStoneTools", "p1"), "holding a branch and a stone discovers it")
	assert_true(inv.consume_items({ StoneTools.BRANCH: 1, StoneTools.LOOSE_STONE: 1 }), "they are put away again")
	for tool in tools:
		var rid := _recipe_for(str(tool))
		assert_true(rid != "", "%s has a recipe" % tool)
		var recipe: Dictionary = GameData.RECIPES[rid].get("recipe")
		assert_eq(str(recipe.get("station", "")), "", "%s needs no station" % rid)
		var need: Dictionary = {}
		for i in recipe.get("inputs", []):
			assert_true(str(i["item"]) in [StoneTools.BRANCH, StoneTools.LOOSE_STONE], "%s takes only branches and stones" % rid)
			need[str(i["item"])] = int(i["quantity"])
		assert_true(tech.is_recipe_unlocked(rid, "p1"), "the discovery teaches %s" % rid)
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

func _tech_rig() -> Dictionary:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("host")
	reg.ensure_player("p1")
	var tech := TechnologySlice.new()
	add_child(tech)
	tech.player_registry = reg
	return { "reg": reg, "tech": tech, "inv": reg.get_inventory("p1") }

func _free_tech_rig(r: Dictionary) -> void:
	r["tech"].free()
	r["reg"].free()

func _test_discovery() -> void:
	var r := _tech_rig()
	var tech: Node = r["tech"]
	var inv: Node = r["inv"]
	assert_true(TechnologySlice.is_discovery("TechStoneTools"), "TechStoneTools is a discovery")
	assert_false(TechnologySlice.is_discovery("TechBasicCarpentry"), "Basic Carpentry is researched")
	assert_eq(TechnologySlice.discovery_inputs("TechStoneTools"), [StoneTools.BRANCH, StoneTools.LOOSE_STONE], "it waits for a branch and a stone")
	var notices: Array = []
	var unlocked: Array = []
	var on_msg := func(key: String, args: Array, target: String) -> void: notices.append([key, args, target])
	var on_unlock := func(tid: String, pid: String) -> void: unlocked.append([tid, pid])
	GameBus.system_message.connect(on_msg)
	GameBus.technology_unlocked.connect(on_unlock)
	inv.add_item(StoneTools.LOOSE_STONE, 3)
	assert_false(tech.is_unlocked("TechStoneTools", "p1"), "stones alone discover nothing")
	assert_true(inv.consume_items({ StoneTools.LOOSE_STONE: 3 }), "the stones are dropped")
	assert_eq(notices, [], "no notice yet")
	inv.add_item(StoneTools.BRANCH, 1)
	GameBus.system_message.disconnect(on_msg)
	GameBus.technology_unlocked.disconnect(on_unlock)
	assert_true(tech.is_unlocked("TechStoneTools", "p1"), "a branch later, with no stone in the pack, discovers it")
	assert_eq(unlocked, [["TechStoneTools", "p1"]], "announced once, for p1")
	assert_eq(notices.size(), 1, "one notice")
	assert_eq(str(notices[0][0]), "notice.tech_discovered", "keyed, never prose")
	assert_eq(str(notices[0][2]), "p1", "addressed to p1 alone")
	assert_eq(str(notices[0][1][0]), I18nScript.ref("tech", "TechStoneTools"), "it names the technology (a ref each client names)")
	for tool in StoneTools.tools():
		assert_true(str(notices[0][1][1]).contains(str(tool)), "and what it makes: %s" % tool)
	inv.add_item(StoneTools.LOOSE_STONE, 1)
	assert_eq(str(tech.begin_research("TechStoneTools", "p1").get("reason", "")), "already_unlocked", "nothing to research")
	_free_tech_rig(r)

func _test_discovery_partial() -> void:
	var r := _tech_rig()
	var tech: Node = r["tech"]
	r["inv"].add_item(StoneTools.LOOSE_STONE, 1)
	r["inv"].add_item("Ashite", 1)
	assert_eq(tech.seen_items("p1").keys(), [StoneTools.LOOSE_STONE], "only discovery inputs are remembered")
	var snap: Dictionary = tech.get_statuses("p1")
	assert_eq(snap.get(TechnologySlice.SEEN_KEY, []), [StoneTools.LOOSE_STONE], "the snapshot carries them")
	var other := TechnologySlice.new()
	add_child(other)
	other.player_registry = r["reg"]
	snap[TechnologySlice.SEEN_KEY] = [StoneTools.LOOSE_STONE, "FerriteIngot", 7]
	other.apply_statuses(snap, "p1")
	assert_eq(other.seen_items("p1").keys(), [StoneTools.LOOSE_STONE], "a restore keeps only discovery inputs")
	assert_eq(other.note_obtained("p1", StoneTools.BRANCH), ["TechStoneTools"], "after a reload a branch completes the discovery")
	other.is_authoritative = false
	assert_eq(other.note_obtained("p2", StoneTools.BRANCH), [], "a client discovers nothing")
	other.free()
	# A pack that is no player's (a merchant) discovers nothing.
	assert_eq(tech.note_obtained("merchant", StoneTools.BRANCH), [], "a merchant's stock discovers nothing")
	_free_tech_rig(r)

func _test_discovery_toast() -> void:
	assert_true(I18nScript.has_key("notice.tech_discovered"), "the notice is in the catalog")
	assert_true(I18nScript.has_key("structure.refused.build_required"), "so is the hammer refusal")
	var r := _tech_rig()
	var ui := _new_test_ui()
	ui.technology_slice = r["tech"]
	GameBus.system_message.emit("notice.tech_discovered", [I18nScript.ref("tech", "TechStoneTools"), I18nScript.ref("item", ["StoneAxe"])], "p1")
	assert_eq(ui.toast_shown(), "", "another player's notice is not shown here")
	GameBus.system_message.emit("notice.tech_discovered", [I18nScript.ref("tech", "TechStoneTools"), I18nScript.ref("item", ["StoneAxe"])], "host")
	assert_true(ui.toast_shown().contains(I18nScript.content("tech", "TechStoneTools")) and ui.toast_shown().contains(I18nScript.content("item", "StoneAxe")), "this machine's player sees a toast naming it")
	GameBus.system_message.emit("structure.ok.repair", [], "")
	assert_eq(ui.toast_queue().size(), 0, "other system lines are not toasts")
	ui.free()
	_free_tech_rig(r)

func _test_discovery_no_local_player() -> void:
	var r := _tech_rig()
	var tech: Node = r["tech"]
	r["reg"].local_player_id = ""   # a dedicated server: a registry, no local player
	var notices: Array = []
	var on_notice := func(k: String, a: Array, t: String) -> void: notices.append([k, a, t])
	GameBus.system_message.connect(on_notice)
	tech.note_obtained("", StoneTools.LOOSE_STONE)
	tech.note_obtained("", StoneTools.BRANCH)
	GameBus.system_message.disconnect(on_notice)
	assert_eq(notices.size(), 0, "no notice, so no broadcast to every client")
	assert_false(tech.is_unlocked("TechStoneTools", ""), "and nothing unlocked for nobody")
	assert_eq(tech.seen_items("").size(), 0, "nor any input remembered")
	_free_tech_rig(r)

func _test_discovery_panel_quiet() -> void:
	var ui := _new_test_ui()
	ui._technology_feedback = Label.new()
	ui._technology_feedback.text = "before"
	GameBus.research_resolved.emit({ "tech_id": "TechStoneTools", "success": true, "reason": "discovered", "status": "unlocked", "player_id": "" })
	assert_eq(ui._technology_feedback.text, "before", "a discovery does not also write the panel label")
	GameBus.research_resolved.emit({ "tech_id": "TechBasicSmithing", "success": true, "reason": "", "status": "unlocked", "player_id": "" })
	assert_eq(ui._technology_feedback.text, I18nScript.t("ui.tech_unlocked", [I18nScript.content("tech", "TechBasicSmithing")]), "other unlocks still do")
	ui._technology_feedback.free()
	ui.free()

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

func _test_hammer_to_build() -> void:
	assert_eq(VoxelEdit.build_work(), "build", "the fabric names the build work")
	assert_true(EquipmentRules.can_do("StoneHammer", "build"), "the stone hammer builds")
	var v := _make_voxel()
	var inv := InventorySlice.new()
	add_child(inv)
	v.inventory_slice = inv
	inv.add_item("Ashite", 2)
	var reasons: Array = []
	var on_res := func(_pid: String, action: String, ok: bool, reason: String) -> void: reasons.append([action, ok, reason])
	GameBus.structure_resolved.connect(on_res)
	assert_false(v.place_block(Vector3(16.0, 2.0, 16.0), Vector3.UP, "Ashite"), "no hammer: refused")
	GameBus.structure_resolved.disconnect(on_res)
	assert_eq(reasons, [["place", false, "build_required"]], "the builder is told why")
	assert_eq(inv.get_item_count("Ashite"), 2, "nothing was spent")
	inv.add_item("StoneHammer", 1)
	var dur := inv.get_durability("StoneHammer")
	assert_true(v.place_block(Vector3(16.0, 2.0, 16.0), Vector3.UP, "Ashite"), "a hammer in hand: placed")
	assert_eq(inv.get_item_count("Ashite"), 1, "the block was spent")
	assert_eq(inv.get_durability("StoneHammer"), dur, "the hammer did not wear")
	# #714: the host answers each place request on the bus, so the builder's work clip plays only on a placement.
	var answers: Array = []
	var on_answer := func(pid: String, placed: bool) -> void: answers.append([pid, placed])
	GameBus.block_place_resolved.connect(on_answer)
	v._edit._on_place_requested(Vector3(20.0, 2.0, 20.0), Vector3.UP, "", "Ashite")
	v._edit._on_place_requested(Vector3(24.0, 2.0, 24.0), Vector3.UP, "", "Ashite")
	GameBus.block_place_resolved.disconnect(on_answer)
	assert_eq(answers, [["", true], ["", false]], "a request that placed answers true, one with no block left answers false")
	v.free()
	inv.free()

func _test_others_need_bench() -> void:
	var stone := StoneTools.tools()
	for key in GameData.RECIPES:
		var recipe: Dictionary = GameData.RECIPES[key].get("recipe")
		for o in recipe.get("outputs", []):
			var res: Resource = GameData.ITEMS.get(str(o["item"]), null)
			if res == null or EquipmentRules.works_of(str(o["item"])).is_empty():
				continue
			if stone.has(str(o["item"])):
				assert_eq(str(recipe.get("station", "")), "", "%s needs no bench" % key)
			else:
				assert_true(str(recipe.get("station", "")) != "", "%s (%s) is made at a bench" % [key, o["item"]])
	for item in GameData.ITEMS:
		var res: Resource = GameData.ITEMS[item]
		var rep: Variant = res.get("repair")
		if EquipmentRules.works_of(str(item)).is_empty() or not (rep is Dictionary):
			continue
		if stone.has(str(item)):
			assert_eq(str(rep.get("station", "")), "", "%s is repaired by hand" % item)
		else:
			assert_true(str(rep.get("station", "")) != "", "%s is repaired at a bench" % item)

func _test_fastest_tool() -> void:
	var inv := InventorySlice.new()
	add_child(inv)
	inv.add_item("StonePick", 1)
	assert_eq(inv.find_for_work("mine"), "StonePick", "the stone pick alone is used")
	inv.add_item("FerritePick", 1)
	assert_eq(inv.find_for_work("mine"), "FerritePick", "the ferrite pick wins once it is in the pack")
	inv.add_item("StoneShovel", 1)
	assert_eq(inv.find_for_work("dig"), "StoneShovel", "the shovel digs")
	inv.free()

func _test_discovery_not_researched() -> void:
	var r := _tech_rig()
	var tech: Node = r["tech"]
	var res: Dictionary = tech.begin_research("TechStoneTools", "p1")
	assert_false(bool(res.get("success", true)), "a research of a discovery technology is refused")
	assert_eq(str(res.get("reason", "")), "discovery_only", "with its own reason")
	assert_true(I18nScript.has_key("reason.discovery_only"), "which the catalog renders")
	assert_eq(tech.get_status("TechStoneTools", "p1"), TechnologySlice.STATE_LOCKED, "and it stays locked, not researching")
	r["inv"].add_item(StoneTools.BRANCH, 1)
	r["inv"].add_item(StoneTools.LOOSE_STONE, 1)
	assert_true(tech.is_unlocked("TechStoneTools", "p1"), "holding the inputs then discovers it")
	var long_arg := TechnologySlice._outputs_arg(["AAAAAAAAAAAAAAAAAAAA", "BBBBBBBBBBBBBBBBBBBB", "CCCCCCCCCCCCCCCCCCCC", "DDDD"])
	assert_true(long_arg.length() <= I18nScript.MAX_ARG_LEN, "the outputs argument always fits a message (%d)" % long_arg.length())
	assert_true(long_arg.ends_with("…"), "and says when it was cut")
	_free_tech_rig(r)

## Phase 290 — the stone shovel works at 1.2, so a soil block takes 0.8 / 1.2 s; the base times did not move, so bare
## hands and the picks keep the Phase 259/260 durations on soil and rock.
func _test_fast_shovel() -> void:
	var WorkHost := preload("res://src/core/work_host.gd")
	var v := _make_voxel()
	v.is_authoritative = true
	var inv := InventorySlice.new()
	add_child(inv)
	inv._max_weight = 1.0e9
	v.inventory_slice = inv
	var host := WorkHost.new()
	host.voxel_slice = v
	var top := Vector3(16.25, 2.0, 16.25)
	var bare := host.resolve("", "block", "", top, Vector3.UP, {})
	assert_eq(str(bare.get("material", "")), "Soil", "the top block of the flat rig is soil")
	assert_eq(str(bare.get("action", "")), "dig", "and it is dug")
	assert_true(absf(float(bare.get("duration", 0.0)) - 0.8 / 0.25) < 0.001, "bare hands dig it in 3.2 s, as before (%.3f)" % float(bare.get("duration", 0.0)))
	inv.add_item("StonePick", 1)
	var pick := host.resolve("", "block", "", top, Vector3.UP, {})
	assert_true(absf(float(pick.get("duration", 0.0)) - 3.2) < 0.001, "a pick digs soil at bare-hands speed, as before (%.3f)" % float(pick.get("duration", 0.0)))
	inv.add_item("StoneShovel", 1)
	var shovel := host.resolve("", "block", "", top, Vector3.UP, {})
	var secs := float(shovel.get("duration", 0.0))
	# Phase 300 — a shovel hold is one brush: the slab time (0.8 s over the shovel's 1.2) times the cells it will
	# remove times the fabric's share, so it digs faster per cell than the slab (share below 1) and a hold is longer.
	var cells: int = v._edit.dig_preview_cells(top, Vector3.UP, "StoneShovel")
	var factor: float = v._edit.dig.work_factor(cells)
	assert_true(cells > 1 and factor > 1.0, "the shovel's brush covers several cells (%d)" % cells)
	assert_true(absf(secs - 0.8 / 1.2 * factor) < 0.001, "0.8 s over the shovel's 1.2, times the brush's volume (%.3f)" % secs)
	assert_true(secs / float(cells) < 0.8 / 1.2, "and a cell is dug faster than a slab alone would be")
	assert_eq(WorkTime.speed("dig", "StoneShovel"), 1.2, "the stone shovel works at 1.2")
	# Unchanged: the base times and the other tools.
	assert_true(absf(WorkTime.seconds("Grass", "dig", "") - 2.4) < 0.001, "bare hands on grass: 2.4 s")
	assert_true(absf(WorkTime.seconds("Ferrite", "mine", "") - 12.0) < 0.001, "bare hands on Ferrite: 12 s")
	assert_true(absf(WorkTime.seconds("Ferrite", "mine", "StonePick") - 5.0) < 0.001, "a stone pick on Ferrite: 5 s")
	assert_true(absf(WorkTime.seconds("Ferrite", "mine", "FerritePick") - 3.0) < 0.001, "a ferrite pick on Ferrite: 3 s")
	assert_true(absf(WorkTime.seconds("Ashite", "mine", "StonePick") - 2.5 / 0.6) < 0.001, "a stone pick on Ashite: unchanged")
	assert_true(absf(WorkTime.seconds("Soil", "dig", "FerritePick") - 3.2) < 0.001, "a ferrite pick on soil: bare-hands speed")
	# Nothing digs slower than the stone shovel.
	for item in GameData.ITEMS:
		var d := EquipmentRules.work_speed(str(item), "dig")
		if d > 0.0:
			assert_true(d >= 1.2, "%s digs at least as fast as the stone shovel" % item)
	v.free()
	inv.free()

## Phase 290 — the chained start the hold sends in the completion frame names the next block once the host has run the
## mine: one STEP_HEIGHT under a dug top, one tile further in behind a dug side face.
func _test_chained_dig_host() -> void:
	var WorkHost := preload("res://src/core/work_host.gd")
	var Hold := preload("res://src/player/work_hold.gd")
	var v := _make_voxel()
	v.is_authoritative = true
	var inv := InventorySlice.new()
	add_child(inv)
	inv._max_weight = 1.0e9
	v.inventory_slice = inv
	var host := WorkHost.new()
	host.voxel_slice = v
	var top := { "kind": "block", "position": Vector3(16.25, 2.0, 16.25), "normal": Vector3.UP, "exact": {} }
	var first := host.resolve("", "block", "", top["position"], Vector3.UP, {})
	assert_true(bool(v.mine_block(top["position"], Vector3.UP).get("success", false)), "the top block is dug")
	var next: Dictionary = Hold.next_dig_target(top)
	var chained := host.start("", "block", "", next["position"], next["normal"], next["exact"], 0.0)
	assert_true(bool(chained.get("ok", false)), "the host starts the chained dig")
	assert_eq(str(chained.get("key", "")), "block:32,32,%.2f" % (2.0 - 2.0 * VoxelSlice.STEP_HEIGHT), "on the block one step under the dug one")
	assert_false(str(chained.get("key", "")) == str(first.get("key", "")), "not on the dug block")
	host.cancel("")
	# A side face of the pit's wall (the face of tile 33 looking west into the pit): the chain goes one tile further in.
	var wall_y := 2.0 - VoxelSlice.STEP_HEIGHT * 0.5
	var side := { "kind": "block", "position": Vector3(16.5, wall_y, 16.25), "normal": Vector3(-1, 0, 0), "exact": {} }
	var side_key := str(host.resolve("", "block", "", side["position"], side["normal"], {}).get("key", ""))
	assert_eq(side_key, "block:33,32,%.2f" % (2.0 - VoxelSlice.STEP_HEIGHT), "the side face names the wall's block")
	assert_true(bool(v.mine_block(side["position"], side["normal"]).get("success", false)), "the wall block is dug")
	next = Hold.next_dig_target(side)
	chained = host.start("", "block", "", next["position"], next["normal"], next["exact"], 0.0)
	assert_eq(str(chained.get("key", "")), "block:34,32,%.2f" % (2.0 - VoxelSlice.STEP_HEIGHT), "the chained side dig is the next tile in")
	host.cancel("")
	v.free()
	inv.free()
