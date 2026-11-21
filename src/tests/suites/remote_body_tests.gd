extends "res://src/tests/test_support.gd"
## Phase 293 — other players look like people: a remote avatar is a player body built from the player rig and the
## peer's look (never the `TravellerHuman` creature), the same body the local player and the Character window
## build from that look, its nameplate above the rig's head; the host sends a peer's look in the same flush as
## that peer's first state in a client's AOI; an equipment change reaches the viewers' copy of the body.

const GameRoot := preload("res://src/core/game_root.gd")
const PeerWiring := preload("res://src/networking/peer_wiring.gd")
const HeldItemWiring := preload("res://src/character/held_item_wiring.gd")
const CreationRules := preload("res://src/character/creation_rules.gd")
const RelayBatch := preload("res://src/networking/relay_batch.gd")
const AvatarBuilder := preload("res://src/character/avatar_builder.gd")
const Part3 := preload("res://src/character/character_part_3.gd")

const LOOK := { "name": "Akira", "gender": "feminine", "hair": "hair_f_bob", "hairColor": 129 }
const LOOK_M := { "name": "Kenji", "gender": "masculine", "hair": "hair_m_spiky", "hairColor": 41 }


func register() -> void:
	_run_test("remote body: a remote avatar is built from the player rig in its look, not the TravellerHuman creature", _test_remote_is_player_rig)
	_run_test("remote body: before its look lands a remote avatar is the default player body, then it is redressed", _test_default_then_look)
	_run_test("remote body: the local player, the Character window and a remote avatar of one look are one body", _test_same_body)
	_run_test("remote body: the nameplate sits above the rig's head, not at the fixed height", _test_nameplate_on_head)
	_run_test("remote body: the host sends a peer's look with its first state in a client's AOI, once per pair", _test_host_first_state_look)
	_run_test("remote body: an equipment change reaches the viewers and the remote body wears it", _test_equipment_resends_look)
	_run_test("remote body: a remote avatar in a known look is built once", _test_built_once)
	_run_test("remote body: the host's own body sends its look ahead of its first state to each new viewer", _test_host_body_look)
	_run_test("remote body: the host reads a look once per player for a crowd of new pairs", _test_look_cache)
	_run_test("remote body: a holder new to a viewer's AOI is shown with its hand item (#719)", _test_held_on_entry)


func _client_rig() -> Dictionary:
	var root: GameRoot = GameRoot.new()
	var ch := CharacterSlice.new()
	add_child(ch)
	var player := PlayerSlice.new()
	root._character = ch
	root._player = player
	root._is_client = true
	var w := PeerWiring.new()
	w.root = root
	return { "root": root, "ch": ch, "player": player, "w": w }

func _free_client(r: Dictionary) -> void:
	r["ch"].free()
	r["player"].free()
	r["root"].free()

func _skeleton_of(rig_node: Node) -> Skeleton3D:
	var found: Array = rig_node.find_children("*", "Skeleton3D", true, false)
	return found[0] as Skeleton3D if not found.is_empty() else null

## The mesh set of a rig scene (node paths, sorted) and its bone count.
func _body_shape(rig_node: Node) -> Array:
	var meshes: Array = []
	for n in rig_node.find_children("*", "MeshInstance3D", true, false):
		meshes.append(str(rig_node.get_path_to(n)))
	meshes.sort()
	var skel := _skeleton_of(rig_node)
	return [meshes, skel.get_bone_count() if skel != null else -1]


func _test_remote_is_player_rig() -> void:
	var r := _client_rig()
	var ch: CharacterSlice = r["ch"]
	ch.set_peer_look(5, LOOK)
	ch.set_peer_equipment(5, { "Chest": "NoviceTunic" })
	var iid: String = r["w"].ensure_remote_avatar(5, Vector3(3, 0, 0))
	assert_true(iid != "", "the avatar is built")
	assert_eq(ch.get_peer_character(5), iid, "and bound to the peer")
	var inst: Dictionary = ch._instances.get(iid, {})
	assert_true(inst.get("rig_node", null) != null, "it wears a rig scene, not the procedural box body")
	assert_eq(str(inst.get("rig_key", "")), "models/characters/bodies/chibi_body_f.glb.raw", "the look's body type picks the body rig")
	var app := ch.get_appearance(iid)
	var want: Dictionary = ch.creation_recipe(LOOK)
	assert_eq(str(app["body"]), str(want["body"]), "the gender's body")
	assert_eq(str(app["hair"]), "hair_f_bob", "the chosen hair")
	assert_eq(int(app["hairColor"]), 129, "the chosen hair colour")
	assert_eq(app.get("skin", null), want.get("skin", null), "the preset's skin")
	assert_eq(ch.get_equipment_set(iid).get("Chest", ""), "NoviceTunic", "what the peer wears")
	assert_true(AvatarBuilder.hair_node(inst["rig_node"]) != null, "hair sits on the head")
	assert_eq(ch.get_nameplate(iid), "Akira", "named")
	# A second state only moves it: no rebuild.
	assert_eq(r["w"].ensure_remote_avatar(5, Vector3(4, 0, 0)), iid, "a later state moves the same avatar")
	var src := FileAccess.get_file_as_string("res://src/networking/peer_wiring.gd")
	assert_false(src.contains("create_character(\"TravellerHuman\""), "the peer wiring never builds a creature for a player")
	_free_client(r)

func _test_default_then_look() -> void:
	var r := _client_rig()
	var ch: CharacterSlice = r["ch"]
	var iid: String = r["w"].ensure_remote_avatar(6, Vector3.ZERO)
	var inst: Dictionary = ch._instances.get(iid, {})
	assert_true(inst.get("rig_node", null) != null, "no look yet: still a player rig")
	assert_true(str(inst.get("rig_key", "")) in ch.DEFAULT_RIG_KEYS or AvatarBuilder.is_body_key(str(inst.get("rig_key", ""))),
		"the default player body, not a creature")
	ch.set_peer_look(6, LOOK_M)
	assert_eq(str(ch._instances[iid].get("rig_key", "")), "models/characters/bodies/chibi_body_m.glb.raw", "the look redresses it on its body")
	assert_eq(str(ch.get_appearance(iid)["hair"]), "hair_m_spiky", "with its hair")
	_free_client(r)

func _test_same_body() -> void:
	var r := _client_rig()
	var ch: CharacterSlice = r["ch"]
	# The local player: the client's boot path builds its own body from its look.
	var own: String = ch.build_player_body(LOOK, Vector3.ZERO)
	ch.set_player_character(own)
	# The Character window's doll: the local player's appearance through the avatar builder.
	var doll: Dictionary = ch.build_avatar("sheet_doll", ch.deserialize_appearance(ch.get_appearance(own)))
	# A remote player in the same look.
	ch.set_peer_look(9, LOOK)
	var remote: String = r["w"].ensure_remote_avatar(9, Vector3(2, 0, 0))
	var want := _body_shape(ch._instances[own]["rig_node"])
	assert_true((want[0] as Array).size() > 0 and int(want[1]) > 0, "the local body has meshes and bones")
	assert_eq(_body_shape(ch._instances[remote]["rig_node"]), want, "the remote avatar has the local body's meshes and bones")
	assert_true(doll.has("rig_node"), "the doll got the rig")
	if doll.has("rig_node"):
		assert_eq(_body_shape(doll["rig_node"]), want, "the doll has the local body's meshes and bones")
		(doll["root"] as Node).free()
	_free_client(r)

func _test_nameplate_on_head() -> void:
	var r := _client_rig()
	var ch: CharacterSlice = r["ch"]
	ch.set_peer_look(7, LOOK)
	var iid: String = r["w"].ensure_remote_avatar(7, Vector3.ZERO)
	var inst: Dictionary = ch._instances[iid]
	var label := (inst["root"] as Node3D).get_node_or_null("Nameplate") as Label3D
	assert_true(label != null and label.visible, "the nameplate is shown over the rig")
	if label != null:
		var skel := _skeleton_of(inst["rig_node"])
		var head := skel.find_bone("Head") if skel != null else -1
		assert_true(head >= 0, "the rig has a head bone")
		if head >= 0:
			var head_y: float = (Part3._to_root(skel, inst["root"]) * skel.get_bone_global_rest(head).origin).y
			assert_true(label.position.y > head_y, "the plate (%.2f m) is above the head bone (%.2f m)" % [label.position.y, head_y])
			assert_true(label.position.y < Part3.NAMEPLATE_HEIGHT, "and closer than the fixed %.1f m over a chibi body" % Part3.NAMEPLATE_HEIGHT)
	_free_client(r)


## A host with two bound clients (peers 4 and 6), each with a created look.
func _host_rig() -> Dictionary:
	var reg := PlayerRegistry.new()
	reg.is_authoritative = true
	add_child(reg)
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.player_registry = reg
	var wire := MemoryTransport.new([4, 6])
	n.set_transport(wire)
	var pids := {}
	for peer: int in [4, 6]:
		var pid := reg.resolve_identity(peer, "")
		n.set_player_id(peer, pid)
		pids[peer] = pid
	reg.create_character(pids[4], { "name": "Akira", "gender": "feminine", "hair": "hair_f_bob", "hairColor": 129 }, 0)
	reg.create_character(pids[6], { "name": "Kenji", "gender": "masculine", "hair": "hair_m_spiky", "hairColor": 41 }, 0)
	return { "reg": reg, "n": n, "wire": wire, "pids": pids }

func _report(n: NetworkingSlice, peer: int, pos: Vector3) -> void:
	n.remember_player_state(peer, pos)
	n._route_c2h(peer, { "type": "player_moved", "pk": WorldPos.pos_to_packet_text(WorldPos.from_world(pos.x, pos.y, pos.z)) })

## Per recipient, the outbox as [type, subject] in send order.
func _sent_to(wire: MemoryTransport, rid: int) -> Array:
	var out: Array = []
	for o in wire.outbox:
		if int(o["peer_id"]) != rid:
			continue
		var p: Dictionary = o["payload"]
		if str(p["type"]) == RelayBatch.PACKET_TYPE:
			for e in RelayBatch.decode(p):
				out.append(["state", int(e[0])])
		elif str(p["type"]) == "peer_look":
			out.append(["look", int(p["peer_id"])])
	return out

func _test_host_first_state_look() -> void:
	var h := _host_rig()
	var n: NetworkingSlice = h["n"]
	var wire: MemoryTransport = h["wire"]
	var entered: Array = []
	var on_entered := func(viewer: int, subject: int) -> void: entered.append([viewer, subject])
	GameBus.aoi_pair_entered.connect(on_entered)
	_report(n, 4, Vector3(0, 10, 0))
	_report(n, 6, Vector3(5, 10, 0))
	wire.outbox.clear()
	n.flush_relays()
	var to4 := _sent_to(wire, 4)
	assert_true(to4.has(["state", 6]), "peer 4 hears peer 6's first state")
	assert_true(to4.has(["look", 6]), "and peer 6's look in the same flush, not on a later request")
	assert_true(to4.find(["look", 6]) < to4.find(["state", 6]), "the look lands first, so the body is built dressed")
	for o in wire.outbox:
		if str(o["payload"]["type"]) == "peer_look" and int(o["payload"]["peer_id"]) == 6:
			assert_eq(str(o["payload"]["look"].get("hair", "")), "hair_m_spiky", "the look is the peer's own")
	assert_true(_sent_to(wire, 6).has(["look", 4]), "both ways")
	assert_true(entered.has([4, 6]) and entered.has([6, 4]), "the pair's entry is announced for the hand item")
	# The pair is known now: later states carry no look.
	wire.outbox.clear()
	entered.clear()
	n._relays._last[4][6][0] -= RelayBatch.KEEPALIVE_MS   # make the next report due
	_report(n, 6, Vector3(6, 10, 0))
	n.flush_relays()
	assert_true(_sent_to(wire, 4).has(["state", 6]), "a later state is relayed")
	assert_false(_sent_to(wire, 4).has(["look", 6]), "without the look again")
	assert_true(entered.is_empty(), "and no second entry")
	# A pair that expired (the subject left and came back) gets the look again.
	n._relays.prune(Time.get_ticks_msec() + RelayBatch.PAIR_TTL_MS * 2.0)
	wire.outbox.clear()
	_report(n, 6, Vector3(7, 10, 0))
	n.flush_relays()
	assert_true(_sent_to(wire, 4).has(["look", 6]), "a peer back in the AOI is sent its look again")
	GameBus.aoi_pair_entered.disconnect(on_entered)
	n.free()
	h["reg"].free()

## The equipment half of a peer's look: a change on the host reaches the viewers in the peer's AOI, and the client's
## copy of the body wears it (the creation look itself carries no gear, so it is not resent).
func _test_equipment_resends_look() -> void:
	var h := _host_rig()
	var n: NetworkingSlice = h["n"]
	var wire: MemoryTransport = h["wire"]
	n.remember_player_state(4, Vector3(0, 10, 0))
	n.remember_player_state(6, Vector3(5, 10, 0))
	wire.outbox.clear()
	GameBus.equipment_changed.emit(str(h["pids"][6]), { "Chest": "NoviceTunic" })
	var worn: Variant = null
	for o in wire.outbox:
		if int(o["peer_id"]) == 4 and str(o["payload"]["type"]) == "peer_equipment" and int(o["payload"]["peer_id"]) == 6:
			worn = o["payload"]["worn"]
	assert_true(worn is Dictionary, "peer 4 is sent peer 6's new worn set")
	for o in wire.outbox:
		assert_false(int(o["peer_id"]) == 6, "the owner is not sent its own")
	n.free()
	h["reg"].free()
	# The client applies it to the remote body it built from the look.
	var r := _client_rig()
	var ch: CharacterSlice = r["ch"]
	ch.set_peer_look(6, LOOK_M)
	var iid: String = r["w"].ensure_remote_avatar(6, Vector3.ZERO)
	ch.set_peer_equipment(6, worn if worn is Dictionary else {})
	assert_eq(ch.get_equipment_set(iid).get("Chest", ""), "NoviceTunic", "the remote body wears the change")
	assert_true(ch._instances[iid].get("rig_node", null) != null, "still on its player rig")
	_free_client(r)

## A remote avatar built in a known look is built once: binding it does not rebuild it in the same look.
func _test_built_once() -> void:
	var r := _client_rig()
	var ch: CharacterSlice = r["ch"]
	ch.set_peer_look(5, LOOK)
	var built := [0]
	var on_built := func(_iid: String, _app: Dictionary) -> void: built[0] += 1
	GameBus.character_appearance_changed.connect(on_built)
	var iid: String = r["w"].ensure_remote_avatar(5, Vector3.ZERO)
	GameBus.character_appearance_changed.disconnect(on_built)
	assert_eq(built[0], 0, "no rebuild through dress_peer after the body was built in its look")
	assert_eq(str(ch._instances[iid].get("look_key", "")), Part3.look_key(LOOK), "the look key is recorded")
	_free_client(r)

## The host reads each player's look once for a crowd of new pairs, and a changed look replaces it.
func _test_look_cache() -> void:
	var h := _host_rig()
	var n: NetworkingSlice = h["n"]
	var pid6: String = h["pids"][6]
	var first: Dictionary = n._m1.cached_look(pid6)
	assert_eq(str(first.get("hair", "")), "hair_m_spiky", "the cache holds the registry's look")
	n._m1._look_cache[pid6] = { "name": "stale" }
	assert_eq(str(n._m1.cached_look(pid6).get("name", "")), "stale", "a second read is served from the cache")
	n._m1.push_look(pid6, h["reg"].look_of(pid6))
	assert_eq(str(n._m1.cached_look(pid6).get("hair", "")), "hair_m_spiky", "a pushed look change replaces it")
	n.free()
	h["reg"].free()

func _test_held_on_entry() -> void:
	var h := _host_rig()
	var n: NetworkingSlice = h["n"]
	var wire: MemoryTransport = h["wire"]
	n.remember_player_state(4, Vector3(0, 10, 0))
	n.remember_player_state(6, Vector3(5, 10, 0))
	var root: GameRoot = GameRoot.new()
	root._registry = h["reg"]
	root._networking = n
	root._is_client = false
	var w := HeldItemWiring.new()
	w.wire(root)
	w._held[str(h["pids"][6])] = "StonePick"
	wire.outbox.clear()
	GameBus.aoi_pair_entered.emit(4, 6)
	GameBus.aoi_pair_entered.emit(6, 4)   # peer 4 holds nothing: nothing to send
	var held: Array = []
	for o in wire.outbox:
		if str(o["payload"]["type"]) == "held":
			held.append([int(o["peer_id"]), int(o["payload"]["peer_id"]), str(o["payload"]["i"])])
	assert_eq(held, [[4, 6, "StonePick"]], "the viewer is told what the holder has in hand when they meet")
	w.unwire()
	root.free()
	n.free()
	h["reg"].free()

func _test_host_body_look() -> void:
	var h := _host_rig()
	var n: NetworkingSlice = h["n"]
	var wire: MemoryTransport = h["wire"]
	var reg: PlayerRegistry = h["reg"]
	reg.set_local_player("host")
	reg.ensure_player("host")
	n.remember_player_state(4, Vector3(0, 10, 0))
	n.remember_player_state(6, Vector3(NetworkingSlice.AOI_RADIUS * 3.0, 10, 0))
	var entered: Array = []
	var on_entered := func(viewer: int, subject: int) -> void: entered.append([viewer, subject])
	GameBus.aoi_pair_entered.connect(on_entered)
	wire.outbox.clear()
	var at := Vector3(2, 10, 0)
	GameBus.player_state_sync_requested.emit({ "position": at, "world_pos": WorldPos.from_world(at.x, at.y, at.z), "hp": 100.0, "max_hp": 100.0 })
	var kinds: Array = []
	for o in wire.outbox:
		if int(o["peer_id"]) == 4:
			kinds.append(str(o["payload"]["type"]))
	assert_true(kinds.find("peer_look") >= 0 and kinds.find("peer_look") < kinds.find("player_moved"), "peer 4 gets the host's look, then its state: %s" % [kinds])
	for o in wire.outbox:
		assert_false(int(o["peer_id"]) == 6, "a peer outside the host's AOI is sent nothing")
	assert_eq(entered, [[4, 1]], "the meeting is announced once, for the hand item")
	wire.outbox.clear()
	GameBus.player_state_sync_requested.emit({ "position": at, "world_pos": WorldPos.from_world(at.x, at.y, at.z), "hp": 100.0, "max_hp": 100.0 })
	for o in wire.outbox:
		assert_false(str(o["payload"]["type"]) == "peer_look", "a later state carries no look")
	assert_eq(n._m1.introduce_host_body(at, Time.get_ticks_msec() + RelayBatch.PAIR_TTL_MS * 2.0), 1, "after the pair lapses the look goes again")
	GameBus.aoi_pair_entered.disconnect(on_entered)
	n.free()
	reg.free()
