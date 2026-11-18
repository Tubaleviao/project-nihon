extends VBoxContainer
## Phase 272 — the skills window: the wheel (Phase 271) with the selected skill's page beside it. Selecting a node
## opens its skill's page; `open_skill` does the same for the toast that announces a newly reached tier.

const SkillWheelView := preload("res://src/ui/skill_wheel_view.gd")
const SkillPagePanel := preload("res://src/ui/skill_page_panel.gd")
const SkillFocus := preload("res://src/character/skill_focus.gd")
const SkillPage := preload("res://src/character/skill_page.gd")
const I18n := preload("res://src/core/i18n.gd")
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

## Open a skill's page (the unlock toast) and mark `node_id` on the wheel (selecting it shows the page, so both agree).
func open_skill(skill: String, node_id: String = "") -> void:
	if node_id != "" and wheel.nodes.has(node_id):
		wheel.select(node_id)
	else:
		page.show_skill(skill)

## A tier was reached: open its page and pulse its node.
func announce(skill: String, tier: String) -> void:
	open_skill(skill, "%s:%s" % [skill, tier])
	wheel.pulse("%s:%s" % [skill, tier])

## The wheel shows where the recent play time went: professions glow by share, the centre lists the leading skills.
func refresh_focus() -> void:
	var res: Resource = GameData.WORLD_SYSTEMS.get("SkillWheel", null)
	var prof_skills: Dictionary = res.get("professionSkills") if res != null else {}
	var view: Dictionary = SkillFocus.local_view
	var total := 0
	for s in view:
		total += int(view[s])
	var skills: Array = view.keys()
	skills.sort_custom(func(a, b): return int(view[a]) > int(view[b]) or (int(view[a]) == int(view[b]) and str(a) < str(b)))
	var lines: Array[String] = []
	for s in skills.slice(0, 3):
		lines.append(I18n.t("ui.skill_wheel_focus_line", [I18n.content("skill", str(s)), I18n.number(float(view[s]) / float(maxi(1, total)) * 100.0)]))
	var text := ""
	if not lines.is_empty():
		text = I18n.t("ui.skill_wheel_focus_title") + "\n" + "\n".join(lines)
	wheel.set_focus(SkillPage.profession_shares(view, prof_skills), text)
