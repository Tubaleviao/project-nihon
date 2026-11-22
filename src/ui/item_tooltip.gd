extends RefCounted
## Inventory tooltip text for an item that is equipment (Phase 296), kept out of `ui_slice.gd` for the line cap.

const I18n := preload("res://src/core/i18n.gd")
const EquipmentRules := preload("res://src/character/equipment_rules.gd")


## Phase 296 — the equipment lines of an item's tooltip: its category, its traits (with their grades) and what it can
## do, all from the content catalog in the active locale; "" for an item that is not equipment.
static func equipment_lines(item_id: String) -> String:
	var spec := EquipmentRules.spec_of(item_id)
	if spec.is_empty():
		return ""
	var out := I18n.t("ui.tip_category", [I18n.content("equipment", str(spec["category"]))])
	var traits: Array = []
	var own: Dictionary = spec.get("traits", {})
	for tr in own:
		var name := I18n.content("trait", str(tr))
		var grade := str((own[tr] as Dictionary).get("grade", "")) if own[tr] is Dictionary else ""
		traits.append(I18n.t("ui.tip_trait_grade", [name, I18n.content("grade", grade)]) if grade != "" else name)
	if not traits.is_empty():
		out += I18n.t("ui.tip_traits", [", ".join(traits)])
	var works: Array = []
	for w in EquipmentRules.works_of(item_id):
		works.append(I18n.content("work", str(w)))
	if not works.is_empty():
		out += I18n.t("ui.tip_can_do", [", ".join(works)])
	return out
