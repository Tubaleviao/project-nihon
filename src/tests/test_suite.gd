extends "res://src/tests/test_support.gd"
## Self-contained automated test suite: the runner.
##
## The tests live in `suites/<system>_tests.gd` (one file per system, each extending
## `test_support.gd`, which holds the shared helpers, fixtures and assertions). This node loads
## every suite file, runs each one's `register()` (a list of `_run_test` calls) and adds up the
## results. Summary is printed to the Godot output log.
##
## Run from game_root by instantiating this node and calling run().
##
## `-- --test-filter=<substring>` runs only the tests whose registered name contains the
## substring; the unregistered-test audit and the orphan check still run.

## Every suite file, in run order. A new `suites/*_tests.gd` is listed here (the audit below
## fails the run when one exists on disk but is missing from this list).
const SUITES: Array[String] = [
	"res://src/tests/suites/terrain_tests.gd",
	"res://src/tests/suites/terrain_stream_tests.gd",
	"res://src/tests/suites/voxel_tests.gd",
	"res://src/tests/suites/persistence_tests.gd",
	"res://src/tests/suites/networking_tests.gd",
	"res://src/tests/suites/ui_tests.gd",
	"res://src/tests/suites/animation_tests.gd",
	"res://src/tests/suites/death_tests.gd",
	"res://src/tests/suites/character_tests.gd",
	"res://src/tests/suites/creature_tests.gd",
	"res://src/tests/suites/creature_path_tests.gd",
	"res://src/tests/suites/settle_tests.gd",
	"res://src/tests/suites/economy_tests.gd",
	"res://src/tests/suites/settlement_tests.gd",
	"res://src/tests/suites/world_tests.gd",
	"res://src/tests/suites/runner_tests.gd",
]
## A suite file may not outgrow this (Phase 133): split it by system instead.
const MAX_SUITE_LINES := 3000
## Phase 154 — no non-test `.gd` under `src/` is longer than this. Files named here are exempt;
## the list is empty and stays that way (split the file instead).
const MAX_SOURCE_LINES := 1500
const SOURCE_LINE_ALLOW_LIST: Array = []
const SUITE_DIR := "res://src/tests/suites"
const FILTER_ARG := "--test-filter="

## The filter value in a user-arg list, or "" when absent.
static func filter_from_args(args: PackedStringArray) -> String:
	for a in args:
		if a.begins_with(FILTER_ARG):
			return a.substr(FILTER_ARG.length())
	return ""

## Names of `_test_*` methods defined on `suite` but never passed to `_run_test`.
static func unregistered_tests(suite: Object, registered: Dictionary) -> Array:
	var out: Array = []
	for m in suite.get_method_list():
		var method_name: String = str(m.get("name", ""))
		if method_name.begins_with("_test_") and not registered.has(method_name):
			out.append(method_name)
	return out

## Every `.gd` file under `dir` (recursive, `src/tests` excluded when `skip_tests`) with more than
## `cap` lines and not in `allow`, as "path (lines)" strings.
static func oversized_source_files(dir: String, cap: int, allow: Array, skip_tests: bool = true) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".gd") or allow.has(f):
			continue
		var lines := FileAccess.get_file_as_string(dir.path_join(f)).trim_suffix("\n").split("\n").size()
		if lines > cap:
			out.append("%s (%d)" % [dir.path_join(f), lines])
	for d in DirAccess.get_directories_at(dir):
		if skip_tests and d == "tests":
			continue
		out.append_array(oversized_source_files(dir.path_join(d), cap, allow, skip_tests))
	return out

## `.gd` files in the suite directory that `SUITES` does not list.
static func unlisted_suite_files() -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(SUITE_DIR):
		if f.ends_with("_tests.gd") and not SUITES.has(SUITE_DIR.path_join(f)):
			out.append(f)
	return out

## The failure line for a filter that matched nothing, or "" when the run is fine.
static func empty_filter_error(filter: String, ran: int, registered: int) -> String:
	if filter != "" and ran == 0:
		return "--test-filter=%s matched none of the %d registered tests" % [filter, registered]
	return ""

func run() -> void:
	print("\n╔══════════════════════════════════════╗")
	print("║       Project Nihon — Test Suite     ║")
	print("╚══════════════════════════════════════╝\n")
	Diag.quiet = true
	# Phase 131 — the suite reads English text and must not see the developer's saved language.
	LocaleSettingsScript.settings_path = "user://test_settings_suite.json"
	TranslationServer.set_locale("en")
	var filter := filter_from_args(OS.get_cmdline_user_args())
	if filter != "":
		print("Test filter: '%s'" % filter)

	var suites: Array = []
	for path in SUITES:
		var suite: Node = (load(path) as GDScript).new()
		suite.name = path.get_file().get_basename()
		suite.test_filter = filter
		add_child(suite)
		suites.append(suite)
		suite.register()

	# Self-check: the _run_test lists are manual, so a test function can be written but
	# forgotten from its list. Fail loudly instead of silently dropping it: any _test_* method in
	# any suite file that is not registered fails the run. Same for a suite file not in SUITES.
	for suite in suites:
		for method_name in unregistered_tests(suite, suite._registered_names):
			push_error("TestSuite: '%s' (%s) is defined but never registered — add it to the _run_test list" % [method_name, suite.name])
			_fail += 1
	for f in unlisted_suite_files():
		push_error("TestSuite: suites/%s is not listed in SUITES" % f)
		_fail += 1

	var ran := 0
	var registered := 0
	for suite in suites:
		ran += suite._ran
		registered += suite._registered
	var empty_error := empty_filter_error(filter, ran, registered)
	if empty_error != "":
		push_error("TestSuite: " + empty_error)
		_fail += 1

	# Phase 84 — the LAST check. Nothing here waits a frame (`--quit` ends the boot before one
	# lands), so every test frees what it made with `free()`, and a `queue_free` the code under
	# test made is freed by the test too. A node left parentless shows up in the engine's count.
	_assert_no_orphan_nodes()

	for suite in suites:
		_pass += suite._pass
		_fail += suite._fail
	Diag.quiet = false
	var total := _pass + _fail
	print("\n────────────────────────────────────────")
	print("Tests: %d registered, %d run%s" % [registered, ran, "" if filter == "" else " (filter '%s')" % filter])
	print("Results: %d/%d passed  (%d failed)" % [_pass, total, _fail])
	if _fail == 0:
		print("All tests passed ✓")
	else:
		push_error("TestSuite: %d test(s) FAILED" % _fail)
	print("────────────────────────────────────────\n")

	# Every test slice is torn down with .free() (immediate, not queue_free's
	# end-of-frame deferral) right after its assertions, so it is gone — and
	# disconnected from the shared GameBus — before the next test runs. Without
	# that, dozens of freed-in-name-only slices would stay alive and connected
	# through the whole suite and into game_root's world boot, re-running saves,
	# loads, crafts and chunk builds against production emissions.
	for suite in suites:
		remove_child(suite)
		suite.free()
