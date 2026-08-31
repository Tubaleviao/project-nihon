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
## Drop items, chances, and quantities live in each creature's `drops` fabric
## field (single source of truth); only the kg weight is runtime-local, so any
## weight change starts in this table.
const RAW_DROP_WEIGHTS: Dictionary = {
	"raw_boar_meat":         0.8,
	"boar_hide":             1.5,
	"boar_tusk":             0.4,
	"wolf_pelt":             1.2,
	"wolf_fang":             0.1,
	"alpha_wolf_fang":       0.2,
	"bison_meat":            1.2,
	"bison_hide":            3.0,
	"bison_bone":            1.0,
	"bison_horn":            0.5,
	"hawk_feather":          0.05,
	"hawk_talon":            0.1,
	"slug_shell_shard":      0.6,
	"superheated_slime_vial": 0.3,
	"lava_core_organ":       0.5,
	"gargoyle_wing_fragment": 0.8,
	"petrified_binding_stone": 0.9,
	"gargoyle_crest":        0.2,
	"glimmer_pelt":          0.9,
	"luminescent_reagent":   0.2,
	"veilstalker_venom_sac": 0.1,
	"shadow_phase_membrane": 0.5,
	"crystallised_phase_shard": 0.3,
	"void_scale":            0.6,
	"void_serpent_fang":     0.4,
	"phase_locked_core":     0.5,
	"rift_shard":            1.0,
	"void_core_crystal":     0.8,
	"warden_sigil":          0.2,
}

## Built at _ready() from GameData.MATERIALS (density) and GameData.ITEMS (weight).
var _item_weight_cache: Dictionary = {}

## Durability tracking: item_id -> Array of per-instance durability points,
## one entry per held unit. Populated from GameData.ITEMS for non-stackable
## items that declare a `durability` field (tools, weapons, armour, shields,
## unique tablets). Each held instance keeps its own durability, so a stack of
## the same tool can mix a broken copy with a pristine one.
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

## Condition tiers ordered pristine → broken, mirroring the fabric's
## DURABILITY_STATES (fabric/gameplay/items/shared.js). The index of a tier is
## exactly how many condition tiers below pristine it sits, so index == the
## number of tiers a repair must restore (0 = pristine, 3 = broken).
const DURABILITY_STATES: Array = ["pristine", "worn", "damaged", "broken"]

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
	GameBus.inventory_synced.connect(_on_inventory_synced)

## Client-side: replace local contents with a host-authoritative inventory.
func replace_contents(contents: Dictionary) -> void:
	_contents.clear()
	_durability.clear()
	_current_weight = 0.0
	for item_id in contents:
		var qty: int = int(contents[item_id])
		if qty <= 0:
			continue
		_contents[item_id] = qty
		_current_weight += _item_weight(item_id) * float(qty)
		_add_instances(item_id, qty, [])
	_is_full = false
	GameBus.inventory_changed.emit()

func _on_inventory_synced(contents: Dictionary) -> void:
	replace_contents(contents)

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
## Clears the durability record when the last unit is dropped so a fresh pickup
## of the same item key always starts at full durability (not the old worn value).
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
	_remove_instances(item_id, quantity)
	_is_full = false
	GameBus.inventory_changed.emit()
	return true

## Add quantity of item_id to the inventory, respecting slot + weight limits.
## Returns true on success; false if it would exceed either limit (no change).
## `durabilities` is an optional per-instance list (one entry per added unit) that
## sets each transferred instance's durability — used by the trade to carry a
## tool's condition across inventories; empty/omitted means fresh (max).
func add_item(item_id: String, quantity: int, durabilities: Array = []) -> bool:
	if quantity <= 0:
		return true
	var add_weight := _item_weight(item_id) * float(quantity)
	if _current_weight + add_weight > _max_weight:
		return false
	if not _contents.has(item_id) and _contents.size() >= _max_slots:
		return false
	_contents[item_id] = _contents.get(item_id, 0) + quantity
	_current_weight += add_weight
	_add_instances(item_id, quantity, durabilities)
	_is_full = false
	GameBus.inventory_changed.emit()
	return true

## Consume a { item_id: quantity } map atomically: returns true only if the
## entire map is available, in which case every item is removed together.
func consume_items(counts: Dictionary) -> bool:
	return bool(consume_items_with_durability(counts).get("success", false))

## Consume a { item_id: quantity } map atomically and return the per-instance
## durability values removed for each durable item (worst first), so a caller
## (the trade) can carry the exact condition to a recipient. Returns
## { success: bool, removed: { item_id: Array } }.
func consume_items_with_durability(counts: Dictionary) -> Dictionary:
	for item_id in counts:
		var qty: int = int(counts[item_id])
		if _contents.get(item_id, 0) < qty:
			return { "success": false, "removed": {} }
	var removed := {}
	for item_id in counts:
		var qty: int = int(counts[item_id])
		var have: int = _contents[item_id]
		_current_weight = maxf(_current_weight - _item_weight(item_id) * float(qty), 0.0)
		if have == qty:
			_contents.erase(item_id)
		else:
			_contents[item_id] = have - qty
		var taken: Array = _remove_instances(item_id, qty)
		if not taken.is_empty():
			removed[item_id] = taken
	_is_full = false
	GameBus.inventory_changed.emit()
	return { "success": true, "removed": removed }

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

## Find the first held durable tool whose fabric `toolType` matches `tool_type`
## (e.g. "pick" for mining, "axe" for chopping). Broken tools (durability == 0)
## are skipped. Returns the item_id, or "" when no usable tool is held.
func find_tool(tool_type: String) -> String:
	for item_id in _item_durability_cache:
		if _contents.get(item_id, 0) <= 0:
			continue
		var res: Resource = GameData.ITEMS.get(item_id, null)
		if res == null or str(res.get("toolType")) != tool_type:
			continue
		_ensure_durability(item_id)
		if not _has_usable_instance(item_id):
			continue
		return str(item_id)
	return ""

## Whether `item_id` has a durability field in the fabric (tools/weapons/armor).
func is_durable(item_id: String) -> bool:
	return _item_durability_cache.has(item_id)

## Current remaining durability for `item_id`, or -1.0 when the item has no
## durability model. Returns the WORST (most-worn) instance's durability, so a
## stack with any broken copy reports 0.
func get_durability(item_id: String) -> float:
	if not _item_durability_cache.has(item_id):
		return -1.0
	_ensure_durability(item_id)
	var arr: Array = _durability.get(item_id, [])
	if arr.is_empty():
		return -1.0
	var worst := float(arr[0])
	for v in arr:
		worst = minf(worst, float(v))
	return worst

## Maximum durability points for `item_id` from GameData.ITEMS, or -1.0.
func get_max_durability(item_id: String) -> float:
	return float(_item_durability_cache.get(item_id, -1.0))

## Return a copy of the per-instance durability values for a held durable item
## (one entry per held unit), or an empty array when the item is not durable or
## not held. Used for inspection and internal-consistency tests.
func get_durability_values(item_id: String) -> Array:
	if not _item_durability_cache.has(item_id):
		return []
	_ensure_durability(item_id)
	return (_durability.get(item_id, []) as Array).duplicate()

## Current condition tier (pristine → worn → damaged → broken) for a durable
## item, derived from the WORST instance's durability vs. max. Non-durable items
## return "".
func get_condition(item_id: String) -> String:
	if not _item_durability_cache.has(item_id):
		return ""
	var max_d := get_max_durability(item_id)
	var cur := get_durability(item_id)
	if cur < 0.0:
		return ""
	return _condition_for(cur, max_d)

## Number of condition tiers below pristine for `item_id`, summed across every
## held instance — i.e. the total tiers a repair must restore to make the whole
## stack pristine (0 = already pristine). Non-durable items return 0.
func condition_tiers_below_pristine(item_id: String) -> int:
	if not _item_durability_cache.has(item_id):
		return 0
	_ensure_durability(item_id)
	var max_d := get_max_durability(item_id)
	var total := 0
	for v in _durability.get(item_id, []):
		total += DURABILITY_STATES.find(_condition_for(float(v), max_d))
	return total

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
	var arr: Array = _durability[item_id]
	var idx := -1
	for i in arr.size():
		if float(arr[i]) > 0.0:
			idx = i
			break
	if idx == -1:
		GameBus.item_broke.emit(item_id)
		return false
	var dec := float(ACTION_DECREMENT.get(action_type, DURABILITY_DECREMENT))
	arr[idx] = maxf(float(arr[idx]) - dec, 0.0)
	_durability[item_id] = arr
	GameBus.inventory_changed.emit()
	if float(arr[idx]) <= 0.0:
		GameBus.item_broke.emit(item_id)
	return true

## Restore a held durable item's durability to its fabric maximum (pristine
## condition). Returns true when the item is held and durable; false otherwise
## (not held, or not a durable equipment item — stackable materials have no
## per-use durability model). No material/station/skill checks here — those
## live in CraftingSlice.repair(), which calls this once its own gates pass.
func repair_item(item_id: String) -> bool:
	if not _item_durability_cache.has(item_id):
		return false
	if _contents.get(item_id, 0) <= 0:
		return false
	_ensure_durability(item_id)
	var max_d := float(_item_durability_cache[item_id])
	var arr: Array = _durability[item_id]
	for i in arr.size():
		arr[i] = max_d
	_durability[item_id] = arr
	GameBus.inventory_changed.emit()
	return true

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

	# Add to inventory. add_item re-checks capacity and handles durability init +
	# weight bookkeeping + inventory_changed.
	if not add_item(item_id, quantity):
		push_warning("InventorySlice: add_item failed for '%s' during pickup" % item_id)
		return

	GameBus.item_picked_up.emit(item_id, quantity)
	print("InventorySlice: picked up %s ×%d  (%.1f/%.1f kg  %d/%d slots)" % [
		item_id, quantity, _current_weight, _max_weight, _contents.size(), _max_slots])

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
	# Seed with raw-drop weights (creature drops not in the item or material fabric).
	_item_weight_cache.merge(RAW_DROP_WEIGHTS)
	# Verify every drop item referenced in creature fabric has a weight entry.
	# Keys come from the single source of truth (creature drop tables); RAW_DROP_WEIGHTS
	# must cover all of them — warn here so new fabric drops are never silently weightless.
	for creature_id in GameData.CREATURES:
		var res: Resource = GameData.CREATURES[creature_id]
		if res == null:
			continue
		var raw_drops = res.get("drops")
		var drops_arr: Array = []
		if raw_drops is Array:
			drops_arr = raw_drops
		elif raw_drops is String and raw_drops != "":
			var parsed = JSON.parse_string(raw_drops)
			if parsed is Array:
				drops_arr = parsed
		for entry in drops_arr:
			if entry is not Dictionary:
				continue
			var item_id: String = str(entry.get("item", ""))
			if item_id == "":
				continue
			# Skip items that have a fabric resource — those get their weight from ITEMS below.
			if GameData.ITEMS.has(item_id):
				continue
			if not _item_weight_cache.has(item_id):
				push_warning("InventorySlice: drop item '%s' (from creature '%s') has no weight in RAW_DROP_WEIGHTS — defaulting to 0 kg. Add it to RAW_DROP_WEIGHTS." % [item_id, creature_id])
	# Fabric raw materials (mined from terrain) declare density (g/cm³); use that
	# as a per-unit kg weight so mined items aren't weightless.
	for key in GameData.MATERIALS:
		var res: Resource = GameData.MATERIALS[key]
		if res != null:
			_item_weight_cache[key] = float(res.get("density"))
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

## Initialize a durable item's durability array to its fabric max on first
## access (one entry per held unit).
func _ensure_durability(item_id: String) -> void:
	if not _item_durability_cache.has(item_id) or _durability.has(item_id):
		return
	var qty := int(_contents.get(item_id, 0))
	var max_d := float(_item_durability_cache[item_id])
	var arr: Array = []
	for i in qty:
		arr.append(max_d)
	_durability[item_id] = arr

## Append `qty` per-instance durability entries to `item_id`. Each entry takes
## its value from `durabilities[i]` (clamped) when present, else the fabric max.
## No-op for non-durable items.
func _add_instances(item_id: String, qty: int, durabilities: Array) -> void:
	if not _item_durability_cache.has(item_id):
		return
	var arr: Array = _durability.get(item_id, [])
	var max_d := float(_item_durability_cache[item_id])
	for i in qty:
		var d := max_d
		if i < durabilities.size():
			d = clampf(float(durabilities[i]), 0.0, max_d)
		arr.append(d)
	_durability[item_id] = arr

## Remove `qty` per-instance durability entries from `item_id`, taking the WORST
## (most-worn, lowest-durability) instances first, and return the removed values
## so a caller can carry them to a recipient. A partial removal keeps the
## better-condition instances. Erases the key when the stack empties. Returns an
## empty array for non-durable/unheld items.
func _remove_instances(item_id: String, qty: int) -> Array:
	if not _durability.has(item_id):
		return []
	var arr: Array = _durability[item_id]
	if qty >= arr.size():
		_durability.erase(item_id)
		return arr
	var sorted := arr.duplicate()
	sorted.sort()   # ascending durability: worst (lowest) first
	var removed: Array = sorted.slice(0, qty)
	_durability[item_id] = sorted.slice(qty)
	return removed

## Whether any held instance of `item_id` still has durability > 0.
func _has_usable_instance(item_id: String) -> bool:
	for v in _durability.get(item_id, []):
		if float(v) > 0.0:
			return true
	return false

## Map a durability value to its condition tier string (pristine → broken).
func _condition_for(cur: float, max_d: float) -> String:
	if cur <= 0.0:
		return DURABILITY_STATES[3]
	if cur >= max_d:
		return DURABILITY_STATES[0]
	if cur >= max_d * 0.5:
		return DURABILITY_STATES[1]
	return DURABILITY_STATES[2]
