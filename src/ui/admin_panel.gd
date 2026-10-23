extends VBoxContainer
## Admin window (Phase 182) — weather, time of day, speed, flying and healing for an admin. Presentation
## only: every control types the matching chat command (`/weather`, `/time`, `/speed`, `/fly`, `/heal`)
## as a `GameBus.chat_intent`, so the host checks and runs it exactly as if it had been typed, and its
## reply lands in the chat log. All text goes through `I18n`.

const I18n := preload("res://src/core/i18n.gd")
const AdminRules := preload("res://src/admin/admin_rules.gd")

## Fallback when the fabric names no weather states (a rig without GameData).
const DEFAULT_STATES := ["clear", "rain"]
const DEFAULT_WEATHER_HOURS := 6

var _weather_pick: OptionButton = null
var _weather_hours: SpinBox = null
var _hour: SpinBox = null
var _speed: SpinBox = null
var _bound: Array = []   # [Node, property, i18n key]
var _confirm: ConfirmationDialog = null
const REGEN_COMMAND := "/regen world confirm"
## The commands this panel sent, newest last (the suite reads it; bounded).
var sent: Array = []
const SENT_KEEP := 16

func _init() -> void:
	add_theme_constant_override("separation", 6)
	# Weather: a state for some in-game hours, on the admin's own weather cell.
	_label("admin.weather")
	var w_row := HBoxContainer.new()
	add_child(w_row)
	_weather_pick = OptionButton.new()
	for id: String in weather_states():
		_weather_pick.add_item(weather_label(id))
		_weather_pick.set_item_metadata(_weather_pick.item_count - 1, id)
	w_row.add_child(_weather_pick)
	_weather_hours = _spin(1, 48, 1, DEFAULT_WEATHER_HOURS, w_row)
	_button("admin.set", func() -> void: run(weather_command(_picked_state(), int(_weather_hours.value))), w_row)
	# Time of day: jump to an hour, or skip one.
	_label("admin.time")
	var t_row := HBoxContainer.new()
	add_child(t_row)
	_hour = _spin(0, 23, 1, 12, t_row)
	_button("admin.set", func() -> void: run(time_command(int(_hour.value))), t_row)
	_button("admin.skip_hour", func() -> void: run("/time +1"), t_row)
	# Speed and flying.
	_label("admin.speed")
	var s_row := HBoxContainer.new()
	add_child(s_row)
	_speed = _spin(AdminRules.SPEED_MIN, AdminRules.SPEED_MAX, 0.1, 1.0, s_row)
	_button("admin.set", func() -> void: run(speed_command(_speed.value)), s_row)
	_button("admin.reset", func() -> void: run(speed_command(1.0)), s_row)
	var m_row := HBoxContainer.new()
	add_child(m_row)
	_button("admin.fly", func() -> void: run("/fly"), m_row)
	_button("admin.heal", func() -> void: run("/heal"), m_row)
	# Regenerating the world asks first; the host asks again unless the command says `confirm`.
	_confirm = ConfirmationDialog.new()
	_confirm.dialog_text = I18n.t("admin.regen_ask")
	_confirm.dialog_autowrap = true
	_confirm.min_size = Vector2i(420, 0)
	_bound.append([_confirm, "dialog_text", "admin.regen_ask"])
	_confirm.confirmed.connect(func() -> void: run(REGEN_COMMAND))
	add_child(_confirm)
	_button("admin.regen", func() -> void: _confirm.popup_centered(), self)

func _ready() -> void:
	GameBus.locale_changed.connect(func(_l: String) -> void: relocalize())

## Send `command` to the host as if it had been typed.
func run(command: String) -> void:
	sent.append(command)
	if sent.size() > SENT_KEEP:
		sent.pop_front()
	GameBus.chat_intent.emit(command, "")

## The language changed: re-render every label and the weather names.
func relocalize() -> void:
	for b: Array in _bound:
		(b[0] as Object).set(str(b[1]), I18n.t(str(b[2])))
	for i in _weather_pick.item_count:
		_weather_pick.set_item_text(i, weather_label(str(_weather_pick.get_item_metadata(i))))

# ---------------------------------------------------------------- pure

## The fabric's weather state ids, sorted (the ids `/weather` takes).
static func weather_states() -> Array:
	var res: Variant = GameData.WORLD_SYSTEMS.get("WeatherSystem", null)
	var rules: Variant = res.get("rules") if res != null else null
	var states: Variant = (rules as Dictionary).get("states", null) if rules is Dictionary else null
	if not (states is Dictionary) or (states as Dictionary).is_empty():
		return DEFAULT_STATES.duplicate()
	var ids: Array = (states as Dictionary).keys()
	ids.sort()
	return ids

## A state's name in the player's language (its id when the catalog has no name for it).
static func weather_label(id: String) -> String:
	var key := "weather.state." + id
	var text := I18n.t(key)
	return id if text == key else text

static func weather_command(state: String, hours: int) -> String:
	return "/weather %s %d" % [state, hours]

static func time_command(hour: int) -> String:
	return "/time %02d:00" % clampi(hour, 0, 23)

static func speed_command(factor: float) -> String:
	return "/speed %s" % str(snappedf(clampf(factor, AdminRules.SPEED_MIN, AdminRules.SPEED_MAX), 0.1))

# ---------------------------------------------------------------- building

func _picked_state() -> String:
	return str(_weather_pick.get_item_metadata(_weather_pick.selected)) if _weather_pick.item_count > 0 else ""

func _label(key: String) -> void:
	var l := Label.new()
	l.text = I18n.t(key)
	_bound.append([l, "text", key])
	add_child(l)

func _button(key: String, on_press: Callable, parent: Control) -> void:
	var b := Button.new()
	b.text = I18n.t(key)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	_bound.append([b, "text", key])
	parent.add_child(b)

func _spin(lo: float, hi: float, step: float, value: float, parent: Control) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	parent.add_child(s)
	return s
