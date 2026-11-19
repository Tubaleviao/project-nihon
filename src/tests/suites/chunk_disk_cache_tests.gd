extends "res://src/tests/test_support.gd"
## Phase 244 — the chunk cache on disk: the region layer file (sector table, keys, growth, removal), the
## encoding of a build result, the byte cap with least-recently-used eviction, a revisit attaching from disk
## and the host's generated heightmaps.

const RegionLayerFile := preload("res://src/persistence/region_layer_file.gd")
const DiskChunkCache := preload("res://src/terrain/disk_chunk_cache.gd")
const VoxelMesh := preload("res://src/terrain/voxel_mesh.gd")

func register() -> void:
	_run_test("disk cache: region file round trip, wrong key is a miss", _test_file_roundtrip)
	_run_test("disk cache: region file entry that grows moves and the gap closes", _test_file_grow_and_remove)
	_run_test("disk cache: region file damage is a miss, never an error", _test_file_damage)
	_run_test("disk cache: encode and decode keep arrays, shapes and heightmap", _test_encode_roundtrip)
	_run_test("disk cache: every key part changes the key", _test_key_parts)
	_run_test("disk cache: the byte cap evicts the least recently used entries", _test_lru_cap)
	_run_test("disk cache: a revisit attaches from disk and matches a fresh build", _test_revisit_from_disk)
	_run_test("disk cache: an edit makes the entry a miss", _test_edit_invalidates)
	_run_test("disk cache: a later session reads the generator's heightmap instead of generating", _test_gen_layer)

func _dir() -> String:
	var d := "user://test_chunk_disk_cache/%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(d)
	return d

func _rm(d: String) -> void:
	var da := DirAccess.open(d)
	if da == null:
		return
	for f in da.get_files():
		DirAccess.remove_absolute(d + f)
	for sub in da.get_directories():
		_rm(d + sub + "/")
	DirAccess.remove_absolute(d)

func _bytes(n: int, seed_v: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(n)
	for i in n:
		b[i] = (i * 7 + seed_v) % 251
	return b

func _free_rig(rig: Dictionary) -> void:
	for k in ["cm", "voxel", "terrain", "player"]:
		if rig.has(k) and is_instance_valid(rig[k]):
			rig[k].free()

func _test_file_roundtrip() -> void:
	var d := _dir()
	var f := RegionLayerFile.new(d + "r.bin")
	var a := _bytes(5000, 1)
	assert_true(f.put(3, 111, a), "stored")
	assert_eq(f.get_entry(3, 111), a, "read back")
	assert_true(f.get_entry(3, 112).is_empty(), "another key is a miss")
	assert_true(f.get_entry(4, 111).is_empty(), "an absent slot is a miss")
	assert_true(f.has(3, 111) and not f.has(3, 5), "has() checks the key")
	var again := RegionLayerFile.new(d + "r.bin")
	assert_eq(again.get_entry(3, 111), a, "a new object over the same file reads it")
	assert_eq(RegionLayerFile.index_of(Vector2i(-1, -1)), 1023, "index wraps by region")
	assert_false(f.put(5, 1, _random_bytes(1500000)), "an entry over 255 sectors is refused")
	_rm(d)

func _random_bytes(n: int) -> PackedByteArray:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var b := PackedByteArray()
	b.resize(n)
	for i in n:
		b[i] = rng.randi() & 255
	return b

func _test_file_grow_and_remove() -> void:
	var d := _dir()
	var f := RegionLayerFile.new(d + "r.bin")
	var small := _random_bytes(3000)
	var other := _random_bytes(9000)
	f.put(0, 1, small)
	f.put(1, 2, other)
	f.put(2, 3, small)
	var big := _random_bytes(20000)
	assert_true(f.put(0, 1, big), "an entry that outgrows its sectors is moved")
	assert_eq(f.get_entry(0, 1), big, "the grown entry reads")
	assert_eq(f.get_entry(1, 2), other, "its neighbours survive the gap closing")
	assert_eq(f.get_entry(2, 3), small, "and the one after them")
	var size_before := FileAccess.get_file_as_bytes(d + "r.bin").size()
	f.remove(1)
	assert_true(f.get_entry(1, 2).is_empty(), "removed")
	assert_eq(f.get_entry(0, 1), big, "entries before the removed one are intact")
	assert_eq(f.get_entry(2, 3), small, "entries after it slid down intact")
	assert_true(FileAccess.get_file_as_bytes(d + "r.bin").size() < size_before, "the file shrank")
	assert_true(RegionLayerFile.new(d + "r.bin").get_entry(2, 3) == small, "and the table on disk matches")
	_rm(d)

func _test_file_damage() -> void:
	var d := _dir()
	var f := RegionLayerFile.new(d + "r.bin")
	f.put(0, 1, _bytes(6000, 3))
	var fa := FileAccess.open(d + "r.bin", FileAccess.WRITE)
	fa.store_buffer(_bytes(100, 9))   # a torn header
	fa.close()
	var g := RegionLayerFile.new(d + "r.bin")
	assert_true(g.get_entry(0, 1).is_empty(), "a short file is a miss")
	assert_true(g.put(0, 1, _bytes(100, 4)), "and is writable again")
	assert_eq(g.get_entry(0, 1), _bytes(100, 4), "after a rewrite")
	var h := FileAccess.open(d + "r.bin", FileAccess.READ_WRITE)
	h.seek(RegionLayerFile.SECTOR + 20)
	h.store_buffer(_bytes(30, 5))   # garbage inside the compressed bytes
	h.close()
	assert_true(RegionLayerFile.new(d + "r.bin").get_entry(0, 1).is_empty(), "a damaged entry is a miss")
	_rm(d)

func _test_encode_roundtrip() -> void:
	var faces := PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)])
	var arrays := { "vertices": faces, "lod": 1, "collision": faces, "shape": VoxelMesh.collision_shape(faces) }
	var hm: Array = [1.0, 2.5, 3.0]
	var d := DiskChunkCache.decode(DiskChunkCache.encode(arrays, hm))
	assert_eq(d["heightmap"], hm, "heightmap")
	assert_eq(d["arrays"]["vertices"], faces, "vertices")
	assert_true(d["arrays"]["shape"] is ConcavePolygonShape3D and (d["arrays"]["shape"] as ConcavePolygonShape3D).get_faces() == faces, "the shape is made again from the faces")
	var split := { "collision": faces, "shape_parts": [VoxelMesh.collision_shape(faces), VoxelMesh.collision_shape(faces)] }
	var s := DiskChunkCache.decode(DiskChunkCache.encode(split, hm))
	assert_eq((s["arrays"]["shape_parts"] as Array).size(), 2, "quadrant shapes too")
	assert_true(DiskChunkCache.encode({ "node": RefCounted.new() }, hm).is_empty(), "an object that cannot be stored refuses the entry")
	assert_true(DiskChunkCache.decode(_bytes(40, 2)).is_empty(), "garbage decodes to nothing")

func _test_key_parts() -> void:
	var base := DiskChunkCache.key_of([1, [0], [5]])
	assert_true(base != DiskChunkCache.key_of([4, [0], [5]]), "the level")
	assert_true(base != DiskChunkCache.key_of([1, [9], [5]]), "an edit digest")
	assert_true(base != DiskChunkCache.key_of([1, [0], [6]]), "a generation record")
	assert_eq(base, DiskChunkCache.key_of([1, [0], [5]]), "the same inputs, the same key")
	assert_true(DiskChunkCache.key_of([1]) != DiskChunkCache.gen_key_of([1]), "the mesher version is in the mesh key only")

func _test_lru_cap() -> void:
	var d := _dir()
	var c := DiskChunkCache.new(d, 3 * RegionLayerFile.SECTOR)   # room for three one-sector entries
	for i in 3:
		c.write("mesh", Vector2i(i, 0), 10 + i, _random_bytes(300))
	assert_eq(c.entry_count(), 3, "three fit")
	assert_false(c.read("mesh", Vector2i(0, 0), 10).is_empty(), "touch the first one")
	c.write("mesh", Vector2i(3, 0), 13, _random_bytes(300))
	assert_true(c.bytes() <= c.max_bytes, "within the cap")
	assert_true(c.read("mesh", Vector2i(1, 0), 11).is_empty(), "the least recently used entry went")
	assert_false(c.read("mesh", Vector2i(0, 0), 10).is_empty(), "the touched one stayed")
	assert_false(c.read("mesh", Vector2i(3, 0), 13).is_empty(), "and the new one")
	var reopened := DiskChunkCache.new(d, 3 * RegionLayerFile.SECTOR)
	assert_eq(reopened.entry_count(), 3, "a new session finds the entries on disk")
	c.clear()
	assert_eq(c.bytes(), 0, "clear empties it")
	_rm(d)

func _test_revisit_from_disk() -> void:
	var d := _dir()
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	cm._m1.disk_cache = DiskChunkCache.new(d)
	var chunk := Vector2i(0, 0)
	cm.load_chunk(chunk)
	_wait_for_builds(cm)
	cm._m1.disk_cache.flush()
	var fresh: Dictionary = cm.chunk_cache()._entries[cm._chunk_key(chunk)]
	assert_true(cm._m1.disk_cache.entry_count() >= 1, "the build was written")
	cm.unload_chunk(chunk)
	cm.chunk_cache().clear()   # a new session: nothing in memory
	cm.load_chunk(chunk)
	assert_false(cm._builds.is_empty(), "a decode task waits to attach")
	_wait_for_builds(cm)
	assert_true(cm.is_chunk_built(chunk), "built")
	assert_eq(cm._m1.disk_attaches, 1, "from the disk cache")
	var again: Dictionary = cm.chunk_cache()._entries[cm._chunk_key(chunk)]
	assert_eq(again["arrays"]["vertices"], fresh["arrays"]["vertices"], "the same vertices as the fresh build")
	assert_eq(again["heightmap"], fresh["heightmap"], "and heightmap")
	_free_rig(rig)
	_rm(d)

func _test_edit_invalidates() -> void:
	var d := _dir()
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var voxel: VoxelSlice = rig["voxel"]
	cm._m1.disk_cache = DiskChunkCache.new(d)
	var chunk := Vector2i(0, 0)
	cm.load_chunk(chunk)
	_wait_for_builds(cm)
	cm._m1.disk_cache.flush()
	cm.unload_chunk(chunk)
	cm.chunk_cache().clear()
	var top := voxel.get_voxel_height_at(Vector2(5.25, 5.25))
	voxel.apply_edits({ VoxelSlice._tile_key(Vector2i(10, 10)): [{ "op": "add", "bottom": top, "top": top + 0.5, "material": "Ferrite" }] })
	cm.load_chunk(chunk)
	_wait_for_builds(cm)
	assert_eq(cm._m1.disk_attaches, 0, "an edit made while it was away: the disk entry is a miss and the chunk builds")
	assert_true(cm.is_chunk_built(chunk), "built")
	assert_true(voxel._query.edit_digest(chunk) != 0 and voxel._query.edit_digest(Vector2i(5, 5)) == 0, "the digest is per chunk, 0 without edits")
	_free_rig(rig)
	_rm(d)

func _test_gen_layer() -> void:
	var d := _dir()
	var chunk := Vector2i(1, 1)
	var first := _gen_once(d, chunk)
	assert_eq(first[1], 0, "the first session found nothing")
	var second := _gen_once(d, chunk)
	assert_eq(second[1], 1, "a later session read the stored map")
	assert_eq(second[0], first[0], "the same heightmap")
	_rm(d)

## [heightmap, gen hits] after one build of `chunk` with a gen cache in `dir`.
func _gen_once(dir: String, chunk: Vector2i) -> Array:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	cm._m1.gen_cache = DiskChunkCache.new(dir)
	rig['terrain'].set_world_seed(4242)
	cm.load_chunk(chunk)
	_wait_for_builds(cm)
	cm._m1.gen_cache.flush()
	var hm: Array = cm.chunk_cache()._entries[cm._chunk_key(chunk)]["heightmap"].duplicate()
	var hits: int = cm._m1.gen_cache.hits
	_free_rig(rig)
	return [hm, hits]
