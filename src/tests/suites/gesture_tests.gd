extends "res://src/tests/test_support.gd"
## Phase 159 — gestures at runtime: the host's rules, the cancel rules, rest regeneration, the rig and the chat commands.

const RigTree := preload("res://src/character/rig_tree.gd")
const GestureRules := preload("res://src/character/gesture_rules.gd")
const GestureSlice := preload("res://src/character/gesture_slice.gd")
const GesturePanel := preload("res://src/ui/gesture_panel.gd")
const LocaleSettings := preload("res://src/core/locale_settings.gd")


func register() -> void:
	_run_test("gesture: /sit plays sit on the rig, moving ends it and the body returns to locomotion", _test_sit_then_move)
	_run_test("gesture: a Sit with no seat in front sits on the ground", _test_sit_without_seat)
	_run_test("gesture: the host refuses an unknown id, a dead player, the rate limit and a stranger's cancel", _test_host_refusals)
	_run_test("gesture: damage cancels LieDown and leaves a Wave alone, as the fabric says", _test_damage_cancel)
	_run_test("gesture: death cancels every pose and a one-shot replaces a pose", _test_death_and_replace)
	_run_test("gesture: regeneration while Sit is held is the base rate times restRegen", _test_rest_regen)
	_run_test("gesture: a pose for a peer waits for its avatar and a late joiner sees it seated", _test_peer_pose_waits_for_avatar)
	_run_test("gesture: a repeated one-shot replays on a remote avatar, and a remote gesture advances and settles", _test_remote_oneshot_repeats)
	_run_test("gesture: a swing ends a held pose", _test_action_cancels)
	_run_test("gesture: seat lift moves the root when a pose starts or ends in place", _test_lift_settles)
	_run_test("gesture: a viewer entering range of a held pose is replayed it once, and again after leaving", _test_new_pairs)
	_run_test("gesture: every gesture has a clip on the placeholder player rig, listed in the loop table", _test_every_gesture_has_a_clip)
	_run_test("gesture: locomotion holds a pose, ends a one-shot, and the Gesture node stands up in 0.3 s", _test_locomotion_and_tree)
	_run_test("gesture: chat commands come from the fabric and never travel as chat", _test_chat_commands)
	_run_test("gesture: the wheel key defaults to Q, rebinds to a free key and refuses a claimed one", _test_wheel_key)
	_run_test("gesture: seat height is read from the target and only a seat-height edge counts", _test_seat_lift)


## A host-shaped GameRoot with the gesture slice and wiring plus the player avatar on its rig.
func _fixture() -> Dictionary:
	var gr: Node = (load("res://src/core/game_root.gd") as GDScript).new()
	var ch := CharacterSlice.new()
	add_child(ch)
	gr._character = ch
	gr._registry = PlayerRegistry.new()
	gr._registry.local_player_id = "p1"
	var iid := ch.create_character_from_recipe({"skeleton": "HumanoidSkeleton"}, Vector3.ZERO)
	assert_true(ch.attach_rig(iid, "models/player_rig.glb.raw"), "the player rig attaches")
	ch.set_player_character(iid)
	var sl := GestureSlice.new()
	var now := [0.0]
	sl.clock = func() -> float: return now[0]
	add_child(sl)
	gr._gesture = sl
	gr._gesture_wiring.wire(gr)
	return {"gr": gr, "ch": ch, "iid": iid, "sl": sl, "now": now}


func _free_fixture(f: Dictionary) -> void:
	f["gr"]._gesture_wiring.unwire()
	f["sl"].free()
	f["ch"].free()
	f["gr"]._registry.free()
	f["gr"].free()


func _loco(f: Dictionary):
	return f["ch"]._instances[f["iid"]]["locomotion"]


func _test_sit_then_move() -> void:
	var f := _fixture()
	f["gr"]._gesture_wiring.seat_probe = func(_iid: String) -> float: return 0.45
	var id := ChatCommands.gesture_id("/sit")
	assert_eq(id, "Sit", "/sit names the Sit gesture")
	assert_eq(f["sl"].request("p1", id, true, true, Vector3.ZERO), "", "the host accepts it")
	assert_eq(f["ch"]._m2.gesture_clip_of(f["iid"]), "sit", "the rig plays sit")
	assert_true(_loco(f).is_gesture_held(), "and holds the pose")
	assert_eq(float(f["ch"]._instances[f["iid"]]["seat_lift"]), 0.45, "the body rides the seat height")
	var tree: AnimationTree = f["ch"]._instances[f["iid"]]["anim_tree"]
	RigTree.drive(tree, _loco(f))
	assert_eq(tree.get_meta("gesture_clip", ""), "sit", "the Gesture node points at the sit clip")
	assert_eq(tree.get_meta("travel_node", ""), "Gesture", "and the tree travels to it")
	# A step of 0.2 m is not leaving; a movement intent is.
	f["sl"].note_position("p1", Vector3(0.2, 0, 0))
	assert_eq(f["sl"].held_id("p1"), "Sit", "a small shuffle keeps the pose")
	f["sl"].note_position("p1", Vector3(2.0, 0, 0))
	assert_eq(f["sl"].held_id("p1"), "", "moving cancels it on the host")
	assert_false(_loco(f).is_gesturing(), "and the avatar stands up")
	assert_eq(float(f["ch"]._instances[f["iid"]]["seat_lift"]), 0.0, "off the seat")
	RigTree.drive(tree, _loco(f))
	assert_eq(tree.get_meta("travel_node", ""), "Locomotion", "back in the locomotion tree")
	_free_fixture(f)


func _test_sit_without_seat() -> void:
	var f := _fixture()
	f["gr"]._gesture_wiring.seat_probe = func(_iid: String) -> float: return -1.0
	f["sl"].request("p1", "Sit", true, true, Vector3.ZERO)
	assert_eq(f["ch"]._m2.gesture_clip_of(f["iid"]), "sit_ground", "no seat in front: the ground sit plays")
	assert_eq(float(f["ch"]._instances[f["iid"]]["seat_lift"]), 0.0, "and the body stays on the ground")
	_free_fixture(f)


func _test_host_refusals() -> void:
	var f := _fixture()
	var sl: GestureSlice = f["sl"]
	assert_eq(sl.request("p1", "Dance", true, true, Vector3.ZERO), GestureSlice.REFUSE_UNKNOWN, "an unknown id is refused")
	assert_eq(sl.request("p1", "x".repeat(200), true, true, Vector3.ZERO), GestureSlice.REFUSE_UNKNOWN, "an oversize id is refused")
	assert_eq(sl.request("p1", "Wave", false, true, Vector3.ZERO), GestureSlice.REFUSE_DEAD, "a dead player cannot gesture")
	assert_eq(sl.request("p1", "Sit", true, false, Vector3.ZERO), GestureSlice.REFUSE_AIRBORNE, "a pose that needs ground is refused in the air")
	assert_false(_loco(f).is_gesturing(), "none of those played")
	# The bucket: a burst, then refusals, then a refill with time.
	f["now"][0] += 10.0
	var accepted := 0
	for i in 8:
		if sl.request("p1", "Wave", true, true, Vector3.ZERO) == "":
			accepted += 1
	assert_eq(accepted, int(GestureRules.RATE_CAPACITY), "only the burst gets through")
	assert_true(sl.rate_refused >= 5, "the rest are counted as rate-refused")
	f["now"][0] += 2.5
	assert_eq(sl.request("p1", "Wave", true, true, Vector3.ZERO), "", "time refills the bucket")
	# Another player's bucket is their own.
	assert_eq(sl.request("p2", "Wave", true, true, Vector3.ZERO), "", "a second player is not throttled by the first")
	# A cancel names the connection's own player: p2 standing up leaves p1's pose.
	f["now"][0] += 10.0
	sl.request("p1", "SitGround", true, true, Vector3.ZERO)
	sl.request("p2", "", true, true, Vector3.ZERO)
	assert_eq(sl.held_id("p1"), "SitGround", "a client cannot cancel another player's pose")
	sl.request("p1", "", true, true, Vector3.ZERO)
	assert_eq(sl.held_id("p1"), "", "but its own, yes")
	_free_fixture(f)


func _test_damage_cancel() -> void:
	var f := _fixture()
	var sl: GestureSlice = f["sl"]
	for id in GameData.GESTURES:
		var res: Resource = GameData.GESTURES[id]
		if not GestureRules.is_pose(res):
			continue
		f["now"][0] += 10.0
		sl.request("p1", id, true, true, Vector3.ZERO)
		sl.note_damage("p1")
		var cancels := GestureRules.flag(res, "cancelOnDamage")
		assert_eq(sl.held_id("p1") == "", cancels, "%s: damage cancels it exactly when the fabric says so" % id)
		sl.cancel("p1")
	# LieDown is the fabric's damage-cancelled pose; a Wave is a one-shot damage never ends.
	assert_true(GestureRules.flag(GameData.GESTURES["LieDown"], "cancelOnDamage"), "LieDown cancels on damage")
	var ends := [0]
	var on_synced := func(_p: String, g: String) -> void:
		if g == "":
			ends[0] += 1
	GameBus.gesture_synced.connect(on_synced)
	f["now"][0] += 10.0
	sl.request("p1", "Wave", true, true, Vector3.ZERO)
	sl.note_damage("p1")
	GameBus.gesture_synced.disconnect(on_synced)
	assert_eq(ends[0], 0, "damage ends no Wave")
	assert_true(_loco(f).is_gesturing(), "the Wave keeps playing")
	f["now"][0] += 10.0
	sl.request("p1", "LieDown", true, true, Vector3.ZERO)
	GameBus.player_damaged.emit(3.0, "w0", "player")
	assert_false(_loco(f).is_gesturing(), "a damage event through the bus stood the lying player up")
	_free_fixture(f)


func _test_death_and_replace() -> void:
	var f := _fixture()
	var sl: GestureSlice = f["sl"]
	sl.request("p1", "Sit", true, true, Vector3.ZERO)
	sl.request("p1", "Wave", true, true, Vector3.ZERO)
	assert_eq(sl.held_id("p1"), "", "a one-shot replaces a held pose")
	sl.request("p1", "Kneel", true, true, Vector3.ZERO)
	assert_eq(sl.held_id("p1"), "Kneel", "a pose is held")
	GameBus.player_died.emit(Vector3.ZERO, "", Vector3.ZERO)
	assert_eq(sl.held_id("p1"), "", "death cancels every pose")
	f["ch"].trigger_death(f["iid"])
	assert_false(f["ch"]._m2.trigger_gesture(f["iid"], "wave", false), "a dead body does not gesture")
	_free_fixture(f)


func _test_rest_regen() -> void:
	var f := _fixture()
	var sl: GestureSlice = f["sl"]
	assert_eq(sl.regen_multiplier("p1"), 1.0, "no pose, no bonus")
	sl.request("p1", "Sit", true, true, Vector3.ZERO)
	var rest := float(GameData.GESTURES["Sit"].get("restRegen"))
	assert_true(rest > 1.0, "sitting is a rest bonus")
	assert_eq(sl.regen_multiplier("p1"), rest, "the multiplier is the fabric's restRegen")
	assert_true(absf(GestureRules.regen_amount(sl.regen_multiplier("p1"), 2.0) - GestureRules.BASE_HP_REGEN_PER_S * rest * 2.0) < 0.0001,
		"HP regained is the base rate times restRegen")
	assert_true(absf(GestureRules.regen_amount(1.0, 2.0) - GestureRules.BASE_HP_REGEN_PER_S * 2.0) < 0.0001, "and the base rate without a pose")
	_free_fixture(f)


func _test_peer_pose_waits_for_avatar() -> void:
	var f := _fixture()
	var gr: Node = f["gr"]
	gr._is_client = true
	var wiring = gr._gesture_wiring
	# The host's join packet names peer 7 seated before its avatar exists on this client.
	GameBus.peer_gesture_synced.emit(7, "SitGround", -1.0)
	assert_eq(wiring._remote_poses.get(7, ""), "SitGround", "the pose waits")
	var other: String = f["ch"].create_character("TravellerHuman", Vector3(3, 0, 0))
	assert_true(f["ch"].attach_rig(other, "models/player_rig.glb.raw"), "the peer's avatar gets a rig")
	f["ch"].bind_peer_character(7, other)
	wiring.tick(0.1)
	assert_eq(f["ch"]._m2.gesture_clip_of(other), "sit_ground", "the avatar sits as soon as it exists")
	wiring.tick(0.1)
	assert_eq(int(f["ch"]._instances[other]["locomotion"].gesture_serial), 1, "and is not restarted every tick")
	GameBus.peer_gesture_synced.emit(7, "", -1.0)
	assert_false(f["ch"]._instances[other]["locomotion"].is_gesturing(), "the stand-up arrives too")
	assert_false(wiring._remote_poses.has(7), "and the pose is forgotten")
	gr._is_client = false
	f["ch"].remove_character(other)
	_free_fixture(f)


func _test_remote_oneshot_repeats() -> void:
	var f := _fixture()
	var gr: Node = f["gr"]
	gr._is_client = true
	var other: String = f["ch"].create_character("TravellerHuman", Vector3(3, 0, 0))
	assert_true(f["ch"].attach_rig(other, "models/player_rig.glb.raw"), "the peer's avatar gets a rig")
	f["ch"].bind_peer_character(7, other)
	GameBus.peer_gesture_synced.emit(7, "Wave", -1.0)
	var loco = f["ch"]._instances[other]["locomotion"]
	assert_eq(int(loco.gesture_serial), 1, "the first wave plays")
	GameBus.peer_gesture_synced.emit(7, "Wave", -1.0)
	assert_eq(int(loco.gesture_serial), 2, "a second wave restarts the clip")
	for i in 40:
		gr._gesture_wiring.tick(0.1)
	assert_false(loco.is_gesturing(), "the remote avatar's one-shot runs out without any position report")
	GameBus.peer_gesture_synced.emit(7, "SitGround", -1.0)
	gr._gesture_wiring.tick(0.1)
	GameBus.peer_gesture_synced.emit(7, "Wave", -1.0)
	assert_false(gr._gesture_wiring._remote_poses.has(7), "a one-shot replaces the stored pose")
	gr._is_client = false
	f["ch"].remove_character(other)
	_free_fixture(f)


func _test_action_cancels() -> void:
	var f := _fixture()
	var seen: Array = []
	var catch := func(p: String, g: String) -> void: seen.append([p, g])
	GameBus.gesture_synced.connect(catch)
	assert_eq(f["sl"].request("p1", "Sit", true, true, Vector3.ZERO), "", "sit accepted")
	GameBus.combat_hit_resolved.emit("p1", "wolf-1", "hit", 3.0)
	assert_eq(f["sl"].held_id("p1"), "", "a swing stands the player up")
	assert_eq(seen.back(), ["p1", ""], "and the stand-up is synced")
	GameBus.gesture_synced.disconnect(catch)
	_free_fixture(f)


func _test_lift_settles() -> void:
	var f := _fixture()
	var root: Node3D = f["ch"]._instances[f["iid"]]["root"]
	var base := root.position.y
	f["ch"]._m2.trigger_gesture(f["iid"], "sit", true, 0.4)
	assert_true(absf(root.position.y - (base + 0.4)) < 0.0001, "the root rises at once")
	f["ch"]._m2.end_gesture(f["iid"])
	assert_true(absf(root.position.y - base) < 0.0001, "and drops at once when the pose ends")
	var tree: AnimationTree = f["ch"]._instances[f["iid"]]["anim_tree"]
	f["ch"]._m2.trigger_gesture(f["iid"], "sit", true, 0.4)
	f["ch"]._m2.advance_gesture(f["iid"], 0.016)
	assert_eq(tree.get_meta("travel_node", ""), "Gesture", "a remote avatar sits")
	f["ch"]._m2.end_gesture(f["iid"])
	assert_eq(tree.get_meta("travel_node", ""), "Locomotion", "and its tree stands up without a local drive")
	_free_fixture(f)


func _test_new_pairs() -> void:
	var entered := {}
	var visible := {"2:1": true}
	assert_eq(GestureRules.new_pairs(visible, entered), ["2:1"], "a viewer in range for the first time is told")
	entered = visible
	assert_eq(GestureRules.new_pairs(visible, entered), [], "and not told again while it stays in range")
	entered = visible
	visible = {}
	entered = visible
	visible = {"2:1": true}
	assert_eq(GestureRules.new_pairs(visible, entered), ["2:1"], "leaving then re-entering replays it")


func _test_every_gesture_has_a_clip() -> void:
	var root := AssetOverlay.load_rig_scene("models/player_rig.glb.raw")
	var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for id in GameData.GESTURES:
		var clip := GestureRules.clip_of(GameData.GESTURES[id])
		assert_true(player.has_animation(clip), "the player rig has %s for %s" % [clip, id])
		assert_true(clip in RigTree.ONE_SHOT_CLIPS, "%s is in the one-shot table, so it holds its last key" % clip)
	root.free()


func _test_locomotion_and_tree() -> void:
	var loco := Locomotion.new()
	loco.trigger_gesture("sit", true, 0.8)
	for i in 100:
		loco.update(0.0, true, 0.0, 0.1)
	assert_true(loco.is_gesture_held(), "a pose is held for as long as it lasts")
	loco.end_gesture()
	assert_eq(loco.get_state(), Locomotion.State.IDLE, "ending it returns to locomotion")
	loco.trigger_gesture("wave", false, 1.0)
	loco.update(0.0, true, 0.0, 0.5)
	assert_true(loco.is_gesturing(), "a one-shot plays out")
	loco.update(0.0, true, 0.0, 0.6)
	assert_eq(loco.get_state(), Locomotion.State.IDLE, "and returns to locomotion by itself")
	loco.trigger_gesture("wave", false, 1.0)
	loco.trigger_hit()
	loco.trigger_death()
	loco.trigger_gesture("wave", false, 1.0)
	assert_eq(loco.get_state(), Locomotion.State.DEATH, "a dead body gestures no more")
	assert_eq(RigTree.node_for_state(Locomotion.State.GESTURE), "Gesture", "the state has its tree node")
	assert_eq(RigTree.xfade_for("Gesture", "Locomotion"), 0.3, "the stand-up is a 0.3 s transition, not a pop")


func _test_chat_commands() -> void:
	assert_eq(ChatCommands.gesture_id("/wave"), "Wave", "/wave")
	assert_eq(ChatCommands.gesture_id("/LIE"), "LieDown", "case does not matter")
	assert_eq(ChatCommands.gesture_id("/sitground now"), "SitGround", "arguments are ignored")
	assert_eq(ChatCommands.gesture_id("sit"), "", "a plain word is chat")
	assert_eq(ChatCommands.gesture_id("/dance"), "", "an unknown command is not a gesture")
	for id in GameData.GESTURES:
		assert_eq(ChatCommands.gesture_id(str(GameData.GESTURES[id].get("chatCommand"))), id, "%s answers its own command" % id)
	var seen: Array = []
	var catch := func(g: String, p: String) -> void: seen.append([g, p])
	GameBus.gesture_intent.connect(catch)
	var chat := ChatSlice.new()
	chat.submit("/sit")
	chat.submit("/wave")
	GameBus.gesture_intent.disconnect(catch)
	chat.free()
	assert_eq(seen, [["Sit", ""], ["Wave", ""]], "a typed command is a gesture_intent for the local player, not a chat line")
	assert_true(ChatCommands.help_lines(false).has("chat.usage.gestures"), "/help lists the gestures")
	assert_true(ChatCommands.is_command("/gestures") and ChatCommands.is_known("gestures"), "/gestures is a known command")
	var listed := ChatCommands.run("/gestures", Vector3.ZERO)
	assert_true(listed.contains("/sit"), "and answers with the gesture commands")
	assert_false(listed.contains("//"), "each command carries one slash, not two")


func _test_wheel_key() -> void:
	var old_path := LocaleSettings.settings_path
	LocaleSettings.settings_path = "user://test_gesture_settings.json"
	DirAccess.remove_absolute(LocaleSettings.settings_path)
	GesturePanel._cached_key = -1
	assert_eq(GesturePanel.key_code(), KEY_Q, "Q by default (G is Proposals and taming)")
	assert_false(GesturePanel.set_key(KEY_W), "a movement key cannot open the wheel")
	assert_false(GesturePanel.set_key(KEY_G), "nor the key Proposals owns")
	assert_true(GesturePanel.set_key(KEY_F7), "a free key can")
	GesturePanel._cached_key = -1
	assert_eq(GesturePanel.key_code(), KEY_F7, "and the choice is read back from the settings file")
	var box := GesturePanel.build(GameData.GESTURES, Callable())
	assert_eq(box.get_child_count(), GameData.GESTURES.size() + 1, "one button per fabric gesture, and the rebind button")
	box.free()
	# Phase 196 — the wheel key is reserved: a hotbar box cannot take it; the old default is free again.
	assert_false(_HotbarScript.bind_allowed(KEY_F7), "a box cannot bind the wheel key")
	assert_true(I18nScript.t("win.gestures", [GesturePanel.key_label()]).contains("F7"), "the window title names the bound key")
	# The rebind button: the next key becomes the wheel key, Escape cancels, a claimed key is refused.
	GesturePanel.awaiting_key = true
	assert_false(GesturePanel.take_rebind_key(KEY_ESCAPE), "Escape cancels a rebind")
	assert_eq(GesturePanel.key_code(), KEY_F7, "and keeps the key")
	assert_false(GesturePanel.awaiting_key, "and stops waiting")
	assert_false(GesturePanel.take_rebind_key(KEY_W), "a claimed key is refused")
	assert_true(GesturePanel.take_rebind_key(KEY_F6), "a free key is taken")
	assert_eq(GesturePanel.key_code(), KEY_F6, "and opens the wheel from now on")
	assert_true(_HotbarScript.bind_allowed(KEY_F7), "and the old key is free for a box again")
	DirAccess.remove_absolute(LocaleSettings.settings_path)
	LocaleSettings.settings_path = old_path
	GesturePanel._cached_key = -1
	_HotbarScript.gesture_key = KEY_Q


func _test_seat_lift() -> void:
	assert_true(absf(GestureRules.seat_lift(10.0, 10.45) - 0.45) < 0.0001, "a block edge 45 cm up is a seat")
	assert_eq(GestureRules.seat_lift(10.0, 10.0), -1.0, "level ground is not")
	assert_eq(GestureRules.seat_lift(10.0, 11.5), -1.0, "nor is a wall")
	assert_true(GestureRules.moved(Vector3.ZERO, Vector3(0.5, 9.0, 0.0)), "horizontal drift ends a pose")
	assert_false(GestureRules.moved(Vector3.ZERO, Vector3(0.0, 0.3, 0.1)), "a shuffle or settling onto the ground does not")
	# Phase 196 — a vertical rise or drop over RISE_CANCEL_M ends it too (a jump leaves the seat).
	assert_true(GestureRules.moved(Vector3.ZERO, Vector3(0.0, 1.2, 0.0)), "a jump in place does")
	assert_true(GestureRules.moved(Vector3.ZERO, Vector3(0.0, -2.0, 0.0)), "and so does a drop")
