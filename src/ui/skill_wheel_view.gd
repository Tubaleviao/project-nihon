extends "res://src/ui/zoom_canvas.gd"
## Phase 271 — the skill wheel drawn on a zoom canvas (Phase 270): professions on the rim, one node per skill
## tier at its `SkillWheelLayout` place, and a line from each node to the one it requires. A node shows the
## skill's localized name (never the tier) and an icon; its state is unlocked, available or locked. A rim
## profession shows its name and icon and a state: locked, active or mastered.
## The view holds no game state: `set_rows` gives it what to show, already localized by the UI slice.

const SkillWheelLayout := preload("res://src/ui/skill_wheel_layout.gd")
const SkillTiers := preload("res://src/core/skill_tiers.gd")
const I18n := preload("res://src/core/i18n.gd")
const UiIcons := preload("res://src/ui/ui_icons.gd")

signal node_selected(node_id: String)

const STATE_UNLOCKED := "unlocked"
const STATE_AVAILABLE := "available"
const STATE_LOCKED := "locked"
const PROF_LOCKED := "profession_locked"
const PROF_ACTIVE := "profession_active"
const PROF_MASTERED := "profession_mastered"

## Pixels per grid unit: the rim has this radius in content coordinates.
const WHEEL_RADIUS := 760.0
const NODE_SIZE := Vector2(104, 34)
const PROFESSION_SIZE := Vector2(136, 44)
const LINE_WIDTH := 2.0
const FOCUS_TINT := Color(1.5, 1.2, 0.55)
const FOCUS_LABEL_SIZE := Vector2(180, 70)
const LINE_LIT := Color(0.95, 0.8, 0.35)
const LINE_DIM := Color(0.45, 0.45, 0.5, 0.55)
const STATE_TINT := {
	STATE_UNLOCKED: Color(0.75, 1.0, 0.75),
	STATE_AVAILABLE: Color(1.0, 1.0, 1.0),
	STATE_LOCKED: Color(0.6, 0.6, 0.65),
	PROF_LOCKED: Color(0.6, 0.6, 0.65),
	PROF_ACTIVE: Color(1.0, 0.9, 0.6),
	PROF_MASTERED: Color(0.7, 0.9, 1.0),
}

var layout: Dictionary = {}
var selected := ""
## { node_id: Button }
var nodes: Dictionary = {}
## { profession_id: Button }
var professions: Dictionary = {}
var states: Dictionary = {}
var segments: Array = []
## Phase 272: { profession_id: share 0..1 } of the recent focus, and the centre label listing the leading skills.
var focus_shares: Dictionary = {}
var focus_label: Label = null

func _init() -> void:
	super._init()
	custom_minimum_size = Vector2(420, 300)
	min_zoom = 0.2
	content.draw.connect(_draw_lines)
	visibility_changed.connect(_on_visibility_changed)

## `node_rows`: [{ id, name, state, icon, tooltip }]; `profession_rows`: [{ id, name, state, state_text, icon, tooltip }].
## Buttons are made once and updated in place.
func set_rows(node_rows: Array, profession_rows: Array, wheel_layout: Dictionary = {}) -> void:
	layout = wheel_layout if not wheel_layout.is_empty() else SkillWheelLayout.for_fabric()
	if layout.is_empty():
		return
	states.clear()
	for row: Dictionary in node_rows:
		var id := str(row["id"])
		if not (layout["position"] as Dictionary).has(id):
			continue
		states[id] = str(row["state"])
		var btn: Button = nodes.get(id, null)
		if btn == null:
			btn = _make_button(id, NODE_SIZE, node_center(id), 12)
			nodes[id] = btn
			btn.pressed.connect(select.bind(id))
		btn.text = str(row["name"])
		btn.icon = row.get("icon", null)
		btn.tooltip_text = str(row.get("tooltip", ""))
		btn.self_modulate = STATE_TINT.get(states[id], Color.WHITE)
		btn.button_pressed = id == selected
	for row: Dictionary in profession_rows:
		var pid := str(row["id"])
		if not (layout["profession_position"] as Dictionary).has(pid):
			continue
		var pb: Button = professions.get(pid, null)
		if pb == null:
			pb = _make_button(pid, PROFESSION_SIZE, profession_center(pid), 14)
			professions[pid] = pb
		pb.text = "%s\n%s" % [row["name"], row["state_text"]]
		pb.icon = row.get("icon", null)
		pb.tooltip_text = str(row.get("tooltip", ""))
		pb.self_modulate = STATE_TINT.get(str(row["state"]), Color.WHITE)
		states["profession:" + pid] = str(row["state"])
	if not focus_shares.is_empty():
		set_focus(focus_shares, focus_label.text if focus_label != null else "")
	segments.clear()
	for e: Array in layout["edges"]:
		if not (nodes.has(e[0]) and nodes.has(e[1])):
			continue
		segments.append({"from": e[0], "to": e[1], "a": node_center(e[0]), "b": node_center(e[1]),
			"lit": states.get(e[1], "") == STATE_UNLOCKED})
	content.queue_redraw()

## Phase 272 — the player's focus on the wheel: a profession whose skills had the recent play time glows in
## proportion to its share, and the centre lists the leading skills. `profession_shares` is
## { profession: share }; `centre_text` is the localized centre text ("" hides it).
func set_focus(profession_shares: Dictionary, centre_text: String) -> void:
	focus_shares = profession_shares.duplicate()
	for pid in professions:
		var pb: Button = professions[pid]
		var base: Color = STATE_TINT.get(str(states.get("profession:" + str(pid), "")), Color.WHITE)
		var share := clampf(float(focus_shares.get(pid, 0.0)), 0.0, 1.0)
		pb.self_modulate = base.lerp(FOCUS_TINT, share)
	if focus_label == null:
		focus_label = Label.new()
		focus_label.name = "FocusCentre"
		focus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		focus_label.size = FOCUS_LABEL_SIZE
		focus_label.position = -FOCUS_LABEL_SIZE / 2.0
		focus_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_label.add_theme_font_size_override("font_size", 13)
		content.add_child(focus_label)
	focus_label.text = centre_text
	focus_label.visible = centre_text != ""

func node_center(id: String) -> Vector2:
	return (layout["position"] as Dictionary).get(id, Vector2.ZERO) * WHEEL_RADIUS

func profession_center(id: String) -> Vector2:
	return (layout["profession_position"] as Dictionary).get(id, Vector2.ZERO) * WHEEL_RADIUS

## The rectangle holding every node and profession, in content coordinates.
func bounds() -> Rect2:
	var r := Rect2()
	var first := true
	for id in nodes:
		var nr := Rect2(node_center(id) - NODE_SIZE / 2.0, NODE_SIZE)
		r = nr if first else r.merge(nr)
		first = false
	for id in professions:
		r = r.merge(Rect2(profession_center(id) - PROFESSION_SIZE / 2.0, PROFESSION_SIZE))
	return r

func fit_all() -> void:
	if not nodes.is_empty():
		fit(bounds())

func select(id: String) -> void:
	selected = id
	for nid in nodes:
		(nodes[nid] as Button).set_pressed_no_signal(nid == id)
	node_selected.emit(id)

## A newly unlocked node flashes (a short tween on its tint); the node keeps its state colour afterwards.
func pulse(node_id: String) -> void:
	var btn: Button = nodes.get(node_id, null)
	if btn == null or not btn.is_inside_tree():
		return
	var rest: Color = btn.self_modulate
	var tw := btn.create_tween()
	tw.tween_property(btn, "self_modulate", Color(1.6, 1.4, 0.6), 0.25)
	tw.tween_property(btn, "self_modulate", rest, 0.6)
	tw.set_loops(3)

func _make_button(id: String, size_px: Vector2, centre: Vector2, font: int) -> Button:
	var btn := Button.new()
	btn.name = "Node_%d" % (nodes.size() + professions.size())
	btn.toggle_mode = true
	btn.size = size_px
	btn.custom_minimum_size = size_px
	btn.position = centre - size_px / 2.0
	btn.expand_icon = false
	btn.add_theme_constant_override("icon_max_width", 22)
	btn.add_theme_font_size_override("font_size", font)
	btn.clip_text = true
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	content.add_child(btn)
	return btn

func _draw_lines() -> void:
	for s: Dictionary in segments:
		content.draw_line(s["a"], s["b"], LINE_LIT if bool(s["lit"]) else LINE_DIM, LINE_WIDTH, true)

func _on_visibility_changed() -> void:
	if is_visible_in_tree() and not nodes.is_empty():
		fit_all.call_deferred()

# ─── Pure projections ───────────────────────────────────────────────────────

## A node's state from the player's tier in its skill: its tier or below is unlocked, the next is available.
static func node_state(player_tier: String, node_tier: String, tiers: Array) -> String:
	var have := tiers.find(player_tier)
	var want := tiers.find(node_tier)
	if want <= have:
		return STATE_UNLOCKED
	return STATE_AVAILABLE if want == have + 1 else STATE_LOCKED

## A profession's state: mastered when every skill it names is at the last tier, active when unlocked.
static func profession_state(unlocked: bool, skill_tiers: Array, last_tier: String) -> String:
	if not unlocked:
		return PROF_LOCKED
	for t in skill_tiers:
		if str(t) != last_tier:
			return PROF_ACTIVE
	return PROF_MASTERED if not skill_tiers.is_empty() else PROF_ACTIVE

## Phase 271 — the wheel's rows from the player's skill tiers and professions. Pure given the tables.
static func rows(tiers: Dictionary, unlocked: Dictionary) -> Dictionary:
	var order: Array = SkillTiers.TIER_ORDER
	var wheel_nodes: Dictionary = SkillWheelLayout.fabric_nodes()
	var node_rows: Array = []
	for id in wheel_nodes:
		var n: Dictionary = wheel_nodes[id]
		var skill := str(n["skill"])
		var have := str(tiers.get(skill, order[0]))
		node_rows.append({"id": id, "name": I18n.content("skill", skill),
			"state": node_state(have, str(n["tier"]), order),
			"icon": UiIcons.load_icon(UiIcons.skill_key(skill)),
			"tooltip": I18n.content("skill", skill, "desc")})
	var res: Resource = GameData.WORLD_SYSTEMS.get("SkillWheel", null)
	var prof_skills: Dictionary = res.get("professionSkills") if res != null else {}
	var prof_rows: Array = []
	for p in SkillWheelLayout.fabric_professions():
		var have_tiers: Array = (prof_skills.get(p, []) as Array).map(func(s): return str(tiers.get(str(s), order[0])))
		var state := profession_state(unlocked.has(p), have_tiers, str(order[order.size() - 1]))
		prof_rows.append({"id": p, "name": I18n.content("profession", str(p)), "state": state,
			"state_text": I18n.t("ui." + state), "icon": null,
			"tooltip": I18n.content("profession", str(p))})
	return {"nodes": node_rows, "professions": prof_rows}

