extends "res://src/tests/test_support.gd"
## Phase 133 — the world tests, moved unchanged from the old single-file suite.


func register() -> void:
	_run_test("waystone: the fabric rule, item and station",   _test_waystone_fabric_rule)
	_run_test("waystone: attune and travel, every refusal",    _test_waystone_attune_and_travel)
	_run_test("waystone: the landing is exact far from origin", _test_waystone_exact_landing_far_out)
	_run_test("waystone: a failed teleport refunds the cost",   _test_waystone_failed_teleport_refunds)
	_run_test("waystone: attunements persist; forged ids refuse", _test_waystone_persistence_and_forged_intent)
	_run_test("waystone: a refusal reaches the client",         _test_waystone_result_reaches_client)
	_run_test("waystone: teleport door and chat leftovers",     _test_waystone_wire_and_chat_leftovers)
	_run_test("waystone: map rename and limb notice",           _test_waystone_map_leftovers)
	_run_test("waystone: placement consumes the item, ids are never reused", _test_phase130_waystone_placement)
	_run_test("waystone: an exact position at x ~ 2e7 survives save and load", _test_phase147_waystone_exact_roundtrip)
	_run_test("waystone: refusals are throttled, a full list is refused early", _test_phase130_waystone_throttle_full)
	_run_test("waystone: a seed change saves the old seed",     _test_minimap_seed_change_saves_old_seed)
	_run_test("fabric: treeDensity stays inside the noisy bound", _test_p126_fabric_density_bound)
	_run_test("asset: reload_manifest drops the cached view",   _test_asset_reload_manifest)
	_run_test("rig tree: a missing clip falls back to idle",    _test_rig_tree_missing_clip_fallback)
	_run_test("asset: manifest merges the private over public", _test_asset_manifest_merge)
	_run_test("tree: spawns the per-chunk budget",              _test_tree_spawn_for_chunk)
	_run_test("tree: per-biome species and density",            _test_tree_per_biome_table)
	_run_test("tree: chop yields wood and wears the axe",       _test_tree_chop_yields_wood_and_wears_axe)
	_run_test("tree: chop requires an axe",                     _test_tree_chop_requires_axe)
	_run_test("tree: stump regrows on its cooldown",            _test_tree_stump_regrows_on_cooldown)
	_run_test("tree: despawn is per chunk",                     _test_tree_despawn_is_per_chunk)
	_run_test("tree: chunk hop keeps the stump cooldown",       _test_tree_chunk_hop_keeps_stump_cooldown)
	_run_test("tree: shrinking budget drops surplus trees",     _test_tree_shrinking_budget_reconciles)
	_run_test("tree: chunk index stays consistent",             _test_tree_index_is_consistent)
	_run_test("tree: client forwards then applies host chop",   _test_tree_client_forwards_then_applies_host_chop)
	_run_test("tree: ids agree across peer spawn order",        _test_tree_ids_agree_across_peer_spawn_order)
	_run_test("tree: ids survive a chunk reload",               _test_tree_ids_survive_chunk_reload)
	_run_test("tree: trunk body carries its identity",          _test_tree_trunk_body_carries_its_identity)
	_run_test("asset: placeholder resolves at canonical path",  _test_asset_placeholder_resolves)
	_run_test("asset: no private-only paths hardcoded",          _test_asset_no_private_paths_hardcoded)
	_run_test("asset: pck round-trip proves override works",    _test_asset_pck_round_trip_override)
	_run_test("asset: manifest lists keys that exist on disk",   _test_asset_manifest_keys_exist)
	_run_test("asset: load_mesh / load_animation_library from .glb.raw", _test_asset_load_mesh_and_animation)
	_run_test("asset: placeholder rig is a visible body (#112)", _test_asset_placeholder_rig_is_a_body)
	_run_test("asset: player rig placeholder has the art's contract", _test_asset_player_rig_placeholder_contract)
	_run_test("asset: body sheet placeholders are 64x64, masks black, detail white", _test_asset_body_sheet_placeholders)
	_run_test("asset: attached rigs wear the character material", _test_rig_wears_character_material)
	_run_test("asset: rig root names and the serpent fall clip", _test_asset_rig_root_names_and_fall_clip)
	_run_test("asset: item icon placeholders are 32x32 RGBA",   _test_asset_item_icon_placeholders)
	_run_test("asset: GraywolfPack placeholders have the quadruped contract", _test_asset_graywolfpack_placeholders)
	_run_test("asset: roster creature placeholders have their skeleton contract", _test_asset_creature_roster_placeholders)
	_run_test("asset: item mesh placeholders load with their sheets", _test_asset_item_mesh_placeholders)
	_run_test("asset: every item has a model within budget and bounds", _test_asset_item_models)
	_run_test("asset: missing model key warns and falls back",   _test_asset_missing_model_falls_back)
	_run_test("asset: creature model key derived from entity name", _test_asset_creature_key)
	_run_test("rig tree: every Locomotion.State maps to a node", _test_rig_tree_state_mapping_total)
	_run_test("rig: attach_rig wires scene + tree, falls back on bad key", _test_attach_rig)
	_run_test("placement: exact far positions survive place, snapshot and client placement", _test_exact_placement_paths)
	_run_test("chunks: set_clock resets the self-heal and stranded-retry throttles", _test_chunk_set_clock_resets_throttles)
	_run_test("diag: warn_count survives concurrent warnings from worker threads", _test_diag_warn_concurrent)

func _test_waystone_fabric_rule() -> void:
	var rules := (GameData.WORLD_SYSTEMS["WaystoneTravel"] as Resource).get("rules") as Dictionary
	assert_eq(str(rules["stationType"]), "waystone", "the fabric names the station type")
	assert_true(GameData.ITEMS.has("Waystone") and GameData.RECIPES.has("RecipeWaystone"), "the item and its recipe exist")
	assert_true(GameData.ITEMS.has(str(rules["costItem"])), "the cost item is a real item")
	var stations := StationSlice.new()
	add_child(stations)
	assert_true(stations.placeable_station_types().has("waystone"), "a waystone can be placed as a station")
	stations.free()

func _test_waystone_attune_and_travel() -> void:
	var rig := _waystone_rig()
	var way: WaystoneSlice = rig["way"]
	var st: StationSlice = rig["stations"]
	var reg: PlayerRegistry = rig["reg"]
	var now: Array = rig["now"]
	var where: Dictionary = rig["where"]
	var moved: Array = rig["moved"]
	var a := st.place_station("waystone", Vector3(0.5, 1.0, 0.5))
	var b := st.place_station("waystone", Vector3(5000.5, 1.0, 0.5))
	assert_eq(way.waystone_ids().size(), 2, "both stones are listed")
	st.place_station("forge", Vector3(9.5, 1.0, 9.5))
	assert_false(way.is_waystone("station_2"), "a forge is not a waystone")
	var inv: Node = reg.get_inventory("p1")
	assert_eq(way.travel(a, b, "p1"), "not_attuned_from", "no travel before attuning")
	now[0] += 1.0
	assert_eq(way.try_attune("p1", a), "", "standing at stone A attunes")
	assert_eq(way.try_attune("p1", b), "too_far", "stone B is out of reach from A")
	where["p1"] = WorldPos.from_world(5000.5, 1.0, 0.5)
	assert_eq(way.try_attune("p1", b), "", "standing at stone B attunes")
	assert_eq(way.attuned("p1"), [a, b], "both stones are listed for the player")
	assert_eq(way.attuned("p2"), [], "another player is not attuned")
	where["p1"] = WorldPos.from_world(0.5, 1.0, 0.5)
	now[0] += 1.0
	assert_eq(way.travel(a, b, "p1"), "no_cost", "the cost must be in the inventory")
	assert_true(inv.add_item("AethermiteShard", 3), "stock the cost")
	now[0] += 1.0
	where["p1"] = WorldPos.from_world(50.0, 1.0, 0.5)
	assert_eq(way.travel(a, b, "p1"), "too_far", "the departure stone must be within the attune radius")
	now[0] += 1.0
	where["p1"] = WorldPos.from_world(0.5, 1.0, 0.5)
	assert_eq(way.travel(a, "station_99", "p1"), "missing_stone", "an unknown stone refuses")
	now[0] += 1.0
	assert_eq(way.travel(a, a, "p1"), "same_stone", "travel to the same stone refuses")
	now[0] += 1.0
	assert_eq(way.travel(a, b, "p1"), "", "attuned, in range, paid: the player is moved")
	assert_eq(moved.size(), 1, "one teleport")
	assert_eq(moved[0][0], "p1", "of the traveller")
	assert_eq(moved[0][1], way.exact_pos(b), "to the stone's exact position")
	assert_eq(inv.get_item_count("AethermiteShard"), 3 - way.travel_cost(a, b), "and the cost was paid")
	now[0] += 1.0
	assert_eq(way.travel(a, b, "p1"), "cooldown", "a second journey waits out the cooldown")
	assert_eq(way.travel(a, b, "p1"), "rate_limited", "an intent right after another is rate limited")
	now[0] += float(way.rules()["cooldownSeconds"])
	st.remove_station(b)
	assert_eq(way.travel(a, b, "p1"), "missing_stone", "a destroyed stone refuses")
	assert_eq(way.attuned("p1"), [a], "and drops out of the attuned list")
	assert_eq(way.travel(a, b, "ghost"), "unknown_player", "an unknown player refuses")
	# Rate limit: two intents inside the interval.
	now[0] += 1.0
	way.travel(a, a, "p1")
	assert_eq(way.travel(a, a, "p1"), "rate_limited", "intents are rate limited per player")
	_free_waystone_rig(rig)

func _test_waystone_exact_landing_far_out() -> void:
	var rig := _waystone_rig()
	var way: WaystoneSlice = rig["way"]
	var st: StationSlice = rig["stations"]
	var reg: PlayerRegistry = rig["reg"]
	var moved: Array = rig["moved"]
	var far := { "chunk": Vector2i(1500000, 3), "local": Vector3(7.3125, 12.5, 0.0625) }
	var a := st.place_station("waystone", Vector3(0.5, 1.0, 0.5))
	var b := st.place_station("waystone", Vector3(40.5, 1.0, 0.5))
	way.note_exact(b, far)
	reg.record_waystones("p1", [a, b])
	reg.get_inventory("p1").add_item("AethermiteShard", 50)
	assert_eq(way.travel(a, b, "p1"), "", "travel to a stone at chunk X = 1,500,000")
	assert_eq(moved[0][1], far, "lands on the exact destination, not a float32 approximation")
	assert_true(way.travel_cost(a, b) >= 1, "a journey costs at least one item")
	_free_waystone_rig(rig)

func _test_waystone_failed_teleport_refunds() -> void:
	var rig := _waystone_rig()
	var way: WaystoneSlice = rig["way"]
	var st: StationSlice = rig["stations"]
	var reg: PlayerRegistry = rig["reg"]
	var a := st.place_station("waystone", Vector3(0.5, 1.0, 0.5))
	var b := st.place_station("waystone", Vector3(40.5, 1.0, 0.5))
	reg.record_waystones("p1", [a, b])
	reg.get_inventory("p1").add_item("AethermiteShard", 4)
	way.teleporter = func(_pid: String, _pos: Dictionary) -> bool: return false
	assert_eq(way.travel(a, b, "p1"), "unreachable", "a teleport that cannot be delivered refuses")
	assert_eq(reg.get_inventory("p1").get_item_count("AethermiteShard"), 4, "and nothing was spent")
	_free_waystone_rig(rig)

func _test_waystone_persistence_and_forged_intent() -> void:
	var rig := _waystone_rig()
	var reg: PlayerRegistry = rig["reg"]
	reg.record_waystones("p1", ["station_3", "station_1", "station_1", "", 7])
	assert_eq(reg.get_waystones("p1"), ["station_1", "station_3"], "attunements are sorted, unique and string-only")
	var data := reg.get_player_data("p1")
	var reg2 := PlayerRegistry.new()
	add_child(reg2)
	reg2.apply_player_data("p1", data)
	assert_eq(reg2.get_waystones("p1"), ["station_1", "station_3"], "attunements round-trip through a save and load")
	reg2.apply_player_data("p2", { "waystones": "nonsense" })
	assert_eq(reg2.get_waystones("p2"), [], "a malformed saved list restores empty")
	reg2.free()
	# A client-forged intent names someone else: the host binds the connection's player.
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.set_transport(MemoryTransport.new([9]))
	var seen: Array = []
	var cb := func(from_id: String, to_id: String, pid: String) -> void: seen.append([from_id, to_id, pid])
	GameBus.waystone_travel_intent.connect(cb)
	n._route_c2h(9, { "type": "waystone_travel_intent", "from": "station_0", "to": "station_1", "player_id": "p2" })
	GameBus.waystone_travel_intent.disconnect(cb)
	assert_eq(seen.size(), 0, "an intent from an un-handshaked peer is dropped")
	n.free()
	# On the slice: an id with no record is refused outright.
	var way: WaystoneSlice = rig["way"]
	assert_eq(way.travel("station_0", "station_1", "player_forged"), "unknown_player", "a forged identity has no record")
	_free_waystone_rig(rig)

func _test_waystone_result_reaches_client() -> void:
	var gr: Node = (load("res://src/core/game_root.gd") as GDScript).new()
	var reg := PlayerRegistry.new()
	add_child(reg)
	gr._registry = reg
	gr._is_client = true
	reg.set_local_player(reg.mint_player_id())
	var seen: Array = []
	var cb := func(pid: String, ok: bool, reason: String) -> void: seen.append([pid, ok, reason])
	GameBus.waystone_travel_resolved.connect(cb)
	gr._peer_wiring.on_own_state_synced({ "waystone_result": { "ok": false, "reason": "cooldown" } })
	GameBus.waystone_travel_resolved.disconnect(cb)
	assert_eq(seen.size(), 1, "a refusal sent on the own-state channel reaches the client's bus")
	assert_eq(seen[0], [reg.local_player_id, false, "cooldown"], "addressed to the local player with the host's reason")
	gr.free()
	reg.free()

func _test_waystone_wire_and_chat_leftovers() -> void:
	var bad_y := ChatCommands.parse_position(["1", str(WorldPos.LOCAL_LIMIT * 2.0), "3"])
	assert_false(bad_y["ok"], "parse_position refuses a Y beyond the wire limit")
	assert_true(ChatCommands.parse_position(["1", "5", "3"])["ok"], "and accepts an ordinary one")
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.set_transport(_StampingTransport.new([4]))
	assert_false(n.send_teleport(77, WorldPos.from_world(1.0, 2.0, 3.0)), "send_teleport is false for an unconnected peer")
	assert_true(n.send_teleport(4, WorldPos.from_world(1.0, 2.0, 3.0)), "and true for a connected one")
	n.emulate_network = true
	n.emulator_loss_rate = NetworkingSlice.MAX_LOSS_RATE
	var sent := 0
	var dropped := 0
	for i in 400:
		if n.send_teleport(4, WorldPos.from_world(1.0, 2.0, 3.0)):
			sent += 1
		else:
			dropped += 1
	assert_true(dropped > 0 and sent > 0, "an emulated drop reports false (%d dropped, %d sent)" % [dropped, sent])
	n.free()
	# /say from an admin spends the bucket; other admin commands do not.
	var rig := _chat_rig()
	var chat: ChatSlice = rig["chat"]
	var now := [100.0]
	chat.set_clock(func() -> float: return now[0])
	for i in ChatSlice.CHAT_BURST + 3:
		chat.handle_intent("/say hello %d" % i, "")
	assert_eq(chat.chat_rate_refused, 3, "an admin's /say is bucket-limited")
	# A burst of distinct speakers is bounded by the cap even inside the refill window.
	for i in ChatSlice.MAX_BUCKETS * 2:
		chat.handle_intent("x", "burst_%d" % i)
	assert_true(chat._buckets.size() <= ChatSlice.MAX_BUCKETS, "buckets never exceed the cap (%d)" % chat._buckets.size())
	chat._prune_buckets()
	assert_true(chat._buckets.size() <= ChatSlice.MAX_BUCKETS, "and _prune_buckets leaves at most the cap")
	chat.free()
	rig["reg"].free()

func _test_waystone_map_leftovers() -> void:
	var MapWindowScript := preload("res://src/ui/map_window.gd")
	var win: Control = MapWindowScript.new()
	win.size = Vector2(400, 400)
	var minimap := Minimap.new()
	win.minimap = minimap
	add_child(win)
	add_child(minimap)
	minimap.add_waypoint("Camp", WorldPos.from_world(10.0, 0.0, 10.0))
	assert_true(minimap.rename_waypoint(0, "Base camp"), "a waypoint can be renamed")
	assert_eq(str(minimap.get_waypoints()[0]["name"]), "Base camp", "and the new name is kept")
	assert_false(minimap.rename_waypoint(0, "   "), "an empty name changes nothing")
	assert_false(minimap.rename_waypoint(5, "x"), "nor does an unknown index")
	# A right-click past the globe's limb names no place: it says so instead of doing nothing.
	win.set_planet(true)
	var heard: Array = []
	win.notice.connect(func(t: String) -> void: heard.append(t))
	win.right_click(Vector2(win._radius_px() * 1.5, 0.0))
	assert_eq(heard.size(), 1, "a right-click off the planet emits a notice")
	win.free()
	minimap.free()

func _test_phase130_waystone_placement() -> void:
	var rig := _waystone_rig()
	var st: StationSlice = rig["stations"]
	var inv: Node = rig["reg"].get_inventory("p1")
	assert_eq(st.placement_item("waystone"), "Waystone", "the fabric names the waystone's placement item")
	assert_eq(st.placement_item("forge"), "", "a forge stays free")
	assert_eq(st.try_place_station("waystone", Vector3(0.5, 1.0, 0.5), inv), "", "no item: refused")
	assert_eq(st.try_place_station("waystone", Vector3(0.5, 1.0, 0.5)), "", "no inventory: refused")
	assert_true(inv.add_item("Waystone", 1), "stock a stone")
	var id := st.try_place_station("waystone", Vector3(0.5, 1.0, 0.5), inv)
	assert_true(id != "", "with the item the stone is placed")
	assert_eq(inv.get_item_count("Waystone"), 0, "and the item is consumed")
	assert_true(st.try_place_station("forge", Vector3(9.5, 1.0, 9.5)) != "", "a forge places without an inventory")
	# A removed trailing id is not reused after save/load.
	var last := st.place_station("waystone", Vector3(20.5, 1.0, 0.5))
	var data := st.get_station_data()
	var next := st.next_id()
	st.remove_station(last)
	data = st.get_station_data()
	var fresh := StationSlice.new()
	add_child(fresh)
	fresh.apply_station_data(data)
	fresh.restore_next_id(next)
	var again := fresh.place_station("waystone", Vector3(30.5, 1.0, 0.5))
	assert_true(again != last, "the removed trailing id %s is not handed out again" % last)
	fresh.free()
	_free_waystone_rig(rig)

func _test_phase130_waystone_throttle_full() -> void:
	var rig := _waystone_rig()
	var way: WaystoneSlice = rig["way"]
	var st: StationSlice = rig["stations"]
	var reg: PlayerRegistry = rig["reg"]
	var now: Array = rig["now"]
	reg.is_authoritative = true
	var a := st.place_station("waystone", Vector3(0.5, 1.0, 0.5))
	var replies: Array = []
	var on_res := func(_pid: String, ok: bool, reason: String) -> void: replies.append([ok, reason])
	GameBus.waystone_travel_resolved.connect(on_res)
	var was_quiet := Diag.quiet
	Diag.quiet = true
	for i in 20:
		way._on_travel_intent(a, "station_99", "p1")
		now[0] += 0.01
	Diag.quiet = was_quiet
	GameBus.waystone_travel_resolved.disconnect(on_res)
	assert_true(replies.size() <= 1, "20 refused intents in 0.2 s earn at most one reply, got %d" % replies.size())
	# A full list refuses early instead of truncating.
	var ids: Array = []
	for i in PlayerRegistry.MAX_WAYSTONES:
		ids.append("fake_%d" % i)
	reg.record_waystones("p1", ids)
	assert_eq(reg.get_waystones("p1").size(), PlayerRegistry.MAX_WAYSTONES, "the list is full")
	assert_eq(way.try_attune("p1", a), "full", "attuning with a full list is refused")
	_free_waystone_rig(rig)

## Phase 125 — a world-seed change writes the old seed's explored set and waypoints before clearing them.
func _test_minimap_seed_change_saves_old_seed() -> void:
	var dir := "user://test_seed_change_dir"
	var old_path: String = _RevealedStore.path_for(dir, 11)
	DirAccess.remove_absolute(old_path)
	var terrain := TerrainSlice.new()
	terrain.set_world_seed(11)
	var m := Minimap.new()
	m.terrain_slice = terrain
	m.revealed_dir = dir
	m.set_player_pos(Vector2(40.0, 40.0))
	m._tick_revealed_store(0.0)
	m._tick_revealed_store(Minimap.SEED_SETTLE_SECONDS)
	assert_true(m.is_revealed_loaded(), "the first seed is loaded")
	assert_true(m.add_waypoint("Keep", WorldPos.from_world(10.0, 0.0, 10.0)), "a waypoint is placed under seed 11")
	assert_false(FileAccess.file_exists(old_path), "not yet written (the debounce has not run)")
	terrain.set_world_seed(12)
	m._tick_revealed_store(0.0)
	m._tick_revealed_store(Minimap.SEED_SETTLE_SECONDS)
	assert_true(FileAccess.file_exists(old_path), "the old seed's file was written before the set was cleared")
	var got: Dictionary = _RevealedStore.load_all(old_path, 11)
	assert_eq(got["waypoints"].size(), 1, "with its waypoint")
	assert_eq(m.get_waypoints().size(), 0, "and the new seed starts with none")
	m.free()
	terrain.free()
	DirAccess.remove_absolute(old_path)
	DirAccess.remove_absolute(_RevealedStore.path_for(dir, 12))

func _test_p126_fabric_density_bound() -> void:
	var bound := int(floor(float(RegionStoreScript.GEN_TREE_MAX) / (1.0 + TreeSlice.DENSITY_NOISE)))
	assert_eq(bound, 42, "the density bound is GEN_TREE_MAX / (1 + DENSITY_NOISE)")
	# Phase 138 — the fabric validator keeps its own copies of the two constants; they must match.
	var js := FileAccess.get_file_as_string("res://fabric/world/biomes/index.js")
	var re := RegEx.new()
	re.compile("const GEN_TREE_MAX = (\\d+)")
	var m := re.search(js)
	assert_true(m != null and int(m.get_string(1)) == RegionStoreScript.GEN_TREE_MAX, "fabric GEN_TREE_MAX matches RegionStore.GEN_TREE_MAX")
	re.compile("const DENSITY_NOISE = ([0-9.]+)")
	m = re.search(js)
	assert_true(m != null and is_equal_approx(float(m.get_string(1)), TreeSlice.DENSITY_NOISE), "fabric DENSITY_NOISE matches TreeSlice.DENSITY_NOISE")
	for key in GameData.BIOMES:
		var b: Variant = GameData.BIOMES[key]
		if b != null and b.get("treeDensity") != null:
			assert_true(int(b.get("treeDensity")) <= bound, "biome %s density is within the noisy bound" % key)


# ---- Phase 127 — terrain streaming, generation records and persistence cleanup sweep ----

## The manifest is cached (including an empty result); `reload_manifest` is how a mount that
## happens after the first lookup gets seen.
func _test_asset_reload_manifest() -> void:
	AssetOverlay._manifest = { "meshes": { "models/not_a_real_key.glb.raw": "x" } }
	AssetOverlay._manifest_loaded = true
	assert_true(AssetOverlay.has_key("meshes", "models/not_a_real_key.glb.raw"), "the cached view answers")
	assert_false(AssetOverlay.has_key("meshes", "models/placeholder_rig.glb.raw"), "and hides what it does not hold")
	AssetOverlay.reload_manifest()
	assert_false(AssetOverlay._manifest_loaded, "the cache is marked stale")
	assert_true(AssetOverlay.has_key("meshes", "models/placeholder_rig.glb.raw"), "the next lookup re-reads the manifest")
	assert_false(AssetOverlay.has_key("meshes", "models/not_a_real_key.glb.raw"), "and the stale entry is gone")


# ---------------------------------------------------------------------------
# Phase 51 — continents, oceans and mountains
# ---------------------------------------------------------------------------

## A rig missing a clip plays idle for it rather than naming a clip the player lacks.
func _test_rig_tree_missing_clip_fallback() -> void:
	const RigTree := preload("res://src/character/rig_tree.gd")
	var player := AnimationPlayer.new()
	var lib := AnimationLibrary.new()
	lib.add_animation("idle", Animation.new())
	lib.add_animation("walk", Animation.new())
	player.add_animation_library("", lib)
	assert_eq(RigTree._resolve_clip(player, "walk"), "walk", "a present clip is used")
	assert_eq(RigTree._resolve_clip(player, "death"), "idle", "a missing clip falls back to idle")
	assert_true(RigTree._warned_missing.has("death"), "and is reported")
	var bare := AnimationPlayer.new()
	assert_eq(RigTree._resolve_clip(bare, "run"), "run", "with no idle either the name is left alone")
	var tree := RigTree.build_tree(player)
	assert_true(tree.tree_root is AnimationNodeStateMachine, "the tree still builds")
	tree.free()
	player.free()
	bare.free()

func _test_asset_manifest_merge() -> void:
	var merged := AssetOverlayScript.merge_manifests(
		{"meshes": {"a": "pub_a", "b": "pub_b"}, "textures": {"t": "pub_t"}},
		{"meshes": {"b": "priv_b", "c": "priv_c"}, "junk": 5})
	assert_eq(merged["meshes"], {"a": "pub_a", "b": "priv_b", "c": "priv_c"}, "private overrides by key, public-only keys survive")
	assert_eq(merged["textures"], {"t": "pub_t"}, "a kind only the public manifest lists survives")
	assert_false(merged.has("junk"), "a non-dictionary section is ignored")
	assert_eq(AssetOverlayScript.merge_manifests({}, {}), {}, "two empty manifests merge to empty")
	assert_eq(AssetOverlay.first_key("meshes", ["models/nope.glb.raw", "models/placeholder_rig.glb.raw"]),
		"models/placeholder_rig.glb.raw", "first_key skips unlisted keys")
	assert_eq(AssetOverlay.first_key("meshes", ["models/nope.glb.raw"]), "", "and is empty when none is listed")

func _test_tree_spawn_for_chunk() -> void:
	var t := _make_tree_slice()
	t.spawn_for_chunk(Vector2i(0, 0))
	var trees: Array = t.get_all_trees()
	assert_eq(trees.size(), 8, "the default temperate biome grants 8 trees per chunk")
	var tiles := {}
	for tree in trees:
		assert_eq(str(tree["species"]), "Thornwood", "the temperate biome grows Thornwood")
		assert_eq(str(tree["wood"]), "Thornwood", "a temperate tree yields Thornwood")
		assert_eq(str(tree["state"]), "standing", "a fresh tree is standing")
		tiles["%.2f,%.2f" % [tree["position"].x, tree["position"].z]] = true
	assert_eq(tiles.size(), trees.size(), "every tree lands on its own spot")
	t.free()

func _test_tree_per_biome_table() -> void:
	var t := _make_tree_slice()
	assert_eq(int(t.tree_entry_for_biome("TemperateForest")["per_chunk"]), 8, "temperate forest is wooded (prose weight 0.8)")
	assert_eq(int(t.tree_entry_for_biome("TemperateGrassland")["per_chunk"]), 2, "grassland grows only isolated copses (prose 0.1)")
	assert_eq(str(t.tree_entry_for_biome("TwilightGrove")["wood"]), "Duskfiber", "twilight trees yield Duskfiber")
	assert_true(t.tree_entry_for_biome("VolcanicBadlands").is_empty(), "the volcanic badlands grow no trees")
	assert_true(t.tree_entry_for_biome("VoidRift").is_empty(), "the void rift grows no trees")
	t.free()

func _test_tree_chop_yields_wood_and_wears_axe() -> void:
	var t := _make_tree_slice()
	var inv := InventorySlice.new()
	add_child(inv)
	inv.add_item("CarpenterAxe", 1)
	t.inventory_slice = inv
	t.spawn_for_chunk(Vector2i(0, 0))
	var tid: String = str(t.get_all_trees()[0]["tree_id"])
	var wear_before: float = float(inv.get_durability_data()["CarpenterAxe"][0])
	var result: Dictionary = t.chop_tree(tid)
	assert_true(result["success"], "a chop succeeds while an axe is held")
	assert_eq(str(result["wood"]), "Thornwood", "the chop reports the wood felled")
	assert_eq(inv.get_item_count("Thornwood"), 2, "the wood lands in the inventory")
	var tree: Dictionary = t.get_tree_record(tid)
	assert_eq(str(tree["state"]), "stump", "a chopped tree becomes a stump")
	assert_true(float(tree["respawn_at"]) > 0.0, "a regrowth deadline is set")
	var wear_after: float = float(inv.get_durability_data()["CarpenterAxe"][0])
	assert_true(wear_after < wear_before, "chopping wears the axe (%.2f -> %.2f)" % [wear_before, wear_after])
	t.free()
	inv.free()

func _test_tree_chop_requires_axe() -> void:
	var t := _make_tree_slice()
	var inv := InventorySlice.new()
	add_child(inv)
	t.inventory_slice = inv
	t.spawn_for_chunk(Vector2i(0, 0))
	var tid: String = str(t.get_all_trees()[0]["tree_id"])
	var bare: Dictionary = t.chop_tree(tid)
	assert_false(bare["success"], "a bare-handed chop is refused")
	assert_eq(str(bare["reason"]), "axe_required", "the refusal names the missing axe")
	assert_eq(str(t.get_tree_record(tid)["state"]), "standing", "a refused chop leaves the tree standing")
	# The fabric's toolType is the discriminator: a pick is not an axe.
	inv.add_item("FerritePick", 1)
	assert_eq(str(t.chop_tree(tid)["reason"]), "axe_required", "a pick does not fell a tree")
	assert_eq(inv.get_item_count("Thornwood"), 0, "a refused chop yields no wood")
	t.free()
	inv.free()

func _test_tree_stump_regrows_on_cooldown() -> void:
	var t := _make_tree_slice()
	var inv := InventorySlice.new()
	add_child(inv)
	inv.add_item("CarpenterAxe", 1)
	t.inventory_slice = inv
	t.spawn_for_chunk(Vector2i(0, 0))
	var tid: String = str(t.get_all_trees()[0]["tree_id"])
	t.chop_tree(tid)
	assert_eq(str(t.chop_tree(tid)["reason"]), "not_standing", "a stump cannot be chopped twice")
	# Drive the deadline into the past — regrowth is wall-clock gated.
	t._trees[tid]["respawn_at"] = Time.get_unix_time_from_system() - 1.0
	t._tick_respawn()
	var tree: Dictionary = t.get_tree_record(tid)
	assert_eq(str(tree["state"]), "standing", "the stump regrows after the cooldown")
	assert_eq(float(tree["respawn_at"]), -1.0, "the regrowth deadline clears")
	assert_true(t.chop_tree(tid)["success"], "a regrown tree can be chopped again")
	t.free()
	inv.free()

func _test_tree_despawn_is_per_chunk() -> void:
	var t := _make_tree_slice()
	t.spawn_for_chunk(Vector2i(0, 0))
	t.spawn_for_chunk(Vector2i(1, 0))
	assert_eq(t.get_all_trees().size(), 16, "two chunks carry their own budgets")
	assert_eq(t.trees_in_chunk(Vector2i(1, 0)).size(), 8, "chunk (1,0) owns 8 trees")
	t.despawn_for_chunk(Vector2i(1, 0))
	assert_eq(t.get_all_trees().size(), 8, "despawning a chunk removes only its trees")
	t.spawn_for_chunk(Vector2i(1, 0))
	assert_eq(t.trees_in_chunk(Vector2i(1, 0)).size(), 8, "a chunk reload restores its budget")
	# The chunk index agrees with a full scan, and a re-spawn never doubles the budget.
	t.spawn_for_chunk(Vector2i(1, 0))
	var scanned := 0
	for rec in t.get_all_trees():
		if rec["chunk"] == Vector2i(1, 0):
			scanned += 1
	assert_eq(t.trees_in_chunk(Vector2i(1, 0)).size(), scanned, "chunk index matches a full scan")
	assert_eq(scanned, 8, "re-spawning a loaded chunk adds no trees")
	t.despawn_for_chunk(Vector2i(1, 0))
	assert_eq(t.trees_in_chunk(Vector2i(1, 0)).size(), 0, "despawn empties the chunk index")
	t.free()

func _test_tree_chunk_hop_keeps_stump_cooldown() -> void:
	var t := _make_tree_slice()
	var inv := InventorySlice.new()
	add_child(inv)
	inv.add_item("CarpenterAxe", 1)
	t.inventory_slice = inv
	var chunk := Vector2i(0, 0)
	t.spawn_for_chunk(chunk)
	var tid: String = str(t.trees_in_chunk(chunk)[0])
	t.chop_tree(tid)
	var deadline: float = float(t.get_tree_record(tid)["respawn_at"])
	t.despawn_for_chunk(chunk)
	t.spawn_for_chunk(chunk)
	var back: Dictionary = t.get_tree_record(tid)
	assert_eq(str(back["state"]), "stump", "a stump is still a stump after the chunk reloads")
	assert_eq(float(back["respawn_at"]), deadline, "the original regrowth deadline survives the hop")
	assert_true(t.index_is_consistent(), "index consistent after the stump reload")
	# A deadline that passed while unloaded just means a standing tree.
	t.chop_tree(tid) # already a stump: no-op
	t.despawn_for_chunk(chunk)
	t._stump_memory[tid] = Time.get_unix_time_from_system() - 5.0
	t.spawn_for_chunk(chunk)
	assert_eq(str(t.get_tree_record(tid)["state"]), "standing", "an expired stump reloads standing")
	assert_false(t._stump_memory.has(tid), "the memory entry is consumed on reload")
	t.free()
	inv.free()

func _test_tree_shrinking_budget_reconciles() -> void:
	var t := _make_tree_slice()
	var chunk := Vector2i(0, 0)
	t.spawn_for_chunk(chunk)
	var budget: int = t.trees_in_chunk(chunk).size()
	assert_true(budget >= 2, "fixture chunk carries at least two trees")
	# Pretend a previous visit saw a bigger budget: an extra tree past the current one.
	t._spawn("Thornwood", "Thornwood", chunk, budget)
	assert_eq(t.trees_in_chunk(chunk).size(), budget + 1, "surplus tree injected")
	t.spawn_for_chunk(chunk)
	assert_eq(t.trees_in_chunk(chunk).size(), budget, "re-spawn trims trees past the budget")
	assert_false(t._trees.has(t._tree_id(chunk, budget)), "the surplus record is gone")
	# A hole in the id range is refilled rather than shifting indices.
	var hole: String = t._tree_id(chunk, 0)
	t._by_chunk[chunk].erase(hole)
	t._remove_tree(hole, false)
	t.spawn_for_chunk(chunk)
	assert_true(t._trees.has(hole), "a missing spawn index is refilled")
	assert_eq(t.trees_in_chunk(chunk).size(), budget, "budget restored exactly")
	assert_true(t.index_is_consistent(), "index consistent after reconciling")
	t.free()

func _test_tree_index_is_consistent() -> void:
	var t := _make_tree_slice()
	assert_true(t.index_is_consistent(), "an empty slice is consistent")
	t.spawn_for_chunk(Vector2i(0, 0))
	t.spawn_for_chunk(Vector2i(1, 0))
	assert_true(t.index_is_consistent(), "consistent after spawning")
	var tid: String = str(t.trees_in_chunk(Vector2i(0, 0))[0])
	t._trees[tid]["chunk"] = Vector2i(9, 9)
	assert_false(t.index_is_consistent(), "a record filed under the wrong chunk is caught")
	t._trees[tid]["chunk"] = Vector2i(0, 0)
	t._trees[tid]["state"] = "stump"
	assert_false(t.index_is_consistent(), "a stump missing from the stump set is caught")
	t._trees[tid]["state"] = "standing"
	t.despawn_for_chunk(Vector2i(0, 0))
	assert_true(t.index_is_consistent(), "consistent after despawn")
	t.free()

func _test_tree_client_forwards_then_applies_host_chop() -> void:
	var t := _make_tree_slice()
	t.spawn_for_chunk(Vector2i(0, 0))
	var tid: String = str(t.get_all_trees()[0]["tree_id"])
	var forwarded := {}
	var listener := func(id, _pid): forwarded["id"] = id
	GameBus.tree_chop_requested.connect(listener)
	t.is_authoritative = false
	var result: Dictionary = t.chop_tree(tid)
	assert_eq(str(result["reason"]), "forwarded", "a client forwards the chop instead of resolving it")
	assert_eq(str(forwarded.get("id", "")), tid, "the forwarded intent carries the tree id")
	assert_eq(str(t.get_tree_record(tid)["state"]), "standing", "a client never chops locally")
	# The host's authoritative chop arrives on the bus.
	GameBus.tree_chopped.emit(tid, "Thornwood", "stump", 12345.0)
	var chopped: Dictionary = t.get_tree_record(tid)
	assert_eq(str(chopped["state"]), "stump", "the client applies the host's chop")
	assert_eq(float(chopped["respawn_at"]), 12345.0, "the host's regrowth deadline is kept")
	# A client never regrows on its own clock.
	t._process(600.0)
	assert_eq(str(t.get_tree_record(tid)["state"]), "stump", "a client does not run the regrowth tick")
	GameBus.tree_chop_requested.disconnect(listener)
	t.free()

## The tree id is the ONLY identity the wire carries (tree_chop_intent /
## tree_chopped / tree_respawned all name a tree by it), and placement is
## deterministic so no snapshot carries it. Peers that stream their chunks in a
## different order must therefore still agree on it.
func _test_tree_ids_agree_across_peer_spawn_order() -> void:
	var host := _make_tree_slice()
	var client := _make_tree_slice()
	host.spawn_for_chunk(Vector2i(0, 0))
	host.spawn_for_chunk(Vector2i(1, 0))
	# The client seeds the same two chunks in the opposite order (its own
	# streaming raced ahead of the host's snapshot, say).
	client.spawn_for_chunk(Vector2i(1, 0))
	client.spawn_for_chunk(Vector2i(0, 0))
	var host_ids: Array = host.trees_in_chunk(Vector2i(0, 0))
	var client_ids: Array = client.trees_in_chunk(Vector2i(0, 0))
	host_ids.sort()
	client_ids.sort()
	assert_eq(client_ids, host_ids, "both peers name a chunk's trees identically")
	# …so a broadcast chop resolves on the client instead of being dropped.
	var tid: String = str(host_ids[0])
	assert_eq(client.get_tree_record(tid).get("position", Vector3.ZERO),
		host.get_tree_record(tid).get("position", Vector3.ZERO),
		"the id names the same tree on both peers")
	host.free()
	client.free()

## A reloaded chunk respawns its trees from scratch, so the id must derive from
## the deterministic placement inputs rather than from spawn order — otherwise a
## chop broadcast naming a tree harvested before the reload resolves to nothing
## (apply_chop_state / _on_tree_respawned silently ignore an unknown id).
func _test_tree_ids_survive_chunk_reload() -> void:
	var t := _make_tree_slice()
	t.spawn_for_chunk(Vector2i(0, 0))
	t.spawn_for_chunk(Vector2i(1, 0))   # an unrelated chunk spawned after it
	var before: Array = t.trees_in_chunk(Vector2i(0, 0))
	before.sort()
	t.despawn_for_chunk(Vector2i(0, 0))
	t.spawn_for_chunk(Vector2i(0, 0))
	var after: Array = t.trees_in_chunk(Vector2i(0, 0))
	after.sort()
	assert_eq(after, before, "a reloaded chunk restores the same tree ids")
	t.free()

## The chop HUD label reads the aimed trunk's species off its collision body, so
## the body must actually carry it (PlayerSlice: get_meta("species")).
func _test_tree_trunk_body_carries_its_identity() -> void:
	var t := _make_tree_slice()
	t.spawn_for_chunk(Vector2i(0, 0))
	var tree: Dictionary = t.get_all_trees()[0]
	var body = tree["body"]
	assert_true(body != null, "a rendered tree builds a trunk collision body")
	assert_eq(str(body.get_meta("tree_id", "")), str(tree["tree_id"]), "the trunk carries its tree id")
	assert_eq(str(body.get_meta("species", "")), str(tree["species"]), "the trunk carries its species (the chop HUD label reads it)")
	t.free()

func _test_asset_placeholder_resolves() -> void:
	assert_true(FileAccess.file_exists(AssetOverlay.PLACEHOLDER_PATH),
		"canonical placeholder exists at %s" % AssetOverlay.PLACEHOLDER_PATH)

## Recursively scans every committed .gd file under res://src for string
## literals that only make sense against the private assets-prod submodule —
## i.e. paths/URLs that would only resolve on a machine with that private
## remote checked out, defeating the public-clone acceptance criterion.
func _test_asset_no_private_paths_hardcoded() -> void:
	const FORBIDDEN := [
		"res://assets-prod",
		"assets-prod/",
		"git@github.com",
		"Tubaleviao/project-nihon-assets",
	]
	var violations: Array[String] = []
	_scan_dir_for_forbidden_strings("res://src", FORBIDDEN, violations)
	assert_eq(violations.size(), 0,
		"no private-only path/URL hardcoded in src/ (found: %s)" % ", ".join(violations))

## Proves the production-override mechanism actually works end to end: packs
## a fixture .pck with PCKPacker (the same primitive `--export-pack` uses
## under the hood), mounts it exactly as AssetOverlay._mount_production_pack
## does, and asserts AssetOverlay.resolve_path now serves the overlaid bytes
## instead of falling back to the public placeholder — not just that the
## constants involved look right.
func _test_asset_pck_round_trip_override() -> void:
	const REL := "round_trip_probe/sample.raw"
	var overlay_path := AssetOverlay.OVERLAY_PREFIX + REL

	assert_false(FileAccess.file_exists(overlay_path),
		"probe path is not present before any fixture pck is mounted")
	assert_eq(AssetOverlay.resolve_path(REL), "res://assets/" + REL,
		"resolve_path falls back to the public placeholder prefix pre-mount")

	var payload := "OVERLAY_CONTENT_ROUND_TRIP_PROBE".to_utf8_buffer()
	var src_path := "user://_rt_probe_src.raw"
	var src_file := FileAccess.open(src_path, FileAccess.WRITE)
	src_file.store_buffer(payload)
	src_file.close()

	var fixture_path := "user://_rt_probe_fixture.pck"
	var packer := PCKPacker.new()
	var err := packer.pck_start(fixture_path)
	assert_eq(err, OK, "PCKPacker.pck_start succeeds (err=%s)" % error_string(err))
	err = packer.add_file(overlay_path, src_path)
	assert_eq(err, OK, "PCKPacker.add_file succeeds (err=%s)" % error_string(err))
	err = packer.flush()
	assert_eq(err, OK, "PCKPacker.flush writes the fixture pck (err=%s)" % error_string(err))

	var mounted := ProjectSettings.load_resource_pack(fixture_path, true)
	assert_true(mounted, "fixture pck mounts over res://")

	assert_true(FileAccess.file_exists(overlay_path),
		"overlay path exists once the fixture pck is mounted")

	var resolved := AssetOverlay.resolve_path(REL)
	assert_eq(resolved, overlay_path,
		"resolve_path now prefers the mounted overlay over the public placeholder")

	var read_back := FileAccess.get_file_as_bytes(resolved)
	assert_eq(read_back, payload,
		"bytes read back through resolve_path match what the fixture pck actually shipped")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(src_path))

# ---------------------------------------------------------------------------
# Trade slice tests (Phase 24)
# ---------------------------------------------------------------------------

func _test_asset_manifest_keys_exist() -> void:
	for kind in ["textures", "meshes", "animations"]:
		assert_true(AssetOverlay.keys(kind).size() > 0, "manifest has %s keys" % kind)
		for k in AssetOverlay.keys(kind):
			assert_true(FileAccess.file_exists(AssetOverlay.resolve_path(k)),
				"manifest %s key %s resolves to a file" % [kind, k])
	assert_false(AssetOverlay.has_key("meshes", "models/nope.glb.raw"), "unlisted key absent")

func _test_asset_load_mesh_and_animation() -> void:
	var mesh := AssetOverlay.load_mesh("models/placeholder_rig.glb.raw")
	assert_true(mesh != null and mesh.get_surface_count() > 0, "load_mesh returns a real Mesh")
	var lib := AssetOverlay.load_animation_library("models/placeholder_rig.glb.raw")
	assert_true(lib.has_animation("idle"), "load_animation_library returns the idle clip")

## Issue #112 — the public placeholder rig IS the avatar a fresh clone renders:
## `game_root._finish_host_boot` calls `CharacterSlice.attach_default_rig`, which
## tries `models/player_rig.glb.raw` first and this key second (now that the public
## manifest lists a player rig placeholder, this one renders only when a manifest leaves
## `player_rig` out), and `attach_rig` HIDES the procedural box body on success. The placeholder used to
## be a SINGLE 1x1 TRIANGLE in the XY plane — flat and single-sided, so a public clone
## showed nothing from behind and a gray sliver from the front: the player's own
## character was invisible. A rig that stands in for the player must be a BODY —
## several parts, human height, thickness on BOTH horizontal axes (so it renders from
## any angle, unlike a flat card), feet on the root's ground plane, and every clip the
## locomotion tree asks for so a fresh clone logs no "[RigTree] rig has no …".
func _test_asset_placeholder_rig_is_a_body() -> void:
	const RigTree := preload("res://src/character/rig_tree.gd")
	var root := AssetOverlay.load_rig_scene("models/placeholder_rig.glb.raw")
	assert_true(root != null, "the placeholder rig parses into a scene")
	if root == null:
		return
	var parts: Array = []
	_collect_mesh_instances(root, parts)
	assert_true(parts.size() >= 5, "the placeholder rig is a body of several parts (%d)" % parts.size())
	var box := AABB()
	var first := true
	for part in parts:
		var mi: MeshInstance3D = part
		var local := mi.transform * mi.get_aabb()
		if first:
			box = local
			first = false
		else:
			box = box.merge(local)
	assert_true(box.size.y >= 1.0, "the body is human-scale tall (%.2f m)" % box.size.y)
	assert_true(box.size.x > 0.1 and box.size.z > 0.1,
		"the body has thickness on BOTH horizontal axes (%.2f x %.2f) — a flat quad reads as invisible edge-on" % [box.size.x, box.size.z])
	assert_true(box.position.y > -0.05 and box.position.y < 0.15,
		"the feet sit on the rig root's ground plane (min y %.2f)" % box.position.y)
	var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_true(player != null, "the rig carries an AnimationPlayer")
	if player != null:
		# Node names in the tree are the lowercase state names, so this is exactly what
		# RigTree._resolve_clip looks up — one miss and the clone warns and plays idle.
		for state in Locomotion.State.values():
			var clip: String = Locomotion.State.keys()[state].to_lower()
			assert_true(player.has_animation(clip), "the placeholder rig ships the '%s' clip" % clip)
		# Free the tree: it is a Node with no parent, and an orphan Node leaks to process
		# exit (measured — the suite's teardown rule is the note after `_run_tests`, and
		# both other `build_tree` callers free theirs the same way).
		var tree := RigTree.build_tree(player)
		assert_true(tree.tree_root != null, "the locomotion tree builds off the placeholder's clips")
		tree.free()
	root.free()

## Asset roadmap A2: `models/player_rig.glb.raw` is the key the private player rig
## overrides, so its public placeholder carries the art's contract (assets/README.md,
## "The placeholder rule"): a skeleton whose bones are the fabric HumanoidSkeleton's,
## names and parents exactly, rest axes in the art's convention (a bone's +Y points at
## its only child), a skin bound at those rests, every clip the locomotion tree plays,
## a human-height body standing on the root's ground plane. Code that reads bones then
## works on a public clone exactly as on the art.
func _test_asset_player_rig_placeholder_contract() -> void:
	var root := AssetOverlay.load_rig_scene("models/player_rig.glb.raw")
	assert_true(root != null, "the player rig placeholder parses into a scene")
	if root == null:
		return
	var skeletons := root.find_children("*", "Skeleton3D", true, false)
	var skeleton: Skeleton3D = skeletons[0] if skeletons.size() == 1 else null
	assert_true(skeleton != null, "the player rig carries a Skeleton3D")
	if skeleton != null:
		var bones: Array = GameDataReader.json_field(GameData.SKELETONS["HumanoidSkeleton"], "bones", [])
		assert_eq(skeleton.get_bone_count(), bones.size(), "one bone per fabric HumanoidSkeleton bone")
		for b in bones:
			var idx := skeleton.find_bone(str(b["name"]))
			assert_true(idx >= 0, "bone %s is in the rig" % b["name"])
			if idx >= 0:
				var parent := skeleton.get_bone_parent(idx)
				assert_eq(skeleton.get_bone_name(parent) if parent >= 0 else "", str(b["parent"]),
					"bone %s has its fabric parent" % b["name"])
		for idx in skeleton.get_bone_count():
			var kids := skeleton.get_bone_children(idx)
			if kids.size() == 1:
				var along := skeleton.get_bone_rest(kids[0]).origin
				assert_true(along.length() > 0.01 and along.normalized().y > 0.99,
					"bone %s points its +Y at its child, as the art's bones do (%s)" % [skeleton.get_bone_name(idx), along])
	var parts: Array = []
	_collect_mesh_instances(root, parts)
	assert_true(parts.size() > 0, "the player rig has a mesh")
	var box := AABB()
	for i in parts.size():
		var mi: MeshInstance3D = parts[i]
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != root and n is Node3D:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var local := xf * mi.get_aabb()
		box = local if i == 0 else box.merge(local)
		# Each bind pose must undo its bone's global rest, or the body renders offset.
		if skeleton != null and mi.skin != null:
			assert_eq(mi.skin.get_bind_count(), skeleton.get_bone_count(), "one skin bind per bone")
			for bi in mi.skin.get_bind_count():
				var bone := mi.skin.get_bind_bone(bi)
				if bone < 0:
					bone = skeleton.find_bone(mi.skin.get_bind_name(bi))
				var err := mi.skin.get_bind_pose(bi) * skeleton.get_bone_global_rest(bone)
				assert_true(err.basis.is_equal_approx(Basis.IDENTITY) and err.origin.length() < 0.001,
					"bind %d (bone %s) inverts the bone's rest" % [bi, skeleton.get_bone_name(bone)])
	assert_true(box.size.y >= 1.5 and box.size.y <= 1.9, "the body is 1.5-1.9 m tall (%.2f m)" % box.size.y)
	assert_true(absf(box.position.y) <= 0.02, "the feet sit on the ground plane (min y %.3f)" % box.position.y)
	assert_true(box.size.x > 0.1 and box.size.z > 0.1, "the body has thickness on both horizontal axes")
	var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_true(player != null, "the player rig carries an AnimationPlayer")
	if player != null:
		for state in Locomotion.State.values():
			var clip: String = Locomotion.State.keys()[state].to_lower()
			assert_true(player.has_animation(clip), "the player rig ships the '%s' clip" % clip)
	root.free()

## The public body sheets stand in for the player rig's authored ones: same image
## size (64x64, the art's). The masks are all-black opaque so a public clone renders
## base colour with no channel, and the detail sheet all-white opaque so it multiplies
## by one, exactly as the shader does with nothing bound. Reads the committed
## placeholder itself, not whatever a mounted pack overlays.
func _test_asset_body_sheet_placeholders() -> void:
	var expected := {
		"textures/characters/player_color_mask.png.raw": Color(0, 0, 0, 1),
		"textures/characters/player_channel.png.raw": Color(0, 0, 0, 1),
		"textures/characters/player.png.raw": Color(1, 1, 1, 1),
	}
	for key: String in expected:
		assert_true(AssetOverlay.has_key("textures", key), "manifest lists %s" % key)
		var img := Image.new()
		var err := img.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/" + key))
		assert_eq(err, OK, "%s decodes as PNG" % key)
		if err != OK:
			continue
		assert_eq(img.get_size(), Vector2i(64, 64), "%s is 64x64 like the art" % key)
		var uniform := true
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y) != expected[key]:
					uniform = false
					break
			if not uniform:
				break
		assert_true(uniform, "%s is opaque %s, as unbound" % [key, expected[key]])

## Phase 123 (#314): an attached rig wears the character shader, with the three body sheets bound
## by key, through one rig material shared by every character and kept apart from the capsules'.
func _test_rig_wears_character_material() -> void:
	const CharacterMaterial := preload("res://src/character/character_material.gd")
	var ch := CharacterSlice.new()
	add_child(ch)
	var a := ch.create_character_from_recipe({"skeleton": "HumanoidSkeleton", "skinColor": 10}, Vector3.ZERO)
	var b := ch.create_character_from_recipe({"skeleton": "HumanoidSkeleton", "skinColor": 77}, Vector3.ZERO)
	assert_true(ch.attach_rig(a, "models/player_rig.glb.raw"), "rig a attaches")
	assert_true(ch.attach_rig(b, "models/player_rig.glb.raw"), "rig b attaches")
	var mat := CharacterMaterial.rig_material(ch._palette_colors())
	assert_true(mat != CharacterMaterial.shared_material(ch._palette_colors()), "the rig material is not the capsules' one")
	assert_eq(mat.shader, CharacterMaterial.SHADER, "the rig material runs the character shader")
	for pair in [["detail_tex", CharacterSlice.RIG_DETAIL_KEY], ["color_mask_tex", CharacterSlice.RIG_COLOR_MASK_KEY],
			["channel_tex", CharacterSlice.RIG_CHANNEL_KEY]]:
		assert_true(mat.get_shader_parameter(pair[0]) is Texture2D, "%s is bound from %s" % pair)
		assert_true(AssetOverlay.has_key("textures", pair[1]), "%s is a listed key" % pair[1])
	# Every mesh of each rig, not the last one found (#331).
	for pair in [[a, 10], [b, 77]]:
		var meshes: Array = ch._instances[pair[0]]["rig_node"].find_children("*", "MeshInstance3D", true, false)
		assert_true(meshes.size() > 0, "the rig has a mesh")
		for m in meshes:
			assert_true((m as MeshInstance3D).material_override == mat, "every rig mesh carries the rig material")
			assert_eq((m as MeshInstance3D).get_instance_shader_parameter("base_index"), pair[1], "every mesh of the rig carries its character's skin index as an instance parameter")
	# The capsules keep the shared material.
	var body: Node3D = ch._instances[a]["root"]
	var capsule_mats := 0
	for m in body.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.material_override == CharacterMaterial.shared_material(ch._palette_colors()):
			capsule_mats += 1
		assert_true(mi.material_override != null, "no mesh renders with the default material")
	assert_true(capsule_mats > 0, "the procedural parts still use shared_material")
	# An appearance change re-applies the indices on the rebuilt rig.
	ch.apply_appearance(a, {"skeleton": "HumanoidSkeleton", "skinColor": 33, "hairColor": 5, "eyeColor": 6, "beardColor": 7})
	var rebuilt: Array = ch._instances[a]["rig_node"].find_children("*", "MeshInstance3D", true, false)
	assert_true(rebuilt.size() > 0, "the rebuilt rig has meshes")
	for m in rebuilt:
		var mi := m as MeshInstance3D
		assert_eq(mi.get_instance_shader_parameter("base_index"), 33, "a new appearance re-applies the skin index on every mesh")
		assert_eq(mi.get_instance_shader_parameter("primary_index"), 5, "hairColor feeds the primary mask region")
		assert_eq(mi.get_instance_shader_parameter("secondary_index"), 6, "eyeColor feeds the secondary mask region")
		assert_eq(mi.get_instance_shader_parameter("accent_index"), 7, "beardColor feeds the accent mask region")
	# #331: the material is built once but follows the palette; the textures are not rebound on an attach.
	var palette_before: Texture2D = mat.get_shader_parameter("palette_tex")
	var palette_data := palette_before.get_image().get_data()
	var other := CharacterMaterial.rig_material([Color.RED, Color.BLUE])
	assert_true(other == mat and other.get_shader_parameter("palette_tex") != palette_before, "a different palette reaches the existing rig material")
	CharacterMaterial.rig_material(ch._palette_colors())
	assert_eq((mat.get_shader_parameter("palette_tex") as Texture2D).get_image().get_data(), palette_data, "and the original palette's colours come back")
	var tex_detail: Variant = mat.get_shader_parameter("detail_tex")
	CharacterMaterial.bind_rig_textures(mat, tex_detail, mat.get_shader_parameter("color_mask_tex"), mat.get_shader_parameter("channel_tex"))
	assert_true(mat.get_shader_parameter("detail_tex") == tex_detail, "binding the same sheets again changes nothing")
	# The placeholder masks are black, so the shader's colour inputs reduce to base_index.
	for key in [CharacterSlice.RIG_COLOR_MASK_KEY, CharacterSlice.RIG_CHANNEL_KEY]:
		var img := (mat.get_shader_parameter("color_mask_tex" if key == CharacterSlice.RIG_COLOR_MASK_KEY else "channel_tex") as Texture2D).get_image()
		var black := true
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y) != Color(0, 0, 0, 1):
					black = false
		assert_true(black, "%s is all black, so colour reduces to base_index" % key)
	ch.free()

## Phase 123 (#321): the wolf rig's scene root is named for the wolf, and the serpent's `fall` clip
## curls (distinct keys); `gen_placeholder_glb.py` regenerates the committed files byte for byte
## (the byte-identical check is `python3 tools/gen_placeholder_glb.py && git diff --exit-code assets`).
func _test_asset_rig_root_names_and_fall_clip() -> void:
	var wolf := AssetOverlay.load_rig_scene(AssetOverlayScript.creature_model_key("GraywolfPack"))
	assert_true(wolf != null, "wolf rig loads")
	if wolf != null:
		assert_true(wolf.get_node_or_null("PlayerRig") == null, "the wolf rig's root is not named PlayerRig")
		assert_true(wolf.get_node_or_null("WolfRig") != null, "the wolf rig's root is named WolfRig")
		wolf.free()
	var player := AssetOverlay.load_rig_scene("models/player_rig.glb.raw")
	assert_true(player != null and player.get_node_or_null("PlayerRig") != null, "the player rig keeps its name")
	if player != null:
		player.free()
	var serpent := AssetOverlay.load_rig_scene(AssetOverlayScript.creature_model_key("VoidSerpent"))
	assert_true(serpent != null, "serpent rig loads")
	if serpent != null:
		var ap := serpent.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var fall: Animation = ap.get_animation("fall") if ap != null and ap.has_animation("fall") else null
		assert_true(fall != null, "the serpent has a fall clip")
		if fall != null:
			var distinct := false
			for t in fall.get_track_count():
				var first: Variant = fall.track_get_key_value(t, 0)
				for k in fall.track_get_key_count(t):
					if fall.track_get_key_value(t, k) != first:
						distinct = true
			assert_true(distinct, "the serpent fall clip has at least two distinct keys")
		serpent.free()

## Issue #319 / Phase 152: every item in `GameData.ITEMS` has a 32x32 RGBA icon, drawn by
## `tools/gen_item_assets.py`: transparent corners, real content, never the same pixels twice.
func _test_asset_item_icon_placeholders() -> void:
	var seen := {}
	for id: String in GameData.ITEMS:
		var key := UiSlice.item_icon_key(id)
		var path := "res://assets/" + key
		assert_true(FileAccess.file_exists(path), "icon placeholder %s exists" % key)
		var img := Image.new()
		var err := img.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
		assert_eq(err, OK, "%s decodes as PNG" % key)
		if err != OK:
			continue
		assert_eq(img.get_size(), Vector2i(32, 32), "%s is 32x32" % key)
		assert_eq(img.get_format(), Image.FORMAT_RGBA8, "%s is RGBA" % key)
		for corner in [Vector2i(0, 0), Vector2i(31, 0), Vector2i(0, 31), Vector2i(31, 31)]:
			assert_eq(img.get_pixelv(corner).a, 0.0, "%s corner %s is transparent" % [key, corner])
		var opaque := 0
		for y in 32:
			for x in 32:
				if img.get_pixel(x, y).a > 0.5:
					opaque += 1
		assert_true(opaque > 40, "%s has more than 40 opaque pixels (%d)" % [key, opaque])
		var digest := img.get_data().hex_encode()
		assert_false(seen.has(digest), "%s is not byte-identical to %s" % [key, seen.get(digest, "")])
		seen[digest] = id

## Phase 152: every item has a model that parses, has a `grip` node, stays within the triangle
## budget and its archetype's bounds, and no file exists for an id that is not an item.
func _test_asset_item_models() -> void:
	var lock: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/items/shapes.lock.json"))
	var budget: int = lock["maxTris"]
	for id: String in GameData.ITEMS:
		var key := "models/items/%s.glb.raw" % id
		assert_true(AssetOverlay.has_key("meshes", key), "%s model listed in the manifest" % id)
		assert_true(lock["items"].has(id), "%s is in shapes.lock.json" % id)
		var root := AssetOverlay.load_rig_scene(key)
		assert_true(root != null, "%s model parses through AssetOverlay" % id)
		if root == null:
			continue
		assert_true(root.find_child("grip", true, false) != null, "%s has a grip node" % id)
		var parts: Array = []
		_collect_mesh_instances(root, parts)
		assert_eq(parts.size(), 1, "%s is one mesh" % id)
		if parts.size() == 1 and lock["items"].has(id):
			var mesh: Mesh = parts[0].mesh
			var arrays := mesh.surface_get_arrays(0)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var tris := (indices.size() if indices.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
			assert_true(tris > 0 and tris <= budget, "%s has %d tris (budget %d)" % [id, tris, budget])
			var entry: Dictionary = lock["items"][id]
			var b: Array = lock["archetypeBounds"][entry["archetype"]]
			var size := mesh.get_aabb().size
			var k: float = entry["scale"]
			assert_true(size.x <= b[0] * k + 0.001 and size.y <= b[1] * k + 0.001 and size.z <= b[2] * k + 0.001,
				"%s AABB %s fits %s bounds" % [id, size, entry["archetype"]])
		root.free()
	for dir_and_suffix in [["res://assets/models/items", ".glb.raw"], ["res://assets/icons/items", ".png.raw"]]:
		for file in DirAccess.get_files_at(dir_and_suffix[0]):
			if file.ends_with(dir_and_suffix[1]):
				var id: String = file.trim_suffix(dir_and_suffix[1])
				assert_true(GameData.ITEMS.has(id), "%s/%s is for an item" % [dir_and_suffix[0], file])

## Issue #318: `models/creatures/GraywolfPack.glb.raw` and its three textures stand in
## for the private wolf: a skin on the fabric QuadrupedSkeleton bones, a visible body, and
## the clips the locomotion tree looks up.
func _test_asset_graywolfpack_placeholders() -> void:
	var key := AssetOverlayScript.creature_model_key("GraywolfPack")
	assert_true(AssetOverlay.has_key("meshes", key), "manifest lists the wolf mesh")
	assert_true(AssetOverlay.has_key("animations", key), "manifest lists the wolf animations")
	for tex in ["GraywolfPack", "GraywolfPack_channel", "GraywolfPack_color_mask"]:
		var tkey := "textures/creatures/%s.png.raw" % tex
		assert_true(AssetOverlay.has_key("textures", tkey), "manifest lists %s" % tkey)
		var img := Image.new()
		assert_eq(img.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/" + tkey)), OK,
			"%s decodes as PNG" % tkey)
	var root := AssetOverlay.load_rig_scene(key)
	assert_true(root != null, "the wolf placeholder parses into a scene")
	if root == null:
		return
	var skeletons := root.find_children("*", "Skeleton3D", true, false)
	assert_eq(skeletons.size(), 1, "one Skeleton3D")
	if skeletons.size() == 1:
		var skeleton: Skeleton3D = skeletons[0]
		var bones: Array = GameDataReader.json_field(GameData.SKELETONS["QuadrupedSkeleton"], "bones", [])
		assert_eq(skeleton.get_bone_count(), bones.size(), "one bone per fabric QuadrupedSkeleton bone")
		for b in bones:
			var idx := skeleton.find_bone(str(b["name"]))
			assert_true(idx >= 0, "bone %s is in the rig" % b["name"])
			if idx >= 0:
				var parent := skeleton.get_bone_parent(idx)
				assert_eq(skeleton.get_bone_name(parent) if parent >= 0 else "", str(b["parent"]),
					"bone %s has its fabric parent" % b["name"])
	var parts: Array = []
	_collect_mesh_instances(root, parts)
	assert_true(parts.size() > 0, "the wolf has a mesh")
	root.free()
	var lib := AssetOverlay.load_animation_library(key)
	assert_true(lib != null, "the wolf has an animation library")
	if lib != null:
		for clip in ["idle", "walk", "run", "fall", "land", "attack", "death"]:
			assert_true(lib.has_animation(clip), "wolf clip %s" % clip)

## Issue #322: the nine roster creatures each have a skinned placeholder on their skeleton
## family's fabric bones, seven clips and three textures at the art's size.
func _test_asset_creature_roster_placeholders() -> void:
	var roster := {
		"ForestBoar": ["QuadrupedSkeleton", 128], "SteppeBison": ["QuadrupedSkeleton", 128],
		"GlimmerFox": ["QuadrupedSkeleton", 64], "VeilStalker": ["QuadrupedSkeleton", 64],
		"RiftWarden": ["QuadrupedSkeleton", 128], "RidgeHawk": ["BirdSkeleton", 64],
		"CinderGargoyle": ["BirdSkeleton", 128], "VoidSerpent": ["SerpentSkeleton", 128],
		"LavaSlug": ["SerpentSkeleton", 128],
	}
	for entity: String in roster:
		var family: String = roster[entity][0]
		var size: int = roster[entity][1]
		var key := AssetOverlayScript.creature_model_key(entity)
		assert_true(AssetOverlay.has_key("meshes", key), "%s mesh listed" % entity)
		assert_true(AssetOverlay.has_key("animations", key), "%s animations listed" % entity)
		for suffix in ["", "_channel", "_color_mask"]:
			var tkey := "textures/creatures/%s%s.png.raw" % [entity, suffix]
			assert_true(AssetOverlay.has_key("textures", tkey), "manifest lists %s" % tkey)
			var img := Image.new()
			var err := img.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/" + tkey))
			assert_eq(err, OK, "%s decodes as PNG" % tkey)
			if err == OK:
				assert_eq(img.get_size(), Vector2i(size, size), "%s is %dx%d" % [tkey, size, size])
		var root := AssetOverlay.load_rig_scene(key)
		assert_true(root != null, "%s parses into a scene" % entity)
		if root == null:
			continue
		var skeletons := root.find_children("*", "Skeleton3D", true, false)
		assert_eq(skeletons.size(), 1, "%s has one Skeleton3D" % entity)
		if skeletons.size() == 1:
			var skeleton: Skeleton3D = skeletons[0]
			var bones: Array = GameDataReader.json_field(GameData.SKELETONS[family], "bones", [])
			assert_eq(skeleton.get_bone_count(), bones.size(), "%s: one bone per %s bone" % [entity, family])
			for b in bones:
				var idx := skeleton.find_bone(str(b["name"]))
				assert_true(idx >= 0, "%s: bone %s present" % [entity, b["name"]])
				if idx >= 0:
					var parent := skeleton.get_bone_parent(idx)
					assert_eq(skeleton.get_bone_name(parent) if parent >= 0 else "", str(b["parent"]),
						"%s: bone %s has its fabric parent" % [entity, b["name"]])
		var parts: Array = []
		_collect_mesh_instances(root, parts)
		assert_true(parts.size() > 0, "%s has a mesh" % entity)
		root.free()
		var lib := AssetOverlay.load_animation_library(key)
		assert_true(lib != null, "%s has an animation library" % entity)
		if lib != null:
			for clip in ["idle", "walk", "run", "fall", "land", "attack", "death"]:
				assert_true(lib.has_animation(clip), "%s clip %s" % [entity, clip])

## Issue #325: the five item meshes each have a static placeholder (one textured box under the
## triangle budget) and three sheets at the art's size.
func _test_asset_item_mesh_placeholders() -> void:
	var items := {"CarpenterAxe": 64, "FerritePick": 64, "FerriteShortSword": 32, "FerriteShield": 64,
		"FerriteHelmet": 64}
	for item: String in items:
		var size: int = items[item]
		var mkey := "models/items/%s.glb.raw" % item
		assert_true(AssetOverlay.has_key("meshes", mkey), "%s mesh listed" % item)
		var root := AssetOverlay.load_rig_scene(mkey)
		assert_true(root != null, "%s parses into a scene" % item)
		if root != null:
			var parts: Array = []
			_collect_mesh_instances(root, parts)
			assert_true(parts.size() > 0, "%s has a mesh" % item)
			root.free()
		for suffix in ["", "_channel", "_color_mask"]:
			var tkey := "textures/items/%s%s.png.raw" % [item, suffix]
			assert_true(AssetOverlay.has_key("textures", tkey), "manifest lists %s" % tkey)
			var img := Image.new()
			var err := img.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/" + tkey))
			assert_eq(err, OK, "%s decodes as PNG" % tkey)
			if err == OK:
				assert_eq(img.get_size(), Vector2i(size, size), "%s is %dx%d" % [tkey, size, size])

func _test_asset_missing_model_falls_back() -> void:
	assert_true(AssetOverlay.load_mesh("models/missing.glb.raw") == null, "missing mesh -> null")
	assert_eq(AssetOverlay.load_animation_library("models/missing.glb.raw").get_animation_list().size(), 0,
		"missing animations -> empty library")

func _test_asset_creature_key() -> void:
	assert_eq(AssetOverlayScript.creature_model_key("Wolf"), "models/creatures/Wolf.glb.raw", "creature key")

func _test_rig_tree_state_mapping_total() -> void:
	const RigTree := preload("res://src/character/rig_tree.gd")
	const Loco := preload("res://src/character/locomotion.gd")
	for s in Loco.State.values():
		assert_true(RigTree.node_for_state(s) != "", "state %d maps to a tree node" % s)
	assert_eq(RigTree.node_for_state(Loco.State.IDLE), RigTree.node_for_state(Loco.State.RUN),
		"idle/walk/run share the blend space")
	# The player is a bare Node with no parent, so freeing it is on us: an orphan Node is
	# leaked to process exit (measured — it is the one `Leaked instance: AnimationPlayer`
	# in the boot's exit noise). Same rule `_test_rig_tree_missing_clip_fallback` follows.
	var player := AnimationPlayer.new()
	var tree := RigTree.build_tree(player)
	assert_true(tree.tree_root is AnimationNodeStateMachine, "tree root is a state machine")
	tree.free()
	player.free()

func _test_attach_rig() -> void:
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid := ch.create_character_from_recipe({"skeleton": "HumanoidSkeleton"}, Vector3.ZERO)
	assert_false(ch.attach_rig(iid, "models/nope.glb.raw"), "unlisted key -> false")
	assert_true(ch.attach_rig(iid, "models/placeholder_rig.glb.raw"), "listed key attaches")
	var root: Node3D = ch._instances[iid]["root"]
	var scene := root.get_node_or_null("RigScene")
	assert_true(scene != null and scene.find_child("AnimationPlayer", true, false) != null,
		"rig scene keeps its AnimationPlayer")
	for child in root.get_children():
		if child is Node3D and child.name != "RigScene":
			assert_false((child as Node3D).visible, "procedural body hidden once a rig is attached")
	assert_true((scene as Node3D).visible, "the rig shows at full detail")
	ch.set_lod(CharacterSlice.IMPOSTOR_LOD)
	assert_false((scene as Node3D).visible, "the rig gives way to the billboard at impostor distance")
	assert_true(ch.is_impostor_visible(iid), "and the impostor stands in for it")
	ch.set_lod(CharacterSlice.MIN_LOD)
	assert_true((scene as Node3D).visible, "the rig is back when the camera is")
	assert_false(ch.is_impostor_visible(iid), "and the impostor is gone")
	for child in root.get_children():
		if child is Node3D and child.name != "RigScene":
			assert_false((child as Node3D).visible, "LOD change does not re-show the procedural body")
	assert_true(ch.attach_rig(iid, "models/placeholder_rig.glb.raw"), "second attach is a no-op")
	assert_eq(root.get_children().filter(func(c): return c.name == "RigScene").size(), 1, "no duplicate rig")
	var old_tree: Node = ch._instances[iid]["anim_tree"]
	ch.apply_appearance(iid, {"skeleton": "HumanoidSkeleton"})
	var new_tree: Variant = ch._instances[iid].get("anim_tree", null)
	assert_true(new_tree != null and new_tree != old_tree and is_instance_valid(new_tree),
		"an appearance rebuild re-attaches the rig as a fresh tree, not the freed one")
	var new_root: Node3D = ch._instances[iid]["root"]
	for child in new_root.get_children():
		if child is Node3D and child.name != "RigScene":
			assert_false((child as Node3D).visible, "the rebuilt procedural body stays hidden under the rig")
	# A rebuild at impostor distance attaches the rig already LOD-correct: no frame of a rig
	# showing at a distance only the billboard should cover.
	ch.set_lod(CharacterSlice.IMPOSTOR_LOD)
	ch.apply_appearance(iid, {"skeleton": "HumanoidSkeleton"})
	var far_scene := (ch._instances[iid]["root"] as Node3D).get_node_or_null("RigScene") as Node3D
	assert_true(far_scene != null and not far_scene.visible, "a rig re-attached at impostor distance starts hidden")
	assert_true(ch.is_impostor_visible(iid), "with the billboard shown")
	ch.set_lod(CharacterSlice.MIN_LOD)
	# A character that never wore a rig keeps showing its body across a rebuild.
	var bare := ch.create_character_from_recipe({"skeleton": "HumanoidSkeleton"}, Vector3.ZERO)
	ch.apply_appearance(bare, {"skeleton": "HumanoidSkeleton"})
	assert_false(ch._instances[bare].has("anim_tree"), "no rig is invented by a rebuild")
	var shown := false
	for child in (ch._instances[bare]["root"] as Node3D).get_children():
		if child is Node3D and (child as Node3D).visible:
			shown = true
	assert_true(shown, "a rig-less rebuild leaves the procedural body visible")
	var dflt := ch.create_character_from_recipe({"skeleton": "HumanoidSkeleton"}, Vector3.ZERO)
	assert_true(ch.attach_default_rig(dflt), "the default rig resolves through the manifest")
	assert_eq(ch._instances[dflt]["rig_key"], "models/player_rig.glb.raw", "to the player rig, which the public manifest lists too")
	# A manifest without a player rig falls back to the public placeholder body.
	AssetOverlay._manifest = { "meshes": { "models/placeholder_rig.glb.raw": "models/placeholder_rig.glb.raw" },
		"animations": { "models/placeholder_rig.glb.raw": "models/placeholder_rig.glb.raw" } }
	AssetOverlay._manifest_loaded = true
	var fallback := ch.create_character_from_recipe({"skeleton": "HumanoidSkeleton"}, Vector3.ZERO)
	assert_true(ch.attach_default_rig(fallback), "the default rig falls back when no player rig is listed")
	assert_eq(ch._instances[fallback]["rig_key"], "models/placeholder_rig.glb.raw", "to the public placeholder body")
	AssetOverlay.reload_manifest()
	ch.free()

## Phase 115 (#258) — an exact far position survives all three placement doors: the host's own
## `_place_local_player`, the host's `_snapshot_own_record` (what `_build_snapshot` ships, through JSON) and
## the client's `_place_from_snapshot` (what `_on_world_snapshot_received` calls), within 1e-3 m.
func _test_exact_placement_paths() -> void:
	var root_script: GDScript = load("res://src/core/game_root.gd")
	var chunk := Vector2i(600000, 40)
	var local := Vector3(12.345, 20.0, 6.789)
	var pid := "exact-place"
	var reg := PlayerRegistry.new()
	reg.local_player_id = pid
	reg.record_world_pos(pid, { "chunk": chunk, "local": local })
	# Door 1: `_place_local_player` reads the record and lands on it.
	var host_body := PlayerSlice.new()
	host_body.render_visuals = true
	add_child(host_body)
	var gr: Node = root_script.new()
	gr._player = host_body
	gr._rebase = RebaseDriver.new([host_body])
	gr._registry = reg
	gr._persistence_wiring.place_local_player(Vector3(5.0, 5.0, 5.0))
	var placed := host_body.get_world_pos()
	assert_eq(placed["chunk"], chunk, "_place_local_player lands in the recorded chunk")
	assert_true((placed["local"] as Vector3).distance_to(local) < 1e-3, "and on the recorded local within 1e-3 m")
	# Door 2: the snapshot's own record carries the exact position through a JSON round trip.
	var shipped: Dictionary = JSON.parse_string(JSON.stringify(gr._snapshot_wiring.snapshot_own_record(pid)))
	assert_true(WorldPos.is_wire(shipped["player"]["position"]), "the snapshot's player position is a valid wire record")
	assert_eq(WorldPos.wire_chunk(shipped["player"]["position"]), chunk, "naming the exact chunk")
	# Door 3: a client places itself from that packet with a rebase, not a float detour.
	var client_body := PlayerSlice.new()
	client_body.render_visuals = true
	add_child(client_body)
	var client: Node = root_script.new()
	client._player = client_body
	client._rebase = RebaseDriver.new([client_body])
	client._snapshot_wiring.place_from_snapshot(shipped["player"])
	var landed := client_body.get_world_pos()
	assert_eq(landed["chunk"], chunk, "_place_from_snapshot rebases to the exact chunk")
	assert_true((landed["local"] as Vector3).distance_to(local) < 1e-3, "and lands on the local within 1e-3 m")
	assert_true(client._client_respawn_point_set, "the first snapshot sets the respawn point")
	client._snapshot_wiring.place_from_snapshot("not a record")
	client._snapshot_wiring.place_from_snapshot({ "position": "elsewhere" })
	assert_eq(client_body.get_world_pos()["chunk"], chunk, "a malformed player record moves nobody")
	client_body.free()
	host_body.free()
	client.free()
	gr.free()
	reg.free()

func _test_chunk_set_clock_resets_throttles() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	cm.view_distance = 1
	cm.prefetch_distance = 0
	cm.self_heal_interval = 60.0
	cm.refresh()
	cm._load_queue.clear()
	cm._pending.clear()
	var stub := _StrandedStub.new()
	cm.region_streamer = stub
	var clock := [50000]
	cm.set_clock(func() -> int: return clock[0])
	cm._loaded["0,0"] = true
	cm._failed["0,0"] = true
	cm._build_attempts["0,0"] = cm.MAX_BUILD_RETRIES
	cm.refresh()
	assert_false(cm._failed.has("0,0"), "the first self-heal runs")
	assert_eq(stub.releases, 1, "the first stranded retry runs")
	cm._failed["0,0"] = true
	cm._build_attempts["0,0"] = cm.MAX_BUILD_RETRIES
	cm.refresh()
	assert_true(cm._failed.has("0,0"), "a second self-heal inside the interval is throttled")
	assert_eq(stub.releases, 1, "and so is the stranded retry")
	cm.set_clock(func() -> int: return 0)
	cm.refresh()
	assert_false(cm._failed.has("0,0"), "a fresh clock at 0 lets the self-heal run at once")
	assert_eq(stub.releases, 2, "and the stranded retry")
	cm.region_streamer = null
	for k in ["cm", "voxel", "terrain", "player"]:
		rig[k].free()

func _test_diag_warn_concurrent() -> void:
	var was_quiet := Diag.quiet
	Diag.quiet = true
	var before := Diag.warn_count()
	var job := func(_idx: int) -> void:
		for k in 1000:
			Diag.warn("concurrent warning")
	var gid := WorkerThreadPool.add_group_task(job, 4)
	WorkerThreadPool.wait_for_group_task_completion(gid)
	Diag.quiet = was_quiet
	assert_eq(Diag.warn_count() - before, 4000, "four tasks of 1,000 warnings raise the count by exactly 4,000")


## Phase 147 — a stone placed near the far seam (x ~ 2e7 m) keeps its exact position through a save.
func _test_phase147_waystone_exact_roundtrip() -> void:
	var rig := _waystone_rig()
	var way: WaystoneSlice = rig["way"]
	var st: StationSlice = rig["stations"]
	var far := { "chunk": Vector2i(int(2.0e7 / WorldPos.CHUNK_METERS), 5), "local": Vector3(7.3125, 12.5, 0.0625) }
	var id := st.place_station("waystone", Vector3(0.5, 1.0, 0.5))
	way.note_exact(id, far)
	var saved := way.exact_data()
	way.apply_exact_data({})
	way.apply_exact_data(saved)
	var back := way.exact_pos(id)
	assert_eq(back["chunk"], far["chunk"], "the chunk survives the save")
	assert_true((back["local"] as Vector3).distance_to(far["local"]) < 0.01, "the local offset is exact to under 1 cm")
	_free_waystone_rig(rig)
