extends RefCounted
## Phase 292 — how the UI names a player that another player is shown.
##
## A replicated blob names players by public handle (Phase 36: the id is a bearer token and never crosses the
## wire), and the handle is for actions only (buy, cancel, a whisper): it is never printed. The host sends the
## character name beside it (`seller_name`, a proposal's `author_name`, a trade's `names`, a clan roll's `name`),
## read from the registry at send time, and every UI string that formats a player field goes through here:
##
##   • the viewer's own entry ("player" on a client, see `NetworkingSlice.adopt_own_handle`) reads "<name> (you)";
##   • the NPC merchant reads its localized name;
##   • a named player reads their name;
##   • a player with no name left (deleted, never created) reads a localized "unknown seller" / "unknown player".
##
## `PLAYER_FIELD_KEYS` is the list of UI strings that format a player field; the suite renders each one from a
## row that carries a handle and fails if the handle shows, and an audit fails if any other UI file formats one
## of these keys itself.

const I18n := preload("res://src/core/i18n.gd")

## The literal a client's own party arrives as (and the host's local player is stored as).
const SELF := "player"
## The NPC seller of the demo market (`GameRoot`), never a player.
const MERCHANT := "merchant"

## Every UI string that formats a player field, with the formatter below that renders it.
const PLAYER_FIELD_KEYS := {
	"ui.listing": "listing_line",
	"ui.proposal_line": "proposal_line",
	"trade.entry": "trade_line",
	"clan.member_line": "ClanPanel.roster_lines",
}

## The label for `party` named `name`. `own_name` names the viewer when the row is theirs and carries no name;
## `unknown_key` is the string for a player with no name left.
## A name that is only a handle (what `display_name` falls back to) counts as no name: it is never printed.
static func label(party: String, name: String, own_name: String = "", unknown_key: String = "party.unknown") -> String:
	var shown := name if not is_handle(name) else ""
	if party == SELF:
		if shown == "" and not is_handle(own_name):
			shown = own_name
		return I18n.t("party.you", [shown]) if shown != "" else I18n.t("party.you_bare")
	if party == MERCHANT:
		return I18n.t("party.merchant")
	return shown if shown != "" else I18n.t(unknown_key)

## True for a public handle (`PlayerRegistry.HANDLE_PREFIX` + 16 hex), "" excluded.
static func is_handle(s: String) -> bool:
	return s.length() == 18 and s.begins_with("p_") and s.substr(2).is_valid_hex_number()

## A row's name: the one the host sent with it, else `resolve(party)` (the host's registry: the host's own blobs
## carry no names, they are added only to the copy a client is sent), else "".
static func name_for(sent: Variant, party: String, resolve: Callable) -> String:
	if sent != null and str(sent) != "":
		return str(sent)
	return str(resolve.call(party)) if resolve.is_valid() else ""

## A clan roll member's label: the name, unless it is empty or only the handle the registry falls back to.
static func member(m: Dictionary) -> String:
	return label(str(m.get("handle", "")), str(m.get("name", "")))

## One market row (`UISlice.market_rows`) as its `ui.listing` line.
static func listing_line(r: Dictionary, own_name: String = "") -> String:
	return I18n.t("ui.listing", [r["id"], I18n.content("item", str(r["item_id"])), r["quantity"], I18n.number(r["price"], 2),
		label(str(r["seller"]), str(r.get("seller_name", "")), own_name, "market.unknown_seller")])

## One proposal row (`UISlice.proposal_rows`) as its `ui.proposal_line` line.
static func proposal_line(r: Dictionary, own_name: String = "") -> String:
	return I18n.t("ui.proposal_line", [r["id"], r["state"], r["title"], r["for"], r["against"],
		label(str(r["author"]), str(r.get("author_name", "")), own_name)])

## One trade row (`UISlice.trade_rows`) as its `trade.entry` line.
static func trade_line(r: Dictionary, own_name: String = "") -> String:
	return I18n.t("trade.entry", [label(str(r["party"]), str(r.get("party_name", "")), own_name),
		I18n.t("trade.side_give" if r["side"] == "give" else "trade.side_want"), I18n.content("item", str(r["item_id"])), r["quantity"]])
