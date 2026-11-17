extends RefCounted
## Station placement rules (Phase 268) — pure reads of the fabric's `StationPlacement` world system: every
## placeable station type's placement item, the reverse lookup (which type an item places), the pick-up reach and
## the 90° rotation steps. No state: `StationSlice` holds the placed stations.

## A placed station turns in quarter turns: 0..3.
const ROTATIONS := 4

static func rules() -> Dictionary:
	var res: Resource = GameData.WORLD_SYSTEMS.get("StationPlacement", null)
	var r: Variant = res.get("rules") if res != null else null
	return r if r is Dictionary else {}

static func _stations() -> Dictionary:
	var s: Variant = rules().get("stations", {})
	return s if s is Dictionary else {}

## Every type the table names, sorted.
static func station_types() -> Array:
	var out: Array = _stations().keys()
	out.sort()
	return out

## The item one placement of `type` consumes ("" for a type the table does not name).
static func placement_item(type: String) -> String:
	var row: Variant = _stations().get(type, {})
	return str((row as Dictionary).get("placementItem", "")) if row is Dictionary else ""

## The station type `item_id` places, or "" when it is no placement item.
static func type_for_item(item_id: String) -> String:
	if item_id == "":
		return ""
	var st := _stations()
	for t: String in st:
		if st[t] is Dictionary and str((st[t] as Dictionary).get("placementItem", "")) == item_id:
			return t
	return ""

static func is_station_item(item_id: String) -> bool:
	return type_for_item(item_id) != ""

## How close (metres) an owner stands to pick up a placed station.
static func pickup_reach() -> float:
	var pu: Variant = rules().get("pickUp", {})
	return float((pu as Dictionary).get("reachMetres", 4.0)) if pu is Dictionary else 4.0

## A rotation from the wire: an int or float in 0..3, anything else 0.
static func clean_rotation(v: Variant) -> int:
	if (v is int or v is float) and is_finite(float(v)):
		return posmod(int(v), ROTATIONS)
	return 0

## The next quarter turn after `rot`.
static func next_rotation(rot: int) -> int:
	return posmod(rot + 1, ROTATIONS)
