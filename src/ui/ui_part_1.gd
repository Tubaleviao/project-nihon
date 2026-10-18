extends RefCounted
## Methods moved verbatim out of `ui_slice.gd` (Phase 154). `sl` is the owning slice; each moved method keeps a forwarder there.

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
	# An appearance change that left the worn set alone (a palette tweak, a LOD swap)
	# produces the same rows; rebuilding the whole grid for it is wasted work.
	var rows = sl.character_rows()
	var signature: int = rows.hash()
	if signature == sl._character_rows_signature and sl._character_grid.get_child_count() > 0:
		return
	sl._character_rows_signature = signature
	for c in sl._character_grid.get_children():
		sl._character_grid.remove_child(c)
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
		sl._character_grid.add_child(slot)

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

	sl._panels[sl.WINDOW_CHARACTER] = sl._build_window(sl.WINDOW_CHARACTER, "win.character", sl._build_character_content(), Vector2(916, 360))
	sl._panels[sl.WINDOW_SKILLS] = sl._build_window(sl.WINDOW_SKILLS, "win.skills", sl._build_skills_content(), Vector2(916, 700))
	sl._panels[sl.WINDOW_SETTLEMENT] = sl._build_window(sl.WINDOW_SETTLEMENT, "win.settlement", sl._build_settlement_content(), Vector2(916, 80))
	sl._panels[sl.WINDOW_MAP] = sl._build_window(sl.WINDOW_MAP, "win.map", sl._build_map_content(), Vector2(200, 80))

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
func _build_window(key: String, title: String, content: Control, position: Vector2) -> PanelContainer:
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
	sl._set_tr(title_label, "text", title)
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
