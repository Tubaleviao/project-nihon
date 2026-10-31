extends VBoxContainer
## Clan window (Phase 204) — found a clan, answer invites, invite, kick, set roles, leave, and the roster: every
## member's skills, sortable by one skill so "who sews best" is one click, with a "Message" button that opens
## the chat box on `/msg <handle> `. Presentation only: every button emits a `GameBus.clan_intent` and the host
## decides. All text goes through `I18n`. The slice's `view()` (the host's last push) is what it renders.

const I18n := preload("res://src/core/i18n.gd")
const ClanSlice := preload("res://src/clan/clan_slice.gd")
const REFRESH_SEC := 1.0
const ROLES := ["elder", "member", "guest"]

var clan_slice: Node = null

var _status: Label = null
var _feedback: Label = null
var _invites: VBoxContainer = null
var _roster: VBoxContainer = null
var _name_edit: LineEdit = null
var _target_edit: LineEdit = null
var _role_pick: OptionButton = null
var _sort_pick: OptionButton = null
var _buttons: Array = []   # [Control, i18n key]
var _elapsed: float = 0.0
## What the invite and roster rows were last built from: a refresh that changes neither keeps them.
var _invites_key := ""
var _roster_key := ""

func _init() -> void:
	add_theme_constant_override("separation", 6)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	_invites = VBoxContainer.new()
	add_child(_invites)
	_name_edit = _line("clan.name_ph")
	_button("clan.found", func() -> void: _send("found", { "name": _name_edit.text }))
	_target_edit = _line("clan.player_ph")
	_button("clan.invite", func() -> void: _send("invite", { "target": _target_edit.text }))
	_button("clan.uninvite", func() -> void: _send("uninvite", { "target": _target_edit.text }))
	_button("clan.kick", func() -> void: _send("kick", { "target": _target_edit.text }))
	_role_pick = OptionButton.new()
	for role: String in ROLES:
		_role_pick.add_item(I18n.t("clan.role." + role))
		_role_pick.set_item_metadata(_role_pick.item_count - 1, role)
	add_child(_role_pick)
	_button("clan.set_role", func() -> void: _send("role", { "target": _target_edit.text, "role": str(_role_pick.get_item_metadata(_role_pick.selected)) }))
	_button("clan.leave", func() -> void: _send("leave", {}))
	_sort_pick = OptionButton.new()
	_sort_pick.add_item(I18n.t("clan.sort_role"))
	_sort_pick.set_item_metadata(0, "")
	for skill: String in skill_keys():
		_sort_pick.add_item(skill_label(skill))
		_sort_pick.set_item_metadata(_sort_pick.item_count - 1, skill)
	_sort_pick.item_selected.connect(func(_i: int) -> void: refresh())
	add_child(_sort_pick)
	_roster = VBoxContainer.new()
	add_child(_roster)
	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_feedback)

## The fabric's skills, sorted, for the sort picker.
static func skill_keys() -> Array:
	var out: Array = GameData.SKILLS.keys()
	out.sort()
	return out

## A skill's display name in the active locale (`skill.<key>`); a skill the catalog has no line for shows its key.
static func skill_label(skill: String) -> String:
	var key := "skill." + skill.to_lower()
	return I18n.t(key) if I18n.has_key(key) else skill

func picked_sort() -> String:
	return str(_sort_pick.get_item_metadata(_sort_pick.selected)) if _sort_pick.selected >= 0 else ""

## Choose the roster's sort skill ("" for by role); used by the window and the tests.
func sort_by(skill: String) -> void:
	for i in _sort_pick.item_count:
		if str(_sort_pick.get_item_metadata(i)) == skill:
			_sort_pick.select(i)
	refresh()

func _ready() -> void:
	GameBus.clan_resolved.connect(_on_resolved)
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

func _send(action: String, args: Dictionary) -> void:
	GameBus.clan_intent.emit(action, args, "")

## The catalog key for a refusal: clan names have their own lines for the character-name codes.
static func refusal_key(reason: String) -> String:
	return "clan.refused." + reason

func _on_resolved(player_id: String, action: String, ok: bool, reason: String) -> void:
	# The host resolves every player's intents on this bus: only the local player's feedback is shown here.
	var reg: Variant = clan_slice.get("registry") if clan_slice != null else null
	if reg != null and "local_player_id" in reg and player_id != str(reg.local_player_id):
		return
	_feedback.text = I18n.t("clan.ok." + action) if ok else I18n.t(refusal_key(reason))
	refresh()

func feedback_text() -> String:
	return _feedback.text

## Re-render from the last view the host pushed (also re-applies the active language).
func refresh() -> void:
	for pair: Array in _buttons:
		var c: Control = pair[0]
		if c is LineEdit:
			(c as LineEdit).placeholder_text = I18n.t(str(pair[1]))
		elif c is Button:
			(c as Button).text = I18n.t(str(pair[1]))
	for i in _role_pick.item_count:
		_role_pick.set_item_text(i, I18n.t("clan.role." + str(_role_pick.get_item_metadata(i))))
	_sort_pick.set_item_text(0, I18n.t("clan.sort_role"))
	for i in range(1, _sort_pick.item_count):
		_sort_pick.set_item_text(i, skill_label(str(_sort_pick.get_item_metadata(i))))
	var view: Dictionary = clan_slice.view() if clan_slice != null else {}
	var mine: Dictionary = view.get("mine", {}) if view.get("mine", {}) is Dictionary else {}
	_render_invites(view.get("invites", []) if mine.is_empty() and view.get("invites", []) is Array else [])
	if mine.is_empty():
		_status.text = I18n.t("clan.none")
		_render_roster([], "")
		return
	_status.text = I18n.t("clan.status", [ClanSlice.display_name(mine), I18n.t("clan.role." + str(mine.get("role", "guest")))])
	var roster: Array = mine.get("roster", []) if mine.get("roster", []) is Array else []
	_render_roster(roster, picked_sort())

## The roster's lines as shown, best first for the picked skill: name, role, online, and either the picked
## skill's tier and XP or the member's best skills. Pure, for the tests.
static func roster_lines(roster: Array, skill: String) -> Array:
	var out: Array = []
	for m: Variant in ClanSlice.sort_roster(roster.filter(func(e: Variant) -> bool: return e is Dictionary), skill):
		var skills: Dictionary = m.get("skills", {}) if m.get("skills", {}) is Dictionary else {}
		var detail := ""
		if skill != "":
			var s: Dictionary = skills.get(skill, {}) if skills.get(skill, {}) is Dictionary else {}
			detail = I18n.t("clan.skill_line", [skill_label(skill), _tier_text(str(s.get("tier", ""))), int(s.get("xp", 0))])
		else:
			var best: Array = skills.keys()
			best.sort_custom(func(a: Variant, b: Variant) -> bool: return int((skills[a] as Dictionary).get("xp", 0)) > int((skills[b] as Dictionary).get("xp", 0)))
			var parts: Array = []
			for k: Variant in best.slice(0, 3):
				parts.append("%s %d" % [skill_label(str(k)), int((skills[k] as Dictionary).get("xp", 0))])
			detail = ", ".join(parts)
		out.append(I18n.t("clan.member_line", [str(m.get("name", "")), I18n.t("clan.role." + str(m.get("role", "guest"))),
			I18n.t("clan.online" if bool(m.get("online", false)) else "clan.offline"), detail]))
	return out

static func _tier_text(tier: String) -> String:
	return I18n.t("clan.tier." + tier) if tier != "" else "—"

func _render_roster(roster: Array, skill: String) -> void:
	var key := "%s|%s|%s" % [TranslationServer.get_locale(), skill, JSON.stringify(roster)]
	if key == _roster_key:
		return
	_roster_key = key
	for c: Node in _roster.get_children():
		_roster.remove_child(c)
		c.queue_free()
	var sorted: Array = ClanSlice.sort_roster(roster.filter(func(e: Variant) -> bool: return e is Dictionary), skill)
	var lines := roster_lines(roster, skill)
	for i in sorted.size():
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = str(lines[i])
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(label)
		var handle := str((sorted[i] as Dictionary).get("handle", ""))
		if handle != "":
			var b := Button.new()
			b.text = I18n.t("clan.message")
			b.pressed.connect(func() -> void: GameBus.chat_compose_requested.emit("/msg %s " % handle))
			row.add_child(b)
		_roster.add_child(row)

## One "Join" and one "Decline" button per pending invite (empty once the player belongs to a clan).
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
		var cid := str((inv as Dictionary).get("id", ""))
		var row := HBoxContainer.new()
		var join := Button.new()
		join.text = "%s — %s" % [I18n.t("clan.invited", [ClanSlice.display_name(inv as Dictionary)]), I18n.t("clan.join")]
		join.pressed.connect(func() -> void: _send("join", { "id": cid }))
		row.add_child(join)
		var no := Button.new()
		no.text = I18n.t("clan.decline")
		no.pressed.connect(func() -> void: _send("decline", { "id": cid }))
		row.add_child(no)
		_invites.add_child(row)
