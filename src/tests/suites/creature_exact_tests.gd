extends "res://src/tests/test_support.gd"
## Phase 195 — creature positions and the snapshot path (#444, #464, #493): a creature far from the origin
## steers, flees, is found and folds on its exact `{chunk, local}`; a snapshot entry with a refused position
## keeps its hp, state and death; and source audits hold the write paths to their one owner. The send path
## (records_sent, the first dropped chunk) is in `crowd_tests.gd`; the AOI delivery is the harness step
## `creature_far_delta`.

const ExactSpatialHash := preload("res://src/core/exact_spatial_hash.gd")

## The roadmap's far chunk: 312,500 chunks east (10,000 km), where float32 world metres are a metre apart.
const FAR := Vector2i(312500, 7)

func register() -> void:
	_run_test("creature exact: a far creature steps toward a target with the origin's heading", _test_far_step_heading)
	_run_test("creature exact: a far creature flees with the origin's heading", _test_far_flee_heading)
	_run_test("creature exact: creatures_in_radius finds a creature across a far chunk seam", _test_far_radius_seam)
	_run_test("creature exact: the exact hash buckets and measures on chunk + local", _test_exact_hash)
	_run_test("creature exact: a fold-log replay far out restores the exact chunk and local", _test_far_fold_log_replay)
	_run_test("creature exact: fold_contents folds the exact pair far out", _test_far_fold_contents)
	_run_test("creature exact: an entry with a refused position still applies hp, state and death", _test_refused_pos_keeps_fields)
	_run_test("creature exact: a huge chunk, a NaN local or a non-number is refused from save or wire", _test_entry_pos_refuses)
	_run_test("creature exact: the death fall starts from an exact position across a rebase", _test_fall_survives_rebase)
	_run_test("creature exact: the far-peak verdict needs a rock/snow share", _test_far_peak_share)
	_run_test("creature exact: a dropped carcass lands at its carrier's host position", _test_carcass_drop_at_carrier)
	_run_test("creature exact (audit): the harness sends snapshots through SnapshotWiring", _test_audit_harness_snapshot)
	_run_test("creature exact (audit): only _store_pos writes a creature's position", _test_audit_store_pos)
	_run_test("creature exact (audit): the playtest bot never touches _carcasses", _test_audit_bot_carcasses)

# --- fixtures ---------------------------------------------------------------------------------------------

## A slice and an AI over it with one boar at `pos` (no surface: the AI steps straight).
func _rig(pos: Dictionary) -> Dictionary:
	var c := CreatureSlice.new()
	add_child(c)
	c.apply_creature_pos("b0", "ForestBoar", "idle", pos, 50.0)
	var ai := CreatureAI.new()
	ai.creature_slice = c
	return {"c": c, "ai": ai}

func _free(rig: Dictionary) -> void:
	(rig["ai"] as Node).free()
	(rig["c"] as Node).free()

## The angle in degrees between two XZ vectors.
func _angle(a: Vector3, b: Vector3) -> float:
	return rad_to_deg(absf(Vector2(a.x, a.z).angle_to(Vector2(b.x, b.z))))

## The displacement one AI move gives the boar standing at `start`, with the player at `start + offset`.
func _moved(start: Dictionary, offset: Vector3, flee: bool) -> Vector3:
	var rig := _rig(start)
	var c: Node = rig["c"]
	var ai: Node = rig["ai"]
	var target := WorldPos.normalized({"chunk": start["chunk"], "local": (start["local"] as Vector3) + offset})
	ai._exact_targets = {"player": target}
	var inst: Dictionary = c._instances["b0"]
	var player_world := WorldPos.to_scene(target, Vector2i.ZERO)   # float32-coarse far out: must not steer
	if flee:
		ai._flee("b0", inst, player_world, 0.1, "player")
	else:
		ai._step_toward(inst, "b0", player_world, 4.0, 0.1, target)
	var out := WorldPos.offset_between(start, c.get_instance_pos("b0"))
	_free(rig)
	return out

# --- tests ------------------------------------------------------------------------------------------------

func _test_far_step_heading() -> void:
	var offset := Vector3(3.3, 0.0, 7.1)
	var near := _moved({"chunk": Vector2i(0, 7), "local": Vector3(10.25, 2.0, 10.75)}, offset, false)
	var far := _moved({"chunk": FAR, "local": Vector3(10.25, 2.0, 10.75)}, offset, false)
	assert_true(near.length() > 0.1, "the boar at the origin moved")
	assert_true(_angle(near, far) < 0.1, "the far step has the origin's heading (%.4f°)" % _angle(near, far))
	assert_true(absf(near.length() - far.length()) < 1.0e-3, "and its length")

func _test_far_flee_heading() -> void:
	var offset := Vector3(-2.2, 0.0, 1.3)
	var near := _moved({"chunk": Vector2i(0, 7), "local": Vector3(16.5, 2.0, 16.5)}, offset, true)
	var far := _moved({"chunk": FAR, "local": Vector3(16.5, 2.0, 16.5)}, offset, true)
	assert_true(near.length() > 0.1, "the boar at the origin fled")
	assert_true(Vector2(near.x, near.z).dot(Vector2(offset.x, offset.z)) < 0.0, "away from the player")
	assert_true(_angle(near, far) < 0.1, "the far flight has the origin's heading (%.4f°)" % _angle(near, far))

func _test_far_radius_seam() -> void:
	var c := CreatureSlice.new()
	add_child(c)
	var a := {"chunk": FAR, "local": Vector3(31.8, 2.0, 5.0)}
	var b := {"chunk": FAR + Vector2i(1, 0), "local": Vector3(0.3, 2.0, 5.0)}   # 0.5 m east, over the seam
	c.apply_creature_pos("a", "ForestBoar", "idle", a)
	c.apply_creature_pos("b", "ForestBoar", "idle", b)
	var hits: Array = c.creatures_in_radius(a, 0.6)
	assert_true(hits.has("a") and hits.has("b"), "both sides of the seam are within 0.6 m")
	assert_false(c.creatures_in_radius(a, 0.4).has("b"), "and the neighbour is not within 0.4 m")
	assert_eq(c.nearest_creature(b, 0.2), "b", "nearest takes an exact position too")
	c.free()

func _test_exact_hash() -> void:
	var h := ExactSpatialHash.new()
	var p := {"chunk": FAR, "local": Vector3(7.9, 0.0, 8.1)}
	assert_eq(ExactSpatialHash.cell_of(p), Vector2i(FAR.x * 4, FAR.y * 4 + 1), "the cell is integer chunk arithmetic")
	h.insert("x", p)
	h.update("x", {"chunk": FAR, "local": Vector3(8.1, 0.0, 8.1)})
	assert_eq(h.size(), 1, "an update moves, it does not add")
	assert_true(h.query_radius({"chunk": FAR, "local": Vector3(8.0, 0.0, 8.1)}, 0.15).has("x"), "found 0.1 m away")
	h.remove("x")
	assert_eq(h.size(), 0, "and removed")
	# A body-sized query probes only the cells its square overlaps (separate_bodies runs one per creature
	# per frame), and still finds a neighbour across a chunk edge on the exact offset.
	h.insert("w", {"chunk": FAR, "local": Vector3(0.3, 0.0, 12.0)})
	h.insert("e", {"chunk": FAR - Vector2i(1, 0), "local": Vector3(WorldPos.CHUNK_METERS - 0.3, 0.0, 12.0)})
	var before := h.probes
	var near := h.query_radius({"chunk": FAR, "local": Vector3(4.0, 0.0, 12.0)}, 2.5)
	assert_eq(h.probes - before, 1, "a 2.5 m query inside one 8 m cell probes that cell alone")
	assert_true(near.is_empty(), "and holds nothing 3.7 m away")
	before = h.probes
	var edge := h.query_radius({"chunk": FAR, "local": Vector3(0.1, 0.0, 12.0)}, 0.5)
	assert_eq(h.probes - before, 2, "across the chunk edge it probes the cell on each side")
	assert_true(edge.has("w") and edge.has("e"), "and finds both neighbours on the exact offset")

func _test_far_fold_log_replay() -> void:
	var c := CreatureSlice.new()
	c.is_authoritative = false
	add_child(c)
	c._log_fold(true, 1)
	var host := {"chunk": FAR, "local": Vector3(12.34, 3.0, 20.56)}
	c.apply_creature_pos("r0", "ForestBoar", "idle", host)
	var want := TerrainSlice.fold_world_pos_like(host, true, 1)
	var got: Dictionary = c.get_instance_pos("r0")
	assert_eq(got["chunk"], want["chunk"], "the replay lands on the fold's exact chunk")
	assert_true(((got["local"] as Vector3) - (want["local"] as Vector3)).length() < 1.0e-4, "and its local")
	assert_true(c.creatures_in_radius(want, 0.05).has("r0"), "and the hash holds it there")
	c.free()

func _test_far_fold_contents() -> void:
	var c := CreatureSlice.new()
	add_child(c)
	var at := {"chunk": FAR, "local": Vector3(1.25, 4.0, 30.5)}
	c.apply_creature_pos("f0", "ForestBoar", "idle", at)
	c.fold_contents(true, -1)
	var want := TerrainSlice.fold_world_pos_like(at, true, -1)
	var got: Dictionary = c.get_instance_pos("f0")
	assert_eq(got["chunk"], want["chunk"], "the carried creature is on the fold's exact chunk")
	assert_true(((got["local"] as Vector3) - (want["local"] as Vector3)).length() < 1.0e-4, "and local")
	assert_eq(c._instances["f0"]["chunk"], want["chunk"], "filed under it")
	assert_true(c.creatures_in_radius(want, 0.05).has("f0"), "and hashed there")
	c.free()

func _test_refused_pos_keeps_fields() -> void:
	var c := CreatureSlice.new()
	add_child(c)
	var at := {"chunk": FAR, "local": Vector3(5.0, 2.0, 5.0)}
	c.apply_creature_pos("k0", "ForestBoar", "idle", at, 50.0)
	c.apply_creature_pos("k1", "ForestBoar", "idle", at, 50.0)
	var deadline := Time.get_unix_time_from_system() + 120.0
	# Client path (a snapshot): a huge chunk.
	c.apply_snapshot_creatures([{"instance_id": "k0", "creature_id": "ForestBoar", "state": "dead", "hp": 0.0,
		"respawn_at": deadline, "position": {"chunk": [999999999, 0], "local": [1.0, 2.0, 3.0]}}])
	var k0: Dictionary = c._instances["k0"]
	assert_eq(k0["state"], "dead", "the death applies")
	assert_eq(float(k0["hp"]), 0.0, "and the hp")
	assert_eq(float(k0["respawn_at"]), deadline, "and the respawn deadline")
	assert_eq(c.get_instance_pos("k0"), at, "the creature stays where it was")
	# Host path (the world record): no position at all.
	c.apply_recorded_creature_states([{"instance_id": "k1", "creature_id": "ForestBoar", "state": "aggressive", "hp": 12.0}])
	assert_eq(c._instances["k1"]["state"], "aggressive", "a recorded state applies without a position")
	assert_eq(float(c._instances["k1"]["hp"]), 12.0, "and its hp")
	assert_eq(c.get_instance_pos("k1"), at, "in place")
	# A held death with a refused position survives a save round trip with no position.
	c.apply_recorded_creature_states([{"instance_id": "away", "creature_id": "ForestBoar", "state": "dead",
		"respawn_at": deadline, "position": {"chunk": [0, 0], "local": [NAN, 0.0, 0.0]}}])
	var saved: Array = c.get_snapshot_creatures().filter(func(e): return e["instance_id"] == "away")
	assert_eq(saved.size(), 1, "the held death is saved")
	assert_false((saved[0] as Dictionary).has("position"), "with no position")
	c.free()

func _test_entry_pos_refuses() -> void:
	var ok := WorldPos.pos_to_wire({"chunk": FAR, "local": Vector3(1.0, 2.0, 3.0)})
	assert_eq(CreatureSlice._entry_pos({"position": ok})["chunk"], FAR, "a plausible far entry decodes")
	assert_false(CreatureSlice._entry_pos({"position": [100.0, 2.0, 3.0]}).is_empty(), "a legacy array decodes")
	for bad in [
		{"chunk": [999999999, 0], "local": [1.0, 2.0, 3.0]},
		{"chunk": [0, 0], "local": [NAN, 2.0, 3.0]},
		{"chunk": [0, 0], "local": [INF, 2.0, 3.0]},
		{"chunk": [0.5, 0], "local": [1.0, 2.0, 3.0]},
		[NAN, 2.0, 3.0],
		["1", 2.0, 3.0],
		[1.0e30, 0.0, 0.0],
		[1.0, 2.0],
		"garbage",
	]:
		assert_true(CreatureSlice._entry_pos({"position": bad}).is_empty(), "refused: %s" % str(bad))
	assert_true(CreatureSlice._entry_pos({}).is_empty(), "no position is refused")

func _test_fall_survives_rebase() -> void:
	var v := CreatureSlice.CreatureVisuals.new()
	add_child(v)
	var m := {"fall_from": v.pos_of_scene(Vector3(3.0, 1.0, 4.0))}
	var before: Vector3 = v.fall_start(m)
	var shift := Vector3(-64.0, 0.0, 32.0)
	v.shift_scene(shift)
	assert_true((v.fall_start(m) - (before + shift)).length() < 1.0e-4, "the fall's start moves with the frame")
	v.free()

func _test_far_peak_share() -> void:
	var Bot: GDScript = load("res://src/tests/playtest_bot.gd")
	assert_true(Bot.far_peak_passes(904, 486), "the pinned seed's far peak passes")
	assert_false(Bot.far_peak_passes(900, 20), "a hill of green with a few grey pixels does not")
	assert_false(Bot.far_peak_passes(20, 7), "too few rock pixels does not")

func _test_carcass_drop_at_carrier() -> void:
	var gr: Node = (load("res://src/core/game_root.gd") as GDScript).new()
	var sl := CarcassSlice.new()
	add_child(sl)
	gr._carcass = sl
	var at := [Vector3(10.0, 0.0, 0.0)]
	var w = gr._carcass_wiring
	w.position_probe = func(_pid: String) -> Variant: return at[0]
	var id: String = sl.create_for_death("ForestBoar", Vector3(9.0, 0.0, 0.0), "p1")
	assert_eq(sl.carry(id, "p1", Vector3(9.0, 0.0, 0.0), 10, 1000.0), "", "p1 takes the body")
	assert_eq(w.drop_point("p1", id), at[0], "a carrier in reach drops the body at its own host position")
	at[0] = Vector3(400.0, 0.0, 0.0)
	assert_eq(w.drop_point("p1", id), sl.position_of(id), "a carrier past the leash leaves it where it is")
	w.position_probe = func(_pid: String) -> Variant: return null
	assert_eq(w.drop_point("p1", id), sl.position_of(id), "an unknown carrier position leaves it too")
	sl.free()
	gr.free()

## Lines of `path` that match `re`, with their numbers.
func _matching_lines(path: String, re: RegEx) -> Array:
	var out: Array = []
	var lines := FileAccess.get_file_as_string(path).split("\n")
	for i in lines.size():
		if re.search(lines[i]) != null:
			out.append("%s:%d" % [path.get_file(), i + 1])
	return out

func _test_audit_harness_snapshot() -> void:
	var re := RegEx.create_from_string("_networking\\.send_snapshot\\(")
	assert_eq(_matching_lines("res://src/tests/net_harness.gd", re), [], "net_harness.gd never calls _networking.send_snapshot")

func _test_audit_store_pos() -> void:
	# A subscript write of a record's `pos` / `position` / spawn pair.
	var re := RegEx.create_from_string("(\\binst|_instances\\[[^\\]]+\\])\\[\"(pos|position|spawn_pos|spawn_exact)\"\\]\\s*=[^=]")
	var lines := FileAccess.get_file_as_string("res://src/creature/creature_slice.gd").split("\n")
	var stray: Array = []
	var in_owner := false
	for i in lines.size():
		var line: String = lines[i]
		if line.begins_with("static func _store_pos(") or line.begins_with("static func _store_spawn("):
			in_owner = true
		elif line.begins_with("func ") or line.begins_with("static func "):
			in_owner = false
		if re.search(line) != null and not in_owner:
			stray.append("creature_slice.gd:%d" % (i + 1))
	assert_eq(stray, [], "nothing in the slice outside _store_pos/_store_spawn writes a creature's position")
	var literal := RegEx.create_from_string("^\\s*\"(pos|position|spawn_pos|spawn_exact)\":")
	var in_record := false
	var stray_literal: Array = []
	for i in lines.size():
		if lines[i].contains("_instances[") and lines[i].contains("] = {"):
			in_record = true
		elif in_record and lines[i].strip_edges() == "}":
			in_record = false
		elif in_record and literal.search(lines[i]) != null:
			stray_literal.append("creature_slice.gd:%d" % (i + 1))
	assert_eq(stray_literal, [], "no instance record literal sets a position: _store_pos does")
	var outside := RegEx.create_from_string("_instances\\[[^\\]]+\\]\\[\"(pos|position)\"\\]\\s*=[^=]")
	for path in ["res://src/creature/creature_ai.gd", "res://src/creature/creature_visuals.gd", "res://src/creature/taming_slice.gd",
			"res://src/tests/playtest_bot.gd", "res://src/tests/net_harness.gd"]:
		assert_eq(_matching_lines(path, outside), [], "%s never writes a creature's position" % path.get_file())

func _test_audit_bot_carcasses() -> void:
	var re := RegEx.create_from_string("_carcasses")
	assert_eq(_matching_lines("res://src/tests/playtest_bot.gd", re), [], "playtest_bot.gd never reaches into _carcasses")
