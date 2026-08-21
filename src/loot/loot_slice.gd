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
## Drop tables are read from the fabric at runtime: each creature entity carries
## a structured `drops` json field (fabric/world/creatures/*.js) with the exact
## drop table — item key, drop chance (0–1), and quantity range [minQty, maxQty].
## The fabric is the single source of truth; this slice never hardcodes drops.
## Format per entry: { "item": String, "chance": float, "minQty": int, "maxQty": int }
##
## Despawn timer is read from GameData.LOOTS["LootTable"].despawnSeconds.
## DESPAWN_SECONDS is a fallback only (matches the fabric defaultValue).
const DESPAWN_SECONDS := 120.0  # LootTable.despawnSeconds defaultValue (fallback)

## Physics layer for pickup bodies (layer 3 / bit 2). PlayerSlice aims with a
## ray whose collision mask targets this layer.
const PICKUP_COLLISION_LAYER := 4

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

## Return the pickup record for an id without consuming it (empty dict if unknown).
func get_pickup(pickup_id: String) -> Dictionary:
	if not _pickups.has(pickup_id):
		return {}
	return _pickups[pickup_id]

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
	var table: Array = _drop_table(fabric_key)
	if table.is_empty():
		print("LootSlice: no loot table for '%s' (fabric key: %s)" % [entity_id, fabric_key])
		return
	for entry in table:
		if randf() <= float(entry.get("chance", 0.0)):
			var item_id: String = str(entry.get("item", ""))
			if item_id == "":
				continue
			var qty: int = randi_range(int(entry.get("minQty", 1)), int(entry.get("maxQty", 1)))
			if qty <= 0:
				continue
			var pid := "pickup_%d" % _next_id
			_next_id += 1
			# Build a visible body so the item actually appears on the ground.
			var body := _make_pickup_visual(pid, item_id, position)
			add_child(body)
			_pickups[pid] = {
				"item_id":    item_id,
				"quantity":   qty,
				"position":   position,
				"spawned_at": Time.get_ticks_msec(),
				"body":       body,
			}
			GameBus.loot_dropped.emit(pid, item_id, position, qty)
			print("LootSlice: %s dropped %s ×%d at %s" % [fabric_key, item_id, qty, position])

## Resolve a creature's structured drop table from the fabric (`drops` json field
## on GameData.CREATURES). Returns the Array of { item, chance, minQty, maxQty }
## entries, or [] when the creature is unknown or has no drops field.
func _drop_table(fabric_key: String) -> Array:
	var res: Resource = GameData.CREATURES.get(fabric_key, null)
	if res == null:
		return []
	var drops = res.get("drops")
	if drops is Array:
		return drops
	if drops is String and drops != "":
		var parsed = JSON.parse_string(drops)
		if parsed is Array:
			return parsed
	return []

## Despawn timer in seconds, read from the fabric LootTable entity (falls back to
## DESPAWN_SECONDS when the entity is unavailable).
func _despawn_seconds() -> float:
	var res: Resource = GameData.LOOTS.get("LootTable", null)
	if res != null:
		return float(res.get("despawnSeconds"))
	return DESPAWN_SECONDS

func _tick_despawn() -> void:
	var now := Time.get_ticks_msec()
	var expired: Array = []
	for pid in _pickups:
		var age_ms: float = float(now - _pickups[pid]["spawned_at"])
		if age_ms >= _despawn_seconds() * 1000.0:
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
func _make_pickup_visual(pid: String, item_id: String, pos: Vector3) -> Node3D:
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

	# Collision body so the player's aim ray can detect this pickup.
	var col_body := StaticBody3D.new()
	col_body.collision_layer = PICKUP_COLLISION_LAYER
	col_body.collision_mask = 0
	col_body.set_meta("pickup_id", pid)
	col_body.set_meta("item_id", item_id)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.4, 0.4, 0.4)
	shape.shape = box_shape
	shape.position = Vector3(0.0, 0.2, 0.0)
	col_body.add_child(shape)
	node.add_child(col_body)

	return node

## Deterministic per-item colour so the same item always looks the same.
func _item_color(item_id: String) -> Color:
	var hue := float(absi(hash(item_id)) % 360) / 360.0
	return Color.from_hsv(hue, 0.65, 0.9)
