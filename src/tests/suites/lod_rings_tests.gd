extends "res://src/tests/test_support.gd"
## Phase 243 — the LOD rings past the window: an LOD chunk's heights against the full chunks', edits
## summarised to the cell, the ring boxes (nesting, even alignment, the neighbouring rule), skirts, the
## haze fitted to the outer radius, and the level-change cross-fade.

const LodRingPolicy := preload("res://src/terrain/lod_ring_policy.gd")
const VoxelLod := preload("res://src/terrain/voxel_lod.gd")
const LodFade := preload("res://src/terrain/lod_fade.gd")
const LodTerrain := preload("res://src/terrain/lod_terrain.gd")
const ChunkSurface := preload("res://src/terrain/chunk_surface.gd")
const WeatherWiring := preload("res://src/world/weather_wiring.gd")
const TerrainLodTests := preload("res://src/tests/suites/terrain_lod_tests.gd")

const SEED := 424242

func register() -> void:
	_run_test("lod rings: an LOD chunk's heights match the full chunks' within its cell", _test_lod_rings_heights)
	_run_test("lod rings: an edited tile's top shows in the LOD mesh", _test_lod_rings_edit_summary)
	_run_test("lod rings: boxes are even-aligned, square and keep the neighbouring rule", _test_lod_rings_boxes)
	_run_test("lod rings: rings nest with no overlap and no gap", _test_lod_rings_nest)
	_run_test("lod rings: a viewer pacing over a chunk border keeps the plan", _test_lod_rings_hysteresis)
	_run_test("lod rings: every LOD chunk skirts its border, render only", _test_lod_rings_skirt)
	_run_test("lod rings: clear haze reaches 90% at the outer LOD radius", _test_lod_rings_haze)
	_run_test("lod rings: a level change cross-fades, complementary, then frees the old surface", _test_lod_rings_fade)
	_run_test("lod rings: the node queues each ring's chunks and the distant hole is the outer box", _test_lod_rings_node)

## The full chunks' surface heights over the LOD chunk, at each tile middle: `{ Vector2i(tile x, z) local: h }`.
func _full_heights(level: int, lchunk: Vector2i) -> Dictionary:
	var noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(noise, SEED)
	var span := 1 << level
	var n := VoxelSlice.CHUNK_SIZE
	var out := {}
	for dz in span:
		for dx in span:
			var c := lchunk * span + Vector2i(dx, dz)
			var hm := TerrainSlice.heightmap_for(c, SEED, noise)
			for tz in n:
				for tx in n:
					out[Vector2i(dx * n + tx, dz * n + tz)] = VoxelSlice._voxel_height(float(hm[tz * n + tx]))
	return out

func _test_lod_rings_heights() -> void:
	ChunkRecordsScript.clear()
	for probe in [[1, Vector2i(1, 1)], [1, Vector2i(150, 3)], [2, Vector2i(-300, 20)]]:
		var level: int = probe[0]
		var lchunk: Vector2i = probe[1]
		var cell := LodRingPolicy.cell_meters(level)
		var built := VoxelLod.build_lod_arrays(level, lchunk, SEED)
		var full := _full_heights(level, lchunk)
		var tiles := int(LodRingPolicy.chunk_meters(level) / VoxelSlice.TILE_SIZE)
		var stride := maxi(tiles / 32, 1)
		var points := PackedVector2Array()
		var keys: Array = []
		for tz in range(0, tiles, stride):
			for tx in range(0, tiles, stride):
				points.append(Vector2((tx + 0.5) * VoxelSlice.TILE_SIZE, (tz + 0.5) * VoxelSlice.TILE_SIZE))
				keys.append(Vector2i(tx, tz))
		var got := TerrainLodTests._surface_at(built, points)
		var sum := 0.0
		var counted := 0
		var holes := 0
		for k in points.size():
			if is_nan(got[k]):
				holes += 1
				continue
			sum += absf(got[k] - float(full[keys[k]]))
			counted += 1
		assert_eq(holes, 0, "level %d chunk %s: the surface covers every point" % [level, lchunk])
		var mean := sum / maxf(float(counted), 1.0)
		assert_true(mean <= cell, "level %d chunk %s: mean height error %.2f m within the %.0f m cell" % [level, lchunk, mean, cell])

func _test_lod_rings_edit_summary() -> void:
	ChunkRecordsScript.clear()
	var level := 1
	var lchunk := Vector2i(1, 1)
	var plain := VoxelLod.build_lod_arrays(level, lchunk, SEED)
	var tile := lchunk * (1 << level) * VoxelSlice.CHUNK_SIZE + Vector2i(40, 70)   # a tile inside the LOD chunk
	var corner := VoxelLod.corner_m(level, lchunk)
	var at := Vector2((tile.x + 0.5) * VoxelSlice.TILE_SIZE, (tile.y + 0.5) * VoxelSlice.TILE_SIZE) - corner
	var ground := float(TerrainLodTests._surface_at(plain, PackedVector2Array([at]))[0])
	var top := ground + 30.0
	var edited := VoxelLod.build_lod_arrays(level, lchunk, SEED, {}, { tile: top })
	var raised := float(TerrainLodTests._surface_at(edited, PackedVector2Array([at]))[0])
	assert_true(raised > ground + 20.0, "the edited tower raises its cell (%.1f → %.1f, top %.1f)" % [ground, raised, top])
	var far := at + Vector2(LodRingPolicy.cell_meters(level) * 4.0, 0.0)
	assert_true(absf(float(TerrainLodTests._surface_at(edited, PackedVector2Array([far]))[0])
		- float(TerrainLodTests._surface_at(plain, PackedVector2Array([far]))[0])) < 0.01, "a cell four over is untouched")

func _windows() -> Array:
	var out: Array = []
	for v in [Vector2(10.0, 10.0), Vector2(-1000.3, 517.9), Vector2(33333.0, -4444.4), Vector2(95.0, -31.0)]:
		var pc := Vector2i(floori(v.x / 32.0), floori(v.y / 32.0))
		var r := LodRingPolicy.WINDOW_RADIUS
		out.append([v, Rect2i(pc - Vector2i(r, r), Vector2i(2 * r + 1, 2 * r + 1))])
	return out

func _test_lod_rings_boxes() -> void:
	for pair in _windows():
		var b := LodRingPolicy.boxes(pair[0], pair[1], 5)
		assert_eq(b.size(), 6, "one box per level, the window's first")
		for k in range(1, b.size()):
			var box: Rect2i = b[k]
			assert_true(posmod(box.position.x, 2) == 0 and posmod(box.position.y, 2) == 0
				and posmod(box.end.x, 2) == 0 and posmod(box.end.y, 2) == 0, "level %d box is even-aligned" % k)
			assert_eq(box.size.x, box.size.y, "level %d box is square" % k)
			assert_true(box.encloses(LodRingPolicy.minimal_parent_box(b[k - 1])), "level %d keeps one chunk round level %d" % [k, k - 1])
			var viewer := LodRingPolicy.level_chunk(pair[0], k)
			var d := LodRingPolicy.distance(k, LodRingPolicy.WINDOW_RADIUS)
			assert_true(box.encloses(Rect2i(viewer - Vector2i(d, d), Vector2i(2 * d + 1, 2 * d + 1))), "level %d reaches its distance" % k)
		assert_true(Rect2i(b[1].position * 2, b[1].size * 2).encloses(pair[1]), "ring 1 holds the window")

## Every 4 m point of the outer box lies in exactly one of: the window, or one ring chunk (minus ring 1's
## cut over the window).
func _test_lod_rings_nest() -> void:
	var rings := 3
	for pair in _windows():
		var window: Rect2i = pair[1]
		var b := LodRingPolicy.boxes(pair[0], window, rings)
		var drawn: Array = []   # [level, Rect2 metres]
		for k in range(1, rings + 1):
			var m := LodRingPolicy.chunk_meters(k)
			for c in LodRingPolicy.ring_chunks(b, k, window):
				drawn.append([k, Rect2(Vector2(c) * m, Vector2(m, m))])
		var win_m := LodRingPolicy.box_rect_m(window, 0)
		var outer := LodRingPolicy.box_rect_m(b[rings], rings)
		var bad := 0
		var step := 16.0
		var x := outer.position.x + 2.0
		while x < outer.end.x:
			var z := outer.position.y + 2.0
			while z < outer.end.y:
				var p := Vector2(x, z)
				var covers := 1 if win_m.has_point(p) else 0
				for d in drawn:
					var r: Rect2 = d[1]
					if r.has_point(p) and not (int(d[0]) == 1 and win_m.has_point(p)):
						covers += 1
				if covers != 1:
					bad += 1
				z += step
			x += step
		assert_eq(bad, 0, "viewer %s: every point drawn exactly once" % pair[0])
		var counts: Array = []
		for k in range(1, rings + 1):
			counts.append(LodRingPolicy.ring_chunks(b, k, window).size())
		# Ring 1 draws its whole box (the window is cut by the shader), so it holds the most; past it the
		# count stays about flat as the cell doubles.
		var outer_counts := counts.slice(1)
		assert_true(outer_counts.max() <= 2 * outer_counts.min(), "the chunks per ring stay about flat: %s" % [counts])
		assert_true(counts[0] <= 16 * 16, "ring 1 stays within its box: %s" % [counts])

func _test_lod_rings_hysteresis() -> void:
	var r := LodRingPolicy.WINDOW_RADIUS
	var win := func(p: Vector2) -> Rect2i:
		var pc := Vector2i(floori(p.x / 32.0), floori(p.y / 32.0))
		return Rect2i(pc - Vector2i(r, r), Vector2i(2 * r + 1, 2 * r + 1))
	var a := Vector2(31.0, 31.0)
	var plan := LodRingPolicy.boxes(a, win.call(a), 5)
	assert_true(LodRingPolicy.still_holds(plan, a, win.call(a)), "a fresh plan holds")
	for p in [Vector2(33.0, 31.0), Vector2(31.0, 33.0), Vector2(-1.0, -1.0), Vector2(33.0, 33.0)]:
		assert_true(LodRingPolicy.still_holds(plan, p, win.call(p)), "a step over the border at %s keeps the plan" % p)
	var far := Vector2(31.0 + 64.0 * 4.0, 31.0)
	assert_false(LodRingPolicy.still_holds(plan, far, win.call(far)), "four ring-1 chunks on, a new plan")

func _test_lod_rings_skirt() -> void:
	ChunkRecordsScript.clear()
	for level in [1, 3]:
		var built := VoxelLod.build_lod_arrays(level, Vector2i(2, -3), SEED)
		assert_true(int(built.get("skirt_quads", 0)) > 0, "level %d chunk skirts its border" % level)
		assert_false(built.has("collision"), "level %d chunk carries no collision" % level)
		var v: PackedVector3Array = built["vertices"]
		var low := INF
		for p in v:
			low = minf(low, p.y)
		assert_true(low <= VoxelSlice.BEDROCK_DEPTH + 0.01, "level %d skirts reach bedrock" % level)
		assert_eq((built["custom0"] as PackedByteArray).size(), v.size() * 4, "level %d carries terrain weights" % level)

func _test_lod_rings_haze() -> void:
	for rings in range(1, LodRingPolicy.MAX_RINGS + 1):
		var r := LodRingPolicy.outer_radius_m(rings, LodRingPolicy.WINDOW_RADIUS)
		var d := WeatherWiring.haze_density_for(rings)
		assert_true(1.0 - exp(-d * r) >= 0.9 - 1e-6, "%d rings: clear fog %.3f at the outer radius %.0f m" % [rings, 1.0 - exp(-d * r), r])
		assert_true(1.0 - exp(-d * r * 0.25) < 0.5, "%d rings: the first quarter stays mostly clear" % rings)
	assert_eq(WeatherWiring.haze_density_for(0), WeatherWiring.HAZE_DENSITY, "no rings: the old haze")
	assert_true(absf(WeatherWiring.weather_fog_density(1.0) - WeatherWiring.haze_density()) < 1e-12, "clear weather is the fitted haze")
	assert_true(WeatherWiring.weather_fog_density(0.5) > WeatherWiring.haze_density(), "weather still thickens it")
	assert_true(LodRingPolicy.outer_radius_m(2, 4) > LodRingPolicy.outer_radius_m(1, 4), "more rings reach further")

class FadeProbe extends Node3D:
	var fades: Array = []
	func set_fade(f: float) -> void:
		fades.append(f)

func _test_lod_rings_fade() -> void:
	var fade := LodFade.new()
	var holder := Node3D.new()
	var old := FadeProbe.new()
	var fresh := FadeProbe.new()
	holder.add_child(old)
	fade.cross_fade([old], [fresh])
	assert_eq(old.get_parent(), fade, "the old surface is handed to the fade")
	assert_eq(fade.active(), 1, "one fade in flight")
	assert_eq(fresh.fades.back(), 0.0, "the new surface starts hidden")
	assert_eq(old.fades.back(), 2.0, "the old one starts whole")
	fade.step(LodFade.FADE_SEC * 0.5)
	assert_true(absf(float(fresh.fades.back()) - 0.5) < 1e-6 and absf(float(old.fades.back()) - 2.5) < 1e-6,
		"half way: the two dithers are complementary at the same progress")
	fade.step(LodFade.FADE_SEC)
	assert_eq(fade.active(), 0, "the fade ends")
	assert_eq(fresh.fades.back(), 1.0, "the new surface is drawn whole")
	assert_true(old.is_queued_for_deletion(), "the old surface is freed")
	old.free()
	fresh.free()
	holder.free()
	fade.free()

func _test_lod_rings_node() -> void:
	ChunkRecordsScript.clear()
	var lod := LodTerrain.new()
	lod.ring_count = 3
	lod.world_seed = SEED
	var pair: Array = _windows()[0]
	assert_true(lod.update(pair[0], pair[1]), "the first update plans the rings")
	assert_false(lod.update(pair[0], pair[1]), "the same viewer plans nothing new")
	var expected := 0
	for k in range(1, 4):
		expected += LodRingPolicy.ring_chunks(lod.boxes(), k, pair[1]).size()
	assert_eq(lod.pending_count(), expected, "every ring chunk is queued")
	assert_eq(lod.outer_rect_m(), Rect2(), "nothing drawn yet: the distant ring keeps the window's hole")
	var outer := lod.planned_outer_rect_m()
	assert_eq(outer, LodRingPolicy.box_rect_m(lod.boxes()[3], 3), "the planned hole is the outer box")
	assert_eq(outer.size.x, outer.size.y, "a square hole")
	assert_true(outer.has_point(pair[0]), "round the viewer")
	var h := lod.hole_rect()
	assert_eq(h, Vector4(pair[1].position.x * 32.0, pair[1].position.y * 32.0, pair[1].end.x * 32.0, pair[1].end.y * 32.0),
		"ring 1's cut is the window")
	lod.free()
