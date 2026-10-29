extends "res://src/tests/test_support.gd"
## Phase 184 — first steps in the fabric: GameData exposes the tutorial steps in order, every step's
## completion trigger names real fabric data (an item, tag, station type, window, slot or technology), the
## bed is reachable in the first hour, and the shelter rule tells a roofed room from an open one. Data and
## pure-rule checks; the bed spawn is Phase 185 and the cards are Phase 186.

const CreationRules := preload("res://src/character/creation_rules.gd")
const ShelterRule := preload("res://src/world/shelter_rule.gd")

## fabric/gameplay/tutorial.js STEPS, in order.
const STEP_IDS := [
	"move", "jump", "look", "controls",
	"mine", "chop", "inventory", "hotbar",
	"technology", "research_carpentry", "place_bench", "crafting", "craft_planks",
	"place_forge", "research_smithing", "craft_tool", "use_tool",
	"craft_bed", "place_bed", "build_shelter",
	"equip_weapon", "kill", "harvest",
	"respawn",
	"map", "waystone",
	"skills", "tier_up", "character",
	"chat", "trade", "settlement",
]


func register() -> void:
	_run_test("tutorial: GameData exposes the steps in fabric order, each chapter's steps together", _test_steps_in_order)
	_run_test("tutorial: every requires names an earlier step and every input names a controls row", _test_requires_and_inputs)
	_run_test("tutorial: every completion trigger resolves to a known item, tag, station type, window, slot or technology", _test_triggers_resolve)
	_run_test("tutorial: every step and chapter has a title and body in every locale, and so do the bed notices", _test_catalog_keys)
	_run_test("bed: placeable through the station path as type bed, consuming one Bed", _test_bed_station)
	_run_test("bed: the recipe is craftable in the first hour from gathered materials and early recipes", _test_bed_first_hour)
	_run_test("shelter: a roofed room passes, an open spot and a roof alone do not", _test_shelter_rule)
	_run_test("shelter: three closed sides are enough, two are not, and a low lip is no wall", _test_shelter_sides)


func _tutorial() -> Resource:
	return GameData.TUTORIALS.get("Tutorial", null)


func _steps() -> Array:
	var t := _tutorial()
	return Array(t.get("steps")) if t != null else []


func _test_steps_in_order() -> void:
	var t := _tutorial()
	assert_true(t != null, "GameData.TUTORIALS has the Tutorial")
	if t == null:
		return
	var ids: Array = []
	for s in _steps():
		ids.append(str(s["id"]))
	assert_eq(ids, STEP_IDS, "the steps in fabric order")
	var chapters: Array = Array(t.get("chapters"))
	assert_eq(chapters.size(), 10, "ten chapters")
	assert_eq(str(chapters[0]), "moving", "moving comes first")
	# Chapters appear in the chapters list order, each as one contiguous run.
	var last := -1
	for s in _steps():
		var at := chapters.find(str(s["chapter"]))
		assert_true(at >= 0, "%s has a known chapter" % s["id"])
		assert_true(at >= last, "%s does not go back to an earlier chapter" % s["id"])
		last = maxi(last, at)


func _test_requires_and_inputs() -> void:
	var actions: Array = []
	for row in UiSlice.controls_rows():
		actions.append(str(row["action"]))
	var t := _tutorial()
	assert_eq(actions, Array(t.get("inputActions")), "the controls rows carry the fabric input actions in order")
	var seen := {}
	for s in _steps():
		for r in s["requires"]:
			assert_true(seen.has(str(r)), "%s requires %s, an earlier step" % [s["id"], r])
		for a in s["inputs"]:
			assert_true(actions.has(str(a)), "%s names input %s, a controls row" % [s["id"], a])
		seen[str(s["id"])] = true


## Every id a tag names: the GameData table of an entity tag (the generator groups entities by their first
## tag, and the generated resources do not keep `tags`), and items whose toolType is the tag.
func _tag_members(tag: String) -> Array:
	var tables := { "item": GameData.ITEMS, "material": GameData.MATERIALS, "creature": GameData.CREATURES }
	var out: Array = (tables[tag] as Dictionary).keys() if tables.has(tag) else []
	for key in GameData.ITEMS:
		var tool = GameData.ITEMS[key].get("toolType")
		if tool != null and str(tool) == tag:
			out.append(key)
	return out


func _test_triggers_resolve() -> void:
	var kinds: Dictionary = _tutorial().get("triggerKinds")
	var stations: Node = StationSlice.new()
	var station_types: Array = stations.placeable_station_types()
	stations.free()
	var slots := EquipmentRules.slots(GameData.ITEMS)
	var fabric_windows: Array = Array(_tutorial().get("windows"))
	for w in fabric_windows:
		assert_true(UiSlice.WINDOW_KEYS.has(w), "fabric window %s is a UiSlice window" % w)
	for s in _steps():
		var t: Dictionary = s["trigger"]
		var kind := str(t["kind"])
		var at := "%s (%s)" % [s["id"], kind]
		assert_true(kinds.has(kind), "%s: a known trigger kind" % at)
		if t.has("item"):
			assert_true(GameData.ITEMS.has(t["item"]) or GameData.MATERIALS.has(t["item"]), "%s: item %s exists" % [at, t["item"]])
		if t.has("tag"):
			assert_true(not _tag_members(str(t["tag"])).is_empty(), "%s: tag %s names something" % [at, t["tag"]])
		if t.has("type"):
			assert_true(station_types.has(t["type"]), "%s: station type %s is placeable" % [at, t["type"]])
		if t.has("window"):
			assert_true(UiSlice.WINDOW_KEYS.has(t["window"]), "%s: window %s exists" % [at, t["window"]])
		if t.has("slot"):
			assert_true(slots.has(t["slot"]), "%s: slot %s exists" % [at, t["slot"]])
		if t.has("creature"):
			assert_true(GameData.CREATURES.has(t["creature"]), "%s: creature %s exists" % [at, t["creature"]])
		if t.has("technology"):
			assert_true(GameData.TECHNOLOGIES.has(t["technology"]), "%s: technology %s exists" % [at, t["technology"]])
	assert_true(_tag_members("pick").has("FerritePick"), "the pick tag names the FerritePick")


func _test_catalog_keys() -> void:
	var cats: Dictionary = I18nScript.parse_csv("res://locale/ui.csv")["catalog"]
	assert_true(cats.has("en") and cats.has("pt_BR"), "both catalog columns exist")
	var keys: Array = []
	for c in Array(_tutorial().get("chapters")):
		keys.append("tutorial.chapter.%s" % c)
	for s in _steps():
		keys.append("tutorial.%s.title" % s["id"])
		keys.append("tutorial.%s.body" % s["id"])
	var bed: Dictionary = GameData.WORLD_SYSTEMS["BedSpawn"].get("rules")
	for k in (bed["notices"] as Dictionary).values():
		keys.append(str(k))
	for loc in cats:
		for k in keys:
			assert_true(str((cats[loc] as Dictionary).get(k, "")) != "", "%s has %s" % [loc, k])


func _test_bed_station() -> void:
	var stations: Node = StationSlice.new()
	assert_true(stations.placeable_station_types().has("bed"), "bed is a placeable station type")
	assert_eq(stations.placement_item("bed"), "Bed", "placing a bed consumes a Bed")
	assert_eq(stations.placement_item("carpentry bench"), "", "a bench stays free")
	stations.free()
	var bed: Resource = GameData.ITEMS.get("Bed", null)
	assert_true(bed != null, "GameData.ITEMS has the Bed")
	assert_eq(str((bed.get("shape") as Dictionary)["archetype"]), "bed", "the Bed draws as a bed")
	assert_true(ResourceLoader.exists("res://assets/icons/items/Bed.png.raw") or FileAccess.file_exists("res://assets/icons/items/Bed.png.raw"), "the Bed has a public icon")


## Recipe key -> the technology that unlocks it.
func _recipe_techs() -> Dictionary:
	var out := {}
	for key in GameData.TECHNOLOGIES:
		var tech = GameData.TECHNOLOGIES[key].get("tech")
		if tech is Dictionary:
			for r in tech.get("unlocks", []):
				out[str(r)] = str(key)
	return out


## What a new player can reach in the first hour, as a fixed point: the starting kit, what bare hands
## mine and the kit's axe chops in a spawn biome, then every recipe whose technology is free (no
## research-point cost, every prerequisite reachable, research materials in hand), whose station is
## free to place, whose skill guard is novice, and whose inputs are reachable.
func _first_hour_items() -> Dictionary:
	var have := {}
	var has_axe := false
	for k in CreationRules.starting_kit():
		have[str(k["item"])] = true
		var res: Resource = GameData.ITEMS.get(str(k["item"]), null)
		if res != null and str(res.get("toolType") if res.get("toolType") != null else "") == "axe":
			has_axe = true
	var ws: Resource = GameData.WORLD_SYSTEMS.get("WorldSystem", null)
	for biome in Array(ws.get("spawnHabitableBiomes")):
		var b: Resource = GameData.BIOMES.get(str(biome), null)
		if b != null and b.get("soilMaterial") != null:
			have[str(b.get("soilMaterial"))] = true
		have[OreField.host_material(str(biome))] = true
		var tree: Dictionary = TreeSlice.TREES_BY_BIOME.get(str(biome), {})
		if has_axe and not tree.is_empty():
			have[str(tree["wood"])] = true
	var stations: Node = StationSlice.new()
	var free_stations := {}
	for st in stations.placeable_station_types():
		if stations.placement_item(st) == "":
			free_stations[st] = true
	stations.free()
	var techs := _recipe_techs()
	var known := {}
	var changed := true
	while changed:
		changed = false
		for key in GameData.TECHNOLOGIES:
			if known.has(key):
				continue
			var res: Resource = GameData.TECHNOLOGIES[key]
			var tech: Dictionary = res.get("tech")
			var ok: bool = int(res.get("researchCost")) == 0
			for r in tech.get("requires", []):
				ok = ok and known.has(str(r))
			for m in tech.get("researchMaterials", []):
				ok = ok and have.has(str(m["item"]))
			if ok:
				known[key] = true
				changed = true
		for key in GameData.RECIPES:
			var recipe: Dictionary = GameData.RECIPES[key].get("recipe")
			var outs: Array = recipe.get("outputs", [])
			if outs.is_empty() or have.has(str(outs[0]["item"])):
				continue
			var ok: bool = known.has(str(techs.get(key, "")))
			var station := str(recipe.get("station", ""))
			ok = ok and (station == "" or free_stations.has(station))
			for g in recipe.get("skillGuards", []):
				ok = ok and str(g["tier"]) == "novice"
			for i in recipe.get("inputs", []):
				ok = ok and have.has(str(i["item"]))
			if ok:
				for o in outs:
					have[str(o["item"])] = true
				changed = true
	return have


func _test_bed_first_hour() -> void:
	var recipe: Dictionary = GameData.RECIPES["RecipeBed"].get("recipe")
	assert_eq(str(recipe["station"]), "", "the bed needs no station")
	var tech := str(_recipe_techs().get("RecipeBed", ""))
	assert_eq(tech, "TechBasicCarpentry", "Basic Carpentry unlocks the bed")
	assert_eq(int(GameData.TECHNOLOGIES[tech].get("researchCost")), 0, "Basic Carpentry costs no research points")
	assert_eq(Array(GameData.TECHNOLOGIES[tech].get("tech")["requires"]), [], "Basic Carpentry has no prerequisite")
	var have := _first_hour_items()
	assert_true(have.has("Thornwood"), "the starting axe reaches wood")
	assert_true(have.has("ThornwoodPlank"), "planks are reachable")
	assert_true(have.has("Bed"), "the bed is reachable in the first hour")
	assert_true(have.has("FerritePick"), "the tutorial's first pick is reachable")
	assert_true(have.has("FerriteShortSword"), "the tutorial's first weapon is reachable")


## A fixture world: { tile: [ { bottom, top } ] }, flat ground at 0 everywhere else.
func _world(extra: Dictionary) -> Callable:
	return func(tile: Vector2i) -> Array:
		var runs: Array = [{ "bottom": -4.0, "top": 0.0 }]
		runs.append_array(extra.get(tile, []))
		return runs


## A wall on `sides` (subset of +x, -x, +z, -z) two tiles out from the bed tile, 2 m high, and a roof
## slab 2 m up over the bed tile when `roof`.
func _room(sides: Array, roof: bool, wall_top: float = 2.0) -> Callable:
	var extra := {}
	var dirs := { "+x": Vector2i(2, 0), "-x": Vector2i(-2, 0), "+z": Vector2i(0, 2), "-z": Vector2i(0, -2) }
	for s in sides:
		extra[dirs[s]] = [{ "bottom": 0.0, "top": wall_top }]
	if roof:
		extra[Vector2i(0, 0)] = [{ "bottom": 2.0, "top": 2.125 }]
	return _world(extra)


func _test_shelter_rule() -> void:
	var bed := Vector3(0.25, 0.0, 0.25)
	var r := ShelterRule.rules()
	assert_eq(int(r.get("minClosedSides", 0)), 3, "the fabric closes three sides of four")
	assert_true(ShelterRule.is_sheltered(bed, _room(["+x", "-x", "+z", "-z"], true)), "walls on four sides and a roof: sheltered")
	assert_false(ShelterRule.is_sheltered(bed, _room([], false)), "open ground: not sheltered")
	assert_false(ShelterRule.is_sheltered(bed, _room([], true)), "a roof alone: not sheltered")
	assert_false(ShelterRule.is_sheltered(bed, _room(["+x", "-x", "+z", "-z"], false)), "four walls and no roof: not sheltered")
	# A roof too high above the bed is the sky, not a roof.
	var high := _world({ Vector2i(0, 0): [{ "bottom": 10.0, "top": 10.5 }], Vector2i(2, 0): [{ "bottom": 0.0, "top": 12.0 }],
		Vector2i(-2, 0): [{ "bottom": 0.0, "top": 12.0 }], Vector2i(0, 2): [{ "bottom": 0.0, "top": 12.0 }] })
	assert_false(ShelterRule.is_sheltered(bed, high), "a slab 10 m up is no roof")


func _test_shelter_sides() -> void:
	var bed := Vector3(0.25, 0.0, 0.25)
	var r := ShelterRule.rules()
	assert_true(ShelterRule.is_sheltered(bed, _room(["+x", "-x", "+z"], true)), "three walls and a roof (a doorway): sheltered")
	assert_false(ShelterRule.is_sheltered(bed, _room(["+x", "-x"], true)), "two walls and a roof: not sheltered")
	assert_eq(ShelterRule.closed_sides(bed, _room(["+x", "-x", "+z", "-z"], false, 0.125), r), 0, "a one-step lip closes no side")
	# A wall past the side reach does not count.
	var far := _world({ Vector2i(9, 0): [{ "bottom": 0.0, "top": 2.0 }] })
	assert_eq(ShelterRule.closed_sides(bed, far, r), 0, "a wall 4.5 m away is outside the 2 m reach")
	# A hillside is a wall: the natural ground rising beside the bed closes that side.
	var hill := _world({ Vector2i(1, 0): [{ "bottom": 0.0, "top": 3.0 }] })
	assert_eq(ShelterRule.closed_sides(bed, hill, r), 1, "a hillside closes a side")
