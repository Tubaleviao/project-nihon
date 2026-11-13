extends CanvasLayer
## Phase 223 — the main menu a boot with no boot user args opens (see GameRoot.should_show_main_menu).
##
## Home: Play, Join server, Options (greyed until Phase 225), Quit.
##   Play — the local worlds (LocalWorlds: name, seed, last played), New world (name only; Phase 238: one fabric seed)
##          and Delete with a confirmation. Choosing one asks the root to boot the listen host on it.
##   Join — an address and an optional friend code, plus the recent servers (RecentServers). Asks the
##          root to boot the client path; a failed join comes back here with a localized reason.
##
## Presentation only. The menu never boots anything itself: it emits `start_requested(choice)` and the
## root builds the world. A choice is `{mode: "host", dir, seed, name}` or `{mode: "join", address, friend}`.
## Every label goes through I18n.t(); world names and addresses are the player's own text.

signal start_requested(choice: Dictionary)

const I18n := preload("res://src/core/i18n.gd")
const LocalWorlds := preload("res://src/menu/local_worlds.gd")
const RecentServers := preload("res://src/menu/recent_servers.gd")
const PersistenceSlice := preload("res://src/persistence/persistence_slice.gd")

const LAYER := 40
const PAGE_HOME := "home"
const PAGE_PLAY := "play"
const PAGE_CONFIRM := "confirm_delete"
const PAGE_JOIN := "join"

## Where worlds live; the suite points these at a temp folder before adding the menu.
var worlds_base: String = LocalWorlds.DEFAULT_BASE
var legacy_dir: String = PersistenceSlice.DEFAULT_SERVER_SAVE_DIR
var recent_path: String = RecentServers.DEFAULT_PATH
## Quit asks the tree to quit; the suite swaps it out.
var quit_callback: Callable = Callable()

var _page := PAGE_HOME
var _pages: Dictionary = {}
var _notice: Label = null
var _world_list: VBoxContainer = null
var _world_error: Label = null
var _name_edit: LineEdit = null
var _confirm_label: Label = null
var _pending_delete: String = ""
var _address_edit: LineEdit = null
var _friend_edit: LineEdit = null
var _join_error: Label = null
var _recent_list: VBoxContainer = null
var _options_button: Button = null
var _version_label: Label = null

## Phase 255 — the game's version (`application/config/version` in project.godot), "" when unset.
static func game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))

## Phase 255 — true when `v` is `major.minor.patch`, three non-negative integers without leading zeros.
static func is_semver(v: String) -> bool:
	return RegEx.create_from_string("^(0|[1-9]\\d*)\\.(0|[1-9]\\d*)\\.(0|[1-9]\\d*)$").search(v) != null

## Phase 255 — the corner label's text: the version through the catalog (a release report names it).
func version_text() -> String:
	return _version_label.text if _version_label != null else ""

## Validate a Join form. Returns {ok: true, mode: "join", address, friend} or {ok: false, error: <key>}.
static func join_choice(raw_address: String, raw_friend: String) -> Dictionary:
	var address := raw_address.strip_edges()
	var friend := raw_friend.strip_edges()
	if not RecentServers.valid_address(address):
		return { "ok": false, "error": "menu.join.error_address" }
	if not RecentServers.valid_friend(friend):
		return { "ok": false, "error": "menu.join.error_friend" }
	return { "ok": true, "mode": "join", "address": address, "friend": friend }

## A host choice for world `w` (a LocalWorlds.list row).
static func host_choice(w: Dictionary) -> Dictionary:
	return { "ok": true, "mode": "host", "dir": str(w["dir"]), "seed": int(w["seed"]), "name": str(w["name"]) }

## What a list row reads as: the name (the legacy save has a localized one), seed and last played.
static func world_row_text(w: Dictionary) -> String:
	var world_name: String = I18n.t("menu.world.legacy_name") if bool(w.get("legacy", false)) else str(w["name"])
	if int(w["last_played"]) <= 0:
		return I18n.t("menu.world.row_never", [world_name, str(int(w["seed"]))])
	return I18n.t("menu.world.row", [world_name, str(int(w["seed"])), I18n.date(int(w["last_played"]))])

func _ready() -> void:
	layer = LAYER
	_build()
	show_page(PAGE_HOME)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func page() -> String:
	return _page

func show_page(p: String) -> void:
	_page = p
	for k in _pages:
		(_pages[k] as Control).visible = k == p
	if p == PAGE_PLAY:
		refresh_worlds()
	elif p == PAGE_JOIN:
		_refresh_recent()

## A line on the home page (a failed join's reason), already a catalog key.
func show_notice(key: String) -> void:
	if _notice == null:
		return
	_notice.text = I18n.t(key) if key != "" else ""
	_notice.visible = key != ""

func notice_text() -> String:
	return _notice.text if _notice != null and _notice.visible else ""

func options_enabled() -> bool:
	return _options_button != null and not _options_button.disabled

func worlds() -> Array:
	return LocalWorlds.list(worlds_base, legacy_dir)

## Create a world from the New world form; on success the list refreshes. Returns the result.
func create_world(raw_name: String, raw_seed: String = "") -> Dictionary:
	DirAccess.make_dir_recursive_absolute(worlds_base)
	var res := LocalWorlds.create(worlds_base, raw_name, raw_seed)
	_world_error.text = "" if bool(res["ok"]) else I18n.t(str(res["error"]))
	if bool(res["ok"]):
		_name_edit.text = ""
	refresh_worlds()
	return res

## Ask to delete world `id`: shows the confirmation page. Nothing is removed until `confirm_delete`.
func request_delete(id: String) -> void:
	var w := _find(id)
	if w.is_empty() or bool(w["legacy"]):
		return
	_pending_delete = id
	show_page(PAGE_CONFIRM)
	_confirm_label.text = I18n.t("menu.world.delete_confirm", [str(w["name"])])

func pending_delete() -> String:
	return _pending_delete

func confirm_delete() -> bool:
	var ok := _pending_delete != "" and LocalWorlds.delete(worlds_base, _pending_delete)
	_pending_delete = ""
	show_page(PAGE_PLAY)
	return ok

func cancel_delete() -> void:
	_pending_delete = ""
	show_page(PAGE_PLAY)

func play_world(id: String) -> bool:
	var w := _find(id)
	if w.is_empty():
		return false
	start_requested.emit(host_choice(w))
	return true

## Submit the Join form. Returns "" when the join was requested, else the error key shown.
func request_join(raw_address: String, raw_friend: String) -> String:
	var choice := join_choice(raw_address, raw_friend)
	if not bool(choice["ok"]):
		_join_error.text = I18n.t(str(choice["error"]))
		return str(choice["error"])
	_join_error.text = ""
	RecentServers.remember(str(choice["address"]), str(choice["friend"]), recent_path)
	start_requested.emit(choice)
	return ""

func _find(id: String) -> Dictionary:
	for w in worlds():
		if str(w["id"]) == id:
			return w
	return {}

func _quit() -> void:
	if quit_callback.is_valid():
		quit_callback.call()
	elif is_inside_tree():
		get_tree().quit()

# ---------------------------------------------------------------------------
# Layout (code-built, like every UI surface in this project)
# ---------------------------------------------------------------------------

func _build() -> void:
	var root := Control.new()
	root.name = "MainMenuRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.09, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	center.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	panel.add_child(stack)
	var title := Label.new()
	title.text = I18n.t("menu.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	stack.add_child(title)
	_pages[PAGE_HOME] = _build_home(stack)
	_pages[PAGE_PLAY] = _build_play(stack)
	_pages[PAGE_CONFIRM] = _build_confirm(stack)
	_pages[PAGE_JOIN] = _build_join(stack)
	# Phase 255 — the version in the bottom-right corner, so a tester's screenshot says which build it was.
	_version_label = Label.new()
	_version_label.name = "VersionLabel"
	_version_label.text = I18n.t("menu.version", [game_version()])
	_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_version_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	_version_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_version_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_version_label.modulate = Color(1, 1, 1, 0.6)
	root.add_child(_version_label)

func _button(parent: Control, key: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = I18n.t(key)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _page_box(parent: Control, page_name: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "Page_" + page_name
	box.add_theme_constant_override("separation", 8)
	parent.add_child(box)
	return box

func _line(parent: Control, placeholder_key: String, max_len: int) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = I18n.t(placeholder_key)
	e.max_length = max_len
	parent.add_child(e)
	return e

func _error_label(parent: Control) -> Label:
	var l := Label.new()
	l.modulate = Color(1.0, 0.55, 0.5)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

func _build_home(parent: Control) -> Control:
	var box := _page_box(parent, PAGE_HOME)
	_notice = _error_label(box)
	_notice.visible = false
	_button(box, "menu.play", func() -> void: show_page(PAGE_PLAY))
	_button(box, "menu.join", func() -> void: show_page(PAGE_JOIN))
	_options_button = _button(box, "menu.options", func() -> void: pass)
	_options_button.disabled = true   # Phase 225 brings the options window
	_options_button.tooltip_text = I18n.t("menu.options_soon")
	_button(box, "menu.quit", _quit)
	return box

func _build_play(parent: Control) -> Control:
	var box := _page_box(parent, PAGE_PLAY)
	var head := Label.new()
	head.text = I18n.t("menu.play_title")
	box.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 220)
	box.add_child(scroll)
	_world_list = VBoxContainer.new()
	_world_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_world_list)
	var new_head := Label.new()
	new_head.text = I18n.t("menu.world.new")
	box.add_child(new_head)
	_name_edit = _line(box, "menu.world.name", LocalWorlds.NAME_MAX)
	_world_error = _error_label(box)
	_button(box, "menu.world.create", func() -> void: create_world(_name_edit.text))
	_button(box, "menu.back", func() -> void: show_page(PAGE_HOME))
	return box

func _build_confirm(parent: Control) -> Control:
	var box := _page_box(parent, PAGE_CONFIRM)
	_confirm_label = Label.new()
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_confirm_label)
	_button(box, "menu.world.delete_yes", func() -> void: confirm_delete())
	_button(box, "menu.cancel", cancel_delete)
	return box

func _build_join(parent: Control) -> Control:
	var box := _page_box(parent, PAGE_JOIN)
	var head := Label.new()
	head.text = I18n.t("menu.join_title")
	box.add_child(head)
	_address_edit = _line(box, "menu.join.address", RecentServers.ADDRESS_MAX)
	_friend_edit = _line(box, "menu.join.friend", 32)
	_join_error = _error_label(box)
	_button(box, "menu.join.connect", func() -> void: request_join(_address_edit.text, _friend_edit.text))
	var recent_head := Label.new()
	recent_head.text = I18n.t("menu.join.recent")
	box.add_child(recent_head)
	_recent_list = VBoxContainer.new()
	box.add_child(_recent_list)
	_button(box, "menu.back", func() -> void: show_page(PAGE_HOME))
	return box

func refresh_worlds() -> void:
	if _world_list == null:
		return
	for c in _world_list.get_children():
		_world_list.remove_child(c)
		c.free()
	var all := worlds()
	if all.is_empty():
		var none := Label.new()
		none.text = I18n.t("menu.world.none")
		_world_list.add_child(none)
	for w in all:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = world_row_text(w)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var id := str(w["id"])
		_button(row, "menu.world.play", func() -> void: play_world(id))
		if not bool(w["legacy"]):
			_button(row, "menu.world.delete", func() -> void: request_delete(id))
		_world_list.add_child(row)

func _refresh_recent() -> void:
	if _recent_list == null:
		return
	for c in _recent_list.get_children():
		_recent_list.remove_child(c)
		c.free()
	for e in RecentServers.load_list(recent_path):
		var addr := str(e["address"])
		var friend := str(e["friend"])
		var b := Button.new()
		b.text = addr if friend == "" else I18n.t("menu.join.recent_row", [addr, friend])
		b.pressed.connect(func() -> void:
			_address_edit.text = addr
			_friend_edit.text = friend)
		_recent_list.add_child(b)
