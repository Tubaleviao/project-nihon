extends Node
## Character slice — data-driven character appearance system (characters.md).
##
## Realizes the design doc as a working vertical slice:
##   - non-humanoid skeletons (humanoid / quadruped / bird / serpent)
##   - bones vs sockets, equipment slots vs sockets, attachment states
##   - body proportions with artistic bounds, mesh hiding, deformation modes
##   - a single 256-entry palette with color indices instead of raw RGB
##   - persistence-as-recipe + multiplayer visual state + derived wear
##   - LOD via per-attachment minLodLevel
##
## Visuals are modular low-poly placeholders (BoxMesh parts) assembled in code —
## real meshes / textures / skeletons / animations are asset-production work
## outside this slice's scope. See characters.md §37 for the animation system
## (not yet specified).
##
## Plug contract (GameBus signals consumed / emitted):
##   OUT : character_spawned(instance_id, skeleton_id, position)
##         character_appearance_changed(instance_id, appearance)
##
## Public API:
##   create_character(appearance_id, pos)                  -> String (instance_id or "")
##   create_character_from_recipe(recipe, pos)             -> String
##   apply_appearance(instance_id, recipe)                 -> bool
##   get_appearance(instance_id)                           -> Dictionary
##   get_visual_state(instance_id)                         -> Dictionary
##   serialize_appearance(recipe)                          -> Dictionary
##   deserialize_appearance(data)                          -> Dictionary
##   palette_color(index)                                  -> Color
##   get_palette_size()                                    -> int
##   set_lod(level) / get_lod()                            -> void / int
##   is_part_visible(instance_id, part_key)                -> bool

const Defs := preload("res://src/character/character_definitions.gd")

const MIN_LOD := 0
const MAX_LOD := 3

## Instance record: { "appearance", "position", "root", "parts" }.
var _instances: Dictionary = {}
var _next_id: int = 0
var _lod: int = 0
var _palette: Array = []

# ---------------------------------------------------------------------------
# Public — creation
# ---------------------------------------------------------------------------

## Spawn a character from a named sample appearance (Defs.SAMPLE_APPEARANCES).
## Returns the instance_id, or "" if the appearance_id is unknown.
func create_character(appearance_id: String, pos: Vector3) -> String:
	if not Defs.SAMPLE_APPEARANCES.has(appearance_id):
		push_error("CharacterSlice: unknown appearance_id '%s'" % appearance_id)
		return ""
	return create_character_from_recipe(Defs.SAMPLE_APPEARANCES[appearance_id], pos)

## Spawn a character from a raw appearance recipe (persisted / network source).
## The recipe is normalized (unknown fields dropped, proportions clamped) before
## the visual is assembled.
func create_character_from_recipe(recipe: Dictionary, pos: Vector3) -> String:
	var normalized := deserialize_appearance(recipe)
	var iid := "character_%d" % _next_id
	_next_id += 1

	var built: Dictionary = _make_visual(iid, normalized)
	var root: Node3D = built["root"]
	root.position = pos
	add_child(root)

	_instances[iid] = {
		"appearance": normalized,
		"position":   pos,
		"root":       root,
		"parts":      built["parts"],
	}
	_apply_lod(iid)

	var skeleton_id: String = str(normalized.get("skeleton", "?"))
	GameBus.character_spawned.emit(iid, skeleton_id, pos)
	print("CharacterSlice: spawned %s [%s] at %s" % [skeleton_id, iid, pos])
	return iid

## Replace an existing instance's appearance recipe (rebuilds the visual).
func apply_appearance(instance_id: String, recipe: Dictionary) -> bool:
	if not _instances.has(instance_id):
		return false
	var normalized := deserialize_appearance(recipe)
	var inst: Dictionary = _instances[instance_id]

	var old_root: Node3D = inst["root"]
	old_root.free()

	var built: Dictionary = _make_visual(instance_id, normalized)
	var root: Node3D = built["root"]
	root.position = inst["position"]
	add_child(root)

	inst["appearance"] = normalized
	inst["root"] = root
	inst["parts"] = built["parts"]
	_apply_lod(instance_id)

	GameBus.character_appearance_changed.emit(instance_id, normalized)
	return true

# ---------------------------------------------------------------------------
# Public — queries
# ---------------------------------------------------------------------------

## Return the normalized appearance recipe for an instance (deep copy).
func get_appearance(instance_id: String) -> Dictionary:
	if not _instances.has(instance_id):
		return {}
	return _instances[instance_id]["appearance"].duplicate(true)

## Assemble the multiplayer visual state (characters.md §32). Derived visual
## state (wear from durability, §23/§33) is computed here and NOT persisted.
func get_visual_state(instance_id: String) -> Dictionary:
	var appearance := get_appearance(instance_id)
	if appearance.is_empty():
		return {}

	var equipment: Dictionary = {}
	var eq_dict: Dictionary = appearance.get("equipment", {})
	for slot in eq_dict:
		var entry: Dictionary = eq_dict[slot]
		equipment[slot] = entry.duplicate(true)
		equipment[slot]["wear"] = _wear_level(float(entry.get("durability", 1.0)))

	return {
		"identity": { "skeleton": appearance.get("skeleton", ""), "body": appearance.get("body", "") },
		"body":     { "proportions": appearance.get("proportions", {}), "skinColor": appearance.get("skinColor", 0) },
		"face":     { "head": appearance.get("head", ""), "eyes": appearance.get("eyes", ""), "eyeColor": appearance.get("eyeColor", 0), "beard": appearance.get("beard", "") },
		"hair":     { "asset": appearance.get("hair", ""), "color": appearance.get("hairColor", 0) },
		"equipment": equipment,
	}

## Whether a named part (e.g. "hair", "Chest") is currently visible under the
## active LOD. Exposed for debug/HUD and tests.
func is_part_visible(instance_id: String, part_key: String) -> bool:
	if not _instances.has(instance_id):
		return false
	var parts: Dictionary = _instances[instance_id]["parts"]
	if not parts.has(part_key):
		return false
	return parts[part_key]["node"].visible

# ---------------------------------------------------------------------------
# Public — recipe (de)serialization (characters.md §30, §31)
# ---------------------------------------------------------------------------

## A recipe is already JSON-safe (String / int / float / Dictionary / Array).
## Return a deep copy so callers cannot mutate live instance state.
func serialize_appearance(recipe: Dictionary) -> Dictionary:
	return recipe.duplicate(true)

## Normalize a recipe: validate skeleton, clamp proportions to artistic bounds,
## clamp color indices to [0, PALETTE_SIZE), and drop equipment whose item is not
## in the definitions (or whose slot is unknown).
func deserialize_appearance(data: Dictionary) -> Dictionary:
	var recipe: Dictionary = {}

	var skeleton: String = str(data.get("skeleton", "humanoid_01"))
	if not Defs.SKELETONS.has(skeleton):
		skeleton = "humanoid_01"
	recipe["skeleton"] = skeleton

	recipe["body"] = str(data.get("body", "human_body_01"))
	recipe["proportions"] = _normalize_proportions(data.get("proportions", {}))

	recipe["skinColor"] = _color_index(data.get("skinColor", 12))
	recipe["head"] = str(data.get("head", "head_01"))
	recipe["eyes"] = str(data.get("eyes", "eyes_01"))
	recipe["eyeColor"] = _color_index(data.get("eyeColor", 225))
	recipe["hair"] = str(data.get("hair", "hair_short_01"))
	recipe["hairColor"] = _color_index(data.get("hairColor", 40))
	recipe["beard"] = str(data.get("beard", "beard_none"))
	recipe["beardColor"] = _color_index(data.get("beardColor", 40))

	var eq_raw = data.get("equipment", {})
	var eq_out: Dictionary = {}
	if eq_raw is Dictionary:
		var eq_in: Dictionary = eq_raw
		for slot in eq_in:
			var entry = eq_in[slot]
			if entry is Dictionary:
				var item_id: String = str(entry.get("item", ""))
				if Defs.EQUIPMENT.has(item_id):
					eq_out[slot] = _normalize_equipment(entry)
	recipe["equipment"] = eq_out

	return recipe

# ---------------------------------------------------------------------------
# Public — palette (characters.md §19)
# ---------------------------------------------------------------------------

## Return the color at a palette index (clamped to [0, PALETTE_SIZE)).
func palette_color(index: int) -> Color:
	var i := clampi(index, 0, Defs.PALETTE_SIZE - 1)
	if _palette.is_empty():
		_palette = _build_default_palette()
	return _palette[i]

func get_palette_size() -> int:
	if _palette.is_empty():
		_palette = _build_default_palette()
	return _palette.size()

# ---------------------------------------------------------------------------
# Public — LOD (characters.md §35, §36)
# ---------------------------------------------------------------------------

func set_lod(level: int) -> void:
	_lod = clampi(level, MIN_LOD, MAX_LOD)
	for iid in _instances:
		_apply_lod(iid)

func get_lod() -> int:
	return _lod

# ---------------------------------------------------------------------------
# Recipe normalization helpers
# ---------------------------------------------------------------------------

func _normalize_proportions(props) -> Dictionary:
	var src: Dictionary = props if props is Dictionary else {}
	var out: Dictionary = {}
	for key in Defs.BODY_PROP_BOUNDS:
		var bounds: Dictionary = Defs.BODY_PROP_BOUNDS[key]
		var lo: float = bounds["min"]
		var hi: float = bounds["max"]
		var def: float = bounds["default"]
		var v = src.get(key, def)
		if v is float or v is int:
			out[key] = clampf(float(v), lo, hi)
		else:
			out[key] = def
	return out

func _color_index(v) -> int:
	if v is float or v is int:
		return clampi(int(v), 0, Defs.PALETTE_SIZE - 1)
	return 0

func _normalize_equipment(entry: Dictionary) -> Dictionary:
	return {
		"item":           str(entry.get("item", "")),
		"state":          str(entry.get("state", "equipped")),
		"primaryColor":   _color_index(entry.get("primaryColor", 0)),
		"secondaryColor": _color_index(entry.get("secondaryColor", 0)),
		"accentColor":    _color_index(entry.get("accentColor", 0)),
		"metal":          str(entry.get("metal", "none")),
		"durability":     clampf(float(entry.get("durability", 1.0)), 0.0, 1.0),
	}

## Wear is derived from durability, never persisted (§23).
func _wear_level(durability: float) -> String:
	if durability >= 0.9:
		return "New"
	if durability >= 0.6:
		return "Used"
	if durability >= 0.3:
		return "Worn"
	return "Heavily Damaged"

# ---------------------------------------------------------------------------
# Palette construction
# ---------------------------------------------------------------------------

func _build_default_palette() -> Array:
	var out: Array = []
	for region in Defs.PALETTE_REGIONS:
		var count: int = region["count"]
		var anchors: Array = region["anchors"]
		out.append_array(_expand_anchors(anchors, count))
	return out

## Expand a list of anchor colors into `count` colors via piecewise-linear
## RGB interpolation along the anchor path.
func _expand_anchors(anchors: Array, count: int) -> Array:
	var out: Array = []
	if anchors.is_empty() or count <= 0:
		return out
	if anchors.size() == 1:
		var single: Color = anchors[0]
		for i in range(count):
			out.append(single)
		return out
	var segments := anchors.size() - 1
	for i in range(count):
		var t: float = float(i) / float(count - 1) * float(segments)
		var seg: int = mini(int(floor(t)), segments - 1)
		var local: float = t - float(seg)
		var c0: Color = anchors[seg]
		var c1: Color = anchors[seg + 1]
		out.append(c0.lerp(c1, local))
	return out

# ---------------------------------------------------------------------------
# LOD
# ---------------------------------------------------------------------------

## A part renders while `_lod <= part.min_lod`. Body/head carry the highest
## min_lod (always visible); fine details (beard, hair) carry the lowest.
func _apply_lod(instance_id: String) -> void:
	if not _instances.has(instance_id):
		return
	var parts: Dictionary = _instances[instance_id]["parts"]
	for key in parts:
		var part: Dictionary = parts[key]
		var node: Node3D = part["node"]
		var min_lod: int = part.get("min_lod", 0)
		node.visible = _lod <= min_lod

# ---------------------------------------------------------------------------
# Visual construction (placeholder)
# ---------------------------------------------------------------------------

func _make_visual(instance_id: String, appearance: Dictionary) -> Dictionary:
	var root := Node3D.new()
	root.name = "Character_%s" % instance_id
	var parts: Dictionary = {}

	var props: Dictionary = appearance.get("proportions", {})
	var height: float = props.get("height", 1.0)
	var mass: float = props.get("bodyMass", 1.0)
	var shoulder: float = props.get("shoulderWidth", 1.0)
	var head_scale: float = props.get("headScale", 1.0)
	var leg_len: float = props.get("legLength", 1.0)

	var skin: Color = palette_color(int(appearance.get("skinColor", 12)))
	var hair_color: Color = palette_color(int(appearance.get("hairColor", 40)))
	var beard_color: Color = palette_color(int(appearance.get("beardColor", 40)))

	var torso_h := 0.62 * height
	var hip_y := 0.38 * leg_len * height
	var head_size := 0.30 * head_scale
	var head_y := hip_y + torso_h + head_size * 0.5

	# Body (torso + legs as one block placeholder).
	var body := _make_box(Vector3(0.55 * shoulder * mass, torso_h, 0.32 * mass), skin)
	body.position = Vector3(0.0, hip_y + torso_h * 0.5, 0.0)
	root.add_child(body)
	parts["body"] = { "node": body, "min_lod": 3 }

	# Head.
	var head := _make_box(Vector3(head_size, head_size, head_size), skin)
	head.position = Vector3(0.0, head_y, 0.0)
	root.add_child(head)
	parts["head"] = { "node": head, "min_lod": 3 }

	# Hair (independent component — §13).
	var hair_id: String = str(appearance.get("hair", "none"))
	if hair_id != "none" and hair_id != "":
		var hair := _make_box(Vector3(head_size * 1.05, head_size * 0.4, head_size * 1.05), hair_color)
		hair.position = Vector3(0.0, head_y + head_size * 0.45, 0.0)
		root.add_child(hair)
		parts["hair"] = { "node": hair, "min_lod": 1 }

	# Beard (independent component — §14).
	var beard_id: String = str(appearance.get("beard", "none"))
	if beard_id != "none" and beard_id != "":
		var beard := _make_box(Vector3(head_size * 0.7, head_size * 0.5, head_size * 0.25), beard_color)
		beard.position = Vector3(0.0, head_y - head_size * 0.1, -head_size * 0.55)
		root.add_child(beard)
		parts["beard"] = { "node": beard, "min_lod": 0 }

	# Equipment — placed at the socket for its current attachment state (§6, §7).
	var equipment: Dictionary = appearance.get("equipment", {})
	for slot in equipment:
		var entry: Dictionary = equipment[slot]
		var def: Dictionary = Defs.EQUIPMENT.get(str(entry.get("item", "")), {})
		if def.is_empty():
			continue
		var socket: String = _attachment_socket(def, str(entry.get("state", "equipped")))
		var local: Vector3 = _socket_offset(socket, props)
		var eq_color: Color = _equipment_color(def, entry)
		var size: Vector3 = _vec3(def.get("size", [0.3, 0.3, 0.3]))
		var mesh := _make_box(size, eq_color)
		mesh.position = local
		root.add_child(mesh)
		parts[str(slot)] = { "node": mesh, "min_lod": int(def.get("minLodLevel", 0)) }

	return { "root": root, "parts": parts }

func _make_box(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	# Pixel-art aesthetic lives at the asset level (Point filtering, low-res
	# textures, palettes), not in post-processing (§29). The placeholder uses
	# flat albedo until real assets exist.
	mesh.material_override = mat
	return mesh

## Resolve the socket for an equipment item's current attachment state (§7).
func _attachment_socket(def: Dictionary, state: String) -> String:
	var attachments: Dictionary = def.get("attachments", {})
	if attachments.has(state):
		return str(attachments[state])
	if attachments.has("equipped"):
		return str(attachments["equipped"])
	return "socket_back"

## Placeholder equipment color: RIGID metal items take the metal tone; otherwise
## the primary mask drives the color (multi-mask-region rendering needs real
## assets, deferred per §42).
func _equipment_color(def: Dictionary, entry: Dictionary) -> Color:
	var mode: String = str(def.get("deformationMode", "RIGID"))
	var metal: String = str(def.get("metal", "none"))
	if mode == "RIGID" and metal != "none" and metal != "":
		return _metal_color(metal)
	var masks: Dictionary = def.get("masks", {})
	if masks.get("primary", false):
		return palette_color(int(entry.get("primaryColor", 0)))
	if masks.get("accent", false):
		return palette_color(int(entry.get("accentColor", 0)))
	return palette_color(int(entry.get("secondaryColor", 0)))

func _metal_color(metal: String) -> Color:
	match metal:
		"iron", "ferrite":
			return Color(0.62, 0.62, 0.66)
		"steel", "veilsteel":
			return Color(0.72, 0.76, 0.82)
		"bronze":
			return Color(0.72, 0.55, 0.35)
		"gold":
			return Color(0.95, 0.78, 0.32)
		_:
			return Color(0.7, 0.7, 0.72)

## Placeholder socket → local offset for the humanoid family, scaled by the
## current proportions. Real rigs define these per skeleton; this mapping keeps
## the code-only placeholder assembly coherent.
func _socket_offset(socket: String, props: Dictionary) -> Vector3:
	var height: float = props.get("height", 1.0)
	var shoulder: float = props.get("shoulderWidth", 1.0)
	var leg_len: float = props.get("legLength", 1.0)
	var head_scale: float = props.get("headScale", 1.0)
	var arm_len: float = props.get("armLength", 1.0)

	var torso_h := 0.62 * height
	var hip_y := 0.38 * leg_len * height
	var chest_y := hip_y + torso_h * 0.6
	var head_size := 0.30 * head_scale
	var head_top := hip_y + torso_h + head_size
	var hand_x := 0.42 * shoulder
	var hand_y := chest_y - 0.05 * arm_len * height

	match socket:
		"socket_head", "socket_face":
			return Vector3(0.0, head_top, 0.0)
		"socket_weapon_r":
			return Vector3(hand_x, hand_y, 0.15)
		"socket_weapon_l":
			return Vector3(-hand_x, hand_y, 0.15)
		"socket_shield":
			return Vector3(-hand_x, hand_y, 0.0)
		"socket_hip_r":
			return Vector3(0.2, hip_y, 0.0)
		"socket_hip_l":
			return Vector3(-0.2, hip_y, 0.0)
		"socket_back":
			return Vector3(0.0, chest_y, -0.25)
		"socket_cape":
			return Vector3(0.0, chest_y + 0.15, -0.25)
		"socket_chest":
			return Vector3(0.0, chest_y, 0.0)
		_:
			return Vector3.ZERO

func _vec3(v) -> Vector3:
	if v is Vector3:
		return v
	if v is Array and v.size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return Vector3(0.3, 0.3, 0.3)
