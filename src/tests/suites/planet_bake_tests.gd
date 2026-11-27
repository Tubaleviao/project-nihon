extends "res://src/tests/test_support.gd"
## Phase 245 — the planet bake reference: determinism, rivers that reach the sea and never flow uphill,
## and width that grows with flow.

const Bake := preload("res://src/terrain/planet_bake.gd")
const Csg := preload("res://src/terrain/terrain_csg.gd")
const BakeJob := preload("res://src/terrain/bake_job.gd")
const W := 48
const H := 32
const SEA := 0

func register() -> void:
	_run_test("bake: the same grid bakes to identical bytes twice", _test_bake_deterministic)
	_run_test("bake: every river cell reaches the sea and never flows uphill", _test_bake_rivers_reach_sea)
	_run_test("bake: river width grows with flow", _test_bake_width_grows)
	_run_test("bake: release_planet_bake drops the seed's bake (old worlds, hosts without one)", _test_bake_release)
	_run_test("bake: a corrupted or truncated file is refused by its hash", _test_bake_corrupt_refused)
	_run_test("bake: the native bake and CSG operations equal the GDScript reference", _test_bake_native_parity)
	_run_test("bake: the planet bakes from the world shape, saves and reloads, and a damaged file is refused", _test_bake_planet_file)
	_run_test("bake: thermal erosion softens slopes, keeps sea and mass, and the native twin matches", _test_bake_erosion)
	_run_test("bake: hydraulic erosion is deterministic, lowers river channels, keeps every river reaching the sea, and the native twin matches", _test_bake_hydraulic)
	_run_test("bake: every cell of a baked planet has a biome that matches the climate rules, and the biome byte survives the file", _test_bake_biomes)
	_run_test("bake: hydrology reads the baked rivers and carves the ground below their water", _test_bake_hydrology)
	_run_test("bake: ensure loads a good file, and bakes again when it is damaged or not the host's", _test_bake_ensure)
	_run_test("bake: the bake-only boot skips the main menu and the file name carries seed and version", _test_bake_cli)
	_run_test("bake: a carved river lies below the water with soft banks", _test_bake_carve)
	_run_test("bake (302): a worldgen-14 world bakes the Phase 245 bytes, a newer one the new profile", _test_bake_profiles, true)
	_run_test("bake (302): the baked macro height is interpolated continuously across its cells", _test_bake_macro_interpolated)
	_run_test("bake (302): the generator reads the baked macro height when a bake is loaded, native and GDScript alike", _test_bake_macro_used, true)
	_run_test("bake (302): along 50 baked rivers the runtime ground lies below the water and no bank step exceeds 0.5 m", _test_bake_runtime_carve, true)

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
			for v in [Bake.BAKE_VERSION_245, Bake.BAKE_VERSION]:   # Phase 302: both bake profiles
				var pf := Bake.profile(v)
				var a: Dictionary = Bake.bake_gd(c[0], c[1], c[2], c[3], c[4], Callable(), v)
				var b: Dictionary = NativeLoaderScript.instance("NativeBake").callv("bake", c + [int(pf.talus), bool(pf.hydraulic)])
				if a.height != b.height or a.dir != b.dir or a.flow != b.flow or a.river != b.river:
					mism += 1
		assert_eq(mism, 0, "native bake equals the reference on %d grids, both profiles" % cases.size())
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


## A steep fixture for thermal erosion (Phase 302): a spike far steeper than the talus beside a massif whose
## flanks are gentler than it, sea on the east side.
func _steep_grid() -> PackedInt32Array:
	var g := PackedInt32Array()
	g.resize(W * H)
	for z in H:
		for x in W:
			var spike := maxi(0, 9000000 - (absi(x - 12) + absi(z - 16)) * 1800000)   # 1.8 km per cell
			var massif := maxi(0, 8500000 - (absi(x - 30) + absi(z - 16)) * 400000)   # 400 m per cell, under the talus
			g[z * W + x] = maxi(spike, massif) + 2000 if x < W - 6 else -5000
	return g

func _test_bake_erosion() -> void:
	# Phase 302: slopes over the talus relax, slopes under it (real mountains) keep their summit.
	var sg := _steep_grid()
	var se: PackedInt32Array = Bake.erode(sg, W, H, SEA)
	assert_true(se[16 * W + 12] < sg[16 * W + 12], "a spike steeper than the talus is worn down (%d -> %d mm)" % [sg[16 * W + 12], se[16 * W + 12]])
	assert_eq(se[16 * W + 30], sg[16 * W + 30], "a summit whose flanks are under the talus keeps its height")
	var gentle_kept := true
	for z in range(12, 21):
		for x in range(27, 34):
			gentle_kept = gentle_kept and se[z * W + x] == sg[z * W + x]
	assert_true(gentle_kept, "the massif's 20% flanks are untouched")
	var steep_max_before := 0
	var steep_max_after := 0
	for z in H:
		for x in range(W - 7):
			steep_max_before = maxi(steep_max_before, absi(sg[z * W + x] - sg[z * W + x + 1]))
			steep_max_after = maxi(steep_max_after, absi(se[z * W + x] - se[z * W + x + 1]))
	assert_true(steep_max_after < steep_max_before, "the steepest land step shrinks (%d -> %d mm)" % [steep_max_before, steep_max_after])
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
				r[i] = rng.randi_range(-8000, 3000000)   # up to 3 km between neighbours: well over the talus
			if NativeLoaderScript.instance("NativeBake").call("erode", r, W, H, SEA, Bake.ERODE_TALUS_MM) != Bake.erode(r, W, H, SEA):
				bad += 1
			if NativeLoaderScript.instance("NativeBake").call("erode", r, W, H, SEA, Bake.ERODE_TALUS_245_MM) != Bake.erode(r, W, H, SEA, Bake.ERODE_TALUS_245_MM):
				bad += 1
		assert_eq(bad, 0, "native erosion equals the reference")
		assert_eq(NativeLoaderScript.instance("NativeBake").call("erode", sg, W, H, SEA, Bake.ERODE_TALUS_MM), se, "native erosion of the steep fixture equals the reference")


func _test_bake_hydraulic() -> void:
	var g := _grid()
	var th: PackedInt32Array = Bake.erode(g, W, H, SEA)
	var hy: PackedInt32Array = Bake.hydraulic(th, W, H, SEA, 12)
	assert_eq(hy, Bake.hydraulic(th, W, H, SEA, 12), "hydraulic erosion is deterministic")
	var lowered := 0
	for i in W * H:
		assert_true(hy[i] <= th[i], "erosion never raises a cell")
		if th[i] <= SEA:
			assert_eq(hy[i], th[i], "a sea cell never changes")
		else:
			assert_true(hy[i] > SEA, "land stays above the sea")
		if hy[i] < th[i]:
			lowered += 1
	assert_true(lowered > 0, "some river channel was cut")
	# Rivers of the eroded bake still reach the sea and never run uphill.
	var bk := Bake.bake(g, W, H, SEA, 12)
	var rivers := 0
	for i in W * H:
		if int(bk["river"][i]) == 0:
			continue
		rivers += 1
		var c := i
		var guard := 0
		while int(bk["dir"][c]) != Bake.NO_DIR and int(bk["height"][c]) > SEA and guard < W * H:
			assert_true(int(bk["height"][int(bk["dir"][c])]) <= int(bk["height"][c]), "a river never flows uphill")
			c = int(bk["dir"][c])
			guard += 1
		# The grid edge is an outlet too, as in `_test_bake_rivers_reach_sea` (the fixture's ends are no planet's poles).
		var edge: bool = c % W == 0 or c / W == 0 or c % W == W - 1 or c / W == H - 1
		assert_true(int(bk["height"][c]) <= SEA or edge, "a river reaches the sea")
	assert_true(rivers > 0, "the grid has rivers")
	if NativeLoaderScript.use_native("NativeBake", "hydraulic"):
		var rng := RandomNumberGenerator.new()
		rng.seed = 3022
		var bad := 0
		for t in 6:
			var r := PackedInt32Array()
			r.resize(W * H)
			for i in W * H:
				r[i] = rng.randi_range(-8000, 90000)
			if NativeLoaderScript.instance("NativeBake").call("hydraulic", r, W, H, SEA, 12) != Bake.hydraulic(r, W, H, SEA, 12):
				bad += 1
		assert_eq(bad, 0, "native hydraulic erosion equals the reference")


func _test_bake_biomes() -> void:
	var circ := 16.0 * Bake.CELL_M
	var bk := Bake.bake_planet(7, 16, 8, circ, 6)
	var biome: PackedByteArray = bk["biome"]
	var keys: Array = TerrainSliceScript.BIOME_KEYS
	assert_eq(biome.size(), 16 * 8, "one biome byte per cell")
	var valid := true
	for v in biome:
		valid = valid and int(v) < keys.size()
	assert_true(valid, "every cell has a biome of the key list")
	assert_eq(biome, Bake.biome_field(bk, 7, circ, keys), "the field is deterministic")
	# Spot check against the climate rules: a cell is the biome the climate picks at its centre and eroded height.
	var cell := circ / 16.0
	var half := cell * 4.0
	var bad := 0
	for i in [0, 21, 50, 77, 100, 127]:
		var cz := (float(i / 16) + 0.5) * cell - half
		var chunk := Vector2i(floori((float(i % 16) + 0.5) * cell / TerrainSliceScript.CHUNK_METERS), floori(cz / TerrainSliceScript.CHUNK_METERS))
		var alt := float(int(bk["height"][i]) - int(bk["sea_mm"])) * 0.001
		var want: String = ClimateFieldScript.biome_for_chunk(7, chunk, keys, TerrainSliceScript.latitude_of(chunk.y), alt, roundi(circ / TerrainSliceScript.CHUNK_METERS))
		if keys[int(biome[i])] != want:
			bad += 1
	assert_eq(bad, 0, "the field matches the climate rules")
	var back := Bake.from_bytes(Bake.to_bytes(bk), Bake.hash_hex(Bake.to_bytes(bk)))
	assert_eq(back.get("biome", PackedByteArray()), biome, "the biome byte survives to_bytes and from_bytes")


const TerrainSliceScript := preload("res://src/terrain/terrain_slice.gd")
const ClimateFieldScript := preload("res://src/terrain/climate_field.gd")
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


func _test_bake_release() -> void:
	var t := TerrainSlice.new()
	var b: Dictionary = Bake.bake_planet(9, 24, 12, 400000.0, 12)
	Hydrology.use_bake(t.get_world_seed(), b, 400000.0)
	assert_true(t.has_planet_bake(), "the slice sees its seed's bake")
	t.release_planet_bake()
	assert_true(not t.has_planet_bake() and not Hydrology.has_bake(t.get_world_seed()), "release returns to the local trace")
	t.free()


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


# ---- Phase 302 — macro height from the bake, soft banks at runtime ----

const MACRO_SEED := 302302

## The bake's macro height: equal to the baked height at every cell centre, continuous across cell borders,
## bounded by the four surrounding cells inside a cell, and wrapping round the planet in X.
func _test_bake_macro_interpolated() -> void:
	var bk := Bake.bake(_grid(), W, H, SEA, 12)
	var cell := 2000.0
	var half := cell * H * 0.5
	var centres_ok := true
	for i in [0, 7, W + 3, 5 * W + 20, (H - 1) * W + W - 1]:
		var x := (float(i % W) + 0.5) * cell
		var z := (float(i / W) + 0.5) * cell - half
		centres_ok = centres_ok and absf(Bake.sample_height(bk, cell, x, z) - float(bk.height[i]) * 0.001) < 1e-9
	assert_true(centres_ok, "the macro height equals the baked height at each cell centre")
	# C0: across every vertical and horizontal cell border of a strip the two sides agree.
	var worst := 0.0
	var jump := 0.0
	for k in 200:
		var bx := float(k % W) * cell + 1000.0   # a border between centres (k, k+1) lies at (k + 1) * cell
		var bz := (float(k % (H - 1)) + 1.0) * cell - half
		var e := 1e-4
		worst = maxf(worst, absf(Bake.sample_height(bk, cell, bx + 1000.0 - e, bz - 300.0) - Bake.sample_height(bk, cell, bx + 1000.0 + e, bz - 300.0)))
		worst = maxf(worst, absf(Bake.sample_height(bk, cell, bx + 300.0, bz - e) - Bake.sample_height(bk, cell, bx + 300.0, bz + e)))
		# A 0.5 m step anywhere changes the height by at most the cell's steepest gradient times 0.5 m.
		jump = maxf(jump, absf(Bake.sample_height(bk, cell, bx, bz) - Bake.sample_height(bk, cell, bx + 0.5, bz)))
	assert_true(worst < 0.01, "no step across a 2 km cell border (worst %.6f m over 0.2 mm)" % worst)
	assert_true(jump < 50.0, "the field has no jump between neighbouring tiles (worst %.3f m)" % jump)
	var bounded := true
	for k in 100:
		var x := 731.0 + float(k) * 997.3
		var z := -half + 1500.0 + float(k) * 523.1
		var gx := floori(x / cell - 0.5)
		var gz := clampi(floori((z + half) / cell - 0.5), 0, H - 2)
		var cs: Array = []
		for c in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			cs.append(float(bk.height[(gz + c.y) * W + posmod(gx + c.x, W)]) * 0.001)
		var v := Bake.sample_height(bk, cell, x, z)
		bounded = bounded and v >= float(cs.min()) - 1e-9 and v <= float(cs.max()) + 1e-9
	assert_true(bounded, "inside a cell the height lies between its four centres")
	assert_true(absf(Bake.sample_height(bk, cell, 123.0, 4567.0) - Bake.sample_height(bk, cell, 123.0 + cell * W, 4567.0)) < 1e-9, "X wraps round the planet")
	assert_true(absf(Bake.sample_height(bk, cell, -10.0, 100.0) - Bake.sample_height(bk, cell, cell * W - 10.0, 100.0)) < 1e-9, "the antimeridian is seamless")

## With a bake loaded the generator's macro height is the bake's (spawn plain kept), native and GDScript
## heightmaps agree on it, and without one (or with a worldgen-14 bake) it is `WorldShape.height` again.
func _test_bake_macro_used() -> void:
	var circ := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	var w := 64
	var bk := Bake.bake_planet(MACRO_SEED, w, w / 2, circ, 12)
	var cell := circ / float(w)
	var far := Vector2(circ * 0.25 + 777.0, 3210.0)   # far from the spawn plain
	var shape := WorldShape.height(MACRO_SEED, far.x, far.y, circ)
	assert_eq(TerrainSlice.macro_height(MACRO_SEED, far.x, far.y, circ), shape, "no bake: the macro height is the world shape")
	Hydrology.use_bake(MACRO_SEED, bk, circ, false)
	assert_eq(TerrainSlice.macro_height(MACRO_SEED, far.x, far.y, circ), shape, "a worldgen-14 bake (rivers only) keeps the world shape")
	Hydrology.use_bake(MACRO_SEED, bk, circ)
	var t := TerrainSlice.new()
	t._world_seed = MACRO_SEED
	assert_true(t.has_bake_macro(), "the slice reports the baked macro height")
	var baked := Bake.sample_height(bk, cell, far.x, far.y)
	assert_eq(TerrainSlice.macro_height(MACRO_SEED, far.x, far.y, circ), baked, "with the bake the macro height is the bake's")
	var differs := 0
	for k in 32:
		var x := float(k) * circ / 32.0 + 911.0
		var z := float(k - 16) * 9000.0
		if absf(TerrainSlice.macro_height(MACRO_SEED, x, z, circ) - WorldShape.height(MACRO_SEED, x, z, circ)) > 0.5:
			differs += 1
	assert_true(differs >= 4, "the baked macro height is not the noise shape (%d of 32 points differ)" % differs)
	var spawn := WorldShape.SPAWN_CENTER
	assert_eq(TerrainSlice.macro_height(MACRO_SEED, spawn.x, spawn.y, circ), WorldShape.spawn_plain_height(MACRO_SEED, circ), "the spawn plain stays flat on a baked world")
	# The 32 m lattice reads the bake: a corner of the generator's cell is the bake's macro height.
	var corner := Vector2i(floori(far.x / 32.0), floori(far.y / 32.0))
	var cache := TerrainSlice.new_corner_cache()
	var got := TerrainSlice.shape_cached(MACRO_SEED, float(corner.x) * 32.0, float(corner.y) * 32.0, circ, cache)
	assert_true(absf(got - Bake.sample_height(bk, cell, float(corner.x) * 32.0, float(corner.y) * 32.0)) < 1e-9, "the generator's corner lattice reads the bake")
	assert_eq(TerrainSlice.generated_corner_height(corner, MACRO_SEED), clampf(TerrainSlice.macro_height(MACRO_SEED, float(corner.x) * 32.0, float(corner.y) * 32.0, circ), WorldShape.min_height(), WorldShape.max_height()), "a generation record stores the baked corners")
	# The player-facing height (macro + detail, carved) over a dry tile is the bake's plus the detail noise.
	var noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(noise, MACRO_SEED)
	t._noise = noise
	var plain := clampf(got + TerrainSlice.detail_of(noise, float(corner.x) * 32.0, float(corner.y) * 32.0), WorldShape.min_height(), WorldShape.max_height())
	var expect := Hydrology.carved_height(MACRO_SEED, float(corner.x) * 32.0, float(corner.y) * 32.0, TerrainSlice.polar_ground(MACRO_SEED, plain, float(corner.x) * 32.0, float(corner.y) * 32.0, circ))
	assert_true(absf(t.get_height_at(Vector2(float(corner.x) * 32.0, float(corner.y) * 32.0)) - expect) < 1e-6, "get_height_at reads the baked macro height plus the detail noise")
	# Native and GDScript heightmaps agree on the baked macro height (the native builder gets the bake's corners).
	var cases: Array = []
	for pos in [corner, Vector2i(0, 0), Vector2i(roundi(circ / 32.0 * 0.5) - 1, 40), Vector2i(-roundi(circ / 32.0 * 0.5), -300), Vector2i(1234, 5678)]:
		cases.append([pos, MACRO_SEED, noise])
	assert_native_parity("NativeChunkBuilder", "heightmap_for", cases, TerrainSlice.heightmap_for_gd, TerrainSlice.heightmap_for, "heightmap_for on the baked macro height")
	var strips: Array = []
	for side in [Vector2i(-1, 0), Vector2i(1, 1), Vector2i(0, -1)]:
		strips.append([corner, side, MACRO_SEED, noise, 2])
	assert_native_parity("NativeChunkBuilder", "heightmap_strip_for", strips, TerrainSlice.heightmap_strip_for_gd, TerrainSlice.heightmap_strip_for, "heightmap_strip_for on the baked macro height")
	Hydrology.clear_bake(MACRO_SEED)
	assert_eq(TerrainSlice.macro_height(MACRO_SEED, far.x, far.y, circ), shape, "released: the world shape again")
	t.free()

## Acceptance (Phase 302): along 50 baked river segments of a planet baked from the world shape, the runtime
## ground (baked macro height + detail noise, carved) at the centreline lies below the water, and no step between
## adjacent tiles across the bank exceeds 0.5 m where the natural ground had none.
func _test_bake_runtime_carve() -> void:
	var circ := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	var w := 200
	var bk := Bake.bake_planet(MACRO_SEED, w, w / 2, circ, 12)
	var cell := circ / float(w)
	Hydrology.use_bake(MACRO_SEED, bk, circ)
	var noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(noise, MACRO_SEED)
	var half_h := cell * float(w / 2) * 0.5
	var all: Array = Hydrology.baked_segs(bk, cell, 0.0, -half_h, circ, half_h)
	assert_true(all.size() >= 50, "the planet has at least 50 baked river segments (%d)" % all.size())
	var stride := maxi(1, all.size() / 50)
	var cache := TerrainSlice.new_corner_cache()
	var row := TerrainSlice.new_polar_row()
	var checked := 0
	var centre_ok := true
	var worst_centre := -INF
	var bank_ok := true
	var worst_bank := 0.0
	var bank_pairs := 0
	var worst_natural := 0.0
	var hm_ok := true
	for n in 50:
		var sg: Array = all[mini(n * stride, all.size() - 1)]
		var mid := Vector2((float(sg[0]) + float(sg[2])) * 0.5, (float(sg[1]) + float(sg[3])) * 0.5)
		mid = Vector2(snappedf(mid.x, TerrainSlice.TILE_SIZE), snappedf(mid.y, TerrainSlice.TILE_SIZE))
		var water := Hydrology.surface_at(MACRO_SEED, mid.x, mid.y)
		var ground := Hydrology.carved_height(MACRO_SEED, mid.x, mid.y, TerrainSlice.height_wrapped_in(MACRO_SEED, noise, mid.x, mid.y, circ, cache, row))
		if is_nan(water):
			centre_ok = false
			continue
		worst_centre = maxf(worst_centre, ground - water)
		centre_ok = centre_ok and ground < water
		checked += 1
		# Walk the tile row across the river (the axis nearer perpendicular to it), 50 tiles each side.
		var along := Vector2(float(sg[2]) - float(sg[0]), float(sg[3]) - float(sg[1]))
		var step := Vector2(TerrainSlice.TILE_SIZE, 0.0) if absf(along.x) < absf(along.y) else Vector2(0.0, TerrainSlice.TILE_SIZE)
		var prev_u := 0.0
		var prev_c := 0.0
		for k in range(-50, 51):
			var p := mid + step * float(k)
			var u := TerrainSlice.height_wrapped_in(MACRO_SEED, noise, p.x, p.y, circ, cache, row)
			var c := Hydrology.carved_height(MACRO_SEED, p.x, p.y, u)
			if k > -50 and (c != u or prev_c != prev_u):
				# The raw step between the two carved tiles, whatever the natural ground did (1 mm for the carve's rounding).
				var s := absf(c - prev_c)
				worst_bank = maxf(worst_bank, s)
				worst_natural = maxf(worst_natural, absf(u - prev_u))
				bank_ok = bank_ok and s <= 0.501
				bank_pairs += 1
			prev_u = u
			prev_c = c
		# The chunk heightmap carves the same ground as the point query.
		if n < 6:
			var chunk := Vector2i(floori(mid.x / TerrainSlice.CHUNK_METERS), floori(mid.y / TerrainSlice.CHUNK_METERS))
			var hm := TerrainSlice.heightmap_for(chunk, MACRO_SEED, noise)
			var tx := roundi((mid.x - float(chunk.x) * TerrainSlice.CHUNK_METERS) / TerrainSlice.TILE_SIZE)
			var tz := roundi((mid.y - float(chunk.y) * TerrainSlice.CHUNK_METERS) / TerrainSlice.TILE_SIZE)
			hm_ok = hm_ok and absf(float(hm[tz * TerrainSlice.CHUNK_SIZE + tx]) - ground) < 1e-6
	Hydrology.clear_bake(MACRO_SEED)
	assert_eq(checked, 50, "50 baked river segments hold water at their midpoint")
	assert_true(centre_ok, "the ground at each centreline lies below the water (worst %.3f m)" % worst_centre)
	assert_true(bank_pairs > 500 and bank_ok, "no bank step between adjacent tiles over 0.5 m (%d carved pairs, worst %.3f m; the uncarved ground there stepped up to %.3f m)" % [bank_pairs, worst_bank, worst_natural])
	assert_true(hm_ok, "the chunk heightmap carves the same ground as the point query")


## Golden hashes of the Phase 245 bake (worldgen 14), recorded by running origin/main's `planet_bake.gd` (before
## Phase 302) on the same inputs: the `_grid()` fixture through `bake_gd`, and a 64 x 32 planet of seed 302245 on
## the fabric planet. A world recorded at worldgen 14 must keep getting these bytes (the stable-world rule).
const BAKE_245_GRID_HASH := "02f476d4f2e4be725cd44c5aa644d5ebdeb633d7815dac95b7120137e65d0deb"
const BAKE_245_PLANET_HASH := "5d02e3a30f858524e6be0b7af38fd2afb205ec01370cd04185a70cf351baeeb6"

func _test_bake_profiles() -> void:
	assert_eq(Bake.BAKE_VERSION, TerrainSlice.WORLDGEN_VERSION, "the newest bake version is the worldgen version")
	assert_eq(Bake.BAKE_VERSION_245, TerrainSlice.BAKE_WORLDGEN_VERSION, "the Phase 245 bake version is the first baked worldgen")
	var old := Bake.bake_gd(_grid(), W, H, SEA, 12, Callable(), Bake.BAKE_VERSION_245)
	assert_eq(Bake.hash_hex(Bake.to_bytes(old)), BAKE_245_GRID_HASH, "the worldgen-14 profile bakes the Phase 245 bytes (GDScript)")
	assert_true(Bake.hash_hex(Bake.to_bytes(Bake.bake_gd(_grid(), W, H, SEA, 12))) != BAKE_245_GRID_HASH, "the newest profile bakes other bytes")
	if NativeLoaderScript.use_native("NativeBake", "bake"):
		assert_eq(Bake.hash_hex(Bake.to_bytes(Bake.bake(_grid(), W, H, SEA, 12, Callable(), Bake.BAKE_VERSION_245))), BAKE_245_GRID_HASH, "and natively")
		assert_true(Bake.to_bytes(Bake.bake(_grid(), W, H, SEA, 12)) == Bake.to_bytes(Bake.bake_gd(_grid(), W, H, SEA, 12)), "the newest profile: native equals GDScript")
	var circ := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	var planet := Bake.bake_planet(302245, 64, 32, circ, 12, Callable(), Bake.BAKE_VERSION_245)
	assert_true(not planet.has("biome"), "a Phase 245 bake has no biome byte")
	assert_eq(Bake.hash_hex(Bake.to_bytes(planet)), BAKE_245_PLANET_HASH, "a worldgen-14 planet bakes the Phase 245 bytes")
	assert_true(Bake.bake_planet(302245, 64, 32, circ, 12).has("biome"), "a newest-profile planet carries the biome byte")
	# The plan picks the file and the profile from the world's version; the boot's job and the slice read the same plan.
	assert_eq(BakeJob.bake_version_for(14), 14, "a world recorded at 14 bakes profile 14")
	assert_eq(BakeJob.bake_version_for(15), Bake.BAKE_VERSION, "a world recorded at 15 bakes the newest")
	assert_eq(BakeJob.bake_version_for(-1), Bake.BAKE_VERSION, "a new world bakes the newest")
	var p14 := BakeJob.plan_for(7, 1000.0 * Bake.CELL_M, 14)
	var p15 := BakeJob.plan_for(7, 1000.0 * Bake.CELL_M, 15)
	assert_true(str(p14.path).contains("_v14_") and int(p14.version) == 14, "the worldgen-14 plan names its own file")
	assert_true(str(p15.path).contains("_v15_") and int(p15.version) == 15, "the worldgen-15 plan names the newest file")
	# ensure() bakes the plan's profile.
	var path := "user://test_bake_profile_v14.bin"
	var r := Bake.ensure(path, 302245, 64, 32, circ, 12, "", Callable(), Bake.BAKE_VERSION_245)
	assert_eq(str(r.hash), BAKE_245_PLANET_HASH, "ensure bakes and saves the worldgen-14 profile")
	assert_eq(str(Bake.ensure(path, 302245, 64, 32, circ, 12, "", Callable(), Bake.BAKE_VERSION_245).hash), BAKE_245_PLANET_HASH, "and reads it back")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".sha256")
