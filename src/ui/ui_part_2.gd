extends RefCounted
## Methods moved verbatim out of `ui_slice.gd` (Phase 154). `sl` is the owning slice; each moved method keeps a forwarder there.

var sl: Node
var trade_box: VBoxContainer = null

const AdminPanelScript := preload("res://src/ui/admin_panel.gd")

func _init(slice: Node) -> void:
	sl = slice

## One row per carried item for the slot grid: { id, quantity, durability,
## icon_key, tooltip, actions }, sorted by key. `inventory_lines()` stays the
## text projection; this is the structured one the grid is built from.
func inventory_rows() -> Array:
	var rows: Array = []
	if sl.inventory_slice == null:
		return rows
	var contents: Dictionary = sl.inventory_slice.get_contents()
	var keys: Array = contents.keys()
	keys.sort()
	var repairable = {}
	for r in sl.repair_rows():
		repairable[str(r["id"])] = true
	for item_id in keys:
		var iid = str(item_id)
		var qty = int(contents[item_id])
		var dur = sl.durability_bar(iid).strip_edges()
		var tip = sl.I18n.t("ui.tip_quantity", [iid, qty])
		if dur != "":
			tip += sl.I18n.t("ui.tip_durability", [dur.trim_prefix("[").trim_suffix("]")])
		var desc = sl.item_description(iid)
		if desc != "":
			tip += "\n" + desc
		rows.append({
			"id": iid,
			"quantity": qty,
			"durability": dur,
			"icon_key": sl.item_icon_key(iid),
			"tooltip": tip,
			"actions": sl.item_actions(iid, repairable),
		})
	return rows

## One row per technology: { id, status, can_research, requires, duration, cost }.
func technology_rows() -> Array:
	var rows: Array = []
	if sl.technology_slice == null:
		return rows
	var ids: Array = GameData.TECHNOLOGIES.keys()
	ids.sort()
	for tech_id in ids:
		var tid = str(tech_id)
		var status: String = sl.technology_slice.get_status(tid)
		var data: Dictionary = sl.technology_slice.get_tech_data(tid)
		var points_cost: int = sl.technology_slice.research_cost(tid)
		var short: bool = status == "locked" and sl.technology_slice.get_points() < points_cost
		rows.append({
			"id": tid,
			"status": status,
			"can_research": sl._can_research(tid, status, data) and not short,
			"points_cost": points_cost,
			"reason": "needs_points:%d" % points_cost if short else "",
			"icon_key": unlock_icon_key(data.get("unlocks", [])),
			"requires": data.get("requires", []),
			"duration": int(data.get("researchDuration", 0)),
			"cost": sl._fmt_entries(data.get("researchMaterials", [])),
		})
	return rows

func refresh_crafting() -> void:
	if sl._crafting_box == null:
		return
	for child in sl._crafting_box.get_children():
		child.queue_free()
	for row in sl.crafting_rows():
		var r: Dictionary = row
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		var btn = Button.new()
		btn.text = sl.I18n.t("ui.craft")
		btn.disabled = not bool(r["can_craft"])
		btn.pressed.connect(sl._on_craft_pressed.bind(str(r["id"])))
		hbox.add_child(btn)
		sl._add_row_icon(hbox, str(r["icon_key"]))
		var line = "%s: %s → %s" % [r["id"], r["inputs"], r["outputs"]]
		if str(r.get("station", "")) != "":
			line += "  @ %s" % r["station"]
		var lbl = Label.new()
		lbl.text = line + ("" if bool(r["can_craft"]) else "  (%s)" % sl.I18n.reason_text(str(r["reason"])))
		lbl.modulate = Color(1, 1, 1) if bool(r["can_craft"]) else Color(0.6, 0.6, 0.6)
		hbox.add_child(lbl)
		sl._crafting_box.add_child(hbox)

	# Repair section: one row per held, repairable, non-pristine item.
	var repair_rows_list: Array = sl.repair_rows()
	if not repair_rows_list.is_empty():
		var sep = Label.new()
		sep.text = sl.I18n.t("ui.repairs_header")
		sep.add_theme_font_size_override("font_size", 14)
		sep.modulate = Color(0.75, 0.75, 0.75)
		sl._crafting_box.add_child(sep)
		for row in repair_rows_list:
			var r: Dictionary = row
			var hbox = HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 8)
			var btn = Button.new()
			btn.text = sl.I18n.t("ui.repair")
			btn.disabled = not bool(r["can_repair"])
			btn.pressed.connect(sl._on_repair_pressed.bind(str(r["id"])))
			hbox.add_child(btn)
			sl._add_row_icon(hbox, str(r["icon_key"]))
			var line = str(r["id"])
			if str(r.get("station", "")) != "":
				line += "  @ %s" % r["station"]
			line += "  " + sl.I18n.t("ui.needs", [r["materials"]])
			var lbl = Label.new()
			lbl.text = line + ("" if bool(r["can_repair"]) else "  (%s)" % sl.I18n.reason_text(str(r["reason"])))
			lbl.modulate = Color(1, 1, 1) if bool(r["can_repair"]) else Color(0.6, 0.6, 0.6)
			hbox.add_child(lbl)
			sl._crafting_box.add_child(hbox)

func _build_map_content() -> Control:
	var box = VBoxContainer.new()
	sl.map_window = sl.MapWindowScript.new()
	sl.map_window.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(sl.map_window)
	sl.map_window.notice.connect(sl.push_toast)
	GameBus.waystone_travel_resolved.connect(sl._on_waystone_resolved)
	var row = HBoxContainer.new()
	box.add_child(row)
	var fold = CheckButton.new()
	sl._set_tr(fold, "text", "map.planet")
	sl._set_tr(fold, "tooltip_text", "map.planet_tip")
	fold.focus_mode = Control.FOCUS_NONE
	fold.toggled.connect(func(on: bool) -> void: sl.map_window.set_planet(on))
	row.add_child(fold)
	var here = Button.new()
	sl._set_tr(here, "text", "map.centre")
	here.focus_mode = Control.FOCUS_NONE
	here.pressed.connect(func() -> void: sl.map_window.center_on_player())
	row.add_child(here)
	var hint = Label.new()
	sl._set_tr(hint, "text", "map.hint")
	sl._set_tr(hint, "tooltip_text", "map.hint_tip")
	hint.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(hint)
	return box

## (Re)build the control rows in the active language.
func _refill_controls() -> void:
	if sl._controls_box == null:
		return
	if sl._language_button != null:
		sl._language_button.text = sl.language_button_text()
	for child in sl._controls_box.get_children():
		if child != sl._language_button:
			child.free()
	var box = sl._controls_box
	for row in sl.controls_rows():
		var line = HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		if int(row["mouse"]) != 0:
			var holder = CenterContainer.new()
			holder.custom_minimum_size = Vector2(56, 30)
			var icon: Control = sl.MouseIconScript.new()
			icon.button = int(row["mouse"])
			icon.custom_minimum_size = Vector2(20, 30)
			holder.add_child(icon)
			line.add_child(holder)
		else:
			var key_label = Label.new()
			key_label.text = str(row["keys"])
			key_label.add_theme_font_size_override("font_size", 15)
			key_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			key_label.custom_minimum_size = Vector2(90, 0)
			line.add_child(key_label)
		var desc = Label.new()
		desc.text = str(row["desc"])
		desc.add_theme_font_size_override("font_size", 15)
		line.add_child(desc)
		box.add_child(line)

func _build_proposals_content() -> Control:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	sl._proposal_title = LineEdit.new()
	sl._set_tr(sl._proposal_title, "placeholder_text", "proposal.title_ph")
	sl._proposal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(sl._proposal_title)
	var submit_btn = Button.new()
	sl._set_tr(submit_btn, "text", "proposal.submit")
	submit_btn.pressed.connect(sl._on_proposal_submit_pressed)
	title_row.add_child(submit_btn)
	vbox.add_child(title_row)
	sl._proposal_body = LineEdit.new()
	sl._set_tr(sl._proposal_body, "placeholder_text", "proposal.body_ph")
	vbox.add_child(sl._proposal_body)
	sl._proposal_feedback = Label.new()
	sl._proposal_feedback.add_theme_font_size_override("font_size", 13)
	vbox.add_child(sl._proposal_feedback)
	var list_lbl = Label.new()
	sl._set_tr(list_lbl, "text", "proposal.list")
	vbox.add_child(list_lbl)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sl._proposal_box = VBoxContainer.new()
	sl._proposal_box.add_theme_constant_override("separation", 4)
	sl._proposal_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(sl._proposal_box)
	vbox.add_child(scroll)
	return vbox

## Phase 140 — the settlement window: found, invite, roles and the shared stockpile.
func _build_settlement_content() -> Control:
	var panel = sl.SettlementPanelScript.new()
	panel.settlement_slice = sl.settlement_slice
	sl.settlement_panel = panel
	return panel

## Phase 182 — the Admin window: weather, time, speed, flying and healing, through the chat commands.
func _build_admin_content() -> Control:
	return AdminPanelScript.new()

## Phase 182 — the host said whether this player is an admin: show or hide the dock box, and close the
## window when the right was taken away.
func set_admin(admin: bool) -> void:
	sl.is_admin = admin
	if sl.window_dock != null:
		sl.window_dock.set_entry_visible(sl.WINDOW_ADMIN, admin)
	if not admin:
		sl.close_window(sl.WINDOW_ADMIN)

func refresh_trade() -> void:
	if sl._trade_status == null:
		return
	sl._trade_status.text = sl._trade_status_text()
	if trade_box == null:
		return
	for child in trade_box.get_children():
		child.queue_free()
	for row in trade_rows():
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		sl._add_row_icon(hbox, str(row["icon_key"]))
		var lbl := Label.new()
		lbl.text = sl.I18n.t("trade.entry", [row["party"], sl.I18n.t("trade.side_give" if row["side"] == "give" else "trade.side_want"), row["item_id"], row["quantity"]])
		hbox.add_child(lbl)
		trade_box.add_child(hbox)

## One row per item in the active trade's offers: { party, side ("give" | "want"), item_id,
## quantity, icon_key }. Empty with no open trade.
func trade_rows() -> Array:
	var rows: Array = []
	if sl.trade_slice == null or sl._active_trade_id == "":
		return rows
	var trade: Dictionary = sl.trade_slice.get_trade(sl._active_trade_id)
	if str(trade.get("state", "pending")) in ["completed", "rejected"]:
		return rows
	var offers: Dictionary = trade.get("offers", {})
	for party in offers:
		for side in ["give", "want"]:
			var stacks: Dictionary = offers[party].get(side, {})
			for item_id in stacks:
				rows.append({
					"party": str(party), "side": side, "item_id": str(item_id),
					"quantity": int(stacks[item_id]), "icon_key": sl.item_icon_key(str(item_id)),
				})
	return rows

## Icon key of what a technology unlocks: the first output of its first recipe that has one.
func unlock_icon_key(unlocks: Array) -> String:
	if sl.crafting_slice == null:
		return ""
	for rid in unlocks:
		var key: String = sl._first_output_icon_key(sl.crafting_slice.get_recipe(str(rid)).get("outputs", []))
		if key != "":
			return key
	return ""

func refresh_technology() -> void:
	if sl._technology_box == null:
		return
	for child in sl._technology_box.get_children():
		child.queue_free()
	var balance := Label.new()
	balance.text = sl.I18n.t("ui.research_points", [sl.research_points()])
	sl._technology_box.add_child(balance)
	for row in sl.technology_rows():
		var r: Dictionary = row
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		var btn := Button.new()
		btn.text = sl.I18n.t("ui.research")
		btn.disabled = not bool(r["can_research"])
		btn.pressed.connect(sl._on_research_pressed.bind(str(r["id"])))
		hbox.add_child(btn)
		sl._add_row_icon(hbox, str(r["icon_key"]))
		var req_arr: Array = r.get("requires", [])
		var reqs: String = ", ".join(req_arr) if req_arr.size() > 0 else "—"
		var line: String = sl.I18n.t("ui.tech_line", [r["id"], r["status"], reqs, r["cost"], r["points_cost"], r["duration"]])
		var lbl := Label.new()
		lbl.text = line + ("  (%s)" % sl.I18n.reason_text(str(r["reason"])) if str(r["reason"]) != "" else "")
		hbox.add_child(lbl)
		sl._technology_box.add_child(hbox)

func build_trade_content() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	var lbl := Label.new()
	sl._set_tr(lbl, "text", "trade.blurb")
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl)
	var start_btn := Button.new()
	sl._set_tr(start_btn, "text", "trade.start")
	start_btn.pressed.connect(sl._on_trade_start_pressed)
	vbox.add_child(start_btn)
	var accept_btn := Button.new()
	sl._set_tr(accept_btn, "text", "trade.accept")
	accept_btn.pressed.connect(sl._on_trade_accept_pressed)
	vbox.add_child(accept_btn)
	sl._trade_status = Label.new()
	sl._trade_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sl._trade_status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(sl._trade_status)
	trade_box = VBoxContainer.new()
	vbox.add_child(trade_box)
	return vbox

# ---------------------------------------------------------------------------
# Phase 181 — the character creation screen
# ---------------------------------------------------------------------------

## Show the creation screen, built on first use on its own layer above the windows; the body takes no keys.
func show_creation(state: Dictionary) -> void:
	if not state.is_empty():
		sl.set_creation_state(state)
	if sl.creation_screen == null:
		sl._creation_layer = CanvasLayer.new()
		sl._creation_layer.name = "Creation"
		sl._creation_layer.layer = 40
		sl.add_child(sl._creation_layer)
		sl.creation_screen = sl.CreationScreen.new()
		sl.creation_screen.visual_builder = _creation_visual
		if sl.character_slice != null:
			sl.creation_screen.palette = sl.character_slice.palette_color
		sl._creation_layer.add_child(sl.creation_screen)
	sl.creation_screen.visible = true
	sl.creation_screen.refresh()
	if sl.player_slice != null:
		sl.player_slice.creation_hold = true

func hide_creation() -> void:
	if sl.creation_screen != null:
		sl.creation_screen.visible = false
	if sl.player_slice != null:
		sl.player_slice.creation_hold = false

## The doll's rig for a choice: the gender's preset with the chosen hair, built like the character sheet's.
func _creation_visual(choice: Dictionary) -> Node3D:
	if sl.character_slice == null:
		return null
	var ch: Node = sl.character_slice
	var built: Dictionary = ch._make_visual("creation_doll", ch.deserialize_appearance(ch.creation_recipe(choice)))
	return built.get("root", null)

## The host answered this machine's creation or skip: a refusal shows on the screen in this locale; a success
## closes it.
func on_creation_resolved(_player_id: String, action: String, reason: String, state: Dictionary) -> void:
	sl.set_creation_state(state)
	if reason != "":
		if sl.creation_screen != null:
			sl.creation_screen.show_refusal(reason)
		return
	hide_creation()
	if action == "create":
		sl.push_toast(sl.I18n.t("creation.welcome", [sl.own_display_name()]))
