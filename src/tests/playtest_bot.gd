extends Node
## Phase 134 — a scripted bot plays a real rendered session.
##
## `--playtest-bot` (a user arg, after `--`) boots the normal listen host WITH rendering and runs a
## fixed step list through the same intents a player's input sends: walk (W key held), stream
## (20 chunks), mine, gather, craft, place, fight, travel. A step that does not reach its expected
## state within its timeout fails, and so does the run. While a step runs the bot records the
## frame times, and after it a screenshot, so a human playtest is one artifact download away.
##
## Output (`playtest/`, next to the project): `report.json`, `report.md` and `<step>.png`.
## Perf numbers are a report, not a gate. Only hard failures fail the run: a step timeout, a frame
## over HARD_FRAME_MS, or a crash (no report at all).
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

const WorldPos := preload("res://src/terrain/world_pos.gd")

const ARG := "--playtest-bot"
const OUT_DIR := "res://playtest"
const HITCH_MS := 50.0        ## a frame over this is a hitch (counted, not a failure)
const HARD_FRAME_MS := 2000.0 ## a frame over this fails the run
const STEP_TIMEOUT_SECS := 60.0 ## wall clock for a WHOLE step, not for one wait inside it
const WARMUP_FRAMES := 3     ## the first frames of a step (shader compile, first upload) are not recorded
const BOOT_TIMEOUT_SECS := 120.0
const STREAM_CHUNKS := 20
const WALK_SECS := 3.0
const FIGHT_RANGE_M := 1.5

var _root: Node
var _frames: Array = []       ## frame times (ms) of the step in flight
var _recording: bool = false
var _skip_frames: int = 0
var _step_deadline_ms: int = 0
var _chunk_builds: int = 0
var _mined: Array = []
var _chopped: Array = []
var _crafted: Array = []
var _placed: Array = []

static func requested(args: Array) -> bool:
	return ARG in args

static func step_names() -> Array:
	return ["walk", "stream", "mine", "gather", "craft", "place", "fight", "travel"]

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

static func step_record(step: String, ok: bool, detail: String, frames_ms: Array, chunk_builds: int) -> Dictionary:
	var rec := summarize(frames_ms)
	rec["step"] = step
	rec["ok"] = ok
	rec["detail"] = detail
	rec["chunk_builds"] = chunk_builds
	return rec

## The run verdict. `failures` names every hard failure: a failed (or timed-out) step, a frame over
## HARD_FRAME_MS, and a step of the fixed list that never ran.
static func build_report(steps: Array) -> Dictionary:
	var failures: Array = []
	var seen := {}
	for s in steps:
		seen[str(s["step"])] = true
		if not bool(s["ok"]):
			failures.append("step %s failed: %s" % [s["step"], s["detail"]])
		if float(s["max_ms"]) > HARD_FRAME_MS:
			failures.append("step %s had a %.0f ms frame (limit %.0f)" % [s["step"], float(s["max_ms"]), HARD_FRAME_MS])
	for name in step_names():
		if not seen.has(name):
			failures.append("step %s never ran" % name)
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
	lines.append("| Step | Result | Frames | p50 ms | p95 ms | p99 ms | Max ms | Hitches (>%d ms) | Chunk builds | Detail |" % int(HITCH_MS))
	lines.append("|---|---|---|---|---|---|---|---|---|---|")
	for s in report["steps"]:
		lines.append("| %s | %s | %d | %.1f | %.1f | %.1f | %.1f | %d | %d | %s |" % [
			_md_cell(str(s["step"])), "ok" if bool(s["ok"]) else "FAIL", int(s["frames"]), float(s["p50_ms"]), float(s["p95_ms"]),
			float(s["p99_ms"]), float(s["max_ms"]), int(s["hitches"]), int(s["chunk_builds"]), _md_cell(str(s["detail"]))])
	if not (report["failures"] as Array).is_empty():
		lines.append("")
		lines.append("## Hard failures")
		for f in report["failures"]:
			lines.append("- %s" % _md_cell(str(f)))
	lines.append("")
	return "\n".join(lines)

# ---------------------------------------------------------------------------
# The run
# ---------------------------------------------------------------------------

func _ready() -> void:
	GameBus.block_mined.connect(func(material: String, quantity: int, _p: Vector3): _mined.append([material, quantity]))
	GameBus.tree_chopped.connect(func(id: String, wood: String, state: String, _r: float): _chopped.append([id, wood, state]))
	GameBus.craft_resolved.connect(func(result: Dictionary): _crafted.append(result))
	GameBus.station_placed.connect(func(id: String, type: String, _p: Vector3): _placed.append([id, type]))
	GameBus.chunk_loaded.connect(func(_c: Vector2i): _chunk_builds += 1)

func _process(delta: float) -> void:
	if not _recording:
		return
	if _skip_frames > 0:
		_skip_frames -= 1
		return
	_frames.append(delta * 1000.0)

func run(root: Node) -> void:
	_root = root
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
		_root._inventory.replace_contents({})   # a saved pack from an earlier run must not decide the result
		for name in step_names():
			steps.append(await _run_step(name))
	var report := build_report(steps)
	_write_report(report)
	for f in report["failures"]:
		print("[Playtest] FAILURE: %s" % f)
	print("[Playtest] %s" % ("PASS" if bool(report["ok"]) else "FAIL"))
	get_tree().quit(0 if bool(report["ok"]) else 1)

func _run_step(step: String) -> Dictionary:
	print("[Playtest] step %s" % step)
	_frames = []
	_chunk_builds = 0
	_skip_frames = WARMUP_FRAMES
	_step_deadline_ms = Time.get_ticks_msec() + int(STEP_TIMEOUT_SECS * 1000.0)
	_recording = true
	var result: Array = await call("_step_" + step)
	_recording = false
	var rec := step_record(step, bool(result[0]), str(result[1]), _frames, _chunk_builds)
	await _screenshot(step)
	print("[Playtest] %s %s %s" % [step, "ok" if bool(rec["ok"]) else "FAIL", rec["detail"]])
	return rec

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

func _write_report(report: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var j := FileAccess.open(OUT_DIR.path_join("report.json"), FileAccess.WRITE)
	if j != null:
		j.store_string(JSON.stringify(report, "\t"))
	var m := FileAccess.open(OUT_DIR.path_join("report.md"), FileAccess.WRITE)
	if m != null:
		m.store_string(report_markdown(report))

# ---------------------------------------------------------------------------
# Steps. Each returns [ok: bool, detail: String].
# ---------------------------------------------------------------------------

func _key(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _player_pos() -> Vector3:
	return _root._player.get_position()

## Hold W for a few seconds: the body must move.
func _step_walk() -> Array:
	var start := _player_pos()
	_key(KEY_W, true)
	await _until(func(): return false, WALK_SECS)
	_key(KEY_W, false)
	var moved := Vector2(_player_pos().x - start.x, _player_pos().z - start.z).length()
	return [moved > 1.0, "moved %.1f m" % moved]

## Hop 20 chunks east, waiting for the chunk under the body at every hop.
func _step_stream() -> Array:
	var home: Dictionary = _root._player.get_world_pos()
	for i in range(1, STREAM_CHUNKS + 1):
		var spot := WorldPos.normalized({ "chunk": (home["chunk"] as Vector2i) + Vector2i(i, 0), "local": home["local"] })
		GameBus.player_teleport.emit(spot)
		var built: bool = await _until(func(): return _root._chunk_manager.is_chunk_built(spot["chunk"]), STEP_TIMEOUT_SECS)
		if not built:
			return [false, "chunk %d east never built" % i]
		await _until(func(): return false, 0.1)
	return [true, "%d chunks streamed" % STREAM_CHUNKS]

## Mine the ground block under the body through the player's own intent.
func _step_mine() -> Array:
	var p := _player_pos()
	var y: float = _root._terrain.get_height_at(Vector2(p.x, p.z))
	var before := _mined.size()
	GameBus.block_mine_requested.emit(Vector3(p.x, y - 0.1, p.z), Vector3.UP, "", {})
	var ok: bool = await _until(func(): return _mined.size() > before, STEP_TIMEOUT_SECS)
	return [ok, "mined %s" % str(_mined.back()) if ok else "no block_mined"]

## Gather: fell the first tree of the loaded window through the player's own intent, with an axe in the pack.
func _step_gather() -> Array:
	var standing: Array = []
	for tid in _root._tree._trees:
		if str(_root._tree._trees[tid]["state"]) == "standing":
			standing.append(str(tid))
	standing.sort()
	if standing.is_empty():
		return [false, "no standing tree in the loaded window"]
	if not _root._inventory.add_item("CarpenterAxe", 1):
		return [false, "axe does not fit the pack (weight %.1f of %.1f)" % [_root._inventory.get_current_weight(), _root._inventory.get_max_weight()]]
	var before := _chopped.size()
	GameBus.tree_chop_requested.emit(standing[0], "")
	var ok: bool = await _until(func(): return _chopped.size() > before, STEP_TIMEOUT_SECS)
	return [ok, "felled %s" % str(_chopped.back()) if ok else "chop %s gave nothing" % standing[0]]

## Research `tech_id` through the technology slice (points and materials granted first). "" on success.
func _unlock(tech_id: String) -> String:
	var t = _root._technology
	var pid: String = t.local_player_id()
	if t.is_unlocked(tech_id, pid):
		return ""
	t._set_points(pid, t.max_points())
	for entry in t.get_tech_data(tech_id).get("researchMaterials", []):
		_root._inventory.add_item(str(entry["item"]), int(entry["quantity"]))
	var begun: Dictionary = t.begin_research(tech_id, pid)
	if not bool(begun["success"]):
		return str(begun["reason"])
	var done: Dictionary = t.complete_research(tech_id, pid)
	return "" if bool(done["success"]) else str(done["reason"])

## Craft planks at a carpentry bench set down at the feet.
func _step_craft() -> Array:
	var tech: Variant = _unlock("TechBasicCarpentry")
	if tech != "":
		return [false, "research: %s" % tech]
	_root._inventory.add_item("Thornwood", 2)
	_root._crafting.set_skill("Carpentry", "novice")
	var p := _player_pos()
	_root._station.set_player_position(p)
	if _root._station.try_place_station("carpentry bench", p + Vector3(2.0, 0.0, 0.0), _root._inventory) == "":
		return [false, "bench placement refused"]
	var before := _crafted.size()
	var planks: int = _root._inventory.get_item_count("ThornwoodPlank")
	GameBus.craft_requested.emit("RecipeThornwoodPlank")
	var ok: bool = await _until(func(): return _crafted.size() > before, STEP_TIMEOUT_SECS)
	if not ok:
		return [false, "no craft_resolved"]
	var got: int = _root._inventory.get_item_count("ThornwoodPlank") - planks
	return [bool(_crafted.back()["success"]) and got == 3, "crafted %d planks (%s)" % [got, str(_crafted.back()["reason"])]]

## Place a station with the player's own placement call.
func _step_place() -> Array:
	var p := _player_pos()
	var before := _placed.size()
	var id: String = _root._station.try_place_station("forge", p + Vector3(-3.0, 0.0, 0.0), _root._inventory)
	if id == "":
		return [false, "forge placement refused"]
	var ok: bool = await _until(func(): return _placed.size() > before, STEP_TIMEOUT_SECS)
	return [ok, "placed %s" % id]

## Fight: a creature set down within reach loses HP to the player's melee round.
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
	var p := _player_pos()
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
	return [ok, "%s at %.0f hp after %d rounds" % [cid, _root._battle.get_hp(iid), rounds]]

## Travel: two attuned waystones, then the intent; the body must land at the second.
func _step_travel() -> Array:
	var seen: Dictionary = _root._player.get_world_pos()
	var gap := 80.0
	var base: Vector3 = WorldPos.to_scene(seen, seen["chunk"])
	var a: String = _root._station.place_station("waystone", base)
	var b: String = _root._station.place_station("waystone", base + Vector3(gap, 0.0, 0.0))
	var dest := WorldPos.normalized({ "chunk": seen["chunk"], "local": (seen["local"] as Vector3) + Vector3(gap, 0.0, 0.0) })
	_root._waystones.note_exact(a, seen)
	_root._waystones.note_exact(b, dest)
	_root._registry.record_waystones(_root._registry.local_player_id, [a, b])
	_root._registry.get_inventory(_root._registry.local_player_id).add_item(str(_root._waystones.rules()["costItem"]), 20)
	GameBus.waystone_travel_intent.emit(a, b, "")
	var ok: bool = await _until(func():
		var now: Dictionary = _root._player.get_world_pos()
		return now["chunk"] == dest["chunk"] and (now["local"] as Vector3).distance_to(dest["local"]) < 2.0, STEP_TIMEOUT_SECS)
	return [ok, "travelled to the second stone" if ok else "body did not reach the second stone"]
