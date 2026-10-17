extends "res://src/tests/test_support.gd"
## Phase 136 — creatures walk on the ground and around obstacles.

const CreaturePath := preload("res://src/creature/creature_path.gd")

## A voxel stand-in: the column top of tile (x, z) is `fn(x, z)`. Tiles are 1 m here (the slice's unwired size).
class FakeVoxel extends Node:
	var fn: Callable
	func get_voxel_height_at(xz: Vector2) -> float:
		return float(fn.call(floori(xz.x), floori(xz.y)))

func register() -> void:
	_run_test("path: fabric carries the ground-movement fields", _test_path_fabric_fields)
	_run_test("path: a chase across a valley stays on the surface", _test_path_valley_chase)
	_run_test("path: a 3 m wall is walked around, not through", _test_path_wall_detour)
	_run_test("path: a non-swimmer avoids water, an island goal ends on the shore", _test_path_water_island)
	_run_test("path: a walled pocket stops at the expansion cap", _test_path_pocket_cap)
	_run_test("path: the budget caps searches per tick and nobody starves", _test_path_budget_fairness)
	_run_test("path: a chase across the X wrap takes the short way round", _test_path_seam_wrap)
	_run_test("path: a flyer holds its hover band, a ground creature stays on the surface", _test_path_flyer_hover)
	_run_test("path: a creature at the end of a partial path retries within the interval", _test_path_partial_retry)
	_run_test("path: a changed column replans, an unloaded chunk freezes", _test_path_stale_and_freeze)

func _flat_rules(extra: Dictionary = {}) -> Dictionary:
	var r := { "max_step": 0.75, "can_swim": false, "radius": 24, "sea_level": 0.0, "lap_tiles": 0 }
	r.merge(extra, true)
	return r

func _surface(fn: Callable) -> Callable:
	return func(tile: Vector2i) -> float: return float(fn.call(tile.x, tile.y))

## A creature slice over `fn`, one ForestBoar at (0.5, ., 0.5), and an AI driving it.
func _make_walker(fn: Callable, count: int = 1) -> Dictionary:
	var v := FakeVoxel.new()
	v.fn = fn
	add_child(v)
	var c := CreatureSlice.new()
	c.voxel_slice = v
	add_child(c)
	var ai := CreatureAI.new()
	ai.creature_slice = c
	add_child(ai)
	var ids: Array = []
	for i in count:
		var iid: String = c._spawn("ForestBoar", Vector2i(0, 0), i)
		c.set_instance_position(iid, Vector3(0.5, 0.0, 0.5))
		ai.force_state(iid, "aggressive")
		ids.append(iid)
	return { "voxel": v, "creature": c, "ai": ai, "ids": ids }

func _free_walker(w: Dictionary) -> void:
	w["ai"].free()
	w["creature"].free()
	w["voxel"].free()

func _test_path_fabric_fields() -> void:
	for key in GameData.CREATURES:
		var res: Resource = GameData.CREATURES[key]
		assert_true(float(res.get("maxStepMetres")) > 0.0, "%s climbs a positive step" % key)
		var radius := int(res.get("pathRadiusTiles"))
		assert_true(radius >= 1 and radius <= 64, "%s has a bounded search radius" % key)
		assert_true(res.get("canSwim") is bool, "%s says whether it swims" % key)

func _test_path_valley_chase() -> void:
	var valley := func(x: int, _z: int) -> float: return 0.25 * float(absi(x - 5))
	var w := _make_walker(valley)
	var ai: CreatureAI = w["ai"]
	var c: CreatureSlice = w["creature"]
	var iid: String = w["ids"][0]
	ai.player_targets = func() -> Dictionary: return { "player": Vector3(10.5, 1.25, 0.5) }
	var worst := 0.0
	for i in 40:
		ai._process(0.1)
		var pos := c.get_instance_position(iid)
		worst = maxf(worst, absf(pos.y - valley.call(floori(pos.x), floori(pos.z))))
	assert_true(worst <= 0.1, "the creature stays within 0.1 m of the surface at every step (worst %f)" % worst)
	assert_true(c.get_instance_position(iid).x > 5.0, "and it made its way across the valley")
	_free_walker(w)

func _test_path_wall_detour() -> void:
	var wall := func(x: int, z: int) -> float: return 3.0 if x == 5 and absi(z) <= 3 else 0.0
	var w := _make_walker(wall)
	var ai: CreatureAI = w["ai"]
	var c: CreatureSlice = w["creature"]
	var iid: String = w["ids"][0]
	ai.player_targets = func() -> Dictionary: return { "player": Vector3(10.5, 0.0, 0.5) }
	var through := false
	for i in 150:
		ai._process(0.1)
		var pos := c.get_instance_position(iid)
		if floori(pos.x) == 5 and absi(floori(pos.z)) <= 3:
			through = true
	assert_false(through, "the creature never stands in the wall")
	assert_true(c.get_instance_position(iid).distance_to(Vector3(10.5, 0.0, 0.5)) < 2.0, "it gets round to the player")
	_free_walker(w)

func _test_path_water_island() -> void:
	var lake := func(x: int, z: int) -> float:
		if x == 5 and z == 0:
			return 1.0
		return -1.0 if x >= 3 and x <= 7 and absi(z) <= 3 else 1.0
	var info := CreaturePath.search(Vector2i(-5, 0), Vector2i(5, 0), _flat_rules(), _surface(lake))
	assert_false(info["reached"], "an island goal is not reachable on foot")
	var path: Array = info["path"]
	assert_false(path.is_empty(), "but the creature still walks toward it")
	for t in path:
		assert_true(float(lake.call(t.x, t.y)) >= 0.0, "no step in %s is in the water" % str(t))
	assert_eq(path[-1], Vector2i(2, 0), "the partial path ends at the nearest shore tile")
	var swim := CreaturePath.search(Vector2i(-5, 0), Vector2i(5, 0), _flat_rules({ "can_swim": true, "max_step": 3.0 }), _surface(lake))
	assert_true(swim["reached"], "a swimmer reaches the island")

func _test_path_pocket_cap() -> void:
	var pocket := func(x: int, z: int) -> float: return 5.0 if maxi(absi(x), absi(z)) == 12 else 0.0
	var info := CreaturePath.search(Vector2i.ZERO, Vector2i(20, 0), _flat_rules({ "max_expansions": 50 }), _surface(pocket))
	assert_true(info["capped"], "the search stops at its cap")
	assert_eq(info["expansions"], 50, "after exactly the capped expansions")
	assert_false(info["reached"], "and does not reach across the wall")

func _test_path_budget_fairness() -> void:
	var flat := func(_x: int, _z: int) -> float: return 0.0
	var count := 200
	var w := _make_walker(flat, count)
	var ai: CreatureAI = w["ai"]
	var c: CreatureSlice = w["creature"]
	var start := {}
	for i in count:
		var iid: String = w["ids"][i]
		c.set_instance_position(iid, Vector3(float(i % 14) + 3.5, 0.0, float(i / 14) - 7.0 + 0.5))
		start[iid] = c.get_instance_position(iid)
	ai.player_targets = func() -> Dictionary: return { "player": Vector3(10.9, 0.0, 0.9) }
	var ticks := ceili(float(count) / float(ai.path_budget))
	for i in ticks:
		ai._process(0.1)
		assert_true(ai.path_searches_this_tick <= ai.path_budget, "tick %d stays within the search budget" % i)
	assert_true(ai.path_searches_peak <= ai.path_budget, "no tick ever exceeded the budget")
	var still := 0
	for iid in w["ids"]:
		if c.get_instance_position(iid).is_equal_approx(start[iid]):
			still += 1
	assert_eq(still, 0, "every creature has moved within ceil(200 / budget) ticks")
	_free_walker(w)

func _test_path_seam_wrap() -> void:
	var flat := func(_x: int, _z: int) -> float: return 0.0
	var lap := TerrainSlice.circumference_chunks() * TerrainSlice.CHUNK_SIZE
	var rules := _flat_rules({ "lap_tiles": lap })
	var seen := {}
	var surface := func(tile: Vector2i) -> float:
		seen[tile.x] = true
		return 0.0
	# Chunk X = 1,500,000 is past one lap (1,250,000): the same place as chunk 250,000.
	var from := Vector2i(1500000 * TerrainSlice.CHUNK_SIZE, 0)
	var info := CreaturePath.search(from, from + Vector2i(10, 0), rules, surface)
	assert_true(info["reached"], "a chase far past the first lap reaches its goal")
	assert_eq(info["path"].size(), 10, "in a straight run of ten tiles")
	for x in seen:
		assert_true(absi(int(x)) <= lap / 2, "the surface is only asked about canonical tiles")
	# Across the seam: from just west of it to just east of it, the short way is 6 tiles, not a lap.
	var west := Vector2i(lap / 2 - 3, 0)
	var east := Vector2i(-lap / 2 + 3, 0)
	var across := CreaturePath.search(west, east, rules, _surface(flat))
	assert_true(across["reached"], "the seam crossing reaches the goal")
	assert_eq(across["path"].size(), 6, "taking the short way round")
	assert_eq(across["path"][-1], Vector2i(lap / 2 + 3, 0), "in a frame continuous with the start")
	var back := CreaturePath.search(east, west, rules, _surface(flat))
	assert_eq(back["path"].size(), 6, "and the same going back")

func _test_path_stale_and_freeze() -> void:
	var world := { "wall": false, "loaded": true }
	var h := func(x: int, z: int) -> float: return 3.0 if world["wall"] and x == 5 and absi(z) <= 3 else 0.0
	var w := _make_walker(h)
	var ai: CreatureAI = w["ai"]
	var c: CreatureSlice = w["creature"]
	var iid: String = w["ids"][0]
	c.chunk_built = func(_chunk: Vector2i) -> bool: return world["loaded"]
	ai.player_targets = func() -> Dictionary: return { "player": Vector3(10.5, 0.0, 0.5) }
	ai._process(0.1)
	ai._process(0.1)
	assert_true(ai._ai[iid].has("path"), "the creature has a path")
	GameBus.block_changed.emit("place", Vector3(5.5, 0.0, 0.5), Vector3.UP, "stone")
	assert_true(ai._ai[iid].get("path_stale", false), "a block placed on the path marks it stale")
	world["wall"] = true
	var wall_hit := false
	for i in 100:
		ai._process(0.1)
		var pos := c.get_instance_position(iid)
		if floori(pos.x) == 5 and absi(floori(pos.z)) <= 3:
			wall_hit = true
	assert_false(wall_hit, "the new wall is walked around")
	var frozen_at := c.get_instance_position(iid)
	world["loaded"] = false
	for i in 5:
		ai._process(0.1)
	assert_eq(c.get_instance_position(iid), frozen_at, "a creature in an unloaded chunk does not move")
	# A mined pit: the creature's Y follows the column top.
	world["loaded"] = true
	c.set_instance_position(iid, Vector3(1.5, 0.0, 8.5))
	assert_eq(c.get_instance_position(iid).y, 0.0, "it stands on the column top")
	_free_walker(w)

func _test_path_flyer_hover() -> void:
	var rolling := func(x: int, _z: int) -> float: return 0.25 * float(absi(x - 5))
	var w := _make_walker(rolling)
	var ai: CreatureAI = w["ai"]
	var c: CreatureSlice = w["creature"]
	var boar: String = w["ids"][0]
	var hawk: String = c._spawn("RidgeHawk", Vector2i(0, 0), 0)
	c.set_instance_position(hawk, Vector3(0.5, 0.0, 2.5))
	ai.force_state(hawk, "aggressive")
	var hover := CreatureSlice.hover_for_creature("RidgeHawk")
	assert_true(hover > 0.0, "the fabric gives the hawk a hover height (%f)" % hover)
	assert_eq(CreatureSlice.hover_for_creature("ForestBoar"), 0.0, "a ground creature has no hover band")
	ai.player_targets = func() -> Dictionary: return { "player": Vector3(10.5, 1.25, 0.5) }
	for i in 100:
		ai._process(0.1)
		var hp := c.get_instance_position(hawk)
		var gp := c.get_instance_position(boar)
		var hawk_ground: float = rolling.call(floori(hp.x), floori(hp.z))
		var boar_ground: float = rolling.call(floori(gp.x), floori(gp.z))
		assert_true(absf(hp.y - (hawk_ground + hover)) < 0.001, "tick %d: the hawk stays %f m above the surface" % [i, hover])
		assert_true(absf(gp.y - boar_ground) < 0.001, "tick %d: the boar stays on the surface" % i)
	_free_walker(w)

func _test_path_partial_retry() -> void:
	var world := { "water": true }
	var h := func(x: int, _z: int) -> float: return -1.0 if world["water"] and x >= 8 else 0.0
	var w := _make_walker(h)
	var ai: CreatureAI = w["ai"]
	var c: CreatureSlice = w["creature"]
	var iid: String = w["ids"][0]
	var goal := Vector3(10.5, 0.0, 0.5)
	ai.player_targets = func() -> Dictionary: return { "player": goal }
	for i in 150:
		ai._process(0.1)
	var stuck := c.get_instance_position(iid)
	assert_true(stuck.x < 8.0, "the creature stops at the shore (%f)" % stuck.x)
	assert_false(bool(ai._ai[iid].get("path_reached", true)), "its path is partial")
	world["water"] = false   # the water drains without any block event: only the retry timer can notice
	var ticks := ceili(CreatureAI.PATH_RETRY_SECONDS / 0.1) + 8
	for i in ticks:
		ai._process(0.1)
	assert_true(c.get_instance_position(iid).distance_to(goal) < 2.0, "it reached the goal within the retry interval")
	_free_walker(w)
