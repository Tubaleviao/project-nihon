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
##     (the ratified PlayerIdentityModel decision). A record is loaded from disk
##     LAZILY, on the claim that asks for it (`set_record_loader`), not all at boot,
##     and it is released again when the connection drops (`evict_player`) — the
##     disk copy is the durable half, so the registry holds records only for the
##     players who are actually online right now.
##   • A remote peer's HP is NOT durable here: it arrives client-declared, so
##     only the local player's HP may be written into a record (see `record_hp`).
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
##   set_record_loader(loader: Callable)         — inject the durable reader
##   resolve_identity(peer_id, claimed_id) -> String
##   unbind_peer(peer_id) -> String
##   get_player_id(peer_id) -> String            — "" when unknown
##   resolve_named_party(name) -> String         — Phase 36: a named counterparty
##   get_peer_id(player_id) -> int               — 0 when offline
##   is_online(player_id) -> bool
##   has_player(player_id) / get_player_ids() -> Array
##   get_online_player_ids() -> Array            — the ids a save should write
##   get_record(player_id) -> Dictionary
##   record_position(player_id, pos) / record_hp(player_id, hp)
##   record_appearance(player_id, recipe) / record_technology(player_id, statuses)
##   record_flags(player_id, flags) / record_companions(player_id, ids)  — Phase 35
##   get_skill_tier(player_id, skill) / record_skill(player_id, skill, tier)  — Phase 36
##   record_skills(player_id, tiers)
##   get_inventory(player_id) -> InventorySlice  — created on first access
##   set_inventory(player_id, inventory)
##   evict_player(player_id) -> bool             — drop an offline player's memory
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

## player_id → record: { player_id, position, hp, appearance, technology, flags,
## companions, skills }.
var _players: Dictionary = {}

## player_id → InventorySlice. The local player's entry is the game's existing
## inventory instance, so inventory is per-player without changing call sites.
var _inventories: Dictionary = {}

## Ids minted by this process, so two mints in the same second stay distinct.
var _mint_counter: int = 0
## CSPRNG source for the id's entropy. `RandomNumberGenerator` is NOT suitable: it
## is a fast PRNG, and the id is a bearer token.
var _crypto := Crypto.new()

## Bytes of CSPRNG entropy in a minted id (128 bits).
const ID_ENTROPY_BYTES := 16

## Phase 36 — the public-handle format (see public_handle).
const HANDLE_PREFIX := "p_"
## Hex characters of the sha256 digest kept in a handle (64 bits).
const HANDLE_HEX_CHARS := 16

## Loads a player record from durable storage (injected by game_root — the registry
## owns identity, not the save layout). Used to bring a record into memory the
## first time a peer claims it (see _ensure_record_loaded).
var _record_loader: Callable = Callable()

func _ready() -> void:
	GameBus.player_join_intent.connect(_on_player_join_intent)

# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------

## Mint a fresh, unique, connection-independent player id.
##
## The trailing component is 128 bits of CRYPTOGRAPHIC randomness, not the 16-bit
## `randi() & 0xFFFF` it used to be. The id is presented on a reconnect and is the
## only thing standing between a peer and a record (`resolve_identity` hands the
## record to whoever claims the id), so it is a bearer token: 16 bits is 65 536
## guesses, brute-forceable in one connect flood, and it would hand an attacker
## another player's inventory and position. The epoch + counter prefix is kept for
## human readability and same-second ordering only — the entropy is what secures it.
func mint_player_id() -> String:
	_mint_counter += 1
	var stamp: int = int(Time.get_unix_time_from_system())
	var entropy: String = _crypto.generate_random_bytes(ID_ENTROPY_BYTES).hex_encode()
	return "player_%d_%d_%s" % [stamp, _mint_counter, entropy]

## Inject the durable-storage reader used for a lazy record load. `loader` takes a
## player id and returns the record dictionary (or {} when there is none).
func set_record_loader(loader: Callable) -> void:
	_record_loader = loader

## Phase 36 — a player's PUBLIC HANDLE: the pseudonym every host → client payload
## names a player by (a listing's seller, a trade's parties, a proposal's author and
## voters). The PLAYER ID must never be broadcast: it is a bearer token — presenting
## it on join claims the record (`resolve_identity`) — so a client that learned
## another player's id could take that player's record (inventory, position,
## appearance, technology) simply by waiting for them to disconnect, and the social
## broadcasts were handing out every id in the world.
##
## DERIVED, not minted: `sha256(player_id)` truncated. That makes it storage-free and
## stable — it needs no record, so it answers for an OFFLINE seller named in a
## persisted listing whose record was long since evicted, and it survives a restart
## with the id it derives from. It is one-way: recovering the id from the handle is a
## preimage search over the id's 128 bits of CSPRNG entropy. A handle is also not a
## claim: `resolve_identity` only honours an id the registry actually owns, and no
## record is EVER keyed by a handle.
func public_handle(player_id: String) -> String:
	if player_id.is_empty():
		return ""
	return HANDLE_PREFIX + player_id.sha256_text().substr(0, HANDLE_HEX_CHARS)

## The player id behind a public handle, among the players this process can see: the
## online ones and the local player (both of which are exactly the players a session
## can be opened with). "" when no such player is here — a handle names someone, but
## only a player who is present can be acted with.
func player_id_for_handle(handle: String) -> String:
	if handle.is_empty() or not handle.begins_with(HANDLE_PREFIX):
		return ""
	if public_handle(local_player_id) == handle:
		return local_player_id
	for player_id in _players:
		var pid := str(player_id)
		if is_online(pid) and public_handle(pid) == handle:
			return pid
	return ""

## True when `candidate` is a `mint_player_id()` value — the shape test, not a
## registry lookup: an offline seller's id appears in a persisted listing (and in a
## client's synced copy) long after their record was evicted, and that id is a bearer
## token whether or not this process still holds the record for it. Used to find the
## ids inside a payload that has to be redacted (see NetworkingSlice.redact_for_client).
static func looks_like_player_id(candidate: String) -> bool:
	if not candidate.begins_with("player_"):
		return false
	var parts: PackedStringArray = candidate.split("_")
	if parts.size() != 4:
		return false
	if not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return false
	return parts[3].length() == ID_ENTROPY_BYTES * 2 and parts[3].is_valid_hex_number(false)

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
## it back ONLY when the registry owns that record and no live peer holds it — the
## reconnect case. Everything else mints a fresh id, which is what makes a spoofed
## or unknown id harmless: the connecting peer simply becomes a new player and
## never touches the record it tried to claim.
##
## The LOCAL player's id is refused outright, in addition to the `is_online` guard:
## a listen host's own player is not bound to a peer id, so the peer-map lookup
## alone would not protect it, and every connecting client would be able to claim
## the host's inventory and position (see `is_online`).
func resolve_identity(peer_id: int, claimed_id: String = "") -> String:
	# Id authority sits on the server: a client never mints, never resolves, and
	# never bundles a record. It waits for the host's player_identity_assigned.
	if not is_authoritative:
		push_warning("PlayerRegistry: resolve_identity on a non-authoritative registry — ignored")
		return ""
	if _peer_ids.has(peer_id):
		# An ALREADY-bound peer asking again is a retry, not a new join: the
		# handshake is re-answered rather than silently swallowed. The client
		# re-presents its join intent when no snapshot has arrived (a lost
		# join_intent, or a lost snapshot), and without this re-emit the retry
		# produced no `player_joined`, so the host never re-sent the snapshot
		# and the client stayed empty forever. Idempotent on both sides:
		# `ensure_player` is a no-op and the handshake snapshot is re-sent.
		GameBus.player_joined.emit(peer_id, str(_peer_ids[peer_id]), false)
		return str(_peer_ids[peer_id])
	var player_id := ""
	var reconnected := false
	var claimable := claimed_id != "" and claimed_id != local_player_id
	if claimable:
		# Records are loaded LAZILY, not all at boot (see _ensure_record_loaded):
		# the claim is where a returning player's record is brought into memory.
		_ensure_record_loaded(claimed_id)
	if claimable and has_player(claimed_id) and not is_online(claimed_id):
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

## Bring `player_id`'s record into memory if it is not already resident, using the
## injected loader. The authoritative boot does NOT read every record on disk — a
## record belonging to a player who never reconnects should not be resident — so a
## record is loaded the first time something actually asks for it: the reconnect
## claim. A no-op when the record is resident, when no loader is wired (isolated
## tests), or when there is no record on disk (a first join mints instead).
func _ensure_record_loaded(player_id: String) -> void:
	if player_id.is_empty() or _players.has(player_id):
		return
	if not _record_loader.is_valid():
		return
	var data: Variant = _record_loader.call(player_id)
	if data is Dictionary and not (data as Dictionary).is_empty():
		apply_player_data(player_id, data)

## Drop a connection's transport mapping. The record on disk is the player's
## durable identity, so the same player_id reconnects to it later; the IN-MEMORY
## copy is a different question and is released by `evict_player` once it is
## safe (which is why a reconnect re-loads rather than re-binds). Returns the id
## the connection held ("" when the peer was never bound).
func unbind_peer(peer_id: int) -> String:
	if not _peer_ids.has(peer_id):
		return ""
	var player_id := str(_peer_ids[peer_id])
	_peer_ids.erase(peer_id)
	return player_id

func get_player_id(peer_id: int) -> String:
	return str(_peer_ids.get(peer_id, ""))

## Phase 36 — resolve a counterparty NAME from a client payload to the player id it
## denotes, or "" when nothing this host can open a session with.
##
## A trade invite is the only client payload that names another player on purpose
## (every acting half is bound to its own connection instead), so this is the one
## place a name from the wire has to be resolved — and it is resolved against the
## ONLINE set: a session with an offline id could never be answered, so the invite
## is dropped rather than parked in the trade table. `is_online` covers the listen
## host's own player, who is an ordinary trade partner.
func resolve_named_party(name: String) -> String:
	if name.is_empty():
		return ""
	if is_online(name):
		return name
	# Phase 36 — a client names the counterparty it saw in a broadcast, which is a
	# public HANDLE now that player ids never travel. Resolve it to whoever is online
	# by that handle (an offline player could not answer an invite anyway).
	var pid := player_id_for_handle(name)
	if pid != "" and is_online(pid):
		return pid
	return ""

## The live peer currently holding `player_id`, or 0 when the player is offline.
func get_peer_id(player_id: String) -> int:
	for pid in _peer_ids:
		if str(_peer_ids[pid]) == player_id:
			return int(pid)
	return 0

## True when a live connection holds `player_id` — or when it is THIS machine's own
## local player, which is online by definition (it is the human at this keyboard).
##
## The local player has no peer mapping: a listen host never connects to itself, so
## `set_local_player()` records no `_peer_ids` entry and a bare peer-map lookup
## answered false. Every client could then claim the host's id and be handed the
## host's inventory and position, since the claim rule is "the record exists and is
## not online". This is the guard that closes that; `resolve_identity` also refuses
## the local id explicitly, so neither alone is load-bearing.
func is_online(player_id: String) -> bool:
	if player_id.is_empty():
		return false
	if player_id == local_player_id:
		return true
	return get_peer_id(player_id) != 0

func has_player(player_id: String) -> bool:
	return _players.has(player_id)

func get_player_ids() -> Array:
	var out: Array = _players.keys()
	out.sort()
	return out

## The ids whose RECORD a save should write: the players whose state can still
## change, i.e. the online ones — which includes the local player (see is_online).
## An offline player's record is already durable and cannot have changed since it
## was written (nothing can move it without a connection), so rewriting every
## long-gone player on every autosave only made the save cost grow with the number
## of players who had ever joined. Sorted, so the write order is deterministic.
func get_online_player_ids() -> Array:
	var out: Array = []
	for player_id in _players:
		if is_online(str(player_id)):
			out.append(str(player_id))
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
			"flags":      {},
			"companions": [],
			"skills":     {},
		}
	return _players[player_id]

func get_record(player_id: String) -> Dictionary:
	return _players.get(player_id, {})

func record_position(player_id: String, position: Vector3) -> void:
	var rec := ensure_player(player_id)
	if rec.is_empty():
		return
	rec["position"] = [position.x, position.y, position.z]

## Record a player's HP — but ONLY for the local (host-simulated) player.
##
## A REMOTE peer's HP is client-declared: the value arrives on the wire in the
## peer's own `player_moved` packet (see networking `_route_c2h`), and the host
## has no simulation of that peer's health to check it against. Writing it into
## the record made persistence into a durable cheat — a client that declared
## 9999 HP kept 9999 HP across a reconnect, a restart, and every future save,
## because the save lifecycle faithfully re-serialized whatever it was given.
## The honest position is that this process cannot vouch for that number, so it
## is not durable; the peer's HP is owned by the simulation on the machine that
## runs it (its own client) and is revocable there.
##
## The local player's HP IS host-simulated and durable (see `is_online` for the
## same local-vs-remote split). Pure predicate, so the rule is testable alone.
static func hp_is_authoritative_locally(player_id: String, local_player_id: String) -> bool:
	return player_id != "" and player_id == local_player_id

func record_hp(player_id: String, hp: float) -> void:
	if not hp_is_authoritative_locally(player_id, local_player_id):
		return
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

## Phase 36 — one player's skill tier (e.g. Smithing → journeyman): the gate every
## crafting recipe and repair step is resolved against. Per-player, because a
## shared table let the first player to reach a tier unlock that tier's recipes for
## everybody on the server.
##
## Returns "" when the record holds no tier for that skill — the caller decides what
## a missing tier means (CraftingSlice reads it as the seed tier, novice), so the
## default lives in one place instead of two.
func get_skill_tier(player_id: String, skill: String) -> String:
	if skill == "":
		return ""
	var skills = get_record(player_id).get("skills", {})
	if skills is Dictionary:
		return str((skills as Dictionary).get(skill, ""))
	return ""

## Record one skill tier on a player's record (durable progression).
func record_skill(player_id: String, skill: String, tier: String) -> void:
	if skill == "" or tier == "":
		return
	var rec := ensure_player(player_id)
	if rec.is_empty():
		return
	var skills: Dictionary = rec.get("skills", {})
	if not (skills is Dictionary):
		skills = {}
	skills[skill] = tier
	rec["skills"] = skills

## Replace a player's whole tier table (restore path / bulk write).
func record_skills(player_id: String, tiers: Dictionary) -> void:
	var rec := ensure_player(player_id)
	if rec.is_empty():
		return
	rec["skills"] = tiers.duplicate()

## The player's taming flags (Phase 35) — e.g. `wolfBondHolder`, which the Ranger
## profession gate reads. Durable, because a flag is progression, not scenery.
func record_flags(player_id: String, flags: Dictionary) -> void:
	var rec := ensure_player(player_id)
	if rec.is_empty():
		return
	rec["flags"] = flags

## The instance ids this player has tamed (Phase 35). Instance ids are derived
## from the chunk, creature and spawn index, so they are stable across restarts
## and a restored binding resolves to the same creature.
func record_companions(player_id: String, companion_ids: Array) -> void:
	var rec := ensure_player(player_id)
	if rec.is_empty():
		return
	var out: Array = []
	for iid in companion_ids:
		out.append(str(iid))
	out.sort()
	rec["companions"] = out

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
# Eviction
# ---------------------------------------------------------------------------

## Release everything this process holds in memory for a player who is no longer
## connected: the record and the registry-owned inventory node.
##
## Without this the registry only ever grew. The record is KEPT on disk and the
## registry holds a loader (`set_record_loader`), so the next claim that presents
## the id pulls it straight back in (`_ensure_record_loaded`) — eviction costs one
## disk read on a reconnect and nothing at all for a player who never returns,
## which is exactly the set the old behaviour leaked. `game_root` writes the
## record before calling this (see `_on_peer_disconnected`), so nothing is lost.
##
## Refused for an ONLINE player and for the local player: the local player is
## online by definition, and its record and inventory are this process's own.
## The inventory NODE is only freed when the registry created it (parent ==
## self); the local player's is the game's own `_inventory` instance, handed in
## by `set_local_player`, and is not this slice's to free.
##
## Returns true when a record was resident and has been dropped.
func evict_player(player_id: String) -> bool:
	if player_id.is_empty() or is_online(player_id):
		return false
	var had_record := _players.erase(player_id)
	var inv: Variant = _inventories.get(player_id, null)
	if inv != null:
		_inventories.erase(player_id)
		var node := inv as Node
		if is_instance_valid(node) and node.get_parent() == self:
			remove_child(node)
			node.queue_free()
	return had_record

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
		"flags":      rec.get("flags", {}),
		"companions": rec.get("companions", []),
		"skills":     rec.get("skills", {}),
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
	# Phase 35: taming flags and companion bindings are per-player progression, so
	# they ride the same record. A saved payload from before this phase simply
	# carries neither key and restores to the empty defaults.
	rec["flags"]      = data.get("flags", {})
	rec["companions"] = data.get("companions", [])
	# Phase 36: skill tiers are per-player progression too, so they ride the same
	# record. A payload from before this phase carries no `skills` key and restores
	# to the empty table — every skill then reads as its seed tier (novice).
	rec["skills"]     = data.get("skills", {})
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
