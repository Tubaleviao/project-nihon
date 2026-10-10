extends VBoxContainer
## Hotbar — rows of boxes along the bottom of the screen (Minecraft-style) for the things a player
## wants one keypress or click away: placeable blocks, gear and skills.
##
## The bottom row has 9 boxes on the keys 1–9. Items the player carries that are usable at
## once (a placeable block, a piece of gear) drop into the first free box on their own, a click selects
## a box. An arrow at the end of the row inserts a second row below it. Its boxes are the player's
## own: drag anything in, then right-click a box to choose the key that fires it.
##
## Anything can be dragged onto a box: an item from the inventory, a skill from the Character window,
## or another box (they swap). A box dragged off the bar into the world is emptied. Dragging an item
## from the inventory into the world drops it on the ground; the UI slice handles that end of the
## drag.
##
## This node owns presentation, the box contents and the shortcut keys. The effect of a selection
## (set the place material, equip) is applied by the UI slice, which listens to `slot_selected`.
## A skill box emits `GameBus.skill_slot_triggered`; what the skill does belongs to the slice
## that implements its behaviors.
##
## Pure, headless-testable statics: `kind_of`, `fill`, `place`, `swap`, `bind_allowed`,
## `digit_slot`, `slot_for_key`, `parse_state`, `state_to_json`, `hint_for`.

const EquipmentRules := preload("res://src/character/equipment_rules.gd")
const SkillTiers := preload("res://src/core/skill_tiers.gd")

signal slot_selected(index: int, item_id: String)
## A drag began from a box; the UI slice uses it to empty the box if it is dropped in the world.
signal drag_began(payload: Dictionary)
## A short message for the player (choosing a shortcut key); the UI slice shows it.
signal notice(text: String)

const COLUMNS := 9
const SLOT_COUNT := 18            # row 1 = 0..8 (keys 1-9), row 2 = 9..17 (player-chosen keys)
const SLOT_PX := 56.0
const MORE_PX := 28.0
const KIND_BLOCK := "block"
const KIND_GEAR := "gear"
const KIND_SKILL := "skill"
const KIND_NONE := ""
const SKILL_PREFIX := "skill:"
const MAX_ENTRY_LEN := 64
const FLASH_SECONDS := 0.18

## Keys the game already uses; a box shortcut can never take them (so a bound key cannot
## fire two things). Letters are the keys of the window dock, movement, combat and building.
const RESERVED_KEYS: Array = [
	KEY_W, KEY_A, KEY_S, KEY_D, KEY_F, KEY_R, KEY_B, KEY_N, KEY_V, KEY_E, KEY_G,
	KEY_I, KEY_C, KEY_H, KEY_T, KEY_Y, KEY_P, KEY_M, KEY_Q,
	KEY_K, KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_TAB, KEY_SLASH, KEY_BACKSPACE,
	KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_QUESTION,
	KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9,
]

const COLOR_IDLE := Color(0.08, 0.08, 0.10, 0.72)
const COLOR_SELECTED := Color(0.22, 0.20, 0.10, 0.92)
const BORDER_IDLE := Color(0.45, 0.45, 0.5, 0.9)
const BORDER_SELECTED := Color(1.0, 0.85, 0.3, 1.0)

## Contents per box: an item id, `skill:<Key>`, or "" for empty. Fixed length SLOT_COUNT.
var slots: Array = []
## Shortcut keycode per box (0 = none). Boxes 0..8 are fixed to 1–9 and ignore this.
var binds: Array = []
var selected: int = 0
var expanded: bool = false
## Where the contents, shortcuts and expansion persist ("" = nowhere). A client-only view setting.
var save_path: String = ""
## `Callable(item_id: String) -> Texture2D` (or null); set by the UI slice.
var icon_loader: Callable = Callable()
## `Callable() -> Dictionary` of item id -> quantity held; set by the UI slice.
var held_provider: Callable = Callable()
## `Callable() -> Dictionary` of skill key -> tier name; set by the UI slice.
var tier_provider: Callable = Callable()

## Items the player took off the bar by hand: auto-fill leaves them out until they are used up.
var _declined: Dictionary = {}
var _buttons: Array = []
var _keys: Array = []
var _row1: HBoxContainer = null
var _row2: HBoxContainer = null
var _more: Button = null
var _menu: PopupMenu = null
var _menu_slot: int = -1
## Box waiting for its shortcut key (-1 = none).
var _binding: int = -1

func _init() -> void:
	name = "Hotbar"
	add_theme_constant_override("separation", 4)
	alignment = BoxContainer.ALIGNMENT_BEGIN
	for i in SLOT_COUNT:
		slots.append("")
		binds.append(0)

func build() -> void:
	# Row 1 (keys 1-9) is created first so `_buttons[i]` is box i; it is always visible and the
	# optional second row sits below it. The arrow's column is mirrored by a spacer so the rows align.
	_row1 = _make_row(0, COLUMNS)
	add_child(_row1)
	_more = Button.new()
	_more.custom_minimum_size = Vector2(MORE_PX, SLOT_PX)
	_more.focus_mode = Control.FOCUS_NONE
	_more.pressed.connect(func(): set_expanded(not expanded))
	_row1.add_child(_more)
	_row2 = _make_row(COLUMNS, SLOT_COUNT)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(MORE_PX, SLOT_PX)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row2.add_child(spacer)
	add_child(_row2)
	_menu = PopupMenu.new()
	_menu.add_item("Set shortcut key…", 0)
	_menu.add_item("Clear shortcut", 1)
	_menu.add_item("Empty this box", 2)
	_menu.id_pressed.connect(_on_menu_pressed)
	add_child(_menu)
	load_state()
	_render()   # not refresh(): the inventory may not be wired yet, and nothing held would empty the saved boxes

func _make_row(from: int, to: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	for i in range(from, to):
		var b := Button.new()
		b.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.expand_icon = true
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(activate.bind(i))
		b.gui_input.connect(_on_slot_gui_input.bind(i))
		b.set_drag_forwarding(_get_drag.bind(i, b), _can_drop, _drop.bind(i))
		var key := Label.new()
		key.position = Vector2(4.0, 1.0)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key.add_theme_font_size_override("font_size", 11)
		key.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		key.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		key.add_theme_constant_override("outline_size", 3)
		b.add_child(key)
		row.add_child(b)
		_buttons.append(b)
		_keys.append(key)
	return row

# ---------------------------------------------------------------------------
# Pure helpers
# ---------------------------------------------------------------------------

## What using an entry does: a placeable block, a wearable, a skill, or nothing.
static func kind_of(entry: String, materials: Dictionary, equip_slot: String) -> String:
	if entry == "":
		return KIND_NONE
	if is_skill(entry):
		return KIND_SKILL
	if materials.has(entry):
		return KIND_BLOCK
	if equip_slot != "":
		return KIND_GEAR
	return KIND_NONE

static func is_skill(entry: String) -> bool:
	return entry.begins_with(SKILL_PREFIX)

static func skill_key(entry: String) -> String:
	return entry.trim_prefix(SKILL_PREFIX)

static func skill_entry(skill: String) -> String:
	return SKILL_PREFIX + skill

## Skill keys of `tiers` (key -> tier name), best tier first, ties by name.
static func ordered_skills(tiers: Dictionary) -> Array:
	var keys: Array = tiers.keys().map(func(k): return str(k))
	keys.sort_custom(func(a, b):
		var ra := SkillTiers.rank(str(tiers.get(a, "novice")))
		var rb := SkillTiers.rank(str(tiers.get(b, "novice")))
		return ra > rb if ra != rb else a < b)
	return keys

## The next box contents. A box whose ITEM is no longer held empties (a skill stays). Every held
## item for which `usable.call(id)` is true, that is not yet on the bar and was not taken
## off by hand (`declined`), takes the first free box of the bottom row, in sorted order, so the
## result is deterministic. Boxes never reshuffle.
static func fill(current: Array, held: Dictionary, usable: Callable, declined: Dictionary = {}) -> Array:
	var out: Array = []
	for i in SLOT_COUNT:
		var id := str(current[i]) if i < current.size() else ""
		var keep := id != "" and (is_skill(id) or int(held.get(id, 0)) > 0)
		out.append(id if keep else "")
	var keys: Array = held.keys()
	keys.sort()
	for key in keys:
		var id := str(key)
		if int(held[key]) <= 0 or out.has(id) or declined.has(id) or not bool(usable.call(id)):
			continue
		var free := out.find("")
		if free == -1 or free >= COLUMNS:
			break
		out[free] = id
	return out

## `slots` with `entry` in box `index`; if it was in another box it moves (never twice on the bar).
static func place(current: Array, index: int, entry: String) -> Array:
	var out := current.duplicate()
	if index < 0 or index >= SLOT_COUNT:
		return out
	for i in out.size():
		if entry != "" and out[i] == entry:
			out[i] = ""
	out[index] = entry
	return out

static func swap(current: Array, a: int, b: int) -> Array:
	var out := current.duplicate()
	if a < 0 or b < 0 or a >= SLOT_COUNT or b >= SLOT_COUNT:
		return out
	var tmp = out[a]
	out[a] = out[b]
	out[b] = tmp
	return out

## Whether a key may become a box shortcut: a letter, a digit 0, or a function key that the game has
## not claimed.
static func bind_allowed(keycode: int) -> bool:
	if RESERVED_KEYS.has(keycode):
		return false
	return (keycode >= KEY_A and keycode <= KEY_Z) or keycode == KEY_0 or (keycode >= KEY_F1 and keycode <= KEY_F12)

## The box a bottom-row digit key fires: KEY_1 -> 0 ... KEY_9 -> 8, else -1.
static func digit_slot(keycode: int) -> int:
	var idx := keycode - KEY_1
	return idx if idx >= 0 and idx < COLUMNS else -1

## The second-row box bound to `keycode`, or -1.
static func slot_for_key(bound: Array, keycode: int) -> int:
	if keycode == 0:
		return -1
	for i in range(COLUMNS, SLOT_COUNT):
		if int(bound[i]) == keycode:
			return i
	return -1

## What the box does, for the line above the row and the tooltip.
static func hint_for(entry: String, kind: String, tier: String = "") -> String:
	match kind:
		KIND_BLOCK:
			return "%s  ·  middle-click to place" % entry
		KIND_GEAR:
			return "%s  ·  worn" % entry
		KIND_SKILL:
			return "%s%s  ·  press its key to use" % [skill_key(entry), (" (%s)" % tier) if tier != "" else ""]
	return entry

## Parse the saved state. Anything malformed falls back to an empty bar rather than injecting junk.
static func parse_state(text: String) -> Dictionary:
	var out := {"slots": [], "binds": [], "expanded": false}
	for i in SLOT_COUNT:
		out["slots"].append("")
		out["binds"].append(0)
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return out
	var d: Dictionary = json.data
	var s = d.get("slots", null)
	if s is Array:
		for i in mini(s.size(), SLOT_COUNT):
			if s[i] is String and (s[i] as String).length() <= MAX_ENTRY_LEN:
				out["slots"][i] = s[i]
	var b = d.get("binds", null)
	if b is Array:
		for i in mini(b.size(), SLOT_COUNT):
			if (b[i] is float or b[i] is int) and i >= COLUMNS and bind_allowed(int(b[i])):
				out["binds"][i] = int(b[i])
	var ex = d.get("expanded", false)
	out["expanded"] = ex is bool and ex
	return out

static func state_to_json(slot_list: Array, bind_list: Array, is_expanded: bool) -> String:
	return JSON.stringify({"slots": slot_list, "binds": bind_list, "expanded": is_expanded})

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

func selected_item() -> String:
	return str(slots[selected])

func kind_at(index: int) -> String:
	var entry := str(slots[index])
	return kind_of(entry, GameData.MATERIALS, "" if is_skill(entry) else _equip_slot(entry))

static func _equip_slot(item_id: String) -> String:
	return EquipmentRules.slot_of(item_id, GameData.ITEMS)

func _is_usable(item_id: String) -> bool:
	return kind_of(item_id, GameData.MATERIALS, _equip_slot(item_id)) != KIND_NONE

## A click or key on a box: a skill fires, anything else becomes the selection.
func activate(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return
	var entry := str(slots[index])
	if is_skill(entry):
		GameBus.skill_slot_triggered.emit(index, skill_key(entry))
		_flash(index)
		return
	select_slot(index)

func select_slot(index: int) -> void:
	selected = clampi(index, 0, SLOT_COUNT - 1)
	_render()
	slot_selected.emit(selected, selected_item())

## Select the box holding `item_id`, without re-announcing when it already is selected.
func select_item(item_id: String) -> bool:
	var idx := slots.find(item_id)
	if idx == -1:
		return false
	if idx != selected:
		select_slot(idx)
	return true

func set_expanded(open: bool) -> void:
	expanded = open
	_render()
	save_state()

## Re-read what is held, update the boxes, and re-announce the selection if its item changed.
func refresh() -> void:
	var held: Dictionary = held_provider.call() if held_provider.is_valid() else {}
	for id in _declined.keys():
		if int(held.get(id, 0)) <= 0:
			_declined.erase(id)
	var before := selected_item()
	slots = fill(slots, held, _is_usable, _declined)
	_render(held)
	if selected_item() != before:
		slot_selected.emit(selected, selected_item())

## Empty a box by hand. An item taken off stays off until it is used up.
func clear_slot(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return
	var entry := str(slots[index])
	if entry != "" and not is_skill(entry):
		_declined[entry] = true
	_set_slots(place(slots, index, ""))

## Put `entry` (an item id or `skill:<Key>`) into a box.
func assign(index: int, entry: String) -> void:
	_declined.erase(entry)
	_set_slots(place(slots, index, entry))

func _set_slots(next: Array) -> void:
	var before := selected_item()
	slots = next
	_render()
	save_state()
	if selected_item() != before:
		slot_selected.emit(selected, selected_item())

# ---------------------------------------------------------------------------
# Keys
# ---------------------------------------------------------------------------

## Offer a key press to the bar. Returns true when it was used (a box fired, or a shortcut was
## being chosen), so the caller can stop other handlers from also reacting.
func handle_key(event: InputEventKey) -> bool:
	if not event.pressed or event.echo:
		return false
	var keycode := int(event.keycode)
	if _binding >= 0:
		_finish_binding(keycode)
		return true
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return false
	var d := digit_slot(keycode)
	if d != -1:
		activate(d)
		return true
	var s := slot_for_key(binds, keycode)
	if s != -1:
		activate(s)
		return true
	return false

func is_binding() -> bool:
	return _binding >= 0

func begin_binding(index: int) -> void:
	if index < COLUMNS or index >= SLOT_COUNT:
		return   # the bottom row is fixed to 1-9
	_binding = index
	set_expanded(true)
	_render()
	notice.emit("Press the key for this box  ·  Esc cancels  ·  Backspace clears")

func _finish_binding(keycode: int) -> void:
	var index := _binding
	_binding = -1
	if keycode == KEY_ESCAPE:
		pass
	elif keycode == KEY_BACKSPACE:
		binds[index] = 0
	elif bind_allowed(keycode):
		for i in SLOT_COUNT:
			if int(binds[i]) == keycode:
				binds[i] = 0
		binds[index] = keycode
	else:
		notice.emit("%s is already used by the game — pick another key" % OS.get_keycode_string(keycode))
		_binding = index
		return
	save_state()
	_render()

# ---------------------------------------------------------------------------
# Mouse: menu, drag and drop
# ---------------------------------------------------------------------------

func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_RIGHT:
		return
	_menu_slot = index
	_menu.set_item_disabled(0, index < COLUMNS)
	_menu.set_item_disabled(1, index < COLUMNS or int(binds[index]) == 0)
	_menu.set_item_disabled(2, str(slots[index]) == "")
	_menu.position = Vector2i(get_viewport().get_mouse_position()) if is_inside_tree() else Vector2i.ZERO
	_menu.popup()
	accept_event()

func _on_menu_pressed(id: int) -> void:
	match id:
		0:
			begin_binding(_menu_slot)
		1:
			binds[_menu_slot] = 0
			save_state()
			_render()
		2:
			clear_slot(_menu_slot)

func _get_drag(_at: Vector2, index: int, source: Control) -> Variant:
	var entry := str(slots[index])
	if entry == "":
		return null
	var label := Label.new()
	label.text = skill_key(entry) if is_skill(entry) else entry
	source.set_drag_preview(label)
	var payload := {"kind": "hotbar", "from": index, "id": entry}
	drag_began.emit(payload)
	return payload

func _can_drop(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and ["item", "skill", "hotbar"].has(str(data.get("kind", ""))) and str(data.get("id", "")) != ""

func _drop(_at: Vector2, data: Variant, index: int) -> void:
	if not _can_drop(_at, data):
		return
	match str(data["kind"]):
		"item":
			assign(index, str(data["id"]))
		"skill":
			assign(index, skill_entry(str(data["id"])))
		"hotbar":
			_set_slots(swap(slots, int(data["from"]), index))

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func save_state() -> void:
	if save_path == "":
		return
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f != null:
		f.store_string(state_to_json(slots, binds, expanded))

func load_state() -> void:
	if save_path == "" or not FileAccess.file_exists(save_path):
		return
	var parsed := parse_state(FileAccess.get_file_as_string(save_path))
	slots = parsed["slots"]
	binds = parsed["binds"]
	expanded = bool(parsed["expanded"])

# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _flash(index: int) -> void:
	if index >= _buttons.size() or not is_inside_tree():
		return
	var b: Button = _buttons[index]
	b.modulate = Color(1.6, 1.5, 0.8)
	create_tween().tween_property(b, "modulate", Color.WHITE, FLASH_SECONDS)

func _key_text(index: int) -> String:
	if index < COLUMNS:
		return str(index + 1)
	if _binding == index:
		return "…"
	var k := int(binds[index])
	return OS.get_keycode_string(k) if k != 0 else ""

func _render(held: Dictionary = {}) -> void:
	if held.is_empty() and held_provider.is_valid():
		held = held_provider.call()
	var tiers: Dictionary = tier_provider.call() if tier_provider.is_valid() else {}
	if _row2 != null:
		_row2.visible = expanded
	if _more != null:
		_more.text = "▴" if expanded else "▾"
		_more.tooltip_text = "Fewer boxes" if expanded else "More boxes — drag items and skills in, then right-click a box to pick its key"
	for i in _buttons.size():
		var b: Button = _buttons[i]
		var entry := str(slots[i])
		var picked := i == selected
		b.add_theme_stylebox_override("normal", _box(picked, false))
		b.add_theme_stylebox_override("hover", _box(picked, true))
		b.add_theme_stylebox_override("pressed", _box(picked, true))
		b.icon = null
		(_keys[i] as Label).text = _key_text(i)
		if entry == "":
			b.text = ""
			b.tooltip_text = "Empty box — pick things up, or drag an item or skill here"
			continue
		var kind := kind_at(i)
		if kind == KIND_SKILL:
			var skill := skill_key(entry)
			b.text = skill.substr(0, 4)
			b.tooltip_text = hint_for(entry, kind, str(tiers.get(skill, "")))
			continue
		var tex: Texture2D = icon_loader.call(entry) if icon_loader.is_valid() else null
		var count := ("×%d" % int(held.get(entry, 0))) if kind == KIND_BLOCK else ""
		if tex != null:
			b.icon = tex
			b.text = count
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		else:
			b.text = ("%s\n%s" % [entry.substr(0, 1).to_upper(), count]).strip_edges()
		b.tooltip_text = hint_for(entry, kind)

func _box(picked: bool, hover: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = (COLOR_SELECTED if picked else COLOR_IDLE).lightened(0.08 if hover else 0.0)
	sb.border_color = BORDER_SELECTED if picked else BORDER_IDLE
	sb.set_border_width_all(3 if picked else 1)
	sb.set_corner_radius_all(4)
	return sb
