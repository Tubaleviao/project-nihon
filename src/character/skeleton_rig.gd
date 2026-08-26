extends Node3D
## Skeleton rig — a Skeleton3D built from a fabric SkeletonDefinition.
##
## Realizes ROADMAP Phase 20's "base humanoid skeleton rig": reads the ordered
## `bones` chain from a generated skeleton resource (GameData.SKELETONS) and
## constructs a real Godot Skeleton3D with the same hierarchy. Provides socket
## resolution (bones vs sockets, characters.md §5) and deformation-mode
## attachment (SKINNED / RIGID / HYBRID, characters.md §10).
##
## The rig is visual/structural only — it carries no physics body of its own.
## Locomotion decisions live in Locomotion (locomotion.gd); this node is the
## thing those decisions deform.

const GameDataReader := preload("res://src/core/game_data_reader.gd")

## Fallback humanoid rest pose, used only when a skeleton resource carries no
## `restPose` field of its own (e.g. a hand-built test double) — real skeleton
## resources (GameData.SKELETONS) define `restPose` in the fabric (§4) and are
## read via `build()` instead.
const REST_POSE: Dictionary = {
	"Root":       Vector3(0.0, 0.0, 0.0),
	"Hips":       Vector3(0.0, 0.95, 0.0),
	"Spine":      Vector3(0.0, 0.15, 0.0),
	"Chest":      Vector3(0.0, 0.30, 0.0),
	"Neck":       Vector3(0.0, 0.25, 0.0),
	"Head":       Vector3(0.0, 0.18, 0.0),
	"Shoulder_L": Vector3(-0.20, 0.18, 0.0),
	"Arm_L":      Vector3(-0.05, -0.18, 0.0),
	"Forearm_L":  Vector3(0.0, -0.28, 0.0),
	"Hand_L":     Vector3(0.0, -0.26, 0.0),
	"Shoulder_R": Vector3(0.20, 0.18, 0.0),
	"Arm_R":      Vector3(0.05, -0.18, 0.0),
	"Forearm_R":  Vector3(0.0, -0.28, 0.0),
	"Hand_R":     Vector3(0.0, -0.26, 0.0),
	"Leg_L":      Vector3(-0.10, -0.40, 0.0),
	"Foot_L":     Vector3(0.0, -0.45, 0.0),
	"Leg_R":      Vector3(0.10, -0.40, 0.0),
	"Foot_R":     Vector3(0.0, -0.45, 0.0),
}

## Fallback local step for bones with no rest pose entry at all (custom/unknown
## bone names) so a chain never collapses to origin.
const DEFAULT_STEP := Vector3(0.0, 0.2, 0.0)

## Placeholder body-shape coefficients (characters.md §8), used as a fallback
## for skeleton families that don't define `bodyShapeCoefficients` (only
## HumanoidSkeleton does — non-humanoid families don't use the humanoid
## placeholder body/socket layout). Mirrors HumanoidSkeleton's fabric defaults.
const DEFAULT_BODY_SHAPE: Dictionary = {
	"torsoHeightFactor": 0.62,
	"hipHeightFactor": 0.38,
	"headSizeFactor": 0.30,
	"chestYFactor": 0.6,
	"handXFactor": 0.42,
	"handYArmFactor": 0.05,
	"weaponForwardOffset": 0.15,
	"hipSideOffset": 0.2,
	"backForwardOffset": -0.25,
	"capeUpOffset": 0.15,
	"legReachMargin": 0.05,
	"footSideFactor": 0.12,
}

var _skeleton: Skeleton3D
var _bone_index: Dictionary = {}   # bone name -> bone index
var _bones: Array = []             # ordered bone names
var _sockets: Dictionary = {}      # socket -> bone name
var _family: String = "humanoid"
var _rest_pose: Dictionary = {}    # bone name -> Vector3, from the resource's restPose
var _body_shape: Dictionary = DEFAULT_BODY_SHAPE
var _turn_speed: float = 8.0

## Build the Skeleton3D from a generated skeleton resource (GameData.SKELETONS
## entry). `props` is the character's body-proportion dict (height, bodyMass,
## shoulderWidth, armLength, legLength, headScale — characters.md §8); each
## bone's rest offset is scaled per its bone group (see `_bone_group_scale`) so
## the rig's real bone positions track the same proportions the placeholder
## mesh/socket/foot-IK math uses instead of a single uniform `height` factor.
func build(skeleton_res: Resource, props: Dictionary = {}) -> void:
	_skeleton = Skeleton3D.new()
	_skeleton.name = "Skeleton3D"
	add_child(_skeleton)

	_family = "humanoid"
	_sockets = {}
	_bones = []
	_bone_index = {}
	_rest_pose = {}
	_body_shape = DEFAULT_BODY_SHAPE
	_turn_speed = 8.0
	if skeleton_res == null:
		return

	_family = GameDataReader.str_field(skeleton_res, "family", "humanoid")
	_sockets = GameDataReader.json_field(skeleton_res, "sockets", {})
	_turn_speed = GameDataReader.float_field(skeleton_res, "turnSpeed", 8.0)

	var raw_coeffs: Dictionary = GameDataReader.json_field(skeleton_res, "bodyShapeCoefficients", {})
	if not raw_coeffs.is_empty():
		_body_shape = raw_coeffs

	var raw_pose: Dictionary = GameDataReader.json_field(skeleton_res, "restPose", {})
	for bone_name in raw_pose:
		_rest_pose[bone_name] = _vec3(raw_pose[bone_name])

	var bone_defs = GameDataReader.json_field(skeleton_res, "bones", [])
	var idx := 0
	for b in bone_defs:
		var bone_name: String = str(b.get("name", ""))
		if bone_name == "":
			continue
		_bones.append(bone_name)
		_bone_index[bone_name] = idx
		_skeleton.add_bone(bone_name)
		_skeleton.set_bone_rest(idx, _rest_transform(bone_name, props))
		idx += 1

	# Wire parents (the fabric guarantees parents precede children).
	for b in bone_defs:
		var bone_name: String = str(b.get("name", ""))
		var parent: String = str(b.get("parent", ""))
		if bone_name != "" and parent != "" and _bone_index.has(parent):
			_skeleton.set_bone_parent(_bone_index[bone_name], _bone_index[parent])

func _rest_transform(bone_name: String, props: Dictionary) -> Transform3D:
	var raw: Vector3
	if _rest_pose.has(bone_name):
		raw = _rest_pose[bone_name]
	elif REST_POSE.has(bone_name):
		raw = REST_POSE[bone_name]
	else:
		raw = DEFAULT_STEP
	return Transform3D(Basis.IDENTITY, raw * _bone_group_scale(bone_name, props))

## Per-bone-group proportion scale, applied per axis so a bone's rest offset
## tracks the same body dimension the placeholder mesh/socket/foot-IK code uses
## for that region — previously every bone scaled by `height` alone while
## `character_slice.gd` additionally factored in shoulderWidth/legLength/
## headScale/armLength, so sockets did not track the body they were dressing.
static func _bone_group_scale(bone_name: String, props: Dictionary) -> Vector3:
	var height: float = props.get("height", 1.0)
	var shoulder: float = props.get("shoulderWidth", 1.0)
	var leg_len: float = props.get("legLength", 1.0)
	var arm_len: float = props.get("armLength", 1.0)
	var head_scale: float = props.get("headScale", 1.0)
	match bone_name:
		"Leg_L", "Leg_R", "Foot_L", "Foot_R", "Leg_FL", "Leg_FR", "Leg_BL", "Leg_BR":
			return Vector3(height, leg_len * height, height)
		"Shoulder_L", "Shoulder_R":
			return Vector3(shoulder, height, height)
		"Arm_L", "Arm_R", "Forearm_L", "Forearm_R", "Hand_L", "Hand_R", "Wing_L", "Wing_R":
			return Vector3(height, arm_len * height, height)
		"Head":
			return Vector3(head_scale, head_scale, head_scale)
		_:
			return Vector3(height, height, height)

static func _vec3(v) -> Vector3:
	if v is Vector3:
		return v
	if v is Array and v.size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return Vector3.ZERO

## Body-shape coefficients this rig was built with (characters.md §8) — read
## from the skeleton resource's `bodyShapeCoefficients` field, falling back to
## `DEFAULT_BODY_SHAPE`. Shared by `compute_landmarks` so the visual assembly,
## socket offsets, and foot IK all derive the same landmarks from one source.
func get_body_shape_coefficients() -> Dictionary:
	return _body_shape

## Facing turn rate in radians/second (characters.md §37), read from the
## skeleton resource's `turnSpeed` field.
func get_turn_speed() -> float:
	return _turn_speed

## Shared placeholder body landmarks — the single formula behind the visual
## assembly, socket offsets, and foot IK (characters.md §8), so all three stay
## in sync as proportions or bodyShapeCoefficients change. `coeffs` is normally
## `get_body_shape_coefficients()`; `props` is the character's proportion dict.
static func compute_landmarks(coeffs: Dictionary, props: Dictionary) -> Dictionary:
	var height: float = props.get("height", 1.0)
	var shoulder: float = props.get("shoulderWidth", 1.0)
	var leg_len: float = props.get("legLength", 1.0)
	var head_scale: float = props.get("headScale", 1.0)
	var arm_len: float = props.get("armLength", 1.0)

	var torso_h: float = float(coeffs.get("torsoHeightFactor", 0.62)) * height
	var hip_y: float = float(coeffs.get("hipHeightFactor", 0.38)) * leg_len * height
	var head_size: float = float(coeffs.get("headSizeFactor", 0.30)) * head_scale
	var chest_y: float = hip_y + torso_h * float(coeffs.get("chestYFactor", 0.6))
	var head_top: float = hip_y + torso_h + head_size
	var head_y: float = hip_y + torso_h + head_size * 0.5
	var hand_x: float = float(coeffs.get("handXFactor", 0.42)) * shoulder
	var hand_y: float = chest_y - float(coeffs.get("handYArmFactor", 0.05)) * arm_len * height
	var leg_reach_margin: float = float(coeffs.get("legReachMargin", 0.05))

	return {
		"torso_h":          torso_h,
		"hip_y":            hip_y,
		"head_size":        head_size,
		"head_top":         head_top,
		"head_y":           head_y,
		"chest_y":          chest_y,
		"hand_x":           hand_x,
		"hand_y":           hand_y,
		"weapon_forward":   float(coeffs.get("weaponForwardOffset", 0.15)),
		"hip_side":         float(coeffs.get("hipSideOffset", 0.2)),
		"back_forward":     float(coeffs.get("backForwardOffset", -0.25)),
		"cape_up":          float(coeffs.get("capeUpOffset", 0.15)),
		"leg_reach_margin": leg_reach_margin,
		"foot_side":        float(coeffs.get("footSideFactor", 0.12)) * height,
		"leg_reach":        hip_y + leg_reach_margin,
	}

## Bone name a socket maps to (characters.md §5); "" when unknown.
func socket_to_bone(socket: String) -> String:
	return str(_sockets.get(socket, ""))

func get_skeleton() -> Skeleton3D:
	return _skeleton

func get_bone_index(bone_name: String) -> int:
	return int(_bone_index.get(bone_name, -1))

## Global (rig-root-space) rest position of a bone's origin, computed by walking
## the parent chain and summing each ancestor's rest transform. Unknown bones
## return Vector3.ZERO. This is the anchor callers subtract to convert a
## root-space socket offset into a bone-local offset.
func get_bone_global_rest(bone_name: String) -> Vector3:
	if not _bone_index.has(bone_name):
		return Vector3.ZERO
	var pos := Vector3.ZERO
	var idx: int = _bone_index[bone_name]
	var guard := 0
	while idx != -1 and guard < _bones.size():
		pos += _skeleton.get_bone_rest(idx).origin
		idx = _skeleton.get_bone_parent(idx)
		guard += 1
	return pos

func get_bone_names() -> Array:
	return _bones.duplicate()

func get_family() -> String:
	return _family

## Attach a mesh to a socket with a deformation mode (characters.md §10).
## SKINNED / HYBRID parent the mesh under a BoneAttachment3D on the socket's
## bone so it deforms with the skeleton; RIGID keeps it as a child of the rig
## root so it stays rigid regardless of bone motion. The mode and bone are
## recorded as mesh metadata for tests and later passes.
func attach(socket: String, mesh: MeshInstance3D, mode: String, local_offset: Vector3) -> void:
	var bone := socket_to_bone(socket)
	var m := mode.to_upper()

	mesh.set_meta("deformation_mode", m)
	mesh.set_meta("socket", socket)

	if m == "RIGID":
		# Rigid: no bone follow — the mesh is a direct child of the rig root,
		# positioned at the root-space socket offset.
		mesh.set_meta("attached_bone", "")
		self.add_child(mesh)
		mesh.transform.origin = local_offset
		return

	# SKINNED / HYBRID: follow the socket's bone. `local_offset` is bone-local.
	attach_to_bone(bone, mesh, local_offset)

## Attach a mesh directly to a named bone (SKINNED/HYBRID). The mesh is parented
## under a BoneAttachment3D on that bone so it follows the skeleton, positioned
## at `local_offset` in bone-local space. An unknown/empty bone name falls back
## to a rig-root child so nothing is left orphaned.
func attach_to_bone(bone_name: String, mesh: MeshInstance3D, local_offset: Vector3) -> void:
	mesh.set_meta("attached_bone", bone_name)
	if bone_name == "" or not _bone_index.has(bone_name):
		self.add_child(mesh)
		mesh.transform.origin = local_offset
		return
	var att := BoneAttachment3D.new()
	att.name = "Attach_%s" % bone_name
	_skeleton.add_child(att)
	att.bone_idx = _bone_index[bone_name]
	att.add_child(mesh)
	mesh.transform.origin = local_offset

## Foot IK — compute world-space foot targets that sit on the terrain surface
## (characters.md §37 "IK targets ... wired to terrain normal"). Pure and
## headless-testable. `terrain_height` is a Callable taking a Vector2 world XZ
## and returning the surface height there. Returns { foot_l, foot_r, hip_y }.
static func compute_foot_targets(
	terrain_height: Callable,
	body_pos: Vector3,
	hip_height: float,
	leg_length: float,
	side_offset: float,
	forward_offset: float
) -> Dictionary:
	var z := body_pos.z + forward_offset
	var left_x := body_pos.x - side_offset
	var right_x := body_pos.x + side_offset
	var left_y := float(terrain_height.call(Vector2(left_x, z)))
	var right_y := float(terrain_height.call(Vector2(right_x, z)))
	var hip_y := body_pos.y + hip_height
	# Clamp so a deep trench never over-extends the leg.
	var foot_l := Vector3(left_x, clampf(left_y, hip_y - leg_length, hip_y), z)
	var foot_r := Vector3(right_x, clampf(right_y, hip_y - leg_length, hip_y), z)
	return { "foot_l": foot_l, "foot_r": foot_r, "hip_y": hip_y }
