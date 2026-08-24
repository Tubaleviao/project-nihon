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

## Humanoid rest pose (local positions, unscaled height) — bone name → Vector3.
## Non-humanoid / unknown bones fall back to a small deterministic chain step.
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

## Fallback local step for bones with no humanoid rest pose (quadruped/bird/
## serpent/custom families) so a non-humanoid chain does not collapse to origin.
const DEFAULT_STEP := Vector3(0.0, 0.2, 0.0)

var _skeleton: Skeleton3D
var _bone_index: Dictionary = {}   # bone name -> bone index
var _bones: Array = []             # ordered bone names
var _sockets: Dictionary = {}      # socket -> bone name
var _family: String = "humanoid"

## Build the Skeleton3D from a generated skeleton resource (GameData.SKELETONS
## entry). `scale` is the height proportion multiplier applied to rest poses.
func build(skeleton_res: Resource, scale: float = 1.0) -> void:
	_skeleton = Skeleton3D.new()
	_skeleton.name = "Skeleton3D"
	add_child(_skeleton)

	_family = "humanoid"
	_sockets = {}
	_bones = []
	_bone_index = {}
	if skeleton_res == null:
		return

	_family = _str_field(skeleton_res, "family", "humanoid")
	_sockets = _json_field(skeleton_res, "sockets", {})

	var bone_defs = _json_field(skeleton_res, "bones", [])
	var idx := 0
	for b in bone_defs:
		var bone_name: String = str(b.get("name", ""))
		if bone_name == "":
			continue
		_bones.append(bone_name)
		_bone_index[bone_name] = idx
		_skeleton.add_bone(bone_name)
		_skeleton.set_bone_rest(idx, _rest_transform(bone_name, scale))
		idx += 1

	# Wire parents (the fabric guarantees parents precede children).
	for b in bone_defs:
		var bone_name: String = str(b.get("name", ""))
		var parent: String = str(b.get("parent", ""))
		if bone_name != "" and parent != "" and _bone_index.has(parent):
			_skeleton.set_bone_parent(_bone_index[bone_name], _bone_index[parent])

func _rest_transform(bone_name: String, scale: float) -> Transform3D:
	var pos: Vector3
	if REST_POSE.has(bone_name):
		pos = REST_POSE[bone_name] * scale
	else:
		pos = DEFAULT_STEP * scale
	return Transform3D(Basis.IDENTITY, pos)

## Bone name a socket maps to (characters.md §5); "" when unknown.
func socket_to_bone(socket: String) -> String:
	return str(_sockets.get(socket, ""))

func get_skeleton() -> Skeleton3D:
	return _skeleton

func get_bone_index(bone_name: String) -> int:
	return int(_bone_index.get(bone_name, -1))

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
		# Rigid: no bone follow — the mesh is a direct child of the rig root.
		mesh.set_meta("attached_bone", "")
		self.add_child(mesh)
		mesh.transform.origin = local_offset
		return

	# SKINNED / HYBRID: follow the socket's bone.
	mesh.set_meta("attached_bone", bone)
	var att := BoneAttachment3D.new()
	att.name = "Attach_%s" % (bone if bone != "" else socket)
	if bone != "" and _bone_index.has(bone):
		att.bone_idx = _bone_index[bone]
	_skeleton.add_child(att)
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

func _str_field(res: Resource, key: String, default: String) -> String:
	var v = res.get(key)
	return str(v) if v != null else default

func _json_field(res: Resource, key: String, default):
	var v = res.get(key)
	if v is Dictionary or v is Array:
		return v
	if v is String and v != "":
		var parsed = JSON.parse_string(v)
		if parsed != null:
			return parsed
	return default
