extends "res://src/tests/test_support.gd"
## Phase 164 — a round horizon: the planet's curvature (`horizon.gd`), the circular distant ring,
## the camera's far plane, the curvature shader, the sky and the haze.

const Horizon := preload("res://src/terrain/horizon.gd")
const WeatherWiring := preload("res://src/world/weather_wiring.gd")
const PlaytestBot := preload("res://src/tests/playtest_bot.gd")

## The fixture ring of the Phase 77 hash test: seed 7, a radius-3 window centred on (16, 16).
const FIXTURE_SQUARE_VERTS := 19908   ## the square ring's vertex count before this phase
const VERTEX_BUDGET := FIXTURE_SQUARE_VERTS * 3 / 2

func register() -> void:
	_run_test("horizon: curvature drop and horizon distance match the closed forms", _test_horizon_closed_forms)
	_run_test("horizon: the ring's outer silhouette is a circle",                     _test_horizon_ring_is_round)
	_run_test("horizon: the outer radius and the camera's far reach the horizon",     _test_horizon_outer_radius_and_far)
	_run_test("horizon: the camera can look out at the horizon and stays above the ground", _test_horizon_camera_can_look_level)
	_run_test("horizon: the polar ring keeps the window hole, no collision, in budget", _test_horizon_ring_hole_and_budget)
	_run_test("horizon: the ring shader's drop is horizon.gd's",                       _test_horizon_ring_shader)
	_run_test("horizon: the sky's horizon is the haze at noon, dusk and night",        _test_horizon_sky_matches_haze)
	_run_test("horizon: the playtest skyline reader finds a flat and a bumped skyline", _test_horizon_skyline_reader)

func _fixture_mesh() -> Dictionary:
	var w := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	var half := 3.5 * 32.0
	var wc := Vector2(16.0, 16.0)
	var ring_half := DistantTerrainScript.ring_half_extent(3)
	var cell := ring_half * 2.0 / float(DistantTerrainScript.GRID)
	var rc := Vector2(floorf(wc.x / cell) * cell, floorf(wc.y / cell) * cell)
	var mesh: ArrayMesh = DistantTerrainScript.build_mesh(7, w, rc, ring_half, half, wc)
	return { "mesh": mesh, "w": w, "half": half, "wc": wc, "ring_half": ring_half, "rc": rc }

func _test_horizon_closed_forms() -> void:
	var c := Horizon.default_circumference()
	assert_eq(c, 40000.0 * 1000.0, "the default circumference is the fabric's 40,000 km")
	var r := c / TAU
	assert_true(absf(Horizon.planet_radius() - r) < 1e-3, "R = C / 2π")
	assert_true(absf(r - 6366197.7) < 1.0, "about 6,366 km (%.1f)" % r)
	for d: float in [1000.0, 10000.0, 100000.0]:
		var expect := d * d / (2.0 * r)
		assert_true(absf(Horizon.curvature_drop(d) - expect) < 1e-6 * maxf(expect, 1.0), "drop at %.0f m is d²/2R (%.4f m)" % [d, expect])
	assert_true(absf(Horizon.curvature_drop(1000.0) - 0.0785) < 0.001, "about 8 cm at 1 km")
	assert_true(absf(Horizon.curvature_drop(100000.0) - 785.4) < 0.5, "about 785 m at 100 km")
	for h: float in [1.7, 10.0, 500.0]:
		var expect := sqrt(2.0 * r * h + h * h)
		assert_true(absf(Horizon.horizon_distance(h) - expect) < 1e-3, "horizon at %.1f m is √(2Rh + h²) (%.0f m)" % [h, expect])
	assert_true(absf(Horizon.horizon_distance(1.7) - 4652.0) < 5.0, "about 4.65 km for a 1.7 m eye")
	assert_eq(Horizon.horizon_distance(0.0), 0.0, "no horizon distance at the ground")
	# The boundary sits where the two horizon distances sum.
	var edge := Horizon.horizon_distance(1.7) + Horizon.horizon_distance(500.0)
	assert_true(Horizon.visible_over_horizon(1.7, 500.0, edge - 1.0), "a 500 m peak just inside the summed distance is in view")
	assert_false(Horizon.visible_over_horizon(1.7, 500.0, edge + 1.0), "and just past it is hidden")
	assert_true(absf(edge - 84500.0) < 500.0, "a 500 m peak clears the horizon from about 84 km (%.0f)" % edge)
	# Another circumference scales R.
	assert_true(absf(Horizon.planet_radius(TAU * 1000.0) - 1000.0) < 1e-6, "a 2π km world has R = 1 km")

func _test_horizon_ring_is_round() -> void:
	var f := _fixture_mesh()
	var verts: PackedVector3Array = (f["mesh"] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var rc: Vector2 = f["rc"]
	var outer := DistantTerrainScript.outer_radius_for(f["ring_half"], f["w"])
	var q := pow(outer / DistantTerrainScript.first_polar_radius(f["ring_half"]), 1.0 / float(DistantTerrainScript.POLAR_RINGS - 1))
	var outer_cell := outer * (1.0 - 1.0 / q)
	assert_true(outer_cell > 0.0 and outer_cell < outer * 0.2, "the outer cell is a sane fraction of the radius (%.0f m)" % outer_cell)
	const BINS := 128
	var far: Array = []
	far.resize(BINS)
	far.fill(0.0)
	var beyond := 0
	for v in verts:
		var d := Vector2(v.x, v.z) - rc
		var dist := d.length()
		if dist > outer + 0.01:
			beyond += 1
		var b := clampi(int(floor((d.angle() + PI) / TAU * float(BINS))), 0, BINS - 1)
		far[b] = maxf(float(far[b]), dist)
	assert_eq(beyond, 0, "no vertex lies beyond the outer radius")
	var worst := 0.0
	for b in BINS:
		worst = maxf(worst, outer - float(far[b]))
	assert_true(worst <= outer_cell, "every direction reaches within one outer cell of the radius (worst gap %.1f m, cell %.1f m)" % [worst, outer_cell])
	# The old square's corners reached √2 × as far as its sides; now a corner direction and a side
	# direction end at the same radius.
	var corner_b := clampi(int(floor((PI / 4.0 + PI) / TAU * float(BINS))), 0, BINS - 1)
	var side_b := clampi(int(floor((0.0 + PI) / TAU * float(BINS))), 0, BINS - 1)
	assert_true(absf(float(far[corner_b]) - float(far[side_b])) < 1.0, "a corner direction ends where a side direction does")
	assert_true(outer > DistantTerrainScript.first_polar_radius(f["ring_half"]), "the circle lies outside the square's corners")

func _test_horizon_outer_radius_and_far() -> void:
	var eye_default := PlayerSlice.camera_eye_height(PlayerSlice.CAMERA_DISTANCE, PlayerSlice.CAMERA_PITCH)
	var eye_max := PlayerSlice.camera_eye_height(PlayerSlice.CAMERA_DISTANCE_MAX, PlayerSlice.CAMERA_PITCH_MIN)
	assert_true(eye_max > eye_default and eye_default > PlayerSlice.CAMERA_PIVOT_HEIGHT, "zooming out raises the eye (%.1f → %.1f m)" % [eye_default, eye_max])
	assert_true(DistantTerrainScript.EYE_HEIGHT_MAX >= eye_max, "the ring's eye height covers the widest zoom (%.1f m)" % eye_max)
	for radius: int in [3, 4, 6]:
		var outer := DistantTerrainScript.outer_radius_for(DistantTerrainScript.ring_half_extent(radius))
		for eye: float in [eye_default, eye_max]:
			assert_true(outer >= Horizon.horizon_distance(eye), "radius %d: the outer circle (%.0f m) reaches the horizon of a %.1f m eye (%.0f m)" % [radius, outer, eye, Horizon.horizon_distance(eye)])
		assert_true(PlayerSlice.view_far_for(outer) >= outer, "radius %d: the far plane reaches the outer circle" % radius)
	# A built ring sets `outer_radius_m`, and the camera follows it.
	var d := DistantTerrainScript.new()
	d.rebuild(Vector2(16.0, 16.0), 4)
	d.poll(true)
	assert_eq(d.outer_radius_m, DistantTerrainScript.outer_radius_for(d.ring_half_m, d.circumference_m), "rebuild records the outer radius")
	var p := PlayerSlice.new()
	add_child(p)
	assert_true(p.view_far() >= d.outer_radius_m, "a fresh camera's far (%.0f m) already reaches the default ring (%.0f m)" % [p.view_far(), d.outer_radius_m])
	assert_true(p.view_far() > 4000.0, "past Godot's 4 km default")
	p.set_view_far(d.outer_radius_m * 2.0)
	assert_true(p.view_far() >= d.outer_radius_m * 2.0, "set_view_far follows a wider ring")
	p.free()
	d.free()

func _test_horizon_ring_hole_and_budget() -> void:
	var f := _fixture_mesh()
	var verts: PackedVector3Array = (f["mesh"] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var wc: Vector2 = f["wc"]
	var half: float = f["half"]
	var inside := 0
	for v in verts:
		if absf(v.x - wc.x) < half - 0.001 and absf(v.z - wc.y) < half - 0.001:
			inside += 1
	assert_eq(inside, 0, "no polar-ring vertex lies inside the voxel window")
	assert_true(verts.size() <= VERTEX_BUDGET, "the ring has %d vertices (budget %d)" % [verts.size(), VERTEX_BUDGET])
	var normals: PackedVector3Array = (f["mesh"] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = (f["mesh"] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	assert_eq(normals.size(), verts.size(), "every vertex has a normal")
	assert_eq(colors.size(), verts.size(), "and a colour")
	var down := 0
	for n in normals:
		if n.y < -0.001:
			down += 1
	assert_eq(down, 0, "no normal faces down (the skirt's face sideways)")
	var idx: PackedInt32Array = (f["mesh"] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	var bad := 0
	for i in idx:
		if i < 0 or i >= verts.size():
			bad += 1
	assert_eq(bad, 0, "every index names a vertex")
	# Ring 0 is the square's boundary row: the polar part's first vertices sit on the square's edge.
	var ring_half: float = f["ring_half"]
	var rc: Vector2 = f["rc"]
	var first := verts.size() - (DistantTerrainScript.POLAR_RINGS + 1) * 4 * DistantTerrainScript.GRID
	var off_edge := 0
	for k in 4 * DistantTerrainScript.GRID:
		var v := verts[first + k]
		var e := maxf(absf(v.x - rc.x), absf(v.z - rc.y))
		if absf(e - ring_half) > 0.01:
			off_edge += 1
	assert_eq(off_edge, 0, "the innermost polar ring is the square's boundary row")
	var d := DistantTerrainScript.new()
	add_child(d)
	d.rebuild(Vector2(16.0, 16.0), 3)
	d.poll(true)
	assert_eq(d.collision_body_count(), 0, "the polar ring carries no collision body")
	d.free()

func _test_horizon_ring_shader() -> void:
	var d := DistantTerrainScript.new()
	add_child(d)
	d.rebuild(Vector2(16.0, 16.0), 3)
	d.poll(true)
	var inst := d.get_child(0) as MeshInstance3D
	var mat := inst.material_override as ShaderMaterial
	assert_true(mat != null, "the ring is drawn with a shader material")
	assert_eq(mat.shader.code, Horizon.CURVATURE_SHADER, "running horizon.gd's curvature shader")
	assert_eq(float(mat.get_shader_parameter("planet_radius")), Horizon.planet_radius(d.circumference_m), "its radius is horizon.gd's planet radius")
	assert_true(mat.shader.code.contains("VERTEX.y -= dot(d, d) / (2.0 * planet_radius);"), "the vertex drop is d² / 2R of the horizontal distance to the camera")
	# The shader's formula, evaluated with its radius, is `curvature_drop`.
	var radius := float(mat.get_shader_parameter("planet_radius"))
	for dist: float in [112.0, 1000.0, 20000.0]:
		var dv := Vector2(dist * 0.6, dist * 0.8)
		assert_true(absf(dv.dot(dv) / (2.0 * radius) - Horizon.curvature_drop(dist, d.circumference_m)) < 1e-6, "drop at %.0f m equals curvature_drop" % dist)
	assert_true(Horizon.curvature_drop(DistantTerrainScript.ring_half_extent(3) / 10.0) < 0.002, "at the voxel window's edge the drop is about a millimetre")
	d.free()

func _test_horizon_sky_matches_haze() -> void:
	var root_script: GDScript = load("res://src/core/game_root.gd")
	var root: Node = root_script.new()   # never enters the tree: no _ready, no boot
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	root.add_child(sun)
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = WeatherWiring.make_environment()
	root.add_child(we)
	var env := we.environment
	assert_eq(env.background_mode, Environment.BG_SKY, "the background is a sky, not a flat colour")
	assert_true(env.sky != null and env.sky.sky_material is ProceduralSkyMaterial, "a procedural sky")
	assert_true(env.fog_enabled and env.fog_density > 0.0, "clear weather still has a haze")
	assert_true(env.fog_aerial_perspective > 0.0, "with aerial perspective")
	assert_eq(env.fog_sky_affect, 0.0, "clear haze leaves the sky alone")
	# Exponential fog: about 95% at the default ring's outer circle.
	var outer := DistantTerrainScript.outer_radius_for(DistantTerrainScript.ring_half_extent(4))
	assert_true(1.0 - exp(-env.fog_density * outer) > 0.9, "the far ring fades into the haze")
	var mat := env.sky.sky_material as ProceduralSkyMaterial
	var lat := 0.0
	var seen: Array = []
	for phase in [0.5, 0.25, 0.0]:   # solar noon, dawn/dusk, midnight
		root._clock.time_days = float(phase)
		root._weather_wiring.apply_sun(lat, 1.0)
		assert_eq(mat.sky_horizon_color, env.fog_light_color, "phase %s: the sky's horizon is the fog colour" % phase)
		assert_eq(mat.ground_horizon_color, env.fog_light_color, "phase %s: so is the ground horizon" % phase)
		assert_eq(mat.ground_bottom_color, env.fog_light_color, "phase %s: and the ground below it" % phase)
		assert_eq(WeatherWiring.sky_horizon_color(env), env.fog_light_color, "phase %s: sky_horizon_color reads it" % phase)
		seen.append(env.fog_light_color)
	assert_true(seen[0] != seen[2], "noon and midnight haze differ")
	assert_true((seen[0] as Color).get_luminance() > (seen[2] as Color).get_luminance(), "noon haze is brighter than night's")
	# Weather thickens the fog on top of the haze and never changes its colour.
	var before := env.fog_light_color
	WeatherWiring.apply_weather_fog(env, 0.3, 0.03)
	assert_true(absf(env.fog_density - (WeatherWiring.HAZE_DENSITY + 0.7 * 0.03)) < 1e-9, "weather adds its share to the haze base")
	assert_true(env.fog_sky_affect > 0.0, "thick weather fogs the sky too")
	assert_eq(env.fog_light_color, before, "the fog colour stays the sky's")
	assert_eq(mat.sky_horizon_color, env.fog_light_color, "and still matches the horizon")
	WeatherWiring.apply_weather_fog(env, 1.0, 0.03)
	assert_true(absf(env.fog_density - WeatherWiring.HAZE_DENSITY) < 1e-9, "clear weather returns to the base haze")
	root.free()

func _test_horizon_skyline_reader() -> void:
	var key := PlaytestBot.SKYLINE_KEY
	var img := Image.create(64, 40, false, Image.FORMAT_RGBA8)
	img.fill(key)
	for x in 64:
		for y in range(20, 40):
			img.set_pixel(x, y, Color(0.2, 0.3, 0.5))
	var rows: Array = PlaytestBot.skyline_rows(img, key)
	assert_eq(rows.size(), 64, "one skyline row per column")
	assert_eq(rows[0], 20, "the first non-sky row")
	assert_eq(PlaytestBot.skyline_spread(rows), 0, "a level skyline has no spread")
	# A bump (the old square's corner) shows as spread.
	for y in range(14, 20):
		img.set_pixel(40, y, Color(0.5, 0.48, 0.45))
	rows = PlaytestBot.skyline_rows(img, key)
	assert_eq(PlaytestBot.skyline_spread(rows), 6, "a 6 px peak spreads the skyline by 6 px")
	# A column with no ground at all (sky to the bottom) counts as the frame's height.
	var empty := Image.create(4, 10, false, Image.FORMAT_RGBA8)
	empty.fill(key)
	assert_eq(PlaytestBot.skyline_rows(empty, key), [10, 10, 10, 10], "an all-sky column reads as the frame height")


func _test_horizon_camera_can_look_level() -> void:
	assert_true(PlayerSlice.CAMERA_PITCH_MAX >= 0.0, "the pitch reaches level, so the horizon can sit mid-screen")
	var half_fov := PlayerSlice.CAMERA_FOV * 0.5
	assert_true(-PlayerSlice.CAMERA_PITCH < half_fov, "at the default pitch the horizon is inside the frame (%.0f° down, %.0f° half view)" % [-PlayerSlice.CAMERA_PITCH, half_fov])
	assert_eq(PlayerSlice.camera_arm_length(12.0, -1.0), 12.0, "a clear arm keeps the zoom distance")
	assert_eq(PlayerSlice.camera_arm_length(12.0, 20.0), 12.0, "terrain past the camera does not pull it in")
	assert_eq(PlayerSlice.camera_arm_length(12.0, 5.0), 5.0 - PlayerSlice.CAMERA_GROUND_CLEARANCE, "terrain in the way pulls it short of the hit")
	assert_eq(PlayerSlice.camera_arm_length(12.0, 0.2), 0.1, "never onto the pivot")
