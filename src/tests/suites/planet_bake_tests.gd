extends "res://src/tests/test_support.gd"
## Phase 245 — the planet bake (reference): the same bytes twice, rivers that reach the sea and never climb, width
## that grows with flow, and a corrupted file refused by its hash.
const Bake := preload("res://src/terrain/planet_bake.gd")
const Csg := preload("res://src/terrain/terrain_csg.gd")

const W := 48
const H := 24

func register() -> void:
	_run_test("planet_bake: twice gives identical bytes", _test_bake_deterministic)
	_run_test("planet_bake: rivers reach the sea and never flow uphill", _test_bake_rivers)
	_run_test("planet_bake: flow grows downstream and a river is wider with more flow", _test_bake_flow_grows)
	_run_test("planet_bake: a corrupted bake is refused", _test_bake_hash_refuses)
	_run_test("river_carve: channel below the water, banks under 0.5 m a tile", _test_carve_channel)

func _heights() -> PackedInt32Array:
	# A continent: a hash-noise ramp that rises inland, sea round the poles and the left edge.
	var out := PackedInt32Array()
	out.resize(W * H)
	for z in H:
		for x in W:
			var hsh := ((x * 73856093) ^ (z * 19349663) ^ 0x5bd1e995) & 0xffff
			var dome := (H / 2 - absi(z - H / 2)) * 12 + mini(x, W - x) * 3 - 30
			out[z * W + x] = (dome * Csg.ONE) + (hsh % 2048)
	return out

func _test_bake_deterministic() -> void:
	var a := Bake.to_bytes(Bake.bake(W, H, _heights()))
	var b := Bake.to_bytes(Bake.bake(W, H, _heights()))
	assert_true(a == b, "same bytes")
	assert_eq(Bake.hash_of(a), Bake.hash_of(b))
	var back := Bake.from_bytes(a)
	assert_true(Bake.to_bytes(back) == a, "round trip")

func _test_bake_rivers() -> void:
	var p := Bake.default_params()
	var r := Bake.bake(W, H, _heights())
	var rivers := 0
	for i in W * H:
		if r["river"][i] == 0:
			continue
		rivers += 1
		var at := i
		var steps := 0
		while r["dir"][at] != Bake.NO_DIR:
			var nx := Bake.neighbour(W, H, at, r["dir"][at])
			assert_true(r["filled"][nx] < r["filled"][at], "never uphill")
			at = nx
			steps += 1
			if steps > W * H:
				break
		assert_true(steps <= W * H, "terminates")
		assert_true(r["filled"][at] <= int(p["sea_level"]), "ends in the sea")
	assert_true(rivers > 0, "the test planet has rivers")

func _test_bake_flow_grows() -> void:
	var r := Bake.bake(W, H, _heights())
	var checked := 0
	for i in W * H:
		if r["dir"][i] == Bake.NO_DIR:
			continue
		var n := Bake.neighbour(W, H, i, r["dir"][i])
		assert_true(r["flow"][n] > r["flow"][i], "flow grows downstream")
		# Width is the root of flow (the carve's radius): never narrower downstream.
		assert_true(Csg.isqrt(r["flow"][n]) >= Csg.isqrt(r["flow"][i]), "width grows")
		checked += 1
	assert_true(checked > 0)

func _test_bake_hash_refuses() -> void:
	var bytes := Bake.to_bytes(Bake.bake(W, H, _heights()))
	var good := Bake.hash_of(bytes)
	assert_true(Bake.accepts(bytes, good))
	var bad := bytes.duplicate()
	bad[100] = bad[100] ^ 0xff
	assert_false(Bake.accepts(bad, good), "corrupted bytes refused")
	assert_false(Bake.accepts(PackedByteArray(), good), "empty refused")
	assert_true(Bake.from_bytes(bytes.slice(0, 50)).is_empty(), "truncated file unreadable")

# ---- the carve ----
const Carve := preload("res://src/terrain/river_carve.gd")

func _test_carve_channel() -> void:
	var m := Csg.ONE
	var pts: Array = []
	for i in 51:   # 50 segments along x, bending a little
		pts.append(Vector2i(i * 8 * m, (i % 7) * 2 * m))
	var depth := 2 * m
	var bank := 8 * m
	var half := 2 * m
	var tile := m / 2
	var water := 10 * m - m / 2   # the water surface: half a metre under the flat ground, as a river sits in its bed
	var steps_checked := 0
	for s in 50:
		var a: Vector2i = pts[s]
		var b: Vector2i = pts[s + 1]
		var mid := Vector2i((a.x + b.x) / 2, (a.y + b.y) / 2)
		var noise := ((s * 7919) % 600) - 300   # detail noise of +-0.3 m
		var centre := Carve.carve(10 * m + noise, mid.x, mid.y, pts, half, depth, bank)
		assert_true(centre < water, "centreline under the water surface (segment %d)" % s)
		# Walk across the bank in tile steps at the same noise: no step over 0.5 m.
		var prev := centre
		for k in range(1, 40):
			var h := Carve.carve(10 * m + noise, mid.x, mid.y + k * tile, pts, half, depth, bank)
			assert_true(absi(h - prev) <= m / 2, "bank step <= 0.5 m (segment %d tile %d)" % [s, k])
			prev = h
		steps_checked += 1
	assert_eq(steps_checked, 50)
	assert_eq(Carve.cut_at(bank, depth, bank), 0)
	assert_eq(Carve.cut_at(0, depth, bank), depth)
	assert_true(Carve.depth_for_flow(400, m / 8, 5 * m) >= Carve.depth_for_flow(100, m / 8, 5 * m), "depth grows with flow")
