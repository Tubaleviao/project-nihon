extends "res://src/tests/test_support.gd"
## Phase 242 — terrain materials: the per-vertex weight function (`TerrainWeights`), the CUSTOM0/CUSTOM1
## arrays a built chunk carries, and the triplanar terrain shader's material (`TerrainMaterial`).

const TerrainWeights := preload("res://src/terrain/terrain_weights.gd")
const TerrainMaterial := preload("res://src/terrain/terrain_material.gd")
const VoxelSmooth := preload("res://src/terrain/voxel_smooth.gd")
const VoxelMesh := preload("res://src/terrain/voxel_mesh.gd")
const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")
const Bot := preload("res://src/tests/playtest_bot.gd")
const NativeBuilder := preload("res://src/terrain/native_builder.gd")
const Hydrology := preload("res://src/terrain/hydrology.gd")

func register() -> void:
	_run_test("terrain materials: the table has a layer per fabric material and resolves every biome", _test_table)
	_run_test("terrain materials: weights sum to 1 over a sweep of slopes, altitudes, water and borders", _test_sum)
	_run_test("terrain materials: ground steeper than the rock slope is mostly rock", _test_rock)
	_run_test("terrain materials: ground above the biome's snow line is mostly snow", _test_snow)
	_run_test("terrain materials: ground at a lake edge is mostly mud, and dry ground has none", _test_wet)
	_run_test("terrain materials: a biome border blends over the same width as the dithered border", _test_border)
	_run_test("terrain materials: packed weights sum to 255 and unpack to the same layers", _test_pack)
	_run_test("terrain materials: a built chunk carries CUSTOM0/CUSTOM1 on every vertex, zero on placed blocks", _test_chunk_arrays)
	_run_test("terrain materials: the native weights equal the GDScript reference on 16 chunks, local and absolute, wet and dry", _test_native_parity, true)
	_run_test("terrain materials: the shader material compiles with every texture array set", _test_shader)
	_run_test("terrain materials: the blend mirror stays finite and sums to 1 on zero weights, black albedo and a zero normal (Phase 285)", _test_blend_mirror)
	_run_test("terrain materials: the shader source holds the guards and a blend_depth minimum above zero (Phase 285)", _test_shader_source_guards)
	_run_test("terrain materials: every layer has height and luminance floors in 0..1 and the material binds them (Phase 285)", _test_height_floors_table)
	_run_test("terrain materials: a map whose darkest 1% is black is rejected for the placeholder, the public maps pass (Phase 285)", _test_dark_map_rejected)
	_run_test("terrain materials: the low quality setting drops to biplanar with no detail, and auto is low on the Compatibility renderer", _test_low_quality)
	_run_test("terrain materials: ground dug below the natural surface draws the dug-ground soil, not turf (Phase 300)", _test_dug_ground_soil)

func _near(a: float, b: float, tol: float, msg: String) -> void:
	assert_true(absf(a - b) <= tol, "%s (%f vs %f)" % [msg, a, b])

func _t() -> Dictionary:
	return TerrainWeights.table()

func _layer(name: String) -> int:
	for e in _t()["layers"]:
		if str(e["name"]) == name:
			return int(e["layer"])
	return -1

func _sum(w: Dictionary) -> float:
	var s := 0.0
	for k in w:
		s += float(w[k])
	return s

func _test_table() -> void:
	var t := _t()
	var layers: Array = t["layers"]
	assert_eq(layers.size(), GameData.TERRAIN_MATERIALS.size(), "one layer per terrain material")
	for i in layers.size():
		assert_eq(int(layers[i]["layer"]), i, "layers are 0..n-1 in order")
	assert_true(layers.size() <= TerrainWeights.LAYERS, "at most eight layers fit the two weight arrays")
	for b in GameData.BIOMES:
		assert_true((t["biome_layer"] as Dictionary).has(b), "biome %s resolves to a material" % b)
	assert_eq(int(t["rock"]), _layer("TerrainRock"), "the slope rule is the rock's")
	assert_eq(int(t["snow"]), _layer("TerrainSnow"), "the snow-line rule is the snow's")
	assert_eq(int(t["wet"]), _layer("TerrainMud"), "the near-water rule is the mud's")

func _test_sum() -> void:
	var t := _t()
	var grounds := [{ "TemperateForest": 1.0 }, { "Taiga": 0.6, "Tundra": 0.4 }, { "Desert": 0.5, "Savanna": 0.3, "Beach": 0.2 }]
	var bad := 0
	var over := 0
	var n := 0
	for g in grounds:
		for slope in [0.0, 20.0, 35.0, 40.0, 48.0, 70.0, 90.0]:
			for alt in [-5.0, 0.0, 50.0, 390.0, 400.0, 700.0, 2000.0]:
				for wd in [0.0, 1.5, 2.9, INF]:
					var w := TerrainWeights.weights(t, g, slope, alt, wd)
					n += 1
					if absf(_sum(w) - 1.0) > 1e-5:
						bad += 1
					if w.size() > TerrainWeights.SLOTS:
						over += 1
	assert_eq(bad, 0, "every one of %d weight sets sums to 1" % n)
	assert_eq(over, 0, "no vertex blends more than four materials")

func _test_rock() -> void:
	var t := _t()
	var rock := _layer("TerrainRock")
	var steep := float(t["rock_slope"]) + TerrainWeights.SLOPE_BAND
	for b in ["TemperateForest", "Desert", "Alpine"]:
		var w := TerrainWeights.weights(t, { b: 1.0 }, steep + 1.0, 50.0, INF)
		assert_true(float(w.get(rock, 0.0)) > 0.9, "%s ground at %.0f° is mostly rock (%.2f)" % [b, steep + 1.0, float(w.get(rock, 0.0))])
	var flat := TerrainWeights.weights(t, { "TemperateForest": 1.0 }, 5.0, 50.0, INF)
	assert_eq(float(flat.get(rock, 0.0)), 0.0, "flat forest ground has no rock")
	assert_true(float(flat.get(_layer("TerrainGrass"), 0.0)) > 0.99, "flat forest ground is grass")

func _test_snow() -> void:
	var t := _t()
	var snow := _layer("TerrainSnow")
	var line := float((t["snow_line"] as Dictionary)["Taiga"])
	assert_true(line < TerrainWeights.NO_LINE, "the taiga has a snow line")
	var above := TerrainWeights.weights(t, { "Taiga": 1.0 }, 5.0, line + TerrainWeights.SNOW_BAND + 5.0, INF)
	assert_true(float(above.get(snow, 0.0)) > 0.9, "taiga ground above its snow line is mostly snow (%.2f)" % float(above.get(snow, 0.0)))
	var below := TerrainWeights.weights(t, { "Taiga": 1.0 }, 5.0, line - TerrainWeights.SNOW_BAND - 5.0, INF)
	assert_eq(float(below.get(snow, 0.0)), 0.0, "taiga ground below its snow line has no snow")
	var desert := TerrainWeights.weights(t, { "Desert": 1.0 }, 5.0, 900.0, INF)
	assert_eq(float(desert.get(snow, 0.0)), 0.0, "a biome with no snow line never snows")
	# Review: at a border with a biome that has no snow line, the snowy side keeps its own share of
	# snow (the lines are not averaged, which put a lineless neighbour's 100 km into the mean).
	var border := TerrainWeights.weights(t, { "Taiga": 0.8, "Desert": 0.2 }, 5.0, line + TerrainWeights.SNOW_BAND + 5.0, INF)
	_near(float(border.get(snow, 0.0)), 0.8, 1e-6, "taiga's share of a border above its snow line is snow")

func _test_wet() -> void:
	var t := _t()
	var mud := _layer("TerrainMud")
	var lake := { "lakes": [{ "x": 0.0, "z": 0.0, "r": 10.0, "surface": 5.0, "depth": 2.0 }], "segs": [] }
	assert_eq(TerrainWeights.water_distance(lake, 5.0, 0.0), 0.0, "inside the lake: distance 0")
	_near(TerrainWeights.water_distance(lake, 12.0, 0.0), 2.0, 1e-4, "2 m outside the lake's edge")
	var edge := TerrainWeights.weights(t, { "TemperateForest": 1.0 }, 5.0, 10.0, 0.0)
	assert_true(float(edge.get(mud, 0.0)) > 0.9, "ground at the lake edge is mostly mud")
	var dry := TerrainWeights.weights(t, { "TemperateForest": 1.0 }, 5.0, 10.0, TerrainWeights.water_distance(lake, 40.0, 0.0))
	assert_eq(float(dry.get(mud, 0.0)), 0.0, "ground 30 m from the lake has no mud")

func _test_border() -> void:
	assert_eq(TerrainWeights.BLEND_TILES, VoxelSlice.BLEND_TILES, "the weights blend over the dithered border's width")
	var extent := float(VoxelConsts.CHUNK_SIZE) * VoxelConsts.TILE_SIZE
	var biomes := { VoxelSlice._chunk_key(Vector2i(0, 0)): "TemperateForest", VoxelSlice._chunk_key(Vector2i(1, 0)): "Desert",
		VoxelSlice._chunk_key(Vector2i(0, 1)): "TemperateForest", VoxelSlice._chunk_key(Vector2i(1, 1)): "Desert",
		VoxelSlice._chunk_key(Vector2i(0, -1)): "TemperateForest", VoxelSlice._chunk_key(Vector2i(1, -1)): "Desert" }
	var mid := extent * 0.5
	var at := TerrainWeights.biome_weights(Vector2(extent - 0.001, mid), biomes)
	_near(float(at.get("Desert", 0.0)), 0.5, 0.01, "at the border the two biomes weigh half each")
	var band := TerrainWeights.BLEND_TILES * VoxelConsts.TILE_SIZE
	for d_tiles in [0.5, 1.0, 2.0, 3.0, 3.9]:
		var w := TerrainWeights.biome_weights(Vector2(extent - d_tiles * VoxelConsts.TILE_SIZE, mid), biomes)
		_near(float(w.get("Desert", 0.0)), BiomeBlend.chance(d_tiles, TerrainWeights.BLEND_TILES), 1e-4,
			"%.1f tiles in, the neighbour weighs the dither's chance" % d_tiles)
	var past := TerrainWeights.biome_weights(Vector2(extent - band - 0.01, mid), biomes)
	assert_eq(past.get("Desert", 0.0), 0.0, "past the band the neighbour weighs nothing")
	assert_eq(past.get("TemperateForest", 0.0), 1.0, "and the own biome everything")

func _test_pack() -> void:
	var w0 := PackedByteArray()
	var w1 := PackedByteArray()
	w0.resize(8)
	w1.resize(8)
	var src := { 0: 0.333, 3: 0.333, 5: 0.334 }
	TerrainWeights.pack(src, w0, w1, 1)
	var total := 0
	for i in range(4, 8):
		total += w0[i] + w1[i]
	assert_eq(total, 255, "the eight channels of a vertex sum to 255")
	assert_eq(w0[0] + w0[1] + w0[2] + w0[3] + w1[0] + w1[1] + w1[2] + w1[3], 0, "the other vertex is untouched")
	var back := TerrainWeights.unpack(w0, w1, 1)
	assert_eq(back.keys().size(), 3, "three layers come back")
	assert_true(back.has(5) and w1[5 - 4 + 4] > 0, "layer 5 lives in CUSTOM1")

func _seed_input(chunk: Vector2i, seed_v: int, noise: FastNoiseLite) -> Dictionary:
	var neighbours := {}
	var biomes := {}
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var c := Vector2i(chunk.x + dx, chunk.y + dz)
			biomes[VoxelSlice._chunk_key(c)] = TerrainSlice.biome_for_chunk(c, seed_v)
			if dx != 0 or dz != 0:
				neighbours[VoxelSlice._chunk_key(c)] = TerrainSlice.heightmap_for(c, seed_v, noise)
	return { "edits": {}, "neighbour_heightmaps": neighbours, "biomes": biomes, "seed": seed_v, "depleted": {}, "pad": 2 }

func _test_chunk_arrays() -> void:
	var seed_v := Bot.WORLD_SEED
	var noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(noise, seed_v)
	var start := TerrainSlice.spawn_point(0.0)
	var c := Vector2i(floori(start.x / TerrainSlice.CHUNK_METERS), floori(start.z / TerrainSlice.CHUNK_METERS))
	var hm := TerrainSlice.heightmap_for(c, seed_v, noise)
	var input := _seed_input(c, seed_v, noise)
	var built := VoxelMesh.build_terrain_arrays(c, hm, VoxelSlice.build_runs(c, hm, input), true)
	var n := (built["vertices"] as PackedVector3Array).size()
	assert_true(n > 0, "the spawn chunk has ground")
	TerrainWeights.apply(built, c, input["biomes"], seed_v)
	var w0: PackedByteArray = built["custom0"]
	var w1: PackedByteArray = built["custom1"]
	assert_eq(w0.size(), n * 4, "CUSTOM0 has four channels per vertex")
	assert_eq(w1.size(), n * 4, "CUSTOM1 has four channels per vertex")
	var natural := int(built["smooth_vertex_count"])
	var off := 0
	for i in natural:
		var s := 0
		for k in 4:
			s += w0[i * 4 + k] + w1[i * 4 + k]
		if s != 255:
			off += 1
	assert_eq(off, 0, "every one of %d natural vertices has weights summing to 255" % natural)
	var mesh := VoxelMesh.mesh_from_arrays(built)
	var fmt := mesh.surface_get_format(0)
	assert_true(fmt & Mesh.ARRAY_FORMAT_CUSTOM0 and fmt & Mesh.ARRAY_FORMAT_CUSTOM1, "the chunk mesh carries CUSTOM0 and CUSTOM1")
	var arrays := mesh.surface_get_arrays(0)
	assert_eq((arrays[Mesh.ARRAY_CUSTOM0] as PackedByteArray).size(), n * 4, "the mesh's CUSTOM0 covers every vertex")
	# A placed block's vertices (after smooth_vertex_count) weigh nothing: the shader draws their colour.
	var placed := { "vertices": PackedVector3Array([Vector3(1, 1, 1), Vector3(2, 1, 1), Vector3(1, 2, 1)]),
		"normals": PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP]), "smooth_vertex_count": 1, "local": true }
	TerrainWeights.apply(placed, c, input["biomes"], seed_v)
	var ps: PackedByteArray = placed["custom0"]
	var ps1: PackedByteArray = placed["custom1"]
	var tail := 0
	for i in range(4, 12):
		tail += ps[i] + ps1[i]
	assert_eq(tail, 0, "vertices past smooth_vertex_count (placed blocks) weigh zero")

func _test_shader() -> void:
	var mat := TerrainMaterial.make(Color(0.9, 0.95, 1.0))
	var names := {}
	for u in mat.shader.get_shader_uniform_list():
		names[str(u["name"])] = true
	for u in ["albedo_maps", "normal_maps", "roughness_maps", "layer_scale", "tint", "biplanar", "detail", "surface_maps"]:
		assert_true(names.has(u), "the terrain shader compiles and declares '%s'" % u)
	var layers := GameData.TERRAIN_MATERIALS.size()
	for map in TerrainMaterial.MAPS:
		var arr: Variant = mat.get_shader_parameter("%s_maps" % map)
		assert_true(arr is Texture2DArray, "%s_maps is set to a texture array" % map)
		if arr is Texture2DArray:
			assert_eq((arr as Texture2DArray).get_layers(), layers, "%s_maps has a layer per terrain material" % map)
			assert_eq((arr as Texture2DArray).get_width(), TerrainMaterial.SIZE, "%s_maps is 1K" % map)
	var scales: PackedFloat32Array = mat.get_shader_parameter("layer_scale")
	assert_eq(scales.size(), TerrainWeights.LAYERS, "a scale per weight channel")
	_near(scales[_layer("TerrainRock")], 6.4, 1e-4, "the rock's scale comes from the fabric")
	assert_true(TerrainMaterial.tint_of(mat).is_equal_approx(Color(0.9, 0.95, 1.0)), "the tint is set")
	# The maps resolve through AssetOverlay: the public CC0 file is what loads without the pack.
	var img: Image = AssetOverlay.load_image("textures/terrain/grass_albedo.jpg.raw")
	assert_true(img != null and img.get_width() == 1024, "a JPEG terrain map decodes through AssetOverlay")

func _test_low_quality() -> void:
	var was: Variant = ProjectSettings.get_setting(TerrainMaterial.QUALITY_SETTING, TerrainMaterial.QUALITY_HIGH)
	assert_eq(int(was), TerrainMaterial.QUALITY_AUTO, "the shipped setting is auto")
	assert_eq(TerrainMaterial.quality_for(TerrainMaterial.QUALITY_AUTO, "gl_compatibility"), TerrainMaterial.QUALITY_LOW, "auto is low on the Compatibility renderer")
	assert_eq(TerrainMaterial.quality_for(TerrainMaterial.QUALITY_AUTO, "forward_plus"), TerrainMaterial.QUALITY_HIGH, "auto is high on Forward+")
	assert_eq(TerrainMaterial.quality_for(TerrainMaterial.QUALITY_HIGH, "gl_compatibility"), TerrainMaterial.QUALITY_HIGH, "an explicit high holds on any renderer")
	ProjectSettings.set_setting(TerrainMaterial.QUALITY_SETTING, TerrainMaterial.QUALITY_LOW)
	var low := TerrainMaterial.make()
	ProjectSettings.set_setting(TerrainMaterial.QUALITY_SETTING, was)
	assert_true(bool(low.get_shader_parameter("biplanar")), "low quality samples biplanar")
	assert_false(bool(low.get_shader_parameter("detail")), "low quality has no detail texture")
	assert_false(bool(low.get_shader_parameter("surface_maps")), "low quality samples albedo only")
	assert_true(low.shader == TerrainMaterial.LOW_SHADER, "low quality uses the lean shader")
	var low_names := {}
	for u in low.shader.get_shader_uniform_list():
		low_names[str(u["name"])] = true
	for u in ["albedo_maps", "layer_scale", "tint"]:
		assert_true(low_names.has(u), "the lean shader compiles and declares '%s'" % u)
	assert_eq((low.get_shader_parameter("albedo_maps") as Texture2DArray).get_width(), TerrainMaterial.LOW_SIZE, "low quality binds the small arrays")
	ProjectSettings.set_setting(TerrainMaterial.QUALITY_SETTING, TerrainMaterial.QUALITY_HIGH)
	var high := TerrainMaterial.make()
	ProjectSettings.set_setting(TerrainMaterial.QUALITY_SETTING, was)
	assert_false(bool(high.get_shader_parameter("biplanar")), "high quality samples triplanar")
	assert_true(bool(high.get_shader_parameter("detail")), "high quality fades in the detail texture")
	assert_true(bool(high.get_shader_parameter("surface_maps")), "high quality samples the normal and roughness maps")

## Land chunks round the spawn on the pinned seed, and among them up to `wet_count` that hold water features.
func _parity_chunks(seed_v: int, noise: FastNoiseLite, dry_count: int, wet_count: int) -> Array:
	var start := TerrainSlice.spawn_point(0.0)
	var c0 := Vector2i(floori(start.x / TerrainSlice.CHUNK_METERS), floori(start.z / TerrainSlice.CHUNK_METERS))
	var dry: Array = []
	var wet: Array = []
	var i := 0
	while (dry.size() < dry_count or wet.size() < wet_count) and i < 2000:
		var c := c0 + Vector2i(i * 7 % 61 - 30, i * 13 % 59 - 29) * (1 + i / 400)
		i += 1
		var f := Hydrology.features_for_chunk(c, seed_v)
		var has_water := not (f["lakes"] as Array).is_empty() or not (f["segs"] as Array).is_empty()
		if has_water and wet.size() < wet_count:
			wet.append(c)
		elif not has_water and dry.size() < dry_count:
			dry.append(c)
	return dry + wet

func _test_native_parity() -> void:
	var seed_v := Bot.WORLD_SEED
	var noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(noise, seed_v)
	var chunks := _parity_chunks(seed_v, noise, 10, 6)
	assert_true(chunks.size() >= 12, "found parity chunks, some with water (%d)" % chunks.size())
	var cases: Array = []
	var k := 0
	for c: Vector2i in chunks:
		var hm := TerrainSlice.heightmap_for(c, seed_v, noise)
		var input := _seed_input(c, seed_v, noise)
		var local := k % 2 == 0
		k += 1
		var built := VoxelMesh.build_terrain_arrays(c, hm, VoxelSlice.build_runs(c, hm, input), local)
		cases.append([built["vertices"], built["normals"], int(built["smooth_vertex_count"]),
			TerrainWeights.native_params(c, local, input["biomes"], seed_v), c, input["biomes"], seed_v, local])
	var reference := func(verts, normals, natural, _params, c, biomes, sv, local) -> Array:
		var b := { "vertices": verts, "normals": normals, "smooth_vertex_count": natural, "local": local }
		TerrainWeights.apply_gd(b, c, biomes, sv)
		return [b["custom0"], b["custom1"]]
	var native := func(verts, normals, natural, params, _c, _biomes, _sv, _local) -> Array:
		return NativeBuilder.builder().call("terrain_weights", verts, normals, natural, params)
	assert_native_parity("NativeChunkBuilder", "terrain_weights", cases, reference, native, "terrain_weights")


# --- Phase 285: ground without black spots ------------------------------------------------------------------------

const TerrainBlend := preload("res://src/terrain/terrain_blend.gd")

func _grey_layers(v: float) -> Array:
	var a := []
	for i in TerrainBlend.LAYERS:
		a.append(Vector3(v, v, v))
	return a

func _up_normals() -> Array:
	var a := []
	for i in TerrainBlend.LAYERS:
		a.append(Vector3.UP)
	return a

func _floors(v: float) -> Array:
	var a := []
	for i in TerrainBlend.LAYERS:
		a.append(v)
	return a

func _finite_unit_sum(r: Dictionary, label: String) -> void:
	var total := 0.0
	var finite := true
	for w in r["weights"] as PackedFloat32Array:
		finite = finite and is_finite(w)
		total += w
	var n: Vector3 = r["normal"]
	var a: Vector3 = r["albedo"]
	assert_true(finite and absf(total - 1.0) < 1e-4, "%s: finite weights summing to 1 (%f)" % [label, total])
	assert_true(is_finite(n.x) and is_finite(n.y) and is_finite(n.z) and absf(n.length() - 1.0) < 1e-4, "%s: a unit normal" % label)
	assert_true(is_finite(a.x) and is_finite(a.y) and is_finite(a.z), "%s: a finite albedo" % label)

func _test_blend_mirror() -> void:
	var zeros := []
	zeros.resize(TerrainBlend.LAYERS)
	zeros.fill(0.0)
	_finite_unit_sum(TerrainBlend.blend(zeros, _grey_layers(0.5), _up_normals(), _floors(0.2), 0.2), "zero vertex weights")
	var grass := zeros.duplicate()
	grass[0] = 1.0
	var black := TerrainBlend.blend(grass, _grey_layers(0.0), _up_normals(), _floors(0.2), 0.2)
	_finite_unit_sum(black, "all-black albedo")
	assert_true(black["weights"][0] > 0.99, "all-black albedo: the layer with weight still wins")
	var cancel := _up_normals()
	cancel[0] = Vector3.UP
	cancel[1] = Vector3.DOWN
	var two := zeros.duplicate()
	two[0] = 0.5
	two[1] = 0.5
	var flat := TerrainBlend.blend(two, _grey_layers(0.5), cancel, _floors(0.2), 0.2, Vector3(0, 0.8, 0.6))
	_finite_unit_sum(flat, "cancelling normals")
	assert_true((flat["normal"] as Vector3).distance_to(Vector3(0, 0.8, 0.6)) < 1e-4, "a zero normal falls back to the geometric one")
	_finite_unit_sum(TerrainBlend.blend(grass, _grey_layers(0.0), [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO,
		Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO], _floors(0.0), 0.0), "zero normal, zero floor, zero depth")
	# Every weight at or below the cut: the heaviest layer is drawn alone, not black.
	var faint := zeros.duplicate()
	faint[1] = 0.4
	faint[2] = 0.3
	faint[3] = 0.3
	var albedos := _grey_layers(0.5)
	albedos[1] = Vector3(0.2, 0.6, 0.2)
	var r := TerrainBlend.blend(faint, albedos, _up_normals(), _floors(0.2), 0.01, Vector3.UP, 0.5)
	_finite_unit_sum(r, "every weight at or below the cut")
	assert_eq(TerrainBlend.heaviest(faint), 1, "the heaviest layer is layer 1")
	assert_true(r["weights"][1] > 0.99 and (r["albedo"] as Vector3).distance_to(albedos[1]) < 1e-4, "that layer is drawn alone")
	# A dark layer with a height floor keeps its share against a brighter one.
	var both := zeros.duplicate()
	both[0] = 0.5
	both[1] = 0.5
	var mixed := _grey_layers(0.9)
	mixed[0] = Vector3.ZERO
	var kept := TerrainBlend.blend(both, mixed, _up_normals(), _floors(0.9), 0.2)
	assert_true(kept["weights"][0] > 0.1, "a floored dark layer still counts in the blend")

func _test_shader_source_guards() -> void:
	var src := FileAccess.get_file_as_string("res://src/terrain/terrain_material.gdshader")
	assert_true(src.contains("sum = max(sum, 1e-4);"), "the blend sum is guarded")
	assert_true(src.contains("length(nrm) > 1e-4 ? normalize(nrm) : n"), "a cancelled normal falls back")
	assert_true(src.contains("i == best"), "the heaviest layer passes the weight cut")
	var re := RegEx.create_from_string("uniform float blend_depth\\s*:\\s*hint_range\\(\\s*([0-9.]+)")
	var m := re.search(src)
	assert_true(m != null and float(m.get_string(1)) > 0.0, "blend_depth has a minimum above zero")
	assert_true(src.contains("layer_height_floor[i]"), "the blend height is floored per layer")
	var low := FileAccess.get_file_as_string("res://src/terrain/terrain_material_low.gdshader")
	assert_false(low.contains("b /= b.x + b.y + b.z;"), "the low shader divides guarded")

func _test_height_floors_table() -> void:
	for e in _t()["layers"]:
		for f in ["height_floor", "min_mean", "min_dark"]:
			var v := float(e[f])
			assert_true(v >= 0.0 and v <= 1.0, "%s: %s is in 0..1" % [e["name"], f])
	var mat := TerrainMaterial.make()
	var floors: PackedFloat32Array = mat.get_shader_parameter("layer_height_floor")
	assert_eq(floors.size(), TerrainWeights.LAYERS, "the material carries a floor per layer")

func _test_dark_map_rejected() -> void:
	var grass: Dictionary = {}
	for e in _t()["layers"]:
		if str(e["name"]) == "TerrainGrass":
			grass = e
	var rel := "%s_albedo.jpg.raw" % grass["key"]
	var placeholder := Image.new()
	assert_eq(placeholder.load_jpg_from_buffer(FileAccess.get_file_as_bytes("res://assets/" + rel)), OK, "the grass placeholder decodes")
	assert_eq(TerrainMaterial.map_rejection(placeholder, float(grass["min_mean"]), float(grass["min_dark"])), "", "the public grass placeholder passes")
	for e in _t()["layers"]:
		var img := Image.new()
		img.load_jpg_from_buffer(FileAccess.get_file_as_bytes("res://assets/%s_albedo.jpg.raw" % e["key"]))
		assert_eq(TerrainMaterial.map_rejection(img, float(e["min_mean"]), float(e["min_dark"])), "", "the public %s placeholder passes" % e["name"])
	# A synthetic map, bright but with 2% black texels: refused, the placeholder is used.
	var broken := Image.create(256, 256, false, Image.FORMAT_RGB8)
	broken.fill(Color(0.4, 0.6, 0.3))
	broken.fill_rect(Rect2i(0, 0, 256, 6), Color.BLACK)
	assert_true(TerrainMaterial.map_rejection(broken, float(grass["min_mean"]), float(grass["min_dark"])).contains("darkest 1%"), "black darkest 1% is rejected")
	var used := TerrainMaterial.checked_albedo(broken, rel, float(grass["min_mean"]), float(grass["min_dark"]))
	assert_eq([used.get_width(), used.get_height()], [placeholder.get_width(), placeholder.get_height()], "the placeholder replaces it")
	assert_true(used != broken, "not the broken image")
	# A map that is dark overall is refused too; a good map passes through untouched.
	var dim := Image.create(64, 64, false, Image.FORMAT_RGB8)
	dim.fill(Color(0.02, 0.02, 0.02))
	assert_true(TerrainMaterial.map_rejection(dim, float(grass["min_mean"]), 0.0).contains("mean luminance"), "a dark map is rejected on its mean")
	assert_true(TerrainMaterial.checked_albedo(placeholder, rel, float(grass["min_mean"]), float(grass["min_dark"])) == placeholder, "a good map is kept")

## Phase 300 (owner, 2026-11-28): a finished dig shows soil, not the grass that was on top. A vertex in a tile
## with a `remove` edit, a step or more below its natural top, is all dug-ground soil; the top of that tile and
## an undug tile keep their turf.
func _test_dug_ground_soil() -> void:
	var t := TerrainWeights.table()
	var dug := int(t["dug"])
	assert_true(dug >= 0, "one terrain material covers dug ground")
	assert_eq(str(t["layers"][dug]["name"]), "TerrainDirt", "dug ground is the dirt layer")
	var n := VoxelConsts.CHUNK_SIZE
	var heightmap: Array = []
	heightmap.resize(n * n)
	heightmap.fill(2.0)
	var grass := TerrainWeights.biome_layer(t, "TemperateForest")
	var verts := PackedVector3Array([Vector3(2.6, 1.5, 2.6), Vector3(2.6, 2.0, 2.6), Vector3(10.1, 1.5, 10.1)])
	var w0 := PackedByteArray()
	var w1 := PackedByteArray()
	w0.resize(verts.size() * 4)
	w1.resize(verts.size() * 4)
	for i in verts.size():
		TerrainWeights.pack({ grass: 1.0 }, w0, w1, i)
	var built := { "vertices": verts, "custom0": w0.duplicate(), "custom1": w1.duplicate(), "smooth_vertex_count": verts.size() }
	var gathered := { "edits": { "5,5": [{ "op": "remove", "bottom": 1.5, "top": 2.0 }] } }
	TerrainWeights.apply_dug(built, Vector2i.ZERO, heightmap, gathered)
	var pit := TerrainWeights.unpack(built["custom0"], built["custom1"], 0)
	assert_true(float(pit.get(dug, 0.0)) > 0.99, "the pit floor is soil (%s)" % str(pit))
	assert_true(float(pit.get(grass, 0.0)) < 0.01, "and no longer grass")
	var top := TerrainWeights.unpack(built["custom0"], built["custom1"], 1)
	assert_true(float(top.get(grass, 0.0)) > 0.99, "the dug tile's untouched top stays grass")
	var other := TerrainWeights.unpack(built["custom0"], built["custom1"], 2)
	assert_true(float(other.get(grass, 0.0)) > 0.99, "an undug tile stays grass")
	var local := { "vertices": PackedVector3Array([Vector3(2.6, 1.5, 2.6)]), "custom0": PackedByteArray([255, 0, 0, 0]),
		"custom1": PackedByteArray([0, 0, 0, 0]), "smooth_vertex_count": 1, "local": true }
	TerrainWeights.apply_dug(local, Vector2i(1, 0), heightmap, { "edits": { "%d,5" % (n + 5): [{ "op": "remove", "bottom": 1.5, "top": 2.0 }] } })
	assert_true(float(TerrainWeights.unpack(local["custom0"], local["custom1"], 0).get(dug, 0.0)) > 0.99, "a chunk-local build finds its dug tile too")
	var placed := { "vertices": verts, "custom0": w0.duplicate(), "custom1": w1.duplicate(), "smooth_vertex_count": verts.size() }
	TerrainWeights.apply_dug(placed, Vector2i.ZERO, heightmap, { "edits": { "5,5": [{ "op": "add", "bottom": 2.0, "top": 2.5, "material": "Concrete" }] } })
	assert_true(float(TerrainWeights.unpack(placed["custom0"], placed["custom1"], 0).get(grass, 0.0)) > 0.99, "a placed block alone digs nothing")
	# A missing neighbour comes as a seam strip: full size, null past its edge rows. A dug tile deep in it has no
	# height here and is skipped, not read as a number (CI: "Nonexistent 'float' constructor" in dug_tops).
	var strip: Array = []
	strip.resize(n * n)
	for tx in n:
		strip[tx] = 2.0
	var tops := TerrainWeights.dug_tops(Vector2i.ZERO, heightmap,
		{ "%d,0" % (n + 3): [{ "op": "remove" }], "%d,9" % (n + 3): [{ "op": "remove" }] }, { "1,0": strip })
	assert_eq(tops.keys(), ["%d,0" % (n + 3)], "a strip's filled row counts, its null rows are left out")
