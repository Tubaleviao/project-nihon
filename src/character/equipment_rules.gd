class_name EquipmentRules
extends RefCounted
## Pure equipment rules (ROADMAP Phase 47): which slots the fabric defines, whether
## an item fits a slot, and the stat totals a worn set adds up to.
##
## Every number is a fabric field summed here (`defense` on the equippable item);
## nothing in this file authors a stat. Static and headless-testable, so the host's
## player registry can validate a peer's claimed set without a CharacterSlice.

const GameDataReader := preload("res://src/core/game_data_reader.gd")

## Fabric fields summed into the Character window's totals. Each is read with
## `GameDataReader.int_field`, so an item without the field contributes zero.
const SUMMED_FIELDS: Array = ["defense"]


## The slot an item equips into, or "" when the key is unknown / not equippable.
static func slot_of(item_key: String, items: Dictionary = {}) -> String:
	var table: Dictionary = items if not items.is_empty() else GameData.ITEMS
	var res: Resource = table.get(item_key, null)
	if res == null:
		return ""
	return GameDataReader.str_field(res, "equipmentSlot", "")


## Every distinct `equipmentSlot` the fabric defines, in a stable (sorted) order.
static func slots(items: Dictionary = {}) -> Array:
	var table: Dictionary = items if not items.is_empty() else GameData.ITEMS
	var seen: Dictionary = {}
	for key in table:
		var slot := slot_of(str(key), table)
		if slot != "":
			seen[slot] = true
	var out: Array = seen.keys()
	out.sort()
	return out


## Keep only entries of `claimed` ({slot: item_key}) whose item exists and fits that
## slot. A claim is evidence about nothing until it passes this: unknown slots,
## unknown items and items in the wrong slot are dropped.
static func sanitize(claimed: Variant, items: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	if not (claimed is Dictionary):
		return out
	for slot in claimed:
		var item_key := str(claimed[slot])
		if item_key != "" and slot_of(item_key, items) == str(slot):
			out[str(slot)] = item_key
	return out


## Sum the fabric values of a worn set. An empty set reports every field as zero.
static func totals(worn: Dictionary, items: Dictionary = {}) -> Dictionary:
	var table: Dictionary = items if not items.is_empty() else GameData.ITEMS
	var out: Dictionary = {}
	for field in SUMMED_FIELDS:
		out[field] = 0
	for slot in worn:
		var res: Resource = table.get(str(worn[slot]), null)
		if res == null:
			continue
		for field in SUMMED_FIELDS:
			out[field] = int(out[field]) + GameDataReader.int_field(res, field, 0)
	return out


## Whether the MainHand holds something (the fabric's bare-hands rule reads this).
static func hands_free(worn: Dictionary) -> bool:
	return str(worn.get("MainHand", "")) == ""
