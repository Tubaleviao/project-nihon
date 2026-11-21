extends RefCounted
## Phase 280 — the hotbar item in the hand. Pure rules (what may be held, the rate limit) and the view
## that attaches the held item's mesh to `socket_weapon_r`. `sl` is the owning CharacterSlice.

const SKILL_PREFIX := "skill:"
## The longest item id a held-item packet may carry.
const MAX_ID_CHARS := 64
## Held-item changes a player may make per RATE_WINDOW_MS; the rest are dropped.
const RATE_LIMIT := 6
const RATE_WINDOW_MS := 1000
const SOCKET := "socket_weapon_r"
## Edge of the box that stands in for an item without a model.
const FALLBACK_BOX := 0.25
## Metadata keys a model resource may carry for its grip (offset in metres, rotation in degrees).
const GRIP_POS_META := "grip_pos"
const GRIP_ROT_META := "grip_rot"

var sl: Node

## instance id -> { node: MeshInstance3D, item: String } of the mesh in the hand.
var _held: Dictionary = {}

func _init(slice: Node = null) -> void:
	sl = slice

## Whether `item_id` may be held: an item or a block of the fabric, never a skill entry or an unknown id.
static func holdable(item_id: String, items: Dictionary, materials: Dictionary) -> bool:
	if item_id == "" or item_id.length() > MAX_ID_CHARS or item_id.begins_with(SKILL_PREFIX):
		return false
	return items.has(item_id) or materials.has(item_id)

## Whether a player whose recent change times are `stamps` (msec, oldest first) may change again at `now`.
## Returns the pruned list with `now` appended, or an empty array when the change is over the limit.
static func admit(stamps: Array, now: int) -> Array:
	var kept: Array = []
	for t in stamps:
		if now - int(t) < RATE_WINDOW_MS:
			kept.append(t)
	if kept.size() >= RATE_LIMIT:
		return []
	kept.append(now)
	return kept

## Show `item_id` in the instance's hand ("" restores the main-hand equipment). False for an unknown instance.
func set_held(instance_id: String, item_id: String) -> bool:
	if not sl._instances.has(instance_id):
		return false
	_clear_mesh(instance_id)
	var inst: Dictionary = sl._instances[instance_id]
	var main: Dictionary = inst["equipment"].get("MainHand", {})
	var main_node: Node3D = main.get("node", null)
	# The held item replaces the equipped main hand only while it is something else.
	var replaces: bool = item_id != "" and item_id != str(main.get("item_id", ""))
	if main_node != null and is_instance_valid(main_node):
		# Only a mesh this view hid is shown again: LOD or a rig may keep the worn mesh hidden for its own reasons.
		if replaces and main_node.visible:
			main_node.visible = false
			main_node.set_meta("held_hid", true)
		elif not replaces and main_node.has_meta("held_hid"):
			main_node.remove_meta("held_hid")
			main_node.visible = true
	if not replaces:
		if item_id != "":
			_held[instance_id] = { "node": null, "item": item_id }
		return true
	var rig = inst["rig"]
	var props: Dictionary = inst["appearance"].get("proportions", {})
	var model: Mesh = sl._item_model(item_id) if sl.render_visuals else null
	var mesh: MeshInstance3D
	if model != null:
		mesh = MeshInstance3D.new()
		mesh.mesh = model
		sl._finish_part(mesh, 0, {})
		mesh.set_meta("item_model", item_id)
	else:
		mesh = sl._make_box(Vector3(FALLBACK_BOX, FALLBACK_BOX, FALLBACK_BOX), 0)
	mesh.name = "Held"
	var bone: String = rig.socket_to_bone(SOCKET)
	var offset: Vector3 = sl._socket_offset(rig, SOCKET, props) - rig.get_bone_global_rest(bone)
	var grip := grip_of(model)
	mesh.rotation_degrees = grip["rot"]
	rig.attach(SOCKET, mesh, "SKINNED", offset + grip["pos"])
	mesh.rotation_degrees = grip["rot"]
	_held[instance_id] = { "node": mesh, "item": item_id }
	return true

## The grip of a model from its resource metadata: { pos: Vector3, rot: Vector3 }, zero when it has none.
static func grip_of(model: Mesh) -> Dictionary:
	var pos := Vector3.ZERO
	var rot := Vector3.ZERO
	if model != null:
		var p: Variant = model.get_meta(GRIP_POS_META) if model.has_meta(GRIP_POS_META) else null
		var r: Variant = model.get_meta(GRIP_ROT_META) if model.has_meta(GRIP_ROT_META) else null
		if p is Vector3:
			pos = -(p as Vector3)   # the grip point goes to the hand: move the model by its negative
		if r is Vector3:
			rot = r
	return { "pos": pos, "rot": rot }

func held_item_of(instance_id: String) -> String:
	return str(_held.get(instance_id, {}).get("item", ""))

func held_node_of(instance_id: String) -> Node3D:
	var n: Variant = _held.get(instance_id, {}).get("node", null)
	return n if n != null and is_instance_valid(n) else null

func _clear_mesh(instance_id: String) -> void:
	var node: Variant = _held.get(instance_id, {}).get("node", null)
	if node != null and is_instance_valid(node):
		var parent: Node = (node as Node).get_parent()
		if parent != null:
			parent.remove_child(node)
		(node as Node).free()
	_held.erase(instance_id)

## The instance is going away: its held mesh goes with the rig, only the record is dropped.
func forget(instance_id: String) -> void:
	_held.erase(instance_id)
