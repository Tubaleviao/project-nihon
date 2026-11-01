extends "res://src/tests/test_support.gd"
## Phase 205 — owned structures: who may edit, damage and dismantle a block, durability and wear, repair, the
## structure index's persistence, the station and tree guards, respawning at will, and what a client may name.
## Phase 206 — the circle around every structure: its size, the lookup, no foreign building, no spawns.

const StructureSlice := preload("res://src/structure/structure_slice.gd")
const StructureRules := preload("res://src/structure/structure_rules.gd")
const ClanSlice := preload("res://src/clan/clan_slice.gd")
const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")
const SeamWrap := preload("res://src/terrain/seam_wrap.gd")
const StructureWiring := preload("res://src/structure/structure_wiring.gd")

## `a` within 0.0001 of `b`.
func assert_near(a: float, b: float, msg: String) -> void:
	assert_true(absf(a - b) < 0.0001, "%s (%f against %f)" % [msg, a, b])

func register() -> void:
	_run_test("structure: a private structure is its builder's anywhere, a clan structure any member's", _test_owner_edits)
	_run_test("structure: an outsider's hits destroy a block at zero durability, a rarer material takes more", _test_damage_destroys)
	_run_test("structure: dismantling returns 50% with no skill, 100% at the top, less after wear", _test_dismantle_share)
	_run_test("structure: ownership changes only by dismantling or destruction", _test_ownership_stable)
	_run_test("structure: a member's private house in clan territory can be entered and dismantled, not edited", _test_member_private_territory)
	_run_test("structure: a destroyer gets nothing, and offline owners make it the offline factor slower", _test_destroyer_offline)
	_run_test("structure: the host keeps an outsider's hit pace, however fast the intents come", _test_hit_pace)
	_run_test("structure: no stranger builds within a block of someone else's structure, the owner still does", _test_placement_buffer)
	_run_test("structure: a clan structure whose clan has no members left is anyone's to edit and dismantle", _test_abandoned_clan)
	_run_test("structure: a placed block that falls keeps its owner and durability at its new height", _test_fallen_block_kept)
	_run_test("structure: a block indexed again is taken from its old structure; a natural span is nobody's", _test_stale_records)
	_run_test("structure: an axe hit on someone else's block wears the axe", _test_axe_wears)
	_run_test("structure: a repair restores durability for its share of materials, only by the owner", _test_repair)
	_run_test("structure: the index saves and loads, wears for downtime once and drops malformed entries", _test_persistence)
	_run_test("structure: blocks worn to nothing collapse in a bounded sweep, and the owner is told", _test_collapse_sweep)
	_run_test("structure: a station or a chop on someone else's structure is refused", _test_station_tree_guard)
	_run_test("structure: /buildas and /repair resolve on the host from its own records", _test_intents)
	_run_test("structure: /respawn kills the speaker's own character, at most once per cooldown", _test_respawn_command)
	_run_test("structure: a hit reaches peers in range as block_damaged", _test_damage_wire)
	_run_test("structure (audit): no owner, clan, durability or skill value is read from a client message", _test_audit_client_values)
	_run_test("structure circle: a larger structure has a larger circle, between the fabric's bounds, and it shrinks", _test_circle_size)
	_run_test("structure circle: the lookup finds a circle across bucket edges and the world seam", _test_circle_lookup)
	_run_test("structure circle: an outsider cannot build in a clan's circle until its building is destroyed", _test_circle_outsider)
	_run_test("structure circle: over a simulated day no creature spawns inside a circle, spawns go on outside", _test_circle_no_spawn)
	_run_test("structure circle: a kept-out pack comes back without a reload, a companion respawns in a circle", _test_circle_spawn_return)
	_run_test("structure circle: the running sums give the circle a full recount gives", _test_circle_incremental)
	_run_test("structure circle: a refused block tells its builder, a client is sent the circles it may not build in", _test_circle_feedback)
	_run_test("structure: a block of a material with no durability falls on the first sweep", _test_zero_durability_sweep)

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

## One swing: the clock moves on by the host's hit interval first, as a player clicking at full pace.
func _mine(r: Dictionary, pid: String, tx: int, tz: int, y: float) -> Dictionary:
	r["now"][0] += StructureSlice.HIT_INTERVAL
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
			r["now"][0] += StructureSlice.HIT_INTERVAL
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

## Review fix — the offline factor is a host rule only if the host spaces the hits: intents arriving
## faster than `HIT_INTERVAL` (a modified client, inside the network bucket) do no damage and wear no pick.
func _test_hit_pace() -> void:
	var r := _rig()
	var st: StructureSlice = r["st"]
	assert_true(_place(r, "p1", 2, 34, 2.0, "Soil"), "p1 builds")
	var first := _mine(r, "p3", 2, 34, 2.125)
	assert_true(bool(first.get("damaged", false)), "an outsider's first hit lands")
	var fraction := float(first["fraction"])
	var burst := {}
	for i in 20:
		burst = r["v"].mine_block(_xyz(2, 34, 2.125), Vector3.UP, "p3")
		assert_false(bool(burst.get("damaged", false)) or bool(burst["success"]), "hit %d inside the interval is refused" % i)
	assert_eq(str(st.plan_mine("p3", Vector2i(2, 34), 2.0, 2.125, "hand").get("reason", "")), "rate_limited", "with its reason")
	var next := _mine(r, "p3", 2, 34, 2.125)
	assert_true(bool(next.get("damaged", false)), "the next hit at pace lands")
	assert_true(float(next["fraction"]) < fraction, "and is the second hit's worth, not twenty-first")
	assert_true(_place(r, "p1", 2, 35, 2.0, "Soil"), "p1 builds beside it")
	var own: Dictionary = r["v"].mine_block(_xyz(2, 35, 2.125), Vector3.UP, "p1")
	assert_true(bool(own["success"]), "the owner dismantling is not held to the outsider's pace")
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
	# The sweep reads a structure's blocks only once wear could bring one to zero: a damaged block goes sooner.
	assert_true(_place(r, "p1", 60, 2, 2.0), "a sound block")
	assert_true(_place(r, "p1", 56, 2, 2.0), "and one p3 hits to under half its durability")
	var k := 0
	while k < 1000 and float(st.block_durability(Vector2i(56, 2), 2.0625).get("fraction", 0.0)) > 0.4:
		r["now"][0] += StructureSlice.HIT_INTERVAL
		var pl: Dictionary = st.plan_mine("p3", Vector2i(56, 2), 2.0, 2.125, "pick")
		st.commit_mine(pl)
		k += 1
	assert_true(float(st.block_durability(Vector2i(56, 2), 2.0625).get("fraction", 1.0)) <= 0.4, "the hit block is under half")
	for tx: int in [60, 56]:
		st.get_structure(_sid(r, tx, 2, 2.0))["wear"] = 0.65
	for i in 3:
		st.tick()
	assert_true(_sid(r, 60, 2, 2.0) != 0, "worn 65%, the sound block stands")
	assert_eq(_sid(r, 56, 2, 2.0), 0, "the damaged one collapses")
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

func _test_placement_buffer() -> void:
	var r := _rig()
	var st: StructureSlice = r["st"]
	assert_true(_place(r, "p2", 40, 40, 2.0), "p2 builds a private block on the ground")
	assert_false(_place(r, "p3", 41, 40, 2.0), "a stranger cannot build on the floor beside it")
	assert_false(_place(r, "p3", 41, 41, 2.0), "nor diagonally")
	assert_false(_place(r, "p1", 39, 40, 2.0), "nor may a clan member beside another member's private house")
	assert_eq(_count(r, "p3", "Ashite"), 2, "refused placements spend nothing")
	assert_eq(str(st.plan_place("p3", Vector2i(41, 40), 2.125, Vector3.UP, "Ashite").get("reason", "")), "not_owner",
		"a block one step up and one across is within the buffer")
	assert_eq(str(st.plan_place("p3", Vector2i(41, 40), 2.25, Vector3.UP, "Ashite").get("verdict", "")), "new",
		"two steps up leaves a block of space: allowed")
	assert_true(_place(r, "p2", 41, 40, 2.0), "the owner still builds right beside their own block")
	assert_eq(_sid(r, 41, 40, 2.0), _sid(r, 40, 40, 2.0), "and it joins their structure")
	assert_true(_place(r, "p3", 43, 40, 2.0), "two columns away leaves a block of space: a stranger builds there")
	assert_true(_place(r, "p3", 44, 40, 2.0), "and beside their own block")
	assert_eq(_sid(r, 44, 40, 2.0), _sid(r, 43, 40, 2.0), "a stranger's own structure grows beside itself")
	assert_false(_place(r, "p2", 42, 40, 2.0), "the buffer holds both ways: p2 cannot close the gap either")
	_free_rig(r)

func _test_abandoned_clan() -> void:
	var r := _rig()
	var st: StructureSlice = r["st"]
	assert_eq(st.set_build_mode("p1", "clan"), "", "p1 builds for the clan")
	assert_true(_place(r, "p1", 10, 10, 2.0), "a clan block")
	assert_true(_place(r, "p1", 10, 10, 2.125), "and another on it")
	var hall := _sid(r, 10, 10, 2.0)
	assert_false(st.may_edit("p3", hall), "an outsider may not edit a clan's structure")
	assert_eq(r["clans"].leave("p2"), "", "p2 leaves")
	assert_eq(r["clans"].leave("p1"), "", "the founder, alone, leaves: the clan is gone")
	assert_true(st.may_edit("p3", hall), "anyone may edit a structure whose clan has no members left")
	assert_true(st.may_dismantle("p3", hall), "and take it apart")
	var got := _mine(r, "p3", 10, 10, 2.25)
	assert_true(bool(got["success"]), "p3 takes a block apart instead of hitting it")
	assert_eq(int(st.get_structure(hall).get("count", 0)), 1, "one block of the hall is left")
	assert_true(_place(r, "p3", 10, 10, 2.125), "and p3 builds on what remains")
	_free_rig(r)

func _test_fallen_block_kept() -> void:
	var r := _rig()
	var st: StructureSlice = r["st"]
	var v: Node = r["v"]
	var tile := Vector2i(40, 40)
	assert_true(_place(r, "p1", 40, 40, 2.0, "Sand"), "p1 places sand on the ground")
	var house := _sid(r, 40, 40, 2.0)
	_mine(r, "p3", 40, 40, 2.125)   # one hit: the block carries some damage down with it
	var worn: float = float(st.block_durability(tile, 2.0625).get("durability", -1.0))
	# The ground under it is dug out from below (a tunnel): the sand hangs, then falls.
	v._append_edit(tile, { "op": "remove", "bottom": 1.5, "top": 2.0 })
	v._settle_note(tile)
	var guard := 0
	while v.settle_pending() > 0 and guard < 10:
		v.settle_tick()
		guard += 1
	assert_eq(float(v.get_runs_at_tile(tile)[-1]["top"]), 1.625, "the sand fell onto the dug floor")
	assert_eq(_sid(r, 40, 40, 1.5), house, "its record moved down with it")
	assert_eq(_sid(r, 40, 40, 2.0), 0, "and nothing is left in the air where it was")
	assert_eq(float(st.block_durability(tile, 1.5625).get("durability", -2.0)), worn, "with the durability it had")
	assert_true(bool(_mine(r, "p3", 40, 40, 1.625).get("damaged", false)), "a stranger still only damages it")
	_free_rig(r)

func _test_stale_records() -> void:
	var r := _rig()
	var st: StructureSlice = r["st"]
	assert_true(_place(r, "p1", 40, 40, 2.0), "p1 builds")
	assert_true(_place(r, "p1", 40, 40, 2.125), "two blocks")
	var old := _sid(r, 40, 40, 2.0)
	var plan := { "verdict": "new", "kind": "private", "owner": "p2", "player_id": "p2", "tile": Vector2i(40, 40),
		"mm": StructureSlice.mm_of(2.0), "material": "Ashite" }
	var fresh := st.commit_place(plan)
	assert_eq(_sid(r, 40, 40, 2.0), fresh, "a block indexed again belongs to the new structure")
	assert_eq(int(st.get_structure(old)["count"]), 1, "and is no longer counted in the old one")
	assert_eq(st.cell_count(), 2, "one record per block")
	# A record left over a natural span (an edit the index never saw): mining it is free and drops the record.
	plan.merge({ "tile": Vector2i(20, 20), "mm": StructureSlice.mm_of(1.875), "owner": "p1", "player_id": "p1" }, true)
	st.commit_place(plan)
	assert_true(_sid(r, 20, 20, 1.875) != 0, "a stale record sits in the natural ground")
	assert_true(bool(_mine(r, "p3", 20, 20, 2.0)["success"]), "a stranger digs the natural ground freely")
	assert_eq(_sid(r, 20, 20, 1.875), 0, "and the stale record is gone")
	_free_rig(r)

func _test_axe_wears() -> void:
	var r := _rig()
	var inv: Node = r["reg"].get_inventory("p3")
	assert_true(_place(r, "p1", 40, 40, 2.0, "Soil"), "p1 builds")
	inv.add_item("CarpenterAxe", 1)
	var before: float = inv.get_durability("CarpenterAxe")
	assert_true(bool(_mine(r, "p3", 40, 40, 2.125).get("damaged", false)), "an axe hit damages the block")
	assert_true(inv.get_durability("CarpenterAxe") < before, "and wears the axe")
	var mid: float = inv.get_durability("CarpenterAxe")
	assert_true(bool(_mine(r, "p3", 30, 30, 2.0)["success"]), "digging natural ground with no pick is bare-handed")
	assert_eq(inv.get_durability("CarpenterAxe"), mid, "and leaves the axe alone")
	_free_rig(r)

# ── Phase 206: circles ───────────────────────────────────────────────────

## Index one `p1` block at (`tile`, `mm`) without touching the world: `sid` 0 starts a structure for `kind`.
func _index(st: StructureSlice, tile: Vector2i, mm: int, sid: int = 0, kind: String = "private", owner: String = "p1") -> int:
	var plan := { "tile": StructureSlice.canonical(tile), "mm": mm, "material": "Ashite", "player_id": "p1" }
	plan.merge({ "verdict": "join", "sid": sid } if sid != 0 else { "verdict": "new", "kind": kind, "owner": owner })
	return st.commit_place(plan)

func _test_circle_size() -> void:
	var r := _rig()
	var st: StructureSlice = r["st"]
	var c: Dictionary = StructureRules.structure()["circle"]
	var lo := float(c["minRadius"])
	var hi := float(c["maxRadius"])
	var one := _index(st, Vector2i(0, 0), 2000)
	assert_near(float(st.circle_of(one)["radius"]), StructureRules.circle_radius(0.25, 0.125), "a single block's circle is its own size")
	assert_true(float(st.circle_of(one)["radius"]) < lo + 1.0, "within a metre of the minimum")
	var hall := _index(st, Vector2i(400, 400), 2000)
	for x in 20:
		for z in 20:
			if x != 0 or z != 0:
				_index(st, Vector2i(400 + x, 400 + z), 2000, hall)
	for k in range(1, 40):
		_index(st, Vector2i(400, 400), 2000 + 125 * k, hall)
	var big: Dictionary = st.circle_of(hall)
	assert_true(float(big["radius"]) > lo, "a 20 × 20 hall with a 5 m tower has a larger circle (%.2f m)" % float(big["radius"]))
	assert_near(float(big["radius"]), StructureRules.circle_radius(400 * 0.25, 5.0), "from its footprint and height")
	assert_true(float(big["radius"]) <= hi, "and no larger than the maximum")
	assert_near(StructureRules.circle_radius(1.0e9, 1.0e6), hi, "the largest structure is clamped to the maximum")
	assert_near(StructureRules.circle_radius(0.0, 0.0), lo, "the smallest to the minimum")
	for x in range(10, 20):
		for z in 20:
			st.drop_span(Vector2i(400 + x, 400 + z), 1.9, 2.1)
	var half := float(st.circle_of(hall)["radius"])
	assert_true(half < float(big["radius"]), "losing half its floor shrinks the circle (%.2f m)" % half)
	assert_true(half >= lo, "but never below the minimum")
	_free_rig(r)

func _test_circle_lookup() -> void:
	var r := _rig()
	var st: StructureSlice = r["st"]
	# A floor whose center sits on a bucket edge (64 m): points either side are in two buckets.
	var floor_id := _index(st, Vector2i(118, 0), 2000)
	for x in range(119, 138):
		_index(st, Vector2i(x, 0), 2000, floor_id)
	var center: Vector2 = st.circle_of(floor_id)["center"]
	assert_near(center.x, 64.0, "the floor is centred on the bucket edge")
	for qx: float in [57.0, 63.9, 64.1, 71.0]:
		assert_eq(st.circles_at(Vector2(qx, 0.25)), [floor_id], "the circle holds x = %.1f" % qx)
	assert_eq(st.circles_at(Vector2(64.0 + float(st.circle_of(floor_id)["radius"]) + 0.5, 0.25)), [], "and not a point past its radius")
	# At the seam: a block at the east edge of the lap, a point just over the seam to the west.
	var lap_tiles := TerrainSlice.circumference_chunks() * VoxelConsts.CHUNK_SIZE
	var lap_m := float(lap_tiles) * VoxelConsts.TILE_SIZE
	var east := _index(st, Vector2i(lap_tiles / 2 - 1, 0), 2000)
	assert_eq(st.circles_at(Vector2(-lap_m * 0.5 + 2.0, 0.25)), [east], "a circle reaches over the world seam")
	assert_eq(st.circles_at(Vector2(lap_m * 0.5 + 2.0, 0.25)), [east], "named from either side of it")
	# A structure across the seam is centred at the seam, not averaged to the far side of the world.
	_index(st, Vector2i(-lap_tiles / 2, 0), 2000, east)
	assert_true(absf(float(st.circle_of(east)["center"].x)) > lap_m * 0.25, "a structure across the seam is centred at the seam")
	assert_true(st.spawn_blocked(Vector2(lap_m * 0.5 - 1.0, 0.25)), "and blocks spawns there")
	_free_rig(r)

func _test_circle_outsider() -> void:
	var r := _rig()
	var st: StructureSlice = r["st"]
	assert_eq(st.set_build_mode("p1", "clan"), "", "p1 builds for the clan")
	assert_true(_place(r, "p1", 10, 10, 2.0, "Soil"), "the clan's hall")
	var hall := _sid(r, 10, 10, 2.0)
	assert_eq(str(st.plan_place("p3", Vector2i(16, 10), 2.0, Vector3.UP, "Ashite").get("reason", "")), "foreign_circle",
		"an outsider's structure 3 m from the hall is refused")
	assert_false(_place(r, "p3", 16, 10, 2.0), "and nothing is placed")
	assert_eq(_count(r, "p3", "Ashite"), 1, "or spent")
	assert_true(_place(r, "p2", 10, 18, 2.0), "a member's private house there is allowed")
	assert_eq(st.get_structure(_sid(r, 10, 18, 2.0))["kind"], "private", "and stays theirs")
	assert_true(_place(r, "p3", 60, 10, 2.0), "an outsider builds outside the circle")
	assert_true(_place(r, "p3", 61, 10, 2.0), "and beside their own there")
	var station := StationSlice.new()
	add_child(station)
	station.structure_guard = st.build_blocker
	assert_eq(station.placement_blocker("forge", _xyz(16, 10, 2.0), "p3"), "foreign_circle", "an outsider's station in the circle is refused")
	assert_eq(station.placement_blocker("forge", _xyz(16, 10, 2.0), "p2"), "", "a member's is not")
	var cats: Dictionary = I18nScript.parse_csv("res://locale/ui.csv")["catalog"]
	for loc in cats:
		for key: String in ["reason.foreign_circle", "structure.refused.foreign_circle"]:
			assert_true((cats[loc] as Dictionary).has(key), "%s has %s" % [loc, key])
	# Destroyed by force, the hall's circle goes with it.
	var hits := 0
	while hits < 5000 and _sid(r, 10, 10, 2.0) != 0:
		_mine(r, "p3", 10, 10, 2.125)
		hits += 1
	assert_eq(_sid(r, 10, 10, 2.0), 0, "p3 destroys the hall")
	assert_eq(st.foreign_circle_at("p3", StructureSlice._tile_xz(Vector2i(16, 10))), 0, "its circle is lifted")
	assert_eq(station.placement_blocker("forge", _xyz(16, 10, 2.0), "p3"), "", "the station is no longer refused")
	assert_true(_place(r, "p3", 16, 10, 2.0), "and the same placement now succeeds")
	station.free()
	_free_rig(r)

## World x/z (metres) of a creature's spawn point.
static func _spawn_xz(inst: Dictionary) -> Vector2:
	var at: Dictionary = inst["spawn_exact"]
	var chunk: Vector2i = at["chunk"]
	var local: Vector3 = at["local"]
	return Vector2(float(chunk.x) * WorldPos.CHUNK_METERS + local.x, float(chunk.y) * WorldPos.CHUNK_METERS + local.z)

func _test_circle_no_spawn() -> void:
	var r := _rig()
	var st: StructureSlice = r["st"]
	var c := CreatureSlice.new()
	add_child(c)
	var chunks: Array = []
	for x in 3:
		for z in 3:
			chunks.append(Vector2i(x, z))
	for ch: Vector2i in chunks:
		c.spawn_for_chunk(ch)
	var free_count := c._instances.size()
	assert_true(free_count > 0, "creatures spawn in the empty area (%d)" % free_count)
	# A house at three creatures' spawn points, one of them held alive across the build.
	var homes: Array = []
	for inst: Dictionary in c._instances.values().slice(0, 3):
		var xz := _spawn_xz(inst)
		homes.append(_index(st, Vector2i(floori(xz.x / VoxelConsts.TILE_SIZE), floori(xz.y / VoxelConsts.TILE_SIZE)), 2000))
	var resident: String = c._instances.keys()[0]
	c.spawn_blocked = st.spawn_blocked
	for ch: Vector2i in chunks:
		if ch != c._instances[resident]["chunk"]:
			c.despawn_for_chunk(ch)
	assert_true(c._instances.has(resident), "a creature already standing in a circle is not removed")
	c._instances[resident]["state"] = "dead"
	c._instances[resident]["respawn_at"] = 1.0
	c._tick_respawn()
	assert_eq(str(c._instances[resident]["state"]), "dead", "killed, it is held dead: its spawn point is in a circle")
	c.despawn_for_chunk(c._instances[resident]["chunk"])
	var spawned_outside := 0
	var inside := 0
	for hour in 24:
		for ch: Vector2i in chunks:
			c.spawn_for_chunk(ch)
		# Half the population dies and is due back at once: respawns obey the circles too.
		var k := 0
		for iid: String in c._instances:
			if k % 2 == hour % 2:
				c._instances[iid]["state"] = "dead"
				c._instances[iid]["respawn_at"] = 1.0
			k += 1
		c._tick_respawn()
		for iid: String in c._instances:
			var inst: Dictionary = c._instances[iid]
			if str(inst["state"]) == "dead":
				continue
			if st.spawn_blocked(_spawn_xz(inst)):
				inside += 1
			else:
				spawned_outside += 1
		for ch: Vector2i in chunks:
			c.despawn_for_chunk(ch)
	assert_eq(inside, 0, "over a day no creature spawns or respawns inside a circle")
	assert_true(spawned_outside > 0, "spawns go on outside (%d live sightings)" % spawned_outside)
	for ch: Vector2i in chunks:
		c.spawn_for_chunk(ch)
	var blocked_count := c._instances.size()
	assert_true(blocked_count < free_count, "the circles keep %d creatures away" % (free_count - blocked_count))
	for ch: Vector2i in chunks:
		c.despawn_for_chunk(ch)
	for sid: int in homes:
		for t: Vector2i in (st.get_structure(sid).get("cells", {}) as Dictionary).keys():
			st.drop_span(t, 0.0, 10.0)
	assert_eq(st.count(), 0, "the houses are gone")
	for ch: Vector2i in chunks:
		c.spawn_for_chunk(ch)
	assert_eq(c._instances.size(), free_count, "and every spawn comes back")
	c.free()
	_free_rig(r)

func _test_circle_spawn_return() -> void:
	var r := _rig()
	var st: StructureSlice = r["st"]
	var c := CreatureSlice.new()
	add_child(c)
	var chunks: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	for ch: Vector2i in chunks:
		c.spawn_for_chunk(ch)
	var free_count := c._instances.size()
	assert_true(free_count > 0, "creatures spawn in the empty area (%d)" % free_count)
	var inst: Dictionary = c._instances.values()[0]
	var xz := _spawn_xz(inst)
	var home := _index(st, Vector2i(floori(xz.x / VoxelConsts.TILE_SIZE), floori(xz.y / VoxelConsts.TILE_SIZE)), 2000)
	c.spawn_blocked = st.spawn_blocked
	for ch: Vector2i in chunks:
		c.despawn_for_chunk(ch)
	for ch: Vector2i in chunks:
		c.spawn_for_chunk(ch)
	var kept_out := free_count - c._instances.size()
	assert_true(kept_out > 0, "the house keeps %d creatures away" % kept_out)
	assert_false(c._deferred_packs.is_empty(), "the kept-out members are remembered")
	c._retry_deferred_packs()
	assert_eq(c._instances.size(), free_count - kept_out, "a retry while the house stands spawns none of them")
	for t: Vector2i in (st.get_structure(home).get("cells", {}) as Dictionary).keys():
		st.drop_span(t, 0.0, 10.0)
	c._retry_deferred_packs()
	assert_eq(c._instances.size(), free_count, "the house gone, the pack is whole again with the chunk still loaded")
	assert_true(c._deferred_packs.is_empty(), "and nothing is pending")
	# A tamed companion whose spawn point a circle covers still comes back.
	var iid: String = c._instances.keys()[0]
	var pet: Dictionary = c._instances[iid]
	var pxz := _spawn_xz(pet)
	_index(st, Vector2i(floori(pxz.x / VoxelConsts.TILE_SIZE), floori(pxz.y / VoxelConsts.TILE_SIZE)), 2000)
	assert_true(st.spawn_blocked(pxz), "the companion's spawn point is in a circle")
	pet["tamed_by"] = "p1"
	pet["state"] = "dead"
	pet["respawn_at"] = 1.0
	c._tick_respawn()
	assert_true(str(c._instances[iid]["state"]) != "dead" or float(c._instances[iid]["respawn_at"]) < 0.0,
		"a tamed companion is not held dead by a circle")
	c.free()
	_free_rig(r)

## The circle `_compute_circle` would give from a full recount of `s`'s cells.
static func _recount_circle(s: Dictionary) -> Dictionary:
	var cells: Dictionary = s["cells"]
	var lap := SeamWrap.world_tiles(TerrainSlice.circumference_chunks(), VoxelConsts.CHUNK_SIZE)
	var a: Vector2i = s["anchor"]
	var sum := Vector2.ZERO
	var lo := 1 << 40
	var hi := -(1 << 40)
	for t: Vector2i in cells:
		sum += Vector2(float(SeamWrap.delta(t.x, a.x, lap)), float(t.y - a.y))
		for mm: int in cells[t]:
			lo = mini(lo, mm)
			hi = maxi(hi, mm + StructureSlice.mm_of(VoxelConsts.STEP_HEIGHT))
	var n := float(cells.size())
	var center := (Vector2(a) + sum / n + Vector2(0.5, 0.5)) * VoxelConsts.TILE_SIZE
	center.x = SeamWrap.wrap_f(center.x, float(TerrainSlice.circumference_chunks()) * WorldPos.CHUNK_METERS)
	return { "center": center, "radius": StructureRules.circle_radius(n * VoxelConsts.TILE_SIZE * VoxelConsts.TILE_SIZE, float(hi - lo) / 1000.0) }

func _test_circle_incremental() -> void:
	var r := _rig()
	var st: StructureSlice = r["st"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 206
	# A structure across x = 0, grown and cut at random; each step's circle matches a full recount. (At the
	# seam the centre is ±20 000 km, where a float32 coordinate moves in 2 m steps: `_test_circle_lookup`.)
	var sid := _index(st, Vector2i(-3, 5), 2000)
	var mismatches := 0
	for i in 400:
		var t := Vector2i(-8 + rng.randi_range(0, 15), 5 + rng.randi_range(0, 6))
		var mm := 2000 + 125 * rng.randi_range(0, 12)
		if rng.randf() < 0.6:
			if int((st._tiles.get(StructureSlice.canonical(t), {}) as Dictionary).get(mm, 0)) == 0:
				_index(st, t, mm, sid)
		elif st.count() > 0 and int(st.get_structure(sid).get("count", 0)) > 1:
			st.drop_span(t, float(mm) / 1000.0 - 0.01, float(mm) / 1000.0 + 0.01)
		if not st._structures.has(sid):
			break
		var got := st.circle_of(sid)
		var want := _recount_circle(st._structures[sid])
		if (got["center"] as Vector2).distance_to(want["center"]) > 1.0e-3 or absf(float(got["radius"]) - float(want["radius"])) > 1.0e-4:
			mismatches += 1
	assert_eq(mismatches, 0, "over 400 random edits the circle always matches a full recount")
	_free_rig(r)

func _test_circle_feedback() -> void:
	var r := _rig()
	var st: StructureSlice = r["st"]
	assert_eq(st.set_build_mode("p1", "clan"), "", "p1 builds for the clan")
	assert_true(_place(r, "p1", 10, 10, 2.0, "Soil"), "the clan's hall")
	var heard: Array = []
	var on := func(pid: String, action: String, ok: bool, reason: String) -> void: heard.append([pid, action, ok, reason])
	GameBus.structure_resolved.connect(on)
	assert_false(_place(r, "p3", 16, 10, 2.0), "an outsider's block in the circle is refused")
	GameBus.structure_resolved.disconnect(on)
	assert_eq(heard, [["p3", "place", false, "foreign_circle"]], "and the builder is told why")
	var at := StructureSlice._tile_xz(Vector2i(16, 10))
	var view: Array = st.foreign_circles_near("p3", at, 64.0)
	assert_eq(view.size(), 1, "the outsider's client is sent the hall's circle")
	assert_eq(st.foreign_circles_near("p2", at, 64.0), [], "a member's is sent none")
	assert_eq(st.foreign_circles_near("p3", at + Vector2(1000.0, 0.0), 64.0), [], "nor anyone far from it")
	var w := StructureWiring.new()
	w.apply_circle_view({ "circle_view": view })
	assert_eq(w.view_blocker("p3", _xyz(16, 10, 2.0)), "foreign_circle", "the client's ghost shows the station refused")
	assert_eq(w.view_blocker("p3", _xyz(200, 10, 2.0)), "", "and allowed outside the circle")
	w.apply_circle_view({ "circle_view": [[1.0, 2.0], "x", [INF, 0.0, 5.0], [0.0, 0.0, 3.0]] })
	assert_eq(w._circle_view, [[0.0, 0.0, 3.0]], "a malformed entry is dropped")
	var cats: Dictionary = I18nScript.parse_csv("res://locale/ui.csv")["catalog"]
	for loc in cats:
		for key: String in ["settlement.refused.foreign_circle", "bed.refuse_circle"]:
			assert_true((cats[loc] as Dictionary).has(key), "%s has %s" % [loc, key])
	assert_eq(StructureSlice.REASONS[0], "not_owner", "a new reason is added at the end, the old ones keep their place")
	_free_rig(r)

func _test_zero_durability_sweep() -> void:
	var r := _rig()
	var st: StructureSlice = r["st"]
	var s := { "hurt": 0.0 }
	st._note_hurt(s, ["NoSuchMaterial", 0.0, 0.0])
	assert_near(float(s["hurt"]), 1.0, "a block with no base durability counts as at zero from the start")
	_free_rig(r)
