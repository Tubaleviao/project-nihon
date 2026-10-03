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
##   • Health is written from EVIDENCE, never from a claim. The local player's HP
##     comes off the live body (`record_hp`); a remote peer's HP is written only
##     when the HOST itself resolved it (`record_simulated_hp`). A value that
##     arrived client-declared is refused by both — see the two docstrings.
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
##   resolve_named_party(name) -> String         — a named counterparty (HANDLES only, Phase 37)
##   get_peer_id(player_id) -> int               — 0 when offline
##   is_online(player_id) -> bool
##   has_player(player_id) / get_player_ids() -> Array
##   get_online_player_ids() -> Array            — the ids a save should write
##   get_record(player_id) -> Dictionary
##   record_position(player_id, pos) / record_hp(player_id, hp)
##   get_hp(player_id) -> float                 — -1.0 when this machine holds none;
##                                                resolves the respawn deadline (Phase 39)
##   record_simulated_hp(player_id, hp)         — the HOST's own hit resolution (Phase 38)
##   simulated_hp_after_hit(hp, damage, max) -> float  — pure rule (static, Phase 38)
##   hp_after_respawn(hp, deadline, now, max) -> float — pure rule (static, Phase 39)
##   record_appearance(player_id, recipe) / record_technology(player_id, statuses)
##   record_flags(player_id, flags) / record_companions(player_id, ids)  — Phase 35
##   record_cooldowns(player_id, cooldowns) / get_cooldowns(player_id)   — Phase 37
##   live_cooldowns(cooldowns, now := -1.0) -> Dictionary  — pure prune (static)
##   get_skill_tier(player_id, skill) / record_skill(player_id, skill, tier)  — Phase 36
##   record_skills(player_id, tiers)
##   get_inventory(player_id) -> InventorySlice  — created on first access
##   set_inventory(player_id, inventory)
##   evict_player(player_id) -> bool             — drop an offline player's memory
##   get_player_data(player_id) -> Dictionary    — serializable record
##   apply_player_data(player_id, data) -> void
##   get_players_data() -> Dictionary / apply_players_data(data) -> void

const InventorySlice := preload("res://src/inventory/inventory_slice.gd")

const EquipmentRules := preload("res://src/character/equipment_rules.gd")

## Phase 39 — the shared rules of a player BODY, from a neutral module rather than from the
## local body's slice (`src/core/player_rules.gd`). Two of them matter here: the ceiling a
## simulated body is clamped to (`MAX_HP`) and the delay a downed body waits before it comes
## back (`RESPAWN_DELAY`). They must not be DUPLICATED — the host's floor for a PEER
## drifting from the ceiling the peer's own client respawns to is exactly the
## two-places-one-rule drift this phase is about — and they must not be read off
## `PlayerSlice` either: persistence preloading presentation is the wrong direction, for two
## numbers neither layer owns, and two review passes have now flagged it.
## **Review pass — this was `preload("res://src/player/player_slice.gd")` for exactly those
## two constants. The values are unchanged; only their home is, and `PlayerSlice` re-exports
## both names so no reader moved.**
const PlayerRules := preload("res://src/core/player_rules.gd")

## Phase 39 — how long a host-simulated peer stays down before its health reads back
## full. The Phase 37 cooldown shape, applied to the one deadline a body carries.
const RESPAWN_DELAY := PlayerRules.RESPAWN_DELAY

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
	GameBus.equipment_intent.connect(_on_equipment_intent)

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
##
## Phase 37 — HANDLES ONLY. This used to answer an online player's RAW ID as well,
## which made it an online-status oracle: `resolve_named_party("player_<…>")` told a
## client whether that exact id was connected, and an id is a BEARER TOKEN (presenting
## it on join claims the record — see resolve_identity). A client learns ids nowhere
## legitimate any more (see NetworkingSlice.redact_for_client), so the only use left
## for accepting one was probing. A public handle is the name a payload may carry:
## derived, opaque, and a claim to nothing.
func resolve_named_party(name: String) -> String:
	if name.is_empty():
		return ""
	# player_id_for_handle is the whole rule: it answers "" unless the name is one of
	# OUR handles (the local player's included) for a player who is present here.
	return player_id_for_handle(name)

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
			"cooldowns":  {},
			# Phase 47 — the worn set, { slot: item_key }.
			"equipment":  {},
			# Phase 39 — 0.0 = "no respawn pending", the same shape the -1.0 hp
			# sentinel has: an absent deadline and a downed body are different facts.
			"respawn_deadline": 0.0,
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
##
## Phase 38 — a remote peer's HP is durable too, but through a DIFFERENT door:
## what the host RESOLVES itself is evidence and is written by
## `record_simulated_hp`. This method stays the live-body writer and still refuses
## a remote id, so the wire's declared value has no path into a record at all.
static func hp_is_authoritative_locally(player_id: String, local_player_id: String) -> bool:
	return player_id != "" and player_id == local_player_id

func record_hp(player_id: String, hp: float) -> void:
	if not hp_is_authoritative_locally(player_id, local_player_id):
		return
	var rec := ensure_player(player_id)
	if rec.is_empty():
		return
	rec["hp"] = hp

## The HP this machine holds for `player_id`, or -1.0 when it holds none.
##
## -1.0 is the "no number here" sentinel the record itself starts with
## (`ensure_player`), so a caller can tell a body it has never modelled from one at
## zero health. A simulation must seed such a body from full health rather than from
## a declared value — see `simulated_hp_after_hit`.
##
## Phase 39 — this is ONE of the two readers of the durable `hp` field, and it
## RESOLVES the respawn deadline rather than returning the stored value raw (the
## resolution itself lives in `hp_after_respawn`). Still a pure read: it writes
## nothing, which is why the deadline and not a rewritten `hp` is the durable fact —
## a write-on-read through `record_simulated_hp` would no-op on exactly the paths
## where that method refuses (a non-authoritative machine, the local id, a player with
## no resident record) while this read had already claimed full health.
func get_hp(player_id: String) -> float:
	return _resolved_hp(get_record(player_id))

## The smallest positive health that still counts as DOWN.
##
## Float arithmetic does not produce exact zeroes: a hit that lands a fraction short of the
## number it cancels leaves the body at ~1e-7 — alive by the letter of a `> 0.0` test, dead
## by every other measure, and (before this) with its respawn deadline CLEARED, so it stayed
## at an invisible sliver for the rest of the session and across every restart. The
## threshold is deliberately far below anything the game deals or heals (damage is
## fractional but never sub-milli), so it can only ever catch an arithmetic remainder, never
## a real hit point. **Review pass — the step was `hp != 0.0` in one place and `hp > 0.0`
## in another, which are two different numbers to be wrong by.**
const HP_EPSILON := 1.0e-4

## Whether `hp` is the number that means DOWN. ONE predicate, because two callers have to
## agree on it: `hp_after_respawn` decides whether a deadline applies, and
## `record_simulated_hp` decides whether to park one or clear it. While they disagreed by an
## epsilon the result was a body that could never come back — the writer cleared the deadline
## an epsilon-off value would have parked, and the reader then handed that sliver out as
## health forever.
##
## The `-1.0` "no number here" sentinel is NOT down (`hp >= 0.0`): this host never modelled
## that body, and a stale deadline beside the sentinel must not be able to invent health for
## it (see `hp_after_respawn`).
static func is_downed(hp: float) -> bool:
	return hp >= 0.0 and hp <= HP_EPSILON

## Phase 39 — pure: the HP a body has, given the deadline its respawn was parked on.
##
## The mirror image of `simulated_hp_after_hit`: that rule is the only thing that can
## take a body DOWN, and this is the only thing that can bring it back. Before it
## existed a host-simulated peer's HP was a subtract-only counter — `clampf(…, 0.0,
## max_hp)` cannot heal — so a peer a creature downed froze at zero for the rest of the
## session and across every restart, and the client handed that zero ended up `_alive ==
## false` with no countdown ever started (`PlayerSlice.set_hp` had no respawn half).
##
## Three cases, in this order:
##   • a body that is not DOWN (see `is_downed`) — real health, or the -1.0 "no number
##     here" sentinel — is returned unchanged. A deadline must not be able to invent health
##     for a body this process never modelled (a stale deadline beside the sentinel would
##     otherwise read as a full bar for a peer nothing here has ever hurt), nor for one that
##     is standing at 37;
##   • a downed body with no deadline (`deadline <= 0`) reads as the canonical ZERO, not as
##     the raw stored number: nothing is parked to bring it back, so it stays down. The zero
##     is returned rather than `hp` so a remainder left by float arithmetic cannot leak out
##     as health — one reading for "down", whichever way the number got there;
##   • a deadline still in the future reads as ZERO (the body is down, and waits), and one
##     that has passed reads as `max_hp` (the body is up again). The deadline's own instant
##     counts as passed.
##
## `now` is an argument (not a clock read) for the same reason `live_cooldowns` takes
## one: the rule is then testable without waiting five seconds. Static and pure, so it
## is asserted alone, beside `simulated_hp_after_hit`.
static func hp_after_respawn(hp: float, deadline: float, now: float = -1.0, max_hp: float = PlayerRules.MAX_HP) -> float:
	if not is_downed(hp):
		return hp
	if deadline <= 0.0:
		return 0.0
	var at: float = Time.get_unix_time_from_system() if now < 0.0 else now
	return max_hp if at >= deadline else 0.0

## The resolved HP of a record — the ONE place the deadline is applied to a stored
## value, so the live reader (`get_hp`) and the saved copy (`get_player_data`) cannot
## answer differently. Phase 38's lesson was a rule that ran on one reader being a
## reader-dependent rule; this keeps the resolution in one expression rather than two.
func _resolved_hp(rec: Dictionary) -> float:
	return hp_after_respawn(
		float(rec.get("hp", -1.0)),
		float(rec.get("respawn_deadline", 0.0)),
		-1.0,
		PlayerRules.MAX_HP
	)

## Phase 38 — pure: a peer's host-simulated HP after a resolved hit.
##
## An UNMODELLED body (the -1.0 sentinel) starts at FULL health. That is the only
## honest seed: the host holds no record of that peer's health, and it will not take
## the peer's own word for it — the value a peer declares on `player_moved` is what
## made a durable record a restart-proof cheat in the first place. A body the host has
## never resolved a hit against is therefore treated as fresh, and from that first hit
## onward the number is the host's own. Clamped to [0, max_hp]: a hit cannot heal, and
## a body this process simulates cannot exceed the same ceiling a local body has.
static func simulated_hp_after_hit(current_hp: float, damage: float, max_hp: float) -> float:
	var base := current_hp if current_hp >= 0.0 else max_hp
	return clampf(base - damage, 0.0, max_hp)

## Phase 38 — write the HOST's OWN resolution of a remote peer's health.
##
## The counterpart to `record_hp`, and the split between them is the whole point. A
## remote peer's HP that arrives over the wire is client-declared and refused. HP the
## host RESOLVED ITSELF — a creature's combat round, opened against a peer the host was
## already tracking (`game_root._on_player_damaged`) — is the host's own evidence, the
## same standing as that peer's last-known position. Before this method existed there
## was nowhere to put it: Phase 37 forwarded the round to the peer's own client and let
## that client keep the number, so a modified client could ignore every hit and an
## honest one lost its health on every reconnect and every restart, because nothing on
## this machine was allowed to remember it.
##
## Refused for the LOCAL player (its live body owns that number, via `record_hp`), for
## an empty id, for a player this host holds no record for (fail closed rather than
## mint a record for a stranger), and on a non-authoritative machine (a client holds no
## records at all).
##
## Phase 39 — a resolved hit that takes the number to ZERO parks the peer's respawn on
## the record as a wall-clock deadline (`respawn_deadline`), and a hit that leaves it
## positive CLEARS that key. The deadline is the only thing that can bring a
## host-simulated body back (`hp_after_respawn`), so it has to be written where the
## number that needs it is written, and dropped the moment the body is up again — the
## prune `live_cooldowns` performs on the cooldown table, applied to the one deadline a
## body carries. A LIVE deadline is never replaced: a creature striking a peer that is
## already down would otherwise push its respawn further away on every round and the
## body would never come back, which is the soft-lock this phase exists to close.
func record_simulated_hp(player_id: String, hp: float) -> void:
	if not is_authoritative:
		return
	if player_id.is_empty() or hp_is_authoritative_locally(player_id, local_player_id):
		return
	var rec := get_record(player_id)
	if rec.is_empty():
		return
	rec["hp"] = hp
	if not is_downed(hp):
		# Cleared to the "no respawn pending" value rather than erased, so the record's
		# shape does not depend on its history: a reader can tell "no deadline" from
		# "absent key" without a sentinel of its own.
		#
		# One predicate with the reader (`hp_after_respawn`), not a second `> 0.0` test:
		# a hit that lands a fraction short of zero leaves a remainder here, and while
		# this half said "up" and the reader said "down" the body could neither come back
		# nor be counted as gone. Review pass.
		rec["respawn_deadline"] = 0.0
		return
	var now := Time.get_unix_time_from_system()
	if float(rec.get("respawn_deadline", 0.0)) <= now:
		rec["respawn_deadline"] = now + RESPAWN_DELAY

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

## Phase 47 — the worn set ({ slot: item_key }). Durable per-player state, released
## with the rest of the record by `evict_player`. The set is filtered through the
## fabric slot check on the way in, so a record never holds an item that does not fit
## its slot. Returns true when the stored set changed.
func record_equipment(player_id: String, worn: Dictionary) -> bool:
	var rec := ensure_player(player_id)
	if rec.is_empty():
		return false
	var clean := EquipmentRules.sanitize(worn)
	if clean == rec.get("equipment", {}):
		return false
	rec["equipment"] = clean
	GameBus.equipment_changed.emit(player_id, clean.duplicate())
	return true

func get_equipment(player_id: String) -> Dictionary:
	var eq: Variant = get_record(player_id).get("equipment", {})
	return (eq as Dictionary).duplicate() if eq is Dictionary else {}

## Phase 37 — the per-player interaction cooldowns (instance_id → wall-clock Unix
## deadline), e.g. the GlimmerFox feed. Durable, because a cooldown is a rule about
## the PLAYER, not about this process: keeping it in memory meant a host restart
## handed every player a fresh set of cooldowns, so a fox could be milked in a loop
## by reconnecting. Only LIVE deadlines are stored — an elapsed one bounds nothing
## and would otherwise accumulate forever on the record.
func record_cooldowns(player_id: String, cooldowns: Dictionary) -> void:
	var rec := ensure_player(player_id)
	if rec.is_empty():
		return
	rec["cooldowns"] = live_cooldowns(cooldowns)

## The player's stored cooldowns (instance_id → deadline), already pruned to live
## deadlines. A pre-Phase-37 record has no such key and answers empty.
func get_cooldowns(player_id: String) -> Dictionary:
	return live_cooldowns(get_record(player_id).get("cooldowns", {}))

## Pure: the entries of a cooldown table whose deadline is still in the future,
## measured against wall-clock Unix seconds — the same clock every other deadline in
## the project uses. Static so the pruning rule is testable on its own.
static func live_cooldowns(cooldowns: Variant, now: float = -1.0) -> Dictionary:
	var out := {}
	if not (cooldowns is Dictionary):
		return out
	var at: float = Time.get_unix_time_from_system() if now < 0.0 else now
	for iid in cooldowns:
		if float(cooldowns[iid]) > at:
			out[str(iid)] = float(cooldowns[iid])
	return out

# ---------------------------------------------------------------------------
# Per-player inventory
# ---------------------------------------------------------------------------

## The inventory owned by `player_id`, creating (and parenting) one on first
## access so every player has their own — never the host's shared instance.
##
## Phase 37 — the created inventory is STAMPED with its owner (`owner_id`), which is
## what stops a bus-wide `inventory_synced` meant for one player from replacing every
## other inventory's contents in the process (see InventorySlice.is_owned_by).
func get_inventory(player_id: String) -> Node:
	if player_id.is_empty():
		return null
	if _inventories.has(player_id):
		return _inventories[player_id]
	if not is_authoritative:
		return null
	var inv := InventorySlice.new()
	inv.name = "Inventory_%s" % player_id
	inv.owner_id = player_id
	add_child(inv)
	_inventories[player_id] = inv
	return inv

## Bind an existing inventory instance to a player (the local player's).
##
## Deliberately does NOT stamp an owner: the local player's inventory IS the game's
## own `_inventory` instance, and the local bucket is what every local sync is
## addressed to (`""` / `"player"` — see InventorySlice.LOCAL_OWNER_LITERALS). An
## inventory the registry CREATES for a peer is stamped in `get_inventory`, because
## that one has to be told apart from this machine's.
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
##
## Phase 39 — the `hp` in here is RESOLVED (`hp_after_respawn`), not the raw stored
## value, for the same reason `get_hp` resolves: this is the copy the handshake
## snapshot, the disconnect save and the autosave all go through, so a downed peer whose
## deadline has passed has to read back ALIVE here too. Resolving on the live reader
## alone left the reconnect — which reads this copy — replaying the zero, and the
## reconnecting client then sat dead with no countdown (see the phase's deliverable 1).
## The deadline travels with it so the fact survives the round trip.
func get_player_data(player_id: String) -> Dictionary:
	var rec := get_record(player_id)
	var data := {
		"player_id": player_id,
		"position":  rec.get("position", [0.0, 0.0, 0.0]),
		"hp":        _resolved_hp(rec),
		"respawn_deadline": float(rec.get("respawn_deadline", 0.0)),
		"appearance": rec.get("appearance", {}),
		"technology": rec.get("technology", {}),
		"flags":      rec.get("flags", {}),
		"companions": rec.get("companions", []),
		"skills":     rec.get("skills", {}),
		"cooldowns":  live_cooldowns(rec.get("cooldowns", {})),
		"equipment":  get_equipment(player_id),
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
	var restored_hp := float(data.get("hp", -1.0))
	rec["hp"] = restored_hp
	# Phase 39 — the respawn deadline rides the same record. The saved `hp` above is
	# ALREADY resolved (see get_player_data), so a restored downed peer arrives here as
	# either the zero it is waiting out or the full health its deadline already bought;
	# the deadline is kept so the wait survives a restart that lands mid-countdown. A
	# payload from before this phase carries no key and restores to 0.0 — no deadline,
	# which is the pre-Phase-39 behaviour for a body with no pending respawn.
	#
	# Kept only while the body it belongs to is DOWN — the same `is_downed` the two readers
	# use. Because the saved `hp` is resolved, a body whose deadline has already been spent
	# arrives here ALIVE carrying that spent deadline, and keeping it would leave a standing
	# body wearing a piece of dead history for the rest of the world's life: harmless to
	# read (`hp_after_respawn` returns a standing body unchanged) and never true again, which
	# is exactly the distinction `record_simulated_hp` draws when it clears the key the
	# moment a hit leaves the body up. One rule for "the body is up", so the key cannot mean
	# two things depending on which door the record came through. **Review pass.**
	var deadline := float(data.get("respawn_deadline", 0.0))
	rec["respawn_deadline"] = deadline if is_downed(restored_hp) else 0.0
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
	# Phase 37: so are the interaction cooldowns (an expired deadline is dropped on
	# the way in — see live_cooldowns). A pre-Phase-37 payload carries no key.
	rec["cooldowns"]  = live_cooldowns(data.get("cooldowns", {}))
	# Phase 47: the worn set; a pre-Phase-47 payload carries no key (nothing worn).
	rec["equipment"]  = EquipmentRules.sanitize(data.get("equipment", {}))
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

## Phase 47 — host: a peer's worn set arrived (the networking slice re-emits an
## inbound intent under the identity bound to the connection, never a payload's).
func _on_equipment_intent(player_id: String, worn: Dictionary) -> void:
	if not is_authoritative or player_id.is_empty():
		return
	# A peer can only wear what its own bag holds; the claim is filtered like any other.
	var inv := get_inventory(player_id)
	var owned: Dictionary = {}
	if inv != null:
		for slot in worn:
			if inv.get_item_count(str(worn[slot])) > 0:
				owned[slot] = worn[slot]
	record_equipment(player_id, owned)

func _on_player_join_intent(peer_id: int, claimed_id: String) -> void:
	if not is_authoritative:
		return
	resolve_identity(peer_id, claimed_id)
