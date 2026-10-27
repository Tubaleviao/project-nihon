extends RefCounted
## Phase 179 — the character sheet: the projection the Character window draws (`rows()`), the drop
## rule for its equipment slots, and the widgets (a rig preview, slots around it, attribute and
## derived-stat panels, a skills summary). The window itself is built by `UiSlice`; this class owns what is in it.
## Numbers come from the player body's attribute table (the host's synced copy) through
## `AttributeRules`, so the sheet shows exactly the values the host uses.

const I18n := preload("res://src/core/i18n.gd")
const AttributeRules := preload("res://src/character/attribute_rules.gd")
const EquipmentRules := preload("res://src/character/equipment_rules.gd")
const UiIcons := preload("res://src/ui/ui_icons.gd")

const ATTRIBUTE_FORMAT := "icons/attributes/%s.png.raw"
const SKILLS_SHOWN := 4
## Slots laid out left and right of the doll, by body position; a slot the fabric adds later goes right.
const LEFT_SLOTS := ["Head", "Chest", "Cape"]
const RIGHT_SLOTS := ["MainHand", "OffHand"]
const PREVIEW_SIZE := Vector2i(180, 260)

var sl: Node

func _init(slice: Node) -> void:
	sl = slice

static func attribute_key(attribute: String) -> String:
	return ATTRIBUTE_FORMAT % attribute

## Which side of the doll a slot sits on: "left" or "right".
static func side_of(slot: String) -> String:
	return "left" if LEFT_SLOTS.has(slot) else "right"

## The attribute table the sheet shows: the body's synced copy, else base values.
func attributes() -> Dictionary:
	if sl.player_slice != null and sl.player_slice.get("attributes") is Dictionary:
		return AttributeRules.sanitize(sl.player_slice.attributes)
	return AttributeRules.defaults()

## `value` of derived stat `stat_id` as the player reads it: an amount with its unit, a factor as ×n, a chance as a percent.
static func format_stat(stat_id: String, value: float) -> String:
	var r: Dictionary = AttributeRules.derivation().get(stat_id, {})
	match str(r.get("kind", "")):
		"amount":
			return "%s %s" % [I18n.number(value, 2 if absf(value) < 10.0 else 0), str(r.get("unit", ""))]
		"chance":
			return "%s%%" % I18n.number(value * 100.0, 1)
		"bonus":
			return "+%s" % I18n.number(value, 2)
	return "×%s" % I18n.number(value, 2)

## The derived stat ids an attribute feeds, in fabric order.
static func stats_fed_by(attribute: String) -> Array:
	var out: Array = []
	var d := AttributeRules.derivation()
	for id in d:
		if str((d[id] as Dictionary).get("attribute", "")) == attribute:
			out.append(str(id))
	return out

## { name, equipment, attributes, stats, skills }: everything the sheet shows, as data.
func rows() -> Dictionary:
	var attrs := attributes()
	var equipment: Array = []
	for r in sl.character_rows():
		var row: Dictionary = (r as Dictionary).duplicate()
		var item := str(row["item"])
		row["durability"] = str(sl.durability_bar(item)).strip_edges() if item != "" else ""
		row["side"] = side_of(str(row["slot"]))
		equipment.append(row)
	var attr_rows: Array = []
	var lo := AttributeRules.creation_min()
	var span := float(maxi(AttributeRules.hard_cap() - lo, 1))
	for a in AttributeRules.ids():
		var value := int(attrs[a])
		var lines: Array = []
		for sid in stats_fed_by(str(a)):
			lines.append("%s: %s" % [I18n.t("stat.%s" % sid), format_stat(sid, AttributeRules.stat(sid, attrs))])
		attr_rows.append({
			"id": a, "name": I18n.t("attr.%s.name" % a), "value": value,
			"icon_key": attribute_key(str(a)),
			"progress": clampf(float(value - lo) / span, 0.0, 1.0),
			"tooltip": "%s\n%s" % [I18n.t("attr.%s.desc" % a), "\n".join(lines)],
		})
	var stat_rows: Array = []
	for id in AttributeRules.derivation():
		var v := AttributeRules.stat(str(id), attrs)
		stat_rows.append({ "id": id, "label": I18n.t("stat.%s" % id), "value": v, "text": format_stat(str(id), v) })
	var skills: Array = []
	var tiers: Dictionary = sl.crafting_slice.get_skills() if sl.crafting_slice != null else {}
	for r in sl.skills_rows(tiers).slice(0, SKILLS_SHOWN):
		skills.append({ "id": r["id"], "tier": r["tier"], "icon_key": UiIcons.skill_key(str(r["id"])), "tooltip": r["tooltip"] })
	return { "name": sl.own_handle, "equipment": equipment, "attributes": attr_rows, "stats": stat_rows, "skills": skills }

## Dropping `data` (a drag payload) on the equipment slot `slot`: only an item that belongs in the slot is worn,
## through the same call as the context menu's Equip. A worn item dropped on its own slot is ignored.
func can_drop_on_slot(slot: String, data: Variant) -> bool:
	return data is Dictionary and str(data.get("kind", "")) == "item" \
		and EquipmentRules.slot_of(str(data.get("id", "")), GameData.ITEMS) == slot

func drop_on_slot(slot: String, data: Variant) -> bool:
	if not can_drop_on_slot(slot, data):
		return false
	return sl.dispatch_item_action(str(data["id"]), "equip")

## A worn item dragged off its slot and dropped on the bag is taken off, as the context menu's Unequip does.
func drop_on_bag(data: Variant) -> bool:
	if not (data is Dictionary and str(data.get("kind", "")) == "worn"):
		return false
	return sl.dispatch_item_action(str(data.get("id", "")), "unequip")

# ---------------------------------------------------------------------------
# Widgets
# ---------------------------------------------------------------------------

## The rig preview: a SubViewport with its own world showing the player rig, turned by dragging, idling.
class DollView extends SubViewportContainer:
	var viewport: SubViewport
	var rig: Node3D = null
	var _drag := false

	func _init() -> void:
		stretch = true
		custom_minimum_size = Vector2(PREVIEW_SIZE)
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		viewport = SubViewport.new()
		viewport.own_world_3d = true
		viewport.transparent_bg = true
		viewport.size = PREVIEW_SIZE
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var cam := Camera3D.new()
		cam.position = Vector3(0.0, 1.0, 5.5)
		cam.fov = 30.0
		viewport.add_child(cam)
		cam.look_at_from_position(cam.position, Vector3(0.0, 0.95, 0.0))
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-35.0, 30.0, 0.0)
		viewport.add_child(sun)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_drag = event.pressed
		elif event is InputEventMouseMotion and _drag and rig != null:
			rig.rotate_y(event.relative.x * 0.01)

	## Replace the preview with a body built under the viewport by `CharacterSlice.build_preview`. False when there is none.
	func rebuild_preview(character_slice: Node) -> bool:
		clear_preview()
		rig = character_slice._m2.build_preview(viewport)   # the sheet's second body: character_part_2.gd
		return rig != null

	## Free the preview body.
	func clear_preview() -> void:
		if rig != null and is_instance_valid(rig):
			rig.free()
		rig = null

	func has_rig() -> bool:
		return rig != null and is_instance_valid(rig)

	## True when the preview has drawn something (any pixel with alpha).
	func is_drawn() -> bool:
		var img := viewport.get_texture().get_image()
		if img == null or img.is_empty():
			return false
		for y in range(0, img.get_height(), 4):
			for x in range(0, img.get_width(), 4):
				if img.get_pixel(x, y).a > 0.05:
					return true
		return false
