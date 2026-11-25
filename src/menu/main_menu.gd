extends CanvasLayer
## Phase 223 — the main menu a boot with no boot user args opens (see GameRoot.should_show_main_menu).
##
## Home: Play, Join server, Options (greyed until Phase 225), Quit.
##   Play — the local worlds (LocalWorlds: name, seed, last played), New world (name only; Phase 238: one fabric seed)
##          and Delete with a confirmation. Choosing one asks the root to boot the listen host on it.
##   Join — an address and an optional friend code, plus the recent servers (RecentServers) with their ping and,
##          since Phase 297, the hosts "On this network" (LAN discovery through the status query). Asks the
##          root to boot the client path; a failed join comes back here with a localized reason.
##          Phase 298: a second tab, "Public servers", lists what the registries know (`PublicServers`), with each
##          server's own status answer, sort, filter, "hide full" and the registry list itself.
##
## Presentation only. The menu never boots anything itself: it emits `start_requested(choice)` and the
## root builds the world. A choice is `{mode: "host", dir, seed, name}` or `{mode: "join", address, friend}`.
## Every label goes through I18n.t(); world names and addresses are the player's own text.

signal start_requested(choice: Dictionary)

const I18n := preload("res://src/core/i18n.gd")
const OptionsWindow := preload("res://src/ui/options_window.gd")
const LocalWorlds := preload("res://src/menu/local_worlds.gd")
const RecentServers := preload("res://src/menu/recent_servers.gd")
const NetAddress := preload("res://src/networking/net_address.gd")
const ServerProbe := preload("res://src/networking/server_probe.gd")
const ServerStatus := preload("res://src/networking/server_status.gd")
const PersistenceSlice := preload("res://src/persistence/persistence_slice.gd")
const PublicServers := preload("res://src/menu/public_servers.gd")
const RegistryList := preload("res://src/networking/registry_list.gd")
const RegistryWire := preload("res://src/networking/registry_wire.gd")

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
## Phase 297 — LAN discovery and the recent servers' ping, live only while the Join page shows.
var _lan_list: VBoxContainer = null
var _lan_none: Label = null
var _probe: ServerProbe = null
## instance → {ip, rtt_ms, status} (`ServerProbe.merge_lan_row`)
var _lan_rows: Dictionary = {}
## recent address → its ping label
var _ping_labels: Dictionary = {}
## Where discovery asks; the net harness points it at loopback.
var lan_targets: Array = ServerProbe.LAN_TARGETS
var lan_status_port: int = ServerStatus.default_status_port(NetAddress.DEFAULT_PORT)
## While the Join page shows, discovery is re-sent every LAN_REFRESH_MS and a host silent for LAN_STALE_MS leaves the list.
const LAN_REFRESH_MS := 3000
const LAN_STALE_MS := 7000
var _last_discover_ms: int = 0
## Phase 298 — the Public servers tab.
const TAB_DIRECT := 0
const TAB_PUBLIC := 1
var public_servers := PublicServers.new()
var _join_tabs: TabContainer = null
var _public_list: VBoxContainer = null
var _public_notice: Label = null
var _public_filter: LineEdit = null
var _public_hide_full: CheckBox = null
var _public_sort: OptionButton = null
var _registries_edit: LineEdit = null
var public_sort_by: String = PublicServers.SORT_PING
var _public_check: CheckBox = null
var _region_pick: OptionButton = null
var _options_button: Button = null
var _options_window: Control = null   # Phase 225 — built on first use
var _version_label: Label = null

## Phase 255 — the game's version (`application/config/version` in project.godot), "" when unset.
static func game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))

## Phase 255 — the corner label's text: the version through the catalog (a release report names it), ""
## when the label is hidden (no `application/config/version`, e.g. a fork that never set one).
func version_text() -> String:
	return _version_label.text if _version_label != null and _version_label.visible else ""

## Phase 255 — the corner label's text for `version`: "" (label hidden) when there is no version.
static func version_label_text(version: String) -> String:
	return I18n.t("menu.version", [version]) if version != "" else ""

## Validate a Join form. Returns {ok: true, mode: "join", address, friend} or {ok: false, error: <key>}.
static func join_choice(raw_address: String, raw_friend: String) -> Dictionary:
	var address := raw_address.strip_edges()
	var friend := raw_friend.strip_edges()
	if not NetAddress.valid(address):
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
	if p == PAGE_JOIN:
		search_servers()
		if _join_tabs != null and _join_tabs.current_tab == TAB_PUBLIC:
			open_public()
	else:
		_stop_probe()
		public_servers.close()

## A line on the home page (a failed join's reason), already a catalog key; `args` are its params (#706).
func show_notice(key: String, args: Array = []) -> void:
	if _notice == null:
		return
	_notice.text = I18n.t(key, args) if key != "" else ""
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
	var choice := host_choice(w)
	choice["public"] = _public_check != null and _public_check.button_pressed   # Phase 298
	choice["region"] = RegistryWire.REGIONS[maxi(0, _region_pick.selected)] if _region_pick != null else ""
	start_requested.emit(choice)
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
	_version_label.text = version_label_text(game_version())
	_version_label.visible = _version_label.text != ""
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

func _open_options() -> void:
	if _options_window == null:
		_options_window = OptionsWindow.new()
		add_child(_options_window)
	_options_window.open()

func options_window() -> Control:
	return _options_window

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
	_options_button = _button(box, "menu.options", _open_options)
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
	# Phase 298 — a listen host announces itself to the registries when this is ticked.
	var pub_row := HBoxContainer.new()
	box.add_child(pub_row)
	_public_check = CheckBox.new()
	_public_check.text = I18n.t("menu.world.public")
	_public_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pub_row.add_child(_public_check)
	_region_pick = OptionButton.new()   # the region the list shows for this host
	for r in RegistryWire.REGIONS:
		_region_pick.add_item(I18n.t("menu.region." + (str(r) if str(r) != "" else "none")))
	_region_pick.tooltip_text = I18n.t("menu.public.col_region")
	pub_row.add_child(_region_pick)
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
	var page := _page_box(parent, PAGE_JOIN)
	var head := Label.new()
	head.text = I18n.t("menu.join_title")
	page.add_child(head)
	# Phase 298 — two tabs: the address form with recent and LAN servers, and the public list.
	_join_tabs = TabContainer.new()
	_join_tabs.custom_minimum_size = Vector2(640, 360)
	page.add_child(_join_tabs)
	var box := VBoxContainer.new()
	box.name = "Direct"
	box.add_theme_constant_override("separation", 8)
	_join_tabs.add_child(box)
	_join_tabs.set_tab_title(TAB_DIRECT, I18n.t("menu.join.tab_direct"))
	_build_public(_join_tabs)
	_join_tabs.set_tab_title(TAB_PUBLIC, I18n.t("menu.public.tab"))
	_join_tabs.tab_changed.connect(func(t: int) -> void:
		if t == TAB_PUBLIC:
			open_public()
		else:
			public_servers.close())
	_address_edit = _line(box, "menu.join.address", RecentServers.ADDRESS_MAX)
	_friend_edit = _line(box, "menu.join.friend", 32)
	_join_error = _error_label(box)
	_button(box, "menu.join.connect", func() -> void: request_join(_address_edit.text, _friend_edit.text))
	var recent_head := Label.new()
	recent_head.text = I18n.t("menu.join.recent")
	box.add_child(recent_head)
	_recent_list = VBoxContainer.new()
	box.add_child(_recent_list)
	# Phase 297 — the hosts that answered the status query on this network.
	var lan_head := HBoxContainer.new()
	box.add_child(lan_head)
	var lan_label := Label.new()
	lan_label.text = I18n.t("menu.join.lan")
	lan_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lan_head.add_child(lan_label)
	_button(lan_head, "menu.join.lan_refresh", search_servers)
	_lan_none = Label.new()
	_lan_none.text = I18n.t("menu.join.lan_none")
	box.add_child(_lan_none)
	_lan_list = VBoxContainer.new()
	box.add_child(_lan_list)
	_button(page, "menu.back", func() -> void: show_page(PAGE_HOME))
	return page

## Phase 298 — the Public servers tab: filter, hide full, sort, refresh; the column headers; the rows; the registries.
func _build_public(parent: Control) -> void:
	var box := VBoxContainer.new()
	box.name = "Public"
	box.add_theme_constant_override("separation", 6)
	parent.add_child(box)
	var bar := HBoxContainer.new()
	box.add_child(bar)
	_public_filter = _line(bar, "menu.public.filter", 64)
	_public_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_public_filter.text_changed.connect(func(_t: String) -> void: refresh_public_rows())
	_public_hide_full = CheckBox.new()
	_public_hide_full.text = I18n.t("menu.public.hide_full")
	_public_hide_full.toggled.connect(func(_on: bool) -> void: refresh_public_rows())
	bar.add_child(_public_hide_full)
	_public_sort = OptionButton.new()
	_public_sort.add_item(I18n.t("menu.public.sort_ping"))
	_public_sort.add_item(I18n.t("menu.public.sort_players"))
	_public_sort.item_selected.connect(func(i: int) -> void:
		set_public_sort(PublicServers.SORT_PING if i == 0 else PublicServers.SORT_PLAYERS))
	bar.add_child(_public_sort)
	_button(bar, "menu.public.refresh", func() -> void: public_servers.refresh())
	_public_notice = Label.new()
	_public_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_public_notice)
	box.add_child(_public_row_box(PUBLIC_HEADERS.map(func(k: String) -> String: return I18n.t(k)), null))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 180)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_public_list = VBoxContainer.new()
	_public_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_public_list)
	var reg := HBoxContainer.new()
	box.add_child(reg)
	_registries_edit = _line(reg, "menu.public.registries", 512)
	_registries_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(reg, "menu.public.registries_save", func() -> void: save_registries(_registries_edit.text))

## The column headers, in order: world, region, players, ping, version.
const PUBLIC_HEADERS := ["menu.public.col_name", "menu.public.col_region", "menu.public.col_players",
	"menu.public.col_ping", "menu.public.col_version"]
const PUBLIC_COL_WIDTHS := [0, 110, 90, 70, 110]

## One line of the table: the first cell a button (a row joins on click) or a label (the header).
func _public_row_box(cells: Array, on_click: Variant) -> HBoxContainer:
	var row := HBoxContainer.new()
	for i in cells.size():
		var c: Control
		if i == 0 and on_click is Callable:
			var b := Button.new()
			b.text = str(cells[i])
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.pressed.connect(on_click)
			c = b
		else:
			var l := Label.new()
			l.text = str(cells[i])
			l.clip_text = true
			c = l
		if int(PUBLIC_COL_WIDTHS[i]) == 0:
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			c.custom_minimum_size = Vector2(PUBLIC_COL_WIDTHS[i], 0)
		row.add_child(c)
	return row

## Phase 298 — the Public servers tab opened: the registry list in effect, the cached rows at once, then a fetch.
func open_public() -> void:
	public_servers.registries = RegistryList.current()
	if _registries_edit != null:
		_registries_edit.text = RegistryList.to_text(public_servers.registries)
	public_servers.open()
	refresh_public_rows()

func show_public_tab() -> void:
	if _join_tabs != null:
		_join_tabs.current_tab = TAB_PUBLIC

## Save the player's registry list from the tab's field and fetch again.
func save_registries(text: String) -> void:
	public_servers.registries = RegistryList.save(RegistryList.from_text(text))
	if _registries_edit != null:
		_registries_edit.text = RegistryList.to_text(public_servers.registries)
	public_servers.refresh()
	refresh_public_rows()

func set_public_sort(by: String) -> void:
	public_sort_by = by
	refresh_public_rows()

## The rows the tab shows now (after its filter, hide full and sort).
func public_rows() -> Array:
	return public_servers.rows(_public_filter.text if _public_filter != null else "",
		_public_hide_full != null and _public_hide_full.button_pressed, public_sort_by)

## A row was clicked: its address goes into the form and the join starts. "" when requested, else the error key.
func join_public(row: Dictionary) -> String:
	if not bool(row.get("joinable", false)):
		var why := str(row.get("refusal", ""))
		return why if why != "" else "menu.public.no_answer"
	var addr := str(row["address"])
	if _address_edit != null:
		_address_edit.text = addr
	return request_join(addr, _friend_edit.text if _friend_edit != null else "")

func refresh_public_rows() -> void:
	if _public_list == null:
		return
	for c in _public_list.get_children():
		_public_list.remove_child(c)
		c.free()
	var rows := public_rows()
	var notice := public_servers.notice
	if notice == "" and rows.is_empty() and not public_servers.entries.is_empty():
		notice = "menu.public.none_match"
	_public_notice.text = I18n.t(notice) if notice != "" else ""
	_public_notice.visible = notice != ""
	for r in rows:
		var t := PublicServers.row_texts(r)
		var row_data: Dictionary = r
		var line := _public_row_box([t["name"], t["region"], t["players"], t["ping"], t["version"]],
			func() -> void: join_public(row_data))
		(line.get_child(0) as Button).disabled = not bool(r["joinable"])
		_public_list.add_child(line)

## Phase 297 — (re)start LAN discovery and the recent servers' ping. The list starts empty: only hosts that answer
## this search are shown.
func search_servers() -> void:
	_lan_rows.clear()
	_refresh_lan()
	if _probe == null:
		_probe = ServerProbe.new()
		if _probe.open() != OK:
			_probe = null
			return
	_last_discover_ms = Time.get_ticks_msec()
	_probe.discover(lan_status_port, "lan", lan_targets, _last_discover_ms)
	for e in RecentServers.load_list(recent_path):
		_probe.query_address(str(e["address"]), "recent:" + str(e["address"]))

func _stop_probe() -> void:
	if _probe != null:
		_probe.close()
		_probe = null
	_lan_rows.clear()

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if public_servers.poll(now):
		refresh_public_rows()
	if _probe == null:
		return
	if now - _last_discover_ms >= LAN_REFRESH_MS:
		_last_discover_ms = now
		_probe.discover(lan_status_port, "lan", lan_targets, now)
	apply_answers(_probe.poll(now))
	if ServerProbe.drop_stale_rows(_lan_rows, now, LAN_STALE_MS):
		_refresh_lan()

func _exit_tree() -> void:
	_stop_probe()
	public_servers.close()

## Status answers in (from the probe, or the suite): LAN rows merged by host, pings written beside recent rows.
func apply_answers(answers: Array) -> void:
	var lan_changed := false
	for ans in answers:
		var key := str(ans["key"])
		if key == "lan":
			ServerProbe.merge_lan_row(_lan_rows, ans)
			lan_changed = true
		elif key.begins_with("recent:"):
			var label: Label = _ping_labels.get(key.substr(7), null)
			if label != null and is_instance_valid(label):
				label.text = I18n.t("menu.join.ping", [str(int(ans["rtt_ms"]))])
	if lan_changed:
		_refresh_lan()

## The LAN rows as shown: [{text, address, joinable}], most players first, then by world name.
func lan_rows() -> Array:
	var out: Array = []
	var raw: Array = _lan_rows.values()
	raw.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := int(a["status"]["players"])
		var pb := int(b["status"]["players"])
		return pa > pb if pa != pb else str(a["status"]["world_name"]) < str(b["status"]["world_name"]))
	for r in raw:
		out.append(lan_row_view(r))
	return out

## One LAN row's text and join address. A host of another protocol is listed but cannot be joined.
static func lan_row_view(row: Dictionary) -> Dictionary:
	var st: Dictionary = row["status"]
	var world_name := str(st["world_name"])
	if world_name == "":
		world_name = I18n.t("menu.join.lan_unnamed")
	var joinable := ServerStatus.protocol_refusal(ServerStatus.PROTOCOL_VERSION, int(st["protocol"])) == ""
	var text := I18n.t("menu.join.lan_row", [world_name, str(int(st["players"])), str(int(st["max_players"])), str(int(row["rtt_ms"]))]) \
		if joinable else I18n.t("menu.join.lan_incompatible", [world_name, str(st["game_version"])])
	return { "text": text, "address": NetAddress.format(str(row["ip"]), int(st["game_port"])), "joinable": joinable }

func _refresh_lan() -> void:
	if _lan_list == null or _lan_none == null:
		return
	for c in _lan_list.get_children():
		_lan_list.remove_child(c)
		c.free()
	var rows := lan_rows()
	_lan_none.visible = rows.is_empty()
	for r in rows:
		var b := Button.new()
		b.text = str(r["text"])
		b.disabled = not bool(r["joinable"])
		var addr := str(r["address"])
		b.pressed.connect(func() -> void: request_join(addr, _friend_edit.text))
		_lan_list.add_child(b)

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
	_ping_labels.clear()
	for e in RecentServers.load_list(recent_path):
		var addr := str(e["address"])
		var friend := str(e["friend"])
		var row := HBoxContainer.new()
		var b := Button.new()
		b.text = addr if friend == "" else I18n.t("menu.join.recent_row", [addr, friend])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			_address_edit.text = addr
			_friend_edit.text = friend)
		row.add_child(b)
		var ping := Label.new()   # Phase 297 — the status round trip, filled in when the host answers
		row.add_child(ping)
		_ping_labels[addr] = ping
		_recent_list.add_child(row)
