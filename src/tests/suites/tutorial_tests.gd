extends "res://src/tests/test_support.gd"
## Phase 184 — first steps in the fabric: GameData exposes the tutorial steps in order, every step's
## completion trigger names real fabric data (an item, tag, station type, window, slot or technology), the
## bed is reachable in the first hour, and the shelter rule tells a roofed room from an open one. Data and
## pure-rule checks; the bed spawn is Phase 185 and the cards are Phase 186.

const CreationRules := preload("res://src/character/creation_rules.gd")
const ShelterRule := preload("res://src/world/shelter_rule.gd")
const StoneTools := preload("res://src/world/stone_tools.gd")
const TutorialMarker := preload("res://src/tutorial/tutorial_marker.gd")
const TutorialRules := preload("res://src/tutorial/tutorial_rules.gd")
const WorkTime := preload("res://src/core/work_time.gd")

## fabric/gameplay/tutorial.js STEPS, in order.
## Phase 262: from bare hands — loose items, stone tools, then the stations.
const STEP_IDS := [
	"move", "jump", "look", "controls",
	"pick_branch", "pick_stone", "inventory", "hotbar",
	"crafting", "craft_axe", "chop", "craft_pick", "craft_shovel", "dig", "mine_stone",
	"technology", "research_carpentry", "craft_bench", "place_bench", "craft_planks",
	"research_smithing", "craft_forge", "place_forge", "craft_tool", "use_tool",
	"craft_bed", "place_bed", "craft_hammer", "build_shelter",
	"equip_weapon", "kill", "craft_knife", "harvest",
	"respawn",
	"map", "waystone",
	"skills", "tier_up", "character",
	"chat", "trade", "settlement", "found_village", "start_project", "contribute_project",
]


func register() -> void:
	_run_test("tutorial: GameData exposes the steps in fabric order, each chapter's steps together", _test_steps_in_order)
	_run_test("tutorial: every requires names an earlier step and every input names a controls row", _test_requires_and_inputs)
	_run_test("tutorial: every completion trigger resolves to a known item, tag, station type, window, slot or technology", _test_triggers_resolve)
	_run_test("tutorial: every step and chapter has a title and body in every locale, and so do the bed notices", _test_catalog_keys)
	_run_test("bed: placeable through the station path as type bed, consuming one Bed", _test_bed_station)
	_run_test("bed: the recipe is craftable in the first hour from gathered materials and early recipes", _test_bed_first_hour)
	_run_test("stone tools: every one is reachable from an empty kit with only loose stones and branches", _test_stone_tools_first_hour)
	_run_test("tutorial: the first stone tools come from the loose items, before the first station is placed", _test_bare_hands_order)
	_run_test("tutorial: on the pinned playtest world, Ferrite is at most 2 blocks down round the spawn or the mine_stone marker names Ferrite within 30 m (Phase 290)", _test_mine_stone_marker_pinned, true)
	_run_test("tutorial: a step marker is the first eligible step's, searched nearest first, and its beacon follows a rebase (Phase 290)", _test_marker_rules)
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
	assert_eq(chapters.size(), 11, "eleven chapters")
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
	assert_eq(stations.placement_item("carpentry bench"), "CarpentryBench", "Phase 268: a bench costs its item")
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
## mine and an axe chops in a spawn biome, then every recipe whose technology is free (no
## research-point cost, every prerequisite reachable, research materials in hand), whose station can be
## placed (free, or its placement item reached), whose skill guard is novice, and whose inputs are reachable.
## Phase 260 — `kit` (a list of item keys) replaces the starting kit when given, `extra` adds items picked off
## the ground, and any axe in hand, crafted ones too, reaches the spawn biomes' wood.
## Phase 262 — the starting kit is empty; with no `extra`, the newcomer grounds' loose items (a branch and a
## loose stone, Phase 261) are what the player picks up.
func _first_hour_items(kit: Variant = null, extra: Variant = null) -> Dictionary:
	var have := {}
	var kit_items: Array = []
	if kit is Array:
		kit_items = kit
	else:
		for k in CreationRules.starting_kit():
			kit_items.append(str(k["item"]))
	var picked: Array = extra if extra is Array else [StoneTools.BRANCH, StoneTools.LOOSE_STONE]
	for item in kit_items + picked:
		have[str(item)] = true
	var woods: Array = []
	var ws: Resource = GameData.WORLD_SYSTEMS.get("WorldSystem", null)
	for biome in Array(ws.get("spawnHabitableBiomes")):
		var b: Resource = GameData.BIOMES.get(str(biome), null)
		if b != null and b.get("soilMaterial") != null:
			have[str(b.get("soilMaterial"))] = true
		have[OreField.host_material(str(biome))] = true
		var tree: Dictionary = TreeSlice.TREES_BY_BIOME.get(str(biome), {})
		if not tree.is_empty():
			woods.append(str(tree["wood"]))
	# Station type -> the item placing it consumes ("" when free); a station counts once that item is reached.
	var stations: Node = StationSlice.new()
	var station_items := {}
	for st in stations.placeable_station_types():
		station_items[st] = stations.placement_item(st)
	stations.free()
	var techs := _recipe_techs()
	var known := {}
	var changed := true
	while changed:
		changed = false
		if _has_axe(have):
			for wood in woods:
				if not have.has(wood):
					have[wood] = true
					changed = true
		for key in GameData.TECHNOLOGIES:
			if known.has(key):
				continue
			var res: Resource = GameData.TECHNOLOGIES[key]
			var tech: Dictionary = res.get("tech")
			var ok: bool = int(res.get("researchCost")) == 0
			# Phase 260 — a discovery technology is known once its recipes' inputs have been held.
			if bool(tech.get("discovery", false)):
				for item in TechnologySlice.discovery_inputs(str(key)):
					ok = ok and have.has(str(item))
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
			ok = ok and (station == "" or (station_items.has(station) and (station_items[station] == "" or have.has(station_items[station]))))
			for g in recipe.get("skillGuards", []):
				ok = ok and str(g["tier"]) == "novice"
			for i in recipe.get("inputs", []):
				ok = ok and have.has(str(i["item"]))
			if ok:
				for o in outs:
					have[str(o["item"])] = true
				changed = true
	return have


func _has_axe(have: Dictionary) -> bool:
	for item in have:
		var res: Resource = GameData.ITEMS.get(str(item), null)
		if res != null and str(res.get("toolType") if res.get("toolType") != null else "") == "axe":
			return true
	return false


## Phase 260 — from an empty pack and only loose stones and branches, every stone tool is reachable, and the
## stone axe then reaches wood.
func _test_stone_tools_first_hour() -> void:
	var have := _first_hour_items([], ["Branch", "LooseStone"])
	var tools: Array = GameData.WORLD_SYSTEMS["StoneTools"].get("tools")
	assert_eq(tools.size(), 5, "five stone tools")
	for tool in tools:
		assert_true(have.has(str(tool)), "%s is reachable from an empty kit" % tool)
	assert_true(have.has("Thornwood"), "the stone axe reaches wood")
	var none := _first_hour_items([], [])
	assert_false(none.has("StoneAxe"), "with nothing picked up, no stone tool is made")


## Phase 262 — the tutorial's tool steps need only what lies on the ground, and placing the first station needs
## the first wood: the loose items come first, the stone axe before the tree, the tree before the bench.
func _test_bare_hands_order() -> void:
	var at := {}
	var steps := _steps()
	for i in steps.size():
		at[str(steps[i]["id"])] = i
	var trig := func(id: String) -> Dictionary: return steps[int(at[id])]["trigger"]
	assert_eq(str(trig.call("pick_branch").get("item", "")), StoneTools.BRANCH, "the first gathering step picks up a branch")
	assert_eq(str(trig.call("pick_stone").get("item", "")), StoneTools.LOOSE_STONE, "and a loose stone")
	for id in ["craft_axe", "craft_pick", "craft_shovel", "craft_hammer", "craft_knife"]:
		var item := str(trig.call(id).get("item", ""))
		var recipe: Dictionary = GameData.RECIPES["Recipe" + item].get("recipe")
		assert_eq(str(recipe["station"]), "", "%s needs no station" % item)
		for inp in recipe["inputs"]:
			assert_true([StoneTools.BRANCH, StoneTools.LOOSE_STONE].has(str(inp["item"])), "%s is made from loose items only" % item)
	assert_true(int(at["pick_branch"]) < int(at["craft_axe"]) and int(at["craft_axe"]) < int(at["chop"]), "branch, then axe, then tree")
	assert_true(int(at["chop"]) < int(at["place_bench"]), "the tree comes before the first station")
	# Phase 268 — a station is an item: each place step requires crafting that item first.
	assert_true(Array(steps[int(at["place_bench"])]["requires"]).has("craft_bench"), "the bench is crafted before it is placed")
	assert_true(Array(steps[int(at["place_forge"])]["requires"]).has("craft_forge"), "the forge is crafted before it is placed")
	assert_eq(str(trig.call("craft_bench").get("item", "")), "CarpentryBench", "the first station is the hand-made carpentry bench")
	assert_true(Array(steps[int(at["chop"])]["requires"]).has("craft_axe"), "chopping requires the stone axe step")
	assert_true(Array(steps[int(at["build_shelter"])]["requires"]).has("craft_hammer"), "building requires the hammer step")
	assert_true(Array(steps[int(at["harvest"])]["requires"]).has("craft_knife"), "the harvest requires the stone knife step")


func _test_bed_first_hour() -> void:
	var recipe: Dictionary = GameData.RECIPES["RecipeBed"].get("recipe")
	assert_eq(str(recipe["station"]), "", "the bed needs no station")
	var tech := str(_recipe_techs().get("RecipeBed", ""))
	assert_eq(tech, "TechBasicCarpentry", "Basic Carpentry unlocks the bed")
	assert_eq(int(GameData.TECHNOLOGIES[tech].get("researchCost")), 0, "Basic Carpentry costs no research points")
	assert_eq(Array(GameData.TECHNOLOGIES[tech].get("tech")["requires"]), [], "Basic Carpentry has no prerequisite")
	assert_eq(CreationRules.starting_kit(), [], "the starting kit is empty (Phase 262)")
	var have := _first_hour_items()
	assert_true(have.has("StoneAxe"), "a stone axe is lashed from the loose items")
	assert_true(have.has("Thornwood"), "the stone axe reaches wood")
	assert_true(have.has("ThornwoodPlank"), "planks are reachable")
	assert_true(have.has("CarpentryBench"), "the carpentry bench item is reachable by hand")
	assert_true(have.has("Forge"), "and the forge item from it")
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

func _step(id: String) -> Dictionary:
	for st in TutorialRules.steps():
		if str(st["id"]) == id:
			return st
	return {}

## Phase 290 — the rock the tutorial asks for is close: checked against world-gen on the pinned playtest world (the
## 2,000 km planet the bot plays; no world-gen change). Either every column within 16 m of the newcomer spawn has
## Ferrite at most 2 blocks down, or the `mine_stone` step's marker finds Ferrite within 30 m. World-gen does not give
## 2 blocks there (the nearest such column is 30-40 m out), so the marker allows the soil the stone shovel digs in
## under 5 s (fabric `maxDepthBlocks`).
func _test_mine_stone_marker_pinned() -> void:
	var Bot := load("res://src/tests/playtest_bot.gd")
	var step := _step("mine_stone")
	assert_eq((step.get("trigger", {}) as Dictionary).get("item", ""), "Ferrite", "mine_stone completes on Ferrite")
	assert_eq(int((step.get("trigger", {}) as Dictionary).get("count", 0)), 1, "one Ferrite is enough")
	var marker: Dictionary = step.get("marker", {})
	assert_eq(str(marker.get("kind", "")), "ore_near_surface", "mine_stone carries a near-surface ore marker")
	assert_eq(str(marker.get("item", "")), "Ferrite", "for Ferrite")
	assert_true(float(marker.get("radiusMetres", 99.0)) <= 30.0, "within 30 m")
	var soil_s := WorkTime.seconds("Soil", "dig", "StoneShovel")
	assert_true(float(int(marker.get("maxDepthBlocks", 99)) - 1) * soil_s < 5.0, "the soil over the marked rock digs in under 5 s with the stone shovel")
	var seed_v: int = Bot.WORLD_SEED
	const NewcomerGrounds := preload("res://src/world/newcomer_grounds.gd")
	NewcomerGrounds.clear_cache()   # the grounds of the modern (2,000 km) planet the bot plays, not a cached legacy one
	var terrain := TerrainSlice.new()
	_own(terrain)
	terrain.set_world_seed(seed_v)
	var height_fn := func(p: Vector2) -> float: return terrain.get_height_at(p)
	SpawnFinderScript.prime_grounds(seed_v, height_fn)
	var sp: Variant = SpawnFinderScript.find_start(seed_v, Bot.PLAYER_ID, null, height_fn)
	assert_true(sp != null, "the pinned player has a newcomer spawn")
	if sp == null:
		NewcomerGrounds.clear_cache()
		return
	var v := VoxelSlice.new()
	add_child(v)
	v.terrain_slice = terrain
	var origin := Vector2i(floori((sp as Vector3).x / VoxelSlice.TILE_SIZE), floori((sp as Vector3).z / VoxelSlice.TILE_SIZE))
	var yield_fn := func(t: Vector2i, span: Dictionary) -> Dictionary: return v.natural_yield(t, span)
	var all_close := true
	var r := int(16.0 / VoxelSlice.TILE_SIZE)
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			if not all_close or dx * dx + dz * dz > r * r:
				continue
			var t := origin + Vector2i(dx, dz)
			if TutorialMarker.depth_of(t, v.get_runs_at_tile(t), "Ferrite", 2, yield_fn) == 0:
				all_close = false
	var hit := TutorialMarker.find(marker, origin, v)
	if not all_close:
		assert_false(hit.is_empty(), "world-gen leaves soil deeper than 2 blocks round the spawn, so the marker finds Ferrite within 30 m")
	if not hit.is_empty():
		assert_true(float(hit["distance"]) <= 30.0, "the marked column is within 30 m (%.1f m)" % float(hit["distance"]))
		assert_true(int(hit["depth_blocks"]) >= 1 and int(hit["depth_blocks"]) <= int(marker["maxDepthBlocks"]), "its Ferrite is at most %d blocks down (%d)" % [int(marker["maxDepthBlocks"]), int(hit["depth_blocks"])])
		assert_true(float(int(hit["depth_blocks"]) - 1) * soil_s < 5.0, "dig-to-rock there is under 5 s of holding (%.2f s)" % (float(int(hit["depth_blocks"]) - 1) * soil_s))
		# The column really yields Ferrite at that depth, block by block as the player mines it.
		var t: Vector2i = hit["tile"]
		var top := float(hit["top"])
		var got := ""
		for i in range(1, int(hit["depth_blocks"]) + 1):
			got = str(v.natural_yield(t, { "bottom": top - i * VoxelSlice.STEP_HEIGHT, "top": top - (i - 1) * VoxelSlice.STEP_HEIGHT, "material": "" })["material"])
		assert_eq(got, "Ferrite", "the marked block is Ferrite")
	v.free()
	NewcomerGrounds.clear_cache()

func _test_marker_rules() -> void:
	# The first eligible step with a marker; none when no eligible step has one.
	var a := { "id": "a", "marker": {} }
	var b := { "id": "b", "marker": { "kind": "ore_near_surface", "item": "Ferrite", "maxDepthBlocks": 2, "radiusMetres": 30 } }
	var c := { "id": "c" }
	assert_eq(TutorialMarker.marker_step([c, a, b]), b, "the first eligible step that has a marker")
	assert_eq(TutorialMarker.marker_step([c, a]), {}, "none without one")
	var state := { "enabled": true, "done": ["move", "jump", "look", "controls", "pick_branch", "pick_stone", "inventory",
		"hotbar", "crafting", "craft_axe", "chop", "craft_pick"], "dismissed": [] }
	assert_eq(str(TutorialMarker.marker_step(TutorialRules.eligible(state)).get("id", "")), "mine_stone", "with the pick made, mine_stone's marker shows")
	(state["done"] as Array).append("mine_stone")
	assert_eq(TutorialMarker.marker_step(TutorialRules.eligible(state)), {}, "and goes once it is done")
	# Nearest first: Ferrite at (4, 0) two blocks down and at (2, 2) one block down; (2, 2) is nearer. The search reads
	# every other tile each way first, so (1, 1) is not seen while the grid has a hit.
	var ore := { Vector2i(4, 0): 2, Vector2i(2, 2): 1, Vector2i(0, 10): 1, Vector2i(1, 1): 1 }
	var runs_fn := func(_t: Vector2i) -> Array: return [{ "bottom": -96.0, "top": 2.0, "material": "" }]
	var yield_fn := func(t: Vector2i, span: Dictionary) -> Dictionary:
		var block := int(round((2.0 - float(span["top"])) / VoxelSlice.STEP_HEIGHT)) + 1
		return { "material": "Ferrite" if int(ore.get(t, 0)) == block else "Soil" }
	var m: Dictionary = b["marker"]
	var hit := TutorialMarker.find_ore_near_surface(Vector2i.ZERO, m, runs_fn, yield_fn)
	assert_eq(hit.get("tile", Vector2i(-1, -1)), Vector2i(2, 2), "the nearest column wins")
	assert_eq(int(hit.get("depth_blocks", 0)), 1, "one block down")
	assert_true(absf(float(hit.get("distance", 0.0)) - sqrt(8.0) * VoxelSlice.TILE_SIZE) < 0.001, "distance in metres")
	assert_eq(TutorialMarker.find_ore_near_surface(Vector2i(1000, 1000), m, runs_fn, yield_fn), {}, "nothing within the radius: no marker")
	# The client's search runs a slice a frame and ends on the same spot.
	var srch := TutorialMarker.ore_search(Vector2i.ZERO, m, runs_fn, yield_fn)
	var frames := 0
	while not srch.step(0):
		frames += 1
	assert_true(frames > 1, "a zero budget reads one column a frame (%d frames)" % frames)
	assert_eq(srch.hit, hit, "and finds the same spot")
	# A strip 1 tile wide on odd tiles only (where the surface cuts a vein thin): the grid misses it, the fine pass
	# that follows an empty grid finds it.
	ore.clear()   # the lambda holds the same Dictionary: mutate it, never reassign
	ore[Vector2i(3, 5)] = 1
	ore[Vector2i(5, 5)] = 1
	var strip := TutorialMarker.find_ore_near_surface(Vector2i.ZERO, m, runs_fn, yield_fn)
	assert_eq(strip.get("tile", Vector2i(-1, -1)), Vector2i(3, 5), "a thin strip off the grid is still found, nearest first")
	ore.clear()
	assert_eq(TutorialMarker.find_ore_near_surface(Vector2i.ZERO, m, runs_fn, yield_fn), {}, "and with no ore anywhere both passes end empty")
	var placed: Array = [{ "bottom": 1.0, "top": 2.0, "material": "Ferrite" }]
	assert_eq(TutorialMarker.depth_of(Vector2i.ZERO, placed, "Ferrite", 2, yield_fn), 1, "a placed block is its own material")
	# The beacon sits at the column from exact positions, so a far world or a rebase does not move it.
	var beacon := TutorialMarker.new()
	add_child(beacon)
	beacon.set_target(b, { "tile": Vector2i(64 * 1000 + 3, -64 * 50 + 2), "top": 10.0 })
	assert_eq(beacon.world_pos["chunk"], Vector2i(1000, -50), "the tile's chunk")
	beacon.follow({ "chunk": Vector2i(1000, -50), "local": Vector3(0.0, 9.0, 0.0) }, Vector3(5.0, 9.0, 5.0))
	assert_true(beacon.position.is_equal_approx(Vector3(5.0 + 3.5 * VoxelSlice.TILE_SIZE, 10.0, 5.0 + 2.5 * VoxelSlice.TILE_SIZE)), "beside the player by the exact offset (%s)" % str(beacon.position))
	beacon.follow({ "chunk": Vector2i(999, -50), "local": Vector3(31.0, 9.0, 0.0) }, Vector3(0.0, 9.0, 0.0))
	assert_true(beacon.position.is_equal_approx(Vector3(1.0 + 3.5 * VoxelSlice.TILE_SIZE, 10.0, 2.5 * VoxelSlice.TILE_SIZE)), "the same column from the next chunk over (%s)" % str(beacon.position))
	assert_true(beacon._label.text.contains(I18nScript.content("item", "Ferrite")), "the label names the ore in the player's language")
	beacon.free()
