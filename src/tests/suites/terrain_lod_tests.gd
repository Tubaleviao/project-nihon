extends "res://src/tests/test_support.gd"
## Phase 190 — coarse chunks beyond the near ring: the coarse build's heights and seams, and the chunk
## manager's level per ring, upgrade on entering the detail ring, and the cases that stay at full detail.
## Native/GDScript parity of the coarse build is in `native_tests.gd`.

const VoxelCoarse := preload("res://src/terrain/voxel_coarse.gd")
const VoxelMesh := preload("res://src/terrain/voxel_mesh.gd")
const NearRing := preload("res://src/terrain/near_ring.gd")

## The largest amount a coarse level's mean top may stand above the full chunk's mean natural top, in
## metres. A cell stands at the highest of its tiles, so it is never below; on the probe chunks the
## measured bias is well under these.
const MEAN_TOLERANCE := { 2: 0.5, 4: 1.0 }

func register() -> void:
	_run_test("lod: a coarse chunk's mean height matches the full chunk's", _test_lod_mean_height)
	_run_test("lod: no gap at a seam between levels (full|coarse, coarse|coarse)", _test_lod_seams_closed)
	_run_test("lod: a coarse chunk meshes fewer quads, with a conservative collision", _test_lod_coarse_fewer_quads)
	_run_test("lod: the level per ring around a walking body", _test_lod_walking_rings)
	_run_test("lod: a fast flyer stands on coarse ground, upgraded once it slows", _test_lod_flying_rings)
	_run_test("lod: a coarse chunk is upgraded when it enters the detail ring", _test_lod_upgrade_on_enter)
	_run_test("lod: edited ground, lod off and a dedicated server build full", _test_lod_full_cases)
	_run_test("lod: a coarse chunk's trees and creatures wait for its upgrade, a peer's window's do not", _test_lod_contents_wait_for_upgrade)
	_run_test("lod: after a landing the chunk under the body is first in the upgrade queue", _test_lod_landing_upgrade_first)

func _probe_chunks() -> Array:
	var pole := TerrainSlice.pole_chunks()
	return [Vector2i(3, 2), Vector2i(300, 7), Vector2i(-1234, -90), Vector2i(40, pole * 2 / 3),
		Vector2i(7, pole - 3), Vector2i(0, 0), Vector2i(2047, -2047)]

## `chunk`'s build input as the coarse dispatch gathers it (the biomes of the 3×3), plus the seed a full build reads.
func _coarse_input(chunk: Vector2i, seed_v: int) -> Dictionary:
	var biomes := {}
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var c := Vector2i(chunk.x + dx, chunk.y + dz)
			biomes[VoxelSlice._chunk_key(c)] = TerrainSlice.biome_for_chunk(c, seed_v)
	return { "biomes": biomes, "seed": seed_v, "depleted": {} }

## Area-weighted mean height of the up-facing quads in `arrays`.
static func _mean_top(arrays: Dictionary) -> float:
	var v: PackedVector3Array = arrays["vertices"]
	var n: PackedVector3Array = arrays["normals"]
	var area := 0.0
	var sum := 0.0
	for q in range(0, v.size(), 4):
		if n[q] != Vector3.UP:
			continue
		var a := absf((v[q + 2].x - v[q].x) * (v[q + 2].z - v[q].z))
		area += a
		sum += a * v[q].y
	return sum / area if area > 0.0 else NAN

func _test_lod_mean_height() -> void:
	var seed_v := 424242
	var noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(noise, seed_v)
	ChunkRecordsScript.clear()
	for chunk: Vector2i in _probe_chunks():
		var hm := TerrainSlice.heightmap_for(chunk, seed_v, noise)
		var full := 0.0
		for h in hm:
			full += VoxelSlice._voxel_height(float(h))
		full /= float(hm.size())
		for step: int in VoxelCoarse.STEPS:
			var mean := _mean_top(VoxelCoarse.build_coarse_arrays(chunk, hm, _coarse_input(chunk, seed_v), step, true))
			assert_true(mean >= full - 0.001, "step %d at %s never dips under the true surface (%.3f vs %.3f)" % [step, str(chunk), mean, full])
			assert_true(mean - full <= float(MEAN_TOLERANCE[step]), "step %d at %s: mean %.3f within %.2f m of the full chunk's %.3f" % [step, str(chunk), mean, MEAN_TOLERANCE[step], full])

## Vertical spans [bottom, top] of the wall quads of `arrays` on the plane `axis` == `plane`, that cover
## the coordinate `along` on the other horizontal axis.
static func _walls_at(arrays: Dictionary, axis: int, plane: float, along: float) -> Array:
	var v: PackedVector3Array = arrays["vertices"]
	var n: PackedVector3Array = arrays["normals"]
	var out: Array = []
	var other := 2 if axis == 0 else 0
	for q in range(0, v.size(), 4):
		if absf(n[q][axis]) < 0.5:
			continue
		if absf(v[q][axis] - plane) > 0.001:
			continue
		var lo := INF
		var hi := -INF
		var a0 := INF
		var a1 := -INF
		for k in 4:
			lo = minf(lo, v[q + k].y)
			hi = maxf(hi, v[q + k].y)
			a0 = minf(a0, v[q + k][other])
			a1 = maxf(a1, v[q + k][other])
		if along > a0 + 0.001 and along < a1 - 0.001:
			out.append([lo, hi])
	return out

static func _covered(spans: Array, y: float) -> bool:
	for s in spans:
		if y >= float(s[0]) - 0.0005 and y <= float(s[1]) + 0.0005:
			return true
	return false

## The top of the up-facing quad of `arrays` over (x, z), or NAN.
static func _top_at(arrays: Dictionary, x: float, z: float) -> float:
	var v: PackedVector3Array = arrays["vertices"]
	var n: PackedVector3Array = arrays["normals"]
	var best := NAN
	for q in range(0, v.size(), 4):
		if n[q] != Vector3.UP:
			continue
		if x > minf(v[q].x, v[q + 2].x) and x < maxf(v[q].x, v[q + 2].x) and z > minf(v[q].z, v[q + 2].z) and z < maxf(v[q].z, v[q + 2].z):
			best = v[q].y if is_nan(best) else maxf(best, v[q].y)
	return best

## Every point of the seam between `a` (the lower chunk on `axis`) and `b` (the next one) from the lower
## surface to the higher one is on a wall of either side: nothing can be seen through.
func _assert_seam_closed(label: String, a: Dictionary, b: Dictionary, axis: int, plane: float, from: float) -> void:
	var gaps := 0
	var eps := 0.05
	for i in 64:
		var along := from + (float(i) + 0.5) * 0.5
		var pa := Vector2(plane - eps, along) if axis == 0 else Vector2(along, plane - eps)
		var pb := Vector2(plane + eps, along) if axis == 0 else Vector2(along, plane + eps)
		var ha := _top_at(a, pa.x, pa.y)
		var hb := _top_at(b, pb.x, pb.y)
		if is_nan(ha) or is_nan(hb):
			gaps += 1
			continue
		var spans := _walls_at(a, axis, plane, along) + _walls_at(b, axis, plane, along)
		var y := minf(ha, hb) + 0.01
		while y < maxf(ha, hb) - 0.005:
			if not _covered(spans, y):
				gaps += 1
				break
			y += 0.03
	assert_eq(gaps, 0, "%s: the seam is closed at every tile (%d open)" % [label, gaps])

func _full_arrays(chunk: Vector2i, hm: Array, seed_v: int, noise: FastNoiseLite) -> Dictionary:
	var input := _coarse_input(chunk, seed_v)
	var neighbours := {}
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var c := Vector2i(chunk.x + dx, chunk.y + dz)
			if c != chunk:
				neighbours[VoxelSlice._chunk_key(c)] = TerrainSlice.heightmap_for(c, seed_v, noise)
	input["edits"] = {}
	input["neighbour_heightmaps"] = neighbours
	return VoxelSlice.build_chunk_arrays(chunk, hm, VoxelSlice.build_runs(chunk, hm, input), false)

func _test_lod_seams_closed() -> void:
	var seed_v := 424242
	var noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(noise, seed_v)
	ChunkRecordsScript.clear()
	var m := TerrainSlice.CHUNK_METERS
	var relief := 0
	# Near enough to the origin that absolute float32 vertices are exact (a far chunk is meshed chunk-local).
	for base: Vector2i in [Vector2i(3, 2), Vector2i(300, 7), Vector2i(-1234, -90), Vector2i(-150, 60)]:
		var east := base + Vector2i(1, 0)
		var south := base + Vector2i(0, 1)
		var hm := TerrainSlice.heightmap_for(base, seed_v, noise)
		var hm_e := TerrainSlice.heightmap_for(east, seed_v, noise)
		var hm_s := TerrainSlice.heightmap_for(south, seed_v, noise)
		var full := _full_arrays(base, hm, seed_v, noise)
		var full_e := _full_arrays(east, hm_e, seed_v, noise)
		var full_s := _full_arrays(south, hm_s, seed_v, noise)
		var c2 := VoxelCoarse.build_coarse_arrays(base, hm, _coarse_input(base, seed_v), 2, false)
		var c2_e := VoxelCoarse.build_coarse_arrays(east, hm_e, _coarse_input(east, seed_v), 2, false)
		var c4_e := VoxelCoarse.build_coarse_arrays(east, hm_e, _coarse_input(east, seed_v), 4, false)
		var c4_s := VoxelCoarse.build_coarse_arrays(south, hm_s, _coarse_input(south, seed_v), 4, false)
		var x_plane := float(east.x) * m
		var z_plane := float(south.y) * m
		var x_from := float(base.y) * m
		var z_from := float(base.x) * m
		_assert_seam_closed("full | coarse 32 east of %s" % str(base), full, c2_e, 0, x_plane, x_from)
		_assert_seam_closed("coarse 32 | full east of %s" % str(base), c2, full_e, 0, x_plane, x_from)
		_assert_seam_closed("full | coarse 16 south of %s" % str(base), full, c4_s, 2, z_plane, z_from)
		_assert_seam_closed("coarse 32 | coarse 16 east of %s" % str(base), c2, c4_e, 0, x_plane, x_from)
		_assert_seam_closed("coarse 32 | full south of %s" % str(base), c2, full_s, 2, z_plane, z_from)
		for i in 64:
			var a := VoxelSlice._voxel_height(float(hm[i * 64 + 63]))
			var b := VoxelSlice._voxel_height(float(hm_e[i * 64]))
			if absf(a - b) >= 0.25:
				relief += 1
	assert_true(relief > 0, "the probe seams have height steps across them, so the closure is tested (%d)" % relief)

func _test_lod_coarse_fewer_quads() -> void:
	var seed_v := 424242
	var noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(noise, seed_v)
	var chunk := Vector2i(3, 2)
	var hm := TerrainSlice.heightmap_for(chunk, seed_v, noise)
	var full := _full_arrays(chunk, hm, seed_v, noise)
	var last := int(full["quad_count"])
	for step: int in VoxelCoarse.STEPS:
		var c := VoxelCoarse.build_coarse_arrays(chunk, hm, _coarse_input(chunk, seed_v), step, true)
		assert_eq((c["collision"] as PackedVector3Array).size(), int(c["quad_count"]) * 6, "step %d collides with the quads it draws" % step)
		assert_eq(int(c["lod"]), step, "step %d reports its level" % step)
		assert_true(int(c["quad_count"]) < last, "step %d meshes fewer quads (%d) than the level before (%d)" % [step, c["quad_count"], last])
		last = int(c["quad_count"])

## A build rig whose manager builds at the Phase 190 levels (the default).
func _lod_rig() -> Dictionary:
	return _make_chunk_build_rig()

func _free_rig(rig: Dictionary) -> void:
	for k in ["cm", "voxel", "terrain", "player", "creature", "tree"]:
		if rig.has(k) and is_instance_valid(rig[k]):
			rig[k].free()

func _build(cm: ChunkManager, chunks: Array) -> void:
	for c in chunks:
		cm.load_chunk(c)
	_wait_for_builds(cm)

func _stand(player: PlayerSlice, chunk: Vector2i) -> void:
	var m := TerrainSlice.CHUNK_METERS
	player.spawn_at(Vector3(float(chunk.x) * m + m * 0.5, 40.0, float(chunk.y) * m + m * 0.5))

func _test_lod_walking_rings() -> void:
	var rig := _lod_rig()
	var cm: ChunkManager = rig["cm"]
	var voxel: VoxelSlice = rig["voxel"]
	_build(cm, [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, -2), Vector2i(3, 0), Vector2i(4, 4)])
	assert_eq(cm.chunk_lod(Vector2i(0, 0)), VoxelCoarse.FULL, "the chunk under a walking body is full")
	assert_eq(cm.chunk_lod(Vector2i(1, 1)), VoxelCoarse.FULL, "its ring is full")
	assert_eq(cm.chunk_lod(Vector2i(2, -2)), VoxelCoarse.FULL, "two out (the 60 m reach) is full")
	assert_eq(cm.chunk_lod(Vector2i(3, 0)), 4, "three out is coarse (16×16)")
	assert_eq(cm.chunk_lod(Vector2i(4, 4)), 4, "four out is coarse (16×16)")
	assert_true(cm.is_chunk_built(Vector2i(3, 0)), "a coarse chunk counts as built (its ground is drawn)")
	assert_false(voxel.has_collision(Vector2i(3, 0)), "a coarse chunk out of reach has no collision attached")
	assert_true(voxel.has_parked_collision(Vector2i(3, 0)), "... and parks its coarse shape (Phase 189)")
	var root: Node3D = voxel._chunks[voxel._chunk_key(Vector2i(3, 0))]
	assert_true(root.get_child_count() > 0 and root.get_child(0) is MeshInstance3D, "a coarse chunk has its mesh")
	assert_eq(cm.chunk_lod(Vector2i(9, 9)), 0, "an unbuilt chunk has no level")
	cm.unload_chunk(Vector2i(3, 0))
	assert_eq(cm._near.lod_of(cm._chunk_key(Vector2i(3, 0))), VoxelCoarse.FULL, "an unload forgets the level")
	_free_rig(rig)

func _test_lod_flying_rings() -> void:
	var rig := _lod_rig()
	var cm: ChunkManager = rig["cm"]
	var voxel: VoxelSlice = rig["voxel"]
	var player: PlayerSlice = rig["player"]
	_stand(player, Vector2i(3, 0))
	player.flying = true
	var clock := [100000]
	cm.pump_clock_usec = func(): return clock[0] * 1000
	cm.note_local_crossing()
	clock[0] += 300
	cm.note_local_crossing()
	assert_true(cm.is_moving_fast(), "the body crosses chunks fast")
	_build(cm, [Vector2i(3, 0), Vector2i(4, 0), Vector2i(3, 1), Vector2i(5, 2), Vector2i(6, 0), Vector2i(7, -4)])
	assert_eq(cm.chunk_lod(Vector2i(3, 0)), 2, "the chunk below a fast flyer is coarse (32×32): nothing is upgraded at speed")
	assert_true(voxel.has_collision(Vector2i(3, 0)), "... and carries its conservative coarse collision")
	assert_eq(cm.chunk_lod(Vector2i(4, 0)), 2, "the next chunk is coarse (32×32)")
	assert_false(voxel.has_collision(Vector2i(4, 0)), "... without collision attached")
	assert_eq(cm.chunk_lod(Vector2i(5, 2)), 2, "two out is coarse (32×32)")
	assert_eq(cm.chunk_lod(Vector2i(6, 0)), 4, "three out is coarse (16×16)")
	assert_eq(cm.chunk_lod(Vector2i(7, -4)), 4, "four out is coarse (16×16)")
	cm._near.tick()
	assert_true(cm._builds.is_empty(), "a fast flyer's tick upgrades nothing")
	clock[0] += ChunkManager.FAST_HOLD_MSEC
	assert_false(cm.is_moving_fast(), "the flight slowed down")
	cm._near.tick()
	_wait_for_builds(cm)
	for c in [Vector2i(3, 0), Vector2i(4, 0), Vector2i(3, 1), Vector2i(5, 2)]:
		assert_eq(cm.chunk_lod(c), VoxelCoarse.FULL, "slowed down, %s in the reach ring is upgraded" % str(c))
	assert_true(voxel.has_collision(Vector2i(3, 0)), "the chunk below has its full collision")
	assert_eq(cm.chunk_lod(Vector2i(6, 0)), 4, "beyond the reach ring stays coarse")
	_free_rig(rig)

func _test_lod_upgrade_on_enter() -> void:
	var rig := _lod_rig()
	var cm: ChunkManager = rig["cm"]
	var voxel: VoxelSlice = rig["voxel"]
	var far := Vector2i(3, 0)
	_build(cm, [far, Vector2i(4, 0)])
	assert_eq(cm.chunk_lod(far), 4, "built coarse while the body is away")
	var heights_before := voxel.get_voxel_height_at(Vector2(3.0 * TerrainSlice.CHUNK_METERS + 5.0, 7.0))
	cm._near.tick()
	assert_true(cm._builds.is_empty(), "a tick with the body away upgrades nothing")
	_stand(rig["player"], Vector2i(2, 0))
	cm._near.tick()
	assert_eq(cm._builds.size(), 2, "entering the detail ring dispatches a full build for each coarse chunk it reaches")
	cm._near.tick()
	assert_eq(cm._builds.size(), 2, "a second tick does not dispatch them twice")
	assert_eq(cm.chunk_lod(far), 4, "the coarse mesh stays until the full one lands")
	_wait_for_builds(cm)
	assert_eq(cm.chunk_lod(far), VoxelCoarse.FULL, "the chunk is full detail now")
	assert_true(voxel.has_collision(far), "and has its collision (it is in the walking reach)")
	assert_eq(voxel.get_voxel_height_at(Vector2(3.0 * TerrainSlice.CHUNK_METERS + 5.0, 7.0)), heights_before, "height queries read the same map at either level")
	_stand(rig["player"], Vector2i(0, 0))
	cm._near.tick()
	assert_eq(cm.chunk_lod(far), VoxelCoarse.FULL, "leaving the ring does not downgrade a chunk in place")
	assert_true(cm._builds.is_empty(), "and dispatches nothing")
	_free_rig(rig)

func _test_lod_full_cases() -> void:
	var rig := _lod_rig()
	var cm: ChunkManager = rig["cm"]
	var voxel: VoxelSlice = rig["voxel"]
	var edited := Vector2i(3, 0)
	var top := voxel.get_voxel_height_at(Vector2(3.0 * TerrainSlice.CHUNK_METERS + 5.25, 5.25))
	voxel.apply_edits({ VoxelSlice._tile_key(Vector2i(3 * 64 + 10, 10)): [{ "op": "add", "bottom": top, "top": top + 0.5, "material": "Ferrite" }] })
	_build(cm, [edited, Vector2i(4, 0)])
	assert_eq(cm.chunk_lod(edited), VoxelCoarse.FULL, "a chunk with an edit is built full, so a placed block never vanishes")
	assert_eq(cm.chunk_lod(Vector2i(4, 0)), 4, "its unedited neighbour is coarse")
	_free_rig(rig)
	for case_i in range(3):
		var r := _lod_rig()
		var m: ChunkManager = r["cm"]
		match case_i:
			0: m.set_lod_enabled(false)
			1: m.set_near_ring_enabled(false)
			2: r["voxel"].attach_geometry = false
		_build(m, [Vector2i(4, 0)])
		assert_true(m.is_chunk_built(Vector2i(4, 0)), "case %d builds the chunk" % case_i)
		assert_eq(m.chunk_lod(Vector2i(4, 0)), VoxelCoarse.FULL, ["lod off", "the near ring off (the record flight)", "a process that draws nothing"][case_i] + " builds full detail")
		_free_rig(r)


## Phase 194 (#509) — a coarse cell stands at its highest tile, so a tree or a creature at its true height would
## sit buried under it: the chunk's contents wait for the full build. A peer's window is the peer's ground.
func _test_lod_contents_wait_for_upgrade() -> void:
	var rig := _lod_rig()
	var cm: ChunkManager = rig["cm"]
	var creature := CreatureSlice.new()
	add_child(creature)
	var tree := _make_tree_slice()
	cm.creature_slice = creature
	cm.tree_slice = tree
	rig["creature"] = creature
	rig["tree"] = tree
	var far := Vector2i(3, 0)
	_build(cm, [far])
	assert_eq(cm.chunk_lod(far), 4, "built coarse while the body is away")
	assert_true(cm._near.is_waiting(far), "its contents wait")
	assert_eq(tree.trees_in_chunk(far).size(), 0, "no tree stands on the coarse chunk")
	var creatures_here := func() -> int: return creature.get_all_instances().filter(func(i): return i["chunk"] == far).size()
	assert_eq(creatures_here.call(), 0, "and no creature")
	cm._near.tick()
	assert_true(cm._near.is_waiting(far), "a tick with the body away (and slow) still holds them")
	_stand(rig["player"], Vector2i(2, 0))
	cm._near.tick()
	_wait_for_builds(cm)
	assert_eq(cm.chunk_lod(far), VoxelCoarse.FULL, "the body came near: upgraded")
	assert_false(cm._near.is_waiting(far), "nothing waits any more")
	assert_true(tree.trees_in_chunk(far).size() + creatures_here.call() > 0, "the full chunk's contents stand")
	var peer_chunk := Vector2i(-6, 0)
	cm.set_peer_center(7, Vector2i(-8, 0), true)
	_build(cm, [peer_chunk])
	assert_true(cm.chunk_lod(peer_chunk) > VoxelCoarse.FULL, "two rings from the peer: coarse on this host")
	assert_false(cm._near.is_waiting(peer_chunk), "but in the peer's window its contents spawn: they are the peer's")
	assert_true(cm._contents_spawned.has(cm._chunk_key(peer_chunk)), "spawned once")
	_free_rig(rig)

## Phase 194 (#509) — landing after a fast flight, the body stands on coarse conservative collision until its chunk is
## upgraded, while the pool is full of the lane's builds: that upgrade goes to the head of the queue.
func _test_lod_landing_upgrade_first() -> void:
	var rig := _lod_rig()
	var cm: ChunkManager = rig["cm"]
	var player: PlayerSlice = rig["player"]
	var under := Vector2i(3, 0)
	_stand(player, under)
	player.flying = true
	var clock := [100000]
	cm.pump_clock_usec = func(): return clock[0] * 1000
	cm.note_local_crossing()
	clock[0] += 300
	cm.note_local_crossing()
	_build(cm, [under, Vector2i(4, 0), Vector2i(3, 1)])
	assert_eq(cm.chunk_lod(under), 2, "flown over: coarse")
	cm.max_builds_in_flight = 1
	cm.load_chunk(Vector2i(9, 9))   # the lane's build holds the only slot
	assert_eq(cm._m1.worker_builds(), 1, "the pool is full")
	cm._queue_rebuild(Vector2i(4, 0))
	cm._queue_rebuild(under)   # already waiting, at the back
	clock[0] += ChunkManager.FAST_HOLD_MSEC
	player.flying = false
	cm._near.tick()
	assert_eq(cm._rebuild_queue[0], under, "the chunk under the body is first")
	assert_eq(cm._rebuild_queue.count(under), 1, "once")
	assert_true(cm._near._want_full.has(cm._chunk_key(under)), "and its next build is the full one")
	cm._near.tick()
	assert_eq(cm._rebuild_queue[0], under, "a second tick leaves it at the head")
	cm.max_builds_in_flight = 4
	_wait_for_builds(cm)
	assert_eq(cm.chunk_lod(under), VoxelCoarse.FULL, "upgraded")
	_free_rig(rig)
