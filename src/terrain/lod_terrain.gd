extends Node3D
## Phase 243 — the LOD rings: ground between the voxel window and the distant ring at falling detail.
##
## `update(viewer, window)` asks `LodRingPolicy` for each level's box and the chunks each ring draws; a
## chunk not built yet is queued (inner rings first, nearest first) and built on a worker
## (`VoxelLod.build_lod_arrays`), at most `MAX_TASKS` at once, and attached through the RenderingServer
## (`ChunkSurface`), at most `ATTACH_PER_FRAME` a frame. When the boxes move, the chunks no ring wants
## any more keep drawing until every new chunk is built, then the two sets cross-fade (`LodFade`) — or
## swap at once on the low terrain shader, which has no fade. Ring 1's chunks overlap the window's edge:
## their material's `lod_hole` (the window, in scene metres) cuts that part out.
##
## Render only (no collision) and client only: `game_root` makes it beside `DistantTerrain`, never on a
## headless server. A chunk is built once with the records and the edits the client holds then; a later
## edit or record shows when the ring moves past it again.

const LodRingPolicy := preload("res://src/terrain/lod_ring_policy.gd")
const VoxelLod := preload("res://src/terrain/voxel_lod.gd")
const ChunkSurface := preload("res://src/terrain/chunk_surface.gd")
const LodFade := preload("res://src/terrain/lod_fade.gd")
const ChunkRecords := preload("res://src/terrain/chunk_records.gd")
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const TerrainWeights := preload("res://src/terrain/terrain_weights.gd")
const TerrainMaterial := preload("res://src/terrain/terrain_material.gd")
const WorldShape := preload("res://src/terrain/world_shape.gd")
const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")
const SceneOffset := preload("res://src/core/scene_offset.gd")

const MAX_TASKS := 2
## The render layer the LOD chunks are drawn on as well as the default one (beside the distant ring's 19
## and the bands' 20).
const RENDER_LAYER := 1 << 18
const ATTACH_PER_FRAME := 4

var world_seed := 0
var ring_count := LodRingPolicy.rings()
## The voxel slice: the per-biome terrain materials and the edits the client holds. Null in a bare rig.
var voxel: Node = null

var _origin: SceneOffset = SceneOffset.new()
var _fade: Node = null
var _boxes: Array[Rect2i] = []
var _window := Rect2i()
var _viewer := Vector2.ZERO
var _snap: Dictionary = {}
## Vector3i(level, x, z) → ChunkSurface drawn now.
var _chunks: Dictionary = {}
var _wanted: Dictionary = {}
var _queue: Array = []
var _in_flight: Dictionary = {}   # key → task id
var _results: Dictionary = {}     # key → arrays (written by workers)
var _mutex := Mutex.new()
## Surfaces the rings no longer want, drawn until the new set is built, and the new set held back.
var _retiring: Array = []
var _fresh: Array = []
var _hole_mats: Dictionary = {}   # biome → ShaderMaterial (ring 1's, with `lod_hole`)
var builds_done := 0
## While true no new build starts (the window is still building: the ground near the body comes first).
var hold := false
var _drawn_outer := Rect2()

## Make the rings under `root` (a client's game root), reading `voxel`'s materials and edits, rebased by
## `rebase`; on the high terrain shader the window's own level changes cross-fade too (`VoxelBuild.lod_fade`).
static func attach(root: Node, voxel_slice: Node, rebase: Variant) -> Node:
	var lod: Node = (load("res://src/terrain/lod_terrain.gd") as GDScript).new()
	lod.name = "LodTerrain"
	lod.voxel = voxel_slice
	root.add_child(lod)
	rebase.targets.append(lod)
	if LodFade.enabled() and voxel_slice != null:
		var fade := LodFade.new()
		fade.name = "ChunkFade"
		root.add_child(fade)
		voxel_slice._build.lod_fade = fade
	return lod

## Follow the player at world `pp` round `chunks`' window (a ChunkManager) and return the distant ring's
## hole (`outer_rect_m`). No build starts while the window still has chunks to load or build: the
## ground near the body always comes first.
func follow(chunks: Node, pp: Vector3, seed_v: int) -> Rect2:
	world_seed = seed_v
	hold = not chunks._load_queue.is_empty() or not chunks.unbuilt_window_chunks().is_empty()
	var r: int = chunks.stream_radius()
	var pc: Vector2i = chunks.player_chunk()
	update(Vector2(pp.x, pp.z), Rect2i(pc - Vector2i(r, r), Vector2i(2 * r + 1, 2 * r + 1)))
	return outer_rect_m()

func _ready() -> void:
	_fade = LodFade.new()
	_fade.name = "LodFade"
	add_child(_fade)

func _exit_tree() -> void:
	for key in _in_flight:
		WorkerThreadPool.wait_for_task_completion(int(_in_flight[key]))
	_in_flight.clear()

## Every box, ring-0 (the window rounded to even) first. Empty before the first update.
func boxes() -> Array[Rect2i]:
	return _boxes

## Chunks drawn now (a test and the playtest read it).
func drawn_count() -> int:
	return _chunks.size()

func pending_count() -> int:
	return _queue.size() + _in_flight.size()

## The outer LOD radius the haze is fitted to.
func outer_radius_m() -> float:
	return LodRingPolicy.outer_radius_m(ring_count, LodRingPolicy.WINDOW_RADIUS)

## The outer box of the rings DRAWN now, in world metres (x, z): the distant ring's hole. Empty until a
## first complete set is attached (the distant ring keeps its window-sized hole until then, so the ground
## between never shows the sky); after a move it is the old box until the new set swaps in.
func outer_rect_m() -> Rect2:
	return _drawn_outer

## The outer box the last update planned, in world metres (x, z). Empty with no rings or before an update.
func planned_outer_rect_m() -> Rect2:
	if ring_count <= 0 or _boxes.size() <= ring_count:
		return Rect2()
	return LodRingPolicy.box_rect_m(_boxes[ring_count], ring_count)

## Follow the viewer at world `viewer_xz` with the voxel `window` (level-0 chunks, end exclusive).
## Returns true when the rings' chunk set changed.
func update(viewer_xz: Vector2, window: Rect2i) -> bool:
	if ring_count <= 0:
		return false
	_viewer = viewer_xz
	if window != _window:
		_window = window
		_refresh_holes()
	if _boxes.size() == ring_count + 1 and LodRingPolicy.still_holds(_boxes, viewer_xz, window):
		return false
	var b := LodRingPolicy.boxes(viewer_xz, window, ring_count)
	if b == _boxes:
		return false
	if not _boxes.is_empty() and not LodRingPolicy.box_rect_m(b[ring_count], ring_count).intersects(planned_outer_rect_m()):
		reset()   # a teleport: nothing of the old set lies under the new one, so nothing to fade from
	_boxes = b
	WorldShape.warm()   # the fabric snapshot and polar caches the workers read, taken here
	TerrainSlice.warm_polar_caches()
	TerrainWeights.warm()
	var outer: Rect2i = _boxes[ring_count]
	var span := 1 << ring_count
	var mid := (outer.position + outer.size / 2) * span
	var reach := outer.size.x * span / 2 + 2
	_snap = {} if ChunkRecords.is_empty() else ChunkRecords.snapshot_near(mid, reach, TerrainSlice.circumference_chunks())
	var wanted := {}
	var order: Array = []
	for k in range(1, ring_count + 1):
		for c in LodRingPolicy.ring_chunks(_boxes, k, window):
			var key := Vector3i(k, c.x, c.y)
			wanted[key] = true
			if not _chunks.has(key):
				order.append(key)
	for key in _chunks.keys():
		if not wanted.has(key):
			var gone: Node = _chunks[key]
			_chunks.erase(key)
			if _fresh.has(gone):
				_fresh.erase(gone)   # never shown: nothing to fade out
				gone.queue_free()
			else:
				_retiring.append(gone)
	_wanted = wanted
	_queue = order
	return true

## Shift every node by `shift` (a client rebase); world positions are unchanged.
func shift_scene(shift: Vector3) -> void:
	_origin.value += shift
	for s in _chunks.values():
		(s as Node3D).position += shift
	for s in _retiring + _fresh:
		if is_instance_valid(s):
			(s as Node3D).position += shift
	if _fade != null:
		_fade.shift_scene(shift)
	_refresh_holes()

func scene_offset() -> Vector3:
	return _origin.value

## Drop everything (a fold re-streams the world in another frame); the next update rebuilds.
func reset() -> void:
	for s in _chunks.values() + _retiring + _fresh:
		if is_instance_valid(s):
			(s as Node).queue_free()
	_chunks.clear()
	_retiring.clear()
	_fresh.clear()
	_queue.clear()
	_wanted.clear()
	_boxes = []
	_drawn_outer = Rect2()
	if _fade != null:
		_fade.finish_all()

func _process(_delta: float) -> void:
	pump()

## Start builds, attach finished ones and, once a moved set is complete, swap it in. Called every frame.
func pump() -> void:
	_collect()
	while not hold and _in_flight.size() < MAX_TASKS and not _queue.is_empty():
		var key: Vector3i = _queue.pop_front()
		if _chunks.has(key) or _in_flight.has(key) or not _wanted.has(key):
			continue
		var level := key.x
		var lchunk := Vector2i(key.y, key.z)
		var edits := edit_tops(level, lchunk)
		var task := WorkerThreadPool.add_task(_build_task.bind(key, world_seed, _snap, edits), false, "lod_chunk")
		_in_flight[key] = task
	if _queue.is_empty() and _in_flight.is_empty() and not _boxes.is_empty():
		if not _retiring.is_empty() or not _fresh.is_empty():
			_swap_in()
		_drawn_outer = planned_outer_rect_m()

func _build_task(key: Vector3i, seed_v: int, snap: Dictionary, edits: Dictionary) -> void:
	var built := VoxelLod.build_lod_arrays(key.x, Vector2i(key.y, key.z), seed_v, snap, edits)
	_mutex.lock()
	_results[key] = built
	_mutex.unlock()

func _collect() -> void:
	var done: Array = []
	for key in _in_flight:
		if WorkerThreadPool.is_task_completed(int(_in_flight[key])):
			done.append(key)
	var attached := 0
	for key in done:
		if attached >= ATTACH_PER_FRAME:
			break
		WorkerThreadPool.wait_for_task_completion(int(_in_flight[key]))
		_in_flight.erase(key)
		_mutex.lock()
		var built: Dictionary = _results.get(key, {})
		_results.erase(key)
		_mutex.unlock()
		builds_done += 1
		if _wanted.has(key) and not _chunks.has(key):
			_attach(key, built)
			attached += 1

func _attach(key: Vector3i, built: Dictionary) -> void:
	var surface := ChunkSurface.new()
	surface.name = "Lod_%d_%d_%d" % [key.x, key.y, key.z]
	var corner := VoxelLod.corner_m(key.x, Vector2i(key.y, key.z))
	surface.position = Vector3(corner.x + _origin.value.x, _origin.value.y, corner.y + _origin.value.z)
	if not surface.setup(built, _material_for(key.x, str(built.get("biome", "")))):
		surface.free()
		return
	# A layer of their own too, so a check can draw the far ground with or without them (the playtest's
	# far_peak counts the ring's holes with the rings drawn).
	surface.set_layers(1 | RENDER_LAYER)
	add_child(surface)
	_chunks[key] = surface
	if not _retiring.is_empty():
		# The old set still draws the ground here: hold the new chunk back until the set is complete.
		if LodFade.enabled():
			surface.set_fade(0.0)
		else:
			surface.visible = false
		_fresh.append(surface)

func _swap_in() -> void:
	if LodFade.enabled() and _fade != null:
		_fade.cross_fade(_retiring, _fresh)
	else:
		for s in _fresh:
			if is_instance_valid(s):
				(s as Node3D).visible = true
		for s in _retiring:
			if is_instance_valid(s):
				(s as Node).queue_free()
	_retiring.clear()
	_fresh.clear()

## The client's edited tiles inside LOD chunk `lchunk` of `level`, as `{ tile: top }` (see `VoxelLod`).
func edit_tops(level: int, lchunk: Vector2i) -> Dictionary:
	var out := {}
	if voxel == null or not ("_edits_by_chunk" in voxel):
		return out
	var span := 1 << level
	var lo := lchunk * span
	var circ := TerrainSlice.circumference_chunks()
	for ckey in voxel._edits_by_chunk:
		var parts := str(ckey).split(",")
		if parts.size() != 2:
			continue
		var c := Vector2i(int(parts[0]), int(parts[1]))
		# A chunk key is canonical (wrapped); match it against the LOD chunk's span in the same frame.
		var dx := posmod(c.x - lo.x, circ) if circ > 0 else c.x - lo.x
		var dz := c.y - lo.y
		if dx < 0 or dx >= span or dz < 0 or dz >= span:
			continue
		for tkey in voxel._edits_by_chunk[ckey]:
			var tp := str(tkey).split(",")
			if tp.size() != 2:
				continue
			var tile := Vector2i(int(tp[0]), int(tp[1]))
			# Back into the LOD chunk's (unwrapped) frame: shift by whole circumferences of tiles.
			tile.x += (lo.x + dx - c.x) * VoxelConsts.CHUNK_SIZE
			out[tile] = float(voxel.column_top_at_tile(Vector2i(int(tp[0]), int(tp[1]))))
	return out

func _material_for(level: int, biome: String) -> Material:
	var base: Material = voxel._terrain_material_for(biome) if voxel != null and voxel.has_method("_terrain_material_for") else null
	if base == null:
		base = TerrainMaterial.make()
	if level != 1:
		return base
	if not _hole_mats.has(biome):
		_hole_mats[biome] = { "base": base, "mat": base.duplicate() }
	var entry: Dictionary = _hole_mats[biome]
	var mat: ShaderMaterial = entry["mat"]
	mat.set_shader_parameter("tint", (entry["base"] as ShaderMaterial).get_shader_parameter("tint"))
	mat.set_shader_parameter("lod_hole", hole_rect())
	return mat

## Ring 1's hole: the window in scene metres, as the shader's (x0, z0, x1, z1).
func hole_rect() -> Vector4:
	var m := LodRingPolicy.CHUNK_METERS
	var o := _origin.value
	return Vector4(float(_window.position.x) * m + o.x, float(_window.position.y) * m + o.z,
		float(_window.end.x) * m + o.x, float(_window.end.y) * m + o.z)

func _refresh_holes() -> void:
	var h := hole_rect()
	for biome in _hole_mats:
		var entry: Dictionary = _hole_mats[biome]
		var mat: ShaderMaterial = entry["mat"]
		mat.set_shader_parameter("lod_hole", h)
		mat.set_shader_parameter("tint", (entry["base"] as ShaderMaterial).get_shader_parameter("tint"))
