extends "res://src/tests/test_support.gd"
## Phase 280 — the hotbar item in the hand: the mesh at `socket_weapon_r`, and the host's checks on a held-item message.

const HeldItem := preload("res://src/character/held_item.gd")
const RigTree := preload("res://src/character/rig_tree.gd")
const Hotbar := preload("res://src/ui/hotbar.gd")

const MAIN := "VeilsteelLongsword"
const TOOL := "StonePick"


func register() -> void:
	_run_test("held item: a hotbar item attaches its mesh under socket_weapon_r and a missing model is a box", _test_attach_and_fallback)
	_run_test("held item: an empty slot restores the main-hand mesh and switching frees the old mesh", _test_restore_and_free)
	_run_test("held item: a grip on the model offsets the mesh", _test_grip)
	_run_test("held item: a main hand worn or cleared under a held item keeps one mesh in the hand", _test_equip_under_held)
	_run_test("held item: the swing reads the held item", _test_attack_clip)
	_run_test("held item: the host refuses an item not in the pack, an unknown id and a skill entry", _test_host_refusals)
	_run_test("held item: changes over the rate limit are dropped", _test_rate_limit)
	_run_test("held item: using up the held item syncs empty", _test_pack_empties)
	_run_test("held item: the hotbar selection is the held item and a skill box holds nothing", _test_hotbar_emits)


func _char_fixture() -> Dictionary:
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid := ch.create_character_from_recipe({"skeleton": "HumanoidSkeleton"}, Vector3.ZERO)
	assert_true(ch.attach_rig(iid, "models/player_rig.glb.raw"), "the player rig attaches")
	ch.set_player_character(iid)
	return {"ch": ch, "iid": iid}


func _test_attach_and_fallback() -> void:
	var f := _char_fixture()
	var ch: CharacterSlice = f["ch"]
	var iid: String = f["iid"]
	assert_true(ch.set_held_item(iid, TOOL), "an item is held")
	var node := ch.held_node_of(iid)
	assert_true(node != null, "the held mesh exists")
	assert_eq(str(node.get_meta("socket", "")), "socket_weapon_r", "the held mesh sits at the right-hand weapon socket")
	assert_eq(ch.held_item_of(iid), TOOL, "the held id is kept")
	assert_true(ch.set_held_item(iid, "NoSuchItemForHeldTest"), "an item with no model is held")
	var box := ch.held_node_of(iid)
	assert_true(box != null and (box as MeshInstance3D).mesh is BoxMesh, "a missing model key gives the box fallback")
	assert_false(ch.set_held_item("nobody", TOOL), "an unknown instance holds nothing")
	CharacterSlice._item_models.erase("NoSuchItemForHeldTest")
	ch.free()


func _test_restore_and_free() -> void:
	var f := _char_fixture()
	var ch: CharacterSlice = f["ch"]
	var iid: String = f["iid"]
	assert_true(ch.apply_equipment(iid, "MainHand", MAIN), "a main hand is worn")
	var main_node: Node3D = ch.get_part_node(iid, "MainHand")
	main_node.visible = true   # a rig keeps worn parts hidden; this test shows it by hand
	ch.set_held_item(iid, TOOL)
	assert_false(main_node.visible, "a held item replaces the worn main-hand mesh")
	var first := ch.held_node_of(iid)
	ch.set_held_item(iid, "Torch")
	assert_false(is_instance_valid(first), "switching frees the old mesh")
	ch.set_held_item(iid, MAIN)
	assert_true(ch.held_node_of(iid) == null, "holding the worn main hand adds no second mesh")
	assert_true(main_node.visible, "the worn main hand shows when it is what is held")
	ch.set_held_item(iid, TOOL)
	var held := ch.held_node_of(iid)
	ch.set_held_item(iid, "")
	assert_false(is_instance_valid(held), "an empty slot frees the held mesh")
	assert_true(main_node.visible, "an empty slot restores the main-hand mesh")
	assert_eq(ch.held_item_of(iid), "", "nothing is held")
	ch.free()


func _test_equip_under_held() -> void:
	var f := _char_fixture()
	var ch: CharacterSlice = f["ch"]
	var iid: String = f["iid"]
	ch.set_held_item(iid, TOOL)
	assert_true(ch.apply_equipment(iid, "MainHand", MAIN), "a main hand is worn after the item is held")
	var worn: Node3D = ch.get_part_node(iid, "MainHand")
	assert_false(worn.visible, "the newly worn main hand stays hidden while another item is held")
	assert_true(ch.held_node_of(iid) != null, "the held mesh is still in the hand")
	ch.clear_equipment(iid, "MainHand")
	assert_true(ch.held_node_of(iid) != null, "clearing the main hand keeps the held mesh")
	ch.free()

func _test_grip() -> void:
	var f := _char_fixture()
	var ch: CharacterSlice = f["ch"]
	var iid: String = f["iid"]
	var plain := BoxMesh.new()
	CharacterSlice._item_models["HeldGripPlain"] = plain
	var gripped := BoxMesh.new()
	gripped.set_meta("grip_pos", Vector3(0.0, 0.0, 0.2))
	gripped.set_meta("grip_rot", Vector3(0.0, 90.0, 0.0))
	CharacterSlice._item_models["HeldGripped"] = gripped
	ch.set_held_item(iid, "HeldGripPlain")
	var base: Vector3 = ch.held_node_of(iid).position
	ch.set_held_item(iid, "HeldGripped")
	var node := ch.held_node_of(iid)
	assert_true(node.position.distance_to(base + Vector3(0.0, 0.0, -0.2)) < 0.0001, "the grip point goes to the hand")
	assert_true(absf(node.rotation_degrees.y - 90.0) < 0.01, "the grip rotation applies")
	CharacterSlice._item_models.erase("HeldGripPlain")
	CharacterSlice._item_models.erase("HeldGripped")
	ch.free()


func _test_attack_clip() -> void:
	var f := _char_fixture()
	var ch: CharacterSlice = f["ch"]
	var iid: String = f["iid"]
	assert_eq(ch.attack_clip_of(iid), RigTree.ATTACK_UNARMED, "bare hands punch")
	ch.set_held_item(iid, TOOL)
	assert_eq(ch.attack_clip_of(iid), RigTree.ATTACK_TOOL, "a pick held from the hotbar swings as a tool")
	ch.set_held_item(iid, "")
	assert_eq(ch.attack_clip_of(iid), RigTree.ATTACK_UNARMED, "an empty hand punches again")
	ch.free()


func _host_fixture() -> Dictionary:
	var gr: Node = (load("res://src/core/game_root.gd") as GDScript).new()
	gr._registry = PlayerRegistry.new()
	gr._registry.local_player_id = "p1"
	var inv := InventorySlice.new()
	gr._inventory = inv
	gr._registry.set_inventory("p1", inv)
	gr._held_item_wiring.wire(gr)
	var seen: Array = []
	var cb := func(pid: String, item: String) -> void: seen.append([pid, item])
	GameBus.held_item_synced.connect(cb)
	return {"gr": gr, "inv": inv, "seen": seen, "cb": cb}


func _free_host(f: Dictionary) -> void:
	GameBus.held_item_synced.disconnect(f["cb"])
	f["gr"]._held_item_wiring.unwire()
	f["inv"].free()
	f["gr"]._registry.free()
	f["gr"].free()


func _test_host_refusals() -> void:
	var f := _host_fixture()
	var gr: Node = f["gr"]
	var seen: Array = f["seen"]
	GameBus.held_item_intent.emit(TOOL, "p1")
	assert_true(seen.is_empty(), "an item the player does not have is refused and syncs nothing")
	f["inv"].add_item(TOOL, 1)
	GameBus.held_item_intent.emit("NoSuchItemAtAll", "p1")
	assert_true(seen.is_empty(), "an unknown id is refused")
	GameBus.held_item_intent.emit("skill:Mining", "p1")
	assert_true(seen.is_empty(), "a skill entry is refused")
	GameBus.held_item_intent.emit(TOOL, "p1")
	assert_eq(seen, [["p1", TOOL]], "an item the player has is held and synced")
	GameBus.held_item_intent.emit("", "p1")
	assert_eq(str(seen[-1][1]), "", "empty hands sync empty")
	_free_host(f)


func _test_rate_limit() -> void:
	var f := _host_fixture()
	f["inv"].add_item(TOOL, 1)
	f["inv"].add_item(MAIN, 1)
	for i in 20:
		GameBus.held_item_intent.emit(TOOL if i % 2 == 0 else MAIN, "p1")
	assert_eq((f["seen"] as Array).size(), HeldItem.RATE_LIMIT, "changes over the limit are dropped")
	var stamps: Array = []
	for i in HeldItem.RATE_LIMIT:
		stamps = HeldItem.admit(stamps, 1000 + i)
	assert_true(HeldItem.admit(stamps, 1500).is_empty(), "the pure limit refuses inside the window")
	assert_false(HeldItem.admit(stamps, 1000 + HeldItem.RATE_WINDOW_MS + HeldItem.RATE_LIMIT).is_empty(), "and admits after it")
	_free_host(f)


func _test_pack_empties() -> void:
	var f := _host_fixture()
	f["inv"].add_item(TOOL, 1)
	GameBus.held_item_intent.emit(TOOL, "p1")
	assert_eq(f["gr"]._held_item_wiring._held.get("p1", ""), TOOL, "held")
	f["inv"].consume_items({TOOL: 1})
	GameBus.inventory_changed.emit()
	assert_eq(str((f["seen"] as Array)[-1][1]), "", "using up the last one syncs empty")
	assert_false(f["gr"]._held_item_wiring._held.has("p1"), "and the host forgets it")
	# a peer's pack: the sync of its contents clears too
	f["inv"].add_item(TOOL, 1)
	GameBus.held_item_intent.emit(TOOL, "p1")
	GameBus.inventory_synced.emit("p1", {}, {})
	assert_eq(str((f["seen"] as Array)[-1][1]), "", "a pack sync without the item syncs empty")
	_free_host(f)


func _test_hotbar_emits() -> void:
	var seen: Array = []
	var cb := func(item: String, _pid: String) -> void: seen.append(item)
	GameBus.held_item_intent.connect(cb)
	var hb := Hotbar.new()
	hb.slots = ["Thornwood", "skill:Mining", "", "", "", "", "", "", "", ""]
	hb.select_slot(0)
	hb.select_slot(1)
	hb.select_slot(2)
	GameBus.held_item_intent.disconnect(cb)
	assert_eq(seen, ["Thornwood", "", ""], "a block is held, a skill box and an empty box hold nothing")
	hb.free()
