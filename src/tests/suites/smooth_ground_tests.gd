extends "res://src/tests/test_support.gd"
## Phase 240 — smooth natural ground: the surface-nets mesher (`VoxelSmooth`), placed blocks kept square,
## the two-tile ring `build_runs` resolves for it, and the step-up that climbs only placed blocks.

const VoxelSmooth := preload("res://src/terrain/voxel_smooth.gd")
const VoxelMesh := preload("res://src/terrain/voxel_mesh.gd")
const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")
const Bot := preload("res://src/tests/playtest_bot.gd")
const StepUpGate := preload("res://src/player/step_up_gate.gd")
const NativeBuilder := preload("res://src/terrain/native_builder.gd")
const GRASS := Color(0.3, 0.6, 0.3)
const STONE := Color(0.5, 0.5, 0.5)

func register() -> void:
	_run_test("smooth ground: a flat column gives a flat surface at the run's top", _test_flat)
	_run_test("smooth ground: a 45 degree ramp of runs gives normals within 5 degrees of the ramp", _test_ramp_normals)
	_run_test("smooth ground: an overhang and a one-tile tunnel give a closed surface", _test_closed)
	_run_test("smooth ground: two neighbouring chunks share their border vertices exactly", _test_seam, true)
	_run_test("smooth ground: 1,000 natural tiles of the pinned seed stand within 0.125 m of their top", _test_pinned_seed_heights, true)
	_run_test("smooth ground: a 3x3 placed wall keeps the block mesher's square faces on smooth ground", _test_placed_wall)
	_run_test("smooth ground: a body walks a 30 degree slope with no step-up, and steps onto a placed block", _test_walk)
	_run_test("smooth ground: build_runs resolves a two-tile ring when asked for pad 2", _test_pad_two)
	_run_test("smooth ground: the native mesher equals the GDScript reference on 24 chunks, edited and with placed blocks", _test_native_parity, true)
	_run_test("smooth ground: the setting routes the game's mesher, on by default", _test_setting)
	# The native build_runs cfg this suite's resolves snapshot is dropped, so a later suite fills its own.
	NativeBuilder.forget_memo("build_runs")

## A resolve table for chunk (0, 0) and its two-tile ring, from `column(gx, gz) -> Array` of runs.
func _table(column: Callable) -> Dictionary:
	var runs := {}
	for gz in range(-VoxelSmooth.PAD, 64 + VoxelSmooth.PAD):
		for gx in range(-VoxelSmooth.PAD, 64 + VoxelSmooth.PAD):
			runs[VoxelConsts.tile_key(Vector2i(gx, gz))] = column.call(gx, gz)
	return { "runs": runs, "deposits": [] }

func _ground(top: float) -> Dictionary:
	return { "bottom": VoxelConsts.BEDROCK_DEPTH, "top": top, "material": "", "color": STONE, "top_color": GRASS }

func _test_flat() -> void:
	var built := VoxelSmooth.build_natural_arrays(Vector2i.ZERO, _flat_heightmap(2.0), _table(func(_x, _z): return [_ground(2.0)]))
	var verts: PackedVector3Array = built["vertices"]
	var normals: PackedVector3Array = built["normals"]
	assert_true(verts.size() > 0, "the flat chunk has a surface")
	var off := 0
	var tilted := 0
	for i in verts.size():
		if absf(verts[i].y - 2.0) > 0.0001:
			off += 1
		if normals[i].angle_to(Vector3.UP) > 0.0001:
			tilted += 1
	assert_eq(off, 0, "every vertex stands at the run's top")
	assert_eq(tilted, 0, "every normal points up")
	assert_eq(int(built["quad_count"]), 64 * 64, "one fan per column top")

func _test_ramp_normals() -> void:
	# A rise of one tile per tile along +X: 0.5 m up per 0.5 m across.
	var built := VoxelSmooth.build_natural_arrays(Vector2i.ZERO, _flat_heightmap(0.0), _table(func(gx, _z): return [_ground(10.0 + gx * 0.5)]))
	var normals: PackedVector3Array = built["normals"]
	var want := Vector3(-1, 1, 0).normalized()
	var worst := 0.0
	for n in normals:
		worst = maxf(worst, rad_to_deg(n.angle_to(want)))
	assert_true(normals.size() > 0, "the ramp has a surface")
	assert_true(worst <= 5.0, "every normal within 5 degrees of the ramp (worst %.2f)" % worst)

## Every edge of the smooth mesh is used by exactly two triangles, once each way, except edges on the
## chunk's open border (both ends in the border cells).
func _assert_closed(built: Dictionary, label: String) -> void:
	var verts: PackedVector3Array = built["vertices"]
	var idx: PackedInt32Array = built["indices"]
	var directed := {}
	for t in range(0, idx.size(), 3):
		for k in 3:
			var a := idx[t + k]
			var b := idx[t + (k + 1) % 3]
			var key := Vector2i(a, b)
			directed[key] = int(directed.get(key, 0)) + 1
	var bad := 0
	var interior := func(p: Vector3) -> bool: return p.x > 0.3 and p.x < 31.7 and p.z > 0.3 and p.z < 31.7
	for key: Vector2i in directed:
		var back := int(directed.get(Vector2i(key.y, key.x), 0))
		if int(directed[key]) == 1 and back == 1:
			continue
		if int(directed[key]) == 1 and back == 0 and not (interior.call(verts[key.x]) and interior.call(verts[key.y])):
			continue   # the chunk's open border
		bad += 1
	assert_eq(bad, 0, label + ": every interior edge is shared by exactly two triangles, wound opposite ways")

func _test_closed() -> void:
	var column := func(gx: int, gz: int) -> Array:
		# A one-tile tunnel along X at z = 20, 1 m tall, inside a hill topped at 4 m.
		if gz == 20 and gx >= 10 and gx <= 40:
			return [{ "bottom": VoxelConsts.BEDROCK_DEPTH, "top": 1.0, "material": "", "color": STONE },
				{ "bottom": 2.0, "top": 4.0, "material": "", "color": STONE, "top_color": GRASS }]
		# A 0.5 m thick overhang ledge, 3x1 tiles, standing out of a cliff at x = 50.
		if gx >= 50:
			return [_ground(8.0)]
		if gx >= 47 and gz >= 40 and gz <= 42:
			return [_ground(4.0), { "bottom": 6.0, "top": 6.5, "material": "", "color": STONE, "top_color": GRASS }]
		return [_ground(4.0)]
	var built := VoxelSmooth.build_natural_arrays(Vector2i.ZERO, _flat_heightmap(4.0), _table(column))
	_assert_closed(built, "tunnel and overhang")
	# The tunnel is there: some vertex inside the hill faces sideways or down at tunnel height.
	var found := false
	var verts: PackedVector3Array = built["vertices"]
	for v in verts:
		if v.z > 10.0 and v.z < 10.5 and v.y > 0.9 and v.y < 2.1 and v.x > 6.0 and v.x < 20.0:
			found = true
			break
	assert_true(found, "the tunnel is meshed")

## The pinned seed's ring input for `chunk`, asking for the two-tile ring.
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

func _seed_noise(seed_v: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(noise, seed_v)
	return noise

## A chunk on the pinned seed with land on it (not flat sea floor), searching along +X from the spawn.
func _land_chunks(seed_v: int, noise: FastNoiseLite, count: int) -> Array:
	var out: Array = []
	var start := TerrainSlice.spawn_point(0.0)
	var c0 := Vector2i(floori(start.x / TerrainSlice.CHUNK_METERS), floori(start.z / TerrainSlice.CHUNK_METERS))
	var i := 0
	while out.size() < count and i < 400:
		var c := c0 + Vector2i(i * 7 % 41 - 20, i * 13 % 37 - 18)
		i += 1
		var hm := TerrainSlice.heightmap_for(c, seed_v, noise)
		var lo := INF
		var hi := -INF
		for h in hm:
			lo = minf(lo, float(h))
			hi = maxf(hi, float(h))
		if hi - lo > 1.0:
			out.append([c, hm])
	return out

func _test_seam() -> void:
	var seed_v := Bot.WORLD_SEED
	var noise := _seed_noise(seed_v)
	ChunkRecordsScript.clear()
	var land := _land_chunks(seed_v, noise, 1)
	assert_eq(land.size(), 1, "a land chunk on the pinned seed")
	if land.is_empty():
		return
	var a_pos: Vector2i = land[0][0]
	var checked := 0
	var mismatched := 0
	for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
		var b_pos := a_pos + step
		var a_hm: Array = land[0][1]
		var b_hm := TerrainSlice.heightmap_for(b_pos, seed_v, noise)
		var a := VoxelSmooth._Mesher.new(a_pos, a_hm, VoxelSlice.build_runs(a_pos, a_hm, _seed_input(a_pos, seed_v, noise))["runs"], false)
		var b := VoxelSmooth._Mesher.new(b_pos, b_hm, VoxelSlice.build_runs(b_pos, b_hm, _seed_input(b_pos, seed_v, noise))["runs"], false)
		a.build()
		b.build()
		# A's last column of cells is B's cell -1: every one A made, B must make identically.
		for along in range(-1, 64):
			for j in range(-200, 2000):
				var key_a := ((j + VoxelSmooth.LEVEL_OFFSET) * VoxelSmooth.SPAN + ((along if step.x == 1 else 63) + VoxelSmooth.PAD)) * VoxelSmooth.SPAN + ((63 if step.x == 1 else along) + VoxelSmooth.PAD)
				if not a.cells.has(key_a):
					continue
				var ia: int = a.cells[key_a]
				var ib: int = b._vertex(-1 if step.x == 1 else along, -1 if step.y == 1 else along, j)
				checked += 1
				if a.vertices[ia] != b.vertices[ib] or a.normals[ia] != b.normals[ib]:
					mismatched += 1
	assert_true(checked > 64, "the border cells were compared (%d)" % checked)
	assert_eq(mismatched, 0, "both chunks put every border vertex and normal in the same place")

func _test_pinned_seed_heights() -> void:
	var seed_v := Bot.WORLD_SEED
	var noise := _seed_noise(seed_v)
	ChunkRecordsScript.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 240
	var worst := 0.0
	var sampled := 0
	var missed := 0
	for entry in _land_chunks(seed_v, noise, 10):
		var c: Vector2i = entry[0]
		var hm: Array = entry[1]
		var resolved := VoxelSlice.build_runs(c, hm, _seed_input(c, seed_v, noise))
		var built := VoxelSmooth.build_natural_arrays(c, hm, resolved, true)
		var verts: PackedVector3Array = built["vertices"]
		var idx: PackedInt32Array = built["indices"]
		# Bucket the triangles by the tiles their XZ box covers.
		var buckets := {}
		for t in range(0, idx.size(), 3):
			var p0 := verts[idx[t]]
			var p1 := verts[idx[t + 1]]
			var p2 := verts[idx[t + 2]]
			for tz in range(floori(minf(p0.z, minf(p1.z, p2.z)) / 0.5), floori(maxf(p0.z, maxf(p1.z, p2.z)) / 0.5) + 1):
				for tx in range(floori(minf(p0.x, minf(p1.x, p2.x)) / 0.5), floori(maxf(p0.x, maxf(p1.x, p2.x)) / 0.5) + 1):
					var key := tz * 1000 + tx
					if not buckets.has(key):
						buckets[key] = []
					buckets[key].append(t)
		for n in 100:
			var tx := rng.randi_range(0, 63)
			var tz := rng.randi_range(0, 63)
			var runs: Array = resolved["runs"][VoxelConsts.tile_key(Vector2i(c.x * 64 + tx, c.y * 64 + tz))]
			var top := float(runs[runs.size() - 1]["top"])
			var centre := Vector2((tx + 0.5) * 0.5, (tz + 0.5) * 0.5)
			var best := -INF
			for t in buckets.get(tz * 1000 + tx, []):
				var h := _tri_height_at(verts[idx[t]], verts[idx[t + 1]], verts[idx[t + 2]], centre)
				if not is_nan(h):
					best = maxf(best, h)
			sampled += 1
			if best == -INF:
				missed += 1
				continue
			worst = maxf(worst, absf(best - top))
	assert_eq(sampled, 1000, "1,000 natural tiles sampled")
	assert_eq(missed, 0, "every sampled tile has ground over its centre")
	assert_true(worst <= 0.125, "the mesh stands within 0.125 m of the column's top (worst %.4f m)" % worst)

func _test_placed_wall() -> void:
	# Gentle natural slope along +Z (0.125 m per tile), and a 3x3 wall of placed blocks on it.
	var column := func(gx: int, gz: int) -> Array:
		var top := 4.0 + gz * 0.125
		var runs: Array = [_ground(top)]
		if gz == 30 and gx >= 30 and gx <= 32:
			runs.append({ "bottom": top, "top": top + 1.5, "material": "Stone", "color": STONE })
		return runs
	var built := VoxelSmooth.build_smooth_arrays(Vector2i.ZERO, _flat_heightmap(4.0), _table(column))
	var verts: PackedVector3Array = built["vertices"]
	var normals: PackedVector3Array = built["normals"]
	var first_placed: int = built["smooth_vertex_count"]
	assert_true(verts.size() > first_placed, "the wall is meshed")
	var axis := 0
	var faces := {}
	for i in range(first_placed, verts.size()):
		var n := normals[i]
		if absf(absf(n.x) + absf(n.y) + absf(n.z) - 1.0) < 0.0001:
			axis += 1
			faces[n] = true
	assert_eq(axis, verts.size() - first_placed, "every placed-block vertex has an axis-aligned normal")
	for n in [Vector3.UP, Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)]:
		assert_true(faces.has(n), "the wall has a face looking %s" % n)
	# The block faces stand on the tile grid: every placed vertex sits on a tile edge in X and Z.
	var on_grid := 0
	for i in range(first_placed, verts.size()):
		var v := verts[i]
		if is_equal_approx(fposmod(v.x, 0.5), 0.0) and is_equal_approx(fposmod(v.z, 0.5), 0.0):
			on_grid += 1
	assert_eq(on_grid, verts.size() - first_placed, "every placed vertex is on the tile grid")
	# The ground around it is smooth: its normals tilt with the slope, not up.
	var tilted := 0
	for i in first_placed:
		if verts[i].z < 12.0 and normals[i].angle_to(Vector3.UP) > deg_to_rad(5.0):
			tilted += 1
	assert_true(tilted > 100, "the natural ground's normals follow the slope (%d tilted)" % tilted)
	# And it does not climb the wall: no smooth vertex inside the wall's footprint above its base.
	var inside := 0
	for i in first_placed:
		var v := verts[i]
		if v.x > 15.05 and v.x < 16.45 and v.z > 15.05 and v.z < 15.45 and v.y > 4.0 + 30 * 0.125 + 0.2:
			inside += 1
	assert_eq(inside, 0, "the smooth ground stops at the wall")

## A collision body over `built`'s triangles, and a capsule body the size of the player's.
func _walk_rig(built: Dictionary) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = VoxelMesh.collision_shape(built["collision"])
	ground.add_child(shape)
	root.add_child(ground)
	var body := CharacterBody3D.new()
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.25
	cap.height = 1.8
	col.shape = cap
	col.position = Vector3(0, 0.9, 0)
	body.add_child(col)
	root.add_child(body)
	return { "root": root, "body": body }

## Walk `body` along +X by `steps` × 0.05 m, sliding on what it hits and settling down after each step
## (the physics frame's `move_and_slide` does not run in the suite). Returns the steepest contact angle.
func _walk(body: CharacterBody3D, steps: int, stop_at_wall: bool) -> float:
	var steepest := 0.0
	for i in steps:
		var motion := Vector3(0.05, 0.0, 0.0)
		for k in 4:
			var hit := body.move_and_collide(motion)
			if hit == null:
				break
			var angle := hit.get_normal().angle_to(Vector3.UP)
			steepest = maxf(steepest, angle)
			if stop_at_wall and angle > body.floor_max_angle:
				return steepest
			motion = hit.get_remainder().slide(hit.get_normal())
		var down := body.move_and_collide(Vector3(0, -0.4, 0))
		if down != null:
			steepest = maxf(steepest, down.get_normal().angle_to(Vector3.UP) if down.get_normal().y > 0.0 else 0.0)
	return steepest

func _test_walk() -> void:
	# A 30 degree natural slope along +X, quantised to the run steps.
	var rise := tan(deg_to_rad(30.0)) * 0.5
	var slope := func(gx: int, _gz: int) -> Array: return [_ground(4.0 + VoxelConsts.voxel_height(maxf(gx - 10, 0) * rise))]
	var rig := _walk_rig(VoxelSmooth.build_smooth_arrays(Vector2i.ZERO, _flat_heightmap(4.0), _table(slope), true))
	var body: CharacterBody3D = rig["body"]
	body.global_position = Vector3(3.0, 4.05, 8.0)
	var steepest := _walk(body, 300, false)
	var climbed := body.global_position.y - 4.0
	assert_true(climbed > 5.0, "the body walked up the slope (%.2f m)" % climbed)
	assert_true(steepest <= body.floor_max_angle, "every contact on the slope is floor, so no step-up fires (%.1f deg)" % rad_to_deg(steepest))
	var ahead: Array = slope.call(40, 16)
	assert_false(StepUpGate.placed_step(ahead, body.global_position.y, PlayerSlice.STEP_UP_HEIGHT), "natural ground never asks for a step-up")
	rig["root"].free()

	# Flat natural ground with a placed block 0.25 m high across the path at x = 10 m.
	var block := func(gx: int, _gz: int) -> Array:
		var runs: Array = [_ground(4.0)]
		if gx >= 20 and gx <= 23:
			runs.append({ "bottom": 4.0, "top": 4.25, "material": "Stone", "color": STONE })
		return runs
	rig = _walk_rig(VoxelSmooth.build_smooth_arrays(Vector2i.ZERO, _flat_heightmap(4.0), _table(block), true))
	body = rig["body"]
	body.global_position = Vector3(8.0, 4.05, 8.0)
	var wall := _walk(body, 100, true)
	assert_true(wall > body.floor_max_angle, "the block's face stops the body as a wall")
	var feet := body.global_position.y
	var tile_ahead: Array = block.call(20, 16)
	assert_true(StepUpGate.placed_step(tile_ahead, feet, PlayerSlice.STEP_UP_HEIGHT), "a placed block a step high allows the step-up")
	var test_move := func(xform: Transform3D, motion: Vector3) -> bool: return body.test_move(xform, motion)
	var start := body.global_transform
	var climbed_xf: Transform3D = PlayerSlice.resolve_step_up(test_move, start, Vector3(0.1, 0, 0), PlayerSlice.STEP_UP_HEIGHT)
	assert_true(climbed_xf.origin.y > start.origin.y + 0.2, "the step-up lifts the body onto the block")
	rig["root"].free()

func _test_pad_two() -> void:
	var seed_v := Bot.WORLD_SEED
	var noise := _seed_noise(seed_v)
	var c := Vector2i(3, -2)
	var hm := TerrainSlice.heightmap_for(c, seed_v, noise)
	var input := _seed_input(c, seed_v, noise)
	var two: Dictionary = VoxelSlice.build_runs(c, hm, input)["runs"]
	assert_eq(two.size(), 68 * 68, "pad 2 resolves the chunk and two tiles round it")
	assert_true(two.has(VoxelConsts.tile_key(Vector2i(c.x * 64 - 2, c.y * 64 + 65))), "a corner of the two-tile ring")
	var gd: Dictionary = VoxelSlice.build_runs_gd(c, hm, input)["runs"]
	assert_eq(gd.size(), two.size(), "the GDScript reference resolves the same ring")
	input["pad"] = 1
	assert_eq((VoxelSlice.build_runs(c, hm, input)["runs"] as Dictionary).size(), 66 * 66, "pad 1 keeps the one-tile ring")

func _test_setting() -> void:
	assert_true(bool(ProjectSettings.get_setting(VoxelSmooth.SETTING, false)), "terrain/smooth_mesh is on in project.godot")
	var table := _table(func(_x, _z): return [_ground(2.0)])
	VoxelSmooth.set_enabled(true)
	assert_eq(VoxelMesh.terrain_pad(), 2, "smooth asks build_runs for the two-tile ring")
	var smooth := VoxelMesh.build_terrain_arrays(Vector2i.ZERO, _flat_heightmap(2.0), table)
	assert_true(smooth.has("smooth_quads"), "on: the game's mesher is the smooth one")
	VoxelSmooth.set_enabled(false)
	assert_eq(VoxelMesh.terrain_pad(), 1, "off: the one-tile ring")
	var blocky := VoxelMesh.build_terrain_arrays(Vector2i.ZERO, _flat_heightmap(2.0), table)
	assert_false(blocky.has("smooth_quads"), "off: the block mesher")
	VoxelSmooth.set_enabled(null)
	assert_true(VoxelSmooth.enabled(), "back to the project setting")

## Edits on chunk `c`: a tunnel, a mined pit, a placed wall and a block on an overhang ledge.
func _parity_edits(c: Vector2i, hm: Array) -> Dictionary:
	var gx := c.x * 64
	var gz := c.y * 64
	var top := VoxelConsts.voxel_height(float(hm[20 * 64 + 20]))
	var edits := {}
	for i in range(8, 30):
		edits[VoxelConsts.tile_key(Vector2i(gx + i, gz + 12))] = [{ "op": "remove", "bottom": top - 3.0, "top": top - 2.0 }]
	for i in range(3):
		for k in range(3):
			edits[VoxelConsts.tile_key(Vector2i(gx + 40 + i, gz + 40 + k))] = [{ "op": "remove", "bottom": top - 1.0, "top": top + 40.0 }]
	for i in range(5):
		var t := VoxelConsts.voxel_height(float(hm[50 * 64 + 20 + i]))
		edits[VoxelConsts.tile_key(Vector2i(gx + 20 + i, gz + 50))] = [{ "op": "add", "bottom": t, "top": t + 1.5, "material": "Stone" }]
	edits[VoxelConsts.tile_key(Vector2i(gx + 63, gz + 5))] = [{ "op": "add", "bottom": top + 2.0, "top": top + 2.5, "material": "" }]
	edits[VoxelConsts.tile_key(Vector2i(gx + 64, gz + 5))] = [{ "op": "add", "bottom": top + 2.5, "top": top + 3.0, "material": "Stone" }]
	return edits

func _test_native_parity() -> void:
	var seed_v := Bot.WORLD_SEED
	var noise := _seed_noise(seed_v)
	ChunkRecordsScript.clear()
	var cases: Array = []
	var i := 0
	for entry in _land_chunks(seed_v, noise, 12):
		var c: Vector2i = entry[0]
		var hm: Array = entry[1]
		var plain := _seed_input(c, seed_v, noise)
		cases.append([c, hm, VoxelSlice.build_runs(c, hm, plain), i % 2 == 0])
		var edited := _seed_input(c, seed_v, noise)
		edited["edits"] = _parity_edits(c, hm)
		cases.append([c, hm, VoxelSlice.build_runs(c, hm, edited), i % 2 == 1])
		i += 1
	assert_native_parity("NativeChunkBuilder", "build_smooth_arrays", cases, VoxelSmooth.build_natural_arrays_gd,
		VoxelSmooth.build_natural_arrays, "build_smooth_arrays")
