extends "res://src/tests/test_support.gd"
## Phase 268 — stations are made, carried and placed from the hotbar: the fabric table, no B/N/V shortcuts,
## the hotbar ghost (shown only with a station item, following the aim, the host's own refusal), the use input's
## one request with its rotation, the host paying one item and refusing without it, and the owner picking a
## placed station up again (another player, or the owner out of reach, refused).

const StationRules := preload("res://src/world/station_rules.gd")
const StationPlacer := preload("res://src/player/station_placer.gd")
const StationWiring := preload("res://src/world/station_wiring.gd")
const Hotbar := preload("res://src/ui/hotbar.gd")
const InputLabels := preload("res://src/ui/input_labels.gd")
const GameRoot := preload("res://src/core/game_root.gd")
const I18n := preload("res://src/core/i18n.gd")

const AT := Vector3(10.5, 2.0, 10.5)

func register() -> void:
	_run_test("stations: every placeable type has a placement item tagged station, and each item a recipe", _test_table)
	_run_test("stations: B, N and V no longer place or cycle stations, and no label names them", _test_no_shortcuts)
	_run_test("stations: no station item selected, no ghost; one selected, the ghost follows the aim with the host's refusal", _test_ghost)
	_run_test("stations: the use input emits one placement request with the rotation R turned", _test_request)
	_run_test("stations: the host refuses a placement without the item and consumes one on success", _test_host_pays)
	_run_test("stations: the owner picks a placed station up and gets its item back; others and the far owner are refused", _test_pick_up)
	_run_test("stations: a station's owner and rotation persist, and a client's copy carries no owner", _test_persistence)
	_run_test("stations: a hotbar box with a station item is a station box, and selecting it arms the player", _test_hotbar_kind)
	_run_test("stations: every placement notice has text in both catalog columns", _test_catalog)

# ── rig ──────────────────────────────────────────────────────────────────

## A host GameRoot (not in the tree) with a registry (p1, p2), a station slice and the station wiring wired; every
## player stands at `pos[pid]` (AT unless moved).
func _rig() -> Dictionary:
	var root: GameRoot = GameRoot.new()
	var reg := PlayerRegistry.new()
	reg.is_authoritative = true
	add_child(reg)
	reg.set_local_player("host")
	for p in ["p1", "p2"]:
		reg.ensure_player(p)
	var st := StationSlice.new()
	add_child(st)
	root._registry = reg
	root._station = st
	root._is_client = false
	var w := StationWiring.new()
	w.root = root
	var pos := {}
	w.position_of = func(pid: String) -> Variant: return pos.get(pid, AT)
	return { "root": root, "reg": reg, "st": st, "w": w, "pos": pos }

func _free_rig(r: Dictionary) -> void:
	r["w"].unwire()
	r["st"].free()
	r["reg"].free()
	r["root"].free()

func _inv(r: Dictionary, pid: String) -> Node:
	return r["reg"].get_inventory(pid)

func _place(r: Dictionary, pid: String, item: String, off: Vector3, rot := 0) -> String:
	r["w"]._last_place.clear()
	return r["w"].resolve("place", { "item": item, "ox": off.x, "oy": off.y, "oz": off.z, "rot": rot }, pid)

# ── tests ────────────────────────────────────────────────────────────────

func _test_table() -> void:
	var st := StationSlice.new()
	add_child(st)
	for t: String in st.placeable_station_types():
		var item := StationRules.placement_item(t)
		assert_true(item != "", "%s has a placement item" % t)
		assert_eq(st.placement_item(t), item, "and the slice pays %s with it" % t)
		assert_eq(StationRules.type_for_item(item), t, "%s places %s" % [item, t])
		var made := false
		for k in GameData.RECIPES:
			for o: Dictionary in (GameData.RECIPES[k].get("recipe") as Dictionary).get("outputs", []):
				made = made or str(o.get("item", "")) == item
		assert_true(made or item == "Hearth", "a recipe makes %s" % item)
	assert_eq(StationRules.placement_item("carpentry bench"), "CarpentryBench", "the first station is the carpentry bench")
	var bench: Dictionary = GameData.RECIPES["RecipeCarpentryBench"].get("recipe")
	assert_eq(str(bench.get("station", "x")), "", "made by hand")
	assert_eq(StationRules.type_for_item("FerritePick"), "", "a pick places nothing")
	st.free()

func _test_no_shortcuts() -> void:
	var st := StationSlice.new()
	add_child(st)
	var p := PlayerSlice.new()
	add_child(p)
	p.station_slice = st
	p.spawn_at(AT)
	var sent: Array = []
	var on := func(a: String, args: Dictionary, pid: String) -> void: sent.append([a, args, pid])
	GameBus.station_intent.connect(on)
	for key in [KEY_B, KEY_N, KEY_V]:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.pressed = true
		p._unhandled_input(ev)
	assert_eq(st.get_all_stations().size(), 0, "B, N and V place no station")
	assert_false(st.is_preview_visible(), "and show no ghost")
	assert_true(sent.filter(func(s: Array) -> bool: return s[0] == "place").is_empty(), "nor ask the host to place one")
	assert_false(p.has_method("_cycle_station_type") or p.has_method("_place_station"), "the cycle and place handlers are gone")
	assert_false(st.has_method("cycle_station_type"), "and so is the slice's cycle")
	GameBus.station_intent.disconnect(on)
	for row: Dictionary in InputLabels.controls_rows():
		if str(row["action"]) == "station":
			assert_false(str(row["keys"]).contains("V"), "the station row no longer names V")
	p.free()
	st.free()

func _test_ghost() -> void:
	var st := StationSlice.new()
	add_child(st)
	var inv := InventorySlice.new()
	add_child(inv)
	var placer := StationPlacer.new()
	placer.select("Thornwood")
	assert_eq(placer.update(st, inv, AT, "", true), "-", "no station item selected: no ghost")
	assert_false(st.is_preview_visible(), "nothing is drawn")
	placer.select("CarpentryBench")
	assert_eq(placer.update(st, inv, AT, "", true), "-", "a station item the pack does not hold shows no ghost")
	inv.add_item("CarpentryBench", 1)
	assert_eq(placer.update(st, inv, AT, "", true), "", "with the item the ghost shows at the aim, placeable")
	assert_true(st.is_preview_visible(), "the ghost is drawn")
	assert_eq(st.preview_position(), st.snap_to_grid(AT), "at the snapped aimed spot")
	var other := Vector3(20.2, 3.0, 4.7)
	placer.update(st, inv, other, "", true)
	assert_eq(st.preview_position(), st.snap_to_grid(other), "and follows the aim")
	assert_eq(st.place_station("forge", st.snap_to_grid(other)) != "", true, "a station stands there")
	var why := placer.update(st, inv, other, "", true)
	assert_true(why.begins_with("too_close_station"), "the ghost reports the overlap")
	assert_eq(why, st.place_refusal("carpentry bench", other, inv, ""), "the same refusal the host checks")
	assert_false(st.preview_ok(), "and is tinted refused")
	assert_true(placer.hint().contains("("), "the hint names the reason")
	placer.update(st, inv, AT, "", false)
	assert_false(st.is_preview_visible(), "a frozen world hides it")
	inv.free()
	st.free()

func _test_request() -> void:
	var st := StationSlice.new()
	add_child(st)
	var p := PlayerSlice.new()
	add_child(p)
	p.station_slice = st
	var inv := InventorySlice.new()
	add_child(inv)
	p.inventory_slice = inv
	p.spawn_at(AT)
	inv.add_item("Forge", 1)
	var sent: Array = []
	var on := func(a: String, args: Dictionary, pid: String) -> void: sent.append([a, args, pid])
	GameBus.station_intent.connect(on)
	GameBus.hotbar_station_selected.emit("Forge")
	var r := InputEventKey.new()
	r.keycode = KEY_R
	r.pressed = true
	p._unhandled_input(r)
	p._unhandled_input(r)
	assert_eq(p._station_placer.rotation, 2, "R turns the ghost a quarter turn each press")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	p._unhandled_input(click)
	assert_eq(sent.size(), 1, "the use input emits one request")
	if sent.size() == 1:
		assert_eq(sent[0][0], "place", "a placement")
		assert_eq(sent[0][1]["item"], "Forge", "of the selected item")
		assert_eq(int(sent[0][1]["rot"]), 2, "with the rotation")
		assert_eq(sent[0][2], "", "the host binds who asks")
	assert_eq(st.get_all_stations().size(), 0, "nothing is placed on this machine")
	GameBus.hotbar_station_selected.emit("")
	p._unhandled_input(r)
	assert_eq(p._station_placer.rotation, 0, "with no station item R is the material cycle again")
	GameBus.station_intent.disconnect(on)
	p.free()
	inv.free()
	st.free()

func _test_host_pays() -> void:
	var r := _rig()
	var st: StationSlice = r["st"]
	assert_eq(_place(r, "p1", "Forge", Vector3(1, 0, 0)), "no_item", "a placement whose item is not in the bag is refused")
	assert_eq(st.get_all_stations().size(), 0, "and places nothing")
	_inv(r, "p1").add_item("Forge", 1)
	assert_eq(_place(r, "p1", "FerritePick", Vector3(1, 0, 0)), "bad_args", "an item that places no station is refused")
	assert_eq(_place(r, "p1", "Forge", Vector3(50, 0, 0)), "far", "out of reach is refused")
	assert_eq(_place(r, "p1", "Forge", Vector3(1, 0, 0), 3), "", "with the item it places")
	assert_eq(int(_inv(r, "p1").get_item_count("Forge")), 0, "and consumes it")
	var all: Array = st.get_all_stations()
	assert_eq(all.size(), 1, "one station")
	if all.size() == 1:
		assert_eq(str(all[0]["type"]), "forge", "a forge")
		assert_eq(str(all[0]["owner"]), "p1", "owned by its placer")
		assert_eq(int(all[0]["rotation"]), 3, "turned as asked")
		assert_eq(all[0]["position"], st.snap_to_grid(AT + Vector3(1, 0, 0)), "at the offset from where the host knows p1 stands")
	assert_eq(_place(r, "p1", "Forge", Vector3(3, 0, 0)), "no_item", "a second placement without a second item is refused")
	_inv(r, "p2").add_item("Forge", 1)
	assert_eq(_place(r, "p2", "Forge", Vector3(1, 0, 0)), "blocked", "an occupied cell is refused")
	assert_eq(int(_inv(r, "p2").get_item_count("Forge")), 1, "and keeps the item")
	assert_eq(r["w"].resolve("place", { "item": "Forge", "ox": "x", "oy": 0, "oz": 0 }, "p2"), "bad_args", "a malformed offset is refused")
	_free_rig(r)

func _test_pick_up() -> void:
	var r := _rig()
	var st: StationSlice = r["st"]
	_inv(r, "p1").add_item("CarpentryBench", 1)
	assert_eq(_place(r, "p1", "CarpentryBench", Vector3(1, 0, 0)), "", "p1 places a bench")
	var id := str(st.get_all_stations()[0]["id"])
	r["w"]._last_pick.clear()
	assert_eq(r["w"].resolve("pick_up", { "id": id }, "p2"), "not_owner", "another player is refused")
	r["pos"]["p1"] = AT + Vector3(30, 0, 0)
	r["w"]._last_pick.clear()
	assert_eq(r["w"].resolve("pick_up", { "id": id }, "p1"), "far", "the owner out of reach is refused")
	assert_eq(st.get_all_stations().size(), 1, "the bench still stands")
	r["pos"]["p1"] = AT
	r["w"]._last_pick.clear()
	assert_eq(r["w"].resolve("pick_up", { "id": id }, "p1"), "", "the owner within reach picks it up")
	assert_eq(st.get_all_stations().size(), 0, "it is gone")
	assert_eq(int(_inv(r, "p1").get_item_count("CarpentryBench")), 1, "and its item is back in the pack")
	r["w"]._last_pick.clear()
	assert_eq(r["w"].resolve("pick_up", { "id": id }, "p1"), "no_station", "a station that is gone cannot be picked up")
	var npc := st.place_station("forge", Vector3(40.5, 2.0, 40.5))
	r["pos"]["p1"] = Vector3(40.5, 2.0, 40.5)
	r["w"]._last_pick.clear()
	assert_eq(r["w"].resolve("pick_up", { "id": npc }, "p1"), "not_owner", "a station nobody owns (a village's) cannot be picked up")
	assert_eq(StationWiring.pickup_refusal({ "owner": "p1", "position": Vector3.ZERO }, "p1", null, 4.0), "far", "an unknown position fails closed")
	_free_rig(r)

func _test_persistence() -> void:
	var st := StationSlice.new()
	add_child(st)
	st.placing_owner = "p1"
	st.placing_rotation = 1
	var id := st.place_station("forge", Vector3(2.5, 1.0, 2.5))
	st.placing_owner = ""
	st.placing_rotation = 0
	var data := st.get_station_data()
	var wire := st.get_station_data(false)
	st.apply_station_data(data)
	assert_eq(str(st.get_station(id).get("owner", "")), "p1", "the owner survives a save and load")
	assert_eq(int(st.get_station(id).get("rotation", 0)), 1, "and the rotation")
	assert_false((wire[0] as Dictionary).has("owner"), "a client's copy carries no owner")
	assert_eq(int(wire[0]["rot"]), 1, "but carries the rotation")
	st.apply_station_data([{ "id": "station_9", "type": "forge", "position": [0, 0, 0], "rot": 99, "owner": 5 }])
	assert_eq(int(st.get_station("station_9").get("rotation", -1)), 3, "a wild rotation is folded into 0..3")
	assert_eq(str(st.get_station("station_9").get("owner", "")), "", "a non-string owner is dropped")
	st.apply_station_entry({ "id": "station_12", "type": "forge", "position": [1, 0, 1], "rot": 2 })
	assert_eq(str(st.get_station("station_12").get("type", "")), "forge", "a synced entry is added")
	st.drop_synced("station_12")
	assert_true(st.get_station("station_12").is_empty(), "and a synced removal drops it")
	st.free()

func _test_hotbar_kind() -> void:
	assert_eq(Hotbar.kind_of("Forge", GameData.MATERIALS, ""), Hotbar.KIND_STATION, "a station item is a station box")
	assert_eq(Hotbar.kind_of("Thornwood", GameData.MATERIALS, ""), Hotbar.KIND_BLOCK, "a material is still a block")
	var p := PlayerSlice.new()
	add_child(p)
	GameBus.hotbar_station_selected.emit("Forge")
	assert_eq(p._station_placer.item, "Forge", "selecting a station box arms the player")
	GameBus.hotbar_station_selected.emit("Thornwood")
	assert_eq(p._station_placer.item, "", "selecting anything else disarms it")
	p.free()

func _test_catalog() -> void:
	var cats: Dictionary = I18n.parse_csv("res://locale/ui.csv")["catalog"]
	var keys: Array = ["placing.ok.place", "placing.ok.pick_up", "hud.station_place"]
	for reason: String in StationWiring.REASONS:
		keys.append("placing.refused." + reason)
	for k: String in keys:
		for loc in cats:
			assert_true(str((cats[loc] as Dictionary).get(k, "")) != "", "%s has %s" % [loc, k])
