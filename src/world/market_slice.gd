extends Node
## Market slice — persistent player-run market (Phase 24). Grounds the
## `EconomyIsPlayerDriven` principle: players list items at a price, others
## browse and buy; listings expire after a configurable duration. Market data
## is part of the world save snapshot so listings survive a save/load.
##
## There is no currency model yet, so `price` is an abstract numeric value
## recorded on the listing (currency exchange is deferred). A buy transfers the
## listed item into the buyer's inventory and removes the listing.
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
##   expire_listings()         -> int    (remove expired, emit signals)
##   set_expiry_seconds(seconds)
##   get_market_data()         -> Dictionary  (persistence)
##   apply_market_data(data)   -> void        (persistence restore)

## Default listing lifetime (seconds) before expiry.
const DEFAULT_EXPIRY_SECONDS: float = 3600.0

## Local player inventory (set by game_root) — receives purchased items.
var inventory_slice: Node = null

## Host authority (Phase 18) — kept for symmetry with other slices.
var is_authoritative: bool = true

## Active + not-yet-collected listings keyed by listing id.
var _listings: Dictionary = {}
var _next_id: int = 0
var _expiry_seconds: float = DEFAULT_EXPIRY_SECONDS

func set_expiry_seconds(seconds: float) -> void:
	_expiry_seconds = seconds

## Create a listing for `quantity` of `item_id` at `price`, expiring after
## `expires_in` seconds (defaults to the configured duration). Returns the
## listing id. A non-positive quantity or negative price is rejected ("").
func list_item(seller: String, item_id: String, quantity: int, price: float, expires_in: float = -1.0) -> String:
	if quantity <= 0 or price < 0.0:
		return ""
	var lifetime: float = _expiry_seconds if expires_in < 0.0 else expires_in
	var now := Time.get_ticks_msec()
	var id := "listing_%d" % _next_id
	_next_id += 1
	_listings[id] = {
		"id": id,
		"seller": seller,
		"item_id": item_id,
		"quantity": quantity,
		"price": price,
		"listed_at": now,
		"expires_at": now + int(lifetime * 1000.0),
	}
	GameBus.market_listing_created.emit(id, seller, item_id, quantity, price)
	return id

## Active (unexpired) listings.
func get_listings() -> Array:
	var out: Array = []
	var now := Time.get_ticks_msec()
	for id in _listings:
		var l: Dictionary = _listings[id]
		if int(l["expires_at"]) > now:
			out.append(l.duplicate())
	return out

## Every listing, expired or not (for inspection / tests).
func get_all_listings() -> Array:
	var out: Array = []
	for id in _listings:
		out.append(_listings[id].duplicate())
	return out

## Purchase a listing: transfer its item into the buyer's inventory and remove
## the listing. Returns { listing_id, success, item_id, quantity, reason }.
func buy(listing_id: String, buyer: String) -> Dictionary:
	var l: Dictionary = _listings.get(listing_id, {})
	if l.is_empty():
		return _buy_fail(listing_id, "", 0, "unknown_listing")
	if int(l["expires_at"]) <= Time.get_ticks_msec():
		return _buy_fail(listing_id, str(l["item_id"]), int(l["quantity"]), "expired")
	var item_id: String = str(l["item_id"])
	var quantity: int = int(l["quantity"])
	if buyer == "player" and inventory_slice != null:
		if not inventory_slice.can_add_items({ item_id: quantity }):
			return _buy_fail(listing_id, item_id, quantity, "inventory_full")
		inventory_slice.add_item(item_id, quantity)
	_listings.erase(listing_id)
	GameBus.market_listing_purchased.emit(listing_id, buyer, item_id, quantity)
	return { "listing_id": listing_id, "success": true, "item_id": item_id, "quantity": quantity, "reason": "" }

## Remove every expired listing, emitting market_listing_expired for each.
## Returns the number expired.
func expire_listings() -> int:
	var now := Time.get_ticks_msec()
	var expired: Array = []
	for id in _listings:
		if int(_listings[id]["expires_at"]) <= now:
			expired.append(id)
	for id in expired:
		_listings.erase(id)
		GameBus.market_listing_expired.emit(id)
	return expired.size()

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
			"listed_at": int(e.get("listed_at", 0)),
			"expires_at": int(e.get("expires_at", 0)),
		}
	# Keep the id counter ahead of any restored listing ids.
	_next_id = _listings.size() + 1

func _buy_fail(listing_id: String, item_id: String, quantity: int, reason: String) -> Dictionary:
	return { "listing_id": listing_id, "success": false, "item_id": item_id, "quantity": quantity, "reason": reason }
