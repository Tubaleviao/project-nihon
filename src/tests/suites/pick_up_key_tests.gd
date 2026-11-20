extends "res://src/tests/test_support.gd"
## Phase 279 — picking up is the `pick_up` input action (E), the equipment toggle is `toggle_equipment` (T). The
## handlers read the action, not a keycode, and still ignore Alt+letter window shortcuts and focused text fields.

const LooseItemSlice := preload("res://src/world/loose_item_slice.gd")
const InputLabels := preload("res://src/ui/input_labels.gd")
const HotbarScript := preload("res://src/ui/hotbar.gd")

const SEED := 7

func register() -> void:
	_run_test("pick up key: E with a pickup in reach emits the pick-up intent; T emits the equipment toggle", _test_e_picks_t_toggles)
	_run_test("pick up key: E in a focused text field neither picks up nor toggles equipment", _test_focused_field)
	_run_test("pick up key: Alt+E opens the inventory and does not pick up", _test_alt_e_inventory)
	_run_test("pick up key: no KEY_E / KEY_T literal in the handlers; labels of pick_up and toggle_equipment are E and T", _test_audit_and_labels)

func _key(code: int, alt: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.pressed = true
	e.keycode = code
	e.alt_pressed = alt
	return e

## A loose-item slice whose local player stands on a loose item, and that item.
func _loose_on_item() -> Dictionary:
	var terrain := TerrainSlice.new()
	_own(terrain)
	terrain.set_world_seed(SEED)
	var height_fn := func(p: Vector2) -> float: return terrain.get_height_at(p)
	SpawnFinderScript.prime_grounds(SEED, height_fn)
	var l := LooseItemSlice.new()
	l.render_visuals = false
	l.world_seed = SEED
	l.height_fn = height_fn
	add_child(l)
	var p: Vector3 = SpawnFinderScript.find_start(SEED, "pick_key", null, height_fn)
	var it: Dictionary = {}
	for i in l.items_near(Vector2(p.x, p.z), 100.0):
		it = i
		break
	assert_false(it.is_empty(), "an item lies near the spawn")
	var xz: Vector2 = it.get("xz", Vector2.ZERO)
	l.local_position = func() -> Vector3: return Vector3(xz.x, 0.0, xz.y)
	l.render_visuals = true   # the key handler runs only where the world is drawn
	return { "slice": l, "item": it }

## Feeds `event` to both handlers; returns [pick intents, equipment toggles].
func _feed(l: Node, ps: Node, event: InputEvent) -> Array:
	var picks: Array = []
	var toggles: Array = []
	var on_pick := func(id: String, _pid: String) -> void: picks.append(id)
	var on_toggle := func() -> void: toggles.append(1)
	GameBus.loose_pick_requested.connect(on_pick)
	GameBus.character_equipment_toggle_requested.connect(on_toggle)
	l._unhandled_input(event)
	ps._unhandled_input(event)
	GameBus.loose_pick_requested.disconnect(on_pick)
	GameBus.character_equipment_toggle_requested.disconnect(on_toggle)
	return [picks, toggles]

func _done(l: Node, ps: Node) -> void:
	l.render_visuals = false
	l.free()
	ps.free()

func _test_e_picks_t_toggles() -> void:
	var w := _loose_on_item()
	var l: Node = w["slice"]
	var ps := PlayerSlice.new()
	var e := _feed(l, ps, _key(KEY_E))
	assert_eq(e[0], [str(w["item"].get("id", ""))], "E picks up the item in reach")
	assert_eq(e[1].size(), 0, "and does not toggle the equipment")
	var echo := _key(KEY_E)
	echo.echo = true
	assert_eq(_feed(l, ps, echo)[0].size(), 0, "a held E (echo) does not pick again")
	var t := _feed(l, ps, _key(KEY_T))
	assert_eq(t[0].size(), 0, "T does not pick up")
	assert_eq(t[1].size(), 1, "T toggles the equipment")
	_done(l, ps)

func _test_focused_field() -> void:
	var w := _loose_on_item()
	var l: Node = w["slice"]
	var ps := PlayerSlice.new()
	var line := LineEdit.new()
	add_child(line)
	line.grab_focus()
	assert_true(get_viewport().gui_get_focus_owner() == line, "the field holds the keyboard")
	var e := _feed(l, ps, _key(KEY_E))
	assert_eq(e[0].size(), 0, "E typed into a field does not pick up")
	assert_eq(e[1].size(), 0, "and does not toggle the equipment")
	var t := _feed(l, ps, _key(KEY_T))
	assert_eq(t[1].size(), 0, "T typed into a field does not toggle the equipment")
	line.free()
	_done(l, ps)

func _test_alt_e_inventory() -> void:
	var w := _loose_on_item()
	var l: Node = w["slice"]
	var ps := PlayerSlice.new()
	var ui := _new_hud_ui()
	ui._input(_key(KEY_E, true))
	assert_true(ui.is_window_open("inventory"), "Alt+E opens the inventory")
	var r := _feed(l, ps, _key(KEY_E, true))
	assert_eq(r[0].size(), 0, "Alt+E does not pick up")
	assert_eq(r[1].size(), 0, "nor toggle the equipment")
	var at := _feed(l, ps, _key(KEY_T, true))
	assert_eq(at[1].size(), 0, "Alt+T (technology window) does not toggle the equipment")
	ui.free()
	_done(l, ps)

## The `_unhandled_input` body of a source file (up to the next top-level declaration).
func _handler_src(path: String) -> String:
	var src := FileAccess.get_file_as_string(path)
	var at := src.find("func _unhandled_input(")
	if at == -1:
		return ""
	var re := RegEx.create_from_string("\\n(func |static func |var |const |## |# -)")
	var m := re.search(src, at + 1)
	return src.substr(at, (m.get_start() if m != null else src.length()) - at)

func _test_audit_and_labels() -> void:
	for path in ["res://src/world/loose_item_slice.gd", "res://src/player/player_slice.gd"]:
		var body := _handler_src(path)
		assert_true(body != "", "%s has a key handler" % path)
		var re := RegEx.create_from_string("\\bKEY_[ET]\\b")
		assert_true(re.search(body) == null, "%s: no KEY_E / KEY_T literal in the key handler" % path)
	var loose_src := FileAccess.get_file_as_string("res://src/world/loose_item_slice.gd")
	assert_true(RegEx.create_from_string("\\bKEY_[ET]\\b").search(loose_src) == null, "the loose-item slice names no pick key")
	assert_true(_handler_src("res://src/world/loose_item_slice.gd").contains("InputLabels.PICK_UP"), "the pick handler reads pick_up")
	assert_true(_handler_src("res://src/player/player_slice.gd").contains("InputLabels.TOGGLE_EQUIPMENT"), "the toggle reads toggle_equipment")
	assert_true(InputMap.has_action(InputLabels.PICK_UP), "pick_up is an input action")
	assert_true(InputMap.has_action(InputLabels.TOGGLE_EQUIPMENT), "toggle_equipment is an input action")
	assert_eq(InputLabels.action_keys(InputLabels.PICK_UP), "E", "pick_up resolves to E")
	assert_eq(InputLabels.action_keys(InputLabels.TOGGLE_EQUIPMENT), "T", "toggle_equipment resolves to T")
	assert_eq(InputLabels.action_keycode(InputLabels.PICK_UP), KEY_E, "the bot presses E to pick up")
	var rows := {}
	for r: Dictionary in InputLabels.controls_rows():
		rows[r["action"]] = str(r["keys"])
	assert_eq(rows.get("pick_up", ""), InputLabels.action_keys(InputLabels.PICK_UP), "the help row for picking up reads the action")
	assert_eq(rows.get("equipment", ""), InputLabels.action_keys(InputLabels.TOGGLE_EQUIPMENT), "the help row for the equipment toggle reads the action")
	assert_true(HotbarScript.RESERVED_KEYS.has(KEY_E) and HotbarScript.RESERVED_KEYS.has(KEY_T), "both keys stay reserved for hotbar boxes")
