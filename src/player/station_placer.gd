extends RefCounted
## Station placer (Phase 268) — the player's side of placing a station from the hotbar. A station item in the
## selected hotbar box arms it: every frame the ghost follows the aimed spot, tinted by the same `place_refusal`
## the host checks; the use input (left click) sends one `station_intent` "place" with the item, the offset from
## the body and the ghost's rotation (R turns it); B asks to pick up the nearest station in reach. The host
## decides everything (`StationWiring`); nothing is placed here.

const StationRules := preload("res://src/world/station_rules.gd")
const I18n := preload("res://src/core/i18n.gd")

## The station item in the selected hotbar box ("" when the box holds anything else).
var item: String = ""
## The ghost's quarter turns (0..3).
var rotation: int = 0
## The refusal the ghost showed last frame ("" = placeable).
var refusal: String = ""
## Whether the ghost was shown last frame.
var showing: bool = false

## The hotbar selection changed: arm on a station item, disarm on anything else.
func select(item_id: String) -> void:
	item = item_id if StationRules.is_station_item(item_id) else ""
	if item == "":
		rotation = 0

## The station type of the armed item ("" when not armed).
func station_type() -> String:
	return StationRules.type_for_item(item)

## Armed with an item the pack still holds.
func is_armed(inventory: Node) -> bool:
	return item != "" and inventory != null and inventory.has_method("get_item_count") and int(inventory.get_item_count(item)) > 0

func rotate() -> int:
	rotation = StationRules.next_rotation(rotation)
	return rotation

## One frame: show the ghost at `target` (tinted by the refusal the host would give) while armed and `allowed`,
## else hide it. Returns the refusal shown ("" placeable, "-" hidden).
func update(station_slice: Node, inventory: Node, target: Vector3, player_id: String, allowed: bool) -> String:
	if station_slice == null:
		return "-"
	if not allowed or not is_armed(inventory):
		if showing:
			station_slice.hide_preview()
		showing = false
		refusal = "-"
		return refusal
	refusal = str(station_slice.place_refusal(station_type(), target, inventory, player_id))
	station_slice.show_preview(station_type(), target, rotation, refusal)
	showing = true
	return refusal

## The use input: one placement request for the armed item at `target`, from a body at `body`. False when not armed.
func request(inventory: Node, target: Vector3, body: Vector3) -> bool:
	if not is_armed(inventory):
		return false
	var off := target - body
	GameBus.station_intent.emit("place", { "item": item, "ox": off.x, "oy": off.y, "oz": off.z, "rot": rotation }, "")
	return true

## B: ask to pick up the nearest placed station within reach of `body` (the host checks it is ours and near).
static func request_pick_up(station_slice: Node, body: Vector3) -> String:
	if station_slice == null:
		return ""
	var best := ""
	var best_d := StationRules.pickup_reach()
	for s: Dictionary in station_slice.get_all_stations():
		var d: float = (s["position"] as Vector3).distance_to(body)
		if d <= best_d:
			best_d = d
			best = str(s["id"])
	if best != "":
		GameBus.station_intent.emit("pick_up", { "id": best }, "")
	return best

## The HUD line while armed: the station's name, the turn and, when refused, why.
func hint() -> String:
	if item == "" or refusal == "-":
		return ""
	var text := I18n.t("hud.station_place", [station_name(station_type())])
	if refusal != "":
		text += "  (%s)" % I18n.reason_text(refusal)
	return text

## A station type's player-facing name (Phase 267: the content catalog's `station.<type>.name`).
static func station_name(type: String) -> String:
	return I18n.content("station", type)
