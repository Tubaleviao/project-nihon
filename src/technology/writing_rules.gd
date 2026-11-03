extends RefCounted
## Writing rules (Phase 209) — pure reads of the fabric's writing items (`fabric/gameplay/items/writings.js`) and
## their rules (`GameData.WRITINGS`: Book, Blueprint). No state: `WritingSlice` resolves the intents and
## `TechnologySlice` holds what each player knows.

## What a writing item teaches: { writing, teaches, kind } ("technology", "station" or "project"), or {} when
## `item_id` is not a writing item.
static func of(item_id: String) -> Dictionary:
	var res: Resource = GameData.ITEMS.get(item_id, null)
	if res == null or not ("writing" in res) or not GameData.WRITINGS.has(str(res.get("writing"))):
		return {}
	return { "writing": str(res.get("writing")), "teaches": str(res.get("teaches")), "kind": str(res.get("teachesKind")) }

static func is_writing(item_id: String) -> bool:
	return not of(item_id).is_empty()

## Every writing item key, sorted.
static func items() -> Array:
	var out: Array = []
	for k: String in GameData.ITEMS:
		if is_writing(k):
			out.append(k)
	out.sort()
	return out

## The writing item that teaches `key`, or "".
static func item_for(key: String) -> String:
	for k: String in items():
		if str(of(k)["teaches"]) == key:
			return k
	return ""

static func rules(writing: String) -> Dictionary:
	var res: Resource = GameData.WRITINGS.get(writing, null)
	var r: Variant = res.get("rules") if res != null else null
	return r if r is Dictionary else {}

## The station a writing is written at ("" = anywhere).
static func station(writing: String) -> String:
	return str(rules(writing).get("station", ""))

## The material cost as { item: quantity }.
static func cost(writing: String) -> Dictionary:
	var out := {}
	for c: Variant in rules(writing).get("cost", []):
		if c is Dictionary:
			var item := str(c.get("item", ""))
			out[item] = int(out.get(item, 0)) + int(c.get("quantity", 1))
	return out
