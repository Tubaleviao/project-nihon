extends "res://src/tests/test_support.gd"
## Phase 157 — the death push, the clip variants and a body that lies on the ground.

const DeathPush := preload("res://src/battle/death_push.gd")
const RigTree := preload("res://src/character/rig_tree.gd")
const CreatureVisuals := preload("res://src/creature/creature_visuals.gd")


func register() -> void:
	_run_test("death: a killing blow throws the body away from the killer, short of a wall", _test_push_direction_and_wall)
	_run_test("death: the battle slice decides the landing and the creature takes it", _test_battle_landing_is_host_value)
	_run_test("death: no client-reported landing exists to trust", _test_landing_is_host_only)
	_run_test("death: a body lands on the ground below it, a bigger attacker throws further, no instance no push", _test_landing_ground_size_unresolved)
	_run_test("death: the clip follows the hit direction", _test_variant_by_direction)
	_run_test("death: every rig has the variants and ends lying on the ground", _test_rigs_end_grounded)
	_run_test("death: a creature model falls to its landing and plays the variant", _test_visuals_fall_and_variant)
	_run_test("death: the corpse lifetime is the fabric's corpseSeconds, else the constant", _test_corpse_lifetime)


func _flat_ground(_p: Vector3) -> bool:
	return true


func _test_push_direction_and_wall() -> void:
	var pos := Vector3(10.0, 2.0, 5.0)
	# A killer to the west, so the body lands east.
	for dmg in [1.0, 10.0, 100.0]:
		var spot := DeathPush.landing(pos, Vector3(5.0, 2.0, 5.0), dmg, 50.0, 1.0, Callable(self, "_flat_ground"))
		var d := spot.x - pos.x
		assert_true(d >= 0.5 and d <= 1.5, "damage %s lands %.2f m east (needs 0.5..1.5)" % [dmg, d])
		assert_true(absf(spot.z - pos.z) <= 0.001, "the push stays on the killer's line")
	assert_true(DeathPush.distance(50.0, 50.0, 2.0) <= DeathPush.MAX_PUSH_M, "a big attacker never throws past the cap")
	assert_true(DeathPush.distance(0.0, 50.0, 0.5) >= DeathPush.MIN_PUSH_M, "a tiny hit still moves the body")
	# A wall 0.7 m east: the body stops short of it, never inside.
	var wall := func(p: Vector3) -> bool: return p.x < pos.x + 0.7
	var short := DeathPush.landing(pos, Vector3(5.0, 2.0, 5.0), 50.0, 50.0, 1.0, wall)
	assert_true(short.x > pos.x and short.x < pos.x + 0.7, "the body lands short of the wall (x=%.2f)" % short.x)
	var blocked := DeathPush.landing(pos, Vector3(5.0, 2.0, 5.0), 50.0, 50.0, 1.0, func(_p: Vector3) -> bool: return false)
	assert_eq(blocked, pos, "a body against a wall stays put")
	assert_eq(DeathPush.landing(pos, pos, 50.0, 50.0, 1.0, Callable()), pos, "a killer on top pushes nothing")


func _test_battle_landing_is_host_value() -> void:
	var cr := CreatureSlice.new()
	add_child(cr)
	cr.apply_creature_state("w0", "GraywolfPack", "aggressive", Vector3(10.0, 0.0, 0.0), 10.0)
	var b := BattleSlice.new()
	add_child(b)
	b.creature_slice = cr
	b.attacker_pos_fn = func(_id: String) -> Variant: return Vector3(5.0, 0.0, 0.0)
	b.walkable_fn = Callable(self, "_flat_ground")
	var seen := {}
	var on_died := func(id: String, pos: Vector3, _killer: String, landing: Vector3) -> void:
		seen["id"] = id
		seen["pos"] = pos
		seen["landing"] = landing
	GameBus.creature_died.connect(on_died)
	b._hp_state["w0"] = 0.01
	seed(7)
	for _i in range(200):
		b.resolve_round("player", "w0")
		if seen.has("id"):
			break
	GameBus.creature_died.disconnect(on_died)
	assert_true(seen.has("id"), "the creature died")
	var landing: Vector3 = seen.get("landing", Vector3.ZERO)
	var d := landing.x - 10.0
	assert_true(d >= 0.5 and d <= 1.5, "it lands %.2f m east of where it stood" % d)
	assert_eq(cr.get_instance_position("w0"), landing, "the creature's authoritative position is the landing")
	b.free()
	cr.free()


func _test_landing_ground_size_unresolved() -> void:
	var b := BattleSlice.new()
	add_child(b)
	b.attacker_pos_fn = func(_id: String) -> Variant: return Vector3(5.0, 3.0, 0.0)
	b.walkable_fn = Callable(self, "_flat_ground")
	b.ground_fn = func(_p: Vector3) -> float: return 1.0
	var spot := b.death_landing(Vector3(10.0, 3.0, 0.0), "player", 5.0, 10.0)
	assert_true(spot != Vector3.ZERO, "the body is thrown")
	assert_eq(spot.y, 1.0, "downhill, it rests on the lower ground rather than hovering at its old height")
	var near := b.death_landing(Vector3(10.0, 3.0, 0.0), "player", 1.0, 100.0, 1.0).x - 10.0
	var far := b.death_landing(Vector3(10.0, 3.0, 0.0), "player", 1.0, 100.0, 2.0).x - 10.0
	assert_true(far > near, "a bigger attacker throws further (%.2f > %.2f)" % [far, near])
	assert_eq(b.size_ratio("no_such_attacker", 50.0), 1.0, "an unknown attacker reads as even")
	# A dying creature with no resolved instance is not thrown from the world origin.
	var seen := {}
	var on_died := func(_id: String, _pos: Vector3, _killer: String, landing: Vector3) -> void:
		seen["landing"] = landing
	GameBus.creature_died.connect(on_died)
	b._hp_state["ghost"] = 0.01
	seed(3)
	for _i in range(200):
		b.resolve_round("player", "ghost")
		if seen.has("landing"):
			break
	GameBus.creature_died.disconnect(on_died)
	assert_eq(seen.get("landing", Vector3.ONE), Vector3.ZERO, "no instance, no push")
	b.free()


func _test_landing_is_host_only() -> void:
	# No request a client can send carries a landing: the combat request is attacker and defender only.
	var args := 0
	for sig in GameBus.get_signal_list():
		if sig["name"] == "combat_round_requested":
			args = (sig["args"] as Array).size()
	assert_eq(args, 2, "combat_round_requested has no landing argument")
	# Without the host's wiring (a client), a kill pushes nothing.
	var b := BattleSlice.new()
	add_child(b)
	assert_eq(b.death_landing(Vector3(1, 0, 1), "player", 10.0, 10.0), Vector3.ZERO, "no host wiring, no push")
	b.free()
	# A creature_died with no landing leaves the body where the creature stood.
	var cr := CreatureSlice.new()
	add_child(cr)
	cr.apply_creature_state("w0", "GraywolfPack", "aggressive", Vector3(3.0, 0.0, 3.0), 10.0)
	GameBus.creature_died.emit("w0", Vector3(3.0, 0.0, 3.0), "player", Vector3.ZERO)
	assert_eq(cr.get_instance_position("w0"), Vector3(3.0, 0.0, 3.0), "a zero landing moves nothing")
	cr.free()


func _test_variant_by_direction() -> void:
	# The body faces -Z (yaw 0). A killer behind it (+Z) hits along -Z: it falls on its face.
	assert_eq(DeathPush.variant(Vector3(0, 0, -1), 0.0), "death_forward", "from behind: forward")
	assert_eq(DeathPush.variant(Vector3(0, 0, 1), 0.0), "death_back", "from the front: back")
	assert_eq(DeathPush.variant(Vector3(1, 0, 0), 0.0), "death_side", "from the side: side")
	assert_eq(DeathPush.variant(Vector3(-1, 0, 0), 0.0), "death_side", "from the other side: side")
	# Turned a quarter: the same world direction reads differently.
	assert_eq(DeathPush.variant(Vector3(0, 0, -1), PI / 2.0), "death_side", "facing changes the variant")
	assert_eq(DeathPush.variant(Vector3.ZERO, 0.0), "death", "no direction, plain death")


## Lowest bone height (m) with every bone of `skeleton` posed at the last key of `anim`.
func _lowest_bone_at_end(anim: Animation, skeleton: Skeleton3D) -> float:
	skeleton.reset_bone_poses()
	for t in anim.get_track_count():
		var bone := skeleton.find_bone(str(anim.track_get_path(t)).get_slice(":", 1))
		if bone < 0 or anim.track_get_key_count(t) == 0:
			continue
		var last := anim.track_get_key_count(t) - 1
		match anim.track_get_type(t):
			Animation.TYPE_ROTATION_3D:
				skeleton.set_bone_pose_rotation(bone, anim.track_get_key_value(t, last))
			Animation.TYPE_POSITION_3D:
				skeleton.set_bone_pose_position(bone, anim.track_get_key_value(t, last))
	var lowest := INF
	for i in skeleton.get_bone_count():
		lowest = minf(lowest, skeleton.get_bone_global_pose(i).origin.y)
	return lowest


func _test_rigs_end_grounded() -> void:
	var meshes: Dictionary = AssetOverlay.manifest().get("meshes", {})
	var keys: Array = ["models/player_rig.glb.raw"]
	for k in meshes:
		if str(k).begins_with("models/creatures/") and str(k).ends_with(".glb.raw"):
			keys.append(str(k))
	var checked := 0
	for key in keys:
		var root := AssetOverlay.load_rig_scene(key)
		if root == null:
			assert_true(false, "%s loads" % key)
			continue
		var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var skeleton := root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		for clip in ["death", "death_back", "death_forward", "death_side"]:
			assert_true(player.has_animation(clip), "%s has %s" % [key, clip])
			if not player.has_animation(clip):
				continue
			var low := _lowest_bone_at_end(player.get_animation(clip), skeleton)
			assert_true(absf(low) <= 0.05, "%s: %s ends %.3f m from the ground (needs 0.05)" % [key, clip, low])
			checked += 1
		root.free()
	assert_true(checked >= 8, "the death clips of the player and the creatures were checked (%d)" % checked)


func _test_visuals_fall_and_variant() -> void:
	var cr := CreatureSlice.new()
	add_child(cr)
	cr.apply_creature_state("w0", "GraywolfPack", "aggressive", Vector3(10.0, 0.0, 0.0), 10.0)
	var vis := cr.visuals()
	assert_true(vis.attach("w0", cr._instances["w0"]), "the wolf has a model")
	vis._update_model("w0", cr._instances["w0"], 0.016)
	var m: Dictionary = vis.models["w0"]
	# Killed from the east side of a model that faces -Z: the host moved the body 1 m east... of a
	# model at x=10, so it travels along +X, a side hit.
	cr._instances["w0"]["state"] = "dead"
	cr._instances["w0"]["position"] = Vector3(11.0, 0.0, 0.0)
	vis._update_model("w0", cr._instances["w0"], 0.016)
	assert_eq(str(m["tree"].get_meta("death_clip", "")), "death_side", "a sideways throw plays death_side")
	var node: Node3D = m["node"]
	assert_true(node.position.x < 11.0 and node.position.x >= 10.0, "mid-fall the body is between start and landing")
	assert_true(node.position.y > 0.0, "and above the ground on the arc")
	vis._update_model("w0", cr._instances["w0"], 1.0)
	assert_true(absf(node.position.x - 11.0) <= 0.001, "after the fall it lies at the landing")
	assert_true(absf(node.position.y - 0.0) <= 0.001, "on the ground")
	cr.free()


func _test_corpse_lifetime() -> void:
	assert_eq(CreatureVisuals.corpse_seconds("GraywolfPack"), float(GameData.CREATURES["GraywolfPack"].get("corpseSeconds")), "the fabric value (Phase 160)")
	assert_eq(CreatureVisuals.corpse_seconds("NoSuchBeast"), CreatureVisuals.CORPSE_SECONDS, "unknown type, the constant")
