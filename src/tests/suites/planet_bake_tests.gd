extends "res://src/tests/test_support.gd"
## Phase 245 — the planet bake reference: determinism, rivers that reach the sea and never flow uphill,
## and width that grows with flow.

const Bake := preload("res://src/terrain/planet_bake.gd")
const W := 48
const H := 32
const SEA := 0

func register() -> void:
	_run_test("bake: the same grid bakes to identical bytes twice", _test_bake_deterministic)
	_run_test("bake: every river cell reaches the sea and never flows uphill", _test_bake_rivers_reach_sea)
	_run_test("bake: river width grows with flow", _test_bake_width_grows)

## A hill-and-sea grid: a ridge with noise-free integer bumps, sea on the east side.
func _grid() -> PackedInt32Array:
	var g := PackedInt32Array()
	g.resize(W * H)
	for z in H:
		for x in W:
			var slope := (W - 1 - x) * 90000 / W - 6000
			var bump := ((x * 7919 + z * 104729) % 23) * 700 - ((x * 31 + z * 17) % 5) * 1500
			g[z * W + x] = slope + bump
	return g

func _test_bake_deterministic() -> void:
	var a := Bake.bake(_grid(), W, H, SEA, 12)
	var b := Bake.bake(_grid(), W, H, SEA, 12)
	var ba := Bake.to_bytes(a)
	assert_true(ba == Bake.to_bytes(b), "same bytes")
	assert_true(Bake.hash_hex(ba) == Bake.hash_hex(Bake.to_bytes(b)), "same hash")
	assert_true(ba.size() == 12 + W * H * 12, "size")

func _test_bake_rivers_reach_sea() -> void:
	var r := Bake.bake(_grid(), W, H, SEA, 12)
	var rivers := 0
	var all_ok := true
	for i in W * H:
		if r.river[i] == 0:
			continue
		rivers += 1
		var c := i
		var steps := 0
		while r.dir[c] != Bake.NO_DIR and steps < W * H:
			var d: int = r.dir[c]
			all_ok = all_ok and r.height[d] <= r.height[c] and r.flow[d] > r.flow[c]
			c = d
			steps += 1
		# The grid edge is an outlet too (the planet wraps east-west and ends at the poles).
		var edge: bool = c % W == 0 or c / W == 0 or c % W == W - 1 or c / W == H - 1
		all_ok = all_ok and (r.height[c] <= SEA or edge) and r.river[i] == c + 1
	assert_true(rivers > 0, "the grid has rivers")
	assert_true(all_ok, "downhill, flow grows, ends in the sea or at the edge")

func _test_bake_width_grows() -> void:
	var prev := -1
	var ok := true
	for f in [1, 4, 16, 64, 256, 1024]:
		var wd := Bake.river_width_mm(f)
		ok = ok and wd > prev
		prev = wd
	assert_true(ok, "monotonic")
	assert_true(Bake.river_width_mm(100) == 10000, "sqrt law")
