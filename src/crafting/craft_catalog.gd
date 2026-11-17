extends RefCounted
## Phase 269 — crafting by hand, and at the station: the pure half of the two crafting windows.
##
## The hand window (the crafting shortcut) lists the recipes with no station; a station's window (the interact
## input on a placed station) lists that station's recipes. Both list only recipes the player knows (technology,
## discovery or a blueprint); a known recipe the player cannot afford is dimmed by the window, never hidden.
## Everything here is read from the fabric recipes (`GameData.RECIPES`, their structured `recipe` field) and the
## items they make; nothing authors content. The host's own station check (`CraftingSlice._check_station_gate`)
## is unchanged: these lists only stop the window offering what the host would refuse.

const GameDataReader := preload("res://src/core/game_data_reader.gd")
const WorkSkills := preload("res://src/character/work_skills.gd")
const StationRules := preload("res://src/world/station_rules.gd")

## The category tabs, in tab order. A recipe's category is the one its structured `recipe` field names
## (`category`), else the category of what it makes (see `category`).
const CATEGORIES := ["tools", "weapons", "armor", "building", "consumables", "materials"]
## Item shapes that are weapons when the item names no equipment slot of its own.
const WEAPON_ARCHETYPES := ["sword", "longsword", "bow"]
const CONSUMABLE_ARCHETYPES := ["potion"]
## How near a placed station must be for the interact input to open its window: the reach a chest or door is
## used from (`ChestSlice.REACH_M`), so the nearer of a station and a chest is the one the key uses.
const INTERACT_REACH := 3.0
## The most crafts one press of the Craft button asks for: each is one craft request, and a client's burst must stay
## well inside the host's per-peer rate bucket (`NetworkingSlice.RATE_BUCKET_CAPACITY`).
const MAX_QUANTITY := 20

## The structured `recipe` field of `recipe_id` ({} when unknown or malformed).
static func recipe(recipe_id: String) -> Dictionary:
	var res: Resource = GameData.RECIPES.get(recipe_id, null)
	if res == null:
		return {}
	var v: Variant = GameDataReader.json_field(res, "recipe", {})
	return v if v is Dictionary else {}

## The station type a recipe needs ("" = made by hand, anywhere).
static func station_of(recipe_id: String) -> String:
	return str(recipe(recipe_id).get("station", ""))

## Every station type some recipe needs, sorted: the stations whose window lists recipes.
static func crafting_station_types() -> Array:
	var seen := {}
	for rid in GameData.RECIPES:
		var st := station_of(str(rid))
		if st != "":
			seen[st] = true
	var out: Array = seen.keys()
	out.sort()
	return out

static func is_crafting_station(type: String) -> bool:
	return type != "" and crafting_station_types().has(type)

## The recipes a window lists: those needing exactly `station_type` ("" = the hand window) that `known` (a
## `(recipe_id) -> bool`) says the player knows, sorted by id. An invalid `known` counts every recipe as known.
static func recipe_ids_for(station_type: String, known: Callable = Callable()) -> Array:
	var out: Array = []
	for rid in GameData.RECIPES:
		var id := str(rid)
		if recipe(id).is_empty() or station_of(id) != station_type:
			continue
		if known.is_valid() and not bool(known.call(id)):
			continue
		out.append(id)
	out.sort()
	return out

## The first output `{ item, quantity }` of a recipe ({} when it makes nothing).
static func output(recipe_id: String) -> Dictionary:
	for e in recipe(recipe_id).get("outputs", []):
		if e is Dictionary and str(e.get("item", "")) != "":
			return { "item": str(e["item"]), "quantity": int(e.get("quantity", 1)) }
	return {}

## The recipe's tab: the `category` its structured recipe names, else one read from what it makes — a tool (a
## tool or harvest class), a weapon (a main-hand slot or a weapon shape), armour (any other equipment slot),
## building (a placeable station's item, a block or a building material), a consumable (a potion), else a material.
## (Entity tags are not carried into the generated resources, so the recipe field is the fabric's way to say it.)
static func category(recipe_id: String) -> String:
	var named := str(recipe(recipe_id).get("category", ""))
	if CATEGORIES.has(named):
		return named
	var item := str(output(recipe_id).get("item", ""))
	if GameData.MATERIALS.has(item):
		return "building"
	var it: Resource = GameData.ITEMS.get(item, null)
	if it == null:
		return "materials"
	var shape: Variant = GameDataReader.json_field(it, "shape", {})
	var archetype := str((shape as Dictionary).get("archetype", "")) if shape is Dictionary else ""
	var slot := GameDataReader.str_field(it, "equipmentSlot", "")
	if GameDataReader.str_field(it, "toolType", "") != "" or GameDataReader.str_field(it, "harvestTool", "") != "":
		return "tools"
	if slot == "MainHand" or WEAPON_ARCHETYPES.has(archetype):
		return "weapons"
	if slot != "":
		return "armor"
	if StationRules.is_station_item(item) or archetype == "block":
		return "building"
	if CONSUMABLE_ARCHETYPES.has(archetype):
		return "consumables"
	return "materials"

## The skill a craft of this recipe trains (its domain's `WorkSkills.craft` row), or "".
static func trained_skill(recipe_id: String) -> String:
	return str(WorkSkills.craft_row(str(recipe(recipe_id).get("domain", ""))).get("skill", ""))

## Seconds one craft takes: the recipe's own `workSeconds`, 0 (instant) when the fabric gives it none.
static func work_seconds(recipe_id: String) -> float:
	var v: Variant = recipe(recipe_id).get("workSeconds", 0.0)
	return maxf(float(v), 0.0) if (v is float or v is int) else 0.0

## The inputs as `{ item, need, have, short }`, `have` read from `count_of` (`(item_id) -> int`, the bag).
static func inputs(recipe_id: String, count_of: Callable) -> Array:
	var out: Array = []
	for e in recipe(recipe_id).get("inputs", []):
		if not (e is Dictionary):
			continue
		var item := str(e.get("item", ""))
		var need := int(e.get("quantity", 1))
		var have := int(count_of.call(item)) if count_of.is_valid() else 0
		out.append({ "item": item, "need": need, "have": have, "short": have < need })
	return out

## How many crafts the bag pays for, at most MAX_QUANTITY (0 when it pays for none).
static func max_quantity(recipe_id: String, count_of: Callable) -> int:
	var n := MAX_QUANTITY
	for e: Dictionary in inputs(recipe_id, count_of):
		if int(e["need"]) > 0:
			n = mini(n, int(e["have"]) / int(e["need"]))
	return maxi(n, 0)

## Whether a recipe's shown name matches the search text (case-insensitive substring; empty matches all).
static func matches(name: String, query: String) -> bool:
	var q := query.strip_edges().to_lower()
	return q == "" or name.to_lower().contains(q)

## The station the interact input opens at `pos`: the id of the nearest placed station within INTERACT_REACH
## when it is a crafting station, else "" (a chest, door or bed nearest keeps its own interaction).
static func interact_station(stations: Array, pos: Vector3) -> String:
	var best: Dictionary = {}
	var best_d := INTERACT_REACH
	for s in stations:
		if not (s is Dictionary) or not ((s as Dictionary).get("position", null) is Vector3):
			continue
		var d := pos.distance_to(s["position"] as Vector3)
		if d <= best_d:
			best_d = d
			best = s
	if best.is_empty() or not is_crafting_station(str(best.get("type", ""))):
		return ""
	return str(best.get("id", ""))

## Whether a player at `pos` is still within `radius` of `station` (a station entry; {} = gone).
static func in_reach(station: Dictionary, pos: Vector3, radius: float) -> bool:
	var at: Variant = station.get("position", null)
	return at is Vector3 and pos.distance_to(at as Vector3) <= radius
