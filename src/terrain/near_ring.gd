extends RefCounted
## Phase 189 — pay the main thread only for the ground a body reaches.
##
## After Phase 187 the build threads keep up at 90 m/s, but each attached chunk cost the main thread
## about 17–30 ms, and most of it went on ground no one touches: the collision body of a chunk four rings
## out (~9 ms) and the creatures and trees of a chunk the player is gone from a second later (4.5–12 ms).
##
## * Collision: a landing build attaches its collision only within Chebyshev `NEAR_RADIUS` of a body (the
##   local player and every peer window's centre), and only under a flying body that is crossing chunks
##   fast. The others keep their worker-made shape parked on the voxel slice, and `tick` attaches it when
##   the chunk enters the ring: the chunk under the local body at once, the rest under the pump budget. A
##   process that draws nothing (the dedicated server) attaches everywhere, as before.
## * Contents: while the local player is moving fast (`ChunkManager.is_moving_fast`), a built chunk beyond
##   its near ring and outside every peer's window keeps its creatures and trees unspawned. They spawn
##   when it enters the ring or the player slows, nearest first under the pump budget. Spawning is a pure
##   function of (seed, chunk), so the same ids land at the same places, later.
##
## `cm` is the owning ChunkManager (it holds this as `_near`).
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const SeamWrap := preload("res://src/terrain/seam_wrap.gd")

## A body reaches the chunk it stands in and the eight around it.
const NEAR_RADIUS := 1

var cm: Node
## False: collision and contents on every attach, as in Phase 187 (`ChunkManager.set_near_ring_enabled`).
var enabled := true
## Built chunks whose contents wait for a body: "cx,cz" -> chunk.
var _waiting: Dictionary = {}

func _init(manager: Node) -> void:
	cm = manager

## Chebyshev distance between two chunks, X measured the short way round the seam. Pure.
static func ring_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(SeamWrap.delta(b.x, a.x, TerrainSlice.circumference_chunks())), absi(b.y - a.y))

## The bodies collision is kept near, as [chunk, radius]: the local player first (radius 0 while it flies
## fast, else `NEAR_RADIUS`), then each peer window's centre at `NEAR_RADIUS`.
func bodies() -> Array:
	var local: Vector2i = cm.player_chunk()
	var flying: bool = cm.player_slice != null and cm.player_slice.get("flying") == true
	var out: Array = [[local, 0 if flying and cm.is_moving_fast() else NEAR_RADIUS]]
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
	if defers_contents(chunk):
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

## Once a frame, after the builds attach: give the chunks the bodies reached their collision and their
## contents. The chunk under the local body is never held by the pump budget; the rest are.
func tick() -> void:
	_attach_near_collision()
	_release_contents()

func _attach_near_collision() -> void:
	var voxel: Node = cm.voxel_slice
	if voxel == null or not voxel.has_method("attach_parked_collision"):
		return
	var under := true   # the first chunk visited is the one under the local body
	for b in bodies():
		for c in _ring_nearest_first(b[0], int(b[1])):
			if voxel.has_parked_collision(c):
				if not under and cm._pump_exhausted():
					return
				voxel.attach_parked_collision(c)
				cm._pump_steps += 1
			under = false

## The chunks within Chebyshev `r` of `centre`, the centre first.
static func _ring_nearest_first(centre: Vector2i, r: int) -> Array:
	var out: Array = [centre]
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx != 0 or dz != 0:
				out.append(centre + Vector2i(dx, dz))
	return out

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
