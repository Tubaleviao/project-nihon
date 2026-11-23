extends RefCounted
## Phase 226 — several characters per player. The fabric's `CharacterRoster` world system
## (fabric/gameplay/character_roster.js) splits the PLAYER (the account a client presents when it connects) from
## the CHARACTER (who walks the world). This is the host's table of which characters each account keeps.
##
## Every slice keeps keying its state on the session's player id, and that id IS the character id: a character's
## record, pack, skills, clan membership and owned structures are its own, so a new character starts from scratch
## and copies nothing from its siblings. The account is only who connects.
##
## Migration (`adopt_legacy`): a save from before Phase 226 has one record per player id. That id becomes the
## account AND its first character, so every world section keyed by it (names, clans, structures, chests) keeps
## resolving unchanged. Later characters get fresh ids. A fresh account's first character takes the account id
## too, so the rule is the same for every account.
##
## The table lives in the world record (`roster`) and is resident in full: an account claim must be checked
## against every character id (`account_of`), so one character's id can never be presented as an account.

const FALLBACK_LIMIT := 4
const FALLBACK_REFUSALS := {
	"limit": "characters.refuse.limit",
	"nameTaken": "creation.refuse.name_taken",
	"confirm": "characters.refuse.confirm",
	"unknown": "characters.refuse.unknown",
	"rateLimited": "characters.refuse.rate_limited",
}
## A runtime refusal the fabric's list does not name: the character (or its account) is in the world right now.
const IN_PLAY_REFUSAL := "characters.refuse.in_play"
## Most accounts a world record may restore (a hand-edited record cannot grow the table without bound).
const MAX_ACCOUNTS := 100000

## account -> { "characters": [character id, …] (oldest first), "last": character id, "played": { id: unix s } }
var _accounts: Dictionary = {}
## character id -> account
var _owner: Dictionary = {}

# ── fabric ───────────────────────────────────────────────────────────────

static func _fabric() -> Resource:
	return GameData.WORLD_SYSTEMS.get("CharacterRoster", null)

## Characters one player may keep on one server (`CharacterRoster.limit`).
static func limit() -> int:
	var res := _fabric()
	return int(res.limit) if res != null and int(res.limit) > 0 else FALLBACK_LIMIT

## The locale key the host refuses with for `reason` (`limit`, `nameTaken`, `confirm`, `unknown`, `rateLimited`).
static func refusal_key(reason: String) -> String:
	var res := _fabric()
	if res != null and (res.refusals as Dictionary).has(reason):
		return str(res.refusals[reason])
	return str(FALLBACK_REFUSALS.get(reason, IN_PLAY_REFUSAL if reason == "inPlay" else ""))

## What a deleted character's structures become: "clan" (its clan's, ownerless without one) or "ownerless".
static func on_delete() -> String:
	var res := _fabric()
	return str(res.onDelete) if res != null else "clan"

## Every locale key the host may send on the list (the catalog test holds each to `locale/ui.csv`).
static func refusal_keys() -> Array:
	var out: Array = []
	for reason: String in FALLBACK_REFUSALS:
		out.append(refusal_key(reason))
	out.append(IN_PLAY_REFUSAL)
	return out

# ── queries ──────────────────────────────────────────────────────────────

func has_account(account: String) -> bool:
	return _accounts.has(account)

## The account `character_id` belongs to, "" when it is no character on this server.
func account_of(character_id: String) -> String:
	return str(_owner.get(character_id, ""))

func is_character(character_id: String) -> bool:
	return _owner.has(character_id)

## The account's characters, oldest first.
func characters_of(account: String) -> Array:
	return (_accounts[account]["characters"] as Array).duplicate() if _accounts.has(account) else []

func count_of(account: String) -> int:
	return (_accounts[account]["characters"] as Array).size() if _accounts.has(account) else 0

## The character the account played last, else its oldest, else "".
func last_of(account: String) -> String:
	if not _accounts.has(account):
		return ""
	var a: Dictionary = _accounts[account]
	var chars: Array = a["characters"]
	if chars.has(str(a["last"])):
		return str(a["last"])
	return str(chars[0]) if not chars.is_empty() else ""

## Unix seconds the character was last entered, 0 for never.
func played_at(character_id: String) -> int:
	var account := account_of(character_id)
	return int((_accounts[account]["played"] as Dictionary).get(character_id, 0)) if account != "" else 0

func account_count() -> int:
	return _accounts.size()

# ── changes ──────────────────────────────────────────────────────────────

## Open an empty account. Idempotent. Past MAX_ACCOUNTS it still opens (a join is never refused for it) but warns:
## the next load keeps only MAX_ACCOUNTS.
func add_account(account: String) -> void:
	if account != "" and not _accounts.has(account):
		if _accounts.size() == MAX_ACCOUNTS:
			push_warning("CharacterRoster: more than %d accounts on this server" % MAX_ACCOUNTS)
		_accounts[account] = { "characters": [], "last": "", "played": {} }

## Give `account` the character `character_id`. False when the id already belongs to a character, or the account
## is at the limit (the caller refuses first; this is the last guard).
func add_character(account: String, character_id: String) -> bool:
	if account == "" or character_id == "" or _owner.has(character_id):
		return false
	add_account(account)
	var chars: Array = _accounts[account]["characters"]
	if chars.size() >= limit():
		return false
	chars.append(character_id)
	_owner[character_id] = account
	return true

## Drop the character from its account; returns the account ("" when it was none). The account stays, empty.
func remove_character(character_id: String) -> String:
	var account := account_of(character_id)
	if account == "":
		return ""
	var a: Dictionary = _accounts[account]
	(a["characters"] as Array).erase(character_id)
	(a["played"] as Dictionary).erase(character_id)
	if str(a["last"]) == character_id:
		a["last"] = ""
	_owner.erase(character_id)
	return account

## The character was entered now: it becomes its account's last, stamped `unix`.
func note_played(character_id: String, unix: int) -> void:
	var account := account_of(character_id)
	if account == "":
		return
	_accounts[account]["last"] = character_id
	_accounts[account]["played"][character_id] = unix

## A pre-Phase-226 player id (`migrateSave`): the id becomes an account whose first (and last) character is the
## id itself. A no-op (false) when it is already an account or already some account's character.
func adopt_legacy(player_id: String) -> bool:
	if player_id == "" or _accounts.has(player_id) or _owner.has(player_id):
		return false
	add_account(player_id)
	add_character(player_id, player_id)
	_accounts[player_id]["last"] = player_id
	return true

# ── record ───────────────────────────────────────────────────────────────

## The table as the world record stores it.
func to_data() -> Dictionary:
	return _accounts.duplicate(true)

## Restore the table from a world record. `valid_id` (`(id) -> bool`) screens every account and character id; a
## bad id, a character claimed twice, a list past the limit and an account past MAX_ACCOUNTS are dropped.
func from_data(raw: Variant, valid_id: Callable = Callable()) -> void:
	_accounts.clear()
	_owner.clear()
	if not (raw is Dictionary):
		return
	var accounts: Array = (raw as Dictionary).keys()
	accounts.sort()
	for account: Variant in accounts:
		if _accounts.size() >= MAX_ACCOUNTS:
			push_warning("CharacterRoster: the world record holds more than %d accounts; the rest were not loaded" % MAX_ACCOUNTS)
			break
		var a: Variant = raw[account]
		if not (account is String) or not (a is Dictionary) or not _ok(str(account), valid_id):
			continue
		add_account(account)
		var chars: Variant = (a as Dictionary).get("characters", [])
		if chars is Array:
			for c: Variant in chars:
				if c is String and _ok(c, valid_id):
					add_character(account, c)
		var played: Variant = (a as Dictionary).get("played", {})
		if played is Dictionary:
			for c: Variant in played:
				var at: Variant = played[c]
				if c is String and account_of(c) == account and (at is int or at is float) and float(at) >= 0.0:
					_accounts[account]["played"][c] = int(at)
		var last := str((a as Dictionary).get("last", ""))
		if account_of(last) == account:
			_accounts[account]["last"] = last

static func _ok(id: String, valid_id: Callable) -> bool:
	return id != "" and (not valid_id.is_valid() or bool(valid_id.call(id)))
