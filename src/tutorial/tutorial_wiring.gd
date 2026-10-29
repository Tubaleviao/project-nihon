extends "res://src/core/wiring.gd"
## Tutorial wiring (Phase 186) — client-side only. It feeds `TutorialSlice` from the events this machine already
## sees (jumps, crafting, stations, research, kills, carcasses, the bed, respawns, chat, worn gear, windows, movement)
## and shows the card. It sends nothing to the host and changes no game state.

const WorldPos := preload("res://src/terrain/world_pos.gd")
const Rules := preload("res://src/tutorial/tutorial_rules.gd")
const TutorialSlice := preload("res://src/tutorial/tutorial_slice.gd")
const TutorialCard := preload("res://src/tutorial/tutorial_card.gd")
const BedStore := preload("res://src/world/bed_store.gd")
const ShelterRule := preload("res://src/world/shelter_rule.gd")

## A jump of the body bigger than this in one frame is a teleport, not walking (m).
const TELEPORT_M := 20.0
## Degrees the look must turn the camera to count as looking around.
const LOOK_DEGREES := 30.0
## Seconds between shelter checks while `build_shelter` is open.
const SHELTER_CHECK_S := 1.0
## Stations farther than this (m) from the player are not counted as the player's when seeding a veteran.
const SEED_STATION_M := 150.0

var slice: TutorialSlice = null
var card: TutorialCard = null
var _layer: CanvasLayer = null
var _last_pos: Vector3 = Vector3.ZERO
var _have_pos: bool = false
var _pack: Dictionary = {}
var _skills: Dictionary = {}
var _skills_known: bool = false
var _pack_known: bool = false
var _pack_dirty: bool = false
## Items crafted since the last frame, so the pack growing by them is not counted as gathered.
var _crafted: Dictionary = {}
var _bed: Dictionary = {}
var _shelter_clock: float = 0.0
var _seeded: bool = false
var _look_from: float = 0.0

func _connect_all() -> void:
	connect_bus(GameBus.tutorial_event, _on_event)
	connect_bus(GameBus.craft_resolved, _on_craft_resolved)
	connect_bus(GameBus.station_placed, _on_station_placed)
	connect_bus(GameBus.technology_unlocked, _on_tech_unlocked)
	connect_bus(GameBus.creature_died, _on_creature_died)
	connect_bus(GameBus.harvest_resolved, _on_harvest_resolved)
	connect_bus(GameBus.bed_synced, _on_bed_synced)
	connect_bus(GameBus.player_respawned, _on_respawned)
	connect_bus(GameBus.chat_intent, _on_chat)
	connect_bus(GameBus.equipment_changed, _on_equipment_changed)
	connect_bus(GameBus.inventory_changed, _on_inventory_changed)
	connect_bus(GameBus.waystones_synced, _on_waystones_synced)
	connect_bus(GameBus.tutorial_changed, _on_changed)

## Build the slice and the card once the UI exists (not on a dedicated server).
func attach() -> void:
	if root._is_server:
		return
	slice = TutorialSlice.new()
	root.add_child(slice)
	slice.load_saved()
	_layer = CanvasLayer.new()
	_layer.layer = 5
	root.add_child(_layer)
	card = TutorialCard.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	_layer.add_child(card)
	card.bind(slice)

func _local() -> String:
	return root._registry.local_player_id

## Mark steps done that the save already satisfies, so a veteran is not taught to walk. Once, after the pack
## and the record are known.
func seed_from_player() -> void:
	if _seeded or slice == null or not slice.is_fresh():
		return
	var rec: Dictionary = root._registry.get_record(_local())
	if rec.is_empty():
		return   # the record has not arrived yet; try again next tick
	_seeded = true
	var facts := { "items": root._inventory.get_contents(), "tags": {}, "stations": [], "bed": false, "kills": 0,
		"slots": [], "technologies": [] }
	for key in facts["items"]:
		facts["tags"][key] = _tags_of(str(key))
	var here: Vector3 = root._player.get_position() if root._player != null else Vector3.ZERO
	for st in root._station.get_all_stations():
		var sp: Variant = st.get("position", null)
		if sp is Vector3 and Vector2((sp as Vector3).x - here.x, (sp as Vector3).z - here.z).length() > SEED_STATION_M:
			continue
		facts["stations"].append(str(st["type"]))
	facts["bed"] = BedStore.from_record(rec) != null
	facts["slots"] = (rec.get("equipment", {}) as Dictionary).keys()
	var tech: Variant = rec.get("technology", {})
	if tech is Dictionary:
		for k in tech:
			var v: Variant = tech[k]
			if str((v as Dictionary).get("status", "") if v is Dictionary else v) in ["researched", "unlocked", "done"]:
				facts["technologies"].append(str(k))
	slice.mark_done_silently(Rules.ids_satisfied(facts, slice.steps()))

## The tags an item or material carries for the trigger tables: `material`, its tool type, `creature` is not one.
static func _tags_of(key: String) -> Array:
	var tags: Array = []
	if GameData.MATERIALS.has(key):
		tags.append("material")
	var res: Resource = GameData.ITEMS.get(key, null)
	if res != null and res.get("toolType") != null:
		tags.append(str(res.get("toolType")))
	return tags

func _note(kind: String, params: Dictionary = {}) -> void:
	if slice == null:
		return
	if slice.note_event(kind, params) != "" and card != null:
		card.show_check()

func _on_event(kind: String, params: Dictionary) -> void:
	_note(kind, params)

func _on_changed() -> void:
	pass

func _on_craft_resolved(result: Dictionary) -> void:
	if not bool(result.get("success", false)):
		return
	var crafter := str(result.get("player_id", ""))
	if crafter != "" and crafter != _local() and crafter != "player":
		return
	for out in result.get("outputs", []):
		var key := str(out.get("item", ""))
		_crafted[key] = int(_crafted.get(key, 0)) + int(out.get("quantity", 1))
		_note("item_crafted", { "item": key, "tags": _tags_of(key) })

func _on_station_placed(_id: String, type: String, _pos: Vector3) -> void:
	_note("station_placed", { "type": type })

func _on_tech_unlocked(tech_id: String, player_id: String) -> void:
	if player_id == _local() or player_id == "" or player_id == "player":
		_note("technology_researched", { "technology": tech_id })

func _on_creature_died(entity_id: String, _pos: Vector3, killer_id: String, _landing: Vector3) -> void:
	if killer_id == _local() or killer_id == "player":
		_note("creature_killed", { "creature": entity_id, "tags": ["creature"] })

func _on_harvest_resolved(player_id: String, _carcass: String, reason: String, _items: Array) -> void:
	if reason == "" and (player_id == _local() or player_id == "player" or player_id == ""):
		_note("carcass_harvested")

func _on_bed_synced(player_id: String, bed: Dictionary) -> void:
	if player_id != _local() or bed.is_empty():
		return
	_bed = bed
	_note("bed_placed")
	_check_shelter()

## The bed may be walled and roofed long after it is placed, so this runs on a timer while the step is open.
func _check_shelter() -> void:
	if _bed.is_empty() or slice == null or slice.is_done("build_shelter"):
		return
	if _bed_sheltered(_bed):
		_note("shelter_complete")

func _bed_sheltered(bed: Dictionary) -> bool:
	var chunk: Vector2i = bed["chunk"]
	var local: Vector3 = bed["local"]
	var world := Vector3(chunk.x * WorldPos.CHUNK_METERS + local.x, local.y, chunk.y * WorldPos.CHUNK_METERS + local.z)
	return ShelterRule.is_sheltered(world, func(t: Vector2i) -> Array: return root._voxel.get_runs_at_tile(t))

func _on_respawned(_pos: Vector3) -> void:
	_note("respawned")

func _on_chat(text: String, pid: String) -> void:
	if pid == "" or pid == _local():
		if not text.begins_with("/"):
			_note("chat_sent")

func _on_equipment_changed(player_id: String, worn: Dictionary) -> void:
	if player_id == _local() or player_id == "":
		for slot in worn:
			if str(worn[slot]) != "":
				_note("item_equipped", { "slot": str(slot) })

## The local pack changed: what it gained is what was gathered (picked up, mined, felled or crafted).
func _on_inventory_changed() -> void:
	_pack_dirty = true   # read in `tick`, after this frame's craft results have been seen

func _scan_pack() -> void:
	_pack_dirty = false
	var contents: Dictionary = root._inventory.get_contents()
	if _pack_known:
		for key in contents:
			var gained := int(contents[key]) - int(_pack.get(key, 0))
			var made := mini(gained, int(_crafted.get(key, 0)))
			if made > 0:
				gained -= made
				_crafted[key] = int(_crafted[key]) - made
			if gained > 0:
				_note("item_gathered", { "item": str(key), "tags": _tags_of(str(key)), "count": gained })
	_pack = contents.duplicate()
	_pack_known = true

func _on_waystones_synced(player_id: String, station_ids: Array) -> void:
	if player_id == _local() and not station_ids.is_empty():
		_note("waystone_discovered")

func tick(delta: float) -> void:
	if slice == null or root._player == null:
		return
	seed_from_player()
	if _pack_dirty or not _pack_known:
		_scan_pack()
	_crafted.clear()
	_shelter_clock += delta
	if _shelter_clock >= SHELTER_CHECK_S:
		_shelter_clock = 0.0
		_check_shelter()
	var pos: Vector3 = root._player.get_position()
	if _have_pos:
		var d := Vector2(pos.x - _last_pos.x, pos.z - _last_pos.z).length()
		if d > 0.0 and d < TELEPORT_M:
			_note("moved_metres", { "metres": d })
	_last_pos = pos
	_have_pos = true
	if root._player.look_degrees - _look_from >= LOOK_DEGREES:
		_note("camera_turned")
		_look_from = root._player.look_degrees
	var tiers: Variant = root._registry.get_record(_local()).get("skills", {})
	if tiers is Dictionary:
		if tiers != _skills:
			if _skills_known:
				_note("skill_tier_up")
			_skills = (tiers as Dictionary).duplicate()
		_skills_known = true
