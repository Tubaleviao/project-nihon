extends "res://src/tests/test_support.gd"
## Phase 193 — the voxel ray (aim, mine and build read the columns, not the collision a walking body keeps
## only on its own 3×3 chunks) and the dive guard (a step never carries the feet below the ground under
## them; feet that end inside solid ground go back onto its top).

const VoxelRay := preload("res://src/terrain/voxel_ray.gd")
const NearRing := preload("res://src/terrain/near_ring.gd")
const DiveGuard := preload("res://src/player/dive_guard.gd")

func register() -> void:
	_run_test("voxel ray: straight down lands on the column top", _test_ray_down)
	_run_test("voxel ray: a slanted ray lands where it meets the top", _test_ray_slanted)
	_run_test("voxel ray: a horizontal ray stops on a wall's side face", _test_ray_wall)
	_run_test("voxel ray: an upward ray hits an overhang's underside", _test_ray_overhang)
	_run_test("voxel ray: a ray starting inside a run hits the next face, not that run", _test_ray_starts_inside)
	_run_test("voxel ray: nothing within range is a miss", _test_ray_miss)
	_run_test("voxel ray: far from the origin it still hits the right tile", _test_ray_far_from_origin)
	_run_test("voxel ray: a tile the ray stays above never reads its runs", _test_ray_top_reject)
	_run_test("voxel ray: the player's aim reads a built chunk's runs", _test_ray_on_voxel_slice)
	_run_test("dive guard: a step drops at most to the ground under the feet", _test_descent_room)
	_run_test("dive guard: feet inside solid ground go back onto its top", _test_buried_lift)
	_run_test("near: a walking body keeps collision one ring out, full detail two", _test_collision_radius)

## A world of columns: `tops` maps a tile to its runs (`[[bottom, top], ...]`); every other tile is ground at `ground`.
func _world(tops: Dictionary, ground: float) -> Array:
	var runs_at := func(t: Vector2i) -> Array:
		var spec: Array = tops.get(t, [[VoxelSlice.BEDROCK_DEPTH, ground]])
		var out: Array = []
		for r in spec:
			out.append({ "bottom": float(r[0]), "top": float(r[1]) })
		return out
	var top_at := func(t: Vector2i) -> float:
		var spec: Array = tops.get(t, [[VoxelSlice.BEDROCK_DEPTH, ground]])
		return float(spec[-1][1])
	return [runs_at, top_at]

func _cast(from: Vector3, dir: Vector3, dist: float, world: Array, offset := Vector3.ZERO) -> Dictionary:
	return VoxelRay.cast(from, dir, dist, offset, world[0], world[1])

func _near(a: Vector3, b: Vector3) -> bool:
	return a.distance_to(b) < 0.001

func _test_ray_down() -> void:
	var hit := _cast(Vector3(0.25, 20.0, 0.25), Vector3.DOWN, 60.0, _world({}, 10.0))
	assert_false(hit.is_empty(), "the ray hits the ground")
	assert_true(_near(hit["position"], Vector3(0.25, 10.0, 0.25)), "on the column top (%s)" % str(hit.get("position")))
	assert_eq(hit["normal"], Vector3.UP, "the top faces up")
	assert_true(absf(float(hit["distance"]) - 10.0) < 0.001, "10 m down")

func _test_ray_slanted() -> void:
	var dir := Vector3(1.0, -1.0, 0.0).normalized()
	var hit := _cast(Vector3(0.1, 20.0, 0.1), dir, 60.0, _world({}, 10.0))
	assert_true(_near(hit.get("position", Vector3.ZERO), Vector3(10.1, 10.0, 0.1)), "a 45° ray meets the top 10 m along (%s)" % str(hit.get("position")))
	assert_eq(hit.get("normal"), Vector3.UP, "on the top face")

func _test_ray_wall() -> void:
	var world := _world({ Vector2i(4, 0): [[VoxelSlice.BEDROCK_DEPTH, 30.0]] }, 10.0)
	var hit := _cast(Vector3(0.25, 15.0, 0.25), Vector3(1, 0, 0), 60.0, world)
	assert_true(_near(hit.get("position", Vector3.ZERO), Vector3(2.0, 15.0, 0.25)), "on tile 4's west face at x 2 m (%s)" % str(hit.get("position")))
	assert_eq(hit.get("normal"), Vector3(-1, 0, 0), "the face looks back at the ray")
	var back := _cast(Vector3(4.25, 15.0, 0.25), Vector3(-1, 0, 0), 60.0, world)
	assert_true(_near(back.get("position", Vector3.ZERO), Vector3(2.5, 15.0, 0.25)), "from the east, its east face at x 2.5 m")
	assert_eq(back.get("normal"), Vector3(1, 0, 0), "facing east")
	var north := _cast(Vector3(2.25, 15.0, -3.0), Vector3(0, 0, 1), 60.0, world)
	assert_eq(north.get("normal"), Vector3(0, 0, -1), "along Z, the face looks back at it too")

func _test_ray_overhang() -> void:
	var world := _world({ Vector2i(0, 0): [[VoxelSlice.BEDROCK_DEPTH, 10.0], [20.0, 25.0]] }, 10.0)
	var hit := _cast(Vector3(0.25, 15.0, 0.25), Vector3.UP, 60.0, world)
	assert_true(_near(hit.get("position", Vector3.ZERO), Vector3(0.25, 20.0, 0.25)), "on the overhang's underside")
	assert_eq(hit.get("normal"), Vector3.DOWN, "facing down")
	var down := _cast(Vector3(0.25, 15.0, 0.25), Vector3.DOWN, 60.0, world)
	assert_true(_near(down.get("position", Vector3.ZERO), Vector3(0.25, 10.0, 0.25)), "and down from the gap, the floor below it")

func _test_ray_starts_inside() -> void:
	var world := _world({ Vector2i(0, 0): [[VoxelSlice.BEDROCK_DEPTH, 10.0], [20.0, 25.0]] }, 10.0)
	var hit := _cast(Vector3(0.25, 5.0, 0.25), Vector3.UP, 60.0, world)
	assert_true(_near(hit.get("position", Vector3.ZERO), Vector3(0.25, 20.0, 0.25)), "the run it starts in is not hit; the next face is")
	var side := _cast(Vector3(0.25, 5.0, 0.25), Vector3(1, 0, 0), 60.0, world)
	assert_true(_near(side.get("position", Vector3.ZERO), Vector3(0.5, 5.0, 0.25)), "sideways, the next tile's face (%s)" % str(side.get("position")))

func _test_ray_miss() -> void:
	assert_true(_cast(Vector3(0.25, 20.0, 0.25), Vector3.DOWN, 5.0, _world({}, 10.0)).is_empty(), "ground 10 m away is out of a 5 m reach")
	assert_true(_cast(Vector3(0.25, 20.0, 0.25), Vector3.UP, 60.0, _world({}, 10.0)).is_empty(), "the sky is a miss")
	assert_true(_cast(Vector3(0.25, 20.0, 0.25), Vector3.ZERO, 60.0, _world({}, 10.0)).is_empty(), "no direction is a miss")

## 5,393,152 m out a float32 world coordinate is only good to 0.5 m: the ray works from the small scene
## position and the exact offset, in doubles.
func _test_ray_far_from_origin() -> void:
	var offset := Vector3(-5393152.0, 0.0, 222528.0)
	var target := Vector2i(floori((0.3 + 5393152.0) / 0.5), floori((0.3 - 222528.0) / 0.5))
	var world := _world({ target: [[VoxelSlice.BEDROCK_DEPTH, 12.0]] }, -50.0)
	var hit := _cast(Vector3(0.3, 20.0, 0.3), Vector3.DOWN, 60.0, world, offset)
	assert_true(_near(hit.get("position", Vector3.ZERO), Vector3(0.3, 12.0, 0.3)), "the pillar under the scene position (%s)" % str(hit.get("position")))
	assert_eq(VoxelRay.tile_of(Vector3(0.3, 0.0, 0.3), offset), target, "tile_of agrees")

func _test_ray_top_reject() -> void:
	var reads := [0]
	var world := _world({}, 10.0)
	var counted := func(t: Vector2i) -> Array:
		reads[0] += 1
		return world[0].call(t)
	var hit := VoxelRay.cast(Vector3(0.25, 12.0, 0.25), Vector3(1, -0.1, 0).normalized(), 60.0, Vector3.ZERO, counted, world[1])
	assert_true(_near(hit.get("position", Vector3.ZERO), Vector3(20.25, 10.0, 0.25)), "the ray lands 20 m out (%s)" % str(hit.get("position")))
	assert_true(reads[0] <= 2, "only the tiles it reaches read their runs (%d reads over ~40 tiles)" % reads[0])

## The real path: a chunk built on a voxel slice, cast through `get_runs_at_tile` / `column_top_at_tile`
## as `PlayerSlice._terrain_ray` does, matches the column the slice reports — edits included.
func _test_ray_on_voxel_slice() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var voxel: VoxelSlice = rig["voxel"]
	cm.load_chunk(Vector2i(0, 0))
	_wait_for_builds(cm)
	var runs_at := func(t: Vector2i) -> Array: return voxel.get_runs_at_tile(t)
	var top_at := func(t: Vector2i) -> float: return voxel.column_top_at_tile(t)
	var xz := Vector2(5.25, 7.25)
	var tile := VoxelRay.tile_of(Vector3(xz.x, 0, xz.y), Vector3.ZERO)
	var top := float(voxel.get_runs_at_tile(tile)[-1]["top"])
	assert_eq(voxel.column_top_at_tile(tile), top, "column_top_at_tile is the runs' top with no edits")
	var hit := VoxelRay.cast(Vector3(xz.x, top + 30.0, xz.y), Vector3.DOWN, 60.0, Vector3.ZERO, runs_at, top_at)
	assert_true(absf(float(hit.get("position", Vector3.ZERO).y) - top) < 0.001, "the ray lands on the built column's top")
	assert_true(voxel.place_block(Vector3(xz.x, top, xz.y), Vector3.UP, "Ashite"), "a block is placed on the column")
	var raised := float(voxel.get_runs_at_tile(tile)[-1]["top"])
	assert_true(raised > top, "a placed block raises the column")
	assert_eq(voxel.column_top_at_tile(tile), raised, "and column_top_at_tile sees the edit")
	var hit2 := VoxelRay.cast(Vector3(xz.x, top + 30.0, xz.y), Vector3.DOWN, 60.0, Vector3.ZERO, runs_at, top_at)
	assert_true(absf(float(hit2.get("position", Vector3.ZERO).y) - raised) < 0.001, "the ray lands on the placed block")
	_free_rig(rig)

func _free_rig(rig: Dictionary) -> void:
	for k in ["cm", "voxel", "terrain", "player"]:
		if rig.has(k) and is_instance_valid(rig[k]):
			rig[k].free()

func _runs(spec: Array) -> Array:
	var out: Array = []
	for r in spec:
		out.append({ "bottom": float(r[0]), "top": float(r[1]) })
	return out

func _test_descent_room() -> void:
	var ground := _runs([[VoxelSlice.BEDROCK_DEPTH, 10.0]])
	assert_eq(DiveGuard.descent_room(15.0, ground), 5.0, "5 m above the top: 5 m to fall")
	assert_eq(DiveGuard.descent_room(10.0, ground), 0.0, "standing on it: none")
	assert_true(absf(DiveGuard.descent_room(10.02, ground) - 0.02) < 0.0001, "a hair above it: just that hair")
	var cave := _runs([[VoxelSlice.BEDROCK_DEPTH, 10.0], [20.0, 25.0]])
	assert_eq(DiveGuard.descent_room(30.0, cave), 5.0, "above a ledge: down to the ledge")
	assert_eq(DiveGuard.descent_room(15.0, cave), 5.0, "under the ledge: down to the floor")
	assert_eq(DiveGuard.descent_room(-50.0, _runs([])), -50.0 - VoxelSlice.BEDROCK_DEPTH, "a dug-out column: down to bedrock")

func _test_buried_lift() -> void:
	var ground := _runs([[VoxelSlice.BEDROCK_DEPTH, 10.0]])
	assert_eq(DiveGuard.buried_lift(4.0, ground), 10.0, "6 m into the ground: back on its top")
	assert_eq(DiveGuard.buried_lift(9.9, ground), 9.9, "pressed in by less than the margin: left to the physics")
	assert_eq(DiveGuard.buried_lift(12.0, ground), 12.0, "above the ground: unchanged")
	var cave := _runs([[VoxelSlice.BEDROCK_DEPTH, 10.0], [20.0, 25.0]])
	assert_eq(DiveGuard.buried_lift(15.0, cave), 15.0, "in a cave's air gap: unchanged")
	assert_eq(DiveGuard.buried_lift(22.0, cave), 25.0, "inside the ledge: onto the ledge")

func _test_collision_radius() -> void:
	assert_eq(NearRing.COLLISION_RADIUS, 1, "collision: the body's chunk and the eight around it")
	assert_eq(NearRing.REACH_RADIUS, 2, "full detail: two rings, past the 60 m aim")
	assert_true(NearRing.COLLISION_RADIUS * TerrainSlice.CHUNK_METERS >= 32.0, "at least 32 m of collided ground past the body's chunk")
