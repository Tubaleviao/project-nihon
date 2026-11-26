extends "res://src/tests/test_support.gd"
## Phase 245 — the terrain CSG helper: reference values per operation, `k` → 0 equal to the sharp form,
## and the shapes' signed distances.

const Csg := preload("res://src/terrain/terrain_csg.gd")

func register() -> void:
	_run_test("csg: sharp union, intersection and subtraction match reference values", _test_csg_sharp)
	_run_test("csg: smooth forms match reference values and reduce to the sharp form as k → 0", _test_csg_smooth)
	_run_test("csg: 2D shapes give the signed distance", _test_csg_shapes_2d)
	_run_test("csg: 3D shapes give the signed distance", _test_csg_shapes_3d)
	_run_test("csg: a 2 km diagonal capsule does not overflow int64", _test_csg_long_diagonal)
	_run_test("csg: isqrt is exact and results repeat", _test_csg_isqrt)

func _test_csg_sharp() -> void:
	assert_true(Csg.union(3000, -2000) == -2000, "union is the min")
	assert_true(Csg.intersection(3000, -2000) == 3000, "intersection is the max")
	assert_true(Csg.subtract(3000, 1000) == 3000, "subtract: outside the cutter keeps a")
	assert_true(Csg.subtract(-3000, -1000) == 1000, "subtract: inside the cutter becomes positive")
	assert_true(Csg.subtract(-3000, 5000) == -3000, "subtract: far from the cutter keeps a")

func _test_csg_smooth() -> void:
	# a == b: the polynomial blend lowers a union by k/4 and raises an intersection by k/4.
	assert_true(Csg.smooth_union(1000, 1000, 400) == 900, "smooth union of equals: min - k/4")
	assert_true(Csg.smooth_intersection(1000, 1000, 400) == 1100, "smooth intersection of equals: max + k/4")
	assert_true(Csg.smooth_subtract(1000, -1000, 400) == 1100, "smooth subtract of equals")
	# Beyond k the blend is the sharp form.
	assert_true(Csg.smooth_union(0, 400, 400) == 0, "smooth union at |a-b| = k is sharp")
	assert_true(Csg.smooth_union(0, 1000, 400) == 0, "smooth union beyond k is sharp")
	# k → 0 equals the sharp form for a sweep of pairs.
	var ok := true
	for a in range(-3000, 3001, 700):
		for b in range(-3000, 3001, 500):
			for k in [0, 1]:
				ok = ok and Csg.smooth_union(a, b, k) == Csg.union(a, b)
				ok = ok and Csg.smooth_intersection(a, b, k) == Csg.intersection(a, b)
				ok = ok and Csg.smooth_subtract(a, b, k) == Csg.subtract(a, b)
	assert_true(ok, "k → 0 equals the sharp form")
	# The smooth union never exceeds the sharp one, and stays within k/4 of it.
	var bounded := true
	for a in range(-2000, 2001, 250):
		for b in range(-2000, 2001, 250):
			var s := Csg.smooth_union(a, b, 800)
			bounded = bounded and s <= Csg.union(a, b) and Csg.union(a, b) - s <= 200
	assert_true(bounded, "smooth union lies within k/4 below the sharp union")

func _test_csg_shapes_2d() -> void:
	assert_true(Csg.disc(Vector2i(5000, 0), Vector2i.ZERO, 2000) == 3000, "disc outside")
	assert_true(Csg.disc(Vector2i(500, 0), Vector2i.ZERO, 2000) == -1500, "disc inside")
	var a := Vector2i(0, 0)
	var b := Vector2i(10000, 0)
	assert_true(Csg.capsule2(Vector2i(5000, 3000), a, b, 1000) == 2000, "capsule beside the segment")
	assert_true(Csg.capsule2(Vector2i(-3000, 4000), a, b, 1000) == 4000, "capsule past an end")
	assert_true(Csg.capsule2(Vector2i(5000, 0), a, b, 1000) == -1000, "capsule on the centreline")
	assert_true(Csg.capsule2(Vector2i(1000, 1000), a, a, 500) == Csg.disc(Vector2i(1000, 1000), a, 500), "degenerate capsule is a disc")
	var pts := [Vector2i(0, 0), Vector2i(10000, 0), Vector2i(10000, 10000)]
	var radii := [1000, 1000]
	assert_true(Csg.polyline(Vector2i(10000, 5000), pts, radii) == -1000, "polyline on its second segment")
	assert_true(Csg.polyline(Vector2i(5000, 5000), pts, radii) == 4000, "polyline away from both")
	assert_true(Csg.box2(Vector2i(0, 0), Vector2i.ZERO, Vector2i(1000, 2000)) == -1000, "box centre")
	assert_true(Csg.box2(Vector2i(4000, 0), Vector2i.ZERO, Vector2i(1000, 2000)) == 3000, "box outside a face")
	assert_true(Csg.box2(Vector2i(4000, 6000), Vector2i.ZERO, Vector2i(1000, 2000)) == 5000, "box outside a corner (3-4-5)")

func _test_csg_shapes_3d() -> void:
	assert_true(Csg.sphere(Vector3i(0, 6000, 0), Vector3i.ZERO, 2000) == 4000, "sphere")
	assert_true(Csg.cylinder(Vector3i(0, 0, 0), Vector3i.ZERO, 2000, 3000) == -2000, "cylinder centre")
	assert_true(Csg.cylinder(Vector3i(5000, 0, 0), Vector3i.ZERO, 2000, 3000) == 3000, "cylinder beside")
	assert_true(Csg.cylinder(Vector3i(0, 7000, 0), Vector3i.ZERO, 2000, 3000) == 4000, "cylinder above")
	assert_true(Csg.box3(Vector3i(0, 0, 0), Vector3i.ZERO, Vector3i(1000, 2000, 3000)) == -1000, "box3 centre")
	assert_true(Csg.box3(Vector3i(4000, 6000, 0), Vector3i.ZERO, Vector3i(1000, 2000, 3000)) == 5000, "box3 outside an edge")
	var a := Vector3i(0, 0, 0)
	var b := Vector3i(0, 10000, 0)
	assert_true(Csg.capsule3(Vector3i(3000, 5000, 0), a, b, 1000) == 2000, "capsule3 beside")
	assert_true(Csg.capsule3(Vector3i(0, 13000, 0), a, b, 1000) == 2000, "capsule3 past an end")

func _test_csg_isqrt() -> void:
	var ok := true
	for n in [0, 1, 2, 3, 4, 15, 16, 17, 999999, 1000000, 1 << 40, (1 << 40) + 1, (1 << 60) - 1]:
		var r := Csg.isqrt(n)
		ok = ok and r * r <= n and (r + 1) * (r + 1) > n
	assert_true(ok, "isqrt floors exactly")
	assert_true(Csg.isqrt(-5) == 0, "isqrt of a negative is 0")
	assert_true(Csg.smooth_union(123, 456, 789) == Csg.smooth_union(123, 456, 789), "repeatable")

## A 2 km cell diagonal (millimetres): `ab.x * dot` is about 1.6e19 there, past int64.
func _test_csg_long_diagonal() -> void:
	var a := Vector2i(0, 0)
	var b := Vector2i(2000000, 2000000)
	var p := Vector2i(1500000, 1500000)   # on the centreline, 75% along
	assert_true(Csg.capsule2(p, a, b, 1000) == -1000, "on the centreline of a long diagonal")
	var q := Vector2i(1500000 + 3000, 1500000 - 3000)
	var d := Csg.capsule2(q, a, b, 0)
	assert_true(absi(d - 4243) <= 2, "off the centreline by 3000 mm either way: %d" % d)
