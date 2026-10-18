extends "res://src/tests/test_support.gd"
## Phase 133 — the creature tests, moved unchanged from the old single-file suite.


func register() -> void:
	# Phase 131 — the suite reads English text and must not see the developer's saved language.
	_run_test("battle: hit reduces defender hp",              _test_battle_hit_reduces_hp)
	_run_test("battle: miss leaves hp unchanged",             _test_battle_miss_leaves_hp_unchanged)
	_run_test("battle: kill emits creature_died signal",      _test_battle_kill_emits_death)
	_run_test("battle: reset_hp restores state",              _test_battle_reset_hp)
	_run_test("battle: resolves stats via creature_slice",    _test_battle_resolves_via_creature_slice)
	_run_test("models: every creature names a skeleton and ships a matching rig", _test_models_rigs_match_fabric)
	_run_test("models: a type without a model takes no slot from one that has it", _test_phase147_unmodelled_takes_no_slot)
	_run_test("models: a respawn teleport does not play run", _test_phase147_respawn_not_run)
	_run_test("models: a respawn near the corpse does not play run", _test_models_near_respawn_not_run)
	_run_test("models: an out-of-range type is pre-warmed one per frame", _test_models_template_prewarm)
	_run_test("models: range, hysteresis and the pool swap",    _test_models_range_hysteresis)
	_run_test("models: a missing key keeps the box, warns once per type", _test_models_missing_key_warns_once)
	_run_test("models: state-to-clip map and death does not loop", _test_models_clip_map)
	_run_test("models: MAX_MODELS keeps the nearest",           _test_models_max_models_nearest)
	_run_test("models: none are built without render_visuals",  _test_models_headless_builds_none)
	_run_test("creature: spawns instances from GameData",     _test_creature_spawns_from_gamedata)
	_run_test("creature: nearest_creature returns closest",   _test_creature_nearest)
	_run_test("creature: death marks instance dead",          _test_creature_death_marks_dead)
	_run_test("creature: respawn resets battle hp state",     _test_creature_respawn_resets_battle_hp)
	_run_test("creature: nearest_creature routes via hash",   _test_creature_nearest_via_hash)
	_run_test("creature: respawn re-hashes spatial position", _test_creature_respawn_rehashes_spatial)
	_run_test("spawn: ocean chunks grow no trees",            _test_ocean_spawns_no_land_tables)
	_run_test("status: the fabric table and creature on-hit entries",  _test_status_fabric_table)
	_run_test("status: burn totals, refresh, expiry and knockdown",    _test_status_burn_refresh_factor)
	_run_test("status: on-hit roll golden values and rate",            _test_status_roll_golden_rate)
	_run_test("status: knockback is clamped to walkable ground",       _test_status_knockback_clamped)
	_run_test("status: a landed hit applies effects and scales damage", _test_status_battle_hit)
	_run_test("status: immobilized players and creatures stay put",    _test_status_immobilized)
	_run_test("status: rain, death and persistence end or keep effects", _test_status_rain_death_persistence)
	_run_test("status: stacked ends round-trip, held peers do not move", _test_phase130_status_authority)
	_run_test("loot: known creature produces drops",          _test_loot_known_creature)
	_run_test("loot: drops read from fabric (LavaSlug)",     _test_loot_drops_from_fabric)
	_run_test("loot: unknown creature produces no drops",     _test_loot_unknown_creature)
	_run_test("loot: consume removes pickup",                 _test_loot_consume_removes)
	_run_test("loot: instance_id resolves to fabric key",     _test_loot_instance_id_resolve)
	_run_test("taming: fabric spec drives the interaction",    _test_taming_fabric_spec)
	_run_test("taming: a creature with no tame field is refused", _test_taming_not_tameable)
	_run_test("taming: wolf needs the alpha down",             _test_taming_wolf_requires_alpha_down)
	_run_test("taming: wolf grants flag and companion",        _test_taming_wolf_grants_flag_companion)
	_run_test("taming: unidentified tamer refused atomically", _test_taming_refusal_is_atomic)
	_run_test("taming: skill gate fails closed",               _test_taming_requires_skill)
	_run_test("taming: bare hands required",                   _test_taming_requires_unarmed)
	_run_test("taming: a peer's hands are the host's record",   _test_taming_peer_bare_hands_claim)
	_run_test("taming: fox feed yields and consumes the offer", _test_taming_fox_feed_yields)
	_run_test("taming: fox feed needs an offering",            _test_taming_fox_needs_offer)
	_run_test("taming: cooldown blocks a second feed",         _test_taming_cooldown)
	_run_test("taming: flags and offerings are per-player",    _test_taming_is_per_player)
	_run_test("taming: client forwards intent, mutates nothing", _test_taming_client_forwards_intent)
	_run_test("taming: a companion does not respawn",          _test_taming_companion_respawn_suppressed)
	_run_test("taming: companion is no target and follows owner", _test_taming_companion_follows)
	_run_test("taming: record round-trip keeps flag + companion", _test_taming_record_round_trip)
	_run_test("creature: respawns share one cap budget",         _test_creature_respawns_share_cap)
	_run_test("creature: chunk index matches the instance table", _test_creature_chunk_index)
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
	_run_test("spawn: hash bits are independent",                _test_spawn_roll_mix_avalanche)
	_run_test("spawn: missing fields warn once",                 _test_spawn_missing_fields_warns_once)
	_run_test("spawn: hash output pinned",                       _test_spawn_roll_mix_pinned)
	_run_test("spawn: seeded roll, density and pack size",       _test_spawn_roll_pure)
	_run_test("spawn: creature packs are scarce and seeded",     _test_spawn_creature_scarcity)
	_run_test("spawn: the population cap holds and is released", _test_spawn_population_cap)
	_run_test("spawn: packs stay in their chunk and retry",      _test_spawn_pack_bounds_and_retry)
	_run_test("spawn: density noise is per species",            _test_spawn_density_per_species)
	_run_test("spawn: tree density comes from the fabric",       _test_spawn_tree_density)
	_run_test("spawn: new players avoid colonized regions", _test_spawn_avoids_colonized)
	_run_test("spawn: friend code lands near the friend", _test_spawn_friend_near)
	_run_test("spawn: respawn point survives a move + reload (host and client)", _test_spawn_point_persists)
	_run_test("spawn: an exact far spawn respawns exactly; placement reads the record once", _test_exact_spawn_respawn)
	_run_test("spawn: counted chunks survive a colonization reload", _test_colonization_counted_persists)
	_run_test("spawn: the colonization map scores, persists and drops malformed data", _test_colonization_map)
	_run_test("spawn: a fresh join is placed, a reconnect is not", _test_spawn_registry_placement)
	_run_test("creature: despawn keeps the death record",         _test_despawn_keeps_death_record)
	_run_test("creature: recorded death survives boot replay",    _test_recorded_death_survives_boot_replay)
	_run_test("creature: state delta keeps the respawn deadline", _test_creature_state_delta_keeps_deadline)
	_run_test("taming: cooldowns are durable",                    _test_taming_cooldowns_are_durable)
	_run_test("taming: per-player mirrors are evicted",           _test_taming_mirrors_evicted_on_forget)
	_run_test("battle: player rounds route by target id",         _test_battle_routes_player_rounds_by_target)
	_run_test("creature: instances_view is cached and live",      _test_creature_instances_view_cached)
	_run_test("taming: cooldown mirror prunes in place",          _test_taming_cooldown_mirror_pruned_in_place)

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

func _test_status_fabric_table() -> void:
	var s := StatusEffects.new()
	for id in ["heat_burn", "paralysis", "knockback", "knockdown", "stagger"]:
		assert_false(s.row(id).is_empty(), "the fabric defines %s" % id)
	assert_eq(float(s.row("heat_burn")["damagePerSecond"]), 5.0, "heat-burn deals 5 per second")
	assert_eq(float(s.row("heat_burn")["durationSeconds"]), 8.0, "for 8 seconds")
	assert_eq(float(s.row("paralysis")["durationSeconds"]), 3.0, "paralysis lasts 3 seconds")
	assert_eq(float(s.row("knockdown")["damageTakenFactor"]), 1.5, "knockdown takes 1.5x")
	assert_eq(int(s.row("knockback")["displaceTiles"]), 1, "knockback is one tile")
	assert_true((s.row("heat_burn")["extinguishedBy"] as Array).has("rain"), "rain extinguishes the burn")
	assert_eq((GameData.CREATURES["VeilStalker"].get("onHitEffects") as Array)[0]["effect"], "paralysis", "VeilStalker paralyses")
	assert_eq(float((GameData.CREATURES["VeilStalker"].get("onHitEffects") as Array)[0]["chance"]), 0.2, "20% a hit")
	assert_eq((GameData.CREATURES["LavaSlug"].get("onHitEffects") as Array)[0]["effect"], "heat_burn", "LavaSlug burns")
	assert_eq((GameData.CREATURES["ForestBoar"].get("onHitEffects") as Array)[0]["effect"], "knockback", "ForestBoar gores")
	assert_false(s.apply("p1", "nonsense", 0.0), "an undefined effect is refused")

func _test_status_burn_refresh_factor() -> void:
	var s := StatusEffects.new()
	assert_true(s.apply("p1", "heat_burn", 100.0), "the burn applies")
	var total := 0.0
	var t := 100.0
	while t < 120.0:
		t += 0.25
		for ev in s.tick(t):
			total += float(ev["damage"])
	assert_true(absf(total - 40.0) < 0.001, "heat-burn deals 5 x 8 = 40 over its duration (got %f)" % total)
	assert_false(s.has_any("p1"), "and then ends")
	# Refresh, not stack: reapplying at 4 s restarts the 8 s without doubling the rate.
	s.apply("p2", "heat_burn", 0.0)
	var dealt := 0.0
	for ev in s.tick(4.0):
		dealt += float(ev["damage"])
	s.apply("p2", "heat_burn", 4.0)
	assert_eq(s.active("p2", 4.0).size(), 1, "one instance after a reapply")
	for ev in s.tick(5.0):
		dealt += float(ev["damage"])
	assert_true(absf(dealt - 25.0) < 0.001, "5 dps throughout: 4 s + 1 s = 25, never doubled (got %f)" % dealt)
	assert_true(absf(float(s.active("p2", 5.0)[0]["remaining"]) - 7.0) < 0.001, "the timer restarted at the reapply")
	# Knockdown multiplies damage while it lasts.
	s.apply("p3", "knockdown", 0.0)
	assert_eq(s.damage_factor("p3", 1.0), 1.5, "a knocked-down target takes 1.5x")
	assert_eq(s.damage_factor("p3", 2.5), 1.0, "and not once it stood")
	assert_eq(s.damage_factor("nobody", 0.0), 1.0, "no effects: 1x")
	# A stacking row (test table) adds instances up to the cap.
	var st := StatusEffects.new()
	st.table_override = { "poison": { "durationSeconds": 4.0, "damagePerSecond": 1.0, "stacks": true } }
	for i in StatusEffects.MAX_PER_TARGET + 3:
		st.apply("p", "poison", 0.0)
	assert_eq(st.active("p", 0.0).size(), StatusEffects.MAX_PER_TARGET, "a stacking row is bounded per target")

func _test_status_roll_golden_rate() -> void:
	var golden := [
		StatusEffects.roll_value(1, "ForestBoar", "player", 0),
		StatusEffects.roll_value(2, "VeilStalker", "player_1", 0),
		StatusEffects.roll_value(1000, "LavaSlug", "player_2", 1),
	]
	for i in golden.size():
		assert_true(golden[i] >= 0.0 and golden[i] < 1.0, "roll #%d is in [0, 1)" % i)
		assert_eq(int(golden[i] * 16777216.0), STATUS_ROLL_GOLDEN[i], "golden roll #%d" % i)
	assert_eq(StatusEffects.roll_value(7, "a", "b", 0), StatusEffects.roll_value(7, "a", "b", 0), "the roll is a pure function")
	assert_true(StatusEffects.roll_value(7, "a", "b", 0) != StatusEffects.roll_value(8, "a", "b", 0), "and depends on the round")
	var s := StatusEffects.new()
	var on_hit: Array = GameData.CREATURES["VeilStalker"].get("onHitEffects")
	var hits := 0
	for seq in 10000:
		if s.rolled_effects(on_hit, seq, "VeilStalker_0", "player").has("paralysis"):
			hits += 1
	assert_true(absf(float(hits) / 10000.0 - 0.2) < 0.01, "paralysis lands within 1 point of 20%% (got %d / 10000)" % hits)
	assert_eq(s.rolled_effects(GameData.CREATURES["LavaSlug"].get("onHitEffects"), 5, "x", "y"), ["heat_burn"], "chance 1.0 always lands")
	assert_eq(s.rolled_effects("junk", 1, "x", "y"), [], "a malformed list rolls nothing")

# ---------------------------------------------------------------------------
# Phase 130 — host authority sweep
# ---------------------------------------------------------------------------

func _test_status_knockback_clamped() -> void:
	var free_all := func(_p: Vector3) -> bool: return true
	var from := Vector3(10, 0, 0)
	var src := Vector3(8, 0, 0)
	var moved := StatusEffects.knockback_target(from, src, 2, 0.5, free_all)
	assert_true(moved.is_equal_approx(Vector3(11, 0, 0)), "pushed 2 tiles of 0.5 m away from the attacker")
	var wall := func(p: Vector3) -> bool: return p.x < 10.6
	var short := StatusEffects.knockback_target(from, src, 2, 0.5, wall)
	assert_true(short.is_equal_approx(Vector3(10.5, 0, 0)), "stops a tile short of a solid voxel")
	var boxed := func(_p: Vector3) -> bool: return false
	assert_eq(StatusEffects.knockback_target(from, src, 2, 0.5, boxed), from, "no free spot: the body stays")
	assert_eq(StatusEffects.knockback_target(from, from, 2, 0.5, free_all), from, "no direction: the body stays")

func _test_status_battle_hit() -> void:
	var b := BattleSlice.new()
	add_child(b)
	var s := StatusEffects.new()
	var clock := [0.0]
	b.status_effects = s
	b.now_fn = func() -> float: return clock[0]
	var knocks: Array = []
	var cb := func(target: String, attacker: String, tiles: int) -> void: knocks.append([target, attacker, tiles])
	GameBus.knockback_requested.connect(cb)
	# A LavaSlug hit burns; find a landed hit.
	var burned := false
	for i in 50:
		var r := b.resolve_round("LavaSlug", "player_1_1_aabbccdd11223344aabbccdd11223344")
		if r["outcome"] != "miss":
			burned = true
			break
	assert_true(burned and s.active("player_1_1_aabbccdd11223344aabbccdd11223344", 0.0).size() == 1, "a landed LavaSlug hit leaves heat-burn on the target")
	for i in 80:
		var r := b.resolve_round("ForestBoar", "player_1_2_aabbccdd11223344aabbccdd11223344")
		if r["outcome"] != "miss":
			break
	assert_true(knocks.size() >= 1 and knocks[0][0] == "player_1_2_aabbccdd11223344aabbccdd11223344" and knocks[0][2] == 1, "a landed ForestBoar hit asks for a one-tile knockback")
	assert_false(s.has_any("player_1_2_aabbccdd11223344aabbccdd11223344"), "knockback is instant: nothing is stored")
	GameBus.knockback_requested.disconnect(cb)
	# Knockdown scales the same seeded hit by 1.5.
	seed(99)
	var plain := b.resolve_round("GraywolfPack", "player_1_3_aabbccdd11223344aabbccdd11223344")
	s.apply("player_1_4_aabbccdd11223344aabbccdd11223344", "knockdown", 0.0)
	seed(99)
	var down := b.resolve_round("GraywolfPack", "player_1_4_aabbccdd11223344aabbccdd11223344")
	if plain["outcome"] != "miss":
		assert_true(absf(float(down["damage"]) - float(plain["damage"]) * 1.5) < 0.2, "a knocked-down target takes 1.5x the same hit")
	else:
		assert_eq(down["damage"], 0.0, "a miss deals nothing either way")
	# A creature's death or respawn clears its effects.
	s.apply("cr_1", "knockdown", 0.0)
	b._on_creature_respawned("cr_1", "ForestBoar")
	assert_false(s.has_any("cr_1"), "a respawn clears every effect")
	b.free()

func _test_status_immobilized() -> void:
	var t := [0.0]
	var p := PlayerSlice.new()
	p.status_clock = func() -> float: return t[0]
	p.apply_status_effects([{ "effect": "paralysis", "remaining": 3.0 }])
	assert_true(p.is_immobilized(), "paralysis immobilizes")
	assert_eq(PlayerSlice.held_speed(PlayerSlice.SPEED, p.is_immobilized()), 0.0, "movement input moves nothing")
	t[0] = 2.9
	assert_true(p.is_immobilized(), "for the whole duration")
	t[0] = 3.1
	assert_false(p.is_immobilized(), "and not after")
	assert_eq(PlayerSlice.held_speed(PlayerSlice.SPEED, p.is_immobilized()), PlayerSlice.SPEED, "speed returns")
	p.apply_status_effects([{ "effect": "bogus", "remaining": 3.0 }, "junk", { "effect": "stagger", "remaining": -1.0 }])
	assert_false(p.is_immobilized(), "unknown or spent entries are dropped")
	assert_eq(PlayerSlice.status_line([{ "effect": "heat_burn", "remaining": 4.2 }]), "heat burn 5s", "the HUD line names the effect and time")
	p.free()
	var ai := CreatureAI.new()
	var s := StatusEffects.new()
	ai.status_effects = s
	ai.now_fn = func() -> float: return t[0]
	t[0] = 0.0
	s.apply("boar_1", "stagger", 0.0)
	assert_true(ai.is_held("boar_1"), "a staggered creature is held")
	t[0] = 1.5
	assert_false(ai.is_held("boar_1"), "and released after a second")
	ai.free()

func _test_status_rain_death_persistence() -> void:
	var s := StatusEffects.new()
	s.apply("p1", "heat_burn", 0.0)
	var dry := func(_t: String) -> String: return "clear"
	var wet := func(_t: String) -> String: return "rain"
	assert_eq(s.tick(1.0, dry).size(), 1, "a dry tick burns")
	assert_eq(s.tick(2.0, wet).size(), 0, "a rain tick deals nothing")
	assert_false(s.has_any("p1"), "and the burn is gone on that tick")
	s.apply("p1", "heat_burn", 3.0)
	s.apply("p1", "knockdown", 3.0)
	s.clear("p1")
	assert_eq(s.active("p1", 3.5).size(), 0, "death clears all effects")
	# Registry round trip through JSON; a legacy record loads with none.
	s.apply("p2", "heat_burn", 10.0)
	s.apply("p2", "paralysis", 10.0)
	var reg := PlayerRegistry.new()
	reg.record_status_effects("p2", s.to_data("p2", 12.0))
	var json: Variant = JSON.parse_string(JSON.stringify(reg.get_player_data("p2")))
	var reg2 := PlayerRegistry.new()
	reg2.apply_player_data("p2", json)
	var s2 := StatusEffects.new()
	s2.from_data("p2", reg2.get_status_effects("p2"), 50.0)
	var left := s2.active("p2", 50.0)
	assert_eq(left.size(), 2, "both effects survive a save/load")
	assert_true(absf(float(left[0]["remaining"]) - 6.0) < 0.001, "with their remaining seconds (6 of the burn's 8)")
	var legacy := PlayerRegistry.new()
	legacy.apply_player_data("old", { "player_id": "old", "hp": 50.0 })
	assert_eq(legacy.get_status_effects("old"), [], "a legacy record loads with none")
	s2.from_data("old", [{ "effect": "heat_burn", "remaining": 9999.0 }, { "effect": "paralysis", "remaining": "x" }], 0.0)
	assert_true(float(s2.active("old", 0.0)[0]["remaining"]) <= 8.0, "a forged remaining time is clamped to the duration")
	reg.free()
	reg2.free()
	legacy.free()

func _test_phase130_status_authority() -> void:
	# Two stacked instances keep their own end times through to_data / from_data.
	var s := StatusEffects.new()
	s.table_override = { "bleed": { "durationSeconds": 10.0, "damagePerSecond": 1.0, "stacks": true } }
	s.apply("t1", "bleed", 0.0)
	s.apply("t1", "bleed", 6.0)
	var saved := s.to_data("t1", 7.0)
	assert_eq(saved.size(), 2, "two stacked instances are live")
	var s2 := StatusEffects.new()
	s2.table_override = s.table_override
	s2.from_data("t1", saved, 100.0)
	var rems: Array = []
	for e in s2.active("t1", 100.0):
		rems.append(snappedf(float(e["remaining"]), 0.01))
	rems.sort()
	assert_eq(rems, [3.0, 9.0], "each instance restores its own remaining time")

	# A paralyzed peer's reports are dropped by the host; a free peer's are not.
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.set_transport(MemoryTransport.new([5]))
	var held := [false]
	n.peer_held = func(_peer: int) -> bool: return held[0]
	n._route_c2h(5, { "type": "player_moved", "position": [1.0, 2.0, 3.0] })
	assert_eq(n.get_last_known_state(5), Vector3(1.0, 2.0, 3.0), "the first report records")
	held[0] = true
	n._route_c2h(5, { "type": "player_moved", "position": [50.0, 2.0, 3.0] })
	assert_eq(n.get_last_known_state(5), Vector3(1.0, 2.0, 3.0), "a held peer's move changes nothing")
	held[0] = false
	n._route_c2h(5, { "type": "player_moved", "position": [50.0, 2.0, 3.0] })
	assert_eq(n.get_last_known_state(5), Vector3(50.0, 2.0, 3.0), "released, the peer moves again")
	# A peer with no reported state reads as the origin: knockback must see it as stateless.
	assert_false(n.has_last_known_state(9), "an unreported peer has no state")
	n.free()

func _test_loot_known_creature() -> void:
	var l := LootSlice.new()
	add_child(l)
	var drops: Array = []
	GameBus.loot_dropped.connect(func(pid, iid, _pos, qty):
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
	GameBus.loot_dropped.connect(func(pid, iid, _pos, qty):
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
	GameBus.loot_dropped.connect(func(pid, iid, _pos, qty):
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
	# CombatWiring._on_player_damaged). Phase 36 closed on the opposite: a peer was chased
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

## Phase 57 — a creature resource lacking spawnChance/spawnDensity warns once (the flag is
## the once-latch the warning sits behind) and still spawns, without a roll.
func _test_spawn_missing_fields_warns_once() -> void:
	var src := GDScript.new()
	src.source_code = "extends Resource\nvar biome: int = 0\nvar spawnCount: int = 2\n"
	assert_eq(src.reload(), OK, "the field-less stand-in compiles")
	var fake: Resource = src.new()
	var c := CreatureSlice.new()
	c.render_visuals = false
	# A scratch table with only the field-less creature, a stub terrain that puts every chunk in its
	# biome, and a population cap of 1 under a pack of 2: the pack is refused whole and deferred, so the
	# real `spawn_for_chunk` reads the fields without needing a spawnable body.
	c.creature_table = { "NoFields": fake }
	var terrain := _BiomeStub.new()
	terrain.biome = "TemperateForest"
	c.terrain_slice = terrain
	c._population_cap = 1
	add_child(c)
	var was_quiet: bool = Diag.quiet
	Diag.quiet = true
	assert_false(c._warned_spawn_fields.has("NoFields"), "nothing warned before the first spawn")
	assert_true(CreatureSlice.spawn_chance_of(fake) == null and CreatureSlice.spawn_density_of(fake) == null, "missing fields read as null (spawn without a roll)")
	c._warned_spawn_fields.clear()
	c.spawn_for_chunk(Vector2i(3, 4))
	assert_true(c._warned_spawn_fields.has("NoFields"), "spawn_for_chunk reports the missing fields")
	assert_true(c._deferred_packs.has([Vector2i(3, 4), "NoFields"]), "and the species still tries to spawn, without a roll")
	assert_eq(c._deferred_packs[[Vector2i(3, 4), "NoFields"]], 2, "a full pack, no noise applied")
	c.spawn_for_chunk(Vector2i(5, 6))
	assert_eq(c._warned_spawn_fields.size(), 1, "once per species, however many chunks spawn")
	c.creature_table = GameData.CREATURES
	c._warned_spawn_fields.clear()
	for key in GameData.CREATURES:
		c._warn_missing_spawn_fields(str(key), CreatureSlice.spawn_chance_of(GameData.CREATURES[key]), CreatureSlice.spawn_density_of(GameData.CREATURES[key]))
	assert_eq(c._warned_spawn_fields.size(), 0, "the fabric's own creatures all carry both fields")
	Diag.quiet = was_quiet
	c.terrain_slice = null
	terrain.free()
	c.free()

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

func _test_spawn_tree_density() -> void:
	var w := _spawn_world(4242, "TemperateForest")
	var t := _make_tree_slice()
	t.terrain_slice = w["terrain"]
	assert_eq(t.density_for("TemperateForest"), 8, "forest density is the fabric treeDensity")
	assert_eq(t.density_for("TemperateGrassland"), 2, "grassland density is the fabric treeDensity")
	assert_eq(t.density_for("VolcanicBadlands"), 0, "the badlands grow no trees")
	var seen := {}
	for ch in w["chunks"]:
		var n: int = t.tree_count_for(ch, "TemperateForest")
		seen[n] = true
		assert_eq(n, t.tree_count_for(ch, "TemperateForest"), "the count is pure in (seed, chunk)")
	assert_true(seen.size() > 1, "tree counts vary across chunks")
	assert_eq(t.tree_count_for(Vector2i(0, 0), "VolcanicBadlands"), 0, "no trees in the badlands")
	t.free()

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
	gr._persistence_wiring.place_local_player(Vector3(5.0, 5.0, 5.0))
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
	gr._persistence_wiring.place_local_player(Vector3(5.0, 5.0, 5.0))
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
	var cmap := ColonizationMapScript.new()
	cmap.note_home(Vector2i(0, 0))
	@warning_ignore("integer_division")
	var ring := TerrainSlice.circumference_chunks() / 32
	assert_true(cmap.is_near_colonized(-10.0, 10.0, 100.0, 1.0), "distance is measured from the region's edge")
	assert_true(cmap.is_near_colonized(float(ring) * ColonizationMapScript.REGION_METERS - 50.0, 10.0, 100.0, 1.0), "distance wraps across the antimeridian")
	assert_true(not cmap.is_near_colonized(5000.0, 10.0, 100.0, 1.0), "a far point is not near")
	var seeded := ColonizationMapScript.new()
	seeded.seed_from_regions([Vector2i(4, 4)])
	seeded.seed_from_regions([Vector2i(4, 4)])
	assert_eq(seeded.score(Vector2i(4, 4)), 1.0, "seeding from region files is idempotent")

func _test_spawn_registry_placement() -> void:
	var reg := PlayerRegistry.new()
	reg.is_authoritative = true
	var calls: Array = []
	reg.set_spawn_placer(func(placed_pid: String, code: String) -> Dictionary:
		calls.append([placed_pid, code])
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
	reg.set_friend_locator(func(h: String) -> Variant: return (Vector3(5.0, 5.0, 5.0) as Variant) if h == ghost else null)
	assert_eq(reg.friend_position(ghost), Vector3(5.0, 5.0, 5.0), "an offline friend is located by the disk locator")
	reg.free()


# ---------------------------------------------------------------------------
# World clock tests (Phase 54)
# ---------------------------------------------------------------------------

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
# Phase 143 — creature models
# ---------------------------------------------------------------------------

const CreatureVisualsScript := preload("res://src/creature/creature_visuals.gd")

## A rendered slice with `n` creatures of `cid` at x = 0, 10, 20... on the z = 0 line (client path).
func _model_slice(cid: String, n: int) -> CreatureSlice:
	var c := CreatureSlice.new()
	add_child(c)
	for i in n:
		c.apply_creature_state("m%d" % i, cid, "idle", Vector3(i * 10.0, 0.0, 0.0), 10.0)
	return c

func _test_models_rigs_match_fabric() -> void:
	assert_true(GameData.CREATURES.size() >= 10, "the roster is loaded")
	for cid: String in GameData.CREATURES:
		var res: Resource = GameData.CREATURES[cid]
		var family: String = str(res.get("skeleton"))
		assert_true(GameData.SKELETONS.has(family), "%s names a known skeleton (%s)" % [cid, family])
		var root := AssetOverlay.load_rig_scene(AssetOverlayScript.creature_model_key(cid))
		assert_true(root != null, "%s model parses" % cid)
		if root == null or not GameData.SKELETONS.has(family):
			if root != null:
				root.free()
			continue
		var skeletons := root.find_children("*", "Skeleton3D", true, false)
		assert_eq(skeletons.size(), 1, "%s has one Skeleton3D" % cid)
		if skeletons.size() == 1:
			var sk: Skeleton3D = skeletons[0]
			for b in GameDataReader.json_field(GameData.SKELETONS[family], "bones", []):
				assert_true(sk.find_bone(str(b["name"])) >= 0, "%s has bone %s of %s" % [cid, b["name"], family])
		var ap := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
		assert_true(ap != null, "%s has an AnimationPlayer" % cid)
		if ap != null:
			for clip in ["idle", "walk", "run", "fall", "land", "attack", "death"]:
				assert_true(ap.has_animation(clip), "%s has clip %s" % [cid, clip])
		root.free()

func _test_models_range_hysteresis() -> void:
	var c := _model_slice("GraywolfPack", 1)
	var v = c.visuals()
	var mi: int = int(c._instances["m0"]["mi"])
	var pool = c._pool
	assert_true(pool.is_shown(mi), "a fresh creature draws as a box")
	v.reselect(c._instances, Vector3(0, 0, CreatureVisualsScript.MODEL_RANGE_M - 1.0))
	assert_true(c.has_model("m0"), "inside the range it has a model")
	assert_false(pool.is_shown(mi), "and no pool box")
	v.reselect(c._instances, Vector3(0, 0, CreatureVisualsScript.MODEL_RANGE_M + 2.0))
	assert_true(c.has_model("m0"), "inside the hysteresis band the model stays")
	v.reselect(c._instances, Vector3(0, 0, CreatureVisualsScript.MODEL_RANGE_M + CreatureVisualsScript.HYSTERESIS_M + 1.0))
	assert_false(c.has_model("m0"), "past the band the model goes")
	assert_true(pool.is_shown(mi), "and the box returns")
	v.reselect(c._instances, Vector3(0, 0, CreatureVisualsScript.MODEL_RANGE_M + 2.0))
	assert_false(c.has_model("m0"), "inside the band but without a model, none is attached")
	c.set_instance_position("m0", Vector3(1, 0, 0))
	v.reselect(c._instances, Vector3(0, 0, 5.0))
	c.set_instance_position("m0", Vector3(2, 0, 0))
	assert_false(pool.is_shown(mi), "a moving modelled creature does not bring its box back")
	c.free()

func _test_models_missing_key_warns_once() -> void:
	var c := CreatureSlice.new()
	add_child(c)
	c.apply_creature_state("g0", "Ghost", "idle", Vector3.ZERO, 10.0)
	c.apply_creature_state("g1", "Ghost", "idle", Vector3(2, 0, 0), 10.0)
	var before := Diag.warn_count()
	c.visuals().reselect(c._instances, Vector3.ZERO)
	c.visuals().reselect(c._instances, Vector3.ZERO)
	assert_false(c.has_model("g0"), "no model for a missing key")
	assert_true(int(c._instances["g0"]["mi"]) >= 0 and c._pool.is_shown(int(c._instances["g0"]["mi"])), "it renders through the pool")
	assert_eq(Diag.warn_count() - before, 1, "one warning per type, not per creature or pass")
	c.free()

func _test_models_clip_map() -> void:
	var V := CreatureVisualsScript
	for st: String in V.STATES:
		for sp in [0.0, 1.0, 5.0]:
			var clip: String = V.clip_name(st, sp)
			assert_true(["idle", "walk", "run", "fall", "land", "attack", "death"].has(clip), "%s at %s maps to a shared clip (%s)" % [st, sp, clip])
	assert_eq(V.clip_name("dead", 0.0), "death", "a dead creature plays death")
	assert_eq(V.clip_name("dead", 6.0), "death", "even with residual speed")
	assert_false(V.clip_loops("dead"), "death does not loop")
	assert_true(V.clip_loops("idle"), "idle loops")
	assert_eq(V.clip_name("fleeing", 0.0), "run", "fleeing runs")
	assert_eq(V.clip_name("aggressive", 0.0), "attack", "a stationary aggressor attacks")
	assert_eq(V.clip_name("idle", 1.0), "walk", "idle at walking speed walks")
	# -Z forward model: facing +Z needs a half turn, facing -Z none.
	assert_true(absf(V.yaw_for_direction(Vector3(0, 0, -1))) < 0.001, "-Z needs no turn")
	assert_true(absf(absf(V.yaw_for_direction(Vector3(0, 0, 1))) - PI) < 0.001, "+Z needs a half turn")
	var c := _model_slice("GraywolfPack", 1)
	c.visuals().reselect(c._instances, Vector3.ZERO)
	var tree: AnimationTree = c.visuals().models["m0"]["tree"]
	var death := (tree.get_node(tree.anim_player) as AnimationPlayer).get_animation("death")
	assert_eq(death.loop_mode, Animation.LOOP_NONE, "the death clip is set not to loop")
	c.free()

func _test_models_max_models_nearest() -> void:
	var c := _model_slice("GraywolfPack", 8)
	var v = c.visuals()
	v.max_models = 3
	v.reselect(c._instances, Vector3(-1.0, 0, 0))
	assert_eq(v.models.size(), 3, "MAX_MODELS is respected")
	for id in ["m0", "m1", "m2"]:
		assert_true(c.has_model(id), "%s is among the nearest" % id)
	assert_false(c.has_model("m3"), "a farther creature stays a box")
	assert_eq(CreatureVisualsScript.select_ids([["a", 5.0], ["b", 1.0], ["c", 50.0]], {}, 40.0, 6.0, 5), ["b", "a"], "select_ids orders by distance and applies the range")
	c.free()

func _test_models_headless_builds_none() -> void:
	var c := CreatureSlice.new()
	c.render_visuals = false
	add_child(c)
	c.apply_creature_state("h0", "GraywolfPack", "idle", Vector3.ZERO, 10.0)
	assert_true(c.visuals() == null, "no model node host without render_visuals")
	assert_false(c.has_model("h0"), "no model")
	c._process(0.1)
	c.free()


func _test_phase147_unmodelled_takes_no_slot() -> void:
	var c := CreatureSlice.new()
	add_child(c)
	c.apply_creature_state("g0", "Ghost", "idle", Vector3(0, 0, 0), 10.0)
	c.apply_creature_state("w1", "GraywolfPack", "idle", Vector3(5, 0, 0), 10.0)
	c.apply_creature_state("w2", "GraywolfPack", "idle", Vector3(10, 0, 0), 10.0)
	var v = c.visuals()
	v.max_models = 2
	var was_quiet := Diag.quiet
	Diag.quiet = true
	v.reselect(c._instances, Vector3(-1.0, 0, 0))
	Diag.quiet = was_quiet
	assert_false(c.has_model("g0"), "the nearest creature has no model key and keeps its box")
	assert_true(c.has_model("w1") and c.has_model("w2"), "both modellable creatures still get one of the two slots")
	c.free()

func _test_phase147_respawn_not_run() -> void:
	var c := _model_slice("GraywolfPack", 1)
	var v = c.visuals()
	v.reselect(c._instances, Vector3.ZERO)
	assert_true(c.has_model("m0"), "the wolf has a model")
	c.apply_creature_state("m0", "GraywolfPack", "idle", Vector3(400, 0, 300), 10.0)
	v._update_model("m0", c._instances["m0"], 0.05)
	var m: Dictionary = v.models["m0"]
	assert_eq(float(m["speed"]), 0.0, "a jump to the respawn point is not a speed")
	assert_true(int(m["loco"]) != CreatureVisualsScript.Locomotion.State.RUN, "so the clip is not run")
	c.free()

func _test_models_near_respawn_not_run() -> void:
	var c := _model_slice("GraywolfPack", 1)
	var v = c.visuals()
	v.reselect(c._instances, Vector3.ZERO)
	c.apply_creature_state("m0", "GraywolfPack", "dead", Vector3.ZERO, 0.0)
	v._update_model("m0", c._instances["m0"], 0.05)
	# Respawned 3 m away: under TELEPORT_JUMP_M, so only leaving `dead` tells it from a run.
	c.apply_creature_state("m0", "GraywolfPack", "idle", Vector3(3, 0, 0), 10.0)
	v._update_model("m0", c._instances["m0"], 0.05)
	var m: Dictionary = v.models["m0"]
	assert_eq(float(m["speed"]), 0.0, "leaving death resets the speed estimate")
	assert_eq(int(m["loco"]), CreatureVisualsScript.Locomotion.State.IDLE, "so the respawned body idles")
	c.free()

func _test_models_template_prewarm() -> void:
	var c := _model_slice("GraywolfPack", 1)
	var v = c.visuals()
	v.reselect(c._instances, Vector3(0, 0, 1000.0))
	assert_false(v._templates.has("GraywolfPack"), "a far creature's type is not built inside the range check")
	assert_eq(v.prewarm_one(), "GraywolfPack", "the next frame builds the queued type")
	assert_true(v._templates.has("GraywolfPack"), "so its first model needs no build")
	assert_eq(v.prewarm_one(), "", "one type per frame, nothing left")
	v.reselect(c._instances, Vector3(0, 0, 1000.0))
	assert_eq(v.prewarm_one(), "", "a built type is not queued again")
	c.free()
