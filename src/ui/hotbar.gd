extends HBoxContainer
## Hotbar — a row of item boxes along the bottom of the screen (Minecraft-style).
##
## The player never has to learn a key: items they carry that can be used at once (a
## placeable block, a piece of gear) drop into the first free box on their own; the mouse
## wheel steps the selection, a click selects a box, and the selected box is what a
## middle-click places or what is worn. A line above the row says what the selected box does.
##
## This node owns presentation and the selection only. The effect of a selection
## (set the place material, equip) is applied by the UI slice, which listens to
## `slot_selected`; the slice talks to the slices that own those rules.
##
## Pure, headless-testable statics: `kind_of`, `wrap_index`, `fill`, `hint_for`.

const EquipmentRules := preload("res://src/character/equipment_rules.gd")

signal slot_selected(index: int, item_id: String)

const SLOT_COUNT := 9
const SLOT_PX := 56.0
const KIND_BLOCK := "block"
const KIND_GEAR := "gear"
const KIND_NONE := ""

const COLOR_IDLE := Color(0.08, 0.08, 0.10, 0.72)
const COLOR_SELECTED := Color(0.22, 0.20, 0.10, 0.92)
const BORDER_IDLE := Color(0.45, 0.45, 0.5, 0.9)
const BORDER_SELECTED := Color(1.0, 0.85, 0.3, 1.0)

## Item id per box ("" = empty). Fixed length SLOT_COUNT.
var slots: Array = []
var selected: int = 0
## `Callable(item_id: String) -> Texture2D` (or null); set by the UI slice.
var icon_loader: Callable = Callable()
## `Callable() -> Dictionary` of item id -> quantity currently held; set by the UI slice.
var held_provider: Callable = Callable()

var _buttons: Array = []
var _hint: Label = null

func _init() -> void:
	name = "Hotbar"
	add_theme_constant_override("separation", 4)
	alignment = BoxContainer.ALIGNMENT_CENTER
	for i in SLOT_COUNT:
		slots.append("")

func build() -> void:
	for i in SLOT_COUNT:
		var b := Button.new()
		b.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.expand_icon = true
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(select_slot.bind(i))
		add_child(b)
		_buttons.append(b)
	refresh()

## The line above the row; created by the owner so it can be placed independently.
func set_hint_label(label: Label) -> void:
	_hint = label

# ---------------------------------------------------------------------------
# Pure helpers
# ---------------------------------------------------------------------------

## What using an item does: a placeable block, a wearable, or nothing.
static func kind_of(item_id: String, materials: Dictionary, equip_slot: String) -> String:
	if item_id == "":
		return KIND_NONE
	if materials.has(item_id):
		return KIND_BLOCK
	if equip_slot != "":
		return KIND_GEAR
	return KIND_NONE

## `index` moved by `delta` with wrap-around, so the wheel loops the row.
static func wrap_index(index: int, delta: int, count: int) -> int:
	if count <= 0:
		return 0
	return posmod(index + delta, count)

## The next box contents. A box whose item is no longer held empties; every held
## item for which `usable.call(id)` is true and that is not yet on the bar takes the first
## free box, in sorted order, so the result is deterministic. Boxes never reshuffle.
static func fill(current: Array, held: Dictionary, usable: Callable) -> Array:
	var out: Array = []
	for i in SLOT_COUNT:
		var id := str(current[i]) if i < current.size() else ""
		out.append(id if id != "" and int(held.get(id, 0)) > 0 else "")
	var keys: Array = held.keys()
	keys.sort()
	for key in keys:
		var id := str(key)
		if int(held[key]) <= 0 or out.has(id) or not bool(usable.call(id)):
			continue
		var free := out.find("")
		if free == -1:
			break
		out[free] = id
	return out

## The line shown above the row for the selected box.
static func hint_for(item_id: String, kind: String) -> String:
	match kind:
		KIND_BLOCK:
			return "%s  ·  middle-click to place" % item_id
		KIND_GEAR:
			return "%s  ·  worn" % item_id
	if item_id != "":
		return item_id
	return "Pick things up and they appear here  ·  scroll to choose"

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

func selected_item() -> String:
	return str(slots[selected])

func select_slot(index: int) -> void:
	selected = clampi(index, 0, SLOT_COUNT - 1)
	_render()
	slot_selected.emit(selected, selected_item())

## Mouse wheel: +1 steps right, -1 left.
func step(delta: int) -> void:
	select_slot(wrap_index(selected, delta, SLOT_COUNT))

## Select the box holding `item_id`, without re-announcing when it already is selected.
func select_item(item_id: String) -> bool:
	var idx := slots.find(item_id)
	if idx == -1:
		return false
	if idx != selected:
		select_slot(idx)
	return true

## Re-read what is held, update the boxes, and re-announce the selection if its item changed.
func refresh() -> void:
	var held: Dictionary = held_provider.call() if held_provider.is_valid() else {}
	var before := selected_item()
	slots = fill(slots, held, _is_usable)
	_render(held)
	if selected_item() != before:
		slot_selected.emit(selected, selected_item())

func _is_usable(item_id: String) -> bool:
	return kind_of(item_id, GameData.MATERIALS, _equip_slot(item_id)) != KIND_NONE

static func _equip_slot(item_id: String) -> String:
	return EquipmentRules.slot_of(item_id, GameData.ITEMS)

func kind_at(index: int) -> String:
	var id := str(slots[index])
	return kind_of(id, GameData.MATERIALS, _equip_slot(id))

func _render(held: Dictionary = {}) -> void:
	if held.is_empty() and held_provider.is_valid():
		held = held_provider.call()
	for i in _buttons.size():
		var b: Button = _buttons[i]
		var id := str(slots[i])
		var picked := i == selected
		b.add_theme_stylebox_override("normal", _box(picked, false))
		b.add_theme_stylebox_override("hover", _box(picked, true))
		b.add_theme_stylebox_override("pressed", _box(picked, true))
		b.icon = null
		if id == "":
			b.text = ""
			b.tooltip_text = "Empty box — things you pick up that you can place or wear appear here"
			continue
		var tex: Texture2D = icon_loader.call(id) if icon_loader.is_valid() else null
		var qty := int(held.get(id, 0))
		var count := ("×%d" % qty) if kind_at(i) == KIND_BLOCK else ""
		if tex != null:
			b.icon = tex
			b.text = count
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		else:
			b.text = ("%s\n%s" % [id.substr(0, 1).to_upper(), count]).strip_edges()
		b.tooltip_text = hint_for(id, kind_at(i))
	if _hint != null:
		_hint.text = hint_for(selected_item(), kind_at(selected))

func _box(picked: bool, hover: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = (COLOR_SELECTED if picked else COLOR_IDLE).lightened(0.08 if hover else 0.0)
	sb.border_color = BORDER_SELECTED if picked else BORDER_IDLE
	var w := 3 if picked else 1
	sb.set_border_width_all(w)
	sb.set_corner_radius_all(4)
	return sb
