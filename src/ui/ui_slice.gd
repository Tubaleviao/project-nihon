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
const I18n := preload("res://src/core/i18n.gd")
const LocaleSettings := preload("res://src/core/locale_settings.gd")

const WINDOW_INVENTORY  := "inventory"
const WINDOW_TECHNOLOGY := "technology"
const WINDOW_CRAFTING   := "crafting"
const WINDOW_TRADE      := "trade"
const WINDOW_MARKET     := "market"
const WINDOW_PROPOSALS  := "proposals"
const WINDOW_CONTROLS   := "controls"
const WINDOW_CHARACTER  := "character"
const WINDOW_SKILLS     := "skills"
const WINDOW_MAP        := "map"
const WINDOW_SETTLEMENT := "settlement"

const WINDOW_KEYS := [
	WINDOW_INVENTORY, WINDOW_TECHNOLOGY, WINDOW_CRAFTING,
	WINDOW_TRADE, WINDOW_MARKET, WINDOW_PROPOSALS, WINDOW_CONTROLS, WINDOW_CHARACTER, WINDOW_SKILLS, WINDOW_MAP, WINDOW_SETTLEMENT,
]

const MouseIconScript := preload("res://src/ui/mouse_icon.gd")
const EquipmentRules := preload("res://src/character/equipment_rules.gd")
const HotbarScript := preload("res://src/ui/hotbar.gd")
const WindowDockScript := preload("res://src/ui/window_dock.gd")
const MapWindowScript := preload("res://src/ui/map_window.gd")
const SettlementPanelScript := preload("res://src/ui/settlement_panel.gd")

## Pixels of a window that must stay reachable on every edge when dragged.
const DRAG_VISIBLE_MARGIN := 48.0
## Largest stored window coordinate a layout file may carry; beyond it the entry is junk.
const LAYOUT_MAX_COORD := 100000.0
const LAYOUT_PATH := "user://ui_layout.json"
const ICON_KEY_FORMAT := "icons/items/%s.png.raw"
const SLOT_SIZE := Vector2(72, 72)
const INVENTORY_COLUMNS := 5

## Set by game_root after instantiation.
const UiPart1 := preload("res://src/ui/ui_part_1.gd")
const UiPart2 := preload("res://src/ui/ui_part_2.gd")
var _m2 := UiPart2.new(self)

var _m1 := UiPart1.new(self)

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
## Phase 117 — the HUD toast channel: a bounded, de-duplicated queue shown one at a time.
const TOAST_MAX := 8
const TOAST_SECONDS := 6.0
var _toast_label: Label = null
## Phase 131 — controls whose text is a catalog key: [{node, prop, key}] (see `_set_tr`).
var _bound: Array = []
var _controls_box: VBoxContainer = null
var _language_button: Button = null
var _toast_queue: Array[String] = []
var _toast_shown: String = ""
var _toast_left: float = 0.0
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
## Phase 111 — the Map window's canvas; game_root wires its terrain, player and minimap.
var map_window: Control = null
var settlement_slice: Node = null
var settlement_panel: Control = null
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
	GameBus.locale_changed.connect(_on_locale_changed)
	GameBus.craft_resolved.connect(_on_craft_resolved)
	GameBus.spawn_notice.connect(_on_spawn_notice)
	GameBus.worldgen_version_mismatch.connect(_on_worldgen_version_mismatch)
	GameBus.worldgen_fingerprint_mismatch.connect(_on_worldgen_fingerprint_mismatch)
	GameBus.repair_resolved.connect(_on_repair_resolved)
	GameBus.research_resolved.connect(_on_research_resolved)
	GameBus.research_points_synced.connect(_on_research_points_synced)
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
			KEY_K:
				toggle_window(WINDOW_SKILLS)
			KEY_M:
				toggle_window(WINDOW_MAP)
			KEY_L:
				toggle_window(WINDOW_SETTLEMENT)
			KEY_ESCAPE:
				_close_all_windows()

# ---------------------------------------------------------------------------
# HUD: hotbar / skill bar / window dock
# ---------------------------------------------------------------------------

func _build_hud() -> void:
	_m1._build_hud()

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
		_notify(I18n.t("ui.drop_blocked"))
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
	# Until the inventory is wired nothing is "held", and refresh() would empty every saved item box.
	if hotbar != null and inventory_slice != null:
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

## Phase 131 — set a control's text from a catalog key and remember it, so a language switch can
## re-apply it. `prop` is the property name ("text", "tooltip_text", "placeholder_text").
func _set_tr(ctrl: Control, prop: String, key: String) -> void:
	ctrl.set(prop, I18n.t(key))
	_bound.append({"node": ctrl, "prop": prop, "key": key})

## The language changed: re-apply every bound control, rebuild the data-driven lists and the controls
## panel, and refresh the HUD, so no window needs a restart.
func _on_locale_changed(_locale: String) -> void:
	for b in _bound:
		if is_instance_valid(b["node"]):
			(b["node"] as Control).set(b["prop"], I18n.t(b["key"]))
	_refill_controls()
	if hotbar != null:
		hotbar.relocalize()
	if window_dock != null:
		window_dock.relocalize()
	if _friend_code_label != null:
		_friend_code_label.text = friend_code_text(own_handle)
	refresh_all()

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
		var pos = layout_entry(parsed.get(key, null))
		if pos != null:
			out[key] = pos
	return out

## One saved window position: a Vector2 for a two-number array of sane finite values, else null.
## NaN/inf or an absurd magnitude from a hand-edited file would poison clamp, so it is skipped.
static func layout_entry(v: Variant) -> Variant:
	if v is Array and v.size() == 2 and (v[0] is float or v[0] is int) and (v[1] is float or v[1] is int):
		var pos := Vector2(float(v[0]), float(v[1]))
		if is_finite(pos.x) and is_finite(pos.y) and absf(pos.x) <= LAYOUT_MAX_COORD and absf(pos.y) <= LAYOUT_MAX_COORD:
			return pos
	return null

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
		actions.append({"action": "repair", "label": I18n.t("ui.repair")})
	var slot := EquipmentRules.slot_of(item_id, GameData.ITEMS)
	# An item already on the avatar offers Unequip in the Character window, not Equip.
	if slot != "" and character_slice != null and str(_local_worn().get(slot, "")) != item_id:
		actions.append({"action": "equip", "label": I18n.t("ui.equip_slot", [slot])})
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
			"tooltip": ("%s: %s" % [slot, item_description(item)]) if item != "" else I18n.t("ui.slot_empty", [slot]),
			"actions": [{"action": "unequip", "label": I18n.t("ui.unequip")}] if item != "" else [],
		})
	return rows

## The Character window's totals line, summed from fabric values only.
func character_stats_text() -> String:
	var totals := EquipmentRules.totals(_local_worn(), GameData.ITEMS)
	return I18n.t("ui.defense", [int(totals.get("defense", 0))])

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

func inventory_rows() -> Array:
	return _m2.inventory_rows()

## The `?` legend, moved here from the always-on HUD panel. Each row:
## { keys, desc, mouse } where `mouse` is a MouseButton for a drawn cue, or 0.
static func controls_rows() -> Array:
	return [
		{"keys": "WASD", "desc": I18n.t("controls.row0"), "mouse": 0},
		{"keys": "Space", "desc": I18n.t("controls.row1"), "mouse": 0},
		{"keys": I18n.t("controls.key.hold"), "desc": I18n.t("controls.row2"), "mouse": MOUSE_BUTTON_RIGHT},
		{"keys": I18n.t("controls.key.scroll"), "desc": I18n.t("controls.row3"), "mouse": 0},
		{"keys": "1 – 9", "desc": I18n.t("controls.row4"), "mouse": 0},
		{"keys": "▴", "desc": I18n.t("controls.row5"), "mouse": 0},
		{"keys": I18n.t("controls.key.drag"), "desc": I18n.t("controls.row6"), "mouse": 0},
		{"keys": "", "desc": I18n.t("controls.row7"), "mouse": MOUSE_BUTTON_LEFT},
		{"keys": "Shift +", "desc": I18n.t("controls.row8"), "mouse": MOUSE_BUTTON_LEFT},
		{"keys": "", "desc": I18n.t("controls.row9"), "mouse": MOUSE_BUTTON_MIDDLE},
		{"keys": "R", "desc": I18n.t("controls.row10"), "mouse": 0},
		{"keys": "B · V", "desc": I18n.t("controls.row11"), "mouse": 0},
		{"keys": "G", "desc": I18n.t("controls.row12"), "mouse": 0},
		{"keys": "E", "desc": I18n.t("controls.row13"), "mouse": 0},
		{"keys": "I · C · K · H · T · Y · P · G", "desc": I18n.t("controls.row14"), "mouse": 0},
		{"keys": "?", "desc": I18n.t("controls.row15"), "mouse": 0},
		{"keys": "Enter · /", "desc": I18n.t("controls.row16"), "mouse": 0},
		{"keys": "ESC", "desc": I18n.t("controls.row17"), "mouse": 0},
	]

func inventory_usage_text() -> String:
	if inventory_slice == null:
		return ""
	return I18n.t("ui.usage", [
		I18n.number(inventory_slice.get_current_weight(), 1),
		I18n.number(inventory_slice.get_max_weight(), 1),
		inventory_slice.get_total_slots_used(),
		inventory_slice.get_max_slots(),
	])

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

func repair_rows() -> Array:
	return _m1.repair_rows()

func technology_rows() -> Array:
	return _m2.technology_rows()

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
func _can_research(_tech_id: String, status: String, data: Dictionary) -> bool:
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
	return I18n.t("ui.friend_code", [handle if handle != "" else I18n.t("ui.friend_code_none")])

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
	push_toast(I18n.t("ui.worldgen_version", [recorded, running]))

## Phase 114 — the fabric's world or biome parameters changed since the world was saved. Recorded land
## keeps its shape; only land nobody has visited yet follows the new parameters.
func _on_worldgen_fingerprint_mismatch(_saved: int, _current: int) -> void:
	push_toast(I18n.t("ui.worldgen_fingerprint"))

## Queue a HUD toast. A text already queued or on screen is not added twice; past TOAST_MAX the
## oldest queued toast is dropped. Returns whether it was queued.
func push_toast(text: String) -> bool:
	if text == "" or text == _toast_shown or _toast_queue.has(text):
		return false
	_toast_queue.append(text)
	while _toast_queue.size() > TOAST_MAX:
		_toast_queue.pop_front()
	_show_next_toast()
	return true

## The queued toasts (not counting the one on screen), oldest first.
func toast_queue() -> Array[String]:
	return _toast_queue

## The toast on screen, "" when none.
func toast_shown() -> String:
	return _toast_shown

## Age the toast on screen by `delta` seconds and bring up the next queued one when it expires.
func advance_toasts(delta: float) -> void:
	if _toast_shown != "":
		_toast_left -= delta
		if _toast_left > 0.0:
			return
		_toast_shown = ""
		if _toast_label != null:
			_toast_label.text = ""
	_show_next_toast()

func _show_next_toast() -> void:
	if _toast_shown != "" or _toast_queue.is_empty():
		return
	_toast_shown = _toast_queue.pop_front()
	_toast_left = TOAST_SECONDS
	if _toast_label != null:
		_toast_label.text = _toast_shown

func _process(delta: float) -> void:
	if _toast_shown != "":
		advance_toasts(delta)

## One row per skill the player has, best tier first: { id, tier, tooltip }. Pure given the table.
static func skills_rows(tiers: Dictionary) -> Array:
	var rows: Array = []
	for skill in HotbarScript.ordered_skills(tiers):
		rows.append({"id": skill, "tier": str(tiers[skill]), "tooltip": I18n.t("ui.skill_tip", [skill, tiers[skill]])})
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
	_m1.refresh_character()

func refresh_crafting() -> void:
	_m2.refresh_crafting()

## The local player's research-point balance (Phase 124); 0 with no technology slice.
func research_points() -> int:
	return 0 if technology_slice == null else int(technology_slice.get_points())

func refresh_technology() -> void:
	if _technology_box == null:
		return
	for child in _technology_box.get_children():
		child.queue_free()
	var balance := Label.new()
	balance.text = I18n.t("ui.research_points", [research_points()])
	_technology_box.add_child(balance)
	for row in technology_rows():
		var r: Dictionary = row
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		var btn := Button.new()
		btn.text = I18n.t("ui.research")
		btn.disabled = not bool(r["can_research"])
		btn.pressed.connect(_on_research_pressed.bind(str(r["id"])))
		hbox.add_child(btn)
		var req_arr: Array = r.get("requires", [])
		var reqs: String = ", ".join(req_arr) if req_arr.size() > 0 else "—"
		var line := I18n.t("ui.tech_line", [r["id"], r["status"], reqs, r["cost"], r["points_cost"], r["duration"]])
		var lbl := Label.new()
		lbl.text = line + ("  (%s)" % I18n.reason_text(str(r["reason"])) if str(r["reason"]) != "" else "")
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
			btn.text = I18n.t("ui.buy")
			btn.pressed.connect(_on_market_buy_pressed.bind(str(r["id"])))
			hbox.add_child(btn)
			var lbl := Label.new()
			lbl.text = I18n.t("ui.listing", [r["id"], r["item_id"], r["quantity"], I18n.number(r["price"], 2), r["seller"]])
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
		lbl.text = I18n.t("ui.proposal_line", [r["id"], r["state"], r["title"], r["for"], r["against"], r["author"]])
		hbox.add_child(lbl)
		if str(r["state"]) == "proposed":
			var for_btn := Button.new()
			for_btn.text = I18n.t("ui.for")
			for_btn.pressed.connect(_on_proposal_vote_pressed.bind(str(r["id"]), "for"))
			hbox.add_child(for_btn)
			var against_btn := Button.new()
			against_btn.text = I18n.t("ui.against")
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
		return I18n.t("trade.unavailable")
	if _active_trade_id == "":
		return I18n.t("trade.none")
	var t: Dictionary = trade_slice.get_trade(_active_trade_id)
	if t.is_empty():
		return I18n.t("trade.ended")
	var state: String = str(t.get("state", "pending"))
	if state == "completed":
		return I18n.t("trade.completed")
	if state == "rejected":
		return I18n.t("trade.rejected")
	return I18n.t("trade.open", [_active_trade_id])

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
			_repair_feedback.text = I18n.t("ui.repaired", [result.get("item_id", "?")])
		else:
			_repair_feedback.text = "%s: %s" % [result.get("item_id", "?"), I18n.reason_text(str(result.get("reason", "?")))]
	refresh_crafting()
	refresh_inventory()

func _on_research_resolved(result: Dictionary) -> void:
	if _technology_feedback != null and _belongs_to_local_player(result):
		if result.get("success", false):
			_technology_feedback.text = I18n.t("ui.researching", [result.get("tech_id", "?")])
		else:
			_technology_feedback.text = "%s: %s" % [result.get("tech_id", "?"), I18n.reason_text(str(result.get("reason", "?")))]
	refresh_technology()

func _on_research_points_synced(player_id: String, _points: int) -> void:
	if _technology_box == null or not _technology_box.is_visible_in_tree():
		return
	if player_id == "" or technology_slice == null or player_id == technology_slice.local_player_id():
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
			_market_feedback.text = I18n.t("market.listed", [item_id, qty, I18n.number(price, 2)])
		else:
			_market_feedback.text = I18n.t("market.list_failed", [item_id])
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
		_proposal_feedback.text = I18n.t("proposal.submitted")
	refresh_proposals()

func _on_proposal_vote_pressed(proposal_id: String, verdict: String) -> void:
	if proposal_slice == null:
		return
	var result: Dictionary = proposal_slice.vote(proposal_id, "player", verdict)
	if _proposal_feedback != null:
		if result.get("success", true):
			_proposal_feedback.text = I18n.t("proposal.voted")
		else:
			_proposal_feedback.text = I18n.t("proposal.vote_rejected", [I18n.reason_text(str(result.get("reason", "?")))])
	refresh_proposals()

# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	_m1._build_ui()

## Phase 140 — the settlement window: found, invite, roles and the shared stockpile.
func _build_settlement_content() -> Control:
	var panel := SettlementPanelScript.new()
	panel.settlement_slice = settlement_slice
	settlement_panel = panel
	return panel

func _build_map_content() -> Control:
	return _m2._build_map_content()

## Phase 125 — a refused travel is said on the toast channel; a success needs no words (the world moves).
func _on_waystone_resolved(player_id: String, ok: bool, reason: String) -> void:
	if ok:
		return
	# A listen host resolves remote peers' intents too; only the owner is told why.
	if player_id != "" and technology_slice != null and player_id != str(technology_slice.local_player_id()):
		return
	push_toast(I18n.t(WAYSTONE_REFUSALS.get(reason, "waystone.default")))

## Reason code → catalog key.
const WAYSTONE_REFUSALS := {
	"unknown_player": "waystone.unknown_player",
	"rate_limited": "waystone.rate_limited",
	"same_stone": "waystone.same_stone",
	"missing_stone": "waystone.missing_stone",
	"not_attuned_from": "waystone.not_attuned_from",
	"not_attuned_to": "waystone.not_attuned_to",
	"too_far": "waystone.too_far",
	"cooldown": "waystone.cooldown",
	"no_cost": "waystone.no_cost",
	"unreachable": "waystone.unreachable",
}

func _build_window(key: String, title: String, content: Control, position: Vector2) -> PanelContainer:
	return _m1._build_window(key, title, content, position)

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

## The selector's label: the active language by its own name.
static func language_button_text() -> String:
	var loc := LocaleSettings.current()
	var key := "locale." + loc
	return I18n.t("settings.language", [I18n.t(key) if I18n.has_key(key) else loc])

func _on_language_pressed() -> void:
	LocaleSettings.set_locale(LocaleSettings.next_locale(), GameBus)

func _build_controls_content() -> Control:
	_controls_box = VBoxContainer.new()
	_controls_box.add_theme_constant_override("separation", 5)
	# Phase 131 — the language selector: one button that steps through the catalog's locales.
	_language_button = Button.new()
	_language_button.focus_mode = Control.FOCUS_NONE
	_language_button.pressed.connect(_on_language_pressed)
	_controls_box.add_child(_language_button)
	_refill_controls()
	return _controls_box

func _refill_controls() -> void:
	_m2._refill_controls()

func _build_inventory_content() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_inventory_usage = Label.new()
	_inventory_usage.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_inventory_usage)
	_inventory_empty = Label.new()
	_set_tr(_inventory_empty, "text", "ui.empty")
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
	_set_tr(copy_btn, "text", "ui.copy")
	copy_btn.pressed.connect(_on_copy_friend_code_pressed)
	code_row.add_child(copy_btn)
	vbox.add_child(code_row)
	_spawn_notice_label = Label.new()
	_spawn_notice_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_spawn_notice_label)
	_character_grid = GridContainer.new()
	_character_grid.columns = INVENTORY_COLUMNS
	vbox.add_child(_character_grid)
	return vbox

func _build_skills_content() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	var title := Label.new()
	_set_tr(title, "text", "ui.skills_title")
	title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(title)
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
	_set_tr(lbl, "text", "trade.blurb")
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl)
	var start_btn := Button.new()
	_set_tr(start_btn, "text", "trade.start")
	start_btn.pressed.connect(_on_trade_start_pressed)
	vbox.add_child(start_btn)
	var accept_btn := Button.new()
	_set_tr(accept_btn, "text", "trade.accept")
	accept_btn.pressed.connect(_on_trade_accept_pressed)
	vbox.add_child(accept_btn)
	_trade_status = Label.new()
	_trade_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trade_status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_trade_status)
	return vbox

func _build_market_content() -> Control:
	return _m1._build_market_content()

func _build_proposals_content() -> Control:
	return _m2._build_proposals_content()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _fmt_entries(entries: Array) -> String:
	var parts: Array = []
	for e in entries:
		parts.append("%s ×%d" % [str(e.get("item", "")), int(e.get("quantity", 1))])
	return ", ".join(parts)
