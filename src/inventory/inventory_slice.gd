extends Node
## Inventory slice — collects nearby loot pickups and tracks carried items.
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : loot_dropped(pickup_id, item_id, position, quantity)
##         player_state_changed(payload)          — used for player position
##   OUT : item_picked_up(item_id, quantity)
##         inventory_full()
##
## Public API:
##   get_contents()                   -> Dictionary  { item_id: quantity }
##   get_item_count(item_id: String)  -> int
##   get_total_slots_used()           -> int
##   drop_item(item_id, quantity)     -> bool

const MAX_SLOTS    := 30
const MAX_WEIGHT   := 50.0     # kg
const PICKUP_RADIUS := 2.0     # tiles — auto-collect within this range

## Weights per item_id (kg). Fallback weight used for unknown items.
const ITEM_WEIGHTS: Dictionary = {
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
const DEFAULT_WEIGHT := 0.5

## The actual inventory: item_id -> quantity.
var _contents: Dictionary = {}
var _current_weight: float = 0.0
var _is_full: bool = false

## Player's last known world position — updated by player_state_changed.
var _player_pos: Vector3 = Vector3.ZERO

## Reference to LootSlice, set by game_root at startup.
var loot_slice: Node = null

func _ready() -> void:
	GameBus.loot_dropped.connect(_on_loot_dropped)
	GameBus.player_state_changed.connect(_on_player_state_changed)

func get_contents() -> Dictionary:
	return _contents.duplicate()

func get_item_count(item_id: String) -> int:
	return _contents.get(item_id, 0)

func get_total_slots_used() -> int:
	return _contents.size()

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
	return true

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _on_player_state_changed(payload: Dictionary) -> void:
	_player_pos = payload.get("position", _player_pos)

func _on_loot_dropped(pickup_id: String, item_id: String, position: Vector3, quantity: int) -> void:
	if position.distance_to(_player_pos) <= PICKUP_RADIUS:
		_try_pickup(pickup_id, item_id, quantity)

func _try_pickup(pickup_id: String, item_id: String, quantity: int) -> void:
	if _is_full:
		push_warning("InventorySlice: cannot pick up '%s' — inventory full" % item_id)
		return

	var add_weight := _item_weight(item_id) * float(quantity)
	if _current_weight + add_weight > MAX_WEIGHT:
		push_warning("InventorySlice: '%s' ×%d would exceed weight limit (%.1f/%.1f kg)" % [
			item_id, quantity, _current_weight + add_weight, MAX_WEIGHT])
		GameBus.inventory_full.emit()
		_is_full = true
		return

	# Check slot budget for new item types.
	var already_have := _contents.has(item_id)
	var would_add_slot := not already_have
	if would_add_slot and _contents.size() >= MAX_SLOTS:
		push_warning("InventorySlice: cannot pick up '%s' — no free slots (%d/%d)" % [
			item_id, _contents.size(), MAX_SLOTS])
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
		item_id, quantity, _current_weight, MAX_WEIGHT, _contents.size(), MAX_SLOTS])

	# Re-check full state after pickup.
	if _contents.size() >= MAX_SLOTS or _current_weight >= MAX_WEIGHT:
		if not _is_full:
			_is_full = true
			GameBus.inventory_full.emit()

func _item_weight(item_id: String) -> float:
	return ITEM_WEIGHTS.get(item_id, DEFAULT_WEIGHT)
