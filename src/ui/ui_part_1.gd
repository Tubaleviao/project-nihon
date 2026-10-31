extends RefCounted
## Methods moved verbatim out of `ui_slice.gd` (Phase 154). `sl` is the owning slice; each moved method keeps a forwarder there.

const UiIcons := preload("res://src/ui/ui_icons.gd")

var sl: Node

func _init(slice: Node) -> void:
	sl = slice

func _build_hud() -> void:
	sl.hotbar = sl.HotbarScript.new()
	sl.hotbar.anchor_left = 0.5
	sl.hotbar.anchor_right = 0.5
	sl.hotbar.anchor_top = 1.0
	sl.hotbar.anchor_bottom = 1.0
	sl.hotbar.offset_left = -300.0
	sl.hotbar.offset_right = 300.0
	sl.hotbar.offset_top = -13.0
	sl.hotbar.offset_bottom = -12.0
	sl.hotbar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sl.hotbar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sl.hotbar.save_path = sl.layout_path.get_basename() + "_hotbar.json"
	sl.hotbar.icon_loader = func(item_id: String) -> Texture2D: return sl._load_item_icon(sl.item_icon_key(item_id))
	sl.hotbar.held_provider = func() -> Dictionary:
		return sl.inventory_slice.get_contents() if sl.inventory_slice != null else {}
	sl.hotbar.tier_provider = func() -> Dictionary:
		return sl.crafting_slice.get_skills() if sl.crafting_slice != null else {}
	sl.hotbar.build()
	sl.hotbar.slot_selected.connect(sl._on_hotbar_selected)
	sl.hotbar.drag_began.connect(sl._on_drag_began)
	sl.hotbar.notice.connect(sl._notify)
	sl._ui.add_child(sl.hotbar)

	# Under the health bar (top-left, see PlayerSlice._build_hud).
	sl.window_dock = sl.WindowDockScript.new()
	sl.window_dock.offset_left = 12.0
	sl.window_dock.offset_top = 48.0
	sl.window_dock.save_path = sl.layout_path.get_basename() + "_dock.json"
	sl.window_dock.build()
	sl.window_dock.window_toggled.connect(sl.toggle_window)
	sl._ui.add_child(sl.window_dock)

	sl._hud_notice = Label.new()
	sl._hud_notice.anchor_left = 0.5
	sl._hud_notice.anchor_right = 0.5
	sl._hud_notice.anchor_top = 1.0
	sl._hud_notice.anchor_bottom = 1.0
	sl._hud_notice.offset_left = -300.0
	sl._hud_notice.offset_right = 300.0
	sl._hud_notice.offset_top = -180.0
	sl._hud_notice.offset_bottom = -156.0
	sl._hud_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sl._hud_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sl._hud_notice.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	sl._hud_notice.add_theme_constant_override("outline_size", 5)
	sl._ui.add_child(sl._hud_notice)

	sl._toast_label = Label.new()
	sl._toast_label.anchor_left = 0.5
	sl._toast_label.anchor_right = 0.5
	sl._toast_label.offset_left = -300.0
	sl._toast_label.offset_right = 300.0
	sl._toast_label.offset_top = 60.0
	sl._toast_label.offset_bottom = 120.0
	sl._toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sl._toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sl._toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sl._toast_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	sl._toast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	sl._toast_label.add_theme_constant_override("outline_size", 5)
	sl._toast_label.text = sl._toast_shown
	sl._ui.add_child(sl._toast_label)

## One row per held repairable item: { id, can_repair, reason, station, materials }.
## Only durable items that have a fabric repair spec AND are currently held AND
## are not pristine are listed — a pristine item needs no repair, and stackable
## materials have no repair spec.
func repair_rows() -> Array:
	var rows: Array = []
	if sl.crafting_slice == null or sl.inventory_slice == null:
		return rows
	var ids: Array = sl.inventory_slice.get_contents().keys()
	ids.sort()
	for item_id in ids:
		var iid = str(item_id)
		var spec: Dictionary = sl.crafting_slice.get_repair_spec(iid)
		if spec.is_empty():
			continue
		var check: Dictionary = sl.crafting_slice.can_repair(iid, spec)
		# Skip items whose only blocker is being pristine — they need no repair.
		# Filter on can_repair's reason (which already reflects the condition)
		# rather than re-deriving "pristine" here.
		if str(check.get("reason", "")) == "already_pristine":
			continue
		rows.append({
			"id": iid,
			"can_repair": bool(check.get("success", false)),
			"reason": str(check.get("reason", "")),
			"station": str(spec.get("station", "")),
			"icon_key": sl.item_icon_key(iid),
			"materials": sl._fmt_entries(spec.get("materials", [])),
		})
	return rows

func refresh_character() -> void:
	if sl._character_grid == null:
		return
	sl._refresh_skills()
	sl._character_stats.text = sl.character_stats_text()
	_refresh_sheet()
	# An appearance change that left the worn set alone (a palette tweak, a LOD swap)
	# produces the same rows; rebuilding the whole grid for it is wasted work.
	var rows = sl.character_rows()
	var signature: int = rows.hash()
	if signature == sl._character_rows_signature and sl._character_grid.get_child_count() > 0:
		return
	sl._character_rows_signature = signature
	for holder in [sl._character_grid, sl._sheet_left, sl._sheet_right]:
		for c in holder.get_children():
			holder.remove_child(c)
			sl._retire(c)
	for row in rows:
		var slot = Button.new()
		slot.custom_minimum_size = sl.SLOT_SIZE
		slot.tooltip_text = str(row["tooltip"])
		slot.clip_text = true
		var tex: Texture2D = sl._load_item_icon(str(row["icon_key"])) if str(row["icon_key"]) != "" else null
		if tex != null:
			slot.icon = tex
			slot.expand_icon = true
			slot.text = str(row["slot"])
		else:
			slot.text = "%s\n%s" % [row["slot"], sl.item_glyph(str(row["item"])) if str(row["item"]) != "" else "—"]
		slot.gui_input.connect(sl._on_slot_gui_input.bind(str(row["item"]), row["actions"]))
		var slot_name := str(row["slot"])
		slot.set_drag_forwarding(sl._slot_drag.bind(str(row["item"]), slot),
				func(_at: Vector2, data: Variant) -> bool: return sl.slot_accepts_drop(slot_name, data),
				func(_at: Vector2, data: Variant) -> void: sl.drop_on_slot(slot_name, data))
		match sl.CharacterSheet.column_of(str(row["slot"])):
			"left":
				sl._sheet_left.add_child(slot)
			"right":
				sl._sheet_right.add_child(slot)
			_:
				sl._character_grid.add_child(slot)

## Phase 179 — the attribute, derived-stat and skills panels, the name above the doll and the doll itself.
## Rebuilt only when the projection changed.
func _refresh_sheet() -> void:
	var rows: Array = sl.character_sheet_rows()
	var panel_rows := rows.filter(func(r): return str(r["section"]) != "slot")
	var signature: int = panel_rows.hash()
	sl._sheet_name.text = sl.own_display_name()
	# Phase 181 — the creation screen stays reachable from the sheet until a character exists.
	if sl._sheet_create_button != null:
		sl._sheet_create_button.visible = not sl.CreationRules.is_created(sl._creation_state)
	_refresh_doll()
	if signature == sl._sheet_signature and sl._sheet_attributes.get_child_count() > 0:
		return
	sl._sheet_signature = signature
	for holder in [sl._sheet_attributes, sl._sheet_stats, sl._sheet_skills]:
		for c in holder.get_children():
			holder.remove_child(c)
			sl._retire(c)
	for row in panel_rows:
		match str(row["section"]):
			"attribute":
				var line := HBoxContainer.new()
				line.tooltip_text = str(row["tooltip"])
				var icon := TextureRect.new()
				icon.texture = UiIcons.load_icon(str(row["icon_key"]))
				icon.custom_minimum_size = Vector2(24, 24)
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				line.add_child(icon)
				var label := Label.new()
				label.text = "%s %d" % [row["name"], int(row["value"])]
				label.custom_minimum_size = Vector2(130, 0)
				line.add_child(label)
				var bar := ProgressBar.new()
				bar.min_value = 0.0
				bar.max_value = 1.0
				bar.value = float(row["progress"])
				bar.show_percentage = false
				bar.custom_minimum_size = Vector2(120, 12)
				bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				line.add_child(bar)
				sl._sheet_attributes.add_child(line)
			"specialty":
				var sline := HBoxContainer.new()
				var sicon := TextureRect.new()
				sicon.texture = UiIcons.load_icon(str(row["icon_key"]))
				sicon.custom_minimum_size = Vector2(24, 24)
				sicon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				sicon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				sline.add_child(sicon)
				var slabel := Label.new()
				slabel.text = str(row["name"])
				sline.add_child(slabel)
				sl._sheet_attributes.add_child(sline)
			"stat":
				var name_label := Label.new()
				name_label.text = str(row["label"])
				name_label.add_theme_font_size_override("font_size", 12)
				sl._sheet_stats.add_child(name_label)
				var value_label := Label.new()
				value_label.text = str(row["text"])
				value_label.add_theme_font_size_override("font_size", 12)
				sl._sheet_stats.add_child(value_label)
			"skill":
				var b := Button.new()
				b.custom_minimum_size = Vector2(sl.SLOT_SIZE.x, 64.0)
				b.clip_text = true
				UiIcons.style_skill_button(b, str(row["id"]), str(row["tier"]))
				b.add_theme_font_size_override("font_size", 12)
				b.tooltip_text = str(row["tooltip"])
				b.pressed.connect(sl.open_window.bind(sl.WINDOW_SKILLS))
				sl._sheet_skills.add_child(b)

## Rebuild the doll's rig from the local avatar's appearance and worn set when either changed.
func _refresh_doll() -> void:
	var ch: Node = sl.character_slice
	if ch == null or sl._sheet_doll == null:
		return
	var iid := str(ch.get_player_character())
	if iid == "":
		return
	var appearance: Dictionary = ch.get_appearance(iid)
	var worn: Dictionary = ch.get_equipment_set(iid)
	var equipment := {}
	for slot in worn:
		equipment[slot] = { "item": str(worn[slot]), "state": "equipped" }
	appearance["equipment"] = equipment
	var signature := appearance.hash()
	if signature == sl._doll_signature and sl._sheet_doll.has_rig():
		return
	sl._doll_signature = signature
	var built: Dictionary = ch._make_visual("sheet_doll", ch.deserialize_appearance(appearance))
	sl._sheet_doll.rebuild(built.get("root", null))

## Phase 179 — the sheet's whole projection, one row per thing it shows, each with a `section`: "slot" (every
## equipment slot), "attribute" (all six), "stat" (every derived stat) and "skill" (the top skills by tier).
## Values are the body's synced attribute table run through the fabric formula.
func character_sheet_rows() -> Array:
	var rows: Array = []
	for r in sl.character_rows():
		var row: Dictionary = (r as Dictionary).duplicate()
		row["section"] = "slot"
		rows.append(row)
	var attrs := _local_attributes()
	rows.append_array(sl.CharacterSheet.attribute_rows(attrs, _local_growth()))
	rows.append_array(sl.CharacterSheet.stat_rows(attrs))
	var view: Dictionary = sl.settlement_slice.view() if sl.settlement_slice != null else {}
	rows.append_array(sl.CharacterSheet.specialty_rows(str((view.get("mine", {}) as Dictionary).get("specialty", ""))))
	rows.append_array(sl.CharacterSheet.skill_rows(sl.skills_rows(sl.crafting_slice.get_skills() if sl.crafting_slice != null else {})))
	return rows

func _local_attributes() -> Dictionary:
	return sl.AttributeRules.sanitize(sl.player_slice.get("attributes")) if sl.player_slice != null and sl.player_slice.get("attributes") != null else sl.AttributeRules.defaults()

func _local_growth() -> Dictionary:
	return sl.AttributeRules.sanitize_growth(sl.player_slice.get("attribute_growth")) if sl.player_slice != null and sl.player_slice.get("attribute_growth") != null else sl.AttributeRules.empty_growth()

## Phase 179 — dropping a bag item on a slot equips it through the same path as the context menu.
func slot_accepts_drop(slot: String, data: Variant) -> bool:
	return data is Dictionary and str((data as Dictionary).get("kind", "")) == "item" \
			and sl.EquipmentRules.slot_of(str((data as Dictionary).get("id", "")), GameData.ITEMS) == slot

func drop_on_slot(slot: String, data: Variant) -> bool:
	return slot_accepts_drop(slot, data) and sl.dispatch_item_action(str((data as Dictionary)["id"]), "equip")

func slot_drag(_at: Vector2, item_id: String, source: Control) -> Variant:
	if item_id == "":
		return null
	var label := Label.new()
	label.text = item_id
	source.set_drag_preview(label)
	sl._drag_payload = {"kind": "equipped", "id": item_id}
	return sl._drag_payload

func build_character_content() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	sl._character_stats = Label.new()
	sl._character_stats.add_theme_font_size_override("font_size", 15)
	vbox.add_child(sl._character_stats)
	# Phase 53 — the friend code: the handle another player enters to spawn beside this one.
	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 6)
	sl._friend_code_label = Label.new()
	sl._friend_code_label.text = sl.friend_code_text(sl.own_handle)
	code_row.add_child(sl._friend_code_label)
	var copy_btn := Button.new()
	sl._set_tr(copy_btn, "text", "ui.copy")
	copy_btn.pressed.connect(sl._on_copy_friend_code_pressed)
	code_row.add_child(copy_btn)
	vbox.add_child(code_row)
	sl._spawn_notice_label = Label.new()
	sl._spawn_notice_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(sl._spawn_notice_label)
	sl._sheet_name = Label.new()
	sl._sheet_name.add_theme_font_size_override("font_size", 16)
	sl._sheet_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sl._sheet_name)
	sl._sheet_create_button = Button.new()
	sl._set_tr(sl._sheet_create_button, "text", "creation.open")
	sl._sheet_create_button.pressed.connect(func() -> void: sl.show_creation())
	vbox.add_child(sl._sheet_create_button)
	var body := HBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	sl._sheet_left = VBoxContainer.new()
	sl._sheet_right = VBoxContainer.new()
	sl._sheet_doll = sl.CharacterSheet.Doll.new()
	body.add_child(sl._sheet_left)
	body.add_child(sl._sheet_doll)
	body.add_child(sl._sheet_right)
	vbox.add_child(body)
	sl._character_grid = GridContainer.new()
	sl._character_grid.columns = sl.INVENTORY_COLUMNS
	vbox.add_child(sl._character_grid)
	sl._sheet_attributes = VBoxContainer.new()
	vbox.add_child(sl._sheet_attributes)
	sl._sheet_stats = GridContainer.new()
	sl._sheet_stats.columns = 2
	sl._sheet_stats.add_theme_constant_override("h_separation", 14)
	vbox.add_child(sl._sheet_stats)
	sl._sheet_skills = HBoxContainer.new()
	vbox.add_child(sl._sheet_skills)
	return vbox

func _build_ui() -> void:
	sl._ui = CanvasLayer.new()
	sl._ui.name = "Windows"
	sl._ui.layer = 30
	sl.add_child(sl._ui)
	# Built first so every window draws above the HUD.
	sl._build_hud()

	sl._panels[sl.WINDOW_INVENTORY] = sl._build_window(sl.WINDOW_INVENTORY, "win.inventory", sl._build_inventory_content(), Vector2(24, 24))
	sl._panels[sl.WINDOW_TECHNOLOGY] = sl._build_window(sl.WINDOW_TECHNOLOGY, "win.technology", sl._build_technology_content(), Vector2(470, 24))
	sl._panels[sl.WINDOW_CRAFTING] = sl._build_window(sl.WINDOW_CRAFTING, "win.crafting", sl._build_crafting_content(), Vector2(24, 360))
	sl._panels[sl.WINDOW_TRADE] = sl._build_window(sl.WINDOW_TRADE, "win.trade", sl._build_trade_content(), Vector2(470, 360))
	sl._panels[sl.WINDOW_MARKET] = sl._build_window(sl.WINDOW_MARKET, "win.market", sl._build_market_content(), Vector2(24, 700))
	sl._panels[sl.WINDOW_PROPOSALS] = sl._build_window(sl.WINDOW_PROPOSALS, "win.proposals", sl._build_proposals_content(), Vector2(470, 700))
	sl._panels[sl.WINDOW_CONTROLS] = sl._build_window(sl.WINDOW_CONTROLS, "win.controls", sl._build_controls_content(), Vector2(916, 24))

	sl._panels[sl.WINDOW_CHARACTER] = sl._build_window(sl.WINDOW_CHARACTER, "win.character", build_character_content(), Vector2(916, 360))
	sl._panels[sl.WINDOW_SKILLS] = sl._build_window(sl.WINDOW_SKILLS, "win.skills", sl._build_skills_content(), Vector2(916, 700))
	sl._panels[sl.WINDOW_SETTLEMENT] = sl._build_window(sl.WINDOW_SETTLEMENT, "win.settlement", sl._build_settlement_content(), Vector2(916, 80))
	sl._panels[sl.WINDOW_GESTURES] = sl._build_window(sl.WINDOW_GESTURES, "win.gestures", sl._build_gesture_content(), Vector2(600, 200),
		func() -> Array: return [sl.GesturePanelScript.key_label()])
	sl._panels[sl.WINDOW_MAP] = sl._build_window(sl.WINDOW_MAP, "win.map", sl._build_map_content(), Vector2(200, 80))
	sl._panels[sl.WINDOW_ADMIN] = sl._build_window(sl.WINDOW_ADMIN, "win.admin", sl._m2._build_admin_content(), Vector2(600, 80))

	sl._slot_menu = PopupMenu.new()
	sl._slot_menu.id_pressed.connect(sl._on_slot_menu_pressed)
	sl._ui.add_child(sl._slot_menu)
	sl._load_layout()
	sl._apply_layout()
	# The panels have no real size until their first layout pass: re-fit once it has run.
	sl._apply_layout.call_deferred()
	# A viewport resize (window drag, fullscreen toggle) re-fits too.
	if sl.is_inside_tree() and not sl.get_viewport().size_changed.is_connected(sl._apply_layout):
		sl.get_viewport().size_changed.connect(sl._apply_layout)

## `title` is a catalog key.
func _build_window(key: String, title: String, content: Control, position: Vector2, title_args: Callable = Callable()) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.position = position
	panel.custom_minimum_size = Vector2(420, 300)
	panel.visible = false
	sl._ui.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var bar = HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.mouse_default_cursor_shape = Control.CURSOR_MOVE
	bar.gui_input.connect(sl._on_title_gui_input.bind(key))
	vbox.add_child(bar)

	var title_label = Label.new()
	sl._set_tr(title_label, "text", title, title_args)
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title_label)

	var close = Button.new()
	close.text = "✕"
	close.pressed.connect(sl._on_close_pressed.bind(key))
	bar.add_child(close)

	# The body fills the window: a ScrollContainer inside it has no minimum height, so a body that
	# only takes its minimum size leaves the crafting and technology lists 0 px tall.
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)
	return panel

func _build_market_content() -> Control:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	var list_lbl = Label.new()
	sl._set_tr(list_lbl, "text", "market.list_prompt")
	vbox.add_child(list_lbl)
	var list_row = HBoxContainer.new()
	list_row.add_theme_constant_override("separation", 6)
	sl._market_item_select = OptionButton.new()
	sl._market_item_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_row.add_child(sl._market_item_select)
	sl._market_qty = LineEdit.new()
	sl._market_qty.text = "1"
	sl._market_qty.custom_minimum_size = Vector2(40, 0)
	list_row.add_child(sl._market_qty)
	sl._market_price = LineEdit.new()
	sl._market_price.text = "1.0"
	sl._market_price.custom_minimum_size = Vector2(50, 0)
	list_row.add_child(sl._market_price)
	var list_btn = Button.new()
	sl._set_tr(list_btn, "text", "market.list")
	list_btn.pressed.connect(sl._on_market_list_pressed)
	list_row.add_child(list_btn)
	vbox.add_child(list_row)
	sl._market_feedback = Label.new()
	sl._market_feedback.add_theme_font_size_override("font_size", 13)
	vbox.add_child(sl._market_feedback)
	var browse_lbl = Label.new()
	sl._set_tr(browse_lbl, "text", "market.browse")
	vbox.add_child(browse_lbl)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sl._market_box = VBoxContainer.new()
	sl._market_box.add_theme_constant_override("separation", 4)
	sl._market_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(sl._market_box)
	vbox.add_child(scroll)
	return vbox
