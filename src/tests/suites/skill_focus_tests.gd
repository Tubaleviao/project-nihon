extends "res://src/tests/test_support.gd"
## Phase 272 — focus: active minutes of play time per skill, the dedication multiplier and the carried fraction.

const SkillFocus := preload("res://src/character/skill_focus.gd")

func register() -> void:
	_run_test("skill focus: a minute with XP counts once for its skill, and for several skills", _test_minute_counts_once)
	_run_test("skill focus: minutes older than the window drop out, logged-off time does not age them", _test_window_and_logoff)
	_run_test("skill focus: the multiplier is 1 with no focus, 1 + maxBonus when full, never below 1", _test_multiplier)
	_run_test("skill focus: a grant is multiplied exactly once", _test_once)
	_run_test("skill focus: 100 grants of 2 XP at +25% pay exactly 250 (the fraction is carried)", _test_carry)
	_run_test("skill focus: sanitize bounds a hostile record", _test_sanitize)
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
	_fill(f, "Smithing", 59)
	var paid := SkillFocus.boost(f, "Smithing", 100, 60, 0.25)
	assert_eq(paid, 125, "one grant pays 100 x 1.25 once, not 1.5625")

func _test_carry() -> void:
	var f := SkillFocus.empty()
	_fill(f, "Smithing", 59)
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
