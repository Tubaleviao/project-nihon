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
## Drop tables are defined inline here, matching the LootTable entity in the fabric.
## Format per entry: { "item_id": String, "chance": float, "min_qty": int, "max_qty": int }

const DESPAWN_SECONDS := 120.0

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
	return p

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _on_creature_died(entity_id: String, position: Vector3, _killer_id: String) -> void:
	if entity_id == "player":
		return
	var table: Array = LOOT_TABLES.get(entity_id, [])
	if table.is_empty():
		print("LootSlice: no loot table for '%s'" % entity_id)
		return
	for entry in table:
		if randf() <= entry["chance"]:
			var qty: int = randi_range(entry["min_qty"], entry["max_qty"])
			if qty <= 0:
				continue
			var pid := "pickup_%d" % _next_id
			_next_id += 1
			_pickups[pid] = {
				"item_id":    entry["item_id"],
				"quantity":   qty,
				"position":   position,
				"spawned_at": Time.get_ticks_msec(),
			}
			GameBus.loot_dropped.emit(pid, entry["item_id"], position, qty)
			print("LootSlice: %s dropped %s ×%d at %s" % [entity_id, entry["item_id"], qty, position])

func _tick_despawn() -> void:
	var now := Time.get_ticks_msec()
	var expired: Array = []
	for pid in _pickups:
		var age_ms: float = float(now - _pickups[pid]["spawned_at"])
		if age_ms >= DESPAWN_SECONDS * 1000.0:
			expired.append(pid)
	for pid in expired:
		_pickups.erase(pid)
		GameBus.loot_expired.emit(pid)
		print("LootSlice: pickup %s expired" % pid)
