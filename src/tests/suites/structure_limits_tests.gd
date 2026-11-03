extends "res://src/tests/test_support.gd"
## Phase 212 — floors and structural limits: the floors each class carries, overhangs past a class's threshold,
## the pure limit reads, what a block keeps of its support through a save, project layouts at their heights with
## the doorway open, the materials above stone, and that no structural value comes from a client.

const StructureSlice := preload("res://src/structure/structure_slice.gd")
const Limits := preload("res://src/structure/structure_limits.gd")
const StructureRules := preload("res://src/structure/structure_rules.gd")
const ClanSlice := preload("res://src/clan/clan_slice.gd")
const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")
const ProjectRules := preload("res://src/settlement/project_rules.gd")
const SettlementWiring := preload("res://src/settlement/settlement_wiring.gd")

func register() -> void:
	_run_test("structure limits: a third wood, sixth stone and eleventh concrete floor are refused; the top class stops at 163", _test_floor_limits)
	_run_test("structure limits: the weakest class carrying a block sets its floors", _test_weakest_carries)
	_run_test("structure limits: an overhang past a class's threshold is refused for it and allowed for the next", _test_overhang)
	_run_test("structure limits: the pure reads follow the fabric's classes and shapes", _test_pure_limits)
	_run_test("structure limits: a tall thin post needs a stronger class, a wall a floor high needs none", _test_slender)
	_run_test("structure limits: a block keeps what holds it up through a save; an old save stands on ground", _test_hold_persists)
	_run_test("structure limits: a refused placement through the world spends nothing and says why", _test_world_refusal)
	_run_test("structure limits: a finished project's doorway is open on every course, its blocks at their heights", _test_project_heights)
	_run_test("structure limits: every class has a material, concrete steel and leyframe are craftable, every project fits its class", _test_materials_above_stone)
	_run_test("structure limits (audit): no structural value is read from a client message", _test_audit_no_client_values)
	_run_test("structure limits: every refusal reason has a line in both catalogs", _test_reason_lines)

# ── rig ──────────────────────────────────────────────────────────────────

## A registry with p1..p3 and an index with no world: its blocks are placed straight through `plan_place`.
func _rig() -> Dictionary:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("host")
	for p in ["p1", "p2", "p3"]:
		reg.ensure_player(p)
	var clans := ClanSlice.new()
	clans.registry = reg
	add_child(clans)
	var st := StructureSlice.new()
	st.registry = reg
	st.clans = clans
	st.now_hour = func() -> int: return 0
	st.mono_sec = func() -> float: return 1000.0
	add_child(st)
	return { "reg": reg, "clans": clans, "st": st }

func _free_rig(r: Dictionary) -> void:
	for k in ["st", "clans", "reg"]:
		r[k].free()

## `pid` places `mat` at [`bottom`, +STEP] in `tile` through the index; the verdict's plan, committed when allowed.
func _put(st: StructureSlice, pid: String, tile: Vector2i, bottom: float, mat: String, normal: Vector3 = Vector3.UP, supported: bool = true) -> Dictionary:
	var plan := st.plan_place(pid, tile, bottom, normal, mat, supported)
	if str(plan["verdict"]) != "refused":
		st.commit_place(plan)
	return plan

## A ground slab of `side` × `side` columns of `mat` from `corner`, one block high at 2 m: a footprint wide enough
## that slenderness never decides a floor test. Returns its structure id.
func _slab(st: StructureSlice, corner: Vector2i, side: int, mat: String) -> int:
	for x in side:
		for z in side:
			_put(st, "p1", corner + Vector2i(x, z), 2.0, mat)
	return st.structure_at(corner, 2.0625)

## Index a block of `mat` at bottom `mm` of `tile` in `sid` standing over a base at `base_mm`, as a tower that rose
## there block by block would have it (without placing the thousands of blocks between).
## `carry` is the weakest class under it (-1: its own material's).
func _seat(st: StructureSlice, sid: int, tile: Vector2i, mm: int, mat: String, base_mm: int, carry: int = -1) -> void:
	st.commit_place({ "verdict": "join", "sid": sid, "tile": tile, "mm": mm, "material": mat, "player_id": "p1",
		"base": base_mm, "reach": 0, "carry": carry if carry >= 0 else Limits.rank_of(mat) })

## The verdict (or refusal reason) of putting `mat` on top of a seated block at floor height `floors` × 3 m − STEP.
func _on_floor(st: StructureSlice, sid: int, tile: Vector2i, floor: int, mat: String) -> String:
	var floor_mm := Limits.floor_mm()
	var bottom_mm := 2000 + (floor - 1) * floor_mm
	_seat(st, sid, tile, bottom_mm - 125, mat, 2000)
	var plan := st.plan_place("p1", tile, float(bottom_mm) / 1000.0, Vector3.UP, mat)
	return str(plan.get("reason", plan["verdict"]))

# ── tests ────────────────────────────────────────────────────────────────

func _test_floor_limits() -> void:
	for row: Array in [["Thornwood", 2], ["Ashite", 5], ["Concrete", 10], ["Steel", 40], ["Leyframe", 163]]:
		var mat: String = row[0]
		var top: int = row[1]
		var r := _rig()
		var st: StructureSlice = r["st"]
		var sid := _slab(st, Vector2i(100, 100), 12, mat)   # 6 m wide: 40 steel floors are not too slender
		assert_true(sid != 0, "%s: a ground slab" % mat)
		assert_eq(Limits.max_floors(Limits.rank_of(mat)), top, "%s carries %d floors" % [mat, top])
		assert_eq(_on_floor(st, sid, Vector2i(101, 101), top, mat), "join", "%s: floor %d is allowed" % [mat, top])
		assert_eq(_on_floor(st, sid, Vector2i(102, 102), top + 1, mat), "too_many_floors", "%s: floor %d is refused" % [mat, top + 1])
		_free_rig(r)
	assert_eq(Limits.max_floors(Limits.rank_of("Leyframe")), int(StructureRules.structure()["maxFloors"]), "the top class reaches the tallest building")

func _test_weakest_carries() -> void:
	var r := _rig()
	var st: StructureSlice = r["st"]
	var sid := _slab(st, Vector2i(0, 0), 8, "Ashite")
	# A wooden post on the slab: everything stacked on it is carried by wood, stone or not.
	var post := Vector2i(3, 3)
	_seat(st, sid, post, 2125, "Thornwood", 2000)
	var plan := st.plan_place("p1", post, 2.25, Vector3.UP, "Ashite")
	assert_eq(int(plan["carry"]), Limits.rank_of("Thornwood"), "stone on wood is carried by wood")
	assert_eq(int(plan["base"]), 2000, "and its load comes down to the slab's ground")
	st.commit_place(plan)
	# The top of the post's second floor, carried by wood as the column rising from it is.
	var top_mm := 2000 + 2 * Limits.floor_mm() - 125
	_seat(st, sid, post, top_mm, "Ashite", 2000, Limits.rank_of("Thornwood"))
	assert_eq(str(st.plan_place("p1", post, float(top_mm + 125) / 1000.0, Vector3.UP, "Ashite").get("reason", "")), "too_many_floors",
		"a third floor over the wooden post is refused, even in stone")
	assert_eq(_on_floor(st, sid, Vector2i(5, 5), 3, "Ashite"), "join", "a stone column beside it reaches the third floor")
	# A basement below the slab is floor 0: no class limits it.
	assert_eq(Limits.floor_of(1000, 2000), 0, "a block a metre below its base is on floor 0")
	assert_eq(Limits.floor_of(2000 + Limits.floor_mm() - 125, 2000), 1, "the top block of the ground floor is floor 1")
	assert_eq(Limits.floor_of(2000 + Limits.floor_mm(), 2000), 2, "the next starts floor 2")
	_free_rig(r)

## A row of blocks hung out sideways from a post at `tile`, along +x, as far as `n`; the reason the last was refused
## ("" when every one was placed).
func _hang_row(st: StructureSlice, pid: String, tile: Vector2i, mat: String, n: int) -> String:
	_put(st, pid, tile, 2.0, mat)
	for i in range(1, n + 1):
		var plan := _put(st, pid, tile + Vector2i(i, 0), 2.0, mat, Vector3(1, 0, 0), false)
		if str(plan["verdict"]) == "refused":
			return "%s@%d" % [plan["reason"], i]
		assert_eq(int(plan["reach"]), i, "%s: the block %d out reaches %d" % [mat, i, i])
	return ""

func _test_overhang() -> void:
	# [weaker, stronger, the reach the weaker refuses and the stronger takes]
	for row: Array in [["Soil", "Thornwood", 9], ["Thornwood", "Ashite", 17], ["Concrete", "Steel", 49], ["Steel", "Leyframe", 129]]:
		var r := _rig()
		var st: StructureSlice = r["st"]
		var reach: int = row[2]
		assert_eq(_hang_row(st, "p1", Vector2i(0, 0), row[0], reach), "overhang_too_far@%d" % reach, "%s hangs %d out and no further" % [row[0], reach - 1])
		assert_eq(_hang_row(st, "p2", Vector2i(0, 20), row[1], reach), "", "%s hangs %d out" % [row[1], reach])
		_free_rig(r)
	var r := _rig()
	var st: StructureSlice = r["st"]
	_hang_row(st, "p1", Vector2i(0, 0), "Thornwood", 4)
	var under := st.plan_place("p1", Vector2i(4, 0), 1.875, Vector3(0, -1, 0), "Thornwood", false)
	assert_eq(int(under["reach"]), 4, "a block hung under a ceiling reaches as far as the ceiling does")
	var on_ground := st.plan_place("p1", Vector2i(5, 1), 2.0, Vector3(1, 0, 0), "Thornwood", true)
	assert_eq(int(on_ground["reach"]), 0, "a block on solid ground beside the overhang starts a new column")
	_free_rig(r)

func _test_pure_limits() -> void:
	var wood := Limits.rank_of("Thornwood")
	var stone := Limits.rank_of("Ashite")
	assert_eq(Limits.rank_of("Leyframe"), StructureRules.CLASSES.size() - 1, "leyframe is the top class")
	assert_eq(Limits.refusal(wood, 2, 0, 0, 0.0), "", "a wood second floor is fine")
	assert_eq(Limits.refusal(wood, 3, 0, 0, 0.0), "too_many_floors", "a wood third floor is not")
	assert_eq(Limits.min_rank("unsupportedSpan", 16.0), 0, "a span of 16 needs no class")
	assert_eq(Limits.min_rank("unsupportedSpan", 17.0), wood, "a span of 17 needs wood")
	assert_eq(Limits.refusal(0, 1, 0, 17, 0.0), "span_too_long", "an earth span of 17 is refused")
	assert_eq(Limits.refusal(stone, 1, 0, 33, 0.0), "", "a stone one of 33 is not")
	assert_eq(Limits.min_rank("heightToFootprint", 3.5), stone, "past a ratio of 3 stone is needed")
	assert_eq(Limits.refusal(wood, 1, 0, 0, 3.5), "too_slender", "a slender wood build is refused")
	assert_near_f(Limits.slenderness(6.0, 16), 3.0, "6 m over a 4×4-column footprint (2 m) is a ratio of 3")
	assert_eq(Limits.last_threshold("unsupportedSpan"), 256.0, "the last span threshold")

func assert_near_f(a: float, b: float, msg: String) -> void:
	assert_true(absf(a - b) < 0.0001, "%s (%f against %f)" % [msg, a, b])

func _test_slender() -> void:
	var r := _rig()
	var st: StructureSlice = r["st"]
	var tile := Vector2i(0, 0)
	var n := Limits.floor_mm() / 125
	for i in n:
		assert_eq(str(_put(st, "p1", tile, 2.0 + 0.125 * i, "Ashite")["verdict"]) != "refused", true, "post block %d (a floor high)" % i)
	var past := st.plan_place("p1", tile, 2.0 + 0.125 * n, Vector3.UP, "Ashite")
	assert_eq(str(past.get("reason", "")), "too_slender", "a one-column stone post taller than a floor is too slender")
	assert_eq(str(st.plan_place("p1", tile, 2.0 + 0.125 * n, Vector3.UP, "Leyframe").get("reason", "")), "too_slender",
		"leyframe on a stone post is carried by stone")
	var r2 := _rig()
	var st2: StructureSlice = r2["st"]
	for i in n:
		_put(st2, "p1", tile, 2.0 + 0.125 * i, "Leyframe")
	assert_eq(str(st2.plan_place("p1", tile, 2.0 + 0.125 * n, Vector3.UP, "Leyframe")["verdict"]), "join", "a leyframe post goes on up")
	_free_rig(r2)
	# A wall one floor high and a block long is no tower.
	for x in range(1, 4):
		for i in n:
			_put(st, "p1", tile + Vector2i(x, 0), 2.0 + 0.125 * i, "Ashite")
	assert_eq(st.get_structure(st.structure_at(tile, 2.0625))["count"], 4 * n, "the wall stands a floor high")
	_free_rig(r)

func _test_hold_persists() -> void:
	var r := _rig()
	var st: StructureSlice = r["st"]
	_hang_row(st, "p1", Vector2i(0, 0), "Steel", 3)
	var sid := st.structure_at(Vector2i(0, 0), 2.0625)
	_seat(st, sid, Vector2i(0, 0), 2125, "Steel", 1500)
	var data := st.to_data()
	st.from_data(data)
	var cell: Array = st.get_structure(sid)["cells"][Vector2i(3, 0)][2000]
	assert_eq(int(cell[5]), 3, "a hung block keeps its reach through a save")
	assert_eq(int(st.get_structure(sid)["cells"][Vector2i(0, 0)][2125][4]), 1500, "and a block its base")
	# A save from before Phase 212 (seven fields a cell): its blocks stand on ground.
	var old: Dictionary = data.duplicate(true)
	for s: Dictionary in old["structures"]:
		for c: Array in s["cells"]:
			c.resize(7)
	st.from_data(old)
	cell = st.get_structure(sid)["cells"][Vector2i(3, 0)][2000]
	assert_eq([int(cell[4]), int(cell[5])], [2000, 0], "an old block is on its own ground, reaching nothing")
	# A save cannot raise a block's class or put its base above it.
	var forged: Dictionary = data.duplicate(true)
	for s: Dictionary in forged["structures"]:
		for c: Array in s["cells"]:
			c[7] = 99999
			c[9] = 5
	st.from_data(forged)
	cell = st.get_structure(sid)["cells"][Vector2i(3, 0)][2000]
	assert_eq([int(cell[4]), int(cell[6])], [2000, Limits.rank_of("Steel")], "a base above the block or a class above its material is clamped")
	_free_rig(r)

func _test_world_refusal() -> void:
	var r := _rig()
	var st: StructureSlice = r["st"]
	var v := _make_voxel()
	v.is_authoritative = true
	v.player_registry = r["reg"]
	v.structures = st
	st.remove_block = v.remove_structure_block
	var inv = r["reg"].get_inventory("p1")
	var n := Limits.floor_mm() / 125
	inv.add_item("Soil", n + 1)
	var reasons: Array = []
	var on_res := func(_pid: String, action: String, ok: bool, reason: String) -> void:
		if action == "place" and not ok:
			reasons.append(reason)
	GameBus.structure_resolved.connect(on_res)
	# Earth carries one floor: a soil post on the ground, a floor high, and then one more block.
	var placed := 0
	for i in n + 1:
		if v.place_block(Vector3(0.25, 2.0 + 0.125 * i, 0.25), Vector3.UP, "Soil", "p1"):
			placed += 1
	GameBus.structure_resolved.disconnect(on_res)
	assert_eq(placed, n, "a soil post stands one floor high")
	assert_eq(reasons, ["too_many_floors"], "the block on the second floor is refused, and the builder is told why")
	assert_eq(int(inv.get_item_count("Soil")), 1, "the refused block is not spent")
	assert_true(is_equal_approx(v.column_top_at_tile(Vector2i(0, 0)), 2.0 + 0.125 * n), "and the world holds no block for it")
	_free_rig(r)
	v.free()

func _test_project_heights() -> void:
	var v := VoxelSlice.new()
	add_child(v)
	var hm: Array = []
	hm.resize(64 * 64)
	for i in hm.size():
		hm[i] = 2.0 + 0.125 * float(i % 3)   # uneven ground: three heights a step apart
	v.build_chunk(Vector2i(0, 0), hm)
	v.is_authoritative = true
	var layout := "shed"
	var cells := ProjectRules.layout_cells(layout, 1)
	var x0 := 8.0
	var z0 := 8.0
	var batch: Array = []
	var ground: Dictionary = {}
	for c: Vector3i in cells:
		var exact := SettlementWiring._exact_at(x0 + (float(c.x) + 0.5) * 0.5, z0 + (float(c.z) + 0.5) * 0.5)
		batch.append({ "exact": exact, "dy": c.y })
		var t := Vector2i(floori((x0 + (float(c.x) + 0.5) * 0.5) / 0.5), floori((z0 + (float(c.z) + 0.5) * 0.5) / 0.5))
		if not ground.has(t):
			ground[t] = v.column_top_at_tile(t)
	var changes := [0]
	var on_change := func(action: String, _p: Vector3, _n: Vector3, _m: String) -> void:
		if action == "place":
			changes[0] += 1
	GameBus.block_changed.connect(on_change)
	var placed := v.place_structure_blocks(batch, "Ashite")
	GameBus.block_changed.disconnect(on_change)
	assert_eq(placed, cells.size(), "every block of the shed is placed")
	assert_eq(changes[0], placed, "each is synced as an ordinary edit")
	var heights := {}
	for g: float in ground.values():
		heights[g] = true
	assert_true(heights.size() > 1, "the shed stands on uneven ground")
	var half := ProjectRules.half_of(layout)
	var wrong := 0
	for c: Vector3i in cells:
		var t := Vector2i(16 + c.x, 16 + c.z)
		var y := float(ground[t]) + 0.125 * float(c.y) + 0.0625
		if not v.VoxelRuns.runs_cover_y(v.get_runs_at_tile(t), y):
			wrong += 1
	assert_eq(wrong, 0, "every block sits at its layout height above its own column's ground")
	var door_open := 0
	var door_cells := 0
	for x in range(-half.x, half.x + 1):
		var c := Vector2i(x, -half.y)
		var t := Vector2i(16 + c.x, 16 + c.y)
		for y in ProjectRules.courses_per_floor():
			var covered: bool = v.VoxelRuns.runs_cover_y(v.get_runs_at_tile(t), float(ground[t]) + 0.125 * float(y) + 0.0625)
			if ProjectRules.is_doorway(layout, c, y):
				door_cells += 1
				if not covered:
					door_open += 1
			elif not covered:
				wrong += 1
	assert_eq(door_cells, ProjectRules.DOOR_TILES * ProjectRules.DOOR_COURSES, "the doorway is %d tiles by %d courses" % [ProjectRules.DOOR_TILES, ProjectRules.DOOR_COURSES])
	assert_eq(door_open, door_cells, "and open on every course it should be")
	assert_eq(wrong, 0, "the lintel over it and the wall beside it are closed")
	v.free()

func _test_materials_above_stone() -> void:
	var by_class: Dictionary = {}
	for m: String in GameData.MATERIALS:
		by_class[StructureRules.class_of(m)] = true
	for c: String in StructureRules.CLASSES:
		assert_true(by_class.has(c), "class %s has a material" % c)
	var made: Dictionary = {}
	for key: String in GameData.RECIPES:
		var rec: Variant = GameData.RECIPES[key].get("recipe")
		if rec is Dictionary:
			for o: Dictionary in rec.get("outputs", []):
				made[str(o.get("item", ""))] = key
	for row: Array in [["Concrete", "concrete"], ["Steel", "steel"], ["Leyframe", "composite"]]:
		assert_eq(StructureRules.class_of(row[0]), row[1], "%s is %s class" % row)
		assert_true(made.has(row[0]), "%s is crafted" % row[0])
	var ley: Dictionary = GameData.RECIPES[made["Leyframe"]].get("recipe")
	var gated := false
	for i: Dictionary in ley.get("inputs", []):
		var m: Resource = GameData.MATERIALS.get(str(i.get("item", "")), null)
		if m != null and bool(m.get("leyGated")):
			gated = true
	assert_true(gated, "the top class takes a ley-gated ingredient")
	for key: String in (ProjectRules.table()["projects"] as Dictionary):
		var pl: Dictionary = ProjectRules.def_of(key)["places"]
		var mat := ProjectRules.block_material(str(pl["block"]))
		assert_true(int(pl["floors"]) <= Limits.max_floors(Limits.rank_of(mat)), "project %s fits its block's class" % key)

func _test_audit_no_client_values() -> void:
	var net := FileAccess.get_file_as_string("res://src/networking/net_part_2.gd")
	assert_true(net.length() > 0, "the client → host routing is readable")
	for field: String in ["base", "reach", "carry", "floor", "floors", "supported", "span", "structuralClass", "class"]:
		assert_false(net.contains("payload.get(\"%s\"" % field), "no client payload's \"%s\" is read" % field)
	var edit := FileAccess.get_file_as_string("res://src/terrain/voxel_edit.gd")
	assert_true(edit.contains("var supported: bool = s.VoxelRuns.runs_cover_y(runs,"), "whether a block is supported is read from the host's runs")
	assert_true(edit.contains("plan_place(player_id, tile, float(span[\"bottom\"]), normal, chosen, supported)"), "and handed to the host's index")
	var slice := FileAccess.get_file_as_string("res://src/structure/structure_slice.gd")
	for field: String in ["base", "reach", "carry"]:
		assert_false(slice.contains("args.get(\"%s\"" % field), "no structure intent names a block's %s" % field)
	var limits := FileAccess.get_file_as_string("res://src/structure/structure_limits.gd")
	assert_false(limits.contains("GameBus") or limits.contains("payload"), "the limits read no message")

func _test_reason_lines() -> void:
	var catalog: Dictionary = I18nScript.parse_csv("res://locale/ui.csv")["catalog"]
	for reason: String in [Limits.TOO_MANY_FLOORS, Limits.OVERHANG, Limits.SPAN, Limits.SLENDER]:
		assert_true(StructureSlice.REASONS.has(reason), "%s is a structure reason" % reason)
		var key := "structure.refused.%s" % reason
		for lang: String in ["en", "pt_BR"]:
			assert_true(str((catalog.get(lang, {}) as Dictionary).get(key, "")) != "", "%s has a %s line" % [key, lang])
