extends "res://src/tests/test_support.gd"
## Phase 283 — trees that look like trees: front-face winding, a model per species, a closed crown.

const VoxelSmoothScript := preload("res://src/terrain/voxel_smooth.gd")
const TreeMaterial := preload("res://src/world/tree_material.gd")

func register() -> void:
	_run_test("tree model: MeshUtil boxes face outward in Godot's winding", _test_box_winding)
	_run_test("tree model: the procedural fallback mesh faces outward",     _test_fallback_mesh_winding)
	_run_test("tree model: deposit markers face outward",                    _test_deposit_winding)
	_run_test("tree model: every species has a placeholder model",           _test_species_models)
	_run_test("tree model: a tree draws its species model, else the fallback", _test_model_or_fallback)
	_run_test("tree model: a pool made after a rebase starts at the shift", _test_pool_after_rebase)
	_run_test("tree model: the variant pick is stable for a tree id",        _test_variant_stable)
	_run_test("tree model: the placeholder crown is closed",                 _test_crown_closed)
	_run_test("tree model: the sway material is off on the low path",        _test_sway_material)
	_run_test("tree model: switching sway off swaps the live pools' material", _test_sway_runtime_swap)
	_run_test("tree model: a model that failed to load is retried later",    _test_model_retry)

## True when the triangle (a, b, c) is a front face seen from outside `center`: Godot 4 treats
## clockwise vertices as the front, so the geometric normal is (c - a) x (b - a).
func _faces_out(a: Vector3, b: Vector3, c: Vector3, center: Vector3) -> bool:
	var n := (c - a).cross(b - a)
	return n.dot((a + b + c) / 3.0 - center) > 0.0

func _test_box_winding() -> void:
	var center := Vector3(1.0, 2.0, -3.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	MeshUtil.add_box(st, center, Vector3(2.0, 1.0, 3.0), Color.WHITE)
	var v: PackedVector3Array = st.commit().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_eq(v.size(), MeshUtil.BOX_VERTEX_COUNT, "add_box emits 36 vertices")
	var bad := 0
	for i in range(0, v.size(), 3):
		if not _faces_out(v[i], v[i + 1], v[i + 2], center):
			bad += 1
	assert_eq(bad, 0, "every add_box triangle faces away from the box centre")
	var av := PackedVector3Array(); var an := PackedVector3Array()
	var ac := PackedColorArray(); var ai := PackedInt32Array()
	MeshUtil.add_box_arrays(av, an, ac, ai, center, Vector3(2.0, 1.0, 3.0), Color.WHITE)
	assert_eq(av.size(), MeshUtil.BOX_VERTEX_COUNT, "add_box_arrays emits 36 vertices")
	bad = 0
	for i in range(0, ai.size(), 3):
		var a := av[ai[i]]; var b := av[ai[i + 1]]; var c := av[ai[i + 2]]
		if not _faces_out(a, b, c, center):
			bad += 1
		# The stored normal agrees with the winding.
		if (c - a).cross(b - a).normalized().dot(an[ai[i]]) < 0.99:
			bad += 1
	assert_eq(bad, 0, "every add_box_arrays triangle faces outward and agrees with its normal")

func _test_fallback_mesh_winding() -> void:
	var t := _make_tree_slice()
	var v: PackedVector3Array = t._tree_mesh().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_eq(v.size(), MeshUtil.BOX_VERTEX_COUNT * 2, "a trunk box and a crown box")
	var bad := 0
	for i in range(0, v.size(), 3):
		var center := Vector3(0.0, TreeSlice.TRUNK_HEIGHT * 0.5, 0.0) if i < MeshUtil.BOX_VERTEX_COUNT \
			else Vector3(0.0, TreeSlice.TRUNK_HEIGHT + TreeSlice.CANOPY_HEIGHT * 0.5, 0.0)
		if not _faces_out(v[i], v[i + 1], v[i + 2], center):
			bad += 1
	assert_eq(bad, 0, "every fallback tree triangle faces outward")
	t.free()

func _test_deposit_winding() -> void:
	var center := Vector3(4.0, 1.0, 5.0)
	var res: Dictionary = VoxelSmoothScript._deposits_only({"deposits": [
		{"position": center, "local_position": center, "size": Vector3(0.4, 0.3, 0.5), "color": Color.RED}]}, false)
	var v: PackedVector3Array = res["deposit_vertices"]
	var idx: PackedInt32Array = res["deposit_indices"]
	assert_eq(v.size(), MeshUtil.BOX_VERTEX_COUNT, "one deposit box")
	var bad := 0
	for i in range(0, idx.size(), 3):
		if not _faces_out(v[idx[i]], v[idx[i + 1]], v[idx[i + 2]], center):
			bad += 1
	assert_eq(bad, 0, "every deposit marker triangle faces outward")

func _species_in_fabric() -> Array:
	var out: Array = []
	for biome in TreeSlice.TREES_BY_BIOME:
		var sp: String = str(TreeSlice.TREES_BY_BIOME[biome]["species"])
		if not out.has(sp):
			out.append(sp)
	return out

func _test_species_models() -> void:
	var species := _species_in_fabric()
	assert_true(species.size() >= 2, "the fabric has tree species")
	for sp in species:
		var keys: Array = TreeMaterial.model_keys(sp)
		assert_true(keys.size() >= 2, "%s has a base model and a variant" % sp)
		for k in keys:
			assert_true(AssetOverlay.has_key("meshes", k), "%s is in the manifest" % k)
			assert_true(TreeMaterial.model_mesh(k) != null, "%s loads" % k)

func _test_model_or_fallback() -> void:
	var t := _make_tree_slice()
	t.spawn_for_chunk(Vector2i(0, 0))
	var trees: Array = t.get_all_trees()
	# Issue #703 — the preconditions are asserted: a slice with no pool or no trees used to pass silently.
	assert_true(t._pool != null, "the suite's tree slice renders (has a pool)")
	assert_false(trees.is_empty(), "chunk (0,0) spawns at least one tree")
	if t._pool == null or trees.is_empty():
		t.free()
		return
	var tree: Dictionary = t.get_tree_record(str(trees[0]["tree_id"]))
	var key := str(tree["pool_key"])
	assert_eq(key, TreeMaterial.model_key_for(str(tree["species"]), str(tree["tree_id"])), "the tree uses its species model")
	assert_true(t._model_pools.has(key) and t._tree_pool(tree) == t._model_pools[key], "from the model's own pool")
	t.free()
	# A key that fails to load: the fallback pool draws the tree.
	var keys: Array = TreeMaterial.model_keys(str(tree["species"]))
	var saved: Dictionary = TreeMaterial._model_meshes.duplicate()
	for k in keys:
		TreeMaterial._model_meshes[k] = null
	var t2 := _make_tree_slice()
	t2.spawn_for_chunk(Vector2i(0, 0))
	var rec: Dictionary = t2.get_tree_record(str(trees[0]["tree_id"]))
	assert_eq(str(rec["pool_key"]), "", "an unloadable model falls back")
	assert_true(t2._tree_pool(rec) == t2._pool, "to the procedural pool")
	TreeMaterial._model_meshes = saved
	t2.free()

func _test_pool_after_rebase() -> void:
	var t := _make_tree_slice()
	assert_true(t._pool != null, "the suite's tree slice renders (has a pool)")
	if t._pool == null:
		t.free()
		return
	var shift := Vector3(512.0, 0.0, -256.0)
	t.shift_scene(shift)
	t.spawn_for_chunk(Vector2i(0, 0))
	var checked := 0
	for k in t._model_pools:
		if t._model_pools[k] != null:
			assert_eq(t._model_pools[k].scene_position(), shift, "a lazily made model pool carries the rebase shift")
			checked += 1
	assert_false(t.get_all_trees().is_empty(), "chunk (0,0) spawns at least one tree")
	assert_true(checked > 0, "a model pool was made")
	t.free()

func _test_variant_stable() -> void:
	var seen := {}
	for i in 64:
		var id := "tree_%d_0_%d" % [i, i % 8]
		var a := TreeMaterial.model_key_for("Thornwood", id)
		assert_eq(a, TreeMaterial.model_key_for("Thornwood", id), "the pick for %s is stable" % id)
		seen[a] = true
	assert_eq(seen.size(), 2, "both variants are picked across trees")
	assert_eq(TreeMaterial.model_key_for("NoSuchSpecies", "tree_0_0_0"), "", "no model, no key")

func _test_crown_closed() -> void:
	for sp in _species_in_fabric():
		for k in TreeMaterial.model_keys(sp):
			var mesh: Mesh = TreeMaterial.model_mesh(k)
			assert_true(mesh != null, "%s loads" % k)
			if mesh == null:
				continue
			var arrays := mesh.surface_get_arrays(0)
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var order: Array = Array(idx) if not idx.is_empty() else range(v.size())
			var edges := {}
			var tris := 0
			var volume := 0.0
			for i in range(0, order.size(), 3):
				var p: Array = [v[order[i]], v[order[i + 1]], v[order[i + 2]]]
				if p[0] == p[1] or p[1] == p[2] or p[0] == p[2]:
					continue
				tris += 1
				volume += (p[0] as Vector3).dot((p[2] as Vector3).cross(p[1])) / 6.0
				for e in 3:
					var a: Vector3 = p[e]; var b: Vector3 = p[(e + 1) % 3]
					var ka := _qkey(a); var kb := _qkey(b)
					var key := ka + "|" + kb if ka < kb else kb + "|" + ka
					edges[key] = int(edges.get(key, 0)) + 1
			var open := 0
			for e in edges:
				if edges[e] != 2:
					open += 1
			assert_eq(open, 0, "%s: every edge is shared by two triangles" % k)
			assert_true(tris > 100 and tris <= 600, "%s: a modest triangle count (%d)" % [k, tris])
			assert_true(volume > 0.0, "%s: the shells enclose positive volume in Godot's winding" % k)
			var aabb := mesh.get_aabb()
			assert_true(absf(aabb.position.y) < 0.01 and aabb.end.y > 3.0 and aabb.end.y < 4.0, "%s: foot on the ground, about 3.8 m tall" % k)
			assert_true(absf(aabb.end.y - TreeMaterial.SWAY_TO) < 0.1, "%s: the sway reaches full weight at the crown top (SWAY_TO %.2f, top %.2f)" % [k, TreeMaterial.SWAY_TO, aabb.end.y])

static func _qkey(p: Vector3) -> String:
	return "%d,%d,%d" % [roundi(p.x * 1000.0), roundi(p.y * 1000.0), roundi(p.z * 1000.0)]

func _test_sway_material() -> void:
	assert_true(TreeMaterial.make(true) is ShaderMaterial, "sway on: a shader material")
	var plain := TreeMaterial.make(false)
	assert_true(plain is StandardMaterial3D, "sway off: the plain vertex-colour material")
	assert_true((plain as StandardMaterial3D).vertex_color_use_as_albedo, "colours still drive the albedo")

## Issue #703 — a runtime switch to the low path (sway off) reaches pools that already exist.
func _test_sway_runtime_swap() -> void:
	var saved: Variant = ProjectSettings.get_setting(TreeMaterial.SWAY_SETTING, true)
	ProjectSettings.set_setting(TreeMaterial.SWAY_SETTING, true)
	var t := _make_tree_slice()
	t.spawn_for_chunk(Vector2i(0, 0))
	var pools: Array = [t._pool]
	pools.append_array(t._model_pools.values())
	assert_true(t._model_pools.size() > 0, "a model pool exists before the switch")
	for p in pools:
		assert_true(p.material() is ShaderMaterial, "sway on: %s sways" % p.name)
	ProjectSettings.set_setting(TreeMaterial.SWAY_SETTING, false)
	t.refresh_sway()
	for p in pools:
		assert_true(p.material() is StandardMaterial3D, "sway off at runtime: %s draws the plain material" % p.name)
	ProjectSettings.set_setting(TreeMaterial.SWAY_SETTING, true)
	t.refresh_sway()
	assert_true(t._pool.material() is ShaderMaterial, "and back on")
	ProjectSettings.set_setting(TreeMaterial.SWAY_SETTING, saved)
	t.free()

## Issue #703 — a model key whose mesh did not load is not cached as a null pool: once the mesh loads,
## the next tree of that key gets the model pool.
func _test_model_retry() -> void:
	var t := _make_tree_slice()
	t.spawn_for_chunk(Vector2i(0, 0))
	var trees: Array = t.get_all_trees()
	assert_false(trees.is_empty(), "chunk (0,0) spawns at least one tree")
	if trees.is_empty():
		t.free()
		return
	var tid := str(trees[0]["tree_id"])
	var species := str(t.get_tree_record(tid)["species"])
	var key := TreeMaterial.model_key_for(species, tid)
	t.free()
	var saved: Dictionary = TreeMaterial._model_meshes.duplicate()
	for k in TreeMaterial.model_keys(species):
		TreeMaterial._model_meshes[k] = null
	var t2 := _make_tree_slice()
	t2.spawn_for_chunk(Vector2i(0, 0))
	assert_eq(str(t2.get_tree_record(tid)["pool_key"]), "", "a failed load draws the fallback")
	assert_false(t2._model_pools.has(key), "and leaves no pool entry for the key")
	assert_true(t2._model_failed.has(key), "the failed key is remembered for the rest of the spawn, not reloaded per tree")
	TreeMaterial._model_meshes = saved
	t2.despawn_for_chunk(Vector2i(0, 0))
	t2.spawn_for_chunk(Vector2i(0, 0))
	assert_eq(str(t2.get_tree_record(tid)["pool_key"]), key, "once the model loads, a respawned tree uses it")
	assert_true(t2._model_pools.has(key), "from a newly made model pool")
	t2.free()
