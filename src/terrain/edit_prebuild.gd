extends RefCounted
## Phase 263 (PR #648 review) — the local player's next edit, built ahead. A whole native chunk build is 30–40 ms
## (the resolve, the smooth mesh, its collision), two frames at 60 Hz, so building the edited chunk on the main
## thread when the work completes put the edit on screen late AND stalled the frame. But the edit is known before
## it completes: the player holds work on the block for the host's timer (Phase 259) first. When that work starts
## (`VoxelEdit.prebuild_edit`), the edit is applied to the voxel data for a moment, the edited chunk's build input
## is gathered from it, the data is put back as it was, and the build runs on a worker at high priority.
##
## At completion `EditRemesh` asks for it (`take`): it is used only when the chunk's input gathered NOW is the very
## input it was built from (the same op logs, depletion, biomes and seed, the same heightmaps: the same array, or
## an equal one, since a rebuild of a chunk hands it a new array of the same generated map). The same input gives
## the same arrays, so attaching it is the edit's own rebuild, bit for bit; anything else (another edit landed on the
## chunk, the work went elsewhere) is a miss and the chunk takes the ordinary priority path.
##
## PR #648 CI: while the work runs, the world round the chunk may still be streaming (on a slow machine, the home
## window after the flight step): a ring chunk that was missing gets its map, and the held build no longer matches.
## Every attach in the chunk's 3x3 ring marks the held build stale (`note_changed`); the next frame (`refresh`)
## compares the parts the edit does not write (maps, biomes, seed) with the chunk's input now and, when they differ,
## builds it again (`redo`, the edit applied for a moment again).

const VoxelCoarse := preload("res://src/terrain/voxel_coarse.gd")
const NativeBuilder := preload("res://src/terrain/native_builder.gd")

var sl: Node   # the ChunkManager
var m1: RefCounted   # its ChunkPart1
var enabled := true
## The suite may run on the GDScript builder.
var without_native := false
var hits := 0
var misses := 0
## Held builds started again because the ring round the chunk changed during the work (`refresh`).
var restarts := 0
## Why the last held build was not started or not used ("" after a hit): the playtest reports it.
var last_miss := ""

var _spec: Dictionary = {}   # { chunk, task, result, sig, redo, stale }
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
## is not worth it: no native builder, the chunk not loaded at full detail, or no geometry here. `redo` builds it
## again with the edit applied (the caller's own call, bound), for `refresh`.
func start(chunk: Vector2i, redo: Callable = Callable()) -> bool:
	drop()
	if not enabled or not (without_native or NativeBuilder.is_native()):
		return _not_started("no native builder")
	if sl.voxel_slice == null or sl.terrain_slice == null or sl.skips_geometry():
		return _not_started("no geometry")
	var key: String = sl._chunk_key(chunk)
	if not sl._loaded.has(key) or sl._near.lod_for(chunk) != VoxelCoarse.FULL:
		return _not_started("chunk not loaded at full detail")
	var known: Array = sl.voxel_slice._heightmaps.get(key, [])
	if known.is_empty():
		return _not_started("no built map")
	var b: Dictionary = m1.noise_build_job(chunk, known)
	if int(b["lod"]) != VoxelCoarse.FULL:
		return _not_started("not a full-detail build")
	var sig := signature(b["input"], known)   # before the worker fills its seam strips into the input
	var task := WorkerThreadPool.add_task(b["job"], true, "edit prebuild %s" % key)
	_spec = { "chunk": chunk, "task": task, "result": b["result"], "sig": sig, "redo": redo, "stale": false }
	return true

## A build of `chunk` was attached (or an edit asked for one): a held build whose ring holds it may be stale.
func note_changed(chunk: Vector2i) -> void:
	if _spec.is_empty():
		return
	var d: Vector2i = (chunk - (_spec["chunk"] as Vector2i)).abs()
	if maxi(d.x, d.y) <= 1:
		_spec["stale"] = true

## Once a frame: a stale held build whose world input (the maps, biomes, seed; not the op logs, which hold the
## edit only while it is built) differs from the chunk's now is built again.
func refresh() -> void:
	if _spec.is_empty() or not bool(_spec["stale"]):
		return
	_spec["stale"] = false
	var chunk: Vector2i = _spec["chunk"]
	var known: Array = sl.voxel_slice._heightmaps.get(sl._chunk_key(chunk), [])
	var now := signature(sl.voxel_slice.gather_build_input_deferred(chunk), known)
	if first_difference(_spec["sig"], now, WORLD_PARTS) == "":
		return
	var redo: Callable = _spec["redo"]
	if redo.is_valid():
		restarts += 1
		redo.call()

## The held build of `chunk` as `{ arrays, heightmap }` when it is finished and its input is the chunk's input
## now; else `{}` (and a held build of this chunk is dropped).
func take(chunk: Vector2i) -> Dictionary:
	if not has(chunk):
		last_miss = "none held" if _spec.is_empty() else "another chunk held"
		return {}
	var spec := _spec
	if not WorkerThreadPool.is_task_completed(int(spec["task"])):
		misses += 1
		last_miss = "still building"
		drop()
		return {}
	WorkerThreadPool.wait_for_task_completion(int(spec["task"]))
	_spec = {}
	var known: Array = sl.voxel_slice._heightmaps.get(sl._chunk_key(chunk), [])
	var result: Array = spec["result"]
	if not (result[0] is Dictionary):
		misses += 1
		last_miss = "empty build"
		return {}
	var differs := first_difference(spec["sig"], signature(sl.voxel_slice.gather_build_input_deferred(chunk), known))
	if differs != "":
		misses += 1
		last_miss = "input changed: " + differs
		return {}
	hits += 1
	last_miss = ""
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
	return first_difference(a, b) == ""

## The first part of two signatures that differs ("" when none does).
## The plain parts of a signature `refresh` compares: what the edit itself does not write.
const WORLD_PARTS := ["biomes", "seed", "pad", "missing"]
const ALL_PARTS := ["edits", "depleted", "biomes", "seed", "pad", "missing"]

static func first_difference(a: Dictionary, b: Dictionary, parts: Array = ALL_PARTS) -> String:
	for k in parts:
		if a[k] != b[k]:
			return k
	if not _same_map(a["known"], b["known"]):
		return "known"
	var ma: Dictionary = a["maps"]
	var mb: Dictionary = b["maps"]
	if ma.size() != mb.size():
		return "maps"
	for k in ma:
		if not mb.has(k) or not _same_map(ma[k], mb[k]):
			return "map " + str(k)
	return ""

## The same heightmap: the same array (cheap, the common case) or an equal one (a rebuild of the chunk hands it a
## new array of the same generated map; the build reads only the values).
static func _same_map(a: Variant, b: Variant) -> bool:
	return is_same(a, b) or (typeof(a) == typeof(b) and a == b)

func _not_started(why: String) -> bool:
	last_miss = "not started: " + why
	return false

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
