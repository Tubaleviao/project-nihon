extends RefCounted
## Methods moved verbatim out of `character_slice.gd` (Phase 154). `sl` is the owning slice; each moved method keeps a forwarder there.

var sl: Node

func _init(slice: Node) -> void:
	sl = slice

## Replace an existing instance's appearance recipe (rebuilds the visual).
func apply_appearance(instance_id: String, recipe: Dictionary) -> bool:
	if not sl._instances.has(instance_id):
		return false
	var normalized = sl.deserialize_appearance(recipe)
	var inst: Dictionary = sl._instances[instance_id]

	var old_root: Node3D = inst["root"]
	old_root.queue_free()

	var built: Dictionary = sl._make_visual(instance_id, normalized)
	var root: Node3D = built["root"]
	root.position = (inst["position"] as Vector3) + sl._origin.value
	sl.add_child(root)

	inst["appearance"] = normalized
	inst["root"] = root
	inst["rig"] = built["rig"]
	inst["locomotion"] = built["locomotion"]
	inst["equipment"] = built["equipment"]
	inst["parts"] = built["parts"]
	inst["impostor"] = built.get("impostor", null)
	inst["limb_pivots"] = built.get("limb_pivots", {})
	inst["anim_phase"] = 0.0
	# The old root (and the attached rig's AnimationTree under it) is freed; keeping the
	# stale handle would make `_apply_lod` hide the new procedural body for good.
	inst.erase("anim_tree")
	inst.erase("rig_node")
	inst["base_equipment"] = normalized.get("equipment", {}).duplicate(true)
	inst["equipment_visible"] = true
	# The rebuilt rig's nodes default to visible; reset the early-out state so
	# _apply_lod force-applies visibility to the new nodes instead of skipping
	# them (which would leave the full rig showing at impostor distance).
	inst["lod"] = -1
	inst.erase("_hidden")
	# The rebuilt body is procedural again; a character that wore a rig gets it back. The rig
	# goes on BEFORE the LOD pass so that pass already knows about it (a rig attached after
	# it stayed visible whatever the distance until the next LOD transition).
	var rig_key: String = str(inst.get("rig_key", ""))
	if rig_key != "":
		sl.attach_rig(instance_id, rig_key)
	sl._apply_lod(instance_id)

	GameBus.character_appearance_changed.emit(instance_id, normalized)
	return true

## A part renders while `_lod <= part.max_lod` and its part key is not hidden by
## a currently-equipped item's `hideRegions` (§16, e.g. a helmet hiding "Hair").
## `max_lod` is the COARSEST level at which a part still renders (fine detail
## like hair/beard is 0, coarse body geometry is MAX_LOD) — the comparison
## `lod <= max_lod` is why the name reads as a max, not a min. The hidden set is
## recomputed from every equipped slot's def each call rather than tracked
## incrementally, so two overlapping hides (and un-equipping one of them) always
## resolve correctly from current state alone.
##
## At IMPOSTOR_LOD the whole rig is replaced by the impostor billboard (Phase 23):
## every part is hidden regardless of its max_lod and the billboard is shown in
## its place.
##
## Early-outs when neither the resolved level nor the hideRegions-derived hidden
## set changed since the last apply — `update_lod` re-runs this every frame, and
## touching node visibility is only warranted on a real transition.
func _apply_lod(instance_id: String) -> void:
	if not sl._instances.has(instance_id):
		return
	var inst: Dictionary = sl._instances[instance_id]
	var equipment: Dictionary = inst["equipment"]

	var lod: int = sl._resolved_lod(instance_id)

	var hidden: Dictionary = {}
	var rig = inst.get("rig", null)
	var is_humanoid: bool = rig != null and rig.get_family() == "humanoid"
	for slot in equipment:
		var def: Dictionary = equipment[slot].get("def", {})
		for region in def.get("hideRegions", []):
			var part_key = sl._region_to_part(str(region), is_humanoid)
			if part_key != "":
				hidden[part_key] = true

	if inst.get("lod", -1) == lod and inst.get("_hidden", {}) == hidden:
		return
	inst["lod"] = lod
	inst["_hidden"] = hidden

	var use_impostor: bool = lod >= sl.IMPOSTOR_LOD
	# An attached rig replaces the procedural body, so LOD must not bring it back.
	var has_rig: bool = inst.has("anim_tree") and is_instance_valid(inst["anim_tree"])
	var parts: Dictionary = inst["parts"]
	for key in parts:
		var part: Dictionary = parts[key]
		var node: Node3D = part["node"]
		var max_lod: int = part.get("max_lod", sl.MAX_LOD)
		node.visible = not has_rig and (not use_impostor) and lod <= max_lod and not hidden.get(key, false)

	# An attached rig is a full-detail body: at impostor distance it gives way to the billboard
	# like the procedural body does, instead of rendering a skinned mesh nobody can resolve.
	var rig_node: Variant = inst.get("rig_node", null)
	if has_rig and rig_node != null and is_instance_valid(rig_node):
		(rig_node as Node3D).visible = not use_impostor
	var impostor = inst.get("impostor", null)
	if impostor != null:
		impostor.visible = use_impostor

## Build the impostor billboard (ROADMAP Phase 23): a camera-facing QuadMesh
## tinted to the character's dominant (skin) palette colour, shown in place of
## the full rig once the instance drops to IMPOSTOR_LOD. Hidden by default —
## `_apply_lod` shows it. Sized to the character's silhouette: total height
## (head_top for humanoid, `height` for other families) by shoulder width.
##
## The quad mesh is cached by size and the unshaded billboard material by the
## RESOLVED skin colour, so impostors sharing a silhouette / colour reuse
## resources. NOTE: the colour is a palette index resolved ONCE at creation into
## the material's albedo (a baked colour), NOT a live sample of the palette
## texture — so a palette-texture swap is NOT reflected here (unlike the real
## parts, which sample the shared palette each frame). A true pre-baked sprite
## impostor that honours palette swaps is deferred (ROADMAP Phase 23 "Known
## simplifications").
func _make_impostor(rig, appearance: Dictionary, props: Dictionary) -> MeshInstance3D:
	var skin_idx: int = int(appearance.get("skinColor", 12))
	var w: float = 0.55 * float(props.get("shoulderWidth", 1.0)) * float(props.get("bodyMass", 1.0))
	var h: float = float(props.get("height", 1.0))
	if rig.get_family() == "humanoid":
		var landmarks: Dictionary = sl.SkeletonRig.compute_landmarks(rig.get_body_shape_coefficients(), props)
		h = float(landmarks["head_top"])
	var size = Vector2(w, h)
	var quad: QuadMesh = sl._impostor_quads.get(size, null)
	if quad == null:
		if sl._impostor_quads.size() >= sl.IMPOSTOR_CACHE_MAX:
			sl._impostor_quads.clear()
		quad = QuadMesh.new()
		quad.size = size
		sl._impostor_quads[size] = quad
	var color = sl.palette_color(skin_idx)
	var mat: StandardMaterial3D = sl._impostor_materials.get(color, null)
	if mat == null:
		if sl._impostor_materials.size() >= sl.IMPOSTOR_CACHE_MAX:
			sl._impostor_materials.clear()
		mat = StandardMaterial3D.new()
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color
		sl._impostor_materials[color] = mat
	var imp = MeshInstance3D.new()
	imp.name = "Impostor"
	imp.mesh = quad
	imp.material_override = mat
	imp.visible = false
	rig.add_child(imp)
	imp.position = Vector3(0.0, h * 0.5, 0.0)
	return imp
