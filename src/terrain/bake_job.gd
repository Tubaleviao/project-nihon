class_name BakeJob
extends RefCounted
## Phase 302 — the planet bake of a world's creation, run on a worker thread while the main thread draws a
## progress screen. The job bakes (or reads) the bake file for a seed exactly as `PlanetBake.ensure` does
## and saves it to `user://bake/`; the boot's own `set_world_seed` then reads that file in a blink, so the
## bytes are the ones a synchronous boot makes. A job that guessed a different seed or circumference than
## the boot adopts only wastes a bake: the boot then bakes synchronously, as before.

const PlanetBake := preload("res://src/terrain/planet_bake.gd")
const BAKE_DIR := "user://bake"

var plan: Dictionary = {}
var _mutex := Mutex.new()
var _stage: StringName = &"load"
var _fraction := 0.0
var _overall := 0.0
var _done := false
var _result: Dictionary = {}
var _thread: Thread = null


## Where and how a world of `circumference_m` and `seed_v` bakes: { seed, path, w, h, circ, version }, or an empty
## dictionary when it keeps the local river trace (a grid under 8 cells wide or over `PlanetBake.MAX_CELLS`).
## `worldgen_version` is the bake version (`PlanetBake.profile`, `bake_version_for`): it names the file and picks
## the algorithm, so a world recorded at worldgen 14 keeps its Phase 245 bake.
static func plan_for(seed_v: int, circumference_m: float, worldgen_version: int, dir: String = BAKE_DIR) -> Dictionary:
	var w := roundi(circumference_m / PlanetBake.CELL_M)
	var h := w / 2
	if w < 8 or w * h > PlanetBake.MAX_CELLS:
		return {}
	var v := mini(worldgen_version, PlanetBake.BAKE_VERSION)
	return { "seed": seed_v, "w": w, "h": h, "circ": circumference_m, "version": v, "path": PlanetBake.file_path(dir, seed_v, v, w, h) }


## Phase 302 — the bake version of a world recorded at `world_version` (-1 or less for a new world): the Phase 245
## algorithm for worldgen 14, the Phase 302 one for 15 to 17, the newest for 18 and later and for a new world.
static func bake_version_for(world_version: int) -> int:
	if world_version >= 0 and world_version <= PlanetBake.BAKE_VERSION_245:
		return PlanetBake.BAKE_VERSION_245
	if world_version >= 0 and world_version < PlanetBake.BAKE_VERSION_WRAP:
		return PlanetBake.BAKE_VERSION_WRAP - 1   # Phase 232: worlds of 15 to 17 keep the bake whose X edges are boundaries
	return PlanetBake.BAKE_VERSION


## Called from the baking thread (or a test); the main thread reads `snapshot()`. The overall share never goes back.
func report(stage: StringName, fraction: float) -> void:
	var o := PlanetBake.overall(stage, fraction)
	_mutex.lock()
	_stage = stage
	_fraction = fraction
	_overall = maxf(_overall, o)
	_mutex.unlock()


## { stage, fraction (in the stage), overall (0..1), done }.
func snapshot() -> Dictionary:
	_mutex.lock()
	var s := { "stage": _stage, "fraction": _fraction, "overall": _overall, "done": _done }
	_mutex.unlock()
	return s


## Run `PlanetBake.ensure` for `plan` on a worker thread; false when there is nothing to bake.
func start() -> bool:
	if plan.is_empty() or _thread != null:
		return false
	_thread = Thread.new()
	_thread.start(_run)
	return true


func _run() -> void:
	var r := PlanetBake.ensure(str(plan.path), int(plan.seed), int(plan.w), int(plan.h), float(plan.circ), PlanetBake.RIVER_FLOW, "", report, int(plan.get("version", PlanetBake.BAKE_VERSION)))
	_mutex.lock()
	_result = { "hash": r.hash, "loaded": r.loaded }
	_overall = 1.0
	_done = true
	_mutex.unlock()


func is_done() -> bool:
	return bool(snapshot().done)


## Join the thread (call once `is_done()`, or to abandon the job) and return { hash, loaded }.
func finish() -> Dictionary:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	return _result
