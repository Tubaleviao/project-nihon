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
## `trade_completed`; full remote-session negotiation is deferred (see ROADMAP).
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
	return inventory_slice

## Open a trade between two parties; returns the trade id.
func start_trade(party_a: String, party_b: String) -> String:
	var id := "trade_%d" % _next_id
	_next_id += 1
	_trades[id] = {
		"id": id,
		"parties": [party_a, party_b],
		"offers": {},
		"accepted": {},
		"state": "pending",
	}
	return id

## Set (or replace) a party's offer: what they give and what they want.
func propose(trade_id: String, party: String, give: Dictionary, want: Dictionary) -> Dictionary:
	var t: Dictionary = _trades.get(trade_id, {})
	if t.is_empty():
		return _fail(trade_id, "unknown_trade")
	t["offers"][party] = { "give": give.duplicate(), "want": want.duplicate() }
	return _state(trade_id)

## Replace an existing offer (a party may only counter-offer after proposing).
func counter_offer(trade_id: String, party: String, give: Dictionary, want: Dictionary) -> Dictionary:
	var t: Dictionary = _trades.get(trade_id, {})
	if t.is_empty():
		return _fail(trade_id, "unknown_trade")
	if not t["offers"].has(party):
		return _fail(trade_id, "no_offer")
	t["offers"][party] = { "give": give.duplicate(), "want": want.duplicate() }
	return _state(trade_id)

## Mark a party as accepting; the trade resolves the moment both accept.
func accept(trade_id: String, party: String) -> Dictionary:
	var t: Dictionary = _trades.get(trade_id, {})
	if t.is_empty():
		return _fail(trade_id, "unknown_trade")
	if not t["offers"].has(party):
		return _fail(trade_id, "no_offer")
	t["accepted"][party] = true
	return _maybe_resolve(trade_id)

## Reject a trade; the session is closed for both parties.
func reject(trade_id: String, party: String) -> Dictionary:
	var t: Dictionary = _trades.get(trade_id, {})
	if t.is_empty():
		return _fail(trade_id, "unknown_trade")
	t["state"] = "rejected"
	return { "trade_id": trade_id, "success": false, "reason": "rejected", "state": "rejected" }

func get_trade(trade_id: String) -> Dictionary:
	return _trades.get(trade_id, {}).duplicate()

## Force-resolve a trade whose two parties have accepted (also called
## automatically by accept). Exchanges give/want items between the parties'
## inventories, applying the local player's Trade broker fee.
func resolve(trade_id: String) -> Dictionary:
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
			return _state(trade_id)
	return _resolve_exchange(t)

## Execute the exchange: A's give → B's inventory, B's give → A's inventory,
## with the local player's Trade broker fee applied to what they receive.
func _resolve_exchange(t: Dictionary) -> Dictionary:
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

	_consume(inv_a, give_a)
	_consume(inv_b, give_b)
	_add(inv_a, received_a)
	_add(inv_b, received_b)

	t["state"] = "completed"
	GameBus.trade_completed.emit(t.duplicate())
	return { "trade_id": t["id"], "success": true, "reason": "", "state": "completed" }

func _apply_tax(counts: Dictionary, tax: float) -> Dictionary:
	var out := {}
	for item_id in counts:
		var qty: int = int(counts[item_id])
		var received: int = int(round(float(qty) * (1.0 - tax)))
		if received > 0:
			out[item_id] = received
	return out

func _can_consume(inv: Node, counts: Dictionary) -> bool:
	for item_id in counts:
		if inv.get_item_count(item_id) < int(counts[item_id]):
			return false
	return true

func _consume(inv: Node, counts: Dictionary) -> void:
	inv.consume_items(counts)

func _can_add(inv: Node, counts: Dictionary) -> bool:
	return inv.can_add_items(counts)

func _add(inv: Node, counts: Dictionary) -> void:
	for item_id in counts:
		inv.add_item(item_id, int(counts[item_id]))

func _state(trade_id: String) -> Dictionary:
	var t: Dictionary = _trades.get(trade_id, {})
	return { "trade_id": trade_id, "success": true, "reason": "", "state": str(t.get("state", "pending")) }

func _fail(trade_id: String, reason: String) -> Dictionary:
	return { "trade_id": trade_id, "success": false, "reason": reason, "state": "failed" }
