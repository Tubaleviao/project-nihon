class_name Holdables
extends RefCounted
## Phase 176 — every id that can sit in an inventory slot, from the generated fabric data: items,
## materials mined or felled into the pack, and the outputs of the creatures' harvest tables.
## `tools/holdables.py` reads the same three sets for the icon generator; the suite checks the two
## agree by requiring an icon file for each id here and no icon file for any other id.

## Sorted, unique ids of everything a stack can be.
static func ids() -> Array:
	var seen := {}
	for id in GameData.ITEMS:
		seen[str(id)] = true
	for id in GameData.MATERIALS:
		seen[str(id)] = true
	for id in drop_ids():
		seen[id] = true
	var out: Array = seen.keys()
	out.sort()
	return out

## Item ids named by any creature's harvest table (`drops`) or taming `yields`, sorted and unique.
static func drop_ids() -> Array:
	var seen := {}
	for creature in GameData.CREATURES.values():
		for entry in creature.drops:
			var item := str(entry.get("item", ""))
			if item != "":
				seen[item] = true
		var tame = creature.get("tame")
		if not (tame is Dictionary):
			continue
		for entry in tame.get("yields", []):
			var item := str(entry.get("item", ""))
			if item != "":
				seen[item] = true
	var out: Array = seen.keys()
	out.sort()
	return out
