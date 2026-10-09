extends Node
## ChunkManager — streams terrain chunks around the player (Phase 17).
##
## Replaces the fixed single-chunk world with a view-distance window: every
## frame (once started) it computes the player's chunk, loads any chunk within
## the streamed radius that isn't loaded yet, and unloads chunks that fell out of
## range. Loading generates the heightmap and spawns the per-chunk creature and
## tree budgets; unloading frees the voxel mesh, despawns non-engaged creatures,
## and drops the chunk's trees.
##
## Phase 42 — the BUILD runs on a worker. Building a chunk (surface mesh + per-column
## collision) is the single most expensive thing this game does, and time-slicing it
## only spread the stall across frames instead of removing it. So a load is now two
## halves: the main thread generates the heightmap and GATHERS the plain state the resolve
## reads (`VoxelSlice.gather_build_input`, which is where the mutable slice state — `_edits`,
## `_heightmaps`, the biome lookup — is read), and a `WorkerThreadPool` task runs the RESOLVE
## (`VoxelSlice.build_runs`) and the PURE build (`VoxelSlice.build_chunk_arrays`) and hands back
## plain arrays. `_process` POLLS the task and applies the result on the main thread — never
## `add_task` + `wait_for_task_completion` in the same frame, which is the
## synchronous build again with extra ceremony.
##
## Phase 42 review pass 9 — the resolve is on the worker too. Until then the main thread paid it
## per dispatch: ~43 ms of per-tile work (measured, see the split probe) against a 16.7 ms frame,
## i.e. the stall the phase exists to remove was still being paid on the main thread, once per
## frame. What the main thread keeps is the noise generation and a handful of copies.
##
## The phase also gates the BOOT on the first ring: `build_first_ring(center)` marks
## the 9 chunks at Chebyshev 0..1 and queues them ahead of the rest, and
## `is_first_ring_ready()` / `first_ring_progress()` let the boot path hold the
## player body (and its loading screen) until the ground it will stand on EXISTS.
## `load_chunk()` still reports `chunk_loaded` when a chunk enters the streamed set
## (its build is dispatched at that point); "the mesh is there" is `_built`.
##
## Phase 42 review — an EDIT rebuilds through the same worker. `request_rebuild(pos)`
## is what `VoxelSlice._rebuild_chunk_at_tile` calls for every chunk whose mesh reads
## the edited tile; it supersedes a build already in flight for that chunk (so an edit
## that lands mid-build is not overwritten by the pre-edit arrays) and dispatches a
## fresh one. A chunk that is not in the streamed set is a no-op — it rebuilds from the
## current edit log when it streams back in.
##
## Phase 42 review — the same pass closed four holes the first one left in the streaming
## loop itself: (1) EVERY dispatch is bounded by `max_builds_in_flight`, including a
## rebuild (`request_rebuild`) and a retry, which used to call `_dispatch_build` outright
## — one corner edit names three chunks, so a single edit or a burst of retries took the
## pool over its own cap. A rebuild the cap defers waits in `_rebuild_queue`, it is never
## dropped. (2) A chunk that leaves the window while QUEUED is dropped rather than built,
## and its `_pending` mark is cleared so it is queued again if it returns (`_within_stream`
## in `_drain_load_queue`). (3) A chunk whose build exhausts MAX_BUILD_RETRIES is put in
## `_failed` and re-armed by `_self_heal_failed`, so a transient failure heals instead of
## leaving a hole for the session. (4) A chunk's
## creature and tree budgets spawn when its GROUND EXISTS (`_spawn_chunk_contents` from
## `_apply_build_entry`) instead of at load time, which is when the build was synchronous.
##
## Phase 42 review pass 3 — four more holes in the SAME loop, all four of them bookkeeping:
## the self-heal was keyed on the window MOVING, so a stationary player (a dedicated
## server's whole shape) never healed a groundless chunk; a rebuild re-derived the chunk's
## creature/tree budgets on EVERY edit, re-scanning every live instance and tree; a rebuild
## that left the streamed set kept its `_rebuild_pending` mark cleared but its `_rebuild_queue`
## entry alive, so a later edit appended a duplicate; and the drain re-read the player's
## chunk once per queued candidate. See `_self_heal_failed`, `_contents_spawned`,
## `_remove_queued_rebuild` and `_within_stream_at`.
##
## Phase 42 review pass 4 — six more, all of them in the self-heal and the streaming
## bookkeeping around it: the sweep SKIPPED a chunk that was `_built`, which is exactly the
## chunk whose REBUILD gave up, so an edited block stayed invisible for the session; the
## sweep re-resolved the player's window per groundless key; the re-arm clock was stamped
## only on the throttled path, so the frame after a crossing was unthrottled; the drain
## resolved the window even with nothing queued; `refresh()` carried two consecutive
## identical `if window_moved:` blocks; and the isolated rig path spawned a chunk's contents
## without the `_contents_spawned` guard the threaded path uses. See `_self_heal_failed`,
## `_drain_load_queue`, `refresh` and `_dispatch_build`.
##
## Plug contract (GameBus signals emitted):
##   OUT : chunk_loaded(chunk_pos), chunk_unloaded(chunk_pos)
##
## Public API:
##   start() / stop()                       — enable/disable automatic streaming
##   refresh()                              — run one synchronous load/unload pass
##   player_chunk() -> Vector2i             — chunk under the player
##   load_chunk(pos) / unload_chunk(pos)    — explicit load/unload
##   request_rebuild(pos)                   — re-dispatch a loaded chunk's build (an edit)
##   get_loaded_chunks() -> Array           — [{ chunk, biome }, ...]
##   build_first_ring(center)               — arm the boot gate; call it BEFORE the first
##                                            `refresh()` of the boot (see there)
##   is_first_ring_ready() -> bool
##   first_ring_progress() -> float         — 0..1, drives the loading bar
const Diag := preload("res://src/core/diag.gd")
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")

## Chunk size is owned by TerrainSlice; world_to_chunk() delegates to it.
const DEFAULT_VIEW_DISTANCE := 3       # Chebyshev radius, in chunks

## Phase 42 — the PURE chunk builder, taken as a SCRIPT, not through the wired
## `voxel_slice` node. That matters: the builder's static methods run on a worker,
## and a task that outlives the tree (a boot that quits with builds in flight) would
## otherwise call into a freed node — `Nonexistent function … in base 'previously
## freed'`, and a crash. A static call through this constant touches no node at all,
## and the lambda's captured value keeps the script resource alive for the task.
const VoxelBuilder := preload("res://src/terrain/voxel_slice.gd")

## Phase 42 — how far BEYOND the view ring a chunk is still queued and kept. The
## streamed window is `view_distance + prefetch_distance`: the load ring leads the
## player's heading, so crossing a boundary requests nothing at the moment it becomes
## needed. `view_distance` stays the radius that is guaranteed fully streamed.
##
## Phase 42 review pass 9 — it is 1, not 2. Everything the queue spans is BUILT, and the
## KEPT window is the queue window again (see `refresh`), so the resident set is the 7×7
## view ring (49) plus a one-chunk lead: 81 chunks (9×9) against the 121 (11×11) that pass 8
## was avoiding, and no chunk is built and then thrown away. A one-chunk lead is already
## enough for the ring a crossing walks into to be built when it arrives.
const DEFAULT_PREFETCH_DISTANCE := 1

## Phase 42 — the boot gate's radius: Chebyshev 0..1 around the centre, the chunk the
## body stands in plus its eight neighbours. Wider would make the loading screen a
## long wait for ground the player cannot reach in the first second.
const FIRST_RING_RADIUS := 1

## Chunk builds to drain from the load queue each frame. Dispatching is cheap now (the
## build itself is on a worker), so this bounds how many chunks are handed out per
## frame rather than how much main-thread work is done. Overridable for tuning/tests.
const DEFAULT_LOADS_PER_FRAME := 1

## Phase 42 — how many worker builds may be in flight at once. Bounds the memory a
## burst of dispatches can hold (each task holds its heightmap + column table) and
## keeps the pool available for other work; results are applied as they complete.
const DEFAULT_MAX_BUILDS_IN_FLIGHT := 4

## Phase 49 — chunk unloads per `_process` tick. A crossing releases 9-17 chunks at once and
## each unload frees a mesh, a trimesh and the chunk's creatures and trees; spreading them
## over frames, like loads, removes that spike. `refresh()` itself still unloads everything
## synchronously (its contract); only the per-frame `_process` path is budgeted.
const DEFAULT_UNLOADS_PER_FRAME := 4

## Phase 42 review — how many times one chunk's build may be dispatched before the
## manager gives up on it and reports the failure. It exists because a worker result can
## now be REFUSED (an empty result, or a chunk rebuilt under it) and a refusal is answered
## with a fresh dispatch; without a cap a build that always fails would spin every frame.
## A fresh edit (`request_rebuild`) resets the budget, so the cap only ever stops a retry
## loop, never a rebuild the player asked for.
const MAX_BUILD_RETRIES := 3

## Phase 42 review pass 8 — how many rounds `flush_builds()` may take before it gives up
## waiting for the in-flight table to empty. One round reaps every task the previous round
## dispatched, so the number of rounds is the length of the longest retry chain rather than
## a frame budget; the cap is here so a build that fails forever cannot spin the blocking
## caller (it ends up in `_failed` for the self-heal, and the retry cap stops it anyway).
const FLUSH_MAX_ROUNDS := 16

## Phase 42 review pass 3 — seconds between self-heal attempts for a chunk whose build gave
## up, while the window is NOT moving (see `_self_heal_failed`). A crossing skips the
## throttle entirely, because a crossing is the signal the re-arm was always keyed on;
## this interval is what makes the STATIONARY case — a dedicated server, or a player who
## is standing still — heal at all without re-dispatching a permanently failing build
## every frame. Overridable for tuning/tests.
const DEFAULT_SELF_HEAL_INTERVAL := 5.0

## Set by game_root before the slices enter the tree.
var terrain_slice: Node = null
var voxel_slice: Node = null
var player_slice: Node = null
var creature_slice: Node = null
var tree_slice: Node = null

## Chebyshev radius in chunks. Overridable (tests use a small radius).
var view_distance: int = DEFAULT_VIEW_DISTANCE

## How far beyond `view_distance` a chunk is still queued and kept (Phase 42).
var prefetch_distance: int = DEFAULT_PREFETCH_DISTANCE

## Chunk dispatches to process per _process tick (see DEFAULT_LOADS_PER_FRAME).
var loads_per_frame: int = DEFAULT_LOADS_PER_FRAME

## Chunk unloads to process per _process tick (see DEFAULT_UNLOADS_PER_FRAME).
var unloads_per_frame: int = DEFAULT_UNLOADS_PER_FRAME

## Worker builds allowed in flight at once (see DEFAULT_MAX_BUILDS_IN_FLIGHT).
var max_builds_in_flight: int = DEFAULT_MAX_BUILDS_IN_FLIGHT

## Phase 42 review pass 3 — seconds between self-heal attempts while the window is not moving
## (see DEFAULT_SELF_HEAL_INTERVAL / `_self_heal_failed`). Overridable for tests.
var self_heal_interval: float = DEFAULT_SELF_HEAL_INTERVAL

var _loaded: Dictionary = {}   # "cx,cz" -> true
## Phase 42 — chunks whose BUILD has landed (mesh + collision attached), as opposed
## to `_loaded`, which only says the chunk was taken into the streamed set. The
## first-ring gate reads THIS: the body may stand on a built chunk, never on a queued
## one.
var _built: Dictionary = {}    # "cx,cz" -> true
var _active: bool = false

## Phase 52 — per-peer windows. The dedicated server used to stream around ONE centre, the idle
## body at the origin, so creatures and trees only lived near it. Each connected peer now adds a
## window centred on that peer's chunk (`set_peer_center`), and the server streams the UNION of
## them with the local player's own window (the listen host's, or the idle body's).
## `_peer_centers` maps peer_id -> the chunk that peer's window is centred on.
## `_last_centers` is the window set the last refresh resolved, so a peer crossing a chunk is a window move.
## `_chunk_refs` counts, per chunk key, how many windows cover it; a chunk is wanted while its count is above zero.
## The load and unload paths release a chunk only at count zero.
var _peer_centers: Dictionary = {}
var _last_centers: Array = []
var _chunk_refs: Dictionary = {}   # "cx,cz" -> number of windows covering it (read by `chunk_ref_count`)

## Phase 62 — a peer's window follows the position its CLIENT reports, so it is bounded: at most
## one recentre per peer per `PEER_RECENTER_INTERVAL` seconds, and a single accepted move
## travels at most `PEER_RECENTER_MAX_CHUNKS` chunks (Chebyshev) toward the reported chunk.
## A move the host itself orders (join, spawn placement) is exempt. Without it a modified
## client could make the host read regions and queue chunk builds as fast as it can send packets.
const PEER_RECENTER_INTERVAL := 0.25
const PEER_RECENTER_MAX_CHUNKS := 8
## peer_id -> `now_msec` time of the last accepted client claim (`set_peer_center`) or host placement.
var _peer_last_claim_msec: Dictionary = {}
## peer_id -> `now_msec` time of the last accepted host sync (`sync_peer_center`) or host placement.
## Kept apart from the claim clock so a sync move never makes an honest claim look too early.
var _peer_last_sync_msec: Dictionary = {}
## Millisecond clock for the peer-window rate limit, self-heal and stranded-region retry; a test swaps it for a fake.
var now_msec: Callable = Time.get_ticks_msec
## Swap the millisecond clock and forget every timestamp taken from the old one (stranded-retry,
## self-heal and per-peer interval), so a stale stamp never throttles against the new clock.
func set_clock(c: Callable) -> void:
	now_msec = c
	_last_stranded_retry_msec = -STRANDED_RETRY_MSEC
	_last_self_heal_msec = -1
	for peer_id in _peer_last_claim_msec:
		_peer_last_claim_msec[peer_id] = -1000000
	for peer_id in _peer_last_sync_msec:
		_peer_last_sync_msec[peer_id] = -1000000

## Client-driven moves refused (rate-limited) or clamped (too far in one step), for the log line and tests.
var peer_recenter_refused: int = 0
## Host syncs (`sync_peer_center`) that moved a window farther than `PEER_RECENTER_MAX_CHUNKS` in one step
## (the move still applies, clamped): an abuse signal that never inflates `peer_recenter_refused`.
var peer_sync_far_hops: int = 0

## Phase 52 — the region streamer (src/persistence/region_streamer.gd), or null on a client /
## in an isolated rig. Told which chunks the windows want on every window move so the edits of
## the regions around every player are resident before their chunks are built.
var region_streamer = null

## Chunks queued for loading, ordered nearest-first to the player. Drained a
## bounded number per frame by _drain_load_queue().
var _load_queue: Array = []    # of Vector2i
## Chunks enqueued but not yet built; dedupes against _load_queue so a refresh
## pass never double-queues a chunk already waiting to load.
var _pending: Dictionary = {}  # "cx,cz" -> true

## Phase 49 — loaded chunks that fell out of the window and wait for their unload slot,
## drained `unloads_per_frame` per tick by `_drain_unload_queue`. The queue is rebuilt from
## scratch on every window move (`refresh`), so a chunk the player walked back toward is
## dropped from it by the next move and never unloaded.
var _unload_queue: Array = []  # of "cx,cz" keys

## Phase 42 — worker builds in flight, keyed by WorkerThreadPool task id:
## { chunk, key, heightmap, revision, result }. `result` is a one-slot Array the
## task writes its plain arrays into; the main thread reads it only after
## `is_task_completed()` says the task is done.
var _builds: Dictionary = {}

## Phase 42 review — dispatches spent on each chunk, keyed "cx,cz" -> int, against
## MAX_BUILD_RETRIES (see `_apply_build_entry`). Cleared when a build attaches, when a
## fresh rebuild is requested, and when the chunk is unloaded.
var _build_attempts: Dictionary = {}

## Phase 42 review — rebuild requests that could NOT be dispatched yet because the
## in-flight cap was reached. `_drain_load_queue` drains them under the SAME cap that
## bounds a streamed load, because `request_rebuild` used to call `_dispatch_build`
## directly: a corner edit (three touched chunks) or a burst of retries then put four,
## five, six tasks in the pool against a `max_builds_in_flight` of four. A rebuild is
## never DROPPED by the cap — it waits a frame, which is why it is a queue and not a
## refusal.
var _rebuild_queue: Array = []         # of Vector2i
var _rebuild_pending: Dictionary = {}  # "cx,cz" -> true, dedupes _rebuild_queue

## Phase 42 review — chunks whose build exhausted MAX_BUILD_RETRIES and were reported
## as groundless. They are re-armed by `_self_heal_failed` instead of staying a hole for
## the session: a build failure that was transient heals, and a permanent one costs one
## RE-ARM per interval rather than a per-frame spin.
##
## **(Phase 42 review pass 10: a re-arm starts a FRESH retry budget — `_self_heal_failed`
## clears `_build_attempts`, and three tests assert it — so one re-arm is up to
## `MAX_BUILD_RETRIES` dispatches, not the single dispatch the older wording here and in the
## give-up message implied. The throttle bounds the re-arm CADENCE (one re-arm per interval
## while the window is stationary); the dispatches within a re-arm are the retry loop's.)**
## **(Phase 42 review pass 3: a crossing re-arms immediately, and an UNMOVED window re-arms
## on a wall-clock interval — keying it on the crossing alone meant a stationary player,
## which is a dedicated server's whole shape, never healed at all. Pass 4: the sweep no
## longer requires `not _built`, so a chunk whose REBUILD gave up — `_built` still true,
## its old mesh still attached, the edit invisible — is re-armed too.)**
var _failed: Dictionary = {}           # "cx,cz" -> true

## Phase 42 review pass 3 — the wall-clock throttle on the self-heal re-arm while the window
## is NOT moving (`_self_heal_failed`). -1 is the "never attempted" sentinel, so the first
## attempt after a chunk goes groundless is never throttled by how long the process has
## been up.
var _last_self_heal_msec: int = -1

## Phase 42 review pass 3 — chunks whose per-chunk CONTENTS (the creature and tree budgets)
## have already been spawned, keyed "cx,cz" -> true. Contents belong to a chunk's
## RESIDENCY, not to its build: an edit rebuilds a loaded chunk, and the apply path used
## to re-run `_spawn_chunk_contents` for it every time, which re-scanned every live
## instance (once per creature in the fabric) and every live tree to re-derive a budget
## that could not have changed. Cleared on unload, so a chunk that streams back in
## repopulates.
var _contents_spawned: Dictionary = {} # "cx,cz" -> true

## Phase 42 — the boot gate. `_first_ring` maps "cx,cz" -> built?, and an EMPTY map
## means the gate was never armed (so `is_first_ring_ready()` answers true for every
## caller that has no boot to hold).
var _first_ring: Dictionary = {}
var _first_ring_center: Vector2i = Vector2i.ZERO

func _process(_delta: float) -> void:
	# Phase 42 review — the APPLY pass runs whether or not streaming is active. `stop()`
	# only ends NEW work; a build already in flight belongs to a chunk that is still
	# loaded, and while the poll sat behind the `_active` guard nothing applied it and
	# nothing awaited it — the chunk was left without a mesh and the task's result sat in
	# the pool until shutdown (the same exit-134 leak `_exit_tree` now closes there).
	_apply_finished_builds()
	if not _active:
		return
	_drain_load_queue()
	refresh(false)
	_drain_unload_queue(unloads_per_frame)

## Begin automatic streaming (driven by _process). The first `refresh()` is what
## centres the window, so the caller places the player before calling it —
## `_boot_host()` reaches it through `_boot_server()` before the spawn and then
## re-centres with a second `refresh()`, while a dedicated server simply streams
## around the player's pre-spawn position (the origin) and never moves it.
func start() -> void:
	_active = true

## Stop automatic streaming (keeps currently loaded chunks).
func stop() -> void:
	_active = false

## One streaming pass: queue missing chunks in range (nearest-first), unload
## chunks out of range. Skips the diff entirely when the player hasn't moved to
## a new chunk since the last call. Loads are NOT built here — they go onto
## _load_queue and are drained a bounded number per frame by _drain_load_queue.
##
## Phase 42 review pass 8 — the KEPT window and the LOAD window are two different radii.
## The load queue spans `stream_radius()` (`view_distance + prefetch_distance`) so the ring
## that leads the player's heading is ALREADY queued when the crossing happens, and the KEPT
## window was narrowed to `view_distance`: what a crossing retains — a resident mesh, its
## trimesh, its creatures and its trees — was the view ring, not the prefetch band, which
## put 49 resident chunks (7×7) where `stream_radius()` had kept 121 (11×11).
##
## **(NINTH review pass: that narrowing locked a WASTE in, and it is reverted. Everything in
## the load queue is BUILT, so a band chunk was built on the worker and then released on the
## next crossing unless the player happened to move toward it — the row measured 65 redundant
## worker builds per crossing, forever. The kept window is the QUEUE window again
## (`stream_radius()`), so nothing is ever unloaded while it still lies inside the radius it
## was queued at, which is also what `_test_chunk_kept_window_is_stream_radius` now asserts.
## The memory pass 8 was protecting is bounded by the radius instead of by a second window:
## `DEFAULT_PREFETCH_DISTANCE` is 1, so the resident set is 81 chunks (9×9) — the 49-chunk
## view ring plus a one-chunk lead — rather than 121.)**
func refresh(unload_now: bool = true) -> void:
	var center := player_chunk()
	var centers := _centers_around(center)
	var window_moved := centers != _last_centers
	# Phase 42 review pass 4 — ONE `window_moved` decision, not two consecutive blocks.
	# The sentinel update and the load/unload diff are the SAME pass; the early return
	# below is what the second block's `if` was really expressing.
	if not window_moved:
		# Nothing to queue or unload — but the self-heal still runs, and it must: a
		# STATIONARY player (a dedicated server's whole shape) is exactly the case a
		# groundless chunk needs re-arming in. See `_self_heal_failed`.
		_self_heal_failed(centers, false)
		_retry_stranded_regions()
		return

	_last_centers = centers
	# ONE radius for WANTED and DESIRED on purpose (ninth review pass): `wanted` — what a
	# crossing retains — is the same radius the queue spans, so no chunk that was queued (and
	# therefore built) is released while it is still inside the window it was built for. See
	# the docstring above for why the two radii were briefly different and why that was a waste.
	var radius := stream_radius()
	var desired: Array = []
	var refs: Dictionary = {}
	for win_center in centers:
		for c in _desired_chunks(win_center, radius):
			if not _in_bounds(c):
				continue
			var ckey := _chunk_key(c)
			if not refs.has(ckey):
				desired.append(c)
				refs[ckey] = 0
			refs[ckey] += 1
	_chunk_refs = refs
	# Phase 52 — the edits of every region the windows touch are resident BEFORE a chunk is
	# queued, so no build reads a log that is missing its region.
	if region_streamer != null:
		region_streamer.sync(region_streamer.regions_for_chunks(desired))

	# Queue loads nearest-first. Dispatching is what is bounded per frame; the build
	# itself runs on a worker.
	var to_load: Array = []
	for c in desired:
		var key := _chunk_key(c)
		if _in_bounds(c) and not _loaded.has(key) and not _pending.has(key):
			to_load.append(c)
	to_load.sort_custom(func(a, b): return _nearest_dist2(centers, a) < _nearest_dist2(centers, b))
	for c in to_load:
		_pending[_chunk_key(c)] = true
		_load_queue.append(c)

	# Phase 49 — a synchronous `refresh()` unloads everything now; the `_process` path
	# (`unload_now == false`) queues the stale chunks and `_drain_unload_queue` releases a
	# bounded number per frame.
	if unload_now:
		for key in _loaded.keys():
			if not _chunk_refs.has(key):
				unload_chunk(_key_to_chunk(key))
		_unload_queue.clear()
	else:
		# Farthest first. The distance is computed once per stale chunk (decorate, sort,
		# undecorate) rather than twice per comparison, which parsed two keys per compare.
		var stale: Array = []
		for key in _loaded.keys():
			if not _chunk_refs.has(key):
				stale.append([_nearest_dist2(centers, _key_to_chunk(key)), key])
		stale.sort_custom(func(a, b): return a[0] > b[0])
		_unload_queue.clear()
		for entry in stale:
			_unload_queue.append(entry[1])

	_self_heal_failed(centers, true)

## Phase 52 — a region released while its chunks were dirty stays resident until a save has
## cleaned them. A stationary window never reaches `RegionStreamer.sync`, so retry here,
## throttled: saves land every autosave interval, not every frame.
const STRANDED_RETRY_MSEC := 2000
var _last_stranded_retry_msec: int = 0

func _retry_stranded_regions() -> void:
	if region_streamer == null or not region_streamer.has_stranded():
		return
	var now: int = now_msec.call()
	if now - _last_stranded_retry_msec < STRANDED_RETRY_MSEC:
		return
	_last_stranded_retry_msec = now
	region_streamer.release_stranded()

## Phase 49 — release up to `budget` queued chunks, farthest first. The queue is rebuilt from
## scratch on every window move, so it never holds a chunk that is inside the current window.
func _drain_unload_queue(budget: int) -> void:
	while budget > 0 and not _unload_queue.is_empty():
		var key: String = _unload_queue.pop_front()
		# A chunk a window has covered again since it was queued stays loaded.
		if _loaded.has(key) and not _chunk_refs.has(key):
			unload_chunk(_key_to_chunk(key))
			budget -= 1

## Phase 42 review — SELF-HEAL. A chunk in range that is loaded but has no built mesh
## is one whose build exhausted MAX_BUILD_RETRIES (see `_apply_build_entry`) and was
## reported as groundless. Left alone it stays a hole for the session: nothing else
## re-dispatches a chunk that is already `_loaded`.
##
## Phase 42 review pass 3 — and it runs on EVERY `refresh()`, not only on one that
## re-centres the window. Keying the re-arm on the window MOVING left a stationary
## player with no self-heal at all: a dedicated server streams around a fixed origin
## and a host player standing still never changes chunk, so `refresh()` returned before
## ever reaching this loop — exactly the case where a groundless chunk persists. The
## backoff is therefore WALL-CLOCK: a crossing re-arms immediately (it is the natural
## signal, and the reason a crossing is still preferred), while an unmoved window
## re-arms at most once per `self_heal_interval`. A build that fails forever is therefore
## re-armed once per interval rather than spun every frame.
##
## Phase 42 review pass 10 — but "re-armed once per interval" is NOT "one dispatch per
## interval": the re-arm clears `_build_attempts` (a FRESH budget, which three tests assert),
## so a re-armed build that keeps failing spends up to `MAX_BUILD_RETRIES` dispatches before it
## gives up again. The throttle bounds how often a re-arm happens, not how many dispatches one
## re-arm costs — the earlier wording here and in the give-up message claimed the wrong half.
##
## Phase 42 review pass 4 — three more things this sweep got wrong, all of them in the
## same twenty lines:
##   * It SKIPPED a groundless chunk that was `_built`. `_failed` is set by a build that
##     gave up, and for an already-built chunk that is a REBUILD which gave up (an edit):
##     the OLD mesh is still attached, so `_built` is true and the old guard jumped over
##     exactly the case where an edited block stays invisible forever.
##   * It re-derived the streamed window per candidate (`_within_stream`), which re-read
##     the player's position for every groundless key. The caller already resolved
##     `center`, so the sweep takes it and uses `_within_stream_at`.
##   * It stamped `_last_self_heal_msec` only on the THROTTLED path. A crossing re-armed
##     and left the clock at its old value, so the very next (stationary) frame was
##     unthrottled and re-armed again. The clock is stamped whenever the sweep proceeds,
##     crossing or not.
func _self_heal_failed(centers: Array, window_moved: bool) -> void:
	if _failed.is_empty():
		return
	var now: int = now_msec.call()
	if not window_moved:
		if _last_self_heal_msec >= 0 and now - _last_self_heal_msec < int(self_heal_interval * 1000.0):
			return
	# Phase 42 review pass 4 — the clock is stamped on BOTH paths. Stamping only the
	# throttled one left the frame right after a crossing unthrottled (the crossing had
	# re-armed immediately and left `_last_self_heal_msec` at its old value), so a
	# stationary player resumed the interval from the crossing instead of after it.
	_last_self_heal_msec = now
	var radius := stream_radius()
	for key in _failed.keys():
		if _within_windows(centers, radius, _key_to_chunk(key)) and not _has_in_flight(key):
			_failed.erase(key)
			_build_attempts.erase(key)
			_queue_rebuild(_key_to_chunk(key))

## The Chebyshev radius a chunk is queued and kept within (Phase 42).
func stream_radius() -> int:
	return view_distance + prefetch_distance

## Dispatch up to `loads_per_frame` queued chunks this frame, nearest-first, while
## respecting the in-flight build cap. The build itself runs on a worker.
##
## Phase 42 review — this is now the ONE place a build is dispatched from a queue, and
## it drains the REBUILD queue first: `request_rebuild` and a build RETRY both enqueue
## here instead of calling `_dispatch_build` directly, so the in-flight cap bounds every
## dispatch and not just a streamed load. Dispatch is the only thing bounded per frame;
## a queued rebuild is never dropped, it waits.
## **(Ninth review pass: those callers reach the queue through `_dispatch_build`'s OWN cap
## guard now, and so does the public `load_chunk` — the cap bounds every dispatch, not only
## the ones an internal caller happened to check first. See `_dispatch_build`.)**
func _drain_load_queue() -> void:
	# Phase 42 review pass 4 — a drain with NOTHING queued has nothing to dispatch, so it
	# does not resolve the window at all. `_process` calls this every tick, and the read
	# below is a `PlayerSlice.get_position()` call; the empty case is the common one
	# (a settled window drains nothing until the player crosses a chunk boundary).
	if _load_queue.is_empty() and _rebuild_queue.is_empty():
		return
	var budget := loads_per_frame
	# Phase 42 review pass 3 — the streamed window is resolved ONCE for the whole drain. The
	# player's chunk cannot move during it (the position is re-read at the next frame's
	# `refresh()`), and the per-chunk form re-derived it — a slice call — for every
	# candidate, so a drain of a full view ring paid ~49 of them to reach the same answer.
	var centers := window_centers()
	var radius := stream_radius()
	while budget > 0:
		if _builds.size() >= max_builds_in_flight:
			return   # the pool is busy: leave the rest queued for a later frame
		if not _rebuild_queue.is_empty():
			var rebuild: Vector2i = _rebuild_queue.pop_front()
			var rkey := _chunk_key(rebuild)
			_rebuild_pending.erase(rkey)
			# Streamed out while it waited: nothing to rebuild (it rebuilds from the
			# current edit log when it streams back in).
			if _loaded.has(rkey):
				_dispatch_build(rebuild)
				budget -= 1
			continue
		if _load_queue.is_empty():
			return
		var chunk: Vector2i = _load_queue.pop_front()
		_pending.erase(_chunk_key(chunk))
		# Phase 42 review — CANCELLATION. A chunk can leave the streamed window while it
		# sits in the queue (the player turned around). Dispatching it anyway built ground
		# nobody wants — and `refresh()` would not re-queue it on the way back in, because
		# its `_pending` mark was still set, so it was silently skipped instead. Dropping
		# it here clears that mark, so a chunk that leaves range and returns is queued
		# again rather than left as a hole.
		if not _within_windows(centers, radius, chunk):
			continue
		if not _loaded.has(_chunk_key(chunk)):
			load_chunk(chunk)
		budget -= 1

## Take a chunk into the streamed set, announce it, and dispatch its terrain build.
##
## Phase 42 — the mesh is no longer produced here. The heightmap is generated and the
## column table resolved on this (main) thread, then `VoxelSlice.build_chunk_arrays`
## runs on a worker and `_apply_finished_builds()` attaches the result once it is
## done. `chunk_loaded` therefore means "this chunk is in the streamed set", and
## `_built` is what says its ground exists.
##
## Phase 42 review — the creature and tree budgets are NO LONGER spawned here. They are
## the ground's contents, so they are spawned once the ground exists
## (`_spawn_chunk_contents`, from the apply path). Spawning them at load time was free
## while the build was synchronous; with the build on a worker it put the population on
## a chunk whose mesh arrived a frame or more later.
func load_chunk(chunk_pos: Vector2i) -> void:
	var key := _chunk_key(chunk_pos)
	if _loaded.has(key):
		return
	_loaded[key] = true
	GameBus.chunk_loaded.emit(chunk_pos)
	rebuild_seam_neighbours(chunk_pos)
	_dispatch_build(chunk_pos)

## Phase 49/69 — a built neighbour of a chunk that just entered the streamed set saw it as a
## GUESS (its generated heightmap, because the chunk was not yet known). When the arriving chunk
## carries edits, that guess may no longer match what the chunk shows, so each built neighbour
## rebuilds once, now that the real column data is available. A chunk with no height-changing
## edit is exactly its generated guess, so nothing rebuilds and a fresh world pays nothing.
## Phase 69 — rebuild the built neighbours of `chunk_pos` across the borders that carry a
## height-changing edit (`VoxelSlice.seam_borders`; deplete-only edits count for nothing), at most
## once per chunk per edit revision.
## Called when a chunk streams in and when edits for an already-loaded chunk arrive.
func rebuild_seam_neighbours(chunk_pos: Vector2i) -> void:
	if voxel_slice == null or not voxel_slice.has_method("seam_borders") \
			or not voxel_slice.has_method("edit_revision"):
		return
	var key := _chunk_key(chunk_pos)
	# A chunk outside the streamed set records nothing: it must still rebuild its neighbours when
	# it streams in, and an entry here would never be cleared by `unload_chunk`.
	if not _loaded.has(key):
		return
	var rev: int = voxel_slice.edit_revision(chunk_pos)
	if _seam_revision.get(key, -1) == rev:
		return
	var complete := true
	for off in voxel_slice.seam_borders(chunk_pos):
		var n: Vector2i = chunk_pos + off
		var nkey := _chunk_key(n)
		if not _built.has(nkey):
			# Loaded but still building: its build may predate the edit, so leave the revision
			# open and let a later call retry.
			if _loaded.has(nkey):
				complete = false
			continue
		request_rebuild(n)
	if complete:
		_seam_revision[key] = rev

## Phase 69 — how many rebuilds each loaded chunk has been asked for (chunk key → count). Read
## only through the test hooks below.
var _rebuild_requests: Dictionary = {}

## Test hooks over the rebuild counter (the game never reads it).
func rebuild_request_count(chunk_pos: Vector2i) -> int:
	return int(_rebuild_requests.get(_chunk_key(chunk_pos), 0))

func rebuilt_chunk_keys() -> Array:
	return _rebuild_requests.keys()

func reset_rebuild_requests() -> void:
	_rebuild_requests.clear()

## Phase 69 — the edit revision each chunk's seams were last rebuilt for.
var _seam_revision: Dictionary = {}

## Phase 42 review — spawn a chunk's per-chunk creature and tree budgets. Called once the
## chunk's GROUND EXISTS (see `_apply_build_entry`) rather than when it enters the
## streamed set, so no body stands on a chunk that has not been built yet.
func _spawn_chunk_contents(chunk_pos: Vector2i) -> void:
	if creature_slice != null and creature_slice.has_method("spawn_for_chunk"):
		creature_slice.spawn_for_chunk(chunk_pos)
	if tree_slice != null and tree_slice.has_method("spawn_for_chunk"):
		tree_slice.spawn_for_chunk(chunk_pos)

## Hand one chunk's build to a worker task. Main-thread work: the heightmap generation and the
## GATHER of the plain state the resolve reads (`gather_build_input` — that is where `_edits`,
## `_heightmaps` and the biome lookup are read). Worker work: the whole resolve
## (`VoxelSlice.build_runs`) AND the pure build (`build_chunk_arrays`), both of which return plain
## arrays the main thread attaches later, in `_apply_finished_builds()`.
##
## Phase 42 review pass 9 — the resolve moved to the worker (see `gather_build_input` and
## `build_runs`). It used to be the main thread's half of every dispatch, and at ~43 ms per chunk
## it was the stall the phase exists to remove, still being paid on the main thread once per
## frame; what remains there is the noise generation and a handful of copies.
func _dispatch_build(chunk_pos: Vector2i) -> void:
	var key := _chunk_key(chunk_pos)
	# An isolated rig (the suite wires no terrain/voxel) has nothing to build, and the
	# chunk is "built" the moment it is loaded — otherwise a gate would hang forever.
	if terrain_slice == null or voxel_slice == null \
			or not terrain_slice.has_method("generate_heightmap") \
			or not voxel_slice.has_method("build_chunk_arrays"):
		_built[key] = true
		# Phase 42 review pass 4 — and the CONTENTS obey the same residency rule as the
		# threaded path (`_contents_spawned`): a rig with no terrain/voxel has nothing to
		# build, but an edit still reaches here through `request_rebuild`, and spawning the
		# chunk's budgets on every such call re-derived a population that was already standing
		# there. The rig used to spawn unconditionally because it never had a second call.
		if not _contents_spawned.has(key):
			_contents_spawned[key] = true
			_spawn_chunk_contents(chunk_pos)
		_update_first_ring_progress()
		return
	# Phase 42 review pass 9 — the in-flight cap is enforced HERE, not only at the call
	# sites. Every internal caller checked it before dispatching, but `load_chunk()` is
	# PUBLIC and dispatched outright: a direct load (a test, a future caller) put the pool
	# over `max_builds_in_flight`. The deferral goes to `_rebuild_queue`, which
	# `_drain_load_queue` drains under this same cap; the chunk is already `_loaded` (both
	# `load_chunk` and `request_rebuild` mark it first), so the drain's rebuild branch is
	# exactly the path that re-dispatches it. Delayed a frame, never dropped.
	if _builds.size() >= max_builds_in_flight:
		_queue_rebuild(chunk_pos)
		return
	# Phase 42 review — SUPERSEDE a build already in flight for this chunk. The caller
	# reaches here for a chunk whose data changed under an in-flight build (see
	# `request_rebuild`), and the older task's arrays describe the terrain BEFORE that
	# change. It cannot simply be erased from `_builds`: the pool keeps a task alive until
	# it is awaited, so it is marked instead and reaped by `_apply_build_entry`, which
	# neither attaches it nor re-dispatches it. Without this the two tasks carry the same
	# revision and BOTH attach, so the mesh could end up the pre-edit one.
	_supersede_in_flight(key)
	# This dispatch satisfies any deferred one still waiting in `_rebuild_queue` (an earlier
	# call the cap deferred). Left there, the drain would dispatch the chunk a second time and
	# supersede the build just started — a wasted worker build and a spent retry.
	if _rebuild_pending.has(key):
		_rebuild_pending.erase(key)
		_remove_queued_rebuild(key)
	_build_attempts[key] = int(_build_attempts.get(key, 0)) + 1
	# A neighbour's gather may already have generated this chunk's map (its seam guess);
	# the voxel slice hands that one over instead of recomputing the noise here.
	var heightmap: Array = voxel_slice.take_heightmap_for_build(chunk_pos) \
		if voxel_slice.has_method("take_heightmap_for_build") \
		else terrain_slice.generate_heightmap(chunk_pos)
	# Phase 42 review pass 9 — the RESOLVE runs on the worker too. The main thread only GATHERS the
	# plain state it reads (`gather_build_input`); before this, resolving the chunk's runs, colours
	# and deposits cost ~43 ms of per-tile work on the main thread per dispatch — 2.7 frames at
	# 60 Hz, and the one main-thread cost the earlier passes left behind (measured; see the split
	# probe). The payload is plain data only (heightmap arrays, deep-copied edit lists,
	# chunk-keyed biomes), so the task may hold it.
	var gathered: Dictionary = voxel_slice.gather_build_input(chunk_pos, heightmap)
	var revision: int = int(voxel_slice.chunk_revision(chunk_pos))
	var result: Array = [null]
	var task_id := WorkerThreadPool.add_task(
		func(): result[0] = VoxelBuilder.build_chunk_arrays(chunk_pos, heightmap,
			VoxelBuilder.build_runs(chunk_pos, heightmap, gathered)),
		false, "chunk build %s" % key)
	_builds[task_id] = {
		"chunk":     chunk_pos,
		"key":       key,
		"heightmap": heightmap,
		"revision":  revision,
		"result":    result,
	}

## Mark any build already in flight for `key` as stale, so `_apply_build_entry` reaps it
## without attaching it and without re-dispatching. Split out of `_dispatch_build` by the
## Phase 42 review because `request_rebuild` has to do it even when the fresh dispatch is
## deferred by the in-flight cap: otherwise a pre-edit mesh would stay on screen until the
## queued dispatch got a slot.
func _supersede_in_flight(key: String) -> void:
	for stale_id in _builds.keys():
		if _builds[stale_id]["key"] == key:
			_builds[stale_id]["superseded"] = true

## Phase 42 review — rebuild an already-loaded chunk whose DATA changed under it: a voxel
## edit (see `VoxelSlice._rebuild_chunk_at_tile`). It goes to a worker like every other
## build, which is the point: an edit used to rebuild up to three chunks SYNCHRONOUSLY in
## the frame that placed the block, which is exactly the stall the worker exists to remove.
##
## A chunk that is not in the streamed set is a no-op: it has no node to refresh, it
## rebuilds from the current edit log when it streams back in (see `apply_edits`), and
## building it here would resurrect a chunk the manager has already streamed away.
##
## Phase 42 review — the dispatch respects `max_builds_in_flight`, because this is the
## call that used to bypass it: an edit at a chunk corner names three touched chunks, and
## each one was dispatched outright, so one corner edit put the pool over its own cap and
## so did every retry. It defers to the rebuild queue instead — never drops — and the
## supersede happens UNCONDITIONALLY so the pre-edit build cannot land while it waits.
func request_rebuild(chunk_pos: Vector2i) -> void:
	var key := _chunk_key(chunk_pos)
	if not _loaded.has(key):
		return
	_rebuild_requests[key] = int(_rebuild_requests.get(key, 0)) + 1
	# A fresh request starts a fresh retry budget: it is a new edit, not a retry of one,
	# and it clears the groundless mark a previous give-up left behind.
	_build_attempts.erase(key)
	_failed.erase(key)
	_supersede_in_flight(key)
	# Phase 42 review pass 9 — no cap check here: `_dispatch_build` enforces the cap itself
	# (deferring to `_rebuild_queue`), so the rule lives in ONE place. The supersede above
	# stays unconditional on purpose — the pre-edit build must not land while it waits.
	_dispatch_build(chunk_pos)

## Enqueue a build that could not be dispatched right now because the in-flight cap was
## reached — `_dispatch_build`'s own cap guard is the one caller (ninth review pass: a
## streamed load, `request_rebuild` and a build RETRY all arrive through it). Deduped, and
## drained by `_drain_load_queue` under the same cap. A build is delayed, never dropped.
func _queue_rebuild(chunk_pos: Vector2i) -> void:
	var key := _chunk_key(chunk_pos)
	if _rebuild_pending.has(key):
		return
	_rebuild_pending[key] = true
	_rebuild_queue.append(chunk_pos)

## Phase 42 review pass 3 — drop a chunk's queued-but-undispatched rebuild, entry AND mark.
## `unload_chunk` needs this: the dedupe reads `_rebuild_pending`, so clearing the mark
## while the queue entry survived made a later `_queue_rebuild` for the same chunk append
## a second entry — two dispatches for one chunk under one revision.
func _remove_queued_rebuild(key: String) -> void:
	if _rebuild_queue.is_empty():
		return
	var kept: Array = []
	for c in _rebuild_queue:
		if _chunk_key(c) != key:
			kept.append(c)
	_rebuild_queue = kept

## True when a worker build for `key` is in flight (superseded or not).
func _has_in_flight(key: String) -> bool:
	for task_id in _builds.keys():
		if _builds[task_id]["key"] == key:
			return true
	return false

## True when `chunk` still lies inside the streamed window around the player (Chebyshev,
## like `stream_radius`). The single-check accessor form: it resolves the window itself, so
## the loops that test MANY chunks — `_drain_load_queue`'s cancellation check and
## `_self_heal_failed`'s sweep — resolve it once and call `_within_stream_at` instead.
func _within_stream(chunk: Vector2i) -> bool:
	return _within_windows(window_centers(), stream_radius(), chunk)

## Phase 52 — the same test against EVERY window: a chunk is in the streamed set when any one
## window (the local player's, or a peer's) covers it.
func _within_windows(centers: Array, radius: int, chunk: Vector2i) -> bool:
	for c in centers:
		if _within_stream_at(c, radius, chunk):
			return true
	return false

## Squared distance from `chunk` to the NEAREST window centre — the load order across windows.
func _nearest_dist2(centers: Array, chunk: Vector2i) -> int:
	var best := 1 << 60
	for c in centers:
		best = mini(best, _dist2(c, chunk))
	return best

## Phase 52 — the window centres: the local player's chunk plus one per connected peer.
## A peer standing in the local player's own chunk adds no second window (same centre).
func window_centers() -> Array:
	return _centers_around(player_chunk())

## `window_centers` for a caller that has already resolved the local player's chunk (one
## `PlayerSlice.get_position()` read per pass, not two).
func _centers_around(local: Vector2i) -> Array:
	var out: Array = [local]
	for peer_id in _peer_centers:
		var c: Vector2i = _peer_centers[peer_id]
		if not out.has(c):
			out.append(c)
	return out

## Phase 52 — place (or move) a connected peer's window. Takes effect on the next `refresh`.
##
## Phase 62 — `host_driven` is true when the HOST placed the peer (join, spawn placement): the
## window goes exactly there, immediately. Otherwise `chunk` is a client claim: a move inside
## `PEER_RECENTER_INTERVAL` of the last one is refused, and one farther than
## `PEER_RECENTER_MAX_CHUNKS` is clamped to that distance (both counted in
## `peer_recenter_refused`). Returns true when the window actually moved.
func set_peer_center(peer_id: int, chunk: Vector2i, host_driven: bool = false) -> bool:
	return _move_peer_center(peer_id, chunk, host_driven, false)

func _move_peer_center(peer_id: int, chunk: Vector2i, host_driven: bool, is_sync: bool) -> bool:
	var now: int = now_msec.call()
	# X is a wrapped planet coordinate: store and compare the canonical chunk.
	chunk = TerrainSlice.wrap_chunk(chunk)
	if host_driven or not _peer_centers.has(peer_id):
		var moved: bool = _peer_centers.get(peer_id, null) != chunk
		_peer_centers[peer_id] = chunk
		_peer_last_claim_msec[peer_id] = now
		_peer_last_sync_msec[peer_id] = now
		return moved
	var current: Vector2i = _peer_centers[peer_id]
	if current == chunk:
		return false
	var last_msec: Dictionary = _peer_last_sync_msec if is_sync else _peer_last_claim_msec
	if now - int(last_msec.get(peer_id, -1000000)) < int(PEER_RECENTER_INTERVAL * 1000.0):
		if not is_sync:
			peer_recenter_refused += 1
		return false
	# X is a wrapped planet coordinate: measure the step the short way round the seam.
	var c := TerrainSlice.circumference_chunks()
	var step := Vector2i(posmod(chunk.x - current.x + c / 2, c) - c / 2, chunk.y - current.y)
	var reach := maxi(absi(step.x), absi(step.y))
	if reach > PEER_RECENTER_MAX_CHUNKS:
		if is_sync:
			peer_sync_far_hops += 1
		else:
			peer_recenter_refused += 1
		step = Vector2i(
			roundi(float(step.x) * PEER_RECENTER_MAX_CHUNKS / float(reach)),
			roundi(float(step.y) * PEER_RECENTER_MAX_CHUNKS / float(reach)))
	_peer_centers[peer_id] = TerrainSlice.wrap_chunk(current + step)
	last_msec[peer_id] = now
	return true

## Phase 82 — the periodic re-centre of a peer on the position the host tracks. That position is
## still client-reported, so it gets the same interval limit and clamp as a claim (a hostile
## client cannot hop the window across the planet every tick); the difference is that a deferral
## here is the sync simply retrying on its next tick, so it is NOT counted in
## `peer_recenter_refused`. A sync that is clamped still moves the window, and is counted in
## `peer_sync_far_hops`. Trust relied on: the caller passes the position the HOST tracks for the
## peer's connection (never a raw client claim), so a far hop here means the tracked position itself
## jumped and is worth surfacing, not refusing. Returns true when the window moved.
func sync_peer_center(peer_id: int, chunk: Vector2i) -> bool:
	return _move_peer_center(peer_id, chunk, false, true)

## The chunk a peer's window is centred on, or null when it has none.
func peer_center(peer_id: int) -> Variant:
	return _peer_centers.get(peer_id, null)

## Phase 52 — drop a peer's window (disconnect). Chunks only that window covered unload.
func clear_peer_center(peer_id: int) -> void:
	_peer_centers.erase(peer_id)
	_peer_last_claim_msec.erase(peer_id)
	_peer_last_sync_msec.erase(peer_id)

func peer_window_count() -> int:
	return _peer_centers.size()

## How many windows cover `chunk` (0 when none): the reference count behind load/unload.
func chunk_ref_count(chunk: Vector2i) -> int:
	return int(_chunk_refs.get(_chunk_key(chunk), 0))

## Phase 42 review pass 3 — the same test against a window the CALLER already resolved. The
## drain reads the player's chunk and the radius ONCE and uses this per candidate, instead
## of the accessor form which re-derived both — a `PlayerSlice.get_position()` call — for
## every queued chunk in the drain.
func _within_stream_at(center: Vector2i, radius: int, chunk: Vector2i) -> bool:
	if not _in_bounds(chunk):
		return false
	return absi(chunk.x - center.x) <= radius and absi(chunk.y - center.y) <= radius

## Never leave a worker build running past the tree: at shutdown a task could still
## be producing arrays for a world nobody owns (and on a `--quit` boot that is one
## frame after the dispatch). Waiting here is a bounded block — the tasks are short.
##
## Phase 42 review — the wait is UNCONDITIONAL, and that is the whole fix. It used to
## be guarded by `is_task_completed`, which is exactly the leak: that call only reports
## that the work is DONE, while the pool keeps the task and its result alive until it is
## AWAITED, so a finished-but-never-awaited build still aborted the process at shutdown
## (exit 134 — the leak this comment describes, walked straight back in through the
## guard). `wait_for_task_completion` returns immediately for a finished task, so
## dropping the guard costs nothing and closes the window.
func _exit_tree() -> void:
	for task_id in _builds.keys():
		WorkerThreadPool.wait_for_task_completion(task_id)
	_builds.clear()

## Attach every worker build that has finished, on the main thread. A result whose
## chunk was streamed back out while it built is dropped, and so is one whose revision
## has moved on (`VoxelSlice.build_chunk` refuses those itself — an edit rebuilt the
## chunk synchronously in the meantime).
func _apply_finished_builds() -> void:
	if _builds.is_empty():
		return
	for task_id in _builds.keys():
		if not WorkerThreadPool.is_task_completed(task_id):
			continue
		_apply_build_entry(task_id)

## Apply every in-flight build NOW, blocking on each task. The frame path polls
## (`_apply_finished_builds`); this is the blocking variant for a caller that has no
## frames to give — a test, or a boot that must not move on until the ground exists.
## Returns how many builds it attached.
##
## Phase 42 review pass 8 — it LOOPS, and the loop is the fix. `_apply_build_entry` can
## DISPATCH (a build that exhausted its retries re-arms, and a failed worker result is
## re-dispatched), so a single pass over a snapshot of `_builds.keys()` can leave a task
## it just created in flight — and this is the blocking variant whose whole contract is
## "nothing is left in flight after me". The snapshot is still taken per round; each round
## therefore reaps what the previous one dispatched, so the number of rounds is the length
## of the longest retry chain, bounded by `FLUSH_MAX_ROUNDS` so a build that fails forever
## cannot spin here (it ends up in `_failed`, re-armed by the self-heal).
func flush_builds() -> int:
	var applied := 0
	var round := 0
	while not _builds.is_empty() and round < FLUSH_MAX_ROUNDS:
		round += 1
		for task_id in _builds.keys():
			if _apply_build_entry(task_id):
				applied += 1
	return applied

## Attach one task's arrays and clear it from the in-flight table. Returns false when
## nothing was attached — a drop is not a failure, it is the reason the table is per-frame.
##
## It WAITS on the task before doing anything with it, and that is not belt-and-braces:
## `is_task_completed` only reports that the work is done, while the pool keeps the task
## — and its result — alive until it is awaited, so a stream of polled-but-never-awaited
## builds accumulates until the pool aborts the process at shutdown (measured: exit 134
## on every boot that streamed one chunk window). On the frame path this call is
## therefore instantaneous, because the caller only reaches here for a finished task.
##
## Phase 42 review — three ways this answers FALSE, and each one now has a defined
## consequence rather than a silent one:
##   * SUPERSEDED — a later dispatch for the same chunk owns its mesh (an edit landed
##     while this build was in flight). Nothing to do, and no re-dispatch: the newer
##     task is already on its way.
##   * the chunk streamed out while it built — nothing to attach it to.
##   * `build_chunk` refused the result: the worker handed back NOTHING (a failed task;
##     it is no longer answered with a synchronous main-thread build, which is the stall
##     Phase 42 removed) or the chunk was rebuilt under it. Either way the chunk still
##     needs a mesh, so the build is RE-DISPATCHED, bounded by MAX_BUILD_RETRIES so a
##     permanently failing build reports an error instead of spinning.
##
## Phase 42 review — and the retry itself now goes through the in-flight cap (it used to
## call `_dispatch_build` outright and so was a second way past it), and giving up leaves
## the chunk in `_failed` so `_self_heal_failed` re-arms it — on the next crossing, or at
## most once per `self_heal_interval` while the window is stationary — instead of leaving a
## hole for the session. A chunk that gave up on a REBUILD is in there too: it is still
## `_built` (its old mesh stands in the world) and the sweep re-arms it all the same.
func _apply_build_entry(task_id: int) -> bool:
	var entry: Dictionary = _builds.get(task_id, {})
	if entry.is_empty():
		return false
	_builds.erase(task_id)
	WorkerThreadPool.wait_for_task_completion(task_id)
	var key: String = str(entry["key"])
	if bool(entry.get("superseded", false)):
		return false   # a later dispatch for this chunk owns the mesh
	if not _loaded.has(key):
		return false   # streamed out while it built: nothing to attach it to
	var result: Array = entry["result"]
	var arrays: Dictionary = {}
	if result[0] is Dictionary:
		arrays = result[0]
	var chunk: Vector2i = entry["chunk"]
	if not voxel_slice.build_chunk(chunk, entry["heightmap"], arrays, int(entry["revision"])):
		if int(_build_attempts.get(key, 0)) < MAX_BUILD_RETRIES:
			# A retry is a dispatch like any other, and `_dispatch_build` enforces the
			# in-flight cap itself (ninth review pass), deferring to `_rebuild_queue` when
			# the pool is full — the entry just reaped usually frees the slot.
			_dispatch_build(chunk)
		else:
			_failed[key] = true
			Diag.error("ChunkManager: chunk %s could not be built after %d attempts — its ground is missing (re-armed by the self-heal: immediately on a window re-centre, otherwise at most once per self_heal_interval, and each re-arm restarts this %d-attempt budget, so one interval costs up to that many dispatches)" % [key, MAX_BUILD_RETRIES, MAX_BUILD_RETRIES])
		return false
	_build_attempts.erase(key)
	_failed.erase(key)
	_built[key] = true
	# The ground exists now, so its contents may: creatures and trees spawn HERE rather
	# than at load time (see `_spawn_chunk_contents`) — but ONCE per residency, not once
	# per build. An EDIT rebuilds a loaded chunk, and re-deriving the population for it
	# re-scanned every live instance and every live tree in the world to arrive at the
	# same count (see `_contents_spawned`).
	if not _contents_spawned.has(key):
		_contents_spawned[key] = true
		_spawn_chunk_contents(chunk)
	_update_first_ring_progress()
	return true

## Arm the boot gate around `center`: the 9 chunks at Chebyshev 0..1 that the body
## stands in and may immediately step onto. They are queued AHEAD of whatever the
## wider ring already queued, so the gate opens as early as it can.
##
## Phase 42 review — that front-queueing only does anything when this runs BEFORE the
## first `refresh()` of the boot, and the boot used to call `refresh()` first: every
## ring chunk was already `_pending`, so `wanted` came out empty, NOTHING was moved to
## the front, and the ring's head start was dead code. Both boot paths now arm the gate
## first (`_boot_server` before its `refresh()`), so the ring is genuinely queued ahead
## of the wider band. Arming after a refresh is still correct, just no longer front-queued
## — the streaming sort is nearest-first, which puts the ring at the head anyway.
func build_first_ring(center: Vector2i) -> void:
	_first_ring_center = center
	_first_ring = {}
	var wanted: Array = []
	for c in _desired_chunks(center, FIRST_RING_RADIUS):
		if not _in_bounds(c):
			continue
		var key := _chunk_key(c)
		_first_ring[key] = _built.has(key)
		if not _loaded.has(key) and not _pending.has(key):
			wanted.append(c)
	wanted.sort_custom(func(a, b): return _dist2(center, a) < _dist2(center, b))
	for i in range(wanted.size() - 1, -1, -1):
		_pending[_chunk_key(wanted[i])] = true
		_load_queue.push_front(wanted[i])

## True when every chunk of the armed first ring has been BUILT. An unarmed gate
## answers true: a caller with no boot to hold must never be blocked by it.
func is_first_ring_ready() -> bool:
	if _first_ring.is_empty():
		return true
	for key in _first_ring:
		if not _first_ring[key]:
			return false
	return true

## Fraction of the armed first ring that has been built (1.0 when unarmed).
func first_ring_progress() -> float:
	if _first_ring.is_empty():
		return 1.0
	var done := 0
	for key in _first_ring:
		if _first_ring[key]:
			done += 1
	return float(done) / float(_first_ring.size())

## How many chunks the armed first ring holds (0 when unarmed).
func first_ring_size() -> int:
	return _first_ring.size()

## Re-read the built set into the gate. Called whenever a chunk's build lands.
##
## Phase 42 review pass 10 — this RECOMPUTES each ring key from `_built` rather than only ever
## LATCHING it true. `unload_chunk` clears `_built` for a chunk that streams away, so a one-way
## latch left `_first_ring` claiming a chunk was built when it no longer was — the gate and the
## set it is supposed to mirror could disagree in the one direction the old code could not see.
## Nothing regressed for a boot in practice (the ring is armed before the player can move, so a
## ring chunk never unloads mid-boot), but the mirror is now exact: a ring key is built iff
## `_built` holds it.
func _update_first_ring_progress() -> void:
	for key in _first_ring:
		_first_ring[key] = _built.has(key)

func unload_chunk(chunk_pos: Vector2i) -> void:
	var key := _chunk_key(chunk_pos)
	if not _loaded.has(key):
		return
	_loaded.erase(key)
	_seam_revision.erase(key)
	_rebuild_requests.erase(key)
	_built.erase(key)
	_build_attempts.erase(key)
	# Phase 42 review — a streamed-out chunk carries no retry state: its groundless mark
	# and any queued rebuild go with it (it rebuilds from the edit log when it streams
	# back in, see `request_rebuild`'s not-loaded branch).
	_failed.erase(key)
	# The residency ends here: the contents are despawned below, so a chunk that streams
	# back in repopulates (`_apply_build_entry`).
	_contents_spawned.erase(key)
	_rebuild_pending.erase(key)
	# Phase 42 review pass 3 — and the QUEUED entry goes with the mark. `_rebuild_queue` is
	# deduped through `_rebuild_pending`, so a mark cleared while its queue entry lived
	# on made the NEXT `_queue_rebuild` for the same chunk append a SECOND entry: two
	# dispatches for one chunk, both under the same revision, both attaching.
	_remove_queued_rebuild(key)
	# A build still in flight belongs to THIS residency. Without the supersede it stays live
	# in `_builds`, and if the chunk streams back in before it lands it attaches alongside
	# the reload's own dispatch under the same revision: the older arrays (gathered before
	# any edit made while the chunk was out) can win, and whichever lands second is refused
	# as stale and spends a needless retry dispatch.
	_supersede_in_flight(key)
	if voxel_slice != null and voxel_slice.has_method("unload_chunk"):
		voxel_slice.unload_chunk(chunk_pos)
	if creature_slice != null and creature_slice.has_method("despawn_for_chunk"):
		creature_slice.despawn_for_chunk(chunk_pos)
	if tree_slice != null and tree_slice.has_method("despawn_for_chunk"):
		tree_slice.despawn_for_chunk(chunk_pos)
	GameBus.chunk_unloaded.emit(chunk_pos)

## Chunk coordinate under the player's current XZ position.
func player_chunk() -> Vector2i:
	# Phase 78 — the exact chunk, so a player far from the origin does not flicker at a boundary.
	if player_slice != null and player_slice.has_method("get_world_pos"):
		return player_slice.get_world_pos()["chunk"]
	if player_slice != null and player_slice.has_method("get_position"):
		var p: Vector3 = player_slice.get_position()
		return world_to_chunk(Vector2(p.x, p.z))
	return Vector2i.ZERO

func world_to_chunk(world_pos: Vector2) -> Vector2i:
	if terrain_slice != null and terrain_slice.has_method("world_to_chunk"):
		return terrain_slice.world_to_chunk(world_pos)
	return Vector2i(floori(world_pos.x / 32), floori(world_pos.y / 32))

## Loaded chunks with their biome, for the minimap and introspection.
func get_loaded_chunks() -> Array:
	var out: Array = []
	for key in _loaded:
		var pos := _key_to_chunk(key)
		var biome := ""
		if terrain_slice != null and terrain_slice.has_method("get_biome_at_chunk"):
			biome = str(terrain_slice.get_biome_at_chunk(pos))
		out.append({ "chunk": pos, "biome": biome })
	return out

## The set of chunk coordinates within Chebyshev distance `radius` of `center`.
func _desired_chunks(center: Vector2i, radius: int) -> Array:
	var out: Array = []
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			out.append(center + Vector2i(dx, dz))
	return out

## Squared Chebyshev-ish distance from `center` to `chunk` — used only for
## ordering the load queue so the chunk nearest the player builds first.
func _dist2(center: Vector2i, chunk: Vector2i) -> int:
	var dx := chunk.x - center.x
	var dz := chunk.y - center.y
	return dx * dx + dz * dz

## True when `chunk` is inside the finite world, or when no terrain slice is
## wired (isolated unit tests treat the world as unbounded).
func _in_bounds(chunk: Vector2i) -> bool:
	if terrain_slice != null and terrain_slice.has_method("is_chunk_in_bounds"):
		return terrain_slice.is_chunk_in_bounds(chunk)
	return true

func _chunk_key(chunk_pos: Vector2i) -> String:
	# Phase 63: canonical key across the east-west seam.
	var c := TerrainSlice.wrap_chunk(chunk_pos)
	return "%d,%d" % [c.x, c.y]

func _key_to_chunk(key: String) -> Vector2i:
	var parts: PackedStringArray = str(key).split(",")
	return Vector2i(int(parts[0]), int(parts[1]))
