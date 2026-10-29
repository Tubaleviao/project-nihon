extends "res://src/tests/test_support.gd"
## Phase 186 — the first-steps tutorial at runtime: the pure rules over the fabric steps, event completion for
## every trigger kind, the saved state, the veteran seeding, and that the slice only listens.

const Rules := preload("res://src/tutorial/tutorial_rules.gd")
const State := preload("res://src/tutorial/tutorial_state.gd")
const TutorialSlice := preload("res://src/tutorial/tutorial_slice.gd")

const FIXTURE := "user://test_tutorial_settings.json"

func register() -> void:
	_run_test("tutorial runtime: next_step follows fabric order and requires, skips done and dismissed, and is empty when off", _test_next_step)
	_run_test("tutorial runtime: each trigger kind completes its step from a synthetic event and an unrelated one completes nothing", _test_events)
	_run_test("tutorial runtime: done and dismissed survive a reload; a corrupt or missing file is tutorial on, nothing done", _test_state_file)
	_run_test("tutorial runtime: a fixture player with a tool, a station and a bed starts with those steps done", _test_veteran)
	_run_test("tutorial runtime: the slice completes only the current step, counts metres and gathers, and restart resets", _test_slice)
	_run_test("tutorial runtime: replaying a session history completes the steps its events would", _test_replay)
	_run_test("tutorial runtime: the removed UI instructions are gone and no catalog key outside tutorial.* and controls.* instructs", _test_catalog_audit)
	_run_test("tutorial runtime: the card shows the step, the player's keys and the controls; the ? panel has the toggle and restart", _test_card)
	_run_test("tutorial runtime: the slice sends no intent and no network message", _test_listens_only)

func _fresh() -> Dictionary:
	return State.fresh()

func _test_next_step() -> void:
	var st := _fresh()
	assert_eq(str(Rules.next_step(st)["id"]), "move", "the first step is the first in the fabric")
	(st["done"] as Array).append("move")
	var nxt := str(Rules.next_step(st)["id"])
	assert_eq(nxt, "jump", "then the next whose requires are done")
	(st["dismissed"] as Array).append("jump")
	assert_true(str(Rules.next_step(st)["id"]) != "jump", "a dismissed step is never returned")
	# Dismissing a step must not strand the steps that require it.
	var skipped := { "enabled": true, "done": [], "dismissed": ["move"] }
	var ids: Array = Rules.eligible(skipped).map(func(x: Dictionary) -> String: return str(x["id"]))
	assert_true(ids.has("jump") and ids.has("mine") and not ids.has("move"), "a dismissed step unlocks the steps after it")
	# A step whose requires are not done is never offered.
	var offered := {}
	for i in 60:
		var s := Rules.next_step(st)
		if s.is_empty():
			break
		offered[str(s["id"])] = true
		for r in s["requires"]:
			assert_true((st["done"] as Array).has(str(r)), "%s is offered only after %s" % [s["id"], r])
		(st["done"] as Array).append(str(s["id"]))
	assert_true(offered.has("place_bed") and Rules.next_step(st).is_empty(), "the whole table is walked, then nothing is left")
	var off := _fresh()
	off["enabled"] = false
	assert_true(Rules.next_step(off).is_empty(), "nothing is returned when the tutorial is off")
	var prog := Rules.progress(st)
	assert_true(Rules.chapter_done(st, "gathering") and not Rules.chapter_done(st, "moving"), "a chapter is done when all its steps are (jump was dismissed)")
	assert_eq(int(prog["moving"]["done"]), int(prog["moving"]["total"]) - 1, "chapter progress counts done steps")

func _step(id: String) -> Dictionary:
	for s in Rules.steps():
		if str(s["id"]) == id:
			return s
	return {}

func _test_events() -> void:
	var cases := [
		["move", "moved_metres", { "metres": 12.0 }, { "metres": 2.0 }],
		["jump", "jumped", {}, {}],
		["look", "camera_turned", {}, {}],
		["mine", "item_gathered", { "tags": ["material"], "count": 1 }, { "tags": ["creature"], "count": 1 }],
		["chop", "item_gathered", { "item": "Thornwood", "count": 4 }, { "item": "Thornwood", "count": 3 }],
		["place_bench", "station_placed", { "type": "carpentry bench" }, { "type": "forge" }],
		["controls", "window_opened", { "window": "controls" }, { "window": "map" }],
		["hotbar", "hotbar_bound", {}, {}],
		["equip_weapon", "item_equipped", { "slot": "MainHand" }, { "slot": "Head" }],
		["kill", "creature_killed", { "creature": "x", "tags": ["creature"] }, { "creature": "x", "tags": [] }],
		["harvest", "carcass_harvested", {}, {}],
		["craft_bed", "item_crafted", { "item": "Bed" }, { "item": "Plank" }],
		["craft_tool", "item_crafted", { "item": "FerritePick", "tags": ["pick"] }, { "item": "Bed", "tags": [] }],
		["place_bed", "bed_placed", {}, {}],
		["build_shelter", "shelter_complete", {}, {}],
		["respawn", "respawned", {}, {}],
		["waystone", "waystone_discovered", {}, {}],
		["tier_up", "skill_tier_up", {}, {}],
		["research_carpentry", "technology_researched", { "technology": "TechBasicCarpentry" }, { "technology": "TechBasicSmithing" }],
		["chat", "chat_sent", {}, {}],
	]
	var kinds := {}
	for c in cases:
		var step := _step(str(c[0]))
		assert_true(not step.is_empty(), "the %s step exists" % c[0])
		kinds[str(c[1])] = true
		assert_true(Rules.event_completes(step, str(c[1]), c[2]), "%s: a matching %s event completes it" % [c[0], c[1]])
		assert_false(Rules.event_completes(step, "never_a_kind", c[2]), "%s: an unrelated kind completes nothing" % c[0])
		if not (c[3] as Dictionary).is_empty() or str(c[1]) in ["moved_metres", "item_gathered"]:
			assert_false(Rules.event_completes(step, str(c[1]), c[3]), "%s: the wrong subject completes nothing" % c[0])
	var fabric_kinds: Dictionary = GameData.TUTORIALS["Tutorial"].get("triggerKinds")
	for k in fabric_kinds:
		assert_true(kinds.has(str(k)), "the trigger kind %s is covered" % k)

func _test_state_file() -> void:
	var st := _fresh()
	st["enabled"] = false
	(st["done"] as Array).append_array(["move", "jump"])
	(st["dismissed"] as Array).append("look")
	assert_true(State.save_state(st, FIXTURE), "the state is written")
	var back := State.load_state(FIXTURE)
	assert_eq(back["enabled"], false, "the toggle survives")
	assert_eq(back["done"], ["move", "jump"], "the done set survives")
	assert_eq(back["dismissed"], ["look"], "the dismissed set survives")
	# The locale beside it is kept.
	var f := FileAccess.open(FIXTURE, FileAccess.WRITE)
	f.store_string(JSON.stringify({ "locale": "pt_BR", "tutorial": { "done": ["move"] } }))
	f.close()
	State.save_state(back, FIXTURE)
	assert_eq(JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))["locale"], "pt_BR", "saving keeps the locale")
	for junk in ["{not json", "[]", "{\"tutorial\": 5}", "{\"tutorial\": {\"done\": \"x\", \"enabled\": 3}}"]:
		var g := FileAccess.open(FIXTURE, FileAccess.WRITE)
		g.store_string(junk)
		g.close()
		var loaded := State.load_state(FIXTURE)
		assert_true(loaded["enabled"] == true and (loaded["done"] as Array).is_empty() and (loaded["dismissed"] as Array).is_empty(),
			"corrupt file %s loads as on and nothing done" % junk)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE))
	assert_eq(State.load_state(FIXTURE), State.fresh(), "a missing file loads as on and nothing done")

func _test_veteran() -> void:
	var facts := {
		"items": { "FerritePick": 1, "Bed": 0 },
		"tags": { "FerritePick": ["pick"] },
		"stations": ["forge", "carpentry bench"],
		"bed": true, "kills": 0, "slots": [], "technologies": [],
	}
	var ids: Array = Rules.ids_satisfied(facts)
	for want in ["craft_tool", "place_forge", "place_bench", "place_bed"]:
		assert_true(ids.has(want), "%s is already done for a veteran" % want)
	assert_true(ids.has("craft_planks") and ids.has("move") and ids.has("chop"), "and so is everything those steps require")
	assert_false(ids.has("kill"), "a step the save does not show stays open")
	assert_eq(Rules.ids_satisfied({}), [], "a new player has nothing done")

func _test_slice() -> void:
	var sl := TutorialSlice.new()
	sl.path = FIXTURE
	add_child(sl)
	assert_eq(sl.note_event("jumped"), "", "a step that is not on the card does not complete")
	assert_eq(sl.note_event("moved_metres", { "metres": 6.0 }), "", "six metres is not enough")
	assert_eq(sl.note_event("moved_metres", { "metres": 6.0 }), "move", "the metres add up to the step")
	assert_eq(sl.current_step()["id"], "jump", "then the next card")
	assert_eq(sl.note_event("item_gathered", { "item": "Granite", "tags": ["material"], "count": 1 }), "mine", "a gathered material completes mine")
	assert_eq(sl.note_event("item_gathered", { "item": "Thornwood", "tags": ["material"], "count": 2 }), "", "two of four Thornwood is not enough")
	assert_eq(sl.note_event("item_gathered", { "item": "Granite", "tags": ["material"], "count": 5 }), "", "another item does not count toward Thornwood")
	assert_eq(sl.note_event("item_gathered", { "item": "Thornwood", "tags": ["material"], "count": 2 }), "chop", "the Thornwood adds up to chop")
	sl.dismiss_current()
	assert_true(sl.current_step()["id"] != "jump", "dismissing moves on")
	sl.set_enabled(false)
	assert_true(sl.current_step().is_empty(), "off shows nothing")
	assert_eq(sl.note_event("camera_turned"), "", "and completes nothing")
	sl.set_enabled(true)
	sl.restart()
	assert_eq(sl.current_step()["id"], "move", "restart starts over")
	assert_true((State.load_state(FIXTURE)["done"] as Array).is_empty(), "and saves it")
	sl.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE))

func _test_listens_only() -> void:
	var sent := []
	var a := func(_x: Variant = null, _y: Variant = null, _z: Variant = null) -> void: sent.append(1)
	GameBus.craft_intent.connect(a)
	GameBus.chat_intent.connect(a)
	GameBus.settlement_intent.connect(a)
	GameBus.bed_place_intent.connect(a)
	var sl := TutorialSlice.new()
	sl.path = FIXTURE
	add_child(sl)
	for kind in ["jumped", "camera_turned", "window_opened", "chat_sent", "respawned"]:
		sl.note_event(kind, { "window": "controls" })
	sl.dismiss_current()
	sl.restart()
	assert_true(sent.is_empty(), "the slice emitted no intent")
	for src in ["tutorial_slice.gd", "tutorial_rules.gd", "tutorial_state.gd"]:
		var text := FileAccess.get_file_as_string("res://src/tutorial/" + src)
		assert_false(text.contains("_intent.emit") or text.contains("send_") or text.contains("_broadcast"), "%s names no intent or network call" % src)
	GameBus.craft_intent.disconnect(a)
	GameBus.chat_intent.disconnect(a)
	GameBus.settlement_intent.disconnect(a)
	GameBus.bed_place_intent.disconnect(a)
	sl.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE))

## Keys whose instruction moved into a tutorial step (Phase 186).
const REMOVED := ["hotbar.empty", "hotbar.more", "map.hint", "map.hint_tip", "chat.placeholder"]
const VERBS_EN := ["click", "right-click", "middle-click", "drag", "press", "hold", "scroll"]
const VERBS_PT := ["clique", "clicar", "arraste", "arrastar", "pressione", "pressionar", "segure", "segurar", "role ", "rolar", "botão direito", "botão do meio"]

func _test_catalog_audit() -> void:
	var cats: Dictionary = I18nScript.parse_csv("res://locale/ui.csv")["catalog"]
	for col in ["en", "pt_BR"]:
		for k in REMOVED:
			assert_false((cats[col] as Dictionary).has(k), "%s is gone from the %s column" % [k, col])
		for k in cats[col]:
			if str(k).begins_with("tutorial.") or str(k).begins_with("controls."):
				continue
			var text := str(cats[col][k]).to_lower()
			for v in (VERBS_EN if col == "en" else VERBS_PT):
				assert_false(_has_word(text, v), "%s (%s) has no instruction verb '%s'" % [k, col, v])
	for k in ["tutorial.dismiss", "tutorial.turn_off", "tutorial.done", "tutorial.counter", "tutorial.toggle", "tutorial.restart"]:
		assert_true((cats["en"] as Dictionary).has(k) and (cats["pt_BR"] as Dictionary).has(k), "%s is in both columns" % k)

func _has_word(text: String, word: String) -> bool:
	var i := text.find(word)
	while i >= 0:
		var before := text[i - 1] if i > 0 else " "
		var end := i + word.length()
		var after := text[end] if end < text.length() else " "
		if not ("a" <= before and before <= "z") and not ("a" <= after and after <= "z"):
			return true
		i = text.find(word, i + 1)
	return false

func _test_card() -> void:
	const Card := preload("res://src/tutorial/tutorial_card.gd")
	var sl := TutorialSlice.new()
	sl.path = FIXTURE
	add_child(sl)
	var card := Card.new()
	add_child(card)
	card.bind(sl)
	assert_true(card.visible, "a new player sees a card")
	assert_true(card._title.text != "" and card._title.text != "tutorial.move.title", "with the step's title")
	assert_true(card._counter.text.contains("1"), "and the step counter")
	var keys := Card.keys_for(sl.current_step(), UiSlice.controls_rows())
	assert_true(keys.contains("WASD"), "the move step names the player's move keys (%s)" % keys)
	assert_true(card._body.text.contains("WASD"), "the card body carries them")
	sl.set_enabled(false)
	assert_false(card.visible, "turning the tutorial off hides the card at once")
	sl.set_enabled(true)
	var box := VBoxContainer.new()
	add_child(box)
	Card.add_settings(box)
	assert_eq(box.get_child_count(), 2, "the ? panel gets a toggle and a Restart button")
	sl.free()
	card.free()
	box.free()
	Card.active = null
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE))

func _test_replay() -> void:
	var history := [
		{ "kind": "item_gathered", "params": { "item": "Thornwood", "tags": ["material"], "count": 3 } },
		{ "kind": "item_gathered", "params": { "item": "Thornwood", "tags": ["material"], "count": 2 } },
		{ "kind": "moved_metres", "params": { "metres": 4.0 } },
		{ "kind": "moved_metres", "params": { "metres": 7.0 } },
		{ "kind": "jumped", "params": {} },
		{ "kind": "camera_turned", "params": {} },
	]
	var done: Array = Rules.replay(history)
	for want in ["move", "jump", "look", "mine", "chop"]:
		assert_true(done.has(want), "%s completes from the recorded session" % want)
	assert_false(done.has("kill"), "a step with no matching event stays open")
	assert_eq(Rules.replay([]), [], "an empty session completes nothing")
