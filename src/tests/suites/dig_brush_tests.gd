extends "res://src/tests/test_support.gd"
## Phase 300 — the dig brush rasteriser: volume, bounds, placed blocks, bedrock, cut rules and a side dig.

const Ras := preload("res://src/terrain/dig_rasteriser.gd")

const CELL_M3 := 0.5 * 0.5 * 0.125

func register() -> void:
	_run_test("dig brush: a 1 m sphere on flat ground removes about a half sphere", _test_dig_half_sphere)
	_run_test("dig brush: no column outside the brush bounds changes", _test_dig_bounds)
	_run_test("dig brush: a placed block inside the bounds is untouched", _test_dig_placed_untouched)
	_run_test("dig brush: the cut stops at BEDROCK_DEPTH", _test_dig_bedrock)
	_run_test("dig brush: a cut_ok that refuses rock removes no rock", _test_dig_cut_rules)
	_run_test("dig brush: a side dig into a cliff leaves a roof run above the hole", _test_dig_side_roof)
	_run_test("dig brush: the cells repeat for the same brush and runs", _test_dig_deterministic)

func _flat(top: float) -> Callable:
	return func(_tile: Vector2i) -> Array: return [{ "bottom": -96.0, "top": top, "material": "" }]

func _test_dig_half_sphere() -> void:
	var brush := { "shape": "sphere", "centre": Vector3(0.25, 0.0, 0.25), "radius": 1.0, "k": 0.0 }
	var cells: Array = Ras.rasterise(brush, _flat(0.0))
	var vol := float(cells.size()) * CELL_M3
	var half := 2.0 * PI / 3.0
	assert_true(absf(vol - half) / half <= 0.05, "volume %.3f within 5%% of half sphere %.3f" % [vol, half])

func _test_dig_bounds() -> void:
	var brush := { "shape": "sphere", "centre": Vector3(0.25, 0.0, 0.25), "radius": 1.0, "k": 0.0 }
	var ok := true
	for cell in Ras.rasterise(brush, _flat(0.0)):
		var t: Vector2i = cell["tile"]
		ok = ok and absi(t.x) <= 2 and absi(t.y) <= 2 and float(cell["bottom"]) >= -1.0 - 0.125
	assert_true(ok, "every cell lies inside the brush bounds")

func _test_dig_placed_untouched() -> void:
	var runs := func(_t: Vector2i) -> Array:
		return [{ "bottom": -96.0, "top": -0.5, "material": "" }, { "bottom": -0.5, "top": 0.0, "material": "Ashite" }]
	var brush := { "shape": "sphere", "centre": Vector3(0.25, 0.0, 0.25), "radius": 1.0, "k": 0.0 }
	var hit_placed := false
	for cell in Ras.rasterise(brush, runs):
		hit_placed = hit_placed or float(cell["bottom"]) >= -0.5
	assert_true(not hit_placed, "no cell inside the placed span")

func _test_dig_bedrock() -> void:
	var brush := { "shape": "sphere", "centre": Vector3(0.25, -96.0, 0.25), "radius": 1.0, "k": 0.0 }
	var low := 0.0
	for cell in Ras.rasterise(brush, _flat(0.0)):
		low = minf(low, float(cell["bottom"]))
	assert_true(low >= -96.0, "nothing below BEDROCK_DEPTH, lowest %f" % low)

func _test_dig_cut_rules() -> void:
	var rock_below := func(_t: Vector2i, bottom: float, _top: float) -> bool: return bottom >= -0.5
	var brush := { "shape": "sphere", "centre": Vector3(0.25, 0.0, 0.25), "radius": 1.0, "k": 0.0 }
	var cells: Array = Ras.rasterise(brush, _flat(0.0), rock_below)
	var deepest := 0.0
	for cell in cells:
		deepest = minf(deepest, float(cell["bottom"]))
	assert_true(not cells.is_empty() and deepest >= -0.5, "the cut stops where cut_ok refuses")

func _test_dig_side_roof() -> void:
	# A cliff face: tiles x >= 0 are ground to y = 4, tiles x < 0 are ground to y = 0. A sphere centred in the wall at y = 1 leaves the wall above it.
	var runs := func(t: Vector2i) -> Array:
		return [{ "bottom": -96.0, "top": 4.0 if t.x >= 0 else 0.0, "material": "" }]
	var brush := { "shape": "sphere", "centre": Vector3(0.25, 1.0, 0.25), "radius": 0.75, "k": 0.0 }
	var cells: Array = Ras.rasterise(brush, runs)
	var top_cut := -100.0
	for cell in cells:
		if (cell["tile"] as Vector2i).x >= 0:
			top_cut = maxf(top_cut, float(cell["top"]))
	assert_true(top_cut > 1.0 and top_cut < 4.0, "hole top %f stays under the wall top 4.0 (a roof run remains)" % top_cut)

func _test_dig_deterministic() -> void:
	var brush := { "shape": "cylinder", "centre": Vector3(1.1, 0.4, -0.7), "radius": 0.8, "half_height": 0.5, "k": 0.2 }
	var a: Array = Ras.rasterise(brush, _flat(0.5))
	var b: Array = Ras.rasterise(brush, _flat(0.5))
	assert_true(a.size() > 0 and a == b, "same brush, same cells")
