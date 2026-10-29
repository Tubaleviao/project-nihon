extends "res://src/tests/test_support.gd"
## Phase 133 — the runner itself: the filter arg, the registration audit across suite files and
## the size cap on a suite file.

const Runner := preload("res://src/tests/test_suite.gd")

func register() -> void:
	_run_test("runner: --test-filter parses and matches by substring", _test_runner_filter_parse_and_match)
	_run_test("runner: a filter that matches nothing fails loudly", _test_runner_empty_filter_fails)
	_run_test("runner: an unregistered _test_* in a suite file is reported", _test_runner_unregistered_audit)
	_run_test("runner: every suite file is listed and under the line cap", _test_runner_suite_files_listed_and_capped)
	_run_test("runner: no source file under src/ is over the line cap", _test_runner_source_size_audit)
	_run_test("playtest: report percentiles and hitch counts", _test_playtest_report_percentiles_and_hitches)
	_run_test("playtest: p95 process budget gate", _test_playtest_budget_gate)
	_run_test("playtest: step failure, hard frame and missing step fail the run", _test_playtest_report_verdicts)
	_run_test("playtest: --playtest-bot is parsed", _test_playtest_bot_arg)
	_run_test("playtest: the world seed is pinned unless --playtest-seed names one", _test_playtest_seed_arg)
	_run_test("playtest: the bot mutates no slice directly", _test_playtest_bot_uses_intents)
	_run_test("playtest: markdown escapes free-text detail", _test_playtest_markdown_escapes_detail)
	_run_test("playtest: the flight step's coverage verdict", _test_playtest_flight_verdict)
	_run_test("playtest: the profiler sums each phase over all frames and over the worst ones", _test_playtest_profiler_summary)
	_run_test("playtest: the bot's player id is pinned and shaped like a minted one", _test_playtest_player_id_pinned)

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

# Phase 154 — the source size audit passes on the real tree and fails on an oversized fixture.
func _test_runner_source_size_audit() -> void:
	assert_eq(Runner.SOURCE_LINE_ALLOW_LIST, [], "the size allow-list is empty")
	assert_eq(Runner.oversized_source_files("res://src", Runner.MAX_SOURCE_LINES, Runner.SOURCE_LINE_ALLOW_LIST), [], "no src/ file is over the cap")
	var dir := "user://size_audit_fixture"
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("big.gd"), FileAccess.WRITE)
	f.store_string("\n".repeat(Runner.MAX_SOURCE_LINES + 5))
	f.close()
	var hits := Runner.oversized_source_files(dir, Runner.MAX_SOURCE_LINES, [])
	assert_eq(hits.size(), 1, "a fixture over the cap is reported")
	assert_eq(Runner.oversized_source_files(dir, Runner.MAX_SOURCE_LINES, ["big.gd"]), [], "an allow-listed file is skipped")
	# A file of exactly the cap (trailing newline included) is within it.
	f = FileAccess.open(dir.path_join("big.gd"), FileAccess.WRITE)
	f.store_string("x\n".repeat(Runner.MAX_SOURCE_LINES))
	f.close()
	assert_eq(Runner.oversized_source_files(dir, Runner.MAX_SOURCE_LINES, []), [], "a file of exactly the cap passes")
	DirAccess.remove_absolute(dir.path_join("big.gd"))
	DirAccess.remove_absolute(dir)

# Phase 134 — the playtest bot's report maths.
const Bot := preload("res://src/tests/playtest_bot.gd")
const ProcessProfiler := preload("res://src/tests/process_profiler.gd")

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
	timed_out[Bot.step_names().find("mine")] = Bot.step_record("mine", false, "no block_mined", [16.0], 0)
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

## Phase 174 — a step over its p95 process budget (+25% headroom) fails the run; an injected 40 ms step does.
func _test_playtest_budget_gate() -> void:
	var budgets := { "walk": 10.0, "craft": 10.0, "fight": 10.0 }
	var steps: Array = []
	for n in Bot.step_names():
		steps.append(Bot.step_record(n, true, "fine", [16.0, 17.0], 0, { "process_ms": [8.0, 9.0, 10.0], "physics_ms": [1.0], "render_ms": [2.0] }))
	var wi := Bot.step_names().find("walk")   # Phase 181: `create` runs first
	assert_true(bool(Bot.build_report(steps, budgets)["ok"]), "a step at its budget passes")
	assert_eq(float(steps[wi]["process_ms"]["p95"]), 10.0, "the record carries the process p95")
	assert_eq(float(steps[wi]["physics_ms"]["p50"]), 1.0, "the record carries physics")
	assert_eq(float(steps[wi]["render_ms"]["max"]), 2.0, "the record carries render")
	steps[wi] = Bot.step_record("walk", true, "fine", [16.0], 0, { "process_ms": [12.4] })
	assert_true(bool(Bot.build_report(steps, budgets)["ok"]), "12.4 ms is inside 10 ms + 25%")
	steps[wi] = Bot.step_record("walk", true, "fine", [16.0], 0, { "process_ms": [12.6] })
	assert_false(bool(Bot.build_report(steps, budgets)["ok"]), "12.6 ms is over 10 ms + 25%")
	steps[wi] = Bot.step_record("walk", true, "fine", [16.0], 0, { "process_ms": [40.0, 40.0, 40.0, 40.0] })
	var bad: Dictionary = Bot.build_report(steps, budgets)
	assert_false(bool(bad["ok"]), "an injected 40 ms step fails the run")
	assert_true(str(bad["failures"][0]).contains("walk"), "the failure names the step")
	assert_true(bool(Bot.build_report(steps)["ok"]), "no budgets, no gate")
	var table: Dictionary = Bot.load_budgets()
	var md := FileAccess.get_file_as_string("res://docs/perf/playtest-baseline.md")
	for n in ["walk", "craft", "fight"]:
		assert_true(table.has(n), "the budget table covers %s" % n)
		assert_true(md.contains("| %s | %d |" % [n, int(table.get(n, -1))]), "playtest-baseline.md lists the %s budget" % n)

## Phase 150 — the bot plays through the bus and the player's own keys: no direct slice mutation.
func _test_playtest_bot_uses_intents() -> void:
	var src := FileAccess.get_file_as_string("res://src/tests/playtest_bot.gd")
	var rx := RegEx.new()
	rx.compile("\\.(try_place_station|place_station|craft|begin_research|complete_research|note_exact)\\(")
	var hits := rx.search_all(src)
	assert_eq(hits.size(), 0, "playtest_bot.gd calls no direct mutation (found %s)" % str(hits.map(func(m): return m.get_string())))
	assert_true(src.contains("GameBus.craft_requested.emit") and src.contains("GameBus.research_requested.emit"), "craft and research go through intents")

func _test_playtest_bot_arg() -> void:
	assert_true(Bot.requested(["--playtest-bot"]), "the flag asks for the bot")
	assert_false(Bot.requested(["--server"]), "other args do not")

func _test_playtest_seed_arg() -> void:
	assert_eq(Bot.seed_from_args(["--playtest-bot"]), Bot.WORLD_SEED, "no override: the pinned seed")
	assert_eq(Bot.seed_from_args(["--playtest-bot", "--playtest-seed", "42"]), 42, "the override names the seed")
	assert_eq(Bot.seed_from_args(["--playtest-bot", "--playtest-seed", "--no-native"]), Bot.WORLD_SEED, "a missing value keeps the pinned seed")

func _test_playtest_markdown_escapes_detail() -> void:
	var rec := [Bot.step_record("craft", false, "research: a | b\nsecond line", [16.0], 0)]
	var md: String = Bot.report_markdown(Bot.build_report(rec))
	assert_true(md.contains("a \\| b second line"), "pipes are escaped and newlines flattened")

## Phase 187 — the flight step passes when the ground under the body was built in FLIGHT_MIN_COVER of the samples.
func _test_playtest_flight_verdict() -> void:
	assert_eq(Bot.FLIGHT_SPEED_MPS, 270.0, "the top admin speed (Phase 191): 4.5 m/s × 30 × 2")
	assert_eq(Bot.flight_speed_from_args(["--playtest-bot", "--playtest-flight-speed", "10"]), 90.0, "the slow-machine run flies at the old 90 m/s")
	assert_eq(Bot.flight_speed_from_args(["--playtest-bot"]), 270.0, "else at the top speed")
	assert_eq(Bot.flight_speed_from_args(["--playtest-flight-speed", "99"]), 270.0, "a factor over the admin cap is clamped")
	assert_eq(Bot.only_from_args(["--playtest-only", "flight"]), "flight", "--playtest-only names one step")
	assert_eq(Bot.only_from_args(["--playtest-bot"]), "", "no flag, every step")
	assert_eq(Bot.all_step_names().size(), 15, "the full list: Phase 179 added character_sheet, Phase 181 create, Phase 186 tutorial")
	assert_eq(str(Bot.all_step_names()[0]), "create", "Phase 181: the character is created before the first walk")
	var v: Dictionary = Bot.flight_verdict([1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0], [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.5])
	assert_true(bool(v["ok"]), "nine of ten passes")
	assert_eq(float(v["worst_ring"]), 0.5, "the worst ring sample is kept")
	assert_false(bool(Bot.flight_verdict([1.0, 0.0], [1.0, 0.0])["ok"]), "half is a failure")
	assert_false(bool(Bot.flight_verdict([1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0.0, 1.0, 1.0], [])["ok"]), "seven of ten is under the floor")
	assert_false(bool(Bot.flight_verdict([], [])["ok"]), "no samples is a failure")
	# PR #518 lowered the floor to 0.75 (#519): pin it so a later change is a visible one.
	assert_eq(Bot.FLIGHT_MIN_COVER, 0.75, "the flight floor is 75%")
	assert_true(bool(Bot.flight_verdict([1.0, 1.0, 1.0, 0.0], [])["ok"]), "three of four sits on the floor and passes")
	assert_false(bool(Bot.flight_verdict([1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.4, 0.0, 0.0], [])["ok"]), "7.4 of ten is just under the floor")
	assert_true("flight" in Bot.step_names(), "the bot has a flight step")
	# Phase 189 — the flight step's main-thread cost is the chunk manager's pump and the phases nested in it.
	var times := { "chunks": 4000, "chunk_attach_collision": 1500, "chunk_attach_mesh": 500, "creature_ai": 9000 }
	assert_eq(Bot.chunk_main_ms(times), 6.0, "chunks + chunk_* in ms, other phases left out")
	assert_eq(Bot.chunk_main_ms({}), 0.0, "an empty probe is no time")
	assert_eq(Bot.chunk_phases_ms(times, 2), { "chunks": 2.0, "chunk_attach_collision": 0.75, "chunk_attach_mesh": 0.25 },
		"the breakdown is per attached chunk, chunk phases only")
	assert_eq(Bot.chunk_phases_ms(times, 0), {}, "no attach, no breakdown")
	assert_eq(Bot.near_ring_ms({ "chunks": 4000, "chunk_attach_collision": 1500, "chunk_contents": 700, "chunk_attach_mesh": 500 }), 2.2,
		"the gated cost is collision and contents only")
	assert_eq(Bot.near_ring_ms(times), 1.5, "a flight that spawned nothing has collision only")
	# Phase 194 (#504) — the shares are defined once: the CI gate reads them from the bot's source.
	var gate := FileAccess.get_file_as_string("res://tools/check_playtest_budget.py")
	assert_true(gate.contains('FLIGHT_MAX_SHARE = bot_const("FLIGHT_MAX_SHARE")') and gate.contains('FLIGHT_WORKER_MAX_SHARE = bot_const("FLIGHT_WORKER_MAX_SHARE")'),
		"the CI gate reads both flight shares from the bot")
	assert_true(is_equal_approx(Bot.FLIGHT_WORKER_MAX_SHARE, 1.0 / 3.0), "the worker share is a third")
	# ... and the bot's own verdict enforces them on a budgeted run (CI's runs report only and gate the median).
	var flight := func(near: float, record_near: float, worker: float, record_worker: float) -> Array:
		return [{ "step": "flight", "ok": true, "max_ms": 10.0, "detail": "", "flight": { "attached": 20, "record_attached": 20,
			"near_ms_per_attach": near, "record_near_ms_per_attach": record_near,
			"crossings": 30, "record_crossings": 30, "worker_ms_per_crossing": worker, "record_worker_ms_per_crossing": record_worker } }]
	assert_eq(Bot.flight_share_failures(flight.call(2.0, 10.0, 40.0, 200.0)), [], "under both shares passes")
	assert_eq(Bot.flight_share_failures(flight.call(6.0, 10.0, 40.0, 200.0)).size(), 1, "collision and contents over half the record fail")
	assert_eq(Bot.flight_share_failures(flight.call(2.0, 10.0, 100.0, 200.0)).size(), 1, "worker ms over a third of the record fail")
	assert_eq(Bot.flight_share_failures([{ "step": "flight", "flight": { "attached": 0 } }]), [], "a flight that attached nothing is not judged on shares")
	assert_true(Bot.build_report(flight.call(6.0, 10.0, 40.0, 200.0), { "walk": 1000.0 })["failures"].any(func(f): return str(f).begins_with("flight:")),
		"a budgeted run fails on the share")
	assert_false(Bot.build_report(flight.call(6.0, 10.0, 40.0, 200.0), {})["failures"].any(func(f): return str(f).begins_with("flight:")),
		"a `--playtest-no-budget` run reports it only")
	# Phase 194 (#504, #512) — the runner checks what a step left behind, and an unknown step name is refused.
	assert_eq(Bot.state_leaks({ "flying": false, "near_ring": true, "tick_probe": false }, { "flying": true, "near_ring": false, "tick_probe": false }),
		["flying on", "near_ring off"], "a step that left the body flying and the ring off is named")
	assert_eq(Bot.state_leaks({ "flying": false }, { "flying": false }), [], "nothing changed, nothing named")
	assert_eq(Bot.only_from_args(["--playtest-abort", "flight"], Bot.ABORT_ARG), "flight", "--playtest-abort names a step")
	assert_false("nosuch" in Bot.all_step_names(), "an unknown name is no step (the run exits 1 on it)")

## Phase 183 — `--playtest-profile`: per phase, the mean ms over every frame and over the worst 5% by total.
func _test_playtest_profiler_summary() -> void:
	assert_true(ProcessProfiler.requested(["--playtest-bot", "--playtest-profile"]), "the flag asks for the profiler")
	assert_false(ProcessProfiler.requested(["--playtest-bot"]), "off by default")
	var frames: Array = []
	for i in 19:
		frames.append({ "node:a": 1000, "node:b": 2000 })   # 3 ms frames
	frames.append({ "node:a": 1000, "node:b": 2000, "chunk_attach_collision": 9000 })   # the one 12 ms frame
	var s := ProcessProfiler.summarize(frames)
	assert_true(is_equal_approx(float(s["node:a"]["mean"]), 1.0), "a phase in every frame: its mean")
	assert_true(is_equal_approx(float(s["chunk_attach_collision"]["mean"]), 0.45), "a phase in one frame of 20: spread over all")
	assert_true(is_equal_approx(float(s["chunk_attach_collision"]["worst_mean"]), 9.0), "and all of it in the worst frame (1 of 20 at 5%)")
	assert_true(is_equal_approx(float(s["node:b"]["worst_mean"]), 2.0), "the worst frame's other phases too")
	assert_eq(ProcessProfiler.summarize([]), {}, "no frames, no phases")

func _test_playtest_player_id_pinned() -> void:
	assert_true(PlayerRegistry.looks_like_player_id(Bot.PLAYER_ID), "the pinned id has the minted shape (redaction and validation treat it as one)")
	var src := FileAccess.get_file_as_string("res://src/tests/playtest_bot.gd")
	assert_true(src.contains("_persistence_wiring.fixed_local_id = PLAYER_ID"), "the bot pins it before the world boot")
