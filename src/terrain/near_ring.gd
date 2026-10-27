extends RefCounted
## Phase 189 — pay the main thread only for the ground a body reaches.
##
## After Phase 187 the build threads keep up at 90 m/s, but each attached chunk cost the main thread
## about 17–30 ms, and most of it went on ground no one touches: the collision body of a chunk four rings
## out (~9 ms) and the creatures and trees of a chunk the player is gone from a second later (4.5–12 ms).
##
## * Collision: a landing build attaches its collision only within Chebyshev `REACH_RADIUS` of the local body, `NEAR_RADIUS` of a peer (the
##   local player and every peer window's centre), and only under a flying body that is crossing chunks
##   fast. The others keep their worker-made shape parked on the voxel slice, and `tick` attaches it when
##   the chunk enters the ring: the chunk under the local body at once, the rest under the pump budget. A
##   process that draws nothing (the dedicated server) attaches everywhere, as before.
## * Contents: while the local player is moving fast (`ChunkManager.is_moving_fast`), a built chunk beyond
##   its near ring and outside every peer's window keeps its creatures and trees unspawned. They spawn
##   when it enters the ring or the player slows, nearest first under the pump budget. Spawning is a pure
##   function of (seed, chunk), so the same ids land at the same places, later.
## * Level of detail (Phase 190): a chunk a body reaches (`detail_bodies`: Chebyshev `REACH_RADIUS` of the
##   walking local body, `NEAR_RADIUS` of a peer) is built at full detail; the rest of the window is built
##   coarse (`VoxelCoarse`): 32×32 cells within `COARSE_RADIUS` of the local body, 16×16 beyond. A coarse
##   chunk is upgraded (a full build dispatched) when it enters the detail ring, and a full chunk is never
##   downgraded in place: it is built coarse again only after it streams out and back. A fast flyer reaches
##   no detail ring: it stands on its chunk's conservative coarse collision (attached by the collision ring
##   above), and the ground it reaches is upgraded once it slows. A chunk with an edit is always full, and
##   a process that draws nothing builds full everywhere.
##
## `cm` is the owning ChunkManager (it holds this as `_near`).
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const SeamWrap := preload("res://src/terrain/seam_wrap.gd")
const VoxelCoarse := preload("res://src/terrain/voxel_coarse.gd")

## A body reaches the chunk it stands in and the eight around it.
const NEAR_RADIUS := 1
## A walking local body keeps collision two rings out (at least 64 m, past the 60 m aim, build and chop
## reach, whose rays hit terrain on the collision layer).
const REACH_RADIUS := 2
## Phase 190 — coarse chunks within this Chebyshev distance of the local body use the finer coarse level.
const COARSE_RADIUS := 2

var cm: Node
## False: collision and contents on every attach, as in Phase 187 (`ChunkManager.set_near_ring_enabled`).
var enabled := true
## Built chunks whose contents wait for a body: "cx,cz" -> chunk.
var _waiting: Dictionary = {}
## Phase 190 — false builds every chunk at full detail (`ChunkManager.set_lod_enabled`).
var lod_enabled := true
## Phase 190 — built chunks at a coarse level: "cx,cz" -> step. A full chunk is absent.
var _coarse: Dictionary = {}
var _upgrading := false

func _init(manager: Node) -> void:
	cm = manager

## Chebyshev distance between two chunks, X measured the short way round the seam. Pure.
static func ring_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(SeamWrap.delta(b.x, a.x, TerrainSlice.circumference_chunks())), absi(b.y - a.y))

## The bodies collision is kept near, as [chunk, radius]: the local player first (radius 0 while it flies
## fast, else `REACH_RADIUS`), then each peer window's centre at `NEAR_RADIUS`.
func bodies() -> Array:
	var local: Vector2i = cm.player_chunk()
	var flying: bool = cm.player_slice != null and cm.player_slice.get("flying") == true
	var out: Array = [[local, 0 if flying and cm.is_moving_fast() else REACH_RADIUS]]
	for peer_id in cm._peer_centers:
		out.append([cm._peer_centers[peer_id], NEAR_RADIUS])
	return out

## True when a build of `chunk` landing now attaches its collision.
func wants_collision(chunk: Vector2i) -> bool:
	if not enabled or not cm.keeps_render():
		return true   # the dedicated server keeps collision everywhere (unchanged)
	return _within(bodies(), chunk)

static func _within(near: Array, chunk: Vector2i) -> bool:
	for b in near:
		if ring_distance(b[0], chunk) <= int(b[1]):
			return true
	return false

## True when a chunk built now keeps its contents for later: the local player is moving fast and the
## chunk is beyond its near ring and outside every peer's window.
func defers_contents(chunk: Vector2i) -> bool:
	return cm.is_moving_fast() and _defers(cm.player_chunk(), chunk)

func _defers(local: Vector2i, chunk: Vector2i) -> bool:
	if not enabled or ring_distance(local, chunk) <= NEAR_RADIUS:
		return false
	var radius: int = cm.stream_radius()
	for peer_id in cm._peer_centers:
		if ring_distance(cm._peer_centers[peer_id], chunk) <= radius:
			return false
	return true

## Spawn a just-built chunk's contents now, or keep them until a body reaches it.
func spawn_or_wait(key: String, chunk: Vector2i) -> void:
	if defers_contents(chunk) and not cm._contents_spawned.has(key):
		_waiting[key] = chunk
	else:
		cm._spawn_contents_once(key, chunk)

## True while `chunk` is built with its contents kept for later.
func is_waiting(chunk: Vector2i) -> bool:
	return _waiting.has(cm._chunk_key(chunk))

func waiting_count() -> int:
	return _waiting.size()

## The chunk left the streamed set: nothing waits for it any more.
func forget(key: String) -> void:
	_waiting.erase(key)
	_coarse.erase(key)

## Phase 190 — the bodies full detail is kept near, as [chunk, radius]: the local player at `REACH_RADIUS`
## unless it flies fast (then none), and each peer window's centre at `NEAR_RADIUS`. `local` is the local
## body's chunk (read when null).
func detail_bodies(local: Variant = null) -> Array:
	var out: Array = []
	var flying: bool = cm.player_slice != null and cm.player_slice.get("flying") == true
	if not (flying and cm.is_moving_fast()):
		out.append([cm.player_chunk() if local == null else local, REACH_RADIUS])
	for peer_id in cm._peer_centers:
		out.append([cm._peer_centers[peer_id], NEAR_RADIUS])
	return out

## Phase 190 — true when `chunk` is ground a body reaches and is kept at full detail.
func wants_detail(chunk: Vector2i, local: Variant = null) -> bool:
	return _within(detail_bodies(local), chunk)

## Phase 190 — the level a build of `chunk` dispatched now is made at: `VoxelCoarse.FULL`, or a coarse step.
## The local body is the window's centre as of the last refresh (as `build_high_priority` reads it), so a
## drain dispatching a whole ring reads the player once; an upgrade (`_upgrade_detail`) is full regardless.
func lod_for(chunk: Vector2i) -> int:
	if _upgrading or not enabled or not lod_enabled or not cm.keeps_render():
		return VoxelCoarse.FULL
	var local: Vector2i = cm._last_centers[0] if not cm._last_centers.is_empty() else cm.player_chunk()
	if wants_detail(chunk, local):
		return VoxelCoarse.FULL
	var voxel: Node = cm.voxel_slice
	if voxel != null and voxel.has_method("has_edits_near_chunk") and voxel.has_edits_near_chunk(chunk, 0):
		return VoxelCoarse.FULL   # a placed block or a dug hole never vanishes at a distance
	return VoxelCoarse.STEPS[0] if ring_distance(local, chunk) <= COARSE_RADIUS else VoxelCoarse.STEPS[1]

## Phase 190 — a build of `key` attached at `lod`.
func note_built(key: String, lod: int) -> void:
	if lod > VoxelCoarse.FULL:
		_coarse[key] = lod
	else:
		_coarse.erase(key)

## Phase 190 — the level the built chunk `key` stands at (`VoxelCoarse.FULL` unless it is coarse).
func lod_of(key: String) -> int:
	return int(_coarse.get(key, VoxelCoarse.FULL))

func coarse_count() -> int:
	return _coarse.size()

## Once a frame, after the builds attach: give the chunks the bodies reached their collision and their
## contents. The chunk under the local body is never held by the pump budget; the rest are.
func tick() -> void:
	_attach_near_collision()
	_release_contents()
	_upgrade_detail()

## Phase 190 — dispatch a full build for each coarse chunk a body now reaches, nearest the local body first;
## the chunk under it is never held by the pump budget. The coarse mesh stays until the full one lands.
func _upgrade_detail() -> void:
	if _coarse.is_empty():
		return
	var local: Vector2i = cm.player_chunk()
	var near := detail_bodies(local)
	if near.is_empty():
		return
	var due: Array = []
	for key in _coarse:
		var chunk: Vector2i = cm._key_to_chunk(key)
		if _within(near, chunk) and not cm._has_in_flight(key) and not cm._rebuild_pending.has(key):
			due.append([ring_distance(local, chunk), chunk])
	due.sort_custom(func(a, b): return a[0] < b[0])
	for d in due:
		if d[0] > 0 and cm._pump_exhausted():
			return
		_upgrading = true
		cm._dispatch_build(d[1])
		_upgrading = false
		cm._pump_steps += 1

func _attach_near_collision() -> void:
	var voxel: Node = cm.voxel_slice
	if voxel == null or not voxel.has_method("attach_parked_collision"):
		return
	var parked: Array = voxel._build.parked_chunks()
	if parked.is_empty():
		return
	var near := bodies()
	var local: Vector2i = near[0][0]
	var due: Array = []
	for c in parked:
		if _within(near, c):
			due.append([ring_distance(local, c), c])
	due.sort_custom(func(a, b): return a[0] < b[0])
	for d in due:
		# the chunk under the local body is never held by the pump budget; the rest are, nearest first
		if d[0] > 0 and cm._pump_exhausted():
			return
		voxel.attach_parked_collision(d[1])
		cm._pump_steps += 1

func _release_contents() -> void:
	if _waiting.is_empty():
		return
	var local: Vector2i = cm.player_chunk()
	var fast: bool = cm.is_moving_fast()
	var due: Array = []
	for key in _waiting.keys():
		var chunk: Vector2i = _waiting[key]
		if not fast or not _defers(local, chunk):
			due.append([ring_distance(local, chunk), key, chunk])
	due.sort_custom(func(a, b): return a[0] < b[0])
	for d in due:
		if cm._pump_exhausted():
			return   # the rest spawn on a later frame
		_waiting.erase(d[1])
		cm._spawn_contents_once(d[1], d[2])
		cm._pump_steps += 1
