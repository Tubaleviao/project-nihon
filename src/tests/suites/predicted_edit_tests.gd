extends "res://src/tests/test_support.gd"
## Phase 263 — digging that shows at once: an edit's remesh jumps the build queue (`EditRemesh`) and a client
## predicts its own edits (`EditPrediction`), rolled back on a refusal.

const EditRemesh := preload("res://src/terrain/edit_remesh.gd")
const EditPrediction := preload("res://src/terrain/edit_prediction.gd")
const NetPart2 := preload("res://src/networking/net_part_2.gd")

const Bot := preload("res://src/tests/playtest_bot.gd")
const VoxelMesh := preload("res://src/terrain/voxel_mesh.gd")

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
	var table: Dictionary = budgets.get(Bot.EDIT_VISIBLE_KEY, {})
	assert_eq([float((table.get("frames", {}) as Dictionary).get("mine", -1)), float(table.get("target_fps", -1))], [2.0, 60.0],
		"the mine step's budget is two frames at 60 Hz")
	assert_true(absf(Bot.edit_visible_limit_ms(2.0, 60.0) - 1000.0 / 30.0) < 0.001, "33.3 ms")
	var step := func(r: Dictionary) -> Array:
		return [{ "step": "mine", "ok": true, "detail": "", "max_ms": 1.0, "edit_visible": r }]
	assert_eq(Bot.edit_visible_failures(step.call(rec), budgets), [], "20 ms passes")
	var slow := Bot.edit_visible_record([s.call(3, 50.0), s.call(4, 60.0)])
	assert_eq(Bot.edit_visible_failures(step.call(slow), budgets).size(), 1, "three frames fail")
	# PR #648 review: one frame that carried a 60 ms main-thread build is not two frames at 60 Hz.
	var hitch := Bot.edit_visible_record([s.call(1, 60.0), s.call(1, 55.0)])
	assert_eq(Bot.edit_visible_failures(step.call(hitch), budgets).size(), 1, "one frame of 60 ms fails")
	assert_eq(Bot.edit_visible_failures(step.call(Bot.edit_visible_record([])), budgets).size(), 1, "no edit recorded fails")
	assert_eq(Bot.budget_failures(step.call(rec), budgets), [], "the edit table is not read as a process budget")

func register() -> void:
	_run_test("edit remesh: an edited chunk is built before every queued streaming chunk", _test_edit_before_streaming)
	_run_test("edit remesh: a short build runs on the main thread at once, collision with it", _test_edit_built_now)
	_run_test("edit remesh: one main-thread build a frame, the rest take the next worker", _test_edit_one_sync_per_frame)
	_run_test("edit remesh: a finished edit build attaches ahead of the frame's attach budget", _test_edit_attach_first)
	_run_test("edit prediction: a refused mine is rolled back byte-equal, the pack untouched", _test_predict_mine_refused)
	_run_test("edit prediction: a refusal takes that one out, the later ones stay on the host's state", _test_predict_rollback_later)
	_run_test("edit prediction: a confirmed mine is not applied twice", _test_predict_confirmed_once)
	_run_test("edit prediction: no answer in time rolls back; a late host edit still applies", _test_predict_timeout)
	_run_test("edit prediction: a placement is predicted only from the pack, which it never spends", _test_predict_place)
	_run_test("edit prediction: the host answers a prediction number and trusts nothing else in it", _test_host_answers_seq)
	_run_test("edit remesh: the playtest gates the mine step at 2 frames of 60 Hz (33 ms) from completion to visible", _test_playtest_edit_visible_gate)
	_run_test("edit remesh: another player's edit never builds on the main thread", _test_remote_edit_on_worker)
	_run_test("edit remesh: a chunk whose last build was slow is not built on the main thread", _test_sync_cost_bound)
	_run_test("edit remesh: the work's dig is built ahead and attached as is at completion", _test_prebuilt_edit)
	_run_test("edit remesh: a prebuilt dig whose chunk changed meanwhile is not used", _test_prebuilt_miss)
	_run_test("edit remesh: a rebuilt chunk keeps its unchanged collision quadrants", _test_reuse_shapes)
	_run_test("edit prediction: another player's edit of the tile survives a rollback", _test_predict_other_player_same_tile)
	_run_test("edit prediction: vein depletion by the host survives a rollback, only the prediction's own goes", _test_predict_vein_elsewhere)
	_run_test("edit prediction: an earlier prediction timing out keeps a later confirmed one", _test_predict_timeout_after_later_confirmed)
	_run_test("edit prediction: a re-scope snapshot or /regen world drops every prediction", _test_predict_cleared_by_snapshot)
	_run_test("edit prediction: a hit on a placed block is not predicted", _test_predict_no_placed_block)
	_run_test("edit prediction: the host's span is compared with the prediction, and wins", _test_predict_span_mismatch)

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
	remesh.max_sync_job_usec = 1 << 40   # whose builds are far over the bound
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
	remesh.max_sync_job_usec = 1 << 40
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
	assert_false(v._predict.is_pending(a), "the refused one is out")
	assert_true(v._predict.is_pending(b) and v._predict.is_pending(other), "the later ones stay pending: the host answers each")
	var ref := _client()
	ref["v"]._predict.predict("mine", Vector3(16.0, 2.0 - VoxelSlice.STEP_HEIGHT, 16.0), Vector3.UP, "")
	ref["v"]._predict.predict("mine", Vector3(20.0, 2.0, 20.0), Vector3.UP, "")
	assert_eq(_chunk_bytes(v, HOME), _chunk_bytes(ref["v"], HOME), "made again as if the refused one never was")
	_free_client(ref)
	v._predict.on_acked(b, false)
	v._predict.on_acked(other, false)
	assert_eq(_chunk_bytes(v, HOME), before, "all refused: byte-equal to before")
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
		GameBus.block_edit_span.emit(Vector2i(6, 6), 1.5, 2.0)
		GameBus.block_changed.emit("mine", pos, normal, "Soil")
	GameBus.block_mine_requested.connect(apply)
	n._route_c2h(7, { "type": "block_edit_intent", "action": "mine", "position": [3.0, 2.0, 3.0], "normal": [0, 1, 0], "edit_seq": 4 })
	GameBus.block_mine_requested.disconnect(apply)
	var changed: Array = transport.outbox.filter(func(e: Dictionary) -> bool: return str(e["payload"].get("type", "")) == "block_changed")
	assert_true(changed.size() >= 1, "the edit went out")
	assert_eq([int(changed[0]["payload"].get("edit_seq", 0)), int(changed[0]["payload"].get("by", 0))], [4, 7], "tagged with the asker's number")
	assert_eq(changed.filter(func(e: Dictionary) -> bool: return (e["payload"] as Dictionary).has("edit_seq")).size(), 1, "the tag rides that one edit only")
	assert_false(NetPart2.edit_span_of(changed[0]["payload"]).is_empty(), "with the span the host resolved")
	assert_eq(NetPart2.edit_span_of({ "edit_span": [6, 6, 1.5, 2.0] }), { "tile": Vector2i(6, 6), "bottom": 1.5, "top": 2.0 }, "read back")
	for bad: Variant in [null, [1, 2, 3], [0.5, 0, 1.0, 2.0], [0, 0, 2.0, 1.0], [0, 0, NAN, 1.0], "0,0,1,2"]:
		assert_eq(NetPart2.edit_span_of({ "edit_span": bad }), {}, "%s is no span" % str(bad))
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

# --- PR #648 review ---------------------------------------------------------

## A remote actor's dig on the host and a replayed `block_changed` both take the worker, whatever the bound says.
func _test_remote_edit_on_worker() -> void:
	var rig := _home_rig()
	var cm: ChunkManager = rig["cm"]
	var voxel: VoxelSlice = rig["voxel"]
	var remesh: EditRemesh = rig["remesh"]
	remesh.sync_enabled = true
	remesh.sync_without_native = true
	remesh.max_sync_job_usec = 1 << 40
	remesh._sync_frame = -1
	assert_true(bool(voxel.mine_block(_home_aim(voxel, Vector2i(16, 16)), Vector3.UP, "player_9_1_cafe").get("success", false)), "a remote actor's dig applied")
	assert_true(_samples_for(remesh, "0,0").is_empty(), "nothing built in the call")
	_pump(cm)
	remesh._sync_frame = -1
	voxel.apply_block_change("mine", _home_aim(voxel, Vector2i(20, 20)), Vector3.UP, "Soil")
	assert_eq(_samples_for(remesh, "0,0").size(), 1, "a host block_changed replayed here builds nothing in the call either")
	_pump(cm)
	var s: Array = _samples_for(remesh, "0,0")
	assert_eq(s.size(), 2, "both rebuilt")
	assert_false(bool(s[0]["sync"]) or bool(s[1]["sync"]), "both on a worker")
	assert_false(bool(s[0]["primary"]) or bool(s[1]["primary"]), "neither counted as the local player's own edit")
	_free_rig(rig)

func _test_sync_cost_bound() -> void:
	var rig := _home_rig()
	var cm: ChunkManager = rig["cm"]
	var remesh: EditRemesh = rig["remesh"]
	remesh.sync_enabled = true
	remesh.sync_without_native = true
	remesh._sync_frame = -1
	remesh.note_cost("0,0", EditRemesh.MAX_SYNC_JOB_USEC + 1)
	assert_false(remesh.can_build_now(HOME), "a build over the bound is not made on the main thread")
	assert_true(remesh.can_build_now(HOME, false), "a prebuilt one may still be attached")
	_mine_home(rig["voxel"])
	assert_true(_samples_for(remesh, "0,0").is_empty(), "the dig went to a worker")
	_pump(cm)
	assert_false(bool(_samples_for(remesh, "0,0")[0]["sync"]), "built on a worker")
	remesh.note_cost("0,0", 2000)
	remesh._sync_frame = -1
	assert_true(remesh.can_build_now(HOME), "a cheap chunk may be")
	remesh.note_cost("0,0", 0)
	assert_true(remesh.can_build_now(HOME), "a zero cost is not recorded")
	_free_rig(rig)

## Wait for the held prebuild's task (the suite has no frames).
func _wait_prebuild(remesh: EditRemesh) -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while not remesh.prebuild._spec.is_empty() and not WorkerThreadPool.is_task_completed(int(remesh.prebuild._spec["task"])) \
			and Time.get_ticks_msec() < deadline:
		OS.delay_msec(2)

func _home_aim(voxel: VoxelSlice, tile: Vector2i) -> Vector3:
	return Vector3((tile.x + 0.5) * VoxelSlice.TILE_SIZE, voxel.column_top_at_tile(tile) - 0.05, (tile.y + 0.5) * VoxelSlice.TILE_SIZE)

func _voxel_state(voxel: VoxelSlice) -> PackedByteArray:
	return var_to_bytes([voxel._edits, voxel._edits_by_chunk, voxel._vein_taken, voxel._partial_chunks, voxel._edit_rev])

func _test_prebuilt_edit() -> void:
	var rig := _home_rig()
	var cm: ChunkManager = rig["cm"]
	var voxel: VoxelSlice = rig["voxel"]
	var remesh: EditRemesh = rig["remesh"]
	remesh.sync_enabled = true
	remesh.prebuild.without_native = true
	remesh._sync_frame = -1
	var aim := _home_aim(voxel, Vector2i(16, 16))
	var data := _voxel_state(voxel)
	GameBus.work_start_requested.emit("block", "", aim, Vector3.UP, {}, "")
	assert_true(remesh.prebuild.has(HOME), "the work's start built the dug chunk ahead")
	assert_eq(_voxel_state(voxel), data, "and left the voxel data as it was")
	assert_true(cm._builds.is_empty() and remesh.queued().is_empty(), "no rebuild was dispatched for the moment's edit")
	_wait_prebuild(remesh)
	assert_true(bool(voxel.mine_block(aim, Vector3.UP).get("success", false)), "the dig applied")
	var s: Array = _samples_for(remesh, "0,0")
	assert_eq(s.size(), 1, "attached in the same call")
	assert_true(bool(s[0]["sync"]) and bool(s[0]["prebuilt"]), "the prebuilt arrays, on the main thread")
	assert_eq(remesh.prebuild.hits, 1, "a hit")
	assert_true(voxel.has_collision(HOME), "with its collision")
	# The same arrays a build made now would give.
	var faces := _collision_faces(voxel, HOME)
	cm.request_rebuild(HOME)
	_pump(cm)
	assert_eq(_collision_faces(voxel, HOME), faces, "the prebuilt chunk is the edit's own build")
	_free_rig(rig)

func _collision_faces(voxel: VoxelSlice, chunk: Vector2i) -> Array:
	var out: Array = []
	for sh in voxel._build._shapes_of(VoxelSlice._chunk_key(chunk)):
		out.append((sh as ConcavePolygonShape3D).get_faces())
	return out

func _test_prebuilt_miss() -> void:
	var rig := _home_rig()
	var voxel: VoxelSlice = rig["voxel"]
	var remesh: EditRemesh = rig["remesh"]
	remesh.sync_enabled = true
	remesh.prebuild.without_native = true
	remesh._sync_frame = -1
	var aim := _home_aim(voxel, Vector2i(16, 16))
	assert_true(voxel._edit.prebuild_edit("mine", aim, Vector3.UP, ""), "built ahead")
	_wait_prebuild(remesh)
	# Another dig lands on the chunk before the work completes (a remote actor's: no main-thread build of its own).
	voxel.mine_block(_home_aim(voxel, Vector2i(30, 30)), Vector3.UP, "player_9_1_cafe")
	_pump(rig["cm"])
	remesh._sync_frame = -1
	var n0 := remesh.samples.size()
	voxel.mine_block(aim, Vector3.UP)
	assert_eq(remesh.prebuild.misses, 1, "the held build no longer matches the chunk's input")
	assert_false(remesh.samples.slice(n0).any(func(x: Dictionary) -> bool: return bool(x.get("prebuilt", false))), "and is not attached")
	_pump(rig["cm"])
	assert_true(remesh.samples.size() > n0, "the dig still rebuilt its chunk")
	_free_rig(rig)

func _test_reuse_shapes() -> void:
	var a := PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)])
	var b := PackedVector3Array([Vector3(5, 0, 0), Vector3(6, 0, 0), Vector3(5, 0, 1)])
	var old := [VoxelMesh.collision_shape(a), VoxelMesh.collision_shape(b)]
	var fresh := [VoxelMesh.collision_shape(a), VoxelMesh.collision_shape(PackedVector3Array([Vector3(5, 1, 0), Vector3(6, 0, 0), Vector3(5, 0, 1)]))]
	var out: Array = preload("res://src/terrain/voxel_build.gd").reuse_shapes(old.duplicate(), fresh)
	assert_true(is_same(out[0], old[0]), "an unchanged quadrant keeps its built shape")
	assert_true(is_same(out[1], fresh[1]), "a changed one is the new shape")

## Two clients over the same flat chunk: `[0]` predicts, `[1]` only ever applies what the host sent.
func _pair(chunk := HOME) -> Array:
	var out: Array = []
	for i in 2:
		var c := _client()
		if chunk != HOME:
			var flat: Array = []
			flat.resize(VoxelSlice.CHUNK_SIZE * VoxelSlice.CHUNK_SIZE)
			flat.fill(2.0)
			c["v"].build_chunk(chunk, flat)
		out.append(c)
	return out

func _test_predict_other_player_same_tile() -> void:
	var pair := _pair()
	var v: VoxelSlice = pair[0]["v"]
	var ref: VoxelSlice = pair[1]["v"]
	var seq: int = v._predict.predict("mine", AIM, Vector3.UP, "")
	var predicted: float = v.column_top_at_tile(Vector2i(32, 32))
	# Another player digs the same column first, as the host has it.
	v._on_block_changed("mine", AIM, Vector3.UP, "Soil")
	ref._on_block_changed("mine", AIM, Vector3.UP, "Soil")
	assert_true(v.column_top_at_tile(Vector2i(32, 32)) < predicted, "our prediction stands on top of their dig")
	v._predict.on_acked(seq, false)
	assert_eq(_chunk_bytes(v, HOME), _chunk_bytes(ref, HOME), "rolled back: their dig is still there, byte-equal to the host's")
	_free_client(pair[0])
	_free_client(pair[1])

func _taken(v: VoxelSlice) -> int:
	var n := 0
	for k in v._vein_taken:
		n += int(v._vein_taken[k])
	return n

func _test_predict_vein_elsewhere() -> void:
	var found := _find_surface_vein(0)
	if found.is_empty():
		assert_true(false, "a vein breaks the surface of a flat chunk somewhere")
		return
	var chunk: Vector2i = found["chunk"]
	var local: Vector2i = found["tile"]
	var vt: Vector2i = chunk * VoxelSlice.CHUNK_SIZE + local
	var vaim := Vector3((vt.x + 0.5) * VoxelSlice.TILE_SIZE, 2.0 - 0.01, (vt.y + 0.5) * VoxelSlice.TILE_SIZE)
	var pair := _pair(chunk)
	var v: VoxelSlice = pair[0]["v"]
	var ref: VoxelSlice = pair[1]["v"]
	# Our prediction: a plain dig elsewhere in the chunk, far from the vein's tile.
	var plain: Vector2i = chunk * VoxelSlice.CHUNK_SIZE + (Vector2i(40, 40) if local.x < 30 else Vector2i(4, 4))
	var paim := Vector3((plain.x + 0.5) * VoxelSlice.TILE_SIZE, 2.0 - 0.01, (plain.y + 0.5) * VoxelSlice.TILE_SIZE)
	var seq: int = v._predict.predict("mine", paim, Vector3.UP, "")
	assert_true(seq > 0, "predicted")
	# Meanwhile another player mines the vein: the host records its depletion.
	v._on_block_changed("mine", vaim, Vector3.UP, "Ore")
	ref._on_block_changed("mine", vaim, Vector3.UP, "Ore")
	assert_true(_taken(ref) > 0, "the host's dig depleted the vein")
	v._predict.on_acked(seq, false)
	assert_eq(v._vein_taken, ref._vein_taken, "the depletion survives our rollback")
	assert_eq(_chunk_bytes(v, chunk), _chunk_bytes(ref, chunk), "byte-equal to the host's state")
	# Our own dig of the same vein, then another player's, then ours refused: only theirs remains.
	var s2: int = v._predict.predict("mine", Vector3(vaim.x, vaim.y - VoxelSlice.STEP_HEIGHT, vaim.z), Vector3.UP, "")
	assert_true(s2 > 0 and _taken(v) > _taken(ref), "our predicted dig depleted the vein further")
	var other := Vector3(vaim.x + VoxelSlice.TILE_SIZE, vaim.y, vaim.z)
	v._on_block_changed("mine", other, Vector3.UP, "Ore")
	ref._on_block_changed("mine", other, Vector3.UP, "Ore")
	v._predict.on_acked(s2, false)
	assert_eq(v._vein_taken, ref._vein_taken, "only our own depletion was undone")
	assert_eq(_chunk_bytes(v, chunk), _chunk_bytes(ref, chunk), "byte-equal to the host's state")
	_free_client(pair[0])
	_free_client(pair[1])

func _test_predict_timeout_after_later_confirmed() -> void:
	var pair := _pair()
	var v: VoxelSlice = pair[0]["v"]
	var ref: VoxelSlice = pair[1]["v"]
	var clock := [1000]
	v._predict.clock_msec = func() -> int: return clock[0]
	var deeper := Vector3(AIM.x, 2.0 - VoxelSlice.STEP_HEIGHT - 0.05, AIM.z)
	var far := Vector3(20.0, 2.0, 20.0)
	var n: int = v._predict.predict("mine", AIM, Vector3.UP, "")   # dropped by the host's rate limit: never answered
	clock[0] += 100
	var n1: int = v._predict.predict("mine", deeper, Vector3.UP, "")
	var n2: int = v._predict.predict("mine", far, Vector3.UP, "")
	assert_true(n > 0 and n1 > n and n2 > n1, "three predictions")
	# The host applied N+1 alone (it never saw N), and N+2.
	var tile := Vector2i(32, 32)
	var span: Dictionary = ref._mine_span(ref.get_runs_at_tile(tile), deeper, Vector3.UP)
	ref._on_block_changed("mine", deeper, Vector3.UP, "Soil")
	v._predict.on_acked(n1, true, { "tile": tile, "bottom": float(span["bottom"]), "top": float(span["top"]) })
	v._on_block_changed("mine", deeper, Vector3.UP, "Soil")
	assert_false(v._predict.is_pending(n1), "N+1 is host state now")
	assert_true(v._predict.is_pending(n), "N still waits")
	clock[0] += EditPrediction.TIMEOUT_MSEC
	v._predict.tick()
	assert_false(v._predict.is_pending(n), "N timed out")
	ref._on_block_changed("mine", far, Vector3.UP, "Soil")
	v._predict.on_acked(n2, true, {})
	v._on_block_changed("mine", far, Vector3.UP, "Soil")
	assert_eq(v._predict.pending_count(), 0, "nothing pending")
	assert_eq(_chunk_bytes(v, HOME), _chunk_bytes(ref, HOME), "N+1's confirmed edit survived N's rollback: byte-equal to the host's")
	_free_client(pair[0])
	_free_client(pair[1])

func _test_predict_cleared_by_snapshot() -> void:
	var c := _client()
	var v: VoxelSlice = c["v"]
	var seq: int = v._predict.predict("mine", AIM, Vector3.UP, "")
	v.apply_edits({ "0,0": [{ "op": "remove", "bottom": 1.5, "top": 2.0 }] })
	assert_eq(v._predict.pending_count(), 0, "a snapshot drops every prediction")
	var after := _chunk_bytes(v, HOME)
	v._predict.on_acked(seq, false)
	v._predict.tick()
	assert_eq(_chunk_bytes(v, HOME), after, "a late refusal brings back nothing from before the snapshot")
	assert_true(v._predict.predict("mine", AIM, Vector3.UP, "") > 0, "predicted again")
	v.reset_world()
	assert_eq(v._predict.pending_count(), 0, "/regen world drops them too")
	_free_client(c)

func _test_predict_no_placed_block() -> void:
	var c := _client()
	var v: VoxelSlice = c["v"]
	v.apply_block_change("place", AIM, Vector3.UP, "Sand")   # someone's block, as the host sent it
	var top: float = v.column_top_at_tile(Vector2i(32, 32))
	assert_true(top > 2.0, "the block stands")
	assert_eq(v._predict.predict("mine", Vector3(AIM.x, top - 0.05, AIM.z), Vector3.UP, ""), 0, "a hit on it is the host's to judge")
	assert_eq(v.column_top_at_tile(Vector2i(32, 32)), top, "and it does not vanish on the client")
	_free_client(c)

func _test_predict_span_mismatch() -> void:
	var c := _client()
	var v: VoxelSlice = c["v"]
	var tile := Vector2i(32, 32)
	var seq: int = v._predict.predict("mine", AIM, Vector3.UP, "")
	var predicted: float = v.column_top_at_tile(tile)
	# The host removed a deeper span than this client derives (the copies disagree): its span is applied as is.
	v._predict.on_acked(seq, true, { "tile": tile, "bottom": 1.0, "top": 2.0 })
	v._on_block_changed("mine", AIM, Vector3.UP, "Soil")
	assert_eq(v._predict.resyncs, 1, "the host's span differed from the one derived here")
	assert_eq(v._predict.mismatches, 1, "and from the prediction")
	assert_true(v.column_top_at_tile(tile) < predicted and is_equal_approx(v.column_top_at_tile(tile), 1.0), "the column is the host's")
	# An agreeing answer changes nothing.
	var far := Vector3(20.0, 2.0, 20.0)
	var s2: int = v._predict.predict("mine", far, Vector3.UP, "")
	var t2: Vector2i = v._resolve_edit_tile("mine", far, Vector3.UP)["tile"]
	var op: Dictionary = (v._edits[VoxelSlice._tile_key(t2)] as Array).back()
	v._predict.on_acked(s2, true, { "tile": t2, "bottom": float(op["bottom"]), "top": float(op["top"]) })
	v._on_block_changed("mine", far, Vector3.UP, "Soil")
	assert_eq([v._predict.resyncs, v._predict.mismatches], [1, 1], "a matching span is no mismatch")
	_free_client(c)
