extends Node
## Inventory slice — collects nearby loot pickups and tracks carried items.
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : pickup_requested(pickup_id)            — player aims at a pickup and clicks
##   OUT : item_picked_up(item_id, quantity)
##         inventory_full()
##         inventory_changed()                    — contents mutated (UI refresh)
## Pickups are collected on demand: PlayerSlice raycasts for the aimed pickup and
## emits pickup_requested; this slice resolves the item via loot_slice and adds it.
##
## Public API:
##   get_contents()                   -> Dictionary  { item_id: quantity }
##   get_item_count(item_id: String)  -> int
##   get_total_slots_used()           -> int
##   get_current_weight()             -> float
##   get_max_weight()                 -> float
##   get_max_slots()                  -> int
##   drop_item(item_id, quantity)     -> bool

## Inventory capacity comes from the Inventory entity in the fabric
## (GameData.PLAYERS["Inventory"].maxSlots / maxWeightKg), loaded in _ready().
## Initial values below match the fabric defaults.
var _max_slots: int = 30
var _max_weight: float = 50.0

## Weights for raw creature drops that are not fabric items (no .tres resource).
## Values are authoritative design decisions; any change starts in this table.
const RAW_DROP_WEIGHTS: Dictionary = {
	"raw_boar_meat":    0.8,
	"boar_hide":        1.5,
	"boar_tusk":        0.4,
	"wolf_pelt":        1.2,
	"wolf_fang":        0.1,
	"alpha_wolf_fang":  0.2,
	"bison_meat":       1.2,
	"bison_hide":       3.0,
	"bison_bone":       1.0,
	"bison_horn":       0.5,
	"hawk_feather":     0.05,
	"hawk_talon":       0.1,
	"slag_gland":       0.6,
	"volcanic_slime":   0.3,
	"gargoyle_shard":   0.8,
	"ember_core":       0.4,
	"glimmer_pelt":     0.9,
	"foxfire_essence":  0.2,
	"veil_hide":        1.1,
	"paralysis_venom":  0.1,
	"void_scale":       0.6,
	"void_essence":     0.3,
	"rift_shard":       1.0,
	"warden_core":      0.8,
}

## Built at _ready() from GameData.ITEMS so fabric item weights are authoritative.
var _item_weight_cache: Dictionary = {}

## Durability tracking: item_id -> remaining durability points. Populated lazily
## from GameData.ITEMS for non-stackable items that declare a `durability` field
## (tools, weapons, armour, shields, unique tablets). Stacks of a durable item
## share one durability value — the inventory models item_id -> quantity, not
## per-slot item instances.
var _item_durability_cache: Dictionary = {}
var _durability: Dictionary = {}

## Durability points consumed per use, by action type. Actions without a
## specific entry fall back to DURABILITY_DECREMENT.
const DURABILITY_DECREMENT: float = 1.0
const ACTION_DECREMENT: Dictionary = {
	"mine": 1.0,
	"chop": 1.0,
	"place": 1.0,
	"attack": 1.0,
}

## The actual inventory: item_id -> quantity.
var _contents: Dictionary = {}
var _current_weight: float = 0.0
var _is_full: bool = false

## Reference to LootSlice, set by game_root at startup.
var loot_slice: Node = null

func _ready() -> void:
	_load_capacity()
	_build_weight_cache()
	_build_durability_cache()
	GameBus.pickup_requested.connect(_on_pickup_requested)

func get_contents() -> Dictionary:
	return _contents.duplicate()

func get_item_count(item_id: String) -> int:
	return _contents.get(item_id, 0)

func get_total_slots_used() -> int:
	return _contents.size()

func get_current_weight() -> float:
	return _current_weight

func get_max_weight() -> float:
	return _max_weight

func get_max_slots() -> int:
	return _max_slots

## Drop quantity of item_id from inventory; returns true if successful.
func drop_item(item_id: String, quantity: int) -> bool:
	var have: int = _contents.get(item_id, 0)
	if have < quantity or quantity <= 0:
		return false
	var w := _item_weight(item_id) * float(quantity)
	_current_weight = maxf(_current_weight - w, 0.0)
	if have == quantity:
		_contents.erase(item_id)
	else:
		_contents[item_id] = have - quantity
	_is_full = false
	GameBus.inventory_changed.emit()
	return true

## Add quantity of item_id to the inventory, respecting slot + weight limits.
## Returns true on success; false if it would exceed either limit (no change).
func add_item(item_id: String, quantity: int) -> bool:
	if quantity <= 0:
		return true
	var add_weight := _item_weight(item_id) * float(quantity)
	if _current_weight + add_weight > _max_weight:
		return false
	if not _contents.has(item_id) and _contents.size() >= _max_slots:
		return false
	_contents[item_id] = _contents.get(item_id, 0) + quantity
	_current_weight += add_weight
	_is_full = false
	GameBus.inventory_changed.emit()
	return true

## Consume a { item_id: quantity } map atomically: returns true only if the
## entire map is available, in which case every item is removed together.
func consume_items(counts: Dictionary) -> bool:
	for item_id in counts:
		var qty: int = int(counts[item_id])
		if _contents.get(item_id, 0) < qty:
			return false
	for item_id in counts:
		var qty: int = int(counts[item_id])
		var have: int = _contents[item_id]
		_current_weight = maxf(_current_weight - _item_weight(item_id) * float(qty), 0.0)
		if have == qty:
			_contents.erase(item_id)
		else:
			_contents[item_id] = have - qty
	_is_full = false
	GameBus.inventory_changed.emit()
	return true

## Whether a { item_id: quantity } map can be added without exceeding weight or
## slot limits. Non-mutating; used by CraftingSlice to pre-flight outputs.
func can_add_items(counts: Dictionary) -> bool:
	var weight := _current_weight
	var slots := _contents.size()
	for item_id in counts:
		var qty: int = int(counts[item_id])
		weight += _item_weight(item_id) * float(qty)
		if not _contents.has(item_id):
			slots += 1
	if weight > _max_weight:
		return false
	if slots > _max_slots:
		return false
	return true

## Whether `item_id` has a durability field in the fabric (tools/weapons/armor).
func is_durable(item_id: String) -> bool:
	return _item_durability_cache.has(item_id)

## Current remaining durability for `item_id`, or -1.0 when the item has no
## durability model. Returns max durability when the item is held but has not
## yet been used.
func get_durability(item_id: String) -> float:
	if not _item_durability_cache.has(item_id):
		return -1.0
	_ensure_durability(item_id)
	return float(_durability[item_id])

## Maximum durability points for `item_id` from GameData.ITEMS, or -1.0.
func get_max_durability(item_id: String) -> float:
	return float(_item_durability_cache.get(item_id, -1.0))

## Current condition tier (pristine → worn → damaged → broken) for a durable
## item, derived from durability points vs. max. Non-durable items return "".
func get_condition(item_id: String) -> String:
	if not _item_durability_cache.has(item_id):
		return ""
	var max_d := get_max_durability(item_id)
	var cur := get_durability(item_id)
	if cur <= 0.0:
		return "broken"
	if cur >= max_d:
		return "pristine"
	if cur >= max_d * 0.5:
		return "worn"
	return "damaged"

## Use a held item for `action_type`. Returns true when the action is allowed
## (item held and, for durable items, not already broken); false when blocked
## (not held, or already broken). Using a durable item decrements its
## durability; when it crosses to 0 the item breaks (item_broke emitted), but
## the use that consumed the last point still counts as allowed — the tool
## breaks AS A RESULT of the use, it does not pre-empt it.
func use_item(item_id: String, action_type: String = "use") -> bool:
	if _contents.get(item_id, 0) <= 0:
		return false
	if not _item_durability_cache.has(item_id):
		return true
	_ensure_durability(item_id)
	if float(_durability[item_id]) <= 0.0:
		GameBus.item_broke.emit(item_id)
		return false
	var dec := float(ACTION_DECREMENT.get(action_type, DURABILITY_DECREMENT))
	_durability[item_id] = maxf(float(_durability[item_id]) - dec, 0.0)
	GameBus.inventory_changed.emit()
	if float(_durability[item_id]) <= 0.0:
		GameBus.item_broke.emit(item_id)
	return true

## Find the first held durable item whose key contains `hint` (e.g. "Pick" for
## mining, "Axe" for chopping). Returns the item_id, or "" when none is held.
## This is a stopgap: the fabric has no structured tool-class field yet, so the
## mining/chopping distinction is encoded in the item name.
func find_tool(hint: String) -> String:
	for item_id in _item_durability_cache:
		if _contents.get(item_id, 0) > 0 and str(item_id).contains(hint):
			return str(item_id)
	return ""

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _on_pickup_requested(pickup_id: String) -> void:
	if loot_slice == null:
		return
	var p: Dictionary = loot_slice.get_pickup(pickup_id)
	if p.is_empty():
		return
	_try_pickup(pickup_id, p["item_id"], p["quantity"])

func _try_pickup(pickup_id: String, item_id: String, quantity: int) -> void:
	if _is_full:
		push_warning("InventorySlice: cannot pick up '%s' — inventory full" % item_id)
		return

	var add_weight := _item_weight(item_id) * float(quantity)
	if _current_weight + add_weight > _max_weight:
		push_warning("InventorySlice: '%s' ×%d would exceed weight limit (%.1f/%.1f kg)" % [
			item_id, quantity, _current_weight + add_weight, _max_weight])
		GameBus.inventory_full.emit()
		_is_full = true
		return

	# Check slot budget for new item types.
	var already_have := _contents.has(item_id)
	var would_add_slot := not already_have
	if would_add_slot and _contents.size() >= _max_slots:
		push_warning("InventorySlice: cannot pick up '%s' — no free slots (%d/%d)" % [
			item_id, _contents.size(), _max_slots])
		GameBus.inventory_full.emit()
		_is_full = true
		return

	# Consume the world pickup if LootSlice is available.
	if loot_slice != null:
		var p: Dictionary = loot_slice.consume_pickup(pickup_id)
		if p.is_empty():
			return   # already claimed by someone else

	# Add to inventory.
	_contents[item_id] = _contents.get(item_id, 0) + quantity
	_current_weight += add_weight

	GameBus.item_picked_up.emit(item_id, quantity)
	print("InventorySlice: picked up %s ×%d  (%.1f/%.1f kg  %d/%d slots)" % [
		item_id, quantity, _current_weight, _max_weight, _contents.size(), _max_slots])
	GameBus.inventory_changed.emit()

	# Re-check full state after pickup.
	if _contents.size() >= _max_slots or _current_weight >= _max_weight:
		if not _is_full:
			_is_full = true
			GameBus.inventory_full.emit()

## Load inventory capacity from the Inventory entity (GameData.PLAYERS).
func _load_capacity() -> void:
	var res: Resource = GameData.PLAYERS.get("Inventory", null)
	if res != null:
		_max_slots = int(res.get("maxSlots"))
		_max_weight = float(res.get("maxWeightKg"))

func _build_weight_cache() -> void:
	# Seed with raw-drop weights (creature drops not in the item fabric).
	_item_weight_cache.merge(RAW_DROP_WEIGHTS)
	# Override/extend with fabric item weights from GameData.ITEMS (authoritative).
	for key in GameData.ITEMS:
		var res: Resource = GameData.ITEMS[key]
		if res != null:
			_item_weight_cache[key] = float(res.get("weight"))

## Build the durability cache from GameData.ITEMS: only non-stackable items
## that declare a `durability` field (tools, weapons, armour, shields, unique
## tablets) are tracked as per-instance durable equipment. Stackable items
## (materials, components, food, potions, magical shards) also carry a
## `durability` field, but it models freshness / potency / charge / structural
## integrity — mechanics a per-use decrement must NOT apply to. `stackable` is
## the fabric's own discriminator: equipment is always non-stackable.
func _build_durability_cache() -> void:
	for key in GameData.ITEMS:
		var res: Resource = GameData.ITEMS[key]
		if res == null:
			continue
		if bool(res.get("stackable")):
			continue
		var d = res.get("durability")
		if d != null and float(d) > 0.0:
			_item_durability_cache[key] = float(d)

func _item_weight(item_id: String) -> float:
	return float(_item_weight_cache.get(item_id, 0.0))

## Initialize a durable item's durability to its fabric max on first access.
func _ensure_durability(item_id: String) -> void:
	if _item_durability_cache.has(item_id) and not _durability.has(item_id):
		_durability[item_id] = _item_durability_cache[item_id]
