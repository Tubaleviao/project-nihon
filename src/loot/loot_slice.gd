extends Node
## Loot slice — spawns world-space pickups when a creature dies.
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : creature_died(entity_id, position, killer_id)
##   OUT : loot_dropped(pickup_id, item_id, position, quantity)
##         loot_expired(pickup_id)
##
## Public API:
##   get_pickups_near(pos: Vector3, radius: float) -> Array[Dictionary]
##   consume_pickup(pickup_id: String)              -> Dictionary  (empty on miss)
##
## Drop tables are a direct transcription of each creature's "drop" behavior rules
## in the fabric (fabric/world/creatures/*.js). They are the authoritative source;
## any balance change starts there.
## Format per entry: { "item_id": String, "chance": float, "min_qty": int, "max_qty": int }
##
## DESPAWN_SECONDS matches LootTable.despawnSeconds defaultValue in the fabric
## (fabric/gameplay/loot.js). If the fabric value changes, update this constant.
const DESPAWN_SECONDS := 120.0  # LootTable.despawnSeconds defaultValue

## Loot tables keyed by creature entity id (matches GameData.CREATURES keys).
const LOOT_TABLES: Dictionary = {
	"ForestBoar": [
		{ "item_id": "raw_boar_meat",   "chance": 1.00, "min_qty": 1, "max_qty": 3 },
		{ "item_id": "boar_hide",       "chance": 1.00, "min_qty": 1, "max_qty": 1 },
		{ "item_id": "boar_tusk",       "chance": 0.20, "min_qty": 1, "max_qty": 1 },
	],
	"GraywolfPack": [
		{ "item_id": "wolf_pelt",       "chance": 1.00, "min_qty": 1, "max_qty": 1 },
		{ "item_id": "wolf_fang",       "chance": 0.40, "min_qty": 0, "max_qty": 1 },
		{ "item_id": "alpha_wolf_fang", "chance": 1.00, "min_qty": 1, "max_qty": 1 },
	],
	"SteppeBison": [
		{ "item_id": "bison_meat",      "chance": 1.00, "min_qty": 3, "max_qty": 6 },
		{ "item_id": "bison_hide",      "chance": 1.00, "min_qty": 2, "max_qty": 2 },
		{ "item_id": "bison_bone",      "chance": 1.00, "min_qty": 1, "max_qty": 2 },
		{ "item_id": "bison_horn",      "chance": 0.25, "min_qty": 1, "max_qty": 1 },
	],
	"RidgeHawk": [
		{ "item_id": "hawk_feather",    "chance": 1.00, "min_qty": 1, "max_qty": 3 },
		{ "item_id": "hawk_talon",      "chance": 0.35, "min_qty": 1, "max_qty": 1 },
	],
	"LavaSlug": [
		{ "item_id": "slag_gland",      "chance": 1.00, "min_qty": 1, "max_qty": 1 },
		{ "item_id": "volcanic_slime",  "chance": 0.70, "min_qty": 1, "max_qty": 2 },
	],
	"CinderGargoyle": [
		{ "item_id": "gargoyle_shard",  "chance": 1.00, "min_qty": 1, "max_qty": 2 },
		{ "item_id": "ember_core",      "chance": 0.30, "min_qty": 1, "max_qty": 1 },
	],
	"GlimmerFox": [
		{ "item_id": "glimmer_pelt",    "chance": 1.00, "min_qty": 1, "max_qty": 1 },
		{ "item_id": "foxfire_essence", "chance": 0.50, "min_qty": 1, "max_qty": 1 },
	],
	"VeilStalker": [
		{ "item_id": "veil_hide",       "chance": 1.00, "min_qty": 1, "max_qty": 1 },
		{ "item_id": "paralysis_venom", "chance": 0.60, "min_qty": 1, "max_qty": 2 },
	],
	"VoidSerpent": [
		{ "item_id": "void_scale",      "chance": 1.00, "min_qty": 2, "max_qty": 4 },
		{ "item_id": "void_essence",    "chance": 0.40, "min_qty": 1, "max_qty": 1 },
	],
	"RiftWarden": [
		{ "item_id": "rift_shard",      "chance": 1.00, "min_qty": 1, "max_qty": 1 },
		{ "item_id": "warden_core",     "chance": 0.20, "min_qty": 1, "max_qty": 1 },
		{ "item_id": "void_essence",    "chance": 0.60, "min_qty": 1, "max_qty": 2 },
	],
}

## Active pickups keyed by pickup_id.
## Each entry: { "item_id", "quantity", "position", "spawned_at" }
var _pickups: Dictionary = {}
var _next_id: int = 0

## Set by game_root so instance IDs can be resolved to fabric creature keys.
var creature_slice: Node = null

func _ready() -> void:
	GameBus.creature_died.connect(_on_creature_died)

func _process(delta: float) -> void:
	_tick_despawn()

## Return all active pickups within radius of pos.
func get_pickups_near(pos: Vector3, radius: float) -> Array:
	var result: Array = []
	for pid in _pickups:
		var p: Dictionary = _pickups[pid]
		if p["position"].distance_to(pos) <= radius:
			result.append({ "id": pid, "item_id": p["item_id"], "quantity": p["quantity"], "position": p["position"] })
	return result

## Remove and return a pickup by id; returns empty dict if not found.
func consume_pickup(pickup_id: String) -> Dictionary:
	if not _pickups.has(pickup_id):
		return {}
	var p: Dictionary = _pickups[pickup_id]
	_pickups.erase(pickup_id)
	if p.has("body") and p["body"] != null:
		p["body"].queue_free()
	return p

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _on_creature_died(entity_id: String, position: Vector3, _killer_id: String) -> void:
	if entity_id == "player":
		return
	# entity_id may be a creature instance_id; resolve to the fabric key for drop table lookup.
	var fabric_key := entity_id
	if creature_slice != null:
		var resolved: String = creature_slice.get_instance_creature_id(entity_id)
		if resolved != "":
			fabric_key = resolved
	var table: Array = LOOT_TABLES.get(fabric_key, [])
	if table.is_empty():
		print("LootSlice: no loot table for '%s' (fabric key: %s)" % [entity_id, fabric_key])
		return
	for entry in table:
		if randf() <= entry["chance"]:
			var qty: int = randi_range(entry["min_qty"], entry["max_qty"])
			if qty <= 0:
				continue
			var pid := "pickup_%d" % _next_id
			_next_id += 1
			# Build a visible body so the item actually appears on the ground.
			var body := _make_pickup_visual(entry["item_id"], position)
			add_child(body)
			_pickups[pid] = {
				"item_id":    entry["item_id"],
				"quantity":   qty,
				"position":   position,
				"spawned_at": Time.get_ticks_msec(),
				"body":       body,
			}
			GameBus.loot_dropped.emit(pid, entry["item_id"], position, qty)
			print("LootSlice: %s dropped %s ×%d at %s" % [fabric_key, entry["item_id"], qty, position])

func _tick_despawn() -> void:
	var now := Time.get_ticks_msec()
	var expired: Array = []
	for pid in _pickups:
		var age_ms: float = float(now - _pickups[pid]["spawned_at"])
		if age_ms >= DESPAWN_SECONDS * 1000.0:
			expired.append(pid)
	for pid in expired:
		var p: Dictionary = _pickups[pid]
		if p.has("body") and p["body"] != null:
			p["body"].queue_free()
		_pickups.erase(pid)
		GameBus.loot_expired.emit(pid)
		print("LootSlice: pickup %s expired" % pid)

# ---------------------------------------------------------------------------
# Visuals
# ---------------------------------------------------------------------------

## Build a small coloured box so a dropped item is visible in the world.
func _make_pickup_visual(item_id: String, pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = "Pickup_%s" % item_id
	node.position = pos

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.25, 0.25, 0.25)
	mesh.mesh = box
	# Rest the pickup just above the surface so it reads as a dropped item.
	mesh.position = Vector3(0.0, 0.2, 0.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = _item_color(item_id)
	mesh.material_override = mat

	node.add_child(mesh)
	return node

## Deterministic per-item colour so the same item always looks the same.
func _item_color(item_id: String) -> Color:
	var hue := float(absi(hash(item_id)) % 360) / 360.0
	return Color.from_hsv(hue, 0.65, 0.9)
