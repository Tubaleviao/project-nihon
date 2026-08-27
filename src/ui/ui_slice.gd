extends Node
## UI slice — window system exposing inventory, technology tree, and crafting
## (Phase 14). Each window is a PanelContainer on a shared CanvasLayer, toggled
## with I / T / C and closed with ESC or the window's ✕ button. Opening a window
## releases the mouse so buttons are clickable; closing the last window
## re-captures it. World input is gated in PlayerSlice on the mouse being
## captured, so no attack/mine slips through an open menu.
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : inventory_changed, item_picked_up, block_mined, block_placed,
##         craft_resolved, research_resolved, technology_unlocked
##   OUT : craft_requested(recipe_id), research_requested(tech_id)
##
## Public API:
##   toggle_window(panel) / open_window(panel) / close_window(panel)
##   is_window_open(panel) -> bool
##   any_window_open()      -> bool
##   inventory_lines()      -> Array[String]     (pure projection, testable)
##   crafting_rows()        -> Array[Dictionary] (pure projection, testable)
##   technology_rows()      -> Array[Dictionary] (pure projection, testable)

const WINDOW_INVENTORY  := "inventory"
const WINDOW_TECHNOLOGY := "technology"
const WINDOW_CRAFTING   := "crafting"
const WINDOW_TRADE      := "trade"
const WINDOW_MARKET     := "market"
const WINDOW_PROPOSALS  := "proposals"

## Set by game_root after instantiation.
var inventory_slice: Node = null
var crafting_slice: Node = null
var technology_slice: Node = null
var market_slice: Node = null
var proposal_slice: Node = null

var _ui: CanvasLayer = null
var _panels: Dictionary = {}                 # panel name -> PanelContainer
var _inventory_usage: Label = null
var _inventory_items: Label = null
var _crafting_box: VBoxContainer = null
var _technology_box: VBoxContainer = null
var _technology_feedback: Label = null
var _market_box: VBoxContainer = null
var _proposal_box: VBoxContainer = null

func _ready() -> void:
	_build_ui()
	GameBus.craft_resolved.connect(_on_craft_resolved)
	GameBus.research_resolved.connect(_on_research_resolved)
	GameBus.technology_unlocked.connect(_on_technology_unlocked)
	GameBus.item_picked_up.connect(_on_item_picked_up)
	GameBus.inventory_changed.connect(_on_inventory_changed)
	GameBus.block_mined.connect(_on_block_mined)
	GameBus.block_placed.connect(_on_block_placed)
	GameBus.market_listing_created.connect(_on_market_changed)
	GameBus.market_listing_purchased.connect(_on_market_changed)
	GameBus.market_listing_expired.connect(_on_market_changed)
	GameBus.proposal_submitted.connect(_on_proposal_changed)
	GameBus.proposal_ratified.connect(_on_proposal_changed)
	refresh_all()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_I:
				toggle_window(WINDOW_INVENTORY)
			KEY_T:
				toggle_window(WINDOW_TECHNOLOGY)
			KEY_C:
				toggle_window(WINDOW_CRAFTING)
			KEY_B:
				toggle_window(WINDOW_TRADE)
			KEY_M:
				toggle_window(WINDOW_MARKET)
			KEY_G:
				toggle_window(WINDOW_PROPOSALS)
			KEY_ESCAPE:
				if any_window_open():
					_close_all_windows()
				elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				else:
					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# ---------------------------------------------------------------------------
# Window state
# ---------------------------------------------------------------------------

func is_window_open(panel: String) -> bool:
	var p: Control = _panels.get(panel, null)
	return p != null and p.visible

func any_window_open() -> bool:
	for panel in _panels:
		if _panels[panel].visible:
			return true
	return false

func open_window(panel: String) -> void:
	var p: Control = _panels.get(panel, null)
	if p == null:
		return
	p.visible = true
	refresh_all()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func close_window(panel: String) -> void:
	var p: Control = _panels.get(panel, null)
	if p == null:
		return
	p.visible = false
	if not any_window_open():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func toggle_window(panel: String) -> void:
	if is_window_open(panel):
		close_window(panel)
	else:
		open_window(panel)

func _close_all_windows() -> void:
	for panel in _panels:
		_panels[panel].visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func refresh_all() -> void:
	refresh_inventory()
	refresh_crafting()
	refresh_technology()
	refresh_market()
	refresh_proposals()

# ---------------------------------------------------------------------------
# Pure projections (testable without a scene tree)
# ---------------------------------------------------------------------------

## One display line per carried item ("Ferrite ×5"), sorted by key. Durable
## items append a durability readout ("FerritePick ×1  [80/80]").
func inventory_lines() -> Array:
	var lines: Array = []
	if inventory_slice == null:
		return lines
	var contents: Dictionary = inventory_slice.get_contents()
	if contents.is_empty():
		return lines
	var keys: Array = contents.keys()
	keys.sort()
	for item_id in keys:
		lines.append("%s ×%d%s" % [item_id, contents[item_id], durability_bar(item_id)])
	return lines

func inventory_usage_text() -> String:
	if inventory_slice == null:
		return ""
	return "Weight: %.1f / %.1f kg   Slots: %d / %d" % [
		inventory_slice.get_current_weight(),
		inventory_slice.get_max_weight(),
		inventory_slice.get_total_slots_used(),
		inventory_slice.get_max_slots(),
	]

## Durability readout for a held durable item ("  [80/80]"), or "" when the
## item has no durability model or is not held.
func durability_bar(item_id: String) -> String:
	if inventory_slice == null or not inventory_slice.has_method("get_durability"):
		return ""
	if inventory_slice.get_item_count(item_id) <= 0:
		return ""
	var cur: float = inventory_slice.get_durability(item_id)
	if cur < 0.0:
		return ""
	var max_d: float = inventory_slice.get_max_durability(item_id)
	var cond := ""
	if inventory_slice.has_method("get_condition"):
		cond = str(inventory_slice.get_condition(item_id))
	if cond == "pristine" or cond == "":
		return "  [%d/%d]" % [int(cur), int(max_d)]
	return "  [%d/%d %s]" % [int(cur), int(max_d), cond]

## One row per recipe: { id, can_craft, reason, inputs, outputs }.
func crafting_rows() -> Array:
	var rows: Array = []
	if crafting_slice == null:
		return rows
	var ids: Array = GameData.RECIPES.keys()
	ids.sort()
	for recipe_id in ids:
		var rid := str(recipe_id)
		var check: Dictionary = crafting_slice.can_craft(rid)
		var recipe: Dictionary = crafting_slice.get_recipe(rid)
		rows.append({
			"id": rid,
			"can_craft": bool(check.get("success", false)),
			"reason": str(check.get("reason", "")),
			"station": str(recipe.get("station", "")),
			"inputs": _fmt_entries(recipe.get("inputs", [])),
			"outputs": _fmt_entries(recipe.get("outputs", [])),
		})
	return rows

## One row per technology: { id, status, can_research, requires, duration, cost }.
func technology_rows() -> Array:
	var rows: Array = []
	if technology_slice == null:
		return rows
	var ids: Array = GameData.TECHNOLOGIES.keys()
	ids.sort()
	for tech_id in ids:
		var tid := str(tech_id)
		var status: String = technology_slice.get_status(tid)
		var data: Dictionary = technology_slice.get_tech_data(tid)
		rows.append({
			"id": tid,
			"status": status,
			"can_research": _can_research(tid, status, data),
			"requires": data.get("requires", []),
			"duration": int(data.get("researchDuration", 0)),
			"cost": _fmt_entries(data.get("researchMaterials", [])),
		})
	return rows

## One row per active market listing: { id, seller, item_id, quantity, price }.
func market_rows() -> Array:
	var rows: Array = []
	if market_slice == null:
		return rows
	for listing in market_slice.get_listings():
		var l: Dictionary = listing
		rows.append({
			"id": str(l["id"]),
			"seller": str(l["seller"]),
			"item_id": str(l["item_id"]),
			"quantity": int(l["quantity"]),
			"price": float(l["price"]),
		})
	return rows

## One row per proposal: { id, title, author, state, for, against }.
func proposal_rows() -> Array:
	var rows: Array = []
	if proposal_slice == null:
		return rows
	for p in proposal_slice.get_all_proposals():
		var votes: Dictionary = p.get("votes", {})
		var for_count: int = 0
		var against_count: int = 0
		for voter in votes:
			if votes[voter] == "for":
				for_count += 1
			else:
				against_count += 1
		rows.append({
			"id": str(p["id"]),
			"title": str(p.get("title", "")),
			"author": str(p.get("author", "")),
			"state": str(p.get("state", "proposed")),
			"for": for_count,
			"against": against_count,
		})
	return rows

## A tech is researchable from the window only when still locked and every
## prerequisite is unlocked. Material availability is validated at research time
## (begin_research), not here.
func _can_research(tech_id: String, status: String, data: Dictionary) -> bool:
	if status != "locked":
		return false
	for req in data.get("requires", []):
		if not technology_slice.is_unlocked(str(req)):
			return false
	return true

# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

func refresh_inventory() -> void:
	if _inventory_items == null:
		return
	var lines: Array = inventory_lines()
	_inventory_usage.text = inventory_usage_text()
	_inventory_items.text = "(empty)" if lines.is_empty() else "\n".join(lines)

func refresh_crafting() -> void:
	if _crafting_box == null:
		return
	for child in _crafting_box.get_children():
		child.queue_free()
	for row in crafting_rows():
		var r: Dictionary = row
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		var btn := Button.new()
		btn.text = "Craft"
		btn.disabled = not bool(r["can_craft"])
		btn.pressed.connect(_on_craft_pressed.bind(str(r["id"])))
		hbox.add_child(btn)
		var line := "%s: %s → %s" % [r["id"], r["inputs"], r["outputs"]]
		if str(r.get("station", "")) != "":
			line += "  @ %s" % r["station"]
		var lbl := Label.new()
		lbl.text = line + ("" if bool(r["can_craft"]) else "  (%s)" % r["reason"])
		lbl.modulate = Color(1, 1, 1) if bool(r["can_craft"]) else Color(0.6, 0.6, 0.6)
		hbox.add_child(lbl)
		_crafting_box.add_child(hbox)

func refresh_technology() -> void:
	if _technology_box == null:
		return
	for child in _technology_box.get_children():
		child.queue_free()
	for row in technology_rows():
		var r: Dictionary = row
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		var btn := Button.new()
		btn.text = "Research"
		btn.disabled = not bool(r["can_research"])
		btn.pressed.connect(_on_research_pressed.bind(str(r["id"])))
		hbox.add_child(btn)
		var req_arr: Array = r.get("requires", [])
		var reqs: String = ", ".join(req_arr) if req_arr.size() > 0 else "—"
		var line := "%s [%s]  requires: %s  cost: %s  %ds" % [r["id"], r["status"], reqs, r["cost"], r["duration"]]
		var lbl := Label.new()
		lbl.text = line
		hbox.add_child(lbl)
		_technology_box.add_child(hbox)

func refresh_market() -> void:
	if _market_box == null:
		return
	for child in _market_box.get_children():
		child.queue_free()
	for row in market_rows():
		var r: Dictionary = row
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		var btn := Button.new()
		btn.text = "Buy"
		btn.pressed.connect(_on_market_buy_pressed.bind(str(r["id"])))
		hbox.add_child(btn)
		var lbl := Label.new()
		lbl.text = "%s  %s ×%d  @ %.2f  (%s)" % [r["id"], r["item_id"], r["quantity"], r["price"], r["seller"]]
		hbox.add_child(lbl)
		_market_box.add_child(hbox)

func refresh_proposals() -> void:
	if _proposal_box == null:
		return
	for child in _proposal_box.get_children():
		child.queue_free()
	for row in proposal_rows():
		var r: Dictionary = row
		var lbl := Label.new()
		lbl.text = "%s [%s] %s  (for:%d / against:%d) — %s" % [r["id"], r["state"], r["title"], r["for"], r["against"], r["author"]]
		_proposal_box.add_child(lbl)

# ---------------------------------------------------------------------------
# Bus handlers
# ---------------------------------------------------------------------------

func _on_craft_pressed(recipe_id: String) -> void:
	GameBus.craft_requested.emit(recipe_id)

func _on_research_pressed(tech_id: String) -> void:
	GameBus.research_requested.emit(tech_id)

func _on_close_pressed(panel: String) -> void:
	close_window(panel)

func _on_craft_resolved(_result: Dictionary) -> void:
	refresh_crafting()
	refresh_inventory()

func _on_research_resolved(result: Dictionary) -> void:
	if _technology_feedback != null:
		if result.get("success", false):
			_technology_feedback.text = "Researching %s…" % result.get("tech_id", "?")
		else:
			_technology_feedback.text = "%s: %s" % [result.get("tech_id", "?"), result.get("reason", "?")]
	refresh_technology()

func _on_technology_unlocked(_tech_id: String) -> void:
	refresh_technology()
	refresh_crafting()

func _on_item_picked_up(_item_id: String, _quantity: int) -> void:
	refresh_inventory()

func _on_inventory_changed() -> void:
	refresh_inventory()
	refresh_crafting()

func _on_block_mined(_material: String, _quantity: int, _position: Vector3) -> void:
	refresh_inventory()

func _on_block_placed(_material: String, _position: Vector3) -> void:
	refresh_inventory()

func _on_market_changed(_a = null, _b = null, _c = null, _d = 0, _e = 0.0) -> void:
	refresh_market()

func _on_proposal_changed(_a = null, _b = null) -> void:
	refresh_proposals()

func _on_market_buy_pressed(listing_id: String) -> void:
	if market_slice != null:
		market_slice.buy(listing_id, "player")
	refresh_market()
	refresh_inventory()

# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "Windows"
	_ui.layer = 30
	add_child(_ui)

	_panels[WINDOW_INVENTORY] = _build_window(WINDOW_INVENTORY, "Inventory", _build_inventory_content(), Vector2(24, 24))
	_panels[WINDOW_TECHNOLOGY] = _build_window(WINDOW_TECHNOLOGY, "Technology", _build_technology_content(), Vector2(470, 24))
	_panels[WINDOW_CRAFTING] = _build_window(WINDOW_CRAFTING, "Crafting", _build_crafting_content(), Vector2(24, 360))
	_panels[WINDOW_TRADE] = _build_window(WINDOW_TRADE, "Trade", _build_trade_content(), Vector2(470, 360))
	_panels[WINDOW_MARKET] = _build_window(WINDOW_MARKET, "Market", _build_market_content(), Vector2(24, 700))
	_panels[WINDOW_PROPOSALS] = _build_window(WINDOW_PROPOSALS, "Proposals", _build_proposals_content(), Vector2(470, 700))

func _build_window(key: String, title: String, content: Control, position: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = position
	panel.custom_minimum_size = Vector2(420, 300)
	panel.visible = false
	_ui.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var bar := HBoxContainer.new()
	vbox.add_child(bar)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title_label)

	var close := Button.new()
	close.text = "✕"
	close.pressed.connect(_on_close_pressed.bind(key))
	bar.add_child(close)

	vbox.add_child(content)
	return panel

func _build_inventory_content() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_inventory_usage = Label.new()
	_inventory_usage.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_inventory_usage)
	_inventory_items = Label.new()
	_inventory_items.add_theme_font_size_override("font_size", 15)
	_inventory_items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_inventory_items)
	return vbox

func _build_crafting_content() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_crafting_box = VBoxContainer.new()
	_crafting_box.add_theme_constant_override("separation", 4)
	_crafting_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_crafting_box)
	return scroll

func _build_technology_content() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_technology_feedback = Label.new()
	_technology_feedback.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_technology_feedback)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_technology_box = VBoxContainer.new()
	_technology_box.add_theme_constant_override("separation", 4)
	_technology_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_technology_box)
	vbox.add_child(scroll)
	return vbox

func _build_trade_content() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	var lbl := Label.new()
	lbl.text = "Player-to-player trade is initiated in-world.\nYour Diplomacy tier lowers the broker fee on received goods."
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl)
	return vbox

func _build_market_content() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_market_box = VBoxContainer.new()
	_market_box.add_theme_constant_override("separation", 4)
	_market_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_market_box)
	return scroll

func _build_proposals_content() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_proposal_box = VBoxContainer.new()
	_proposal_box.add_theme_constant_override("separation", 4)
	_proposal_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_proposal_box)
	return scroll

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _fmt_entries(entries: Array) -> String:
	var parts: Array = []
	for e in entries:
		parts.append("%s ×%d" % [str(e.get("item", "")), int(e.get("quantity", 1))])
	return ", ".join(parts)
