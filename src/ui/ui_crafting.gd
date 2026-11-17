extends RefCounted
## Phase 269 — crafting by hand, and at the station: the UI slice's half of the two crafting windows (the card
## projection both windows draw, and the station window's opening, title and reach). `sl` is the owning UiSlice;
## each method keeps a forwarder there.

const I18n := preload("res://src/core/i18n.gd")
const CraftCatalog := preload("res://src/crafting/craft_catalog.gd")
const CraftingSliceScript := preload("res://src/crafting/crafting_slice.gd")

var sl: Node

func _init(owner: Node) -> void:
	sl = owner

## Phase 269 — one card per recipe a crafting window lists: the known recipes needing exactly `type` ("" = the
## hand window), sorted by shown name: { id, name, icon_key, output, count, category, can_craft, reason,
## inputs: [{ item, name, icon_key, have, need, short }], skill, skill_name, work_seconds, max_quantity }.
## `have` follows the bag the host crafts from; a card the player cannot afford has `can_craft` false (dimmed).
func craft_cards(type: String) -> Array:
	var cards: Array = []
	if sl.crafting_slice == null:
		return cards
	var inv: Node = null
	if sl.crafting_slice.has_method("inventory_for"):
		inv = sl.crafting_slice.inventory_for(str(sl.crafting_slice.local_player_id()) if sl.crafting_slice.has_method("local_player_id") else "")
	if inv == null:
		inv = sl.inventory_slice
	var count_of := func(item: String) -> int: return int(inv.get_item_count(item)) if inv != null else 0
	var known := func(rid: String) -> bool: return bool(sl.crafting_slice.is_recipe_known(rid)) if sl.crafting_slice.has_method("is_recipe_known") else true
	for rid: String in CraftCatalog.recipe_ids_for(type, known):
		var out := CraftCatalog.output(rid)
		var check: Dictionary = sl.crafting_slice.can_craft(rid)
		var ins: Array = []
		for e: Dictionary in CraftCatalog.inputs(rid, count_of):
			ins.append(e.merged({ "name": I18n.content("item", str(e["item"])), "icon_key": sl.item_icon_key(str(e["item"])) }))
		var skill := CraftCatalog.trained_skill(rid)
		cards.append({
			"id": rid,
			"name": I18n.content("recipe", rid),
			"output": str(out.get("item", "")),
			"icon_key": sl.item_icon_key(str(out["item"])) if out.has("item") else "",
			"count": int(out.get("quantity", 1)),
			"category": CraftCatalog.category(rid),
			"can_craft": bool(check.get("success", false)),
			"reason": str(check.get("reason", "")),
			"inputs": ins,
			"skill": skill,
			"skill_name": I18n.content("skill", skill) if skill != "" else "",
			"work_seconds": CraftCatalog.work_seconds(rid),
			"max_quantity": CraftCatalog.max_quantity(rid, count_of),
		})
	cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var c := str(a["name"]).naturalnocasecmp_to(str(b["name"]))
		return c < 0 if c != 0 else str(a["id"]) < str(b["id"]))
	return cards

## Phase 269 — open the window of the placed crafting station `id`: it lists that station's recipes and is titled
## with its name. Refused (false) for an unknown station or one no recipe needs (a chest, a door, a bed).
func open_station_window(id: String) -> bool:
	if sl.station_slice == null or sl.station_window == null:
		return false
	var st: Dictionary = sl.station_slice.get_station(id)
	var type := str(st.get("type", ""))
	if st.is_empty() or not CraftCatalog.is_crafting_station(type):
		return false
	sl.station_id = id
	sl.station_type = type
	sl.station_window.station_type = type
	sl.station_window.selected = ""
	retitle("win.station")
	sl.open_window(sl.WINDOW_STATION)
	return true

## Phase 269 — the station window closes when its station is gone or the player at `pos` is out of its reach (the
## host's crafting radius, `CraftingSlice.STATION_RADIUS`). True when it closed.
func check_station_reach(pos: Vector3) -> bool:
	if sl.station_id == "" or not sl.is_window_open(sl.WINDOW_STATION):
		return false
	var st: Dictionary = sl.station_slice.get_station(sl.station_id) if sl.station_slice != null else {}
	if CraftCatalog.in_reach(st, pos, CraftingSliceScript.STATION_RADIUS):
		return false
	sl.close_window(sl.WINDOW_STATION)
	return true

## Re-apply the bound text of every control bound to `key` (a title whose arguments changed).
func retitle(key: String) -> void:
	for b in sl._bound:
		if b["key"] == key and is_instance_valid(b["node"]):
			var args_fn: Callable = b.get("args", Callable())
			(b["node"] as Control).set(b["prop"], I18n.t(key, args_fn.call() if args_fn.is_valid() else []))
