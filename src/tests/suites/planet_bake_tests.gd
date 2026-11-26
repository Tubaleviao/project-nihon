extends "res://src/tests/test_support.gd"
## Phase 245 — the planet bake reference: determinism, rivers that reach the sea and never flow uphill,
## and width that grows with flow.

const Bake := preload("res://src/terrain/planet_bake.gd")
const Csg := preload("res://src/terrain/terrain_csg.gd")
const W := 48
const H := 32
const SEA := 0

func register() -> void:
	_run_test("bake: the same grid bakes to identical bytes twice", _test_bake_deterministic)
	_run_test("bake: every river cell reaches the sea and never flows uphill", _test_bake_rivers_reach_sea)
	_run_test("bake: river width grows with flow", _test_bake_width_grows)
	_run_test("bake: a corrupted or truncated file is refused by its hash", _test_bake_corrupt_refused)
	_run_test("bake: the native bake and CSG operations equal the GDScript reference", _test_bake_native_parity)
	_run_test("bake: the planet bakes from the world shape, saves and reloads, and a damaged file is refused", _test_bake_planet_file)
	_run_test("bake: thermal erosion softens slopes, keeps sea and mass, and the native twin matches", _test_bake_erosion)
	_run_test("bake: hydrology reads the baked rivers and carves the ground below their water", _test_bake_hydrology)
	_run_test("bake: ensure loads a good file, and bakes again when it is damaged or not the host's", _test_bake_ensure)
	_run_test("bake: the bake-only boot skips the main menu and the file name carries seed and version", _test_bake_cli)
	_run_test("bake: a carved river lies below the water with soft banks", _test_bake_carve)

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

func _test_bake_corrupt_refused() -> void:
	var bytes := Bake.to_bytes(Bake.bake(_grid(), W, H, SEA, 12))
	var good := Bake.hash_hex(bytes)
	var ok := Bake.from_bytes(bytes, good)
	assert_true(not ok.is_empty() and ok.w == W and ok.h == H, "good file loads")
	var bad := bytes.duplicate()
	bad[100] = bad[100] ^ 0xFF
	assert_true(Bake.from_bytes(bad, good).is_empty(), "flipped byte refused")
	assert_true(Bake.from_bytes(bytes, "00").is_empty(), "wrong hash refused")
	assert_true(Bake.from_bytes(bytes.slice(0, 20), good).is_empty(), "truncated refused")

func _test_bake_carve() -> void:
	# 50 segments of varied direction and width: the centreline lies below the water, banks step <= 0.5 m.
	var ok_centre := true
	var ok_bank := true
	for s in 50:
		var a := Vector2i(s * 1300, s * 700)
		var b := a + Vector2i(40000 + s * 500, (s % 7 - 3) * 9000)
		var width := Bake.river_width_mm(4 + s * 3)
		var water := 3000
		var ground := 6000 + (s % 5) * 400
		var mid := (a + b) / 2
		ok_centre = ok_centre and Bake.carved_height(ground, mid, a, b, width, water, 2000, 1500) < water
		var prev := Bake.carved_height(ground, mid, a, b, width, water, 2000, 1500)
		for step in range(1, 60):
			var q := Vector2i(mid.x, mid.y + step * 500)
			var hq := Bake.carved_height(ground, q, a, b, width, water, 2000, 1500)
			ok_bank = ok_bank and absi(hq - prev) <= 500
			prev = hq
	assert_true(ok_centre, "centreline below the water surface")
	assert_true(ok_bank, "no bank step over 0.5 m")

func _test_bake_native_parity() -> void:
	var bases: Array = [_grid()]
	var rng := RandomNumberGenerator.new()
	rng.seed = 245
	for t in 3:
		var g := PackedInt32Array()
		g.resize(W * H)
		for i in W * H:
			g[i] = rng.randi_range(-8000, 90000)
		bases.append(g)
	var cases: Array = []
	for g in bases:
		cases.append([g, W, H, SEA, 12])
		cases.append([g, W, H, 20000, 5])
	var mism := 0
	if NativeLoaderScript.use_native("NativeBake", "bake"):
		for c: Array in cases:
			var a: Dictionary = Bake.bake_gd(c[0], c[1], c[2], c[3], c[4])
			var b: Dictionary = NativeLoaderScript.instance("NativeBake").callv("bake", c)
			if a.height != b.height or a.dir != b.dir or a.flow != b.flow or a.river != b.river:
				mism += 1
		assert_eq(mism, 0, "native bake equals the reference on %d grids" % cases.size())
	var op: Array = []
	for i in 3000:
		op.append([rng.randi_range(-30000, 30000), rng.randi_range(-30000, 30000), rng.randi_range(-3, 4000)])
	assert_native_parity("NativeBake", "smooth_union", op, Csg.smooth_union)
	assert_native_parity("NativeBake", "smooth_intersection", op, Csg.smooth_intersection)
	assert_native_parity("NativeBake", "smooth_subtract", op, Csg.smooth_subtract)
	var sq: Array = []
	for i in 3000:
		sq.append([rng.randi_range(-5, 1 << 50)])
	assert_native_parity("NativeBake", "isqrt", sq, Csg.isqrt)
	var caps: Array = []
	for i in 3000:
		caps.append([Vector2i(rng.randi_range(-90000, 90000), rng.randi_range(-90000, 90000)), Vector2i(rng.randi_range(-90000, 90000), rng.randi_range(-90000, 90000)),
			Vector2i(rng.randi_range(-90000, 90000), rng.randi_range(-90000, 90000)), rng.randi_range(0, 5000)])
	caps.append([Vector2i(5, 5), Vector2i(1, 1), Vector2i(1, 1), 100])
	assert_native_parity("NativeBake", "capsule2", caps, Csg.capsule2)
	var v2 := func() -> Vector2i: return Vector2i(rng.randi_range(-90000, 90000), rng.randi_range(-90000, 90000))
	var v3 := func() -> Vector3i: return Vector3i(rng.randi_range(-90000, 90000), rng.randi_range(-90000, 90000), rng.randi_range(-90000, 90000))
	var dc: Array = []
	var bx: Array = []
	var pl: Array = []
	var sp: Array = []
	var cy: Array = []
	var b3: Array = []
	var c3: Array = []
	for i in 1500:
		dc.append([v2.call(), v2.call(), rng.randi_range(0, 5000)])
		bx.append([v2.call(), v2.call(), Vector2i(rng.randi_range(0, 9000), rng.randi_range(0, 9000))])
		pl.append([v2.call(), [v2.call(), v2.call(), v2.call()], [rng.randi_range(0, 4000), rng.randi_range(0, 4000)], rng.randi_range(0, 3000)])
		sp.append([v3.call(), v3.call(), rng.randi_range(0, 5000)])
		cy.append([v3.call(), v3.call(), rng.randi_range(0, 5000), rng.randi_range(0, 5000)])
		b3.append([v3.call(), v3.call(), Vector3i(rng.randi_range(0, 9000), rng.randi_range(0, 9000), rng.randi_range(0, 9000))])
		c3.append([v3.call(), v3.call(), v3.call(), rng.randi_range(0, 5000)])
	c3.append([Vector3i(5, 5, 5), Vector3i(1, 1, 1), Vector3i(1, 1, 1), 100])
	assert_native_parity("NativeBake", "disc", dc, Csg.disc)
	assert_native_parity("NativeBake", "box2", bx, Csg.box2)
	assert_native_parity("NativeBake", "polyline", pl, Csg.polyline)
	assert_native_parity("NativeBake", "sphere", sp, Csg.sphere)
	assert_native_parity("NativeBake", "cylinder", cy, Csg.cylinder)
	assert_native_parity("NativeBake", "box3", b3, Csg.box3)
	assert_native_parity("NativeBake", "capsule3", c3, Csg.capsule3)

func _test_bake_planet_file() -> void:
	var circ := float(TerrainSlice.circumference_chunks()) * 32.0
	var a := Bake.bake_planet(12345, 64, 32, circ, 20)
	var b := Bake.bake_planet(12345, 64, 32, circ, 20)
	assert_true(Bake.to_bytes(a) == Bake.to_bytes(b), "the planet bakes to the same bytes twice")
	var c := Bake.bake_planet(54321, 64, 32, circ, 20)
	assert_true(Bake.to_bytes(a) != Bake.to_bytes(c), "another seed bakes another planet")
	var path := "user://test_planet_bake.bin"
	assert_true(Bake.save(a, path), "saved")
	var back := Bake.load_file(path)
	assert_true(not back.is_empty() and back.height == a.height and back.flow == a.flow and back.river == a.river and back.dir == a.dir, "reloads equal, its flow directions rebuilt")
	var raw := FileAccess.get_file_as_bytes(path)
	raw[40] = raw[40] ^ 0x55
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(raw)
	f.close()
	assert_true(Bake.load_file(path).is_empty(), "a damaged file is refused")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".sha256")


func _test_bake_erosion() -> void:
	var g := _grid()
	var e: PackedInt32Array = Bake.erode(g, W, H, SEA)
	assert_eq(e, Bake.erode(g, W, H, SEA), "erosion is deterministic")
	var steep_before := 0
	var steep_after := 0
	var mass_before := 0
	var mass_after := 0
	for z in H:
		for x in range(W - 1):
			var i := z * W + x
			if g[i] > SEA and g[i + 1] > SEA:
				steep_before = maxi(steep_before, absi(g[i] - g[i + 1]))
				steep_after = maxi(steep_after, absi(e[i] - e[i + 1]))
	for i in W * H:
		if g[i] <= SEA:
			assert_eq(e[i], g[i], "a sea cell never changes")
		else:
			mass_before += g[i]
			mass_after += e[i]
	assert_true(steep_after <= steep_before, "the steepest step did not grow (%d -> %d)" % [steep_before, steep_after])
	assert_true(absi(mass_after - mass_before) <= W * H, "land mass is conserved within integer rounding")
	if NativeLoaderScript.use_native("NativeBake", "erode"):
		var rng := RandomNumberGenerator.new()
		rng.seed = 2452
		var bad := 0
		for t in 6:
			var r := PackedInt32Array()
			r.resize(W * H)
			for i in W * H:
				r[i] = rng.randi_range(-8000, 90000)
			if NativeLoaderScript.instance("NativeBake").call("erode", r, W, H, SEA) != Bake.erode(r, W, H, SEA):
				bad += 1
		assert_eq(bad, 0, "native erosion equals the reference")


const Hydrology := preload("res://src/terrain/hydrology.gd")

func _test_bake_hydrology() -> void:
	var bk := Bake.bake(_grid(), W, H, SEA, 12)
	var cell := 2000.0
	var half := cell * H * 0.5
	var segs: Array = Hydrology.baked_segs(bk, cell, 0.0, -half, cell * W, half)
	var rivers := 0
	for i in W * H:
		if bk.river[i] != 0 and bk.dir[i] >= 0:
			rivers += 1
	assert_true(rivers > 0, "the bake has rivers")
	assert_eq(segs.size(), rivers, "one segment per baked river cell")
	var checked := 0
	var ok := true
	for sg in segs:
		var f := { "lakes": [], "segs": [sg] }
		var mx: float = (sg[0] + sg[2]) * 0.5
		var mz: float = (sg[1] + sg[3]) * 0.5
		var wt := Hydrology.water_at(f, mx, mz)
		if wt.is_empty():
			ok = false
			continue
		# Ground at the centreline is carved to the bed, which lies under the surface; banks end at the waterline.
		ok = ok and float(wt["bed"]) < float(wt["surface"]) and sg[4] >= sg[5]
		checked += 1
		if checked >= 50:
			break
	assert_true(ok and checked > 0, "%d baked segments hold water above a carved bed and run downhill" % checked)
	assert_true(Hydrology.baked_segs(bk, cell, 1.0e9, 1.0e9, 1.0e9 + 10.0, 1.0e9 + 10.0).is_empty(), "a box beyond the poles has no rivers")
	assert_true(not Hydrology.has_bake(7), "no bake loaded by default")


func _test_bake_ensure() -> void:
	var dir := "user://bake_test_%d" % Time.get_ticks_usec()
	var path: String = Bake.file_path(dir, 5, 14, 24, 16)
	var a: Dictionary = Bake.ensure(path, 5, 24, 16, 400000.0, 12)
	assert_true(not a.loaded, "the first call bakes")
	var b: Dictionary = Bake.ensure(path, 5, 24, 16, 400000.0, 12, a.hash)
	assert_true(b.loaded and b.hash == a.hash, "the second reads the file and its hash matches")
	var c: Dictionary = Bake.ensure(path, 5, 24, 16, 400000.0, 12, "00" + a.hash.substr(2))
	assert_true(not c.loaded and c.hash == a.hash, "a hash the host did not announce is refused and re-baked")
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	f.seek(20)
	f.store_8(0xAB)
	f.close()
	var d: Dictionary = Bake.ensure(path, 5, 24, 16, 400000.0, 12, a.hash)
	assert_true(not d.loaded and d.hash == a.hash, "a damaged file is refused and re-baked to the same bytes")
	for fn in [path, path + ".sha256"]:
		DirAccess.remove_absolute(fn)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))


func _test_bake_cli() -> void:
	const MenuWiring := preload("res://src/menu/menu_wiring.gd")
	assert_true(not MenuWiring.should_show_main_menu(["--bake-planet", "build/bake"]), "--bake-planet boots without the menu")
	assert_eq(Bake.file_path("d", 238, 13, 1000, 500), "d/planet_238_v13_1000x500.bin", "file name")
