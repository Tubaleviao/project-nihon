extends "res://src/core/wiring.gd"
## Loot wiring — ground pickups across the wire.
##
## Host: a pickup inside a peer's area of interest is sent to it (`pickup`), and one that is taken, expires or
## leaves the AOI is withdrawn (`pickup_removed`). A peer's `pickup_intent` / `drop_intent` arrive bound to the
## connection's player; the host checks them against its own records (the peer's reported position, the
## pickup's position, that player's bag as the registry holds it) and syncs the bag back to its owner.
## Client: `peer_pickup_synced` / `peer_pickup_removed` keep LootSlice's views. Before this a client saw no
## pickup at all (each lived only on the host), so nothing it was owed on the ground, a full bag's harvest
## overflow included, could be picked up, and it could not drop anything.

const WorldPos := preload("res://src/terrain/world_pos.gd")
const PlayerSlice := preload("res://src/player/player_slice.gd")
const PlayerRegistry := preload("res://src/persistence/player_registry.gd")

## How far past `PlayerSlice.PICKUP_RANGE` a peer may take a pickup, from the host's last record of it.
const PICKUP_REACH_SLACK_M := 2.0
## Seconds between AOI scans (bodies moving in and out of view).
const AOI_SCAN_INTERVAL := 1.0

## peer id -> { pickup id: true } the peer has been sent and not withdrawn.
var _seen: Dictionary = {}
var _aoi_clock: float = 0.0

func _connect_all() -> void:
	connect_bus(GameBus.loot_dropped, _on_dropped)
	connect_bus(GameBus.loot_removed, _on_removed)
	connect_bus(GameBus.loot_expired, _on_removed)
	connect_bus(GameBus.pickup_intent, on_pickup_intent)
	connect_bus(GameBus.drop_intent, on_drop_intent)
	connect_bus(GameBus.peer_pickup_synced, _on_view_synced)
	connect_bus(GameBus.peer_pickup_removed, _on_view_removed)
	connect_bus(GameBus.peer_disconnected, _on_peer_disconnected)

func _is_host() -> bool:
	return not root._is_client and root._networking != null and root._networking.is_host()

# ---------------------------------------------------------------------------
# Host: what each peer sees
# ---------------------------------------------------------------------------

static func packet_of(view: Dictionary) -> Dictionary:
	var p: Vector3 = view["position"]
	return { "type": "pickup", "id": view["id"], "item": view["item_id"], "qty": view["quantity"], "pos": [p.x, p.y, p.z] }

func _on_dropped(pickup_id: String, _item_id: String, position: Vector3, _quantity: int) -> void:
	if not _is_host():
		return
	var view: Dictionary = root._loot.view_of(pickup_id)
	if view.is_empty():
		return
	for peer in root._networking.connected_peers():
		var peer_id := int(peer)
		if root._networking.has_last_known_state(peer_id) and root._networking.in_aoi(peer_id, position):
			if root._networking._deliver(peer_id, packet_of(view)):
				(_seen.get_or_add(peer_id, {}) as Dictionary)[pickup_id] = true

func _on_removed(pickup_id: String) -> void:
	if not _is_host():
		return
	for peer in _seen:
		if (_seen[peer] as Dictionary).has(pickup_id):
			(_seen[peer] as Dictionary).erase(pickup_id)
			root._networking._deliver(int(peer), { "type": "pickup_removed", "id": pickup_id })

func _on_peer_disconnected(peer_id: int) -> void:
	_seen.erase(peer_id)

func tick(delta: float) -> void:
	if not _is_host() or root._loot == null:
		return
	_aoi_clock += delta
	if _aoi_clock < AOI_SCAN_INTERVAL:
		return
	_aoi_clock = 0.0
	scan_aoi()

## Send each peer the pickups that came inside its AOI and withdraw those that left it.
func scan_aoi() -> void:
	var peers: Array = root._networking.connected_peers()
	for stale in _seen.keys():
		if not peers.has(stale):
			_seen.erase(stale)
	for peer in peers:
		var peer_id := int(peer)
		if not root._networking.has_last_known_state(peer_id):
			continue
		var seen: Dictionary = _seen.get(peer_id, {})
		var now := {}
		for id in root._loot.ids():
			var view: Dictionary = root._loot.view_of(str(id))
			if not root._networking.in_aoi(peer_id, view["position"]):
				continue
			if seen.has(id) or root._networking._deliver(peer_id, packet_of(view)):
				now[id] = true
		for id in seen:
			if not now.has(id):
				root._networking._deliver(peer_id, { "type": "pickup_removed", "id": id })
		_seen[peer_id] = now

# ---------------------------------------------------------------------------
# Host: a peer takes or drops
# ---------------------------------------------------------------------------

## The connected, living peer behind `player_id`, or 0.
func _live_peer(player_id: String) -> int:
	if not _is_host() or player_id == "" or player_id == "player" or player_id == root._registry.local_player_id:
		return 0
	var peer: int = root._registry.get_peer_id(player_id)
	if peer == 0 or not root._networking.has_last_known_state(peer):
		return 0
	if PlayerRegistry.is_downed(root._registry.get_hp(player_id)):
		return 0
	return peer

## Host: a peer takes the pickup `pickup_id` into its bag. True when it was taken.
## On a client the same signal is the outbound one: it is sent to the host (the target id only).
func on_pickup_intent(pickup_id: String, player_id: String) -> bool:
	if root._is_client:
		if player_id == "" and root._networking != null:
			root._networking._broadcast({ "type": "pickup_intent", "id": pickup_id })
		return false
	var peer := _live_peer(player_id)
	if peer == 0 or root._loot == null:
		return false
	var p: Dictionary = root._loot.get_pickup(pickup_id)
	if p.is_empty():
		return false
	var at: Vector3 = p["position"]
	var gap: float = WorldPos.offset_between(root._peer_wiring.peer_exact_pos(peer), WorldPos.from_world(at.x, at.y, at.z)).length()
	if gap > PlayerSlice.PICKUP_RANGE + PICKUP_REACH_SLACK_M:
		return false
	var inv: Node = root._registry.get_inventory(player_id)
	var item := str(p["item_id"])
	var qty := int(p["quantity"])
	if inv == null or not inv.can_add_items({ item: qty }):
		return false
	root._loot.consume_pickup(pickup_id)
	if not inv.add_item(item, qty, p.get("durabilities", [])):
		root._loot.spawn_pickup(item, qty, at, p.get("durabilities", []))   # cannot happen after can_add_items; never lose goods
		return false
	root._peer_wiring.sync_peer_own_state({ "success": true, "player_id": player_id })
	return true

## Host: a peer drops up to `quantity` of `item_id` at its own reported feet. True when something was dropped.
func on_drop_intent(item_id: String, quantity: int, player_id: String) -> bool:
	if root._is_client:
		if player_id == "" and root._networking != null:
			root._networking._broadcast({ "type": "drop_intent", "id": item_id, "qty": quantity })
		return false
	var peer := _live_peer(player_id)
	if peer == 0 or root._loot == null or quantity <= 0:
		return false
	var inv: Node = root._registry.get_inventory(player_id)
	if inv == null:
		return false
	var take := mini(quantity, int(inv.get_item_count(item_id)))
	if take <= 0:
		return false
	var res: Dictionary = inv.drop_item_returning(item_id, take)
	if not bool(res.get("success", false)):
		return false
	root._loot.spawn_pickup(item_id, take, root._networking.get_last_known_state(peer), res.get("removed", []))
	root._peer_wiring.sync_peer_own_state({ "success": true, "player_id": player_id })
	return true

# ---------------------------------------------------------------------------
# Client
# ---------------------------------------------------------------------------

func _on_view_synced(record: Dictionary) -> void:
	if root._is_client and root._loot != null:
		root._loot.apply_view(record)

func _on_view_removed(pickup_id: String) -> void:
	if root._is_client and root._loot != null:
		root._loot.remove_view(pickup_id)
