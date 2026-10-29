extends "res://src/tests/test_support.gd"
## Phase 191 — the recent-chunk cache (a return trip attaches without a worker build, an edit invalidates,
## the cache stays within its bound) and the distant ring's patches under unbuilt window chunks.

const VoxelCoarse := preload("res://src/terrain/voxel_coarse.gd")
const ChunkCache := preload("res://src/terrain/chunk_cache.gd")

func register() -> void:
	_run_test("cache: a returning chunk attaches without a dispatch", _test_cache_hit_without_dispatch)
	_run_test("cache: an edit or a rebuild request invalidates the entry", _test_cache_invalidated_by_edit)
	_run_test("cache: a coarse entry is not reused at another level", _test_cache_level_mismatch)
	_run_test("cache: entry count and bytes stay within the bound, least recently used first", _test_cache_bound)
	_run_test("cache: a restream empties it", _test_cache_restream_clears)
	_run_test("cache: digging or placing in a neighbour invalidates a cached chunk", _test_cache_neighbour_edit)
	_run_test("cache: a hit attaches in apply order under the frame's pacing, without a worker slot", _test_cache_hit_apply_order)
	_run_test("cache: approx_bytes counts the mesh arrays and the collision faces", _test_cache_bytes_with_collision)
	_run_test("distant: the unbuilt list and the bands are read again only when their inputs change", _test_distant_rebuild_on_change)
	_run_test("distant: the ring covers an unbuilt window chunk and leaves a built one to the voxel mesh", _test_distant_unbuilt_cover)
	_run_test("distant: a spent fill budget makes one patch a call, and the rest follow", _test_distant_fill_budget)

func _free_rig(rig: Dictionary) -> void:
	for k in ["cm", "voxel", "terrain", "player"]:
		if rig.has(k) and is_instance_valid(rig[k]):
			rig[k].free()

func _build(cm: ChunkManager, chunks: Array) -> void:
	for c in chunks:
		cm.load_chunk(c)
	_wait_for_builds(cm)

func _test_cache_hit_without_dispatch() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var chunk := Vector2i(0, 0)
	_build(cm, [chunk])
	assert_true(cm.is_chunk_built(chunk), "the chunk is built")
	assert_true(cm.chunk_cache().has_entry(cm._chunk_key(chunk)), "and remembered")
	cm.unload_chunk(chunk)
	assert_false(cm.is_chunk_built(chunk), "streamed out")
	var attached := cm.builds_attached
	cm.load_chunk(chunk)
	assert_eq(cm._m1.worker_builds(), 0, "the return dispatches no worker task")
	assert_eq(cm._builds.size(), 1, "the hit waits, done, to attach with the frame's finished builds (Phase 194)")
	cm._apply_finished_builds()
	assert_true(cm.is_chunk_built(chunk), "the next apply attaches it")
	assert_eq(cm.cache_attaches, 1, "from the cache")
	assert_eq(cm.builds_attached, attached + 1, "and counts as an attach")
	assert_true(cm.chunk_cache().has_entry(cm._chunk_key(chunk)), "the entry stays for the next return")
	var h: float = rig["voxel"].get_voxel_height_at(Vector2(5.0, 5.0))
	assert_true(h > -1000.0, "the ground answers height queries")
	_free_rig(rig)

func _test_cache_invalidated_by_edit() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var voxel: VoxelSlice = rig["voxel"]
	var chunk := Vector2i(0, 0)
	_build(cm, [chunk])
	cm.unload_chunk(chunk)
	var top := voxel.get_voxel_height_at(Vector2(5.25, 5.25))
	voxel.apply_edits({ VoxelSlice._tile_key(Vector2i(10, 10)): [{ "op": "add", "bottom": top, "top": top + 0.5, "material": "Ferrite" }] })
	cm.load_chunk(chunk)
	assert_false(cm._builds.is_empty(), "an edit made while it was away forces a worker build")
	assert_eq(cm.cache_attaches, 0, "nothing came from the cache")
	_wait_for_builds(cm)
	assert_true(cm.chunk_cache().has_entry(cm._chunk_key(chunk)), "the fresh build is cached under the new revision")
	cm.request_rebuild(chunk)
	assert_false(cm.chunk_cache().has_entry(cm._chunk_key(chunk)), "a rebuild request (an edit in the loaded chunk) drops the entry at once")
	_wait_for_builds(cm)
	_free_rig(rig)

func _test_cache_level_mismatch() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var far := Vector2i(6, 0)
	_build(cm, [far])
	assert_eq(cm.chunk_lod(far), 4, "built coarse while the body is away")
	cm.unload_chunk(far)
	rig["player"].spawn_at(Vector3(6.0 * 32.0 + 16.0, 40.0, 16.0))
	cm._last_centers = [far]
	cm.load_chunk(far)
	assert_false(cm._builds.is_empty(), "the body arrived: the full build is dispatched, the coarse entry is not reused")
	assert_eq(cm.cache_attaches, 0, "no cache attach")
	_wait_for_builds(cm)
	assert_eq(cm.chunk_lod(far), VoxelCoarse.FULL, "built full")
	_free_rig(rig)

func _arrays_of(n: int) -> Dictionary:
	var v := PackedVector3Array()
	v.resize(n)
	return { "vertices": v }

func _test_cache_bound() -> void:
	var c := ChunkCache.new()
	c.max_entries = 3
	for i in 5:
		c.put("k%d" % i, i, _arrays_of(10), [])
	assert_eq(c.size(), 3, "at most max_entries are kept")
	assert_false(c.has_entry("k0") or c.has_entry("k1"), "the oldest went first")
	assert_false(c.take("k2", 2).is_empty(), "a matching signature hits")
	c.put("k5", 5, _arrays_of(10), [])
	assert_true(c.has_entry("k2"), "a hit refreshes the entry")
	assert_false(c.has_entry("k3"), "so the next-oldest is evicted instead")
	assert_true(c.take("k2", 99).is_empty(), "another signature misses")
	assert_false(c.has_entry("k2"), "and drops the stale entry")
	var per := ChunkCache.approx_bytes(_arrays_of(10))
	assert_eq(per, 120 + ChunkCache.VARIANT_BYTES, "10 vertices are 120 bytes, plus the value's slot")
	var b := ChunkCache.new()
	b.max_bytes = per * 2 + 1
	for i in 6:
		b.put("b%d" % i, 0, _arrays_of(10), [])
	assert_true(b.size() <= 2 and b.bytes() <= b.max_bytes, "the byte bound holds (%d entries, %d bytes)" % [b.size(), b.bytes()])
	b.put("huge", 0, _arrays_of(1000), [])
	assert_false(b.has_entry("huge"), "an entry over the whole budget is not kept")
	assert_eq(b.bytes(), per * b.size(), "the byte count follows the entries")
	b.clear()
	assert_eq(b.bytes(), 0, "clear empties it")

func _test_cache_restream_clears() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	_build(cm, [Vector2i(0, 0)])
	assert_true(cm.chunk_cache().size() > 0, "filled")
	cm.restream()
	assert_eq(cm.chunk_cache().size(), 0, "a restream (a fold, a regenerated world) drops every entry")
	_free_rig(rig)

func _test_distant_unbuilt_cover() -> void:
	var ring := DistantTerrainScript.new()
	ring.world_seed = 7
	add_child(ring)
	var a := Vector2i(1, 1)
	var b := Vector2i(2, 1)
	assert_eq(ring.set_unbuilt([a, b], Vector2i.ZERO), 2, "a patch stands under each unbuilt chunk")
	assert_true(ring.covers_chunk(a) and ring.covers_chunk(b), "both are covered")
	assert_false(ring.covers_chunk(Vector2i(0, 0)), "a chunk not listed (built) is left to the voxel mesh")
	ring.set_unbuilt([b], Vector2i.ZERO)
	assert_false(ring.covers_chunk(a), "once built, its patch goes")
	assert_true(ring.covers_chunk(b), "the other stays")
	var mesh := DistantTerrainScript.build_fill_mesh(7, ring.circumference_m, a)
	var verts := (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	assert_eq(verts.size(), DistantTerrainScript.FILL_CELLS * DistantTerrainScript.FILL_CELLS * 4, "a patch is FILL_CELLS² quads")
	var inside := true
	for v in verts:
		if v.x < 32.0 - 0.001 or v.x > 64.0 + 0.001 or v.z < 32.0 - 0.001 or v.z > 64.0 + 0.001:
			inside = false
	assert_true(inside, "and lies within its chunk's square")
	var many: Array = []
	for i in 10:
		many.append(Vector2i(10 + i, 0))
	ring.set_unbuilt(many, Vector2i(10, 0))
	assert_true(ring.fill_count() <= 1 + DistantTerrainScript.FILL_PER_CALL, "new patches are paced per call")
	assert_eq(ring.collision_body_count(), 0, "patches carry no collision")
	ring.free()

## Phase 183 — with no time to spare after the first patch, each call makes exactly one, nearest first.
func _test_distant_fill_budget() -> void:
	var ring := DistantTerrainScript.new()
	ring.world_seed = 7
	add_child(ring)
	var many: Array = []
	for i in 4:
		many.append(Vector2i(10 + i, 0))
	assert_eq(ring.set_unbuilt(many, Vector2i(10, 0), 1), 1, "a 1 µs budget still makes the first patch, and only it")
	assert_true(ring.covers_chunk(Vector2i(10, 0)), "the nearest one")
	for i in 3:
		ring.set_unbuilt(many, Vector2i(10, 0), 1)
	assert_eq(ring.fill_count(), 4, "one call each covers the rest")
	ring.free()

## Phase 194 (#512) — the cache signs a build with its own and its neighbours' edit revisions. A dig or a place
## did not bump them, so a chunk cached before a neighbour's edit came back with the old seam.
func _test_cache_neighbour_edit() -> void:
	for how in ["mine", "place"]:
		var rig := _make_chunk_build_rig()
		var cm: ChunkManager = rig["cm"]
		var voxel: VoxelSlice = rig["voxel"]
		var chunk := Vector2i(0, 0)
		var neighbour := Vector2i(1, 0)
		_build(cm, [chunk, neighbour])
		var sig_before := cm.cache_signature(chunk, cm.chunk_lod(chunk))
		cm.unload_chunk(chunk)
		var at := Vector2(32.0 + 16.25, 16.25)   # the middle of the neighbour: no seam rebuild reaches the cached chunk
		var top := voxel.get_voxel_height_at(at)
		var rev := voxel.edit_revision(neighbour)
		if how == "mine":
			assert_true(bool(voxel.mine_block(Vector3(at.x, top - 0.1, at.y))["success"]), "dug the neighbour")
		else:
			assert_true(voxel.place_block(Vector3(at.x, top + 0.1, at.y), Vector3.UP, "Ferrite"), "built on the neighbour")
		assert_true(voxel.edit_revision(neighbour) > rev, "%s bumps the neighbour's edit revision" % how)
		assert_true(cm.cache_signature(chunk, sig_before[0]) != sig_before, "so the cached chunk's signature moved")
		cm.load_chunk(chunk)
		assert_eq(cm.cache_attaches, 0, "after a %s in a neighbour the cache never hands back the older mesh" % how)
		assert_true(cm._has_in_flight(cm._chunk_key(chunk)) and cm._builds.keys().all(func(id): return id >= 0), "a worker builds it afresh")
		_wait_for_builds(cm)
		_free_rig(rig)

## Phase 194 (#512) — a hit used to attach inside dispatch: after waiting for a worker slot it never used, and
## ahead of the frame's apply order and pacing.
func _test_cache_hit_apply_order() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var near := Vector2i(1, 0)
	var far := Vector2i(2, 2)
	_build(cm, [near, far])
	cm.unload_chunk(near)
	cm.unload_chunk(far)
	cm.max_builds_in_flight = 1
	cm.load_chunk(Vector2i(0, 3))   # a worker build holds the only slot
	cm.refresh(false)   # the apply order reads the window's centre
	cm.load_chunk(far)
	cm.load_chunk(near)
	assert_true(cm._rebuild_queue.is_empty(), "a hit does not wait for the full pool")
	assert_eq(cm._m1.worker_builds(), 1, "and takes no worker slot")
	var done: Array = cm._builds.keys().filter(func(id): return id < 0)
	var order: Array = cm._apply_order(done).map(func(id): return cm._builds[id]["chunk"])
	assert_eq(order, [near, far], "the hit beside the body attaches before the one further out")
	cm.applies_per_frame = 1
	cm._apply_finished_builds()
	assert_eq(int(cm.is_chunk_built(near)) + int(cm.is_chunk_built(far)), 1, "one apply a frame, hits included")
	_wait_for_builds(cm)
	cm.flush_builds()
	assert_true(cm.is_chunk_built(near) and cm.is_chunk_built(far), "both attach")
	assert_eq(cm.cache_attaches, 2, "from the cache")
	_free_rig(rig)

func _test_cache_bytes_with_collision() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var chunk := Vector2i(0, 0)
	_build(cm, [chunk])
	var e: Dictionary = cm.chunk_cache()._entries[cm._chunk_key(chunk)]
	var arrays: Dictionary = e["arrays"]
	var mesh := 0
	for k in ["vertices", "normals", "colors", "indices", "collision"]:
		if arrays.has(k):
			mesh += ChunkCache.value_bytes(arrays[k])
	var faces := 0
	for sh in (arrays.get("shape_parts", []) as Array) + ([arrays["shape"]] if arrays.has("shape") else []):
		faces += (sh as ConcavePolygonShape3D).get_faces().size() * 12
	assert_true(faces > 0, "the fixture chunk carries collision shapes")
	assert_true(ChunkCache.approx_bytes(arrays) >= mesh + faces, "approx_bytes (%d) is at least the mesh arrays (%d) plus the collision faces (%d)" % [ChunkCache.approx_bytes(arrays), mesh, faces])
	assert_true(int(e["bytes"]) >= ChunkCache.approx_bytes(arrays) + (e["heightmap"] as Array).size() * ChunkCache.VARIANT_BYTES, "the entry counts its heightmap's slots too")
	_free_rig(rig)

## A chunk manager as `DistantTerrain.rebuild` reads it: a key, the unbuilt list (counted) and the body's chunk.
class StubChunks extends Node:
	var key: Array = [0]
	var unbuilt: Array = []
	var reads := 0
	func unbuilt_window_key() -> Array:
		return key
	func unbuilt_window_chunks() -> Array:
		reads += 1
		return unbuilt
	func player_chunk() -> Vector2i:
		return Vector2i.ZERO

## Phase 194 (#512, #444) — `rebuild` runs every frame; the window's unbuilt list (string keys, a dict) and the bands'
## update were recomputed each time.
func _test_distant_rebuild_on_change() -> void:
	var ring := DistantTerrainScript.new()
	ring.world_seed = 7
	add_child(ring)
	var bands: Node3D = ring.make_bands(self)
	var stub := StubChunks.new()
	ring.rebuild(Vector2(16.0, 16.0), 3, stub)
	assert_eq(stub.reads, 1, "the first frame reads the list")
	ring.rebuild(Vector2(17.0, 16.0), 3, stub)
	assert_eq(stub.reads, 1, "an unchanged key does not read it again")
	stub.key = [1]
	ring.rebuild(Vector2(17.0, 16.0), 3, stub)
	assert_eq(stub.reads, 2, "a changed key does")
	for i in 7:
		stub.unbuilt.append(Vector2i(1 + i, 2))
	stub.key = [2]
	ring.rebuild(Vector2(17.0, 16.0), 3, stub)
	assert_true(ring.fill_count() >= 1 and ring.fill_count() < stub.unbuilt.size(), "patches are paced per call (%d of %d)" % [ring.fill_count(), stub.unbuilt.size()])
	var frames := 1
	while ring.fill_count() < stub.unbuilt.size() and frames < 20:
		ring.rebuild(Vector2(17.0, 16.0), 3, stub)
		frames += 1
	assert_eq(ring.fill_count(), stub.unbuilt.size(), "patches still owed keep the list read until every one stands")
	var reads := stub.reads
	ring.rebuild(Vector2(17.0, 16.0), 3, stub)
	assert_eq(stub.reads, reads, "then it stops")
	bands.ring_radius_m = -1.0   # a marker: `update` writes it on every call
	ring.rebuild(Vector2(100.0, 16.0), 3, stub)
	assert_eq(bands.ring_radius_m, -1.0, "a move within band 0's cell leaves the bands alone")
	ring.rebuild(Vector2(16.0 + bands.CELL_0, 16.0), 3, stub)
	assert_true(bands.ring_radius_m > 0.0, "a move across a cell asks them again")
	bands.free()
	ring.free()
	stub.free()
