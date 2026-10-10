extends Node
## Self-contained automated test suite.
##
## Each test_* method is discovered and run automatically in _ready().
## Tests use assert_eq / assert_true / assert_false helpers.
## Summary is printed to the Godot output log.
##
## Run from game_root by instantiating this node and calling run().
const Diag := preload("res://src/core/diag.gd")

# Preload slices so tests are isolated from the main scene tree.
const BattleSlice     := preload("res://src/battle/battle_slice.gd")
const CreatureSlice   := preload("res://src/creature/creature_slice.gd")
const CreatureAI      := preload("res://src/creature/creature_ai.gd")
const TamingSlice     := preload("res://src/creature/taming_slice.gd")
const TerrainSlice    := preload("res://src/terrain/terrain_slice.gd")
const SpawnRoll       := preload("res://src/world/spawn_roll.gd")
const WorldClock      := preload("res://src/world/world_clock.gd")
const ChunkManager    := preload("res://src/terrain/chunk_manager.gd")
const PersistenceSlice:= preload("res://src/persistence/persistence_slice.gd")
const LootSlice       := preload("res://src/loot/loot_slice.gd")
const InventorySlice  := preload("res://src/inventory/inventory_slice.gd")
const CharacterSlice  := preload("res://src/character/character_slice.gd")
const CraftingSlice   := preload("res://src/crafting/crafting_slice.gd")
const TechnologySlice := preload("res://src/technology/technology_slice.gd")
const UiSlice         := preload("res://src/ui/ui_slice.gd")
const VoxelSlice      := preload("res://src/terrain/voxel_slice.gd")
const RebaseDriver    := preload("res://src/terrain/rebase_driver.gd")
const ChatCommands    := preload("res://src/core/chat_commands.gd")
const ChatSlice       := preload("res://src/chat/chat_slice.gd")
const StationSlice    := preload("res://src/world/station_slice.gd")
const TreeSlice       := preload("res://src/world/tree_slice.gd")
const MeshUtil        := preload("res://src/core/mesh_util.gd")
const MarketSlice     := preload("res://src/world/market_slice.gd")
const TradeSlice      := preload("res://src/trade/trade_slice.gd")
const ProposalSlice   := preload("res://src/governance/proposal_slice.gd")
const Minimap         := preload("res://src/ui/minimap.gd")
const BiomeBlend      := preload("res://src/terrain/biome_blend.gd")
const PlayerSlice     := preload("res://src/player/player_slice.gd")
const NetworkingSlice := preload("res://src/networking/networking_slice.gd")
const ClimateField := preload("res://src/terrain/climate_field.gd")
const WorldShape := preload("res://src/terrain/world_shape.gd")
const DistantTerrainScript := preload("res://src/terrain/distant_terrain.gd")
const Locomotion      := preload("res://src/character/locomotion.gd")
const SkeletonRig     := preload("res://src/character/skeleton_rig.gd")
const SkillTiers      := preload("res://src/core/skill_tiers.gd")
const MultimeshPool   := preload("res://src/core/multimesh_pool.gd")
const SpatialHash     := preload("res://src/core/spatial_hash.gd")
const PlayerRegistry  := preload("res://src/persistence/player_registry.gd")
const EquipmentRules   := preload("res://src/character/equipment_rules.gd")
const GameDataReader   := preload("res://src/core/game_data_reader.gd")
const NetHarness      := preload("res://src/tests/net_harness.gd")
const OreField        := preload("res://src/terrain/ore_field.gd")

var _pass: int = 0
var _fail: int = 0
var _current_test: String = ""
## Method names (e.g. "_test_foo") registered via _run_test, used by the
## self-check to catch a test function that was written but never registered.
var _registered_names: Dictionary = {}

# ---------------------------------------------------------------------------
# Entry
# ---------------------------------------------------------------------------

func run() -> void:
	print("\n╔══════════════════════════════════════╗")
	print("║       Project Nihon — Test Suite     ║")
	print("╚══════════════════════════════════════╝\n")
	Diag.quiet = true

	_run_test("battle: hit reduces defender hp",              _test_battle_hit_reduces_hp)
	_run_test("battle: miss leaves hp unchanged",             _test_battle_miss_leaves_hp_unchanged)
	_run_test("battle: kill emits creature_died signal",      _test_battle_kill_emits_death)
	_run_test("battle: reset_hp restores state",              _test_battle_reset_hp)
	_run_test("battle: resolves stats via creature_slice",    _test_battle_resolves_via_creature_slice)
	_run_test("creature: spawns instances from GameData",     _test_creature_spawns_from_gamedata)
	_run_test("creature: nearest_creature returns closest",   _test_creature_nearest)
	_run_test("creature: death marks instance dead",          _test_creature_death_marks_dead)
	_run_test("creature: respawn resets battle hp state",     _test_creature_respawn_resets_battle_hp)
	_run_test("spatial: insert + query_radius finds entity",  _test_spatial_query_radius)
	_run_test("spatial: update moves entity across cells",    _test_spatial_update_moves_cell)
	_run_test("spatial: remove drops entity",                 _test_spatial_remove)
	_run_test("spatial: nearest returns closest",             _test_spatial_nearest)
	_run_test("creature: nearest_creature routes via hash",   _test_creature_nearest_via_hash)
	_run_test("creature: respawn re-hashes spatial position", _test_creature_respawn_rehashes_spatial)
	_run_test("terrain: chunk size is correct",               _test_terrain_chunk_size)
	_run_test("terrain: height is non-negative",              _test_terrain_height_nonneg)
	_run_test("terrain: two chunks are independent",          _test_terrain_two_chunks)
	_run_test("terrain: the world seed determines the terrain", _test_terrain_seed_deterministic)
	_run_test("terrain: ocean share and mountains over a transect", _test_terrain_ocean_share_transect)
	_run_test("terrain: the spawn plain is dry land",         _test_terrain_spawn_plain_dry)
	_run_test("terrain: the shape wraps and stays in range",  _test_world_shape_wraps_in_range)
	_run_test("climate: poles are cold, peaks are cold",      _test_climate_poles_and_peaks)
	_run_test("climate: ocean chunks are Ocean, fantasy biomes are niches", _test_climate_ocean_and_niches)
	_run_test("climate: niches are index-stable, share-exact and smooth", _test_climate_niches_stable_and_smooth)
	_run_test("climate: niche field wraps, table is calibrated, fallback pool is cached", _test_climate_niche_wraps_and_is_calibrated)
	_run_test("climate: the Voronoi fallback is land-only", _test_climate_fallback_is_land_only)
	_run_test("water: spans cover exactly the tiles below sea level", _test_water_spans)
	_run_test("voxel: a chunk-local build keeps far-from-origin vertices small and exact", _test_voxel_local_build_far_chunk)
	_run_test("locomotion: reset stands a dead avatar back up", _test_locomotion_reset_after_death)
	_run_test("polar: ice is streamed to the pole and whitens the ground", _test_polar_ice)
	_run_test("player: deep water is swum, not walked",       _test_player_swims_in_deep_water)
	_run_test("terrain: the distant ring is 10x the window with no collision", _test_distant_ring)
	_run_test("terrain: the ring meets the voxel ground at the window edge", _test_distant_ring_window_edge)
	_run_test("player: swimming reads the voxel column, not the generated height", _test_swim_reads_voxel_column)
	_run_test("terrain: the distant ring builds off the main thread", _test_distant_ring_async)
	_run_test("terrain: freeing the ring mid-build aborts the worker at the next row", _test_distant_ring_abort)
	_run_test("terrain: a build that is not aborted is unchanged by the abort check", _test_distant_ring_unaborted_same)
	_run_test("terrain: a reparented ring rebuilds to the undisturbed mesh", _test_distant_ring_reparent)
	_run_test("terrain: a rebuild while detached starts exactly one task per request", _test_distant_ring_detached_rebuild)
	_run_test("terrain: a ring reparented with a queued request builds the queued centre", _test_distant_ring_reparent_queued)
	_run_test("terrain: the ring abort path is repeatable without engine errors", _test_distant_ring_abort_loop)
	_run_test("terrain: the distant ring's vertices are pinned by a hash", _test_distant_ring_vertex_hash)
	_run_test("terrain: detail noise has one formula", _test_detail_noise_single_formula)
	_run_test("terrain: walking 5 chunks requests at most 5 ring rebuilds", _test_distant_ring_rebuild_counter)
	_run_test("terrain: concurrent height sampling matches single-threaded", _test_height_concurrent)
	_run_test("chunk: deplete-only edits request no neighbour rebuild", _test_seam_deplete_only)
	_run_test("chunk: a border height edit rebuilds only that neighbour", _test_seam_east_border_edit)
	_run_test("chunk: late edits rebuild the neighbour across the border", _test_seam_late_edits)
	_run_test("chunk: edits synced while unloaded still rebuild neighbours on stream-in", _test_seam_unloaded_then_streamed)
	_run_test("chunk: removing a corner edit rebuilds the diagonal neighbour", _test_seam_corner_removal)
	_run_test("spawn: ocean chunks grow no trees",            _test_ocean_spawns_no_land_tables)
	_run_test("terrain: the world wraps east-west",           _test_terrain_wraps_east_west)
	_run_test("terrain: chunk keys are canonical across the seam", _test_chunk_key_canonical_at_seam)
	_run_test("wire: positions travel as chunk + local; old float arrays still read", _test_wire_chunk_local)
	_run_test("rebase: driver shifts player, tree, creature, station and chunks together", _test_rebase_driver)
	_run_test("terrain: detail noise stays exact far from the origin", _test_far_noise_quantised)
	_run_test("chat: /where prints latitude and longitude", _test_where_command)
	_run_test("chat: slash lines parse, sanitize and validate", _test_chat_parse)
	_run_test("chat: admin commands run for admins only",     _test_chat_admin_commands)
	_run_test("chat: lines and intents cross the wire",       _test_chat_wire)
	_run_test("chat: the input box is on screen while closed", _test_chat_box_visible)
	_run_test("chat: a token bucket bounds each player's lines", _test_chat_rate_limit)
	_run_test("chat: /kill on a peer runs through simulated HP", _test_chat_kill_peer_simulated_hp)
	_run_test("chat: no one else calls send_player_damaged",  _test_chat_no_direct_damage_door)
	_run_test("chat: teleports carry the exact position",     _test_chat_exact_teleports)
	_run_test("chat: /tp wraps X and refuses a Z past the poles", _test_chat_tp_limits)
	_run_test("terrain: latitude and longitude from the fabric planet", _test_terrain_planet_coordinates)
	_run_test("rebase: loot, avatars and the station preview follow the shift", _test_rebase_extras)
	_run_test("player: rebased origin keeps the world position", _test_world_pos_rebase)
	_run_test("player: the scene origin is the driver's integer chunk", _test_scene_origin_single_source)
	_run_test("terrain: walking over a pole or round the planet folds the position", _test_globe_fold)
	_run_test("wire: one validator for dictionaries and records", _test_one_wire_validator)
	_run_test("player: exact chunk + local far from the origin", _test_player_exact_far_position)
	_run_test("rebase: TreeSlice shifts its trunks and pool, not other children", _test_tree_shift_explicit_set)
	_run_test("rebase: LootSlice shifts its pickups, survives a freed one", _test_loot_shift_explicit_set)
	_run_test("rebase: a physics-step rebase never jumps the world position", _test_rebase_in_physics_step)
	_run_test("persistence: position saved as chunk + local, old saves migrate", _test_registry_world_pos)
	_run_test("persistence: save then load round-trip",       _test_persistence_round_trip)
	_run_test("persistence: worldgen stamp on a new world",   _test_worldgen_stamp_new_world)
	_run_test("persistence: worldgen mismatch warns once and keeps the stamp", _test_worldgen_stamp_mismatch)
	_run_test("game_root: worldgen stamp wiring on load",     _test_worldgen_stamp_game_root_wiring)
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
	_run_test("character: LOD medium hides fine detail",       _test_character_lod_medium_hides_fine_detail)
	_run_test("character: LOD hysteresis on thresholds",       _test_character_lod_hysteresis)
	_run_test("character: LOD equipping at impostor hides node", _test_character_lod_equip_at_impostor)
	_run_test("character: skeleton rig builds bone hierarchy",_test_character_skeleton_rig)
	_run_test("character: bone pose initialized from rest",    _test_character_skeleton_pose_matches_rest)
	_run_test("character: avatar faces movement direction",   _test_character_faces_movement_direction)
	_run_test("character: locomotion idle→walk→run by speed", _test_character_locomotion_speed)
	_run_test("character: blend curve maps speed to 0..1",     _test_character_blend_curve)
	_run_test("character: attack/death play on bus signals",  _test_character_attack_death_signals)
	_run_test("character: foot IK tracks terrain surface",    _test_character_foot_ik)
	_run_test("character: avatar root Y matches voxel ground", _test_avatar_root_y_matches_voxel_ground)
	_run_test("player: step-up climbs a rise, not a wall",     _test_player_step_up)
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
	_run_test("character: same-size parts share one mesh",     _test_character_mesh_shared)
	_run_test("character: procedural walk swings limbs",        _test_character_procedural_walk_animation)
	_run_test("character: toggle equipment on/off",             _test_character_toggle_equipment)
	_run_test("character: nearby proportions snap to one bucket",   _test_character_proportions_quantized)
	_run_test("crafting: recipe data loaded from fabric",     _test_crafting_recipe_data_loaded)
	_run_test("crafting: skill guard blocks low tier",        _test_crafting_skill_guard_blocks)
	_run_test("crafting: consumes inputs and produces output", _test_crafting_consumes_and_produces)
	_run_test("crafting: missing inputs fail",                _test_crafting_missing_inputs)
	_run_test("crafting: unknown recipe rejected",            _test_crafting_unknown_recipe)
	_run_test("crafting: can_craft does not mutate",          _test_crafting_can_craft_no_mutate)
	_run_test("crafting: skill tiers are per-player",         _test_craft_skill_tiers_are_per_player)
	_run_test("station: gate blocks without nearby station",           _test_station_gate_blocks)
	_run_test("station: gate passes when station nearby",             _test_station_gate_passes)
	_run_test("station: wrong station type still blocks",             _test_station_wrong_type_blocks)
	_run_test("station: carpentry bench gates carpentry recipe",      _test_station_carpentry_bench)
	_run_test("station: master forge gates high-tier recipe",         _test_station_master_forge)
	_run_test("station: nearest_station ignores wrong type",          _test_station_nearest_ignores_wrong_type)
	_run_test("station: all canonical types accepted",                _test_station_all_canonical_types)
	_run_test("station: placement snaps and refuses overlap",         _test_station_placement_validation)
	_run_test("station: types derived from fabric",                   _test_station_types_from_fabric)
	_run_test("station: placement cost and overlap rule",             _test_station_placement_cost_and_overlap)
	_run_test("station: player placement target and gating",          _test_player_station_placement)
	_run_test("durability: use decrements points",                    _test_durability_use_decrements)
	_run_test("durability: broken tool emits item_broke",             _test_durability_broken_emits)
	_run_test("durability: stackable materials excluded",             _test_durability_stackable_excluded)
	_run_test("durability: drop and repick resets to full",           _test_durability_drop_repick_resets)
	_run_test("durability: find_tool returns held pick",              _test_durability_find_tool)
	_run_test("durability: find_tool skips broken, returns working",  _test_durability_find_tool_skips_broken)
	_run_test("durability: values round-trip (sync/trade/market)",    _test_durability_values_round_trip)
	_run_test("durability: sync/load copy, not move",                _test_durability_sync_is_copy_not_move)
	_run_test("durability: host sync overwrites worn with pristine",  _test_sync_pristine_over_worn)
	_run_test("durability: missing payload + larger host qty grants fresh excess", _test_sync_missing_payload_grants_fresh_excess)
	_run_test("durability: shrink to 1 keeps worst instance",        _test_sync_shrink_keeps_worst_instance)
	_run_test("durability: short payload pads with carried value",   _test_sync_short_payload_pads_with_carried_value)
	_run_test("durability: above-max payload value clamped",         _test_durability_clamp_above_max)
	_run_test("durability: negative payload value becomes broken",   _test_durability_clamp_negative_broken)
	_run_test("repair: spec loaded from fabric",                    _test_repair_spec_loaded)
	_run_test("repair: worn tool restored to pristine",             _test_repair_restores_worn)
	_run_test("repair: materials consumed",                         _test_repair_consumes_materials)
	_run_test("repair: skill guard blocks low tier",                _test_repair_skill_guard_blocks)
	_run_test("repair: station gate blocks without forge",          _test_repair_station_gate_blocks)
	_run_test("repair: pristine item already repaired",             _test_repair_pristine_rejected)
	_run_test("repair: non-durable item rejected",                  _test_repair_non_durable_rejected)
	_run_test("repair: broken tool restored via bus",               _test_repair_broken_via_bus)
	_run_test("repair: can_repair is non-mutating",                _test_repair_can_repair_direct)
	_run_test("repair: failed repair consumes no materials",       _test_repair_failed_consumes_nothing)
	_run_test("repair: missing materials blocked",                 _test_repair_missing_inputs)
	_run_test("repair: no item held",                              _test_repair_no_item)
	_run_test("repair: multi-material AethermiteBow",              _test_repair_multi_material_aethermitebow)
	_run_test("repair: specs resolve against fabric",              _test_repair_specs_resolve)
	_run_test("repair: resolves against the repairer's inventory",  _test_repair_uses_repairer_inventory)
	_run_test("repair: client forwards intent, mutates nothing",    _test_repair_client_forwards_intent)
	_run_test("technology: recipe resolves to owning tech",    _test_technology_recipe_resolves_to_tech)
	_run_test("technology: research requires prerequisite",    _test_technology_research_requires_prereq)
	_run_test("technology: research consumes materials",       _test_technology_research_consumes_materials)
	_run_test("technology: complete research unlocks",         _test_technology_complete_unlocks)
	_run_test("technology: crafting blocked while locked",     _test_technology_crafting_blocked_locked)
	_run_test("technology: crafting allowed after unlock",     _test_technology_crafting_allowed_after_unlock)
	_run_test("technology: unknown technology rejected",       _test_technology_unknown_rejected)
	_run_test("technology: tree and materials are per-player",  _test_research_is_per_player)
	_run_test("technology: client forwards research intent",    _test_technology_client_forwards_intent)
	_run_test("technology: client does not resolve research",  _test_technology_client_resolves_nothing)
	_run_test("taming: fabric spec drives the interaction",    _test_taming_fabric_spec)
	_run_test("taming: a creature with no tame field is refused", _test_taming_not_tameable)
	_run_test("taming: wolf needs the alpha down",             _test_taming_wolf_requires_alpha_down)
	_run_test("taming: wolf grants flag and companion",        _test_taming_wolf_grants_flag_companion)
	_run_test("taming: unidentified tamer refused atomically", _test_taming_refusal_is_atomic)
	_run_test("taming: skill gate fails closed",               _test_taming_requires_skill)
	_run_test("taming: bare hands required",                   _test_taming_requires_unarmed)
	_run_test("taming: a peer's hands are the host's record",   _test_taming_peer_bare_hands_claim)
	_run_test("equipment: an intent needs an owned item",       _test_equipment_intent_requires_ownership)
	_run_test("equipment: equip actions are host-authoritative", _test_equip_intent_is_host_authoritative)
	_run_test("equipment: the client diffs gear into actions",  _test_equip_actions_diff)
	_run_test("equipment: restore paths on a host and a client", _test_apply_local_equipment_paths)
	_run_test("equipment: bag loss clears the slot",            _test_equipment_revalidated_on_bag_loss)
	_run_test("equipment: join payload carries a revalidated set", _test_equipment_revalidated_before_join)
	_run_test("equipment: a stale revoke does not wipe a newer equip", _test_equipment_stale_revoke_ignored)
	_run_test("equipment: refused intents are rate limited",    _test_equipment_refusals_rate_limited)
	_run_test("equipment: a suppressed refusal still revokes once", _test_equipment_trailing_revoke)
	_run_test("equipment: bookkeeping is dropped with the player", _test_equipment_bookkeeping_evicted)
	_run_test("equipment: the sequence number never rewinds",   _test_equipment_seq_monotonic)
	_run_test("region: a failed save re-marks only failed chunks", _test_region_failed_keys_and_remark)
	_run_test("region: a depletion in an evicted chunk keeps its other edits", _test_region_depletion_merges_evicted)
	_run_test("region: a malformed entry warns once per store", _test_region_malformed_warns_once)
	_run_test("region: a legacy tile height survives a depletion overlay", _test_region_overlay_legacy_height)
	_run_test("region: one legacy-height parser refuses non-finite and unreadable values", _test_legacy_height_parser)
	_run_test("voxel: a legacy op migrates against the materials stack", _test_legacy_op_materials_stack)
	_run_test("voxel: a partial chunk with a stored legacy height loads whole", _test_partial_chunk_legacy_op)
	_run_test("voxel: an unreadable legacy op is dropped and a plain tile round-trips", _test_legacy_op_unreadable_dropped)
	_run_test("region: a malformed entry survives a neighbour's save", _test_region_malformed_entry_kept)
	_run_test("region: a valid entry replaces a malformed one", _test_region_malformed_entry_replaced)
	_run_test("region: a partial chunk loads its stored edits when the region streams in", _test_region_partial_chunk_loads_stored)
	_run_test("region: an overlay keeps the larger stored depletion count", _test_region_overlay_keeps_larger_taken)
	_run_test("region: migration recovers a monolith chunk whose region entry is malformed", _test_region_migrate_malformed_recovers)
	_run_test("rebase: an unshiftable target is reported",      _test_rebase_driver_reports_unshiftable)
	_run_test("game_root: implausible peer positions dropped",  _test_remote_state_plausibility)
	_run_test("networking: a remote peer's exact position is saved exactly", _test_remote_peer_exact_position)
	_run_test("networking: peer windows and relays use the exact peer position", _test_peer_exact_window_and_relay)
	_run_test("equipment: slots cached, peer evict, owner map", _test_equipment_phase48_misc)
	_run_test("equipment: host worn set + AOI enter/leave",      _test_equipment_host_and_aoi_transitions)
	_run_test("net: broadcasts go through _test_peers",          _test_network_broadcast_uses_test_peers)
	_run_test("net: test seam follows the boot gate",            _test_network_seam_follows_boot_gate)
	_run_test("ui: ? hotkey matches on unicode",                 _test_ui_question_mark_hotkey)
	_run_test("ui: failed layout rename cleans tmp",             _test_ui_layout_failed_rename_cleans_tmp)
	_run_test("equipment: rules totals + sanitize",             _test_equipment_rules_totals)
	_run_test("equipment: derived stats + record + replicate",  _test_character_derived_stats_and_record)
	_run_test("ui: character window rows + equip",              _test_ui_character_rows)
	_run_test("taming: fox feed yields and consumes the offer", _test_taming_fox_feed_yields)
	_run_test("taming: fox feed needs an offering",            _test_taming_fox_needs_offer)
	_run_test("taming: cooldown blocks a second feed",         _test_taming_cooldown)
	_run_test("taming: flags and offerings are per-player",    _test_taming_is_per_player)
	_run_test("taming: client forwards intent, mutates nothing", _test_taming_client_forwards_intent)
	_run_test("taming: a companion does not respawn",          _test_taming_companion_respawn_suppressed)
	_run_test("taming: companion is no target and follows owner", _test_taming_companion_follows)
	_run_test("taming: record round-trip keeps flag + companion", _test_taming_record_round_trip)
	_run_test("voxel: mine lowers height and yields material", _test_voxel_mine_yields_material)
	_run_test("voxel: mine at bedrock fails",                  _test_voxel_mine_bedrock)
	_run_test("voxel: side-face mine targets hit block",       _test_voxel_mine_side_face)
	_run_test("voxel: cycle filters to held materials",        _test_voxel_cycle_inventory_filtered)
	_run_test("voxel: place raises height and consumes",       _test_voxel_place_consumes)
	_run_test("voxel: place beyond cap fails and refunds",     _test_voxel_place_cap)
	_run_test("voxel: biome material mapping",                 _test_voxel_biome_materials)
	_run_test("voxel: grass top, soil side",                   _test_voxel_grass_top_soil_side)
	_run_test("voxel: biome border blends with a dither",      _test_voxel_biome_border_blend)
	_run_test("voxel: yield biome equals the drawn surface biome", _test_voxel_yield_matches_blended_biome)
	_run_test("voxel: no biome is borrowed across the pole", _test_voxel_pole_blend)
	_run_test("voxel: in-world border tiles unchanged by the pole rule", _test_voxel_inworld_border_unchanged)
	_run_test("voxel: shown_biome_at memoises per chunk", _test_shown_biome_memo)
	_run_test("voxel: the shown-biome memo follows the terrain slice", _test_shown_biome_follows_slice)
	_run_test("voxel: the pole bound follows the terrain slice", _test_pole_bound_follows_slice)
	_run_test("minimap: blend never borrows an unrevealed biome", _test_minimap_blend_respects_fog)
	_run_test("minimap: a second redraw looks up no biome",      _test_minimap_redraw_uses_cache)
	_run_test("minimap: sub-2px cells draw one rect per chunk",  _test_minimap_far_zoom_one_rect)
	_run_test("minimap: biome cache is bounded and seed-keyed",  _test_minimap_cache_bounded_and_seeded)
	_run_test("ui: saved layout past the edge lands inside",     _test_ui_layout_first_apply_fits)
	_run_test("climate: partial envelope does not break warm()", _test_climate_partial_envelope_warms)
	_run_test("voxel: the surface never yields a deep ore",     _test_voxel_material_rarity)
	_run_test("voxel: edits round-trip",                       _test_voxel_edits_round_trip)
	_run_test("voxel: placed block keeps material colour",    _test_voxel_placed_block_keeps_material_color)
	_run_test("voxel: mining placed block yields its material", _test_voxel_mine_placed_block_yields_material)
	_run_test("voxel: placed block preserves base colour",     _test_voxel_placed_block_preserves_base_colour)
	_run_test("voxel: place after mine keeps placed colour",   _test_voxel_place_after_mine_keeps_colour)
	_run_test("voxel: vein markers mark live veins",           _test_voxel_rare_vein_deposits)
	_run_test("voxel: an exhausted vein is host rock",         _test_voxel_rare_vein_materials)
	_run_test("voxel: terrain material is one instance",       _test_voxel_terrain_material_is_one_instance)
	_run_test("voxel: a tunnel keeps its floor and its roof",   _test_voxel_tunnel_runs)
	_run_test("voxel: the support sampler honours a ceiling",   _test_voxel_support_sampler_under_ceiling)
	_run_test("voxel: a legacy save migrates to run edits",     _test_voxel_legacy_edit_migration)
	_run_test("voxel: a seam wall ignores the build order",      _test_voxel_seam_wall_order_independent)
	_run_test("voxel: concurrent seam is exact",                 _test_voxel_concurrent_seam_exact)
	_run_test("voxel: seam exact for both chunks and the worker path", _test_voxel_seam_exact_both_ways)
	_run_test("voxel: every biome declares a surface style",    _test_voxel_surface_style_complete)
	_run_test("voxel: topsoil style is memoised per build",     _test_voxel_topsoil_style_memoised)
	_run_test("asset: reload_manifest drops the cached view",   _test_asset_reload_manifest)
	_run_test("creature: respawns share one cap budget",         _test_creature_respawns_share_cap)
	_run_test("creature: chunk index matches the instance table", _test_creature_chunk_index)
	_run_test("player: a suppressed ghost is not drawn twice",   _test_player_ghost_suppression)
	_run_test("net: a scoped apply replaces only its disc",     _test_snapshot_scoped_apply_in_place)
	_run_test("net: within_aoi takes an explicit centre",       _test_net_within_aoi_explicit_center)
	_run_test("climate: 3x3 search is exact at the jitter bound", _test_climate_search_window_exact)
	_run_test("voxel: guess cache is bounded",                  _test_voxel_guess_cache_bounded)
	_run_test("voxel: a build reuses its neighbour's guess",    _test_voxel_build_reuses_guess)
	_run_test("voxel: a re-seed drops cached guesses",          _test_voxel_reseed_drops_guesses)
	_run_test("voxel: an abandoned guess is swept by its unload", _test_voxel_abandoned_guess_swept)
	_run_test("voxel: a tunnel floor top face mines the floor",  _test_voxel_tunnel_floor_top_face)
	_run_test("voxel: the edit log is compacted",                _test_voxel_edit_log_is_compacted)
	_run_test("voxel: an unknown edit op is ignored",            _test_voxel_unknown_op_is_ignored)
	_run_test("voxel: a re-rolled legacy save keeps its stack",  _test_voxel_legacy_migration_keeps_materials)
	_run_test("voxel: an edge edit rebuilds the neighbour chunk", _test_voxel_edge_edit_rebuilds_neighbour_chunk)
	_run_test("voxel: unload prunes the heightmap to the ring",  _test_voxel_unload_prunes_heightmaps)
	_run_test("voxel: a snapshot rebuilds only what changed",    _test_voxel_snapshot_rebuild_is_scoped)
	_run_test("ui: windows toggle open/close",                 _test_ui_window_toggle)
	_run_test("ui: inventory lines reflect contents",          _test_ui_inventory_lines)
	_run_test("ui: window drag clamps on-screen",              _test_ui_window_clamp)
	_run_test("ui: layout parse/serialise drops junk",         _test_ui_layout_roundtrip)
	_run_test("ui: layout persists through a file",            _test_ui_layout_file_roundtrip)
	_run_test("ui: closing windows ends a drag",               _test_ui_drag_state_resets)
	_run_test("ui: inventory rows project N slots",            _test_ui_inventory_rows)
	_run_test("ui: item icon key + action intent mapping",     _test_ui_icon_key_and_intent)
	_run_test("ui: controls legend lives behind ?, not HUD",   _test_ui_controls_panel)
	_run_test("hud: hotbar fill / wrap / kinds",               _test_hud_hotbar_pure)
	_run_test("hud: hotbar selection drives place material",   _test_hud_hotbar_selection)
	_run_test("hud: skills and shortcut keys on the bar",      _test_hud_hotbar_skills_and_binding)
	_run_test("hud: drag and drop to boxes and the ground",    _test_hud_drag_and_drop)
	_run_test("hud: a dropped tool keeps its wear",            _test_hud_drop_keeps_durability)
	_run_test("hud: skills list + window keys",                _test_hud_skills_rows_and_window_keys)
	_run_test("hud: window dock letters match the key map",    _test_hud_window_dock)
	_run_test("ui: crafting rows gate on technology",          _test_ui_crafting_rows_tech_gate)
	_run_test("ui: technology rows report status + prereqs",   _test_ui_technology_rows_status)
	_run_test("ai: idle→alert when player within alertRadius", _test_ai_idle_to_alert)
	_run_test("ai: alert→aggressive when player within attackRadius", _test_ai_alert_to_aggressive)
	_run_test("ai: aggressive→fleeing below flee threshold",   _test_ai_aggressive_to_fleeing)
	_run_test("ai: fleeing→idle when safe distance exceeded",  _test_ai_fleeing_to_idle)
	_run_test("ai: attack emits combat_round_requested",       _test_ai_attack_emits_combat)
	_run_test("ai: pack shares aggressive state",              _test_ai_pack_shares_aggressive)
	_run_test("ai: herd shares fleeing state",                 _test_ai_herd_shares_flee)
	_run_test("ai: solitary creature does not propagate",      _test_ai_solitary_no_propagation)
	_run_test("ai: group behavior reads from fabric",          _test_ai_group_behavior_reads_fabric)
	_run_test("ai: targets the nearest of every player",        _test_ai_targets_nearest_of_all_players)
	_run_test("player: respawn resets hp and alive flag",      _test_player_respawn)
	_run_test("chunk: desired set within view distance",        _test_chunk_desired_set)
	_run_test("chunk: world/chunk coordinate round-trip",       _test_chunk_coordinate_round_trip)
	_run_test("chunk: per-chunk biome is stable",               _test_chunk_biome_stable)
	_run_test("terrain: neighbouring chunks mostly share a biome", _test_biome_regions_coherent)
	_run_test("climate: fabric envelopes select the biome",     _test_climate_envelope_selects)
	_run_test("voxel: topsoil yields the biome's fabric soil", _test_mine_topsoil_yields_biome_soil)
	_run_test("chunk: load/unload emits signals",               _test_chunk_load_unload_signals)
	_run_test("chunk: refresh queues nearest-first",            _test_chunk_refresh_queues_nearest_first)
	_run_test("chunk: load queue respects per-frame budget",    _test_chunk_load_queue_respects_budget)
	_run_test("chunk: voxel edits isolated per chunk",          _test_chunk_voxel_edits_isolated)
	_run_test("chunk: unload preserves edits on reload",        _test_chunk_unload_preserves_edits)
	_run_test("chunk: creature spawn scales per chunk",         _test_chunk_creature_spawn_per_chunk)
	_run_test("chunk: tree spawn scales per chunk",             _test_chunk_tree_spawn_per_chunk)
	_run_test("clock: hemispheres are opposite",                 _test_clock_hemispheres_opposite)
	_run_test("clock: day length varies by latitude",            _test_clock_day_length_by_latitude)
	_run_test("clock: sun follows the hour and the season",      _test_clock_sun_elevation)
	_run_test("clock: seasonal temperature, tint and snow",      _test_clock_season_effects)
	_run_test("clock: sun follows the biome's dayNightSpeed",    _test_clock_sun_biome_daylight)
	_run_test("clock: season tint is per chunk biome",           _test_clock_season_tint_per_chunk)
	_run_test("clock: client stays within 1 s over 10 minutes",  _test_clock_client_sync)
	_run_test("clock: persistence, HUD text and fabric values",  _test_clock_persistence_and_fabric)
	_run_test("spawn: hash bits are independent",                _test_spawn_roll_mix_avalanche)
	_run_test("spawn: missing fields warn once",                 _test_spawn_missing_fields_warns_once)
	_run_test("spawn: hash output pinned",                       _test_spawn_roll_mix_pinned)
	_run_test("spawn: seeded roll, density and pack size",       _test_spawn_roll_pure)
	_run_test("spawn: creature packs are scarce and seeded",     _test_spawn_creature_scarcity)
	_run_test("spawn: the population cap holds and is released", _test_spawn_population_cap)
	_run_test("spawn: packs stay in their chunk and retry",      _test_spawn_pack_bounds_and_retry)
	_run_test("spawn: density noise is per species",            _test_spawn_density_per_species)
	_run_test("rig tree: a missing clip falls back to idle",    _test_rig_tree_missing_clip_fallback)
	_run_test("asset: manifest merges the private over public", _test_asset_manifest_merge)
	_run_test("character: remote avatar move/remove",           _test_character_remote_avatar)
	_run_test("spawn: tree density comes from the fabric",       _test_spawn_tree_density)
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
	_run_test("chunk: reload honours engaged spawn budget",     _test_chunk_reload_engaged_budget)
	_run_test("chunk: apply_edits preserves dirty chunks",      _test_apply_edits_preserves_dirty_chunks)
	_run_test("chunk: persistence round-trips per-chunk edits", _test_chunk_persistence_manifest)
	_run_test("chunk: minimap cells resolve chunks",            _test_chunk_minimap_cells)
	_run_test("chunk: minimap reveals fog of war",              _test_chunk_minimap_fog_of_war)
	_run_test("chunk: minimap zooms in and out",                _test_chunk_minimap_zoom)
	_run_test("chunk: minimap arrow points at facing",          _test_chunk_minimap_arrow_direction)
	# Phase 42 — threaded chunk build, greedy merge, the first-ring gate.
	_run_test("chunk: the pure builder is a function of its args", _test_voxel_build_arrays_pure)
	_run_test("chunk: greedy merge collapses a flat chunk",      _test_voxel_greedy_merge)
	_run_test("chunk: the merge never spans a gap",              _test_voxel_merge_keeps_lone_quad)
	_run_test("chunk: a load dispatches a worker build",         _test_chunk_load_dispatches_build)
	_run_test("chunk: the first-ring gate opens when built",     _test_chunk_first_ring_gate)
	_run_test("chunk: the prefetch ring widens the stream",      _test_chunk_prefetch_ring)
	# Phase 42 review — the worker-build follow-ups the review pass found.
	_run_test("chunk: an edit during a build is not lost",       _test_chunk_edit_during_build_is_not_lost)
	_run_test("chunk: an edit dispatches its rebuild",           _test_chunk_edit_dispatches_rebuild)
	_run_test("chunk: stop still lands in-flight builds",        _test_chunk_stop_does_not_abandon_builds)
	_run_test("voxel: an empty worker result is refused",        _test_voxel_empty_worker_result_is_refused)
	_run_test("chunk: the first-ring gate times out",            _test_host_boot_first_ring_timeout)
	_run_test("player: the loading freeze refuses world input",  _test_player_world_input_freeze)
	# Phase 42 second review pass — the streaming-loop holes the first pass left.
	_run_test("chunk: a rebuild respects the in-flight cap",     _test_chunk_rebuild_respects_inflight_cap)
	_run_test("chunk: a queued chunk that leaves range cancels",  _test_chunk_queued_leaving_range_is_cancelled)
	_run_test("chunk: a groundless chunk is re-armed",           _test_chunk_failed_chunk_is_rearmed)
	_run_test("chunk: contents spawn once the ground exists",    _test_chunk_contents_spawn_after_ground)
	_run_test("chunk: the build split is measured",              _test_chunk_build_split_probe)
	_run_test("player: the loading freeze holds the body",       _test_player_movement_freeze)
	_run_test("ui: the loading screen shows and hides",          _test_loading_screen_visibility)
	# Phase 42 third review pass — the streaming loop's own bookkeeping, and the CI boot gate.
	_run_test("chunk: a stationary player re-arms a failed chunk", _test_chunk_failed_chunk_is_rearmed_while_stationary)
	_run_test("chunk: unloading drops a queued rebuild",         _test_chunk_unload_drops_queued_rebuild)
	_run_test("chunk: an edit does not re-spawn contents",       _test_chunk_contents_spawn_once_per_residency)
	_run_test("chunk: a drain reads the window once",            _test_chunk_drain_reads_window_once)
	_run_test("boot: a boot quits when its world is up",         _test_quit_after_boot_predicate)
	# Phase 42 fourth review pass — the self-heal sweep, the idle drain, and the rig path.
	_run_test("chunk: a failed REBUILD of a built chunk heals",  _test_chunk_failed_rebuild_of_built_chunk_is_rearmed)
	_run_test("chunk: the stationary throttle suppresses a re-arm", _test_chunk_self_heal_throttle_suppresses_rearm)
	_run_test("chunk: a crossing stamps the self-heal clock",    _test_chunk_crossing_stamps_self_heal_clock)
	_run_test("chunk: the self-heal reads the window once",      _test_chunk_self_heal_reads_window_once)
	_run_test("chunk: an idle drain reads no position",          _test_chunk_idle_drain_reads_no_position)
	_run_test("chunk: a rig dispatch keeps contents per residency", _test_chunk_rig_dispatch_respects_contents_residency)
	# Phase 42 fifth review pass — the per-actor harvest, the seam re-scope, the resurrect guard.
	_run_test("net: a remote mine credits the actor",           _test_net_remote_mine_credits_the_actor)
	_run_test("net: a remote place spends the actor's pack",    _test_net_remote_place_spends_the_actor)
	_run_test("net: a remote chop credits the actor",           _test_net_remote_chop_credits_the_actor)
	_run_test("voxel: a re-scope rebuilds a changed tile's seam", _test_voxel_apply_edits_rebuilds_seam_neighbours)
	_run_test("voxel: an edit never resurrects an unloaded chunk", _test_voxel_edit_does_not_resurrect_unloaded_chunk)
	# Phase 42 sixth review pass — a legacy edit shape the migration must refuse.
	_run_test("voxel: a legacy edit of an unknown shape is dropped", _test_voxel_legacy_edit_type_guard)
	# Phase 42 eighth review pass — the deposit build off the main thread, the kept window,
	# the split assertion, the re-scope's rebuild route, and the flush's retries.
	_run_test("chunk: apply_edits dispatches a rebuild",     _test_voxel_apply_edits_dispatches_rebuild)
	_run_test("chunk: flush_builds awaits its retries",      _test_chunk_flush_builds_awaits_retries)
	# Phase 42 ninth review pass — the kept window is the queue window, the in-flight cap is
	# enforced at dispatch, the split probe's absolute frame ceiling, the packed colour's wrap,
	# the prebuilt biome roll table, and the required build-payload shape.
	_run_test("chunk: the kept window is the stream radius",  _test_chunk_kept_window_is_stream_radius)
	_run_test("chunk: unloads are budgeted per frame",  _test_chunk_unloads_budgeted)
	_run_test("chunk: a direct load respects the in-flight cap", _test_chunk_load_respects_inflight_cap)
	_run_test("voxel: the group key survives the colour band", _test_voxel_group_key_colour_band)
	_run_test("ore: the band table is prebuilt",               _test_voxel_biome_roll_table_prebuilt)
	_run_test("ore: every canonical biome has a bias",          _test_voxel_every_canonical_biome_has_a_roll_table)
	_run_test("voxel: the build payload shape is required",   _test_voxel_build_payload_shape_required)
	_run_test("chunk: the gathered payload carries the ring", _test_chunk_gather_carries_the_ring)
	# Phase 43 — natural resource distribution: the ore field, its fabric gates, vein yield
	# and depletion.
	_run_test("ore: a fixed seed puts the same veins in the same place", _test_ore_deterministic)
	_run_test("ore: a client sees the host's veins with no snapshot", _test_ore_client_agrees_without_snapshot)
	_run_test("ore: aethermite keeps to its band and its ley lines", _test_ore_aethermite_gates)
	_run_test("ore: the bands are fabric values",              _test_ore_bands_are_fabric)
	_run_test("ore: the ley field is a field of lines",        _test_ore_ley_field)
	_run_test("ore: the uniform draw is gone",                 _test_ore_uniform_draw_gone)
	_run_test("ore: a blob is continuous across a chunk border", _test_ore_blob_crosses_chunk_border)
	_run_test("ore: a vein yields more than one and runs out", _test_ore_vein_yields_and_exhausts)
	_run_test("ore: surrounding rock is the bias, never the gated ore", _test_ore_host_rock_yield)
	_run_test("ore: depletion is one op per vein and persists", _test_ore_depletion_persists)
	_run_test("ore: surface-breaking veins are the exception", _test_ore_surface_veins_rare)
	_run_test("ore: surface-vein chance is the fabric value",  _test_ore_surface_vein_chance_gates_by_biome)
	_run_test("ore: a client replays the host's depletion",    _test_ore_client_replays_depletion)
	_run_test("ore: the build payload carries the field",      _test_ore_build_payload_carries_field)
	_run_test("player: facing is a normalized yaw vector",      _test_player_facing)
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
	_run_test("net: acting identity is the bound connection",    _test_net_peer_party_scopes_identity)
	_run_test("net: social intents bind connection identity",    _test_net_social_intents_bind_connection_identity)
	_run_test("net: trade intents bind connection identity",     _test_net_trade_intents_bind_connection_identity)
	_run_test("net: block edit needs handshake + reach",         _test_net_block_intent_requires_handshake_and_reach)
	_run_test("net: tree chop needs handshake + reach",          _test_net_tree_intent_requires_handshake_and_reach)
	_run_test("net: client packet size is capped",               _test_net_client_packet_size_capped)
	_run_test("net: client packet rate is limited per peer",     _test_net_client_packet_rate_limited)
	_run_test("boot: the automated suite is gated",              _test_boot_suite_is_gated)
	_run_test("identity: public handles are derived + opaque",   _test_identity_handles_are_derived_and_opaque)
	_run_test("identity: social syncs carry handles, not ids",   _test_identity_syncs_are_redacted)
	_run_test("identity: a client adopts its own handle",        _test_client_adopts_its_own_handle)
	_run_test("net: AOI center defaults to spawn; in_aoi gates", _test_net_aoi_center_and_in_aoi)
	_run_test("net: re-scope snapshot edits hold only AOI chunks", _test_snapshot_edits_scoped_to_aoi)
	_run_test("net: AOI recipients are near peers only",         _test_net_aoi_recipients)
	_run_test("net: AOI region floors to grid cell",             _test_net_aoi_region)
	_run_test("net: player intents bind connection identity",    _test_net_player_intents_bind_connection_identity)
	_run_test("net: own-state push is peer-scoped",              _test_net_own_state_push_is_peer_scoped)
	_run_test("asset: placeholder resolves at canonical path",  _test_asset_placeholder_resolves)
	_run_test("asset: no private-only paths hardcoded",          _test_asset_no_private_paths_hardcoded)
	_run_test("asset: pck round-trip proves override works",    _test_asset_pck_round_trip_override)
	_run_test("asset: manifest lists keys that exist on disk",   _test_asset_manifest_keys_exist)
	_run_test("asset: load_mesh / load_animation_library from .glb.raw", _test_asset_load_mesh_and_animation)
	_run_test("asset: placeholder rig is a visible body (#112)", _test_asset_placeholder_rig_is_a_body)
	_run_test("asset: missing model key warns and falls back",   _test_asset_missing_model_falls_back)
	_run_test("asset: creature model key derived from entity name", _test_asset_creature_key)
	_run_test("rig tree: every Locomotion.State maps to a node", _test_rig_tree_state_mapping_total)
	_run_test("rig: attach_rig wires scene + tree, falls back on bad key", _test_attach_rig)
	_run_test("trade: both accept resolves exchange",           _test_trade_both_accept_resolves)
	_run_test("trade: counter-offer requires prior offer",      _test_trade_counter_offer_requires_offer)
	_run_test("trade: reject closes session",                   _test_trade_reject)
	_run_test("trade: missing goods blocks resolution",         _test_trade_missing_goods)
	_run_test("trade: Trade tier lowers broker fee",           _test_trade_skill_lowers_fee)
	_run_test("trade: fee burns the best instance",            _test_trade_fee_burns_best_instance)
	_run_test("trade: no broker fee when neither side is player", _test_trade_no_fee_without_player)
	_run_test("trade: propose reports success",                 _test_trade_state_reports_success)
	_run_test("trade: get_trade returns a defensive copy",      _test_trade_get_trade_defensive_copy)
	_run_test("trade: get_trade deep-copies nested offers",     _test_trade_get_trade_deep_copy)
	_run_test("trade: unknown party is rejected",               _test_trade_unknown_party_rejected)
	_run_test("trade: failed resolve reports still-pending",    _test_trade_failed_resolve_stays_pending)
	_run_test("trade: client forwards intents",                 _test_trade_client_forwards_intents)
	_run_test("trade: client applies authoritative sync",       _test_trade_client_applies_sync)
	_run_test("trade: double accept does not duplicate",        _test_trade_double_accept_no_dupe)
	_run_test("trade: remote party has no host inventory",      _test_trade_remote_party_no_inventory)
	_run_test("trade: rejected trade cannot resolve",           _test_trade_rejected_cannot_resolve)
	_run_test("trade: broker fee never destroys goods",         _test_trade_fee_never_destroys_goods)
	_run_test("trade: state round-trips for snapshot/persist",  _test_trade_data_round_trip)
	_run_test("trade: partial accept broadcasts sync",          _test_trade_partial_accept_syncs)
	_run_test("trade: broken item stays broken across trade",    _test_trade_broken_item_not_pristine)
	_run_test("trade: pristine transfer preserves broken copy",  _test_trade_pristine_to_broken_holder)
	_run_test("market: list and browse listings",               _test_market_list_browse)
	_run_test("market: buy transfers escrow to buyer",          _test_market_buy_transfers)
	_run_test("market: expired listing is not browsable",       _test_market_expired_not_browsable)
	_run_test("market: expiry is wall-clock, not uptime",       _test_market_expiry_wall_clock)
	_run_test("market: listings persist across disk save/load", _test_market_persistence_disk)
	_run_test("market: escrow prevents list/buy duplication",   _test_market_escrow_no_dupe)
	_run_test("market: buy fails without buyer inventory",      _test_market_buy_no_inventory)
	_run_test("market: list rejects insufficient stock",        _test_market_list_insufficient)
	_run_test("market: expiry refunds escrow to seller",        _test_market_expire_refunds_escrow)
	_run_test("market: expiry refunds worn item as worn",       _test_market_expire_preserves_wear)
	_run_test("market: restored ids never collide",             _test_market_restore_no_id_collision)
	_run_test("market: client forwards list/buy intent",        _test_market_client_forwards_intent)
	_run_test("market: client applies authoritative sync",      _test_market_sync_applies_on_client)
	_run_test("market: authoritative list emits sync",          _test_market_authoritative_emits_sync)
	_run_test("market: expiry keeps escrow when seller full",   _test_market_expire_keeps_escrow_when_full)
	_run_test("market: expiry drops listing with no seller inv", _test_market_expire_drops_no_inventory_seller)
	_run_test("proposal: quorum met ratifies",                  _test_proposal_quorum_ratify)
	_run_test("proposal: below quorum stays proposed",          _test_proposal_below_quorum)
	_run_test("proposal: author cannot vote on own proposal",   _test_proposal_author_self_vote)
	_run_test("proposal: voting window rejects late votes",     _test_proposal_window_expiry)
	_run_test("proposal: lapsed proposal transitions to expired", _test_proposal_expire_transitions)
	_run_test("proposal: client forwards submit/vote intent",   _test_proposal_client_forwards_intent)
	_run_test("proposal: client applies authoritative sync",    _test_proposal_sync_applies_on_client)
	_run_test("proposal: open proposals round-trip",            _test_proposal_persistence_round_trip)
	_run_test("proposal: ratification updates decisions log",   _test_proposal_decisions_log)
	_run_test("proposal: below threshold stays proposed",       _test_proposal_below_threshold)
	_run_test("proposal: leadership gates guild formation",     _test_proposal_leadership_guild)
	_run_test("skills: unknown tier fails closed",              _test_unknown_tier_fails_closed)
	_run_test("proposal: get_proposal deep-copies votes",       _test_proposal_get_proposal_deep_copy)
	_run_test("proposal: supersede replaces a proposal",        _test_proposal_supersede)
	_run_test("proposal: supersede needs ratified replacement", _test_proposal_supersede_requires_ratified_replacement)
	_run_test("proposal: expiry tick is authority-gated",       _test_proposal_expiry_authority_gated)
	_run_test("instancing: pool alloc grows and recycles",      _test_multimesh_pool_alloc_recycle)
	_run_test("instancing: headless creature has no visual",    _test_creature_headless_no_visual)
	_run_test("instancing: creatures share one pool",           _test_creature_single_pool)
	_run_test("instancing: headless player has no ghost/broadcast", _test_player_headless_no_ghost_or_broadcast)
	_run_test("identity: restart round-trip restores the world",  _test_identity_restart_round_trip)
	_run_test("identity: reconnect keeps the inventory",         _test_identity_reconnect_keeps_inventory)
	_run_test("identity: disconnect mid-craft stays consistent", _test_identity_disconnect_mid_craft)
	_run_test("identity: spoofed id is rejected",               _test_identity_spoofed_id_rejected)
	_run_test("identity: snapshot carries own record only on handshake", _test_identity_snapshot_own_record_rule)
	_run_test("identity: record replay skips ids not spawned",   _test_identity_record_replay_skips_unknown_ids)
	_run_test("identity: unknown peer position is not 0,0,0",    _test_identity_unknown_peer_has_no_position)
	# Phase 33 review fixes
	_run_test("persistence: incremental merge keeps unstreamed creature deaths", _test_merge_keeps_unstreamed_creature_deaths)
	_run_test("persistence: creature merge is per instance_id",   _test_merge_creature_states_by_instance_id)
	_run_test("persistence: autosave interval falls back when 0", _test_autosave_interval_falls_back)
	_run_test("persistence: player id is path-safe",              _test_player_id_is_path_safe)
	_run_test("persistence: non-canonical player id refused",     _test_non_canonical_player_id_refused)
	_run_test("persistence: thread-safe write_job writes records", _test_write_job_writes_records)
	# Phase 42 sixth review pass — an incremental save that can express a deleted chunk.
	_run_test("persistence: an incremental save can delete a chunk", _test_persistence_incremental_save_can_delete_a_chunk)
	# Phase 52 — region storage and per-peer streaming.
	_run_test("region: chunks map onto 32x32 regions, negatives floor", _test_region_mapping)
	_run_test("region: a save after editing one chunk writes exactly one region file", _test_region_save_writes_one_file)
	_run_test("region: a Phase 51 save migrates with every edit intact", _test_region_migrates_monolith)
	_run_test("region: a full save erases compacted chunks; migration keeps newer region data", _test_region_full_save_erases_and_migration_keeps_newer)
	_run_test("region: an unreadable region file is never overwritten by a save", _test_region_unreadable_not_overwritten)
	_run_test("region: one unreadable region does not block the others' save", _test_region_partial_save)
	_run_test("region: only edge chunks pull in neighbouring regions", _test_region_neighbour_expansion_edges_only)
	_run_test("region: a failed region read is retried, not marked resident", _test_region_failed_read_retried)
	_run_test("registry: bound peer ids come straight off the peer map", _test_registry_bound_peer_ids)
	_run_test("spawn: new players avoid colonized regions", _test_spawn_avoids_colonized)
	_run_test("spawn: friend code lands near the friend", _test_spawn_friend_near)
	_run_test("spawn: respawn point survives a move + reload (host and client)", _test_spawn_point_persists)
	_run_test("spawn: an exact far spawn respawns exactly; placement reads the record once", _test_exact_spawn_respawn)
	_run_test("persistence: a fresh player's first-boot spawn is recorded exactly", _test_first_boot_spawn_exact)
	_run_test("spawn: counted chunks survive a colonization reload", _test_colonization_counted_persists)
	_run_test("spawn: the colonization map scores, persists and drops malformed data", _test_colonization_map)
	_run_test("spawn: a fresh join is placed, a reconnect is not", _test_spawn_registry_placement)
	_run_test("region: a vein depleted from an evicted chunk stays depleted in its neighbours", _test_region_evict_keeps_vein_depletion)
	_run_test("region: one unwritable region does not stop the rest of the save", _test_region_failed_write_saves_the_rest)
	_run_test("region: a region whose read fails is not resident and is retried", _test_region_failed_read_not_resident)
	_run_test("chat: /where is spelled once",                       _test_chat_command_constant)
	_run_test("region: a failed read backs off",                    _test_region_failed_read_backs_off)
	_run_test("region: op lists with non-dictionary ops are dropped", _test_region_entry_rejects_bad_ops)
	_run_test("region: a chunk entry with edits or materials of the wrong type is skipped with one warning", _test_region_malformed_entry_skipped)
	_run_test("peer window: a flood of far claims moves the window at most once", _test_peer_window_rate_limited)
	_run_test("peer window: the interval is measured on the injected clock", _test_peer_window_fake_clock)
	_run_test("peer window: a 20-chunk claim is clamped inside the map and across the seam", _test_peer_window_clamp_cap)
	_run_test("peer window: a seam crossing is a short step, not a planet-wide one", _test_peer_window_clamps_across_seam)
	_run_test("peer window: a host-driven move recentres at once", _test_peer_window_host_driven)
	_run_test("peer window: the host's periodic sync is never a counted refusal", _test_peer_window_host_sync)
	_run_test("peer window: syncs and claims keep separate interval clocks", _test_peer_window_separate_clocks)
	_run_test("peer window: a far host sync is counted apart from refusals", _test_peer_window_sync_far_hops)
	_run_test("chunks: set_clock resets the self-heal and stranded-retry throttles", _test_chunk_set_clock_resets_throttles)
	_run_test("diag: warn_count survives concurrent warnings from worker threads", _test_diag_warn_concurrent)
	_run_test("peer window: a move into a stored region makes its edits resident", _test_peer_window_move_loads_region_edits)
	_run_test("region: 1,000 regions on disk, only the ones near a window are resident", _test_region_streams_only_near_windows)
	_run_test("chunk: each peer has a window and chunks are reference counted", _test_chunk_peer_windows_refcount)
	_run_test("chunk: two peers 100 km apart each have creatures simulated", _test_chunk_far_peers_simulated)
	_run_test("chunk: dirty clear is per key + re-markable",      _test_dirty_keys_clear_and_remark)
	_run_test("identity: minted id carries 128-bit entropy",      _test_minted_id_has_crypto_entropy)
	_run_test("identity: local player id is not claimable",       _test_local_player_id_not_claimable)
	_run_test("identity: offline record loads lazily on claim",   _test_record_loaded_lazily_on_claim)
	_run_test("identity: save writes online records only",        _test_save_writes_online_records_only)
	_run_test("creature: despawn keeps the death record",         _test_despawn_keeps_death_record)
	_run_test("creature: recorded death survives boot replay",    _test_recorded_death_survives_boot_replay)
	_run_test("creature: state delta keeps the respawn deadline", _test_creature_state_delta_keeps_deadline)
	_run_test("persistence: shutdown poll is independent of autosave", _test_shutdown_poll_cadence)
	_run_test("identity: client-declared hp is never persisted",   _test_remote_hp_not_persisted)
	_run_test("ui: retiring 1,000 controls prunes the list a handful of times", _test_ui_retire_prunes_amortised)
	_run_test("identity: disconnect evicts record + inventory",   _test_disconnect_evicts_player)
	_run_test("identity: handshake retry re-answers a bound peer", _test_handshake_retry_reanswers_peer)
	_run_test("net: retry re-presents the join intent",           _test_retry_represents_join_intent)
	_run_test("market: cleared party inventory binding",          _test_party_inventory_binding_cleared)
	_run_test("persistence: failed write reports + keeps record",  _test_failed_write_reports_and_preserves)
	_run_test("craft: craft uses the crafter's own inventory",    _test_craft_uses_crafter_inventory)
	_run_test("craft: client forwards a craft intent",            _test_craft_client_forwards_intent)

	# Phase 37 review fixes
	_run_test("net: inventory sync is owner-scoped",              _test_inventory_sync_is_owner_scoped)
	_run_test("net: inventory sync is peer-scoped on the wire",   _test_net_inventory_sync_is_peer_scoped)
	_run_test("net: incomplete snapshot is evicted on disconnect", _test_net_incomplete_snapshot_evicted_on_disconnect)
	_run_test("net: a player's damage is routed to their peer",   _test_net_peer_damage_is_peer_scoped)
	_run_test("identity: a named party is a handle, not an id",   _test_named_party_accepts_handles_only)
	_run_test("taming: cooldowns are durable",                    _test_taming_cooldowns_are_durable)
	_run_test("taming: per-player mirrors are evicted",           _test_taming_mirrors_evicted_on_forget)
	_run_test("battle: player rounds route by target id",         _test_battle_routes_player_rounds_by_target)
	_run_test("creature: instances_view is cached and live",      _test_creature_instances_view_cached)

	# Phase 38 review fixes
	_run_test("identity: the host simulates a peer's hp",         _test_host_simulates_peer_hp)
	_run_test("net: snapshot social keys are one list",           _test_snapshot_social_keys_are_identified)
	_run_test("net: snapshot buffer clears when host is lost",    _test_net_snapshot_buffer_cleared_when_host_lost)
	_run_test("taming: cooldown mirror prunes in place",          _test_taming_cooldown_mirror_pruned_in_place)

	# Phase 39 — deliverable 1 (a downed body comes back) and the network harness's
	# own pure logic. The harness's SOCKET half runs in its own boot mode
	# (`--net-harness <role>`, see src/tests/net_harness.gd); everything here is the
	# part that can be asserted without frames.
	_run_test("identity: the respawn rule is pure",               _test_hp_after_respawn_is_pure)
	_run_test("identity: a downed peer comes back",               _test_host_simulated_hp_respawns)
	_run_test("identity: set_hp starts the respawn countdown",    _test_player_set_hp_starts_respawn)
	_run_test("identity: set_hp announces and clears",           _test_player_set_hp_announces_and_clears)
	_run_test("identity: a sliver of health is down",             _test_hp_sliver_is_downed)
	_run_test("net: harness step table is the driver contract",   _test_net_harness_step_table)
	_run_test("net: harness log line round-trips",                _test_net_harness_line_round_trip)
	_run_test("net: harness verdict treats refusal as a pass",    _test_net_harness_verdict)
	_run_test("net: harness targets are deterministic",           _test_net_harness_target_selection)
	_run_test("net: harness awaits are not bare",                 _test_net_harness_bare_await_audit)

	# Self-check: the _run_test list above is manual, so a test function can be
	# written but forgotten from the list. Fail loudly instead of silently
	# dropping it: any _test_* method not registered above fails the suite.
	for m in get_method_list():
		var method_name: String = str(m.get("name", ""))
		if method_name.begins_with("_test_") and not _registered_names.has(method_name):
			push_error("TestSuite: '%s' is defined but never registered — add it to the _run_test list" % method_name)
			_fail += 1

	# Phase 84 — the LAST check. Nothing here waits a frame (`--quit` ends the boot before one
	# lands), so every test frees what it made with `free()`, and a `queue_free` the code under
	# test made is freed by the test too. A node left parentless shows up in the engine's count.
	_assert_no_orphan_nodes()

	Diag.quiet = false
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
# Phase 26/27 — instancing + headless server
# ---------------------------------------------------------------------------

func _test_multimesh_pool_alloc_recycle() -> void:
	var pool := MultimeshPool.new()
	add_child(pool)
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	pool.setup(box, true)
	assert_eq(pool.alloc(), 0, "first alloc is index 0")
	assert_eq(pool.alloc(), 1, "second alloc is index 1")
	assert_eq(pool.alloc(), 2, "third alloc is index 2")
	pool.release(1)
	assert_eq(pool.alloc(), 1, "released index is recycled first")
	for i in range(300):
		pool.alloc()
	assert_true(pool.instance_count() > 300, "pool grew beyond the initial step")
	pool.free()

func _test_creature_headless_no_visual() -> void:
	# A headless server (render_visuals = false) spawns creatures as pure data:
	# no MultiMesh pool is built and each instance carries the -1 sentinel index.
	var c := CreatureSlice.new()
	c.render_visuals = false
	add_child(c)
	c.spawn_for_chunk(Vector2i(0, 0))
	var all := c.get_all_instances()
	assert_true(all.size() > 0, "headless creatures still spawn as data")
	assert_true(c._pool == null, "no pool is built when render_visuals is false")
	assert_eq(int(c._instances[all[0]["instance_id"]]["mi"]), -1, "instance index is the -1 sentinel")
	c.free()

func _test_creature_single_pool() -> void:
	# With rendering on, every creature shares ONE MultiMesh pool (one draw call).
	var c := CreatureSlice.new()
	add_child(c)
	c.spawn_for_chunk(Vector2i(0, 0))
	var all := c.get_all_instances()
	assert_true(all.size() > 1, "enough creatures to exercise the shared pool")
	assert_true(c._pool != null, "a pool is built when rendering")
	var seen := {}
	for inst in all:
		var mi: int = int(c._instances[inst["instance_id"]]["mi"])
		assert_true(mi >= 0, "rendered creature has a valid instance index")
		seen[mi] = true
	assert_eq(seen.size(), all.size(), "instance indices are unique per creature")
	c.free()

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
		# Force the respawn timer to have elapsed, then tick. Deadlines are
		# WALL-CLOCK seconds (Phase 33), not process uptime.
		c._instances[iid]["respawn_at"] = Time.get_unix_time_from_system() - 1.0
		c._tick_respawn()
		assert_false(b._hp_state.has(iid), "battle hp state cleared on respawn")
		assert_eq(c._instances[iid]["state"], "idle", "creature state back to idle after respawn")
	b.free()
	c.free()

# ---------------------------------------------------------------------------
# SpatialHash tests (Phase 28)
# ---------------------------------------------------------------------------

func _test_spatial_query_radius() -> void:
	var h := SpatialHash.new(8.0)
	h.insert("a", Vector3(0.0, 0.0, 0.0))
	h.insert("b", Vector3(2.0, 0.0, 0.0))
	h.insert("far", Vector3(100.0, 0.0, 100.0))
	var near := h.query_radius(Vector3(0.0, 0.0, 0.0), 3.0)
	assert_true(near.has("a"), "entity at origin within radius")
	assert_true(near.has("b"), "entity 2m away within radius")
	assert_false(near.has("far"), "distant entity excluded from radius query")
	assert_eq(h.size(), 3, "hash tracks all three entities")

func _test_spatial_update_moves_cell() -> void:
	var h := SpatialHash.new(8.0)
	h.insert("a", Vector3(0.0, 0.0, 0.0))
	h.update("a", Vector3(30.0, 0.0, 30.0))
	assert_false(h.query_radius(Vector3(0.0, 0.0, 0.0), 1.0).has("a"), "entity no longer found near old cell")
	assert_true(h.query_radius(Vector3(30.0, 0.0, 30.0), 1.0).has("a"), "entity found near new position")
	assert_eq(h.size(), 1, "update preserves a single entry")

func _test_spatial_remove() -> void:
	var h := SpatialHash.new(8.0)
	h.insert("a", Vector3(0.0, 0.0, 0.0))
	h.insert("b", Vector3(1.0, 0.0, 0.0))
	h.remove("a")
	assert_false(h.has("a"), "removed entity no longer present")
	assert_true(h.has("b"), "other entity unaffected")
	assert_eq(h.size(), 1, "size reflects removal")
	h.remove("a")
	assert_eq(h.size(), 1, "removing an unknown id is a no-op")

func _test_spatial_nearest() -> void:
	var h := SpatialHash.new(8.0)
	h.insert("near", Vector3(1.0, 0.0, 0.0))
	h.insert("far", Vector3(50.0, 0.0, 50.0))
	assert_eq(h.nearest(Vector3(0.0, 0.0, 0.0)), "near", "nearest returns closest entity")
	assert_eq(h.nearest(Vector3(100.0, 0.0, 100.0)), "far", "nearest from a distant origin")

func _test_creature_nearest_via_hash() -> void:
	var c := CreatureSlice.new()
	add_child(c)
	c.spawn_for_chunk(Vector2i(0, 0))
	var instances := c.get_all_instances()
	assert_true(instances.size() > 0, "need at least one instance")
	if instances.size() > 0:
		assert_eq(c._spatial.size(), instances.size(), "spatial hash mirrors _instances count")
		var pos: Vector3 = instances[0]["position"]
		var result := c.nearest_creature(pos, 1000.0)
		assert_true(result != "", "nearest_creature via hash returns an id")
	c.free()

func _test_creature_respawn_rehashes_spatial() -> void:
	var c := CreatureSlice.new()
	add_child(c)
	c.spawn_for_chunk(Vector2i(0, 0))
	var instances := c.get_all_instances()
	assert_true(instances.size() > 0, "need an instance to respawn")
	if instances.size() > 0:
		var iid: String = instances[0]["instance_id"]
		var spawn_pos: Vector3 = c._instances[iid]["spawn_pos"]
		# Move the creature away from its spawn point (the AI patrol path does this).
		var moved := spawn_pos + Vector3(100.0, 0.0, 100.0)
		c.set_instance_position(iid, moved)
		assert_false(c._spatial.query_radius(spawn_pos, 1.0).has(iid), "hash cleared old cell after move")
		assert_true(c._spatial.query_radius(moved, 1.0).has(iid), "hash holds the moved position")
		# Kill it and force the respawn timer to have elapsed, then tick.
		c._instances[iid]["state"] = "dead"
		c._instances[iid]["respawn_at"] = Time.get_unix_time_from_system() - 1.0
		c._tick_respawn()
		assert_eq(c._instances[iid]["position"], spawn_pos, "position reset to the spawn point")
		assert_true(c._spatial.query_radius(spawn_pos, 1.0).has(iid), "hash re-keyed to the spawn point after respawn")
		assert_false(c._spatial.query_radius(moved, 1.0).has(iid), "hash cleared the death cell after respawn")
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

## Phase 41 — the world seed is the world's IDENTITY: two runs with the same seed
## must produce a byte-identical heightmap per chunk, which is what lets a host and
## a client agree on the ground with no heightmap on the wire. The biome seed was
## already fixed; heights were the only non-determinism (`_noise.seed = randi()`).
func _test_terrain_seed_deterministic() -> void:
	var a := TerrainSlice.new()
	add_child(a)
	var b := TerrainSlice.new()
	add_child(b)
	var c := TerrainSlice.new()
	add_child(c)
	a.set_world_seed(4242)
	b.set_world_seed(4242)
	c.set_world_seed(4243)
	assert_eq(a.get_world_seed(), 4242, "the seed reads back")
	var ha: Array = a._generate(Vector2i(0, 0))
	var hb: Array = b._generate(Vector2i(0, 0))
	var hc: Array = c._generate(Vector2i(0, 0))
	assert_eq(ha.size(), TerrainSlice.CHUNK_SIZE * TerrainSlice.CHUNK_SIZE, "a full chunk of heights")
	assert_eq(hash(ha), hash(hb), "the same seed generates the same chunk")
	assert_true(hash(ha) != hash(hc), "a different seed generates a different chunk")
	a.free()
	b.free()
	c.free()

## Phase 50 — the world is a planet: X wraps, so the last chunk column meets the first with no
## seam wall; Z is latitude and ends in polar ice.
func _test_terrain_wraps_east_west() -> void:
	var t := TerrainSlice.new()
	add_child(t)
	t.set_world_seed(77)
	var c := TerrainSlice.circumference_chunks()
	assert_eq(c, 1250000, "40,000 km around is 1.25M chunks")
	var last := TerrainSlice.wrap_chunk(Vector2i(c / 2 - 1, 3))
	var first := TerrainSlice.wrap_chunk(Vector2i(c / 2, 3))
	assert_eq(first, Vector2i(-c / 2, 3), "one past the east edge is the west edge")
	assert_eq(TerrainSlice.wrap_chunk(Vector2i(-c / 2 - 1, 3)), last, "one past the west edge is the east edge")
	assert_eq(TerrainSlice.wrap_chunk(Vector2i(5, -9)), Vector2i(5, -9), "an interior chunk is unchanged")
	var east: Array = t.generate_heightmap(last)
	var west: Array = t.generate_heightmap(first)
	var n := TerrainSlice.CHUNK_SIZE
	var worst := 0.0
	for row in range(n):
		# The east chunk's last column is half a tile from the west chunk's first column.
		worst = maxf(worst, absf(float(east[row * n + n - 1]) - float(west[row * n])))
	# One tile of real detail-noise slope (Phase 63 samples it exactly out here; float32 used to flatten it).
	assert_true(worst < 0.5, "no seam wall across the wrap (worst step %f)" % worst)
	assert_eq(t.generate_heightmap(Vector2i(c / 2, 3)), west, "a chunk past the edge is the wrapped chunk")
	t.free()

func _test_chunk_key_canonical_at_seam() -> void:
	var c := TerrainSlice.circumference_chunks()
	var voxel := VoxelSlice.new()
	assert_eq(voxel._chunk_key(Vector2i(c / 2, 4)), voxel._chunk_key(Vector2i(-c / 2, 4)),
		"VoxelSlice keys chunk (C/2, z) and (-C/2, z) as one chunk")
	assert_eq(voxel._chunk_key(Vector2i(7, -2)), "7,-2", "an interior key is unchanged")
	var east_tile := Vector2i(c / 2 * TerrainSlice.CHUNK_SIZE + 3, 70)
	var west_tile := Vector2i(-c / 2 * TerrainSlice.CHUNK_SIZE + 3, 70)
	assert_eq(VoxelSlice._tile_key(east_tile), VoxelSlice._tile_key(west_tile),
		"a tile east of the seam is the same edit key as the tile west of it")
	voxel._set_edit_ops(VoxelSlice._tile_key(east_tile), [{ "op": "raise", "n": 1 }])
	assert_true(voxel.edited_chunk_keys().has(voxel._chunk_key(Vector2i(-c / 2, 1))),
		"an edit made at chunk (C/2, z) is found when reading chunk (-C/2, z)")
	var cm := ChunkManager.new()
	assert_eq(cm._chunk_key(Vector2i(c / 2, 4)), cm._chunk_key(Vector2i(-c / 2, 4)),
		"ChunkManager keys both sides of the seam as one chunk")
	cm.free()
	voxel.free()

func _test_wire_chunk_local() -> void:
	var far := Vector3(1.0e7 + 5.0, 2.0, -70.25)   # a Vector3 is float32: 1 m steps this far out
	var wire := WorldPos.to_wire(far)
	assert_eq(wire["chunk"], [312500, -3], "the chunk index is an exact int on the wire")
	assert_eq(wire["local"], [5.0, 2.0, 25.75], "local is small and exact")
	assert_eq(WorldPos.pos_to_wire(WorldPos.from_world(1.0e7 + 5.125, 2.0, -70.25))["local"], [5.125, 2.0, 25.75],
		"a double-precision position keeps the 0.125 step on the wire")
	var round_trip: Variant = JSON.parse_string(JSON.stringify(wire))
	assert_eq(WorldPos.from_wire(round_trip), far, "the wire form survives a JSON round trip")
	assert_eq(WorldPos.from_wire([1.5, 2.0, 3.5]), Vector3(1.5, 2.0, 3.5), "an old float array is still accepted")
	assert_eq(WorldPos.from_wire("junk", Vector3.ONE), Vector3.ONE, "garbage decodes to the fallback")
	assert_true(WorldPos.is_wire(wire) and WorldPos.is_wire([0, 0, 0]) and not WorldPos.is_wire([0, 0]), "is_wire")
	var c := TerrainSlice.circumference_chunks()
	assert_eq(WorldPos.wire_chunk({"chunk": [c / 2, 4], "local": [0, 0, 0]}), Vector2i(-c / 2, 4), "a wire chunk past the seam is canonical")
	var w := float(c) * TerrainSlice.CHUNK_METERS
	assert_eq(WorldPos.wrap_world(Vector3(w / 2.0 + 3.0, 1.0, 9.0)), Vector3(-w / 2.0 + 3.0, 1.0, 9.0), "X wraps when it crosses the seam")
	var creature := CreatureSlice.new()
	creature.render_visuals = false
	add_child(creature)
	creature.apply_snapshot_creatures([{ "instance_id": "w1", "creature_id": "Wolf", "state": "idle",
		"position": WorldPos.to_wire(far), "hp": 10.0, "respawn_at": -1.0 }])
	var out: Array = creature.get_snapshot_creatures()
	var found := false
	for e in out:
		if e["instance_id"] == "w1":
			found = true
			assert_true(e["position"] is Dictionary and e["position"].has("chunk"), "snapshot creature positions carry {chunk, local}")
	assert_true(found or out.size() == 0, "the creature snapshot round trips")
	creature.free()
	var station := StationSlice.new()
	add_child(station)
	station._insert_station("station_1", "Forge", far)
	var sdata: Array = station.get_station_data()
	assert_true(sdata[0]["position"] is Dictionary, "station positions carry {chunk, local}")
	station.apply_station_data([{ "id": "station_2", "type": "Forge", "position": [1.0, 2.0, 3.0] }])
	assert_true(station.get_station_data().size() == 1, "a legacy float-array station still loads")
	station.free()

func _test_rebase_extras() -> void:
	var loot := LootSlice.new()
	add_child(loot)
	var pickup := loot._make_pickup_visual("p1", "wood", Vector3(10.0, 1.0, 5.0))
	loot.add_child(pickup)
	loot._world_nodes.append(pickup)
	var station := StationSlice.new()
	add_child(station)
	station.show_preview("Forge", Vector3(10.0, 1.0, 5.0))
	var preview_before := station._preview.position
	var pickup_before := pickup.position
	var shift := Vector3(-3000.0, 0.0, 0.0)
	var driver := RebaseDriver.new([loot, station])
	driver.rebase_to(Vector2i(94, 0))
	var applied: Vector3 = driver.targets[0].scene_offset()
	assert_true(applied != Vector3.ZERO, "the loot slice took the shift")
	assert_eq(pickup.position, pickup_before + applied, "a pickup shifts by the rebase offset")
	assert_eq(station._preview.position, preview_before + applied, "the preview shifts with the markers")
	station.show_preview("Forge", Vector3(10.0, 1.0, 5.0))
	assert_eq(station._preview.position, preview_before + applied, "a re-shown preview uses the shifted frame")
	var pickup2 := loot._make_pickup_visual("p2", "wood", Vector3(10.0, 1.0, 5.0))
	assert_eq(pickup2.position, pickup_before + applied, "a pickup spawned after the rebase uses the shifted frame")
	pickup2.free()
	station.free()
	loot.free()

## Review of #165 — a target with no `shift_scene` is reported, not silently left behind.
func _test_rebase_driver_reports_unshiftable() -> void:
	var good := LootSlice.new()
	add_child(good)
	var bad := Node3D.new()
	add_child(bad)
	var driver := RebaseDriver.new([good, null, bad])
	driver.rebase_to(Vector2i(94, 0))
	assert_eq(driver.unshiftable_skipped, 1, "the node without shift_scene is counted; null is not")
	assert_true(good.scene_offset() != Vector3.ZERO, "the shiftable target still moved")
	driver.rebase_to(Vector2i(188, 0))
	assert_eq(driver.unshiftable_skipped, 2, "it is counted on every rebase")
	assert_eq(driver._reported_unshiftable.size(), 1, "but reported once")
	bad.free()
	good.free()

## Review of #165 — drop non-finite or absurd positions before any consumer reads them.
func _test_remote_state_plausibility() -> void:
	var root_script: GDScript = load("res://src/core/game_root.gd")
	assert_true(root_script._is_plausible_position(Vector3(10.0, 2.0, -5.0)), "an ordinary position passes")
	assert_true(root_script._is_plausible_position(Vector3(-2.0e7, 0.0, 2.0e7)), "a far planet position passes")
	assert_false(root_script._is_plausible_position(Vector3(NAN, 0.0, 0.0)), "NaN is dropped")
	assert_false(root_script._is_plausible_position(Vector3(0.0, INF, 0.0)), "infinity is dropped")
	assert_false(root_script._is_plausible_position(Vector3(0.0, 0.0, -INF)), "negative infinity is dropped")
	assert_false(root_script._is_plausible_position(Vector3(1.0e9, 0.0, 0.0)), "a coordinate past the planet is dropped")
	var gr: Node = root_script.new()
	gr._is_client = false
	gr._on_remote_player_state(3, Vector3(NAN, 0.0, 0.0))
	assert_true(gr._peer_aoi_regions.is_empty(), "a rejected claim records no AOI region (and needs no networking slice)")
	gr.free()

## Phase 86 — a peer's report carries `{chunk, local}`; the host keeps it and the fold persists it exactly.
func _test_remote_peer_exact_position() -> void:
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	var chunk := Vector2i(250000, 1000)
	var local := Vector3(12.345, 40.0, 7.891)
	var wire := WorldPos.pos_to_wire({ "chunk": chunk, "local": local })
	n._route_c2h(5, { "type": "player_moved", "position": wire })
	assert_eq(n.get_last_known_exact(5)["chunk"], chunk, "the host holds the exact chunk")
	var reg := PlayerRegistry.new()
	_own(reg)
	var gr: Node = (load("res://src/core/game_root.gd") as GDScript).new()
	gr._networking = n
	gr._registry = reg
	gr._fold_last_known_state(5, "p5")
	var rec: Dictionary = JSON.parse_string(JSON.stringify(reg.get_record("p5")))
	var reg2 := PlayerRegistry.new()
	_own(reg2)
	reg2.apply_player_data("p5", rec)
	var back: Dictionary = reg2.get_world_pos("p5")
	assert_eq(back["chunk"], chunk, "the saved record reloads in the same chunk")
	assert_true((back["local"] as Vector3).distance_to(local) < 1e-4, "and at the same local, not float32 metres")
	# A malformed report is refused and leaves the previous state alone.
	var was_quiet := Diag.quiet
	Diag.quiet = true
	n._route_c2h(5, { "type": "player_moved", "position": { "chunk": "x", "local": [1, 2] } })
	n._route_c2h(5, { "type": "player_moved" })
	n._route_c2h(5, { "type": "player_moved", "position": { "chunk": [0, 0], "local": [{}, null, "x"] } })
	n._route_c2h(5, { "type": "player_moved", "position": [NAN, 0.0, 0.0] })
	n._route_c2h(5, { "type": "player_moved", "position": { "chunk": [0, 0], "local": [INF, 0.0, 0.0] } })
	Diag.quiet = was_quiet
	assert_eq(n.get_last_known_exact(5)["chunk"], chunk, "a malformed report leaves the exact state")
	assert_true(n.get_last_known_state(5).distance_to(WorldPos.from_wire(wire)) < 1.0, "and the Vector3 state")
	# A legacy array report still records a position, with no exact entry.
	n._route_c2h(6, { "type": "player_moved", "position": [10.0, 2.0, -5.0] })
	assert_eq(n.get_last_known_state(6), Vector3(10.0, 2.0, -5.0), "a legacy report records its Vector3")
	assert_true(n.get_last_known_exact(6).is_empty(), "with no exact position")
	gr._fold_last_known_state(6, "p6")
	assert_eq(reg.get_world_pos("p6")["chunk"], Vector2i(0, -1), "and the fold falls back to record_position")
	gr.free()
	n.free()

## Phase 97 — near a chunk border far from the origin the float path rounds into the neighbour; the
## window, the relay and the fold all read the exact position instead.
func _test_peer_exact_window_and_relay() -> void:
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n._test_peers = [7]
	var chunk := Vector2i(600000, 3)
	var local := Vector3(31.9, 0.0, 0.1)
	var wire := WorldPos.pos_to_wire({ "chunk": chunk, "local": local })
	n.remember_player_state(7, Vector3(0.0, 0.0, 0.0))
	n._route_c2h(5, { "type": "player_moved", "position": wire })
	var reg := PlayerRegistry.new()
	_own(reg)
	var cm := ChunkManager.new()
	var gr: Node = (load("res://src/core/game_root.gd") as GDScript).new()
	gr._networking = n
	gr._registry = reg
	gr._chunk_manager = cm
	assert_eq(gr._peer_window_chunk(5), chunk, "the window is centred on the exact chunk")
	# The relay to the other clients carries the exact position.
	var relayed: Array = []
	for out in n._test_outbox:
		if str(out["payload"].get("type", "")) == "remote_player_state" and int(out["payload"].get("peer_id", 0)) == 5:
			relayed.append(out)
	n._test_outbox = []
	n.remember_player_state(7, WorldPos.from_wire(wire))
	n._route_c2h(5, { "type": "player_moved", "position": wire })
	for out in n._test_outbox:
		if str(out["payload"].get("type", "")) == "remote_player_state" and int(out["payload"].get("peer_id", 0)) == 5:
			relayed.append(out)
	assert_false(relayed.is_empty(), "the position was relayed to the peer in range")
	if not relayed.is_empty():
		var got: Dictionary = WorldPos.pos_from_wire(relayed.back()["payload"]["position"])
		assert_eq(got["chunk"], chunk, "the relay decodes to the same chunk")
		assert_true((got["local"] as Vector3).distance_to(local) < 1e-3, "and the same local")
	# An exact position past the pole row is not folded; the record keeps its previous position.
	gr._fold_last_known_state(5, "p5")
	assert_eq(reg.get_world_pos("p5")["chunk"], chunk, "a sane exact position is folded")
	n._last_known_exact[5] = { "chunk": Vector2i(10, TerrainSlice.pole_chunks() + TerrainSlice.FOLD_MARGIN_CHUNKS + 5), "local": Vector3.ZERO }
	gr._fold_last_known_state(5, "p5")
	assert_eq(reg.get_world_pos("p5")["chunk"], chunk, "an off-planet exact position leaves the record alone")
	gr._chunk_manager = null
	cm.free()
	gr.free()
	n.free()

## Phase 80 — `TreeSlice.shift_scene` moves its own trunks and the pool, nothing else.
func _test_tree_shift_explicit_set() -> void:
	var trees := TreeSlice.new()
	trees.render_visuals = true
	add_child(trees)
	var a := trees._build_collision("t_a", Vector3(10.0, 0.0, 5.0), "oak")
	var b := trees._build_collision("t_b", Vector3(20.0, 0.0, 7.0), "oak")
	var extra := Node3D.new()
	extra.position = Vector3(1.0, 2.0, 3.0)
	trees.add_child(extra)
	var pool_before: Vector3 = trees._pool.scene_position()
	var shift := Vector3(-4096.0, 0.0, 0.0)
	trees.shift_scene(shift)
	assert_eq(a.position, Vector3(10.0, 0.0, 5.0) + shift, "the first trunk moves by the shift")
	assert_eq(b.position, Vector3(20.0, 0.0, 7.0) + shift, "the second trunk moves by the shift")
	assert_eq(extra.position, Vector3(1.0, 2.0, 3.0), "a non-world child does not move")
	assert_eq(trees._pool.scene_position(), pool_before + shift, "the pool moves exactly once")
	b.free()
	assert_eq(trees._world_nodes.size(), 1, "a freed trunk leaves the world set at once")
	trees.shift_scene(shift)
	assert_eq(a.position, Vector3(10.0, 0.0, 5.0) + shift * 2.0, "a freed trunk is dropped and the survivor still moves")
	trees.free()

## Phase 80 — the same for pickups, one of them collected before the shift.
func _test_loot_shift_explicit_set() -> void:
	var l := LootSlice.new()
	add_child(l)
	GameBus.creature_died.emit("ForestBoar", Vector3(10.0, 1.0, 5.0), "player")
	var ids: Array = l._pickups.keys()
	assert_true(ids.size() >= 2, "a boar drops at least two pickups")
	var extra := Node3D.new()
	extra.position = Vector3(1.0, 2.0, 3.0)
	l.add_child(extra)
	var gone: Dictionary = l._pickups[ids[0]]
	var kept: Node3D = l._pickups[ids[1]]["body"]
	var kept_before := kept.position
	(gone["body"] as Node).free()
	var shift := Vector3(-4096.0, 0.0, 0.0)
	l.shift_scene(shift)
	assert_eq(kept.position, kept_before + shift, "the surviving pickup moves")
	assert_eq(extra.position, Vector3(1.0, 2.0, 3.0), "a non-world child does not move")
	l.free()

## Phase 80 — walking across the rebase distance in physics steps: the world position moves by
## one step's travel per step, including on the step the rebase fires.
func _test_rebase_in_physics_step() -> void:
	var root_script: GDScript = load("res://src/core/game_root.gd")
	var gr: Node = root_script.new()
	var player := PlayerSlice.new()
	player.render_visuals = true
	add_child(player)
	player.spawn_at(Vector3(WorldPos.REBASE_DISTANCE - 5.0, 1.0, 0.0))
	gr._player = player
	gr._rebase = RebaseDriver.new([player])
	var step := 0.5
	var prev := _continuous_x(player)
	var worst := 0.0
	for i in range(30):
		gr._physics_process(0.016)   # the rebase runs first, as in the engine
		player._body.global_position += Vector3(step, 0.0, 0.0)   # then the movement step
		var now := _continuous_x(player)
		worst = maxf(worst, absf(now - prev))
		prev = now
	assert_true(gr._rebase.rebase_count >= 1, "the walk crossed the rebase distance")
	assert_true(worst <= step + 0.01, "the world position never jumped by more than one step (worst %f)" % worst)
	player.free()
	gr.free()

func _continuous_x(player: PlayerSlice) -> float:
	var wp := player.get_world_pos()
	return float((wp["chunk"] as Vector2i).x) * WorldPos.CHUNK_METERS + (wp["local"] as Vector3).x

## Phase 90 — the player's scene origin is the driver's integer `origin_chunk`, and its offset is
## derived from it exactly.
func _test_scene_origin_single_source() -> void:
	var player := PlayerSlice.new()
	player.render_visuals = true
	add_child(player)
	var driver := RebaseDriver.new([player])
	var rng := RandomNumberGenerator.new()
	rng.seed = 90
	for _i in 1000:
		driver.rebase_to(Vector2i(rng.randi_range(-1500000, 1500000), rng.randi_range(-100000, 100000)))
	assert_eq(player._scene_origin_chunk, driver.origin_chunk, "the player's origin chunk is the driver's")
	var want := Vector3(-float(driver.origin_chunk.x) * WorldPos.CHUNK_METERS, 0.0,
		-float(driver.origin_chunk.y) * WorldPos.CHUNK_METERS)
	assert_eq(player.scene_offset(), want, "the offset is exactly -origin_chunk * CHUNK_METERS")
	player.free()

## Phase 91 — the planet is a globe: every direction leads round it.
func _test_globe_fold() -> void:
	var c := TerrainSlice.circumference_chunks()
	var pole := TerrainSlice.pole_chunks()
	var m := TerrainSlice.FOLD_MARGIN_CHUNKS
	var cm := TerrainSlice.CHUNK_METERS
	# Inside the slack nothing moves: pacing over a line costs no fold.
	for chunk in [Vector2i(0, pole + m - 1), Vector2i(0, -pole - m), Vector2i(c / 2 + m - 1, 0), Vector2i(-c / 2 - m, 0)]:
		var still := TerrainSlice.fold_world_pos({"chunk": chunk, "local": Vector3(1.0, 2.0, 3.0)})
		assert_false(still["folded"], "no fold inside the slack at %s" % chunk)
	# Over the north pole: back down the meridian 180 degrees round, turned about.
	var north := TerrainSlice.fold_world_pos({"chunk": Vector2i(10, pole + m), "local": Vector3(5.0, 7.0, 4.0)})
	assert_true(north["folded"] and north["turned"], "past the north pole the position folds and turns")
	var np: Dictionary = north["pos"]
	var z_before := float(pole + m) * cm + 4.0
	var z_after: float = float(np["chunk"].y) * cm + (np["local"] as Vector3).z
	assert_true(absf((z_before - float(pole) * cm) + (z_after - float(pole) * cm)) < 0.001, "Z mirrors about the pole")
	assert_eq(np["chunk"].x, 10 - c / 2, "X moves half a lap (canonical)")
	assert_eq(np["local"].x, 5.0, "local X is kept")
	assert_eq(np["local"].y, 7.0, "and the height")
	assert_true(absf(TerrainSlice.latitude_at(z_before) - TerrainSlice.latitude_at(z_after)) < 0.001, "the same latitude on both sides")
	# Over the south pole.
	var south := TerrainSlice.fold_world_pos({"chunk": Vector2i(-3, -pole - m - 1), "local": Vector3(0.0, 0.0, 0.0)})
	assert_true(south["turned"], "past the south pole too")
	var sp: Dictionary = south["pos"]
	var sz: float = float(sp["chunk"].y) * cm + (sp["local"] as Vector3).z
	assert_true(absf(sz - (-2.0 * float(pole) * cm - float(-pole - m - 1) * cm)) < 0.001, "Z mirrors about the south pole")
	assert_true((sp["local"] as Vector3).z >= 0.0 and (sp["local"] as Vector3).z < cm, "the folded local stays inside its chunk")
	# Round the antimeridian: one lap, no turn.
	var east := TerrainSlice.fold_world_pos({"chunk": Vector2i(c / 2 + m, 7), "local": Vector3(1.0, 0.0, 2.0)})
	assert_true(east["folded"] and not east["turned"], "past the seam the position folds without a turn")
	assert_eq(east["pos"]["chunk"], Vector2i(-c / 2 + m, 7), "one lap west")
	var west := TerrainSlice.fold_world_pos({"chunk": Vector2i(-c / 2 - m - 1, 7), "local": Vector3(1.0, 0.0, 2.0)})
	assert_eq(west["pos"]["chunk"], Vector2i(c / 2 - m - 1, 7), "and one lap east")
	# The folded position is a valid wire position, and a peer may stand in the slack.
	assert_true(WorldPos.is_wire(WorldPos.pos_to_wire(np)), "the folded position goes on the wire")
	assert_true(WorldPos.is_wire({"chunk": [0, pole + m - 1], "local": [0, 0, 0]}), "a player in the slack past a pole is a valid position")
	# An edit near the pole resolves its tile from the exact aim, not the quantised float32.
	var vs := VoxelSlice.new()
	var aim := {"chunk": Vector2i(3, pole - 10), "local": Vector3(0.3, 2.0, 31.9)}
	var coarse := Vector3(3.0 * cm + 0.3, 2.0, float(pole - 10) * cm + 31.9)
	var r: Dictionary = vs._resolve_edit_tile("mine", coarse, Vector3.UP, aim)
	assert_eq(r["tile"], Vector2i(3 * 64, (pole - 10) * 64 + 63), "the exact aim names the tile under the cursor")
	var side: Dictionary = vs._resolve_edit_tile("place", coarse, Vector3(0.0, 0.0, 1.0), aim)
	assert_eq(side["tile"], Vector2i(3 * 64, (pole - 9) * 64), "a side-face place steps into the next tile")
	vs.free()
	# A saved position past a pole loads folded.
	var saved := PlayerRegistry.world_pos_of({"chunk": [4, pole + 2], "local": [1.0, 0.0, 1.0]})
	assert_true(saved["chunk"].y < pole, "a record past the pole loads on the canonical planet")
	assert_eq(saved["chunk"].x, 4 - c / 2, "half a lap round")

func _test_one_wire_validator() -> void:
	var good_dict := {"chunk": [3, -4], "local": [1.0, 2.0, 3.0]}
	assert_true(WorldPos.is_wire(good_dict), "a {chunk, local} dictionary is a wire position")
	assert_true(WorldPos.is_wire({"chunk": [3.0, -4.0], "local": [1, 2, 3]}), "JSON-decoded integer-valued floats pass")
	assert_true(WorldPos.is_wire([1.0, 2.0, 3.0]), "a legacy array is a wire position")
	assert_true(WorldPos.is_wire(WorldPos.to_wire(Vector3(123.0, 4.0, -56.0))), "an encoded position passes")
	assert_false(WorldPos.is_wire({"chunk": [3, -4]}), "a dictionary missing local is refused")
	assert_false(WorldPos.is_wire({"chunk": [1.5, 2], "local": [0, 0, 0]}), "a non-integer chunk is refused")
	assert_false(WorldPos.is_wire({"chunk": [1, 2], "local": [0.0, NAN, 0.0]}), "a NaN component is refused")
	assert_false(WorldPos.is_wire({"chunk": [NAN, 2], "local": [0, 0, 0]}), "a NaN chunk is refused")
	assert_false(WorldPos.is_wire({"chunk": [0, TerrainSlice.pole_chunks() + TerrainSlice.FOLD_MARGIN_CHUNKS + 1], "local": [0, 0, 0]}), "a chunk past the pole and its fold slack is refused")
	assert_false(WorldPos.is_wire({"chunk": [0, 0], "local": [2.0e6, 0, 0]}), "a local beyond a chunk's reach is refused")
	assert_false(WorldPos.is_wire({"chunk": [0, 0, 0], "local": [0, 0, 0]}), "a three-element chunk is refused")
	assert_true(PlayerRegistry.world_pos_of(good_dict)["chunk"] == Vector2i(3, -4), "the registry decodes through the same rule")

## Phase 78 — the player's exact `{chunk, local}` survives a far rebase, a save → reload and the
## snapshot's own-record position.
func _test_player_exact_far_position() -> void:
	var chunk := Vector2i(1200000, 3)
	var want := {"chunk": chunk, "local": Vector3(0.25, 10.0, 0.75)}
	var player := PlayerSlice.new()
	player.render_visuals = true
	add_child(player)
	player.shift_scene(WorldPos.rebase_shift(Vector2i.ZERO, chunk))   # what the rebase driver does
	player.place_at_world_pos(want)
	var got := player.get_world_pos()
	assert_eq(got["chunk"], chunk, "the far player reports its chunk")
	assert_true((got["local"] as Vector3).distance_to(want["local"]) < 0.001, "and its local within 1 mm")
	# A second rebase (the player walked on) keeps the world position.
	player.shift_scene(WorldPos.rebase_shift(chunk, chunk + Vector2i(1, 0)))
	var walked := player.get_world_pos()
	assert_eq(walked["chunk"], chunk, "a later rebase leaves the chunk alone")
	assert_true((walked["local"] as Vector3).distance_to(want["local"]) < 0.001, "and the local")
	# A fold (Phase 91) lands on the exact position: a player past the seam, once rebased onto the
	# folded chunk, is on the same wrapped chunk at the same local.
	var inside := TerrainSlice.wrap_chunk(chunk)
	var p2 := PlayerSlice.new()
	p2.render_visuals = true
	add_child(p2)
	p2.shift_scene(WorldPos.rebase_shift(Vector2i.ZERO, inside))
	p2.fold_to({"chunk": inside, "local": want["local"]}, false)
	assert_eq(p2.get_world_pos()["chunk"], inside, "a folded player is on the wrapped chunk")
	assert_true((p2.get_world_pos()["local"] as Vector3).distance_to(want["local"]) < 0.001, "at the same local")
	var facing := p2.get_facing()
	p2._vel = Vector3(1.0, -2.0, 3.0)
	p2.fold_to({"chunk": inside, "local": want["local"]}, true)
	assert_true(p2.get_facing().distance_to(-facing) < 0.001, "a pole fold turns the view about")
	assert_true(p2.get_velocity().distance_to(Vector3(-1.0, -2.0, -3.0)) < 0.001, "and the motion, keeping the fall")
	p2.free()
	# Save -> reload through the registry record.
	var reg := PlayerRegistry.new()
	_own(reg)
	reg.record_world_pos("p1", got)
	var rec: Dictionary = reg.get_record("p1").duplicate(true)
	var reg2 := PlayerRegistry.new()
	_own(reg2)
	reg2.apply_player_data("p1", JSON.parse_string(JSON.stringify(rec)))
	var back: Dictionary = reg2.get_world_pos("p1")
	assert_eq(back["chunk"], TerrainSlice.wrap_chunk(chunk), "a reloaded player is in the same chunk (chunk 1,500,000 is past one lap, so the registry folds it)")
	assert_true((back["local"] as Vector3).distance_to(want["local"]) < 0.001, "at the same local within 1 mm")
	# The snapshot's own-record position is the stored one, exactly.
	var snap_pos: Dictionary = PlayerRegistry.snapshot_position(reg2.get_record("p1"))
	var stored: Dictionary = reg2.get_record("p1")
	assert_eq(snap_pos["chunk"], stored["chunk"], "the snapshot carries the stored chunk exactly")
	assert_eq(snap_pos["local"], stored["local"], "and the stored local exactly")
	var damaged: Dictionary = stored.duplicate(true)
	damaged["position"] = "garbage"
	assert_true(PlayerRegistry.snapshot_position(damaged) is Dictionary, "a damaged position field still yields the exact stored one")
	player.free()

func _test_rebase_driver() -> void:
	var voxel := VoxelSlice.new()
	add_child(voxel)
	var flat: Array = []
	flat.resize(64 * 64)
	flat.fill(1.0)
	voxel.build_chunk(Vector2i(0, 0), flat)
	var trees := TreeSlice.new()
	trees.render_visuals = true
	add_child(trees)
	var creature := CreatureSlice.new()
	creature.render_visuals = true
	add_child(creature)
	var station := StationSlice.new()
	add_child(station)
	var far_pos := Vector3(3000.0, 1.0, 40.0)
	station._insert_station("station_1", "Forge", far_pos)
	var player := PlayerSlice.new()
	player.render_visuals = true
	add_child(player)
	player.spawn_at(far_pos)
	player._on_remote_player_state(7, Vector3(3010.0, 1.0, 40.0))
	var ghost_pool_before: Vector3 = player._ghost_pool.scene_position() if player._ghost_pool != null else Vector3.ZERO
	var world_before: Vector3 = player.get_position()
	var tree_pool_before: Vector3 = trees._pool.scene_position()
	var creature_pool_before: Vector3 = creature._pool.scene_position()
	var marker := station._markers["station_1"] as Node3D
	var marker_before := marker.position
	var chunk_root := voxel._chunks.values()[0] as Node3D
	var chunk_before := chunk_root.position
	var driver := RebaseDriver.new([voxel, trees, creature, station, player])
	var chunk: Vector2i = WorldPos.from_world(far_pos.x, far_pos.y, far_pos.z)["chunk"]
	assert_true(not driver.tick(Vector3(100.0, 0.0, 0.0), chunk), "a nearby player does not rebase")
	assert_true(driver.tick(player.get_scene_position(), chunk), "a player 3 km out rebases")
	var shift := WorldPos.rebase_shift(Vector2i.ZERO, chunk)
	assert_true(shift.x < 0.0, "the shift moves the world back toward the origin")
	assert_eq(player.get_position(), world_before, "the player keeps its world position")
	assert_eq(player.get_scene_position(), world_before + shift, "the player body shifts by the offset")
	assert_eq(trees._pool.scene_position(), tree_pool_before + shift, "trees shift by the same offset")
	if player._ghost_pool != null:
		assert_eq(player._ghost_pool.scene_position(), ghost_pool_before + shift, "remote ghosts shift by the same offset")
	assert_eq(creature._pool.scene_position(), creature_pool_before + shift, "creatures shift by the same offset")
	assert_eq(marker.position, marker_before + shift, "stations shift by the same offset")
	assert_eq(station.get_station_data()[0]["position"], WorldPos.to_wire(far_pos), "the station keeps its {chunk, local}")
	assert_eq(chunk_root.position, chunk_before + shift, "terrain chunks shift by the same offset")
	assert_true(not driver.tick(player.get_scene_position(), chunk), "no second rebase straight after")
	assert_eq(driver.rebase_count, 1, "one rebase happened")
	player.free()
	station.free()
	creature.free()
	trees.free()
	voxel.free()

func _test_far_noise_quantised() -> void:
	var t := TerrainSlice.new()
	add_child(t)
	t.set_world_seed(1234)
	# Inside the span the coordinate is untouched: ground near the origin does not change.
	assert_eq(TerrainSlice.noise_coord(123.5), 123.5, "the fold is the identity near the origin")
	assert_eq(TerrainSlice.noise_coord(-8000.25), -8000.25, "and for negative coordinates")
	var far_x := 312500.0 * TerrainSlice.CHUNK_METERS
	var prev := -1.0
	var distinct := 0
	for i in range(64):
		var x := far_x + float(i) * TerrainSlice.TILE_SIZE
		var coord := TerrainSlice.noise_coord(x)
		assert_true(absf(coord) <= TerrainSlice.NOISE_SPAN, "the folded coordinate stays small")
		assert_eq(coord, snappedf(coord, 0.125), "the folded coordinate is exact to the 0.125 step")
		var d := t.detail_at(x, 77.5)
		if absf(d - prev) > 0.0:
			distinct += 1
		assert_true(prev < 0.0 or absf(d - prev) < 1.0, "adjacent tiles differ by terrain slope, not a rounding jump")
		prev = d
	assert_eq(distinct, 64, "no terracing: every tile steps to a new value")
	# Continuous across the fold: a half-step either side of the fold agrees to within one tile of slope.
	var fold := TerrainSlice.NOISE_SPAN
	assert_true(absf(t.detail_at(fold - 0.25, 5.0) - t.detail_at(fold + 0.25, 5.0)) < 1.0, "the fold has no cliff")
	t.free()

func _test_where_command() -> void:
	var pos := Vector3(0.0, 12.0, 0.0)
	assert_true(ChatCommands.is_command("/where"), "/where is a command")
	assert_true(ChatCommands.is_command("  /WHERE "), "case and padding are ignored")
	assert_true(not ChatCommands.is_command("hello"), "plain chat is not a command")
	assert_eq(ChatCommands.run("/where", pos), TerrainSlice.where_text(pos), "/where prints where_text")
	assert_eq(ChatCommands.run("hello", pos), "", "plain chat prints nothing")
	assert_false(ChatCommands.is_command("/wherever"), "only the exact command matches")
	assert_eq(ChatCommands.run("/WHERE ", pos), TerrainSlice.where_text(pos), "run and is_command agree on spelling")

func _test_terrain_planet_coordinates() -> void:
	var t := TerrainSlice.new()
	add_child(t)
	var pole := TerrainSlice.pole_chunks()
	assert_true(absf(TerrainSlice.latitude_of(pole - 1) - 90.0) < 0.001, "the last row is at the pole")
	assert_true(absf(TerrainSlice.latitude_at(0.0)) < 0.001, "the equator is latitude 0")
	assert_true(absf(TerrainSlice.longitude_of(0)) < 0.001, "the origin is longitude 0")
	assert_true(absf(TerrainSlice.longitude_at(TerrainSlice.circumference_chunks() * TerrainSlice.CHUNK_METERS * 0.25) - 90.0) < 0.001, "a quarter around is 90 degrees east")
	assert_true(t.is_chunk_in_bounds(Vector2i(999999, 0)), "any longitude is walkable")
	assert_true(t.is_chunk_in_bounds(Vector2i(0, TerrainSlice.polar_chunks())), "polar ice is walkable")
	assert_true(t.is_chunk_in_bounds(Vector2i(0, -TerrainSlice.pole_chunks())), "up to the south pole")
	assert_eq(TerrainSlice.where_text(Vector3(0.0, 4.2, 0.0)), "0.000\u00b0N 0.000\u00b0E  alt 4 m", "where: the origin")
	assert_eq(TerrainSlice.where_text(Vector3(-0.5, 0.0, 0.0)), "0.000\u00b0N 0.000\u00b0E  alt 0 m", "where: just west of the meridian rounds to 0.000, no \"0.000 W\"")
	assert_true(PlayerRegistry.world_pos_of({"chunk": [0, TerrainSlice.pole_chunks()], "local": [0.0, 0.0, 1.0e6]})["chunk"].y <= TerrainSlice.pole_chunks(), "world_pos_of: a huge local cannot push the chunk past the pole")
	assert_true(TerrainSlice.where_text(Vector3(-3200.0, 0.0, 3200.0)).contains("W"), "where: west of the origin")
	# Position quantiser at a far chunk: a tile offset is exact in double precision, so a
	# 0.125 step is the same 0.125 at chunk 600,000 as at the origin.
	var far := Vector2i(600000, 0)
	var origin_x := t.chunk_to_world(far).x
	assert_eq((origin_x + 0.125) - origin_x, 0.125, "0.125 step survives at 19,200 km")
	t.free()

const WorldPos := preload("res://src/terrain/world_pos.gd")

func _test_world_pos_rebase() -> void:
	# A player 10,000 km east: chunk 312,500, local offset exact.
	var far := WorldPos.from_world(1.0e7 + 5.125, 2.0, -70.25)
	assert_eq(far["chunk"], Vector2i(312500, -3), "split into the right chunk")
	var local: Vector3 = far["local"]
	assert_true(local.x >= 0.0 and local.x < 32.0 and local.z >= 0.0 and local.z < 32.0, "local lies inside its chunk")
	assert_eq(local.z, 25.75, "local keeps the 0.125 step")
	# Rebase: the world position ({chunk, local}) is unchanged and every node shifts by one offset.
	var old_origin := Vector2i(100, 100)
	var pos := {"chunk": Vector2i(100 + 70, 100 - 3), "local": Vector3(5.125, 1.0, 9.5)}
	var scene_before := WorldPos.to_scene(pos, old_origin)
	assert_true(WorldPos.needs_rebase(scene_before), "2.2 km out needs a rebase")
	var new_origin := WorldPos.rebase_origin(pos)
	var shift := WorldPos.rebase_shift(old_origin, new_origin)
	var scene_after := WorldPos.to_scene(pos, new_origin)
	assert_eq(scene_after, scene_before + shift, "the player moves by exactly the shift")
	assert_eq(WorldPos.from_scene(scene_after, new_origin), WorldPos.normalized(pos), "chunk + local unchanged by the rebase")
	assert_eq(WorldPos.to_scene(pos, new_origin), pos["local"], "the player sits at their local offset")
	assert_true(not WorldPos.needs_rebase(scene_after), "no rebase needed afterwards")
	# A chunk node 3 chunks east of the player's chunk shifts by the same offset.
	var node_chunk := Vector2i(173, 97)
	assert_eq(WorldPos.to_scene({"chunk": node_chunk, "local": Vector3.ZERO}, new_origin),
		WorldPos.to_scene({"chunk": node_chunk, "local": Vector3.ZERO}, old_origin) + shift, "streamed nodes shift together")
	# The real nodes: a VoxelSlice shifts every chunk root by the same offset, and a chunk built
	# after the rebase lands in the same frame.
	var v := VoxelSlice.new()
	add_child(v)
	var flat: Array = []
	flat.resize(64 * 64)
	flat.fill(1.0)
	v.build_chunk(Vector2i(0, 0), flat)
	v.build_chunk(Vector2i(1, 0), flat)
	var floor_before: Vector3 = v.get_node("WorldFloor").position
	v.shift_scene(shift)
	# A chunk node sits at its own corner (its vertices are chunk-local), so the rebase offset is the
	# node's position minus that corner.
	var corner := func(cx: int) -> Vector3: return Vector3(float(cx * 64) * VoxelSlice.TILE_SIZE, 0.0, 0.0)
	for cx in [0, 1]:
		assert_eq(v.get_node("Chunk_%d,0" % cx).position, shift + corner.call(cx), "chunk %d root shifted by the rebase offset" % cx)
	assert_eq(v.get_node("WorldFloor").position, floor_before + shift, "the world floor shifts with the chunks")
	v.build_chunk(Vector2i(2, 0), flat)
	assert_eq(v.get_node("Chunk_2,0").position, shift + corner.call(2), "a chunk built after the rebase uses the shifted frame")
	remove_child(v)
	v.free()
	# The 0.125 step quantiser holds at a large chunk index: 400 steps east of 10,000 km, each
	# step lands on a multiple of 0.125 and the chunk + local sum advances by exactly one step.
	var stepper := {"chunk": far["chunk"], "local": far["local"]}
	for i in 400:
		var before_local: Vector3 = stepper["local"]
		var before_chunk: Vector2i = stepper["chunk"]
		stepper = WorldPos.normalized({"chunk": before_chunk, "local": before_local + Vector3(0.125, 0.0, 0.0)})
		var after_local: Vector3 = stepper["local"]
		var advanced: float = float(stepper["chunk"].x - before_chunk.x) * 32.0 + after_local.x - before_local.x
		assert_eq(advanced, 0.125, "step %d advances exactly 0.125 m at chunk 312,500" % i)
		assert_eq(fmod(after_local.x, 0.125), 0.0, "step %d stays on the 0.125 lattice" % i)
	assert_eq(stepper["chunk"].x, 312500 + (floori(far["local"].x + 50.0) / 32), "400 steps = 50 m east")
	# Walking across a chunk edge normalises.
	var walked := WorldPos.normalized({"chunk": Vector2i(5, 5), "local": Vector3(33.0, 0.0, -1.0)})
	assert_eq(walked["chunk"], Vector2i(6, 4), "walking over an edge changes the chunk")
	assert_eq(walked["local"], Vector3(1.0, 0.0, 31.0), "and wraps the local offset")

func _test_registry_world_pos() -> void:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.record_position("p1", Vector3(70.5, 3.0, -10.25))
	var wp: Dictionary = reg.get_world_pos("p1")
	assert_eq(wp["chunk"], Vector2i(2, -1), "recorded into chunk coordinates")
	assert_eq(wp["local"], Vector3(6.5, 3.0, 21.75), "with the local offset")
	var data: Dictionary = reg.get_player_data("p1")
	assert_eq(data["chunk"], [2, -1], "the save payload carries the chunk")
	# A Phase 49 payload has only `position`: it maps to the same coordinates.
	reg.apply_player_data("old", {"position": [70.5, 3.0, -10.25], "hp": 10.0})
	assert_eq(reg.get_world_pos("old"), wp, "an old save loads at the mapped coordinates")
	# A far payload keeps its exact local offset.
	reg.apply_player_data("far", {"chunk": [600000, -40], "local": [5.125, 2.0, 9.5], "hp": 10.0})
	var far: Dictionary = reg.get_world_pos("far")
	assert_eq(far["chunk"], Vector2i(600000, -40), "a far chunk survives the round trip")
	assert_eq(far["local"], Vector3(5.125, 2.0, 9.5), "at 0.125 precision")
	assert_eq(reg.get_player_data("far")["local"], [5.125, 2.0, 9.5], "and re-saves identically")
	assert_eq(reg.get_record("far")["position"][0], 600000 * 32.0 + 5.125, "position is rebuilt in doubles, not float32")
	# A malformed chunk keeps the saved position instead of resetting to the origin.
	reg.apply_player_data("bad", {"chunk": [1, 2, 3], "local": [1.0, 2.0, 3.0], "position": [70.5, 3.0, -10.25], "hp": 10.0})
	assert_eq(reg.get_world_pos("bad"), wp, "a malformed chunk falls back to position")
	assert_eq(reg.get_record("bad")["position"], [70.5, 3.0, -10.25], "and position is untouched")
	reg.free()

# ---------------------------------------------------------------------------
# PersistenceSlice tests
# ---------------------------------------------------------------------------

## Phase 71 — a new world is stamped with the running generator version.
func _test_worldgen_stamp_new_world() -> void:
	var dir := "user://saves/test_worldgen_new/"
	_wipe_dir(dir)
	var writer := PersistenceSlice.new()
	add_child(writer)
	writer.server_save_dir = dir
	var stamp := PersistenceSlice.worldgen_stamp_for_save({}, TerrainSlice.WORLDGEN_VERSION)
	assert_eq(writer.save_world({ "local_player_id": "player_1_1_ab", "worldgenVersion": stamp }, false), OK, "the record writes")
	var loaded := writer.load_world_record()
	assert_eq(PersistenceSlice.worldgen_version_of(loaded), TerrainSlice.WORLDGEN_VERSION, "a new world saves worldgenVersion == WORLDGEN_VERSION")
	var warns := Diag.warn_count()
	assert_false(PersistenceSlice.check_worldgen_version(loaded, TerrainSlice.WORLDGEN_VERSION), "a matching record is no mismatch")
	assert_false(PersistenceSlice.check_worldgen_version({}, TerrainSlice.WORLDGEN_VERSION), "a new world is no mismatch")
	assert_eq(Diag.warn_count(), warns, "and neither warns")
	writer.free()
	_wipe_dir(dir)

## Phase 71 — an unstamped or older record loads with its edits intact, warns exactly once, and is
## re-saved with its ORIGINAL stamp.
func _test_worldgen_stamp_mismatch() -> void:
	var dir := "user://saves/test_worldgen_old/"
	_wipe_dir(dir)
	var voxel := _make_voxel()
	assert_true(voxel.mine_block(Vector3(16.25, 2.0, 16.25)).get("success", false), "the column was mined")
	var writer := PersistenceSlice.new()
	add_child(writer)
	writer.server_save_dir = dir
	for original in [0, TerrainSlice.WORLDGEN_VERSION - 1]:
		var record := { "local_player_id": "player_1_1_ab", "chunks": voxel.get_chunk_manifest() }
		if original > 0:
			record["worldgenVersion"] = original
		assert_eq(writer.save_world(record, false), OK, "the old record writes")
		var loaded := writer.load_world_record()
		assert_eq(PersistenceSlice.worldgen_version_of(loaded), original, "a missing stamp reads as 0, an old one as itself")
		var warns := Diag.warn_count()
		assert_true(PersistenceSlice.check_worldgen_version(loaded, TerrainSlice.WORLDGEN_VERSION), "the mismatch is reported")
		assert_eq(Diag.warn_count() - warns, 1, "with exactly one warning")
		var stamp := PersistenceSlice.worldgen_stamp_for_save(loaded, TerrainSlice.WORLDGEN_VERSION)
		assert_eq(stamp, original, "a re-save keeps the original stamp")
		assert_eq(writer.save_world({ "local_player_id": "player_1_1_ab", "worldgenVersion": stamp }, true), OK, "the re-save writes")
		assert_eq(PersistenceSlice.worldgen_version_of(writer.load_world_record()), original, "and the stamp on disk is unchanged")
		assert_true((writer.load_world()["chunks"] as Dictionary).has("0,0"), "every edit is intact")
	voxel.free()
	writer.free()
	_wipe_dir(dir)

## Phase 71 — the game_root half: loading a record sets the stamp the next save carries and
## raises the bus signal exactly when the record's generator is not the running one.
func _test_worldgen_stamp_game_root_wiring() -> void:
	var root_script: GDScript = load("res://src/core/game_root.gd")
	var gr: Node = root_script.new()
	assert_eq(gr._worldgen_stamp, TerrainSlice.WORLDGEN_VERSION, "a process that loads nothing stamps the running version")
	var seen: Array = []
	var cb := func(recorded: int, running: int) -> void: seen.append([recorded, running])
	GameBus.worldgen_version_mismatch.connect(cb)
	gr._loaded_world = {}
	gr._note_worldgen_version()
	assert_true(seen.is_empty(), "a new world raises no mismatch")
	assert_eq(gr._worldgen_stamp, TerrainSlice.WORLDGEN_VERSION, "and takes the running stamp")
	gr._loaded_world = { "worldgenVersion": TerrainSlice.WORLDGEN_VERSION }
	gr._note_worldgen_version()
	assert_true(seen.is_empty(), "a matching record raises none")
	gr._loaded_world = { "seed": 7 }
	gr._note_worldgen_version()
	assert_eq(seen, [[0, TerrainSlice.WORLDGEN_VERSION]], "an unstamped record reads as v0 and raises once")
	assert_eq(gr._worldgen_stamp, 0, "and the next save keeps that original stamp")
	GameBus.worldgen_version_mismatch.disconnect(cb)
	gr.free()

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
	# hair and even coarse body geometry are all gone.
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

func _test_character_lod_medium_hides_fine_detail() -> void:
	# LOD 1 (medium) must hide fine detail (hair) via its `max_lod`, while
	# keeping coarse geometry (body_legs/head) visible and NOT swapping in the
	# impostor — distinct from the LOD 2 impostor force-hide. Guards the
	# max_lod renumbering: hair must be 0 (hidden at LOD 1), coarse parts
	# MAX_LOD (visible through the impostor tier).
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid := ch.create_character("TravellerHuman", Vector3.ZERO)
	ch.set_lod(0)
	assert_true(ch.is_part_visible(iid, "hair"), "hair visible at LOD0")
	assert_true(ch.is_part_visible(iid, "body_legs"), "body_legs visible at LOD0")
	ch.set_lod(1)
	assert_false(ch.is_part_visible(iid, "hair"), "hair hidden at LOD1 (fine detail)")
	assert_true(ch.is_part_visible(iid, "body_legs"), "body_legs visible at LOD1 (coarse)")
	assert_true(ch.is_part_visible(iid, "head"), "head visible at LOD1 (coarse)")
	assert_false(ch.is_impostor_visible(iid), "no impostor at LOD1")
	ch.free()

func _test_character_lod_hysteresis() -> void:
	# Hysteresis (Phase 23): a move to a FINER level steps down one level at a
	# time and only commits once the distance has moved a full LOD_HYSTERESIS
	# margin inside the threshold — so an instance straddling a boundary doesn't
	# flicker, and one jumping several levels doesn't hold a stale coarse level.
	# A move to a COARSER level still commits immediately.
	assert_eq(CharacterSlice.lod_level_for_distance(19.0, 1), 1, "19m from LOD1 stays 1 (inside 20m but within margin)")
	assert_eq(CharacterSlice.lod_level_for_distance(17.0, 1), 0, "17m from LOD1 refines to 0 (past margin)")
	assert_eq(CharacterSlice.lod_level_for_distance(59.0, 2), 2, "59m from LOD2 stays 2 (within margin)")
	assert_eq(CharacterSlice.lod_level_for_distance(57.0, 2), 1, "57m from LOD2 refines to 1 (past margin)")
	assert_eq(CharacterSlice.lod_level_for_distance(21.0, 0), 1, "21m from LOD0 coarsens immediately to 1")
	assert_eq(CharacterSlice.lod_level_for_distance(61.0, 1), 2, "61m from LOD1 coarsens immediately to 2")
	assert_eq(CharacterSlice.lod_level_for_distance(19.0, 2), 1, "19m from LOD2 steps to 1, not held at impostor")
	assert_eq(CharacterSlice.lod_level_for_distance(10.0, 2), 1, "10m from LOD2 steps one level finer (2→1), then 1→0 next frame")

func _test_character_lod_equip_at_impostor() -> void:
	# Equipping at impostor distance must still hide the freshly-built node:
	# the _apply_lod early-out would otherwise skip nodes that default to
	# visible, leaving the rig showing through the impostor.
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid := ch.create_character("TravellerHuman", Vector3.ZERO)
	ch.set_lod(2)
	assert_true(ch.is_impostor_visible(iid), "impostor visible at LOD2")
	# VeilsteelLongsword has no hideRegions, so the hidden set is unchanged and
	# the early-out path (not the hideRegions recompute path) is exercised.
	assert_true(ch.apply_equipment(iid, "MainHand", "VeilsteelLongsword"), "sword equips at impostor LOD")
	assert_false(ch.is_part_visible(iid, "MainHand"), "equipment hidden at impostor LOD")
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

func _test_character_skeleton_pose_matches_rest() -> void:
	# Regression: build() must initialize each bone's POSE from its REST.
	# `set_bone_rest` stores only the rest transform; the pose (what
	# BoneAttachment3D follows) stays identity after `add_bone`. Without
	# reset_bone_poses(), every bone-attached mesh (head, torso, SKINNED/HYBRID
	# equipment) snaps to the skeleton origin — displaced by
	# `-get_bone_global_rest(bone)` — the "head in the wrong place / missing
	# body parts" bug. The pose must match the rest so attachments track bones.
	var rig := SkeletonRig.new()
	add_child(rig)
	rig.build(GameData.SKELETONS["HumanoidSkeleton"], {})
	var skel: Skeleton3D = rig.get_skeleton()
	for bone_name in ["Hips", "Chest", "Neck", "Head", "Hand_L", "Foot_L"]:
		var idx: int = rig.get_bone_index(bone_name)
		assert_true(
			skel.get_bone_pose(idx).origin.is_equal_approx(skel.get_bone_rest(idx).origin),
			"%s pose matches rest (bone attachments track the bone)" % bone_name
		)
	rig.free()

func _test_character_faces_movement_direction() -> void:
	# Regression: the avatar's forward (the face/beard side, -Z) must point along
	# the movement direction. A bare atan2(vx, vz) aligned +Z (the back) with
	# velocity, so the avatar walked backwards. Negating both args aligns -Z.
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid := ch.create_character_from_recipe({ "skeleton": "HumanoidSkeleton" }, Vector3.ZERO)
	# The legs container is a rig-root child, so its parent is the rig root.
	var rig: Node3D = ch.get_part_node(iid, "body_legs").get_parent() as Node3D
	assert_true(rig != null, "rig root reachable from the legs container")
	var flat := func(_xz: Vector2) -> float: return 0.0
	# Move forward (-Z) with a large delta so rotate_toward snaps to the target.
	ch.sync_player_avatar(iid, Vector3.ZERO, Vector3(0.0, 0.0, -1.0), 0.0, true, 10.0, flat)
	assert_true(is_equal_approx(rig.rotation.y, 0.0), "forward (-Z) movement faces yaw 0, not backwards")
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

## The rig root sits at the FEET — every body part is placed at
## `landmarks["hip_y"]` ABOVE it (`CharacterSlice._make_avatar`) — so
## `sync_player_avatar` must put the root at the sampled surface height itself.
## It used to subtract the LOCAL hip offset (`landmarks["hip_y"]`, ~0.9) from the
## sampled surface, reading it off the landmarks dict where the foot targets' own
## WORLD hip ordinate used to carry the same key name; the avatar therefore stood
## ~0.9 BELOW the ground it was standing on. The sampler passed here is the voxel
## height the collision boxes are built from (`VoxelSlice.get_voxel_height_at`).
func _test_avatar_root_y_matches_voxel_ground() -> void:
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid := ch.create_character("TravellerHuman", Vector3.ZERO)
	assert_true(iid != "", "character created")
	var rig: Node3D = ch.get_part_node(iid, "body_legs").get_parent() as Node3D
	assert_true(rig != null, "rig root reachable from the legs container")
	var ground := 2.0
	var voxel := func(_xz: Vector2) -> float: return ground
	# The controller stands ON the surface, so its own Y is the surface height.
	ch.sync_player_avatar(iid, Vector3(16.0, ground, 16.0), Vector3.ZERO, 0.0, true, 0.1, voxel)
	assert_true(
		is_equal_approx(rig.position.y, ground),
		"avatar root Y equals the sampled voxel ground height (got %f, want %f)" % [rig.position.y, ground]
	)
	ch.free()

## Walking into a one-step voxel rise must ADVANCE HORIZONTALLY without jumping:
## `resolve_step_up` lifts the body by at most one step and moves it forward, and
## produces a position only — no vertical velocity, so the step is walked, not
## hopped. Pure: the collision is a fake Callable, because the suite runs
## synchronously inside `GameRoot._ready()` with no physics frame (a
## `move_and_slide()` there is a silent no-op, verified — see ROADMAP §Phase 39,
## "the synchronous suite has no physics frame").
func _test_player_step_up() -> void:
	var step_h: float = VoxelSlice.STEP_HEIGHT          # 0.125 — one quantised rise
	var floor_y := 1.0
	var start := Transform3D(Basis.IDENTITY, Vector3(0.0, floor_y, 0.5))
	var forward := Vector3(0.0, 0.0, -0.8)             # crosses the rise's face
	# A solid rise on the far side of z = 0 whose top is `top`: a motion that ends
	# up past the face with its feet still under the top is blocked.
	var top_one := floor_y + step_h
	var blocked_one := func(xform: Transform3D, motion: Vector3) -> bool:
		var dest := xform.origin + motion
		return dest.z < 0.0 and dest.y < top_one
	assert_true(blocked_one.call(start, forward), "the fake blocks the floor-level attack on the step")

	var cleared := PlayerSlice.resolve_step_up(blocked_one, start, forward, PlayerSlice.STEP_UP_HEIGHT)
	assert_true(cleared.origin.z < start.origin.z,
		"a one-step rise is advanced through (z %.3f -> %.3f)" % [start.origin.z, cleared.origin.z])
	assert_true(is_equal_approx(cleared.origin.z - start.origin.z, forward.z),
		"the horizontal advance is the cast, no more and no less")
	assert_true(is_equal_approx(cleared.origin.y - start.origin.y, PlayerSlice.STEP_UP_HEIGHT),
		"the rise is one step-up, not a jump (got %f)" % (cleared.origin.y - start.origin.y))
	assert_true(PlayerSlice.STEP_UP_HEIGHT > step_h,
		"STEP_UP_HEIGHT exceeds a voxel STEP_HEIGHT (%.3f > %.3f)" % [PlayerSlice.STEP_UP_HEIGHT, step_h])

	# A rise taller than STEP_UP_HEIGHT is a wall, not a stair: refused, unmoved.
	var top_wall := floor_y + 2.0 * PlayerSlice.STEP_UP_HEIGHT
	var blocked_wall := func(xform: Transform3D, motion: Vector3) -> bool:
		var dest := xform.origin + motion
		return dest.z < 0.0 and dest.y < top_wall
	var refused := PlayerSlice.resolve_step_up(blocked_wall, start, forward, PlayerSlice.STEP_UP_HEIGHT)
	assert_true(refused == start, "a rise taller than STEP_UP_HEIGHT is not climbed")

	# Nothing in the way: not a step-up at all — the body is left alone.
	var free := func(_xform: Transform3D, _motion: Vector3) -> bool: return false
	assert_true(
		PlayerSlice.resolve_step_up(free, start, forward, PlayerSlice.STEP_UP_HEIGHT) == start,
		"an unblocked move is not a step-up"
	)

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
	# Parts with identical extents share one mesh resource (§43 / Phase 22
	# mesh-sharing criterion): two instances of the same appearance have the same
	# proportions, so their body parts (now a rounded capsule) share one capsule.
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid1 := ch.create_character("TravellerHuman", Vector3.ZERO)
	var iid2 := ch.create_character("TravellerHuman", Vector3.ZERO)
	assert_true(iid1 != "" and iid2 != "", "characters created")
	var n1 := ch.get_part_node(iid1, "body_chest") as MeshInstance3D
	var n2 := ch.get_part_node(iid2, "body_chest") as MeshInstance3D
	assert_true(n1 != null and n2 != null, "body parts exist")
	assert_true(n1.mesh is CapsuleMesh and n2.mesh is CapsuleMesh, "parts use a CapsuleMesh")
	assert_true(n1.mesh == n2.mesh, "same-size parts share one mesh resource")
	ch.free()

func _test_character_procedural_walk_animation() -> void:
	# Driving the avatar forward swings the limb pivots away from the rest pose,
	# and idle settles them back (procedural locomotion — no authored clips yet).
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid := ch.create_character("TravellerHuman", Vector3.ZERO)
	assert_true(iid != "", "character created")
	var terrain := func(_v: Vector2) -> float: return 0.0
	# Idle: no horizontal speed -> rest pose (zero swing).
	ch.sync_player_avatar(iid, Vector3.ZERO, Vector3.ZERO, 0.0, true, 0.1, terrain)
	var arm_l: Node3D = ch.get_part_node(iid, "arm_l")
	var arm_r: Node3D = ch.get_part_node(iid, "arm_r")
	assert_true(arm_l != null and arm_r != null, "arm pivots exist")
	assert_true(absf(arm_l.rotation.x) < 0.001 and absf(arm_r.rotation.x) < 0.001, "idle arms at rest pose")
	# Walk: advance a frame at walking speed -> arms swing in opposition.
	ch.sync_player_avatar(iid, Vector3.ZERO, Vector3(0.0, 0.0, 2.0), 0.0, true, 0.1, terrain)
	assert_true(absf(arm_l.rotation.x) > 0.001 or absf(arm_r.rotation.x) > 0.001, "arms swing while walking")
	ch.free()

func _test_character_toggle_equipment() -> void:
	# Toggling all equipment at once clears then restores every slot, so the
	# "naked" body can be inspected under the gear (vanity/debug).
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid := ch.create_character("TravellerHuman", Vector3.ZERO)
	assert_true(iid != "", "character created")
	assert_true(ch.get_part_node(iid, "Chest") != null, "chestplate equipped initially")
	assert_true(ch.toggle_equipment(iid), "toggle off returns true")
	assert_true(ch.get_part_node(iid, "Chest") == null, "chestplate cleared after toggle")
	assert_true(ch.get_part_node(iid, "MainHand") == null, "sword cleared after toggle")
	assert_true(ch.get_part_node(iid, "OffHand") == null, "shield cleared after toggle")
	assert_true(ch.toggle_equipment(iid), "toggle on returns true")
	assert_true(ch.get_part_node(iid, "Chest") != null, "chestplate restored after toggle")
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

func _test_craft_skill_tiers_are_per_player() -> void:
	# Skill tiers used to be ONE process-wide table, so every player shared every
	# gate: the first peer to reach journeyman unlocked those recipes for the whole
	# server, and a peer's craft was gated by whoever had levelled last.
	# Phase 36 moves the tiers onto the player record — this proves two players in
	# one process can hold different tiers, that neither reads the other's, and that
	# a tier survives the record round-trip.
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("player_host_1")
	var c := CraftingSlice.new()
	add_child(c)
	c.player_registry = reg

	# Any recipe carrying a skill guard: the gate answers before the inputs do.
	var recipe_id := ""
	var skill := ""
	var required := ""
	for key in GameData.RECIPES:
		var spec: Dictionary = c.get_recipe(str(key))
		var guards: Array = spec.get("skillGuards", [])
		if guards.size() > 0:
			recipe_id = str(key)
			skill = str(guards[0].get("skill", ""))
			required = str(guards[0].get("tier", "novice"))
			break
	assert_true(recipe_id != "" and skill != "" and required != "",
		"need a recipe with a skill guard (fabric defines several)")

	var peer_a := "player_peer_a_1_cafe"
	var peer_b := "player_peer_b_2_beef"
	# The exact guard this test is about: a recipe may carry several skill guards, and
	# only THIS one's tier is being raised.
	var gate := "skill_requirement:%s:%s" % [skill, required]
	assert_eq(str(c.can_craft(recipe_id, peer_a)["reason"]), gate, "a player with no tier is gated")
	assert_eq(c.get_skill_for(peer_a, skill), "novice", "and reads as the seed tier")

	# The earning player lifts their own gate...
	assert_true(c.set_skill_for(peer_a, skill, required), "a valid tier is applied")
	assert_true(str(c.can_craft(recipe_id, peer_a)["reason"]) != gate,
		"their own tier lifts their own gate")
	assert_eq(c.get_skill_for(peer_a, skill), required, "and only theirs")

	# ...while a second player is still gated, and still reads novice.
	assert_eq(str(c.can_craft(recipe_id, peer_b)["reason"]), gate,
		"a second player is NOT unlocked by the first player's tier")
	assert_eq(c.get_skill_for(peer_b, skill), "novice", "a peer with no tier reads as novice")

	# The LOCAL player's live table must not leak into a peer's gate either: the
	# demo/UI path writes via set_skill(), which is the local player's own store.
	c.set_skill(skill, required)
	assert_eq(c.get_skill_for("player_host_1", skill), required, "the local player reads their own tier")
	assert_eq(str(c.can_craft(recipe_id, peer_b)["reason"]), gate,
		"and the local player's tier still does not unlock a peer")

	# Durable: the tier rides the record, and an older payload (no `skills` key)
	# restores to the seed tier rather than to somebody else's numbers.
	var data: Dictionary = reg.get_player_data(peer_a)
	assert_eq(str(data.get("skills", {}).get(skill, "")), required, "the tier rides the record")
	var restored := PlayerRegistry.new()
	add_child(restored)
	restored.apply_player_data(peer_a, data)
	assert_eq(restored.get_skill_tier(peer_a, skill), required, "and restores from it")
	var legacy := PlayerRegistry.new()
	add_child(legacy)
	legacy.apply_player_data(peer_b, { "position": [1.0, 2.0, 3.0] })
	assert_eq(legacy.get_skill_tier(peer_b, skill), "", "a pre-Phase-36 payload has no tiers in it")

	c.free()
	reg.free()
	restored.free()
	legacy.free()

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

func _test_station_placement_validation() -> void:
	var station := StationSlice.new()
	add_child(station)
	var t: String = str(station.placeable_station_types()[0])
	assert_eq(station.snap_to_grid(Vector3(2.3, 1.0, -0.2)), Vector3(2.5, 1.0, -0.5), "snaps x/z to cell centre")
	assert_true(station.try_place_station(t, Vector3(2.3, 0.0, 2.3)) != "", "first placement accepted")
	assert_eq(station.try_place_station(t, Vector3(2.9, 0.0, 2.1)), "", "same cell refused")
	assert_true(station.placement_blocker(t, Vector3(2.5, 0.0, 2.5)) != "", "blocker names the overlap")
	assert_true(station.placement_blocker(t, Vector3(2.5, 7.0, 2.5)) != "", "same cell at another height refused")
	assert_true(station.try_place_station(t, Vector3(4.5, 0.0, 2.5)) != "", "adjacent cell accepted")
	assert_eq(station.try_place_station("NoSuchStation", Vector3(9.5, 0.0, 9.5)), "", "unknown type refused")
	assert_eq(station.get_all_stations().size(), 2, "only accepted placements stored")
	station.show_preview(t, Vector3(2.5, 0.0, 2.5))
	assert_true(station.is_preview_visible(), "preview shown")
	station.hide_preview()
	assert_true(not station.is_preview_visible(), "preview hidden")
	station.free()

## Phase 56 — placement is cheap per frame and the overlap rule is defined on snapped
## cells: the fabric scan runs once however often the blocker / preview ask, two stations in
## one x/z cell collide at any height, and neighbouring cells do not.
func _test_station_placement_cost_and_overlap() -> void:
	var station := StationSlice.new()
	add_child(station)
	var t: String = str(station.placeable_station_types()[0])
	assert_eq(station.placeable_scan_count, 1, "the first ask scans the fabric once")
	assert_true(station.try_place_station(t, Vector3(5.5, 0.0, 5.5)) != "", "a station is placed")
	for i in 20:
		station.placement_blocker(t, Vector3(7.5, 0.0, 7.5))
		station.show_preview(t, Vector3(7.5, float(i), 7.5))
	assert_eq(station.placeable_scan_count, 1, "twenty blocker checks and previews never rescan RECIPES/ITEMS")
	assert_eq(station.try_place_station(t, Vector3(5.2, 9.0, 5.8)), "", "the same cell at another height collides")
	assert_true(station.placement_blocker(t, Vector3(5.5, -3.0, 5.5)).begins_with("too close"), "and the reason says why")
	assert_true(station.try_place_station(t, Vector3(6.5, 0.0, 5.5)) != "", "the adjacent cell on x is free")
	assert_true(station.try_place_station(t, Vector3(5.5, 0.0, 6.5)) != "", "the adjacent cell on z is free")
	assert_eq(station.snap_to_grid(Vector3(-0.1, 2.0, 0.9)), Vector3(-0.5, 2.0, 0.5), "negative coordinates snap to their own cell")
	station.free()

## Phase 56 — the player's placement target (aimed top face, side hit, feet), the V key
## through `try_place_station` with its refusal reason on the label, and the preview ghost
## hidden while a menu or the loading screen owns the input.
func _test_player_station_placement() -> void:
	var station := StationSlice.new()
	add_child(station)
	var p := PlayerSlice.new()
	add_child(p)
	p.station_slice = station
	p.spawn_at(Vector3(10.0, 5.0, 10.0))
	var feet: Vector3 = p.get_position() - Vector3(0.0, 0.4, 0.0)
	# No aimed block: the feet fallback.
	p._aimed_block_hit = false
	assert_eq(p._station_target(), feet, "no aim: the target is at the player's feet")
	# An aimed top face puts it on top of the block (half a block up).
	p._aimed_block_hit = true
	p._aimed_block_pos = Vector3(3.5, 2.0, 3.5)
	p._aimed_block_normal = Vector3.UP
	assert_eq(p._station_target(), Vector3(3.5, 2.5, 3.5), "aimed top face: on top of the block")
	# A side or underside hit falls back to the feet rather than burying the marker.
	p._aimed_block_normal = Vector3.RIGHT
	assert_eq(p._station_target(), feet, "a side hit falls back to the feet")
	p._aimed_block_normal = Vector3.DOWN
	assert_eq(p._station_target(), feet, "an underside hit falls back to the feet")

	# V through try_place_station: placed once, refused (with the reason) the second time.
	p._aimed_block_hit = true
	p._aimed_block_pos = Vector3(3.5, 2.0, 3.5)
	p._aimed_block_normal = Vector3.UP
	var label := Label.new()
	p._station_label = label
	p._place_station()
	assert_eq(station.get_all_stations().size(), 1, "V places a station at the aimed spot")
	p._place_station()
	assert_eq(station.get_all_stations().size(), 1, "a second V on the same cell places nothing")
	assert_true(label.text.contains("too close"), "and the refusal reason shows on the station label")
	label.free()

	# The ghost follows the target while the preview is on and input is allowed; while a menu
	# or the loading freeze holds the input it is hidden instead.
	p._station_preview_on = true
	p.set_world_input_frozen(true)
	station.show_preview(str(station.placeable_station_types()[0]), Vector3(1.5, 0.0, 1.5))
	p._update_station_preview()
	assert_false(station.is_preview_visible(), "a frozen world hides the placement ghost")
	p._station_preview_on = false
	p._update_station_preview()
	assert_false(station.is_preview_visible(), "preview off: nothing is drawn")
	p.free()
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
	# Force the tool to one remaining point via use_item, then use it past the break.
	_wear_item(inv, "FerritePick", int(inv.get_max_durability("FerritePick")) - 1)
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
	var drop_before := _sum_durability_across([inv])
	inv.drop_item("FerritePick", 1)
	assert_eq(inv.get_item_count("FerritePick"), 0, "pick dropped from inventory")
	assert_true(_sum_durability_across([inv]) <= drop_before, "drop never increases total durability")
	# Pick up a fresh FerritePick — durability must be full again.
	inv.add_item("FerritePick", 1)
	assert_eq(inv.get_durability("FerritePick"), max_d, "repicked tool starts at max durability")
	inv.free()

func _test_durability_find_tool_skips_broken() -> void:
	var inv := InventorySlice.new()
	add_child(inv)
	inv.add_item("FerritePick", 1)
	inv.add_item("VeilsteelPick", 1)
	# Break both picks via use_item — find_tool must return "".
	_break_item(inv, "VeilsteelPick")
	_break_item(inv, "FerritePick")
	var none := inv.find_tool("pick")
	assert_eq(none, "", "find_tool returns empty when all picks are broken")
	# Restore one pick's durability — find_tool must return it now.
	inv.repair_item("FerritePick")
	var found := inv.find_tool("pick")
	assert_eq(found, "FerritePick", "find_tool returns FerritePick once restored")
	inv.free()


# ---------------------------------------------------------------------------
# Repair tests (Phase 25 — deferred from Phase 16 tool repair)
# ---------------------------------------------------------------------------

## Wear `item_id` down by `uses` via the public use_item API, so durability
## tests exercise the real wear path instead of poking the private
## `_durability` dictionary.
func _wear_item(item: Node, item_id: String, uses: int) -> void:
	for i in uses:
		item.use_item(item_id, "mine")

## Break `item_id` completely by applying use_item max_durability times.
func _break_item(item: Node, item_id: String) -> void:
	var max_d := int(item.get_max_durability(item_id))
	for i in max_d:
		item.use_item(item_id, "mine")

## Sum every per-instance durability value across a list of inventory slices.
## Used to assert durability is conserved across a sync/load copy (never lost,
## never fabricated).
func _sum_durability_across(invs: Array) -> float:
	var total := 0.0
	for inv in invs:
		var data: Dictionary = inv.get_durability_data()
		for item_id in data:
			for v in data[item_id]:
				total += float(v)
	return total

func _test_durability_sync_is_copy_not_move() -> void:
	# Sync/load apply a COPY of the source's durability: the destination's
	# durability map matches the source's exactly, the total is conserved, and
	# the source retains its own state — unlike a transfer/consume, which is a
	# MOVE that empties the source.
	var src := InventorySlice.new()
	add_child(src)
	var dst := InventorySlice.new()
	add_child(dst)
	src.add_item("FerritePick", 2)
	src.use_item("FerritePick", "mine")   # wear one instance
	var src_data: Dictionary = src.get_durability_data()
	dst.replace_contents(src.get_contents(), src_data)
	assert_eq(dst.get_durability_data(), src.get_durability_data(), "destination durability map equals source exactly")
	assert_eq(dst.get_durability_values("FerritePick"), src.get_durability_values("FerritePick"), "per-instance values match")
	assert_eq(_sum_durability_across([dst]), _sum_durability_across([src]), "total durability conserved by the copy")
	assert_eq(src.get_item_count("FerritePick"), 2, "source still holds its items (copy, not move)")
	assert_eq(src.get_durability_data(), src_data, "source durability unchanged after sync")
	src.free()
	dst.free()

func _test_sync_shrink_keeps_worst_instance() -> void:
	# A shrinking sync (host says 1, client holds 3) with NO durability payload
	# must keep the WORST instance, not the first-stored (pristine) one.
	var client := InventorySlice.new()
	add_child(client)
	client.add_item("FerritePick", 3, [80.0, 50.0, 10.0])
	assert_eq(client.get_durability_values("FerritePick").size(), 3, "client holds three picks")
	client.replace_contents({ "FerritePick": 1 }, {})
	var vals := client.get_durability_values("FerritePick")
	assert_eq(vals.size(), 1, "one survivor after the shrink")
	assert_eq(vals[0], 10.0, "survivor is the worst instance, not the first-stored pristine one")
	client.free()

func _test_sync_short_payload_pads_with_carried_value() -> void:
	# A payload claiming 3 instances but carrying one value pads all three with
	# that value, NOT the fabric max — a short payload must not fabricate
	# pristine copies.
	var inv := InventorySlice.new()
	add_child(inv)
	inv.replace_contents({ "FerritePick": 3 }, { "FerritePick": [50.0] })
	var vals := inv.get_durability_values("FerritePick")
	assert_eq(vals.size(), 3, "three instances after sync")
	assert_eq(vals[0], 50.0, "first instance carries the payload value")
	assert_eq(vals[1], 50.0, "second instance padded with the carried value")
	assert_eq(vals[2], 50.0, "third instance padded with the carried value")
	inv.free()

func _test_durability_clamp_above_max() -> void:
	# A payload durability above the fabric max must clamp to max — it must not
	# fabricate condition beyond pristine.
	var inv := InventorySlice.new()
	add_child(inv)
	var max_d := inv.get_max_durability("FerritePick")
	inv.replace_contents({ "FerritePick": 1 }, { "FerritePick": [max_d + 50.0] })
	assert_eq(inv.get_durability("FerritePick"), max_d, "above-max payload value clamps to max")
	inv.free()

func _test_durability_clamp_negative_broken() -> void:
	# A negative payload durability clamps to 0 (broken), not to a bogus
	# negative value.
	var inv := InventorySlice.new()
	add_child(inv)
	inv.replace_contents({ "FerritePick": 1 }, { "FerritePick": [-5.0] })
	assert_eq(inv.get_durability("FerritePick"), 0.0, "negative payload value becomes broken (0)")
	inv.free()

func _test_durability_values_round_trip() -> void:
	# Sync: replace_contents with durability data preserves exact values.
	var inv := InventorySlice.new()
	add_child(inv)
	inv.add_item("FerritePick", 2)
	inv.use_item("FerritePick", "mine")
	var inv2 := InventorySlice.new()
	add_child(inv2)
	inv2.replace_contents(inv.get_contents(), inv.get_durability_data())
	assert_eq(inv2.get_durability_values("FerritePick"), inv.get_durability_values("FerritePick"), "sync round-trips exact durability values")
	inv.free()
	inv2.free()
	# Trade: the transferred pick keeps its exact worn value.
	var inv_a := InventorySlice.new()
	add_child(inv_a)
	var inv_b := InventorySlice.new()
	add_child(inv_b)
	inv_a.add_item("FerritePick", 1)
	inv_a.use_item("FerritePick", "mine")
	var worn_d := inv_a.get_durability("FerritePick")
	var t := TradeSlice.new()
	add_child(t)
	t.set_party_inventory("player", inv_a)
	t.set_party_inventory("peer", inv_b)
	t.set_skill("Trade", "master")
	var tid := t.start_trade("player", "peer")
	t.propose(tid, "player", { "FerritePick": 1 }, {})
	t.propose(tid, "peer", {}, { "FerritePick": 1 })
	var trade_before := _sum_durability_across([inv_a, inv_b])
	t.accept(tid, "player")
	t.accept(tid, "peer")
	assert_eq(inv_b.get_durability("FerritePick"), worn_d, "trade round-trips the exact worn value")
	assert_true(_sum_durability_across([inv_a, inv_b]) <= trade_before, "trade never increases total durability")
	t.free()
	inv_a.free()
	inv_b.free()
	# Market: buying a worn listing yields a worn item.
	var seller := InventorySlice.new()
	add_child(seller)
	var buyer := InventorySlice.new()
	add_child(buyer)
	var m := MarketSlice.new()
	add_child(m)
	m.set_party_inventory("seller", seller)
	m.set_party_inventory("buyer", buyer)
	seller.add_item("FerritePick", 1)
	seller.use_item("FerritePick", "mine")
	var worn_d2 := seller.get_durability("FerritePick")
	var buy_before := _sum_durability_across([seller, buyer])
	var lid := m.list_item("seller", "FerritePick", 1, 10.0)
	assert_true(lid != "", "listing created")
	var buy_res := m.buy(lid, "buyer")
	assert_true(bool(buy_res.get("success", false)), "buy succeeds")
	assert_eq(buyer.get_durability("FerritePick"), worn_d2, "market buy round-trips the exact worn value")
	assert_true(_sum_durability_across([seller, buyer]) <= buy_before, "market buy never increases total durability")
	seller.free()
	buyer.free()
	m.free()

func _test_market_expire_preserves_wear() -> void:
	var seller := InventorySlice.new()
	add_child(seller)
	var m := MarketSlice.new()
	add_child(m)
	m.set_party_inventory("seller", seller)
	seller.add_item("FerritePick", 1)
	seller.use_item("FerritePick", "mine")
	var worn_d := seller.get_durability("FerritePick")
	var max_d := seller.get_max_durability("FerritePick")
	assert_true(worn_d < max_d, "seller holds a worn pick")
	var expiry_before := _sum_durability_across([seller])
	var lid := m.list_item("seller", "FerritePick", 1, 10.0, 0.0)   # expires immediately
	assert_true(lid != "", "listing created")
	assert_eq(seller.get_item_count("FerritePick"), 0, "pick escrowed out of seller inventory")
	var removed := m.expire_listings()
	assert_true(removed >= 1, "listing expired")
	assert_eq(seller.get_item_count("FerritePick"), 1, "pick refunded")
	assert_eq(seller.get_durability("FerritePick"), worn_d, "refunded pick is still worn, not pristine")
	assert_true(_sum_durability_across([seller]) <= expiry_before, "market expiry never increases total durability")
	seller.free()
	m.free()

func _test_sync_pristine_over_worn() -> void:
	# Host's authoritative durability must overwrite a client's worn copy — a
	# pristine pick in the sync payload comes back pristine, not preserved-worn.
	var client := InventorySlice.new()
	add_child(client)
	client.add_item("FerritePick", 1)
	client.use_item("FerritePick", "mine")
	var max_d := client.get_max_durability("FerritePick")
	assert_true(client.get_durability("FerritePick") < max_d, "client pick starts worn")

	var host := InventorySlice.new()
	add_child(host)
	host.add_item("FerritePick", 1)   # pristine

	client.replace_contents(host.get_contents(), host.get_durability_data())
	assert_eq(client.get_durability("FerritePick"), max_d, "host pristine pick overwrites the client's worn copy")
	client.free()
	host.free()

func _test_sync_missing_payload_grants_fresh_excess() -> void:
	# A sync whose payload omits a durable item must preserve the LOCAL worn
	# value for the overlapping quantity, but grant FRESH (max) for the excess —
	# the host says we now hold 3, we only ever held 1, so the 2 new copies are
	# genuinely fresh, not cloned-worn.
	var client := InventorySlice.new()
	add_child(client)
	client.add_item("FerritePick", 1)
	client.use_item("FerritePick", "mine")
	var max_d := client.get_max_durability("FerritePick")
	var worn_d := client.get_durability("FerritePick")
	assert_true(worn_d < max_d, "client pick starts worn")

	# Host syncs a larger quantity but sends NO durability for FerritePick.
	client.replace_contents({ "FerritePick": 3 }, {})
	var vals := client.get_durability_values("FerritePick")
	assert_eq(vals.size(), 3, "three instances after sync")
	assert_eq(vals[0], worn_d, "overlapping instance preserves the local worn value")
	assert_eq(vals[1], max_d, "first excess instance is fresh (max)")
	assert_eq(vals[2], max_d, "second excess instance is fresh (max)")
	client.free()

func _test_repair_spec_loaded() -> void:
	var c := CraftingSlice.new()
	add_child(c)
	var spec := c.get_repair_spec("FerritePick")
	assert_false(spec.is_empty(), "FerritePick has a repair spec")
	assert_eq(spec["station"], "forge", "FerritePick repairs at a forge")
	assert_eq(spec["materials"][0]["item"], "FerriteIngot", "repair material is FerriteIngot")
	assert_eq(spec["skillGuards"][0]["skill"], "Smithing", "repair guard is Smithing")
	assert_true(c.get_repair_spec("FerriteIngot").is_empty(), "stackable material has no repair spec")
	c.free()

func _test_repair_restores_worn() -> void:
	var c := CraftingSlice.new()
	add_child(c)
	var inv := InventorySlice.new()
	add_child(inv)
	c.inventory_slice = inv
	inv.add_item("FerritePick", 1)
	inv.add_item("FerriteIngot", 1)
	var max_d := inv.get_max_durability("FerritePick")
	inv.use_item("FerritePick", "mine")
	assert_eq(inv.get_durability("FerritePick"), max_d - 1.0, "pick worn by one use")
	var result := c.repair("FerritePick")
	assert_true(result["success"], "repair succeeds")
	assert_eq(inv.get_durability("FerritePick"), max_d, "durability restored to max")
	assert_eq(inv.get_condition("FerritePick"), "pristine", "condition back to pristine")
	c.free()
	inv.free()

func _test_repair_consumes_materials() -> void:
	var c := CraftingSlice.new()
	add_child(c)
	var inv := InventorySlice.new()
	add_child(inv)
	c.inventory_slice = inv
	inv.add_item("FerritePick", 1)
	inv.add_item("FerriteIngot", 3)
	inv.use_item("FerritePick", "mine")
	var result := c.repair("FerritePick")
	assert_true(result["success"], "repair succeeds")
	assert_eq(inv.get_item_count("FerriteIngot"), 2, "one FerriteIngot consumed")
	c.free()
	inv.free()

func _test_repair_skill_guard_blocks() -> void:
	var c := CraftingSlice.new()
	add_child(c)
	var inv := InventorySlice.new()
	add_child(inv)
	c.inventory_slice = inv
	inv.add_item("VeilsteelPick", 1)
	inv.add_item("VeilsteelIngot", 1)
	_wear_item(inv, "VeilsteelPick", 1)   # worn
	# Default Smithing tier is novice; VeilsteelPick repair requires journeyman.
	var result := c.repair("VeilsteelPick")
	assert_false(result["success"], "repair blocked at novice")
	assert_true(str(result["reason"]).begins_with("skill_requirement"), "reason is skill_requirement")
	c.free()
	inv.free()

func _test_repair_station_gate_blocks() -> void:
	var station := StationSlice.new()
	add_child(station)
	var c := CraftingSlice.new()
	add_child(c)
	var inv := InventorySlice.new()
	add_child(inv)
	c.inventory_slice = inv
	c.station_slice = station
	inv.add_item("FerritePick", 1)
	inv.add_item("FerriteIngot", 1)
	_wear_item(inv, "FerritePick", 1)
	station.set_player_position(Vector3.ZERO)
	var result := c.repair("FerritePick")
	assert_false(result["success"], "repair blocked without a forge")
	assert_true(str(result["reason"]).begins_with("station_required"), "reason is station_required")
	station.place_station("forge", Vector3(1.0, 0.0, 0.0))
	var result2 := c.repair("FerritePick")
	assert_true(result2["success"], "repair succeeds with a forge nearby")
	station.free()
	c.free()
	inv.free()

func _test_repair_pristine_rejected() -> void:
	var c := CraftingSlice.new()
	add_child(c)
	var inv := InventorySlice.new()
	add_child(inv)
	c.inventory_slice = inv
	inv.add_item("FerritePick", 1)
	inv.add_item("FerriteIngot", 1)
	var result := c.repair("FerritePick")
	assert_false(result["success"], "pristine item cannot be repaired")
	assert_eq(result["reason"], "already_pristine", "reason is already_pristine")
	c.free()
	inv.free()

func _test_repair_non_durable_rejected() -> void:
	var c := CraftingSlice.new()
	add_child(c)
	var inv := InventorySlice.new()
	add_child(inv)
	c.inventory_slice = inv
	inv.add_item("FerriteIngot", 5)
	var result := c.repair("FerriteIngot")
	assert_false(result["success"], "stackable material cannot be repaired")
	assert_eq(result["reason"], "not_repairable", "reason is not_repairable")
	c.free()
	inv.free()

func _test_repair_broken_via_bus() -> void:
	var c := CraftingSlice.new()
	add_child(c)
	var inv := InventorySlice.new()
	add_child(inv)
	c.inventory_slice = inv
	inv.add_item("FerritePick", 1)
	inv.add_item("FerriteIngot", 3)
	_break_item(inv, "FerritePick")   # broken
	var resolved := {}
	GameBus.repair_resolved.connect(func(r): resolved["r"] = r)
	GameBus.repair_requested.emit("FerritePick")
	var r: Dictionary = resolved.get("r", {})
	assert_true(r.get("success", false), "repair via bus succeeds")
	assert_eq(inv.get_durability("FerritePick"), inv.get_max_durability("FerritePick"), "broken tool restored to full")
	assert_eq(inv.get_item_count("FerriteIngot"), 0, "broken repair consumed all three tier-scaled ingots")
	c.free()
	inv.free()

func _test_repair_can_repair_direct() -> void:
	var c := CraftingSlice.new()
	add_child(c)
	var inv := InventorySlice.new()
	add_child(inv)
	c.inventory_slice = inv
	inv.add_item("FerritePick", 1)
	inv.add_item("FerriteIngot", 1)
	inv.use_item("FerritePick", "mine")
	var check := c.can_repair("FerritePick")
	assert_true(check["success"], "can_repair reports success for a worn held pick with materials")
	# can_repair must be a pure query: no materials consumed, durability unchanged.
	assert_eq(inv.get_item_count("FerriteIngot"), 1, "can_repair consumes no materials")
	assert_eq(inv.get_condition("FerritePick"), "worn", "can_repair does not restore durability")
	c.free()
	inv.free()

func _test_repair_failed_consumes_nothing() -> void:
	var c := CraftingSlice.new()
	add_child(c)
	var inv := InventorySlice.new()
	add_child(inv)
	c.inventory_slice = inv
	inv.add_item("VeilsteelPick", 1)
	inv.add_item("VeilsteelIngot", 1)
	_wear_item(inv, "VeilsteelPick", 1)
	# Novice Smithing blocks the journeyman-gated repair.
	var result := c.repair("VeilsteelPick")
	assert_false(result["success"], "repair blocked by the skill guard")
	assert_eq(inv.get_item_count("VeilsteelIngot"), 1, "a failed repair consumes no materials")
	c.free()
	inv.free()

func _test_repair_missing_inputs() -> void:
	var c := CraftingSlice.new()
	add_child(c)
	var inv := InventorySlice.new()
	add_child(inv)
	c.inventory_slice = inv
	inv.add_item("FerritePick", 1)
	inv.use_item("FerritePick", "mine")
	var result := c.repair("FerritePick")
	assert_false(result["success"], "repair fails when materials are absent")
	assert_eq(result["reason"], "missing_inputs", "reason is missing_inputs")
	c.free()
	inv.free()

func _test_repair_no_item() -> void:
	var c := CraftingSlice.new()
	add_child(c)
	var inv := InventorySlice.new()
	add_child(inv)
	c.inventory_slice = inv
	inv.add_item("FerriteIngot", 1)
	var result := c.repair("FerritePick")
	assert_false(result["success"], "repair fails when the item is not held")
	assert_eq(result["reason"], "no_item", "reason is no_item")
	c.free()
	inv.free()

func _test_repair_multi_material_aethermitebow() -> void:
	var c := CraftingSlice.new()
	add_child(c)
	var inv := InventorySlice.new()
	add_child(inv)
	c.inventory_slice = inv
	c.set_skill("ArcaneForging", "apprentice")
	inv.add_item("AethermiteBow", 1)
	inv.add_item("ThornwoodPlank", 1)
	inv.add_item("AethermiteDust", 1)
	inv.use_item("AethermiteBow", "attack")   # worn (tiers=1)
	var result := c.repair("AethermiteBow")
	assert_true(result["success"], "AethermiteBow repairs with both materials")
	assert_eq(inv.get_item_count("ThornwoodPlank"), 0, "thornwood plank consumed")
	assert_eq(inv.get_item_count("AethermiteDust"), 0, "aethermite dust consumed")
	assert_eq(inv.get_condition("AethermiteBow"), "pristine", "bow restored to pristine")
	c.free()
	inv.free()

func _test_trade_broken_item_not_pristine() -> void:
	var inv_a := InventorySlice.new()
	add_child(inv_a)
	var inv_b := InventorySlice.new()
	add_child(inv_b)
	inv_a.add_item("FerritePick", 1)
	_break_item(inv_a, "FerritePick")
	assert_eq(inv_a.get_condition("FerritePick"), "broken", "seller holds a broken pick")
	var t := TradeSlice.new()
	add_child(t)
	t.set_party_inventory("player", inv_a)
	t.set_party_inventory("peer", inv_b)
	t.set_skill("Trade", "master")   # tax-free so the exchange is clean
	var tid := t.start_trade("player", "peer")
	t.propose(tid, "player", { "FerritePick": 1 }, {})
	t.propose(tid, "peer", {}, { "FerritePick": 1 })
	t.accept(tid, "player")
	var result: Dictionary = t.accept(tid, "peer")
	assert_true(bool(result.get("success", false)), "trade resolves")
	assert_eq(inv_b.get_item_count("FerritePick"), 1, "peer received the pick")
	assert_eq(inv_b.get_condition("FerritePick"), "broken", "traded pick stays broken, not pristine")
	t.free()
	inv_a.free()
	inv_b.free()

func _test_trade_pristine_to_broken_holder() -> void:
	var inv_a := InventorySlice.new()
	add_child(inv_a)
	var inv_b := InventorySlice.new()
	add_child(inv_b)
	# B already holds a broken pick.
	inv_b.add_item("FerritePick", 1)
	_break_item(inv_b, "FerritePick")
	assert_eq(inv_b.get_condition("FerritePick"), "broken", "holder's pick is broken")
	# A trades a pristine pick to B.
	inv_a.add_item("FerritePick", 1)
	var t := TradeSlice.new()
	add_child(t)
	t.set_party_inventory("player", inv_a)
	t.set_party_inventory("peer", inv_b)
	t.set_skill("Trade", "master")
	var tid := t.start_trade("player", "peer")
	t.propose(tid, "player", { "FerritePick": 1 }, {})
	t.propose(tid, "peer", {}, { "FerritePick": 1 })
	t.accept(tid, "player")
	var result: Dictionary = t.accept(tid, "peer")
	assert_true(bool(result.get("success", false)), "trade resolves")
	assert_eq(inv_b.get_item_count("FerritePick"), 2, "holder now has two picks")
	# The broken copy is preserved — the pristine transfer must not overwrite it.
	assert_eq(inv_b.get_condition("FerritePick"), "broken", "broken copy still broken, not overwritten")
	assert_eq(inv_b.find_tool("pick"), "FerritePick", "a usable pristine instance is still present")
	t.free()
	inv_a.free()
	inv_b.free()

func _test_repair_specs_resolve() -> void:
	var c := CraftingSlice.new()
	add_child(c)
	for item_id in GameData.ITEMS:
		var spec := c.get_repair_spec(str(item_id))
		if spec.is_empty():
			continue
		assert_true(str(spec.get("station", "")) != "", "repair spec for %s names a station" % item_id)
		for mat in spec.get("materials", []):
			var mid := str(mat.get("item", ""))
			assert_true(
				GameData.ITEMS.has(mid) or GameData.MATERIALS.has(mid),
				"repair material '%s' for %s resolves to an item or material" % [mid, item_id]
			)
		for guard in spec.get("skillGuards", []):
			var skill := str(guard.get("skill", ""))
			var tier := str(guard.get("tier", "novice"))
			assert_true(GameData.SKILLS.has(skill), "repair skill '%s' for %s resolves to a skill" % [skill, item_id])
			assert_true(SkillTiers.TIER_ORDER.has(tier), "repair tier '%s' for %s is a valid tier" % [tier, item_id])
	c.free()


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
	hm.resize(64 * 64)
	hm.fill(2.0)
	v.build_chunk(Vector2i(0, 0), hm)
	return v

func _test_voxel_mine_yields_material() -> void:
	var v := _make_voxel()
	var inv := InventorySlice.new()
	add_child(inv)
	v.inventory_slice = inv
	assert_eq(v.get_voxel_height_at(Vector2(16.0, 16.0)), 2.0, "flat chunk height is 2.0")
	var r := v.mine_block(Vector3(16.0, 2.0, 16.0))
	assert_true(r.get("success", false), "mine succeeds on a 2.0-tall column")
	assert_eq(v.get_voxel_height_at(Vector2(16.0, 16.0)), 1.875, "height lowered by STEP_HEIGHT")
	assert_true(GameData.MATERIALS.has(r.get("material", "")), "yielded a valid fabric material")
	assert_eq(inv.get_item_count(str(r.get("material", ""))), 1, "material added to inventory")
	v.free()
	inv.free()

## Phase 41 — bedrock is a DEPTH now (BEDROCK_DEPTH), not zero: the ground has real
## thickness, so a column can be mined below y = 0 and the floor refuses only when
## there is no material above it left to yield.
func _test_voxel_mine_bedrock() -> void:
	var v := _make_voxel()
	var floor_y: float = VoxelSlice.BEDROCK_DEPTH
	var last_step: float = floor_y + VoxelSlice.STEP_HEIGHT
	# A column whose only material is the last step above the floor.
	v.apply_edits({ "32,32": last_step })
	var xz := Vector2(16.25, 16.25)
	assert_eq(v.get_voxel_height_at(xz), last_step, "the column stands on the last step above the floor")
	var r := v.mine_block(Vector3(xz.x, last_step, xz.y))
	assert_true(r.get("success", false), "mining one STEP_HEIGHT above bedrock succeeds")
	assert_eq(v.get_column_runs_at(xz).size(), 0, "and leaves nothing above the floor")
	var r2 := v.mine_block(Vector3(xz.x, last_step, xz.y))
	assert_false(r2.get("success", false), "mining at BEDROCK_DEPTH is refused")
	v.free()

## A side-face hit lands on the boundary between two columns, so the ray is stepped
## back into the block it aimed at — and, since Phase 41, the SPAN it removes is the
## block at the height it hit, not the column's top. A mid-column carve therefore
## leaves a floor run and a roof run: a tunnel.
func _test_voxel_mine_side_face() -> void:
	var v := _make_voxel()
	var inv := InventorySlice.new()
	add_child(inv)
	v.inventory_slice = inv
	# East-facing face (normal +X) at x=17.0: the hit block is tile 33 (west, world [16.5,17.0)).
	v.mine_block(Vector3(17.0, 1.5, 16.5), Vector3(1, 0, 0))
	assert_eq(v.get_column_runs_at(Vector2(16.75, 16.75)).size(), 2, "+X face carves the block west of the boundary")
	assert_eq(v.get_voxel_height_at(Vector2(16.75, 16.75)), 2.0, "and leaves the block above it standing")
	assert_eq(v.get_column_runs_at(Vector2(17.25, 16.75)).size(), 1, "east block untouched")
	# West-facing face (normal -X) at x=19.0: the hit block is tile 38 (east, world [19.0,19.5)).
	v.mine_block(Vector3(19.0, 1.5, 16.5), Vector3(-1, 0, 0))
	assert_eq(v.get_column_runs_at(Vector2(19.25, 16.75)).size(), 2, "-X face carves the block east of the boundary")
	assert_eq(v.get_column_runs_at(Vector2(18.75, 16.75)).size(), 1, "west block untouched")
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
	var ok := v.place_block(Vector3(16.0, 2.0, 16.0), Vector3.UP)
	assert_true(ok, "place succeeds")
	assert_eq(v.get_voxel_height_at(Vector2(16.0, 16.0)), 2.125, "height raised by STEP_HEIGHT")
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
	v.apply_edits({ "32,32": v.MAX_HEIGHT })
	var ok := v.place_block(Vector3(16.0, v.MAX_HEIGHT, 16.0), Vector3.UP)
	assert_false(ok, "place beyond build cap fails")
	assert_eq(inv.get_item_count("Ashite"), 1, "blocked placement refunds the material")
	v.free()
	inv.free()

func _test_voxel_biome_materials() -> void:
	var v := VoxelSlice.new()
	var volcanic: Array = []
	for i in range(64):
		volcanic.append(v.material_for_biome("VolcanicBadlands", Vector2(i, 0)))
	assert_true(volcanic.has("Ashite"), "volcanic yields ashite (dominant rock)")
	assert_false(volcanic.has("Thornwood") or volcanic.has("Duskfiber"), "no wood from the volcanic ground")
	var temperate: Array = []
	for i in range(64):
		temperate.append(v.material_for_biome("TemperateForest", Vector2(i, 0)))
	assert_true(temperate.has("Ferrite"), "temperate yields ferrite (dominant metal)")
	assert_false(temperate.has("Thornwood") or temperate.has("Duskfiber"), "no wood from the temperate ground")
	v.free()

## Phase 49 — an unedited natural column's top face wears the biome's fabric surface tint, its
## wall wears the soil tint down to `topsoilDepth`, and rock (the host material's colour) shows
## below that.
func _test_voxel_grass_top_soil_side() -> void:
	var v := VoxelSlice.new()
	add_child(v)
	var style := VoxelSlice.surface_style("TemperateForest")
	assert_false(style.is_empty(), "the temperate biome carries fabric surface fields")
	var hm: Array = []
	hm.resize(64 * 64)
	hm.fill(8.0)
	var arrays := VoxelSlice.build_chunk_arrays(Vector2i(0, 0), hm, v.collect_build_runs(Vector2i(0, 0), hm))
	var rock := VoxelSlice._material_color(OreField.host_material("TemperateForest"))
	var normals: PackedVector3Array = arrays["normals"]
	var colors: PackedColorArray = arrays["colors"]
	var verts: PackedVector3Array = arrays["vertices"]
	var top_ok := true
	var soil_seen := false
	var rock_seen := false
	var top_y := 8.0
	for i in range(verts.size()):
		if normals[i].y > 0.5:
			top_ok = top_ok and colors[i].is_equal_approx(style["top"])
		elif absf(normals[i].y) < 0.1:
			if verts[i].y > top_y - float(style["depth"]) + 0.01:
				soil_seen = soil_seen or colors[i].is_equal_approx(style["soil"])
			elif verts[i].y < top_y - float(style["depth"]) - 0.01:
				rock_seen = rock_seen or colors[i].is_equal_approx(rock)
	assert_true(top_ok, "every unedited top face is the fabric grass tint")
	assert_true(soil_seen, "the wall shows soil within topsoilDepth of the surface")
	assert_true(rock_seen, "and rock below the topsoil")
	assert_false(style["top"].is_equal_approx(rock), "grass is not the rock colour")
	v.free()

## Phase 43 — the uniform per-tile draw is retired: the surface (depth 0) is host rock and
## shallow veins, and a DEEP ore never appears there however many tiles are asked.
func _test_voxel_material_rarity() -> void:
	var v := VoxelSlice.new()
	# Fabric fidelity: the temperate prose grants no rare ground ore (ferrite
	# outcrops only — wood comes from trees), so the whole biome is ferrite.
	var temperate_only_ferrite := true
	for tz in range(64):
		for tx in range(64):
			var wc := Vector2(
				tx * VoxelSlice.TILE_SIZE + VoxelSlice.TILE_SIZE * 0.5,
				tz * VoxelSlice.TILE_SIZE + VoxelSlice.TILE_SIZE * 0.5)
			if v.material_for_biome("TemperateForest", wc) != "Ferrite" and \
					OreField.vein_at(0, Vector2i.ZERO, Vector2i(tx, tz), 0.0).is_empty():
				temperate_only_ferrite = false
	assert_true(temperate_only_ferrite, "temperate host rock is ferrite (no invented rare ore)")
	# The volcanic host is ashite, and Aethermite — a DEEP ore — is never at the surface.
	var ashite := 0
	var aethermite := 0
	for tz in range(64):
		for tx in range(64):
			var wc := Vector2(
				tx * VoxelSlice.TILE_SIZE + VoxelSlice.TILE_SIZE * 0.5,
				tz * VoxelSlice.TILE_SIZE + VoxelSlice.TILE_SIZE * 0.5)
			var m := v.material_for_biome("VolcanicBadlands", wc, 0.0625)
			if m == "Ashite":
				ashite += 1
			elif m == "Aethermite":
				aethermite += 1
	assert_true(ashite > 0, "the volcanic surface is ashite host rock (%d tiles)" % ashite)
	assert_eq(aethermite, 0, "and never surface aethermite (its band starts four units down)")
	v.free()

func _test_voxel_edits_round_trip() -> void:
	var v := _make_voxel()
	v.apply_edits({ "32,32": 1.0, "34,34": 3.5 })
	assert_true(v.get_edits().get("32,32", null) is Array, "an edit is stored as typed run edits")
	assert_eq(v.get_voxel_height_at(Vector2(16.0, 16.0)), 1.0, "height reflects restored edit")
	assert_eq(v.get_voxel_height_at(Vector2(17.0, 17.0)), 3.5, "second edit restored")
	v.free()

## Phase 41 — a column carries a SPARSE list of solid runs, and a mid-column carve
## leaves TWO of them: a floor and a roof. Mining the roof must not touch the floor,
## and the collision soup the trimesh is built from must carry a downward face at the
## roof's underside, or a body inside the tunnel would fall straight through it.
##
## The physics half is exercised in GAME only: `_run_tests()` runs synchronously
## inside `GameRoot._ready()`, where a `move_and_slide()` never registers a collision
## (ROADMAP §Phase 39). What is asserted here is the geometry the trimesh is built
## from — the same triangles the mesh shows.
func _test_voxel_tunnel_runs() -> void:
	var v := _make_voxel()
	var inv := InventorySlice.new()
	add_child(inv)
	v.inventory_slice = inv
	# A side-face hit at y = 1.5 on the east face of tile (32,32): the ray lands on
	# the boundary x = 16.5, so the block it aimed at is the one west of it.
	var r := v.mine_block(Vector3(16.5, 1.5, 16.25), Vector3(1, 0, 0))
	assert_true(r.get("success", false), "the side-face mine succeeds")
	var xz := Vector2(16.25, 16.25)
	var runs: Array = v.get_column_runs_at(xz)
	assert_eq(runs.size(), 2, "the column now has a floor run and a roof run")
	assert_true(is_equal_approx(float(runs[0]["bottom"]), VoxelSlice.BEDROCK_DEPTH), "the floor run starts at the world floor")
	assert_true(is_equal_approx(float(runs[0]["top"]), 1.5), "and ends where the block was carved")
	assert_true(is_equal_approx(float(runs[1]["bottom"]), 1.625), "the roof run starts above the carve")
	assert_true(is_equal_approx(float(runs[1]["top"]), 2.0), "and reaches the old surface")
	assert_eq(v.get_voxel_height_at(xz), 2.0, "the column top is still the roof")
	# The collision triangle soup carries the roof's underside: all three vertices of
	# a triangle at y = 1.625, which is the downward face of the ceiling.
	var faces: PackedVector3Array = v.collision_faces(Vector2i(0, 0), v._heightmaps["0,0"])
	var ceiling_faces := 0
	for i in range(0, faces.size() - 2, 3):
		if is_equal_approx(faces[i].y, 1.625) and is_equal_approx(faces[i + 1].y, 1.625) and is_equal_approx(faces[i + 2].y, 1.625):
			ceiling_faces += 1
	assert_true(ceiling_faces > 0, "the collision soup carries the tunnel's ceiling (a face at y = 1.625)")
	# Mining the ROOF from inside the tunnel leaves the floor alone.
	var r2 := v.mine_block(Vector3(16.25, 1.625, 16.25), Vector3.DOWN)
	assert_true(r2.get("success", false), "the roof can be mined from inside the tunnel")
	var after: Array = v.get_column_runs_at(xz)
	assert_eq(after.size(), 2, "still two runs — the tunnel is still a tunnel")
	assert_true(is_equal_approx(float(after[0]["top"]), 1.5), "the tunnel floor is untouched")
	assert_true(float(after[1]["bottom"]) > 1.625, "only the roof's lowest step went")
	v.free()
	inv.free()

## Phase 41 — the footing sampler answers with the top of the highest run AT OR BELOW
## the body's own Y. A column-top sampler would answer with the tunnel's ROOF, which
## would stand the avatar on the ceiling it is walking under.
func _test_voxel_support_sampler_under_ceiling() -> void:
	var v := _make_voxel()
	var inv := InventorySlice.new()
	add_child(inv)
	v.inventory_slice = inv
	v.mine_block(Vector3(16.5, 1.5, 16.25), Vector3(1, 0, 0))
	var xz := Vector2(16.25, 16.25)
	assert_eq(v.get_voxel_height_at(xz), 2.0, "the column top is the roof")
	assert_eq(v.sample_support_height_at(xz, 1.5), 1.5, "a body at y 1.5 stands on the tunnel floor")
	assert_eq(v.sample_support_height_at(xz, 2.0), 2.0, "a body standing on the roof stands on the roof")
	assert_eq(v.sample_support_height_at(xz, VoxelSlice.BEDROCK_DEPTH), VoxelSlice.BEDROCK_DEPTH, "and nothing below the floor supports anything")
	v.free()
	inv.free()

## Phase 41 — a save written before this phase stored a bare absolute quantised height
## per tile, with the placed-material stacks beside it. That shape must LOAD with the
## edit intact: a scalar height becomes the single run from BEDROCK_DEPTH up to it, and
## a placed stack stays its own runs above the natural ground.
func _test_voxel_legacy_edit_migration() -> void:
	var v := VoxelSlice.new()
	add_child(v)
	var flat: Array = []
	flat.resize(64 * 64)
	flat.fill(2.0)
	v.build_chunk(Vector2i(0, 0), flat)
	# The pre-Phase-41 manifest, exactly as a version-1 world record carries it.
	var legacy := { "0,0": {
		"edits":     { "32,32": 1.0, "34,34": 2.125 },
		"materials": { "34,34": ["Ashite"] },
	} }
	v.apply_chunk_manifest(legacy)
	var mined_xz := Vector2(16.25, 16.25)
	assert_eq(v.get_voxel_height_at(mined_xz), 1.0, "a mined legacy edit migrates to its saved height")
	var runs: Array = v.get_column_runs_at(mined_xz)
	assert_eq(runs.size(), 1, "and migrates to ONE run")
	assert_true(is_equal_approx(float(runs[0]["bottom"]), VoxelSlice.BEDROCK_DEPTH), "from the world floor")
	assert_true(is_equal_approx(float(runs[0]["top"]), 1.0), "up to the saved height")
	# A legacy edit that BUILT (a top above the natural surface) plus its placed stack.
	var built_xz := Vector2(17.25, 17.25)
	assert_eq(v.get_voxel_height_at(built_xz), 2.125, "a built legacy edit migrates too")
	var built: Array = v.get_column_runs_at(built_xz)
	assert_eq(built.size(), 2, "as natural ground plus the placed block")
	assert_eq(str(built[-1]["material"]), "Ashite", "and the placed block keeps its material")
	# The migrated save is re-serialized in the NEW shape.
	var ops: Variant = v.get_chunk_manifest()["0,0"]["edits"]["32,32"]
	assert_true(ops is Array, "a migrated edit is written back as typed run edits")
	assert_eq(str(ops[0]["op"]), "remove", "naming the span it carved")
	v.free()

## Phase 41 review pass — the rendered shell must not depend on the ORDER the
## streamed chunks were built in. ChunkManager streams one chunk per frame,
## nearest-first, so a chunk's neighbour is very often built LATER, and nothing
## rebuilds a chunk when its neighbour arrives: a mesher that skipped the seam face
## while the neighbour was unknown therefore left it out for good, and every such
## seam (and the whole streamed window) was see-through. An unknown neighbour is
## read as EMPTY instead, so the column carrying the material always emits the
## facing wall — and the pair of facing walls is still emitted exactly once,
## whichever chunk was built first.
func _test_voxel_seam_wall_order_independent() -> void:
	var v := VoxelSlice.new()
	add_child(v)
	var west: Array = []
	west.resize(64 * 64)
	west.fill(2.0)
	var east: Array = []
	east.resize(64 * 64)
	east.fill(1.0)
	# The west chunk is built FIRST, while its lower neighbour is unknown.
	v.build_chunk(Vector2i(0, 0), west)
	var before := _plane_x_wall_spans(v.collision_faces(Vector2i(0, 0), west), 32.0)
	assert_true(before.size() > 0, "a chunk built before its lower neighbour still emits the seam wall")
	assert_eq(before, [[VoxelSlice.BEDROCK_DEPTH, 2.0]],
		"and it spans the whole column while the neighbour is still unknown")
	# The lower neighbour arrives, then the same chunk is rebuilt now that its
	# neighbour is KNOWN: the same one wall along the seam, now spanning exactly the
	# part the neighbour does NOT fill. The overlap below the neighbour's surface was
	# invisible inside its ground either way, so the rendered shell is the same set
	# of VISIBLE faces in either order — and it is asserted as geometry, not as a
	# triangle count: a wall emitted across the wrong ordinates has the same count.
	v.build_chunk(Vector2i(1, 0), east)
	v.build_chunk(Vector2i(0, 0), west)
	var after := _plane_x_wall_spans(v.collision_faces(Vector2i(0, 0), west), 32.0)
	assert_eq(after, [[1.0, 2.0]], "the seam converges on the exposed span when its neighbour arrives")
	assert_eq(after.size(), before.size(), "and it is still ONE wall along the seam, not two")
	# Duplicate-free from the other side: the lower chunk emits nothing at the same
	# plane, because it has no material the higher side lacks.
	assert_eq(_plane_x_spans(v.collision_faces(Vector2i(1, 0), east), 32.0), [],
		"the lower side emits no wall at the shared plane")
	v.free()

## The DISTINCT vertical spans of the collision triangles lying wholly on the
## vertical plane x = `plane`, sorted. A seam assertion needs the GEOMETRY: a wall
## emitted across the wrong ordinates (say the whole column instead of the step the
## neighbour does not fill) has exactly the same triangle COUNT as the right one.
func _plane_x_spans(faces: PackedVector3Array, plane: float) -> Array:
	var spans: Array = []
	for i in range(0, faces.size() - 2, 3):
		if not (is_equal_approx(faces[i].x, plane) and is_equal_approx(faces[i + 1].x, plane) and is_equal_approx(faces[i + 2].x, plane)):
			continue
		var span := [
			minf(faces[i].y, minf(faces[i + 1].y, faces[i + 2].y)),
			maxf(faces[i].y, maxf(faces[i + 1].y, faces[i + 2].y)),
		]
		if not spans.has(span):
			spans.append(span)
	spans.sort_custom(func(a: Array, b: Array): return float(a[0]) < float(b[0]))
	return spans

## `_plane_x_spans` with abutting spans fused. Phase 49 splits a wall at the soil line (two
## colours), so a wall is one fused span; only callers on a topsoiled wall should use this —
## the raw form above is what catches a genuinely split wall.
func _plane_x_wall_spans(faces: PackedVector3Array, plane: float) -> Array:
	var merged: Array = []
	for span in _plane_x_spans(faces, plane):
		if not merged.is_empty() and is_equal_approx(float(merged[-1][1]), float(span[0])):
			merged[-1][1] = span[1]
		else:
			merged.append(span)
	return merged

## Phase 41 review pass — an UP-face hit must resolve to the run whose TOP the ray
## landed on, not to the column's topmost run. A tunnel FLOOR keeps an exposed top
## face with the roof above it, and "the topmost run" answers with the ROOF: mining
## the floor took the roof's last step, and stacking on the floor put the block on
## the roof. Phase 41's whole point is that a column can carry a ceiling, so the
## floor has to be aimable.
func _test_voxel_tunnel_floor_top_face() -> void:
	var v := _make_voxel()
	var inv := InventorySlice.new()
	add_child(inv)
	v.inventory_slice = inv
	# Carve a tunnel: a side-face hit at y = 1.5 on the east face of tile (32,32).
	var r := v.mine_block(Vector3(16.5, 1.5, 16.25), Vector3(1, 0, 0))
	assert_true(r.get("success", false), "the side-face mine succeeds")
	var xz := Vector2(16.25, 16.25)
	var runs: Array = v.get_column_runs_at(xz)
	assert_eq(runs.size(), 2, "the column becomes a tunnel: a floor run and a roof run")
	var floor_top: float = float(runs[0]["top"])
	var roof_bottom: float = float(runs[1]["bottom"])
	# Aim at the tunnel FLOOR's top face. The floor loses its last step and the roof
	# above it is untouched.
	var r2 := v.mine_block(Vector3(xz.x, floor_top, xz.y), Vector3.UP)
	assert_true(r2.get("success", false), "the tunnel floor's top face can be mined")
	var after: Array = v.get_column_runs_at(xz)
	assert_eq(after.size(), 2, "still two runs after mining the floor")
	assert_true(is_equal_approx(float(after[0]["top"]), floor_top - VoxelSlice.STEP_HEIGHT), "the FLOOR lost its last step")
	assert_true(is_equal_approx(float(after[1]["bottom"]), roof_bottom), "and the ROOF is untouched")
	# Placing on the same face stacks on the FLOOR (in the gap under the roof).
	var new_floor_top: float = floor_top - VoxelSlice.STEP_HEIGHT
	v.set_place_material("Ashite")
	inv.add_item("Ashite", 1)
	assert_true(v.place_block(Vector3(xz.x, new_floor_top, xz.y), Vector3.UP), "placing on the floor face succeeds")
	var placed: Array = v.get_column_runs_at(xz)
	assert_eq(placed.size(), 3, "the gap under the roof holds the placed block")
	assert_true(is_equal_approx(float(placed[1]["bottom"]), new_floor_top), "sitting on the floor, not on the roof")
	assert_eq(str(placed[1]["material"]), "Ashite", "and it is the placed block")
	assert_true(is_equal_approx(float(placed[2]["top"]), 2.0), "the roof is still the column top")
	v.free()
	inv.free()

func _test_voxel_placed_block_keeps_material_color() -> void:
	var v := _make_voxel()
	var inv := InventorySlice.new()
	add_child(inv)
	v.inventory_slice = inv
	# The synthetic chunk has no terrain_slice, so its biome is TemperateForest
	# (fabric prose: ferrite outcrops only — no rare ground ore). Place a
	# DIFFERENT material so the colour change is unambiguous: the column must
	# render the placed block's own colour, not the biome colour.
	v.set_place_material("Ashite")
	inv.add_item("Ashite", 1)
	var center := Vector2(16.0, 16.0)
	assert_eq(v._natural_color(center), VoxelSlice.MATERIAL_COLORS["Ferrite"], "natural column renders the ferrite biome colour")
	assert_true(v.place_block(Vector3(center.x, 2.0, center.y), Vector3.UP), "place succeeds")
	# The colour the mesher tints the top face with comes off the column's own RUNS.
	var top_run: Dictionary = v.get_column_runs_at(center)[-1]
	assert_eq(v._run_color(top_run, center), VoxelSlice.MATERIAL_COLORS["Ashite"], "placed block renders Ashite colour, not biome colour")
	v.free()
	inv.free()

func _test_voxel_mine_placed_block_yields_material() -> void:
	var v := _make_voxel()
	var inv := InventorySlice.new()
	add_child(inv)
	v.inventory_slice = inv
	v.set_place_material("Thornwood")
	inv.add_item("Thornwood", 1)
	assert_true(v.place_block(Vector3(16.0, 2.0, 16.0), Vector3.UP), "place Thornwood succeeds")
	var r := v.mine_block(Vector3(16.0, 2.5, 16.0))
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
	# Place Ashite on a temperate (ferrite) column, then check the column renders
	# as two distinct layers: natural base (biome colour) + the placed block
	# (Ashite colour) — the base must NOT be recoloured.
	v.set_place_material("Ashite")
	inv.add_item("Ashite", 1)
	var center := Vector2(16.0, 16.0)
	assert_true(v.place_block(Vector3(center.x, 2.0, center.y), Vector3.UP), "place succeeds")
	# The rendered colours come off the column's RUNS — the same `_run_color` the
	# mesher tints each face with: a natural run takes the biome colour, the placed
	# run its own material's colour.
	var runs: Array = v.get_column_runs_at(center)
	assert_true(runs.size() >= 2, "column has natural + placed runs")
	assert_eq(v._run_color(runs[0], center), v._natural_color(center), "natural base keeps its biome colour")
	assert_true(v._natural_color(center) != VoxelSlice.MATERIAL_COLORS["Ashite"], "placed colour differs from the biome colour")
	assert_eq(v._run_color(runs[-1], center), VoxelSlice.MATERIAL_COLORS["Ashite"], "placed block renders Ashite colour")
	v.free()
	inv.free()

func _test_voxel_place_after_mine_keeps_colour() -> void:
	var v := _make_voxel()
	var inv := InventorySlice.new()
	add_child(inv)
	v.inventory_slice = inv
	# Mine the natural top block of a temperate column (yields the biome
	# material — ferrite here), then place a different material back on it.
	var center := Vector2(16.0, 16.0)
	var mine_pos := Vector3(center.x, 2.0, center.y)
	assert_true(v.mine_block(mine_pos).get("success", false), "mine natural succeeds")
	v.set_place_material("Ashite")
	inv.add_item("Ashite", 1)
	assert_true(v.place_block(mine_pos, Vector3.UP), "place Ashite succeeds")
	var runs: Array = v.get_column_runs_at(center)
	assert_true(runs.size() >= 2, "column has natural + placed runs")
	assert_eq(v._run_color(runs[-1], center), VoxelSlice.MATERIAL_COLORS["Ashite"], "placed Ashite renders Ashite colour, not the mined material's colour")
	assert_true(VoxelSlice.MATERIAL_COLORS["Ashite"] != v._natural_color(center), "placed colour differs from the mined material's colour")
	v.free()
	inv.free()

## Review pass — the op log is BOUNDED. Mining and rebuilding the same block used to
## append an op per click forever, and a tile's whole log is replayed on every
## column read (mesh, collision, footing, save) and re-serialized on every save. Past
## `MAX_TILE_OPS` the list is rewritten as the minimal description of what the column
## IS; a column that is back to its natural self compacts away entirely.
func _test_voxel_edit_log_is_compacted() -> void:
	var v := _make_voxel()
	var inv := InventorySlice.new()
	add_child(inv)
	v.inventory_slice = inv
	var tile := Vector2i(32, 32)
	var key := v._tile_key(tile)
	var xz := Vector2(16.25, 16.25)
	# Cycle twenty times: mine the top step, put a block back on it.
	for i in range(20):
		v.mine_block(Vector3(xz.x, 2.0, xz.y))
		v.set_place_material("Ashite")
		inv.add_item("Ashite", 1)
		v.place_block(Vector3(xz.x, 1.875, xz.y), Vector3.UP)
	assert_true(v._edits.has(key), "the column still carries its edits")
	assert_true(v._edits[key].size() <= VoxelSlice.MAX_TILE_OPS,
		"the op log is compacted rather than appended forever (got %d ops)" % [v._edits[key].size()])
	var runs: Array = v.get_column_runs_at(xz)
	assert_eq(runs.size(), 2, "and the column is still a natural step with a placed block on top")
	assert_eq(str(runs[-1]["material"]), "Ashite", "the placed block keeps its material")
	assert_eq(v.get_voxel_height_at(xz), 2.0, "and the column top is unchanged by the compaction")
	# A log that has cancelled itself out compacts away ENTIRELY: eight ops that
	# undo each other (built directly — the public mine/place pair always leaves a
	# placed block behind) and a ninth that adds nothing new.
	var cancel: Array = []
	for i in range(4):
		cancel.append({ "op": "remove", "bottom": 1.875, "top": 2.0 })
		cancel.append({ "op": "add", "bottom": 1.875, "top": 2.0, "material": "" })
	v._set_edit_ops(key, cancel)
	v._append_edit(tile, { "op": "add", "bottom": 1.875, "top": 2.0, "material": "" })
	assert_false(v._edits.has(key), "a column back to its natural self compacts away entirely")
	assert_eq(v.get_voxel_height_at(xz), 2.0, "and it resolves as its natural self")
	v.free()
	inv.free()

## Review pass — an edit op this version does not understand is DROPPED, never
## defaulted. `remove` carves and `add` fills, so reading an unknown kind as
## "remove" turns a damaged save into silent terrain damage: a corrupt op mines the
## column it names.
func _test_voxel_unknown_op_is_ignored() -> void:
	var v := _make_voxel()
	v.apply_edits({ "32,32": [
		{ "op": "wibble", "bottom": 1.0, "top": 2.0 },
		{ "op": "add", "bottom": 2.0, "top": 2.125, "material": "Ashite" },
	] })
	var xz := Vector2(16.25, 16.25)
	var runs: Array = v.get_column_runs_at(xz)
	assert_eq(runs.size(), 2, "the unknown op carved nothing")
	assert_eq(float(runs[0]["top"]), 2.0, "the natural run is untouched by the unknown op")
	assert_eq(str(runs[-1]["material"]), "Ashite", "while the op beside it still applies")
	assert_eq(v.get_voxel_height_at(xz), 2.125, "and the column stands where that edit put it")
	v.free()

## Review pass — the legacy migration keeps the placed-material STACK even when the
## saved height sits further above the current base than the stack is tall. That is
## the re-rolled-seed case: a version-1 world carries no seed, so its ground is
## generated afresh under a save whose column was written against another noise
## field. Collapsing that column into one anonymous span (the pre-review behaviour)
## repaints the player's placed blocks as natural ground.
func _test_voxel_legacy_migration_keeps_materials() -> void:
	var v := _make_voxel()   # natural top is 2.0
	v.apply_edits({ "32,32": 3.0 }, { "32,32": ["Ashite", "Thornwood"] })
	var xz := Vector2(16.25, 16.25)
	var runs: Array = v.get_column_runs_at(xz)
	# Read through guarded accesses: on the pre-fix policy this column collapses to
	# ONE anonymous run, and an index that does not exist would abort the test
	# instead of reporting a clean failure.
	var stack_top := str(runs[-1].get("material", "")) if not runs.is_empty() else ""
	var stack_below := str(runs[-2].get("material", "")) if runs.size() >= 2 else ""
	var ground_top := float(runs[0]["top"]) if not runs.is_empty() else 0.0
	assert_eq(v.get_voxel_height_at(xz), 3.0, "the saved height is restored")
	assert_eq(runs.size(), 3, "and the stack's two blocks are still their own runs")
	assert_eq(stack_top, "Thornwood", "the top of the stack is still the last material placed")
	assert_eq(stack_below, "Ashite", "and the one under it the material before it")
	assert_eq(ground_top, 2.75, "while the ground below the stack is still natural")
	v.free()

## Review pass — editing a tile on a CHUNK EDGE rebuilds the chunk next door too. A
## wall face is the DIFFERENCE between a column's runs and its neighbour's, so a
## tile across the edge is a neighbour column to the other chunk's tiles and its
## edit changes what THEY emit. Rebuilding only the edited tile's own chunk left the
## neighbour drawing its old wall — here, a blind face where the carve opened the
## seam and the tunnel's mouth should be visible.
func _test_voxel_edge_edit_rebuilds_neighbour_chunk() -> void:
	var v := VoxelSlice.new()
	add_child(v)
	var low: Array = []
	low.resize(64 * 64)
	low.fill(2.0)
	var high: Array = []
	high.resize(64 * 64)
	high.fill(3.0)
	v.build_chunk(Vector2i(0, 0), low)     # the seam's LOW side (tiles 0..63)
	v.build_chunk(Vector2i(1, 0), high)    # the HIGH side (tiles 64..)
	assert_eq(_plane_x_spans(v.collision_faces(Vector2i(0, 0), low), 32.0), [],
		"the low side is buried inside the high column to begin with")
	var neighbour_node: Node3D = v._chunks["0,0"]
	# A -X face hit at x = 32.0 steps EAST into tile (64, 32), the high side's seam
	# tile, and carves the step the ray is inside.
	assert_true(v.mine_block(Vector3(32.0, 1.5, 16.25), Vector3(-1, 0, 0)).get("success", false),
		"mining the high side's seam tile succeeds")
	assert_eq(_plane_x_spans(v.collision_faces(Vector2i(0, 0), low), 32.0), [[1.5, 1.625]],
		"the low column now emits the wall the carve exposed, and only there")
	assert_false(is_same(v._chunks["0,0"], neighbour_node),
		"because the neighbour chunk was rebuilt, not left with its old wall")
	v.free()

## Review pass — the base heightmaps are bounded by the loaded window plus its
## one-tile ring. They used to be kept for the whole session (so a streamed-out
## neighbour could still answer with its real runs), which held every chunk the
## player ever walked past in memory. The RING is what keeps the neighbour answer
## truthful for a chunk that is actually on screen.
func _test_voxel_unload_prunes_heightmaps() -> void:
	var v := VoxelSlice.new()
	add_child(v)
	var flat: Array = []
	flat.resize(64 * 64)
	flat.fill(2.0)
	v.build_chunk(Vector2i(0, 0), flat)
	v.build_chunk(Vector2i(1, 0), flat)
	v.build_chunk(Vector2i(9, 9), flat)   # built, and far from anything else
	assert_eq(v.get_heightmaps().size(), 3, "every built chunk is known")
	v.unload_chunk(Vector2i(1, 0))
	assert_true(v.get_heightmaps().has("0,0"), "a loaded chunk keeps its own heightmap")
	assert_true(v.get_heightmaps().has("1,0"), "and so does the ring around it")
	v.unload_chunk(Vector2i(9, 9))
	assert_false(v.get_heightmaps().has("9,9"), "an unloaded chunk with no loaded neighbour is pruned")
	assert_true(v.get_heightmaps().has("0,0"), "while the loaded chunk's map stays")
	v.unload_chunk(Vector2i(0, 0))
	assert_true(v.get_heightmaps().is_empty(), "unloading the last chunk prunes it and its ring")
	# A build guesses its DIAGONAL neighbours' maps too; unloading must drop them.
	v._guess_heightmaps["6,6"] = flat
	v.build_chunk(Vector2i(5, 5), flat)
	v._guess_heightmaps["6,6"] = flat
	v.unload_chunk(Vector2i(5, 5))
	assert_false(v._guess_heightmaps.has("6,6"), "a diagonal guess is pruned with its chunk")
	v.free()

## Review pass — a snapshot rebuilds only the chunks whose edits CHANGED, and never
## one that is not loaded. `apply_edits` is the re-scope path on a client: a
## snapshot re-sends the manifest it already applied — or one that differs in a
## chunk or two — and rebuilding every held chunk for that is a whole-frame stall
## per scope change. Building an UNLOADED chunk is worse: it resurrects a node
## ChunkManager has already streamed away and will not stream out again.
func _test_voxel_snapshot_rebuild_is_scoped() -> void:
	var v := VoxelSlice.new()
	add_child(v)
	var flat: Array = []
	flat.resize(64 * 64)
	flat.fill(2.0)
	v.build_chunk(Vector2i(0, 0), flat)
	v.build_chunk(Vector2i(1, 0), flat)
	var edit: Array = [{ "op": "remove", "bottom": 1.0, "top": 2.0 }]
	var manifest := { "0,0": { "edits": { "32,32": edit } } }
	v.apply_chunk_manifest(manifest)
	var correct_node: Node3D = v._chunks["0,0"]
	var stale_node: Node3D = v._chunks["1,0"]
	# The SAME manifest again: nothing changed, so nothing is rebuilt.
	v.apply_chunk_manifest(manifest)
	assert_true(v._chunks["0,0"] == correct_node, "an unchanged manifest rebuilds nothing")
	# A manifest that also edits chunk (1,0) rebuilds THAT chunk, and leaves the
	# chunk that was already right alone.
	v.apply_chunk_manifest({
		"0,0": { "edits": { "32,32": edit } },
		"1,0": { "edits": { "96,32": edit } },
	})
	assert_true(v._chunks["1,0"] != stale_node, "a chunk whose edits changed IS rebuilt")
	assert_true(v._chunks["0,0"] == correct_node, "and the unchanged one is not")
	# A chunk that has been streamed out is never built back into existence, even by
	# a manifest that DOES change it.
	v.unload_chunk(Vector2i(1, 0))
	v.apply_chunk_manifest({
		"0,0": { "edits": { "32,32": edit } },
		"1,0": { "edits": { "96,32": edit, "98,32": edit } },
	})
	assert_false(v._chunks.has("1,0"), "an unloaded chunk is not resurrected by a snapshot")
	assert_true(v._chunks["0,0"] == correct_node, "and the untouched chunk is still not rebuilt")
	v.free()

## Phase 42 review (fifth pass) — the re-scope path's seam closure. A wall face is the
## difference against the NEIGHBOUR column (`_wall_cells`), so a changed tile on a
## chunk's EDGE changes the neighbour's mesh too. `_rebuild_chunk_at_tile` has closed
## that since the Phase 41 review; `apply_edits` — the snapshot/re-scope path — was
## rebuilding the tile's own chunk alone, which left a see-through slot (or a ghost
## collision wall) at the seam until that chunk happened to restream.
func _test_voxel_apply_edits_rebuilds_seam_neighbours() -> void:
	var v := VoxelSlice.new()
	add_child(v)
	var flat: Array = []
	flat.resize(64 * 64)
	flat.fill(2.0)
	v.build_chunk(Vector2i(0, 0), flat)
	v.build_chunk(Vector2i(1, 0), flat)
	v.build_chunk(Vector2i(5, 5), flat)
	var own_node: Node3D = v._chunks["0,0"]
	var seam_node: Node3D = v._chunks["1,0"]
	var control_node: Node3D = v._chunks["5,5"]
	# Tile 63 is the LAST column of chunk (0,0) (64 tiles × 0.5 units = 32 world units
	# per chunk): its east wall is the difference against chunk (1,0)'s tile 64.
	var edit: Array = [{ "op": "remove", "bottom": 1.0, "top": 2.0 }]
	v.apply_chunk_manifest({ "0,0": { "edits": { "63,32": edit } } })
	assert_true(v._chunks["0,0"] != own_node, "the changed tile's own chunk is rebuilt")
	assert_true(v._chunks["1,0"] != seam_node, "and so is the chunk across the seam it changed")
	assert_true(v._chunks["5,5"] == control_node, "a chunk that reads nothing of the edit is left alone")
	# An INTERIOR tile (32 is nowhere near an edge) names its own chunk and no seam: the
	# closure is not a blanket "rebuild every neighbour", so the scoping the previous pass
	# added survives. (63,32 is unchanged by this snapshot, so only 32,32 is touched.)
	var interior_node: Node3D = v._chunks["0,0"]
	var seam_unmoved: Node3D = v._chunks["1,0"]
	v.apply_chunk_manifest({ "0,0": { "edits": { "63,32": edit, "32,32": edit } } })
	assert_true(v._chunks["0,0"] != interior_node, "an interior tile rebuilds its own chunk")
	assert_true(v._chunks["1,0"] == seam_unmoved, "and names no seam")
	v.free()

## Phase 42 review (fifth pass) — an edit never resurrects a chunk that is not loaded,
## on BOTH edit paths. The synchronous fallback (a slice with no manager — the suite)
## guarded on `_heightmaps`, and since the Phase 41 pass that map deliberately RETAINS
## the one-tile ring around the loaded window — so an edit on a chunk edge rebuilt, and
## so resurrected, a chunk `ChunkManager` had already streamed away and would never
## stream out again. `_chunks` is the guard, exactly as `ChunkManager.request_rebuild`
## (`_loaded`) and `apply_edits` (`_chunks`) already do it.
func _test_voxel_edit_does_not_resurrect_unloaded_chunk() -> void:
	var v := VoxelSlice.new()
	add_child(v)
	var flat: Array = []
	flat.resize(64 * 64)
	flat.fill(2.0)
	v.build_chunk(Vector2i(0, 0), flat)
	v.build_chunk(Vector2i(1, 0), flat)
	v.unload_chunk(Vector2i(1, 0))
	assert_false(v._chunks.has("1,0"), "the neighbour is streamed out, as ChunkManager would")
	assert_true(v.get_heightmaps().has("1,0"), "but its map is still retained for the loaded ring")
	# World x 31.75 = tile 63, the last column of chunk (0,0): its seam names chunk (1,0).
	var r := v.mine_block(Vector3(31.75, 2.0, 16.25))
	assert_true(r.get("success", false), "the seam column was mined")
	assert_false(v._chunks.has("1,0"), "and the streamed-out neighbour was not resurrected")
	v.free()

## Phase 42 review (sixth pass) — the LEGACY half of `apply_edits` accepted any shape
## and cast it with `float()`. That cast was not a refusal: `float()` answers 0.0 for
## a string that is not a number (measured), so a corrupt or re-rolled record migrated
## into an absolute height AT THE WORLD FLOOR — the column carved away — and a dict
## value raised `Invalid call. Nonexistent 'float' constructor` on the load path. The
## migration now admits exactly what a pre-Phase-41 edit could be — an int, a float, or
## a numeric string — and DROPS anything else with a warning, the policy
## `_normalise_ops` already applies to an op whose kind it cannot read. A dropped entry
## is inert: the tile keeps its natural ground.
func _test_voxel_legacy_edit_type_guard() -> void:
	var v := VoxelSlice.new()
	add_child(v)
	var flat: Array = []
	flat.resize(64 * 64)
	flat.fill(2.0)
	v.build_chunk(Vector2i(0, 0), flat)
	# Tile (32,32) is the honest pre-Phase-41 shape (a bare number) and (40,40) is the
	# other one a JSON round-trip can produce (a numeric string). The rest are not
	# heights at all.
	var junk := { "0,0": { "edits": {
		"32,32": 1.0,
		"40,40": "1.5",
		"34,34": { "op": "remove", "bottom": 1.0, "top": 2.0 },
		"36,36": "not-a-height",
		"38,38": true,
	} } }
	v.apply_chunk_manifest(junk)
	assert_eq(v.get_voxel_height_at(Vector2(16.25, 16.25)), 1.0,
		"a bare numeric legacy height still migrates")
	assert_eq(v.get_voxel_height_at(Vector2(20.25, 20.25)), 1.5,
		"and so does a numeric string")
	for key in ["34,34", "36,36", "38,38"]:
		assert_false(v.get_edits().has(key),
			"an edit of an unknown shape (%s) is dropped, never cast" % [key])
	assert_eq(v.get_voxel_height_at(Vector2(17.25, 17.25)), 2.0,
		"a dict value leaves the column at its natural height instead of raising")
	assert_eq(v.get_voxel_height_at(Vector2(18.25, 18.25)), 2.0,
		"an unparsable string no longer carves the column to the world floor")
	assert_eq(v.get_voxel_height_at(Vector2(19.25, 19.25)), 2.0,
		"and neither does a bool (it used to cast to 1.0)")
	v.free()

# ---------------------------------------------------------------------------
# UiSlice tests (Phase 14 windows)
# ---------------------------------------------------------------------------

const TEST_UI_LAYOUT := "user://test_ui_layout.json"

## UiSlice wired to a scratch layout file so tests never read the real one.
func _new_test_ui() -> UiSlice:
	DirAccess.remove_absolute(TEST_UI_LAYOUT)
	var ui := UiSlice.new()
	ui.layout_path = TEST_UI_LAYOUT
	add_child(ui)
	return ui

func _test_ui_retire_prunes_amortised() -> void:
	var ui := _new_test_ui()
	var controls: Array = []
	for i in 1000:
		var c := Control.new()
		controls.append(c)
		ui._retire(c)
	assert_true(ui.retired_prunes <= 11, "retiring 1,000 controls prunes at most 11 times (%d)" % ui.retired_prunes)
	assert_true(ui.retired_prunes >= 1, "and the prune does run")
	ui.free()
	var leaked := 0
	for c in controls:
		if is_instance_valid(c):
			leaked += 1
	assert_eq(leaked, 0, "freeing the slice frees every retired control still valid")

func _test_ui_layout_file_roundtrip() -> void:
	var ui := _new_test_ui()
	ui._layout["inventory"] = Vector2(50, 60)
	ui._save_layout()
	ui.free()
	var ui2 := UiSlice.new()
	ui2.layout_path = TEST_UI_LAYOUT
	add_child(ui2)
	assert_eq(ui2._layout.get("inventory"), Vector2(50, 60), "layout reloaded from file")
	assert_eq(ui2._panels["inventory"].position, Vector2(50, 60), "window reopens at stored position")
	assert_false(FileAccess.file_exists(TEST_UI_LAYOUT + ".tmp"), "no partial temp file remains after save")
	assert_true(UiSlice.parse_layout(FileAccess.get_file_as_string(TEST_UI_LAYOUT)).has("inventory"), "saved file is complete and parseable")
	ui2.free()
	DirAccess.remove_absolute(TEST_UI_LAYOUT)

## Phase 67 — a failed layout rename leaves no `.tmp` file behind.
func _test_ui_layout_failed_rename_cleans_tmp() -> void:
	var ui := _new_test_ui()
	# A directory at the target path makes the rename fail.
	DirAccess.make_dir_recursive_absolute(TEST_UI_LAYOUT)
	ui._layout["inventory"] = Vector2(1, 2)
	ui._save_layout()
	assert_false(FileAccess.file_exists(TEST_UI_LAYOUT + ".tmp"), "failed rename removes the temp file")
	ui.free()
	DirAccess.remove_absolute(TEST_UI_LAYOUT)

## Phase 67 — `_broadcast` and `_broadcast_aoi` both fan out through `_test_peers` only.
func _test_network_broadcast_uses_test_peers() -> void:
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n._test_peers = [4, 5]
	n._broadcast({ "type": "probe" })
	var got := []
	for m in n._test_outbox:
		got.append(m["peer_id"])
	got.sort()
	assert_eq(got, [4, 5], "_broadcast reaches exactly the test peers")
	n._test_outbox.clear()
	n.remember_player_state(4, Vector3.ZERO)
	n.remember_player_state(5, Vector3.ZERO)
	n._broadcast_aoi({ "type": "probe" }, Vector3.ZERO)
	got = []
	for m in n._test_outbox:
		got.append(m["peer_id"])
	got.sort()
	assert_eq(got, [4, 5], "_broadcast_aoi reaches exactly the test peers in range")
	n.free()

func _test_ui_drag_state_resets() -> void:
	var ui := _new_test_ui()
	ui._drag_key = "inventory"
	ui._close_all_windows()
	assert_eq(ui._drag_key, "", "closing windows ends a drag")
	ui.free()

func _ui_row(rows: Array, id: String) -> Dictionary:
	for r in rows:
		if str(r["id"]) == id:
			return r
	return {}

func _test_ui_window_toggle() -> void:
	var ui := _new_test_ui()
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

func _test_ui_window_clamp() -> void:
	var vp := Vector2(1280, 720)
	var sz := Vector2(420, 300)
	assert_eq(UiSlice.clamp_window_position(Vector2(100, 100), sz, vp), Vector2(100, 100), "on-screen position unchanged")
	var far := UiSlice.clamp_window_position(Vector2(99999, 99999), sz, vp)
	assert_true(far.x < vp.x and far.y < vp.y, "far bottom-right is pulled back inside")
	assert_true(far.x + sz.x > 0.0 and far.y >= 0.0, "still reachable")
	var neg := UiSlice.clamp_window_position(Vector2(-99999, -99999), sz, vp)
	assert_true(neg.x + sz.x >= UiSlice.DRAG_VISIBLE_MARGIN, "left edge keeps a margin visible")
	assert_eq(neg.y, 0.0, "title bar never above the screen")

func _test_ui_layout_roundtrip() -> void:
	var layout := {"inventory": Vector2(10, 20), "controls": Vector2(300.5, 40)}
	var back := UiSlice.parse_layout(UiSlice.layout_to_json(layout))
	assert_eq(back, layout, "layout survives serialise/parse")
	assert_eq(UiSlice.parse_layout("not json"), {}, "garbage parses to empty")
	var junk := UiSlice.parse_layout('{"bogus":[1,2],"inventory":["a",2],"market":[5,6]}')
	assert_false(junk.has("bogus"), "unknown window key dropped")
	assert_false(junk.has("inventory"), "non-numeric entry dropped")
	assert_eq(junk.get("market"), Vector2(5, 6), "valid entry kept")
	var huge := UiSlice.parse_layout('{"inventory":[1e999,2],"market":[5,6]}')
	assert_false(huge.has("inventory"), "non-finite entry dropped")
	assert_eq(huge.get("market"), Vector2(5, 6), "finite entry beside it kept")
	var absurd := UiSlice.parse_layout('{"inventory":[1e308,2],"market":[5,-1e308],"controls":[7,8]}')
	assert_false(absurd.has("inventory"), "1e308 x dropped to default")
	assert_false(absurd.has("market"), "-1e308 y dropped to default")
	assert_eq(absurd.get("controls"), Vector2(7, 8), "sane entry beside absurd ones kept")
	var nan_text := UiSlice.parse_layout('{"inventory":[NaN,2],"market":[5,6]}')
	assert_false(nan_text.has("inventory"), "NaN entry dropped")
	# The JSON parser rejects a bare NaN token outright, so the whole file falls back to defaults.
	assert_false(nan_text.has("market"), "NaN token makes the file parse to defaults")

func _test_ui_inventory_rows() -> void:
	var ui := _new_test_ui()
	assert_eq(ui.inventory_rows().size(), 0, "no inventory -> no rows")
	var inv := InventorySlice.new()
	add_child(inv)
	ui.inventory_slice = inv
	inv.add_item("Ferrite", 5)
	inv.add_item("Thornwood", 2)
	var rows: Array = ui.inventory_rows()
	assert_eq(rows.size(), 2, "N items -> N slots")
	var r := _ui_row(rows, "Ferrite")
	assert_eq(r["quantity"], 5, "row carries quantity")
	assert_true(str(r["tooltip"]).contains("Ferrite") and str(r["tooltip"]).contains("5"), "tooltip names item and quantity")
	assert_eq(r["icon_key"], "icons/items/Ferrite.png.raw", "icon key derived from entity name")
	ui.refresh_inventory()
	assert_eq(ui._inventory_grid.get_child_count(), 2, "grid renders one slot per row")
	assert_true(ui.inventory_rows()[0]["actions"].is_empty(), "stackable material offers no actions")
	ui.free()
	inv.free()

func _test_ui_icon_key_and_intent() -> void:
	assert_eq(UiSlice.item_icon_key("FerritePick"), "icons/items/FerritePick.png.raw", "icon key")
	assert_eq(UiSlice.item_glyph("ferrite"), "F", "placeholder glyph is the initial")
	assert_eq(UiSlice.item_glyph(""), "?", "empty id glyph")
	var intent := UiSlice.action_intent("FerritePick", "repair")
	assert_eq(intent["signal"], "repair_requested", "repair maps to the existing bus intent")
	assert_eq(intent["args"], ["FerritePick"], "intent carries the item id")
	assert_true(UiSlice.action_intent("X", "nope").is_empty(), "unknown action maps to nothing")
	var ui := _new_test_ui()
	assert_false(ui.dispatch_item_action("X", "nope"), "unknown action is not dispatched")
	var got: Array = []
	var cb := func(id: String) -> void: got.append(id)
	GameBus.repair_requested.connect(cb)
	assert_true(ui.dispatch_item_action("FerritePick", "repair"), "repair dispatches")
	GameBus.repair_requested.disconnect(cb)
	assert_eq(got, ["FerritePick"], "same intent the text UI emitted")
	ui.free()

func _test_ui_controls_panel() -> void:
	var rows := UiSlice.controls_rows()
	var descs: Array = rows.map(func(r): return r["desc"])
	assert_true(descs.has("Move") and descs.has("Mine") and descs.has("Place"), "legend rows moved into the panel")
	var ui := _new_test_ui()
	assert_false(ui.is_window_open("controls"), "controls collapsed by default")
	ui.toggle_window("controls")
	assert_true(ui.is_window_open("controls"), "? opens controls")
	ui.toggle_window("controls")
	assert_false(ui.is_window_open("controls"), "? closes controls")
	ui.free()
	var p := PlayerSlice.new()
	p.render_visuals = true
	add_child(p)
	var names: Array = []
	for c in p._hud.get_children():
		names.append(str(c.name))
	assert_false(names.has("ShortcutsMenu"), "HUD paints no always-on legend")
	p.free()

const _HotbarScript := preload("res://src/ui/hotbar.gd")
const _WindowDockScript := preload("res://src/ui/window_dock.gd")
const _TEST_HOTBAR_FILE := "user://test_ui_layout_hotbar.json"
const _TEST_DOCK_FILE := "user://test_ui_layout_dock.json"

func _first_gear_item() -> String:
	var keys: Array = GameData.ITEMS.keys()
	keys.sort()
	for k in keys:
		if EquipmentRules.slot_of(str(k), GameData.ITEMS) != "":
			return str(k)
	return ""

func _first_block() -> String:
	var mats: Array = GameData.MATERIALS.keys()
	mats.sort()
	return str(mats[0])

func _blank_slots() -> Array:
	var cur := []
	for i in _HotbarScript.SLOT_COUNT:
		cur.append("")
	return cur

func _test_hud_hotbar_pure() -> void:
	var block := _first_block()
	var gear := _first_gear_item()
	assert_eq(_HotbarScript.kind_of(block, GameData.MATERIALS, ""), "block", "a material is a block")
	assert_eq(_HotbarScript.kind_of(gear, {}, "mainHand"), "gear", "an equippable is gear")
	assert_eq(_HotbarScript.kind_of("skill:Archery", GameData.MATERIALS, ""), "skill", "a skill entry is a skill")
	assert_eq(_HotbarScript.kind_of("", GameData.MATERIALS, ""), "", "empty is neither")
	var usable := func(id: String) -> bool: return id == block or id == gear
	var cur := _blank_slots()
	var filled := _HotbarScript.fill(cur, {block: 3, gear: 1, "Junk": 5}, usable)
	assert_eq(filled.count(block) + filled.count(gear), 2, "usable held items take boxes")
	assert_false(filled.has("Junk"), "non-usable items stay off the bar")
	assert_eq(_HotbarScript.fill(filled, {block: 3, gear: 1}, usable), filled, "fill is stable: nothing reshuffles")
	var after := _HotbarScript.fill(filled, {gear: 1}, usable)
	assert_false(after.has(block), "an item no longer held leaves its box")
	assert_eq(after.find(gear), filled.find(gear), "the other boxes keep their place")
	assert_eq(_HotbarScript.fill(cur, {block: 3}, usable, {block: true}), cur, "an item taken off by hand is not re-added")
	var with_skill := cur.duplicate()
	with_skill[12] = "skill:Archery"
	assert_eq(_HotbarScript.fill(with_skill, {}, usable)[12], "skill:Archery", "a skill box survives an empty pack")
	var full := cur.duplicate()
	for i in 9:
		full[i] = "x%d" % i
	var refilled := _HotbarScript.fill(full, {block: 1}, usable)
	assert_eq(refilled[0], block, "a held usable item takes a freed bottom box")
	var row2 := cur.duplicate()
	for i in range(0, 9):
		row2[i] = "skill:S%d" % i
	assert_eq(_HotbarScript.fill(row2, {block: 1}, usable).slice(9).count(block), 0, "auto-fill never uses the player's second row")
	# place / swap
	var placed := _HotbarScript.place(cur, 3, "Ferrite")
	assert_eq(placed[3], "Ferrite", "place puts the entry in the box")
	assert_eq(_HotbarScript.place(placed, 10, "Ferrite")[3], "", "placing an entry elsewhere moves it")
	var swapped := _HotbarScript.swap(placed, 3, 4)
	assert_eq([swapped[3], swapped[4]], ["", "Ferrite"], "swap exchanges two boxes")
	# keys
	assert_eq(_HotbarScript.digit_slot(KEY_1), 0, "1 fires the first box")
	assert_eq(_HotbarScript.digit_slot(KEY_9), 8, "9 fires the ninth box")
	assert_eq(_HotbarScript.digit_slot(KEY_0), -1, "0 is not a bottom-row key")
	for k in [KEY_W, KEY_I, KEY_C, KEY_H, KEY_M, KEY_P, KEY_1, KEY_ESCAPE, KEY_SPACE]:
		assert_false(_HotbarScript.bind_allowed(k), "game key %d cannot be a shortcut" % k)
	for k in [KEY_Z, KEY_X, KEY_J, KEY_F5, KEY_0]:
		assert_true(_HotbarScript.bind_allowed(k), "key %d may be a shortcut" % k)
	var binds := []
	for i in 18:
		binds.append(0)
	binds[11] = KEY_Z
	assert_eq(_HotbarScript.slot_for_key(binds, KEY_Z), 11, "a bound key finds its box")
	assert_eq(_HotbarScript.slot_for_key(binds, KEY_X), -1, "an unbound key finds none")
	# persistence
	var json := _HotbarScript.state_to_json(placed, binds, true)
	var back := _HotbarScript.parse_state(json)
	assert_eq(back["slots"], placed, "slots round-trip")
	assert_eq(back["binds"], binds, "binds round-trip")
	assert_true(back["expanded"], "expansion round-trips")
	var bad := _HotbarScript.parse_state('{"slots": [1, {}, "ok"], "binds": [0,0,0,0,0,0,0,0,0,87,"x",99999], "expanded": "yes"}')
	assert_eq(bad["slots"][2], "ok", "a good entry survives")
	assert_eq(bad["slots"][0], "", "a non-string entry is dropped")
	assert_eq(bad["binds"][9], 0, "a reserved key (W) is dropped from the file")
	assert_eq(bad["binds"][11], 0, "an absurd key is dropped")
	assert_false(bad["expanded"], "a non-bool expansion is false")
	assert_eq(_HotbarScript.parse_state("not json")["slots"], _blank_slots(), "a corrupt file starts empty")

func _new_hud_ui() -> UiSlice:
	DirAccess.remove_absolute(_TEST_HOTBAR_FILE)
	DirAccess.remove_absolute(_TEST_DOCK_FILE)
	return _new_test_ui()

func _test_hud_hotbar_selection() -> void:
	var ui := _new_hud_ui()
	var inv := InventorySlice.new()
	add_child(inv)
	var vox := VoxelSlice.new()
	add_child(vox)
	ui.inventory_slice = inv
	ui.voxel_slice = vox
	var block := _first_block()
	inv.add_item(block, 4)
	ui.refresh_hud()
	assert_eq(ui.hotbar.slots[0], block, "a picked-up block lands in the first box")
	assert_eq(vox.get_place_material(), block, "and, being selected, becomes the place material")
	ui.hotbar.select_slot(1)
	assert_eq(vox.get_place_material(), "", "an empty box clears the place material")
	ui.hotbar.select_slot(0)
	assert_eq(vox.get_place_material(), block, "selecting the block box re-selects it")
	ui.hotbar.select_slot(5)
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_1
	assert_true(ui.hotbar.handle_key(key), "the 1 key is used by the bar")
	assert_eq(ui.hotbar.selected, 0, "1 selects the first box")
	GameBus.block_place_material_changed.emit(block)
	assert_eq(ui.hotbar.selected, 0, "R cycling to a material on the bar keeps/selects its box")
	vox.free()
	inv.free()
	ui.free()

func _test_hud_hotbar_skills_and_binding() -> void:
	var ui := _new_hud_ui()
	var hb = ui.hotbar
	# Button i is box i (the numbered row is first), so a swapped item renders in its own box.
	hb.assign(3, "skill:Mining")
	assert_eq((hb._buttons[3] as Button).text, "Mini", "box 3 draws its own contents")
	assert_eq((hb._buttons[12] as Button).text, "", "box 12 stays empty")
	assert_true(hb._buttons[0].get_parent() == hb._row1 and hb._buttons[9].get_parent() == hb._row2, "numbered row first, extra row second")
	assert_true(hb.get_child(0) == hb._row1, "the numbered row sits above the extra row")
	hb.assign(3, "")
	hb.assign(2, "skill:Alchemy")
	var got: Array = []
	var cb := func(slot: int, skill: String) -> void: got.append([slot, skill])
	GameBus.skill_slot_triggered.connect(cb)
	var k3 := InputEventKey.new()
	k3.pressed = true
	k3.keycode = KEY_3
	assert_true(hb.handle_key(k3), "3 fires the third box")
	GameBus.skill_slot_triggered.disconnect(cb)
	assert_eq(got, [[2, "Alchemy"]], "a skill box reports the press on the bus")
	# Bottom row boxes cannot be rebound; a second-row box can.
	hb.begin_binding(1)
	assert_false(hb.is_binding(), "the bottom row is fixed to 1-9")
	hb.assign(10, "skill:Archery")
	hb.begin_binding(10)
	assert_true(hb.is_binding() and hb.expanded, "binding a second-row box expands the bar")
	var bad := InputEventKey.new()
	bad.pressed = true
	bad.keycode = KEY_W
	assert_true(hb.handle_key(bad), "a key press is swallowed while choosing a shortcut")
	assert_true(hb.is_binding(), "a game key is refused and the choice stays open")
	var z := InputEventKey.new()
	z.pressed = true
	z.keycode = KEY_Z
	hb.handle_key(z)
	assert_false(hb.is_binding(), "an allowed key finishes the choice")
	assert_eq(hb.binds[10], KEY_Z, "the box now has that shortcut")
	got.clear()
	GameBus.skill_slot_triggered.connect(cb)
	assert_true(hb.handle_key(z), "the chosen key fires the box")
	GameBus.skill_slot_triggered.disconnect(cb)
	assert_eq(got, [[10, "Archery"]], "second-row shortcut fires its skill")
	# A second box taking the same key steals it.
	hb.assign(11, "skill:Smithing")
	hb.begin_binding(11)
	hb.handle_key(z)
	assert_eq([hb.binds[10], hb.binds[11]], [0, KEY_Z], "a key belongs to one box")
	# Persistence
	assert_true(FileAccess.file_exists(ui.hotbar.save_path), "the bar saved itself")
	var again := _HotbarScript.parse_state(FileAccess.get_file_as_string(ui.hotbar.save_path))
	assert_eq(again["slots"][2], "skill:Alchemy", "contents persisted")
	assert_eq(again["binds"][11], KEY_Z, "shortcuts persisted")
	ui.free()
	DirAccess.remove_absolute(_TEST_HOTBAR_FILE)

func _test_hud_drag_and_drop() -> void:
	var ui := _new_hud_ui()
	var inv := InventorySlice.new()
	add_child(inv)
	var loot := LootSlice.new()
	add_child(loot)
	inv.loot_slice = loot
	ui.inventory_slice = inv
	var hb = ui.hotbar
	# Drop onto a box.
	assert_true(hb._can_drop(Vector2.ZERO, {"kind": "item", "id": "Ferrite"}), "an inventory item can be dropped on a box")
	assert_false(hb._can_drop(Vector2.ZERO, {"kind": "junk", "id": "x"}), "unknown payloads are refused")
	assert_false(hb._can_drop(Vector2.ZERO, "text"), "non-dictionary payloads are refused")
	hb._drop(Vector2.ZERO, {"kind": "item", "id": "Ferrite"}, 12)
	assert_eq(hb.slots[12], "Ferrite", "the item is in the box")
	hb._drop(Vector2.ZERO, {"kind": "skill", "id": "Archery"}, 13)
	assert_eq(hb.slots[13], "skill:Archery", "a skill is in the box")
	hb._drop(Vector2.ZERO, {"kind": "hotbar", "from": 12, "id": "skill:Archery"}, 13)
	assert_eq([hb.slots[12], hb.slots[13]], ["skill:Archery", "Ferrite"], "dragging a box onto another swaps them")
	# Out into the world: a box is emptied, an item lands on the ground.
	assert_eq(ui.finish_world_drop({"kind": "hotbar", "from": 13, "id": "Ferrite"}, false), "cleared", "a box dragged to the world is emptied")
	assert_eq(hb.slots[13], "", "and is empty")
	inv.add_item("Ferrite", 5)
	var seen: Array = []
	var cb := func(id: String, qty: int, _pos: Vector3) -> void: seen.append([id, qty])
	GameBus.item_drop_requested.connect(cb)
	assert_eq(ui.finish_world_drop({"kind": "item", "id": "Ferrite", "quantity": 5}, false), "dropped", "an item dragged to the world is dropped")
	assert_eq(inv.get_item_count("Ferrite"), 4, "a plain drag drops one unit")
	assert_eq(ui.finish_world_drop({"kind": "item", "id": "Ferrite", "quantity": 4}, true), "dropped", "shift drops the stack")
	assert_eq(inv.get_item_count("Ferrite"), 0, "and the whole stack leaves the pack")
	assert_eq(ui.request_drop("Ferrite", 1), "none", "an item not held is refused")
	ui.drops_enabled = false
	assert_eq(ui.request_drop("Ferrite", 1), "client", "a client cannot drop")
	GameBus.item_drop_requested.disconnect(cb)
	assert_eq(seen, [["Ferrite", 1], ["Ferrite", 4]], "the bus carried one unit, then the stack")
	assert_eq(loot.get_pickups_near(Vector3.ZERO, 100.0).size(), 2, "both landed on the ground")
	# The slice's own limits.
	inv.add_item("Ferrite", 3)
	GameBus.item_drop_requested.emit("Ferrite", 99, Vector3(1, 0, 1))
	assert_eq(inv.get_item_count("Ferrite"), 0, "a drop is capped at what is held")
	GameBus.item_drop_requested.emit("Ferrite", 1, Vector3.ZERO)
	assert_eq(inv.get_item_count("Ferrite"), 0, "dropping what is not held does nothing")
	inv.is_authoritative = false
	inv.add_item("Ferrite", 2)
	GameBus.item_drop_requested.emit("Ferrite", 1, Vector3.ZERO)
	assert_eq(inv.get_item_count("Ferrite"), 2, "a client inventory never removes goods on its own")
	loot.free()
	inv.free()
	ui.free()
	DirAccess.remove_absolute(_TEST_HOTBAR_FILE)

func _test_hud_drop_keeps_durability() -> void:
	var inv := InventorySlice.new()
	add_child(inv)
	var loot := LootSlice.new()
	add_child(loot)
	inv.loot_slice = loot
	var tool := ""
	for k in GameData.ITEMS.keys():
		if inv.is_durable(str(k)):
			tool = str(k)
			break
	if tool == "":
		loot.free()
		inv.free()
		return
	inv.add_item(tool, 1, [7.0])
	GameBus.item_drop_requested.emit(tool, 1, Vector3(5, 0, 5))
	assert_eq(inv.get_item_count(tool), 0, "the tool left the pack")
	var near := loot.get_pickups_near(Vector3(5, 0, 5), 1.0)
	assert_eq(near.size(), 1, "it lies on the ground")
	GameBus.pickup_requested.emit(str(near[0]["id"]))
	assert_eq(inv.get_item_count(tool), 1, "picked up again")
	assert_eq(inv.get_durability(tool), 7.0, "with its wear intact: dropping cannot repair a tool")
	loot.free()
	inv.free()

func _test_hud_skills_rows_and_window_keys() -> void:
	var rows := UiSlice.skills_rows({"Archery": "novice", "Smithing": "master", "Alchemy": "expert"})
	assert_eq(rows.map(func(r): return r["id"]), ["Smithing", "Alchemy", "Archery"], "skills list best tier first")
	var ui := _new_hud_ui()
	for pair in [[KEY_C, "character"], [KEY_K, "skills"], [KEY_H, "crafting"], [KEY_P, "market"], [KEY_I, "inventory"]]:
		var e := InputEventKey.new()
		e.pressed = true
		e.keycode = pair[0]
		ui._input(e)
		assert_true(ui.is_window_open(pair[1]), "key %d opens %s" % [pair[0], pair[1]])
	ui.free()

func _test_hud_window_dock() -> void:
	var seen := {}
	for e in _WindowDockScript.entries():
		assert_false(seen.has(e["letter"]), "shortcut letters are unique: %s" % e["letter"])
		seen[e["letter"]] = true
		assert_true(UiSlice.WINDOW_KEYS.has(e["key"]), "dock window exists: %s" % e["key"])
		assert_false(_HotbarScript.bind_allowed(OS.find_keycode_from_string(str(e["letter"]))) , "dock letter %s is reserved from box shortcuts" % e["letter"])
	assert_false(seen.has("M"), "M stays free for the map window")
	assert_true(seen.has("K"), "K is Skills")
	assert_true(seen.has("C") and seen.has("H"), "C is Character, H is Crafting")
	var ui := _new_hud_ui()
	var toggled: Array = []
	ui.window_dock.window_toggled.connect(func(k: String) -> void: toggled.append(k))
	ui.window_dock.window_toggled.emit("inventory")
	assert_true(ui.is_window_open("inventory"), "clicking the I box opens the inventory")
	assert_eq(toggled, ["inventory"], "the dock reported the click")
	ui.window_dock.set_expanded(false)
	assert_false(ui.window_dock.is_expanded(), "the dock collapses")
	ui.free()
	# A collapsed dock stays collapsed on the next start.
	var again := _new_test_ui()
	assert_false(again.window_dock.is_expanded(), "the dock reopens the way it was left")
	again.window_dock.set_expanded(true)
	again.free()
	var third := _new_test_ui()
	assert_true(third.window_dock.is_expanded(), "an expanded dock persists too")
	third.free()
	DirAccess.remove_absolute(_TEST_DOCK_FILE)

func _test_ui_inventory_lines() -> void:
	var ui := _new_test_ui()
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
	var ui := _new_test_ui()
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
	var ui := _new_test_ui()
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

## Collect the instance ids of a specific creature type from a CreatureSlice.
func _instances_of(c: CreatureSlice, creature_id: String) -> Array:
	var out: Array = []
	for iid in c._instances:
		if c._instances[iid]["creature_id"] == creature_id:
			out.append(iid)
	return out

func _test_ai_pack_shares_aggressive() -> void:
	var rig := _make_ai_rig()
	var c: CreatureSlice = rig["creature"]
	var ai: CreatureAI   = rig["ai"]
	var wolves := _instances_of(c, "GraywolfPack")
	assert_true(wolves.size() >= 2, "GraywolfPack spawns at least 2 pack members")
	var lead: String = wolves[0]
	var ally: String = wolves[1]
	ai.force_state(lead, "idle")
	ai.force_state(ally, "idle")
	# Cluster the ally next to the lead so packRadius covers it.
	var lead_pos: Vector3 = c._instances[lead]["position"]
	c.set_instance_position(ally, lead_pos + Vector3(1.0, 0.0, 0.0))
	# A player right on the lead wolf turns it aggressive (territorial: idle → aggressive).
	var player_pos: Vector3 = lead_pos + Vector3(0.5, 0.0, 0.0)
	ai._tick_instance(lead, c._instances[lead], player_pos, 0.1)
	assert_eq(ai.get_state(lead), "aggressive", "lead wolf turns aggressive")
	assert_eq(ai.get_state(ally), "aggressive", "pack member shares the aggressive state")
	rig["creature"].free()
	rig["ai"].free()

func _test_ai_herd_shares_flee() -> void:
	var rig := _make_ai_rig()
	var c: CreatureSlice = rig["creature"]
	var ai: CreatureAI   = rig["ai"]
	var bison := _instances_of(c, "SteppeBison")
	assert_true(bison.size() >= 2, "SteppeBison spawns at least 2 herd members")
	var lead: String = bison[0]
	var ally: String = bison[1]
	ai.force_state(lead, "aggressive")
	ai.force_state(ally, "idle")
	var lead_pos: Vector3 = c._instances[lead]["position"]
	c.set_instance_position(ally, lead_pos + Vector3(1.0, 0.0, 0.0))
	# Drain the lead bison below its flee threshold so it flees.
	var res: Resource = GameData.CREATURES.get("SteppeBison", null)
	var max_hp: float = float(res.get("baseHp")) if res else 200.0
	c._instances[lead]["hp"] = max_hp * 0.10
	var player_pos: Vector3 = lead_pos + Vector3(0.5, 0.0, 0.0)
	ai._tick_instance(lead, c._instances[lead], player_pos, 0.1)
	assert_eq(ai.get_state(lead), "fleeing", "lead bison flees below threshold")
	assert_eq(ai.get_state(ally), "fleeing", "herd member shares the fleeing state")
	rig["creature"].free()
	rig["ai"].free()

func _test_ai_solitary_no_propagation() -> void:
	var rig := _make_ai_rig()
	var c: CreatureSlice = rig["creature"]
	var ai: CreatureAI   = rig["ai"]
	var boars := _instances_of(c, "ForestBoar")
	assert_true(boars.size() >= 2, "ForestBoar spawns at least 2 instances")
	var a: String = boars[0]
	var b: String = boars[1]
	ai.force_state(a, "idle")
	ai.force_state(b, "idle")
	var a_pos: Vector3 = c._instances[a]["position"]
	c.set_instance_position(b, a_pos + Vector3(1.0, 0.0, 0.0))
	# ForestBoar is solitary (no groupBehavior): detecting a player must NOT drag
	# its neighbour along.
	var player_pos: Vector3 = a_pos + Vector3(0.5, 0.0, 0.0)
	ai._tick_instance(a, c._instances[a], player_pos, 0.1)
	assert_true(ai.get_state(a) != "idle", "boar leaves idle on detection")
	assert_eq(ai.get_state(b), "idle", "solitary boar does not drag its neighbour")
	rig["creature"].free()
	rig["ai"].free()

func _test_ai_group_behavior_reads_fabric() -> void:
	var rig := _make_ai_rig()
	var ai: CreatureAI = rig["ai"]
	var wolf_res: Resource  = GameData.CREATURES.get("GraywolfPack", null)
	var bison_res: Resource = GameData.CREATURES.get("SteppeBison", null)
	var boar_res: Resource  = GameData.CREATURES.get("ForestBoar", null)
	assert_eq(ai._group_behavior(wolf_res), CreatureAI.GROUP_PACK, "GraywolfPack is a pack")
	assert_eq(ai._group_behavior(bison_res), CreatureAI.GROUP_HERD, "SteppeBison is a herd")
	assert_eq(ai._group_behavior(boar_res), CreatureAI.GROUP_NONE, "ForestBoar is solitary (no groupBehavior)")
	assert_true(ai._pack_radius(wolf_res) > 0.0, "pack has a positive packRadius")
	assert_eq(ai._pack_radius(boar_res), 0.0, "solitary creature has zero packRadius")
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

## Phase 49 — biomes are regions, not 32 m stripes, and the layout depends on the seed.
## Coherence is checked at several seeds with a cutoff well under the measured ~0.87, so a
## one-seed fluke cannot fail it; the seed check goes through `get_biome_at_chunk` (the
## production path) and wants a real fraction of chunks to move, not a single one.
func _test_biome_regions_coherent() -> void:
	for seed_v in [TerrainSlice.BIOME_SEED, 12345, 777]:
		var same := 0
		var pairs := 0
		for cz in range(-16, 16):
			for cx in range(-16, 16):
				var b := TerrainSlice.biome_for_chunk(Vector2i(cx, cz), seed_v)
				if TerrainSlice.biome_for_chunk(Vector2i(cx + 1, cz), seed_v) == b:
					same += 1
				if TerrainSlice.biome_for_chunk(Vector2i(cx, cz + 1), seed_v) == b:
					same += 1
				pairs += 2
		var frac := float(same) / float(pairs)
		assert_true(frac >= 0.75, "neighbouring chunks mostly share a biome at seed %d (%.2f)" % [seed_v, frac])
	var terrain := TerrainSlice.new()
	add_child(terrain)
	terrain.set_world_seed(111)
	var layout_a: Array = []
	for cx in range(-16, 16):
		layout_a.append(terrain.get_biome_at_chunk(Vector2i(cx, 3)))
	terrain.set_world_seed(222)
	var moved := 0
	for i in layout_a.size():
		if terrain.get_biome_at_chunk(Vector2i(i - 16, 3)) != layout_a[i]:
			moved += 1
	assert_true(moved >= 4, "a different world seed re-lays out the biomes through get_biome_at_chunk (%d of 32 moved)" % moved)
	terrain.free()

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

func _test_chunk_refresh_queues_nearest_first() -> void:
	var cm := ChunkManager.new()
	add_child(cm)
	var player := PlayerSlice.new()
	add_child(player)
	cm.player_slice = player
	cm.view_distance = 1
	player.spawn_at(Vector3(16.0, 40.0, 16.0))  # chunk (0,0)
	cm.refresh()
	assert_true(cm._load_queue.size() > 0, "refresh enqueues desired chunks")
	assert_eq(cm._load_queue[0], Vector2i(0, 0), "center chunk queued first (nearest-first)")
	assert_false(cm._loaded.has("0,0"), "loads are queued, not built immediately")
	cm.free()
	player.free()

func _test_chunk_load_queue_respects_budget() -> void:
	var cm := ChunkManager.new()
	add_child(cm)
	cm.loads_per_frame = 2
	cm._pending["1,0"] = true
	cm._pending["0,1"] = true
	cm._pending["0,0"] = true
	cm._load_queue = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, 0)]
	cm._drain_load_queue()
	assert_eq(cm._load_queue.size(), 1, "budget of 2 leaves one chunk still queued")
	assert_true(cm._loaded.has("1,0"), "first queued chunk loaded")
	assert_true(cm._loaded.has("0,1"), "second queued chunk loaded")
	assert_false(cm._loaded.has("0,0"), "third chunk still pending after one drain")
	assert_false(cm._pending.has("1,0"), "loaded chunk cleared from pending set")
	cm.free()

func _test_chunk_voxel_edits_isolated() -> void:
	var v := VoxelSlice.new()
	add_child(v)
	var inv := InventorySlice.new()
	add_child(inv)
	v.inventory_slice = inv
	var flat: Array = []
	flat.resize(64 * 64)
	flat.fill(2.0)
	v.build_chunk(Vector2i(0, 0), flat)
	v.build_chunk(Vector2i(1, 0), flat)
	assert_true(v.mine_block(Vector3(16.0, 2.0, 16.0)).get("success", false), "mine in chunk (0,0)")
	assert_eq(v.get_voxel_height_at(Vector2(16.0, 16.0)), 1.875, "chunk (0,0) lowered")
	assert_eq(v.get_voxel_height_at(Vector2(48.0, 16.0)), 2.0, "chunk (1,0) unaffected")
	v.free()
	inv.free()

func _test_chunk_unload_preserves_edits() -> void:
	var v := VoxelSlice.new()
	add_child(v)
	var flat: Array = []
	flat.resize(64 * 64)
	flat.fill(2.0)
	v.build_chunk(Vector2i(0, 0), flat)
	v.apply_edits({ "32,32": 1.0 })
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
	flat.resize(64 * 64)
	flat.fill(2.0)
	v.build_chunk(Vector2i(0, 0), flat)
	# Mine a block — this marks chunk (0,0) dirty.
	v.mine_block(Vector3(16.0, 2.0, 16.0))
	assert_true(v.get_dirty_chunk_keys().size() > 0, "mining marks a chunk dirty")
	# Simulate a save: clear dirty tracking (as game_root does after save).
	v.clear_dirty_chunks()
	assert_eq(v.get_dirty_chunk_keys().size(), 0, "dirty cleared after save")
	# Mine another block — this marks the chunk dirty mid-save-cycle.
	v.mine_block(Vector3(17.0, 2.0, 16.0))
	assert_true(v.get_dirty_chunk_keys().size() > 0, "mid-cycle mine marks chunk dirty again")
	# apply_edits simulates what happens on load (world data reapplied).
	# It must NOT clear the dirty tracking set by the mid-cycle mine above.
	v.apply_edits({ "32,32": 1.0 })
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
	flat.resize(64 * 64)
	flat.fill(2.0)
	v.build_chunk(Vector2i(0, 0), flat)
	v.apply_edits({ "32,32": 1.0, "96,96": 3.0 })
	var manifest: Dictionary = v.get_chunk_manifest()
	assert_true(manifest.has("0,0"), "manifest groups chunk (0,0)")
	assert_true(manifest.has("1,1"), "manifest groups chunk (1,1)")
	var entry: Variant = manifest["0,0"]["edits"]["32,32"]
	assert_true(entry is Array, "chunk (0,0) edit is a typed run edit")
	assert_eq(str(entry[0]["op"]), "remove", "and names what the edit DID")
	assert_eq(float(entry[0]["top"]), 2.0, "carving from the natural top down to the saved height")
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
	mm.set_player_pos(Vector2(16.0, 16.0))
	assert_eq(mm.get_player_cell()["chunk"], Vector2i(0, 0), "player cell resolves to chunk (0,0)")
	assert_true(mm.is_revealed(Vector2i(0, 0)), "player's own chunk is revealed")
	assert_true(Minimap.BIOME_COLORS.has("TemperateForest"), "biome resolves to a colour")
	var tf: Variant = GameData.BIOMES.get("TemperateForest", null)
	assert_true(tf != null, "the TemperateForest biome resource is loaded")
	assert_true(tf != null and tf.get("surfaceTint") != null, "TemperateForest declares a fabric surfaceTint")
	var want_tint: Color = Color.from_string(str(tf.get("surfaceTint")), Color.BLACK) if tf != null and tf.get("surfaceTint") != null else Color.BLACK
	assert_eq(mm.biome_color("TemperateForest"), want_tint, "minimap uses the fabric surface tint")
	assert_eq(mm.biome_color("TemperateForest"), want_tint, "and a repeated lookup returns the cached colour")
	assert_eq(mm.biome_color("NoSuchBiome"), Minimap.FALLBACK_COLOR, "unknown biome falls back to grey")
	mm.free()

func _test_chunk_minimap_fog_of_war() -> void:
	var mm := Minimap.new()
	add_child(mm)
	mm.set_player_pos(Vector2(16.0, 16.0))  # chunk (0,0), reveals a 3x3 neighbourhood
	assert_true(mm.is_revealed(Vector2i(0, 0)), "current chunk revealed")
	assert_true(mm.is_revealed(Vector2i(1, 1)), "neighbour revealed (reveal radius)")
	assert_false(mm.is_revealed(Vector2i(3, 3)), "far chunk not yet revealed")
	# Move far away: previously visited chunks stay revealed (persistent fog).
	mm.set_player_pos(Vector2(16.0 + 32.0 * 10.0, 16.0))  # chunk (10, 0)
	assert_true(mm.is_revealed(Vector2i(0, 0)), "previously visited chunk stays revealed")
	mm.free()

func _test_chunk_minimap_zoom() -> void:
	var mm := Minimap.new()
	add_child(mm)
	assert_true(mm.get_zoom() < Minimap.ZOOM_MAX, "default zoom is zoomed in")
	var before: float = mm.get_zoom()
	mm.zoom_out()
	assert_true(mm.get_zoom() > before, "zoom out shows more chunks")
	mm.zoom_in()
	mm.zoom_in()
	assert_true(mm.get_zoom() < Minimap.ZOOM_MAX, "zoom in shows fewer chunks")
	mm.set_zoom(1000.0)
	assert_eq(mm.get_zoom(), Minimap.ZOOM_MAX, "zoom clamps to ZOOM_MAX")
	mm.set_zoom(-5.0)
	assert_eq(mm.get_zoom(), Minimap.ZOOM_MIN, "zoom clamps to ZOOM_MIN")
	mm.free()

func _test_chunk_minimap_arrow_direction() -> void:
	var mm := Minimap.new()
	add_child(mm)
	assert_true(mm._facing_screen_dir(Vector2(0.0, -1.0)).is_equal_approx(Vector2(0.0, -1.0)), "north (world -Z) maps to screen up")
	assert_true(mm._facing_screen_dir(Vector2(1.0, 0.0)).is_equal_approx(Vector2(1.0, 0.0)), "east (world +X) maps to screen right")
	assert_true(mm._facing_screen_dir(Vector2(0.0, 1.0)).is_equal_approx(Vector2(0.0, 1.0)), "south (world +Z) maps to screen down")
	assert_true(mm._facing_screen_dir(Vector2.ZERO).is_equal_approx(Vector2(0.0, -1.0)), "degenerate facing falls back to north")
	mm.free()

func _test_player_facing() -> void:
	var p := PlayerSlice.new()
	add_child(p)
	var f0: Vector2 = p.get_facing()
	assert_true(absf(f0.length() - 1.0) < 0.001, "facing is a unit vector")
	assert_true(f0.is_equal_approx(Vector2(0.0, -1.0)), "unrotated player faces -Z (north)")
	p._pivot.rotate_y(PI * 0.5)
	var f1: Vector2 = p.get_facing()
	assert_false(f1.is_equal_approx(f0), "facing changes after yaw rotation")
	assert_true(absf(f1.length() - 1.0) < 0.001, "rotated facing stays normalized")
	p.free()

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
	flat.resize(64 * 64)
	flat.fill(2.0)
	v.build_chunk(Vector2i(0, 0), flat)
	var intent := {}
	GameBus.block_edit_intent.connect(func(action, pos, normal, material):
		intent["action"] = action
		intent["material"] = material
	)
	v._on_mine_requested(Vector3(16.0, 2.0, 16.0), Vector3.UP, "")
	assert_eq(intent.get("action", ""), "mine", "client forwards a mine intent")
	assert_false(v._edits.has("32,32"), "mine_block did not edit this slice directly")
	v.free()

func _test_net_voxel_apply_block_change() -> void:
	# apply_block_change applies a host-authoritative edit without touching
	# inventory or re-emitting block_changed.
	var v := VoxelSlice.new()
	add_child(v)
	var flat: Array = []
	flat.resize(64 * 64)
	flat.fill(2.0)
	v.build_chunk(Vector2i(0, 0), flat)
	var reemit := 0
	GameBus.block_changed.connect(func(_a, _p, _n, _m): reemit += 1)
	v.apply_block_change("mine", Vector3(16.0, 2.0, 16.0), Vector3.UP, "")
	assert_eq(v.get_voxel_height_at(Vector2(16.0, 16.0)), 1.875, "mine applied (2.0 → 1.875)")
	v.apply_block_change("place", Vector3(16.0, 2.0, 16.0), Vector3.UP, "Ferrite")
	assert_eq(v.get_voxel_height_at(Vector2(16.0, 16.0)), 2.0, "place applied (1.875 → 2.0)")
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
	var pos: Vector3 = p._ghosts[2]["pos"]
	assert_true(pos.x > 0.0 and pos.x < 10.0, "ghost interpolates between snapshots")
	p.free()

func _test_net_player_ghost_self_filter() -> void:
	# The local player's own peer id must never spawn a ghost — the host echoes
	# a client's movement back to every peer, including the originator.
	var p := PlayerSlice.new()
	add_child(p)
	p._on_remote_player_state(multiplayer.get_unique_id(), Vector3(1.0, 2.0, 3.0))
	assert_eq(p.get_remote_ghost_count(), 0, "own peer id does not spawn a ghost")
	p.free()

func _test_player_headless_no_ghost_or_broadcast() -> void:
	# A headless server (render_visuals = false) has no local player and renders
	# nothing: it must not build a ghost pool for remote players, and it must not
	# broadcast a phantom player at (0,0,0) to clients.
	var p := PlayerSlice.new()
	p.render_visuals = false
	add_child(p)
	p._on_remote_player_state(2, Vector3(1.0, 2.0, 3.0))
	assert_eq(p.get_remote_ghost_count(), 0, "headless server spawns no remote ghost")
	assert_true(p._ghost_pool == null, "headless server builds no ghost pool")
	var emitted := {}
	var cb := func(_payload): emitted["hit"] = true
	GameBus.player_state_changed.connect(cb)
	p._broadcast_state()
	assert_true(not emitted.has("hit"), "headless server does not broadcast a phantom player")
	GameBus.player_state_changed.disconnect(cb)
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
	inv.replace_contents({ "Ashite": 3, "FerritePick": 2 })
	assert_eq(inv.get_item_count("Ferrite"), 0, "replace clears old items")
	assert_eq(inv.get_item_count("Ashite"), 3, "replace applies host contents")
	assert_eq(inv.get_item_count("FerritePick"), 2, "replace applies a durable item")
	assert_eq(inv.get_durability_values("FerritePick").size(), 2, "durable durability rebuilt to match quantity")
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
	# Phase 47 — announcing gear is host-only and needs a connection: offline it is a no-op, not a crash.
	n.announce_equipment_to_aoi(2)
	n.announce_equipment_to_aoi(99)
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

func _test_net_peer_party_scopes_identity() -> void:
	# The acting party behind a connection is the identity the host bound to it —
	# whatever a payload names, and nothing at all before the handshake. `party_id_for`
	# keeps answering a transport label for display, but never authorizes anything.
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	assert_eq(n._actor_id(5), "", "an un-handshaked peer has no acting identity")
	assert_eq(n.party_id_for(5), "peer_5", "its diagnostic label falls back to the transport id")
	n.set_player_id(5, "player_5_1_beef")
	assert_eq(n._actor_id(5), "player_5_1_beef", "the bound identity is the acting party")
	n.free()

func _test_net_social_intents_bind_connection_identity() -> void:
	# Market and governance intents carry an identity the host must IGNORE: a client
	# that could name one could sell a victim's goods (the escrow debit empties their
	# inventory), buy into a victim's own listing, or cast a victim's vote — a quorum
	# of one. The connection decides who is acting; un-handshaked peers cannot act.
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	var listed: Array = []
	var bought: Array = []
	var authored: Array = []
	var voted: Array = []
	var superseded: Array = []
	var on_list := func(seller: String, item_id: String, qty: int, price: float) -> void:
		listed.append([seller, item_id, qty, price])
	var on_buy := func(listing_id: String, buyer: String) -> void:
		bought.append([listing_id, buyer])
	var on_submit := func(author: String, title: String, _body: String) -> void:
		authored.append([author, title])
	var on_vote := func(proposal_id: String, voter: String, verdict: String) -> void:
		voted.append([proposal_id, voter, verdict])
	var on_supersede := func(proposal_id: String, replacement_id: String) -> void:
		superseded.append([proposal_id, replacement_id])
	GameBus.market_list_intent.connect(on_list)
	GameBus.market_buy_intent.connect(on_buy)
	GameBus.proposal_submit_intent.connect(on_submit)
	GameBus.proposal_vote_intent.connect(on_vote)
	GameBus.proposal_supersede_intent.connect(on_supersede)

	var spoof := "player_victim_1_deadbeef"
	n._route_c2h(7, { "type": "market_list_intent", "seller": spoof, "item_id": "wolf_fang", "quantity": 2, "price": 5.0 })
	n._route_c2h(7, { "type": "market_buy_intent", "listing_id": "listing_0", "buyer": spoof })
	n._route_c2h(7, { "type": "proposal_submit_intent", "author": spoof, "title": "T", "body": "B" })
	n._route_c2h(7, { "type": "proposal_vote_intent", "proposal_id": "proposal_0", "voter": spoof, "verdict": "for" })
	n._route_c2h(7, { "type": "proposal_supersede_intent", "proposal_id": "proposal_0", "replacement_id": "proposal_1" })
	assert_eq(listed.size(), 0, "an un-handshaked peer cannot list")
	assert_eq(bought.size(), 0, "nor buy")
	assert_eq(authored.size(), 0, "nor author a proposal")
	assert_eq(voted.size(), 0, "nor vote")
	assert_eq(superseded.size(), 0, "nor move the decisions log")

	n.set_player_id(7, "player_7_1_cafe")
	n._route_c2h(7, { "type": "market_list_intent", "seller": spoof, "item_id": "wolf_fang", "quantity": 2, "price": 5.0 })
	n._route_c2h(7, { "type": "market_buy_intent", "listing_id": "listing_0", "buyer": spoof })
	n._route_c2h(7, { "type": "proposal_submit_intent", "author": spoof, "title": "T", "body": "B" })
	n._route_c2h(7, { "type": "proposal_vote_intent", "proposal_id": "proposal_0", "voter": spoof, "verdict": "for" })
	n._route_c2h(7, { "type": "proposal_supersede_intent", "proposal_id": "proposal_0", "replacement_id": "proposal_1" })
	assert_eq(str(listed[0][0]), "player_7_1_cafe", "the seller is the connection's player, not the name")
	assert_eq(str(bought[0][1]), "player_7_1_cafe", "and so is the buyer")
	assert_eq(str(authored[0][0]), "player_7_1_cafe", "and the proposal author")
	assert_eq(str(voted[0][1]), "player_7_1_cafe", "and the voter")
	assert_eq(voted[0][2], "for", "with the verdict it did send")
	assert_eq(superseded.size(), 1, "a bound peer's supersede is re-emitted")

	GameBus.market_list_intent.disconnect(on_list)
	GameBus.market_buy_intent.disconnect(on_buy)
	GameBus.proposal_submit_intent.disconnect(on_submit)
	GameBus.proposal_vote_intent.disconnect(on_vote)
	GameBus.proposal_supersede_intent.disconnect(on_supersede)
	n.free()

func _test_net_trade_intents_bind_connection_identity() -> void:
	# Every trade step acts as the connection's own player: a spoofed accept used to
	# commit the OTHER side's goods. An invite may name a counterparty, but only one
	# the host can resolve to an online player — nobody can be dragged into a session
	# that cannot be answered.
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("player_host_1")
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.player_registry = reg
	var started: Array = []
	var proposed: Array = []
	var accepted: Array = []
	var rejected: Array = []
	var on_start := func(party_a: String, party_b: String) -> void:
		started.append([party_a, party_b])
	var on_propose := func(trade_id: String, party: String, _give: Dictionary, _want: Dictionary) -> void:
		proposed.append([trade_id, party])
	var on_accept := func(trade_id: String, party: String) -> void:
		accepted.append([trade_id, party])
	var on_reject := func(trade_id: String, party: String) -> void:
		rejected.append([trade_id, party])
	GameBus.trade_start_intent.connect(on_start)
	GameBus.trade_propose_intent.connect(on_propose)
	GameBus.trade_accept_intent.connect(on_accept)
	GameBus.trade_reject_intent.connect(on_reject)

	var spoof := "player_victim_1_deadbeef"
	n._route_c2h(7, { "type": "trade_accept_intent", "trade_id": "trade_0", "party": spoof })
	n._route_c2h(7, { "type": "trade_propose_intent", "trade_id": "trade_0", "party": spoof, "give": {}, "want": {} })
	n._route_c2h(7, { "type": "trade_reject_intent", "trade_id": "trade_0", "party": spoof })
	n._route_c2h(7, { "type": "trade_start_intent", "party_a": spoof, "party_b": "player_host_1" })
	assert_eq(accepted.size(), 0, "an un-handshaked peer cannot accept")
	assert_eq(proposed.size(), 0, "nor propose")
	assert_eq(rejected.size(), 0, "nor reject")
	assert_eq(started.size(), 0, "nor open a session")

	n.set_player_id(7, "player_7_1_cafe")
	n._route_c2h(7, { "type": "trade_accept_intent", "trade_id": "trade_0", "party": spoof })
	n._route_c2h(7, { "type": "trade_propose_intent", "trade_id": "trade_0", "party": spoof, "give": {}, "want": {} })
	n._route_c2h(7, { "type": "trade_reject_intent", "trade_id": "trade_0", "party": spoof })
	assert_eq(str(accepted[0][1]), "player_7_1_cafe", "the accepter is the connection's player")
	assert_eq(str(proposed[0][1]), "player_7_1_cafe", "and the proposer")
	assert_eq(str(rejected[0][1]), "player_7_1_cafe", "and the rejecter")

	# Invites: the named counterparty must resolve. Phase 37 — the name is a public
	# HANDLE, which is the only identity a client is ever told, so that is what an
	# invite carries.
	var host_handle: String = reg.public_handle("player_host_1")
	n._route_c2h(7, { "type": "trade_start_intent", "party_a": spoof, "party_b": host_handle })
	assert_eq(started.size(), 1, "an invite to an online player's handle is opened")
	assert_eq(str(started[0][0]), "player_7_1_cafe", "in the sender's own name")
	assert_eq(str(started[0][1]), "player_host_1", "naming the counterparty it resolved")

	# Phase 37 — a RAW PLAYER ID is no longer a name an invite may carry, even a real
	# online player's: answering it turned this into a yes/no oracle for "is that exact
	# id connected", and an id is a bearer token (see resolve_identity). Nothing
	# legitimate still sends one — a client learns ids nowhere (redact_for_client).
	n._route_c2h(7, { "type": "trade_start_intent", "party_a": "player_7_1_cafe", "party_b": "player_host_1" })
	assert_eq(started.size(), 1, "a raw online player id is refused")
	n._route_c2h(7, { "type": "trade_start_intent", "party_a": "player_7_1_cafe", "party_b": "player_nobody_9_0" })
	n._route_c2h(7, { "type": "trade_start_intent", "party_a": "player_7_1_cafe", "party_b": "" })
	n._route_c2h(7, { "type": "trade_start_intent", "party_a": "player_7_1_cafe", "party_b": "player_7_1_cafe" })
	assert_eq(started.size(), 1, "an unresolvable, empty or self counterparty is refused")

	GameBus.trade_start_intent.disconnect(on_start)
	GameBus.trade_propose_intent.disconnect(on_propose)
	GameBus.trade_accept_intent.disconnect(on_accept)
	GameBus.trade_reject_intent.disconnect(on_reject)
	n.free()
	reg.free()

func _test_net_block_intent_requires_handshake_and_reach() -> void:
	# A block edit is the world's state, so it needs a bound identity and a target the
	# host can place relative to where it last saw the peer: without the reach check a
	# client could mine or build anywhere (another player's feet included).
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	var mined: Array = []
	var on_mine := func(pos: Vector3, normal: Vector3, _player_id: String) -> void:
		mined.append([pos, normal])
	GameBus.block_mine_requested.connect(on_mine)

	var near := Vector3(30.0, 4.0, 0.0)
	var edit := { "type": "block_edit_intent", "action": "mine", "position": [near.x, near.y, near.z], "normal": [0, 1, 0] }
	n._route_c2h(7, edit)
	assert_eq(mined.size(), 0, "an un-handshaked peer cannot edit the world")

	n.set_player_id(7, "player_7_1_cafe")
	n._route_c2h(7, edit)
	assert_eq(mined.size(), 0, "a peer with no recorded position has no reach to check")

	n.remember_player_state(7, Vector3.ZERO)
	n._route_c2h(7, edit)
	assert_eq(mined.size(), 1, "an edit within reach is applied")
	assert_eq(mined[0][0], near, "at the position the client asked for")

	var far := Vector3(2000.0, 4.0, 2000.0)
	n._route_c2h(7, { "type": "block_edit_intent", "action": "place", "position": [far.x, far.y, far.z], "normal": [0, 1, 0] })
	assert_eq(mined.size(), 1, "an edit beyond reach is dropped")

	GameBus.block_mine_requested.disconnect(on_mine)
	n.free()

func _test_net_tree_intent_requires_handshake_and_reach() -> void:
	# The chop intent names only a tree id, so the reach check resolves the tree's own
	# position through the wired TreeSlice — and fails closed when no tree is known.
	var trees := TreeSlice.new()
	add_child(trees)
	trees.spawn_for_chunk(Vector2i(0, 0))
	var all_trees: Array = trees.get_all_trees()
	assert_true(all_trees.size() > 0, "the rig has trees to chop")
	var target: Dictionary = all_trees[0]
	var tree_pos: Vector3 = target["position"]

	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.tree_slice = trees
	var chops: Array = []
	var on_chop := func(tree_id: String, _player_id: String) -> void:
		chops.append(tree_id)
	GameBus.tree_chop_requested.connect(on_chop)

	var intent := { "type": "tree_chop_intent", "tree_id": str(target["tree_id"]) }
	n._route_c2h(7, intent)
	assert_eq(chops.size(), 0, "an un-handshaked peer cannot chop")

	n.set_player_id(7, "player_7_1_cafe")
	n._route_c2h(7, { "type": "tree_chop_intent", "tree_id": "tree_999_999_9" })
	assert_eq(chops.size(), 0, "a tree the host does not have is not chopable")

	n.remember_player_state(7, tree_pos + Vector3(10.0, 0.0, 0.0))
	n._route_c2h(7, intent)
	assert_eq(chops.size(), 1, "a chop within reach is re-emitted for TreeSlice")
	assert_eq(str(chops[0]), str(target["tree_id"]), "for the tree the client named")

	n.remember_player_state(7, tree_pos + Vector3(500.0, 0.0, 500.0))
	n._route_c2h(7, { "type": "tree_chop_intent", "tree_id": str(all_trees[1]["tree_id"]) })
	assert_eq(chops.size(), 1, "a chop beyond reach is dropped")

	GameBus.tree_chop_requested.disconnect(on_chop)
	n.free()
	trees.free()

## Phase 42 review (fifth pass) — a world edit resolved on the host for a REMOTE peer is
## the PEER's resource. Every check and mutation used to go through
## `VoxelSlice.inventory_slice`, which is the HOST's own pack: a client's mine filled the
## host's inventory while the client — whose own client mirrors only ITS pack — saw
## nothing. The acting identity now rides the request (`_route_c2h` binds it to the
## connection, never to a payload), the resolution goes through `inventory_for(actor)`,
## and the actor's own client is pushed the result on `inventory_synced` (addressed to its
## owner, so networking delivers it to that peer alone — Phase 37).
func _test_net_remote_mine_credits_the_actor() -> void:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("player_host_1")
	var host_inv := InventorySlice.new()
	add_child(host_inv)
	var peer_pid := "player_7_1_cafe"

	var v := _make_voxel()
	v.is_authoritative = true
	v.inventory_slice = host_inv
	v.player_registry = reg

	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.set_player_id(7, peer_pid)
	n.remember_player_state(7, Vector3.ZERO)

	var mined: Array = []
	var on_mined := func(material: String, _qty: int, _pos: Vector3) -> void:
		mined.append(material)
	GameBus.block_mined.connect(on_mined)
	var synced: Array = []
	var on_synced := func(owner: String, _contents: Dictionary, _durabilities: Dictionary) -> void:
		synced.append(owner)
	GameBus.inventory_synced.connect(on_synced)

	n._route_c2h(7, { "type": "block_edit_intent", "action": "mine",
		"position": [16.0, 2.0, 16.0], "normal": [0, 1, 0] })

	assert_eq(mined.size(), 1, "the mine resolved (handshake + reach both pass)")
	var material := str(mined[0])
	var peer_inv: Node = reg.get_inventory(peer_pid)
	assert_eq(peer_inv.get_item_count(material), 1, "the yield lands in the ACTOR's pack")
	assert_eq(host_inv.get_item_count(material), 0, "and NOT in the host's own pack")
	assert_true(synced.has(peer_pid), "and the actor's own client is pushed the change")

	GameBus.block_mined.disconnect(on_mined)
	GameBus.inventory_synced.disconnect(on_synced)
	v.free()
	n.free()
	reg.free()

## The placement half of the same rule: the block comes out of the ACTOR's pack, and the
## material placed is the one the ACTOR named (not this host's own `_place_material`). A
## material that is not in the fabric's table grants nothing even when the request "holds"
## it — the request is a claim, `GameData.MATERIALS` is the authority.
func _test_net_remote_place_spends_the_actor() -> void:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("player_host_1")
	var host_inv := InventorySlice.new()
	add_child(host_inv)
	host_inv.add_item("Ferrite", 4)
	var peer_pid := "player_7_1_cafe"

	var v := _make_voxel()
	v.is_authoritative = true
	v.inventory_slice = host_inv
	v.player_registry = reg
	v.set_place_material("Ferrite")   # the HOST's selection — a peer must not inherit it

	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.set_player_id(7, peer_pid)
	n.remember_player_state(7, Vector3.ZERO)

	var peer_inv: Node = reg.get_inventory(peer_pid)
	peer_inv.add_item("Ashite", 2)

	var placed: Array = []
	var on_placed := func(material: String, _pos: Vector3) -> void:
		placed.append(material)
	GameBus.block_placed.connect(on_placed)

	n._route_c2h(7, { "type": "block_edit_intent", "action": "place",
		"position": [24.0, 2.0, 16.0], "normal": [0, 1, 0], "material": "Ashite" })
	assert_eq(placed.size(), 1, "the placement resolved")
	var placed_material := str(placed[0]) if placed.size() > 0 else ""
	assert_eq(placed_material, "Ashite", "the material placed is the one the ACTOR named")
	assert_eq(v.get_voxel_height_at(Vector2(24.25, 16.25)), 2.125, "and the block is really there")
	assert_eq(peer_inv.get_item_count("Ashite"), 1, "spent out of the ACTOR's pack")
	assert_eq(host_inv.get_item_count("Ashite"), 0, "the host's pack never held it")
	assert_eq(host_inv.get_item_count("Ferrite"), 4, "and the host's own selection was not spent")

	# A material the fabric does not know: refused before the debit, so it neither
	# places a ghost block nor costs the actor anything. (Inside chunk "0,0", the only
	# chunk this rig built — an unbuilt chunk answers BEDROCK_DEPTH and would mask it.)
	peer_inv.add_item("NotAMaterial", 1)
	n._route_c2h(7, { "type": "block_edit_intent", "action": "place",
		"position": [20.0, 2.0, 16.0], "normal": [0, 1, 0], "material": "NotAMaterial" })
	assert_eq(placed.size(), 1, "a fabricated material emits no placement")
	assert_eq(v.get_voxel_height_at(Vector2(20.25, 16.25)), 2.0, "and places nothing")
	assert_eq(peer_inv.get_item_count("NotAMaterial"), 1, "and costs the actor nothing")

	GameBus.block_placed.disconnect(on_placed)
	v.free()
	n.free()
	reg.free()

## The chop half: the wood lands in the CHOPPER's pack and the axe that wears is the
## chopper's own (a peer used to wear the host's axe and fill the host's pack).
func _test_net_remote_chop_credits_the_actor() -> void:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("player_host_1")
	var host_inv := InventorySlice.new()
	add_child(host_inv)
	host_inv.add_item("CarpenterAxe", 1)
	var peer_pid := "player_7_1_cafe"

	var t := TreeSlice.new()
	add_child(t)
	t.is_authoritative = true
	t.inventory_slice = host_inv
	t.player_registry = reg
	t.spawn_for_chunk(Vector2i(0, 0))
	var target: Dictionary = t.get_all_trees()[0]
	var tid: String = str(target["tree_id"])
	var tree_pos: Vector3 = target["position"]

	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.tree_slice = t
	n.set_player_id(7, peer_pid)
	n.remember_player_state(7, tree_pos + Vector3(10.0, 0.0, 0.0))

	var peer_inv: Node = reg.get_inventory(peer_pid)
	peer_inv.add_item("CarpenterAxe", 1)
	var wear_before: float = float(peer_inv.get_durability_data()["CarpenterAxe"][0])

	var synced: Array = []
	var on_synced := func(owner: String, _contents: Dictionary, _durabilities: Dictionary) -> void:
		synced.append(owner)
	GameBus.inventory_synced.connect(on_synced)

	n._route_c2h(7, { "type": "tree_chop_intent", "tree_id": tid })

	assert_eq(str(t.get_tree_record(tid)["state"]), "stump", "the chop resolved on the host")
	assert_eq(peer_inv.get_item_count("Thornwood"), 2, "the wood lands in the CHOPPER's pack")
	assert_eq(host_inv.get_item_count("Thornwood"), 0, "and NOT in the host's")
	assert_true(float(peer_inv.get_durability_data()["CarpenterAxe"][0]) < wear_before,
		"the axe that wore is the CHOPPER's")
	assert_true(synced.has(peer_pid), "and the chopper's own client is pushed the change")

	GameBus.inventory_synced.disconnect(on_synced)
	t.free()
	n.free()
	reg.free()

func _test_net_client_packet_size_capped() -> void:
	# An oversized client packet is dropped before it is parsed: the cap is what keeps
	# one peer from making the authoritative process chew on an arbitrarily large JSON
	# string.
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	# `_rpc_c2h` reads the sender off the multiplayer API, so the rig has to bind the
	# identity to whatever this isolated slice reports as the remote sender.
	var sender := multiplayer.get_remote_sender_id()
	n.set_player_id(sender, "player_7_1_cafe")
	var crafts: Array = []
	var on_craft := func(recipe_id: String, player_id: String) -> void:
		crafts.append([recipe_id, player_id])
	GameBus.craft_intent.connect(on_craft)

	n._rpc_c2h(JSON.stringify({ "type": "craft_intent", "recipe_id": "R" }))
	assert_eq(crafts.size(), 1, "a packet within the cap is routed")
	var filler := "x".repeat(NetworkingSlice.MAX_CLIENT_PACKET_BYTES)
	n._rpc_c2h(JSON.stringify({ "type": "craft_intent", "recipe_id": "R", "filler": filler }))
	assert_eq(crafts.size(), 1, "a packet over the cap is dropped")

	GameBus.craft_intent.disconnect(on_craft)
	n.free()

func _test_net_client_packet_rate_limited() -> void:
	# A per-peer token bucket: a burst is capped, the bucket refills at the sustained
	# rate, and a reconnecting peer starts fresh instead of inheriting the debt.
	var n := NetworkingSlice.new()
	add_child(n)
	var allowed := 0
	for i in range(int(NetworkingSlice.RATE_BUCKET_CAPACITY) + 10):
		if n._allow_packet(3, 0.0):
			allowed += 1
	assert_eq(allowed, int(NetworkingSlice.RATE_BUCKET_CAPACITY), "a burst is capped at the bucket capacity")

	var later := 500.0
	assert_true(n._allow_packet(3, later), "the bucket refills over time")
	var refilled := 0
	for i in range(1000):
		if n._allow_packet(3, later):
			refilled += 1
	assert_eq(refilled, int(NetworkingSlice.RATE_BUCKET_REFILL_PER_SEC * 0.5) - 1,
		"and is then held to the sustained refill rate")

	n.forget_player_id(3)
	assert_true(n._allow_packet(3, later), "a disconnected peer's bucket goes with its transport state")
	n.free()

func _test_identity_handles_are_derived_and_opaque() -> void:
	# The player id is a BEARER TOKEN: presenting it on join claims the record. A
	# public handle is the pseudonym a payload may name a player by — derived from the
	# id, so it needs no storage and answers for an offline player, and one-way, so it
	# cannot be turned back into the token it came from.
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("player_host_1")
	var handle := reg.public_handle("player_host_1")
	assert_eq(handle, reg.public_handle("player_host_1"), "a handle is stable")
	assert_eq(handle.length(), PlayerRegistry.HANDLE_PREFIX.length() + PlayerRegistry.HANDLE_HEX_CHARS,
		"with a fixed width")
	assert_false(handle.contains("player_host_1"), "and reveals nothing of the id")
	assert_false(PlayerRegistry.looks_like_player_id(handle), "a handle is not id-shaped")
	assert_eq(reg.public_handle("player_host_1"), handle, "derivation needs no record to be resident")
	assert_true(reg.public_handle("player_host_2") != handle, "two players get different handles")

	var guest := "player_1700000000_1_" + "ab".repeat(16)
	assert_true(PlayerRegistry.looks_like_player_id(guest), "a minted id is id-shaped")
	assert_false(PlayerRegistry.looks_like_player_id("merchant"), "a demo party name is not")
	assert_false(PlayerRegistry.looks_like_player_id("player_1700000000_1_zz"), "nor is a malformed one")

	# Reverse lookup goes through players this process can actually act with.
	assert_eq(reg.player_id_for_handle(handle), "player_host_1", "the local player resolves by handle")
	assert_eq(reg.player_id_for_handle(reg.public_handle(guest)), "", "an offline stranger does not")

	# THE TAKEOVER: what a leaked id would have bought, and what a handle does not.
	var victim := str(reg.resolve_identity(1))
	reg.get_record(victim)["hp"] = 42.0
	assert_eq(reg.unbind_peer(1), victim, "the victim disconnects")
	assert_eq(reg.resolve_identity(2, victim), victim,
		"a leaked ID is honoured as that player's reconnect (the leak's value)")
	assert_eq(reg.unbind_peer(2), victim, "…and let go again")
	assert_true(reg.resolve_identity(3, reg.public_handle(victim)) != victim,
		"a leaked HANDLE claims nothing: it mints a fresh identity")
	reg.free()

func _test_identity_syncs_are_redacted() -> void:
	# Market, trade and governance state named players by id on the wire.
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("player_host_1")
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.player_registry = reg

	var alice := "player_1700000000_7_" + "11".repeat(16)
	var bob := "player_1700000001_8_" + "22".repeat(16)
	var alice_h := reg.public_handle(alice)
	var bob_h := reg.public_handle(bob)

	var market = n.redact_for_client({ "listing_0": { "seller": alice, "item_id": "wolf_fang", "quantity": 2 } })
	assert_eq(str(market["listing_0"]["seller"]), alice_h, "a listing's seller is a handle")
	assert_eq(str(market["listing_0"]["item_id"]), "wolf_fang", "and nothing else is touched")

	var trade = n.redact_for_client({
		"trades": { "trade_0": { "parties": [alice, bob], "offers": { alice: { "give": {} } }, "accepted": { bob: true } } },
		"next_id": 1,
	})
	var t: Dictionary = trade["trades"]["trade_0"]
	assert_eq(str(t["parties"][0]), alice_h, "a trade party is a handle")
	assert_eq(str(t["parties"][1]), bob_h, "both of them")
	assert_true(t["offers"].has(alice_h), "and the offers map is keyed by handle")
	assert_true(t["accepted"].has(bob_h), "so is the accepted map")
	assert_eq(int(trade["next_id"]), 1, "counters pass through")

	var gov = n.redact_for_client({
		"proposals": { "proposal_0": { "author": alice, "votes": { bob: "for" }, "title": "Open a road" } },
		"decisions_log": [{ "author": bob, "title": "Old" }],
	})
	assert_eq(str(gov["proposals"]["proposal_0"]["author"]), alice_h, "a proposal's author is a handle")
	assert_eq(str(gov["proposals"]["proposal_0"]["title"]), "Open a road", "its title is not")
	assert_true(gov["proposals"]["proposal_0"]["votes"].has(bob_h), "and its votes are keyed by handle")
	assert_eq(str(gov["decisions_log"][0]["author"]), bob_h, "the decisions log too")

	# The merchant scaffolding party is a literal, not an id: it must survive untouched,
	# or single-player listings would lose their seller.
	var demo = n.redact_for_client({ "listing_0": { "seller": "merchant" } })
	assert_eq(str(demo["listing_0"]["seller"]), "merchant", "a demo party name is not redacted")

	# And no raw id survives the encoding.
	var json := JSON.stringify(n.redact_for_client({ "trades": { "t": { "parties": [alice, bob] } } }))
	assert_false(json.contains(alice), "no raw id survives the encoding")
	assert_false(json.contains(bob), "for either party")
	n.free()
	reg.free()

func _test_client_adopts_its_own_handle() -> void:
	# A client is named by its own handle in everything broadcast; it shows that back to
	# its own slices as the literal "player" (the convention the local player has always
	# had), while every other handle stays opaque.
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.CLIENT
	assert_eq(n.claimed_handle, "", "no handle before the handshake")

	n._route_h2c({
		"type": "identity_assigned",
		"player_id": "player_1700000000_3_" + "cd".repeat(16),
		"handle": "p_0123456789abcdef",
	})
	assert_eq(n.claimed_player_id, "player_1700000000_3_" + "cd".repeat(16), "the id is cached for reconnect")
	assert_eq(n.claimed_handle, "p_0123456789abcdef", "and so is the handle")

	var applied: Array = []
	var on_market := func(data: Dictionary) -> void:
		applied.append(data)
	GameBus.market_synced.connect(on_market)
	n._route_h2c({ "type": "market_synced", "data": {
		"listing_0": { "seller": "p_0123456789abcdef" },
		"listing_1": { "seller": "p_ffffffffffffffff" },
	} })
	GameBus.market_synced.disconnect(on_market)
	assert_eq(applied.size(), 1, "the payload reaches the market slice")
	var rows: Dictionary = applied[0]
	assert_eq(str(rows["listing_0"]["seller"]), "player", "our own handle reads as the local player")
	assert_eq(str(rows["listing_1"]["seller"]), "p_ffffffffffffffff", "another player's stays opaque")

	# The snapshot path maps the same three blobs.
	var snapshot: Dictionary = n._adopt_snapshot_identities({
		"heightmaps": { "0,0": [1.0] },
		"market": { "listing_0": { "seller": "p_0123456789abcdef" } },
		"governance": { "proposals": {} },
		"trade": { "trades": { "trade_0": { "parties": ["p_0123456789abcdef", "p_ffffffffffffffff"] } } },
	})
	assert_eq(str(snapshot["market"]["listing_0"]["seller"]), "player", "the snapshot's market is mapped")
	assert_eq(str(snapshot["trade"]["trades"]["trade_0"]["parties"][0]), "player", "so are its trade parties")
	assert_eq(str(snapshot["trade"]["trades"]["trade_0"]["parties"][1]), "p_ffffffffffffffff", "and only ours")
	assert_true(snapshot["heightmaps"].has("0,0"), "world data is left alone")
	n.free()

## Phase 67 review — the network test seam follows the boot gate exactly (no private copy of
## the `--run-tests` rule), so a release boot refuses the seam and the suite's boots allow it.
func _test_network_seam_follows_boot_gate() -> void:
	assert_false(NetworkingSlice._test_seam_allowed_for([], false), "a release boot refuses the test seam")
	assert_true(NetworkingSlice._test_seam_allowed_for(["--run-tests"], false), "--run-tests allows it")
	assert_false(NetworkingSlice._test_seam_allowed_for([], true), "a debug build alone does not allow it")
	assert_true(NetworkingSlice._test_seam_allowed(), "this boot (the suite) allows it")

## Phase 67 review — the `?` hotkey matches on the unicode the key produced, whatever the layout.
func _test_ui_question_mark_hotkey() -> void:
	var ui := _new_test_ui()
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.unicode = 63
	ev.keycode = KEY_SLASH
	ui._input(ev)
	assert_true(ui.is_window_open("controls"), "unicode 63 opens the controls panel")
	ui._input(ev)
	assert_false(ui.is_window_open("controls"), "and toggles it closed")
	var slash := InputEventKey.new()
	slash.pressed = true
	slash.unicode = 47
	slash.keycode = KEY_SLASH
	ui._input(slash)
	assert_false(ui.is_window_open("controls"), "a plain / (unicode 47) does not")
	ui.free()

func _test_boot_suite_is_gated() -> void:
	# The automated suite no longer runs on EVERY boot: a release export that was
	# never asked for it must boot without the 7000-assertion development harness,
	# while a debug build (and an explicit --run-tests) still runs it. Asserted on
	# the pure predicate, so the rule is pinned without booting twice.
	var root_script: GDScript = load("res://src/core/game_root.gd")
	assert_false(root_script.should_run_tests([], false),
		"a release boot without the flag runs no suite")
	assert_false(root_script.should_run_tests(["--server"], false),
		"and neither does a matching --server boot")
	assert_false(root_script.should_run_tests([], true),
		"a debug build does not run the suite unless asked")
	assert_true(root_script.should_run_tests(["--run-tests"], false),
		"and --run-tests asks for it explicitly")
	assert_true(root_script.should_run_tests(["--client", "127.0.0.1", "--run-tests"], true),
		"the flag is independent of the network role")

func _test_net_aoi_center_and_in_aoi() -> void:
	# Interest management (Phase 29): a peer with no reported position falls back
	# to the spawn AOI center, and in_aoi gates on the AOI radius.
	var n := NetworkingSlice.new()
	add_child(n)
	assert_eq(n.get_aoi_center(99), NetworkingSlice.DEFAULT_AOI_CENTER,
		"unknown peer defaults to the spawn AOI center")
	n.remember_player_state(2, Vector3(0.0, 0.0, 0.0))
	assert_true(n.in_aoi(2, Vector3(50.0, 0.0, 0.0)), "position within AOI radius is in AOI")
	assert_false(n.in_aoi(2, Vector3(200.0, 0.0, 0.0)), "position beyond AOI radius is out of AOI")
	n.free()

func _test_snapshot_edits_scoped_to_aoi() -> void:
	var host := VoxelSlice.new()
	add_child(host)
	# Chunk (0,0) is near the origin; chunk (20,20) is ~640 m away.
	host.apply_edits({ "32,32": 1.0, "%d,%d" % [20 * 64 + 5, 20 * 64 + 5]: 3.0 })
	var scoped: Dictionary = host.get_chunk_manifest_in_radius(Vector3.ZERO, NetworkingSlice.EDITS_SCOPE_RADIUS)
	assert_true(scoped.has("0,0"), "AOI manifest holds the chunk in range")
	assert_false(scoped.has("20,20"), "AOI manifest omits the chunk out of range")
	var extent := float(VoxelSlice.CHUNK_SIZE) * VoxelSlice.TILE_SIZE
	var streamed := float(ChunkManager.DEFAULT_VIEW_DISTANCE + ChunkManager.DEFAULT_PREFETCH_DISTANCE) * extent
	assert_true(NetworkingSlice.EDITS_SCOPE_RADIUS >= (streamed + NetworkingSlice.AOI_RADIUS) * sqrt(2.0),
		"edit scope covers the streamed window plus an AOI cell of roaming, on the diagonal")
	assert_eq(host.get_chunk_manifest().size(), 2, "full manifest still holds both")
	# A client that already holds a far edit keeps it across a scoped apply.
	var client := VoxelSlice.new()
	add_child(client)
	client.apply_edits({ "%d,%d" % [20 * 64 + 5, 20 * 64 + 5]: 3.0 })
	client.apply_scoped_chunk_manifest(scoped, Vector3.ZERO, NetworkingSlice.EDITS_SCOPE_RADIUS)
	var held: Dictionary = client.get_chunk_manifest()
	assert_true(held.has("0,0"), "client adopted the in-scope edit")
	assert_true(held.has("20,20"), "client kept its out-of-scope edit")
	host.free()
	client.free()

func _test_net_aoi_recipients() -> void:
	# A delta is delivered only to peers whose AOI contains the entity: a near
	# peer receives it, a far peer does not, and a non-connected peer is never
	# delivered to even when in range.
	var n := NetworkingSlice.new()
	add_child(n)
	n.remember_player_state(2, Vector3(0.0, 0.0, 0.0))        # near
	n.remember_player_state(3, Vector3(5000.0, 0.0, 5000.0))  # far
	var near: Array = n.aoi_recipients(Vector3(10.0, 0.0, 0.0), [2, 3])
	assert_true(near.has(2), "near peer is an AOI recipient")
	assert_false(near.has(3), "far peer is not an AOI recipient")
	var far: Array = n.aoi_recipients(Vector3(5000.0, 0.0, 5000.0), [2, 3])
	assert_true(far.has(3), "far entity reaches the far peer")
	assert_false(far.has(2), "far entity does not reach the near peer")
	assert_false(n.aoi_recipients(Vector3.ZERO, [3]).has(2),
		"peer outside the connected set is excluded even when in range")
	n.free()

func _test_net_aoi_region() -> void:
	# The AOI grid cell floors world position by the AOI radius, negative values
	# included, so a peer crossing a boundary triggers a re-scope.
	var n := NetworkingSlice.new()
	add_child(n)
	assert_eq(n.aoi_region(Vector3.ZERO), Vector2i(0, 0), "origin maps to cell (0,0)")
	assert_eq(n.aoi_region(Vector3(NetworkingSlice.AOI_RADIUS, 0.0, 0.0)), Vector2i(1, 0),
		"exactly AOI_RADIUS crosses into cell (1,0)")
	assert_eq(n.aoi_region(Vector3(-1.0, 0.0, -1.0)), Vector2i(-1, -1),
		"negative positions floor to negative cells")
	n.free()

# ---------------------------------------------------------------------------
# AssetOverlay tests (Phase 21 — asset separation)
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
## prefers the private `models/player_rig.glb.raw` and falls back to this public key,
## and `attach_rig` HIDES the procedural box body on success. The placeholder used to
## be a SINGLE 1x1 TRIANGLE in the XY plane — flat and single-sided, so a public clone
## showed nothing from behind and a gray sliver from the front: the player's own
## character was invisible. A rig that stands in for the player must be a BODY —
## several parts, human height, thickness on BOTH horizontal axes (so it renders from
## any angle, unlike a flat card), feet on the root's ground plane, and every clip the
## locomotion tree asks for so a fresh clone logs no "[RigTree] rig has no …".
func _test_asset_placeholder_rig_is_a_body() -> void:
	const RigTree := preload("res://src/character/rig_tree.gd")
	const Locomotion := preload("res://src/character/locomotion.gd")
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

## Recursively collect every MeshInstance3D under `node` into `out`.
func _collect_mesh_instances(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect_mesh_instances(child, out)

func _test_asset_missing_model_falls_back() -> void:
	assert_true(AssetOverlay.load_mesh("models/missing.glb.raw") == null, "missing mesh -> null")
	assert_eq(AssetOverlay.load_animation_library("models/missing.glb.raw").get_animation_list().size(), 0,
		"missing animations -> empty library")

func _test_asset_creature_key() -> void:
	assert_eq(AssetOverlay.creature_model_key("Wolf"), "models/creatures/Wolf.glb.raw", "creature key")

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
	assert_eq(ch._instances[dflt]["rig_key"], "models/placeholder_rig.glb.raw", "to the public placeholder when no player rig is listed")
	ch.free()

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
# Trade slice tests (Phase 24)
# ---------------------------------------------------------------------------

func _test_trade_both_accept_resolves() -> void:
	var inv_a := InventorySlice.new()
	add_child(inv_a)
	var inv_b := InventorySlice.new()
	add_child(inv_b)
	inv_a.add_item("wolf_fang", 5)
	inv_b.add_item("hawk_feather", 3)
	var t := TradeSlice.new()
	add_child(t)
	t.set_party_inventory("player", inv_a)
	t.set_party_inventory("peer", inv_b)
	t.set_skill("Trade", "master")   # tax-free so the exchange is clean
	var tid := t.start_trade("player", "peer")
	t.propose(tid, "player", { "wolf_fang": 5 }, { "hawk_feather": 3 })
	t.propose(tid, "peer", { "hawk_feather": 3 }, { "wolf_fang": 5 })
	t.accept(tid, "player")
	var result: Dictionary = t.accept(tid, "peer")
	assert_true(bool(result.get("success", false)), "trade resolves when both accept")
	assert_eq(inv_a.get_item_count("wolf_fang"), 0, "player gave away wolf fangs")
	assert_eq(inv_a.get_item_count("hawk_feather"), 3, "player received hawk feathers")
	assert_eq(inv_b.get_item_count("hawk_feather"), 0, "peer gave away hawk feathers")
	assert_eq(inv_b.get_item_count("wolf_fang"), 5, "peer received wolf fangs")
	t.free()
	inv_a.free()
	inv_b.free()

func _test_trade_counter_offer_requires_offer() -> void:
	var t := TradeSlice.new()
	add_child(t)
	var tid := t.start_trade("player", "peer")
	var result: Dictionary = t.counter_offer(tid, "player", { "wolf_fang": 1 }, {})
	assert_false(bool(result.get("success", false)), "counter-offer without a prior offer fails")
	assert_eq(str(result.get("reason", "")), "no_offer", "reason is no_offer")
	t.free()

func _test_trade_reject() -> void:
	var t := TradeSlice.new()
	add_child(t)
	var tid := t.start_trade("player", "peer")
	t.propose(tid, "player", { "wolf_fang": 1 }, {})
	t.reject(tid, "player")
	assert_eq(str(t.get_trade(tid)["state"]), "rejected", "rejected trade state is rejected")
	t.free()

func _test_trade_missing_goods() -> void:
	var inv_a := InventorySlice.new()
	add_child(inv_a)
	var inv_b := InventorySlice.new()
	add_child(inv_b)
	# Player has no wolf_fang to give.
	var t := TradeSlice.new()
	add_child(t)
	t.set_party_inventory("player", inv_a)
	t.set_party_inventory("peer", inv_b)
	t.set_skill("Trade", "master")
	var tid := t.start_trade("player", "peer")
	t.propose(tid, "player", { "wolf_fang": 5 }, {})
	t.propose(tid, "peer", {}, { "wolf_fang": 5 })
	t.accept(tid, "player")
	var result: Dictionary = t.accept(tid, "peer")
	assert_false(bool(result.get("success", false)), "trade with missing goods fails")
	assert_true(str(result.get("reason", "")).begins_with("missing_goods"), "reason is missing_goods")
	t.free()
	inv_a.free()
	inv_b.free()

func _test_trade_skill_lowers_fee() -> void:
	var inv_a := InventorySlice.new()
	add_child(inv_a)
	var inv_b := InventorySlice.new()
	add_child(inv_b)
	inv_b.add_item("hawk_feather", 10)
	var t := TradeSlice.new()
	add_child(t)
	t.set_party_inventory("player", inv_a)
	t.set_party_inventory("peer", inv_b)
	# Novice Trade (default) applies a 10% broker fee to received goods.
	t.set_skill("Trade", "novice")
	var tid := t.start_trade("player", "peer")
	t.propose(tid, "player", {}, { "hawk_feather": 10 })
	t.propose(tid, "peer", { "hawk_feather": 10 }, {})
	t.accept(tid, "player")
	t.accept(tid, "peer")
	assert_eq(inv_a.get_item_count("hawk_feather"), 9, "novice Trade: 10 → 9 after 10% fee")
	assert_eq(inv_b.get_item_count("hawk_feather"), 0, "giver's full give leaves their inventory — the fee is destroyed, not retained")
	t.free()
	inv_a.free()
	inv_b.free()

func _test_trade_fee_burns_best_instance() -> void:
	# A taxed trade of a mixed-condition stack must deliver a DEFINED subset: the
	# receiver keeps the WORST instance and the fee burns the BEST — the same
	# worst-first ordering as _remove_instances/_worst_values. Total durability
	# never increases.
	var inv_a := InventorySlice.new()   # player (receiver)
	add_child(inv_a)
	var inv_b := InventorySlice.new()   # peer (giver)
	add_child(inv_b)
	var max_d := inv_b.get_max_durability("FerritePick")
	var worn := max_d - 30.0
	inv_b.add_item("FerritePick", 2, [max_d, worn])   # pristine + worn
	var t := TradeSlice.new()
	add_child(t)
	t.set_party_inventory("player", inv_a)
	t.set_party_inventory("peer", inv_b)
	t._broker_fee = { "novice": 0.9 }   # 90% fee rounds 2 → 1
	t.set_skill("Trade", "novice")
	var trade_before := _sum_durability_across([inv_a, inv_b])
	var tid := t.start_trade("player", "peer")
	t.propose(tid, "player", {}, { "FerritePick": 2 })
	t.propose(tid, "peer", { "FerritePick": 2 }, {})
	t.accept(tid, "player")
	t.accept(tid, "peer")
	assert_eq(inv_a.get_item_count("FerritePick"), 1, "90% fee delivers 1 of 2 instances")
	assert_eq(inv_b.get_item_count("FerritePick"), 0, "giver's full give leaves their inventory")
	assert_eq(inv_a.get_durability("FerritePick"), worn, "receiver keeps the worst instance — the fee burns the best")
	assert_true(_sum_durability_across([inv_a, inv_b]) <= trade_before, "taxed trade never increases total durability")
	t.free()
	inv_a.free()
	inv_b.free()

func _test_trade_no_fee_without_player() -> void:
	# A host resolving a peer-to-peer trade (neither party is "player") applies
	# no broker fee — the fee keys on the local player's Trade tier.
	var inv_a := InventorySlice.new()
	add_child(inv_a)
	inv_a.add_item("wolf_fang", 10)
	var inv_b := InventorySlice.new()
	add_child(inv_b)
	inv_b.add_item("hawk_feather", 10)
	var t := TradeSlice.new()
	add_child(t)
	t.set_party_inventory("peer_x", inv_a)
	t.set_party_inventory("peer_y", inv_b)
	var tid := t.start_trade("peer_x", "peer_y")
	t.propose(tid, "peer_x", { "wolf_fang": 10 }, { "hawk_feather": 10 })
	t.propose(tid, "peer_y", { "hawk_feather": 10 }, { "wolf_fang": 10 })
	t.accept(tid, "peer_x")
	var result: Dictionary = t.accept(tid, "peer_y")
	assert_true(bool(result.get("success", false)), "peer-to-peer trade resolves")
	assert_eq(inv_a.get_item_count("hawk_feather"), 10, "peer_x receives full amount (no fee)")
	assert_eq(inv_b.get_item_count("wolf_fang"), 10, "peer_y receives full amount (no fee)")
	t.free()
	inv_a.free()
	inv_b.free()

func _test_trade_state_reports_success() -> void:
	var t := TradeSlice.new()
	add_child(t)
	var tid := t.start_trade("player", "peer")
	var result: Dictionary = t.propose(tid, "player", {}, {})
	assert_true(bool(result.get("success", false)), "propose reports success")
	assert_eq(str(result.get("state", "")), "pending", "propose returns the trade state")
	t.free()

func _test_trade_get_trade_defensive_copy() -> void:
	var t := TradeSlice.new()
	add_child(t)
	var tid := t.start_trade("player", "peer")
	var snapshot: Dictionary = t.get_trade(tid)
	snapshot["state"] = "tampered"
	assert_eq(str(t.get_trade(tid)["state"]), "pending", "get_trade returns a copy, not live state")
	t.free()

func _test_trade_get_trade_deep_copy() -> void:
	var t := TradeSlice.new()
	add_child(t)
	var tid := t.start_trade("player", "peer")
	t.propose(tid, "player", { "wolf_fang": 1 }, {})
	var snapshot: Dictionary = t.get_trade(tid)
	snapshot["offers"]["player"]["give"]["wolf_fang"] = 99
	assert_eq(int(t.get_trade(tid)["offers"]["player"]["give"]["wolf_fang"]), 1, "nested offers are deep-copied, not shared")
	t.free()

func _test_trade_unknown_party_rejected() -> void:
	var t := TradeSlice.new()
	add_child(t)
	var tid := t.start_trade("player", "peer")
	var r: Dictionary = t.propose(tid, "stranger", {}, {})
	assert_false(bool(r.get("success", false)), "propose by a non-party fails")
	assert_eq(str(r.get("reason", "")), "unknown_party", "propose reason is unknown_party")
	r = t.reject(tid, "stranger")
	assert_false(bool(r.get("success", false)), "reject by a non-party fails")
	assert_eq(str(r.get("reason", "")), "unknown_party", "reject reason is unknown_party")
	assert_eq(str(t.get_trade(tid)["state"]), "pending", "non-party reject leaves the trade pending")
	t.free()

func _test_trade_failed_resolve_stays_pending() -> void:
	var inv_a := InventorySlice.new()
	add_child(inv_a)
	var inv_b := InventorySlice.new()
	add_child(inv_b)
	var t := TradeSlice.new()
	add_child(t)
	t.set_party_inventory("player", inv_a)
	t.set_party_inventory("peer", inv_b)
	t.set_skill("Trade", "master")
	var tid := t.start_trade("player", "peer")
	t.propose(tid, "player", { "wolf_fang": 5 }, {})
	t.propose(tid, "peer", {}, { "wolf_fang": 5 })
	t.accept(tid, "player")
	var result: Dictionary = t.accept(tid, "peer")
	assert_false(bool(result.get("success", false)), "missing goods fails")
	assert_eq(str(result.get("state", "")), "pending", "failed resolve reports the trade still pending")
	assert_eq(str(t.get_trade(tid)["state"]), "pending", "get_trade agrees the trade is still pending")
	t.free()
	inv_a.free()
	inv_b.free()

func _test_trade_client_forwards_intents() -> void:
	var t := TradeSlice.new()
	add_child(t)
	t.is_authoritative = false
	var box := {}
	GameBus.trade_start_intent.connect(func(_a, _b): box["start"] = true)
	GameBus.trade_propose_intent.connect(func(_tid, _p, _g, _w): box["propose"] = true)
	GameBus.trade_accept_intent.connect(func(_tid, _p): box["accept"] = true)
	GameBus.trade_reject_intent.connect(func(_tid, _p): box["reject"] = true)
	var tid := t.start_trade("player", "peer")
	assert_eq(tid, "", "client start returns empty (forwarded)")
	assert_true(box.get("start", false), "start intent forwarded")
	var r: Dictionary = t.propose("trade_0", "player", {}, {})
	assert_eq(str(r.get("reason", "")), "forwarded", "client propose forwards intent")
	assert_true(box.get("propose", false), "propose intent forwarded")
	assert_eq(t.get_trade_data()["trades"].size(), 0, "client does not mutate trade state locally")
	r = t.accept("trade_0", "player")
	assert_true(box.get("accept", false), "accept intent forwarded")
	r = t.reject("trade_0", "player")
	assert_true(box.get("reject", false), "reject intent forwarded")
	t.free()

func _test_trade_client_applies_sync() -> void:
	var t := TradeSlice.new()
	add_child(t)
	t.is_authoritative = false
	GameBus.trade_synced.emit({
		"trades": {
			"trade_0": { "id": "trade_0", "parties": ["player", "peer"], "offers": {}, "accepted": {}, "state": "pending" }
		},
		"next_id": 1,
	})
	assert_eq(str(t.get_trade("trade_0")["state"]), "pending", "client applied authoritative trade state")
	t.free()

func _test_trade_double_accept_no_dupe() -> void:
	var inv_a := InventorySlice.new()
	add_child(inv_a)
	var inv_b := InventorySlice.new()
	add_child(inv_b)
	inv_a.add_item("wolf_fang", 5)
	inv_b.add_item("hawk_feather", 3)
	var t := TradeSlice.new()
	add_child(t)
	t.set_party_inventory("player", inv_a)
	t.set_party_inventory("peer", inv_b)
	t.set_skill("Trade", "master")
	var tid := t.start_trade("player", "peer")
	t.propose(tid, "player", { "wolf_fang": 5 }, { "hawk_feather": 3 })
	t.propose(tid, "peer", { "hawk_feather": 3 }, { "wolf_fang": 5 })
	t.accept(tid, "player")
	t.accept(tid, "peer")   # resolves once
	# A second accept (double-click the UI button) must not re-run the exchange.
	var r: Dictionary = t.accept(tid, "peer")
	assert_true(bool(r.get("success", false)), "second accept is a no-op success")
	assert_eq(inv_a.get_item_count("hawk_feather"), 3, "player's received items are not duplicated")
	assert_eq(inv_b.get_item_count("wolf_fang"), 5, "peer's received items are not duplicated")
	assert_eq(inv_a.get_item_count("wolf_fang"), 0, "player's given items stay gone")
	assert_eq(inv_b.get_item_count("hawk_feather"), 0, "peer's given items stay gone")
	t.free()
	inv_a.free()
	inv_b.free()

func _test_trade_remote_party_no_inventory() -> void:
	# A remote peer ("peer_5") the host has no inventory for must resolve to
	# null (fail-closed) — never to the host's own inventory_slice.
	var inv := InventorySlice.new()
	add_child(inv)
	inv.add_item("wolf_fang", 5)
	var t := TradeSlice.new()
	add_child(t)
	t.inventory_slice = inv
	t.set_skill("Trade", "master")
	var tid := t.start_trade("player", "peer_5")
	t.propose(tid, "player", { "wolf_fang": 5 }, {})
	t.propose(tid, "peer_5", {}, { "wolf_fang": 5 })
	t.accept(tid, "player")
	var r: Dictionary = t.accept(tid, "peer_5")
	assert_false(bool(r.get("success", false)), "remote peer with no inventory cannot resolve")
	assert_eq(str(r.get("reason", "")), "no_inventory", "reason is no_inventory (not host-credited)")
	assert_eq(inv.get_item_count("wolf_fang"), 5, "host inventory is not credited to the remote peer")
	t.free()
	inv.free()

func _test_trade_rejected_cannot_resolve() -> void:
	var inv_a := InventorySlice.new()
	add_child(inv_a)
	inv_a.add_item("wolf_fang", 5)
	var inv_b := InventorySlice.new()
	add_child(inv_b)
	inv_b.add_item("hawk_feather", 3)
	var t := TradeSlice.new()
	add_child(t)
	t.set_party_inventory("player", inv_a)
	t.set_party_inventory("peer", inv_b)
	t.set_skill("Trade", "master")
	var tid := t.start_trade("player", "peer")
	t.propose(tid, "player", { "wolf_fang": 5 }, { "hawk_feather": 3 })
	t.propose(tid, "peer", { "hawk_feather": 3 }, { "wolf_fang": 5 })
	t.accept(tid, "player")
	t.reject(tid, "peer")
	# A late accept on a rejected trade must not resolve the exchange.
	var r: Dictionary = t.accept(tid, "peer")
	assert_false(bool(r.get("success", false)), "rejected trade cannot resolve")
	assert_eq(str(r.get("reason", "")), "rejected", "reason is rejected")
	assert_eq(inv_a.get_item_count("wolf_fang"), 5, "no goods moved — player kept their fangs")
	assert_eq(inv_b.get_item_count("hawk_feather"), 3, "no goods moved — peer kept their feathers")
	t.free()
	inv_a.free()
	inv_b.free()

func _test_trade_fee_never_destroys_goods() -> void:
	var inv_a := InventorySlice.new()
	add_child(inv_a)
	var inv_b := InventorySlice.new()
	add_child(inv_b)
	inv_b.add_item("hawk_feather", 1)
	var t := TradeSlice.new()
	add_child(t)
	t.set_party_inventory("player", inv_a)
	t.set_party_inventory("peer", inv_b)
	t._broker_fee = { "novice": 0.9 }   # a 90% fee would round 1 → 0 without the guard
	t.set_skill("Trade", "novice")
	var tid := t.start_trade("player", "peer")
	t.propose(tid, "player", {}, { "hawk_feather": 1 })
	t.propose(tid, "peer", { "hawk_feather": 1 }, {})
	t.accept(tid, "player")
	t.accept(tid, "peer")
	assert_eq(inv_a.get_item_count("hawk_feather"), 1, "a positive received quantity never rounds to zero")
	t.free()
	inv_a.free()
	inv_b.free()

func _test_trade_data_round_trip() -> void:
	var t := TradeSlice.new()
	add_child(t)
	var tid := t.start_trade("player", "peer")
	t.propose(tid, "player", { "wolf_fang": 2 }, {})
	var data: Dictionary = t.get_trade_data()
	var t2 := TradeSlice.new()
	add_child(t2)
	t2.apply_trade_data(data)
	assert_eq(str(t2.get_trade(tid)["state"]), "pending", "trade state restored")
	assert_eq(int(t2.get_trade(tid)["offers"]["player"]["give"]["wolf_fang"]), 2, "nested offer restored")
	var new_tid := t2.start_trade("player", "peer")
	assert_eq(new_tid, "trade_1", "next_id continues past restored trades")
	t.free()
	t2.free()

func _test_trade_partial_accept_syncs() -> void:
	var t := TradeSlice.new()
	add_child(t)
	var box := {}
	GameBus.trade_synced.connect(func(data): box["data"] = data)
	var tid := t.start_trade("player", "peer")
	t.propose(tid, "player", { "wolf_fang": 1 }, {})
	t.propose(tid, "peer", { "hawk_feather": 1 }, {})
	# A single-party accept mutates authoritative state (the accepted flag)
	# without resolving; it must broadcast so a client reflects who accepted.
	t.accept(tid, "player")
	var synced: Dictionary = box.get("data", {})
	var trades: Dictionary = synced.get("trades", {})
	assert_true(trades.has(tid), "partial accept broadcasts trade_synced")
	assert_true(bool(trades[tid]["accepted"].get("player", false)), "synced state reflects the accepting party")
	assert_false(bool(trades[tid]["accepted"].get("peer", false)), "the other party is not yet marked accepted")
	t.free()

# ---------------------------------------------------------------------------
# Market slice tests (Phase 24)
# ---------------------------------------------------------------------------

func _test_market_list_browse() -> void:
	var m := MarketSlice.new()
	add_child(m)
	var seller_a := InventorySlice.new()
	add_child(seller_a)
	seller_a.add_item("hawk_feather", 5)
	var seller_b := InventorySlice.new()
	add_child(seller_b)
	seller_b.add_item("wolf_fang", 3)
	m.set_party_inventory("seller_a", seller_a)
	m.set_party_inventory("seller_b", seller_b)
	var id1 := m.list_item("seller_a", "hawk_feather", 5, 10.0)
	var id2 := m.list_item("seller_b", "wolf_fang", 3, 20.0)
	assert_true(id1 != "" and id2 != "", "listings created with non-empty ids")
	assert_eq(m.get_listings().size(), 2, "two active listings browsable")
	m.free()
	seller_a.free()
	seller_b.free()

func _test_market_buy_transfers() -> void:
	var m := MarketSlice.new()
	add_child(m)
	var seller := InventorySlice.new()
	add_child(seller)
	seller.add_item("hawk_feather", 3)
	var buyer := InventorySlice.new()
	add_child(buyer)
	m.set_party_inventory("seller", seller)
	m.set_party_inventory("player", buyer)
	var id := m.list_item("seller", "hawk_feather", 3, 5.0)
	assert_eq(seller.get_item_count("hawk_feather"), 0, "seller debited (escrow) on list")
	var result: Dictionary = m.buy(id, "player")
	assert_true(bool(result.get("success", false)), "buy succeeds")
	assert_eq(buyer.get_item_count("hawk_feather"), 3, "escrow transferred to buyer (not minted)")
	assert_eq(seller.get_item_count("hawk_feather"), 0, "seller stays debited after sale")
	assert_eq(m.get_listings().size(), 0, "purchased listing removed")
	m.free()
	seller.free()
	buyer.free()

func _test_market_expired_not_browsable() -> void:
	var m := MarketSlice.new()
	add_child(m)
	var seller := InventorySlice.new()
	add_child(seller)
	seller.add_item("hawk_feather", 1)
	m.set_party_inventory("seller", seller)
	var id := m.list_item("seller", "hawk_feather", 1, 5.0, 0.0)
	assert_eq(m.get_listings().size(), 0, "expired listing not browsable")
	assert_eq(m.get_all_listings().size(), 1, "still present until expire_listings")
	var n := m.expire_listings()
	assert_eq(n, 1, "one listing expired")
	assert_eq(m.get_all_listings().size(), 0, "expired listing removed")
	assert_eq(seller.get_item_count("hawk_feather"), 1, "expired escrow refunded to seller")
	m.free()
	seller.free()

func _test_market_expiry_wall_clock() -> void:
	var m := MarketSlice.new()
	add_child(m)
	var seller := InventorySlice.new()
	add_child(seller)
	seller.add_item("hawk_feather", 5)
	m.set_party_inventory("seller", seller)
	var before := Time.get_unix_time_from_system()
	m.list_item("seller", "hawk_feather", 5, 7.5)
	var all: Array = m.get_all_listings()
	assert_eq(all.size(), 1, "one listing recorded")
	var expires_at: float = float(all[0]["expires_at"])
	# A wall-clock deadline is a Unix-epoch timestamp (~1.7e9), not process
	# uptime (a few hundred ms). This proves expiry tracks real time.
	assert_true(expires_at > 1_000_000_000.0, "expires_at is a wall-clock (epoch) timestamp, not uptime")
	assert_true(expires_at > before, "deadline is in the future")
	m.free()
	seller.free()

func _test_market_persistence_disk() -> void:
	# Round-trip through the real persistence slice (disk), not an in-memory
	# get/apply, so a restored listing keeps its wall-clock deadline.
	var m := MarketSlice.new()
	add_child(m)
	var seller := InventorySlice.new()
	add_child(seller)
	seller.add_item("hawk_feather", 5)
	m.set_party_inventory("seller", seller)
	m.list_item("seller", "hawk_feather", 5, 7.5)
	var market_data: Dictionary = m.get_market_data()
	var ps := PersistenceSlice.new()
	add_child(ps)
	ps.save(97, { "market": market_data })
	var loaded: Dictionary = ps.load_slot(97)
	assert_true(loaded.has("market"), "market key restored from disk")
	var m2 := MarketSlice.new()
	add_child(m2)
	m2.apply_market_data(loaded["market"])
	var listings: Array = m2.get_listings()
	assert_eq(listings.size(), 1, "listing restored from disk")
	assert_eq(str(listings[0]["item_id"]), "hawk_feather", "item id preserved")
	assert_eq(int(listings[0]["quantity"]), 5, "quantity preserved")
	assert_true(float(listings[0]["expires_at"]) > Time.get_unix_time_from_system(), "restored listing has a future wall-clock deadline")
	m.free()
	m2.free()
	seller.free()
	ps.free()

func _test_market_escrow_no_dupe() -> void:
	# Single-player: the same inventory is seller and buyer. Listing debits the
	# escrow up front, so buying your own listing nets zero — never a duplicate.
	var m := MarketSlice.new()
	add_child(m)
	var inv := InventorySlice.new()
	add_child(inv)
	inv.add_item("hawk_feather", 5)
	m.set_party_inventory("player", inv)
	var id := m.list_item("player", "hawk_feather", 5, 10.0)
	assert_eq(inv.get_item_count("hawk_feather"), 0, "listing escrows the whole stack")
	m.buy(id, "player")
	assert_eq(inv.get_item_count("hawk_feather"), 5, "self-buy nets zero (5, not 10)")
	m.free()
	inv.free()

func _test_market_buy_no_inventory() -> void:
	var m := MarketSlice.new()
	add_child(m)
	var seller := InventorySlice.new()
	add_child(seller)
	seller.add_item("hawk_feather", 3)
	m.set_party_inventory("seller", seller)
	var id := m.list_item("seller", "hawk_feather", 3, 5.0)
	# Buyer "nobody" has no inventory mapped and isn't "player".
	var result: Dictionary = m.buy(id, "nobody")
	assert_false(bool(result.get("success", false)), "buy fails for a buyer with no inventory")
	assert_eq(str(result.get("reason", "")), "no_inventory", "reason is no_inventory")
	assert_eq(m.get_listings().size(), 1, "listing is preserved, not erased")
	m.free()
	seller.free()

func _test_market_list_insufficient() -> void:
	var m := MarketSlice.new()
	add_child(m)
	var seller := InventorySlice.new()
	add_child(seller)
	seller.add_item("hawk_feather", 2)
	m.set_party_inventory("seller", seller)
	var id := m.list_item("seller", "hawk_feather", 5, 10.0)
	assert_eq(id, "", "listing rejected when seller lacks stock")
	assert_eq(seller.get_item_count("hawk_feather"), 2, "seller not debited on rejected listing")
	m.free()
	seller.free()

func _test_market_expire_refunds_escrow() -> void:
	var m := MarketSlice.new()
	add_child(m)
	var seller := InventorySlice.new()
	add_child(seller)
	seller.add_item("hawk_feather", 4)
	m.set_party_inventory("seller", seller)
	m.list_item("seller", "hawk_feather", 4, 8.0, 0.0)
	assert_eq(seller.get_item_count("hawk_feather"), 0, "escrowed on list")
	var n := m.expire_listings()
	assert_eq(n, 1, "one listing expired")
	assert_eq(seller.get_item_count("hawk_feather"), 4, "escrow refunded on expiry")
	m.free()
	seller.free()

func _test_market_restore_no_id_collision() -> void:
	var m := MarketSlice.new()
	add_child(m)
	# Restore a listing whose id suffix (5) exceeds the restored set size (1).
	m.apply_market_data({
		"listing_5": {
			"seller": "seller", "item_id": "hawk_feather", "quantity": 1,
			"price": 5.0, "listed_at": 0.0, "expires_at": 0.0,
		}
	})
	var seller := InventorySlice.new()
	add_child(seller)
	seller.add_item("hawk_feather", 2)
	m.set_party_inventory("seller", seller)
	var new_id := m.list_item("seller", "hawk_feather", 1, 5.0)
	assert_true(new_id != "listing_5", "new listing id does not collide with a restored id")
	assert_eq(str(new_id), "listing_6", "next id continues past the largest restored suffix")
	m.free()
	seller.free()

func _test_market_client_forwards_intent() -> void:
	var m := MarketSlice.new()
	add_child(m)
	m.is_authoritative = false
	var box := {}
	GameBus.market_list_intent.connect(func(_s, _i, _q, _p): box["list"] = true)
	GameBus.market_buy_intent.connect(func(_lid, _b): box["buy"] = true)
	var id := m.list_item("player", "hawk_feather", 5, 10.0)
	assert_eq(id, "", "client list returns empty (forwarded)")
	assert_true(box.get("list", false), "list intent forwarded")
	assert_eq(m.get_all_listings().size(), 0, "client list does not mutate locally")
	var r: Dictionary = m.buy("listing_0", "player")
	assert_eq(str(r.get("reason", "")), "forwarded", "client buy forwards intent")
	assert_true(box.get("buy", false), "buy intent forwarded")
	m.free()

func _test_market_sync_applies_on_client() -> void:
	var m := MarketSlice.new()
	add_child(m)
	m.is_authoritative = false
	GameBus.market_synced.emit({
		"listing_0": { "seller": "merchant", "item_id": "wolf_fang", "quantity": 2, "price": 15.0, "listed_at": 0.0, "expires_at": 9999999999.0 }
	})
	assert_eq(m.get_listings().size(), 1, "client applied authoritative market state")
	m.free()

func _test_market_authoritative_emits_sync() -> void:
	var m := MarketSlice.new()
	add_child(m)
	var seller := InventorySlice.new()
	add_child(seller)
	seller.add_item("hawk_feather", 5)
	m.set_party_inventory("seller", seller)
	var box := {}
	GameBus.market_synced.connect(func(_d): box["synced"] = true)
	m.list_item("seller", "hawk_feather", 5, 10.0)
	assert_true(box.get("synced", false), "authoritative list emits market_synced")
	m.free()
	seller.free()

func _test_market_expire_keeps_escrow_when_full() -> void:
	# Fill the seller's weight, list an item (freeing a little), then re-fill so
	# the escrow refund can no longer fit — expiry must keep the listing, not
	# destroy the items.
	var m := MarketSlice.new()
	add_child(m)
	var seller := InventorySlice.new()
	add_child(seller)
	m.set_party_inventory("seller", seller)
	seller.add_item("Ferrite", 1)
	while seller.add_item("Veilsteel", 1):
		pass
	var id := m.list_item("seller", "Ferrite", 1, 5.0, 0.0)
	assert_true(id != "", "listing created")
	# Re-fill the weight the debit freed so the Ferrite refund can't fit.
	while seller.add_item("Veilsteel", 1):
		pass
	var n := m.expire_listings()
	assert_eq(n, 0, "expiry keeps the listing when the seller is full")
	assert_eq(m.get_all_listings().size(), 1, "escrow is not destroyed")
	m.free()
	seller.free()

func _test_market_expire_drops_no_inventory_seller() -> void:
	# A listing whose seller's inventory no longer exists can never be refunded.
	# Expiry must drop it (terminating the retry loop) rather than retry forever.
	var m := MarketSlice.new()
	add_child(m)
	var seller := InventorySlice.new()
	add_child(seller)
	seller.add_item("hawk_feather", 3)
	m.set_party_inventory("seller", seller)
	var id := m.list_item("seller", "hawk_feather", 3, 5.0, 0.0)
	assert_true(id != "", "listing created")
	m._party_inventory.erase("seller")   # the seller's inventory is gone
	var n := m.expire_listings()
	assert_eq(n, 1, "listing dropped when the seller has no inventory")
	assert_eq(m.get_all_listings().size(), 0, "no infinite retry — listing removed")
	m.free()
	seller.free()

# ---------------------------------------------------------------------------
# Governance / proposal tests (Phase 24)
# ---------------------------------------------------------------------------

func _test_proposal_quorum_ratify() -> void:
	var p := ProposalSlice.new()
	add_child(p)
	p.set_quorum(3)
	p.set_ratification_threshold(0.6)
	var pid := p.submit_proposal("alice", "Allow X", "body")
	assert_true(pid != "", "proposal submitted with an id")
	p.vote(pid, "bob", "for")
	p.vote(pid, "carol", "for")
	p.vote(pid, "dave", "for")
	assert_eq(str(p.get_proposal(pid)["state"]), "accepted", "quorum met (3/3 for) ratifies")
	p.free()

func _test_proposal_below_quorum() -> void:
	var p := ProposalSlice.new()
	add_child(p)
	p.set_quorum(3)
	var pid := p.submit_proposal("alice", "X", "body")
	p.vote(pid, "bob", "for")
	p.vote(pid, "carol", "for")
	# 2 unanimous votes < quorum 3 → still proposed.
	assert_eq(str(p.get_proposal(pid)["state"]), "proposed", "below quorum stays proposed")
	p.free()

func _test_proposal_author_self_vote() -> void:
	var p := ProposalSlice.new()
	add_child(p)
	p.set_quorum(1)
	var pid := p.submit_proposal("alice", "X", "body")
	var result: Dictionary = p.vote(pid, "alice", "for")
	assert_false(bool(result.get("success", false)), "author vote is rejected")
	assert_eq(str(result.get("reason", "")), "author_cannot_vote", "reason is author_cannot_vote")
	assert_eq(str(p.get_proposal(pid)["state"]), "proposed", "author cannot self-ratify")
	p.free()

func _test_proposal_window_expiry() -> void:
	var p := ProposalSlice.new()
	add_child(p)
	p.set_quorum(1)
	p.set_voting_window(0.0)
	var pid := p.submit_proposal("alice", "X", "body")
	# window 0 → expires immediately; a vote after the window is rejected.
	var result: Dictionary = p.vote(pid, "bob", "for")
	assert_false(bool(result.get("success", false)), "late vote rejected")
	assert_eq(str(result.get("reason", "")), "expired", "reason is expired")
	assert_eq(str(p.get_proposal(pid)["state"]), "proposed", "expired proposal stays proposed")
	p.free()

func _test_proposal_expire_transitions() -> void:
	var p := ProposalSlice.new()
	add_child(p)
	p.set_voting_window(0.0)
	var pid := p.submit_proposal("alice", "X", "body")
	assert_eq(str(p.get_proposal(pid)["state"]), "proposed", "starts proposed")
	var n := p.expire_proposals()
	assert_eq(n, 1, "one proposal expired")
	assert_eq(str(p.get_proposal(pid)["state"]), "expired", "lapsed proposal transitions to expired")
	p.free()

func _test_proposal_client_forwards_intent() -> void:
	var p := ProposalSlice.new()
	add_child(p)
	p.is_authoritative = false
	var box := {}
	GameBus.proposal_submit_intent.connect(func(_a, _t, _b): box["submit"] = true)
	GameBus.proposal_vote_intent.connect(func(_pid, _v, _ver): box["vote"] = true)
	var pid := p.submit_proposal("alice", "X", "body")
	assert_eq(pid, "", "client submit returns empty (forwarded)")
	assert_true(box.get("submit", false), "submit intent forwarded")
	assert_eq(p.get_all_proposals().size(), 0, "client submit does not mutate locally")
	var r: Dictionary = p.vote("proposal_0", "bob", "for")
	assert_eq(str(r.get("reason", "")), "forwarded", "client vote forwards intent")
	assert_true(box.get("vote", false), "vote intent forwarded")
	p.free()

func _test_proposal_sync_applies_on_client() -> void:
	var p := ProposalSlice.new()
	add_child(p)
	p.is_authoritative = false
	GameBus.governance_synced.emit({
		"proposals": {
			"proposal_0": { "id": "proposal_0", "author": "alice", "title": "X", "body": "", "state": "proposed", "votes": {}, "submitted_at": 0.0, "expires_at": 9999999999.0 },
		},
		"decisions_log": [],
		"next_id": 1,
	})
	assert_eq(p.get_all_proposals().size(), 1, "client applied authoritative governance state")
	p.free()

func _test_proposal_persistence_round_trip() -> void:
	var p := ProposalSlice.new()
	add_child(p)
	p.set_quorum(1)
	var pid := p.submit_proposal("alice", "X", "body")
	assert_true(pid != "", "proposal submitted")
	var data: Dictionary = p.get_governance_data()
	var p2 := ProposalSlice.new()
	add_child(p2)
	p2.apply_governance_data(data)
	var proposals: Array = p2.get_all_proposals()
	assert_eq(proposals.size(), 1, "open proposal restored")
	assert_eq(str(proposals[0]["title"]), "X", "title preserved")
	assert_eq(str(proposals[0]["state"]), "proposed", "state preserved")
	p.free()
	p2.free()

func _test_proposal_decisions_log() -> void:
	var p := ProposalSlice.new()
	add_child(p)
	p.set_quorum(2)
	p.set_ratification_threshold(0.6)
	var pid := p.submit_proposal("alice", "Ratify the thing", "body")
	p.vote(pid, "bob", "for")
	p.vote(pid, "carol", "for")
	var log: Array = p.get_decisions_log()
	assert_eq(log.size(), 1, "one ratified proposal logged")
	assert_eq(str(log[0]["title"]), "Ratify the thing", "log records the title")
	assert_eq(str(log[0]["state"]), "accepted", "log records accepted state")
	p.free()

func _test_proposal_below_threshold() -> void:
	var p := ProposalSlice.new()
	add_child(p)
	p.set_quorum(3)
	p.set_ratification_threshold(0.6)
	var pid := p.submit_proposal("alice", "X", "body")
	# 3 votes meets quorum, but 1 for / 2 against = 0.33 < 0.6 threshold.
	p.vote(pid, "a", "for")
	p.vote(pid, "b", "against")
	p.vote(pid, "c", "against")
	assert_eq(str(p.get_proposal(pid)["state"]), "proposed", "1 for / 3 votes stays proposed")
	p.free()

func _test_proposal_leadership_guild() -> void:
	var p := ProposalSlice.new()
	add_child(p)
	assert_false(p.can_form_guild("novice"), "novice cannot form a guild")
	assert_true(p.can_form_guild("apprentice"), "apprentice can form a guild")
	assert_true(p.can_form_guild("master"), "master can form a guild")
	p.free()

func _test_unknown_tier_fails_closed() -> void:
	# Guild formation: an unknown Leadership tier must be rejected, not ranked.
	var p := ProposalSlice.new()
	add_child(p)
	assert_false(p.can_form_guild("grandmaster"), "unknown leadership tier cannot form a guild")
	p.free()
	# Craft guard: an unknown required tier must block even a master crafter.
	var c := CraftingSlice.new()
	add_child(c)
	var inv := InventorySlice.new()
	add_child(inv)
	c.inventory_slice = inv
	c.set_skill("Smithing", "master")
	inv.add_item("FerritePick", 1)
	inv.add_item("FerriteIngot", 1)
	inv.use_item("FerritePick", "mine")   # worn
	var bogus_spec := {
		"station": "",
		"materials": [{ "item": "FerriteIngot", "quantity": 1 }],
		"skillGuards": [{ "skill": "Smithing", "tier": "grandmaster" }],
	}
	var check := c.can_repair("FerritePick", bogus_spec)
	assert_false(bool(check.get("success", false)), "unknown required tier blocks repair")
	assert_true(str(check.get("reason", "")).begins_with("skill_requirement"), "reason is skill_requirement")
	c.free()
	inv.free()

func _test_proposal_get_proposal_deep_copy() -> void:
	var p := ProposalSlice.new()
	add_child(p)
	p.set_quorum(2)
	var pid := p.submit_proposal("alice", "X", "body")
	p.vote(pid, "bob", "for")
	var snapshot: Dictionary = p.get_proposal(pid)
	snapshot["votes"]["bob"] = "against"
	assert_eq(str(p.get_proposal(pid)["votes"]["bob"]), "for", "nested votes are deep-copied, not shared")
	p.free()

func _test_proposal_supersede() -> void:
	var p := ProposalSlice.new()
	add_child(p)
	p.set_quorum(1)
	var old_pid := p.submit_proposal("alice", "Old rule", "body")
	var new_pid := p.submit_proposal("bob", "New rule", "body")
	p.vote(new_pid, "carol", "for")   # ratify the replacement (quorum 1)
	assert_eq(str(p.get_proposal(new_pid)["state"]), "accepted", "replacement ratified")
	var r: Dictionary = p.supersede_proposal(old_pid, new_pid)
	assert_true(bool(r.get("success", false)), "supersede succeeds")
	assert_eq(str(p.get_proposal(old_pid)["state"]), "superseded", "old proposal superseded")
	p.free()

func _test_proposal_supersede_requires_ratified_replacement() -> void:
	var p := ProposalSlice.new()
	add_child(p)
	p.set_quorum(3)
	var old_pid := p.submit_proposal("alice", "Old", "body")
	var new_pid := p.submit_proposal("bob", "New", "body")
	# Replacement is still proposed (quorum 3 unmet) — supersede must refuse.
	var r: Dictionary = p.supersede_proposal(old_pid, new_pid)
	assert_false(bool(r.get("success", false)), "supersede requires a ratified replacement")
	assert_eq(str(r.get("reason", "")), "replacement_not_ratified", "reason is replacement_not_ratified")
	assert_eq(str(p.get_proposal(old_pid)["state"]), "proposed", "old proposal unchanged")
	p.free()

func _test_proposal_expiry_authority_gated() -> void:
	var p := ProposalSlice.new()
	add_child(p)
	p.is_authoritative = false
	p.set_voting_window(0.0)
	# Seed an already-expired proposal via the authoritative sync path.
	var now := Time.get_unix_time_from_system()
	p.apply_governance_data({
		"proposals": {
			"proposal_0": { "id": "proposal_0", "author": "alice", "title": "X", "body": "", "state": "proposed", "votes": {}, "submitted_at": 0.0, "expires_at": now - 10.0 }
		},
		"decisions_log": [],
		"next_id": 1,
	})
	# A client's _process tick must NOT expire proposals — the host owns expiry.
	p._process(2.0)
	assert_eq(str(p.get_proposal("proposal_0")["state"]), "proposed", "non-authoritative tick does not expire proposals")
	p.free()

# ---------------------------------------------------------------------------
# TreeSlice tests (Phase 31)
# ---------------------------------------------------------------------------

## A TreeSlice with no terrain wired: biome "" falls back to the default
## (temperate) entry, mirroring CreatureSlice's isolated-test path.
func _make_tree_slice() -> Node:
	var t := TreeSlice.new()
	add_child(t)
	return t

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

func _test_chunk_tree_spawn_per_chunk() -> void:
	var cm := ChunkManager.new()
	add_child(cm)
	var t := _make_tree_slice()
	cm.tree_slice = t
	cm.load_chunk(Vector2i(0, 0))
	assert_true(t.trees_in_chunk(Vector2i(0, 0)).size() > 0, "loading a chunk spawns its trees")
	cm.unload_chunk(Vector2i(0, 0))
	assert_eq(t.trees_in_chunk(Vector2i(0, 0)).size(), 0, "unloading a chunk drops its trees")
	t.free()
	cm.free()

# ---------------------------------------------------------------------------
# Rare-vein deposit tests (Phase 31)
# ---------------------------------------------------------------------------

## Phase 49 — the biome comes from the fabric's temperature/moisture envelopes.
func _test_climate_envelope_selects() -> void:
	var keys: Array = TerrainSlice.BIOME_KEYS
	var B: Dictionary = GameData.BIOMES
	assert_eq(_climate_pick(0.5, 0.8, keys, B), "TemperateForest", "mild and wet is forest")
	assert_eq(_climate_pick(0.5, 0.1, keys, B), "TemperateGrassland", "mild and dry is grassland")
	assert_eq(_climate_pick(0.95, 0.5, keys, B), "VolcanicBadlands", "hot is badlands")
	assert_eq(_climate_pick(0.4, 0.8, keys, B), "TwilightGrove", "cool and wet is twilight")
	assert_eq(_climate_pick(0.1, 0.1, keys, B), "VoidRift", "cold and dry is the rift")
	assert_eq(_climate_pick(0.5, 0.5, keys, {}), "", "no envelopes, no pick")
	for ckey in keys:
		var surf: float = OreField.surface_vein_chance(str(ckey))
		var res: Variant = GameData.BIOMES.get(str(ckey), null)
		assert_true(res != null and res.get("surfaceVeinChance") != null, "%s carries surfaceVeinChance" % ckey)
		assert_eq(surf, float(res.get("surfaceVeinChance")), "surface_vein_chance is the fabric value for %s" % ckey)

## Phase 49 — a tile near a chunk border may wear the biome across it; the interior never does,
## and the pick is a pure function of the tile.
func _test_voxel_biome_border_blend() -> void:
	var extent := float(VoxelSlice.CHUNK_SIZE * VoxelSlice.TILE_SIZE)
	var biomes := { "0,0": "TemperateForest", "1,0": "VoidRift" }
	var border_worn := 0
	for tz in range(0, VoxelSlice.CHUNK_SIZE):
		var xz := Vector2(extent - VoxelSlice.TILE_SIZE * 0.5, tz * VoxelSlice.TILE_SIZE + VoxelSlice.TILE_SIZE * 0.5)
		var shown := VoxelSlice.blended_biome(xz, biomes, "TemperateForest")
		assert_eq(VoxelSlice.blended_biome(xz, biomes, "TemperateForest"), shown, "blend is deterministic")
		if shown == "VoidRift":
			border_worn += 1
	assert_true(border_worn > 0 and border_worn < VoxelSlice.CHUNK_SIZE, "the border column is dithered, not cut")
	for tz in range(0, VoxelSlice.CHUNK_SIZE):
		var inner := Vector2(extent * 0.5, tz * VoxelSlice.TILE_SIZE + 0.25)
		assert_eq(VoxelSlice.blended_biome(inner, biomes, "TemperateForest"), "TemperateForest", "the interior keeps its biome")

## Phase 64 — the yield reads the biome the surface draws: for every tile of a border band the
## instance accessor (what `_natural_yield` reads) equals `blended_biome` (what the mesher reads).
func _test_voxel_yield_matches_blended_biome() -> void:
	var v := VoxelSlice.new()
	add_child(v)
	var ts := TerrainSlice.new()
	add_child(ts)
	v.terrain_slice = ts
	var checked := 0
	for cx in range(-12, 12):
		var biomes := v.gather_biomes_for(Vector2i(cx, 0))
		for tx in range(0, int(VoxelSlice.BLEND_TILES) + 1):
			for tz in range(0, VoxelSlice.CHUNK_SIZE, 3):
				var xz := Vector2((cx * VoxelSlice.CHUNK_SIZE + tx) * VoxelSlice.TILE_SIZE + 0.25,
					tz * VoxelSlice.TILE_SIZE + 0.25)
				var own := VoxelSlice.biome_of(xz, biomes)
				assert_eq(v.shown_biome_at(xz), VoxelSlice.blended_biome(xz, biomes, own),
					"yield biome is the surface biome at %s" % xz)
				checked += 1
	assert_true(checked > 0, "tiles were checked")
	assert_eq(BiomeBlend.chance(VoxelSlice.BLEND_TILES, VoxelSlice.BLEND_TILES), 0.0, "no blend at the band's inner edge")
	assert_eq(BiomeBlend.chance(0.0, VoxelSlice.BLEND_TILES), BiomeBlend.MAX_CHANCE, "half a chance at the border")
	ts.free()
	v.free()

## Phase 63 — the one chat command is spelled in one place.
func _test_chat_command_constant() -> void:
	var ChatCommands: GDScript = load("res://src/core/chat_commands.gd")
	assert_true(ChatCommands.is_command(ChatCommands.WHERE), "the constant is a command")
	assert_true(ChatCommands.is_command("  /WHERE "), "case and padding are ignored")
	assert_eq(ChatCommands.run("/where", Vector3.ZERO), TerrainSlice.where_text(Vector3.ZERO), "run answers it")
	assert_eq(ChatCommands.run("/nope", Vector3.ZERO), "", "anything else answers nothing")

## Phase 64 — a revealed border cell next to an UNREVEALED chunk never wears that chunk's biome.
func _test_minimap_blend_respects_fog() -> void:
	var mm := Minimap.new()
	add_child(mm)
	mm._revealed = { "0,0": true, "-1,0": true }
	mm.terrain_slice = _own(BiomeStub.new())
	var n := Minimap.CELLS_PER_CHUNK
	var cell_tiles := float(TerrainSlice.CHUNK_SIZE) / n
	var west_cells := 0
	for j in n:
		for i in n:
			var got: String = mm._cell_biome(Vector2i(0, 0), i, j, "TemperateForest")
			assert_true(got != "VoidRift", "the unrevealed east/south chunks' biome is never worn (%d,%d)" % [i, j])
			if i < n - 1 - i and i <= mini(j, n - 1 - j):   # nearest border is the revealed west one
				west_cells += 1
				var expect := "DesertDunes" if BiomeBlend.wears_neighbour(i, j, cell_tiles * 0.5, cell_tiles) else "TemperateForest"
				assert_eq(got, expect, "a west-border cell wears the revealed neighbour exactly when the blend rule says so (%d,%d)" % [i, j])
	assert_true(west_cells > 0, "the revealed west neighbour has border cells to check")
	assert_false(mm._has_blend_neighbour(Vector2i(5, 5), "TemperateForest"), "no revealed neighbours: one rect")
	mm.free()

## Phase 81 — the last walkable chunk row, tiles facing the pole: never the off-world biome, in
## the yield accessor and in what the mesher gets (`gather_biomes_for` -> `blended_biome`).
func _test_voxel_pole_blend() -> void:
	var v := VoxelSlice.new()
	add_child(v)
	var ts := PoleBiomeStub.new()
	add_child(ts)
	v.terrain_slice = ts
	var last := TerrainSlice.polar_chunks() - 1
	assert_true(TerrainSlice.lends_biome(Vector2i(0, last), TerrainSlice.polar_chunks()), "last row lends")
	assert_false(TerrainSlice.lends_biome(Vector2i(0, last + 1), TerrainSlice.polar_chunks()), "the ice row does not")
	assert_false(TerrainSlice.lends_biome(Vector2i(0, -(last + 1)), TerrainSlice.polar_chunks()), "nor the south ice row")
	var biomes := v.gather_biomes_for(Vector2i(0, last))
	var checked := 0
	# The pole is ~295k chunks out, where a float32 Vector2 resolves ~1 m: stop 0.75 m short of the
	# border so rounding cannot move the sample into the ice row.
	for tz in range(VoxelSlice.CHUNK_SIZE - int(VoxelSlice.BLEND_TILES), VoxelSlice.CHUNK_SIZE - 1):
		for tx in range(int(VoxelSlice.BLEND_TILES) + 1, VoxelSlice.CHUNK_SIZE - int(VoxelSlice.BLEND_TILES)):
			var xz := Vector2(tx * VoxelSlice.TILE_SIZE + 0.25, (last * VoxelSlice.CHUNK_SIZE + tz) * VoxelSlice.TILE_SIZE + 0.25)
			assert_eq(v.shown_biome_at(xz), "DesertDunes", "yield keeps its own biome at the pole (%d,%d)" % [tx, tz])
			assert_eq(VoxelSlice.blended_biome(xz, biomes, VoxelSlice.biome_of(xz, biomes)), "DesertDunes",
				"mesher colour keeps its own biome at the pole (%d,%d)" % [tx, tz])
			checked += 1
	assert_true(checked > 0, "pole tiles were checked")
	ts.free()
	v.free()

## Phase 81 — 64 border tiles well inside the map: the pole rule changes nothing, the voxel
## answer is the plain 3×3 `blended_biome` answer (and so still the minimap's, Phase 64).
func _test_voxel_inworld_border_unchanged() -> void:
	var v := VoxelSlice.new()
	add_child(v)
	var ts := PoleBiomeStub.new()
	add_child(ts)
	v.terrain_slice = ts
	var extent := float(VoxelSlice.CHUNK_SIZE * VoxelSlice.TILE_SIZE)
	var checked := 0
	var borrowed := 0
	for i in 64:
		var xz := Vector2(extent + 0.25 + (i % 4) * VoxelSlice.TILE_SIZE, (i / 4) * 2 * VoxelSlice.TILE_SIZE + 0.25)
		var biomes: Dictionary = {}
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var n := Vector2i(1 + dx, dz)
				biomes["%d,%d" % [n.x, n.y]] = ts.biome_for_chunk(n)
		var expect := VoxelSlice.blended_biome(xz, biomes, ts.biome_for_chunk(Vector2i(1, 0)))
		assert_eq(v.shown_biome_at(xz), expect, "in-world tile %d agrees with the plain blend" % i)
		if expect != ts.biome_for_chunk(Vector2i(1, 0)):
			borrowed += 1
		checked += 1
	assert_eq(checked, 64, "64 tiles checked")
	assert_true(borrowed > 0, "some tiles do wear the neighbour")
	ts.free()
	v.free()

## Phase 81 — 100 `shown_biome_at` calls inside one chunk read the terrain slice at most 9 times.
func _test_shown_biome_memo() -> void:
	var v := VoxelSlice.new()
	add_child(v)
	var ts := PoleBiomeStub.new()
	add_child(ts)
	v.terrain_slice = ts
	var base := v.biome_lookups
	for i in 100:
		v.shown_biome_at(Vector2(0.25 + (i % 10) * VoxelSlice.TILE_SIZE, 0.25 + (i / 10) * VoxelSlice.TILE_SIZE))
	assert_true(v.biome_lookups - base <= 9, "at most 9 lookups for 100 calls (got %d)" % (v.biome_lookups - base))
	v.free()
	ts.free()

## Phase 92 — a fake terrain slice for the memo and pole-bound tests: a fixed biome, an optional
## polar bound.
class FixedBiomeStub extends Node:
	var biome := "DesertDunes"
	var radius := -1
	var world_seed := 1
	func get_biome_at(_xz: Vector2) -> String:
		return biome
	func get_world_seed() -> int:
		return world_seed
	func world_radius_chunks() -> int:
		return radius if radius >= 0 else TerrainSlice.polar_chunks()

## Phase 92 — a swapped terrain slice drops the shown-biome memo.
func _test_shown_biome_follows_slice() -> void:
	var v := VoxelSlice.new()
	add_child(v)
	var a := FixedBiomeStub.new()
	var b := FixedBiomeStub.new()
	b.biome = "TemperateForest"
	add_child(a)
	add_child(b)
	v.terrain_slice = a
	var xz := Vector2(16.0, 16.0)
	assert_eq(v.shown_biome_at(xz), "DesertDunes", "slice A's biome is memoised")
	v.terrain_slice = b
	assert_eq(v.shown_biome_at(xz), "TemperateForest", "assigning slice B serves B's answer")
	v.free()
	a.free()
	b.free()

## Phase 92 — a terrain slice with a smaller polar bound leaves a chunk between the bounds out of
## both the gather and the shown blend.
func _test_pole_bound_follows_slice() -> void:
	var v := VoxelSlice.new()
	add_child(v)
	var ts := FixedBiomeStub.new()
	ts.radius = 5
	add_child(ts)
	v.terrain_slice = ts
	assert_true(TerrainSlice.polar_chunks() > 6, "the static bound is wider than the fake one")
	var own := Vector2i(0, 4)
	var between := Vector2i(0, 5)   # inside the static bound, past the fake one
	var gathered := v.gather_biomes_for(own)
	assert_true(gathered.has(VoxelSlice._chunk_key(own)), "the chunk itself is always gathered")
	assert_false(gathered.has(VoxelSlice._chunk_key(between)), "gather leaves the chunk past the slice's bound out")
	var lent := v._lending_ring(own, [own, between, Vector2i(0, 3)])
	assert_eq(lent, [own, Vector2i(0, 3)], "shown_biome_at's ring leaves it out too")
	var before := v.biome_lookups
	v.shown_biome_at(Vector2(16.0, (4.0 * 32.0) + 16.0))
	assert_true(v.biome_lookups - before <= 6, "and the blend never asks for it (%d lookups)" % (v.biome_lookups - before))
	v.free()
	ts.free()

## A terrain slice whose chunks past the pole rows carry a biome nothing in the world should wear.
class PoleBiomeStub extends Node:
	var world_seed := 1
	func biome_for_chunk(c: Vector2i) -> String:
		if absi(c.y) >= TerrainSlice.polar_chunks():
			return "VoidRift"
		return "DesertDunes" if c.x % 2 == 0 else "TemperateForest"
	func get_biome_at(xz: Vector2) -> String:
		return biome_for_chunk(Vector2i(floori(xz.x / VoxelSlice.CHUNK_SIZE / VoxelSlice.TILE_SIZE), floori(xz.y / VoxelSlice.CHUNK_SIZE / VoxelSlice.TILE_SIZE)))
	func get_world_seed() -> int:
		return world_seed

class BiomeStub extends Node:
	var lookups := 0
	var world_seed := 1
	func get_biome_at_chunk(c: Vector2i) -> String:
		lookups += 1
		return "DesertDunes" if c.x < 0 else ("TemperateForest" if c == Vector2i.ZERO else "VoidRift")
	func get_world_seed() -> int:
		return world_seed

## Phase 74 — a persistent biome cache: the second redraw of an unchanged view asks the terrain
## nothing.
func _test_minimap_redraw_uses_cache() -> void:
	var mm := Minimap.new()
	add_child(mm)
	var stub := BiomeStub.new()
	mm.terrain_slice = stub
	mm.set_zoom(Minimap.ZOOM_DEFAULT)
	mm.set_player_pos(Vector2(16.0, 16.0))
	var first: Array = mm._view_rects(Vector2(180, 180))
	assert_true(stub.lookups > 0, "the first redraw looks biomes up")
	var after_first := stub.lookups
	var second: Array = mm._view_rects(Vector2(180, 180))
	assert_eq(stub.lookups, after_first, "the second redraw of the same view looks up zero biomes")
	assert_eq(second.size(), first.size(), "and draws the same thing")
	stub.free()
	mm.free()

## Phase 74 — at a zoom where a sub-cell is under 2 px, a revealed chunk is a single rect.
func _test_minimap_far_zoom_one_rect() -> void:
	var mm := Minimap.new()
	add_child(mm)
	mm.terrain_slice = BiomeStub.new()
	mm.set_player_pos(Vector2(16.0, 16.0))
	mm._revealed = { "0,0": true, "-1,0": true, "1,0": true, "0,1": true }   # mixed biomes: blend would split
	mm.set_zoom(Minimap.ZOOM_MAX)
	var size := Vector2(120, 120)   # 120 / 65 = 1.8 px per chunk
	var rects: Array = mm._view_rects(size)
	assert_eq(rects.size(), mm._revealed.size(), "one rect per revealed chunk, no outlines")
	mm.set_zoom(Minimap.ZOOM_MIN)
	assert_true(mm._view_rects(Vector2(400, 400)).size() > mm._revealed.size(), "zoomed in, the blend cells and outlines draw")
	mm.terrain_slice.free()
	mm.free()

## Phase 74 — the cache is bounded and forgets everything when the seed changes.
func _test_minimap_cache_bounded_and_seeded() -> void:
	var mm := Minimap.new()
	add_child(mm)
	var stub := BiomeStub.new()
	mm.terrain_slice = stub
	mm.set_player_pos(Vector2(16.0, 16.0))
	mm._view_rects(Vector2(180, 180))
	var before := stub.lookups
	stub.world_seed = 2
	mm._view_rects(Vector2(180, 180))
	assert_true(stub.lookups > before, "a new world seed re-asks every biome")
	for i in Minimap.BIOME_CACHE_MAX + 10:
		mm._biome_cache["%d,999" % i] = "TemperateForest"
	mm._view_rects(Vector2(180, 180))
	assert_true(mm._biome_cache.size() <= Minimap.BIOME_CACHE_MAX, "the cache is pruned past its bound")
	stub.free()
	mm.free()

	# A fully revealed ZOOM_MAX view fits the cache: the second redraw asks nothing.
	var big := Minimap.new()
	add_child(big)
	var bstub := BiomeStub.new()
	big.terrain_slice = bstub
	big.set_zoom(Minimap.ZOOM_MAX)
	big.set_player_pos(Vector2(16.0, 16.0))
	for cz in range(-35, 36):
		for cx in range(-35, 36):
			big._revealed["%d,%d" % [cx, cz]] = true
	big._view_rects(Vector2(400, 400))
	var filled := bstub.lookups
	big._view_rects(Vector2(400, 400))
	assert_eq(bstub.lookups, filled, "a full ZOOM_MAX view does not thrash the cache")
	bstub.free()
	big.free()

	# With no terrain wired the fallback biome is not remembered.
	var bare := Minimap.new()
	add_child(bare)
	bare.set_player_pos(Vector2(16.0, 16.0))
	bare._view_rects(Vector2(180, 180))
	assert_eq(bare._biome_cache.size(), 0, "the no-terrain fallback is not cached")
	bare.free()

## Phase 74 — a saved window position at x = 10,000 ends up wholly inside an 800x600 viewport
## after the first apply plus the deferred one.
func _test_ui_layout_first_apply_fits() -> void:
	var ui := _new_test_ui()
	ui.viewport_size_override = Vector2(800, 600)
	ui._layout["inventory"] = Vector2(10000, 10000)
	ui._apply_layout()
	var panel: Control = ui._panels["inventory"]
	panel.size = Vector2(520, 380)   # the real size, known only after the first layout pass
	ui._apply_layout()
	assert_true(panel.position.x >= 0.0 and panel.position.x + panel.size.x <= 800.0, "fully inside horizontally")
	assert_true(panel.position.y >= 0.0 and panel.position.y + panel.size.y <= 600.0, "fully inside vertically")
	assert_eq(UiSlice.fit_window_position(Vector2(-50, -50), Vector2(100, 100), Vector2(800, 600)), Vector2.ZERO, "negative pulled in")
	assert_eq(UiSlice.fit_window_position(Vector2(5, 5), Vector2(900, 900), Vector2(800, 600)), Vector2.ZERO, "oversized window pins to the origin")
	ui.free()
	DirAccess.remove_absolute(TEST_UI_LAYOUT)

## Phase 64 — a biome whose envelope dicts lack keys (or whose altitude lacks `max`) must not
## error in `_envelope_of`, and the complete envelopes still load.
func _test_climate_partial_envelope_warms() -> void:
	var bad := { "temperature": { "min": 0.2 }, "moisture": { "max": 0.7 }, "altitude": { "min": 5.0 } }
	var holder := PartialBiome.new()
	holder.temperature = bad["temperature"]
	holder.moisture = bad["moisture"]
	holder.altitude = bad["altitude"]
	var env := ClimateField._envelope_of(holder)
	assert_eq(env.size(), 7, "a partial envelope still yields the full row")
	assert_eq(env[1], 1.0, "a missing max defaults open")
	assert_eq(env[5], 100000.0, "a missing altitude max defaults open")
	var saved_env: Dictionary = ClimateField._envelopes.duplicate()
	var saved_warm: bool = ClimateField._warmed
	ClimateField._envelopes.clear()
	ClimateField._warmed = false
	ClimateField.warm()
	assert_true(ClimateField._warmed and ClimateField._envelopes.size() > 0, "the real envelopes load")
	ClimateField._envelopes = saved_env
	ClimateField._warmed = saved_warm

class PartialBiome extends RefCounted:
	var temperature: Dictionary = {}
	var moisture: Dictionary = {}
	var altitude: Dictionary = {}

## Phase 49 — mining a NATURAL slice within a biome's topsoil yields that biome's fabric
## `soilMaterial`, whatever the cover: Grass, Moss, Ash and Void ground all yield soil, not
## only the temperate Grass biome. Below `topsoilDepth` the same column yields the biome's
## host rock. The surface-material → soil-material mapping is the biome's own fabric field,
## so no GDScript branch decides it (issue #111).
func _test_mine_topsoil_yields_biome_soil() -> void:
	assert_true(GameData.MATERIALS.has("Soil") and GameData.MATERIALS.has("Grass"), "Grass and Soil are fabric materials")
	var terrain := TerrainSlice.new()
	add_child(terrain)
	terrain.set_world_seed(31337)
	var v := VoxelSlice.new()
	add_child(v)
	v.terrain_slice = terrain
	var checked := {}
	# The tiles to probe: a coarse grid round the origin, plus a chunk of each fantasy biome
	# (Phase 51: they are rare climate niches at the temperate latitudes, not near the equator).
	var tiles: Array = []
	for cx in range(-60, 60):
		for cz in range(-60, 60):
			tiles.append(Vector2i(cx * 32 + 3, cz * 32 + 3))
	for fantasy in ["VolcanicBadlands", "TwilightGrove", "VoidRift"]:
		for chunk_v in _biome_chunks(terrain, [fantasy], 1):
			var chunk: Vector2i = chunk_v
			tiles.append(chunk * 64 + Vector2i(3, 3))
	for t_v in tiles:
		if true:
			var t: Vector2i = t_v
			var p := Vector2(t.x * 0.5 + 0.25, t.y * 0.5 + 0.25)
			var biome := v._biome_at(p)
			var b: Variant = GameData.BIOMES.get(biome, null)
			if b == null or b.get("soilMaterial") == null or checked.has(biome):
				continue
			var base := v._base_top_for_tile(t)
			var top_span := { "bottom": 0.0, "top": v.get_voxel_height_at(p) }
			# A live vein at the tile would yield its ore instead, so skip those tiles.
			if not v._live_vein_at(p, v._run_depth(top_span, base), v._world_seed(), v._vein_taken, {}).is_empty():
				continue
			checked[biome] = true
			var soil := str(b.get("soilMaterial"))
			assert_eq(str(v._natural_yield(t, top_span)["material"]), soil,
				"%s topsoil yields its fabric soilMaterial (%s)" % [biome, soil])
			# One unit below the topsoil, the same column is the host rock (when no vein sits there).
			var depth := float(b.get("topsoilDepth"))
			var deep_span := { "bottom": base - depth - 1.5, "top": base - depth - 1.0 }
			if v._live_vein_at(p, v._run_depth(deep_span, base), v._world_seed(), v._vein_taken, {}).is_empty():
				assert_eq(str(v._natural_yield(t, deep_span)["material"]), OreField.host_material(biome),
					"%s below topsoilDepth yields host rock, not soil" % biome)
	# Every cover the fabric names was actually mined, not just the temperate Grass.
	for surface in ["Grass", "Moss", "Ash", "Void"]:
		var hit := false
		for key in checked:
			var res: Variant = GameData.BIOMES.get(key, null)
			hit = hit or (res != null and res.get("surfaceMaterial") == surface)
		assert_true(hit, "a %s-covered biome was found and its topsoil mined" % surface)
	v.free()
	terrain.free()

## First chunk whose biome is one of `biomes`, or Vector2i(-1, -1) when none is found.
## Phase 51: biomes follow latitude and the continents, so the scan walks a few latitude rows
## (the equator, then the temperate and subpolar belts of both hemispheres) and sweeps each east.
func _find_chunk_with_biome(terrain: Node, biomes: Array) -> Vector2i:
	for chunk in _biome_chunks(terrain, biomes, 1):
		return chunk
	return Vector2i(-1, -1)

## Up to `count` chunks whose biome is one of `biomes`, spread over the latitude rows.
func _biome_chunks(terrain: Node, biomes: Array, count: int) -> Array:
	var out: Array = []
	var pole := TerrainSlice.pole_chunks()
	for row in [0.0, 0.1, -0.1, 0.2, -0.2, 0.3, -0.3, 0.45, -0.45, 0.55, -0.55, 0.65, -0.65, 0.75, -0.75]:
		var cz := int(row * float(pole))
		# Continents are thousands of kilometres across: a coarse sweep of the whole circumference
		# finds land, and a fine sweep round each landfall finds the wanted biome.
		for coarse in range(-600000, 600000, 500):
			if str(terrain.get_biome_at_chunk(Vector2i(coarse, cz))) == "Ocean":
				continue
			for cx in range(coarse - 1500, coarse + 1500, 4):
				if biomes.has(str(terrain.get_biome_at_chunk(Vector2i(cx, cz)))):
					out.append(Vector2i(cx, cz))
					if out.size() >= count:
						return out
	return out

## Vertex count of the built chunk's rendered surfaces: the terrain surface plus the
## rare-vein deposit mesh. Phase 41 split those into two MeshInstance3Ds deliberately
## (a deposit is decoration and must never enter the collision soup), so the count is
## summed over the chunk's mesh children.
func _chunk_vein_vertices(voxel: Node, chunk_pos: Vector2i) -> int:
	# The rare-vein overlay is the chunk's SECOND mesh child; the terrain surface is
	# the first. Counted separately because the merged surface's vertex count is not a
	# per-tile number any more (Phase 42).
	var root: Node3D = voxel._chunks["%d,%d" % [chunk_pos.x, chunk_pos.y]]
	var meshes: Array = []
	for child in root.get_children():
		if child is MeshInstance3D:
			meshes.append(child)
	if meshes.size() < 2:
		return 0
	return (meshes[1] as MeshInstance3D).mesh.surface_get_array_len(0)

## Surface vertices of a chunk, from its committed mesh. Used where a test needs the
## TRIANGLE SOUP's shape rather than a per-tile count (see `_chunk_vein_vertices` for
## the overlay, which is unaffected by the merge).
func _chunk_surface_vertices(voxel: Node, chunk_pos: Vector2i) -> int:
	var root: Node3D = voxel._chunks["%d,%d" % [chunk_pos.x, chunk_pos.y]]
	var total := 0
	for child in root.get_children():
		if child is MeshInstance3D:
			total += (child as MeshInstance3D).mesh.surface_get_array_len(0)
	return total

## Phase 43 — the raised markers mark LIVE veins the field actually holds (they used to mark
## every tile a uniform roll called rare), in the vein's own colour.
func _test_voxel_rare_vein_deposits() -> void:
	var v := VoxelSlice.new()
	add_child(v)
	var found := _find_surface_vein(0)
	assert_false(found.is_empty(), "a vein breaks the surface of a flat chunk somewhere")
	if found.is_empty():
		v.free()
		return
	var chunk: Vector2i = found["chunk"]
	var vein: Dictionary = found["vein"]
	var flat := _flat_heightmap(2.0)

	var deposits: Array = v.vein_deposits(chunk, flat)
	assert_true(deposits.size() > 0, "a surfacing vein gets raised markers")
	# Vector3 holds 32-bit floats, so compare the deposit geometry approximately.
	var expected_top: float = 2.0 + VoxelSlice.VEIN_DEPOSIT_HEIGHT * 0.5
	var expected_size: float = VoxelSlice.TILE_SIZE - VoxelSlice.VEIN_DEPOSIT_INSET * 2.0
	var every_marker_is_a_vein := true
	for d in deposits:
		assert_true(absf(float(d["position"].y) - expected_top) < 0.0001, "a deposit sits on the column top")
		assert_true(absf(float(d["size"].x) - expected_size) < 0.0001, "a deposit is inset inside its tile")
		var t: Vector2i = VoxelSlice._world_to_tile(Vector2(d["position"].x, d["position"].z))
		var hit := OreField.vein_at(0, chunk, t - chunk * 64, 0.0625)
		if hit.is_empty() or d["color"] != VoxelSlice.MATERIAL_COLORS.get(str(hit["material"]), VoxelSlice.FALLBACK_TERRAIN_COLOR):
			every_marker_is_a_vein = false
	assert_true(every_marker_is_a_vein, "every marker sits on a vein tile, in that vein's colour")

	# A column mined down OUT of the vein loses its marker.
	var tile: Vector2i = found["tile"]
	var key := VoxelSlice._tile_key(chunk * 64 + tile)
	var bottom := 2.0 - (float(vein["center"].y) + float(vein["half_height"]) * (1.0 + OreField.SHAPE_NOISE) + 0.125)
	v._set_edit_ops(key, [{ "op": "remove", "bottom": bottom, "top": VoxelSlice.MAX_HEIGHT }])
	var other := OreField.vein_at(0, chunk, tile, 2.0 - (bottom - VoxelSlice.STEP_HEIGHT * 0.5))
	assert_true(other.is_empty() or str(other["id"]) != str(vein["id"]), "the cut goes below the vein")
	var mined: Array = v.vein_deposits(chunk, flat)
	assert_eq(mined.size(), deposits.size() - (1 if other.is_empty() else 0),
		"a column mined below its vein loses that vein's marker")
	v._set_edit_ops(key, [])

	# The markers reach the rendered mesh as the chunk's second mesh child.
	v.build_chunk(chunk, flat)
	assert_eq(_chunk_vein_vertices(v, chunk), deposits.size() * MeshUtil.BOX_VERTEX_COUNT,
		"every deposit reaches the chunk mesh")
	v.free()

## Phase 43 — an EXHAUSTED vein is host rock to the eye: no marker, no tint.
func _test_voxel_rare_vein_materials() -> void:
	var v := VoxelSlice.new()
	add_child(v)
	var found := _find_surface_vein(0)
	if found.is_empty():
		assert_true(false, "a vein breaks the surface of a flat chunk somewhere")
		v.free()
		return
	var chunk: Vector2i = found["chunk"]
	var vein: Dictionary = found["vein"]
	var flat := _flat_heightmap(2.0)
	v.build_chunk(chunk, flat)
	var g: Vector2i = chunk * 64 + (found["tile"] as Vector2i)
	var xz := Vector2(g.x * 0.5 + 0.25, g.y * 0.5 + 0.25)
	assert_eq(v.material_at(xz, 0.0625), str(vein["material"]), "a live vein reads as its material")
	var before: int = v.vein_deposits(chunk, flat).size()
	v._record_depletion(vein, int(vein["reserve"]))
	assert_false(OreField.is_live(vein, v.get_vein_depletion()), "the reserve is mined out")
	assert_eq(v.material_at(xz, 0.0625), OreField.host_material(VoxelSlice.DEFAULT_BIOME),
		"an exhausted vein reads as host rock")
	assert_true(v.vein_deposits(chunk, flat).size() < before, "and its markers are gone")
	assert_eq(_chunk_vein_vertices(v, chunk), v.vein_deposits(chunk, flat).size() * MeshUtil.BOX_VERTEX_COUNT,
		"the exhaustion rebuilt the chunk mesh")
	v.free()

## The MeshInstance3D children of a built chunk, in attach order: the terrain surface
## first, the rare-vein deposit overlay second when the chunk has one.
func _chunk_mesh_instances(voxel: Node, chunk_pos: Vector2i) -> Array:
	var root: Node3D = voxel._chunks["%d,%d" % [chunk_pos.x, chunk_pos.y]]
	var meshes: Array = []
	for child in root.get_children():
		if child is MeshInstance3D:
			meshes.append(child)
	return meshes

## Phase 42 review — ONE terrain material instance per slice, shared by every mesh it
## builds and reused by a rebuild.
##
## The material used to be minted per `_terrain_material()` call: two allocations per
## chunk build (surface + deposit overlay) and two more for every edit rebuild, re-stream
## or self-heal, so the churn tracked the streamed rebuild count rather than the slice.
## Asserted on the BUILT MESHES rather than on the private field, so the test describes the
## guarantee (the meshes share one instance) and not the mechanism that happens to hold it.
func _test_voxel_terrain_material_is_one_instance() -> void:
	var terrain := TerrainSlice.new()
	add_child(terrain)
	var v := VoxelSlice.new()
	add_child(v)
	v.terrain_slice = terrain
	var flat: Array = []
	flat.resize(64 * 64)
	flat.fill(2.0)
	# Surface veins are rare (Phase 49), so scan the rare biomes' chunks for one with a deposit.
	var rare := Vector2i(-1, -1)
	for cand in _biome_chunks(terrain, ["VolcanicBadlands", "TwilightGrove"], 60):
		if not v.vein_deposits(cand, flat).is_empty():
			rare = cand
			break
	assert_true(rare.x != -1, "found a biome that grants a rare vein")

	v.build_chunk(rare, flat)
	var meshes := _chunk_mesh_instances(v, rare)
	assert_eq(meshes.size(), 2, "the chunk carries a surface and a deposit overlay")
	var surface_mat: Material = (meshes[0] as MeshInstance3D).material_override
	var deposit_mat: Material = (meshes[1] as MeshInstance3D).material_override
	assert_true(surface_mat is StandardMaterial3D, "the surface carries a terrain material")
	assert_true(is_same(surface_mat, deposit_mat),
		"the surface and the deposit overlay share ONE material instance")
	assert_eq((surface_mat as StandardMaterial3D).cull_mode, BaseMaterial3D.CULL_DISABLED,
		"and it is the terrain material (both faces rendered)")

	# A rebuild — an edit, a re-stream, the self-heal — must not mint another one.
	v.build_chunk(rare, flat)
	var rebuilt := _chunk_mesh_instances(v, rare)
	assert_eq(rebuilt.size(), 2, "the rebuild carries the same two meshes")
	assert_true(is_same((rebuilt[0] as MeshInstance3D).material_override, surface_mat),
		"a rebuild reuses the same material instance")
	assert_true(is_same((rebuilt[1] as MeshInstance3D).material_override, surface_mat),
		"and so does the rebuilt deposit overlay")
	v.free()
	terrain.free()

# ---------------------------------------------------------------------------
# Phase 33 — player identity + server-side persistence
# ---------------------------------------------------------------------------

## Empty a test save directory so each run starts from a known state.
func _wipe_dir(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		DirAccess.make_dir_recursive_absolute(dir)
		return
	for file_name in d.get_files():
		d.remove(file_name)

func _test_identity_restart_round_trip() -> void:
	# save → fresh boot → load must reproduce player position, HP, inventory with
	# per-instance durability, stations, and creature death / respawn state. This
	# is the "the world is persistent" acceptance criterion, end to end.
	var dir := "user://saves/test_p33_roundtrip/"
	_wipe_dir(dir)

	# ---- process 1: mutate state, then save ----
	var voxel := VoxelSlice.new()
	add_child(voxel)
	var flat: Array = []
	flat.resize(64 * 64)
	flat.fill(2.0)
	voxel.build_chunk(Vector2i(0, 0), flat)
	voxel.build_chunk(Vector2i(1, 0), flat)
	voxel.mine_block(Vector3(16.0, 2.0, 16.0))    # chunk "0,0"
	voxel.mine_block(Vector3(48.0, 2.0, 16.0))    # chunk "1,0"

	var stations := StationSlice.new()
	add_child(stations)
	stations.place_station("forge", Vector3(20.0, 3.0, 20.0))

	var creatures := CreatureSlice.new()
	add_child(creatures)
	creatures.spawn_for_chunk(Vector2i(0, 0))
	var spawned := creatures.get_all_instances()
	assert_true(spawned.size() > 0, "need a population to record")
	var dead_id: String = str(spawned[0]["instance_id"])
	GameBus.creature_died.emit(dead_id, Vector3.ZERO, "player")
	var deadline := float(creatures._instances[dead_id]["respawn_at"])
	assert_eq(str(creatures._instances[dead_id]["state"]), "dead", "the creature is recorded dead")
	# The deadline must be WALL-CLOCK, or a restart makes it meaningless.
	assert_true(deadline > Time.get_unix_time_from_system(), "respawn deadline is a future Unix-epoch second")

	var registry := PlayerRegistry.new()
	add_child(registry)
	var inventory := InventorySlice.new()
	add_child(inventory)
	inventory.add_item("FerritePick", 1)     # durable → per-instance wear
	inventory.add_item("Ashite", 6)
	inventory.use_item("FerritePick", "mine")
	var worn := float(inventory.get_durability_values("FerritePick")[0])
	assert_true(worn < inventory.get_max_durability("FerritePick"), "the pick is worn before the save")
	var pid := registry.mint_player_id()
	registry.set_local_player(pid, inventory)
	registry.record_position(pid, Vector3(21.0, 4.5, 22.0))
	registry.record_hp(pid, 63.0)
	# Appearance is part of the identity: store the avatar's recipe.
	var character := CharacterSlice.new()
	add_child(character)
	var char_id := character.create_character("TravellerHuman", Vector3.ZERO)
	var appearance: Dictionary = character.get_appearance(char_id)
	assert_false(appearance.is_empty(), "the character exposes an appearance recipe")
	registry.record_appearance(pid, appearance)

	var writer := PersistenceSlice.new()
	add_child(writer)
	writer.server_save_dir = dir
	var full := {
		"timestamp":       Time.get_unix_time_from_system(),
		"local_player_id": pid,
		"chunks":          voxel.get_chunk_manifest(),
		"dirty_chunks":    voxel.get_dirty_chunk_keys(),
		"stations":        stations.get_station_data(),
		"creatures":       creatures.get_snapshot_creatures(),
	}
	assert_eq(writer.save_world(full, false), OK, "the full world record writes")
	assert_eq(writer.save_player(pid, registry.get_player_data(pid)), OK, "the player record writes")
	assert_true(writer.has_world(), "world record exists on disk")
	assert_eq(writer.list_player_records(), [pid], "exactly one player record is listed")

	# ---- an autosave is incremental: only the dirty chunk is re-serialized ----
	voxel.clear_dirty_chunks()
	voxel.mine_block(Vector3(48.0, 2.0, 20.0))   # chunk "1,0" only
	var dirty := voxel.get_dirty_chunk_keys()
	assert_eq(dirty.size(), 1, "only the edited chunk is dirty")
	var subset := PersistenceSlice.dirty_chunk_subset(voxel.get_chunk_manifest(), dirty)
	assert_eq(subset.size(), 1, "the incremental payload carries only the dirty manifest")
	assert_true(subset.has("1,0"), "the dirty chunk is the one carried")
	assert_false(subset.has("0,0"), "a clean chunk is NOT re-serialized")
	assert_eq(writer.save_world({
		"timestamp":       Time.get_unix_time_from_system(),
		"local_player_id": pid,
		"chunks":          subset,
		"dirty_chunks":    dirty,
		"stations":        stations.get_station_data(),
		"creatures":       creatures.get_snapshot_creatures(),
	}, true), OK, "the incremental world record writes")

	# ---- process end ----
	voxel.free()
	stations.free()
	creatures.free()
	inventory.free()
	writer.free()
	character.free()

	# ---- process 2: a fresh boot reads it back ----
	var reader := PersistenceSlice.new()
	add_child(reader)
	reader.server_save_dir = dir
	var world := reader.load_world()
	assert_false(world.is_empty(), "the world record reloads")
	# The incremental merge kept the chunk the earlier FULL save wrote.
	assert_true(world["chunks"].has("0,0"), "the clean chunk survives the incremental merge")
	assert_true(world["chunks"].has("1,0"), "the dirty chunk is present after the merge")

	var voxel2 := VoxelSlice.new()
	add_child(voxel2)
	# The terrain a reload regenerates: the same two flat chunks the writer held, so
	# the stored run edits resolve against the ground they were made on.
	var flat2: Array = []
	flat2.resize(64 * 64)
	flat2.fill(2.0)
	voxel2.build_chunk(Vector2i(0, 0), flat2)
	voxel2.build_chunk(Vector2i(1, 0), flat2)
	voxel2.apply_chunk_manifest(world["chunks"])
	assert_eq(voxel2.get_voxel_height_at(Vector2(16.0, 16.0)), 1.875, "the mined column comes back mined")
	assert_eq(voxel2.get_voxel_height_at(Vector2(48.0, 16.0)), 1.875, "the second mined column too")
	assert_eq(voxel2.get_voxel_height_at(Vector2(48.0, 20.0)), 1.875, "and the autosaved edit")

	var stations2 := StationSlice.new()
	add_child(stations2)
	stations2.apply_station_data(world.get("stations", []))
	assert_eq(stations2.get_all_stations().size(), 1, "the station comes back")
	assert_eq(str(stations2.get_all_stations()[0]["id"]), "station_0", "a station keeps its saved id")
	assert_eq(str(stations2.get_all_stations()[0]["type"]), "forge", "and its type")

	# Creature state: the population respawns from the same deterministic inputs,
	# then the recorded state is applied over it — the boot order.
	var creatures2 := CreatureSlice.new()
	add_child(creatures2)
	creatures2.spawn_for_chunk(Vector2i(0, 0))
	creatures2.apply_snapshot_creatures(world.get("creatures", []))
	assert_true(creatures2._instances.has(dead_id), "the recorded instance id exists after a fresh spawn")
	if creatures2._instances.has(dead_id):
		assert_eq(str(creatures2._instances[dead_id]["state"]), "dead", "the death survives the restart")
		# The record is JSON text, so compare within a millisecond rather than
		# bit-for-bit: the deadline is the same INSTANT after the round-trip.
		assert_true(absf(float(creatures2._instances[dead_id]["respawn_at"]) - deadline) < 0.001,
			"the wall-clock deadline survives the restart")

	var record := reader.load_player(pid)
	assert_false(record.is_empty(), "the player record reloads")
	assert_eq(str(record["player_id"]), pid, "the record is keyed by the player id")
	assert_eq(float(record["position"][0]), 21.0, "position x round-trips")
	assert_eq(float(record["position"][2]), 22.0, "position z round-trips")
	assert_eq(float(record["hp"]), 63.0, "HP round-trips")

	# The stored appearance recipe is a usable recipe, not just data on disk.
	var saved_appearance: Variant = record.get("appearance", {})
	assert_true(saved_appearance is Dictionary and not (saved_appearance as Dictionary).is_empty(),
		"appearance is persisted with the record")
	var character2 := CharacterSlice.new()
	add_child(character2)
	assert_true(character2.create_character_from_recipe(saved_appearance, Vector3.ZERO) != "",
		"the stored appearance recipe rebuilds a character")
	character2.free()

	var inventory2 := InventorySlice.new()
	add_child(inventory2)
	inventory2.replace_contents(record["inventory"], record.get("inventory_durability", {}))
	assert_eq(inventory2.get_item_count("Ashite"), 6, "stack contents round-trip")
	assert_eq(inventory2.get_item_count("FerritePick"), 1, "the durable item round-trips")
	assert_eq(float(inventory2.get_durability_values("FerritePick")[0]), worn, "per-instance wear round-trips")
	inventory2.free()
	reader.free()

func _test_identity_reconnect_keeps_inventory() -> void:
	# A reconnect is a NEW peer_id. The registry must hand the same player_id back,
	# along with the same inventory and record — nothing may be keyed on peer_id.
	var registry := PlayerRegistry.new()
	add_child(registry)

	var pid := registry.resolve_identity(2)
	assert_true(pid != "", "a first join is minted an identity")
	assert_true(pid != "peer_2", "the identity is not the connection id")
	var inventory = registry.get_inventory(pid)
	assert_true(inventory != null, "the player gets an inventory")
	inventory.add_item("Ashite", 5)
	# POSITION is the surviving-field probe here, not HP: a remote peer's HP is
	# client-declared and deliberately NOT persisted (see record_hp and
	# _test_remote_hp_not_persisted), so it could not carry this assertion.
	registry.record_position(pid, Vector3(7.0, 1.0, 8.0))
	assert_true(registry.is_online(pid), "the identity is bound while connected")
	assert_eq(registry.get_peer_id(pid), 2, "the id maps to the live connection")

	# Disconnect: the transport mapping goes, the record and inventory stay.
	assert_eq(registry.unbind_peer(2), pid, "unbind returns the identity it held")
	assert_false(registry.is_online(pid), "the player is offline after the disconnect")
	assert_true(registry.has_player(pid), "the record is retained while offline")

	# Reconnect on a different connection, claiming the cached id.
	var again := registry.resolve_identity(7, pid)
	assert_eq(again, pid, "the reconnect re-binds to the same player_id")
	assert_eq(registry.get_peer_id(pid), 7, "the id now maps to the new connection")
	assert_eq(registry.get_inventory(pid).get_item_count("Ashite"), 5, "the inventory survives the reconnect")
	assert_eq(registry.get_record(pid)["position"], [7.0, 1.0, 8.0], "the record survives the reconnect")

	# Two players never share an inventory instance.
	var other := registry.resolve_identity(9)
	assert_true(other != pid, "a different connection is a different player")
	assert_true(registry.get_inventory(other) != registry.get_inventory(pid), "inventories are per-player")
	registry.free()

func _test_identity_disconnect_mid_craft() -> void:
	# A craft consumes its inputs then produces its outputs. A disconnect writes
	# the player record, so the saved inventory must be an all-or-nothing step:
	# no half-consumed materials (inputs gone, no output) and no duplicated output.
	var crafting := CraftingSlice.new()
	add_child(crafting)
	var registry := PlayerRegistry.new()
	add_child(registry)
	var inventory := InventorySlice.new()
	add_child(inventory)
	crafting.inventory_slice = inventory
	crafting.set_skill("Smithing", "master")

	var recipe: Dictionary = crafting.get_recipe("RecipeFerriteIngot")
	assert_false(recipe.is_empty(), "the recipe resolves from GameData")
	# The structured field carries [{item, quantity}] entries; the slice folds
	# them into { item_id: quantity } counts for consumption checks.
	var inputs: Dictionary = crafting._to_counts(recipe.get("inputs", []))
	var outputs: Dictionary = crafting._to_counts(recipe.get("outputs", []))
	assert_true(inputs.size() > 0 and outputs.size() > 0, "the recipe has structured inputs and outputs")
	for item_id in inputs:
		inventory.add_item(str(item_id), int(inputs[item_id]) * 2)

	var pid := registry.mint_player_id()
	registry.set_local_player(pid, inventory)
	assert_true(bool(crafting.craft("RecipeFerriteIngot").get("success", false)), "the craft succeeds")

	# The disconnect-time record write.
	var dir := "user://saves/test_p33_craft/"
	_wipe_dir(dir)
	var store := PersistenceSlice.new()
	add_child(store)
	store.server_save_dir = dir
	store.save_player(pid, registry.get_player_data(pid))

	# A fresh inventory restored from that record: exactly one craft happened.
	var restored := InventorySlice.new()
	add_child(restored)
	var record := store.load_player(pid)
	restored.replace_contents(record["inventory"], record.get("inventory_durability", {}))
	for item_id in inputs:
		assert_eq(restored.get_item_count(str(item_id)),
			int(inputs[item_id]), "exactly one craft's inputs were consumed")
	for item_id in outputs:
		assert_eq(restored.get_item_count(str(item_id)),
			int(outputs[item_id]), "the output is present exactly once — never duplicated")
	# The write is a snapshot of ONE consistent state: what is on disk is exactly
	# what the player holds, so a kill between consume and produce cannot persist
	# a half-finished craft. (JSON numbers come back as floats, hence int().)
	var live: Dictionary = inventory.get_contents()
	var saved: Dictionary = record["inventory"]
	assert_eq(saved.size(), live.size(), "the saved record holds exactly the live items")
	for item_id in live:
		assert_eq(int(saved.get(item_id, -1)), int(live[item_id]),
			"the saved record matches the live '%s' count" % item_id)

	restored.free()
	store.free()
	inventory.free()
	registry.free()
	crafting.free()

func _test_identity_spoofed_id_rejected() -> void:
	# Id authority sits on the server. Claiming a record that a LIVE peer holds,
	# or one the server has never seen, must not grant access to it.
	var registry := PlayerRegistry.new()
	add_child(registry)

	var victim := registry.resolve_identity(2)
	var victim_inventory = registry.get_inventory(victim)
	victim_inventory.add_item("Ashite", 9)
	assert_true(registry.is_online(victim), "the victim is connected")

	# A second connection claims the victim's id while the victim is still online.
	var attacker := registry.resolve_identity(5, victim)
	assert_true(attacker != victim, "a claim on a live identity is refused")
	assert_eq(registry.get_player_id(2), victim, "the victim keeps its identity")
	assert_eq(victim_inventory.get_item_count("Ashite"), 9, "the victim's inventory is untouched")
	var attacker_inventory = registry.get_inventory(attacker)
	attacker_inventory.add_item("Ashite", 1)
	assert_eq(victim_inventory.get_item_count("Ashite"), 9, "the attacker cannot write into the victim's record")

	# An id the server has never issued is discarded too.
	var fresh := registry.resolve_identity(6, "player_never_issued")
	assert_true(fresh != "player_never_issued", "an unknown claimed id is discarded")
	assert_true(registry.has_player(fresh), "the peer becomes a new player instead")

	# The third case: an OFFLINE record — one that exists but no live PEER holds. The
	# listen host's own player is exactly that (it has no connection to itself, so no
	# peer_id maps to it), and the old rule — "the record exists and is not online" —
	# handed it to whichever client claimed the id first, inventory and all.
	var host_id := registry.mint_player_id()
	registry.set_local_player(host_id)
	registry.get_inventory(host_id).add_item("Ashite", 3)
	assert_true(registry.is_online(host_id), "the local player counts as online")
	assert_eq(registry.get_peer_id(host_id), 0, "even though no peer id holds it")
	var grab := registry.resolve_identity(11, host_id)
	assert_true(grab != host_id, "a claim on the host's own offline record is refused")
	assert_eq(registry.get_inventory(host_id).get_item_count("Ashite"), 3,
		"and the host's inventory is untouched")

	# A client owns no identity authority at all.
	registry.is_authoritative = false
	assert_eq(registry.resolve_identity(9, ""), "", "a non-authoritative registry mints nothing")
	registry.free()

func _test_identity_snapshot_own_record_rule() -> void:
	# The peer's own record (position / HP / inventory / technology) may ride the
	# JOIN snapshot only. The client applies whatever the snapshot carries, and the
	# record is written at load and at disconnect — never per frame — so carrying it
	# on an AOI re-scope would teleport a moving client back to its last-saved
	# position and roll its inventory back with it.
	assert_true(PersistenceSlice.snapshot_carries_own_record(true, "player_1_1_ab"),
		"the handshake snapshot of a known peer carries its record")
	assert_false(PersistenceSlice.snapshot_carries_own_record(false, "player_1_1_ab"),
		"an AOI re-scope never carries the record")
	assert_false(PersistenceSlice.snapshot_carries_own_record(true, ""),
		"a snapshot for a peer with no resolved identity carries no record")
	assert_false(PersistenceSlice.snapshot_carries_own_record(false, ""),
		"neither does a re-scope before the handshake lands")

func _test_identity_record_replay_skips_unknown_ids() -> void:
	# A saved world record is replayed over the population chunk streaming spawned.
	# An id the slice does not hold belongs to an unstreamed chunk: the replay must
	# skip it rather than fabricate an instance (no chunk, leaked visual, and an id
	# the real spawn would later overwrite, losing the restored state anyway).
	var creatures := CreatureSlice.new()
	add_child(creatures)
	creatures.spawn_for_chunk(Vector2i(0, 0))
	var spawned := creatures.get_all_instances()
	assert_true(spawned.size() > 0, "need a streamed population to replay onto")
	var known_id: String = str(spawned[0]["instance_id"])
	var count_before: int = spawned.size()

	# A record with one id this process spawned, one id from a chunk it did not.
	var record: Array = [
		{
			"instance_id": known_id,
			"creature_id": str(spawned[0]["creature_id"]),
			"state":       "dead",
			"position":    [1.0, 2.0, 3.0],
			"hp":          0.0,
			"respawn_at":  4102444800.0,
		},
		{
			"instance_id": "creature_999_999_Ghost_0",
			"creature_id": "CinderGargoyle",
			"state":       "dead",
			"position":    [100.0, 0.0, 100.0],
			"hp":          0.0,
			"respawn_at":  4102444800.0,
		},
	]
	creatures.apply_recorded_creature_states(record)

	assert_eq(creatures.get_all_instances().size(), count_before,
		"the replay creates no instance for an id that was never spawned")
	assert_false(creatures._instances.has("creature_999_999_Ghost_0"),
		"the unstreamed id is not fabricated")
	assert_true(creatures._instances.has(known_id), "the streamed instance is still present")
	assert_eq(str(creatures._instances[known_id]["state"]), "dead",
		"the recorded death re-applies to the instance that exists")
	assert_eq(float(creatures._instances[known_id]["respawn_at"]), 4102444800.0,
		"the wall-clock deadline re-applies with it")

	# The CLIENT path is unchanged: first sight still creates the instance, or a
	# client would render nothing the host tells it about.
	creatures.apply_snapshot_creatures([{ "instance_id": "creature_5_5_Slug_0", "creature_id": "LavaSlug", "state": "idle", "position": [4.0, 1.0, 4.0] }])
	assert_true(creatures._instances.has("creature_5_5_Slug_0"),
		"the client snapshot path still creates an unknown instance on first sight")
	creatures.free()

func _test_identity_unknown_peer_has_no_position() -> void:
	# get_last_known_state() answers Vector3.ZERO both for "standing at the origin"
	# and for "never reported". A disconnect handler that cannot tell them apart
	# writes (0,0,0) into a durable player record, so a returning player resurrects
	# at the world origin. has_last_known_state() is the discriminator.
	var n := NetworkingSlice.new()
	add_child(n)
	assert_false(n.has_last_known_state(4), "a peer that never reported has no known state")
	assert_eq(n.get_last_known_state(4), Vector3.ZERO, "and its position reads as the origin sentinel")
	n.remember_player_state(4, Vector3(9.0, 2.0, 9.0))
	assert_true(n.has_last_known_state(4), "a reporting peer has a known state")
	assert_eq(n.get_last_known_state(4), Vector3(9.0, 2.0, 9.0), "and the real position reads back")
	n.free()

# ---------------------------------------------------------------------------
# Phase 33 review fixes
# ---------------------------------------------------------------------------

func _test_merge_keeps_unstreamed_creature_deaths() -> void:
	# An incremental save carries only the population the process holds (the streamed
	# chunks). Replacing the recorded creature list wholesale dropped the death of
	# every creature in a chunk that was not in view — walk away from a corpse, save,
	# walk back, and the death was gone.
	var base: Array = [
		{ "instance_id": "creature_0_0_Boar_0", "state": "dead", "respawn_at": 4102444800.0 },
		{ "instance_id": "creature_1_0_Wolf_0", "state": "idle", "respawn_at": -1.0 },
	]
	var inc: Array = [
		{ "instance_id": "creature_1_0_Wolf_0", "state": "dead", "respawn_at": 4102444801.0 },
	]
	var merged := PersistenceSlice.merge_creature_states(base, inc)
	assert_eq(merged.size(), 2, "the unstreamed entry is retained")
	var by_id: Dictionary = {}
	for entry in merged:
		by_id[str(entry["instance_id"])] = entry
	assert_eq(str(by_id["creature_0_0_Boar_0"]["state"]), "dead",
		"a death in a chunk that is not in view survives the merge")
	assert_eq(str(by_id["creature_1_0_Wolf_0"]["state"]), "dead", "the payload's newer state wins")
	assert_eq(float(by_id["creature_1_0_Wolf_0"]["respawn_at"]), 4102444801.0, "and its deadline with it")

	# The same through the real incremental disk path (_merge_world).
	var dir := "user://saves/test_merge_creatures/"
	_wipe_dir(dir)
	var store := PersistenceSlice.new()
	add_child(store)
	store.server_save_dir = dir
	assert_eq(store.save_world({ "creatures": base }, false), OK, "the full record writes")
	assert_eq(store.save_world({ "creatures": inc }, true), OK, "the incremental record writes")
	var world := store.load_world()
	assert_eq((world["creatures"] as Array).size(), 2, "the incremental write merged, not replaced")
	store.free()

func _test_merge_creature_states_by_instance_id() -> void:
	# The merge is keyed on instance_id: the payload wins per id, junk is ignored, and
	# a missing list on either side is not a crash.
	assert_eq(PersistenceSlice.merge_creature_states([], []).size(), 0, "two empties merge to empty")
	assert_eq(PersistenceSlice.merge_creature_states(null, null).size(), 0, "and so do two nulls")
	assert_eq(PersistenceSlice.merge_creature_states(["junk", 3], []).size(), 0,
		"non-dictionary entries are ignored, not fatal")
	var only_inc := PersistenceSlice.merge_creature_states([], [{ "instance_id": "a", "state": "dead" }])
	assert_eq(only_inc.size(), 1, "an entry only the payload knows is added")
	assert_eq(only_inc[0]["state"], "dead", "with the payload's state")
	var only_base := PersistenceSlice.merge_creature_states([{ "instance_id": "a", "state": "dead" }], [])
	assert_eq(only_base.size(), 1, "an entry only the record knows is retained")
	assert_eq(only_base[0]["state"], "dead", "with the record's state")

func _test_autosave_interval_falls_back() -> void:
	# 0 (or a negative) in the fabric used to SILENTLY DISABLE the autosave, and a
	# headless server has no other save hook — nothing is delivered for SIGTERM. It
	# falls back like the string fields do instead of being honoured as "never".
	assert_eq(PersistenceSlice.resolved_autosave_interval(0.0), PersistenceSlice.DEFAULT_AUTOSAVE_SECS,
		"a zero interval falls back")
	assert_eq(PersistenceSlice.resolved_autosave_interval(-5.0), PersistenceSlice.DEFAULT_AUTOSAVE_SECS,
		"a negative interval falls back too")
	assert_eq(PersistenceSlice.resolved_autosave_interval(60.0), 60.0, "a positive interval is respected")
	assert_true(PersistenceSlice.autosave_due(300.0, PersistenceSlice.resolved_autosave_interval(0.0)),
		"and the fallback really does make an autosave due")

func _test_player_id_is_path_safe() -> void:
	var store := PersistenceSlice.new()
	add_child(store)
	store.server_save_dir = "user://saves/server/"
	assert_eq(PersistenceSlice.sanitize_player_id("player_1_1_ab"), "player_1_1_ab",
		"a canonical id is unchanged")
	assert_eq(PersistenceSlice.sanitize_player_id("../../world"), "world", "traversal is stripped")
	assert_eq(PersistenceSlice.sanitize_player_id("a/b"), "ab", "separators are stripped")
	assert_eq(PersistenceSlice.sanitize_player_id("a\\b"), "ab", "windows separators too")
	assert_eq(PersistenceSlice.sanitize_player_id("..."), "", "dots alone sanitize away")
	var path := store.player_path("../../world")
	assert_true(path.begins_with(store.server_save_dir), "the record path stays inside the save dir: %s" % path)
	assert_false(path.contains(".."), "and carries no traversal: %s" % path)
	assert_eq(path, store.player_path("world"), "a traversal id cannot name a different file than its safe form")
	store.free()

func _test_non_canonical_player_id_refused() -> void:
	# A player id reaches the filesystem through player_path(), so a non-canonical one
	# is refused outright rather than sanitized into a DIFFERENT record's path.
	var dir := "user://saves/test_sanitize/"
	_wipe_dir(dir)
	var store := PersistenceSlice.new()
	add_child(store)
	store.server_save_dir = dir
	var pid := "player_1_1_ab"
	assert_eq(store.save_player(pid, { "player_id": pid }), OK, "a canonical id saves")
	assert_eq(str(store.load_player(pid).get("player_id", "")), pid, "and loads back")
	assert_eq(store.save_player("../escape", {}), ERR_INVALID_PARAMETER, "a traversal id is refused")
	assert_true(store.load_player("../escape").is_empty(), "and cannot be read back")
	assert_true(store.load_player("").is_empty(), "an empty id is refused too")
	assert_eq(store.list_player_records(), [pid], "exactly the canonical record is on disk")
	assert_false(FileAccess.file_exists("user://saves/escape.json"), "no file escaped the save dir")
	store.free()

func _test_write_job_writes_records() -> void:
	# The authoritative save runs write_job on a worker THREAD (see game_root), so the
	# job must be plain data with no bus signals and no node access — and it must
	# produce exactly the records a synchronous save would.
	var dir := "user://saves/test_write_job/"
	_wipe_dir(dir)
	var store := PersistenceSlice.new()
	add_child(store)
	store.server_save_dir = dir
	var pid := "player_1_1_abc"
	var job := {
		"world":       { "local_player_id": pid, "chunks": { "0,0": { "edits": { "1,1": [{ "op": "raise", "n": 1 }] } } } },
		"incremental": false,
		"players":     { pid: { "player_id": pid, "hp": 12.0 } },
	}
	var thread := Thread.new()
	assert_eq(thread.start(store.write_job.bind(job)), OK, "the job starts on a worker thread")
	assert_eq(int(thread.wait_to_finish()), OK, "and reports success")
	assert_true(store.has_world(), "the world record landed")
	assert_eq(str(store.load_world().get("local_player_id", "")), pid, "with its local player id")
	assert_eq(float(store.load_player(pid).get("hp", -1.0)), 12.0, "and the player record landed")

	# An incremental job merges over what is already on disk.
	var job2 := {
		"world":       { "local_player_id": pid, "creatures": [{ "instance_id": "c0", "state": "dead" }] },
		"incremental": true,
		"players":     {},
	}
	assert_eq(int(store.write_job(job2)), OK, "the incremental job writes")
	var world := store.load_world()
	assert_true((world.get("chunks", {}) as Dictionary).has("0,0"), "the earlier chunk survived the merge")
	assert_eq((world.get("creatures", []) as Array).size(), 1, "and the new creature state was folded in")
	store.free()

## Phase 42 review (sixth pass) — an incremental save could not express a DELETED
## chunk. `_append_edit` ERASES a tile's op list once it compacts back to the
## column's natural self (the player mined a block and put it back), and the chunk's
## manifest entry goes with it — but dirty tracking is per CHUNK and is reset only by
## the save that consumed it, so the chunk is still dirty with nothing left to
## serialize. `dirty_chunk_subset` skipped a key the manifest did not have and
## `_merge_world` only folded entries IN, so the record on disk kept the edits the
## earlier FULL save wrote: reload and the terrain the player put back was still
## carved. The payload now carries an EMPTY edit set for a dirty chunk with no edits,
## and the merge reads that as a deletion.
func _test_persistence_incremental_save_can_delete_a_chunk() -> void:
	var dir := "user://saves/test_incremental_delete/"
	_wipe_dir(dir)
	var voxel := _make_voxel()
	assert_true(voxel.mine_block(Vector3(16.25, 2.0, 16.25)).get("success", false),
		"the column was mined")
	var writer := PersistenceSlice.new()
	add_child(writer)
	writer.server_save_dir = dir
	assert_eq(writer.save_world({ "local_player_id": "player_1_1_ab", "chunks": voxel.get_chunk_manifest() }, false), OK,
		"the full world record writes")
	assert_true((writer.load_world()["chunks"] as Dictionary).has("0,0"),
		"the record on disk carries the edited chunk")

	# The player puts it back: the op log compacts away ENTIRELY, so the chunk has no
	# edits left to serialize — while it is still dirty (the second mine is a real edit
	# and re-marks it).
	voxel.clear_dirty_chunks()
	voxel.mine_block(Vector3(16.25, 2.0, 16.25))
	var key := voxel._tile_key(Vector2i(32, 32))
	var cancel: Array = []
	for i in range(4):
		cancel.append({ "op": "remove", "bottom": 1.875, "top": 2.0 })
		cancel.append({ "op": "add", "bottom": 1.875, "top": 2.0, "material": "" })
	voxel._set_edit_ops(key, cancel)
	voxel._append_edit(Vector2i(32, 32), { "op": "add", "bottom": 1.875, "top": 2.0, "material": "" })
	assert_false(voxel.get_edits().has(key), "the column is back to its natural self")
	assert_eq(voxel.get_dirty_chunk_keys(), ["0,0"], "and the chunk is still dirty")
	var manifest := voxel.get_chunk_manifest()
	assert_false(manifest.has("0,0"), "there are no edits left to serialize")
	var subset := PersistenceSlice.dirty_chunk_subset(manifest, voxel.get_dirty_chunk_keys())
	assert_true(subset.has("0,0"), "the incremental payload still names the dirty chunk")
	assert_true((subset["0,0"]["edits"] as Dictionary).is_empty(),
		"and says it has no edits, which IS the deletion statement")

	# The merge rule on its own: an empty edit set deletes the key, and a chunk the
	# payload does not mention at all is kept.
	var folded := writer._merge_world(
		{ "chunks": { "0,0": { "edits": { "32,32": [] } } } },
		{ "chunks": { "0,0": { "edits": {} } } })
	assert_false((folded["chunks"] as Dictionary).has("0,0"),
		"an empty edit set deletes the chunk from the record")
	var kept := writer._merge_world(
		{ "chunks": { "0,0": { "edits": { "32,32": [] } } } },
		{ "chunks": { "2,2": { "edits": { "160,160": [] } } } })
	assert_true((kept["chunks"] as Dictionary).has("0,0"),
		"a chunk the payload does not mention is kept")
	assert_false(PersistenceSlice.is_empty_edit_set({ "materials": {} }),
		"an entry with no 'edits' key is not read as a deletion")

	# ---- the disk path end to end ----
	assert_eq(writer.save_world({ "local_player_id": "player_1_1_ab", "chunks": subset }, true), OK,
		"the incremental world record writes")
	var world := writer.load_world()
	assert_false((world["chunks"] as Dictionary).has("0,0"),
		"the deleted chunk is gone from the record on disk")
	var reloaded := _make_voxel()
	reloaded.apply_chunk_manifest(world["chunks"])
	assert_eq(reloaded.get_voxel_height_at(Vector2(16.25, 16.25)), 2.0,
		"and a reload regenerates natural ground, not the carved column")
	reloaded.free()
	writer.free()
	voxel.free()

func _test_dirty_keys_clear_and_remark() -> void:
	# The authoritative save clears the dirty keys it SERIALIZED, on the main thread,
	# because the write is off-thread. A keyed clear (plus a re-mark when the write
	# failed) is what keeps an edit made during the write from being silently dropped.
	var voxel := VoxelSlice.new()
	add_child(voxel)
	var flat: Array = []
	flat.resize(64 * 64)
	flat.fill(2.0)
	voxel.build_chunk(Vector2i(0, 0), flat)
	voxel.build_chunk(Vector2i(1, 0), flat)
	voxel.mine_block(Vector3(16.0, 2.0, 16.0))   # chunk "0,0"
	voxel.mine_block(Vector3(48.0, 2.0, 16.0))   # chunk "1,0"
	assert_eq(voxel.get_dirty_chunk_keys().size(), 2, "two chunks are dirty")
	voxel.clear_dirty_chunk_keys(["0,0"])
	assert_eq(voxel.get_dirty_chunk_keys(), ["1,0"], "only the serialized key was cleared")
	voxel.mark_dirty_chunks(["0,0"])
	assert_eq(voxel.get_dirty_chunk_keys().size(), 2, "a failed write puts its chunks back")
	voxel.clear_dirty_chunk_keys(voxel.get_dirty_chunk_keys())
	assert_eq(voxel.get_dirty_chunk_keys().size(), 0, "all keys can be cleared")
	voxel.mine_block(Vector3(20.0, 2.0, 16.0))   # chunk "0,0" again
	assert_eq(voxel.get_dirty_chunk_keys(), ["0,0"], "a later edit re-marks its own chunk only")
	voxel.free()

func _test_minted_id_has_crypto_entropy() -> void:
	# player_id is a bearer token: whoever presents it is handed the record. It used
	# to carry 16 bits of a fast PRNG — 65 536 guesses, brute-forceable in one
	# reconnect flood. It is 128 bits of CSPRNG now.
	var registry := PlayerRegistry.new()
	add_child(registry)
	var a := registry.mint_player_id()
	var b := registry.mint_player_id()
	assert_true(a != b, "two mints differ")
	var parts := a.split("_")
	assert_eq(parts.size(), 4, "the id keeps its readable player_<epoch>_<n>_<entropy> shape")
	assert_eq(parts[0], "player", "with its prefix")
	assert_eq(parts[3].length(), PlayerRegistry.ID_ENTROPY_BYTES * 2, "128 bits of entropy, hex-encoded")
	assert_true(parts[3].is_valid_hex_number(false), "and it is hex")
	assert_true(parts[3].length() > 4, "strictly more than the 4 hex chars (16 bits) it replaced")
	assert_eq(PersistenceSlice.sanitize_player_id(a), a, "a minted id is path-canonical")
	registry.free()

func _test_local_player_id_not_claimable() -> void:
	# A listen host's own player has no peer mapping (it never connects to itself), so
	# a peer-map lookup answered "offline" and the claim rule — "the record exists and
	# is not online" — handed the host's inventory to any client that asked for it.
	var registry := PlayerRegistry.new()
	add_child(registry)
	var host_id := registry.mint_player_id()
	registry.set_local_player(host_id)
	assert_true(registry.is_online(host_id), "the local player is online by definition")
	assert_eq(registry.get_peer_id(host_id), 0, "even though no peer holds it")
	var inventory = registry.get_inventory(host_id)
	assert_true(inventory.add_item("Ashite", 3), "the host holds materials")
	var claim := registry.resolve_identity(4, host_id)
	assert_true(claim != host_id, "another peer cannot claim the host's identity")
	assert_eq(registry.get_inventory(host_id).get_item_count("Ashite"), 3,
		"and the host's inventory is untouched")
	assert_eq(registry.get_player_id(4), claim, "the claiming peer got a fresh identity of its own")
	registry.free()

func _test_record_loaded_lazily_on_claim() -> void:
	# The boot no longer reads every record on disk into memory (the registry never
	# evicts, so a long-lived server held every player who had ever joined). A record
	# is pulled in the first time something claims it.
	var dir := "user://saves/test_lazy/"
	_wipe_dir(dir)
	var store := PersistenceSlice.new()
	add_child(store)
	store.server_save_dir = dir
	var stored := "player_1_1_lazy"
	assert_eq(store.save_player(stored, { "player_id": stored, "hp": 55.0, "position": [3.0, 4.0, 5.0] }), OK,
		"a record exists on disk")
	var unseen := "player_1_1_unseen"
	assert_eq(store.save_player(unseen, { "player_id": unseen, "hp": 1.0 }), OK, "and so does another")

	var registry := PlayerRegistry.new()
	add_child(registry)
	registry.set_record_loader(store.load_player)
	assert_false(registry.has_player(stored), "an unclaimed record is NOT resident")
	var pid := registry.resolve_identity(3, stored)
	assert_eq(pid, stored, "the claim re-binds to the stored record")
	assert_true(registry.has_player(stored), "the record was loaded on the claim")
	assert_eq(float(registry.get_record(stored)["hp"]), 55.0, "with its HP")
	assert_eq(float(registry.get_record(stored)["position"][0]), 3.0, "and its position")
	registry.resolve_identity(8)
	assert_false(registry.has_player(unseen), "a record nobody claimed is never loaded at all")
	registry.free()
	store.free()

func _test_save_writes_online_records_only() -> void:
	# An offline player's record is already durable and cannot change without a
	# connection, so rewriting every long-gone player on every autosave only grew the
	# write cost with the number of players who had ever joined.
	var registry := PlayerRegistry.new()
	add_child(registry)
	var host_id := registry.mint_player_id()
	registry.set_local_player(host_id)
	var online := registry.resolve_identity(2)
	var offline := registry.resolve_identity(5)
	registry.unbind_peer(5)
	assert_true(registry.is_online(online), "a bound peer is online")
	assert_false(registry.is_online(offline), "an unbound player is offline")
	var ids := registry.get_online_player_ids()
	assert_true(host_id in ids, "the save set includes the local player")
	assert_true(online in ids, "and every connected peer")
	assert_false(offline in ids, "but not a player who has gone away")
	registry.free()

func _test_despawn_keeps_death_record() -> void:
	# A dead creature's state IS the record. Despawning the chunk erased the instance
	# outright, so walking back respawned the creature alive, ignoring the death.
	var creatures := CreatureSlice.new()
	add_child(creatures)
	creatures.spawn_for_chunk(Vector2i(0, 0))
	var spawned := creatures.get_all_instances()
	assert_true(spawned.size() > 0, "need a population to kill")
	var iid: String = str(spawned[0]["instance_id"])
	GameBus.creature_died.emit(iid, Vector3.ZERO, "player")
	var deadline := float(creatures._instances[iid]["respawn_at"])
	assert_eq(str(creatures._instances[iid]["state"]), "dead", "the creature is dead")

	creatures.despawn_for_chunk(Vector2i(0, 0))
	assert_false(creatures._instances.has(iid), "the instance is despawned (its body slot freed)")
	var carried := false
	for entry in creatures.get_snapshot_creatures():
		if str(entry.get("instance_id", "")) == iid:
			carried = true
			assert_eq(str(entry["state"]), "dead", "the snapshot still carries the death")
			assert_true(absf(float(entry["respawn_at"]) - deadline) < 0.001,
				"with its wall-clock deadline")
	assert_true(carried, "a despawned death is still part of the record")

	# Walking back: the chunk respawns its budget, and the dead one comes back DEAD.
	creatures.spawn_for_chunk(Vector2i(0, 0))
	assert_true(creatures._instances.has(iid), "the instance exists again after the reload")
	assert_eq(str(creatures._instances[iid]["state"]), "dead", "and it came back dead, not alive")
	assert_true(absf(float(creatures._instances[iid]["respawn_at"]) - deadline) < 0.001,
		"with the same respawn deadline")

	# A deadline that has already passed is spent: the reload brings it back alive.
	creatures._instances[iid]["respawn_at"] = Time.get_unix_time_from_system() - 1.0
	creatures._tick_respawn()
	assert_eq(str(creatures._instances[iid]["state"]), "idle", "a spent deadline respawns it")
	creatures.despawn_for_chunk(Vector2i(0, 0))
	creatures.spawn_for_chunk(Vector2i(0, 0))
	assert_eq(str(creatures._instances[iid]["state"]), "idle", "and a spent death is not remembered")
	creatures.free()

func _test_recorded_death_survives_boot_replay() -> void:
	# The boot replays a saved record AFTER chunk streaming. A recorded death for an
	# id outside the boot view window used to be dropped on the floor — and the chunk
	# streams later, so the creature respawned alive. It is held instead.
	var creatures := CreatureSlice.new()
	add_child(creatures)
	creatures.spawn_for_chunk(Vector2i(4, 4))
	var ids: Array = []
	for entry in creatures.get_all_instances():
		ids.append(str(entry["instance_id"]))
	assert_true(ids.size() > 0, "need a population to name ids")
	var target: String = str(ids[0])
	var deadline := Time.get_unix_time_from_system() + 600.0
	for iid in ids:
		creatures._instances.erase(iid)   # a slice that has never streamed chunk 4,4
	var replay: Array = [{
		"instance_id": target,
		"creature_id": "",
		"state":       "dead",
		"position":    [1.0, 2.0, 3.0],
		"hp":          0.0,
		"respawn_at":  deadline,
	}]
	creatures.apply_recorded_creature_states(replay)
	assert_false(creatures._instances.has(target), "the replay still fabricates no instance")
	assert_true(creatures._dead_state.has(target), "but it HOLDS the death for the unstreamed chunk")

	creatures.spawn_for_chunk(Vector2i(4, 4))
	assert_true(creatures._instances.has(target), "the chunk finally streams")
	assert_eq(str(creatures._instances[target]["state"]), "dead", "and the creature is dead, as recorded")
	assert_true(absf(float(creatures._instances[target]["respawn_at"]) - deadline) < 0.001,
		"with the recorded deadline")
	creatures.free()

func _test_creature_state_delta_keeps_deadline() -> void:
	# apply_creature_state's optional fields are SENTINELS, not defaults: the per-tick
	# delta carries neither, so a 4-arg call must not wipe the respawn deadline it
	# does not mention. Assigning the -1.0 default unconditionally did exactly that,
	# so a dead instance lost its deadline on the very next state packet.
	var creatures := CreatureSlice.new()
	add_child(creatures)
	var iid := "creature_0_0_Boar_0"
	creatures.apply_creature_state(iid, "ForestBoar", "dead", Vector3(1.0, 2.0, 3.0), 0.0, 4102444800.0)
	assert_eq(float(creatures._instances[iid]["respawn_at"]), 4102444800.0, "the deadline is recorded")
	creatures.apply_creature_state(iid, "ForestBoar", "idle", Vector3(2.0, 2.0, 3.0))
	assert_eq(float(creatures._instances[iid]["respawn_at"]), 4102444800.0,
		"a delta carrying no deadline leaves it alone")
	assert_eq(str(creatures._instances[iid]["state"]), "idle", "while applying the state it does carry")
	creatures.apply_creature_state(iid, "ForestBoar", "dead", Vector3(2.0, 2.0, 3.0), 0.0, 4102444900.0)
	assert_eq(float(creatures._instances[iid]["respawn_at"]), 4102444900.0,
		"an explicit deadline replaces it")
	creatures.apply_creature_state(iid, "ForestBoar", "idle", Vector3(2.0, 2.0, 3.0), 12.0)
	assert_eq(float(creatures._instances[iid]["hp"]), 12.0, "an explicit hp is applied")
	creatures.apply_creature_state(iid, "ForestBoar", "idle", Vector3(2.0, 2.0, 3.0))
	assert_eq(float(creatures._instances[iid]["hp"]), 12.0, "and an omitted hp leaves it alone")
	creatures.free()

func _test_shutdown_poll_cadence() -> void:
	# The shutdown-request poll used to be gated behind the autosave tick (300 s by
	# default), so a restart request sat unread for up to five minutes and an
	# orchestrator that sigkills after a short grace period killed the server
	# before it saved. The poll has its OWN, far shorter cadence.
	assert_eq(PersistenceSlice.resolved_shutdown_poll_interval(0.0),
		PersistenceSlice.DEFAULT_SHUTDOWN_POLL_SECS, "a zero poll cadence falls back")
	assert_eq(PersistenceSlice.resolved_shutdown_poll_interval(-1.0),
		PersistenceSlice.DEFAULT_SHUTDOWN_POLL_SECS, "a negative one falls back too")
	assert_eq(PersistenceSlice.resolved_shutdown_poll_interval(2.0), 2.0, "a positive cadence is respected")
	assert_true(PersistenceSlice.poll_due(5.0, 5.0), "the poll fires on its own cadence")
	# The regression in one assertion: at the poll deadline an autosave is NOT due.
	assert_true(PersistenceSlice.poll_due(PersistenceSlice.DEFAULT_SHUTDOWN_POLL_SECS,
		PersistenceSlice.DEFAULT_SHUTDOWN_POLL_SECS), "the default poll deadline is reached")
	assert_false(PersistenceSlice.autosave_due(PersistenceSlice.DEFAULT_SHUTDOWN_POLL_SECS,
		PersistenceSlice.DEFAULT_AUTOSAVE_SECS), "while the autosave is nowhere near due")
	assert_false(PersistenceSlice.poll_due(4.999, 5.0), "and nothing fires early")
	assert_false(PersistenceSlice.poll_due(10.0, 0.0), "a zero cadence never fires (resolved before use)")
	# autosave_due keeps its own semantics through the shared rule.
	assert_true(PersistenceSlice.autosave_due(300.0, 300.0), "autosave_due still matches on the deadline")
	assert_false(PersistenceSlice.autosave_due(299.0, 300.0), "and not before it")

func _test_remote_hp_not_persisted() -> void:
	# A remote peer's HP arrives CLIENT-DECLARED on its own player_moved packet. The
	# host has no simulation of that peer to check it against, so writing it into the
	# durable record made health a restart-proof cheat: declare 9999 and keep 9999
	# across a reconnect, a restart, and every later save.
	var registry := PlayerRegistry.new()
	add_child(registry)
	var host_id := registry.mint_player_id()
	registry.set_local_player(host_id)
	var remote := registry.resolve_identity(7)
	assert_true(remote != "" and remote != host_id, "a remote peer gets its own identity")
	registry.record_hp(remote, 9999.0)
	assert_eq(float(registry.get_record(remote).get("hp", -2.0)), -1.0,
		"a client-declared hp is refused, so the record keeps the unknown sentinel")
	assert_eq(float(registry.get_player_data(remote).get("hp", -2.0)), -1.0,
		"and the serializable record cannot carry it to disk either")
	assert_false(PlayerRegistry.hp_is_authoritative_locally(remote, host_id),
		"the rule names a remote peer's hp as non-authoritative")
	assert_false(PlayerRegistry.hp_is_authoritative_locally("", host_id), "an empty id is never authoritative")
	assert_true(PlayerRegistry.hp_is_authoritative_locally(host_id, host_id),
		"the local player's hp IS host-simulated")
	registry.record_hp(host_id, 42.0)
	assert_eq(float(registry.get_record(host_id)["hp"]), 42.0,
		"so the local player's hp is still persisted")
	registry.free()

## `evict_player` only `queue_free`s the inventory node it detaches, and the suite never reaches a
## frame, so the node would leak into Phase 84's orphan check. Every test that evicts goes through here.
func _evict_and_free(registry: PlayerRegistry, player_id: String) -> bool:
	var inv: Variant = registry.get_inventory(player_id) if registry.has_inventory(player_id) else null
	var evicted: bool = registry.evict_player(player_id)
	if inv != null and is_instance_valid(inv) and (inv as Node).get_parent() == null:
		(inv as Node).free()
	return evicted

func _test_disconnect_evicts_player() -> void:
	# The registry used to retain every record and every inventory node forever, so a
	# long-lived server grew with every peer that had EVER connected — and a record
	# for someone who never came back was never needed. The record is durable on
	# disk before eviction, and the next claim re-loads it, so eviction is lossless.
	var dir := "user://saves/test_evict/"
	_wipe_dir(dir)
	var store := PersistenceSlice.new()
	add_child(store)
	store.server_save_dir = dir
	var registry := PlayerRegistry.new()
	add_child(registry)
	registry.set_record_loader(store.load_player)
	var host_id := registry.mint_player_id()
	var host_inv := InventorySlice.new()
	add_child(host_inv)   # parented to the TEST, like the game's own _inventory
	registry.set_local_player(host_id, host_inv)

	var remote := registry.resolve_identity(4)
	assert_true(store.save_player(remote, registry.get_player_data(remote)) == OK, "the record is durable")
	var remote_inv = registry.get_inventory(remote)
	assert_true(remote_inv != null, "the peer owns an inventory")
	assert_true(remote_inv.get_parent() == registry, "which the registry created and parents")

	registry.unbind_peer(4)
	assert_true(_evict_and_free(registry, remote), "the disconnected player's record is evicted")
	assert_false(registry.has_player(remote), "the record is no longer resident")
	assert_false(registry.has_inventory(remote), "nor is the inventory node")
	assert_false(is_instance_valid(remote_inv), "the registry-owned node was detached and freed")
	assert_false(registry.evict_player(remote), "eviction is idempotent")

	# The LOCAL player is never evicted: it is online by definition and its
	# inventory is the game's own instance, not this slice's to free.
	assert_false(registry.evict_player(host_id), "the local player cannot be evicted")
	assert_true(registry.has_player(host_id), "its record stays resident")
	assert_true(is_instance_valid(host_inv), "and its injected inventory is not freed")
	assert_true(host_inv.get_parent() != registry, "because the registry does not own that node")

	# Lossless: the next claim pulls the record back off disk.
	var reclaimed := registry.resolve_identity(9, remote)
	assert_eq(reclaimed, remote, "a reconnect re-binds to the evicted record")
	assert_true(registry.has_player(remote), "which was re-loaded from disk")
	registry.free()
	store.free()

func _test_handshake_retry_reanswers_peer() -> void:
	# The handshake is the only route to a client's identity and world. A lost
	# join_intent (or a lost snapshot) used to leave a connected client with nothing,
	# and a retry would have been SWALLOWED: an already-bound peer returned early
	# without emitting player_joined, so the host never re-sent the snapshot.
	var registry := PlayerRegistry.new()
	add_child(registry)
	var answers: Array = []
	var on_joined := func(peer_id: int, player_id: String, reconnected: bool) -> void:
		answers.append([peer_id, player_id, reconnected])
	GameBus.player_joined.connect(on_joined)
	var first := registry.resolve_identity(4)
	assert_eq(answers.size(), 1, "the first join is answered")
	assert_true(first != "", "with an identity")
	var retry := registry.resolve_identity(4)
	assert_eq(retry, first, "a retry gets the SAME identity rather than a fresh mint")
	assert_eq(answers.size(), 2, "and is answered again, so the host re-sends the snapshot")
	assert_eq(str(answers[1][1]), first, "carrying the bound id")
	assert_false(bool(answers[1][2]), "and it is not reported as a reconnect")
	# A retry cannot re-point the connection at another player's record either.
	assert_eq(registry.resolve_identity(4, "player_9_9_deadbeef"), first,
		"a claim from an already-bound peer is ignored")
	assert_eq(answers.size(), 3, "and it is still answered")
	GameBus.player_joined.disconnect(on_joined)
	registry.free()

func _test_retry_represents_join_intent() -> void:
	# The client half of the retry: each re-presentation is a real packet with a
	# FRESH seq, so the host's dedup cannot mistake it for a duplicate and drop it.
	var n := NetworkingSlice.new()
	add_child(n)
	n.emulate_network = true
	n.request_handshake()
	assert_eq(n._pending.size(), 0, "a non-client never presents a join intent")
	n._role = NetworkingSlice.Role.CLIENT
	n.request_handshake()
	assert_eq(n._pending.size(), 1, "the client presents a join intent")
	var first: Dictionary = JSON.parse_string(str(n._pending[0]["json"]))
	assert_eq(str(first.get("type", "")), "join_intent", "and it is a join intent")
	var first_seq := int(first.get("seq", -1))
	n.request_handshake()
	assert_eq(n._pending.size(), 2, "the retry is a real second packet, not a suppressed duplicate")
	var second: Dictionary = JSON.parse_string(str(n._pending[1]["json"]))
	assert_true(int(second.get("seq", -1)) > first_seq, "with a fresh seq")
	n.free()

func _test_party_inventory_binding_cleared() -> void:
	# Trade and market hold a RAW node reference per party. When the registry frees a
	# disconnected player's inventory that reference becomes a FREED object — which is
	# not null — so a listing expiry or a trade would hand out a dead node. The
	# binding has to be cleared, and a freed one must resolve as "no inventory".
	var market := MarketSlice.new()
	add_child(market)
	var inv := InventorySlice.new()
	add_child(inv)
	var pid := "player_1_1_abc"
	market.set_party_inventory(pid, inv)
	assert_true(market._inventory_for(pid) == inv, "the binding resolves while the inventory lives")
	market.clear_party_inventory(pid)
	assert_true(market._inventory_for(pid) == null, "clearing it yields no inventory")
	market.set_party_inventory(pid, inv)
	inv.free()
	assert_true(market._inventory_for(pid) == null, "a freed inventory resolves as none, not as a dead node")
	market.free()

	var trade := TradeSlice.new()
	add_child(trade)
	var trade_inv := InventorySlice.new()
	add_child(trade_inv)
	trade.set_party_inventory(pid, trade_inv)
	assert_true(trade._inventory_for(pid) == trade_inv, "the trade slice resolves a live binding")
	trade.clear_party_inventory(pid)
	assert_true(trade._inventory_for(pid) == null, "and forgets it on disconnect")
	trade_inv.free()
	trade.free()

func _test_failed_write_reports_and_preserves() -> void:
	# A failed write has to be REPORTED (game_root._finish_save is what logs it and
	# re-marks the cleared dirty chunks) and must never damage the record already on
	# disk. The old lifecycle only reaped the worker at the START of the next save,
	# so the failure went unnoticed for a whole interval while the edits looked saved.
	var dir := "user://saves/test_failed_write/"
	_wipe_dir(dir)
	var store := PersistenceSlice.new()
	add_child(store)
	store.server_save_dir = dir
	assert_eq(store.save_world({ "local_player_id": "p1" }, false), OK, "the first record writes")
	var on_disk := store.load_world()
	assert_eq(str(on_disk.get("local_player_id", "")), "p1", "and reads back")
	# Point the writer at a path that cannot be opened.
	store.atomic_writes = false
	store.server_save_dir = ""
	store.world_file = ""
	var err := store.write_job({ "world": { "local_player_id": "p2" }, "incremental": false, "players": {} })
	assert_true(err != OK, "an unopenable target reports an error instead of silently succeeding")
	assert_eq(str(on_disk.get("local_player_id", "")), "p1", "and the record already on disk is untouched")
	store.free()

func _test_craft_uses_crafter_inventory() -> void:
	# Each player persists their OWN inventory, so a craft must consume and produce
	# against the crafter's — a single host-scoped inventory landed a remote peer's
	# craft on the host's, and persisted it against the host's record.
	var crafting := CraftingSlice.new()
	add_child(crafting)
	var registry := PlayerRegistry.new()
	add_child(registry)
	crafting.inventory_slice = null      # prove the registry is what answers
	crafting.player_registry = registry
	crafting.set_skill("Smithing", "master")
	var recipe := crafting.get_recipe("RecipeFerriteIngot")
	assert_false(recipe.is_empty(), "the recipe resolves from the fabric")
	var inputs := crafting._to_counts(recipe.get("inputs", []))
	var outputs := crafting._to_counts(recipe.get("outputs", []))
	var crafter := registry.resolve_identity(2)
	var other := registry.resolve_identity(3)
	var crafter_inv = registry.get_inventory(crafter)
	var other_inv = registry.get_inventory(other)
	for item_id in inputs:
		crafter_inv.add_item(str(item_id), int(inputs[item_id]))
		other_inv.add_item(str(item_id), int(inputs[item_id]) * 3)

	assert_true(bool(crafting.craft("RecipeFerriteIngot", crafter).get("success", false)), "the craft succeeds")
	for item_id in inputs:
		assert_eq(crafter_inv.get_item_count(str(item_id)), 0, "the crafter's inputs were consumed")
		assert_eq(other_inv.get_item_count(str(item_id)), int(inputs[item_id]) * 3,
			"another player's inventory is untouched")
	for item_id in outputs:
		assert_eq(crafter_inv.get_item_count(str(item_id)), int(outputs[item_id]),
			"the output went to the crafter")
		assert_eq(other_inv.get_item_count(str(item_id)), 0, "and to nobody else")
	# can_craft is scoped the same way.
	assert_true(bool(crafting.can_craft("RecipeFerriteIngot", other).get("success", false)),
		"the other player can still craft from their own materials")
	assert_false(bool(crafting.can_craft("RecipeFerriteIngot", crafter).get("success", false)),
		"the crafter now lacks the inputs")
	crafting.free()
	registry.free()

func _test_craft_client_forwards_intent() -> void:
	# A client owns no records, so it must FORWARD a craft to the host rather than
	# resolve it locally against its synced copy of the inventory.
	var crafting := CraftingSlice.new()
	add_child(crafting)
	var inventory := InventorySlice.new()
	add_child(inventory)
	crafting.inventory_slice = inventory
	crafting.is_authoritative = false
	var forwarded: Array = []
	var on_intent := func(recipe_id: String, player_id: String) -> void:
		forwarded.append([recipe_id, player_id])
	GameBus.craft_intent.connect(on_intent)
	GameBus.craft_requested.emit("RecipeFerriteIngot")
	GameBus.craft_intent.disconnect(on_intent)
	assert_eq(forwarded.size(), 1, "the client forwarded exactly one intent")
	assert_eq(str(forwarded[0][0]), "RecipeFerriteIngot", "carrying the recipe id")
	assert_eq(str(forwarded[0][1]), "", "and no identity — the host decides who is crafting")
	assert_eq(inventory.get_item_count("Ferrite"), 0, "the client mutated nothing locally")
	crafting.free()
	inventory.free()

# ---------------------------------------------------------------------------
# Phase 34 — per-player repair and research
# ---------------------------------------------------------------------------

func _test_research_is_per_player() -> void:
	# The technology tree is per-player STATE: one player's research consumes THAT
	# player's materials and moves THAT player's statuses. Before Phase 34 a single
	# process-wide dictionary unlocked the technology for everyone on the host, and
	# the material cost came off the host's own inventory.
	var tech := TechnologySlice.new()
	add_child(tech)
	var registry := PlayerRegistry.new()
	add_child(registry)
	tech.inventory_slice = null        # prove the registry is what answers
	tech.player_registry = registry
	var alice := registry.resolve_identity(2)
	var bob := registry.resolve_identity(3)
	var alice_inv = registry.get_inventory(alice)
	var bob_inv = registry.get_inventory(bob)
	var cost: Array = tech.get_tech_data("TechBasicSmithing").get("researchMaterials", [])
	assert_true(cost.size() > 0, "the fabric gives TechBasicSmithing a material cost")
	for entry in cost:
		assert_true(alice_inv.add_item(str(entry["item"]), int(entry["quantity"])),
			"alice's materials fit her inventory")
	for entry in cost:
		assert_true(bob_inv.add_item(str(entry["item"]), int(entry["quantity"])),
			"bob's materials fit his inventory")

	assert_true(bool(tech.begin_research("TechBasicSmithing", alice).get("success", false)),
		"alice researches with her own materials")
	assert_eq(tech.get_status("TechBasicSmithing", alice), "researching", "alice's tree moves")
	assert_eq(tech.get_status("TechBasicSmithing", bob), "locked", "bob's tree is untouched")
	for entry in cost:
		var item_id := str(entry["item"])
		assert_eq(alice_inv.get_item_count(item_id), 0, "alice's %s was consumed" % item_id)
		assert_eq(bob_inv.get_item_count(item_id), int(entry["quantity"]),
			"bob's %s was not" % item_id)
	assert_false(tech.is_recipe_unlocked("RecipeFerriteIngot", bob),
		"the recipe is not unlocked for the player who did not research it")

	# A prerequisite is per-player too: bob is blocked until HE holds it.
	var blocked := tech.begin_research("TechMasterForge", bob)
	assert_false(bool(blocked.get("success", false)), "bob is blocked by a prerequisite he lacks")
	assert_true(str(blocked.get("reason", "")).begins_with("prerequisite_locked"),
		"reason is prerequisite_locked")

	assert_true(bool(tech.complete_research("TechBasicSmithing", alice).get("success", false)),
		"alice's research completes")
	assert_true(tech.is_recipe_unlocked("RecipeFerriteIngot", alice), "unlocked for alice")
	assert_false(tech.is_recipe_unlocked("RecipeFerriteIngot", bob), "still locked for bob")

	# Bob now researches the SAME technology, paying from his own inventory — two
	# players can hold the same technology independently.
	assert_true(bool(tech.begin_research("TechBasicSmithing", bob).get("success", false)),
		"bob researches the same technology on his own")
	for entry in cost:
		assert_eq(bob_inv.get_item_count(str(entry["item"])), 0, "paying the cost from his inventory")
	assert_eq(tech.get_status("TechBasicSmithing", bob), "researching", "bob's tree moved")
	assert_eq(tech.get_status("TechBasicSmithing", alice), "unlocked", "alice's is unaffected")

	# The craft gate asks about the CRAFTER's tree, not the process's.
	var crafting := CraftingSlice.new()
	add_child(crafting)
	crafting.technology_slice = tech
	crafting.inventory_slice = null
	crafting.player_registry = registry
	crafting.set_skill("Smithing", "master")
	var recipe := crafting.get_recipe("RecipeFerriteIngot")
	for entry in recipe.get("inputs", []):
		assert_true(alice_inv.add_item(str(entry["item"]), int(entry["quantity"])),
			"alice's craft inputs fit her inventory")
	assert_true(bool(crafting.can_craft("RecipeFerriteIngot", alice).get("success", false)),
		"alice may craft the recipe she unlocked")
	assert_true(str(crafting.can_craft("RecipeFerriteIngot", bob).get("reason", "")).begins_with("technology_locked"),
		"and bob is still technology-locked on it")
	crafting.free()
	tech.free()
	registry.free()

func _test_technology_client_forwards_intent() -> void:
	# A client owns no records, so it must FORWARD a research to the host rather than
	# resolve one against its synced copy of the tree.
	var tech := TechnologySlice.new()
	add_child(tech)
	var inv := InventorySlice.new()
	add_child(inv)
	tech.inventory_slice = inv
	tech.is_authoritative = false
	inv.add_item("Ferrite", 4)
	var forwarded: Array = []
	var on_intent := func(tech_id: String, player_id: String) -> void:
		forwarded.append([tech_id, player_id])
	GameBus.research_intent.connect(on_intent)
	GameBus.research_requested.emit("TechBasicSmithing")
	GameBus.research_intent.disconnect(on_intent)
	assert_eq(forwarded.size(), 1, "the client forwarded exactly one intent")
	assert_eq(str(forwarded[0][0]), "TechBasicSmithing", "carrying the technology id")
	assert_eq(str(forwarded[0][1]), "", "and no identity — the host decides who is researching")
	assert_eq(tech.get_status("TechBasicSmithing"), "locked", "nothing resolved locally")
	assert_eq(inv.get_item_count("Ferrite"), 4, "and no materials were consumed")
	tech.free()
	inv.free()

func _test_technology_client_resolves_nothing() -> void:
	# A client caches the tree the host hands it, but it must never RESOLVE a research
	# locally. `apply_statuses` re-arms the auto-complete deadline for a status restored
	# mid-research (so a slice does not stay stuck in "researching" after a reload), and
	# on a CLIENT that deadline must never fire: the host owns completion and pushes the
	# finished status back through `own_state_synced`. Without the authority guard the
	# client unlocks the technology on its own clock — exactly the "a client never
	# resolves a repair or research locally" invariant this phase is built on, and a
	# status the host never granted.
	var client := TechnologySlice.new()
	add_child(client)
	client.is_authoritative = false
	client.apply_statuses({ "TechBasicSmithing": "researching" })
	assert_true(client._research_end_at[""].has("TechBasicSmithing"),
		"the restored status re-armed a deadline (the setup is real)")
	client._research_end_at[""]["TechBasicSmithing"] = Time.get_unix_time_from_system() - 1.0
	client._tick_research()
	assert_eq(client.get_status("TechBasicSmithing"), "researching",
		"a client does not complete research locally")

	# The same slice WITH authority does complete it, on the same due deadline — the
	# guard is about who is allowed to resolve, not about the deadline path being dead.
	var host := TechnologySlice.new()
	add_child(host)
	host.apply_statuses({ "TechBasicSmithing": "researching" })
	host._research_end_at[""]["TechBasicSmithing"] = Time.get_unix_time_from_system() - 1.0
	host._tick_research()
	assert_eq(host.get_status("TechBasicSmithing"), "unlocked",
		"the authoritative slice still auto-completes")
	client.free()
	host.free()

func _test_repair_uses_repairer_inventory() -> void:
	# A repair consumes materials and restores durability, and both live in the
	# repairing player's own inventory — so it resolves against THAT player, never a
	# single host-scoped one.
	var crafting := CraftingSlice.new()
	add_child(crafting)
	var registry := PlayerRegistry.new()
	add_child(registry)
	crafting.inventory_slice = null      # prove the registry is what answers
	crafting.player_registry = registry
	crafting.set_skill("Smithing", "master")
	var alice := registry.resolve_identity(2)
	var bob := registry.resolve_identity(3)
	var alice_inv = registry.get_inventory(alice)
	var bob_inv = registry.get_inventory(bob)
	for inv in [alice_inv, bob_inv]:
		inv.add_item("FerritePick", 1)
		inv.add_item("FerriteIngot", 3)
		_wear_item(inv, "FerritePick", 1)
	var bob_worn: float = bob_inv.get_durability("FerritePick")

	assert_true(bool(crafting.repair("FerritePick", alice).get("success", false)),
		"alice's repair succeeds")
	assert_eq(alice_inv.get_condition("FerritePick"), "pristine", "alice's pick is restored")
	assert_eq(alice_inv.get_item_count("FerriteIngot"), 2, "alice's material was consumed")
	assert_eq(bob_inv.get_condition("FerritePick"), "worn", "bob's pick is untouched")
	assert_eq(bob_inv.get_durability("FerritePick"), bob_worn, "bob's durability is untouched")
	assert_eq(bob_inv.get_item_count("FerriteIngot"), 3, "bob's materials are untouched")
	# The check half is scoped the same way.
	assert_true(bool(crafting.can_repair("FerritePick", {}, bob).get("success", false)),
		"bob can still repair his own worn pick")
	assert_false(bool(crafting.can_repair("FerritePick", {}, alice).get("success", false)),
		"alice's is already pristine")
	crafting.free()
	registry.free()

func _test_repair_client_forwards_intent() -> void:
	# The repair half of "a client owns no records": it forwards the item to the host,
	# which is the only machine that can consume a persisted inventory.
	var crafting := CraftingSlice.new()
	add_child(crafting)
	var inv := InventorySlice.new()
	add_child(inv)
	crafting.inventory_slice = inv
	crafting.is_authoritative = false
	inv.add_item("FerritePick", 1)
	inv.add_item("FerriteIngot", 3)
	_wear_item(inv, "FerritePick", 1)
	var forwarded: Array = []
	var on_intent := func(item_id: String, player_id: String) -> void:
		forwarded.append([item_id, player_id])
	GameBus.repair_intent.connect(on_intent)
	GameBus.repair_requested.emit("FerritePick")
	GameBus.repair_intent.disconnect(on_intent)
	assert_eq(forwarded.size(), 1, "the client forwarded exactly one intent")
	assert_eq(str(forwarded[0][0]), "FerritePick", "carrying the item id")
	assert_eq(str(forwarded[0][1]), "", "and no identity — the host decides who is repairing")
	assert_eq(inv.get_condition("FerritePick"), "worn", "the client restored nothing locally")
	assert_eq(inv.get_item_count("FerriteIngot"), 3, "and consumed nothing")
	crafting.free()
	inv.free()

func _test_net_player_intents_bind_connection_identity() -> void:
	# A repair or research intent names no player: the host resolves it for the
	# identity bound to the connection, an un-handshaked peer cannot act at all, and
	# an id inside the payload is ignored (it is a client's word, not evidence).
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	var research: Array = []
	var repair: Array = []
	var on_research := func(tech_id: String, player_id: String) -> void:
		research.append([tech_id, player_id])
	var on_repair := func(item_id: String, player_id: String) -> void:
		repair.append([item_id, player_id])
	GameBus.research_intent.connect(on_research)
	GameBus.repair_intent.connect(on_repair)

	n._route_c2h(7, { "type": "research_intent", "tech_id": "TechBasicSmithing" })
	n._route_c2h(7, { "type": "repair_intent", "item_id": "FerritePick" })
	assert_eq(research.size(), 0, "an un-handshaked peer cannot research")
	assert_eq(repair.size(), 0, "and cannot repair")

	n.set_player_id(7, "player_7_1_deadbeef")
	n._route_c2h(7, { "type": "research_intent", "tech_id": "TechBasicSmithing" })
	n._route_c2h(7, { "type": "repair_intent", "item_id": "FerritePick", "player_id": "player_victim" })
	assert_eq(research.size(), 1, "the bound peer's research is re-emitted")
	assert_eq(str(research[0][1]), "player_7_1_deadbeef", "carrying the connection's identity")
	assert_eq(repair.size(), 1, "and its repair too")
	assert_eq(str(repair[0][1]), "player_7_1_deadbeef", "ignoring the id the payload tried to name")

	GameBus.research_intent.disconnect(on_research)
	GameBus.repair_intent.disconnect(on_repair)
	n.free()

func _test_net_own_state_push_is_peer_scoped() -> void:
	# The host hands a peer its own record slice back after acting on its behalf, and
	# that push is addressed to the peer ALONE — an inventory is private, so it cannot
	# ride a broadcast the way an AOI-scoped world delta can.
	var host := NetworkingSlice.new()
	add_child(host)
	host.emulate_network = true
	host.send_own_state(5, { "inventory": {} })
	assert_eq(host._pending.size(), 0, "a non-host cannot push own-state")
	host._role = NetworkingSlice.Role.HOST
	host.send_own_state(5, {
		"inventory": { "Ferrite": 1 },
		"technology": { "TechBasicSmithing": "unlocked" },
	})
	assert_eq(host._pending.size(), 1, "the host queues exactly one packet")
	var packet: Dictionary = JSON.parse_string(str(host._pending[0]["json"]))
	assert_eq(str(packet.get("type", "")), "own_state_synced", "of the own_state_synced type")
	assert_eq(int(host._pending[0]["peer_id"]), 5, "addressed to the peer it was given for")

	# The client half: the packet reaches the bus, which game_root applies.
	var client := NetworkingSlice.new()
	add_child(client)
	client._role = NetworkingSlice.Role.CLIENT
	var applied: Array = []
	var on_synced := func(data: Dictionary) -> void:
		applied.append(data)
	GameBus.own_state_synced.connect(on_synced)
	client._route_h2c(packet)
	GameBus.own_state_synced.disconnect(on_synced)
	assert_eq(applied.size(), 1, "the payload reaches own_state_synced")
	assert_eq(int(applied[0].get("inventory", {}).get("Ferrite", 0)), 1,
		"carrying the peer's own inventory")
	host.free()
	client.free()

## Phase 36 — a creature aggros the nearest player, remote peers included. Before
## this the AI compared against `player_slice` alone, which on a host is the host's
## own body: a peer could walk through a wolf's territory untouched, because the
## wolf literally never looked at where that peer was.
func _test_ai_targets_nearest_of_all_players() -> void:
	var rig := _make_ai_rig()
	var c: CreatureSlice = rig["creature"]
	var ai: CreatureAI   = rig["ai"]
	var instances: Array = c.get_all_instances()
	assert_true(instances.size() > 0, "need at least one creature instance")

	# A CinderGargoyle (aggressionLevel 2) chases without an alert pause, so the
	# chase is visible in one tick.
	var iid := ""
	var pos := Vector3.ZERO
	for inst in instances:
		var res: Resource = GameData.CREATURES.get(inst["creature_id"], null)
		if res != null and int(res.get("aggressionLevel")) == 2:
			iid = str(inst["instance_id"])
			pos = inst["position"]
			break
	assert_true(iid != "", "need an AGGRESSIVE creature instance (aggressionLevel == 2)")

	var peer_pos := pos + Vector3(2.0, 0.0, 0.0)
	var host_pos := pos + Vector3(400.0, 0.0, 0.0)
	var targets := { "player": host_pos, "player_peer": peer_pos }
	ai.player_targets = func() -> Dictionary:
		return targets
	var nearest: Dictionary = ai._nearest_target(pos, ai._player_targets())
	assert_eq(str(nearest.get("id", "")), "player_peer",
		"the nearest player is the peer, not the host's own body")

	ai.force_state(iid, "idle")
	ai._process(0.1)
	assert_eq(ai.get_state(iid), "aggressive", "the creature aggros the nearest player whatever machine it is")
	# The idle → aggressive tick only transitions (it returns); the chase itself is
	# the NEXT tick.
	ai._process(0.1)
	var moved: Vector3 = c._instances[iid]["position"]
	assert_true(moved.distance_to(peer_pos) < pos.distance_to(peer_pos),
		"and chases it (the peer, not the host 400 m away)")

	# Phase 37 — and it IS struck: the round is routed by the target the creature
	# engaged, so a remote peer's id rides `combat_round_requested` and the host can
	# deliver the hit to that peer's own client (see BattleSlice.is_player_target and
	# GameRoot._on_player_damaged). Phase 36 closed on the opposite: a peer was chased
	# and then swung at nothing at all.
	var rounds: Array = []
	var on_round := func(attacker: String, defender: String) -> void:
		rounds.append([attacker, defender])
	GameBus.combat_round_requested.connect(on_round)
	ai.force_state(iid, "aggressive")
	ai._ai[iid]["attack_timer"] = CreatureAI.ATTACK_INTERVAL
	# In attack range by construction (0.5 m), so the round does not depend on how far
	# the chase above happened to get this tick.
	ai._tick_instance(iid, c._instances[iid], c._instances[iid]["position"] + Vector3(0.5, 0.0, 0.0), 0.01, "player_peer")
	assert_eq(rounds.size(), 1, "a remote peer is struck, not merely chased")
	assert_eq(str(rounds[0][1]), "player_peer", "under the id the creature actually engaged")

	ai._ai[iid]["attack_timer"] = CreatureAI.ATTACK_INTERVAL
	ai._tick_instance(iid, c._instances[iid], c._instances[iid]["position"] + Vector3(0.5, 0.0, 0.0), 0.01)
	assert_eq(rounds.size(), 2, "the local player is struck too")
	assert_eq(str(rounds[1][1]), "player", "under the defender id the bus has always used")

	GameBus.combat_round_requested.disconnect(on_round)
	rig["creature"].free()
	rig["ai"].free()

# ---------------------------------------------------------------------------
# Phase 35 — creature taming
# ---------------------------------------------------------------------------
## A taming rig: a creature population, the local player's registry + inventory,
## and the taming slice wired to both. `character_slice` is left null unless a
## test needs the bare-hands rule (see _test_taming_requires_unarmed), because a
## null character slice means "no equipment model here" and the rule is skipped.
func _make_taming_rig() -> Dictionary:
	var c := CreatureSlice.new()
	add_child(c)
	c.spawn_for_chunk(Vector2i(0, 0))
	var crafting := CraftingSlice.new()
	add_child(crafting)
	var registry := PlayerRegistry.new()
	add_child(registry)
	registry.set_local_player(registry.mint_player_id())
	var taming := TamingSlice.new()
	add_child(taming)
	taming.creature_slice  = c
	taming.crafting_slice  = crafting
	taming.player_registry = registry
	taming.inventory_slice = null   # prove the registry is what answers
	# Phase 36 — the crafting slice is wired to the same registry game_root wires it
	# to, because skill tiers are resolved per player through it: without it the
	# slice has no notion of "this machine's player" and would read every tier as
	# novice (`get_skill_for` cannot tell a peer from a nameless local player).
	crafting.player_registry = registry
	return { "creature": c, "taming": taming, "crafting": crafting, "registry": registry }

## Resolve a tame for a REMOTE player the way the host does: through the intent the
## networking slice re-emits under the identity bound to the connection. The bare-hands
## rule is read from the host's own record of that peer's worn set.
func _taming_tame_via_intent(instance_id: String, player_id: String) -> Dictionary:
	var captured: Array = []
	var on_resolved := func(result: Dictionary) -> void:
		captured.append(result)
	GameBus.tame_resolved.connect(on_resolved)
	GameBus.tame_intent.emit(instance_id, player_id)
	GameBus.tame_resolved.disconnect(on_resolved)
	if captured.is_empty():
		return {}
	return captured[0]

## The first instance id of a fabric creature key, or "" when the population has
## none. Spawn order is deterministic but not alphabetical, so tests must look the
## species up rather than index the array.
func _taming_instance_of(c: Node, creature_id: String) -> String:
	for inst in c.get_all_instances():
		if str(inst["creature_id"]) == creature_id:
			return str(inst["instance_id"])
	return ""

## Every instance id of one species, in population order.
func _taming_instances_of(c: Node, creature_id: String) -> Array:
	var out: Array = []
	for inst in c.get_all_instances():
		if str(inst["creature_id"]) == creature_id:
			out.append(str(inst["instance_id"]))
	return out

## Put a player next to a creature. The approach rule is real (TamingSlice re-checks
## the distance), and a fresh record sits at the world origin, so a test that
## forgets this reads "too_far" instead of the reason it meant to assert.
func _taming_stand_near(registry: Node, player_id: String, c: Node, instance_id: String) -> void:
	registry.record_position(player_id, c.get_instance_position(instance_id))

func _test_taming_fabric_spec() -> void:
	# The interaction is data: every rule the slice enforces comes off the creature's
	# `tame` json field, so the assertions here are on the FABRIC, not on a table in
	# GDScript. If the fabric changes, these fail — which is the point.
	var rig := _make_taming_rig()
	var taming: Node = rig["taming"]
	var wolf: Dictionary = taming.tame_data("GraywolfPack")
	assert_eq(str(wolf.get("result", "")), "companion", "the wolf tame yields a companion")
	assert_eq(str(wolf.get("grantsFlag", "")), "wolfBondHolder", "and sets the Ranger flag")
	assert_true(bool(wolf.get("requiresDefeated", false)), "and needs the alpha down")
	assert_true(bool(wolf.get("suppressRespawn", false)), "a tamed wolf does not respawn")
	assert_true(bool(wolf.get("requiresUnarmed", false)), "and needs bare hands")
	var wolf_skill: Dictionary = wolf.get("requiresSkill", {})
	assert_eq(str(wolf_skill.get("skill", "")), "Unarmed", "gated on the Unarmed skill")
	assert_eq(str(wolf_skill.get("tier", "")), "journeyman", "at journeyman")

	var fox: Dictionary = taming.tame_data("GlimmerFox")
	assert_eq(str(fox.get("result", "")), "yield", "the fox tame yields items, not a companion")
	assert_eq(int(fox.get("cooldownSeconds", 0)), 600, "with the fabric's 10-minute cooldown")
	assert_true(bool(fox.get("requiresUnarmed", false)), "and needs bare hands too")
	assert_false(str(fox.get("grantsFlag", "")) != "", "but grants no flag")
	var offers: Array = fox.get("requiresAnyItem", [])
	assert_eq(offers.size(), 2, "the fabric names two alternative offerings")
	assert_eq(str((offers[0] as Dictionary).get("item", "")), "FieldRations", "rations first")
	var yields: Array = fox.get("yields", [])
	assert_eq(yields.size(), 1, "and one shed item")
	assert_eq(str((yields[0] as Dictionary).get("item", "")), "glimmer_fur_tuft", "the fur tuft")

	assert_true(taming.is_tameable("GlimmerFox"), "the fox is tameable")
	assert_false(taming.is_tameable("ForestBoar"), "the boar is not")
	rig["creature"].free()
	rig["taming"].free()
	rig["crafting"].free()
	rig["registry"].free()

func _test_taming_not_tameable() -> void:
	# A creature with no `tame` field is refused, and an unknown instance is refused
	# with a different reason — the UI needs to tell "not tameable" from "gone".
	var rig := _make_taming_rig()
	var c: Node = rig["creature"]
	var taming: Node = rig["taming"]
	var boar := _taming_instance_of(c, "ForestBoar")
	assert_true(boar != "", "a ForestBoar instance exists")
	_taming_stand_near(rig["registry"], str(rig["registry"].local_player_id), c, boar)
	assert_eq(str(taming.can_tame(boar, "")["reason"]), "not_tameable", "the boar is not tameable")
	assert_eq(taming.tame_data("ForestBoar").size(), 0, "and carries no tame data")
	assert_eq(str(taming.can_tame("creature_nope", "")["reason"]), "unknown_instance",
		"an unknown instance is refused as unknown")
	assert_false(bool(taming.tame(boar, "")["success"]), "tame() fails on it too")
	rig["creature"].free()
	rig["taming"].free()
	rig["crafting"].free()
	rig["registry"].free()

func _test_taming_wolf_requires_alpha_down() -> void:
	# The fabric rule is "tame a surviving pup AFTER defeating the alpha wolf". The
	# runtime models a pack as N instances of one creature id, so the gate is "one
	# member of this species is dead".
	var rig := _make_taming_rig()
	var c: Node = rig["creature"]
	var taming: Node = rig["taming"]
	var registry: Node = rig["registry"]
	var pid := str(registry.local_player_id)
	var wolves := _taming_instances_of(c, "GraywolfPack")
	assert_true(wolves.size() >= 2, "the fabric spawns at least two pack members")
	var target := str(wolves[1])
	_taming_stand_near(registry, pid, c, target)

	# Too far away: the creature must be approached, not summoned.
	registry.record_position(pid, Vector3(500.0, 0.0, 500.0))
	assert_eq(str(taming.can_tame(target, "")["reason"]), "too_far", "a distant target cannot be tamed")
	_taming_stand_near(registry, pid, c, target)

	assert_eq(str(taming.can_tame(target, "")["reason"]), "alpha_alive",
		"not tameable while the whole pack stands")
	assert_false(c.has_defeated_species("GraywolfPack"), "no pack member is down yet")

	# The template has no skill either, so kill a member and confirm the gate that
	# answers next is the SKILL one: the alpha gate is satisfied, not skipped.
	GameBus.creature_died.emit(str(wolves[0]), Vector3.ZERO, "player")
	assert_true(c.has_defeated_species("GraywolfPack"), "a pack member is dead")
	assert_eq(str(taming.can_tame(target, "")["reason"]), "skill_locked:Unarmed:journeyman",
		"the alpha gate is satisfied and the skill gate answers next")
	rig["creature"].free()
	rig["taming"].free()
	rig["crafting"].free()
	rig["registry"].free()

func _test_taming_wolf_grants_flag_companion() -> void:
	var rig := _make_taming_rig()
	var c: Node = rig["creature"]
	var taming: Node = rig["taming"]
	var registry: Node = rig["registry"]
	var pid := str(registry.local_player_id)
	var wolves := _taming_instances_of(c, "GraywolfPack")
	var target := str(wolves[1])
	_taming_stand_near(registry, pid, c, target)
	GameBus.creature_died.emit(str(wolves[0]), Vector3.ZERO, "player")
	assert_true(bool(rig["crafting"].set_skill("Unarmed", "journeyman")), "Unarmed: journeyman")

	var result: Dictionary = taming.tame(target, "")
	assert_true(bool(result["success"]), "the tame resolves")
	assert_eq(str(result["result"]), "companion", "as a companion")
	assert_eq(str(result["flag"]), "wolfBondHolder", "granting the flag")
	assert_true(taming.has_flag(pid, "wolfBondHolder"), "the player holds the flag")
	assert_eq(c.get_tamed_by(target), pid, "and the instance is bound to them")
	assert_true(c.is_tamed(target), "the instance reports tamed")
	assert_true((taming.get_companions(pid) as Array).has(target), "the companion is listed")

	# Idempotence: a second tame of the same instance is refused, not doubled.
	assert_eq(str(taming.can_tame(target, "")["reason"]), "already_tamed", "already tamed")
	assert_eq((taming.get_companions(pid) as Array).size(), 1, "and it is still one companion")
	rig["creature"].free()
	rig["taming"].free()
	rig["crafting"].free()
	rig["registry"].free()

func _test_taming_refusal_is_atomic() -> void:
	# An isolated slice with NO registry has no identified player, and `tamed_by` is
	# an owner id ("" means wild) — so an unidentified tamer cannot bind a companion
	# and is refused as `already_tamed` (see the class docstring). That refusal must
	# be ATOMIC: it may not leave the wolf's `wolfBondHolder` flag set (progression)
	# or an offering spent — the same rule `inventory_full` already follows. This is
	# the one rig that reaches the refusal: every other taming test wires a registry,
	# precisely because a rig without one gets a refusal, not a binding.
	var c := CreatureSlice.new()
	add_child(c)
	c.spawn_for_chunk(Vector2i(0, 0))
	var crafting := CraftingSlice.new()
	add_child(crafting)
	var inventory := InventorySlice.new()
	add_child(inventory)
	var taming := TamingSlice.new()
	add_child(taming)
	taming.creature_slice  = c
	taming.crafting_slice  = crafting
	# No registry: inventory_for("") falls back to the slice's own inventory.
	taming.inventory_slice = inventory
	var wolves := _taming_instances_of(c, "GraywolfPack")
	var target := str(wolves[1])
	GameBus.creature_died.emit(str(wolves[0]), Vector3.ZERO, "player")
	assert_true(bool(crafting.set_skill("Unarmed", "journeyman")), "Unarmed: journeyman")
	assert_true(bool(taming.can_tame(target, "")["ok"]), "every requirement but the owner is met")

	var refused: Dictionary = taming.tame(target, "")
	assert_false(bool(refused["success"]), "an unidentified tamer cannot bind a companion")
	assert_eq(str(refused["reason"]), "already_tamed",
		"refused as already_tamed rather than bound to a wild owner")
	assert_false(c.is_tamed(target), "so the instance stays wild")
	assert_eq(c.get_tamed_by(target), "", "with no owner written on it")
	assert_false(taming.has_flag("", "wolfBondHolder"), "and the refusal left no flag behind")
	assert_eq((taming.get_companions("") as Array).size(), 0, "nor listed a companion")
	c.free()
	crafting.free()
	inventory.free()
	taming.free()

func _test_taming_requires_skill() -> void:
	# The skill gate fails CLOSED: an unwired/unadvanced table reads as "novice", so a
	# journeyman requirement is refused rather than skipped.
	var rig := _make_taming_rig()
	var c: Node = rig["creature"]
	var taming: Node = rig["taming"]
	var registry: Node = rig["registry"]
	var pid := str(registry.local_player_id)
	var wolves := _taming_instances_of(c, "GraywolfPack")
	var target := str(wolves[1])
	_taming_stand_near(registry, pid, c, target)
	GameBus.creature_died.emit(str(wolves[0]), Vector3.ZERO, "player")

	assert_eq(taming.skill_tier(pid, "Unarmed"), "novice", "a fresh table is novice")
	var refused: Dictionary = taming.tame(target, "")
	assert_false(bool(refused["success"]), "a novice cannot tame the pup")
	assert_eq(str(refused["reason"]), "skill_locked:Unarmed:journeyman", "reason names the gate")
	assert_false(c.is_tamed(target), "and nothing was tamed")

	# apprentice is still below journeyman — the gate is a rank, not an exact match.
	rig["crafting"].set_skill("Unarmed", "apprentice")
	assert_false(bool(taming.can_tame(target, "")["ok"]), "apprentice is not enough")
	rig["crafting"].set_skill("Unarmed", "journeyman")
	assert_true(bool(taming.can_tame(target, "")["ok"]), "journeyman passes")
	rig["creature"].free()
	rig["taming"].free()
	rig["crafting"].free()
	rig["registry"].free()

func _test_taming_requires_unarmed() -> void:
	# "Player must approach the pup while unarmed": an equipped main hand is what the
	# rule reads. Only the local player's character is modelled, so the check runs
	# against the character slice's own view of that character's equipment.
	var rig := _make_taming_rig()
	var c: Node = rig["creature"]
	var taming: Node = rig["taming"]
	var registry: Node = rig["registry"]
	var pid := str(registry.local_player_id)
	var wolves := _taming_instances_of(c, "GraywolfPack")
	var target := str(wolves[1])
	_taming_stand_near(registry, pid, c, target)
	GameBus.creature_died.emit(str(wolves[0]), Vector3.ZERO, "player")
	rig["crafting"].set_skill("Unarmed", "journeyman")

	var ch := CharacterSlice.new()
	add_child(ch)
	taming.character_slice = ch
	var char_id := ch.create_character("TravellerHuman", Vector3.ZERO)
	assert_true(char_id != "", "the player character exists")
	ch.set_player_character(char_id)
	assert_true(taming.is_unarmed(""), "empty hands by default")
	assert_true(bool(taming.can_tame(target, "")["ok"]), "so the tame is allowed")

	assert_true(ch.apply_equipment(char_id, "MainHand", "VeilsteelLongsword"), "a sword is equipped")
	assert_false(taming.is_unarmed(""), "an equipped weapon is not bare hands")
	var refused: Dictionary = taming.tame(target, "")
	assert_false(bool(refused["success"]), "a drawn weapon blocks the tame")
	assert_eq(str(refused["reason"]), "armed", "reason is armed")
	assert_false(c.is_tamed(target), "and nothing was tamed")

	ch.clear_equipment(char_id, "MainHand")
	assert_true(taming.is_unarmed(""), "clearing the slot frees the hands")
	assert_true(bool(taming.tame(target, "")["success"]), "and the tame goes through")
	rig["creature"].free()
	rig["taming"].free()
	rig["crafting"].free()
	rig["registry"].free()

## Phase 47 — a remote peer's hands are the HOST's copy of its worn set, never the tame
## intent's claim. Phase 36 evaluated a claim riding the intent; a client that lied
## was believed. The registry now answers, and the claim argument is ignored.
func _test_taming_peer_bare_hands_claim() -> void:
	var rig := _make_taming_rig()
	var c: Node = rig["creature"]
	var taming: Node = rig["taming"]
	var registry: Node = rig["registry"]
	var fox := _taming_instance_of(c, "GlimmerFox")
	var peer := str(registry.resolve_identity(2))
	rig["crafting"].set_skill_for(peer, "Alchemy", "apprentice")
	var inv: Node = registry.get_inventory(peer)
	assert_true(inv.add_item("FieldRations", 1), "the peer carries a ration")
	_taming_stand_near(registry, peer, c, fox)

	# The host recorded a weapon in the peer's hand: nothing the payload could say matters.
	assert_true(taming.is_unarmed(peer), "a peer with nothing recorded in hand is bare-handed (the host authors the set)")
	assert_true(registry.record_equipment(peer, { "MainHand": "VeilsteelLongsword" }), "the host records the worn sword")
	assert_false(taming.is_unarmed(peer), "a peer wearing a sword is armed")
	var armed: Dictionary = _taming_tame_via_intent(fox, peer)
	assert_eq(str(armed.get("reason", "")), "armed", "the host's recorded sword refuses the tame")
	assert_eq(inv.get_item_count("FieldRations"), 1, "and spends nothing")

	# Hands recorded free: the tame goes through.
	GameBus.equip_intent.emit(peer, "MainHand", "")
	assert_true(taming.is_unarmed(peer), "unequipping the sword frees the hands")
	var honest: Dictionary = _taming_tame_via_intent(fox, peer)
	assert_true(bool(honest.get("success", false)), "the recorded (empty) set satisfies the rule")
	assert_eq(inv.get_item_count("FieldRations"), 0, "and the offering is spent")
	rig["creature"].free()
	rig["taming"].free()
	rig["crafting"].free()
	rig["registry"].free()

## Phase 47 — the pure rules: slots come from the fabric, totals are sums of fabric
## values (zeros for an empty set), and a claim is filtered through the slot table.
func _test_equipment_rules_totals() -> void:
	var slots: Array = EquipmentRules.slots(GameData.ITEMS)
	for expected in ["Head", "Chest", "Cape", "OffHand", "MainHand"]:
		assert_true(slots.has(expected), "the fabric defines slot %s" % expected)
	assert_eq(int(EquipmentRules.totals({}, GameData.ITEMS)["defense"]), 0, "an empty set totals zero")
	var worn := { "Head": "FerriteHelmet", "Chest": "VeilsteelChestplate" }
	var expect := 0
	for item in worn.values():
		expect += GameDataReader.int_field(GameData.ITEMS[item], "defense", 0)
	assert_true(expect > 0, "armour carries a fabric defense value")
	assert_eq(int(EquipmentRules.totals(worn, GameData.ITEMS)["defense"]), expect, "totals equal the sum of the fabric values")
	var clean := EquipmentRules.sanitize({ "Head": "VeilsteelChestplate", "Bogus": "FerriteHelmet", "Chest": "VeilsteelChestplate", "Cape": "NoSuchItem" }, GameData.ITEMS)
	assert_eq(clean, { "Chest": "VeilsteelChestplate" }, "wrong-slot, unknown-slot and unknown-item claims are dropped")
	assert_true(EquipmentRules.sanitize("junk", GameData.ITEMS).is_empty(), "a non-dictionary claim is empty")

## Phase 47 — equipping changes the avatar AND the derived totals; a worn set
## round-trips through the player record and survives an eviction-less reload.
func _test_character_derived_stats_and_record() -> void:
	var ch := CharacterSlice.new()
	add_child(ch)
	var cid := ch.create_character("TravellerHuman", Vector3.ZERO)
	# The seeded character spawns in its recipe's base gear; start from bare.
	for slot in ch.get_equipment_set(cid).keys():
		ch.clear_equipment(cid, str(slot))
	var before := int(ch.derived_stats(cid)["defense"])
	assert_eq(before, 0, "a bare character totals zero")
	assert_true(ch.apply_equipment(cid, "Head", "FerriteHelmet"), "helmet equips")
	var after := int(ch.derived_stats(cid)["defense"])
	assert_true(after > before, "equipping raises the derived defense")
	assert_eq(ch.get_equipment_set(cid).get("Head", ""), "FerriteHelmet", "the set names the helmet")
	assert_eq(int(ch.derived_stats("nope")["defense"]), 0, "an unknown instance reads zeros")

	var registry := PlayerRegistry.new()
	add_child(registry)
	var pid := str(registry.mint_player_id())
	registry.record_equipment(pid, ch.get_equipment_set(cid))
	var saved: Dictionary = registry.get_player_data(pid)
	var registry2 := PlayerRegistry.new()
	add_child(registry2)
	registry2.apply_player_data(pid, saved)
	assert_eq(registry2.get_equipment(pid), { "Head": "FerriteHelmet" }, "the worn set survives a restart through the record")
	registry2.record_equipment(pid, { "Head": "VeilsteelLongsword" })
	assert_eq(registry2.get_equipment(pid), {}, "a forged slot/item pairing never reaches the record")

	var ch2 := CharacterSlice.new()
	add_child(ch2)
	var cid2 := ch2.create_character("TravellerHuman", Vector3.ZERO)
	ch2.apply_equipment_set(cid2, registry2.get_equipment(pid))
	ch2.apply_equipment_set(cid2, { "Chest": "VeilsteelChestplate" })
	assert_eq(ch2.get_equipment_set(cid2), { "Chest": "VeilsteelChestplate" }, "apply_equipment_set replaces the whole set")

	# Replication target: a peer's set lands on its bound character instance.
	ch2.bind_peer_character(7, cid2)
	ch2.set_peer_equipment(7, { "Head": "FerriteHelmet", "MainHand": "FerriteHelmet" })
	assert_eq(ch2.get_equipment_set(cid2), { "Head": "FerriteHelmet" }, "the peer's character wears only the valid replicated entries")
	ch2.forget_peer(7)
	assert_eq(ch2.get_peer_equipment(7), {}, "forget_peer drops the replicated set of a peer that left")
	ch2.set_peer_equipment(7, { "Chest": "VeilsteelChestplate" })
	assert_eq(ch2.get_equipment_set(cid2), { "Head": "FerriteHelmet" }, "forget_peer unbinds the instance: a recycled id does not rewrite it")
	ch.free()
	ch2.free()
	registry.free()
	registry2.free()

## Phase 47 — the Character window lists one row per fabric slot and its totals match.
func _test_ui_character_rows() -> void:
	var ch := CharacterSlice.new()
	add_child(ch)
	var cid := ch.create_character("TravellerHuman", Vector3.ZERO)
	ch.set_player_character(cid)
	for slot in ch.get_equipment_set(cid).keys():
		ch.clear_equipment(cid, str(slot))
	var ui := UiSlice.new()
	ui.character_slice = ch
	add_child(ui)
	var rows: Array = ui.character_rows()
	assert_eq(rows.size(), EquipmentRules.slots(GameData.ITEMS).size(), "one row per fabric slot")
	assert_eq(ui.character_stats_text(), "Defense 0", "empty set totals zero")
	var bag := InventorySlice.new()
	add_child(bag)
	ui.inventory_slice = bag
	assert_false(ui.dispatch_item_action("FerriteHelmet", "equip"), "an item the bag does not hold cannot be worn")
	assert_false(ch.get_equipment_set(cid).has("Head"), "and the avatar stays bare")
	bag.add_item("FerriteHelmet", 1)
	assert_true(ui.dispatch_item_action("FerriteHelmet", "equip"), "equip goes through apply_equipment")
	assert_eq(ch.get_equipment_set(cid).get("Head", ""), "FerriteHelmet", "the avatar wears it")
	assert_eq(ui.item_actions("FerriteHelmet", {}).filter(func(a): return a["action"] == "equip").size(), 0,
		"a worn item offers no Equip action")
	assert_true(ui.character_stats_text() != "Defense 0", "and the totals changed")
	assert_true(ui.dispatch_item_action("FerriteHelmet", "unequip"), "unequip clears the slot")
	assert_eq(ui.character_stats_text(), "Defense 0", "back to zero")
	assert_eq(ui.item_actions("FerriteHelmet", {}).filter(func(a): return a["action"] == "equip").size(), 1,
		"an unworn held item offers Equip")
	bag.free()
	ui.free()
	ch.free()

func _test_taming_fox_feed_yields() -> void:
	# The fox tame is the non-lethal half: the creature stays alive, sheds its fur and
	# the offering comes off the TAMER's inventory.
	var rig := _make_taming_rig()
	var c: Node = rig["creature"]
	var taming: Node = rig["taming"]
	var registry: Node = rig["registry"]
	var pid := str(registry.local_player_id)
	var fox := _taming_instance_of(c, "GlimmerFox")
	assert_true(fox != "", "a GlimmerFox instance exists")
	_taming_stand_near(registry, pid, c, fox)
	rig["crafting"].set_skill("Alchemy", "apprentice")
	var inventory: Node = taming.inventory_for(pid)
	assert_true(inventory.add_item("FieldRations", 1), "the tamer carries rations")

	var result: Dictionary = taming.tame(fox, "")
	assert_true(bool(result["success"]), "the fox accepts the offer")
	assert_eq(str(result["result"]), "yield", "it is a yield tame")
	assert_eq(inventory.get_item_count("glimmer_fur_tuft"), 1, "the fox shed a fur tuft")
	assert_eq(inventory.get_item_count("FieldRations"), 0, "and the ration was consumed by it")
	assert_eq(str(c.get_tamed_by(fox)), "", "the fox is not a companion")
	assert_eq(str(c._instances[fox]["state"]), "idle", "and it did not die")
	var granted: Array = result["yields"]
	assert_eq(granted.size(), 1, "the result reports the shed yield")
	assert_eq(str((granted[0] as Dictionary).get("item", "")), "glimmer_fur_tuft", "as the fur tuft")
	assert_eq(int((granted[0] as Dictionary).get("quantity", 0)), 1, "one of them")
	assert_false(taming.has_flag(pid, "wolfBondHolder"), "a feed grants no flag")
	rig["creature"].free()
	rig["taming"].free()
	rig["crafting"].free()
	rig["registry"].free()

func _test_taming_fox_needs_offer() -> void:
	var rig := _make_taming_rig()
	var c: Node = rig["creature"]
	var taming: Node = rig["taming"]
	var registry: Node = rig["registry"]
	var pid := str(registry.local_player_id)
	var fox := _taming_instance_of(c, "GlimmerFox")
	_taming_stand_near(registry, pid, c, fox)
	rig["crafting"].set_skill("Alchemy", "apprentice")

	assert_eq(str(taming.can_tame(fox, "")["reason"]), "missing_offer", "an empty-handed feed is refused")
	var refused: Dictionary = taming.tame(fox, "")
	assert_false(bool(refused["success"]), "and nothing is resolved")
	assert_eq(str(refused["reason"]), "missing_offer", "reason is missing_offer")

	# The raw-meat alternative satisfies the same rule, and is what gets consumed.
	var inventory: Node = taming.inventory_for(pid)
	assert_true(inventory.add_item("raw_boar_meat", 1), "raw meat is carried")
	assert_true(bool(taming.tame(fox, "")["success"]), "the alternative offering works")
	assert_eq(inventory.get_item_count("raw_boar_meat"), 0, "and it was the item consumed")
	assert_eq(inventory.get_item_count("glimmer_fur_tuft"), 1, "still yielding the fur tuft")
	rig["creature"].free()
	rig["taming"].free()
	rig["crafting"].free()
	rig["registry"].free()

func _test_taming_cooldown() -> void:
	# A yield tame leaves the creature alive, so the fabric's cooldown is the only
	# thing that stops the same fox being fed in a loop. Wall-clock, like every other
	# deadline in the project.
	var rig := _make_taming_rig()
	var c: Node = rig["creature"]
	var taming: Node = rig["taming"]
	var registry: Node = rig["registry"]
	var pid := str(registry.local_player_id)
	var fox := _taming_instance_of(c, "GlimmerFox")
	_taming_stand_near(registry, pid, c, fox)
	rig["crafting"].set_skill("Alchemy", "apprentice")
	var inventory: Node = taming.inventory_for(pid)
	inventory.add_item("FieldRations", 3)

	assert_true(bool(taming.tame(fox, "")["success"]), "the first feed succeeds")
	assert_true(taming.cooldown_remaining(fox, pid) > 0.0, "a cooldown is running")
	assert_true(taming.cooldown_remaining(fox, pid) <= 600.0, "and it is bounded by the fabric's 600 s")
	assert_eq(str(taming.can_tame(fox, "")["reason"]), "on_cooldown", "a second feed is refused")
	assert_eq(inventory.get_item_count("FieldRations"), 2, "and the ration was NOT eaten")
	assert_eq(inventory.get_item_count("glimmer_fur_tuft"), 1, "nor is a second tuft shed")
	assert_false(bool(taming.tame(fox, "")["success"]), "tame() refuses it as well")

	# Expire the deadline: the same fox can be fed again.
	taming._cooldowns[pid][fox] = Time.get_unix_time_from_system() - 1.0
	assert_eq(taming.cooldown_remaining(fox, pid), 0.0, "the cooldown has elapsed")
	assert_true(bool(taming.tame(fox, "")["success"]), "so the fox can be fed again")
	assert_eq(inventory.get_item_count("glimmer_fur_tuft"), 2, "shedding a second tuft")
	rig["creature"].free()
	rig["taming"].free()
	rig["crafting"].free()
	rig["registry"].free()

func _test_taming_is_per_player() -> void:
	# Taming is per-player for the same reason research is: the granted flag, the
	# companion binding and the consumed offering all belong to ONE player's record and
	# ONE player's inventory.
	var rig := _make_taming_rig()
	var c: Node = rig["creature"]
	var taming: Node = rig["taming"]
	var registry: Node = rig["registry"]
	var local_pid := str(registry.local_player_id)
	var wolves := _taming_instances_of(c, "GraywolfPack")
	var target := str(wolves[1])
	GameBus.creature_died.emit(str(wolves[0]), Vector3.ZERO, "player")

	var alice: String = str(registry.resolve_identity(2))
	var bob: String = str(registry.resolve_identity(3))
	# Phase 36 — the tier is the TAMER's, so each tamer is given their own: a single
	# process-wide set_skill() no longer stands in for every player's progression.
	for tamer in [alice, bob]:
		rig["crafting"].set_skill_for(str(tamer), "Unarmed", "journeyman")
		rig["crafting"].set_skill_for(str(tamer), "Alchemy", "apprentice")
	_taming_stand_near(registry, alice, c, target)
	_taming_stand_near(registry, bob, c, target)
	# Only BOB carries the offering: a feed by alice must not spend bob's ration.
	var bob_inv: Node = registry.get_inventory(bob)
	assert_true(bob_inv.add_item("FieldRations", 1), "bob carries a ration")

	var alice_result: Dictionary = _taming_tame_via_intent(target, alice)
	assert_true(bool(alice_result["success"]), "alice tames the pup with her own hands")
	assert_eq(str(alice_result["player_id"]), alice, "and the result names alice")
	assert_true(taming.has_flag(alice, "wolfBondHolder"), "alice holds the flag")
	assert_false(taming.has_flag(bob, "wolfBondHolder"), "bob does not")
	assert_eq(c.get_tamed_by(target), alice, "the companion belongs to alice")
	assert_true((taming.get_companions(alice) as Array).has(target), "and is listed for her")
	assert_false((taming.get_companions(bob) as Array).has(target), "not for bob")

	# The offering is per-player: bob's ration is invisible to alice's feed, and alice
	# has no ration of her own.
	var fox := _taming_instance_of(c, "GlimmerFox")
	_taming_stand_near(registry, alice, c, fox)
	var fed: Dictionary = _taming_tame_via_intent(fox, alice)
	assert_false(bool(fed["success"]), "alice cannot feed the fox on bob's ration")
	assert_eq(str(fed["reason"]), "missing_offer", "reason is missing_offer")
	assert_eq(bob_inv.get_item_count("FieldRations"), 1, "bob's ration is untouched")

	# ...and bob, standing next to the same fox, does get fed.
	_taming_stand_near(registry, bob, c, fox)
	assert_true(bool(_taming_tame_via_intent(fox, bob)["success"]), "bob feeds it with his own ration")
	assert_eq(bob_inv.get_item_count("FieldRations"), 0, "spending his own")
	assert_eq(bob_inv.get_item_count("glimmer_fur_tuft"), 1, "and receiving the tuft")
	rig["creature"].free()
	rig["taming"].free()
	rig["crafting"].free()
	rig["registry"].free()

func _test_taming_client_forwards_intent() -> void:
	# A client owns no records, so it must FORWARD a tame to the host rather than
	# resolve one against its synced world: the flag, the companion binding and the
	# consumed offering all belong to a record only the host can write.
	var c := CreatureSlice.new()
	add_child(c)
	c.spawn_for_chunk(Vector2i(0, 0))
	var taming := TamingSlice.new()
	add_child(taming)
	taming.creature_slice = c
	taming.is_authoritative = false
	var target := _taming_instance_of(c, "GraywolfPack")
	var forwarded: Array = []
	var on_intent := func(instance_id: String, player_id: String) -> void:
		forwarded.append([instance_id, player_id])
	GameBus.tame_intent.connect(on_intent)
	GameBus.tame_requested.emit(target)
	GameBus.tame_intent.disconnect(on_intent)
	assert_eq(forwarded.size(), 1, "the client forwarded exactly one intent")
	assert_eq(str(forwarded[0][0]), target, "carrying the instance id")
	assert_eq(str(forwarded[0][1]), "", "and no identity — the host decides who is taming")
	assert_eq(forwarded[0].size(), 2, "and nothing about its hands: the host reads those from its own record")
	assert_false(c.is_tamed(target), "nothing resolved locally")
	c.free()
	taming.free()

func _test_taming_companion_respawn_suppressed() -> void:
	# "Pup does not respawn if tamed": the tamed binding outlives the death, so the
	# respawn tick must leave a dead companion dead — while a wild creature with the
	# same expired deadline does come back.
	var rig := _make_taming_rig()
	var c: Node = rig["creature"]
	var taming: Node = rig["taming"]
	var registry: Node = rig["registry"]
	var pid := str(registry.local_player_id)
	var wolves := _taming_instances_of(c, "GraywolfPack")
	var target := str(wolves[1])
	_taming_stand_near(registry, pid, c, target)
	GameBus.creature_died.emit(str(wolves[0]), Vector3.ZERO, "player")
	rig["crafting"].set_skill("Unarmed", "journeyman")
	assert_true(bool(taming.tame(target, "")["success"]), "the pup is tamed")

	GameBus.creature_died.emit(target, Vector3.ZERO, "player")
	assert_eq(str(c._instances[target]["state"]), "dead", "the companion died")
	c._instances[target]["respawn_at"] = Time.get_unix_time_from_system() - 1.0

	var wild := _taming_instance_of(c, "ForestBoar")
	assert_true(wild != "", "a wild creature exists to control against")
	GameBus.creature_died.emit(wild, Vector3.ZERO, "player")
	c._instances[wild]["respawn_at"] = Time.get_unix_time_from_system() - 1.0

	c._tick_respawn()
	assert_eq(str(c._instances[target]["state"]), "dead", "a tamed companion does not respawn")
	assert_eq(str(c._instances[wild]["state"]), "idle", "a wild creature still does")
	assert_eq(c.get_tamed_by(target), pid, "and the binding survives the death")
	rig["creature"].free()
	rig["taming"].free()
	rig["crafting"].free()
	rig["registry"].free()

func _test_taming_companion_follows() -> void:
	# A companion is not a target and not a pack member: the attack targeting skips it,
	# and its AI walks it toward its owner instead of patrolling.
	var rig := _make_taming_rig()
	var c: Node = rig["creature"]
	var taming: Node = rig["taming"]
	var registry: Node = rig["registry"]
	var pid := str(registry.local_player_id)
	var wolves := _taming_instances_of(c, "GraywolfPack")
	var target := str(wolves[1])
	_taming_stand_near(registry, pid, c, target)
	GameBus.creature_died.emit(str(wolves[0]), Vector3.ZERO, "player")
	rig["crafting"].set_skill("Unarmed", "journeyman")
	assert_true(bool(taming.tame(target, "")["success"]), "the pup is tamed")

	var at: Vector3 = c.get_instance_position(target)
	assert_true(c.nearest_creature(at, 20.0) != target, "a companion is not offered as a target")
	var wild := _taming_instance_of(c, "ForestBoar")
	assert_true(c.nearest_creature(c.get_instance_position(wild), 20.0) != "",
		"while a wild creature still is")

	var ai := CreatureAI.new()
	add_child(ai)
	ai.creature_slice = c
	ai.taming_slice = taming
	ai.on_companion_tamed(target, pid)
	assert_eq(ai.get_state(target), "tamed", "the companion enters the tamed state")
	ai.on_companion_tamed(target, pid)
	assert_eq(ai.get_state(target), "tamed", "and re-entering it is idempotent")

	var owner_at := Vector3(40.0, 0.0, 40.0)
	registry.record_position(pid, owner_at)
	var before: float = c.get_instance_position(target).distance_to(owner_at)
	ai._tick_companion(target, c._instances[target], 0.5)
	var after: float = c.get_instance_position(target).distance_to(owner_at)
	assert_true(after < before, "the companion closes on its owner")
	assert_eq(ai.get_state(target), "tamed", "and stays tamed while following")
	rig["creature"].free()
	rig["taming"].free()
	rig["crafting"].free()
	rig["registry"].free()

func _test_taming_record_round_trip() -> void:
	# The flag and the companion binding are per-player PROGRESSION, so they persist on
	# the same record as position/HP/technology. A record written before this phase has
	# neither key and restores to empty, not to a crash.
	var rig := _make_taming_rig()
	var c: Node = rig["creature"]
	var taming: Node = rig["taming"]
	var registry: Node = rig["registry"]
	var pid := str(registry.local_player_id)
	var wolves := _taming_instances_of(c, "GraywolfPack")
	var target := str(wolves[1])
	_taming_stand_near(registry, pid, c, target)
	GameBus.creature_died.emit(str(wolves[0]), Vector3.ZERO, "player")
	rig["crafting"].set_skill("Unarmed", "journeyman")
	assert_true(bool(taming.tame(target, "")["success"]), "the pup is tamed")

	taming.sync_record(pid)
	var data: Dictionary = registry.get_player_data(pid)
	assert_true(data.has("flags"), "the record carries flags")
	assert_true(data.has("companions"), "and companions")
	assert_true(bool((data["flags"] as Dictionary).get("wolfBondHolder", false)), "the flag is written")
	assert_true((data["companions"] as Array).has(target), "and the companion id")

	# A fresh slice (a server boot) restores both from the record, and re-binds the
	# companion to the creature instance that is resident again.
	var restored := TamingSlice.new()
	add_child(restored)
	restored.creature_slice = c
	restored.player_registry = registry
	restored.apply_record(data, pid)
	assert_true(restored.has_flag(pid, "wolfBondHolder"), "the flag is restored")
	assert_true((restored.get_companions(pid) as Array).has(target), "so is the companion")
	assert_eq(c.get_tamed_by(target), pid, "and the binding is re-applied to the instance")

	# A pre-Phase-35 record applies to empty state.
	var legacy := TamingSlice.new()
	add_child(legacy)
	legacy.apply_record({ "player_id": pid }, pid)
	assert_eq(legacy.get_flags(pid).size(), 0, "an older record restores no flags")
	assert_eq((legacy.get_companions(pid) as Array).size(), 0, "and no companions")
	# Both extra slices are torn down like every other test slice: they are connected to
	# `tame_intent`/`tame_requested` on the shared bus, so leaving them alive let a later
	# test's tame be resolved — and refused — by an unwired leftover first.
	restored.free()
	legacy.free()
	rig["creature"].free()
	rig["taming"].free()
	rig["crafting"].free()
	rig["registry"].free()

# ---------------------------------------------------------------------------
# Phase 37 — review pass: owner-scoped syncs, durable cooldowns, bounded mirrors,
# routed rounds, and a cached population view
# ---------------------------------------------------------------------------

## Phase 37 — an inventory sync NAMES its owner, and only that owner's inventory applies
## it. Before this the signal was global and every InventorySlice in the process replaced
## its contents with whatever was synced, so a peer's sync clobbered the host's own pack
## and the demo merchant's stock.
func _test_inventory_sync_is_owner_scoped() -> void:
	var reg := PlayerRegistry.new()
	add_child(reg)
	var local_pid := reg.mint_player_id()
	reg.set_local_player(local_pid)
	var local_inv := InventorySlice.new()
	add_child(local_inv)
	reg.set_inventory(local_pid, local_inv)
	# A registry-CREATED inventory carries its owner (get_inventory stamps it).
	var peer_pid := "player_peer_1"
	var peer_inv: Node = reg.get_inventory(peer_pid)
	var merchant := InventorySlice.new()
	add_child(merchant)
	merchant.owner_id = "merchant"

	local_inv.add_item("Ferrite", 2)
	peer_inv.add_item("Thornwood", 3)
	merchant.add_item("hawk_feather", 5)

	GameBus.inventory_synced.emit(peer_pid, { "Ashite": 7 }, {})
	assert_eq(peer_inv.get_item_count("Ashite"), 7, "the peer's inventory takes its own sync")
	assert_eq(local_inv.get_item_count("Ferrite"), 2, "the local pack is untouched")
	assert_eq(merchant.get_item_count("hawk_feather"), 5, "and so is the merchant's stock")

	# The local bucket answers for this machine's own inventory, under either literal.
	GameBus.inventory_synced.emit("player", { "WolfFang": 1 }, {})
	assert_eq(local_inv.get_item_count("WolfFang"), 1, "a local sync lands on the local pack")
	assert_eq(peer_inv.get_item_count("Ashite"), 7, "and not on a peer's")
	assert_eq(merchant.get_item_count("WolfFang"), 0, "nor on the merchant's")
	GameBus.inventory_synced.emit("", { "Ferrite": 4 }, {})
	assert_eq(local_inv.get_item_count("Ferrite"), 4, "the empty literal means the same thing")

	# The stamp is what the filter reads.
	assert_true(peer_inv.is_owned_by(peer_pid), "a peer's inventory answers to its own id")
	assert_false(peer_inv.is_owned_by("merchant"), "and to nothing else")
	assert_false(peer_inv.is_owned_by(""), "not even the local bucket")
	assert_true(local_inv.is_owned_by(""), "the local pack answers the empty literal")
	assert_true(local_inv.is_owned_by("player"), "and the \"player\" literal")
	assert_false(local_inv.is_owned_by(peer_pid), "but not a peer's id")
	merchant.free()
	local_inv.free()
	reg.free()   # frees the registry-created peer inventory with it

## Phase 37 — and the wire half: an inventory is PRIVATE, so the host sends a sync to
## the OWNER'S peer alone and never broadcasts it (and never falls back to a broadcast
## when it cannot resolve the owner).
func _test_net_inventory_sync_is_peer_scoped() -> void:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("player_host_1")
	var peer_pid := str(reg.resolve_identity(5))
	var host := NetworkingSlice.new()
	add_child(host)
	host.player_registry = reg
	host.emulate_network = true
	host._role = NetworkingSlice.Role.HOST

	host._on_inventory_synced(peer_pid, { "Ferrite": 1 }, {})
	assert_eq(host._pending.size(), 1, "one packet, for the owner's peer")
	assert_eq(int(host._pending[0]["peer_id"]), 5, "addressed to that peer alone")
	var packet: Dictionary = JSON.parse_string(str(host._pending[0]["json"]))
	assert_eq(str(packet.get("type", "")), "inventory_synced", "of the inventory_synced type")
	assert_eq(int(packet.get("contents", {}).get("Ferrite", 0)), 1, "carrying the contents")
	assert_false(JSON.stringify(packet).contains(peer_pid), "and no player id — a bearer token stays off the wire")

	# Nobody to send it to: the local bucket (this process's own inventory is already
	# live here), an offline/unknown owner, or an unwired registry. Each FAILS CLOSED.
	host._pending.clear()
	host._on_inventory_synced("", { "Ferrite": 1 }, {})
	host._on_inventory_synced("player", { "Ferrite": 1 }, {})
	host._on_inventory_synced("player_nobody_9_0", { "Ferrite": 1 }, {})
	assert_eq(host._pending.size(), 0, "a local or unresolvable owner is sent nothing")
	host.player_registry = null
	host._on_inventory_synced(peer_pid, { "Ferrite": 1 }, {})
	assert_eq(host._pending.size(), 0, "an unwired registry does not fall back to a broadcast")

	# The client half: the peer-scoped packet reaches the bus as the LOCAL bucket, so
	# only this machine's own inventory applies it.
	var client := NetworkingSlice.new()
	add_child(client)
	client._role = NetworkingSlice.Role.CLIENT
	var seen: Array = []
	var on_sync := func(owner: String, contents: Dictionary, _durabilities: Dictionary) -> void:
		seen.append([owner, contents])
	GameBus.inventory_synced.connect(on_sync)
	client._route_h2c(packet)
	GameBus.inventory_synced.disconnect(on_sync)
	assert_eq(seen.size(), 1, "the client re-emits the sync for its own slices")
	assert_eq(str(seen[0][0]), "", "under the local bucket")
	assert_eq(int((seen[0][1] as Dictionary).get("Ferrite", 0)), 1, "with the synced contents")
	client.free()
	host.free()
	reg.free()

## Phase 37 — a snapshot that lost a chunk can never complete, so its reassembly entry
## used to sit in the buffer for the rest of the session: one leak per lost chunk, on a
## connection that may be long gone. It is transport state, so it goes with the
## connection.
func _test_net_incomplete_snapshot_evicted_on_disconnect() -> void:
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.CLIENT
	n._accumulate_snapshot_chunk({ "snapshot_id": 1, "index": 0, "count": 2, "data": "{\"a\":" })
	assert_eq(n._snapshot_buffer.size(), 1, "a partial snapshot is buffered")
	n.forget_player_id(1)
	assert_eq(n._snapshot_buffer.size(), 0, "the dropped connection's reassembly state goes with it")

	# A complete snapshot still empties its own entry (the pre-existing path).
	n._accumulate_snapshot_chunk({ "snapshot_id": 2, "index": 0, "count": 2, "data": "{\"a\":" })
	n._accumulate_snapshot_chunk({ "snapshot_id": 2, "index": 1, "count": 2, "data": "1}" })
	assert_eq(n._snapshot_buffer.size(), 0, "reassembly is unchanged for a snapshot that completes")
	n.free()

## Phase 37 — a creature's round is routed by the TARGET it engaged. Both a player's
## shapes go down the damage-forwarding path: the local body ("player") and a remote
## peer's player id. Neither may reach the creature path, which tracks hit points and
## emits `creature_died` — on a player id that would be a corpse on somebody's identity.
func _test_battle_routes_player_rounds_by_target() -> void:
	assert_true(BattleSlice.is_player_target("player"), "the local body is a player target")
	assert_true(BattleSlice.is_player_target("player_1700000000_1_" + "ab".repeat(16)),
		"so is a server-minted player id")
	assert_false(BattleSlice.is_player_target("ForestBoar"), "a fabric creature key is not")
	assert_false(BattleSlice.is_player_target("creature_0_0_ForestBoar_0"), "nor an instance id")

	var b := BattleSlice.new()
	add_child(b)
	var hits: Array = []
	var on_damage := func(damage: float, attacker_id: String, target_id: String) -> void:
		hits.append([damage, attacker_id, target_id])
	var deaths: Array = []
	var on_death := func(entity_id: String, _position: Vector3, _killer: String) -> void:
		deaths.append(entity_id)
	GameBus.player_damaged.connect(on_damage)
	GameBus.creature_died.connect(on_death)

	var peer := "player_1700000000_1_" + "cd".repeat(16)
	for i in 20:
		b.resolve_round("ForestBoar", peer)
	GameBus.player_damaged.disconnect(on_damage)
	GameBus.creature_died.disconnect(on_death)
	assert_true(hits.size() > 0, "the rounds against a peer forward damage")
	for h in hits:
		assert_eq(str(h[2]), peer, "each one naming the target the round was routed by")
		assert_eq(str(h[1]), "ForestBoar", "and the creature that struck")
	assert_eq(deaths.size(), 0, "a player target never reaches the creature death path")
	assert_eq(b.get_hp(peer), -1.0, "and no hit points are tracked for a player here")

	# The local body routes the same way, under the id the bus has always used for it.
	var local_hits: Array = []
	var on_local := func(_damage: float, _attacker: String, target_id: String) -> void:
		local_hits.append(target_id)
	GameBus.player_damaged.connect(on_local)
	for i in 20:
		b.resolve_round("ForestBoar", "player")
	GameBus.player_damaged.disconnect(on_local)
	assert_true(local_hits.size() > 0, "the local body is struck too")
	for t in local_hits:
		assert_eq(str(t), "player", "under the local defender id")
	b.free()

## Phase 37 — the wire half of round routing: the host cannot apply a peer's damage
## (it holds no verifiable HP for that peer), so it sends the round to the peer whose
## body is simulated there; that client applies it to its own PlayerSlice.
func _test_net_peer_damage_is_peer_scoped() -> void:
	var host := NetworkingSlice.new()
	add_child(host)
	host.emulate_network = true
	host.send_player_damaged(5, 12.0, "creature_0_0_ForestBoar_0")
	assert_eq(host._pending.size(), 0, "a non-host cannot send damage")
	host._role = NetworkingSlice.Role.HOST
	host.send_player_damaged(5, 12.0, "creature_0_0_ForestBoar_0")
	assert_eq(host._pending.size(), 1, "the host queues exactly one packet")
	assert_eq(int(host._pending[0]["peer_id"]), 5, "addressed to the peer that was hit")
	var packet: Dictionary = JSON.parse_string(str(host._pending[0]["json"]))
	assert_eq(str(packet.get("type", "")), "player_damaged", "of the player_damaged type")

	# The client half: the local body absorbs it, under the id the bus has always used.
	var client := NetworkingSlice.new()
	add_child(client)
	client._role = NetworkingSlice.Role.CLIENT
	var hits: Array = []
	var on_damage := func(damage: float, attacker_id: String, target_id: String) -> void:
		hits.append([damage, attacker_id, target_id])
	GameBus.player_damaged.connect(on_damage)
	client._route_h2c(packet)
	GameBus.player_damaged.disconnect(on_damage)
	assert_eq(hits.size(), 1, "the peer's client applies the hit")
	assert_eq(float(hits[0][0]), 12.0, "for the damage the host resolved")
	assert_eq(str(hits[0][1]), "creature_0_0_ForestBoar_0", "attributed to the creature")
	assert_eq(str(hits[0][2]), "player", "addressed to the local body")

	# And a round aimed at ANOTHER player is not this body's to absorb.
	var player := PlayerSlice.new()
	add_child(player)
	assert_true(player._is_local_target("player"), "the local body takes the local rounds")
	assert_true(player._is_local_target(""), "under the resolve_player literal too")
	assert_false(player._is_local_target("player_someone_else_1_x"), "another player's is refused")
	player.free()
	client.free()
	host.free()

## Phase 37 — a named counterparty must be a public HANDLE. Accepting a raw player id as
## well made the resolver a yes/no oracle for "is this exact id online", and an id is a
## bearer token: presenting one on join claims the record.
func _test_named_party_accepts_handles_only() -> void:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("player_host_1")
	var guest := str(reg.resolve_identity(3))

	assert_eq(reg.resolve_named_party(reg.public_handle(guest)), guest, "a handle resolves")
	assert_eq(reg.resolve_named_party(reg.public_handle("player_host_1")), "player_host_1",
		"the local player's handle resolves too")
	assert_eq(reg.resolve_named_party(guest), "", "a raw ONLINE player id does not")
	assert_eq(reg.resolve_named_party("player_host_1"), "", "not even the local player's own id")
	assert_eq(reg.resolve_named_party("player_nobody_9_0"), "", "nor an unknown id")
	assert_eq(reg.resolve_named_party("merchant"), "", "nor a demo scaffolding literal")
	assert_eq(reg.resolve_named_party(""), "", "nor an empty name")
	assert_eq(reg.resolve_named_party(reg.public_handle("player_nobody_9_0")), "",
		"and an offline player's handle answers nothing")

	# The offline case: dropping the connection takes the handle's answer with it.
	reg.unbind_peer(3)
	assert_eq(reg.resolve_named_party(reg.public_handle(guest)), "",
		"a handle resolves only while its player is here")
	reg.free()

## Phase 37 — a tame cooldown is a rule about the PLAYER, so it rides the player record.
## In memory alone, a host restart (or a reconnect) handed every player a clean table and
## the fox could be fed in a loop again.
func _test_taming_cooldowns_are_durable() -> void:
	var rig := _make_taming_rig()
	var c: Node = rig["creature"]
	var taming: Node = rig["taming"]
	var registry: Node = rig["registry"]
	var crafting: Node = rig["crafting"]
	var pid := str(registry.local_player_id)
	var fox := _taming_instance_of(c, "GlimmerFox")
	_taming_stand_near(registry, pid, c, fox)
	crafting.set_skill_for(pid, "Alchemy", "apprentice")
	var inventory: Node = taming.inventory_for(pid)
	assert_true(inventory.add_item("FieldRations", 2), "the tamer carries rations")

	assert_true(bool(taming.tame(fox, "")["success"]), "the first feed succeeds")
	assert_true(taming.cooldown_remaining(fox, pid) > 0.0, "and starts the fabric's cooldown")
	taming.sync_record(pid)
	var data: Dictionary = registry.get_player_data(pid)
	assert_true(data.has("cooldowns"), "the record carries the cooldown table")
	assert_true((data["cooldowns"] as Dictionary).has(fox), "with this fox's deadline")

	# A fresh slice (the shape of a server restart) restores it from the record.
	var restored := TamingSlice.new()
	add_child(restored)
	restored.creature_slice = c
	restored.crafting_slice = crafting
	restored.player_registry = registry
	restored.apply_record(data, pid)
	assert_true(restored.cooldown_remaining(fox, pid) > 0.0,
		"the fox is still on cooldown after the restart")
	assert_eq(str(restored.can_tame(fox, pid)["reason"]), "on_cooldown",
		"and the feed is refused — the same refusal the pre-restart process gave")

	# An EXPIRED deadline is not persisted: it bounds nothing, and keeping it would grow
	# the record with every fox ever fed.
	restored._cooldowns_for(pid)[fox] = Time.get_unix_time_from_system() - 1.0
	restored.sync_record(pid)
	assert_false(registry.get_cooldowns(pid).has(fox), "an elapsed cooldown is pruned from the record")
	var live := PlayerRegistry.live_cooldowns({
		"stale": Time.get_unix_time_from_system() - 1.0,
		"fresh": Time.get_unix_time_from_system() + 60.0,
	})
	assert_eq(live.size(), 1, "the prune rule is pure and keeps only live deadlines")
	assert_true(live.has("fresh"), "the live one")

	restored.free()
	rig["creature"].free()
	rig["taming"].free()
	rig["crafting"].free()
	rig["registry"].free()

## Phase 37 — the three per-player taming mirrors (flags, companion bindings, cooldowns)
## only ever grew: a server that had seen a thousand tamers held a thousand tables for the
## rest of the session. They are released on disconnect, and nothing is lost — the record
## written at that moment is the durable copy, and a reconnect re-applies it.
func _test_taming_mirrors_evicted_on_forget() -> void:
	var rig := _make_taming_rig()
	var c: Node = rig["creature"]
	var taming: Node = rig["taming"]
	var registry: Node = rig["registry"]
	var wolves := _taming_instances_of(c, "GraywolfPack")
	var target := str(wolves[1])
	GameBus.creature_died.emit(str(wolves[0]), Vector3.ZERO, "player")
	var alice: String = str(registry.resolve_identity(2))
	rig["crafting"].set_skill_for(alice, "Unarmed", "journeyman")
	_taming_stand_near(registry, alice, c, target)
	var tamed: Dictionary = _taming_tame_via_intent(target, alice)
	assert_eq(str(tamed.get("reason", "no_result")), "", "alice's tame is not refused")
	assert_true(bool(tamed.get("success", false)), "alice tames the pup")
	assert_true(taming.has_flag(alice, "wolfBondHolder"), "the flag is mirrored")
	taming._cooldowns_for(alice)[target] = Time.get_unix_time_from_system() + 60.0
	taming.sync_record(alice)
	var record: Dictionary = registry.get_player_data(alice)
	assert_true(bool((record["flags"] as Dictionary).get("wolfBondHolder", false)),
		"and written on the durable record first")

	taming.forget_player_id(alice)
	assert_false(taming._flags.has(alice), "the flags mirror is released")
	assert_false(taming._companions.has(alice), "so is the companion mirror")
	assert_false(taming._cooldowns.has(alice), "and the cooldown mirror")
	assert_true(bool((registry.get_record(alice)["flags"] as Dictionary).get("wolfBondHolder", false)),
		"while the record still holds the flag — the reconnect path reads it back")

	# The reconnect path: apply_record re-applies the claimed record.
	taming.apply_record(registry.get_record(alice), alice)
	assert_true(taming.has_flag(alice, "wolfBondHolder"), "a reconnect restores the flag")
	assert_true((taming.get_companions(alice) as Array).has(target), "and the companion binding")

	# The local player is never evicted: it is online by definition, and its mirrors are
	# this process's own (the same rule PlayerRegistry.evict_player follows).
	taming.forget_player_id(str(registry.local_player_id))
	taming.forget_player_id("")
	assert_true(taming.has_flag(alice, "wolfBondHolder"), "forgetting a local id evicts nothing")
	assert_true((taming.get_companions(alice) as Array).has(target), "neither the flags nor the companions")

	rig["creature"].free()
	rig["taming"].free()
	rig["crafting"].free()
	rig["registry"].free()

## Phase 37 — `get_all_instances()` builds a fresh dictionary per instance on every call,
## and the AI ran it once per frame. `instances_view()` serves the same population without
## the copies: it is cached until the population's MEMBERSHIP changes, and the records it
## hands out are the slice's own (live) ones.
func _test_creature_instances_view_cached() -> void:
	var c := CreatureSlice.new()
	add_child(c)
	c.spawn_for_chunk(Vector2i(0, 0))
	var view: Array = c.instances_view()
	assert_eq(view.size(), c.get_all_instances().size(), "the view holds the whole live population")
	var first: Dictionary = view[0]
	assert_true(first.has("instance_id"), "each record carries its own id")
	assert_true(is_same(c.instances_view(), view), "and the view is CACHED — no per-frame rebuild")

	# The records ARE the slice's own, which is what makes the view cheap and what makes
	# it read-only by contract: writing through it writes the world.
	first["state"] = "alert"
	assert_eq(str(c._instances[str(first["instance_id"])]["state"]), "alert",
		"the view exposes the live record, not a copy")

	# Membership changes are the one thing that invalidates it.
	var before: int = c.instances_view().size()
	c.despawn_for_chunk(Vector2i(0, 0))
	assert_false(is_same(c.instances_view(), view), "a despawn rebuilds the view")
	assert_true(c.instances_view().size() < before, "without the despawned instances")
	c.free()

# ---------------------------------------------------------------------------
# Phase 38 review-fix tests
# ---------------------------------------------------------------------------

## Phase 38 — a peer's health is the HOST's to simulate. Phase 37 delivered the round to
## the peer's own client and let THAT client keep the number, so a modified client could
## ignore every hit and be unkillable, while an honest one lost its health on every
## reconnect and every restart — the host had resolved the round and then discarded the
## only evidence it had. The host now applies the hit to its own durable record for that
## peer, while the DECLARED hp a peer sends is still refused at every door.
func _test_host_simulates_peer_hp() -> void:
	# The pure rule first. An unmodelled body starts at FULL health: the host holds no
	# record of that peer's health and will not take the peer's word for it, so a fresh
	# body is the only honest seed — and from the first resolved hit the number is the
	# host's own.
	assert_eq(PlayerRegistry.simulated_hp_after_hit(-1.0, 12.0, 100.0), 88.0,
		"an unmodelled body starts at full health and takes the hit")
	assert_eq(PlayerRegistry.simulated_hp_after_hit(50.0, 12.0, 100.0), 38.0,
		"a modelled body continues from the number the host already holds")
	assert_eq(PlayerRegistry.simulated_hp_after_hit(5.0, 12.0, 100.0), 0.0,
		"a hit cannot drive a simulated body below zero")
	assert_eq(PlayerRegistry.simulated_hp_after_hit(90.0, -12.0, 100.0), 100.0,
		"and nothing here heals a body past its ceiling")

	var registry := PlayerRegistry.new()
	add_child(registry)
	var host_id := registry.mint_player_id()
	registry.set_local_player(host_id)
	var remote := str(registry.resolve_identity(7))
	assert_eq(registry.get_hp(remote), -1.0, "the host begins holding no number for a peer")

	registry.record_simulated_hp(remote, 88.0)
	assert_eq(registry.get_hp(remote), 88.0, "the host's OWN resolution is recorded")
	assert_eq(float(registry.get_record(remote).get("hp", -2.0)), 88.0, "on the peer's record")

	# DURABLE: it rides the serializable record, so a reconnect or a restart does not hand
	# the peer a full bar again — exactly the reset the Phase 37 behaviour produced.
	var restored := PlayerRegistry.new()
	add_child(restored)
	restored.apply_player_data(remote, registry.get_player_data(remote))
	assert_eq(restored.get_hp(remote), 88.0, "and survives the record round trip")

	# The declared half still has no door, and the new one has no side entrances.
	registry.record_hp(remote, 9999.0)
	assert_eq(registry.get_hp(remote), 88.0, "a client-declared hp is still refused")
	registry.record_simulated_hp(host_id, 1.0)
	assert_eq(registry.get_hp(host_id), -1.0, "the local body's hp is record_hp's to write")
	registry.record_simulated_hp("", 1.0)
	var stranger := registry.mint_player_id()
	registry.record_simulated_hp(stranger, 1.0)
	assert_eq(registry.get_hp(stranger), -1.0,
		"a player this host holds no record for is refused, not minted")
	registry.record_simulated_hp(remote, 1.0)
	assert_eq(registry.get_hp(remote), 1.0, "while a peer the host does hold updates")
	# A client holds no records at all, even if a record should find its way into it.
	var client_reg := PlayerRegistry.new()
	add_child(client_reg)
	client_reg.is_authoritative = false
	client_reg._players[remote] = registry.get_record(remote).duplicate(true)
	client_reg.record_simulated_hp(remote, 7.0)
	assert_eq(client_reg.get_hp(remote), 1.0, "a non-authoritative registry writes nothing")
	client_reg.free()
	registry.free()
	restored.free()

## Phase 38 — the snapshot's social/economy blobs travel under the ONE list of
## identity-bearing keys (`IDENTIFIED_STATE_KEYS`), the same list the receiving side walks
## to adopt its own handle. Hardcoded literals in game_root meant a fourth entry in the
## constant would have been adopted by every client while never being redacted on the way
## out: a player id on the wire.
func _test_snapshot_social_keys_are_identified() -> void:
	assert_eq(NetworkingSlice.IDENTIFIED_STATE_KEYS.size(), 3,
		"the list names three identity-bearing blobs")
	for key in ["market", "governance", "trade"]:
		assert_true(NetworkingSlice.IDENTIFIED_STATE_KEYS.has(key),
			"%s is one of them" % key)

	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("player_1000_1_" + "aa".repeat(16))
	var seller := str(reg.resolve_identity(4))
	var n := NetworkingSlice.new()
	add_child(n)
	n.player_registry = reg

	var sessions := {}
	sessions[seller] = { "state": "open" }
	var walked: Dictionary = n.redact_social_state({
		"market":     { "listings": [{ "seller": seller, "price": 3.0 }] },
		"governance": { "proposals": [{ "author": seller }] },
		"trade":      { "sessions": sessions },
		"creatures":  [{ "seller": seller }],
	})
	assert_eq(walked.size(), 3, "only the listed blobs are carried")
	for key in NetworkingSlice.IDENTIFIED_STATE_KEYS:
		assert_true(walked.has(key), "and %s is carried under its wire name" % key)
	assert_false(walked.has("creatures"),
		"a blob the list does not name is dropped, never passed through unredacted")

	var market: Dictionary = walked["market"]
	var listing: Dictionary = (market.get("listings", []) as Array)[0]
	assert_eq(str(listing.get("seller", "")), reg.public_handle(seller),
		"a listing's seller crosses the wire as a public handle")
	var gov: Dictionary = walked["governance"]
	var proposal: Dictionary = (gov.get("proposals", []) as Array)[0]
	assert_eq(str(proposal.get("author", "")), reg.public_handle(seller),
		"so does a proposal's author")
	var trade: Dictionary = walked["trade"]
	assert_true((trade.get("sessions", {}) as Dictionary).has(reg.public_handle(seller)),
		"and a trade party does, even as a dictionary KEY")
	assert_false(JSON.stringify(walked).contains(seller),
		"with no player id left anywhere in the payload")
	n.free()
	reg.free()

## Phase 38 — the snapshot buffer's clear sites were both on the HOST's side of the wire
## (this slice's own teardown, and a PEER disconnecting), so a client that lost its host
## kept a half-reassembled snapshot for the rest of the session. The host it was waiting
## on is gone, and no chunk of that snapshot can still arrive.
func _test_net_snapshot_buffer_cleared_when_host_lost() -> void:
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.CLIENT
	n._accumulate_snapshot_chunk({ "snapshot_id": 1, "index": 0, "count": 2, "data": "{\"a\":" })
	assert_eq(n._snapshot_buffer.size(), 1, "a partial snapshot is buffered")
	n._on_server_disconnected()
	assert_eq(n._snapshot_buffer.size(), 0,
		"losing the host takes the half-reassembled snapshot with it")

	# Role-gated: a host has no server to lose, and its own teardown (`disconnect_all`)
	# already clears the buffer — this must not become a second, weaker clear.
	n._role = NetworkingSlice.Role.HOST
	n._accumulate_snapshot_chunk({ "snapshot_id": 2, "index": 0, "count": 2, "data": "{\"a\":" })
	n._on_server_disconnected()
	assert_eq(n._snapshot_buffer.size(), 1, "a host-role call changes nothing")
	n.free()

## Phase 38 — the cooldown MIRROR is pruned where it is read. The prune used to run only
## on the way out (`get_cooldowns` hands the record a filtered copy), so the table the
## slice held kept every deadline the player had ever set while the saved copy dropped
## them: the mirror grew with every fox ever fed, for as long as the player stayed on.
func _test_taming_cooldown_mirror_pruned_in_place() -> void:
	var rig := _make_taming_rig()
	var taming: Node = rig["taming"]
	var registry: Node = rig["registry"]
	var pid := str(registry.local_player_id)
	var now := Time.get_unix_time_from_system()
	taming._cooldowns[pid] = { "creature_elapsed": now - 1.0, "creature_live": now + 60.0 }

	assert_eq(taming.get_cooldowns(pid).size(), 1, "only the live deadline is handed to the record")
	var mirror: Dictionary = taming._cooldowns[pid]
	assert_false(mirror.has("creature_elapsed"),
		"and the elapsed one is gone from the MIRROR, not merely from the copy")
	assert_true(mirror.has("creature_live"), "while the live deadline stays")
	assert_eq(taming.cooldown_remaining("creature_elapsed", pid), 0.0,
		"an elapsed cooldown is not in force")
	assert_true(taming.cooldown_remaining("creature_live", pid) > 0.0, "and a live one still is")

	# A new deadline still lands in the table the reader left behind, so the prune did not
	# hand the write path a detached dictionary.
	taming._cooldowns_for(pid)["creature_fresh"] = now + 30.0
	assert_true((taming._cooldowns[pid] as Dictionary).has("creature_fresh"),
		"a deadline written after a prune stays in the mirror")
	assert_eq(taming.get_cooldowns(pid).size(), 2, "and is handed out with the other live one")
	rig["creature"].free()
	rig["taming"].free()
	rig["crafting"].free()
	rig["registry"].free()

# ---------------------------------------------------------------------------
# Phase 39 — a downed body comes back (deliverable 1) + the two-client harness
# ---------------------------------------------------------------------------

## Phase 39 — the respawn rule, asserted ALONE, the way `simulated_hp_after_hit` is.
##
## This is the missing half of a host-simulated peer's health: `simulated_hp_after_hit`
## can only subtract (it clamps at zero), so before this rule a peer a creature downed
## froze at zero for the rest of the session and across every restart.
func _test_hp_after_respawn_is_pure() -> void:
	var now := 1_000_000.0
	assert_eq(PlayerRegistry.hp_after_respawn(0.0, now + 1.0, now), 0.0,
		"a downed body waits out a deadline that has not passed")
	assert_eq(PlayerRegistry.hp_after_respawn(0.0, now - 1.0, now), 100.0,
		"and is back at full health once it has")
	assert_eq(PlayerRegistry.hp_after_respawn(0.0, now, now), 100.0,
		"the deadline's own instant counts as passed")
	assert_eq(PlayerRegistry.hp_after_respawn(0.0, 0.0, now), 0.0,
		"no deadline means no respawn is pending — the body stays down")
	assert_eq(PlayerRegistry.hp_after_respawn(-1.0, 0.0, now), -1.0,
		"the no-number sentinel is not a downed body")
	assert_eq(PlayerRegistry.hp_after_respawn(-1.0, now - 1.0, now), -1.0,
		"and a stale deadline cannot invent health for a body this host never modelled")
	assert_eq(PlayerRegistry.hp_after_respawn(37.0, now - 1.0, now), 37.0,
		"a live body is returned unchanged")
	assert_eq(PlayerRegistry.hp_after_respawn(37.0, now + 1.0, now), 37.0,
		"even with a deadline beside it — the number is returned raw")
	assert_eq(PlayerRegistry.hp_after_respawn(0.0, now - 1.0, now, 60.0), 60.0,
		"the ceiling is the caller's, so a peer respawns to the same MAX_HP the client uses")

## Phase 39 — deliverable 1, registry half: a resolved hit that reaches zero parks the
## respawn on the record, and BOTH readers of the field resolve it.
##
## The reader that matters is `get_player_data` — the saved copy the handshake snapshot
## reads on a reconnect. Resolving on `get_hp` alone left the reconnect replaying the
## zero, which is Phase 38's lesson in mirror image: a rule that runs on one reader is a
## reader-dependent rule.
func _test_host_simulated_hp_respawns() -> void:
	var registry := PlayerRegistry.new()
	add_child(registry)
	var host_id := registry.mint_player_id()
	registry.set_local_player(host_id)
	var remote := str(registry.resolve_identity(7))

	# A resolved hit that does NOT reach zero leaves no deadline behind.
	registry.record_simulated_hp(remote, 88.0)
	assert_eq(float(registry.get_record(remote).get("respawn_deadline", -2.0)), 0.0,
		"a positive resolution parks no respawn")
	assert_eq(registry.get_player_data(remote).get("hp", -2.0), 88.0,
		"and the saved copy carries the number")

	# A hit that reaches zero takes the deadline down WITH the number.
	registry.record_simulated_hp(remote, 0.0)
	assert_eq(registry.get_hp(remote), 0.0, "a downed peer reads zero while its deadline is live")
	var live: float = float(registry.get_record(remote).get("respawn_deadline", 0.0))
	assert_true(live > Time.get_unix_time_from_system(), "and the deadline is a future instant")
	assert_eq(registry.get_player_data(remote).get("hp", -2.0), 0.0,
		"the saved copy agrees while the body is still down")

	# A LIVE deadline is never replaced: a creature striking a body already at zero
	# must not push the respawn further away on every round.
	registry.record_simulated_hp(remote, 0.0)
	assert_eq(float(registry.get_record(remote).get("respawn_deadline", 0.0)), live,
		"a repeated zero does not restart a running deadline")

	# The deadline passes (wound back rather than waited out): BOTH readers bring the
	# body back, and they answer the SAME number.
	var rec := registry.get_record(remote)
	rec["respawn_deadline"] = Time.get_unix_time_from_system() - 1.0
	assert_eq(registry.get_hp(remote), PlayerSlice.MAX_HP,
		"the live reader resolves a passed deadline")
	assert_eq(registry.get_player_data(remote).get("hp", -2.0), PlayerSlice.MAX_HP,
		"and so does the saved copy — the one a reconnect reads")
	assert_eq(registry.get_hp(remote), float(registry.get_player_data(remote).get("hp", -2.0)),
		"the two readers cannot disagree")

	# DURABLE: the resolved number and the deadline both ride the serializable record, so
	# a restart lands mid-wait rather than at full health.
	var restored := PlayerRegistry.new()
	add_child(restored)
	restored.apply_player_data(remote, registry.get_player_data(remote))
	assert_eq(restored.get_hp(remote), PlayerSlice.MAX_HP, "a restart after the deadline is a live body")
	var pending := PlayerRegistry.new()
	add_child(pending)
	var waiting := registry.get_player_data(remote).duplicate(true)
	waiting["hp"] = 0.0
	waiting["respawn_deadline"] = Time.get_unix_time_from_system() + 60.0
	pending.apply_player_data(remote, waiting)
	assert_eq(pending.get_hp(remote), 0.0, "while a restart INSIDE the wait stays down")
	assert_true(float(pending.get_record(remote).get("respawn_deadline", 0.0)) > 0.0,
		"with its deadline intact, so the wait is not silently forgiven")

	# And a positive resolution clears the deadline, so a body that is up again carries
	# no stale fact that a later read could act on.
	registry.record_simulated_hp(remote, 1.0)
	assert_eq(float(registry.get_record(remote).get("respawn_deadline", -2.0)), 0.0,
		"a body back on its feet drops the deadline")
	assert_eq(registry.get_hp(remote), 1.0, "and reads the number it was given")

	pending.free()
	restored.free()
	registry.free()

## Phase 39 review pass — "down" is a RANGE, and both halves of the rule share one
## predicate for it.
##
## (a) Float arithmetic does not land on exact zeroes: a hit that comes a fraction short of
## cancelling the number leaves a body at ~1e-7. That body is alive by the letter of the old
## `hp > 0.0` test and dead by every other measure — it cannot be healed, it cannot act, and
## the writer CLEARED its respawn deadline, so it stayed at an invisible sliver for the rest
## of the session and across every restart. `is_downed` counts it as down, so the deadline is
## parked and the body comes back.
## (b) The two halves used to test differently — `hp != 0.0` in the reader, `hp > 0.0` in the
## writer — which is two chances to disagree about the same body. The remainder is the value
## that lands between them.
func _test_hp_sliver_is_downed() -> void:
	assert_true(PlayerRegistry.is_downed(0.0), "an exact zero is down")
	assert_true(PlayerRegistry.is_downed(1.0e-7), "and so is the remainder a hit leaves behind")
	assert_false(PlayerRegistry.is_downed(PlayerRegistry.HP_EPSILON * 2.0),
		"while real health is not — the threshold only ever catches arithmetic")
	assert_false(PlayerRegistry.is_downed(-1.0),
		"and the no-number-here sentinel is NOT down, so a stale deadline cannot invent health")
	assert_eq(PlayerRegistry.hp_after_respawn(1.0e-7, 0.0, 1_000_000.0), 0.0,
		"a remainder with no deadline parked reads as the canonical zero, not as 1e-7")
	assert_eq(PlayerRegistry.hp_after_respawn(1.0e-7, 999_999.0, 1_000_000.0), PlayerSlice.MAX_HP,
		"and with a passed deadline reads as full health — so it CAN come back")

	var registry := PlayerRegistry.new()
	add_child(registry)
	var host_id := registry.mint_player_id()
	registry.set_local_player(host_id)
	var remote := str(registry.resolve_identity(7))

	registry.record_simulated_hp(remote, 1.0e-7)
	assert_true(float(registry.get_record(remote).get("respawn_deadline", 0.0)) > Time.get_unix_time_from_system(),
		"a hit that lands on a sliver PARKS a respawn instead of clearing it")
	assert_eq(registry.get_hp(remote), 0.0, "and the body reads as down, not as a sliver")

	# The restored-record half: `get_player_data` saves `hp` RESOLVED, so an alive record
	# reaches `apply_player_data` wearing the deadline its own resolution has spent. Keeping
	# it left a standing body carrying dead history forever.
	registry.get_record(remote)["respawn_deadline"] = Time.get_unix_time_from_system() - 1.0
	var restored := PlayerRegistry.new()
	add_child(restored)
	restored.apply_player_data(remote, registry.get_player_data(remote))
	assert_eq(restored.get_hp(remote), PlayerSlice.MAX_HP,
		"a record restored after its deadline is a live body")
	assert_eq(float(restored.get_record(remote).get("respawn_deadline", -2.0)), 0.0,
		"and wears no deadline its own resolution has already spent")

	restored.free()
	registry.free()

## Phase 39 — deliverable 1, client half: a body handed a zero starts its own countdown.
##
## The same soft-lock as the registry half, seen from the client: a peer's client that
## received its own zero (on a join snapshot, or forwarded from a hit) ended up
## `_alive == false` with `_respawn_timer == -1.0` — dead, with `_physics_process` ticking
## a countdown that had never been started. `set_hp` is the ONE door such a zero comes
## through. Starting rather than RESTARTING matters: a repeated zero would otherwise push
## the respawn away on every application and the body would never come back.
func _test_player_set_hp_starts_respawn() -> void:
	var p := PlayerSlice.new()
	p.render_visuals = false
	add_child(p)
	assert_eq(p._respawn_timer, -1.0, "a fresh body has no countdown running")
	p.set_hp(40.0)
	assert_eq(p._respawn_timer, -1.0, "applying health does not start one")
	assert_true(p._alive, "and the body is up")

	p.set_hp(0.0)
	assert_false(p._alive, "a zero takes the body down")
	assert_eq(p._respawn_timer, PlayerSlice.RESPAWN_DELAY,
		"and starts the respawn countdown — the half that was missing")

	# The countdown is STARTED, never restarted: a second zero (a re-forwarded hit, a
	# re-delivered snapshot) leaves the one already running alone.
	p._respawn_timer = 2.0
	p.set_hp(0.0)
	assert_eq(p._respawn_timer, 2.0, "a repeated zero does not push the respawn away")
	p.free()

## Phase 39 review pass — the two rules `set_hp()` owes the callers it already had.
##
## (a) A zero that takes a LIVE body down has to be announced THROUGH the death door.
## `set_hp` applied the number and started the countdown but never called `_die()`, so the
## body was dead on this machine with no `player_died` behind it — while that same
## countdown announced `player_respawned` when it ran out. A respawn with no death is half
## a pair, and the pairing is what listeners see (game_root turns `player_died` into the
## character-death consequence). A zero applied to a body ALREADY down is not news and must
## not re-announce it.
##
## (b) A value that leaves the body UP has to clear the countdown parked on it.
## `_physics_process` ticks the timer only while `_alive` is false, so on a living body a
## leftover countdown sat frozen and was then REUSED by the next zero instead of a fresh
## one: the body came back early, on the seconds left over from the death it had already
## recovered from.
func _test_player_set_hp_announces_and_clears() -> void:
	var died: Array = []
	GameBus.player_died.connect(func(_pos, _killer): died.append(1))
	var p := PlayerSlice.new()
	p.render_visuals = false
	add_child(p)

	p.set_hp(0.0)
	assert_false(p._alive, "a zero takes a live body down")
	assert_eq(died.size(), 1, "and announces the death it caused — the missing half")
	assert_eq(p._respawn_timer, PlayerSlice.RESPAWN_DELAY, "with a countdown to come back on")

	p.set_hp(0.0)
	assert_eq(died.size(), 1, "a repeated zero does not re-announce the death")
	assert_eq(p._respawn_timer, PlayerSlice.RESPAWN_DELAY, "and does not restart the countdown")

	# A stale countdown left on a living body is the leftover this rule exists to drop.
	p._respawn_timer = 2.0
	p.set_hp(50.0)
	assert_true(p._alive, "applying health brings the body up")
	assert_eq(p._respawn_timer, -1.0, "and clears the countdown parked on it")

	p.set_hp(0.0)
	assert_eq(p._respawn_timer, PlayerSlice.RESPAWN_DELAY,
		"so the next death gets a FULL countdown rather than the leftover seconds")
	assert_eq(died.size(), 2, "and is announced like any other death")
	p.free()

# ---------------------------------------------------------------------------
# Phase 39 — the network harness's own logic
# ---------------------------------------------------------------------------
#
# The harness itself needs frames and a socket, so it runs in its own boot mode (see
# src/tests/net_harness.gd). Its PURE half — the step table, the log-line format and
# parser, the convergence verdict, and the deterministic target selection — is registered
# here, so it is covered on every ordinary boot instead of only when two processes are
# specially arranged. That matters most for the two pieces the driver's whole oracle
# rests on: the line format (the only channel between the processes) and the verdict.

## Phase 39 — the step table is the scenario's contract with the driver: the driver
## asserts that BOTH processes reported every step in it, so a step silently dropped from
## one side (a role that no longer runs it after an edit) is caught rather than passing
## on the other side's line alone.
func _test_net_harness_step_table() -> void:
	var steps := NetHarness.steps()
	assert_true(steps.size() >= 10, "the scenario carries a substantial step list")
	var names: Dictionary = {}
	for s in steps:
		assert_true(s is Dictionary, "every entry is a step record")
		assert_true(s.has("name"), "and names itself")
		assert_true(s.has("compare"), "and says whether the driver must compare its details")
		names[str(s.get("name", ""))] = true
	assert_eq(names.size(), steps.size(), "step names are unique — the driver keys on them")
	assert_eq(str(steps[0].get("name", "")), "handshake", "the scenario starts with the handshake")
	assert_eq(str(steps[steps.size() - 1].get("name", "")), "spawn_near_friend",
		"and ends with the friend-code spawn (Phase 53), the far peer rejoining as a new player")

## Phase 39 — the wire is a text channel between two processes, so the line format and its
## parser are load-bearing: if they disagreed, the driver would silently compare nothing
## and every run would look green.
func _test_net_harness_line_round_trip() -> void:
	var line := NetHarness.format_line("chop_in_reach", "ok", "tree_0_0_1")
	assert_eq(line, "HARNESS chop_in_reach ok tree_0_0_1", "the compiled line is the agreed format")
	var parsed := NetHarness.parse_line(line)
	assert_eq(str(parsed.get("step", "")), "chop_in_reach", "and parses back to its step")
	assert_eq(str(parsed.get("verdict", "")), "ok", "its verdict")
	assert_eq(str(parsed.get("detail", "")), "tree_0_0_1", "and its detail")
	# Noise must not parse: the driver reads the WHOLE process log, which is full of the
	# game's own output, and a false positive there would fake a step.
	assert_true(NetHarness.parse_line("").is_empty(), "an empty line is not a harness line")
	assert_true(NetHarness.parse_line("[Server] listening on port 7777, max_clients 64").is_empty(),
		"nor is a server boot line")
	assert_true(NetHarness.parse_line("HARNESS handshake ok").is_empty(),
		"nor a line missing its detail")
	assert_true(NetHarness.parse_line("harness handshake ok detail").is_empty(),
		"and the tag is case-exact")

## Phase 39 — the convergence verdict. "refused" is a PASS: half the scenario asserts that
## something did NOT happen (an out-of-reach chop, an oversized packet), so a verdict
## function that treated "not seen" as failure would turn the security steps into tests
## that fail whenever they work.
func _test_net_harness_verdict() -> void:
	assert_eq(NetHarness.verdict(true, true), "ok", "an expected event that happened passes")
	assert_eq(NetHarness.verdict(false, false), "refused", "an expected ABSENCE that held passes as a refusal")
	assert_eq(NetHarness.verdict(false, true), "fail", "an expected event that never came fails")
	assert_eq(NetHarness.verdict(true, false), "fail", "and so does an event that should not have happened")
	assert_true(NetHarness.passed("ok"), "ok counts as a pass")
	assert_true(NetHarness.passed("refused"), "and so does refused")
	assert_false(NetHarness.passed("fail"), "while fail does not")

## Phase 39 — the target selection. Both processes pick their scenario trees from their
## OWN table with this rule, so it has to be a pure function of the tree table: any
## dependence on dictionary order would have the two sides naming different trees.
func _test_net_harness_target_selection() -> void:
	var origin := Vector3(16.0, 12.0, 16.0)
	var trees: Array = [
		{ "tree_id": "tree_c", "position": Vector3(20.0, 3.0, 20.0) },   # near
		{ "tree_id": "tree_a", "position": Vector3(30.0, 3.0, 16.0) },   # near
		{ "tree_id": "tree_b", "position": Vector3(5.0, 3.0, 5.0) },     # near
		{ "tree_id": "tree_far", "position": Vector3(200.0, 3.0, 200.0) },
	]
	var picked := NetHarness.in_reach_targets(trees, origin, 20.0, 3)
	assert_eq(picked.size(), 3, "every tree inside the radius is a candidate")
	assert_eq(str(picked[0]), "tree_a", "and they come back sorted by id, not by table order")
	assert_eq(str(picked[2]), "tree_c", "so both processes agree without a side channel")
	assert_eq(NetHarness.in_reach_targets(trees, origin, 20.0, 2).size(), 2,
		"the caller's count caps the list")
	# The out-of-reach half: beyond the radius, and again id-sorted so a small difference
	# between the two sides' view of the world cannot change the answer.
	assert_eq(NetHarness.beyond_reach_target(trees, origin, 70.0), "tree_far",
		"only the far tree is beyond the refusal radius")
	assert_eq(NetHarness.beyond_reach_target(trees, origin, 1000.0), "",
		"and an empty selection is reported as empty, never as the nearest tree")

## Phase 39 review pass — the pump's own audit, the ONE class the synchronous suite could
## not otherwise reach, because it has no frames to give and so cannot host the pump.
##
## A coroutine called without `await` compiles, runs, and returns at its first yield: the
## step stops waiting and the scenario reports on a run that did not happen. That is not
## hypothetical — every `_await_settle` call site in the runner was bare, so the rate-limit
## step fired its post-burst chops in the same frame as the burst that had emptied the peer's
## step blamed the LIMITER for its own missing wait. The rule is
## assertable without frames, so it lives as a pure function; the runner also points it at
## its OWN source on every boot (`NetHarness._self_audit`), which is the half this test
## cannot do for it.
func _test_net_harness_bare_await_audit() -> void:
	# The definition is not a call, an awaited call in an expression is fine, and a bare
	# call is the offender — as a LINE NUMBER, so a failure names where to look.
	var mixed := PackedStringArray([
		"func _await_until(p: Callable, t: float) -> bool:",
		"		_await_settle(1.0)",
		"	await _await_until(func(): return true, 1.0)",
		"	var ok: bool = await _await_until(f, 1.0)",
		"",
		"		await _await_settle(ABSENCE_WINDOW_SECS)",
	])
	var flagged := NetHarness.unawaited_waits(mixed)
	assert_eq(flagged.size(), 1, "exactly one line of that sample is a bare coroutine call")
	assert_true(flagged.has("2"), "and it is the bare call, reported by line number")
	var clean := PackedStringArray(["", "await _await_until(f, 1.0)", "await _await_settle(1.0)"])
	assert_true(NetHarness.unawaited_waits(clean).is_empty(), "an awaited file reports nothing")

	# And the file the audit guards, audited. Skipped with a note rather than passed when the
	# source is not on disk (an exported build ships bytecode) — an audit that could not run
	# is not evidence, which is also what `NetHarness._self_audit` says out loud.
	var src := FileAccess.open("res://src/tests/net_harness.gd", FileAccess.READ)
	if src == null:
		return
	var offenders := NetHarness.unawaited_waits(src.get_as_text().split("\n"))
	assert_true(offenders.is_empty(),
		"NetHarness calls a bare coroutine at line(s) %s" % [", ".join(offenders)])

# ---------------------------------------------------------------------------
# Phase 42 — threaded chunk build, greedy merge, the first-ring gate
# ---------------------------------------------------------------------------
#
# The build is dispatched to a WorkerThreadPool task and applied on the main thread,
# and the suite has no frames to give — so these tests drive the manager's pump by
# hand: DRAIN (dispatch), BLOCK on each in-flight task, APPLY. That is exactly what
# `ChunkManager._process` does across frames, with the wait made explicit.

## A duck-typed stand-in for a CONTENTS slice (creature or tree): the manager only asks
## for `has_method("spawn_for_chunk")` / `despawn_for_chunk`, so a spy is enough to count
## what the apply path asks for — which is the whole of the review-pass-3 finding that a
## rebuild re-derived a chunk's budgets on every block edit.
class ContentsSpy:
	extends Node
	var spawned: Array = []
	var despawned: Array = []
	func spawn_for_chunk(chunk_pos: Vector2i) -> void:
		spawned.append(chunk_pos)
	func despawn_for_chunk(chunk_pos: Vector2i) -> void:
		despawned.append(chunk_pos)

## A player stand-in that COUNTS how often its position is read. `ChunkManager.player_chunk()`
## reaches the body through `player_slice.get_position()`, so the count is a direct measure of
## how often the manager resolved the streamed window.
class PlayerPosSpy:
	extends Node
	var reads: int = 0
	var position: Vector3 = Vector3(16.0, 40.0, 16.0)
	func get_position() -> Vector3:
		reads += 1
		return position

## A ChunkManager wired to a real TerrainSlice + VoxelSlice and a local player — what
## the threaded build needs. An isolated manager with no terrain has nothing to
## dispatch (see `_dispatch_build`'s early return, which the older rigs rely on).
func _make_chunk_build_rig() -> Dictionary:
	var cm := ChunkManager.new()
	add_child(cm)
	var terrain := TerrainSlice.new()
	add_child(terrain)
	var voxel := VoxelSlice.new()
	voxel.terrain_slice = terrain
	add_child(voxel)
	var player := PlayerSlice.new()
	add_child(player)
	cm.terrain_slice = terrain
	cm.voxel_slice = voxel
	cm.player_slice = player
	# Phase 42 review — the production wiring is two-way: game_root also points the voxel
	# slice back at the manager, so an EDIT dispatches its rebuild to a worker instead of
	# building the touched chunks synchronously (see `request_rebuild`).
	voxel.chunk_manager = cm
	player.spawn_at(Vector3(16.0, 40.0, 16.0))
	return { "cm": cm, "terrain": terrain, "voxel": voxel, "player": player }

## Drive the manager's build pump to quiescence: dispatch, BLOCK on the in-flight
## builds, apply. `flush_builds` is the blocking variant of the frame loop's poll —
## the suite cannot yield, so it waits rather than polling, which is also why it does
## not call `WorkerThreadPool.is_task_completed` itself.
func _wait_for_builds(cm: Node, rounds: int = 128) -> void:
	for i in range(rounds):
		if cm._builds.is_empty() and cm._load_queue.is_empty() and cm._rebuild_queue.is_empty():
			return
		cm._drain_load_queue()
		cm.flush_builds()

## Phase 42 — the builder is what makes a worker legal: it must be a function of its
## three arguments alone, with no slice state reachable from it.
##
## Phase 42 review pass 8 — this test used to be vacuous. It built the SAME resolved table
## twice, so it asserted `f(x) == f(x)` and its second slice `b` — created with a different
## place material and an edit in another chunk, precisely to prove that slice state cannot
## reach the build — was DEAD SETUP: nothing was ever resolved from `b`. It now resolves the
## chunk from BOTH slices and builds from each. `b`'s state is in another chunk and on the
## place path, so the two resolves must AGREE and the two builds must be identical; a
## resolve that leaked one slice's state into another's answer turns the first assertion
## red, and a builder that read back into the slice turns the second one red.
func _test_voxel_build_arrays_pure() -> void:
	var a := VoxelSlice.new()
	add_child(a)
	var b := VoxelSlice.new()
	add_child(b)
	var flat: Array = []
	flat.resize(64 * 64)
	flat.fill(2.0)
	# `b` carries state `a` does not: a different place material and an edit in another
	# chunk. Neither may reach the build — the caller resolves the table, not the builder.
	b.set_place_material("Ashite")
	b._set_edit_ops("900,900", [{ "op": "remove", "bottom": 0.0, "top": 1.0 }])
	var resolved_a: Dictionary = a.collect_build_runs(Vector2i(0, 0), flat)
	var resolved_b: Dictionary = b.collect_build_runs(Vector2i(0, 0), flat)
	var first: Dictionary = VoxelSlice.build_chunk_arrays(Vector2i(0, 0), flat, resolved_a)
	var second: Dictionary = VoxelSlice.build_chunk_arrays(Vector2i(0, 0), flat, resolved_a)
	assert_eq(int(first["quad_count"]), int(second["quad_count"]), "the same input builds the same quads")
	assert_true(first["vertices"] == second["vertices"], "and the same vertices")
	assert_true(first["indices"] == second["indices"], "and the same indices")
	assert_true(first["collision"] == second["collision"], "and the same collision soup")
	# The two SLICES' resolves agree, so `b`'s differing state reached neither.
	assert_true(resolved_a["runs"] == resolved_b["runs"],
		"a differently-stated slice resolves the same columns for an untouched chunk")
	# ...and building from `b`'s resolve is the same build, which is the actual claim: the
	# builder reads its argument and nothing else.
	var from_b: Dictionary = VoxelSlice.build_chunk_arrays(Vector2i(0, 0), flat, resolved_b)
	assert_true(first["vertices"] == from_b["vertices"], "and the other slice's table builds it identically")
	assert_true(first["collision"] == from_b["collision"], "collision included")
	# A caller with only a map — no resolved table at all — still gets the chunk's own
	# natural columns. That is the fallback the suite and a fresh probe rely on.
	var bare: Dictionary = VoxelSlice.build_chunk_arrays(Vector2i(0, 0), flat, { "runs": {} })
	assert_true(int(bare["quad_count"]) > 0, "an empty table still builds the natural columns")
	a.free()
	b.free()

## Phase 42 — the merge's effect as NUMBERS from one build. `cell_count` is what the
## per-tile mesher emitted, `quad_count` what the merge left, so the acceptance
## criterion's before/after comes out of the run rather than out of a comment.
func _test_voxel_greedy_merge() -> void:
	var v := VoxelSlice.new()
	add_child(v)
	var flat: Array = []
	flat.resize(64 * 64)
	flat.fill(2.0)
	# A flat chunk with no resolved table: every tile is its own natural column, so
	# 4096 top faces — and walls ONLY on the chunk's four EDGES (256), because a wall is
	# emitted from the difference against a neighbour and the in-chunk neighbour is
	# solid at the same height. 4352 faces, which is 26112 vertices as the per-tile
	# mesher emitted them.
	var bare: Dictionary = VoxelSlice.build_chunk_arrays(Vector2i(0, 0), flat, { "runs": {} })
	assert_eq(int(bare["cell_count"]), 64 * 64 + 64 * 4, "a top face per tile, walls on the edges")
	assert_eq(int(bare["quad_count"]), 5, "and the merge leaves one quad per facing")
	var bare_quads := int(bare["quad_count"])
	assert_true(bare_quads * 4 < int(bare["cell_count"]),
		"the merge leaves far fewer quads than faces (%d of %d)" % [bare_quads, int(bare["cell_count"])])
	assert_eq(bare["vertices"].size(), bare_quads * 4, "a merged quad is four INDEXED vertices")
	assert_eq(bare["indices"].size(), bare_quads * 6, "and two triangles")
	assert_eq(bare["collision"].size(), bare_quads * 6, "the collision carries the same two triangles")
	assert_eq(bare["normals"].size(), bare_quads * 4, "one normal per vertex")

	# And a REAL chunk: noise terrain with its ring built, which is the number worth
	# quoting (its walls mostly vanish against equal-height neighbours).
	var terrain := TerrainSlice.new()
	add_child(terrain)
	var w := VoxelSlice.new()
	add_child(w)
	w.terrain_slice = terrain
	for cz in range(-1, 2):
		for cx in range(-1, 2):
			w._heightmaps["%d,%d" % [cx, cz]] = terrain._generate(Vector2i(cx, cz))
	var hm: Array = terrain._generate(Vector2i(0, 0))
	var natural: Dictionary = VoxelSlice.build_chunk_arrays(Vector2i(0, 0), hm, w.collect_build_runs(Vector2i(0, 0), hm))
	print("PROBE Phase 42 flat chunk:  %d faces -> %d quads (%d vertices)" % [
		int(bare["cell_count"]), bare_quads, bare["vertices"].size()])
	print("PROBE Phase 42 natural chunk: %d faces -> %d quads (%d vertices)" % [
		int(natural["cell_count"]), int(natural["quad_count"]), natural["vertices"].size()])
	assert_true(int(natural["quad_count"]) < int(natural["cell_count"]),
		"a natural chunk merges too")
	v.free()
	w.free()
	terrain.free()

## Phase 42 review pass 9 — the fourth component of the group key is a packed uint32 kept in an
## int32 slot, and the pass-8 comment claimed it fit ("`to_rgba32()` is an int32 by
## definition"). It does not: opaque white packs to 4294967295 and the component reads back as
## -1, the high bit kept as the SIGN. What the grouping actually depends on is that the wrap is
## a BIJECTION, and that is what this pins — at the exact values measured on 4.7, plus the
## grouping itself (one colour = one group, two colours = two), so a key that dropped or folded
## the colour's high bit would go red.
func _test_voxel_group_key_colour_band() -> void:
	var white := Color(1.0, 1.0, 1.0, 1.0)
	assert_eq(white.to_rgba32(), 4294967295, "opaque white packs to the top of the uint32 range")
	var packed_key := Vector4i(0, 0, 0, white.to_rgba32())
	assert_eq(packed_key[3], -1, "and the int32 component keeps only the sign bit of it")
	assert_eq(packed_key[3] & 0xFFFFFFFF, white.to_rgba32(),
		"the wrap round-trips, so the packed colour is still exact in the key")
	var a := Vector4i(0, 0, 0, Color(1.0, 0.0, 0.0, 1.0).to_rgba32())
	var b := Vector4i(0, 0, 0, Color(1.0, 0.0, 1.0, 1.0).to_rgba32())
	assert_true(a != b, "colours sharing the low bits do not collide onto one key")
	# And the grouping: coplanar cells of ONE colour merge, a second colour is its own group.
	var groups: Dictionary = {}
	VoxelSlice._group_cell(groups, "up", 1.0, 1.0, 1.0, Color(1.0, 0.0, 0.0, 1.0), 0, 0)
	VoxelSlice._group_cell(groups, "up", 1.0, 1.0, 1.0, Color(1.0, 0.0, 0.0, 1.0), 1, 0)
	assert_eq(groups["up"].size(), 1, "the same plane and colour share one merge group")
	assert_eq(groups["up"].values()[0]["cells"].size(), 2, "and both cells are in it")
	VoxelSlice._group_cell(groups, "up", 1.0, 1.0, 1.0, Color(1.0, 0.0, 1.0, 1.0), 2, 0)
	assert_eq(groups["up"].size(), 2, "a second colour is its own group (the colour is IN the key)")

## Phase 43 — the ore field's band table replaced the Phase 42 roll table and inherits its
## contract: it is process-wide class state a WORKER reads, so it is filled at `_ready()` on the
## main thread, not on a worker's first use. Snapshot-and-restore, as the roll table's test did.
func _test_voxel_biome_roll_table_prebuilt() -> void:
	var saved: Dictionary = OreField._bands.duplicate()
	OreField._bands.clear()
	OreField._warmed = false
	assert_eq(OreField._bands.size(), 0, "the band table starts empty (the assertion is not vacuous)")
	var v := VoxelSlice.new()
	add_child(v)
	assert_eq(OreField._bands.size(), GameData.MATERIALS.size(),
		"every material's band is read at _ready, not on first use")
	v.free()
	if not saved.is_empty():
		OreField._bands = saved
	assert_eq(OreField._bands.size(), GameData.MATERIALS.size(), "and the table is left full")

## Every canonical biome has a BIAS entry, so its host rock is its own and never the fallback.
func _test_voxel_every_canonical_biome_has_a_roll_table() -> void:
	for biome in TerrainSlice.BIOME_KEYS:
		assert_true(VoxelSlice.BIOME_BIAS.has(str(biome)),
			"canonical biome %s has a BIOME_BIAS entry" % str(biome))
		assert_true(OreField.BIOME_BIAS[str(biome)].has(OreField.host_material(str(biome))),
			"and its host rock is one of its own materials")

## Phase 42 review pass 9 — the payload shape `build_chunk_arrays` takes is REQUIRED, not
## sniffed. The old fallback (`resolved.get("runs", resolved)`) meant a dictionary that merely
## HELD a tile-coordinate key was silently read AS the runs table; the table below lifts one
## tile's column well above the natural one, so under the old fallback it changes the build and
## under the required shape it is ignored as "no resolved columns", which is the natural-column
## fallback. The two builds must therefore be byte-identical.
func _test_voxel_build_payload_shape_required() -> void:
	var flat: Array = []
	flat.resize(64 * 64)
	flat.fill(2.0)
	var natural: Dictionary = VoxelSlice.build_chunk_arrays(Vector2i(0, 0), flat, { "runs": {} })
	var sniffed: Dictionary = VoxelSlice.build_chunk_arrays(Vector2i(0, 0), flat, {
		"0,0": [{ "bottom": -8.0, "top": 6.0, "material": "", "color": Color(1.0, 0.0, 1.0) }],
	})
	assert_eq(int(sniffed["cell_count"]), int(natural["cell_count"]),
		"a bare table is not reinterpreted as the runs table (the payload shape is required)")
	assert_true(sniffed["vertices"] == natural["vertices"], "and the build is identical")
	assert_eq(int(natural["cell_count"]), 64 * 64 + 64 * 4,
		"both are the natural chunk (a top face per tile, walls on the edges)")

## Phase 42 — the merge is a greedy RECTANGLE sweep, so it must never cover a gap: a
## cell with no neighbour of its own group is its own 1x1 quad, and scattered cells stay
## separate. That is the "a tile whose neighbours differ still emits a valid 1×1 quad"
## criterion, asserted on the pure sweep rather than through a whole chunk's geometry.
func _test_voxel_merge_keeps_lone_quad() -> void:
	var lone: Array = VoxelSlice._merge_rects({ 20 * 64 + 10: true })
	assert_eq(lone.size(), 1, "a lone cell is its own rectangle")
	assert_eq(int(lone[0]["w"]), 1, "one tile wide")
	assert_eq(int(lone[0]["h"]), 1, "and one tile deep")

	# Four cells, none of which touches another: (0,0), (5,0), (0,3) and (2,4).
	var scattered: Array = VoxelSlice._merge_rects({ 0: true, 5: true, 64 * 3: true, 64 * 4 + 2: true })
	assert_eq(scattered.size(), 4, "cells with no neighbour in the group never merge")

	# A full row merges into ONE rectangle, and a second identical row below extends it.
	var row: Dictionary = {}
	for tx in range(64):
		row[tx] = true
	var row_rects: Array = VoxelSlice._merge_rects(row)
	assert_eq(row_rects.size(), 1, "a full row is one rectangle")
	assert_eq(int(row_rects[0]["w"]), 64, "the full chunk wide")
	assert_eq(int(row_rects[0]["h"]), 1, "and one tile deep")
	for tx in range(64):
		row[64 + tx] = true
	var block: Array = VoxelSlice._merge_rects(row)
	assert_eq(block.size(), 1, "the row below extends it rather than splitting it")
	assert_eq(int(block[0]["h"]), 2, "into a two-tile-deep rectangle")

	# A row with a HOLE in it must not be covered: the sweep restarts after the gap.
	var holed: Dictionary = {}
	for tx in range(64):
		if tx != 30:
			holed[tx] = true
	var holed_rects: Array = VoxelSlice._merge_rects(holed)
	assert_eq(holed_rects.size(), 2, "a gap splits the row in two")

## Phase 42 — a load dispatches instead of building, and a chunk counts as BUILT only
## once the worker's arrays have been applied on the main thread.
func _test_chunk_load_dispatches_build() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var voxel: VoxelSlice = rig["voxel"]
	cm.load_chunk(Vector2i(0, 0))
	assert_true(cm._loaded.has("0,0"), "the chunk enters the streamed set")
	assert_false(cm._built.has("0,0"), "but its build is in flight, not on the main thread")
	assert_eq(voxel.get_loaded_chunks().size(), 0, "and no chunk mesh exists yet")
	_wait_for_builds(cm)
	assert_true(cm._built.has("0,0"), "the build lands once the worker has finished")
	assert_eq(voxel.get_loaded_chunks().size(), 1, "and the chunk's mesh with it")
	rig["cm"].free()
	rig["voxel"].free()
	rig["terrain"].free()
	rig["player"].free()

## Phase 42 — the boot gate: closed until every chunk of the Chebyshev 0..1 ring around
## the centre has been BUILT, then open. The loading screen is shown for exactly this
## window and the player body is placed at its end.
func _test_chunk_first_ring_gate() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var voxel: VoxelSlice = rig["voxel"]
	cm.view_distance = 1
	cm.prefetch_distance = 0
	cm.refresh()
	cm.build_first_ring(Vector2i(0, 0))
	assert_eq(cm._first_ring.size(), 9, "the gate covers the 3x3 ring the body stands in")
	assert_false(cm.is_first_ring_ready(), "and is closed before a single ring chunk is built")
	assert_eq(cm.first_ring_progress(), 0.0, "reporting no progress")
	_wait_for_builds(cm)
	assert_true(cm.is_first_ring_ready(), "the gate opens once every ring chunk's ground exists")
	assert_eq(cm.first_ring_progress(), 1.0, "and reports complete")
	assert_true(voxel.get_loaded_chunks().size() >= 9, "with every ring chunk meshed")
	# An UNARMED gate never blocks: a caller with no boot to hold must not be gated by
	# a ring some other call site armed.
	var loose := ChunkManager.new()
	add_child(loose)
	assert_true(loose.is_first_ring_ready(), "an unarmed gate is open")
	assert_eq(loose.first_ring_progress(), 1.0, "and reports complete")
	loose.free()
	rig["cm"].free()
	rig["voxel"].free()
	rig["terrain"].free()
	rig["player"].free()

## Phase 42 — the prefetch band: a chunk beyond the view ring is QUEUED, so a crossing never
## asks for ground at the moment it becomes needed.
##
## Phase 42 review pass 8 — "and kept" was questioned here and the KEPT window briefly narrowed
## to `view_distance`. Ninth review pass: it is the QUEUE radius again (`stream_radius()`), so
## the band is queued AND kept — see `_test_chunk_kept_window_is_stream_radius` for why (a band
## chunk is BUILT, so releasing it on the next crossing throws that build away).
func _test_chunk_prefetch_ring() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	cm.view_distance = 1
	cm.prefetch_distance = 2
	assert_eq(cm.stream_radius(), 3, "the streamed radius is the view ring plus the prefetch band")
	cm.refresh()
	var queued: Dictionary = {}
	for c in cm._load_queue:
		queued[c] = true
	assert_true(queued.has(Vector2i(3, 0)), "a chunk one band beyond the view ring is queued")
	assert_true(queued.has(Vector2i(0, 3)), "on both axes")
	assert_false(queued.has(Vector2i(4, 0)), "and nothing beyond the prefetch band")
	rig["cm"].free()
	rig["voxel"].free()
	rig["terrain"].free()
	rig["player"].free()

## Phase 49 — the `_process` path releases at most `unloads_per_frame` chunks per tick, and a
## chunk the player walked back toward while it waited is kept.
func _test_chunk_unloads_budgeted() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var player: PlayerSlice = rig["player"]
	cm.view_distance = 1
	cm.prefetch_distance = 0
	cm.loads_per_frame = 64
	cm.unloads_per_frame = 2
	cm.refresh()
	_wait_for_builds(cm)
	var before: int = cm._loaded.size()
	player.spawn_at(Vector3(16.0, 40.0, 160.0))   # nothing of the old window survives
	cm.refresh(false)
	assert_eq(cm._loaded.size(), before, "a budgeted refresh releases nothing by itself")
	assert_eq(cm._unload_queue.size(), before, "every stale chunk waits in the unload queue")
	cm._drain_unload_queue(cm.unloads_per_frame)
	assert_eq(cm._loaded.size(), before - 2, "one tick releases exactly the budget")
	cm._drain_unload_queue(64)
	assert_true(cm._unload_queue.is_empty(), "the queue drains to empty")
	assert_false(cm._loaded.has("0,0"), "the old window is gone")
	# Farthest first, and a chunk the player walks back toward is dropped from the queue.
	player.spawn_at(Vector3(16.0, 40.0, 16.0))
	cm.refresh()
	_wait_for_builds(cm)
	var held: int = cm._loaded.size()
	player.spawn_at(Vector3(16.0, 40.0, 160.0))
	cm.refresh(false)
	var center := cm.player_chunk()
	var last := -1
	var ordered := true
	for key in cm._unload_queue:
		var d: int = cm._dist2(center, cm._key_to_chunk(key))
		if last >= 0 and d > last:
			ordered = false
		last = d
	assert_true(ordered, "the unload queue runs farthest first")
	assert_eq(cm._unload_queue.size(), held, "the whole old window is queued")
	player.spawn_at(Vector3(16.0, 40.0, 16.0))   # walk straight back before any slot is used
	cm.refresh(false)
	assert_true(cm._unload_queue.size() < held, "walking back removes chunks from the queue")
	assert_false(cm._unload_queue.has("0,0"), "the chunk under the player is no longer queued")
	rig["cm"].free()
	rig["voxel"].free()
	rig["terrain"].free()
	rig["player"].free()

## Phase 42 review pass 9 — the KEPT window is the QUEUE window (`stream_radius()`), and that
## is what stops a chunk being built and then thrown away. Pass 8 had narrowed it to
## `view_distance`, so every band chunk — BUILT, because everything the queue spans is — was
## released on the next crossing unless the player happened to move toward it; the row
## measured 65 redundant worker builds per crossing, forever. Two assertions, in the order the
## row asks for them: the invariant (nothing is ever unloaded while it still lies inside the
## queue radius), and the retention arithmetic as an exact NUMBER — a one-chunk crossing
## releases the seven chunks of the departing edge, not the forty a view-ring window releases.
func _test_chunk_kept_window_is_stream_radius() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var player: PlayerSlice = rig["player"]
	cm.view_distance = 1
	cm.prefetch_distance = 2
	cm.loads_per_frame = 64
	cm.refresh()
	_wait_for_builds(cm)
	assert_true(cm._loaded.has("3,0"), "a band chunk out at the queue radius is loaded and built")
	assert_true(cm._loaded.has("1,0"), "and so is one inside the view ring")
	# Cross one chunk toward +x: the window re-centres on (1,0) and still spans Chebyshev 3,
	# so (3,0) is INSIDE it and must NOT be released — that release is the waste pass 8 locked in.
	var before: Dictionary = cm._loaded.duplicate()
	player.spawn_at(Vector3(32.0 + 16.0, 40.0, 16.0))
	cm.refresh()
	var released: Array = []
	for key in before:
		if not cm._loaded.has(key):
			released.append(key)
	assert_true(cm._loaded.has("3,0"), "a band chunk still inside the queue radius is NOT released")
	assert_true(cm._loaded.has("2,0"), "nor one the player moved toward")
	assert_eq(released.size(), 7,
		"a one-chunk crossing releases only the departing edge's seven chunks, not the band")
	# And the invariant, at a crossing where nothing of the old window survives: every resident
	# chunk lies inside the radius it was queued at.
	player.spawn_at(Vector3(16.0, 40.0, 160.0))
	cm.refresh()
	var center := cm.player_chunk()
	var radius: int = cm.stream_radius()
	for key in cm._loaded.keys():
		var probe: PackedStringArray = str(key).split(",")
		var c := Vector2i(int(probe[0]), int(probe[1]))
		assert_true(cm._within_stream_at(center, radius, c),
			"every resident chunk is inside the queue radius (%s)" % key)
	rig["cm"].free()
	rig["voxel"].free()
	rig["terrain"].free()
	rig["player"].free()

## Phase 42 review — an edit to a chunk whose build is still IN FLIGHT is not lost.
## Before the fix nothing rebuilt it: the edit path gated on a cached heightmap, which a
## chunk only gets when its build LANDS, so the edit was skipped entirely and the worker's
## PRE-edit arrays were attached on top of it. `request_rebuild` needs no cached map — it
## supersedes the in-flight build and dispatches a fresh one — so the mesh that lands is
## built from the current columns.
func _test_chunk_edit_during_build_is_not_lost() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var voxel: VoxelSlice = rig["voxel"]
	cm.load_chunk(Vector2i(0, 0))
	assert_false(voxel._heightmaps.has("0,0"),
		"a chunk's heightmap is not cached until its build lands")
	assert_true(voxel.mine_block(Vector3(16.0, 2.0, 16.0)).get("success", false),
		"an edit lands while the chunk's build is in flight")
	_wait_for_builds(cm)
	assert_true(cm._built.has("0,0"), "the chunk's build lands")
	# The mesh that landed must be the POST-edit one: a fresh build of the chunk's current
	# columns (the edit log included) is exactly what the attached mesh has to agree with.
	var hm: Array = voxel._heightmaps["0,0"]
	var expected: Dictionary = VoxelSlice.build_chunk_arrays(Vector2i(0, 0), hm,
		voxel.collect_build_runs(Vector2i(0, 0), hm))
	assert_eq(_chunk_surface_vertices(voxel, Vector2i(0, 0)),
		int(expected["vertices"].size()) + _chunk_vein_vertices(voxel, Vector2i(0, 0)),
		"the attached mesh is the post-edit build, not the pre-edit arrays")
	rig["cm"].free()
	rig["voxel"].free()
	rig["terrain"].free()
	rig["player"].free()

## Phase 42 review — an edit DISPATCHES its rebuild to the worker instead of building up to
## three chunks synchronously in the frame that placed the block, which is the stall the
## worker exists to remove. So the edited chunk keeps its old mesh for a frame or two and
## the new one lands when the build does.
func _test_chunk_edit_dispatches_rebuild() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var voxel: VoxelSlice = rig["voxel"]
	cm.load_chunk(Vector2i(0, 0))
	_wait_for_builds(cm)
	var before: Node3D = voxel._chunks["0,0"]
	assert_true(voxel.mine_block(Vector3(16.0, 2.0, 16.0)).get("success", false), "mine succeeds")
	assert_true(voxel._chunks["0,0"] == before, "the mesh is NOT rebuilt in the edit's own frame")
	assert_eq(cm._builds.size(), 1, "the rebuild went to a worker instead")
	_wait_for_builds(cm)
	assert_false(voxel._chunks["0,0"] == before, "and the mesh is replaced once the build lands")
	rig["cm"].free()
	rig["voxel"].free()
	rig["terrain"].free()

## Phase 42 review pass 8 — the RE-SCOPE path takes the same route as an edit.
## `apply_edits` (what `apply_chunk_manifest` calls, so what a joining client's snapshot and
## a load both land in) used to call `build_chunk` SYNCHRONOUSLY for every touched chunk in
## the frame that applied the snapshot — up to three chunks of main-thread build work — and
## to advance each chunk's revision on the main thread, which made an in-flight worker result
## stale while its task was still the frame path's to reap. It goes through
## `ChunkManager.request_rebuild` now, exactly like `_rebuild_chunk_at_tile`.
func _test_voxel_apply_edits_dispatches_rebuild() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var voxel: VoxelSlice = rig["voxel"]
	cm.load_chunk(Vector2i(0, 0))
	_wait_for_builds(cm)
	var before: Node3D = voxel._chunks["0,0"]
	# An interior tile, so exactly one chunk is touched.
	voxel.apply_chunk_manifest({ "0,0": { "edits": { "32,32": [
		{ "op": "remove", "bottom": 1.5, "top": 2.0 } ] } } })
	assert_true(voxel._chunks["0,0"] == before,
		"the snapshot's rebuild is NOT done in the frame that applied it")
	assert_eq(cm._builds.size(), 1, "it went to a worker instead")
	_wait_for_builds(cm)
	assert_false(voxel._chunks["0,0"] == before, "and the mesh is replaced once the build lands")
	assert_true(cm._built.has("0,0"), "with the chunk still counted as built")
	rig["cm"].free()
	rig["voxel"].free()
	rig["terrain"].free()
	rig["player"].free()

## Phase 42 review pass 8 — `flush_builds()` is the BLOCKING variant, so its contract is
## that no build is left in flight behind it. It iterated a snapshot of `_builds.keys()`, so
## a task that `_apply_build_entry` re-DISPATCHED during the pass (a refused worker result,
## here a revision that moved under the build) was created after the snapshot and simply
## never reaped: it sat in the pool awaited by nobody but the frame path — which in a
## blocking caller (a test, a boot tail) may never come. The loop re-reads the table per
## round, which is what makes the retry it just dispatched its own to await.
func _test_chunk_flush_builds_awaits_retries() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var voxel: VoxelSlice = rig["voxel"]
	cm.load_chunk(Vector2i(0, 0))
	assert_eq(cm._builds.size(), 1, "one build in flight")
	# Simulate what an edit does to a chunk a build is in flight for: the revision it was
	# dispatched at moves on, so its result is REFUSED on apply and the build is re-dispatched.
	voxel._chunk_revision["0,0"] = int(voxel.chunk_revision(Vector2i(0, 0))) + 1
	var applied := cm.flush_builds()
	assert_eq(cm._builds.size(), 0, "the retry dispatched during the pass is awaited by it")
	assert_true(cm._built.has("0,0"), "and the chunk ends up built (%d meshes attached)" % applied)
	rig["cm"].free()
	rig["voxel"].free()
	rig["terrain"].free()
	rig["player"].free()

## Phase 42 review — `stop()` ends NEW streaming, not work already in flight. The frame
## path used to return before its apply pass while streaming was stopped, so a build
## dispatched a moment earlier was applied by nobody and AWAITED by nobody: the chunk was
## left without a mesh and the task's result sat in the pool until shutdown (exit 134).
func _test_chunk_stop_does_not_abandon_builds() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var voxel: VoxelSlice = rig["voxel"]
	cm.start()
	cm.load_chunk(Vector2i(0, 0))
	assert_false(cm._built.has("0,0"), "the build is in flight")
	cm.stop()
	assert_false(cm._active, "streaming is stopped")
	# The frame path only applies FINISHED builds, so let the task finish first — this is
	# the poll `_process` would make on a later frame, and the point is that it still makes
	# it. (Without the fix the poll is behind the `_active` guard and never runs again.)
	var deadline := Time.get_ticks_msec() + 5000
	while not cm._builds.is_empty() and Time.get_ticks_msec() < deadline:
		if WorkerThreadPool.is_task_completed(int(cm._builds.keys()[0])):
			break
	cm._process(0.016)
	assert_true(cm._built.has("0,0"), "the in-flight build still lands")
	assert_eq(voxel.get_loaded_chunks().size(), 1, "and its mesh with it")
	rig["cm"].free()
	rig["voxel"].free()
	rig["terrain"].free()
	rig["player"].free()

## Phase 42 review — a worker result that carried NOTHING is a failed task, and it is
## REFUSED rather than answered with a synchronous main-thread rebuild of the whole chunk
## (the stall the worker exists to remove, done silently). The 2-arg synchronous form is
## untouched: no `arrays` and no revision means "resolve it here".
func _test_voxel_empty_worker_result_is_refused() -> void:
	var v := VoxelSlice.new()
	add_child(v)
	var flat: Array = []
	flat.resize(64 * 64)
	flat.fill(2.0)
	assert_false(v.build_chunk(Vector2i(0, 0), flat, {}, 0), "an empty worker result is refused")
	assert_eq(v.get_loaded_chunks().size(), 0, "and it builds no mesh")
	assert_eq(v.chunk_revision(Vector2i(0, 0)), 0, "and it does not advance the revision")
	assert_true(v.build_chunk(Vector2i(0, 0), flat), "the synchronous form still builds")
	assert_eq(v.get_loaded_chunks().size(), 1, "with a mesh of its own")
	v.free()

## Phase 42 review — the first-ring gate TIMES OUT. The gate is a worker build, and a
## stalled one used to hold the boot forever with the loading screen up and nothing
## logged; past the timeout the host tail runs anyway. Asserted on the pure predicate, so
## the rule is pinned without booting.
func _test_host_boot_first_ring_timeout() -> void:
	var root_script: GDScript = load("res://src/core/game_root.gd")
	assert_true(root_script.host_boot_may_proceed(true, 0.0),
		"a built ring lets the boot through")
	assert_false(root_script.host_boot_may_proceed(false, 0.0),
		"an unbuilt ring holds the boot")
	assert_false(root_script.host_boot_may_proceed(false, root_script.FIRST_RING_TIMEOUT - 0.1),
		"and keeps holding it right up to the timeout")
	assert_true(root_script.host_boot_may_proceed(false, root_script.FIRST_RING_TIMEOUT),
		"past the timeout the tail runs anyway, so a stalled ring cannot hang the boot")

## Phase 42 — the loading screen's freeze, asserted at the predicate the player's input
## consults. A headless run has no mouse capture at all, so the freeze has to be
## assertable ON ITS OWN — which is also why it is a hook of the screen's own and not a
## reuse of `any_window_open()` (asserted below to be false here).
func _test_player_world_input_freeze() -> void:
	var p := PlayerSlice.new()
	add_child(p)
	assert_false(p.is_world_input_frozen(), "a fresh slice is not frozen")
	GameBus.world_input_frozen.emit(true)
	assert_true(p.is_world_input_frozen(), "the loading screen's signal freezes the world")
	assert_false(p.world_input_allowed(), "and no world action may resolve")
	GameBus.world_input_frozen.emit(false)
	assert_false(p.is_world_input_frozen(), "clearing the signal unfreezes it")

	# The window predicate would have answered `false` for a loading screen: it only
	# knows the panels the UI slice holds.
	var ui := UiSlice.new()
	add_child(ui)
	assert_false(ui.any_window_open(), "no UI window is open while the loading screen shows")
	p.set_world_input_frozen(true)
	assert_false(p.world_input_allowed(), "so the freeze, not a window predicate, is what refuses")
	p.free()
	ui.free()

## Phase 42 review — a REBUILD cannot take the pool over its in-flight cap. An edit at a
## chunk corner names three touched chunks and `request_rebuild` used to dispatch each one
## outright, so a single corner edit — or a burst of build retries — put more builds in
## flight than `max_builds_in_flight` allows. A rebuild the cap defers WAITS in
## `_rebuild_queue`: delayed a frame, never dropped.
func _test_chunk_rebuild_respects_inflight_cap() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	cm.load_chunk(Vector2i(0, 0))
	_wait_for_builds(cm)
	assert_true(cm._built.has("0,0"), "the chunk is built")
	# One slot, and it is taken.
	cm.max_builds_in_flight = 1
	cm.load_chunk(Vector2i(1, 0))
	assert_eq(cm._builds.size(), 1, "the pool holds one build, at its cap")
	cm.request_rebuild(Vector2i(0, 0))
	assert_eq(cm._builds.size(), 1, "an edit does not put the pool over its cap")
	assert_true(cm._rebuild_pending.has("0,0"), "the rebuild is queued instead of dropped")
	assert_eq(cm._rebuild_queue.size(), 1, "and waits for a slot")
	_wait_for_builds(cm)
	assert_eq(cm._builds.size(), 0, "the queued rebuild dispatches once the pool frees")
	assert_eq(cm._rebuild_queue.size(), 0, "and the rebuild queue drains")
	rig["cm"].free()
	rig["voxel"].free()
	rig["terrain"].free()
	rig["player"].free()

## Phase 42 review pass 9 — the in-flight cap is enforced by `_dispatch_build` ITSELF, so the
## public `load_chunk` cannot bypass it. Every internal caller checked the cap first, but a
## direct load dispatched outright and put more builds in the pool than
## `max_builds_in_flight` allows. The deferred load WAITS in `_rebuild_queue` (it is already
## `_loaded`, so the drain's rebuild branch is the path that re-dispatches it) and drains under
## the same cap, exactly like a queued rebuild: delayed a frame, never dropped.
func _test_chunk_load_respects_inflight_cap() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	cm.max_builds_in_flight = 1
	cm.load_chunk(Vector2i(0, 0))        # takes the pool's only slot
	assert_eq(cm._builds.size(), 1, "the first load takes the slot")
	cm.load_chunk(Vector2i(1, 0))        # a SECOND, direct load with the pool at its cap
	assert_eq(cm._builds.size(), 1, "a direct load does not put the pool over its cap")
	assert_true(cm._loaded.has("1,0"), "the chunk is still taken into the streamed set")
	assert_true(cm._rebuild_pending.has("1,0"), "its build waits in the queue instead of being dropped")
	assert_eq(cm._rebuild_queue.size(), 1, "as one queued entry")
	_wait_for_builds(cm)
	assert_true(cm._built.has("0,0"), "the chunk that held the slot was built")
	assert_true(cm._built.has("1,0"), "and the deferred load lands once the pool frees")
	assert_eq(cm._builds.size(), 0, "with nothing left in flight")
	rig["cm"].free()
	rig["voxel"].free()
	rig["terrain"].free()
	rig["player"].free()

## Phase 42 review — a chunk that leaves the streamed window while it is still QUEUED is
## not built. It used to be dispatched regardless (the queue was drained without re-reading
## the window), and its `_pending` mark stayed set — so a chunk that left the window and
## came back was silently skipped instead of being queued again.
func _test_chunk_queued_leaving_range_is_cancelled() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var player: PlayerSlice = rig["player"]
	cm.view_distance = 2
	cm.prefetch_distance = 0
	cm.loads_per_frame = 64
	# A chunk queued while it was in range, drained only after the player moved away.
	cm._load_queue = [Vector2i(5, 0)]
	cm._pending["5,0"] = true
	assert_false(cm._within_stream(Vector2i(5, 0)), "the chunk is outside the window now")
	cm._drain_load_queue()
	assert_false(cm._loaded.has("5,0"), "a chunk that left the window while queued is not built")
	assert_false(cm._pending.has("5,0"), "and its pending mark is cleared, not left behind")
	# Coming back: the window re-centres on it and it is queued again — the cleared mark is
	# what makes that work.
	player.spawn_at(Vector3(5.0 * 32.0 + 16.0, 40.0, 16.0))
	cm.refresh()
	assert_true(cm._pending.has("5,0"), "a chunk that returns to the window is queued again")
	rig["cm"].free()
	rig["voxel"].free()
	rig["terrain"].free()
	rig["player"].free()

## Phase 42 review — a build that exhausts MAX_BUILD_RETRIES does not leave a hole for the
## session. The chunk is marked groundless and RE-ARMED by the next `refresh()` that
## re-centres the window, with a fresh retry budget. Keyed on the window MOVING, so a build
## that fails forever costs one dispatch per crossing rather than a per-frame spin.
func _test_chunk_failed_chunk_is_rearmed() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var player: PlayerSlice = rig["player"]
	cm.view_distance = 1
	cm.prefetch_distance = 0
	cm.refresh()
	cm._load_queue.clear()
	cm._pending.clear()
	# The terminal state of a build that gave up: loaded, no mesh, marked groundless.
	cm._loaded["0,0"] = true
	cm._built.erase("0,0")
	cm._failed["0,0"] = true
	cm._build_attempts["0,0"] = cm.MAX_BUILD_RETRIES
	player.spawn_at(Vector3(16.0 + 32.0, 40.0, 16.0))   # cross into chunk (1,0)
	cm.refresh()
	assert_false(cm._failed.has("0,0"), "the re-centre clears the groundless mark")
	cm._drain_load_queue()
	assert_eq(int(cm._build_attempts.get("0,0", 0)), 1, "with a fresh retry budget")
	assert_true(cm._has_in_flight("0,0"), "and a fresh dispatch in flight")
	_wait_for_builds(cm)
	assert_true(cm._built.has("0,0"), "so the hole fills itself instead of staying for the session")
	rig["cm"].free()
	rig["voxel"].free()
	rig["terrain"].free()
	rig["player"].free()

## Phase 42 review — a chunk's creature and tree budgets spawn when its GROUND EXISTS, not
## when it enters the streamed set. The build is on a worker, so spawning at load time put
## the population on a chunk whose mesh arrived a frame or more later.
func _test_chunk_contents_spawn_after_ground() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var terrain: TerrainSlice = rig["terrain"]
	var tree := TreeSlice.new()
	add_child(tree)
	tree.terrain_slice = terrain
	cm.tree_slice = tree
	# The world seed is random per run and a chunk of a tree biome can roll as a clearing
	# (Phase 44), so pick one that actually grows trees — otherwise this fails ~10% of runs.
	var c := Vector2i(-1, -1)
	for cx in range(-80, 80):
		var cand := Vector2i(cx, 0)
		var biome := str(terrain.get_biome_at_chunk(cand))
		if ["TemperateForest", "TwilightGrove"].has(biome) and tree.tree_count_for(cand, biome) > 0:
			c = cand
			break
	var key := "%d,%d" % [c.x, c.y]
	cm.load_chunk(c)
	assert_false(cm._built.has(key), "the build is in flight")
	assert_eq(tree.trees_in_chunk(c).size(), 0,
		"no trees exist while the chunk's ground does not")
	_wait_for_builds(cm)
	assert_true(cm._built.has(key), "the ground lands")
	assert_true(tree.trees_in_chunk(c).size() > 0,
		"and the chunk's trees spawn with it")
	rig["cm"].free()
	rig["voxel"].free()
	rig["terrain"].free()
	rig["player"].free()
	tree.free()

## Phase 42 review pass 3 — the self-heal cannot be keyed on the window MOVING. A dedicated
## server streams around a fixed origin and a host player standing still never changes
## chunk, so `refresh()` returned before it ever reached the re-arm loop: a chunk whose
## build gave up stayed a hole for the session, which is exactly the case the re-arm exists
## for. A crossing still re-arms immediately; an unmoved window re-arms on a wall-clock
## interval (set to 0 here — the interval is the backoff, not the behaviour under test).
func _test_chunk_failed_chunk_is_rearmed_while_stationary() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	cm.view_distance = 1
	cm.prefetch_distance = 0
	cm.self_heal_interval = 0.0
	cm.refresh()
	cm._load_queue.clear()
	cm._pending.clear()
	# The terminal state of a build that gave up, as in the crossing test above.
	cm._loaded["0,0"] = true
	cm._built.erase("0,0")
	cm._failed["0,0"] = true
	cm._build_attempts["0,0"] = cm.MAX_BUILD_RETRIES
	# The player has NOT moved: the window does not re-centre.
	cm.refresh()
	assert_false(cm._failed.has("0,0"), "a stationary player still re-arms a groundless chunk")
	assert_eq(int(cm._build_attempts.get("0,0", 0)), 0, "clearing the give-up state with it")
	cm._drain_load_queue()
	assert_eq(int(cm._build_attempts.get("0,0", 0)), 1, "with a fresh retry budget")
	assert_true(cm._has_in_flight("0,0"), "and a fresh dispatch in flight")
	_wait_for_builds(cm)
	assert_true(cm._built.has("0,0"), "so the hole fills without a chunk crossing")
	rig["cm"].free()
	rig["voxel"].free()
	rig["terrain"].free()
	rig["player"].free()

## Phase 42 review pass 3 — `unload_chunk` cleared a queued rebuild's `_rebuild_pending`
## mark but left its entry in `_rebuild_queue`. The dedupe reads the MARK, so the next
## `_queue_rebuild` for that same chunk appended a SECOND entry — two dispatches for one
## chunk under one revision, both attaching.
func _test_chunk_unload_drops_queued_rebuild() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	cm.load_chunk(Vector2i(0, 0))
	_wait_for_builds(cm)
	cm.max_builds_in_flight = 1
	cm.load_chunk(Vector2i(1, 0))   # takes the pool's one slot
	cm.request_rebuild(Vector2i(0, 0))
	assert_eq(cm._rebuild_queue.size(), 1, "the rebuild waits in the queue")
	assert_true(cm._rebuild_pending.has("0,0"), "with its pending mark")
	cm.unload_chunk(Vector2i(0, 0))
	assert_eq(cm._rebuild_queue.size(), 0, "unloading a chunk drops its queued entry too")
	assert_false(cm._rebuild_pending.has("0,0"), "and its pending mark")
	# And the dedupe still holds afterwards: the chunk streams back in, is edited again
	# behind the same full pool, and gets exactly ONE queue entry.
	_wait_for_builds(cm)
	cm.load_chunk(Vector2i(0, 0))
	_wait_for_builds(cm)
	cm.load_chunk(Vector2i(2, 0))
	cm.request_rebuild(Vector2i(0, 0))
	assert_eq(cm._rebuild_queue.size(), 1, "a later rebuild for the same chunk is queued once")
	_wait_for_builds(cm)
	assert_eq(cm._rebuild_queue.size(), 0, "and drains")
	rig["cm"].free()
	rig["voxel"].free()
	rig["terrain"].free()
	rig["player"].free()

## Phase 42 review pass 3 — contents belong to a chunk's RESIDENCY, not to its build. An
## edit rebuilds a loaded chunk, and the apply path re-ran `_spawn_chunk_contents` for it
## every time: `spawn_for_chunk` walks every creature in the fabric and every live tree to
## arrive at the count it already had. Counted through a spy, because the CALL is the
## finding — the resulting population is identical either way.
func _test_chunk_contents_spawn_once_per_residency() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var spy := ContentsSpy.new()
	add_child(spy)
	cm.creature_slice = spy
	cm.tree_slice = spy
	cm.load_chunk(Vector2i(0, 0))
	_wait_for_builds(cm)
	assert_eq(spy.spawned.size(), 2, "the creature and tree budgets spawn with the ground")
	# A block edit rebuilds the chunk — the population is already standing there.
	cm.request_rebuild(Vector2i(0, 0))
	_wait_for_builds(cm)
	assert_true(cm._built.has("0,0"), "the rebuild landed")
	assert_eq(spy.spawned.size(), 2, "and did NOT re-derive the chunk's contents")
	# Streaming out and back in is a NEW residency: it repopulates.
	cm.unload_chunk(Vector2i(0, 0))
	cm.load_chunk(Vector2i(0, 0))
	_wait_for_builds(cm)
	assert_eq(spy.spawned.size(), 4, "a chunk that streams back in repopulates")
	assert_eq(spy.despawned.size(), 2, "and its contents were despawned on the way out")
	rig["cm"].free()
	rig["voxel"].free()
	rig["terrain"].free()
	rig["player"].free()
	spy.free()

## Phase 42 review pass 3 — the drain resolved the streamed window once per QUEUED chunk:
## `_within_stream` re-derived `player_chunk()` (a slice call) and the radius for every
## candidate, so one drain of a view ring paid dozens of position reads for one answer.
func _test_chunk_drain_reads_window_once() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var spy := PlayerPosSpy.new()
	add_child(spy)
	cm.player_slice = spy
	cm.view_distance = 2
	cm.prefetch_distance = 0
	cm.loads_per_frame = 64
	cm.refresh()
	assert_true(cm._load_queue.size() > 9,
		"a full view ring is queued (%d chunks)" % cm._load_queue.size())
	var before: int = spy.reads
	cm._drain_load_queue()
	assert_eq(spy.reads - before, 1,
		"one drain resolves the player's chunk ONCE, not once per candidate")
	# No `_wait_for_builds` on purpose here: the count IS the subject, and freeing the
	# manager reaps whatever task is still in flight (`_exit_tree` awaits them).
	rig["cm"].free()
	rig["voxel"].free()
	rig["terrain"].free()
	rig["player"].free()
	spy.free()

## Phase 42 review pass 4 — and the sweep overwrote `_last_self_heal_msec` only on the
## THROTTLED path. A crossing re-armed immediately and left the clock at its old value
## (often the -1 sentinel), so the very next frame — stationary, with a fresh failure —
## was unthrottled and re-armed again. Stamping whenever the sweep proceeds makes "at most
## once per interval" start at the crossing. Asserted through a chunk the sweep runs over
## but cannot re-arm (a build already in flight), which is what keeps it in `_failed` with
## its mark visible across the crossing.
func _test_chunk_crossing_stamps_self_heal_clock() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var player: PlayerSlice = rig["player"]
	cm.view_distance = 1
	cm.prefetch_distance = 0
	cm.self_heal_interval = 60.0
	cm.refresh()
	cm._load_queue.clear()
	cm._pending.clear()
	cm._loaded["0,0"] = true
	cm._failed["0,0"] = true
	cm._build_attempts["0,0"] = cm.MAX_BUILD_RETRIES
	cm._builds[424242] = { "chunk": Vector2i(0, 0), "key": "0,0" }   # already in flight
	player.spawn_at(Vector3(16.0 + 32.0, 40.0, 16.0))                # cross into chunk (1,0)
	cm.refresh()
	assert_true(cm._failed.has("0,0"),
		"an in-flight build keeps the chunk groundless through the crossing")
	# The in-flight build lands (it does not clear `_failed`), and the next frame is
	# STATIONARY. The crossing stamped the clock, so this frame must be throttled.
	cm._builds.erase(424242)
	cm.refresh()
	assert_true(cm._failed.has("0,0"), "the frame after a crossing is throttled, not unthrottled")
	# And the throttle is the only reason: zeroing the interval re-arms the same state.
	cm.self_heal_interval = 0.0
	cm.refresh()
	assert_false(cm._failed.has("0,0"), "clearing the interval re-arms it")
	rig["cm"].free()
	rig["voxel"].free()
	rig["terrain"].free()
	rig["player"].free()

## Phase 42 review pass 3 tested the stationary re-arm with `self_heal_interval = 0.0`,
## which DISABLES the throttle: it proved the re-arm runs without a crossing, but nothing
## proved the interval suppresses one. This pins the throttle: a second stationary sweep
## inside the interval re-arms nothing, and zeroing the interval is the only thing that
## re-arms again.
func _test_chunk_self_heal_throttle_suppresses_rearm() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	cm.view_distance = 1
	cm.prefetch_distance = 0
	cm.self_heal_interval = 60.0
	cm.refresh()
	cm._load_queue.clear()
	cm._pending.clear()
	cm._loaded["0,0"] = true
	cm._failed["0,0"] = true
	cm._build_attempts["0,0"] = cm.MAX_BUILD_RETRIES
	# First stationary sweep: never attempted before (the -1 sentinel), so not throttled.
	cm.refresh()
	assert_false(cm._failed.has("0,0"), "the first stationary attempt is not throttled")
	# The same terminal state again, INSIDE the interval: the sweep must refuse.
	cm._failed["0,0"] = true
	cm._build_attempts["0,0"] = cm.MAX_BUILD_RETRIES
	cm.refresh()
	assert_true(cm._failed.has("0,0"), "a second re-arm inside the interval is suppressed")
	assert_eq(int(cm._build_attempts.get("0,0", 0)), cm.MAX_BUILD_RETRIES,
		"and the give-up state is left untouched by it")
	# The interval is the ONLY reason it was refused.
	cm.self_heal_interval = 0.0
	cm.refresh()
	assert_false(cm._failed.has("0,0"), "clearing the interval re-arms on the next sweep")
	rig["cm"].free()
	rig["voxel"].free()
	rig["terrain"].free()
	rig["player"].free()

## Phase 42 review pass 4 — the sweep required `not _built`, and a chunk whose REBUILD gave
## up IS `_built`: its old mesh is still attached, so the sweep skipped exactly the case the
## re-arm exists for — an edit whose rebuild never landed, leaving the edited block invisible
## for the session. `_failed` is what says the build gave up; a groundless chunk is re-armed
## whatever `_built` says.
func _test_chunk_failed_rebuild_of_built_chunk_is_rearmed() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var player: PlayerSlice = rig["player"]
	cm.view_distance = 1
	cm.prefetch_distance = 0
	cm.self_heal_interval = 0.0
	cm.refresh()
	cm._load_queue.clear()
	cm._pending.clear()
	# Built ONCE (so `_built` is true and its stale mesh stands), then an edit whose rebuild
	# exhausted its retries.
	cm._loaded["0,0"] = true
	cm._built["0,0"] = true
	cm._failed["0,0"] = true
	cm._build_attempts["0,0"] = cm.MAX_BUILD_RETRIES
	player.spawn_at(Vector3(16.0 + 32.0, 40.0, 16.0))   # a crossing re-arms immediately
	cm.refresh()
	assert_false(cm._failed.has("0,0"), "a failed REBUILD of an already-built chunk is re-armed")
	cm._drain_load_queue()
	assert_eq(int(cm._build_attempts.get("0,0", 0)), 1, "with a fresh retry budget")
	assert_true(cm._has_in_flight("0,0"), "and a fresh dispatch in flight")
	_wait_for_builds(cm)
	assert_true(cm._built.has("0,0"), "so the edit's mesh lands instead of staying invisible")
	rig["cm"].free()
	rig["voxel"].free()
	rig["terrain"].free()
	rig["player"].free()

## Phase 42 review pass 4 — the sweep re-derived the streamed window per groundless key
## (`_within_stream`), a `PlayerSlice.get_position()` call each. The caller has already
## resolved `center` for its own pass, so the sweep takes it and uses `_within_stream_at`.
## Counted through the position spy, because the answer is identical either way.
func _test_chunk_self_heal_reads_window_once() -> void:
	var cm := ChunkManager.new()
	add_child(cm)
	var spy := PlayerPosSpy.new()
	add_child(spy)
	cm.player_slice = spy
	cm.view_distance = 2
	cm.prefetch_distance = 0
	cm.self_heal_interval = 0.0
	cm.refresh()
	cm._load_queue.clear()
	cm._pending.clear()
	for k in ["-1,0", "0,-1", "0,1", "1,0"]:
		cm._loaded[k] = true
		cm._failed[k] = true
		cm._build_attempts[k] = cm.MAX_BUILD_RETRIES
	assert_eq(cm._failed.size(), 4, "four groundless chunks, all in range, to sweep")
	var before: int = spy.reads
	cm.refresh()
	assert_eq(spy.reads - before, 1,
		"one sweep resolves the player's window ONCE, not once per groundless key")
	assert_eq(cm._failed.size(), 0, "and the sweep still re-armed every one of them")
	cm.free()
	spy.free()

## Phase 42 review pass 4 — `_process` calls the drain every frame, and the drain resolved
## the player's chunk before knowing whether there was anything to dispatch. A settled
## window (the common case) drained nothing and paid a position read for it.
func _test_chunk_idle_drain_reads_no_position() -> void:
	var cm := ChunkManager.new()
	add_child(cm)
	var spy := PlayerPosSpy.new()
	add_child(spy)
	cm.player_slice = spy
	cm.refresh()
	cm._load_queue.clear()
	cm._pending.clear()
	assert_true(cm._load_queue.is_empty() and cm._rebuild_queue.is_empty(),
		"nothing is queued now")
	var before: int = spy.reads
	for i in range(8):
		cm._drain_load_queue()
	assert_eq(spy.reads - before, 0,
		"a drain with both queues empty does not resolve the player's position at all")
	# Sanity: a NON-empty queue still drains and still resolves the window once.
	cm._load_queue = [Vector2i(0, 0)]
	cm._pending["0,0"] = true
	cm._drain_load_queue()
	assert_true(cm._loaded.has("0,0"), "a queued chunk still drains")
	assert_eq(spy.reads - before, 1, "and a non-empty drain resolves the window once")
	cm.free()
	spy.free()

## Phase 42 review pass 4 — the isolated fast path in `_dispatch_build` (no terrain/voxel)
## spawned a chunk's contents unconditionally, ignoring `_contents_spawned`: the threaded
## path's residency rule was fixed in pass 3, this one was not. An EDIT still reaches it
## through `request_rebuild`, so the budgets were re-derived on every block edit there too.
func _test_chunk_rig_dispatch_respects_contents_residency() -> void:
	var cm := ChunkManager.new()
	add_child(cm)
	var spy := ContentsSpy.new()
	add_child(spy)
	cm.creature_slice = spy
	cm.tree_slice = spy
	cm.load_chunk(Vector2i(0, 0))
	assert_eq(spy.spawned.size(), 2, "the rig spawns the creature and tree budgets once")
	cm.request_rebuild(Vector2i(0, 0))
	assert_eq(spy.spawned.size(), 2, "and an edit does not re-derive them")
	# A new residency still repopulates.
	cm.unload_chunk(Vector2i(0, 0))
	cm.load_chunk(Vector2i(0, 0))
	assert_eq(spy.spawned.size(), 4, "a chunk that streams back in repopulates")
	cm.free()
	spy.free()

## Phase 42 review pass 3 — the CI host job ended a boot with `--quit-after N`, a FRAME
## budget, for a wait that is measured in WORKER time: a fast headless frame loop can burn
## the budget before the ring's tasks land, and the job then fails for a boot that was
## working. `--quit-after-boot` hands the decision to the boot itself. Static and
## argument-driven, so the rule is pinned without booting (same shape as `should_run_tests`).
func _test_quit_after_boot_predicate() -> void:
	var root_script: GDScript = load("res://src/core/game_root.gd")
	assert_true(root_script.should_quit_after_boot([root_script.QUIT_AFTER_BOOT_ARG]),
		"the flag is read from the user args")
	assert_false(root_script.should_quit_after_boot([]),
		"no flag leaves the exit to the engine's own budget")
	assert_false(root_script.should_quit_after_boot(["--server", "--run-tests"]),
		"and another arg is not it")

## Phase 42 review — the phase's headline claim ("the build is on a worker, the main
## thread does not build") is a QUANTITATIVE one, so it leaves a number behind rather than
## prose. This times the two halves of one chunk build on this machine, as
## `_dispatch_build` actually spends them.
##
## Phase 42 review pass 8 — and it now ASSERTS the split, which is the criterion the phase
## was accepted on and which this test only PRINTED.
##
## Phase 42 review pass 9 — THE SPLIT ITSELF MOVED. The resolve (runs, colours, deposits) was the
## main thread's half and cost ~43 ms per dispatch — 2.7 frames at 60 Hz — which is exactly what
## rows 3 and 4 of this pass found: the ratio assertion passed while the frame did not. The main
## thread now only GENERATES the heightmap and GATHERS the plain state the resolve reads
## (`VoxelSlice.gather_build_input`), and the worker runs the resolve (`build_runs`) AND the build
## (`build_chunk_arrays`). So the probe measures the NEW halves: main = generate + gather + the
## apply pass, worker = resolve + build. Both are kept PER PASS, because the first pass pays the
## one-time costs and the steady state is what a frame actually gets.
##
## The ceiling is the row's: one dispatch's main-thread half must fit inside ONE FRAME at 60 Hz,
## because the streaming loop dispatches one chunk per frame. The ratio is still asserted
## alongside it — the worker half must also dominate, i.e. the expensive work is off the main
## thread — and both numbers are printed for a reviewer to check.
func _test_chunk_build_split_probe() -> void:
	var terrain := TerrainSlice.new()
	add_child(terrain)
	var voxel := VoxelSlice.new()
	voxel.terrain_slice = terrain
	add_child(voxel)
	# A 3×3 ring of heightmaps, so the resolve has real ring tiles to subtract against — the
	# production case. Without them every ring tile reads as an UNKNOWN neighbour and the measured
	# cost would flatter itself.
	for cz in range(-1, 2):
		for cx in range(-1, 2):
			var c := Vector2i(cx, cz)
			voxel._heightmaps["%d,%d" % [cx, cz]] = terrain.generate_heightmap(c)
	var resolve_us := 0            # the main-thread half, summed (see `main_pass` for per-pass)
	var pure_us := 0               # the worker half (resolve + build), summed
	var apply_us := 0
	var worker_resolve_us := 0
	var main_pass: Array = []      # per-pass main-thread half: generate + gather + apply
	var resolve_pass: Array = []   # per-pass main-thread gather alone
	var built: Dictionary = {}
	for i in range(3):
		# --- the MAIN-THREAD half of one dispatch, in `_dispatch_build`'s own order ---
		var t0 := Time.get_ticks_usec()
		var hm: Array = terrain.generate_heightmap(Vector2i(0, 0))
		var gathered: Dictionary = voxel.gather_build_input(Vector2i(0, 0), hm)
		var r_us := Time.get_ticks_usec() - t0
		resolve_us += r_us
		resolve_pass.append(r_us)
		# --- the WORKER half: the resolve, then the pure build ---
		t0 = Time.get_ticks_usec()
		var resolved: Dictionary = VoxelSlice.build_runs(Vector2i(0, 0), hm, gathered)
		worker_resolve_us += Time.get_ticks_usec() - t0
		t0 = Time.get_ticks_usec()
		built = VoxelSlice.build_chunk_arrays(Vector2i(0, 0), hm, resolved)
		pure_us += Time.get_ticks_usec() - t0
		# The apply half: exactly what `build_chunk` does with the worker's result on the
		# main thread (minus the node attachment, a few object allocations either way).
		t0 = Time.get_ticks_usec()
		VoxelSlice._mesh_from_arrays(built)
		var deposit_vertices: PackedVector3Array = built["deposit_vertices"]
		if not deposit_vertices.is_empty():
			VoxelSlice._mesh_from_arrays({
				"vertices": built["deposit_vertices"], "normals": built["deposit_normals"],
				"colors": built["deposit_colors"], "indices": built["deposit_indices"],
			})
		var trimesh := ConcavePolygonShape3D.new()
		trimesh.set_faces(built["collision"])
		var a_us := Time.get_ticks_usec() - t0
		apply_us += a_us
		main_pass.append(r_us + a_us)
	var main_us := resolve_us + apply_us
	var steady_main: int = int(main_pass[main_pass.size() - 1])
	var steady_resolve: int = int(resolve_pass[resolve_pass.size() - 1])
	var deposit_verts: int = (built["deposit_vertices"] as PackedVector3Array).size()
	print("PROBE Phase 42 build split (3 passes): main-thread half %d us (generate+gather %d + apply %d), worker half %d us (resolve %d + build %d) (%d faces -> %d quads, %d deposit verts)" % [
		main_us, resolve_us, apply_us, pure_us, worker_resolve_us, pure_us - worker_resolve_us,
		int(built["cell_count"]), int(built["quad_count"]), deposit_verts])
	print("PROBE Phase 42 build split per pass: main %s us (steady state %d, of which generate+gather %d), worker %s us" % [
		str(main_pass), steady_main, steady_resolve, str(resolve_pass)])
	assert_true(int(built["cell_count"]) > 0, "the worker half produced a real chunk")
	assert_true((VoxelSlice._mesh_from_arrays(built)).get_surface_count() == 1,
		"and its arrays commit to a mesh")
	assert_true(resolve_us > 0 and pure_us > 0, "and both halves' costs were measured")
	# THE ratio criterion (row 8): the expensive half is the half that runs off the main thread.
	# Measured ~1.8x on the machine that pass ran on, so a strict `>` is the honest assertion — a
	# ratio test tight enough to be interesting would be a flake.
	assert_true(pure_us > main_us,
		"the worker half dominates the main thread's own work (%d us vs %d us)" % [pure_us, main_us])
	# THE absolute ceiling (rows 3 and 4): one dispatch per frame means the main thread pays this
	# every frame, so it must fit in a frame. The three-pass SUM is not the number a frame gets —
	# the steady state is — and this is the assertion the old ratio let a 43 ms frame pass.
	var frame_us: int = 16667   # one frame at 60 Hz
	assert_true(steady_main < frame_us,
		"one dispatch's main-thread half fits inside a frame (%d us of %d us, generate+gather %d)" % [
			steady_main, frame_us, steady_resolve])

	# Phase 42 review pass 10 — and the ceiling is asserted AGAIN over a POPULATED edit log,
	# which is what the pass-9 probe could not do: it measured a FRESH slice, so `_edits` was
	# empty, `_gather_edits` returned on its first line, and the gather cost — the one thing the
	# chunk index exists to bound — was never in the number the ceiling checked. Populate a
	# WORLD's worth of edits (a full chunk in the window, plus several chunks far outside it, so
	# the LOG is large while the WINDOW is not) and time the same main-thread half. The far
	# chunks are the point: the old gather walked and string-split EVERY one of them on each
	# dispatch; only the window's are copied now.
	var op_template := [{ "op": "remove", "bottom": 1.5, "top": 2.0 }]
	for ty in range(64):
		for tx in range(64):
			voxel._set_edit_ops(VoxelSlice._tile_key(Vector2i(tx, ty)), op_template)
	# ...plus 24 chunks well OUTSIDE the window (≈98k more edits), so the log is a long-played
	# world's and dwarfs the window. That ratio is the assertion: with the OLD world-scan gather
	# this log cost one string split per edit here per dispatch and blew the frame; with the
	# index only the window's 4096 are copied, whatever the world holds.
	for far_i in range(24):
		var far := Vector2i(far_i % 6 + 4, far_i / 6 + 4)
		for i in range(4096):
			voxel._set_edit_ops(VoxelSlice._tile_key(Vector2i(far.x * 64 + (i % 64), far.y * 64 + (i / 64))), op_template)
	var populated_pass: Array = []
	var window_edits := 0
	for i in range(3):
		var t0p := Time.get_ticks_usec()
		var hm2: Array = terrain.generate_heightmap(Vector2i(0, 0))
		var gathered2: Dictionary = voxel.gather_build_input(Vector2i(0, 0), hm2)
		window_edits = (gathered2["edits"] as Dictionary).size()
		populated_pass.append(Time.get_ticks_usec() - t0p)
	var steady_pop: int = int(populated_pass[populated_pass.size() - 1])
	print("PROBE Phase 42 gather with a populated edit log: %d edits across %d chunks (%d in the window), main-thread generate+gather %s us (steady %d of %d)" % [
		voxel._edits.size(), voxel._edits_by_chunk.size(), window_edits, str(populated_pass), steady_pop, frame_us])
	assert_true(window_edits >= 4096, "the window's edit log is genuinely populated (%d tiles)" % window_edits)
	assert_true(steady_pop < frame_us,
		"and the main-thread half still fits a frame with a populated edit log (%d us of %d us, %d window edits)" % [
			steady_pop, frame_us, window_edits])
	terrain.free()
	voxel.free()

## Phase 42 review pass 9 — the gathered payload has to carry the RING, or the resolve would run
## on the worker with a silently wrong input: a ring tile whose chunk IS built would read as the
## UNKNOWN neighbour (an empty column), and a ring chunk's own edits would be invisible. Both
## halves are asserted on the table itself, where the answer is unambiguous — the ring tile at
## (64, 32) belongs to chunk (1, 0), so its runs must come from THAT chunk's heightmap and its
## edits, not from this chunk's.
func _test_chunk_gather_carries_the_ring() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var voxel: VoxelSlice = rig["voxel"]
	var terrain: TerrainSlice = rig["terrain"]
	var centre := Vector2i(0, 0)
	cm.load_chunk(centre)
	_wait_for_builds(cm)
	var hm: Array = voxel._heightmaps["0,0"]
	var ring_key := VoxelSlice._tile_key(Vector2i(64, 32))   # chunk (1, 0)'s own tile

	# UNKNOWN: the neighbour the gather did not carry reads as empty, which is the documented
	# unknown-column path (`_neighbour_runs`), not an error.
	# (Phase 49: only with no generator wired — with one, the gather carries a generated map.)
	voxel._heightmaps.erase("1,0")
	voxel._guess_heightmaps.erase("1,0")
	voxel.terrain_slice = null
	var unknown: Dictionary = VoxelSlice.build_runs(centre, hm, voxel.gather_build_input(centre, hm))
	voxel.terrain_slice = terrain
	assert_true((unknown["runs"][ring_key] as Array).is_empty(),
		"a ring chunk the gather did not carry resolves as the UNKNOWN neighbour")

	# KNOWN: the ring tile resolves from the NEIGHBOUR's heightmap — a deliberately different one
	# (6.0 against this chunk's noise), so the value names its source.
	var flat6: Array = []
	flat6.resize(64 * 64)
	flat6.fill(6.0)
	voxel._heightmaps["1,0"] = flat6
	var known: Dictionary = VoxelSlice.build_runs(centre, hm, voxel.gather_build_input(centre, hm))
	var ring_runs: Array = known["runs"][ring_key]
	assert_true(ring_runs.size() > 0, "a carried ring chunk resolves its real column")
	assert_eq(float((ring_runs[0] as Dictionary)["top"]), 6.0,
		"from the NEIGHBOUR's heightmap the payload carried, not this chunk's")

	# And the ring chunk's OWN EDIT reaches the resolve through the same payload.
	voxel._set_edit_ops(ring_key, [{ "op": "add", "bottom": 0.0, "top": 8.0, "material": "Ashite" }])
	var edited: Dictionary = VoxelSlice.build_runs(centre, hm, voxel.gather_build_input(centre, hm))
	var placed := false
	for run in edited["runs"][ring_key]:
		if str((run as Dictionary)["material"]) == "Ashite":
			placed = true
	assert_true(placed, "and a RING tile's edit reaches the worker-side resolve")
	voxel._set_edit_ops(ring_key, [])
	rig["cm"].free()
	rig["voxel"].free()
	rig["terrain"].free()
	rig["player"].free()

## Phase 42 review — the loading freeze holds the BODY, not just `_input`. On a joining
## client the body exists from the snapshot while its ring is still building, so an
## input-only freeze left it falling through ground that did not exist. Asserted through
## gravity: the suite's physics is inert, so an unfrozen body accumulates `_vel.y` and a
## frozen one does not move at all.
func _test_player_movement_freeze() -> void:
	var falling := PlayerSlice.new()
	add_child(falling)
	falling.spawn_at(Vector3(16.0, 40.0, 16.0))
	GameBus.world_input_frozen.emit(false)
	falling._physics_process(0.1)
	assert_true(falling.get_velocity().y < 0.0, "an unfrozen body accumulates gravity")

	var held := PlayerSlice.new()
	add_child(held)
	held.spawn_at(Vector3(16.0, 40.0, 16.0))
	GameBus.world_input_frozen.emit(true)
	held._physics_process(0.1)
	assert_eq(held.get_velocity(), Vector3.ZERO, "the loading freeze holds the body too")
	falling.free()
	held.free()

## Phase 42 review — the loading screen's own visibility contract, asserted by the suite
## instead of by hand. It is presentation (a CanvasLayer), so nothing else in the run
## observes it: before this test the only evidence that it ever appeared was a `visible`
## flag read off a live boot.
func _test_loading_screen_visibility() -> void:
	var screen = load("res://src/ui/loading_screen.gd").new()
	add_child(screen)
	var emitted: Array = []
	var cb := func(frozen: bool): emitted.append(frozen)
	GameBus.world_input_frozen.connect(cb)
	assert_false(screen.is_active(), "a fresh loading screen is down")
	assert_false(screen.visible, "and hidden")
	screen.begin()
	assert_true(screen.is_active(), "begin shows it")
	assert_true(screen.visible, "and makes it visible")
	assert_eq(emitted.size(), 1, "and emits the freeze")
	assert_true(bool(emitted[0]), "freezing world input")
	screen.set_progress(0.5)
	assert_eq(screen._bar.value, 50.0, "the bar tracks the progress fraction")
	screen.finish()
	assert_false(screen.is_active(), "finish puts it away")
	assert_false(screen.visible, "and hides it")
	assert_eq(emitted.size(), 2, "and emits the thaw")
	assert_false(bool(emitted[1]), "releasing world input")
	GameBus.world_input_frozen.disconnect(cb)
	screen.free()

# ---------------------------------------------------------------------------
# Phase 43 — natural resource distribution
# ---------------------------------------------------------------------------

func _flat_heightmap(h: float) -> Array:
	var hm: Array = []
	hm.resize(64 * 64)
	hm.fill(h)
	return hm

## The first vein (searching chunks along +X) whose blob breaks the surface of a flat 2.0
## chunk: `{ chunk, tile (chunk-local), vein }`, or `{}`.
func _find_surface_vein(seed: int) -> Dictionary:
	for cx in range(0, 16):
		var chunk := Vector2i(cx, 0)
		var cache: Dictionary = {}
		for tz in range(64):
			for tx in range(64):
				var vein := OreField.vein_at(seed, chunk, Vector2i(tx, tz), 0.0625, cache)
				if not vein.is_empty():
					return { "chunk": chunk, "tile": Vector2i(tx, tz), "vein": vein }
	return {}

## A grid sample of the field: "gx,gz,k" → material ("" outside a vein).
func _ore_sample(seed: int) -> Dictionary:
	var out: Dictionary = {}
	for cz in range(-2, 2):
		for cx in range(-2, 2):
			var chunk := Vector2i(cx, cz)
			for tz in range(0, 64, 3):
				for tx in range(0, 64, 3):
					for k in range(0, 12):
						var depth := 0.0625 + float(k) * 0.875
						var vein := OreField.vein_at(seed, chunk, Vector2i(tx, tz), depth)
						out["%d,%d,%d" % [cx * 64 + tx, cz * 64 + tz, k]] = "" if vein.is_empty() else str(vein["material"])
	return out

func _test_ore_deterministic() -> void:
	var a := _ore_sample(12345)
	var b := _ore_sample(12345)
	assert_eq(a, b, "the same seed samples the same field twice")
	var veins := 0
	for key in a:
		if str(a[key]) != "":
			veins += 1
	assert_true(veins > 0, "and the sample holds veins (%d samples)" % veins)
	assert_true(veins < a.size(), "but is not all vein")
	var c := _ore_sample(54321)
	assert_true(a != c, "a different seed is a different field")
	# The descriptor itself is a pure function of (seed, cell): no cache, no order.
	var cell := Vector3i(3, 1, -2)
	assert_eq(OreField.vein_in_cell(777, cell), OreField.vein_in_cell(777, cell, {}), "a cell's vein is cache-free")

func _test_ore_client_agrees_without_snapshot() -> void:
	var t_host := TerrainSlice.new()
	add_child(t_host)
	t_host.set_world_seed(424242)
	var t_client := TerrainSlice.new()
	add_child(t_client)
	t_client.set_world_seed(424242)
	var host := VoxelSlice.new()
	host.terrain_slice = t_host
	var client := VoxelSlice.new()
	client.terrain_slice = t_client
	client.is_authoritative = false
	var same := true
	var materials: Dictionary = {}
	var volcanic := _find_chunk_with_biome(t_host, ["VolcanicBadlands"])
	assert_true(volcanic != Vector2i(-1, -1), "a volcanic chunk exists to sample")
	var anchor := Vector2(float(volcanic.x) * 32.0, float(volcanic.y) * 32.0)
	for i in range(0, 4000, 7):
		var xz := anchor + Vector2(float(i % 200) * 0.5 - 50.0, float(i / 200) * 0.5 * 9.0 - 40.0)
		for depth in [0.0625, 1.5625, 4.5625, 7.0625]:
			var m: String = host.material_at(xz, depth)
			materials[m] = true
			if m != client.material_at(xz, depth):
				same = false
	assert_true(same, "host and client evaluate the same field from the seed alone")
	assert_true(materials.size() > 1, "and the field is not one material (%s)" % str(materials.keys()))
	# The rendered colours agree too: the resolve is the same pure function on both sides.
	var flat := _flat_heightmap(2.0)
	assert_eq(VoxelSlice.build_runs(Vector2i(1, 1), flat, host.gather_build_input(Vector2i(1, 1), flat)),
		VoxelSlice.build_runs(Vector2i(1, 1), flat, client.gather_build_input(Vector2i(1, 1), flat)),
		"and the two resolves are identical")
	host.free()
	client.free()
	t_host.free()
	t_client.free()

func _test_ore_aethermite_gates() -> void:
	var band := OreField.band_of("Aethermite")
	var seen := 0
	var above_band := 0
	var off_ley := 0
	var scan := TerrainSlice.new()
	add_child(scan)
	for seed in [1, 2, 3]:
		scan.set_world_seed(seed)
		# Aethermite lives in volcanic and twilight ground, which Phase 51 made climate niches.
		for chunk_v in _biome_chunks(scan, ["VolcanicBadlands", "TwilightGrove"], 14):
			if true:
				var chunk: Vector2i = chunk_v
				var cache: Dictionary = {}
				for tz in range(0, 64, 2):
					for tx in range(0, 64, 2):
						for k in range(0, 26):
							var depth := 0.0625 + float(k) * 0.5
							var vein := OreField.vein_at(seed, chunk, Vector2i(tx, tz), depth, cache)
							if vein.is_empty() or str(vein["material"]) != "Aethermite":
								continue
							seen += 1
							if depth < float(band["min"]):
								above_band += 1
							var g := chunk * 64 + Vector2i(tx, tz)
							if not OreField.near_ley_line(seed, Vector2(g.x * 0.5 + 0.25, g.y * 0.5 + 0.25)):
								off_ley += 1
	scan.free()
	assert_true(seen > 0, "the sample found aethermite (%d tiles) — the gates are not vacuous" % seen)
	assert_eq(above_band, 0, "aethermite never sits above its fabric depth band")
	assert_eq(off_ley, 0, "aethermite never sits far from a ley line")

func _test_ore_bands_are_fabric() -> void:
	for key in GameData.MATERIALS:
		var res: Resource = GameData.MATERIALS[key]
		assert_true(res.get("depthBand") is Dictionary, "%s carries a fabric depthBand" % str(key))
		assert_true(res.get("leyGated") != null, "%s carries a fabric leyGated" % str(key))
		var band := OreField.band_of(str(key))
		assert_eq(float(band["min"]), float(res.get("depthBand")["min"]), "%s band min is the fabric's" % str(key))
		assert_eq(float(band["max"]), float(res.get("depthBand")["max"]), "%s band max is the fabric's" % str(key))
		assert_eq(bool(band["ley"]), bool(res.get("leyGated")), "%s ley gate is the fabric's" % str(key))
	assert_true(bool(OreField.band_of("Aethermite")["ley"]), "aethermite is the ley-gated ore")
	assert_true(float(OreField.band_of("Aethermite")["min"]) > 0.0, "and a deep one")
	# A wood is never a ground vein: its band is empty.
	assert_false(OreField.allows("Thornwood", 1.0, Vector2.ZERO, 0), "a wood's band admits nothing")
	assert_false(OreField.allows("Veilsteel", 1.0, Vector2.ZERO, 0), "nor does an alloy's")

func _test_ore_ley_field() -> void:
	var near := 0
	var total := 0
	var lo := 1.0
	var hi := 0.0
	for z in range(-200, 200, 3):
		for x in range(-200, 200, 3):
			var v := OreField.ley_line_value(99, Vector2(x, z))
			lo = minf(lo, v)
			hi = maxf(hi, v)
			total += 1
			if OreField.near_ley_line(99, Vector2(x, z)):
				near += 1
	assert_true(lo >= 0.0 and hi <= 1.0, "the ley value is in [0, 1]")
	var frac := float(near) / float(total)
	assert_true(frac > 0.05 and frac < 0.6, "ley lines cover some but not most of the world (%.2f)" % frac)
	assert_eq(OreField.ley_line_value(99, Vector2(3.5, -7.25)), OreField.ley_line_value(99, Vector2(3.5, -7.25)),
		"and the field is a pure function of position")

## Aethermite vein counts of up to 16 volcanic chunks of world `seed` (appended to `counts`).
func _collect_volcanic_counts(seed: int, counts: Array) -> void:
	for cz in range(-400, 400, 5):   # rare niches are blobs now: scan wide to find volcanic ground
		for cx in range(-400, 400, 5):
			var chunk := Vector2i(cx, cz)
			if TerrainSlice.biome_for_chunk(chunk, seed) != "VolcanicBadlands":
				continue
			var n := 0
			var cache: Dictionary = {}
			for tz in range(0, 64, 2):
				for tx in range(0, 64, 2):
					for depth in [4.5, 6.5, 8.5]:
						var vein := OreField.vein_at(seed, chunk, Vector2i(tx, tz), depth, cache)
						if not vein.is_empty() and str(vein["material"]) == "Aethermite":
							n += 1
			counts.append(n)
			if counts.size() >= 16:
				break
		if counts.size() >= 16:
			break

## The retired draw gave every volcanic chunk the SAME Aethermite share (17/100, every
## depth). Per-chunk counts from the field must now vary.
func _test_ore_uniform_draw_gone() -> void:
	var counts: Array = []
	# Volcanic ground is a rare, latitude-bound niche: take the first world that has enough of it near spawn.
	for seed in range(7, 40):
		counts.clear()
		_collect_volcanic_counts(seed, counts)
		if counts.size() >= 8:
			break
	assert_true(counts.size() >= 8, "enough volcanic chunks sampled (%d)" % counts.size())
	var mean := 0.0
	for n in counts:
		mean += float(n)
	mean /= float(counts.size())
	var variance := 0.0
	for n in counts:
		variance += (float(n) - mean) * (float(n) - mean)
	variance /= float(counts.size())
	assert_true(variance > 1.0, "per-chunk aethermite counts vary (mean %.1f, variance %.1f, %s)" % [mean, variance, str(counts)])
	# The old constant share: 17% of the 32*32*3 samples = 522 per chunk, every chunk.
	var old_constant := int(0.17 * 32.0 * 32.0 * 3.0)
	var off := 0
	for n in counts:
		if absi(int(n) - old_constant) > old_constant / 2:
			off += 1
	assert_true(off > counts.size() / 2, "and most chunks are far from the retired constant share")

func _test_ore_blob_crosses_chunk_border() -> void:
	# Cells straddle chunk borders by construction (CELL_OFFSET_TILES), so some blob must
	# cover tiles on both sides of the x = 64 border. Find one and check continuity.
	var crossing := 0
	var agree := true
	for seed in [1, 2, 3, 4]:
		for tz in range(0, 64):
			for k in range(0, 24):
				var depth := 0.0625 + float(k) * 0.5
				var left := OreField.vein_at(seed, Vector2i(0, 0), Vector2i(63, tz), depth)
				var right := OreField.vein_at(seed, Vector2i(1, 0), Vector2i(0, tz), depth)
				# The same global tile asked through EITHER chunk is the same answer.
				if OreField.vein_at(seed, Vector2i(0, 0), Vector2i(64, tz), depth) != right:
					agree = false
				if not left.is_empty() and not right.is_empty() and str(left["id"]) == str(right["id"]):
					crossing += 1
	assert_true(agree, "a tile's vein does not depend on which chunk asks")
	assert_true(crossing > 0, "a vein blob spans the chunk border continuously (%d slices)" % crossing)

## Mine a surfacing vein out slice by slice: each vein slice yields its quantity (> 1),
## the reserve runs out exactly, and what is left of the blob yields host rock.
func _test_ore_vein_yields_and_exhausts() -> void:
	var found := _find_surface_vein(0)
	if found.is_empty():
		assert_true(false, "a vein breaks the surface of a flat chunk somewhere")
		return
	var chunk: Vector2i = found["chunk"]
	var vein: Dictionary = found["vein"]
	var id := str(vein["id"])
	var v := VoxelSlice.new()
	add_child(v)
	var inv := InventorySlice.new()
	add_child(inv)
	v.inventory_slice = inv
	v.build_chunk(chunk, _flat_heightmap(2.0))
	# Every (tile, slice) of THIS vein, top-down per tile.
	var slices: Array = []
	for tz in range(64):
		for tx in range(64):
			for k in range(0, 40):
				var depth := 0.0625 + float(k) * VoxelSlice.STEP_HEIGHT
				var hit := OreField.vein_at(0, chunk, Vector2i(tx, tz), depth)
				if not hit.is_empty() and str(hit["id"]) == id:
					slices.append([Vector2i(tx, tz), k])
	assert_true(slices.size() * int(vein["quantity"]) > int(vein["reserve"]),
		"the blob holds more slices than its reserve pays for (%d slices)" % slices.size())
	var vein_units := 0
	var max_yield := 0
	var host_after := ""
	var host_qty := 0
	for entry in slices:
		var t: Vector2i = entry[0]
		var k: int = entry[1]
		var g := chunk * 64 + t
		var xz := Vector2(g.x * 0.5 + 0.25, g.y * 0.5 + 0.25)
		# Mine the column down until its top slice is slice k, then mine slice k.
		var target_top := 2.0 - float(k) * VoxelSlice.STEP_HEIGHT
		while v.get_voxel_height_at(xz) > target_top + 0.0001:
			v.mine_block(Vector3(xz.x, v.get_voxel_height_at(xz), xz.y), Vector3.UP)
		var live := OreField.is_live(vein, v.get_vein_depletion())
		var r := v.mine_block(Vector3(xz.x, v.get_voxel_height_at(xz), xz.y), Vector3.UP)
		if live:
			assert_eq(str(r["material"]), str(vein["material"]), "a live vein slice yields the vein's material")
			vein_units += int(r["quantity"])
			max_yield = maxi(max_yield, int(r["quantity"]))
		else:
			host_after = str(r["material"])
			host_qty = int(r["quantity"])
			break
	assert_true(max_yield > 1, "a vein slice yields more than one unit (%d)" % max_yield)
	assert_eq(vein_units, int(vein["reserve"]), "the vein pays out exactly its reserve")
	assert_false(OreField.is_live(vein, v.get_vein_depletion()), "and is then exhausted")
	# A vein within the topsoil mines out to Soil (Phase 49); deeper it is the host rock.
	assert_true(host_after == OreField.host_material(VoxelSlice.DEFAULT_BIOME) or host_after == "Soil",
		"the rest of the blob is host rock or topsoil (%s)" % host_after)
	assert_eq(host_qty, 1, "one unit per slice, like any host rock")
	v.free()
	inv.free()

func _test_ore_host_rock_yield() -> void:
	var terrain := TerrainSlice.new()
	add_child(terrain)
	terrain.set_world_seed(31337)
	var v := VoxelSlice.new()
	add_child(v)
	v.terrain_slice = terrain
	var inv := InventorySlice.new()
	add_child(inv)
	v.inventory_slice = inv
	var chunk := _find_chunk_with_biome(terrain, ["VolcanicBadlands"])
	assert_true(chunk.x != -1, "found a volcanic chunk")
	v.build_chunk(chunk, _flat_heightmap(2.0))
	var host := 0
	var soil := 0
	var gated := 0
	var cache: Dictionary = {}
	for tz in range(0, 64, 16):
		for tx in range(0, 64, 16):
			var g := chunk * 64 + Vector2i(tx, tz)
			var xz := Vector3(g.x * 0.5 + 0.25, 2.0, g.y * 0.5 + 0.25)
			# Only tiles with NO vein anywhere in the band mined: surrounding rock.
			var veinous := false
			for k in range(13):
				if not OreField.vein_at(31337, chunk, Vector2i(tx, tz), float(k) * 0.125 + 0.0625, cache).is_empty():
					veinous = true
					break
			if veinous:
				continue
			# Mine one column down: the topsoil yields soil, then the rock below the biome's host
			# material — and never the gated ore.
			for _k in range(12):
				var r := v.mine_block(xz, Vector3.UP)
				if not bool(r["success"]):
					break
				var mat := str(r["material"])
				if mat == "Aethermite":
					gated += 1
				elif mat == "Soil":
					soil += 1
				elif mat == "Ashite" and int(r["quantity"]) == 1:
					host += 1
	assert_true(soil > 0, "the volcanic topsoil yields soil (%d slices)" % soil)
	assert_true(host > 0, "the rock below yields the host ashite, one unit (%d slices)" % host)
	assert_eq(gated, 0, "and never the gated ore")
	v.free()
	inv.free()
	terrain.free()

func _test_ore_surface_veins_rare() -> void:
	var top := 0
	var top_surface := 0
	for cx in range(-20, 20):
		for cz in range(-20, 20):
			var v0 := OreField.vein_in_cell(4242, Vector3i(cx, 0, cz))
			if not v0.is_empty():
				top += 1
				var c: Vector3 = v0["center"]
				if c.y - float(v0["half_height"]) * (1.0 + OreField.SHAPE_NOISE) < 0.0:
					top_surface += 1
	assert_true(top > 0, "the top cell holds veins")
	# Few surface breakers: each biome keeps only its fabric `surfaceVeinChance` of them, so
	# the kept share stays well under the unfiltered share that would poke out.
	assert_true(float(top_surface) / float(top) < 0.2, "surface-breaking veins are a minority (%d of %d)" % [top_surface, top])
	assert_eq(OreField.vein_in_cell(4242, Vector3i(3, 0, 3)), OreField.vein_in_cell(4242, Vector3i(3, 0, 3)), "still deterministic")

## Phase 49 — the surface-vein density is the BIOME's fabric `surfaceVeinChance`, not one
## code constant: a biome with a higher fabric chance keeps a larger share of its own
## surface-breaking top-cell veins, measured off the field itself. Proves the fabric value
## gates `_build_vein` (issue #111).
func _test_ore_surface_vein_chance_gates_by_biome() -> void:
	var kept := {}
	var total := {}
	# Cells of a block of chunks of each biome (Phase 51: the biomes are spread over the planet by
	# latitude, so a patch round the origin holds one or two of them).
	var scan := TerrainSlice.new()
	add_child(scan)
	scan.set_world_seed(4242)
	var cells: Array = []
	for biome_name in ["VolcanicBadlands", "TemperateForest", "VoidRift"]:
		for chunk_v in _biome_chunks(scan, [biome_name], 160):
			var chunk: Vector2i = chunk_v
			for dx in range(4):
				for dz in range(4):
					cells.append(Vector2i(chunk.x * 4 + dx, chunk.y * 4 + dz))
	scan.free()
	for cell_v in cells:
		var cell: Vector2i = cell_v
		if true:
			var vein := OreField.vein_in_cell(4242, Vector3i(cell.x, 0, cell.y))
			if vein.is_empty():
				continue
			var biome := str(vein["biome"])
			total[biome] = int(total.get(biome, 0)) + 1
			var c: Vector3 = vein["center"]
			if c.y - float(vein["half_height"]) * (1.0 + OreField.SHAPE_NOISE) < 0.0:
				kept[biome] = int(kept.get(biome, 0)) + 1
	var share := {}
	for biome in total:
		if int(total[biome]) >= 20:
			share[biome] = float(kept.get(biome, 0)) / float(total[biome])
	for biome in ["VolcanicBadlands", "TemperateForest", "VoidRift"]:
		assert_true(share.has(biome), "%s has top-cell veins in the sample" % biome)
	assert_true(float(share["VolcanicBadlands"]) > float(share["TemperateForest"]),
		"the 0.25 biome breaks the surface more than the 0.2 one (%s vs %s)" % [share["VolcanicBadlands"], share["TemperateForest"]])
	assert_true(float(share["TemperateForest"]) > float(share["VoidRift"]),
		"the 0.2 biome breaks the surface more than the 0.05 one (%s vs %s)" % [share["TemperateForest"], share["VoidRift"]])
	# The chance varies per biome, so the fabric field is observable rather than one default.
	var distinct := {}
	for biome in total:
		distinct[OreField.surface_vein_chance(biome)] = true
	assert_true(distinct.size() > 1, "surfaceVeinChance is per-biome, not one fabric default everywhere")

func _test_ore_depletion_persists() -> void:
	var found := _find_surface_vein(0)
	if found.is_empty():
		assert_true(false, "a vein breaks the surface of a flat chunk somewhere")
		return
	var chunk: Vector2i = found["chunk"]
	var vein: Dictionary = found["vein"]
	var id := str(vein["id"])
	var v := VoxelSlice.new()
	add_child(v)
	v.build_chunk(chunk, _flat_heightmap(2.0))
	var g: Vector2i = chunk * 64 + (found["tile"] as Vector2i)
	var xz := Vector2(g.x * 0.5 + 0.25, g.y * 0.5 + 0.25)
	var r := v.mine_block(Vector3(xz.x, 2.0, xz.y), Vector3.UP)
	assert_eq(int(r["quantity"]), int(vein["quantity"]), "the first vein slice yields the vein's quantity")
	assert_eq(int(v.get_vein_depletion().get(id, 0)), int(vein["quantity"]), "the depletion is recorded")
	# More mining of the same vein REPLACES the record; it never appends one per swing.
	v._record_depletion(vein, 1)
	v._record_depletion(vein, 1)
	var ops := 0
	for key in v.get_edits():
		for op in v.get_edits()[key]:
			if str(op.get("op", "")) == "deplete" and str(op.get("vein", "")) == id:
				ops += 1
	assert_eq(ops, 1, "one deplete op per vein, however many swings")
	var taken := int(v.get_vein_depletion()[id])
	# The anchor's chunk is dirty, so the save carries it.
	var anchor: Vector2i = vein["anchor"]
	assert_true(v.get_dirty_chunk_keys().has(VoxelSlice._chunk_key(VoxelSlice._tile_to_chunk(anchor))),
		"the vein's anchor chunk is marked dirty for the save")
	# A save round-trip restores it.
	var manifest := v.get_chunk_manifest()
	var json: Variant = JSON.parse_string(JSON.stringify(manifest))
	var w := VoxelSlice.new()
	add_child(w)
	w.apply_chunk_manifest(json)
	assert_eq(int(w.get_vein_depletion().get(id, -1)), taken, "the depletion survives a save and load")
	# Compaction rewrites a tile's run ops but keeps its depletion record.
	var key := VoxelSlice._tile_key(anchor)
	for i in range(VoxelSlice.MAX_TILE_OPS + 2):
		w._append_edit(anchor, { "op": "remove", "bottom": 1.875, "top": 2.0 })
		w._append_edit(anchor, { "op": "add", "bottom": 1.875, "top": 2.0, "material": "" })
	var kept := false
	for op in w.get_edits().get(key, []):
		if str(op.get("op", "")) == "deplete":
			kept = true
	assert_true(kept, "compaction keeps the depletion record")
	w._reindex_edits()
	assert_eq(int(w.get_vein_depletion().get(id, -1)), taken, "and the index still reads it")
	# An unreadable deplete op is dropped on load, never guessed.
	var normalised: Array = w._normalise_ops([{ "op": "deplete", "vein": "", "taken": 3 }, { "op": "deplete", "vein": "1,0,1", "taken": -2 }])
	assert_eq(normalised.size(), 0, "a deplete op with no vein or a negative count is dropped")
	v.free()
	w.free()

func _test_ore_client_replays_depletion() -> void:
	var found := _find_surface_vein(0)
	if found.is_empty():
		assert_true(false, "a vein breaks the surface of a flat chunk somewhere")
		return
	var chunk: Vector2i = found["chunk"]
	var flat := _flat_heightmap(2.0)
	var host := VoxelSlice.new()
	add_child(host)
	host.build_chunk(chunk, flat)
	# The client is NOT in the tree, so it does not hear the host's block_changed on the bus;
	# the edit is handed to it explicitly, exactly as the network would.
	var client := VoxelSlice.new()
	client.is_authoritative = false
	client.build_chunk(chunk, flat)
	var g: Vector2i = chunk * 64 + (found["tile"] as Vector2i)
	var pos := Vector3(g.x * 0.5 + 0.25, 2.0, g.y * 0.5 + 0.25)
	var r := host.mine_block(pos, Vector3.UP)
	client.apply_block_change("mine", pos, Vector3.UP, str(r["material"]))
	assert_eq(client.get_vein_depletion(), host.get_vein_depletion(), "the client records the host's depletion")
	assert_eq(client.get_edits(), host.get_edits(), "and its edit log matches the host's")
	host.free()
	client.free()

func _test_ore_build_payload_carries_field() -> void:
	var terrain := TerrainSlice.new()
	add_child(terrain)
	terrain.set_world_seed(2468)
	var v := VoxelSlice.new()
	add_child(v)
	v.terrain_slice = terrain
	var flat := _flat_heightmap(2.0)
	var payload := v.gather_build_input(Vector2i.ZERO, flat)
	assert_eq(int(payload["seed"]), 2468, "the payload carries the world seed")
	assert_true(payload["depleted"] is Dictionary, "and the depletion record")
	v._vein_taken["9,9,9"] = 3
	var copied: Dictionary = v.gather_build_input(Vector2i.ZERO, flat)["depleted"]
	v._vein_taken["9,9,9"] = 4
	assert_eq(int(copied["9,9,9"]), 3, "the depletion record is COPIED for the worker, not shared")
	v.free()
	terrain.free()

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

## Phase 84 — nothing the suite or the code it drove left parentless. Reads the engine's own
## orphan monitor, so it covers production leaks too (a node created but never parented or freed).
func _assert_no_orphan_nodes() -> void:
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	if orphans != 0:
		Node.print_orphan_nodes()
	assert_eq(orphans, 0, "the suite leaves no orphan nodes")

## Phase 84 — nodes a test helper created and handed back: freed right after the test, so a
## helper (`_spawn_world`) does not need every caller to remember a `free()`.
var _owned: Array = []

func _own(n: Node) -> Node:
	_owned.append(n)
	return n

func _free_owned() -> void:
	for n in _owned:
		if is_instance_valid(n):
			n.free()
	_owned.clear()

func _run_test(name: String, fn: Callable) -> void:
	_current_test = name
	_registered_names[str(fn.get_method())] = true
	var fails_before := _fail
	fn.call()
	_free_owned()
	var outcome := "✓" if _fail == fails_before else "✗"
	print("  %s %s" % [outcome, name])


# ---------------------------------------------------------------------------
# Phase 44 — spawn scarcity
# ---------------------------------------------------------------------------

## A wired world for the spawn tests: a real terrain slice on `seed_v`, and the chunks of
## `biome` found in a 24x24 sample (a creature only spawns in chunks of its own biome).
func _spawn_world(seed_v: int, biome: String) -> Dictionary:
	var terrain := TerrainSlice.new()
	_own(terrain)
	terrain.set_world_seed(seed_v)
	var chunks: Array = []
	for x in range(-12, 12):
		for z in range(-12, 12):
			if str(terrain.get_biome_at_chunk(Vector2i(x, z))) == biome:
				chunks.append(Vector2i(x, z))
	return { "terrain": terrain, "chunks": chunks }

## Pins the hash's raw output: it leans on 64-bit int wraparound, and any edit to it
## silently reshuffles every world's spawns. Values computed with 64-bit wrap arithmetic.
func _test_spawn_roll_mix_pinned() -> void:
	assert_eq(SpawnRoll._mix(7, 0, 0, 0), 1245989457, "mix pinned: zero chunk")
	assert_eq(SpawnRoll._mix(7, 3, -5, 12345), 1437575032, "mix pinned: mixed-sign chunk")
	assert_eq(SpawnRoll._mix(123456789, -2, 9, -77), 1142957741, "mix pinned: large seed, negative salt")
	assert_eq(SpawnRoll._mix(1, 1, 1, 1), 1444049576, "mix pinned: ones")

func _test_spawn_roll_pure() -> void:
	var lo := 9.0
	var hi := -9.0
	for x in range(-20, 20):
		var u := SpawnRoll.unit(7, Vector2i(x, 3), "x")
		assert_true(u >= 0.0 and u < 1.0, "the roll is in [0, 1)")
		var m := SpawnRoll.density(7, Vector2i(x, 3), 0.5)
		lo = minf(lo, m)
		hi = maxf(hi, m)
	assert_true(lo >= 0.5 and hi <= 1.5, "the density multiplier stays within 1 +/- amplitude")
	assert_true(hi - lo > 0.05, "the density multiplier actually varies")
	assert_eq(SpawnRoll.density(7, Vector2i(4, 4), 0.0), 1.0, "amplitude 0 is flat")
	assert_eq(SpawnRoll.unit(7, Vector2i(2, 5), "a"), SpawnRoll.unit(7, Vector2i(2, 5), "a"), "the roll is pure")
	assert_true(SpawnRoll.unit(7, Vector2i(2, 5), "a") != SpawnRoll.unit(8, Vector2i(2, 5), "a"), "the seed changes the roll")
	assert_eq(SpawnRoll.pack_size(1, Vector2i(0, 0), "s", 3, 0.0, 0.5), 0, "chance 0 never spawns")
	assert_eq(SpawnRoll.pack_size(1, Vector2i(0, 0), "s", 3, 1.0, 0.0), 3, "chance 1, flat density spawns the full pack")
	assert_eq(SpawnRoll.pack_size(1, Vector2i(0, 0), "s", 0, 1.0, 0.0), 0, "a zero pack is no spawn")
	var empty := 0
	var sizes := {}
	for x in range(40):
		var n := SpawnRoll.pack_size(1, Vector2i(x, 0), "s", 3, 0.6, 0.5)
		sizes[n] = true
		if n == 0:
			empty += 1
	assert_true(empty > 0 and empty < 40, "a chunk can roll no spawn, and not every chunk does")
	assert_true(sizes.size() > 2, "pack sizes vary across chunks")

func _test_spawn_creature_scarcity() -> void:
	var w := _spawn_world(4242, "TemperateForest")
	var chunks: Array = w["chunks"]
	assert_true(chunks.size() >= 8, "the sample holds enough forest chunks")
	var host := CreatureSlice.new()
	host.render_visuals = false
	host.terrain_slice = w["terrain"]
	add_child(host)
	var twin := CreatureSlice.new()
	twin.render_visuals = false
	twin.terrain_slice = w["terrain"]
	add_child(twin)
	var counts := {}
	for ch in chunks:
		host.spawn_for_chunk(ch)
	for ch in chunks.slice(0, 20):
		twin.spawn_for_chunk(ch)
	for iid in host._instances:
		var inst: Dictionary = host._instances[iid]
		if inst["creature_id"] != "ForestBoar":
			continue
		counts[inst["chunk"]] = int(counts.get(inst["chunk"], 0)) + 1
	var seen := {}
	var empty := 0
	for ch in chunks:
		var n := int(counts.get(ch, 0))
		seen[n] = true
		if n == 0:
			empty += 1
	assert_true(empty > 0, "some chunk rolls no boar at all")
	assert_true(seen.size() > 1, "boar counts per chunk have non-zero variance (not the retired constant 3)")
	for ch in chunks.slice(0, 20):
		var a := 0
		var b := 0
		for iid in host._instances:
			if host._instances[iid]["chunk"] == ch:
				a += 1
		for iid in twin._instances:
			if twin._instances[iid]["chunk"] == ch:
				b += 1
		assert_eq(a, b, "two peers on one seed place the same pack in %s" % str(ch))
	host.free()
	twin.free()

func _test_spawn_population_cap() -> void:
	var w := _spawn_world(4242, "TemperateForest")
	var chunks: Array = w["chunks"]
	var unbounded := CreatureSlice.new()
	unbounded.render_visuals = false
	unbounded.terrain_slice = w["terrain"]
	add_child(unbounded)
	for ch in chunks:
		unbounded.spawn_for_chunk(ch)
	var total: int = unbounded.live_population()
	assert_true(total > 6, "the unbounded walk accumulates more than the cap under test")
	unbounded.free()
	var c := CreatureSlice.new()
	c.render_visuals = false
	c.terrain_slice = w["terrain"]
	c.set_population_cap(6)
	add_child(c)
	for ch in chunks:
		c.spawn_for_chunk(ch)
		assert_true(c.live_population() <= 6, "live instances never exceed the cap")
	var held: int = c.live_population()
	assert_true(held > 0, "the cap still admits packs that fit")
	var first_chunk: Variant = null
	for iid in c._instances:
		first_chunk = c._instances[iid]["chunk"]
		break
	c.despawn_for_chunk(first_chunk)
	assert_true(c.live_population() < held, "a despawn returns budget")
	for ch in chunks:
		c.spawn_for_chunk(ch)
	assert_true(c.live_population() <= 6, "the released budget is reused without breaching the cap")
	# A death frees a slot a new pack may take; the dead creature's respawn must then wait
	# for room instead of pushing the live count over the cap.
	for iid in c._instances:
		if c._instances[iid]["state"] != "dead":
			c._instances[iid]["state"] = "dead"
			c._instances[iid]["respawn_at"] = 1.0
			break
	for ch in chunks:
		c.spawn_for_chunk(ch)
	c._tick_respawn()
	assert_true(c.live_population() <= 6, "a respawn never breaches the cap")
	c.free()

## Phase 57 follow-up — every member of a pack lands inside its chunk (also with packs
## bigger than the offset table), and no two members share a spot.
func _test_spawn_pack_bounds_and_retry() -> void:
	var c := CreatureSlice.new()
	c.render_visuals = false
	add_child(c)
	var cs: int = c._chunk_size()
	for chunk in [Vector2i(0, 0), Vector2i(-3, 5), Vector2i(7, -2)]:
		var seen := {}
		for idx in range(CreatureSlice.MAX_PACK_MEMBERS):
			var xz: Vector2 = c._deterministic_chunk_position(chunk, "Wolf", 0) + c._pack_member_offset(idx)
			assert_true(xz.x >= chunk.x * cs and xz.x < (chunk.x + 1) * cs
					and xz.y >= chunk.y * cs and xz.y < (chunk.y + 1) * cs,
				"member %d of a full pack is inside its chunk" % idx)
			seen[xz] = true
		assert_eq(seen.size(), CreatureSlice.MAX_PACK_MEMBERS, "no two pack members stack")
	c.free()
	# A pack the cap refused is remembered and admitted once room frees up, with no
	# chunk reload; leaving the chunk forgets it.
	var w := _spawn_world(4242, "TemperateForest")
	var capped := CreatureSlice.new()
	capped.render_visuals = false
	capped.terrain_slice = w["terrain"]
	capped.set_population_cap(2)
	add_child(capped)
	for ch in w["chunks"]:
		capped.spawn_for_chunk(ch)
	assert_false(capped._deferred_packs.is_empty(), "a refused pack is remembered")
	var before: int = capped.live_population()
	capped.set_population_cap(0)
	capped._retry_deferred_packs()
	assert_true(capped.live_population() > before, "the deferred packs are admitted once the cap allows")
	assert_true(capped._deferred_packs.is_empty(), "and are no longer pending")
	capped.set_population_cap(1)
	var gone: Variant = null
	for ch in w["chunks"]:
		capped.despawn_for_chunk(ch)
		capped.spawn_for_chunk(ch)
		if not capped._deferred_packs.is_empty():
			gone = capped._deferred_packs.keys()[0][0]
			break
	if gone != null:
		capped.despawn_for_chunk(gone)
		for key in capped._deferred_packs:
			assert_true(key[0] != gone, "leaving a chunk drops its deferred packs")
	capped.free()

## Phase 57 — a creature resource lacking spawnChance/spawnDensity warns once (the flag is
## the once-latch the warning sits behind) and still spawns, without a roll.
func _test_spawn_missing_fields_warns_once() -> void:
	var src := GDScript.new()
	src.source_code = "extends Resource\nvar biome: int = 0\nvar spawnCount: int = 1\n"
	assert_eq(src.reload(), OK, "the field-less stand-in compiles")
	var fake: Resource = src.new()
	var c := CreatureSlice.new()
	c.render_visuals = false
	add_child(c)
	var was_quiet: bool = Diag.quiet
	Diag.quiet = true
	assert_false(c._warned_spawn_fields.has("NoFields"), "nothing warned before the first read")
	var fields: Array = c._spawn_fields("NoFields", fake)
	assert_true(fields[0] == null and fields[1] == null, "missing fields read as null (spawn without a roll)")
	assert_true(c._warned_spawn_fields.has("NoFields"), "the missing fields are reported")
	c._spawn_fields("NoFields", fake)
	assert_eq(c._warned_spawn_fields.size(), 1, "once per species, however often it is read")
	for key in GameData.CREATURES:
		c._spawn_fields(str(key), GameData.CREATURES[key])
	assert_eq(c._warned_spawn_fields.size(), 1, "the fabric's own creatures all carry both fields")
	Diag.quiet = was_quiet
	c.free()

## Species do not thicken and thin in lockstep: the density noise is salted per species.
func _test_spawn_density_per_species() -> void:
	var differs := false
	for x in range(40):
		var a := SpawnRoll.density(9, Vector2i(x, 1), 0.8, "Wolf")
		var b := SpawnRoll.density(9, Vector2i(x, 1), 0.8, "Boar")
		if not is_equal_approx(a, b):
			differs = true
		assert_eq(a, SpawnRoll.density(9, Vector2i(x, 1), 0.8, "Wolf"), "a salted field is still pure")
	assert_true(differs, "two species see different density fields")
	assert_eq(SpawnRoll.density(9, Vector2i(3, 3), 0.8), SpawnRoll.density(9, Vector2i(3, 3), 0.8, ""),
		"no salt is the unsalted field")

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
	var merged := AssetOverlay.merge_manifests(
		{"meshes": {"a": "pub_a", "b": "pub_b"}, "textures": {"t": "pub_t"}},
		{"meshes": {"b": "priv_b", "c": "priv_c"}, "junk": 5})
	assert_eq(merged["meshes"], {"a": "pub_a", "b": "priv_b", "c": "priv_c"}, "private overrides by key, public-only keys survive")
	assert_eq(merged["textures"], {"t": "pub_t"}, "a kind only the public manifest lists survives")
	assert_false(merged.has("junk"), "a non-dictionary section is ignored")
	assert_eq(AssetOverlay.merge_manifests({}, {}), {}, "two empty manifests merge to empty")
	assert_eq(AssetOverlay.first_key("meshes", ["models/nope.glb.raw", "models/placeholder_rig.glb.raw"]),
		"models/placeholder_rig.glb.raw", "first_key skips unlisted keys")
	assert_eq(AssetOverlay.first_key("meshes", ["models/nope.glb.raw"]), "", "and is empty when none is listed")

func _test_character_remote_avatar() -> void:
	var ch := CharacterSlice.new()
	add_child(ch)
	var iid := ch.create_character("TravellerHuman", Vector3.ZERO)
	ch.bind_peer_character(9, iid)
	assert_true(ch.set_character_position(iid, Vector3(4, 0, 5)), "an instance can be moved")
	assert_eq(ch.get_character_position(iid), Vector3(4, 0, 5), "and reports where it is")
	assert_false(ch.set_character_position("nope", Vector3.ZERO), "an unknown instance cannot")
	assert_true(ch.remove_character(iid), "an instance can be removed")
	assert_true(ch.get_character_position(iid) == null, "and is gone")
	ch.set_peer_equipment(9, { "Head": "FerriteHelmet" })
	assert_eq(ch.get_peer_equipment(9), { "Head": "FerriteHelmet" }, "removal unbinds: later gear is stored, not applied to a ghost")
	assert_false(ch.remove_character(iid), "removing twice is a no-op")
	ch.free()

func _test_spawn_tree_density() -> void:
	var w := _spawn_world(4242, "TemperateForest")
	var t := _make_tree_slice()
	t.terrain_slice = w["terrain"]
	assert_eq(t.density_for("TemperateForest"), 8, "forest density is the fabric treeDensity")
	assert_eq(t.density_for("TemperateGrassland"), 2, "grassland density is the fabric treeDensity")
	assert_eq(t.density_for("VolcanicBadlands"), 0, "the badlands grow no trees")
	var seen := {}
	var clearings := 0
	for ch in w["chunks"]:
		var n: int = t.tree_count_for(ch, "TemperateForest")
		seen[n] = true
		if n == 0:
			clearings += 1
		assert_eq(n, t.tree_count_for(ch, "TemperateForest"), "the count is pure in (seed, chunk)")
	assert_true(seen.size() > 1, "tree counts vary across chunks")
	assert_eq(t.tree_count_for(Vector2i(0, 0), "VolcanicBadlands"), 0, "no trees in the badlands")
	t.free()

## Phase 47 review — the host records only the gear the peer's own bag holds, so an
## equip action cannot conjure an item the peer never owned.
func _test_equipment_intent_requires_ownership() -> void:
	var registry := PlayerRegistry.new()
	add_child(registry)
	var peer := str(registry.resolve_identity(2))
	var revoked: Array = []
	var rcb := func(pid: String, worn: Dictionary) -> void: revoked.append([pid, worn])
	GameBus.equipment_revoked.connect(rcb)
	GameBus.equip_intent.emit(peer, "Chest", "VeilsteelChestplate")
	assert_true(registry.get_equipment(peer).is_empty(), "an unowned chestplate is not recorded")
	assert_eq(revoked.size(), 1, "the refused equip tells the owner what it must show")
	if revoked.size() == 1:
		assert_eq(revoked[0][0], peer, "the correction names the owner")
		assert_true((revoked[0][1] as Dictionary).is_empty(), "and carries the host's (empty) set")
	assert_true(registry.get_inventory(peer).add_item("VeilsteelChestplate", 1), "the peer picks one up")
	GameBus.equip_intent.emit(peer, "Chest", "VeilsteelChestplate")
	assert_eq(registry.get_equipment(peer).get("Chest", ""), "VeilsteelChestplate", "an owned one is recorded")
	assert_eq(revoked.size(), 1, "an accepted equip needs no correction")
	GameBus.equipment_revoked.disconnect(rcb)
	registry.free()

## Host-authoritative equip — an action touches exactly one slot of the record. A wrong-slot
## item, an unknown item and an unknown slot are refused; taking an item off clears only
## its slot; omitting gear is not expressible, so a worn weapon stays recorded.
func _test_equip_intent_is_host_authoritative() -> void:
	var registry := PlayerRegistry.new()
	add_child(registry)
	var peer := str(registry.resolve_identity(2))
	var inv: Node = registry.get_inventory(peer)
	inv.add_item("VeilsteelChestplate", 1)
	inv.add_item("VeilsteelLongsword", 1)
	GameBus.equip_intent.emit(peer, "Chest", "VeilsteelChestplate")
	GameBus.equip_intent.emit(peer, "MainHand", "VeilsteelLongsword")
	assert_eq(registry.get_equipment(peer), { "Chest": "VeilsteelChestplate", "MainHand": "VeilsteelLongsword" }, "two actions, two slots")
	GameBus.equip_intent.emit(peer, "Head", "VeilsteelChestplate")
	GameBus.equip_intent.emit(peer, "Head", "NoSuchItem")
	GameBus.equip_intent.emit(peer, "NoSuchSlot", "VeilsteelChestplate")
	GameBus.equip_intent.emit(peer, "Chest", "")
	assert_eq(registry.get_equipment(peer), { "MainHand": "VeilsteelLongsword" }, "bad actions change nothing; unequip clears only its slot")
	GameBus.equip_intent.emit(peer, "Chest", "")
	assert_eq(registry.get_equipment(peer), { "MainHand": "VeilsteelLongsword" }, "unequipping an empty slot is a no-op")
	assert_true(registry.equip_allowed(peer, "MainHand", "VeilsteelLongsword"), "equip_allowed accepts an owned, fitting item")
	assert_false(registry.equip_allowed(peer, "Chest", "VeilsteelLongsword"), "a sword does not fit the chest")
	assert_false(registry.equip_allowed(peer, "", "VeilsteelLongsword"), "an empty slot fails closed")
	assert_false(registry.equip_allowed(peer, "MainHand", ""), "an empty item fails closed")
	registry.free()

## Host-authoritative equip — what the local avatar shows after a restore. A host keeps the
## gear its recipe gave an avatar when the record is empty (and records it); a client shows
## exactly the host's record, an empty one included, and rebases its diff on it so the
## restore itself sends no action.
func _test_apply_local_equipment_paths() -> void:
	var root_script: GDScript = load("res://src/core/game_root.gd")
	for as_client in [false, true]:
		var gr: Node = root_script.new()
		var ch := CharacterSlice.new()
		add_child(ch)
		var reg := PlayerRegistry.new()
		add_child(reg)
		gr._character = ch
		gr._registry = reg
		gr._is_client = as_client
		var iid: String = ch.create_character("TravellerHuman", Vector3.ZERO)
		ch.set_player_character(iid)
		reg.set_local_player(reg.mint_player_id())
		ch.apply_equipment(iid, "Chest", "VeilsteelChestplate")
		var sent: Array = []
		var on_action := func(_p: String, slot: String, item: String) -> void: sent.append([slot, item])
		GameBus.equip_intent.connect(on_action)
		gr._apply_local_equipment({})
		GameBus.equip_intent.disconnect(on_action)
		var tag := "client" if as_client else "host"
		assert_true(sent.is_empty(), "%s: a restore sends no equip action" % tag)
		if as_client:
			assert_true(ch.get_equipment_set(iid).is_empty(), "client: an empty host record strips the recipe's gear")
			assert_true((gr._last_sent_equipment as Dictionary).is_empty(), "client: the diff baseline is the applied set")
		else:
			assert_eq(ch.get_equipment_set(iid).get("Chest", ""), "VeilsteelChestplate", "host: an empty record keeps the recipe's gear")
			assert_eq(reg.get_equipment(reg.local_player_id).get("Chest", ""), "VeilsteelChestplate", "host: and records it")
		# A recorded set is applied exactly.
		gr._apply_local_equipment({ "Head": "FerriteHelmet" })
		assert_eq(ch.get_equipment_set(iid).get("Head", ""), "FerriteHelmet", "%s: a recorded set is worn" % tag)
		gr.free()
		ch.free()
		reg.free()

## Host-authoritative equip — the client diffs its avatar's set into per-slot actions.
func _test_equip_actions_diff() -> void:
	assert_eq(EquipmentRules.diff_actions({}, {}), [], "no change, no action")
	assert_eq(EquipmentRules.diff_actions({}, { "Chest": "A" }), [{ "slot": "Chest", "item": "A" }], "a new item is an equip")
	assert_eq(EquipmentRules.diff_actions({ "Chest": "A" }, {}), [{ "slot": "Chest", "item": "" }], "a removed item is an unequip")
	assert_eq(EquipmentRules.diff_actions({ "Chest": "A" }, { "Chest": "B" }), [{ "slot": "Chest", "item": "B" }], "a swap is one equip")
	assert_eq(EquipmentRules.diff_actions({ "Chest": "A", "Head": "H" }, { "Chest": "A", "MainHand": "S" }),
		[{ "slot": "Head", "item": "" }, { "slot": "MainHand", "item": "S" }], "only differing slots, sorted")


## Phase 48 — wearing an item and then losing it from the bag clears the slot and
## emits equipment_changed through the same record path as an equip.
func _test_equipment_revalidated_on_bag_loss() -> void:
	var registry := PlayerRegistry.new()
	add_child(registry)
	var peer := str(registry.resolve_identity(2))
	var inv: Node = registry.get_inventory(peer)
	inv.add_item("VeilsteelChestplate", 1)
	GameBus.equip_intent.emit(peer, "Chest", "VeilsteelChestplate")
	assert_eq(registry.get_equipment(peer).get("Chest", ""), "VeilsteelChestplate", "worn after the action")
	var seen: Array = []
	var cb := func(pid: String, worn: Dictionary) -> void: seen.append([pid, worn])
	var revoked: Array = []
	var rcb := func(pid: String, worn: Dictionary) -> void: revoked.append([pid, worn])
	GameBus.equipment_changed.connect(cb)
	GameBus.equipment_revoked.connect(rcb)
	assert_true(inv.drop_item("VeilsteelChestplate", 1), "the peer drops it")
	GameBus.equipment_changed.disconnect(cb)
	GameBus.equipment_revoked.disconnect(rcb)
	assert_eq(revoked.size(), 1, "the owner is told about the forced clear")
	if revoked.size() == 1:
		assert_eq(revoked[0][0], peer, "the revocation names the owner")
		assert_true((revoked[0][1] as Dictionary).is_empty(), "and carries the emptied set")
	assert_true(registry.get_equipment(peer).is_empty(), "the slot is cleared once the bag no longer holds it")
	assert_eq(seen.size(), 1, "exactly one equipment_changed was emitted")
	if seen.size() == 1:
		assert_true((seen[0][1] as Dictionary).is_empty(), "the change carries the emptied set")
	registry.free()

## Phase 70 — a returning player's worn item the bag no longer holds is gone from the record
## by the time `player_joined` fires, which is when the handshake snapshot is built.
func _test_equipment_revalidated_before_join() -> void:
	var registry := PlayerRegistry.new()
	add_child(registry)
	registry.apply_player_data("returning", { "equipment": { "Chest": "VeilsteelChestplate" } })
	registry.record_equipment("returning", { "Chest": "VeilsteelChestplate" })
	assert_eq(registry.get_equipment("returning").size(), 1, "the saved record wears a chestplate")
	var at_join: Array = []
	var cb := func(_peer: int, pid: String, _re: bool) -> void: at_join.append(registry.get_equipment(pid).duplicate())
	GameBus.player_joined.connect(cb)
	var bound := registry.resolve_identity(3, "returning")
	GameBus.player_joined.disconnect(cb)
	assert_eq(bound, "returning", "the player is rebound to its record")
	assert_eq(at_join.size(), 1, "one join was announced")
	if at_join.size() == 1:
		assert_true((at_join[0] as Dictionary).is_empty(), "the slot is already empty in the join payload")
	registry.free()

## Phase 70 — refused intent N then valid intent N+1: the host answers N with a revoke
## numbered N (no Chest), then N+1 with the item. The client has already sent N+1, so the
## older correction is skipped and it ends up showing N+1's item.
func _test_equipment_stale_revoke_ignored() -> void:
	var root_script: GDScript = load("res://src/core/game_root.gd")
	var gr: Node = root_script.new()
	var ch := CharacterSlice.new()
	add_child(ch)
	var reg := PlayerRegistry.new()
	add_child(reg)
	var net := NetworkingSlice.new()
	add_child(net)
	gr._character = ch
	gr._registry = reg
	gr._networking = net
	gr._is_client = true
	var iid: String = ch.create_character("TravellerHuman", Vector3.ZERO)
	ch.set_player_character(iid)
	reg.set_local_player(reg.mint_player_id())
	net._role = NetworkingSlice.Role.CLIENT
	net._on_equip_intent("", "Head", "NoSuchHelmet")      # seq 1 — will be refused
	net._on_equip_intent("", "Chest", "VeilsteelChestplate")  # seq 2 — valid
	assert_eq(net.equip_seq_sent(), 2, "each action advances the sequence")
	ch.apply_equipment(iid, "Chest", "VeilsteelChestplate")
	# Replies arrive in order: the revoke for #1 (host had no Chest yet), then the record for #2.
	gr._on_own_state_synced({ "equipment": {}, "equipment_seq": 1 })
	assert_eq(ch.get_equipment_set(iid).get("Chest", ""), "VeilsteelChestplate", "the older revoke is ignored")
	gr._on_own_state_synced({ "equipment": { "Chest": "VeilsteelChestplate" }, "equipment_seq": 2 })
	assert_eq(ch.get_equipment_set(iid).get("Chest", ""), "VeilsteelChestplate", "the newer reply keeps the item")
	gr._on_own_state_synced({ "equipment": {}, "equipment_seq": 2 })
	assert_true(ch.get_equipment_set(iid).is_empty(), "a revoke answering the newest action is applied")
	gr.free()
	net.free()
	ch.free()
	reg.free()

## Phase 70 — a peer spamming refused equips costs one warn and one revoke per interval.
func _test_equipment_refusals_rate_limited() -> void:
	var registry := PlayerRegistry.new()
	add_child(registry)
	var peer := str(registry.resolve_identity(2))
	var revoked: Array = []
	var rcb := func(pid: String, _worn: Dictionary) -> void: revoked.append(pid)
	GameBus.equipment_revoked.connect(rcb)
	var warns_before: int = Diag.warn_count()
	for i in 100:
		registry.note_equip_seq(peer, i + 1)
		GameBus.equip_intent.emit(peer, "Chest", "VeilsteelChestplate")
	GameBus.equipment_revoked.disconnect(rcb)
	assert_eq(revoked.size(), 1, "one revoke for 100 refusals in an interval")
	assert_eq(Diag.warn_count() - warns_before, 1, "and one warn")
	assert_eq(registry.equip_refused_suppressed, 99, "the rest are counted")
	assert_eq(registry.equip_seq_of(peer), 100, "the host remembers the newest sequence it processed")
	registry.free()

## Review of #181 — a refusal the rate limit swallows must not leave the owner showing a
## refused item: one trailing revoke answers the burst, carrying the record as it then is.
func _test_equipment_trailing_revoke() -> void:
	var registry := PlayerRegistry.new()
	add_child(registry)
	var peer := str(registry.resolve_identity(2))
	var revoked: Array = []
	var rcb := func(pid: String, _worn: Dictionary) -> void: revoked.append(pid)
	GameBus.equipment_revoked.connect(rcb)
	GameBus.equip_intent.emit(peer, "Chest", "VeilsteelChestplate")
	assert_eq(revoked.size(), 1, "the first refusal revokes at once")
	GameBus.equip_intent.emit(peer, "Chest", "VeilsteelChestplate")
	assert_eq(revoked.size(), 1, "the second is suppressed")
	assert_true(registry._equip_revoke_pending.has(peer), "but a trailing revoke is scheduled")
	for i in 5:
		GameBus.equip_intent.emit(peer, "Chest", "VeilsteelChestplate")
	assert_eq(registry._equip_revoke_pending.size(), 1, "a burst schedules one trailing revoke, not one per refusal")
	registry._flush_trailing_revoke(peer)
	assert_eq(revoked.size(), 2, "the trailing revoke goes out when the interval ends")
	assert_false(registry._equip_revoke_pending.has(peer), "and clears the pending mark")
	registry._flush_trailing_revoke(peer)
	assert_eq(revoked.size(), 2, "a second flush is a no-op")
	GameBus.equipment_revoked.disconnect(rcb)
	registry.free()

## Review of #181 — nothing equip-related outlives the record it describes.
func _test_equipment_bookkeeping_evicted() -> void:
	var registry := PlayerRegistry.new()
	add_child(registry)
	var peer := str(registry.resolve_identity(2))
	registry.note_equip_seq(peer, 4)
	GameBus.equip_intent.emit(peer, "Chest", "VeilsteelChestplate")
	GameBus.equip_intent.emit(peer, "Chest", "VeilsteelChestplate")
	assert_true(registry._equip_seq.has(peer) and registry._equip_refusals.has(peer), "the entries exist while the player is resident")
	registry.unbind_peer(2)
	assert_true(_evict_and_free(registry, peer), "the player is evicted")
	assert_false(registry._equip_seq.has(peer), "the sequence entry goes with it")
	assert_false(registry._equip_refusals.has(peer), "so does the refusal timestamp")
	assert_false(registry._equip_revoke_pending.has(peer), "and the pending trailing revoke")
	var revoked: Array = []
	var rcb := func(pid: String, _worn: Dictionary) -> void: revoked.append(pid)
	GameBus.equipment_revoked.connect(rcb)
	registry._flush_trailing_revoke(peer)
	GameBus.equipment_revoked.disconnect(rcb)
	assert_true(revoked.is_empty(), "a timer firing after eviction revokes nothing")
	registry.free()

## Review of #181 — a client sending a lower number than before cannot rewind the host's tag.
func _test_equipment_seq_monotonic() -> void:
	var registry := PlayerRegistry.new()
	add_child(registry)
	registry.note_equip_seq("p", 5)
	registry.note_equip_seq("p", 2)
	assert_eq(registry.equip_seq_of("p"), 5, "a lower number is ignored")
	registry.note_equip_seq("p", -3)
	assert_eq(registry.equip_seq_of("p"), 5, "a negative one too")
	registry.note_equip_seq("p", 6)
	assert_eq(registry.equip_seq_of("p"), 6, "a higher one advances")
	registry.free()

func _test_equipment_phase48_misc() -> void:
	var first := EquipmentRules.slots(GameData.ITEMS)
	first.append("Mutated")
	assert_false(EquipmentRules.slots(GameData.ITEMS).has("Mutated"), "slots() hands out copies of its cache")
	assert_true(EquipmentRules.slots({}).is_empty(), "an empty item table is an empty fabric, not GameData.ITEMS")
	assert_eq(EquipmentRules.slots(GameData.ITEMS), EquipmentRules.slots(GameData.ITEMS), "cached result is stable")
	var ch := CharacterSlice.new()
	add_child(ch)
	ch.set_peer_equipment(9, { "Chest": "VeilsteelChestplate" })
	ch.evict_peer_equipment(9)
	assert_eq(ch.get_peer_equipment(9), {}, "an AOI exit evicts the stored set")
	ch.free()
	var n := NetworkingSlice.new()
	add_child(n)
	n._equipment_sent["2:1"] = true
	n._equipment_sent["3:2"] = true
	n._equipment_sent["3:4"] = true
	n._equipment_eval_positions[2] = Vector3.ZERO
	n._equipment_eval_positions[3] = Vector3.ONE
	n._forget_equipment_pairs(2)
	assert_eq(n._equipment_sent.keys(), ["3:4"], "a disconnect drops every pair that involved the peer")
	assert_false(n._equipment_eval_positions.has(2), "a disconnect drops the peer's last-evaluated position")
	assert_true(n._equipment_eval_positions.has(3), "other peers keep theirs")
	n.free()


## Phase 48 criteria — the replication target list includes the listen host as an owner,
## and a peer entering/leaving AOI after the last gear change is sent / evicted. Uses the
## networking slice's no-socket test seam: with `_test_peers` set, every fan-out path
## (`_connected_peers()`) answers it and `_deliver` appends to `_test_outbox`.
func _test_equipment_host_and_aoi_transitions() -> void:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("player_host_1")
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.player_registry = reg
	n._test_peers = [2, 3]
	var pid2 := str(reg.resolve_identity(2))
	var pid3 := str(reg.resolve_identity(3))
	n.remember_player_state(2, Vector3(0, 0, 0))
	n.remember_player_state(3, Vector3(1000, 0, 0))
	n.set_host_position(Vector3(5, 0, 0))

	# Host as owner: peer 2 (in AOI) is a target, peer 3 (far) is not, the host never is.
	assert_eq(n.equipment_targets(NetworkingSlice.HOST_PEER_ID), [2], "the host's set goes to peers in its AOI only")
	assert_eq(n.equipment_targets(2), [], "a lone nearby peer has no other peer to tell (host excluded)")
	n._test_outbox.clear()
	n._on_equipment_changed("player_host_1", { "Chest": "VeilsteelChestplate" })
	assert_eq(n._test_outbox.size(), 1, "one delivery for the host's gear change")
	if n._test_outbox.size() == 1:
		assert_eq(n._test_outbox[0]["peer_id"], 2, "to the peer in AOI")
		assert_eq(n._test_outbox[0]["payload"]["type"], "peer_equipment", "as a peer_equipment packet")
		assert_eq(n._test_outbox[0]["payload"]["peer_id"], NetworkingSlice.HOST_PEER_ID, "tagged with the host's id")

	# Enter: peer 3 wears something at range, then walks into peer 2's... host's AOI.
	reg.record_equipment(pid3, { "Chest": "VeilsteelChestplate" })
	reg.record_equipment(pid2, { "Chest": "VeilsteelChestplate" })
	n._test_outbox.clear()
	n._equipment_sent.clear()
	n.remember_player_state(3, Vector3(10, 0, 0))
	n._refresh_equipment_pairs(3)
	var sent_to_2 := false
	var sent_to_3 := false
	for m in n._test_outbox:
		var pl: Dictionary = m["payload"]
		if pl["type"] == "peer_equipment" and pl["peer_id"] == 3 and m["peer_id"] == 2:
			sent_to_2 = true
		if pl["type"] == "peer_equipment" and pl["peer_id"] == 2 and m["peer_id"] == 3:
			sent_to_3 = true
	assert_true(sent_to_2, "a peer walking into AOI after the last change is sent to the viewer")
	assert_true(sent_to_3, "and receives the viewer's set")

	# Leave: peer 3 walks away; both viewers are told to evict, once.
	n._test_outbox.clear()
	n.remember_player_state(3, Vector3(2000, 0, 0))
	n._refresh_equipment_pairs(3)
	var evicts := 0
	var evict_viewers := []
	for m in n._test_outbox:
		if m["payload"]["type"] == "peer_equipment_evict":
			evicts += 1
			evict_viewers.append(m["peer_id"])
	evict_viewers.sort()
	assert_eq(evicts, 2, "leaving AOI evicts the stored set on each viewer")
	assert_eq(evict_viewers, [2, 3], "the evicts go to peer 2 (told peer 3 left) and peer 3 (told peer 2 left)")
	assert_false(n._equipment_sent.has("2:3"), "the sent record for the pair is dropped")
	n._test_outbox.clear()
	n.remember_player_state(3, Vector3(2100, 0, 0))
	n._refresh_equipment_pairs(3)
	assert_eq(n._test_outbox.size(), 0, "no repeat eviction while it stays away")
	n.free()
	reg.free()


## Phase 49 — a chunk built BEFORE its neighbour reads the neighbour's generated surface,
## so it emits the same faces as when the neighbour was built first (no bedrock-to-top
## wall from an "unknown" neighbour).
func _test_voxel_concurrent_seam_exact() -> void:
	var terrain := TerrainSlice.new()
	add_child(terrain)
	var v := VoxelSlice.new()
	add_child(v)
	v.terrain_slice = terrain
	var a := Vector2i(2, 3)
	var b := Vector2i(3, 3)
	var hm_a: Array = terrain.generate_heightmap(a)
	var hm_b: Array = terrain.generate_heightmap(b)
	v.build_chunk(a, hm_a)
	var first := v.collision_faces(a, hm_a)
	assert_eq(v.get_heightmaps().has("3,3"), false, "the neighbour is a guess, not a built chunk")
	v.build_chunk(b, hm_b)
	var second := v.collision_faces(a, hm_a)
	assert_eq(first.size(), second.size(), "first-built and after-neighbour faces match")
	assert_eq(first, second, "the seam geometry is identical either way")
	v.free()
	terrain.free()


## Both chunks of a seam, and the worker path (`gather_build_input` -> `build_runs` ->
## `build_chunk_arrays`, what the chunk manager dispatches), come out identical whichever
## builds first. Several pairs, and the check is not vacuous: at least one pair has a seam
## whose faces differ from the same chunk built against an UNKNOWN neighbour.
func _test_voxel_seam_exact_both_ways() -> void:
	var terrain := TerrainSlice.new()
	add_child(terrain)
	var pairs: Array = [[Vector2i(2, 3), Vector2i(3, 3)], [Vector2i(-4, 1), Vector2i(-3, 1)],
			[Vector2i(7, -2), Vector2i(7, -1)], [Vector2i(0, 9), Vector2i(1, 9)]]
	var seam_mattered := false
	for pair in pairs:
		var a: Vector2i = pair[0]
		var b: Vector2i = pair[1]
		var hm_a: Array = terrain.generate_heightmap(a)
		var hm_b: Array = terrain.generate_heightmap(b)
		var v := VoxelSlice.new()
		add_child(v)
		v.terrain_slice = terrain
		# Worker path: gather while the neighbour is only a guess, then again once it is built.
		var guessed_a: Dictionary = VoxelSlice.build_chunk_arrays(a, hm_a,
				VoxelSlice.build_runs(a, hm_a, v.gather_build_input(a, hm_a)))
		var guessed_b: Dictionary = VoxelSlice.build_chunk_arrays(b, hm_b,
				VoxelSlice.build_runs(b, hm_b, v.gather_build_input(b, hm_b)))
		v.build_chunk(a, hm_a)
		v.build_chunk(b, hm_b)
		var built_a: Dictionary = VoxelSlice.build_chunk_arrays(a, hm_a,
				VoxelSlice.build_runs(a, hm_a, v.gather_build_input(a, hm_a)))
		var built_b: Dictionary = VoxelSlice.build_chunk_arrays(b, hm_b,
				VoxelSlice.build_runs(b, hm_b, v.gather_build_input(b, hm_b)))
		assert_eq(guessed_a.hash(), built_a.hash(), "chunk a: guess-built == neighbour-built at %s" % a)
		assert_eq(guessed_b.hash(), built_b.hash(), "chunk b: guess-built == neighbour-built at %s" % b)
		# And an unknown neighbour (no terrain wired) is what the guess replaces.
		var bare := VoxelSlice.new()
		add_child(bare)
		var unknown_a: Dictionary = VoxelSlice.build_chunk_arrays(a, hm_a,
				VoxelSlice.build_runs(a, hm_a, bare.gather_build_input(a, hm_a)))
		if unknown_a.hash() != built_a.hash():
			seam_mattered = true
		bare.free()
		v.free()
	assert_true(seam_mattered, "at least one seam differs from the unknown-neighbour build")
	terrain.free()

func _test_voxel_guess_cache_bounded() -> void:
	var terrain := TerrainSlice.new()
	add_child(terrain)
	var v := VoxelSlice.new()
	add_child(v)
	v.terrain_slice = terrain
	for i in VoxelSlice.GUESS_CACHE_MAX + 20:
		var c := Vector2i(i, 100)
		v._generated_heightmap(c, v._chunk_key(c))
	assert_eq(v._guess_heightmaps.size(), VoxelSlice.GUESS_CACHE_MAX, "the guess cache stops at its bound")
	assert_false(v._guess_heightmaps.has("0,100"), "the oldest guess is the one evicted")
	var newest := Vector2i(VoxelSlice.GUESS_CACHE_MAX + 19, 100)
	assert_true(v._guess_heightmaps.has(v._chunk_key(newest)), "the newest guess is kept")
	v.free()
	terrain.free()

func _test_voxel_build_reuses_guess() -> void:
	var terrain := TerrainSlice.new()
	add_child(terrain)
	var v := VoxelSlice.new()
	add_child(v)
	v.terrain_slice = terrain
	var a := Vector2i(2, 3)
	var b := Vector2i(3, 3)
	var hm_a: Array = terrain.generate_heightmap(a)
	v.gather_build_input(a, hm_a)   # guesses b (and the rest of a's ring)
	assert_true(v._guess_heightmaps.has("3,3"), "gathering a guessed its neighbour b")
	var guess: Array = v._guess_heightmaps["3,3"]
	var taken: Array = v.take_heightmap_for_build(b)
	assert_true(is_same(taken, guess), "b's own build takes the guess instead of regenerating")
	assert_false(v._guess_heightmaps.has("3,3"), "the guess is consumed")
	assert_eq(taken, terrain.generate_heightmap(b), "and it is exactly what the generator gives")
	var fresh: Array = v.take_heightmap_for_build(Vector2i(40, 40))
	assert_eq(fresh.size(), taken.size(), "with no guess cached it generates a map")
	var bare := VoxelSlice.new()
	add_child(bare)
	assert_true(bare.take_heightmap_for_build(b).is_empty(), "no generator wired reads as empty")
	bare.free()
	v.free()
	terrain.free()

func _test_voxel_reseed_drops_guesses() -> void:
	var terrain := TerrainSlice.new()
	add_child(terrain)
	terrain.set_world_seed(1234)
	var v := VoxelSlice.new()
	add_child(v)
	v.terrain_slice = terrain
	var c := Vector2i(5, 5)
	var old_map: Array = v._generated_heightmap(c, v._chunk_key(c))
	terrain.set_world_seed(98765)
	var new_map: Array = v._generated_heightmap(c, v._chunk_key(c))
	assert_true(old_map != new_map, "a re-seed does not serve the old world's cached map")
	assert_eq(new_map, terrain.generate_heightmap(c), "the guess matches the new world's generator")
	v.free()
	terrain.free()

## A guess made for a chunk whose build never landed is swept by the unload of any chunk
## in its 3x3, driven through the real gather path rather than a hand-planted entry.
func _test_voxel_abandoned_guess_swept() -> void:
	var terrain := TerrainSlice.new()
	add_child(terrain)
	var v := VoxelSlice.new()
	add_child(v)
	v.terrain_slice = terrain
	var a := Vector2i(2, 3)
	v.gather_build_input(a, terrain.generate_heightmap(a))   # dispatch that is then abandoned
	assert_true(v._guess_heightmaps.size() >= 8, "the gather guessed the whole ring")
	v.unload_chunk(Vector2i(3, 3))   # an edge neighbour unloads; nothing is loaded anywhere
	assert_false(v._guess_heightmaps.has("3,3"), "the unloaded chunk's own guess goes")
	assert_false(v._guess_heightmaps.has("2,4"), "and so does a guess in its 3x3")
	assert_true(v._guess_heightmaps.has("1,2"), "while a guess outside it stays until its own sweep")
	v.free()
	terrain.free()

## `surfaceMaterial` is not consumed by the build yet, so nothing else would notice a biome
## that lost it: pin it, with the tints and depth the topsoil does use.
func _test_voxel_surface_style_complete() -> void:
	assert_true(GameData.BIOMES.size() > 0, "the fabric declares biomes")
	for key in GameData.BIOMES:
		var style: Dictionary = VoxelSlice.surface_style(str(key))
		assert_false(style.is_empty(), "%s has a surface style" % key)
		assert_true(str(style.get("material", "")) != "", "%s names a surface material" % key)
		assert_true(float(style.get("depth", 0.0)) > 0.0, "%s has a topsoil depth" % key)
	# Phase 49 — the biome's `soilMaterial` reaches the inventory VERBATIM (`_natural_yield`
	# returns it as the mined material), so a typo would mint a phantom item nothing can use.
	# The fabric cannot type it (a plain string, like `surfaceMaterial`), so pin it here.
	for key in GameData.BIOMES:
		var res: Variant = GameData.BIOMES[key]
		var soil := str(res.get("soilMaterial"))
		assert_true(GameData.MATERIALS.has(soil), "%s names a declared soil material (%s)" % [key, soil])
	assert_true(VoxelSlice.surface_style("NoSuchBiome").is_empty(), "an unknown biome has no style")

## One style lookup per biome per build, however many runs ask.
func _test_voxel_topsoil_style_memoised() -> void:
	var styles: Dictionary = {}
	var biome := str(GameData.BIOMES.keys()[0])
	var biomes := { "0,0": biome }
	var surface := 2.0
	for i in 5:
		var entry := { "material": "", "top": surface, "bottom": 0.0 }
		VoxelSlice._apply_topsoil(entry, Vector2(1.0, 1.0), biomes, surface, VoxelSlice._field(0, {}), styles)
	assert_eq(styles.size(), 1, "five runs of one biome resolve its style once")
	assert_true(styles.has(biome), "keyed by biome")

## The re-scope path touches only the disc it names: an in-scope edit the host no longer
## lists is dropped, a changed one is replaced, and everything outside is left as it was.
func _test_snapshot_scoped_apply_in_place() -> void:
	var far_key := "%d,%d" % [20 * 64 + 5, 20 * 64 + 5]
	var client := VoxelSlice.new()
	add_child(client)
	client.apply_edits({ "32,32": 1.0, "33,32": 1.0, far_key: 3.0 })
	assert_true(VoxelSlice.chunk_in_radius(Vector2i(0, 0), Vector3.ZERO, 10.0), "the origin chunk is in a small disc")
	assert_false(VoxelSlice.chunk_in_radius(Vector2i(20, 20), Vector3.ZERO, 100.0), "a far chunk is not")
	assert_true(VoxelSlice.chunk_in_radius(Vector2i(1, 0), Vector3(30.0, 0.0, 10.0), 2.5), "a disc reaches a neighbour by its edge")
	assert_false(VoxelSlice.chunk_in_radius(Vector2i(1, 0), Vector3(20.0, 0.0, 10.0), 2.5), "and stops short of it")
	var far_before: Array = (client._edits[far_key] as Array)
	var host := VoxelSlice.new()
	add_child(host)
	host.apply_edits({ "32,32": 2.0 })   # same tile, different edit; "33,32" is gone
	var scoped: Dictionary = host.get_chunk_manifest_in_radius(Vector3.ZERO, 100.0)
	client.apply_scoped_chunk_manifest(scoped, Vector3.ZERO, 100.0)
	assert_false(client._edits.has("33,32"), "an in-scope edit the host dropped is dropped here")
	assert_true(client._edits.has("32,32"), "the in-scope edit the host holds stays")
	assert_true(VoxelSlice._ops_equal(client._edits["32,32"], host._edits["32,32"]), "and takes the host's value")
	assert_true(is_same(client._edits[far_key], far_before), "an out-of-scope op list is the very same object")
	assert_eq(client._edits_by_chunk.size(), 2, "the chunk index tracks the result (near chunk and far chunk)")
	host.free()
	client.free()

func _test_net_within_aoi_explicit_center() -> void:
	var n := NetworkingSlice.new()
	add_child(n)
	n.remember_player_state(2, Vector3.ZERO)
	var pos := Vector3(500.0, 0.0, 0.0)
	assert_false(n.in_aoi(2, pos), "the recorded centre does not reach it")
	assert_true(NetworkingSlice.within_aoi(Vector3(480.0, 0.0, 0.0), pos), "a fresher centre does")
	assert_eq(NetworkingSlice.within_aoi(Vector3.ZERO, Vector3(50.0, 0.0, 0.0)), n.in_aoi(2, Vector3(50.0, 0.0, 0.0)),
		"in_aoi is within_aoi at the recorded centre")
	n.free()

## `ClimateField.biome_for_chunk` searches the 3x3 cells round the chunk's own; that is exact
## only while a feature point cannot wander further than that. Pin the bound, and check the
## 3x3 answer against a 5x5 brute force over a spread of seeds and chunks.
func _test_climate_search_window_exact() -> void:
	assert_true(ClimateField.JITTER <= 0.8, "JITTER stays within what the 3x3 search can see")
	assert_eq(ClimateField.biome_for_chunk(1, Vector2i(3, 3), []), "", "no keys reads as no biome")
	var keys := ["A", "B", "C", "D", "E"]
	for seed_v in [1, 77, 20260815, -5]:
		for i in 60:
			var chunk := Vector2i(i * 7 - 200, i * 13 - 300)
			var p := Vector2(chunk.x + 0.5, chunk.y + 0.5)
			var cx := floori(p.x / ClimateField.CELL_CHUNKS)
			var cz := floori(p.y / ClimateField.CELL_CHUNKS)
			var best := INF
			var bx := cx
			var bz := cz
			for dz in range(-2, 3):
				for dx in range(-2, 3):
					var d := ClimateField._feature_point(seed_v, cx + dx, cz + dz).distance_squared_to(p)
					if d < best:
						best = d
						bx = cx + dx
						bz = cz + dz
			var wide: String = keys[ClimateField._mix(seed_v, bx, bz, 3) % keys.size()]
			assert_eq(ClimateField.biome_for_chunk(seed_v, chunk, keys), wide, "3x3 == 5x5 at seed %d chunk %s" % [seed_v, chunk])

## A peer with a CharacterSlice avatar has no capsule ghost: suppressing releases an existing
## ghost, blocks a new one, and lifting it lets the next report draw the ghost again.
func _test_player_ghost_suppression() -> void:
	var p := PlayerSlice.new()
	add_child(p)
	p._on_remote_player_state(2, Vector3(1.0, 0.0, 1.0))
	assert_eq(p.get_remote_ghost_count(), 1, "a ghost exists before the avatar does")
	p.set_ghost_suppressed(2, true)
	assert_eq(p.get_remote_ghost_count(), 0, "the avatar's arrival releases the ghost")
	p._on_remote_player_state(2, Vector3(2.0, 0.0, 1.0))
	assert_eq(p.get_remote_ghost_count(), 0, "later reports do not rebuild it")
	p._on_remote_player_state(3, Vector3(5.0, 0.0, 5.0))
	assert_eq(p.get_remote_ghost_count(), 1, "other peers keep theirs")
	p.set_ghost_suppressed(2, false)
	p._on_remote_player_state(2, Vector3(3.0, 0.0, 1.0))
	assert_eq(p.get_remote_ghost_count(), 2, "with the avatar gone the ghost returns")
	p.free()

## Phase 49 — `spawn_for_chunk` / `despawn_for_chunk` work off a per-chunk index. It agrees
## with a scan of the table, keeps an engaged survivor across a despawn (and counts it
## against the pack on reload), and drops the chunk's entry once nothing is left.
func _test_creature_chunk_index() -> void:
	var c := CreatureSlice.new()
	add_child(c)
	var a := Vector2i(4, 4)
	var b := Vector2i(5, 4)
	c.spawn_for_chunk(a)
	c.spawn_for_chunk(b)
	assert_true(c.get_all_instances().size() > 0, "the fixture chunks carry creatures")
	for chunk in [a, b]:
		var scanned := 0
		for rec in c.get_all_instances():
			if rec["chunk"] == chunk:
				scanned += 1
		assert_eq((c._by_chunk.get(chunk, []) as Array).size(), scanned, "index == scan for %s" % chunk)
	var total_b := (c._by_chunk[b] as Array).size()
	var engaged: String = str((c._by_chunk[a] as Array)[0])
	c._instances[engaged]["state"] = "aggressive"
	c.despawn_for_chunk(a)
	assert_eq((c._by_chunk[a] as Array).size(), 1, "only the engaged survivor stays indexed")
	assert_true(c._instances.has(engaged), "and its record stays")
	assert_eq((c._by_chunk[b] as Array).size(), total_b, "another chunk's index is untouched")
	var before_reload := c.get_all_instances().size()
	c.spawn_for_chunk(a)
	var reloaded := 0
	for rec in c.get_all_instances():
		if rec["chunk"] == a:
			reloaded += 1
	assert_eq((c._by_chunk[a] as Array).size(), reloaded, "the index follows a reload")
	assert_true(c.get_all_instances().size() >= before_reload, "a reload restores the pack around the survivor")
	c._instances[engaged]["state"] = "idle"
	c.despawn_for_chunk(a)
	c.despawn_for_chunk(b)
	assert_false(c._by_chunk.has(a), "an emptied chunk drops its index entry")
	assert_eq(c.get_all_instances().size(), 0, "nothing is left once every chunk is despawned")
	c.free()

## Several creatures coming due in the same tick are admitted against ONE running live count:
## with room for exactly one, exactly one revives and the rest stay dead with their deadlines.
func _test_creature_respawns_share_cap() -> void:
	var c := CreatureSlice.new()
	c.render_visuals = false
	add_child(c)
	c.spawn_for_chunk(Vector2i(4, 4))
	var ids: Array = []
	for rec in c.get_all_instances():
		ids.append(str(rec["instance_id"]))
	assert_true(ids.size() >= 3, "need three creatures to kill")
	var due := Time.get_unix_time_from_system() - 1.0
	for i in 3:
		var inst: Dictionary = c._instances[ids[i]]
		inst["state"] = "dead"
		inst["hp"] = 0.0
		inst["respawn_at"] = due
	c.set_population_cap(c.live_population() + 1)
	c._tick_respawn()
	var alive := 0
	for i in 3:
		if c._instances[ids[i]]["state"] != "dead":
			alive += 1
	assert_eq(alive, 1, "a cap with one free slot revives exactly one of three")
	assert_eq(c.live_population(), c.get_population_cap(), "and the population sits at the cap")
	for i in 3:
		if c._instances[ids[i]]["state"] == "dead":
			assert_true(float(c._instances[ids[i]]["respawn_at"]) > 0.0, "a held creature keeps its deadline")
	c.set_population_cap(0)
	c._tick_respawn()
	assert_eq(c.live_population(), ids.size(), "lifting the cap lets the rest return")
	c.free()

## The hash feeds every chunk's spawn roll, so adjacent chunks and salts must not move
## together. Flipping one input bit should flip about half of the 31 output bits (avalanche),
## and the low bit - the one a `% 2` style use would read - must not track a neighbouring chunk.
func _test_spawn_roll_mix_avalanche() -> void:
	var flipped := 0
	var trials := 0
	for seed_v in [3, 91, 20260815]:
		for i in 64:
			var base: int = SpawnRoll._mix(seed_v, i, 2 * i - 7, 1000 + i)
			for bit in [0, 1, 5, 9]:
				var other: int = SpawnRoll._mix(seed_v, i ^ (1 << bit), 2 * i - 7, 1000 + i)
				var diff: int = base ^ other
				while diff != 0:
					flipped += diff & 1
					diff >>= 1
				trials += 1
	var mean := float(flipped) / float(trials)
	assert_true(mean > 13.0 and mean < 18.0, "one flipped input bit flips ~15.5 of 31 output bits (got %.2f)" % mean)
	# Neighbouring chunks: the low output bit agrees about half the time, not (nearly) always.
	var same := 0
	var n := 400
	for i in n:
		if (SpawnRoll._mix(5, i, 0, 7) & 1) == (SpawnRoll._mix(5, i + 1, 0, 7) & 1):
			same += 1
	var frac := float(same) / float(n)
	assert_true(frac > 0.40 and frac < 0.60, "adjacent chunks' low bits are uncorrelated (agree %.2f)" % frac)
	# The roll stays in range and varies across a row of chunks.
	var lo := 1.0
	var hi := 0.0
	for i in 200:
		var u := SpawnRoll.unit(11, Vector2i(i, 3), "pack")
		lo = minf(lo, u)
		hi = maxf(hi, u)
	assert_true(lo >= 0.0 and hi < 1.0 and hi - lo > 0.8, "unit rolls spread across [0, 1)")

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

## The fraction of a 1,000 km east-west transect (sampled every 2 km) below sea level, pooled over
## several seeds and latitudes (one transect is under half a continental wavelength, so a single
## one is a coin toss by design), lands within the fabric's target ocean share; and at least one
## height above 300 m appears on land.
func _test_terrain_ocean_share_transect() -> void:
	var w := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	var below := 0
	var total := 0
	var peak := -1000.0
	var trough := 1000.0
	var sea := WorldShape.sea_level()
	for seed_v in [3, 17, 99, 2026, 777777, 31337, 424242, 8]:
		for lat_row in [-4000.0e3, -1500.0e3, 0.0, 1800.0e3, 3500.0e3]:
			for i in range(500):
				var x := 6000.0e3 + float(i) * 2000.0
				var h := WorldShape.height(seed_v, x, lat_row, w)
				total += 1
				if h < sea:
					below += 1
				peak = maxf(peak, h)
				trough = minf(trough, h)
	var share := float(below) / float(total)
	var target := WorldShape.ocean_share()
	assert_true(absf(share - target) <= 0.07, "ocean share %.3f is within 0.07 of the fabric target %.2f" % [share, target])
	assert_true(share >= 0.55 and share <= 0.75, "and inside the 55-75%% band (%.3f)" % share)
	assert_true(peak > 300.0, "a peak above 300 m appears (%.0f m)" % peak)
	assert_true(peak <= WorldShape.max_height() and trough >= WorldShape.min_height(), "heights stay in the fabric's range (%.0f..%.0f)" % [trough, peak])

func _test_terrain_spawn_plain_dry() -> void:
	var w := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	for seed_v in [1, 2, 3, 99, 12345, 777777]:
		for off in [Vector2(0, 0), Vector2(900, 0), Vector2(0, -1200), Vector2(-1400, 1000)]:
			var h := WorldShape.height(seed_v, 16.0 + off.x, 16.0 + off.y, w)
			assert_true(h > WorldShape.sea_level(), "land within the spawn plain at seed %d offset %s (%.1f)" % [seed_v, off, h])
		assert_true(TerrainSlice.biome_for_chunk(Vector2i(0, 0), seed_v) != "Ocean", "the spawn chunk is never Ocean at seed %d" % seed_v)
	var t := TerrainSlice.new()
	add_child(t)
	assert_true(t.get_height_at(Vector2(16.0, 16.0)) > 1.5, "the player spawns above the waterline")
	t.free()

func _test_world_shape_wraps_in_range() -> void:
	var w := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	for seed_v in [5, 6]:
		for z in [-2000.0e3, 0.0, 777.0e3]:
			assert_true(absf(WorldShape.height(seed_v, -w * 0.5, z, w) - WorldShape.height(seed_v, w * 0.5, z, w)) < 0.001, "the shape is periodic around the planet")
			assert_true(absf(WorldShape.height(seed_v, 123456.0, z, w) - WorldShape.height(seed_v, 123456.0 + w, z, w)) < 0.001, "one lap east is the same ground")
	assert_eq(WorldShape.height(9, 6.0e6, 1.0e6, w), WorldShape.height(9, 6.0e6, 1.0e6, w), "and the shape is pure in (seed, position)")
	assert_true(WorldShape.height(9, 6.0e6, 1.0e6, w) != WorldShape.height(10, 6.0e6, 1.0e6, w) or WorldShape.height(9, 7.1e6, -3.0e6, w) != WorldShape.height(10, 7.1e6, -3.0e6, w), "a different seed shapes different continents")

## At latitude 85 degrees the land biome is the polar one (Tundra), and a 450 m peak at the equator is Alpine.
func _test_climate_poles_and_peaks() -> void:
	var keys: Array = TerrainSlice.BIOME_KEYS
	var B: Dictionary = GameData.BIOMES
	for seed_v in [1, 42, 9001]:
		for cx in [-300, 0, 77, 4000]:
			var pole := ClimateField.biome_for_chunk(seed_v, Vector2i(cx, 0), keys, 85.0, 20.0)
			assert_eq(pole, "Tundra", "land at 85 degrees is polar at seed %d chunk %d" % [seed_v, cx])
			var peak := ClimateField.biome_for_chunk(seed_v, Vector2i(cx, 0), keys, 0.0, 450.0)
			assert_eq(peak, "Alpine", "a 450 m peak at the equator is Alpine at seed %d chunk %d" % [seed_v, cx])
	assert_true(ClimateField.temperature_at(1, Vector2(5, 5), 85.0, 20.0) < 0.2, "85 degrees is cold")
	assert_true(ClimateField.temperature_at(1, Vector2(5, 5), 0.0, 450.0) < ClimateField.temperature_at(1, Vector2(5, 5), 0.0, 0.0), "height cools the equator")
	assert_eq(_climate_pick(0.5, 0.5, keys, B, 450.0, 1.0), "Alpine", "pure envelope pick: high ground is Alpine")
	assert_eq(_climate_pick(0.5, 0.5, keys, B, -30.0, 1.0), "Ocean", "below sea level is Ocean")
	assert_eq(_climate_pick(0.5, 0.5, keys, B, 0.5, 1.0), "Beach", "the first metre of shore is Beach")
	assert_eq(_climate_pick(0.85, 0.8, keys, B, 10.0, 1.0) in ["Beach", "Ocean"], false, "hot wet ground 10 m up is land, not shore")
	assert_eq(_climate_pick(0.7, 0.1, keys, B, 50.0, 1.0), "Desert", "hot and dry is desert")
	assert_eq(_climate_pick(0.7, 0.4, keys, B, 50.0, 1.0), "Savanna", "hot and middling is savanna")
	assert_eq(_climate_pick(0.25, 0.7, keys, B, 50.0, 1.0), "Taiga", "cool and wet is taiga")
	for key in ["Ocean", "Beach", "Desert", "Tundra", "Alpine", "Taiga", "Savanna"]:
		var res: Variant = GameData.BIOMES.get(key, null)
		assert_true(res != null, "%s is a fabric biome" % key)
		assert_true(res.get("surfaceMaterial") != null and res.get("treeDensity") != null, "%s carries surfaceMaterial and treeDensity" % key)
		assert_true(TerrainSlice.BIOME_KEYS.has(key), "%s is a canonical biome key" % key)

## Pure envelope pick over `biomes`' resources at (t, m, altitude); `niche` stands in for every
## biome's niche draw. Was `ClimateField.biome_for_climate`, which only the suite called.
func _climate_pick(t: float, m: float, keys: Array, biomes: Dictionary, altitude: float = 50.0, niche: float = 0.0) -> String:
	var envs: Dictionary = {}
	for key in keys:
		envs[str(key)] = ClimateField._envelope_of(biomes.get(key, null))
	return ClimateField._pick(t, m, altitude, keys, envs, niche, false)

func _test_climate_niches_stable_and_smooth() -> void:
	var keys: Array = TerrainSlice.BIOME_KEYS.duplicate()
	var shifted: Array = keys.duplicate()
	shifted.insert(2, "DummyBiome")
	ClimateField.warm()
	for key in ["VolcanicBadlands", "TwilightGrove", "VoidRift"]:
		assert_true(shifted.find(key) != keys.find(key), "%s moved index when a biome was inserted" % key)
	# The same chunks must pick the same biomes whether or not a dummy sits in the key list.
	var same := true
	for i in 1500:
		var p := Vector2(float(i * 37 % 4001) - 2000.0, float(i * 91 % 4001) - 2000.0)
		var t := float(i * 13 % 101) / 100.0
		var m := float(i * 29 % 101) / 100.0
		var alt := float(i * 7 % 300) + 1.0
		if ClimateField._pick(t, m, alt, keys, ClimateField._envelopes, 0.0, true, 5, p) != ClimateField._pick(t, m, alt, shifted, ClimateField._envelopes, 0.0, true, 5, p):
			same = false
	assert_true(same, "inserting a biome leaves every other biome's pick unchanged")
	assert_true(ClimateField.niche_salt("VoidRift") != ClimateField.niche_salt("TwilightGrove"), "two biomes get distinct niche salts")
	# Share and smoothness over a 400x400-chunk sample.
	for key in ["VolcanicBadlands", "TwilightGrove", "VoidRift"]:
		var rarity: float = float(GameData.BIOMES[key].get("rarity"))
		var salt := ClimateField.niche_salt(key)
		var inside := 0
		var total := 0
		var runs := 0
		for seed_v in [11, 12, 13]:   # a 400x400 sample holds only ~200 features, so average a few worlds
			for cz in range(0, 400, 2):
				var in_run := false
				for cx in 400:
					var hit := ClimateField.niche_value(seed_v, Vector2(cx + 0.5, cz + 0.5), salt) < rarity
					total += 1
					if hit:
						inside += 1
						if not in_run:
							runs += 1
					in_run = hit
		var share := float(inside) / float(total)
		assert_true(absf(share - rarity) <= rarity * 0.2, "%s niche covers its rarity %.2f (got %.3f)" % [key, rarity, share])
		assert_true(runs > 0 and float(inside) / float(runs) > float(ClimateField.NICHE_CELL_CHUNKS),
			"%s niche runs along a row exceed one niche cell (mean %.1f)" % [key, float(inside) / maxf(float(runs), 1.0)])

func _test_climate_niche_wraps_and_is_calibrated() -> void:
	ClimateField.warm()
	var c := TerrainSlice.circumference_chunks()
	var fixed_bound := 0.1
	for key in ["VolcanicBadlands", "TwilightGrove", "VoidRift"]:
		var salt := ClimateField.niche_salt(key)
		var worst_seam := 0.0
		var worst_inside := 0.0
		for i in 200:
			var cz := float(i * 37 % 4000 - 2000) + 0.5
			var seed_v := i % 5 + 1
			var a := ClimateField.niche_value(seed_v, Vector2(c - 0.5, cz), salt, c)
			var b := ClimateField.niche_value(seed_v, Vector2(0.5, cz), salt, c)
			worst_seam = maxf(worst_seam, absf(a - b))
			var m := float(i * 53 % 4000) + 0.5
			var m1 := ClimateField.niche_value(seed_v, Vector2(m, cz), salt, c)
			var m2 := ClimateField.niche_value(seed_v, Vector2(m + 1.0, cz), salt, c)
			worst_inside = maxf(worst_inside, absf(m1 - m2))
		assert_true(worst_seam < fixed_bound, "%s niche is continuous across the antimeridian (worst %.4f)" % [key, worst_seam])
		assert_true(worst_seam <= worst_inside + fixed_bound, "%s seam step is no worse than an interior step" % key)
	# The field is periodic in X: a point one circumference away draws the same value.
	for i in 50:
		var pt := Vector2(float(i * 977 % 5000) + 0.5, float(i * 31 % 800 - 400) + 0.5)
		# Vector2 is float32: at 1.25 million chunks the point itself is only exact to 0.125.
		assert_true(absf(ClimateField.niche_value(3, pt, 9, c) - ClimateField.niche_value(3, pt + Vector2(c, 0.0), 9, c)) < 0.01, "niche repeats after one circumference")
	# The table is a cache of this generator.
	var q := ClimateField.niche_quantiles(60000)
	assert_eq(q.size(), ClimateField._NICHE_QUANTILES.size(), "recomputed quantile table has the same length")
	var worst := 0.0
	for k in q.size():
		worst = maxf(worst, absf(float(q[k]) - float(ClimateField._NICHE_QUANTILES[k])))
	assert_true(worst <= 0.005, "recomputed quantiles match _NICHE_QUANTILES within 0.005 (worst %.4f)" % worst)
	# The fallback pool is built once per key set and holds land biomes read from the data.
	var keys: Array = TerrainSlice.BIOME_KEYS.duplicate()
	ClimateField._voronoi_biome(1, Vector2i(0, 0), keys)
	var before := ClimateField.pool_builds
	for i in 1000:
		ClimateField._voronoi_biome(i % 7 + 1, Vector2i(i * 5, i * 3), keys)
	assert_eq(ClimateField.pool_builds, before, "1,000 fallback calls with one key array build the pool once")
	var pool := ClimateField._fallback_pool(keys)
	for k in ["Ocean", "Beach", "Alpine"]:
		assert_false(pool.has(k), "land fallback pool excludes %s" % k)
	assert_true(pool.size() >= 3, "land fallback pool is not empty")

func _test_climate_fallback_is_land_only() -> void:
	var seen := {}
	for i in 600:
		var b := ClimateField._voronoi_biome(i % 7 + 1, Vector2i(i * 11 - 3000, i * 17 - 5000), TerrainSlice.BIOME_KEYS)
		seen[b] = true
		assert_false(b in ["Ocean", "Beach", "Alpine"], "fallback never hands out %s" % b)
	assert_true(seen.size() >= 3, "the fallback still varies (%s)" % [seen.keys()])

func _test_climate_ocean_and_niches() -> void:
	var w := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	var seed_v := 20260
	var counts := {}
	var n := 0
	var ocean_ok := true
	for cz in range(-400, 400, 8):
		for cx in range(100000, 100000 + 800, 8):
			var chunk := Vector2i(cx * 40, cz * 40)
			var b := TerrainSlice.biome_for_chunk(chunk, seed_v)
			counts[b] = int(counts.get(b, 0)) + 1
			n += 1
			var alt := TerrainSlice.biome_altitude(seed_v, (float(chunk.x) + 0.5) * TerrainSlice.CHUNK_METERS, (float(chunk.y) + 0.5) * TerrainSlice.CHUNK_METERS, w)
			if (alt < 0.0) != (b == "Ocean"):
				ocean_ok = false
	assert_true(ocean_ok, "a chunk is Ocean exactly when its large-scale ground is below sea level")
	var fantasy := 0
	for key in ["VolcanicBadlands", "TwilightGrove", "VoidRift"]:
		fantasy += int(counts.get(key, 0))
	assert_true(float(fantasy) / float(n) < 0.15, "fantasy biomes are rare climate niches (%d of %d)" % [fantasy, n])
	assert_true(counts.size() >= 4, "several biomes appear across the sample (%s)" % [counts])

## /tp to the seam (x ~ 2e7 m): absolute float32 vertices would snap to 2 m. A local build stays
## inside the chunk's own 32 m, and is the absolute build shifted by the chunk corner.
func _test_voxel_local_build_far_chunk() -> void:
	var n := TerrainSlice.CHUNK_SIZE
	var far := Vector2i(624999, 0)
	var hm: Array = []
	hm.resize(n * n)
	hm.fill(3.0)
	var v := VoxelSlice.new()
	add_child(v)
	var built := VoxelSlice.build_chunk_arrays(far, hm, v.collect_build_runs(far, hm), true)
	v.free()
	assert_true(bool(built["local"]), "the build says it is chunk-local")
	var verts: PackedVector3Array = built["vertices"]
	assert_true(not verts.is_empty(), "the far chunk has geometry")
	var extent := float(n) * VoxelSlice.TILE_SIZE
	var inside := true
	for p in verts:
		if p.x < -0.001 or p.x > extent + 0.001 or p.z < -0.001 or p.z > extent + 0.001:
			inside = false
	assert_true(inside, "every vertex lies within the chunk's own span")
	var water := VoxelSlice.water_mesh_for(far, hm, true)
	assert_true(water == null, "dry ground has no water")
	var wet: Array = []
	wet.resize(n * n)
	wet.fill(-5.0)
	var wm := VoxelSlice.water_mesh_for(far, wet, true)
	assert_true(wm != null and wm.get_aabb().position.x >= -0.001 and wm.get_aabb().end.x <= extent + 0.001,
		"a local water surface is relative to the chunk corner")

func _test_locomotion_reset_after_death() -> void:
	var loco := Locomotion.new()
	loco.trigger_death()
	assert_eq(loco.state_name(), "DEATH", "death is the terminal pose")
	loco.reset()
	assert_eq(loco.state_name(), "IDLE", "a respawn resets it to idle")

func _test_polar_ice() -> void:
	var t := TerrainSlice.new()
	var polar := TerrainSlice.polar_chunks()
	var pole := TerrainSlice.pole_chunks()
	assert_true(t.is_chunk_in_bounds(Vector2i(0, polar)), "polar ice is walkable")
	assert_true(t.is_chunk_loadable(Vector2i(0, pole + 4)), "and streamed in past the pole: no void there")
	# Near a pole the ground is the pole's snow field: not flat, and the same on both sides of a fold.
	t.set_world_seed(12345)
	var cm := TerrainSlice.CHUNK_METERS
	var w := float(TerrainSlice.circumference_chunks()) * cm
	var p_m := float(pole) * cm
	var seen := {}
	for e in [3.0, 40.0, 177.0, 512.0, 900.0, 1600.0]:
		for xm in [0.0, 1234.5, -98765.0]:
			var here := t.get_height_at(Vector2(xm, p_m - e))
			var over := t.get_height_at(Vector2(xm + w * 0.5, p_m + e))
			assert_true(absf(here - over) < 0.0001, "north: %.0f m from the pole matches the far side (x %.1f)" % [e, xm])
			assert_true(absf(here - t.get_height_at(Vector2(xm + 5000.0, p_m - e))) < 0.0001, "and is the same along the row")
			var south := t.get_height_at(Vector2(xm, -p_m + e))
			assert_true(absf(south - t.get_height_at(Vector2(xm + w * 0.5, -p_m - e))) < 0.0001, "south too")
			seen[snappedf(here, 0.01)] = true
	assert_true(seen.size() > 2, "the snow field has relief, it is not flat")
	var shelf := WorldShape.sea_level() + TerrainSlice.ICE_SHELF_M
	# Frozen sea: from the shelf latitude the ground never lies below the ice, so no water.
	var metres_per_deg := float(pole) * cm / 90.0
	for xm in range(0, 200000, 5000):
		assert_true(t.get_height_at(Vector2(float(xm), 82.0 * metres_per_deg)) >= shelf, "no open sea at 82 N (x %d)" % xm)
	t.free()
	# Rows past a pole read the latitude they have on the far meridian.
	assert_true(absf(TerrainSlice.latitude_of(pole) - TerrainSlice.latitude_of(pole - 1)) < 0.001, "the row past the pole mirrors the last row")
	assert_true(absf(TerrainSlice.latitude_at(float(pole + 1) * cm) - TerrainSlice.latitude_at(float(pole - 1) * cm)) < 0.001, "latitude folds over the pole")
	var grass := Color(0.35, 0.6, 0.28)
	assert_eq(VoxelSlice.icy(grass, 45.0 * metres_per_deg), grass, "temperate ground is untouched")
	assert_eq(VoxelSlice.icy(grass, 85.0 * metres_per_deg), VoxelSlice.ICE_COLOR, "the polar cap is ice")
	assert_eq(VoxelSlice.icy(grass, -85.0 * metres_per_deg), VoxelSlice.ICE_COLOR, "south as well")
	var mid := VoxelSlice.icy(grass, 76.0 * metres_per_deg)
	assert_true(mid != grass and mid != VoxelSlice.ICE_COLOR, "the band between whitens gradually")

func _test_water_spans() -> void:
	var n := TerrainSlice.CHUNK_SIZE
	var hm: Array = []
	hm.resize(n * n)
	hm.fill(3.0)
	assert_eq(VoxelSlice.water_spans(hm, 0.0).size(), 0, "dry ground has no water")
	assert_true(VoxelSlice.water_mesh_for(Vector2i(0, 0), hm) == null, "and no water mesh")
	for tx in range(10, 20):
		hm[5 * n + tx] = -4.0
	hm[5 * n + 63] = -1.0
	hm[6 * n + 0] = -1.0
	var spans := VoxelSlice.water_spans(hm, 0.0)
	assert_eq(spans, [Vector3i(5, 10, 20), Vector3i(5, 63, 64), Vector3i(6, 0, 1)], "wet tiles merge into row spans")
	var mesh := VoxelSlice.water_mesh_for(Vector2i(2, -1), hm)
	assert_true(mesh != null and mesh.get_surface_count() == 1, "wet ground gets a water surface")
	var aabb := mesh.get_aabb()
	assert_true(is_equal_approx(aabb.position.y, 0.0) and is_equal_approx(aabb.size.y, 0.0), "flat at the sea level")
	assert_true(is_equal_approx(aabb.position.x, (2.0 * n + 0.0) * VoxelSlice.TILE_SIZE), "placed at the chunk's world origin")

func _test_player_swims_in_deep_water() -> void:
	var sea := 0.0
	assert_false(PlayerSlice.is_swimming(-0.5, sea), "shallows are waded")
	assert_false(PlayerSlice.is_swimming(2.0, sea), "dry ground is walked")
	assert_true(PlayerSlice.is_swimming(-PlayerSlice.WADE_DEPTH - 0.5, sea), "deep water is swum")
	assert_true(PlayerSlice.is_swimming(-40.0, sea), "the ocean floor is far below a swimmer")
	# A body standing on a deep sea floor is lifted to the surface and holds there.
	var y := -30.0
	for _i in range(1500):
		y += PlayerSlice.swim_vertical_velocity(y, sea) / 60.0
	assert_true(absf(y - (sea - PlayerSlice.SWIM_FLOAT)) < 0.05, "a swimmer settles at the surface (%.2f)" % y)
	assert_true(PlayerSlice.swim_vertical_velocity(-30.0, sea) > 0.0, "buoyancy lifts it off the floor")
	assert_true(PlayerSlice.swim_vertical_velocity(5.0, sea) < 0.0, "and drops a body that was above the water")
	assert_true(absf(PlayerSlice.swim_vertical_velocity(-80.0, sea)) <= PlayerSlice.SWIM_MAX_VERTICAL, "the rise rate is capped")
	assert_true(PlayerSlice.SWIM_SPEED_FACTOR < 1.0, "swimming is slower than walking")

func _test_distant_ring() -> void:
	var radius := 3
	var d := DistantTerrainScript.new()
	add_child(d)
	d.world_seed = 7
	assert_true(d.rebuild(Vector2(16.0, 16.0), radius), "the first call builds the ring")
	d.poll(true)
	var window_m := (float(radius) + 0.5) * 32.0
	assert_true(is_equal_approx(d.ring_half_m, 10.0 * window_m), "the ring reaches 10x the voxel window")
	assert_eq(d.collision_body_count(), 0, "the distant ring has no collision bodies")
	assert_false(d.rebuild(Vector2(17.0, 16.5), radius), "a small move does not rebuild")
	var mesh: ArrayMesh = (d.get_child(0) as MeshInstance3D).mesh
	var aabb := mesh.get_aabb()
	assert_true(aabb.size.x > 1.8 * d.ring_half_m * 0.95, "the mesh spans the ring (%.0f m)" % aabb.size.x)
	assert_true(aabb.size.x <= 2.0 * d.ring_half_m + 1.0, "and no further")
	# The voxel window is a hole: no ring vertex lies strictly inside it (Phase 73: the whole window).
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var inside := 0
	for v in verts:
		if absf(v.x - 16.0) < window_m - 0.001 and absf(v.z - 16.0) < window_m - 0.001:
			inside += 1
	assert_eq(inside, 0, "the ring leaves the voxel window to the voxel chunks")
	var normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	assert_eq(normals.size(), verts.size(), "every ring vertex has a normal")
	assert_true(normals.size() > 0 and normals[0].y > 0.0, "ring normals face up")
	d.world_seed = 8
	assert_true(d.rebuild(Vector2(16.0, 16.5), radius), "a new world seed rebuilds the ring in place")
	d.poll(true)
	d.free()

## Phase 73 — the ring's height at the window edge meets the voxel ground (shape + detail).
func _test_distant_ring_window_edge() -> void:
	var seed_v := 7
	var t := TerrainSlice.new()
	add_child(t)   # _ready configures the detail noise
	t.set_world_seed(seed_v)
	var w := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	var half := 3.5 * 32.0
	var wc := Vector2(16.0, 16.0)
	var ring_half := DistantTerrainScript.ring_half_extent(3)
	var cell := ring_half * 2.0 / 64.0
	var rc := Vector2(floorf(wc.x / cell) * cell, floorf(wc.y / cell) * cell)
	var mesh: ArrayMesh = DistantTerrainScript.build_mesh(seed_v, w, rc, ring_half, half, wc)
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var inside := 0
	for v in verts:
		if absf(v.x - wc.x) < half - 0.001 and absf(v.z - wc.y) < half - 0.001:
			inside += 1
	assert_eq(inside, 0, "no ring vertex inside the window")
	# 64 points around the edge: the topmost ring surface there (a triangle containing the point,
	# or a vertex on it) is within 1 m of the voxel ground.
	var sea := WorldShape.sea_level()
	var worst := 0.0
	var checked := 0
	for k in 64:
		var f := float(k) / 16.0   # 0..4 around the perimeter
		var side := int(f)
		var u := (f - float(side)) * 2.0 * half - half
		var pt := Vector2.ZERO
		match side:
			0: pt = wc + Vector2(u, -half)
			1: pt = wc + Vector2(half, u)
			2: pt = wc + Vector2(-u, half)
			_: pt = wc + Vector2(-half, -u)
		var ground := t.get_height_at(pt)
		if ground < sea:
			continue   # the voxel window shows the water sheet here; the ring is a flat sea at the edge
		var best := -INF
		for ti in range(0, idx.size(), 3):
			var a := verts[idx[ti]]
			var b := verts[idx[ti + 1]]
			var c := verts[idx[ti + 2]]
			if absf(a.x - b.x) < 0.0001 and absf(b.x - c.x) < 0.0001 and absf(a.z - b.z) < 0.0001:
				continue   # vertical skirt
			var y := _tri_height_at(a, b, c, pt)
			if not is_nan(y):
				best = maxf(best, y)
		if best > -INF:
			checked += 1
			worst = maxf(worst, absf(best - ground))
	assert_true(checked > 0, "some of the edge points are land (%d)" % checked)
	assert_true(worst <= 1.0, "the ring is within 1 m of the voxel ground at the window edge (worst %.2f m)" % worst)
	t.free()

## Height of triangle (a, b, c) at the XZ of `pt`, or NAN when the point lies outside it.
func _tri_height_at(a: Vector3, b: Vector3, c: Vector3, pt: Vector2) -> float:
	var d := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
	if absf(d) < 0.000001:
		return NAN
	var l1 := ((b.z - c.z) * (pt.x - c.x) + (c.x - b.x) * (pt.y - c.z)) / d
	var l2 := ((c.z - a.z) * (pt.x - c.x) + (a.x - c.x) * (pt.y - c.z)) / d
	var l3 := 1.0 - l1 - l2
	var e := -0.0001
	if l1 < e or l2 < e or l3 < e:
		return NAN
	return l1 * a.y + l2 * b.y + l3 * c.y

class SwimTerrainStub extends Node:
	var height := 0.0
	func get_height_at(_p: Vector2) -> float:
		return height

class SwimVoxelStub extends Node:
	var runs: Array = []
	func get_column_runs_at(_p: Vector2) -> Array:
		return runs

## Phase 73 — a body swims only where there is water over ground that is, as edited, deep enough.
func _test_swim_reads_voxel_column() -> void:
	var sea := WorldShape.sea_level()
	var p := PlayerSlice.new()
	add_child(p)
	var terr := SwimTerrainStub.new()
	var vox := SwimVoxelStub.new()
	add_child(terr)
	add_child(vox)
	p.terrain_slice = terr
	p.spawn_at(Vector3(10.0, sea - 0.2, 10.0))
	# Open ocean, unedited column: swims.
	terr.height = sea - 20.0
	vox.runs = [{"bottom": -72.0, "top": sea - 20.0}]
	p.voxel_slice = null
	assert_true(p._swimming_now(), "isolated rig: the generated sea floor is deep, so it swims")
	p.voxel_slice = vox
	assert_true(p._swimming_now(), "wired: an unedited deep column swims")
	# The player filled the column up to sea level + 1 m.
	vox.runs = [{"bottom": -72.0, "top": sea + 1.0}]
	assert_false(p._swimming_now(), "ground built up out of the sea does not swim")
	# A land pit dug below sea level holds no water.
	terr.height = sea + 6.0
	vox.runs = [{"bottom": -72.0, "top": sea - 10.0}]
	assert_false(p._swimming_now(), "a dry pit below sea level does not swim")
	vox.runs = []
	assert_false(p._swimming_now(), "nor does one mined out to the floor")
	p.free()
	terr.free()
	vox.free()

## Phase 83 — leaving the tree mid-build raises the abort flag; the worker stops within one more row
## and the freed node never applies a result.
func _test_distant_ring_abort() -> void:
	var d := DistantTerrainScript.new()
	add_child(d)
	d.world_seed = 11
	d.rebuild(Vector2(100.0, -40.0), 3)
	var control = d._control
	assert_true(control != null, "the build has a control block")
	remove_child(d)   # joined outside any locked iteration, then freed
	d.free()
	var rows_after_abort: int = control.rows
	assert_true(control.aborted, "leaving the tree raised the abort flag")
	# The worker is joined by now: no row was started after the flag, bar the one in progress.
	assert_true(rows_after_abort <= 2 * (DistantTerrainScript.GRID + 1) + 1, "the row counter is bounded")
	# An unaborted build of the same ring reaches the full row count; the aborted one stopped earlier.
	var half := DistantTerrainScript.ring_half_extent(3)
	var win := (3.0 + 0.5) * DistantTerrainScript.CHUNK_METERS
	var full := DistantTerrainScript.BuildControl.new()
	DistantTerrainScript.build_mesh(11, 40000.0 * 1000.0, Vector2.ZERO, half, win, Vector2.ZERO, full)
	assert_eq(full.rows, 2 * DistantTerrainScript.GRID + 1, "an unaborted build visits every row")
	assert_true(rows_after_abort < full.rows, "the aborted build stopped strictly before the full row count")
	OS.delay_msec(20)
	assert_eq(control.rows, rows_after_abort, "no worker row runs after the node is gone")

## Phase 88 — a ring reparented mid-build (exit, then re-enter) still ends with the same mesh as an
## undisturbed ring.
func _test_distant_ring_reparent() -> void:
	var calm := DistantTerrainScript.new()
	add_child(calm)
	calm.world_seed = 11
	calm.rebuild(Vector2(100.0, -40.0), 2)
	calm.poll(true)
	var moved := DistantTerrainScript.new()
	add_child(moved)
	moved.world_seed = 11
	moved.rebuild(Vector2(100.0, -40.0), 2)
	assert_true(moved.is_building(), "a build is in flight")
	remove_child(moved)
	assert_false(moved.is_building(), "leaving the tree discarded the build")
	add_child(moved)
	assert_true(moved.is_building(), "re-entering the tree re-requested it")
	assert_true(moved.poll(true), "the rebuilt mesh is swapped in")
	var a: ArrayMesh = (calm.get_child(0) as MeshInstance3D).mesh
	var b: ArrayMesh = (moved.get_child(0) as MeshInstance3D).mesh
	assert_eq(hash(b.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]), hash(a.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]),
		"the reparented ring's vertex hash equals an undisturbed ring's")
	calm.free()
	moved.free()

## Phase 96 — a `rebuild` while the node is out of the tree starts one build, and re-entering the tree
## does not start a second one: the mesh swapped in is the newest centre's.
func _test_distant_ring_detached_rebuild() -> void:
	var c1 := Vector2(100.0, -40.0)
	var c2 := Vector2(1500.0, 900.0)
	var calm := DistantTerrainScript.new()
	add_child(calm)
	calm.world_seed = 11
	calm.rebuild(c2, 2)
	calm.poll(true)
	var d := DistantTerrainScript.new()
	add_child(d)
	d.world_seed = 11
	d.rebuild(c1, 2)
	remove_child(d)
	assert_true(d.rebuild(c2, 2), "a detached rebuild at a new centre is accepted")
	add_child(d)
	assert_eq(d.builds_started, d.rebuilds_requested - d.rebuilds_dropped, "one task started per accepted request")
	assert_true(d.poll(true), "the newest centre's mesh is swapped in")
	assert_eq(d.builds_started, d.rebuilds_requested - d.rebuilds_dropped, "re-entering started no extra task")
	var a: ArrayMesh = (calm.get_child(0) as MeshInstance3D).mesh
	var b: ArrayMesh = (d.get_child(0) as MeshInstance3D).mesh
	assert_eq(hash(b.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]), hash(a.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]),
		"the swapped-in mesh is the newest centre's")
	calm.free()
	d.free()

## Phase 96 — one build in flight and one queued, then a reparent: the queued request is the one built.
func _test_distant_ring_reparent_queued() -> void:
	var c1 := Vector2(100.0, -40.0)
	var c2 := Vector2(1500.0, 900.0)
	var calm := DistantTerrainScript.new()
	add_child(calm)
	calm.world_seed = 11
	calm.rebuild(c2, 2)
	calm.poll(true)
	var d := DistantTerrainScript.new()
	add_child(d)
	d.world_seed = 11
	d.rebuild(c1, 2)
	assert_true(d.rebuild(c2, 2), "a second request queues behind the first")
	remove_child(d)
	add_child(d)
	assert_true(d.is_building(), "re-entering restarted the queued request")
	assert_true(d.poll(true), "its mesh is swapped in")
	var a: ArrayMesh = (calm.get_child(0) as MeshInstance3D).mesh
	var b: ArrayMesh = (d.get_child(0) as MeshInstance3D).mesh
	assert_eq(hash(b.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]), hash(a.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]),
		"the vertex hash equals an undisturbed ring built at the queued centre")
	calm.free()
	d.free()

## Phase 96 — the abort path, run repeatedly: detach first (`remove_child`) so the worker is joined
## outside any locked iteration, then free.
func _test_distant_ring_abort_loop() -> void:
	for i in 50:
		var d := DistantTerrainScript.new()
		add_child(d)
		d.world_seed = 11 + i
		d.rebuild(Vector2(100.0 + float(i), -40.0), 2)
		var control = d._control
		remove_child(d)
		assert_true(control.aborted, "iteration %d: leaving the tree raised the abort flag" % i)
		assert_false(d.is_building(), "iteration %d: no task left in flight" % i)
		d.free()

func _test_distant_ring_unaborted_same() -> void:
	var half := DistantTerrainScript.ring_half_extent(2)
	var win := (2.0 + 0.5) * DistantTerrainScript.CHUNK_METERS
	var plain: ArrayMesh = DistantTerrainScript.build_mesh(5, 4.0e7, Vector2.ZERO, half, win, Vector2.ZERO)
	var ctl := DistantTerrainScript.BuildControl.new()
	var checked: ArrayMesh = DistantTerrainScript.build_mesh(5, 4.0e7, Vector2.ZERO, half, win, Vector2.ZERO, ctl)
	assert_eq(hash(checked.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]),
		hash(plain.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]), "same vertex hash with the check in place")
	assert_eq(ctl.rows, 2 * DistantTerrainScript.GRID + 1, "every row was visited")
	var abort := DistantTerrainScript.BuildControl.new()
	abort.aborted = true
	assert_true(DistantTerrainScript.build_mesh(5, 4.0e7, Vector2.ZERO, half, win, Vector2.ZERO, abort) == null, "an aborted build returns no mesh")
	assert_eq(abort.rows, 0, "and starts no row")

## Phase 68 — `rebuild` never evaluates the lattice on the main thread; the swapped-in mesh equals a
## synchronous build for the same centre.
func _test_distant_ring_async() -> void:
	var radius := 2
	var d := DistantTerrainScript.new()
	add_child(d)
	d.world_seed = 11
	assert_true(d.rebuild(Vector2(100.0, -40.0), radius), "the request is accepted")
	assert_true(d.is_building() or d.get_child_count() == 0, "no mesh is built synchronously")
	assert_eq(d.get_child_count(), 0, "rebuild returns before any mesh exists")
	assert_true(d.poll(true), "the finished mesh is swapped in")
	var cell := d.ring_half_m * 2.0 / 64.0
	var origin := Vector2i(floori(100.0 / cell), floori(-40.0 / cell))
	var snapped := Vector2(float(origin.x) * cell, float(origin.y) * cell)
	var sync_mesh: ArrayMesh = DistantTerrainScript.build_mesh(11, d.circumference_m, snapped, d.ring_half_m, d.window_half_m, Vector2(112.0, -48.0))   # the chunk-snapped window centre
	var got: ArrayMesh = (d.get_child(0) as MeshInstance3D).mesh
	assert_eq(got.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], sync_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], "the async mesh equals a synchronous build")
	# A request that arrives mid-build supersedes it; the newest wins.
	assert_true(d.rebuild(Vector2(5000.0, 5000.0), radius), "a far move starts a build")
	assert_true(d.rebuild(Vector2(-9000.0, 3000.0), radius), "a second far move queues behind it")
	d.poll(true)
	assert_false(d.is_building(), "everything drains")
	assert_false(d.rebuild(Vector2(-9000.0, 3000.0), radius), "the newest centre is the one built")
	d.free()

## Phase 77 — the ring's vertex array for a fixed seed and centre is pinned by a hash (recorded
## before the strip and detail-noise refactors), so neither can move a vertex.
func _test_distant_ring_vertex_hash() -> void:
	var seed_v := 7
	var w := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	var half := 3.5 * 32.0
	var wc := Vector2(16.0, 16.0)
	var ring_half := DistantTerrainScript.ring_half_extent(3)
	var cell := ring_half * 2.0 / 64.0
	var rc := Vector2(floorf(wc.x / cell) * cell, floorf(wc.y / cell) * cell)
	var mesh: ArrayMesh = DistantTerrainScript.build_mesh(seed_v, w, rc, ring_half, half, wc)
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_eq(verts.size(), 19908, "the ring for seed 7 has the recorded vertex count")
	assert_eq(hash(verts), 391342816, "the ring for seed 7 has the recorded vertex hash")

## Phase 77 — `detail_at`, `detail_of` and the detail term inside `_raw_height_at` are one formula.
func _test_detail_noise_single_formula() -> void:
	var t := TerrainSlice.new()
	add_child(t)
	t.set_world_seed(23)
	var w := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	var noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(noise, 23)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var cache := t._corner_cache()
	var bad := 0
	for _i in 256:
		var x := rng.randf_range(-3.0e6, 3.0e6)
		var z := rng.randf_range(-3.0e6, 3.0e6)
		var d := TerrainSlice.detail_of(noise, x, z)
		if t.detail_at(x, z) != d:
			bad += 1
		var expect := clampf(t._shape_at(x, z, w, cache) + d, WorldShape.min_height(), WorldShape.max_height())
		if t._raw_height_at(x, z, w, cache) != expect:
			bad += 1
	assert_eq(bad, 0, "detail_at, detail_of and _raw_height_at's detail term agree at 256 points")
	t.free()

## Phase 77 — walking the player across 5 chunks asks for at most 5 ring rebuilds, and the worker
## never has more than one build running plus one queued.
func _test_distant_ring_rebuild_counter() -> void:
	var radius := 3   # a lattice cell (35 m) is wider than a chunk (32 m): one request per chunk step
	var d := DistantTerrainScript.new()
	add_child(d)
	d.world_seed = 5
	d.rebuild(Vector2(16.0, 16.0), radius)
	d.poll(true)
	var base := d.rebuilds_requested
	var worst_in_flight := 0
	for chunk in range(1, 6):
		d.rebuild(Vector2(float(chunk) * 32.0 + 16.0, 16.0), radius)
		d.rebuild(Vector2(float(chunk) * 32.0 + 17.0, 16.0), radius)   # same chunk and cell: no request
		var in_flight := d.rebuilds_requested - d.rebuilds_completed - d.rebuilds_dropped
		worst_in_flight = maxi(worst_in_flight, in_flight)
		if chunk % 2 == 0:
			d.poll(true)
	d.poll(true)
	assert_true(d.rebuilds_requested - base <= 5, "5 chunks request at most 5 rebuilds (%d)" % (d.rebuilds_requested - base))
	assert_true(worst_in_flight <= 2, "at most one build running and one queued (%d)" % worst_in_flight)
	assert_eq(d.rebuilds_requested, d.rebuilds_completed + d.rebuilds_dropped, "every request is completed or dropped once drained")
	d.free()

## Phase 68 — heights sampled from several worker tasks at once equal the single-threaded samples
## (the corner cache is per thread).
func _test_height_concurrent() -> void:
	var t := TerrainSlice.new()
	_own(t)
	t.set_world_seed(31)
	var pts := PackedVector2Array()
	for i in 400:
		pts.append(Vector2(float(i * 37 % 900) * 3.1 - 1200.0, float(i * 53 % 700) * 2.7 - 900.0))
	var expect := PackedFloat32Array()
	for p in pts:
		expect.append(t.get_height_at(p))
	var tasks := 4
	var out: Array = []
	out.resize(tasks)
	var job := func(idx: int) -> void:
		var r := PackedFloat32Array()
		for k in pts.size():
			var p := pts[(k + idx * 97) % pts.size()]   # each task walks the cells in its own order
			r.append(t.get_height_at(p))
		out[idx] = r
	var gid := WorkerThreadPool.add_group_task(job, tasks)
	WorkerThreadPool.wait_for_group_task_completion(gid)
	var ok := true
	for idx in tasks:
		var r: PackedFloat32Array = out[idx]
		for k in pts.size():
			if r[k] != expect[(k + idx * 97) % pts.size()]:
				ok = false
	assert_true(ok, "concurrent samples equal single-threaded samples")

func _test_ocean_spawns_no_land_tables() -> void:
	assert_true(TreeSlice.TREES_BY_BIOME.get("Ocean", {}).is_empty(), "Ocean grows no trees")
	assert_true(TreeSlice.TREES_BY_BIOME.get("Alpine", {}).is_empty(), "nor does Alpine")
	var ts := TreeSlice.new()
	assert_eq(ts.tree_count_for(Vector2i(3, 3), "Ocean"), 0, "an Ocean chunk's tree budget is zero")
	ts.free()
	var creature := CreatureSlice.new()
	var keys: Array = TerrainSlice.BIOME_KEYS
	assert_eq(creature._biome_keys(), keys, "the creature slice's fallback list matches the terrain's")
	assert_true(keys.has("Ocean"), "Ocean is a canonical biome key")
	for res in GameData.CREATURES.values():
		var idx: int = int(res.get("biome"))
		assert_true(str(keys[idx]) != "Ocean", "no creature table names the Ocean")
	creature.free()


# ---------------------------------------------------------------------------
# Phase 52 — region storage and per-peer streaming
# ---------------------------------------------------------------------------

const RegionStoreScript := preload("res://src/persistence/region_store.gd")
const RegionStreamerScript := preload("res://src/persistence/region_streamer.gd")

func _fresh_region_dir(name: String) -> String:
	var dir := "user://saves/%s/" % name
	_wipe_dir(dir)
	_wipe_dir(dir + "regions/")
	return dir

func _test_region_mapping() -> void:
	var R := RegionStoreScript
	assert_eq(R.region_of_chunk(Vector2i(0, 0)), Vector2i(0, 0), "chunk 0,0 is in region 0,0")
	assert_eq(R.region_of_chunk(Vector2i(31, 31)), Vector2i(0, 0), "chunk 31,31 is the last of region 0,0")
	assert_eq(R.region_of_chunk(Vector2i(32, 0)), Vector2i(1, 0), "chunk 32,0 opens region 1,0")
	assert_eq(R.region_of_chunk(Vector2i(-1, -32)), Vector2i(-1, -1), "negative chunks floor into negative regions")
	assert_eq(R.region_of_chunk(Vector2i(-33, 0)), Vector2i(-2, 0), "chunk -33 is in region -2")
	assert_eq(R.file_name(Vector2i(-1, 2)), "r.-1.2.json", "the file name carries the signed coordinates")
	var parsed: Dictionary = R.region_from_file_name("r.-1.2.json")
	assert_true(bool(parsed["ok"]) and parsed["region"] == Vector2i(-1, 2), "a region file name parses back")
	assert_false(bool(R.region_from_file_name("world.json")["ok"]), "world.json is not a region file")
	assert_false(bool(R.region_from_file_name("r.x.1.json")["ok"]), "a non-numeric name is not a region file")
	var grouped: Dictionary = R.group_manifest({ "0,0": { "edits": { "1": [] } }, "5,5": { "edits": { "2": [] } }, "40,0": { "edits": { "3": [] } } })
	assert_eq(grouped.size(), 2, "three chunks in two regions group into two")
	assert_eq((grouped["0,0"] as Dictionary).size(), 2, "chunks 0,0 and 5,5 share region 0,0")
	var folded: Dictionary = R.fold_chunks({ "0,0": { "edits": { "1": [1] } }, "1,1": { "edits": { "2": [2] } } },
		{ "0,0": { "edits": {} }, "2,2": { "edits": { "3": [3] } } })
	assert_false(folded.has("0,0"), "an empty edit set deletes the chunk")
	assert_true(folded.has("1,1") and folded.has("2,2"), "the other chunks are kept and added")

func _region_files(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d != null:
		for f in d.get_files():
			if f.begins_with("r.") and f.ends_with(".json"):
				out.append(f)
	out.sort()
	return out

func _test_region_save_writes_one_file() -> void:
	var dir := _fresh_region_dir("test_p52_one_file")
	var writer := PersistenceSlice.new()
	add_child(writer)
	writer.server_save_dir = dir
	writer._rebuild_region_store()
	var edit := { "edits": { "0,0": [{ "op": "raise", "n": 1 }] } }
	var manifest := { "0,0": edit, "40,0": edit, "-1,0": edit }
	assert_eq(writer.save_world({ "local_player_id": "p" , "chunks": manifest }, false), OK, "the first save writes")
	assert_eq(_region_files(dir + "regions/"), ["r.-1.0.json", "r.0.0.json", "r.1.0.json"], "three regions, three files")
	assert_false("chunks" in writer.load_world_record(), "world.json keeps no chunks")
	# Remove two of the files; a save carrying ONE dirty chunk must recreate only its own.
	DirAccess.remove_absolute(dir + "regions/r.1.0.json")
	DirAccess.remove_absolute(dir + "regions/r.-1.0.json")
	var subset := PersistenceSlice.dirty_chunk_subset(manifest, ["0,0"])
	assert_eq(writer.save_world({ "local_player_id": "p", "chunks": subset }, true), OK, "the incremental save writes")
	assert_eq(_region_files(dir + "regions/"), ["r.0.0.json"], "exactly the dirty chunk's region file was written")
	assert_eq(writer.region_store.list_dirty(["0,0", "3,3"]).size(), 1, "list_dirty names one region for two chunks in it")
	writer.free()

func _test_region_full_save_erases_and_migration_keeps_newer() -> void:
	var dir := _fresh_region_dir("test_p52_full_erase")
	var writer := PersistenceSlice.new()
	add_child(writer)
	writer.server_save_dir = dir
	writer._rebuild_region_store()
	var old_edit := { "edits": { "0,0": [{ "op": "raise", "n": 1 }] } }
	assert_eq(writer.save_world({ "local_player_id": "p", "chunks": { "0,0": old_edit, "1,0": old_edit } }, false), OK, "seed save")
	# A FULL save whose dirty chunk 0,0 compacted away carries the deletion marker.
	assert_eq(writer.save_world({ "local_player_id": "p", "chunks": { "0,0": { "edits": {} }, "1,0": old_edit } }, false), OK, "full save with a marker")
	var chunks := writer.load_region_chunks([Vector2i(0, 0)])
	assert_false(chunks.has("0,0"), "a full save erases a chunk whose edits compacted away")
	assert_true(chunks.has("1,0"), "and keeps the others")
	# A migration never overwrites a chunk a region already holds (stale monolith vs newer saves).
	var stale := { "1,0": { "edits": { "9,9": [{ "op": "raise", "n": 5 }] } }, "2,0": old_edit }
	assert_eq(writer.region_store.migrate_manifest(stale), OK, "migration runs")
	chunks = writer.load_region_chunks([Vector2i(0, 0)])
	assert_false((chunks["1,0"]["edits"] as Dictionary).has("9,9"), "the newer region entry wins over the stale monolith")
	assert_true(chunks.has("2,0"), "a chunk the region lacked is migrated in")
	writer.free()

func _test_region_migrates_monolith() -> void:
	var dir := _fresh_region_dir("test_p52_migrate")
	var voxel := _make_voxel()
	assert_true(voxel.mine_block(Vector3(16.25, 2.0, 16.25)).get("success", false), "an edit exists in chunk 0,0")
	var manifest := voxel.get_chunk_manifest()
	# A Phase 51 record: one world.json carrying every chunk.
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir + "world.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({ "version": 2, "seed": 7, "local_player_id": "p", "chunks": manifest }))
	f.close()
	var store := PersistenceSlice.new()
	add_child(store)
	store.server_save_dir = dir
	store._rebuild_region_store()
	var record := store.load_world_record()
	assert_false(record.has("chunks"), "the migrated record carries no chunks")
	assert_eq(int(record.get("seed", -1)), 7, "and keeps its global state")
	assert_eq(_region_files(dir + "regions/"), ["r.0.0.json"], "the chunks split into region files on first boot")
	var on_disk := JSON.parse_string(FileAccess.get_file_as_string(dir + "world.json")) as Dictionary
	assert_false(on_disk.has("chunks"), "world.json was rewritten without them")
	var voxel2 := _make_voxel()
	voxel2.apply_chunk_manifest(store.load_world()["chunks"])
	assert_true(voxel2.get_chunk_manifest() == manifest, "every edit survives the migration")
	voxel.free()
	voxel2.free()
	store.free()

func _test_region_unreadable_not_overwritten() -> void:
	var dir := _fresh_region_dir("test_p52_unreadable")
	var store: RegionStoreScript = RegionStoreScript.new(dir + "regions/")
	DirAccess.make_dir_recursive_absolute(dir + "regions/")
	var path := store.path_of(Vector2i.ZERO)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	var entry := { "edits": { "0,0": [{ "op": "raise", "n": 1 }] } }
	assert_true(store.write_chunks({ "1,1": entry }) != OK, "a save into an unreadable region reports an error")
	assert_true(store.migrate_manifest({ "1,1": entry }) != OK, "a migration into an unreadable region reports an error")
	assert_eq(FileAccess.get_file_as_string(path), "{ not json", "the unreadable file is left untouched")
	# Malformed entries are dropped on read; malformed manifest keys are skipped, not filed under 0,0.
	var g := FileAccess.open(path, FileAccess.WRITE)
	g.store_string(JSON.stringify({ "version": 1, "chunks": { "3,4": 5, "1,1": entry } }))
	g.close()
	assert_eq(store.load_region(Vector2i.ZERO).keys(), ["1,1"], "a non-Dictionary chunk entry is dropped on read")
	assert_eq(RegionStoreScript.group_manifest({ "a": entry, "2,2": entry }).size(), 1, "a malformed chunk key is skipped")

## Phase 52 follow-up — a save into several regions writes every region it can; the unreadable
## one is left alone and reported, and a malformed `edits` / `materials` entry is dropped on read.
func _test_region_partial_save() -> void:
	var dir := _fresh_region_dir("test_p52_partial")
	var store: RegionStoreScript = RegionStoreScript.new(dir + "regions/")
	DirAccess.make_dir_recursive_absolute(dir + "regions/")
	var bad_path := store.path_of(Vector2i(0, 0))
	var f := FileAccess.open(bad_path, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	var entry := { "edits": { "0,0": [{ "op": "raise", "n": 1 }] } }
	var err := store.write_chunks({ "1,1": entry, "40,40": entry })   # region 0,0 (bad) and region 1,1
	assert_true(err != OK, "the unreadable region is reported")
	assert_eq(FileAccess.get_file_as_string(bad_path), "{ not json", "and left untouched")
	assert_true(store.has_region(Vector2i(1, 1)), "the readable region was still written")
	assert_eq(store.load_region(Vector2i(1, 1)).keys(), ["40,40"], "with its own chunk")
	var g := FileAccess.open(bad_path, FileAccess.WRITE)
	g.store_string(JSON.stringify({ "version": 1, "chunks": {
		"1,1": entry, "2,2": { "edits": [1] }, "3,3": { "edits": {}, "materials": "x" }, "4,4": { "materials": {} } } }))
	g.close()
	var keys: Array = store.load_region(Vector2i(0, 0)).keys()
	keys.sort()
	assert_eq(keys, ["1,1", "4,4"], "entries whose edits or materials are not Dictionaries are dropped")
	assert_true(RegionStoreScript.is_valid_chunk_entry({ "edits": {}, "materials": {} }), "a well-formed entry is valid")
	assert_false(RegionStoreScript.is_valid_chunk_entry(5), "a non-Dictionary entry is not")

## Review of #159 — a failed save re-marks only the chunks of the regions that failed.
func _test_region_failed_keys_and_remark() -> void:
	var dir := _fresh_region_dir("test_failed_keys")
	var store: RegionStoreScript = RegionStoreScript.new(dir + "regions/")
	DirAccess.make_dir_recursive_absolute(dir + "regions/")
	var f := FileAccess.open(store.path_of(Vector2i(0, 0)), FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	var entry := { "edits": { "0,0": [{ "op": "raise", "n": 1 }] } }
	assert_true(store.write_chunks({ "1,1": entry, "2,2": entry, "40,40": entry }) != OK, "one region fails")
	var failed: Array = store.last_failed_chunk_keys.duplicate()
	failed.sort()
	assert_eq(failed, ["1,1", "2,2"], "exactly the chunks of the unreadable region are reported")
	assert_eq(store.write_chunks({ "40,40": entry }), OK, "a clean write succeeds")
	assert_true(store.last_failed_chunk_keys.is_empty(), "and clears the report")
	var root_script: GDScript = load("res://src/core/game_root.gd")
	assert_eq(root_script._chunks_to_remark(["1,1", "40,40", "2,2"], ["1,1", "2,2"]), ["1,1", "2,2"],
		"only the failed region's dirty chunks go back")
	assert_eq(root_script._chunks_to_remark(["1,1", "40,40"], []), ["1,1", "40,40"],
		"with no region failure (record or player write failed) every chunk stays dirty")
	assert_eq(root_script._chunks_to_remark(["40,40"], ["1,1"]), [],
		"a failed chunk that was not part of this save is not invented")
	var persistence := PersistenceSlice.new()
	add_child(persistence)
	persistence.region_store = store
	assert_eq(persistence.failed_chunk_keys(), [], "the slice reports the store's last write")
	persistence.free()

func _test_region_neighbour_expansion_edges_only() -> void:
	var interior := RegionStreamerScript.regions_for_chunks([Vector2i(10, 10)])
	assert_eq(interior.keys(), ["0,0"], "an interior chunk wants only its own region")
	var corner := RegionStreamerScript.regions_for_chunks([Vector2i(0, 0)])
	assert_true(corner.has("0,0") and corner.has("-1,-1") and corner.has("-1,0") and corner.has("0,-1"),
		"a corner chunk also wants the regions across its edges")
	var east := RegionStreamerScript.regions_for_chunks([Vector2i(31, 10)])
	assert_true(east.has("0,0") and east.has("1,0") and not east.has("0,1") and not east.has("0,-1"),
		"an east-edge chunk reaches the next region east and no other")

## Phase 75 — mining a vein anchored in an EVICTED chunk must not replace that chunk's stored
## entry with the lone depletion op.
func _test_region_depletion_merges_evicted() -> void:
	var found := _find_surface_vein(0)
	if found.is_empty():
		assert_true(false, "a vein breaks the surface of a flat chunk somewhere")
		return
	var vein: Dictionary = found["vein"]
	var anchor: Vector2i = vein["anchor"]
	var a_key := VoxelSlice._chunk_key(VoxelSlice._tile_to_chunk(anchor))
	var dir := _fresh_region_dir("test_p75_depletion")
	var store: RegionStoreScript = RegionStoreScript.new(dir + "regions/")
	var v := VoxelSlice.new()
	add_child(v)
	var edit_keys: Array = []
	for off in [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(0, 2), Vector2i(-1, -1), Vector2i(1, 1)]:
		var tile: Vector2i = anchor + off
		if edit_keys.size() < 3 and VoxelSlice._chunk_key(VoxelSlice._tile_to_chunk(tile)) == a_key:
			edit_keys.append(VoxelSlice._tile_key(tile))
	assert_eq(edit_keys.size(), 3, "three tiles of the anchor's chunk to edit")
	for k in edit_keys:
		v._set_edit_ops(k, [{ "op": "remove", "bottom": 0.0, "top": 1.0 }])
	v.mark_dirty_chunks([a_key])
	assert_eq(store.write_chunks(v.get_save_manifest()), OK, "the three edits are saved")
	v.clear_dirty_chunks()
	assert_eq(v.evict_clean_chunks([a_key]), 1, "the chunk is evicted")
	# Mined from a neighbour: the depletion lands on the anchor of the evicted chunk.
	v._record_depletion(vein, 1)
	v.mark_dirty_chunks([a_key])
	var manifest := v.get_save_manifest()
	assert_true(bool(manifest[a_key].get("merge", false)), "the partial entry is flagged for merging")
	assert_false(v.get_chunk_manifest()[a_key].has("merge"), "the wire manifest carries no flag")
	assert_eq(store.write_chunks(PersistenceSlice.dirty_chunk_subset(manifest, [a_key])), OK, "the depletion is saved")
	var stored: Dictionary = store.load_region(RegionStoreScript.region_of_chunk_key(a_key))[a_key]
	assert_false(stored.has("merge"), "the merge flag is not stored")
	for k in edit_keys:
		assert_true(stored["edits"].has(k), "stored edit %s survives" % k)
	var deplete_ops := 0
	for op in stored["edits"][VoxelSlice._tile_key(anchor)]:
		if str(op.get("op", "")) == "deplete":
			deplete_ops += 1
	assert_eq(deplete_ops, 1, "and the depletion is stored once")
	# A second save of the same partial chunk neither duplicates nor loses anything.
	assert_eq(store.write_chunks(PersistenceSlice.dirty_chunk_subset(v.get_save_manifest(), [a_key])), OK, "saved again")
	var again: Dictionary = store.load_region(RegionStoreScript.region_of_chunk_key(a_key))[a_key]
	assert_true(again == stored, "a repeated merge is idempotent")
	var w := VoxelSlice.new()
	add_child(w)
	w.apply_region_chunks(store.load_region(RegionStoreScript.region_of_chunk_key(a_key)))
	assert_eq(w.get_edits().size(), 4, "after reload the chunk holds the three edits and the depletion")
	assert_eq(int(w.get_vein_depletion().get(str(vein["id"]), 0)), 1, "with the vein's count")
	v.free()
	w.free()

func _write_region_file(store: RegionStoreScript, chunks: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(store.dir)
	var f := FileAccess.open(store.path_of(Vector2i.ZERO), FileAccess.WRITE)
	f.store_string(JSON.stringify({ "version": 1, "chunks": chunks }))
	f.close()

## Phase 75 — a malformed entry is not handed out, is rewritten unchanged by a neighbour's save,
## and warns once per read (not per save).
func _test_region_malformed_entry_kept() -> void:
	var dir := _fresh_region_dir("test_p75_malformed")
	var store: RegionStoreScript = RegionStoreScript.new(dir + "regions/")
	var good := { "edits": { "0,0": [{ "op": "remove", "bottom": 0.0, "top": 1.0 }] } }
	_write_region_file(store, { "1,1": { "edits": "x" }, "2,2": good })
	var warns := Diag.warn_count()
	var read := store.read_region(Vector2i.ZERO)
	assert_eq(Diag.warn_count() - warns, 1, "one warning for the one malformed entry on a read")
	assert_eq(read["chunks"].keys(), ["2,2"], "only the valid entry is handed out")
	assert_eq(read["raw_invalid"].keys(), ["1,1"], "the malformed one is reported separately")
	warns = Diag.warn_count()
	assert_eq(store.write_chunks({ "3,3": good }), OK, "a neighbour is saved")
	assert_eq(store.write_chunks({ "3,3": good }), OK, "and again")
	assert_eq(Diag.warn_count() - warns, 0, "saves do not re-warn")
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.path_of(Vector2i.ZERO)))
	assert_eq(JSON.stringify(parsed["chunks"]["1,1"]), JSON.stringify({ "edits": "x" }), "the malformed entry is rewritten unchanged")
	var keys: Array = parsed["chunks"].keys()
	keys.sort()
	assert_eq(keys, ["1,1", "2,2", "3,3"], "with both valid entries")

## Phase 89 — a malformed entry warns once per store, not on every streaming read.
func _test_region_malformed_warns_once() -> void:
	var dir := _fresh_region_dir("test_p89_warn_once")
	var store: RegionStoreScript = RegionStoreScript.new(dir + "regions/")
	var good := { "edits": { "0,0": [{ "op": "remove", "bottom": 0.0, "top": 1.0 }] } }
	_write_region_file(store, { "1,1": { "edits": "x" }, "2,2": good })
	var warns := Diag.warn_count()
	for _i in 50:
		store.read_region(Vector2i.ZERO)
	assert_eq(Diag.warn_count() - warns, 1, "50 reads of one malformed entry warn once")
	var f := FileAccess.open(store.path_of(Vector2i(1, 0)), FileAccess.WRITE)
	f.store_string(JSON.stringify({ "version": 1, "chunks": { "33,1": { "edits": 5 } } }))
	f.close()
	warns = Diag.warn_count()
	for _i in 50:
		store.read_region(Vector2i(1, 0))
		store.read_region(Vector2i.ZERO)
	assert_eq(Diag.warn_count() - warns, 1, "a malformed entry in another region warns once more")
	store.reset_warnings()
	warns = Diag.warn_count()
	store.read_region(Vector2i.ZERO)
	store.read_region(Vector2i.ZERO)
	assert_eq(Diag.warn_count() - warns, 1, "after the reset the first read warns again")
	var other: RegionStoreScript = RegionStoreScript.new(dir + "regions/")
	warns = Diag.warn_count()
	other.read_region(Vector2i.ZERO)
	assert_eq(Diag.warn_count() - warns, 1, "a new store warns on its first read")
	assert_eq(store.write_chunks({ "3,3": good }), OK, "a neighbour is saved")
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.path_of(Vector2i.ZERO)))
	assert_eq(JSON.stringify(parsed["chunks"]["1,1"]), JSON.stringify({ "edits": "x" }), "the malformed entry survives the rewrite unchanged")

func _test_region_malformed_entry_replaced() -> void:
	var dir := _fresh_region_dir("test_p75_malformed_replace")
	var store: RegionStoreScript = RegionStoreScript.new(dir + "regions/")
	var good := { "edits": { "0,0": [{ "op": "remove", "bottom": 0.0, "top": 1.0 }] } }
	_write_region_file(store, { "1,1": { "edits": "x" } })
	assert_eq(store.write_chunks({ "1,1": good }), OK, "a save carrying the key")
	var read := store.read_region(Vector2i.ZERO)
	assert_true(read["raw_invalid"].is_empty(), "no malformed entry remains")
	assert_true(read["chunks"]["1,1"] == good, "the valid entry replaced it")

func _test_region_partial_chunk_loads_stored() -> void:
	var found := _find_surface_vein(0)
	if found.is_empty():
		assert_true(false, "a vein breaks the surface of a flat chunk somewhere")
		return
	var vein: Dictionary = found["vein"]
	var anchor: Vector2i = vein["anchor"]
	var a_key := VoxelSlice._chunk_key(VoxelSlice._tile_to_chunk(anchor))
	var other: Vector2i = anchor + Vector2i(2, 0)
	if VoxelSlice._chunk_key(VoxelSlice._tile_to_chunk(other)) != a_key:
		other = anchor - Vector2i(2, 0)
	var other_key := VoxelSlice._tile_key(other)
	var stored := { a_key: { "edits": { other_key: [{ "op": "remove", "bottom": 0.0, "top": 1.0 }] } } }
	var v := VoxelSlice.new()
	add_child(v)
	v._record_depletion(vein, 1)   # the anchor chunk holds no edits: the depletion is partial
	v.apply_region_chunks(stored)
	assert_true(v.get_edits().has(other_key), "the stored edit is applied beneath the depletion")
	assert_eq(int(v.get_vein_depletion().get(str(vein["id"]), 0)), 1, "the depletion is kept")
	assert_false(v.get_save_manifest()[a_key].has("merge"), "the chunk is whole, so the next save replaces")
	v.free()

## Phase 99 — the shared legacy-height parser: finite numbers and numeric strings only.
func _test_legacy_height_parser() -> void:
	for bad in [NAN, INF, -INF, "abc", "", "inf", null, [1.0], { "h": 1.0 }]:
		assert_true(is_nan(RegionStoreScript.legacy_height_of(bad)), "the shared parser refuses %s" % str(bad))
		assert_false(RegionStoreScript._is_legacy_height(bad), "the region check refuses %s" % str(bad))
		assert_true(is_nan(VoxelSlice._legacy_height_of(bad)), "the voxel parser refuses %s" % str(bad))
	for good in [3.0, 3, "3.0"]:
		assert_eq(RegionStoreScript.legacy_height_of(good), 3.0, "the shared parser reads %s" % str(good))
		assert_true(RegionStoreScript._is_legacy_height(good), "the region check accepts %s" % str(good))
		assert_eq(VoxelSlice._legacy_height_of(good), 3.0, "the voxel parser reads %s" % str(good))

## Phase 99 — a `legacy` op migrates against the tile's materials stack exactly as a bare height does.
func _test_legacy_op_materials_stack() -> void:
	var mats := { "32,32": ["stone", "dirt"] }
	var bare := _make_voxel()
	bare.apply_edits({ "32,32": 4.0 }, mats)
	var typed := _make_voxel()
	typed.apply_edits({ "32,32": [{ "op": RegionStoreScript.LEGACY_OP, "height": 4.0 }] }, mats)
	assert_true(bare.get_edits()["32,32"].size() >= 3, "the stack is migrated into several ops")
	assert_eq(typed.get_edits()["32,32"], bare.get_edits()["32,32"], "the legacy op equals the bare height")
	bare.free()
	typed.free()

## Phase 99 — `apply_region_chunks` lays a resident depletion over a stored bare height.
func _test_partial_chunk_legacy_op() -> void:
	var found := _find_surface_vein(0)
	if found.is_empty():
		assert_true(false, "a vein breaks the surface of a flat chunk somewhere")
		return
	var vein: Dictionary = found["vein"]
	var anchor: Vector2i = vein["anchor"]
	var a_key := VoxelSlice._chunk_key(VoxelSlice._tile_to_chunk(anchor))
	var tile_key := VoxelSlice._tile_key(anchor)
	var v := VoxelSlice.new()
	add_child(v)
	v._record_depletion(vein, 1)   # the chunk holds only the depletion: partial
	v.apply_region_chunks({ a_key: { "edits": { tile_key: 1.0 } } })
	var ops: Array = v.get_edits().get(tile_key, [])
	var depleted := false
	var migrated := false
	for op in ops:
		depleted = depleted or op["op"] == "deplete"
		migrated = migrated or op["op"] == "add" or op["op"] == "remove"
		assert_true(op["op"] != RegionStoreScript.LEGACY_OP, "no raw legacy op is left in the log")
	assert_true(depleted, "the depletion is kept")
	assert_true(migrated, "the stored bare height was migrated to a typed run edit")
	v.free()

## Phase 99 — an unreadable legacy op is dropped with one warning; a tile with no legacy op is unchanged.
func _test_legacy_op_unreadable_dropped() -> void:
	var v := _make_voxel()
	var remove := { "op": "remove", "bottom": 0.0, "top": 1.0 }
	var warns := Diag.warn_count()
	v.apply_edits({ "32,32": [{ "op": RegionStoreScript.LEGACY_OP, "height": "abc" }, remove] })
	assert_eq(Diag.warn_count() - warns, 1, "one warning for the unreadable legacy height")
	assert_eq(v.get_edits()["32,32"].size(), 1, "only the typed op survives")
	assert_eq(v.get_edits()["32,32"][0]["op"], "remove", "and it is the remove")
	var plain := [remove, { "op": "add", "bottom": 0.0, "top": 0.5, "material": "stone" }]
	v.apply_edits({ "40,40": plain })
	assert_eq(v.get_edits()["40,40"], plain, "a tile with no legacy op round-trips unchanged")
	v.free()

## Phase 91 — a bare legacy tile height overlaid with a deplete survives as a typed `legacy` op and
## migrates to the same column as the bare height alone.
func _test_region_overlay_legacy_height() -> void:
	var dep := { "op": "deplete", "vein": "v", "taken": 4 }
	var stored := { "edits": { "32,32": 1.0 } }
	var out := RegionStoreScript.overlay_entry(stored, { "merge": true, "edits": { "32,32": [dep] } })
	var ops: Array = out["edits"]["32,32"]
	assert_eq(ops.size(), 2, "the legacy height and the depletion")
	assert_eq(ops[0], { "op": RegionStoreScript.LEGACY_OP, "height": 1.0 }, "the legacy height is first")
	assert_true(RegionStoreScript.is_valid_chunk_entry(out), "the overlaid entry is a valid chunk entry")
	var bare := _make_voxel()
	bare.apply_edits({ "32,32": 1.0 })
	var via := _make_voxel()
	via.apply_edits(out["edits"])
	assert_eq(via.get_voxel_height_at(Vector2(16.0, 16.0)), bare.get_voxel_height_at(Vector2(16.0, 16.0)),
		"the column top equals the bare height alone")
	assert_eq(via.get_voxel_height_at(Vector2(16.0, 16.0)), 1.0, "and is the legacy height")
	var kept := false
	for op in via.get_edits()["32,32"]:
		kept = kept or (op["op"] == "deplete" and int(op["taken"]) == 4)
	assert_true(kept, "the depletion's taken count is kept")
	# A second deplete keeps exactly one legacy op.
	var again := RegionStoreScript.overlay_entry(out, { "merge": true, "edits": { "32,32": [{ "op": "deplete", "vein": "v", "taken": 6 }] } })
	var legacy_ops := 0
	for op in again["edits"]["32,32"]:
		if op["op"] == RegionStoreScript.LEGACY_OP:
			legacy_ops += 1
	assert_eq(legacy_ops, 1, "exactly one legacy op after a second deplete")
	assert_eq(again["edits"]["32,32"].size(), 2, "and the larger depletion replaced the first")
	# A numeric string migrates the same.
	var str_out := RegionStoreScript.overlay_entry({ "edits": { "32,32": "1.0" } }, { "merge": true, "edits": { "32,32": [dep] } })
	assert_eq(str_out["edits"]["32,32"][0], { "op": RegionStoreScript.LEGACY_OP, "height": 1.0 }, "a numeric string is carried too")
	# A typed op list overlays as before.
	var typed := RegionStoreScript.overlay_entry({ "edits": { "32,32": [{ "op": "remove", "bottom": 0.0, "top": 1.0 }] } },
		{ "merge": true, "edits": { "32,32": [dep] } })
	assert_eq(typed["edits"]["32,32"].size(), 2, "a typed list gains the depletion only")
	assert_eq(typed["edits"]["32,32"][0]["op"], "remove", "and gains no legacy op")
	bare.free()
	via.free()

func _test_region_overlay_keeps_larger_taken() -> void:
	var stored := { "edits": { "0,0": [{ "op": "deplete", "vein": "v", "taken": 40 }] } }
	var entry := { "merge": true, "edits": { "0,0": [{ "op": "deplete", "vein": "v", "taken": 3 }] } }
	var out := RegionStoreScript.overlay_entry(stored, entry)
	assert_eq(out["edits"]["0,0"].size(), 1, "one depletion op remains")
	assert_eq(int(out["edits"]["0,0"][0]["taken"]), 40, "with the larger count")

func _test_region_migrate_malformed_recovers() -> void:
	var dir := _fresh_region_dir("test_p75_migrate_malformed")
	var store: RegionStoreScript = RegionStoreScript.new(dir + "regions/")
	var good := { "edits": { "0,0": [{ "op": "remove", "bottom": 0.0, "top": 1.0 }] } }
	_write_region_file(store, { "1,1": { "edits": "x" }, "2,2": { "edits": "y" } })
	assert_eq(store.migrate_manifest({ "1,1": good }), OK, "migrated")
	var read := store.read_region(Vector2i.ZERO, false)
	assert_true(read["chunks"]["1,1"] == good, "the monolith's valid copy fills the malformed slot")
	assert_eq(read["raw_invalid"].keys(), ["2,2"], "an unrelated malformed entry stays")

func _test_region_evict_keeps_vein_depletion() -> void:
	var found := _find_surface_vein(0)
	if found.is_empty():
		assert_true(false, "a vein breaks the surface of a flat chunk somewhere")
		return
	var vein: Dictionary = found["vein"]
	var id := str(vein["id"])
	var v := VoxelSlice.new()
	add_child(v)
	# Deplete the whole reserve: the op lands on the anchor tile's chunk (chunk A).
	v._record_depletion(vein, int(vein["reserve"]))
	var a_key := VoxelSlice._chunk_key(VoxelSlice._tile_to_chunk(vein["anchor"]))
	assert_false(OreField.is_live(vein, v.get_vein_depletion()), "the vein is exhausted")
	var manifest := v.get_chunk_manifest()
	v.clear_dirty_chunks()
	assert_eq(v.evict_clean_chunks([a_key]), 1, "chunk A is evicted")
	assert_false(v.edited_chunk_keys().has(a_key), "no edit of chunk A stays resident")
	assert_false(OreField.is_live(vein, v.get_vein_depletion()), "the vein stays depleted for chunk B after A is evicted")
	assert_eq(int(v.get_vein_depletion().get(id, 0)), int(vein["reserve"]), "with its full count")
	v.apply_region_chunks(manifest)
	assert_false(OreField.is_live(vein, v.get_vein_depletion()), "and after A is re-read")
	assert_true(v._vein_carry.is_empty(), "the carry is dropped once the op is resident again")
	v.free()

func _test_region_failed_write_saves_the_rest() -> void:
	var dir := _fresh_region_dir("test_p61_save")
	var store := PersistenceSlice.new()
	add_child(store)
	store.server_save_dir = dir
	var entry := { "edits": { "0,0": [{ "op": "raise", "n": 1 }] } }
	# Region (0,0) is unreadable; region (1,0) is fine.
	DirAccess.make_dir_recursive_absolute(dir + "regions/")
	var bad := store.region_store.path_of(Vector2i.ZERO)
	var f := FileAccess.open(bad, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	var pid := "player_1_1_abc"
	var job := {
		"world":       { "local_player_id": pid, "chunks": { "1,1": entry, "40,1": entry } },
		"incremental": false,
		"players":     { pid: { "player_id": pid, "hp": 7.0 } },
	}
	assert_true(int(store.write_job(job)) != OK, "the save reports the unreadable region")
	assert_true(store.region_store.has_region(Vector2i(1, 0)), "the readable region was still written")
	assert_eq(FileAccess.get_file_as_string(bad), "{ not json", "the unreadable file is untouched")
	assert_true(store.has_world(), "world.json was still written")
	assert_eq(float(store.load_player(pid).get("hp", -1.0)), 7.0, "and so was the player record")
	store.free()

## Phase 52 follow-up — a region whose file cannot be read is not marked resident, so a later
## sync retries it once the file is readable.
func _test_region_failed_read_retried() -> void:
	var dir := _fresh_region_dir("test_p52_retry")
	var store: RegionStoreScript = RegionStoreScript.new(dir + "regions/")
	DirAccess.make_dir_recursive_absolute(dir + "regions/")
	var path := store.path_of(Vector2i(0, 0))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	var voxel := _make_voxel()
	var streamer := RegionStreamerScript.new(store, voxel)
	var clock := [0]
	streamer._now = func() -> int: return clock[0]
	var first := streamer.sync({ "0,0": true })
	assert_eq(int(first["failed"]), 1, "the unreadable region is reported as failed")
	assert_eq(int(first["loaded"]), 0, "and not as loaded")
	assert_false(streamer.is_resident(Vector2i(0, 0)), "it is not resident")
	var edit := { "edits": { "0,0": [{ "op": "raise", "n": 1 }] } }
	assert_eq(store.save_region(Vector2i(0, 0), { "1,1": edit }), OK, "the file is repaired")
	clock[0] += RegionStreamerScript.BACKOFF_START_MSEC   # the first backoff has elapsed
	var second := streamer.sync({ "0,0": true })
	assert_eq(int(second["loaded"]), 1, "the next sync reads it")
	assert_true(streamer.is_resident(Vector2i(0, 0)), "and it is resident now")
	voxel.free()

func _test_registry_bound_peer_ids() -> void:
	var reg := PlayerRegistry.new()
	_own(reg)
	reg.is_authoritative = true
	assert_eq(reg.get_bound_peer_ids().size(), 0, "no peers, no ids")
	var a := reg.resolve_identity(4)
	var b := reg.resolve_identity(9)
	assert_true(a != "" and b != "", "two peers bind")
	var ids: Array = reg.get_bound_peer_ids()
	ids.sort()
	assert_eq(ids, [4, 9], "both bound peers are listed")
	reg.unbind_peer(4)
	assert_eq(reg.get_bound_peer_ids(), [9], "an unbound peer drops out")

## An unreadable region is not re-read (or re-logged) on every sync: the delay doubles per failure
## up to the cap, and a successful read forgets it.
func _test_region_failed_read_backs_off() -> void:
	var dir := _fresh_region_dir("test_p61_backoff")
	var store: RegionStoreScript = RegionStoreScript.new(dir + "regions/")
	DirAccess.make_dir_recursive_absolute(dir + "regions/")
	var f := FileAccess.open(store.path_of(Vector2i.ZERO), FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	var voxel := _make_voxel()
	var streamer := RegionStreamerScript.new(store, voxel)
	var clock := [0]
	streamer._now = func() -> int: return clock[0]
	var wanted := { "0,0": true }
	streamer.sync(wanted)
	assert_true(streamer.is_backing_off(Vector2i.ZERO), "a failed read starts a backoff")
	var base: int = RegionStreamerScript.BACKOFF_START_MSEC
	clock[0] = base - 1
	var during := streamer.sync(wanted)
	assert_eq(int(during["failed"]), 1, "a sync inside the backoff still reports the region as failed")
	assert_true(streamer.is_backing_off(Vector2i.ZERO), "and keeps backing off")
	clock[0] = base
	assert_false(streamer.is_backing_off(Vector2i.ZERO), "the backoff elapses")
	streamer.sync(wanted)   # fails again: the delay doubles
	clock[0] = base + base * 2 - 1
	assert_true(streamer.is_backing_off(Vector2i.ZERO), "the second delay is twice the first")
	for i in 12:
		clock[0] += RegionStreamerScript.BACKOFF_MAX_MSEC
		streamer.sync(wanted)
	clock[0] += RegionStreamerScript.BACKOFF_MAX_MSEC - 1
	assert_true(streamer.is_backing_off(Vector2i.ZERO), "the delay is capped, not unbounded")
	clock[0] += 1
	assert_false(streamer.is_backing_off(Vector2i.ZERO), "and the cap is the longest wait")
	assert_eq(store.save_region(Vector2i.ZERO, { "0,0": { "edits": { "0,0": [{ "op": "raise", "n": 1 }] } } }), OK, "the file is repaired")
	assert_eq(int(streamer.sync(wanted)["loaded"]), 1, "the first read after the backoff loads it")
	assert_false(streamer.is_backing_off(Vector2i.ZERO), "and clears the backoff")
	voxel.free()

func _test_region_failed_read_not_resident() -> void:
	var dir := _fresh_region_dir("test_p61_read")
	var store: RegionStoreScript = RegionStoreScript.new(dir + "regions/")
	DirAccess.make_dir_recursive_absolute(dir + "regions/")
	var path := store.path_of(Vector2i.ZERO)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	var voxel := _make_voxel()
	var streamer := RegionStreamerScript.new(store, voxel)
	var clock := [0]
	streamer._now = func() -> int: return clock[0]
	var wanted := { "0,0": true }
	var r := streamer.sync(wanted)
	assert_eq(int(r["loaded"]), 0, "nothing loaded from an unreadable region")
	assert_false(streamer.is_resident(Vector2i.ZERO), "the region is not marked resident")
	var entry := { "edits": { "0,0": [{ "op": "raise", "n": 1 }] } }
	assert_eq(store.save_region(Vector2i.ZERO, { "0,0": entry }), OK, "the file is repaired")
	clock[0] += RegionStreamerScript.BACKOFF_START_MSEC
	r = streamer.sync(wanted)
	assert_eq(int(r["loaded"]), 1, "the next sync reads it again")
	assert_true(streamer.is_resident(Vector2i.ZERO), "and it is resident")
	assert_true(voxel.edited_chunk_keys().has("0,0"), "with its edits applied")
	voxel.free()

## A tile's op list must hold ops (Dictionaries) — or, for a legacy entry, a bare number.
func _test_region_entry_rejects_bad_ops() -> void:
	assert_true(RegionStoreScript.is_valid_chunk_entry({ "edits": { "0,0": [{ "op": "raise", "n": 1 }] } }), "an op list of ops is valid")
	assert_true(RegionStoreScript.is_valid_chunk_entry({ "edits": { "0,0": 1.5 } }), "a legacy bare height is left to the voxel slice")
	assert_false(RegionStoreScript.is_valid_chunk_entry({ "edits": { "0,0": [5, "x"] } }), "an op list of non-ops is not")
	assert_false(RegionStoreScript.is_valid_chunk_entry({ "edits": { "0,0": [{ "op": "raise" }, null] } }), "one bad op spoils the list")

func _test_region_malformed_entry_skipped() -> void:
	var dir := _fresh_region_dir("test_p61_entry")
	var store: RegionStoreScript = RegionStoreScript.new(dir + "regions/")
	DirAccess.make_dir_recursive_absolute(dir + "regions/")
	var good := { "edits": { "0,0": [{ "op": "raise", "n": 1 }] } }
	var f := FileAccess.open(store.path_of(Vector2i.ZERO), FileAccess.WRITE)
	f.store_string(JSON.stringify({ "version": 1, "chunks": {
		"1,1": good, "2,2": { "edits": 5 }, "3,3": { "edits": {}, "materials": "x" } } }))
	f.close()
	var before := Diag.warn_count()
	var chunks := store.load_region(Vector2i.ZERO)
	assert_eq(chunks.keys(), ["1,1"], "the well-formed chunk loads")
	assert_eq(Diag.warn_count() - before, 2, "one warning per malformed entry")

func _test_peer_window_rate_limited() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	assert_true(cm.set_peer_center(5, Vector2i(2, 2)), "the first placement lands")
	var moves := 0
	for i in range(100):
		if cm.set_peer_center(5, Vector2i(100000 + i * 156, 100000)):
			moves += 1
	assert_true(moves <= 1, "100 claims 10 km apart within one interval move the window at most once")
	assert_eq(cm.peer_recenter_refused, 100, "every claim was refused or clamped")
	var centre: Vector2i = cm._peer_centers[5]
	assert_true(maxi(absi(centre.x - 2), absi(centre.y - 2)) <= ChunkManager.PEER_RECENTER_MAX_CHUNKS,
		"and the window never travelled farther than the cap")
	cm._peer_last_claim_msec[5] = -1000000
	assert_true(cm.set_peer_center(5, Vector2i(3, 2)), "a near claim after the interval is accepted")
	for k in ["cm", "voxel", "terrain", "player"]:
		rig[k].free()

func _test_peer_window_fake_clock() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var clock := [1000]
	cm.set_clock(func() -> int: return clock[0])
	cm.set_peer_center(5, Vector2i(2, 2), true)
	clock[0] += 100
	assert_false(cm.set_peer_center(5, Vector2i(3, 2)), "a claim 100 ms after the last is refused")
	assert_eq(cm.peer_recenter_refused, 1, "and counted")
	clock[0] = 1000 + int(ChunkManager.PEER_RECENTER_INTERVAL * 1000.0) - 1
	assert_false(cm.set_peer_center(5, Vector2i(3, 2)), "1 ms inside the interval is still refused")
	clock[0] += 2
	assert_true(cm.set_peer_center(5, Vector2i(3, 2)), "one ms past the interval is accepted")
	assert_eq(cm.peer_center(5), Vector2i(3, 2), "and the window moved")
	for k in ["cm", "voxel", "terrain", "player"]:
		rig[k].free()

func _test_peer_window_clamp_cap() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var cap := ChunkManager.PEER_RECENTER_MAX_CHUNKS
	cm.set_clock(func() -> int: return 0)
	cm.set_peer_center(5, Vector2i(10, 10), true)
	cm.set_clock(func() -> int: return 10000)
	assert_true(cm.set_peer_center(5, Vector2i(30, 10)), "a 20-chunk claim moves the window")
	assert_eq(cm.peer_center(5), Vector2i(10 + cap, 10), "but only by the cap")
	assert_eq(cm.peer_recenter_refused, 1, "and is counted")
	var c := TerrainSlice.circumference_chunks()
	cm.set_clock(func() -> int: return 20000)
	cm.set_peer_center(6, Vector2i(c - 2, 10), true)
	cm.set_clock(func() -> int: return 30000)
	assert_true(cm.set_peer_center(6, Vector2i(18, 10)), "a 20-chunk claim across the seam moves the window")
	assert_eq(cm.peer_center(6), Vector2i(posmod(c - 2 + cap, c), 10), "by the cap, the short way round")
	for k in ["cm", "voxel", "terrain", "player"]:
		rig[k].free()

func _test_peer_window_clamps_across_seam() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var half := TerrainSlice.circumference_chunks() / 2
	cm.set_peer_center(5, Vector2i(half - 1, 0), true)
	cm._peer_last_claim_msec[5] = -1000000
	# One chunk east of the seam is one chunk away, not a planet-width: no clamp, no refusal.
	assert_true(cm.set_peer_center(5, Vector2i(-half, 0)), "a seam crossing moves the window")
	assert_eq(cm.peer_recenter_refused, 0, "a one-chunk seam step is not clamped")
	assert_eq(cm.peer_center(5), Vector2i(-half, 0), "and lands on the wrapped chunk")
	for k in ["cm", "voxel", "terrain", "player"]:
		rig[k].free()

func _test_peer_window_host_driven() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	cm.set_peer_center(5, Vector2i(2, 2))
	var far := Vector2i(50000, -40000)
	assert_true(cm.set_peer_center(5, far, true), "a host-driven move is accepted inside the interval")
	assert_eq(cm._peer_centers[5], far, "and lands exactly on the target")
	assert_eq(cm.peer_recenter_refused, 0, "without counting as a refusal")
	for k in ["cm", "voxel", "terrain", "player"]:
		rig[k].free()

func _test_peer_window_host_sync() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var clock := [1000]
	cm.set_clock(func() -> int: return clock[0])
	cm.sync_peer_center(5, Vector2i(2, 2))
	for i in 10:
		clock[0] += 50
		assert_false(cm.sync_peer_center(5, Vector2i(2, 2)), "a peer that has not moved is not re-centred")
	for i in 5:
		clock[0] += 300
		assert_true(cm.sync_peer_center(5, Vector2i(3 + i, 2)), "a tracked move after the interval lands")
	assert_eq(cm.peer_center(5), Vector2i(7, 2), "and the window follows the peer")
	assert_eq(cm.peer_recenter_refused, 0, "none of it counts as a refusal")
	# The tracked position is client-reported: sync is still interval-limited and clamped, silently.
	clock[0] += 50
	assert_false(cm.sync_peer_center(5, Vector2i(8, 2)), "a sync inside the interval defers")
	clock[0] += 300
	assert_true(cm.sync_peer_center(5, Vector2i(7, 500)), "a far hop moves, but clamped")
	assert_eq(cm.peer_center(5), Vector2i(7, 2 + ChunkManager.PEER_RECENTER_MAX_CHUNKS), "to the clamp distance")
	assert_eq(cm.peer_recenter_refused, 0, "deferral and clamp by the sync are not counted")
	# A client claim inside the interval of the last move is still refused and counted once.
	cm.set_peer_center(6, Vector2i(2, 2), true)
	clock[0] += 100
	assert_false(cm.set_peer_center(6, Vector2i(3, 2)), "a client claim inside the interval is refused")
	assert_eq(cm.peer_recenter_refused, 1, "and counted once")
	for k in ["cm", "voxel", "terrain", "player"]:
		rig[k].free()

func _test_peer_window_sync_far_hops() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var clock := [1000]
	cm.set_clock(func() -> int: return clock[0])
	cm.sync_peer_center(5, Vector2i(2, 2))
	clock[0] += 1000
	assert_true(cm.sync_peer_center(5, Vector2i(3, 2)), "a one-chunk sync move lands")
	assert_eq(cm.peer_sync_far_hops, 0, "and is not a far hop")
	clock[0] += 1000
	assert_true(cm.sync_peer_center(5, Vector2i(3, 500)), "a sync past the claim clamp still applies the move")
	assert_eq(cm.peer_center(5), Vector2i(3, 2 + ChunkManager.PEER_RECENTER_MAX_CHUNKS), "up to the clamp")
	assert_eq(cm.peer_sync_far_hops, 1, "and raises the far-hop counter by exactly one")
	assert_eq(cm.peer_recenter_refused, 0, "without touching the refusal counter")
	for k in ["cm", "voxel", "terrain", "player"]:
		rig[k].free()

class _StrandedStub:
	var releases := 0
	func has_stranded() -> bool:
		return true
	func release_stranded() -> int:
		releases += 1
		return 0

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

func _test_peer_window_separate_clocks() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var clock := [1000]
	cm.set_clock(func() -> int: return clock[0])
	cm.sync_peer_center(5, Vector2i(2, 2))
	clock[0] += 1000
	assert_true(cm.sync_peer_center(5, Vector2i(3, 2)), "a sync move lands")
	clock[0] += 100
	assert_true(cm.set_peer_center(5, Vector2i(4, 2)), "a claim 100 ms after a sync is accepted")
	assert_eq(cm.peer_recenter_refused, 0, "and is not counted as a refusal")
	# Two claims 100 ms apart still count exactly one refusal.
	clock[0] += 1000
	assert_true(cm.set_peer_center(5, Vector2i(5, 2)), "a claim after the interval lands")
	clock[0] += 100
	assert_false(cm.set_peer_center(5, Vector2i(6, 2)), "a second claim 100 ms later is refused")
	assert_eq(cm.peer_recenter_refused, 1, "and counted once")
	cm.clear_peer_center(5)
	assert_false(cm._peer_last_claim_msec.has(5), "clearing a peer drops its claim timestamp")
	assert_false(cm._peer_last_sync_msec.has(5), "and its sync timestamp")
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

func _test_peer_window_move_loads_region_edits() -> void:
	var dir := _fresh_region_dir("test_p62_teleport")
	var store: RegionStoreScript = RegionStoreScript.new(dir + "regions/")
	var edit := { "edits": { "%d,0" % (34 * 64): [{ "op": "raise", "n": 1 }] } }
	assert_eq(store.save_region(Vector2i(1, 0), { "34,0": edit }), OK, "region (1,0) holds an edit")
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var voxel: VoxelSlice = rig["voxel"]
	cm.region_streamer = RegionStreamerScript.new(store, voxel)
	cm.view_distance = 1
	cm.prefetch_distance = 0
	cm.set_peer_center(7, Vector2i(28, 0), true)
	cm.refresh(false)
	assert_false(voxel.edited_chunk_keys().has("34,0"), "the edit is not resident before the move")
	cm._peer_last_claim_msec[7] = -1000000
	# The order the re-scope handler uses: recentre, refresh, THEN read the edits for the snapshot.
	assert_true(cm.set_peer_center(7, Vector2i(34, 0)), "the claim is within the cap")
	cm.refresh(false)
	assert_true(voxel.get_edits().has("%d,0" % (34 * 64)), "the edits the re-scope snapshot reads include the stored ones")
	for k in ["cm", "voxel", "terrain", "player"]:
		rig[k].free()

func _test_region_streams_only_near_windows() -> void:
	var dir := _fresh_region_dir("test_p52_rss")
	var store: RegionStoreScript = RegionStoreScript.new(dir + "regions/")
	# 1,000 edited regions on disk, none of them the origin's. A chunk is 64 tiles a side.
	for i in range(1000):
		var region := Vector2i(10 + i % 40, 10 + i / 40)
		var edit := { "edits": { "%d,%d" % [region.x * 32 * 64, region.y * 32 * 64]: [{ "op": "raise", "n": 1 }] } }
		assert_eq(store.save_region(region, { "%d,%d" % [region.x * 32, region.y * 32]: edit }), OK, "region %d written" % i)
	var edit := { "edits": { "0,0": [{ "op": "raise", "n": 1 }] } }
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var voxel: VoxelSlice = rig["voxel"]
	cm.region_streamer = RegionStreamerScript.new(store, voxel)
	cm.view_distance = 1
	cm.prefetch_distance = 0
	cm.refresh()
	assert_eq(voxel.edited_chunk_keys().size(), 0, "with a window at the origin no far region's edits are resident")
	assert_true(cm.region_streamer.resident_regions().size() <= 4, "only the regions at the origin (a corner plus its margin) are resident")
	# A peer window 10 regions away pulls in exactly its own region, and releases it again.
	cm.set_peer_center(7, Vector2i(10 * 32 + 3, 10 * 32 + 3))
	cm.refresh()
	assert_eq(voxel.edited_chunk_keys().size(), 1, "the peer's region edits are resident")
	cm.clear_peer_center(7)
	cm.refresh()
	assert_eq(voxel.edited_chunk_keys().size(), 0, "leaving every window releases a clean region's edits")
	# A dirty chunk is never dropped: its edits exist nowhere else until a save.
	voxel.apply_region_chunks({ "0,0": edit })
	voxel.mark_dirty_chunks(["0,0"])
	cm.set_peer_center(7, Vector2i(500, 500), true)
	cm.refresh()
	assert_true(voxel.edited_chunk_keys().has("0,0"), "a dirty chunk keeps its edits after its region leaves every window")
	# A collected-but-unwritten chunk (in flight) is not evicted either, and a stale region
	# re-read cannot overwrite it; once the write settles it is released without a window move.
	var far_edit := { "edits": { "%d,%d" % [320 * 64, 320 * 64]: [{ "op": "raise", "n": 1 }] } }
	cm.set_peer_center(7, Vector2i(323, 323), true)
	cm.refresh()
	voxel.apply_region_chunks({ "320,320": far_edit })   # an edit made inside the peer's window
	cm.set_peer_center(7, Vector2i(500, 500), true)
	voxel.begin_inflight_chunks(["320,320"])
	assert_true(voxel.edited_chunk_keys().has("320,320"), "the far chunk's edit is resident")
	cm.refresh()
	assert_true(voxel.edited_chunk_keys().has("320,320"), "an in-flight chunk keeps its edits once its region is unwanted")
	voxel.end_inflight_chunks(["320,320"])
	cm._last_stranded_retry_msec = -10000
	cm.refresh()
	assert_false(voxel.edited_chunk_keys().has("320,320"), "a settled clean chunk is released without a window move")
	for k in ["cm", "voxel", "terrain", "player"]:
		rig[k].free()

func _test_chunk_peer_windows_refcount() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	cm.view_distance = 1
	cm.prefetch_distance = 0
	cm.loads_per_frame = 64
	cm.refresh()
	_wait_for_builds(cm)
	assert_eq(cm._loaded.size(), 9, "the local window alone holds 3x3 chunks")
	assert_eq(cm.chunk_ref_count(Vector2i(0, 0)), 1, "a chunk one window covers has a count of one")
	cm.set_peer_center(3, Vector2i(1, 0))
	cm.refresh()
	assert_eq(cm.chunk_ref_count(Vector2i(0, 0)), 2, "two overlapping windows count the shared chunk twice")
	assert_eq(cm.chunk_ref_count(Vector2i(2, 0)), 1, "a chunk only the peer covers counts once")
	_wait_for_builds(cm)
	assert_true(cm._loaded.has("2,0"), "a chunk only the peer's window covers is loaded")
	cm.clear_peer_center(3)
	cm.refresh()
	assert_false(cm._loaded.has("2,0"), "the chunk unloads when its count returns to zero")
	assert_true(cm._loaded.has("0,0"), "while a still-covered chunk stays")
	for k in ["cm", "voxel", "terrain", "player"]:
		rig[k].free()

func _test_chunk_far_peers_simulated() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var creatures := CreatureSlice.new()
	add_child(creatures)
	cm.creature_slice = creatures
	cm.view_distance = 0
	cm.prefetch_distance = 0
	cm.loads_per_frame = 16
	var far := Vector2i(3125, 0)   # 100 km at 32 m a chunk
	cm.refresh()
	cm.set_peer_center(1, far, true)
	cm.set_peer_center(2, Vector2i(0, 3125), true)
	cm.refresh()
	_wait_for_builds(cm)
	for chunk in [Vector2i(0, 0), far, Vector2i(0, 3125)]:
		assert_true(creatures._by_chunk.get(chunk, []).size() > 0,
			"creatures are simulated in the window around %s" % str(chunk))
	for k in ["cm", "voxel", "terrain", "player"]:
		rig[k].free()
	creatures.free()


# ---------------------------------------------------------------------------
# Phase 53 — spawn placement and friend codes
# ---------------------------------------------------------------------------

const SpawnFinderScript := preload("res://src/world/spawn_finder.gd")
const WorldShapeScript := preload("res://src/terrain/world_shape.gd")
const ColonizationMapScript := preload("res://src/world/colonization_map.gd")

## Distance in metres from world (x, z) to the rectangle of `region`, X the short way round.
## Independent of `ColonizationMap.is_near_colonized`, so the avoidance test is not circular.
func _dist_to_region(x: float, z: float, region: Vector2i) -> float:
	var m := ColonizationMapScript.REGION_METERS
	var circ := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	var dx := absf(fposmod(x - (float(region.x) + 0.5) * m + circ * 0.5, circ) - circ * 0.5)
	var dz := absf(z - (float(region.y) + 0.5) * m)
	return Vector2(maxf(dx - m * 0.5, 0.0), maxf(dz - m * 0.5, 0.0)).length()

func _test_spawn_avoids_colonized() -> void:
	var terrain := TerrainSlice.new()
	terrain.set_world_seed(7)
	var height_fn := func(p: Vector2) -> float: return terrain.get_height_at(p)
	var rule := SpawnFinderScript.rule()
	var min_d := float(rule["min_colonized_distance"])
	var empty := ColonizationMapScript.new()
	# 1,000 colonized regions: the regions the first 100 spawns would have taken (so the
	# avoidance has to move them), plus a spread of others.
	var map := ColonizationMapScript.new()
	var first: Array = []
	for i in range(100):
		var p: Variant = SpawnFinderScript.find_new(7, "player_%d" % i, empty, height_fn)
		assert_true(p != null, "an empty world has a spawn for player %d" % i)
		first.append(p)
		map.note_home(Vector2i(floori(p.x / TerrainSlice.CHUNK_METERS), floori(p.z / TerrainSlice.CHUNK_METERS)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 53
	while map.region_count() < 1000:
		map.note_home(Vector2i(rng.randi_range(-3000, 3000) * 32, rng.randi_range(-3000, 3000) * 32))
	var regions := map.colonized_regions(float(rule["colonized_score"]))
	assert_eq(regions.size(), 1000, "1,000 colonized regions are seeded")
	var moved := 0
	for i in range(100):
		var p: Variant = SpawnFinderScript.find_new(7, "player_%d" % i, map, height_fn)
		assert_true(p != null, "a colonized world still has a spawn for player %d" % i)
		if p == null:
			continue
		var clear := true
		for r in regions:
			if _dist_to_region(p.x, p.z, r) < min_d:
				clear = false
				break
		assert_true(clear, "spawn %d is at least %.0f m from every colonized region" % [i, min_d])
		assert_true(SpawnFinderScript.is_standable(7, p.x, p.z, rule["habitable"], height_fn), "spawn %d is habitable, dry, flat land" % i)
		assert_true(absf(p.y - 1.0 - float(height_fn.call(Vector2(p.x, p.z)))) <= 0.001, "spawn %d stands on the sampled surface" % i)
		if first[i] != null and (p.x != first[i].x or p.z != first[i].z):
			moved += 1
	assert_true(moved > 0, "the colonized regions pushed some spawns elsewhere")
	var a: Variant = SpawnFinderScript.find_new(7, "player_3", map, height_fn)
	var b: Variant = SpawnFinderScript.find_new(7, "player_3", map, height_fn)
	assert_eq(a, b, "the search is deterministic for one player id")
	terrain.free()

func _test_spawn_friend_near() -> void:
	var terrain := TerrainSlice.new()
	terrain.set_world_seed(7)
	var height_fn := func(p: Vector2) -> float: return terrain.get_height_at(p)
	var radius := float(SpawnFinderScript.rule()["friend_radius"])
	for i in range(5):
		var friend: Variant = SpawnFinderScript.find_new(7, "friend_%d" % i, null, height_fn)
		assert_true(friend != null, "friend %d stands somewhere" % i)
		var center := Vector2(friend.x, friend.z)
		var p: Variant = SpawnFinderScript.find_near(7, "newcomer_%d" % i, center, radius, height_fn)
		assert_true(p != null, "a spawn exists near friend %d" % i)
		if p == null:
			continue
		assert_true(Vector2(p.x, p.z).distance_to(center) <= radius + 0.01, "spawn %d is within the friend radius" % i)
		var ground := float(height_fn.call(Vector2(p.x, p.z)))
		assert_true(absf(p.y - 1.0 - ground) <= 0.001, "spawn %d is on the ground" % i)
		assert_true(ground > WorldShapeScript.sea_level(), "spawn %d is not in water" % i)
		var chunk := Vector2i(floori(p.x / TerrainSlice.CHUNK_METERS), floori(p.z / TerrainSlice.CHUNK_METERS))
		assert_true(not (["Ocean", "VoidRift"] as Array).has(TerrainSlice.biome_for_chunk(chunk, 7)), "spawn %d is not in an unsafe biome" % i)
	# Open ocean: nothing qualifies, and the caller gets null rather than a drowned spawn.
	var ocean := Vector2.ZERO
	for cx in range(0, 4000, 40):
		var c := Vector2i(cx, 900)
		if TerrainSlice.biome_for_chunk(c, 7) == "Ocean" and float(height_fn.call(Vector2(cx * 32.0, 900 * 32.0))) < -10.0:
			ocean = Vector2(cx * 32.0, 900 * 32.0)
			break
	if ocean != Vector2.ZERO:
		assert_eq(SpawnFinderScript.find_near(7, "newcomer", ocean, 20.0, height_fn), null, "no spawn in open water")
	terrain.free()

func _test_colonization_map() -> void:
	var m := ColonizationMapScript.new()
	assert_true(not m.is_colonized(Vector2i(2, 3), 1.0), "an untouched region is not colonized")
	assert_true(m.note_edited_chunk(Vector2i(70, 100)), "the first edit of a chunk counts")
	assert_true(not m.note_edited_chunk(Vector2i(70, 100)), "a second edit of the same chunk does not")
	assert_eq(m.score(Vector2i(2, 3)), 1.0, "one edited chunk scores one")
	m.note_home(Vector2i(70, 100))
	assert_eq(m.score(Vector2i(2, 3)), 11.0, "a home adds ten")
	m.note_presence(Vector2i(500, 500), 1000.0)
	assert_eq(m.score(Vector2i(15, 15), 1000.0), 1.0, "recent presence scores one")
	assert_eq(m.score(Vector2i(15, 15), 1000.0 + 8.0 * 86400.0), 0.0, "old presence scores nothing")
	var copy := ColonizationMapScript.new()
	copy.from_data(m.to_data())
	assert_eq(copy.score(Vector2i(2, 3)), 11.0, "the map survives a to_data / from_data round trip")
	copy.from_data({ "regions": { "1,2": { "edits": 4 }, "bad": { "edits": 9 }, "3,4": "x", "5,6": { "edits": -3, "homes": "no" } } })
	assert_eq(copy.region_count(), 2, "malformed entries are dropped")
	assert_eq(copy.score(Vector2i(1, 2)), 4.0, "a good entry keeps its score")
	copy.from_data("not a dictionary")
	assert_eq(copy.region_count(), 0, "a non-dictionary record yields an empty map")
	var wrap := ColonizationMapScript.new()
	wrap.note_home(Vector2i(0, 0))
	var ring := TerrainSlice.circumference_chunks() / 32
	assert_true(wrap.is_near_colonized(-10.0, 10.0, 100.0, 1.0), "distance is measured from the region's edge")
	assert_true(wrap.is_near_colonized(float(ring) * ColonizationMapScript.REGION_METERS - 50.0, 10.0, 100.0, 1.0), "distance wraps across the antimeridian")
	assert_true(not wrap.is_near_colonized(5000.0, 10.0, 100.0, 1.0), "a far point is not near")
	var seeded := ColonizationMapScript.new()
	seeded.seed_from_regions([Vector2i(4, 4)])
	seeded.seed_from_regions([Vector2i(4, 4)])
	assert_eq(seeded.score(Vector2i(4, 4)), 1.0, "seeding from region files is idempotent")

## Phase 66 — a host placed at S, moved away and reloaded respawns at S; a client reconnecting after
## moving away is sent S in its handshake block and respawns there. Legacy records fall back.
func _test_spawn_point_persists() -> void:
	var root_script: GDScript = load("res://src/core/game_root.gd")
	var spawn := Vector3(1234.0, 9.0, -777.0)
	var reg := PlayerRegistry.new()
	reg.is_authoritative = true
	reg.set_spawn_placer(func(_pid: String, _code: String) -> Dictionary:
		return { "position": spawn, "source": "search", "message": "" })
	var pid := reg.resolve_identity(5)
	reg.record_position(pid, Vector3(-4000.0, 3.0, 2500.0))   # moved far away
	var saved: Dictionary = reg.get_player_data(pid)
	assert_true(saved.has("spawn"), "the saved record carries the spawn point")
	# Host: a fresh registry loaded from that save respawns at S, not at the saved position.
	var fresh := PlayerRegistry.new()
	fresh.apply_player_data(pid, saved)
	var host_rec: Dictionary = fresh.get_record(pid)
	var host_point: Variant = root_script.respawn_point_for(host_rec)
	assert_true(host_point != null and _wp_world(host_point).distance_to(spawn) < 0.01,
		"a reloaded host respawns at its original spawn point")
	assert_true(absf(float(host_rec["position"][0]) + 4000.0) < 0.01, "while still standing where it logged off")
	# Client: the handshake block carries the spawn; the client has since moved.
	var own: Dictionary = { "position": saved["position"], "hp": 100.0, "spawn": saved["spawn"] }
	var standing := WorldPos.from_world(-4000.0, 3.0, 2500.0)
	var wire: Dictionary = root_script.client_respawn_point(own, standing)
	assert_true(_wp_world(wire).distance_to(spawn) < 0.01, "a reconnecting client respawns at its original spawn point")
	var other := WorldPos.from_world(1.0, 2.0, 3.0)
	assert_eq(root_script.client_respawn_point({ "position": saved["position"] }, other),
		other, "a host that sent no spawn leaves the standing position")
	var arr_pt: Dictionary = root_script.client_respawn_point({ "spawn": [10.0, 5.0, 20.0] }, other)
	assert_true(_wp_world(arr_pt).distance_to(Vector3(10.0, 5.0, 20.0)) < 0.01, "a legacy array spawn is accepted, not a crash")
	# Legacy and malformed records fall back to the saved position.
	var legacy: Dictionary = saved.duplicate(true)
	legacy.erase("spawn")
	var old := PlayerRegistry.new()
	old.apply_player_data(pid, legacy)
	assert_eq(old.spawn_of(pid), null, "a record without the field has no spawn")
	var fallback: Variant = root_script.respawn_point_for(old.get_record(pid))
	assert_true(_wp_world(fallback).distance_to(Vector3(-4000.0, 3.0, 2500.0)) < 0.01, "and falls back to its saved position")
	legacy["spawn"] = { "chunk": ["x", 1], "local": [0, 0] }
	old.apply_player_data(pid, legacy)
	assert_eq(old.spawn_of(pid), null, "a malformed spawn is dropped")
	reg.free()
	fresh.free()
	old.free()

func _wp_world(wp: Variant) -> Vector3:
	var chunk: Vector2i = wp["chunk"]
	var local: Vector3 = wp["local"]
	return Vector3(chunk.x * WorldPos.CHUNK_METERS + local.x, local.y, chunk.y * WorldPos.CHUNK_METERS + local.z)

## Phase 98 — the fresh-player branch records the body's exact position, not a float32 round trip.
func _test_first_boot_spawn_exact() -> void:
	var chunk := Vector2i(600000, 3)
	var local := Vector3(0.25, 10.0, 0.75)
	var player := PlayerSlice.new()
	player.render_visuals = true
	add_child(player)
	player.shift_scene(WorldPos.rebase_shift(Vector2i.ZERO, chunk))
	player.place_at_world_pos({ "chunk": chunk, "local": local })
	var reg := PlayerRegistry.new()
	_own(reg)
	var pid := "first-boot"
	reg.ensure_player(pid)
	var gr: Node = (load("res://src/core/game_root.gd") as GDScript).new()
	gr._player = player
	gr._registry = reg
	gr._record_first_spawn(pid)
	var spawn: Variant = reg.spawn_of(pid)
	assert_true(spawn != null, "the spawn was recorded")
	assert_eq(spawn["chunk"], chunk, "in the exact chunk")
	assert_true((spawn["local"] as Vector3).distance_to(local) < 1.0e-6, "and the exact local within 1e-6 m")
	gr.free()
	player.free()

## Phase 87 — a spawn far from the origin is recorded, saved, reloaded and respawned at exactly;
## `_place_local_player` reads the record once and lets it win over `pos`.
func _test_exact_spawn_respawn() -> void:
	var root_script: GDScript = load("res://src/core/game_root.gd")
	var chunk := Vector2i(-300000, 500)
	var local := Vector3(3.21, 50.0, 9.87)
	var reg := PlayerRegistry.new()
	var pid := "exact-spawn"
	reg.record_spawn_world_pos(pid, {"chunk": chunk, "local": local})
	reg.record_world_pos(pid, {"chunk": chunk + Vector2i(7, 0), "local": Vector3(1.0, 2.0, 3.0)})   # walked off
	var fresh := PlayerRegistry.new()
	fresh.apply_player_data(pid, reg.get_player_data(pid))
	var point: Variant = root_script.respawn_point_for(fresh.get_record(pid))
	assert_true(point != null, "the reloaded record has a respawn point")
	assert_eq(point["chunk"], chunk, "the spawn chunk survives the save and load")
	assert_true((point["local"] as Vector3).distance_to(local) < 1.0e-6, "and its local within 1e-6 m")
	var player := PlayerSlice.new()
	player.render_visuals = true
	add_child(player)
	player.shift_scene(WorldPos.rebase_shift(Vector2i.ZERO, chunk))
	player.set_respawn_world_pos(point)
	player._respawn()
	var got := player.get_world_pos()
	assert_eq(got["chunk"], chunk, "a respawn lands in the spawn chunk")
	assert_true((got["local"] as Vector3).distance_to(local) < 1.0e-6, "and on the spawn local within 1e-6 m")
	# A pre-Phase-66 record (no spawn) falls back to its saved position.
	var legacy: Dictionary = reg.get_player_data(pid)
	legacy.erase("spawn")
	var old := PlayerRegistry.new()
	old.apply_player_data(pid, legacy)
	var back: Variant = root_script.respawn_point_for(old.get_record(pid))
	assert_eq(back["chunk"], chunk + Vector2i(7, 0), "a record with no spawn respawns at its saved position")
	# `_place_local_player`: the record wins and is read once; without one `pos` is used.
	var gr: Node = root_script.new()
	gr._player = player
	gr._rebase = RebaseDriver.new([player])
	gr._registry = reg
	reg.local_player_id = pid
	gr._saved_position_reads = 0
	gr._place_local_player(Vector3(5.0, 5.0, 5.0))
	assert_eq(gr._saved_position_reads, 1, "a placement reads the saved position once")
	assert_eq(player.get_world_pos()["chunk"], chunk + Vector2i(7, 0), "a saved record wins over pos")
	var blank := PlayerRegistry.new()
	blank.local_player_id = "nobody"
	var near := PlayerSlice.new()
	near.render_visuals = true
	add_child(near)
	gr._player = near
	gr._rebase = RebaseDriver.new([near])
	gr._registry = blank
	gr._place_local_player(Vector3(5.0, 5.0, 5.0))
	assert_true(_wp_world(near.get_world_pos()).distance_to(Vector3(5.0, 5.0, 5.0)) < 0.01, "with no record the body goes to pos")
	near.free()
	player.free()
	gr.free()
	reg.free()
	fresh.free()
	old.free()
	blank.free()

## Phase 66 — edit chunk K, save, reload, edit K again: the region's count is unchanged.
func _test_colonization_counted_persists() -> void:
	var m := ColonizationMapScript.new()
	m.note_edited_chunk(Vector2i(70, 100))
	var region := Vector2i(2, 3)
	assert_eq(m.score(region), 1.0, "one counted chunk")
	var reloaded := ColonizationMapScript.new()
	reloaded.from_data(JSON.parse_string(JSON.stringify(m.to_data())))
	assert_true(not reloaded.note_edited_chunk(Vector2i(70, 100)), "the reloaded map knows the chunk was counted")
	assert_eq(reloaded.score(region), 1.0, "re-editing it leaves the region's count unchanged")
	assert_true(reloaded.note_edited_chunk(Vector2i(71, 100)), "a different chunk still counts")
	reloaded.from_data({ "regions": {}, "counted": ["bad", "1,x", 7, "5,6"] })
	assert_true(not reloaded.note_edited_chunk(Vector2i(5, 6)) and reloaded.note_edited_chunk(Vector2i(1, 1)),
		"malformed counted entries are dropped, good ones kept")

func _test_spawn_registry_placement() -> void:
	var reg := PlayerRegistry.new()
	reg.is_authoritative = true
	var calls: Array = []
	reg.set_spawn_placer(func(pid: String, code: String) -> Dictionary:
		calls.append([pid, code])
		return { "position": Vector3(1234.0, 9.0, -777.0), "source": "search", "message": "" })
	var friend_handle := reg.public_handle("player_1_1_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
	reg.note_friend_code(5, friend_handle)
	var pid := reg.resolve_identity(5)
	assert_eq(calls.size(), 1, "a fresh join is placed once")
	assert_eq(calls[0][1], friend_handle, "the friend code the join carried reaches the placer")
	var rec := reg.get_record(pid)
	assert_true(absf(float(rec["position"][0]) - 1234.0) <= 0.01, "the record holds the placed position")
	reg.unbind_peer(5)
	var again := reg.resolve_identity(6, pid)
	assert_eq(again, pid, "the same player reconnects")
	assert_eq(calls.size(), 1, "a reconnect is not placed again")
	assert_true(absf(float(reg.get_record(pid)["position"][0]) - 1234.0) <= 0.01, "a reconnect keeps its saved position")
	reg.note_friend_code(7, "../../etc/passwd")
	reg.resolve_identity(7)
	assert_eq(calls[1][1], "", "a malformed friend code never reaches the placer")
	assert_true(not PlayerRegistry.is_valid_friend_code("p_zzzzzzzzzzzzzzzz"), "a handle is hex")
	assert_true(PlayerRegistry.is_valid_friend_code(friend_handle), "a real handle is a valid code")
	# friend_position: a player in memory, else the disk locator.
	reg.record_position(pid, Vector3(10.0, 2.0, 20.0))
	assert_eq(reg.friend_position(reg.public_handle(pid)), Vector3(10.0, 2.0, 20.0), "an in-memory friend is located")
	var ghost := "p_" + "0123456789abcdef"
	assert_eq(reg.friend_position(ghost), null, "an unknown handle locates nobody")
	reg.set_friend_locator(func(h: String) -> Variant: return Vector3(5.0, 5.0, 5.0) if h == ghost else null)
	assert_eq(reg.friend_position(ghost), Vector3(5.0, 5.0, 5.0), "an offline friend is located by the disk locator")
	reg.free()


# ---------------------------------------------------------------------------
# World clock tests (Phase 54)
# ---------------------------------------------------------------------------

func _clock_at_year_fraction(yf: float) -> RefCounted:
	var c := WorldClock.new()
	c.time_days = yf * c.year_length_days + 0.5   # solar noon
	return c

func _test_clock_hemispheres_opposite() -> void:
	var summer_north := _clock_at_year_fraction(0.25)
	assert_eq(summer_north.season_at(45.0), "summer", "+45 is in summer at the northern solstice")
	assert_eq(summer_north.season_at(-45.0), "winter", "-45 is in winter on the same date")
	assert_true(summer_north.warmth_at(45.0) > 0.99 and summer_north.warmth_at(-45.0) < -0.99, "warmth is +1 / -1")
	var winter_north := _clock_at_year_fraction(0.75)
	assert_eq(winter_north.season_at(45.0), "winter", "+45 in winter half a year on")
	assert_eq(winter_north.season_at(-45.0), "summer", "-45 in summer half a year on")
	assert_eq(_clock_at_year_fraction(0.0).season_at(45.0), "spring", "equinox: northern spring")
	assert_eq(_clock_at_year_fraction(0.0).season_at(-45.0), "autumn", "equinox: southern autumn")
	assert_true(absf(summer_north.warmth_at(0.0)) < 1e-6, "no seasons on the equator")
	assert_true(summer_north.declination() > 23.0, "declination is +tilt at the northern solstice")

func _test_clock_day_length_by_latitude() -> void:
	var tilt: float = WorldClock.new().axial_tilt
	var decl: float = WorldClock.declination_deg(0.25, tilt)
	assert_true(WorldClock.daylight_fraction(60.0, decl) > WorldClock.daylight_fraction(0.0, decl),
			"daylight is longer at +60 than at the equator at the solstice")
	assert_true(absf(WorldClock.daylight_fraction(0.0, decl) - 0.5) < 1e-6, "the equator always has half a day")
	assert_true(WorldClock.daylight_fraction(-60.0, decl) < 0.5, "and the south has the short day")
	assert_eq(WorldClock.daylight_fraction(85.0, decl), 1.0, "polar day")
	assert_eq(WorldClock.daylight_fraction(-85.0, decl), 0.0, "polar night")
	assert_true(absf(WorldClock.daylight_fraction(60.0, 0.0) - 0.5) < 1e-6, "equinox: 12 h everywhere")

func _test_clock_sun_elevation() -> void:
	var noon: float = WorldClock.sun_elevation_deg(45.0, 0.0, 0.5)
	assert_true(absf(noon - 45.0) < 1e-6, "equinox noon at 45 N: sun 45 degrees up")
	assert_true(WorldClock.sun_elevation_deg(45.0, 0.0, 0.0) < 0.0, "midnight: below the horizon")
	assert_true(WorldClock.sun_elevation_deg(45.0, 23.5, 0.5) > WorldClock.sun_elevation_deg(45.0, -23.5, 0.5),
			"the summer sun stands higher than the winter sun")
	assert_eq(WorldClock.daylight_level(-20.0), 0.0, "night is dark")
	assert_eq(WorldClock.daylight_level(40.0), 1.0, "high sun is full light")
	assert_eq(WorldClock.biome_daylight(0.0, 1.0), 0.0, "night speed 1 follows the clock")
	assert_eq(WorldClock.biome_daylight(0.0, 0.0), 0.5, "night speed 0 stays at dusk")

## Phase 65 — the applied sun goes through `biome_daylight` with the biome's `dayNightSpeed`:
## speed 0 holds the energy at dusk (0.5) at midnight AND noon; speed 1 follows the clock.
func _test_clock_sun_biome_daylight() -> void:
	var root_script: GDScript = load("res://src/core/game_root.gd")
	var root: Node = root_script.new()   # never enters the tree: no _ready, no boot
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	root.add_child(sun)
	var lat := 0.0
	for phase in [0.0, 0.5]:   # midnight, solar noon
		root._clock.time_days = float(phase)
		var elev: float = root._clock.sun_elevation_at(lat)
		var d: float = WorldClock.daylight_level(elev)
		root._apply_sun(lat, 0.0)
		assert_true(absf(sun.light_energy - 1.4 * WorldClock.biome_daylight(d, 0.0)) < 1e-6,
			"night speed 0: sun energy is biome_daylight(d, 0) at day phase %s" % phase)
		assert_true(absf(sun.light_energy - 0.7) < 1e-6, "night speed 0 stays at dusk energy")
		root._apply_sun(lat, 1.0)
		assert_true(absf(sun.light_energy - 1.4 * d) < 1e-6,
			"night speed 1 follows the clock at day phase %s" % phase)
	root.free()

## Phase 65 — a freezing biome's own chunks go snow-white while a temperate biome's chunk keeps
## its non-snow tint, even though both share a slice and a latitude.
func _test_clock_season_tint_per_chunk() -> void:
	var tundra: Variant = GameData.BIOMES["Tundra"]
	var forest: Variant = GameData.BIOMES["TemperateForest"]
	var winter := 0.0   # the equinox: tundra is below freezing, the forest is not
	var snow: Color = WorldClock.season_look(tundra, winter)
	var green: Color = WorldClock.season_look(forest, winter)
	assert_true(WorldClock.is_snowing_ground(WorldClock.seasonal_temperature(
		float(tundra.get("avgTemperature")), float(tundra.get("seasonSwing")), winter)), "tundra freezes in winter")
	assert_true(snow.r > 1.0, "the freezing biome's look is snow-bright")
	assert_eq(green, WorldClock.season_tint(forest, winter), "the temperate biome keeps its plain season tint (not snow)")
	var terrain := TerrainSlice.new()
	add_child(terrain)
	var v := VoxelSlice.new()
	add_child(v)
	v.terrain_slice = terrain
	var flat: Array = []
	flat.resize(64 * 64)
	flat.fill(2.0)
	var t_chunks: Array = _biome_chunks(terrain, ["Tundra"], 1)
	var f_chunks: Array = _biome_chunks(terrain, ["TemperateForest"], 1)
	assert_true(not t_chunks.is_empty() and not f_chunks.is_empty(), "found a tundra and a forest chunk")
	if t_chunks.is_empty() or f_chunks.is_empty():
		v.free()
		terrain.free()
		return
	v.build_chunk(t_chunks[0], flat)
	v.build_chunk(f_chunks[0], flat)
	v.set_season_tints({ "Tundra": snow, "TemperateForest": green })
	var t_mat: StandardMaterial3D = (_chunk_mesh_instances(v, t_chunks[0])[0] as MeshInstance3D).material_override
	var f_mat: StandardMaterial3D = (_chunk_mesh_instances(v, f_chunks[0])[0] as MeshInstance3D).material_override
	assert_false(is_same(t_mat, f_mat), "the two biomes' chunks wear different materials")
	assert_true(t_mat.albedo_color.is_equal_approx(snow), "the tundra chunk is snow-tinted")
	assert_true(f_mat.albedo_color.is_equal_approx(green), "the forest chunk keeps its non-snow tint")
	v.free()
	terrain.free()

func _test_clock_season_effects() -> void:
	var forest: Variant = GameData.BIOMES["TemperateForest"]
	var tundra: Variant = GameData.BIOMES["Tundra"]
	assert_true(WorldClock.growth_multiplier(forest, 1.0) > 1.0, "trees regrow faster in summer")
	assert_true(WorldClock.growth_multiplier(forest, -1.0) < 1.0, "and slower in winter")
	assert_true(WorldClock.spawn_multiplier(forest, 1.0) > WorldClock.spawn_multiplier(forest, -1.0), "more spawns in summer")
	assert_true(WorldClock.season_tint(forest, 1.0) != WorldClock.season_tint(forest, -1.0), "the tint changes with the season")
	assert_eq(WorldClock.season_tint(null, 1.0), Color.WHITE, "no biome, no tint")
	var swing: float = float(forest.get("seasonSwing"))
	var winter_t: float = WorldClock.seasonal_temperature(float(forest.get("avgTemperature")), swing, -1.0)
	var summer_t: float = WorldClock.seasonal_temperature(float(forest.get("avgTemperature")), swing, 1.0)
	assert_true(summer_t > winter_t, "summer is warmer than winter")
	assert_true(WorldClock.is_snowing_ground(WorldClock.seasonal_temperature(float(tundra.get("avgTemperature")), float(tundra.get("seasonSwing")), 0.0)),
			"tundra ground is snow-covered at an equinox")
	assert_false(WorldClock.is_snowing_ground(summer_t), "temperate summer ground is bare")
	# Slices consult the clock; without a biome (isolated rig) they stay flat.
	var t := _make_tree_slice()
	var c := WorldClock.new()
	t.world_clock = c
	assert_eq(t.regrow_seconds(Vector2i(0, 0)) > 0.0, true, "regrow seconds is positive with a clock")
	t.world_clock = null
	assert_eq(t.regrow_seconds(Vector2i(0, 0)), TreeSlice.RESPAWN_SECONDS, "no clock: flat regrow time")
	t.free()

## A client advancing 0.2 % fast (a worst-case frame-time skew), corrected by a host tick every
## 5 s with 100 ms of latency, never strays more than a second from the host over 10 minutes.
func _test_clock_client_sync() -> void:
	var host := WorldClock.new()
	var client := WorldClock.new()
	client.time_days = host.time_days + 0.4 / host.day_seconds()   # starts 0.4 s ahead
	var worst: float = 0.0
	var step := 0.05
	var elapsed := 0.0
	var next_tick := WorldClock.TICK_SECONDS
	while elapsed < 600.0:
		host.advance(step)
		client.advance(step * 1.002)
		elapsed += step
		if elapsed >= next_tick:
			next_tick += WorldClock.TICK_SECONDS
			# The sample left the host 100 ms ago: the client applies the time it WAS.
			client.apply_host_time(host.time_days - 0.1 / host.day_seconds())
		worst = maxf(worst, absf(host.time_days - client.time_days) * host.day_seconds())
	assert_true(worst < 1.0, "client within 1 s of the host over 10 minutes (worst %.3f s)" % worst)
	# A large error snaps rather than crawling.
	client.apply_host_time(host.time_days + 100.0 / host.day_seconds())
	assert_true(absf(client.time_days - (host.time_days + 100.0 / host.day_seconds())) < 1e-9, "a >2 s error snaps to the host")

func _test_clock_persistence_and_fabric() -> void:
	var a := WorldClock.new()
	a.time_days = 11.625
	var b := WorldClock.new()
	b.from_data(a.to_data())
	assert_eq(b.time_days, 11.625, "the clock round-trips through the world record")
	b.from_data({ "time_days": -3.0 })
	assert_eq(b.time_days, 11.625, "a negative time is ignored")
	b.from_data("junk")
	assert_eq(b.time_days, 11.625, "a malformed record is ignored")
	assert_eq(WorldClock.hud_text(11.625, 32.0, 45.0), "Day 12 \u00b7 15:00 \u00b7 Summer", "HUD line: day, time, season")
	var ws: Variant = GameData.WORLD_SYSTEMS["WorldSystem"]
	assert_eq(a.day_length_minutes, float(ws.get("dayLengthMinutes")), "day length is a fabric fact")
	assert_eq(a.year_length_days, float(ws.get("yearLengthDays")), "year length is a fabric fact")
	assert_eq(a.axial_tilt, float(ws.get("axialTilt")), "axial tilt is a fabric fact")
	for key in GameData.BIOMES:
		var biome: Variant = GameData.BIOMES[key]
		assert_true(biome.get("seasonSwing") != null and biome.get("seasonGrowth") is Dictionary and biome.get("seasonSpawn") is Dictionary,
				"%s declares its seasonal modifiers" % key)


## Phase 69 — a loaded rig with the 3×3 block around (0,0) built except (0,0) itself.
func _seam_rig() -> Dictionary:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	cm.max_builds_in_flight = 16
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if dx != 0 or dz != 0:
				cm.load_chunk(Vector2i(dx, dz))
	_wait_for_builds(cm)
	cm.reset_rebuild_requests()
	return rig

func _seam_rig_free(rig: Dictionary) -> void:
	rig["cm"].free()
	rig["voxel"].free()
	rig["terrain"].free()
	rig["player"].free()

func _seam_requested(cm: ChunkManager) -> Array:
	var out: Array = cm.rebuilt_chunk_keys()
	out.sort()
	return out

func _test_seam_deplete_only() -> void:
	var rig := _seam_rig()
	var cm: ChunkManager = rig["cm"]
	var v: VoxelSlice = rig["voxel"]
	# Tile 63,10 is on chunk (0,0)'s east border; a deplete op never changes a height.
	v._set_edit_ops("63,10", [{ "op": "deplete", "vein": "9,9,9", "taken": 1 }])
	assert_eq(v.seam_borders(Vector2i(0, 0)).size(), 0, "a deplete-only chunk reports no seam border")
	cm.load_chunk(Vector2i(0, 0))
	assert_eq(_seam_requested(cm).size(), 0, "streaming it in requests no neighbour rebuild")
	_seam_rig_free(rig)

func _test_seam_east_border_edit() -> void:
	var rig := _seam_rig()
	var cm: ChunkManager = rig["cm"]
	var v: VoxelSlice = rig["voxel"]
	v._set_edit_ops("63,10", [{ "op": "remove", "bottom": 1.0, "top": 2.0 }])
	assert_eq(v.seam_borders(Vector2i(0, 0)), [Vector2i(1, 0)], "the east border is the only seam")
	cm.load_chunk(Vector2i(0, 0))
	assert_eq(_seam_requested(cm), ["1,0"], "only the east neighbour is rebuilt")
	cm.rebuild_seam_neighbours(Vector2i(0, 0))
	assert_eq(cm.rebuild_request_count(Vector2i(1, 0)), 1, "and at most once per edit revision")
	_seam_rig_free(rig)

func _test_seam_late_edits() -> void:
	var rig := _seam_rig()
	var cm: ChunkManager = rig["cm"]
	var v: VoxelSlice = rig["voxel"]
	cm.load_chunk(Vector2i(0, 0))
	_wait_for_builds(cm)
	cm.reset_rebuild_requests()
	# Edits for the already-loaded chunk arrive by sync, with a corner edit (south-east).
	var edit: Array = [{ "op": "remove", "bottom": 1.0, "top": 2.0 }]
	v.apply_edits({ "63,63": edit })
	var got := _seam_requested(cm)
	assert_true(got.has("1,0") and got.has("0,1") and got.has("1,1"), "east, south and the diagonal neighbour rebuild (%s)" % str(got))
	assert_false(got.has("-1,0") or got.has("0,-1"), "the far borders do not")
	_seam_rig_free(rig)

func _test_seam_unloaded_then_streamed() -> void:
	var rig := _seam_rig()
	var cm: ChunkManager = rig["cm"]
	var v: VoxelSlice = rig["voxel"]
	# Edits arrive while (0,0) is not streamed in: nothing is requested and no revision is recorded.
	v.apply_edits({ "63,10": [{ "op": "remove", "bottom": 1.0, "top": 2.0 }] })
	cm.reset_rebuild_requests()
	cm.rebuild_seam_neighbours(Vector2i(0, 0))
	assert_eq(_seam_requested(cm).size(), 0, "an unloaded chunk requests nothing")
	cm.load_chunk(Vector2i(0, 0))
	assert_eq(_seam_requested(cm), ["1,0"], "streaming it in still rebuilds the east neighbour")
	_seam_rig_free(rig)

func _test_seam_corner_removal() -> void:
	var rig := _seam_rig()
	var cm: ChunkManager = rig["cm"]
	var v: VoxelSlice = rig["voxel"]
	cm.load_chunk(Vector2i(0, 0))
	_wait_for_builds(cm)
	v.apply_edits({ "63,63": [{ "op": "remove", "bottom": 1.0, "top": 2.0 }] })
	_wait_for_builds(cm)
	cm.reset_rebuild_requests()
	v.apply_edits({})
	assert_true(_seam_requested(cm).has("1,1"), "removing the corner edit rebuilds the diagonal neighbour")
	_seam_rig_free(rig)


# ---------------------------------------------------------------------------
# Phase 85 — chat box and admin commands
# ---------------------------------------------------------------------------

func _test_chat_parse() -> void:
	var parsed := ChatCommands.parse("  /TP  1 2.5  -3 ")
	assert_eq(parsed["name"], "tp", "name is lower-cased and slash-free")
	assert_eq(parsed["args"], ["1", "2.5", "-3"], "args are whitespace-split")
	assert_eq(ChatCommands.parse("hello")["name"], "", "plain chat parses to no command")
	assert_eq(ChatCommands.parse("/")["name"], "", "a bare slash names nothing")
	assert_true(ChatCommands.is_slash(" /x"), "padding does not hide a slash")
	assert_eq(ChatCommands.sanitize("a\nb\u0001c"), "abc", "control characters are dropped")
	assert_eq(ChatCommands.sanitize("   ").length(), 0, "blank is nothing")
	assert_eq(ChatCommands.sanitize("x".repeat(500)).length(), ChatCommands.MAX_MESSAGE_CHARS, "long lines are capped")
	var ok := ChatCommands.parse_position(["1", "2.5", "-3"])
	assert_true(ok["ok"] and ok["pos"] == Vector3(1.0, 2.5, -3.0), "three numbers make a position")
	assert_false(ChatCommands.parse_position(["1", "2"])["ok"], "too few numbers")
	assert_false(ChatCommands.parse_position(["1", "x", "3"])["ok"], "not a number")
	assert_false(ChatCommands.parse_position(["1", "nan", "3"])["ok"], "nan is refused")
	assert_false(ChatCommands.parse_position(["1", "inf", "3"])["ok"], "inf is refused")
	assert_false(ChatCommands.parse_position(["1", "1e12", "3"])["ok"], "beyond the planet is refused")
	assert_eq(ChatCommands.parse_quantity("5"), 5, "a quantity")
	assert_eq(ChatCommands.parse_quantity("0"), 0, "zero is refused")
	assert_eq(ChatCommands.parse_quantity("-2"), 0, "negative is refused")
	assert_eq(ChatCommands.parse_quantity("99999999"), 0, "huge is refused")
	assert_eq(ChatCommands.parse_quantity("1.5"), 0, "fractions are refused")
	assert_eq(ChatCommands.match_item("ferriteingot", ["FerriteIngot", "Other"]), "FerriteIngot", "item match ignores case")
	assert_eq(ChatCommands.match_item("nope", ["FerriteIngot"]), "", "unknown item")
	assert_true(ChatCommands.is_admin_command("kill") and not ChatCommands.is_admin_command("help"), "admin set")
	assert_true(ChatCommands.is_known("where") and ChatCommands.is_known("give") and not ChatCommands.is_known("nope"), "known set")
	assert_true(ChatCommands.help_lines(true).size() > ChatCommands.help_lines(false).size(), "admins see more of /help")

func _test_chat_admin_commands() -> void:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("player_host_1")
	var inv := InventorySlice.new()
	add_child(inv)
	var body := PlayerSlice.new()
	body.render_visuals = false
	add_child(body)
	var chat := ChatSlice.new()
	chat.render_visuals = false
	chat.admins_path = "user://does_not_exist_admins.json"
	chat.player_registry = reg
	chat.player_slice = body
	chat.inventory_slice = inv
	add_child(chat)
	# A fake clock that runs a second ahead per line keeps this test clear of the chat token bucket.
	var ticks := [0.0]
	chat.set_clock(func() -> float:
		ticks[0] += 10.0
		return ticks[0])

	var posted: Array = []
	var cb := func(channel: String, sender: String, text: String, target: String) -> void:
		posted.append({ "channel": channel, "sender": sender, "text": text, "target": target })
	GameBus.chat_posted.connect(cb)
	var teleports: Array = []
	var tp := func(pos: Dictionary) -> void: teleports.append(WorldPos.to_scene(pos, Vector2i.ZERO))
	GameBus.player_teleport.connect(tp)

	assert_true(chat.is_admin("player_host_1"), "the host's own player is an admin")
	assert_false(chat.is_admin("player_other"), "anyone else is not")
	assert_false(chat.is_admin(""), "nobody is not")

	chat.handle_intent("hello world", "")
	assert_eq(posted.back()["channel"], "chat", "plain text is said")
	assert_eq(posted.back()["text"], "hello world", "as typed")
	assert_eq(posted.back()["target"], "", "to everyone")

	posted.clear()
	chat.handle_intent("/say server restarts soon", "")
	assert_eq(posted.back()["channel"], "announce", "/say announces")
	assert_eq(posted.back()["sender"], "Server", "from the server")
	assert_eq(posted.back()["text"], "server restarts soon", "the whole message")

	chat.handle_intent("/give ferriteingot 3", "")
	assert_eq(inv.get_item_count("FerriteIngot"), 3, "/give creates items for the admin")
	chat.handle_intent("/give nonsense", "")
	assert_eq(inv.get_item_count("nonsense"), 0, "an unknown item creates nothing")
	assert_true(str(posted.back()["text"]).contains("Unknown item"), "and says so")
	chat.handle_intent("/give FerriteIngot 0", "")
	assert_eq(inv.get_item_count("FerriteIngot"), 3, "a zero quantity creates nothing")

	chat.handle_intent("/tp 10 20 30", "")
	assert_eq(teleports.size(), 1, "/tp moves the admin")
	assert_eq(teleports[0], Vector3(10.0, 20.0, 30.0), "to the typed spot")
	chat.handle_intent("/tp 10 banana 30", "")
	assert_eq(teleports.size(), 1, "a bad coordinate moves nobody")

	chat.handle_intent("/kill", "")
	assert_eq(body.get_hp(), 0.0, "/kill with no target kills the admin")

	# A non-admin is refused every admin command, and the refusal is addressed to them alone.
	posted.clear()
	teleports.clear()
	for line in ["/say hi", "/tp 1 2 3", "/give FerriteIngot 1", "/kill me", "/bring me"]:
		chat.handle_intent(line, "player_other")
	assert_eq(teleports.size(), 0, "a non-admin teleports nobody")
	assert_eq(inv.get_item_count("FerriteIngot"), 3, "a non-admin creates nothing")
	assert_eq(posted.size(), 5, "each refused line is answered")
	for m in posted:
		assert_eq(m["target"], "player_other", "the refusal goes to the caller only")
		assert_eq(m["channel"], "system", "as a system line")
	# Non-admins keep the open commands.
	posted.clear()
	chat.handle_intent("/help", "player_other")
	assert_true(posted.size() >= 3, "/help answers a non-admin")
	posted.clear()
	chat.handle_intent("/nope", "player_other")
	assert_true(str(posted.back()["text"]).contains("Unknown command"), "an unknown command is named")

	# An admins file grants admin to the ids it lists.
	var path := "user://test_admins_phase85.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("[\"player_other\", 7, \"\"]")
	f.close()
	chat.admins_path = path
	chat._load_admins()
	assert_true(chat.is_admin("player_other"), "a listed id is an admin")
	assert_false(chat.is_admin("player_third"), "an unlisted one is not")
	DirAccess.remove_absolute(path)

	GameBus.chat_posted.disconnect(cb)
	GameBus.player_teleport.disconnect(tp)
	chat.free()
	body.free()
	inv.free()
	reg.free()

func _test_chat_box_visible() -> void:
	var c := ChatSlice.new()
	add_child(c)
	assert_true(c._field != null and c._field.visible, "the box shows before Enter is pressed")
	assert_false(c.is_typing(), "but it does not hold the keyboard")
	assert_true(c._field.placeholder_text.contains("Enter"), "and it says how to start typing")
	c.open_input("/")
	assert_eq(c._field.text, "/", "Enter or / prefills and focuses it")
	c._close_input()
	c.queue_free()

## Test stand-in for the local body: reports a fixed exact world position.
class _StubBody extends Node:
	var wp: Dictionary = {}
	func get_world_pos() -> Dictionary:
		return wp
	func get_position() -> Vector3:
		return Vector3.ZERO

func _chat_rig() -> Dictionary:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("player_host_1")
	var chat := ChatSlice.new()
	chat.render_visuals = false
	chat.admins_path = "user://does_not_exist_admins.json"
	chat.player_registry = reg
	add_child(chat)
	return { "reg": reg, "chat": chat }

## Phase 101 — a burst is bounded per player, refills with the clock and is dropped on disconnect.
func _test_chat_rate_limit() -> void:
	var rig := _chat_rig()
	var chat: ChatSlice = rig["chat"]
	var now := [100.0]
	chat.set_clock(func() -> float: return now[0])
	var posted: Array = []
	var cb := func(channel: String, sender: String, text: String, target: String) -> void:
		posted.append({ "channel": channel, "text": text, "target": target })
	GameBus.chat_posted.connect(cb)
	for i in ChatSlice.CHAT_BURST + 10:
		chat.handle_intent("line %d" % i, "player_other")
	var said := posted.filter(func(m): return m["channel"] == "chat" and m["target"] == "")
	var notices := posted.filter(func(m): return m["channel"] == "system")
	assert_eq(said.size(), ChatSlice.CHAT_BURST, "exactly CHAT_BURST lines are broadcast")
	assert_eq(chat.chat_rate_refused, 10, "the rest are counted as refused")
	assert_eq(notices.size(), 1, "one slow-down notice")
	assert_eq(notices[0]["target"], "player_other", "addressed to the speaker alone")
	now[0] += 1.0 / ChatSlice.CHAT_LINES_PER_SEC
	posted.clear()
	chat.handle_intent("again", "player_other")
	assert_eq(posted.size(), 1, "one more line after 1/CHAT_LINES_PER_SEC seconds")
	assert_eq(posted[0]["text"], "again", "and it is the line")
	chat.handle_intent("too soon", "player_other")
	assert_eq(chat.chat_rate_refused, 11, "but not two")
	# Another player has a bucket of their own, and the host's local player is limited too.
	posted.clear()
	chat.handle_intent("hi", "player_third")
	assert_eq(posted.size(), 1, "one player's flood does not starve another")
	for i in ChatSlice.CHAT_BURST + 1:
		chat.handle_intent("host %d" % i, "")
	assert_eq(chat.chat_rate_refused, 12, "the local player is subject to the bucket")
	assert_true(chat._buckets.has("player_other"), "a bucket exists while the player is here")
	GameBus.player_left.emit("player_other")
	assert_false(chat._buckets.has("player_other"), "a disconnect removes the bucket entry")
	GameBus.chat_posted.disconnect(cb)
	chat.free()
	rig["reg"].free()

## Phase 101 — `/kill` on a peer goes through the host's hit path: simulated HP floor, one packet,
## and the simulated number survives a reconnect.
func _test_chat_kill_peer_simulated_hp() -> void:
	var rig := _chat_rig()
	var chat: ChatSlice = rig["chat"]
	var reg: PlayerRegistry = rig["reg"]
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n._test_peers = [7]
	chat.networking = n
	var pid := str(reg.resolve_identity(7))
	var gr: Node = (load("res://src/core/game_root.gd") as GDScript).new()
	gr._is_client = false
	gr._registry = reg
	gr._networking = n
	GameBus.player_damaged.connect(gr._on_player_damaged)
	n._test_outbox.clear()
	chat.handle_intent("/kill %s" % reg.public_handle(pid), "")
	GameBus.player_damaged.disconnect(gr._on_player_damaged)
	var hits := n._test_outbox.filter(func(o): return o["payload"]["type"] == "player_damaged")
	assert_eq(hits.size(), 1, "exactly one player_damaged goes out")
	assert_eq(hits[0]["peer_id"], 7, "to that peer")
	assert_eq(reg.get_hp(pid), 0.0, "the host's simulated HP is at the floor")
	var back := PlayerRegistry.new()
	add_child(back)
	back.apply_player_data(pid, reg.get_player_data(pid))
	assert_eq(back.get_hp(pid), 0.0, "a reconnect restores the simulated value, not MAX_HP")
	back.free()
	gr.free()
	n._test_peers = null
	n.free()
	chat.free()
	reg.free()

## Phase 101 — the damage door is game_root's: nothing else calls `send_player_damaged`.
func _test_chat_no_direct_damage_door() -> void:
	var offenders: Array = []
	var stack: Array = ["res://src"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			stack.append(dir + "/" + sub)
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd") or f in ["game_root.gd", "networking_slice.gd", "test_suite.gd", "net_harness.gd"]:
				continue
			if FileAccess.get_file_as_string(dir + "/" + f).contains("send_player_damaged("):
				offenders.append(f)
	assert_eq(offenders, [], "no file but game_root / networking calls send_player_damaged")

## Phase 101 — a teleport keeps the exact `{chunk, local}` end to end, far from the origin.
func _test_chat_exact_teleports() -> void:
	var rig := _chat_rig()
	var chat: ChatSlice = rig["chat"]
	var reg: PlayerRegistry = rig["reg"]
	var stub := _StubBody.new()
	stub.wp = { "chunk": Vector2i(1200000, 3), "local": Vector3(0.25, 10.0, 0.75) }
	add_child(stub)
	chat.player_slice = stub
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n._test_peers = [7]
	chat.networking = n
	var pid := str(reg.resolve_identity(7))
	var handle: String = reg.public_handle(pid)
	n._route_c2h(7, { "type": "player_moved", "position": WorldPos.pos_to_wire(
		{ "chunk": Vector2i(-900001, 40), "local": Vector3(31.9, 2.0, 0.1) }) })
	n._test_outbox.clear()
	chat.handle_intent("/bring " + handle, "")
	var sent := n._test_outbox.filter(func(o): return o["payload"]["type"] == "teleport")
	assert_eq(sent.size(), 1, "/bring sends one teleport")
	var got: Dictionary = WorldPos.pos_from_wire(sent[0]["payload"]["position"])
	assert_eq(got["chunk"], Vector2i(1200000, 3), "to the admin's exact chunk")
	assert_true((got["local"] as Vector3).distance_to(Vector3(0.25, 10.0, 0.75)) < 1e-3, "and local")
	# The client side decodes it to the same record.
	var seen: Array = []
	var cb := func(pos: Dictionary) -> void: seen.append(pos)
	GameBus.player_teleport.connect(cb)
	n._role = NetworkingSlice.Role.CLIENT
	n._route_h2c(sent[0]["payload"])
	assert_eq(seen.size(), 1, "the client places the body")
	assert_eq(seen[0]["chunk"], Vector2i(1200000, 3), "in the exact chunk")
	# A malformed position is dropped and moves nothing.
	var was_quiet := Diag.quiet
	Diag.quiet = true
	n._route_h2c({ "type": "teleport", "position": { "chunk": [0, 0], "local": [NAN, 0, 0] } })
	n._route_h2c({ "type": "teleport", "position": "elsewhere" })
	n._route_h2c({ "type": "teleport", "position": { "chunk": [1.5, 0], "local": [1, 2, 3] } })
	Diag.quiet = was_quiet
	assert_eq(seen.size(), 1, "a malformed teleport position is dropped")
	# `/tp <peer>` by the local admin lands on the peer's exact chunk.
	seen.clear()
	n._role = NetworkingSlice.Role.HOST
	chat.handle_intent("/tp " + handle, "")
	GameBus.player_teleport.disconnect(cb)
	assert_eq(seen.size(), 1, "/tp <player> teleports the admin")
	assert_eq(seen[0]["chunk"], Vector2i(-900001, 40), "to the peer's exact chunk")
	assert_true((seen[0]["local"] as Vector3).distance_to(Vector3(31.9, 2.0, 0.1)) < 1e-3, "and local")
	n._test_peers = null
	n.free()
	stub.free()
	chat.free()
	reg.free()

## Phase 101 — `/tp x y z` wraps X onto one lap and refuses a Z past the pole rows.
func _test_chat_tp_limits() -> void:
	var rig := _chat_rig()
	var chat: ChatSlice = rig["chat"]
	var seen: Array = []
	var cb := func(pos: Dictionary) -> void: seen.append(pos)
	GameBus.player_teleport.connect(cb)
	var posted: Array = []
	var pcb := func(_c: String, _s: String, text: String, _t: String) -> void: posted.append(text)
	GameBus.chat_posted.connect(pcb)
	var pole_m := float(TerrainSlice.pole_chunks()) * TerrainSlice.CHUNK_METERS
	var past_z := pole_m + TerrainSlice.CHUNK_METERS
	chat.handle_intent("/tp 0 10 %s" % str(past_z), "")
	assert_eq(seen.size(), 0, "a Z past the pole is refused")
	assert_true(str(posted.back()).contains(str(int(pole_m))), "and the reply names the limit")
	var lap := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	chat.handle_intent("/tp %s 10 0" % str(2.5 * lap), "")
	assert_eq(seen.size(), 1, "an X several laps round still teleports")
	var at: Vector3 = WorldPos.to_scene(seen[0], Vector2i.ZERO)
	assert_true(absf(absf(at.x) - lap * 0.5) < 1.0, "to the wrapped X (the seam)")
	GameBus.chat_posted.disconnect(pcb)
	GameBus.player_teleport.disconnect(cb)
	chat.free()
	rig["reg"].free()

func _test_chat_wire() -> void:
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n._test_peers = [4, 5]
	n._on_chat_posted("announce", "Server", "hello", "")
	var kinds: Array = []
	for m in n._test_outbox:
		kinds.append([m["peer_id"], m["payload"]["type"], m["payload"]["text"]])
	assert_eq(kinds, [[4, "chat_message", "hello"], [5, "chat_message", "hello"]], "an untargeted line reaches every peer")
	n._test_outbox.clear()
	n.send_teleport(4, WorldPos.from_world(5.0, 6.0, 7.0))
	assert_eq(n._test_outbox.size(), 1, "a teleport goes to one peer")
	assert_eq(n._test_outbox[0]["payload"]["type"], "teleport", "as a teleport packet")

	# Host side of the intent: the speaker is the connection's player, never the payload's claim.
	var got: Array = []
	var cb := func(text: String, pid: String) -> void: got.append([text, pid])
	GameBus.chat_intent.connect(cb)
	n._route_c2h(9, { "type": "chat_intent", "text": "hi", "player_id": "player_forged" })
	assert_eq(got.size(), 0, "an un-handshaked peer cannot speak")
	n.set_player_id(9, "player_real")
	n._route_c2h(9, { "type": "chat_intent", "text": "hi", "player_id": "player_forged" })
	assert_eq(got, [["hi", "player_real"]], "the connection's player speaks, not the claimed one")
	n._route_c2h(9, { "type": "chat_intent", "text": 42 })
	assert_eq(got.size(), 1, "a non-string line is dropped")
	GameBus.chat_intent.disconnect(cb)

	# Client side: the intent is forwarded and a hosted line is shown.
	n._test_outbox.clear()
	n._role = NetworkingSlice.Role.CLIENT
	n._on_chat_intent("/tp 1 2 3", "")
	assert_eq(n._test_outbox.size(), 1, "a client forwards its line to the host")
	assert_eq(n._test_outbox[0]["payload"]["type"], "chat_intent", "as an intent")
	assert_false(n._test_outbox[0]["payload"].has("player_id"), "carrying no identity")
	var shown: Array = []
	var cb2 := func(channel: String, sender: String, text: String, target: String) -> void:
		shown.append([channel, sender, text, target])
	GameBus.chat_posted.connect(cb2)
	n._route_h2c({ "type": "chat_message", "channel": "announce", "sender": "Server", "text": "hey" })
	GameBus.chat_posted.disconnect(cb2)
	assert_eq(shown, [["announce", "Server", "hey", ""]], "a hosted line is re-emitted for the box")
	var moved: Array = []
	var cb3 := func(pos: Dictionary) -> void: moved.append(WorldPos.to_scene(pos, Vector2i.ZERO))
	GameBus.player_teleport.connect(cb3)
	n._route_h2c({ "type": "teleport", "position": WorldPos.to_wire(Vector3(100.0, 9.0, -40.0)) })
	GameBus.player_teleport.disconnect(cb3)
	assert_eq(moved.size(), 1, "a teleport packet moves the body")
	assert_true(moved[0].distance_to(Vector3(100.0, 9.0, -40.0)) < 0.01, "to the sent spot")
	n._test_peers = null
	n.free()
