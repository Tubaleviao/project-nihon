extends "res://src/tests/test_support.gd"
## Phase 181 — character creation at runtime: the host intent (every field refused with its own key, the
## name unique across offline players, the rate limit, the starting kit), the creation record on a pre-181 save
## (offered once, a skip recorded and the handle shown), the wire (the intent bound to the connection, a look
## answered only inside the AOI), the peers' avatars and nameplates, the creation screen built from the public
## tree with a placeholder for every skin and icon key, and the display name in chat and settlement lists.

const CreationRules := preload("res://src/character/creation_rules.gd")
const AvatarBuilder := preload("res://src/character/avatar_builder.gd")
const CreationScreen := preload("res://src/ui/creation_screen.gd")

const VALID := { "name": "Akira", "gender": "feminine", "hair": "hair_f_bob", "hairColor": 129 }


func register() -> void:
	_run_test("creation runtime: the host accepts a valid creation and refuses each invalid field with its own key", _test_fields_refused)
	_run_test("creation runtime: a duplicate name is refused across offline players, the index survives the world record", _test_names_unique)
	_run_test("creation runtime: creation is rate-limited, happens once, and a skipped player may still create", _test_rate_and_once)
	_run_test("creation runtime: a new character's bag and equipment are empty (Phase 262)", _test_starting_kit)
	_run_test("creation runtime: a pre-181 save offers creation once and keeps inventory and skills; a skip shows the handle", _test_legacy_save)
	_run_test("creation runtime: the intent is bound to the connection, and a look is answered only inside the AOI", _test_wire)
	_run_test("creation runtime: a peer's look dresses its avatar and names it, whichever arrives first", _test_peer_look)
	_run_test("creation runtime: the world avatar, the creation rig and the doll are one body (Phase 265)", _test_one_body)
	_run_test("creation runtime: every hair style loads its own mesh on the head socket and a change swaps it (Phase 265)", _test_hair_meshes)
	_run_test("creation runtime: every hair key has a public placeholder (Phase 265)", _test_hair_placeholders)
	_run_test("creation runtime: hair and head anchors coincide and the scalp gap stays within 1 cm, also at head scale 1.2 (Phase 284)", _test_hair_anchors_and_scalp_gap)
	_run_test("creation runtime: a male and a female character attach their own body and head, the male's shoulder/hip ratio 15% above (Phase 286)", _test_body_types_differ)
	_run_test("creation runtime: hair is fitted by its anchors, and a rig without one keeps the old placement (Phase 284)", _test_hair_fit_and_fallback)
	_run_test("creation runtime: a new look with another body type swaps the attached body rig (Phase 286)", _test_look_change_swaps_body)
	_run_test("creation runtime: every skin and icon key has a public placeholder at its size, and no orphan exists", _test_skin_placeholders)
	_run_test("creation runtime: the screen builds from the public tree and sends what the player chose", _test_screen)
	_run_test("creation runtime: the UI holds the body while the screen is up and the sheet offers it until created", _test_ui_flow)
	_run_test("creation runtime: the sheet's create button follows the host's state and hides once created (Phase 221)", _test_button_follows_host)
	_run_test("creation runtime: a screen opened from the sheet closes with Back and Esc, also after already_created (Phase 221)", _test_back_closes)
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
	assert_eq(reg.look_of(pid), { "name": "Akira", "gender": "feminine", "hair": "hair_f_bob", "hairColor": 129, "title": "Newcomer" }, "the look peers get")
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
	assert_eq(CreationRules.starting_kit(), [], "the fabric's starting kit is empty")
	var reg := _reg()
	var made: Array = _created(reg, VALID, 1000)
	var pid := str(made[0])
	assert_eq(str(made[1]), "", "the character is created")
	assert_true(reg.get_inventory(pid).get_contents().is_empty(), "the new character's bag is empty")
	var worn := 0
	for slot in reg.get_equipment(pid):
		if str(reg.get_equipment(pid)[slot]) != "":
			worn += 1
	assert_eq(worn, 0, "and nothing is worn")
	for g in ["masculine", "feminine"]:
		var preset: Resource = CreationRules.preset(g)
		assert_true((preset.get("equipment") as Dictionary).is_empty(), "the %s preset wears no item: its plain clothes are the body's" % g)
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
	assert_eq(look, { "name": reg2.public_handle(pid), "title": "Newcomer" }, "its look is the handle and the default body")
	var ch: CharacterSlice = gr._character
	var iid := ch.create_character("TravellerHuman", Vector3.ZERO)
	ch.bind_peer_character(5, iid)
	ch.set_peer_look(5, look)
	assert_eq(ch.get_nameplate(ch.get_peer_character(5)), reg2.public_handle(pid) + "\nNewcomer", "the nameplate shows the handle")
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


## Everything that makes a rig scene look the way it does: per mesh node its path, mesh shape and the palette
## indices and material parameters written on it.
func _rig_signature(rig_node: Node) -> Array:
	var out: Array = []
	for n in rig_node.find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		var params := []
		for k in ["base_index", "primary_index", "secondary_index", "accent_index", "metalness", "roughness"]:
			params.append(m.get_instance_shader_parameter(k))
		out.append([str(rig_node.get_path_to(m)), m.mesh.get_surface_count(), m.mesh.get_aabb(), params,
			m.material_override.shader if m.material_override is ShaderMaterial else null])
	out.sort_custom(func(a, b): return str(a[0]) < str(b[0]))
	return out


func _hair_mesh_of(rig_node: Node) -> MeshInstance3D:
	return AvatarBuilder.hair_node(rig_node)


func _test_one_body() -> void:
	var ch := CharacterSlice.new()
	add_child(ch)
	var look := { "name": "Akira", "gender": "feminine", "hair": "hair_f_braid", "hairColor": 129 }
	var recipe: Dictionary = ch.creation_recipe(look)
	recipe["equipment"] = { "main_hand": { "item": "stone_axe", "state": "equipped" } }
	var appearance: Dictionary = ch.deserialize_appearance(recipe)
	var iid: String = ch.create_character_from_recipe(recipe, Vector3.ZERO)
	assert_true(ch.attach_default_rig(iid), "the world avatar wears the default rig")
	var world: Node = ch._instances[iid]["rig_node"]
	var creation: Dictionary = ch.build_avatar("creation_doll", appearance)
	var doll: Dictionary = ch.build_avatar("sheet_doll", appearance)
	assert_true(creation.has("rig_node") and doll.has("rig_node"), "both views got the rig, not the procedural body")
	var want := _rig_signature(world)
	assert_true(want.size() > 0, "the world rig has meshes")
	assert_eq(_rig_signature(creation["rig_node"]), want, "the creation rig has the world's meshes, materials and hair")
	assert_eq(_rig_signature(doll["rig_node"]), want, "the doll has the world's meshes, materials and hair")
	var eq_world: Array = (ch._instances[iid]["equipment"] as Dictionary).keys()
	eq_world.sort()
	for built in [creation, doll]:
		var eq: Array = (built["equipment"] as Dictionary).keys()
		eq.sort()
		assert_eq(eq, eq_world, "the same worn set is attached")
	assert_true(((creation["rig_node"] as Node).find_child("AnimationPlayer", true, false) as AnimationPlayer).current_animation == "idle", "the creation rig plays the idle clip")
	for built in [creation, doll]:
		(built["root"] as Node).free()
	ch.free()
	# Without a rig in the manifest the procedural body is the fallback.
	var saved: Variant = AssetOverlay._manifest
	AssetOverlay._manifest = { "meshes": {}, "animations": {} }
	AssetOverlay._manifest_loaded = true
	var ch2 := CharacterSlice.new()
	add_child(ch2)
	var fb: Dictionary = ch2.build_avatar("x", ch2.deserialize_appearance(ch2.creation_recipe(look)))
	assert_false(fb.has("rig_node"), "no rig listed: the procedural body stays")
	(fb["root"] as Node).free()
	ch2.free()
	AssetOverlay.reload_manifest()


func _test_hair_meshes() -> void:
	var ch := CharacterSlice.new()
	add_child(ch)
	var styles: Dictionary = CreationRules.data().get("hairStyles")
	var seen: Dictionary = {}
	for id in styles:
		var gender := str((styles[id] as Dictionary).get("gender"))
		var app: Dictionary = ch.deserialize_appearance(ch.creation_recipe({ "gender": gender, "hair": id, "hairColor": 129 }))
		var built: Dictionary = ch.build_avatar("h", app)
		var hair := _hair_mesh_of(built["rig_node"])
		assert_true(hair != null, "%s: a hair mesh is on the rig" % id)
		if hair != null:
			assert_eq(hair.get_meta("hair_style"), id, "%s: its own style" % id)
			assert_true(hair.get_parent() is BoneAttachment3D and (hair.get_parent() as BoneAttachment3D).bone_name == "Head", "%s: on the head socket" % id)
			assert_eq(hair.get_instance_shader_parameter("base_index"), 129.0, "%s: tinted by the hair colour" % id)
			var sig := [hair.mesh.get_aabb(), hair.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()]
			assert_false(seen.has(str(sig)), "%s: a mesh no other style has" % id)
			seen[str(sig)] = id
		(built["root"] as Node).free()
	# A change of style on the creation screen replaces the hair mesh.
	var screen := CreationScreen.new()
	screen.visual_builder = func(c: Dictionary) -> Node3D:
		return ch.build_avatar("creation_doll", ch.deserialize_appearance(ch.creation_recipe(c)))["root"]
	screen.palette = ch.palette_color
	add_child(screen)
	screen.set_gender("feminine")
	var ids: Array = CreationRules.hair_options("feminine").map(func(o): return str(o["id"]) if o is Dictionary else str(o))
	screen.set_hair(ids[0])
	var first := _hair_mesh_of(screen._doll.pivot)
	var first_id: String = str(first.get_meta("hair_style")) if first != null else ""
	var had_first := first != null
	screen.set_hair(ids[1])
	var second := _hair_mesh_of(screen._doll.pivot)
	assert_true(had_first and second != null, "the doll shows hair for both styles")
	assert_eq(first_id, ids[0], "the first style's mesh")
	assert_eq(str(second.get_meta("hair_style")), ids[1], "a style change swaps the hair mesh")
	screen.free()
	ch.free()


func _test_hair_placeholders() -> void:
	var styles: Dictionary = CreationRules.data().get("hairStyles")
	for id in styles:
		var key := AvatarBuilder.hair_key(str(id))
		assert_true(key != "", "%s: its mesh key is in the manifest" % id)
		assert_true(FileAccess.file_exists("res://assets/" + AvatarBuilder.HAIR_KEY_FORMAT % id), "%s has a public placeholder" % id)
	assert_eq(AvatarBuilder.hair_key("none"), "", "no style, no key")


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


## Phase 221 — a client's sheet shows the button only as the host's synced state implies, and a listen host whose
## handle the boot set first still learns its own record (the divergence found in play).
func _test_button_follows_host() -> void:
	var host := _reg()
	var made: Array = _created(host, VALID, 1000)
	var host_pid := str(made[0])
	var rig := _root_rig(true)
	var gr: Node = rig["gr"]
	var ui: Node = rig["ui"]
	gr._creation_wiring.sync_ui()
	ui.refresh_character()
	assert_false(ui._sheet_create_button.visible, "a client offers nothing before the host said its state")
	gr._creation_wiring.apply_own({ "creation": { "state": CreationRules.STATE_SKIPPED } })
	ui.refresh_character()
	assert_true(ui._sheet_create_button.visible, "a skipped player is offered creation")
	gr._creation_wiring.apply_own({ "creation": host.creation_of(host_pid) })
	ui.refresh_character()
	assert_false(ui._sheet_create_button.visible, "a created character's sheet hides the button")
	assert_eq(ui._sheet_name.text, "Akira", "and names the character")
	_free_rig(rig)
	host.free()
	# A listen host: the boot sets the handle before the wiring ticks; the record already holds a character.
	rig = _root_rig(false)
	gr = rig["gr"]
	ui = rig["ui"]
	var reg: PlayerRegistry = gr._registry
	var pid := reg.mint_player_id()
	reg.set_local_player(pid)
	assert_eq(reg.create_character(pid, VALID, 1000), "", "the host's record holds a character")
	ui.set_own_handle(reg.public_handle(pid))
	gr._creation_wiring.tick(0.0)
	assert_true(ui._creation_known, "the tick tells the host's UI its own state")
	assert_true(CreationRules.is_created(ui._creation_state), "the created one its record holds")
	ui.refresh_character()
	assert_eq(ui._sheet_name.text, "Akira", "and the sheet names the character")
	assert_false(ui._sheet_create_button.visible, "the host's own sheet hides the button once its record is created")
	assert_false(gr._creation_wiring.sync_ui(), "and stays in step without re-rendering every frame")
	_free_rig(rig)


## Phase 221 — Back and Esc close a screen opened from the sheet and free the body; a host refusal keeps it usable
## with the reason, and `already_created` offers the way back even on the first-join offer.
func _test_back_closes() -> void:
	var rig := _root_rig(false)
	var gr: Node = rig["gr"]
	var ui: Node = rig["ui"]
	var reg: PlayerRegistry = gr._registry
	var pid := reg.mint_player_id()
	reg.set_local_player(pid)
	gr._creation_wiring.sync_ui()
	ui.refresh_character()
	ui._sheet_create_button.pressed.emit()
	assert_true(ui.is_creation_open(), "the sheet's button opens the screen")
	assert_true(gr._player.creation_hold, "and holds the body")
	var back: Button = ui.creation_screen.find_child("Back", true, false)
	assert_true(back != null and back.visible, "with a Back button")
	back.pressed.emit()
	assert_false(ui.is_creation_open(), "Back hides the screen")
	assert_false(gr._player.creation_hold, "and world input is unfrozen")
	ui._sheet_create_button.pressed.emit()
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	assert_true(ui.creation_screen.handle_key(esc), "Esc is taken")
	assert_false(ui.is_creation_open(), "and hides the screen")
	assert_false(gr._player.creation_hold, "and unfreezes world input")
	# The first-join offer has no Back: it is left by entering or skipping.
	ui.show_creation()
	assert_false(back.visible, "the first-join offer has no Back")
	assert_false(ui.creation_screen.handle_key(esc), "nor closes on Esc")
	# The host already holds a character this screen did not know about: it refuses, the screen stays usable.
	assert_eq(reg.create_character(pid, VALID, 1000), "", "the record gains a character elsewhere")
	reg._creation_tries.clear()
	var other := VALID.duplicate()
	other["name"] = "Hikari"
	GameBus.character_creation_intent.emit("create", other, "")
	assert_true(ui.is_creation_open(), "a host refusal keeps the screen up")
	assert_eq(ui.creation_screen.error_text(), I18nScript.t("creation.refuse.already_created"), "showing the reason")
	assert_true(back.visible, "with the way back")
	ui.refresh_character()
	assert_false(ui._sheet_create_button.visible, "the sheet follows the host's answer")
	assert_true(ui.creation_screen.handle_key(esc), "Esc closes it")
	assert_false(ui.is_creation_open(), "the screen is hidden")
	assert_false(gr._player.creation_hold, "and world input is unfrozen")
	# Opened from the sheet, the same refusal leaves Back working.
	ui.show_creation({}, true)
	reg._creation_tries.clear()
	GameBus.character_creation_intent.emit("create", other, "")
	assert_true(ui.is_creation_open(), "refused from the sheet, the screen stays up")
	assert_true(back.visible, "with Back visible before it is pressed")
	back.pressed.emit()
	assert_false(ui.is_creation_open(), "Back hides it")
	assert_false(gr._player.creation_hold, "and world input is unfrozen")
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
		"creation.name", "creation.enter", "creation.open", "creation.welcome", "creation.back",
		"creation.refuse.rate_limited", "creation.refuse.already_created"]
	for loc in ["en", "pt_BR"]:
		for k in keys:
			assert_true(str((cats.get(loc, {}) as Dictionary).get(k, "")).strip_edges() != "", "%s has %s" % [loc, k])


# --- Phase 284: hair sits on the scalp -------------------------------------------------------------------------

const HEAD_KEY_FORMAT := "models/characters/heads/%s.glb.raw"
const HEAD_IDS := ["chibi_head_m", "chibi_head_f"]
const BODY_KEY := "models/characters/bodies/chibi_body_m.glb.raw"


func _hair_ids() -> Array:
	return (CreationRules.data().get("hairStyles") as Dictionary).keys()


## Every triangle of a mesh as [a, b, c] in the mesh space, scaled by `s` about the origin and moved by `offset`.
func _triangles(mesh: Mesh, offset: Vector3, s: float) -> Array:
	var out := []
	for surf in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surf)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i in range(0, idx.size(), 3):
			out.append([v[idx[i]] * s + offset, v[idx[i + 1]] * s + offset, v[idx[i + 2]] * s + offset])
	return out


## Heights at which the vertical line through (x, z) crosses the triangles.
func _hits(tris: Array, x: float, z: float) -> Array:
	var ys := []
	for t in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var c: Vector3 = t[2]
		var d := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
		if absf(d) < 1e-9:
			continue
		var l1 := ((b.z - c.z) * (x - c.x) + (c.x - b.x) * (z - c.z)) / d
		var l2 := ((c.z - a.z) * (x - c.x) + (a.x - c.x) * (z - c.z)) / d
		var l3 := 1.0 - l1 - l2
		if l1 >= -1e-6 and l2 >= -1e-6 and l3 >= -1e-6:
			ys.append(l1 * a.y + l2 * b.y + l3 * c.y)
	return ys


func _test_hair_anchors_and_scalp_gap() -> void:
	for head in HEAD_IDS:
		var head_key: String = HEAD_KEY_FORMAT % head
		var head_anchor: Variant = AssetOverlay.load_marker(head_key, AvatarBuilder.HEAD_ANCHOR)
		assert_true(head_anchor != null, "%s has a hair_anchor" % head)
		var head_mesh := AssetOverlay.load_mesh(head_key)
		if head_anchor == null or head_mesh == null:
			continue
		for id in _hair_ids():
			var hair_key := AvatarBuilder.hair_key(str(id))
			var hair_anchor: Variant = AssetOverlay.load_marker(hair_key, AvatarBuilder.HAIR_ANCHOR)
			assert_true(hair_anchor != null, "%s has an anchor" % id)
			var hair_mesh := AssetOverlay.load_mesh(hair_key)
			if hair_anchor == null or hair_mesh == null:
				continue
			for s in [1.0, 1.2]:
				var fit := AvatarBuilder.fit_transform(head_anchor, hair_anchor, s)
				var head_tris := _triangles(head_mesh, Vector3.ZERO, s)
				# Anchors coincide: the hair's marker lands on the head's marker (scaled with the head).
				assert_true((fit * (hair_anchor as Vector3)).distance_to((head_anchor as Vector3) * s) <= 0.001,
					"%s on %s at scale %s: the anchors coincide" % [id, head, s])
				var hair_tris := _triangles(hair_mesh, fit.origin, s)
				var top: float = (head_anchor as Vector3).y * s
				var covered := 0
				for p in [Vector2(0, 0), Vector2(0.22, 0.2), Vector2(-0.22, 0.2), Vector2(0.22, -0.2), Vector2(-0.22, -0.2)]:
					var hits := _hits(hair_tris, p.x * s, p.y * s)
					if hits.is_empty():
						continue
					covered += 1
					var gap := maxf(0.0, float(hits.min()) - top)
					var poke := maxf(0.0, top - float(hits.max()))
					assert_true(gap <= 0.01, "%s on %s at scale %s: scalp gap %.3f m <= 1 cm" % [id, head, s, gap])
					assert_true(poke <= 0.005, "%s on %s at scale %s: the scalp pokes %.3f m through" % [id, head, s, poke])
				assert_true(covered > 0, "%s on %s: the hair covers part of the scalp" % [id, head])
				assert_true(not head_tris.is_empty(), "%s: the head has triangles" % head)


func _test_hair_fit_and_fallback() -> void:
	var ch := CharacterSlice.new()
	add_child(ch)
	var app: Dictionary = ch.deserialize_appearance(ch.creation_recipe({ "gender": "masculine", "hair": "hair_m_crop", "hairColor": 129 }))
	# A rig whose head carries the scalp anchor: the hair is fitted so the anchors coincide.
	var body := AssetOverlay.load_rig_scene(BODY_KEY)
	assert_true(body != null, "the chibi body loads")
	if body != null:
		var scalp: Variant = AvatarBuilder.head_anchor(body)
		assert_true(scalp != null, "the chibi body's head anchor is under the Head bone")
		var hair := AvatarBuilder.attach_hair(ch, body, app)
		assert_true(hair != null, "the hair attaches")
		if hair != null and scalp != null:
			var marker: Variant = AssetOverlay.load_marker(AvatarBuilder.hair_key("hair_m_crop"), AvatarBuilder.HAIR_ANCHOR)
			assert_true((hair.transform * (marker as Vector3)).distance_to(scalp as Vector3) <= 0.001, "the fitted hair's anchor is on the scalp")
		body.free()
	# A rig without a head anchor (the player rig): hair attaches as before, at the bone origin, no crash.
	var rig := AssetOverlay.load_rig_scene(AssetOverlay.first_key("meshes", ch.DEFAULT_RIG_KEYS))
	if rig != null:
		assert_true(AvatarBuilder.head_anchor(rig) == null, "the default rig has no head anchor")
		var plain := AvatarBuilder.attach_hair(ch, rig, app)
		assert_true(plain != null and plain.transform == Transform3D.IDENTITY, "hair on an anchorless rig keeps its old placement")
		rig.free()
	# The fit moves the hair by the anchor difference and scales both with the head.
	var t := AvatarBuilder.fit_transform(Vector3(0, 0.4, 0), Vector3(0, 0.3, 0), 1.2)
	assert_true(t.origin.distance_to(Vector3(0, 0.12, 0)) < 1e-6 and is_equal_approx(t.basis.x.x, 1.2), "the fit offsets and scales")
	ch.free()


# --- Phase 286: men and women who look different ------------------------------------------------------------------

func _joint_x(scene: Node3D, bone: String) -> float:
	var skeleton := scene.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	return absf(skeleton.get_bone_global_rest(skeleton.find_bone(bone)).origin.x)


func _test_body_types_differ() -> void:
	var ch := CharacterSlice.new()
	add_child(ch)
	var ratios := {}
	var meshes := {}
	for g in ["masculine", "feminine"]:
		var recipe: Dictionary = ch.creation_recipe({ "gender": g, "hair": "hair_m_crop" if g == "masculine" else "hair_f_bob", "hairColor": 129 })
		var iid: String = ch.create_character_from_recipe(recipe, Vector3.ZERO)
		assert_true(ch.attach_default_rig(iid), "%s: a rig attaches" % g)
		var want := "models/characters/bodies/%s.glb.raw" % ("chibi_body_m" if g == "masculine" else "chibi_body_f")
		assert_eq(ch._instances[iid]["rig_key"], want, "%s: the body type's own mesh" % g)
		var scene: Node3D = ch._instances[iid]["rig_node"]
		assert_true(scene.find_child(AvatarBuilder.HEAD_NODE, true, false) != null, "%s: its own head mesh is on the Head bone" % g)
		# Shoulder joint span over hip joint span, measured on the placeholder skeleton.
		ratios[g] = _joint_x(scene, "Arm_L") / _joint_x(scene, "Leg_L")
		var body: MeshInstance3D = null
		for m in scene.find_children("*", "MeshInstance3D", true, false):
			if (m as MeshInstance3D).name == "Body":
				body = m
		assert_true(body != null, "%s: a body mesh" % g)
		meshes[g] = [body.mesh.get_aabb(), (scene.find_child(AvatarBuilder.HEAD_NODE, true, false) as MeshInstance3D).mesh.get_aabb()]
		# Every equipment socket resolves to a bone of this body's skeleton, and a chestplate attaches.
		var skeleton := scene.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		for socket in ["socket_head", "socket_chest", "socket_weapon_r", "socket_weapon_l", "socket_shield", "socket_back",
				"socket_hip_r", "socket_hip_l", "socket_cape"]:
			var bone: String = ch._instances[iid]["rig"].socket_to_bone(socket)
			assert_true(bone != "" and skeleton.find_bone(bone) != -1, "%s: %s is a bone of the body (%s)" % [g, socket, bone])
		assert_true(ch.apply_equipment(iid, "Chest", "VeilsteelChestplate"), "%s: a chestplate attaches" % g)
		assert_true(ch.get_part_node(iid, "Chest") != null, "%s: the chestplate is on" % g)
	assert_true(ratios["masculine"] >= ratios["feminine"] * 1.15, "the male shoulder/hip ratio is >= 15%% above the female's (%.2f vs %.2f)" % [ratios["masculine"], ratios["feminine"]])
	assert_true(meshes["masculine"] != meshes["feminine"], "the attached meshes differ")
	# Without a body mesh in the manifest the single rig stays as the fallback.
	var plain := ch.create_character_from_recipe({ "skeleton": "HumanoidSkeleton", "body": "no_such_body" }, Vector3.ZERO)
	assert_true(ch.attach_default_rig(plain), "an unknown body id still gets a rig")
	assert_eq(ch._instances[plain]["rig_key"], "models/player_rig.glb.raw", "the default rig is the fallback")
	ch.free()


func _test_look_change_swaps_body() -> void:
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid: String = ch.create_character_from_recipe(ch.creation_recipe({ "gender": "masculine", "hair": "hair_m_crop", "hairColor": 129 }), Vector3.ZERO)
	assert_true(ch.attach_default_rig(iid), "a rig attaches")
	assert_eq(ch._instances[iid]["rig_key"], "models/characters/bodies/chibi_body_m.glb.raw", "the male body")
	assert_true(ch.apply_look(iid, { "gender": "feminine", "hair": "hair_f_bob", "hairColor": 129 }), "the look applies")
	assert_eq(ch._instances[iid]["rig_key"], "models/characters/bodies/chibi_body_f.glb.raw", "the new look wears the female body")
	assert_true(ch._instances[iid]["rig_node"].find_child(AvatarBuilder.HEAD_NODE, true, false) != null, "with its own head")
	# A character on the default rig gets its body rig once its look names one.
	var plain: String = ch.create_character_from_recipe({ "skeleton": "HumanoidSkeleton", "body": "no_such_body" }, Vector3.ZERO)
	assert_true(ch.attach_default_rig(plain), "the default rig attaches")
	assert_true(ch.apply_look(plain, { "gender": "masculine", "hair": "hair_m_crop", "hairColor": 129 }), "a created look applies")
	assert_eq(ch._instances[plain]["rig_key"], "models/characters/bodies/chibi_body_m.glb.raw", "the created look wears its body")
	ch.free()
