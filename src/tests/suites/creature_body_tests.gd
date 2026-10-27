extends "res://src/tests/test_support.gd"
## Phase 192 — creatures collide with each other and with players, and their models squash on contact.

const CreatureBody := preload("res://src/creature/creature_body.gd")

## A voxel stand-in: the column top of tile (x, z) is `fn(x, z)`.
class FakeVoxel extends Node:
	var fn: Callable
	func get_voxel_height_at(xz: Vector2) -> float:
		return float(fn.call(floori(xz.x), floori(xz.y)))

func register() -> void:
	_run_test("body: fabric gives every creature a footprint and a squash in range", _test_body_fabric_fields)
	_run_test("body: an overlapping pair is pushed apart evenly, a far or stacked pair is not", _test_body_pair_push)
	_run_test("body: two creatures on one spot fan out until they only touch", _test_body_creatures_separate)
	_run_test("body: a creature in a player is moved out and the player is not", _test_body_player_push_out)
	_run_test("body: a push never carries a ground creature up a ledge", _test_body_ledge_blocks_push)
	_run_test("body: a contact reports its direction and depth", _test_body_contact)
	_run_test("body: squash keeps volume and presses along the contact", _test_body_squash_basis)
	_run_test("body: the squash spring presses in, rebounds and settles", _test_body_spring)

## A slice and an AI with `count` ForestBoars all at `at` (no surface unless `voxel` is given).
func _make_pack(count: int, at: Vector3, voxel: Node = null) -> Dictionary:
	var c := CreatureSlice.new()
	if voxel != null:
		c.voxel_slice = voxel
	add_child(c)
	var ai := CreatureAI.new()
	ai.creature_slice = c
	add_child(ai)
	var ids: Array = []
	for i in count:
		var iid: String = c._spawn("ForestBoar", Vector2i(0, 0), i)
		c.set_instance_position(iid, at)
		ids.append(iid)
	return {"creature": c, "ai": ai, "ids": ids}

func _free_pack(p: Dictionary) -> void:
	p["ai"].free()
	p["creature"].free()

func _test_body_fabric_fields() -> void:
	for key in GameData.CREATURES:
		var res: Resource = GameData.CREATURES[key]
		var r: Variant = res.get("bodyRadiusMetres")
		var s: Variant = res.get("squash")
		assert_true(r != null and float(r) >= 0.2 and float(r) <= CreatureBody.MAX_RADIUS, "%s has a footprint in range" % key)
		assert_true(s != null and float(s) >= 0.0 and float(s) <= 0.5, "%s has a squash in range" % key)
	assert_true(CreatureBody.squash_of("LavaSlug") > CreatureBody.squash_of("CinderGargoyle"), "a slug gives more than a stone gargoyle")

func _test_body_pair_push() -> void:
	var push := CreatureBody.pair_push(Vector3(0.5, 0, 0), 0.5, Vector3(-0.5, 0, 0), 0.5)
	assert_true(push == Vector3.ZERO, "footprints that just touch are not pushed")
	push = CreatureBody.pair_push(Vector3(0.2, 0, 0), 0.5, Vector3(-0.2, 0, 0), 0.5)
	assert_true(absf(push.x - 0.6 * CreatureBody.RELAX) < 1e-4 and absf(push.z) < 1e-6, "an overlap of 0.6 m pushes RELAX of it along the line between them (got %s)" % push)
	push = CreatureBody.pair_push(Vector3(0, 3.0, 0), 0.5, Vector3.ZERO, 0.5)
	assert_true(push == Vector3.ZERO, "a flyer over a walker does not touch it")
	var a := CreatureBody.pair_push(Vector3.ZERO, 0.5, Vector3.ZERO, 0.5, "a|b")
	var b := CreatureBody.pair_push(Vector3.ZERO, 0.5, Vector3.ZERO, 0.5, "a|b")
	assert_true(a.length() > 0.0 and a == b, "coincident bodies split along a seeded direction, the same every time")

func _test_body_creatures_separate() -> void:
	var p := _make_pack(3, Vector3(4.0, 0.0, 4.0))
	var c: CreatureSlice = p["creature"]
	var ai: CreatureAI = p["ai"]
	var reach := 2.0 * CreatureBody.radius_of("ForestBoar")
	for i in 40:
		ai.separate_bodies(c.instances_view(), {})
	var closest := INF
	var ids: Array = p["ids"]
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var d := c.get_instance_position(ids[i]).distance_to(c.get_instance_position(ids[j]))
			closest = minf(closest, d)
	assert_true(closest >= reach * 0.95, "the closest pair ends at least 95%% of a body apart (%.3f of %.3f)" % [closest, reach])
	assert_true(closest <= reach * 1.5, "and they only spread to touching, not scattered (%.3f)" % closest)
	_free_pack(p)

func _test_body_player_push_out() -> void:
	var player := Vector3(4.0, 0.0, 4.0)
	var p := _make_pack(1, player + Vector3(0.1, 0.0, 0.0))
	var c: CreatureSlice = p["creature"]
	var ai: CreatureAI = p["ai"]
	var iid: String = p["ids"][0]
	var targets := {"player": player}
	for i in 20:
		ai.separate_bodies(c.instances_view(), targets)
	var d := c.get_instance_position(iid).distance_to(player)
	var reach := CreatureBody.radius_of("ForestBoar") + CreatureBody.PLAYER_RADIUS
	assert_true(d >= reach - 1e-3, "the creature stands clear of the player (%.3f of %.3f)" % [d, reach])
	assert_true(c.get_instance_position(iid).x > player.x, "pushed away on the side it stood")
	assert_eq(targets["player"], player, "the player is not moved")
	# Through the AI tick: a creature chasing the player ends against it, not inside it.
	ai.player_targets = func() -> Dictionary: return targets
	ai.force_state(iid, "aggressive")
	for i in 30:
		ai._process(0.1)
	d = c.get_instance_position(iid).distance_to(player)
	assert_true(d >= reach * 0.9, "a chasing creature presses against the player but stays out (%.3f)" % d)
	_free_pack(p)

func _test_body_ledge_blocks_push() -> void:
	# A 3 m wall at x >= 5: the pair stands at its foot, one pushed toward it.
	var v := FakeVoxel.new()
	v.fn = func(x: int, _z: int) -> float: return 3.0 if x >= 5 else 0.0
	add_child(v)
	var p := _make_pack(2, Vector3(4.6, 0.0, 0.5), v)
	var c: CreatureSlice = p["creature"]
	var ai: CreatureAI = p["ai"]
	var ids: Array = p["ids"]
	c.set_instance_position(ids[1], Vector3(4.3, 0.0, 0.5))
	for i in 20:
		ai.separate_bodies(c.instances_view(), {})
	for iid in ids:
		var pos := c.get_instance_position(iid)
		assert_true(pos.x < 5.0 and absf(pos.y) < 1e-3, "%s stays below the ledge (%s)" % [iid, pos])
	assert_true(c.get_instance_position(ids[1]).x < 4.3, "the one with room still moves away")
	_free_pack(p)
	v.free()

func _test_body_contact() -> void:
	var none := CreatureBody.contact(Vector3.ZERO, 0.5, [[Vector3(5, 0, 0), 0.5]])
	assert_eq(float(none["depth"]), 0.0, "nothing near: no contact")
	var touch := CreatureBody.contact(Vector3.ZERO, 0.5, [[Vector3(1.0, 0, 0), 0.5], [Vector3(0, 0, -0.6), 0.5]])
	assert_true(float(touch["depth"]) > 0.0, "a neighbour within reach is a contact")
	assert_true((touch["dir"] as Vector3).is_equal_approx(Vector3(0, 0, -1)), "the deepest contact wins and points at it (%s)" % touch["dir"])
	var full := CreatureBody.contact(Vector3.ZERO, 0.5, [[Vector3(0.3, 0, 0), 0.5]])
	assert_eq(float(full["depth"]), 1.0, "a deep overlap saturates at 1")

func _test_body_squash_basis() -> void:
	assert_true(CreatureBody.squash_basis(Vector3.RIGHT, 0.0).is_equal_approx(Basis()), "no squash: identity")
	var dir := Vector3(1, 0, 1).normalized()
	var b := CreatureBody.squash_basis(dir, 0.3)
	assert_true(absf((b * dir).length() - 0.7) < 1e-4, "the contact axis shrinks by the squash")
	assert_true(absf(b.determinant() - 1.0) < 1e-4, "volume is kept (det %.5f)" % b.determinant())
	assert_true((b * Vector3.UP).y > 1.0, "the body bulges upward")
	var side := dir.cross(Vector3.UP)
	assert_true(absf((b * side).dot(dir)) < 1e-4, "the sideways axis is not sheared into the contact")

func _test_body_spring() -> void:
	var s := Vector2.ZERO
	for i in 30:
		s = CreatureBody.spring_step(s, 0.2, 1.0 / 60.0)
	assert_true(absf(s.x - 0.2) < 0.05, "held in contact, the squash reaches its target (%.3f)" % s.x)
	var lowest := s.x
	for i in 120:
		s = CreatureBody.spring_step(s, 0.0, 1.0 / 60.0)
		lowest = minf(lowest, s.x)
	assert_true(lowest < 0.0, "released, it overshoots into a stretch (%.3f)" % lowest)
	assert_true(absf(s.x) < 0.01, "and settles back to rest (%.4f)" % s.x)
	var big := CreatureBody.spring_step(Vector2.ZERO, 0.3, 2.0)
	assert_true(absf(big.x) <= 0.6, "a long frame does not blow the spring up")
