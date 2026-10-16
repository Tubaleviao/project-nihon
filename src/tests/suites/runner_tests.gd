extends "res://src/tests/test_support.gd"
## Phase 133 — the runner itself: the filter arg, the registration audit across suite files and
## the size cap on a suite file.

const Runner := preload("res://src/tests/test_suite.gd")

func register() -> void:
	_run_test("runner: --test-filter parses and matches by substring", _test_runner_filter_parse_and_match)
	_run_test("runner: a filter that matches nothing fails loudly", _test_runner_empty_filter_fails)
	_run_test("runner: an unregistered _test_* in a suite file is reported", _test_runner_unregistered_audit)
	_run_test("runner: every suite file is listed and under the line cap", _test_runner_suite_files_listed_and_capped)

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
