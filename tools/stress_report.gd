extends SceneTree
## Phase 162 — the report step of `tools/stress.sh`, in a bare SceneTree (no game boot).
##
##   godot --headless --path . -s tools/stress_report.gd -- build <runs_dir> <out_dir> [key=value …]
##       Reads every `<runs_dir>/<profile>/<pattern>/<size>/{host,watch,bots}.json`, writes
##       `<out_dir>/report.json` and `<out_dir>/report.md`, prints `STRESS_LARGEST <series> <size>` per
##       series and `STRESS_HOTSPOT <rank> <name>` for the top hot spots, and exits 1 when any run
##       had a hard failure (a crash, a frame over 2 s, a bot dropped without a reason, an orphaned
##       peer record), 0 otherwise. Missed budgets are a report, not a failure.
##   godot … -s tools/stress_report.gd -- continue <run_dir>
##       Exits 0 when the ladder may climb past this run (its host tick p95 is under the stop
##       ceiling and the host wrote a report), 1 when it should stop.

const StressRules := preload("res://src/tests/stress_rules.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := str(args[0]) if args.size() > 0 else ""
	if mode == "build" and args.size() >= 3:
		quit(_build(str(args[1]), str(args[2]), args.slice(3)))
	elif mode == "continue" and args.size() >= 2:
		quit(_continue(str(args[1])))
	else:
		printerr("usage: stress_report.gd -- build <runs_dir> <out_dir> [k=v …] | continue <run_dir>")
		quit(2)

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}

static func _row(run_dir: String, profile: String, pattern: String, size: int) -> Dictionary:
	var row := StressRules.run_row(_read(run_dir.path_join("host.json")), _read(run_dir.path_join("watch.json")),
			_read(run_dir.path_join("bots.json")))
	# The directory names what was run, even when a recorder never wrote its file.
	row["profile"] = profile
	row["pattern"] = pattern
	row["size"] = size
	return row

func _continue(run_dir: String) -> int:
	var host := _read(run_dir.path_join("host.json"))
	if host.is_empty():
		return 1
	var p95 := StressRules.percentile(host.get("tick_ms", []), 95.0)
	print("STRESS_TICK_P95 %.3f" % p95)
	return 0 if p95 <= StressRules.LADDER_STOP_TICK_P95_MS else 1

func _build(runs_dir: String, out_dir: String, extra: Array) -> int:
	var rows: Array = []
	for profile in DirAccess.get_directories_at(runs_dir):
		for pattern in DirAccess.get_directories_at(runs_dir.path_join(profile)):
			for size in DirAccess.get_directories_at(runs_dir.path_join(profile).path_join(pattern)):
				if not size.is_valid_int():
					continue
				rows.append(_row(runs_dir.path_join(profile).path_join(pattern).path_join(size), profile, pattern, int(size)))
	var meta := {}
	for kv in extra:
		var parts := str(kv).split("=", true, 1)
		if parts.size() == 2:
			meta[parts[0]] = parts[1]
	var report := StressRules.build_report(rows, meta)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var fj := FileAccess.open(out_dir.path_join("report.json"), FileAccess.WRITE)
	if fj == null:
		push_error("stress_report: cannot write %s" % out_dir)
		return 1
	fj.store_string(JSON.stringify(report, "  "))
	fj.close()
	var fm := FileAccess.open(out_dir.path_join("report.md"), FileAccess.WRITE)
	fm.store_string(StressRules.report_markdown(report))
	fm.close()
	var series: Dictionary = report["series"]
	for key in series:
		print("STRESS_LARGEST %s %d" % [key, int(series[key]["largest_passing"])])
	var rank := 1
	for h in report["hot_spots"]:
		if rank > 5:
			break
		print("STRESS_HOTSPOT %d %s:%s %.3f" % [rank, str(h["kind"]), str(h["name"]), float(h["budget_share"])])
		rank += 1
	for f in report["hard_failures"]:
		print("STRESS_HARD_FAILURE %s" % str(f))
	print("STRESS_RUNS %d" % rows.size())
	return 1 if not (report["hard_failures"] as Array).is_empty() or rows.is_empty() else 0
