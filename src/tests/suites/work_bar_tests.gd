extends "res://src/tests/test_support.gd"
## Phase 289 — hold to work, told and shown: the work bar centred under the crosshair at every viewport size, the
## "keep holding" line and the early-release hint, and the tutorial's work steps saying to hold.

const Hold := preload("res://src/player/work_hold.gd")
const Card := preload("res://src/tutorial/tutorial_card.gd")
const Rules := preload("res://src/tutorial/tutorial_rules.gd")
const Labels := preload("res://src/ui/input_labels.gd")
const I18n := preload("res://src/core/i18n.gd")

const NEW_KEYS := ["controls.work_keep_holding", "controls.work_released_early", "tutorial.hold_hint", "controls.key.lmb"]
const HOLD_STEPS := ["chop", "dig", "mine_stone"]

func register() -> void:
	_run_test("work bar: inside the viewport, centred and below the centre at 1280x720, 1920x1080, 800x600 and after a resize", _test_bar_in_view)
	_run_test("work bar: an early release shows the hint for 2 s; a completed hold does not", _test_early_release_hint)
	_run_test("work bar: a running hold says to keep holding the input", _test_keep_holding_line)
	_run_test("work bar: the chop, dig and mine tutorial steps say to hold, in en and pt_BR", _test_tutorial_says_hold)

## A WorkHold in a SubViewport of `size`, ready. The caller frees the returned viewport.
func _rig(size: Vector2i) -> Array:
	var vp := SubViewport.new()
	vp.size = size
	add_child(vp)
	var wh: Control = Hold.new()
	vp.add_child(wh)
	return [vp, wh]

func _check_in_view(wh: Control, size: Vector2i) -> void:
	var view := Rect2(Vector2.ZERO, Vector2(size))
	var r: Rect2 = wh.bar().get_global_rect()
	assert_true(view.encloses(r), "at %s the bar %s lies inside the viewport" % [str(size), str(r)])
	assert_true(absf(r.get_center().x - view.size.x * 0.5) <= 2.0, "at %s the bar is centred (x %.1f)" % [str(size), r.get_center().x])
	assert_true(r.position.y > view.size.y * 0.5, "at %s the bar is below the screen centre" % str(size))
	assert_true(r.size.x >= 220.0 and r.size.y >= 12.0, "the bar is 220 x 12")

func _test_bar_in_view() -> void:
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(800, 600)]:
		var rig := _rig(size)
		_check_in_view(rig[1], size)
		rig[0].free()
	var rig := _rig(Vector2i(1920, 1080))
	var vp: SubViewport = rig[0]
	vp.size = Vector2i(800, 600)   # size_changed re-places it
	_check_in_view(rig[1], Vector2i(800, 600))
	vp.size = Vector2i(1280, 720)
	_check_in_view(rig[1], Vector2i(1280, 720))
	vp.free()

func _test_early_release_hint() -> void:
	var rig := _rig(Vector2i(1280, 720))
	var wh: Control = rig[1]
	var tree := { "kind": "tree", "tree_id": "p289-tree" }
	wh.press(tree)
	wh._on_started("tree:p289-tree", 3.0, "chop", "Thornwood")
	assert_true(wh.bar_showing(), "the bar shows while the hold runs")
	wh.tick(1.0, "p289-tree", {})
	wh.release()
	assert_false(wh.bar_showing(), "the bar hides on release")
	assert_true(wh.hint_showing(), "an early release shows the hint")
	assert_eq(wh._hint.text, I18n.t("controls.work_released_early"), "the hint is the catalog's text")
	wh.step_hint(1.9)
	assert_true(wh.hint_showing(), "the hint is still up at 1.9 s")
	wh.step_hint(0.2)
	assert_false(wh.hint_showing(), "the hint hides after 2 s")
	assert_false(wh.visible, "nothing of the bar shows once the hint is gone")
	# A completed hold, then letting go: no hint.
	wh.press(tree)
	wh._on_started("tree:p289-tree", 3.0, "chop", "Thornwood")
	wh.tick(3.1, "p289-tree", {})
	assert_false(wh.bar_showing(), "the bar hides when the work completes")
	wh.release()
	assert_false(wh.hint_showing(), "a completed hold shows no hint")
	# A press on nothing, released, is not a hold.
	wh.press({})
	wh.release()
	assert_false(wh.hint_showing(), "a press on nothing shows no hint")
	rig[0].free()

func _test_keep_holding_line() -> void:
	var rig := _rig(Vector2i(1280, 720))
	var wh: Control = rig[1]
	wh.press({ "kind": "tree", "tree_id": "p289-tree" })
	wh._on_started("tree:p289-tree", 3.0, "chop", "Thornwood")
	var line := I18n.t("controls.work_keep_holding", [Labels.work_input("tree")])
	assert_true(str(wh._label.text).contains(line), "the label says to keep holding the input: %s" % wh._label.text)
	assert_true(Labels.work_input("tree") != "" and Labels.work_input("block").contains(Labels.work_input("tree")), "a block is worked with Shift + the tree's input")
	var lbl: Label = wh._label
	assert_true(lbl.get_global_rect().end.y <= wh.bar().get_global_rect().position.y, "the label stands above the bar")
	wh.release()
	rig[0].free()

func _test_tutorial_says_hold() -> void:
	var cats: Dictionary = I18n.parse_csv("res://locale/ui.csv")["catalog"]
	for k: String in NEW_KEYS:
		for loc in ["en", "pt_BR"]:
			assert_true(str((cats[loc] as Dictionary).get(k, "")) != "", "%s has %s" % [loc, k])
	var by_id := {}
	for s: Dictionary in Rules.steps():
		by_id[str(s["id"])] = s
	var old := TranslationServer.get_locale()
	for loc in ["en", "pt_BR"]:
		TranslationServer.set_locale(loc)
		for id: String in HOLD_STEPS:
			assert_true(by_id.has(id), "the %s step exists" % id)
			var step: Dictionary = by_id[id]
			for loc_key in ["tutorial.%s.body" % id]:
				assert_true(str((cats[loc] as Dictionary).get(loc_key, "")).contains("{0}"), "%s %s names the hold through a param" % [loc, loc_key])
			var kind := "block" if (step["inputs"] as Array).has("mine") else "tree"
			var hint := I18n.t("tutorial.hold_hint", [Labels.work_input(kind)])
			var body := Card.body_text(step)
			assert_true(body.contains(hint), "%s %s says to hold: %s" % [loc, id, body])
			assert_false(body.contains("{0}"), "%s %s has its param filled" % [loc, id])
	TranslationServer.set_locale(old)
