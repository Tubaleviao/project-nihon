extends Node
## Self-contained automated test suite.
##
## Each test_* method is discovered and run automatically in _ready().
## Tests use assert_eq / assert_true / assert_false helpers.
## Summary is printed to the Godot output log.
##
## Run from game_root by instantiating this node and calling run().

# Preload slices so tests are isolated from the main scene tree.
const BattleSlice     := preload("res://src/battle/battle_slice.gd")
const CreatureSlice   := preload("res://src/creature/creature_slice.gd")
const CreatureAI      := preload("res://src/creature/creature_ai.gd")
const TerrainSlice    := preload("res://src/terrain/terrain_slice.gd")
const ChunkManager    := preload("res://src/terrain/chunk_manager.gd")
const PersistenceSlice:= preload("res://src/persistence/persistence_slice.gd")
const LootSlice       := preload("res://src/loot/loot_slice.gd")
const InventorySlice  := preload("res://src/inventory/inventory_slice.gd")
const CharacterSlice  := preload("res://src/character/character_slice.gd")
const CraftingSlice   := preload("res://src/crafting/crafting_slice.gd")
const TechnologySlice := preload("res://src/technology/technology_slice.gd")
const UiSlice         := preload("res://src/ui/ui_slice.gd")
const VoxelSlice      := preload("res://src/terrain/voxel_slice.gd")
const StationSlice    := preload("res://src/world/station_slice.gd")
const Minimap         := preload("res://src/ui/minimap.gd")
const PlayerSlice     := preload("res://src/player/player_slice.gd")
const NetworkingSlice := preload("res://src/networking/networking_slice.gd")
const Locomotion      := preload("res://src/character/locomotion.gd")
const SkeletonRig     := preload("res://src/character/skeleton_rig.gd")

var _pass: int = 0
var _fail: int = 0
var _current_test: String = ""

# ---------------------------------------------------------------------------
# Entry
# ---------------------------------------------------------------------------

func run() -> void:
	print("\n╔══════════════════════════════════════╗")
	print("║       Project Nihon — Test Suite     ║")
	print("╚══════════════════════════════════════╝\n")

	_run_test("battle: hit reduces defender hp",              _test_battle_hit_reduces_hp)
	_run_test("battle: miss leaves hp unchanged",             _test_battle_miss_leaves_hp_unchanged)
	_run_test("battle: kill emits creature_died signal",      _test_battle_kill_emits_death)
	_run_test("battle: reset_hp restores state",              _test_battle_reset_hp)
	_run_test("battle: resolves stats via creature_slice",    _test_battle_resolves_via_creature_slice)
	_run_test("creature: spawns instances from GameData",     _test_creature_spawns_from_gamedata)
	_run_test("creature: nearest_creature returns closest",   _test_creature_nearest)
	_run_test("creature: death marks instance dead",          _test_creature_death_marks_dead)
	_run_test("creature: respawn resets battle hp state",     _test_creature_respawn_resets_battle_hp)
	_run_test("terrain: chunk size is correct",               _test_terrain_chunk_size)
	_run_test("terrain: height is non-negative",              _test_terrain_height_nonneg)
	_run_test("terrain: two chunks are independent",          _test_terrain_two_chunks)
	_run_test("persistence: save then load round-trip",       _test_persistence_round_trip)
	_run_test("persistence: missing slot emits load_failed",  _test_persistence_missing_slot)
	_run_test("loot: known creature produces drops",          _test_loot_known_creature)
	_run_test("loot: drops read from fabric (LavaSlug)",     _test_loot_drops_from_fabric)
	_run_test("loot: unknown creature produces no drops",     _test_loot_unknown_creature)
	_run_test("loot: consume removes pickup",                 _test_loot_consume_removes)
	_run_test("loot: instance_id resolves to fabric key",     _test_loot_instance_id_resolve)
	_run_test("inventory: pickup adds item",                  _test_inventory_pickup_adds)
	_run_test("inventory: drop reduces quantity",             _test_inventory_drop)
	_run_test("inventory: over-drop returns false",           _test_inventory_over_drop)
	_run_test("inventory: slot count correct",                _test_inventory_slot_count)
	_run_test("inventory: weights loaded from GameData.ITEMS",_test_inventory_weights_from_gamedata)
	_run_test("character: palette has 256 entries",           _test_character_palette_size)
	_run_test("character: color index clamps to palette",     _test_character_color_clamp)
	_run_test("character: proportions clamp to bounds",       _test_character_clamp_proportions)
	_run_test("character: unknown equipment dropped",         _test_character_drops_unknown_equipment)
	_run_test("character: recipe round-trips",                _test_character_recipe_round_trip)
	_run_test("character: visual state derives wear",         _test_character_visual_state_wear)
	_run_test("character: spawns non-humanoid",               _test_character_spawns_nonhumanoid)
	_run_test("character: unknown appearance rejected",       _test_character_unknown_appearance)
	_run_test("character: LOD hides fine detail",             _test_character_lod_hides_detail)
	_run_test("character: LOD distance thresholds map to level", _test_character_lod_distance_thresholds)
	_run_test("character: LOD impostor billboard swap",        _test_character_lod_impostor)
	_run_test("character: LOD auto resolves by distance",      _test_character_lod_auto_distance)
	_run_test("character: skeleton rig builds bone hierarchy",_test_character_skeleton_rig)
	_run_test("character: locomotion idle→walk→run by speed", _test_character_locomotion_speed)
	_run_test("character: blend curve maps speed to 0..1",     _test_character_blend_curve)
	_run_test("character: attack/death play on bus signals",  _test_character_attack_death_signals)
	_run_test("character: foot IK tracks terrain surface",    _test_character_foot_ik)
	_run_test("character: equipment SKINNED vs RIGID",        _test_character_deformation_modes)
	_run_test("character: apply/clear equipment",             _test_character_apply_clear_equipment)
	_run_test("character: RIGID socket offset places mesh",   _test_character_rigid_socket_offset)
	_run_test("character: non-humanoid rest pose feet at y=0", _test_nonhumanoid_rest_pose_feet_at_y0)
	_run_test("character: non-humanoid socket at bone rest",   _test_nonhumanoid_socket_offset_from_bone)
	_run_test("character: non-humanoid hideRegions hide body", _test_nonhumanoid_hide_regions_map_to_body)
	_run_test("character: full spawn path assembles + signals", _test_character_full_spawn_path)
	_run_test("character: shared palette texture (256×1)",        _test_character_palette_texture_shared)
	_run_test("character: palette pixel matches fabric hex",      _test_character_palette_pixel_matches_fabric)
	_run_test("character: palette swap round-trips shader params", _test_character_palette_swap_round_trip)
	_run_test("character: unknown palette channel rejected",     _test_character_palette_bad_channel_key)
	_run_test("character: parts share one shader + material",    _test_character_material_shader_shared)
	_run_test("character: wear channel derives from tiers",      _test_character_wear_channel)
	_run_test("character: metal channel is palette-driven",      _test_character_metal_channel)
	_run_test("character: emission path uses palette index",     _test_character_emission_path)
	_run_test("character: instance uniforms reach shader",        _test_character_instance_uniforms_reach_shader)
	_run_test("character: same-size parts share one BoxMesh",     _test_character_mesh_shared)
	_run_test("character: nearby proportions snap to one bucket",   _test_character_proportions_quantized)
	_run_test("crafting: recipe data loaded from fabric",     _test_crafting_recipe_data_loaded)
	_run_test("crafting: skill guard blocks low tier",        _test_crafting_skill_guard_blocks)
	_run_test("crafting: consumes inputs and produces output", _test_crafting_consumes_and_produces)
	_run_test("crafting: missing inputs fail",                _test_crafting_missing_inputs)
	_run_test("crafting: unknown recipe rejected",            _test_crafting_unknown_recipe)
	_run_test("crafting: can_craft does not mutate",          _test_crafting_can_craft_no_mutate)
	_run_test("station: gate blocks without nearby station",           _test_station_gate_blocks)
	_run_test("station: gate passes when station nearby",             _test_station_gate_passes)
	_run_test("station: wrong station type still blocks",             _test_station_wrong_type_blocks)
	_run_test("station: carpentry bench gates carpentry recipe",      _test_station_carpentry_bench)
	_run_test("station: master forge gates high-tier recipe",         _test_station_master_forge)
	_run_test("station: nearest_station ignores wrong type",          _test_station_nearest_ignores_wrong_type)
	_run_test("station: all canonical types accepted",                _test_station_all_canonical_types)
	_run_test("station: types derived from fabric",                   _test_station_types_from_fabric)
	_run_test("durability: use decrements points",                    _test_durability_use_decrements)
	_run_test("durability: broken tool emits item_broke",             _test_durability_broken_emits)
	_run_test("durability: stackable materials excluded",             _test_durability_stackable_excluded)
	_run_test("durability: drop and repick resets to full",           _test_durability_drop_repick_resets)
	_run_test("durability: find_tool returns held pick",              _test_durability_find_tool)
	_run_test("durability: find_tool skips broken, returns working",  _test_durability_find_tool_skips_broken)
	_run_test("technology: recipe resolves to owning tech",    _test_technology_recipe_resolves_to_tech)
	_run_test("technology: research requires prerequisite",    _test_technology_research_requires_prereq)
	_run_test("technology: research consumes materials",       _test_technology_research_consumes_materials)
	_run_test("technology: complete research unlocks",         _test_technology_complete_unlocks)
	_run_test("technology: crafting blocked while locked",     _test_technology_crafting_blocked_locked)
	_run_test("technology: crafting allowed after unlock",     _test_technology_crafting_allowed_after_unlock)
	_run_test("technology: unknown technology rejected",       _test_technology_unknown_rejected)
	_run_test("voxel: mine lowers height and yields material", _test_voxel_mine_yields_material)
	_run_test("voxel: mine at bedrock fails",                  _test_voxel_mine_bedrock)
	_run_test("voxel: side-face mine targets hit block",       _test_voxel_mine_side_face)
	_run_test("voxel: cycle filters to held materials",        _test_voxel_cycle_inventory_filtered)
	_run_test("voxel: place raises height and consumes",       _test_voxel_place_consumes)
	_run_test("voxel: place beyond cap fails and refunds",     _test_voxel_place_cap)
	_run_test("voxel: biome material mapping",                 _test_voxel_biome_materials)
	_run_test("voxel: edits round-trip",                       _test_voxel_edits_round_trip)
	_run_test("voxel: placed block keeps material colour",    _test_voxel_placed_block_keeps_material_color)
	_run_test("voxel: mining placed block yields its material", _test_voxel_mine_placed_block_yields_material)
	_run_test("voxel: placed block preserves base colour",     _test_voxel_placed_block_preserves_base_colour)
	_run_test("voxel: place after mine keeps placed colour",   _test_voxel_place_after_mine_keeps_colour)
	_run_test("ui: windows toggle open/close",                 _test_ui_window_toggle)
	_run_test("ui: inventory lines reflect contents",          _test_ui_inventory_lines)
	_run_test("ui: crafting rows gate on technology",          _test_ui_crafting_rows_tech_gate)
	_run_test("ui: technology rows report status + prereqs",   _test_ui_technology_rows_status)
	_run_test("ai: idle→alert when player within alertRadius", _test_ai_idle_to_alert)
	_run_test("ai: alert→aggressive when player within attackRadius", _test_ai_alert_to_aggressive)
	_run_test("ai: aggressive→fleeing below flee threshold",   _test_ai_aggressive_to_fleeing)
	_run_test("ai: fleeing→idle when safe distance exceeded",  _test_ai_fleeing_to_idle)
	_run_test("ai: attack emits combat_round_requested",       _test_ai_attack_emits_combat)
	_run_test("player: respawn resets hp and alive flag",      _test_player_respawn)
	_run_test("chunk: desired set within view distance",        _test_chunk_desired_set)
	_run_test("chunk: world/chunk coordinate round-trip",       _test_chunk_coordinate_round_trip)
	_run_test("chunk: per-chunk biome is stable",               _test_chunk_biome_stable)
	_run_test("chunk: load/unload emits signals",               _test_chunk_load_unload_signals)
	_run_test("chunk: voxel edits isolated per chunk",          _test_chunk_voxel_edits_isolated)
	_run_test("chunk: unload preserves edits on reload",        _test_chunk_unload_preserves_edits)
	_run_test("chunk: creature spawn scales per chunk",         _test_chunk_creature_spawn_per_chunk)
	_run_test("chunk: persistence round-trips per-chunk edits", _test_chunk_persistence_manifest)
	_run_test("chunk: minimap cells resolve chunks",            _test_chunk_minimap_cells)
	_run_test("net: client forwards block intent",               _test_net_voxel_client_forwards_intent)
	_run_test("net: apply_block_change applies host edit",       _test_net_voxel_apply_block_change)
	_run_test("net: client does not spawn creatures locally",    _test_net_creature_client_no_local_spawn)
	_run_test("net: creature snapshot round-trips",              _test_net_creature_snapshot_roundtrip)
	_run_test("net: remote player ghost interpolates",           _test_net_player_ghost_interpolation)
	_run_test("net: own peer id does not ghost",                 _test_net_player_ghost_self_filter)
	_run_test("net: creature dirty-track broadcast",             _test_net_creature_dirty_broadcast)
	_run_test("net: inventory replace_contents",                 _test_net_inventory_replace_contents)
	_run_test("net: packets carry per-type monotonic seq",        _test_net_sequence_monotonic)
	_run_test("net: duplicate dropped; reordered-unseen accepted", _test_net_sequence_dedup)
	_run_test("net: emulator queues with monotonic seq",         _test_net_emulator_delivery)
	_run_test("net: emulator drops near loss rate",              _test_net_emulator_loss)
	_run_test("net: emulator jitter centered around zero",       _test_net_emulator_jitter)
	_run_test("net: emulator adds no queue when disabled",       _test_net_emulator_zero_overhead)
	_run_test("net: jitter buffer interpolates within tolerance", _test_net_jitter_buffer)
	_run_test("net: inventory replace_contents is idempotent",   _test_net_inventory_replace_idempotent)
	_run_test("net: host persists last-known state across disconnect", _test_net_reconnect_last_known_state)
	_run_test("net: emulated loss+reorder — all delivered packets accepted", _test_net_two_peer_loss_reorder)
	_run_test("asset: placeholder resolves at canonical path",  _test_asset_placeholder_resolves)
	_run_test("asset: no private-only paths hardcoded",          _test_asset_no_private_paths_hardcoded)
	_run_test("asset: pck round-trip proves override works",    _test_asset_pck_round_trip_override)

	var total := _pass + _fail
	print("\n────────────────────────────────────────")
	print("Results: %d/%d passed  (%d failed)" % [_pass, total, _fail])
	if _fail == 0:
		print("All tests passed ✓")
	else:
		push_error("TestSuite: %d test(s) FAILED" % _fail)
	print("────────────────────────────────────────\n")

	# Every test slice is torn down with .free() (immediate, not queue_free's
	# end-of-frame deferral) right after its assertions, so it is gone — and
	# disconnected from the shared GameBus — before the next test runs. Without
	# that, dozens of freed-in-name-only slices would stay alive and connected
	# through the whole suite and into game_root's world boot, re-running saves,
	# loads, crafts and chunk builds against production emissions.

# ---------------------------------------------------------------------------
# BattleSlice tests
# ---------------------------------------------------------------------------

func _test_battle_hit_reduces_hp() -> void:
	var b := BattleSlice.new()
	add_child(b)
	b._hp_state["ForestBoar"] = 80.0
	# Force a deterministic hit by stuffing initial HP and reading result.
	var result := b.resolve_round("ForestBoar", "GraywolfPack")
	assert_true(result.has("defender_hp_remaining"), "result has defender_hp_remaining")
	assert_true(result["defender_hp_remaining"] >= 0.0, "HP is non-negative")
	b.free()

func _test_battle_miss_leaves_hp_unchanged() -> void:
	var b := BattleSlice.new()
	add_child(b)
	seed(11)
	# Start HP high enough that the defender survives any number of rounds in
	# this test, so a miss is observed from a live (non-zero) HP state.
	b._hp_state["GraywolfPack"] = 10000.0
	var saw_miss := false
	for _i in range(200):
		var before: float = b._hp_state["GraywolfPack"]
		var r := b.resolve_round("ForestBoar", "GraywolfPack")
		if r["outcome"] == "miss":
			assert_eq(b._hp_state["GraywolfPack"], before, "miss leaves defender HP unchanged")
			saw_miss = true
			break
	assert_true(saw_miss, "observed at least one miss over 200 seeded rounds")
	b.free()

func _test_battle_kill_emits_death() -> void:
	var b := BattleSlice.new()
	add_child(b)
	seed(42)
	# Prime the defender with 1 HP so the next non-miss attack kills it.
	b._hp_state["ForestBoar"] = 1.0
	var captured := {}
	GameBus.creature_died.connect(func(_id, _pos, _killer): captured["died"] = true)
	for _i in range(200):
		b.resolve_round("GraywolfPack", "ForestBoar")
		if captured.get("died", false):
			break
	assert_true(captured.get("died", false), "creature_died emitted once defender HP reaches zero")
	b.free()

func _test_battle_reset_hp() -> void:
	var b := BattleSlice.new()
	add_child(b)
	b._hp_state["ForestBoar"] = 10.0
	b.reset_hp("ForestBoar")
	assert_false(b._hp_state.has("ForestBoar"), "HP state cleared after reset")
	b.free()

func _test_battle_resolves_via_creature_slice() -> void:
	var c := CreatureSlice.new()
	add_child(c)
	c.spawn_for_chunk(Vector2i(0, 0))
	var b := BattleSlice.new()
	b.creature_slice = c
	add_child(b)
	# Grab the first spawned instance and attack it by instance_id.
	var instances := c.get_all_instances()
	assert_true(instances.size() > 0, "creature slice spawned at least one instance")
	if instances.size() > 0:
		var iid: String = instances[0]["instance_id"]
		var result := b.resolve_round("player", iid)
		assert_true(result.has("defender_hp_remaining"), "result has defender_hp_remaining for instance_id")
	b.free()
	c.free()

# ---------------------------------------------------------------------------
# CreatureSlice tests
# ---------------------------------------------------------------------------

func _test_creature_spawns_from_gamedata() -> void:
	var c := CreatureSlice.new()
	add_child(c)
	c.spawn_for_chunk(Vector2i(0, 0))
	var instances := c.get_all_instances()
	assert_true(instances.size() > 0, "at least one creature spawned from GameData")
	for inst in instances:
		assert_true(GameData.CREATURES.has(inst["creature_id"]),
			"creature_id '%s' exists in GameData.CREATURES" % inst["creature_id"])
		assert_true(inst["hp"] > 0.0, "spawned creature has positive HP from fabric")
	c.free()

func _test_creature_nearest() -> void:
	var c := CreatureSlice.new()
	add_child(c)
	c.spawn_for_chunk(Vector2i(0, 0))
	var instances := c.get_all_instances()
	assert_true(instances.size() > 0, "need at least one instance for nearest test")
	if instances.size() > 0:
		var pos: Vector3 = instances[0]["position"]
		var result := c.nearest_creature(pos, 1000.0)
		assert_true(result != "", "nearest_creature returns an instance_id within large radius")
	c.free()

func _test_creature_death_marks_dead() -> void:
	var c := CreatureSlice.new()
	add_child(c)
	c.spawn_for_chunk(Vector2i(0, 0))
	var instances := c.get_all_instances()
	assert_true(instances.size() > 0, "need an instance to kill")
	if instances.size() > 0:
		var iid: String = instances[0]["instance_id"]
		var creature_id: String = instances[0]["creature_id"]
		GameBus.creature_died.emit(iid, Vector3.ZERO, "player")
		var updated := c.get_all_instances()
		var found := false
		for inst in updated:
			if inst["instance_id"] == iid:
				assert_eq(inst["state"], "dead", "instance state is dead after creature_died signal")
				found = true
		assert_true(found, "dead instance still present in get_all_instances")
	c.free()

func _test_creature_respawn_resets_battle_hp() -> void:
	var c := CreatureSlice.new()
	add_child(c)
	c.spawn_for_chunk(Vector2i(0, 0))
	var b := BattleSlice.new()
	b.creature_slice = c
	add_child(b)
	var instances := c.get_all_instances()
	assert_true(instances.size() > 0, "need an instance to respawn")
	if instances.size() > 0:
		var iid: String = instances[0]["instance_id"]
		# Simulate a kill: battle tracks 0 HP and the creature dies via the bus.
		b._hp_state[iid] = 0.0
		GameBus.creature_died.emit(iid, Vector3.ZERO, "player")
		# Force the respawn timer to have elapsed, then tick.
		c._instances[iid]["respawn_at"] = Time.get_ticks_msec() - 1.0
		c._tick_respawn()
		assert_false(b._hp_state.has(iid), "battle hp state cleared on respawn")
		assert_eq(c._instances[iid]["state"], "idle", "creature state back to idle after respawn")
	b.free()
	c.free()

# ---------------------------------------------------------------------------
# TerrainSlice tests
# ---------------------------------------------------------------------------

func _test_terrain_chunk_size() -> void:
	var t := TerrainSlice.new()
	add_child(t)
	var captured := {}
	GameBus.chunk_ready.connect(func(_pos, hm): captured["heightmap"] = hm)
	t.request_chunk(Vector2i(0, 0))
	var heightmap: Array = captured.get("heightmap", [])
	assert_eq(heightmap.size(), t.CHUNK_SIZE * t.CHUNK_SIZE, "heightmap size matches CHUNK_SIZE²")
	t.free()

func _test_terrain_height_nonneg() -> void:
	var t := TerrainSlice.new()
	add_child(t)
	var captured := {}
	GameBus.chunk_ready.connect(func(_pos, hm): captured["heightmap"] = hm)
	t.request_chunk(Vector2i(1, 1))
	for h in captured.get("heightmap", []):
		assert_true(h >= 0.0, "height is non-negative")
	t.free()

func _test_terrain_two_chunks() -> void:
	var t := TerrainSlice.new()
	add_child(t)
	var maps: Array = []
	GameBus.chunk_ready.connect(func(_pos, hm): maps.append(hm))
	t.request_chunk(Vector2i(0, 0))
	t.request_chunk(Vector2i(5, 5))
	assert_eq(maps.size(), 2, "two chunk_ready signals received")
	t.free()

# ---------------------------------------------------------------------------
# PersistenceSlice tests
# ---------------------------------------------------------------------------

func _test_persistence_round_trip() -> void:
	var p := PersistenceSlice.new()
	add_child(p)
	var captured := {}
	GameBus.load_completed.connect(func(_slot, data): captured["data"] = data)
	var data := { "player": "TestPlayer", "level": 42 }
	p.save(99, data)
	p.load_slot(99)
	var loaded: Dictionary = captured.get("data", {})
	assert_eq(loaded.get("player", ""), "TestPlayer", "player name round-trips")
	assert_eq(loaded.get("level", 0),   42,           "level round-trips")
	p.free()

func _test_persistence_missing_slot() -> void:
	var p := PersistenceSlice.new()
	add_child(p)
	var captured := {}
	GameBus.load_failed.connect(func(_slot, _reason): captured["failed"] = true)
	p.load_slot(98)   # slot 98 was never saved in this test run
	assert_true(captured.get("failed", false), "load_failed emitted for missing slot")
	p.free()

# ---------------------------------------------------------------------------
# LootSlice tests
# ---------------------------------------------------------------------------

func _test_loot_known_creature() -> void:
	var l := LootSlice.new()
	add_child(l)
	var drops: Array = []
	GameBus.loot_dropped.connect(func(pid, iid, pos, qty):
		drops.append({ "id": pid, "item": iid, "qty": qty }))
	# Emit death for ForestBoar — guaranteed drops: raw_boar_meat + boar_hide.
	GameBus.creature_died.emit("ForestBoar", Vector3.ZERO, "player")
	assert_true(drops.size() >= 2, "at least 2 guaranteed drops for ForestBoar")
	var items := drops.map(func(d): return d["item"])
	assert_true(items.has("raw_boar_meat"), "raw_boar_meat always drops")
	assert_true(items.has("boar_hide"),     "boar_hide always drops")
	l.free()

func _test_loot_drops_from_fabric() -> void:
	var l := LootSlice.new()
	add_child(l)
	var drops: Array = []
	GameBus.loot_dropped.connect(func(pid, iid, pos, qty):
		drops.append({ "id": pid, "item": iid, "qty": qty }))
	# LavaSlug's fabric drop table: slug_shell_shard (2–4), superheated_slime_vial
	# (1–2), lava_core_organ (15%). The first two are guaranteed; the old
	# hardcoded ids (slag_gland / volcanic_slime) must no longer appear.
	GameBus.creature_died.emit("LavaSlug", Vector3.ZERO, "player")
	var items := drops.map(func(d): return d["item"])
	assert_true(items.has("slug_shell_shard"),       "slug_shell_shard drops from fabric")
	assert_true(items.has("superheated_slime_vial"), "superheated_slime_vial always drops")
	assert_false(items.has("slag_gland"),            "stale 'slag_gland' id no longer used")
	assert_false(items.has("volcanic_slime"),        "stale 'volcanic_slime' id no longer used")
	l.free()

func _test_loot_unknown_creature() -> void:
	var l := LootSlice.new()
	add_child(l)
	var captured := {}
	GameBus.loot_dropped.connect(func(_pid, _iid, _pos, _qty): captured["dropped"] = true)
	GameBus.creature_died.emit("UnknownBeast", Vector3.ZERO, "")
	assert_false(captured.get("dropped", false), "no loot dropped for unknown creature")
	l.free()

func _test_loot_consume_removes() -> void:
	var l := LootSlice.new()
	add_child(l)
	var captured := {}
	GameBus.loot_dropped.connect(func(pid, _iid, _pos, _qty): captured["pid"] = pid)
	GameBus.creature_died.emit("ForestBoar", Vector3.ZERO, "player")
	var last_pid: String = captured.get("pid", "")
	assert_true(last_pid != "", "at least one pickup was created")
	var result := l.consume_pickup(last_pid)
	assert_false(result.is_empty(), "consume returns the pickup data")
	var second := l.consume_pickup(last_pid)
	assert_true(second.is_empty(), "second consume returns empty (already taken)")
	l.free()

func _test_loot_instance_id_resolve() -> void:
	var c := CreatureSlice.new()
	add_child(c)
	c.spawn_for_chunk(Vector2i(0, 0))
	var l := LootSlice.new()
	l.creature_slice = c
	add_child(l)
	var drops: Array = []
	GameBus.loot_dropped.connect(func(pid, iid, pos, qty):
		drops.append({ "id": pid, "item": iid, "qty": qty }))
	# Kill by instance_id; loot slice must resolve to "ForestBoar" for drop table.
	var instances := c.get_all_instances()
	var boar_iid := ""
	for inst in instances:
		if inst["creature_id"] == "ForestBoar":
			boar_iid = inst["instance_id"]
			break
	if boar_iid != "":
		GameBus.creature_died.emit(boar_iid, Vector3.ZERO, "player")
		assert_true(drops.size() >= 2,
			"ForestBoar drops via instance_id produce at least 2 guaranteed items")
	else:
		assert_true(true, "no ForestBoar instance — skip instance_id resolve test")
	l.free()
	c.free()

# ---------------------------------------------------------------------------
# InventorySlice tests
# ---------------------------------------------------------------------------

func _test_inventory_pickup_adds() -> void:
	var inv := InventorySlice.new()
	add_child(inv)
	# Directly call internal pickup helper; bypass proximity check.
	inv._try_pickup("test_pid", "hawk_feather", 3)
	assert_eq(inv.get_item_count("hawk_feather"), 3, "hawk_feather ×3 in inventory")
	inv.free()

func _test_inventory_drop() -> void:
	var inv := InventorySlice.new()
	add_child(inv)
	inv._try_pickup("p1", "wolf_pelt", 2)
	var ok := inv.drop_item("wolf_pelt", 1)
	assert_true(ok, "drop returned true")
	assert_eq(inv.get_item_count("wolf_pelt"), 1, "one wolf pelt remains")
	inv.free()

func _test_inventory_over_drop() -> void:
	var inv := InventorySlice.new()
	add_child(inv)
	inv._try_pickup("p1", "wolf_pelt", 1)
	var ok := inv.drop_item("wolf_pelt", 5)
	assert_false(ok, "drop of more than held returns false")
	assert_eq(inv.get_item_count("wolf_pelt"), 1, "quantity unchanged after failed drop")
	inv.free()

func _test_inventory_slot_count() -> void:
	var inv := InventorySlice.new()
	add_child(inv)
	inv._try_pickup("p1", "wolf_pelt",   1)
	inv._try_pickup("p2", "hawk_feather",1)
	inv._try_pickup("p3", "boar_hide",   1)
	assert_eq(inv.get_total_slots_used(), 3, "3 distinct item types = 3 slots")
	inv._try_pickup("p4", "wolf_pelt",   1)   # stack merge
	assert_eq(inv.get_total_slots_used(), 3, "stacking same item doesn't add a slot")
	inv.free()

func _test_inventory_weights_from_gamedata() -> void:
	var inv := InventorySlice.new()
	add_child(inv)
	# FieldRations is in GameData.ITEMS (weight = 0.3 in fabric/gameplay/items/food.js).
	# After _ready(), the weight cache should have its weight from the resource.
	var w: float = inv._item_weight("FieldRations")
	assert_true(w > 0.0, "FieldRations weight > 0 (loaded from GameData.ITEMS)")
	# Raw drop not in GameData.ITEMS must still return a positive weight.
	var w2: float = inv._item_weight("raw_boar_meat")
	assert_true(w2 > 0.0, "raw_boar_meat weight > 0 (from RAW_DROP_WEIGHTS)")
	inv.free()

# ---------------------------------------------------------------------------
# CharacterSlice tests
# ---------------------------------------------------------------------------

func _test_character_palette_size() -> void:
	var ch := CharacterSlice.new()
	add_child(ch)
	assert_eq(ch.get_palette_size(), 256, "palette expands to 256 entries")
	var c0 := ch.palette_color(0)
	var c255 := ch.palette_color(255)
	assert_true(c0 is Color and c255 is Color, "palette_color returns Color")
	ch.free()

func _test_character_color_clamp() -> void:
	var ch := CharacterSlice.new()
	add_child(ch)
	assert_true(ch.palette_color(-5) == ch.palette_color(0), "negative index clamps to 0")
	assert_true(ch.palette_color(9999) == ch.palette_color(255), "oversized index clamps to 255")
	assert_true(ch.palette_color(100) is Color, "in-range index returns Color")
	ch.free()

func _test_character_clamp_proportions() -> void:
	var ch := CharacterSlice.new()
	add_child(ch)
	var recipe := ch.deserialize_appearance({
		"skeleton": "HumanoidSkeleton",
		"proportions": { "height": 9.0, "bodyMass": 0.01, "shoulderWidth": 1.0 },
	})
	var props: Dictionary = recipe["proportions"]
	assert_true(is_equal_approx(props["height"], 1.15), "height clamped to max 1.15")
	assert_true(is_equal_approx(props["bodyMass"], 0.80), "bodyMass clamped to min 0.80")
	assert_true(is_equal_approx(props["shoulderWidth"], 1.0), "in-range value unchanged")
	ch.free()

func _test_character_drops_unknown_equipment() -> void:
	var ch := CharacterSlice.new()
	add_child(ch)
	var recipe := ch.deserialize_appearance({
		"skeleton": "HumanoidSkeleton",
		"equipment": {
			"Chest": { "item": "VeilsteelChestplate", "state": "equipped" },
			"Head":  { "item": "NonexistentHelm", "state": "equipped" },
		},
	})
	var eq: Dictionary = recipe["equipment"]
	assert_true(eq.has("Chest"), "known equipment kept")
	assert_false(eq.has("Head"), "unknown equipment dropped")
	ch.free()

func _test_character_recipe_round_trip() -> void:
	var ch := CharacterSlice.new()
	add_child(ch)
	var original := {
		"skeleton": "HumanoidSkeleton",
		"body": "human_body_02",
		"proportions": { "height": 0.96, "bodyMass": 1.04 },
		"skinColor": 12,
		"hair": "hair_long_04",
		"hairColor": 40,
		"equipment": { "MainHand": { "item": "VeilsteelLongsword", "state": "sheathed", "durability": 0.7 } },
	}
	var normalized := ch.deserialize_appearance(original)
	var serialized := ch.serialize_appearance(normalized)
	var again := ch.deserialize_appearance(serialized)
	assert_eq(again["skeleton"], "HumanoidSkeleton", "skeleton survives")
	assert_eq(again["skinColor"], 12, "skinColor survives")
	assert_eq(again["hairColor"], 40, "hairColor survives")
	var eq: Dictionary = again["equipment"]
	assert_true(eq.has("MainHand"), "equipment survives round-trip")
	assert_eq(eq["MainHand"]["durability"], 0.7, "durability survives round-trip")
	ch.free()

func _test_character_visual_state_wear() -> void:
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid := ch.create_character_from_recipe({
		"skeleton": "HumanoidSkeleton",
		"equipment": { "MainHand": { "item": "VeilsteelLongsword", "state": "equipped", "durability": 0.7 } },
	}, Vector3.ZERO)
	assert_true(iid != "", "character created")
	var vs := ch.get_visual_state(iid)
	var eq: Dictionary = vs.get("equipment", {})
	assert_eq(eq["MainHand"]["wear"], "Used", "wear derived from durability 0.7")
	ch.free()

func _test_character_spawns_nonhumanoid() -> void:
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid := ch.create_character("BoarRider", Vector3.ZERO)
	assert_true(iid != "", "boar_rider (quadruped) created")
	var app := ch.get_appearance(iid)
	assert_eq(app["skeleton"], "QuadrupedSkeleton", "quadruped skeleton preserved")
	ch.free()

func _test_character_unknown_appearance() -> void:
	var ch := CharacterSlice.new()
	add_child(ch)
	assert_eq(ch.create_character("does_not_exist", Vector3.ZERO), "", "unknown appearance_id returns empty")
	ch.free()

func _test_nonhumanoid_rest_pose_feet_at_y0() -> void:
	# Non-humanoid rest poses share the humanoid "feet at y=0" convention
	# (characters.md §37.4): the lowest leg/contact bone rests on the ground
	# plane so a rig placed at the origin stands on the terrain, not above or
	# sunk into it.
	var q := SkeletonRig.new()
	add_child(q)
	q.build(GameData.SKELETONS["QuadrupedSkeleton"], {})
	assert_true(is_equal_approx(q.get_bone_global_rest("Leg_FL").y, 0.0), "quadruped fore foot rests at y=0")
	assert_true(is_equal_approx(q.get_bone_global_rest("Leg_BR").y, 0.0), "quadruped hind foot rests at y=0")
	q.free()

	var b := SkeletonRig.new()
	add_child(b)
	b.build(GameData.SKELETONS["BirdSkeleton"], {})
	assert_true(is_equal_approx(b.get_bone_global_rest("Leg_L").y, 0.0), "bird foot rests at y=0")
	assert_true(is_equal_approx(b.get_bone_global_rest("Leg_R").y, 0.0), "bird right foot rests at y=0")
	b.free()

	var s := SkeletonRig.new()
	add_child(s)
	s.build(GameData.SKELETONS["SerpentSkeleton"], {})
	assert_true(is_equal_approx(s.get_bone_global_rest("Spine_1").y, 0.0), "serpent body rests at y=0")
	s.free()

func _test_nonhumanoid_socket_offset_from_bone() -> void:
	# Non-humanoid sockets attach at their socket bone's rest origin, not the
	# humanoid landmark layout (characters.md §4). A RIGID head item on a
	# quadruped must land at the Head bone (y≈0.75), not humanoid head_top
	# (y≈1.80) — asserting y<1.0 catches a regression to the humanoid layout.
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid := ch.create_character("BoarRider", Vector3.ZERO)
	assert_true(ch.apply_equipment(iid, "Head", "FerriteHelmet"), "helmet equips on quadruped")
	var helmet: Node3D = ch.get_part_node(iid, "Head")
	assert_true(helmet != null, "helmet mesh exposed")
	assert_true(helmet.position.y > 0.0 and helmet.position.y < 1.0, "head socket at bone rest, not humanoid landmark")
	ch.free()

func _test_nonhumanoid_hide_regions_map_to_body() -> void:
	# Non-humanoid families build a single generic "body" part instead of the
	# humanoid body_chest/body_legs split, so body hideRegions (e.g. a
	# chestplate's BodyChest/BodyShoulders) must hide that one part (§16).
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid := ch.create_character("BoarRider", Vector3.ZERO)
	assert_true(ch.is_part_visible(iid, "body"), "quadruped body visible before equipment")
	assert_true(ch.apply_equipment(iid, "Chest", "VeilsteelChestplate"), "chestplate equips on quadruped")
	assert_false(ch.is_part_visible(iid, "body"), "BodyChest/BodyShoulders hide the generic non-humanoid body part")
	ch.free()

func _test_character_lod_hides_detail() -> void:
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid := ch.create_character("TravellerHuman", Vector3.ZERO)
	assert_true(iid != "", "traveller created")
	ch.set_lod(0)
	assert_true(ch.is_part_visible(iid, "hair"), "hair visible at LOD0")
	# LOD 2 swaps in the impostor billboard (Phase 23), hiding the whole rig —
	# hair (min_lod 1) and even coarse body geometry are all gone.
	ch.set_lod(2)
	assert_false(ch.is_part_visible(iid, "hair"), "hair hidden at LOD2")
	assert_false(ch.is_part_visible(iid, "body_legs"), "body_legs hidden at LOD2 (impostor)")
	assert_true(ch.is_impostor_visible(iid), "impostor shown at LOD2")
	ch.free()

func _test_character_lod_distance_thresholds() -> void:
	# Pure distance→LOD mapping (Phase 23): ≤20m full, ≤60m medium, beyond
	# impostor. Boundaries are inclusive of the nearer level.
	assert_eq(CharacterSlice.lod_level_for_distance(0.0), 0, "0m → LOD 0")
	assert_eq(CharacterSlice.lod_level_for_distance(20.0), 0, "20m (boundary) → LOD 0")
	assert_eq(CharacterSlice.lod_level_for_distance(20.1), 1, "just past 20m → LOD 1")
	assert_eq(CharacterSlice.lod_level_for_distance(60.0), 1, "60m (boundary) → LOD 1")
	assert_eq(CharacterSlice.lod_level_for_distance(60.1), 2, "just past 60m → LOD 2")
	assert_eq(CharacterSlice.lod_level_for_distance(500.0), 2, "far → LOD 2 (impostor)")

func _test_character_lod_impostor() -> void:
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid := ch.create_character("TravellerHuman", Vector3.ZERO)
	ch.set_lod(0)
	assert_false(ch.is_impostor_visible(iid), "impostor hidden at LOD0")
	assert_true(ch.is_part_visible(iid, "body_legs"), "body_legs visible at LOD0")
	ch.set_lod(1)
	assert_false(ch.is_impostor_visible(iid), "impostor hidden at LOD1")
	assert_true(ch.is_part_visible(iid, "body_legs"), "coarse geometry still visible at LOD1")
	ch.set_lod(2)
	assert_true(ch.is_impostor_visible(iid), "impostor shown at LOD2")
	assert_false(ch.is_part_visible(iid, "body_legs"), "body_legs hidden at LOD2")
	# The impostor billboard is tinted to the character's own palette colour
	# (dominant skin colour), so a palette swap follows the instance.
	var imp: Node3D = ch.get_impostor_node(iid)
	assert_true(imp != null, "impostor node exists")
	var skin_idx: int = int(ch.get_appearance(iid)["skinColor"])
	var mat: Material = imp.material_override
	assert_true(mat is StandardMaterial3D, "impostor uses a StandardMaterial3D")
	assert_true((mat as StandardMaterial3D).albedo_color.is_equal_approx(ch.palette_color(skin_idx)), "impostor tinted to the character's palette colour")
	ch.free()

func _test_character_lod_auto_distance() -> void:
	# Distance-driven LOD (Phase 23): update_lod switches to AUTO and resolves
	# each instance's level from its world distance to the viewer.
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid := ch.create_character("TravellerHuman", Vector3.ZERO)
	ch.update_lod(Vector3(0.0, 0.0, 10.0))
	assert_eq(ch.get_instance_lod(iid), 0, "10m → LOD 0")
	assert_false(ch.is_impostor_visible(iid), "no impostor at 10m")
	ch.update_lod(Vector3(0.0, 0.0, 40.0))
	assert_eq(ch.get_instance_lod(iid), 1, "40m → LOD 1")
	assert_false(ch.is_impostor_visible(iid), "no impostor at 40m")
	ch.update_lod(Vector3(0.0, 0.0, 100.0))
	assert_eq(ch.get_instance_lod(iid), 2, "100m → LOD 2")
	assert_true(ch.is_impostor_visible(iid), "impostor shown at 100m")
	# Manual set_lod re-overrides auto evaluation.
	ch.set_lod(0)
	assert_eq(ch.get_instance_lod(iid), 0, "set_lod(0) overrides auto LOD")
	assert_false(ch.is_impostor_visible(iid), "impostor hidden after manual reset")
	ch.free()

func _test_character_skeleton_rig() -> void:
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid := ch.create_character("TravellerHuman", Vector3.ZERO)
	assert_true(iid != "", "traveller created")
	var bones: Array = ch.get_skeleton_bone_names(iid)
	assert_true(bones.has("Root"),   "Root bone present")
	assert_true(bones.has("Hips"),   "Hips bone present")
	assert_true(bones.has("Chest"),  "Chest bone present")
	assert_true(bones.has("Head"),   "Head bone present")
	assert_true(bones.has("Hand_R"), "Hand_R bone present")
	assert_true(bones.has("Foot_L"), "Foot_L bone present")
	ch.free()

func _test_character_locomotion_speed() -> void:
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid := ch.create_character("TravellerHuman", Vector3.ZERO)
	assert_eq(ch.get_locomotion_state_name(iid), "IDLE", "character starts idle")
	ch.update_locomotion(iid, 2.0, true, 0.0, 0.0)
	assert_eq(ch.get_locomotion_state_name(iid), "WALK", "speed 2.0 → WALK")
	ch.update_locomotion(iid, 5.0, true, 0.0, 0.0)
	assert_eq(ch.get_locomotion_state_name(iid), "RUN", "speed 5.0 → RUN")
	ch.update_locomotion(iid, 0.0, true, 0.0, 0.0)
	assert_eq(ch.get_locomotion_state_name(iid), "IDLE", "speed 0.0 → IDLE")
	ch.free()

func _test_character_attack_death_signals() -> void:
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid := ch.create_character("TravellerHuman", Vector3.ZERO)
	GameBus.character_attack_requested.emit(iid)
	assert_eq(ch.get_locomotion_state_name(iid), "ATTACK", "attack request → ATTACK")
	GameBus.character_death_requested.emit(iid)
	assert_eq(ch.get_locomotion_state_name(iid), "DEATH", "death request → DEATH")
	ch.free()

func _test_character_foot_ik() -> void:
	var flat := func(_xz: Vector2) -> float: return 0.0
	var t := SkeletonRig.compute_foot_targets(flat, Vector3(0.0, 1.0, 0.0), 0.5, 1.5, 0.2, 0.0)
	var fl: Vector3 = t["foot_l"]
	var fr: Vector3 = t["foot_r"]
	assert_true(is_equal_approx(fl.y, 0.0), "left foot on flat terrain y=0")
	assert_true(is_equal_approx(fr.y, 0.0), "right foot on flat terrain y=0")
	var slope := func(xz: Vector2) -> float: return xz.x * 0.5
	var t2 := SkeletonRig.compute_foot_targets(slope, Vector3(0.0, 1.0, 0.0), 0.5, 1.5, 0.2, 0.0)
	var sl: Vector3 = t2["foot_l"]
	var sr: Vector3 = t2["foot_r"]
	assert_true(sl.y < sr.y, "slope tilts feet (left lower)")
	var trench := func(_xz: Vector2) -> float: return -10.0
	var t3 := SkeletonRig.compute_foot_targets(trench, Vector3(0.0, 1.0, 0.0), 0.5, 1.5, 0.2, 0.0)
	var tl: Vector3 = t3["foot_l"]
	assert_true(is_equal_approx(tl.y, 0.0), "deep trench clamps foot to leg reach")

func _test_character_deformation_modes() -> void:
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid := ch.create_character_from_recipe({ "skeleton": "HumanoidSkeleton" }, Vector3.ZERO)
	assert_true(ch.apply_equipment(iid, "Cape", "DuskfiberCloak"), "cloak (SKINNED) equipped")
	assert_true(ch.apply_equipment(iid, "MainHand", "VeilsteelLongsword"), "sword (RIGID) equipped")
	assert_eq(ch.get_equipment_deformation_mode(iid, "Cape"), "SKINNED", "cloak deforms (SKINNED)")
	assert_eq(ch.get_equipment_deformation_mode(iid, "MainHand"), "RIGID", "sword stays rigid (RIGID)")
	assert_true(ch.get_equipment_attached_bone(iid, "Cape") != "", "SKINNED cloak follows a bone")
	assert_eq(ch.get_equipment_attached_bone(iid, "MainHand"), "", "RIGID sword does not follow a bone")
	ch.free()

func _test_character_apply_clear_equipment() -> void:
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid := ch.create_character_from_recipe({ "skeleton": "HumanoidSkeleton" }, Vector3.ZERO)
	assert_true(ch.apply_equipment(iid, "MainHand", "VeilsteelLongsword"), "sword equipped")
	assert_eq(ch.get_equipment_deformation_mode(iid, "MainHand"), "RIGID", "sword present")
	assert_true(ch.clear_equipment(iid, "MainHand"), "sword cleared")
	assert_eq(ch.get_equipment_deformation_mode(iid, "MainHand"), "", "slot empty after clear")
	assert_false(ch.clear_equipment(iid, "MainHand"), "clearing empty slot returns false")
	ch.free()

func _test_character_blend_curve() -> void:
	# The blend weight is a continuous 0..1 curve over speed (idle → walk → run),
	# replacing the old per-state magic constants (WALK → 0, RUN → 1).
	assert_eq(Locomotion.blend_curve(0.0), 0.0, "idle speed → blend 0")
	assert_eq(Locomotion.blend_curve(Locomotion.WALK_SPEED), 0.0, "walk threshold → blend 0")
	assert_eq(Locomotion.blend_curve(Locomotion.RUN_SPEED), 1.0, "run threshold → blend 1")
	var mid: float = (Locomotion.WALK_SPEED + Locomotion.RUN_SPEED) / 2.0
	assert_true(is_equal_approx(Locomotion.blend_curve(mid), 0.5), "mid-band speed → blend 0.5")
	assert_true(Locomotion.blend_curve(0.0) < Locomotion.blend_curve(mid), "blend rises through the walk band")
	var loco := Locomotion.new()
	loco.update(mid, true, 0.0, 0.0)
	assert_true(is_equal_approx(loco.get_blend_weight(), 0.5), "get_blend_weight tracks last update speed")

func _test_character_rigid_socket_offset() -> void:
	# Socket offsets place equipment in two spaces: RIGID in root space (mesh is
	# a rig-root child), SKINNED/HYBRID in bone-local space (mesh under a
	# BoneAttachment3D). Both must land at a non-origin socket position.
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid := ch.create_character_from_recipe({ "skeleton": "HumanoidSkeleton" }, Vector3.ZERO)

	assert_true(ch.apply_equipment(iid, "MainHand", "VeilsteelLongsword"), "RIGID sword equipped")
	var sword: Node3D = ch.get_part_node(iid, "MainHand")
	assert_true(sword != null, "RIGID mesh exposed")
	assert_eq(ch.get_equipment_attached_bone(iid, "MainHand"), "", "RIGID sword not bone-parented")
	assert_false(sword.get_parent() is BoneAttachment3D, "RIGID mesh is a rig-root child, not under a bone")
	var sp: Vector3 = sword.position
	assert_true(sp.x > 0.0 and sp.y > 0.0, "RIGID sword at right-hand socket offset, not origin")

	assert_true(ch.apply_equipment(iid, "Cape", "DuskfiberCloak"), "SKINNED cloak equipped")
	var cloak: Node3D = ch.get_part_node(iid, "Cape")
	assert_true(cloak != null, "SKINNED mesh exposed")
	assert_true(ch.get_equipment_attached_bone(iid, "Cape") != "", "SKINNED cloak bone-parented")
	assert_true(cloak.get_parent() is BoneAttachment3D, "SKINNED mesh under a BoneAttachment3D")
	assert_true(cloak.position != Vector3.ZERO, "SKINNED cloak honors a non-zero bone-local socket offset")
	ch.free()

func _test_character_full_spawn_path() -> void:
	# End-to-end spawn: create_character must register an instance, assemble the
	# rig (bone hierarchy + body/head skinned to bones), initialise locomotion to
	# idle, and emit character_spawned with the correct skeleton and position.
	var ch := CharacterSlice.new()
	add_child(ch)

	var captured := {}
	# Bound to a local Callable (rather than left as an inline connect target) so
	# it can be explicitly disconnected below — a lambda connected to an
	# autoload signal is not severed just by freeing `ch`, unlike GameBus
	# connections made through a slice's own bound methods.
	var on_spawned := func(iid, skeleton_id, position):
		captured["count"] = captured.get("count", 0) + 1
		captured["iid"] = iid
		captured["skeleton"] = skeleton_id
		captured["position"] = position
	GameBus.character_spawned.connect(on_spawned)

	var pos := Vector3(4.0, 2.0, 6.0)
	var iid := ch.create_character("TravellerHuman", pos)
	assert_true(iid != "", "character created")

	assert_eq(ch.get_appearance(iid)["skeleton"], "HumanoidSkeleton", "skeleton preserved")

	var bones: Array = ch.get_skeleton_bone_names(iid)
	assert_true(bones.has("Root") and bones.has("Chest") and bones.has("Head"), "bone hierarchy assembled")

	var body: Node3D = ch.get_part_node(iid, "body_chest")
	var head: Node3D = ch.get_part_node(iid, "head")
	assert_true(body != null and head != null, "body and head parts assembled")
	assert_eq(str(body.get_meta("attached_bone")), "Chest", "body skinned to torso bone")
	assert_eq(str(head.get_meta("attached_bone")), "Head", "head skinned to head bone")

	assert_eq(ch.get_locomotion_state_name(iid), "IDLE", "starts idle")

	assert_eq(captured.get("count", 0), 1, "character_spawned emitted exactly once")
	assert_eq(captured.get("iid"), iid, "signal carries instance id")
	assert_eq(captured.get("skeleton"), "HumanoidSkeleton", "signal carries skeleton id")
	assert_eq(captured.get("position"), pos, "signal carries spawn position")

	GameBus.character_spawned.disconnect(on_spawned)
	ch.free()

func _test_character_palette_texture_shared() -> void:
	# The palette is ONE shared 256×1 texture (characters.md §19); every part
	# samples it. A part's material carries it as `palette_tex`, so a palette
	# swap writes a shader index — no per-skin texture asset is ever created.
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid := ch.create_character("TravellerHuman", Vector3.ZERO)
	assert_true(iid != "", "character created")
	var shared := ch.get_palette_texture()
	assert_true(shared is ImageTexture, "palette texture is an ImageTexture")
	assert_eq(shared.get_width(), 256, "palette texture is 256 wide")
	assert_eq(shared.get_height(), 1, "palette texture is a single row")
	var mat := ch.get_part_material(iid, "head")
	assert_true(mat is ShaderMaterial, "part uses a ShaderMaterial")
	assert_true(mat.get_shader_parameter("palette_tex") == shared, "part material references the shared palette texture")
	ch.free()

func _test_character_palette_pixel_matches_fabric() -> void:
	# The palette texture pixels must equal the fabric hex entries byte-for-byte
	# (§19): the fabric palette is the single source of truth for colour.
	var ch := CharacterSlice.new()
	add_child(ch)
	var res: Resource = GameData.PALETTES.get("DefaultPalette", null)
	assert_true(res != null, "DefaultPalette resource present")
	var entries = res.get("entries")
	assert_true(entries is Array and entries.size() == 256, "fabric palette has 256 entries")
	var img: Image = ch.get_palette_texture().get_image()
	for i in [0, 32, 160, 192, 255]:
		var hex_str: String = str(entries[i])
		var expected: Color = Color(hex_str)
		var px: Color = img.get_pixel(i, 0)
		assert_eq(px.r8, expected.r8, "red channel of pixel %d matches fabric hex" % i)
		assert_eq(px.g8, expected.g8, "green channel of pixel %d matches fabric hex" % i)
		assert_eq(px.b8, expected.b8, "blue channel of pixel %d matches fabric hex" % i)
	ch.free()

func _test_character_palette_swap_round_trip() -> void:
	# A palette swap is a per-instance shader-parameter write (§20): apply a new
	# index, read it back from the mesh, confirm it matches — no new texture, no
	# new material.
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid := ch.create_character("TravellerHuman", Vector3.ZERO)
	assert_true(iid != "", "character created")
	var before: int = int(ch.get_part_shader_parameter(iid, "body_chest", "base_index"))
	assert_true(ch.apply_palette_index(iid, "body_chest", "primary_index", 200), "apply_palette_index succeeds")
	assert_eq(int(ch.get_part_shader_parameter(iid, "body_chest", "primary_index")), 200, "primary_index round-trips through the shader parameter")
	assert_eq(int(ch.get_part_shader_parameter(iid, "body_chest", "base_index")), before, "base_index unchanged by primary swap")
	ch.apply_palette_index(iid, "body_chest", "accent_index", 9999)
	assert_eq(int(ch.get_part_shader_parameter(iid, "body_chest", "accent_index")), 255, "oversized index clamps to 255")
	ch.free()

func _test_character_palette_bad_channel_key() -> void:
	# Unknown channel keys are rejected (§20), not silently ignored.
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid := ch.create_character("TravellerHuman", Vector3.ZERO)
	assert_true(iid != "", "character created")
	assert_false(ch.apply_palette_index(iid, "body_chest", "bogus_channel", 10), "unknown channel key rejected")
	assert_false(ch.apply_palette_index(iid, "body_chest", "emission_index", 10), "emission_index is not a palette-swap channel")
	assert_true(ch.apply_palette_index(iid, "body_chest", "accent_index", 10), "known channel key accepted")
	ch.free()

func _test_character_material_shader_shared() -> void:
	# All parts share ONE shader AND ONE material resource (§20); only
	# per-instance parameters differ. Parts on different characters reference the
	# same Shader and the same ShaderMaterial instance.
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid := ch.create_character("TravellerHuman", Vector3.ZERO)
	var iid2 := ch.create_character("BoarRider", Vector3.ZERO)
	assert_true(iid != "" and iid2 != "", "characters created")
	var m1 := ch.get_part_material(iid, "body_chest")
	var m2 := ch.get_part_material(iid2, "body")
	assert_true(m1 is ShaderMaterial and m2 is ShaderMaterial, "parts use ShaderMaterial")
	assert_true(m1.shader == m2.shader, "parts share the same shader resource")
	assert_true(m1 == m2, "parts share ONE material resource (per-instance params live on the mesh)")
	ch.free()

func _test_character_wear_channel() -> void:
	# Wear derives from the durability tiers (§23): a low-durability equipment
	# mesh carries a higher `wear` shader parameter than a fresh one, degrading
	# it visually. Wear is a discrete tier value, not `1 - durability`.
	var ch := CharacterSlice.new()
	add_child(ch)
	var worn_iid := ch.create_character_from_recipe({
		"skeleton": "HumanoidSkeleton",
		"equipment": { "MainHand": { "item": "VeilsteelLongsword", "state": "equipped", "durability": 0.1 } },
	}, Vector3.ZERO)
	var fresh_iid := ch.create_character_from_recipe({
		"skeleton": "HumanoidSkeleton",
		"equipment": { "MainHand": { "item": "VeilsteelLongsword", "state": "equipped", "durability": 1.0 } },
	}, Vector3.ZERO)
	var worn: float = float(ch.get_part_shader_parameter(worn_iid, "MainHand", "wear"))
	var fresh: float = float(ch.get_part_shader_parameter(fresh_iid, "MainHand", "wear"))
	assert_true(worn > fresh, "worn equipment carries higher wear than fresh")
	assert_true(is_equal_approx(worn, 1.0), "wear = Heavily Damaged tier (1.0) at durability 0.1")
	assert_true(is_equal_approx(fresh, 0.0), "wear = New tier (0.0) at durability 1.0")
	ch.free()

func _test_character_metal_channel() -> void:
	# RIGID metal equipment is palette-driven but metallic (§21): its mesh
	# carries metalness = 1 (from masks.metal) and a metals-region base index
	# (160–191), not a hardcoded RGB — metal colours flow through the shared
	# palette.
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid := ch.create_character_from_recipe({
		"skeleton": "HumanoidSkeleton",
		"equipment": { "OffHand": { "item": "FerriteShield", "state": "equipped", "durability": 1.0 } },
	}, Vector3.ZERO)
	assert_true(iid != "", "character created")
	assert_eq(float(ch.get_part_shader_parameter(iid, "OffHand", "metalness")), 1.0, "metal equipment is metallic")
	var base: int = int(ch.get_part_shader_parameter(iid, "OffHand", "base_index"))
	assert_true(base >= 160 and base <= 191, "metal base index is in the metals region (160–191)")
	ch.free()

func _test_character_emission_path() -> void:
	# Emission (§22) is palette-driven: an item with an emission mask resolves a
	# palette index in the emission region (192–223) from its emissionColor field.
	var ch := CharacterSlice.new()
	add_child(ch)
	var def := {
		"deformationMode": "RIGID",
		"metal": "none",
		"masks": { "primary": true, "metal": false, "emission": true },
		"emissionColor": 205,
	}
	var opts := ch._equipment_material_opts(def, { "durability": 1.0 })
	assert_true(opts.has("emission_index"), "emission items carry an emission_index")
	assert_true(int(opts["emission_index"]) >= 192 and int(opts["emission_index"]) <= 223, "emission_index in the emission region (192–223)")
	assert_eq(int(opts["emission_index"]), 205, "emission_index reflects the item's emissionColor field")
	assert_eq(float(opts["emission_strength"]), 1.0, "emission items have emission_strength = 1")
	var nondef := {
		"deformationMode": "RIGID",
		"metal": "none",
		"masks": { "primary": true, "metal": false, "emission": false },
		"emissionColor": 205,
	}
	var nonopts := ch._equipment_material_opts(nondef, { "durability": 1.0 })
	assert_false(nonopts.has("emission_index"), "non-emission items omit emission_index")
	assert_eq(float(nonopts["emission_strength"]), 0.0, "non-emission items have emission_strength = 0")
	ch.free()

func _test_character_instance_uniforms_reach_shader() -> void:
	# set_instance_shader_parameter only reaches the shader when the uniform is
	# declared `instance uniform`; get_instance_shader_parameter reads the stored
	# value back regardless, so the round-trip tests can't catch a missing
	# `instance` keyword. Instance uniforms are excluded from
	# get_shader_uniform_list() (they're per-instance, not per-material), so
	# assert the 9 palette/channel uniforms are NOT in that list.
	var shader: Shader = load("res://src/character/character_material.gdshader")
	assert_true(shader != null, "character material shader loads")
	var material_uniforms := {}
	for u in shader.get_shader_uniform_list():
		material_uniforms[str(u["name"])] = true
	var instance_uniforms := ["base_index", "primary_index", "secondary_index", "accent_index", "emission_index", "metalness", "emission_strength", "roughness", "wear"]
	for key in instance_uniforms:
		assert_false(material_uniforms.has(key), "uniform '%s' is instance-scoped (a regular uniform would be a no-op write)" % key)
	# The shared samplers remain material-level uniforms (bound once on the shared
	# material), so they DO appear in the list.
	assert_true(material_uniforms.has("palette_tex"), "palette_tex remains a material-level uniform")
	assert_true(material_uniforms.has("detail_tex"), "detail_tex remains a material-level uniform")

func _test_character_mesh_shared() -> void:
	# Parts with identical extents share one BoxMesh resource (§43 / Phase 22
	# mesh-sharing criterion): two instances of the same appearance have the same
	# proportions, so their body boxes share one BoxMesh.
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid1 := ch.create_character("TravellerHuman", Vector3.ZERO)
	var iid2 := ch.create_character("TravellerHuman", Vector3.ZERO)
	assert_true(iid1 != "" and iid2 != "", "characters created")
	var n1 := ch.get_part_node(iid1, "body_chest") as MeshInstance3D
	var n2 := ch.get_part_node(iid2, "body_chest") as MeshInstance3D
	assert_true(n1 != null and n2 != null, "body parts exist")
	assert_true(n1.mesh is BoxMesh and n2.mesh is BoxMesh, "parts use a BoxMesh")
	assert_true(n1.mesh == n2.mesh, "same-size parts share one BoxMesh resource")
	ch.free()

func _test_character_proportions_quantized() -> void:
	# Nearby proportion sliders snap to the same PROPORTION_STEP bucket (§8), so
	# characters with slightly different sliders still derive identical extents
	# and share one placeholder mesh — and the mesh size stays on the same grid as
	# the socket position (no extent/position seam).
	var ch := CharacterSlice.new()
	add_child(ch)
	var recipe := ch.deserialize_appearance({
		"skeleton": "HumanoidSkeleton",
		"proportions": { "height": 0.96, "bodyMass": 1.04, "shoulderWidth": 1.07 },
	})
	var props: Dictionary = recipe["proportions"]
	assert_true(is_equal_approx(props["height"], 0.95), "0.96 snaps to the 0.95 bucket")
	assert_true(is_equal_approx(props["bodyMass"], 1.05), "1.04 snaps to the 1.05 bucket")
	assert_true(is_equal_approx(props["shoulderWidth"], 1.05), "1.07 snaps to the 1.05 bucket")
	ch.free()

# ---------------------------------------------------------------------------
# CraftingSlice tests
# ---------------------------------------------------------------------------

func _test_crafting_recipe_data_loaded() -> void:
	var c := CraftingSlice.new()
	add_child(c)
	var recipe := c.get_recipe("RecipeFerritePick")
	assert_false(recipe.is_empty(), "RecipeFerritePick has structured recipe data")
	assert_eq(recipe["outputs"][0]["item"], "FerritePick", "output item is FerritePick")
	assert_eq(recipe["inputs"][0]["item"], "FerriteIngot", "first input is FerriteIngot")
	c.free()

func _test_crafting_skill_guard_blocks() -> void:
	var c := CraftingSlice.new()
	add_child(c)
	var inv := InventorySlice.new()
	add_child(inv)
	c.inventory_slice = inv
	# Default tier is novice; RecipeVoidRuneTablet requires VoidSmithing: expert.
	var result := c.craft("RecipeVoidRuneTablet")
	assert_false(result["success"], "craft fails without required skill tier")
	assert_true(str(result["reason"]).begins_with("skill_requirement"), "reason is a skill requirement")
	c.free()
	inv.free()

func _test_crafting_consumes_and_produces() -> void:
	var c := CraftingSlice.new()
	add_child(c)
	var inv := InventorySlice.new()
	add_child(inv)
	c.inventory_slice = inv
	inv.add_item("Ferrite", 4)
	c.set_skill("Smithing", "novice")
	var result := c.craft("RecipeFerriteIngot")
	assert_true(result["success"], "FerriteIngot craft succeeds")
	assert_eq(inv.get_item_count("Ferrite"), 2, "2 Ferrite remain (4 - 2 consumed)")
	assert_eq(inv.get_item_count("FerriteIngot"), 1, "1 FerriteIngot produced")
	c.free()
	inv.free()

func _test_crafting_missing_inputs() -> void:
	var c := CraftingSlice.new()
	add_child(c)
	var inv := InventorySlice.new()
	add_child(inv)
	c.inventory_slice = inv
	c.set_skill("Smithing", "novice")
	var result := c.craft("RecipeFerriteIngot")
	assert_false(result["success"], "craft fails without inputs")
	assert_eq(result["reason"], "missing_inputs", "reason is missing_inputs")
	c.free()
	inv.free()

func _test_crafting_unknown_recipe() -> void:
	var c := CraftingSlice.new()
	add_child(c)
	var inv := InventorySlice.new()
	add_child(inv)
	c.inventory_slice = inv
	var result := c.craft("DoesNotExist")
	assert_false(result["success"], "unknown recipe rejected")
	assert_eq(result["reason"], "unknown_recipe", "reason is unknown_recipe")
	c.free()
	inv.free()

func _test_crafting_can_craft_no_mutate() -> void:
	var c := CraftingSlice.new()
	add_child(c)
	var inv := InventorySlice.new()
	add_child(inv)
	c.inventory_slice = inv
	inv.add_item("Ferrite", 2)
	c.set_skill("Smithing", "novice")
	var check := c.can_craft("RecipeFerriteIngot")
	assert_true(check["success"], "can_craft returns true when craftable")
	assert_eq(inv.get_item_count("Ferrite"), 2, "can_craft does not consume inputs")
	c.free()
	inv.free()

# ---------------------------------------------------------------------------
# StationSlice tests (Phase 16 station-gated crafting)
# ---------------------------------------------------------------------------

func _test_station_gate_blocks() -> void:
	var station := StationSlice.new()
	add_child(station)
	var craft := CraftingSlice.new()
	add_child(craft)
	var inv := InventorySlice.new()
	add_child(inv)
	craft.inventory_slice = inv
	craft.station_slice = station
	inv.add_item("Ferrite", 2)
	craft.set_skill("Smithing", "novice")
	# Player at origin with no station placed → RecipeFerriteIngot (forge) blocked.
	station.set_player_position(Vector3.ZERO)
	var result := craft.craft("RecipeFerriteIngot")
	assert_false(result["success"], "craft blocked without a nearby forge")
	assert_true(str(result["reason"]).begins_with("station_required"), "reason is station_required")
	station.free()
	craft.free()
	inv.free()

func _test_station_gate_passes() -> void:
	var station := StationSlice.new()
	add_child(station)
	var craft := CraftingSlice.new()
	add_child(craft)
	var inv := InventorySlice.new()
	add_child(inv)
	craft.inventory_slice = inv
	craft.station_slice = station
	inv.add_item("Ferrite", 2)
	craft.set_skill("Smithing", "novice")
	station.set_player_position(Vector3.ZERO)
	station.place_station("forge", Vector3(1.0, 0.0, 0.0))
	var result := craft.craft("RecipeFerriteIngot")
	assert_true(result["success"], "craft succeeds with a forge nearby")
	assert_eq(inv.get_item_count("FerriteIngot"), 1, "FerriteIngot produced")
	station.free()
	craft.free()
	inv.free()

func _test_station_wrong_type_blocks() -> void:
	var station := StationSlice.new()
	add_child(station)
	var craft := CraftingSlice.new()
	add_child(craft)
	var inv := InventorySlice.new()
	add_child(inv)
	craft.inventory_slice = inv
	craft.station_slice = station
	inv.add_item("Ferrite", 2)
	craft.set_skill("Smithing", "novice")
	station.set_player_position(Vector3.ZERO)
	# Place a carpentry bench — not a forge — so RecipeFerriteIngot (forge) stays blocked.
	station.place_station("carpentry bench", Vector3(1.0, 0.0, 0.0))
	var result := craft.craft("RecipeFerriteIngot")
	assert_false(result["success"], "craft blocked when only a wrong-type station is nearby")
	assert_true(str(result["reason"]).begins_with("station_required"), "reason is station_required")
	station.free()
	craft.free()
	inv.free()

func _test_station_carpentry_bench() -> void:
	var station := StationSlice.new()
	add_child(station)
	var craft := CraftingSlice.new()
	add_child(craft)
	var inv := InventorySlice.new()
	add_child(inv)
	craft.inventory_slice = inv
	craft.station_slice = station
	inv.add_item("Thornwood", 2)
	craft.set_skill("Carpentry", "novice")
	station.set_player_position(Vector3.ZERO)
	station.place_station("carpentry bench", Vector3(1.0, 0.0, 0.0))
	var result := craft.craft("RecipeThornwoodPlank")
	assert_true(result["success"], "RecipeThornwoodPlank succeeds next to a carpentry bench")
	assert_eq(inv.get_item_count("ThornwoodPlank"), 3, "3 ThornwoodPlanks produced")
	station.free()
	craft.free()
	inv.free()

func _test_station_master_forge() -> void:
	var station := StationSlice.new()
	add_child(station)
	var craft := CraftingSlice.new()
	add_child(craft)
	var inv := InventorySlice.new()
	add_child(inv)
	craft.inventory_slice = inv
	craft.station_slice = station
	inv.add_item("FerriteIngot", 3)
	inv.add_item("AethermiteShard", 1)
	craft.set_skill("Smithing", "journeyman")
	station.set_player_position(Vector3.ZERO)
	# A plain forge must NOT satisfy the master forge requirement.
	station.place_station("forge", Vector3(1.0, 0.0, 0.0))
	var blocked := craft.craft("RecipeVeilsteelIngot")
	assert_false(blocked["success"], "RecipeVeilsteelIngot blocked next to a plain forge")
	# Re-stock inputs and place a master forge.
	inv.add_item("FerriteIngot", 3)
	inv.add_item("AethermiteShard", 1)
	station.place_station("master forge", Vector3(-1.0, 0.0, 0.0))
	var result := craft.craft("RecipeVeilsteelIngot")
	assert_true(result["success"], "RecipeVeilsteelIngot succeeds next to a master forge")
	assert_eq(inv.get_item_count("VeilsteelIngot"), 1, "VeilsteelIngot produced")
	station.free()
	craft.free()
	inv.free()

func _test_station_nearest_ignores_wrong_type() -> void:
	var station := StationSlice.new()
	add_child(station)
	station.set_player_position(Vector3.ZERO)
	station.place_station("carpentry bench", Vector3(1.0, 0.0, 0.0))
	station.place_station("forge", Vector3(100.0, 0.0, 0.0))   # far away
	# nearest_station("forge", 5.0) should return "" — the forge is outside radius.
	var near_forge := station.nearest_station(Vector3.ZERO, "forge", 5.0)
	assert_eq(near_forge, "", "no forge within radius 5 — carpentry bench is not counted")
	var near_bench := station.nearest_station(Vector3.ZERO, "carpentry bench", 5.0)
	assert_true(near_bench != "", "carpentry bench within radius 5 found")
	station.free()

func _test_station_all_canonical_types() -> void:
	var station := StationSlice.new()
	add_child(station)
	station.set_player_position(Vector3.ZERO)
	var types: Array = station.placeable_station_types()
	assert_true(types.size() >= 4, "at least 4 station types in the fabric")
	for i in range(types.size()):
		var t: String = str(types[i])
		var sid := station.place_station(t, Vector3(float(i), 0.0, 0.0))
		assert_true(sid != "", "place_station('%s') returns a non-empty id" % t)
		assert_true(station.station_near_player(t, 200.0), "station_near_player finds '%s'" % t)
	station.free()

# ---------------------------------------------------------------------------
# Inventory durability tests (Phase 16 tool durability)
# ---------------------------------------------------------------------------

func _test_durability_use_decrements() -> void:
	var inv := InventorySlice.new()
	add_child(inv)
	inv.add_item("FerritePick", 1)
	var max_d := inv.get_max_durability("FerritePick")
	assert_true(max_d > 0.0, "FerritePick has a durability model")
	assert_eq(inv.get_durability("FerritePick"), max_d, "fresh tool starts at max durability")
	var ok := inv.use_item("FerritePick", "mine")
	assert_true(ok, "use succeeds while tool has durability")
	assert_eq(inv.get_durability("FerritePick"), max_d - 1.0, "durability decremented by one")
	inv.free()

func _test_durability_broken_emits() -> void:
	var inv := InventorySlice.new()
	add_child(inv)
	inv.add_item("FerritePick", 1)
	var broke := {}
	GameBus.item_broke.connect(func(iid): broke["id"] = iid)
	# Force the tool to one remaining point, then use it past the break.
	inv._durability["FerritePick"] = 1.0
	var ok := inv.use_item("FerritePick", "mine")
	assert_true(ok, "the use that consumes the last point still succeeds")
	assert_eq(broke.get("id", ""), "FerritePick", "item_broke emitted for FerritePick")
	assert_eq(inv.get_durability("FerritePick"), 0.0, "durability clamped at 0")
	# A broken tool blocks further use and re-emits item_broke.
	broke.clear()
	var ok2 := inv.use_item("FerritePick", "mine")
	assert_false(ok2, "broken tool blocks further use")
	assert_eq(broke.get("id", ""), "FerritePick", "item_broke re-emitted on broken use")
	inv.free()

func _test_durability_stackable_excluded() -> void:
	var inv := InventorySlice.new()
	add_child(inv)
	# Stackable items carry a durability field (structural integrity / freshness)
	# but must NOT be treated as per-instance equipment.
	assert_false(inv.is_durable("FerriteIngot"), "stackable material is not durable equipment")
	assert_false(inv.is_durable("ThornwoodPlank"), "stackable component is not durable equipment")
	assert_false(inv.is_durable("FieldRations"), "stackable food is not durable equipment")
	# Non-stackable tools / weapons / armour are durable.
	assert_true(inv.is_durable("FerritePick"), "non-stackable tool is durable")
	assert_true(inv.is_durable("VeilsteelLongsword"), "non-stackable weapon is durable")
	assert_true(inv.is_durable("FerriteShield"), "non-stackable shield is durable")
	inv.free()

func _test_durability_find_tool() -> void:
	var inv := InventorySlice.new()
	add_child(inv)
	assert_eq(inv.find_tool("pick"), "", "no tool held when inventory empty")
	inv.add_item("FerritePick", 1)
	inv.add_item("VeilsteelPick", 1)
	inv.add_item("CarpenterAxe", 1)
	# find_tool matches on the fabric toolType, not the item name.
	assert_eq(inv.find_tool("pick"), "FerritePick", "find_tool returns a held pick")
	assert_eq(inv.find_tool("axe"), "CarpenterAxe", "find_tool returns the held axe")
	# A non-tool durable item (a weapon) has no toolType and never matches.
	inv.add_item("FerriteShortSword", 1)
	assert_eq(inv.find_tool("pick"), "FerritePick", "a weapon is not a mining tool")
	inv.free()

func _test_station_types_from_fabric() -> void:
	var station := StationSlice.new()
	add_child(station)
	var types: Array = station.placeable_station_types()
	assert_true(types.has("forge"), "forge derived from recipe station fields")
	assert_true(types.has("alchemy bench"), "alchemy bench derived from recipe station fields")
	assert_true(types.size() >= 2, "multiple station types exist")
	station.free()


func _test_durability_drop_repick_resets() -> void:
	var inv := InventorySlice.new()
	add_child(inv)
	# Pick up a FerritePick, use it once to wear it, then drop it.
	inv.add_item("FerritePick", 1)
	var max_d := inv.get_max_durability("FerritePick")
	inv.use_item("FerritePick", "mine")
	assert_eq(inv.get_durability("FerritePick"), max_d - 1.0, "durability decremented after use")
	inv.drop_item("FerritePick", 1)
	assert_eq(inv.get_item_count("FerritePick"), 0, "pick dropped from inventory")
	# Pick up a fresh FerritePick — durability must be full again.
	inv.add_item("FerritePick", 1)
	assert_eq(inv.get_durability("FerritePick"), max_d, "repicked tool starts at max durability")
	inv.free()

func _test_durability_find_tool_skips_broken() -> void:
	var inv := InventorySlice.new()
	add_child(inv)
	inv.add_item("FerritePick", 1)
	inv.add_item("VeilsteelPick", 1)
	# Break both picks — find_tool must return "".
	inv._durability["VeilsteelPick"] = 0.0
	inv._durability["FerritePick"] = 0.0
	var none := inv.find_tool("pick")
	assert_eq(none, "", "find_tool returns empty when all picks are broken")
	# Restore one pick's durability — find_tool must return it now.
	inv._durability.erase("FerritePick")   # erase so _ensure_durability reinits to max
	var found := inv.find_tool("pick")
	assert_eq(found, "FerritePick", "find_tool returns FerritePick once restored")
	inv.free()


# ---------------------------------------------------------------------------
# TechnologySlice tests (research gates)
# ---------------------------------------------------------------------------

func _test_technology_recipe_resolves_to_tech() -> void:
	var t := TechnologySlice.new()
	add_child(t)
	assert_eq(t.get_recipe_tech("RecipeFerriteIngot"), "TechBasicSmithing", "FerriteIngot belongs to TechBasicSmithing")
	assert_eq(t.get_recipe_tech("RecipeVoidRuneTablet"), "TechVoidMastery", "VoidRuneTablet belongs to TechVoidMastery")
	t.free()

func _test_technology_research_requires_prereq() -> void:
	var t := TechnologySlice.new()
	add_child(t)
	# TechMasterForge requires TechBasicSmithing (still locked).
	var result := t.begin_research("TechMasterForge")
	assert_false(result["success"], "research blocked without prerequisite")
	assert_true(str(result["reason"]).begins_with("prerequisite_locked"), "reason is a prerequisite gate")
	t.free()

func _test_technology_research_consumes_materials() -> void:
	var t := TechnologySlice.new()
	add_child(t)
	var inv := InventorySlice.new()
	add_child(inv)
	t.inventory_slice = inv
	inv.add_item("Ferrite", 4)
	var result := t.begin_research("TechBasicSmithing")
	assert_true(result["success"], "research begins with materials present")
	assert_eq(t.get_status("TechBasicSmithing"), "researching", "status is researching")
	assert_eq(inv.get_item_count("Ferrite"), 0, "Ferrite material cost consumed")
	t.free()
	inv.free()

func _test_technology_complete_unlocks() -> void:
	var t := TechnologySlice.new()
	add_child(t)
	var inv := InventorySlice.new()
	add_child(inv)
	t.inventory_slice = inv
	inv.add_item("Ferrite", 4)
	t.begin_research("TechBasicSmithing")
	var result := t.complete_research("TechBasicSmithing")
	assert_true(result["success"], "complete research succeeds")
	assert_eq(t.get_status("TechBasicSmithing"), "unlocked", "status is unlocked")
	assert_true(t.is_recipe_unlocked("RecipeFerriteIngot"), "recipe now unlocked")
	t.free()
	inv.free()

func _test_technology_crafting_blocked_locked() -> void:
	var t := TechnologySlice.new()
	add_child(t)
	var c := CraftingSlice.new()
	add_child(c)
	var inv := InventorySlice.new()
	add_child(inv)
	c.inventory_slice = inv
	c.technology_slice = t
	inv.add_item("Ferrite", 2)
	c.set_skill("Smithing", "novice")
	var result := c.craft("RecipeFerriteIngot")
	assert_false(result["success"], "craft blocked while technology locked")
	assert_true(str(result["reason"]).begins_with("technology_locked"), "reason is a technology gate")
	t.free()
	c.free()
	inv.free()

func _test_technology_crafting_allowed_after_unlock() -> void:
	var t := TechnologySlice.new()
	add_child(t)
	var c := CraftingSlice.new()
	add_child(c)
	var inv := InventorySlice.new()
	add_child(inv)
	c.inventory_slice = inv
	c.technology_slice = t
	t.inventory_slice = inv
	inv.add_item("Ferrite", 6)   # 4 for research + 2 for the craft
	c.set_skill("Smithing", "novice")
	assert_true(t.begin_research("TechBasicSmithing")["success"], "begin research succeeds")
	assert_true(t.complete_research("TechBasicSmithing")["success"], "complete research succeeds")
	var result := c.craft("RecipeFerriteIngot")
	assert_true(result["success"], "craft succeeds after technology unlocked")
	assert_eq(inv.get_item_count("FerriteIngot"), 1, "ingot produced")
	t.free()
	c.free()
	inv.free()

func _test_technology_unknown_rejected() -> void:
	var t := TechnologySlice.new()
	add_child(t)
	var result := t.begin_research("DoesNotExist")
	assert_false(result["success"], "unknown technology rejected")
	assert_eq(result["reason"], "unknown_technology", "reason is unknown_technology")
	t.free()

# ---------------------------------------------------------------------------
# VoxelSlice tests (mining & building)
# ---------------------------------------------------------------------------

## Build a VoxelSlice over a flat 2.0-tall synthetic chunk (deterministic).
func _make_voxel() -> VoxelSlice:
	var v := VoxelSlice.new()
	add_child(v)
	var hm: Array = []
	hm.resize(32 * 32)
	hm.fill(2.0)
	v.build_chunk(Vector2i(0, 0), hm)
	return v

func _test_voxel_mine_yields_material() -> void:
	var v := _make_voxel()
	var inv := InventorySlice.new()
	add_child(inv)
	v.inventory_slice = inv
	assert_eq(v.get_voxel_height_at(Vector2(16.0, 16.0)), 2.0, "flat chunk height is 2.0")
	var r := v.mine_block(Vector3(16.5, 2.0, 16.5))
	assert_true(r.get("success", false), "mine succeeds on a 2.0-tall column")
	assert_eq(v.get_voxel_height_at(Vector2(16.0, 16.0)), 1.5, "height lowered by STEP_HEIGHT")
	assert_true(GameData.MATERIALS.has(r.get("material", "")), "yielded a valid fabric material")
	assert_eq(inv.get_item_count(str(r.get("material", ""))), 1, "material added to inventory")
	v.free()
	inv.free()

func _test_voxel_mine_bedrock() -> void:
	var v := _make_voxel()
	v.apply_edits({ "16,16": 0.0 })
	var r := v.mine_block(Vector3(16.5, 0.0, 16.5))
	assert_false(r.get("success", false), "mining at bedrock fails")
	v.free()

func _test_voxel_mine_side_face() -> void:
	var v := _make_voxel()
	var inv := InventorySlice.new()
	add_child(inv)
	v.inventory_slice = inv
	# East-facing face (normal +X) at x=17.0: the hit block is tile 16 (west).
	v.mine_block(Vector3(17.0, 1.5, 16.5), Vector3(1, 0, 0))
	assert_eq(v.get_voxel_height_at(Vector2(16.0, 16.0)), 1.5, "+X face mines the block west of the boundary")
	assert_eq(v.get_voxel_height_at(Vector2(17.0, 16.0)), 2.0, "east block untouched")
	# West-facing face (normal -X) at x=19.0: the hit block is tile 19 (east).
	v.mine_block(Vector3(19.0, 1.5, 16.5), Vector3(-1, 0, 0))
	assert_eq(v.get_voxel_height_at(Vector2(19.0, 16.0)), 1.5, "-X face mines the block east of the boundary")
	assert_eq(v.get_voxel_height_at(Vector2(18.0, 16.0)), 2.0, "west block untouched")
	v.free()
	inv.free()

func _test_voxel_cycle_inventory_filtered() -> void:
	var v := _make_voxel()
	var inv := InventorySlice.new()
	add_child(inv)
	v.inventory_slice = inv
	inv.add_item("Ashite", 2)
	inv.add_item("Thornwood", 1)
	v.set_place_material("Ashite")
	assert_eq(v.cycle_place_material(), "Thornwood", "cycles to the other held material")
	assert_eq(v.cycle_place_material(), "Ashite", "wraps back, skipping materials not held")
	v.free()
	inv.free()

func _test_voxel_place_consumes() -> void:
	var v := _make_voxel()
	var inv := InventorySlice.new()
	add_child(inv)
	v.inventory_slice = inv
	v.set_place_material("Ashite")
	inv.add_item("Ashite", 3)
	var ok := v.place_block(Vector3(16.5, 2.0, 16.5), Vector3.UP)
	assert_true(ok, "place succeeds")
	assert_eq(v.get_voxel_height_at(Vector2(16.0, 16.0)), 2.5, "height raised by STEP_HEIGHT")
	assert_eq(inv.get_item_count("Ashite"), 2, "Ashite consumed from inventory")
	v.free()
	inv.free()

func _test_voxel_place_cap() -> void:
	var v := _make_voxel()
	var inv := InventorySlice.new()
	add_child(inv)
	v.inventory_slice = inv
	v.set_place_material("Ashite")
	inv.add_item("Ashite", 1)
	v.apply_edits({ "16,16": v.MAX_HEIGHT })
	var ok := v.place_block(Vector3(16.5, v.MAX_HEIGHT, 16.5), Vector3.UP)
	assert_false(ok, "place beyond build cap fails")
	assert_eq(inv.get_item_count("Ashite"), 1, "blocked placement refunds the material")
	v.free()
	inv.free()

func _test_voxel_biome_materials() -> void:
	var v := VoxelSlice.new()
	var volcanic: Array = []
	for i in range(16):
		volcanic.append(v.material_for_biome("VolcanicBadlands", Vector2(i, 0)))
	assert_true(volcanic.has("Ashite") or volcanic.has("Aethermite"), "volcanic yields ashite/aethermite")
	var temperate: Array = []
	for i in range(16):
		temperate.append(v.material_for_biome("TemperateForest", Vector2(i, 0)))
	assert_true(temperate.has("Ferrite") or temperate.has("Thornwood"), "temperate yields ferrite/thornwood")
	v.free()

func _test_voxel_edits_round_trip() -> void:
	var v := _make_voxel()
	v.apply_edits({ "16,16": 1.0, "17,17": 3.5 })
	assert_eq(v.get_edits().get("16,16", 0.0), 1.0, "edit 16,16 survives")
	assert_eq(v.get_voxel_height_at(Vector2(16.0, 16.0)), 1.0, "height reflects restored edit")
	assert_eq(v.get_voxel_height_at(Vector2(17.0, 17.0)), 3.5, "second edit restored")
	v.free()

func _test_voxel_placed_block_keeps_material_color() -> void:
	var v := _make_voxel()
	var inv := InventorySlice.new()
	add_child(inv)
	v.inventory_slice = inv
	# Find a tile whose biome material is NOT Ferrite so the colour change is
	# unambiguous (the synthetic chunk has no terrain_slice → TemperateForest).
	var tile := Vector2i(-1, -1)
	for tz in range(32):
		for tx in range(32):
			if v.material_for_biome("TemperateForest", Vector2(tx, tz)) != "Ferrite":
				tile = Vector2i(tx, tz)
				break
		if tile.x >= 0:
			break
	assert_true(tile.x >= 0, "found a non-Ferrite tile in the test chunk")
	v.set_place_material("Ferrite")
	inv.add_item("Ferrite", 1)
	var center := Vector2(tile.x + 0.5, tile.y + 0.5)
	assert_true(v.place_block(Vector3(center.x, 2.0, center.y), Vector3.UP), "place succeeds")
	assert_eq(v._column_color(center), VoxelSlice.MATERIAL_COLORS["Ferrite"], "placed block renders Ferrite colour, not biome colour")
	v.free()
	inv.free()

func _test_voxel_mine_placed_block_yields_material() -> void:
	var v := _make_voxel()
	var inv := InventorySlice.new()
	add_child(inv)
	v.inventory_slice = inv
	v.set_place_material("Thornwood")
	inv.add_item("Thornwood", 1)
	assert_true(v.place_block(Vector3(16.5, 2.0, 16.5), Vector3.UP), "place Thornwood succeeds")
	var r := v.mine_block(Vector3(16.5, 2.5, 16.5))
	assert_true(r.get("success", false), "mine succeeds")
	assert_eq(str(r.get("material", "")), "Thornwood", "mining a placed block yields its own material")
	assert_eq(v.get_voxel_height_at(Vector2(16.0, 16.0)), 2.0, "height back to natural after mining")
	v.free()
	inv.free()

func _test_voxel_placed_block_preserves_base_colour() -> void:
	var v := _make_voxel()
	var inv := InventorySlice.new()
	add_child(inv)
	v.inventory_slice = inv
	# Place Ferrite on a tile whose biome material is NOT Ferrite, then check the
	# column renders as two distinct layers: natural base (biome colour) + the
	# placed block (Ferrite colour) — the base must NOT be recoloured.
	var tile := Vector2i(-1, -1)
	for tz in range(32):
		for tx in range(32):
			if v.material_for_biome("TemperateForest", Vector2(tx, tz)) != "Ferrite":
				tile = Vector2i(tx, tz)
				break
		if tile.x >= 0:
			break
	assert_true(tile.x >= 0, "found a non-Ferrite tile in the test chunk")
	v.set_place_material("Ferrite")
	inv.add_item("Ferrite", 1)
	var center := Vector2(tile.x + 0.5, tile.y + 0.5)
	assert_true(v.place_block(Vector3(center.x, 2.0, center.y), Vector3.UP), "place succeeds")
	var layers: Array = v._column_layers(Vector2i(0, 0), v._heightmaps["0,0"], tile.x, tile.y)
	assert_true(layers.size() >= 2, "column has natural + placed layers")
	assert_eq(layers[0]["color"], v._natural_color(center), "natural base keeps its biome colour")
	assert_eq(layers[-1]["color"], VoxelSlice.MATERIAL_COLORS["Ferrite"], "placed block renders Ferrite colour")
	v.free()
	inv.free()

func _test_voxel_place_after_mine_keeps_colour() -> void:
	var v := _make_voxel()
	var inv := InventorySlice.new()
	add_child(inv)
	v.inventory_slice = inv
	# Find a non-Ferrite (e.g. Thornwood) tile to mine.
	var tile := Vector2i(-1, -1)
	for tz in range(32):
		for tx in range(32):
			if v.material_for_biome("TemperateForest", Vector2(tx, tz)) != "Ferrite":
				tile = Vector2i(tx, tz)
				break
		if tile.x >= 0:
			break
	assert_true(tile.x >= 0, "found a non-Ferrite tile in the test chunk")
	var center := Vector2(tile.x + 0.5, tile.y + 0.5)
	var mine_pos := Vector3(center.x, 2.0, center.y)
	# Mine the natural top block (yields the biome material, e.g. Thornwood).
	assert_true(v.mine_block(mine_pos).get("success", false), "mine natural succeeds")
	# Place Ferrite back in the same column.
	v.set_place_material("Ferrite")
	inv.add_item("Ferrite", 1)
	assert_true(v.place_block(mine_pos, Vector3.UP), "place Ferrite succeeds")
	var layers: Array = v._column_layers(Vector2i(0, 0), v._heightmaps["0,0"], tile.x, tile.y)
	assert_true(layers.size() >= 2, "column has natural + placed layers")
	assert_eq(layers[-1]["color"], VoxelSlice.MATERIAL_COLORS["Ferrite"], "placed Ferrite renders Ferrite colour, not the mined material's colour")
	v.free()
	inv.free()

# ---------------------------------------------------------------------------
# UiSlice tests (Phase 14 windows)
# ---------------------------------------------------------------------------

func _ui_row(rows: Array, id: String) -> Dictionary:
	for r in rows:
		if str(r["id"]) == id:
			return r
	return {}

func _test_ui_window_toggle() -> void:
	var ui := UiSlice.new()
	add_child(ui)
	assert_false(ui.any_window_open(), "no windows open initially")
	ui.toggle_window("inventory")
	assert_true(ui.is_window_open("inventory"), "inventory opens on toggle")
	assert_true(ui.any_window_open(), "any_window_open true after open")
	ui.toggle_window("technology")
	assert_true(ui.is_window_open("technology"), "technology opens independently")
	ui.toggle_window("inventory")
	assert_false(ui.is_window_open("inventory"), "inventory closes on second toggle")
	assert_true(ui.any_window_open(), "technology still open")
	ui.close_window("technology")
	assert_false(ui.any_window_open(), "all windows closed")
	ui.free()

func _test_ui_inventory_lines() -> void:
	var ui := UiSlice.new()
	add_child(ui)
	var inv := InventorySlice.new()
	add_child(inv)
	ui.inventory_slice = inv
	inv.add_item("Ferrite", 5)
	inv.add_item("Thornwood", 2)
	var lines: Array = ui.inventory_lines()
	assert_true(lines.has("Ferrite ×5"), "Ferrite line present")
	assert_true(lines.has("Thornwood ×2"), "Thornwood line present")
	ui.free()
	inv.free()

func _test_ui_crafting_rows_tech_gate() -> void:
	var ui := UiSlice.new()
	add_child(ui)
	var inv := InventorySlice.new()
	add_child(inv)
	var tech := TechnologySlice.new()
	add_child(tech)
	var craft := CraftingSlice.new()
	add_child(craft)
	ui.inventory_slice = inv
	ui.crafting_slice = craft
	ui.technology_slice = tech
	craft.inventory_slice = inv
	craft.technology_slice = tech
	tech.inventory_slice = inv
	craft.set_skill("Smithing", "novice")
	inv.add_item("Ferrite", 6)   # 4 for research + 2 for the craft
	var locked := _ui_row(ui.crafting_rows(), "RecipeFerriteIngot")
	assert_false(bool(locked["can_craft"]), "crafting blocked while tech locked")
	assert_true(str(locked["reason"]).begins_with("technology_locked"), "reason is technology_locked")
	assert_true(tech.begin_research("TechBasicSmithing")["success"], "begin research succeeds")
	assert_true(tech.complete_research("TechBasicSmithing")["success"], "complete research succeeds")
	var unlocked := _ui_row(ui.crafting_rows(), "RecipeFerriteIngot")
	assert_true(bool(unlocked["can_craft"]), "crafting allowed after unlock")
	ui.free()
	craft.free()
	tech.free()
	inv.free()

func _test_ui_technology_rows_status() -> void:
	var ui := UiSlice.new()
	add_child(ui)
	var tech := TechnologySlice.new()
	add_child(tech)
	var inv := InventorySlice.new()
	add_child(inv)
	ui.technology_slice = tech
	ui.inventory_slice = inv
	tech.inventory_slice = inv
	var root := _ui_row(ui.technology_rows(), "TechBasicSmithing")
	assert_eq(root["status"], "locked", "root tech starts locked")
	assert_true(bool(root["can_research"]), "root tech researchable (no prereqs)")
	var gated := _ui_row(ui.technology_rows(), "TechMasterForge")
	assert_false(bool(gated["can_research"]), "TechMasterForge gated by prereq")
	assert_true((gated["requires"] as Array).has("TechBasicSmithing"), "requires lists TechBasicSmithing")
	ui.free()
	tech.free()
	inv.free()

# ---------------------------------------------------------------------------
# CreatureAI tests (Phase 15)
# ---------------------------------------------------------------------------

## Build an isolated AI rig: CreatureSlice + CreatureAI + a minimal PlayerSlice
## stub (just needs get_position()).
func _make_ai_rig() -> Dictionary:
	var c := CreatureSlice.new()
	add_child(c)
	c.spawn_for_chunk(Vector2i(0, 0))
	var ai := CreatureAI.new()
	ai.creature_slice = c
	add_child(ai)
	return { "creature": c, "ai": ai }

func _test_ai_idle_to_alert() -> void:
	var rig := _make_ai_rig()
	var c: CreatureSlice = rig["creature"]
	var ai: CreatureAI   = rig["ai"]
	var instances := c.get_all_instances()
	assert_true(instances.size() > 0, "need at least one creature instance")
	# idle→alert only applies to NEUTRAL creatures (aggressionLevel == 1). Aggressive
	# creatures skip the alert state entirely, so select a NEUTRAL instance instead of
	# blindly using instances[0] (which is CinderGargoyle, aggressionLevel == 2).
	var iid := ""
	var pos := Vector3.ZERO
	for inst in instances:
		var res: Resource = GameData.CREATURES.get(inst["creature_id"], null)
		if res != null and int(res.get("aggressionLevel")) == 1:
			iid = inst["instance_id"]
			pos = inst["position"]
			break
	assert_true(iid != "", "need a NEUTRAL creature instance (aggressionLevel == 1)")
	ai.force_state(iid, "idle")
	# Place the "player" close enough to trigger alert (within ALERT_RADIUS_DEFAULT).
	var near_pos := pos + Vector3(1.0, 0.0, 0.0)
	# Simulate a tick via internal logic: transition should fire.
	var captured := {}
	GameBus.creature_alert.connect(func(id): captured["alert"] = id)
	ai._tick_instance(iid, c._instances[iid], near_pos, 0.1)
	assert_true(captured.get("alert", "") == iid, "creature_alert emitted for instance_id")
	assert_eq(ai.get_state(iid), "alert", "state is alert after player enters alertRadius")
	rig["creature"].free()
	rig["ai"].free()

func _test_ai_alert_to_aggressive() -> void:
	var rig := _make_ai_rig()
	var c: CreatureSlice = rig["creature"]
	var ai: CreatureAI   = rig["ai"]
	var instances := c.get_all_instances()
	assert_true(instances.size() > 0, "need at least one creature instance")
	var iid: String  = instances[0]["instance_id"]
	var pos: Vector3 = instances[0]["position"]
	ai.force_state(iid, "alert")
	# Place "player" within attackRadius.
	var attack_pos := pos + Vector3(0.5, 0.0, 0.0)
	var captured := {}
	GameBus.creature_aggressive.connect(func(id): captured["aggro"] = id)
	ai._tick_instance(iid, c._instances[iid], attack_pos, 0.1)
	assert_true(captured.get("aggro", "") == iid, "creature_aggressive emitted")
	assert_eq(ai.get_state(iid), "aggressive", "state is aggressive")
	rig["creature"].free()
	rig["ai"].free()

func _test_ai_aggressive_to_fleeing() -> void:
	var rig := _make_ai_rig()
	var c: CreatureSlice = rig["creature"]
	var ai: CreatureAI   = rig["ai"]
	var instances := c.get_all_instances()
	assert_true(instances.size() > 0, "need at least one creature instance")
	var iid: String  = instances[0]["instance_id"]
	var pos: Vector3 = instances[0]["position"]
	ai.force_state(iid, "aggressive")
	# Drain HP below flee threshold.
	var res: Resource = GameData.CREATURES.get(c._instances[iid]["creature_id"], null)
	var max_hp: float = float(res.get("baseHp")) if res else 100.0
	c._instances[iid]["hp"] = max_hp * 0.10   # 10 % < 20 % threshold
	var captured := {}
	GameBus.creature_fleeing.connect(func(id): captured["flee"] = id)
	ai._tick_instance(iid, c._instances[iid], pos + Vector3(1.0, 0.0, 0.0), 0.1)
	assert_true(captured.get("flee", "") == iid, "creature_fleeing emitted")
	assert_eq(ai.get_state(iid), "fleeing", "state is fleeing below flee threshold")
	rig["creature"].free()
	rig["ai"].free()

func _test_ai_fleeing_to_idle() -> void:
	var rig := _make_ai_rig()
	var c: CreatureSlice = rig["creature"]
	var ai: CreatureAI   = rig["ai"]
	var instances := c.get_all_instances()
	assert_true(instances.size() > 0, "need at least one creature instance")
	var iid: String  = instances[0]["instance_id"]
	var pos: Vector3 = instances[0]["position"]
	ai.force_state(iid, "fleeing")
	# Place player beyond safe_r (always base alertRadius * 1.5, regardless of aggression).
	var res: Resource = GameData.CREATURES.get(c._instances[iid]["creature_id"], null)
	var base_alert_r: float = float(res.get("alertRadius")) if res else 12.0
	var safe_r: float = base_alert_r * 1.5
	var far_pos := pos + Vector3(safe_r + 5.0, 0.0, 0.0)
	ai._tick_instance(iid, c._instances[iid], far_pos, 0.1)
	assert_eq(ai.get_state(iid), "idle", "creature relaxes to idle when player is far")
	rig["creature"].free()
	rig["ai"].free()

func _test_ai_attack_emits_combat() -> void:
	var rig := _make_ai_rig()
	var c: CreatureSlice = rig["creature"]
	var ai: CreatureAI   = rig["ai"]
	var instances := c.get_all_instances()
	assert_true(instances.size() > 0, "need at least one creature instance")
	var iid: String  = instances[0]["instance_id"]
	var pos: Vector3 = instances[0]["position"]
	ai.force_state(iid, "aggressive")
	# Pre-charge the attack timer so it fires on the next tick.
	ai._ai[iid]["attack_timer"] = CreatureAI.ATTACK_INTERVAL
	# Player within attack radius.
	var attack_pos := pos + Vector3(0.5, 0.0, 0.0)
	var captured := {}
	GameBus.combat_round_requested.connect(func(att, def): captured["att"] = att; captured["def"] = def)
	ai._tick_instance(iid, c._instances[iid], attack_pos, 0.01)
	assert_eq(captured.get("att", ""), iid, "attacker is the creature instance_id")
	assert_eq(captured.get("def", ""), "player", "defender is player")
	rig["creature"].free()
	rig["ai"].free()

func _test_player_respawn() -> void:
	const PlayerSlice := preload("res://src/player/player_slice.gd")
	var p := PlayerSlice.new()
	add_child(p)
	# Simulate death: drain HP to zero.
	p.take_damage(PlayerSlice.MAX_HP)
	assert_false(p._alive, "player is dead after lethal damage")
	assert_true(p._hp <= 0.0, "player HP at zero")
	# Force respawn timer to expire.
	p._respawn_timer = 0.001
	p._physics_process(1.0)   # one physics tick advances timer past 0
	assert_true(p._alive, "player alive after respawn")
	assert_eq(p._hp, PlayerSlice.MAX_HP, "player HP restored to max on respawn")
	p.free()

# ---------------------------------------------------------------------------
# Chunk streaming tests (Phase 17)
# ---------------------------------------------------------------------------

func _test_chunk_desired_set() -> void:
	var cm := ChunkManager.new()
	add_child(cm)
	var set1: Array = cm._desired_chunks(Vector2i(0, 0), 1)
	assert_eq(set1.size(), 9, "view distance 1 yields a 3x3 window")
	var set3: Array = cm._desired_chunks(Vector2i(0, 0), 3)
	assert_eq(set3.size(), 49, "view distance 3 yields a 7x7 window")
	assert_true(set1.has(Vector2i(0, 0)), "center chunk included")
	assert_true(set1.has(Vector2i(1, 1)), "corner chunk included at radius 1")
	cm.free()

func _test_chunk_coordinate_round_trip() -> void:
	var t := TerrainSlice.new()
	add_child(t)
	assert_eq(t.chunk_to_world(Vector2i(2, -3)), Vector2(64.0, -96.0), "chunk (2,-3) maps to world (64,-96)")
	assert_eq(t.world_to_chunk(Vector2(64.0, -96.0)), Vector2i(2, -3), "world round-trips to chunk")
	assert_eq(t.world_to_chunk(Vector2(70.0, -90.0)), Vector2i(2, -3), "interior point maps to same chunk")
	t.free()

func _test_chunk_biome_stable() -> void:
	var t := TerrainSlice.new()
	add_child(t)
	var b1 := t.get_biome_at_chunk(Vector2i(3, 4))
	var b2 := t.get_biome_at_chunk(Vector2i(3, 4))
	assert_eq(b1, b2, "same chunk yields the same biome across calls")
	assert_true(TerrainSlice.BIOME_KEYS.has(b1), "biome is a known canonical key")
	var world: Vector2 = t.chunk_to_world(Vector2i(3, 4))
	assert_eq(t.get_biome_at(world + Vector2(5.0, 7.0)), b1, "get_biome_at agrees inside the chunk")
	t.free()

func _test_chunk_load_unload_signals() -> void:
	var cm := ChunkManager.new()
	add_child(cm)
	var loaded := {}
	var unloaded := {}
	GameBus.chunk_loaded.connect(func(p): loaded[p] = true)
	GameBus.chunk_unloaded.connect(func(p): unloaded[p] = true)
	cm.load_chunk(Vector2i(0, 0))
	assert_true(loaded.has(Vector2i(0, 0)), "chunk_loaded emitted on load")
	cm.unload_chunk(Vector2i(0, 0))
	assert_true(unloaded.has(Vector2i(0, 0)), "chunk_unloaded emitted on unload")
	cm.free()

func _test_chunk_voxel_edits_isolated() -> void:
	var v := VoxelSlice.new()
	add_child(v)
	var inv := InventorySlice.new()
	add_child(inv)
	v.inventory_slice = inv
	var flat: Array = []
	flat.resize(32 * 32)
	flat.fill(2.0)
	v.build_chunk(Vector2i(0, 0), flat)
	v.build_chunk(Vector2i(1, 0), flat)
	assert_true(v.mine_block(Vector3(16.5, 2.0, 16.5)).get("success", false), "mine in chunk (0,0)")
	assert_eq(v.get_voxel_height_at(Vector2(16.0, 16.0)), 1.5, "chunk (0,0) lowered")
	assert_eq(v.get_voxel_height_at(Vector2(48.0, 16.0)), 2.0, "chunk (1,0) unaffected")
	v.free()
	inv.free()

func _test_chunk_unload_preserves_edits() -> void:
	var v := VoxelSlice.new()
	add_child(v)
	var flat: Array = []
	flat.resize(32 * 32)
	flat.fill(2.0)
	v.build_chunk(Vector2i(0, 0), flat)
	v.apply_edits({ "16,16": 1.0 })
	assert_eq(v.get_voxel_height_at(Vector2(16.0, 16.0)), 1.0, "edit applied")
	v.unload_chunk(Vector2i(0, 0))
	v.build_chunk(Vector2i(0, 0), flat)
	assert_eq(v.get_voxel_height_at(Vector2(16.0, 16.0)), 1.0, "edit survives unload/reload")
	v.free()

func _test_apply_edits_preserves_dirty_chunks() -> void:
	var v := VoxelSlice.new()
	add_child(v)
	var inv := InventorySlice.new()
	add_child(inv)
	v.inventory_slice = inv
	var flat: Array = []
	flat.resize(32 * 32)
	flat.fill(2.0)
	v.build_chunk(Vector2i(0, 0), flat)
	# Mine a block — this marks chunk (0,0) dirty.
	v.mine_block(Vector3(16.5, 2.0, 16.5))
	assert_true(v.get_dirty_chunk_keys().size() > 0, "mining marks a chunk dirty")
	# Simulate a save: clear dirty tracking (as game_root does after save).
	v.clear_dirty_chunks()
	assert_eq(v.get_dirty_chunk_keys().size(), 0, "dirty cleared after save")
	# Mine another block — this marks the chunk dirty mid-save-cycle.
	v.mine_block(Vector3(17.5, 2.0, 16.5))
	assert_true(v.get_dirty_chunk_keys().size() > 0, "mid-cycle mine marks chunk dirty again")
	# apply_edits simulates what happens on load (world data reapplied).
	# It must NOT clear the dirty tracking set by the mid-cycle mine above.
	v.apply_edits({ "16,16": 1.0 })
	assert_true(v.get_dirty_chunk_keys().size() > 0, "apply_edits preserves pre-existing dirty chunks")
	v.free()
	inv.free()

func _test_chunk_creature_spawn_per_chunk() -> void:
	var c := CreatureSlice.new()
	add_child(c)
	c.spawn_for_chunk(Vector2i(0, 0))
	var before: int = c.get_all_instances().size()
	assert_true(before > 0, "initial chunk has creatures")
	c.spawn_for_chunk(Vector2i(1, 0))
	var after: int = c.get_all_instances().size()
	assert_true(after > before, "spawning another chunk adds creatures")
	c.despawn_for_chunk(Vector2i(1, 0))
	assert_eq(c.get_all_instances().size(), before, "despawning a chunk removes only its creatures")
	c.free()

func _test_chunk_reload_engaged_budget() -> void:
	var c := CreatureSlice.new()
	add_child(c)
	c.spawn_for_chunk(Vector2i(0, 0))
	var initial_count: int = c.get_all_instances().size()
	assert_true(initial_count > 0, "initial spawn populates the chunk")
	# Mark the first instance aggressive so despawn_for_chunk keeps it alive.
	var all: Array = c.get_all_instances()
	var engaged_id: String = all[0]["instance_id"]
	c._instances[engaged_id]["state"] = "aggressive"
	c.despawn_for_chunk(Vector2i(0, 0))
	# One engaged creature survives the despawn.
	assert_eq(c.get_all_instances().size(), 1, "engaged creature survives despawn")
	# Reload: spawn_for_chunk must honour the budget and not exceed initial_count.
	c.spawn_for_chunk(Vector2i(0, 0))
	var after_reload: int = c.get_all_instances().size()
	assert_true(after_reload <= initial_count, "reload does not exceed original spawn budget (got %d, budget %d)" % [after_reload, initial_count])
	c.free()

func _test_chunk_persistence_manifest() -> void:
	var v := VoxelSlice.new()
	add_child(v)
	var flat: Array = []
	flat.resize(32 * 32)
	flat.fill(2.0)
	v.build_chunk(Vector2i(0, 0), flat)
	v.apply_edits({ "16,16": 1.0, "48,48": 3.0 })
	var manifest: Dictionary = v.get_chunk_manifest()
	assert_true(manifest.has("0,0"), "manifest groups chunk (0,0)")
	assert_true(manifest.has("1,1"), "manifest groups chunk (1,1)")
	assert_eq(float(manifest["0,0"]["edits"]["16,16"]), 1.0, "chunk (0,0) edit recorded")
	var v2 := VoxelSlice.new()
	add_child(v2)
	v2.build_chunk(Vector2i(0, 0), flat)
	v2.build_chunk(Vector2i(1, 1), flat)
	v2.apply_chunk_manifest(manifest)
	assert_eq(v2.get_voxel_height_at(Vector2(16.0, 16.0)), 1.0, "restored edit in chunk (0,0)")
	assert_eq(v2.get_voxel_height_at(Vector2(48.0, 48.0)), 3.0, "restored edit in chunk (1,1)")
	v.free()
	v2.free()

func _test_chunk_minimap_cells() -> void:
	var mm := Minimap.new()
	add_child(mm)
	mm.set_chunks([
		{ "chunk": Vector2i(0, 0), "biome": "TemperateForest" },
		{ "chunk": Vector2i(1, 0), "biome": "VolcanicBadlands" },
	])
	var cells: Array = mm.get_chunk_cells()
	assert_eq(cells.size(), 2, "two chunks reported")
	assert_true(Minimap.BIOME_COLORS.has(cells[0]["biome"]), "biome resolves to a colour")
	mm.set_player_pos(Vector2(16.0, 16.0))
	assert_eq(mm.get_player_cell()["chunk"], Vector2i(0, 0), "player cell resolves to chunk (0,0)")
	mm.free()

# ---------------------------------------------------------------------------
# Networking / authority tests (Phase 18)
# ---------------------------------------------------------------------------

func _test_net_voxel_client_forwards_intent() -> void:
	# A non-authoritative voxel slice must NOT mutate terrain via mine_block —
	# it forwards a block_edit_intent to the host instead. Invoke the handler
	# directly so the shared bus (and stale slices from other tests) can't
	# interfere with the assertion.
	var v := VoxelSlice.new()
	add_child(v)
	v.is_authoritative = false
	var flat: Array = []
	flat.resize(32 * 32)
	flat.fill(2.0)
	v.build_chunk(Vector2i(0, 0), flat)
	var intent := {}
	GameBus.block_edit_intent.connect(func(action, pos, normal, material):
		intent["action"] = action
		intent["material"] = material
	)
	v._on_mine_requested(Vector3(16.0, 2.0, 16.0), Vector3.UP)
	assert_eq(intent.get("action", ""), "mine", "client forwards a mine intent")
	assert_false(v._edits.has("16,16"), "mine_block did not edit this slice directly")
	v.free()

func _test_net_voxel_apply_block_change() -> void:
	# apply_block_change applies a host-authoritative edit without touching
	# inventory or re-emitting block_changed.
	var v := VoxelSlice.new()
	add_child(v)
	var flat: Array = []
	flat.resize(32 * 32)
	flat.fill(2.0)
	v.build_chunk(Vector2i(0, 0), flat)
	var reemit := 0
	GameBus.block_changed.connect(func(_a, _p, _n, _m): reemit += 1)
	v.apply_block_change("mine", Vector3(16.0, 2.0, 16.0), Vector3.UP, "")
	assert_eq(v.get_voxel_height_at(Vector2(16.0, 16.0)), 1.5, "mine applied (2.0 → 1.5)")
	v.apply_block_change("place", Vector3(16.0, 2.0, 16.0), Vector3.UP, "Ferrite")
	assert_eq(v.get_voxel_height_at(Vector2(16.0, 16.0)), 2.0, "place applied (1.5 → 2.0)")
	assert_eq(reemit, 0, "apply_block_change does not re-emit block_changed")
	v.free()

func _test_net_creature_client_no_local_spawn() -> void:
	var c := CreatureSlice.new()
	add_child(c)
	c.is_authoritative = false
	c.spawn_for_chunk(Vector2i(0, 0))
	assert_eq(c.get_all_instances().size(), 0, "client does not spawn locally")
	# But it does apply host state deltas.
	c.apply_creature_state("creature_9", "ForestBoar", "idle", Vector3(1.0, 2.0, 3.0))
	var all := c.get_all_instances()
	assert_eq(all.size(), 1, "client applies a host creature state")
	assert_eq(all[0]["instance_id"], "creature_9", "instance id preserved")
	assert_eq(all[0]["creature_id"], "ForestBoar", "creature id preserved")
	assert_eq(all[0]["state"], "idle", "state preserved")
	# Update path.
	c.apply_creature_state("creature_9", "ForestBoar", "aggressive", Vector3(4.0, 5.0, 6.0))
	assert_eq(c.get_all_instances().size(), 1, "update does not duplicate the instance")
	assert_eq(c.get_all_instances()[0]["state"], "aggressive", "state updated")
	c.free()

func _test_net_creature_snapshot_roundtrip() -> void:
	var host := CreatureSlice.new()
	add_child(host)
	host.spawn_for_chunk(Vector2i(0, 0))
	var snap := host.get_snapshot_creatures()
	assert_true(snap.size() > 0, "host produces a non-empty snapshot")
	var client := CreatureSlice.new()
	add_child(client)
	client.is_authoritative = false
	client.apply_snapshot_creatures(snap)
	assert_eq(client.get_all_instances().size(), snap.size(), "client seeds population from snapshot")
	# creature_id must survive the snapshot round-trip.
	var cfirst: Dictionary = client.get_all_instances()[0]
	var sfirst: Dictionary = snap[0]
	assert_eq(cfirst["creature_id"], sfirst["creature_id"], "creature_id preserved through snapshot")
	host.free()
	client.free()

func _test_net_player_ghost_interpolation() -> void:
	var p := PlayerSlice.new()
	add_child(p)
	assert_eq(p.get_remote_ghost_count(), 0, "no ghosts initially")
	p._on_remote_player_state(2, Vector3(0.0, 0.0, 0.0))
	assert_eq(p.get_remote_ghost_count(), 1, "first remote state spawns a ghost")
	# A second snapshot resets interpolation toward the new target.
	p._on_remote_player_state(2, Vector3(10.0, 0.0, 0.0))
	p._tick_ghosts(0.05)   # half the interp time
	var body: Node3D = p._ghosts[2]["body"]
	assert_true(body.position.x > 0.0 and body.position.x < 10.0, "ghost interpolates between snapshots")
	p.free()

func _test_net_player_ghost_self_filter() -> void:
	# The local player's own peer id must never spawn a ghost — the host echoes
	# a client's movement back to every peer, including the originator.
	var p := PlayerSlice.new()
	add_child(p)
	p._on_remote_player_state(multiplayer.get_unique_id(), Vector3(1.0, 2.0, 3.0))
	assert_eq(p.get_remote_ghost_count(), 0, "own peer id does not spawn a ghost")
	p.free()

func _test_net_creature_dirty_broadcast() -> void:
	# Unchanged instances are not re-broadcast; only mutated ones are.
	var c := CreatureSlice.new()
	add_child(c)
	c.spawn_for_chunk(Vector2i(0, 0))
	var emissions := []
	GameBus.creature_state_changed.connect(func(iid, _cid, _state, _pos): emissions.append(iid))
	c._broadcast_creature_states()
	assert_true(emissions.size() > 0, "first broadcast ships the population")
	emissions.clear()
	c._broadcast_creature_states()
	assert_eq(emissions.size(), 0, "unchanged creatures are not re-broadcast")
	var first_id: String = c.get_all_instances()[0]["instance_id"]
	c.set_instance_position(first_id, Vector3(50.0, 50.0, 50.0))
	c._broadcast_creature_states()
	assert_eq(emissions.size(), 1, "only the moved creature is re-broadcast")
	assert_eq(emissions[0], first_id, "the dirty instance is the one broadcast")
	c.free()

func _test_net_inventory_replace_contents() -> void:
	var inv := InventorySlice.new()
	add_child(inv)
	inv.add_item("Ferrite", 5)
	inv.replace_contents({ "Ashite": 3 })
	assert_eq(inv.get_item_count("Ferrite"), 0, "replace clears old items")
	assert_eq(inv.get_item_count("Ashite"), 3, "replace applies host contents")
	inv.free()

# ---------------------------------------------------------------------------
# Networking / chaos resilience tests (Phase 19)
# ---------------------------------------------------------------------------

func _test_net_sequence_monotonic() -> void:
	# Each packet type maintains its own counter; two packets of the same type
	# increment together, while a different type starts fresh at 0.
	var n := NetworkingSlice.new()
	add_child(n)
	var p1 := { "type": "player_moved" }
	var p2 := { "type": "player_moved" }
	var p3 := { "type": "block_changed" }
	n._deliver(1, p1)
	n._deliver(1, p2)
	n._deliver(1, p3)
	assert_eq(int(p1["seq"]), 0, "first player_moved gets seq 0")
	assert_eq(int(p2["seq"]), 1, "second player_moved gets seq 1")
	assert_eq(int(p3["seq"]), 0, "block_changed starts its own per-type counter at 0")
	n.free()

func _test_net_sequence_dedup() -> void:
	# In-order and forward-gap packets are accepted. True duplicates (same seq
	# already in the window) are dropped. Out-of-order packets that have NOT been
	# seen before are accepted (delivered late is fine; dropped is not). Each
	# packet type is tracked independently.
	var n := NetworkingSlice.new()
	add_child(n)
	assert_true(n._dedup(1, { "seq": 0, "type": "x" }), "first seq accepted")
	assert_true(n._dedup(1, { "seq": 1, "type": "x" }), "next in-order seq accepted")
	assert_false(n._dedup(1, { "seq": 1, "type": "x" }), "duplicate seq dropped")
	assert_false(n._dedup(1, { "seq": 0, "type": "x" }), "already-seen seq dropped")
	assert_true(n._dedup(1, { "seq": 5, "type": "x" }), "forward gap accepted (logged, not blocking)")
	# Out-of-order but UNSEEN: seq 3 arrives after seq 5 — must be accepted, not dropped.
	assert_true(n._dedup(1, { "seq": 3, "type": "x" }), "out-of-order unseen seq accepted (delivered late)")
	# Cross-type isolation: same seq on a different type has its own counter.
	assert_true(n._dedup(1, { "seq": 0, "type": "y" }), "same seq on a different type accepted independently")
	n.free()

func _test_net_emulator_delivery() -> void:
	# With emulation on but no loss/jitter, every packet is queued and the
	# queue preserves monotonic seq order.
	var n := NetworkingSlice.new()
	add_child(n)
	n.emulate_network = true
	n.emulator_loss_rate = 0.0
	n.emulator_jitter_ms = 0.0
	n._rng.seed = 7
	for i in range(10):
		n._deliver(1, { "type": "x", "i": i })
	assert_eq(n._pending.size(), 10, "all packets queued when no loss and no jitter")
	var seqs: Array = []
	for e in n._pending:
		var parsed = JSON.parse_string(e["json"])
		seqs.append(int(parsed["seq"]))
	seqs.sort()
	assert_eq(seqs, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], "queued packets carry monotonic seq 0..9")
	n.free()

func _test_net_emulator_loss() -> void:
	# At a 15% loss rate the emulator drops a fraction close to 15% (and the
	# mechanism is deterministic under a seeded RNG).
	var n := NetworkingSlice.new()
	add_child(n)
	n.emulate_network = true
	n.emulator_loss_rate = 15.0
	n._rng.seed = 12345
	var dropped := 0
	var total := 1000
	for _i in range(total):
		if n._should_drop():
			dropped += 1
	var pct := float(dropped) / float(total) * 100.0
	assert_true(pct > 8.0 and pct < 22.0, "loss rate near 15%% (got %.1f%%)" % pct)
	n.free()

func _test_net_emulator_jitter() -> void:
	# Jitter delays are uniformly distributed in [-bound, +bound] with no
	# positive bias. Negative values are delivered immediately by the drain loop.
	var n := NetworkingSlice.new()
	add_child(n)
	n.emulate_network = true
	n.emulator_jitter_ms = 50.0
	n._rng.seed = 99
	for _i in range(200):
		var d: float = n._jitter_delay_ms()
		assert_true(d >= -50.0 and d <= 50.0, "jitter delay within [-50, 50] (got %.1f)" % d)
	n.free()

func _test_net_emulator_zero_overhead() -> void:
	# With emulation disabled (production default), packets go straight out and
	# never enter the delivery queue.
	var n := NetworkingSlice.new()
	add_child(n)
	n._deliver(1, { "type": "x" })
	assert_eq(n._pending.size(), 0, "no packets queued when emulation disabled")
	n.free()

func _test_net_jitter_buffer() -> void:
	# The client jitter buffer replays remote-player snapshots on a fixed
	# playback delay and interpolates between the surrounding snapshots.
	var n := NetworkingSlice.new()
	add_child(n)
	n.jitter_buffer_ms = 100.0
	n._jitter_buffer[1] = [
		{ "at_ms": 0.0,   "position": Vector3(0.0, 0.0, 0.0) },
		{ "at_ms": 50.0,  "position": Vector3(10.0, 0.0, 0.0) },
		{ "at_ms": 100.0, "position": Vector3(20.0, 0.0, 0.0) },
	]
	var a: Vector3 = n._sample_remote_state_at(1, 100.0)
	assert_true(abs(a.x) < 0.001, "playback before first snapshot returns first position")
	var b: Vector3 = n._sample_remote_state_at(1, 150.0)
	assert_true(abs(b.x - 10.0) < 0.001, "playback at middle snapshot returns exact position")
	var c: Vector3 = n._sample_remote_state_at(1, 125.0)
	assert_true(abs(c.x - 5.0) < 0.5, "interpolated between snapshots within tolerance")
	var d: Vector3 = n._sample_remote_state_at(1, 250.0)
	assert_true(abs(d.x - 20.0) < 0.001, "playback past last snapshot returns last position")
	n.free()

func _test_net_inventory_replace_idempotent() -> void:
	# replace_contents must be idempotent: applying the same snapshot twice
	# (e.g. initial join followed by a rejoin) must not duplicate entries.
	var inv := InventorySlice.new()
	add_child(inv)
	inv.add_item("Ferrite", 5)
	var contents: Dictionary = inv.get_contents()
	inv.replace_contents(contents)
	inv.replace_contents(contents)
	assert_eq(inv.get_item_count("Ferrite"), 5, "double replace_contents does not duplicate inventory")
	inv.free()

func _test_net_reconnect_last_known_state() -> void:
	# The host retains a client's last-known position across a disconnect so a
	# rejoining client resumes from it.
	var n := NetworkingSlice.new()
	add_child(n)
	n.remember_player_state(2, Vector3(4.0, 5.0, 6.0))
	assert_eq(n.get_last_known_state(2), Vector3(4.0, 5.0, 6.0), "state remembered")
	n._on_peer_disconnected(2)
	assert_eq(n.get_last_known_state(2), Vector3(4.0, 5.0, 6.0), "last-known state retained across disconnect")
	assert_true(n.get_last_known_states().has(2), "retained state present for snapshot")
	n.free()

func _test_net_two_peer_loss_reorder() -> void:
	# End-to-end emulation: a sender with 10% loss and reorder stages packets;
	# all non-dropped packets must be accepted by the receiver's sliding-window
	# dedup even when delivered in reverse order (worst-case reorder). A second
	# pass must reject every packet as a duplicate (dedup is idempotent).
	var sender := NetworkingSlice.new()
	add_child(sender)
	sender.emulate_network = true
	sender.emulator_loss_rate = 10.0
	sender.emulator_reorder = true
	sender._rng.seed = 1337

	for i in range(30):
		sender._deliver(1, { "type": "player_moved", "i": i })

	# Collect the packets the emulator kept (not lost), in whatever order the
	# reorder step staged them.
	var queued: Array = []
	for entry in sender._pending:
		var parsed = JSON.parse_string(str(entry["json"]))
		if parsed is Dictionary:
			queued.append(parsed)

	assert_true(queued.size() > 0, "at least some packets survive 10% loss over 30 sent")

	var receiver := NetworkingSlice.new()
	add_child(receiver)

	# Deliver in reverse order — maximum reorder stress.
	var reversed_q := queued.duplicate()
	reversed_q.reverse()
	var accepted := 0
	for pkt in reversed_q:
		if receiver._dedup(1, pkt):
			accepted += 1

	assert_eq(accepted, queued.size(),
		"all %d non-dropped packets accepted despite reverse-order delivery" % queued.size())

	# Second pass: every seq is now in the seen window — all must be rejected.
	var duplicates := 0
	for pkt in queued:
		if receiver._dedup(1, pkt):
			duplicates += 1

	assert_eq(duplicates, 0, "no packet accepted a second time — dedup is idempotent")

	sender.free()
	receiver.free()

# ---------------------------------------------------------------------------
# AssetOverlay tests (Phase 21 — asset separation)
# ---------------------------------------------------------------------------

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

func _scan_dir_for_forbidden_strings(dir_path: String, forbidden: Array, violations: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var full_path := dir_path.path_join(entry)
			if dir.current_is_dir():
				_scan_dir_for_forbidden_strings(full_path, forbidden, violations)
			elif entry.ends_with(".gd") and full_path != "res://src/tests/test_suite.gd":
				var f := FileAccess.open(full_path, FileAccess.READ)
				if f != null:
					var text := f.get_as_text()
					for needle in forbidden:
						if text.contains(needle):
							violations.append("%s contains '%s'" % [full_path, needle])
		entry = dir.get_next()
	dir.list_dir_end()

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
# Assertion helpers
# ---------------------------------------------------------------------------

func assert_eq(a, b, msg: String = "") -> void:
	if a == b:
		_ok()
	else:
		_ko("assert_eq FAILED [%s]: expected %s, got %s" % [msg, str(b), str(a)])

func assert_true(cond: bool, msg: String = "") -> void:
	if cond:
		_ok()
	else:
		_ko("assert_true FAILED [%s]" % msg)

func assert_false(cond: bool, msg: String = "") -> void:
	if not cond:
		_ok()
	else:
		_ko("assert_false FAILED [%s]" % msg)

func _ok() -> void:
	_pass += 1

func _ko(msg: String) -> void:
	_fail += 1
	push_error("  ✗ [%s] %s" % [_current_test, msg])

func _run_test(name: String, fn: Callable) -> void:
	_current_test = name
	var fails_before := _fail
	fn.call()
	var outcome := "✓" if _fail == fails_before else "✗"
	print("  %s %s" % [outcome, name])
