class_name BakeBoot
extends RefCounted
## Phase 302 — bake the host's planet off the main thread before the world boots. `warm` works out the seed and
## circumference the boot is about to adopt, runs a `BakeJob` for them and waits for it frame by frame, drawing
## a `BakeScreen` (a rendered host) or logging the stage and percent (a dedicated server, a headless boot, which
## waits in place instead of yielding frames).
## `set_world_seed` then finds the file written and reads it. A wrong guess costs a spare bake file and the old
## synchronous bake. Off for clients (they bake from the host's seed after the join), the test run, and worlds
## that keep the local river trace.

const BakeJob := preload("res://src/terrain/bake_job.gd")
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const PersistenceSlice := preload("res://src/persistence/persistence_slice.gd")
const BakeScreen := preload("res://src/ui/bake_screen.gd")
const LOG_EVERY_MSEC := 1000

var root: Node


func _init(p_root: Node) -> void:
	root = p_root


## The job this boot needs, or null when it bakes nothing now (no bake wanted, or the file is already there).
func plan_job() -> BakeJob:
	if root._is_client or "--run-tests" in OS.get_cmdline_user_args():
		return null
	var rec: Dictionary = root._persistence.load_world_record()
	var seed_v: int = root._terrain.get_world_seed()
	var circ_m := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	if not rec.is_empty():
		if PersistenceSlice.worldgen_version_of(rec) < TerrainSlice.BAKE_WORLDGEN_VERSION:
			return null   # recorded before the bake: it keeps its local rivers
		if rec.get("seed", null) != null:
			seed_v = int(rec["seed"])
		var km := float(rec["circumferenceKm"]) if rec.has("circumferenceKm") else TerrainSlice.DEFAULT_CIRCUMFERENCE_KM
		circ_m = float(TerrainSlice.circumference_chunks_for_km(km)) * TerrainSlice.CHUNK_METERS
	var plan := BakeJob.plan_for(seed_v, circ_m, TerrainSlice.WORLDGEN_VERSION)
	if plan.is_empty() or FileAccess.file_exists(str(plan.path)):
		return null   # nothing to bake, or a file to read (a damaged one is baked again by the boot)
	var job := BakeJob.new()
	job.plan = plan
	return job


func warm() -> void:
	var job := plan_job()
	if job == null or not job.start():
		return
	var tree := root.get_tree()
	var drawn: bool = not root._is_server and DisplayServer.get_name() != "headless"
	var screen: CanvasLayer = null
	if drawn:
		screen = BakeScreen.new()
		root.add_child(screen)
	var last_log := -LOG_EVERY_MSEC
	while not job.is_done():
		var s := job.snapshot()
		if screen != null:
			screen.show_progress(s.stage, s.fraction, s.overall)
		elif Time.get_ticks_msec() - last_log >= LOG_EVERY_MSEC:
			last_log = Time.get_ticks_msec()
			print("[World] baking the planet: %s %d%%" % [s.stage, roundi(float(s.overall) * 100.0)])
		if screen != null:
			await tree.process_frame
		else:
			OS.delay_msec(50)   # nothing to draw: wait in place, so a boot that quits after one frame still completes
	job.finish()
	if screen != null:
		root.remove_child(screen)
		screen.free()
	print("[World] planet bake done")
