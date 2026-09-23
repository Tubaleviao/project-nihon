extends Node
## Player registry — player identity and per-player records (Phase 33).
##
## The registry is the single owner of the `peer_id → player_id` transport map
## and of every player-scoped record. `peer_id` is ENet's, and ENet reassigns it
## on every connection, so nothing durable may be keyed on it:
##
##   • `player_id` is a server-issued id minted on first join. It survives a
##     reconnect and a server restart, and it is the key for the record
##     (position, HP, appearance, technology) and the player's own inventory.
##   • A joining client may present a CACHED id. The host honours it only when it
##     already owns that record and no live peer holds it — i.e. a genuine
##     reconnect. Any other claim is ignored and a fresh id is minted, so a
##     spoofed id can never read or write another player's record
##     (the ratified PlayerIdentityModel decision).
##   • Clients never mint, load, or store anything: `is_authoritative` is false
##     there and every mutating entry point returns early.
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : player_join_intent(peer_id, claimed_id)
##   OUT : player_joined(player_id, reconnected)
##         player_left(player_id)
##
## Public API:
##   set_local_player(player_id, inventory)      — bind the local player's id
##   resolve_identity(peer_id, claimed_id) -> String
##   unbind_peer(peer_id) -> String
##   get_player_id(peer_id) -> String            — "" when unknown
##   get_peer_id(player_id) -> int               — 0 when offline
##   is_online(player_id) -> bool
##   has_player(player_id) / get_player_ids() -> Array
##   get_record(player_id) -> Dictionary
##   record_position(player_id, pos) / record_hp(player_id, hp)
##   record_appearance(player_id, recipe) / record_technology(player_id, statuses)
##   get_inventory(player_id) -> InventorySlice  — created on first access
##   set_inventory(player_id, inventory)
##   get_player_data(player_id) -> Dictionary    — serializable record
##   apply_player_data(player_id, data) -> void
##   get_players_data() -> Dictionary / apply_players_data(data) -> void

const InventorySlice := preload("res://src/inventory/inventory_slice.gd")

## Authoritative (host / dedicated server) or not (client). A client owns no
## records: it caches the id the host assigned and receives its state in the
## host's snapshot.
var is_authoritative: bool = true

## The local player's id on the authoritative machine (the listen host's human
## player / single-player). Persisted in the world record so a restart keeps it.
var local_player_id: String = ""

## peer_id (transport) → player_id (identity). The only thing keyed on the
## connection, and it is thrown away on disconnect.
var _peer_ids: Dictionary = {}

## player_id → record: { player_id, position, hp, appearance, technology }.
var _players: Dictionary = {}

## player_id → InventorySlice. The local player's entry is the game's existing
## inventory instance, so inventory is per-player without changing call sites.
var _inventories: Dictionary = {}

## Ids minted by this process, so two mints in the same second stay distinct.
var _mint_counter: int = 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	GameBus.player_join_intent.connect(_on_player_join_intent)

# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------

## Mint a fresh, unique, connection-independent player id.
func mint_player_id() -> String:
	_mint_counter += 1
	var stamp: int = int(Time.get_unix_time_from_system())
	var entropy: int = _rng.randi() & 0xFFFF
	return "player_%d_%d_%04x" % [stamp, _mint_counter, entropy]

## Bind the local player's identity to an existing inventory instance (the
## game's `_inventory`). Called by game_root on boot / after load.
func set_local_player(player_id: String, inventory: Node = null) -> void:
	local_player_id = player_id
	ensure_player(player_id)
	if inventory != null:
		set_inventory(player_id, inventory)

## Resolve (or mint) the identity behind a connection.
##
## A peer that is already bound keeps its id. A peer presenting `claimed_id` gets
## it back ONLY when the registry owns that record and no live peer holds it —
## the reconnect case. Everything else mints a fresh id, which is what makes a
## spoofed or unknown id harmless: the connecting peer simply becomes a new
## player and never touches the record it tried to claim.
func resolve_identity(peer_id: int, claimed_id: String = "") -> String:
	# Id authority sits on the server: a client never mints, never resolves, and
	# never bundles a record. It waits for the host's player_identity_assigned.
	if not is_authoritative:
		push_warning("PlayerRegistry: resolve_identity on a non-authoritative registry — ignored")
		return ""
	if _peer_ids.has(peer_id):
		return str(_peer_ids[peer_id])
	var player_id := ""
	var reconnected := false
	if claimed_id != "" and has_player(claimed_id) and not is_online(claimed_id):
		player_id = claimed_id
		reconnected = true
	else:
		if claimed_id != "":
			push_warning("PlayerRegistry: peer %d claimed unavailable id '%s' — minting a fresh identity" % [peer_id, claimed_id])
		player_id = mint_player_id()
	_peer_ids[peer_id] = player_id
	ensure_player(player_id)
	GameBus.player_joined.emit(peer_id, player_id, reconnected)
	return player_id

## Drop a connection's transport mapping. The record is RETAINED, so the same
## player_id reconnects to it later. Returns the id the connection held ("" when
## the peer was never bound).
func unbind_peer(peer_id: int) -> String:
	if not _peer_ids.has(peer_id):
		return ""
	var player_id := str(_peer_ids[peer_id])
	_peer_ids.erase(peer_id)
	return player_id

func get_player_id(peer_id: int) -> String:
	return str(_peer_ids.get(peer_id, ""))

## The live peer currently holding `player_id`, or 0 when the player is offline.
func get_peer_id(player_id: String) -> int:
	for pid in _peer_ids:
		if str(_peer_ids[pid]) == player_id:
			return int(pid)
	return 0

func is_online(player_id: String) -> bool:
	return get_peer_id(player_id) != 0

func has_player(player_id: String) -> bool:
	return _players.has(player_id)

func get_player_ids() -> Array:
	var out: Array = _players.keys()
	out.sort()
	return out

# ---------------------------------------------------------------------------
# Records
# ---------------------------------------------------------------------------

## Create an empty record for `player_id` when it has none. Idempotent.
func ensure_player(player_id: String) -> Dictionary:
	if player_id.is_empty():
		return {}
	if not _players.has(player_id):
		_players[player_id] = {
			"player_id":  player_id,
			"position":   [0.0, 0.0, 0.0],
			"hp":         -1.0,
			"appearance": {},
			"technology": {},
		}
	return _players[player_id]

func get_record(player_id: String) -> Dictionary:
	return _players.get(player_id, {})

func record_position(player_id: String, position: Vector3) -> void:
	var rec := ensure_player(player_id)
	if rec.is_empty():
		return
	rec["position"] = [position.x, position.y, position.z]

func record_hp(player_id: String, hp: float) -> void:
	var rec := ensure_player(player_id)
	if rec.is_empty():
		return
	rec["hp"] = hp

func record_appearance(player_id: String, recipe: Dictionary) -> void:
	var rec := ensure_player(player_id)
	if rec.is_empty():
		return
	rec["appearance"] = recipe

func record_technology(player_id: String, statuses: Dictionary) -> void:
	var rec := ensure_player(player_id)
	if rec.is_empty():
		return
	rec["technology"] = statuses

# ---------------------------------------------------------------------------
# Per-player inventory
# ---------------------------------------------------------------------------

## The inventory owned by `player_id`, creating (and parenting) one on first
## access so every player has their own — never the host's shared instance.
func get_inventory(player_id: String) -> Node:
	if player_id.is_empty():
		return null
	if _inventories.has(player_id):
		return _inventories[player_id]
	if not is_authoritative:
		return null
	var inv := InventorySlice.new()
	inv.name = "Inventory_%s" % player_id
	add_child(inv)
	_inventories[player_id] = inv
	return inv

## Bind an existing inventory instance to a player (the local player's).
func set_inventory(player_id: String, inventory: Node) -> void:
	if player_id.is_empty() or inventory == null:
		return
	_inventories[player_id] = inventory

func has_inventory(player_id: String) -> bool:
	return _inventories.has(player_id)

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

## One player's full record: identity + state + inventory contents with
## per-instance durability. The inventory's durable-item array IS its stack
## (Phase 25), so durability round-trips per player with no shared state.
func get_player_data(player_id: String) -> Dictionary:
	var rec := get_record(player_id)
	var data := {
		"player_id": player_id,
		"position":  rec.get("position", [0.0, 0.0, 0.0]),
		"hp":        float(rec.get("hp", -1.0)),
		"appearance": rec.get("appearance", {}),
		"technology": rec.get("technology", {}),
		"inventory": {},
		"inventory_durability": {},
	}
	var inv = _inventories.get(player_id, null)
	if inv != null and is_instance_valid(inv):
		data["inventory"] = inv.get_contents()
		data["inventory_durability"] = inv.get_durability_data()
	return data

## Restore a player's record and inventory from a saved payload. The inventory
## instance for the player is created on demand.
func apply_player_data(player_id: String, data: Dictionary) -> void:
	if player_id.is_empty() or data.is_empty():
		return
	var rec := ensure_player(player_id)
	rec["position"] = data.get("position", [0.0, 0.0, 0.0])
	rec["hp"] = float(data.get("hp", -1.0))
	rec["appearance"] = data.get("appearance", {})
	rec["technology"] = data.get("technology", {})
	var contents: Variant = data.get("inventory", {})
	if contents is Dictionary and not contents.is_empty():
		var inv = get_inventory(player_id)
		if inv != null:
			inv.replace_contents(contents, data.get("inventory_durability", {}))

## Every player record, keyed by player_id (host → disk).
func get_players_data() -> Dictionary:
	var out := {}
	for player_id in _players:
		out[player_id] = get_player_data(player_id)
	return out

## Restore every player record in a saved payload (disk → host).
func apply_players_data(players: Dictionary) -> void:
	for player_id in players:
		var data: Variant = players[player_id]
		if data is Dictionary:
			apply_player_data(str(player_id), data)

# ---------------------------------------------------------------------------
# Bus
# ---------------------------------------------------------------------------

func _on_player_join_intent(peer_id: int, claimed_id: String) -> void:
	if not is_authoritative:
		return
	resolve_identity(peer_id, claimed_id)
