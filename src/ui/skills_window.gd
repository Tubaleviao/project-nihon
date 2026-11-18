extends VBoxContainer
## Phase 272 — the skills window: the wheel (Phase 271) with the selected skill's page beside it. Selecting a node
## opens its skill's page; `open_skill` does the same for the toast that announces a newly reached tier.

const SkillWheelView := preload("res://src/ui/skill_wheel_view.gd")
const SkillPagePanel := preload("res://src/ui/skill_page_panel.gd")
const SkillWheelLayout := preload("res://src/ui/skill_wheel_layout.gd")

var wheel: Control = null
var page: Control = null

func _init() -> void:
	add_theme_constant_override("separation", 6)

## `title_node` and `fit_button` are made by the caller (they carry the translation hooks).
func build(title_node: Control, fit_button: Button) -> void:
	var bar := HBoxContainer.new()
	title_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title_node)
	bar.add_child(fit_button)
	add_child(bar)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wheel = SkillWheelView.new()
	wheel.custom_minimum_size = Vector2(620, 560)
	wheel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wheel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fit_button.pressed.connect(wheel.fit_all)
	wheel.node_selected.connect(func(id: String) -> void: show_skill_of_node(id))
	row.add_child(wheel)
	var scroll := ScrollContainer.new()
	scroll.name = "SkillPageScroll"
	scroll.custom_minimum_size = Vector2(SkillPagePanel.PAGE_WIDTH + 16.0, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page = SkillPagePanel.new()
	scroll.add_child(page)
	row.add_child(scroll)
	add_child(row)
	page.show_skill("")

func show_skill_of_node(node_id: String) -> void:
	var n: Variant = SkillWheelLayout.fabric_nodes().get(node_id, null)
	page.show_skill(str(n["skill"]) if n is Dictionary else "")

## Open a skill's page (the unlock toast) and mark its node on the wheel.
func open_skill(skill: String) -> void:
	page.show_skill(skill)
