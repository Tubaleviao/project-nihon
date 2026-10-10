extends Node
## UI slice — window system exposing inventory, technology, crafting, trade,
## market, and proposals. Each window is a PanelContainer on a shared CanvasLayer,
## toggled with I / T / H (crafting) / C (character) / Y (trade) / P (market) / G (proposals) / ? (controls)
## and closed with ESC or the window's ✕ button. Every window drags by its title
## bar and reopens where it was left (Phase 46). Opening a window
## never touches the mouse: the pointer is always free (Phase 85) and only
## held-right-click captures it for the camera. A click on a window is consumed
## by the window, so no attack/mine slips through an open menu.
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
##   inventory_rows()       -> Array[Dictionary] (slot grid projection, testable)
##   controls_rows()        -> Array[Dictionary] (the `?` legend, testable)
##   clamp_window_position / item_icon_key / item_actions / action_intent (pure)
##
## Window layout persistence: positions are a CLIENT-ONLY view setting, stored in
## `user://ui_layout.json` (not on the player record). A layout carries no
## authority, differs per machine and must not be replicated; the file holds at
## most one entry per known window key, is overwritten in place, and unknown keys
## are dropped on load, so nothing accumulates and there is no per-connection
## state to evict.
const Diag := preload("res://src/core/diag.gd")

const WINDOW_INVENTORY  := "inventory"
const WINDOW_TECHNOLOGY := "technology"
const WINDOW_CRAFTING   := "crafting"
const WINDOW_TRADE      := "trade"
const WINDOW_MARKET     := "market"
const WINDOW_PROPOSALS  := "proposals"
const WINDOW_CONTROLS   := "controls"
const WINDOW_CHARACTER  := "character"

const WINDOW_KEYS := [
	WINDOW_INVENTORY, WINDOW_TECHNOLOGY, WINDOW_CRAFTING,
	WINDOW_TRADE, WINDOW_MARKET, WINDOW_PROPOSALS, WINDOW_CONTROLS, WINDOW_CHARACTER,
]

const MouseIconScript := preload("res://src/ui/mouse_icon.gd")
const EquipmentRules := preload("res://src/character/equipment_rules.gd")
const HotbarScript := preload("res://src/ui/hotbar.gd")
const WindowDockScript := preload("res://src/ui/window_dock.gd")

## Pixels of a window that must stay reachable on every edge when dragged.
const DRAG_VISIBLE_MARGIN := 48.0
## Largest stored window coordinate a layout file may carry; beyond it the entry is junk.
const LAYOUT_MAX_COORD := 100000.0
const LAYOUT_PATH := "user://ui_layout.json"
const ICON_KEY_FORMAT := "icons/items/%s.png.raw"
const SLOT_SIZE := Vector2(72, 72)
const INVENTORY_COLUMNS := 5

## Set by game_root after instantiation.
var inventory_slice: Node = null
## Phase 47 — the character slice: the Character window reads the local avatar's
## worn set and stats from it, and equips through its `apply_equipment`.
var character_slice: Node = null
var crafting_slice: Node = null
var technology_slice: Node = null
var market_slice: Node = null
var proposal_slice: Node = null
var trade_slice: Node = null
## The voxel slice owns the place-material selection the hotbar drives.
var voxel_slice: Node = null

## HUD: item/skill boxes along the bottom, window shortcuts under the health bar.
var hotbar: VBoxContainer = null
var window_dock: VBoxContainer = null
## The player body, for where a dropped item lands (`drop_point()`); set by game_root.
var player_slice: Node = null
## False when this machine is a client: its pack is the host's, so a drop to the ground is refused.
var drops_enabled: bool = true
## The payload of the drag in flight (set by the drag sources), read when the drag ends.
var _drag_payload: Dictionary = {}
var _skills_grid: GridContainer = null
var _skills_signature: int = 0
## Brief line shown when a drag-drop is refused.
var _hud_notice: Label = null

var _ui: CanvasLayer = null
## Set while the loading screen holds world input (`GameBus.world_input_frozen`). The
## window keys and Escape are refused meanwhile: the loading screen restores the mouse
## capture it saved on `finish()`, so a window opened during loading would be left open
## under a captured mouse, and clicks would reach the world through the menu.
var _world_input_frozen: bool = false
var _panels: Dictionary = {}                 # panel name -> PanelContainer
var _inventory_usage: Label = null
var _inventory_grid: GridContainer = null
var _inventory_empty: Label = null
var _character_stats: Label = null
## Phase 53 — the player's own public handle (their friend code) and the spawn note.
var own_handle: String = ""
var _friend_code_label: Label = null
var _spawn_notice_label: Label = null
var _worldgen_notice_label: Label = null
var _character_grid: GridContainer = null
var _slot_menu: PopupMenu = null
var _slot_menu_item: String = ""
var _slot_menu_actions: Array = []
var _drag_key: String = ""
var _drag_moved: bool = false
## Resolved icon path -> Texture2D (or null); the path changes when a pack mounts.
var _icon_cache: Dictionary = {}
var _drag_grab: Vector2 = Vector2.ZERO
var layout_path: String = LAYOUT_PATH
var _layout: Dictionary = {}                 # window key -> Vector2
var _crafting_box: VBoxContainer = null
var _repair_feedback: Label = null
var _technology_box: VBoxContainer = null
var _technology_feedback: Label = null
var _market_box: VBoxContainer = null
var _proposal_box: VBoxContainer = null
# Phase 24 social/economy window widgets (trade / market / proposals).
var _active_trade_id: String = ""
var _trade_status: Label = null
var _market_item_select: OptionButton = null
var _market_qty: LineEdit = null
var _market_price: LineEdit = null
var _market_feedback: Label = null
var _proposal_title: LineEdit = null
var _proposal_body: LineEdit = null
var _proposal_feedback: Label = null
## `str(character_rows())` at the last grid build; an unchanged one skips the rebuild.
var _character_rows_signature: int = 0

func _ready() -> void:
	_build_ui()
	GameBus.craft_resolved.connect(_on_craft_resolved)
	GameBus.spawn_notice.connect(_on_spawn_notice)
	GameBus.worldgen_version_mismatch.connect(_on_worldgen_version_mismatch)
	GameBus.repair_resolved.connect(_on_repair_resolved)
	GameBus.research_resolved.connect(_on_research_resolved)
	GameBus.technology_unlocked.connect(_on_technology_unlocked)
	GameBus.item_picked_up.connect(_on_item_picked_up)
	GameBus.inventory_changed.connect(_on_inventory_changed)
	GameBus.character_appearance_changed.connect(_on_character_appearance_changed)
	GameBus.block_mined.connect(_on_block_mined)
	GameBus.block_placed.connect(_on_block_placed)
	GameBus.market_listing_created.connect(_on_market_listing_created)
	GameBus.market_listing_purchased.connect(_on_market_listing_purchased)
	GameBus.market_listing_expired.connect(_on_market_listing_expired)
	GameBus.proposal_submitted.connect(_on_proposal_submitted)
	GameBus.proposal_ratified.connect(_on_proposal_ratified)
	GameBus.world_input_frozen.connect(_on_world_input_frozen)
	GameBus.block_place_material_changed.connect(_on_place_material_changed)
	refresh_all()

func _on_world_input_frozen(frozen: bool) -> void:
	_world_input_frozen = frozen

func _input(event: InputEvent) -> void:
	if _world_input_frozen:
		return
	if event is InputEventKey and event.pressed:
		# Typing into a text field must not trigger window hotkeys.
		var focus := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
		if (focus is LineEdit or focus is TextEdit) and event.keycode != KEY_ESCAPE:
			return
		# The hotbar first: 1-9 and the player's own box shortcuts, or a key being chosen for a box.
		if hotbar != null and hotbar.handle_key(event):
			if is_inside_tree():
				get_viewport().set_input_as_handled()
			return
		# `?` is matched on the character it produces: it is not Shift+/ on every layout.
		if event.unicode == 63:
			toggle_window(WINDOW_CONTROLS)
			return
		match event.keycode:
			KEY_I:
				toggle_window(WINDOW_INVENTORY)
			KEY_T:
				toggle_window(WINDOW_TECHNOLOGY)
			KEY_H:
				toggle_window(WINDOW_CRAFTING)
			KEY_Y:
				toggle_window(WINDOW_TRADE)
			KEY_P:
				toggle_window(WINDOW_MARKET)
			KEY_G:
				toggle_window(WINDOW_PROPOSALS)
			KEY_C:
				toggle_window(WINDOW_CHARACTER)
			KEY_ESCAPE:
				_close_all_windows()

# ---------------------------------------------------------------------------
# HUD: hotbar / skill bar / window dock
# ---------------------------------------------------------------------------

func _build_hud() -> void:
	hotbar = HotbarScript.new()
	hotbar.anchor_left = 0.5
	hotbar.anchor_right = 0.5
	hotbar.anchor_top = 1.0
	hotbar.anchor_bottom = 1.0
	hotbar.offset_left = -300.0
	hotbar.offset_right = 300.0
	hotbar.offset_top = -13.0
	hotbar.offset_bottom = -12.0
	hotbar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hotbar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hotbar.save_path = layout_path.get_basename() + "_hotbar.json"
	hotbar.icon_loader = func(item_id: String) -> Texture2D: return _load_item_icon(item_icon_key(item_id))
	hotbar.held_provider = func() -> Dictionary:
		return inventory_slice.get_contents() if inventory_slice != null else {}
	hotbar.tier_provider = func() -> Dictionary:
		return crafting_slice.get_skills() if crafting_slice != null else {}
	hotbar.build()
	hotbar.slot_selected.connect(_on_hotbar_selected)
	hotbar.drag_began.connect(_on_drag_began)
	_ui.add_child(hotbar)

	# Under the health bar (top-left, see PlayerSlice._build_hud).
	window_dock = WindowDockScript.new()
	window_dock.offset_left = 12.0
	window_dock.offset_top = 48.0
	window_dock.build()
	window_dock.window_toggled.connect(toggle_window)
	_ui.add_child(window_dock)

	_hud_notice = Label.new()
	_hud_notice.anchor_left = 0.5
	_hud_notice.anchor_right = 0.5
	_hud_notice.anchor_top = 1.0
	_hud_notice.anchor_bottom = 1.0
	_hud_notice.offset_left = -300.0
	_hud_notice.offset_right = 300.0
	_hud_notice.offset_top = -180.0
	_hud_notice.offset_bottom = -156.0
	_hud_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_notice.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hud_notice.add_theme_constant_override("outline_size", 5)
	_ui.add_child(_hud_notice)

# ---------------------------------------------------------------------------
# Drag and drop
# ---------------------------------------------------------------------------

func _on_drag_began(payload: Dictionary) -> void:
	_drag_payload = payload

## The drag source for an inventory slot: carries the item id; hold Shift on release to drop the whole stack.
func _inventory_drag(_at: Vector2, item_id: String, qty: int, source: Control) -> Variant:
	var label := Label.new()
	label.text = "%s ×%d" % [item_id, qty] if qty > 1 else item_id
	source.set_drag_preview(label)
	_drag_payload = {"kind": "item", "id": item_id, "quantity": qty}
	return _drag_payload

func _skill_drag(_at: Vector2, skill: String, source: Control) -> Variant:
	var label := Label.new()
	label.text = skill
	source.set_drag_preview(label)
	_drag_payload = {"kind": "skill", "id": skill}
	return _drag_payload

func _on_drag_end() -> void:
	if _drag_payload.is_empty():
		return
	var payload := _drag_payload
	_drag_payload = {}
	var vp := get_viewport() if is_inside_tree() else null
	if vp == null or vp.gui_is_drag_successful():
		return
	# Released over a control that refused it (a window, the hotbar edge): nothing happens.
	# Released over the bare world: the drop target is the ground.
	if vp.gui_get_hovered_control() == null:
		finish_world_drop(payload, Input.is_key_pressed(KEY_SHIFT))

## A drag that ended in the world. An inventory item lands on the ground (one unit, or the whole
## stack with `whole_stack`); a hotbar box is simply emptied. Returns what happened, for tests.
func finish_world_drop(payload: Dictionary, whole_stack: bool) -> String:
	match str(payload.get("kind", "")):
		"hotbar":
			hotbar.clear_slot(int(payload.get("from", -1)))
			return "cleared"
		"item":
			return request_drop(str(payload.get("id", "")), int(payload.get("quantity", 1)) if whole_stack else 1)
	return ""

## Ask for `quantity` of `item_id` to be dropped in front of the player. Returns "dropped",
## or the reason it was refused.
func request_drop(item_id: String, quantity: int) -> String:
	if not drops_enabled:
		_notify("Items can't be dropped while joined to another player's world yet")
		return "client"
	if inventory_slice == null or quantity <= 0 or int(inventory_slice.get_item_count(item_id)) <= 0:
		return "none"
	var where := Vector3.ZERO
	if player_slice != null and player_slice.has_method("drop_point"):
		where = player_slice.drop_point()
	GameBus.item_drop_requested.emit(item_id, mini(quantity, int(inventory_slice.get_item_count(item_id))), where)
	return "dropped"

func _notify(text: String) -> void:
	if _hud_notice == null:
		return
	_hud_notice.text = text
	if is_inside_tree():
		var t := create_tween()
		t.tween_interval(3.0)
		t.tween_callback(func(): _hud_notice.text = "")

## Apply what a hotbar selection means: a block becomes the place material, gear is worn, and
## anything else (or an empty box) clears the place material so a stray click places nothing.
func _on_hotbar_selected(index: int, item_id: String) -> void:
	if voxel_slice == null:
		return
	var kind: String = hotbar.kind_at(index)
	var material := item_id if kind == HotbarScript.KIND_BLOCK else ""
	if voxel_slice.get_place_material() != material:
		voxel_slice.set_place_material(material)
		GameBus.block_place_material_changed.emit(material)
	if kind == HotbarScript.KIND_GEAR:
		dispatch_item_action(item_id, "equip")

## R (cycle material) and any other path that changes the place material: follow it on the bar.
func _on_place_material_changed(material: String) -> void:
	if hotbar != null and material != "" and hotbar.selected_item() != material:
		hotbar.select_item(material)

func refresh_hud() -> void:
	if hotbar != null:
		hotbar.refresh()
	if window_dock != null:
		var open: Array = []
		for key in _panels:
			if _panels[key].visible:
				open.append(key)
		window_dock.mark_open(open)

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
	if panel == WINDOW_CRAFTING and _repair_feedback != null:
		_repair_feedback.text = ""
	p.visible = true
	p.position = clamp_window_position(p.position, p.size, _viewport_size())
	refresh_all()

func close_window(panel: String) -> void:
	var p: Control = _panels.get(panel, null)
	if p == null:
		return
	p.visible = false
	_drag_key = ""
	refresh_hud()

func toggle_window(panel: String) -> void:
	if is_window_open(panel):
		close_window(panel)
	else:
		open_window(panel)

func _close_all_windows() -> void:
	for panel in _panels:
		_panels[panel].visible = false
	_drag_key = ""
	refresh_hud()

func refresh_all() -> void:
	refresh_inventory()
	refresh_crafting()
	refresh_technology()
	refresh_market()
	refresh_proposals()
	refresh_trade()
	refresh_character()
	refresh_hud()

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

## Where a dragged window may sit: at least DRAG_VISIBLE_MARGIN px of it stays
## inside the viewport on every edge, and the title bar (top) never leaves the
## screen, so a window can never be dragged fully off-screen.
static func clamp_window_position(pos: Vector2, window_size: Vector2, viewport: Vector2) -> Vector2:
	var min_x := DRAG_VISIBLE_MARGIN - window_size.x
	var max_x := maxf(min_x, viewport.x - DRAG_VISIBLE_MARGIN)
	var max_y := maxf(0.0, viewport.y - DRAG_VISIBLE_MARGIN)
	return Vector2(clampf(pos.x, min_x, max_x), clampf(pos.y, 0.0, max_y))

## Where a stored window sits so it is wholly inside the viewport (top-left pinned if it is
## larger than the viewport). Stricter than `clamp_window_position`, which only keeps a margin
## of a dragged window on screen.
static func fit_window_position(pos: Vector2, window_size: Vector2, viewport: Vector2) -> Vector2:
	return Vector2(clampf(pos.x, 0.0, maxf(0.0, viewport.x - window_size.x)),
		clampf(pos.y, 0.0, maxf(0.0, viewport.y - window_size.y)))

## Parse a stored layout. Malformed JSON, unknown window keys and non-numeric
## entries are dropped, so a hand-edited or stale file cannot inject state.
static func parse_layout(text: String) -> Dictionary:
	var out: Dictionary = {}
	# Instance parse() returns an error code instead of printing one to the log.
	var json := JSON.new()
	if json.parse(text) != OK:
		return out
	var parsed = json.data
	if not (parsed is Dictionary):
		return out
	for key in WINDOW_KEYS:
		var v = parsed.get(key, null)
		if v is Array and v.size() == 2 and (v[0] is float or v[0] is int) and (v[1] is float or v[1] is int):
			var pos := Vector2(float(v[0]), float(v[1]))
			# NaN/inf or an absurd magnitude from a hand-edited file would poison clamp; skip the entry.
			if is_finite(pos.x) and is_finite(pos.y) and absf(pos.x) <= LAYOUT_MAX_COORD and absf(pos.y) <= LAYOUT_MAX_COORD:
				out[key] = pos
	return out

static func layout_to_json(layout: Dictionary) -> String:
	var d: Dictionary = {}
	for key in WINDOW_KEYS:
		if layout.has(key):
			var v: Vector2 = layout[key]
			d[key] = [v.x, v.y]
	return JSON.stringify(d)

## Canonical overlay key for an item's icon. Derivation only: the overlay
## decides at fill time whether a pack or the public placeholder answers.
static func item_icon_key(item_id: String) -> String:
	return ICON_KEY_FORMAT % item_id

## First glyph of the item name, painted when no icon asset exists.
static func item_glyph(item_id: String) -> String:
	return item_id.substr(0, 1).to_upper() if item_id != "" else "?"

## Right-click actions an item supports. Only intents that already exist on the
## bus are offered; today that is repair (a held, non-pristine item with a
## fabric repair spec). Each entry: { action, label }.
## `repairable` (item id -> true) may be passed to avoid recomputing
## `repair_rows()` for every item; null means compute it here.
func item_actions(item_id: String, repairable = null) -> Array:
	if repairable == null:
		repairable = {}
		for r in repair_rows():
			repairable[str(r["id"])] = true
	var actions: Array = []
	if repairable.has(item_id):
		actions.append({"action": "repair", "label": "Repair"})
	var slot := EquipmentRules.slot_of(item_id, GameData.ITEMS)
	# An item already on the avatar offers Unequip in the Character window, not Equip.
	if slot != "" and character_slice != null and str(_local_worn().get(slot, "")) != item_id:
		actions.append({"action": "equip", "label": "Equip (%s)" % slot})
	return actions

## The bus intent an action maps to: { signal, args }, or {} for an unknown action.
static func action_intent(item_id: String, action: String) -> Dictionary:
	match action:
		"repair":
			return {"signal": "repair_requested", "args": [item_id]}
		"equip":
			return {"signal": "equip", "args": [item_id]}
		"unequip":
			return {"signal": "unequip", "args": [item_id]}
	return {}

## Emit the bus intent for an item action. Returns false for an unknown action.
func dispatch_item_action(item_id: String, action: String) -> bool:
	var intent := action_intent(item_id, action)
	if intent.is_empty():
		return false
	match str(intent["signal"]):
		"repair_requested":
			GameBus.repair_requested.emit(item_id)
		"equip", "unequip":
			return _dispatch_equipment(str(intent["signal"]), item_id)
		_:
			return false
	return true

## Phase 47 — equip / unequip on the local avatar. `apply_equipment` and
## `clear_equipment` stay the only mutation path; the slot is the fabric's.
func _dispatch_equipment(kind: String, item_id: String) -> bool:
	if character_slice == null:
		return false
	var char_id := str(character_slice.get_player_character())
	var slot := EquipmentRules.slot_of(item_id, GameData.ITEMS)
	if char_id == "" or slot == "":
		return false
	if kind == "equip":
		# Only what the bag holds can be worn; the host would drop the claim anyway, and
		# wearing it here first would leave this client showing gear the host disowns.
		if inventory_slice == null or int(inventory_slice.get_item_count(item_id)) <= 0:
			return false
		return bool(character_slice.apply_equipment(char_id, slot, item_id))
	return bool(character_slice.clear_equipment(char_id, slot))

## Phase 47 — one row per fabric `equipmentSlot` (sorted): { slot, item, icon_key,
## tooltip, actions }. `item` is "" for an empty slot.
func character_rows() -> Array:
	var worn := _local_worn()
	var rows: Array = []
	for slot in EquipmentRules.slots(GameData.ITEMS):
		var item := str(worn.get(slot, ""))
		rows.append({
			"slot": slot,
			"item": item,
			"icon_key": item_icon_key(item) if item != "" else "",
			"tooltip": ("%s: %s" % [slot, item_description(item)]) if item != "" else "%s: empty" % slot,
			"actions": [{"action": "unequip", "label": "Unequip"}] if item != "" else [],
		})
	return rows

## The Character window's totals line, summed from fabric values only.
func character_stats_text() -> String:
	var totals := EquipmentRules.totals(_local_worn(), GameData.ITEMS)
	return "Defense %d" % int(totals.get("defense", 0))

func _local_worn() -> Dictionary:
	if character_slice == null:
		return {}
	var char_id := str(character_slice.get_player_character())
	if char_id == "":
		return {}
	return character_slice.get_equipment_set(char_id)

## Fabric description of an item ("" when the item has no definition).
static func item_description(item_id: String) -> String:
	var res: Resource = GameData.ITEMS.get(item_id, null)
	if res == null:
		return ""
	var d = res.get("description")
	return str(d) if d != null else ""

## One row per carried item for the slot grid: { id, quantity, durability,
## icon_key, tooltip, actions }, sorted by key. `inventory_lines()` stays the
## text projection; this is the structured one the grid is built from.
func inventory_rows() -> Array:
	var rows: Array = []
	if inventory_slice == null:
		return rows
	var contents: Dictionary = inventory_slice.get_contents()
	var keys: Array = contents.keys()
	keys.sort()
	var repairable := {}
	for r in repair_rows():
		repairable[str(r["id"])] = true
	for item_id in keys:
		var iid := str(item_id)
		var qty := int(contents[item_id])
		var dur := durability_bar(iid).strip_edges()
		var tip := "%s\nQuantity: %d" % [iid, qty]
		if dur != "":
			tip += "\nDurability: %s" % dur.trim_prefix("[").trim_suffix("]")
		var desc := item_description(iid)
		if desc != "":
			tip += "\n" + desc
		rows.append({
			"id": iid,
			"quantity": qty,
			"durability": dur,
			"icon_key": item_icon_key(iid),
			"tooltip": tip,
			"actions": item_actions(iid, repairable),
		})
	return rows

## The `?` legend, moved here from the always-on HUD panel. Each row:
## { keys, desc, mouse } where `mouse` is a MouseButton for a drawn cue, or 0.
static func controls_rows() -> Array:
	return [
		{"keys": "WASD", "desc": "Move", "mouse": 0},
		{"keys": "Space", "desc": "Jump", "mouse": 0},
		{"keys": "Hold", "desc": "Look around (the cursor hides while held)", "mouse": MOUSE_BUTTON_RIGHT},
		{"keys": "Scroll", "desc": "Zoom", "mouse": 0},
		{"keys": "1 – 9", "desc": "Use the box on the bottom row (a block, gear or a skill)", "mouse": 0},
		{"keys": "▴", "desc": "Expand the bottom bar: drag items and skills in, right-click a box to choose its key", "mouse": 0},
		{"keys": "Drag", "desc": "Inventory item onto a box, or onto the ground to drop it (Shift: whole stack)", "mouse": 0},
		{"keys": "", "desc": "Click: Attack / Pick up / Chop", "mouse": MOUSE_BUTTON_LEFT},
		{"keys": "Shift +", "desc": "Mine", "mouse": MOUSE_BUTTON_LEFT},
		{"keys": "", "desc": "Place", "mouse": MOUSE_BUTTON_MIDDLE},
		{"keys": "R", "desc": "Next placeable block", "mouse": 0},
		{"keys": "B · V", "desc": "Station cycle / place", "mouse": 0},
		{"keys": "G", "desc": "Tame nearest creature (G is shared with Proposals)", "mouse": 0},
		{"keys": "E", "desc": "Toggle equipment", "mouse": 0},
		{"keys": "I · C · H · T · Y · P · G", "desc": "Inventory · Character · Crafting · Tech · Trade · Market · Proposals (or click the boxes under your health)", "mouse": 0},
		{"keys": "?", "desc": "This panel", "mouse": 0},
		{"keys": "Enter · /", "desc": "Chat and commands (/help)", "mouse": 0},
		{"keys": "ESC", "desc": "Close windows", "mouse": 0},
	]

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

## One row per held repairable item: { id, can_repair, reason, station, materials }.
## Only durable items that have a fabric repair spec AND are currently held AND
## are not pristine are listed — a pristine item needs no repair, and stackable
## materials have no repair spec.
func repair_rows() -> Array:
	var rows: Array = []
	if crafting_slice == null or inventory_slice == null:
		return rows
	var ids: Array = inventory_slice.get_contents().keys()
	ids.sort()
	for item_id in ids:
		var iid := str(item_id)
		var spec: Dictionary = crafting_slice.get_repair_spec(iid)
		if spec.is_empty():
			continue
		var check: Dictionary = crafting_slice.can_repair(iid, spec)
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
			"materials": _fmt_entries(spec.get("materials", [])),
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

## Sorted list of inventory item ids currently held (feeds the market "list"
## item selector). Empty when no inventory is wired.
func listable_items() -> Array:
	var out: Array = []
	if inventory_slice == null:
		return out
	var contents: Dictionary = inventory_slice.get_contents()
	for item_id in contents:
		if int(contents[item_id]) > 0:
			out.append(str(item_id))
	out.sort()
	return out

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

## A row removed from a grid is `queue_free`d (it may be the control whose signal is running), but it
## has no parent until that lands, so the slice keeps it: freed with the slice if the frame never
## comes (a `--quit` boot, the test suite) rather than left an orphan. Owner: this slice.
var _retired: Array = []
## Freed entries are filtered out only once the list reaches this size, then it doubles from what
## survived, so a burst of N retirements prunes O(log N) times instead of rescanning on every call.
const RETIRED_PRUNE_MIN := 8
var _retired_prune_at: int = RETIRED_PRUNE_MIN
## How many times `_retire` has pruned, for the tests.
var retired_prunes: int = 0

func _retire(c: Node) -> void:
	c.queue_free()
	_retired.append(c)
	if _retired.size() >= _retired_prune_at:
		_retired = _retired.filter(func(n): return is_instance_valid(n))
		retired_prunes += 1
		_retired_prune_at = maxi(RETIRED_PRUNE_MIN, _retired.size() * 2)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_on_drag_end()
	elif what == NOTIFICATION_PREDELETE:
		for n in _retired:
			if is_instance_valid(n):
				n.free()
		_retired.clear()

func refresh_inventory() -> void:
	if _inventory_grid == null:
		return
	_inventory_usage.text = inventory_usage_text()
	for c in _inventory_grid.get_children():
		_inventory_grid.remove_child(c)
		_retire(c)
	var rows: Array = inventory_rows()
	_inventory_empty.visible = rows.is_empty()
	for row in rows:
		_inventory_grid.add_child(_make_slot(row))

## Icons resolve here, at fill time: caching the texture per item would paint a
## placeholder over real art once a pack mounts (or the reverse).
func _make_slot(row: Dictionary) -> Control:
	var slot := Button.new()
	slot.custom_minimum_size = SLOT_SIZE
	slot.tooltip_text = str(row["tooltip"])
	slot.clip_text = true
	var tex: Texture2D = _load_item_icon(str(row["icon_key"]))
	if tex != null:
		slot.icon = tex
		slot.expand_icon = true
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		slot.text = "×%d" % int(row["quantity"])
	else:
		slot.text = "%s\n×%d" % [item_glyph(str(row["id"])), int(row["quantity"])]
	if str(row["durability"]).contains(" "):
		slot.modulate = Color(1.0, 0.9, 0.8)
	slot.gui_input.connect(_on_slot_gui_input.bind(str(row["id"]), row["actions"]))
	slot.set_drag_forwarding(_inventory_drag.bind(str(row["id"]), int(row["quantity"]), slot), Callable(), Callable())
	return slot

func _load_item_icon(key: String) -> Texture2D:
	var path := AssetOverlay.resolve_path(key)
	if _icon_cache.has(path):
		return _icon_cache[path]
	var tex: Texture2D = null
	if FileAccess.file_exists(path):
		tex = AssetOverlay.load_texture(key)
	_icon_cache[path] = tex
	return tex

func _on_slot_gui_input(event: InputEvent, item_id: String, actions: Array) -> void:
	if not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_RIGHT:
		return
	if actions.is_empty() or _slot_menu == null:
		return
	_slot_menu.clear()
	_slot_menu_item = item_id
	_slot_menu_actions = actions
	for i in actions.size():
		_slot_menu.add_item(str(actions[i]["label"]), i)
	_slot_menu.position = Vector2i(get_viewport().get_mouse_position())
	_slot_menu.popup()

func _on_slot_menu_pressed(index: int) -> void:
	if index < 0 or index >= _slot_menu_actions.size():
		return
	# No refresh here: a worn-set change emits `character_appearance_changed`, which is what
	# redraws the window, and an action that changed nothing has nothing to redraw.
	dispatch_item_action(_slot_menu_item, str(_slot_menu_actions[index]["action"]))

## Only the local avatar's gear is shown in the Character window; NPC changes are noise.
func _on_character_appearance_changed(iid: String, _appearance: Dictionary) -> void:
	if character_slice == null or str(iid) == str(character_slice.get_player_character()):
		refresh_character()

## The friend-code line of the Character window. Pure.
static func friend_code_text(handle: String) -> String:
	return "Friend code: %s" % (handle if handle != "" else "(not assigned yet)")

func set_own_handle(handle: String) -> void:
	own_handle = handle
	if _friend_code_label != null:
		_friend_code_label.text = friend_code_text(handle)

func _on_copy_friend_code_pressed() -> void:
	if own_handle != "":
		DisplayServer.clipboard_set(own_handle)

func _on_spawn_notice(message: String) -> void:
	if _spawn_notice_label != null:
		_spawn_notice_label.text = message

## Phase 71 — the host's world record came from another generator version.
func _on_worldgen_version_mismatch(recorded: int, running: int) -> void:
	if _worldgen_notice_label != null:
		_worldgen_notice_label.text = "World saved with generator v%d, running v%d: terrain may not match saved edits." % [recorded, running]

## One row per skill the player has, best tier first: { id, tier, tooltip }. Pure given the table.
static func skills_rows(tiers: Dictionary) -> Array:
	var rows: Array = []
	for skill in HotbarScript.ordered_skills(tiers):
		rows.append({"id": skill, "tier": str(tiers[skill]), "tooltip": "%s (%s)\nDrag onto the bottom bar to use it with a key" % [skill, tiers[skill]]})
	return rows

func _refresh_skills() -> void:
	if _skills_grid == null:
		return
	var rows := skills_rows(crafting_slice.get_skills() if crafting_slice != null else {})
	if rows.hash() == _skills_signature and _skills_grid.get_child_count() > 0:
		return
	_skills_signature = rows.hash()
	for c in _skills_grid.get_children():
		_skills_grid.remove_child(c)
		_retire(c)
	for row in rows:
		var b := Button.new()
		b.custom_minimum_size = Vector2(SLOT_SIZE.x, 48.0)
		b.clip_text = true
		b.text = "%s\n%s" % [str(row["id"]).substr(0, 8), str(row["tier"])]
		b.add_theme_font_size_override("font_size", 12)
		b.tooltip_text = str(row["tooltip"])
		b.set_drag_forwarding(_skill_drag.bind(str(row["id"]), b), Callable(), Callable())
		_skills_grid.add_child(b)

func refresh_character() -> void:
	if _character_grid == null:
		return
	_refresh_skills()
	_character_stats.text = character_stats_text()
	# An appearance change that left the worn set alone (a palette tweak, a LOD swap)
	# produces the same rows; rebuilding the whole grid for it is wasted work.
	var rows := character_rows()
	var signature: int = rows.hash()
	if signature == _character_rows_signature and _character_grid.get_child_count() > 0:
		return
	_character_rows_signature = signature
	for c in _character_grid.get_children():
		_character_grid.remove_child(c)
		_retire(c)
	for row in rows:
		var slot := Button.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.tooltip_text = str(row["tooltip"])
		slot.clip_text = true
		var tex: Texture2D = _load_item_icon(str(row["icon_key"])) if str(row["icon_key"]) != "" else null
		if tex != null:
			slot.icon = tex
			slot.expand_icon = true
			slot.text = str(row["slot"])
		else:
			slot.text = "%s\n%s" % [row["slot"], item_glyph(str(row["item"])) if str(row["item"]) != "" else "—"]
		slot.gui_input.connect(_on_slot_gui_input.bind(str(row["item"]), row["actions"]))
		_character_grid.add_child(slot)

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

	# Repair section: one row per held, repairable, non-pristine item.
	var repair_rows_list: Array = repair_rows()
	if not repair_rows_list.is_empty():
		var sep := Label.new()
		sep.text = "— Repairs —"
		sep.add_theme_font_size_override("font_size", 14)
		sep.modulate = Color(0.75, 0.75, 0.75)
		_crafting_box.add_child(sep)
		for row in repair_rows_list:
			var r: Dictionary = row
			var hbox := HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 8)
			var btn := Button.new()
			btn.text = "Repair"
			btn.disabled = not bool(r["can_repair"])
			btn.pressed.connect(_on_repair_pressed.bind(str(r["id"])))
			hbox.add_child(btn)
			var line := str(r["id"])
			if str(r.get("station", "")) != "":
				line += "  @ %s" % r["station"]
			line += "  needs: %s" % r["materials"]
			var lbl := Label.new()
			lbl.text = line + ("" if bool(r["can_repair"]) else "  (%s)" % r["reason"])
			lbl.modulate = Color(1, 1, 1) if bool(r["can_repair"]) else Color(0.6, 0.6, 0.6)
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
	if _market_box != null:
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
	_refresh_market_item_selector()

func _refresh_market_item_selector() -> void:
	if _market_item_select == null:
		return
	var selected: int = _market_item_select.selected
	_market_item_select.clear()
	for item_id in listable_items():
		_market_item_select.add_item(str(item_id))
	if _market_item_select.item_count > 0:
		_market_item_select.selected = clampi(selected, 0, _market_item_select.item_count - 1)

func refresh_proposals() -> void:
	if _proposal_box == null:
		return
	for child in _proposal_box.get_children():
		child.queue_free()
	for row in proposal_rows():
		var r: Dictionary = row
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		var lbl := Label.new()
		lbl.text = "%s [%s] %s  (for:%d / against:%d) — %s" % [r["id"], r["state"], r["title"], r["for"], r["against"], r["author"]]
		hbox.add_child(lbl)
		if str(r["state"]) == "proposed":
			var for_btn := Button.new()
			for_btn.text = "For"
			for_btn.pressed.connect(_on_proposal_vote_pressed.bind(str(r["id"]), "for"))
			hbox.add_child(for_btn)
			var against_btn := Button.new()
			against_btn.text = "Against"
			against_btn.pressed.connect(_on_proposal_vote_pressed.bind(str(r["id"]), "against"))
			hbox.add_child(against_btn)
		_proposal_box.add_child(hbox)

func refresh_trade() -> void:
	if _trade_status == null:
		return
	_trade_status.text = _trade_status_text()

## Human-readable summary of the active trade session, or a prompt when none is
## open. Pure projection so it is testable without a scene tree.
func _trade_status_text() -> String:
	if trade_slice == null:
		return "Trade is unavailable (no trade slice wired)."
	if _active_trade_id == "":
		return "No active trade. Click \"Start trade\" to open a session with the merchant."
	var t: Dictionary = trade_slice.get_trade(_active_trade_id)
	if t.is_empty():
		return "Trade session ended."
	var state: String = str(t.get("state", "pending"))
	if state == "completed":
		return "Trade completed — the merchant's goods were added to your inventory (less the Trade broker fee)."
	if state == "rejected":
		return "Trade rejected."
	return "Trade %s open — click \"Accept trade\" to complete the exchange." % _active_trade_id

# ---------------------------------------------------------------------------
# Bus handlers
# ---------------------------------------------------------------------------

func _on_craft_pressed(recipe_id: String) -> void:
	GameBus.craft_requested.emit(recipe_id)

func _on_repair_pressed(item_id: String) -> void:
	GameBus.repair_requested.emit(item_id)

func _on_research_pressed(tech_id: String) -> void:
	GameBus.research_requested.emit(tech_id)

func _on_close_pressed(panel: String) -> void:
	close_window(panel)

func _on_craft_resolved(result: Dictionary) -> void:
	# Phase 34 — gated like the repair/research feedback below: a listen host resolves
	# crafts for remote peers too, and their outcome must not clear the local player's
	# repair feedback label.
	if _repair_feedback != null and _belongs_to_local_player(result):
		_repair_feedback.text = ""
	refresh_crafting()
	refresh_inventory()

func _on_repair_resolved(result: Dictionary) -> void:
	if _repair_feedback != null and _belongs_to_local_player(result):
		if result.get("success", false):
			_repair_feedback.text = "Repaired %s." % result.get("item_id", "?")
		else:
			_repair_feedback.text = "%s: %s" % [result.get("item_id", "?"), result.get("reason", "?")]
	refresh_crafting()
	refresh_inventory()

func _on_research_resolved(result: Dictionary) -> void:
	if _technology_feedback != null and _belongs_to_local_player(result):
		if result.get("success", false):
			_technology_feedback.text = "Researching %s…" % result.get("tech_id", "?")
		else:
			_technology_feedback.text = "%s: %s" % [result.get("tech_id", "?"), result.get("reason", "?")]
	refresh_technology()

func _on_technology_unlocked(_tech_id: String, _player_id: String) -> void:
	refresh_technology()
	refresh_crafting()

## Whether a resolved action concerns THIS machine's player. A listen host resolves
## craft / repair / research for remote peers too (Phase 34), and their outcome must
## not be reported in the local player's feedback labels.
func _belongs_to_local_player(result: Dictionary) -> bool:
	var pid := str(result.get("player_id", ""))
	if pid == "":
		return true
	if technology_slice != null and technology_slice.has_method("local_player_id"):
		return pid == str(technology_slice.local_player_id())
	return true

func _on_item_picked_up(_item_id: String, _quantity: int) -> void:
	refresh_inventory()
	refresh_hud()

func _on_inventory_changed() -> void:
	refresh_inventory()
	refresh_hud()
	refresh_crafting()
	_refresh_market_item_selector()

func _on_block_mined(_material: String, _quantity: int, _position: Vector3) -> void:
	refresh_inventory()
	refresh_hud()

func _on_block_placed(_material: String, _position: Vector3) -> void:
	refresh_inventory()

func _on_market_listing_created(_listing_id: String, _seller: String, _item_id: String, _quantity: int, _price: float) -> void:
	refresh_market()

func _on_market_listing_purchased(_listing_id: String, _buyer: String, _item_id: String, _quantity: int) -> void:
	refresh_market()

func _on_market_listing_expired(_listing_id: String) -> void:
	refresh_market()

func _on_proposal_submitted(_proposal_id: String) -> void:
	refresh_proposals()

func _on_proposal_ratified(_proposal_id: String, _title: String) -> void:
	refresh_proposals()

func _on_market_buy_pressed(listing_id: String) -> void:
	if market_slice != null:
		market_slice.buy(listing_id, "player")
	refresh_market()
	refresh_inventory()

func _on_trade_start_pressed() -> void:
	if trade_slice == null:
		return
	_active_trade_id = trade_slice.start_trade("player", "merchant")
	# The merchant proposes a fixed offer (10 hawk feathers, wants nothing) and
	# accepts; the player completes the exchange with "Accept trade".
	trade_slice.propose(_active_trade_id, "merchant", { "hawk_feather": 10 }, {})
	trade_slice.accept(_active_trade_id, "merchant")
	refresh_trade()

func _on_trade_accept_pressed() -> void:
	if trade_slice == null or _active_trade_id == "":
		return
	trade_slice.propose(_active_trade_id, "player", {}, { "hawk_feather": 10 })
	trade_slice.accept(_active_trade_id, "player")
	refresh_trade()
	refresh_inventory()

func _on_market_list_pressed() -> void:
	if market_slice == null or _market_item_select == null:
		return
	if _market_item_select.item_count == 0:
		return
	var item_id: String = _market_item_select.get_item_text(_market_item_select.selected)
	var qty: int = int(_market_qty.text) if _market_qty != null else 1
	var price: float = float(_market_price.text) if _market_price != null else 1.0
	if qty <= 0:
		qty = 1
	if price < 0.0:
		price = 0.0
	var id: String = market_slice.list_item("player", item_id, qty, price)
	if _market_feedback != null:
		if id != "":
			_market_feedback.text = "Listed %s ×%d @ %.2f." % [item_id, qty, price]
		else:
			_market_feedback.text = "Couldn't list %s — check you hold the quantity." % item_id
	refresh_market()

func _on_proposal_submit_pressed() -> void:
	if proposal_slice == null:
		return
	var title := _proposal_title.text if _proposal_title != null else ""
	var body := _proposal_body.text if _proposal_body != null else ""
	if title.strip_edges() == "":
		return
	proposal_slice.submit_proposal("player", title, body)
	_proposal_title.text = ""
	_proposal_body.text = ""
	if _proposal_feedback != null:
		_proposal_feedback.text = "Proposal submitted. Other players can now vote."
	refresh_proposals()

func _on_proposal_vote_pressed(proposal_id: String, verdict: String) -> void:
	if proposal_slice == null:
		return
	var result: Dictionary = proposal_slice.vote(proposal_id, "player", verdict)
	if _proposal_feedback != null:
		if result.get("success", true):
			_proposal_feedback.text = "Vote cast."
		else:
			_proposal_feedback.text = "Vote rejected: %s" % result.get("reason", "?")
	refresh_proposals()

# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "Windows"
	_ui.layer = 30
	add_child(_ui)
	# Built first so every window draws above the HUD.
	_build_hud()

	_panels[WINDOW_INVENTORY] = _build_window(WINDOW_INVENTORY, "Inventory", _build_inventory_content(), Vector2(24, 24))
	_panels[WINDOW_TECHNOLOGY] = _build_window(WINDOW_TECHNOLOGY, "Technology", _build_technology_content(), Vector2(470, 24))
	_panels[WINDOW_CRAFTING] = _build_window(WINDOW_CRAFTING, "Crafting (H)", _build_crafting_content(), Vector2(24, 360))
	_panels[WINDOW_TRADE] = _build_window(WINDOW_TRADE, "Trade", _build_trade_content(), Vector2(470, 360))
	_panels[WINDOW_MARKET] = _build_window(WINDOW_MARKET, "Market (P)", _build_market_content(), Vector2(24, 700))
	_panels[WINDOW_PROPOSALS] = _build_window(WINDOW_PROPOSALS, "Proposals", _build_proposals_content(), Vector2(470, 700))
	_panels[WINDOW_CONTROLS] = _build_window(WINDOW_CONTROLS, "Controls (?)", _build_controls_content(), Vector2(916, 24))

	_panels[WINDOW_CHARACTER] = _build_window(WINDOW_CHARACTER, "Character (C)", _build_character_content(), Vector2(916, 360))

	_slot_menu = PopupMenu.new()
	_slot_menu.id_pressed.connect(_on_slot_menu_pressed)
	_ui.add_child(_slot_menu)
	_load_layout()
	_apply_layout()
	# The panels have no real size until their first layout pass: re-fit once it has run.
	_apply_layout.call_deferred()
	# A viewport resize (window drag, fullscreen toggle) re-fits too.
	if is_inside_tree() and not get_viewport().size_changed.is_connected(_apply_layout):
		get_viewport().size_changed.connect(_apply_layout)

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
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.mouse_default_cursor_shape = Control.CURSOR_MOVE
	bar.gui_input.connect(_on_title_gui_input.bind(key))
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

# ---------------------------------------------------------------------------
# Window drag + layout persistence
# ---------------------------------------------------------------------------

## Test seam: a non-zero value stands in for the viewport size.
var viewport_size_override := Vector2.ZERO

func _viewport_size() -> Vector2:
	if viewport_size_override != Vector2.ZERO:
		return viewport_size_override
	if is_inside_tree():
		return get_viewport().get_visible_rect().size
	return Vector2(1280, 720)

## ONE handler for every window's title bar: press grabs, motion moves, release
## stores the position.
func _on_title_gui_input(event: InputEvent, key: String) -> void:
	var panel: Control = _panels.get(key, null)
	if panel == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_key = key
			_drag_moved = false
			_drag_grab = panel.get_global_mouse_position() - panel.position
		elif _drag_key == key:
			_drag_key = ""
			if _drag_moved:
				_layout[key] = panel.position
				_save_layout()
	elif event is InputEventMouseMotion and _drag_key == key:
		if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_drag_key = ""
			return
		_drag_moved = true
		panel.position = clamp_window_position(
			panel.get_global_mouse_position() - _drag_grab, panel.size, _viewport_size())

func _load_layout() -> void:
	_layout = {}
	if FileAccess.file_exists(layout_path):
		_layout = parse_layout(FileAccess.get_file_as_string(layout_path))

func _save_layout() -> void:
	# Write a temp file then rename, so a crash mid-write cannot truncate the layout.
	var tmp_path := layout_path + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		Diag.warn("[UiSlice] cannot write %s" % tmp_path)
		return
	f.store_string(layout_to_json(_layout))
	f.close()
	if DirAccess.rename_absolute(tmp_path, layout_path) != OK:
		Diag.warn("[UiSlice] cannot replace %s" % layout_path)
		DirAccess.remove_absolute(tmp_path)

## Put every stored window where it lies fully inside the viewport. Runs once at build and again
## after the first layout pass, when the panels' real sizes are known.
func _apply_layout() -> void:
	for key in _layout:
		var panel: Control = _panels.get(key, null)
		if panel != null:
			panel.position = fit_window_position(_layout[key], panel.custom_minimum_size.max(panel.size), _viewport_size())

func _build_controls_content() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	for row in controls_rows():
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		if int(row["mouse"]) != 0:
			var holder := CenterContainer.new()
			holder.custom_minimum_size = Vector2(56, 30)
			var icon: Control = MouseIconScript.new()
			icon.button = int(row["mouse"])
			icon.custom_minimum_size = Vector2(20, 30)
			holder.add_child(icon)
			line.add_child(holder)
		else:
			var key_label := Label.new()
			key_label.text = str(row["keys"])
			key_label.add_theme_font_size_override("font_size", 15)
			key_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			key_label.custom_minimum_size = Vector2(90, 0)
			line.add_child(key_label)
		var desc := Label.new()
		desc.text = str(row["desc"])
		desc.add_theme_font_size_override("font_size", 15)
		line.add_child(desc)
		box.add_child(line)
	return box

func _build_inventory_content() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_inventory_usage = Label.new()
	_inventory_usage.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_inventory_usage)
	_inventory_empty = Label.new()
	_inventory_empty.text = "(empty)"
	vbox.add_child(_inventory_empty)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_inventory_grid = GridContainer.new()
	_inventory_grid.columns = INVENTORY_COLUMNS
	scroll.add_child(_inventory_grid)
	return vbox

func _build_character_content() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_character_stats = Label.new()
	_character_stats.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_character_stats)
	# Phase 53 — the friend code: the handle another player enters to spawn beside this one.
	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 6)
	_friend_code_label = Label.new()
	_friend_code_label.text = friend_code_text(own_handle)
	code_row.add_child(_friend_code_label)
	var copy_btn := Button.new()
	copy_btn.text = "Copy"
	copy_btn.pressed.connect(_on_copy_friend_code_pressed)
	code_row.add_child(copy_btn)
	vbox.add_child(code_row)
	_spawn_notice_label = Label.new()
	_spawn_notice_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_spawn_notice_label)
	_worldgen_notice_label = Label.new()
	_worldgen_notice_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_worldgen_notice_label)
	_character_grid = GridContainer.new()
	_character_grid.columns = INVENTORY_COLUMNS
	vbox.add_child(_character_grid)
	var skills_title := Label.new()
	skills_title.text = "Skills — drag one onto the bottom bar"
	skills_title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(skills_title)
	_skills_grid = GridContainer.new()
	_skills_grid.columns = INVENTORY_COLUMNS
	vbox.add_child(_skills_grid)
	return vbox

func _build_crafting_content() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_repair_feedback = Label.new()
	_repair_feedback.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_repair_feedback)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_crafting_box = VBoxContainer.new()
	_crafting_box.add_theme_constant_override("separation", 4)
	_crafting_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_crafting_box)
	vbox.add_child(scroll)
	return vbox

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
	lbl.text = "Player-to-player trade with the merchant. Your Trade tier lowers the broker fee on received goods."
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl)
	var start_btn := Button.new()
	start_btn.text = "Start trade"
	start_btn.pressed.connect(_on_trade_start_pressed)
	vbox.add_child(start_btn)
	var accept_btn := Button.new()
	accept_btn.text = "Accept trade"
	accept_btn.pressed.connect(_on_trade_accept_pressed)
	vbox.add_child(accept_btn)
	_trade_status = Label.new()
	_trade_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trade_status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_trade_status)
	return vbox

func _build_market_content() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	var list_lbl := Label.new()
	list_lbl.text = "List an item for sale (item · qty · price):"
	vbox.add_child(list_lbl)
	var list_row := HBoxContainer.new()
	list_row.add_theme_constant_override("separation", 6)
	_market_item_select = OptionButton.new()
	_market_item_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_row.add_child(_market_item_select)
	_market_qty = LineEdit.new()
	_market_qty.text = "1"
	_market_qty.custom_minimum_size = Vector2(40, 0)
	list_row.add_child(_market_qty)
	_market_price = LineEdit.new()
	_market_price.text = "1.0"
	_market_price.custom_minimum_size = Vector2(50, 0)
	list_row.add_child(_market_price)
	var list_btn := Button.new()
	list_btn.text = "List"
	list_btn.pressed.connect(_on_market_list_pressed)
	list_row.add_child(list_btn)
	vbox.add_child(list_row)
	_market_feedback = Label.new()
	_market_feedback.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_market_feedback)
	var browse_lbl := Label.new()
	browse_lbl.text = "Available listings:"
	vbox.add_child(browse_lbl)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_market_box = VBoxContainer.new()
	_market_box.add_theme_constant_override("separation", 4)
	_market_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_market_box)
	vbox.add_child(scroll)
	return vbox

func _build_proposals_content() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	_proposal_title = LineEdit.new()
	_proposal_title.placeholder_text = "Proposal title"
	_proposal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_proposal_title)
	var submit_btn := Button.new()
	submit_btn.text = "Submit"
	submit_btn.pressed.connect(_on_proposal_submit_pressed)
	title_row.add_child(submit_btn)
	vbox.add_child(title_row)
	_proposal_body = LineEdit.new()
	_proposal_body.placeholder_text = "Proposal body (optional)"
	vbox.add_child(_proposal_body)
	_proposal_feedback = Label.new()
	_proposal_feedback.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_proposal_feedback)
	var list_lbl := Label.new()
	list_lbl.text = "Proposals:"
	vbox.add_child(list_lbl)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_proposal_box = VBoxContainer.new()
	_proposal_box.add_theme_constant_override("separation", 4)
	_proposal_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_proposal_box)
	vbox.add_child(scroll)
	return vbox

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _fmt_entries(entries: Array) -> String:
	var parts: Array = []
	for e in entries:
		parts.append("%s ×%d" % [str(e.get("item", "")), int(e.get("quantity", 1))])
	return ", ".join(parts)
