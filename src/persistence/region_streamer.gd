extends RefCounted
## Region streamer — keeps resident exactly the regions the streamed windows touch (Phase 52).
##
## `ChunkManager` hands it the set of chunks its windows want; the streamer reads the
## regions those chunks (plus a one-chunk margin, for the neighbour guess) fall in and
## adds their edits to the voxel log, and releases the edits of regions no window needs
## any more. A server with a thousand edited regions on disk therefore holds only the
## ones around its players.
##
## Region reads are synchronous file reads on the calling thread by default (the suite, the
## tools). Phase 142 — with `async_reads` set (the game) a missing region is read on a worker
## task instead and `poll()` applies a finished read on the main thread, so a window move never
## blocks the frame on the disk; `regions_settled` is what a chunk waits for before it builds.
const RegionStore := preload("res://src/persistence/region_store.gd")
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const ChunkRecords := preload("res://src/terrain/chunk_records.gd")
const SeamWrap := preload("res://src/terrain/seam_wrap.gd")

var _store: RegionStore
## Phase 142 — read missing regions on a worker (see the header). Off: `sync` reads inline.
var async_reads := false
## "rx,rz" -> worker task id of a read in flight; "rx,rz" -> its finished { "read": ... } result.
var _reading: Dictionary = {}
var _read_out: Dictionary = {}
var _read_mutex := Mutex.new()
## Thread ids that ran a region read (test hook: none may be the main thread under `async_reads`).
var read_thread_ids: Array = []
var record_threads := false   # off in the game: the list would grow with every read
## The keys of the last `sync`'s wanted set: a read that finishes for a region no longer wanted is dropped.
var _wanted_last: Dictionary = {}
## Phase 162 — region reads begun (sync or on a worker), for the crowd stress report.
var reads_started := 0
var _voxel: Object
## "rx,rz" -> true for every region read and still wanted.
var _resident: Dictionary = {}
## Released regions whose DIRTY chunks could not be dropped yet (their edits exist only in
## memory until a save carries them). Retried on every sync until a save has cleaned them.
var _stranded: Dictionary = {}

## Failed reads back off: "rx,rz" -> { "until": msec before which the read is not retried,
## "delay": the current backoff }. A region that cannot be read (a corrupt or unreadable file)
## would otherwise log an error and hit the disk on every sync. A successful read forgets it.
var _backoff: Dictionary = {}
const BACKOFF_START_MSEC := 1000
const BACKOFF_MAX_MSEC := 60000
## The clock the backoff reads; a test swaps it for a deterministic one.
var _now: Callable = Time.get_ticks_msec

## Phase 121 — a stranded region is retried on its own backoff, whether or not a window moved, so a
## stationary server recovers it once a save has cleaned its chunks without rescanning every frame.
const STRANDED_RETRY_START_MSEC := 2000
const STRANDED_RETRY_MAX_MSEC := 16000
## "rx,rz" -> { "until", "delay" } for each stranded region: a second region stranded later starts at
## `STRANDED_RETRY_START_MSEC`, not at the delay an earlier one has grown to; a cleaned region is forgotten.
var _stranded_wait: Dictionary = {}

func _init(store: RegionStore, voxel: Object, async: bool = false) -> void:
	async_reads = async
	_store = store
	_voxel = voxel

## The "rx,rz" keys of every region touched by `chunks` (Vector2i) or any chunk adjacent to
## one. Pure.
## Phase 114 — a chunk that already has a generation record needs only `recorded_margin` (a frontier
## blend reads records around an UNRECORDED chunk), so a fully recorded window loads no extra region.
static func regions_for_chunks(chunks: Array, margin: int = 1, recorded_margin: int = 1) -> Dictionary:
	# Phase 163 — regions are collected as Vector2i and keyed once each at the end: a crossing's window
	# has hundreds of chunks but touches a handful of regions, and a string per chunk (nine per edge
	# chunk) was most of a refresh.
	var regions: Dictionary = {}
	# Only a chunk near an edge (for the wider margin) can reach past its region, so only those are
	# looked up in the record table, in one locked pass (not a lock per chunk).
	var widest := maxi(margin, recorded_margin)
	var circumference := TerrainSlice.circumference_chunks()
	var edge: Array = []
	for c in chunks:
		regions[RegionStore.region_of_chunk(c)] = true
		if _near_region_edge(c, widest):
			edge.append(c)
	var recorded: Dictionary = ChunkRecords.recorded_keys(edge, TerrainSlice.wrap_chunk) if margin != recorded_margin else {}
	for c in edge:
		var chunk: Vector2i = c
		var reach := recorded_margin if recorded.has(chunk) else margin
		if not _near_region_edge(chunk, reach):
			continue   # an interior chunk reads nothing beyond its own region
		# The margin matters only on a region's edge: a chunk there is rebuilt against its
		# neighbour's real edits, which live in the next region.
		# Neighbours are wrapped in X like every chunk key, so a seam chunk's margin is the
		# region on the far side of the seam.
		# Phase 113: the host passes `Frontier.BLEND_CHUNKS`, the records a frontier chunk reads.
		# Regions are `REGION_SIZE` wide, far wider than the margin, so the extremes and the centre
		# of the square touch every region it does.
		# The three region columns and three region rows of the square, each computed once.
		var rxs: Array = []
		for dx in [-reach, 0, reach]:
			rxs.append(floori(float(SeamWrap.wrap_i(chunk.x + dx, circumference)) / float(RegionStore.REGION_SIZE)))
		var rzs: Array = []
		for dz in [-reach, 0, reach]:
			rzs.append(floori(float(chunk.y + dz) / float(RegionStore.REGION_SIZE)))
		for rx in rxs:
			for rz in rzs:
				regions[Vector2i(rx, rz)] = true
	var out: Dictionary = {}
	for r in regions:
		out[RegionStore.region_key(r)] = true
	return out

## Phase 121 — true when `chunk` is within `reach` chunks of its region's edge or of the X seam (where
## wrapping puts the neighbour in another region), the only chunks whose margin can cross a region. Pure.
static func _near_region_edge(chunk: Vector2i, reach: int) -> bool:
	var lx := posmod(chunk.x, RegionStore.REGION_SIZE)
	var lz := posmod(chunk.y, RegionStore.REGION_SIZE)
	if lx < reach or lx >= RegionStore.REGION_SIZE - reach or lz < reach or lz >= RegionStore.REGION_SIZE - reach:
		return true
	@warning_ignore("integer_division")
	var half := TerrainSlice.circumference_chunks() / 2
	return chunk.x < -half + reach or chunk.x >= half - reach

## Make exactly `wanted` ("rx,rz" keys) resident: read the missing ones, release the rest.
## Returns { "loaded": n, "released": n, "failed": n, "adopted": [chunk keys whose generation record
## this sync added or replaced] } for the log line, the tests and the rebuild of built chunks.
func sync(wanted: Dictionary) -> Dictionary:
	var loaded := 0
	var released := 0
	var failed := 0
	var adopted: Array = []
	_wanted_last = wanted
	if async_reads:
		var polled := poll()
		loaded += int(polled["loaded"])
		adopted.append_array(polled["adopted"])
	for rkey in wanted:
		if _resident.has(rkey):
			continue
		var now: int = _now.call()
		if _backoff.has(rkey) and now < int(_backoff[rkey]["until"]):
			failed += 1   # still backing off: no read, no log line
			continue
		if async_reads:
			_start_read(str(rkey))
			continue
		reads_started += 1
		var read := _store.read_region(RegionStore.region_from_key(str(rkey)))
		if not bool(read["ok"]):
			# Not resident: a later sync (the next window move) retries the read once the backoff
			# has elapsed, instead of treating the region as loaded.
			_note_failure(str(rkey))
			failed += 1
			continue
		_adopt_read(str(rkey), read, adopted)
		loaded += 1
	for rkey in _resident.keys():
		if not wanted.has(rkey):
			_stranded[rkey] = true
			_resident.erase(rkey)
			# This sync is the region's first release attempt; its own retry clock starts at the base wait.
			_stranded_wait[rkey] = { "until": int(_now.call()) + STRANDED_RETRY_START_MSEC, "delay": STRANDED_RETRY_START_MSEC }
	# Release every unwanted region's CLEAN chunks. The chunk list is read off the voxel
	# log (not remembered from the file): an edit made after the region was read, in a
	# region that had no file yet, is just as resident.
	if not _stranded.is_empty():
		var by_region: Dictionary = {}
		var edited_keys: Array = _voxel.edited_chunk_keys()   # once per sync
		for ckey in edited_keys:
			var rk := RegionStore.region_key(RegionStore.region_of_chunk_key(str(ckey)))
			if _stranded.has(rk):
				if not by_region.has(rk):
					by_region[rk] = []
				by_region[rk].append(ckey)
		var evicted_from: Dictionary = {}   # rkey -> chunks released from it
		for rkey in _stranded.keys():
			if wanted.has(rkey):
				_stranded.erase(rkey)   # wanted again: re-read above, and memory won
				continue
			var listed: Array = by_region.get(rkey, [])
			var n: int = _voxel.evict_clean_chunks(listed)
			released += n
			evicted_from[rkey] = n >= listed.size()   # true: nothing of the region is left in memory
		# Dirty chunks stay (and their region stays stranded) until a save cleans them.
		for rkey in evicted_from:
			if evicted_from[rkey]:
				_stranded.erase(rkey)
	return { "loaded": loaded, "released": released, "failed": failed, "adopted": adopted }

## Apply a successful region read: its edits into the voxel log, its generation records into the table.
func _adopt_read(rkey: String, read: Dictionary, adopted: Array) -> void:
	_backoff.erase(rkey)
	_voxel.apply_region_chunks(read["chunks"])
	# Phase 108: the region's generation records (a newer generator's stay on disk, unread).
	var readable: Dictionary = {}
	for ckey in read["chunks"]:
		var gen: Variant = (read["chunks"][ckey] as Dictionary).get("gen", null)
		if not RegionStore.is_newer_gen(gen):
			readable[ckey] = read["chunks"][ckey]
	ChunkRecords.adopt_region(readable, adopted)
	_resident[rkey] = true

## Phase 182 — forget every region read, finished or in flight, so the next `sync` reads them all
## again (from a region directory `/regen world` has just emptied). Waits for reads in flight: one
## landing afterwards would adopt the old world's edits and records.
func reset() -> void:
	for rkey in _reading.keys():
		WorkerThreadPool.wait_for_task_completion(_reading[rkey])
	_reading.clear()
	_read_mutex.lock()
	_read_out.clear()
	_read_mutex.unlock()
	_resident.clear()
	_stranded.clear()
	_stranded_wait.clear()
	_backoff.clear()
	_wanted_last.clear()

## Take (and forget) a finished worker read's result.
func _take_read(rkey: String) -> Dictionary:
	_read_mutex.lock()
	var read: Dictionary = _read_out.get(rkey, { "ok": false, "chunks": {} })
	_read_out.erase(rkey)
	_read_mutex.unlock()
	return read

## Start (or grow) the backoff of a region whose read failed.
func _note_failure(rkey: String) -> void:
	var now: int = _now.call()
	@warning_ignore("integer_division")
	var delay := mini(int(_backoff.get(rkey, { "delay": BACKOFF_START_MSEC / 2 })["delay"]) * 2, BACKOFF_MAX_MSEC)
	_backoff[rkey] = { "until": now + delay, "delay": delay }

func _start_read(rkey: String) -> void:
	if _reading.has(rkey):
		return
	reads_started += 1
	_reading[rkey] = WorkerThreadPool.add_task(_read_task.bind(rkey), true, "region read " + rkey)

## The worker body: only the file read runs here (`RegionStore.read_region` is safe off the main thread).
func _read_task(rkey: String) -> void:
	var read := _store.read_region(RegionStore.region_from_key(rkey))
	_read_mutex.lock()
	if record_threads:
		read_thread_ids.append(OS.get_thread_caller_id())
	_read_out[rkey] = read
	_read_mutex.unlock()

## Apply every finished worker read (main thread, never blocks: an unfinished task is left alone).
## A read for a region no longer wanted is dropped; a failed one starts its backoff. Returns
## { "loaded": n, "adopted": [chunk keys] } like `sync`.
func poll() -> Dictionary:
	var loaded := 0
	var adopted: Array = []
	for rkey in _reading.keys():
		if not WorkerThreadPool.is_task_completed(_reading[rkey]):
			continue
		WorkerThreadPool.wait_for_task_completion(_reading[rkey])
		_reading.erase(rkey)
		var read := _take_read(rkey)
		if not _wanted_last.has(rkey) or _resident.has(rkey):
			continue
		if not bool(read["ok"]):
			_note_failure(rkey)
			continue
		_adopt_read(rkey, read, adopted)
		loaded += 1
	return { "loaded": loaded, "adopted": adopted }

## True when every region `chunk` reads with `margin` is resident or has failed (backing off): a chunk
## waits for a read in flight, but never for a region that will not read (it builds without it, as an
## inline failure always did).
func regions_settled(chunk: Vector2i, margin: int) -> bool:
	if not async_reads:
		return true
	for rkey in regions_for_chunks([chunk], margin, margin):
		if _resident.has(rkey):
			continue
		if _backoff.has(rkey) and not _reading.has(rkey):
			continue
		return false
	return true

## Block until every read in flight has finished and been applied (a test, a shutdown). Returns the
## chunk keys whose records the reads adopted.
func flush_reads() -> Array:
	var adopted: Array = []
	for rkey in _reading.keys():
		WorkerThreadPool.wait_for_task_completion(_reading[rkey])
		_reading.erase(rkey)
		var read := _take_read(rkey)
		if _wanted_last.has(rkey) and not _resident.has(rkey) and bool(read["ok"]):
			_adopt_read(rkey, read, adopted)
	return adopted

## Retry the stranded regions without a window move: a save may have cleaned their dirty
## chunks since. Cheap when nothing is stranded. Returns how many chunks were released.
func release_stranded() -> int:
	for rkey in _stranded_wait.keys():
		if not _stranded.has(rkey):
			_stranded_wait.erase(rkey)
	if _stranded.is_empty():
		return 0
	var now: int = _now.call()
	var due: Array = []
	for rkey in _stranded:
		if not _stranded_wait.has(rkey) or now >= int(_stranded_wait[rkey]["until"]):
			due.append(rkey)
	if due.is_empty():
		return 0
	var released := int(sync(_resident.duplicate())["released"])
	# A region still stranded after its retry waits twice as long (up to the cap); a cleaned one is forgotten.
	for rkey in _stranded_wait.keys():
		if not _stranded.has(rkey):
			_stranded_wait.erase(rkey)
	for rkey in due:
		if _stranded.has(rkey):
			var delay := mini(int(_stranded_wait[rkey]["delay"]) * 2, STRANDED_RETRY_MAX_MSEC) if _stranded_wait.has(rkey) else STRANDED_RETRY_START_MSEC
			_stranded_wait[rkey] = { "until": now + delay, "delay": delay }
	return released

## Phase 114 — true when every region `chunk` reads with `margin` is resident (none failed or backing off).
func regions_ready(chunk: Vector2i, margin: int) -> bool:
	for rkey in regions_for_chunks([chunk], margin, margin):
		if not _resident.has(rkey):
			return false
	return true

## True while a failed region read is being backed off.
func is_backing_off(region: Vector2i) -> bool:
	var rkey := RegionStore.region_key(region)
	return _backoff.has(rkey) and int(_now.call()) < int(_backoff[rkey]["until"])

func has_stranded() -> bool:
	return not _stranded.is_empty()

func resident_regions() -> Array:
	return _resident.keys()

func is_resident(region: Vector2i) -> bool:
	return _resident.has(RegionStore.region_key(region))
