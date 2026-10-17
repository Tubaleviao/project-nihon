extends "res://src/tests/test_support.gd"
## Phase 133 — the persistence tests, moved unchanged from the old single-file suite.


func register() -> void:
	_run_test("regions: an async read runs off the main thread and a chunk waits for it", _test_region_async_read_off_main)
	_run_test("persistence: position saved as chunk + local, old saves migrate", _test_registry_world_pos)
	_run_test("persistence: save then load round-trip",       _test_persistence_round_trip)
	_run_test("persistence: worldgen stamp on a new world",   _test_worldgen_stamp_new_world)
	_run_test("persistence: worldgen mismatch warns once and keeps the stamp", _test_worldgen_stamp_mismatch)
	_run_test("records: lifecycle, flush backoff, exit",      _test_p114_record_lifecycle)
	_run_test("records: deferred while a region is down",     _test_p114_deferred_and_adopted)
	_run_test("records: newer version survives a rewrite",    _test_p114_newer_version_kept)
	_run_test("records: tree-only update keeps the revision", _test_p114_tree_only_revision)
	_run_test("records: client prunes to gen_scope",          _test_p114_prune_scope)
	_run_test("records: cap counts valid; join stamp",        _test_p114_cap_and_join_stamp)
	_run_test("records: streamer margin only when unrecorded", _test_p114_streamer_margin)
	_run_test("records: no records leaves 64 chunks as before",  _test_records_none_unchanged)
	_run_test("records: a record overrides biome and corner heights", _test_records_override)
	_run_test("records: a streamed chunk is recorded exactly once", _test_records_written_once)
	_run_test("records: ring and client write none",              _test_records_ring_and_client)
	_run_test("records: ore field reads the recorded biome on a worker", _test_records_ore_worker)
	_run_test("records: an older record version changes nothing", _test_records_old_version)
	_run_test("record sync: a snapshot carries the window's records only", _test_record_sync_scope)
	_run_test("record sync: bad records are dropped, the rest apply", _test_record_sync_validation)
	_run_test("record sync: a packet over the cap refuses the rest", _test_record_sync_cap)
	_run_test("tree pin: building on a tree's tile clears it for good", _test_tree_pin_edit_clears)
	_run_test("tree pin: a station clears the trees inside its radius only", _test_tree_pin_station_radius)
	_run_test("tree pin: a recorded chunk keeps its tree budget", _test_tree_pin_budget_kept)
	_run_test("tree pin: a client frees a cleared tree", _test_tree_pin_client_cleared)
	_run_test("tree pin: a chopped stump still regrows", _test_tree_pin_stump_regrows)
	_run_test("tree pin: x and t are validated and round-trip", _test_tree_pin_record_validation)
	_run_test("tree pin: a tree on edited ground is cleared at first spawn", _test_tree_pin_edited_ground)
	_run_test("tree clears: a late chunk spawns without its cleared tree", _test_p116_late_chunk)
	_run_test("tree clears: the world seam and edit depth", _test_p116_seam_and_depth)
	_run_test("tree clears: a station clears an unloaded neighbour", _test_p116_station_unloaded)
	_run_test("tree clears: _cleared_local is range-checked, capped and evicted", _test_p116_cleared_local)
	_run_test("tree clears: the host keeps every clear and a save/load restores them", _test_p126_host_keeps_clears)
	_run_test("tree clears: a client's cap evicts the least recently used chunk", _test_p126_client_cap_lru)
	_run_test("tree clears: an unloaded chunk beside recorded land pins the frontier record", _test_p126_frontier_clear)
	_run_test("tree clears: a client keeps an unrecorded clear, range follows the scope", _test_p126_client_scope_and_ghost)
	_run_test("tree clears: an unpinnable host clear survives a save/restart", _test_p138_unpinned_clear_restart)
	_run_test("tree clears: no frontier record is pinned for a circle that hits no tree", _test_p138_no_pin_without_hit)
	_run_test("region store: a save with no chunks ends failure streaks", _test_p138_idle_save_ends_streaks)
	_run_test("save txn: a live foreign journal keeps the .bak and defers the commit", _test_p138_txn_foreign_journal)
	_run_test("tree clears: scope clamp, running total, a client never writes the host's record", _test_p138_scope_total_client)
	_run_test("tree clears: a deep edit and clear_trees_near_tile agree", _test_p126_deep_edit_agrees)
	_run_test("tree clears: a far edit clears the resolved tile", _test_p126_far_edit_tile)
	_run_test("region store: normalize_gen drops only the bad t/x entries", _test_p126_normalize_gen_drops_bad_entries)
	_run_test("p127: records, snapshots, folds and revisions", _test_p127_records)
	_run_test("p127: frontier diagonal has no step", _test_p127_frontier_diagonal)
	_run_test("p127: final flush, compact length, one decode, emulator copy", _test_p127_flush_final_and_compact)
	_run_test("p127: streamer backoff, commit and escalation", _test_p127_streamer_and_txn)
	_run_test("p127: audit of removed names and ranges", _test_p127_audit)
	_run_test("tree clears: a tree-only record keeps the ground revision", _test_p116_record_revision)
	_run_test("persistence: missing slot emits load_failed",  _test_persistence_missing_slot)
	_run_test("region: a failed save re-marks only failed chunks", _test_region_failed_keys_and_remark)
	_run_test("region: a depletion in an evicted chunk keeps its other edits", _test_region_depletion_merges_evicted)
	_run_test("region: a malformed entry warns once per store", _test_region_malformed_warns_once)
	_run_test("region: a legacy tile height survives a depletion overlay", _test_region_overlay_legacy_height)
	_run_test("region: one legacy-height parser refuses non-finite and unreadable values", _test_legacy_height_parser)
	_run_test("region: a malformed entry survives a neighbour's save", _test_region_malformed_entry_kept)
	_run_test("region: a valid entry replaces a malformed one", _test_region_malformed_entry_replaced)
	_run_test("region: a gen record round-trips", _test_region_gen_round_trip)
	_run_test("region: a version-1 file loads and saves as version 2", _test_region_v1_upgrade)
	_run_test("region: a malformed gen is dropped, edits survive, one warning", _test_region_gen_malformed)
	_run_test("region: 1,024 recorded chunks stay small", _test_region_gen_size)
	_run_test("region: a partial chunk loads its stored edits when the region streams in", _test_region_partial_chunk_loads_stored)
	_run_test("region: an overlay keeps the larger stored depletion count", _test_region_overlay_keeps_larger_taken)
	_run_test("region: migration recovers a monolith chunk whose region entry is malformed", _test_region_migrate_malformed_recovers)
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
	_run_test("persistence: a fresh player's first-boot spawn is recorded exactly", _test_first_boot_spawn_exact)
	_run_test("region: a vein depleted from an evicted chunk stays depleted in its neighbours", _test_region_evict_keeps_vein_depletion)
	_run_test("region: one unwritable region does not stop the rest of the save", _test_region_failed_write_saves_the_rest)
	_run_test("region: a region whose read fails is not resident and is retried", _test_region_failed_read_not_resident)
	_run_test("region: a failed read backs off",                    _test_region_failed_read_backs_off)
	_run_test("region: op lists with non-dictionary ops are dropped", _test_region_entry_rejects_bad_ops)
	_run_test("region: a chunk entry with edits or materials of the wrong type is skipped with one warning", _test_region_malformed_entry_skipped)
	_run_test("region: 1,000 regions on disk, only the ones near a window are resident", _test_region_streams_only_near_windows)
	_run_test("persistence: shutdown poll is independent of autosave", _test_shutdown_poll_cadence)
	_run_test("persistence: failed write reports + keeps record",  _test_failed_write_reports_and_preserves)
	_run_test("p121: a fault at each write step leaves one world", _test_p121_fault_at_each_step)
	_run_test("p121: a region that cannot stage changes nothing",  _test_p121_region_stage_fault)
	_run_test("p121: crash recovery and stray tmp files",          _test_p121_crash_recovery_and_stray_tmp)
	_run_test("p121: one failing region of three",                 _test_p121_one_failing_region_of_three)
	_run_test("p121: a malformed op is dropped alone",             _test_p121_malformed_op_dropped_alone)
	_run_test("p121: streamer scans once and retries stranded",    _test_p121_streamer_scan_and_retry)
	_run_test("p121: world stamp through save job and load",       _test_p121_world_stamp_round_trip)

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

func _test_persistence_round_trip() -> void:
	var p := PersistenceSlice.new()
	add_child(p)
	var captured := {}
	GameBus.load_completed.connect(func(_slot, slot_data): captured["data"] = slot_data)
	var data := { "player": "TestPlayer", "level": 42 }
	p.save(99, data)
	p.load_slot(99)
	var loaded: Dictionary = captured.get("data", {})
	assert_eq(loaded.get("player", ""), "TestPlayer", "player name round-trips")
	assert_eq(loaded.get("level", 0),   42,           "level round-trips")
	p.free()

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
	for original in [TerrainSlice.WORLDGEN_VERSION - 1]:
		var record := { "local_player_id": "player_1_1_ab", "chunks": voxel.get_chunk_manifest() }
		record["worldgenVersion"] = original
		assert_eq(writer.save_world(record, false), OK, "the old record writes")
		var loaded := writer.load_world_record()
		assert_eq(PersistenceSlice.worldgen_version_of(loaded), original, "an old stamp reads as itself")
		var warns := Diag.warn_count()
		assert_true(PersistenceSlice.check_worldgen_version(loaded, TerrainSlice.WORLDGEN_VERSION), "the mismatch is reported")
		assert_eq(Diag.warn_count() - warns, 1, "with exactly one warning")
		var stamp := PersistenceSlice.worldgen_stamp_for_save(loaded, TerrainSlice.WORLDGEN_VERSION)
		assert_eq(stamp, original, "a re-save keeps the original stamp")
		assert_eq(writer.save_world({ "local_player_id": "player_1_1_ab", "worldgenVersion": stamp }, true), OK, "the re-save writes")
		assert_eq(PersistenceSlice.worldgen_version_of(writer.load_world_record()), original, "and the stamp on disk is unchanged")
		assert_true((writer.load_world()["chunks"] as Dictionary).has("0,0"), "every edit is intact")
	# Phase 117: a pre-stamp record has no version: it is neither version 0 nor a mismatch.
	assert_eq(PersistenceSlice.worldgen_version_of({ "seed": 1 }), -1, "a pre-stamp record has no version")
	var quiet := Diag.warn_count()
	assert_false(PersistenceSlice.check_worldgen_version({ "seed": 1 }, TerrainSlice.WORLDGEN_VERSION), "a pre-stamp record is no mismatch")
	assert_eq(Diag.warn_count(), quiet, "and does not warn")
	assert_eq(PersistenceSlice.worldgen_stamp_for_save({ "seed": 1 }, TerrainSlice.WORLDGEN_VERSION), TerrainSlice.WORLDGEN_VERSION, "its next save takes the running stamp")
	voxel.free()
	writer.free()
	_wipe_dir(dir)

## ChunkRecords is empty after a world reload and after the manager leaves the tree; pending records
## reach the disk first; a failing region is written at most once per backoff interval.
func _test_p114_record_lifecycle() -> void:
	var rig := _records_rig("test_p114_life")
	var cm: ChunkManager = rig["cm"]
	var store: RegionStoreScript = rig["store"]
	cm.load_chunk(Vector2i(10, 10))
	assert_eq(cm.pending_record_count(), 1, "a record is pending")
	add_child(cm)
	remove_child(cm)
	cm.free()
	assert_false(ChunkRecordsScript.is_empty(), "freeing a manager leaves the shared table to GameRoot")
	assert_false(store.get_gen(Vector2i(10, 10)).is_empty(), "and the pending record reached the disk")
	# Backoff: region (0,0) is unreadable, so every flush of a chunk in it fails.
	var rig2 := _records_rig("test_p114_backoff")
	var cm2: ChunkManager = rig2["cm"]
	var store2: RegionStoreScript = rig2["store"]
	_p114_corrupt_region(store2, Vector2i.ZERO)
	var clock := [0]
	cm2.set_clock(func() -> int: return clock[0])
	cm2.load_chunk(Vector2i(2, 2))
	cm2.flush_records()
	assert_false(store2.last_failed_chunk_keys.is_empty(), "the first flush tries and fails")
	assert_eq(cm2.pending_record_count(), 1, "the record stays pending")
	store2.last_failed_chunk_keys = []
	for i in 5:
		cm2.flush_records()
	assert_true(store2.last_failed_chunk_keys.is_empty(), "five more flushes inside the interval touch nothing")
	clock[0] += ChunkManager.FLUSH_BACKOFF_START_MSEC * 2
	cm2.flush_records()
	assert_false(store2.last_failed_chunk_keys.is_empty(), "one retry once the interval elapsed")
	store2.save_region(Vector2i.ZERO, {})
	store2.last_failed_chunk_keys = []
	clock[0] += ChunkManager.FLUSH_BACKOFF_MAX_MSEC * 2
	cm2.flush_records()
	assert_eq(cm2.pending_record_count(), 0, "a repaired region takes the record")
	cm2.free()
	(rig["t"] as Node).free()
	(rig2["t"] as Node).free()
	ChunkRecordsScript.clear()
	# A world (re)load clears the table.
	ChunkRecordsScript.set_record(Vector2i(1, 1), _sync_record(Vector2i(1, 1)))
	var gr: Node = load("res://src/core/game_root.gd").new()
	gr._persistence_wiring._forget_world_records()
	assert_true(ChunkRecordsScript.is_empty(), "a world load empties the table")
	assert_true(FileAccess.get_file_as_string("res://src/persistence/persistence_wiring.gd").contains("_persistence.load_world_record()\n\t_forget_world_records()"), "and _load_world_records calls it right after reading the record")
	gr.free()

## A chunk is not recorded while a region within BLEND_CHUNKS failed; it is recorded and rebuilt once
## the region reads; a region read after the chunk was built rebuilds it on the adopted record.
func _test_p114_deferred_and_adopted() -> void:
	var rig := _records_rig("test_p114_defer")
	var cm: ChunkManager = rig["cm"]
	var store: RegionStoreScript = rig["store"]
	var voxel := _make_voxel()
	var streamer := RegionStreamerScript114.new(store, voxel)
	var clock := [0]
	streamer._now = func() -> int: return clock[0]
	cm.region_streamer = streamer
	_p114_corrupt_region(store, Vector2i.ZERO)
	var c := Vector2i(2, 2)
	var want := RegionStreamerScript114.regions_for_chunks([c], Frontier.BLEND_CHUNKS)
	var first := streamer.sync(want)
	assert_eq(int(first["failed"]), 1, "region (0,0) failed")
	cm.load_chunk(c)
	assert_eq(cm.records_created, 0, "no record while a neighbouring region is down")
	assert_eq(cm.deferred_record_count(), 1, "the chunk is remembered")
	assert_false(ChunkRecordsScript.has_record(c), "and nothing is in the table")
	store.save_region(Vector2i.ZERO, {})
	clock[0] += RegionStreamerScript114.BACKOFF_START_MSEC * 2
	cm.track_rebuilds()
	var rebuilds := cm.rebuild_request_count(c)
	# A stationary host (no window move) retries on its own: refresh() re-syncs and records the chunk.
	cm._chunk_refs = { cm._chunk_key(c): 1 }
	cm.now_msec = func() -> int: return clock[0]
	cm._retry_deferred_records()
	assert_eq(cm.records_created, 1, "recorded once every region is resident")
	assert_eq(cm.deferred_record_count(), 0, "and forgotten")
	assert_eq(cm.rebuild_request_count(c), rebuilds + 1, "the built chunk is rebuilt on its record")
	# Late adoption: a record appears in a region read after the chunk was built.
	var d := Vector2i(40, 40)
	ChunkRecordsScript.clear()
	var other := RegionStoreScript.new(_fresh_region_dir("test_p114_late") + "regions/")
	var late_streamer := RegionStreamerScript114.new(other, voxel)
	var rec := RegionStoreScript.normalize_gen(TerrainSlice.generation_record(d, 31))
	other.write_chunks({ "40,40": { "gen": rec } })
	cm.record_store = null   # a client-like manager: it only loads
	cm.load_chunk(d)
	cm.track_rebuilds()
	var before := cm.rebuild_request_count(d)
	var synced := late_streamer.sync(RegionStreamerScript114.regions_for_chunks([d], 1))
	cm._rebuild_adopted(synced["adopted"])
	assert_true(ChunkRecordsScript.has_record(d), "the record was adopted")
	assert_eq(cm.rebuild_request_count(d), before + 1, "and the built chunk rebuilt once")
	voxel.free()
	cm.free()
	(rig["t"] as Node).free()
	ChunkRecordsScript.clear()

## A record written by a newer generator rides through a rewrite and is never adopted.
func _test_p114_newer_version_kept() -> void:
	var dir := _fresh_region_dir("test_p114_newer")
	var store: RegionStoreScript = RegionStoreScript.new(dir + "regions/")
	var future := { "v": TerrainSlice.WORLDGEN_VERSION + 5, "f": 3, "b": "Desert", "h": [1.0, 2.0, 3.0, 4.0] }
	assert_true(RegionStoreScript.is_newer_gen(future), "a newer v is recognised")
	assert_true(RegionStoreScript.normalize_gen(future).is_empty(), "but not trusted")
	assert_eq(store.save_region(Vector2i.ZERO, { "2,2": { "gen": future } }), OK, "the file is written")
	var good := RegionStoreScript.normalize_gen(TerrainSlice.generation_record(Vector2i(3, 3), 31))
	assert_eq(store.write_chunks({ "3,3": { "gen": good } }), OK, "another chunk's record is written")
	var read := store.read_region(Vector2i.ZERO)
	assert_eq((read["chunks"]["2,2"]["gen"] as Dictionary)["v"], future["v"], "the newer record survived the rewrite verbatim")
	assert_false(store.get_gen(Vector2i(3, 3)).is_empty(), "and the new one is there")
	ChunkRecordsScript.clear()
	var voxel := _make_voxel()
	var streamer := RegionStreamerScript114.new(store, voxel)
	streamer.sync({ "0,0": true })
	assert_false(ChunkRecordsScript.has_record(Vector2i(2, 2)), "the streamer does not adopt it")
	assert_true(ChunkRecordsScript.has_record(Vector2i(3, 3)), "but adopts the readable one")
	# A gen-only write over the newer record (a build that cannot see it records the chunk anew) loses.
	var mine := RegionStoreScript.normalize_gen(TerrainSlice.generation_record(Vector2i(2, 2), 31))
	assert_eq(store.write_chunks({ "2,2": { "gen": mine } }), OK, "a rewrite of the chunk is accepted")
	assert_eq(int((store.read_region(Vector2i.ZERO)["chunks"]["2,2"]["gen"] as Dictionary)["v"]), int(future["v"]),
		"but a newer generator's record is not replaced")
	var folded := RegionStoreScript.fold_chunks({ "2,2": { "gen": future } }, { "2,2": { "edits": { "1,1": [] }, "gen": mine } }, false)
	assert_eq(int((folded["2,2"]["gen"] as Dictionary)["v"]), int(future["v"]), "an entry with edits and an older record keeps the newer record")
	assert_true((folded["2,2"] as Dictionary).has("edits"), "and its edits")
	voxel.free()
	ChunkRecordsScript.clear()

## A tree-only update changes the content revision and leaves the ground revision alone.
func _test_p114_tree_only_revision() -> void:
	ChunkRecordsScript.clear()
	var c := Vector2i(7, 7)
	var rec := RegionStoreScript.normalize_gen(_sync_record(c))
	ChunkRecordsScript.set_record(c, rec)
	var ground := ChunkRecordsScript.revision()
	var content := ChunkRecordsScript.content_revision()
	var with_trees: Dictionary = rec.duplicate(true)
	with_trees["t"] = 4
	assert_true(ChunkRecordsScript.set_record(c, with_trees), "the tree budget is a change")
	assert_eq(ChunkRecordsScript.revision(), ground, "but the ground revision stays")
	assert_eq(ChunkRecordsScript.content_revision(), content + 1, "while the content revision moves")
	var moved: Dictionary = with_trees.duplicate(true)
	moved["h"] = [5.0, 5.0, 5.0, 5.0]
	ChunkRecordsScript.set_record(c, moved)
	assert_eq(ChunkRecordsScript.revision(), ground + 1, "a height change moves the ground revision")
	ChunkRecordsScript.clear()
	ChunkRecordsScript.set_record(c, rec)
	var tree_only := ChunkRecordSyncScript.apply({ ChunkRecordsScript.key_of(c): with_trees })
	assert_eq((tree_only["changed"] as Array).size(), 0, "a tree-only record from the host is not a ground change")
	var ground_change := ChunkRecordSyncScript.apply({ ChunkRecordsScript.key_of(c): moved })
	assert_eq((ground_change["changed"] as Array).size(), 1, "a ground change is reported")
	ChunkRecordsScript.clear()

## The client prunes its table to the host's scope, the short way round the seam.
func _test_p114_prune_scope() -> void:
	ChunkRecordsScript.clear()
	var circ := TerrainSlice.circumference_chunks()
	for c in [Vector2i(0, 0), Vector2i(3, 2), Vector2i(50, 0), Vector2i(circ - 1, 0), Vector2i(0, -40)]:
		ChunkRecordsScript.set_record(c, _sync_record(c))
	assert_eq(ChunkRecordSyncScript.prune_to_scope("junk"), 0, "a malformed scope prunes nothing")
	assert_eq(ChunkRecordSyncScript.prune_to_scope([0, 0]), 0, "a short scope prunes nothing")
	assert_eq(ChunkRecordSyncScript.prune_to_scope([0.0, 0.0, 5.0]), 2, "the two far records go")
	assert_eq(ChunkRecordsScript.size(), 3, "three remain")
	assert_true(ChunkRecordsScript.has_record(Vector2i(circ - 1, 0)), "the one across the seam stays")
	assert_eq(ChunkRecordSyncScript.prune_to_scope([1000, 1000, 5]), 3, "a re-scope elsewhere empties it")
	assert_true(ChunkRecordsScript.is_empty(), "the table is empty")

## Malformed entries do not use up the cap; a join snapshot without records does not stamp the peer.
func _test_p114_cap_and_join_stamp() -> void:
	ChunkRecordsScript.clear()
	var payload := {}
	for i in 5:
		payload["bad%d" % i] = "junk"
	for i in 3:
		payload["%d,0" % i] = _sync_record(Vector2i(i, 0))
	var res := ChunkRecordSyncScript.apply(payload, 3)
	assert_eq(res["applied"], 3, "all three valid records apply under a cap of 3")
	assert_eq(res["dropped"], 5, "the five malformed are dropped")
	assert_eq(res["refused"], 0, "nothing valid refused")
	assert_eq((res["changed"] as Array).size(), 3, "and reported as changed")
	ChunkRecordsScript.clear()
	var gr: Node = load("res://src/core/game_root.gd").new()
	var cm := ChunkManager.new()
	gr._chunk_manager = cm
	var snap := {}
	gr._snapshot_wiring._add_generation_records(snap, 9, Vector3.ZERO)
	assert_true(gr._peer_records_msec.has(9), "a snapshot without records still stamps the re-scope delay (window-rate-limited)")
	assert_true(snap.has("gen_scope") and not snap.has("gen_records"), "but names its scope")
	ChunkRecordsScript.set_record(Vector2i(0, 0), _sync_record(Vector2i(0, 0)))
	var snap2 := {}
	gr._snapshot_wiring._add_generation_records(snap2, 9, Vector3.ZERO)
	assert_true(gr._peer_records_msec.has(9) and snap2.has("gen_records"), "records sent: stamped")
	cm.free()
	gr.free()
	ChunkRecordsScript.clear()

## An already-recorded chunk asks for no region beyond its own one-chunk margin.
func _test_p114_streamer_margin() -> void:
	ChunkRecordsScript.clear()
	var c := Vector2i(29, 5)   # 3 chunks from the next region: the blend margin crosses, the 1-chunk one does not
	var open := RegionStreamerScript114.regions_for_chunks([c], Frontier.BLEND_CHUNKS)
	assert_true(open.has("1,0"), "an unrecorded chunk reads the next region for its blend")
	ChunkRecordsScript.set_record(c, _sync_record(c))
	var closed := RegionStreamerScript114.regions_for_chunks([c], Frontier.BLEND_CHUNKS)
	assert_eq(closed.keys(), ["0,0"], "a recorded chunk loads no extra region")
	assert_eq(RegionStreamerScript114.regions_for_chunks([c], Frontier.BLEND_CHUNKS, Frontier.BLEND_CHUNKS).size(), open.size(), "unless the caller asks for the full margin")
	ChunkRecordsScript.clear()

# ---------------------------------------------------------------------------
# Phase 121 — crash-consistent saves
# ---------------------------------------------------------------------------

func _test_records_none_unchanged() -> void:
	ChunkRecordsScript.clear()
	var t := TerrainSlice.new()
	add_child(t)
	t.set_world_seed(4242)
	var chunks := _records_chunks64()
	var first := _records_hash(t, chunks)
	assert_eq(first, RECORDS_GOLDEN_HASH, "heightmap hash of 64 chunks is the pre-phase value (got %d)" % first)
	var biomes := ""
	for c in chunks:
		biomes += TerrainSlice.biome_for_chunk(c, 4242).substr(0, 2)
	assert_eq(biomes.hash(), RECORDS_GOLDEN_BIOMES, "biomes of 64 chunks are the pre-phase values (got %d)" % biomes.hash())
	# A record equal to the generator's own (rounded to 1e-4) moves no height by more than that.
	var plain: Array = []
	for c in chunks:
		plain.append(t.generate_heightmap(c))
	for c in chunks:
		ChunkRecordsScript.set_record(c, RegionStoreScript.normalize_gen(TerrainSlice.generation_record(c, 4242)))
	var worst := 0.0
	for i in chunks.size():
		var hm: Array = t.generate_heightmap(chunks[i])
		for j in range(0, hm.size(), 11):
			worst = maxf(worst, absf(float(hm[j]) - float(plain[i][j])))
	assert_true(worst <= 1.5e-4, "self-recorded chunks generate the same ground to 1e-4 (worst %.6f)" % worst)
	ChunkRecordsScript.clear()
	t.free()

func _test_records_override() -> void:
	ChunkRecordsScript.clear()
	var t := TerrainSlice.new()
	add_child(t)
	t.set_world_seed(99)
	var c := Vector2i(300, 120)
	var nb := Vector2i(301, 120)
	var before: Array = t.generate_heightmap(c)
	var nb_before: Array = t.generate_heightmap(nb)
	var gen_biome := TerrainSlice.biome_for_chunk(c, 99)
	var other: String = "Desert" if gen_biome != "Desert" else "Tundra"
	var rec := TerrainSlice.generation_record(c, 99)
	var shifted: Array = []
	for hh in rec["h"]:
		shifted.append(minf(float(hh) + 3.0, WorldShapeScript.max_height() - 1.0))
	rec["h"] = shifted
	rec["b"] = other
	rec = RegionStoreScript.normalize_gen(rec)
	assert_false(rec.is_empty(), "the stub record is valid")
	ChunkRecordsScript.set_record(c, rec)
	assert_eq(TerrainSlice.biome_for_chunk(c, 99), other, "the recorded biome wins")
	assert_eq(t.get_biome_at_chunk(c), other, "and the instance form agrees")
	assert_eq(TerrainSlice.biome_for_chunk(nb, 99), TerrainSlice.generated_biome_for_chunk(nb, 99), "a neighbour keeps the generator's biome")
	var after: Array = t.generate_heightmap(c)
	var moved := 0
	for i in after.size():
		if absf(float(after[i]) - float(before[i])) > 0.5:
			moved += 1
	@warning_ignore("integer_division")
	assert_true(moved > after.size() / 2, "the recorded corners move the chunk's ground (%d tiles)" % moved)
	assert_true(t.generate_heightmap(nb) == nb_before, "the neighbour's heightmap is the generator's")
	assert_true(not is_equal_approx(TerrainSlice.shape_height(99, 300.5 * 32.0, 120.5 * 32.0, 4.0e7),
		WorldShapeScript.height(99, 300.5 * 32.0, 120.5 * 32.0, 4.0e7)), "the ring's shape read follows the record")
	ChunkRecordsScript.erase_record(c)
	assert_true(t.generate_heightmap(c) == before, "dropping the record restores the generator's ground")
	ChunkRecordsScript.clear()
	t.free()

func _test_records_written_once() -> void:
	var rig := _records_rig("test_p108_once")
	var cm: ChunkManager = rig["cm"]
	var store: RegionStoreScript = rig["store"]
	var cs := [Vector2i(10, 10), Vector2i(11, 10), Vector2i(40, -3)]
	for c in cs:
		cm.load_chunk(c)
	assert_eq(cm.records_created, 3, "each chunk got one record")
	assert_eq(cm.pending_record_count(), 3, "pending until flushed")
	cm.flush_records()
	assert_eq(cm.pending_record_count(), 0, "flushed")
	for c in cs:
		assert_false(store.get_gen(c).is_empty(), "record of %s is on disk" % str(c))
		assert_eq(store.get_gen(c)["b"], TerrainSlice.generated_biome_for_chunk(c, 31), "recorded biome is the generator's")
	for c in cs:
		cm.unload_chunk(c)
		cm.load_chunk(c)
	assert_eq(cm.records_created, 3, "a second load creates nothing")
	assert_eq(cm.pending_record_count(), 0, "and rewrites nothing")
	cm.records_flush_blocked = func() -> bool: return true
	cm.load_chunk(Vector2i(12, 10))
	cm.flush_records()
	assert_eq(cm.pending_record_count(), 1, "a flush waits while a save runs")
	cm.records_flush_blocked = Callable()
	cm.flush_records()
	assert_false(store.get_gen(Vector2i(12, 10)).is_empty(), "then lands")
	# A fresh process: the region's records are adopted, so the chunk is not recorded again.
	ChunkRecordsScript.clear()
	var read := store.read_region(Vector2i.ZERO)
	assert_true(ChunkRecordsScript.adopt_region(read["chunks"]) >= 3, "the region read adopts its records")
	var created := cm.records_created
	cm.unload_chunk(Vector2i(10, 10))
	cm.load_chunk(Vector2i(10, 10))
	assert_eq(cm.records_created, created, "an adopted record is not rewritten")
	cm.free()
	(rig["t"] as Node).free()
	ChunkRecordsScript.clear()

func _test_records_ring_and_client() -> void:
	var rig := _records_rig("test_p108_client", false)
	var cm: ChunkManager = rig["cm"]
	for c in [Vector2i(5, 5), Vector2i(6, 5)]:
		cm.load_chunk(c)
	assert_eq(cm.records_created, 0, "a client-role manager creates no record")
	assert_eq(ChunkRecordsScript.size(), 0, "and the table stays empty")
	cm.free()
	var d := DistantTerrainScript.new()
	add_child(d)
	d.world_seed = 31
	d.rebuild(Vector2(16.0, 16.0), 3)
	d.poll(true)
	assert_eq(ChunkRecordsScript.size(), 0, "building a ring writes no record")
	d.free()
	(rig["t"] as Node).free()

func _test_records_ore_worker() -> void:
	ChunkRecordsScript.clear()
	var c := Vector2i(77, 31)
	var gen_biome := TerrainSlice.biome_for_chunk(c, 5)
	var other: String = "Desert" if gen_biome != "Desert" else "Tundra"
	var rec := TerrainSlice.generation_record(c, 5)
	rec["b"] = other
	ChunkRecordsScript.set_record(c, RegionStoreScript.normalize_gen(rec))
	var result: Array = [""]
	var tid := WorkerThreadPool.add_task(func(): result[0] = TerrainSlice.biome_for_chunk(c, 5))
	WorkerThreadPool.wait_for_task_completion(tid)
	assert_eq(result[0], other, "a worker asking for a recorded chunk gets the recorded biome")
	# OreField's own read goes through the same call.
	var seen := false
	for dx in range(0, 64, 4):
		for dz in range(0, 64, 4):
			var v := OreField.vein_at(5, c, Vector2i(dx, dz), 0.0)
			if not v.is_empty():
				assert_eq(v["biome"], other, "a vein of the recorded chunk carries the recorded biome")
				seen = true
	if not seen:
		print("    (no surface vein sampled in the recorded chunk; worker read asserted above)")
	ChunkRecordsScript.clear()

func _test_records_old_version() -> void:
	ChunkRecordsScript.clear()
	var t := TerrainSlice.new()
	add_child(t)
	t.set_world_seed(8)
	var c := Vector2i(-210, 44)
	var rec := RegionStoreScript.normalize_gen(TerrainSlice.generation_record(c, 8))
	ChunkRecordsScript.set_record(c, rec)
	var current: Array = t.generate_heightmap(c)
	var cur_biome := TerrainSlice.biome_for_chunk(c, 8)
	var old := rec.duplicate()
	old["v"] = 1
	assert_false(RegionStoreScript.normalize_gen(old).is_empty(), "an older version is a valid record")
	ChunkRecordsScript.set_record(c, RegionStoreScript.normalize_gen(old))
	assert_true(t.generate_heightmap(c) == current, "an older record version leaves the ground unchanged")
	assert_eq(TerrainSlice.biome_for_chunk(c, 8), cur_biome, "and the biome")
	ChunkRecordsScript.clear()
	t.free()

func _test_record_sync_scope() -> void:
	ChunkRecordsScript.clear()
	var near := Vector2i(100, 50)
	var far := Vector2i(100 + 40, 50)
	ChunkRecordsScript.set_record(near, _sync_record(near))
	ChunkRecordsScript.set_record(Vector2i(104, 52), _sync_record(Vector2i(104, 52)))
	ChunkRecordsScript.set_record(far, _sync_record(far))
	var got := ChunkRecordSyncScript.records_in_window(Vector2i(101, 50), 5)
	var recs: Dictionary = got["records"]
	assert_eq(recs.size(), 2, "a peer's window carries the two records inside it")
	assert_true(recs.has("100,50") and recs.has("104,52"), "the in-window chunks are named")
	assert_false(recs.has("140,50"), "a record outside the window stays home")
	var away := ChunkRecordSyncScript.records_in_window(Vector2i(-300, -90), 5)
	assert_true((away["records"] as Dictionary).is_empty(), "a far peer's snapshot carries none of them")
	# The wire form is JSON: heights come back as floats, ids as whole floats.
	var wire: Variant = JSON.parse_string(JSON.stringify(recs))
	ChunkRecordsScript.clear()
	var res := ChunkRecordSyncScript.apply(wire)
	assert_eq(res["applied"], 2, "a JSON round trip applies both records")
	assert_eq(ChunkRecordsScript.get_record(near).get("b", ""), "Desert", "the client holds the host's biome")
	ChunkRecordsScript.clear()

func _test_record_sync_validation() -> void:
	ChunkRecordsScript.clear()
	var good_a := Vector2i(1, 1)
	var good_b := Vector2i(2, 2)
	var payload := {
		"1,1": _sync_record(good_a),
		"3,3": _sync_record(Vector2i(3, 3), "NotABiome"),
		"4,4": _sync_record(Vector2i(4, 4)),
		"5,5": _sync_record(Vector2i(5, 5)),
		"bad": _sync_record(Vector2i(6, 6)),
		"2,2": _sync_record(good_b),
	}
	payload["4,4"]["h"] = [NAN, 1.0, 1.0, 1.0]
	payload["5,5"]["h"] = [1.0, 1.0, 1.0, WorldShapeScript.max_height() + 50.0]
	var res := ChunkRecordSyncScript.apply(payload)
	assert_eq(res["applied"], 2, "the two good records apply")
	assert_eq(res["dropped"], 4, "unknown biome, NaN, over max_height and a bad key are dropped")
	assert_eq(res["refused"], 0, "nothing refused under the cap")
	assert_true(ChunkRecordsScript.has_record(good_a) and ChunkRecordsScript.has_record(good_b), "good ones landed")
	assert_false(ChunkRecordsScript.has_record(Vector2i(3, 3)), "the bad biome did not")
	assert_false(ChunkRecordsScript.has_record(Vector2i(4, 4)), "nor the NaN height")
	assert_false(ChunkRecordsScript.has_record(Vector2i(5, 5)), "nor the tall one")
	assert_eq(ChunkRecordSyncScript.apply("nonsense")["applied"], 0, "a non-dictionary payload applies nothing")
	ChunkRecordsScript.clear()

func _test_record_sync_cap() -> void:
	ChunkRecordsScript.clear()
	var payload := {}
	for i in 10:
		payload["%d,0" % i] = _sync_record(Vector2i(i, 0))
	var res := ChunkRecordSyncScript.apply(payload, 4)
	assert_eq(res["applied"], 4, "the first cap records apply")
	assert_eq(res["refused"], 6, "the rest are counted as refused")
	assert_true(ChunkRecordsScript.has_record(Vector2i(3, 0)) and not ChunkRecordsScript.has_record(Vector2i(4, 0)), "in order")
	# The host side stops at the cap too.
	ChunkRecordsScript.clear()
	for i in 10:
		ChunkRecordsScript.set_record(Vector2i(i, 0), _sync_record(Vector2i(i, 0)))
	var got := ChunkRecordSyncScript.records_in_window(Vector2i(5, 0), 6, 4)
	assert_eq((got["records"] as Dictionary).size(), 4, "a window with more records than the cap sends the cap")
	assert_true(bool(got["truncated"]), "and says it truncated")
	ChunkRecordsScript.clear()


# --- Phase 110 — trees pinned per chunk, cleared where players build -----------------------------

func _test_tree_pin_edit_clears() -> void:
	var chunk := Vector2i(0, 0)
	var t := _tree_pin_rig(chunk)
	t.spawn_for_chunk(chunk)
	assert_eq(t.trees_in_chunk(chunk).size(), 8, "the chunk starts with its 8 trees")
	var victim: Dictionary = t.get_all_trees()[0]
	var cleared: Array = []
	var on_cleared := func(id: String) -> void: cleared.append(id)
	GameBus.tree_cleared.connect(on_cleared)
	var pos: Vector3 = victim["position"]
	GameBus.block_edit_resolved.emit(_edit_tile_of(pos, t), pos.y)
	assert_true(cleared.has(str(victim["tree_id"])), "tree_cleared names the tree on the edited tile")
	assert_true(t.get_tree_record(str(victim["tree_id"])).is_empty(), "the tree is gone")
	assert_true(t.index_is_consistent(), "the tree index stays consistent")
	var left: int = t.trees_in_chunk(chunk).size()
	t.despawn_for_chunk(chunk)
	t.spawn_for_chunk(chunk)
	assert_eq(t.trees_in_chunk(chunk).size(), left, "after unload and reload it stays gone")
	assert_true(t.get_tree_record(str(victim["tree_id"])).is_empty(), "the same tree does not return")
	# Save and load: the record goes through the region store and back.
	var dir := _fresh_region_dir("test_p110_clear")
	var store := RegionStoreScript.new(dir + "regions/")
	var rec := ChunkRecordsScript.get_record(chunk)
	assert_true((rec["x"] as Array).has(int(victim["index"])), "the record lists the cleared index")
	assert_eq(store.write_chunks({ "0,0": { "gen": rec } }), OK, "the record is saved")
	ChunkRecordsScript.clear()
	ChunkRecordsScript.adopt_region(store.read_region(Vector2i.ZERO)["chunks"])
	t.despawn_for_chunk(chunk)
	t.spawn_for_chunk(chunk)
	assert_eq(t.trees_in_chunk(chunk).size(), left, "after save and load it is still gone")
	GameBus.tree_cleared.disconnect(on_cleared)
	t.free()
	ChunkRecordsScript.clear()

func _test_tree_pin_station_radius() -> void:
	var chunk := Vector2i(0, 0)
	var t := _tree_pin_rig(chunk)
	t.spawn_for_chunk(chunk)
	var centre: Vector3 = t.get_all_trees()[0]["position"]
	var inside := 0
	var outside := 0
	var inside_ids: Array = []
	for tree in t.get_all_trees():
		var p: Vector3 = tree["position"]
		if Vector2(p.x - centre.x, p.z - centre.z).length() <= TreeSlice.clear_radius_m():
			inside += 1
			inside_ids.append(str(tree["tree_id"]))
		else:
			outside += 1
	GameBus.station_placed.emit("station_t110", "Workbench", centre)
	assert_eq(t.trees_in_chunk(chunk).size(), outside, "only the trees outside the radius remain")
	assert_true(inside >= 1, "at least the centre tree was inside")
	for tid in inside_ids:
		assert_true(t.get_tree_record(str(tid)).is_empty(), "%s inside the radius is cleared" % tid)
	t.free()
	ChunkRecordsScript.clear()

func _test_tree_pin_budget_kept() -> void:
	var chunk := Vector2i(0, 0)
	var t := _tree_pin_rig(chunk)
	t.spawn_for_chunk(chunk)
	assert_eq(int(ChunkRecordsScript.get_record(chunk).get("t", -1)), 8, "the record stamps the budget it spawned")
	var biome: Variant = GameData.BIOMES.get("TemperateForest", null)
	var original: Variant = biome.get("treeDensity")
	biome.set("treeDensity", 2)
	t.despawn_for_chunk(chunk)
	t.spawn_for_chunk(chunk)
	assert_eq(t.trees_in_chunk(chunk).size(), 8, "a changed treeDensity does not touch a recorded chunk")
	var fresh := Vector2i(5, 5)
	t.spawn_for_chunk(fresh)
	assert_eq(t.trees_in_chunk(fresh).size(), 2, "a chunk with no record follows the new density")
	biome.set("treeDensity", original)
	t.free()
	ChunkRecordsScript.clear()

func _test_tree_pin_client_cleared() -> void:
	var chunk := Vector2i(0, 0)
	var t := _tree_pin_rig(chunk)
	t.is_authoritative = false
	t.spawn_for_chunk(chunk)
	var tid: String = str(t.get_all_trees()[0]["tree_id"])
	var body: Variant = t.get_tree_record(tid)["body"]
	GameBus.tree_cleared.emit("tree_unknown_id")
	assert_eq(t.trees_in_chunk(chunk).size(), 8, "an unknown id is ignored")
	# A clear for a chunk this client has not loaded is remembered, so the tree never spawns there.
	var far := Vector2i(7, 7)
	GameBus.tree_cleared.emit("tree_7_7_0")
	assert_true(t.cleared_indices(far).has(0), "a clear for an unloaded chunk is remembered")
	assert_false(t.cleared_indices(chunk).has(0), "and only for that chunk")
	GameBus.tree_cleared.emit(tid)
	assert_true(t.get_tree_record(tid).is_empty(), "the client drops the cleared tree")
	assert_eq(t.trees_in_chunk(chunk).size(), 7, "and only that one")
	assert_true(t.index_is_consistent(), "the index is consistent")
	if body != null:
		assert_true((body as Node).is_queued_for_deletion(), "its collision body is freed")
	# The client remembers it: unloading and reloading the chunk does not bring the tree back.
	t.despawn_for_chunk(chunk)
	t.spawn_for_chunk(chunk)
	assert_eq(t.trees_in_chunk(chunk).size(), 7, "a cleared tree stays gone after a client chunk reload")
	# A client never clears on its own from a local edit.
	var cpos: Vector3 = t.get_all_trees()[0]["position"]
	GameBus.block_edit_resolved.emit(_edit_tile_of(cpos, t), cpos.y)
	assert_eq(t.trees_in_chunk(chunk).size(), 7, "a client waits for the host")
	# A record arriving after the trees spawned reconciles them.
	var rec := ChunkRecordsScript.get_record(chunk).duplicate(true)
	rec["x"] = [0, 1]
	ChunkRecordsScript.set_record(chunk, RegionStoreScript.normalize_gen(rec))
	t.resync_recorded_chunks()
	assert_false(t.trees_in_chunk(chunk).has("tree_0_0_0") or t.trees_in_chunk(chunk).has("tree_0_0_1"),
		"a late record removes its cleared trees")
	t.free()
	ChunkRecordsScript.clear()

func _test_tree_pin_stump_regrows() -> void:
	var chunk := Vector2i(0, 0)
	var t := _tree_pin_rig(chunk)
	t.spawn_for_chunk(chunk)
	var tid: String = str(t.get_all_trees()[0]["tree_id"])
	t._set_chopped(tid)
	assert_eq(str(t.get_tree_record(tid)["state"]), "stump", "chopped")
	assert_false(ChunkRecordsScript.get_record(chunk).has("x"), "a chop records no cleared tree")
	t._trees[tid]["respawn_at"] = 1.0
	t._tick_respawn()
	assert_eq(str(t.get_tree_record(tid)["state"]), "standing", "the stump regrows after its cooldown")
	t.free()
	ChunkRecordsScript.clear()

func _test_tree_pin_record_validation() -> void:
	var base := _sync_record(Vector2i(3, 3))
	var ok := base.duplicate(true)
	ok["t"] = 5
	ok["x"] = [3, 1, 3]
	var n := RegionStoreScript.normalize_gen(ok)
	assert_eq(int(n["t"]), 5, "a valid budget is kept")
	assert_eq(n["x"], [1, 3], "cleared indices are deduplicated and sorted")
	for bad in [{ "t": -1 }, { "t": 9999 }, { "t": "8" }, { "x": [-1] }, { "x": [64] }, { "x": "1" }, { "x": [1.5] }]:
		var r := base.duplicate(true)
		r.merge(bad)
		var cleaned := RegionStoreScript.normalize_gen(r)
		assert_false(cleaned.is_empty(), "a malformed optional field keeps the ground: %s" % str(bad))
		assert_false(cleaned.has(str(bad.keys()[0])), "and only that field is dropped: %s" % str(bad))
		assert_eq(cleaned["h"], RegionStoreScript.normalize_gen(base)["h"], "the heights are untouched: %s" % str(bad))
	var half := ok.duplicate(true)
	half["x"] = "nope"
	var kept := RegionStoreScript.normalize_gen(half)
	assert_eq(int(kept["t"]), 5, "a malformed x keeps a valid t")
	assert_false(kept.has("x"), "and drops x")
	var broken := base.duplicate(true)
	broken["b"] = "NotABiome"
	assert_true(RegionStoreScript.normalize_gen(broken).is_empty(), "a malformed required field still rejects the record")
	assert_false(RegionStoreScript.normalize_gen(base).has("t"), "a record with neither stays as before")

func _test_tree_pin_edited_ground() -> void:
	var chunk := Vector2i(0, 0)
	var t := _tree_pin_rig(chunk)
	t.spawn_for_chunk(chunk)
	var target: Vector2i = t.get_all_trees()[0]["tile"]
	t.despawn_for_chunk(chunk)
	t.free()
	ChunkRecordsScript.clear()
	ChunkRecordsScript.set_record(chunk, _sync_record(chunk, "TemperateForest"))
	var vox := VoxelSlice.new()
	vox.place_block(Vector3(float(target.x) + 0.5, 0.0, float(target.y) + 0.5), Vector3.UP, "Stone")
	var t2 := _tree_pin_rig(chunk)
	t2.voxel_slice = vox
	if not vox.has_edit_near(target, 1):
		vox._edits[VoxelSlice._tile_key(target)] = [{ "op": "legacy" }]
		vox._edits_by_chunk[VoxelSlice._chunk_key(VoxelSlice._tile_to_chunk(target))] = { VoxelSlice._tile_key(target): true }
	t2.spawn_for_chunk(chunk)
	assert_true(t2.trees_in_chunk(chunk).size() < 8, "the tree on the edited tile never spawns")
	assert_true(ChunkRecordsScript.get_record(chunk).has("x"), "and is recorded as cleared")
	t2.free()
	vox.free()
	ChunkRecordsScript.clear()


# ---- Phase 116 — tree clears follow chunks onto clients ----

func _test_p116_late_chunk() -> void:
	var near := Vector2i(0, 0)
	var late := Vector2i(1, 0)
	ChunkRecordsScript.clear()
	var t := _make_tree_slice()
	t.is_authoritative = false
	t.spawn_for_chunk(near)
	# The host cleared tree 2 of a chunk this client had not loaded (and was not in its snapshot window).
	GameBus.tree_cleared.emit("tree_1_0_2")
	t.spawn_for_chunk(late)
	assert_true(t.get_tree_record("tree_1_0_2").is_empty(), "the cleared tree does not spawn on a late chunk")
	assert_eq(t.trees_in_chunk(late).size(), 7, "its siblings do")
	# A clear far from anything loaded is not remembered (the scoped records bring it on arrival).
	GameBus.tree_cleared.emit("tree_900_0_1")
	assert_false(t.cleared_indices(Vector2i(900, 0)).has(1), "a clear nowhere near the loaded chunks is dropped")
	# A record carrying the list reaches an already-spawned chunk with no trees of its own.
	var rec := _sync_record(late, "TemperateForest")
	rec["x"] = [0]
	ChunkRecordsScript.set_record(late, RegionStoreScript.normalize_gen(rec))
	t.resync_recorded_chunks()
	assert_true(t.get_tree_record("tree_1_0_0").is_empty(), "a late record clears its listed tree")
	t.free()
	ChunkRecordsScript.clear()

func _test_p116_seam_and_depth() -> void:
	var circ := TerrainSlice.circumference_chunks()
	var chunk := Vector2i(-1, 0)
	var t := _tree_pin_rig(chunk)
	t.spawn_for_chunk(chunk)
	var trees: Array = t.get_all_trees()
	var victim: Dictionary = trees[0]
	var vpos: Vector3 = victim["position"]
	var lap := float(circ * TerrainSlice.CHUNK_SIZE) * float(t._tile_size())
	# A mine 8 m below the tree's root leaves it standing.
	GameBus.block_edit_resolved.emit(_edit_tile_of(vpos, t), vpos.y - 8.0)
	assert_eq(t.trees_in_chunk(chunk).size(), trees.size(), "a deep mine clears nothing")
	# The same edit one lap round the world clears exactly what it clears here.
	GameBus.block_edit_resolved.emit(_edit_tile_of(Vector3(vpos.x + lap, vpos.y, vpos.z), t), vpos.y)
	assert_true(t.get_tree_record(str(victim["tree_id"])).is_empty(), "an edit across the seam clears the same tree")
	var after_seam: int = t.trees_in_chunk(chunk).size()
	var other: Dictionary = t.get_all_trees()[0]
	var opos: Vector3 = other["position"]
	GameBus.block_edit_resolved.emit(_edit_tile_of(opos, t), opos.y)
	assert_true(t.get_tree_record(str(other["tree_id"])).is_empty(), "and one away from the seam clears too")
	assert_true(t.trees_in_chunk(chunk).size() < after_seam, "one more tree went")
	assert_true(t.index_is_consistent(), "the index is consistent")
	t.free()
	ChunkRecordsScript.clear()

func _test_p116_station_unloaded() -> void:
	var home := Vector2i(0, 0)
	var next := Vector2i(1, 0)
	var t := _tree_pin_rig(home)
	t.spawn_for_chunk(home)
	var entry: Dictionary = t.tree_entry_for_biome("")
	var best := -1
	var best_x := 1.0e9
	for i in t.tree_count_for(next, ""):
		var xz: Vector2 = t._deterministic_chunk_position(next, str(entry["species"]), i)
		if xz.x < best_x:
			best_x = xz.x
			best = i
	var target: Vector2 = t._deterministic_chunk_position(next, str(entry["species"]), best)
	var cleared: Array = []
	var on_cleared := func(id: String) -> void: cleared.append(id)
	GameBus.tree_cleared.connect(on_cleared)
	GameBus.station_placed.emit("station_t116", "Workbench", Vector3(target.x - 2.0, 0.0, target.y))
	GameBus.tree_cleared.disconnect(on_cleared)
	assert_true(cleared.has("tree_1_0_%d" % best), "the station announces a tree in the not-yet-loaded neighbour")
	t.spawn_for_chunk(next)
	assert_true(t.get_tree_record("tree_1_0_%d" % best).is_empty(), "it stays cleared when the neighbour loads")
	t.free()
	ChunkRecordsScript.clear()

func _test_p116_cleared_local() -> void:
	ChunkRecordsScript.clear()
	var t := _make_tree_slice()
	t.is_authoritative = false
	t.spawn_for_chunk(Vector2i(0, 0))
	var tid: String = str(t.get_all_trees()[0]["tree_id"])
	var mi: int = int(t.get_tree_record(tid)["mi"])
	GameBus.tree_cleared.emit(tid)
	if t._pool != null:
		assert_true(t._pool._free.has(mi), "the MultiMesh slot of a cleared tree is released")
	GameBus.tree_cleared.emit("tree_1_0_64")
	GameBus.tree_cleared.emit("tree_1_0_-1")
	assert_false(t._cleared_local.has(Vector2i(1, 0)), "out-of-range indices are refused")
	for cx in range(-8, 9):
		for cz in range(-8, 9):
			for i in 12:
				GameBus.tree_cleared.emit("tree_%d_%d_%d" % [cx, cz, i])
	var total := 0
	for c in t._cleared_local:
		total += (t._cleared_local[c] as Dictionary).size()
	assert_true(total <= TreeSlice.CLEARED_LOCAL_CAP, "the local clears never exceed the cap (%d)" % total)
	assert_true(total > 0, "and still remember the recent ones")
	t._cleared_local[Vector2i(3, 3)] = { 1: true }
	t.despawn_for_chunk(Vector2i(3, 3))
	assert_true(t._cleared_local.has(Vector2i(3, 3)), "a client keeps its unrecorded clears across a despawn (Phase 126)")
	t.free()
	ChunkRecordsScript.clear()

func _test_p126_host_keeps_clears() -> void:
	var rig := _p126_host_rig()
	var t: Node = rig["t"]
	for i in 3000:
		@warning_ignore("integer_division")
		t._record_cleared(Vector2i(i % 60, i / 60), 1 + i % 7)
	var kept := 0
	for i in 3000:
		@warning_ignore("integer_division")
		var c := Vector2i(i % 60, i / 60)
		var rec := ChunkRecordsScript.get_record(c)
		var held: Dictionary = t._cleared_local.get(c, {})
		if (rec.get("x", []) as Array).has(1 + i % 7) or held.has(1 + i % 7):
			kept += 1
		# What a save writes and a load reads back is the record itself.
		if not rec.is_empty():
			assert_eq(RegionStoreScript.normalize_gen(rec), rec, "a stored record survives a save/load round trip")
	assert_eq(kept, 3000, "the host keeps every one of 3,000 chunks' clears (none evicted)")
	assert_eq(t.cleared_evictions, 0, "and evicts nothing")
	# With no way to pin a record (an isolated host) the clears wait, uncapped.
	t.record_writer = Callable()
	t._cleared_local.clear()
	t._cleared_total = 0
	for i in 3000:
		@warning_ignore("integer_division")
		t._record_cleared(Vector2i(i % 60, 100 + i / 60), 3)
	assert_eq(t._cleared_local.size(), 3000, "unpinnable host clears are all held, past the client cap")
	_p126_free(rig)

## Phase 138 — a plain-generator chunk (x >= 2) that grows at least `min_trees`; its biome entry and budget.
func _p138_tree_chunk(t: Node, min_trees: int) -> Vector2i:
	for x in range(2, 60):
		var c := Vector2i(x, 0)
		var biome: String = t._chunk_biome(c)
		if not t.tree_entry_for_biome(biome).is_empty() and t.tree_count_for(c, biome) >= min_trees:
			return c
	return Vector2i(-1000, 0)

func _test_p138_unpinned_clear_restart() -> void:
	var rig := _p126_host_rig()
	var t: Node = rig["t"]
	t.frontier_ready = func(_c: Vector2i) -> bool: return false   # the regions around the chunk are unread
	var chunk := _p138_tree_chunk(t, 2)
	assert_true(chunk != Vector2i(-1000, 0), "a tree-growing chunk exists in the search window")
	var biome: String = t._chunk_biome(chunk)
	var entry: Dictionary = t.tree_entry_for_biome(biome)
	var xz: Vector2 = t._deterministic_chunk_position(chunk, str(entry["species"]), 0)
	GameBus.station_placed.emit("station_p138", "Workbench", Vector3(xz.x, 0.0, xz.y))
	assert_false(ChunkRecordsScript.has_record(chunk), "no record could be pinned")
	assert_true(t._pending_spots.has(chunk), "the host held the clear circle")
	# A restart: the spots ride the world record's JSON, the chunk then loads with its record.
	var saved: Variant = JSON.parse_string(JSON.stringify(t.pending_spots_to_data()))
	t.free()
	ChunkRecordsScript.clear()
	var t2 := _make_tree_slice()
	t2.terrain_slice = rig["terrain"]
	t2.record_writer = func(c: Vector2i, rec: Dictionary) -> void:
		ChunkRecordsScript.set_record(c, RegionStoreScript.normalize_gen(rec))
	t2.pending_spots_from_data(saved)
	assert_true(t2._pending_spots.has(chunk), "the spots were restored")
	t2.spawn_for_chunk(chunk)
	assert_true(t2._pending_spots.has(chunk), "a chunk still without a record keeps them")
	assert_false(t2.get_tree_record("tree_%d_%d_0" % [chunk.x, chunk.y]).is_empty(), "and its tree stands until it has one")
	t2._pin_frontier_record(chunk)
	t2.spawn_for_chunk(chunk)
	assert_true(t2.get_tree_record("tree_%d_%d_0" % [chunk.x, chunk.y]).is_empty(), "once recorded, the cleared tree stays gone after the restart")
	assert_false(t2._pending_spots.has(chunk), "and the spots are released")
	t2.pending_spots_from_data({ "x,y": [[1, 2, 3]], "1,1": "junk", "2,2": [[1, 2], [NAN, 0, 1], ["a", 0, 1]] })
	assert_eq(t2._pending_spots.size(), 0, "malformed saved spots are skipped")
	t2.free()
	rig["terrain"].free()
	ChunkRecordsScript.clear()

func _test_p138_no_pin_without_hit() -> void:
	var rig := _p126_host_rig()
	var t: Node = rig["t"]
	var chunk := _p138_tree_chunk(t, 1)
	var biome: String = t._chunk_biome(chunk)
	var entry: Dictionary = t.tree_entry_for_biome(biome)
	var budget: int = t.tree_count_for(chunk, biome)
	var radius := TreeSlice.clear_radius_m()
	var span: float = float(t._chunk_size()) * float(t._tile_size())
	var spot := Vector2.INF
	for gz in range(1, 8):
		for gx in range(1, 8):
			var p := Vector2((float(chunk.x) + gx / 8.0) * span, (float(chunk.y) + gz / 8.0) * span)
			var near := false
			for i in budget:
				if t._deterministic_chunk_position(chunk, str(entry["species"]), i).distance_to(p) <= radius:
					near = true
			if not near and not spot.is_finite():
				spot = p
	if spot.is_finite():
		assert_eq(t._clear_unloaded_chunk(chunk, spot, radius, t._lap_metres()), 0, "a circle with no tree in it clears none")
		assert_false(ChunkRecordsScript.has_record(chunk), "and pins no record for the chunk")
		var first := Vector2(t._deterministic_chunk_position(chunk, str(entry["species"]), 0))
		assert_true(t._clear_unloaded_chunk(chunk, first, radius, t._lap_metres()) >= 1, "a circle on a tree clears it")
		assert_true(ChunkRecordsScript.has_record(chunk), "and then the record is pinned")
	_p126_free(rig)

func _test_p138_scope_total_client() -> void:
	var rig := _p126_host_rig()
	var t: Node = rig["t"]
	t.set_clear_scope([0, 0, 1000000])
	assert_eq(t.clear_id_range, TreeSlice.MAX_CLEAR_RANGE_CHUNKS, "a hostile scope radius is clamped")
	t.free()
	ChunkRecordsScript.clear()
	# A client: the running total follows the table, and a record is never written from the client side.
	var c := _make_tree_slice()
	c.is_authoritative = false
	var writes := []
	c.record_writer = func(ch: Vector2i, r: Dictionary) -> void: writes.append(ch)
	for i in 5:
		c._record_cleared(Vector2i(1, 0), i)
	c._record_cleared(Vector2i(2, 0), 1)
	assert_eq(c._cleared_total, 6, "the running total counts every held index")
	ChunkRecordsScript.set_record(Vector2i(1, 0), RegionStoreScript.normalize_gen(_sync_record(Vector2i(1, 0), "TemperateForest")))
	c._adopt_local_clears(Vector2i(1, 0))
	assert_true(writes.is_empty(), "a client does not write the host's record")
	assert_true(c._cleared_local.has(Vector2i(1, 0)), "and keeps indices the record does not carry")
	var rec := ChunkRecordsScript.get_record(Vector2i(1, 0)).duplicate(true)
	rec["x"] = [0, 1, 2, 3, 4]
	ChunkRecordsScript.set_record(Vector2i(1, 0), RegionStoreScript.normalize_gen(rec))
	c._adopt_local_clears(Vector2i(1, 0))
	assert_false(c._cleared_local.has(Vector2i(1, 0)), "it lets go once the record carries them")
	assert_eq(c._cleared_total, 1, "and the total follows")
	c.free()
	rig["terrain"].free()
	ChunkRecordsScript.clear()

func _test_p126_client_cap_lru() -> void:
	ChunkRecordsScript.clear()
	var t := _make_tree_slice()
	t.is_authoritative = false
	for cx in 40:
		for i in 60:
			t._record_cleared(Vector2i(cx, 0), i)
		if cx == 20:
			t._record_cleared(Vector2i(0, 0), 61)   # touched again: now the most recent chunk's neighbour
	t._record_cleared(Vector2i(0, 0), 62)
	var total := 0
	for c in t._cleared_local:
		total += (t._cleared_local[c] as Dictionary).size()
	assert_true(total <= TreeSlice.CLEARED_LOCAL_CAP, "a client holds at most the cap")
	assert_true(t._cleared_local.has(Vector2i(0, 0)), "the recently touched chunk survives the cap")
	assert_false(t._cleared_local.has(Vector2i(1, 0)), "the least recently touched chunk goes first")
	assert_true(t.cleared_evictions > 0, "evictions are counted")
	assert_true(t._eviction_warned, "and warned about (once)")
	t.free()
	ChunkRecordsScript.clear()

func _test_p126_frontier_clear() -> void:
	var rig := _p126_host_rig()
	var t: Node = rig["t"]
	var found := _p126_find_transition(t)
	assert_false(found.is_empty(), "a chunk beside recorded land with a transition biome exists in the search window")
	if not found.is_empty():
		var n: Vector2i = found["chunk"]
		var entry: Dictionary = t.tree_entry_for_biome(str(found["framed"]))
		var xz: Vector2 = t._deterministic_chunk_position(n, str(entry["species"]), 0)
		var cleared: Array = []
		var on_cleared := func(id: String) -> void: cleared.append(id)
		GameBus.tree_cleared.connect(on_cleared)
		GameBus.station_placed.emit("station_p126", "Workbench", Vector3(xz.x, 0.0, xz.y))
		GameBus.tree_cleared.disconnect(on_cleared)
		var rec := ChunkRecordsScript.get_record(n)
		assert_eq(str(rec.get("b", "")), str(found["framed"]), "the clear pinned the frontier record, not the plain biome")
		assert_true((rec.get("x", []) as Array).has(0), "with the cleared index in it")
		assert_true(cleared.has("tree_%d_%d_0" % [n.x, n.y]), "the clear names the tree of the frontier biome")
		t.spawn_for_chunk(n)
		assert_true(t.get_tree_record("tree_%d_%d_0" % [n.x, n.y]).is_empty(), "the same tree is gone once the chunk loads")
	_p126_free(rig)

func _test_p126_client_scope_and_ghost() -> void:
	ChunkRecordsScript.clear()
	var t := _make_tree_slice()
	t.is_authoritative = false
	var home := Vector2i(0, 0)
	t.spawn_for_chunk(home)
	var tid: String = str(t.get_all_trees()[0]["tree_id"])
	GameBus.tree_cleared.emit(tid)
	t.despawn_for_chunk(home)
	assert_true(t._cleared_local.has(home), "a client keeps an unrecorded clear after the chunk unloads")
	t.spawn_for_chunk(home)
	assert_true(t.get_tree_record(tid).is_empty(), "no ghost tree on return")
	# The host's record arrives carrying the clear: the local entry is released.
	var rec := _sync_record(home, "TemperateForest")
	rec["x"] = [int(tid.split("_")[3])]
	t.record_writer = func(c: Vector2i, r: Dictionary) -> void: ChunkRecordsScript.set_record(c, RegionStoreScript.normalize_gen(r))
	ChunkRecordsScript.set_record(home, RegionStoreScript.normalize_gen(rec))
	t.spawn_for_chunk(home)
	assert_false(t._cleared_local.has(home), "the record's arrival releases the local entry")
	assert_true(t.get_tree_record(tid).is_empty(), "and the tree stays gone")
	# The range is the scope's radius.
	t.set_clear_scope([0, 0, 5])
	assert_eq(t.clear_id_range, 5, "the clear range equals the gen_scope radius")
	GameBus.tree_cleared.emit("tree_5_0_3")
	GameBus.tree_cleared.emit("tree_6_0_3")
	assert_true(t._cleared_local.has(Vector2i(5, 0)), "a clear at the scope's edge is kept")
	assert_false(t._cleared_local.has(Vector2i(6, 0)), "one past it is left to the records")
	t._cleared_local[Vector2i(4, 4)] = { 1: true }
	t._cleared_total += 1
	t.set_clear_scope([20, 0, 5])
	assert_false(t._cleared_local.has(Vector2i(4, 4)), "a scope move releases clears outside it")
	t.set_clear_scope("junk")
	assert_eq(t.clear_id_range, 5, "a malformed scope changes nothing")
	for k in 200:
		t.spawn_for_chunk(Vector2i(k, 0))
	for k in 200:
		t.despawn_for_chunk(Vector2i(k, 0))
	assert_true(t._spawn_buckets.is_empty(), "the bucket index empties with the spawned chunks")
	# Across the world seam, whatever the cell size: the last chunk on one side sees the first on the other.
	var circ := TerrainSlice.circumference_chunks()
	for r in [3, 5, 8, 13]:
		t.clear_id_range = r
		@warning_ignore("integer_division")
		t.spawn_for_chunk(Vector2i(-circ / 2, 0))
		@warning_ignore("integer_division")
		assert_true(t._near_loaded_chunk(Vector2i(circ / 2 - 1, 0)), "range %d: a chunk across the seam is near" % r)
		@warning_ignore("integer_division")
		t.despawn_for_chunk(Vector2i(-circ / 2, 0))
	t.free()
	ChunkRecordsScript.clear()

func _test_p126_deep_edit_agrees() -> void:
	var chunk := Vector2i(0, 0)
	var t := _tree_pin_rig(chunk)
	t.spawn_for_chunk(chunk)
	var victim: Dictionary = t.get_all_trees()[0]
	var tile: Vector2i = victim["tile"]
	var root_y := float((victim["position"] as Vector3).y)
	assert_eq(t.clear_trees_near_tile(tile, root_y - 8.0), 0, "a deep edit clears nothing live")
	t.despawn_for_chunk(chunk)
	t.free()
	var vox := VoxelSlice.new()
	var deep := root_y - 8.0
	vox._edits[VoxelSlice._tile_key(tile)] = [{ "op": "remove", "bottom": deep - 0.125, "top": deep },
		{ "op": "deplete", "vein": 1, "taken": 1 }]
	vox._edits_by_chunk[VoxelSlice._chunk_key(VoxelSlice._tile_to_chunk(tile))] = { VoxelSlice._tile_key(tile): true }
	var t2 := _tree_pin_rig(chunk)
	t2.voxel_slice = vox
	t2.spawn_for_chunk(chunk)
	assert_false(t2.get_tree_record(str(victim["tree_id"])).is_empty(), "on reload the same tree is kept by the deep edit")
	t2.despawn_for_chunk(chunk)
	vox._edits[VoxelSlice._tile_key(tile)] = [{ "op": "add", "bottom": root_y, "top": root_y + 0.125, "material": "Stone" }]
	t2.spawn_for_chunk(chunk)
	assert_true(t2.get_tree_record(str(victim["tree_id"])).is_empty(), "a shallow edit on the tile clears it on reload")
	t2.free()
	vox.free()
	ChunkRecordsScript.clear()

func _test_p126_far_edit_tile() -> void:
	var chunk := Vector2i(1500000, 0)
	var t := _tree_pin_rig(chunk)
	t.spawn_for_chunk(chunk)
	var trees: Array = t.get_all_trees()
	assert_true(trees.size() > 1, "the far chunk grows trees")
	var victim: Dictionary = trees[0]
	var tile: Vector2i = victim["tile"]
	GameBus.block_edit_resolved.emit(tile, float((victim["position"] as Vector3).y))
	assert_true(t.get_tree_record(str(victim["tree_id"])).is_empty(), "an edit at chunk X = 1,500,000 clears the resolved tile's tree")
	t.free()
	ChunkRecordsScript.clear()

func _test_p126_normalize_gen_drops_bad_entries() -> void:
	var base := _sync_record(Vector2i(2, 2), "TemperateForest")
	base["t"] = 5
	base["x"] = [3, "junk", 70, 4, -1, 3]
	var before := RegionStoreScript.malformed_gen_entries
	var out := RegionStoreScript.normalize_gen(base)
	assert_eq(out["x"], [3, 4], "a gen with malformed x entries keeps its other entries")
	assert_eq(int(out["t"]), 5, "and its t")
	assert_eq(RegionStoreScript.malformed_gen_entries - before, 3, "each bad entry is counted")
	var bad_t := base.duplicate(true)
	bad_t["t"] = "many"
	var out2 := RegionStoreScript.normalize_gen(bad_t)
	assert_false(out2.has("t"), "a malformed t is dropped alone")
	assert_eq(out2["x"], [3, 4], "and the cleared list stays")

func _test_p127_records() -> void:
	var R := RegionStoreScript
	# #287: an older incoming gen never overwrites a newer stored gen, even on the empty-edit branch.
	var newer := { "v": TerrainSlice.WORLDGEN_VERSION + 1, "x": 1 }
	var base := { "0,0": { "edits": { "1,1": [] }, "gen": newer } }
	var folded := R.fold_chunks(base, { "0,0": { "edits": {}, "gen": _p127_rec() } })
	assert_eq(folded["0,0"]["gen"], newer, "an older incoming gen does not replace a newer stored one")
	# a tree-only adopt reports nothing to rebuild
	ChunkRecordsScript.clear()
	var a := _p127_rec()
	var changed: Array = []
	ChunkRecordsScript.adopt_region({ "3,3": { "gen": a } }, changed)
	assert_eq(changed, ["3,3"], "a new ground is reported")
	var with_trees := a.duplicate()
	with_trees["t"] = 4
	changed = []
	ChunkRecordsScript.adopt_region({ "3,3": { "gen": with_trees } }, changed)
	assert_true(changed.is_empty(), "a tree-only difference rebuilds no mesh")
	assert_eq(ChunkRecordsScript.get_record(Vector2i(3, 3)).get("t", 0), 4, "though the table takes it")
	# #306: snapshot_near on a big table splits no keys
	ChunkRecordsScript.clear()
	for i in 100000:
		@warning_ignore("integer_division")
		ChunkRecordsScript.set_record(Vector2i(i % 1000, i / 1000), _p127_rec())
	var splits := ChunkRecordsScript.key_splits
	var snap := ChunkRecordsScript.snapshot_near(Vector2i(500, 50), 3, 0)
	assert_eq(snap.size(), 49, "the window's records are found")
	assert_eq(ChunkRecordsScript.key_splits, splits, "without splitting a single key")
	# #307: shape_height with records builds no snapshot
	var built := ChunkRecordsScript.snapshots_built
	TerrainSlice.shape_height(7, 500.0 * 32.0 + 3.0, 50.0 * 32.0 + 3.0, 0.0)
	assert_eq(ChunkRecordsScript.snapshots_built, built, "shape_height looks a record up directly")
	# the region revision: a change outside the window leaves its sum alone, one inside moves it
	var wrev := ChunkRecordsScript.window_revision(Vector2i(500, 50), 3, 0)
	ChunkRecordsScript.set_record(Vector2i(5000, 5000), _p127_rec("Forest"))
	assert_eq(ChunkRecordsScript.window_revision(Vector2i(500, 50), 3, 0), wrev, "a far change leaves the window revision")
	ChunkRecordsScript.set_record(Vector2i(501, 51), _p127_rec("Forest", 9.0))
	assert_true(ChunkRecordsScript.window_revision(Vector2i(500, 50), 3, 0) != wrev, "a change inside moves it")
	ChunkRecordsScript.clear()
	# #288: pruned chunks are reported
	for i in 5:
		ChunkRecordsScript.set_record(Vector2i(i * 40, 0), _p127_rec())
	var pruned: Array = []
	ChunkRecordSyncScript.prune_to_scope([0, 0, 50], pruned)
	assert_eq(pruned.size(), 3, "the pruned chunks are collected for a rebuild")
	ChunkRecordsScript.clear()
	# #288: freeing a manager leaves another's records
	var rig := _records_rig("test_p127_free")
	var cm: ChunkManager = rig["cm"]
	ChunkRecordsScript.set_record(Vector2i(1, 1), _p127_rec())
	add_child(cm)
	remove_child(cm)
	cm.free()
	assert_true(ChunkRecordsScript.has_record(Vector2i(1, 1)), "freeing one manager leaves the table intact")
	(rig["t"] as Node).free()
	ChunkRecordsScript.clear()

func _test_p127_frontier_diagonal() -> void:
	ChunkRecordsScript.clear()
	var recs := { Vector2i(0, 0): { "b": "Desert", "h": [40.0, 40.0, 40.0, 40.0] } }
	var cache := {}
	var prev := NAN
	var worst := 0.0
	for k in range(1, 8):
		var p := Vector2i(k + 1, k + 1)
		var off: float = Frontier.corner_height(p, 5, recs, cache) - TerrainSlice.generated_corner_height(p, 5)
		if not is_nan(prev):
			worst = maxf(worst, absf(off - prev))
		prev = off
	assert_true(worst <= 40.0 * 0.6, "the offset fades without a step along the diagonal (worst %.2f)" % worst)
	var far: float = Frontier.corner_height(Vector2i(9, 9), 5, recs, cache)
	assert_eq(far, snappedf(clampf(TerrainSlice.generated_corner_height(Vector2i(9, 9), 5), WorldShape.min_height(), WorldShape.max_height()), TerrainSlice.GEN_HEIGHT_STEP), "past the span the plain generator answers")

func _test_p127_flush_final_and_compact() -> void:
	var rig := _records_rig("test_p127_flush")
	var cm: ChunkManager = rig["cm"]
	var store: RegionStoreScript = rig["store"]
	_p114_corrupt_region(store, Vector2i.ZERO)
	cm.load_chunk(Vector2i(2, 2))
	assert_eq(cm.pending_record_count(), 1, "a record is pending")
	cm.flush_records_final()
	assert_eq(cm.pending_record_count(), 1, "a failed final flush keeps its keys pending")
	cm.free()
	(rig["t"] as Node).free()
	ChunkRecordsScript.clear()
	# #302: a 40-character compact position is refused before decoding
	var before := WorldPos.compact_decodes
	var good := WorldPos.pos_to_packet_text(WorldPos.from_world(1.0, 2.0, 3.0))
	assert_true(WorldPos.pos_from_compact(good).size() > 0, "an exact-length position decodes")
	assert_eq(WorldPos.compact_decodes, before + 1, "counted")
	assert_true(WorldPos.pos_from_compact("A".repeat(40)).is_empty(), "a 40-character text is refused")
	# a per-tick packet is decoded once
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.set_transport(MemoryTransport.new([5]))
	var seen: Array = []
	var cb := func(_peer: int, pos: Vector3) -> void: seen.append(pos)
	GameBus.remote_player_state.connect(cb)
	var d0 := WorldPos.compact_decodes
	n._route_c2h(5, { "type": "player_moved", "peer_id": 5, "pk": good })
	GameBus.remote_player_state.disconnect(cb)
	assert_eq(WorldPos.compact_decodes - d0, 1, "a per-tick packet is decoded once")
	n.free()
	# the emulator delivers the payload as it was at enqueue
	var e := NetworkingSlice.new()
	add_child(e)
	e.set_transport(_StampingTransport.new([4]))
	e.emulate_network = true
	e.emulator_loss_rate = 0.0
	e.emulator_jitter_ms = 0.0
	var payload := { "type": "x", "v": [1] }
	e._deliver(4, payload)
	payload["v"].append(2)
	e._drain_emulator()
	var out: Array = e.memory_transport().outbox
	assert_eq(out.size(), 1, "delivered")
	assert_eq((out[0]["payload"]["v"] as Array).size(), 1, "as it was when queued")
	e.free()

func _test_p127_streamer_and_txn() -> void:
	# per-region stranded backoff: a second region starts at the base wait
	var dir := _fresh_region_dir("test_p127_stream")
	var store := RegionStoreScript.new(dir + "regions/")
	var voxel := _Voxel121.new()
	var streamer := RegionStreamer121.new(store, voxel)
	var clock := [0]
	streamer._now = func() -> int: return clock[0]
	streamer.sync({ "0,0": true })
	voxel.keys = ["1,1"]
	voxel.dirty = { "1,1": true }
	streamer.sync({})
	for i in 3:
		clock[0] += RegionStreamer121.STRANDED_RETRY_MAX_MSEC
		streamer.release_stranded()
	assert_eq(int(streamer._stranded_wait["0,0"]["delay"]), RegionStreamer121.STRANDED_RETRY_MAX_MSEC, "the first region has backed off to the cap")
	streamer.sync({ "1,0": true })
	voxel.keys = ["1,1", "40,1"]
	voxel.dirty = { "1,1": true, "40,1": true }
	streamer.sync({})
	assert_eq(int(streamer._stranded_wait["1,0"]["delay"]), RegionStreamer121.STRANDED_RETRY_START_MSEC, "a second stranded region starts at the base backoff")
	# SaveTxn: a stale .bak is not restored over a newer commit; a read during commit sees the old file
	var d := "user://saves/test_p127_txn/"
	_wipe_dir(d)
	DirAccess.make_dir_recursive_absolute(d)
	var path := d + "a.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("new")
	f.close()
	var stale := FileAccess.open(path + ".bak", FileAccess.WRITE)
	stale.store_string("stale")
	stale.close()
	var tmp := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	tmp.store_string("newer")
	tmp.close()
	var ops := [{ "path": path, "tmp": path + ".tmp", "kind": "region" }, { "path": d + "w.json", "tmp": "", "kind": "world" }]
	assert_eq(SaveTxn121.commit(ops, d + "j", Callable()), OK, "the commit lands")
	assert_eq(FileAccess.get_file_as_string(path), "newer", "the new content is live")
	assert_false(FileAccess.file_exists(path + ".bak"), "and no .bak is left")
	# a region read in the commit gap
	var rs := RegionStoreScript.new(d + "regions/")
	DirAccess.make_dir_recursive_absolute(d + "regions/")
	rs.save_region(Vector2i.ZERO, { "0,0": { "gen": _p127_rec() } })
	var rpath := rs.path_of(Vector2i.ZERO)
	DirAccess.rename_absolute(rpath, rpath + ".bak")
	assert_true(rs.read_region(Vector2i.ZERO)["chunks"].is_empty(), "with no journal a lone .bak is stale: nothing is read")
	var j := FileAccess.open(rs.journal_path(), FileAccess.WRITE)
	j.store_string("{}")
	j.close()
	assert_true(rs.read_region(Vector2i.ZERO)["chunks"].has("0,0"), "mid-commit (journal present) the old file is read, never 'missing'")
	DirAccess.remove_absolute(rs.journal_path())
	DirAccess.remove_absolute(rpath + ".bak")
	# a region failing past the bound escalates: world.json is written
	var slice := _slice121("test_p127_escalate")
	var chunks := { "1,1": { "gen": _p127_rec() } }
	var _bad := RegionStoreScript.new(slice.server_save_dir + "regions/")
	_p114_corrupt_region(slice.region_store, Vector2i.ZERO)
	for i in RegionStoreScript.MAX_REGION_FAILURES - 1:
		assert_true(slice.save_world({ "seed": 3, "chunks": chunks }) != OK, "a failing region fails the save")
	assert_false(slice.has_world(), "the record is held back while the region is within the bound")
	assert_true(slice.save_world({ "seed": 3, "chunks": chunks }) != OK, "past the bound the error is still reported")
	assert_true(slice.has_world(), "but world.json is written")
	# a region that stopped failing no longer escalates a different region's first failure
	assert_true(slice.region_store.has_exhausted_region(), "the failing region is exhausted")
	slice.region_store.last_failed_region_keys = ["99,99"]
	assert_false(slice.region_store.has_exhausted_region(), "only regions that failed in the last save count")
	slice.free()

func _test_p127_audit() -> void:
	var sync_src := FileAccess.get_file_as_string("res://src/terrain/chunk_record_sync.gd")
	assert_true(sync_src.contains("different.\nstatic func apply("), "apply's doc comment sits on apply, not on SCAN_FACTOR")
	assert_true(FileAccess.get_file_as_string("res://src/terrain/climate_field.gd").contains("A lattice draw in `[0, 1)`"), "_lattice carries its own doc comment")
	var src := FileAccess.get_file_as_string("res://src/terrain/chunk_manager.gd")
	assert_false(src.contains("_in_bounds"), "_in_bounds is gone")
	assert_false(src.contains("var _now"), "ChunkManager has one clock")
	assert_false(FileAccess.get_file_as_string("res://src/persistence/region_store.gd").contains("func recover("), "RegionStore.recover is gone")
	assert_eq(TerrainSlice.NOISE_OFFSET_RANGE * 0.5, 2048.0, "the offsets span half the range either way")
	for i in 200:
		var o := TerrainSlice.cell_offset(11, i + 1, -i - 3)
		assert_true(absf(o.x) <= TerrainSlice.NOISE_OFFSET_RANGE * 0.5 and absf(o.y) <= TerrainSlice.NOISE_OFFSET_RANGE * 0.5, "cell_offset stays within the documented range")


# ---------------------------------------------------------------------------
# Phase 128 — weather
# ---------------------------------------------------------------------------

func _test_p116_record_revision() -> void:
	var chunk := Vector2i(20, 20)
	var rig := _records_rig("test_p116_rev")
	var cm: ChunkManager = rig["cm"]
	cm.load_chunk(chunk)
	var rec: Dictionary = ChunkRecordsScript.get_record(chunk).duplicate(true)
	var before := ChunkRecordsScript.revision()
	rec["t"] = 5
	rec["x"] = [1, 2]
	cm.update_record(chunk, rec)
	assert_eq(int(ChunkRecordsScript.get_record(chunk).get("t", -1)), 5, "the tree budget is stored")
	assert_eq(ChunkRecordsScript.revision(), before, "a tree-only update leaves the ground revision alone")
	rec["h"] = [1.0, 1.0, 1.0, 1.0]
	cm.update_record(chunk, rec)
	assert_true(ChunkRecordsScript.revision() != before, "a ground change bumps it")
	cm.free()
	rig["t"].free()
	ChunkRecordsScript.clear()


# ---- Phase 114 — generation record and frontier cleanup sweep ----

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

## Review of #159 — a failed save re-marks only the chunks of the regions that failed.
func _test_region_failed_keys_and_remark() -> void:
	var dir := _fresh_region_dir("test_failed_keys")
	var store: RegionStoreScript = RegionStoreScript.new(dir + "regions/")
	DirAccess.make_dir_recursive_absolute(dir + "regions/")
	var f := FileAccess.open(store.path_of(Vector2i(0, 0)), FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	var entry := { "edits": { "0,0": [{ "op": "remove", "bottom": 1.0, "top": 1.0 }] } }
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

func _test_region_malformed_entry_replaced() -> void:
	var dir := _fresh_region_dir("test_p75_malformed_replace")
	var store: RegionStoreScript = RegionStoreScript.new(dir + "regions/")
	var good := { "edits": { "0,0": [{ "op": "remove", "bottom": 0.0, "top": 1.0 }] } }
	_write_region_file(store, { "1,1": { "edits": "x" } })
	assert_eq(store.write_chunks({ "1,1": good }), OK, "a save carrying the key")
	var read := store.read_region(Vector2i.ZERO)
	assert_true(read["raw_invalid"].is_empty(), "no malformed entry remains")
	assert_true(read["chunks"]["1,1"] == good, "the valid entry replaced it")

func _test_region_gen_round_trip() -> void:
	var dir := _fresh_region_dir("test_p107_roundtrip")
	var store: RegionStoreScript = RegionStoreScript.new(dir + "regions/")
	var rec := _gen_rec()
	var edit := { "edits": { "0,0": [{ "op": "remove", "bottom": 0.0, "top": 1.0 }] } }
	assert_eq(store.write_chunks({ "2,3": edit }), OK, "an edit is saved")
	assert_eq(store.set_gen(Vector2i(2, 3), rec), OK, "a gen is recorded beside it")
	assert_eq(store.set_gen(Vector2i(-1, 0), rec), OK, "a gen-only chunk is recorded in another region")
	var got := store.get_gen(Vector2i(2, 3))
	assert_eq(int(got["v"]), int(rec["v"]), "version kept")
	assert_eq(int(got["f"]), int(rec["f"]), "fingerprint kept")
	assert_eq(got["b"], "Tundra", "biome kept")
	for i in 4:
		assert_true(absf(float(got["h"][i]) - float(rec["h"][i])) <= 1e-4, "height %d equal to 1e-4" % i)
	assert_true(store.load_region(Vector2i.ZERO)["2,3"]["edits"] == edit["edits"], "the edits survive set_gen")
	assert_eq(store.write_chunks({ "2,3": { "edits": {} } }), OK, "edits compact away")
	assert_eq(store.get_gen(Vector2i(2, 3)).get("b", ""), "Tundra", "the gen outlives the deletion marker")
	assert_true(store.write_chunks({ "2,3": { "edits": { "1,1": [] } } }) == OK and store.get_gen(Vector2i(2, 3)).has("h"), "an edit save keeps the gen")
	assert_eq(store.list_dirty(["2,3", "40,0"]).size(), 2, "list_dirty counts a gen-only change")
	assert_eq(store.set_gen(Vector2i(5, 5), { "v": 1 }), ERR_INVALID_DATA, "a malformed record is refused")
	assert_true(store.get_gen(Vector2i(5, 5)).is_empty(), "nothing written for it")

func _test_region_v1_upgrade() -> void:
	var dir := _fresh_region_dir("test_p107_v1")
	var store: RegionStoreScript = RegionStoreScript.new(dir + "regions/")
	var edit := { "edits": { "0,0": [{ "op": "remove", "bottom": 0.0, "top": 1.0 }] } }
	_write_region_file(store, { "1,1": edit })   # writes "version": 1
	assert_true(store.load_region(Vector2i.ZERO)["1,1"] == edit, "a version-1 file loads unchanged")
	assert_true(store.get_gen(Vector2i(1, 1)).is_empty(), "and carries no gen")
	assert_eq(store.set_gen(Vector2i(1, 1), _gen_rec()), OK, "a save of it")
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.path_of(Vector2i.ZERO)))
	assert_eq(int(parsed["version"]), 2, "writes version 2")
	assert_eq(JSON.stringify(parsed["chunks"]["1,1"]["edits"]), JSON.stringify(edit["edits"]), "with its edits intact")

func _test_region_gen_malformed() -> void:
	var dir := _fresh_region_dir("test_p107_malformed")
	var store: RegionStoreScript = RegionStoreScript.new(dir + "regions/")
	var edit := { "edits": { "0,0": [{ "op": "remove", "bottom": 0.0, "top": 1.0 }] } }
	var good := _gen_rec()
	var bads: Array = [
		"x", { "v": "5", "f": 1, "b": "Tundra", "h": [1, 1, 1, 1] },
		{ "v": 1, "f": 1, "b": "Nowhere", "h": [1.0, 1.0, 1.0, 1.0] },
		{ "v": 1, "f": 1, "b": "Tundra", "h": [1.0, 1.0, 1.0] },
		{ "v": 1, "f": 1, "b": "Tundra", "h": [1.0, 1.0, 1.0, "a"] },
		{ "v": 1, "f": 1, "b": "Tundra", "h": [1.0, 1.0, 1.0, WorldShape.max_height() + 1.0] },
		{ "v": 1, "f": 1, "b": "Tundra", "h": [1.0, 1.0, 1.0, WorldShape.min_height() - 1.0] },
	]
	var chunks := {}
	for i in bads.size():
		chunks["%d,0" % i] = { "edits": edit["edits"], "gen": bads[i] }
	chunks["20,0"] = { "edits": edit["edits"], "gen": good }
	_write_region_file(store, chunks)
	var loaded := store.load_region(Vector2i.ZERO)
	for i in bads.size():
		assert_true(loaded["%d,0" % i] == edit, "bad gen %d dropped, edits survive" % i)
	assert_true(loaded["20,0"].has("gen"), "a good record is kept")
	var nan_h := { "v": 1, "f": 1, "b": "Tundra", "h": [NAN, 1.0, 1.0, 1.0] }
	assert_true(RegionStoreScript.normalize_gen(nan_h).is_empty(), "a NaN height is refused")
	# One warning for two loads: the second read finds the key already warned.
	var warned_before := store._warned.size()
	store.load_region(Vector2i.ZERO)
	assert_eq(store._warned.size(), warned_before, "a second load raises no new warning")
	assert_eq(warned_before, bads.size(), "the first load warned once per bad record")

func _test_region_gen_size() -> void:
	var dir := _fresh_region_dir("test_p107_size")
	var store: RegionStoreScript = RegionStoreScript.new(dir + "regions/")
	var chunks := {}
	for x in 32:
		for z in 32:
			var rec := _gen_rec(TerrainSlice.BIOME_KEYS[(x + z) % TerrainSlice.BIOME_KEYS.size()], 3.0 + x * 0.123456 + z * 0.0173)
			chunks["%d,%d" % [x, z]] = { "gen": RegionStoreScript.normalize_gen(rec) }
	assert_eq(store.write_chunks(chunks), OK, "1,024 recorded chunks are saved")
	var bytes := FileAccess.get_file_as_bytes(store.path_of(Vector2i.ZERO)).size()
	assert_true(bytes < 100 * 1024, "the region file is under 100 KB (%d bytes)" % bytes)
	assert_eq(store.load_region(Vector2i.ZERO).size(), 1024, "all of them load back")

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
		"world":       { "local_player_id": pid, "chunks": { "0,0": { "edits": { "1,1": [{ "op": "remove", "bottom": 1.0, "top": 1.0 }] } } } },
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
	var key := VoxelSlice._tile_key(Vector2i(32, 32))
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

func _test_region_save_writes_one_file() -> void:
	var dir := _fresh_region_dir("test_p52_one_file")
	var writer := PersistenceSlice.new()
	add_child(writer)
	writer.server_save_dir = dir
	writer._sync_region_store()
	var edit := { "edits": { "0,0": [{ "op": "remove", "bottom": 1.0, "top": 1.0 }] } }
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
	store._sync_region_store()
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

func _test_region_full_save_erases_and_migration_keeps_newer() -> void:
	var dir := _fresh_region_dir("test_p52_full_erase")
	var writer := PersistenceSlice.new()
	add_child(writer)
	writer.server_save_dir = dir
	writer._sync_region_store()
	var old_edit := { "edits": { "0,0": [{ "op": "remove", "bottom": 1.0, "top": 1.0 }] } }
	assert_eq(writer.save_world({ "local_player_id": "p", "chunks": { "0,0": old_edit, "1,0": old_edit } }, false), OK, "seed save")
	# A FULL save whose dirty chunk 0,0 compacted away carries the deletion marker.
	assert_eq(writer.save_world({ "local_player_id": "p", "chunks": { "0,0": { "edits": {} }, "1,0": old_edit } }, false), OK, "full save with a marker")
	var chunks := writer.load_region_chunks([Vector2i(0, 0)])
	assert_false(chunks.has("0,0"), "a full save erases a chunk whose edits compacted away")
	assert_true(chunks.has("1,0"), "and keeps the others")
	# A migration never overwrites a chunk a region already holds (stale monolith vs newer saves).
	var stale := { "1,0": { "edits": { "9,9": [{ "op": "remove", "bottom": 1.0, "top": 5.0 }] } }, "2,0": old_edit }
	assert_eq(writer.region_store.migrate_manifest(stale), OK, "migration runs")
	chunks = writer.load_region_chunks([Vector2i(0, 0)])
	assert_false((chunks["1,0"]["edits"] as Dictionary).has("9,9"), "the newer region entry wins over the stale monolith")
	assert_true(chunks.has("2,0"), "a chunk the region lacked is migrated in")
	writer.free()

func _test_region_unreadable_not_overwritten() -> void:
	var dir := _fresh_region_dir("test_p52_unreadable")
	var store: RegionStoreScript = RegionStoreScript.new(dir + "regions/")
	DirAccess.make_dir_recursive_absolute(dir + "regions/")
	var path := store.path_of(Vector2i.ZERO)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	var entry := { "edits": { "0,0": [{ "op": "remove", "bottom": 1.0, "top": 1.0 }] } }
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
	var entry := { "edits": { "0,0": [{ "op": "remove", "bottom": 1.0, "top": 1.0 }] } }
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

func _test_region_neighbour_expansion_edges_only() -> void:
	var interior := RegionStreamerScript.regions_for_chunks([Vector2i(10, 10)])
	assert_eq(interior.keys(), ["0,0"], "an interior chunk wants only its own region")
	var corner := RegionStreamerScript.regions_for_chunks([Vector2i(0, 0)])
	assert_true(corner.has("0,0") and corner.has("-1,-1") and corner.has("-1,0") and corner.has("0,-1"),
		"a corner chunk also wants the regions across its edges")
	var east := RegionStreamerScript.regions_for_chunks([Vector2i(31, 10)])
	assert_true(east.has("0,0") and east.has("1,0") and not east.has("0,1") and not east.has("0,-1"),
		"an east-edge chunk reaches the next region east and no other")

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
	var edit := { "edits": { "0,0": [{ "op": "remove", "bottom": 1.0, "top": 1.0 }] } }
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
	gr._persistence_wiring._record_first_spawn(pid)
	var spawn: Variant = reg.spawn_of(pid)
	assert_true(spawn != null, "the spawn was recorded")
	assert_eq(spawn["chunk"], chunk, "in the exact chunk")
	assert_true((spawn["local"] as Vector3).distance_to(local) < 1.0e-6, "and the exact local within 1e-6 m")
	gr.free()
	player.free()

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
	var entry := { "edits": { "0,0": [{ "op": "remove", "bottom": 1.0, "top": 1.0 }] } }
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
	assert_false(store.has_world(), "world.json is held back while a region failed (Phase 121)")
	assert_eq(float(store.load_player(pid).get("hp", -1.0)), 7.0, "and so was the player record")
	store.free()

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
	var entry := { "edits": { "0,0": [{ "op": "remove", "bottom": 1.0, "top": 1.0 }] } }
	assert_eq(store.save_region(Vector2i.ZERO, { "0,0": entry }), OK, "the file is repaired")
	clock[0] += RegionStreamerScript.BACKOFF_START_MSEC
	r = streamer.sync(wanted)
	assert_eq(int(r["loaded"]), 1, "the next sync reads it again")
	assert_true(streamer.is_resident(Vector2i.ZERO), "and it is resident")
	assert_true(voxel.edited_chunk_keys().has("0,0"), "with its edits applied")
	voxel.free()

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
	assert_eq(store.save_region(Vector2i.ZERO, { "0,0": { "edits": { "0,0": [{ "op": "remove", "bottom": 1.0, "top": 1.0 }] } } }), OK, "the file is repaired")
	assert_eq(int(streamer.sync(wanted)["loaded"]), 1, "the first read after the backoff loads it")
	assert_false(streamer.is_backing_off(Vector2i.ZERO), "and clears the backoff")
	voxel.free()

## A tile's op list must hold ops (Dictionaries) — or, for a legacy entry, a bare number.
func _test_region_entry_rejects_bad_ops() -> void:
	assert_true(RegionStoreScript.is_valid_chunk_entry({ "edits": { "0,0": [{ "op": "remove", "bottom": 1.0, "top": 1.0 }] } }), "an op list of ops is valid")
	assert_true(RegionStoreScript.is_valid_chunk_entry({ "edits": { "0,0": 1.5 } }), "a legacy bare height is left to the voxel slice")
	assert_false(RegionStoreScript.is_valid_chunk_entry({ "edits": { "0,0": [5, "x"] } }), "an op list of non-ops is not")
	assert_false(RegionStoreScript.is_valid_chunk_entry({ "edits": { "0,0": [{ "op": "raise" }, null] } }), "one bad op spoils the list")

func _test_region_malformed_entry_skipped() -> void:
	var dir := _fresh_region_dir("test_p61_entry")
	var store: RegionStoreScript = RegionStoreScript.new(dir + "regions/")
	DirAccess.make_dir_recursive_absolute(dir + "regions/")
	var good := { "edits": { "0,0": [{ "op": "remove", "bottom": 1.0, "top": 1.0 }] } }
	var f := FileAccess.open(store.path_of(Vector2i.ZERO), FileAccess.WRITE)
	f.store_string(JSON.stringify({ "version": 1, "chunks": {
		"1,1": good, "2,2": { "edits": 5 }, "3,3": { "edits": {}, "materials": "x" } } }))
	f.close()
	var before := Diag.warn_count()
	var chunks := store.load_region(Vector2i.ZERO)
	assert_eq(chunks.keys(), ["1,1"], "the well-formed chunk loads")
	assert_eq(Diag.warn_count() - before, 2, "one warning per malformed entry")

func _test_region_streams_only_near_windows() -> void:
	var dir := _fresh_region_dir("test_p52_rss")
	var store: RegionStoreScript = RegionStoreScript.new(dir + "regions/")
	# 1,000 edited regions on disk, none of them the origin's. A chunk is 64 tiles a side.
	for i in range(1000):
		@warning_ignore("integer_division")
		var region := Vector2i(10 + i % 40, 10 + i / 40)
		var region_edit := { "edits": { "%d,%d" % [region.x * 32 * 64, region.y * 32 * 64]: [{ "op": "remove", "bottom": 1.0, "top": 1.0 }] } }
		assert_eq(store.save_region(region, { "%d,%d" % [region.x * 32, region.y * 32]: region_edit }), OK, "region %d written" % i)
	var edit := { "edits": { "0,0": [{ "op": "remove", "bottom": 1.0, "top": 1.0 }] } }
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
	cm.set_peer_center(7, Vector2i(10 * 32 + 3, 10 * 32 + 3), true)
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
	var far_edit := { "edits": { "%d,%d" % [320 * 64, 320 * 64]: [{ "op": "remove", "bottom": 1.0, "top": 1.0 }] } }
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
	cm.region_streamer._stranded_wait.clear()   # the streamer's own per-region retry clock has elapsed
	cm.refresh()
	assert_false(voxel.edited_chunk_keys().has("320,320"), "a settled clean chunk is released without a window move")
	for k in ["cm", "voxel", "terrain", "player"]:
		rig[k].free()

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

func _test_failed_write_reports_and_preserves() -> void:
	# A failed write has to be REPORTED (PersistenceWiring._finish_save is what logs it and
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

## A fault at each write step leaves the full old world (or, with no fault, the full new one).
func _test_p121_fault_at_each_step() -> void:
	var steps := [["backup", 1], ["backup", 3], ["region_rename", 1],
		["region_rename", 2], ["world_tmp", 1], ["world_rename", 1], ["journal", 1]]
	for s in steps:
		var slice := _slice121("test_p121_fault")
		assert_eq(slice.save_world(_world121(1, 2.0), false), OK, "old world saved (%s)" % str(s))
		var old_state := _state121(slice)
		assert_eq(old_state, [1, [2.0, 2.0]], "old world reads back")
		var hits := [0]
		var step: String = s[0]
		var nth: int = s[1]
		slice.fault = func(file_name: String) -> bool:
			if file_name != step:
				return false
			hits[0] += 1
			return hits[0] == nth
		var err := slice.save_world(_world121(2, 3.0), false)
		assert_true(err != OK, "the faulted save reports an error (%s)" % str(s))
		slice.fault = Callable()
		assert_eq(_state121(slice), old_state, "a fault at %s #%d leaves the old world, never a mix" % [step, nth])
		assert_false(FileAccess.file_exists(slice.journal_path()), "no journal is left behind (%s)" % str(s))
		assert_eq(slice.save_world(_world121(2, 3.0), false), OK, "the retry succeeds (%s)" % str(s))
		assert_eq(_state121(slice), [2, [3.0, 3.0]], "and the new world is whole (%s)" % str(s))
		slice.free()

## A region that cannot be staged leaves its file and `world.json` as they were; the other regions land.
func _test_p121_region_stage_fault() -> void:
	var slice := _slice121("test_p121_stage")
	assert_eq(slice.save_world(_world121(1, 2.0), false), OK, "old world")
	slice.fault = func(file_name: String) -> bool: return file_name == "region_tmp"
	assert_true(slice.save_world(_world121(2, 3.0), false) != OK, "the save reports the failure")
	slice.fault = Callable()
	assert_eq(_state121(slice), [1, [2.0, 2.0]], "world.json and the regions are unchanged")
	assert_eq(slice.failed_chunk_keys().size(), 2, "both chunks stay dirty")
	slice.free()

## A crash mid-commit (journal + .bak files on disk) is rolled back on load; a stray .tmp is deleted.
func _test_p121_crash_recovery_and_stray_tmp() -> void:
	var slice := _slice121("test_p121_crash")
	assert_eq(slice.save_world(_world121(1, 2.0), false), OK, "old world")
	var wpath := slice.world_path()
	var rpath := slice.region_store.path_of(Vector2i(0, 0))
	# Simulate a commit killed after world.json went live but before the region did.
	DirAccess.copy_absolute(wpath, wpath + ".bak")
	var f := FileAccess.open(wpath, FileAccess.WRITE)
	f.store_string(JSON.stringify({ "seed": 99, "local_player_id": "p" }))
	f.close()
	var j := FileAccess.open(slice.journal_path(), FileAccess.WRITE)
	j.store_string(JSON.stringify({ "targets": [{ "path": wpath, "had": true }, { "path": rpath, "had": true }] }))
	j.close()
	slice.free()
	var reborn := PersistenceSlice.new()
	add_child(reborn)
	reborn.server_save_dir = "user://saves/test_p121_crash/"
	assert_eq(int(reborn.load_world_record().get("seed", -1)), 1, "the interrupted save is rolled back to the old world")
	assert_false(FileAccess.file_exists(wpath + ".bak") or FileAccess.file_exists(reborn.journal_path()), "journal and backup are gone")
	reborn.free()

	# A region-store commit (own journal in regions/) killed mid-way is rolled back, its .bak not swept.
	var rs := _slice121("test_p121_regionjournal")
	assert_eq(rs.save_world(_world121(1, 2.0), false), OK, "old world")
	var rp := rs.region_store.path_of(Vector2i(0, 0))
	DirAccess.rename_absolute(rp, rp + ".bak")
	var nf := FileAccess.open(rp + ".tmp", FileAccess.WRITE)
	nf.store_string("{}")
	nf.close()
	var rj := FileAccess.open(rs.region_store.journal_path(), FileAccess.WRITE)
	rj.store_string(JSON.stringify({ "targets": [{ "path": rp, "had": true }] }))
	rj.close()
	rs._recovered_dir = ""
	assert_eq(_state121(rs)[1][0], 2.0, "the region store's interrupted commit is rolled back, not swept")
	assert_false(FileAccess.file_exists(rs.region_store.journal_path()), "region journal is gone")
	rs.free()

	var stray := _slice121("test_p121_stray")
	assert_eq(stray.save_world(_world121(5, 2.0), false), OK, "world")
	for p in [stray.world_path() + ".tmp", stray.region_store.path_of(Vector2i(0, 0)) + ".tmp"]:
		var t := FileAccess.open(p, FileAccess.WRITE)
		t.store_string("{ torn")
		t.close()
	stray._recovered_dir = ""
	assert_eq(int(stray.load_world_record().get("seed", -1)), 5, "the real world.json is read, not the stray")
	assert_false(FileAccess.file_exists(stray.world_path() + ".tmp"), "the stray world tmp is deleted")
	assert_false(FileAccess.file_exists(stray.region_store.path_of(Vector2i(0, 0)) + ".tmp"), "the stray region tmp is deleted")
	assert_eq(_state121(stray)[1], [2.0, 2.0], "and the real region still loads")
	stray.free()

## Of three regions one is unreadable: only its chunks stay failed, and world.json is not rewritten.
func _test_p121_one_failing_region_of_three() -> void:
	var slice := _slice121("test_p121_partial")
	var store := slice.region_store
	var e := _op121(2.0)
	assert_eq(slice.save_world({ "seed": 1, "local_player_id": "p", "chunks": { "1,1": e, "40,0": e, "-5,0": e } }, false), OK, "seed save")
	var bad := FileAccess.open(store.path_of(Vector2i(1, 0)), FileAccess.WRITE)
	bad.store_string("{ not json")
	bad.close()
	var err := slice.save_world({ "seed": 2, "local_player_id": "p", "chunks": { "1,1": _op121(3.0), "40,0": _op121(3.0), "-5,0": _op121(3.0) } }, false)
	assert_true(err != OK, "the save reports the failure")
	assert_eq(slice.failed_chunk_keys(), ["40,0"], "only the unreadable region's chunk is left dirty")
	assert_eq(int(slice.load_world_record().get("seed", -1)), 1, "world.json keeps the previous record")
	assert_eq(float(store.load_region(Vector2i(0, 0))["1,1"]["edits"]["0,0"][0]["top"]), 3.0, "the healthy regions were written")
	slice.free()

## One malformed op is dropped alone, the tile's other ops load, and the store warns once.
func _test_p121_malformed_op_dropped_alone() -> void:
	var dir := _fresh_region_dir("test_p121_ops")
	var store := RegionStoreScript.new(dir + "regions/")
	DirAccess.make_dir_recursive_absolute(dir + "regions/")
	var good := { "op": "remove", "bottom": 1.0, "top": 2.0 }
	var ops: Array = [good, { "op": "remove", "bottom": "x", "top": 2.0 }, { "op": "nuke" }, { "op": "deplete", "vein": "v1", "taken": 1.5 },
		{ "op": "add", "bottom": 1.0, "top": 2.0, "material": "stone" }, { "op": "deplete", "vein": "v1", "taken": 2 }]
	var f := FileAccess.open(store.path_of(Vector2i(0, 0)), FileAccess.WRITE)
	f.store_string(JSON.stringify({ "version": 2, "chunks": { "0,0": { "edits": { "3,3": ops } } } }))
	f.close()
	var warns := Diag.warn_count()
	var got: Array = store.load_region(Vector2i(0, 0))["0,0"]["edits"]["3,3"]
	assert_eq(got.size(), 3, "the three valid ops load")
	assert_eq(got[0], good, "in order")
	store.load_region(Vector2i(0, 0))
	assert_eq(Diag.warn_count() - warns, 1, "one warning for the entry, however often it is read")

## Interior chunks read only their own region; a stranded region is retried on a backoff with no window
## move; one sync scans the edited chunks once.
func _test_p121_streamer_scan_and_retry() -> void:
	assert_eq(RegionStreamer121.regions_for_chunks([Vector2i(10, 10), Vector2i(20, 12)], 3, 3).keys(), ["0,0"],
		"a window wholly inside one region returns that region only")
	assert_true(RegionStreamer121.regions_for_chunks([Vector2i(30, 10)], 3, 3).has("1,0"), "an edge chunk still reaches across")
	var dir := _fresh_region_dir("test_p121_streamer")
	var store := RegionStoreScript.new(dir + "regions/")
	var voxel := _Voxel121.new()
	var streamer := RegionStreamer121.new(store, voxel)
	var clock := [0]
	streamer._now = func() -> int: return clock[0]
	streamer.sync({ "0,0": true })
	voxel.keys = ["1,1", "2,2"]
	voxel.dirty = { "2,2": true }
	voxel.scans = 0
	streamer.sync({})
	assert_eq(voxel.scans, 1, "edited_chunk_keys() is scanned once per sync")
	assert_true(streamer.has_stranded(), "a dirty chunk keeps its region stranded")
	voxel.dirty = {}
	assert_eq(streamer.release_stranded(), 0, "a freshly stranded region waits the base backoff")
	clock[0] += RegionStreamer121.STRANDED_RETRY_START_MSEC
	assert_eq(streamer.release_stranded(), 1, "then the retry releases the cleaned chunk")
	assert_false(streamer.has_stranded(), "and the region is no longer stranded")
	voxel.keys = ["1,1"]
	voxel.dirty = { "1,1": true }
	streamer.sync({ "0,0": true })
	streamer.sync({})
	voxel.dirty = {}
	voxel.scans = 0
	assert_eq(streamer.release_stranded(), 0, "inside the backoff nothing is rescanned")
	assert_eq(voxel.scans, 0, "no scan either")
	clock[0] += RegionStreamer121.STRANDED_RETRY_START_MSEC
	assert_eq(streamer.release_stranded(), 1, "after the backoff, with no player movement, the region is released")

## The world stamp survives a save job and a reload: `_collect_save_job` carries `_worldgen_stamp` and the
## fingerprint stamp into the record, the persistence slice writes them, and loading that record raises
## the bus signal for an older generator.
func _test_p121_world_stamp_round_trip() -> void:
	var gr: Node = load("res://src/core/game_root.gd").new()
	var voxel := _make_voxel()
	var slice := _slice121("test_p121_stamp")
	gr._voxel = voxel
	gr._terrain = TerrainSlice.new()
	gr._creature = CreatureSlice.new()
	gr._station = StationSlice.new()
	gr._registry = PlayerRegistry.new()
	gr._persistence = slice
	var older := TerrainSlice.WORLDGEN_VERSION - 1
	gr._loaded_world = { "seed": 7, "worldgenVersion": older, "worldgenFingerprint": 12345 }
	var seen: Array = []
	var cb := func(recorded: int, running: int) -> void: seen.append([recorded, running])
	GameBus.worldgen_version_mismatch.connect(cb)
	gr._persistence_wiring._note_worldgen_version()
	seen.clear()
	var job: Dictionary = gr._persistence_wiring._collect_save_job(false)
	assert_eq(int(job["world"]["worldgenVersion"]), older, "the save job carries the loaded stamp")
	assert_eq(int(job["world"]["worldgenFingerprint"]), TerrainSlice.worldgen_fingerprint(), "and the fingerprint stamp (refreshed to the running one by the single notice, Phase 138)")
	assert_eq(slice.write_job(job), OK, "the job is written")
	var record := slice.load_world_record()
	assert_eq(PersistenceSlice.worldgen_version_of(record), older, "the stamp round-trips through the record")
	gr._loaded_world = record
	gr._persistence_wiring._note_worldgen_version()
	assert_eq(seen, [[older, TerrainSlice.WORLDGEN_VERSION]], "and loading it raises the mismatch signal once")
	GameBus.worldgen_version_mismatch.disconnect(cb)
	for n in [gr._terrain, gr._creature, gr._station]:
		n.free()
	gr._registry.free()
	gr._registry = null
	gr._persistence = null
	slice.free()
	voxel.free()
	gr.free()


# ---------------------------------------------------------------------------
# Phase 124 — research points, and the void-burst leftovers (#299, #300)
# ---------------------------------------------------------------------------
# --- Phase 138 — cleanup sweep ---------------------------------------------------------------

func _test_p138_txn_foreign_journal() -> void:
	var dir := "user://p138_txn"
	DirAccess.make_dir_recursive_absolute(dir)
	for stale in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + stale)
	var target := dir + "/r.json"
	var tmp := target + ".tmp"
	var journal := dir + "/own.journal"
	var other := dir + "/other.journal"
	for pair in [[target, "live"], [target + SaveTxn121.BAK_EXT, "only-old-copy"], [tmp, "new"], [other, "{}"]]:
		var f := FileAccess.open(str(pair[0]), FileAccess.WRITE)
		f.store_string(str(pair[1]))
		f.close()
	var ops := [{ "path": target, "tmp": tmp, "kind": "region" }]
	assert_eq(SaveTxn121.commit(ops, journal, Callable(), [other]), ERR_BUSY, "commit defers while another journal is live")
	assert_eq(FileAccess.get_file_as_string(target + SaveTxn121.BAK_EXT), "only-old-copy", ".bak kept")
	assert_eq(FileAccess.get_file_as_string(target), "live", "target untouched")
	assert_true(FileAccess.file_exists(tmp), "ERR_BUSY keeps the staged tmp for a retry")
	assert_eq(FileAccess.get_file_as_string(tmp), "new", "staged content intact")
	# Without the foreign journal the stale .bak is cleared and the same ops commit.
	DirAccess.remove_absolute(other)
	assert_eq(SaveTxn121.commit(ops, journal, Callable(), [other]), OK, "commit lands once the other journal is gone")
	assert_eq(FileAccess.get_file_as_string(target), "new", "new content live")
	for n in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + n)
	DirAccess.remove_absolute(dir)

func _test_p138_idle_save_ends_streaks() -> void:
	var store = RegionStoreScript.new()
	store.region_failures["0,0"] = 2
	store.end_all_failure_streaks()
	assert_true(store.region_failures.is_empty(), "an idle save clears the streaks")


## Phase 142 — a window move's region reads run on a worker, never the main thread; a chunk whose
## region is still reading waits in the queue and builds once the read has landed.
func _test_region_async_read_off_main() -> void:
	var dir := _fresh_region_dir("test_p142_async")
	var store: RegionStoreScript = RegionStoreScript.new(dir + "regions/")
	var edit := { "edits": { "0,0": [{ "op": "remove", "bottom": 1.0, "top": 1.0 }] } }
	assert_eq(store.save_region(Vector2i.ZERO, { "0,0": edit }), OK, "the origin region is on disk")
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var voxel: VoxelSlice = rig["voxel"]
	var streamer = RegionStreamerScript.new(store, voxel)
	streamer.async_reads = true
	streamer.record_threads = true
	cm.region_streamer = streamer
	cm.view_distance = 0
	cm.prefetch_distance = 0
	cm.refresh()
	assert_eq(voxel.edited_chunk_keys().size(), 0, "the move read nothing inline")
	assert_false(streamer.regions_settled(Vector2i.ZERO, Frontier.BLEND_CHUNKS), "the chunk's region is still reading")
	cm._drain_load_queue()
	assert_false(cm._loaded.has("0,0"), "so the chunk waits in the queue and is not loaded")
	assert_eq(cm._load_queue.size(), 1, "still queued")
	streamer.flush_reads()
	assert_true(voxel.edited_chunk_keys().has("0,0"), "the finished read applies its edits")
	assert_true(streamer.regions_settled(Vector2i.ZERO, Frontier.BLEND_CHUNKS), "and the chunk may build")
	assert_true(streamer.read_thread_ids.size() > 0, "a read ran")
	for tid in streamer.read_thread_ids:
		assert_true(int(tid) != OS.get_main_thread_id(), "and never on the main thread")
	cm._drain_load_queue()
	assert_true(cm._loaded.has("0,0"), "the chunk loads once its region is resident")
	_wait_for_builds(cm)
	cm.free()
	voxel.free()
	rig["terrain"].free()
	rig["player"].free()
