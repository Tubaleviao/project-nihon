extends RefCounted
## Phase 263 — a dug or placed block shows at once. An edit's rebuild used to wait behind the streaming work
## in the build queue (`_rebuild_queue` and `_load_queue`, under the in-flight cap and the frame's pump budget),
## so the ground changed seconds after the work completed. Now:
##
## * the edited chunk (`PRIMARY`) is built on the main thread at once when the build is short enough: the
##   native smooth mesher is loaded and the chunk is a full-detail one. At most `SYNC_PER_FRAME` such builds
##   run in one frame, so a burst of edits cannot stall it;
## * otherwise, and for the neighbours whose seam the edit touches (`NEIGHBOUR`), the build waits here, ahead
##   of every streaming chunk, and takes the next free worker (`drain`, called first by the manager's drain,
##   whatever the frame's budget), at high priority;
## * its finished build attaches first (`first`) and is never held back by the attach budget.
##
## The collision shape rides the same build (`_attach_built` gives the chunk its shape with its mesh), so the
## body never falls into a hole it cannot see, nor stands on one it can.
##
## Each edit's rebuild is timed from the request (the edit's completion) to the attach: the queue wait, the
## build and the whole, in ms and in frames (`samples`). The playtest `mine` step reports them.

const NativeBuilder := preload("res://src/terrain/native_builder.gd")
const VoxelCoarse := preload("res://src/terrain/voxel_coarse.gd")

const NONE := 0
const NEIGHBOUR := 1   ## a chunk whose seam the edit touches: first in line for a worker
const PRIMARY := 2     ## the chunk the edited tile is in: built at once when it is short enough
const SYNC_PER_FRAME := 1
const MAX_SAMPLES := 256
## An open rebuild never attached (its chunk streamed out, or an isolated rig built nothing) is forgotten after this.
const OPEN_TTL_USEC := 10_000_000

var sl: Node   # the ChunkManager
var m1: RefCounted   # its ChunkPart1
## Main-thread builds for a PRIMARY chunk. `sync_without_native` lets a test run them on the GDScript builder.
var sync_enabled := true
var sync_without_native := false
## `{ chunk, primary, sync, queue_ms, build_ms, total_ms, frames, at_usec }` per attached edit rebuild, oldest first.
var samples: Array = []
## Clock for the samples (µs); a test may stub it.
var clock_usec: Callable = func() -> int: return Time.get_ticks_usec()

var _queue: Array = []   # of Vector2i, waiting for a worker
var _open: Dictionary = {}   # key -> { t0, f0, dispatched, primary, sync }
var _sync_frame := -1
var _sync_count := 0

func _init(manager: Node, part: RefCounted) -> void:
	sl = manager
	m1 = part

## True while `key` has an edit rebuild requested and not yet attached.
func is_priority(key: String) -> bool:
	return _open.has(key)

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
	_open[key] = { "t0": now, "f0": Engine.get_process_frames(), "dispatched": -1, "primary": priority >= PRIMARY, "sync": false }
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
func note_attached(key: String) -> void:
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
	})
	if samples.size() > MAX_SAMPLES:
		samples.pop_front()

## True when a PRIMARY chunk may be built on the main thread now: the native mesher is loaded (or a test said
## so), the chunk is drawn at full detail with geometry, and this frame has not had its main-thread build yet.
func can_build_now(chunk: Vector2i) -> bool:
	if not sync_enabled or not (sync_without_native or NativeBuilder.is_native()):
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
	if not sl._loaded.has(key) or not can_build_now(chunk):
		return false
	_sync_count += 1
	# An edit changes the runs, never the generated map: the one the chunk was built from is reused, so the
	# main thread does not pay the noise again.
	var b: Dictionary = m1.noise_build_job(chunk, sl.voxel_slice._heightmaps.get(key, []))
	_open[key]["dispatched"] = int(clock_usec.call())
	_open[key]["sync"] = true
	(b["job"] as Callable).call()
	var result: Array = b["result"]
	sl.worker_usec += int(result[2]) if result.size() > 2 else 0
	_open[key]["job_usec"] = int(result[2]) if result.size() > 2 else 0
	if not (result[0] is Dictionary):
		_open[key]["sync"] = false
		return false
	sl._build_attempts[key] = int(sl._build_attempts.get(key, 0)) + 1
	var heightmap: Array = result[1] if result[1] is Array else []
	sl._attach_built(key, chunk, heightmap, result[0], int(b["revision"]))
	return true

func _prune(now: int) -> void:
	for key in _open.keys():
		if now - int(_open[key]["t0"]) > OPEN_TTL_USEC:
			_open.erase(key)

## Forget everything queued and open (the manager released its window).
func clear() -> void:
	_queue.clear()
	_open.clear()
