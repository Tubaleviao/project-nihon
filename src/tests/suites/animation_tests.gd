extends "res://src/tests/test_support.gd"
## Phase 156 — idle variants, a swing on every hit, the flinch, and the clips behind them.

const RigTree := preload("res://src/character/rig_tree.gd")
const DeathPush := preload("res://src/battle/death_push.gd")


const Bot := preload("res://src/tests/playtest_bot.gd")

func register() -> void:
	_run_test("animation: camera shake and hit-stop are options, on by default (Phase 287)", _test_hit_feel_options)
	_run_test("animation: a swing while moving plays on the upper body through a bone mask and the feet keep moving (Phase 287)", _test_upper_body_attack)
	_run_test("animation: a creature hit past the stagger share staggers, a light one flinches (Phase 287)", _test_creature_hit_clip_param)
	_run_test("animation: the host deals a player swing at the impact time, and a refused re-check deals nothing (Phase 287)", _test_battle_impact_timing)
	_run_test("animation: a pending hit lands at impact and is cancelled by range, death, stagger or a weapon switch (Phase 287)", _test_pending_hits)
	_run_test("animation: repeated attacks inside the window play the combo variants, a pause restarts, a missing variant falls back (Phase 287)", _test_combo_chain)
	_run_test("gestures: GameData lists every gesture with its clip and chat command", _test_p158_gesture_data)
	_run_test("gestures: every gesture name key is in both catalogs", _test_p158_gesture_catalog)
	_run_test("animation: a creature's hit swings its model and flinches the player", _test_creature_hit_animates_both)
	_run_test("animation: a synced swing animates a peer's avatar", _test_synced_swing_animates_peer)
	_run_test("animation: three hits in one round are three swings", _test_three_hits_three_swings)
	_run_test("animation: the swing follows the main hand and mining uses the tool swing", _test_attack_variant_follows_hand)
	_run_test("animation: the idle variant waits for its seeded delay and never plays while moving", _test_idle_variant)
	_run_test("animation: every rig has idle, hit and an attack, and every clip is visible", _test_rig_clips_present_and_visible)
	_run_test("animation: the walk clip's feet alternate lead within one cycle", _test_walk_clip_feet_alternate)
	_run_test("animation: a rig missing a variant falls back to attack", _test_attack_fallback)
	_run_test("animation: a killing blow does not queue a flinch on a player avatar", _test_kill_no_flinch)
	_run_test("death: the attacker position needs a body and knows the local player's id", _test_death_attacker_pos_guards)
	_run_test("death: the player's death clip goes through the bus intent", _test_player_death_clip_via_bus)


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
	GameBus.combat_hit_synced.emit("p:5", "c:w0", "swing")   # the host announces a player's swing at the click
	assert_eq(int(f["ch"]._instances[peer_iid]["locomotion"].swing_serial), 1, "the peer's avatar swung")
	GameBus.combat_hit_synced.emit("p:5", "c:w0", "hit")
	assert_eq(int(f["ch"]._instances[peer_iid]["locomotion"].swing_serial), 1, "its hit at impact does not swing again")
	assert_eq(int(f["cr"].visuals().models["w0"]["tree"].get_meta("hit_shots", 0)), 1, "and the target flinched")
	assert_eq(int(f["ch"]._instances[f["iid"]]["locomotion"].swing_serial), 0, "the local avatar did not")
	# A host never plays a packet's animation twice: the synced signal only acts on a client.
	f["gr"]._is_client = false
	GameBus.combat_hit_synced.emit("p:5", "c:w0", "swing")
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
	assert_eq(loco.attack_clip, "attack_2h", "a two-handed sword swings two-handed (Phase 287)")
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


## Phase 253 — the playtest walk step no longer fails on the gait, so the clip itself is pinned here: sampled
## across one and a half cycles, the left and right feet each lead (along -Z, the rig's forward) at least once
## and the lead changes hands at least twice.
func _test_walk_clip_feet_alternate() -> void:
	var proot := AssetOverlay.load_rig_scene("models/player_rig.glb.raw")
	add_child(proot)
	var pp := proot.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var skel := proot.find_child("Skeleton3D", true, false) as Skeleton3D
	assert_true(pp != null and skel != null and pp.has_animation("walk"), "the player rig has a skeleton and a walk clip")
	if pp == null or skel == null or not pp.has_animation("walk"):
		proot.queue_free()
		return
	var fl := skel.find_bone("Foot_L")
	var fr := skel.find_bone("Foot_R")
	assert_true(fl >= 0 and fr >= 0, "the rig has both foot bones")
	if fl < 0 or fr < 0:
		proot.queue_free()
		return
	var length := pp.get_animation("walk").length
	pp.play("walk")
	var steps := 30
	var leader := 0
	var switches := 0
	var left_led := false
	var right_led := false
	for i in steps + 1:
		pp.seek(1.5 * length * float(i) / float(steps), true)
		var lead := skel.get_bone_global_pose(fr).origin.z - skel.get_bone_global_pose(fl).origin.z   # forward is -Z
		if absf(lead) < Bot.WALK_FOOT_DEADBAND_M:
			continue
		var side := 1 if lead > 0.0 else -1
		left_led = left_led or side > 0
		right_led = right_led or side < 0
		if leader != 0 and side != leader:
			switches += 1
		leader = side
	assert_true(left_led and right_led, "both feet take the lead during the walk clip")
	assert_true(switches >= 2, "the lead changes hands at least twice in 1.5 cycles (%d)" % switches)
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


func _test_p158_gesture_data() -> void:
	var expected := {
		"Sit": ["sit", "/sit"], "SitGround": ["sit_ground", "/sitground"], "LieDown": ["lie_down", "/lie"],
		"Wave": ["wave", "/wave"], "Point": ["point", "/point"], "Bow": ["bow", "/bow"],
		"Cheer": ["cheer", "/cheer"], "Shrug": ["shrug", "/shrug"], "Clap": ["clap", "/clap"],
		"Kneel": ["kneel", "/kneel"],
	}
	assert_eq(GameData.GESTURES.size(), expected.size(), "ten gestures")
	var seen_cmds := {}
	for id in expected:
		assert_true(GameData.GESTURES.has(id), "%s is listed" % id)
		var g: Resource = GameData.GESTURES[id]
		assert_eq([g.clip, g.chatCommand], expected[id], "%s clip and command" % id)
		assert_false(seen_cmds.has(g.chatCommand), "%s command is unique" % id)
		seen_cmds[g.chatCommand] = true
		assert_true(g.restRegen >= 1.0, "%s restRegen is never below 1" % id)
		assert_true(int(g.kind) in [0, 1], "%s has a known kind" % id)

func _test_p158_gesture_catalog() -> void:
	var cats: Dictionary = I18nScript.parse_csv("res://locale/ui.csv")["catalog"]
	for id in GameData.GESTURES:
		var key: String = GameData.GESTURES[id].nameKey
		assert_true(key != "", "%s has a name key" % id)
		for loc in cats:
			assert_true((cats[loc] as Dictionary).has(key), "%s has %s" % [loc, key])


func _test_kill_no_flinch() -> void:
	var f := _fixture()
	var peer_iid: String = f["ch"].create_character_from_recipe({"skeleton": "HumanoidSkeleton"}, Vector3(3, 0, 0))
	f["ch"].bind_peer_character(5, peer_iid)
	f["gr"]._is_client = true
	var loco = f["ch"]._instances[peer_iid]["locomotion"]
	GameBus.combat_hit_synced.emit("c:w0", "p:5", "hit")
	assert_eq(int(loco.hit_serial), 1, "a plain hit flinches the peer's avatar")
	GameBus.combat_hit_synced.emit("c:w0", "p:5", "kill")
	assert_eq(int(loco.hit_serial), 1, "the killing blow queues no flinch to replay on respawn")
	assert_eq(int(f["cr"].visuals().models["w0"]["swing"]), 2, "the killer still swings")
	_free_fixture(f)


func _test_death_attacker_pos_guards() -> void:
	var f := _fixture()
	var cw = f["gr"]._combat_wiring
	f["gr"]._registry.local_player_id = "local-1"
	assert_true(f["gr"]._player == null, "the fixture has no player body (a dedicated server)")
	assert_true(cw.death_attacker_pos("player") == null, "no body, no position for 'player'")
	assert_true(cw.death_attacker_pos("local-1") == null, "nor for the local player's own id")
	var wolf: Variant = cw.death_attacker_pos("w0")
	assert_true(wolf is Vector3, "a creature attacker resolves to its instance position")
	assert_true(cw.death_attacker_pos("nobody") == null, "an unknown attacker resolves to nothing")
	_free_fixture(f)


func _test_player_death_clip_via_bus() -> void:
	var f := _fixture()
	var cw = f["gr"]._combat_wiring
	var loco = f["ch"]._instances[f["iid"]]["locomotion"]
	var heard: Array = []
	var spy := func(iid: String, clip: String) -> void: heard.append([iid, clip])
	GameBus.character_death_requested.connect(spy)
	# The wolf stands at the origin; the body dies 2 m away along +x.
	var death_pos := Vector3(2, 0, 0)
	var yaw: float = f["ch"].get_character_yaw(f["iid"])
	var expected := DeathPush.variant(death_pos - Vector3.ZERO, yaw)
	assert_eq(cw.death_clip(f["iid"], death_pos, "w0"), expected, "the clip follows killer-to-body against the facing")
	assert_eq(cw.death_clip(f["iid"], death_pos, ""), DeathPush.DEATH_DEFAULT, "no killer, the default clip")
	assert_eq(cw.death_clip("missing", death_pos, "w0"), DeathPush.DEATH_DEFAULT, "no avatar, the default clip")
	GameBus.player_died.emit(death_pos, "w0", Vector3.ZERO)
	GameBus.character_death_requested.disconnect(spy)
	assert_eq(heard, [[f["iid"], expected]], "the death goes out as one bus intent carrying the clip")
	assert_eq(loco.get_state(), Locomotion.State.DEATH, "and the avatar dies")
	assert_eq(loco.death_clip, expected, "playing that clip")
	assert_true(f["ch"].get_character_yaw("missing") == null, "an unknown instance has no yaw")
	_free_fixture(f)


# --- Phase 287: combos -------------------------------------------------------------------------------------------

const ComboChain := preload("res://src/battle/combo_chain.gd")

func _test_combo_chain() -> void:
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid: String = ch.create_character_from_recipe({ "skeleton": "HumanoidSkeleton" }, Vector3.ZERO)
	ch.attach_default_rig(iid)
	assert_true(ch.apply_equipment(iid, "MainHand", "VeilsteelLongsword"), "the longsword equips")
	var played := []
	for t in [0.0, 0.5, 1.0]:
		ch.trigger_attack(iid, "", t)
		played.append(ch._instances[iid]["locomotion"].attack_clip)
	assert_eq(played, ["attack_2h", "attack_2h_2", "attack_2h"], "swings inside the window cycle through the variants and wrap")
	ch.trigger_attack(iid, "", 1.0 + 5.0)
	assert_eq(ch._instances[iid]["locomotion"].attack_clip, "attack_2h", "a pause past the window restarts at the first")
	var steps := []
	var last := ""
	var step := -1
	for t in [0.0, 0.5, 1.0]:
		step = ComboChain.next_step("one_hand", last, step, 0.5 if t > 0.0 else 0.0)
		last = "one_hand"
		steps.append(ComboChain.clip_for("one_hand", step))
	assert_eq(steps, ["attack_1h", "attack_1h_2", "attack_1h_3"], "three one-handed swings inside the window play attack_1h, _2, _3")
	# A rig without a variant plays the base clip.
	assert_eq(ComboChain.clip_for("one_hand", 2, ["attack_1h", "attack"]), "attack_1h", "a missing variant falls back to the base clip")
	assert_eq(ComboChain.clip_for("one_hand", 2, ["attack"]), "attack", "and to attack when the base is missing too")
	# Another weapon class restarts the chain; unarmed and two-handed have their own clips.
	assert_eq(ComboChain.next_step("unarmed", "one_hand", 1, 0.1), 0, "switching weapon class restarts")
	assert_eq(ComboChain.next_step("unarmed", "unarmed", 1, 0.1), 0, "the chain wraps after its last step")
	assert_eq(ComboChain.clip_for("unarmed", 1), "attack_unarmed_2", "unarmed has a second blow")
	assert_eq(ComboChain.clip_for("two_hand", 1), "attack_2h_2", "two-handed has a second blow")
	assert_eq(ComboChain.weapon_class("VeilsteelLongsword", GameData.ITEMS), "two_hand", "the longsword is two-handed")
	assert_eq(ComboChain.weapon_class("FerritePick", GameData.ITEMS), "tool", "a pick is a tool")
	assert_true(ComboChain.damage_multiplier("one_hand", 2) > ComboChain.damage_multiplier("one_hand", 0), "the third blow hits harder")
	assert_true(absf(ComboChain.impact_seconds("one_hand", 0, 0.5) - 0.25) < 1e-6, "impact is a share of the clip length")
	# Every chain clip exists on the public player rig.
	var lengths: Dictionary = ch._instances[iid]["swing_lengths"]
	for w in ["unarmed", "one_hand", "two_hand", "tool"]:
		for clip in ComboChain.chain(w)["clips"]:
			assert_true(lengths.has(clip), "the player rig has %s" % clip)
	ch.free()


const PendingHit := preload("res://src/battle/pending_hit.gd")

func _impact_state(over: Dictionary = {}) -> Callable:
	var base := { "attacker_alive": true, "attacker_staggered": false, "attacker_item": "VeilsteelLongsword", "target_alive": true, "gap": 1.0, "reach": 2.5 }
	base.merge(over, true)
	return func(_entry): return base

func _test_pending_hits() -> void:
	var q := PendingHit.new()
	var e := q.start("a", "w0", "two_hand", "VeilsteelLongsword", 0, 10.0, 0.6)
	assert_true(absf(float(e["due"]) - (10.0 + 0.55 * 0.6)) < 1e-6, "the hit is due at the impact time, not the click")
	assert_eq(q.resolve_due(10.2, _impact_state()).size(), 0, "no damage before the impact time")
	var done := q.resolve_due(10.4, _impact_state())
	assert_true(done.size() == 1 and done[0]["reason"] == "", "the hit lands at impact")
	assert_eq(q.size(), 0, "and leaves the queue")
	# Re-checks at impact, one reason each.
	for case in [["a target that left range", { "gap": 9.0 }, "out_of_range"], ["a target that died", { "target_alive": false }, "target_dead"],
			["an attacker who died", { "attacker_alive": false }, "attacker_dead"], ["an attacker who was staggered", { "attacker_staggered": true }, "attacker_staggered"],
			["a weapon switch", { "attacker_item": "StoneAxe" }, "weapon_switched"]]:
		q.start("a", "w0", "two_hand", "VeilsteelLongsword", 0, 0.0, 0.6)
		var r := q.resolve_due(1.0, _impact_state(case[1]))
		assert_eq(r[0]["reason"], case[2], "%s deals nothing (%s)" % [case[0], case[2]])
	# Another action cancels the pending hit; a new swing replaces it.
	q.start("a", "w0", "two_hand", "VeilsteelLongsword", 0, 0.0, 0.6)
	assert_true(q.cancel("a") and q.resolve_due(5.0, _impact_state()).is_empty(), "a cancelled hit never lands")
	q.start("a", "w0", "two_hand", "VeilsteelLongsword", 0, 0.0, 0.6)
	q.start("a", "w1", "two_hand", "VeilsteelLongsword", 1, 0.5, 0.6)
	assert_eq(q.size(), 1, "a new swing replaces the pending one")
	assert_eq(PendingHit.reaction(30.0, 100.0, 0.25), "stagger", "a hit above the stagger share staggers")
	assert_eq(PendingHit.reaction(10.0, 100.0, 0.25), "hit", "a lighter hit flinches")
	assert_eq(PendingHit.knockback_direction(Vector3(0, 0, 0), Vector3(3, 1, 0)), Vector3(1, 0, 0), "the knock-back points away from the attacker")

const BattleSliceP := preload("res://src/battle/battle_slice.gd")

func _test_battle_impact_timing() -> void:
	var b := BattleSliceP.new()
	add_child(b)
	var clock := [0.0]
	b.now_fn = func(): return clock[0]
	b.impact_queue = PendingHit.new()
	b.impact_info_fn = func(_a): return { "weapon": "one_hand", "item": "X", "step": 0, "clip_length": 0.5 }
	var world := { "alive": true, "target_alive": true, "gap": 1.0 }
	b.impact_state_fn = func(_e): return { "attacker_alive": world["alive"], "attacker_staggered": false, "attacker_item": "X",
		"target_alive": world["target_alive"], "gap": world["gap"], "reach": 3.0 }
	b._hp_state["GraywolfPack"] = 10000.0
	var hits := []
	var cb := func(a, d, outcome, _dmg): hits.append([a, d, outcome])
	GameBus.combat_hit_resolved.connect(cb)
	GameBus.combat_round_requested.emit("player", "GraywolfPack")
	assert_eq(hits.size(), 0, "nothing is dealt at the click")
	clock[0] = 0.1
	assert_eq(b.tick_impacts(), 0, "nor before the impact time")
	clock[0] = 0.3
	assert_eq(b.tick_impacts(), 1, "the hit lands at impact")
	assert_eq(hits.size(), 1, "and one hit is announced")
	# A target that left range before impact takes nothing and nothing is synced.
	clock[0] = 1.0
	GameBus.combat_round_requested.emit("player", "GraywolfPack")
	world["gap"] = 9.0
	clock[0] = 1.5
	assert_eq(b.tick_impacts(), 0, "a target out of range at impact takes no damage")
	assert_eq(hits.size(), 1, "and no hit sync is sent")
	# A second click while a swing is in flight neither pushes its impact back nor starts another swing.
	world["gap"] = 1.0
	clock[0] = 2.0
	var started := [0]
	b.swing_started_fn = func(_a, _d): started[0] += 1
	GameBus.combat_round_requested.emit("player", "GraywolfPack")
	clock[0] = 2.2
	GameBus.combat_round_requested.emit("player", "GraywolfPack")
	assert_eq(started[0], 1, "a click during a swing in flight starts no second swing")
	clock[0] = 2.4
	assert_eq(b.tick_impacts(), 1, "so the first swing lands at its own impact time")
	# An attacker staggered (immobilised) at impact deals nothing.
	b.impact_state_fn = func(_e): return { "attacker_alive": true, "attacker_staggered": true, "attacker_item": "X",
		"target_alive": true, "gap": 1.0, "reach": 3.0 }
	clock[0] = 3.0
	GameBus.combat_round_requested.emit("player", "GraywolfPack")
	clock[0] = 3.5
	assert_eq(b.tick_impacts(), 0, "a staggered attacker's hit is cancelled")
	GameBus.combat_hit_resolved.disconnect(cb)
	b.free()

func _test_creature_hit_clip_param() -> void:
	var f := _fixture()
	f["gr"]._battle = BattleSliceP.new()
	add_child(f["gr"]._battle)
	assert_true(f["gr"]._combat_wiring.reaction_for("GraywolfPack", 1.0) == "hit", "a light hit on a creature is a hit")
	assert_true(f["gr"]._combat_wiring.reaction_for("GraywolfPack", 1000.0) == "stagger", "a heavy hit on a creature staggers it")
	f["gr"]._battle.free()
	f["gr"]._battle = null
	_free_fixture(f)

func _test_upper_body_attack() -> void:
	var root := AssetOverlay.load_rig_scene("models/player_rig.glb.raw")
	var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	RigTree.prepare_library(player)
	var tree := RigTree.build_tree(player)
	root.add_child(tree)
	var loco_tree: AnimationNodeBlendTree = tree.get_meta("loco_tree")
	assert_true(loco_tree.has_node(RigTree.UPPER_NODE), "the rig has an upper-body attack node")
	var shot := loco_tree.get_node(RigTree.UPPER_NODE) as AnimationNodeOneShot
	assert_true(shot.filter_enabled, "the node is filtered (a bone mask)")
	var paths := RigTree.upper_body_paths(player)
	assert_true(not paths.is_empty(), "the mask names the upper-body bones")
	for p in paths:
		assert_true(shot.is_path_filtered(p), "%s is masked in" % p)
		assert_false(str(p).ends_with(":Leg_L") or str(p).ends_with(":Shin_L") or str(p).ends_with(":Foot_L"), "no leg bone is masked in")
	var loco := Locomotion.new()
	loco.update(3.0, true, 0.0, 0.1)
	loco.trigger_attack("attack_1h", 0.5)
	assert_true(loco.get_state() == Locomotion.State.ATTACK and loco.get_speed() > RigTree.UPPER_ATTACK_MIN_SPEED, "a swing while running keeps its speed")
	assert_true(RigTree.swing_on_upper_body(tree, loco), "it plays on the upper body")
	RigTree.drive_shots(tree, null, loco)
	assert_eq(int(tree.get_meta("upper_shots", 0)), 1, "the upper-body one-shot fired")
	var still := Locomotion.new()
	still.trigger_attack("attack_1h", 0.5)
	assert_false(RigTree.swing_on_upper_body(tree, still), "a standing swing keeps its own state")
	# The node is latched when the swing starts: stopping mid-swing keeps the swing on the upper body.
	var moving_then_stopped := Locomotion.new()
	moving_then_stopped.update(3.0, true, 0.0, 0.1)
	moving_then_stopped.trigger_attack("attack_1h", 0.5)
	RigTree.drive_shots(tree, null, moving_then_stopped)
	assert_true(bool(tree.get_meta("swing_upper", false)), "a swing begun while moving is latched upper-body")
	root.free()

const HitFeel := preload("res://src/battle/hit_feel.gd")
const GameSettings := preload("res://src/core/game_settings.gd")

func _test_hit_feel_options() -> void:
	assert_true(GameSettings.SPEC.has("camera_shake") and GameSettings.SPEC.has("hit_stop"), "both switches are options")
	assert_true(GameSettings.SPEC["camera_shake"]["default"] and GameSettings.SPEC["hit_stop"]["default"], "on by default")
	var cam := Camera3D.new()
	add_child(cam)
	var before: bool = GameSettings.get_value("camera_shake")
	GameSettings.set_value("camera_shake", true, null, false)
	assert_true(HitFeel.shake(cam), "a landed hit shakes the camera")
	GameSettings.set_value("camera_shake", false, null, false)
	assert_false(HitFeel.shake(cam), "and not with the option off")
	GameSettings.set_value("camera_shake", before, null, false)
	cam.free()
	assert_false(HitFeel.hit_stop(null), "no tree, no hit-stop")
