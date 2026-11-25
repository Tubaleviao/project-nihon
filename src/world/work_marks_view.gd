extends Node3D
## #629 — draws the work marks (`work_marks.gd`) on this machine: a crack overlay on the top face of a worked block,
## darker and more broken with each stage, and a sway on a tree being chopped. Presentation only: it reads the marks
## the wiring applied and never decides anything. A rebase target (`shift_scene`), so the overlays stay on their
## blocks when the scene origin moves.

const WorkMarks := preload("res://src/world/work_marks.gd")
const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")

## The crack texture's size (pixels) and the overlay's lift above the face, so it never z-fights the ground.
const CRACK_TEXTURE_SIZE := 64
const LIFT := 0.01

var marks := WorkMarks.new()
## `TreeSlice` (for the shake); null on a boot with no trees.
var tree_slice: Node = null
## `Callable() -> float`, seconds; the suite sets a fake clock.
var clock: Callable = func() -> float: return Time.get_ticks_msec() * 0.001

## The scene-origin shift applied so far (world frame → scene).
var _offset := Vector3.ZERO
## `{ key: MeshInstance3D }` — one overlay per block mark.
var _overlays: Dictionary = {}
## Tree ids this view tilted, so a stop puts them back.
var _shaken: Dictionary = {}
## One texture per crack stage, built once (deterministic).
static var _textures: Array = []

## Apply a host message (see `WorkMarks.apply`) and redraw at once. Returns whether it was taken.
func apply(key: Variant, duration: Variant) -> bool:
	if not marks.apply(key, duration, clock.call()):
		return false
	if not marks.has(str(key)):
		_drop(str(key))
	step()
	return true

func _process(_delta: float) -> void:
	step()

## One frame: expire lost marks, then draw each one at its progress.
func step() -> void:
	var now: float = clock.call()
	for k in marks.expire(now):
		_drop(str(k))
	# A mark the store evicted when full never comes back from `expire`: drop what it left drawn.
	for k in _overlays.keys():
		if not marks.has(str(k)):
			_drop(str(k))
	for tid in _shaken.keys():
		if not marks.has("tree:" + str(tid)):
			_drop("tree:" + str(tid))
	for k in marks.keys():
		var key := str(k)
		var target := WorkMarks.parse_key(key)
		if target["kind"] == "tree":
			_shake(key, str(target["tree_id"]), now)
		else:
			_crack(key, target, now)

## The overlay drawn for `key` (null when none), for the suite.
func overlay(key: String) -> MeshInstance3D:
	return _overlays.get(key, null)

func is_shaking(tree_id: String) -> bool:
	return _shaken.has(tree_id)

func shift_scene(shift: Vector3) -> void:
	_offset += shift
	for k in _overlays:
		(_overlays[k] as Node3D).position += shift

func clear() -> void:
	for k in marks.keys():
		_drop(str(k))
	marks.clear()

func _exit_tree() -> void:
	for tid in _shaken.keys():
		_untilt(str(tid))
	_shaken.clear()

func _shake(key: String, tree_id: String, now: float) -> void:
	if tree_slice == null or not "_fall" in tree_slice:
		return
	var angle := WorkMarks.shake_angle(marks.elapsed(key, now), marks.progress(key, now))
	if tree_slice._fall.shake(tree_id, angle):
		_shaken[tree_id] = true

func _untilt(tree_id: String) -> void:
	if tree_slice != null and is_instance_valid(tree_slice) and "_fall" in tree_slice:
		tree_slice._fall.shake(tree_id, 0.0)

func _crack(key: String, target: Dictionary, now: float) -> void:
	var stage := WorkMarks.crack_stage(marks.progress(key, now))
	var mi: MeshInstance3D = _overlays.get(key, null)
	if mi == null:
		mi = MeshInstance3D.new()
		mi.name = "Crack"
		var quad := QuadMesh.new()
		quad.size = Vector2(VoxelConsts.TILE_SIZE, VoxelConsts.TILE_SIZE)
		quad.orientation = PlaneMesh.FACE_Y
		mi.mesh = quad
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.05, 0.04, 0.03, 1.0)
		mi.material_override = mat
		mi.position = WorkMarks.block_top(target["tile"], float(target["bottom"]), VoxelConsts.TILE_SIZE,
			VoxelConsts.STEP_HEIGHT) + Vector3(0.0, LIFT, 0.0) + _offset
		add_child(mi)
		_overlays[key] = mi
	var m := mi.material_override as StandardMaterial3D
	if stage > 0 and int(mi.get_meta("stage", 0)) != stage:
		m.albedo_texture = crack_texture(stage)
		mi.set_meta("stage", stage)
	mi.visible = stage > 0

func _drop(key: String) -> void:
	var mi: MeshInstance3D = _overlays.get(key, null)
	if mi != null:
		_overlays.erase(key)
		remove_child(mi)
		mi.free()
	var target := WorkMarks.parse_key(key)
	if not target.is_empty() and target["kind"] == "tree":
		var tid := str(target["tree_id"])
		if _shaken.has(tid):
			_untilt(tid)
			_shaken.erase(tid)

## The crack texture of `stage` (1..CRACK_STAGES): the same few cracks every time (a fixed seed), each stage drawing
## more of them and longer, on a transparent ground.
static func crack_texture(stage: int) -> Texture2D:
	if _textures.is_empty():
		for s in range(1, WorkMarks.CRACK_STAGES + 1):
			_textures.append(ImageTexture.create_from_image(crack_image(s)))
	return _textures[clampi(stage, 1, WorkMarks.CRACK_STAGES) - 1]

## The crack image of `stage`: random walks from the centre, `stage * 2` of them, each `stage * 6` steps long.
static func crack_image(stage: int) -> Image:
	var n := CRACK_TEXTURE_SIZE
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 629
	var c := Vector2(n * 0.5, n * 0.5)
	for i in stage * 2:
		var p := c
		var dir := Vector2.RIGHT.rotated(TAU * float(i) / float(stage * 2) + rng.randf_range(-0.3, 0.3))
		for _s in stage * 6:
			dir = dir.rotated(rng.randf_range(-0.6, 0.6))
			p += dir * 2.0
			var px := Vector2i(clampi(int(p.x), 0, n - 1), clampi(int(p.y), 0, n - 1))
			img.set_pixelv(px, Color(1, 1, 1, 0.9))
			img.set_pixelv(Vector2i(mini(px.x + 1, n - 1), px.y), Color(1, 1, 1, 0.6))
	return img
