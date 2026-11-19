extends RefCounted
## Methods moved verbatim out of `ui_slice.gd` (Phase 154). `sl` is the owning slice; each moved method keeps a forwarder there.

var sl: Node
var trade_box: VBoxContainer = null

const AdminPanelScript := preload("res://src/ui/admin_panel.gd")
const WritingRules := preload("res://src/technology/writing_rules.gd")
const TechTreeView := preload("res://src/ui/tech_tree_view.gd")

func _init(slice: Node) -> void:
	sl = slice

## One row per carried item for the slot grid: { id, quantity, durability,
## icon_key, tooltip, actions }, sorted by key. `inventory_lines()` stays the
## text projection; this is the structured one the grid is built from.
func inventory_rows() -> Array:
	var rows: Array = []
	if sl.inventory_slice == null:
		return rows
	var contents: Dictionary = bag_contents()
	var keys: Array = contents.keys()
	keys.sort()
	var repairable = {}
	for r in sl.repair_rows():
		repairable[str(r["id"])] = true
	for item_id in keys:
		var iid = str(item_id)
		var qty = int(contents[item_id])
		var dur = sl.durability_bar(iid).strip_edges()
		var tip = sl.I18n.t("ui.tip_quantity", [sl.I18n.content("item", iid), qty])
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

## One row per technology: { id, status, state, can_research, requires, unlocks, duration, cost }.
## `state` is what the tree shows (Phase 270): researched, researching, available (locked with every
## prerequisite researched) or locked.
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
		var prereqs_met: bool = sl._can_research(tid, status, data)
		rows.append({
			"id": tid,
			"status": status,
			"state": tech_state(status, prereqs_met),
			"can_research": prereqs_met and not short,
			"unlocks": data.get("unlocks", []),
			"points_cost": points_cost,
			"reason": "needs_points:%d" % points_cost if short else "",
			"icon_key": unlock_icon_key(data.get("unlocks", [])),
			"requires": data.get("requires", []),
			"duration": int(data.get("researchDuration", 0)),
			"cost": sl._fmt_entries(data.get("researchMaterials", [])),
		})
	return rows

## Phase 209 — a book or blueprint is read from the pack; the host decides what it teaches.
func writing_actions(item_id: String) -> Array:
	return [{"action": "read", "label": sl.I18n.t("ui.read")}] if WritingRules.is_writing(item_id) else []

## Phase 209 — write a book or blueprint; the host checks what the writer knows, the station and the cost.
func write_pressed(item_id: String) -> void:
	GameBus.writing_intent.emit("write", item_id, "")

## Phase 209 — one row per book or blueprint: { id, writing, teaches, kind, can_write, station, cost }. `can_write`
## is what this machine knows the player knows; the host decides.
func writing_rows() -> Array:
	var rows: Array = []
	if sl.technology_slice == null:
		return rows
	for item_id: String in WritingRules.items():
		var w: Dictionary = WritingRules.of(item_id)
		var cost := []
		var counts: Dictionary = WritingRules.cost(str(w["writing"]))
		for item: String in counts:
			cost.append({ "item": item, "quantity": counts[item] })
		rows.append({
			"id": item_id,
			"writing": str(w["writing"]),
			"teaches": str(w["teaches"]),
			"kind": str(w["kind"]),
			"can_write": bool(sl.technology_slice.knows(str(w["kind"]), str(w["teaches"]))),
			"station": WritingRules.station(str(w["writing"])),
			"cost": sl._fmt_entries(cost),
		})
	return rows

## The local player's points or learnt set changed: redraw the open Technology window and (Phase 209: a
## blueprint read arrives this way and can unlock a recipe) the open crafting windows, hand and station (Phase 269).
func on_research_points_synced(player_id: String) -> void:
	if not (player_id == "" or sl.technology_slice == null or player_id == sl.technology_slice.local_player_id()):
		return
	if sl._technology_box != null and sl._technology_box.is_visible_in_tree():
		sl.refresh_technology()
	if sl.is_window_open(sl.WINDOW_CRAFTING) or sl.is_window_open(sl.WINDOW_STATION):
		sl.refresh_crafting()

## Phase 209 — a writing row's name in the active locale: "Book: <technology>", "Blueprint: <recipe>".
func writing_name(row: Dictionary) -> String:
	return sl.I18n.t("writing.name.%s" % str(row["writing"]).to_lower(), [teaches_name(str(row["kind"]), str(row["teaches"]))])

## Phase 267 — what a writing teaches, by name: a technology, a station's recipe or a settlement project.
func teaches_name(kind: String, teaches: String) -> String:
	match kind:
		"technology":
			return sl.I18n.content("tech", teaches)
		"station":
			return sl.I18n.content("recipe", teaches)
	return sl.I18n.t("settlement.project." + teaches) if sl.I18n.has_key("settlement.project." + teaches) else sl.I18n.t(sl.I18n.CONTENT_UNKNOWN_KEY)

## Phase 209 — a writing's station in the active locale (Phase 267: `I18n.content("station", type)`), or "anywhere".
func station_name(type: String) -> String:
	if type == "":
		return sl.I18n.t("station.anywhere")
	return sl.I18n.content("station", type)

## Phase 269 — each OPEN crafting window redraws its cards (a closed one is rebuilt by `open_window` → `refresh_all`,
## so a craft resolved for any peer costs nothing while both are closed); the hand window lists the repairs under its grid.
func refresh_crafting() -> void:
	if sl.station_window != null and sl.is_window_open(sl.WINDOW_STATION):
		sl.station_window.refresh()
	if sl.hand_window == null or not sl.is_window_open(sl.WINDOW_CRAFTING):
		return
	sl.hand_window.refresh()
	var repairs: VBoxContainer = sl.hand_window.extra_box
	for child in repairs.get_children():
		child.queue_free()

	# Repair section: one row per held, repairable, non-pristine item.
	var repair_rows_list: Array = sl.repair_rows()
	if not repair_rows_list.is_empty():
		var sep = Label.new()
		sep.text = sl.I18n.t("ui.repairs_header")
		sep.add_theme_font_size_override("font_size", 14)
		sep.modulate = Color(0.75, 0.75, 0.75)
		repairs.add_child(sep)
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
			var line = sl.I18n.content("item", str(r["id"]))
			if str(r.get("station", "")) != "":
				line += "  @ %s" % station_name(str(r["station"]))
			line += "  " + sl.I18n.t("ui.needs", [r["materials"]])
			var lbl = Label.new()
			lbl.text = line + ("" if bool(r["can_repair"]) else "  (%s)" % sl.I18n.reason_text(str(r["reason"])))
			lbl.modulate = Color(1, 1, 1) if bool(r["can_repair"]) else Color(0.6, 0.6, 0.6)
			hbox.add_child(lbl)
			repairs.add_child(hbox)

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
	# Phase 53 — the friend code: the handle another player enters to spawn beside this one. Phase 222 — it and
	# the spawn notice sit here, beside the player's place in the world, on the map's own row so the map stays compact.
	sl._friend_code_label = Label.new()
	sl._friend_code_label.text = sl.friend_code_text(sl.own_handle)
	sl._friend_code_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl._friend_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(sl._friend_code_label)
	sl._m1.friend_code_copy = Button.new()
	sl._set_tr(sl._m1.friend_code_copy, "text", "ui.copy")
	sl._m1.friend_code_copy.focus_mode = Control.FOCUS_NONE
	sl._m1.friend_code_copy.pressed.connect(sl._on_copy_friend_code_pressed)
	row.add_child(sl._m1.friend_code_copy)
	sl._spawn_notice_label = Label.new()
	sl._spawn_notice_label.add_theme_font_size_override("font_size", 13)
	sl._spawn_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# An autowrap label measured with no width wraps every word onto its own line: give it the map's width.
	sl._spawn_notice_label.custom_minimum_size = Vector2(sl.map_window.custom_minimum_size.x, 0)
	# At most two lines, so no notice can push the map window past the minimum viewport; the tooltip has it all.
	sl._spawn_notice_label.max_lines_visible = 2
	sl._spawn_notice_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(sl._spawn_notice_label)
	return box

## (Re)build the control rows in the active language.
func _refill_controls() -> void:
	if sl._controls_box == null:
		return
	if sl._language_button != null:
		sl._language_button.text = sl.language_button_text()
	for child in sl._controls_box.get_children():
		if child != sl._language_button and not child.is_in_group("tutorial_settings"):
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
			if key_label.text.length() > 30:   # the windows row lists every Alt+letter: wrap it instead of widening the panel
				key_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				key_label.custom_minimum_size = Vector2(300, 0)
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

## Phase 204 — the clan window: found, invites, roles and the skill roster.
func _build_clan_content() -> Control:
	var panel = preload("res://src/ui/clan_panel.gd").new()
	sl.clan_panel = panel
	return panel

## Phase 208 — the chest window: what the open chest holds, put and take, and its access mode for an owner.
func _build_chest_content() -> Control:
	var panel = preload("res://src/ui/chest_panel.gd").new()
	sl.chest_panel = panel
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
		lbl.text = sl.I18n.t("trade.entry", [row["party"], sl.I18n.t("trade.side_give" if row["side"] == "give" else "trade.side_want"), sl.I18n.content("item", str(row["item_id"])), row["quantity"]])
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

## Phase 270 — a technology's tree state from its research status and whether its prerequisites are met.
static func tech_state(status: String, prereqs_met: bool) -> String:
	match status:
		"unlocked":
			return TechTreeView.STATE_RESEARCHED
		"researching":
			return TechTreeView.STATE_RESEARCHING
	return TechTreeView.STATE_AVAILABLE if prereqs_met else TechTreeView.STATE_LOCKED

## A tree state in the active locale (each key spelled out so the catalog audit sees it).
func tech_state_text(state: String) -> String:
	match state:
		TechTreeView.STATE_RESEARCHED:
			return sl.I18n.t("ui.tech_state_researched")
		TechTreeView.STATE_RESEARCHING:
			return sl.I18n.t("ui.tech_state_researching")
		TechTreeView.STATE_AVAILABLE:
			return sl.I18n.t("ui.tech_state_available")
	return sl.I18n.t("ui.tech_state_locked")

## Width of the technology detail column beside the tree.
const TECH_DETAIL_WIDTH := 240.0
## Minimum height of the books-and-blueprints list under the tree, so its Write and Read actions stay reachable.
const TECH_WRITING_MIN_HEIGHT := 140.0

## Phase 270 — the Technology window's tree: a toolbar (balance, fit button), the zoom canvas and the
## selected technology's details, added to `parent` above the books-and-blueprints list.
func build_tech_tree(parent: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	sl._tech_balance = Label.new()
	sl._tech_balance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(sl._tech_balance)
	var fit := Button.new()
	sl._set_tr(fit, "text", "ui.tech_fit")
	bar.add_child(fit)
	parent.add_child(bar)
	# The tree and the selected technology's details sit side by side; the details scroll in a
	# fixed-width column, so a long description never pushes the books-and-blueprints list below
	# out of the (unresizable, content-sized) window.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.size_flags_stretch_ratio = 3.0
	var tree: Control = TechTreeView.new()
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fit.pressed.connect(tree.fit_all)
	tree.tech_selected.connect(func(_id: String) -> void: refresh_tech_detail())
	row.add_child(tree)
	sl._tech_tree = tree
	var detail_scroll := ScrollContainer.new()
	detail_scroll.name = "TechDetailScroll"
	detail_scroll.custom_minimum_size = Vector2(TECH_DETAIL_WIDTH, 0)
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sl._tech_detail = VBoxContainer.new()
	sl._tech_detail.add_theme_constant_override("separation", 4)
	sl._tech_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(sl._tech_detail)
	row.add_child(detail_scroll)
	parent.add_child(row)

## The tree's node rows: localized name, state and description; the icon of what it unlocks.
func tech_tree_rows(rows: Array) -> Array:
	var out: Array = []
	for r: Dictionary in rows:
		var id := str(r["id"])
		var key := str(r["icon_key"])
		out.append({
			"id": id,
			"name": sl.I18n.content("tech", id),
			"state": r["state"],
			"state_text": tech_state_text(str(r["state"])),
			"icon": sl._load_item_icon(key) if key != "" else null,
			"tooltip": sl.I18n.content("tech", id, "desc"),
		})
	return out

## Phase 270 — the selected technology's description, cost, time, prerequisites, the recipes it unlocks
## (icons, named in their tooltips) and, when it is available, a Research button. The host still checks
## every research request.
func refresh_tech_detail() -> void:
	if sl._tech_detail == null:
		return
	# Detach before freeing (as `refresh_inventory` does): rows only queued for deletion would still
	# count toward the panel's minimum size for a frame and grow the window for good.
	for child in sl._tech_detail.get_children():
		sl._tech_detail.remove_child(child)
		sl._retire(child)
	var id: String = "" if sl._tech_tree == null else str(sl._tech_tree.selected)
	var r: Dictionary = {}
	for row: Dictionary in sl.technology_rows():
		if str(row["id"]) == id:
			r = row
	if r.is_empty():
		_detail_label(sl.I18n.t("ui.tech_select_hint"))
		return
	var title := _detail_label(sl.I18n.content("tech", id))
	title.add_theme_font_size_override("font_size", 18)
	_detail_label(tech_state_text(str(r["state"])))
	_detail_label(sl.I18n.content("tech", id, "desc")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label(sl.I18n.t("ui.tech_cost", [sl.I18n.number(int(r["points_cost"])), r["cost"] if str(r["cost"]) != "" else "—"]))
	_detail_label(sl.I18n.t("ui.tech_time", [sl.I18n.number(int(r["duration"]))]))
	var req_arr: Array = r.get("requires", [])
	_detail_label(sl.I18n.t("ui.tech_requires", [sl.I18n.content_list("tech", req_arr) if req_arr.size() > 0 else "—"]))
	var unlocks := HBoxContainer.new()
	unlocks.add_theme_constant_override("separation", 4)
	var head := Label.new()
	head.text = sl.I18n.t("ui.tech_unlocks")
	unlocks.add_child(head)
	for rid in r.get("unlocks", []):
		var key: String = "" if sl.crafting_slice == null else sl._first_output_icon_key(sl.crafting_slice.get_recipe(str(rid)).get("outputs", []))
		var tex: Texture2D = sl._load_item_icon(key) if key != "" else null
		if tex == null:
			var named := Label.new()
			named.text = sl.I18n.content("recipe", str(rid))
			unlocks.add_child(named)
			continue
		var rect := TextureRect.new()
		rect.texture = tex
		rect.custom_minimum_size = Vector2(28, 28)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.tooltip_text = sl.I18n.content("recipe", str(rid))
		unlocks.add_child(rect)
	sl._tech_detail.add_child(unlocks)
	if str(r["state"]) == TechTreeView.STATE_AVAILABLE:
		var btn := Button.new()
		btn.name = "Research"
		btn.text = sl.I18n.t("ui.research")
		btn.disabled = not bool(r["can_research"])
		btn.pressed.connect(sl._on_research_pressed.bind(id))
		sl._tech_detail.add_child(btn)
		if str(r["reason"]) != "":
			_detail_label(sl.I18n.reason_text(str(r["reason"])))

func _detail_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	sl._tech_detail.add_child(lbl)
	return lbl

func refresh_technology() -> void:
	if sl._tech_balance != null:
		sl._tech_balance.text = sl.I18n.t("ui.research_points", [sl.research_points()])
	if sl._tech_tree != null:
		sl._tech_tree.set_rows(tech_tree_rows(sl.technology_rows()))
	refresh_tech_detail()
	if sl._technology_box == null:
		return
	for child in sl._technology_box.get_children():
		child.queue_free()
	var header := Label.new()
	header.text = sl.I18n.t("ui.writing_header")
	sl._technology_box.add_child(header)
	for row in writing_rows():
		var w: Dictionary = row
		if not bool(w["can_write"]):
			continue
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		var btn := Button.new()
		btn.text = sl.I18n.t("ui.write")
		btn.pressed.connect(write_pressed.bind(str(w["id"])))
		hbox.add_child(btn)
		sl._add_row_icon(hbox, sl.item_icon_key(str(w["id"])))
		var lbl := Label.new()
		lbl.text = sl.I18n.t("ui.writing_line", [writing_name(w), w["cost"], station_name(str(w["station"]))])
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
## Phase 221 — `from_sheet`: opened from the Character window, so the screen offers Back and closes on Esc.
func show_creation(state: Dictionary, from_sheet: bool = false) -> void:
	if not state.is_empty():
		sl.set_creation_state(state)
	if sl.creation_screen == null:
		sl._creation_layer = CanvasLayer.new()
		sl._creation_layer.name = "Creation"
		sl._creation_layer.layer = 40
		sl.add_child(sl._creation_layer)
		sl.creation_screen = sl.CreationScreen.new()
		sl.creation_screen.visual_builder = _creation_visual
		sl.creation_screen.back_requested.connect(hide_creation)
		if sl.character_slice != null:
			sl.creation_screen.palette = sl.character_slice.palette_color
		sl._creation_layer.add_child(sl.creation_screen)
	sl.creation_screen.set_closable(from_sheet)
	sl.creation_screen.show_refusal("")
	sl.creation_screen.visible = true
	sl.creation_screen.refresh()
	if sl.player_slice != null:
		sl.player_slice.creation_hold = true

## Phase 221 — the Character window offers the creation screen only while the authority's state for this player is
## known (`_creation_known`: the registry on a host, the join snapshot on a client) and no character exists; a
## character is created once (`already_created` stays the host's rule).
func creation_button_shown() -> bool:
	return sl._creation_known and not sl.CreationRules.is_created(sl._creation_state)

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
	var built: Dictionary = ch.build_avatar("creation_doll", ch.deserialize_appearance(ch.creation_recipe(choice)))
	return built.get("root", null)

## The host answered this machine's creation or skip: a refusal shows on the screen in this locale; a success
## closes it.
func on_creation_resolved(_player_id: String, action: String, reason: String, state: Dictionary) -> void:
	sl.set_creation_state(state)
	if reason != "":
		if sl.creation_screen != null:
			sl.creation_screen.show_refusal(reason)
			# Phase 221 — the character already exists: nothing is left to do here, so the way back is offered.
			if reason == "already_created":
				sl.creation_screen.set_closable(true)
		return
	hide_creation()
	if action == "create":
		sl.push_toast(sl.I18n.t("creation.welcome", [sl.own_display_name()]))

## The bag as the player sees it: carried items less the copies the local avatar wears (worn gear stays in the bag
## for weight checks but shows only in the Character window). Feeds the Inventory grid, the text lines and the
## sale list; the hotbar and repair keep the whole bag, since a worn tool is still used and repaired.
func bag_contents() -> Dictionary:
	if sl.inventory_slice == null:
		return {}
	return without_worn(sl.inventory_slice.get_contents(), sl._local_worn())

## `contents` (item -> count) less one copy per worn slot holding that item; items left at 0 are dropped.
static func without_worn(contents: Dictionary, worn: Dictionary) -> Dictionary:
	var out := contents.duplicate()
	for slot in worn:
		var id := str(worn[slot])
		if out.has(id):
			out[id] = int(out[id]) - 1
			if int(out[id]) <= 0:
				out.erase(id)
	return out

## The action a double-click on an item slot runs: wear it, take it off (Character window), or read it ("" when the item has neither;
## repair and the rest stay on the right-click menu).
const PRIMARY_ACTIONS := ["equip", "unequip", "read"]
static func primary_action(actions: Array) -> String:
	for want in PRIMARY_ACTIONS:
		for a in actions:
			if str(a.get("action", "")) == want:
				return want
	return ""

## Phase 47 — one row per fabric `equipmentSlot` (sorted): { slot, item, icon_key, tooltip, actions }. `item` is "" for an empty slot.
func character_rows() -> Array:
	var worn: Dictionary = sl._local_worn()
	var repairable := {}
	for r in sl.repair_rows():
		repairable[str(r["id"])] = true
	var rows: Array = []
	for slot in sl.EquipmentRules.slots(GameData.ITEMS):
		var item := str(worn.get(slot, ""))
		# Worn gear is shown only here, so its repair action is offered here too.
		var actions: Array = []
		if item != "":
			if repairable.has(item):
				actions.append({"action": "repair", "label": sl.I18n.t("ui.repair")})
			actions.append({"action": "unequip", "label": sl.I18n.t("ui.unequip")})
		rows.append({
			"slot": slot,
			"item": item,
			"icon_key": sl.item_icon_key(item) if item != "" else "",
			"tooltip": ("%s: %s\n%s" % [slot, sl.I18n.content("item", item), sl.item_description(item)]).strip_edges() if item != "" else sl.I18n.t("ui.slot_empty", [slot]),
			"actions": actions,
		})
	return rows

## Phase 224 — Esc with no text field focused (the field is left first, in `UiSlice._input`): close the top open
## window, else open the Esc menu, else (the menu is up) close it. Returns what it did: "window", "menu_open",
## "menu_close".
func handle_escape() -> String:
	if sl.is_pause_menu_open():
		close_pause_menu()
		return "menu_close"
	if close_top_window():
		return "window"
	open_pause_menu()
	return "menu_open"

## Close the most recently opened window still open; one shown some other way (no open order) closes too.
func close_top_window() -> bool:
	while not sl._open_order.is_empty():
		var top := str(sl._open_order.pop_back())
		if sl.is_window_open(top):
			sl.close_window(top)
			return true
	if sl.any_window_open():
		sl._close_all_windows()
		return true
	return false

## Open the Esc menu: world input stops (the body's `pause_hold`, Phase 219's rule) and a held look ends.
func open_pause_menu() -> void:
	if sl.pause_menu == null:
		sl._pause_layer = CanvasLayer.new()
		sl._pause_layer.name = "Pause"
		sl._pause_layer.layer = 45   # above the creation screen (40)
		sl.add_child(sl._pause_layer)
		sl.pause_menu = sl.PauseMenuScript.new()
		sl.pause_menu.resume_requested.connect(close_pause_menu)
		sl.pause_menu.exit_requested.connect(_on_pause_choice.bind(GameBus.exit_to_menu_requested))
		sl.pause_menu.quit_requested.connect(_on_pause_choice.bind(GameBus.quit_game_requested))
		sl._pause_layer.add_child(sl.pause_menu)
	if not sl.is_pause_menu_open():
		Sound.play("ui.window_open")   # Phase 276 — the Esc menu is a window too
	sl.pause_menu.open()
	if sl.player_slice != null:
		sl.player_slice.pause_hold = true
	GameBus.pause_menu_toggled.emit(true)

func close_pause_menu() -> void:
	if not sl.is_pause_menu_open():
		return
	Sound.play("ui.window_close")
	sl.pause_menu.close()
	if sl.player_slice != null:
		sl.player_slice.pause_hold = false
	GameBus.pause_menu_toggled.emit(false)

## Exit to main menu / Quit game: the menu closes and the choice goes out as a local bus intent (MenuWiring).
func _on_pause_choice(intent: Signal) -> void:
	close_pause_menu()
	intent.emit()

## Phase 260 — a host notice (`notice.*`, e.g. a technology discovered) for this machine's player is also shown
## as a toast balloon, rendered from its key in the local locale; the chat keeps its line.
func on_system_notice(key: String, args: Array, target_id: String) -> void:
	if not key.begins_with("notice."):
		return
	if target_id != "" and not sl._belongs_to_local_player({ "player_id": target_id }):
		return
	sl.push_toast(sl.I18n.render(sl.I18n.sanitize_msg(key, args)))
