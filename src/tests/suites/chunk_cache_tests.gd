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
	_run_test("distant: the ring covers an unbuilt window chunk and leaves a built one to the voxel mesh", _test_distant_unbuilt_cover)

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
	assert_true(cm._builds.is_empty(), "the return dispatches no worker task")
	assert_true(cm.is_chunk_built(chunk), "yet the chunk is built at once")
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
	assert_eq(per, 120, "10 vertices are 120 bytes")
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
