extends Node
## Trade slice — player-to-player trade sessions (Phase 24). Grounds the
## `EconomyIsPlayerDriven` constitution principle: two parties propose and
## counter-offer items, and a trade resolves only when both accept.
##
## A trade is a two-party session. Each party proposes what they give and what
## they want; either side may counter-offer; the exchange commits when both
## accept. The local player's Trade skill tier applies a broker fee to the
## goods they receive — higher Trade lowers the fee — making the social skill
## tree visibly affect a trade. (Diplomacy is scoped to NPC factions in the
## fabric and does not affect player-to-player trade.)
##
## Plug contract (GameBus signals emitted):
##   OUT : trade_completed(trade)   — the resolved trade record
##         trade_synced(data)       — authoritative full state (host)
##         trade_start_intent / trade_propose_intent / trade_accept_intent /
##         trade_reject_intent      — client intent
##   IN  : trade_start_intent / trade_propose_intent / trade_accept_intent /
##         trade_reject_intent      (host applies)
##         trade_synced(data)       — apply authoritative state (client)
##
## Public API:
##   start_trade(a, b)              -> String     (trade id)
##   propose(trade_id, party, give, want) -> Dictionary
##   counter_offer(trade_id, party, give, want) -> Dictionary
##   accept(trade_id, party)        -> Dictionary (auto-resolves when both accept)
##   reject(trade_id, party)        -> Dictionary
##   resolve(trade_id)              -> Dictionary (force-resolve both accepted)
##   get_trade(trade_id)            -> Dictionary
##   set_skill / get_skill / get_skills
##   set_party_inventory(party, inventory)  — override a party's inventory (tests)

## Local player party id.
const PARTY_PLAYER := "player"

## Preload the inventory slice so the exchange can use its static `transfer`.
const InventorySlice := preload("res://src/inventory/inventory_slice.gd")

## Trade tier → fraction of received goods withheld as a broker fee (fallback,
## mirroring the fabric TradeSystem.brokerFee default). Higher Trade lowers the
## fee; a master trades tax-free. Overridden from GameData in _ready().
const DEFAULT_BROKER_FEE: Dictionary = {
	"novice": 0.10,
	"apprentice": 0.08,
	"journeyman": 0.05,
	"expert": 0.02,
	"master": 0.0,
}

## Social skill whose tier drives the broker fee (fabric TradeSystem.feeSkill).
var _fee_skill: String = "Trade"

## Broker-fee table loaded from the fabric (TradeSystem.brokerFee); defaults to
## DEFAULT_BROKER_FEE until _ready() loads the authoritative values.
var _broker_fee: Dictionary = DEFAULT_BROKER_FEE.duplicate()

## Local player inventory (set by game_root). Default party inventory.
var inventory_slice: Node = null

## Host authority (Phase 18). The host resolves trades and broadcasts
## `trade_completed`; a client forwards intents to the host and applies
## `trade_synced` broadcasts (full remote-session negotiation is deferred — see
## ROADMAP).
var is_authoritative: bool = true

## Runtime player skill tiers: skill key → tier name, seeded novice.
var _skill_tiers: Dictionary = {}

## Party id → inventory node override (used by tests to model both sides).
var _party_inventory: Dictionary = {}

## Active trades keyed by trade id.
var _trades: Dictionary = {}
var _next_id: int = 0

func _ready() -> void:
	for skill_key in GameData.SKILLS:
		_skill_tiers[skill_key] = "novice"
	_load_trade_config()
	GameBus.trade_start_intent.connect(_on_start_intent)
	GameBus.trade_propose_intent.connect(_on_propose_intent)
	GameBus.trade_accept_intent.connect(_on_accept_intent)
	GameBus.trade_reject_intent.connect(_on_reject_intent)
	GameBus.trade_synced.connect(_on_trade_synced)

## Load the broker-fee table and fee skill from the fabric TradeSystem entity so
## balance numbers stay fabric-first (single source of truth in GameData).
func _load_trade_config() -> void:
	var res: Resource = GameData.WORLD_SYSTEMS.get("TradeSystem", null)
	if res == null:
		return
	var fee: Variant = res.get("brokerFee")
	if fee is Dictionary and not fee.is_empty():
		_broker_fee = (fee as Dictionary).duplicate()
	var skill: String = str(res.get("feeSkill"))
	if skill != "":
		_fee_skill = skill

func set_skill(skill: String, tier: String) -> void:
	_skill_tiers[skill] = tier

func get_skill(skill: String) -> String:
	return str(_skill_tiers.get(skill, "novice"))

func get_skills() -> Dictionary:
	return _skill_tiers.duplicate()

## Override the inventory for a party (tests model both trade sides).
func set_party_inventory(party: String, inv: Node) -> void:
	_party_inventory[party] = inv

func _inventory_for(party: String) -> Node:
	if _party_inventory.has(party):
		return _party_inventory[party]
	if party == "player":
		return inventory_slice
	return null

## Open a trade between two parties; returns the trade id. On a client this
## forwards a start intent and returns "" (the host assigns the id).
func start_trade(party_a: String, party_b: String) -> String:
	if not is_authoritative:
		GameBus.trade_start_intent.emit(party_a, party_b)
		return ""
	var id := "trade_%d" % _next_id
	_next_id += 1
	_trades[id] = {
		"id": id,
		"parties": [party_a, party_b],
		"offers": {},
		"accepted": {},
		"state": "pending",
	}
	_emit_synced()
	return id

## Set (or replace) a party's offer: what they give and what they want. On a
## client this forwards a propose intent and returns a "forwarded" marker.
func propose(trade_id: String, party: String, give: Dictionary, want: Dictionary) -> Dictionary:
	if not is_authoritative:
		GameBus.trade_propose_intent.emit(trade_id, party, give, want)
		return { "trade_id": trade_id, "success": false, "reason": "forwarded", "state": "pending" }
	var t: Dictionary = _trades.get(trade_id, {})
	if t.is_empty():
		return _fail(trade_id, "unknown_trade")
	if not _is_party(t, party):
		return _fail(trade_id, "unknown_party")
	t["offers"][party] = { "give": give.duplicate(true), "want": want.duplicate(true) }
	_emit_synced()
	return _state(trade_id)

## Replace an existing offer (a party may only counter-offer after proposing).
## On a client this forwards a propose intent and returns a "forwarded" marker.
func counter_offer(trade_id: String, party: String, give: Dictionary, want: Dictionary) -> Dictionary:
	if not is_authoritative:
		GameBus.trade_propose_intent.emit(trade_id, party, give, want)
		return { "trade_id": trade_id, "success": false, "reason": "forwarded", "state": "pending" }
	var t: Dictionary = _trades.get(trade_id, {})
	if t.is_empty():
		return _fail(trade_id, "unknown_trade")
	if not _is_party(t, party):
		return _fail(trade_id, "unknown_party")
	if not t["offers"].has(party):
		return _fail(trade_id, "no_offer")
	t["offers"][party] = { "give": give.duplicate(true), "want": want.duplicate(true) }
	_emit_synced()
	return _state(trade_id)

## Mark a party as accepting; the trade resolves the moment both accept. On a
## client this forwards an accept intent and returns a "forwarded" marker.
func accept(trade_id: String, party: String) -> Dictionary:
	if not is_authoritative:
		GameBus.trade_accept_intent.emit(trade_id, party)
		return { "trade_id": trade_id, "success": false, "reason": "forwarded", "state": "pending" }
	var t: Dictionary = _trades.get(trade_id, {})
	if t.is_empty():
		return _fail(trade_id, "unknown_trade")
	if not _is_party(t, party):
		return _fail(trade_id, "unknown_party")
	if not t["offers"].has(party):
		return _fail(trade_id, "no_offer")
	t["accepted"][party] = true
	return _maybe_resolve(trade_id)

## Reject a trade; the session is closed for both parties. `party` is validated
## against the trade's parties (a non-party cannot reject). On a client this
## forwards a reject intent.
func reject(trade_id: String, party: String) -> Dictionary:
	if not is_authoritative:
		GameBus.trade_reject_intent.emit(trade_id, party)
		return { "trade_id": trade_id, "success": false, "reason": "forwarded", "state": "pending" }
	var t: Dictionary = _trades.get(trade_id, {})
	if t.is_empty():
		return _fail(trade_id, "unknown_trade")
	if not _is_party(t, party):
		return _fail(trade_id, "unknown_party")
	t["state"] = "rejected"
	_emit_synced()
	return { "trade_id": trade_id, "success": false, "reason": "rejected", "state": "rejected" }

func get_trade(trade_id: String) -> Dictionary:
	return _trades.get(trade_id, {}).duplicate(true)

## Force-resolve a trade whose two parties have accepted (also called
## automatically by accept). Exchanges give/want items between the parties'
## inventories, applying the local player's Trade broker fee.
func resolve(trade_id: String) -> Dictionary:
	if not is_authoritative:
		return { "trade_id": trade_id, "success": false, "reason": "forwarded", "state": "pending" }
	var t: Dictionary = _trades.get(trade_id, {})
	if t.is_empty():
		return _fail(trade_id, "unknown_trade")
	if t["state"] == "completed":
		return { "trade_id": trade_id, "success": true, "reason": "", "state": "completed" }
	if t["state"] == "rejected":
		return _fail(trade_id, "rejected")
	var parties: Array = t["parties"]
	var accepted: Dictionary = t["accepted"]
	for party in parties:
		if not accepted.get(party, false):
			return _fail(trade_id, "not_accepted")
	return _resolve_exchange(t)

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _maybe_resolve(trade_id: String) -> Dictionary:
	var t: Dictionary = _trades.get(trade_id, {})
	var parties: Array = t["parties"]
	for party in parties:
		if not t["accepted"].get(party, false):
			# A single-party acceptance mutates authoritative state (the
			# accepted flag) but doesn't resolve yet — broadcast it so clients
			# see who has accepted. The full resolve path (_resolve_exchange)
			# emits its own sync, so this only fires on the partial-accept path.
			_emit_synced()
			return _state(trade_id)
	return _resolve_exchange(t)

## Execute the exchange: A's give → B's inventory, B's give → A's inventory,
## with the local player's Trade broker fee applied to what they receive.
func _resolve_exchange(t: Dictionary) -> Dictionary:
	# Idempotent: once completed, never re-run the exchange. A double accept
	# (reachable by clicking the UI "accept" button twice) must not duplicate
	# the transferred items.
	if str(t.get("state", "")) == "completed":
		return { "trade_id": t["id"], "success": true, "reason": "", "state": "completed" }
	# A rejected trade is terminal: reject leaves the accepted flags intact, so
	# a late accept must not resolve a rejected session.
	if str(t.get("state", "")) == "rejected":
		return _fail(t["id"], "rejected")
	var parties: Array = t["parties"]
	var a: String = parties[0]
	var b: String = parties[1]
	var offer_a: Dictionary = t["offers"].get(a, {})
	var offer_b: Dictionary = t["offers"].get(b, {})
	if offer_a.is_empty() or offer_b.is_empty():
		return _fail(t["id"], "missing_offer")

	var give_a: Dictionary = offer_a.get("give", {})
	var give_b: Dictionary = offer_b.get("give", {})

	var inv_a := _inventory_for(a)
	var inv_b := _inventory_for(b)
	if inv_a == null or inv_b == null:
		return _fail(t["id"], "no_inventory")

	if not _can_consume(inv_a, give_a):
		return _fail(t["id"], "missing_goods:%s" % a)
	if not _can_consume(inv_b, give_b):
		return _fail(t["id"], "missing_goods:%s" % b)

	# The local player's Trade broker fee applies only to goods the LOCAL player
	# receives. When neither party is "player" (e.g. a host resolving a
	# peer-to-peer trade), no fee applies.
	var received_a: Dictionary = give_b.duplicate()
	var received_b: Dictionary = give_a.duplicate()
	var tax: float = float(_broker_fee.get(get_skill(_fee_skill), 0.10))
	if a == PARTY_PLAYER:
		received_a = _apply_tax(give_b, tax)
	elif b == PARTY_PLAYER:
		received_b = _apply_tax(give_a, tax)

	if not _can_add(inv_a, received_a):
		return _fail(t["id"], "inventory_full:%s" % a)
	if not _can_add(inv_b, received_b):
		return _fail(t["id"], "inventory_full:%s" % b)

	# Move the goods with two static transfers, each carrying the removed
	# instances' exact per-instance durability (worst first), so a worn/broken
	# item arrives with its real condition instead of resetting to pristine.
	var r_a: Dictionary = InventorySlice.transfer(inv_b, inv_a, received_a)   # A receives B's give
	if not bool(r_a.get("success", false)):
		return _fail(t["id"], str(r_a.get("reason", "transfer_failed")))
	var r_b: Dictionary = InventorySlice.transfer(inv_a, inv_b, received_b)   # B receives A's give
	if not bool(r_b.get("success", false)):
		return _fail(t["id"], str(r_b.get("reason", "transfer_failed")))

	t["state"] = "completed"
	_emit_synced()
	GameBus.trade_completed.emit(t.duplicate(true))
	return { "trade_id": t["id"], "success": true, "reason": "", "state": "completed" }

func _apply_tax(counts: Dictionary, tax: float) -> Dictionary:
	var out := {}
	for item_id in counts:
		var qty: int = int(counts[item_id])
		if qty <= 0:
			continue
		# The fee withholds a fraction of received goods; never let it round a
		# positive quantity down to zero — that would destroy the item outright.
		var received: int = maxi(1, int(round(float(qty) * (1.0 - tax))))
		out[item_id] = received
	return out

func _can_consume(inv: Node, counts: Dictionary) -> bool:
	for item_id in counts:
		if inv.get_item_count(item_id) < int(counts[item_id]):
			return false
	return true

func _can_add(inv: Node, counts: Dictionary) -> bool:
	return inv.can_add_items(counts)

func _state(trade_id: String) -> Dictionary:
	var t: Dictionary = _trades.get(trade_id, {})
	return { "trade_id": trade_id, "success": true, "reason": "", "state": str(t.get("state", "pending")) }

func _fail(trade_id: String, reason: String) -> Dictionary:
	# The reported state reflects the trade's actual state, not a hardcoded
	# "failed": a resolve that fails on missing goods leaves the trade pending
	# (retryable), so the result and get_trade() stay consistent.
	var state := "failed"
	var t: Dictionary = _trades.get(trade_id, {})
	if not t.is_empty():
		state = str(t.get("state", "pending"))
	return { "trade_id": trade_id, "success": false, "reason": reason, "state": state }

func _is_party(t: Dictionary, party: String) -> bool:
	return party in t["parties"]

## Full trade state for authoritative sync (all active sessions + id counter).
func get_trade_data() -> Dictionary:
	return { "trades": _trades.duplicate(true), "next_id": _next_id }

## Restore full trade state from an authoritative sync.
func apply_trade_data(data: Dictionary) -> void:
	_trades.clear()
	var trades: Variant = data.get("trades", {})
	if trades is Dictionary:
		_trades = trades.duplicate(true)
	_next_id = int(data.get("next_id", _next_id))

# ---------------------------------------------------------------------------
# Authority (Phase 24) — intent forwarding + authoritative broadcast
# ---------------------------------------------------------------------------

func _on_start_intent(party_a: String, party_b: String) -> void:
	if is_authoritative:
		start_trade(party_a, party_b)

func _on_propose_intent(trade_id: String, party: String, give: Dictionary, want: Dictionary) -> void:
	if is_authoritative:
		propose(trade_id, party, give, want)

func _on_accept_intent(trade_id: String, party: String) -> void:
	if is_authoritative:
		accept(trade_id, party)

func _on_reject_intent(trade_id: String, party: String) -> void:
	if is_authoritative:
		reject(trade_id, party)

func _on_trade_synced(data: Dictionary) -> void:
	if not is_authoritative:
		apply_trade_data(data)

func _emit_synced() -> void:
	if is_authoritative:
		GameBus.trade_synced.emit(get_trade_data())
