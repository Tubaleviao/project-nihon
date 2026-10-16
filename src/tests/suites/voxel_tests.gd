extends "res://src/tests/test_support.gd"
## Phase 133 — the voxel tests, moved unchanged from the old single-file suite.


func register() -> void:
	_run_test("voxel: a chunk-local build keeps far-from-origin vertices small and exact", _test_voxel_local_build_far_chunk)
	_run_test("chunk: deplete-only edits request no neighbour rebuild", _test_seam_deplete_only)
	_run_test("chunk: a border height edit rebuilds only that neighbour", _test_seam_east_border_edit)
	_run_test("chunk: late edits rebuild the neighbour across the border", _test_seam_late_edits)
	_run_test("chunk: edits synced while unloaded still rebuild neighbours on stream-in", _test_seam_unloaded_then_streamed)
	_run_test("chunk: removing a corner edit rebuilds the diagonal neighbour", _test_seam_corner_removal)
	_run_test("voxel: a legacy op migrates against the materials stack", _test_legacy_op_materials_stack)
	_run_test("voxel: a partial chunk with a stored legacy height loads whole", _test_partial_chunk_legacy_op)
	_run_test("voxel: an unreadable legacy op is dropped and a plain tile round-trips", _test_legacy_op_unreadable_dropped)
	_run_test("voxel: corner blends are symmetric, deep ocean keeps vein depth", _test_phase122_blend_and_bedrock)
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
	_run_test("chunk: desired set within view distance",        _test_chunk_desired_set)
	_run_test("chunk: world/chunk coordinate round-trip",       _test_chunk_coordinate_round_trip)
	_run_test("chunk: per-chunk biome is stable",               _test_chunk_biome_stable)
	_run_test("voxel: topsoil yields the biome's fabric soil", _test_mine_topsoil_yields_biome_soil)
	_run_test("chunk: load/unload emits signals",               _test_chunk_load_unload_signals)
	_run_test("chunk: refresh queues nearest-first",            _test_chunk_refresh_queues_nearest_first)
	_run_test("chunk: load queue respects per-frame budget",    _test_chunk_load_queue_respects_budget)
	_run_test("chunk: voxel edits isolated per chunk",          _test_chunk_voxel_edits_isolated)
	_run_test("chunk: unload preserves edits on reload",        _test_chunk_unload_preserves_edits)
	_run_test("chunk: creature spawn scales per chunk",         _test_chunk_creature_spawn_per_chunk)
	_run_test("chunk: tree spawn scales per chunk",             _test_chunk_tree_spawn_per_chunk)
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
	# Phase 42 second review pass — the streaming-loop holes the first pass left.
	_run_test("chunk: a rebuild respects the in-flight cap",     _test_chunk_rebuild_respects_inflight_cap)
	_run_test("chunk: a queued chunk that leaves range cancels",  _test_chunk_queued_leaving_range_is_cancelled)
	_run_test("chunk: a groundless chunk is re-armed",           _test_chunk_failed_chunk_is_rearmed)
	_run_test("chunk: contents spawn once the ground exists",    _test_chunk_contents_spawn_after_ground)
	_run_test("chunk: the build split is measured",              _test_chunk_build_split_probe)
	_run_test("chunk: the build split holds under a 5x slower clock", _test_chunk_build_split_slow_clock)
	# Phase 42 third review pass — the streaming loop's own bookkeeping, and the CI boot gate.
	_run_test("chunk: a stationary player re-arms a failed chunk", _test_chunk_failed_chunk_is_rearmed_while_stationary)
	_run_test("chunk: unloading drops a queued rebuild",         _test_chunk_unload_drops_queued_rebuild)
	_run_test("chunk: an edit does not re-spawn contents",       _test_chunk_contents_spawn_once_per_residency)
	_run_test("chunk: a drain reads the window once",            _test_chunk_drain_reads_window_once)
	# Phase 42 fourth review pass — the self-heal sweep, the idle drain, and the rig path.
	_run_test("chunk: a failed REBUILD of a built chunk heals",  _test_chunk_failed_rebuild_of_built_chunk_is_rearmed)
	_run_test("chunk: the stationary throttle suppresses a re-arm", _test_chunk_self_heal_throttle_suppresses_rearm)
	_run_test("chunk: a crossing stamps the self-heal clock",    _test_chunk_crossing_stamps_self_heal_clock)
	_run_test("chunk: the self-heal reads the window once",      _test_chunk_self_heal_reads_window_once)
	_run_test("chunk: an idle drain reads no position",          _test_chunk_idle_drain_reads_no_position)
	_run_test("chunk: a rig dispatch keeps contents per residency", _test_chunk_rig_dispatch_respects_contents_residency)
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
	_run_test("voxel: the build payload shape is required",   _test_voxel_build_payload_shape_required)
	_run_test("chunk: the gathered payload carries the ring", _test_chunk_gather_carries_the_ring)
	_run_test("chunk: each peer has a window and chunks are reference counted", _test_chunk_peer_windows_refcount)
	_run_test("chunk: two peers 100 km apart each have creatures simulated", _test_chunk_far_peers_simulated)
	_run_test("chunk: dirty clear is per key + re-markable",      _test_dirty_keys_clear_and_remark)

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

func _test_phase122_blend_and_bedrock() -> void:
	var extent := float(VoxelSlice.CHUNK_SIZE * VoxelSlice.TILE_SIZE)
	var ts := float(VoxelSlice.TILE_SIZE)
	# Transposed layout: swapping X and Z in both the biome map and the position swaps the answer.
	var a := { "0,0": "Desert", "1,0": "Tundra", "0,1": "VoidRift", "1,1": "Alpine" }
	var b := { "0,0": "Desert", "0,1": "Tundra", "1,0": "VoidRift", "1,1": "Alpine" }
	var worn := 0
	for i in range(VoxelSlice.CHUNK_SIZE):
		for j in range(VoxelSlice.CHUNK_SIZE):
			var xz := Vector2(extent - (float(i) + 0.5) * ts, extent - (float(j) + 0.5) * ts)   # the 0,0 chunk's far corner
			var got := VoxelSlice.blended_biome(xz, a, "Desert")
			var swapped := VoxelSlice.blended_biome(Vector2(xz.y, xz.x), b, "Desert")
			assert_eq(got, swapped, "blend at (%d,%d) is symmetric under X/Z swap" % [i, j])
			if got != "Desert":
				worn += 1
	assert_true(worn > 0, "the corner band is dithered with the neighbours' biomes")
	# A deep-ocean column (the fabric's lowest surface) has the authored vein depth above bedrock.
	var deepest := 0.0
	for key in GameData.MATERIALS:
		var band: Variant = GameData.MATERIALS[key].get("depthBand")
		if band is Dictionary:
			deepest = maxf(deepest, float((band as Dictionary).get("max", 0.0)))
	assert_true(WorldShape.min_height() - deepest > VoxelSlice.BEDROCK_DEPTH, "the deepest vein band (%.0f m) fits above bedrock under the deepest ocean floor" % deepest)

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
		volcanic.append(VoxelSlice.material_for_biome("VolcanicBadlands", Vector2(i, 0)))
	assert_true(volcanic.has("Ashite"), "volcanic yields ashite (dominant rock)")
	assert_false(volcanic.has("Thornwood") or volcanic.has("Duskfiber"), "no wood from the volcanic ground")
	var temperate: Array = []
	for i in range(64):
		temperate.append(VoxelSlice.material_for_biome("TemperateForest", Vector2(i, 0)))
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
		@warning_ignore("integer_division")
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
		@warning_ignore("integer_division")
		v.shown_biome_at(Vector2(0.25 + (i % 10) * VoxelSlice.TILE_SIZE, 0.25 + (i / 10) * VoxelSlice.TILE_SIZE))
	assert_true(v.biome_lookups - base <= 9, "at most 9 lookups for 100 calls (got %d)" % (v.biome_lookups - base))
	v.free()
	ts.free()

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
			if VoxelSlice.material_for_biome("TemperateForest", wc) != "Ferrite" and \
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
			var m := VoxelSlice.material_for_biome("VolcanicBadlands", wc, 0.0625)
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

func _test_voxel_guess_cache_bounded() -> void:
	var terrain := TerrainSlice.new()
	add_child(terrain)
	var v := VoxelSlice.new()
	add_child(v)
	v.terrain_slice = terrain
	for i in VoxelSlice.GUESS_CACHE_MAX + 20:
		var c := Vector2i(i, 100)
		v._generated_heightmap(c, VoxelSlice._chunk_key(c))
	assert_eq(v._guess_heightmaps.size(), VoxelSlice.GUESS_CACHE_MAX, "the guess cache stops at its bound")
	assert_false(v._guess_heightmaps.has("0,100"), "the oldest guess is the one evicted")
	var newest := Vector2i(VoxelSlice.GUESS_CACHE_MAX + 19, 100)
	assert_true(v._guess_heightmaps.has(VoxelSlice._chunk_key(newest)), "the newest guess is kept")
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
	var old_map: Array = v._generated_heightmap(c, VoxelSlice._chunk_key(c))
	terrain.set_world_seed(98765)
	var new_map: Array = v._generated_heightmap(c, VoxelSlice._chunk_key(c))
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
	var key := VoxelSlice._tile_key(tile)
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
			if not VoxelSlice._live_vein_at(p, VoxelSlice._run_depth(top_span, base), v._world_seed(), v._vein_taken, {}).is_empty():
				continue
			checked[biome] = true
			var soil := str(b.get("soilMaterial"))
			assert_eq(str(v._natural_yield(t, top_span)["material"]), soil,
				"%s topsoil yields its fabric soilMaterial (%s)" % [biome, soil])
			# One unit below the topsoil, the same column is the host rock (when no vein sits there).
			var depth := float(b.get("topsoilDepth"))
			var deep_span := { "bottom": base - depth - 1.5, "top": base - depth - 1.0 }
			if VoxelSlice._live_vein_at(p, VoxelSlice._run_depth(deep_span, base), v._world_seed(), v._vein_taken, {}).is_empty():
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
	_chunk_build_split_probe(1)

## Phase 123 (#324): the same probe with every clock read multiplied by 5, the way a slow runner
## stretches every measured span. The assertions are ratios between spans read from the one clock,
## so they hold at any speed; a fixed wall-clock budget would fail here. Phase 133 (#331): uniform
## scaling cancels in every ratio, so the clock also stalls on every 23rd read (a descheduled
## thread hitting one span) — the medians and the floor must absorb it.
func _test_chunk_build_split_slow_clock() -> void:
	_chunk_build_split_probe(5, 23)

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
	for run_entry in edited["runs"][ring_key]:
		if str((run_entry as Dictionary)["material"]) == "Ashite":
			placed = true
	assert_true(placed, "and a RING tile's edit reaches the worker-side resolve")
	voxel._set_edit_ops(ring_key, [])
	rig["cm"].free()
	rig["voxel"].free()
	rig["terrain"].free()
	rig["player"].free()

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
