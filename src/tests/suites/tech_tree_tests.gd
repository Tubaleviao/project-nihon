extends "res://src/tests/test_support.gd"
## Phase 270 — the technology tree: a pure layout from the fabric's `requires` (columns by longest
## prerequisite chain, barycentre rows), a node per technology with its state, one line per edge, a
## zoom canvas that clamps and zooms around the cursor, and no entity id on a node or the detail panel.

const I18n := preload("res://src/core/i18n.gd")
const TechTreeLayout := preload("res://src/ui/tech_tree_layout.gd")
const TechTreeView := preload("res://src/ui/tech_tree_view.gd")
const ZoomCanvas := preload("res://src/ui/zoom_canvas.gd")
const ContentLocaleTests := preload("res://src/tests/suites/content_locale_tests.gd")

const NEW_KEYS := ["ui.tech_state_researched", "ui.tech_state_researching", "ui.tech_state_available",
	"ui.tech_state_locked", "ui.tech_fit", "ui.tech_select_hint", "ui.tech_cost", "ui.tech_time",
	"ui.tech_requires", "ui.tech_unlocks"]

func register() -> void:
	_run_test("tech tree: every technology's column is greater than each prerequisite's", _test_columns)
	_run_test("tech tree: the layout is identical across runs and input orders", _test_deterministic)
	_run_test("tech tree: barycentre passes reduce crossings", _test_barycentre)
	_run_test("tech tree: each requires edge is drawn exactly once, lit when researched", _test_edges_once)
	_run_test("tech tree: zoom stays within its clamp and zooms around the cursor", _test_zoom)
	_run_test("tech tree: fit and centre on the newest available technology", _test_fit_and_centre)
	_run_test("tech tree: a node's state follows the player's research", _test_state_follows_research)
	_run_test("tech tree: the detail panel shows cost, time, unlocks and a Research button when available", _test_detail_panel)
	_run_test("tech tree: the books-and-blueprints list keeps a usable height beside the tree and details", _test_writing_list_height)
	_run_test("tech tree: selecting nodes does not grow the window", _test_detail_rows_detached)
	_run_test("tech tree: a drag whose release was missed does not pan", _test_drag_needs_button)
	_run_test("tech tree: no node or panel shows an entity id", _test_no_entity_ids)
	_run_test("tech tree: every new string is in both locales", _test_locales)

func _test_columns() -> void:
	var lay := TechTreeLayout.for_fabric()
	var reqs := TechTreeLayout.fabric_requires()
	assert_eq((lay["column"] as Dictionary).size(), GameData.TECHNOLOGIES.size(), "every technology has a column")
	var deep := 0
	for id: String in reqs:
		for r in reqs[id]:
			assert_true(int(lay["column"][id]) > int(lay["column"][str(r)]), "%s sits right of its prerequisite %s" % [id, r])
		deep = maxi(deep, int(lay["column"][id]))
	assert_true(deep >= 2, "the fabric tree has a chain of at least three (%d)" % deep)
	# A longest chain decides the column, not the nearest prerequisite.
	var syn := TechTreeLayout.layout({"A": [], "B": ["A"], "C": ["B"], "D": ["A", "C"]})
	assert_eq(syn["column"], {"A": 0, "B": 1, "C": 2, "D": 3}, "D's column is its longest chain A-B-C-D")
	for id in syn["row"]:
		assert_eq(int(syn["row"][id]), 0, "%s is alone in its column" % id)

func _test_deterministic() -> void:
	var a := TechTreeLayout.layout(TechTreeLayout.fabric_requires())
	var b := TechTreeLayout.layout(TechTreeLayout.fabric_requires())
	assert_eq(a, b, "two runs on the fabric give the same layout")
	assert_eq(TechTreeLayout.for_fabric(), a, "the cached layout is that layout")
	var forward := {"T1": [], "T2": [], "T3": ["T1"], "T4": ["T2", "T1"], "T5": ["T3", "T4"], "T6": ["T2"]}
	var backward := {}
	var keys: Array = forward.keys()
	keys.reverse()
	for k in keys:
		var r: Array = (forward[k] as Array).duplicate()
		r.reverse()
		backward[k] = r
	assert_eq(TechTreeLayout.layout(forward), TechTreeLayout.layout(backward), "key and prerequisite order do not change the layout")

func _test_barycentre() -> void:
	# In id order A, B over C, D the lines A->D and B->C cross; the barycentre pass uncrosses them.
	var req := {"A": [], "B": [], "C": ["B"], "D": ["A"]}
	var id_order := [["A", "B"], ["C", "D"]]
	var edges := [["A", "D"], ["B", "C"]]
	assert_eq(TechTreeLayout.crossings(id_order, edges), 1, "id order crosses once")
	var lay := TechTreeLayout.layout(req)
	assert_eq(int(lay["crossings"]), 0, "the layout has no crossing")
	assert_eq(TechTreeLayout.crossings(lay["columns"], lay["edges"]), 0, "and its columns agree")
	# On the fabric, the layout never has more crossings than plain id order.
	var fab := TechTreeLayout.for_fabric()
	var plain: Array = []
	for c in (fab["columns"] as Array).size():
		var col: Array = (fab["columns"][c] as Array).duplicate()
		col.sort()
		plain.append(col)
	assert_true(int(fab["crossings"]) <= TechTreeLayout.crossings(plain, fab["edges"]), "the fabric layout crosses no more than id order")

func _new_tree_ui() -> Array:
	var ui := _new_test_ui()
	var inv := InventorySlice.new()
	add_child(inv)
	var craft := CraftingSlice.new()
	add_child(craft)
	var tech := TechnologySlice.new()
	add_child(tech)
	ui.inventory_slice = inv
	ui.crafting_slice = craft
	ui.technology_slice = tech
	tech.inventory_slice = inv
	ui.refresh_technology()
	return [ui, inv, craft, tech]

func _free_all(nodes: Array) -> void:
	for n: Node in nodes:
		n.free()

func _test_edges_once() -> void:
	var parts := _new_tree_ui()
	var ui = parts[0]
	var tech = parts[3]
	var tree = ui._tech_tree
	assert_true(tree != null, "the Technology window has a tree")
	assert_eq((tree.nodes as Dictionary).size(), GameData.TECHNOLOGIES.size(), "one node per technology")
	var reqs := TechTreeLayout.fabric_requires()
	var expected := 0
	var seen: Dictionary = {}
	for s: Dictionary in tree.segments:
		var key := "%s>%s" % [s["from"], s["to"]]
		seen[key] = int(seen.get(key, 0)) + 1
	for id: String in reqs:
		for r in reqs[id]:
			expected += 1
			assert_eq(int(seen.get("%s>%s" % [r, id], 0)), 1, "%s -> %s is drawn once" % [r, id])
	assert_eq((tree.segments as Array).size(), expected, "no other line is drawn")
	for s: Dictionary in tree.segments:
		assert_false(bool(s["lit"]), "nothing researched: no line is lit")
		assert_true((s["a"] as Vector2).x < (s["b"] as Vector2).x, "a line runs left to right")
	tech.apply_statuses({"TechBasicSmithing": "unlocked"})
	ui.refresh_technology()
	for s: Dictionary in tree.segments:
		assert_eq(bool(s["lit"]), s["from"] == "TechBasicSmithing", "%s -> %s lit only from a researched prerequisite" % [s["from"], s["to"]])
	assert_eq((tree.segments as Array).size(), expected, "a refresh does not add lines")
	assert_eq((tree.nodes as Dictionary).size(), GameData.TECHNOLOGIES.size(), "or nodes")
	_free_all(parts)

func _test_zoom() -> void:
	var c = ZoomCanvas.new()
	c.size = Vector2(400, 300)
	var pivot := Vector2(120, 80)
	var under: Vector2 = c.to_content(pivot)
	c.zoom_at(1.5, pivot)
	assert_true(is_equal_approx(c.zoom, 1.5), "the zoom changed")
	assert_true((c.to_content(pivot) as Vector2).is_equal_approx(under), "the point under the cursor stays put")
	for i in 40:
		c.zoom_at(2.0, pivot)
	assert_eq(c.zoom, c.max_zoom, "zooming in stops at the clamp")
	assert_true((c.to_content(pivot) as Vector2).is_equal_approx(under), "still around the cursor at the clamp")
	for i in 40:
		c.zoom_at(0.5, Vector2(300, 200))
	assert_eq(c.zoom, c.min_zoom, "zooming out stops at the clamp")
	# A wheel notch zooms around the mouse position.
	var before: float = c.zoom
	var at := Vector2(200, 150)
	var spot: Vector2 = c.to_content(at)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = at
	c._gui_input(wheel)
	assert_true(c.zoom > before, "the wheel zooms in")
	assert_true((c.to_content(at) as Vector2).is_equal_approx(spot), "around the cursor")
	var pinch := InputEventMagnifyGesture.new()
	pinch.factor = 1000.0
	pinch.position = at
	c._gui_input(pinch)
	assert_eq(c.zoom, c.max_zoom, "a pinch is clamped too")
	# Dragging pans.
	var off: Vector2 = c.offset
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	c._gui_input(press)
	var move := InputEventMouseMotion.new()
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	move.relative = Vector2(30, -10)
	c._gui_input(move)
	assert_eq(c.offset, off + Vector2(30, -10), "a drag pans")
	assert_eq((c.content as Control).position, c.offset, "the content follows the offset")
	assert_eq((c.content as Control).scale, Vector2(c.zoom, c.zoom), "and the zoom")
	assert_eq(ZoomCanvas.zoom_about(Vector2(10, 10), 1.0, 2.0, Vector2(10, 10)), Vector2(10, 10), "zooming about the origin keeps it")
	c.free()

func _test_fit_and_centre() -> void:
	var parts := _new_tree_ui()
	var ui = parts[0]
	var tree = ui._tech_tree
	tree.size = Vector2(500, 320)
	tree.fit_all()
	var r: Rect2 = tree.bounds()
	var tl: Vector2 = tree.to_canvas(r.position)
	var br: Vector2 = tree.to_canvas(r.end)
	assert_true(tl.x >= -0.5 and tl.y >= -0.5 and br.x <= 500.5 and br.y <= 320.5, "fit shows the whole tree")
	assert_true(tree.zoom >= tree.min_zoom and tree.zoom <= tree.max_zoom, "inside the clamp")
	# Nothing researched: the newest available technology is the deepest root-level one.
	var newest: String = TechTreeView.newest_available(tree.layout, tree.states)
	assert_true(newest != "", "something is available at the start")
	assert_eq(tree.state_of(newest), TechTreeView.STATE_AVAILABLE, "it is available")
	var tech = parts[3]
	tech.apply_statuses({"TechBasicSmithing": "unlocked"})
	ui.refresh_technology()
	newest = TechTreeView.newest_available(tree.layout, tree.states)
	assert_true(int(tree.layout["column"][newest]) >= 1, "researching a root makes a deeper technology the newest (%s)" % newest)
	tree.center_on_newest()
	assert_true((tree.to_canvas(tree.node_center(newest)) as Vector2).is_equal_approx(Vector2(250, 160)), "the view centres on it")
	_free_all(parts)

func _test_state_follows_research() -> void:
	var parts := _new_tree_ui()
	var ui = parts[0]
	var tech = parts[3]
	var tree = ui._tech_tree
	assert_eq(tree.state_of("TechBasicSmithing"), TechTreeView.STATE_AVAILABLE, "a root is available")
	assert_eq(tree.state_of("TechMasterForge"), TechTreeView.STATE_LOCKED, "its dependent is locked")
	tech.apply_statuses({"TechBasicSmithing": "researching"})
	ui.refresh_technology()
	assert_eq(tree.state_of("TechBasicSmithing"), TechTreeView.STATE_RESEARCHING, "research begun")
	assert_eq(tree.state_of("TechMasterForge"), TechTreeView.STATE_LOCKED, "still locked")
	tech.apply_statuses({"TechBasicSmithing": "unlocked"})
	ui.refresh_technology()
	assert_eq(tree.state_of("TechBasicSmithing"), TechTreeView.STATE_RESEARCHED, "researched")
	assert_eq(tree.state_of("TechMasterForge"), TechTreeView.STATE_AVAILABLE, "its dependent is now available")
	var label: Label = (tree.nodes["TechMasterForge"] as Button).get_node("State")
	assert_eq(label.text, I18n.t("ui.tech_state_available"), "the node says so")
	for row: Dictionary in ui.technology_rows():
		assert_eq(tree.state_of(str(row["id"])), str(row["state"]), "%s: the node shows the row's state" % row["id"])
	_free_all(parts)

func _texts(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.is_queued_for_deletion():
			continue
		if n is Label:
			out.append((n as Label).text)
		elif n is Button:
			out.append((n as Button).text)
		if n is Control and (n as Control).tooltip_text != "":
			out.append((n as Control).tooltip_text)
		stack.append_array(n.get_children())
	return out

func _test_detail_panel() -> void:
	var parts := _new_tree_ui()
	var ui = parts[0]
	var tech = parts[3]
	var tree = ui._tech_tree
	assert_eq(_texts(ui._tech_detail), [I18n.t("ui.tech_select_hint")], "nothing selected: a hint")
	tech.grant_points("", "craft", tech.research_cost("TechBasicSmithing"))
	ui.refresh_technology()
	(tree.nodes["TechBasicSmithing"] as Button).pressed.emit()
	assert_eq(tree.selected, "TechBasicSmithing", "clicking a node selects it")
	var texts := _texts(ui._tech_detail)
	var data: Dictionary = tech.get_tech_data("TechBasicSmithing")
	assert_true(texts.has(I18n.content("tech", "TechBasicSmithing")), "the panel names it")
	assert_true(texts.has(I18n.content("tech", "TechBasicSmithing", "desc")), "with its description")
	assert_true(texts.has(I18n.t("ui.tech_time", [I18n.number(int(data.get("researchDuration", 0)))])), "its time")
	var cost_line := false
	for t: String in texts:
		if t.begins_with(I18n.t("ui.tech_cost", ["§", ""]).get_slice("§", 0)) and t.contains(I18n.number(tech.research_cost("TechBasicSmithing"))):
			cost_line = true
	assert_true(cost_line, "its cost in research points")
	for rid in data.get("unlocks", []):
		assert_true(texts.has(I18n.content("recipe", str(rid))), "the unlocked recipe %s is shown (icon tooltip or name)" % rid)
	var btn: Button = ui._tech_detail.get_node_or_null("Research")
	assert_true(btn != null and not btn.disabled, "an available technology has a Research button")
	var asked: Array = []
	var on_req := func(id: String) -> void: asked.append(id)
	GameBus.research_requested.connect(on_req)
	btn.pressed.emit()
	GameBus.research_requested.disconnect(on_req)
	assert_eq(asked, ["TechBasicSmithing"], "it sends the research request (the host checks it)")
	tree.select("TechMasterForge")
	assert_true(ui._tech_detail.get_node_or_null("Research") == null, "a locked technology has no Research button")
	_free_all(parts)

## Lays the Technology content out at its minimum size (no frames run in the suite) and returns the
## writing list's height.
func _writing_list_height(ui) -> float:
	var scroll: Control = ui._technology_box.get_parent()
	var content: Container = scroll.get_parent()
	var row: Container = ui._tech_tree.get_parent()
	content.size = content.get_combined_minimum_size()
	content.notification(Container.NOTIFICATION_SORT_CHILDREN)
	row.notification(Container.NOTIFICATION_SORT_CHILDREN)
	return scroll.size.y

func _test_writing_list_height() -> void:
	var parts := _new_tree_ui()
	var ui = parts[0]
	var tech = parts[3]
	var content: Control = (ui._technology_box.get_parent() as Control).get_parent()
	assert_true(_writing_list_height(ui) >= 100.0, "on open the writing list has a usable height (%.0f)" % _writing_list_height(ui))
	var before: float = content.get_combined_minimum_size().y
	tech.grant_points("", "craft", tech.research_cost("TechBasicSmithing"))
	ui.refresh_technology()
	for id: String in ui._tech_tree.nodes:
		ui._tech_tree.select(id)
		assert_true(_writing_list_height(ui) >= 100.0, "with %s selected the writing list keeps its height" % id)
	assert_eq(content.get_combined_minimum_size().y, before, "the details scroll: selecting never raises the content's minimum height")
	var detail_scroll: Control = ui._tech_detail.get_parent()
	assert_true(detail_scroll is ScrollContainer, "the details sit in their own scroll area")
	assert_eq(ui._tech_tree.get_parent(), detail_scroll.get_parent(), "beside the tree")
	_free_all(parts)

func _test_detail_rows_detached() -> void:
	var parts := _new_tree_ui()
	var ui = parts[0]
	var tree = ui._tech_tree
	for id: String in tree.nodes:
		tree.select(id)
		for n: Node in ui._tech_detail.get_children():
			assert_false(n.is_queued_for_deletion(), "%s: no old detail row is left in the panel" % id)
	_free_all(parts)

func _test_drag_needs_button() -> void:
	var canvas: Control = ZoomCanvas.new()
	canvas.size = Vector2(400, 300)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	canvas._gui_input(press)
	var held := InputEventMouseMotion.new()
	held.button_mask = MOUSE_BUTTON_MASK_LEFT
	held.relative = Vector2(10, 5)
	var start: Vector2 = canvas.offset
	canvas._gui_input(held)
	assert_true(canvas.offset != start, "a held button pans")
	# The release is lost (window closed mid-drag): plain motion must not pan.
	var loose := InputEventMouseMotion.new()
	loose.relative = Vector2(30, 30)
	var after: Vector2 = canvas.offset
	canvas._gui_input(loose)
	assert_eq(canvas.offset, after, "motion with no button held does not pan")
	canvas._gui_input(held)
	assert_eq(canvas.offset, after, "and the stuck drag is dropped")
	canvas.free()

func _test_no_entity_ids() -> void:
	var parts := _new_tree_ui()
	var ui = parts[0]
	var tech = parts[3]
	var tree = ui._tech_tree
	tech.apply_statuses({"TechBasicSmithing": "unlocked", "TechAlchemy": "researching"})
	var ids := ContentLocaleTests.entity_ids()
	for loc: String in ["en", "pt_BR"]:
		var before := TranslationServer.get_locale()
		TranslationServer.set_locale(loc)
		var raw := {}
		for kind: String in ids:
			for id in ids[kind]:
				if I18n.content(kind, str(id)) != str(id):
					raw[str(id)] = kind
		ui.refresh_technology()
		var texts := _texts(tree)
		for id: String in tree.nodes:
			tree.select(id)
			texts.append_array(_texts(ui._tech_detail))
		assert_true(texts.size() > GameData.TECHNOLOGIES.size() * 3, "%s: the audit read the nodes and panels (%d)" % [loc, texts.size()])
		for text: String in texts:
			assert_false(text.contains("⟨"), "%s: no missing-name marker in '%s'" % [loc, text])
			assert_false(raw.has(text.strip_edges()), "%s: a label is the id '%s'" % [loc, text])
			for word in text.split(" ", false):
				var token := word.strip_edges().trim_suffix(",").trim_suffix(":").trim_suffix(".")
				assert_false(raw.has(token), "%s: '%s' shows the %s id %s" % [loc, text, raw.get(token, ""), token])
		TranslationServer.set_locale(before)
	_free_all(parts)

func _test_locales() -> void:
	var cats: Dictionary = I18n.parse_csv(I18n.CATALOG_PATH)["catalog"]
	for loc: String in ["en", "pt_BR"]:
		for key: String in NEW_KEYS:
			assert_true((cats[loc] as Dictionary).has(key) and str(cats[loc][key]) != "", "%s has %s" % [loc, key])
	for key: String in NEW_KEYS:
		assert_true(str(cats["en"][key]) != str(cats["pt_BR"][key]) or key == "ui.tech_time", "%s is translated" % key)
