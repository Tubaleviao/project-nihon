extends "res://src/tests/test_support.gd"
## Phase 133 — the terrain tests, moved unchanged from the old single-file suite.


func register() -> void:
	_run_test("spatial: insert + query_radius finds entity",  _test_spatial_query_radius)
	_run_test("spatial: update moves entity across cells",    _test_spatial_update_moves_cell)
	_run_test("spatial: remove drops entity",                 _test_spatial_remove)
	_run_test("spatial: nearest returns closest",             _test_spatial_nearest)
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
	_run_test("polar: ice is streamed to the pole and whitens the ground", _test_polar_ice)
	_run_test("terrain: the distant ring is 10x the window with no collision", _test_distant_ring)
	_run_test("terrain: the ring meets the voxel ground at the window edge", _test_distant_ring_window_edge)
	_run_test("terrain: the distant ring builds off the main thread", _test_distant_ring_async)
	_run_test("terrain: freeing the ring mid-build aborts the worker at the next row", _test_distant_ring_abort)
	_run_test("terrain: a build that is not aborted is unchanged by the abort check", _test_distant_ring_unaborted_same)
	_run_test("terrain: a reparented ring rebuilds to the undisturbed mesh", _test_distant_ring_reparent)
	_run_test("terrain: a rebuild while detached starts exactly one task per request", _test_distant_ring_detached_rebuild)
	_run_test("terrain: a ring reparented with a queued request builds the queued centre", _test_distant_ring_reparent_queued)
	_run_test("terrain: the ring abort path is repeatable without engine errors", _test_distant_ring_abort_loop)
	_run_test("terrain: the distant ring's vertices are pinned by a hash", _test_distant_ring_vertex_hash)
	_run_test("terrain: the ring draws recorded corners exactly", _test_distant_ring_recorded_corners)
	_run_test("terrain: a new record schedules exactly one ring rebuild", _test_distant_ring_record_rebuild)
	_run_test("terrain: freeing a detached or in-tree ring joins its worker", _test_distant_ring_free_joins)
	_run_test("terrain: ring build counters balance across a queued restart", _test_distant_ring_counter_invariant)
	_run_test("terrain: polar caches are warm before the ring's worker runs", _test_distant_ring_warm_caches)
	_run_test("terrain: detail noise has one formula", _test_detail_noise_single_formula)
	_run_test("terrain: walking 5 chunks requests at most 5 ring rebuilds", _test_distant_ring_rebuild_counter)
	_run_test("terrain: concurrent height sampling matches single-threaded", _test_height_concurrent)
	_run_test("terrain: the world wraps east-west",           _test_terrain_wraps_east_west)
	_run_test("terrain: chunk keys are canonical across the seam", _test_chunk_key_canonical_at_seam)
	_run_test("rebase: driver shifts player, tree, creature, station and chunks together", _test_rebase_driver)
	_run_test("terrain: detail noise stays exact far from the origin", _test_far_noise_quantised)
	_run_test("weather: the fabric table and every biome reach a state", _test_weather_fabric_table)
	_run_test("weather: golden values, planet lap and hour buckets",   _test_weather_golden_lap_bucket)
	_run_test("weather: biome limits and weighted shares",             _test_weather_distribution)
	_run_test("weather: outdoor walking speed follows the state",      _test_weather_walking_speed)
	_run_test("weather: /weather overrides, reverts and refuses",      _test_weather_admin_override)
	_run_test("weather: overrides persist, sync and reject forgeries", _test_weather_persistence_and_wire)
	_run_test("terrain: latitude and longitude from the fabric planet", _test_terrain_planet_coordinates)
	_run_test("rebase: loot, avatars and the station preview follow the shift", _test_rebase_extras)
	_run_test("terrain: walking over a pole or round the planet folds the position", _test_globe_fold)
	_run_test("terrain: a fold carries the ground across, unseen", _test_fold_is_seamless)
	_run_test("rebase: TreeSlice shifts its trunks and pool, not other children", _test_tree_shift_explicit_set)
	_run_test("rebase: LootSlice shifts its pickups, survives a freed one", _test_loot_shift_explicit_set)
	_run_test("rebase: a physics-step rebase never jumps the world position", _test_rebase_in_physics_step)
	_run_test("worldgen: fingerprint stable and sensitive",   _test_worldgen_fingerprint)
	_run_test("worldgen: fingerprint stamp on the world record", _test_worldgen_fingerprint_record)
	_run_test("worldgen: fingerprint mismatch wiring",        _test_worldgen_fingerprint_game_root)
	_run_test("worldgen: golden generator values",            _test_worldgen_golden)
	_run_test("worldgen: fingerprint test restores statics",  _test_worldgen_fingerprint_restores)
	_run_test("worldgen: fingerprint notice reaches the UI",  _test_worldgen_fingerprint_notice)
	_run_test("biomes: adjacency table",                      _test_adjacency_table)
	_run_test("biomes: adjacency scan of the generator",      _test_adjacency_scan)
	_run_test("biomes: adjacency scan can fail",              _test_adjacency_scan_detects)
	_run_test("biomes: a coast search that finds none reports it", _test_adjacency_coast_search_reports_failure)
	_run_test("biomes: the coast search finds a one-chunk strip", _test_find_coast_finds_thin_strip)
	_run_test("frontier: recorded chunks unchanged",          _test_frontier_recorded_unchanged)
	_run_test("frontier: seam shares corners, bounded step",  _test_frontier_seam)
	_run_test("frontier: far chunks are the plain generator", _test_frontier_far_is_plain)
	_run_test("frontier: adjacency around a recorded block",  _test_frontier_adjacency)
	_run_test("frontier: two hosts agree",                    _test_frontier_deterministic)
	_run_test("frontier: order-independent field, weight",    _test_frontier_order_and_weight)
	_run_test("seam wrap: one module, no copies", _test_p126_seam_wrap_module)
	_run_test("rebase: an unshiftable target is reported",      _test_rebase_driver_reports_unshiftable)
	_run_test("far origin: exact AOI, south fold row, ore warm retry", _test_phase122_exact_positions)
	_run_test("far origin: bad snapshot position spawns, registry clamps local", _test_phase122_snapshot_fallback_and_clamp)
	_run_test("rebase: one SceneOffset helper, whole-chunk shifts only", _test_scene_shift_helper)
	_run_test("climate: partial envelope does not break warm()", _test_climate_partial_envelope_warms)
	_run_test("climate: 3x3 search is exact at the jitter bound", _test_climate_search_window_exact)
	_run_test("terrain: neighbouring chunks mostly share a biome", _test_biome_regions_coherent)
	_run_test("climate: fabric envelopes select the biome",     _test_climate_envelope_selects)
	_run_test("clock: hemispheres are opposite",                 _test_clock_hemispheres_opposite)
	_run_test("clock: day length varies by latitude",            _test_clock_day_length_by_latitude)
	_run_test("clock: sun follows the hour and the season",      _test_clock_sun_elevation)
	_run_test("clock: seasonal temperature, tint and snow",      _test_clock_season_effects)
	_run_test("clock: sun follows the biome's dayNightSpeed",    _test_clock_sun_biome_daylight)
	_run_test("clock: season tint is per chunk biome",           _test_clock_season_tint_per_chunk)
	_run_test("clock: client stays within 1 s over 10 minutes",  _test_clock_client_sync)
	_run_test("clock: persistence, HUD text and fabric values",  _test_clock_persistence_and_fabric)
	_run_test("ore: the band table is prebuilt",               _test_voxel_biome_roll_table_prebuilt)
	_run_test("ore: every canonical biome has a bias",          _test_voxel_every_canonical_biome_has_a_roll_table)
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

func _test_polar_ice() -> void:
	var t := TerrainSlice.new()
	var polar := TerrainSlice.polar_chunks()
	var pole := TerrainSlice.pole_chunks()
	assert_true(t.is_chunk_in_bounds(Vector2i(0, polar)), "polar ice is walkable")
	assert_false(t.is_chunk_in_bounds(Vector2i(0, pole + TerrainSlice.FOLD_MARGIN_CHUNKS)), "the walkable bound ends at the fold slack; streaming is not bounded")
	# Near a pole the ground is the pole's snow field: flat (any relief would run along X as ridges,
	# drawn as lines to the horizon), so the same on both sides of a fold.
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
	assert_eq(seen.keys(), [snappedf(TerrainSlice.pole_field(), 0.01)], "the snow field is one flat sheet")
	for row in [pole - 1, -pole]:
		var b := TerrainSlice.generated_biome_for_chunk(Vector2i(0, row), 12345)
		assert_true(b != "Beach" and b != "Ocean", "the snow field sits above the beach band (row %d: %s)" % [row, b])
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
	var snapped_pos := Vector2(float(origin.x) * cell, float(origin.y) * cell)
	var sync_mesh: ArrayMesh = DistantTerrainScript.build_mesh(11, d.circumference_m, snapped_pos, d.ring_half_m, d.window_half_m, Vector2(112.0, -48.0))   # the chunk-snapped window centre
	var got: ArrayMesh = (d.get_child(0) as MeshInstance3D).mesh
	assert_eq(got.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], sync_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], "the async mesh equals a synchronous build")
	# A request that arrives mid-build supersedes it; the newest wins.
	assert_true(d.rebuild(Vector2(5000.0, 5000.0), radius), "a far move starts a build")
	assert_true(d.rebuild(Vector2(-9000.0, 3000.0), radius), "a second far move queues behind it")
	d.poll(true)
	assert_false(d.is_building(), "everything drains")
	assert_false(d.rebuild(Vector2(-9000.0, 3000.0), radius), "the newest centre is the one built")
	d.free()

## Phase 83 — leaving the tree mid-build raises the abort flag; the worker stops within one more row
## and the freed node never applies a result.
func _test_distant_ring_abort() -> void:
	var d := DistantTerrainScript.new()
	add_child(d)
	d.world_seed = 11
	d.rebuild(Vector2(100.0, -40.0), 3)
	var control = d._control
	assert_true(control != null, "the build has a control block")
	d.free()   # an in-tree ring: `_exit_tree` raises the flag and joins the worker
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

## Phase 120 — a recorded chunk whose corners differ from the generator by 10 m is drawn at its recorded
## corners; its unrecorded neighbour stays on the plain generator.
func _test_distant_ring_recorded_corners() -> void:
	ChunkRecordsScript.clear()
	var seed_v := 5
	var c := Vector2i(40, 12)
	var rec := TerrainSlice.generation_record(c, seed_v)
	var hs: Array = rec["h"]
	for i in 4:
		hs[i] = clampf(float(hs[i]) + 10.0, WorldShape.min_height() + 1.0, WorldShape.max_height() - 1.0)
	rec["h"] = hs
	rec = RegionStoreScript.normalize_gen(rec)
	assert_false(rec.is_empty(), "the shifted record is valid")
	ChunkRecordsScript.set_record(c, rec)
	var w := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	var snap := ChunkRecordsScript.snapshot_near(c, 4, TerrainSlice.circumference_chunks())
	assert_eq(snap.size(), 1, "the snapshot holds the one record")
	var x := float(c.x) * 32.0
	var z := float(c.y) * 32.0
	assert_eq(TerrainSlice.shape_height_in(snap, seed_v, x, z, w), float(rec["h"][0]), "the ring's shape at the recorded corner is the recorded corner exactly")
	var noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(noise, seed_v)
	var ring_h := DistantTerrainScript.ground_at(noise, seed_v, x, z, w, snap)
	var expect := TerrainSlice.polar_ground(seed_v, clampf(float(rec["h"][0]) + TerrainSlice.detail_of(noise, x, z), WorldShape.min_height(), WorldShape.max_height()), x, z, w)
	assert_eq(ring_h, expect, "the ring's ground there is the recorded corner plus detail")
	var gen_h := DistantTerrainScript.ground_at(noise, seed_v, x, z, w)
	assert_true(absf(ring_h - gen_h) > 5.0, "and differs from the plain generator")
	var nx := float(c.x + 1) * 32.0 + 3.0
	assert_eq(TerrainSlice.shape_height_in(snap, seed_v, nx, z, w), WorldShape.height(seed_v, nx, z, w), "an unrecorded neighbour equals the plain generator")
	assert_eq(DistantTerrainScript.ground_at(noise, seed_v, nx, z, w, snap), DistantTerrainScript.ground_at(noise, seed_v, nx, z, w), "its ring ground is the plain generator's too")
	ChunkRecordsScript.set_record(c, RegionStoreScript.normalize_gen(TerrainSlice.generation_record(c, seed_v)))   # the snapshot is a copy
	assert_eq(TerrainSlice.shape_height_in(snap, seed_v, x, z, w), float(rec["h"][0]), "a later table change never reaches the snapshot")
	ChunkRecordsScript.clear()
	# A recorded chunk west of the origin (canonical negative x) is found by both snapshot branches.
	var cn := Vector2i(-40, 12)
	ChunkRecordsScript.set_record(cn, RegionStoreScript.normalize_gen(TerrainSlice.generation_record(cn, seed_v)))
	var circ := TerrainSlice.circumference_chunks()
	assert_true(ChunkRecordsScript.snapshot_near(cn, 0, circ).has(cn), "a negative-x record is in the window-scan snapshot")
	assert_true(ChunkRecordsScript.snapshot_near(cn, 4, circ).has(cn), "and in the table-scan snapshot")
	assert_true(ChunkRecordsScript.snapshot_near(Vector2i(-38, 12), 0, circ).has(cn) == false, "outside the radius it is left out")
	ChunkRecordsScript.clear()

## Phase 120 — adding a record inside the ring after a build schedules exactly one rebuild.
func _test_distant_ring_record_rebuild() -> void:
	ChunkRecordsScript.clear()
	var d := DistantTerrainScript.new()
	add_child(d)
	d.world_seed = 5
	d.record_debounce_ms = 0
	d.rebuild(Vector2(16.0, 16.0), 2)
	d.poll(true)
	assert_false(d.rebuild(Vector2(16.0, 16.0), 2), "no change, no rebuild")
	var base := d.rebuilds_requested
	ChunkRecordsScript.set_record(Vector2i(3, 1), RegionStoreScript.normalize_gen(TerrainSlice.generation_record(Vector2i(3, 1), 5)))
	assert_true(d.rebuild(Vector2(16.0, 16.0), 2), "a new record asks for a rebuild")
	assert_false(d.rebuild(Vector2(16.0, 16.0), 2), "and only one")
	d.poll(true)
	assert_false(d.rebuild(Vector2(16.0, 16.0), 2), "still only one after it lands")
	assert_eq(d.rebuilds_requested - base, 1, "exactly one rebuild was scheduled")
	var debounced := DistantTerrainScript.new()
	add_child(debounced)
	debounced.world_seed = 5
	debounced.rebuild(Vector2(16.0, 16.0), 2)
	debounced.poll(true)
	ChunkRecordsScript.set_record(Vector2i(4, 1), RegionStoreScript.normalize_gen(TerrainSlice.generation_record(Vector2i(4, 1), 5)))
	assert_false(debounced.rebuild(Vector2(16.0, 16.0), 2), "a records-only change right after a build is debounced")
	d.free()
	debounced.free()
	ChunkRecordsScript.clear()

## Phase 120 — a worker started while detached is joined when the ring is freed; so is an in-tree one,
## within the abort bound.
func _test_distant_ring_free_joins() -> void:
	var d := DistantTerrainScript.new()   # never in the tree
	d.world_seed = 11
	d.rebuild(Vector2(100.0, -40.0), 3)
	assert_true(d.is_building(), "a detached ring started a worker")
	var control = d._control
	d.free()
	assert_true(control.aborted, "freeing it raised the abort flag (and joined the worker)")
	var t := DistantTerrainScript.new()
	add_child(t)
	t.world_seed = 12
	t.rebuild(Vector2(100.0, -40.0), 3)
	var start := Time.get_ticks_msec()
	t.free()
	assert_true(Time.get_ticks_msec() - start < 3000, "freeing an in-tree ring mid-build does not stall")

## Phase 120 — `builds_started == rebuilds_requested - rebuilds_dropped + restarts` across a queued restart,
## and the script keeps no static counter.
func _test_distant_ring_counter_invariant() -> void:
	var d := DistantTerrainScript.new()
	add_child(d)
	d.world_seed = 11
	d.rebuild(Vector2(100.0, -40.0), 2)
	d.rebuild(Vector2(1500.0, 900.0), 2)
	d.rebuild(Vector2(2500.0, 900.0), 2)   # replaces the queued one
	d.poll(true)
	assert_eq(d.builds_started, d.rebuilds_requested - d.rebuilds_dropped + d.restarts, "the counters balance")
	assert_eq(d.restarts, 1, "the queued request's start was a restart")
	var e := DistantTerrainScript.new()
	add_child(e)
	e.world_seed = 11
	e.rebuild(Vector2(100.0, -40.0), 2)
	remove_child(e)
	add_child(e)
	e.poll(true)
	assert_eq(e.builds_started, e.rebuilds_requested - e.rebuilds_dropped + e.restarts, "and across a reparent")
	var g := DistantTerrainScript.new()
	add_child(g)
	g.world_seed = 11
	g.rebuild(Vector2(100.0, -40.0), 2)
	g.rebuild(Vector2(1500.0, 900.0), 2)   # queued behind the running build
	remove_child(g)   # the running one is aborted, the queued one is set aside
	add_child(g)
	g.poll(true)
	g.poll(true)
	assert_eq(g.builds_started, g.rebuilds_requested - g.rebuilds_dropped + g.restarts, "and across a reparent with a queued request")
	d.free()
	e.free()
	g.free()
	var f := FileAccess.open("res://src/terrain/distant_terrain.gd", FileAccess.READ)
	assert_false(f.get_as_text().contains("static var "), "distant_terrain.gd has no static variable")

## Phase 120 — the polar caches are filled on the main thread by `rebuild`, never first on a worker.
func _test_distant_ring_warm_caches() -> void:
	TerrainSlice._circumference_cache = -1
	TerrainSlice._polar_cache = -1
	TerrainSlice.worker_cache_fills = 0
	var d := DistantTerrainScript.new()
	add_child(d)
	d.world_seed = 5
	d.rebuild(Vector2(16.0, 16.0), 2)
	assert_true(TerrainSlice._circumference_cache > 0 and TerrainSlice._polar_cache > 0, "rebuild filled both caches before the worker ran")
	d.poll(true)
	assert_eq(TerrainSlice.worker_cache_fills, 0, "no worker-side fill happened")
	d.free()

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

## Phase 50 — the world is a planet: X wraps, so the last chunk column meets the first with no
## seam wall; Z is latitude and ends in polar ice.
func _test_terrain_wraps_east_west() -> void:
	var t := TerrainSlice.new()
	add_child(t)
	t.set_world_seed(77)
	var c := TerrainSlice.circumference_chunks()
	assert_eq(c, 1250000, "40,000 km around is 1.25M chunks")
	@warning_ignore("integer_division")
	var last := TerrainSlice.wrap_chunk(Vector2i(c / 2 - 1, 3))
	@warning_ignore("integer_division")
	var first := TerrainSlice.wrap_chunk(Vector2i(c / 2, 3))
	@warning_ignore("integer_division")
	assert_eq(first, Vector2i(-c / 2, 3), "one past the east edge is the west edge")
	@warning_ignore("integer_division")
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
	@warning_ignore("integer_division")
	assert_eq(t.generate_heightmap(Vector2i(c / 2, 3)), west, "a chunk past the edge is the wrapped chunk")
	t.free()

func _test_chunk_key_canonical_at_seam() -> void:
	var c := TerrainSlice.circumference_chunks()
	var voxel := VoxelSlice.new()
	@warning_ignore("integer_division")
	assert_eq(VoxelSlice._chunk_key(Vector2i(c / 2, 4)), VoxelSlice._chunk_key(Vector2i(-c / 2, 4)),
		"VoxelSlice keys chunk (C/2, z) and (-C/2, z) as one chunk")
	assert_eq(VoxelSlice._chunk_key(Vector2i(7, -2)), "7,-2", "an interior key is unchanged")
	@warning_ignore("integer_division")
	var east_tile := Vector2i(c / 2 * TerrainSlice.CHUNK_SIZE + 3, 70)
	@warning_ignore("integer_division")
	var west_tile := Vector2i(-c / 2 * TerrainSlice.CHUNK_SIZE + 3, 70)
	assert_eq(VoxelSlice._tile_key(east_tile), VoxelSlice._tile_key(west_tile),
		"a tile east of the seam is the same edit key as the tile west of it")
	voxel._set_edit_ops(VoxelSlice._tile_key(east_tile), [{ "op": "remove", "bottom": 1.0, "top": 1.0 }])
	@warning_ignore("integer_division")
	assert_true(voxel.edited_chunk_keys().has(VoxelSlice._chunk_key(Vector2i(-c / 2, 1))),
		"an edit made at chunk (C/2, z) is found when reading chunk (-C/2, z)")
	var cm := ChunkManager.new()
	@warning_ignore("integer_division")
	assert_eq(cm._chunk_key(Vector2i(c / 2, 4)), cm._chunk_key(Vector2i(-c / 2, 4)),
		"ChunkManager keys both sides of the seam as one chunk")
	cm.free()
	voxel.free()

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
	var span := TerrainSlice.NOISE_SPAN
	# Inside the origin cell, away from its borders, the coordinate is untouched.
	assert_eq(TerrainSlice.cell_offset(1234, 0, 0), Vector2.ZERO, "the origin cell has no offset")
	assert_true(TerrainSlice.cell_offset(1234, 1, 0) != Vector2.ZERO, "a far cell has an offset")
	assert_eq(TerrainSlice.cell_offset(1234, 3, -2), TerrainSlice.cell_offset(1234, 3, -2), "the offset is pure")
	for off in [TerrainSlice.cell_offset(1234, 1, 0), TerrainSlice.cell_offset(-99, -4, 7)]:
		assert_true(absf(off.x) <= TerrainSlice.NOISE_OFFSET_RANGE and absf(off.y) <= TerrainSlice.NOISE_OFFSET_RANGE, "the offset is bounded")
		assert_eq(off.x, snappedf(off.x, 0.125), "and exact to the 0.125 step")
	var ref := FastNoiseLite.new()
	TerrainSlice.configure_noise(ref, 1234)
	assert_eq(t.detail_at(123.5, -8000.25), (ref.get_noise_2d(123.5, -8000.25) + 1.0) * 0.5 * TerrainSlice.HEIGHT_SCALE, "ground near the origin is the plain noise")
	# No mirror: x and 2·NOISE_SPAN − x differ for 1,000 points beyond the span.
	var differ := 0
	for i in range(1000):
		var x := span + 1000.0 + float(i) * 37.25
		var z := 77.5 + float(i) * 11.0
		if absf(t.detail_at(x, z) - t.detail_at(2.0 * span - x, z)) > 1e-6:
			differ += 1
	assert_eq(differ, 1000, "detail noise does not mirror beyond the span")
	# Far tiles still step smoothly (no terracing from float32).
	var far_x := 312500.0 * TerrainSlice.CHUNK_METERS
	var prev := -1.0
	var distinct := 0
	for i in range(64):
		var d := t.detail_at(far_x + float(i) * TerrainSlice.TILE_SIZE, 77.5)
		if absf(d - prev) > 0.0:
			distinct += 1
		assert_true(prev < 0.0 or absf(d - prev) < 1.0, "adjacent tiles differ by terrain slope, not a rounding jump")
		prev = d
	assert_eq(distinct, 64, "no terracing: every tile steps to a new value")
	# Continuous across cell borders on both axes: the largest step stays at slope scale.
	var worst := 0.0
	for border in [span, 3.0 * span, -span]:
		for k in range(-80, 80):
			var x0: float = border + float(k) * 0.125
			worst = maxf(worst, absf(t.detail_at(x0, 5.0) - t.detail_at(x0 + 0.125, 5.0)))
			worst = maxf(worst, absf(t.detail_at(5.0, x0) - t.detail_at(5.0, x0 + 0.125)))
			worst = maxf(worst, absf(t.detail_at(x0, x0) - t.detail_at(x0 + 0.125, x0 + 0.125)))
	assert_true(worst < 0.5, "the field is continuous across a cell border (max step %.4f)" % worst)
	t.free()

func _test_weather_fabric_table() -> void:
	var w := _weather_rig()
	var rules := w.rules()
	assert_true(rules["states"].has("clear") and rules["states"].has("storm") and rules["states"].has("void_storm"), "the table names the states")
	for id in w.state_ids():
		assert_true(w.move_factor(id) >= 0.0 and w.move_factor(id) <= 1.0, "%s moveSpeedFactor is in 0..1" % id)
		assert_true(w.visibility_factor(id) >= 0.0 and w.visibility_factor(id) <= 1.0, "%s visibilityFactor is in 0..1" % id)
	assert_eq(w.move_factor("storm"), 0.7, "a storm slows walking by 30 percent (the fabric rule)")
	for biome in GameData.BIOMES:
		var c := w.climate_of(biome)
		var reached := false
		for t in [c["temperature"] - c["swing"], c["temperature"], c["temperature"] + c["swing"]]:
			if not w.allowed_states(biome, t).is_empty():
				reached = true
		assert_true(reached, "%s reaches at least one weather state" % biome)
	assert_eq(w.move_factor("no_such_state"), 1.0, "an unknown state does not slow anyone")
	w.free()

func _test_weather_golden_lap_bucket() -> void:
	var w := _weather_rig()
	# The integer mix is pinned: a changed constant would re-roll every world's weather.
	assert_eq(WeatherSlice.mix(424242, 3, -2, 17), WEATHER_GOLDEN_MIX, "the integer mix matches its golden value")
	var cases: Array = [[Vector2i(0, 0), 0], [Vector2i(130, -70), 6], [Vector2i(-500, 900), 100], [Vector2i(12345, 77), 4000], [Vector2i(999, 3), 123456]]
	for i in cases.size():
		assert_eq(w.weather_at(cases[i][0], cases[i][1]), WEATHER_GOLDEN_STATES[i], "golden weather #%d" % i)
	var lap := TerrainSlice.circumference_chunks()
	for c in cases:
		assert_eq(w.weather_at(Vector2i(c[0].x + lap, c[0].y), c[1]), w.weather_at(c[0], c[1]), "one planet lap along is the same weather")
		assert_eq(w.weather_at(Vector2i(c[0].x - lap, c[0].y), c[1]), w.weather_at(c[0], c[1]), "and one lap back")
	var per := w.hours_per_roll()
	for bucket in [0, 3, 41]:
		var first := w.weather_at(Vector2i(10, 10), bucket * per)
		for h in per:
			assert_eq(w.weather_at(Vector2i(10, 10), bucket * per + h), first, "constant within one hoursPerRoll bucket")
	var seen := {}
	for b in 200:
		seen[w.weather_at(Vector2i(10, 10), b * per)] = true
	assert_true(seen.size() > 1, "and it changes between buckets")
	w.free()

func _test_weather_distribution() -> void:
	const N := 10000
	var w := _weather_rig("Desert")
	var seen := {}
	var expect := {}
	for i in N:
		@warning_ignore("integer_division")
		var chunk := Vector2i((i % 100) * 64 + 1, (i / 100 - 50) * 64)
		var hour := i * 5
		var state := w.weather_at(chunk, hour)
		seen[state] = int(seen.get(state, 0)) + 1
		var biome := "Desert"
		var cell_chunk := w.cell_center(w.cell_of(chunk))
		var allowed := w.allowed_states(biome, w.temperature_at(biome, TerrainSlice.latitude_of(cell_chunk.y), hour))
		var total := 0.0
		for id in allowed:
			total += float(w._state(id)["weight"])
		for id in allowed:
			expect[id] = float(expect.get(id, 0.0)) + float(w._state(id)["weight"]) / total
	assert_false(seen.has("blizzard"), "a desert cell never rolls a blizzard")
	for id in expect:
		assert_true(absf(float(seen.get(id, 0)) / N - float(expect[id]) / N) <= 0.05, "desert %s share is within 5 points of its weight" % id)
	w.free()
	var v := _weather_rig("VoidRift")
	seen.clear()
	expect.clear()
	for i in N:
		@warning_ignore("integer_division")
		var chunk := Vector2i((i % 100) * 64 + 1, (i / 100 - 50) * 64)
		var hour := i * 5
		var state := v.weather_at(chunk, hour)
		seen[state] = int(seen.get(state, 0)) + 1
		var allowed := v.allowed_states("VoidRift", 10.0)
		var total := 0.0
		for id in allowed:
			total += float(v._state(id)["weight"])
		for id in allowed:
			expect[id] = float(expect.get(id, 0.0)) + float(v._state(id)["weight"]) / total
	for id in seen:
		assert_true(id == "void_storm" or id == "clear", "a VoidRift cell rolls only void_storm or clear (%s)" % id)
	for id in expect:
		assert_true(absf(float(seen.get(id, 0)) - float(expect[id])) / N <= 0.05, "VoidRift %s share is within 5 points of its weight" % id)
	v.free()
	# A cold cell can blizzard and a hot one cannot: the season moves the allowed set.
	var t := _weather_rig("Tundra")
	assert_true("blizzard" in t.allowed_states("Tundra", -20.0), "a freezing tundra allows blizzards")
	assert_false("rain" in t.allowed_states("Tundra", -20.0), "and no rain")
	t.free()

func _test_weather_walking_speed() -> void:
	var w := _weather_rig()
	var storm: float = w.move_factor("storm")
	assert_eq(PlayerSlice.walking_speed(false, storm), PlayerSlice.SPEED * storm, "outdoors in a storm: SPEED x moveSpeedFactor")
	assert_eq(PlayerSlice.walking_speed(true, storm), PlayerSlice.SPEED * PlayerSlice.SWIM_SPEED_FACTOR, "swimming speed is unchanged by the weather")
	assert_eq(PlayerSlice.walking_speed(false, 1.0), PlayerSlice.SPEED, "clear weather walks at full speed")
	var roof := [{ "bottom": 0.0, "top": 10.0, "material": "Soil" }, { "bottom": 12.0, "top": 13.0, "material": "Thornwood" }]
	assert_true(PlayerSlice.roof_overhead(roof, 10.0), "a span 2 m above the head shelters")
	assert_false(PlayerSlice.roof_overhead([roof[0]], 10.0), "open sky does not")
	assert_false(PlayerSlice.roof_overhead([{ "bottom": 30.0, "top": 31.0 }], 10.0), "a span far overhead does not")
	# The body reads it end to end: a storm override on its cell, then a roof span.
	var body := PlayerSlice.new()
	body.render_visuals = false
	body.weather_slice = w
	add_child(body)
	w.set_override(w.cell_of(Vector2i.ZERO), "storm", 2)
	assert_eq(body._weather_factor_now(), storm, "the body is slowed by the storm on its cell")
	body.weather_slice = null
	assert_eq(body._weather_factor_now(), 1.0, "a rig with no weather is not slowed")
	body.free()
	w.free()

func _test_weather_admin_override() -> void:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("player_host_1")
	var body := PlayerSlice.new()
	body.render_visuals = false
	add_child(body)
	var w := _weather_rig()
	var chat := ChatSlice.new()
	chat.render_visuals = false
	chat.admins_path = "user://does_not_exist_admins.json"
	chat.player_registry = reg
	chat.player_slice = body
	chat.weather_slice = w
	add_child(chat)
	var ticks := [0.0]
	chat.set_clock(func() -> float:
		ticks[0] += 10.0
		return ticks[0])
	var posted: Array = []
	var cb := func(channel: String, _sender: String, text: String, target: String) -> void:
		posted.append({ "channel": channel, "text": text, "target": target })
	GameBus.chat_posted.connect(cb)
	var sysb_22029 := _p131_system_bridge(cb)
	var synced: Array = []
	var sync_cb := func(o: Array) -> void: synced.append(o)
	GameBus.weather_overrides_synced.connect(sync_cb)
	var here := body.get_world_pos()["chunk"] as Vector2i
	var rolled := w.weather_at(here, w.current_hour())
	var want := "storm" if rolled != "storm" else "fog"
	chat.handle_intent("/weather %s 2" % want, "")
	assert_eq(w.weather_at(here, w.current_hour()), want, "the admin's cell takes the state")
	assert_eq(synced.size(), 1, "and the change is announced for the wire")
	assert_eq(w.weather_at(here, w.current_hour() + 1), want, "still there an hour later")
	assert_eq(w.weather_at(here, w.current_hour() + 2), w.rolled_state(w.cell_of(here), w.current_hour() + 2), "and reverts to the rolled weather after two hours")
	w.clock.time_days += 2.0 / 24.0 + 0.001
	w.tick()
	assert_eq(w.override_count(), 0, "an expired override is dropped on the host's tick")
	assert_eq(synced.size(), 2, "and clients are told")
	posted.clear()
	chat.handle_intent("/weather storm %d" % (w.override_max_hours() + 1), "")
	assert_eq(w.override_count(), 0, "a duration above overrideMaxHours is refused")
	assert_true(posted.any(func(m): return "At most" in str(m["text"])), "with a reason")
	chat.handle_intent("/weather hurricane 2", "")
	assert_eq(w.override_count(), 0, "an unknown state is refused")
	chat.handle_intent("/weather storm 0", "")
	chat.handle_intent("/weather storm", "")
	chat.handle_intent("/weather storm two", "")
	assert_eq(w.override_count(), 0, "bad hours and missing arguments are refused")
	posted.clear()
	chat.handle_intent("/weather storm 2", "player_other")
	assert_eq(w.override_count(), 0, "a non-admin sender is refused")
	assert_true(posted.any(func(m): return "for admins" in str(m["text"])), "and told why")
	GameBus.weather_overrides_synced.disconnect(sync_cb)
	GameBus.chat_posted.disconnect(cb)
	GameBus.system_message.disconnect(sysb_22029)
	chat.free()
	w.free()
	body.free()
	reg.free()

func _test_weather_persistence_and_wire() -> void:
	var w := _weather_rig()
	assert_eq(w.set_override(Vector2i(2, 3), "blizzard", 5), "", "an override is set")
	assert_eq(w.set_override(Vector2i(2, 3), "nope", 5), "unknown_state", "unknown state")
	assert_eq(w.set_override(Vector2i(2, 3), "storm", 0), "bad_hours", "zero hours")
	assert_eq(w.set_override(Vector2i(2, 3), "storm", 99999), "too_long", "too long")
	assert_eq(w.set_override(Vector2i(-1, 3), "storm", 1), "bad_cell", "an X cell off the planet")
	var past_x := w.cell_of(Vector2i(TerrainSlice.circumference_chunks() - 1, 0)).x + 1
	assert_eq(w.set_override(Vector2i(past_x, 3), "storm", 1), "bad_cell", "the first X cell past one lap")
	assert_eq(w.set_override(Vector2i(0, 1 << 30), "storm", 1), "bad_cell", "a Y cell far off the planet")
	var saved := w.to_data()
	var json: Variant = JSON.parse_string(JSON.stringify(saved))
	var back := _weather_rig()
	back.from_data(json)
	assert_eq(back.to_data(), saved, "the table survives a save/load through JSON")
	assert_eq(back.weather_at(back.cell_center(Vector2i(2, 3)), 0), "blizzard", "and still applies")
	back.apply_view([[1, 1, "storm", 10], [1], "junk", [1, 1, "volcano", 10], [1, 1, 5, 10], [0.0, 2.0, "fog", 3]])
	assert_eq(back.override_count(), 2, "a client keeps the well-formed entries only")
	back.apply_view([[1, 1, "storm", 10], [1, 2, "storm", 0], [1, 3, "storm", 100000], [-1, 1, "storm", 10], [1, 1 << 30, "storm", 10]])
	assert_eq(back.override_count(), 1, "an expired, over-long or off-planet entry is dropped on load")
	back.apply_view("nonsense")
	assert_eq(back.override_count(), 0, "a non-list clears the table")
	var big: Array = []
	for i in WeatherSlice.MAX_OVERRIDES + 50:
		big.append([i, 0, "fog", 10 + i % 30])
	back.apply_view(big)
	assert_eq(back.override_count(), WeatherSlice.MAX_OVERRIDES, "a forged table is bounded")
	var full_cell := Vector2i(0, 1)
	assert_eq(back.set_override(full_cell, "storm", 1), "", "a full table still takes a short override")
	assert_eq(back.weather_at(back.cell_center(full_cell), back.current_hour()), "storm", "and the new override is not the one evicted")
	assert_eq(back.override_count(), WeatherSlice.MAX_OVERRIDES, "at the cap")
	# update_local reports a change once.
	var changes: Array = []
	var cb := func(state: String) -> void: changes.append(state)
	GameBus.weather_changed.connect(cb)
	back.apply_view([])
	back.update_local(Vector2i(5, 5))
	back.update_local(Vector2i(5, 5))
	assert_eq(changes.size(), 1, "weather_changed fires when the state changes, not every call")
	GameBus.weather_changed.disconnect(cb)
	back.free()
	w.free()

# ---------------------------------------------------------------------------
# Phase 129 — combat status effects
# ---------------------------------------------------------------------------

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
	assert_eq(TerrainSlice.where_text(Vector3(0.0, 4.2, 0.0)), "X 0  Y 0  alt 4 m", "where: the origin")
	assert_eq(TerrainSlice.where_text(Vector3(-0.4, 0.0, 0.0)), "X 0  Y 0  alt 0 m", "where: under half a metre west rounds to X 0")
	assert_true(PlayerRegistry.world_pos_of({"chunk": [0, TerrainSlice.pole_chunks()], "local": [0.0, 0.0, 1.0e6]})["chunk"].y <= TerrainSlice.pole_chunks(), "world_pos_of: a huge local cannot push the chunk past the pole")
	assert_eq(TerrainSlice.where_text(Vector3(-3200.0, 0.0, 3200.0)), "X -3200  Y 3200  alt 0 m", "where: west and south of the origin are negative/positive")
	# Position quantiser at a far chunk: a tile offset is exact in double precision, so a
	# 0.125 step is the same 0.125 at chunk 600,000 as at the origin.
	var far := Vector2i(600000, 0)
	var origin_x := t.chunk_to_world(far).x
	assert_eq((origin_x + 0.125) - origin_x, 0.125, "0.125 step survives at 19,200 km")
	t.free()

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

## Phase 91 — the planet is a globe: every direction leads round it.
func _test_globe_fold() -> void:
	var c := TerrainSlice.circumference_chunks()
	var pole := TerrainSlice.pole_chunks()
	var m := TerrainSlice.FOLD_MARGIN_CHUNKS
	var cm := TerrainSlice.CHUNK_METERS
	# Inside the slack nothing moves: pacing over a line costs no fold.
	@warning_ignore("integer_division")
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
	@warning_ignore("integer_division")
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
	@warning_ignore("integer_division")
	var east := TerrainSlice.fold_world_pos({"chunk": Vector2i(c / 2 + m, 7), "local": Vector3(1.0, 0.0, 2.0)})
	assert_true(east["folded"] and not east["turned"], "past the seam the position folds without a turn")
	@warning_ignore("integer_division")
	assert_eq(east["pos"]["chunk"], Vector2i(-c / 2 + m, 7), "one lap west")
	@warning_ignore("integer_division")
	var west := TerrainSlice.fold_world_pos({"chunk": Vector2i(-c / 2 - m - 1, 7), "local": Vector3(1.0, 0.0, 2.0)})
	@warning_ignore("integer_division")
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
	@warning_ignore("integer_division")
	assert_eq(saved["chunk"].x, 4 - c / 2, "half a lap round")

## Phase 120 — a fold is not seen: the scene carried by `fold_scene_transform` shows, at every point
## around the player, the ground the folded frame has there; the voxel chunks stand in until rebuilt.
func _test_fold_is_seamless() -> void:
	var c := TerrainSlice.circumference_chunks()
	var pole := TerrainSlice.pole_chunks()
	var m := TerrainSlice.FOLD_MARGIN_CHUNKS
	var cm := TerrainSlice.CHUNK_METERS
	var t := TerrainSlice.new()
	t.set_world_seed(12345)
	@warning_ignore("integer_division")
	for case in [[Vector2i(10, pole + m), Vector3(5.25, 7.0, 4.0), "the +Z pole"], [Vector2i(-3, -pole - m - 1), Vector3(30.5, 7.0, 1.0), "the -Z pole"], [Vector2i(c / 2 + m, 7), Vector3(2.0, 7.0, 2.0), "the antimeridian"]]:
		var wp := {"chunk": case[0], "local": case[1]}
		var fold := TerrainSlice.fold_world_pos(wp)
		assert_true(fold["folded"], "%s folds" % case[2])
		var np: Dictionary = fold["pos"]
		# The scene origin sits on the player's chunk before the fold and on the folded chunk after it.
		var old_origin: Vector2i = wp["chunk"]
		var new_origin: Vector2i = np["chunk"]
		var before := WorldPos.to_scene(wp, old_origin)
		var after := WorldPos.to_scene(np, new_origin)
		var xf := TerrainSlice.fold_scene_transform(before, after, fold["turned"])
		var moved := xf * before - after
		assert_true(absf(moved.z) < 0.001 and absf(moved.x) <= cm * 0.5 + 0.001 and absf(moved.y) < 0.001,
			"%s: the ground under the player moves at most half a chunk along its row" % case[2])
		var worst := 0.0
		# Whole-metre steps: `get_height_at` takes a float32 Vector2, exact to the metre (2 m at the seam) here.
		for dz in range(-600, 601, 50):
			for dx in range(-600, 601, 50):
				var s := before + Vector3(float(dx), 0.0, float(dz))
				var old_world := Vector2(float(s.x) + float(old_origin.x) * cm, float(s.z) + float(old_origin.y) * cm)
				var carried := xf * s
				var new_world := Vector2(float(carried.x) + float(new_origin.x) * cm, float(carried.z) + float(new_origin.y) * cm)
				worst = maxf(worst, absf(t.get_height_at(old_world) - t.get_height_at(new_world)))
		assert_true(worst < 0.001, "%s: the carried ground is the folded frame's ground within 600 m (worst %.4f m)" % [case[2], worst])
	t.free()
	# Voxel stand-ins: carried roots cover the chunk they land on until that chunk is built.
	var v := VoxelSlice.new()
	add_child(v)
	var flat: Array = []
	flat.resize(64 * 64)
	flat.fill(1.0)
	v.build_chunk(Vector2i(0, 0), flat)
	v.build_chunk(Vector2i(1, 0), flat)
	var roots := v.detach_standins()
	assert_eq(roots.size(), 2, "every streamed root is handed over")
	v.adopt_standins(roots, TerrainSlice.fold_scene_transform(Vector3(10.0, 0.0, 10.0), Vector3(10.0 + 2.0 * cm, 0.0, 10.0), false))
	assert_true(v.has_standin(Vector2i(2, 0)) and v.has_standin(Vector2i(3, 0)), "each stands in for the chunk it now covers")
	assert_eq(v.standin_count(), 2, "two stand-ins")
	v.build_chunk(Vector2i(2, 0), flat)
	assert_false(v.has_standin(Vector2i(2, 0)), "the built chunk replaces its stand-in")
	assert_true((roots[0] as Node3D).is_queued_for_deletion(), "which is freed")
	v.prune_standins(func(ch: Vector2i) -> bool: return ch == Vector2i(9, 9))
	assert_eq(v.standin_count(), 0, "a stand-in the folded window does not cover is dropped")
	# A pole fold turns the carried root about the player.
	v.build_chunk(Vector2i(0, 0), flat)
	var turned_roots := v.detach_standins()
	assert_eq(turned_roots.size(), 2, "the built chunks, including the rebuilt one")
	v.adopt_standins(turned_roots, TerrainSlice.fold_scene_transform(Vector3(10.0, 0.0, 10.0), Vector3(10.0, 0.0, -10.0), true))
	assert_true(v.has_standin(Vector2i(0, -1)), "turned half a turn, chunk (0,0) lands on (0,-1)")
	v.release_standins()
	assert_eq(v.standin_count(), 0, "release frees the rest")
	v.free()
	# The distant ring hands its mesh over and frees it when the next ring is swapped in.
	var d := DistantTerrainScript.new()
	add_child(d)
	var ring_mesh := MeshInstance3D.new()
	d.add_child(ring_mesh)
	d._mesh_inst = ring_mesh
	assert_eq(d.detach_ring(), ring_mesh, "the ring is handed over")
	d.shift_scene(Vector3(1000.0, 0.0, 0.0))
	assert_eq(ring_mesh.position, Vector3.ZERO, "and a rebase no longer moves it")
	d._swap_in(ArrayMesh.new())
	assert_true(ring_mesh.is_queued_for_deletion(), "the next ring frees it")
	d.free()

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

## Phase 106 — the fingerprint is stable across calls and a `warm()` reset, and moves when a fabric
## shape parameter or a biome envelope does.
func _test_worldgen_fingerprint() -> void:
	var fp := TerrainSlice.worldgen_fingerprint()
	assert_eq(TerrainSlice.worldgen_fingerprint(), fp, "stable across two calls")
	# Each mutation is undone on the very next line, before its assert is read, so a failing assert
	# (which records and goes on) can never leave a static changed for the tests after this one.
	var saved_shape_warmed: bool = WorldShape._warmed
	var saved_env: Dictionary = ClimateField._envelopes.duplicate(true)
	var saved_clim_warmed: bool = ClimateField._warmed
	WorldShape._warmed = false
	ClimateField._warmed = false
	ClimateField._envelopes.clear()
	TerrainSlice.reset_fingerprint_cache()
	var after_reset := TerrainSlice.worldgen_fingerprint()
	assert_eq(after_reset, fp, "stable across a warm() reset")
	var saved_amp: float = WorldShape._ridge_amp
	WorldShape._ridge_amp = saved_amp + 1.0
	var ridge_fp := TerrainSlice.compute_worldgen_fingerprint()
	WorldShape._ridge_amp = saved_amp
	assert_true(ridge_fp != fp, "changing ridgeAmplitude changes it")
	var saved_spline: Array = WorldShape._spline
	var edited: Array = saved_spline.duplicate(true)
	edited[1][1] = float(edited[1][1]) + 1.0
	WorldShape._spline = edited
	var spline_fp := TerrainSlice.compute_worldgen_fingerprint()
	WorldShape._spline = saved_spline
	assert_true(spline_fp != fp, "changing the height spline changes it")
	assert_eq(TerrainSlice.compute_worldgen_fingerprint(), fp, "restoring the shape restores it")
	var first_key: String = str(ClimateField._envelopes.keys()[0])
	ClimateField._envelopes[first_key][0] = float(ClimateField._envelopes[first_key][0]) + 0.01
	var env_fp := TerrainSlice.compute_worldgen_fingerprint()
	WorldShape._warmed = saved_shape_warmed
	ClimateField._envelopes = saved_env
	ClimateField._warmed = saved_clim_warmed
	TerrainSlice.reset_fingerprint_cache()
	assert_true(env_fp != fp, "changing a biome envelope changes it")
	assert_eq(TerrainSlice.worldgen_fingerprint(), fp, "and the cache is back to the running value")

## Phase 106 — a stamped record that differs warns once; an unstamped one warns not, and is stamped.
func _test_worldgen_fingerprint_record() -> void:
	var running := TerrainSlice.worldgen_fingerprint()
	var warns := Diag.warn_count()
	assert_false(PersistenceSlice.check_worldgen_fingerprint({ "worldgenFingerprint": running }, running), "a matching record is no mismatch")
	assert_false(PersistenceSlice.check_worldgen_fingerprint({ "seed": 1 }, running), "an unstamped record is no mismatch")
	assert_false(PersistenceSlice.check_worldgen_fingerprint({}, running), "a new world is no mismatch")
	assert_eq(Diag.warn_count(), warns, "and none warns")
	assert_true(PersistenceSlice.check_worldgen_fingerprint({ "worldgenFingerprint": running + 1 }, running), "a different fingerprint mismatches")
	assert_eq(Diag.warn_count() - warns, 1, "with exactly one warning")
	assert_eq(PersistenceSlice.fingerprint_stamp_for_save({}, running), running, "a new world takes the running fingerprint")
	assert_eq(PersistenceSlice.fingerprint_stamp_for_save({ "seed": 1 }, running), running, "an unstamped record is stamped on the next save")
	assert_eq(PersistenceSlice.fingerprint_stamp_for_save({ "worldgenFingerprint": 5 }, running), 5, "a stamped record keeps its original")
	var dir := "user://saves/test_worldgen_fp/"
	_wipe_dir(dir)
	var writer := PersistenceSlice.new()
	add_child(writer)
	writer.server_save_dir = dir
	assert_eq(writer.save_world({ "local_player_id": "player_1_1_ab", "worldgenFingerprint": running }, false), OK, "the record writes")
	assert_eq(PersistenceSlice.worldgen_fingerprint_of(writer.load_world_record()), running, "the fingerprint round-trips")
	writer.free()
	_wipe_dir(dir)

## Phase 106 — game_root raises `worldgen_fingerprint_mismatch` exactly once for a differing record,
## and never for an unstamped one (which the next save stamps).
func _test_worldgen_fingerprint_game_root() -> void:
	var root_script: GDScript = load("res://src/core/game_root.gd")
	var gr: Node = root_script.new()
	var running := TerrainSlice.worldgen_fingerprint()
	var seen: Array = []
	var cb := func(saved: int, current: int) -> void: seen.append([saved, current])
	GameBus.worldgen_fingerprint_mismatch.connect(cb)
	gr._loaded_world = {}
	gr._persistence_wiring._note_worldgen_version()
	assert_true(seen.is_empty(), "a new world raises none")
	assert_eq(gr._worldgen_fp_stamp, running, "and takes the running fingerprint")
	gr._loaded_world = { "worldgenVersion": TerrainSlice.WORLDGEN_VERSION }
	gr._persistence_wiring._note_worldgen_version()
	assert_true(seen.is_empty(), "an unstamped record raises none")
	assert_eq(gr._worldgen_fp_stamp, running, "and is stamped for the next save")
	gr._loaded_world = { "worldgenVersion": TerrainSlice.WORLDGEN_VERSION, "worldgenFingerprint": running + 1 }
	gr._persistence_wiring._note_worldgen_version()
	assert_eq(seen, [[running + 1, running]], "a differing record raises exactly once")
	assert_eq(gr._worldgen_fp_stamp, running + 1, "and the stamp survives the notice (a save does not overwrite it)")
	GameBus.worldgen_fingerprint_mismatch.disconnect(cb)
	gr.free()

## Phase 106 — golden generator values. A Godot upgrade or an unversioned edit that moves any of
## them must bump `TerrainSlice.WORLDGEN_VERSION` and update these numbers in the same change.
func _test_worldgen_golden() -> void:
	var n := FastNoiseLite.new()
	TerrainSlice.configure_noise(n, 12345)
	var detail: Array = [3.524644747, 2.464545919, 2.602311652, 2.597774304, 2.300039381, 2.238469739, 2.919664383, 2.066151761]
	for i in 8:
		var got := TerrainSlice.detail_of(n, 37.0 * i + 5.5, -91.0 * i + 3.25)
		assert_true(absf(got - float(detail[i])) < 1e-6, "detail noise point %d matches the golden value (got %.9f)" % [i, got])
	var w: float = float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	var shape: Array = [2.0, -57.776415828, 105.545489436, -53.650412350, -34.981083839, -53.885990050, -55.059654802, -52.487651444]
	for i in 8:
		var got := WorldShape.height(777 + i, 1234.5 * i * 1000.0, -5000.0 * i + 300.0, w)
		assert_true(absf(got - float(shape[i])) < 1e-8, "shape height %d matches the golden value (got %.9f)" % [i, got])
	var biomes: Array = ["TemperateGrassland", "Ocean", "TemperateForest", "Ocean", "Ocean", "Ocean", "Ocean", "Desert",
		"Alpine", "Ocean", "Ocean", "Ocean", "Ocean", "Ocean", "TemperateForest", "Ocean"]
	for i in 16:
		var c := Vector2i((i * 65537) % 600000 - 300000, (i * 104729) % 300000 - 150000)
		assert_eq(TerrainSlice.biome_for_chunk(c, 100 + i), biomes[i], "biome of golden chunk %d" % i)


# ---- Phase 112 — a biome adjacency table in the fabric and an offline scan ----

## Phase 114 — `_test_worldgen_fingerprint` leaves `_warmed`, `_envelopes`, the ridge amplitude and the
## spline as it found them.
func _test_worldgen_fingerprint_restores() -> void:
	WorldShape.warm()
	ClimateField.warm()
	var shape_warmed: bool = WorldShape._warmed
	var amp: float = WorldShape._ridge_amp
	var spline: Array = WorldShape._spline.duplicate(true)
	var clim_warmed: bool = ClimateField._warmed
	var env: Dictionary = ClimateField._envelopes.duplicate(true)
	var failures_before := _fail
	_test_worldgen_fingerprint()
	assert_eq(_fail, failures_before, "the fingerprint test itself passes")
	assert_eq(WorldShape._warmed, shape_warmed, "WorldShape._warmed restored")
	assert_eq(WorldShape._ridge_amp, amp, "ridge amplitude restored")
	assert_eq(WorldShape._spline, spline, "spline restored")
	assert_eq(ClimateField._warmed, clim_warmed, "ClimateField._warmed restored")
	assert_eq(ClimateField._envelopes, env, "envelopes restored")

## Phase 114 — the fingerprint mismatch reaches the UI notice, once; the next load finds none.
func _test_worldgen_fingerprint_notice() -> void:
	var ui := UiSlice.new()
	GameBus.worldgen_fingerprint_mismatch.connect(ui._on_worldgen_fingerprint_mismatch)
	var root_script: GDScript = load("res://src/core/game_root.gd")
	var gr: Node = root_script.new()
	var running := TerrainSlice.worldgen_fingerprint()
	gr._loaded_world = { "worldgenVersion": TerrainSlice.WORLDGEN_VERSION, "worldgenFingerprint": running + 1 }
	gr._persistence_wiring._note_worldgen_version()
	GameBus.worldgen_fingerprint_mismatch.disconnect(ui._on_worldgen_fingerprint_mismatch)
	assert_true(ui.toast_shown().contains("parameters changed"), "the notice reaches the HUD toast")
	assert_eq(gr._worldgen_fp_stamp, running + 1, "the stamp survives the mismatch load")
	var seen: Array = []
	var cb := func(saved: int, current: int) -> void: seen.append([saved, current])
	GameBus.worldgen_fingerprint_mismatch.connect(cb)
	gr._loaded_world = { "worldgenVersion": TerrainSlice.WORLDGEN_VERSION, "worldgenFingerprint": gr._worldgen_fp_stamp }
	gr._persistence_wiring._note_worldgen_version()
	GameBus.worldgen_fingerprint_mismatch.disconnect(cb)
	assert_eq(seen, [[running + 1, running]], "the next load of that world still reports the same mismatch")
	ui.free()
	gr.free()

func _test_adjacency_table() -> void:
	var rules := BiomeAdjacency.table()
	var trans := BiomeAdjacency.transitions()
	assert_eq(rules.size(), GameData.BIOMES.size(), "every biome carries the adjacency field")
	var forbidden_pairs := 0
	for a in rules:
		for b in (rules[a] as Array):
			assert_true(GameData.BIOMES.has(b), "%s forbids a known biome (%s)" % [a, b])
			assert_true((rules.get(b, []) as Array).has(a), "%s/%s is symmetric" % [a, b])
			forbidden_pairs += 1
		if not (rules[a] as Array).is_empty():
			assert_true(GameData.BIOMES.has(trans[a]), "%s has a known transition (%s)" % [a, trans[a]])
			assert_false((rules[a] as Array).has(trans[a]), "%s transition is not a forbidden neighbour" % a)
			for f in (rules[a] as Array):
				assert_false(BiomeAdjacency.is_forbidden(rules, trans[a], f), "%s transition %s may touch %s" % [a, trans[a], f])
	assert_true(forbidden_pairs > 0, "the table forbids at least one pair")
	assert_true(BiomeAdjacency.is_forbidden(rules, "Tundra", "Desert") and BiomeAdjacency.is_forbidden(rules, "Desert", "Tundra"), "Tundra and Desert are forbidden both ways")
	assert_false(BiomeAdjacency.is_forbidden(rules, "Tundra", "Tundra"), "a biome beside itself is fine")

func _test_adjacency_scan() -> void:
	var rules := BiomeAdjacency.table()
	for seed_v in ADJACENCY_SEEDS:
		var gen := func(c: Vector2i) -> String: return TerrainSlice.generated_biome_for_chunk(c, seed_v)
		for origin in _adjacency_origins(seed_v):
			var hits := BiomeAdjacency.scan(gen, rules, origin, ADJACENCY_GRID, 1000)
			assert_eq(hits.size(), 0, "seed %d grid at %s has no forbidden pair (first: %s)" % [seed_v, origin, str(hits.slice(0, 2))])

func _test_adjacency_scan_detects() -> void:
	var rules := BiomeAdjacency.table()
	# A scratch generator: two envelopes that abut at temperature 0.5 and sit on the climate pick.
	var envs := {
		"Tundra": [0.0, 0.5, 0.0, 1.0, -100000.0, 100000.0, 1.0],
		"Desert": [0.5, 1.0, 0.0, 1.0, -100000.0, 100000.0, 1.0],
	}
	var gen := func(c: Vector2i) -> String:
		return ClimateField._pick(float(c.x) / 255.0, 0.5, 50.0, ["Tundra", "Desert"], envs, 0.0, false)
	var hits := BiomeAdjacency.scan(gen, rules, Vector2i.ZERO, ADJACENCY_GRID, 1000)
	assert_true(hits.size() > 0, "two forbidden biomes side by side are found")
	assert_eq(hits.size(), ADJACENCY_GRID, "one border column of edges is found, once each")
	assert_eq(str(hits[0]["pair"]), "Desert|Tundra", "the pair is named, sorted")
	# The same layout with the rule removed is clean.
	assert_eq(BiomeAdjacency.scan(gen, {}, Vector2i.ZERO, ADJACENCY_GRID).size(), 0, "no rule, no violation")

# ---- Phase 113 — frontier generation: a new generator version meets recorded land ----

## Phase 115 (#280) — a search that finds no coast says so: a scratch zero-step search reports not found,
## so `_adjacency_origins` would fail its assert instead of scanning the row start as a coast.
func _test_adjacency_coast_search_reports_failure() -> void:
	@warning_ignore("integer_division")
	var none := _find_coast(ADJACENCY_SEEDS[0], TerrainSlice.pole_chunks() / 4, 0)
	assert_false(none["found"], "a zero-step search finds no coast")
	@warning_ignore("integer_division")
	assert_eq(none["coast"], Vector2i(0, TerrainSlice.pole_chunks() / 4), "and falls back to the row start")
	@warning_ignore("integer_division")
	var real := _find_coast(ADJACENCY_SEEDS[0], TerrainSlice.pole_chunks() / 4, 9000, Callable(), COAST_SCAN_STRIDE)
	assert_true(real["found"], "the real search finds one")

## Phase 125 — a one-chunk ocean strip is found: the search steps by one chunk and keeps `prev` current.
func _test_find_coast_finds_thin_strip() -> void:
	var strip := func(c: Vector2i) -> String: return "Ocean" if c.x == 301 else "Grass"
	var found := _find_coast(1, 0, 1000, strip)
	assert_true(found["found"], "a strip one chunk wide is found")
	assert_eq(found["coast"], Vector2i(301, 0), "at its first chunk")
	var all_land := func(_c: Vector2i) -> String: return "Grass"
	assert_false(_find_coast(1, 0, 100000, all_land)["found"], "a planet of land has no coast")

func _test_frontier_recorded_unchanged() -> void:
	var t := TerrainSlice.new()
	add_child(t)
	t.set_world_seed(FRONTIER_SEED)
	_frontier_record_block()
	var chunks: Array = []
	for dz in FRONTIER_BLOCK_SIZE:
		for dx in FRONTIER_BLOCK_SIZE:
			chunks.append(FRONTIER_BLOCK + Vector2i(dx, dz))
	var biomes_before: Array = []
	for c in chunks:
		biomes_before.append(TerrainSlice.biome_for_chunk(c, FRONTIER_SEED))
	var hash_before := _records_hash(t, chunks)
	var plain_before := TerrainSlice.generation_record(chunks[0], FRONTIER_SEED)
	var saved := _frontier_change_generator()
	var changed := 0
	for c in chunks:
		if TerrainSlice.generation_record(c, FRONTIER_SEED)["h"] != ChunkRecordsScript.get_record(c)["h"]:
			changed += 1
	assert_eq(changed, chunks.size(), "the stand-in generator really moves every corner of the block")
	assert_true(TerrainSlice.generation_record(chunks[0], FRONTIER_SEED)["f"] != plain_before["f"], "and changes the fingerprint")
	for i in chunks.size():
		assert_eq(TerrainSlice.biome_for_chunk(chunks[i], FRONTIER_SEED), biomes_before[i], "recorded biome of chunk %s is unchanged" % chunks[i])
	assert_eq(_records_hash(t, chunks), hash_before, "recorded heightmaps are unchanged by the new generator")
	# Filling the frontier around the block must not rewrite a recorded chunk either.
	var before: Dictionary = {}
	for c in chunks:
		before[c] = ChunkRecordsScript.get_record(c).duplicate(true)
	_frontier_fill_window()
	for c in chunks:
		assert_eq(ChunkRecordsScript.get_record(c), before[c], "frontier fill leaves recorded chunk %s alone" % c)
	_frontier_restore_generator(saved)
	ChunkRecordsScript.clear()
	t.free()

func _test_frontier_seam() -> void:
	_frontier_record_block()
	var saved := _frontier_change_generator()
	# Shared corners: a new chunk east of / south of the block reuses the recorded corners exactly.
	var east := FRONTIER_BLOCK + Vector2i(FRONTIER_BLOCK_SIZE, 2)
	var rec_e := RegionStoreScript.normalize_gen(Frontier.record_for(east, FRONTIER_SEED))
	var edge: Array = ChunkRecordsScript.get_record(east + Vector2i(-1, 0))["h"]
	assert_eq(rec_e["h"][0], edge[1], "east neighbour shares the recorded north-east corner exactly")
	assert_eq(rec_e["h"][2], edge[3], "and the south-east corner")
	var south := FRONTIER_BLOCK + Vector2i(3, FRONTIER_BLOCK_SIZE)
	var rec_s := RegionStoreScript.normalize_gen(Frontier.record_for(south, FRONTIER_SEED))
	var above: Array = ChunkRecordsScript.get_record(south + Vector2i(0, -1))["h"]
	assert_eq(rec_s["h"][0], above[2], "south neighbour shares the recorded south-west corner exactly")
	assert_eq(rec_s["h"][1], above[3], "and the south-east corner")
	# The largest step between adjacent corners across the whole band.
	_frontier_fill_window()
	var o := _frontier_window_origin()
	var corners: Dictionary = {}   # corner lattice point -> height, taken from the chunk whose NW corner it is
	for dz in FRONTIER_WINDOW:
		for dx in FRONTIER_WINDOW:
			var c := o + Vector2i(dx, dz)
			var h: Array = ChunkRecordsScript.get_record(c)["h"]
			corners[c] = h[0]
			if dx == FRONTIER_WINDOW - 1:
				corners[c + Vector2i(1, 0)] = h[1]
			if dz == FRONTIER_WINDOW - 1:
				corners[c + Vector2i(0, 1)] = h[2]
	var worst := 0.0
	var disagree := 0
	for dz in FRONTIER_WINDOW:
		for dx in FRONTIER_WINDOW:
			var c := o + Vector2i(dx, dz)
			var h: Array = ChunkRecordsScript.get_record(c)["h"]
			if absf(float(h[1]) - float(corners[c + Vector2i(1, 0)])) > 0.001 or absf(float(h[2]) - float(corners[c + Vector2i(0, 1)])) > 0.001:
				disagree += 1
			worst = maxf(worst, maxf(absf(float(h[0]) - float(h[1])), absf(float(h[0]) - float(h[2]))))
	assert_eq(disagree, 0, "adjacent chunks agree on every shared corner")
	# Bound: the plain generator's own largest step, plus what easing the largest recorded-versus-generated
	# offset can add: a smoothstep falls at most 1.5 / span of its height per lattice step, with 1.5x slack for
	# the diagonal spread of the averaged offsets.
	var plain_worst := _frontier_plain_max_step(o)
	var max_offset := 0.0
	for dz in FRONTIER_BLOCK_SIZE + 1:
		for dx in FRONTIER_BLOCK_SIZE + 1:
			var q := FRONTIER_BLOCK + Vector2i(dx, dz)
			max_offset = maxf(max_offset, absf(float(corners[q]) - TerrainSlice.generated_corner_height(q, FRONTIER_SEED)))
	var bound := plain_worst + max_offset * 1.5 * 1.5 / float(Frontier.BLEND_SPAN)
	assert_true(worst <= bound, "largest corner step %.1f m is within %.1f m (plain %.2f m, offset up to %.1f m)" % [worst, bound, plain_worst, max_offset])
	# A scratch broken blend (recorded corners kept, everything else the plain generator, no easing)
	# must trip that same bound, or the bound proves nothing.
	var broken := _frontier_unblended_max_step(o, corners)
	assert_true(broken > bound, "an unblended edge (%.1f m) exceeds the bound (%.1f m)" % [broken, bound])
	_frontier_restore_generator(saved)
	ChunkRecordsScript.clear()

func _test_frontier_far_is_plain() -> void:
	_frontier_record_block()
	var saved := _frontier_change_generator()
	var far: Array = [
		FRONTIER_BLOCK + Vector2i(FRONTIER_BLOCK_SIZE - 1 + Frontier.BLEND_CHUNKS, 2),
		FRONTIER_BLOCK + Vector2i(-Frontier.BLEND_CHUNKS, 2),
		FRONTIER_BLOCK + Vector2i(2, FRONTIER_BLOCK_SIZE - 1 + Frontier.BLEND_CHUNKS),
		FRONTIER_BLOCK + Vector2i(2, -Frontier.BLEND_CHUNKS),
		FRONTIER_BLOCK + Vector2i(40, 40),
	]
	for c in far:
		assert_eq(Frontier.record_for(c, FRONTIER_SEED), TerrainSlice.generation_record(c, FRONTIER_SEED), "chunk %s, %d+ chunks from recorded land, is the plain new generator" % [c, Frontier.BLEND_CHUNKS])
	var near := FRONTIER_BLOCK + Vector2i(FRONTIER_BLOCK_SIZE - 1 + Frontier.BLEND_CHUNKS - 1, 2)
	assert_true(Frontier.record_for(near, FRONTIER_SEED)["h"] != TerrainSlice.generation_record(near, FRONTIER_SEED)["h"], "one chunk closer the blend is still felt")
	ChunkRecordsScript.clear()
	assert_eq(Frontier.record_for(near, FRONTIER_SEED), TerrainSlice.generation_record(near, FRONTIER_SEED), "with no records at all it is the plain generator")
	_frontier_restore_generator(saved)

func _test_frontier_adjacency() -> void:
	var rules := BiomeAdjacency.table()
	var trans := BiomeAdjacency.transitions()
	var keys := TerrainSlice.BIOME_KEYS
	assert_eq(Frontier.resolve_biome(rules, trans, "Desert", ["Tundra"], keys), trans["Desert"], "a forbidden pick becomes its transition")
	assert_eq(trans["Desert"], "Savanna", "which for Desert beside Tundra is Savanna")
	assert_eq(Frontier.resolve_biome(rules, trans, "Desert", ["Savanna", "Alpine"], keys), "Desert", "an allowed pick stands")
	assert_eq(Frontier.resolve_biome(rules, trans, "Desert", [], keys), "Desert", "no recorded neighbour, no change")
	# The transition is itself forbidden beside another recorded neighbour: fall back to a neighbour's biome.
	var scratch := { "A": ["B"], "B": ["A"], "T": ["C"], "C": ["T"], "N": [] }
	var scratch_trans := { "A": "T", "B": "N", "T": "N", "C": "N", "N": "" }
	assert_eq(Frontier.resolve_biome(scratch, scratch_trans, "A", ["B", "C"], ["A", "B", "C", "N", "T"]), "B", "a transition forbidden beside another neighbour falls back to a neighbour's biome")
	# Around a recorded block, with the changed generator, the filled window has no forbidden pair.
	for seed_v in [FRONTIER_SEED, 7]:
		ChunkRecordsScript.clear()
		for dz in FRONTIER_BLOCK_SIZE:
			for dx in FRONTIER_BLOCK_SIZE:
				var c := FRONTIER_BLOCK + Vector2i(dx, dz)
				ChunkRecordsScript.set_record(c, RegionStoreScript.normalize_gen(TerrainSlice.generation_record(c, seed_v)))
		var saved := _frontier_change_generator()
		var o := _frontier_window_origin()
		# Phase 114: filled in raster order, then again from the far corner back (the order a window
		# that scrolled the other way would load it).
		var snapshot: Dictionary = {}
		for dz in FRONTIER_WINDOW:
			for dx in FRONTIER_WINDOW:
				var c := o + Vector2i(dx, dz)
				if ChunkRecordsScript.has_record(c):
					snapshot[c] = ChunkRecordsScript.get_record(c)
		for reverse in [false, true]:
			for c in snapshot:
				ChunkRecordsScript.set_record(c, snapshot[c])
			for i in FRONTIER_WINDOW * FRONTIER_WINDOW:
				var j: int = FRONTIER_WINDOW * FRONTIER_WINDOW - 1 - i if reverse else i
				@warning_ignore("integer_division")
				var c := o + Vector2i(j % FRONTIER_WINDOW, j / FRONTIER_WINDOW)
				if not ChunkRecordsScript.has_record(c):
					ChunkRecordsScript.set_record(c, RegionStoreScript.normalize_gen(Frontier.record_for(c, seed_v)))
			var at := func(c: Vector2i) -> String: return str(ChunkRecordsScript.get_record(c)["b"])
			var hits := BiomeAdjacency.scan(at, rules, o, FRONTIER_WINDOW, 100)
			assert_eq(hits.size(), 0, "seed %d, %s fill: no forbidden pair around the recorded block (first: %s)" % [seed_v, "reverse" if reverse else "raster", str(hits.slice(0, 2))])
			if not reverse:
				ChunkRecordsScript.clear()
		_frontier_restore_generator(saved)
	ChunkRecordsScript.clear()

func _test_frontier_deterministic() -> void:
	_frontier_record_block()
	var saved := _frontier_change_generator()
	var target := FRONTIER_BLOCK + Vector2i(FRONTIER_BLOCK_SIZE, 1)
	var first := Frontier.record_for(target, FRONTIER_SEED)
	# A second host: the same records inserted in the opposite order.
	var recs: Array = []
	for dz in FRONTIER_BLOCK_SIZE:
		for dx in FRONTIER_BLOCK_SIZE:
			var c := FRONTIER_BLOCK + Vector2i(dx, dz)
			recs.append([c, ChunkRecordsScript.get_record(c)])
	ChunkRecordsScript.clear()
	recs.reverse()
	for r in recs:
		ChunkRecordsScript.set_record(r[0], r[1])
	assert_eq(Frontier.record_for(target, FRONTIER_SEED), first, "same records, same generator: same record")
	assert_eq(Frontier.record_for(target, FRONTIER_SEED), first, "and the same again")
	ChunkRecordsScript.clear()
	_frontier_restore_generator(saved)

# ---- Phase 108 — terrain reads and writes the generation record on the host ----

## The blend weight is monotone, 1 at a recorded corner and exactly 0 at `BLEND_CHUNKS`; the field does
## not depend on the order the recorded chunks were gathered in.
func _test_frontier_order_and_weight() -> void:
	assert_eq(Frontier.blend_weight(0.0), 1.0, "full weight at a recorded corner")
	assert_eq(Frontier.blend_weight(float(Frontier.BLEND_CHUNKS - 1)), 0.0, "exactly 0 at the last ring (a chunk BLEND_CHUNKS out has no recorded corner nearer)")
	var prev := 2.0
	for i in range(0, Frontier.BLEND_CHUNKS * 4 + 1):
		var w := Frontier.blend_weight(float(i) / 4.0)
		assert_true(w <= prev and w >= 0.0, "weight never rises with distance (step %d: %.4f)" % [i, w])
		prev = w
	assert_true(Frontier.blend_weight(float(Frontier.BLEND_CHUNKS - 2)) > 0.0, "and is still felt one ring in")
	_frontier_record_block()
	var saved := _frontier_change_generator()
	var target := FRONTIER_BLOCK + Vector2i(FRONTIER_BLOCK_SIZE + 1, 1)
	var recs := Frontier.gather(target)
	var keys: Array = recs.keys()
	keys.reverse()
	var reordered: Dictionary = {}
	for k in keys:
		reordered[k] = recs[k]
	assert_eq(Frontier.compute(target, FRONTIER_SEED, reordered), Frontier.compute(target, FRONTIER_SEED, recs), "the same records in another order give the same record")
	for p in [target, target + Vector2i(1, 1)]:
		assert_eq(Frontier.corner_height(p, FRONTIER_SEED, reordered), Frontier.corner_height(p, FRONTIER_SEED, recs), "corner %s is order-independent" % p)
	# Averaged over every recorded corner in range, the offset reaches 0 at the last ring: a corner
	# BLEND_CHUNKS from the block is exactly the plain generator.
	var far_corner := FRONTIER_BLOCK + Vector2i(FRONTIER_BLOCK_SIZE + Frontier.BLEND_CHUNKS - 1, 2)
	assert_eq(Frontier.corner_height(far_corner, FRONTIER_SEED, Frontier.gather(far_corner)),
		snappedf(TerrainSlice.generated_corner_height(far_corner, FRONTIER_SEED), TerrainSlice.GEN_HEIGHT_STEP),
		"a corner at the last ring is the plain generator")
	assert_true(Frontier.gather(FRONTIER_BLOCK + Vector2i(500, 500)).is_empty(), "gather answers {} far from any record")
	_frontier_restore_generator(saved)
	ChunkRecordsScript.clear()

func _test_p126_seam_wrap_module() -> void:
	assert_eq(SeamWrapScript.wrap_i(5, 10), -5, "the half lap wraps to the negative side")
	assert_eq(SeamWrapScript.delta(-4, 4, 10), 2, "the short way round a lap of 10")
	assert_true(is_equal_approx(SeamWrapScript.delta_f(-4.0, 4.0, 10.0), 2.0), "and for floats")
	assert_eq(SeamWrapScript.world_tiles(8, 32), 256, "tiles in a lap")
	assert_true(is_equal_approx(SeamWrapScript.world_metres(8, 32, 0.5), 128.0), "metres in a lap")
	# The helpers live in seam_wrap.gd and nowhere else.
	var offenders: Array = []
	for dir in ["res://src/world", "res://src/terrain", "res://src/persistence", "res://src/core", "res://src/networking"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd") or f == "seam_wrap.gd":
				continue
			var src := FileAccess.get_file_as_string(dir + "/" + f)
			for probe in ["_wrapped_delta", "_world_tiles(", "_world_metres("]:
				if src.contains("func " + probe) or src.contains("static func " + probe):
					offenders.append(dir + "/" + f + ":" + probe)
	assert_eq(offenders, [], "no module keeps its own copy of the seam helpers")

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

func _test_phase122_exact_positions() -> void:
	var far := { "chunk": Vector2i(1500000, 7), "local": Vector3(30.0, 2.0, 5.0) }
	var near := { "chunk": Vector2i(1500001, 7), "local": Vector3(2.0, 2.0, 5.0) }   # 4 m east
	var gone := { "chunk": Vector2i(1500000 + 20, 7), "local": Vector3(2.0, 2.0, 5.0) }
	assert_eq(WorldPos.offset_between(far, near), Vector3(4.0, 0.0, 0.0), "the offset between exact positions is exact at chunk X 1,500,000")
	assert_true(NetworkingSlice.within_aoi_exact(far, near), "a neighbour 4 m away is in the AOI at chunk X 1,500,000")
	assert_false(NetworkingSlice.within_aoi_exact(far, gone), "a position 600 m away is not")
	var row: int = -TerrainSlice.pole_chunks() - TerrainSlice.FOLD_MARGIN_CHUNKS - 1
	assert_true(WorldPos.is_wire({ "chunk": [0, row], "local": [1.0, 2.0, 3.0] }), "the first south fold row is a wire position")
	assert_false(WorldPos.is_wire({ "chunk": [0, row - 1], "local": [1.0, 2.0, 3.0] }), "one row further is not")
	assert_true(WorldPos.is_wire({ "chunk": [0, TerrainSlice.pole_chunks() + TerrainSlice.FOLD_MARGIN_CHUNKS], "local": [1.0, 2.0, 3.0] }), "the north limit is unchanged")
	# OreField.warm() latches only once ClimateField is warm.
	var was_ore: bool = OreField._warmed
	var was_climate: bool = ClimateField._warmed
	OreField._warmed = false
	ClimateField._warmed = false
	OreField.warm()
	assert_true(ClimateField.is_warm() and OreField._warmed, "OreField.warm() warms ClimateField and latches")
	OreField._warmed = was_ore
	ClimateField._warmed = was_climate

func _test_phase122_snapshot_fallback_and_clamp() -> void:
	var root_script: GDScript = load("res://src/core/game_root.gd")
	var terrain := TerrainSlice.new()
	add_child(terrain)
	var body := PlayerSlice.new()
	body.render_visuals = true
	add_child(body)
	var gr: Node = root_script.new()
	gr._player = body
	gr._terrain = terrain
	gr._rebase = RebaseDriver.new([body])
	gr._rebase.rebase_to(Vector2i(600000, 40))
	body.place_at_world_pos({ "chunk": Vector2i(600000, 40), "local": Vector3(1.0, 20.0, 1.0) })
	# A wire-shaped but invalid position (a chunk far past the pole) spawns the body at the spawn point.
	gr._snapshot_wiring._place_from_snapshot({ "position": { "chunk": [0, 99999999], "local": [1.0, 2.0, 3.0] } })
	var landed := body.get_world_pos()
	assert_eq(landed["chunk"], Vector2i.ZERO, "a bad snapshot position rebases to the spawn chunk")
	var spawn: Vector3 = landed["local"]
	assert_true(Vector2(spawn.x, spawn.z).distance_to(WorldShape.SPAWN_CENTER) < 1.0, "and lands on the spawn point")
	gr.free()
	body.free()
	terrain.free()
	# record_world_pos derives `position` from the normalised chunk: an overflowing local carries over.
	var reg := PlayerRegistry.new()
	reg.record_world_pos("clamp", { "chunk": Vector2i(5, 6), "local": Vector3(WorldPos.CHUNK_METERS + 7.0, 3.0, -4.0) })
	var rec := reg.get_record("clamp")
	var pos: Array = rec["position"]
	var cm: float = WorldPos.CHUNK_METERS
	assert_eq(float(pos[0]), 6.0 * cm + 7.0, "an overflowing local X carries into the next chunk")
	assert_eq(float(pos[2]), 6.0 * cm - 4.0, "a negative local Z carries into the previous chunk")
	reg.free()
	# A non-multiple shift is refused even at a huge shift (no relative tolerance).
	assert_false(PlayerSlice.is_chunk_multiple_shift(Vector3(-48000000.0 + 100.0, 0.0, 0.0)), "a 100 m off-grid shift is refused at 48,000 km")
	assert_true(PlayerSlice.is_chunk_multiple_shift(Vector3(-48000000.0, 0.0, 32.0)), "whole-chunk shifts pass")

## Phase 122 — the scene-offset state lives in scene_offset.gd alone, and the player refuses a
## shift that is not a whole number of chunks.
func _test_scene_shift_helper() -> void:
	var holders := 0
	for dir in ["res://src"]:
		holders += _count_files_with(dir, "_scene_" + "offset")
	assert_eq(holders, 0, "no source file declares its own scene offset field")
	var so := preload("res://src/core/scene_offset.gd").new()
	so.add(Vector3(64.0, 0.0, -32.0))
	assert_eq(so.to_scene(Vector3(1.0, 2.0, 3.0)), Vector3(65.0, 2.0, -29.0), "to_scene adds the offset")
	assert_eq(so.to_world(so.to_scene(Vector3(1.0, 2.0, 3.0))), Vector3(1.0, 2.0, 3.0), "to_world undoes it")
	var cm := WorldPos.CHUNK_METERS
	assert_true(PlayerSlice.is_chunk_multiple_shift(Vector3(2.0 * cm, 0.0, -cm)), "a whole-chunk shift is accepted")
	assert_false(PlayerSlice.is_chunk_multiple_shift(Vector3(cm * 0.5, 0.0, 0.0)), "half a chunk is refused")
	assert_false(PlayerSlice.is_chunk_multiple_shift(Vector3(cm, 3.0, 0.0)), "a vertical shift is refused")
	var player := PlayerSlice.new()
	add_child(player)
	player.shift_scene(Vector3(cm * 0.25, 0.0, 0.0))
	assert_eq(player.scene_offset(), Vector3.ZERO, "a refused shift leaves the offset alone")
	player.shift_scene(Vector3(-cm, 0.0, 0.0))
	assert_eq(player.scene_offset(), Vector3(-cm, 0.0, 0.0), "a whole-chunk shift moves it")
	player.free()

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
		root._weather_wiring._apply_sun(lat, 0.0)
		assert_true(absf(sun.light_energy - 1.4 * WorldClock.biome_daylight(d, 0.0)) < 1e-6,
			"night speed 0: sun energy is biome_daylight(d, 0) at day phase %s" % phase)
		assert_true(absf(sun.light_energy - 0.7) < 1e-6, "night speed 0 stays at dusk energy")
		root._weather_wiring._apply_sun(lat, 1.0)
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
		@warning_ignore("integer_division")
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
	for seed_v in [1, 2, 3]:
		scan.set_world_seed(seed_v)
		# Aethermite lives in volcanic and twilight ground, which Phase 51 made climate niches.
		for chunk_v in _biome_chunks(scan, ["VolcanicBadlands", "TwilightGrove"], 14):
			if true:
				var chunk: Vector2i = chunk_v
				var cache: Dictionary = {}
				for tz in range(0, 64, 2):
					for tx in range(0, 64, 2):
						for k in range(0, 26):
							var depth := 0.0625 + float(k) * 0.5
							var vein := OreField.vein_at(seed_v, chunk, Vector2i(tx, tz), depth, cache)
							if vein.is_empty() or str(vein["material"]) != "Aethermite":
								continue
							seen += 1
							if depth < float(band["min"]):
								above_band += 1
							var g := chunk * 64 + Vector2i(tx, tz)
							if not OreField.near_ley_line(seed_v, Vector2(g.x * 0.5 + 0.25, g.y * 0.5 + 0.25)):
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

## The retired draw gave every volcanic chunk the SAME Aethermite share (17/100, every
## depth). Per-chunk counts from the field must now vary.
func _test_ore_uniform_draw_gone() -> void:
	var counts: Array = []
	# Volcanic ground is a rare, latitude-bound niche: take the first world that has enough of it near spawn.
	for seed_v in range(7, 40):
		counts.clear()
		_collect_volcanic_counts(seed_v, counts)
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
		@warning_ignore("integer_division")
		if absi(int(n) - old_constant) > old_constant / 2:
			off += 1
	@warning_ignore("integer_division")
	assert_true(off > counts.size() / 2, "and most chunks are far from the retired constant share")

func _test_ore_blob_crosses_chunk_border() -> void:
	# Cells straddle chunk borders by construction (CELL_OFFSET_TILES), so some blob must
	# cover tiles on both sides of the x = 64 border. Find one and check continuity.
	var crossing := 0
	var agree := true
	for seed_v in [1, 2, 3, 4]:
		for tz in range(0, 64):
			for k in range(0, 24):
				var depth := 0.0625 + float(k) * 0.5
				var left := OreField.vein_at(seed_v, Vector2i(0, 0), Vector2i(63, tz), depth)
				var right := OreField.vein_at(seed_v, Vector2i(1, 0), Vector2i(0, tz), depth)
				# The same global tile asked through EITHER chunk is the same answer.
				if OreField.vein_at(seed_v, Vector2i(0, 0), Vector2i(64, tz), depth) != right:
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
