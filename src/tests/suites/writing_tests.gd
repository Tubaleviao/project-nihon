extends "res://src/tests/test_support.gd"
## Phase 209 — books and blueprints: research shared by writing. A writer must know what they write about and pay
## the fabric's cost at its station; reading teaches the reader alone and keeps the item; a blueprint teaches a
## station recipe or a project; what a player learnt saves and loads; the wire binds the identity.

const WritingSlice := preload("res://src/technology/writing_slice.gd")
const WritingRules := preload("res://src/technology/writing_rules.gd")
const UiSliceScript := preload("res://src/ui/ui_slice.gd")

const AT := Vector3(10.5, 2.125, 10.5)
const BOOK := "BookTechBasicSmithing"
const BED_PRINT := "BlueprintRecipeBed"

func register() -> void:
	_run_test("writing: one item per technology, station recipe and project, with the fabric's cost and station", _test_rules)
	_run_test("writing: a reader of a book unlocks its technology; a player who has not read it is unchanged", _test_read_book)
	_run_test("writing: writing about a technology the writer does not know is refused", _test_write_unknown_refused)
	_run_test("writing: a write pays the cost from the writer's pack and gives the book", _test_write_pays)
	_run_test("writing: a blueprint is drawn at its station and teaches its recipe", _test_blueprint)
	_run_test("writing: a project blueprint needs the project known, and teaches it", _test_project_blueprint)
	_run_test("writing: a book does not skip the tree, and reading what you know or do not hold is refused", _test_read_refusals)
	_run_test("writing: what a player learnt saves and loads, bounded to the fabric", _test_persistence)
	_run_test("writing: the host rate-limits one player's intents", _test_rate)
	_run_test("writing: the wire binds the connection's player, and a client forwards", _test_wire)
	_run_test("writing: the pack offers Read on a book, and the Technology window lists what can be written", _test_ui)
	_run_test("writing: a book waits for research under way, and a station blueprint needs its tree's prerequisites", _test_learn_guards)
	_run_test("writing: a project is known by crafted materials only, through any recipe that makes them", _test_knows_materials)
	_run_test("writing: the host's rate-limit table drops stale players", _test_rate_bounded)
	_run_test("writing: the Technology window names writings and stations in the locale, and a read says learnt", _test_ui_text)

# ── rig ──────────────────────────────────────────────────────────────────

## A registry with p1 and p2, a technology slice reading their packs, and a writing slice whose players stand at
## AT and whose only station is the type in `station` (none when "").
func _rig() -> Dictionary:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("host")
	for p in ["p1", "p2"]:
		reg.ensure_player(p)
	var tech := TechnologySlice.new()
	tech.player_registry = reg
	tech.is_authoritative = true
	add_child(tech)
	var station := { "type": "" }
	var clock := [100000]
	var w := WritingSlice.new()
	w.technology = tech
	w.inventory_for = tech.inventory_for
	w.position_of = func(_pid: String) -> Variant: return AT
	w.nearest_station = func(pos: Vector3, type: String, radius: float) -> String:
		return "st1" if type == str(station["type"]) and pos.distance_to(AT) <= radius else ""
	w.now_ms = func() -> int:
		clock[0] += 1000
		return clock[0]
	add_child(w)
	return { "reg": reg, "tech": tech, "w": w, "station": station, "clock": clock }

func _free_rig(r: Dictionary) -> void:
	r["w"].free()
	r["tech"].free()
	r["reg"].free()

func _give(r: Dictionary, pid: String, item: String, n: int) -> void:
	assert_true(r["reg"].get_inventory(pid).add_item(item, n), "%s gets %d %s" % [pid, n, item])

func _count(r: Dictionary, pid: String, item: String) -> int:
	return int(r["reg"].get_inventory(pid).get_item_count(item))

func _give_cost(r: Dictionary, pid: String, item_id: String) -> void:
	var cost := WritingRules.cost(str(WritingRules.of(item_id)["writing"]))
	for item: String in cost:
		_give(r, pid, item, int(cost[item]))

# ── tests ────────────────────────────────────────────────────────────────

func _test_rules() -> void:
	var items := WritingRules.items()
	assert_eq(items.size(), GameData.TECHNOLOGIES.size() + 8, "a book per technology, a blueprint per station recipe and project")
	for tid: String in GameData.TECHNOLOGIES:
		var book := WritingRules.item_for(tid)
		assert_eq(book, "Book" + tid, "%s has a book" % tid)
		assert_eq(WritingRules.of(book), { "writing": "Book", "teaches": tid, "kind": "technology" }, "which teaches it")
	assert_eq(WritingRules.of(BED_PRINT)["kind"], "station", "a station recipe blueprint")
	assert_eq(WritingRules.of("BlueprintPalisade"), { "writing": "Blueprint", "teaches": "palisade", "kind": "project" }, "a project blueprint")
	assert_eq(WritingRules.of("Thornwood"), {}, "a material is not a writing")
	assert_eq(WritingRules.of("nope"), {}, "nor is an unknown key")
	assert_eq(WritingRules.station("Book"), "", "a book is written anywhere")
	assert_eq(WritingRules.station("Blueprint"), "carpentry bench", "a blueprint at a carpentry bench")
	assert_eq(WritingRules.cost("Book"), { "Duskfiber": 2, "ThornwoodPlank": 1 }, "the book's fabric cost")
	assert_eq(WritingRules.cost("Blueprint"), { "Duskfiber": 3 }, "the blueprint's")
	for item_id: String in items:
		var res: Resource = GameData.ITEMS[item_id]
		assert_true(bool(res.get("stackable")), "%s stacks" % item_id)

func _test_read_book() -> void:
	var r := _rig()
	var tech: Node = r["tech"]
	var w: Node = r["w"]
	_give(r, "p1", BOOK, 1)
	assert_false(tech.is_unlocked("TechBasicSmithing", "p1"), "p1 has not researched smithing")
	var unlocked: Array = []
	var cb := func(tid: String, pid: String) -> void: unlocked.append([tid, pid])
	GameBus.technology_unlocked.connect(cb)
	assert_eq(w.resolve("read", BOOK, "p1"), "", "p1 reads the book")
	GameBus.technology_unlocked.disconnect(cb)
	assert_true(tech.is_unlocked("TechBasicSmithing", "p1"), "the reader unlocks its technology")
	assert_eq(unlocked, [["TechBasicSmithing", "p1"]], "announced like finished research, for the reader")
	assert_true(tech.is_recipe_unlocked("RecipeFerritePick", "p1"), "and its recipes")
	assert_eq(_count(r, "p1", BOOK), 1, "the book is kept")
	assert_false(tech.is_unlocked("TechBasicSmithing", "p2"), "a player who has not read it is unchanged")
	assert_eq(tech.get_statuses("p2"), tech.get_statuses("nobody"), "p2's whole tree is untouched")
	# Lent: the same book in another pack teaches its new reader.
	assert_true(r["reg"].get_inventory("p1").consume_items({ BOOK: 1 }), "p1 hands the book over")
	_give(r, "p2", BOOK, 1)
	assert_eq(w.resolve("read", BOOK, "p2"), "", "p2 reads the lent book")
	assert_true(tech.is_unlocked("TechBasicSmithing", "p2"), "and learns it")
	_free_rig(r)

func _test_write_unknown_refused() -> void:
	var r := _rig()
	var w: Node = r["w"]
	_give_cost(r, "p1", BOOK)
	var seen: Array = []
	var cb := func(pid: String, action: String, item: String, ok: bool, why: String) -> void: seen.append([pid, action, item, ok, why])
	GameBus.writing_resolved.connect(cb)
	assert_eq(w.resolve("write", BOOK, "p1"), "not_known", "writing about a technology the writer does not know is refused")
	GameBus.writing_resolved.disconnect(cb)
	assert_eq(seen, [["p1", "write", BOOK, false, "not_known"]], "the refusal is announced to the writer")
	assert_eq(_count(r, "p1", BOOK), 0, "no book")
	assert_eq(_count(r, "p1", "Duskfiber"), 2, "and nothing paid")
	assert_eq(w.resolve("write", "Thornwood", "p1"), "unknown_writing", "a non-writing item cannot be written")
	assert_eq(w.resolve("fly", BOOK, "p1"), "unknown_writing", "nor can an unknown action run")
	_free_rig(r)

func _test_write_pays() -> void:
	var r := _rig()
	var tech: Node = r["tech"]
	var w: Node = r["w"]
	tech.apply_statuses({ "TechBasicSmithing": "unlocked" }, "p1")
	assert_eq(w.resolve("write", BOOK, "p1"), "missing_materials", "a writer without the cost is refused")
	_give(r, "p1", "Duskfiber", 2)
	assert_eq(w.resolve("write", BOOK, "p1"), "missing_materials", "a part of the cost is not enough")
	assert_eq(_count(r, "p1", "Duskfiber"), 2, "and is not taken")
	_give(r, "p1", "ThornwoodPlank", 1)
	assert_eq(w.resolve("write", BOOK, "p1"), "", "a writer who knows it and carries the cost writes")
	assert_eq(_count(r, "p1", BOOK), 1, "the book is in the pack")
	assert_eq([_count(r, "p1", "Duskfiber"), _count(r, "p1", "ThornwoodPlank")], [0, 0], "the cost is paid")
	_free_rig(r)

func _test_blueprint() -> void:
	var r := _rig()
	var tech: Node = r["tech"]
	var w: Node = r["w"]
	var crafting := CraftingSlice.new()
	crafting.technology_slice = tech
	assert_false(tech.is_recipe_unlocked("RecipeBed", "p2"), "p2 cannot make a bed")
	assert_true(crafting._check_tech_gate("RecipeBed", "p2") != "", "the craft gate refuses it")
	tech.apply_statuses({ "TechBasicCarpentry": "unlocked" }, "p1")
	assert_true(tech.knows("station", "RecipeBed", "p1"), "p1 knows the bed from carpentry")
	_give_cost(r, "p1", BED_PRINT)
	assert_eq(w.resolve("write", BED_PRINT, "p1"), "station_required", "a blueprint is drawn at its station")
	r["station"]["type"] = "forge"
	assert_eq(w.resolve("write", BED_PRINT, "p1"), "station_required", "the right station")
	r["station"]["type"] = "carpentry bench"
	assert_eq(w.resolve("write", BED_PRINT, "p1"), "", "at a carpentry bench p1 draws it")
	assert_eq(_count(r, "p1", BED_PRINT), 1, "the blueprint is in p1's pack")
	assert_true(r["reg"].get_inventory("p1").consume_items({ BED_PRINT: 1 }), "p1 gives it away")
	_give(r, "p2", BED_PRINT, 1)
	assert_eq(w.resolve("read", BED_PRINT, "p2"), "", "p2 reads it")
	assert_true(tech.is_recipe_unlocked("RecipeBed", "p2"), "a blueprint teaches its recipe")
	assert_eq(crafting._check_tech_gate("RecipeBed", "p2"), "", "the craft gate lets p2 make a bed")
	assert_false(tech.is_unlocked("TechBasicCarpentry", "p2"), "without the technology")
	assert_false(tech.is_recipe_unlocked("RecipeChest", "p2"), "or the technology's other recipes")
	assert_eq(_count(r, "p2", BED_PRINT), 1, "the blueprint is kept")
	assert_eq(w.resolve("read", BED_PRINT, "p2"), "already_known", "reading it again teaches nothing new")
	crafting.free()
	_free_rig(r)

func _test_project_blueprint() -> void:
	var r := _rig()
	var tech: Node = r["tech"]
	var w: Node = r["w"]
	r["station"]["type"] = "carpentry bench"
	# A palisade takes planks and ferrite ingots: knowing it is knowing how to make both.
	assert_false(tech.knows("project", "palisade", "p1"), "p1 cannot make a palisade's materials")
	_give_cost(r, "p1", "BlueprintPalisade")
	assert_eq(w.resolve("write", "BlueprintPalisade", "p1"), "not_known", "so cannot draw it")
	tech.apply_statuses({ "TechBasicCarpentry": "unlocked" }, "p1")
	assert_false(tech.knows("project", "palisade", "p1"), "planks alone are not enough")
	tech.apply_statuses({ "TechBasicCarpentry": "unlocked", "TechBasicSmithing": "unlocked" }, "p1")
	assert_true(tech.knows("project", "palisade", "p1"), "planks and ingots are")
	assert_eq(w.resolve("write", "BlueprintPalisade", "p1"), "", "p1 draws the palisade")
	_give(r, "p2", "BlueprintPalisade", 1)
	assert_false(tech.knows("project", "palisade", "p2"), "p2 does not know it")
	assert_eq(w.resolve("read", "BlueprintPalisade", "p2"), "", "until reading the blueprint")
	assert_true(tech.knows("project", "palisade", "p2"), "which teaches the project")
	assert_false(tech.is_unlocked("TechBasicSmithing", "p2"), "and nothing else")
	_free_rig(r)

func _test_read_refusals() -> void:
	var r := _rig()
	var tech: Node = r["tech"]
	var w: Node = r["w"]
	assert_eq(w.resolve("read", BOOK, "p1"), "not_held", "a book not in the pack cannot be read")
	_give(r, "p1", "BookTechMasterForge", 1)
	assert_eq(w.resolve("read", "BookTechMasterForge", "p1"), "prerequisite_locked", "a book does not skip the tree")
	assert_false(tech.is_unlocked("TechMasterForge", "p1"), "nothing is learnt")
	_give(r, "p1", BOOK, 1)
	assert_eq(w.resolve("read", BOOK, "p1"), "", "the prerequisite first")
	assert_eq(w.resolve("read", "BookTechMasterForge", "p1"), "", "then the master forge")
	assert_eq(w.resolve("read", BOOK, "p1"), "already_known", "a known technology is refused")
	assert_eq(_count(r, "p1", BOOK), 1, "and the book is still kept")
	_free_rig(r)

func _test_persistence() -> void:
	var r := _rig()
	var tech: Node = r["tech"]
	tech.apply_statuses({ "TechBasicCarpentry": "unlocked" }, "p1")
	assert_eq(tech.learn("station", "RecipeBed", "p1"), "already_known", "a craftable recipe is known already")
	assert_eq(tech.learn("station", "RecipeFerritePick", "p1"), "", "a recipe is learnt")
	assert_eq(tech.learn("project", "watchtower", "p1"), "", "and a project")
	assert_eq(tech.learn("project", "moon", "p1"), "unknown", "an unknown project is not")
	var snap: Dictionary = tech.get_statuses("p1")
	assert_eq(snap[TechnologySlice.LEARNT_KEY], ["RecipeFerritePick", "watchtower"], "the snapshot carries what was learnt, sorted")
	var other := TechnologySlice.new()
	add_child(other)
	var raw := snap.duplicate()
	raw[TechnologySlice.LEARNT_KEY] = ["RecipeFerritePick", "watchtower", "RecipeNothing", 7]
	other.apply_statuses(raw, "p1")
	assert_true(other.is_recipe_unlocked("RecipeFerritePick", "p1"), "a loaded record keeps a learnt recipe")
	assert_true(other.knows("project", "watchtower", "p1"), "and project")
	assert_eq(other.get_statuses("p1")[TechnologySlice.LEARNT_KEY], ["RecipeFerritePick", "watchtower"], "stray entries are dropped")
	other.apply_statuses({}, "p1")
	assert_false(other.is_recipe_unlocked("RecipeFerritePick", "p1"), "a legacy record learnt nothing")
	other.free()
	_free_rig(r)

func _test_rate() -> void:
	var r := _rig()
	var w: Node = r["w"]
	w.now_ms = func() -> int: return 5000
	assert_eq(w.resolve("read", BOOK, "p1"), "not_held", "the first intent is resolved")
	assert_eq(w.resolve("read", BOOK, "p1"), "rate", "a second within the gap is refused")
	assert_eq(w.resolve("read", BOOK, "p2"), "not_held", "another player is not held back")
	_free_rig(r)

func _test_wire() -> void:
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.set_transport(MemoryTransport.new([9]))
	var seen: Array = []
	var cb := func(action: String, item: String, pid: String) -> void: seen.append([action, item, pid])
	GameBus.writing_intent.connect(cb)
	n._route_c2h(9, { "type": "writing_intent", "action": "read", "item_id": BOOK, "player_id": "p2" })
	assert_eq(seen.size(), 0, "an un-handshaked peer's intent is dropped")
	n.set_player_id(9, "p3")
	n._route_c2h(9, { "type": "writing_intent", "action": "read", "item_id": BOOK, "player_id": "p1" })
	n._route_c2h(9, { "type": "writing_intent", "action": "write", "item_id": [BOOK] })
	assert_eq(seen, [["read", BOOK, "p3"], ["write", "", "p3"]], "the host binds the connection's player and keeps only a string item")
	GameBus.writing_intent.disconnect(cb)
	n.free()
	var c := NetworkingSlice.new()
	add_child(c)
	c._role = NetworkingSlice.Role.CLIENT
	c.set_transport(MemoryTransport.new([1]))
	assert_true(GameBus.writing_intent.is_connected(c._m2.forward_writing_intent), "a client forwards writing intents")
	c.free()
	var client := WritingSlice.new()
	client.is_host = false
	add_child(client)
	var resolved: Array = []
	var rc := func(_p: String, _a: String, _i: String, _ok: bool, _w: String) -> void: resolved.append(true)
	GameBus.writing_resolved.connect(rc)
	GameBus.writing_intent.emit("read", BOOK, "")
	GameBus.writing_resolved.disconnect(rc)
	assert_eq(resolved.size(), 0, "a client's writing slice resolves nothing")
	client.free()

func _test_ui() -> void:
	var r := _rig()
	var tech: Node = r["tech"]
	var ui := UiSliceScript.new()
	ui.technology_slice = tech
	var labels: Array = []
	for a: Dictionary in ui.item_actions(BOOK, {}):
		labels.append(str(a["action"]))
	assert_true(labels.has("read"), "a book offers Read")
	assert_false(ui.item_actions("Thornwood", {}).any(func(a: Dictionary) -> bool: return str(a["action"]) == "read"), "a material does not")
	assert_eq(UiSliceScript.action_intent(BOOK, "read"), { "signal": "writing_intent", "args": ["read", BOOK, ""] }, "Read is a writing intent")
	var seen: Array = []
	var cb := func(action: String, item: String, pid: String) -> void: seen.append([action, item, pid])
	GameBus.writing_intent.connect(cb)
	assert_true(ui.dispatch_item_action(BOOK, "read"), "dispatched")
	ui._m2.write_pressed(BED_PRINT)
	GameBus.writing_intent.disconnect(cb)
	assert_eq(seen, [["read", BOOK, ""], ["write", BED_PRINT, ""]], "the window sends read and write to the host")
	var rows: Array = ui._m2.writing_rows()
	assert_eq(rows.size(), WritingRules.items().size(), "a row per writing")
	var writable := rows.filter(func(row: Dictionary) -> bool: return bool(row["can_write"]))
	assert_eq(writable.size(), 0, "nothing is writable before anything is known")
	tech.apply_statuses({ "TechBasicCarpentry": "unlocked" }, "host")
	var ids: Array = ui._m2.writing_rows().filter(func(row: Dictionary) -> bool: return bool(row["can_write"])).map(func(row: Dictionary) -> String: return str(row["id"]))
	assert_true(ids.has("BookTechBasicCarpentry") and ids.has(BED_PRINT), "carpentry makes its book and the bed's blueprint writable")
	assert_false(ids.has(BOOK), "but not smithing's")
	ui.free()
	_free_rig(r)

func _test_learn_guards() -> void:
	var r := _rig()
	var tech: Node = r["tech"]
	var w: Node = r["w"]
	tech.apply_statuses({ "TechBasicSmithing": "researching" }, "p1")
	_give(r, "p1", BOOK, 1)
	assert_eq(w.resolve("read", BOOK, "p1"), "researching", "a book does not cut short research already paid for")
	assert_eq(tech.get_status("TechBasicSmithing", "p1"), "researching", "and the research goes on")
	assert_eq(tech.learn("station", "RecipeAshiteBlock", "p2"), "prerequisite_locked:TechBasicSmithing", "a blueprint does not skip the tree")
	assert_false(tech.is_recipe_unlocked("RecipeAshiteBlock", "p2"), "nothing is learnt")
	tech.apply_statuses({ "TechBasicSmithing": "unlocked" }, "p2")
	assert_eq(tech.learn("station", "RecipeAshiteBlock", "p2"), "", "with the prerequisite, the recipe alone is learnt")
	assert_true(tech.is_recipe_unlocked("RecipeAshiteBlock", "p2"), "and craftable")
	_free_rig(r)

func _test_knows_materials() -> void:
	var r := _rig()
	var tech: Node = r["tech"]
	assert_false(tech.knows_materials([], "p1"), "a project with no materials is not known by default")
	assert_false(tech.knows_materials([{ "item": "Thornwood", "quantity": 4 }], "p1"), "nor one of gathered materials")
	tech.apply_statuses({ "TechBasicCarpentry": "unlocked" }, "p1")
	assert_true(tech.knows_materials([{ "item": "ThornwoodPlank", "quantity": 1 }, { "item": "Thornwood", "quantity": 1 }], "p1"),
		"crafted materials the player can make are enough; gathered ones need nothing")
	# Every recipe that outputs an item is indexed, not only the last one read.
	var missing: Array = []
	for recipe_id in GameData.RECIPES:
		var recipe: Variant = GameData.RECIPES[recipe_id].get("recipe")
		if recipe is Dictionary:
			for out: Variant in recipe.get("outputs", []):
				if out is Dictionary and not (tech._item_recipe.get(str(out.get("item", "")), []) as Array).has(str(recipe_id)):
					missing.append(recipe_id)
	assert_eq(missing, [], "each recipe is indexed under its outputs")
	_free_rig(r)

func _test_rate_bounded() -> void:
	var r := _rig()
	var w: Node = r["w"]
	var t := [0]
	w.now_ms = func() -> int: return t[0]
	for i in WritingSlice.MAX_TRACKED:
		w.resolve("read", BOOK, "gone%d" % i)
	t[0] = WritingSlice.GAP_MS * 4
	assert_eq(w.resolve("read", BOOK, "p1"), "not_held", "a new writer is resolved")
	assert_eq(w._last_ms.size(), 1, "and the players who stopped writing are dropped")
	_free_rig(r)

func _test_ui_text() -> void:
	var ui := UiSliceScript.new()
	var row := { "writing": "Book", "teaches": "TechBasicSmithing" }
	assert_eq(ui._m2.writing_name(row), I18nScript.t("writing.name.book", ["TechBasicSmithing"]), "a book is named from the locale")
	assert_eq(ui._m2.station_name("carpentry bench"), I18nScript.t("station.carpentry_bench"), "a station too")
	assert_eq(ui._m2.station_name(""), I18nScript.t("station.anywhere"), "and anywhere")
	for item_id: String in WritingRules.items():
		var w := WritingRules.of(item_id)
		var keys := ["writing.name.%s" % str(w["writing"]).to_lower(), "writing.ok.write_%s" % str(w["writing"]).to_lower()]
		var station := WritingRules.station(str(w["writing"]))
		if station != "":
			keys.append("station." + station.replace(" ", "_"))
		for key: String in keys:
			assert_true(I18nScript.has_key(key), "%s has %s" % [item_id, key])
	for code: String in WritingSlice.REASONS:
		assert_true(I18nScript.has_key("writing.refused." + code), "writing.refused.%s is in the locale" % code)
	ui._technology_feedback = Label.new()
	ui._on_research_resolved({ "tech_id": "TechBasicSmithing", "success": true, "reason": "learnt", "status": "unlocked", "player_id": "" })
	assert_eq(ui._technology_feedback.text, I18nScript.t("ui.tech_unlocked", ["TechBasicSmithing"]), "a read book says it is known, not researching")
	ui._on_research_resolved({ "tech_id": "TechBasicSmithing", "success": true, "reason": "", "status": "researching", "player_id": "" })
	assert_eq(ui._technology_feedback.text, I18nScript.t("ui.researching", ["TechBasicSmithing"]), "research begun still says researching")
	ui._technology_feedback.free()
	ui.free()
