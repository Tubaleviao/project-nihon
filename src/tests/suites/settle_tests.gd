extends "res://src/tests/test_support.gd"
## Phase 137 — loose ground settles: sand and soil fall when undermined.

const Settle := preload("res://src/terrain/settle.gd")

## Counts the rebuilds a settle asks for, so a 1,000-column collapse does not mesh a chunk per column.
class RebuildCounter extends Node:
	var rebuilds := 0
	func request_rebuild(_chunk: Vector2i) -> void:
		rebuilds += 1

func register() -> void:
	_run_test("settle: the fabric marks sand, soil and snow granular and rock not", _test_settle_fabric)
	_run_test("settle: a sand span over air lands on the first solid span, volume kept", _test_settle_column)
	_run_test("settle: rock over air stays and a settled column is a no-op", _test_settle_rock_and_noop)
	_run_test("settle: mining under a sand stack leaves nothing over air, saved and loaded", _test_settle_mine_under_stack)
	_run_test("settle: a 1,000-column collapse respects the per-tick budget", _test_settle_budget)
	_run_test("settle: a column in an unloaded chunk waits for the chunk", _test_settle_unloaded_chunk)
	_run_test("settle: a client edit queues nothing, a settle grants no item", _test_settle_client_and_items)
	_run_test("settle: a client applies the host's settle and matches its column", _test_settle_client_sync)
	_run_test("settle: a fall deeper than the tree clear depth clears trees", _test_settle_tree_clear)

func _sand(bottom: float, top: float) -> Dictionary:
	return { "bottom": bottom, "top": top, "material": "Sand" }

func _is_granular(material: String) -> bool:
	return VoxelSlice.is_granular(material)

## Sand `height` m thick standing on `base` of a tile, with the natural column under it dug out by `gap`.
func _stack_with_gap(v: VoxelSlice, tile: Vector2i, base: float, height: float, gap: float) -> void:
	v._append_edit(tile, { "op": "add", "bottom": base, "top": base + height, "material": "Sand" })
	v._append_edit(tile, { "op": "remove", "bottom": base - gap, "top": base })

func _loose_over_air(runs: Array) -> bool:
	var support := VoxelSlice.BEDROCK_DEPTH
	for run in runs:
		if VoxelSlice.is_granular(str(run["material"])) and float(run["bottom"]) > support + 0.000001:
			return true
		support = maxf(support, float(run["top"]))
	return false

func _volume_by_material(runs: Array) -> Dictionary:
	var out := {}
	for run in runs:
		var m := str(run["material"])
		out[m] = float(out.get(m, 0.0)) + float(run["top"]) - float(run["bottom"])
	return out

func _test_settle_fabric() -> void:
	for m in ["Sand", "Soil", "Snow"]:
		assert_true(VoxelSlice.is_granular(m), "%s is granular" % m)
	for m in ["Ferrite", "Ashite", "Lumenfite", "Thornwood", "Grass"]:
		assert_false(VoxelSlice.is_granular(m), "%s is not granular" % m)
	assert_false(VoxelSlice.is_granular("NoSuchMaterial"), "an unknown material is not granular")
	assert_eq(Settle.TREE_CLEAR_DROP_M, TreeSlice.CLEAR_DEPTH_M, "a fall clears trees at the Phase 116 depth")

func _test_settle_column() -> void:
	var rock := { "bottom": -96.0, "top": 1.0, "material": "" }
	var spans := [rock, _sand(3.0, 4.0), _sand(6.0, 6.5)]
	var out := Settle.settle_column(spans, _is_granular)
	assert_eq(out.size(), 2, "the two sand spans stack into one run once they land")
	assert_eq(float(out[1]["bottom"]), 1.0, "sand lands on the first solid span")
	assert_eq(float(out[1]["top"]), 2.5, "the second span lands on the first")
	var before := _volume_by_material(spans)
	var after := _volume_by_material(out)
	assert_eq(after["Sand"], before["Sand"], "sand volume is kept")
	assert_eq(after[""], before[""], "rock volume is kept")
	var floor_drop := Settle.settle_column([_sand(-10.0, -9.0)], _is_granular, -96.0)
	assert_eq(float(floor_drop[0]["bottom"]), -96.0, "sand over nothing lands on the world floor")

func _test_settle_rock_and_noop() -> void:
	var spans := [{ "bottom": -96.0, "top": 1.0, "material": "" }, { "bottom": 3.0, "top": 4.0, "material": "Ashite" }]
	var out := Settle.settle_column(spans, _is_granular)
	assert_eq(out, spans, "a rock span over air does not move")
	var mixed := [{ "bottom": -96.0, "top": 1.0, "material": "" }, _sand(3.0, 4.0)]
	var once := Settle.settle_column(mixed, _is_granular)
	assert_eq(Settle.settle_column(once, _is_granular), once, "settling a settled column is a no-op")
	assert_true(Settle.moves(once, _is_granular).is_empty(), "a settled column has no moves")

func _test_settle_mine_under_stack() -> void:
	var v := _make_voxel()
	var tile := Vector2i(32, 32)
	# 5 sand blocks on the ground (top 2.0), then the stone under them dug out by 4 steps.
	for i in range(5):
		v._append_edit(tile, { "op": "add", "bottom": 2.0 + i * 0.125, "top": 2.125 + i * 0.125, "material": "Sand" })
	v._append_edit(tile, { "op": "remove", "bottom": 1.5, "top": 2.0 })
	v._settle_note(tile)
	assert_true(_loose_over_air(v.get_runs_at_tile(tile)), "the stack hangs before the queue runs")
	var guard := 0
	while v.settle_pending() > 0 and guard < 10:
		v.settle_tick()
		guard += 1
	var runs := v.get_runs_at_tile(tile)
	assert_false(_loose_over_air(runs), "no granular span over air after the queue drains")
	assert_eq(_volume_by_material(runs).get("Sand", 0.0), 0.625, "the sand volume is kept")
	assert_eq(float(runs[-1]["top"]), 1.5 + 0.625, "the stack sits on the first support")
	# Survives a save and load: a fresh slice given the saved edits reads the same column.
	var saved := v.get_edits()
	var w := _make_voxel()
	w.apply_edits(saved)
	assert_eq(w.get_runs_at_tile(tile), runs, "the settled column survives a save and load")
	assert_eq(w.settle_pending(), 0, "loading a world queues nothing")
	w.free()
	v.free()

func _test_settle_budget() -> void:
	var v := _make_voxel()
	var counter := RebuildCounter.new()
	add_child(counter)
	v.chunk_manager = counter
	var tiles: Array = []
	for z in range(0, 40):
		for x in range(0, 25):
			tiles.append(Vector2i(x + 4, z + 4))
	assert_eq(tiles.size(), 1000, "a 1,000-column collapse")
	for t in tiles:
		_stack_with_gap(v, t, 2.0, 0.5, 0.5)
		v._settle.push(t)
	var budget := 32
	var ticks := 0
	var most := 0
	while v.settle_pending() > 0 and ticks < 100:
		var n := v.settle_tick(budget)
		most = maxi(most, n)
		ticks += 1
	assert_true(most <= budget, "a tick never processes more than the budget (%d)" % most)
	assert_eq(ticks, ceili(1000.0 / budget), "the collapse finishes in ceil(1000 / budget) ticks")
	for t in tiles:
		if _loose_over_air(v.get_runs_at_tile(t)):
			assert_true(false, "tile %s still hangs" % str(t))
			break
	v.free()
	counter.free()

func _test_settle_unloaded_chunk() -> void:
	var v := _make_voxel()
	var edge := Vector2i(63, 10)   # chunk (0, 0); its east neighbour (64, 10) is in chunk (1, 0), not loaded
	var beyond := Vector2i(64, 10)
	var counter := RebuildCounter.new()
	add_child(counter)
	v.chunk_manager = counter
	v._settle_note(edge)
	v.settle_tick()
	assert_eq(v._settle.pending_size(), 1, "the column in the unloaded chunk is parked, not dropped")
	assert_eq(v._settle.size(), 0, "nothing else waits")
	# The neighbour chunk loads with sand hanging over air in the parked column.
	var hm: Array = []
	hm.resize(64 * 64)
	hm.fill(2.0)
	v._append_edit(beyond, { "op": "add", "bottom": 2.5, "top": 3.0, "material": "Sand" })
	v.chunk_manager = null
	v.build_chunk(Vector2i(1, 0), hm)
	assert_eq(v._settle.pending_size(), 0, "loading the chunk releases the parked column")
	v.settle_tick()
	assert_false(_loose_over_air(v.get_runs_at_tile(beyond)), "the settle applies once the chunk is loaded")
	v.free()
	counter.free()

func _test_settle_client_and_items() -> void:
	var v := _make_voxel()
	v.is_authoritative = false
	v._settle_note(Vector2i(32, 32))
	assert_eq(v.settle_pending(), 0, "a client's local edit enqueues nothing")
	assert_eq(v.settle_tick(), 0, "a client never settles")
	v.free()
	var host := _make_voxel()
	var inv := InventorySlice.new()
	add_child(inv)
	host.inventory_slice = inv
	var tile := Vector2i(32, 32)
	_stack_with_gap(host, tile, 2.0, 0.5, 0.5)
	host._settle_note(tile)
	host.settle_tick()
	assert_true(host.settle_edits > 0, "the host settled the column")
	assert_eq(inv.get_item_count("Sand"), 0, "a settle edit grants no item")
	assert_eq(inv.get_item_count("Soil"), 0, "a settle edit grants no other item")
	assert_eq(host.settle_pending(), 0, "a settle queues nothing")
	host.free()
	inv.free()

func _test_settle_client_sync() -> void:
	var host := _make_voxel()
	var client := _make_voxel()
	client.is_authoritative = false
	var tile := Vector2i(32, 32)
	for v in [host, client]:
		_stack_with_gap(v, tile, 2.0, 1.0, 1.0)
	assert_true(_loose_over_air(client.get_runs_at_tile(tile)), "the client sees the hanging column before the sync")
	host._settle_note(tile)
	host.settle_tick()
	assert_eq(client.get_runs_at_tile(tile), host.get_runs_at_tile(tile), "the client's column matches the host's after the sync")
	host.free()
	client.free()

func _test_settle_tree_clear() -> void:
	var v := _make_voxel()
	var seen: Array = []
	var cb := func(tile: Vector2i, edit_y: float) -> void: seen.append([tile, edit_y])
	GameBus.block_edit_resolved.connect(cb)
	var shallow := Vector2i(32, 32)
	_stack_with_gap(v, shallow, 2.0, 0.5, 0.5)
	v._settle_note(shallow)
	v.settle_tick()
	assert_true(seen.is_empty(), "a small fall clears no trees")
	var deep := Vector2i(40, 40)
	v._append_edit(deep, { "op": "add", "bottom": 8.0, "top": 8.5, "material": "Sand" })
	v._settle_note(deep)
	v.settle_tick()
	GameBus.block_edit_resolved.disconnect(cb)
	assert_eq(seen.size(), 1, "a fall deeper than CLEAR_DEPTH_M reports the ground edit once")
	assert_eq(seen[0][0], deep, "on the fallen tile")
	v.free()
