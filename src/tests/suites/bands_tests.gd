extends "res://src/tests/test_support.gd"
## Phase 165 — mountains on the horizon: the distant bands outside the ring (`distant_bands.gd`).

const Horizon := preload("res://src/terrain/horizon.gd")
const Bands := preload("res://src/terrain/distant_bands.gd")

const SEED := 7
const PEAK_H := 500.0
const PEAK_SIGMA := 4000.0

func register() -> void:
	_run_test("bands: the outer radius is the closed form and follows maxHeight",   _test_bands_outer_radius)
	_run_test("bands: a single 500 m peak keeps its height in every band",          _test_bands_peak_kept)
	_run_test("bands: a near-band cell rebuilds only the near band, off the main thread", _test_bands_rebuild_rules)
	_run_test("bands: they wrap at the antimeridian; adjacent bands share their edge", _test_bands_wrap_and_seams)
	_run_test("bands: the playtest far_peak reader counts rock and snow above the ring", _test_bands_far_peak_reader)
	_run_test("bands: no collision body, vertices within budget, far plane reaches them", _test_bands_budget_and_far)

func _ring_radius() -> float:
	return DistantTerrainScript.outer_radius_for(DistantTerrainScript.ring_half_extent(PlayerSlice.DEFAULT_RING_RADIUS))

func _test_bands_outer_radius() -> void:
	var eye := Bands.EYE_HEIGHT
	var expect := Horizon.horizon_distance(eye) + Horizon.horizon_distance(WorldShape.max_height())
	assert_eq(Bands.outer_radius(), expect, "outer radius is the eye's horizon plus the tallest terrain's")
	var r := Horizon.planet_radius()
	var closed := sqrt(2.0 * r * eye + eye * eye) + sqrt(2.0 * r * WorldShape.max_height() + pow(WorldShape.max_height(), 2.0))
	assert_true(absf(Bands.outer_radius() - closed) < 1e-3, "and equals √(2Rh + h²) + √(2RH + H²) (%.0f m)" % closed)
	assert_true(absf(Bands.outer_radius() - 85000.0) < 1500.0, "about 85 km at the default 512 m (%.0f m)" % Bands.outer_radius())
	assert_true(Bands.outer_radius(-1.0, eye, WorldShape.max_height() * 2.0) > Bands.outer_radius() + 20000.0, "a taller maxHeight reaches farther")
	assert_true(Bands.outer_radius(-1.0, eye, WorldShape.max_height() / 2.0) < Bands.outer_radius() - 20000.0, "a lower one reaches less far")
	var specs := Bands.plan(_ring_radius(), Bands.outer_radius())
	var last: Dictionary = specs.back()
	assert_true(float(last["half"]) - float(last["cell"]) >= Bands.outer_radius(), "the outermost band's square clears the circle")
	for k in specs.size():
		assert_eq(float(specs[k]["cell"]), Bands.CELL_0 * pow(2.0, float(k)), "band %d's cell is a multiple of the one inside it" % k)
		if k > 0:
			assert_eq(float(specs[k]["hole_half"]), float(specs[k - 1]["half"]), "band %d's hole is band %d's outer edge" % [k, k - 1])
		var n := Bands.cells_per_side(specs[k])
		assert_eq(n % 4, 0, "band %d has a whole number of coarser cells per side" % k)

func _gauss(cx: float, cz: float) -> Callable:
	return func(x: float, z: float) -> float:
		var d2 := (x - cx) * (x - cx) + (z - cz) * (z - cz)
		return PEAK_H * exp(-d2 / (2.0 * PEAK_SIGMA * PEAK_SIGMA))

func _band_of(specs: Array, d: float) -> int:
	for k in specs.size():
		if d >= float(specs[k]["hole_half"]) + 2.0 * float(specs[k]["cell"]) and d < float(specs[k]["half"]) - 2.0 * float(specs[k]["cell"]):
			return k
	return -1

func _test_bands_peak_kept() -> void:
	var w := Horizon.default_circumference()
	var specs := Bands.plan(_ring_radius(), Bands.outer_radius())
	var eye := Bands.EYE_HEIGHT
	var d0 := Horizon.horizon_distance(eye)
	var r := Horizon.planet_radius()
	var sea := WorldShape.sea_level()
	for d: float in [20000.0, 50000.0, 80000.0, 90000.0]:
		var k := _band_of(specs, d)
		assert_true(k >= 0, "a band holds %.0f km" % (d / 1000.0))
		if k < 0:
			continue
		var cell: float = specs[k]["cell"]
		var px := d + 0.37 * cell   # off the lattice on purpose
		var mesh := Bands.build_band(SEED, w, specs[k], Vector2i.ZERO, k < specs.size() - 1, null, _gauss(px, 0.0))
		var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var top := verts[0]
		for v in verts:
			if v.y > top.y:
				top = v
		var peak_y := top.y + Bands.BAND_DROP
		assert_true(absf(peak_y - PEAK_H) <= 5.0, "%.0f km: the peak's vertex is %.1f m (within 5 m of %.0f)" % [d / 1000.0, peak_y, PEAK_H])
		var dist := Vector2(top.x, top.z).length()
		var visible := Horizon.visible_over_horizon(eye, PEAK_H, dist)
		var above_line := (peak_y - Horizon.curvature_drop(dist)) > (eye - dist * d0 / r)
		assert_eq(above_line, visible, "%.0f km: the dropped vertex is above the eye's line exactly when the peak clears the horizon" % (dist / 1000.0))
		assert_true(top.y >= sea - Bands.BAND_DROP, "the sea sheet is never under the peak")

func _wait_idle(b: Node) -> void:
	b.poll(true)

func _test_bands_rebuild_rules() -> void:
	var b := Bands.new()
	b.world_seed = SEED
	add_child(b)
	var ring := _ring_radius()
	b.update(Vector2(100.0, 100.0), ring)
	_wait_idle(b)
	var n: int = b.band_count()
	assert_true(n >= 3, "the default view has at least three bands (%d)" % n)
	var base: Array = []
	for k in n:
		base.append(b.band_builds_started(k))
		assert_eq(b.band_builds_completed(k), 1, "band %d built once" % k)
		assert_true(b.band_thread(k) != OS.get_main_thread_id() and b.band_thread(k) != -1, "band %d was built on a worker" % k)
	assert_false(b.update(Vector2(100.0, 100.0), ring), "the same spot asks for nothing")
	# One near-band cell: only the near band.
	assert_true(b.update(Vector2(100.0 + Bands.CELL_0, 100.0), ring), "moving a near-band cell rebuilds")
	_wait_idle(b)
	assert_eq(b.band_builds_started(0), base[0] + 1, "band 0 rebuilt")
	for k in range(1, n):
		assert_eq(b.band_builds_started(k), base[k], "band %d did not" % k)
	# A whole band-1 cell: bands 0 and 1, not the farthest.
	var cell1: float = b.band_spec(1)["cell"]
	assert_true(b.update(Vector2(cell1 + 10.0, 100.0), ring), "moving a whole band-1 cell rebuilds band 1 too")
	_wait_idle(b)
	assert_eq(b.band_builds_started(1), base[1] + 1, "band 1 rebuilt")
	assert_eq(b.band_builds_started(n - 1), base[n - 1], "the far band did not")
	assert_false(b.is_building(), "nothing is left building")
	assert_eq(b.collision_body_count(), 0, "no collision")
	b.free()

func _vertex_map(mesh: ArrayMesh) -> Dictionary:
	var m := {}
	for v: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		m[Vector2(v.x, v.z)] = v.y
	return m

func _test_bands_wrap_and_seams() -> void:
	var w := Horizon.default_circumference()
	var specs := Bands.plan(_ring_radius(), Bands.outer_radius())
	var cell: float = specs[0]["cell"]
	# Across the antimeridian: a vertex past the seam has the height of the one a lap behind it.
	var lap_cells := int(round(w / cell))
	var mismatched := 0
	for ix in [100, 977, -3000, 2000]:
		for iz in [0, -40, 211]:
			var a := Bands.cell_height(SEED, w, cell, ix, iz)
			var c := Bands.cell_height(SEED, w, cell, ix + lap_cells, iz)
			if absf(a - c) > 0.01:
				mismatched += 1
	assert_eq(mismatched, 0, "cell heights a lap apart agree")
	var seam_x := w * 0.5
	var origin := Vector2i(int(floor(seam_x / cell)) - 3, 100)
	var mesh := Bands.build_band(SEED, w, specs[0], origin, true)
	var sea := WorldShape.sea_level()
	var crossed := 0
	var bad := 0
	var arr: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in range(0, verts.size(), 7):
		var v := verts[i]
		if v.x > seam_x:
			crossed += 1
			var wrapped := Bands.cell_height(SEED, w, cell, roundi(v.x / cell) - lap_cells, roundi(v.z / cell))
			var own := Bands.cell_height(SEED, w, cell, roundi(v.x / cell), roundi(v.z / cell))
			if absf(wrapped - own) > 0.01:
				bad += 1
			if absf(v.y - Bands.band_y(own, sea)) > 60.0 and absf(v.y - Bands.band_y(wrapped, sea)) > 60.0:
				bad += 1   # (edge vertices take the next band's height, which can differ)
	assert_true(crossed > 0, "the band spans the seam")
	assert_eq(bad, 0, "vertices past the seam match the shape at the wrapped position")
	# A band over a pole stays finite.
	var pole_z := float(TerrainSlice.pole_chunks()) * TerrainSlice.CHUNK_METERS
	var pmesh := Bands.build_band(SEED, w, specs[0], Vector2i(0, int(pole_z / cell)), true)
	for v: Vector3 in pmesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		assert_true(is_finite(v.y), "a vertex over the pole is finite")
		if not is_finite(v.y):
			break
	# Adjacent bands share the edge: no crack beyond RING_DROP.
	for p: Vector2 in [Vector2(30000.0, -12000.0), Vector2(1234.0, 98765.0)]:
		for k in specs.size() - 1:
			var o_k := Bands.origin_for(specs[k], p)
			var o_n := Bands.origin_for(specs[k + 1], p)
			var inner := Bands.build_band(SEED, w, specs[k], o_k, true)
			var outer := Bands.build_band(SEED, w, specs[k + 1], o_n, k + 1 < specs.size() - 1)
			var om := _vertex_map(outer)
			var shared := 0
			var worst := 0.0
			for key: Vector2 in _vertex_map(inner):
				if om.has(key):
					shared += 1
					worst = maxf(worst, absf(float(om[key]) - float(_vertex_map(inner)[key])))
			assert_true(shared > 100, "bands %d/%d share %d edge vertices at %s" % [k, k + 1, shared, str(p)])
			assert_true(worst <= DistantTerrainScript.RING_DROP, "bands %d/%d agree on the edge (worst %.3f m)" % [k, k + 1, worst])
			# The midpoints between shared vertices lie on the coarse edge too: no T-junction crack.
			var cc: float = specs[k + 1]["cell"]
			var im := _vertex_map(inner)
			var cracks := 0
			for key: Vector2 in im:
				var ex := is_zero_approx(fposmod(key.x, cc))
				var ez := is_zero_approx(fposmod(key.y, cc))
				if ex == ez:
					continue
				var step := Vector2(0.0, specs[k]["cell"]) if ex else Vector2(specs[k]["cell"], 0.0)
				if om.has(key - step) and om.has(key + step):
					if absf(float(im[key]) - 0.5 * (float(om[key - step]) + float(om[key + step]))) > DistantTerrainScript.RING_DROP:
						cracks += 1
			assert_eq(cracks, 0, "bands %d/%d: edge midpoints follow the coarse edge" % [k, k + 1])

func _test_bands_far_peak_reader() -> void:
	var PB := preload("res://src/tests/playtest_bot.gd")
	assert_true("far_peak" in PB.step_names(), "the bot has a far_peak step")
	var key := PB.SKYLINE_KEY
	var img := Image.create(40, 30, false, Image.FORMAT_RGB8)
	img.fill(key)
	var ring_rows: Array = []
	ring_rows.resize(40)
	ring_rows.fill(20)   # the ring's skyline: first non-key row 20
	assert_eq(PB.rock_pixels_above(img, ring_rows, key), 0, "an empty (keyed) frame has none")
	for y in range(20, 30):   # land below the skyline: green, not counted anyway
		for x in 40:
			img.set_pixel(x, y, Color(0.36, 0.5, 0.28))
	assert_eq(PB.rock_pixels_above(img, ring_rows, key), 0, "land below the skyline is not counted")
	for x in range(10, 20):   # a snow cap 3 rows tall above it
		for y in range(17, 20):
			img.set_pixel(x, y, Color(0.9, 0.92, 0.95))
	assert_eq(PB.rock_pixels_above(img, ring_rows, key), 30, "snow above the skyline is counted")
	for x in range(25, 30):   # green above it (a nearer hill): not rock
		img.set_pixel(x, 18, Color(0.3, 0.5, 0.2))
	img.set_pixel(30, 18, Color(0.5, 0.48, 0.45))   # one rock pixel
	assert_eq(PB.rock_pixels_above(img, ring_rows, key), 31, "rock counts, green does not")
	assert_eq(PB.rock_pixels_above(img, ring_rows, key, 0.08, true), 36, "any_colour counts the green too")

func _test_bands_budget_and_far() -> void:
	var b := Bands.new()
	b.world_seed = SEED
	add_child(b)
	b.update(Vector2(16.0, 16.0), _ring_radius())
	b.poll(true)
	var total := 0
	for k in b.band_count():
		var spec: Dictionary = b.band_spec(k)
		var mi: MeshInstance3D = b.get_child(k)
		var mesh := mi.mesh as ArrayMesh
		var count := (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		assert_eq(count, Bands.band_vertex_count(spec), "band %d has the planned vertex count" % k)
		assert_eq(mi.layers & Bands.BANDS_RENDER_LAYER, Bands.BANDS_RENDER_LAYER, "band %d is on the bands layer" % k)
		total += count
	assert_true(total <= Bands.VERTEX_BUDGET, "%d vertices within the %d budget" % [total, Bands.VERTEX_BUDGET])
	assert_eq(b.vertex_total(), total, "vertex_total agrees")
	assert_eq(b.collision_body_count(), 0, "the bands carry no collision body")
	assert_true(b.outer_radius_m > 80000.0, "outer radius recorded (%.0f m)" % b.outer_radius_m)
	var ring := DistantTerrainScript.new()
	add_child(ring)
	var made: Node3D = ring.make_bands(self)
	ring.rebuild(Vector2(16.0, 16.0), PlayerSlice.DEFAULT_RING_RADIUS)
	ring.poll(true)
	made.poll(true)
	assert_true(made.band_count() >= 3 and made.band_builds_completed(0) == 1, "the ring keeps its bands centred")
	assert_true(ring.reach_m() >= made.outer_radius_m and made.outer_radius_m > ring.outer_radius_m, "the reach is the bands' outer radius (%.0f m)" % ring.reach_m())
	assert_eq(ring.get_child_count(), 1, "the ring's only child is its mesh")
	made.free()
	ring.free()
	var p := PlayerSlice.new()
	add_child(p)
	assert_true(p.view_far() >= b.outer_radius_m, "a fresh camera's far (%.0f m) reaches the outermost band" % p.view_far())
	p.free()
	b.free()
