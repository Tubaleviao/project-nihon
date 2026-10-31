extends RefCounted
## Phase 179 — the character sheet: pure projections of the attribute and derived-stat panels, and the paper-doll
## preview. Numbers come from `AttributeRules` (the fabric formula) over the body's synced attribute table; text goes
## through `I18n`. The window itself is built in `ui_slice.gd`.

const AttributeRules := preload("res://src/character/attribute_rules.gd")
const UiIcons := preload("res://src/ui/ui_icons.gd")
const I18n := preload("res://src/core/i18n.gd")

## Equipment slots drawn left and right of the doll, by body position; any other slot sits in a row under it.
const LEFT_SLOTS := ["Head", "Chest", "Cape"]
const RIGHT_SLOTS := ["MainHand", "OffHand"]
## How many skills the sheet summarises.
const TOP_SKILLS := 4
## The doll turns this many radians per dragged pixel, and idles at this speed (rad/s).
const DRAG_RADIANS_PER_PIXEL := 0.012
const IDLE_TURN_RAD_PER_S := 0.35


## One derived stat's value as text, per its fabric kind. The unit is the fabric's (`kg`, `hp`, `m`).
static func format_stat(stat_id: String, value: float) -> String:
	var row: Variant = AttributeRules.derivation().get(stat_id, null)
	var kind := str((row as Dictionary).get("kind", "amount")) if row is Dictionary else "amount"
	match kind:
		"factor":
			return "×" + I18n.number(value, 2)
		"chance":
			return I18n.number(value * 100.0, 1) + "%"
		"bonus":
			return ("+" if value >= 0.0 else "") + I18n.number(value, 1)
	var unit := str((row as Dictionary).get("unit", "")) if row is Dictionary else ""
	var text := I18n.number(value, 2 if value < 10.0 else 1)
	return text if unit == "" else text + " " + unit


## One row per derived stat fed by `attribute`: { id, label, value, text }.
static func fed_stats(attribute: String, attributes: Dictionary) -> Array:
	var rows: Array = []
	var derivation := AttributeRules.derivation()
	var ids: Array = derivation.keys()
	ids.sort()
	for id in ids:
		if str((derivation[id] as Dictionary)["attribute"]) != attribute:
			continue
		var v := AttributeRules.stat(str(id), attributes)
		rows.append({ "id": str(id), "label": I18n.t("stat.%s" % id), "value": v, "text": format_stat(str(id), v) })
	return rows


## Attribute rows: { section, id, name, value, icon_key, points, progress, maxed, tooltip }. `growth` is the
## `{ points, xp }` state the host banked; progress is the XP toward the next point (0..1).
static func attribute_rows(attributes: Dictionary, growth: Dictionary) -> Array:
	var rows: Array = []
	var points: Dictionary = growth.get("points", {})
	var xp: Dictionary = growth.get("xp", {})
	for a in AttributeRules.ids():
		var id := str(a)
		var grown := int(points.get(id, 0))
		var maxed := not AttributeRules.can_grow(id, attributes, growth)
		var cost := AttributeRules.cost_of_next(grown)
		var progress := 1.0 if maxed else clampf(float(xp.get(id, 0.0)) / cost, 0.0, 1.0)
		var lines: Array = [I18n.t("attr.%s.desc" % id)]
		for f in fed_stats(id, attributes):
			lines.append("%s: %s" % [f["label"], f["text"]])
		rows.append({
			"section": "attribute", "id": id, "name": I18n.t("attr.%s.name" % id),
			"value": int(attributes.get(id, AttributeRules.base())), "icon_key": UiIcons.attribute_key(id),
			"points": grown, "progress": progress, "maxed": maxed, "tooltip": "\n".join(lines),
		})
	return rows


## Derived-stat rows: { section, id, label, value, text }, sorted by id.
static func stat_rows(attributes: Dictionary) -> Array:
	var rows: Array = []
	var ids: Array = AttributeRules.derivation().keys()
	ids.sort()
	for id in ids:
		var v := AttributeRules.stat(str(id), attributes)
		rows.append({ "section": "stat", "id": str(id), "label": I18n.t("stat.%s" % id), "value": v, "text": format_stat(str(id), v) })
	return rows


## The first `TOP_SKILLS` of the skills window's rows, as sheet rows: { section, id, tier, tooltip }.
static func skill_rows(all_rows: Array) -> Array:
	var rows: Array = []
	for r in all_rows.slice(0, TOP_SKILLS):
		rows.append({ "section": "skill", "id": str(r["id"]), "tier": str(r["tier"]), "tooltip": str(r["tooltip"]) })
	return rows


## Which column a slot sits in: "left", "right" or "bottom".
static func column_of(slot: String) -> String:
	if slot in LEFT_SLOTS:
		return "left"
	return "right" if slot in RIGHT_SLOTS else "bottom"


## The doll: a viewport of its own world holding a copy of the local rig. Drag turns it; left alone it idles on a
## slow turn. `rebuild` swaps the rig when the appearance or the worn set changed.
class Doll extends SubViewportContainer:
	var viewport: SubViewport
	var pivot: Node3D
	var _dragging := false

	func _init() -> void:
		custom_minimum_size = Vector2(150, 220)
		stretch = true
		viewport = SubViewport.new()
		viewport.own_world_3d = true
		viewport.transparent_bg = true
		viewport.size = Vector2i(150, 220)
		viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
		add_child(viewport)
		pivot = Node3D.new()
		viewport.add_child(pivot)
		var cam := Camera3D.new()
		cam.position = Vector3(0.0, 0.95, 3.1)
		cam.fov = 38.0
		viewport.add_child(cam)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-35.0, 30.0, 0.0)
		viewport.add_child(sun)

	func rebuild(visual: Node3D) -> void:
		for c in pivot.get_children():
			pivot.remove_child(c)
			c.free()
		if visual != null:
			pivot.add_child(visual)

	func has_rig() -> bool:
		return pivot.get_child_count() > 0

	func _process(delta: float) -> void:
		if not _dragging and is_visible_in_tree():
			pivot.rotate_y(IDLE_TURN_RAD_PER_S * delta)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_dragging = (event as InputEventMouseButton).pressed
		elif event is InputEventMouseMotion and _dragging:
			pivot.rotate_y((event as InputEventMouseMotion).relative.x * DRAG_RADIANS_PER_PIXEL)

## Phase 199 — the settlement specialty row of the sheet: [] when the host named none (or the player has no
## settlement), else one { section "specialty", id, name, icon_key } row.
static func specialty_rows(specialty: String) -> Array:
	if specialty == "":
		return []
	return [{ "section": "specialty", "id": specialty, "name": I18n.t("character.specialty", [I18n.t("settlement.specialty." + specialty)]),
		"icon_key": UiIcons.specialty_key(specialty) }]
