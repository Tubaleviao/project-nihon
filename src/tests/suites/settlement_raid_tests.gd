extends "res://src/tests/test_support.gd"
## Phase 200 — settlement raids: the pure rules (eligibility, packs, losses, defence) and the raid record.

const SettlementSlice := preload("res://src/settlement/settlement_slice.gd")
const RaidRules := preload("res://src/settlement/raid_rules.gd")

func register() -> void:
	_run_test("raid rules: no raid without a member online, before the age, under the value floor or in the cooldown", _test_eligibility)
	_run_test("raid rules: a pack comes from the biome's rows within their counts", _test_pack)
	_run_test("raid: a lost raid takes at most the loss share, a defended one nothing, defence scales it down", _test_losses)
	_run_test("raid: the cooldown and last result survive a save and reload, a pre-200 world loads as never raided", _test_persistence)
	_run_test("raid: every refusal and result has catalog text", _test_strings)

func _ready_info() -> Dictionary:
	return { "age_sec": 3600.0, "tier": "growing", "stock_stacks": 0, "since_last_sec": 1.0e12, "active": false,
		"online_in_claim": 1, "biome": "TemperateForest" }

func _test_eligibility() -> void:
	assert_eq(RaidRules.start_blocker(_ready_info()), "", "a grown, old, watched village may be raided")
	var i := _ready_info()
	i["online_in_claim"] = 0
	assert_eq(RaidRules.start_blocker(i), "no_member_online", "nobody online inside the claim")
	i = _ready_info()
	i["age_sec"] = 29.0 * 60.0
	assert_eq(RaidRules.start_blocker(i), "too_young", "before the minimum age")
	i = _ready_info()
	i["tier"] = "founded"
	assert_eq(RaidRules.start_blocker(i), "not_worth_raiding", "founded tier and a small stockpile")
	i["stock_stacks"] = 10
	assert_eq(RaidRules.start_blocker(i), "", "ten stacks make a founded village worth raiding")
	i = _ready_info()
	i["since_last_sec"] = 5.0 * 3600.0
	assert_eq(RaidRules.start_blocker(i), "cooldown", "inside the cooldown")
	i["since_last_sec"] = 6.0 * 3600.0
	assert_eq(RaidRules.start_blocker(i), "", "cooldown over")
	i = _ready_info()
	i["active"] = true
	assert_eq(RaidRules.start_blocker(i), "raid_active", "one raid at a time")
	i = _ready_info()
	i["biome"] = "Ocean"
	assert_eq(RaidRules.start_blocker(i), "no_pack", "a biome with no row is never raided")

func _test_pack() -> void:
	var lowest := RaidRules.pack_for("TemperateForest", [0.0, 0.0])
	assert_eq(lowest, [{ "creature": "GraywolfPack", "count": 3 }, { "creature": "ForestBoar", "count": 1 }], "rolls at 0: the minimums")
	var highest := RaidRules.pack_for("TemperateForest", [0.999, 0.999])
	assert_eq(highest, [{ "creature": "GraywolfPack", "count": 5 }, { "creature": "ForestBoar", "count": 2 }], "rolls near 1: the maximums")
	assert_eq(RaidRules.pack_for("Ocean", [0.5]), [], "no row, no pack")
	for biome: String in RaidRules.table()["packs"]:
		for row: Dictionary in RaidRules.table()["packs"][biome]:
			assert_true(GameData.CREATURES.has(str(row["creature"])), "%s is a creature" % row["creature"])

func _rig() -> Dictionary:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("host")
	reg.ensure_player("p1")
	var s := SettlementSlice.new()
	s.registry = reg
	add_child(s)
	var now := [1000000.0]
	s.now_sec = func() -> float: return now[0]
	s.mono_sec = func() -> float: return now[0]
	s.position_of = func(_pid: String) -> Variant: return Vector2(10.0, 10.0)
	s.place_structure = func(_id: String, _key: String, _site: Dictionary) -> void: pass
	assert_true(reg.get_inventory("p1").add_item("Hearth", 1), "hearth")
	assert_eq(s.found("p1", "Oak", Vector2(10.0, 10.0)), "", "founded")
	return { "reg": reg, "s": s, "now": now }

func _free_rig(rig: Dictionary) -> void:
	rig["s"].free()
	rig["reg"].free()

func _test_losses() -> void:
	var stock := { "ThornwoodPlank": 100, "FerriteIngot": 3 }
	assert_eq(RaidRules.losses(true, stock, 0.0), { "stock": {}, "project_damage": 0.0 }, "a defended raid takes nothing")
	var lost := RaidRules.losses(false, stock, 0.0)
	assert_eq(lost["stock"], { "ThornwoodPlank": 20 }, "at most 20%, rounded down per item")
	assert_eq(lost["project_damage"], 0.25, "the project damage share")
	var guarded := RaidRules.losses(false, stock, 0.5)
	assert_eq(guarded["stock"], { "ThornwoodPlank": 10 }, "a palisade and watchtower (0.5) halve it")
	assert_eq(RaidRules.losses(false, stock, 5.0)["stock"], { "ThornwoodPlank": 5 }, "defence is capped at 0.75")
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	s._settlements["settlement_1"]["stock"] = { "ThornwoodPlank": 100 }
	assert_eq(s.start_project("p1", "palisade"), "", "palisade started")
	s.projects_of("settlement_1")
	s._settlements["settlement_1"]["projects"]["palisade"]["work"] = 40.0
	var out := s.end_raid("settlement_1", false)
	assert_eq(out["stock"], { "ThornwoodPlank": 20 }, "the slice takes the capped share")
	assert_eq(s.stock_of("settlement_1")["ThornwoodPlank"], 80, "and the stockpile shrinks by it")
	assert_eq(float(s.projects_of("settlement_1")["palisade"]["work"]), 30.0, "an unfinished project loses a quarter of its labour")
	var kept := s.end_raid("settlement_1", true)
	assert_eq(kept["stock"], {}, "a defended raid takes nothing from the slice")
	assert_eq(s.stock_of("settlement_1")["ThornwoodPlank"], 80, "stockpile untouched")
	_free_rig(rig)

func _test_persistence() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	assert_eq(s.raid_record("settlement_1"), { "last_end": 0.0, "last_result": "" }, "never raided")
	var out := s.end_raid("settlement_1", false)
	assert_eq(out["result"], "lost", "a lost raid")
	var data := s.to_data()
	var again := SettlementSlice.new()
	add_child(again)
	again.from_data(data)
	assert_eq(again.raid_record("settlement_1"), { "last_end": 1000000.0, "last_result": "lost" }, "the cooldown clock and result survive")
	again.free()
	var legacy := s.to_data()
	legacy["format"] = 2
	var old := SettlementSlice.new()
	add_child(old)
	old.from_data(legacy)
	assert_eq(old.raid_record("settlement_1"), { "last_end": 0.0, "last_result": "" }, "a pre-200 record loads as never raided")
	old.free()
	assert_eq(s.end_raid("nowhere", true), {}, "no such settlement")
	_free_rig(rig)

func _test_strings() -> void:
	for code: String in RaidRules.REASONS:
		assert_true(I18nScript.has_key("settlement.raid.refused." + code), "refusal %s has catalog text" % code)
	for k in ["settlement.raid.warning", "settlement.raid.result.defended", "settlement.raid.result.lost"]:
		assert_true(I18nScript.has_key(k), "%s is in the catalog" % k)
