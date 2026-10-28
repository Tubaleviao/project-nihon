extends "res://src/tests/test_support.gd"
## Phase 181 — character creation at runtime: the host intent (every field refused with its own key, the
## name unique across offline players, the rate limit, the starting kit), the creation record on a pre-181 save
## (offered once, a skip recorded and the handle shown), the wire (the intent bound to the connection, a look
## answered only inside the AOI), the peers' avatars and nameplates, the creation screen built from the public
## tree with a placeholder for every skin and icon key, and the display name in chat and settlement lists.

const CreationRules := preload("res://src/character/creation_rules.gd")
const CreationScreen := preload("res://src/ui/creation_screen.gd")

const VALID := { "name": "Akira", "gender": "feminine", "hair": "hair_f_bob", "hairColor": 129 }


func register() -> void:
	_run_test("creation runtime: the host accepts a valid creation and refuses each invalid field with its own key", _test_fields_refused)
	_run_test("creation runtime: a duplicate name is refused across offline players, the index survives the world record", _test_names_unique)
	_run_test("creation runtime: creation is rate-limited, happens once, and a skipped player may still create", _test_rate_and_once)
	_run_test("creation runtime: a created character gets the starting kit, worn", _test_starting_kit)
	_run_test("creation runtime: a pre-181 save offers creation once and keeps inventory and skills; a skip shows the handle", _test_legacy_save)
	_run_test("creation runtime: the intent is bound to the connection, and a look is answered only inside the AOI", _test_wire)
	_run_test("creation runtime: a peer's look dresses its avatar and names it, whichever arrives first", _test_peer_look)
	_run_test("creation runtime: every skin and icon key has a public placeholder at its size, and no orphan exists", _test_skin_placeholders)
	_run_test("creation runtime: the screen builds from the public tree and sends what the player chose", _test_screen)
	_run_test("creation runtime: the UI holds the body while the screen is up and the sheet offers it until created", _test_ui_flow)
	_run_test("creation runtime: chat and settlement lists show the display name, the friend code stays the handle", _test_display_names)
	_run_test("creation runtime: every new string is in both catalogs", _test_catalog)


func _reg() -> PlayerRegistry:
	var reg := PlayerRegistry.new()
	reg.is_authoritative = true
	return reg


func _created(reg: PlayerRegistry, c: Dictionary, now: int) -> Array:
	var pid := reg.mint_player_id()
	reg.ensure_player(pid)
	return [pid, reg.create_character(pid, c, now)]


func _test_fields_refused() -> void:
	var reg := _reg()
	var pid := reg.mint_player_id()
	reg.ensure_player(pid)
	var now := 0
	var cases := [
		["name", "Al", "name_length"], ["name", "R2D2", "name_chars"], ["name", "Аlice", "name_script"],
		["name", "Admin", "name_reserved"], ["gender", "neuter", "gender"], ["hair", "hair_x", "hair"],
		["hair", "hair_m_crop", "hair_gender"], ["hairColor", 0, "hair_color"],
	]
	for case in cases:
		var c := VALID.duplicate()
		c[case[0]] = case[1]
		now += 1000
		var reason := reg.create_character(pid, c, now)
		assert_eq(reason, str(case[2]), "%s = %s is refused as %s" % [case[0], str(case[1]), case[2]])
		assert_true(I18nScript.has_key(CreationRules.refusal_key(reason)), "and %s has a catalog line" % reason)
		assert_true(CreationRules.should_offer(reg.creation_of(pid)), "a refusal records nothing")
	now += 1000
	assert_eq(reg.create_character(pid, VALID, now), "", "the valid creation is accepted")
	var state := reg.creation_of(pid)
	assert_true(CreationRules.is_created(state), "and recorded")
	assert_eq(reg.display_name(pid), "Akira", "the display name is the created one")
	assert_eq(reg.look_of(pid), { "name": "Akira", "gender": "feminine", "hair": "hair_f_bob", "hairColor": 129 }, "the look peers get")
	var round := _reg()
	round.apply_player_data(pid, reg.get_player_data(pid))
	assert_eq(round.creation_of(pid), state, "the creation survives a save")
	assert_eq(round.display_name(pid), "Akira", "with its name")
	round.free()
	reg.free()


func _test_names_unique() -> void:
	var reg := _reg()
	var first: Array = _created(reg, VALID, 1000)
	assert_eq(first[1], "", "the first Akira is created")
	var c := VALID.duplicate()
	for dup in ["akira", "AKIRA", "Ákira", "Аkirа"]:
		c["name"] = dup
		var other: Array = _created(reg, c, 5000)
		assert_true(str(other[1]) == "name_taken" or str(other[1]) == "name_script", "%s is refused (%s)" % [dup, other[1]])
	# The index rides the world record: after a restart the first player is offline (no record resident), and
	# its name is still taken and still shown for it.
	var world := reg.names_to_data()
	var reg2 := _reg()
	reg2.names_from_data(world)
	assert_false(reg2.has_player(str(first[0])), "the first player's record is not resident")
	c["name"] = "akira"
	assert_eq(_created(reg2, c, 1000)[1], "name_taken", "an offline player's name is still taken")
	assert_eq(reg2.display_name(str(first[0])), "Akira", "and still shows for them")
	reg2.names_from_data({ "not-an-id": "Bob", reg2.mint_player_id(): "B0b" })
	assert_eq(reg2.names_to_data().size(), 0, "a bad key or a name that breaks the rule is dropped")
	reg2.free()
	reg.free()


func _test_rate_and_once() -> void:
	var reg := _reg()
	var pid := reg.mint_player_id()
	reg.ensure_player(pid)
	var bad := VALID.duplicate()
	bad["name"] = "X"
	assert_eq(reg.create_character(pid, bad, 1000), "name_length", "a first try is read")
	assert_eq(reg.create_character(pid, VALID, 1000 + CreationRules.RATE_LIMIT_MSEC - 1), "rate_limited", "a try inside the interval is refused")
	assert_eq(reg.creation_rate_limited, 1, "and counted")
	assert_true(CreationRules.should_offer(reg.creation_of(pid)), "nothing was recorded")
	assert_eq(reg.skip_creation(pid, 3000), "", "a skip is recorded")
	assert_eq(str(reg.creation_of(pid)["state"]), CreationRules.STATE_SKIPPED, "as skipped")
	assert_false(CreationRules.should_offer(reg.creation_of(pid)), "and not offered again")
	assert_eq(reg.display_name(pid), reg.public_handle(pid), "a skipped player is shown by the handle")
	assert_eq(reg.create_character(pid, VALID, 5000), "", "a skipped player may still create from the sheet")
	assert_eq(reg.create_character(pid, VALID, 7000), "already_created", "but only once")
	assert_eq(reg.skip_creation(pid, 9000), "already_created", "and cannot skip back")
	reg.is_authoritative = false
	assert_eq(reg.create_character(pid, VALID, 11000), "not_host", "a client registry creates nothing")
	reg.free()


func _test_starting_kit() -> void:
	var reg := _reg()
	var made: Array = _created(reg, VALID, 1000)
	var pid := str(made[0])
	for k in CreationRules.starting_kit():
		assert_true(reg.get_inventory(pid).get_item_count(str(k["item"])) >= int(k["quantity"]), "the bag holds %s" % k["item"])
		if bool(k.get("equip", false)):
			var slot := EquipmentRules.slot_of(str(k["item"]), GameData.ITEMS)
			assert_eq(reg.get_equipment(pid).get(slot, ""), str(k["item"]), "and %s is worn" % k["item"])
	reg.free()


## A bare GameRoot with a registry, a character slice, a body and a UI: enough for the creation wiring.
func _root_rig(is_client: bool) -> Dictionary:
	var gr: Node = (load("res://src/core/game_root.gd") as GDScript).new()
	gr._is_client = is_client
	gr._registry = _reg()
	gr._registry.is_authoritative = not is_client
	gr._character = CharacterSlice.new()
	add_child(gr._character)
	gr._player = PlayerSlice.new()
	gr._networking = NetworkingSlice.new()
	add_child(gr._networking)
	var ui := UiSlice.new()
	ui.character_slice = gr._character
	ui.player_slice = gr._player
	add_child(ui)
	gr._ui = ui
	gr._creation_wiring.wire(gr)
	return { "gr": gr, "ui": ui }


func _free_rig(rig: Dictionary) -> void:
	var gr: Node = rig["gr"]
	gr._creation_wiring.unwire()
	rig["ui"].free()
	gr._networking.free()
	gr._player.free()
	gr._character.free()
	gr._registry.free()
	gr.free()


func _test_legacy_save() -> void:
	var rig := _root_rig(false)
	var gr: Node = rig["gr"]
	var reg: PlayerRegistry = gr._registry
	var pid := reg.mint_player_id()
	# A pre-181 payload: no creation key at all.
	reg.apply_player_data(pid, { "player_id": pid, "position": [1.0, 2.0, 3.0], "hp": 80.0,
		"skills": { "Smithing": "journeyman" }, "inventory": { "Ferrite": 3 } })
	reg.set_local_player(pid)
	assert_true(CreationRules.should_offer(reg.creation_of(pid)), "a pre-181 record offers creation")
	assert_eq(reg.get_inventory(pid).get_item_count("Ferrite"), 3, "its inventory is kept")
	assert_eq(reg.get_skill_tier(pid, "Smithing"), "journeyman", "and its skills")
	assert_true(gr._creation_wiring.maybe_offer(), "the screen is offered")
	assert_true(rig["ui"].is_creation_open(), "and shown")
	assert_true(gr._player.creation_hold, "the body takes no keys while it is up")
	assert_false(gr._player.world_input_allowed(), "and no world action resolves")
	assert_false(gr._creation_wiring.maybe_offer(), "once per session")
	GameBus.character_creation_intent.emit("skip", {}, "")
	assert_false(rig["ui"].is_creation_open(), "a skip closes it")
	assert_false(gr._player.creation_hold, "and frees the body")
	assert_eq(str(reg.creation_of(pid)["state"]), CreationRules.STATE_SKIPPED, "the skip is recorded")
	assert_eq(reg.get_inventory(pid).get_item_count("Ferrite"), 3, "progress is untouched")
	# The next join reads the saved record: not offered again.
	var saved := reg.get_player_data(pid)
	var reg2 := _reg()
	reg2.apply_player_data(pid, saved)
	assert_false(CreationRules.should_offer(reg2.creation_of(pid)), "a recorded skip is not offered on the next join")
	var look := reg2.look_of(pid)
	assert_eq(look, { "name": reg2.public_handle(pid) }, "its look is the handle and the default body")
	var ch: CharacterSlice = gr._character
	var iid := ch.create_character("TravellerHuman", Vector3.ZERO)
	ch.bind_peer_character(5, iid)
	ch.set_peer_look(5, look)
	assert_eq(ch.get_nameplate(ch.get_peer_character(5)), reg2.public_handle(pid), "the nameplate shows the handle")
	reg2.free()
	_free_rig(rig)


func _test_wire() -> void:
	var reg := _reg()
	var pid := reg.resolve_identity(4, "")
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.player_registry = reg
	n.set_player_id(4, pid)
	var wire := MemoryTransport.new([4, 6])
	n.set_transport(wire)
	var seen: Array = []
	var on_intent := func(action: String, c: Dictionary, who: String) -> void: seen.append([action, c, who])
	GameBus.character_creation_intent.connect(on_intent)
	n._route_c2h(4, { "type": "creation_intent", "action": "create", "name": "Akira" + "x".repeat(200), "gender": "feminine",
		"hair": "hair_f_bob", "hairColor": 129, "player_id": "someone_else" })
	assert_eq(seen.size(), 1, "a bound peer's creation is routed")
	assert_eq(str(seen[0][2]), pid, "for the connection's own player, never a payload name")
	assert_eq(str(seen[0][1]["name"]).length(), CreationRules.MAX_FIELD_LEN, "a long field is capped")
	n._route_c2h(9, { "type": "creation_intent", "action": "create", "name": "Akira" })
	n._route_c2h(4, { "type": "creation_intent", "action": "delete_everyone" })
	assert_eq(seen.size(), 1, "an unbound peer and an unknown action are dropped")
	GameBus.character_creation_intent.disconnect(on_intent)
	# A look is answered only for a subject inside the requester's AOI.
	var other := reg.resolve_identity(6, "")
	n.set_player_id(6, other)
	n.remember_player_state(4, Vector3(0, 10, 0))
	n.remember_player_state(6, Vector3(10, 10, 0))
	wire.outbox.clear()
	assert_true(n.answer_look_request(4, 6), "a peer in range is answered")
	assert_eq(str(wire.outbox[0]["payload"]["type"]), "peer_look", "with its look")
	assert_eq(int(wire.outbox[0]["payload"]["peer_id"]), 6, "named by its peer id")
	assert_false(str(wire.outbox[0]["payload"]).contains(other), "never by its player id")
	n.remember_player_state(6, Vector3(NetworkingSlice.AOI_RADIUS * 3.0, 10, 0))
	assert_false(n.answer_look_request(4, 6), "a peer out of range is not")
	assert_false(n.answer_look_request(4, 77), "nor an unknown one")
	assert_eq(n.look_requests_refused, 2, "both counted")
	# The client keeps only choices that pass the rules.
	var clean := CreationRules.sanitize_look({ "name": "Zed", "gender": "feminine", "hair": "hair_m_crop", "hairColor": 129 })
	assert_eq(clean, { "name": "Zed" }, "a look with a bad hair keeps the name and the default body")
	n.free()
	reg.free()


func _test_peer_look() -> void:
	var ch := CharacterSlice.new()
	add_child(ch)
	var look := { "name": "Akira", "gender": "feminine", "hair": "hair_f_bob", "hairColor": 129 }
	# Look first, avatar later.
	ch.set_peer_look(3, look)
	var iid := ch.create_character("TravellerHuman", Vector3.ZERO)
	ch.bind_peer_character(3, iid)
	var app := ch.get_appearance(iid)
	assert_eq(int(app["hairColor"]), 129, "the avatar wears the chosen colour")
	assert_eq(str(app["hair"]), "hair_f_bob", "and hair")
	assert_eq(str(app["body"]), str(CreationRules.preset("feminine").get("body")), "on the gender's body preset")
	assert_eq(ch.get_nameplate(iid), "Akira", "named above its head")
	# Avatar first, look later; gear is kept across the rebuild.
	var iid2 := ch.create_character("TravellerHuman", Vector3.ZERO)
	ch.bind_peer_character(8, iid2)
	ch.apply_equipment(iid2, "Chest", "NoviceTunic")
	ch.set_peer_look(8, { "name": "Renée", "gender": "masculine", "hair": "hair_m_spiky", "hairColor": 41 })
	assert_eq(str(ch.get_appearance(iid2)["hair"]), "hair_m_spiky", "an existing avatar is redressed")
	assert_eq(ch.get_equipment_set(iid2).get("Chest", ""), "NoviceTunic", "keeping what it wears")
	assert_eq(ch.get_nameplate(iid2), "Renée", "and named")
	ch.forget_peer(8)
	assert_true(ch.get_peer_look(8).is_empty(), "a peer that left is forgotten")
	ch.free()


func _test_skin_placeholders() -> void:
	for sid in CreationScreen.SKIN:
		var key: String = str(CreationScreen.SKIN[sid]["key"])
		var path := AssetOverlay.resolve_path(key)
		assert_true(FileAccess.file_exists("res://assets/" + key), "%s has a public placeholder" % key)
		assert_true(AssetOverlay.has_key("textures", key), "%s is in the manifest" % key)
		var img := Image.new()
		assert_eq(img.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/" + key)), OK, "%s decodes" % key)
		assert_eq(img.get_size(), CreationScreen.SKIN[sid]["size"] as Vector2i, "%s is at its final size" % key)
		assert_true(path != "", "and resolves")
	var icon_keys := CreationScreen.icon_keys()
	for key in icon_keys:
		assert_true(FileAccess.file_exists("res://assets/" + str(key)), "%s has a public placeholder" % key)
	var skin_keys := CreationScreen.skin_keys()
	for dir in ["textures/ui/creation", "icons/ui/creation"]:
		for file in DirAccess.get_files_at("res://assets/" + dir):
			if file.ends_with(".import"):
				continue
			var key: String = dir + "/" + file
			assert_true(skin_keys.has(key) or icon_keys.has(key), "%s is read by the screen (no orphan)" % key)


func _test_screen() -> void:
	var screen := CreationScreen.new()
	var ch := CharacterSlice.new()
	add_child(ch)
	screen.visual_builder = func(c: Dictionary) -> Node3D:
		return ch._make_visual("creation_doll", ch.deserialize_appearance(ch.creation_recipe(c)))["root"]
	screen.palette = ch.palette_color
	add_child(screen)
	assert_true(screen.has_rig(), "the doll holds a rig built only from the public tree")
	var gs := CreationRules.genders()
	assert_true(screen.find_child("Gender_" + str(gs[0]), true, false).get_index() < screen.find_child("Gender_" + str(gs[1]), true, false).get_index() - 1, "a toggle on either side of the rig")
	for gender in CreationRules.genders():
		screen.set_gender(str(gender))
		assert_eq(screen.find_children("Hair_*", "Button", true, false).size(), CreationRules.hair_options(str(gender)).size(), "%s: a cell per hair style" % gender)
		assert_eq(CreationRules.choice_refusal(screen.choice), "", "%s: switching keeps a valid choice" % gender)
	for s in range(20):
		assert_eq(CreationRules.choice_refusal(screen.randomize_choice(s)), "", "randomize %d picks a valid look" % s)
	assert_eq(screen.randomize_choice(7), screen.randomize_choice(7), "a seeded randomize repeats")
	var sent: Array = []
	var on_intent := func(action: String, c: Dictionary, who: String) -> void: sent.append([action, c, who])
	GameBus.character_creation_intent.connect(on_intent)
	screen.set_name_text("A")
	screen.submit()
	assert_eq(sent.size(), 0, "a name the rule refuses is not sent")
	assert_eq(screen.error_text(), I18nScript.t("creation.refuse.name_length"), "the reason shows in this locale")
	screen.set_name_text("Hikari")
	screen.submit()
	assert_eq(sent.size(), 1, "a valid creation is sent")
	assert_eq(str(sent[0][0]), "create", "as a create")
	assert_eq(str(sent[0][1]["name"]), "Hikari", "with the typed name")
	assert_eq(str(sent[0][2]), "", "for this machine's own player")
	screen.show_refusal("name_taken")
	assert_eq(screen.error_text(), I18nScript.t("creation.refuse.name_taken"), "the host's refusal is rendered here")
	screen.skip()
	assert_eq(str(sent[1][0]), "skip", "skip sends a skip")
	GameBus.character_creation_intent.disconnect(on_intent)
	screen.free()
	ch.free()


func _test_ui_flow() -> void:
	var rig := _root_rig(false)
	var gr: Node = rig["gr"]
	var ui: Node = rig["ui"]
	var reg: PlayerRegistry = gr._registry
	var pid := reg.mint_player_id()
	reg.set_local_player(pid)
	var avatar: String = gr._character.create_character("TravellerHuman", Vector3.ZERO)
	gr._character.set_player_character(avatar)
	ui.set_own_handle(reg.public_handle(pid))
	ui.set_creation_state(reg.creation_of(pid))
	ui.refresh_character()
	assert_true(ui._sheet_create_button.visible, "the sheet offers creation while there is none")
	assert_eq(ui._sheet_name.text, reg.public_handle(pid), "and names the player by the handle")
	ui.show_creation()
	var c := VALID.duplicate()
	c["name"] = "Al"
	GameBus.character_creation_intent.emit("create", c, "")
	assert_true(ui.is_creation_open(), "a refusal keeps the screen up")
	assert_eq(ui.creation_screen.error_text(), I18nScript.t("creation.refuse.name_length"), "and shows the reason")
	reg._creation_tries.clear()
	GameBus.character_creation_intent.emit("create", VALID, "")
	assert_false(ui.is_creation_open(), "a creation closes it")
	assert_eq(str(gr._character.get_appearance(avatar)["hair"]), "hair_f_bob", "the local avatar wears the look")
	ui.refresh_character()
	assert_false(ui._sheet_create_button.visible, "the sheet no longer offers it")
	assert_eq(ui._sheet_name.text, "Akira", "and shows the created name")
	_free_rig(rig)


func _test_display_names() -> void:
	var reg := _reg()
	var made: Array = _created(reg, VALID, 1000)
	var pid := str(made[0])
	var chat := ChatSlice.new()
	chat.player_registry = reg
	assert_eq(chat._name_of(pid), "Akira", "chat names a created player by the name")
	assert_eq(chat._handle_of(pid), reg.public_handle(pid), "the handle (friend code) is unchanged")
	var skipper := reg.mint_player_id()
	reg.ensure_player(skipper)
	assert_eq(chat._name_of(skipper), reg.public_handle(skipper), "and anyone else by the handle")
	chat.free()
	var SettlementSliceScript: GDScript = load("res://src/settlement/settlement_slice.gd")
	var st: Node = SettlementSliceScript.new()
	st.registry = reg
	var names: Dictionary = st._member_names({ "members": { pid: "founder", skipper: "member" } })
	assert_eq(str(names[pid]), "Akira", "a settlement lists a member by the name")
	assert_eq(str(names[skipper]), reg.public_handle(skipper), "or the handle")
	st.free()
	reg.free()


func _test_catalog() -> void:
	var cats: Dictionary = I18nScript.parse_csv("res://locale/ui.csv")["catalog"]
	var keys := ["creation.title", "creation.hair", "creation.hair_color", "creation.randomize", "creation.skip",
		"creation.name", "creation.enter", "creation.open", "creation.welcome",
		"creation.refuse.rate_limited", "creation.refuse.already_created"]
	for loc in ["en", "pt_BR"]:
		for k in keys:
			assert_true(str((cats.get(loc, {}) as Dictionary).get(k, "")).strip_edges() != "", "%s has %s" % [loc, k])
