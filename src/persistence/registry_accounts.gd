extends RefCounted
## Phase 226 — the host's accounts: who connects, as opposed to the character a session plays.
##
## Every slice keys its state on the session's player id, which IS the character id (see CharacterRoster). This
## is the PlayerRegistry's account half: which account a connection presented and which of its characters it
## enters (`resolve`), the character list it is sent (`roster_view`), and making and deleting characters. It
## reads and writes the registry it belongs to (`reg`), whose `roster` is the table of accounts.

const CharacterRoster := preload("res://src/character/character_roster.gd")
const CreationRules := preload("res://src/character/creation_rules.gd")
const Diag := preload("res://src/core/diag.gd")

var reg: Node = null
## peer_id -> the account that connection entered as.
var _peer_accounts: Dictionary = {}
## peer_id -> the character its join intent asked for (absent: the account's last).
var _peer_characters: Dictionary = {}

func _init(registry: Node) -> void:
	reg = registry

## Which character a join enters. The claim is an account; the character is the one the join intent asked for
## (`note_character_choice`), else the account's last. A claim the registry will not hand out (unknown, busy,
## a later character's id) mints a fresh account whose first character takes the same id, as a migrated save's
## does. Returns { player_id, account, reconnected }, or {} when the join asked for a character that is not the
## account's (`playCharacter`): it is refused with the list, and nothing is bound.
func resolve(peer_id: int, claimed_id: String) -> Dictionary:
	var wanted := str(_peer_characters.get(peer_id, ""))
	_peer_characters.erase(peer_id)
	var account := claimed_id if account_claimable(claimed_id) else ""
	var player_id := ""
	if account != "":
		if wanted != "" and reg.roster.account_of(wanted) != account:
			GameBus.character_roster_synced.emit(peer_id, roster_view(account, "play", "unknown", wanted))
			return {}
		player_id = wanted if wanted != "" else reg.roster.last_of(account)
		if player_id == "":
			# Every character was deleted: a join with no choice makes a fresh one.
			player_id = reg.mint_player_id()
			reg.roster.add_character(account, player_id)
		reg._ensure_record_loaded(player_id)
	else:
		if claimed_id != "":
			Diag.warn("PlayerRegistry: peer %d claimed unavailable id '%s' — minting a fresh identity" % [peer_id, claimed_id])
		account = reg.mint_player_id()
		player_id = account
		reg.roster.add_character(account, player_id)
	_peer_accounts[peer_id] = account
	reg.roster.note_played(player_id, int(Time.get_unix_time_from_system()))
	return { "player_id": player_id, "account": account, "reconnected": reg.has_player(player_id) }

## Remember which character a connection's join intent asked for ("" for its account's last). Consumed by the
## next `resolve` of that peer; a malformed id is dropped, so the join falls back to the last.
func note_character_choice(peer_id: int, character_id: String) -> void:
	if character_id != "" and reg.looks_like_player_id(character_id):
		_peer_characters[peer_id] = character_id
	else:
		_peer_characters.erase(peer_id)

func forget_peer(peer_id: int) -> void:
	_peer_accounts.erase(peer_id)
	_peer_characters.erase(peer_id)

## The account bound to a connection ("" when none).
func get_account(peer_id: int) -> String:
	return str(_peer_accounts.get(peer_id, ""))

## The account a character belongs to; a character no roster names (a test's bare record) is its own account.
func account_of(character_id: String) -> String:
	var account: String = reg.roster.account_of(character_id)
	return account if account != "" else character_id

## Whether a connection may enter as `account`: an account this server knows (a pre-Phase-226 player record is
## adopted as one, `migrateSave`: its id becomes the account's first character), not this machine's own
## player's, not merely a later character's id, and with none of its characters in the world right now.
func account_claimable(account: String) -> bool:
	if account == "" or account == reg.local_account or account == reg.local_player_id:
		return false
	if reg.roster.is_character(account) and reg.roster.account_of(account) != account:
		return false
	if not reg.roster.has_account(account):
		reg._ensure_record_loaded(account)
		if not reg.has_player(account):
			return false
		reg.roster.adopt_legacy(account)
	return not account_online(account)

## True when the account is this machine's own player's, or one of its characters holds a live connection.
func account_online(account: String) -> bool:
	if account == "":
		return false
	if account == reg.local_account:
		return true
	for character: String in reg.roster.characters_of(account):
		if reg.is_online(character):
			return true
	return false

## The character list the host sends a player (`listCharacters`): each character's name (its handle for one
## never named), look and last play, the account's last character, the limit, and the result of the action
## that asked for it. `reason` is "" on success, else a fabric refusal name (`CharacterRoster.refusal_key`).
func roster_view(account: String, op: String = "list", reason: String = "", id: String = "") -> Dictionary:
	var chars: Array = []
	for character: String in reg.roster.characters_of(account):
		var state := _creation_for_list(character)
		var created := CreationRules.is_created(state)
		chars.append({ "id": character, "name": str(state["name"]) if created else "", "handle": reg.public_handle(character),
			"look": CreationRules.look(state, "") if created else {}, "last_played": reg.roster.played_at(character), "created": created })
	return { "account": account, "characters": chars, "last": reg.roster.last_of(account), "limit": CharacterRoster.limit(),
		"result": { "op": op, "reason": CharacterRoster.refusal_key(reason) if reason != "" else "", "id": id } }

## A listed character's creation state: its resident record, else the one on disk, read WITHOUT making it
## resident (a list is not a join), else "none" (made on the list and never entered).
func _creation_for_list(character_id: String) -> Dictionary:
	if reg.has_player(character_id):
		return reg.creation_of(character_id)
	if reg._record_loader.is_valid():
		var data: Variant = reg._record_loader.call(character_id)
		if data is Dictionary:
			return CreationRules.sanitize_state((data as Dictionary).get("creation", {}))
	return CreationRules.sanitize_state({})

## Make a fresh character for `account` (`createCharacter`): { id } or { reason }. No record exists until it is
## entered, when it is placed like any new player; nothing is copied from the account's other characters.
func create_character(account: String) -> Dictionary:
	if not reg.is_authoritative or account == "" or not reg.roster.has_account(account):
		return { "reason": "unknown" }
	if reg.roster.count_of(account) >= CharacterRoster.limit():
		return { "reason": "limit" }
	var id: String = reg.mint_player_id()
	return { "id": id } if reg.roster.add_character(account, id) else { "reason": "limit" }

## Whether `confirm` (what the player typed) deletes `character_id` of `account`: "" or a refusal name. The text
## must be the character's name (its public handle for one never named); the host compares it, never the client.
func delete_refusal(account: String, character_id: String, confirm: String) -> String:
	if character_id == "" or reg.roster.account_of(character_id) != account:
		return "unknown"
	if reg.is_online(character_id):
		return "inPlay"
	var state := _creation_for_list(character_id)
	var name: String = str(state["name"]) if CreationRules.is_created(state) else reg.public_handle(character_id)
	return "" if confirm.strip_edges() == name else "confirm"

## The registry's half of deleting a character (after `delete_refusal` passed): it leaves the roster, its name is
## free again, its record leaves memory. The caller moves its clan and structures first and removes the file.
func drop_character(character_id: String) -> void:
	reg.roster.remove_character(character_id)
	if reg._names.has(character_id):
		var sk := CreationRules.skeleton(str(reg._names[character_id]))
		if str(reg._taken.get(sk, "")) == character_id:
			reg._taken.erase(sk)
		reg._names.erase(character_id)
	reg.evict_player(character_id)
