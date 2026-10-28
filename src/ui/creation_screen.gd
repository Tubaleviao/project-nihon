extends Control
## Phase 181 — the character creation screen, shown before a new player enters the world.
##
## Layout (fixed here, in code): the hair style grid (icons) on the left with the hair colour row under it, the
## live chibi rig in the centre on a dark backdrop inside a frame, a gender toggle on either side of the rig, and
## the name field with "enter the world" at the bottom right. A randomize button picks a gender, hair and colour;
## "skip" keeps the default look and the handle.
##
## The skin is art at overlay keys, never a theme: each PNG is loaded through `AssetOverlay.load_texture` and the
## `StyleBoxTexture`s are built here with fixed patch margins, so the private pack replaces pixels without a code
## change. The public placeholders come from `tools/gen_ui_skin.py` (skin) and `tools/gen_ui_icons.py` (icons).
##
## The screen sends `character_creation_intent` and shows the host's keyed refusal in this machine's locale
## (`on_resolved`); it never decides a creation itself.

const CreationRules := preload("res://src/character/creation_rules.gd")
const CharacterSheet := preload("res://src/ui/character_sheet.gd")
const UiIcons := preload("res://src/ui/ui_icons.gd")
const I18n := preload("res://src/core/i18n.gd")

## Skin keys and the size (px) each is drawn at. The generator writes the placeholders at these sizes and the
## suite checks they match, so a placeholder and the art agree on what a patch margin means.
const SKIN := {
	"backdrop":       { "key": "textures/ui/creation/backdrop.png.raw",       "size": Vector2i(256, 256) },
	"panel":          { "key": "textures/ui/creation/panel.png.raw",          "size": Vector2i(48, 48) },
	"rig_frame":      { "key": "textures/ui/creation/rig_frame.png.raw",      "size": Vector2i(64, 64) },
	"button":         { "key": "textures/ui/creation/button.png.raw",         "size": Vector2i(48, 32) },
	"button_hover":   { "key": "textures/ui/creation/button_hover.png.raw",   "size": Vector2i(48, 32) },
	"button_pressed": { "key": "textures/ui/creation/button_pressed.png.raw", "size": Vector2i(48, 32) },
}
## Icon keys the screen reads beside the hair icons (`icons/hair/<id>.png.raw`).
const ICONS := {
	"randomize": "icons/ui/creation/randomize.png.raw",
	"masculine": "icons/ui/creation/gender_masculine.png.raw",
	"feminine":  "icons/ui/creation/gender_feminine.png.raw",
}
const HAIR_ICON_FORMAT := "icons/hair/%s.png.raw"
## 9-slice patch margins (px), the same on every side.
const PANEL_MARGIN := 12
const FRAME_MARGIN := 16
const BUTTON_MARGIN := 8
## Layout sizes (px).
const OUTER_MARGIN := 32
const HAIR_COLUMNS := 3
const HAIR_BUTTON := Vector2(64, 64)
const SWATCH := Vector2(28, 28)
const SWATCH_COLUMNS := 6
const RIG_SIZE := Vector2(300, 420)
const GENDER_BUTTON := Vector2(72, 72)
const NAME_WIDTH := 260.0
const TITLE_FONT := 30
const LABEL_FONT := 16
const ERROR_FONT := 15

## Builds the rig shown in the centre from an appearance recipe (`CharacterSlice._make_visual`); unset in a rig
## with no character slice, where the doll stays empty.
var visual_builder: Callable = Callable()
## Palette index -> Color for the swatches; unset, they draw grey.
var palette: Callable = Callable()

var choice: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _name: LineEdit
var _error: Label
var _doll: CharacterSheet.Doll
var _hair_grid: GridContainer
var _colors: GridContainer
var _gender_buttons: Dictionary = {}
var _texts: Array = []   # [control, property, key] re-rendered on a locale change
var _doll_key := ""


func _init() -> void:
	name = "CreationScreen"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	choice = CreationRules.default_choice()


func _ready() -> void:
	_build()
	refresh()


## Every skin key the screen reads.
static func skin_keys() -> Array:
	var out: Array = []
	for k in SKIN:
		out.append(str(SKIN[k]["key"]))
	return out


## Every icon key the screen reads: its own controls and one per hair style.
static func icon_keys() -> Array:
	var out: Array = ICONS.values()
	var d := CreationRules.data()
	if d != null:
		for id in (d.get("hairStyles") as Dictionary):
			out.append(HAIR_ICON_FORMAT % id)
	return out


## The hair picker's cells for a gender: [{ id, icon_key }].
static func hair_rows(gender: String) -> Array:
	var rows: Array = []
	for id in CreationRules.hair_options(gender):
		rows.append({ "id": id, "icon_key": HAIR_ICON_FORMAT % id })
	return rows


## A 9-slice stylebox over a skin texture (null when the key does not decode).
static func skin_box(skin_id: String, margin: int) -> StyleBoxTexture:
	var tex := AssetOverlay.load_texture(str(SKIN[skin_id]["key"]))
	if tex == null:
		return null
	var box := StyleBoxTexture.new()
	box.texture = tex
	box.texture_margin_left = margin
	box.texture_margin_right = margin
	box.texture_margin_top = margin
	box.texture_margin_bottom = margin
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = margin
	box.content_margin_bottom = margin
	return box


static func _skin_button(b: Button) -> void:
	for pair in [["normal", "button"], ["hover", "button_hover"], ["pressed", "button_pressed"], ["hover_pressed", "button_pressed"], ["focus", "button_hover"]]:
		var box := skin_box(pair[1], BUTTON_MARGIN)
		if box != null:
			b.add_theme_stylebox_override(pair[0], box)


func _tr(ctrl: Control, prop: String, key: String) -> void:
	ctrl.set(prop, I18n.t(key))
	_texts.append([ctrl, prop, key])


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var box := skin_box("panel", PANEL_MARGIN)
	if box != null:
		p.add_theme_stylebox_override("panel", box)
	return p


func _build() -> void:
	var backdrop := TextureRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.texture = AssetOverlay.load_texture(str(SKIN["backdrop"]["key"]))
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, OUTER_MARGIN)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", TITLE_FONT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tr(title, "text", "creation.title")
	column.add_child(title)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	column.add_child(body)

	# Left: the hair grid, the colour row under it.
	var left := _panel()
	left.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_child(left)
	var left_box := VBoxContainer.new()
	left_box.add_theme_constant_override("separation", 10)
	left.add_child(left_box)
	var hair_label := Label.new()
	hair_label.add_theme_font_size_override("font_size", LABEL_FONT)
	_tr(hair_label, "text", "creation.hair")
	left_box.add_child(hair_label)
	_hair_grid = GridContainer.new()
	_hair_grid.columns = HAIR_COLUMNS
	left_box.add_child(_hair_grid)
	var color_label := Label.new()
	color_label.add_theme_font_size_override("font_size", LABEL_FONT)
	_tr(color_label, "text", "creation.hair_color")
	left_box.add_child(color_label)
	_colors = GridContainer.new()
	_colors.columns = SWATCH_COLUMNS
	left_box.add_child(_colors)

	# Centre: a gender toggle either side of the framed rig.
	var centre := HBoxContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_theme_constant_override("separation", 16)
	body.add_child(centre)
	var genders := CreationRules.genders()
	var rig_frame := PanelContainer.new()
	var frame_box := skin_box("rig_frame", FRAME_MARGIN)
	if frame_box != null:
		rig_frame.add_theme_stylebox_override("panel", frame_box)
	_doll = CharacterSheet.Doll.new()
	_doll.custom_minimum_size = RIG_SIZE
	rig_frame.add_child(_doll)
	for i in genders.size():
		if i == 1:
			centre.add_child(rig_frame)
		centre.add_child(_gender_button(str(genders[i])))
	if genders.size() < 2:
		centre.add_child(rig_frame)

	# Bottom: randomize and skip on the left, the name and "enter the world" on the right.
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	column.add_child(bottom)
	var random_button := Button.new()
	random_button.name = "Randomize"
	random_button.icon = UiIcons.load_icon(str(ICONS["randomize"]))
	random_button.expand_icon = true
	random_button.custom_minimum_size = Vector2(56, 56)
	_tr(random_button, "tooltip_text", "creation.randomize")
	_skin_button(random_button)
	random_button.pressed.connect(func() -> void: randomize_choice())
	bottom.add_child(random_button)
	var skip_button := Button.new()
	skip_button.name = "Skip"
	_tr(skip_button, "text", "creation.skip")
	_skin_button(skip_button)
	skip_button.pressed.connect(skip)
	bottom.add_child(skip_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	var name_panel := _panel()
	bottom.add_child(name_panel)
	var name_box := VBoxContainer.new()
	name_panel.add_child(name_box)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	name_box.add_child(name_row)
	_name = LineEdit.new()
	_name.name = "Name"
	_name.custom_minimum_size = Vector2(NAME_WIDTH, 0)
	_name.max_length = CreationRules.MAX_FIELD_LEN
	_tr(_name, "placeholder_text", "creation.name")
	_name.text_submitted.connect(func(_t: String) -> void: submit())
	name_row.add_child(_name)
	var enter := Button.new()
	enter.name = "Enter"
	_tr(enter, "text", "creation.enter")
	_skin_button(enter)
	enter.pressed.connect(submit)
	name_row.add_child(enter)
	_error = Label.new()
	_error.name = "Error"
	_error.add_theme_font_size_override("font_size", ERROR_FONT)
	_error.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.custom_minimum_size = Vector2(NAME_WIDTH, 0)
	name_box.add_child(_error)


func _gender_button(gender: String) -> Button:
	var b := Button.new()
	b.name = "Gender_" + gender
	b.toggle_mode = true
	b.custom_minimum_size = GENDER_BUTTON
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.icon = UiIcons.load_icon(str(ICONS.get(gender, "")))
	b.expand_icon = true
	_tr(b, "tooltip_text", CreationRules.gender_key(gender))
	_skin_button(b)
	b.pressed.connect(func() -> void: set_gender(gender))
	_gender_buttons[gender] = b
	return b


## Re-render every label in the active locale and every picker from `choice`. The hair grid is rebuilt only when
## the gender changed (a button is never freed from inside its own press); everything else is restyled in place.
func refresh() -> void:
	for t in _texts:
		(t[0] as Control).set(str(t[1]), I18n.t(str(t[2])))
	if _hair_grid == null:
		return
	for g in _gender_buttons:
		(_gender_buttons[g] as Button).set_pressed_no_signal(str(g) == str(choice.get("gender", "")))
	if _grid_gender != str(choice.get("gender", "")):
		_rebuild_hair()
	for b in _hair_grid.get_children():
		(b as Button).set_pressed_no_signal(str(b.name) == "Hair_" + str(choice.get("hair", "")))
	if _colors.get_child_count() == 0:
		_build_swatches()
	for sw in _colors.get_children():
		var on := str(sw.name) == "Color_%d" % int(choice.get("hairColor", -1))
		(sw as Button).set_pressed_no_signal(on)
		((sw as Button).get_theme_stylebox("normal") as StyleBoxFlat).set_border_width_all(3 if on else 0)
	_refresh_doll()

var _grid_gender := ""

func _rebuild_hair() -> void:
	_grid_gender = str(choice.get("gender", ""))
	for c in _hair_grid.get_children():
		_hair_grid.remove_child(c)
		c.free()
	for row in hair_rows(_grid_gender):
		var b := Button.new()
		b.name = "Hair_" + str(row["id"])
		b.toggle_mode = true
		b.custom_minimum_size = HAIR_BUTTON
		b.icon = UiIcons.load_icon(str(row["icon_key"]))
		b.expand_icon = true
		_skin_button(b)
		var id := str(row["id"])
		b.pressed.connect(func() -> void: set_hair(id))
		_hair_grid.add_child(b)

func _build_swatches() -> void:
	for idx in CreationRules.color_options():
		var sw := Button.new()
		sw.name = "Color_%d" % int(idx)
		sw.toggle_mode = true
		sw.custom_minimum_size = SWATCH
		var flat := StyleBoxFlat.new()
		flat.bg_color = palette.call(int(idx)) if palette.is_valid() else Color.GRAY
		flat.border_color = Color.WHITE
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			sw.add_theme_stylebox_override(state, flat)
		var color := int(idx)
		sw.pressed.connect(func() -> void: set_hair_color(color))
		_colors.add_child(sw)


func _refresh_doll() -> void:
	if _doll == null or not visual_builder.is_valid():
		return
	var key := JSON.stringify(choice)
	if key == _doll_key and _doll.has_rig():
		return
	_doll_key = key
	var built: Variant = visual_builder.call(choice)
	_doll.rebuild(built as Node3D if built is Node3D else null)


## True when the doll holds a rig.
func has_rig() -> bool:
	return _doll != null and _doll.has_rig()


## Pick a gender: its first hair style replaces a hair of the other gender; the colour is kept.
func set_gender(gender: String) -> void:
	if not CreationRules.genders().has(gender):
		return
	choice["gender"] = gender
	var hairs := CreationRules.hair_options(gender)
	if not hairs.has(str(choice.get("hair", ""))) and not hairs.is_empty():
		choice["hair"] = str(hairs[0])
	refresh()


func set_hair(hair: String) -> void:
	if CreationRules.hair_options(str(choice.get("gender", ""))).has(hair):
		choice["hair"] = hair
		refresh()


func set_hair_color(color: int) -> void:
	if CreationRules.color_options().has(color):
		choice["hairColor"] = color
		refresh()


## Randomize gender, hair and colour (the name is the player's own).
func randomize_choice(rng_seed: int = -1) -> Dictionary:
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	choice = CreationRules.random_choice(_rng)
	refresh()
	return choice


func set_name_text(text: String) -> void:
	if _name != null:
		_name.text = text


## The intent this screen would send for "enter the world".
func creation() -> Dictionary:
	var c := choice.duplicate()
	c["name"] = _name.text if _name != null else ""
	return c


## Send the creation. The name rule is checked here first only to answer at once; the host decides.
func submit() -> void:
	var c := creation()
	var reason := CreationRules.creation_refusal(c)
	if reason != "":
		show_refusal(reason)
		return
	show_refusal("")
	GameBus.character_creation_intent.emit("create", c, "")


func skip() -> void:
	show_refusal("")
	GameBus.character_creation_intent.emit("skip", {}, "")


## Show a refusal reason in the active locale ("" clears it).
func show_refusal(reason: String) -> void:
	if _error != null:
		_error.text = "" if reason == "" else I18n.t(CreationRules.refusal_key(reason))


func error_text() -> String:
	return _error.text if _error != null else ""
