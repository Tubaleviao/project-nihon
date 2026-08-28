extends Node
## Market slice — persistent player-run market (Phase 24). Grounds the
## `EconomyIsPlayerDriven` principle: players list items at a price, others
## browse and buy; listings expire after a configurable duration. Market data
## is part of the world save snapshot so listings survive a save/load.
##
## Listings are ESCROWED: `list_item` debits the seller's inventory up front and
## refuses the listing if they don't hold the quantity; `buy` transfers the
## escrowed items into the buyer's inventory (no duplication — a self-buy nets
## zero, not double); an expired listing refunds its escrow back to the seller.
## There is no currency model yet, so `price` is an abstract numeric value
## recorded on the listing.
##
## Plug contract (GameBus signals emitted):
##   OUT : market_listing_created(listing_id, seller, item_id, quantity, price)
##         market_listing_purchased(listing_id, buyer, item_id, quantity)
##         market_listing_expired(listing_id)
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

## How often (seconds) the runtime expiry tick runs. Without a caller,
## expire_listings() never fires outside tests and escrow is never refunded.
const EXPIRY_TICK_INTERVAL: float = 1.0

## Local player inventory (set by game_root) — default party inventory.
var inventory_slice: Node = null

## Host authority (Phase 18) — kept for symmetry with other slices.
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

func _process(delta: float) -> void:
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

## Wall-clock time (Unix epoch seconds). Listings must track real deadlines, not
## process uptime, so a saved listing keeps its deadline across sessions.
func _now() -> float:
	return Time.get_unix_time_from_system()

## Create a listing for `quantity` of `item_id` at `price`, expiring after
## `expires_in` seconds (defaults to the configured duration). The listing is
## ESCROWED: the seller's inventory is debited up front, and the listing is
## rejected ("") when the seller has no inventory or doesn't hold the quantity.
## Returns the listing id.
func list_item(seller: String, item_id: String, quantity: int, price: float, expires_in: float = -1.0) -> String:
	if quantity <= 0 or price < 0.0:
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
## inventory to credit or can't hold the item. Returns
## { listing_id, success, item_id, quantity, reason }.
func buy(listing_id: String, buyer: String) -> Dictionary:
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
	return { "listing_id": listing_id, "success": true, "item_id": item_id, "quantity": quantity, "reason": "" }

## Remove every expired listing, refunding its escrow to the seller and emitting
## market_listing_expired for each. Returns the number expired.
func expire_listings() -> int:
	var now := _now()
	var expired: Array = []
	for id in _listings:
		if float(_listings[id]["expires_at"]) <= now:
			expired.append(id)
	for id in expired:
		var l: Dictionary = _listings[id]
		_refund_escrow(l)
		_listings.erase(id)
		GameBus.market_listing_expired.emit(id)
	return expired.size()

## Return an expired listing's escrowed items to its seller.
func _refund_escrow(l: Dictionary) -> void:
	var seller_inv := _inventory_for(str(l["seller"]))
	if seller_inv == null:
		return
	seller_inv.add_item(str(l["item_id"]), int(l["quantity"]))

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
	# Keep the id counter ahead of any restored listing id. Derive it from the
	# largest existing suffix rather than the count, so restoring "listing_5"
	# never lets a fresh listing reuse 5 just because the set is small.
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
