extends "res://src/tests/test_support.gd"
## Phase 238 — one world: the fabric seed, a 2,000 km planet, one open continent, closed sites that are never
## recorded or edited, and a pre-238 record that keeps its own circumference.

const Spawn := preload("res://src/world/spawn_finder.gd")
const LocalWorlds := preload("res://src/menu/local_worlds.gd")

func register() -> void:
	_run_test("one world: two new worlds share the fabric seed and the heights", _test_same_seed, true)
	_run_test("one world: the planet is 2,000 km round", _test_circumference, true)
	_run_test("one world: ocean outside the open continent, land in its core", _test_continent_sample, true)
	_run_test("one world: a closed site is never recorded or edited; opened, only it changes", _test_closed_site, true)
	_run_test("one world: the horizon reads the 2,000 km planet", _test_horizon_small_planet, true)
	_run_test("one world: every spawn lies inside an open continent", _test_spawn_inside, true)
	_run_test("one world: a pre-238 record keeps 40,000 km and no mask", _test_legacy_record, true)

func _w() -> float:
	return float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS

func _test_same_seed() -> void:
	var base := "user://t238_" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(base)
	var a := LocalWorlds.create(base, "One", "", 0)
	var b := LocalWorlds.create(base, "Two", "", 0)
	assert_eq(int(a["seed"]), int(b["seed"]), "two new worlds take the same seed")
	assert_eq(int(a["seed"]), 238, "and it is the fabric's worldSeed")
	var w := _w()
	for i in 8:
		var x := float(i) * 90000.0 - 300000.0
		assert_eq(WorldShape.height(int(a["seed"]), x, 1000.0, w), WorldShape.height(int(b["seed"]), x, 1000.0, w), "the same heights")
	LocalWorlds.delete(base, str(a["id"]))
	LocalWorlds.delete(base, str(b["id"]))
	DirAccess.remove_absolute(base)

func _test_circumference() -> void:
	assert_eq(TerrainSlice.circumference_chunks(), 62500, "2,000 km / 32 m is 62,500 chunks")

func _test_continent_sample() -> void:
	var w := _w()
	var seed_v := LocalWorlds.fabric_seed()
	var land := 0
	var core := 0
	var bad := 0
	var n := 0
	for i in 60:
		for j in 30:
			var x := (float(i) / 60.0 - 0.5) * w
			var z := (float(j) / 30.0 - 0.5) * w * 0.5
			var in_any := false
			for c in WorldShape.continents():
				if bool(c[3]) and WorldShape.continent_distance_m(c, x, z, w) <= float(c[2]) * 1000.0:
					in_any = true
			if not in_any and WorldShape.altitude(seed_v, x, z, w) >= 0.0:
				bad += 1
			n += 1
	assert_eq(bad, 0, "every sample outside the open continents is below sea level (%d samples)" % n)
	for k in 400:
		var a := float(k) * 0.7853
		var r := 0.45 * 300000.0 * sqrt(float(k) / 400.0)
		var h := WorldShape.altitude(seed_v, cos(a) * r, sin(a) * r, w)
		core += 1
		if h > 0.0:
			land += 1
	assert_true(float(land) / float(core) > 0.7, "most of the core is land (%d of %d)" % [land, core])

func _test_closed_site() -> void:
	var w := _w()
	var east := Vector2(w * 0.5, 0.0)   # the closed "east" site, longitude 180
	assert_true(TerrainSlice.in_closed_site(east), "the east site is closed")
	assert_true(not TerrainSlice.in_closed_site(Vector2(0, 0)), "the open continent is not")
	assert_true(TerrainSlice.chunk_in_closed_site(Vector2i(int(w * 0.5 / TerrainSlice.CHUNK_METERS), 0)), "a chunk there is in the site")
	var saved: Array = WorldShape.continents().duplicate(true)
	var seed_v := LocalWorlds.fabric_seed()
	var probes := [Vector2(0, 0), Vector2(150000, 40000), Vector2(w * 0.5, 0), Vector2(w * 0.5 + 100000.0, 20000), Vector2(-w * 0.25, 90000)]
	var before: Array = []
	for p in probes:
		before.append(WorldShape.height(seed_v, p.x, p.y, w))
	var opened: Array = saved.duplicate(true)
	for c in opened:
		if not bool(c[3]) and absf(float(c[1]) - 180.0) < 0.1:
			c[3] = true
	WorldShape.set_continents(opened)
	var changed_inside := false
	for i in probes.size():
		var h := WorldShape.height(seed_v, probes[i].x, probes[i].y, w)
		var inside := WorldShape.continent_at(probes[i].x, probes[i].y, w, 0.0, false) == 1
		if inside:
			changed_inside = changed_inside or h != before[i]
		else:
			assert_eq(h, before[i], "ground outside the opened site is unchanged at probe %d" % i)
	assert_true(changed_inside, "opening the site changes its own ground")
	WorldShape.set_continents(saved)

func _test_spawn_inside() -> void:
	var seed_v := LocalWorlds.fabric_seed()
	var w := _w()
	var height_fn := func(p: Vector2) -> float: return WorldShape.height(seed_v, p.x, p.y, w)
	var found := 0
	for i in 6:
		var p: Variant = Spawn.find_new(seed_v, "player_%d" % i, null, height_fn)
		if p != null:
			found += 1
			assert_true(WorldShape.continent_at(p.x, p.z, w, 0.0, true) >= 0, "spawn %d is inside an open continent" % i)
	assert_true(found > 0, "the search finds land")

func _test_legacy_record() -> void:
	var ts := TerrainSlice
	ts.adopt_record_circumference({ "seed": 7 })
	assert_eq(ts.circumference_chunks(), 1250000, "a record without a circumference is 40,000 km")
	assert_true(not WorldShape.mask_enabled(), "and has no continent mask")
	var w := _w()
	assert_eq(WorldShape.continentalness(7, 0.0, 0.0, w), WorldShape.continentalness(7, 0.0, 0.0, w), "unmasked continentalness is deterministic")
	ts.adopt_record_circumference({ "seed": 7, "circumferenceKm": 2000.0, "continentMask": true })
	assert_eq(ts.circumference_chunks(), 62500, "a 238 record keeps 2,000 km")
	assert_true(WorldShape.mask_enabled(), "with the mask")
	ts.set_world_circumference(ts.fabric_circumference_km(), true)

func _test_horizon_small_planet() -> void:
	const Horizon := preload("res://src/terrain/horizon.gd")
	assert_eq(Horizon.default_circumference(), 2000.0 * 1000.0, "the default circumference is the fabric's 2,000 km")
