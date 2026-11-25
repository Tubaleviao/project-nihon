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
	_run_test("work anim: a peer's copy with no rig still plays the kind's own clip", _test_p281_rigless_copy)
	_run_test("work anim: #714 ending a hold never cuts a combat swing started since", _test_stop_work_keeps_swing)
	_run_test("work anim: #714 a hold whose host session is gone stops instead of refreshing forever", _test_dead_hold_stops)
	_run_test("work anim: #714 a hold longer than the remote expiry keeps playing on the host and on a viewer", _test_long_hold_refreshed)
	_run_test("work anim: #714 the dissect loop ends on the pose it starts from (no pop to standing)", _test_dissect_loop_safe)
	_run_test("work anim: #714 a client drops a work answer for a hold it released or a tree it left", _test_stale_answer_dropped)
	_run_test("work anim: #714 a peer that leaves mid-hold has its loop stopped for the viewers", _test_leave_stops_loop)
	_run_test("work anim: #714 the host plays build only for a placement that went through, once per placement", _test_refused_place_no_build)


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
	assert_false(w.is_working(1), "a placement the host did not make (no block placed) plays nothing (#714)")
	_place_on_host()
	assert_eq(loco.attack_clip, "build", "placing a block plays build")
	assert_false(w._active[1]["loop"], "and plays once")
	GameBus.work_cancel_requested.emit("")
	assert_true(w.is_working(1), "a stop with no loop running neither cuts the single action short nor is broadcast")
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
	var ch: CharacterSlice = f["ch"]
	var w = f["w"]
	var peer_iid: String = ch.create_character_from_recipe({"skeleton": "HumanoidSkeleton"}, Vector3.ZERO)
	assert_true(ch.attach_rig(peer_iid, "models/player_rig.glb.raw"), "the peer's copy has the rig")
	ch.bind_peer_character(7, peer_iid)
	var seen := [""]
	var cb := func(peer: int, kind: String) -> void: seen[0] = "%d:%s" % [peer, kind]
	GameBus.work_anim_changed.connect(cb)
	GameBus.work_anim_changed.emit(7, "chop")
	GameBus.work_anim_changed.disconnect(cb)
	assert_eq(seen[0], "7:chop", "the change is a bus signal other systems can read")
	assert_eq(str(ch._instances[peer_iid]["locomotion"].attack_clip), "chop", "peer 7's copy plays chop")
	assert_true(w.is_working(7), "and loops it")
	assert_true(f["loco"].get_state() != Locomotion.State.ATTACK, "the local body is left alone")
	GameBus.work_anim_changed.emit(7, "")
	assert_false(w.is_working(7), "the stop ends the copy's loop")
	GameBus.work_anim_changed.emit(8, "chop")
	assert_false(w.is_working(8), "an unknown peer draws no copy and plays nothing")
	GameBus.work_anim_changed.emit(7, "mine")
	GameBus.peer_disconnected.emit(7)
	assert_false(w.is_working(7) or w.last_clip.has(7) or w.clip_history.has(7) or w._announced.has(7),
		"a peer that left takes its per-peer state with it")
	ch.remove_character(peer_iid)
	_free_fixture(f)

## The client builds another player's copy without a rig; the net harness drew it in time on a slow runner and
## saw `attack_tool` for a chop. Only a rig that lacks the clip falls back.
func _test_p281_rigless_copy() -> void:
	var f := _fixture()
	var ch: CharacterSlice = f["ch"]
	var w = f["w"]
	var peer_iid: String = ch.create_character_from_recipe({"skeleton": "HumanoidSkeleton"}, Vector3.ZERO)
	ch.bind_peer_character(7, peer_iid)
	GameBus.work_anim_changed.emit(7, "chop")
	assert_eq(str(w.last_clip.get(7, "")), "chop", "the rig-less copy plays chop, not attack_tool")
	GameBus.work_anim_changed.emit(7, "")
	ch._instances[peer_iid]["swing_lengths"] = {"attack_tool": 0.5}
	GameBus.work_anim_changed.emit(7, "chop")
	assert_eq(str(w.last_clip.get(7, "")), "attack_tool", "a rig without the clip still falls back")
	GameBus.work_anim_changed.emit(7, "")
	GameBus.peer_disconnected.emit(7)
	ch.remove_character(peer_iid)
	_free_fixture(f)

func _test_p281_face_target() -> void:
	var f := _fixture()
	GameBus.work_start_requested.emit("block", "", Vector3(5.0, 0.0, 0.0), Vector3.UP, {}, "")
	GameBus.work_started.emit("k", 1.0, "dig", "")
	var yaw: float = f["ch"].get_character_yaw(f["iid"])
	assert_true(absf(yaw - atan2(-5.0, 0.0)) < 0.01, "a block to the east turns the face (-Z) east (yaw %.2f)" % yaw)
	_free_fixture(f)

## #714 — `stop_work` used to call `end_attack()` whatever the pose was, so releasing a hold right after a combat
## swing cut the swing. It now ends only the work clip it started: a newer swing (or no work at all) plays out.
func _test_stop_work_keeps_swing() -> void:
	var f := _fixture()
	var ch: CharacterSlice = f["ch"]
	var iid: String = f["iid"]
	var loco = f["loco"]
	assert_eq(ch.trigger_work(iid, "chop"), "chop", "the hold plays chop")
	ch.stop_work(iid)
	assert_true(loco.get_state() != Locomotion.State.ATTACK, "ending the hold ends its own clip")
	ch.trigger_work(iid, "mine")
	loco.trigger_attack("attack", 0.6)   # a combat swing over the work pose
	ch.stop_work(iid)
	assert_eq(loco.get_state(), Locomotion.State.ATTACK, "the swing started since is not cut")
	assert_eq(loco.attack_clip, "attack", "and keeps its own clip")
	loco.end_attack()
	loco.trigger_attack("attack", 0.6)
	ch.stop_work(iid)
	assert_eq(loco.get_state(), Locomotion.State.ATTACK, "with no work running, a stop leaves a swing alone")
	ch.stop_work("nobody")   # an unknown instance is a no-op
	_free_fixture(f)


## #714 — a remote copy used to stop after REMOTE_LOOP_MAX_SECONDS even while the hold still ran. The host keeps
## its own copy of a running loop alive and re-announces it every LOOP_REFRESH_SECONDS; a viewer's repeat of the
## same loop only pushes the expiry back, never restarts the clip.
func _test_long_hold_refreshed() -> void:
	var f := _fixture()
	var ch: CharacterSlice = f["ch"]
	var w = f["w"]
	var peer_iid: String = ch.create_character_from_recipe({"skeleton": "HumanoidSkeleton"}, Vector3.ZERO)
	assert_true(ch.attach_rig(peer_iid, "models/player_rig.glb.raw"), "the peer's copy has the rig")
	ch.bind_peer_character(7, peer_iid)
	var loco = ch._instances[peer_iid]["locomotion"]
	# Host: peer 7 holds a chop for longer than the remote expiry.
	GameBus.work_anim_changed.emit(7, "chop")
	assert_true(w.is_working(7), "the host plays peer 7's chop")
	var steps := int((WorkAnimWiring.REMOTE_LOOP_MAX_SECONDS + 5.0) / 0.5)
	for i in steps:
		w.tick(0.5)
	assert_true(w.is_working(7), "past the remote expiry the host's copy still plays: the hold is running")
	assert_eq(w._since_sent.get(7, -1.0) < WorkAnimWiring.LOOP_REFRESH_SECONDS, true, "and the loop was re-sent on schedule")
	GameBus.work_anim_changed.emit(7, "")
	assert_false(w.is_working(7), "the stop ends it")
	w.tick(WorkAnimWiring.LOOP_REFRESH_SECONDS + 1.0)
	assert_false(w._since_sent.has(7), "and a stopped loop is not re-sent")
	# Viewer: the host's refresh of the same loop keeps the clip running without restarting it.
	f["gr"]._is_client = true
	w._announced.clear()
	GameBus.work_anim_changed.emit(7, "chop")
	var serial := int(loco.swing_serial)
	var t := 0.0
	while t < WorkAnimWiring.REMOTE_LOOP_MAX_SECONDS + 5.0:
		w.tick(0.5)
		t += 0.5
		if fmod(t, WorkAnimWiring.LOOP_REFRESH_SECONDS) == 0.0:
			GameBus.work_anim_changed.emit(7, "chop")   # the host's refresh
	assert_true(w.is_working(7), "a refreshed loop outlives the remote expiry on a viewer")
	assert_true(float(w._active[7]["age"]) < WorkAnimWiring.LOOP_REFRESH_SECONDS, "its expiry was pushed back")
	assert_true(int(loco.swing_serial) > serial, "the loop kept cycling its clip")
	# Without refreshes (the worker left range) the viewer's copy still expires.
	for i in int((WorkAnimWiring.REMOTE_LOOP_MAX_SECONDS + 1.0) / 0.5):
		w.tick(0.5)
	assert_false(w.is_working(7), "an unrefreshed remote loop expires")
	_free_fixture(f)


## A hold whose WorkHost session vanished without a stop (death, abandoned hold) is ended for everyone at the next
## refresh instead of being re-announced forever.
func _test_dead_hold_stops() -> void:
	var f := _fixture()
	var w = f["w"]
	var ch: CharacterSlice = f["ch"]
	var peer_iid: String = ch.create_character_from_recipe({"skeleton": "HumanoidSkeleton"}, Vector3.ZERO)
	assert_true(ch.attach_rig(peer_iid, "models/player_rig.glb.raw"), "the peer's copy has the rig")
	ch.bind_peer_character(7, peer_iid)
	var host = (load("res://src/core/work_host.gd") as GDScript).new()
	var net := NetworkingSlice.new()
	net.set_meta("work_host", host)
	f["gr"]._networking = net
	GameBus.work_anim_changed.emit(7, "chop")
	assert_true(w.is_working(7), "the host plays peer 7's chop")
	w.tick(WorkAnimWiring.LOOP_REFRESH_SECONDS + 1.0)
	assert_false(w.is_working(7), "no session on the host: the refresh ends the hold")
	assert_eq(str(w._announced.get(7, "")), "", "and it is not announced again")
	f["gr"]._networking = null
	net.free()
	_free_fixture(f)

## The host's order for an accepted placement: the VoxelSlice places the block (`block_placed`) while the request
## is being handled, before the wiring sees the request.
func _place_on_host(player_id: String = "") -> void:
	GameBus.block_placed.emit("Soil", Vector3.ZERO)
	GameBus.block_place_requested.emit(Vector3.ZERO, Vector3.UP, player_id, "Soil", {})

## #714 — `build` played on every placement request, even one the host refused. Now only a request whose block was
## placed in the same frame plays it, one placement per request, and a placement no request claimed (a boot
## fixture) is never claimed by a later refused request.
func _test_refused_place_no_build() -> void:
	var f := _fixture()
	var w = f["w"]
	var heard: Array = []
	var cb := func(peer: int, kind: String) -> void: heard.append("%d:%s" % [peer, kind])
	GameBus.work_anim_changed.connect(cb)
	GameBus.block_place_requested.emit(Vector3.ZERO, Vector3.UP, "", "Soil", {})
	assert_eq(heard.size(), 0, "a refused placement announces nothing")
	_place_on_host()
	assert_eq(heard, ["1:build"], "an accepted one announces build for its builder")
	GameBus.block_place_requested.emit(Vector3.ZERO, Vector3.UP, "", "Soil", {})
	assert_eq(heard.size(), 1, "a second request cannot claim the first one's placement")
	GameBus.block_placed.emit("Soil", Vector3.ZERO)
	w._placed_frame = Engine.get_process_frames() - 1   # that placement was made in an earlier frame
	GameBus.block_place_requested.emit(Vector3.ZERO, Vector3.UP, "", "Soil", {})
	assert_eq(heard.size(), 1, "a placement from an earlier frame is not claimed by a later refused request")
	GameBus.work_anim_changed.disconnect(cb)
	_free_fixture(f)

## #714 — the dissect clip's last key kept the kneel while its first key stood up, so each loop restart popped the
## body to standing. The first and last frames now match on every bone, with the hips still down.
func _test_dissect_loop_safe() -> void:
	var proot := AssetOverlay.load_rig_scene("models/player_rig.glb.raw")
	add_child(proot)
	var pp := proot.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var skel := proot.find_child("Skeleton3D", true, false) as Skeleton3D
	assert_true(pp != null and skel != null and pp.has_animation("dissect"), "the rig has a dissect clip")
	if pp == null or skel == null or not pp.has_animation("dissect"):
		proot.queue_free()
		return
	pp.play("dissect")
	var length := pp.get_animation("dissect").length
	var poses: Array = []
	for t in [0.0, length]:
		pp.seek(t, true)
		var frame: Array = []
		for b in skel.get_bone_count():
			frame.append(skel.get_bone_global_pose(b))
		poses.append(frame)
	var worst := 0.0
	for b in skel.get_bone_count():
		worst = maxf(worst, (poses[0][b] as Transform3D).origin.distance_to((poses[1][b] as Transform3D).origin))
	assert_true(worst < 0.005, "the first and last frames match on every bone (worst %.3f m)" % worst)
	pp.seek(0.0, true)
	var root_bone := skel.find_bone("Root")
	var drop := skel.get_bone_rest(root_bone).origin.y - skel.get_bone_pose_position(root_bone).y
	assert_true(drop >= 0.30, "the loop starts already kneeling (hips %.2f m down)" % drop)
	proot.queue_free()

## #714 — a client's `work_started` comes back over the wire. One that lands after the hold was released played a
## loop nothing would stop; one for a tree the player had left played on the new target. Both are dropped now.
func _test_stale_answer_dropped() -> void:
	var f := _fixture()
	var w = f["w"]
	f["gr"]._is_client = true
	GameBus.work_started.emit("tree:t1", 1.0, "chop", "")
	assert_false(w.is_working(1), "an answer with no hold open plays nothing")
	GameBus.work_start_requested.emit("tree", "t1", Vector3.ZERO, Vector3.UP, {}, "")
	GameBus.work_cancel_requested.emit("")
	GameBus.work_started.emit("tree:t1", 1.0, "chop", "")
	assert_false(w.is_working(1), "an answer landing after the release plays nothing")
	GameBus.work_start_requested.emit("tree", "t2", Vector3.ZERO, Vector3.UP, {}, "")
	GameBus.work_started.emit("tree:t1", 1.0, "chop", "")
	assert_false(w.is_working(1), "an answer for the tree the player left plays nothing")
	GameBus.work_started.emit("tree:t2", 1.0, "chop", "")
	assert_true(w.is_working(1), "the answer for the held tree plays")
	GameBus.work_cancel_requested.emit("")
	GameBus.work_start_requested.emit("block", "", Vector3.ONE, Vector3.UP, {}, "")
	GameBus.work_started.emit("block:1:2:3", 1.0, "mine", "")
	assert_true(w.is_working(1), "a block hold takes the host's key as given")
	GameBus.work_cancel_requested.emit("")
	assert_true(WorkAnimWiring.answers_hold("*", "tree:x") and not WorkAnimWiring.answers_hold("", "block:1"), "answers_hold: any target, and none when released")
	_free_fixture(f)

## #714 — a peer that disconnected mid-hold left its loop running on every viewer until the 30 s remote expiry: the
## host dropped its state without a stop. It now sends the stop to the peers in range of the last known position.
func _test_leave_stops_loop() -> void:
	var f := _fixture()
	var w = f["w"]
	var net := NetworkingSlice.new()
	add_child(net)
	net._role = NetworkingSlice.Role.HOST
	var wire := MemoryTransport.new([5, 6])
	net.set_transport(wire)
	net.remember_player_state(5, Vector3(2, 0, 2))
	net.remember_player_state(6, Vector3(4, 0, 4))
	f["gr"]._networking = net
	GameBus.work_anim_changed.emit(5, "chop")
	assert_eq(str(w._announced.get(5, "")), "chop", "the host runs peer 5's chop loop")
	wire.outbox.clear()
	w._on_peer_disconnected(5)
	var stops := wire.outbox.filter(func(e): return e["payload"].get("type", "") == "work_anim" and int(e["payload"].get("p", 0)) == 5 \
		and str(e["payload"].get("k", "x")) == "")
	assert_true(stops.size() >= 1 and stops.any(func(e): return int(e["peer_id"]) == 6), "the viewer in range is told the loop stopped")
	assert_false(w._announced.has(5), "and the departed peer's state is gone")
	wire.outbox.clear()
	w._on_peer_disconnected(6)
	assert_true(wire.outbox.is_empty(), "a peer with no loop running leaves without a stop")
	f["gr"]._networking = null
	net.free()
	_free_fixture(f)
