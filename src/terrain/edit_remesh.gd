extends RefCounted
## Phase 263 — a dug or placed block shows at once. An edit's rebuild used to wait behind the streaming work
## in the build queue (`_rebuild_queue` and `_load_queue`, under the in-flight cap and the frame's pump budget),
## so the ground changed seconds after the work completed. Now:
##
## * the chunk of the LOCAL player's own edit (`PRIMARY`) is attached on the main thread at once when that is
##   cheap: its build was made ahead on a worker while the player's work timer ran (`EditPrebuild`: the same
##   input, so the same arrays), or the chunk's last build took at most `max_sync_job_usec`. At most
##   `SYNC_PER_FRAME` such attaches run in one frame, so a burst of edits cannot stall it;
## * otherwise, and for every chunk of another player's edit (a remote actor on the host, a replayed
##   `block_changed` on a client) and the neighbours whose seam an edit touches (`NEIGHBOUR`), the build
##   waits here, ahead of every streaming chunk, and takes the next free worker (`drain`, called first by the
##   manager's drain, whatever the frame's budget), at high priority;
## * its finished build attaches first (`first`) and is never held back by the attach budget.
##
## The collision shape rides the same build (`_attach_built` gives the chunk its shape with its mesh), so the
## body never falls into a hole it cannot see, nor stands on one it can.
##
## Each edit's rebuild is timed from the request (the edit's completion) to the attach: the queue wait, the
## build and the whole, in ms and in frames (`samples`). The playtest `mine` step reports them.

const NativeBuilder := preload("res://src/terrain/native_builder.gd")
const VoxelCoarse := preload("res://src/terrain/voxel_coarse.gd")
const EditPrebuild := preload("res://src/terrain/edit_prebuild.gd")

const NONE := 0
const NEIGHBOUR := 1   ## another player's edit, or a seam the edit touches: first in line for a worker
const PRIMARY := 2     ## the chunk of the local player's own edit: attached at once when that is cheap
const SYNC_PER_FRAME := 1
## A chunk whose last build took longer than this is never built on the main thread (PR #648 review: a whole
## native chunk build is 30–40 ms, two frames at 60 Hz).
const MAX_SYNC_JOB_USEC := 6000
const MAX_COSTS := 1024
const MAX_SAMPLES := 256
## An open rebuild never attached (its chunk streamed out, or an isolated rig built nothing) is forgotten after this.
const OPEN_TTL_USEC := 10_000_000
const NO_CHUNK := Vector2i(1 << 30, 1 << 30)

var sl: Node   # the ChunkManager
var m1: RefCounted   # its ChunkBuildQueue
## Main-thread builds for a PRIMARY chunk. `sync_without_native` lets a test run them on the GDScript builder.
var sync_enabled := true
var sync_without_native := false
var max_sync_job_usec := MAX_SYNC_JOB_USEC
## The local player's next edit, built ahead (see `edit_prebuild.gd`).
var prebuild: EditPrebuild
## `{ chunk, primary, sync, queue_ms, build_ms, total_ms, frames, at_usec }` per attached edit rebuild, oldest first.
var samples: Array = []
## Clock for the samples (µs); a test may stub it.
var clock_usec: Callable = func() -> int: return Time.get_ticks_usec()

var _queue: Array = []   # of Vector2i, waiting for a worker
var _open: Dictionary = {}   # key -> { t0, f0, dispatched, primary, sync }
var _sync_frame := -1
var _sync_count := 0
var _job_usec: Dictionary = {}   # key -> the job time of the chunk's last finished build (µs)

func _init(manager: Node, part: RefCounted) -> void:
	sl = manager
	m1 = part
	prebuild = EditPrebuild.new(manager, part)

## A finished build of `key` took `usec` of worker time: the cost bound of its next main-thread build.
func note_cost(key: String, usec: int) -> void:
	if usec <= 0:
		return
	_job_usec.erase(key)
	_job_usec[key] = usec   # re-inserted: the oldest entries go first below
	while _job_usec.size() > MAX_COSTS:
		_job_usec.erase(_job_usec.keys()[0])

## True while `key` has an edit rebuild requested and not yet attached.
func is_priority(key: String) -> bool:
	return _open.has(key)

## #649 — true while `key` has a PRIMARY edit rebuild (this player's own edit) open: only those attach outside the
## frame's attach budget; a NEIGHBOUR rebuild (another player's edit, a seam neighbour) goes first but counts.
func is_primary(key: String) -> bool:
	return _open.has(key) and bool(_open[key]["primary"])

## The chunks waiting for a worker, in order.
func queued() -> Array:
	return _queue.duplicate()

## Rebuild `chunk` at `priority` (`NONE` is the manager's ordinary dispatch). The caller has already
## superseded any build in flight for it.
func dispatch(chunk: Vector2i, priority: int) -> void:
	if priority <= NONE:
		sl._dispatch_build(chunk)
		return
	var key: String = sl._chunk_key(chunk)
	var now := int(clock_usec.call())
	_prune(now)
	if priority < PRIMARY:
		prebuild.note_changed(chunk)   # another edit in the held chunk's ring
	_open[key] = { "t0": now, "f0": Engine.get_process_frames(), "dispatched": -1, "primary": priority >= PRIMARY or is_primary(key), "sync": false }
	# A deferred ordinary rebuild of the same chunk is this one now.
	if sl._rebuild_pending.has(key):
		sl._rebuild_pending.erase(key)
		sl._remove_queued_rebuild(key)
	if priority >= PRIMARY and _build_now(chunk, key):
		return
	if not _queue.has(chunk):
		_queue.append(chunk)
	drain()

## Hand the waiting edit rebuilds to free workers, before any streaming dispatch and outside the frame's budget.
func drain() -> void:
	prebuild.reap()
	prebuild.refresh()   # PR #648 CI: the ring round a held build changed while the work ran
	while not _queue.is_empty() and m1.worker_builds() < sl.build_cap():
		var chunk: Vector2i = _queue.pop_front()
		var key: String = sl._chunk_key(chunk)
		if not sl._loaded.has(key):
			_open.erase(key)   # streamed out while it waited: it rebuilds from the edit log when it streams back
			continue
		if _open.has(key):
			_open[key]["dispatched"] = int(clock_usec.call())
		sl._dispatch_build(chunk)

## `order` (finished build ids) with the edit rebuilds first, otherwise in the same order.
func first(order: Array) -> Array:
	if _open.is_empty():
		return order
	var front: Array = []
	var rest: Array = []
	for task_id in order:
		var entry: Dictionary = sl._builds.get(task_id, {})
		if not entry.is_empty() and _open.has(str(entry["key"])):
			front.append(task_id)
		else:
			rest.append(task_id)
	return front + rest

## The manager attached `key`'s build: close its edit rebuild, if one is open, as a sample.
func note_attached(key: String, chunk: Vector2i = NO_CHUNK) -> void:
	prebuild.note_changed(chunk)
	if not _open.has(key):
		return
	var o: Dictionary = _open[key]
	_open.erase(key)
	var now := int(clock_usec.call())
	var t0 := int(o["t0"])
	var sent := int(o["dispatched"]) if int(o["dispatched"]) >= 0 else t0
	samples.append({
		"chunk": key, "primary": bool(o["primary"]), "sync": bool(o["sync"]),
		"queue_ms": float(sent - t0) / 1000.0, "build_ms": float(now - sent) / 1000.0, "total_ms": float(now - t0) / 1000.0,
		"frames": Engine.get_process_frames() - int(o["f0"]) + 1, "at_usec": now,
		"job_ms": float(o.get("job_usec", 0)) / 1000.0,   # a main-thread build's own work, without the gather and attach
		"prebuilt": bool(o.get("prebuilt", false)),
		"miss": str(o.get("miss", "")),   # why a PRIMARY rebuild was not a held build (`EditPrebuild.last_miss`)
	})
	if samples.size() > MAX_SAMPLES:
		samples.pop_front()

## True when a PRIMARY chunk may be attached on the main thread now: the chunk is drawn at full detail with
## geometry and this frame has not had its main-thread attach yet. `full` (a whole build here, not a prebuilt
## one) also needs the native mesher (or a test's say-so) and a last build within `max_sync_job_usec`.
func can_build_now(chunk: Vector2i, full: bool = true) -> bool:
	if not sync_enabled:
		return false
	if full and not (sync_without_native or NativeBuilder.is_native()):
		return false
	if full and int(_job_usec.get(sl._chunk_key(chunk), 1 << 40)) > max_sync_job_usec:
		return false
	if sl.terrain_slice == null or sl.voxel_slice == null or sl.skips_geometry():
		return false
	if not sl.terrain_slice.has_method("detail_noise_copy") or not sl.voxel_slice.has_method("gather_build_input_deferred"):
		return false
	if sl._near.lod_for(chunk) != VoxelCoarse.FULL:
		return false
	var f := Engine.get_process_frames()
	if f != _sync_frame:
		_sync_frame = f
		_sync_count = 0
	return _sync_count < SYNC_PER_FRAME

## Build `chunk` on the main thread and attach it. False (nothing done) when it may not, or the build came back
## empty: the caller then queues it for a worker.
func _build_now(chunk: Vector2i, key: String) -> bool:
	if not sl._loaded.has(key):
		return false
	_open[key]["miss"] = "cannot attach now"
	if can_build_now(chunk, false):
		var ready: Dictionary = prebuild.take(chunk)
		_open[key]["miss"] = prebuild.last_miss
		if not ready.is_empty():
			_sync_count += 1
			_open[key]["dispatched"] = int(clock_usec.call())
			_open[key]["sync"] = true
			_open[key]["prebuilt"] = true
			sl._build_attempts[key] = int(sl._build_attempts.get(key, 0)) + 1
			# #679: `take` returned it only because the chunk's input still matches what it was built from, so the
			# disk key of the state now is the key of the state it read.
			var lod := int((ready["arrays"] as Dictionary).get("lod", 1))
			sl._attach_built(key, chunk, ready["heightmap"], ready["arrays"], int(sl.voxel_slice.chunk_revision(chunk)),
				{ "disk_key": m1.dispatch_disk_key(chunk, lod), "disk_lod": lod })
			return true
	if not can_build_now(chunk):
		return false
	_sync_count += 1
	# An edit changes the runs, never the generated map: the one the chunk was built from is reused, so the
	# main thread does not pay the noise again.
	var b: Dictionary = m1.noise_build_job(chunk, sl.voxel_slice._heightmaps.get(key, []))
	_open[key]["dispatched"] = int(clock_usec.call())
	_open[key]["sync"] = true
	var disk_entry := { "disk_key": m1.dispatch_disk_key(chunk, int(b["lod"])), "disk_lod": int(b["lod"]) }   # #679: the state it reads
	(b["job"] as Callable).call()
	var result: Array = b["result"]
	sl.worker_usec += int(result[2]) if result.size() > 2 else 0
	_open[key]["job_usec"] = int(result[2]) if result.size() > 2 else 0
	note_cost(key, int(_open[key]["job_usec"]))
	if not (result[0] is Dictionary):
		_open[key]["sync"] = false
		return false
	sl._build_attempts[key] = int(sl._build_attempts.get(key, 0)) + 1
	var heightmap: Array = result[1] if result[1] is Array else []
	sl._attach_built(key, chunk, heightmap, result[0], int(b["revision"]), disk_entry)
	return true

func _prune(now: int) -> void:
	for key in _open.keys():
		if now - int(_open[key]["t0"]) > OPEN_TTL_USEC:
			_open.erase(key)

## Forget everything queued and open (the manager released its window).
func clear() -> void:
	_queue.clear()
	_open.clear()
	_job_usec.clear()
	prebuild.drop()
