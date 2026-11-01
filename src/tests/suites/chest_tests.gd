extends "res://src/tests/test_support.gd"
## Phase 208 — chests and doors: access modes (owner, clan, everyone) and who may change them, a door at a
## member's private house in the clan's territory, putting and taking, lock picks (time, skill, tool break,
## the owner told) and breaking one open (time, spill), persistence, the stockpile migration and the wire.

const ChestSlice := preload("res://src/world/chest_slice.gd")
const ChestRules := preload("res://src/world/chest_rules.gd")
const ChestWiring := preload("res://src/world/chest_wiring.gd")
const StructureSlice := preload("res://src/structure/structure_slice.gd")
const StructureRules := preload("res://src/structure/structure_rules.gd")
const ClanSlice := preload("res://src/clan/clan_slice.gd")
const SettlementSlice := preload("res://src/settlement/settlement_slice.gd")
const WorkSkills := preload("res://src/character/work_skills.gd")

const AT := Vector3(10.5, 2.125, 10.5)

func register() -> void:
	_run_test("chest: the fabric places a chest and a door from their items, and the lockpick picks", _test_rules)
	_run_test("chest: owner-only refuses a clan member, clan refuses an outsider, everyone opens for anyone", _test_access_modes)
	_run_test("chest: only an owner changes the mode, any member for a clan chest", _test_mode_owner_only)
	_run_test("chest: doors follow the same rules, and a member's private house in clan territory lets members in", _test_doors)
	_run_test("chest: put and take move items between the pack and the chest, within reach and capacity", _test_put_take)
	_run_test("chest: a harder lock takes longer to pick and to break", _test_harder_lock)
	_run_test("chest: a finished pick opens it once, grants Lockpicking, and tells the owner", _test_pick)
	_run_test("chest: a failed pick can break the lockpick, and needs a lockpick at all", _test_pick_fails)
	_run_test("chest: a broken chest spills everything it held for anyone, and the station goes", _test_break_spills)
	_run_test("chest: chests and doors save and load, malformed entries and lost stations dropped", _test_persistence)
	_run_test("chest: a migrated settlement's stockpile becomes a clan chest with the same contents", _test_stockpile_migration)
	_run_test("chest (audit): the host reads the hit method, owner and chest from its own state, never the client", _test_audit_client_values)
	_run_test("chest: a client's view is sanitized, and the wire binds the identity", _test_wire)

# ── rig ──────────────────────────────────────────────────────────────────

## A registry with p1..p4, a clan "Oakhold" with p1 (founder) and p2 (member), a structure index on a flat
## voxel slice, and a chest slice whose players all stand at AT unless moved (`pos`).
func _rig() -> Dictionary:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("host")
	for p in ["p1", "p2", "p3", "p4"]:
		reg.ensure_player(p)
	var clans := ClanSlice.new()
	clans.registry = reg
	add_child(clans)
	var now := [1000000.0]
	clans.now_sec = func() -> float: return now[0]
	clans.mono_sec = func() -> float: return now[0]
	assert_eq(clans.found("p1", "Oakhold"), "", "p1 founds a clan")
	assert_eq(clans.invite("p1", "p2"), "", "p1 invites p2")
	assert_eq(clans.join("p2", "clan_1"), "", "p2 joins")
	var st := StructureSlice.new()
	st.registry = reg
	st.clans = clans
	st.now_hour = func() -> int: return 0
	st.mono_sec = func() -> float: return now[0]
	add_child(st)
	var v := _make_voxel()
	v.is_authoritative = true
	v.player_registry = reg
	v.structures = st
	st.remove_block = v.remove_structure_block
	var c := ChestSlice.new()
	c.registry = reg
	c.clans = clans
	c.structures = st
	var pos := {}
	var tech := {}
	var spilled: Array = []
	var removed: Array = []
	var roll := [0.99]
	c.position_of = func(pid: String) -> Variant: return pos.get(pid, AT)
	c.build_mode_of = st.build_mode
	c.tech_known = func(pid: String, t: String) -> bool: return (tech.get(pid, []) as Array).has(t)
	c.spill = func(item: String, qty: int, at: Vector3) -> void: spilled.append([item, qty, at])
	c.remove_station = func(id: String) -> void: removed.append(id)
	c.roll = func() -> float: return roll[0]
	c.mono_sec = func() -> float: return now[0]
	add_child(c)
	return { "reg": reg, "clans": clans, "st": st, "v": v, "c": c, "pos": pos, "tech": tech, "spilled": spilled,
		"removed": removed, "roll": roll, "now": now }

func _free_rig(r: Dictionary) -> void:
	for k: String in ["c", "v", "st", "clans", "reg"]:
		r[k].free()

func _online(r: Dictionary, pid: String, peer: int) -> void:
	r["reg"]._peer_ids[peer] = pid

func _give(r: Dictionary, pid: String, item: String, n: int) -> void:
	r["reg"].get_inventory(pid).add_item(item, n)

func _count(r: Dictionary, pid: String, item: String) -> int:
	return int(r["reg"].get_inventory(pid).get_item_count(item))

## The chest type and the door type from the fabric.
func _chest() -> String:
	return ChestRules.station_types().filter(func(t: String) -> bool: return ChestRules.holds_items(t))[0]

func _door() -> String:
	return ChestRules.station_types().filter(func(t: String) -> bool: return not ChestRules.holds_items(t))[0]

# ── tests ────────────────────────────────────────────────────────────────

func _test_rules() -> void:
	assert_eq(ChestRules.station_types(), ["chest", "door"], "the fabric has a chest and a door")
	assert_eq(ChestRules.placement_item("chest"), "Chest", "a chest is placed from a Chest")
	assert_eq(ChestRules.placement_item("door"), "Door", "a door from a Door")
	assert_true(GameData.ITEMS.has("Chest") and GameData.ITEMS.has("Door") and GameData.ITEMS.has("Lockpick"), "the three items exist")
	assert_eq(str(GameData.ITEMS["Lockpick"].get("toolType")), ChestRules.tool_type(), "the Lockpick is the lock tool")
	assert_eq(ChestRules.default_mode(), "owner", "a new chest opens for its owner only")
	var stations := StationSlice.new()
	assert_true(stations.placeable_station_types().has("chest") and stations.placeable_station_types().has("door"), "both are placeable")
	assert_eq(stations.placement_item("chest"), "Chest", "and placing one consumes its item")
	stations.free()
	var recipes := {}
	for key: String in GameData.RECIPES:
		for out: Dictionary in (GameData.RECIPES[key].get("recipe") as Dictionary).get("outputs", []):
			recipes[str(out["item"])] = true
	for item: String in ["Chest", "Door", "Lockpick"]:
		assert_true(recipes.has(item), "%s can be crafted" % item)
	assert_false(WorkSkills.UNWIRED.has("lockpick"), "lockpick is gone from WorkSkills.UNWIRED")

func _test_access_modes() -> void:
	var r := _rig()
	var c: ChestSlice = r["c"]
	assert_true(c.register("s1", _chest(), AT, "p1"), "p1 places a chest")
	assert_eq(c.get_lock("s1")["kind"], "private", "it is p1's own")
	assert_true(c.may_open("p1", "s1"), "the owner opens it")
	assert_false(c.may_open("p2", "s1"), "owner-only refuses a clan member")
	assert_eq(c.open("p2", "s1"), "locked", "and says it is locked")
	assert_eq(c.set_mode("p1", "s1", "clan"), "", "the owner opens it to the clan")
	assert_true(c.may_open("p2", "s1"), "a clan member opens it now")
	assert_false(c.may_open("p3", "s1"), "a clan chest refuses an outsider")
	assert_eq(c.set_mode("p1", "s1", "everyone"), "", "and to everyone")
	assert_true(c.may_open("p3", "s1") and c.may_open("p4", "s1"), "everyone opens for anyone")
	r["st"].set_build_mode("p2", "clan")
	assert_true(c.register("s2", _chest(), AT + Vector3(2, 0, 0), "p2"), "p2 places a chest for the clan")
	assert_eq([c.get_lock("s2")["kind"], c.get_lock("s2")["owner"]], ["clan", "clan_1"], "it is the clan's")
	assert_true(c.may_open("p1", "s2") and c.may_open("p2", "s2"), "every member opens a clan-owned chest in owner mode")
	assert_false(c.may_open("p3", "s2"), "an outsider does not")
	_free_rig(r)

func _test_mode_owner_only() -> void:
	var r := _rig()
	var c: ChestSlice = r["c"]
	c.register("s1", _chest(), AT, "p1")
	assert_eq(c.set_mode("p2", "s1", "everyone"), "not_owner", "a clan member cannot change a private chest's mode")
	assert_eq(c.set_mode("p3", "s1", "everyone"), "not_owner", "nor an outsider")
	assert_eq(c.get_lock("s1")["mode"], "owner", "the mode is unchanged")
	assert_eq(c.set_mode("p1", "s1", "friends"), "bad_mode", "a mode outside the fabric's is refused")
	c.set_mode("p1", "s1", "everyone")
	c.open("p3", "s1")
	assert_eq(c.resolve("mode", { "mode": "owner" }, "p3"), "not_owner", "opening it does not make p3 an owner")
	r["st"].set_build_mode("p1", "clan")
	c.register("s2", _chest(), AT, "p1")
	assert_eq(c.set_mode("p2", "s2", "everyone"), "", "any member sets a clan chest's mode")
	assert_eq(c.set_mode("p3", "s2", "owner"), "not_owner", "an outsider never does")
	_free_rig(r)

func _test_doors() -> void:
	var r := _rig()
	var c: ChestSlice = r["c"]
	var st: StructureSlice = r["st"]
	c.register("d1", _door(), AT, "p1")
	assert_true(c.may_open("p1", "d1"), "the owner passes their door")
	assert_false(c.may_open("p2", "d1"), "owner-only refuses a clan member")
	assert_eq(c.open("p2", "d1"), "locked", "who is told it is locked")
	assert_eq(c.set_mode("p2", "d1", "everyone"), "not_owner", "a non-owner cannot change a door's mode")
	c.set_mode("p1", "d1", "clan")
	assert_true(c.may_open("p2", "d1") and not c.may_open("p3", "d1"), "a clan door lets members in, not outsiders")
	c.set_mode("p1", "d1", "everyone")
	assert_true(c.may_open("p3", "d1"), "an everyone door lets anyone in")
	# A member's private house inside the clan's territory: members may enter, so its door lets them in.
	st.set_build_mode("p1", "clan")
	r["reg"].get_inventory("p1").add_item("Ashite", 1)
	assert_true(r["v"].place_block(Vector3(20 * 0.5 + 0.25, 2.0, 20 * 0.5 + 0.25), Vector3.UP, "Ashite", "p1"), "the clan's hall")
	r["reg"].get_inventory("p2").add_item("Ashite", 1)
	var house := Vector3(24 * 0.5 + 0.25, 2.0, 20 * 0.5 + 0.25)
	assert_true(r["v"].place_block(house, Vector3.UP, "Ashite", "p2"), "p2's private house beside it")
	var at := house + Vector3(0, 0.125, 0)
	r["pos"]["p1"] = at
	r["pos"]["p3"] = at
	c.register("d2", _door(), at, "p2")
	c.register("c2", _chest(), at + Vector3(0, 0, 1), "p2")
	assert_true(c.may_open("p1", "d2"), "a clan member opens the door of a member's private house in the territory")
	assert_eq(c.open("p1", "d2"), "", "and passes it")
	assert_false(c.may_open("p3", "d2"), "an outsider does not")
	assert_false(c.may_open("p1", "c2"), "the house's owner-only chest stays shut to the member")
	_free_rig(r)

func _test_put_take() -> void:
	var r := _rig()
	var c: ChestSlice = r["c"]
	c.register("s1", _chest(), AT, "p1")
	_give(r, "p1", "Thornwood", 30)
	assert_eq(c.put("p1", "s1", "Thornwood", 10), "not_open", "the chest is opened first")
	assert_eq(c.resolve("use", {}, "p1"), "", "U opens the nearest chest")
	assert_eq(c.put("p1", "s1", "Thornwood", 10), "", "p1 puts ten in")
	assert_eq([_count(r, "p1", "Thornwood"), c.items_of("s1")], [20, { "Thornwood": 10 }], "they move from the pack to the chest")
	assert_eq(c.put("p1", "s1", "Thornwood", 50), "no_stock", "not more than the pack holds")
	assert_eq(c.take("p1", "s1", "Thornwood", 11), "no_stock", "nor more than the chest holds")
	assert_eq(c.take("p1", "s1", "Thornwood", 4), "", "p1 takes four back")
	assert_eq([_count(r, "p1", "Thornwood"), c.items_of("s1")], [24, { "Thornwood": 6 }], "both sides add up")
	_give(r, "p1", "FerritePick", 1)
	assert_eq(c.put("p1", "s1", "FerritePick", 1), "durable", "a tool that wears stays in the pack")
	var cap := ChestRules.capacity_stacks(_chest())
	c.register_clan_chest("full", _chest(), AT + Vector3(0, 0, 0.5), "clan_1", { "Ferrite": cap * ChestSlice.STACK_SIZE })
	r["pos"]["p2"] = AT + Vector3(0, 0, 0.5)
	_give(r, "p2", "Thornwood", 1)
	assert_eq(c.resolve("use", {}, "p2"), "", "p2 opens the clan's full chest")
	assert_eq(c.put("p2", "full", "Thornwood", 1), "full", "a chest holds capacityStacks stacks")
	assert_eq(c.take("p2", "s1", "Thornwood", 1), "locked", "a member cannot take from an owner-only chest")
	r["pos"]["p1"] = AT + Vector3(10, 0, 0)
	assert_eq(c.take("p1", "s1", "Thornwood", 1), "far", "nor anyone out of reach")
	c.tick(0.1)
	assert_eq(c.open_of("p1"), "", "walking away closes it")
	_free_rig(r)

func _test_harder_lock() -> void:
	var r := _rig()
	var c: ChestSlice = r["c"]
	c.register("weak", _chest(), AT, "p1")
	r["tech"]["p2"] = ["TechBasicSmithing", "TechMasterForge"]
	r["st"].set_build_mode("p2", "private")
	c.register("strong", _chest(), AT + Vector3(2, 0, 0), "p2")
	assert_eq(c.get_lock("weak")["tech"], "none", "a placer who knows no lock technology gives a plain lock")
	assert_eq(c.get_lock("strong")["tech"], "TechMasterForge", "the best one the placer knows is used")
	assert_true(c.difficulty("strong") > c.difficulty("weak"), "the better lock is harder")
	var lvl_cap := int(GameData.SKILLS["Lockpicking"].get("levelCap"))
	assert_true(ChestRules.pick_seconds(c.difficulty("strong"), 0, lvl_cap) > ChestRules.pick_seconds(c.difficulty("weak"), 0, lvl_cap),
		"a harder chest takes longer to pick")
	assert_true(ChestRules.pick_seconds(c.difficulty("weak"), lvl_cap, lvl_cap) < ChestRules.pick_seconds(c.difficulty("weak"), 0, lvl_cap),
		"a better picker is faster")
	for m: String in StructureRules.METHODS:
		assert_true(c.hits_to_break("strong", m) > c.hits_to_break("weak", m), "a harder chest takes more %s hits to break" % m)
	assert_true(ChestRules.difficulty("Voidite", "none") > ChestRules.difficulty("Thornwood", "none"), "a rarer lock material is harder")
	assert_true(ChestRules.lock_durability("Voidite", "none") > ChestRules.lock_durability("Thornwood", "none"), "and lasts longer")
	# The slice's own clock: actually picking both, the strong one takes longer.
	_give(r, "p3", "Lockpick", 2)
	var times: Array = []
	for id: String in ["weak", "strong"]:
		r["pos"]["p3"] = c.get_lock(id)["pos"]
		assert_eq(c.start_pick("p3", id), "", "p3 starts picking %s" % id)
		var t := 0.0
		while c.pick_of("p3").size() > 0 and t < 1000.0:
			c.tick(0.5)
			t += 0.5
		times.append(t)
	assert_true(float(times[1]) > float(times[0]), "the strong chest took longer to pick (%s)" % str(times))
	_free_rig(r)

func _test_pick() -> void:
	var r := _rig()
	var c: ChestSlice = r["c"]
	var told: Array = []
	var cb := func(key: String, args: Array, to: String) -> void: told.append([key, to])
	GameBus.system_message.connect(cb)
	_online(r, "p1", 5)
	c.register("s1", _chest(), AT, "p1")
	_give(r, "p3", "Lockpick", 1)
	var xp_before := int(r["reg"].get_skill_xp("p3", "Lockpicking"))
	assert_eq(c.resolve("pick", {}, "p3"), "", "p3 starts picking the nearest lock")
	assert_eq(c.resolve("pick", {}, "p3"), "busy", "one pick at a time")
	assert_true(c.pick_seconds_left("p3") > 0.0, "it takes time")
	c.tick(c.pick_seconds_left("p3") + 0.01)
	assert_true(c.pick_of("p3").is_empty(), "the pick finished")
	assert_eq(int(r["reg"].get_skill_xp("p3", "Lockpicking")) - xp_before, int(WorkSkills.row("lockpick")["xp"]), "a picked lock grants the lockpick row")
	assert_true(c.may_open("p3", "s1"), "the lock lets its picker in")
	assert_true(told.has(["lock.picked", "p1"]), "the owner is told")
	assert_eq(c.open("p3", "s1"), "", "p3 opens it")
	c.close("p3")
	assert_false(c.may_open("p3", "s1"), "once: closed, it is locked to them again")
	assert_eq(c.start_pick("p1", "s1"), "not_locked", "an owner has nothing to pick")
	GameBus.system_message.disconnect(cb)
	_free_rig(r)

func _test_pick_fails() -> void:
	var r := _rig()
	var c: ChestSlice = r["c"]
	var told: Array = []
	var cb := func(key: String, _args: Array, to: String) -> void: told.append([key, to])
	GameBus.system_message.connect(cb)
	_online(r, "p1", 5)
	c.register("s1", _chest(), AT, "p1")
	assert_eq(c.start_pick("p3", "s1"), "no_tool", "no lockpick, no pick")
	_give(r, "p3", "Lockpick", 2)
	r["roll"][0] = 0.0   # a failure always breaks the tool
	c.start_pick("p3", "s1")
	r["pos"]["p3"] = AT + Vector3(2, 0, 0)
	c.tick(0.1)
	assert_true(c.pick_of("p3").is_empty(), "moving cancels the pick")
	assert_false(c.may_open("p3", "s1"), "and the lock holds")
	assert_eq(_count(r, "p3", "Lockpick"), 1, "the failure broke a lockpick")
	assert_true(told.has(["lock.pick_failed", "p1"]), "and the owner is told")
	r["pos"]["p3"] = AT
	r["roll"][0] = 0.999   # above any break chance
	c.start_pick("p3", "s1")
	c.resolve("cancel", {}, "p3")
	assert_eq(_count(r, "p3", "Lockpick"), 1, "a failure whose roll misses keeps the tool")
	assert_true(ChestRules.break_chance(c.difficulty("s1")) <= 1.0 and ChestRules.break_chance(1.0) > 0.0, "the break chance is a probability")
	GameBus.system_message.disconnect(cb)
	_free_rig(r)

func _test_break_spills() -> void:
	var r := _rig()
	var c: ChestSlice = r["c"]
	c.register("s1", _chest(), AT, "p1")
	_give(r, "p1", "Thornwood", 12)
	_give(r, "p1", "Ferrite", 3)
	c.open("p1", "s1")
	c.put("p1", "s1", "Thornwood", 12)
	c.put("p1", "s1", "Ferrite", 3)
	var hits := 0
	while c.has_lock("s1") and hits < 100000:
		r["now"][0] += 1.0
		c.hit("p3", "s1", "pick")
		hits += 1
	assert_false(c.has_lock("s1"), "enough hits break the chest")
	assert_true(hits > 1, "and it takes more than one (%d)" % hits)
	assert_eq(r["removed"], ["s1"], "its station is removed")
	var spilled := {}
	for e: Array in r["spilled"]:
		spilled[e[0]] = int(spilled.get(e[0], 0)) + int(e[1])
		assert_eq(e[2], AT, "it spills where the chest stood")
	assert_eq(spilled, { "Thornwood": 12, "Ferrite": 3 }, "a destroyed chest spills everything it held")
	assert_eq(_count(r, "p3", "Thornwood"), 0, "the destroyer gets nothing else")
	c.register("s2", _chest(), AT, "p1")
	r["now"][0] += 1.0
	assert_eq(c.hit("p3", "s2", "pick"), "", "a hit lands")
	assert_eq(c.hit("p3", "s2", "pick"), "rate", "the host keeps the hit pace")
	_free_rig(r)

func _test_persistence() -> void:
	var r := _rig()
	var c: ChestSlice = r["c"]
	c.register("s1", _chest(), AT, "p1")
	c.register("d1", _door(), AT + Vector3(3, 0, 0), "p1")
	_give(r, "p1", "Thornwood", 5)
	c.open("p1", "s1")
	c.put("p1", "s1", "Thornwood", 5)
	c.set_mode("p1", "d1", "everyone")
	r["now"][0] += 1.0
	c.hit("p3", "s1", "hand")
	var data := c.to_data()
	data["locks"]["bad1"] = { "type": "bench", "kind": "private", "owner": "p1", "pos": [0, 0, 0] }
	data["locks"]["bad2"] = { "type": "chest", "kind": "nobody", "owner": "p1", "pos": [0, 0, 0] }
	data["locks"]["bad3"] = { "type": "chest", "kind": "private", "owner": "p1", "pos": [0, "x", 0] }
	data["locks"]["lost"] = { "type": "chest", "kind": "private", "owner": "p1", "pos": [0, 0, 0] }
	var j: Variant = JSON.parse_string(JSON.stringify(data))
	var c2 := ChestSlice.new()
	c2.from_data(j, func(id: String) -> bool: return id != "lost")
	assert_eq(c2.ids(), ["d1", "s1"], "only well-formed entries whose station stands come back")
	assert_eq(c2.items_of("s1"), { "Thornwood": 5 }, "a chest keeps its items")
	assert_eq(c2.get_lock("d1")["mode"], "everyone", "a door keeps its mode")
	assert_true(absf(float(c2.get_lock("s1")["hp"]) - float(c.get_lock("s1")["hp"])) < 0.001, "and a lock its damage")
	c2.free()
	_free_rig(r)

func _test_stockpile_migration() -> void:
	var r := _rig()
	var c: ChestSlice = r["c"]
	var settle := SettlementSlice.new()
	settle.from_data({ "settlements": { "settlement_1": { "name": "Oakhold", "founder": "p1", "members": { "p1": "founder" },
		"status": "camp", "stock": { "Thornwood": 40, "Ferrite": 7 }, "hx": 10.0, "hz": 10.0 } } })
	var stock := settle.stock_of("settlement_1")
	assert_eq(stock, { "Thornwood": 40, "Ferrite": 7 }, "the saved settlement holds a stockpile")
	assert_true(c.register_clan_chest("s9", _chest(), AT, "clan_1", stock), "it becomes a clan chest")
	assert_eq(settle.take_stock("settlement_1"), stock, "the settlement gives its stock up")
	assert_true(settle.stock_of("settlement_1").is_empty(), "and keeps none of it")
	assert_eq(c.items_of("s9"), stock, "the clan chest has the same contents")
	assert_true(c.may_open("p2", "s9") and not c.may_open("p3", "s9"), "every member opens it, an outsider does not")
	var src := FileAccess.get_file_as_string("res://src/world/chest_wiring.gd")
	assert_true(src.contains("func migrate_stockpiles") and FileAccess.get_file_as_string("res://src/persistence/persistence_wiring.gd").contains("_chest_wiring.load_record"),
		"the host migrates stockpiles when it loads a record without chests")
	settle.free()
	_free_rig(r)

func _test_audit_client_values() -> void:
	var r := _rig()
	var c: ChestSlice = r["c"]
	c.register("s1", _chest(), AT, "p1")
	var hp := float(c.get_lock("s1")["hp"])
	assert_eq(c.resolve("hit", { "method": "pick", "id": "s1" }, "p3"), "", "a bare-handed hit lands")
	assert_true(absf(hp - float(c.get_lock("s1")["hp"]) - StructureRules.hit_damage("hand", str(c.get_lock("s1")["material"]), true)) < 0.001,
		"as a hand, whatever method the client names")
	r["pos"]["p3"] = AT + Vector3(50, 0, 0)
	c.register("far", _chest(), AT + Vector3(50, 0, 0), "p1")
	c.set_mode("p1", "s1", "everyone")
	assert_eq(c.resolve("use", { "id": "s1" }, "p3"), "locked", "the chest is the one nearest the host's view of the player, not one named")
	assert_eq(c.resolve("use", {}, ""), "bad_args", "an intent with no player is refused")
	var src := FileAccess.get_file_as_string("res://src/world/chest_slice.gd")
	assert_false(src.contains("args.get(\"owner\"") or src.contains("args.get(\"id\"") or src.contains("args.get(\"method\""),
		"no owner, chest id or method is read from a client message")
	_free_rig(r)

func _test_wire() -> void:
	var v := ChestWiring._clean_view({ "id": "s1", "type": "chest", "mode": "clan", "items": { "Thornwood": 3, "x": "y" }, "owner": 1, "hp": "lots" })
	assert_eq(v["items"], { "Thornwood": 3 }, "a view keeps only counted items")
	assert_eq([v["hp"], v["owner"]], [0, true], "and well-typed numbers")
	assert_eq(ChestWiring._clean_view({ "type": "bench" }), {}, "a view of no chest or door is nothing")
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.set_transport(MemoryTransport.new([9]))
	var seen: Array = []
	var cb := func(action: String, args: Dictionary, pid: String) -> void: seen.append([action, args, pid])
	GameBus.chest_intent.connect(cb)
	n._route_c2h(9, { "type": "chest_intent", "action": "use", "args": {}, "player_id": "p2" })
	assert_eq(seen.size(), 0, "an un-handshaked peer's intent is dropped")
	n.set_player_id(9, "p3")
	n._route_c2h(9, { "type": "chest_intent", "action": "take", "args": { "item": "Thornwood", "qty": 2, "x": [1] }, "player_id": "p1" })
	assert_eq(seen, [["take", { "item": "Thornwood", "qty": 2 }, "p3"]], "the host binds the connection's player and keeps scalar args")
	GameBus.chest_intent.disconnect(cb)
	n.free()
	var c := NetworkingSlice.new()
	add_child(c)
	c._role = NetworkingSlice.Role.CLIENT
	c.set_transport(MemoryTransport.new([1]))
	assert_true(GameBus.chest_intent.is_connected(c._m2.forward_chest_intent), "a client forwards chest intents")
	c.free()
