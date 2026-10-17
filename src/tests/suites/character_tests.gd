extends "res://src/tests/test_support.gd"
## Phase 133 — the character tests, moved unchanged from the old single-file suite.


func register() -> void:
	_run_test("locomotion: reset stands a dead avatar back up", _test_locomotion_reset_after_death)
	_run_test("locomotion: a step down is not a fall", _test_locomotion_step_down_is_not_a_fall)
	_run_test("player: the camera eases over a step and snaps on a teleport", _test_player_camera_height_follow)
	_run_test("player: deep water is swum, not walked",       _test_player_swims_in_deep_water)
	_run_test("player: swimming reads the voxel column, not the generated height", _test_swim_reads_voxel_column)
	_run_test("player: rebased origin keeps the world position", _test_world_pos_rebase)
	_run_test("player: the scene origin is the driver's integer chunk", _test_scene_origin_single_source)
	_run_test("player: exact chunk + local far from the origin", _test_player_exact_far_position)
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
	_run_test("equipment: slots cached, peer evict, owner map", _test_equipment_phase48_misc)
	_run_test("equipment: host worn set + AOI enter/leave",      _test_equipment_host_and_aoi_transitions)
	_run_test("equipment: rules totals + sanitize",             _test_equipment_rules_totals)
	_run_test("equipment: derived stats + record + replicate",  _test_character_derived_stats_and_record)
	_run_test("player: a suppressed ghost is not drawn twice",   _test_player_ghost_suppression)
	_run_test("player: respawn resets hp and alive flag",      _test_player_respawn)
	_run_test("character: remote avatar move/remove",           _test_character_remote_avatar)
	_run_test("player: the loading freeze refuses world input",  _test_player_world_input_freeze)
	_run_test("player: the loading freeze holds the body",       _test_player_movement_freeze)
	_run_test("player: facing is a normalized yaw vector",      _test_player_facing)
	_run_test("identity: public handles are derived + opaque",   _test_identity_handles_are_derived_and_opaque)
	_run_test("identity: social syncs carry handles, not ids",   _test_identity_syncs_are_redacted)
	_run_test("identity: a client adopts its own handle",        _test_client_adopts_its_own_handle)
	_run_test("identity: restart round-trip restores the world",  _test_identity_restart_round_trip)
	_run_test("identity: reconnect keeps the inventory",         _test_identity_reconnect_keeps_inventory)
	_run_test("identity: disconnect mid-craft stays consistent", _test_identity_disconnect_mid_craft)
	_run_test("identity: spoofed id is rejected",               _test_identity_spoofed_id_rejected)
	_run_test("identity: snapshot carries own record only on handshake", _test_identity_snapshot_own_record_rule)
	_run_test("identity: record replay skips ids not spawned",   _test_identity_record_replay_skips_unknown_ids)
	_run_test("identity: unknown peer position is not 0,0,0",    _test_identity_unknown_peer_has_no_position)
	_run_test("identity: minted id carries 128-bit entropy",      _test_minted_id_has_crypto_entropy)
	_run_test("identity: local player id is not claimable",       _test_local_player_id_not_claimable)
	_run_test("identity: offline record loads lazily on claim",   _test_record_loaded_lazily_on_claim)
	_run_test("identity: save writes online records only",        _test_save_writes_online_records_only)
	_run_test("identity: client-declared hp is never persisted",   _test_remote_hp_not_persisted)
	_run_test("identity: disconnect evicts record + inventory",   _test_disconnect_evicts_player)
	_run_test("identity: handshake retry re-answers a bound peer", _test_handshake_retry_reanswers_peer)
	_run_test("identity: a named party is a handle, not an id",   _test_named_party_accepts_handles_only)
	# Phase 38 review fixes
	_run_test("identity: the host simulates a peer's hp",         _test_host_simulates_peer_hp)
	# Phase 39 — deliverable 1 (a downed body comes back) and the network harness's
	# own pure logic. The harness's SOCKET half runs in its own boot mode
	# (`--net-harness <role>`, see src/tests/net_harness.gd); everything here is the
	# part that can be asserted without frames.
	_run_test("identity: the respawn rule is pure",               _test_hp_after_respawn_is_pure)
	_run_test("identity: a downed peer comes back",               _test_host_simulated_hp_respawns)
	_run_test("identity: set_hp starts the respawn countdown",    _test_player_set_hp_starts_respawn)
	_run_test("identity: set_hp announces and clears",           _test_player_set_hp_announces_and_clears)
	_run_test("identity: a sliver of health is down",             _test_hp_sliver_is_downed)

func _test_locomotion_reset_after_death() -> void:
	var loco := Locomotion.new()
	loco.trigger_death()
	assert_eq(loco.state_name(), "DEATH", "death is the terminal pose")
	loco.reset()
	assert_eq(loco.state_name(), "IDLE", "a respawn resets it to idle")

## Walking off a block leaves the body airborne for a fraction of a second. That must keep
## the walk pose (no FALL, then no LAND); only a longer or faster drop reads as a fall.
func _test_locomotion_step_down_is_not_a_fall() -> void:
	var dt := 1.0 / 60.0
	var loco := Locomotion.new()
	loco.update(2.0, true, 0.0, dt)
	assert_eq(loco.get_state(), Locomotion.State.WALK, "walking on the ground")
	# A 0.5 m drop under gravity: about 0.32 s in the air, reaching -3.1 m/s.
	var vy := 0.0
	var t := 0.0
	while t < 0.32:
		vy -= 9.8 * dt
		t += dt
		loco.update(2.0, false, vy, dt)
		assert_true(loco.get_state() != Locomotion.State.FALL, "a step down holds the walk pose (%.2f s)" % t)
	loco.update(2.0, true, 0.0, dt)
	assert_eq(loco.get_state(), Locomotion.State.WALK, "and lands straight back into the walk, with no LAND pose")
	# A real drop: once the grace is over the body falls, and landing plays LAND.
	t = 0.0
	vy = 0.0
	while t < Locomotion.FALL_GRACE + 0.05:
		vy -= 9.8 * dt
		t += dt
		loco.update(2.0, false, vy, dt)
	assert_eq(loco.get_state(), Locomotion.State.FALL, "a longer drop falls")
	loco.update(2.0, true, 0.0, dt)
	assert_eq(loco.get_state(), Locomotion.State.LAND, "landing from a fall plays LAND")
	# A fast drop falls at once (knockback off a cliff, say).
	var fast := Locomotion.new()
	fast.update(0.0, false, -Locomotion.FALL_SPEED - 0.5, dt)
	assert_eq(fast.get_state(), Locomotion.State.FALL, "a fast drop falls without waiting for the grace")
	assert_false(Locomotion.is_falling(10.0, 1.0), "rising (a jump) never reads as falling")
	# Phase 149 — a jump that outlasts the fall threshold does not enter FALL before its apex.
	var jump := Locomotion.new()
	jump.update(2.0, true, 0.0, dt)
	var jt := 0.0
	var jvy := 6.0
	while jvy > 0.0:
		jvy -= 9.8 * dt
		jt += dt
		jump.update(2.0, false, jvy, dt)
		if jvy > 0.0:
			assert_true(jump.get_state() != Locomotion.State.FALL, "rising never falls (%.2f s)" % jt)
	assert_true(jt > Locomotion.FALL_GRACE, "the jump outlasts the fall grace (%.2f s)" % jt)
	assert_true(jump.get_state() != Locomotion.State.FALL, "no FALL pose at the apex")

## The camera follows the body's height with exponential easing: a block step is spread
## over several frames (never overshooting, always converging), while the first frame and
## a teleport snap straight to the body.
func _test_player_camera_height_follow() -> void:
	var dt := 1.0 / 60.0
	assert_eq(PlayerSlice.follow_height(NAN, 7.0, dt), 7.0, "the first frame snaps to the body")
	assert_eq(PlayerSlice.follow_height(0.0, 50.0, dt), 50.0, "a teleport snaps")
	var y := 1.0
	var first := PlayerSlice.follow_height(y, 1.5, dt)
	assert_true(first > 1.0 and first < 1.25, "one frame covers only part of a 0.5 m step (%.3f)" % first)
	for i in 60:
		var next := PlayerSlice.follow_height(y, 1.5, dt)
		assert_true(next >= y and next <= 1.5, "the ease never overshoots the step")
		y = next
	assert_true(absf(y - 1.5) < 0.01, "within a second the camera has settled on the new height (%.4f)" % y)

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
	@warning_ignore("integer_division")
	assert_eq(stepper["chunk"].x, 312500 + (floori(far["local"].x + 50.0) / 32), "400 steps = 50 m east")
	# Walking across a chunk edge normalises.
	var walked := WorldPos.normalized({"chunk": Vector2i(5, 5), "local": Vector3(33.0, 0.0, -1.0)})
	assert_eq(walked["chunk"], Vector2i(6, 4), "walking over an edge changes the chunk")
	assert_eq(walked["local"], Vector3(1.0, 0.0, 31.0), "and wraps the local offset")

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
	var on_spawned := func(spawned_iid, skeleton_id, position):
		captured["count"] = captured.get("count", 0) + 1
		captured["iid"] = spawned_iid
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
	# Knees and elbows: each limb has a middle joint that bends during the stride (a knee
	# folds the shin back, an elbow folds the forearm forward) and is straight at rest.
	var knees: Array = []
	var elbows: Array = []
	for limb in [arm_l, arm_r]:
		assert_eq(limb.get_child_count(), 2, "an arm is an upper capsule plus an elbow joint")
		elbows.append(limb.get_child(1))
	var legs: Node3D = ch.get_part_node(iid, "body_legs")
	for leg in legs.get_children():
		knees.append(leg.get_child(1))
		assert_true(leg.get_child(1).get_child_count() == 2, "a knee carries the shin and the foot")
	for knee in knees:
		assert_true(knee.rotation.x < -0.001, "a knee bends back (foot behind) mid-stride (%.3f)" % knee.rotation.x)
	for elbow in elbows:
		assert_true(elbow.rotation.x > 0.001, "an elbow bends forward mid-stride (%.3f)" % elbow.rotation.x)
	for i in 30:
		ch.sync_player_avatar(iid, Vector3.ZERO, Vector3.ZERO, 0.0, true, 0.1, terrain)
	for joint in knees + elbows:
		assert_true(absf(joint.rotation.x) < 0.001, "idle straightens the knees and elbows")
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

## Host-authoritative equip — the client diffs its avatar's set into per-slot actions.
func _test_equip_actions_diff() -> void:
	assert_eq(EquipmentRules.diff_actions({}, {}), [], "no change, no action")
	assert_eq(EquipmentRules.diff_actions({}, { "Chest": "A" }), [{ "slot": "Chest", "item": "A" }], "a new item is an equip")
	assert_eq(EquipmentRules.diff_actions({ "Chest": "A" }, {}), [{ "slot": "Chest", "item": "" }], "a removed item is an unequip")
	assert_eq(EquipmentRules.diff_actions({ "Chest": "A" }, { "Chest": "B" }), [{ "slot": "Chest", "item": "B" }], "a swap is one equip")
	assert_eq(EquipmentRules.diff_actions({ "Chest": "A", "Head": "H" }, { "Chest": "A", "MainHand": "S" }),
		[{ "slot": "Head", "item": "" }, { "slot": "MainHand", "item": "S" }], "only differing slots, sorted")


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
		gr._character_wiring.apply_local_equipment({})
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
		gr._character_wiring.apply_local_equipment({ "Head": "FerriteHelmet" })
		assert_eq(ch.get_equipment_set(iid).get("Head", ""), "FerriteHelmet", "%s: a recorded set is worn" % tag)
		gr.free()
		ch.free()
		reg.free()

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
	gr._peer_wiring.on_own_state_synced({ "equipment": {}, "equipment_seq": 1 })
	assert_eq(ch.get_equipment_set(iid).get("Chest", ""), "VeilsteelChestplate", "the older revoke is ignored")
	gr._peer_wiring.on_own_state_synced({ "equipment": { "Chest": "VeilsteelChestplate" }, "equipment_seq": 2 })
	assert_eq(ch.get_equipment_set(iid).get("Chest", ""), "VeilsteelChestplate", "the newer reply keeps the item")
	gr._peer_wiring.on_own_state_synced({ "equipment": {}, "equipment_seq": 2 })
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
## networking slice's no-socket test seam: with a `MemoryTransport` set, every fan-out path
## (`_connected_peers()`) answers it and `_deliver` appends to its outbox.
func _test_equipment_host_and_aoi_transitions() -> void:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("player_host_1")
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.player_registry = reg
	n.set_transport(MemoryTransport.new([2, 3]))
	var pid2 := str(reg.resolve_identity(2))
	var pid3 := str(reg.resolve_identity(3))
	n.remember_player_state(2, Vector3(0, 0, 0))
	n.remember_player_state(3, Vector3(1000, 0, 0))
	n.set_host_position(Vector3(5, 0, 0))

	# Host as owner: peer 2 (in AOI) is a target, peer 3 (far) is not, the host never is.
	assert_eq(n.equipment_targets(NetworkingSlice.HOST_PEER_ID), [2], "the host's set goes to peers in its AOI only")
	assert_eq(n.equipment_targets(2), [], "a lone nearby peer has no other peer to tell (host excluded)")
	n.memory_transport().outbox.clear()
	n._on_equipment_changed("player_host_1", { "Chest": "VeilsteelChestplate" })
	assert_eq(n.memory_transport().outbox.size(), 1, "one delivery for the host's gear change")
	if n.memory_transport().outbox.size() == 1:
		assert_eq(n.memory_transport().outbox[0]["peer_id"], 2, "to the peer in AOI")
		assert_eq(n.memory_transport().outbox[0]["payload"]["type"], "peer_equipment", "as a peer_equipment packet")
		assert_eq(n.memory_transport().outbox[0]["payload"]["peer_id"], NetworkingSlice.HOST_PEER_ID, "tagged with the host's id")

	# Enter: peer 3 wears something while far away, then walks into the host's AOI (peer 2 is already there).
	reg.record_equipment(pid3, { "Chest": "VeilsteelChestplate" })
	reg.record_equipment(pid2, { "Chest": "VeilsteelChestplate" })
	n.memory_transport().outbox.clear()
	n._equipment_sent.clear()
	n.remember_player_state(3, Vector3(10, 0, 0))
	n._refresh_equipment_pairs(3)
	var sent_to_2 := false
	var sent_to_3 := false
	for m in n.memory_transport().outbox:
		var pl: Dictionary = m["payload"]
		if pl["type"] == "peer_equipment" and pl["peer_id"] == 3 and m["peer_id"] == 2:
			sent_to_2 = true
		if pl["type"] == "peer_equipment" and pl["peer_id"] == 2 and m["peer_id"] == 3:
			sent_to_3 = true
	assert_true(sent_to_2, "a peer walking into AOI after the last change is sent to the viewer")
	assert_true(sent_to_3, "and receives the viewer's set")

	# Leave: peer 3 walks away; both viewers are told to evict, once.
	n.memory_transport().outbox.clear()
	n.remember_player_state(3, Vector3(2000, 0, 0))
	n._refresh_equipment_pairs(3)
	var evict_receivers := []   # the peers an evict was delivered to
	for m in n.memory_transport().outbox:
		if m["payload"]["type"] == "peer_equipment_evict":
			evict_receivers.append(m["peer_id"])
	evict_receivers.sort()
	assert_eq(evict_receivers.size(), 2, "leaving AOI evicts the stored set on each viewer")
	assert_eq(evict_receivers, [2, 3], "the evicts go to peer 2 (told peer 3 left) and peer 3 (told peer 2 left)")
	assert_false(n._equipment_sent.has("2:3"), "the sent record for the pair is dropped")
	n.memory_transport().outbox.clear()
	n.remember_player_state(3, Vector3(2100, 0, 0))
	n._refresh_equipment_pairs(3)
	assert_eq(n.memory_transport().outbox.size(), 0, "no repeat eviction while it stays away")
	n.free()
	reg.free()


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

func _test_player_respawn() -> void:
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
