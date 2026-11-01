extends "res://src/tests/test_support.gd"
## Phase 205 — owned structures: who may edit, damage and dismantle a block, durability and wear, repair, the
## structure index's persistence, the station and tree guards, respawning at will, and what a client may name.

const StructureSlice := preload("res://src/structure/structure_slice.gd")
const StructureRules := preload("res://src/structure/structure_rules.gd")
const ClanSlice := preload("res://src/clan/clan_slice.gd")

func register() -> void:
	_run_test("structure: a private structure is its builder's anywhere, a clan structure any member's", _test_owner_edits)
	_run_test("structure: an outsider's hits destroy a block at zero durability, a rarer material takes more", _test_damage_destroys)
	_run_test("structure: dismantling returns 50% with no skill, 100% at the top, less after wear", _test_dismantle_share)
	_run_test("structure: ownership changes only by dismantling or destruction", _test_ownership_stable)
	_run_test("structure: a member's private house in clan territory can be entered and dismantled, not edited", _test_member_private_territory)
	_run_test("structure: a destroyer gets nothing, and offline owners make it the offline factor slower", _test_destroyer_offline)
	_run_test("structure: a repair restores durability for its share of materials, only by the owner", _test_repair)
	_run_test("structure: the index saves and loads, wears for downtime once and drops malformed entries", _test_persistence)
	_run_test("structure: blocks worn to nothing collapse in a bounded sweep, and the owner is told", _test_collapse_sweep)
	_run_test("structure: a station or a chop on someone else's structure is refused", _test_station_tree_guard)
	_run_test("structure: /buildas and /repair resolve on the host from its own records", _test_intents)
	_run_test("structure: /respawn kills the speaker's own character, at most once per cooldown", _test_respawn_command)
	_run_test("structure: a hit reaches peers in range as block_damaged", _test_damage_wire)
	_run_test("structure (audit): no owner, clan, durability or skill value is read from a client message", _test_audit_client_values)

# ── rig ──────────────────────────────────────────────────────────────────

## A flat chunk (ground at 2 m), a registry with p1..p4 (offline unless connected), a clan "Oakhold" with p1
## (founder) and p2 (member), and the structure index wired into the voxel slice.
func _rig() -> Dictionary:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("host")
	for p in ["p1", "p2", "p3", "p4"]:
		reg.ensure_player(p)
	var clans := ClanSlice.new()
	clans.registry = reg
	add_child(clans)
	var now := [1000000.0]
	clans.now_sec = func() -> float: return now[0]
	clans.mono_sec = func() -> float: return now[0]
	assert_eq(clans.found("p1", "Oakhold"), "", "p1 founds a clan")
	assert_eq(clans.invite("p1", "p2"), "", "p1 invites p2")
	assert_eq(clans.join("p2", "clan_1"), "", "p2 joins")
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
	return { "reg": reg, "clans": clans, "st": st, "v": v, "hour": hour, "now": now }

func _free_rig(r: Dictionary) -> void:
	r["v"].free()
	r["st"].free()
	r["clans"].free()
	r["reg"].free()

func _online(r: Dictionary, pid: String, peer: int) -> void:
	r["reg"]._peer_ids[peer] = pid

func _xyz(tx: int, tz: int, y: float) -> Vector3:
	return Vector3(float(tx) * 0.5 + 0.25, y, float(tz) * 0.5 + 0.25)

## `pid` places one `mat` on top of column (tx, tz) at height `y` (given the block first).
func _place(r: Dictionary, pid: String, tx: int, tz: int, y: float, mat: String = "Ashite") -> bool:
	r["reg"].get_inventory(pid).add_item(mat, 1)
	return r["v"].place_block(_xyz(tx, tz, y), Vector3.UP, mat, pid)

func _mine(r: Dictionary, pid: String, tx: int, tz: int, y: float) -> Dictionary:
	return r["v"].mine_block(_xyz(tx, tz, y), Vector3.UP, pid)

func _count(r: Dictionary, pid: String, mat: String) -> int:
	return int(r["reg"].get_inventory(pid).get_item_count(mat))

func _sid(r: Dictionary, tx: int, tz: int, y: float) -> int:
	return int(r["st"].structure_at(Vector2i(tx, tz), y + 0.0625))

# ── tests ────────────────────────────────────────────────────────────────

func _test_owner_edits() -> void:
	var r := _rig()
	var st: StructureSlice = r["st"]
	# A private house far from anything (no hearth exists at all).
	assert_true(_place(r, "p2", 40, 40, 2.0), "p2 builds a private block")
	var house := _sid(r, 40, 40, 2.0)
	assert_true(house != 0, "it is indexed")
	assert_eq(st.get_structure(house)["kind"], "private", "private by default")
	assert_eq(st.get_structure(house)["owner"], "p2", "owned by its builder")
	assert_true(_place(r, "p2", 40, 40, 2.125), "its owner builds on it")
	assert_eq(_sid(r, 40, 40, 2.125), house, "the new block joins the house")
	assert_false(_place(r, "p1", 40, 40, 2.25), "a clan member cannot build on another member's private house")
	assert_false(st.may_edit("p1", house), "nor edit it")
	var hit := _mine(r, "p1", 40, 40, 2.25)
	assert_false(bool(hit["success"]), "a clan member's mine there takes nothing away")
	assert_true(bool(hit.get("damaged", false)), "it is a hit")
	assert_eq(st.get_structure(house)["count"], 2, "both blocks stand")
	# A clan structure: any member, no outsider.
	assert_eq(st.set_build_mode("p1", "clan"), "", "p1 builds for the clan")
	assert_true(_place(r, "p1", 10, 10, 2.0), "p1 builds a clan block")
	var hall := _sid(r, 10, 10, 2.0)
	assert_eq([st.get_structure(hall)["kind"], st.get_structure(hall)["owner"]], ["clan", "clan_1"], "owned by the clan")
	assert_true(_place(r, "p2", 10, 10, 2.125), "a member builds on it")
	assert_eq(st.get_structure(_sid(r, 10, 10, 2.125))["owner"], "p2", "in private mode the block is the member's own, touching the hall")
	assert_eq(st.set_build_mode("p2", "clan"), "", "p2 builds for the clan")
	assert_true(_place(r, "p2", 10, 11, 2.0), "beside the hall")
	assert_eq(_sid(r, 10, 11, 2.0), hall, "and in clan mode the block joins the hall")
	assert_false(r["v"].place_block(_xyz(10, 11, 2.125), Vector3.UP, "Ashite", "p3") if r["reg"].get_inventory("p3").add_item("Ashite", 1) else true, "an outsider cannot build on it")
	assert_eq(_count(r, "p3", "Ashite"), 1, "a refused placement spends nothing")
	var own := _mine(r, "p1", 10, 11, 2.125)
	assert_true(bool(own["success"]), "a member takes a clan block apart")
	assert_true(bool(_mine(r, "p3", 10, 10, 2.125).get("damaged", false)), "an outsider only damages it")
	_free_rig(r)

func _test_damage_destroys() -> void:
	var r := _rig()
	var st: StructureSlice = r["st"]
	assert_true(_place(r, "p1", 4, 4, 2.0, "Soil"), "p1 builds an earth block")
	var hits := 0
	var last := {}
	while hits < 5000:
		last = _mine(r, "p3", 4, 4, 2.125)
		hits += 1
		if bool(last["success"]):
			break
	var per_hit := StructureRules.hit_damage("hand", "Soil", true)
	assert_eq(hits, ceili(StructureRules.base_durability("Soil") / per_hit - 0.000001), "bare hands take the block down hit by hit")
	assert_true(bool(last.get("destroyed", false)), "the last hit destroys it")
	assert_eq(_sid(r, 4, 4, 2.0), 0, "and it is gone from the index")
	assert_eq(st.count(), 0, "with its structure")
	# A rarer material of the same class takes more hits with the same tool.
	var n := {}
	for mat: String in ["Ashite", "Aethermite"]:
		var t := 6 if mat == "Ashite" else 8
		assert_true(_place(r, "p1", t, 4, 2.0, mat), "p1 builds %s" % mat)
		var plan := {}
		var k := 0
		while k < 1000:
			plan = st.plan_mine("p3", Vector2i(t, 4), 2.0, 2.125, "pick")
			st.commit_mine(plan)
			k += 1
			if str(plan["verdict"]) == "destroy":
				break
		n[mat] = k
	assert_eq(StructureRules.class_of("Ashite"), StructureRules.class_of("Aethermite"), "both are stone")
	assert_true(StructureRules.base_durability("Aethermite") > StructureRules.base_durability("Ashite"), "the rarer one is more durable")
	assert_true(int(n["Aethermite"]) > int(n["Ashite"]), "and takes more hits (%d against %d)" % [n["Aethermite"], n["Ashite"]])
	_free_rig(r)

## p1 builds `n` stacked Ashite blocks at (tx, tz) and takes them all apart; returns the Ashite back.
func _build_and_dismantle(r: Dictionary, tx: int, n: int, hours: int = 0) -> int:
	var before := _count(r, "p1", "Ashite")
	for i in n:
		assert_true(_place(r, "p1", tx, 2, 2.0 + 0.125 * i), "block %d" % i)
	r["hour"][0] += hours
	var got := _count(r, "p1", "Ashite") - before
	for i in range(n - 1, -1, -1):
		var m := _mine(r, "p1", tx, 2, 2.0 + 0.125 * (i + 1))
		assert_true(bool(m["success"]), "the owner takes block %d apart" % i)
	return _count(r, "p1", "Ashite") - before - got

func _test_dismantle_share() -> void:
	var r := _rig()
	r["st"].weather_at = func(_tile: Vector2i, _hour: int) -> String: return "rain"
	assert_eq(StructureRules.dismantle_share(1.0, 0), 0.5, "the fabric's no-skill point")
	assert_eq(StructureRules.dismantle_share(1.0, 10), 1.0, "and its top-skill point")
	assert_eq(_build_and_dismantle(r, 2, 10), 5, "at full durability with no Building skill, half comes back")
	r["reg"].add_skill_xp("p1", "Building", 5000)
	assert_eq(StructureRules.level_for_xp("Building", r["reg"].get_skill_xp("p1", "Building")), 10, "p1 is at the top level")
	assert_eq(_build_and_dismantle(r, 4, 10), 10, "with a very high skill, everything comes back")
	var month := _build_and_dismantle(r, 6, 10, 30 * 24)
	assert_true(month > 0 and month < 10, "after a month of rain, less (%d of 10)" % month)
	var year := _build_and_dismantle(r, 8, 10, 365 * 24)
	assert_true(year < month, "and less still after a year of rain (%d)" % year)
	_free_rig(r)

func _test_ownership_stable() -> void:
	var r := _rig()
	var st: StructureSlice = r["st"]
	st.set_build_mode("p2", "clan")
	assert_true(_place(r, "p2", 12, 12, 2.0), "p2 builds a clan block")
	st.set_build_mode("p2", "private")
	assert_true(_place(r, "p2", 12, 12, 2.125), "and a private one on top")
	var hall := _sid(r, 12, 12, 2.0)
	var mine := _sid(r, 12, 12, 2.125)
	assert_true(hall != mine, "touching structures keep their own blocks")
	var before := [st.get_structure(hall)["owner"], st.get_structure(mine)["owner"]]
	assert_eq(before, ["clan_1", "p2"], "one is the clan's, one p2's")
	_mine(r, "p3", 12, 12, 2.25)   # damage
	st.set_build_mode("p2", "clan")   # a new mode for new structures only
	r["clans"].leave("p2")   # p2 leaves the clan
	r["hour"][0] += 24 * 10   # time and wear
	var saved: Variant = JSON.parse_string(JSON.stringify(st.to_data()))
	st.from_data(saved)
	assert_eq([st.get_structure(hall)["owner"], st.get_structure(mine)["owner"]], before, "damage, modes, leaving the clan, time and a reload change no owner")
	assert_false(st.may_edit("p2", hall), "a leaver no longer edits the clan's block")
	assert_true(st.may_edit("p2", mine), "but still their own")
	assert_true(bool(_mine(r, "p2", 12, 12, 2.25)["success"]), "dismantling the private block")
	assert_true(st.get_structure(mine).is_empty(), "is what ends its ownership")
	_free_rig(r)

func _test_member_private_territory() -> void:
	var r := _rig()
	var st: StructureSlice = r["st"]
	st.set_build_mode("p1", "clan")
	assert_true(_place(r, "p1", 20, 20, 2.0), "the clan's hall")
	assert_true(_place(r, "p2", 24, 20, 2.0), "p2's private house beside it")
	assert_true(_place(r, "p2", 60, 60, 2.0), "and another far away")
	var near := _sid(r, 24, 20, 2.0)
	var far := _sid(r, 60, 60, 2.0)
	assert_true(st.in_clan_territory(near, "clan_1"), "the near house is in the clan's territory")
	assert_false(st.in_clan_territory(far, "clan_1"), "the far one is not")
	assert_true(st.may_enter("p1", near), "a clan member may enter the near house")
	assert_true(st.may_dismantle("p1", near), "and dismantle it")
	assert_false(st.may_edit("p1", near), "but not edit it")
	assert_false(_place(r, "p1", 24, 20, 2.125), "so building on it is refused")
	assert_false(st.may_enter("p1", far), "outside the territory they may not enter")
	assert_false(st.may_dismantle("p1", far), "or dismantle")
	assert_false(st.may_enter("p3", near), "an outsider may not enter even in the territory")
	assert_true(bool(_mine(r, "p1", 60, 60, 2.125).get("damaged", false)), "a member's mine of the far house is only a hit")
	var took := _mine(r, "p1", 24, 20, 2.125)
	assert_true(bool(took["success"]), "a member dismantles the near house")
	assert_eq(_sid(r, 24, 20, 2.0), 0, "and it is gone")
	_free_rig(r)

func _test_destroyer_offline() -> void:
	var r := _rig()
	var st: StructureSlice = r["st"]
	assert_true(_place(r, "p1", 2, 30, 2.0, "Soil"), "p1 builds")
	var sid := _sid(r, 2, 30, 2.0)
	assert_true(st.owners_offline(sid), "p1 is offline")
	var before := _count(r, "p3", "Soil")
	var offline_hits := 0
	while offline_hits < 5000 and _sid(r, 2, 30, 2.0) != 0:
		_mine(r, "p3", 2, 30, 2.125)
		offline_hits += 1
	assert_eq(_count(r, "p3", "Soil"), before, "the destroyer gets nothing from the block")
	assert_true(_place(r, "p1", 2, 30, 2.0, "Soil"), "p1 builds again")
	_online(r, "p1", 5)
	assert_false(st.owners_offline(_sid(r, 2, 30, 2.0)), "p1 is online")
	var online_hits := 0
	while online_hits < 5000 and _sid(r, 2, 30, 2.0) != 0:
		_mine(r, "p3", 2, 30, 2.125)
		online_hits += 1
	var factor := float(StructureRules.durability_rules()["methods"]["hand"]["offlineFactor"])
	assert_eq(offline_hits, online_hits * int(factor), "with every owner offline it takes the offline factor (%d×) longer" % int(factor))
	# A clan structure is "offline" only while every member is.
	st.set_build_mode("p1", "clan")
	assert_true(_place(r, "p1", 6, 30, 2.0), "a clan block")
	var hall := _sid(r, 6, 30, 2.0)
	assert_false(st.owners_offline(hall), "one member online is enough")
	r["reg"]._peer_ids.erase(5)
	assert_true(st.owners_offline(hall), "every member offline")
	_free_rig(r)

func _test_repair() -> void:
	var r := _rig()
	var st: StructureSlice = r["st"]
	for i in 4:
		assert_true(_place(r, "p1", 30, 2, 2.0 + 0.125 * i), "block %d" % i)
	var sid := _sid(r, 30, 2, 2.0)
	assert_eq(st.repair("p1", sid), "intact", "a new structure needs no repair")
	r["hour"][0] += 24 * 125   # 125 days: a quarter of base lost to age
	var d: Dictionary = st.block_durability(Vector2i(30, 2), 2.0625)
	assert_true(absf(float(d["fraction"]) - 0.75) < 0.001, "a quarter worn (%.3f)" % float(d["fraction"]))
	var cost: Dictionary = st.repair_cost(sid)
	assert_eq(cost, { "Ashite": ceili(StructureRules.repair_share() * 4 * 0.25 - 0.000001) }, "the share of 4 blocks times the quarter restored")
	assert_eq(st.repair("p3", sid), "not_owner", "a non-owner's repair is refused")
	assert_eq(st.repair("p1", sid), "missing_materials", "without the materials it is refused")
	assert_eq(st.block_durability(Vector2i(30, 2), 2.0625)["fraction"], d["fraction"], "a refused repair restores nothing")
	r["reg"].get_inventory("p1").add_item("Ashite", 5)
	assert_eq(st.repair("p1", sid), "", "the owner repairs")
	assert_eq(_count(r, "p1", "Ashite"), 5 - int(cost["Ashite"]), "spending exactly the cost")
	assert_eq(st.block_durability(Vector2i(30, 2), 2.0625)["fraction"], 1.0, "back to full durability")
	_free_rig(r)

func _test_persistence() -> void:
	var r := _rig()
	var st: StructureSlice = r["st"]
	st.set_build_mode("p1", "clan")
	assert_true(_place(r, "p1", 14, 6, 2.0), "a clan block")
	st.set_build_mode("p2", "private")
	assert_true(_place(r, "p2", 16, 6, 2.0, "Thornwood"), "a private wooden block")
	_mine(r, "p3", 16, 6, 2.125)
	var dmg: float = st.block_durability(Vector2i(16, 6), 2.0625)["durability"]
	var data: Variant = JSON.parse_string(JSON.stringify(st.to_data()))
	var fresh := StructureSlice.new()
	fresh.clans = r["clans"]
	fresh.registry = r["reg"]
	fresh.now_hour = st.now_hour
	add_child(fresh)
	fresh.from_data(data)
	assert_eq(fresh.count(), 2, "both structures load")
	assert_eq(fresh.cell_count(), 2, "with their blocks")
	assert_eq(fresh.get_structure(_sid(r, 14, 6, 2.0))["owner"], "clan_1", "and their owners")
	assert_eq(fresh.block_durability(Vector2i(16, 6), 2.0625)["durability"], dmg, "and their damage")
	assert_eq(fresh.build_mode("p1"), "clan", "and each builder's mode")
	# Ten days down: worn for them once, on this load.
	fresh.from_data(data, 240.0)
	var worn: float = fresh.block_durability(Vector2i(14, 6), 2.0625)["fraction"]
	assert_true(absf(worn - (1.0 - StructureRules.age_wear(240.0))) < 0.0001, "ten days of downtime wear the block (%.4f)" % worn)
	assert_eq(fresh.block_durability(Vector2i(14, 6), 2.0625)["fraction"], worn, "reading again wears nothing more")
	fresh.from_data({ "structures": [
		"junk",
		{ "id": 1, "kind": "tribe", "owner": "p1", "anchor": [0, 0], "cells": [[0, 0, 2000, "Ashite", 0, 0]] },
		{ "id": 2, "kind": "private", "owner": "", "anchor": [0, 0], "cells": [[0, 0, 2000, "Ashite", 0, 0]] },
		{ "id": 3, "kind": "private", "owner": "p1", "anchor": [0, 0], "cells": [[0, 0, 2000, "Nonsense", 0, 0], "x"] },
		{ "id": 4, "kind": "private", "owner": "p1", "anchor": [1, 1], "cells": [[1, 1, 2000, "Ashite", 0, 0]] },
		{ "id": 5, "kind": "private", "owner": "p2", "anchor": [1, 1], "cells": [[1, 1, 2000, "Ashite", 0, 0]] },
	] })
	assert_eq(fresh.count(), 1, "malformed structures, unknown materials and a block two records claim are dropped")
	assert_eq(fresh.get_structure(4)["owner"], "p1", "the first claim keeps the block")
	fresh.from_data("nonsense")
	assert_eq(fresh.count(), 0, "a non-dictionary record restores empty")
	fresh.free()
	_free_rig(r)

func _test_collapse_sweep() -> void:
	var r := _rig()
	var st: StructureSlice = r["st"]
	_online(r, "p1", 5)
	var notes: Array = []
	var cb := func(key: String, _args: Array, target: String) -> void: notes.append([key, target])
	GameBus.system_message.connect(cb)
	assert_true(_place(r, "p1", 50, 2, 2.0, "Soil"), "p1 builds")
	assert_true(_place(r, "p1", 50, 2, 2.125, "Soil"), "two blocks")
	r["hour"][0] += 24 * 600   # 600 days: worn away
	st.tick()
	assert_eq(st.count(), 0, "the worn-out structure is gone from the index")
	assert_eq(r["v"].column_top_at_tile(Vector2i(50, 2)), 2.0, "and its blocks from the world")
	assert_true(notes.has(["structure.destroyed", "p1"]), "its owner is told")
	GameBus.system_message.disconnect(cb)
	_free_rig(r)

func _test_station_tree_guard() -> void:
	var r := _rig()
	var st: StructureSlice = r["st"]
	assert_true(_place(r, "p1", 22, 30, 2.0), "p1's floor")
	var station := StationSlice.new()
	add_child(station)
	station.structure_guard = st.edit_blocker
	var on := _xyz(22, 30, 2.125)
	assert_eq(station.placement_blocker("forge", on, "p3"), "not_owner", "an outsider's station on it is refused")
	assert_eq(station.placement_blocker("forge", on, "p1"), "", "the owner's is fine")
	assert_eq(station.placement_blocker("forge", _xyz(40, 30, 2.0), "p3"), "", "free ground is free")
	var cats: Dictionary = I18nScript.parse_csv("res://locale/ui.csv")["catalog"]
	for loc in cats:
		assert_true((cats[loc] as Dictionary).has("reason.not_owner"), "%s has reason.not_owner" % loc)
	station.free()
	var t := _make_tree_slice()
	t.structure_guard = st.edit_blocker
	t._spawn("Oak", "Wood", Vector2i(0, 0), 0)
	var tid: String = t._trees.keys()[0]
	t._trees[tid]["position"] = _xyz(22, 30, 2.125)
	assert_eq(str(t.chop_tree(tid, "p3")["reason"]), "not_owner", "an outsider cannot fell a tree standing on the structure")
	assert_eq(str(t._trees[tid]["state"]), "standing", "and the tree stands")
	assert_true(str(t.chop_tree(tid, "p1")["reason"]) != "not_owner", "its owner is not refused by it")
	t.free()
	_free_rig(r)

func _test_intents() -> void:
	var r := _rig()
	var st: StructureSlice = r["st"]
	var seen: Array = []
	var cb := func(pid: String, action: String, ok: bool, reason: String) -> void: seen.append([pid, action, ok, reason])
	GameBus.structure_resolved.connect(cb)
	GameBus.structure_intent.emit("build_as", { "mode": "clan" }, "p3")
	assert_eq(seen.back(), ["p3", "build_as", false, "no_clan"], "an outsider has no clan to build for")
	r["now"][0] += 1.0
	GameBus.structure_intent.emit("build_as", { "mode": "clan" }, "p1")
	assert_eq(seen.back(), ["p1", "build_as", true, ""], "a member builds for the clan")
	GameBus.structure_intent.emit("build_as", { "mode": "private" }, "p1")
	assert_eq(seen.back()[3], "rate_limited", "intents are rate limited")
	r["now"][0] += 1.0
	GameBus.structure_intent.emit("build_as", { "mode": "palace" }, "p1")
	assert_eq(seen.back()[3], "bad_args", "an unknown mode is refused")
	r["now"][0] += 1.0
	GameBus.structure_intent.emit("repair", {}, "p1")
	assert_eq(seen.back()[3], "no_structure", "/repair needs a structure of the speaker's in reach")
	st.is_host = false
	var n := seen.size()
	r["now"][0] += 1.0
	GameBus.structure_intent.emit("build_as", { "mode": "private" }, "p1")
	assert_eq(seen.size(), n, "a client slice resolves nothing")
	GameBus.structure_resolved.disconnect(cb)
	var chat := ChatSlice.new()
	chat.render_visuals = false
	chat.admins_path = "user://does_not_exist_admins.json"
	chat.player_registry = r["reg"]
	add_child(chat)
	var intents: Array = []
	var icb := func(action: String, args: Dictionary, pid: String) -> void: intents.append([action, args, pid])
	GameBus.structure_intent.connect(icb)
	chat.handle_intent("/buildas Clan", "p2")
	chat.handle_intent("/repair", "p2")
	assert_eq(intents, [["build_as", { "mode": "clan" }, "p2"], ["repair", {}, "p2"]], "the chat commands become intents for the speaker, naming no owner")
	GameBus.structure_intent.disconnect(icb)
	chat.free()
	_free_rig(r)

func _test_respawn_command() -> void:
	assert_eq(ChatCommands.RESPAWN_NAME, str(StructureRules.respawn()["command"]), "the command is the fabric's")
	assert_true(ChatCommands.PLAYER_COMMANDS.has(ChatCommands.RESPAWN_NAME), "any player may run it")
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("host")
	reg.ensure_player("p2")
	reg._peer_ids[7] = "p2"
	var chat := ChatSlice.new()
	chat.render_visuals = false
	chat.admins_path = "user://does_not_exist_admins.json"
	chat.player_registry = reg
	add_child(chat)
	var clock := [100.0]
	chat.set_clock(func() -> float: return clock[0])
	var hits: Array = []
	var cb := func(dmg: float, attacker: String, target: String) -> void: hits.append([attacker, target, dmg >= 100.0])
	GameBus.player_damaged.connect(cb)
	var keys: Array = []
	var kcb := func(key: String, _args: Array, target: String) -> void: keys.append([key, target])
	GameBus.system_message.connect(kcb)
	chat.handle_intent("/respawn", "p2")
	assert_eq(hits, [["self", "p2", true]], "the speaker's own character is killed, by themselves")
	assert_true(keys.has(["chat.respawning", "p2"]), "and told so")
	clock[0] += 10.0
	chat.handle_intent("/respawn", "p2")
	assert_eq(hits.size(), 1, "again inside the cooldown does nothing")
	assert_true(keys.has(["chat.respawn_wait", "p2"]), "but says how long to wait")
	clock[0] += StructureRules.respawn_cooldown_sec()
	chat.handle_intent("/respawn", "p2")
	assert_eq(hits.size(), 2, "after the cooldown it works again")
	GameBus.player_damaged.disconnect(cb)
	GameBus.system_message.disconnect(kcb)
	chat.free()
	reg.free()

func _test_damage_wire() -> void:
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.CLIENT
	n.set_transport(MemoryTransport.new([1]))
	var heard: Array = []
	var cb := func(pos: Vector3, fraction: float) -> void: heard.append([pos, fraction])
	GameBus.block_damaged.connect(cb)
	n._route_h2c({ "type": "block_damaged", "position": [1.0, 2.0, 3.0], "fraction": 0.5 })
	assert_eq(heard.size(), 1, "a client hears a host's block_damaged")
	assert_eq(heard[0][1], 0.5, "with its fraction")
	n._route_h2c({ "type": "block_damaged", "position": [1.0, 2.0, 3.0], "fraction": "lots" })
	assert_eq(heard.size(), 1, "a malformed fraction is dropped")
	GameBus.block_damaged.disconnect(cb)
	n.free()

## The packets a client sends that reach structure rules carry only an aim and a material (block edits), a
## chat line (`/buildas`, `/repair`, `/respawn`) or a settlement/clan intent: owner, clan, durability and skill
## come from the host's records. Scans the client → host routing for any of those keys read off a payload.
func _test_audit_client_values() -> void:
	var src := FileAccess.get_file_as_string("res://src/networking/net_part_2.gd")
	assert_true(src.length() > 0, "the client → host routing is readable")
	for field: String in ["owner", "clan", "durability", "skill", "kind", "fraction", "wear", "damage", "level"]:
		assert_false(src.contains("payload.get(\"%s\"" % field), "no client payload's \"%s\" is read" % field)
	var slice_src := FileAccess.get_file_as_string("res://src/structure/structure_slice.gd")
	assert_false(slice_src.contains("args.get(\"owner\"") or slice_src.contains("args.get(\"clan\"") or slice_src.contains("args.get(\"sid\""),
		"a structure intent names no owner, clan or structure: the host finds them")
	var edit_src := FileAccess.get_file_as_string("res://src/terrain/voxel_edit.gd")
	assert_true(edit_src.contains("s.structures.plan_mine(player_id, tile,"), "a mine's verdict comes from the host's index")
	assert_true(edit_src.contains("s.structures.plan_place(player_id, tile,"), "and a placement's")
