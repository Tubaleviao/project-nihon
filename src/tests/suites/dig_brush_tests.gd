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
	_run_test("dig brush: a shovel dig is one brush op that moves a shovelful", _test_dig_shovel_host)
	_run_test("dig brush: yield is conserved however a volume is split", _test_dig_yield_conservation)
	_run_test("dig brush: a client applying the wire op holds the host's runs", _test_dig_wire_parity)
	_run_test("dig brush: the dig remainder is saved with the player", _test_dig_remainder_saved)
	_run_test("dig brush: the fabric brushes stay under the radius cap", _test_dig_fabric_caps)
	_run_test("dig brush: the GDScript and native rasterisers agree on 200 random brushes", _test_dig_native_parity)
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

func _shovel_voxel() -> Array:
	var v := _make_voxel()
	var inv := InventorySlice.new()
	add_child(inv)
	inv._max_weight = 1.0e9
	v.inventory_slice = inv
	inv.add_item("StoneShovel", 1)
	return [v, inv]

func _runs_of(v: VoxelSlice, centre: Vector2, reach: int) -> Dictionary:
	var out := {}
	var t0 := Vector2i(floori(centre.x / VoxelSlice.TILE_SIZE), floori(centre.y / VoxelSlice.TILE_SIZE))
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			var t := t0 + Vector2i(dx, dz)
			out[t] = v.get_runs_at_tile(t)
	return out

func _test_dig_shovel_host() -> void:
	var pair := _shovel_voxel()
	var v: VoxelSlice = pair[0]
	var inv: Node = pair[1]
	var top := v.get_voxel_height_at(Vector2(16.25, 16.25))
	var sent: Array = []
	var cb := func(action: String, pos: Vector3, normal: Vector3, material: String) -> void: sent.append([action, pos, normal, material])
	GameBus.block_changed.connect(cb)
	var r := v.mine_block(Vector3(16.25, top, 16.25), Vector3.UP)
	GameBus.block_changed.disconnect(cb)
	assert_true(bool(r.get("success", false)), "the dig succeeds")
	assert_true(sent.size() == 1 and sent[0][0] == "dig", "one dig op on the wire, not one per slab")
	assert_true(int(r["quantity"]) > 4, "a shovelful yields many units, got %d" % int(r["quantity"]))
	assert_true(v.get_voxel_height_at(Vector2(16.25, 16.25)) < top, "the ground is lower")
	v.queue_free()
	inv.queue_free()

func _test_dig_wire_parity() -> void:
	var host := _make_voxel()
	var client := _make_voxel()
	var tool := "StoneShovel"
	var plan := host._dig.plan(Vector3(16.25, 1.5, 16.25), 0.6, 0.0, "sphere", tool)
	assert_true(not (plan["cells"] as Array).is_empty(), "the host plan cuts something")
	host._dig.apply_plan(plan["cells"], 0)
	client.apply_block_change("dig", Vector3(16.25, 1.5, 16.25), Vector3(0.6, 0.0, 0.0), tool)
	var a := _runs_of(host, Vector2(16.25, 16.25), 3)
	var b := _runs_of(client, Vector2(16.25, 16.25), 3)
	assert_true(a == b, "identical runs for every touched tile")
	var changed := 0
	for t in a:
		if a[t] != _make_voxel().get_runs_at_tile(t):
			changed += 1
	assert_true(changed > 0, "the dig changed columns")
	host.queue_free()
	client.queue_free()

func _test_dig_yield_conservation() -> void:
	var v := _make_voxel()
	var unit := 0.5 * 0.5 * 0.125
	var small := {}
	for _i in 20:
		var paid: Dictionary = v._dig.pay_units("p1", { "Soil": unit * 0.1 })
		for m in paid:
			small[m] = int(small.get(m, 0)) + int(paid[m])
	var big: Dictionary = v._dig.pay_units("p2", { "Soil": unit * 0.1 * 20.0 })
	assert_eq(int(small.get("Soil", 0)), int(big.get("Soil", 0)), "20 small digs yield what one big dig does")
	v.queue_free()

func _test_dig_fabric_caps() -> void:
	var res: Resource = GameData.WORLD_SYSTEMS.get("DigBrush", null)
	assert_true(res != null, "the DigBrush fabric entity exists")
	var cap := float(res.get("radiusCap"))
	for tool in (res.get("brushes") as Dictionary):
		var b: Dictionary = res.get("brushes")[tool]
		assert_true(float(b["radiusMax"]) <= cap, "%s stays under the cap" % tool)
	var shovel: Dictionary = res.get("brushes")["StoneShovel"]
	assert_true(not (shovel["materials"] as Array).has("Ashite"), "a shovel cuts no rock")

func _test_dig_remainder_saved() -> void:
	var v := _make_voxel()
	var reg := PlayerRegistry.new()
	v.player_registry = reg
	reg.ensure_player("p")
	v._dig.pay_units("p", { "Soil": 0.01 })
	assert_true(absf(float(reg.get_dig_remainder("p").get("Soil", 0.0)) - 0.01) < 0.000001, "the remainder is on the record")
	var reg2 := PlayerRegistry.new()
	reg2.apply_player_data("p", reg.get_player_data("p"))
	assert_true(absf(float(reg2.get_dig_remainder("p").get("Soil", 0.0)) - 0.01) < 0.000001, "and survives a save")
	reg2.apply_player_data("q", { "dig_remainder": { "Soil": "bad", "Sand": -4.0, "Snow": 99.0 } })
	var clean := reg2.get_dig_remainder("q")
	assert_true(not clean.has("Soil") and float(clean["Sand"]) == 0.0 and float(clean["Snow"]) == 1.0, "a hostile payload is clamped")
	v.player_registry = null
	reg2.free()
	reg.free()
	v.queue_free()

func _test_dig_native_parity() -> void:
	if not NativeLoaderScript.use_native("NativeBake", "dig_cells"):
		return   # no native build here: the GDScript is the only implementation, nothing to compare
	var rng := RandomNumberGenerator.new()
	rng.seed = 300
	var shapes := ["sphere", "cylinder", "box"]
	var same := true
	var cells := 0
	for i in 200:
		var brush := {
			"shape": shapes[rng.randi() % 3],
			"centre": Vector3(rng.randf_range(-500.0, 500.0), rng.randf_range(-97.0, 60.0), rng.randf_range(-500.0, 500.0)),
			"radius": rng.randf_range(0.2, 1.5), "half_height": rng.randf_range(0.2, 1.5), "k": rng.randf_range(0.0, 0.5),
		}
		var a := Ras.geometry_gd(brush)
		var b := Ras.geometry(brush)
		cells += a.size()
		if a != b:
			same = false
			print("parity mismatch on brush %d: %s (%d vs %d cells)" % [i, brush, a.size(), b.size()])
			break
	assert_true(same and cells > 0, "identical cells for 200 random brushes (%d ints)" % cells)
