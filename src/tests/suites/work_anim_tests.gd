extends "res://src/tests/test_support.gd"
## Phase 281 — work you can see: the fabric clip table, the five placeholder clips and the wiring that plays them.

const RigTree := preload("res://src/character/rig_tree.gd")
const WorkAnim := preload("res://src/character/work_anim.gd")
const WorkAnimWiring := preload("res://src/character/work_anim_wiring.gd")

const KINDS := ["chop", "mine", "dig", "dissect", "build"]

func register() -> void:
	_run_test("work anim: the fabric table names a clip and a mode for every kind", _test_p281_table)
	_run_test("work anim: a rig without the clip falls back to attack_tool", _test_p281_fallback)
	_run_test("work anim: the five placeholder clips differ from each other and from attack_tool", _test_p281_clips_differ)
	_run_test("work anim: holds play their clip, release stops it, a placed block plays build once", _test_p281_wiring)
	_run_test("work anim: one strike per cycle at the impact marker", _test_p281_strike_timing)
	_run_test("work anim: the body turns to face the work target", _test_p281_face_target)
	_run_test("work anim: another peer's work plays on its copy", _test_p281_peer_copy)


func _fixture() -> Dictionary:
	var gr: Node = (load("res://src/core/game_root.gd") as GDScript).new()
	var ch := CharacterSlice.new()
	add_child(ch)
	gr._character = ch
	gr._registry = PlayerRegistry.new()
	var iid := ch.create_character_from_recipe({"skeleton": "HumanoidSkeleton"}, Vector3.ZERO)
	assert_true(ch.attach_rig(iid, "models/player_rig.glb.raw"), "the player rig attaches")
	ch.set_player_character(iid)
	gr._combat_wiring.wire(gr)
	gr._work_anim_wiring.wire(gr)
	return {"gr": gr, "ch": ch, "iid": iid, "w": gr._work_anim_wiring, "loco": ch._instances[iid]["locomotion"]}

func _free_fixture(f: Dictionary) -> void:
	f["gr"]._work_anim_wiring.unwire()
	f["gr"]._combat_wiring.unwire()
	f["ch"].free()
	f["gr"]._registry.free()
	f["gr"].free()

func _test_p281_table() -> void:
	for k in KINDS:
		assert_true(WorkAnim.has_kind(k), "%s has a row" % k)
		assert_eq(WorkAnim.clip_of(k), k, "%s plays its own clip" % k)
	for k in ["chop", "mine", "dig", "dissect"]:
		assert_true(WorkAnim.is_loop(k), "%s is a hold and loops" % k)
	assert_eq(WorkAnim.mode_of("build"), "once", "a placed block plays once")
	assert_eq(WorkAnim.clip_of("dismantle"), "build", "dismantling plays build until art splits it")
	assert_true(absf(WorkAnim.impact_time("chop", 1.0) - 0.4) < 0.001, "the strike lands at 40% of the clip")

func _test_p281_fallback() -> void:
	assert_eq(WorkAnim.resolve("chop", {"chop": 0.7}), "chop", "a rig with the clip plays it")
	assert_eq(WorkAnim.resolve("chop", {"attack_tool": 0.5}), "attack_tool", "a rig without it plays attack_tool")
	assert_eq(WorkAnim.resolve("nonsense", {"chop": 0.7}), "attack_tool", "an unknown kind plays attack_tool")

func _hand_track(player: AnimationPlayer, skel: Skeleton3D, clip: String, samples: int) -> Array:
	var hand := skel.find_bone("Hand_R")
	var out: Array = []
	player.play(clip)
	var length := player.get_animation(clip).length
	for i in samples + 1:
		player.seek(length * float(i) / float(samples), true)
		out.append(skel.get_bone_global_pose(hand).origin)
	return out

func _test_p281_clips_differ() -> void:
	var proot := AssetOverlay.load_rig_scene("models/player_rig.glb.raw")
	add_child(proot)
	var pp := proot.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var skel := proot.find_child("Skeleton3D", true, false) as Skeleton3D
	assert_true(pp != null and skel != null, "the rig has a player and a skeleton")
	if pp == null or skel == null:
		proot.queue_free()
		return
	var names := KINDS + ["attack_tool"]
	var tracks := {}
	for n in names:
		assert_true(pp.has_animation(n), "the player rig has %s" % n)
		tracks[n] = _hand_track(pp, skel, n, 12)
	for i in names.size():
		for j in range(i + 1, names.size()):
			var best := 0.0
			for s in 13:
				best = maxf(best, (tracks[names[i]][s] as Vector3).distance_to(tracks[names[j]][s]))
			assert_true(best > 0.10, "%s and %s differ by more than 10 cm at some sample (%.2f m)" % [names[i], names[j], best])
	# The body lowers through the Root bone's translation track (the same channel the kneel gesture uses).
	var root_bone := skel.find_bone("Root")
	var rest_y := skel.get_bone_rest(root_bone).origin.y
	pp.play("dissect")
	pp.seek(pp.get_animation("dissect").length * 0.5, true)
	var low_y := skel.get_bone_pose_position(root_bone).y
	assert_true(rest_y - low_y >= 0.30, "dissect lowers the hips by at least 30 cm (%.2f)" % (rest_y - low_y))
	proot.queue_free()

func _test_p281_wiring() -> void:
	var f := _fixture()
	var w = f["w"]
	var loco = f["loco"]
	for k in ["chop", "mine", "dig"]:
		GameBus.work_started.emit("k", 1.0, k, "")
		assert_eq(loco.attack_clip, k, "a %s hold plays %s" % [k, k])
		assert_true(w.is_working(1), "%s loops" % k)
		GameBus.work_cancel_requested.emit("")
		assert_false(w.is_working(1), "releasing the %s hold stops the loop" % k)
		assert_true(loco.get_state() != Locomotion.State.ATTACK, "and the body leaves the work pose")
	GameBus.harvest_started.emit("", "c1", 4.0)
	assert_eq(loco.attack_clip, "dissect", "a carcass hold plays dissect")
	assert_true(w.is_working(1), "the dissect loops")
	GameBus.harvest_resolved.emit("", "c1", "", [])
	assert_false(w.is_working(1), "a resolved harvest stops the dissect loop")
	GameBus.block_place_requested.emit(Vector3.ZERO, Vector3.UP, "", "Soil", {})
	assert_eq(loco.attack_clip, "build", "placing a block plays build")
	assert_false(w._active[1]["loop"], "and plays once")
	_free_fixture(f)

func _test_p281_strike_timing() -> void:
	var f := _fixture()
	var w = f["w"]
	GameBus.work_started.emit("k", 1.0, "chop", "")
	var length: float = w._active[1]["length"]
	var impact := WorkAnim.impact_time("chop", length)
	w.tick(impact * 0.9)
	assert_eq(int(w.strikes.get(1, 0)), 0, "no strike before the marker")
	w.tick(impact * 0.2)
	assert_eq(int(w.strikes.get(1, 0)), 1, "one strike at the marker")
	w.tick(0.01)
	assert_eq(int(w.strikes.get(1, 0)), 1, "and only one in that cycle")
	w.tick(length)
	w.tick(impact + 0.01)
	assert_eq(int(w.strikes.get(1, 0)), 2, "the next cycle strikes again")
	_free_fixture(f)

func _test_p281_peer_copy() -> void:
	var f := _fixture()
	var gr: Node = f["gr"]
	var peer_iid: String = f["ch"].create_character_from_recipe({"skeleton": "HumanoidSkeleton"}, Vector3.ZERO)
	f["ch"].attach_rig(peer_iid, "models/player_rig.glb.raw")
	gr._registry.set_meta("x", 1)
	var w = f["w"]
	var seen := [""]
	var cb := func(peer: int, kind: String) -> void: seen[0] = "%d:%s" % [peer, kind]
	GameBus.work_anim_changed.connect(cb)
	GameBus.work_anim_changed.emit(7, "chop")
	assert_eq(seen[0], "7:chop", "the change is a bus signal other systems can read")
	GameBus.work_anim_changed.disconnect(cb)
	assert_false(w.is_working(7), "an unknown peer draws no copy and plays nothing")
	f["ch"].free_character(peer_iid) if f["ch"].has_method("free_character") else null
	_free_fixture(f)

func _test_p281_face_target() -> void:
	var f := _fixture()
	GameBus.work_start_requested.emit("block", "", Vector3(5.0, 0.0, 0.0), Vector3.UP, {}, "")
	GameBus.work_started.emit("k", 1.0, "dig", "")
	var yaw: float = f["ch"].get_character_yaw(f["iid"])
	assert_true(absf(yaw - atan2(-5.0, 0.0)) < 0.01, "a block to the east turns the face (-Z) east (yaw %.2f)" % yaw)
	_free_fixture(f)
