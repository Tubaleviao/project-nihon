extends "res://src/tests/test_support.gd"
## Phase 272 — focus: active minutes of play time per skill, the dedication multiplier and the carried fraction.

const SkillFocus := preload("res://src/character/skill_focus.gd")
const SkillPage := preload("res://src/character/skill_page.gd")
const SkillPagePanel := preload("res://src/ui/skill_page_panel.gd")
const SkillWheelView := preload("res://src/ui/skill_wheel_view.gd")
const WorkSkills := preload("res://src/character/work_skills.gd")
const I18n := preload("res://src/core/i18n.gd")

func register() -> void:
	_run_test("skill focus: a minute with XP counts once for its skill, and for several skills", _test_minute_counts_once)
	_run_test("skill focus: minutes older than the window drop out, logged-off time does not age them", _test_window_and_logoff)
	_run_test("skill focus: the multiplier is 1 with no focus, 1 + maxBonus when full, never below 1", _test_multiplier)
	_run_test("skill focus: a grant is multiplied exactly once", _test_once)
	_run_test("skill focus: 100 grants of 2 XP at +25% pay exactly 250 (the fraction is carried)", _test_carry)
	_run_test("skill focus: sanitize bounds a hostile record", _test_sanitize)
	_run_test("skill focus: the registry multiplies a grant once and saves focus with the record", _test_registry)
	_run_test("skill focus: a player is told only their own focus", _test_own_view)
	_run_test("skill page: level, XP, next tiers, trainers, professions and focus match the skill state", _test_page_matches_state)
	_run_test("skill page: the panel shows names, no raw ids, a bar and category shares", _test_page_panel)
	_run_test("skill page: a new tier of the local player toasts and opens its page", _test_toast_opens_page)
	_run_test("skill wheel: focus shares by profession glow the rim and the centre lists the leading skills", _test_wheel_focus)
	_run_test("skill page: every new string is in both locales", _test_locales)
	_run_test("skill focus: the fabric defaults are an hour and +25%", _test_fabric)

func _fill(f: Dictionary, skill: String, minutes: int) -> void:
	for i in minutes:
		SkillFocus.note(f, skill)
		SkillFocus.advance(f, 60.0)

func _test_minute_counts_once() -> void:
	var f := SkillFocus.empty()
	for i in 5:
		SkillFocus.note(f, "Smithing")
	SkillFocus.note(f, "Archery")
	assert_eq(SkillFocus.active_minutes(f, "Smithing", 60), 1, "five grants in one minute count once")
	assert_eq(SkillFocus.active_minutes(f, "Archery", 60), 1, "the same minute counts for another skill too")
	SkillFocus.advance(f, 60.0)
	SkillFocus.note(f, "Smithing")
	assert_eq(SkillFocus.active_minutes(f, "Smithing", 60), 2, "the next minute counts again")
	assert_eq(SkillFocus.active_minutes(f, "Archery", 60), 1, "a skill with no XP this minute keeps only its own")

func _test_window_and_logoff() -> void:
	var f := SkillFocus.empty()
	_fill(f, "Smithing", 10)
	assert_eq(SkillFocus.active_minutes(f, "Smithing", 60), 10, "ten active minutes")
	# Logged off: the clock does not move, so nothing ages (no `advance` call), however long the wall clock ran.
	assert_eq(SkillFocus.active_minutes(f, "Smithing", 60), 10, "time logged off does not age focus")
	SkillFocus.advance(f, 55.0 * 60.0)
	assert_eq(SkillFocus.active_minutes(f, "Smithing", 60), 4, "minutes older than the window drop out")
	SkillFocus.advance(f, 60.0 * 60.0)
	assert_eq(SkillFocus.active_minutes(f, "Smithing", 60), 0, "all of them are gone an hour on")

func _test_multiplier() -> void:
	var f := SkillFocus.empty()
	assert_eq(SkillFocus.multiplier(f, "Smithing", 60, 0.25), 1.0, "no focus earns the normal rate")
	_fill(f, "Smithing", 60)
	SkillFocus.note(f, "Smithing")
	assert_true(is_equal_approx(SkillFocus.multiplier(f, "Smithing", 60, 0.25), 1.25), "a full window gives +25%")
	assert_eq(SkillFocus.multiplier(f, "Archery", 60, 0.25), 1.0, "another skill has none")
	assert_true(SkillFocus.multiplier(f, "Smithing", 60, -1.0) >= 1.0, "a negative bonus never goes below 1")
	var half := SkillFocus.empty()
	_fill(half, "Smithing", 30)
	SkillFocus.note(half, "Smithing")
	assert_true(is_equal_approx(SkillFocus.multiplier(half, "Smithing", 60, 0.25), 1.0 + 0.25 * 31.0 / 60.0), "half an hour gives about +12.5%")

func _test_once() -> void:
	var f := SkillFocus.empty()
	_fill(f, "Smithing", 60)
	SkillFocus.note(f, "Smithing")
	var paid := SkillFocus.boost(f, "Smithing", 100, 60, 0.25)
	assert_eq(paid, 125, "one grant pays 100 x 1.25 once, not 1.5625")

func _test_carry() -> void:
	var f := SkillFocus.empty()
	_fill(f, "Smithing", 60)
	SkillFocus.note(f, "Smithing")
	var total := 0
	for i in 100:
		total += SkillFocus.boost(f, "Smithing", 2, 60, 0.25)
	assert_eq(total, 250, "100 grants of 2 XP at +25% pay exactly 250")
	assert_true(float((f["carry"] as Dictionary)["Smithing"]) < 1.0, "the carry stays below a whole point")

func _test_sanitize() -> void:
	var s := SkillFocus.sanitize({"clock": -5.0, "minutes": {"A": [3, 1, "x", -4, 2.0], "B": 7}, "carry": {"A": 9.0, "Z": 0.5}})
	assert_eq(s["clock"], 0.0, "a negative clock is zero")
	assert_eq(s["minutes"], {"A": [1, 2, 3]}, "bad entries are dropped and the rest sorted")
	assert_true(float(s["carry"]["A"]) < 1.0 and not (s["carry"] as Dictionary).has("Z"), "carry is a fraction of a known skill")
	assert_eq(SkillFocus.sanitize("junk"), SkillFocus.empty(), "junk is empty")
	var big: Array = []
	for i in 5000:
		big.append(i)
	assert_true((SkillFocus.sanitize({"minutes": {"A": big}})["minutes"]["A"] as Array).size() <= SkillFocus.MAX_MINUTES_KEPT, "minutes are bounded")

func _test_fabric() -> void:
	assert_eq(SkillFocus.window_minutes(), 60, "the window is an hour")
	assert_eq(SkillFocus.max_bonus(), 0.25, "maxBonus is 0.25")

func _registry() -> PlayerRegistry:
	var reg := PlayerRegistry.new()
	reg.is_authoritative = true
	reg.ensure_player("p1")
	reg.ensure_player("p2")
	return reg

func _test_registry() -> void:
	var reg := _registry()
	# No focus yet: the first grant pays the normal rate.
	reg.grant_skill_xp("p1", "Smithing", 10)
	assert_eq(reg.get_skill_xp("p1", "Smithing"), 10, "a first grant earns the normal rate")
	# A full hour on Smithing: 100 grants of 2 XP, one a minute, then 100 at the full bonus.
	var rec := reg.get_record("p1")
	rec["skill_focus"] = SkillFocus.empty()
	_fill(rec["skill_focus"], "Smithing", 60)
	SkillFocus.note(rec["skill_focus"], "Smithing")
	var before := reg.get_skill_xp("p1", "Smithing")
	for i in 100:
		reg.grant_skill_xp("p1", "Smithing", 2)
	assert_eq(reg.get_skill_xp("p1", "Smithing") - before, 250, "100 grants of 2 XP at +25% pay 250")
	assert_eq(reg.get_skill_xp("p2", "Smithing"), 0, "another player earned nothing")
	var data := reg.get_player_data("p1")
	assert_true(data.get("skill_focus", null) is Dictionary and not (data["skill_focus"]["minutes"] as Dictionary).is_empty(), "focus is saved with the record")
	reg.free()

func _test_own_view() -> void:
	var reg := _registry()
	var rec := reg.get_record("p1")
	rec["skill_focus"] = SkillFocus.empty()
	_fill(rec["skill_focus"], "Smithing", 20)
	var mine := SkillFocus.view_of_record(rec)
	assert_eq(mine.get("Smithing", 0), 20, "the owner is told their active minutes")
	assert_eq(SkillFocus.view_of_record(reg.get_record("p2")), {}, "another player's view is theirs, empty")
	assert_eq(SkillFocus.sanitize_view({"A": 5, "B": -1, "C": "x"}), {"A": 5}, "a garbled synced view is bounded")
	reg.free()

# ─── The page ───────────────────────────────────────────────────────────────

func _wheel() -> Resource:
	return GameData.WORLD_SYSTEMS.get("SkillWheel", null)

func _test_page_matches_state() -> void:
	var p := SkillPage.page("Smithing", 450, {"Smithing": 30}, _wheel())
	assert_eq(p["tier"], "journeyman", "450 XP is journeyman, as the skill state says")
	assert_eq(p["tier"], WorkSkills.tier_for_xp(450), "the page reads the same table as the host")
	assert_eq(p["level_floor"], 400, "the tier starts at 400 XP")
	assert_eq(p["next_floor"], 1200, "the next tier starts at 1200 XP")
	assert_true(is_equal_approx(float(p["progress"]), 50.0 / 800.0), "the bar is the share of the way to the next tier")
	assert_eq((p["next_unlocks"] as Array).map(func(u): return u["tier"]), ["expert", "master"], "the tiers above are listed")
	assert_true((p["professions"] as Array).has("Blacksmith"), "Smithing leads to Blacksmith")
	assert_true(not (p["trainers"] as Array).is_empty(), "something trains Smithing")
	assert_true(is_equal_approx(float(p["focus_bonus"]), 0.25 * 30.0 / 60.0), "30 active minutes give +12.5%")
	var top := SkillPage.page("Smithing", 99999, {}, _wheel())
	assert_eq(top["next_floor"], -1, "the last tier has no next")
	assert_eq(top["progress"], 1.0, "the bar is full at the top")

func _test_page_panel() -> void:
	SkillPage.local_xp = {"Smithing": 450}
	SkillFocus.local_view = {"Smithing": 30, "Archery": 30}
	var panel := SkillPagePanel.new()
	panel.show_skill("Smithing")
	assert_true(panel.lines.has(I18n.content("skill", "Smithing")), "the page names the skill")
	assert_true(panel.bar != null and is_equal_approx(panel.bar.value, 50.0 / 800.0), "its bar matches the XP")
	for l in panel.lines:
		assert_true(not GameData.SKILLS.has(l) or l == I18n.content("skill", l), "no raw entity id on the page: %s" % l)
		assert_true(not l.begins_with("ui."), "no raw key on the page: %s" % l)
	var shares := SkillPage.category_shares(SkillFocus.local_view)
	assert_true(is_equal_approx(float(shares.get("crafting", 0.0)), 0.5) and is_equal_approx(float(shares.get("combat", 0.0)), 0.5), "shares group by category")
	panel.free()
	SkillPage.local_xp = {}
	SkillFocus.local_view = {}

func _test_toast_opens_page() -> void:
	var ui := _new_test_ui()
	var crafting := CraftingSlice.new()
	ui.crafting_slice = crafting
	ui._build_skills_content()
	GameBus.skill_tier_recorded.emit(crafting.local_player_id(), "Smithing", "apprentice")
	assert_eq(ui._skills_window.page.skill, "Smithing", "the page of the skill that moved is open")
	assert_true(ui.toast_shown() != "", "a toast announces it")
	GameBus.skill_tier_recorded.emit("someone-else", "Archery", "apprentice")
	assert_eq(ui._skills_window.page.skill, "Smithing", "another player's tier opens nothing")
	ui._skills_window.free()
	crafting.free()
	ui.free()

func _test_wheel_focus() -> void:
	var view := {"Smithing": 30, "Mining": 10}
	var shares := SkillPage.profession_shares(view, {"Blacksmith": ["Smithing", "Mining"], "Ranger": ["Archery"], "Arcanist": ["Smithing"]})
	assert_true(absf(float(shares["Blacksmith"]) - 1.0) < 0.0001, "all the focus is in the Blacksmith's skills")
	assert_true(absf(float(shares["Arcanist"]) - 0.75) < 0.0001, "a shared skill counts for each profession it leads to")
	assert_false(shares.has("Ranger"), "a profession with no focus is absent")
	assert_true(SkillPage.profession_shares({}, {"Blacksmith": ["Smithing"]}).is_empty(), "no focus, no shares")
	var wheel := SkillWheelView.new()
	var rows := SkillWheelView.rows({}, {})
	wheel.set_rows(rows["nodes"], rows["professions"])
	var pid := str(wheel.professions.keys()[0])
	var rest: Color = (wheel.professions[pid] as Button).self_modulate
	wheel.set_focus({pid: 1.0}, "Recent focus\nSmithing: 75%")
	assert_true((wheel.professions[pid] as Button).self_modulate != rest, "a focused profession glows")
	assert_true(wheel.focus_label.visible and wheel.focus_label.text.contains("Smithing"), "the centre lists the leading skill")
	wheel.set_rows(rows["nodes"], rows["professions"])
	assert_true((wheel.professions[pid] as Button).self_modulate != rest, "a refresh keeps the glow")
	wheel.set_focus({}, "")
	assert_true((wheel.professions[pid] as Button).self_modulate == rest and not wheel.focus_label.visible, "no focus clears both")
	wheel.free()

func _test_locales() -> void:
	var cats: Dictionary = I18n.parse_csv(I18n.CATALOG_PATH)["catalog"]
	var keys: Array = []
	for k in (cats["en"] as Dictionary):
		if str(k).begins_with("ui.skill_page") or str(k).begins_with("ui.tier_") or str(k).begins_with("ui.work.") or str(k).begins_with("ui.category_") or k == "ui.skill_unlocked_toast" or str(k).begins_with("ui.skill_wheel_focus"):
			keys.append(k)
	assert_true(keys.size() >= 40, "the new strings exist (%d)" % keys.size())
	for loc: String in ["en", "pt_BR"]:
		for k in keys:
			assert_true((cats[loc] as Dictionary).has(k) and str(cats[loc][k]) != "", "%s has %s" % [loc, k])
	for kind in SkillPage.trainers("Smithing") + SkillPage.trainers("Mining") + SkillPage.trainers("Foraging") + SkillPage.trainers("Skinning") + SkillPage.trainers("Building"):
		assert_true((cats["en"] as Dictionary).has("ui.work." + str(kind)), "work kind %s has a label" % kind)
