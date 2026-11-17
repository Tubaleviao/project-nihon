extends "res://src/tests/test_support.gd"
## Phase 263 — digging that shows at once: an edit's remesh jumps the build queue (`EditRemesh`) and a client
## predicts its own edits (`EditPrediction`), rolled back on a refusal.

const EditRemesh := preload("res://src/terrain/edit_remesh.gd")
const EditPrediction := preload("res://src/terrain/edit_prediction.gd")
const NetPart2 := preload("res://src/networking/net_part_2.gd")

const Bot := preload("res://src/tests/playtest_bot.gd")

const HOME := Vector2i(0, 0)

# --- the playtest gate ------------------------------------------------------

func _test_playtest_edit_visible_gate() -> void:
	var s := func(frames: int, ms: float, primary := true) -> Dictionary:
		return { "chunk": "0,0", "primary": primary, "sync": frames == 1, "queue_ms": 0.0, "build_ms": ms, "total_ms": ms, "frames": frames }
	var rec := Bot.edit_visible_record([s.call(1, 4.0), s.call(1, 5.0), s.call(2, 20.0), s.call(9, 150.0, false)])
	assert_eq(int(rec["edits"]), 3, "only the edited chunks themselves count, not their seam neighbours")
	assert_eq(float(rec["frames_p95"]), 2.0, "p95 frames")
	assert_eq(int(rec["on_main_thread"]), 2, "two built on the main thread")
	var budgets: Dictionary = Bot.load_budgets()
	assert_eq(float((budgets.get(Bot.EDIT_VISIBLE_KEY, {}) as Dictionary).get("mine", -1)), 2.0, "the mine step's budget is two frames")
	var step := func(r: Dictionary) -> Array:
		return [{ "step": "mine", "ok": true, "detail": "", "max_ms": 1.0, "edit_visible": r }]
	assert_eq(Bot.edit_visible_failures(step.call(rec), budgets), [], "two frames pass")
	var slow := Bot.edit_visible_record([s.call(3, 50.0), s.call(4, 60.0)])
	assert_eq(Bot.edit_visible_failures(step.call(slow), budgets).size(), 1, "three frames fail")
	assert_eq(Bot.edit_visible_failures(step.call(Bot.edit_visible_record([])), budgets).size(), 1, "no edit recorded fails")
	assert_eq(Bot.budget_failures(step.call(rec), budgets), [], "the edit table is not read as a process budget")

func register() -> void:
	_run_test("edit remesh: an edited chunk is built before every queued streaming chunk", _test_edit_before_streaming)
	_run_test("edit remesh: a short build runs on the main thread at once, collision with it", _test_edit_built_now)
	_run_test("edit remesh: one main-thread build a frame, the rest take the next worker", _test_edit_one_sync_per_frame)
	_run_test("edit remesh: a finished edit build attaches ahead of the frame's attach budget", _test_edit_attach_first)
	_run_test("edit prediction: a refused mine is rolled back byte-equal, the pack untouched", _test_predict_mine_refused)
	_run_test("edit prediction: a refusal rolls back the later predictions too", _test_predict_rollback_later)
	_run_test("edit prediction: a confirmed mine is not applied twice", _test_predict_confirmed_once)
	_run_test("edit prediction: no answer in time rolls back; a late host edit still applies", _test_predict_timeout)
	_run_test("edit prediction: a placement is predicted only from the pack, which it never spends", _test_predict_place)
	_run_test("edit prediction: the host answers a prediction number and trusts nothing else in it", _test_host_answers_seq)
	_run_test("edit remesh: the playtest gates the mine step at two frames from completion to visible", _test_playtest_edit_visible_gate)

# --- rigs -----------------------------------------------------------------

func _free_rig(rig: Dictionary) -> void:
	for k in ["cm", "voxel", "terrain", "player"]:
		if rig.has(k) and is_instance_valid(rig[k]):
			rig[k].free()

## A built home chunk with nothing queued, the worker path forced (no main-thread build) unless a test opts in.
func _home_rig() -> Dictionary:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	cm.set_lod_enabled(false)
	cm.load_chunk(HOME)
	_wait_for_builds(cm)
	var remesh: EditRemesh = cm._m1.remesh
	remesh.sync_enabled = false
	rig["remesh"] = remesh
	return rig

## Mine the top of an interior tile of the home chunk (its own chunk only), as the host does.
func _mine_home(voxel: VoxelSlice, tile := Vector2i(16, 16)) -> Dictionary:
	var xz := Vector2((tile.x + 0.5) * VoxelSlice.TILE_SIZE, (tile.y + 0.5) * VoxelSlice.TILE_SIZE)
	return voxel.mine_block(Vector3(xz.x, voxel.column_top_at_tile(tile), xz.y), Vector3.UP)

func _samples_for(remesh: EditRemesh, key: String) -> Array:
	return remesh.samples.filter(func(s: Dictionary) -> bool: return str(s["chunk"]) == key)

# --- the priority remesh ----------------------------------------------------

func _test_edit_before_streaming() -> void:
	var rig := _home_rig()
	var cm: ChunkManager = rig["cm"]
	var remesh: EditRemesh = rig["remesh"]
	cm.adaptive_workers = false
	cm.max_builds_in_flight = 1
	cm.loads_per_frame = 1
	cm.refresh(false)
	cm._drain_load_queue()   # one streaming build takes the only worker
	assert_eq(cm._m1.worker_builds(), 1, "the pool is full of streaming work")
	var streaming: Array = cm._load_queue.duplicate() + cm._rebuild_queue.duplicate()
	assert_true(streaming.size() >= 8, "streaming chunks are queued (%d)" % streaming.size())
	assert_true(bool(_mine_home(rig["voxel"]).get("success", false)), "the dig applied")
	assert_eq(remesh.queued(), [HOME], "the edited chunk waits for the next worker, in its own line")
	var built_early: Array = []
	for i in 64:
		cm._drain_load_queue()
		cm.flush_builds()
		if not _samples_for(remesh, "0,0").is_empty():
			break
		for c in streaming:
			if cm.is_chunk_built(c):
				built_early.append(c)
	assert_eq(_samples_for(remesh, "0,0").size(), 1, "the edited chunk was rebuilt")
	assert_eq(built_early, [], "no queued streaming chunk was built before it")
	var unbuilt := streaming.filter(func(c: Vector2i) -> bool: return not cm.is_chunk_built(c))
	assert_true(unbuilt.size() >= streaming.size() - 1, "the streaming queue is still waiting behind it (%d of %d)" % [unbuilt.size(), streaming.size()])
	var s: Dictionary = _samples_for(remesh, "0,0")[0]
	assert_false(bool(s["sync"]), "built on a worker")
	assert_true(float(s["total_ms"]) >= float(s["build_ms"]) and float(s["queue_ms"]) >= 0.0, "timed: queue wait, build and the whole")
	_free_rig(rig)

func _test_edit_built_now() -> void:
	var rig := _home_rig()
	var cm: ChunkManager = rig["cm"]
	var voxel: VoxelSlice = rig["voxel"]
	var remesh: EditRemesh = rig["remesh"]
	remesh.sync_enabled = true
	remesh.sync_without_native = true   # the suite may run on the GDScript builder
	remesh._sync_frame = -1
	var rev_before: int = voxel.chunk_revision(HOME)
	var tile := Vector2i(16, 16)
	var top_before: float = voxel.column_top_at_tile(tile)
	assert_true(bool(_mine_home(voxel, tile).get("success", false)), "the dig applied")
	var s: Array = _samples_for(remesh, "0,0")
	assert_eq(s.size(), 1, "the edited chunk was rebuilt in the same call, no pump")
	assert_true(bool(s[0]["sync"]) and int(s[0]["frames"]) == 1, "on the main thread, visible the frame the work completed")
	assert_true(cm._builds.is_empty() and remesh.queued().is_empty(), "nothing left for a worker")
	assert_true(voxel.chunk_revision(HOME) > rev_before, "the edit moved the chunk's revision")
	assert_true(voxel.has_collision(HOME), "the collision came with the mesh")
	assert_true(voxel.column_top_at_tile(tile) < top_before, "the column is lower")
	_free_rig(rig)

func _test_edit_one_sync_per_frame() -> void:
	var rig := _home_rig()
	var cm: ChunkManager = rig["cm"]
	var remesh: EditRemesh = rig["remesh"]
	remesh.sync_enabled = true
	remesh.sync_without_native = true
	remesh._sync_frame = -1
	cm.adaptive_workers = false
	cm.max_builds_in_flight = 4
	_mine_home(rig["voxel"], Vector2i(16, 16))
	_mine_home(rig["voxel"], Vector2i(20, 20))
	var s: Array = _samples_for(remesh, "0,0")
	assert_eq(s.size(), 1, "one main-thread build this frame")
	assert_true(remesh.is_priority("0,0"), "the second edit's rebuild is open")
	assert_eq(cm._m1.worker_builds() + remesh.queued().size(), 1, "and went to a worker instead")
	_pump(cm)
	s = _samples_for(remesh, "0,0")
	assert_eq(s.size(), 2, "both edits rebuilt")
	assert_false(bool(s[1]["sync"]), "the second on a worker")
	_free_rig(rig)

func _test_edit_attach_first() -> void:
	var rig := _home_rig()
	var cm: ChunkManager = rig["cm"]
	var remesh: EditRemesh = rig["remesh"]
	cm.adaptive_workers = false
	cm.max_builds_in_flight = 4
	# Two finished builds; the edit's dispatched last, the frame allows one attach.
	cm.load_chunk(Vector2i(2, 0))
	_mine_home(rig["voxel"])
	var order: Array = cm._builds.keys()
	assert_eq(order.size(), 2, "a streaming build and the edit's are in flight")
	var deadline := Time.get_ticks_msec() + 20000
	while order.any(func(id: int) -> bool: return id >= 0 and not WorkerThreadPool.is_task_completed(id)) and Time.get_ticks_msec() < deadline:
		OS.delay_msec(2)
	var first: Array = remesh.first(order)
	assert_eq(str(cm._builds[first[0]]["key"]), "0,0", "the edit's build attaches first")
	# The streaming one first in its own order, one attach a frame: the edit's still attaches in this pass.
	cm.applies_per_frame = 1
	cm._last_centers = [Vector2i(2, 0)]
	cm._apply_finished_builds()
	assert_eq(_samples_for(remesh, "0,0").size(), 1, "the edit's mesh attached in this frame's pass")
	_pump(cm)
	_free_rig(rig)

## Dispatch and attach until nothing is queued or in flight, the edit queue included.
func _pump(cm: ChunkManager) -> void:
	for i in 64:
		if cm._builds.is_empty() and cm._load_queue.is_empty() and cm._rebuild_queue.is_empty() and cm._m1.remesh.queued().is_empty():
			return
		cm._drain_load_queue()
		cm.flush_builds()

# --- prediction -------------------------------------------------------------

## A client voxel slice over flat ground at 2 m (one chunk), with a pack.
func _client() -> Dictionary:
	var v := VoxelSlice.new()
	add_child(v)
	v.is_authoritative = false
	var flat: Array = []
	flat.resize(VoxelSlice.CHUNK_SIZE * VoxelSlice.CHUNK_SIZE)
	flat.fill(2.0)
	v.build_chunk(HOME, flat)
	var inv := InventorySlice.new()
	add_child(inv)
	inv.add_item("Sand", 3)
	v.inventory_slice = inv
	return { "v": v, "inv": inv }

func _free_client(c: Dictionary) -> void:
	c["v"].free()
	c["inv"].free()

## Everything the chunk's voxel data holds, as bytes: its tiles' op logs and runs, the vein depletion, the marks.
func _chunk_bytes(v: VoxelSlice, chunk: Vector2i) -> PackedByteArray:
	var n := VoxelSlice.CHUNK_SIZE
	var logs: Dictionary = {}
	var runs: Array = []
	for z in n:
		for x in n:
			var t := Vector2i(chunk.x * n + x, chunk.y * n + z)
			var k: String = VoxelSlice._tile_key(t)
			if v._edits.has(k):
				logs[k] = v._edits[k]
			runs.append(v.get_runs_at_tile(t))
	return var_to_bytes([logs, runs, v._vein_taken, v._partial_chunks, v._edits_by_chunk.get(VoxelSlice._chunk_key(chunk), {})])

const AIM := Vector3(16.0, 2.0, 16.0)

func _test_predict_mine_refused() -> void:
	var c := _client()
	var v: VoxelSlice = c["v"]
	var before := _chunk_bytes(v, HOME)
	var pack := var_to_bytes(c["inv"].get_contents())
	var rolled: Array = []
	var on_rolled := func(action: String, reason: String) -> void: rolled.append([action, reason])
	GameBus.block_edit_rolled_back.connect(on_rolled)
	var seq: int = v._predict.predict("mine", AIM, Vector3.UP, "")
	assert_true(seq > 0 and v._predict.is_pending(seq), "the mine is predicted and pending")
	assert_true(_chunk_bytes(v, HOME) != before, "the client's voxel data changed at once")
	assert_eq(var_to_bytes(c["inv"].get_contents()), pack, "the pack did not change on the prediction")
	v._predict.on_acked(seq, false)
	GameBus.block_edit_rolled_back.disconnect(on_rolled)
	assert_eq(_chunk_bytes(v, HOME), before, "the refusal left the chunk byte-equal to before")
	assert_eq(rolled, [["mine", "refused"]], "the refusal is told")
	assert_eq(v._predict.pending_count(), 0, "nothing pending")
	assert_eq(var_to_bytes(c["inv"].get_contents()), pack, "the pack never changed")
	_free_client(c)

func _test_predict_rollback_later() -> void:
	var c := _client()
	var v: VoxelSlice = c["v"]
	var before := _chunk_bytes(v, HOME)
	var a: int = v._predict.predict("mine", AIM, Vector3.UP, "")
	var b: int = v._predict.predict("mine", Vector3(16.0, 2.0 - VoxelSlice.STEP_HEIGHT, 16.0), Vector3.UP, "")
	var other: int = v._predict.predict("mine", Vector3(20.0, 2.0, 20.0), Vector3.UP, "")
	assert_true(a > 0 and b > a and other > b, "three predictions, two in one column")
	v._predict.on_acked(a, false)
	assert_eq(_chunk_bytes(v, HOME), before, "the first refused: it and every later one rolled back, byte-equal")
	assert_false(v._predict.is_pending(b) or v._predict.is_pending(other), "none left pending")
	# An answer that still comes for a dropped one is an ordinary host edit.
	v._predict.on_acked(b, true)
	v._on_block_changed("mine", AIM, Vector3.UP, "Soil")
	assert_true(_chunk_bytes(v, HOME) != before, "the host's own edit applies")
	_free_client(c)

func _test_predict_confirmed_once() -> void:
	var c := _client()
	var v: VoxelSlice = c["v"]
	var tile := Vector2i(32, 32)
	var seq: int = v._predict.predict("mine", AIM, Vector3.UP, "")
	var predicted: float = v.column_top_at_tile(tile)
	assert_true(predicted < 2.0, "the column is dug on the client")
	v._predict.on_acked(seq, true)
	v._on_block_changed("mine", AIM, Vector3.UP, "Soil")
	assert_eq(v.column_top_at_tile(tile), predicted, "the confirmed edit is not applied a second time")
	assert_eq(v._predict.pending_count(), 0, "confirmed: nothing pending")
	v._on_block_changed("mine", AIM, Vector3.UP, "Soil")
	assert_true(v.column_top_at_tile(tile) < predicted, "another player's edit of the same column applies")
	assert_eq(v._predict.samples.size(), 1, "the round trip is recorded")
	assert_true(bool(v._predict.samples[0]["accepted"]), "as accepted")
	_free_client(c)

func _test_predict_timeout() -> void:
	var c := _client()
	var v: VoxelSlice = c["v"]
	var clock := [1000]
	v._predict.clock_msec = func() -> int: return clock[0]
	var before := _chunk_bytes(v, HOME)
	var rolled: Array = []
	var on_rolled := func(_action: String, reason: String) -> void: rolled.append(reason)
	GameBus.block_edit_rolled_back.connect(on_rolled)
	var seq: int = v._predict.predict("mine", AIM, Vector3.UP, "")
	clock[0] += EditPrediction.TIMEOUT_MSEC - 1
	v._predict.tick()
	assert_true(v._predict.is_pending(seq), "still pending just before the timeout")
	clock[0] += 1
	v._predict.tick()
	GameBus.block_edit_rolled_back.disconnect(on_rolled)
	assert_eq(rolled, ["timeout"], "no answer in time rolls it back")
	assert_eq(_chunk_bytes(v, HOME), before, "byte-equal to before")
	v._predict.on_acked(seq, true)
	v._on_block_changed("mine", AIM, Vector3.UP, "Soil")
	assert_true(v.column_top_at_tile(Vector2i(32, 32)) < 2.0, "the host's late edit still applies: the client converges")
	_free_client(c)

func _test_predict_place() -> void:
	var c := _client()
	var v: VoxelSlice = c["v"]
	var inv: Node = c["inv"]
	var sent: Array = []
	var on_intent := func(action, _p, _n, material, _e, seq) -> void: sent.append([action, material, seq])
	GameBus.block_edit_intent.connect(on_intent)
	v._edit._on_place_requested(AIM, Vector3.UP, "", "Sand")
	v._edit._on_place_requested(Vector3(20.0, 2.0, 20.0), Vector3.UP, "", "Thornwood")
	GameBus.block_edit_intent.disconnect(on_intent)
	assert_eq(sent.size(), 2, "both intents go to the host")
	assert_true(int(sent[0][2]) > 0, "a material the pack shows is predicted")
	assert_eq(int(sent[1][2]), 0, "one it does not is left to the host")
	assert_true(v.column_top_at_tile(Vector2i(32, 32)) > 2.0, "the block stands on the client at once")
	assert_eq(inv.get_item_count("Sand"), 3, "the pack is not spent by the prediction")
	v._predict.on_acked(int(sent[0][2]), false)
	assert_eq(v.column_top_at_tile(Vector2i(32, 32)), 2.0, "a refused placement is taken back")
	assert_eq(inv.get_item_count("Sand"), 3, "and the pack never changed")
	_free_client(c)

func _test_host_answers_seq() -> void:
	assert_eq(NetPart2.edit_seq_of({ "edit_seq": 7 }), 7, "a number")
	assert_eq(NetPart2.edit_seq_of({ "edit_seq": 7.0 }), 7, "as JSON carries it")
	for bad: Variant in [0, -3, 7.5, "7", 1 << 40, INF, null]:
		assert_eq(NetPart2.edit_seq_of({ "edit_seq": bad }), 0, "%s is no prediction number" % str(bad))
	assert_eq(NetPart2.edit_seq_of({}), 0, "none")
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	var transport := MemoryTransport.new([7])
	n.set_transport(transport)
	n.set_player_id(7, "player_7_1_cafe")
	n.remember_player_state(7, Vector3.ZERO)
	_open_work_gate_for(n)
	# Applied: the host's edit (a stand-in for the voxel slice) answers with block_changed tagged for the asker.
	var apply := func(pos: Vector3, normal: Vector3, _pid: String, _exact: Dictionary) -> void:
		GameBus.block_changed.emit("mine", pos, normal, "Soil")
	GameBus.block_mine_requested.connect(apply)
	n._route_c2h(7, { "type": "block_edit_intent", "action": "mine", "position": [3.0, 2.0, 3.0], "normal": [0, 1, 0], "edit_seq": 4 })
	GameBus.block_mine_requested.disconnect(apply)
	var changed: Array = transport.outbox.filter(func(e: Dictionary) -> bool: return str(e["payload"].get("type", "")) == "block_changed")
	assert_true(changed.size() >= 1, "the edit went out")
	assert_eq([int(changed[0]["payload"].get("edit_seq", 0)), int(changed[0]["payload"].get("by", 0))], [4, 7], "tagged with the asker's number")
	assert_eq(changed.filter(func(e: Dictionary) -> bool: return (e["payload"] as Dictionary).has("edit_seq")).size(), 1, "the tag rides that one edit only")
	# Refused: the host's work timer never ran for it, and one far away is out of reach.
	n.get_meta("work_host").enforce = true
	transport.outbox.clear()
	n._route_c2h(7, { "type": "block_edit_intent", "action": "mine", "position": [3.0, 2.0, 3.0], "normal": [0, 1, 0], "edit_seq": 5 })
	n._route_c2h(7, { "type": "block_edit_intent", "action": "place", "position": [900.0, 2.0, 3.0], "normal": [0, 1, 0], "material": "Sand", "edit_seq": 6 })
	var refused: Array = transport.outbox.map(func(e: Dictionary) -> Array: return [str(e["payload"]["type"]), int(e["payload"].get("edit_seq", 0)), int(e["peer_id"])])
	assert_eq(refused, [["block_edit_refused", 5, 7], ["block_edit_refused", 6, 7]], "each refusal answered to the asker alone")
	# The tag is gone after the edit: a later host edit of its own carries none.
	transport.outbox.clear()
	GameBus.block_changed.emit("mine", Vector3(3.0, 2.0, 3.0), Vector3.UP, "Soil")
	assert_false((transport.outbox[0]["payload"] as Dictionary).has("edit_seq"), "a host edit of its own carries no number")
	n.free()

## The host's work gate open, as the networking suite does (its helper lives there).
func _open_work_gate_for(n: Node) -> void:
	var host = preload("res://src/core/work_host.gd").new()
	host.enforce = false
	n.set_meta("work_host", host)
