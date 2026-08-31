extends Node
## Market slice — persistent player-run market (Phase 24). Grounds the
## `EconomyIsPlayerDriven` principle: players list items at a price, others
## browse and buy; listings expire after a configurable duration. Market data
## is part of the world save snapshot so listings survive a save/load.
##
## Listings are ESCROWED: `list_item` debits the seller's inventory up front and
## refuses the listing if they don't hold the quantity; `buy` transfers the
## escrowed items into the buyer's inventory (no duplication — a self-buy nets
## zero, not double); an expired listing refunds its escrow back to the seller
## (a seller with a full inventory keeps the listing escrowed until there is
## room, so items are never destroyed).
##
## Host authority (Phase 18/24): the host owns the market. A non-authoritative
## slice (client) forwards list/buy intents to the host via the bus instead of
## mutating locally, and applies `market_synced` broadcasts. There is no
## currency model yet, so `price` is an abstract numeric value.
##
## Plug contract (GameBus signals emitted / consumed):
##   OUT : market_listing_created / market_listing_purchased / market_listing_expired
##         market_synced(data)     — authoritative full state (host)
##         market_list_intent / market_buy_intent — client intent
##   IN  : market_list_intent / market_buy_intent (host applies)
##         market_synced(data)     — apply authoritative state (client)
##
## Public API:
##   list_item(seller, item_id, quantity, price, expires_in) -> String
##   get_listings()            -> Array  (active only)
##   get_all_listings()        -> Array  (including expired, for inspection)
##   buy(listing_id, buyer)    -> Dictionary
##   expire_listings()         -> int    (remove expired, refund escrow, emit signals)
##   set_expiry_seconds(seconds)
##   set_party_inventory(party, inventory)  — resolve a party's inventory (escrow/buy)
##   get_market_data()         -> Dictionary  (persistence)
##   apply_market_data(data)   -> void        (persistence restore)

## Default listing lifetime (seconds) before expiry — fallback mirroring the
## fabric MarketSystem.defaultExpirySeconds; overridden from GameData in _ready().
const DEFAULT_EXPIRY_SECONDS: float = 3600.0

## How often (seconds) the runtime expiry tick runs.
const EXPIRY_TICK_INTERVAL: float = 1.0

## Local player inventory (set by game_root) — default party inventory.
var inventory_slice: Node = null

## Host authority (Phase 18). The host mutates + broadcasts; a client forwards
## intent and applies authoritative deltas.
var is_authoritative: bool = true

## Party id → inventory override (tests model seller/buyer sides; a host models
## remote parties).
var _party_inventory: Dictionary = {}

## Active + not-yet-collected listings keyed by listing id.
var _listings: Dictionary = {}
var _next_id: int = 0
var _expiry_seconds: float = DEFAULT_EXPIRY_SECONDS
var _expiry_tick_accum: float = 0.0

func _ready() -> void:
	_load_market_config()
	GameBus.market_list_intent.connect(_on_list_intent)
	GameBus.market_buy_intent.connect(_on_buy_intent)
	GameBus.market_synced.connect(_on_market_synced)

func _process(delta: float) -> void:
	if not is_authoritative:
		return
	_expiry_tick_accum += delta
	if _expiry_tick_accum >= EXPIRY_TICK_INTERVAL:
		_expiry_tick_accum = 0.0
		expire_listings()

## Load the default listing lifetime from the fabric MarketSystem entity so the
## expiry window is fabric-first (single source of truth in GameData).
func _load_market_config() -> void:
	var res: Resource = GameData.WORLD_SYSTEMS.get("MarketSystem", null)
	if res == null:
		return
	var secs: Variant = res.get("defaultExpirySeconds")
	if secs != null:
		_expiry_seconds = float(secs)

func set_expiry_seconds(seconds: float) -> void:
	_expiry_seconds = seconds

## Override the inventory for a party (tests model both sides of a sale).
func set_party_inventory(party: String, inv: Node) -> void:
	_party_inventory[party] = inv

func _inventory_for(party: String) -> Node:
	if _party_inventory.has(party):
		return _party_inventory[party]
	if party == "player":
		return inventory_slice
	return null

## Wall-clock time (Unix epoch seconds).
func _now() -> float:
	return Time.get_unix_time_from_system()

## Create a listing for `quantity` of `item_id` at `price`, expiring after
## `expires_in` seconds. On the authoritative slice the seller's inventory is
## debited up front and the listing is rejected ("") when the seller can't
## supply the quantity. On a client this forwards a list intent and returns "".
func list_item(seller: String, item_id: String, quantity: int, price: float, expires_in: float = -1.0) -> String:
	if quantity <= 0 or price < 0.0:
		return ""
	if not is_authoritative:
		GameBus.market_list_intent.emit(seller, item_id, quantity, price)
		return ""
	var seller_inv := _inventory_for(seller)
	if seller_inv == null:
		return ""
	if not seller_inv.consume_items({ item_id: quantity }):
		return ""
	var lifetime: float = _expiry_seconds if expires_in < 0.0 else expires_in
	var now := _now()
	var id := "listing_%d" % _next_id
	_next_id += 1
	_listings[id] = {
		"id": id,
		"seller": seller,
		"item_id": item_id,
		"quantity": quantity,
		"price": price,
		"listed_at": now,
		"expires_at": now + lifetime,
	}
	GameBus.market_listing_created.emit(id, seller, item_id, quantity, price)
	_emit_synced()
	return id

## Active (unexpired) listings.
func get_listings() -> Array:
	var out: Array = []
	var now := _now()
	for id in _listings:
		var l: Dictionary = _listings[id]
		if float(l["expires_at"]) > now:
			out.append(l.duplicate())
	return out

## Every listing, expired or not (for inspection / tests).
func get_all_listings() -> Array:
	var out: Array = []
	for id in _listings:
		out.append(_listings[id].duplicate())
	return out

## Purchase a listing: transfer its escrowed item into the buyer's inventory and
## remove the listing. Fails (leaving the listing intact) when the buyer has no
## inventory or can't hold the item. On a client this forwards a buy intent.
## Returns { listing_id, success, item_id, quantity, reason }.
func buy(listing_id: String, buyer: String) -> Dictionary:
	if not is_authoritative:
		GameBus.market_buy_intent.emit(listing_id, buyer)
		return { "listing_id": listing_id, "success": false, "item_id": "", "quantity": 0, "reason": "forwarded" }
	var l: Dictionary = _listings.get(listing_id, {})
	if l.is_empty():
		return _buy_fail(listing_id, "", 0, "unknown_listing")
	if float(l["expires_at"]) <= _now():
		return _buy_fail(listing_id, str(l["item_id"]), int(l["quantity"]), "expired")
	var item_id: String = str(l["item_id"])
	var quantity: int = int(l["quantity"])
	var buyer_inv := _inventory_for(buyer)
	if buyer_inv == null:
		return _buy_fail(listing_id, item_id, quantity, "no_inventory")
	if not buyer_inv.can_add_items({ item_id: quantity }):
		return _buy_fail(listing_id, item_id, quantity, "inventory_full")
	buyer_inv.add_item(item_id, quantity)
	_listings.erase(listing_id)
	GameBus.market_listing_purchased.emit(listing_id, buyer, item_id, quantity)
	_emit_synced()
	return { "listing_id": listing_id, "success": true, "item_id": item_id, "quantity": quantity, "reason": "" }

## Remove every expired listing, refunding its escrow to the seller and emitting
## market_listing_expired for each. A seller whose inventory can't hold the
## refund keeps the listing escrowed (retried next tick) so items are never
## destroyed. A seller whose inventory no longer exists (null) can never be
## refunded, so the listing is dropped rather than retried forever. Returns the
## number removed.
func expire_listings() -> int:
	var now := _now()
	var expired: Array = []
	for id in _listings:
		if float(_listings[id]["expires_at"]) <= now:
			expired.append(id)
	var removed := 0
	for id in expired:
		var l: Dictionary = _listings[id]
		var seller_inv := _inventory_for(str(l["seller"]))
		if seller_inv == null:
			# No inventory to refund to — the escrow is unrecoverable. Drop the
			# listing so the expiry tick doesn't retry it forever.
			_listings.erase(id)
			GameBus.market_listing_expired.emit(id)
			removed += 1
			continue
		if not _refund_escrow(l):
			continue   # seller can't hold the refund yet — keep it escrowed
		_listings.erase(id)
		GameBus.market_listing_expired.emit(id)
		removed += 1
	if removed > 0:
		_emit_synced()
	return removed

## Return an expired listing's escrowed items to its seller. Returns false
## (keeping the listing escrowed) when the seller has no inventory or can't hold
## the items — items are never silently dropped.
func _refund_escrow(l: Dictionary) -> bool:
	var seller_inv := _inventory_for(str(l["seller"]))
	if seller_inv == null:
		return false
	var item_id := str(l["item_id"])
	var quantity := int(l["quantity"])
	if not seller_inv.can_add_items({ item_id: quantity }):
		return false
	seller_inv.add_item(item_id, quantity)
	return true

## Serialize active + expired listings for the save snapshot.
func get_market_data() -> Dictionary:
	var data := {}
	for id in _listings:
		var l: Dictionary = _listings[id]
		data[id] = {
			"seller": l["seller"],
			"item_id": l["item_id"],
			"quantity": l["quantity"],
			"price": l["price"],
			"listed_at": l["listed_at"],
			"expires_at": l["expires_at"],
		}
	return data

## Restore listings from a persisted snapshot (ignores malformed entries).
func apply_market_data(data: Dictionary) -> void:
	_listings.clear()
	for id in data:
		var e = data[id]
		if e is not Dictionary:
			continue
		var item_id: String = str(e.get("item_id", ""))
		if item_id == "":
			continue
		_listings[str(id)] = {
			"id": str(id),
			"seller": str(e.get("seller", "")),
			"item_id": item_id,
			"quantity": int(e.get("quantity", 0)),
			"price": float(e.get("price", 0.0)),
			"listed_at": float(e.get("listed_at", 0.0)),
			"expires_at": float(e.get("expires_at", 0.0)),
		}
	_next_id = _max_listing_suffix() + 1

## Largest numeric suffix among existing listing ids (-1 when none).
func _max_listing_suffix() -> int:
	var max_id := -1
	for id in _listings:
		var sid := str(id)
		if sid.begins_with("listing_"):
			max_id = maxi(max_id, int(sid.substr("listing_".length())))
	return max_id

func _buy_fail(listing_id: String, item_id: String, quantity: int, reason: String) -> Dictionary:
	return { "listing_id": listing_id, "success": false, "item_id": item_id, "quantity": quantity, "reason": reason }

# ---------------------------------------------------------------------------
# Authority (Phase 24) — intent forwarding + authoritative broadcast
# ---------------------------------------------------------------------------

## Host: apply a client's list intent.
func _on_list_intent(seller: String, item_id: String, quantity: int, price: float) -> void:
	if is_authoritative:
		list_item(seller, item_id, quantity, price)

## Host: apply a client's buy intent.
func _on_buy_intent(listing_id: String, buyer: String) -> void:
	if is_authoritative:
		buy(listing_id, buyer)

## Client: apply the host's authoritative market state.
func _on_market_synced(data: Dictionary) -> void:
	if not is_authoritative:
		apply_market_data(data)

## Host: broadcast the authoritative market state to clients.
func _emit_synced() -> void:
	if is_authoritative:
		GameBus.market_synced.emit(get_market_data())
