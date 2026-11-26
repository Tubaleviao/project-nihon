extends "res://src/tests/test_support.gd"
## Phase 245 — `terrain_csg.gd`: reference values for every operation and shape, and `k` → 0 equal to the sharp form.
const Csg := preload("res://src/terrain/terrain_csg.gd")

func register() -> void:
	_run_test("terrain_csg: sharp operations", _test_csg_sharp)
	_run_test("terrain_csg: smooth operations reduce to sharp as k goes to 0", _test_csg_smooth_limit)
	_run_test("terrain_csg: smooth union reference values", _test_csg_smooth_reference)
	_run_test("terrain_csg: 2D shapes", _test_csg_shapes_2d)
	_run_test("terrain_csg: 3D shapes", _test_csg_shapes_3d)
	_run_test("terrain_csg: integer square root is exact", _test_csg_isqrt)

func _test_csg_sharp() -> void:
	assert_eq(Csg.op_union(3, -2), -2)
	assert_eq(Csg.op_subtract(5, 2), 5, "outside both stays")
	assert_eq(Csg.op_subtract(-5, -2), 2, "inside b is carved away")
	assert_eq(Csg.op_intersect(3, -2), 3)

func _test_csg_smooth_limit() -> void:
	for a in [-3000, -10, 0, 500, 4096]:
		for b in [-2048, -1, 0, 7, 3000]:
			assert_eq(Csg.smooth_union(a, b, 0), Csg.op_union(a, b))
			assert_eq(Csg.smooth_subtract(a, b, 0), Csg.op_subtract(a, b))
			assert_eq(Csg.smooth_intersect(a, b, 0), Csg.op_intersect(a, b))
			# Far apart (|a - b| >= k) the smooth form is the sharp one too.
			var k := 8
			if absi(a - b) >= k:
				assert_eq(Csg.smooth_union(a, b, k), Csg.op_union(a, b))

func _test_csg_smooth_reference() -> void:
	# Equal distances, k = 1 m: the blend takes k / 4 = 0.25 m off the union.
	assert_eq(Csg.smooth_union(0, 0, Csg.ONE), -Csg.ONE / 4)
	assert_eq(Csg.smooth_intersect(0, 0, Csg.ONE), Csg.ONE / 4)
	assert_eq(Csg.smooth_subtract(0, 0, Csg.ONE), Csg.ONE / 4)
	# Half way into the blend (|a - b| = k / 2): h = 0.5, correction k / 16.
	assert_eq(Csg.smooth_union(0, Csg.ONE / 2, Csg.ONE), -Csg.ONE / 16)

func _test_csg_shapes_2d() -> void:
	var m := Csg.ONE
	assert_eq(Csg.disc(5 * m, 0, 0, 0, 2 * m), 3 * m)
	assert_eq(Csg.disc(0, 0, 0, 0, 2 * m), -2 * m)
	assert_eq(Csg.capsule(5 * m, 3 * m, 0, 0, 10 * m, 0, m), 2 * m, "beside the middle")
	assert_eq(Csg.capsule(13 * m, 0, 0, 0, 10 * m, 0, m), 2 * m, "past the end")
	assert_eq(Csg.capsule(1, 1, 0, 0, 0, 0, 0), Csg.isqrt(2), "a zero-length capsule is a disc")
	var pts := [Vector2i(0, 0), Vector2i(10 * m, 0), Vector2i(10 * m, 10 * m)]
	assert_eq(Csg.polyline(10 * m, 5 * m, pts, m), -m, "on the second leg")
	assert_eq(Csg.polyline(5 * m, 2 * m, pts, 0), 2 * m)
	assert_eq(Csg.box(5 * m, 0, 0, 0, 2 * m, 2 * m), 3 * m)
	assert_eq(Csg.box(0, 0, 0, 0, 2 * m, 3 * m), -2 * m)
	assert_eq(Csg.box(5 * m, 6 * m, 0, 0, 2 * m, 2 * m), 5 * m, "the corner: 3-4-5")

func _test_csg_shapes_3d() -> void:
	var m := Csg.ONE
	assert_eq(Csg.sphere(0, 5 * m, 0, 0, 0, 0, 2 * m), 3 * m)
	assert_eq(Csg.cylinder(5 * m, 0, 0, 0, 0, 0, 2 * m, 4 * m), 3 * m)
	assert_eq(Csg.cylinder(0, 0, 0, 0, 0, 0, 2 * m, 4 * m), -2 * m)
	assert_eq(Csg.cylinder(5 * m, 7 * m, 0, 0, 2 * m, 0, 2 * m, 1 * m), 5 * m, "past the rim and the lid: 3-4-5")
	assert_eq(Csg.box3(5 * m, 0, 0, 0, 0, 0, 2 * m, 2 * m, 2 * m), 3 * m)
	assert_eq(Csg.box3(0, 0, 0, 0, 0, 0, 2 * m, 3 * m, 4 * m), -2 * m)
	assert_eq(Csg.capsule3(5 * m, 3 * m, 0, 0, 0, 0, 10 * m, 0, 0, m), 2 * m)
	assert_eq(Csg.capsule3(0, 0, 0, 0, 0, 0, 0, 0, 0, m), -m)

func _test_csg_isqrt() -> void:
	for n in [0, 1, 2, 3, 4, 15, 16, 17, 1 << 30, (1 << 40) + 12345, (1 << 50) - 1]:
		var r: int = Csg.isqrt(n)
		assert_true(r * r <= n and (r + 1) * (r + 1) > n, "isqrt(%d)" % n)
