extends "res://src/ui/zoom_canvas.gd"
## Phase 270 — the technology tree drawn on a zoom canvas: one node per technology (icon, localized name,
## state) at its `TechTreeLayout` place, and one line from each prerequisite to it, lit when the
## prerequisite is researched. Clicking a node selects it (`tech_selected`); the window shows the details.
## The view holds no game state: `set_rows` gives it what to show, already localized by the UI slice.

const TechTreeLayout := preload("res://src/ui/tech_tree_layout.gd")

signal tech_selected(tech_id: String)

const STATE_RESEARCHED := "researched"
const STATE_RESEARCHING := "researching"
const STATE_AVAILABLE := "available"
const STATE_LOCKED := "locked"

const NODE_SIZE := Vector2(156, 58)
const SPACING := Vector2(220, 92)
const LINE_WIDTH := 3.0
const LINE_LIT := Color(0.95, 0.8, 0.35)
const LINE_DIM := Color(0.45, 0.45, 0.5, 0.7)
const STATE_TINT := {
	STATE_RESEARCHED: Color(0.75, 1.0, 0.75),
	STATE_RESEARCHING: Color(0.8, 0.9, 1.0),
	STATE_AVAILABLE: Color(1.0, 1.0, 1.0),
	STATE_LOCKED: Color(0.6, 0.6, 0.65),
}

var layout: Dictionary = {}
var selected := ""
## { tech_id: Button }
var nodes: Dictionary = {}
## { tech_id: state } from the last `set_rows`.
var states: Dictionary = {}
## One per `requires` edge: { from, to, a, b, lit } with `a`/`b` the line's ends in content coordinates.
var segments: Array = []

func _init() -> void:
	super._init()
	custom_minimum_size = Vector2(420, 300)
	content.draw.connect(_draw_lines)
	visibility_changed.connect(_on_visibility_changed)

## `rows`: [{ id, name, state, state_text, icon (Texture2D or null), tooltip }]. Nodes are made once
## and updated in place, so a refresh never rebuilds the tree.
func set_rows(rows: Array, tree_layout: Dictionary = {}) -> void:
	layout = tree_layout if not tree_layout.is_empty() else TechTreeLayout.for_fabric()
	states.clear()
	for row: Dictionary in rows:
		var id := str(row["id"])
		if not (layout["position"] as Dictionary).has(id):
			continue
		states[id] = str(row["state"])
		var btn: Button = nodes.get(id, null)
		if btn == null:
			btn = _make_node(id)
		btn.text = str(row["name"])
		btn.icon = row.get("icon", null)
		btn.tooltip_text = str(row.get("tooltip", ""))
		btn.self_modulate = STATE_TINT.get(states[id], Color.WHITE)
		btn.button_pressed = id == selected
		(btn.get_node("State") as Label).text = str(row["state_text"])
	segments.clear()
	for e: Array in layout["edges"]:
		if not (nodes.has(e[0]) and nodes.has(e[1])):
			continue
		segments.append({
			"from": e[0], "to": e[1],
			"a": node_center(e[0]) + Vector2(NODE_SIZE.x / 2.0, 0),
			"b": node_center(e[1]) - Vector2(NODE_SIZE.x / 2.0, 0),
			"lit": states.get(e[0], "") == STATE_RESEARCHED,
		})
	content.queue_redraw()

func state_of(tech_id: String) -> String:
	return str(states.get(tech_id, ""))

## A node's centre in content coordinates.
func node_center(tech_id: String) -> Vector2:
	var p: Vector2 = (layout["position"] as Dictionary).get(tech_id, Vector2.ZERO)
	return p * SPACING

## The rectangle holding every node, in content coordinates.
func bounds() -> Rect2:
	var r := Rect2()
	var first := true
	for id in nodes:
		var nr := Rect2(node_center(id) - NODE_SIZE / 2.0, NODE_SIZE)
		r = nr if first else r.merge(nr)
		first = false
	return r

func fit_all() -> void:
	if not nodes.is_empty():
		fit(bounds())

## The newest available technology: the available one deepest in the tree (highest column), the
## topmost on a tie; "" when none is available.
static func newest_available(tree_layout: Dictionary, tech_states: Dictionary) -> String:
	var best := ""
	for col: Array in tree_layout["columns"]:
		for id: String in col:
			if tech_states.get(id, "") == STATE_AVAILABLE:
				best = id
				break
	return best

## Centre the view on the newest available technology (the whole tree when none is).
func center_on_newest() -> void:
	var id := newest_available(layout, states)
	if id == "":
		fit_all()
	else:
		center_on(node_center(id))

func select(tech_id: String) -> void:
	selected = tech_id
	for id in nodes:
		(nodes[id] as Button).set_pressed_no_signal(id == tech_id)
	tech_selected.emit(tech_id)

func _make_node(id: String) -> Button:
	var btn := Button.new()
	btn.name = "Node_%d" % nodes.size()
	btn.toggle_mode = true
	btn.size = NODE_SIZE
	btn.custom_minimum_size = NODE_SIZE
	btn.position = node_center(id) - NODE_SIZE / 2.0
	btn.expand_icon = false
	btn.add_theme_constant_override("icon_max_width", 28)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	btn.clip_text = true
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(select.bind(id))
	var state := Label.new()
	state.name = "State"
	state.add_theme_font_size_override("font_size", 12)
	state.position = Vector2(8, NODE_SIZE.y - 22)
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(state)
	content.add_child(btn)
	nodes[id] = btn
	return btn

func _draw_lines() -> void:
	for s: Dictionary in segments:
		content.draw_line(s["a"], s["b"], LINE_LIT if bool(s["lit"]) else LINE_DIM, LINE_WIDTH, true)

func _on_visibility_changed() -> void:
	if is_visible_in_tree() and not nodes.is_empty():
		# The window has no size until its first layout pass: centre after it.
		center_on_newest.call_deferred()
