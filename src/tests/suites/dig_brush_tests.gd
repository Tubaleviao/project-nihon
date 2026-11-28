extends "res://src/tests/test_support.gd"
## Phase 300 — digging with a brush: the pure rasteriser (`DigBrush`), the host's dig and yield by volume
## (`VoxelDig`), the wire op and the client's prediction of the whole brush.

const DigBrush := preload("res://src/terrain/dig_brush.gd")
const VoxelDig := preload("res://src/terrain/voxel_dig.gd")
const WorkSkillsRef := preload("res://src/character/work_skills.gd")
const WorkTimeRef := preload("res://src/core/work_time.gd")
const RecordSanitize := preload("res://src/persistence/record_sanitize.gd")

const HOME := Vector2i(0, 0)
const AIM := Vector3(16.25, 2.0, 16.25)   # the middle of tile (32, 32) on the flat 2 m chunk

func register() -> void:
	_run_test("dig brush: a 1 m sphere dug into flat ground removes about a half sphere", _test_sphere_volume)
	_run_test("dig brush: no column outside the brush bounds changes, and the order is fixed", _test_bounds_and_order)
	_run_test("dig brush: a placed block inside the bounds is untouched", _test_placed_block_untouched)
	_run_test("dig brush: the cut stops at bedrock", _test_bedrock)
	_run_test("dig brush: a shovel dig into rock removes no rock, a pick's does", _test_shovel_rock)
	_run_test("dig brush: a side dig into a cliff leaves a roof run above the hole", _test_side_dig_roof)
	_run_test("dig brush: shapes and the smooth rim (cylinder, box, k) cut what their distance says", _test_shapes_and_blend)
	_run_test("dig brush: 20 small digs and one large dig of the same volume yield the same, a vein's reserve falls by the yield", _test_yield_conservation)
	_run_test("dig brush: the yield remainder is saved with the player and sanitised", _test_remainder_saved)
	_run_test("dig brush: the host plans the radius from its own tool and tier, a client's op is bounded", _test_host_plans_radius)
	_run_test("dig brush: a host dig digs the ground, banks the yield by volume and broadcasts one op", _test_host_dig)
	_run_test("dig brush: a client applies the wire op to the same logs as the host", _test_wire_logs_match)
	_run_test("dig brush: a client predicts the whole brush, and the host's op confirms it without applying twice", _test_prediction)
	_run_test("dig brush: a brush dig takes the time of its volume", _test_work_time)

# --- fixtures -------------------------------------------------------------------

## Natural columns for tiles `[x0, x1] x [z0, z1]`, each one run `[bottom, top]` (mm).
func _columns(x0: int, x1: int, z0: int, z1: int, bottom: int, top: int) -> Dictionary:
	var out: Dictionary = {}
	for tx in range(x0, x1 + 1):
		for tz in range(z0, z1 + 1):
			out[Vector2i(tx, tz)] = PackedInt32Array([bottom, top])
	return out

func _classify_as(material: String) -> Callable:
	return func(_tx: int, _tz: int, _b: int) -> Dictionary: return { "material": material, "vein": {} }

func _cells(result: Dictionary) -> int:
	var n := 0
	for t in result["tiles"]:
		var spans: PackedInt32Array = t[2]
		for i in range(0, spans.size(), 2):
			n += (spans[i + 1] - spans[i]) / DigBrush.STEP_MM
	return n

func _op(shape: String, cx: int, cy: int, cz: int, r: int, k: int = 0) -> Dictionary:
	return { "shape": shape, "centre": [cx, cy, cz], "radius": r, "k": k }

## A flat host slice with the brush on.
func _brush_voxel() -> VoxelSlice:
	var v := _make_voxel()
	v._edit.brush_enabled = true
	return v

func _inventory(v: VoxelSlice, items: Dictionary = {}) -> InventorySlice:
	var inv := InventorySlice.new()
	add_child(inv)
	v.inventory_slice = inv
	for k in items:
		inv.add_item(k, int(items[k]))
	return inv

## The flat chunk's own natural runs of a tile, as the dig sees them.
func _runs(v: VoxelSlice, tx: int, tz: int) -> Array:
	return v.get_runs_at_tile(Vector2i(tx, tz))

# --- the rasteriser ---------------------------------------------------------------

func _test_sphere_volume() -> void:
	# A sphere centred on the surface cuts a half sphere of the ground (centred on a tile corner, so the tiles are
	# sampled evenly round it; centred on a tile's middle the 0.5 m grid takes a tenth less).
	var cols := _columns(-8, 8, -8, 8, -50000, 2000)
	var res := DigBrush.rasterise(_op("sphere", 0, 2000, 0, 1000), cols, _classify_as("Soil"), { "Soil": true })
	var vol := float(_cells(res)) * 0.03125
	var half := 2.0 / 3.0 * PI   # r = 1 m
	assert_true(absf(vol - half) / half < 0.05, "volume %.3f m3 is within 5%% of the half sphere %.3f m3" % [vol, half])
	assert_eq(int((res["volume"] as Dictionary)["Soil"]), _cells(res), "the per-material volume counts the same cells")
	# The native twin's entry point: plain arrays in, plain arrays out.
	var cells := DigBrush.cut_cells(_op("sphere", 0, 2000, 0, 1000), cols)
	assert_true(cells[0] is Array and cells[0][2] is PackedInt32Array, "tiles come back as [tx, tz, PackedInt32Array]")

func _test_bounds_and_order() -> void:
	var op := _op("sphere", 750, 1000, -250, 600, 250)
	var cols := _columns(-20, 20, -20, 20, -50000, 2000)
	var res := DigBrush.rasterise(op, cols, _classify_as("Soil"), { "Soil": true })
	var b := DigBrush.bounds(op)
	var last := Vector2i(-1000000, -1000000)
	assert_true(not (res["tiles"] as Array).is_empty(), "something is cut")
	for t in res["tiles"]:
		assert_true(t[0] >= b[0] and t[0] <= b[1] and t[1] >= b[2] and t[1] <= b[3], "tile %d,%d is inside the bounds" % [t[0], t[1]])
		var here := Vector2i(t[0], t[1])
		assert_true(here.x > last.x or (here.x == last.x and here.y > last.y), "tiles come tx ascending, then tz ascending")
		last = here
		var spans: PackedInt32Array = t[2]
		for i in range(0, spans.size(), 2):
			assert_true(spans[i] < spans[i + 1] and (i == 0 or spans[i] > spans[i - 1]), "spans ascend and merge")
	assert_eq(DigBrush.rasterise(op, cols, _classify_as("Soil"), { "Soil": true }), res, "the same op over the same runs gives the same result")
	# On the slice: a dig changes no tile outside the bounds.
	var v := _brush_voxel()
	_inventory(v)
	var before: Dictionary = v._edits.duplicate(true)
	var r := v.mine_block(AIM, Vector3.UP, "")
	assert_true(bool(r.get("success", false)), "bare hands dig soil with the brush")
	var plan: Dictionary = v._edit._dig.plan(AIM, Vector3.UP, "")
	var pb := DigBrush.bounds(plan["op"])
	for key in v._edits:
		var t: Vector2i = v._key_to_tile(key)
		assert_true(t.x >= pb[0] and t.x <= pb[1] and t.y >= pb[2] and t.y <= pb[3], "only tiles in the bounds were edited (%s)" % key)
	assert_true(v._edits.size() > before.size(), "tiles were edited")
	v.inventory_slice.free()
	v.free()

func _test_placed_block_untouched() -> void:
	var v := _brush_voxel()
	_inventory(v, { "StoneShovel": 1 })
	var near := Vector2i(33, 32)
	v._append_edit(near, { "op": "add", "bottom": 2.0, "top": 2.125, "material": "Stone" })
	var placed_before: Array = _runs(v, near.x, near.y).filter(func(r: Dictionary) -> bool: return str(r["material"]) != "")
	var r := v.mine_block(AIM, Vector3.UP, "")
	assert_true(bool(r.get("success", false)), "the shovel dig succeeds")
	var placed_after: Array = _runs(v, near.x, near.y).filter(func(x: Dictionary) -> bool: return str(x["material"]) != "")
	assert_eq(placed_after, placed_before, "the placed block beside the dug column is exactly as it was")
	var natural_after: Array = _runs(v, near.x, near.y).filter(func(x: Dictionary) -> bool: return str(x["material"]) == "")
	assert_true(not natural_after.is_empty() and float(natural_after[0]["top"]) < 2.0, "the natural ground under it was cut")
	v.inventory_slice.free()
	v.free()

func _test_bedrock() -> void:
	var cols := _columns(-4, 4, -4, 4, -100000, -90000)
	var res := DigBrush.rasterise(_op("sphere", 250, -96000, 250, 1500), cols, _classify_as("Ferrite"), { "Ferrite": true })
	assert_true(_cells(res) > 0, "ground above bedrock is cut")
	for t in res["tiles"]:
		assert_true((t[2] as PackedInt32Array)[0] >= DigBrush.BEDROCK_MM, "no cell below BEDROCK_DEPTH")

func _test_shovel_rock() -> void:
	var cols := _columns(-4, 4, -4, 4, -50000, 2000)
	var op := _op("sphere", 250, 1500, 250, 750)
	var shovel := DigBrush.rasterise(op, cols, _classify_as("Ferrite"), VoxelDig.cuts_of("StoneShovel"))
	assert_eq((shovel["tiles"] as Array).size(), 0, "a shovel dig into rock removes no rock")
	var pick := DigBrush.rasterise(op, cols, _classify_as("Ferrite"), VoxelDig.cuts_of("StonePick"))
	assert_true(_cells(pick) > 0, "a pick cuts it")
	var soil := DigBrush.rasterise(op, cols, func(_a: int, _b: int, cb: int) -> Dictionary:
		return { "material": "Soil" if cb >= 1500 else "Ferrite", "vein": {} }, VoxelDig.cuts_of("StoneShovel"))
	assert_true(_cells(soil) > 0, "the soil layer of a mixed face is cut")
	for t in soil["tiles"]:
		assert_true((t[2] as PackedInt32Array)[0] >= 1500, "and the rock under it stays")
	assert_true(VoxelDig.cuts_of("hands").has("Soil") and not VoxelDig.cuts_of("hands").has("Ferrite"), "bare hands cut soil, not rock")

func _test_side_dig_roof() -> void:
	# A wall: tiles x >= 0 hold ground up to 2 m, x < 0 is air. A hit on its face at 1 m, normal -x.
	var cols := _columns(0, 12, -6, 6, -50000, 2000)
	var op := DigBrush.make_op("sphere", Vector3(0.0, 1.0, 0.25), Vector3(-1, 0, 0), 600, 0)
	assert_true(int(op["centre"][0]) > 0, "the centre is pushed into the wall")
	var res := DigBrush.rasterise(op, cols, _classify_as("Soil"), { "Soil": true })
	assert_true(_cells(res) > 0, "the face is dug sideways")
	var roof := false
	var through := false
	for t in res["tiles"]:
		var spans: PackedInt32Array = t[2]
		if spans[spans.size() - 1] < 2000:
			roof = true
		if spans[0] > -50000 and spans[spans.size() - 1] < 2000:
			through = true
	assert_true(roof and through, "a hole with ground above it and below it: the tunnel keeps its roof run")

func _test_shapes_and_blend() -> void:
	var cols := _columns(-6, 6, -6, 6, -50000, 2000)
	var all := { "Soil": true }
	var cyl := DigBrush.rasterise(_op("cylinder", 0, 1000, 0, 800), cols, _classify_as("Soil"), all)
	var box := DigBrush.rasterise(_op("box", 0, 1000, 0, 800), cols, _classify_as("Soil"), all)
	var sph := DigBrush.rasterise(_op("sphere", 0, 1000, 0, 800), cols, _classify_as("Soil"), all)
	assert_true(_cells(box) > _cells(cyl) and _cells(cyl) > _cells(sph), "a box cuts more than a cylinder, which cuts more than a sphere")
	var sharp := _cells(DigBrush.rasterise(_op("sphere", 0, 2000, 0, 1000, 0), cols, _classify_as("Soil"), all))
	var eased := _cells(DigBrush.rasterise(_op("sphere", 0, 2000, 0, 1000, 250), cols, _classify_as("Soil"), all))
	assert_true(eased <= sharp and eased > sharp * 8 / 10, "the blend eases the rim a little, never adds ground to the hole")
	assert_eq(DigBrush.problem(_op("sphere", 0, 0, 0, 750), 1500), "", "a sane op passes")
	assert_eq(DigBrush.problem(_op("sphere", 0, 0, 0, 9000), 1500), "radius", "a radius over the cap is refused")
	assert_eq(DigBrush.problem(_op("blob", 0, 0, 0, 500), 1500), "shape", "an unknown shape is refused")

# --- yield by volume ----------------------------------------------------------------

## A result with `cells` cells of `material` and no veins.
func _res_of(material: String, cells: int) -> Dictionary:
	return { "tiles": [], "volume": { material: cells }, "veins": {} }

func _with_unit_volume(vol: float, fn: Callable) -> void:
	var res: Resource = GameData.WORLD_SYSTEMS["DigBrushes"]
	var saved: Variant = (res.get("unitVolume") as Dictionary).duplicate(true)
	res.set("unitVolume", { "default": vol, "overrides": {} })
	fn.call()
	res.set("unitVolume", saved)

func _test_yield_conservation() -> void:
	_with_unit_volume(0.03125 * 3.0, func() -> void:
		var v := _brush_voxel()
		var dig: RefCounted = v._edit._dig
		var small_total := 0
		var rem: Dictionary = {}
		var cells_total := 0
		for i in 20:
			var n := 1 + (i * 7) % 5
			cells_total += n
			var y: Dictionary = dig.yield_of(_res_of("Soil", n), rem)
			rem = y["remainders"]
			small_total += int((y["units"] as Dictionary).get("Soil", 0))
		var big: Dictionary = dig.yield_of(_res_of("Soil", cells_total), {})
		assert_eq(small_total, int(big["units"]["Soil"]), "20 small digs and one large dig of the same volume yield the same quantity")
		assert_eq(small_total, cells_total / 3, "which is the volume over the unit volume, floored")
		# A vein: its reserve falls by exactly what was yielded, and never below zero.
		var vein := { "id": "t,1,1", "material": "Aethermite", "reserve": 9, "quantity": 2, "anchor": Vector2i(0, 0) }
		var paid := 0
		rem = {}
		for i in 12:
			var r := { "tiles": [], "volume": {}, "veins": { "t,1,1": { "vein": vein, "cells": 2 } } }
			var yy: Dictionary = dig.yield_of(r, rem)
			rem = yy["remainders"]
			var got := int((yy["units"] as Dictionary).get("Aethermite", 0))
			var took := int((yy["deplete"] as Dictionary).get("t,1,1", 0))
			assert_true(took <= got, "a vein pays no more than it yielded")
			paid += took
			v._vein_taken["t,1,1"] = int(v._vein_taken.get("t,1,1", 0)) + took
		assert_eq(int(v._vein_taken["t,1,1"]), paid, "the depletion is what was paid")
		assert_true(paid <= 9 and v.OreField.remaining(vein, v._vein_taken) == 9 - paid, "the reserve fell by the yield, not past empty")
		assert_eq(paid, 9, "a vein dug long enough pays out its whole reserve")
		v.free())

func _test_remainder_saved() -> void:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.ensure_player("p1")
	assert_eq(reg.get_record("p1")["dig_remainder"], {}, "a new character has no remainder")
	reg.get_record("p1")["dig_remainder"] = { "Soil": 0.5, "Aethermite": 1.0 / 3.0 }
	var data: Dictionary = reg.get_player_data("p1")
	var reg2 := PlayerRegistry.new()
	add_child(reg2)
	reg2.apply_player_data("p2", data)
	var back: Dictionary = reg2.get_record("p2")["dig_remainder"]
	assert_eq(back, { "Soil": 0.5, "Aethermite": 1.0 / 3.0 }, "the remainder is restored with the player")
	assert_eq(RecordSanitize.sanitize_remainders({ "Soil": 7.0, "": 0.1, "X": "nope", "Y": NAN, "Z": -1 }), { "Soil": 0.999999, "Z": 0.0 },
		"a saved remainder is bounded to [0, 1) and bad entries dropped")
	assert_eq(RecordSanitize.sanitize_remainders("junk"), {}, "a non-dictionary restores empty")
	reg.free()
	reg2.free()

# --- the host -----------------------------------------------------------------------

func _test_host_plans_radius() -> void:
	var v := _brush_voxel()
	var inv := _inventory(v, { "StoneShovel": 1 })
	var dig: RefCounted = v._edit._dig
	var p: Dictionary = dig.plan(AIM, Vector3.UP, "")
	var fab: Dictionary = VoxelDig.brush_of("StoneShovel")
	assert_eq(str(p["tool"]), "StoneShovel", "the held shovel picks the brush")
	assert_eq(int(p["op"]["radius"]), roundi(float(fab["radius"]) * 1000.0), "at novice the radius is the fabric's")
	assert_eq(str(p["op"]["shape"]), str(fab["shape"]), "and so is the shape")
	assert_eq(p["op"]["centre"][0] % 500, 250, "the centre is quantised to the middle of its tile")
	assert_eq(int(p["op"]["centre"][1]) % 125, 0, "and to a step in height")
	# A client's wire op is bounded: a radius over the cap, a made-up tool, a far-off centre.
	var good := VoxelDig.encode(p["op"], "StoneShovel", {})
	assert_true(not VoxelDig.decode(good).is_empty(), "the host's own op decodes")
	var big: Dictionary = (p["op"] as Dictionary).duplicate(true)
	big["radius"] = 50000
	assert_true(VoxelDig.decode(VoxelDig.encode(big, "StoneShovel", {})).is_empty(), "a radius over the fabric cap is refused")
	assert_true(VoxelDig.decode(VoxelDig.encode(p["op"], "DiamondShovel", {})).is_empty(), "a tool the fabric has no brush for is refused")
	assert_true(VoxelDig.decode("sphere|750|250|StoneShovel|1,2|").is_empty(), "a malformed op is refused")
	var far := v._apply_edit("dig", Vector3(0, 0, 0), Vector3.UP, VoxelDig.encode(p["op"], "StoneShovel", {}))
	assert_false(bool(far.get("applied", true)), "a centre nowhere near its stated position is not applied")
	# Skill grows the radius up to the cap, from the host's own record.
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.ensure_player("p1")
	v.player_registry = reg
	v.set_meta("p", 0)
	var skill := WorkSkillsRef.bonus_skill("dig", "speed")
	reg.record_skill("p1", skill, "master")
	var inv2: Node = reg.get_inventory("p1")
	inv2.add_item("StoneShovel", 1)
	var pm: Dictionary = dig.plan(AIM, Vector3.UP, "p1")
	var want := mini(roundi((float(fab["radius"]) + 4.0 * float(GameData.WORLD_SYSTEMS["DigBrushes"].get("skillRadiusPerTier"))) * 1000.0),
		VoxelDig.radius_cap_mm())
	assert_eq(int(pm["op"]["radius"]), want, "a master digs a larger brush, up to the cap")
	assert_true(int(pm["op"]["radius"]) <= VoxelDig.radius_cap_mm(), "never past it")
	v.player_registry = null
	reg.free()
	inv.free()
	v.free()

func _test_host_dig() -> void:
	var v := _brush_voxel()
	var inv := _inventory(v, { "StoneShovel": 1 })
	var changes: Array = []
	var spans: Array = []
	var on_changed := func(a: String, p: Vector3, n: Vector3, m: String) -> void: changes.append([a, p, n, m])
	var on_span := func(t: Vector2i, b: float, top: float) -> void: spans.append([t, b, top])
	GameBus.block_changed.connect(on_changed)
	GameBus.block_edit_span.connect(on_span)
	var r := v.mine_block(AIM, Vector3.UP, "")
	GameBus.block_changed.disconnect(on_changed)
	GameBus.block_edit_span.disconnect(on_span)
	assert_true(bool(r["success"]), "the dig succeeded")
	assert_eq(changes.size(), 1, "one block_changed for the whole brush")
	assert_eq(str(changes[0][0]), "dig", "with the dig action")
	assert_eq(spans.size(), 1, "and one edit span")
	var soil := inv.get_item_count("Soil") + inv.get_item_count("Grass")
	assert_true(soil > 8, "a shovelful yields many units (%d)" % soil)
	var removed := 0.0
	for key in v._edits:
		for op in v._edits[key]:
			if str(op.get("op", "")) == "remove":
				removed += (float(op["top"]) - float(op["bottom"])) * 0.25
	var units := 0
	for m in r["units"]:
		units += int(r["units"][m])
	assert_true(absf(removed / 0.03125 - float(units)) < 1.5, "%.1f cells removed, %d units yielded: the yield is the volume over the unit volume" % [removed / 0.03125, units])
	assert_true(int(r["banked"]) <= units and int(r["banked"]) > 0, "a pack that cannot hold it all takes what fits")
	# Hands: the brush is smaller. The old single slab stays the smallest case.
	var hands := _brush_voxel()
	_inventory(hands)
	var hp: Dictionary = hands._edit._dig.plan(AIM, Vector3.UP, "")
	assert_true(int(hp["op"]["radius"]) < int(v._edit._dig.plan(AIM, Vector3.UP, "")["op"]["radius"]), "bare hands dig a smaller brush than the shovel")
	hands._edit.brush_enabled = false
	hands.mine_block(AIM, Vector3.UP, "")
	var slab_ops := 0
	for key in hands._edits:
		slab_ops += (hands._edits[key] as Array).size()
	assert_eq(slab_ops, 1, "with the brush off a dig is the single slab")
	hands.inventory_slice.free()
	hands.free()
	inv.free()
	v.free()

func _test_work_time() -> void:
	var v := _brush_voxel()
	_inventory(v, { "StoneShovel": 1 })
	var t: Dictionary = v._edit._dig.work_target(AIM, Vector3.UP, "")
	assert_true(not t.is_empty() and float(t["seconds"]) > 0.0, "a brush dig has a work time")
	var slab: float = WorkTimeRef.duration(str(t["material"]), "dig", "StoneShovel", "novice", "dig")
	assert_true(float(t["seconds"]) > slab, "more volume takes longer than one slab (%.2f s vs %.2f s)" % [float(t["seconds"]), slab])
	var hands := _brush_voxel()
	_inventory(hands)
	var th: Dictionary = hands._edit._dig.work_target(AIM, Vector3.UP, "")
	assert_true(not th.is_empty(), "bare hands too")
	v.inventory_slice.free()
	v.free()
	hands.inventory_slice.free()
	hands.free()

# --- the wire and the prediction ----------------------------------------------------

## A host and a client over the same flat chunk (the client applies only what the host sent).
func _host_client() -> Dictionary:
	var host := _brush_voxel()
	var hinv := _inventory(host, { "StoneShovel": 1 })
	var c := VoxelSlice.new()
	add_child(c)
	c._edit.brush_enabled = true
	c.is_authoritative = false
	var flat: Array = []
	flat.resize(VoxelSlice.CHUNK_SIZE * VoxelSlice.CHUNK_SIZE)
	flat.fill(2.0)
	c.build_chunk(HOME, flat)
	var cinv := _inventory(c, { "StoneShovel": 1 })
	return { "host": host, "hinv": hinv, "client": c, "cinv": cinv }

func _free_pair(p: Dictionary) -> void:
	for k in ["host", "hinv", "client", "cinv"]:
		(p[k] as Node).free()

func _logs(v: VoxelSlice) -> Dictionary:
	var out: Dictionary = {}
	for k in v._edits:
		out[k] = (v._edits[k] as Array).duplicate(true)
	return out

## The one `block_changed` the host emits for a dig at the aim.
func _host_dig(p: Dictionary) -> Array:
	var changes: Array = []
	var on_changed := func(a: String, pos: Vector3, n: Vector3, m: String) -> void: changes.append([a, pos, n, m])
	GameBus.block_changed.connect(on_changed)
	p["host"].mine_block(AIM, Vector3.UP, "")
	GameBus.block_changed.disconnect(on_changed)
	return changes

func _test_wire_logs_match() -> void:
	var p := _host_client()
	var ch := _host_dig(p)
	assert_eq(ch.size(), 1, "one op")
	var c: VoxelSlice = p["client"]
	c._on_block_changed(ch[0][0], ch[0][1], ch[0][2], ch[0][3])
	assert_eq(_logs(c), _logs(p["host"]), "a client that applies the op holds the host's logs exactly")
	assert_false(_logs(c).is_empty(), "and they are not empty")
	_free_pair(p)

func _test_prediction() -> void:
	var p := _host_client()
	var c: VoxelSlice = p["client"]
	var seq: int = c._predict.predict("mine", AIM, Vector3.UP, "")
	assert_true(seq > 0 and c._predict.is_pending(seq), "the dig is predicted")
	var predicted := _logs(c)
	assert_true(predicted.size() > 1, "the whole brush is applied at once, not one tile (%d tiles)" % predicted.size())
	var ch := _host_dig(p)
	assert_eq(predicted, _logs(p["host"]), "the prediction made the host's logs already")
	var span: Dictionary = c._edit._dig.wire_span(str(ch[0][3]))
	c._predict.on_acked(seq, true, span)
	c._on_block_changed(ch[0][0], ch[0][1], ch[0][2], ch[0][3])
	assert_eq(_logs(c), _logs(p["host"]), "the confirmed op is host state, applied once")
	assert_eq(c._predict.pending_count(), 0, "nothing pending")
	# A refusal rolls the whole brush back byte-equal.
	var before := _logs(c)
	var seq2: int = c._predict.predict("mine", Vector3(20.25, 2.0, 20.25), Vector3.UP, "")
	assert_true(seq2 > 0 and _logs(c) != before, "a second dig is predicted")
	c._predict.on_acked(seq2, false)
	assert_eq(_logs(c), before, "a refusal takes the whole brush back")
	_free_pair(p)
