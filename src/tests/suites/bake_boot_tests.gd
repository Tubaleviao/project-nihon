extends "res://src/tests/test_support.gd"
## Phase 302 — the progress of the host's planet bake: reports that only go forward and reach the end, bytes
## that do not depend on a progress callback, a job that bakes on a thread and leaves the file the boot reads,
## and a screen whose strings are all in both locales.

const Bake := preload("res://src/terrain/planet_bake.gd")
const BakeJobScript := preload("res://src/terrain/bake_job.gd")
const BakeScreenScript := preload("res://src/ui/bake_screen.gd")
const W := 32
const H := 16

func register() -> void:
	_run_test("bake progress: stage shares sum to one and the overall share only grows", _test_progress_shares)
	_run_test("bake progress: the bake reports forward through its stages and ends done, bytes equal without a callback", _test_progress_monotonic_bytes)
	_run_test("bake progress: the GDScript bake reports too and equals the plain one", _test_progress_gd)
	_run_test("bake progress: a job bakes on a thread, reports done and leaves the file ensure reads", _test_job_thread)
	_run_test("bake progress: plan_for follows the grid limits", _test_plan_for)
	_run_test("bake progress: the screen's keys exist in en and pt_BR and its labels follow the locale", _test_screen_keys)

func _grid() -> PackedInt32Array:
	var g := PackedInt32Array()
	g.resize(W * H)
	for z in H:
		for x in W:
			g[z * W + x] = (W - 1 - x) * 90000 / W - 6000 + ((x * 7919 + z * 104729) % 23) * 700
	return g

func _test_progress_shares() -> void:
	var total := 0.0
	for s in Bake.STAGE_WEIGHTS:
		total += s
	assert_true(absf(total - 1.0) < 0.0001, "the stage weights sum to 1")
	assert_eq(Bake.STAGES.size(), Bake.STAGE_WEIGHTS.size(), "one weight per stage")
	var prev := -1.0
	for stage in Bake.STAGES:
		for f in [0.0, 0.5, 1.0]:
			var o := Bake.overall(stage, f)
			assert_true(o >= prev, "overall never goes back at %s %s" % [stage, f])
			prev = o
	assert_true(absf(Bake.overall(&"save", 1.0) - 1.0) < 0.0001, "the last stage ends at 1")
	assert_eq(Bake.overall(&"nope", 0.5), 0.0, "an unknown stage counts for nothing")

func _record(log: Array) -> Callable:
	return func(stage: StringName, fraction: float) -> void: log.append([stage, fraction])

func _assert_forward(log: Array, what: String) -> void:
	assert_true(log.size() > 2, "%s reported" % what)
	var prev := -1.0
	var seen := {}
	for e in log:
		var o := Bake.overall(e[0], e[1])
		assert_true(o + 0.0000001 >= prev, "%s: %s %s did not go back" % [what, e[0], e[1]])
		prev = o
		seen[e[0]] = true
	assert_true(seen.has(&"grid") and seen.has(&"terrain") and seen.has(&"biome"), "%s passed the grid, terrain and biome stages" % what)

func _test_progress_monotonic_bytes() -> void:
	var log := []
	var circ := float(W) * Bake.CELL_M
	var with_cb := Bake.bake_planet(7, W, H, circ, Bake.RIVER_FLOW, _record(log))
	var plain := Bake.bake_planet(7, W, H, circ, Bake.RIVER_FLOW)
	_assert_forward(log, "bake_planet")
	assert_eq(Bake.hash_hex(Bake.to_bytes(with_cb)), Bake.hash_hex(Bake.to_bytes(plain)), "a progress callback does not change a byte")

func _test_progress_gd() -> void:
	var log := []
	var sea := 0
	var a := Bake.bake_gd(_grid(), W, H, sea, 12, _record(log))
	var b := Bake.bake_gd(_grid(), W, H, sea, 12)
	assert_true(log.size() >= 4 and log[0] == [&"terrain", 0.0] and log[log.size() - 1] == [&"terrain", 1.0], "the GDScript bake reports its steps from 0 to 1")
	var prev := -1.0
	for e in log:
		assert_true(e[1] >= prev, "terrain fraction only grows")
		prev = e[1]
	assert_eq(Bake.hash_hex(Bake.to_bytes(a)), Bake.hash_hex(Bake.to_bytes(b)), "same bytes with a callback")

func _test_job_thread() -> void:
	var dir := "user://test_bake_job"
	var circ := float(W) * Bake.CELL_M
	var job := BakeJobScript.new()
	job.plan = BakeJobScript.plan_for(11, circ, Bake.BAKE_VERSION, dir)
	assert_false(job.plan.is_empty(), "a 32-cell planet has a plan")
	DirAccess.remove_absolute(str(job.plan.path))
	DirAccess.remove_absolute(str(job.plan.path) + ".sha256")
	assert_true(job.start(), "the job starts")
	assert_false(job.start(), "a second start is refused")
	var guard := 0
	while not job.is_done() and guard < 2000:
		OS.delay_msec(10)
		guard += 1
	assert_true(job.is_done(), "the job finishes")
	var s := job.snapshot()
	assert_true(absf(float(s.overall) - 1.0) < 0.0001, "the job ends at 100%")
	var r := job.finish()
	assert_false(bool(r.loaded), "the job baked, not read")
	var again := Bake.ensure(str(job.plan.path), 11, W, H, circ, Bake.RIVER_FLOW)
	assert_true(bool(again.loaded), "the boot's ensure reads the job's file")
	assert_eq(str(again.hash), str(r.hash), "the same hash")
	var direct := Bake.bake_planet(11, W, H, circ, Bake.RIVER_FLOW)
	assert_eq(str(r.hash), Bake.hash_hex(Bake.to_bytes(direct)), "the threaded bake equals a plain one")
	DirAccess.remove_absolute(str(job.plan.path))
	DirAccess.remove_absolute(str(job.plan.path) + ".sha256")
	DirAccess.remove_absolute(dir)

func _test_plan_for() -> void:
	assert_true(BakeJobScript.plan_for(1, 4.0 * Bake.CELL_M, 1).is_empty(), "under 8 cells keeps the local trace")
	assert_true(BakeJobScript.plan_for(1, 4000.0 * Bake.CELL_M, 1).is_empty(), "over the cell cap keeps the local trace")
	var p := BakeJobScript.plan_for(5, 1000.0 * Bake.CELL_M, 14)
	assert_eq(int(p.w), 1000, "width")
	assert_eq(int(p.h), 500, "height")
	assert_eq(str(p.path), Bake.file_path("user://bake", 5, 14, 1000, 500), "the path the boot reads")

func _test_screen_keys() -> void:
	var cats: Dictionary = I18nScript.parse_csv("res://locale/ui.csv")["catalog"]
	for key in BakeScreenScript.keys():
		assert_true(cats["en"].has(key) and str(cats["en"][key]) != "", "%s in en" % key)
		assert_true(cats["pt_BR"].has(key) and str(cats["pt_BR"][key]) != "", "%s in pt_BR" % key)
	var old := TranslationServer.get_locale()
	TranslationServer.set_locale("pt_BR")
	var pt: String = BakeScreenScript.caption(&"biome", 0.42)
	TranslationServer.set_locale("en")
	var en: String = BakeScreenScript.caption(&"biome", 0.42)
	TranslationServer.set_locale(old)
	assert_true(pt != en and pt.contains("42%") and en.contains("42%"), "the caption follows the locale and shows the percent: %s / %s" % [en, pt])
	assert_false(en.contains("bake."), "the key was translated")
	var screen := BakeScreenScript.new()
	screen._build()
	screen.show_progress(&"terrain", 0.5, 0.4)
	assert_true(screen.get_node("BakeRoot").get_child_count() > 0, "the screen builds its panel")
	screen.free()
