extends "res://src/tests/test_support.gd"
## Phase 143 — rigged creature models: the fabric skeleton field, the public models, the range swap
## with hysteresis, the model cap, the missing-model fallback, the state-to-clip map and the headless
## path.

const CreatureVisuals := preload("res://src/creature/creature_visuals.gd")


func register() -> void:
	_run_test("creature model: every creature names a defined skeleton", _test_model_fabric_skeleton)
	_run_test("creature model: each public model parses with its family's bones and seven clips", _test_model_public_models)
	_run_test("creature model: range swap with hysteresis", _test_model_range_hysteresis)
	_run_test("creature model: a missing model keeps the box and warns once per type", _test_model_missing_key)
	_run_test("creature model: the clip map covers every state and death holds", _test_model_clip_map)
	_run_test("creature model: MAX_MODELS goes to the nearest", _test_model_max_models)
	_run_test("creature model: no model nodes without render_visuals", _test_model_headless)
	_run_test("creature model: a model faces its movement and follows despawn", _test_model_facing_and_despawn)


## Stands in for the MultiMesh pool, which a headless rendering server does not read back: it
## records whether each instance is hidden or placed.
class FakePool extends Node:
	var hidden: Dictionary = {}
	var _next := 0
	func alloc() -> int:
		_next += 1
		return _next - 1
	func release(idx: int) -> void:
		hidden[idx] = true
	func set_transform(idx: int, _t: Transform3D) -> void:
		hidden[idx] = false
	func set_color(_idx: int, _c: Color) -> void:
		pass
	func hide(idx: int) -> void:
		hidden[idx] = true
	func shift_scene(_shift: Vector3) -> void:
		pass


## A client-mode slice in the tree (model layer built, pool swapped for a FakePool) whose creatures
## the test places exactly. The fake pool is a child of the slice, so freeing the slice frees it.
func _model_slice() -> CreatureSlice:
	var c := CreatureSlice.new()
	c.is_authoritative = false
	add_child(c)
	var fake := FakePool.new()
	fake.name = "FakePool"
	c.add_child(fake)
	c._pool = fake
	return c


## Whether the instance's box is hidden in the slice's FakePool.
func _box_hidden(c: CreatureSlice, iid: String) -> bool:
	return bool((c._pool as FakePool).hidden.get(int(c._instances[iid]["mi"]), false))


func _place(c: CreatureSlice, iid: String, cid: String, pos: Vector3, state: String = "idle") -> void:
	c.apply_creature_state(iid, cid, state, pos)


func _model_names(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		out.append(str(child.name))
	return out


func _test_model_fabric_skeleton() -> void:
	for cid in GameData.CREATURES:
		var res: Resource = GameData.CREATURES[cid]
		var skeleton: Variant = res.get("skeleton")
		assert_true(skeleton is String and skeleton != "", "%s names a skeleton" % cid)
		assert_true(GameData.SKELETONS.has(str(skeleton)), "%s skeleton %s is a fabric skeleton" % [cid, skeleton])


func _test_model_public_models() -> void:
	for cid in GameData.CREATURES:
		var family := str((GameData.CREATURES[cid] as Resource).get("skeleton"))
		var root := AssetOverlay.load_rig_scene(AssetOverlayScript.creature_model_key(cid))
		assert_true(root != null, "%s public model parses" % cid)
		if root == null:
			continue
		var skeletons := root.find_children("*", "Skeleton3D", true, false)
		assert_eq(skeletons.size(), 1, "%s has one Skeleton3D" % cid)
		if skeletons.size() == 1:
			var skeleton: Skeleton3D = skeletons[0]
			var bones: Array = GameDataReader.json_field(GameData.SKELETONS[family], "bones", [])
			assert_eq(skeleton.get_bone_count(), bones.size(), "%s: one bone per %s bone" % [cid, family])
			for b in bones:
				var idx := skeleton.find_bone(str(b["name"]))
				assert_true(idx >= 0, "%s bone %s is in the rig" % [cid, b["name"]])
				if idx >= 0:
					var parent := skeleton.get_bone_parent(idx)
					assert_eq(skeleton.get_bone_name(parent) if parent >= 0 else "", str(b["parent"]),
						"%s bone %s has its fabric parent" % [cid, b["name"]])
		var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
		assert_true(player != null, "%s has an AnimationPlayer" % cid)
		if player != null:
			for clip in CreatureVisuals.CLIPS:
				assert_true(player.has_animation(clip), "%s has clip %s" % [cid, clip])
		root.free()


func _test_model_range_hysteresis() -> void:
	var c := _model_slice()
	var viewer := Vector3(100.0, 0.0, 100.0)
	var r := CreatureVisuals.MODEL_RANGE_M
	var h := CreatureVisuals.MODEL_HYSTERESIS_M
	_place(c, "near", "ForestBoar", viewer + Vector3(r - 1.0, 0.0, 0.0))
	_place(c, "far", "ForestBoar", viewer + Vector3(r + 1.0, 0.0, 0.0))
	c.update_models(viewer, 0.1)
	assert_true(c.has_model("near"), "a creature inside the range has a model")
	assert_true(bool(c._instances["near"].get("modeled", false)), "its record is marked modelled")
	assert_true(_box_hidden(c, "near"), "and its pool instance is hidden")
	assert_false(c.has_model("far"), "a creature outside the range has no model")
	assert_false(_box_hidden(c, "far"), "and keeps its pool instance")
	# Into the hysteresis band: the near one keeps its model, the far one stays a box.
	_place(c, "near", "ForestBoar", viewer + Vector3(r + h * 0.5, 0.0, 0.0))
	_place(c, "far", "ForestBoar", viewer + Vector3(r + h * 0.5, 0.0, 0.0))
	c.update_models(viewer, 0.1)
	assert_true(c.has_model("near"), "inside the band a modelled creature keeps its model")
	assert_false(c.has_model("far"), "inside the band a box stays a box")
	assert_true(_box_hidden(c, "near"), "a moving modelled creature keeps its box hidden")
	# Past the band the model goes and the box comes back.
	_place(c, "near", "ForestBoar", viewer + Vector3(r + h + 1.0, 0.0, 0.0))
	c.update_models(viewer, 0.1)
	assert_false(c.has_model("near"), "past the band the model is released")
	assert_false(_box_hidden(c, "near"), "and the pool instance is back")
	assert_eq(c.visuals().model_count(), 0, "no model left")
	assert_eq(c.visuals().get_child_count(), 0, "no model node left")
	c.free()


func _test_model_missing_key() -> void:
	var c := _model_slice()
	var viewer := Vector3.ZERO
	var before := Diag.warn_count()
	_place(c, "a", "NoSuchCreature", Vector3(2.0, 0.0, 0.0))
	_place(c, "b", "NoSuchCreature", Vector3(3.0, 0.0, 0.0))
	c.update_models(viewer, 0.1)
	c.update_models(viewer, 0.1)
	assert_false(c.has_model("a") or c.has_model("b"), "a creature with no model key has no model")
	assert_false(_box_hidden(c, "a"), "it renders through the pool")
	assert_eq(Diag.warn_count() - before, 1, "the missing model warns once for the type")
	c.free()


func _test_model_clip_map() -> void:
	for cid in GameData.CREATURES:
		var script: Script = (GameData.CREATURES[cid] as Resource).get_script()
		var states: Dictionary = script.get_script_constant_map().get("State", {})
		assert_true(states.size() > 0, "%s has a state enum" % cid)
		for s in states:
			var state := str(s).to_lower()
			assert_true(CreatureVisuals.STATE_CLIPS.has(state), "%s state %s has clips" % [cid, state])
			for speed in [0.0, 1.0, 5.0]:
				assert_true(CreatureVisuals.clip_for(state, speed) in CreatureVisuals.CLIPS,
					"%s %s at %.0f m/s plays a rig clip" % [cid, state, speed])
	assert_eq(CreatureVisuals.clip_for("dead", 0.0), "death", "a dead creature plays death")
	assert_eq(CreatureVisuals.clip_for("dead", 5.0), "death", "even while its body slides")
	assert_eq(CreatureVisuals.clip_for("idle", 0.0), "idle", "still idle")
	assert_eq(CreatureVisuals.clip_for("idle", 1.0), "walk", "wandering walks")
	assert_eq(CreatureVisuals.clip_for("idle", 5.0), "run", "fast wandering runs")
	assert_eq(CreatureVisuals.clip_for("aggressive", 0.0), "attack", "a still attacker attacks")
	assert_eq(CreatureVisuals.clip_for("aggressive", 5.0), "run", "a chasing attacker runs")
	assert_eq(CreatureVisuals.clip_for("fleeing", 5.0), "run", "fleeing runs")
	# On a live model: death does not loop and stays the clip after the creature dies.
	var c := _model_slice()
	_place(c, "w", "GraywolfPack", Vector3(1.0, 0.0, 0.0))
	c.update_models(Vector3.ZERO, 0.1)
	assert_true(c.has_model("w"), "the wolf has a model")
	assert_eq(c.visuals().model_clip("w"), "idle", "an idle wolf plays idle")
	_place(c, "w", "GraywolfPack", Vector3(1.0, 0.0, 0.0), "dead")
	c.update_models(Vector3.ZERO, 0.1)
	c.update_models(Vector3.ZERO, 0.1)
	assert_true(c.has_model("w"), "a creature that dies in view keeps its model")
	assert_eq(c.visuals().model_clip("w"), "death", "and plays death")
	var player := c.visuals().model_node("w").find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_eq(player.get_animation("death").loop_mode, Animation.LOOP_NONE, "death does not loop")
	assert_eq(player.get_animation("idle").loop_mode, Animation.LOOP_LINEAR, "idle loops")
	assert_eq(str(player.current_animation), "death", "the player is on the death clip")
	# A creature already dead when it comes into range gets no model.
	_place(c, "corpse", "GraywolfPack", Vector3(2.0, 0.0, 0.0), "dead")
	c.update_models(Vector3.ZERO, 0.1)
	assert_false(c.has_model("corpse"), "a creature dead before it came into range stays a hidden box")
	c.free()


func _test_model_max_models() -> void:
	var c := _model_slice()
	var n := CreatureVisuals.MAX_MODELS + 6
	for i in n:
		_place(c, "c%02d" % i, "ForestBoar", Vector3(1.0 + float(i), 0.0, 0.0))
	c.update_models(Vector3.ZERO, 0.1)
	assert_eq(c.visuals().model_count(), CreatureVisuals.MAX_MODELS, "the model count stops at MAX_MODELS")
	for i in n:
		assert_eq(c.has_model("c%02d" % i), i < CreatureVisuals.MAX_MODELS,
			"creature %d %s a model" % [i, "has" if i < CreatureVisuals.MAX_MODELS else "has no"])
	# A nearer creature arrives: it takes the farthest model's place.
	_place(c, "close", "ForestBoar", Vector3(0.5, 0.0, 0.0))
	c.update_models(Vector3.ZERO, 0.1)
	assert_true(c.has_model("close"), "the nearest creature gets a model")
	assert_false(c.has_model("c%02d" % (CreatureVisuals.MAX_MODELS - 1)), "the farthest modelled one gives it up")
	assert_eq(c.visuals().model_count(), CreatureVisuals.MAX_MODELS, "still capped")
	c.free()


func _test_model_headless() -> void:
	var c := CreatureSlice.new()
	c.render_visuals = false
	c.is_authoritative = false
	add_child(c)
	_place(c, "w", "GraywolfPack", Vector3(1.0, 0.0, 0.0))
	c.update_models(Vector3.ZERO, 0.1)
	assert_true(c.visuals() == null, "no model layer without render_visuals")
	assert_false(c.has_model("w"), "no model")
	assert_eq(c.get_child_count(), 0, "the slice builds no visual nodes")
	c.free()


func _test_model_facing_and_despawn() -> void:
	# The basis turns the rig's -Z forward onto the movement direction.
	for dir in [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, -1).normalized(), Vector3(0.3, 0, -0.9).normalized()]:
		var fwd: Vector3 = CreatureVisuals.facing_basis(dir) * CreatureVisuals.MODEL_FORWARD
		assert_true(fwd.is_equal_approx(dir), "forward %s follows %s" % [fwd, dir])
	var c := CreatureSlice.new()
	add_child(c)
	c.spawn_for_chunk(Vector2i(0, 0))
	var view := c.get_all_instances()
	assert_true(view.size() > 0, "chunk 0 spawns creatures")
	if view.size() == 0:
		c.free()
		return
	var iid: String = view[0]["instance_id"]
	var start: Vector3 = view[0]["position"]
	c.update_models(start, 0.1)
	assert_true(c.has_model(iid), "a spawned creature beside the viewer has a model")
	c.set_instance_position(iid, start + Vector3(0.0, 0.0, 1.0))
	c.update_models(start, 1.0)
	var node := c.visuals().model_node(iid)
	assert_true((node.basis * CreatureVisuals.MODEL_FORWARD).is_equal_approx(Vector3(0, 0, 1)), "the model faces where it walked")
	assert_true(node.position.is_equal_approx(start + Vector3(0.0, 0.0, 1.0)), "the model stands at the record position")
	assert_eq(c.visuals().model_clip(iid), "walk", "1 m/s is a walk")
	c.despawn_for_chunk(Vector2i(0, 0))
	assert_false(c.has_model(iid), "a despawned creature's model is freed")
	assert_eq(c.visuals().get_child_count(), 0, "no model node outlives its creature")
	c.free()
