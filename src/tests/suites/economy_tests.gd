extends "res://src/tests/test_support.gd"
## Phase 133 — the economy tests, moved unchanged from the old single-file suite.


func register() -> void:
	_run_test("research points: ceiling, window cap and one sync per craft", _test_phase130_research_caps)
	_run_test("inventory: pickup adds item",                  _test_inventory_pickup_adds)
	_run_test("inventory: drop reduces quantity",             _test_inventory_drop)
	_run_test("inventory: over-drop returns false",           _test_inventory_over_drop)
	_run_test("inventory: slot count correct",                _test_inventory_slot_count)
	_run_test("inventory: weights loaded from GameData.ITEMS",_test_inventory_weights_from_gamedata)
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
	_run_test("void burst: fabric data reaches GameData",      _test_void_fabric_data)
	_run_test("void burst: roll is deterministic and calibrated", _test_void_burst_roll_deterministic_and_calibrated)
	_run_test("void burst: consumes, damages, flags on survival", _test_void_burst_consumes_damages_and_flags)
	_run_test("void burst: flag gate and VoidTouched unlock",  _test_void_flag_gate_and_profession_unlock)
	_run_test("void burst: client never rolls, result owner-scoped", _test_void_client_never_rolls_and_result_is_owner_scoped)
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
	_run_test("research points: too few refuse, enough spend exactly", _test_research_points_gate_and_spend)
	_run_test("research points: host craft pays the crafter only, saves", _test_research_points_craft_grant_and_roundtrip)
	_run_test("research points: a craft that grants nothing keeps the first-craft bonus", _test_phase147_first_craft_marker)
	_run_test("research points: gather pays, UI rows show cost",  _test_research_points_gather_and_ui)
	_run_test("research points: fabric rule table and costs",     _test_research_points_fabric_data)
	_run_test("void burst: failed consume keeps the counter",   _test_void_failed_consume_keeps_counter)
	_run_test("void burst: golden rolls and counter round-trip", _test_void_burst_roll_golden_and_counter_roundtrip)
	_run_test("void burst: no player id reports no flag",       _test_void_burst_no_player_reports_no_flag)
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
	_run_test("market: cleared party inventory binding",          _test_party_inventory_binding_cleared)
	_run_test("craft: craft uses the crafter's own inventory",    _test_craft_uses_crafter_inventory)
	_run_test("craft: client forwards a craft intent",            _test_craft_client_forwards_intent)

func _test_phase130_research_caps() -> void:
	var registry := PlayerRegistry.new()
	add_child(registry)
	var t := TechnologySlice.new()
	add_child(t)
	t.player_registry = registry
	var clock := [1000.0]
	t.now_sec = func() -> float: return clock[0]
	registry.ensure_player("pa")
	var rules: Dictionary = (GameData.WORLD_SYSTEMS["ResearchPointRule"] as Resource).get("rules")
	var cap := int(rules["windowCap"])
	for i in 100:
		t.grant_points("pa", "gather", 1)
	assert_eq(t.get_points("pa"), cap, "100 one-unit gathers in one window earn exactly the window cap")
	clock[0] += float(rules["windowSeconds"]) + 1.0
	t.grant_points("pa", "gather", 5)
	assert_eq(t.get_points("pa"), cap + 5, "a new window pays again")
	# The balance never passes the ceiling, however it is restored or earned.
	var top := int(rules["maxPoints"])
	t.apply_statuses({ "_research_points": top * 10 }, "pa")
	assert_eq(t.get_points("pa"), top, "a restored balance is clamped to the ceiling")
	clock[0] += 100000.0
	assert_eq(t.grant_points("pa", "craft", 5), 0, "at the ceiling nothing more is earned")
	assert_eq(t.get_points("pa"), top, "the balance holds")
	# One craft is one balance change and so one technology sync.
	var crafting := CraftingSlice.new()
	add_child(crafting)
	crafting.player_registry = registry
	crafting.technology_slice = t
	registry.ensure_player("pb")
	t.apply_statuses({ "TechBasicSmithing": "unlocked" }, "pb")
	registry.get_inventory("pb").add_item("Ferrite", 6)
	var syncs: Array = []
	var on_sync := func(pid: String, _pts: int) -> void: syncs.append(pid)
	GameBus.research_points_synced.connect(on_sync)
	assert_true(bool(crafting.craft("RecipeFerriteIngot", "pb")["success"]), "the craft succeeds")
	GameBus.research_points_synced.disconnect(on_sync)
	assert_eq(syncs.size(), 1, "a first craft (craft + bonus) sends one sync")
	crafting.free()
	t.free()
	registry.free()


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

func _test_crafting_recipe_data_loaded() -> void:
	var c := CraftingSlice.new()
	add_child(c)
	var recipe := c.get_recipe("RecipeFerritePick")
	assert_false(recipe.is_empty(), "RecipeFerritePick has structured recipe data")
	assert_eq(recipe["outputs"][0]["item"], "FerritePick", "output item is FerritePick")
	assert_eq(recipe["inputs"][0]["item"], "FerriteIngot", "first input is FerriteIngot")
	c.free()

# ---------------------------------------------------------------------------
# Phase 118 — void bursts, the survivor flag and the VoidTouched unlock
# ---------------------------------------------------------------------------

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

func _test_station_types_from_fabric() -> void:
	var station := StationSlice.new()
	add_child(station)
	var types: Array = station.placeable_station_types()
	assert_true(types.has("forge"), "forge derived from recipe station fields")
	assert_true(types.has("alchemy bench"), "alchemy bench derived from recipe station fields")
	assert_true(types.size() >= 2, "multiple station types exist")
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
	GameBus.repair_resolved.connect(func(rep): resolved["r"] = rep)
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

func _test_void_fabric_data() -> void:
	var recipe: Dictionary = GameData.RECIPES[VOID_RECIPE].recipe
	assert_false(recipe.is_empty(), "GameData has the refining recipe")
	assert_eq(str(recipe["station"]), "forge", "at a forge")
	assert_eq(str(recipe["inputs"][0]["item"]), "Voidite", "from one raw voidite")
	assert_eq(str(recipe["outputs"][0]["item"]), "RefinedVoiditeShard", "to one refined shard")
	assert_true(GameData.ITEMS.has("RefinedVoiditeShard"), "the refined-shard item exists")
	var burst: Dictionary = recipe["burst"]
	assert_true(float(burst["chance"]) > 0.0 and float(burst["chance"]) < 1.0, "an authored burst chance")
	assert_true(float(burst["damage"]) > 0.0, "and an authored damage")
	assert_eq(str(burst["grantsFlag"]), "voidBurstSurvivor", "granting the survivor flag")
	var spec: Dictionary = (load("res://src/crafting/profession_slice.gd") as GDScript).unlock_spec("VoidTouched")
	assert_eq((spec["skills"] as Array).size(), 2, "VoidTouched needs two skill tiers")
	assert_eq(str(spec["requiresFlag"]), "voidBurstSurvivor", "and the flag")
	assert_eq(str(GameData.RECIPES["RecipeVoidRuneTablet"].recipe["profession"]), "VoidTouched", "the tablet recipe names the profession")
	assert_eq(str(GameData.SKILLS["VoidSmithing"].flagGate["requiresFlag"]), "voidBurstSurvivor", "Void Smithing is flag-gated")
	assert_eq(str(GameData.SKILLS["VoidMagic"].flagGate["requiresFlag"]), "voidBurstSurvivor", "and so is Void Magic")

func _test_void_burst_roll_deterministic_and_calibrated() -> void:
	var chance := float(GameData.RECIPES[VOID_RECIPE].recipe["burst"]["chance"])
	var bursts := 0
	for i in 10000:
		var roll := CraftingSlice.burst_roll(1234, "player_a", i)
		if i < 3:
			assert_true(roll >= 0.0 and roll < 1.0, "a draw stays in [0, 1)")
		if roll < chance:
			bursts += 1
		if i < 50:
			assert_eq(roll, CraftingSlice.burst_roll(1234, "player_a", i), "the same inputs draw the same roll")
	assert_true(absf(float(bursts) / 10000.0 - chance) <= 0.01, "the rate over 10,000 crafts is within 1 point of the authored chance (%d)" % bursts)
	var differs := 0
	for i in 100:
		if CraftingSlice.burst_roll(1, "player_a", i) != CraftingSlice.burst_roll(2, "player_a", i):
			differs += 1
		if CraftingSlice.burst_roll(1, "player_a", i) != CraftingSlice.burst_roll(1, "player_b", i):
			differs += 1
	assert_true(differs > 150, "the seed and the player both change the sequence")

func _test_void_burst_consumes_damages_and_flags() -> void:
	var rig := _make_void_rig()
	var crafting: Node = rig["crafting"]
	var registry: Node = rig["registry"]
	var taming: Node = rig["taming"]
	var pid := "player_peer_void"
	registry.ensure_player(pid)
	crafting.set_skill_for(pid, "Smithing", "journeyman")
	var hits: Array = []
	var on_hit := func(dmg: float, attacker: String, target: String) -> void:
		hits.append([dmg, attacker, target])
	var bursts: Array = []
	var on_burst := func(r: Dictionary) -> void:
		bursts.append(r)
	GameBus.player_damaged.connect(on_hit)
	GameBus.void_burst_resolved.connect(on_burst)

	# A safe draw: the input becomes the shard and nothing bursts.
	var safe := _void_craft(rig, pid, _void_counter(pid, false))
	assert_true(bool(safe["success"]), "a safe draw refines")
	assert_eq(registry.get_inventory(pid).get_item_count("RefinedVoiditeShard"), 1, "into one shard")
	assert_eq(registry.get_inventory(pid).get_item_count("Voidite"), 0, "consuming the voidite")
	assert_true(hits.is_empty() and bursts.is_empty(), "with no damage and no burst")

	# A burst the crafter survives: input gone, no output, authored damage, flag set.
	var damage := float(crafting.get_recipe(VOID_RECIPE)["burst"]["damage"])
	var hit := _void_craft(rig, pid, _void_counter(pid, true))
	assert_false(bool(hit["success"]), "a burst is not a success")
	assert_eq(str(hit["reason"]), "void_burst", "with the burst reason")
	assert_eq(registry.get_inventory(pid).get_item_count("Voidite"), 0, "the input is consumed")
	assert_eq(registry.get_inventory(pid).get_item_count("RefinedVoiditeShard"), 1, "and no shard is produced")
	assert_eq(hits.size(), 1, "one damage round")
	assert_eq(float(hits[0][0]), damage, "of the authored amount")
	assert_eq(str(hits[0][2]), pid, "addressed to the crafter")
	assert_true(bool(hit["burst"]["survived"]), "the crafter survives")
	assert_true(taming.has_flag(pid, "voidBurstSurvivor"), "and gains the flag")
	assert_eq(bursts.size(), 1, "void_burst_resolved fires once")

	# A crafter the burst takes DOWN gains nothing.
	var weak := "player_peer_weak"
	registry.ensure_player(weak)
	crafting.set_skill_for(weak, "Smithing", "journeyman")
	registry.record_simulated_hp(weak, damage - 1.0)
	var dead := _void_craft(rig, weak, _void_counter(weak, true))
	assert_false(bool(dead["burst"]["survived"]), "a body at damage-1 HP does not survive")
	assert_false(taming.has_flag(weak, "voidBurstSurvivor"), "and gets no flag")
	assert_eq(registry.get_inventory(weak).get_item_count("Voidite"), 0, "though the input is still consumed")

	# The flag and the counter survive a save/load.
	var saved: Dictionary = JSON.parse_string(JSON.stringify(registry.get_player_data(pid)))
	var reg2 := PlayerRegistry.new()
	add_child(reg2)
	reg2.apply_player_data(pid, saved)
	var tam2 := TamingSlice.new()
	add_child(tam2)
	tam2.apply_record(reg2.get_record(pid), pid)
	assert_true(tam2.has_flag(pid, "voidBurstSurvivor"), "the flag survives a save/load")
	assert_true(reg2.get_craft_counter(pid) > 0, "and so does the craft counter")
	GameBus.player_damaged.disconnect(on_hit)
	GameBus.void_burst_resolved.disconnect(on_burst)
	tam2.free()
	reg2.free()
	_free_void_rig(rig)

func _test_void_flag_gate_and_profession_unlock() -> void:
	var rig := _make_void_rig()
	var crafting: Node = rig["crafting"]
	var taming: Node = rig["taming"]
	var professions: Node = rig["professions"]
	var registry: Node = rig["registry"]
	var pid := "player_peer_gate"
	registry.ensure_player(pid)
	var tablet := "RecipeVoidRuneTablet"

	# Tier held but no flag: the not-tutored guard refuses.
	crafting.set_skill_for(pid, "VoidSmithing", "expert")
	assert_eq(str(crafting.can_craft(tablet, pid)["reason"]), "requires_flag:voidBurstSurvivor", "no flag: refused")
	taming.grant_flag(pid, "voidBurstSurvivor")
	var after_flag := str(crafting.can_craft(tablet, pid)["reason"])
	assert_true(after_flag != "requires_flag:voidBurstSurvivor", "with the flag the guard passes")
	# ...and the next gate is the profession, which is still locked.
	assert_eq(after_flag, "requires_profession:VoidTouched", "a recipe naming VoidTouched is refused before the unlock")
	assert_false(professions.is_unlocked(pid, "VoidTouched"), "not unlocked yet")

	var unlocked: Array = []
	var on_unlock := func(p: String, unlock_name: String) -> void:
		unlocked.append([p, unlock_name])
	GameBus.profession_unlocked.connect(on_unlock)
	crafting.set_skill_for(pid, "VoidMagic", "journeyman")
	assert_false(professions.is_unlocked(pid, "VoidTouched"), "one tier short of expert: locked")
	crafting.set_skill_for(pid, "VoidMagic", "expert")
	assert_true(professions.is_unlocked(pid, "VoidTouched"), "both tiers and the flag: unlocked")
	assert_eq(unlocked.size(), 1, "profession_unlocked fires once")
	crafting.set_skill_for(pid, "VoidMagic", "master")
	assert_eq(unlocked.size(), 1, "and not again")
	assert_true(bool(registry.get_record(pid)["professions"].get("VoidTouched", false)), "the unlock is on the record")
	assert_eq(str(crafting.can_craft(tablet, pid)["reason"]), "missing_inputs", "the recipe now reaches its inputs")

	# Without the flag the tiers alone never unlock.
	var other := "player_peer_noflag"
	registry.ensure_player(other)
	crafting.set_skill_for(other, "VoidSmithing", "expert")
	crafting.set_skill_for(other, "VoidMagic", "expert")
	assert_false(professions.is_unlocked(other, "VoidTouched"), "tiers without the flag: locked")

	# The record restores the set; a client mirror is bounded to known professions.
	var mirror: Node = (load("res://src/crafting/profession_slice.gd") as GDScript).new()
	add_child(mirror)
	mirror.apply_record({ "professions": { "VoidTouched": true, "Nonsense": true } }, "p")
	assert_true(mirror.is_unlocked("p", "VoidTouched"), "a mirror takes a known profession")
	assert_false(mirror.is_unlocked("p", "Nonsense"), "and drops an unknown one")
	mirror.is_authoritative = false
	assert_true(mirror.evaluate("p").is_empty(), "a client never evaluates an unlock")
	GameBus.profession_unlocked.disconnect(on_unlock)
	mirror.free()
	_free_void_rig(rig)

func _test_void_client_never_rolls_and_result_is_owner_scoped() -> void:
	var rig := _make_void_rig()
	var crafting: Node = rig["crafting"]
	var registry: Node = rig["registry"]
	var local_pid := str(registry.local_player_id)
	crafting.set_skill_for(local_pid, "Smithing", "journeyman")
	registry.get_inventory(local_pid).add_item("Voidite", 1)
	crafting.is_authoritative = false
	var intents: Array = []
	var on_intent := func(recipe_id: String, p: String) -> void:
		intents.append([recipe_id, p])
	var resolved: Array = []
	var on_resolved := func(r: Dictionary) -> void:
		resolved.append(r)
	GameBus.craft_intent.connect(on_intent)
	GameBus.craft_resolved.connect(on_resolved)
	GameBus.craft_requested.emit(VOID_RECIPE)
	GameBus.craft_intent.disconnect(on_intent)
	GameBus.craft_resolved.disconnect(on_resolved)
	assert_eq(intents.size(), 1, "a client forwards the intent")
	assert_true(resolved.is_empty(), "and resolves nothing")
	assert_eq(registry.get_craft_counter(local_pid), 0, "no draw was taken")
	assert_eq(registry.get_inventory(local_pid).get_item_count("Voidite"), 1, "the input is untouched")

	# The host's result goes to the crafter's peer alone, with no player id on the wire.
	var peer_pid := str(registry.resolve_identity(5))
	var other_pid := str(registry.resolve_identity(6))
	var host := NetworkingSlice.new()
	add_child(host)
	host.player_registry = registry
	host.emulate_network = true
	host._role = NetworkingSlice.Role.HOST
	var result := { "recipe_id": VOID_RECIPE, "player_id": peer_pid, "damage": 40.0, "survived": true, "flag": "voidBurstSurvivor" }
	host._on_void_burst_resolved(result)
	assert_eq(host._pending.size(), 1, "one packet")
	assert_eq(int(host._pending[0]["peer_id"]), 5, "for the crafter's peer")
	var packet: Dictionary = JSON.parse_string(host._pending[0]["payload"])
	assert_eq(str(packet["type"]), "void_burst_resolved", "of the burst type")
	assert_false(JSON.stringify(packet).contains(peer_pid) or JSON.stringify(packet).contains(other_pid), "carrying no player id")
	host._pending.clear()
	host._on_profession_unlocked(peer_pid, "VoidTouched")
	assert_eq(int(host._pending[0]["peer_id"]), 5, "the unlock goes to its owner alone")
	host._pending.clear()
	result["player_id"] = str(registry.local_player_id)
	host._on_void_burst_resolved(result)
	assert_eq(host._pending.size(), 0, "a burst on the host's own player is sent to nobody")

	var client := NetworkingSlice.new()
	add_child(client)
	client._role = NetworkingSlice.Role.CLIENT
	var seen: Array = []
	var on_burst := func(r: Dictionary) -> void:
		seen.append(r)
	GameBus.void_burst_resolved.connect(on_burst)
	client._route_h2c(packet)
	GameBus.void_burst_resolved.disconnect(on_burst)
	assert_eq(seen.size(), 1, "the client re-emits the burst")
	assert_true(bool(seen[0]["survived"]) and float(seen[0]["damage"]) == 40.0, "with its outcome")
	client.free()
	host.free()
	_free_void_rig(rig)

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

func _test_research_points_gate_and_spend() -> void:
	var t := TechnologySlice.new()
	add_child(t)
	var inv := InventorySlice.new()
	add_child(inv)
	t.inventory_slice = inv
	inv.add_item("Ferrite", 4)
	assert_true(bool(t.begin_research("TechBasicSmithing")["success"]), "the free root tech needs no points")
	t.complete_research("TechBasicSmithing")
	var cost := t.research_cost("TechMasterForge")
	assert_true(cost > 1, "master forge costs several points")
	inv.add_item("Ashite", 20)

	var short := t.begin_research("TechMasterForge")
	assert_false(bool(short["success"]), "no points: refused")
	assert_eq(str(short["reason"]), "insufficient_points", "with the points reason")
	assert_eq(inv.get_item_count("Ashite"), 20, "and no material is consumed")
	assert_eq(t.get_status("TechMasterForge"), "locked", "and the status is unchanged")

	t.grant_points("", "craft", cost - 1)
	assert_eq(str(t.begin_research("TechMasterForge")["reason"]), "insufficient_points", "one point short: still refused")
	assert_eq(t.get_points(), cost - 1, "and nothing is spent by a refusal")

	t.grant_points("", "craft", 3)
	# Phase 140 — the fabric's materialSource is the settlement stockpile: a pack full of ore is not enough.
	var homeless := t.begin_research("TechMasterForge")
	assert_eq(str(homeless["reason"]), "no_settlement", "materials in the pack do not count without a settlement")
	assert_eq(t.get_points(), cost + 2, "a refusal spends no points")
	var stock := _StubStockpile.new()
	t.settlement_slice = stock
	var ok := t.begin_research("TechMasterForge")
	assert_true(bool(ok["success"]), "with enough points research begins")
	assert_eq(t.get_points(), 2, "and exactly researchCost was spent")
	assert_eq(int(stock.stock["Ashite"]), 0, "the stockpile pays the materials")
	assert_eq(inv.get_item_count("Ashite"), 20, "and the pack is untouched")
	stock.free()
	t.free()
	inv.free()

## A settlement slice that always stands at the site and holds twenty Ashite.
class _StubStockpile extends Node:
	var stock := { "Ashite": 20 }
	func at_research_site(_pid: String) -> bool:
		return true
	func research_stock(_pid: String, item: String) -> int:
		return int(stock.get(item, 0))
	func consume_research(_pid: String, counts: Dictionary) -> bool:
		for item: String in counts:
			stock[item] = int(stock[item]) - int(counts[item])
		return true

func _test_research_points_craft_grant_and_roundtrip() -> void:
	var registry := PlayerRegistry.new()
	add_child(registry)
	var t := TechnologySlice.new()
	add_child(t)
	t.player_registry = registry
	var crafting := CraftingSlice.new()
	add_child(crafting)
	crafting.player_registry = registry
	crafting.technology_slice = t
	var a := "player_peer_pts_a"
	var b := "player_peer_pts_b"
	registry.ensure_player(a)
	registry.ensure_player(b)
	t.apply_statuses({ "TechBasicSmithing": "unlocked" }, a)
	var synced: Array = []
	var on_sync := func(pid: String, pts: int) -> void:
		synced.append([pid, pts])
	GameBus.research_points_synced.connect(on_sync)

	registry.get_inventory(a).add_item("Ferrite", 6)
	var r := crafting.craft("RecipeFerriteIngot", a)
	assert_true(bool(r["success"]), "the craft succeeds")
	var first := t.points_for("craft") + t.points_for("firstCraftOfRecipe")
	assert_eq(t.get_points(a), first, "the crafter earns craft + first-craft points")
	assert_eq(t.get_points(b), 0, "another player earns nothing")
	assert_eq(synced.back(), [a, first], "research_points_synced names the crafter and the balance")
	crafting.craft("RecipeFerriteIngot", a)
	assert_eq(t.get_points(a), first + t.points_for("craft"), "a repeat craft earns no first-craft bonus")

	# A refused craft earns nothing.
	var before := t.get_points(a)
	assert_false(bool(crafting.craft("RecipeFerriteIngot", b)["success"]), "b has no ferrite")
	assert_eq(t.get_points(a), before, "a failed craft pays nobody")

	# A client's own grant changes nothing.
	var c := TechnologySlice.new()
	add_child(c)
	c.is_authoritative = false
	assert_eq(c.grant_points("", "craft", 5), 0, "a client grant grants nothing")
	assert_eq(c.note_craft("RecipeFerriteIngot"), 0, "and so does a client craft note")
	assert_eq(c.get_points(), 0, "balance stays 0")
	assert_eq(t.grant_points(a, "bogus", 5), 0, "an unknown source grants nothing")
	assert_eq(t.grant_points(a, "craft", -3), 0, "and a non-positive amount")

	# Round trip through a JSON-encoded registry record.
	registry.record_technology(a, t.get_statuses(a))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(registry.get_player_data(a)))
	var reg2 := PlayerRegistry.new()
	add_child(reg2)
	reg2.apply_player_data(a, saved)
	var t2 := TechnologySlice.new()
	add_child(t2)
	t2.apply_statuses(reg2.get_record(a)["technology"], a)
	assert_eq(t2.get_points(a), before, "points survive a registry save/load")
	t2.note_craft("RecipeFerriteIngot", a)
	assert_eq(t2.get_points(a), before + t2.points_for("craft"), "and the paid first-craft bonus is remembered")
	# A legacy snapshot with no points loads as 0.
	t2.apply_statuses({ "TechBasicSmithing": "unlocked" }, a)
	assert_eq(t2.get_points(a), 0, "a legacy record loads as 0 points")
	assert_eq(t2.get_status("TechBasicSmithing", a), "unlocked", "keeping its statuses")
	# An unknown recipe id in a snapshot is dropped, not stored.
	t2.apply_statuses({ TechnologySlice.CRAFTED_KEY: ["RecipeFerriteIngot", "NotARecipe"] }, a)
	assert_eq(t2.get_statuses(a).get(TechnologySlice.CRAFTED_KEY, []), ["RecipeFerriteIngot"], "unknown first-craft ids are dropped")

	GameBus.research_points_synced.disconnect(on_sync)
	t2.free()
	reg2.free()
	c.free()
	crafting.free()
	t.free()
	registry.free()

func _test_research_points_gather_and_ui() -> void:
	var t := TechnologySlice.new()
	add_child(t)
	assert_eq(t.grant_points("", "gather", t.points_for("gather")), t.points_for("gather"), "a gather pays the fabric rule")
	var ui := _new_test_ui()
	ui.technology_slice = t
	assert_eq(ui.research_points(), t.points_for("gather"), "the UI reports the balance")
	var rows: Array = ui.technology_rows()
	var forge: Dictionary = {}
	for row in rows:
		if row["id"] == "TechAlchemy":
			forge = row
	assert_eq(int(forge["points_cost"]), t.research_cost("TechAlchemy"), "a row carries the point cost")
	assert_false(bool(forge["can_research"]), "short of points the button is disabled")
	assert_true(str(forge["reason"]).contains("research points"), "with the reason")
	t.grant_points("", "craft", 10)
	for row in ui.technology_rows():
		if row["id"] == "TechAlchemy":
			assert_true(bool(row["can_research"]), "with the points it is enabled")
			assert_eq(str(row["reason"]), "", "and carries no reason")
	ui.free()
	t.free()

func _test_research_points_fabric_data() -> void:
	var rule: Resource = GameData.WORLD_SYSTEMS.get("ResearchPointRule", null)
	assert_true(rule != null, "GameData has the ResearchPointRule table")
	var rules: Dictionary = rule.get("rules")
	for source in ["craft", "gather", "firstCraftOfRecipe"]:
		assert_true(rules.has(source) and int(rules[source]) >= 0, "rule %s is a non-negative integer" % source)
	var bound := int(rule.get("maxResearchCost"))
	for tech_id in GameData.TECHNOLOGIES:
		var cost := int(GameData.TECHNOLOGIES[tech_id].get("researchCost"))
		assert_true(cost >= 0 and cost <= bound, "%s researchCost is reachable" % tech_id)
	assert_eq(int(GameData.TECHNOLOGIES["TechBasicSmithing"].get("researchCost")), 0, "the root smithing tech is free")
	assert_true(int(GameData.TECHNOLOGIES["TechMasterForge"].get("researchCost")) > 0, "a later tech costs points")

func _test_void_failed_consume_keeps_counter() -> void:
	var inv := RefusingInventory.new()
	add_child(inv)
	inv.add_item("Voidite", 1)
	var crafting := CraftingSlice.new()
	add_child(crafting)
	crafting.inventory_slice = inv
	crafting.set_skill("Smithing", "journeyman")
	var r := crafting.craft(VOID_RECIPE, "")
	assert_false(bool(r["success"]), "the craft fails")
	assert_eq(str(r["reason"]), "missing_inputs", "on the consume")
	assert_eq(crafting._burst_counter(""), 0, "and the burst counter did not advance")
	crafting.free()
	inv.free()

func _test_void_burst_roll_golden_and_counter_roundtrip() -> void:
	# Pinned: a change to the mix changes every player's burst sequence.
	assert_eq(int(CraftingSlice.burst_roll(0, "player_a", 0) * 16777216.0), 14654706, "golden roll 1")
	assert_eq(int(CraftingSlice.burst_roll(0, "player_a", 1) * 16777216.0), 10874, "golden roll 2")
	assert_eq(int(CraftingSlice.burst_roll(1234, "player_a", 7) * 16777216.0), 10492433, "golden roll 3")
	assert_eq(int(CraftingSlice.burst_roll(-5, "player_b", 100) * 16777216.0), 5965196, "golden roll 4 (negative seed)")

	var rig := _make_void_rig()
	var registry: Node = rig["registry"]
	var crafting: Node = rig["crafting"]
	var pid := "player_peer_ctr"
	registry.ensure_player(pid)
	crafting.set_skill_for(pid, "Smithing", "journeyman")
	var start := _void_counter(pid, false)
	_void_craft(rig, pid, start)
	assert_eq(registry.get_craft_counter(pid), start + 1, "a craft advances the counter by one")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(registry.get_player_data(pid)))
	var reg2 := PlayerRegistry.new()
	add_child(reg2)
	reg2.apply_player_data(pid, saved)
	assert_eq(reg2.get_craft_counter(pid), start + 1, "the counter survives a registry save/load")
	var crafting2 := CraftingSlice.new()
	add_child(crafting2)
	crafting2.player_registry = reg2
	assert_eq(crafting2._burst_counter(pid), start + 1, "and the next roll continues the sequence")
	crafting2.free()
	reg2.free()
	_free_void_rig(rig)

func _test_void_burst_no_player_reports_no_flag() -> void:
	var rig := _make_void_rig()
	var crafting: Node = rig["crafting"]
	var spec: Dictionary = GameData.RECIPES[VOID_RECIPE].recipe["burst"]
	var result: Dictionary = crafting._resolve_burst(VOID_RECIPE, spec, "")
	assert_true(bool(result["burst"]["survived"]), "a full-health local body survives")
	assert_eq(str(result["burst"]["flag"]), "", "but with no player id no flag is reported")
	_free_void_rig(rig)

# ---------------------------------------------------------------------------
# Phase 125 — waystones
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
	m.list_item("seller", "hawk_feather", 1, 5.0, 0.0)
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
	var decisions: Array = p.get_decisions_log()
	assert_eq(decisions.size(), 1, "one ratified proposal logged")
	assert_eq(str(decisions[0]["title"]), "Ratify the thing", "log records the title")
	assert_eq(str(decisions[0]["state"]), "accepted", "log records accepted state")
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


func _test_phase147_first_craft_marker() -> void:
	var t := TechnologySlice.new()
	add_child(t)
	t.is_authoritative = true
	t._note_earned("", t.window_room(""))   # the window is full: the next craft pays nothing
	assert_eq(t.note_craft("RecipeFerriteIngot"), 0, "a full window grants nothing")
	assert_false(t._first_crafts.has(""), "and the first-craft marker is not burned")
	t.free()
