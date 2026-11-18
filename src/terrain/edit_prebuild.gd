extends RefCounted
## Phase 263 (PR #648 review) — the local player's next edit, built ahead. A whole native chunk build is 30–40 ms
## (the resolve, the smooth mesh, its collision), two frames at 60 Hz, so building the edited chunk on the main
## thread when the work completes put the edit on screen late AND stalled the frame. But the edit is known before
## it completes: the player holds work on the block for the host's timer (Phase 259) first. When that work starts
## (`VoxelEdit.prebuild_edit`), the edit is applied to the voxel data for a moment, the edited chunk's build input
## is gathered from it, the data is put back as it was, and the build runs on a worker at high priority.
##
## At completion `EditRemesh` asks for it (`take`): it is used only when the chunk's input gathered NOW is the very
## input it was built from (the same op logs, depletion, biomes and seed, the same heightmap arrays by identity:
## a map is only ever replaced, never written in place). The same input gives the same arrays, so attaching it is
## the edit's own rebuild, bit for bit; anything else (another edit landed on the chunk, a neighbour streamed in,
## the work went elsewhere) is a miss and the chunk takes the ordinary priority path.

const VoxelCoarse := preload("res://src/terrain/voxel_coarse.gd")
const NativeBuilder := preload("res://src/terrain/native_builder.gd")

var sl: Node   # the ChunkManager
var m1: RefCounted   # its ChunkPart1
var enabled := true
## The suite may run on the GDScript builder.
var without_native := false
var hits := 0
var misses := 0

var _spec: Dictionary = {}   # { chunk, task, result, sig }
var _orphans: Array = []   # task ids of dropped builds, waited for once they finish

func _init(manager: Node, part: RefCounted) -> void:
	sl = manager
	m1 = part

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		finish()

## True while a build is held for `chunk`.
func has(chunk: Vector2i) -> bool:
	return not _spec.is_empty() and _spec["chunk"] == chunk

## Build `chunk` from the voxel data as it is now (the caller has the edit applied) on a worker. False when it
## is not worth it: no native builder, the chunk not loaded at full detail, or no geometry here.
func start(chunk: Vector2i) -> bool:
	drop()
	if not enabled or not (without_native or NativeBuilder.is_native()):
		return false
	if sl.voxel_slice == null or sl.terrain_slice == null or sl.skips_geometry():
		return false
	var key: String = sl._chunk_key(chunk)
	if not sl._loaded.has(key) or sl._near.lod_for(chunk) != VoxelCoarse.FULL:
		return false
	var known: Array = sl.voxel_slice._heightmaps.get(key, [])
	if known.is_empty():
		return false
	var b: Dictionary = m1.noise_build_job(chunk, known)
	if int(b["lod"]) != VoxelCoarse.FULL:
		return false
	var sig := signature(b["input"], known)   # before the worker fills its seam strips into the input
	var task := WorkerThreadPool.add_task(b["job"], true, "edit prebuild %s" % key)
	_spec = { "chunk": chunk, "task": task, "result": b["result"], "sig": sig }
	return true

## The held build of `chunk` as `{ arrays, heightmap }` when it is finished and its input is the chunk's input
## now; else `{}` (and a held build of this chunk is dropped).
func take(chunk: Vector2i) -> Dictionary:
	if not has(chunk):
		return {}
	var spec := _spec
	if not WorkerThreadPool.is_task_completed(int(spec["task"])):
		misses += 1
		drop()
		return {}
	WorkerThreadPool.wait_for_task_completion(int(spec["task"]))
	_spec = {}
	var known: Array = sl.voxel_slice._heightmaps.get(sl._chunk_key(chunk), [])
	var result: Array = spec["result"]
	if not (result[0] is Dictionary) or not same_input(spec["sig"], signature(sl.voxel_slice.gather_build_input_deferred(chunk), known)):
		misses += 1
		return {}
	hits += 1
	var hm: Array = result[1] if result[1] is Array and not (result[1] as Array).is_empty() else known
	return { "arrays": result[0], "heightmap": hm }

## What a full-detail build reads, kept so it can be compared: the plain data by value, the maps by reference.
static func signature(input: Dictionary, known: Array) -> Dictionary:
	return {
		"edits": input.get("edits", {}), "depleted": input.get("depleted", {}), "biomes": input.get("biomes", {}),
		"seed": input.get("seed", 0), "pad": input.get("pad", 0),
		"missing": (input.get("missing_neighbours", []) as Array).duplicate(),
		"maps": (input.get("neighbour_heightmaps", {}) as Dictionary).duplicate(), "known": known,
	}

static func same_input(a: Dictionary, b: Dictionary) -> bool:
	for k in ["edits", "depleted", "biomes", "seed", "pad", "missing"]:
		if a[k] != b[k]:
			return false
	if not is_same(a["known"], b["known"]):
		return false
	var ma: Dictionary = a["maps"]
	var mb: Dictionary = b["maps"]
	if ma.size() != mb.size():
		return false
	for k in ma:
		if not mb.has(k) or not is_same(ma[k], mb[k]):
			return false
	return true

## Forget the held build; one still running is waited for later (`reap`).
func drop() -> void:
	if _spec.is_empty():
		return
	_orphans.append(int(_spec["task"]))
	_spec = {}
	reap()

## Wait for the dropped builds that have finished (a pool task must be waited for once).
func reap() -> void:
	var i := 0
	while i < _orphans.size():
		if WorkerThreadPool.is_task_completed(int(_orphans[i])):
			WorkerThreadPool.wait_for_task_completion(int(_orphans[i]))
			_orphans.remove_at(i)
		else:
			i += 1

## Wait for everything (the manager is going away).
func finish() -> void:
	drop()
	for t in _orphans:
		WorkerThreadPool.wait_for_task_completion(int(t))
	_orphans.clear()
