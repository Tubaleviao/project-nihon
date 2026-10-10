extends HBoxContainer
## Skill bar — a few boxes in the top-right corner, one per skill, fired by the number keys
## (1 is the first box, 2 the second, and so on).
##
## The boxes list the player's skills, best tier first, so the strongest are under the lowest
## numbers. Pressing a number (or clicking a box) emits `GameBus.skill_slot_triggered`; what a
## skill DOES is owned by the slice that implements its behaviors, not by this bar. The bar
## flashes the box so the press always has visible feedback.
##
## Pure, headless-testable statics: `ordered`, `slot_for_keycode`, `label_for`.

const SkillTiers := preload("res://src/core/skill_tiers.gd")

const SLOT_COUNT := 5
const SLOT_PX := 48.0
const FLASH_SECONDS := 0.18

## Skill key per box ("" = empty). Fixed length SLOT_COUNT.
var slots: Array = []
## `Callable() -> Dictionary` of skill key -> tier name; set by the UI slice.
var tier_provider: Callable = Callable()

var _buttons: Array = []

func _init() -> void:
	name = "SkillBar"
	add_theme_constant_override("separation", 4)
	alignment = BoxContainer.ALIGNMENT_END
	for i in SLOT_COUNT:
		slots.append("")

func build() -> void:
	for i in SLOT_COUNT:
		var b := Button.new()
		b.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(trigger.bind(i))
		add_child(b)
		_buttons.append(b)
	refresh()

# ---------------------------------------------------------------------------
# Pure helpers
# ---------------------------------------------------------------------------

## The first `count` skill keys of `tiers` (key -> tier), highest tier first, ties by name.
static func ordered(tiers: Dictionary, count: int) -> Array:
	var keys: Array = tiers.keys().map(func(k): return str(k))
	keys.sort_custom(func(a, b):
		var ra := SkillTiers.rank(str(tiers.get(a, "novice")))
		var rb := SkillTiers.rank(str(tiers.get(b, "novice")))
		return ra > rb if ra != rb else a < b)
	return keys.slice(0, count)

## The box a key press fires: KEY_1 -> 0 ... KEY_5 -> 4, or -1 for any other key.
static func slot_for_keycode(keycode: int) -> int:
	var idx := keycode - KEY_1
	return idx if idx >= 0 and idx < SLOT_COUNT else -1

static func label_for(skill: String, index: int) -> String:
	return "%d\n%s" % [index + 1, skill.substr(0, 4)] if skill != "" else "%d" % (index + 1)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

func refresh() -> void:
	var tiers: Dictionary = tier_provider.call() if tier_provider.is_valid() else {}
	slots = ordered(tiers, SLOT_COUNT)
	while slots.size() < SLOT_COUNT:
		slots.append("")
	for i in _buttons.size():
		var b: Button = _buttons[i]
		var skill := str(slots[i])
		b.text = label_for(skill, i)
		b.tooltip_text = ("%s (%s) — press %d" % [skill, tiers.get(skill, "novice"), i + 1]) if skill != "" else "Empty skill box"

## Fire box `index`. Returns the skill key fired, or "" for an empty box.
func trigger(index: int) -> String:
	if index < 0 or index >= SLOT_COUNT or str(slots[index]) == "":
		return ""
	var skill := str(slots[index])
	GameBus.skill_slot_triggered.emit(index, skill)
	_flash(index)
	return skill

func _flash(index: int) -> void:
	if index >= _buttons.size() or not is_inside_tree():
		return
	var b: Button = _buttons[index]
	b.modulate = Color(1.6, 1.5, 0.8)
	var t := create_tween()
	t.tween_property(b, "modulate", Color.WHITE, FLASH_SECONDS)
