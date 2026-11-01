extends VBoxContainer
## Settlement window (Phase 140) — invite, roles, leave and the shared stockpile (no founding since Phase 205), and (Phase 198)
## the project board: what each project needs and has been given and who helped (no labour since Phase 207). Presentation
## only: every button emits a `GameBus.settlement_intent` and the host decides. All text goes through
## `I18n`. The slice's `view()` (the host's last push) is what it renders.

const I18n := preload("res://src/core/i18n.gd")
const SettlementSlice := preload("res://src/settlement/settlement_slice.gd")
const ProjectRules := preload("res://src/settlement/project_rules.gd")
const REFRESH_SEC := 1.0

var settlement_slice: Node = null

var _status: Label = null
var _members: Label = null
var _stock: Label = null
var _feedback: Label = null
var _invites: VBoxContainer = null
var _target_edit: LineEdit = null
var _role_pick: OptionButton = null
var _item_edit: LineEdit = null
var _qty_edit: LineEdit = null
var _buttons: Array = []   # [Button, i18n key]
var _elapsed: float = 0.0
var _projects: Label = null
var _project_pick: OptionButton = null

func _init() -> void:
	add_theme_constant_override("separation", 6)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	_invites = VBoxContainer.new()
	add_child(_invites)
	_target_edit = _line("settlement.player_ph")
	_button("settlement.invite", func() -> void: _send("invite", { "target": _target_edit.text }))
	_button("settlement.uninvite", func() -> void: _send("uninvite", { "target": _target_edit.text }))
	_role_pick = OptionButton.new()
	for role: String in ["elder", "member", "guest"]:
		_role_pick.add_item(I18n.t("settlement.role." + role))
		_role_pick.set_item_metadata(_role_pick.item_count - 1, role)
	add_child(_role_pick)
	_button("settlement.set_role", func() -> void: _send("role", { "target": _target_edit.text, "role": str(_role_pick.get_item_metadata(_role_pick.selected)) }))
	_button("settlement.leave", func() -> void: _send("leave", {}))
	_members = Label.new()
	_members.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_members)
	_stock = Label.new()
	_stock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_stock)
	_item_edit = _line("settlement.item_ph")
	_qty_edit = _line("settlement.qty_ph")
	_button("settlement.deposit", func() -> void: _send("deposit", { "item": _item_edit.text, "qty": _qty()}))
	_button("settlement.withdraw", func() -> void: _send("withdraw", { "item": _item_edit.text, "qty": _qty() }))
	_build_board()
	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_feedback)

## Phase 198 — the project board: the projects' state, a project picker, start, give (the item and quantity
## fields above). A project completes on the contribution that brings in its last material (Phase 207).
func _build_board() -> void:
	_projects = Label.new()
	_projects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_projects)
	_project_pick = OptionButton.new()
	var keys: Array = (ProjectRules.table()["projects"] as Dictionary).keys()
	keys.sort()
	for key: String in keys:
		_project_pick.add_item(I18n.t("settlement.project." + key))
		_project_pick.set_item_metadata(_project_pick.item_count - 1, key)
	add_child(_project_pick)
	_button("settlement.project_start", func() -> void: _send("project_start", { "project": picked_project() }))
	_button("settlement.project_give", func() -> void: _send("project_give", { "project": picked_project(), "item": _item_edit.text, "qty": _qty(), "from": "bag" }))
	_button("settlement.project_give_stock", func() -> void: _send("project_give", { "project": picked_project(), "item": _item_edit.text, "qty": _qty(), "from": "stock" }))

func picked_project() -> String:
	return str(_project_pick.get_item_metadata(_project_pick.selected)) if _project_pick.item_count > 0 and _project_pick.selected >= 0 else ""

func _ready() -> void:
	GameBus.settlement_resolved.connect(_on_resolved)
	visibility_changed.connect(refresh)
	refresh()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_elapsed += delta
	if _elapsed >= REFRESH_SEC:
		_elapsed = 0.0
		refresh()

func _line(ph_key: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = I18n.t(ph_key)
	add_child(e)
	_buttons.append([e, ph_key])
	return e

func _button(key: String, action: Callable) -> void:
	var b := Button.new()
	b.text = I18n.t(key)
	b.pressed.connect(action)
	add_child(b)
	_buttons.append([b, key])

func _qty() -> int:
	return int(_qty_edit.text) if _qty_edit.text.is_valid_int() else 0

func _send(action: String, args: Dictionary) -> void:
	GameBus.settlement_intent.emit(action, args, "")

func _on_resolved(player_id: String, action: String, ok: bool, reason: String) -> void:
	# The host resolves every player's intents on this bus: only the local player's feedback is shown here.
	var reg: Variant = settlement_slice.get("registry") if settlement_slice != null else null
	if reg != null and "local_player_id" in reg and player_id != str(reg.local_player_id):
		return
	_feedback.text = I18n.t("settlement.ok." + action) if ok else I18n.t("settlement.refused." + reason)
	refresh()

## Re-render from the last view the host pushed (also re-applies the active language).
func refresh() -> void:
	for pair: Array in _buttons:
		var c: Control = pair[0]
		if c is LineEdit:
			(c as LineEdit).placeholder_text = I18n.t(str(pair[1]))
		elif c is Button:
			(c as Button).text = I18n.t(str(pair[1]))
	for i in _role_pick.item_count:
		_role_pick.set_item_text(i, I18n.t("settlement.role." + str(_role_pick.get_item_metadata(i))))
	for i in _project_pick.item_count:
		_project_pick.set_item_text(i, I18n.t("settlement.project." + str(_project_pick.get_item_metadata(i))))
	var view: Dictionary = settlement_slice.view() if settlement_slice != null else {}
	var mine: Dictionary = view.get("mine", {})
	_render_invites(view.get("invites", []) if mine.is_empty() else [])
	if mine.is_empty():
		_status.text = I18n.t("settlement.none")
		_members.text = ""
		_stock.text = ""
		_projects.text = ""
		return
	var claim := {}
	for c: Dictionary in view.get("claims", []):
		if str(c.get("id", "")) == str(mine.get("id", "")):
			claim = c
	_status.text = I18n.t("settlement.status", [SettlementSlice.display_name(claim), I18n.t("settlement.tier." + str(claim.get("status", "founded"))),
		I18n.t("settlement.role." + str(mine.get("role", "guest"))), int(float(claim.get("radius", 0.0)))])
	var lines: Array = []
	var names: Dictionary = mine.get("names", {}) if mine.get("names", {}) is Dictionary else {}
	for pid: String in (mine.get("members", {}) as Dictionary):
		# Phase 181 — the member's display name when the host sent one, else the start of its key.
		var line := "%s: %s" % [str(names.get(pid, pid.left(8))), I18n.t("settlement.role." + str(mine["members"][pid]))]
		var sp := str((mine.get("specialties", {}) as Dictionary).get(pid, ""))
		if sp != "":
			line += " (%s)" % I18n.t("settlement.specialty." + sp)
		lines.append(line)
	_members.text = I18n.t("settlement.members", [", ".join(lines)])
	var items: Array = []
	for item: String in (mine.get("stock", {}) as Dictionary):
		items.append("%s ×%d" % [item, int(mine["stock"][item])])
	_stock.text = I18n.t("settlement.stock", [int(mine.get("used", 0)), int(mine.get("capacity", 0)), ", ".join(items)])
	_projects.text = board_text(mine.get("projects", []), names)

## Phase 198 — the board's text for the projects in a view: per project whether it is building or built, the
## materials needed against given, and who helped.
static func board_text(projects: Variant, names: Dictionary) -> String:
	var out: Array = [I18n.t("settlement.projects")]
	if not (projects is Array):
		return out[0]
	for p: Variant in projects:
		if not (p is Dictionary):
			continue
		var name := I18n.t("settlement.project." + str(p.get("key", "")))
		if str(p.get("status", "")) == "done":
			out.append(I18n.t("settlement.project_built", [name]))
			continue
		out.append(I18n.t("settlement.project_building", [name]))
		var need: Dictionary = p.get("need", {}) if p.get("need", {}) is Dictionary else {}
		var given: Dictionary = p.get("given", {}) if p.get("given", {}) is Dictionary else {}
		var mats: Array = []
		for item: String in need:
			mats.append(I18n.t("settlement.project_need", [item, int(given.get(item, 0)), int(need[item])]))
		out.append("  " + ", ".join(mats))
		var helpers: Array = []
		var c: Dictionary = p.get("contributors", {}) if p.get("contributors", {}) is Dictionary else {}
		for pid: String in c:
			helpers.append(str(names.get(pid, pid.left(8))))
		if not helpers.is_empty():
			out.append("  " + I18n.t("settlement.project_helpers", [", ".join(helpers)]))
	return "\n".join(out)

## What the invite buttons were last built from (the invites and the locale): a refresh that changes
## neither keeps the buttons instead of rebuilding them.
var _invites_key := ""

## One "Join" button per pending invite (empty once the player belongs to a settlement).
func _render_invites(invites: Array) -> void:
	var key := "%s|%s" % [TranslationServer.get_locale(), JSON.stringify(invites)]
	if key == _invites_key:
		return
	_invites_key = key
	for c: Node in _invites.get_children():
		_invites.remove_child(c)
		c.queue_free()
	for inv: Variant in invites:
		if not inv is Dictionary:
			continue
		var b := Button.new()
		b.text = "%s — %s" % [I18n.t("settlement.invited", [SettlementSlice.display_name(inv as Dictionary)]), I18n.t("settlement.join")]
		var sid := str((inv as Dictionary).get("id", ""))
		b.pressed.connect(func() -> void: _send("join", { "id": sid }))
		_invites.add_child(b)
