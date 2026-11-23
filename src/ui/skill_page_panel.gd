extends VBoxContainer
## Phase 272 — a skill's own page, beside the wheel: name, description, tier and XP with a bar to the next tier,
## what the next tiers unlock, what trains it, the professions it leads to, and the player's focus on it with the
## bonus it gives now, plus where the recent play time went by skill category. `show_skill` takes the skill id;
## everything it reads is a pure projection (`SkillPage`) and every word goes through `I18n`.

const I18n := preload("res://src/core/i18n.gd")
const SkillPage := preload("res://src/character/skill_page.gd")
const SkillFocus := preload("res://src/character/skill_focus.gd")
const GearTiers := preload("res://src/character/gear_tiers.gd")

const PAGE_WIDTH := 250.0
## Catalog key stems; the id is appended (a key built at run time, so the literal audit does not read it).
const TIER_KEY := "ui.tier_%s"
const UNLOCK_KEY := "ui.skill_page_unlock_%s"
const CATEGORY_KEY := "ui.category_%s"
const WORK_KEY := "ui.work.%s"
const ABILITY_KEY := "ui.ability.%s"
const CATEGORY_ORDER := ["combat", "crafting", "magic", "exploration", "social", "gathering", "other"]

var skill := ""
## Phase 229 — `Callable() -> Array`: the items the local player holds (main hand, off hand; "" bare), for the ability rows.
var weapon_provider: Callable = Callable()
var bar: ProgressBar = null
## Every label text on the page, for tests.
var lines: Array[String] = []

func _init() -> void:
	name = "SkillPage"
	# A combat skill's rows follow the wielded weapon: rebuild an open page when the gear changes.
	GameBus.held_item_synced.connect(_on_gear_changed)
	GameBus.equipment_changed.connect(_on_gear_changed)
	custom_minimum_size = Vector2(PAGE_WIDTH, 0)
	add_theme_constant_override("separation", 4)

func _label(text: String, size: int = 13) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(PAGE_WIDTH - 12.0, 0)
	l.add_theme_font_size_override("font_size", size)
	add_child(l)
	lines.append(text)
	return l

func clear_page() -> void:
	for c in get_children():
		remove_child(c)
		c.free()
	lines.clear()
	bar = null

func _on_gear_changed(_player_id: String, _what: Variant) -> void:
	if skill != "" and GearTiers.is_combat_skill(skill) and is_inside_tree():
		show_skill(skill)

## Show `skill_id`'s page from the local player's synced XP and focus.
func show_skill(skill_id: String) -> void:
	clear_page()
	skill = skill_id
	if skill_id == "":
		_label(I18n.t("ui.skill_page_hint"))
		return
	var wheel: Resource = GameData.WORLD_SYSTEMS.get("SkillWheel", null)
	var xp := int(SkillPage.local_xp.get(skill_id, 0))
	var p := SkillPage.page(skill_id, xp, SkillFocus.local_view, wheel)
	_label(I18n.content("skill", skill_id), 18)
	_label(I18n.content("skill", skill_id, "desc"))
	_label(I18n.t("ui.skill_page_level", [I18n.t(TIER_KEY % str(p["tier"])), I18n.number(xp)]))
	bar = ProgressBar.new()
	bar.step = 0.0
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = float(p["progress"])
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(PAGE_WIDTH - 12.0, 14)
	add_child(bar)
	if int(p["next_floor"]) < 0:
		_label(I18n.t("ui.skill_page_maxed"))
	else:
		_label(I18n.t("ui.skill_page_progress", [I18n.number(xp - int(p["level_floor"])), I18n.number(int(p["next_floor"]) - int(p["level_floor"]))]))
	if not (p["next_unlocks"] as Array).is_empty():
		_label(I18n.t("ui.skill_page_next"), 15)
		for u: Dictionary in p["next_unlocks"]:
			_label(I18n.t(UNLOCK_KEY % str(u["kind"]), [I18n.t(TIER_KEY % str(u["tier"]))]))
	if GearTiers.is_combat_skill(skill_id):
		# Phase 229 — each ability with its tier; one the skill or the wielded weapon cannot reach says what it needs.
		_label(I18n.t("ui.skill_page_abilities"), 15)
		var weapon: Variant = weapon_provider.call() if weapon_provider.is_valid() else ""
		for r: Dictionary in GearTiers.ability_rows(skill_id, str(p["tier"]), weapon):
			var line := I18n.t("ui.skill_page_ability", [I18n.t(ABILITY_KEY % str(r["ability"])), I18n.t(TIER_KEY % str(r["tier"]))])
			if not bool(r["available"]):
				line = I18n.t("ui.skill_page_ability_refused", [line, I18n.reason_text(str(r["reason"]))])
			var l := _label(line)
			if not bool(r["available"]):
				l.modulate = Color(0.6, 0.6, 0.6)
	if not (p["trainers"] as Array).is_empty():
		_label(I18n.t("ui.skill_page_trains"), 15)
		_label(", ".join((p["trainers"] as Array).map(func(k): return I18n.t(WORK_KEY % str(k)))))
	if not (p["professions"] as Array).is_empty():
		_label(I18n.t("ui.skill_page_leads"), 15)
		_label(", ".join((p["professions"] as Array).map(func(k): return I18n.content("profession", str(k)))))
	_label(I18n.t("ui.skill_page_focus_title"), 15)
	if int(p["focus_minutes"]) <= 0:
		_label(I18n.t("ui.skill_page_focus_none"))
	else:
		_label(I18n.t("ui.skill_page_focus", [I18n.number(int(p["focus_minutes"])), I18n.number(float(p["focus_bonus"]) * 100.0, 1)]))
	var shares := SkillPage.category_shares(SkillFocus.local_view)
	if not shares.is_empty():
		_label(I18n.t("ui.skill_page_shares"), 15)
		for c in CATEGORY_ORDER:
			if shares.has(c):
				_label(I18n.t("ui.skill_page_share", [I18n.t(CATEGORY_KEY % str(c)), I18n.number(float(shares[c]) * 100.0)]))
