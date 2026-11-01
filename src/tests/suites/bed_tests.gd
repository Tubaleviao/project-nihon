extends "res://src/tests/test_support.gd"
## Phase 185 — the bed is the spawn point: the respawn rule prefers it, a second bed replaces the first,
## a lost bed is cleared with a keyed notice, a blocked bed finds the nearest free cell, and the host
## refuses a bad placement with its own key. Socket behaviour is in the net harness (`bed_spawn`).

const BedStore := preload("res://src/world/bed_store.gd")
const SpawnFinder := preload("res://src/world/spawn_finder.gd")
const BedRule := preload("res://src/world/bed_rule.gd")
const I18n := preload("res://src/core/i18n.gd")
const BedSlice := preload("res://src/world/bed_slice.gd")

var _runs: Array = []        ## extra runs on top of the ground, for the fixture world
var _resolved: Array = []    ## [player_id, ok, key]
var _synced: Array = []      ## [player_id, bed]
var _placed: Array = []      ## station_placed ids

func register() -> void:
	_run_test("bed: respawn_point_for prefers the bed, then the original spawn; a pre-185 record has no bed", _test_respawn_rule)
	_run_test("bed: the bed survives a save and reload", _test_persistence)
	_run_test("bed: a second bed replaces the first and returns it as an item", _test_replace)
	_run_test("bed: a destroyed bed station or support clears the entry and notifies the owner", _test_lost)
	_run_test("bed: a blocked bed respawns at the nearest free cell, else the original spawn", _test_blocked)
	_run_test("bed: the host refuses a bad placement, each with its own key", _test_refusals)
	_run_test("bed: every refusal key is in both catalog columns", _test_catalog)

# --- fixtures ---------------------------------------------------------------------------------------------

func _ground(_tile: Vector2i) -> Array:
	return [{ "bottom": -10.0, "top": 0.0 }] + _runs

class Rig:
	var reg: PlayerRegistry
	var station: StationSlice
	var bed: BedSlice
	var pid := "p1"

func _rig() -> Rig:
	_runs = []
	_resolved = []
	_synced = []
	_placed = []
	var r := Rig.new()
	r.reg = PlayerRegistry.new()
	r.reg.is_authoritative = true
	add_child(r.reg)
	r.reg.ensure_player("p1")
	r.reg.ensure_player("p2")
	r.station = StationSlice.new()
	add_child(r.station)
	r.bed = BedSlice.new()
	r.bed.station_slice = r.station
	r.bed.registry = r.reg
	r.bed.runs_at = self._ground
	r.bed.position_of = func(_pid: String) -> Dictionary:
		return { "chunk": Vector2i.ZERO, "local": Vector3(0.0, 0.0, 0.0) }
	add_child(r.bed)
	return r

func _free(r: Rig) -> void:
	r.bed.free()
	r.station.free()
	r.reg.free()

func _connect() -> Array:
	var a := func(pid: String, ok: bool, key: String) -> void: _resolved.append([pid, ok, key])
	var b := func(pid: String, bed: Dictionary) -> void: _synced.append([pid, bed])
	GameBus.bed_resolved.connect(a)
	GameBus.bed_synced.connect(b)
	return [a, b]

func _disconnect(c: Array) -> void:
	GameBus.bed_resolved.disconnect(c[0])
	GameBus.bed_synced.disconnect(c[1])

## Hand `pid` a Bed and place it at `offset` through the intent, claiming it as the wiring would.
func _place(r: Rig, pid: String, offset: Vector3, give := true) -> void:
	if give:
		r.reg.get_inventory(pid).add_item("Bed", 1)
	var claim := func(id: String, type: String, pos: Vector3) -> void:
		_placed.append(id)
		var who := r.bed.placing_for()
		var exact := WorldPos.from_world(pos.x, pos.y, pos.z)
		if type == r.bed.station_type():
			r.bed.claim(who, id, exact)
	GameBus.station_placed.connect(claim)
	r.bed._last_intent.clear()
	GameBus.bed_place_intent.emit(offset, pid)
	GameBus.station_placed.disconnect(claim)

func _world(wp: Dictionary) -> Vector3:
	var c: Vector2i = wp["chunk"]
	var l: Vector3 = wp["local"]
	return Vector3(c.x * WorldPos.CHUNK_METERS + l.x, l.y, c.y * WorldPos.CHUNK_METERS + l.z)

func _last_key() -> String:
	return "" if _resolved.is_empty() else str(_resolved.back()[2])

# --- tests ------------------------------------------------------------------------------------------------

func _test_respawn_rule() -> void:
	var root_script: GDScript = load("res://src/core/game_root.gd")
	var reg := PlayerRegistry.new()
	reg.is_authoritative = true
	reg.record_spawn_world_pos("a", { "chunk": Vector2i(1, 2), "local": Vector3(3, 4, 5) })
	var orig: Variant = root_script.respawn_point_for(reg.get_record("a"))
	assert_eq(orig["chunk"], Vector2i(1, 2), "without a bed the original spawn")
	BedStore.set_bed(reg, "a", { "chunk": Vector2i(-4, 7), "local": Vector3(1, 2, 3) }, "station_9")
	var with_bed: Variant = root_script.respawn_point_for(reg.get_record("a"))
	assert_eq(with_bed["chunk"], Vector2i(-4, 7), "with a bed the bed")
	assert_eq(SpawnFinder.original_spawn_for(reg.get_record("a"))["chunk"], Vector2i(1, 2), "the original spawn is still recorded")
	# A pre-185 record: no bed key at all.
	var old := reg.get_player_data("a")
	old.erase("bed")
	old.erase("bed_station")
	var pre := PlayerRegistry.new()
	pre.apply_player_data("a", old)
	assert_eq(BedStore.of(pre, "a"), null, "a pre-185 record loads with no bed")
	assert_eq(root_script.respawn_point_for(pre.get_record("a"))["chunk"], Vector2i(1, 2), "and the same respawn point as before")
	old["bed"] = { "chunk": ["x"], "local": [1] }
	pre.apply_player_data("a", old)
	assert_eq(BedStore.of(pre, "a"), null, "a malformed bed is dropped")
	reg.free()
	pre.free()

func _test_persistence() -> void:
	var reg := PlayerRegistry.new()
	reg.is_authoritative = true
	var wp := { "chunk": Vector2i(-300000, 500), "local": Vector3(3.5, 50.0, 9.25) }
	reg.record_spawn_world_pos("a", { "chunk": Vector2i.ZERO, "local": Vector3.ZERO })
	BedStore.set_bed(reg, "a", wp, "station_3")
	var back := PlayerRegistry.new()
	back.apply_player_data("a", reg.get_player_data("a"))
	var got: Variant = BedStore.of(back, "a")
	assert_eq(got["chunk"], wp["chunk"], "the bed chunk is exact after a reload")
	assert_true((got["local"] as Vector3).distance_to(wp["local"]) < 1.0e-6, "and its local")
	assert_eq(BedStore.station_of(back, "a"), "station_3", "and the station that draws it")
	assert_eq(BedStore.owner_of_station(back, "station_3"), "a", "which finds the owner")
	reg.free()
	back.free()

func _test_replace() -> void:
	var r := _rig()
	var c := _connect()
	_place(r, "p1", Vector3(2, 0, 0))
	assert_eq(_last_key(), "bed.placed", "the first bed is placed")
	var first: String = BedStore.station_of(r.reg, "p1")
	assert_true(first != "" and r.station.get_station(first).size() > 0, "its station exists")
	assert_eq(r.reg.get_inventory("p1").get_item_count("Bed"), 0, "placing consumed the Bed item")
	_place(r, "p1", Vector3(-3, 0, 0))
	var second: String = BedStore.station_of(r.reg, "p1")
	assert_true(second != first, "the second bed is a new station")
	assert_eq(r.station.get_station(first).size(), 0, "the first station is removed")
	assert_eq(r.reg.get_inventory("p1").get_item_count("Bed"), 1, "and drops back as an item")
	assert_true(BedStore.of(r.reg, "p1") != null, "the owner still has exactly one bed")
	assert_true(_synced.size() >= 1 and str(_synced.back()[0]) == "p1", "bed_synced names its owner only")
	_disconnect(c)
	_free(r)

func _test_lost() -> void:
	var r := _rig()
	var c := _connect()
	_place(r, "p1", Vector3(2, 0, 0))
	var id: String = BedStore.station_of(r.reg, "p1")
	_resolved.clear()
	r.station.remove_station(id)
	r.bed.on_station_removed(id)   # the wiring forwards GameBus.station_removed
	assert_eq(BedStore.of(r.reg, "p1"), null, "removing the station clears the bed")
	assert_eq(_last_key(), "bed.lost", "and the owner gets bed.lost")
	assert_true((_synced.back()[1] as Dictionary).is_empty(), "bed_synced carries an empty bed")
	# A destroyed support block.
	_place(r, "p1", Vector3(2, 0, 0))
	_resolved.clear()
	r.bed.on_block_changed(Vector3(2.5, -0.5, 0.5))
	assert_true(BedStore.of(r.reg, "p1") != null, "a block edit with the ground still under the bed keeps it")
	var holed := func(_tile: Vector2i) -> Array: return [{ "bottom": -10.0, "top": -3.0 }]
	r.bed.runs_at = holed
	r.bed.on_block_changed(Vector3(2.5, -0.5, 0.5))
	assert_eq(BedStore.of(r.reg, "p1"), null, "a bed with no support left is cleared")
	assert_eq(_last_key(), "bed.lost", "with the notice")
	# A regenerated world clears every bed.
	r.bed.runs_at = self._ground
	_place(r, "p1", Vector3(2, 0, 0))
	_place(r, "p2", Vector3(-2, 0, 0))
	r.bed.clear_all()
	assert_true(BedStore.of(r.reg, "p1") == null and BedStore.of(r.reg, "p2") == null, "clear_all drops every bed")
	_disconnect(c)
	_free(r)

func _test_blocked() -> void:
	var root_script: GDScript = load("res://src/core/game_root.gd")
	var reg := PlayerRegistry.new()
	reg.is_authoritative = true
	reg.record_spawn_world_pos("a", { "chunk": Vector2i.ZERO, "local": Vector3(40, 0, 40) })
	BedStore.set_bed(reg, "a", { "chunk": Vector2i.ZERO, "local": Vector3(2.25, 0, 2.25) }, "s")
	var open := func(_t: Vector2i) -> Array: return [{ "bottom": -10.0, "top": 0.0 }]
	var free_pt: Variant = root_script.respawn_point_for(reg.get_record("a"), open)
	assert_true((free_pt["local"] as Vector3).distance_to(Vector3(2.25, 0, 2.25)) < 1.0e-5, "a free bed is the respawn point")
	# A pillar fills the bed's own tile and the ring around it.
	var bed_tile := BedRule.tile_of(Vector3(2.25, 0, 2.25))
	var pillar := func(t: Vector2i) -> Array:
		if absi(t.x - bed_tile.x) <= 1 and absi(t.y - bed_tile.y) <= 1:
			return [{ "bottom": -10.0, "top": 5.0 }]
		return [{ "bottom": -10.0, "top": 0.0 }]
	assert_true(BedRule.blocked(Vector3(2.25, 0, 2.25), pillar), "the bed's spot is blocked by the pillar")
	var moved: Variant = root_script.respawn_point_for(reg.get_record("a"), pillar)
	var d: float = ((moved["local"] as Vector3) - Vector3(2.25, 0, 2.25)).length()
	assert_true(d > 0.5 and d < 2.5, "a blocked bed respawns at the nearest free cell (%.2f m away)" % d)
	assert_false(BedRule.blocked(moved["local"], pillar), "which is free to stand in")
	# Everything solid around: no free cell, so the original spawn.
	var solid := func(_t: Vector2i) -> Array: return [{ "bottom": -10.0, "top": 50.0 }]
	var fallback: Variant = root_script.respawn_point_for(reg.get_record("a"), solid)
	assert_true(_world(fallback).distance_to(Vector3(40, 0, 40)) < 1.0e-4, "no free cell falls back to the original spawn")
	reg.free()

func _test_refusals() -> void:
	var r := _rig()
	var c := _connect()
	_place(r, "p1", Vector3(2, 0, 0), false)
	assert_eq(_last_key(), "bed.refuse_no_item", "no Bed item")
	_place(r, "p1", Vector3(40, 0, 0))
	assert_eq(_last_key(), "bed.refuse_far", "out of reach")
	assert_eq(r.reg.get_inventory("p1").get_item_count("Bed"), 1, "a refusal keeps the item")
	r.station.structure_guard = func(_pid: String, _pos: Vector3) -> String: return "not_owner"
	_place(r, "p1", Vector3(2, 0, 0), false)
	assert_eq(_last_key(), "bed.refuse_structure", "on a structure it may not edit")
	r.station.structure_guard = Callable()
	_runs = [{ "bottom": 0.0, "top": 3.0 }]
	_place(r, "p1", Vector3(2, 0, 0), false)
	assert_eq(_last_key(), "bed.refuse_blocked", "no free space")
	_runs = []
	_place(r, "p2", Vector3(-2, 0, 0))
	assert_eq(_last_key(), "bed.placed", "another player places theirs")
	_place(r, "p1", Vector3(-2, 0, 0), false)
	assert_eq(_last_key(), "bed.refuse_not_yours", "another player's bed cannot be claimed")
	assert_true(BedStore.of(r.reg, "p1") == null, "p1 owns nothing")
	_place(r, "p1", Vector3(2, 0, 0), false)
	r.station.place_station("forge", Vector3(4.5, 0, 0.5))
	_place(r, "p1", Vector3(4, 0, 0))
	assert_eq(_last_key(), "bed.refuse_occupied", "a spot with another station on it")
	# The rate limit: two intents in a row.
	r.bed._last_intent["p1"] = r.bed._now()
	GameBus.bed_place_intent.emit(Vector3(1, 0, 0), "p1")
	assert_eq(_last_key(), "bed.refuse_rate", "a second intent inside the interval")
	GameBus.bed_place_intent.emit(Vector3(1, 0, 0), "")
	_disconnect(c)
	_free(r)

func _test_catalog() -> void:
	for k in ["bed.placed", "bed.lost", "bed.refuse_no_item", "bed.refuse_far", "bed.refuse_structure",
			"bed.refuse_not_yours", "bed.refuse_occupied", "bed.refuse_blocked", "bed.refuse_rate"]:
		assert_true(I18n.has_key(k), "%s is in the catalog" % k)
		assert_true(I18n.t(k) != k and I18n.t(k).length() > 4, "%s has English text" % k)
