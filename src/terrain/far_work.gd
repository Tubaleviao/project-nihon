extends RefCounted
## Phase 189 — the work `ChunkManager.defer_far_work` withholds from far chunks: collision bodies and
## creature/tree contents are served only near a body (see the manager's `defer_far_work`). `cm` is the manager.

const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const NEAR_RING := 1
const CONTENTS_SETTLE_MSEC := 1500

var cm: Node
## Built chunks whose contents wait for the near ring or a still window: "cx,cz" -> true.
var waiting: Dictionary = {}
var _last_recenter_msec: int = 0
var _last_local_center: Vector2i = Vector2i(1 << 30, 1 << 30)

func _init(manager: Node) -> void:
	cm = manager

## True when `chunk` is within NEAR_RING (Chebyshev) of any window centre.
func in_near_ring(chunk: Vector2i) -> bool:
	for c in cm.window_centers():
		if cm._within_stream_at(c, NEAR_RING, chunk):
			return true
	return false

## Collision for chunks that entered the near ring, contents for chunks in it (all at once) and, once the
## local window has been still, one waiting chunk a frame. Returns how many chunks it gave something to.
func serve() -> int:
	if not cm.defer_far_work or cm.voxel_slice == null:
		return 0
	var local: Vector2i = cm.player_chunk()
	var now: int = cm.now_msec.call()
	if local != _last_local_center:
		_last_local_center = local
		_last_recenter_msec = now
	var served := 0
	for c in cm.window_centers():
		for dz in range(-NEAR_RING, NEAR_RING + 1):
			for dx in range(-NEAR_RING, NEAR_RING + 1):
				var ch: Vector2i = TerrainSlice.wrap_chunk(c + Vector2i(dx, dz))
				var key: String = cm._chunk_key(ch)
				if cm.voxel_slice._build.attach_pending_collision(ch):
					served += 1
				if waiting.has(key) and cm._built.has(key):
					_release(key, ch)
					served += 1
	if not waiting.is_empty() and now - _last_recenter_msec >= CONTENTS_SETTLE_MSEC:
		var key: String = waiting.keys()[0]
		_release(key, cm._key_to_chunk(key))
		served += 1
	return served

func _release(key: String, chunk: Vector2i) -> void:
	waiting.erase(key)
	cm._spawn_contents_once(key, chunk, true)
