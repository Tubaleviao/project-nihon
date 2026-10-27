extends RefCounted
## The peer window re-centre rules, moved out of `chunk_manager.gd` (line cap). `cm` is the manager.

const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const SeamWrap := preload("res://src/terrain/seam_wrap.gd")

var cm: Node

func _init(manager: Node) -> void:
	cm = manager

func move(peer_id: int, chunk: Vector2i, host_driven: bool, is_sync: bool) -> bool:
	var now: int = cm.now_msec.call()
	# X is a wrapped planet coordinate: store and compare the canonical chunk.
	chunk = TerrainSlice.wrap_chunk(chunk)
	if not host_driven and not is_sync and not cm._peer_centers.has(peer_id):
		# A raw client claim has nothing to measure a step from: only the host's placement (or its own tracked
		# position, the sync) may set a first center.
		cm.peer_recenter_refused += 1
		return false
	if host_driven or not cm._peer_centers.has(peer_id):
		var moved: bool = cm._peer_centers.get(peer_id, null) != chunk
		cm._peer_centers[peer_id] = chunk
		cm._peer_last_claim_msec[peer_id] = now
		cm._peer_last_sync_msec[peer_id] = now
		return moved
	var current: Vector2i = cm._peer_centers[peer_id]
	if current == chunk:
		return false
	var last_msec: Dictionary = cm._peer_last_sync_msec if is_sync else cm._peer_last_claim_msec
	if now - int(last_msec.get(peer_id, -1000000)) < int(cm.PEER_RECENTER_INTERVAL * 1000.0):
		if not is_sync:
			cm.peer_recenter_refused += 1
		return false
	var step := wrapped_step(current, chunk)
	var reach := maxi(absi(step.x), absi(step.y))
	if reach > cm.PEER_RECENTER_MAX_CHUNKS:
		if is_sync:
			cm.peer_sync_far_hops += 1
		else:
			cm.peer_recenter_refused += 1
		step = scaled_step(step, reach)
	cm._peer_centers[peer_id] = TerrainSlice.wrap_chunk(current + step)
	last_msec[peer_id] = now
	return true

## The step from `from` to `to`, X measured the short way round the seam.
func wrapped_step(from: Vector2i, to: Vector2i) -> Vector2i:
	var c := TerrainSlice.circumference_chunks()
	return Vector2i(SeamWrap.delta(to.x, from.x, c), to.y - from.y)

func scaled_step(step: Vector2i, reach: int) -> Vector2i:
	return Vector2i(
		roundi(float(step.x) * cm.PEER_RECENTER_MAX_CHUNKS / float(reach)),
		roundi(float(step.y) * cm.PEER_RECENTER_MAX_CHUNKS / float(reach)))

