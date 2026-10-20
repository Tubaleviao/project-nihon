extends Node
## Loot slice — world-space pickups for items dropped on the ground (a creature's body is the CarcassSlice's, Phase 161).
##
## Plug contract (GameBus signals consumed / emitted):
##   OUT : loot_dropped(pickup_id, item_id, position, quantity)
##         loot_expired(pickup_id)
##
## Public API:
##   get_pickups_near(pos: Vector3, radius: float) -> Array[Dictionary]
##   consume_pickup(pickup_id: String)              -> Dictionary  (empty on miss)
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

## Despawn threshold in milliseconds, cached at startup from the fabric.
var _despawn_ms: float = DESPAWN_SECONDS * 1000.0

## Set by game_root so instance IDs can be resolved to fabric creature keys.
var creature_slice: Node = null

func _ready() -> void:
	var res: Resource = GameData.LOOTS.get("LootTable", null)
	if res != null:
		_despawn_ms = float(res.get("despawnSeconds")) * 1000.0

func _process(_delta: float) -> void:
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

## Put `quantity` of `item_id` on the ground at `position` and return its pickup id.
## `durabilities` (one per unit, worst first) is what the pickup hands back to whoever collects it,
## so a worn tool keeps its wear; empty means fresh.
func spawn_pickup(item_id: String, quantity: int, position: Vector3, durabilities: Array = []) -> String:
	var pid := "pickup_%d" % _next_id
	_next_id += 1
	# Build a visible body so the item actually appears on the ground.
	var body := _make_pickup_visual(pid, item_id, position)
	add_child(body)
	_world_nodes.append(body)
	body.tree_exited.connect(_forget_world_node.bind(body))
	_pickups[pid] = {
		"item_id":      item_id,
		"quantity":     quantity,
		"position":     position,
		"spawned_at":   Time.get_ticks_msec(),
		"body":         body,
		"durabilities": durabilities,
	}
	GameBus.loot_dropped.emit(pid, item_id, position, quantity)
	return pid

func _tick_despawn() -> void:
	var now := Time.get_ticks_msec()
	var expired: Array = []
	for pid in _pickups:
		var age_ms: float = float(now - _pickups[pid]["spawned_at"])
		if age_ms >= _despawn_ms:
			expired.append(pid)
	for pid in expired:
		var p: Dictionary = _pickups[pid]
		if p.has("body") and p["body"] != null:
			p["body"].queue_free()
		_pickups.erase(pid)
		GameBus.loot_expired.emit(pid)

# ---------------------------------------------------------------------------
# Visuals
# ---------------------------------------------------------------------------

## Phase 63: the scene-origin offset a client rebase has applied (see `shift_scene`).
const SceneOffset := preload("res://src/core/scene_offset.gd")
var _origin: SceneOffset = SceneOffset.new()

## Phase 80 — the pickup nodes this slice spawned in world space. `shift_scene` moves exactly
## these, so a helper node parented under the slice is never shifted by accident.
var _world_nodes: Array = []

## Shift every pickup node by `shift`; its world position is unchanged. Freed nodes drop out.
func shift_scene(shift: Vector3) -> void:
	_origin.value += shift
	var live: Array = []
	for n in _world_nodes:
		if is_instance_valid(n):
			(n as Node3D).position += shift
			live.append(n)
	_world_nodes = live

## Drop a freed world node from the shift set.
func _forget_world_node(node: Node) -> void:
	_world_nodes.erase(node)

func scene_offset() -> Vector3:
	return _origin.value

## Build a small coloured box so a dropped item is visible in the world.
func _make_pickup_visual(pid: String, item_id: String, pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = "Pickup_%s" % item_id
	node.position = pos + _origin.value

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
