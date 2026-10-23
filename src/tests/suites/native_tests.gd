extends "res://src/tests/test_support.gd"
## Phase 166 — the native chunk builder scaffold: the loader's native / GDScript-fallback decision.
## CI runs the suite twice: once with no binary (`--expect-fallback`) and once with the Linux
## binary built by the `native` job (`--expect-native`). Without either flag the real loader is
## only checked for consistency with what the engine can see.

const NativeBuilder := preload("res://src/terrain/native_builder.gd")
const VoxelRuns := preload("res://src/terrain/voxel_runs.gd")
const VoxelMesh := preload("res://src/terrain/voxel_mesh.gd")

const EXPECT_NATIVE_ARG := "--expect-native"
const EXPECT_FALLBACK_ARG := "--expect-fallback"

func register() -> void:
	_run_test("native: the loader picks native only when the extension loaded and the class exists", _test_native_mode_decision)
	_run_test("native: the real loader matches the build (native present or fallback)",             _test_native_real_loader)
	_run_test("native: only ported functions are routed natively",                                 _test_native_routes_only_ported)
	_run_test("native: heightmap_for matches the GDScript reference on the fixed chunk set",       _test_native_heightmap_parity)
	_run_test("native: build_runs matches the GDScript reference on the fixed chunk set",          _test_native_build_runs_parity)
	_run_test("native: build_chunk_arrays matches the GDScript reference on the fixed chunk set",  _test_native_chunk_arrays_parity)
	_run_test("native: a rejected build_chunk_arrays falls back to the GDScript reference",        _test_native_chunk_arrays_rejection_falls_back)
	_run_test("native: a rejected build_runs falls back to the GDScript reference",                _test_native_build_runs_rejection_falls_back)
	_run_test("native: the build_runs cfg snapshot is filled once across threads",                 _test_native_runs_cfg_single_fill)
	_run_test("native: run edits resolve in a total order",                                     _test_native_run_ops_order)
	_run_test("native: the extension and its build files are in the tree",                         _test_native_files_present)
	_run_test("native: CI times the playtest stream step once per builder",                         _test_native_speed_gate_wired)
	_run_test("native: the build breakdown decides on the heightmap share",                         _test_native_build_breakdown)
	_run_test("native: the release workflow is tag-triggered and builds three platforms",           _test_native_release_workflow)

func _test_native_mode_decision() -> void:
	assert_eq(NativeBuilder.mode_for(true, true), NativeBuilder.MODE_NATIVE, "loaded and registered: native")
	assert_eq(NativeBuilder.mode_for(false, false), NativeBuilder.MODE_FALLBACK, "no extension: GDScript fallback")
	assert_eq(NativeBuilder.mode_for(true, false), NativeBuilder.MODE_FALLBACK, "loaded but the class is missing: fallback")
	assert_eq(NativeBuilder.mode_for(false, true), NativeBuilder.MODE_FALLBACK, "a failed load never reports native")

func _test_native_real_loader() -> void:
	NativeBuilder.reset_for_tests()
	var args := OS.get_cmdline_user_args()
	var mode := NativeBuilder.init()
	assert_eq(NativeBuilder.init(), mode, "the decision is cached")
	if EXPECT_NATIVE_ARG in args:
		assert_eq(mode, NativeBuilder.MODE_NATIVE, "the binary is present: the loader reports native")
		assert_true(ClassDB.class_exists(NativeBuilder.CLASS_NAME), "NativeChunkBuilder is registered")
		assert_eq(NativeBuilder.version(), 4, "the native class reports its version")
		var b: RefCounted = ClassDB.instantiate(NativeBuilder.CLASS_NAME)
		assert_eq(b.call("functions") as PackedStringArray, PackedStringArray(["heightmap_for", "build_runs", "build_chunk_arrays"]), "Phases 167-169 port heightmap_for, build_runs and build_chunk_arrays")
	if EXPECT_FALLBACK_ARG in args:
		assert_eq(mode, NativeBuilder.MODE_FALLBACK, "no binary: the loader reports the GDScript fallback")
		assert_eq(NativeBuilder.version(), -1, "no native version on the fallback")
	assert_eq(mode == NativeBuilder.MODE_NATIVE, ClassDB.class_exists(NativeBuilder.CLASS_NAME), "native exactly when the class is registered")
	assert_eq(NativeBuilder.use_native("heightmap_for"), mode == NativeBuilder.MODE_NATIVE, "heightmap_for is native exactly when the extension loaded")

func _test_native_routes_only_ported() -> void:
	NativeBuilder.init()
	assert_eq(NativeBuilder.use_native("build_runs"), NativeBuilder.is_native(), "build_runs is native exactly when the extension loaded")
	assert_eq(NativeBuilder.use_native("build_chunk_arrays"), NativeBuilder.is_native(), "build_chunk_arrays is native exactly when the extension loaded")
	assert_false(NativeBuilder.use_native("not_a_function"), "an unknown function is never native")

## The chunk set the native port is held to: equator, ice shelf, pole snow field, both sides of the
## antimeridian blend band, a far-from-origin chunk, and chunks whose cells carry records.
func _native_parity_chunks() -> Array:
	var c := TerrainSlice.circumference_chunks()
	var pole := TerrainSlice.pole_chunks()
	var ice := int(float(pole) * (TerrainSlice.ICE_SHELF_LAT + 1.0) / 90.0)
	return [
		Vector2i(300, 7),                    # equator, away from the spawn plain
		Vector2i(-1234, -90),                # temperate, far
		Vector2i(40, ice),                   # ice shelf
		Vector2i(-40, -ice),                 # ice shelf, south
		Vector2i(7, pole - 3),               # pole snow field
		Vector2i(c / 2 - 1, 11),             # east of the antimeridian: blend band
		Vector2i(-c / 2, 11),                # west of it
		Vector2i(c / 2 - 5, pole - 2),       # blend band at the pole
		Vector2i(0, 0),                      # spawn plain
		Vector2i(2047, -2047),               # far detail-noise cell
	]

func _test_native_heightmap_parity() -> void:
	NativeBuilder.init()
	if not NativeBuilder.is_native():
		print("[Native] heightmap parity skipped: no native extension in this run")
		return
	var seed_v := 777001
	var noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(noise, seed_v)
	var chunks := _native_parity_chunks()
	var c := TerrainSlice.circumference_chunks()
	ChunkRecordsScript.clear()
	for round_i in range(2):
		if round_i == 1:
			# An edited chunk: records keep their own corner heights, here lifted off the generator's.
			for pos: Vector2i in [chunks[0], chunks[5], chunks[6]]:
				ChunkRecordsScript.set_record(pos, {"b": "TemperateForest", "h": [3.25, 4.5, -2.0, 9.125], "v": TerrainSlice.WORLDGEN_VERSION})
		for pos: Vector2i in chunks:
			var want := TerrainSlice.heightmap_for_gd(pos, seed_v, noise)
			var got := TerrainSlice.heightmap_for(pos, seed_v, noise)
			assert_eq(got.size(), want.size(), "native heightmap_for %s has the same size (records %d)" % [str(pos), round_i])
			assert_true(got == want, "native heightmap_for %s equals the GDScript reference (records %d)" % [str(pos), round_i])
	ChunkRecordsScript.clear()

## One build input for `chunk`: the 3x3 ring's heightmaps (the +x column left unknown for the odd
## chunks, so unknown-neighbour reads are covered), their biomes, the seed, edits and a depletion
## record naming real veins found by the first pass.
func _native_runs_input(chunk: Vector2i, seed_v: int, noise: FastNoiseLite, edits: Dictionary, depleted: Dictionary, skip_east: bool) -> Dictionary:
	var neighbours := {}
	var biomes := {}
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var c := Vector2i(chunk.x + dx, chunk.y + dz)
			var key := VoxelSlice._chunk_key(c)
			biomes[key] = TerrainSlice.biome_for_chunk(c, seed_v)
			if (dx != 0 or dz != 0) and not (skip_east and dx == 1):
				neighbours[key] = TerrainSlice.heightmap_for(c, seed_v, noise)
	return {"edits": edits, "neighbour_heightmaps": neighbours, "biomes": biomes, "seed": seed_v, "depleted": depleted}

func _native_runs_edits(chunk: Vector2i) -> Dictionary:
	var gx := chunk.x * 64
	var gz := chunk.y * 64
	var edits := {}
	var top := 40.0
	# A carved tunnel, a stacked placed block, a corner tile on the ring, and an unknown op kind.
	edits[VoxelSlice._tile_key(Vector2i(gx + 5, gz + 5))] = [{"op": "remove", "bottom": -3.0, "top": -2.0}]
	edits[VoxelSlice._tile_key(Vector2i(gx + 6, gz + 5))] = [{"op": "add", "bottom": top, "top": top + 0.25, "material": "Ferrite"}, {"op": "remove", "bottom": -90.0, "top": -80.0}]
	edits[VoxelSlice._tile_key(Vector2i(gx - 1, gz - 1))] = [{"op": "remove", "bottom": -10.0, "top": 30.0}, {"op": "bogus", "bottom": 0.0, "top": 1.0}]
	edits[VoxelSlice._tile_key(Vector2i(gx + 64, gz + 10))] = [{"op": "add", "bottom": -96.0, "top": 5.0, "material": "Voidite"}]
	return edits

func _test_native_build_runs_parity() -> void:
	NativeBuilder.init()
	if not NativeBuilder.is_native():
		print("[Native] build_runs parity skipped: no native extension in this run")
		return
	var seed_v := 777001
	var noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(noise, seed_v)
	ChunkRecordsScript.clear()
	var deposits_seen := 0
	var vein_colours := 0
	var topsoil := 0
	for chunk: Vector2i in _native_parity_chunks():
		var hm := TerrainSlice.heightmap_for(chunk, seed_v, noise)
		for variant in range(3):
			# 0 plain, 1 edited + one live vein mined out, 2 edited with an unknown east ring
			var edits := {} if variant == 0 else _native_runs_edits(chunk)
			var depleted := {}
			if variant == 1:
				# Mine out every other vein cell the chunk's ring touches, at the top two depth cells.
				var c0 := int(floor(float(chunk.x * 64 - 1 + OreField.CELL_OFFSET_TILES) / OreField.CELL_TILES))
				var z0 := int(floor(float(chunk.y * 64 - 1 + OreField.CELL_OFFSET_TILES) / OreField.CELL_TILES))
				for cx in range(c0, c0 + 6):
					for cz in range(z0, z0 + 6):
						if (cx + cz) % 2 == 0:
							for cy in range(0, 3):
								depleted["%d,%d,%d" % [cx, cy, cz]] = 99
			var input := _native_runs_input(chunk, seed_v, noise, edits, depleted, variant == 2)
			var want := VoxelSlice.build_runs_gd(chunk, hm, input)
			var got := VoxelSlice.build_runs(chunk, hm, input)
			assert_eq((got["runs"] as Dictionary).keys(), (want["runs"] as Dictionary).keys(), "native build_runs %s v%d has the same tiles in the same order" % [str(chunk), variant])
			assert_true(got["runs"] == want["runs"], "native build_runs %s v%d runs equal the GDScript reference" % [str(chunk), variant])
			assert_true(got["deposits"] == want["deposits"], "native build_runs %s v%d deposits equal the reference, same order" % [str(chunk), variant])
			deposits_seen += (want["deposits"] as Array).size()
			for key in (want["runs"] as Dictionary):
				for entry: Dictionary in want["runs"][key]:
					if entry.has("top_color"):
						topsoil += 1
	assert_true(deposits_seen > 0, "the fixed chunk set holds vein deposits, so the ore path is compared (%d)" % deposits_seen)
	assert_true(topsoil > 0, "the fixed chunk set holds topsoiled runs, so the topsoil path is compared (%d)" % topsoil)

## Phase 169 — the native greedy mesher gives the same arrays, in the same order, as the reference:
## resolved runs (plain, edited, unknown east ring), a bare natural-column build, absolute and
## chunk-local vertices.
func _test_native_chunk_arrays_parity() -> void:
	NativeBuilder.init()
	if not NativeBuilder.is_native():
		print("[Native] build_chunk_arrays parity skipped: no native extension in this run")
		return
	var seed_v := 777001
	var noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(noise, seed_v)
	ChunkRecordsScript.clear()
	var deposits_seen := 0
	var quads := 0
	var walls_with_soil := 0
	for chunk: Vector2i in _native_parity_chunks():
		var hm := TerrainSlice.heightmap_for(chunk, seed_v, noise)
		for variant in range(3):
			var edits := {} if variant == 0 else _native_runs_edits(chunk)
			var input := _native_runs_input(chunk, seed_v, noise, edits, {}, variant == 2)
			var resolved := VoxelSlice.build_runs_gd(chunk, hm, input)
			for local in [false, true]:
				var want := VoxelMesh.build_chunk_arrays_gd(chunk, hm, resolved, local)
				var got := VoxelSlice.build_chunk_arrays(chunk, hm, resolved, local)
				assert_true(got == want, "native build_chunk_arrays %s v%d local=%s equals the GDScript reference" % [str(chunk), variant, str(local)])
				assert_eq(got["quad_count"], want["quad_count"], "same quad count %s v%d" % [str(chunk), variant])
				assert_eq((got["vertices"] as PackedVector3Array).size(), (want["vertices"] as PackedVector3Array).size(), "same vertex count %s v%d" % [str(chunk), variant])
				if not local:
					quads += int(want["quad_count"])
					deposits_seen += (want["deposit_vertices"] as PackedVector3Array).size()
		# A bare build: no resolved tiles, every column natural off the heightmap.
		var bare_want := VoxelMesh.build_chunk_arrays_gd(chunk, hm, {"runs": {}})
		assert_true(VoxelSlice.build_chunk_arrays(chunk, hm, {"runs": {}}) == bare_want, "native bare build %s equals the reference" % str(chunk))
	assert_true(quads > 0, "the fixed chunk set meshes quads (%d)" % quads)
	assert_true(deposits_seen > 0, "the fixed chunk set meshes vein deposit boxes (%d)" % deposits_seen)

## A malformed resolve table is rejected by the native mesher (empty result); `VoxelMesh` then runs
## the GDScript reference rather than hand back a result without arrays.
func _test_native_chunk_arrays_rejection_falls_back() -> void:
	NativeBuilder.init()
	if not NativeBuilder.is_native():
		print("[Native] build_chunk_arrays fallback skipped: no native extension in this run")
		return
	var chunk := Vector2i(300, 7)
	var hm: Array = []
	hm.resize(4096)
	hm.fill(3.0)
	# A string "bottom" is unreadable to the native port but still a number to the reference (float("0")).
	var col := [{"bottom": "-96.0", "top": 3.0, "color": Color.RED}]
	var bad := {"runs": {VoxelSlice._tile_key(Vector2i(300 * 64, 7 * 64)): col}}
	var cfg := { "circumference_chunks": TerrainSlice.circumference_chunks(), "fallback_color": VoxelMesh.FALLBACK_TERRAIN_COLOR }
	var direct := NativeBuilder.builder().call("build_chunk_arrays", chunk, hm, bad, false, cfg) as Dictionary
	assert_true(direct.is_empty(), "the native mesher rejects the malformed table")
	var got := VoxelSlice.build_chunk_arrays(chunk, hm, bad)
	assert_true(got.has("vertices"), "a rejected native build still returns arrays")
	assert_true(got == VoxelMesh.build_chunk_arrays_gd(chunk, hm, bad), "the fallback produced the reference result")

## #452 — a native `build_runs` that rejects its input returns an empty Dictionary; `VoxelSlice.build_runs`
## falls back to the GDScript reference instead of handing the caller a result without `runs`.
func _test_native_build_runs_rejection_falls_back() -> void:
	NativeBuilder.init()
	if not NativeBuilder.is_native():
		print("[Native] build_runs fallback skipped: no native extension in this run")
		return
	var seed_v := 777001
	var noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(noise, seed_v)
	ChunkRecordsScript.clear()
	var chunk := Vector2i(300, 7)
	var hm := TerrainSlice.heightmap_for(chunk, seed_v, noise)
	var input := _native_runs_input(chunk, seed_v, noise, {}, {}, false)
	var good := VoxelSlice.native_runs_cfg()
	var bad := good.duplicate()
	bad["vein_cell"] = Callable()   # the native side fails its vein-callable check
	NativeBuilder._memo["build_runs"] = bad
	var got := VoxelSlice.build_runs(chunk, hm, input)
	NativeBuilder._memo["build_runs"] = good
	var want := VoxelSlice.build_runs_gd(chunk, hm, input)
	assert_true(got.has("runs"), "a rejected native build still returns runs")
	assert_true(got["runs"] == want["runs"], "the fallback runs are the GDScript reference")

## #452 — the cfg snapshot is filled under a lock: workers that reach it before `_ready` warmed it all
## get the one snapshot instead of racing to build their own.
func _test_native_runs_cfg_single_fill() -> void:
	var saved := VoxelSlice.native_runs_cfg()
	NativeBuilder.forget_memo("build_runs")
	var threads: Array[Thread] = []
	for i in range(4):
		var t := Thread.new()
		t.start(VoxelSlice.native_runs_cfg)
		threads.append(t)
	var results: Array = []
	for t in threads:
		results.append(t.wait_to_finish())
	for cfg in results:
		assert_true(is_same(cfg, results[0]), "every worker gets the same cfg snapshot")
	assert_false((results[0] as Dictionary).is_empty(), "the snapshot is filled")
	assert_true(results[0] == saved, "a refill equals the warmed snapshot")
	assert_true(is_same(VoxelSlice.native_runs_cfg(), results[0]), "later calls get that same snapshot")

## `add_span` merges runs sorted by bottom; with the sort on `bottom` alone a tie fell to the
## (unstable) sort's whim. Two runs that share a bottom now resolve the same whatever their order.
func _test_native_run_ops_order() -> void:
	var a := VoxelRuns.apply_run_ops([], [{"op": "add", "bottom": 1.0, "top": 2.0, "material": "Ferrite"}, {"op": "add", "bottom": 1.0, "top": 1.5, "material": "Soil"}])
	var b := VoxelRuns.apply_run_ops([], [{"op": "add", "bottom": 1.0, "top": 1.5, "material": "Soil"}, {"op": "add", "bottom": 1.0, "top": 2.0, "material": "Ferrite"}])
	assert_true(a == b, "equal-bottom runs resolve to the same list in either insertion order")

func _test_native_files_present() -> void:
	assert_true(FileAccess.file_exists(NativeBuilder.EXTENSION_PATH), "the .gdextension file is committed")
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(NativeBuilder.EXTENSION_PATH), OK, "the .gdextension parses")
	assert_eq(cfg.get_value("configuration", "entry_symbol", ""), "nihon_native_init", "entry symbol")
	for key in ["linux.release.x86_64", "windows.release.x86_64", "macos.release"]:
		assert_true(cfg.has_section_key("libraries", key), "a %s library is declared" % key)

func _test_native_speed_gate_wired() -> void:
	assert_eq(NativeBuilder.NO_NATIVE_ARG, "--no-native", "the fallback switch the speed gate passes")
	assert_true(FileAccess.file_exists("res://tools/check_stream_rate.py") or not FileAccess.file_exists("res://.github/workflows/ci.yml"), "the stream-rate gate script is in the tree")
	var f := FileAccess.open("res://.github/workflows/ci.yml", FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	var live := ""
	for line in text.split("\n"):
		if not line.strip_edges().begins_with("#"):
			live += line + "\n"
	assert_true(live.contains("--playtest-bot --no-native"), "CI runs the playtest bot on the GDScript fallback")
	assert_true(live.contains("check_stream_rate.py playtest/report.json playtest/report-gdscript.json"), "CI checks the native rate against the fallback's")
	assert_true(live.contains("fallback_status"), "CI reads the fallback run's exit status")

func _test_native_build_breakdown() -> void:
	var PB := preload("res://src/tests/playtest_bot.gd")
	var low := PB.build_breakdown({ "heightmap": 2000, "seam": 1000, "runs": 3000, "arrays": 4000 }, 2, 5)
	assert_eq(int(low["window_radius"]), 5, "window radius recorded")
	assert_true(absf(float(low["total_ms"]) - 5.0) < 0.0001, "10 ms over 2 chunks is 5 ms per chunk")
	assert_true(absf(float(low["heightmap_share"]) - 0.2) < 0.0001, "heightmap is 20%")
	assert_eq(low["decision"], "no_shader", "under half: no shader")
	var high := PB.build_breakdown({ "heightmap": 7000, "seam": 1000, "runs": 1000, "arrays": 1000 }, 1, 5)
	assert_eq(high["decision"], "compute_shader", "over half: a shader is justified")
	var empty := PB.build_breakdown({ "heightmap": 0 }, 0, 0)
	assert_eq(empty["decision"], "no_shader", "no time measured: no shader")

func _test_native_release_workflow() -> void:
	var f := FileAccess.open("res://.github/workflows/release.yml", FileAccess.READ)
	if f == null:
		return   # an export does not carry .github; the suite runs from the project tree
	var text := f.get_as_text()
	assert_true(text.contains('tags: ["v*"]'), "the release workflow triggers on v* tags")
	for p in ["linux", "windows", "macos"]:
		assert_true(text.contains("name: " + p), "the release builds the %s binary" % p)
	assert_true(text.contains("gh release create"), "the release workflow creates the GitHub Release")
