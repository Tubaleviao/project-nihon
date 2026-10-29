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
var _gathered: Dictionary = {}   ## tag -> count gathered since the current step began

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

## An event the client saw. Completes the current step when it matches; returns its id, else "".
## Only the step on the card completes, so a step never finishes before the player is shown it.
func note_event(kind: String, params: Dictionary = {}) -> String:
	if kind == "moved_metres":
		_metres += float(params.get("metres", 0.0))
		params = { "metres": _metres }
	var step := current_step()
	if step.is_empty():
		return ""
	if kind == "item_gathered":
		var tags: Array = params.get("tags", [])
		for tg in tags:
			_gathered[str(tg)] = int(_gathered.get(str(tg), 0)) + int(params.get("count", 1))
		params = params.duplicate()
		params["count"] = _gathered.get(str(step["trigger"].get("tag", "")), 0) if step["trigger"].has("tag") \
			else int(params.get("count", 1))
	if not Rules.event_completes(step, kind, params):
		return ""
	(state["done"] as Array).append(str(step["id"]))
	_gathered.clear()
	_commit()
	return str(step["id"])

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
	_gathered.clear()
	_commit()

func _commit() -> void:
	State.save_state(state, path)
	GameBus.tutorial_changed.emit()
