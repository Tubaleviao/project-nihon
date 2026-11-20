extends "res://src/tests/test_support.gd"
## Phase 278 — loose stones and branches draw with their own item models, a yaw/scale jitter and variants.

const LooseItemSlice := preload("res://src/world/loose_item_slice.gd")
const StoneTools := preload("res://src/world/stone_tools.gd")
const NewcomerGrounds := preload("res://src/world/newcomer_grounds.gd")

const SEED := 7

func register() -> void:
	_run_test("loose items: one multimesh per kind present, with the kind's model mesh and no box", _test_model_meshes)
	_run_test("loose items: a missing model key falls back to a box with a vertex-colour material", _test_fallback)
	_run_test("loose items: the same tile gives the same yaw, scale and variant, within bounds", _test_look_deterministic)
	_run_test("loose items: an absent variant key is never picked and every loose kind has placeholder models", _test_variants)

func _drawn() -> Dictionary:
	var h := func(_p: Vector2) -> float: return 100.0
	SpawnFinderScript.prime_grounds(SEED, h)
	var l := LooseItemSlice.new()
	l.world_seed = SEED
	l.height_fn = h
	var c: Vector2 = NewcomerGrounds.centres(SEED)[0]
	var p := Vector3(c.x, 100.0, c.y)
	l.local_position = func() -> Vector3: return p
	add_child(l)
	l.redraw()
	return { "slice": l, "mms": l.drawn_multimeshes() }

func _test_model_meshes() -> void:
	var d := _drawn()
	var l: Node = d["slice"]
	var mms: Dictionary = d["mms"]
	assert_true(mms.size() >= 2, "both kinds are drawn (%d groups)" % mms.size())
	var kinds := {}
	for gk in mms.keys():
		kinds[str(gk).split("#")[0]] = true
		var mm: MultiMesh = mms[gk]
		assert_true(mm.mesh != null and not (mm.mesh is BoxMesh), "%s uses a model mesh, not a box" % gk)
	assert_true(kinds.has(StoneTools.BRANCH) and kinds.has(StoneTools.LOOSE_STONE), "a group for each kind")
	remove_child(l)
	l.free()

func _test_fallback() -> void:
	assert_true(LooseItemSlice.loose_mesh("models/items/NoSuchLoose.glb.raw", "Branch") == null, "an unknown key yields no model")
	var box := LooseItemSlice.fallback_box()
	var mat := box.material as StandardMaterial3D
	assert_true(mat != null and mat.vertex_color_use_as_albedo, "the fallback box shows the per-instance colours")

func _test_look_deterministic() -> void:
	var yaws := {}
	for tx in 60:
		var a := LooseItemSlice.look_at_tile(Vector2i(tx, 5), "Branch", 3)
		var b := LooseItemSlice.look_at_tile(Vector2i(tx, 5), "Branch", 3)
		assert_eq(a, b, "tile %d builds the same look twice" % tx)
		assert_true(float(a["scale"]) >= 0.85 and float(a["scale"]) <= 1.15, "scale %.3f in 0.85..1.15" % float(a["scale"]))
		assert_true(int(a["variant"]) >= 0 and int(a["variant"]) < 3, "variant in range")
		yaws[snappedf(float(a["yaw"]), 0.01)] = true
	assert_true(yaws.size() > 30, "yaws vary across tiles")

func _test_variants() -> void:
	for kind in LooseItemSlice.KINDS:
		var keys: Array = LooseItemSlice.variant_keys(kind)
		assert_eq(keys[0], AssetOverlay.item_model_key(kind), "%s: base key first" % kind)
		assert_true(AssetOverlay.has_key("meshes", keys[0]), "%s: base model in the manifest" % kind)
		assert_eq(keys.size(), 1 + LooseItemSlice.MAX_VARIANTS, "%s: every variant key has a placeholder" % kind)
		for k in keys:
			assert_true(AssetOverlay.has_key("meshes", k), "%s listed" % k)
			assert_true(FileAccess.file_exists(AssetOverlay.resolve_path(k)), "%s has a file" % k)
		for tx in 100:
			assert_true(int(LooseItemSlice.look_at_tile(Vector2i(tx, 0), kind, keys.size())["variant"]) < keys.size(), "picked variant exists")
	assert_eq(LooseItemSlice.look_at_tile(Vector2i(3, 4), "Branch", 1)["variant"], 0, "one key means variant 0")
