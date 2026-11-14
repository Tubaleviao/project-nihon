extends "res://src/tests/test_support.gd"
## Phase 261 — newcomer grounds: a few large, gentle areas where new characters start, with only weak creatures,
## loose stones and branches on the ground, and a protected centre.

const NewcomerGrounds := preload("res://src/world/newcomer_grounds.gd")
const LooseItemSlice := preload("res://src/world/loose_item_slice.gd")
const StoneTools := preload("res://src/world/stone_tools.gd")

const SEED := 7

func register() -> void:
	_run_test("newcomer grounds: the centres are identical for the same seed and spread apart", _test_centres_pure)
	_run_test("newcomer grounds: a new character's spawn lies inside a ground on dry, walkable land", _test_spawn_inside)
	_run_test("newcomer grounds: trees, rock, soil, loose items and an allowed creature lie within reach of a spawn", _test_resources_in_reach)
	_run_test("newcomer grounds: loose-item placement is identical for the same (seed, tile) and denser inside", _test_loose_pure)
	_run_test("newcomer grounds: a picked item is gone for every peer and regrows after the delay", _test_pick_and_regrow)
	_run_test("newcomer grounds: a pick-up out of reach, of a taken item or of a made-up id is refused", _test_pick_refused)
	_run_test("newcomer grounds: only allowed creatures spawn inside a ground", _test_creature_spawns)
	_run_test("newcomer grounds: an aggressive creature turns back at the edge, a weak one walks in", _test_turn_back)
	_run_test("newcomer grounds: no structure is placed within the claim radius of a centre", _test_claim_zone)
	_run_test("newcomer grounds: a spawn skips structure circles and falls back to the protected centre", _test_spawn_skips_structures)
	_run_test("newcomer grounds: loose items are jittered over both axes of their tile", _test_loose_jitter)
	_run_test("newcomer grounds: picks are rate limited; a join snapshot carries the taken items", _test_pick_rate_and_join)

## A terrain at SEED and the grounds primed for it.
func _world() -> Dictionary:
	var terrain := TerrainSlice.new()
	_own(terrain)
	terrain.set_world_seed(SEED)
	var height_fn := func(p: Vector2) -> float: return terrain.get_height_at(p)
	SpawnFinderScript.prime_grounds(SEED, height_fn)
	return { "terrain": terrain, "height_fn": height_fn }

func _test_centres_pure() -> void:
	var w := _world()
	var a: Array = NewcomerGrounds.centres(SEED).duplicate()
	assert_true(a.size() >= 1, "the world has at least one ground")
	assert_eq(a.size(), int(NewcomerGrounds.rule()["count"]), "as many as the fabric asks for")
	NewcomerGrounds.clear_cache()
	SpawnFinderScript.prime_grounds(SEED, w["height_fn"])
	assert_eq(NewcomerGrounds.centres(SEED), a, "the same seed gives the same centres")
	for i in a.size():
		for j in range(i + 1, a.size()):
			assert_true(NewcomerGrounds.wrapped_distance(a[i], a[j]) >= float(NewcomerGrounds.rule()["radiusMetres"]) * 4.0, "grounds %d and %d are apart" % [i, j])

func _test_spawn_inside() -> void:
	var w := _world()
	var biomes: Array = NewcomerGrounds.rule()["biomes"]
	for i in 12:
		var pid := "newcomer_%d" % i
		var p: Variant = SpawnFinderScript.find_start(SEED, pid, null, w["height_fn"])
		assert_true(p != null, "player %d has a spawn" % i)
		assert_true(NewcomerGrounds.inside(SEED, p.x, p.z), "player %d spawns inside a ground" % i)
		assert_true(SpawnFinderScript.is_standable(SEED, p.x, p.z, biomes, w["height_fn"]), "on dry, walkable land")
		assert_false(NewcomerGrounds.in_claim_zone(SEED, p.x, p.z), "never on the protected centre")
		assert_eq(p, SpawnFinderScript.find_start(SEED, pid, null, w["height_fn"]), "and it is the same every time")

func _loose(w: Dictionary) -> Node:
	var l := LooseItemSlice.new()
	l.render_visuals = false
	l.world_seed = SEED
	l.height_fn = w["height_fn"]
	add_child(l)
	return l

func _test_resources_in_reach() -> void:
	var w := _world()
	var l := _loose(w)
	var r := NewcomerGrounds.rule()
	var rad := float(r["resourceRadiusMetres"])
	var tree_slice := _make_tree_slice()
	var allowed: Array = r["allowedCreatures"]
	var soil_or_rock := ["TerrainDirt", "TerrainRock"]
	for k in soil_or_rock:
		assert_true(GameData.TERRAIN_MATERIALS.has(k), "%s is a terrain material" % k)
	for i in 6:
		var p: Vector3 = SpawnFinderScript.find_start(SEED, "res_%d" % i, null, w["height_fn"])
		var near: Array = l.items_near(Vector2(p.x, p.z), rad)
		var kinds := {}
		for it in near:
			kinds[it["kind"]] = true
		assert_true(kinds.has(StoneTools.BRANCH), "a branch within %d m of spawn %d" % [int(rad), i])
		assert_true(kinds.has(StoneTools.LOOSE_STONE), "a loose stone within reach of spawn %d" % i)
		var chunk := Vector2i(floori(p.x / TerrainSlice.CHUNK_METERS), floori(p.z / TerrainSlice.CHUNK_METERS))
		var trees := 0
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				var c := chunk + Vector2i(dx, dz)
				var b: String = str(w["terrain"].get_biome_at_chunk(c))
				trees += tree_slice.tree_count_for(c, b)
		assert_true(trees > 0, "trees grow around spawn %d" % i)
	assert_true(allowed.size() >= 1, "the fabric allows a creature for the first hunt")
	tree_slice.free()
	l.free()

func _test_loose_pure() -> void:
	var w := _world()
	var c: Vector2 = NewcomerGrounds.centres(SEED)[0]
	var inside_n := 0
	var out_n := 0
	var ctx := floori(c.x / LooseItemSlice.TILE)
	var ctz := floori(c.y / LooseItemSlice.TILE)
	for dx in range(-60, 60):
		for dz in range(-60, 60):
			var a := LooseItemSlice.item_at(SEED, ctx + dx, ctz + dz)
			assert_eq(a, LooseItemSlice.item_at(SEED, ctx + dx, ctz + dz), "the same tile gives the same item")
			if not a.is_empty():
				inside_n += 1
			var b := LooseItemSlice.item_at(SEED, ctx + 5000 + dx, ctz + 5000 + dz)
			if not b.is_empty():
				out_n += 1
	assert_true(inside_n > out_n * 3, "denser inside a ground (%d vs %d)" % [inside_n, out_n])
	assert_true(w != null, "world built")

func _first_item(l: Node, p: Vector3) -> Dictionary:
	var best: Dictionary = {}
	for it in l.items_near(Vector2(p.x, p.z), 100.0):
		best = it
		break
	return best

func _test_pick_and_regrow() -> void:
	var w := _world()
	var host := _loose(w)
	var client := _loose(w)
	client.is_authoritative = false
	var inv := InventorySlice.new()
	add_child(inv)
	host.inventory_slice = inv
	var now := [1000.0]
	host.clock = func() -> float: return now[0]
	var p: Vector3 = SpawnFinderScript.find_start(SEED, "pick", null, w["height_fn"])
	var it := _first_item(host, p)
	assert_false(it.is_empty(), "an item lies near the spawn")
	var xz: Vector2 = it["xz"]
	host.local_position = func() -> Vector3: return Vector3(xz.x, 0.0, xz.y)
	var res: Dictionary = host.pick(str(it["id"]), "")
	assert_true(bool(res["success"]), "picked (%s)" % str(res.get("reason", "")))
	assert_eq(inv.get_item_count(str(it["kind"])), 1, "the item is in the pack")
	assert_true(host.is_taken(str(it["id"])), "and gone from the host")
	assert_true(client.is_taken(str(it["id"])), "and gone for the peer too (loose_picked reached it)")
	var again: Dictionary = host.pick(str(it["id"]), "")
	assert_false(bool(again["success"]), "a second pick of it is refused")
	now[0] += float(NewcomerGrounds.rule()["looseRegrowSeconds"]) - 1.0
	host.tick()
	assert_true(host.is_taken(str(it["id"])), "not back before the delay")
	now[0] += 2.0
	host.tick()
	assert_false(host.is_taken(str(it["id"])), "back after the delay")
	assert_false(client.is_taken(str(it["id"])), "back for the peer too")
	host.free()
	client.free()
	inv.free()

func _test_pick_refused() -> void:
	var w := _world()
	var host := _loose(w)
	var inv := InventorySlice.new()
	add_child(inv)
	host.inventory_slice = inv
	var p: Vector3 = SpawnFinderScript.find_start(SEED, "far", null, w["height_fn"])
	var it := _first_item(host, p)
	var xz: Vector2 = it["xz"]
	host.local_position = func() -> Vector3: return Vector3(xz.x + 30.0, 0.0, xz.y)
	assert_eq(str(host.pick(str(it["id"]), "")["reason"]), "out_of_reach", "out of reach is refused")
	assert_eq(str(host.pick("not an id", "")["reason"]), "no_item", "a malformed id is refused")
	assert_eq(str(host.pick("99999999999:1", "")["reason"]), "no_item", "an id past the planet is refused")
	var nothing := "%d:%d" % [floori(p.x / 4.0) + 7777, 3]
	assert_eq(str(host.pick(nothing, "")["reason"]), "no_item", "a tile with no item is refused")
	assert_eq(inv.get_item_count(str(it["kind"])), 0, "nothing was given")
	host.free()
	inv.free()

func _ground_chunk(w: Dictionary) -> Vector2i:
	var c: Vector2 = NewcomerGrounds.centres(SEED)[0]
	return Vector2i(floori(c.x / TerrainSlice.CHUNK_METERS), floori(c.y / TerrainSlice.CHUNK_METERS))

func _test_creature_spawns() -> void:
	var w := _world()
	var cs := CreatureSlice.new()
	cs.render_visuals = false
	cs.terrain_slice = w["terrain"]
	cs.creature_table = GameData.CREATURES
	var chunk := _ground_chunk(w)
	var was_quiet: bool = Diag.quiet
	Diag.quiet = true
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			var c := chunk + Vector2i(dx, dz)
			var m := TerrainSlice.CHUNK_METERS
			if NewcomerGrounds.inside(SEED, (float(c.x) + 0.5) * m, (float(c.y) + 0.5) * m):
				cs.spawn_for_chunk(c)
	Diag.quiet = was_quiet
	var allowed: Array = NewcomerGrounds.rule()["allowedCreatures"]
	var n := 0
	for inst in cs.get_all_instances():
		n += 1
		assert_true(allowed.has(str(inst["creature_id"])), "%s is allowed inside a ground" % str(inst["creature_id"]))
	assert_true(n >= 3, "enough weak creatures live there for the first hunt (%d)" % n)
	cs.terrain_slice = null
	cs.free()

func _test_turn_back() -> void:
	var w := _world()
	var cs := CreatureSlice.new()
	cs.render_visuals = false
	cs.terrain_slice = w["terrain"]
	cs.creature_table = GameData.CREATURES
	var c: Vector2 = NewcomerGrounds.centres(SEED)[0]
	var edge := c + Vector2(float(NewcomerGrounds.rule()["radiusMetres"]) + 1.0, 0.0)
	var m := TerrainSlice.CHUNK_METERS
	var chunk := Vector2i(floori(edge.x / m), floori(edge.y / m))
	var local := Vector3(edge.x - float(chunk.x) * m, 0.0, edge.y - float(chunk.y) * m)
	for pair in [["GraywolfPack", true], ["ForestBoar", false]]:
		var iid := "turn_%s" % pair[0]
		cs._instances[iid] = { "creature_id": pair[0], "pos": { "chunk": chunk, "local": local }, "tamed_by": "" }
		assert_eq(cs._turned_back_at_ground(iid, cs._instances[iid]["pos"], Vector3(-3.0, 0.0, 0.0)), pair[1], "%s at the edge" % pair[0])
		assert_false(cs._turned_back_at_ground(iid, cs._instances[iid]["pos"], Vector3(3.0, 0.0, 0.0)), "%s walking away is free" % pair[0])
	cs._instances.clear()
	cs.terrain_slice = null
	cs.free()

func _test_claim_zone() -> void:
	var w := _world()
	var c: Vector2 = NewcomerGrounds.centres(SEED)[0]
	var claim := float(NewcomerGrounds.rule()["claimRadiusMetres"])
	assert_true(NewcomerGrounds.in_claim_zone(SEED, c.x, c.y), "the centre is protected")
	assert_true(NewcomerGrounds.in_claim_zone(SEED, c.x + claim - 1.0, c.y), "up to the claim radius")
	assert_false(NewcomerGrounds.in_claim_zone(SEED, c.x + claim + 2.0, c.y), "building elsewhere in the ground is allowed")
	assert_true(NewcomerGrounds.inside(SEED, c.x + claim + 2.0, c.y), "still inside the ground")
	assert_true(w != null, "world built")

func _test_spawn_skips_structures() -> void:
	var w := _world()
	var pid := "walled_in"
	var free: Vector3 = SpawnFinderScript.find_start(SEED, pid, null, w["height_fn"], 0.0, func(_p: Vector2) -> bool: return false)
	assert_eq(free, SpawnFinderScript.find_start(SEED, pid, null, w["height_fn"]), "nothing built: the same spawn as before")
	# A circle over the spawn point: the search goes on to another point.
	var around := func(p: Vector2) -> bool: return p.distance_to(Vector2(free.x, free.z)) < 40.0
	var moved: Vector3 = SpawnFinderScript.find_start(SEED, pid, null, w["height_fn"], 0.0, around)
	assert_true(Vector2(moved.x, moved.z).distance_to(Vector2(free.x, free.z)) >= 40.0, "a point inside a structure circle is skipped")
	assert_true(NewcomerGrounds.inside(SEED, moved.x, moved.z), "and the spawn is still in a ground")
	# Everything outside the protected centre is built over: the spawn falls back to the centre.
	var all_built := func(p: Vector2) -> bool: return not NewcomerGrounds.in_claim_zone(SEED, p.x, p.y)
	var c: Variant = SpawnFinderScript.find_start(SEED, pid, null, w["height_fn"], 0.0, all_built)
	assert_true(c != null, "a spawn is still found")
	assert_true(NewcomerGrounds.in_claim_zone(SEED, c.x, c.z), "on the protected centre, which no structure may hold")

func _test_loose_jitter() -> void:
	var xs := {}
	var zs := {}
	for tx in 200:
		var j := hash([SEED, tx, 0, "loose_xz"])
		xs[posmod(j & 0xFFFF, 300)] = true
		zs[posmod((j >> 16) & 0xFFFF, 300)] = true
	assert_true(xs.size() > 50 and zs.size() > 50, "both offsets vary across tiles (%d, %d)" % [xs.size(), zs.size()])
	var w := _world()
	var c: Vector2 = NewcomerGrounds.centres(SEED)[0]
	var lo := INF
	var hi := -INF
	var ctx := floori(c.x / LooseItemSlice.TILE)
	var ctz := floori(c.y / LooseItemSlice.TILE)
	for dx in 40:
		for dz in 40:
			var it := LooseItemSlice.item_at(SEED, ctx + dx, ctz + dz)
			if not it.is_empty():
				var jz: float = (it["jitter"] as Vector2).y
				lo = minf(lo, jz)
				hi = maxf(hi, jz)
	assert_true(hi - lo > 1.5, "items spread across the tile in z, not one row (%.2f..%.2f)" % [lo, hi])
	assert_true(w != null, "world built")

func _test_pick_rate_and_join() -> void:
	var w := _world()
	var host := _loose(w)
	var client := _loose(w)
	client.is_authoritative = false
	var inv := InventorySlice.new()
	add_child(inv)
	host.inventory_slice = inv
	var now := [5000.0]
	host.clock = func() -> float: return now[0]
	var p: Vector3 = SpawnFinderScript.find_start(SEED, "rate", null, w["height_fn"])
	var items: Array = host.items_near(Vector2(p.x, p.z), 100.0)
	assert_true(items.size() >= 2, "two items near the spawn")
	host.local_position = func() -> Vector3: return Vector3((items[0]["xz"] as Vector2).x, 0.0, (items[0]["xz"] as Vector2).y)
	assert_true(bool(host.pick(str(items[0]["id"]), "")["success"]), "the first pick is taken")
	host.local_position = func() -> Vector3: return Vector3((items[1]["xz"] as Vector2).x, 0.0, (items[1]["xz"] as Vector2).y)
	assert_eq(str(host.pick(str(items[1]["id"]), "")["reason"]), "rate_limited", "a second pick in the same instant is refused")
	now[0] += LooseItemSlice.PICK_COOLDOWN + 0.01
	assert_true(bool(host.pick(str(items[1]["id"]), "")["success"]), "after the cooldown it is taken")
	# A peer that joins later learns both from the snapshot.
	var late := _loose(w)
	late.is_authoritative = false
	late.apply_taken(host.taken_data())
	assert_true(late.is_taken(str(items[0]["id"])) and late.is_taken(str(items[1]["id"])), "a late joiner sees both taken")
	late.apply_taken({ "bad id": 1.0, "1:2": "x", 3: 4.0 })
	assert_eq(late._taken.size(), 0, "malformed entries are dropped")
	host.free()
	client.free()
	late.free()
	inv.free()
