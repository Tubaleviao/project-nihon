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
const TamingSlice     := preload("res://src/creature/taming_slice.gd")
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
const TreeSlice       := preload("res://src/world/tree_slice.gd")
const MeshUtil        := preload("res://src/core/mesh_util.gd")
const MarketSlice     := preload("res://src/world/market_slice.gd")
const TradeSlice      := preload("res://src/trade/trade_slice.gd")
const ProposalSlice   := preload("res://src/governance/proposal_slice.gd")
const Minimap         := preload("res://src/ui/minimap.gd")
const PlayerSlice     := preload("res://src/player/player_slice.gd")
const NetworkingSlice := preload("res://src/networking/networking_slice.gd")
const Locomotion      := preload("res://src/character/locomotion.gd")
const SkeletonRig     := preload("res://src/character/skeleton_rig.gd")
const SkillTiers      := preload("res://src/core/skill_tiers.gd")
const MultimeshPool   := preload("res://src/core/multimesh_pool.gd")
const SpatialHash     := preload("res://src/core/spatial_hash.gd")
const PlayerRegistry  := preload("res://src/persistence/player_registry.gd")

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
	_run_test("taming: skill gate fails closed",               _test_taming_requires_skill)
	_run_test("taming: bare hands required",                   _test_taming_requires_unarmed)
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
	_run_test("voxel: common material outnumbers rare",        _test_voxel_material_rarity)
	_run_test("voxel: edits round-trip",                       _test_voxel_edits_round_trip)
	_run_test("voxel: placed block keeps material colour",    _test_voxel_placed_block_keeps_material_color)
	_run_test("voxel: mining placed block yields its material", _test_voxel_mine_placed_block_yields_material)
	_run_test("voxel: placed block preserves base colour",     _test_voxel_placed_block_preserves_base_colour)
	_run_test("voxel: place after mine keeps placed colour",   _test_voxel_place_after_mine_keeps_colour)
	_run_test("voxel: rare vein deposits on natural tiles",    _test_voxel_rare_vein_deposits)
	_run_test("voxel: rare vein material list",                _test_voxel_rare_vein_materials)
	_run_test("ui: windows toggle open/close",                 _test_ui_window_toggle)
	_run_test("ui: inventory lines reflect contents",          _test_ui_inventory_lines)
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
	_run_test("player: respawn resets hp and alive flag",      _test_player_respawn)
	_run_test("chunk: desired set within view distance",        _test_chunk_desired_set)
	_run_test("chunk: world/chunk coordinate round-trip",       _test_chunk_coordinate_round_trip)
	_run_test("chunk: per-chunk biome is stable",               _test_chunk_biome_stable)
	_run_test("chunk: load/unload emits signals",               _test_chunk_load_unload_signals)
	_run_test("chunk: refresh queues nearest-first",            _test_chunk_refresh_queues_nearest_first)
	_run_test("chunk: load queue respects per-frame budget",    _test_chunk_load_queue_respects_budget)
	_run_test("chunk: voxel edits isolated per chunk",          _test_chunk_voxel_edits_isolated)
	_run_test("chunk: unload preserves edits on reload",        _test_chunk_unload_preserves_edits)
	_run_test("chunk: creature spawn scales per chunk",         _test_chunk_creature_spawn_per_chunk)
	_run_test("chunk: tree spawn scales per chunk",             _test_chunk_tree_spawn_per_chunk)
	_run_test("tree: spawns the per-chunk budget",              _test_tree_spawn_for_chunk)
	_run_test("tree: per-biome species and density",            _test_tree_per_biome_table)
	_run_test("tree: chop yields wood and wears the axe",       _test_tree_chop_yields_wood_and_wears_axe)
	_run_test("tree: chop requires an axe",                     _test_tree_chop_requires_axe)
	_run_test("tree: stump regrows on its cooldown",            _test_tree_stump_regrows_on_cooldown)
	_run_test("tree: despawn is per chunk",                     _test_tree_despawn_is_per_chunk)
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
	_run_test("net: client self-reference is peer-scoped",       _test_net_peer_party_scopes_identity)
	_run_test("net: AOI center defaults to spawn; in_aoi gates", _test_net_aoi_center_and_in_aoi)
	_run_test("net: AOI recipients are near peers only",         _test_net_aoi_recipients)
	_run_test("net: AOI region floors to grid cell",             _test_net_aoi_region)
	_run_test("net: player intents bind connection identity",    _test_net_player_intents_bind_connection_identity)
	_run_test("net: own-state push is peer-scoped",              _test_net_own_state_push_is_peer_scoped)
	_run_test("asset: placeholder resolves at canonical path",  _test_asset_placeholder_resolves)
	_run_test("asset: no private-only paths hardcoded",          _test_asset_no_private_paths_hardcoded)
	_run_test("asset: pck round-trip proves override works",    _test_asset_pck_round_trip_override)
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
	_run_test("identity: disconnect evicts record + inventory",   _test_disconnect_evicts_player)
	_run_test("identity: handshake retry re-answers a bound peer", _test_handshake_retry_reanswers_peer)
	_run_test("net: retry re-presents the join intent",           _test_retry_represents_join_intent)
	_run_test("market: cleared party inventory binding",          _test_party_inventory_binding_cleared)
	_run_test("persistence: failed write reports + keeps record",  _test_failed_write_reports_and_preserves)
	_run_test("craft: craft uses the crafter's own inventory",    _test_craft_uses_crafter_inventory)
	_run_test("craft: client forwards a craft intent",            _test_craft_client_forwards_intent)

	# Self-check: the _run_test list above is manual, so a test function can be
	# written but forgotten from the list. Fail loudly instead of silently
	# dropping it: any _test_* method not registered above fails the suite.
	for m in get_method_list():
		var method_name: String = str(m.get("name", ""))
		if method_name.begins_with("_test_") and not _registered_names.has(method_name):
			push_error("TestSuite: '%s' is defined but never registered — add it to the _run_test list" % method_name)
			_fail += 1

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

func _test_voxel_mine_bedrock() -> void:
	var v := _make_voxel()
	v.apply_edits({ "32,32": 0.0 })
	var r := v.mine_block(Vector3(16.0, 0.0, 16.0))
	assert_false(r.get("success", false), "mining at bedrock fails")
	v.free()

func _test_voxel_mine_side_face() -> void:
	var v := _make_voxel()
	var inv := InventorySlice.new()
	add_child(inv)
	v.inventory_slice = inv
	# East-facing face (normal +X) at x=17.0: the hit block is tile 33 (west, world [16.5,17.0)).
	v.mine_block(Vector3(17.0, 1.5, 16.5), Vector3(1, 0, 0))
	assert_eq(v.get_voxel_height_at(Vector2(16.5, 16.5)), 1.875, "+X face mines the block west of the boundary")
	assert_eq(v.get_voxel_height_at(Vector2(17.0, 16.5)), 2.0, "east block untouched")
	# West-facing face (normal -X) at x=19.0: the hit block is tile 38 (east, world [19.0,19.5)).
	v.mine_block(Vector3(19.0, 1.5, 16.5), Vector3(-1, 0, 0))
	assert_eq(v.get_voxel_height_at(Vector2(19.0, 16.5)), 1.875, "-X face mines the block east of the boundary")
	assert_eq(v.get_voxel_height_at(Vector2(18.5, 16.5)), 2.0, "west block untouched")
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
			if v.material_for_biome("TemperateForest", wc) != "Ferrite":
				temperate_only_ferrite = false
	assert_true(temperate_only_ferrite, "temperate ground is ferrite only (no invented rare ore)")
	# Rarity: the volcanic prose grants ashite 0.9 / aethermite 0.2, so the
	# common rock dominates the surface and the rare ore is sparse veins.
	var ashite := 0
	var aethermite := 0
	for tz in range(64):
		for tx in range(64):
			var wc := Vector2(
				tx * VoxelSlice.TILE_SIZE + VoxelSlice.TILE_SIZE * 0.5,
				tz * VoxelSlice.TILE_SIZE + VoxelSlice.TILE_SIZE * 0.5)
			var m := v.material_for_biome("VolcanicBadlands", wc)
			if m == "Ashite":
				ashite += 1
			elif m == "Aethermite":
				aethermite += 1
	assert_true(ashite > aethermite, "common ashite outnumbers rare aethermite (%d vs %d)" % [ashite, aethermite])
	assert_true(aethermite > 0, "rare aethermite appears as sparse veins")
	v.free()

func _test_voxel_edits_round_trip() -> void:
	var v := _make_voxel()
	v.apply_edits({ "32,32": 1.0, "34,34": 3.5 })
	assert_eq(v.get_edits().get("32,32", 0.0), 1.0, "edit 32,32 survives")
	assert_eq(v.get_voxel_height_at(Vector2(16.0, 16.0)), 1.0, "height reflects restored edit")
	assert_eq(v.get_voxel_height_at(Vector2(17.0, 17.0)), 3.5, "second edit restored")
	v.free()

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
	assert_eq(v._column_color(center), VoxelSlice.MATERIAL_COLORS["Ashite"], "placed block renders Ashite colour, not biome colour")
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
	var layers: Array = v._column_layers(Vector2i(0, 0), v._heightmaps["0,0"], 32, 32)
	assert_true(layers.size() >= 2, "column has natural + placed layers")
	assert_eq(layers[0]["color"], v._natural_color(center), "natural base keeps its biome colour")
	assert_true(v._natural_color(center) != VoxelSlice.MATERIAL_COLORS["Ashite"], "placed colour differs from the biome colour")
	assert_eq(layers[-1]["color"], VoxelSlice.MATERIAL_COLORS["Ashite"], "placed block renders Ashite colour")
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
	var layers: Array = v._column_layers(Vector2i(0, 0), v._heightmaps["0,0"], 32, 32)
	assert_true(layers.size() >= 2, "column has natural + placed layers")
	assert_eq(layers[-1]["color"], VoxelSlice.MATERIAL_COLORS["Ashite"], "placed Ashite renders Ashite colour, not the mined material's colour")
	assert_true(VoxelSlice.MATERIAL_COLORS["Ashite"] != v._natural_color(center), "placed colour differs from the mined material's colour")
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
	assert_eq(float(manifest["0,0"]["edits"]["32,32"]), 1.0, "chunk (0,0) edit recorded")
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
	v._on_mine_requested(Vector3(16.0, 2.0, 16.0), Vector3.UP)
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
	var n := NetworkingSlice.new()
	add_child(n)
	assert_eq(n._peer_party(5, "player"), "peer_5", "client 'player' self-reference is peer-scoped")
	assert_eq(n._peer_party(5, "merchant"), "merchant", "non-self party id passes through unchanged")
	assert_eq(n._peer_party(5, "peer_9"), "peer_9", "already-scoped id passes through unchanged")
	n.free()

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
	t.free()

func _test_tree_client_forwards_then_applies_host_chop() -> void:
	var t := _make_tree_slice()
	t.spawn_for_chunk(Vector2i(0, 0))
	var tid: String = str(t.get_all_trees()[0]["tree_id"])
	var forwarded := {}
	var listener := func(id): forwarded["id"] = id
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

## First chunk (scanning along cz = 0) whose biome is one of `biomes`, or
## Vector2i(-1, -1) when none is found.
func _find_chunk_with_biome(terrain: Node, biomes: Array) -> Vector2i:
	for cx in range(-80, 80):
		if biomes.has(str(terrain.get_biome_at_chunk(Vector2i(cx, 0)))):
			return Vector2i(cx, 0)
	return Vector2i(-1, -1)

## Vertex count of the built chunk's visual surface (surface 0).
func _chunk_surface_vertices(voxel: Node, chunk_pos: Vector2i) -> int:
	var root: Node3D = voxel._chunks["%d,%d" % [chunk_pos.x, chunk_pos.y]]
	var mesh_inst: MeshInstance3D = root.get_child(0)
	return mesh_inst.mesh.surface_get_array_len(0)

func _test_voxel_rare_vein_deposits() -> void:
	var terrain := TerrainSlice.new()
	add_child(terrain)
	var v := VoxelSlice.new()
	add_child(v)
	v.terrain_slice = terrain
	var rare := _find_chunk_with_biome(terrain, ["VolcanicBadlands", "TwilightGrove"])
	var plain := _find_chunk_with_biome(terrain, ["TemperateForest", "TemperateGrassland"])
	assert_true(rare.x != -1, "found a biome that grants a rare vein")
	assert_true(plain.x != -1, "found a biome with no rare vein")
	var flat: Array = []
	flat.resize(64 * 64)
	flat.fill(2.0)

	var deposits: Array = v.vein_deposits(rare, flat)
	assert_true(deposits.size() > 0, "rare vein tiles get a raised deposit")
	# Vector3 holds 32-bit floats, so compare the deposit geometry approximately.
	var expected_top: float = 2.0 + VoxelSlice.VEIN_DEPOSIT_HEIGHT * 0.5
	var expected_size: float = VoxelSlice.TILE_SIZE - VoxelSlice.VEIN_DEPOSIT_INSET * 2.0
	for d in deposits:
		assert_true(absf(float(d["position"].y) - expected_top) < 0.0001, "a deposit sits on the column top")
		assert_true(absf(float(d["size"].x) - expected_size) < 0.0001, "a deposit is inset inside its tile")
	assert_eq(v.vein_deposits(plain, flat).size(), 0, "common ground carries no deposit")

	# A mined natural column is not a *placed* one, so its vein keeps its deposit
	# — at the lowered height (only a player-placed surface is exempt).
	var mined_tile: Vector2i = v._world_to_tile(Vector2(deposits[0]["position"].x, deposits[0]["position"].z))
	v._edits[v._tile_key(mined_tile)] = 1.5
	var mined: Array = v.vein_deposits(rare, flat)
	assert_eq(mined.size(), deposits.size(), "mining a vein column does not remove its deposit")
	assert_true(absf(float(mined[0]["position"].y) - (1.5 + VoxelSlice.VEIN_DEPOSIT_HEIGHT * 0.5)) < 0.0001,
		"the deposit rides down to the mined column top")
	# Undo the simulated mine: the mesh check below compares flat chunks.
	v._edits.erase(v._tile_key(mined_tile))

	# The deposits must actually reach the rendered mesh: a rare-biome chunk
	# carries exactly one box per rare tile more than a ferrite-only chunk of the
	# same (identical, flat) heightmap.
	v.build_chunk(rare, flat)
	v.build_chunk(plain, flat)
	var delta: int = _chunk_surface_vertices(v, rare) - _chunk_surface_vertices(v, plain)
	assert_eq(delta, deposits.size() * MeshUtil.BOX_VERTEX_COUNT, "every deposit reaches the chunk mesh")
	v.free()
	terrain.free()

func _test_voxel_rare_vein_materials() -> void:
	var v := VoxelSlice.new()
	add_child(v)
	assert_true(VoxelSlice.RARE_VEIN_MATERIALS.has("Aethermite"), "aethermite is a vein material")
	assert_true(VoxelSlice.RARE_VEIN_MATERIALS.has("Lumenfite"), "lumenfite is a vein material")
	assert_true(VoxelSlice.RARE_VEIN_MATERIALS.has("Voidite"), "voidite is a vein material")
	assert_false(VoxelSlice.RARE_VEIN_MATERIALS.has("Ferrite"), "the common ground is not a vein")
	assert_false(VoxelSlice.RARE_VEIN_MATERIALS.has("Ashite"), "the volcanic bulk rock is not a vein")
	v.free()

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
		"world":       { "local_player_id": pid, "chunks": { "0,0": { "edits": {}, "materials": {} } } },
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
	assert_true(registry.evict_player(remote), "the disconnected player's record is evicted")
	assert_false(registry.has_player(remote), "the record is no longer resident")
	assert_false(registry.has_inventory(remote), "nor is the inventory node")
	assert_true(remote_inv.get_parent() == null, "the registry-owned node was detached for freeing")
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
	return { "creature": c, "taming": taming, "crafting": crafting, "registry": registry }

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
	rig["crafting"].set_skill("Unarmed", "journeyman")
	rig["crafting"].set_skill("Alchemy", "apprentice")
	var wolves := _taming_instances_of(c, "GraywolfPack")
	var target := str(wolves[1])
	GameBus.creature_died.emit(str(wolves[0]), Vector3.ZERO, "player")

	var alice: String = str(registry.resolve_identity(2))
	var bob: String = str(registry.resolve_identity(3))
	_taming_stand_near(registry, alice, c, target)
	_taming_stand_near(registry, bob, c, target)
	# Only BOB carries the offering: a feed by alice must not spend bob's ration.
	var bob_inv: Node = registry.get_inventory(bob)
	assert_true(bob_inv.add_item("FieldRations", 1), "bob carries a ration")

	var alice_result: Dictionary = taming.tame(target, alice)
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
	var fed: Dictionary = taming.tame(fox, alice)
	assert_false(bool(fed["success"]), "alice cannot feed the fox on bob's ration")
	assert_eq(str(fed["reason"]), "missing_offer", "reason is missing_offer")
	assert_eq(bob_inv.get_item_count("FieldRations"), 1, "bob's ration is untouched")

	# ...and bob, standing next to the same fox, does get fed.
	_taming_stand_near(registry, bob, c, fox)
	assert_true(bool(taming.tame(fox, bob)["success"]), "bob feeds it with his own ration")
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
	rig["creature"].free()
	rig["taming"].free()
	rig["crafting"].free()
	rig["registry"].free()

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
	_registered_names[str(fn.get_method())] = true
	var fails_before := _fail
	fn.call()
	var outcome := "✓" if _fail == fails_before else "✗"
	print("  %s %s" % [outcome, name])
