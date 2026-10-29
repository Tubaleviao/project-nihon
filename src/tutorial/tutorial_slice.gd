extends Node
## Tutorial slice (Phase 186) — the first-steps tutorial on this machine. It holds the player's state
## (`TutorialState`), completes steps from events (`note_event`, fed by `TutorialWiring`) and offers the
## current step to the card. Client-side only: it emits no intent and sends nothing to the host.
##
## Plug contract (GameBus): OUT : tutorial_changed()   (a notification for the card, not an intent)

const Rules := preload("res://src/tutorial/tutorial_rules.gd")
const State := preload("res://src/tutorial/tutorial_state.gd")

var state: Dictionary = State.fresh()
## Where the state is saved; "" is the shared settings file. A test points it at a fixture.
var path: String = ""
var _table: Array = []
## Metres walked, so a `moved_metres` trigger counts the distance rather than one step.
var _metres: float = 0.0
var _gathered_items: Dictionary = {}   ## item -> count gathered this session
var _gathered_tags: Dictionary = {}    ## tag -> count gathered this session
## Every event seen this session, oldest first and capped (`TutorialRules.replay` reads it).
var history: Array = []
const MAX_HISTORY := 600

func load_saved() -> void:
	state = State.load_state(path)
	GameBus.tutorial_changed.emit()

## True while nothing has been done or dismissed (a new install, or just after a restart).
func is_fresh() -> bool:
	return (state["done"] as Array).is_empty() and (state["dismissed"] as Array).is_empty()

func steps() -> Array:
	return _table if not _table.is_empty() else Rules.steps()

func current_step() -> Dictionary:
	return Rules.next_step(state, steps())

func is_done(id: String) -> bool:
	return (state["done"] as Array).has(id)

## Mark `ids` done without showing them (a veteran's existing progress).
func mark_done_silently(ids: Array) -> void:
	var changed := false
	for id in ids:
		if not is_done(str(id)):
			(state["done"] as Array).append(str(id))
			changed = true
	if changed:
		_commit()

## An event the client saw. Completes every eligible step it matches (the card's and any other whose `requires`
## are done); returns the first completed id, else "".
func note_event(kind: String, params: Dictionary = {}) -> String:
	if kind == "moved_metres" and not history.is_empty() and str(history.back()["kind"]) == kind:
		history.back()["params"]["metres"] = float(history.back()["params"]["metres"]) + float(params.get("metres", 0.0))
	elif history.size() < MAX_HISTORY:
		history.append({ "kind": kind, "params": params.duplicate(true) })
	if kind == "moved_metres":
		_metres += float(params.get("metres", 0.0))
	elif kind == "item_gathered":
		var n := int(params.get("count", 1))
		_gathered_items[str(params.get("item", ""))] = int(_gathered_items.get(str(params.get("item", "")), 0)) + n
		for tg in params.get("tags", []):
			_gathered_tags[str(tg)] = int(_gathered_tags.get(str(tg), 0)) + n
	var first := ""
	for step in Rules.eligible(state, steps()):
		var p := params
		if kind == "moved_metres":
			p = { "metres": _metres }
		elif kind == "item_gathered":
			var t: Dictionary = step["trigger"]
			p = params.duplicate()
			p["count"] = int(_gathered_items.get(str(t["item"]), 0)) if t.has("item") else int(_gathered_tags.get(str(t.get("tag", "")), 0))
		if Rules.event_completes(step, kind, p):
			(state["done"] as Array).append(str(step["id"]))
			first = first if first != "" else str(step["id"])
	if first != "":
		_commit()
	return first

func dismiss_current() -> void:
	var step := current_step()
	if step.is_empty():
		return
	(state["dismissed"] as Array).append(str(step["id"]))
	_commit()

func set_enabled(on: bool) -> void:
	state["enabled"] = on
	_commit()

## Forget all progress and turn the tutorial back on.
func restart() -> void:
	state = State.fresh()
	_metres = 0.0
	history.clear()
	_gathered_items.clear()
	_gathered_tags.clear()
	_commit()

func _commit() -> void:
	State.save_state(state, path)
	GameBus.tutorial_changed.emit()
