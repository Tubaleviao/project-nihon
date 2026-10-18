extends "res://src/tests/test_support.gd"
## Phase 156 — idle variants, a swing on every hit, the flinch, and the clips behind them.

const RigTree := preload("res://src/character/rig_tree.gd")


func register() -> void:
	_run_test("animation: a creature's hit swings its model and flinches the player", _test_creature_hit_animates_both)
	_run_test("animation: a synced swing animates a peer's avatar", _test_synced_swing_animates_peer)
	_run_test("animation: three hits in one round are three swings", _test_three_hits_three_swings)
	_run_test("animation: the swing follows the main hand and mining uses the tool swing", _test_attack_variant_follows_hand)
	_run_test("animation: the idle variant waits for its seeded delay and never plays while moving", _test_idle_variant)
	_run_test("animation: every rig has idle, hit and an attack, and every clip is visible", _test_rig_clips_present_and_visible)
	_run_test("animation: a rig missing a variant falls back to attack", _test_attack_fallback)


## A host-shaped GameRoot with the slices the combat wiring touches, plus the player avatar with a rig.
func _fixture() -> Dictionary:
	var gr: Node = (load("res://src/core/game_root.gd") as GDScript).new()
	var ch := CharacterSlice.new()
	add_child(ch)
	gr._character = ch
	gr._registry = PlayerRegistry.new()
	var iid := ch.create_character_from_recipe({"skeleton": "HumanoidSkeleton"}, Vector3.ZERO)
	assert_true(ch.attach_rig(iid, "models/player_rig.glb.raw"), "the player rig attaches")
	ch.set_player_character(iid)
	var cr := CreatureSlice.new()
	add_child(cr)
	cr.apply_creature_state("w0", "GraywolfPack", "aggressive", Vector3.ZERO, 10.0)
	cr.visuals().attach("w0", cr._instances["w0"])
	gr._creature = cr
	gr._combat_wiring.wire(gr)
	return {"gr": gr, "ch": ch, "cr": cr, "iid": iid}


func _free_fixture(f: Dictionary) -> void:
	f["gr"]._combat_wiring.unwire()
	f["ch"].free()
	f["cr"].free()
	f["gr"]._registry.free()
	f["gr"].free()


func _test_creature_hit_animates_both() -> void:
	var f := _fixture()
	var tree: AnimationTree = f["ch"]._instances[f["iid"]]["anim_tree"]
	var models: Dictionary = f["cr"].visuals().models
	assert_true(models.has("w0"), "the wolf has a model")
	GameBus.player_damaged.emit(6.0, "w0", "player")
	GameBus.combat_hit_resolved.emit("w0", "player", "hit", 6.0)
	assert_eq(int(models["w0"]["swing"]), 1, "the wolf's model swung once")
	assert_eq(int(f["ch"]._instances[f["iid"]]["locomotion"].hit_serial), 1, "the player flinched once, not twice")
	RigTree.drive(tree, f["ch"]._instances[f["iid"]]["locomotion"])
	assert_eq(int(tree.get_meta("hit_shots", 0)), 1, "the player rig fired its hit one-shot")
	# A hit on the wolf flinches its model.
	GameBus.combat_hit_resolved.emit("player", "w0", "hit", 6.0)
	assert_eq(int(models["w0"]["tree"].get_meta("hit_shots", 0)), 1, "the wolf's model fired its hit one-shot")
	# A miss swings but does not flinch.
	GameBus.combat_hit_resolved.emit("player", "w0", "miss", 0.0)
	assert_eq(int(models["w0"]["tree"].get_meta("hit_shots", 0)), 1, "a miss does not flinch")
	assert_eq(int(f["ch"]._instances[f["iid"]]["locomotion"].swing_serial), 2, "both of the player's swings played")
	_free_fixture(f)


func _test_synced_swing_animates_peer() -> void:
	var f := _fixture()
	f["gr"]._is_client = true
	var peer_iid: String = f["ch"].create_character_from_recipe({"skeleton": "HumanoidSkeleton"}, Vector3(3, 0, 0))
	f["ch"].bind_peer_character(5, peer_iid)
	GameBus.combat_hit_synced.emit("p:5", "c:w0", "hit")
	assert_eq(int(f["ch"]._instances[peer_iid]["locomotion"].swing_serial), 1, "the peer's avatar swung")
	assert_eq(int(f["cr"].visuals().models["w0"]["tree"].get_meta("hit_shots", 0)), 1, "and the target flinched")
	assert_eq(int(f["ch"]._instances[f["iid"]]["locomotion"].swing_serial), 0, "the local avatar did not")
	# A host never plays a packet's animation twice: the synced signal only acts on a client.
	f["gr"]._is_client = false
	GameBus.combat_hit_synced.emit("p:5", "c:w0", "hit")
	assert_eq(int(f["ch"]._instances[peer_iid]["locomotion"].swing_serial), 1, "a host ignores the synced signal")
	_free_fixture(f)


func _test_three_hits_three_swings() -> void:
	var f := _fixture()
	var loco = f["ch"]._instances[f["iid"]]["locomotion"]
	for i in 3:
		GameBus.combat_hit_resolved.emit("player", "w0", "hit", 4.0)
	assert_eq(loco.swing_serial, 3, "three hits in one round, three swings")
	# Each swing after the first restarts the clip that is already playing.
	var tree: AnimationTree = f["ch"]._instances[f["iid"]]["anim_tree"]
	var fake := _FakePlayback.new()
	tree.set_meta("travel_node", "Attack")
	RigTree.drive_shots(tree, fake, loco)
	assert_eq(fake.started, ["Attack"], "a swing while attacking restarts the clip")
	GameBus.combat_hit_resolved.emit("player", "w0", "hit", 4.0)
	RigTree.drive_shots(tree, fake, loco)
	assert_eq(fake.started.size(), 2, "the next one restarts it again")
	RigTree.drive_shots(tree, fake, loco)
	assert_eq(fake.started.size(), 2, "a drive with no new swing restarts nothing")
	_free_fixture(f)


class _FakePlayback extends RefCounted:
	var started: Array = []
	func start(node: String) -> void:
		started.append(node)


func _test_attack_variant_follows_hand() -> void:
	assert_eq(RigTree.attack_clip_for("", GameData.ITEMS), "attack_unarmed", "empty hands punch")
	assert_eq(RigTree.attack_clip_for("VeilsteelLongsword", GameData.ITEMS), "attack_1h", "a sword swings one-handed")
	assert_eq(RigTree.attack_clip_for("FerritePick", GameData.ITEMS), "attack_tool", "a pick swings the tool swing")
	var f := _fixture()
	var loco = f["ch"]._instances[f["iid"]]["locomotion"]
	f["ch"].trigger_attack(f["iid"])
	assert_eq(loco.attack_clip, "attack_unarmed", "an unarmed avatar punches")
	assert_eq(loco.get_state(), Locomotion.State.ATTACK, "and is attacking")
	loco.reset()
	assert_true(f["ch"].apply_equipment(f["iid"], "MainHand", "VeilsteelLongsword"), "the sword equips")
	f["ch"].trigger_attack(f["iid"])
	assert_eq(loco.attack_clip, "attack_1h", "a sword-bearer swings one-handed")
	loco.reset()
	GameBus.block_mine_requested.emit(Vector3.ZERO, Vector3.UP, "", {})
	assert_eq(loco.attack_clip, "attack_tool", "mining a block plays the tool swing")
	assert_eq(loco.swing_serial, 3, "and counts as a swing")
	# A remote player's mining is not this player's swing.
	GameBus.block_mine_requested.emit(Vector3.ZERO, Vector3.UP, "someone-else", {})
	assert_eq(loco.swing_serial, 3, "another player's mining does not swing this avatar")
	_free_fixture(f)


func _test_idle_variant() -> void:
	var a := Locomotion.new()
	var b := Locomotion.new()
	a.seed_idle(77)
	b.seed_idle(77)
	assert_eq(a.idle_delay, b.idle_delay, "the same seed draws the same delay")
	assert_true(a.idle_delay >= Locomotion.IDLE_DELAY_MIN and a.idle_delay <= Locomotion.IDLE_DELAY_MAX, "the delay is 6-12 s")
	var delay := a.idle_delay
	a.update(0.0, true, 0.0, delay - 0.1)
	assert_eq(a.idle_serial, 0, "no variant before the delay")
	a.update(0.0, true, 0.0, 0.2)
	assert_eq(a.idle_serial, 1, "the variant plays once the delay has passed")
	assert_true(a.idle_clip in Locomotion.IDLE_VARIANTS, "and it is one of the variants (%s)" % a.idle_clip)
	b.update(0.0, true, 0.0, delay + 0.1)
	assert_eq(b.idle_clip, a.idle_clip, "the same seed picks the same variant")
	# Never while moving, however long.
	var mover := Locomotion.new()
	mover.seed_idle(77)
	for i in 600:
		mover.update(2.0, true, 0.0, 0.1)
	assert_eq(mover.idle_serial, 0, "a walking body never plays an idle variant")
	# Standing time restarts when the body moves.
	var c := Locomotion.new()
	c.seed_idle(77)
	c.update(0.0, true, 0.0, c.idle_delay - 0.5)
	c.update(2.0, true, 0.0, 0.1)
	c.update(0.0, true, 0.0, 1.0)
	assert_eq(c.idle_serial, 0, "a step resets the standing time")
	# The rig fires its one-shot, and cuts it short when the body moves.
	var f := _fixture()
	var inst: Dictionary = f["ch"]._instances[f["iid"]]
	var loco = inst["locomotion"]
	loco.update(0.0, true, 0.0, loco.idle_delay + 0.1)
	RigTree.drive(inst["anim_tree"], loco)
	assert_eq(int(inst["anim_tree"].get_meta("idle_shots", 0)), 1, "the rig fired the idle variant")
	_free_fixture(f)


func _angle_between(a: Quaternion, b: Quaternion) -> float:
	return rad_to_deg(a.angle_to(b))


## Largest rotation of any joint in `anim`, in degrees from the joint's rest pose in `skeleton`.
func _peak_degrees(anim: Animation, skeleton: Skeleton3D) -> float:
	var peak := 0.0
	for t in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := skeleton.find_bone(str(anim.track_get_path(t)).get_slice(":", 1))
		if bone < 0:
			continue
		var rest := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
		for k in anim.track_get_key_count(t):
			peak = maxf(peak, _angle_between(rest, anim.track_get_key_value(t, k)))
	return peak


func _test_rig_clips_present_and_visible() -> void:
	var rigs := 0
	var meshes: Dictionary = AssetOverlay.manifest().get("meshes", {})
	var keys: Array = ["models/player_rig.glb.raw"]
	for k in meshes:
		if str(k).begins_with("models/creatures/") and str(k).ends_with(".glb.raw"):
			keys.append(str(k))
	for key in keys:
		var root := AssetOverlay.load_rig_scene(key)
		assert_true(root != null, "%s loads" % key)
		if root == null:
			continue
		var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
		assert_true(player.has_animation("idle"), "%s has idle" % key)
		assert_true(player.has_animation("hit"), "%s has hit" % key)
		var attacks := 0
		for clip in player.get_animation_list():
			attacks += 1 if str(clip).begins_with("attack") else 0
			var peak := _peak_degrees(player.get_animation(clip), root.find_children("*", "Skeleton3D", true, false)[0])
			assert_true(peak >= 10.0, "%s: %s peaks at %.1f degrees (needs 10)" % [key, clip, peak])
			var listed: bool = str(clip) in RigTree.LOOPING_CLIPS or str(clip) in RigTree.ONE_SHOT_CLIPS
			assert_true(listed, "%s: %s is in the loop table" % [key, clip])
		assert_true(attacks >= 1, "%s has an attack clip" % key)
		rigs += 1
		root.free()
	assert_true(rigs >= 2, "the player rig and the creature models were checked (%d)" % rigs)
	# The player has every variant.
	var proot := AssetOverlay.load_rig_scene("models/player_rig.glb.raw")
	var pp := proot.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for clip in ["attack", "attack_unarmed", "attack_1h", "attack_tool", "hit", "stagger", "idle_look", "idle_stretch"]:
		assert_true(pp.has_animation(clip), "the player rig has %s" % clip)
	proot.free()


func _test_attack_fallback() -> void:
	# The wolf has no `attack_1h`: the Attack node falls back to `attack`.
	var root := AssetOverlay.load_rig_scene("models/creatures/GraywolfPack.glb.raw")
	var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	RigTree.prepare_library(player)
	var tree := RigTree.build_tree(player)
	assert_eq(RigTree.set_attack_clip(tree, "attack_1h"), "attack", "a missing variant plays attack")
	assert_eq(RigTree.set_attack_clip(tree, "attack"), "attack", "attack plays attack")
	assert_true(RigTree.fire_hit(tree), "the wolf rig has a hit one-shot")
	var bare := _player_without_hit()
	var bare_tree := RigTree.build_tree(bare)
	assert_false(RigTree.fire_hit(bare_tree), "a rig without hit has no flinch node")
	bare_tree.free()
	bare.free()
	tree.free()
	root.free()


func _player_without_hit() -> AnimationPlayer:
	var p := AnimationPlayer.new()
	var lib := AnimationLibrary.new()
	for clip in ["idle", "walk", "run", "fall", "land", "attack", "death"]:
		lib.add_animation(clip, Animation.new())
	p.add_animation_library("", lib)
	return p
