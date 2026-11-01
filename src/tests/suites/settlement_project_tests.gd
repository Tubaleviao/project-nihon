extends "res://src/tests/test_support.gd"
## Phase 198 — settlement projects at runtime: the rules, contributions, completion and its structure,
## persistence and the board. Phase 207 — no labour: the last material completes a project, which changes
## nothing but itself.

const SettlementSlice := preload("res://src/settlement/settlement_slice.gd")
const ProjectRules := preload("res://src/settlement/project_rules.gd")
const SpecialtyRules := preload("res://src/settlement/specialty_rules.gd")

func register() -> void:
	_run_test("project rules: contributions are checked, each refusal has its own key", _test_rules_contribution)
	_run_test("project rules: completion and layouts", _test_rules_shape)
	_run_test("project: start, contribute from bag and stockpile", _test_project_flow)
	_run_test("project: the contribution of its last material completes it and places its structure", _test_project_complete)
	_run_test("project: completing one changes no clan-level value but the project", _test_project_completion_isolated)
	_run_test("project: a saved project with labour left completes on load once its materials are in", _test_project_saved_labour)
	_run_test("project (audit): no labour code remains", _test_no_labour_code)
	_run_test("project: state survives save and load, a pre-198 world loads with none", _test_project_persistence)
	_run_test("project: intents resolve through the bus with keyed refusals", _test_project_intents)
	_run_test("project: every refusal and board string has catalog text, every action fits the wire", _test_project_strings)

func _rig() -> Dictionary:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("host")
	for p in ["p1", "p2", "p3", "p4"]:
		reg.ensure_player(p)
	var s := SettlementSlice.new()
	s.registry = reg
	add_child(s)
	var now := [1000000.0]
	s.now_sec = func() -> float: return now[0]
	s.mono_sec = func() -> float: return now[0]
	var where := { "p1": Vector2(10.0, 10.0), "p2": Vector2(12.0, 10.0), "p3": Vector2(900.0, 900.0), "p4": Vector2(11.0, 11.0) }
	s.position_of = func(pid: String) -> Variant: return where.get(pid, null)
	var placed: Array = []
	s.place_structure = func(id: String, key: String, site: Dictionary) -> void: placed.append([id, key, site])
	return { "reg": reg, "s": s, "now": now, "where": where, "placed": placed }

func _free_rig(rig: Dictionary) -> void:
	rig["s"].free()
	rig["reg"].free()

func _give(rig: Dictionary, pid: String, item: String, n: int) -> void:
	assert_true(rig["reg"].get_inventory(pid).add_item(item, n), "%s gets %d %s" % [pid, n, item])

## p1 founds at (10, 10); p2 joins as a member.
func _village(rig: Dictionary) -> String:
	var s: SettlementSlice = rig["s"]
	assert_eq(s.found("p1", "Oak", Vector2(10.0, 10.0)), "", "p1 founds")
	assert_eq(s.invite("p1", "p2"), "", "p1 invites p2")
	assert_eq(s.join("p2", "settlement_1"), "", "p2 joins")
	return "settlement_1"

func _test_rules_contribution() -> void:
	var def := ProjectRules.def_of("palisade")
	assert_false(def.is_empty(), "the fabric has a palisade")
	var state := { "status": "building", "given": { "ThornwoodPlank": 30 } }
	assert_eq(ProjectRules.contribution_blocker(def, state, "ThornwoodPlank", 10), "", "the last ten planks are accepted")
	assert_eq(ProjectRules.contribution_blocker(def, state, "AshiteBlock", 1), "unknown_item", "a material it does not use")
	assert_eq(ProjectRules.contribution_blocker(def, state, "ThornwoodPlank", 11), "too_much", "more planks than it needs")
	assert_eq(ProjectRules.contribution_blocker(def, state, "ThornwoodPlank", 0), "bad_args", "zero")
	assert_eq(ProjectRules.contribution_blocker({}, state, "ThornwoodPlank", 1), "unknown_project", "no such project")
	assert_eq(ProjectRules.contribution_blocker(def, { "status": "done", "given": {} }, "ThornwoodPlank", 1), "project_done", "a finished project")
	var member := { "take": true, "withdrawLimit": 50 }
	assert_eq(ProjectRules.stock_draw_blocker("member", member, 40, 10), "", "a member draws up to the limit")
	assert_eq(ProjectRules.stock_draw_blocker("member", member, 40, 11), "over_limit", "past the limit")
	assert_eq(ProjectRules.stock_draw_blocker("founder", { "take": true, "withdrawLimit": 0 }, 900, 100), "", "the founder has no limit")
	assert_eq(ProjectRules.stock_draw_blocker("guest", { "take": false, "withdrawLimit": 0 }, 0, 1), "no_permission", "a guest takes nothing")
	assert_eq(ProjectRules.start_blocker("watchtower", "founded", {}), "tier_too_low", "the watchtower needs growing")
	assert_eq(ProjectRules.start_blocker("watchtower", "growing", {}), "", "a growing village may raise it")
	assert_eq(ProjectRules.start_blocker("palisade", "founded", { "palisade": {} }), "project_exists", "each structure once")
	assert_eq(ProjectRules.start_blocker("moat", "town", {}), "unknown_project", "an unknown key")
	var busy := { "a": { "status": "building" }, "b": { "status": "building" }, "c": { "status": "building" } }
	assert_eq(ProjectRules.start_blocker("palisade", "founded", busy), "too_many_projects", "three under way is the cap")

func _test_rules_shape() -> void:
	var def := ProjectRules.def_of("storehouse")
	assert_false(def.has("labour"), "the runtime table holds no labour steps")
	var full := { "status": "building", "given": ProjectRules.needed_materials(def) }
	assert_true(ProjectRules.is_complete(def, full), "materials in: complete, with no work done")
	var short: Dictionary = full.duplicate(true)
	short["given"]["ThornwoodPlank"] = int(short["given"]["ThornwoodPlank"]) - 1
	assert_false(ProjectRules.is_complete(def, short), "a plank short")
	var done := { "storehouse": { "status": "done" }, "palisade": { "status": "building" } }
	# Phase 205 — projects have no effects: a standing storehouse adds no stockpile stacks.
	assert_false(ProjectRules.def_of("storehouse").has("effects"), "no project carries effects")
	assert_eq(ProjectRules.completed_count(done), 1, "one done")
	for layout in ["ring", "tower", "hall", "shed"]:
		var cells := ProjectRules.layout_cells(layout, 40)
		assert_eq(cells.size(), 40, "%s fills exactly its block count" % layout)
		var seen := {}
		for c: Vector3i in cells:
			seen[c] = true
		assert_eq(seen.size(), 40, "%s cells are distinct" % layout)
	assert_eq(ProjectRules.station_offsets(2), [Vector2i(-1, 0), Vector2i(1, 0)], "two stations side by side")
	assert_eq(ProjectRules.block_material("AshiteBlock"), "Ashite", "an AshiteBlock builds Ashite")
	assert_eq(ProjectRules.block_material("ThornwoodPlank"), "Thornwood", "a plank builds Thornwood")

func _test_project_flow() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	var id := _village(rig)
	assert_eq(s.start_project("p2", "storehouse"), "no_permission", "a member cannot start a project")
	assert_eq(s.start_project("p3", "storehouse"), "not_member", "an outsider cannot")
	assert_eq(s.start_project("p1", "watchtower"), "tier_too_low", "the watchtower waits for growing")
	# Phase 206 — a project site inside the circle of a clan the starter is not in is refused.
	s.build_blocked = func(pid: String, _xz: Vector2) -> bool: return pid == "p1"
	assert_eq(s.start_project("p1", "storehouse"), "foreign_circle", "not inside another clan's circle")
	assert_true(s.projects_of(id).is_empty(), "and nothing is started")
	s.build_blocked = Callable()
	assert_eq(s.start_project("p1", "storehouse"), "", "the founder starts the storehouse")
	assert_eq(s.start_project("p1", "storehouse"), "project_exists", "not twice")
	_give(rig, "p2", "ThornwoodPlank", 40)
	assert_eq(s.contribute("p2", "storehouse", "ThornwoodPlank", 31), "too_much", "more than it needs")
	assert_eq(s.contribute("p2", "storehouse", "FerriteIngot", 1), "unknown_item", "not a storehouse material")
	assert_eq(s.contribute("p3", "storehouse", "ThornwoodPlank", 1), "not_member", "an outsider's contribution")
	assert_eq(s.contribute("p2", "storehouse", "ThornwoodPlank", 30), "", "p2 brings the planks")
	assert_eq(rig["reg"].get_inventory("p2").get_item_count("ThornwoodPlank"), 10, "they left p2's pack")
	# Stockpile: p2 is a member (limit 50 a day).
	_give(rig, "p1", "AshiteBlock", 12)
	assert_eq(s.deposit("p1", "AshiteBlock", 12), "", "p1 stocks blocks")
	_give(rig, "p1", "Thornwood", 45)
	assert_eq(s.deposit("p1", "Thornwood", 45), "", "and logs")
	assert_eq(s.withdraw("p2", "Thornwood", 45), "", "p2 withdraws 45 today")
	assert_eq(s.contribute("p2", "storehouse", "AshiteBlock", 6, "stock"), "over_limit", "45 + 6 is over the member limit")
	assert_eq(s.contribute("p2", "storehouse", "AshiteBlock", 5, "stock"), "", "45 + 5 fits")
	assert_eq(int(s.stock_of(id)["AshiteBlock"]), 7, "taken from the stockpile")
	assert_eq(s.contribute("p1", "storehouse", "AshiteBlock", 6, "stock"), "", "the founder draws all but one")
	var p: Dictionary = s.projects_of(id)["storehouse"]
	assert_eq(int(p["contributors"]["p2"]["items"]), 35, "p2's 35 materials are recorded")
	assert_eq(str(p["status"]), "building", "still building")
	assert_false(p.has("work"), "a project records no work")
	var view: Dictionary = s.private_view("p2")["mine"]
	assert_eq((view["projects"] as Array).size(), 1, "members see the project")
	assert_false((view["projects"][0] as Dictionary).has("step"), "with no labour step")
	assert_eq((s.private_view("p3")["mine"] as Dictionary).size(), 0, "an outsider sees none of it")
	_free_rig(rig)

func _test_project_complete() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	var id := _village(rig)
	var cap := s.capacity_stacks(id)
	for key in ["storehouse", "palisade"]:
		assert_eq(s.start_project("p1", key), "", "start %s" % key)
		var need := ProjectRules.needed_materials(ProjectRules.def_of(key))
		var items: Array = need.keys()
		for i in items.size():
			var item: String = items[i]
			var n := int(need[item])
			_give(rig, "p1", item, n)
			if i == items.size() - 1:
				assert_eq(s.contribute("p1", key, item, n - 1), "", "%s gets all but one %s" % [key, item])
				assert_eq(str(s.projects_of(id)[key]["status"]), "building", "%s is one short: still building" % key)
				assert_eq(s.contribute("p1", key, item, 1), "", "%s gets its last %s" % [key, item])
				assert_eq(str(s.projects_of(id)[key]["status"]), "done", "%s completes on the last material" % key)
			else:
				assert_eq(s.contribute("p1", key, item, n), "", "%s gets its %s" % [key, item])
		assert_eq(s.contribute("p1", key, items[0], 1), "project_done", "%s takes nothing more" % key)
	var projects: Dictionary = s.projects_of(id)
	assert_eq(str(projects["storehouse"]["status"]), "done", "the storehouse completes")
	assert_eq((rig["placed"] as Array).size(), 2, "two structures placed")
	assert_eq(str(rig["placed"][0][1]), "storehouse", "the storehouse is placed")
	assert_eq(s.capacity_stacks(id), cap, "a standing storehouse adds no capacity (no project effects since Phase 205)")
	assert_eq(s.tier_for(id, float(rig["now"][0])), "founded", "two members are short of growing")
	assert_eq(s.invite("p1", "p4"), "", "invite p4")
	assert_eq(s.join("p4", id), "", "p4 joins: three members")
	assert_eq(s.tier_for(id, float(rig["now"][0])), "founded", "projects count toward no tier: growing still waits for its days")
	rig["now"][0] += 3.0 * SettlementSlice.DAY_SEC
	assert_eq(s.tier_for(id, float(rig["now"][0])), "growing", "three members and three days reach growing")
	_free_rig(rig)

## Phase 207 — completing a project changes nothing at the clan level: not the tier, the stockpile, the
## members, their skills or attributes, or any other project; only the project itself.
func _test_project_completion_isolated() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	var reg: Node = rig["reg"]
	var id := _village(rig)
	assert_eq(s.invite("p1", "p4"), "", "invite p4")
	assert_eq(s.join("p4", id), "", "p4 joins: three members, growing's count")
	_give(rig, "p1", "Thornwood", 10)
	assert_eq(s.deposit("p1", "Thornwood", 10), "", "a stocked village")
	assert_eq(s.start_project("p1", "storehouse"), "", "a second project under way")
	assert_eq(s.start_project("p1", "palisade"), "", "the palisade")
	var need := ProjectRules.needed_materials(ProjectRules.def_of("palisade"))
	for item: String in need:
		_give(rig, "p2", item, int(need[item]))
	var before: Dictionary = s.get_settlement(id).duplicate(true)
	var skills_before := {}
	for pid in ["p1", "p2", "p4"]:
		skills_before[pid] = [reg.get_record(pid).get("skill_xp", {}).duplicate(true), reg.get_attributes(pid)]
	for item: String in need:
		assert_eq(s.contribute("p2", "palisade", item, int(need[item])), "", "p2 brings the palisade's %s" % item)
	s.tick(float(rig["now"][0]))
	var after: Dictionary = s.get_settlement(id).duplicate(true)
	assert_eq(str(after["projects"]["palisade"]["status"]), "done", "the palisade is done")
	for k: String in before:
		if k == "projects" or k == "last_active":
			continue
		assert_eq(after[k], before[k], "completion leaves the settlement's %s alone" % k)
	assert_eq(after["projects"]["storehouse"], before["projects"]["storehouse"], "and the other project")
	for pid in ["p1", "p2", "p4"]:
		assert_eq([reg.get_record(pid).get("skill_xp", {}), reg.get_attributes(pid)], skills_before[pid], "%s gains no skill or attribute from it" % pid)
	_free_rig(rig)

## Phase 207 — a pre-207 save may hold a project with every material in and labour still to do: it completes
## (and is placed) on the next tick; one still short of materials stays building.
func _test_project_saved_labour() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	var id := _village(rig)
	assert_eq(s.start_project("p1", "palisade"), "", "start the palisade")
	assert_eq(s.start_project("p1", "storehouse"), "", "and the storehouse")
	var data: Dictionary = JSON.parse_string(JSON.stringify(s.to_data()))
	var pal: Dictionary = data["settlements"][id]["projects"]["palisade"]
	pal["given"] = ProjectRules.needed_materials(ProjectRules.def_of("palisade"))
	pal["work"] = 3.0   # a pre-207 record's labour, long gone from the rules
	pal["contributors"] = { "p1": { "items": 40, "work": 3.0 } }
	s.from_data(data)
	assert_eq(str(s.projects_of(id)["palisade"]["status"]), "building", "loaded as it was saved")
	assert_false(s.projects_of(id)["palisade"].has("work"), "its labour is dropped")
	s.tick(float(rig["now"][0]))
	assert_eq(str(s.projects_of(id)["palisade"]["status"]), "done", "the tick completes it")
	assert_eq((rig["placed"] as Array).size(), 1, "and places it once")
	assert_eq(str(s.projects_of(id)["storehouse"]["status"]), "building", "a project short of materials keeps building")
	s.tick(float(rig["now"][0]))
	assert_eq((rig["placed"] as Array).size(), 1, "a second tick places nothing more")
	_free_rig(rig)

## Phase 207 — the labour stage is gone from the runtime: its constants, clock, tool check, steps, intent,
## specialty bonus and catalog text.
func _test_no_labour_code() -> void:
	var files := ["res://src/settlement/settlement_slice.gd", "res://src/settlement/project_rules.gd", "res://src/settlement/specialty_rules.gd",
		"res://src/settlement/settlement_wiring.gd", "res://src/ui/settlement_panel.gd"]
	var banned := ["LABOUR_GAP_SEC", "SITE_RADIUS", "LABOUR_HOLD", "_labour_clock", "tool_in_hand", "func labour(", "labour_bonus",
		"labour_multiplier", "bonusLabour", "workSecondsPerUnit", "total_work", "current_step", "work_units", "is_tool_item",
		"project_work", "minProjects", "LABOUR_BEAT_SEC"]
	for path: String in files:
		var src := FileAccess.get_file_as_string(path)
		assert_true(src.length() > 0, "%s reads" % path)
		for word: String in banned:
			assert_false(src.contains(word), "%s has no %s" % [path.get_file(), word])
	assert_false(SettlementSlice.ACTIONS.has("project_work"), "no work intent")
	assert_false(SettlementSlice.REASONS.has("labour_done") or SettlementSlice.REASONS.has("no_tool"), "no labour refusals")
	assert_false(I18nScript.has_key("settlement.project_work"), "no Work here button text")
	assert_false(SpecialtyRules.table().has("bonusLabour"), "the specialty table has no labour bonus")

func _test_project_persistence() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	var id := _village(rig)
	assert_eq(s.start_project("p1", "palisade"), "", "start the palisade")
	_give(rig, "p1", "ThornwoodPlank", 12)
	assert_eq(s.contribute("p1", "palisade", "ThornwoodPlank", 12), "", "twelve planks")
	var data: Dictionary = s.to_data()
	assert_eq(int(data["format"]), SettlementSlice.DATA_FORMAT, "the record carries its format")
	var round := SettlementSlice.new()
	round.from_data(JSON.parse_string(JSON.stringify(data)))
	var p: Dictionary = round.projects_of(id)["palisade"]
	assert_eq(int(p["given"]["ThornwoodPlank"]), 12, "given materials survive")
	assert_eq(int(p["contributors"]["p1"]["items"]), 12, "contributors survive")
	# A pre-198 record (no format): no projects, even if the key is somehow there.
	var legacy: Dictionary = data.duplicate(true)
	legacy.erase("format")
	round.from_data(legacy)
	assert_eq(round.projects_of(id).size(), 0, "a pre-198 settlement loads with no projects")
	assert_true(round.get_settlement(id).has("projects"), "but has the field to start one")
	# Malformed: an unknown project, an over-full material, a bad site.
	var bad: Dictionary = data.duplicate(true)
	bad["settlements"][id]["projects"]["moat"] = { "site": { "x": 0, "z": 0 } }
	bad["settlements"][id]["projects"]["palisade"]["given"] = { "ThornwoodPlank": 9999, "Gold": 4 }
	round.from_data(bad)
	assert_false(round.projects_of(id).has("moat"), "an unknown project is dropped")
	assert_eq(round.projects_of(id)["palisade"]["given"], { "ThornwoodPlank": 40 }, "counts clamp to the need, unknown items drop")
	round.free()
	_free_rig(rig)

func _test_project_intents() -> void:
	var rig := _rig()
	_village(rig)
	# Another settlement slice may be listening on the bus too: read the last resolution, as the Phase 140
	# intent test does.
	var got: Array = []
	var on_res := func(pid: String, action: String, ok: bool, reason: String) -> void: got.append([pid, action, ok, reason])
	GameBus.settlement_resolved.connect(on_res)
	var events: Array = []
	var on_proj := func(_id: String, key: String, what: String, pid: String) -> void: events.append([key, what, pid])
	GameBus.settlement_project_changed.connect(on_proj)
	GameBus.settlement_intent.emit("project_start", { "project": "palisade" }, "p1")
	assert_eq(got.back(), ["p1", "project_start", true, ""], "the founder starts")
	assert_eq(events.back(), ["palisade", "started", "p1"], "the bus carries the start")
	rig["now"][0] += 1.0
	_give(rig, "p2", "ThornwoodPlank", 5)
	GameBus.settlement_intent.emit("project_give", { "project": "palisade", "item": "ThornwoodPlank", "qty": 5 }, "p2")
	assert_eq(got.back(), ["p2", "project_give", true, ""], "a member contributes")
	assert_eq(events.back(), ["palisade", "contributed", "p2"], "the bus carries the contribution")
	rig["now"][0] += 1.0
	GameBus.settlement_intent.emit("project_give", { "project": "palisade", "item": "ThornwoodPlank", "qty": 1 }, "p3")
	assert_eq(got.back(), ["p3", "project_give", false, "not_member"], "an outsider is refused")
	rig["now"][0] += 1.0
	GameBus.settlement_intent.emit("project_give", { "project": "palisade", "item": "ThornwoodPlank", "qty": 1, "from": "elsewhere" }, "p2")
	assert_eq(got.back(), ["p2", "project_give", false, "bad_args"], "an unknown source is refused")
	rig["now"][0] += 1.0
	GameBus.settlement_intent.emit("project_work", { "project": "palisade" }, "p2")
	assert_eq(got.back(), ["p2", "project_work", false, "unknown_action"], "the labour intent is gone (Phase 207)")
	GameBus.settlement_resolved.disconnect(on_res)
	GameBus.settlement_project_changed.disconnect(on_proj)
	_free_rig(rig)

func _test_project_strings() -> void:
	for action: String in SettlementSlice.ACTIONS:
		assert_true(action.length() <= 16, "action %s fits the 16 characters the wire keeps" % action)
	for code: String in SettlementSlice.REASONS:
		assert_true(I18nScript.has_key("settlement.refused." + code), "refusal %s has catalog text" % code)
	for action in ["project_start", "project_give"]:
		assert_true(I18nScript.has_key("settlement.ok." + action), "%s has a success line" % action)
	for key: String in (ProjectRules.table()["projects"] as Dictionary):
		assert_true(I18nScript.has_key("settlement.project." + key), "project %s has a name" % key)
