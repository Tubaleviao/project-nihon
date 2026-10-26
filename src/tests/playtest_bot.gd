extends Node
## Phase 134 — a scripted bot plays a real rendered session.
##
## `--playtest-bot` (a user arg, after `--`) boots the normal listen host WITH rendering and runs a
## fixed step list through the same intents a player's input sends: walk (W key held), stream
## (20 chunks), mine, gather, craft, place, fight, travel, pole (a crossing over the north pole). A
## step that does not reach its expected state within its timeout fails, and so does the run. While a step runs the bot records the
## frame times, and after it a screenshot, so a human playtest is one artifact download away.
##
## Output (`playtest/`, next to the project): `report.json`, `report.md` and `<step>.png`.
## Perf is gated on p95 PROCESS time per step (Phase 174, `docs/perf/playtest-budget.json`, +25% headroom); wall frame time stays a report,
## because software rendering inflates it. Other hard failures: a step timeout, a frame over HARD_FRAME_MS, or a crash (no report at all).
##
## The report maths (percentiles, hitches, verdicts, markdown) is static and pure, so the
## synchronous suite pins it (`_test_playtest_report_*`); `run()` is the only part that needs frames.
##
## Public API:
##   requested(args) -> bool                  — static, is the bot asked for
##   run(root) -> void                        — drive the steps, write the report, quit
##   summarize(frames_ms) -> Dictionary       — static: p50/p95/p99/max/mean/hitches/frames
##   percentile(sorted_ms, p) -> float        — static, nearest-rank
##   step_record(name, ok, detail, frames_ms, chunk_builds) -> Dictionary  — static
##   build_report(steps) -> Dictionary        — static: steps + run verdict + hard failures
##   report_markdown(report) -> String        — static
##   step_names() -> Array                    — static, the fixed step order

const VoxelSlice := preload("res://src/terrain/voxel_slice.gd")
const WorldPos := preload("res://src/terrain/world_pos.gd")
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const WaystoneSlice := preload("res://src/world/waystone_slice.gd")
const WorldShape := preload("res://src/terrain/world_shape.gd")
const Horizon := preload("res://src/terrain/horizon.gd")
const DistantTerrain := preload("res://src/terrain/distant_terrain.gd")
const DistantBands := preload("res://src/terrain/distant_bands.gd")
const PlayerSlice := preload("res://src/player/player_slice.gd")
const AdminRules := preload("res://src/admin/admin_rules.gd")
const TickProbe := preload("res://src/core/tick_probe.gd")

const ARG := "--playtest-bot"
const OUT_DIR := "res://playtest"
## The bot's own save directory, emptied before the boot: a saved world must not pick the seed.
const SAVE_DIR := "user://playtest/server/"
## The world seed every run plays, so a step's verdict depends on the commit, not on a random world:
## on a fresh `randi()` seed far_peak, travel and horizon passed or failed by luck (a seed's tallest
## ridge is ~350 m against far_peak's 330). Where the bot stands still varies run to run (builder,
## walk distance), so far_peak also hops between search origins (`FAR_PEAK_HOP_M`). 42, 31 and 7
## passed every step locally; 162 failed walk. `--playtest-seed <n>` plays another seed.
const WORLD_SEED := 42
const SEED_ARG := "--playtest-seed"
const HITCH_MS := 50.0        ## a frame over this is a hitch (counted, not a failure)
const HARD_FRAME_MS := 2000.0 ## a frame over this fails the run
const STEP_TIMEOUT_SECS := 60.0 ## wall clock for a WHOLE step, not for one wait inside it
const STREAM_TIMEOUT_SECS := 300.0 ## the stream step builds 20 chunks one hop at a time; software rendering is slow
const WARMUP_FRAMES := 3     ## the first frames of a step (shader compile, first upload) are not recorded
const BOOT_TIMEOUT_SECS := 120.0
const WATCHDOG_SLACK_SECS := 60.0 ## whole-run budget = boot + every step's timeout + this
const STREAM_CHUNKS := 20
const SHADER_SHARE_LIMIT := 0.5   ## Phase 170: heightmap share of the build above which a compute shader is justified
const RATE_CHUNKS := 24      ## chunks the stream step times the pure worker build on (Phase 169)
const NativeBuilder := preload("res://src/terrain/native_builder.gd")
const BUDGET_PATH := "res://docs/perf/playtest-budget.json"   ## Phase 174: per-step p95 process budget (ms), source of the table in playtest-baseline.md
const BUDGET_HEADROOM := 1.25   ## a step fails the gate above budget * this, so a noisy shared runner does not fail unrelated PRs
const NO_BUDGET_ARG := "--playtest-no-budget"   ## report only: CI runs the bot 3 times with this and gates the median (tools/check_playtest_budget.py)
const WALK_SECS := 3.0
const WALK_MIN_M := 4.0        ## the walk step keeps going until the body has moved this far
const WALK_MAX_SECS := 20.0   ## ... but not past this
const WALK_FOOT_SECS := 2.0   ## the walk step samples the feet over the last this many seconds
## The feet must swap the lead at least this often over the window. A share-of-frames check flaked
## under xvfb: ~10 fps samples alias with the gait, so a cycling walk could read 14% one foot ahead.
const WALK_FOOT_MIN_SWITCHES := 2
const WALK_FOOT_DEADBAND_M := 0.03   ## a lead smaller than this is the feet passing, not a swap
const GATHER_SEARCH_CHUNKS := 30  ## forest chunks the gather step will hop to at most
const GATHER_SEARCH_RADIUS := 60  ## chunk rings around the body it scans for forest
const GATHER_FAR_BEARINGS := 16    ## rays the far scan casts when the rings hold no forest
const GATHER_FAR_STEP := 8         ## chunks between samples along a far-scan ray
const GATHER_FAR_RADIUS := 4000    ## chunks a far-scan ray reaches
const FIGHT_RANGE_M := 1.5
## Phase 187 — the flight step: the body is carried east at the top admin speed (walk speed × the
## `/speed` cap × the flying factor: 90 m/s) for FLIGHT_SECS, and the chunk under it must be built in
## at least FLIGHT_MIN_COVER of the samples taken after FLIGHT_WARMUP_SECS (the first crossings drain
## the queue the start position left behind). Gated with the native builder only.
const FLIGHT_SPEED_MPS := PlayerSlice.SPEED * AdminRules.SPEED_MAX * AdminRules.FLY_SPEED_FACTOR
const FLIGHT_SECS := 12.0
const FLIGHT_WARMUP_SECS := 1.5
const FLIGHT_SAMPLE_SECS := 0.25
const FLIGHT_MIN_COVER := 0.9
const FLIGHT_MAX_SHARE := 0.5   ## Phase 189: near-ring ms per attached chunk at most this share of the record flight's (CI median)
## Phase 189 — the chunk phases the near ring removes: off-ring collision bodies and contents spawned under a
## fast player. The gate compares these; the rest of the pump (mesh upload, dispatch) is report-only, since
## its share varies with the machine (a 2-core llvmpipe runner pays ~4 ms more per chunk on both flights).
const NEAR_RING_PHASES := ["chunk_attach_collision", "chunk_contents"]
const TELEPORT_SETTLE_MS := 1500 ## frames this long after a teleport (the new window's builds) are not recorded
const STEP_GRACE_SECS := 10.0    ## past its deadline a step that has not returned has crashed or hung: fail it
const SPAWN_OFFSET_M := 2.0      ## a teleport lands this far above the ground
const FIGHT_MAX_GROUND_GAP_M := 2.0
const CREATURE_CLEAR_M := 60.0   ## fight's harvest removes the world's creatures this near the body
const HARVEST_TRIES := 3         ## fight's harvest tries: one a hit cancels ("damaged") is retried
const ARRIVE_TOLERANCE_M := 2.0    ## travel lands the body on the destination stone, within this ground distance
## Phase 164 — the horizon step: from the nearest coast, look out to sea in four headings and read the
## skyline of the distant ring alone (drawn over a key colour), which must be level to SKYLINE_FLAT_PX.
const HORIZON_TIMEOUT_SECS := 240.0
const SKYLINE_KEY := Color(1.0, 0.0, 1.0)
const SKYLINE_FLAT_PX := 2
const HORIZON_PITCH := -20.0          ## a shallow down-look (about PlayerSlice.CAMERA_PITCH), the skyline in the frame's upper part
const HORIZON_HEADINGS := [-15.0, -5.0, 5.0, 15.0]   ## degrees either side of the open-sea bearing
const HORIZON_HALF_FOV := 60.0        ## rays are checked this far either side of each heading (the frame's half width)
const HORIZON_RAY_STEP := 5.0         ## degrees between checked rays
const HORIZON_RISE_MAX := 0.002       ## radians (~1 px): land may rise this far over the sea horizon (half the skyline limit)
const HORIZON_STAND_TOLERANCE_M := 3.0   ## the body must stand within this far under the built coast ground
## Phase 165 — the far_peak step: stand `FAR_PEAK_DISTANCE_M` from a tall ridge on the world seed and look
## at it with only the ring and the bands drawn: rock or snow must show above the ring's skyline.
const FAR_PEAK_DISTANCE_M := 60000.0
const FAR_PEAK_MIN_HEIGHT := 330.0    ## 80+ m over the horizon from 60 km (about 250 m for the camera's eye): a ridge barely over it shows a few pixels
const FAR_PEAK_SEARCH_M := 2.0e6      ## the ridge is looked for this far from the body, nearest square ring first
const FAR_PEAK_SEARCH_STEP_M := 8000.0
const FAR_PEAK_EXTRA_RINGS := 40     ## rings searched past the first with a ridge, for more candidates
const FAR_PEAK_CANDIDATES := 8       ## nearest ridges with a usable vantage compared (the most open sight line wins)
const FAR_PEAK_ATTEMPTS := 3         ## vantages tried per search origin (most open sight line first): a hill beside one can hide the bands behind the ring's own skyline
const FAR_PEAK_MAX_TRIES := 8        ## vantages tried in all, over every search origin
const FAR_PEAK_HOP_M := 500000.0     ## when an origin's vantages all fail, search again this far N/E/S/W of the body
const FAR_PEAK_SAME_RIDGE_M := 30000.0   ## a vantage on a peak this close to one already tried is skipped (same massif)
const FAR_PEAK_STEP_SECS := 900.0    ## wall clock for the whole step (a try takes ~20-50 s)
const FAR_PEAK_MIN_PX := 8            ## rock or snow pixels above the ring's skyline needed to pass
const FAR_PEAK_SAT_MAX := 0.18        ## rock (grey) and snow (white) are below this saturation; land and sea are not
const FAR_PEAK_TIMEOUT_SECS := 240.0
const RIDGE_SIGHT_STEP_M := 500.0   ## the sight line to the ridge is sampled this often (`ridge_clearance`)
const COAST_SEARCH_M := 4.0e6         ## the coast search marches this far from the body
const COAST_BEARING_STEP := 11.25     ## degrees between marched bearings
const COAST_MARCH_M := 2000.0         ## march step on the large-scale shape
const COAST_INLAND_M := 48.0          ## the body stands this far back from the shore
const COAST_DEEP_M := 20.0            ## open water: the shape lies this far under the sea level
const COAST_WORK_MS := 40             ## search work per frame before it yields

var _root: Node
var _frames: Array = []       ## frame times (ms) of the step in flight
var _process_ms: Array = []   ## Phase 174: per recorded frame, the scene tree's _process work (ms), first callback to last
var _physics_ms: Array = []   ## ... the _physics_process work of the ticks that ran before it (0 when none did)
var _render_ms: Array = []    ## ... measured render time of the root viewport, CPU + GPU (0 headless)
var _recording: bool = false
var _frame_start_us: int = 0   ## this frame's first _process callback (the bot's own, see FrameEnd)
var _frame_delta_ms: float = -1.0   ## this frame's delta when it is recorded, -1 when it is skipped
var _physics_start_us: int = 0
var _physics_frame_us: int = 0   ## physics work since the last recorded frame
var _skip_frames: int = 0
var _place_refusal: String = ""   ## why `_place_walking`'s last try was refused (for the step's detail)
var _skip_until_ms: int = 0   ## frames before this tick are not recorded (just after a teleport)
var _step_result: Array = []  ## set by the step runner when its coroutine returns; empty while it runs
var _step_deadline_ms: int = 0
var _chunk_builds: int = 0
var _build_breakdown: Dictionary = {}   ## Phase 170: the stream step's per-stage build time
var _stream_rate: float = 0.0   ## the stream step's chunk build rate (chunks/s), 0 until it ran
var _flight: Dictionary = {}   ## Phase 187: the flight step's coverage record
var _mined: Array = []
var _chopped: Array = []
var _crafted: Array = []
var _researched: Array = []
var _placed: Array = []
var _steps_done: Array = []   ## finished step records, for the watchdog's partial report

static func requested(args: Array) -> bool:
	return ARG in args

## The seed a run with `args` plays: `--playtest-seed <n>` when given, else `WORLD_SEED`.
static func seed_from_args(args: Array) -> int:
	var i := args.find(SEED_ARG)
	if i >= 0 and i + 1 < args.size() and str(args[i + 1]).is_valid_int():
		return int(str(args[i + 1]))
	return WORLD_SEED

## Before the world boot: an emptied save directory and the pinned seed, so every run plays one world.
static func prepare(root: Node) -> void:
	var args := Array(OS.get_cmdline_user_args())
	if not requested(args) or root._is_client or root._is_server:
		return
	root._persistence.server_save_dir = SAVE_DIR
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	_clear_dir(SAVE_DIR)
	var seed_v := seed_from_args(args)
	root._terrain.set_world_seed(seed_v)
	print("[Playtest] world seed %d" % seed_v)

static func _clear_dir(path: String) -> void:
	if not path.begins_with("user://playtest/") or ".." in path:
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_clear_dir(path.path_join(sub))
		dir.remove(sub)
	for file in dir.get_files():
		dir.remove(file)

static func _step_timeout(step: String) -> float:
	if step == "horizon":
		return HORIZON_TIMEOUT_SECS
	if step == "far_peak":
		return FAR_PEAK_STEP_SECS
	return STREAM_TIMEOUT_SECS if step == "stream" or step == "pole" or step == "flight" else STEP_TIMEOUT_SECS

static func step_names() -> Array:
	return ["walk", "stream", "flight", "mine", "gather", "craft", "place", "fight", "travel", "horizon", "far_peak", "pole"]

# ---------------------------------------------------------------------------
# Pure report maths
# ---------------------------------------------------------------------------

## Nearest-rank percentile (p in 0..100) of an ascending list; 0.0 for an empty list.
static func percentile(sorted_ms: Array, p: float) -> float:
	if sorted_ms.is_empty():
		return 0.0
	var rank := int(ceil(p / 100.0 * float(sorted_ms.size())))
	return float(sorted_ms[clampi(rank - 1, 0, sorted_ms.size() - 1)])

static func summarize(frames_ms: Array) -> Dictionary:
	var sorted := frames_ms.duplicate()
	sorted.sort()
	var total := 0.0
	var hitches := 0
	for f in sorted:
		total += float(f)
		if float(f) > HITCH_MS:
			hitches += 1
	return {
		"frames": sorted.size(),
		"mean_ms": total / float(sorted.size()) if not sorted.is_empty() else 0.0,
		"p50_ms": percentile(sorted, 50.0),
		"p95_ms": percentile(sorted, 95.0),
		"p99_ms": percentile(sorted, 99.0),
		"max_ms": float(sorted.back()) if not sorted.is_empty() else 0.0,
		"hitches": hitches,
	}

## Phase 174: p50/p95/max of one frame-time part.
static func part_summary(values_ms: Array) -> Dictionary:
	var s := summarize(values_ms)
	return { "p50": s["p50_ms"], "p95": s["p95_ms"], "max": s["max_ms"] }

static func step_record(step: String, ok: bool, detail: String, frames_ms: Array, chunk_builds: int, parts: Dictionary = {}) -> Dictionary:
	var rec := summarize(frames_ms)
	for key in ["process_ms", "physics_ms", "render_ms"]:
		rec[key] = part_summary(parts.get(key, []))
	rec["step"] = step
	rec["ok"] = ok
	rec["detail"] = detail
	rec["chunk_builds"] = chunk_builds
	return rec

## Phase 174 — the steps whose p95 process time is over budget * headroom. `budgets` maps step to ms.
static func budget_failures(steps: Array, budgets: Dictionary, headroom: float = BUDGET_HEADROOM) -> Array:
	var out: Array = []
	for s in steps:
		var name := str(s["step"])
		if not budgets.has(name) or not s.has("process_ms"):
			continue
		var limit := float(budgets[name]) * headroom
		var p95 := float((s["process_ms"] as Dictionary)["p95"])
		if p95 > limit:
			out.append("step %s p95 process time %.1f ms is over its budget %.1f ms (+%d%% headroom = %.1f ms)" % [
				name, p95, float(budgets[name]), int(round((headroom - 1.0) * 100.0)), limit])
	return out

static func load_budgets() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(BUDGET_PATH))
	return parsed if parsed is Dictionary else {}

## The run verdict. `failures` names every hard failure: a failed (or timed-out) step, a frame over
## HARD_FRAME_MS, a step over its process-time budget (`budgets`, empty to skip) and a step of the
## fixed list that never ran.
static func build_report(steps: Array, budgets: Dictionary = {}) -> Dictionary:
	var failures: Array = []
	failures.append_array(budget_failures(steps, budgets))
	var seen := {}
	for s in steps:
		seen[str(s["step"])] = true
		if not bool(s["ok"]):
			failures.append("step %s failed: %s" % [s["step"], s["detail"]])
		if float(s["max_ms"]) > HARD_FRAME_MS:
			failures.append("step %s had a %.0f ms frame (limit %.0f)" % [s["step"], float(s["max_ms"]), HARD_FRAME_MS])
	for step_name in step_names():
		if not seen.has(step_name):
			failures.append("step %s never ran" % step_name)
	return { "ok": failures.is_empty(), "failures": failures, "steps": steps }

## One line, no column break: `|` and newlines in free text would split a table row.
static func _md_cell(text: String) -> String:
	return text.replace("|", "\\|").replace("\r", " ").replace("\n", " ")

static func report_markdown(report: Dictionary) -> String:
	var lines: Array = []
	lines.append("# Playtest report")
	lines.append("")
	lines.append("Result: **%s**" % ("PASS" if bool(report["ok"]) else "FAIL"))
	lines.append("")
	if report.has("adapter"):
		lines.append("Adapter: %s (%s), native builder: %s" % [_md_cell(str(report["adapter"])), _md_cell(str(report.get("driver", ""))), str(report.get("native_builder", false))])
		lines.append("")
	lines.append("| Step | Result | Frames | p50 ms | p95 ms | p99 ms | Max ms | Hitches (>%d ms) | Chunk builds | Detail |" % int(HITCH_MS))
	lines.append("|---|---|---|---|---|---|---|---|---|---|")
	for s in report["steps"]:
		lines.append("| %s | %s | %d | %.1f | %.1f | %.1f | %.1f | %d | %d | %s |" % [
			_md_cell(str(s["step"])), "ok" if bool(s["ok"]) else "FAIL", int(s["frames"]), float(s["p50_ms"]), float(s["p95_ms"]),
			float(s["p99_ms"]), float(s["max_ms"]), int(s["hitches"]), int(s["chunk_builds"]), _md_cell(str(s["detail"]))])
	lines.append("")
	lines.append("| Step | process p50/p95 ms | physics p50/p95 ms | render p50/p95 ms |")
	lines.append("|---|---|---|---|")
	for s in report["steps"]:
		if s.has("process_ms"):
			lines.append("| %s | %.1f / %.1f | %.1f / %.1f | %.1f / %.1f |" % [_md_cell(str(s["step"])),
				float(s["process_ms"]["p50"]), float(s["process_ms"]["p95"]), float(s["physics_ms"]["p50"]), float(s["physics_ms"]["p95"]),
				float(s["render_ms"]["p50"]), float(s["render_ms"]["p95"])])
	for s in report["steps"]:
		var bb: Dictionary = s.get("build_breakdown", {})
		if not bb.is_empty():
			lines.append("")
			lines.append("Build time per chunk (window radius %d, %d chunks): heightmap %.1f ms, seam %.1f ms, runs %.1f ms, arrays %.1f ms, total %.1f ms. Heightmap share %.0f%% (limit %.0f%%): **%s**." % [
				int(bb["window_radius"]), int(bb["chunks"]), float(bb["heightmap_ms"]), float(bb["seam_ms"]), float(bb["runs_ms"]),
				float(bb["arrays_ms"]), float(bb["total_ms"]), 100.0 * float(bb["heightmap_share"]), 100.0 * SHADER_SHARE_LIMIT, str(bb["decision"])])
	if not (report["failures"] as Array).is_empty():
		lines.append("")
		lines.append("## Hard failures")
		for f in report["failures"]:
			lines.append("- %s" % _md_cell(str(f)))
	lines.append("")
	return "\n".join(lines)

## Phase 164 — the skyline of a frame drawn over `key`: per column, the first row from the top that is
## not the key colour (the frame's height when the whole column is key).
static func skyline_rows(img: Image, key: Color, tol: float = 0.08) -> Array:
	var rows: Array = []
	var fmt := img.duplicate() as Image
	fmt.convert(Image.FORMAT_RGB8)
	var data := fmt.get_data()
	var w := fmt.get_width()
	var h := fmt.get_height()
	var limit := int(tol * 3.0 * 255.0)
	var kr := int(roundf(key.r * 255.0))
	var kg := int(roundf(key.g * 255.0))
	var kb := int(roundf(key.b * 255.0))
	for x in w:
		var row := h
		for y in h:
			var i := (y * w + x) * 3
			if absi(data[i] - kr) + absi(data[i + 1] - kg) + absi(data[i + 2] - kb) > limit:
				row = y
				break
		rows.append(row)
	return rows

## Phase 165 — pixels of `img` that are rock or snow (grey or white: low saturation, not the key colour)
## and lie ABOVE `ring_rows` (the first non-key row of each column of the ring-only frame). `any_colour`
## counts every non-key pixel instead: the ring-only frame shows only key above the ring's skyline, so
## whatever the bands draw there is band geometry, grassy or rocky.
static func rock_pixels_above(img: Image, ring_rows: Array, key: Color, tol: float = 0.08, any_colour: bool = false) -> int:
	var fmt := img.duplicate() as Image
	fmt.convert(Image.FORMAT_RGB8)
	var data := fmt.get_data()
	var w := fmt.get_width()
	var limit := int(tol * 3.0 * 255.0)
	var kr := int(roundf(key.r * 255.0))
	var kg := int(roundf(key.g * 255.0))
	var kb := int(roundf(key.b * 255.0))
	var count := 0
	for x in mini(w, ring_rows.size()):
		for y in int(ring_rows[x]):
			var i := (y * w + x) * 3
			if absi(data[i] - kr) + absi(data[i + 1] - kg) + absi(data[i + 2] - kb) <= limit:
				continue
			var c := Color8(data[i], data[i + 1], data[i + 2])
			if any_colour or (c.s <= FAR_PEAK_SAT_MAX and c.v > 0.15):
				count += 1
	return count

## Highest minus lowest skyline row (0 for a level skyline).
static func skyline_spread(rows: Array) -> int:
	if rows.is_empty():
		return 0
	return int(rows.max()) - int(rows.min())

# ---------------------------------------------------------------------------
# The run
# ---------------------------------------------------------------------------

func _ready() -> void:
	GameBus.block_mined.connect(func(material: String, quantity: int, _p: Vector3): _mined.append([material, quantity]))
	GameBus.tree_chopped.connect(func(id: String, wood: String, state: String, _r: float): _chopped.append([id, wood, state]))
	GameBus.craft_resolved.connect(func(result: Dictionary): _crafted.append(result))
	GameBus.research_resolved.connect(func(result: Dictionary): _researched.append(result))
	GameBus.station_placed.connect(func(id: String, type: String, _p: Vector3): _placed.append([id, type]))
	GameBus.chunk_loaded.connect(func(_c: Vector2i): _chunk_builds += 1)
	# Phase 174: the bot's callbacks run first and FrameEnd's last, so the two clocks bracket the frame's
	# _process and _physics_process work. Performance.TIME_PROCESS cannot stand in: Godot publishes the MAX
	# process time of the last second, once a second, so a per-frame sample of it is the step's worst frame.
	process_priority = FrameEnd.FIRST
	process_physics_priority = FrameEnd.FIRST
	var end := FrameEnd.new()
	end.bot = self
	add_child(end)

## The last _process and _physics_process callback of every frame (see `_ready`).
class FrameEnd extends Node:
	const FIRST := -(1 << 30)
	var bot: Node

	func _ready() -> void:
		process_priority = -FIRST
		process_physics_priority = -FIRST

	func _process(_delta: float) -> void:
		bot._end_frame()

	func _physics_process(_delta: float) -> void:
		bot._physics_frame_us += Time.get_ticks_usec() - bot._physics_start_us

func _physics_process(_delta: float) -> void:
	_physics_start_us = Time.get_ticks_usec()

func _process(delta: float) -> void:
	_frame_start_us = Time.get_ticks_usec()
	_frame_delta_ms = -1.0
	if not _recording:
		return
	if Time.get_ticks_msec() < _skip_until_ms:
		return
	if _skip_frames > 0:
		_skip_frames -= 1
		return
	_frame_delta_ms = delta * 1000.0

func _end_frame() -> void:
	var physics_us := _physics_frame_us
	_physics_frame_us = 0
	if _frame_delta_ms < 0.0 or not _recording:
		return
	_frames.append(_frame_delta_ms)
	_process_ms.append(float(Time.get_ticks_usec() - _frame_start_us) / 1000.0)
	_physics_ms.append(float(physics_us) / 1000.0)
	var vp := get_viewport().get_viewport_rid()
	_render_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.viewport_get_measured_render_time_gpu(vp))

func run(root: Node) -> void:
	_root = root
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	# A step body that hits a script error aborts its coroutine and would leave the process
	# running with no verdict; the watchdog writes what exists and quits.
	var budget := BOOT_TIMEOUT_SECS + WATCHDOG_SLACK_SECS
	for step_name in step_names():
		budget += _step_timeout(step_name)
	get_tree().create_timer(budget).timeout.connect(_on_watchdog)
	print("[Playtest] waiting for the world boot")
	var booted: bool = await _until(func(): return _root._player != null and not _root._chunk_manager._first_ring.is_empty() and _root._chunk_manager.is_first_ring_ready() \
		and not _root._pending_host_boot, BOOT_TIMEOUT_SECS)
	print("[Playtest] boot wait over: %s" % str(booted))
	var steps: Array = []
	if not booted:
		steps.append(step_record("boot", false, "world boot did not finish in %ds" % int(BOOT_TIMEOUT_SECS), [], 0))
	else:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
		_root._persistence.autosave_interval = 1.0e9   # the bot's edits must never reach the player's save
		_root._chunk_manager.record_store = null   # flush_records runs every frame; no frontier record of the bot may reach the player's region files
		_root._chunk_manager._pending_records.clear()
		_root._inventory.replace_contents({})   # a saved pack from an earlier run must not decide the result
		for step_name in step_names():
			var rec: Dictionary = await _run_step(step_name)
			_steps_done.append(rec)
			steps.append(rec)
	_finish(steps)

func _on_watchdog() -> void:
	_recording = false
	_key(KEY_W, false)
	_key(KEY_S, false)
	var steps := _steps_done.duplicate()
	steps.append(step_record("watchdog", false, "the run did not finish in time (a step crashed or hung)", [], 0))
	print("[Playtest] watchdog fired")
	_finish(steps)

## Write the report, print the verdict and quit. Pending chunk records are dropped first: the
## game's exit flush would otherwise put the bot's frontier chunks into the player's region store.
func _finish(steps: Array) -> void:
	var budgets: Dictionary = {} if NO_BUDGET_ARG in OS.get_cmdline_user_args() else load_budgets()
	var report := build_report(steps, budgets)
	report["builder"] = NativeBuilder.mode()
	report["native_builder"] = NativeBuilder.is_native()
	report["adapter"] = RenderingServer.get_video_adapter_name()
	report["driver"] = RenderingServer.get_current_rendering_driver_name()
	report["budget_ms"] = budgets
	if not _write_report(report):
		report["ok"] = false
		(report["failures"] as Array).append("the report could not be written to %s" % OUT_DIR)
	if _root != null and is_instance_valid(_root._chunk_manager):
		_root._chunk_manager._pending_records.clear()
	for f in report["failures"]:
		print("[Playtest] FAILURE: %s" % f)
	print("[Playtest] %s" % ("PASS" if bool(report["ok"]) else "FAIL"))
	get_tree().quit(0 if bool(report["ok"]) else 1)

func _run_step(step: String) -> Dictionary:
	print("[Playtest] step %s" % step)
	_frames = []
	_process_ms = []
	_physics_ms = []
	_render_ms = []
	_chunk_builds = 0
	_skip_frames = WARMUP_FRAMES
	_step_deadline_ms = Time.get_ticks_msec() + int(_step_timeout(step) * 1000.0)
	_recording = true
	_step_result = []
	_run_step_body(step)
	# A step coroutine that hits a script error never returns; its own waits all stop at the step
	# deadline, so a step still silent a little after it has crashed (or hung) and fails here, not
	# at the whole-run watchdog.
	var give_up_ms := _step_deadline_ms + int(STEP_GRACE_SECS * 1000.0)
	while _step_result.is_empty() and Time.get_ticks_msec() < give_up_ms:
		await get_tree().process_frame
	var result: Array = _step_result if not _step_result.is_empty() else [false, "step %s crashed or hung (no result %d s past its deadline)" % [step, int(STEP_GRACE_SECS)]]
	_key(KEY_W, false)
	_recording = false
	var rec := step_record(step, bool(result[0]), str(result[1]), _frames, _chunk_builds,
		{ "process_ms": _process_ms, "physics_ms": _physics_ms, "render_ms": _render_ms })
	if step == "stream":
		rec["builder"] = NativeBuilder.mode()
		rec["build_rate"] = _stream_rate
		rec["build_breakdown"] = _build_breakdown
	if step == "flight":
		rec["flight"] = _flight
	await _screenshot(step)
	print("[Playtest] %s %s %s" % [step, "ok" if bool(rec["ok"]) else "FAIL", rec["detail"]])
	return rec

func _run_step_body(step: String) -> void:
	_step_result = await call("_step_" + step)

## Poll `pred` once a frame until it holds or `secs` of wall clock pass.
func _until(pred: Callable, secs: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(secs * 1000.0)
	if _recording:
		deadline = mini(deadline, _step_deadline_ms)
	while Time.get_ticks_msec() < deadline:
		if pred.call():
			return true
		await get_tree().process_frame
	return bool(pred.call())

func _screenshot(step: String) -> void:
	if DisplayServer.get_name() == "headless":
		return   # no renderer: the CI job runs under xvfb and gets the pictures
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(ProjectSettings.globalize_path(OUT_DIR.path_join(step + ".png")))

## True when both files were written; a failure is printed, not swallowed.
func _write_report(report: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var ok := true
	for entry in [["report.json", JSON.stringify(report, "\t")], ["report.md", report_markdown(report)]]:
		var f := FileAccess.open(OUT_DIR.path_join(entry[0]), FileAccess.WRITE)
		if f == null:
			print("[Playtest] cannot write %s: %s" % [entry[0], error_string(FileAccess.get_open_error())])
			ok = false
			continue
		f.store_string(entry[1])
	return ok

# ---------------------------------------------------------------------------
# Steps. Each returns [ok: bool, detail: String].
# ---------------------------------------------------------------------------

func _key(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)

## Stand the player on the ground of `chunk` at `local`'s x/z, SPAWN_OFFSET_M above the surface that is
## actually built there (the voxel surface, else the generator's), and skip the frame-time check for the
## frames the new window's builds will cost.
func _teleport_to(chunk: Vector2i, local: Vector3) -> Dictionary:
	var m := WorldPos.CHUNK_METERS
	var xz := Vector2(float(chunk.x) * m + local.x, float(chunk.y) * m + local.z)
	var ground: float = _root._voxel.get_voxel_height_at(xz) if _root._chunk_manager.is_chunk_built(chunk) else _root._terrain.get_height_at(xz)
	var spot := WorldPos.normalized({ "chunk": chunk, "local": Vector3(local.x, ground + SPAWN_OFFSET_M, local.z) })
	GameBus.player_teleport.emit(spot)
	_skip_until_ms = Time.get_ticks_msec() + TELEPORT_SETTLE_MS
	return spot

func _player_pos() -> Vector3:
	return _root._player.get_position()

## Hold W for a few seconds: the body must move, and the feet must swap the lead at least
## WALK_FOOT_MIN_SWITCHES times over the last WALK_FOOT_SECS (a clip stuck on its last key keeps one foot ahead).
func _step_walk() -> Array:
	var start := _player_pos()
	var rig := _player_rig()
	var skeleton: Skeleton3D = null
	if rig != null:
		skeleton = _first_skeleton(rig)
	var foot_l := skeleton.find_bone("Foot_L") if skeleton != null else -1
	var foot_r := skeleton.find_bone("Foot_R") if skeleton != null else -1
	var samples: Array = []  # [time, left, right] foot positions in world space; only the last WALK_FOOT_SECS are kept
	_key(KEY_W, true)
	var t0 := Time.get_ticks_msec()
	# A slow runner (the world still loading under the body) walks late, so keep walking until the body has
	# covered WALK_MIN_M, up to WALK_MAX_SECS, then judge the feet over the final WALK_FOOT_SECS.
	while true:
		await get_tree().process_frame
		var elapsed := float(Time.get_ticks_msec() - t0) / 1000.0
		var here := _player_pos()
		var travelled := Vector2(here.x - start.x, here.z - start.z).length()
		if foot_l >= 0 and foot_r >= 0:
			samples.append([elapsed, skeleton.to_global(skeleton.get_bone_global_pose(foot_l).origin),
				skeleton.to_global(skeleton.get_bone_global_pose(foot_r).origin)])
			while elapsed - float(samples[0][0]) > WALK_FOOT_SECS:
				samples.pop_front()
		if (elapsed >= WALK_SECS and travelled >= WALK_MIN_M) or elapsed >= WALK_MAX_SECS:
			break
	_key(KEY_W, false)
	var delta := Vector2(_player_pos().x - start.x, _player_pos().z - start.z)
	var moved := delta.length()
	var note := "moved %.1f m" % moved
	var ok := moved > 1.0
	if samples.size() >= 10 and moved > 1.0:
		var dir := delta.normalized()
		var left_ahead := 0
		var switches := 0
		var leader := 0  # +1 left ahead, -1 right ahead, 0 not yet known
		for pair in samples:
			var l: Vector3 = pair[1]
			var r: Vector3 = pair[2]
			var lead := Vector2(l.x - r.x, l.z - r.z).dot(dir)
			if lead > 0.0:
				left_ahead += 1
			if absf(lead) < WALK_FOOT_DEADBAND_M:
				continue   # feet level: passing, not a change of leader
			var side := 1 if lead > 0.0 else -1
			if leader != 0 and side != leader:
				switches += 1
			leader = side
		var frac := float(left_ahead) / float(samples.size())
		note += ", left foot ahead %.0f%% of %d frames, %d lead switches" % [frac * 100.0, samples.size(), switches]
		ok = ok and switches >= WALK_FOOT_MIN_SWITCHES
	else:
		note += ", no rig feet sampled"
	return [ok, note]

func _player_rig() -> Node:
	var inst: Dictionary = _root._character._instances.get(_root._character.get_player_character(), {})
	var rig: Variant = inst.get("rig_node", null)
	return rig if rig is Node and is_instance_valid(rig) else null

func _first_skeleton(n: Node) -> Skeleton3D:
	var found := n.find_children("*", "Skeleton3D", true, false)
	return found[0] as Skeleton3D if not found.is_empty() else null

## Hop 20 chunks east, waiting for the chunk under the body at every hop.
func _step_stream() -> Array:
	var home: Dictionary = _root._player.get_world_pos()
	for i in range(1, STREAM_CHUNKS + 1):
		var spot := _teleport_to((home["chunk"] as Vector2i) + Vector2i(i, 0), home["local"])
		var built: bool = await _until(func(): return _root._chunk_manager.is_chunk_built(spot["chunk"]), STREAM_TIMEOUT_SECS)
		if not built:
			return [false, "chunk %d east never built" % i]
		await _until(func(): return false, 0.1)
	_recording = false   # the timed loop blocks the main thread on purpose: it is not a frame to judge
	_stream_rate = _measure_build_rate(home["chunk"])
	_recording = true
	_skip_frames = WARMUP_FRAMES
	return [true, "%d chunks streamed; %s builder %.1f chunks/s, heightmap %.0f%% of the build" % [STREAM_CHUNKS, NativeBuilder.mode(), _stream_rate, 100.0 * float(_build_breakdown.get("heightmap_share", 0.0))]]

## Phase 187 — the flight verdict from the samples taken after the warm-up: `under` and `ring` are
## per-sample shares (0..1) of the chunk under the body and of its 3×3 ring that were built. Pure.
static func flight_verdict(under: Array, ring: Array, min_cover: float = FLIGHT_MIN_COVER) -> Dictionary:
	var n := under.size()
	var u := 0.0
	var r := 0.0
	var worst := 1.0
	for i in n:
		u += float(under[i])
		r += float(ring[i]) if i < ring.size() else 0.0
		worst = minf(worst, float(ring[i]) if i < ring.size() else 0.0)
	var cover := u / float(n) if n > 0 else 0.0
	return { "samples": n, "under_cover": cover, "ring_cover": r / float(n) if n > 0 else 0.0,
		"worst_ring": worst if n > 0 else 0.0, "ok": n > 0 and cover >= min_cover }

## Phase 189 — main-thread ms the chunk manager spent, from a `TickProbe.take_times()` table (µs): its
## frame pump (`chunks`) and every phase nested in it (`chunk_*`: attach arrays, mesh, collision). Pure.
static func chunk_main_ms(times: Dictionary) -> float:
	var us := 0
	for phase in times:
		if str(phase) == "chunks" or str(phase).begins_with("chunk_"):
			us += int(times[phase])
	return float(us) / 1000.0

## Phase 189 — ms of the phases the near ring targets (`NEAR_RING_PHASES`), from the same table. Pure.
static func near_ring_ms(times: Dictionary) -> float:
	var us := 0
	for phase in NEAR_RING_PHASES:
		us += int(times.get(phase, 0))
	return float(us) / 1000.0

## The same phases one by one, in ms per attached chunk (the flight report's breakdown). Pure.
static func chunk_phases_ms(times: Dictionary, attached: int) -> Dictionary:
	var out := {}
	for phase in times:
		if attached > 0 and (str(phase) == "chunks" or str(phase).begins_with("chunk_")):
			out[str(phase)] = snappedf(float(times[phase]) / 1000.0 / float(attached), 0.01)
	return out

## Phase 187 — carry the body east at FLIGHT_SPEED_MPS (a ground-hugging teleport every frame: the
## streaming load of admin flight without its input or physics) and sample the ground under it.
## Then put it back where it started, built, for the steps that follow.
## Phase 189 — the body flies (as `/fly` sets it), and after the warm-up each flight records the chunk
## manager's main-thread ms per attached chunk (TickProbe phases). The step flies twice over the same
## ground: the gated flight, then a record flight with the near ring off (`set_near_ring_enabled(false)`,
## the Phase 187 behaviour). The record flies second, over warm ground, so the comparison does not favour
## the near ring. `tools/check_playtest_budget.py` gates the medians: `near_ms_per_attach` (collision and
## contents) at most FLIGHT_MAX_SHARE of `record_near_ms_per_attach`; the whole pump is report-only.
func _step_flight() -> Array:
	var cm = _root._chunk_manager
	var home: Dictionary = _root._player.get_world_pos()
	var home_chunk: Vector2i = home["chunk"]
	var home_local: Vector3 = home["local"]
	var was_flying: bool = _root._player.flying
	var speed: float = _root._player.admin_speed_factor
	GameBus.admin_moves_synced.emit(speed, true)   # what `/fly` sends
	var gated := await _fly_east(home_chunk, home_local)
	var settled := await _return_home(home_chunk, home_local)
	if not settled:
		# a record flight launched from the wrong place would be meaningless: restore and fail the step
		GameBus.admin_moves_synced.emit(speed, was_flying)
		return [false, "the start chunk never rebuilt after the gated flight"]
	cm.set_near_ring_enabled(false)
	var record := await _fly_east(home_chunk, home_local)
	cm.set_near_ring_enabled(true)
	GameBus.admin_moves_synced.emit(speed, was_flying)
	settled = await _return_home(home_chunk, home_local) and settled
	_flight = flight_verdict(gated["under"], gated["ring"])
	_flight["speed_mps"] = FLIGHT_SPEED_MPS
	_flight["attached"] = gated["attached"]
	_flight["main_ms_per_attach"] = gated["ms_per_attach"]
	_flight["record_attached"] = record["attached"]
	_flight["record_ms_per_attach"] = record["ms_per_attach"]
	_flight["near_ms_per_attach"] = gated["near_ms_per_attach"]
	_flight["record_near_ms_per_attach"] = record["near_ms_per_attach"]
	_flight["phases_ms_per_attach"] = gated["phases"]
	_flight["record_phases_ms_per_attach"] = record["phases"]
	var note := "%.0f m/s for %.0f s: ground under the body built in %.0f%% of %d samples, 3×3 ring %.0f%% (worst %.0f%%); main thread %.1f ms per attached chunk (%d chunks), %.1f ms with the near ring off (%d chunks); collision and contents %.1f ms, %.1f ms with it off" % [
		FLIGHT_SPEED_MPS, FLIGHT_SECS, 100.0 * float(_flight["under_cover"]), int(_flight["samples"]),
		100.0 * float(_flight["ring_cover"]), 100.0 * float(_flight["worst_ring"]),
		float(gated["ms_per_attach"]), int(gated["attached"]), float(record["ms_per_attach"]), int(record["attached"]),
		float(gated["near_ms_per_attach"]), float(record["near_ms_per_attach"])]
	if not settled:
		return [false, note + "; the start chunk never rebuilt"]
	# The gate is the native builder's: the GDScript fallback (CI's `--no-native` run) builds about 7× slower
	# and cannot hold 90 m/s, so that run reports the coverage without failing on it.
	_flight["gated"] = NativeBuilder.mode() == NativeBuilder.MODE_NATIVE
	if not bool(_flight["gated"]):
		return [true, note + " (report only: %s builder)" % NativeBuilder.mode()]
	return [bool(_flight["ok"]), note]

## One flight east from home: { under, ring } per-sample shares, and the chunks attached after the warm-up
## with the chunk manager's main-thread ms per attached chunk.
func _fly_east(home_chunk: Vector2i, home_local: Vector3) -> Dictionary:
	var cm = _root._chunk_manager
	var m := WorldPos.CHUNK_METERS
	var x0: float = float(home_chunk.x) * m + home_local.x
	var probe_was := TickProbe.enabled
	var attached0: int = cm.builds_attached
	var probing := false
	var under: Array = []
	var ring: Array = []
	var t0 := Time.get_ticks_msec()
	var next_sample := FLIGHT_WARMUP_SECS
	while true:
		await get_tree().process_frame
		var secs := float(Time.get_ticks_msec() - t0) / 1000.0
		if secs >= FLIGHT_SECS:
			break
		var x := x0 + FLIGHT_SPEED_MPS * secs
		var cx := floori(x / m)
		var ch := Vector2i(cx, home_chunk.y)
		var xz := Vector2(x, float(home_chunk.y) * m + home_local.z)
		var built: bool = cm.is_chunk_built(ch)
		var ground: float = _root._voxel.get_voxel_height_at(xz) if built else _root._terrain.get_height_at(xz)
		GameBus.player_teleport.emit(WorldPos.normalized({ "chunk": ch,
			"local": Vector3(x - float(cx) * m, ground + SPAWN_OFFSET_M, home_local.z) }))
		if secs >= FLIGHT_WARMUP_SECS and not probing:
			probing = true
			TickProbe.enabled = true
			TickProbe.take_times()
			attached0 = cm.builds_attached
		if secs >= next_sample:
			next_sample += FLIGHT_SAMPLE_SECS
			var n := 0
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					if cm.is_chunk_built(ch + Vector2i(dx, dz)):
						n += 1
			under.append(1.0 if built else 0.0)
			ring.append(float(n) / 9.0)
	var times := TickProbe.take_times()
	var main_ms := chunk_main_ms(times)
	TickProbe.enabled = probe_was
	var attached: int = cm.builds_attached - attached0
	return { "under": under, "ring": ring, "attached": attached,
		"ms_per_attach": main_ms / float(attached) if attached > 0 else 0.0,
		"near_ms_per_attach": near_ring_ms(times) / float(attached) if attached > 0 else 0.0,
		"phases": chunk_phases_ms(times, attached) }

## Put the body back where a flight started and wait for its chunk to be built.
## The world's own creatures can down the body while it waits on a slow build (CI's GDScript run saw
## HP 0 here), and a downed body respawns at its respawn point, out of reach of the home chunk. So a
## downed body is let respawn, healed and carried home again, under one deadline.
func _return_home(home_chunk: Vector2i, home_local: Vector3) -> bool:
	var cm = _root._chunk_manager
	var player = _root._player
	var deadline_ms := Time.get_ticks_msec() + int((PlayerSlice.RESPAWN_DELAY + STEP_TIMEOUT_SECS) * 1000.0)
	while true:
		var left := float(deadline_ms - Time.get_ticks_msec()) / 1000.0
		if left <= 0.0:
			return false
		if not player.is_alive():
			await _until(func(): return player.is_alive(), left)
			continue
		GameBus.admin_healed.emit()
		var back := _teleport_to(home_chunk, home_local)
		_clear_creatures_near_body()
		await _until(func(): return cm.is_chunk_built(back["chunk"]) or not player.is_alive(), left)
		if player.is_alive():
			return cm.is_chunk_built(back["chunk"])
	return false

## Phase 169 — the chunk build rate of the builder in use (`NativeBuilder.mode()`), chunks per second of
## the pure worker half (map, seam strips, resolve, mesh) run synchronously on `RATE_CHUNKS` chunks past
## the streamed ones. It times the builder itself, so the pump's scheduling (Phase 142) is not in the
## number and a native run is comparable with a `--no-native` run on the same commit.
func _measure_build_rate(home_chunk: Vector2i) -> float:
	TerrainSlice.warm_polar_caches()
	var seed_v: int = int(_root._terrain.get_world_seed())
	var noise: FastNoiseLite = _root._terrain.detail_noise_copy()
	var parts := { "heightmap": 0, "seam": 0, "runs": 0, "arrays": 0 }
	var started := Time.get_ticks_usec()
	for i in range(RATE_CHUNKS):
		var c := home_chunk + Vector2i(STREAM_CHUNKS + 4 + i % 6, 4 + i / 6)
		var t0 := Time.get_ticks_usec()
		var hm: Array = TerrainSlice.heightmap_for(c, seed_v, noise)
		var t1 := Time.get_ticks_usec()
		var gathered: Dictionary = _root._voxel.gather_build_input_deferred(c)
		VoxelSlice.fill_seam_strips(c, gathered, seed_v, noise)
		var t2 := Time.get_ticks_usec()
		var runs: Dictionary = VoxelSlice.build_runs(c, hm, gathered)
		var t3 := Time.get_ticks_usec()
		VoxelSlice.build_chunk_arrays(c, hm, runs, true)
		var t4 := Time.get_ticks_usec()
		parts["heightmap"] += t1 - t0
		parts["seam"] += t2 - t1
		parts["runs"] += t3 - t2
		parts["arrays"] += t4 - t3
	var secs := float(Time.get_ticks_usec() - started) / 1.0e6
	_build_breakdown = build_breakdown(parts, RATE_CHUNKS, _root._chunk_manager.stream_radius())
	return float(RATE_CHUNKS) / maxf(secs, 0.000001)

## Phase 170 — where one chunk build goes. `parts_usec` is the summed microseconds of each stage over
## `chunks` builds; the record carries milliseconds per chunk, the heightmap's share of the total, the
## streamed window radius of the session (`DEFAULT_VIEW_DISTANCE + prefetch`, the largest default; context
## only, the timed chunks are a fixed block east of the spawn, so the share is that of spawn-latitude land) and the decision: a compute-shader heightmap is worth building only when
## `heightmap_for` is over `SHADER_SHARE_LIMIT` of the build.
static func build_breakdown(parts_usec: Dictionary, chunks: int, window_radius: int) -> Dictionary:
	var total := 0.0
	for k in parts_usec:
		total += float(parts_usec[k])
	var n := float(maxi(chunks, 1))
	var rec := { "chunks": chunks, "window_radius": window_radius }
	for k in parts_usec:
		rec["%s_ms" % k] = float(parts_usec[k]) / 1000.0 / n
	rec["total_ms"] = total / 1000.0 / n
	var share: float = float(parts_usec.get("heightmap", 0)) / total if total > 0.0 else 0.0
	rec["heightmap_share"] = share
	rec["decision"] = "compute_shader" if share > SHADER_SHARE_LIMIT else "no_shader"
	return rec

## Mine the ground block under the body through the player's own intent.
func _step_mine() -> Array:
	var p := _player_pos()
	var y: float = _root._terrain.get_height_at(Vector2(p.x, p.z))
	var before := _mined.size()
	GameBus.block_mine_requested.emit(Vector3(p.x, y - 0.1, p.z), Vector3.UP, "", {})
	var ok: bool = await _until(func(): return _mined.size() > before, STEP_TIMEOUT_SECS)
	return [ok, "mined %s" % str(_mined.back()) if ok else "no block_mined"]

func _standing_trees() -> Array:
	var standing: Array = []
	for tid in _root._tree._trees:
		if str(_root._tree._trees[tid]["state"]) == "standing":
			standing.append(str(tid))
	standing.sort()
	return standing

## The standing tree closest to the body (ids are sorted, so a tie is stable).
func _nearest_tree(ids: Array) -> String:
	var from: Vector3 = _player_pos() - _root._tree.scene_offset()   # trees live in the slice frame
	var best := str(ids[0])
	var best_d := INF
	for tid in ids:
		var pos: Vector3 = _root._tree._trees[tid]["position"]
		var d := pos.distance_squared_to(from)
		if d < best_d:
			best_d = d
			best = str(tid)
	return best

func _grows_trees(c: Vector2i) -> bool:
	var canon := TerrainSlice.wrap_chunk(c)
	return _root._tree.tree_count_for(canon, str(_root._terrain.get_biome_at_chunk(canon))) > 0

## Chunks around `origin`, nearest ring first, whose biome grows trees (budget above zero). The spawn
## is not pinned, so the body can stand in a desert or ice sheet wider than the rings: then rays cast
## outward, nearest sample first, and the first forest chunk found seeds a ring scan around it.
func _forest_chunks_near(origin: Vector2i) -> Array:
	var found := _forest_rings(origin)
	if not found.is_empty():
		return found
	for d in range(GATHER_SEARCH_RADIUS + GATHER_FAR_STEP, GATHER_FAR_RADIUS + 1, GATHER_FAR_STEP):
		for b in range(GATHER_FAR_BEARINGS):
			var a := TAU * float(b) / float(GATHER_FAR_BEARINGS)
			var c := origin + Vector2i(roundi(cos(a) * d), roundi(sin(a) * d))
			if _grows_trees(c):
				found = [c]
				found.append_array(_forest_rings(c))
				return found.slice(0, GATHER_SEARCH_CHUNKS)
	return found

func _forest_rings(origin: Vector2i) -> Array:
	var found: Array = []
	for r in range(1, GATHER_SEARCH_RADIUS + 1):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := origin + Vector2i(dx, dy)
				if _grows_trees(c):
					found.append(c)
		if found.size() >= GATHER_SEARCH_CHUNKS:
			break
	return found

## Gather: fell the first tree of the loaded window through the player's own intent, with an axe in the pack.
func _step_gather() -> Array:
	var standing: Array = _standing_trees()
	# The stream step left the body wherever the 20th hop landed, and a first boot spawns at a
	# time-dependent spot, so that may be desert, ice or sea. Look for a forest chunk on paper (the
	# biome and the tree budget are pure functions of the chunk), ring by ring, and hop straight to it.
	var here: Dictionary = _root._player.get_world_pos()
	var tried := 0
	var forest: Array = _forest_chunks_near(here["chunk"] as Vector2i)
	for chunk in forest:
		if not standing.is_empty() or tried >= GATHER_SEARCH_CHUNKS or Time.get_ticks_msec() >= _step_deadline_ms:
			break
		tried += 1
		var spot := _teleport_to(chunk, here["local"])
		await _until(func(): return _root._chunk_manager.is_chunk_built(spot["chunk"]), STEP_TIMEOUT_SECS)
		spot = _teleport_to(chunk, here["local"])   # the body dropped while the chunk built: stand it on the built ground
		await _until(func(): return false, 0.5)
		standing = _standing_trees()
	if standing.is_empty():
		return [false, "no standing tree in the loaded window (%d forest chunks found near %s, %d visited)" % [forest.size(), str(here["chunk"]), tried]]
	if not _root._inventory.add_item("CarpenterAxe", 1):
		return [false, "axe does not fit the pack (weight %.1f of %.1f)" % [_root._inventory.get_current_weight(), _root._inventory.get_max_weight()]]
	var before := _chopped.size()
	var target := _nearest_tree(standing)
	# The pool grows past its first block once enough chunks have streamed in; a grow must not wipe the
	# trees already drawn (a zero transform draws nothing). Only a real renderer keeps the transforms.
	var pool = _root._tree._pool
	if pool != null and DisplayServer.get_name() != "headless":
		var xf: Transform3D = pool._multimesh.get_instance_transform(int(_root._tree._trees[target]["mi"]))
		if is_zero_approx(xf.basis.determinant()):
			return [false, "standing tree %s has no drawn mesh (pool of %d)" % [target, pool.instance_count()]]
	GameBus.tree_chop_requested.emit(target, "")
	var ok: bool = await _until(func(): return _chopped.size() > before, STEP_TIMEOUT_SECS)
	return [ok, "felled %s" % str(_chopped.back()) if ok else "chop %s gave nothing" % target]

## Research `tech_id` through the player's own intent (research points and materials granted first, the
## way a session would earn them). "" on success.
func _unlock(tech_id: String) -> String:
	var t = _root._technology
	var pid: String = t.local_player_id()
	if t.is_unlocked(tech_id, pid):
		return ""
	t._set_points(pid, t.max_points())   # setup: the points a session would have earned
	for entry in t.get_tech_data(tech_id).get("researchMaterials", []):
		_root._inventory.add_item(str(entry["item"]), int(entry["quantity"]))
	var before := _researched.size()
	GameBus.research_requested.emit(tech_id)
	if _researched.size() == before or not bool(_researched.back()["success"]):
		return str(_researched.back()["reason"]) if _researched.size() > before else "no research_resolved"
	# The research clock runs on wall time: wait for the unlock it ends in.
	var unlocked: bool = await _until(func(): return t.is_unlocked(tech_id, pid), STEP_TIMEOUT_SECS)
	return "" if unlocked else "research did not finish"

## Tap `keycode` (press and release).
func _tap(keycode: Key) -> void:
	_key(keycode, true)
	_key(keycode, false)

## Place `station_type` with the player's own keys: B cycles the selection, V places it at the feet.
## Returns the number of stations placed (0 when refused).
func _place_with_keys(station_type: String) -> int:
	var station = _root._station
	for _i in range(32):
		if station.get_place_station_type() == station_type:
			break
		_tap(KEY_B)
		await get_tree().process_frame
	if station.get_place_station_type() != station_type:
		return 0
	var before := _placed.size()
	_tap(KEY_V)
	await _until(func(): return _placed.size() > before, 2.0)
	return _placed.size() - before

## `_place_with_keys`, walking forward 1.5 s and aiming again after each refusal, up to `tries` attempts.
## Each retry turns the view a quarter first: a body stuck against a slope or a trunk walks nowhere, and its
## next spot is still inside the last station's spacing. `_place_refusal` says why the last try was refused.
func _place_walking(station_type: String, tries: int) -> int:
	_place_refusal = ""
	for attempt in tries:
		var placed := await _place_with_keys(station_type)
		if placed > 0:
			return placed
		var station = _root._station
		var why: String = station.placement_blocker(station_type, station.snap_to_grid(_root._player._station_target()))
		_place_refusal = "%s at %s" % [why if why != "" else "no blocker (aim or item)", str(_player_pos().snapped(Vector3.ONE * 0.1))]
		var pivot: Node3D = _root._player._pivot
		pivot.global_rotation.y += PI * 0.5
		_key(KEY_W, true)
		await _until(func(): return false, 1.5)
		_key(KEY_W, false)
	return 0

## Craft planks at a carpentry bench set down at the feet.
func _step_craft() -> Array:
	var tech: Variant = await _unlock("TechBasicCarpentry")
	if tech != "":
		return [false, "research: %s" % tech]
	_root._inventory.add_item("Thornwood", 2)
	_root._crafting.set_skill("Carpentry", "novice")
	# The bench counts only within reach of the body. The key places it at the aimed block, which can lie
	# beyond the station radius, so when it is not near, walk the body (a teleport) to where it went down.
	if await _place_with_keys("carpentry bench") == 0:
		return [false, "bench placement refused"]
	await _until(func(): return false, 0.5)
	var radius: float = _root._crafting.STATION_RADIUS
	var near: bool = _root._station.station_near_player("carpentry bench", radius)
	if not near:
		var m := WorldPos.CHUNK_METERS
		var at: Vector3 = _root._station.get_station(str(_placed.back()[0]))["position"]
		var chunk := Vector2i(floori(at.x / m), floori(at.z / m))
		# Stand just above the bench itself, not the generated ground under it: the aimed block can be a canopy
		# or a ledge well above the ground, and a body dropped on the ground would still be out of reach.
		var spot := WorldPos.normalized({ "chunk": chunk, "local": Vector3(at.x - float(chunk.x) * m, at.y + 1.5, at.z - float(chunk.y) * m) })
		GameBus.player_teleport.emit(spot)
		_skip_until_ms = Time.get_ticks_msec() + TELEPORT_SETTLE_MS
		await _until(func(): return false, 1.0)   # the body settles
		near = _root._station.station_near_player("carpentry bench", radius)
	if not near:
		return [false, "the bench is out of reach of the body"]
	var before := _crafted.size()
	var planks: int = _root._inventory.get_item_count("ThornwoodPlank")
	GameBus.craft_requested.emit("RecipeThornwoodPlank")
	var ok: bool = await _until(func(): return _crafted.size() > before, STEP_TIMEOUT_SECS)
	if not ok:
		return [false, "no craft_resolved"]
	var got: int = _root._inventory.get_item_count("ThornwoodPlank") - planks
	var detail := "crafted %d planks (%s)" % [got, str(_crafted.back()["reason"])]
	# Phase 153: a held weapon is drawn from its model. No recipe yields a hand-held item, so the bot
	# puts a weapon in hand (screenshotted with this step) and checks the hand socket's node.
	var character: Node = _root._character
	var iid: String = character.get_player_character()
	var hand_ok: bool = iid != "" and character.apply_equipment(iid, "MainHand", "VeilsteelLongsword")
	var node: Node = character.get_part_node(iid, "MainHand") if hand_ok else null
	hand_ok = node != null and str(node.get_meta("item_model", "")) == "VeilsteelLongsword"
	return [bool(_crafted.back()["success"]) and got == 3 and hand_ok, "%s; hand model %s" % [detail, "ok" if hand_ok else "MISSING"]]

## Place a station with the player's own keys, a few metres from the bench so the two do not overlap.
func _step_place() -> Array:
	var placed := 0
	for attempt in range(3):
		_key(KEY_W, true)
		await _until(func(): return false, 1.0)
		_key(KEY_W, false)
		placed = await _place_with_keys("forge")
		if placed > 0:
			break
	return [placed > 0, "placed %s" % str(_placed.back()[0]) if placed > 0 else "forge placement refused"]

## Fight: a creature set down within reach loses HP to the player's melee round and is drawn as a model.
func _step_fight() -> Array:
	var cid := ""
	var best := -1.0
	var keys: Array = GameData.CREATURES.keys()
	keys.sort()
	for k in keys:   # the sturdiest creature: it survives the rounds, so its tracked HP stays readable
		var hp := float((GameData.CREATURES[k] as Resource).get("baseHp"))
		if hp > best:
			best = hp
			cid = str(k)
	if cid == "":
		return [false, "no creature in GameData"]
	# Placed in the creature slice's own frame, from the camera that draws it, so the model range check
	# and the screenshot see the same distance whatever the scene origin or float32 rounding did to the body.
	var p := _player_pos()
	if absf(_ground_gap()) > FIGHT_MAX_GROUND_GAP_M:
		# The body is not on the surface (it fell while ground streamed in): stand it back on it.
		var here: Dictionary = _root._player.get_world_pos()
		_teleport_to(here["chunk"], here["local"])
		await _until(func(): return absf(_ground_gap()) <= FIGHT_MAX_GROUND_GAP_M, STEP_TIMEOUT_SECS)
		await _until(func(): return false, 0.3)
		p = _player_pos()
	var gap := _ground_gap()
	if absf(gap) > FIGHT_MAX_GROUND_GAP_M:
		return [false, "the player is %.1f m from the terrain surface (limit %.1f)" % [gap, FIGHT_MAX_GROUND_GAP_M]]
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		p = cam.global_position - _root._creature.scene_offset()
	var iid: String = _root._creature._spawn(cid, Vector2i(9000, 9000), 0)
	if iid == "":
		return [false, "spawn refused"]
	var y: float = _root._terrain.get_height_at(Vector2(p.x + FIGHT_RANGE_M, p.z))
	_root._creature.set_instance_position(iid, Vector3(p.x + FIGHT_RANGE_M, y, p.z))
	var rounds := 0
	var ok := false
	while rounds < 20 and not ok:
		GameBus.combat_round_requested.emit("player", iid)
		rounds += 1
		await _until(func(): return false, 0.2)
		var left: float = _root._battle.get_hp(iid)
		ok = left >= 0.0 and left < float((GameData.CREATURES[cid] as Resource).get("baseHp"))
	# Phase 143: the screenshot that follows shows the target as a rigged model, not a box.
	var modelled: bool = ok and await _until(func(): return _root._creature.has_model(iid), STEP_TIMEOUT_SECS)
	var why := "drawn as a model" if modelled else "no model node (%s)" % _model_diag(iid)
	var left_hp: float = _root._battle.get_hp(iid)
	_root._creature.despawn_instance(iid)   # the bot's target must not outlive the step
	# Phase 161: the kill leaves a body; a knife in hand takes its pelt and meat into the bag.
	var harvested := await _harvest_after_kill(cid)
	return [ok and modelled and harvested[0], "%s at %.0f hp after %d rounds, %s, player %.1f m from the surface; %s" % [cid, left_hp, rounds, why, gap, harvested[1]]]

## Kill `creature_key` beside the player through the real death path, harvest the body with a knife and
## check the bag holds what came off. Chances are pinned to 1 so the check does not depend on a roll.
func _harvest_after_kill(creature_key: String) -> Array:
	var slice: Node = _root._carcass
	# #487: the host refuses a harvest by a downed body ("unavailable"), and the fight can down it. Let a
	# downed body respawn first (the kill below lands where it stands), then heal it through the admin door.
	var player = _root._player
	if not player.is_alive():
		await _until(func(): return player.is_alive(), PlayerSlice.RESPAWN_DELAY + STEP_TIMEOUT_SECS)
		_skip_until_ms = Time.get_ticks_msec() + TELEPORT_SETTLE_MS
		await _hold_still(3.0)
	GameBus.admin_healed.emit()
	var before: int = slice.count()
	GameBus.creature_died.emit(creature_key, _root._player.get_position(), "player", Vector3.ZERO)
	if slice.count() != before + 1:
		return [false, "a kill left no carcass"]
	var cid: String = slice.ids().back()
	for e: Dictionary in slice._carcasses[cid]["entries"]:
		e["chance"] = 1.0
	_root._inventory.add_item("SkinningKnife", 1)
	_clear_creatures_near_body()
	var held_before := {}
	for e: Dictionary in slice.workable_entries(cid, "knife"):
		held_before[str(e["item"])] = _root._inventory.get_item_count(str(e["item"]))
	# Wait for the host's verdict, not a fixed time: the action counts game-tick seconds, which a slow
	# rendered frame stretches past the wall clock.
	var verdict := []
	var on_resolved := func(_pid: String, _cid: String, reason: String, _items: Array) -> void: verdict.append(reason)
	# A hit cancels the work ("damaged"); the world's own creatures can land one mid-harvest, so a
	# cancelled try is retried and the attackers are named in the note.
	var attackers := []
	var on_damaged := func(_dmg: float, attacker_id: String, _target_id: String) -> void: attackers.append(attacker_id)
	GameBus.harvest_resolved.connect(on_resolved)
	GameBus.player_damaged.connect(on_damaged)
	var secs: float = float(GameData.HARVESTS["HarvestRules"].get("harvestSeconds"))
	var got: Array = []
	# One deadline across every try (#444): HARVEST_TRIES full waits would outrun the step's own timeout.
	var deadline_ms := Time.get_ticks_msec() + int(maxf(secs * 6.0, STEP_TIMEOUT_SECS) * 1000.0)
	for _try in HARVEST_TRIES:
		var left := float(deadline_ms - Time.get_ticks_msec()) / 1000.0
		if left <= 0.0:
			break
		# #472 root cause of "moved": the host cancels work when the body drifts 0.6 m from where it started, and the
		# bot's body can still be settling (falling after the fight step's teleport, or a rebase) at that instant.
		# Start only once it has held still, so the origin the host records is the resting position.
		await _hold_still(minf(left, 3.0))
		# The body was laid where the player stood at the kill; a fall or rebase since then (CI saw
		# "out_of_range" at 0.0 m from the surface) must not make the range check the thing under test.
		if slice.has_carcass(cid):
			slice._carcasses[cid]["position"] = _root._player.get_position()
		var seen := verdict.size()
		GameBus.harvest_intent.emit(cid, "")
		await _until(func(): return verdict.size() > seen, left)
		for item in held_before:
			if _root._inventory.get_item_count(str(item)) > int(held_before[item]):
				got.append(item)
		if not got.is_empty() or verdict.size() <= seen or not ["damaged", "moved", "out_of_range"].has(str(verdict.back())):
			break
	GameBus.harvest_resolved.disconnect(on_resolved)
	GameBus.player_damaged.disconnect(on_damaged)
	var why := str(verdict) if not verdict.is_empty() else "no verdict"
	if not attackers.is_empty():
		why += ", hit by %s" % str(attackers)
	why += ", player hp %.0f%s" % [player.get_hp(), "" if player.is_alive() else " (down)"]
	return [not got.is_empty(), "harvested %s" % str(got) if not got.is_empty() else "the bag gained nothing from the body (%s)" % why]

## Wait (bounded by `max_secs`) until the player's position has moved less than 0.1 m over 0.3 s.
func _hold_still(max_secs: float) -> void:
	var deadline := Time.get_ticks_msec() + int(max_secs * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var a := _player_pos()
		await _until(func(): return false, 0.3)
		if _player_pos().distance_to(a) < 0.1:
			return

## The world's own creatures (a wolf pack) can reach the body and cancel every harvest try with a hit; the
## step tests the harvest, not the world's spawns, so the ones near the body are removed first.
func _clear_creatures_near_body() -> void:
	var here := _player_pos()
	for iid in _root._creature._instances.keys():
		var pos: Vector3 = (_root._creature._instances[iid] as Dictionary)["position"]
		if Vector2(pos.x - here.x, pos.z - here.z).length() <= CREATURE_CLEAR_M:
			_root._creature.despawn_instance(str(iid))

## Player height minus the built surface under the body (0 on the surface).
func _ground_gap() -> float:
	var here: Dictionary = _root._player.get_world_pos()
	var chunk: Vector2i = here["chunk"]
	var local: Vector3 = here["local"]
	var m := WorldPos.CHUNK_METERS
	var xz := Vector2(float(chunk.x) * m + local.x, float(chunk.y) * m + local.z)
	return local.y - float(_root._voxel.get_voxel_height_at(xz))

## Why a creature has no model: its record, the camera and the distance between them.
func _model_diag(iid: String) -> String:
	var inst: Variant = _root._creature._instances.get(iid, null)
	var cam := get_viewport().get_camera_3d()
	var parts: Array = ["camera %s" % ("yes" if cam != null else "none")]
	parts.append("record %s" % ("yes" if inst != null else "none"))
	var vis: Node3D = _root._creature.visuals()
	if vis != null:
		parts.append("models %d, warned %s" % [vis.models.size(), str(vis.warned_types.keys())])
		if cam != null and inst != null:
			parts.append("%.1f m from camera, state %s" % [(cam.global_position - vis.position).distance_to(inst["position"]), str(inst["state"])])
			parts.append("camera %s, models node at %s, creature %s, player %s" % [str(cam.global_position), str(vis.position), str(inst["position"]), str(_player_pos())])
	return ", ".join(parts)

## Travel: two waystones set down with the player's own keys, attuned, then the intent; the body must land at the second.
func _step_travel() -> Array:
	var stone: String = str(_root._waystones.station_type())
	_key(KEY_W, true)   # clear of the bench and the forge the earlier steps set down
	await _until(func(): return false, 1.5)
	_key(KEY_W, false)
	var before := _placed.size()
	var item: String = _root._station.placement_item(stone)
	if item != "":
		_root._inventory.add_item(item, 2)   # each placement consumes one
	# #471 root cause of "first waystone refused": the key places at the aimed block, which can be sky, unbuilt
	# ground or inside another station's clearance. Only the second stone retried; both walk on and aim again.
	if await _place_walking(stone, 3) == 0:
		return [false, "first waystone refused (%s)" % _place_refusal]
	var a: String = str(_placed[before][0])
	_key(KEY_W, true)
	await _until(func(): return false, 1.5)
	_key(KEY_W, false)
	var second := await _place_walking(stone, 4)
	if second == 0:
		return [false, "second waystone refused (%s)" % _place_refusal]
	var b: String = str(_placed.back()[0])
	# Back beside the first stone, which the travel starts from. Placed, not walked: a timed walk
	# back can stop outside the attune radius and the host refuses the travel as too_far.
	var home: Dictionary = _root._waystones.exact_pos(a)
	_teleport_to(home["chunk"], home["local"])
	var near: bool = await _until(func():
		return WaystoneSlice.distance_m(_root._player.get_world_pos(), home) <= 1.0, STEP_TIMEOUT_SECS)
	if not near:
		return [false, "could not stand beside the first waystone"]
	_root._registry.record_waystones(_root._registry.local_player_id, [a, b])
	_root._registry.get_inventory(_root._registry.local_player_id).add_item(str(_root._waystones.rules()["costItem"]), 20)
	GameBus.waystone_travel_intent.emit(a, b, "")
	_skip_until_ms = Time.get_ticks_msec() + TELEPORT_SETTLE_MS
	var dest: Dictionary = _root._waystones.exact_pos(b)
	# The host teleports the body onto the stone's exact position; ground distance (as the waystone
	# rules measure it) ignores the body settling onto the terrain after the drop.
	var ok: bool = await _until(func():
		return WaystoneSlice.distance_m(_root._player.get_world_pos(), dest) < ARRIVE_TOLERANCE_M, STEP_TIMEOUT_SECS)
	return [ok, "travelled to the second stone" if ok else "body did not reach the second stone"]

## Phase 164 — the horizon: find the nearest coast with open sea across four headings, stand there and
## look out at the shallowest pitch. Each heading's frame is drawn with the camera seeing only the
## distant ring over a key colour (no sky, no fog, no HUD), so the first non-key row of each column is
## the ring's silhouette; it must be level to SKYLINE_FLAT_PX across the frame (the old square ring
## showed its corners as peaks).
func _step_horizon() -> Array:
	if DisplayServer.get_name() == "headless":
		return [true, "headless: no frame to read (skipped)"]
	var player = _root._player
	var start: Vector3 = _player_pos()
	var found: Array = await _find_coast(Vector2(start.x, start.z))
	if found.is_empty():
		return [false, "no coast with open sea within %.0f km" % (COAST_SEARCH_M / 1000.0)]
	var spot_xz: Vector2 = found[0]
	var bearing: float = found[1]
	var m := WorldPos.CHUNK_METERS
	var chunk := Vector2i(floori(spot_xz.x / m), floori(spot_xz.y / m))
	var rings_before: int = _root._distant.rebuilds_completed
	var spot := _teleport_to(chunk, Vector3(spot_xz.x - float(chunk.x) * m, 0.0, spot_xz.y - float(chunk.y) * m))
	if not await _until(func(): return _root._chunk_manager.is_chunk_built(spot["chunk"]), HORIZON_TIMEOUT_SECS):
		return [false, "the coast chunk never built"]
	# The body fell while the chunk's ground was missing (a coast far from the start has no collider at
	# the teleport): put it back on the built ground, let it settle, and require it to stand there.
	spot = _teleport_to(chunk, Vector3(spot_xz.x - float(chunk.x) * m, 0.0, spot_xz.y - float(chunk.y) * m))
	await _until(func(): return false, 1.0)   # the body settles
	var ground_y: float = _root._voxel.get_voxel_height_at(spot_xz)
	var body_y: float = _player_pos().y
	if body_y < ground_y - HORIZON_STAND_TOLERANCE_M:
		return [false, "the body is %.1f m under the coast ground (fell through)" % (ground_y - body_y)]
	# The ring on screen must be one built after the teleport, around the body (not the old one).
	if not await _until(func(): return _ring_ready_at(rings_before), HORIZON_TIMEOUT_SECS):
		return [false, "the distant ring never rebuilt at the coast"]
	var cam: Camera3D = player._camera
	var arm: Node3D = player._cam_arm
	var pivot: Node3D = player._pivot
	var keyed := Environment.new()
	keyed.background_mode = Environment.BG_COLOR
	keyed.background_color = SKYLINE_KEY
	keyed.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	keyed.ambient_light_color = Color(0.5, 0.5, 0.5)
	var layers: Array = []
	for cl in _root.find_children("*", "CanvasLayer", true, false):
		layers.append([cl, cl.visible])
		cl.visible = false
	var old_mask := cam.cull_mask
	var old_pitch := arm.rotation_degrees.x
	var old_yaw := pivot.global_rotation.y
	cam.cull_mask = DistantTerrain.RING_RENDER_LAYER
	cam.environment = keyed
	arm.rotation_degrees.x = HORIZON_PITCH
	var spreads: Array = []
	var worst := 0
	for h in HORIZON_HEADINGS:
		var dir := Vector2.from_angle(deg_to_rad(bearing + float(h)))
		pivot.global_rotation.y = atan2(-dir.x, -dir.y)
		for _f in 3:
			await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if img == null:
			continue
		img.save_png(ProjectSettings.globalize_path(OUT_DIR.path_join("horizon_%+d.png" % int(h))))
		var rows := skyline_rows(img, SKYLINE_KEY)
		var spread := skyline_spread(rows)
		if int(rows.min()) >= img.get_height():
			spread = img.get_height()   # no ring in view at all
		spreads.append(spread)
		worst = maxi(worst, spread)
	cam.environment = null
	cam.cull_mask = old_mask
	arm.rotation_degrees.x = old_pitch
	pivot.global_rotation.y = old_yaw
	for pair in layers:
		if is_instance_valid(pair[0]):
			pair[0].visible = pair[1]
	if spreads.size() < HORIZON_HEADINGS.size():
		return [false, "only %d of %d frames read" % [spreads.size(), HORIZON_HEADINGS.size()]]
	return [worst <= SKYLINE_FLAT_PX, "coast at %.0f m, bearing %.0f°, skyline spread %s px (limit %d)" % [
		Vector2(start.x, start.z).distance_to(spot_xz), bearing, str(spreads), SKYLINE_FLAT_PX]]

## Phase 165 — a vantage `FAR_PEAK_DISTANCE_M` from a tall ridge: the search over the shape
## on a coarse grid around `from` (nearest square ring first) for points at least `FAR_PEAK_MIN_HEIGHT` tall, then, for the
## nearest `FAR_PEAK_CANDIDATES` of them, the dry-land bearing (of sixteen) with the most open sight line to the ridge
## (`ridge_clearance`); most open first. Returns a list of [vantage, bearing_to_peak_deg, peak, peak_height, clearance],
## empty when none.
func _find_far_peak(from: Vector2) -> Array:
	var seed_v: int = _root._terrain.get_world_seed()
	var w := Horizon.default_circumference()
	var sea := WorldShape.sea_level()
	var peaks: Array = []   # [distance, point, height] of every grid point tall enough, nearest rings first
	var t0 := Time.get_ticks_msec()
	var n := int(FAR_PEAK_SEARCH_M / FAR_PEAK_SEARCH_STEP_M)
	var last_ring := n
	for r in range(0, n + 1):   # square rings of growing radius
		if r > last_ring:
			break
		for j in range(-r, r + 1):
			if Time.get_ticks_msec() - t0 > COAST_WORK_MS:
				await get_tree().process_frame
				t0 = Time.get_ticks_msec()
			var i_step := 1 if absi(j) == r or r == 0 else 2 * r   # interior cells belong to a smaller ring
			for i in range(-r, r + 1, i_step):
				var p := from + Vector2(float(i), float(j)) * FAR_PEAK_SEARCH_STEP_M
				var h := WorldShape.height(seed_v, p.x, p.y, w)
				if h >= FAR_PEAK_MIN_HEIGHT:
					peaks.append([p.distance_to(from), p, h])
					last_ring = mini(last_ring, r + FAR_PEAK_EXTRA_RINGS)
	# A ridge whose 60 km ring is all sea or highland has no vantage: take the nearest ridges that do,
	# and of those the most open sight line first (`ridge_clearance`).
	peaks.sort_custom(func(p1, p2): return float(p1[0]) < float(p2[0]))
	var vantages: Array = []
	var usable := 0
	for k in peaks.size():
		if usable >= FAR_PEAK_CANDIDATES:
			break
		if Time.get_ticks_msec() - t0 > COAST_WORK_MS:
			await get_tree().process_frame
			t0 = Time.get_ticks_msec()
		var peak: Vector2 = peaks[k][1]
		var best: Array = []
		var height_at := func(p: Vector2) -> float: return WorldShape.height(seed_v, p.x, p.y, w)
		for b in 16:
			var dir := Vector2.from_angle(deg_to_rad(float(b) * 22.5))
			var v := peak + dir * FAR_PEAK_DISTANCE_M
			var vh := WorldShape.height(seed_v, v.x, v.y, w)
			if vh > sea + 3.0 and vh < 100.0:
				var clear := ridge_clearance(height_at, v, peak, w / TAU)
				if best.is_empty() or clear > float(best[4]):
					best = [v, rad_to_deg((-dir).angle()), peak, peaks[k][2], clear]
			if Time.get_ticks_msec() - t0 > COAST_WORK_MS:
				await get_tree().process_frame
				t0 = Time.get_ticks_msec()
		if not best.is_empty():
			vantages.append(best)
			usable += 1
	# Most open sight line first: a taller ridge behind a nearer hill shows nothing.
	vantages.sort_custom(func(a, b): return float(a[4]) > float(b[4]))
	return vantages

## Phase 165 — how far (radians of elevation) the ridge at `peak` stands above the highest terrain between it and
## `from`, seen from a standing eye at `from` on a sphere of radius `radius_m`. `height_at` maps an xz point to the
## shape height. Positive: the ridge's top clears every nearer rise, so its bands can show above the ring's skyline;
## negative: a nearer hill hides it. Sampled every `RIDGE_SIGHT_STEP_M` along the line.
static func ridge_clearance(height_at: Callable, from: Vector2, peak: Vector2, radius_m: float) -> float:
	var dist := from.distance_to(peak)
	if dist < 2.0 * RIDGE_SIGHT_STEP_M:
		return 0.0   # no line to sample
	var eye: float = float(height_at.call(from)) + 2.0
	var top_angle := (float(height_at.call(peak)) - eye) / dist - dist / (2.0 * radius_m)
	var blocker := -INF
	var n := int(dist / RIDGE_SIGHT_STEP_M)
	for i in range(1, n):
		var d := float(i) * RIDGE_SIGHT_STEP_M
		var h: float = height_at.call(from.lerp(peak, d / dist))
		blocker = maxf(blocker, (h - eye) / d - d / (2.0 * radius_m))
	return top_angle - blocker

## Phase 165 — mountains on the horizon: from 60 km, a tall ridge shows rock or snow above the ring's skyline.
func _step_far_peak() -> Array:
	if DisplayServer.get_name() == "headless":
		return [true, "headless: no frame to read (skipped)"]
	var player = _root._player
	var start: Vector3 = _player_pos()
	var origin0 := Vector2(start.x, start.z)
	# The body's spot when the step starts varies run to run: when every vantage near it fails (a low
	# ridge, a hill in the way), hop to a few more origins across the world and search again.
	var origins: Array = [origin0]
	for d in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
		origins.append(origin0 + d * FAR_PEAK_HOP_M)
	var tried_peaks: Array = []
	var fails: Array = []
	for origin in origins:
		if tried_peaks.size() >= FAR_PEAK_MAX_TRIES:
			break
		var vantages: Array = await _find_far_peak(origin)
		var tries := 0
		for v in vantages:
			if tries >= FAR_PEAK_ATTEMPTS or tried_peaks.size() >= FAR_PEAK_MAX_TRIES:
				break
			if tried_peaks.any(func(p): return (p as Vector2).distance_to(v[2]) < FAR_PEAK_SAME_RIDGE_M):
				continue
			tried_peaks.append(v[2])
			tries += 1
			var res: Array = await _far_peak_attempt(v, player)
			print("[Playtest] far_peak try %d: %s" % [tried_peaks.size(), res[1]])
			if res[0]:
				return [true, "%s (try %d)" % [res[1], tried_peaks.size()]]
			fails.append(res[1])
	if fails.is_empty():
		return [false, "no ridge of %.0f m within %.0f km of %d origins with dry land %.0f km from it" % [FAR_PEAK_MIN_HEIGHT, FAR_PEAK_SEARCH_M / 1000.0, origins.size(), FAR_PEAK_DISTANCE_M / 1000.0]]
	return [false, "%d vantages failed; last: %s" % [fails.size(), fails[-1]]]

## One vantage of `_step_far_peak`: stand there, draw the ring alone and then the ring with the bands, count.
func _far_peak_attempt(found: Array, player) -> Array:
	var spot_xz: Vector2 = found[0]
	var bearing: float = found[1]
	var m := WorldPos.CHUNK_METERS
	var chunk := Vector2i(floori(spot_xz.x / m), floori(spot_xz.y / m))
	var bands = _root._distant.bands
	var before: Array = []   # per band: [builds completed, origin asked for] before the move
	for k in bands.band_count():
		before.append([bands.band_builds_completed(k), bands.band_origin(k)])
	var spot := _teleport_to(chunk, Vector3(spot_xz.x - float(chunk.x) * m, 0.0, spot_xz.y - float(chunk.y) * m))
	if not await _until(func(): return _root._chunk_manager.is_chunk_built(spot["chunk"]), FAR_PEAK_TIMEOUT_SECS):
		return [false, "the vantage chunk never built"]
	spot = _teleport_to(chunk, Vector3(spot_xz.x - float(chunk.x) * m, 0.0, spot_xz.y - float(chunk.y) * m))
	await _until(func(): return false, 1.0)   # the body settles
	if not await _until(func(): return _bands_ready_after(before), FAR_PEAK_TIMEOUT_SECS):
		return [false, "the distant bands never rebuilt at the vantage"]
	var cam: Camera3D = player._camera
	var arm: Node3D = player._cam_arm
	var pivot: Node3D = player._pivot
	var keyed := Environment.new()
	keyed.background_mode = Environment.BG_COLOR
	keyed.background_color = SKYLINE_KEY
	keyed.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	keyed.ambient_light_color = Color(0.5, 0.5, 0.5)
	var layers: Array = []
	for cl in _root.find_children("*", "CanvasLayer", true, false):
		layers.append([cl, cl.visible])
		cl.visible = false
	var old_mask := cam.cull_mask
	var old_pitch := arm.rotation_degrees.x
	var old_yaw := pivot.global_rotation.y
	cam.environment = keyed
	arm.rotation_degrees.x = HORIZON_PITCH
	var dir := Vector2.from_angle(deg_to_rad(bearing))
	pivot.global_rotation.y = atan2(-dir.x, -dir.y)
	var ring_img: Image = null
	var all_img: Image = null
	for pass_i in 2:
		cam.cull_mask = DistantTerrain.RING_RENDER_LAYER if pass_i == 0 else (DistantTerrain.RING_RENDER_LAYER | DistantBands.BANDS_RENDER_LAYER)
		for _f in 3:
			await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if pass_i == 0:
			ring_img = img
		else:
			all_img = img
	cam.environment = null
	cam.cull_mask = old_mask
	arm.rotation_degrees.x = old_pitch
	pivot.global_rotation.y = old_yaw
	for pair in layers:
		if is_instance_valid(pair[0]):
			pair[0].visible = pair[1]
	if ring_img == null or all_img == null:
		return [false, "no frame read"]
	ring_img.save_png(ProjectSettings.globalize_path(OUT_DIR.path_join("far_peak_ring.png")))
	all_img.save_png(ProjectSettings.globalize_path(OUT_DIR.path_join("far_peak_bands.png")))
	var rows := skyline_rows(ring_img, SKYLINE_KEY)
	# The tallest ridge on the seed is only ~350 m: its upper slopes may be grass at night, so the pass counts
	# any band pixel above the ring (the rock/snow share is reported beside it).
	var px := rock_pixels_above(all_img, rows, SKYLINE_KEY, 0.08, true)
	var rock_px := rock_pixels_above(all_img, rows, SKYLINE_KEY)
	var worst_ms := 0.0
	for f in _frames:
		worst_ms = maxf(worst_ms, float(f))
	var detail := "ridge %.0f m at %.0f km, bearing %.0f°: %d band px above the ring's skyline, %d of them rock/snow (need %d), worst frame %.0f ms" % [
		float(found[3]), Vector2(spot_xz).distance_to(Vector2(found[2])) / 1000.0, bearing, px, rock_px, FAR_PEAK_MIN_PX, worst_ms]
	return [px >= FAR_PEAK_MIN_PX, detail]

## True when every band whose origin moved since `before` (`[completed, origin]` per band) has
## completed a build newer than it, none is pending, and band 0 is centred on the cell the body stands
## in. A band whose origin did not move is never asked again, so it is not waited for (#444).
func _bands_ready_after(before: Array) -> bool:
	var b = _root._distant.bands
	if b == null or b.is_building():
		return false
	for k in b.band_count():
		if k >= before.size():
			if b.band_builds_completed(k) == 0:
				return false
			continue
		if b.band_origin(k) != before[k][1] and (b.band_builds_completed(k) <= int(before[k][0]) or b.band_built_origin(k) != b.band_origin(k)):
			return false
	var pp := _player_pos()
	return b.band_built_origin(0) == DistantBands.origin_for(b.band_spec(0), Vector2(pp.x, pp.z))

## True when a ring build newer than `completed_before` is swapped in, none is pending, and it is
## centred within two lattice cells of the body.
func _ring_ready_at(completed_before: int) -> bool:
	var d = _root._distant
	if d == null or d.is_building() or d.rebuilds_completed <= completed_before or d.get_child_count() == 0 or d._req.built == null:
		return false
	var pp := _player_pos()
	var rc: Vector2 = d._req.built.args["ring_center"]
	return rc.distance_to(Vector2(pp.x, pp.z)) <= 4.0 * d.ring_half_m / float(DistantTerrain.GRID)

## The nearest coast from which every ray across the four headings' frames sees nothing above the sea
## horizon out to the ring's outer circle. Bearings every COAST_BEARING_STEP are marched outward on the
## large-scale shape until they reach the sea; each crossing (nearest first) is bisected to the shore
## and a point COAST_INLAND_M back onto land is tested. Returns [xz, bearing_deg] or [] when none
## within COAST_SEARCH_M works. Yields every COAST_WORK_MS.
func _find_coast(from: Vector2) -> Array:
	var outer: float = _root._distant.outer_radius_m if _root._distant != null and _root._distant.outer_radius_m > 0.0 \
		else DistantTerrain.outer_radius_for(DistantTerrain.ring_half_extent(_root._chunk_manager.stream_radius()))
	var eye_h := PlayerSlice.camera_eye_height(PlayerSlice.CAMERA_DISTANCE, HORIZON_PITCH)
	var span: float = float(HORIZON_HEADINGS.back()) - float(HORIZON_HEADINGS.front()) + 2.0 * HORIZON_HALF_FOV
	var need := int(ceil(span / HORIZON_RAY_STEP)) + 1
	var rays := int(360.0 / HORIZON_RAY_STEP)
	var sea := WorldShape.sea_level()
	var seed_v: int = _root._terrain.get_world_seed()
	var w := Horizon.default_circumference()
	var t0 := Time.get_ticks_msec()
	var crossings: Array = []   # [distance, direction]
	for b in int(360.0 / COAST_BEARING_STEP):
		var dir := Vector2.from_angle(deg_to_rad(float(b) * COAST_BEARING_STEP))
		var d := 0.0
		while d <= COAST_SEARCH_M:
			if Time.get_ticks_msec() - t0 > COAST_WORK_MS:
				await get_tree().process_frame
				t0 = Time.get_ticks_msec()
			var p := from + dir * d
			if WorldShape.height(seed_v, p.x, p.y, w) < sea - COAST_DEEP_M and _open_water(seed_v, w, p, dir, outer, sea - COAST_DEEP_M):
				crossings.append([d, dir])
				break
			d += COAST_MARCH_M
	crossings.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	for c in crossings:
		if Time.get_ticks_msec() > _step_deadline_ms:
			break
		var dir: Vector2 = c[1]
		var hi := float(c[0])                               # sea
		var lo := maxf(hi - COAST_MARCH_M, 0.0)
		# The shape marched above `sea - COAST_DEEP_M` there, which may still be water: walk back to land.
		while lo > 0.0 and _root._terrain.get_height_at(from + dir * lo) < sea:
			hi = lo
			lo = maxf(lo - COAST_MARCH_M, 0.0)
		while hi - lo > 16.0:
			var mid := (lo + hi) * 0.5
			var p := from + dir * mid
			if _root._terrain.get_height_at(p) < sea:
				hi = mid
			else:
				lo = mid
		var xz := from + dir * maxf(lo - COAST_INLAND_M, 0.0)
		var ground: float = _root._terrain.get_height_at(xz)
		if ground < sea:
			continue
		var open := {}
		var r0 := 0
		while r0 < rays:
			var run := 0
			while run < need and _ray_cached(open, xz, (r0 + run) % rays, ground + eye_h, outer, sea):
				run += 1
			if run >= need:
				print("[Playtest] coast at %.0f km" % (from.distance_to(xz) / 1000.0))
				return [xz, float(r0) * HORIZON_RAY_STEP + span / 2.0]
			r0 += run + 1   # no run through the failed ray can hold the span
			await get_tree().process_frame
	print("[Playtest] none of %d coast crossings had open sea across the frames" % crossings.size())
	return []

## True when the large-scale shape stays under `level` for `reach` metres past `p` along `dir` (open
## water, not a lagoon or a shallow flat the detail noise lifts above the sea).
static func _open_water(seed_v: int, w: float, p: Vector2, dir: Vector2, reach: float, level: float) -> bool:
	var d := COAST_MARCH_M
	while d <= reach:
		var q := p + dir * d
		if WorldShape.height(seed_v, q.x, q.y, w) >= level:
			return false
		d += COAST_MARCH_M
	return true

func _ray_cached(cache: Dictionary, xz: Vector2, r: int, eye_y: float, outer: float, sea: float) -> bool:
	if not cache.has(r):
		cache[r] = _ray_open(xz, deg_to_rad(float(r) * HORIZON_RAY_STEP), eye_y, outer, sea)
	return cache[r]

## True when nothing along the ray at `angle` from `xz` rises over the sea horizon of an eye at `eye_y`
## by more than HORIZON_RISE_MAX: every sample out to `outer` is sea, or lies at most that far above the
## eye's horizon line after the curvature drop.
func _ray_open(xz: Vector2, angle: float, eye_y: float, outer: float, sea: float) -> bool:
	var dir := Vector2.from_angle(angle)
	var horizon_dip := sqrt(2.0 * maxf(eye_y - sea, 0.1) / Horizon.planet_radius())
	var d := 64.0
	while d <= outer:
		var h: float = _root._terrain.get_height_at(xz + dir * d)
		if h >= sea:
			var dip := (eye_y - h + Horizon.curvature_drop(d)) / d
			if dip < horizon_dip - HORIZON_RISE_MAX:
				return false
		d += 64.0 if d < 1000.0 else 500.0
	return true

## Phase 141 — the pole: stand just past the north pole, let the window settle, then step over the
## fold line. Only the frames from the fold until the folded window is rebuilt (no stand-in left,
## nothing queued or in flight) are recorded, so the row is the cost of a pole crossing.
func _step_pole() -> Array:
	var x: int = (_root._player.get_world_pos()["chunk"] as Vector2i).x
	var row := TerrainSlice.pole_chunks() + TerrainSlice.FOLD_MARGIN_CHUNKS - 2
	var near := { "chunk": Vector2i(x, row), "local": Vector3(16.0, 0.0, 16.0) }
	GameBus.player_teleport.emit(near)
	if not await _until(func(): return _root._chunk_manager.is_chunk_built(near["chunk"]) and _window_settled(), STREAM_TIMEOUT_SECS):
		return [false, "the window past the pole never settled"]
	_frames = []
	_chunk_builds = 0
	_skip_frames = 0
	var started := Time.get_ticks_msec()
	# Phase 145 — what the window holds at the fold (`last_fold_ids`) must cross it: only the ones the
	# folded window does not cover (`fold_pruned`) may go.
	var pruned_before: int = _root._creature.fold_pruned + _root._tree.fold_pruned
	GameBus.player_teleport.emit({ "chunk": Vector2i(x, row + 2), "local": Vector3(16.0, 0.0, 16.0) })
	var folded: bool = await _until(func(): return absi((_root._player.get_world_pos()["chunk"] as Vector2i).y) < TerrainSlice.pole_chunks(), STEP_TIMEOUT_SECS)
	if not folded:
		return [false, "the body was never folded over the pole"]
	var rebuilt: bool = await _until(func(): return _root._voxel.standin_count() == 0 and _window_settled(), STEP_TIMEOUT_SECS)
	var held_creatures: Array = _root._creature.last_fold_ids
	var held_trees: Array = _root._tree.last_fold_ids
	var lost := 0
	for iid in held_creatures:
		if not _root._creature._instances.has(iid):
			lost += 1
	for tid in held_trees:
		if not _root._tree._trees.has(tid):
			lost += 1
	var despawned: int = lost - (_root._creature.fold_pruned + _root._tree.fold_pruned - pruned_before)
	if despawned > 0:
		return [false, "%d creatures or trees despawned across the fold" % despawned]
	return [rebuilt, "folded, window rebuilt in %d ms, %d creatures and %d trees held, none despawned" % [Time.get_ticks_msec() - started, held_creatures.size(), held_trees.size()] if rebuilt else "folded window not rebuilt"]

## Nothing queued, deferred or in flight in the chunk manager.
func _window_settled() -> bool:
	var cm = _root._chunk_manager
	return cm._load_queue.is_empty() and cm._rebuild_queue.is_empty() and cm._builds.is_empty() and cm._unload_queue.is_empty()
