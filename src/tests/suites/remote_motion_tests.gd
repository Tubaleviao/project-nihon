extends "res://src/tests/test_support.gd"
## Phase 294 — other players and creatures walk instead of jumping: one `RemoteMotion` track per remote body plays
## the host's states back a buffer behind and moves the body every frame (forward, never back, never a step bigger
## than a frame's worth), snaps once across a teleport, carries on for at most one send interval when states stop,
## turns at the fabric's turn rate and picks idle / walk / run from the speed played back. Remote player avatars
## and client creatures use the same track.

const RemoteMotion := preload("res://src/networking/remote_motion.gd")
const RemoteMotionRules := preload("res://src/networking/remote_motion_rules.gd")
const GameRoot := preload("res://src/core/game_root.gd")
const PeerWiring := preload("res://src/networking/peer_wiring.gd")
const RelayBatch := preload("res://src/networking/relay_batch.gd")

## The roadmap's frame: 16 ms; the most a body may move in one.
const FRAME_MS := 16.0
const MAX_STEP_M := 0.25


func register() -> void:
	_run_test("remote motion: the fabric table is read (buffer, teleport, extrapolation, turn rate, walk/run speeds)", _test_rules_read)
	_run_test("remote motion: states 100 ms and 1 m apart draw a body moving forward every 16 ms frame, never back, at most 0.25 m", _test_smooth_forward)
	_run_test("remote motion: a jump past the teleport distance snaps once and interpolation carries on", _test_teleport_snaps_once)
	_run_test("remote motion: no state for 300 ms moves the body on for at most one send interval, then it stops", _test_extrapolation_capped)
	_run_test("remote motion: a stop followed by keepalives at the same spot never turns the body round", _test_stop_keepalive)
	_run_test("remote motion: a pause does not stretch the playback delay of the next walk", _test_pause_not_a_gap)
	_run_test("remote motion: a non-finite state is dropped", _test_non_finite_dropped)
	_run_test("remote motion: the teleport check's relay gap mirrors RelayBatch.FAR_GAP_MS", _test_far_gap_mirrored)
	_run_test("remote motion: a late state behind the carried body does not pull it back", _test_late_state_never_back)
	_run_test("remote motion: a body whose states come less often is played back later, still smooth", _test_sparse_states_smooth)
	_run_test("remote motion: a stalled link's backlog arriving within a few ms plays back at walking pace, in no frame above 0.25 m", _test_burst_after_stall)
	_run_test("remote motion: a playback resync after a long stall eases the body instead of stepping it", _test_resync_eases)
	_run_test("remote motion: a same-instant burst does not rewrite the segment playback is inside", _test_burst_inside_segment)
	_run_test("remote motion: the state list stays bounded", _test_bounded_states)
	_run_test("remote motion: a remote player plays walk, run and idle from its speed and turns at the turn rate", _test_avatar_clips_and_turn)
	_run_test("remote motion: a remote avatar is not moved by a state, only by its playback", _test_avatar_state_does_not_snap)
	_run_test("remote motion: a creature driven by the host's creature states uses the same track and passes the frame test", _test_creature_same_track)
	_run_test("remote motion: the host sends a creature far from every player less often", _test_far_creature_throttled)
	_run_test("remote motion: a client fold drops the creatures' tracks and drawn positions", _test_fold_clears_tracks)


## A walk at 1 m / 100 ms, then 600 ms of silence, then the six states sent in the gap arriving 1 ms apart.
func _test_burst_after_stall() -> void:
	var t := _track()
	var states := _line(0.0, 8, 100.0, 1.0)   # 0..700 ms, x 0..7
	for k in 6:
		states.append([1300.0 + float(k), Vector3(8.0 + float(k), 0.0, 0.0)])
	for k in 10:
		states.append([1400.0 + float(k) * 100.0, Vector3(14.0 + float(k), 0.0, 0.0)])
	var drawn := _play(t, states, 3500.0)
	var worst := 0.0
	var back := 0
	for i in range(int(1500.0 / FRAME_MS), int(2500.0 / FRAME_MS)):   # the backlog and the walk after it (a stop eases back by design)
		worst = maxf(worst, (drawn[i] as Vector3).distance_to(drawn[i - 1]))
		if (drawn[i] as Vector3).x < (drawn[i - 1] as Vector3).x - 0.001:
			back += 1
	assert_true(worst <= MAX_STEP_M, "no frame above %.2f m after a burst (worst %.3f)" % [MAX_STEP_M, worst])
	assert_eq(back, 0, "never back along the line")
	assert_true((drawn[drawn.size() - 1] as Vector3).x >= 22.0, "the body reaches the last state")

func _test_resync_eases() -> void:
	var t := _track()
	var states := _line(0.0, 40, 100.0, 0.45)
	var drawn := _play(t, states, 1200.0)
	var before: Vector3 = drawn[drawn.size() - 1]
	# The clock jumps 1.6 s between two frames (a stalled process) while states kept arriving.
	for k in range(12, 28):
		t.push(1200.0 + float(k - 11) * 100.0, Vector3(float(k) * 0.45, 0.0, 0.0))
	t.step(2900.0, FRAME_MS / 1000.0)
	assert_true(t.position.distance_to(before) <= MAX_STEP_M, "the resync frame moves the body %.3f m (limit %.2f)" % [t.position.distance_to(before), MAX_STEP_M])

func _test_burst_inside_segment() -> void:
	var t := _track()
	var drawn := _play(t, _line(0.0, 8, 100.0, 0.45), 800.0)   # states to 700 ms; playback is inside the last segment
	var before: Vector3 = drawn[drawn.size() - 1]
	t.push(800.0, Vector3(5.0, 0.0, 0.0))
	t.push(800.0, Vector3(6.0, 0.0, 0.0))
	t.step(816.0, FRAME_MS / 1000.0)
	assert_true(t.position.distance_to(before) <= MAX_STEP_M, "the burst moved the body %.3f m" % t.position.distance_to(before))

func _track() -> RemoteMotion:
	return RemoteMotion.new(RemoteMotionRules.group("players"))

## Drive `track` from 0 to `end_ms` in 16 ms frames; `states` is [[t_ms, Vector3]] pushed when the clock reaches
## them. Returns the drawn positions, one per frame.
func _play(track: RemoteMotion, states: Array, end_ms: float, start_ms: float = 0.0) -> Array:
	var out: Array = []
	var i := 0
	var t := start_ms
	while t <= end_ms:
		while i < states.size() and float(states[i][0]) <= t:
			track.push(float(states[i][0]), states[i][1])
			i += 1
		track.step(t, FRAME_MS / 1000.0)
		out.append(track.position)
		t += FRAME_MS
	return out

func _line(from_ms: float, count: int, gap_ms: float, step_m: float, origin := Vector3.ZERO) -> Array:
	var out: Array = []
	for k in count:
		out.append([from_ms + float(k) * gap_ms, origin + Vector3(float(k) * step_m, 0.0, 0.0)])
	return out


func _test_rules_read() -> void:
	var r := RemoteMotionRules.rules()
	var res: Resource = GameData.WORLD_SYSTEMS.get("RemoteMotion", null)
	assert_true(res != null, "the fabric ships the RemoteMotion table")
	var fab: Dictionary = res.get("rules")
	assert_eq(float(r["players"]["bufferMs"]), float(fab["players"]["bufferMs"]), "the buffer is the fabric's")
	assert_eq(float(r["teleportDistanceM"]), float(fab["teleportDistanceM"]), "the teleport distance is the fabric's")
	assert_eq(float(r["creatures"]["extrapolateMaxMs"]), float(fab["creatures"]["extrapolateMaxMs"]), "the extrapolation cap is the fabric's")
	assert_eq(float(r["turnRateRadPerSec"]), float(fab["turnRateRadPerSec"]), "the turn rate is the fabric's")
	assert_eq(Locomotion.walk_speed(), float(fab["walkSpeed"]), "the local player's walk threshold is the fabric's")
	assert_eq(Locomotion.run_speed(), float(fab["runSpeed"]), "and its run threshold")
	var t := _track()
	assert_eq(t.buffer_ms, float(fab["players"]["bufferMs"]), "a player track takes the player buffer")
	assert_true(t.extrapolate_ms <= t.send_interval_ms, "and extrapolates at most one send interval")
	assert_true(is_equal_approx(RemoteMotionRules.player_send_interval_s() * 1000.0, float(fab["players"]["sendIntervalMs"])), "the player report interval is the fabric's")


func _test_smooth_forward() -> void:
	var t := _track()
	var drawn := _play(t, _line(0.0, 21, 100.0, 1.0), 2000.0)
	# From the frame the playback reaches the second state the body is walking: every frame moves it forward.
	var start := int(ceil((100.0 + t.delay_ms()) / FRAME_MS)) + 1
	var worst := 0.0
	var forward := true
	for k in range(1, drawn.size()):
		var a: Vector3 = drawn[k - 1]
		var b: Vector3 = drawn[k]
		worst = maxf(worst, a.distance_to(b))
		if b.x < a.x - 0.00001:
			forward = false
		if k >= start and b.x <= a.x:
			forward = false
	assert_true(forward, "the body moves forward every frame and never back")
	assert_true(worst <= MAX_STEP_M, "no frame moves it more than 0.25 m (worst %.3f)" % worst)
	assert_true((drawn[drawn.size() - 1] as Vector3).x > 17.0, "and it covers the walk (%.2f m)" % (drawn[drawn.size() - 1] as Vector3).x)
	assert_eq(t.snaps, 0, "a walk never snaps")


func _test_teleport_snaps_once() -> void:
	var t := _track()
	var far := Vector3(t.teleport_m + 50.0, 0.0, 0.0)
	var states := _line(0.0, 6, 100.0, 1.0)
	states.append_array(_line(600.0, 10, 100.0, 1.0, far))
	var drawn := _play(t, states, 1600.0)
	assert_eq(t.snaps, 1, "a jump past the teleport distance snaps once")
	var jumps := 0
	var after_snap: Array = []
	for k in range(1, drawn.size()):
		var d := (drawn[k - 1] as Vector3).distance_to(drawn[k])
		if d > MAX_STEP_M:
			jumps += 1
		elif (drawn[k] as Vector3).x >= far.x:
			after_snap.append(drawn[k])
	assert_eq(jumps, 1, "the body jumps in one frame, once")
	assert_true(after_snap.size() > 20 and (after_snap[after_snap.size() - 1] as Vector3).x > far.x + 5.0, "and keeps interpolating from the new place")
	var forward := true
	for k in range(1, after_snap.size()):
		if (after_snap[k] as Vector3).x < (after_snap[k - 1] as Vector3).x:
			forward = false
	assert_true(forward, "forward, never back, after the snap")


func _test_extrapolation_capped() -> void:
	var t := _track()
	var states := _line(0.0, 11, 100.0, 1.0)   # last state at 1000 ms, 10 m; then 300 ms and more of nothing
	var drawn := _play(t, states, 3000.0)
	var last_x := 10.0
	var cap := t.extrapolate_ms / 100.0   # 1 m per 100 ms
	var most := 0.0
	for p in drawn:
		most = maxf(most, (p as Vector3).x)
	assert_true(most > last_x, "past the newest state the body carries on (%.2f m)" % most)
	assert_true(most <= last_x + cap + 0.001, "for at most one send interval (%.2f m, cap %.2f)" % [most, last_x + cap])
	var tail: Array = drawn.slice(drawn.size() - 10)
	var stopped := true
	for p in tail:
		if not (p as Vector3).is_equal_approx(tail[0]):
			stopped = false
	assert_true(stopped, "then it stops")
	assert_true((tail[0] as Vector3).is_equal_approx(Vector3(last_x, 0, 0)), "where the last state put it, once nothing more came (%.3f)" % (tail[0] as Vector3).x)
	assert_true(t.settled and t.at_rest(), "and the track reads as settled")
	assert_eq(t.speed, 0.0, "standing: no speed")


func _test_late_state_never_back() -> void:
	var t := _track()
	# States every 100 ms, then one arrives 250 ms late: the body is carried past the last state, and the late
	# state (on the same line, behind where the body was carried) must not pull it back.
	var states := _line(0.0, 8, 100.0, 1.0)
	states.append([950.0, Vector3(8.0, 0.0, 0.0)])
	for k in range(9, 18):
		states.append([float(k) * 100.0 + 50.0, Vector3(float(k), 0.0, 0.0)])
	var drawn := _play(t, states, 2000.0)
	var back := false
	var worst := 0.0
	for k in range(1, drawn.size()):
		if (drawn[k] as Vector3).x < (drawn[k - 1] as Vector3).x - 0.00001:
			back = true
		worst = maxf(worst, (drawn[k - 1] as Vector3).distance_to(drawn[k]))
	assert_false(back, "the body never moves back")
	assert_true(worst <= MAX_STEP_M, "nor jumps (worst %.3f)" % worst)


func _test_sparse_states_smooth() -> void:
	var t := RemoteMotion.new(RemoteMotionRules.group("creatures"))
	# A far body: states 400 ms and 1 m apart (2.5 m/s).
	var drawn := _play(t, _line(0.0, 16, 400.0, 1.0), 6000.0)
	assert_true(t.delay_ms() >= 400.0, "the playback runs at least one measured gap behind (%.0f ms)" % t.delay_ms())
	var back := false
	var worst := 0.0
	for k in range(1, drawn.size()):
		if (drawn[k] as Vector3).x < (drawn[k - 1] as Vector3).x - 0.00001:
			back = true
		worst = maxf(worst, (drawn[k - 1] as Vector3).distance_to(drawn[k]))
	assert_false(back, "never back")
	assert_true(worst <= MAX_STEP_M, "and no step above 0.25 m (worst %.3f)" % worst)


func _test_bounded_states() -> void:
	var t := _track()
	for k in 500:
		t.push(float(k) * 10.0, Vector3(float(k) * 0.01, 0.0, 0.0))
	assert_true(t.state_count() <= RemoteMotion.MAX_STATES, "a stalled playback keeps at most MAX_STATES")
	t.step(5000.0, 0.016)
	assert_true(t.state_count() <= RemoteMotion.MAX_STATES, "and so does a playing one")


func _client() -> Dictionary:
	var root: GameRoot = GameRoot.new()
	var ch := CharacterSlice.new()
	add_child(ch)
	var player := PlayerSlice.new()
	root._character = ch
	root._player = player
	root._is_client = true
	var w := PeerWiring.new()
	w.root = root
	return { "root": root, "ch": ch, "player": player, "w": w }

func _free_client(r: Dictionary) -> void:
	r["ch"].free()
	r["player"].free()
	r["root"].free()

## Walk peer 5 along +X at `speed` m/s for `ms`, states every 100 ms, frames every 16 ms; returns the avatar id.
func _walk_avatar(r: Dictionary, speed: float, ms: float) -> String:
	var w: PeerWiring = r["w"]
	var iid := ""
	var t := 0.0
	var next_state := 0.0
	while t <= ms:
		if t >= next_state:
			iid = w.note_remote_state(5, Vector3(speed * next_state / 1000.0, 0.0, 0.0), next_state)
			next_state += 100.0
		w.tick_remote_avatars(FRAME_MS / 1000.0, t)
		t += FRAME_MS
	return iid

func _loco_name(ch: CharacterSlice, iid: String) -> String:
	return str(ch._instances[iid]["locomotion"].state_name())

func _test_avatar_clips_and_turn() -> void:
	var r := _client()
	var ch: CharacterSlice = r["ch"]
	var walk := (Locomotion.walk_speed() + Locomotion.run_speed()) * 0.5
	var iid := _walk_avatar(r, walk, 1500.0)
	assert_true(iid != "", "the avatar is built")
	assert_eq(_loco_name(ch, iid), "WALK", "at walking speed it plays walk")
	assert_true(absf(float(ch.get_character_yaw(iid)) - atan2(-1.0, 0.0)) < 0.01, "and faces where it goes (+X)")
	r["w"]._remove_remote_avatar(5)
	iid = _walk_avatar(r, Locomotion.run_speed() + 2.0, 1500.0)
	assert_eq(_loco_name(ch, iid), "RUN", "at running speed it plays run")
	r["w"]._remove_remote_avatar(5)
	iid = _walk_avatar(r, 0.0, 1500.0)
	assert_eq(_loco_name(ch, iid), "IDLE", "standing it plays idle")
	# Turning: a body facing -Z (yaw 0) that starts walking along +X turns at the turn rate, not at once.
	r["w"]._remove_remote_avatar(5)
	var w: PeerWiring = r["w"]
	iid = w.note_remote_state(5, Vector3.ZERO, 0.0)
	w.tick_remote_avatars(0.016, 0.0)
	var yaw0 := float(ch.get_character_yaw(iid))
	for k in range(1, 6):
		w.note_remote_state(5, Vector3(0.3 * float(k), 0.0, 0.0), float(k) * 100.0)
	var target := atan2(-1.0, 0.0)
	var t := 400.0
	var turned_once := false
	var bounded := true
	var prev := yaw0
	var rate := float(RemoteMotionRules.rules()["turnRateRadPerSec"])
	while t <= 1000.0:
		w.tick_remote_avatars(FRAME_MS / 1000.0, t)
		var y := float(ch.get_character_yaw(iid))
		if absf(angle_difference(prev, y)) > rate * FRAME_MS / 1000.0 + 0.0001:
			bounded = false
		if absf(angle_difference(y, target)) > 0.01 and absf(angle_difference(y, yaw0)) > 0.0001:
			turned_once = true
		prev = y
		t += FRAME_MS
	assert_true(bounded, "no frame turns it more than turn rate × frame")
	assert_true(turned_once, "it passes through the angles between, not at once")
	assert_true(absf(angle_difference(prev, target)) < 0.01, "and ends facing its movement")
	r["w"]._remove_remote_avatar(5)
	_free_client(r)


func _test_avatar_state_does_not_snap() -> void:
	var r := _client()
	var ch: CharacterSlice = r["ch"]
	var w: PeerWiring = r["w"]
	var iid := w.note_remote_state(5, Vector3.ZERO, 0.0)
	assert_eq(ch.get_character_position(iid), Vector3.ZERO, "the first state builds the avatar there")
	w.note_remote_state(5, Vector3(1, 0, 0), 100.0)
	assert_eq(ch.get_character_position(iid), Vector3.ZERO, "a later state alone does not move it")
	var t := 0.0
	while t <= 100.0 + w.remote_motion_of(5).delay_ms() - 30.0:
		w.tick_remote_avatars(FRAME_MS / 1000.0, t)
		t += FRAME_MS
	var at: Vector3 = ch.get_character_position(iid)
	assert_true(at.x > 0.0 and at.x < 1.0, "the playback does, between the states (%.2f)" % at.x)
	w._remove_remote_avatar(5)
	assert_true(w.remote_motion_of(5) == null, "the track goes with the avatar")
	_free_client(r)


func _test_creature_same_track() -> void:
	var c := CreatureSlice.new()
	add_child(c)
	c.is_authoritative = false
	var clock := [0.0]
	c._motion.clock = func() -> float: return clock[0]
	var iid := "boar-test-1"
	var drawn: Array = []
	var next_state := 0.0
	var k := 0
	var t := 0.0
	while t <= 2000.0:
		clock[0] = t
		if t >= next_state and k <= 20:
			# What the client does with a host `creature_state_changed` (the relay of `relay_creature_state`).
			c._on_creature_state_changed(iid, "ForestBoar", "wandering", WorldPos.from_world(float(k), 0.0, 0.0))
			k += 1
			next_state += 100.0
		c.tick_motion(FRAME_MS / 1000.0, t)
		var draw: Dictionary = (c._instances.get(iid, {}) as Dictionary).get("draw", {})
		if not draw.is_empty():
			drawn.append(WorldPos.to_scene(draw["pos"], Vector2i.ZERO))
		t += FRAME_MS
	assert_true(c.motion_of(iid) is RemoteMotion, "the creature has the same motion track as a remote player")
	var worst := 0.0
	var back := false
	for i in range(1, drawn.size()):
		worst = maxf(worst, (drawn[i - 1] as Vector3).distance_to(drawn[i]))
		if (drawn[i] as Vector3).x < (drawn[i - 1] as Vector3).x - 0.00001:
			back = true
	assert_true(drawn.size() > 100, "it is drawn every frame")
	assert_false(back, "never back")
	assert_true(worst <= MAX_STEP_M, "no step above 0.25 m (worst %.3f)" % worst)
	assert_true((drawn[drawn.size() - 1] as Vector3).x > 15.0, "and it walks the line")
	c._on_creature_state_changed(iid, "ForestBoar", "dead", WorldPos.from_world(20.0, 0.0, 0.0))
	assert_true(c.motion_of(iid) == null, "a dead body leaves the track (its fall is the model's)")
	c.free()


func _test_far_creature_throttled() -> void:
	var c := CreatureSlice.new()
	add_child(c)
	c.spawn_for_chunk(Vector2i(0, 0))
	var sent := []
	var cb := func(iid, _cid, _state, _pos): sent.append(iid)
	GameBus.creature_state_changed.connect(cb)
	var first: Dictionary = c.get_all_instances()[0]
	var iid: String = first["instance_id"]
	var at: Vector3 = first["position"]
	var far_m := float(RemoteMotionRules.rules()["creatures"]["farDistanceM"])
	var gap := float(RemoteMotionRules.rules()["creatures"]["farSendIntervalMs"])
	var player := [at + Vector3(far_m * 3.0, 0, 0)]
	c.player_positions = func() -> Dictionary: return { "p": player[0] }
	c._broadcast_creature_states(0.0)
	sent.clear()
	c.set_instance_position(iid, at + Vector3(0.5, 0, 0))
	c._broadcast_creature_states(100.0)
	assert_false(sent.has(iid), "a far creature's move waits for the far interval")
	c._broadcast_creature_states(gap + 1.0)
	assert_true(sent.has(iid), "and goes once it is due")
	sent.clear()
	player[0] = at
	c.set_instance_position(iid, at + Vector3(1.0, 0, 0))
	c._broadcast_creature_states(gap + 101.0)
	assert_true(sent.has(iid), "a creature near a player is sent at the full rate")
	GameBus.creature_state_changed.disconnect(cb)
	c.free()


func _test_stop_keepalive() -> void:
	var t := _track()
	# Walk +X at 4 m/s, stop at 1000 ms (4 m), then the relay's keepalive at the same spot every 1000 ms.
	var states: Array = []
	for k in 11:
		states.append([float(k) * 100.0, Vector3(0.4 * float(k), 0.0, 0.0)])
	for k in range(1, 5):
		states.append([1000.0 + 1000.0 * float(k), Vector3(4.0, 0.0, 0.0)])
	var facing := atan2(-1.0, 0.0)
	var i := 0
	var tm := 0.0
	var turned := false
	var walked_back := false
	while tm <= 6000.0:
		while i < states.size() and float(states[i][0]) <= tm:
			t.push(float(states[i][0]), states[i][1])
			i += 1
		t.step(tm, FRAME_MS / 1000.0)
		if tm > 1000.0 and absf(angle_difference(t.yaw, facing)) > 0.01:
			turned = true
		if tm > 1300.0 and t.speed >= Locomotion.walk_speed():
			walked_back = true
		tm += FRAME_MS
	assert_false(turned, "the body keeps facing the way it walked")
	assert_false(walked_back, "and plays no walk while it settles")
	assert_true(t.position.is_equal_approx(Vector3(4.0, 0, 0)), "it ends on the host's spot (%.3f)" % t.position.x)
	assert_true(t.delay_ms() <= t.buffer_ms + 0.001, "keepalives do not stretch the delay (%.0f ms)" % t.delay_ms())


func _test_pause_not_a_gap() -> void:
	var t := RemoteMotion.new(RemoteMotionRules.group("creatures"))
	# A creature walks, stands 5 s (the host sends nothing for an unchanged creature), then walks again.
	var states := _line(0.0, 6, 100.0, 0.4)
	states.append_array(_line(5500.0, 10, 100.0, 0.4, Vector3(2.0, 0, 0)))
	_play(t, states, 7000.0)
	assert_true(t.delay_ms() <= t.buffer_ms + 0.001, "the pause is not a gap between moving states (%.0f ms)" % t.delay_ms())


func _test_non_finite_dropped() -> void:
	var t := _track()
	t.push(0.0, Vector3.ZERO)
	t.push(100.0, Vector3(NAN, 0, 0))
	t.push(200.0, Vector3(INF, 0, 0))
	assert_eq(t.state_count(), 1, "a NaN or infinite position is not queued")
	t.step(300.0, 0.016)
	assert_true(t.position.is_finite() and is_finite(t.yaw), "the body stays drawable")


func _test_far_gap_mirrored() -> void:
	# `fabric/gameplay/remote_motion.js` checks teleportDistanceM against RELAY_FAR_GAP_MS = 750.
	assert_eq(RelayBatch.FAR_GAP_MS, 750.0, "the fabric validator's relay gap is the relay's")
	assert_true(float(RemoteMotionRules.rules()["teleportDistanceM"]) > 90.0 * RelayBatch.FAR_GAP_MS / 1000.0,
		"a 90 m/s flier relayed far does not snap on every state")


func _test_fold_clears_tracks() -> void:
	var c := CreatureSlice.new()
	add_child(c)
	c.is_authoritative = false
	var clock := [0.0]
	c._motion.clock = func() -> float: return clock[0]
	c._on_creature_state_changed("boar-fold", "ForestBoar", "wandering", WorldPos.from_world(1.0, 0.0, 1.0))
	c.tick_motion(0.016, 0.0)
	assert_true(c.motion_of("boar-fold") != null and c._instances["boar-fold"].has("draw"), "a client creature is drawn from its track")
	c.fold_contents(false, 0)
	assert_true(c.motion_of("boar-fold") == null, "a fold drops the track (it was in the old frame)")
	assert_false(c._instances["boar-fold"].has("draw"), "and the drawn position, so the folded state is drawn")
	clock[0] = 100.0
	c._on_creature_state_changed("boar-fold", "ForestBoar", "wandering", WorldPos.from_world(2.0, 0.0, 1.0))
	assert_true(c.motion_of("boar-fold") != null, "the next state starts a new track")
	c.free()
