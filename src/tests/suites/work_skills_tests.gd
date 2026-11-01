extends "res://src/tests/test_support.gd"
## Phase 207 — skills grow from work: the WorkSkills table, sewing growing Tailoring for the sewer alone, each
## kind of work granting its mapped skill on the host, and the audit that no XP comes from a client message.

const WorkSkills := preload("res://src/character/work_skills.gd")
const StructureSlice := preload("res://src/structure/structure_slice.gd")
const ClanSlice := preload("res://src/clan/clan_slice.gd")

func register() -> void:
	_run_test("work skills: the table maps every recipe domain, every material and every kind of work", _test_table)
	_run_test("work skills: sewing adds Tailoring XP to the sewer and to no one else", _test_sewing)
	_run_test("work skills: mining, chopping, building, dismantling, repairing and skinning grant their mapped skill", _test_each_kind)
	_run_test("work skills: a client machine grants nothing", _test_client_grants_nothing)
	_run_test("work skills (audit): no XP amount is read from a client message", _test_audit)

func _registry() -> PlayerRegistry:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("host")
	for p in ["p1", "p2", "p3"]:
		reg.ensure_player(p)
	return reg

## Every player's skill XP, as a comparable snapshot.
func _xp(reg: PlayerRegistry) -> Dictionary:
	var out := {}
	for p in ["host", "p1", "p2", "p3"]:
		out[p] = (reg.get_record(p).get("skill_xp", {}) as Dictionary).duplicate()
	return out

## `after` minus `before` for every player, keeping only skills that moved: { pid: { skill: delta } }.
func _gained(before: Dictionary, after: Dictionary) -> Dictionary:
	var out := {}
	for p: String in after:
		for skill: String in after[p]:
			var d := int(after[p][skill]) - int((before.get(p, {}) as Dictionary).get(skill, 0))
			if d != 0:
				if not out.has(p):
					out[p] = {}
				out[p][skill] = d
	return out

func _test_table() -> void:
	var domains := {}
	for key: String in GameData.RECIPES:
		var r: Variant = GameData.RECIPES[key].get("recipe")
		if r is Dictionary and str(r.get("domain", "")) != "":
			domains[str(r["domain"])] = true
	assert_true(domains.has("tailoring"), "a recipe sews (the tailoring domain has a recipe)")
	for d: String in domains:
		assert_false(WorkSkills.craft_row(d).is_empty(), "crafting in %s grows a skill" % d)
	assert_eq(WorkSkills.craft_row("tailoring"), { "skill": "Tailoring", "xp": 8 }, "sewing grows Tailoring")
	for m: String in GameData.MATERIALS:
		assert_true(WorkSkills.family_of(m) in ["metal", "stone", "wood", "soil"], "%s has a gather family" % m)
		assert_false(WorkSkills.gather_row(m).is_empty(), "gathering %s grows a skill" % m)
	assert_eq(str(WorkSkills.gather_row("Ferrite")["skill"]), "Smithing", "ore grows Smithing")
	assert_eq(str(WorkSkills.gather_row("Thornwood")["skill"]), "Carpentry", "wood grows Carpentry")
	assert_eq(WorkSkills.gather_row("carcass"), { "skill": "Skinning", "xp": int(GameData.SKILLS["Skinning"].get("xpPerHarvest")) },
		"a carcass grows Skinning by Phase 160's amount")
	for kind in WorkSkills.SINGLE_KINDS:
		assert_false(WorkSkills.row(kind).is_empty(), "%s grows a skill" % kind)
	assert_true(WorkSkills.row("craft").is_empty() and WorkSkills.gather_row("Nope").is_empty(), "nothing else does")

func _test_sewing() -> void:
	var reg := _registry()
	var crafting := CraftingSlice.new()
	add_child(crafting)
	crafting.player_registry = reg
	var recipe: Dictionary = crafting.get_recipe("RecipeNoviceTunic")
	assert_eq(str(recipe.get("domain", "")), "tailoring", "the tunic is sewn")
	reg.get_inventory("p1").add_item("Duskfiber", 4)
	reg.get_inventory("p2").add_item("Duskfiber", 4)
	var before := _xp(reg)
	var res: Dictionary = crafting.craft("RecipeNoviceTunic", "p1")
	assert_true(bool(res["success"]), "p1 sews a tunic (%s)" % str(res.get("reason", "")))
	assert_eq(_gained(before, _xp(reg)), { "p1": { "Tailoring": 8 } }, "Tailoring XP for the sewer, nothing for anyone else")
	before = _xp(reg)
	assert_false(bool(crafting.craft("RecipeNoviceTunic", "p3")["success"]), "p3 has no fibre")
	assert_eq(_gained(before, _xp(reg)), {}, "a failed craft grows nothing")
	crafting.free()
	reg.free()

func _test_each_kind() -> void:
	var reg := _registry()
	var clans := ClanSlice.new()
	clans.registry = reg
	add_child(clans)
	var now := [1000000.0]
	clans.now_sec = func() -> float: return now[0]
	clans.mono_sec = func() -> float: return now[0]
	var st := StructureSlice.new()
	st.registry = reg
	st.clans = clans
	var hour := [0]
	st.now_hour = func() -> int: return hour[0]
	st.mono_sec = func() -> float: return now[0]
	add_child(st)
	var v := _make_voxel()
	v.is_authoritative = true
	v.player_registry = reg
	v.structures = st
	st.remove_block = v.remove_structure_block
	var at := func(tx: int, y: float) -> Vector3: return Vector3(float(tx) * 0.5 + 0.25, y, 2.0 * 0.5 + 0.25)

	# Gathering: a natural block mined into the pack grows its family's skill.
	var before := _xp(reg)
	var m: Dictionary = v.mine_block(at.call(10, 2.0), Vector3.UP, "p1")
	assert_true(bool(m["success"]) and int(m["quantity"]) > 0, "p1 mines natural ground")
	var row := WorkSkills.gather_row(str(m["material"]))
	assert_eq(_gained(before, _xp(reg)), { "p1": { str(row["skill"]): int(row["xp"]) } }, "mining %s grows %s" % [m["material"], row["skill"]])

	# Building: each placed block.
	before = _xp(reg)
	for i in 3:
		reg.get_inventory("p2").add_item("Ashite", 1)
		assert_true(v.place_block(at.call(20, 2.0 + 0.125 * i), Vector3.UP, "Ashite", "p2"), "p2 places block %d" % i)
	assert_eq(_gained(before, _xp(reg)), { "p2": { "Building": 3 * int(WorkSkills.row("build")["xp"]) } }, "three blocks built")

	# Dismantling: the owner takes the top block apart.
	before = _xp(reg)
	now[0] += StructureSlice.HIT_INTERVAL
	var d: Dictionary = v.mine_block(at.call(20, 2.0 + 0.125 * 3), Vector3.UP, "p2")
	assert_true(bool(d["success"]), "p2 dismantles a block")
	assert_eq(_gained(before, _xp(reg)), { "p2": { "Building": int(WorkSkills.row("dismantle")["xp"]) } }, "dismantling grows Building, not a gather skill")

	# Hitting someone else's block grows nothing.
	before = _xp(reg)
	now[0] += StructureSlice.HIT_INTERVAL
	v.mine_block(at.call(20, 2.0 + 0.125 * 2), Vector3.UP, "p3")
	assert_eq(_gained(before, _xp(reg)), {}, "a hit on another's block grows no one's skill")

	# Repairing: a worn structure restored by its owner.
	var sid := int(st.structure_at(Vector2i(20, 2), 2.0625))
	assert_true(sid != 0, "p2's blocks are a structure")
	hour[0] += 24 * 200
	reg.get_inventory("p2").add_item("Ashite", 10)
	before = _xp(reg)
	assert_eq(st.repair("p2", sid), "", "p2 repairs")
	assert_eq(_gained(before, _xp(reg)), { "p2": { "Building": int(WorkSkills.row("repair")["xp"]) } }, "repairing grows Building")
	before = _xp(reg)
	assert_eq(st.repair("p2", sid), "intact", "nothing left to repair")
	assert_eq(_gained(before, _xp(reg)), {}, "a refused repair grows nothing")

	# Chopping: a felled tree grows its wood's skill.
	var t := _make_tree_slice()
	t.player_registry = reg
	reg.get_inventory("p3").add_item("CarpenterAxe", 1)
	t.spawn_for_chunk(Vector2i(0, 0))
	var tid: String = str(t.get_all_trees()[0]["tree_id"])
	before = _xp(reg)
	var c: Dictionary = t.chop_tree(tid, "p3")
	assert_true(bool(c["success"]), "p3 fells a tree (%s)" % str(c.get("reason", "")))
	row = WorkSkills.gather_row(str(c["wood"]))
	assert_eq(_gained(before, _xp(reg)), { "p3": { str(row["skill"]): int(row["xp"]) } }, "chopping grows %s" % row["skill"])
	t.free()

	v.free()
	st.free()
	clans.free()
	reg.free()

## A client's registry refuses grants, so work resolved (or predicted) on a client grows nothing there.
func _test_client_grants_nothing() -> void:
	var reg := _registry()
	reg.is_authoritative = false
	var before := _xp(reg)
	WorkSkills.grant(reg, "p1", WorkSkills.craft_row("tailoring"))
	WorkSkills.grant(reg, "", WorkSkills.row("build"))
	assert_eq(_gained(before, _xp(reg)), {}, "no XP on a non-authoritative machine")
	reg.free()

## Every XP grant in the game goes through `WorkSkills.grant` with a row looked up from the fabric table, and
## only `work_skills.gd` calls `grant_skill_xp`: no amount can come from an intent's args.
func _test_audit() -> void:
	var callers: Array = []
	var bad_grants: Array = []
	for path: String in _gd_files("res://src"):
		if path.begins_with("res://src/tests/"):
			continue
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var line: String = lines[i]
			if line.strip_edges().begins_with("#") or line.strip_edges().begins_with("##"):
				continue
			if line.contains("grant_skill_xp(") and not line.contains("func grant_skill_xp("):
				callers.append("%s:%d" % [path, i + 1])
			if line.contains("WorkSkills.grant(") and not (line.contains("WorkSkills.craft_row(") or line.contains("WorkSkills.gather_row(") or line.contains("WorkSkills.row(")):
				bad_grants.append("%s:%d" % [path, i + 1])
	assert_true(callers.size() == 1 and str(callers[0]).begins_with("res://src/character/work_skills.gd:"),
		"only WorkSkills calls grant_skill_xp (found %s)" % str(callers))
	assert_eq(bad_grants, [], "every grant's row comes from the WorkSkills table")

func _gd_files(dir: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_gd_files(dir.path_join(d)))
	return out
