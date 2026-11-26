extends "res://src/tests/test_support.gd"
## #629 — the in-world marks of timed work: a crack on the worked block and a shake on the chopped tree, drawn on
## every machine in range. The host announces a mark when a session starts on a new target and when it ends; a
## viewer validates what the host sent and draws it; nothing about the work itself is decided here.

const WorkMarks := preload("res://src/world/work_marks.gd")
const WorkMarksView := preload("res://src/world/work_marks_view.gd")
const WorkHost := preload("res://src/core/work_host.gd")
const TreeFall := preload("res://src/world/tree_fall.gd")
const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")

## A stand-in for `TreeSlice`'s presentation half: one standing tree in a real `MultimeshPool`.
class FakeTrees extends Node:
	var _trees: Dictionary = {}
	var pool: Node = null
	var _fall: RefCounted = null
	func _tree_pool(_tree: Dictionary) -> Node:
		return pool
	func _visual_transform(pos: Vector3) -> Transform3D:
		return Transform3D(Basis(), pos)

## A pool that remembers each slot's transform (a headless MultiMesh does not read its transforms back).
class FakePool extends Node:
	var xf: Dictionary = {}
	var _next := 0
	func alloc() -> int:
		_next += 1
		return _next - 1
	func set_transform(idx: int, t: Transform3D) -> void:
		xf[idx] = t

func register() -> void:
	_run_test("work marks: a key names a tree or a block, and anything else is malformed", _test_keys)
	_run_test("work marks: a duration is a start up to the cap, 0 a stop, anything else malformed", _test_durations)
	_run_test("work marks: the store starts, stops, restarts, is bounded and expires a lost mark", _test_store)
	_run_test("work marks: the crack goes through its stages and the shake stays within its tilt", _test_stages)
	_run_test("work marks: the host announces a new target, a retarget, a cancel and a finished claim, once each", _test_host_announces)
	_run_test("work marks: the view cracks a block on its top face and drops it on the stop", _test_view_block)
	_run_test("work marks: the view sways a tree about its foot and stands it back up on the stop", _test_view_tree)
	_run_test("work marks: the client takes the host's packet and refuses a malformed one", _test_client_packet)
	_run_test("work marks: #714 a strike steps the crack, kicks the tree and throws chips at the nearest mark", _test_view_strike)
	_run_test("work marks: #714 a work_strike reaches the mark nearest the striking body", _test_strike_wiring)

func _test_keys() -> void:
	assert_eq(WorkMarks.parse_key("tree:t_1_2_3"), { "kind": "tree", "tree_id": "t_1_2_3" }, "a tree key names its tree")
	assert_eq(WorkMarks.parse_key(WorkHost.tree_key("abc")), { "kind": "tree", "tree_id": "abc" }, "the host's own tree key parses")
	var b := WorkMarks.parse_key("block:-12,40,1.75")
	assert_eq(b.get("kind", ""), "block", "a block key names a block")
	assert_eq(b.get("tile", null), Vector2i(-12, 40), "with its tile")
	assert_eq(float(b.get("bottom", 0.0)), 1.75, "and the bottom of the worked span")
	for bad in ["", "tree:", "tree:a:b", "block:1,2", "block:1,2,x", "block:a,2,1.0", "block:1,2,inf", "chest:1",
			"tree:" + "x".repeat(WorkMarks.MAX_KEY_LEN)]:
		assert_eq(WorkMarks.parse_key(bad), {}, "'%s' is malformed" % bad.left(20))
	assert_eq(WorkMarks.parse_key(7), {}, "a number is not a key")
	assert_eq(WorkMarks.parse_key(null), {}, "nor is a missing one")

func _test_durations() -> void:
	assert_eq(WorkMarks.parse_duration(2.5), 2.5, "a start")
	assert_eq(WorkMarks.parse_duration(3), 3.0, "an int start")
	assert_eq(WorkMarks.parse_duration(0.0), 0.0, "a stop")
	assert_eq(WorkMarks.parse_duration(WorkMarks.MAX_DURATION), WorkMarks.MAX_DURATION, "the cap itself")
	for bad in [-1.0, WorkMarks.MAX_DURATION + 0.01, INF, NAN, "2", null, [1.0]]:
		assert_eq(WorkMarks.parse_duration(bad), -1.0, "%s is malformed" % str(bad))

func _test_store() -> void:
	var m := WorkMarks.new()
	assert_true(m.apply("tree:a", 4.0, 10.0), "a start is taken")
	assert_true(m.has("tree:a"), "and recorded")
	assert_eq(m.progress("tree:a", 12.0), 0.5, "half way after half the time")
	assert_eq(m.elapsed("tree:a", 11.0), 1.0, "a second in")
	assert_true(m.apply("tree:a", 4.0, 13.0), "a restart is taken")
	assert_eq(m.progress("tree:a", 13.0), 0.0, "and starts the job again")
	assert_true(m.apply("tree:a", 0.0, 14.0), "a stop is taken")
	assert_false(m.has("tree:a"), "and drops the mark")
	assert_true(m.apply("tree:gone", 0, 14.0), "a stop of nothing is harmless")
	assert_false(m.apply("nope", 4.0, 14.0), "a malformed key is refused")
	assert_false(m.apply("tree:b", -2.0, 14.0), "a malformed duration is refused")
	assert_eq(m.size(), 0, "and neither recorded anything")
	for i in WorkMarks.MAX_MARKS + 5:
		m.apply("tree:t%d" % i, 4.0, 20.0)
	assert_eq(m.size(), WorkMarks.MAX_MARKS, "the store is bounded")
	assert_false(m.has("tree:t0"), "the oldest marks go first")
	assert_true(m.has("tree:t%d" % (WorkMarks.MAX_MARKS + 4)), "the newest stays")
	m.clear()
	m.apply("tree:a", 2.0, 0.0)
	assert_eq(m.expire(2.0 + WorkMarks.GRACE_SECONDS - 0.1), [], "a mark outlives its work by the grace")
	assert_eq(m.expire(2.0 + WorkMarks.GRACE_SECONDS + 0.1), ["tree:a"], "then a lost stop cannot leave it forever")
	assert_eq(m.progress("tree:a", 1.0), 0.0, "no mark, no progress")

func _test_stages() -> void:
	assert_eq(WorkMarks.crack_stage(0.0), 0, "no crack before the work")
	assert_eq(WorkMarks.crack_stage(0.01), 1, "the first crack at once")
	assert_eq(WorkMarks.crack_stage(0.5), WorkMarks.CRACK_STAGES / 2, "half the stages half way")
	assert_eq(WorkMarks.crack_stage(1.0), WorkMarks.CRACK_STAGES, "all of them at the end")
	assert_eq(WorkMarks.crack_stage(7.0), WorkMarks.CRACK_STAGES, "and never more")
	assert_eq(WorkMarks.shake_angle(0.0, 0.0), 0.0, "a tree is still before the first blow")
	var peak := deg_to_rad(WorkMarks.SHAKE_DEGREES)
	var moved := false
	for i in 50:
		var a := WorkMarks.shake_angle(0.013 * (i + 1), 1.0)
		assert_true(absf(a) <= peak + 0.0001, "the sway stays within its tilt")
		moved = moved or absf(a) > peak * 0.5
	assert_true(moved, "and does sway")
	var top := WorkMarks.block_top(Vector2i(4, -2), 1.0, VoxelConsts.TILE_SIZE, VoxelConsts.STEP_HEIGHT)
	assert_eq(top, Vector3(4.5 * VoxelConsts.TILE_SIZE, 1.0 + VoxelConsts.STEP_HEIGHT, -1.5 * VoxelConsts.TILE_SIZE),
		"a block's mark sits on the middle of its top face")
	for s in range(1, WorkMarks.CRACK_STAGES + 1):
		assert_eq(WorkMarksView.crack_image(s).get_data(), WorkMarksView.crack_image(s).get_data(), "stage %d's crack is the same every time" % s)
	assert_true(_lit(WorkMarksView.crack_image(WorkMarks.CRACK_STAGES)) > _lit(WorkMarksView.crack_image(1)), "a later stage is more broken")

func _lit(img: Image) -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				n += 1
	return n

## A tree stand-in for the host: `get_tree_record` answers one standing tree, as `TreeSlice` does.
class HostTrees extends Node:
	var player_registry: Object = null
	func get_tree_record(tree_id: String) -> Dictionary:
		return { "state": "standing", "wood": "Thornwood" } if tree_id.begins_with("t") else {}
	func inventory_for(_player_id: String) -> Node:
		return null

func _test_host_announces() -> void:
	var trees := HostTrees.new()
	var host := WorkHost.new()
	host.tree_slice = trees
	var heard: Array = []
	var cb := func(pid: String, key: String, d: float) -> void: heard.append([pid, key, d > 0.0])
	GameBus.work_mark_changed.connect(cb)
	var r: Dictionary = host.start("p1", "tree", "t1", Vector3.ZERO, Vector3.UP, {}, 0.0)
	assert_true(bool(r["ok"]), "the chop starts")
	assert_eq(heard, [["p1", "tree:t1", true]], "a new target announces its mark")
	host.start("p1", "tree", "t1", Vector3.ZERO, Vector3.UP, {}, 0.5)
	assert_eq(heard.size(), 1, "a repeated start on the same tree announces nothing")
	host.start("p1", "tree", "t2", Vector3.ZERO, Vector3.UP, {}, 1.0)
	assert_eq(heard.slice(1), [["p1", "tree:t1", false], ["p1", "tree:t2", true]], "a retarget stops the old mark first")
	host.start("p1", "tree", "x9", Vector3.ZERO, Vector3.UP, {}, 1.0)
	assert_eq(heard.size(), 3, "a target that cannot be worked announces nothing")
	assert_true(host.cancel("p1"), "a release cancels")
	assert_eq(heard[-1], ["p1", "tree:t2", false], "and stops the mark")
	assert_false(host.cancel("p1"), "a second release has nothing to cancel")
	assert_eq(heard.size(), 4, "and announces nothing")
	r = host.start("p2", "tree", "t3", Vector3.ZERO, Vector3.UP, {}, 0.0)
	assert_false(host.claim("p2", "tree:t3", 0.0), "an early claim is refused")
	assert_eq(heard[-1], ["p2", "tree:t3", true], "and leaves the mark up")
	assert_true(host.claim("p2", "tree:t3", float(r["duration"]) + 0.1), "the claim after the host's timer completes")
	assert_eq(heard[-1], ["p2", "tree:t3", false], "and stops the mark")
	host.start("p3", "tree", "t4", Vector3.ZERO, Vector3.UP, {}, 0.0)
	assert_false(host.claim("p3", "tree:t4", 99.0, false), "a claim out of reach ends the work")
	assert_eq(heard[-1], ["p3", "tree:t4", false], "and stops its mark")
	GameBus.work_mark_changed.disconnect(cb)
	trees.free()

func _view(now: Array) -> WorkMarksView:
	var v := WorkMarksView.new()
	v.clock = func() -> float: return float(now[0])
	add_child(v)
	return v

func _test_view_block() -> void:
	var now := [100.0]
	var v := _view(now)
	var key := "block:4,-2,1.00"
	assert_true(v.apply(key, 2.0), "the host's start is drawn")
	var mi := v.overlay(key)
	assert_true(mi != null, "the block gets an overlay")
	assert_eq(mi.position, WorkMarks.block_top(Vector2i(4, -2), 1.0, VoxelConsts.TILE_SIZE, VoxelConsts.STEP_HEIGHT)
		+ Vector3(0.0, WorkMarksView.LIFT, 0.0), "on the block's top face")
	assert_false(mi.visible, "with no crack before the first blow")
	now[0] = 100.6
	v.step()
	assert_true(mi.visible, "the crack shows as the work goes")
	assert_eq(int(mi.get_meta("stage", 0)), WorkMarks.crack_stage(0.3), "at the stage of its progress")
	now[0] = 101.9
	v.step()
	assert_eq(int(mi.get_meta("stage", 0)), WorkMarks.CRACK_STAGES, "near the end it is fully broken")
	v.shift_scene(Vector3(10.0, 0.0, 0.0))
	assert_eq(mi.position.x, WorkMarks.block_top(Vector2i(4, -2), 1.0, VoxelConsts.TILE_SIZE, VoxelConsts.STEP_HEIGHT).x + 10.0,
		"a rebase moves the overlay with its block")
	assert_true(v.apply(key, 0.0), "the host's stop is taken")
	assert_eq(v.overlay(key), null, "and drops the overlay")
	assert_eq(v.get_child_count(), 0, "with nothing left in the scene")
	for i in WorkMarks.MAX_MARKS + 3:
		v.apply("block:%d,0,0.50" % i, 5.0)
	assert_eq(v.get_child_count(), WorkMarks.MAX_MARKS, "a mark evicted from a full store takes its overlay with it")
	v.clear()
	v.apply("block:1,1,0.50", 1.0)
	now[0] = 102.0 + 1.0 + WorkMarks.GRACE_SECONDS + 0.1
	v.step()
	assert_eq(v.get_child_count(), 0, "a mark whose stop was lost goes after the grace")
	remove_child(v)
	v.free()

func _test_view_tree() -> void:
	var trees := FakeTrees.new()
	add_child(trees)
	var pool := FakePool.new()
	trees.add_child(pool)
	trees.pool = pool
	trees._fall = TreeFall.new(trees)
	var mi := pool.alloc()
	var foot := Vector3(3.0, 2.0, -5.0)
	trees._trees["oak1"] = { "state": "standing", "mi": mi, "position": foot }
	pool.set_transform(mi, Transform3D(Basis(), foot))
	var now := [50.0]
	var v := _view(now)
	v.tree_slice = trees
	assert_true(v.apply("tree:oak1", 3.0), "the host's chop is drawn")
	now[0] = 50.05
	v.step()
	var t: Transform3D = pool.xf[mi]
	assert_true(v.is_shaking("oak1"), "the tree sways")
	assert_eq(t.origin, foot, "about its foot, which stays put")
	assert_false(t.basis.is_equal_approx(Basis()), "tilted off upright")
	assert_true(t.basis.y.angle_to(Vector3.UP) <= deg_to_rad(WorkMarks.SHAKE_DEGREES) + 0.001, "by no more than the sway")
	assert_true(v.apply("tree:oak1", 0.0), "the host's stop is taken")
	t = pool.xf[mi]
	assert_true(t.basis.is_equal_approx(Basis()) and t.origin == foot, "the tree stands back up where it was")
	assert_false(v.is_shaking("oak1"), "and no longer sways")
	trees._trees["oak2"] = { "state": "stump", "mi": pool.alloc(), "position": foot }
	v.apply("tree:oak2", 3.0)
	assert_false(v.is_shaking("oak2"), "a stump does not sway")
	v.apply("tree:unknown", 3.0)
	assert_false(v.is_shaking("unknown"), "nor does a tree this machine does not have")
	remove_child(v)
	v.free()
	remove_child(trees)
	trees.free()

func _test_client_packet() -> void:
	var was_quiet := Diag.quiet
	Diag.quiet = true
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.CLIENT
	var got: Array = []
	var cb := func(key: String, d: float) -> void: got.append([key, d])
	GameBus.work_mark_synced.connect(cb)
	n._route_h2c({ "type": "work_mark", "k": "tree:t1", "d": 2.5 })
	n._route_h2c({ "type": "work_mark", "k": "tree:t1", "d": 0 })
	n._route_h2c({ "type": "work_mark", "k": 5, "d": 2.5 })
	n._route_h2c({ "type": "work_mark", "k": "tree:t1", "d": "2.5" })
	n._route_h2c({ "type": "work_mark", "k": "tree:" + "x".repeat(200), "d": 1.0 })
	n._role = NetworkingSlice.Role.HOST
	n._route_h2c({ "type": "work_mark", "k": "tree:t1", "d": 2.5 })
	GameBus.work_mark_synced.disconnect(cb)
	assert_eq(got, [["tree:t1", 2.5], ["tree:t1", 0.0]], "only a client takes well-typed, bounded marks")
	remove_child(n)
	n.free()
	# The store behind the view refuses what the wire check lets through but is still not a mark.
	var m := WorkMarks.new()
	assert_false(m.apply("block:1,2", 1.0, 0.0), "a malformed block key is never drawn")
	assert_false(m.apply("tree:t1", 9999.0, 0.0), "nor a job past the cap")
	Diag.quiet = was_quiet


## #714 — once struck, a mark draws the progress of its last strike (the crack steps on the beat), a struck tree
## sways harder for a moment, and each strike throws one chip burst that goes after its lifetime.
func _test_view_strike() -> void:
	var now := [10.0]
	var v := _view(now)
	var key := "block:0,0,0.00"
	var top := WorkMarks.block_top(Vector2i(0, 0), 0.0, VoxelConsts.TILE_SIZE, VoxelConsts.STEP_HEIGHT)
	v.apply(key, 4.0)
	v.apply("block:40,0,0.00", 4.0)
	assert_eq(v.strike(top + Vector3(WorkMarksView.STRIKE_REACH + 1.0, 0.0, 0.0)), "", "a strike out of reach takes no mark")
	now[0] = 11.1
	assert_eq(v.strike(top + Vector3(1.0, 0.0, 0.0)), key, "a strike in reach takes the nearest mark")
	assert_eq(v.struck_at(key), 11.1, "at the strike's time")
	var mi := v.overlay(key)
	var at_strike := WorkMarks.crack_stage(1.1 / 4.0)
	assert_eq(int(mi.get_meta("stage", 0)), at_strike, "the crack shows the strike's progress")
	assert_eq(v.chips.size(), 1, "the strike throws one chip burst")
	assert_true((v.chips[0][0] as CPUParticles3D).position.is_equal_approx(top), "at the struck face")
	now[0] = 12.5
	v.step()
	assert_eq(int(mi.get_meta("stage", 0)), at_strike, "and holds it until the next strike")
	assert_true(WorkMarks.crack_stage(2.5 / 4.0) > at_strike, "(time alone would have stepped it)")
	v.strike(top)
	assert_eq(int(mi.get_meta("stage", 0)), WorkMarks.crack_stage(2.5 / 4.0), "the next strike steps it")
	assert_eq(v.chips.size(), 1, "the first burst is gone, the second strike threw its own")
	now[0] = 12.5 + WorkMarksView.CHIP_LIFETIME + 0.01
	v.step()
	assert_eq(v.chips.size(), 0, "bursts go after their lifetime")
	for i in WorkMarksView.MAX_CHIP_BURSTS + 3:
		v.strike(top)
	assert_eq(v.chips.size(), WorkMarksView.MAX_CHIP_BURSTS, "bursts alive at once are capped")
	v.apply(key, 4.0)
	assert_eq(v.struck_at(key), -1.0, "a restarted mark starts a new beat")
	v.clear()
	assert_eq(v.chips.size(), 0, "a clear takes the bursts with it")
	assert_eq(v.get_child_count(), 0, "with nothing left in the scene")
	# A struck tree kicks: its tilt right after the strike is larger than the plain sway at the same moment.
	var trees := FakeTrees.new()
	add_child(trees)
	var pool := FakePool.new()
	trees.add_child(pool)
	trees.pool = pool
	trees._fall = TreeFall.new(trees)
	var tmi := pool.alloc()
	var foot := Vector3(3.0, 2.0, -5.0)
	trees._trees["oak1"] = { "state": "standing", "mi": tmi, "position": foot }
	pool.set_transform(tmi, Transform3D(Basis(), foot))
	v.tree_slice = trees
	now[0] = 20.0
	v.apply("tree:oak1", 3.0)
	now[0] = 20.05
	v.step()
	var plain := (pool.xf[tmi] as Transform3D).basis.y.angle_to(Vector3.UP)
	assert_eq(v.strike(foot), "tree:oak1", "a strike by the trunk takes the tree")
	var kicked := (pool.xf[tmi] as Transform3D).basis.y.angle_to(Vector3.UP)
	assert_true(kicked > plain * 2.0, "the struck tree sways harder (%f vs %f)" % [kicked, plain])
	assert_eq(v.chips[-1][0].color, Color(0.45, 0.3, 0.15), "with wood chips")
	now[0] = 20.05 + WorkMarksView.KICK_SECONDS + 0.01
	v.step()
	assert_true((pool.xf[tmi] as Transform3D).basis.y.angle_to(Vector3.UP) <= deg_to_rad(WorkMarks.SHAKE_DEGREES) + 0.001,
		"and settles back to the plain sway")
	remove_child(v)
	v.free()
	remove_child(trees)
	trees.free()

## #714 — the wiring places a `work_strike` at the striking body (`WorkAnimWiring.body_position`) and hands it to
## the view; nothing happens before a mark was drawn.
func _test_strike_wiring() -> void:
	var gr: Node = (load("res://src/core/game_root.gd") as GDScript).new()
	var ch := CharacterSlice.new()
	add_child(ch)
	gr._character = ch
	gr._registry = PlayerRegistry.new()
	var iid := ch.create_character_from_recipe({"skeleton": "HumanoidSkeleton"}, Vector3(1.0, 0.0, 1.0))
	ch.set_player_character(iid)
	gr._work_anim_wiring.root = gr
	gr._work_mark_wiring.wire(gr)
	GameBus.work_strike.emit(1, "mine")   # no view yet: nothing to strike, nothing made
	assert_eq(gr._work_mark_wiring.view, null, "a strike makes no view")
	var now := [5.0]
	var v := _view(now)
	gr._work_mark_wiring.view = v
	v.apply("block:0,0,0.00", 2.0)
	v.apply("block:9,9,0.00", 2.0)
	now[0] = 5.5
	GameBus.work_strike.emit(1, "mine")
	assert_eq(v.struck_at("block:0,0,0.00"), 5.5, "the local body's strike lands on the block beside it")
	assert_eq(v.struck_at("block:9,9,0.00"), -1.0, "not on the far one")
	GameBus.work_strike.emit(42, "mine")
	assert_eq(v.chips.size(), 1, "a peer with no body here strikes nothing")
	# The worker's own mark wins over a nearer one: the host learns it from `work_mark_changed`.
	now[0] = 5.7
	gr._work_mark_wiring.on_mark_changed("", "block:9,9,0.00", 2.0)
	assert_eq(gr._work_mark_wiring.peer_keys.get(1, ""), "block:9,9,0.00", "the host notes which mark its player works")
	GameBus.work_strike.emit(1, "mine")
	assert_eq(v.struck_at("block:9,9,0.00"), 5.7, "the strike lands on the worker's own mark, not the nearest")
	gr._work_mark_wiring.on_mark_changed("", "block:9,9,0.00", 0.0)
	assert_false(gr._work_mark_wiring.peer_keys.has(1), "its stop forgets it")
	# With no known mark, the kind picks the target: a chop never steps a block's crack.
	now[0] = 5.8
	GameBus.work_strike.emit(1, "chop")
	assert_eq(v.struck_at("block:0,0,0.00"), 5.5, "a chop strike passes the block beside it")
	gr._work_mark_wiring.view = null
	gr._work_mark_wiring.unwire()
	remove_child(v)
	v.free()
	ch.free()
	gr._registry.free()
	gr.free()
