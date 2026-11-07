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
const ProcessProfiler := preload("res://src/tests/process_profiler.gd")
const StructureRules := preload("res://src/structure/structure_rules.gd")
const StructureLimits := preload("res://src/structure/structure_limits.gd")
const ChatCommands := preload("res://src/core/chat_commands.gd")
const PlayerRules := preload("res://src/core/player_rules.gd")
const WritingRules := preload("res://src/technology/writing_rules.gd")
const ChestRules := preload("res://src/world/chest_rules.gd")

const ARG := "--playtest-bot"
const OUT_DIR := "res://playtest"
## The bot's own save directory, emptied before the boot: a saved world must not pick the seed.
const SAVE_DIR := "user://playtest/server/"
const TUTORIAL_FILE := "user://playtest/tutorial.json"
## The world seed every run plays, so a step's verdict depends on the commit, not on a random world:
## on a fresh `randi()` seed far_peak, travel and horizon passed or failed by luck (a seed's tallest
## ridge was ~350 m against far_peak's 330 before Phase 211). Where the bot stands still varies run to run
## (builder, walk distance); since Phase 211 far_peak looks at the planet's summits, not near the body. 42, 31 and 7
## passed every step locally; 162 failed walk. `--playtest-seed <n>` plays another seed.
const WORLD_SEED := 42
## Phase 181 — the name the `create` step gives the bot's character (a fresh save offers the screen).
const CREATE_NAME := "Hikari"
const SEED_ARG := "--playtest-seed"
## Phase 183 — the local player's id in every run. The spawn search is seeded by it, and a minted id is
## new every run: the bot started on a different continent each time, with 0 to 280 creatures around the
## gated steps, which was most of their run-to-run spread.
const PLAYER_ID := "player_0_1_0000000000000000000000000000b076"
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
const WALK_WINDOW_MIN_M := 1.5   ## ... and the body must have covered this much inside the feet window
const WALK_GROUND_SECS := 15.0   ## the walk step waits this long for the chunk under the body
const WALK_FOOT_SECS := 2.0   ## the walk step samples the feet over the last this many seconds
## The feet must swap the lead at least this often over the window. A share-of-frames check flaked
## under xvfb: ~10 fps samples alias with the gait, so a cycling walk could read 14% one foot ahead.
const WALK_FOOT_MIN_SWITCHES := 2
const WALK_FOOT_MIN_FRAMES := 30   ## the walk step keeps sampling until the feet window holds this many frames (a ~7 fps runner aliases with the gait)
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
## Phase 191 — the slow-machine run (CI, worker pool limited to 2 threads): `--playtest-only flight` plays that
## one step, `--playtest-flight-speed 10` flies it at the old 90 m/s (walk speed × 10 × the flying factor).
const ONLY_ARG := "--playtest-only"
const FLIGHT_SPEED_ARG := "--playtest-flight-speed"
## Phase 194 (#504) — `--playtest-abort flight` (a check of the bot, never a gated run): the flight step hangs in its
## record flight, with the body flying, the near ring off and the TickProbe on, so the run proves the step runner
## restores all three when a step never returns.
const ABORT_ARG := "--playtest-abort"
const FLIGHT_SECS := 12.0
const FLIGHT_WARMUP_SECS := 1.5
const FLIGHT_SAMPLE_SECS := 0.25
## The floor sits under the shared CI runner's spread at 270 m/s: native-builder covers of 79–100% on the
## same commit, so 0.9 failed on runner noise rather than on a streaming regression.
const FLIGHT_MIN_COVER := 0.75
const FLIGHT_MAX_SHARE := 0.5   ## Phase 189: near-ring ms per attached chunk at most this share of the record flight's (CI median)
const FLIGHT_WORKER_MAX_SHARE := 1.0 / 3.0   ## Phase 190: worker ms per crossing at most this share of the record flight's (CI median)
## Phase 189 — the chunk phases the near ring removes: off-ring collision bodies and contents spawned under a
## fast player. The gate compares these; the rest of the pump (mesh upload, dispatch) is report-only, since
## its share varies with the machine (a 2-core llvmpipe runner pays ~4 ms more per chunk on both flights).
const NEAR_RING_PHASES := ["chunk_attach_collision", "chunk_contents"]
const TELEPORT_SETTLE_MS := 1500 ## frames this long after a teleport (the new window's builds) are not recorded
const STEP_GRACE_SECS := 10.0    ## past its deadline a step that has not returned has crashed or hung: fail it
const SPAWN_OFFSET_M := 2.0      ## a teleport lands this far above the ground
## Phase 206 — the village seeded round the spawn before the steps (`_seed_village`): this many private houses,
## each a VILLAGE_SIDE-tile square floor walled VILLAGE_WALL_STEPS steps high, on a ring between these radii.
const VILLAGE_HOUSES := 24
const VILLAGE_SIDE := 8
const VILLAGE_WALL_STEPS := 16
const VILLAGE_RING_M := Vector2(40.0, 120.0)
## Metres above the spawn's ground the village's index records sit: a circle is measured on the ground, so the
## houses still keep creatures away, but no block the steps mine, place or walk on can ever be one of them.
const VILLAGE_ALTITUDE_M := 4000.0
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
## Phase 211 — the ridge is an Earth-scale peak: one of the seed's strongest massif summits
## (`WorldShape.massif_summits`), at least FAR_PEAK_MIN_HEIGHT tall, seen from lowland 150 km out (its
## top stands about 7 km over the curve of the planet there), and the frame must have no holes.
const FAR_PEAK_DISTANCE_M := 150000.0
const FAR_PEAK_MIN_HEIGHT := 8000.0
const FAR_PEAK_VANTAGE_MAX_M := 2000.0   ## a vantage stands on dry land below this, well under the peak
const FAR_PEAK_SUMMIT_RADIUS_M := 12000.0   ## the crest is looked for this far around a summit node
const FAR_PEAK_SUMMIT_STEP_M := 500.0
const FAR_PEAK_CANDIDATES := 8       ## strongest summits with a usable vantage compared (the most open sight line wins)
const FAR_PEAK_MAX_HOLE_PX := 0      ## key-colour pixels allowed between the drawn skyline and the ring's (holes)
const FAR_PEAK_MAX_TRIES := 8        ## vantages tried in all, over every search origin
const FAR_PEAK_SAME_RIDGE_M := 30000.0   ## a vantage on a peak this close to one already tried is skipped (same massif)
const FAR_PEAK_STEP_SECS := 900.0    ## wall clock for the whole step (a try takes ~20-50 s)
const FAR_PEAK_MIN_PX := 8            ## rock or snow pixels above the ring's skyline needed to pass
const FAR_PEAK_SAT_MAX := 0.18        ## rock (grey) and snow (white) are below this saturation; land and sea are not
## Phase 195 — least share of the band pixels above the ring's skyline that must be rock or snow (#444): any
## band geometry (a near hill) draws there, a far peak draws grey and white. A run at the pinned seed saw 54%.
const FAR_PEAK_MIN_ROCK_SHARE := 0.1
const FAR_PEAK_TIMEOUT_SECS := 240.0
const RIDGE_SIGHT_STEP_M := 500.0   ## the sight line to the ridge is sampled this often (`ridge_clearance`)
const COAST_SEARCH_M := 4.0e6         ## the coast search marches this far from the body
const COAST_BEARING_STEP := 11.25     ## degrees between marched bearings
const COAST_MARCH_M := 2000.0         ## march step on the large-scale shape
const COAST_INLAND_M := 48.0          ## the body stands this far back from the shore
const COAST_DEEP_M := 20.0            ## open water: the shape lies this far under the sea level
const COAST_WORK_MS := 40             ## search work per frame before it yields
## Phase 213 — the tower step: a clan builds past the wood floor limit on flattened ground beside home, then on in a
## higher class, sets a chest to owner-only, reads a book, dismantles fresh blocks, respawns and flies to a peak.
const TOWER_TIMEOUT_SECS := 420.0
const TOWER_CLAN := "Towerfolk"
const TOWER_SIDE := 5                ## the wood part is TOWER_SIDE × TOWER_SIDE columns (2.5 m: three floors are not too slender)
const TOWER_WOOD := "Thornwood"
const TOWER_HIGH := "Concrete"       ## the class above wood the step switches to: a row of TOWER_SIDE columns along the wood's +x side
const TOWER_HIGH_FLOORS := 4         ## the concrete row is built this many floors high, one past the wood's refusal
const TOWER_OFFSET_M := 6.0          ## candidate footprints start this far from home, on TOWER_BEARINGS bearings
const TOWER_BEARINGS := 8
const TOWER_MAX_SPREAD_M := 1.0      ## the flattest candidate's natural ground may differ by at most this (mined level)
const TOWER_DISMANTLE_BLOCKS := 2    ## fresh blocks placed and dismantled at Building level 0 (half each: one comes back)
const TOWER_VIEW_M := 9.0            ## the tower's screenshot is taken from this far west of the footprint
const TOWER_PEAK_MIN_M := 8000.0     ## the peak the step flies to is at least this high

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
var _flight_mps: float = -1.0   ## Phase 194: the flight speed, read from the command line once (`_flight_speed`)
## Phase 194 (#504) — what a step changed that the runner must put back whether or not the step returns (a step
## coroutine that hits a script error or hangs never reaches its own restore). Called once, after the step.
var _step_restore: Callable = Callable()
var _mined: Array = []
var _chopped: Array = []
var _crafted: Array = []
var _researched: Array = []
var _placed: Array = []
var _home: Dictionary = {}   ## Phase 213: where the body stood after the boot (the tower is built beside it)
var _structure_refusals: Array = []   ## per `structure_resolved`: the reason of a refused placement, else ""
var _chest_results: Array = []   ## [action, reason] per `chest_resolved`
var _writing_results: Array = []   ## [action, item, reason] per `writing_resolved`
var _respawns := 0
var _tower_started_ms := 0
var _spawns_seen := 0   ## Phase 213: creature spawns and respawns in the session
var _circle_spawns: Array = []   ## ... the ones whose spawn point lies inside a structure's circle
var _steps_done: Array = []   ## finished step records, for the watchdog's partial report
var _profiler: ProcessProfiler = null   ## Phase 183: `--playtest-profile`, else null
var _profile_frames: Array = []   ## ... per recorded frame, its TickProbe phase table (µs)
var _profile_creatures := 0   ## ... the most creature instances the host held in a recorded frame
var _frame_end: Node

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
	# Phase 186 — the tutorial plays from its own fresh file, so the bot never marks or restarts the player's steps.
	var tut = root._tutorial_wiring.slice
	if tut != null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TUTORIAL_FILE))
		tut.path = TUTORIAL_FILE
		tut.load_saved()
	var seed_v := seed_from_args(args)
	root._terrain.set_world_seed(seed_v)
	root._persistence_wiring.fixed_local_id = PLAYER_ID
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
	if step == "tower":
		return TOWER_TIMEOUT_SECS
	return STREAM_TIMEOUT_SECS if step == "stream" or step == "pole" or step == "flight" else STEP_TIMEOUT_SECS

static func step_names() -> Array:
	var only := only_from_args(Array(OS.get_cmdline_user_args()))
	return [only] if only != "" else all_step_names()

## Phase 191 — the step `--playtest-only <step>` names (or `flag` names), or "".
static func only_from_args(args: Array, flag: String = ONLY_ARG) -> String:
	var i := args.find(flag)
	if i >= 0 and i + 1 < args.size():
		return str(args[i + 1])
	return ""

## Phase 191 — the flight speed in m/s: `--playtest-flight-speed <factor>` is the `/speed` factor (clamped to the
## admin range), else the top admin speed (`FLIGHT_SPEED_MPS`).
static func flight_speed_from_args(args: Array) -> float:
	var i := args.find(FLIGHT_SPEED_ARG)
	if i >= 0 and i + 1 < args.size() and str(args[i + 1]).is_valid_float():
		return PlayerSlice.SPEED * clampf(str(args[i + 1]).to_float(), AdminRules.SPEED_MIN, AdminRules.SPEED_MAX) * AdminRules.FLY_SPEED_FACTOR
	return FLIGHT_SPEED_MPS

static func all_step_names() -> Array:
	return ["create", "walk", "stream", "flight", "mine", "gather", "craft", "character_sheet", "place", "fight", "tutorial", "travel", "mount", "horizon", "far_peak", "pole", "tower"]

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

## Phase 194 (#504) — the flight step's share gates on one run: collision and contents per attached chunk over
## FLIGHT_MAX_SHARE of the record flight's, worker ms per crossing over FLIGHT_WORKER_MAX_SHARE of the record's.
## A flight that attached or crossed nothing on either flight is not judged here (its coverage verdict is).
## CI gates the median of three runs instead (`tools/check_playtest_budget.py`, which reads both shares from here).
static func flight_share_failures(steps: Array) -> Array:
	var out: Array = []
	for s in steps:
		var f: Dictionary = s.get("flight", {}) if str(s["step"]) == "flight" else {}
		if int(f.get("attached", 0)) > 0 and int(f.get("record_attached", 0)) > 0:
			var limit := float(f["record_near_ms_per_attach"]) * FLIGHT_MAX_SHARE
			if float(f["near_ms_per_attach"]) > limit:
				out.append("flight: collision and contents %.1f ms per attached chunk is over %.1f ms (%d%% of the near-ring-off record's)" % [
					float(f["near_ms_per_attach"]), limit, roundi(FLIGHT_MAX_SHARE * 100.0)])
		if int(f.get("crossings", 0)) > 0 and int(f.get("record_crossings", 0)) > 0:
			var wlimit := float(f["record_worker_ms_per_crossing"]) * FLIGHT_WORKER_MAX_SHARE
			if float(f["worker_ms_per_crossing"]) > wlimit:
				out.append("flight: worker %.0f ms per crossing is over %.0f ms (%d%% of the full-detail record's)" % [
					float(f["worker_ms_per_crossing"]), wlimit, roundi(FLIGHT_WORKER_MAX_SHARE * 100.0)])
	return out

static func load_budgets() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(BUDGET_PATH))
	return parsed if parsed is Dictionary else {}

## The run verdict. `failures` names every hard failure: a failed (or timed-out) step, a frame over
## HARD_FRAME_MS, a step over its process-time budget or a flight over its shares (`budgets`, empty to skip
## both: `--playtest-no-budget`) and a step of the fixed list that never ran.
static func build_report(steps: Array, budgets: Dictionary = {}) -> Dictionary:
	var failures: Array = []
	failures.append_array(budget_failures(steps, budgets))
	if not budgets.is_empty():
		failures.append_array(flight_share_failures(steps))
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

## Phase 211 — holes in what the bands draw above the ring: per column, the key-colour pixels between the
## frame's own skyline (its first non-key row) and the ring's skyline row (`ring_rows`). Terrain is a
## heightfield seen from above it, so below a column's first drawn pixel every ray meets ground: a key
## pixel there is a gap in the mesh. (Below the ring's skyline the voxel window's hole shows key, so the
## count stops there.)
static func hole_pixels(img: Image, ring_rows: Array, key: Color, tol: float = 0.08) -> int:
	var fmt := img.duplicate() as Image
	fmt.convert(Image.FORMAT_RGB8)
	var data := fmt.get_data()
	var w := fmt.get_width()
	var limit := int(tol * 3.0 * 255.0)
	var kr := int(roundf(key.r * 255.0))
	var kg := int(roundf(key.g * 255.0))
	var kb := int(roundf(key.b * 255.0))
	var top_rows := skyline_rows(img, key, tol)
	var count := 0
	for x in mini(w, ring_rows.size()):
		for y in range(int(top_rows[x]), int(ring_rows[x])):
			var i := (y * w + x) * 3
			if absi(data[i] - kr) + absi(data[i + 1] - kg) + absi(data[i + 2] - kb) <= limit:
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
	GameBus.structure_resolved.connect(func(_p: String, action: String, ok: bool, reason: String): _structure_refusals.append(reason if action == "place" and not ok else ""))
	GameBus.chest_resolved.connect(func(_p: String, action: String, _ok: bool, reason: String): _chest_results.append([action, reason]))
	GameBus.writing_resolved.connect(func(_p: String, action: String, item: String, _ok: bool, reason: String): _writing_results.append([action, item, reason]))
	GameBus.player_respawned.connect(func(_pos: Vector3): _respawns += 1)
	GameBus.creature_spawned.connect(func(iid: String, _c: String, _pos: Vector3): _note_spawn(iid))
	GameBus.creature_respawned.connect(func(iid: String, _c: String): _note_spawn(iid))
	# Phase 174: the bot's callbacks run first and FrameEnd's last, so the two clocks bracket the frame's
	# _process and _physics_process work. Performance.TIME_PROCESS cannot stand in: Godot publishes the MAX
	# process time of the last second, once a second, so a per-frame sample of it is the step's worst frame.
	process_priority = FrameEnd.FIRST
	process_physics_priority = FrameEnd.FIRST
	_frame_end = FrameEnd.new()
	_frame_end.bot = self
	add_child(_frame_end)

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
	if _profiler != null:
		TickProbe.enabled = true
		TickProbe.take_times()   # what ran between frames (physics) is not this frame's process work
		_profiler.take_over(get_tree().root, [self, _frame_end])
		_profiler.run_frame(delta)
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
	if _profiler != null:
		_profile_frames.append(TickProbe.take_times())
		if _root != null and _root._creature != null:
			_profile_creatures = maxi(_profile_creatures, _root._creature.instances_view().size())
	var vp := get_viewport().get_viewport_rid()
	_render_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.viewport_get_measured_render_time_gpu(vp))

func run(root: Node) -> void:
	_root = root
	# Phase 194 (#512) — an unknown `--playtest-only` name is a mistake, not a request for every step.
	var only := only_from_args(Array(OS.get_cmdline_user_args()))
	if only != "" and not only in all_step_names():
		print("[Playtest] FAILURE: --playtest-only names no step: %s (steps: %s)" % [only, ", ".join(all_step_names())])
		print("[Playtest] FAIL")
		get_tree().quit(1)
		return
	if ProcessProfiler.requested(Array(OS.get_cmdline_user_args())):
		_profiler = ProcessProfiler.new()
		print("[Playtest] profiling every script _process (diagnostic: not a gated run)")
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	# A step body that hits a script error aborts its coroutine and would leave the process
	# running with no verdict; the watchdog writes what exists and quits.
	var budget := BOOT_TIMEOUT_SECS + WATCHDOG_SLACK_SECS
	for step_name in step_names():
		budget += _step_timeout(step_name)
	get_tree().create_timer(budget).timeout.connect(_on_watchdog)
	print("[Playtest] waiting for the world boot")
	# The host's own gate held the boot until the first ring was built (`_finish_host_boot`). The ring is armed round
	# the boot centre, and once the player is placed at the spawn the window can stream those chunks away, so the
	# ring reading ready is a race (Phase 213: a faster boot lost it every run). The ground under the body is what
	# the steps stand on.
	var booted: bool = await _until(func(): return _root._player != null and not _root._chunk_manager._first_ring.is_empty() \
		and not _root._pending_host_boot and _root._chunk_manager.is_chunk_built(_root._player.get_world_pos()["chunk"]), BOOT_TIMEOUT_SECS)
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
		_home = _root._player.get_world_pos().duplicate()
		_seed_village()
		for step_name in step_names():
			var rec: Dictionary = await _run_step(step_name)
			_steps_done.append(rec)
			steps.append(rec)
	_finish(steps)

## Phase 206 — a village of structures round the spawn, so walk, craft and fight pay the circle lookups a town
## costs (every spawn and placement asks the index). Recorded in the host's structure index only, not the
## world: other players' private houses, whose circles keep creatures away but refuse none of the bot's builds.
## They are recorded high above the ground (`VILLAGE_ALTITUDE_M`), so no block of the world coincides with one.
func _seed_village() -> void:
	var st = _root._structures
	var at: Dictionary = _root._player.get_world_pos()
	var m := WorldPos.CHUNK_METERS
	var home := Vector2(float(at["chunk"].x) * m + at["local"].x, float(at["chunk"].y) * m + at["local"].z)
	var step_mm := roundi(VoxelSlice.STEP_HEIGHT * 1000.0)
	var floor_mm := roundi((_root._terrain.get_height_at(home) + VILLAGE_ALTITUDE_M) * 1000.0)
	for h in VILLAGE_HOUSES:
		var angle := float(h) * 2.39996   # the golden angle: the houses spread round the ring
		var dist := lerpf(VILLAGE_RING_M.x, VILLAGE_RING_M.y, float(h) / float(maxi(1, VILLAGE_HOUSES - 1)))
		var c := home + Vector2(cos(angle), sin(angle)) * dist
		var corner := Vector2i(floori(c.x / VoxelSlice.TILE_SIZE), floori(c.y / VoxelSlice.TILE_SIZE))
		var sid := 0
		for x in VILLAGE_SIDE:
			for z in VILLAGE_SIDE:
				var wall := x == 0 or z == 0 or x == VILLAGE_SIDE - 1 or z == VILLAGE_SIDE - 1
				for k in (VILLAGE_WALL_STEPS if wall else 1):
					var plan := { "tile": st.canonical(corner + Vector2i(x, z)), "mm": floor_mm + k * step_mm, "material": "Ashite", "player_id": "villager_%d" % h }
					plan.merge({ "verdict": "join", "sid": sid } if sid != 0 else { "verdict": "new", "kind": "private", "owner": "villager_%d" % h })
					sid = st.commit_place(plan)
	print("[Playtest] village: %d structures, %d blocks round the spawn" % [st.count(), st.cell_count()])

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
	print("[Playtest] step %s at chunk %s" % [step, str(_root._player.get_world_pos()["chunk"])])
	_frames = []
	_process_ms = []
	_physics_ms = []
	_render_ms = []
	_profile_frames = []
	_profile_creatures = 0
	_chunk_builds = 0
	_skip_frames = WARMUP_FRAMES
	_step_deadline_ms = Time.get_ticks_msec() + int(_step_timeout(step) * 1000.0)
	_recording = true
	_step_result = []
	var before := _session_state()
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
	if _step_restore.is_valid():
		_step_restore.call()
		_step_restore = Callable()
	var leaks := state_leaks(before, _session_state())
	if not leaks.is_empty():
		result = [false, "%s; left behind: %s" % [str(result[1]), ", ".join(leaks)]]
	var rec := step_record(step, bool(result[0]), str(result[1]), _frames, _chunk_builds,
		{ "process_ms": _process_ms, "physics_ms": _physics_ms, "render_ms": _render_ms })
	if step == "stream":
		rec["builder"] = NativeBuilder.mode()
		rec["build_rate"] = _stream_rate
		rec["build_breakdown"] = _build_breakdown
	if step == "flight":
		rec["flight"] = _flight
	if _profiler != null:
		rec["profile"] = ProcessProfiler.summarize(_profile_frames)
		rec["profile_creatures"] = _profile_creatures
	if step != "create" and step != "tower":   # Phase 181: create shoots the screen itself, before it closes; tower its two views
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

## A key tapped with Alt held (a window shortcut, Phase 214).
func _alt_key(keycode: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.alt_pressed = true
		ev.pressed = pressed
		Input.parse_input_event(ev)

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
	# The pinned spawn has a wolf pack beside it (Phase 211's freed workers bring it in sooner): it downed the
	# body mid-walk on CI, and the respawn's teleport read as 5,400 km walked. The step tests the gait, not the
	# world's spawns: a downed body respawns first, then it is healed and the creatures near it removed.
	if not _root._player.is_alive():
		await _until(func(): return _root._player.is_alive(), PlayerSlice.RESPAWN_DELAY + STEP_TIMEOUT_SECS)
	GameBus.admin_healed.emit()
	_clear_creatures_near_body()
	# A slow builder may not have the ground under the body yet: it would stand or crawl, and the
	# clip rightly stays near idle. Wait for the ground before judging the gait.
	var here_chunk: Vector2i = _root._player.get_world_pos()["chunk"]
	await _until(func(): return _root._chunk_manager.is_chunk_built(here_chunk), WALK_GROUND_SECS)
	var start := _player_pos()
	var rig := _player_rig()
	var skeleton: Skeleton3D = null
	if rig != null:
		skeleton = _first_skeleton(rig)
	var foot_l := skeleton.find_bone("Foot_L") if skeleton != null else -1
	var foot_r := skeleton.find_bone("Foot_R") if skeleton != null else -1
	var samples: Array = []  # [time, left, right] foot positions in world space; the last WALK_FOOT_SECS are kept, but never fewer than WALK_FOOT_MIN_FRAMES
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
				skeleton.to_global(skeleton.get_bone_global_pose(foot_r).origin), here])
			while samples.size() > WALK_FOOT_MIN_FRAMES and elapsed - float(samples[0][0]) > WALK_FOOT_SECS:
				samples.pop_front()
		var window_m := 0.0
		if not samples.is_empty():
			var first: Vector3 = samples[0][3]
			window_m = Vector2(here.x - first.x, here.z - first.z).length()
		if (elapsed >= WALK_SECS and travelled >= WALK_MIN_M and (window_m >= WALK_WINDOW_MIN_M or foot_l < 0) and (samples.size() >= WALK_FOOT_MIN_FRAMES or foot_l < 0)) or elapsed >= WALK_MAX_SECS:
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

func _flight_speed() -> float:
	if _flight_mps < 0.0:
		_flight_mps = flight_speed_from_args(Array(OS.get_cmdline_user_args()))
	return _flight_mps

## Phase 194 (#504) — the session state a step may change and must leave as it found it: the body's flight, the
## near ring and the TickProbe (the profiler owns the probe in a `--playtest-profile` run).
func _session_state() -> Dictionary:
	var state := { "flying": _root._player.flying, "near_ring": _root._chunk_manager._near.enabled }
	if _profiler == null:
		state["tick_probe"] = TickProbe.enabled
	return state

## The entries of `after` that differ from `before`, as "name on/off". Pure.
static func state_leaks(before: Dictionary, after: Dictionary) -> Array:
	var out: Array = []
	for k in before:
		if after.has(k) and after[k] != before[k]:
			out.append("%s %s" % [k, "on" if bool(after[k]) else "off"])
	return out

## Put back what the flight step changed (see `_step_restore`).
func _restore_flight(speed: float, was_flying: bool, probe_was: bool) -> void:
	_root._chunk_manager.set_near_ring_enabled(true)
	if _root._player.flying != was_flying:
		GameBus.admin_moves_synced.emit(speed, was_flying)
	TickProbe.enabled = probe_was

## Phase 187 — carry the body east at FLIGHT_SPEED_MPS (a ground-hugging teleport every frame: the
## streaming load of admin flight without its input or physics) and sample the ground under it.
## Then put it back where it started, built, for the steps that follow.
## Phase 189 — the body flies (as `/fly` sets it), and after the warm-up each flight records the chunk
## manager's main-thread ms per attached chunk (TickProbe phases). The step flies twice over the same
## ground: the gated flight, then a record flight with the near ring off (`set_near_ring_enabled(false)`,
## the Phase 187 behaviour). The record flies second, over warm ground, so the comparison does not favour
## the near ring. `tools/check_playtest_budget.py` gates the medians: `near_ms_per_attach` (collision and
## contents) at most FLIGHT_MAX_SHARE of `record_near_ms_per_attach`; the whole pump is report-only.
## Phase 190 — the near ring off also builds every chunk at full detail (`NearRing.lod_for`), so the record
## flight is the Phase 189 worker load too: each flight records its worker ms per local chunk crossing
## (`ChunkManager.worker_usec`), gated at FLIGHT_WORKER_MAX_SHARE of the record's.
func _step_flight() -> Array:
	var cm = _root._chunk_manager
	var home: Dictionary = _root._player.get_world_pos()
	var home_chunk: Vector2i = home["chunk"]
	var home_local: Vector3 = home["local"]
	var was_flying: bool = _root._player.flying
	var speed: float = _root._player.admin_speed_factor
	_step_restore = _restore_flight.bind(speed, was_flying, TickProbe.enabled)
	GameBus.admin_moves_synced.emit(speed, true)   # what `/fly` sends
	var gated := await _fly_east(home_chunk, home_local)
	var settled := await _return_home(home_chunk, home_local)
	if not settled:
		# a record flight launched from the wrong place would be meaningless: fail the step (the runner restores)
		return [false, "the start chunk never rebuilt after the gated flight"]
	cm.set_near_ring_enabled(false)
	var record := await _fly_east(home_chunk, home_local)
	_step_restore.call()   # the body walks home: the runner's call after the step finds nothing left to put back
	settled = await _return_home(home_chunk, home_local) and settled
	_flight = flight_verdict(gated["under"], gated["ring"])
	_flight["speed_mps"] = _flight_speed()
	_flight["attached"] = gated["attached"]
	_flight["main_ms_per_attach"] = gated["ms_per_attach"]
	_flight["record_attached"] = record["attached"]
	_flight["record_ms_per_attach"] = record["ms_per_attach"]
	_flight["near_ms_per_attach"] = gated["near_ms_per_attach"]
	_flight["record_near_ms_per_attach"] = record["near_ms_per_attach"]
	_flight["phases_ms_per_attach"] = gated["phases"]
	_flight["record_phases_ms_per_attach"] = record["phases"]
	_flight["crossings"] = gated["crossings"]
	_flight["record_crossings"] = record["crossings"]
	_flight["worker_ms_per_crossing"] = gated["worker_ms_per_crossing"]
	_flight["record_worker_ms_per_crossing"] = record["worker_ms_per_crossing"]
	var note := "%.0f m/s for %.0f s: ground under the body built in %.0f%% of %d samples, 3×3 ring %.0f%% (worst %.0f%%); main thread %.1f ms per attached chunk (%d chunks), %.1f ms with the near ring off (%d chunks); collision and contents %.1f ms, %.1f ms with it off; worker %.0f ms per crossing, %.0f ms with coarse chunks off" % [
		_flight_speed(), FLIGHT_SECS, 100.0 * float(_flight["under_cover"]), int(_flight["samples"]),
		100.0 * float(_flight["ring_cover"]), 100.0 * float(_flight["worst_ring"]),
		float(gated["ms_per_attach"]), int(gated["attached"]), float(record["ms_per_attach"]), int(record["attached"]),
		float(gated["near_ms_per_attach"]), float(record["near_ms_per_attach"]),
		float(gated["worker_ms_per_crossing"]), float(record["worker_ms_per_crossing"])]
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
	var worker0: int = cm.worker_usec
	var crossings0: int = cm.local_crossings
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
		var x := x0 + _flight_speed() * secs
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
			if not cm._near.enabled and only_from_args(Array(OS.get_cmdline_user_args()), ABORT_ARG) == "flight":
				print("[Playtest] %s flight: the step hangs here, flying, near ring off, TickProbe on" % ABORT_ARG)
				while true:
					await get_tree().process_frame
			TickProbe.take_times()
			attached0 = cm.builds_attached
			worker0 = cm.worker_usec
			crossings0 = cm.local_crossings
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
	var crossings: int = cm.local_crossings - crossings0
	return { "under": under, "ring": ring, "attached": attached, "crossings": crossings,
		"worker_ms_per_crossing": float(cm.worker_usec - worker0) / 1000.0 / float(crossings) if crossings > 0 else 0.0,
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

## True once the body is within crafting reach of a `station_type`. When it is not, the body is walked (a
## teleport) to station `station_id`. Returns whether it is in reach after that.
func _reach_station(station_type: String, station_id: String) -> bool:
	var radius: float = _root._crafting.STATION_RADIUS
	if _root._station.station_near_player(station_type, radius):
		return true
	var m := WorldPos.CHUNK_METERS
	var at: Vector3 = _root._station.get_station(station_id)["position"]
	var chunk := Vector2i(floori(at.x / m), floori(at.z / m))
	# Stand just above the station itself, not the generated ground under it: the aimed block can be a canopy
	# or a ledge well above the ground, and a body dropped on the ground would still be out of reach.
	var spot := WorldPos.normalized({ "chunk": chunk, "local": Vector3(at.x - float(chunk.x) * m, at.y + 1.5, at.z - float(chunk.y) * m) })
	GameBus.player_teleport.emit(spot)
	_skip_until_ms = Time.get_ticks_msec() + TELEPORT_SETTLE_MS
	await _until(func(): return false, 1.0)   # the body settles
	return _root._station.station_near_player(station_type, radius)

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
	if not await _reach_station("carpentry bench", str(_placed.back()[0])):
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

## Phase 181: the first step. A fresh save offers the creation screen; the bot picks a seeded random look, types
## a name, saves the screenshot of the screen and enters the world. The host records the creation and the screen
## closes, so every later step plays a created character.
func _step_create() -> Array:
	var ui: Node = _root._ui
	if not await _until(func(): return ui.is_creation_open(), 10.0):
		return [false, "the creation screen was not offered on a fresh save"]
	var screen: Control = ui.creation_screen
	screen.randomize_choice(WORLD_SEED)
	screen.set_name_text(CREATE_NAME)
	await _until(func(): return false, 0.5)
	await _screenshot("create")
	var rig := bool(screen.has_rig())
	screen.submit()
	var closed: bool = await _until(func(): return not ui.is_creation_open(), 5.0)
	var state: Dictionary = _root._registry.creation_of(_root._registry.local_player_id)
	var ok: bool = closed and rig and str(state.get("state", "")) == "created" and str(state.get("name", "")) == CREATE_NAME \
		and not _root._player.creation_hold
	return [ok, "created %s (%s, %s, colour %d); screen %s, rig %s" % [str(state.get("name", "?")), str(state.get("gender", "?")),
		str(state.get("hair", "?")), int(state.get("hairColor", -1)), "closed" if closed else "STILL OPEN: " + str(screen.error_text()), str(rig)]]

## Phase 179: open the Character window, check every attribute and slot is listed and the doll holds a rig, and (on
## a display) that the doll's viewport is not blank. The step's screenshot shows the sheet.
func _step_character_sheet() -> Array:
	var ui: Node = _root._ui
	# Phase 214 — the sheet is two windows, opened by the player's own keys: Alt+A (Attributes), Alt+Q (Equipment).
	# (A run of this step alone still has the creation screen up, which swallows keys: open them directly then.)
	if ui.is_creation_open():
		ui.open_window(ui.WINDOW_ATTRIBUTES)
		ui.open_window(ui.WINDOW_EQUIPMENT)
	else:
		# Keys toggle: press only for a window that is not already open.
		if not ui.is_window_open(ui.WINDOW_ATTRIBUTES):
			_alt_key(KEY_A)
		if not ui.is_window_open(ui.WINDOW_EQUIPMENT):
			_alt_key(KEY_Q)
	await _until(func(): return false, 0.5)
	if not ui.is_window_open(ui.WINDOW_ATTRIBUTES) or not ui.is_window_open(ui.WINDOW_EQUIPMENT):
		return [false, "Alt+A / Alt+Q did not open Attributes (%s) and Equipment (%s) " % [str(ui.is_window_open(ui.WINDOW_ATTRIBUTES)), str(ui.is_window_open(ui.WINDOW_EQUIPMENT))]]
	ui.refresh_character()
	var rows: Array = ui.character_sheet_rows()
	var attrs := rows.filter(func(r): return str(r["section"]) == "attribute").size()
	var slots := rows.filter(func(r): return str(r["section"]) == "slot").size()
	var doll = ui._sheet_doll
	if attrs != 6 or slots == 0 or doll == null or not doll.has_rig():
		return [false, "sheet incomplete: %d attributes, %d slots, rig %s" % [attrs, slots, str(doll != null and doll.has_rig())]]
	if DisplayServer.get_name() == "headless":
		return [true, "%d attributes, %d slots, doll rig built (headless: viewport not read)" % [attrs, slots]]
	await _until(func(): return false, 0.3)
	var img: Image = doll.viewport.get_texture().get_image()
	var seen := {}
	if img != null:
		for y in range(0, img.get_height(), 4):
			for x in range(0, img.get_width(), 4):
				seen[img.get_pixel(x, y).to_html()] = true
	var ok := seen.size() > 3
	return [ok, "%d attributes, %d slots, doll viewport %d colours" % [attrs, slots, seen.size()]]

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
	# Phase 195 — the body is laid where the player stands at the kill, and the host range-checks the harvest
	# against it. The bot no longer rewrites the carcass's position (#493): it lets the body come to rest
	# (a fall after the fight step's teleport, a rebase) before the kill instead.
	await _hold_still(3.0)
	var before: int = slice.count()
	GameBus.creature_died.emit(creature_key, _root._player.get_position(), "player", Vector3.ZERO)
	if slice.count() != before + 1:
		return [false, "a kill left no carcass"]
	var cid: String = slice.ids().back()
	slice.pin_entry_chances(cid, 1.0)
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
		var seen := verdict.size()
		GameBus.harvest_intent.emit(cid, "")
		await _until(func(): return verdict.size() > seen, left)
		for item in held_before:
			if _root._inventory.get_item_count(str(item)) > int(held_before[item]):
				got.append(item)
		# A cancelled try is retried, and so is "out_of_range" (#531): the body can still be settling when the
		# first try is judged, and the next try starts only after `_hold_still`. A refusal that repeats on every
		# try is still a failure the step reports.
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

## Phase 186 — the tutorial ran beside the session. The windows the earlier steps did not open are opened with the
## player's own windows keys' targets, then the events the tutorial saw are replayed: the moving, gathering,
## first-tools, first-stations and first-hunt chapters must all complete. The screenshot shows a card.
const TUTORIAL_CHAPTERS := ["moving", "gathering", "first_stations", "first_tools", "first_hunt"]

## Hold the right button over the middle of the view and drag: the camera orbits as a player's look does.
func _look_around() -> void:
	var at: Vector2 = get_viewport().get_visible_rect().size * 0.5
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = at
	Input.parse_input_event(press)
	for _i in 10:   # 400 px: about 46°, past the tutorial's 30°
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(40.0, 0.0)
		motion.position = at
		Input.parse_input_event(motion)
	var release := press.duplicate()
	release.pressed = false
	Input.parse_input_event(release)

func _step_tutorial() -> Array:
	var wiring = _root._tutorial_wiring
	if wiring.slice == null:
		return [false, "no tutorial slice"]
	# What the earlier steps never do, done the player's way: a jump, a look around with the right button held,
	# smithing researched and a pick crafted at the place step's forge.
	_key(KEY_SPACE, true)
	await _until(func(): return false, 0.3)
	_key(KEY_SPACE, false)
	_look_around()
	await _until(func(): return false, 0.2)
	var tech: String = await _unlock("TechBasicSmithing")
	if tech != "":
		return [false, "research: %s" % tech]
	var forge := ""
	for p in _placed:
		if str(p[1]) == "forge":
			forge = str(p[0])
	if forge == "" or not await _reach_station("forge", forge):
		return [false, "no forge in reach for the pick"]
	_root._inventory.add_item("FerriteIngot", 2)
	_root._inventory.add_item("ThornwoodPlank", 1)
	_root._crafting.set_skill("Smithing", "novice")
	var crafted := _crafted.size()
	GameBus.craft_requested.emit("RecipeFerritePick")
	if not await _until(func(): return _crafted.size() > crafted, STEP_TIMEOUT_SECS) or not bool(_crafted.back().get("success", false)):
		return [false, "pick craft: %s" % (str(_crafted.back().get("reason", "")) if _crafted.size() > crafted else "no craft_resolved")]
	var ui: Node = _root._ui
	for w in ["controls", "inventory", "technology", "crafting"]:
		ui.open_window(w)
	ui.hotbar.assign(0, "Thornwood")   # a box filled by hand, as a drag from the pack does
	# The fight step wounds the sturdiest creature and harvests a carcass but never kills it (1989 hp); the death of
	# a creature the player killed arrives on the same bus signal a real kill uses.
	GameBus.creature_died.emit("playtest_target", _root._player.get_position(), _root._registry.local_player_id, Vector3.ZERO)
	await _until(func(): return false, 0.3)
	for w in ["controls", "inventory", "technology", "crafting"]:
		ui.close_window(w)
	var done: Array = wiring.Rules.replay(wiring.slice.history, wiring.slice.steps())
	var state := { "enabled": true, "done": done, "dismissed": [] }
	var missing := []
	for c in TUTORIAL_CHAPTERS:
		if not wiring.Rules.chapter_done(state, c, wiring.slice.steps()):
			missing.append(c)
	var kinds := {}
	for ev in wiring.slice.history:
		kinds[str(ev["kind"])] = int(kinds.get(str(ev["kind"]), 0)) + 1
	print("[Playtest] tutorial events: ", kinds)
	var open_steps := []
	for s in wiring.slice.steps():
		if TUTORIAL_CHAPTERS.has(str(s["chapter"])) and not done.has(str(s["id"])):
			open_steps.append(str(s["id"]))
	wiring.slice.restart()   # a card to photograph: the session starts the tutorial over
	await _until(func(): return wiring.card != null and wiring.card.visible, 1.0)
	var ok: bool = missing.is_empty() and wiring.card != null and wiring.card.visible
	return [ok, "%d steps completed by the session; chapters missing: %s; open steps: %s" % [done.size(), str(missing), str(open_steps)]]

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

## Phase 216 — mount: a wolf stood beside the player and bound to them as a taming leaves it is mounted through the
## intent, ridden 200 m and dismounted. The mounted average speed must reach the fabric factor times the walking
## speed x0.9 (the Phase 216 spec). The rider is kept at full health (creatures near the village would otherwise end the ride in a death).
const MOUNT_RIDE_M := 200.0
const MOUNT_RIDE_SECS := 45.0
const MOUNT_SPEED_SLACK := 0.9
func _step_mount() -> Array:
	var me: String = str(_root._registry.local_player_id)
	var chunk: Vector2i = _root._player.get_world_pos()["chunk"]
	var iid: String = _root._creature._spawn("GraywolfPack", chunk, 98)
	if iid == "" or not _root._creature.mark_tamed(iid, me):
		return [false, "no wolf to tame"]
	_root._creature.set_instance_position(iid, _player_pos())
	var factor: float = float(_root._mount_wiring.slice.spec_of_creature("GraywolfPack").get("speedFactor", 0.0))
	GameBus.mount_intent.emit(iid, "")
	if not await _until(func(): return _root._mount_wiring.slice.is_mounted(me), STEP_TIMEOUT_SECS * 0.25):
		return [false, "the host did not mount the wolf"]
	await _until(func(): return false, 1.0)   # the body settles after the mount; the start is read after it
	_key(KEY_W, true)
	await _until(func(): return false, 0.5)   # up to speed before the clock starts
	var start: Dictionary = _root._player.get_world_pos()
	var t0 := Time.get_ticks_msec()
	# Cruising speed: the median of the speeds over 0.5 s legs that moved (a tree or a ledge on the line stalls a leg,
	# and the ride is judged on how fast the mount goes, not on the terrain between the two points).
	var legs: Array = []
	# Legs are timed on the physics clock: under the software-rendered fallback the frame rate drops and physics
	# runs slower than the wall clock, which would read as a slow mount.
	var tps := float(Engine.physics_ticks_per_second)
	var last := [_root._player.get_world_pos(), Engine.get_physics_frames()]
	var throws := [0]   # an Array: a lambda captures an int by value, so += 1 inside it was never seen here
	# Path ridden on the mounted legs, the same way. The ride is judged on it, not on the straight line from the
	# start: each stall on a tree turns the wolf 0.9 rad, and on PR #563's CI run the straight-line distance
	# reached 173 m in 45 s while the wolf cruised at 9.3 m/s.
	var ridden := [0.0]
	# Who threw the rider, for the report: a landed hit on the wolf ends the ride (Phase 216 spec).
	var hitters := {}
	var on_hit := func(attacker: String, defender: String, outcome: String, damage: float) -> void:
		if defender == iid and outcome != "miss" and damage > 0.0:
			hitters[attacker] = int(hitters.get(attacker, 0)) + 1
	GameBus.combat_hit_resolved.connect(on_hit)
	# Why the host put the rider on foot or refused a remount, for the report.
	var answers := {}
	var on_resolved := func(pid: String, action: String, ok: bool, reason: String) -> void:
		if pid == me:
			var k := "%s:%s" % [action, "ok" if ok else reason]
			answers[k] = int(answers.get(k, 0)) + 1
	GameBus.mount_resolved.connect(on_resolved)
	var was_on := [true]
	var rode: bool = await _until(func():
		_root._player.set_hp(PlayerSlice.MAX_HP)
		var now_ms := Engine.get_physics_frames()
		if not _root._mount_wiring.slice.is_mounted(me):
			# A creature hit the wolf and threw the rider (Phase 216 spec): get back on, and drop the leg that
			# was on foot so the cruising speed is judged on the mounted legs only.
			if bool(was_on[0]):
				throws[0] = int(throws[0]) + 1
			was_on[0] = false
			# The wolf may have been knocked or wandered off while the rider was on foot: stand it beside
			# them again, or the remount is refused as too_far.
			_root._creature.set_instance_position(iid, _player_pos())
			GameBus.mount_intent.emit(iid, "")
			last[0] = _root._player.get_world_pos()
			last[1] = now_ms
		elif not bool(was_on[0]):
			was_on[0] = true
			last[0] = _root._player.get_world_pos()
			last[1] = now_ms
		elif float(now_ms - int(last[1])) / tps >= 0.5:
			var here: Dictionary = _root._player.get_world_pos()
			var leg: float = WaystoneSlice.distance_m(here, last[0]) / (float(now_ms - int(last[1])) / tps)
			legs.append(leg)
			ridden[0] = float(ridden[0]) + WaystoneSlice.distance_m(here, last[0])
			if leg < 1.0:
				_root._player._pivot.rotate_y(0.9)   # stalled on a tree or a ledge: turn and go on
			last[0] = here
			last[1] = now_ms
		return float(ridden[0]) >= MOUNT_RIDE_M, MOUNT_RIDE_SECS)
	_key(KEY_W, false)
	GameBus.combat_hit_resolved.disconnect(on_hit)
	GameBus.mount_resolved.disconnect(on_resolved)
	var metres: float = WaystoneSlice.distance_m(_root._player.get_world_pos(), start)
	var moving: Array = legs.filter(func(v: float) -> bool: return v >= 1.0)
	moving.sort()
	var avg: float = float(moving[moving.size() / 2]) if not moving.is_empty() else 0.0
	GameBus.dismount_intent.emit("")
	var off: bool = await _until(func(): return not _root._mount_wiring.slice.is_mounted(me), STEP_TIMEOUT_SECS * 0.25)
	var need := factor * PlayerSlice.SPEED * MOUNT_SPEED_SLACK
	var ok: bool = rode and off and factor > 1.0 and avg >= need and float(ridden[0]) < MOUNT_RIDE_M * 2.0
	return [ok, "rode %.0f m (%.0f m from the start), cruising at %.1f m/s (need %.1f), dismounted %s, thrown %d times by %s, host answers %s" % [float(ridden[0]), metres, avg, need, str(off), int(throws[0]), str(hitters), str(answers)]]

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

## Phase 165 — a vantage `FAR_PEAK_DISTANCE_M` from a tall ridge: of the seed's strongest massif summits
## (Phase 211), each crest at least `FAR_PEAK_MIN_HEIGHT` tall, the first `FAR_PEAK_CANDIDATES` with a dry-land
## bearing (of sixteen) below `FAR_PEAK_VANTAGE_MAX_M`, and of each the most open sight line to the crest
## (`ridge_clearance`); most open first. Returns a list of [vantage, bearing_to_peak_deg, peak, peak_height,
## clearance], empty when none.
func _find_far_peak() -> Array:
	var seed_v: int = _root._terrain.get_world_seed()
	var w := Horizon.default_circumference()
	var sea := WorldShape.sea_level()
	var peaks: Array = []   # [strength, crest, height] of the strongest summits whose crest is tall enough
	await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	for sm in WorldShape.massif_summits(seed_v, w, FAR_PEAK_CANDIDATES * 2):
		var hit: Array = WorldShape.highest_near(seed_v, sm[1], w, FAR_PEAK_SUMMIT_RADIUS_M, FAR_PEAK_SUMMIT_STEP_M)
		if float(hit[0]) >= FAR_PEAK_MIN_HEIGHT:
			peaks.append([sm[0], hit[1], hit[0]])
		if Time.get_ticks_msec() - t0 > COAST_WORK_MS:
			await get_tree().process_frame
			t0 = Time.get_ticks_msec()
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
			if vh > sea + 3.0 and vh < FAR_PEAK_VANTAGE_MAX_M:
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
	# Phase 211 — the summits are the planet's, not the body's surroundings, so one search serves every try.
	var tried_peaks: Array = []
	var fails: Array = []
	for v in await _find_far_peak():
		if tried_peaks.size() >= FAR_PEAK_MAX_TRIES:
			break
		if tried_peaks.any(func(p): return (p as Vector2).distance_to(v[2]) < FAR_PEAK_SAME_RIDGE_M):
			continue
		tried_peaks.append(v[2])
		var res: Array = await _far_peak_attempt(v, player)
		print("[Playtest] far_peak try %d: %s" % [tried_peaks.size(), res[1]])
		if res[0]:
			return [true, "%s (try %d)" % [res[1], tried_peaks.size()]]
		fails.append(res[1])
	if fails.is_empty():
		return [false, "no massif summit of %.0f m with dry land under %.0f m %.0f km from it" % [FAR_PEAK_MIN_HEIGHT, FAR_PEAK_VANTAGE_MAX_M, FAR_PEAK_DISTANCE_M / 1000.0]]
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
	# Phase 195 — the pass needs rock or snow, not any band pixel (#444): a near hill drawn by the bands also
	# rises above the ring. The tallest ridge on the seed is only ~350 m and partly grass, so the rock/snow
	# pixels need only be a share (`FAR_PEAK_MIN_ROCK_SHARE`) of the band pixels, and at least `FAR_PEAK_MIN_PX`.
	var px := rock_pixels_above(all_img, rows, SKYLINE_KEY, 0.08, true)
	var rock_px := rock_pixels_above(all_img, rows, SKYLINE_KEY)
	var holes := hole_pixels(all_img, rows, SKYLINE_KEY)
	var rock_ok := far_peak_passes(px, rock_px) and holes <= FAR_PEAK_MAX_HOLE_PX
	var worst_ms := 0.0
	for f in _frames:
		worst_ms = maxf(worst_ms, float(f))
	var detail := "ridge %.0f m at %.0f km, bearing %.0f°: %d band px above the ring's skyline, %d of them rock/snow (need %d and %.0f%%), %d hole px (at most %d), worst frame %.0f ms" % [
		float(found[3]), Vector2(spot_xz).distance_to(Vector2(found[2])) / 1000.0, bearing, px, rock_px, FAR_PEAK_MIN_PX, FAR_PEAK_MIN_ROCK_SHARE * 100.0, holes, FAR_PEAK_MAX_HOLE_PX, worst_ms]
	return [rock_ok, detail]

## Phase 195 — the far-peak verdict from the band pixels above the ring's skyline (`band_px`) and how many of
## them are rock or snow (`rock_px`). Pure, so the suite pins it.
static func far_peak_passes(band_px: int, rock_px: int) -> bool:
	return rock_px >= FAR_PEAK_MIN_PX and float(rock_px) >= float(band_px) * FAR_PEAK_MIN_ROCK_SHARE

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

# ---------------------------------------------------------------------------
# Phase 213 — a clan's tower on a mountain: the arc, played
# ---------------------------------------------------------------------------

## Phase 213 — a creature spawn or respawn the host admitted: counted, and recorded when its spawn point lies inside
## a structure's circle (`StructureSlice.spawn_blocked`), which no wild spawn may.
func _note_spawn(iid: String) -> void:
	if _root == null or _root._structures == null or _root._creature == null:
		return
	var inst: Dictionary = _root._creature._instances.get(iid, {})
	var at: Variant = inst.get("spawn_exact", null)
	if not (at is Dictionary):
		return
	var m := WorldPos.CHUNK_METERS
	var xz := Vector2(float(at["chunk"].x) * m + at["local"].x, float(at["chunk"].y) * m + at["local"].z)
	_spawns_seen += 1
	if _root._structures.spawn_blocked(xz):
		_circle_spawns.append("%s at (%.0f, %.0f)" % [str(inst.get("creature_id", iid)), xz.x, xz.y])

## The exact point at the middle of world tile `tile`, `y` metres up, as { chunk, local }.
static func tile_exact(tile: Vector2i, y: float) -> Dictionary:
	var cs := VoxelSlice.CHUNK_SIZE
	var chunk := Vector2i(floori(float(tile.x) / float(cs)), floori(float(tile.y) / float(cs)))
	return { "chunk": chunk, "local": Vector3((float(tile.x - chunk.x * cs) + 0.5) * VoxelSlice.TILE_SIZE, y,
		(float(tile.y - chunk.y * cs) + 0.5) * VoxelSlice.TILE_SIZE) }

static func _exact_xyz(exact: Dictionary) -> Vector3:
	var m := WorldPos.CHUNK_METERS
	var l: Vector3 = exact["local"]
	return Vector3(float(exact["chunk"].x) * m + l.x, l.y, float(exact["chunk"].y) * m + l.z)

## The world tile under the ground point `xz`.
static func tile_of(xz: Vector2) -> Vector2i:
	return Vector2i(floori(xz.x / VoxelSlice.TILE_SIZE), floori(xz.y / VoxelSlice.TILE_SIZE))

## The tiles of a tower footprint at `corner`: `side` + 1 columns along x (the last is the higher class's row) by
## `side` along z.
static func tower_tiles(corner: Vector2i, side: int) -> Array:
	var out: Array = []
	for x in side + 1:
		for z in side:
			out.append(corner + Vector2i(x, z))
	return out

## Place `material` on top of `tile`'s column with the player's own intent (a top-face click). "" when the column
## rose by the block, else the host's refusal reason ("not placed" when it gave none).
func _place_top(tile: Vector2i, material: String) -> String:
	var v = _root._voxel
	var top: float = v.column_top_at_tile(tile)
	var exact := tile_exact(tile, top)
	var before := _structure_refusals.size()
	GameBus.block_place_requested.emit(_exact_xyz(exact), Vector3.UP, "", material, exact)
	if float(v.column_top_at_tile(tile)) > top + 0.001:
		return ""
	for i in range(_structure_refusals.size() - 1, before - 1, -1):
		if str(_structure_refusals[i]) != "":
			return str(_structure_refusals[i])
	return "not placed"

## Mine the top block of `tile`'s column with the player's own intent. Whether the column went down.
func _mine_top(tile: Vector2i) -> bool:
	var v = _root._voxel
	var top: float = v.column_top_at_tile(tile)
	var exact := tile_exact(tile, top)
	GameBus.block_mine_requested.emit(_exact_xyz(exact), Vector3.UP, "", exact)
	return float(v.column_top_at_tile(tile)) < top - 0.001

## Phase 213 — the arc, played. Beside home the bot founds a clan and builds as it, dismantles fresh blocks for half
## their material (at Building level 0, before any of the step's work grows it), flattens a footprint and raises a
## 5 × 5 wood tower to the top of floor 2: the next block, on floor 3, is refused. It then raises a concrete row
## beside it to floor TOWER_HIGH_FLOORS, sets a chest to owner-only, reads a book, kills its character to respawn and
## flies to a peak of at least TOWER_PEAK_MIN_M, screenshotting the tower and the peak. Last in the run, it also
## checks that no creature spawned inside a structure's circle in the session.
func _step_tower() -> Array:
	var notes: Array = []
	_tower_started_ms = Time.get_ticks_msec()
	var pid: String = _root._registry.local_player_id
	var inv: Node = _root._inventory
	var v = _root._voxel
	var player = _root._player
	var was_flying: bool = player.flying
	var speed: float = player.admin_speed_factor
	_step_restore = _restore_flight.bind(speed, was_flying, TickProbe.enabled)
	if was_flying:
		GameBus.admin_moves_synced.emit(speed, false)
	if _home.is_empty():
		return [false, "no home position was recorded after the boot"]
	if _root._ui.is_creation_open():   # `--playtest-only tower`: no create step ran, and the screen hides the views
		var created: Array = await _step_create()
		if not bool(created[0]):
			return [false, "create: %s" % str(created[1])]
	# The footprints lie within TOWER_OFFSET_M + 3 m of home: the 3 × 3 chunks round it hold them all.
	var ring_built := func() -> bool:
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if not _root._chunk_manager.is_chunk_built(_home["chunk"] + Vector2i(dx, dz)):
					return false
		return true
	# A body the earlier steps left down respawns near the origin, where a wolf pack can down it again, and a respawn
	# moves it off home whatever was teleported: until the chunks are built, put a living body back home, clear.
	var at_home := func() -> bool:
		if not player.is_alive():
			return false
		if player.get_world_pos()["chunk"] != _home["chunk"]:
			_teleport_to(_home["chunk"], _home["local"])
			_clear_creatures_near_body()
			return false
		return ring_built.call()
	if not await _until(at_home, STREAM_TIMEOUT_SECS):
		var cm = _root._chunk_manager
		var unbuilt: Array = []
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var c: Vector2i = _home["chunk"] + Vector2i(dx, dz)
				if not cm.is_chunk_built(c):
					unbuilt.append(str(c))
		return [false, "the chunks round home never built (home %s, body at %s; unbuilt %s; load %d, builds %d, rebuild %d)" % [
			str(_home["chunk"]), str(player.get_world_pos()["chunk"]), ", ".join(unbuilt), cm._load_queue.size(), cm._builds.size(), cm._rebuild_queue.size()]]
	_teleport_to(_home["chunk"], _home["local"])
	await _until(func(): return false, 1.0)   # the body settles
	_clear_creatures_near_body()
	inv.replace_contents({})   # no pick to wear out, and room for the step's materials

	# A clan, and everything built from now on is its.
	GameBus.clan_intent.emit("found", { "name": TOWER_CLAN }, pid)
	if not await _until(func(): return _root._clans.clan_of(pid) != "", 5.0):
		return [false, "the clan was not founded"]
	var clan: String = _root._clans.clan_of(pid)
	GameBus.chat_intent.emit("/%s clan" % ChatCommands.BUILDAS_NAME, "")
	if not await _until(func(): return str(_root._structures.build_mode(pid)) == "clan", 5.0):
		return [false, "/buildas clan left the build mode %s" % str(_root._structures.build_mode(pid))]
	notes.append("founded %s" % TOWER_CLAN)
	_tower_note(notes)

	# The flattest footprint on a ring round home (natural ground, in a built chunk).
	var home_xz := Vector2(float(_home["chunk"].x) * WorldPos.CHUNK_METERS + _home["local"].x, float(_home["chunk"].y) * WorldPos.CHUNK_METERS + _home["local"].z)
	# A chunk being rebuilt reads as unbuilt for a moment: scan again until one candidate is whole. (A lambda
	# captures locals by value, so the scan keeps its best in a dictionary.)
	var best := { "spread": INF, "corner": Vector2i.ZERO }
	var scan := func() -> bool:
		best["spread"] = INF
		for b in TOWER_BEARINGS:
			var c := tile_of(home_xz + Vector2.from_angle(TAU * float(b) / float(TOWER_BEARINGS)) * TOWER_OFFSET_M)
			var lo := INF
			var hi := -INF
			var built := true
			for t: Vector2i in tower_tiles(c, TOWER_SIDE):
				var chunk := Vector2i(floori(float(t.x) / float(VoxelSlice.CHUNK_SIZE)), floori(float(t.y) / float(VoxelSlice.CHUNK_SIZE)))
				built = built and _root._chunk_manager.is_chunk_built(chunk)
				var top: float = v.column_top_at_tile(t)
				lo = minf(lo, top)
				hi = maxf(hi, top)
			if built and hi - lo < float(best["spread"]):
				best["spread"] = hi - lo
				best["corner"] = c
		return float(best["spread"]) <= TOWER_MAX_SPREAD_M
	await _until(scan, 30.0)
	var spread: float = best["spread"]
	var corner: Vector2i = best["corner"]
	if spread > TOWER_MAX_SPREAD_M:
		return [false, "no footprint near home within %.1f m of level (flattest %.2f m)" % [TOWER_MAX_SPREAD_M, spread]]
	var tiles := tower_tiles(corner, TOWER_SIDE)

	# Fresh blocks dismantled at Building level 0 come back at half: two blocks, one back.
	var level: int = _root._structures._level_of(pid)
	var share: float = StructureRules.dismantle_share(1.0, level)
	var probe: Vector2i = tiles[0]
	inv.add_item(TOWER_WOOD, TOWER_DISMANTLE_BLOCKS)
	for i in TOWER_DISMANTLE_BLOCKS:
		var why := _place_top(probe, TOWER_WOOD)
		if why != "":
			return [false, "a block to dismantle was refused: %s" % why]
	var sid: int = _root._structures.structure_at(probe, v.column_top_at_tile(probe) - VoxelSlice.STEP_HEIGHT * 0.5)
	var owned: Dictionary = _root._structures.get_structure(sid) if sid != 0 else {}
	if str(owned.get("kind", "")) != "clan" or str(owned.get("owner", "")) != clan:
		return [false, "the first block is not the clan's (%s %s)" % [str(owned.get("kind", "none")), str(owned.get("owner", ""))]]
	var wood_before: int = inv.get_item_count(TOWER_WOOD)
	for i in TOWER_DISMANTLE_BLOCKS:
		if not _mine_top(probe):
			return [false, "dismantling block %d failed" % (i + 1)]
	var returned: int = inv.get_item_count(TOWER_WOOD) - wood_before
	var expect := floori(float(TOWER_DISMANTLE_BLOCKS) * share + 0.000001)
	# The share is whatever the rules give at the bot's level; the half-back check holds only at level 0 (an
	# earlier step that grows Building moves the share, which is not this step's failure).
	if level == 0 and expect * 2 != TOWER_DISMANTLE_BLOCKS:
		return [false, "at Building level 0 the dismantle share is %.2f, not a half" % share]
	if returned != expect:
		return [false, "dismantled %d fresh blocks at Building level %d (share %.2f): %d came back, %d expected" % [
			TOWER_DISMANTLE_BLOCKS, level, share, returned, expect]]
	notes.append("dismantled %d fresh blocks for %d (%.0f%%, Building level %d)" % [TOWER_DISMANTLE_BLOCKS, returned, 100.0 * share, level])
	_tower_note(notes)

	# Level the footprint: mine every column down to the lowest one.
	var ground := INF
	for t: Vector2i in tiles:
		ground = minf(ground, v.column_top_at_tile(t))
	var mined := 0
	for t: Vector2i in tiles:
		while float(v.column_top_at_tile(t)) > ground + 0.001:
			if not _mine_top(t):
				return [false, "the footprint could not be levelled at %s" % str(t)]
			mined += 1
		await get_tree().process_frame
	inv.replace_contents({})
	notes.append("levelled the footprint (spread %.2f m, %d blocks mined)" % [spread, mined])
	_tower_note(notes)

	# Wood, course by course, to the top of its last floor; the next block is refused.
	var per_floor: int = StructureLimits.floor_mm() / roundi(VoxelSlice.STEP_HEIGHT * 1000.0)
	var wood_floors: int = StructureLimits.max_floors(StructureLimits.rank_of(TOWER_WOOD))
	var wood_tiles := tiles.filter(func(t: Vector2i) -> bool: return t.x - corner.x < TOWER_SIDE)
	var high_tiles := tiles.filter(func(t: Vector2i) -> bool: return t.x - corner.x == TOWER_SIDE)
	for course in wood_floors * per_floor:
		if not inv.add_item(TOWER_WOOD, wood_tiles.size()):
			return [false, "the pack took no %s for course %d" % [TOWER_WOOD, course]]
		for t: Vector2i in wood_tiles:
			var why := _place_top(t, TOWER_WOOD)
			if why != "":
				return [false, "wood course %d (floor %d) refused at %s: %s" % [course, course / per_floor + 1, str(t), why]]
		await get_tree().process_frame
	var mid: Vector2i = corner + Vector2i(TOWER_SIDE / 2, TOWER_SIDE / 2)
	inv.add_item(TOWER_WOOD, 1)
	var refused_floor := StructureLimits.floor_of(roundi(float(v.column_top_at_tile(mid)) * 1000.0), roundi(ground * 1000.0))
	var refusal := _place_top(mid, TOWER_WOOD)
	if refusal != StructureLimits.TOO_MANY_FLOORS or refused_floor != wood_floors + 1:
		return [false, "a wood block on floor %d was %s, not refused as %s" % [refused_floor, "placed" if refusal == "" else "refused: " + refusal, StructureLimits.TOO_MANY_FLOORS]]
	notes.append("wood to floor %d (%d blocks), floor %d refused (%s)" % [wood_floors, wood_tiles.size() * wood_floors * per_floor, refused_floor, refusal])
	_tower_note(notes)

	# A higher class from the ground beside it, on past the wood's limit.
	for course in TOWER_HIGH_FLOORS * per_floor:
		if not inv.add_item(TOWER_HIGH, high_tiles.size()):
			return [false, "the pack took no %s for course %d" % [TOWER_HIGH, course]]
		for t: Vector2i in high_tiles:
			var why := _place_top(t, TOWER_HIGH)
			if why != "":
				return [false, "%s course %d (floor %d) refused at %s: %s" % [TOWER_HIGH, course, course / per_floor + 1, str(t), why]]
		await get_tree().process_frame
	var top_floor := StructureLimits.floor_of(roundi(float(v.column_top_at_tile(high_tiles[0]) - VoxelSlice.STEP_HEIGHT) * 1000.0), roundi(ground * 1000.0))
	var tower: Dictionary = _root._structures.get_structure(_root._structures.structure_at(high_tiles[0], ground + VoxelSlice.STEP_HEIGHT * 0.5))
	if top_floor != TOWER_HIGH_FLOORS or str(tower.get("owner", "")) != clan:
		return [false, "the %s row stopped on floor %d (owner %s)" % [TOWER_HIGH, top_floor, str(tower.get("owner", "none"))]]
	notes.append("%s on to floor %d; one clan structure of %d blocks" % [TOWER_HIGH, top_floor, int(tower.get("count", 0))])
	_tower_note(notes)

	# Stand west of the tower: a chest at the feet, set to owner-only.
	var west := Vector2((float(corner.x) - TOWER_VIEW_M / VoxelSlice.TILE_SIZE) * VoxelSlice.TILE_SIZE, (float(corner.y) + float(TOWER_SIDE) * 0.5) * VoxelSlice.TILE_SIZE)
	var west_chunk := Vector2i(floori(west.x / WorldPos.CHUNK_METERS), floori(west.y / WorldPos.CHUNK_METERS))
	_teleport_to(west_chunk, Vector3(west.x - float(west_chunk.x) * WorldPos.CHUNK_METERS, 0.0, west.y - float(west_chunk.y) * WorldPos.CHUNK_METERS))
	await _until(func(): return false, 1.0)
	var chest := await _place_chest()
	if chest[0] == "":
		return [false, "chest: %s" % chest[1]]
	var lock: Dictionary = _root._chests.get_lock(chest[0])
	if str(lock.get("mode", "")) != "owner":
		return [false, "the chest is in mode %s, not owner" % str(lock.get("mode", "?"))]
	notes.append("chest %s" % chest[1])
	_tower_note(notes)

	# A book read teaches what it holds.
	var book := ""
	for item: String in WritingRules.items():
		var w := WritingRules.of(item)
		var t: String = str(w["teaches"])
		if str(w["kind"]) == "technology" and not _root._technology.is_unlocked(t, pid) \
				and (_root._technology.get_tech_data(t).get("requires", []) as Array).all(func(r) -> bool: return _root._technology.is_unlocked(str(r), pid)):
			book = item
			break
	if book == "":
		return [false, "no book teaches a technology the bot could learn"]
	inv.add_item(book, 1)
	var reads := _writing_results.size()
	GameBus.writing_intent.emit("read", book, "")
	var taught := str(WritingRules.of(book)["teaches"])
	if _writing_results.size() == reads or str(_writing_results.back()[2]) != "" or not _root._technology.is_unlocked(taught, pid) or inv.get_item_count(book) != 1:
		return [false, "reading %s: %s" % [book, str(_writing_results.back()[2]) if _writing_results.size() > reads else "no writing_resolved"]]
	notes.append("read %s (learnt %s, kept it)" % [book, taught])
	_tower_note(notes)

	# The tower, from the west.
	var pivot: Node3D = player._pivot
	var arm: Node3D = player._cam_arm
	var old_pitch := arm.rotation_degrees.x
	pivot.global_rotation.y = -PI * 0.5   # facing +x
	arm.rotation_degrees.x = 10.0
	await _until(func(): return false, 1.0)
	await _screenshot("tower")
	arm.rotation_degrees.x = old_pitch

	# A way out: kill the character and come back at the bed or the world spawn.
	var respawns := _respawns
	GameBus.chat_intent.emit("/%s" % ChatCommands.RESPAWN_NAME, "")
	if not await _until(func(): return not player.is_alive(), 5.0):
		return [false, "/respawn did not kill the character"]
	if not await _until(func(): return _respawns > respawns and player.is_alive(), PlayerRules.RESPAWN_DELAY + 15.0):
		return [false, "the character did not respawn"]
	notes.append("respawned")
	_tower_note(notes)

	# Fly to the tallest summit of the strongest massifs.
	var peak := await _find_peak()
	if peak.is_empty():
		return [false, "no massif summit of %.0f m" % TOWER_PEAK_MIN_M]
	GameBus.admin_moves_synced.emit(speed, true)   # what `/fly` sends
	var pxz: Vector2 = peak[1]
	var pchunk := Vector2i(floori(pxz.x / WorldPos.CHUNK_METERS), floori(pxz.y / WorldPos.CHUNK_METERS))
	var plocal := Vector3(pxz.x - float(pchunk.x) * WorldPos.CHUNK_METERS, 0.0, pxz.y - float(pchunk.y) * WorldPos.CHUNK_METERS)
	_teleport_to(pchunk, plocal)
	if not await _until(func(): return _root._chunk_manager.is_chunk_built(pchunk), STREAM_TIMEOUT_SECS):
		return [false, "the summit chunk never built"]
	_teleport_to(pchunk, plocal)
	await _until(func(): return false, 1.5)
	var ground_m: float = v.get_voxel_height_at(pxz)
	var body_m: float = float(player.get_world_pos()["local"].y)
	if ground_m < TOWER_PEAK_MIN_M or body_m < ground_m - 1.0:
		return [false, "at the summit the ground is %.0f m and the body %.0f m (need %.0f m)" % [ground_m, body_m, TOWER_PEAK_MIN_M]]
	pivot.global_rotation.y = 0.0
	await _until(func(): return false, 1.0)
	await _screenshot("tower_peak")
	notes.append("flew to a %.0f m peak (body at %.0f m)" % [ground_m, body_m])
	_tower_note(notes)

	notes.append("%d creature spawns in the session, %d inside a circle" % [_spawns_seen, _circle_spawns.size()])
	_tower_note(notes)
	if not _circle_spawns.is_empty():
		return [false, "; ".join(notes) + ": " + ", ".join(_circle_spawns.slice(0, 5))]
	return [true, "; ".join(notes)]

## Print the tower step's latest note with the step's wall time so far: a slow or hung phase shows in the log.
func _tower_note(notes: Array) -> void:
	print("[Playtest] tower %.1f s: %s" % [float(Time.get_ticks_msec() - _tower_started_ms) / 1000.0, str(notes.back())])

## Place a chest beside the body with the player's own intent, open it and set it to clan, then owner-only.
## [id, note], or ["", why] when it failed.
func _place_chest() -> Array:
	_root._inventory.add_item(ChestRules.placement_item("chest"), 1)
	var here := _player_pos()
	var off := Vector3.ZERO
	for b in 8:
		var d := Vector3(cos(TAU * float(b) / 8.0), 0.0, sin(TAU * float(b) / 8.0)) * 1.5 + Vector3(0.0, -0.4, 0.0)
		if _root._station.placement_blocker("chest", _root._station.snap_to_grid(here + d), _root._registry.local_player_id) == "":
			off = d
			break
	if off == Vector3.ZERO:
		return ["", "no free spot round the body"]
	var placed := _placed.size()
	var results := _chest_results.size()
	GameBus.chest_intent.emit("place", { "type": "chest", "ox": off.x, "oy": off.y, "oz": off.z }, "")
	if _placed.size() == placed:
		return ["", "placement refused (%s)" % (str(_chest_results.back()[1]) if _chest_results.size() > results else "no reply")]
	var id := str(_placed.back()[0])
	for row: Array in [["use", {}], ["mode", { "mode": "clan" }], ["mode", { "mode": "owner" }], ["close", {}]]:
		var n := _chest_results.size()
		GameBus.chest_intent.emit(str(row[0]), row[1], "")
		if _chest_results.size() == n or str(_chest_results.back()[1]) != "":
			return ["", "%s refused (%s)" % [str(row[0]), str(_chest_results.back()[1]) if _chest_results.size() > n else "no reply"]]
	return [id, "%s placed, set to clan and then owner-only" % id]

## The tallest crest at least TOWER_PEAK_MIN_M high near the strongest massif summits: [height, xz], or [].
func _find_peak() -> Array:
	var seed_v: int = _root._terrain.get_world_seed()
	var w := Horizon.default_circumference()
	var t0 := Time.get_ticks_msec()
	for sm in WorldShape.massif_summits(seed_v, w, FAR_PEAK_CANDIDATES * 2):
		var hit: Array = WorldShape.highest_near(seed_v, sm[1], w, FAR_PEAK_SUMMIT_RADIUS_M, FAR_PEAK_SUMMIT_STEP_M)
		if float(hit[0]) >= TOWER_PEAK_MIN_M:
			return hit
		if Time.get_ticks_msec() - t0 > COAST_WORK_MS:
			await get_tree().process_frame
			t0 = Time.get_ticks_msec()
	return []
