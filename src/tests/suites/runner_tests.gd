extends "res://src/tests/test_support.gd"
## Phase 133 — the runner itself: the filter arg, the registration audit across suite files and
## the size cap on a suite file.

const Runner := preload("res://src/tests/test_suite.gd")

func register() -> void:
	_run_test("runner: --test-filter parses and matches by substring", _test_runner_filter_parse_and_match)
	_run_test("runner: a filter that matches nothing fails loudly", _test_runner_empty_filter_fails)
	_run_test("runner: an unregistered _test_* in a suite file is reported", _test_runner_unregistered_audit)
	_run_test("runner: every suite file is listed and under the line cap", _test_runner_suite_files_listed_and_capped)
	_run_test("playtest: report percentiles and hitch counts", _test_playtest_report_percentiles_and_hitches)
	_run_test("playtest: step failure, hard frame and missing step fail the run", _test_playtest_report_verdicts)
	_run_test("playtest: --playtest-bot is parsed", _test_playtest_bot_arg)
	_run_test("playtest: markdown escapes free-text detail", _test_playtest_markdown_escapes_detail)

func _test_runner_filter_parse_and_match() -> void:
	assert_eq(Runner.filter_from_args(PackedStringArray(["--run-tests"])), "", "no filter arg means no filter")
	assert_eq(Runner.filter_from_args(PackedStringArray(["--run-tests", "--test-filter=worldgen"])), "worldgen", "the value after = is the filter")
	assert_eq(Runner.filter_from_args(PackedStringArray(["--test-filter="])), "", "an empty value is no filter")
	assert_true(Runner.matches_filter("worldgen: golden generator values", "worldgen"), "a substring matches")
	assert_true(Runner.matches_filter("persistence: worldgen stamp", "worldgen"), "the substring may sit mid-name")
	assert_true(Runner.matches_filter("Terrain: Height", "terrain: height"), "matching ignores case")
	assert_false(Runner.matches_filter("terrain: height", "worldgen"), "a non-match is skipped")
	assert_true(Runner.matches_filter("anything", ""), "an empty filter runs everything")

func _test_runner_empty_filter_fails() -> void:
	assert_eq(Runner.empty_filter_error("", 0, 0), "", "no filter is never an error")
	assert_eq(Runner.empty_filter_error("worldgen", 9, 805), "", "a filter that ran tests is fine")
	var err: String = Runner.empty_filter_error("nosuchtest", 0, 805)
	assert_true(err.contains("nosuchtest") and err.contains("805"), "a filter that ran nothing names itself and the registered count")

class _Registered extends Node:
	func _test_a() -> void:
		pass
	func _test_b() -> void:
		pass

func _test_runner_unregistered_audit() -> void:
	var probe := _Registered.new()
	assert_eq(Runner.unregistered_tests(probe, {}).size(), 2, "both test methods are reported when none is registered")
	assert_eq(Runner.unregistered_tests(probe, { "_test_a": true }), ["_test_b"], "a registered one is not reported")
	assert_eq(Runner.unregistered_tests(probe, { "_test_a": true, "_test_b": true }), [], "all registered is clean")
	probe.free()
	# The real suites: every _test_* of every suite file is registered after a register() pass.
	for path in Runner.SUITES:
		var suite: Node = (load(path) as GDScript).new()
		suite.test_filter = "\u0001no test name has this\u0001"
		add_child(suite)
		suite.register()
		assert_eq(Runner.unregistered_tests(suite, suite._registered_names), [], "%s registers every _test_*" % path.get_file())
		remove_child(suite)
		suite.free()

func _test_runner_suite_files_listed_and_capped() -> void:
	assert_eq(Runner.unlisted_suite_files(), [], "every suites/*_tests.gd is listed in SUITES")
	for dir in ["res://src/tests", Runner.SUITE_DIR]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var lines := FileAccess.get_file_as_string(dir.path_join(f)).split("\n").size()
			assert_true(lines <= Runner.MAX_SUITE_LINES, "%s/%s has %d lines (cap %d)" % [dir, f, lines, Runner.MAX_SUITE_LINES])

# Phase 134 — the playtest bot's report maths.
const Bot := preload("res://src/tests/playtest_bot.gd")

func _test_playtest_report_percentiles_and_hitches() -> void:
	var frames: Array = []
	for i in range(1, 101):
		frames.append(float(i))   # 1..100 ms
	var s: Dictionary = Bot.summarize(frames)
	assert_eq(int(s["frames"]), 100, "frame count")
	assert_eq(float(s["p50_ms"]), 50.0, "p50 is the 50th of 100")
	assert_eq(float(s["p95_ms"]), 95.0, "p95 is the 95th of 100")
	assert_eq(float(s["p99_ms"]), 99.0, "p99 is the 99th of 100")
	assert_eq(float(s["max_ms"]), 100.0, "max")
	assert_eq(int(s["hitches"]), 50, "frames over 50 ms: 51..100")
	assert_eq(float(s["mean_ms"]), 50.5, "mean")
	var shuffled: Array = [30.0, 10.0, 20.0]
	assert_eq(float(Bot.summarize(shuffled)["p50_ms"]), 20.0, "input order does not matter")
	var empty: Dictionary = Bot.summarize([])
	assert_eq(int(empty["frames"]), 0, "empty list has no frames")
	assert_eq(float(empty["max_ms"]), 0.0, "empty list has max 0")
	assert_eq(int(empty["hitches"]), 0, "empty list has no hitches")

func _all_ok_steps() -> Array:
	var steps: Array = []
	for n in Bot.step_names():
		steps.append(Bot.step_record(n, true, "fine", [16.0, 17.0, 400.0], 3))
	return steps

func _test_playtest_report_verdicts() -> void:
	var good: Dictionary = Bot.build_report(_all_ok_steps())
	assert_true(bool(good["ok"]), "slow percentiles (400 ms frames) are a report, not a failure")
	assert_true((good["failures"] as Array).is_empty(), "no failures listed")
	var timed_out: Array = _all_ok_steps()
	timed_out[2] = Bot.step_record("mine", false, "no block_mined", [16.0], 0)
	var bad: Dictionary = Bot.build_report(timed_out)
	assert_false(bool(bad["ok"]), "a failed or timed-out step fails the run")
	assert_eq((bad["failures"] as Array).size(), 1, "one failure")
	assert_true(str(bad["failures"][0]).contains("mine"), "the failure names the step")
	var hard: Array = _all_ok_steps()
	hard[0] = Bot.step_record("walk", true, "ok", [16.0, 2500.0], 0)
	assert_false(bool(Bot.build_report(hard)["ok"]), "a frame over 2 s fails the run")
	var missing: Array = _all_ok_steps()
	missing.pop_back()
	assert_false(bool(Bot.build_report(missing)["ok"]), "a step that never ran fails the run")
	var md: String = Bot.report_markdown(bad)
	assert_true(md.contains("FAIL") and md.contains("| mine |"), "the markdown lists the failing step")

func _test_playtest_bot_arg() -> void:
	assert_true(Bot.requested(["--playtest-bot"]), "the flag asks for the bot")
	assert_false(Bot.requested(["--server"]), "other args do not")

func _test_playtest_markdown_escapes_detail() -> void:
	var rec := [Bot.step_record("craft", false, "research: a | b\nsecond line", [16.0], 0)]
	var md: String = Bot.report_markdown(Bot.build_report(rec))
	assert_true(md.contains("a \\| b second line"), "pipes are escaped and newlines flattened")
