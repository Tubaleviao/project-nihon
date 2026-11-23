extends "res://src/core/wiring.gd"
## Phase 226 — several characters per player at runtime: the host's character list and the list's screen.
##
## Host / offline: `character_roster_intent` (this machine's own player's, peer 0, or a peer's forwarded by
## networking) is resolved here: `list`, `create` (a fresh character on the account, refused over the limit) and
## `delete` (the typed name checked by the host; the character leaves its clan, its structures, chests and doors
## go to that clan or become ownerless, its name is free again, its record is removed). The answer is
## `character_roster_synced` (peer 0: this machine's screen; any other peer: networking sends it).
## Every machine with a UI: the character list screen (`CharacterListPanel`) shows the host's last list and
## sends the player's actions; Play emits `character_chosen`, which a listen host's boot or a client's join takes.

const CharacterRoster := preload("res://src/character/character_roster.gd")
const RosterView := preload("res://src/character/roster_view.gd")
const CharacterListPanel := preload("res://src/ui/character_list_panel.gd")

## Shortest gap between two list actions of one connection (the host's rate limit).
const RATE_LIMIT_MSEC := 250
## Most connections the rate table remembers before it is cleared (a flood of fresh peers cannot grow it).
const MAX_RATE_ENTRIES := 4096

## This boot came from the main menu, so the player picks a character from the host's list before entering: a
## listen host before its local player is bound (`local_pending`), a client before its join intent
## (`NetworkingSlice.awaiting_character`). CLI, harness and test boots enter as the account's last character.
var pick: bool = false
## The listen host's world is loaded and waits for the local player's choice.
var local_pending: bool = false

## peer -> msec of its last list action.
var _last_action: Dictionary = {}
## List actions refused by the rate limit since boot.
var rate_limited: int = 0
## The screen, while it is open.
var panel: Control = null
var _layer: CanvasLayer = null
## Test seam: msec now.
var now_msec: Callable = func() -> int: return Time.get_ticks_msec()

func _connect_all() -> void:
	connect_bus(GameBus.character_roster_intent, _on_roster_intent)
	connect_bus(GameBus.character_roster_synced, _on_roster_synced)
	connect_bus(GameBus.character_chosen, _on_character_chosen)
	connect_bus(GameBus.peer_disconnected, _on_peer_disconnected)

func _on_peer_disconnected(peer_id: int) -> void:
	_last_action.erase(peer_id)

# ── host ─────────────────────────────────────────────────────────────────

## Host: one list action from this machine's own player (peer 0) or a remote peer.
func _on_roster_intent(op: String, args: Dictionary, peer_id: int) -> void:
	if root._is_client:
		if peer_id == 0 and root._networking != null:
			root._networking._m3.send_roster_intent(op, str(args.get("id", "")), str(args.get("confirm", "")))
		return
	GameBus.character_roster_synced.emit(peer_id, resolve(op, args, peer_id))

## Host: the list after `op`, with its result. Pure over the registry and the slices it hands a character's
## belongings to; the caller sends it.
func resolve(op: String, args: Dictionary, peer_id: int) -> Dictionary:
	var reg = root._registry
	# The rate limit first: an unbound connection's claim may read a record off disk.
	if peer_id != 0 and _too_soon(peer_id):
		return reg.accounts.roster_view("", op, "rateLimited")
	var claimed := str(args.get("claimed_id", ""))
	var account := _account_for(peer_id, claimed)
	if account == "":
		# An account in the world on another connection is said so, never shown as missing: New or Play would
		# mint a fresh account the client then caches over its real one.
		if claimed != "" and reg.roster.has_account(claimed) and reg.accounts.account_online(claimed):
			return reg.accounts.roster_view("", op, "inPlay")
		# An unknown account sees an empty list; a join without a choice makes it a fresh one.
		return reg.accounts.roster_view("", op, "unknown" if op != "list" else "")
	match op:
		"list":
			return reg.accounts.roster_view(account, op)
		"create":
			var made: Dictionary = reg.accounts.create_character(account)
			return reg.accounts.roster_view(account, op, str(made.get("reason", "")), str(made.get("id", "")))
		"delete":
			var id := str(args.get("id", ""))
			var reason: String = reg.accounts.delete_refusal(account, id, str(args.get("confirm", "")))
			if reason == "":
				delete_character(id)
			return reg.accounts.roster_view(account, op, reason, id)
	return reg.accounts.roster_view(account, op, "unknown")

## The account a list action speaks for: this machine's own player's (peer 0); a bound connection's own; an
## unbound connection's claim when the registry lets it be claimed (`account_claimable`), else "".
func _account_for(peer_id: int, claimed: String) -> String:
	var reg = root._registry
	if peer_id == 0:
		return reg.local_account
	var bound: String = reg.accounts.get_account(peer_id)
	if bound != "":
		return bound
	return claimed if reg.accounts.account_claimable(claimed) else ""

func _too_soon(peer_id: int) -> bool:
	var now := int(now_msec.call())
	var last := int(_last_action.get(peer_id, -RATE_LIMIT_MSEC))
	if now - last < RATE_LIMIT_MSEC:
		rate_limited += 1
		return true
	if _last_action.size() >= MAX_RATE_ENTRIES:
		_last_action.clear()
	_last_action[peer_id] = now
	return false

## Host: delete a character (`deleteCharacter`, after `PlayerRegistry.delete_refusal` passed). Its clan is read
## first: its structures, chests and doors go to that clan (`onDelete` "clan"), or become ownerless (also when
## it founded the clan alone, which disbands with it). Its companions go wild and it leaves any settlement. The
## world is saved at once, so the removed record file and the roster never disagree on disk.
func delete_character(id: String) -> void:
	var clan := ""
	if root._clans != null and CharacterRoster.on_delete() == "clan":
		clan = str(root._clans.clan_of(id))
	if root._clans != null:
		root._clans.drop_character(id)
		if clan != "" and root._clans.get_clan(clan).is_empty():
			clan = ""
	if root._creature != null:
		root._creature.release_tamed_by(id)
	if root._settlements != null:
		root._settlements.leave(id)   # a founder stays one: settlements are legacy, migrated to clans
	if root._structures != null:
		root._structures.release_owner(id, clan)
	if root._chests != null:
		root._chests.release_owner(id, clan)
	root._registry.accounts.drop_character(id)
	if root._persistence != null:
		root._persistence.delete_player(id)
	if root._voxel != null and root._persistence_wiring != null:
		root._persistence_wiring.save_everything(true)

# ── the screen ───────────────────────────────────────────────────────────

## Listen host, after the world loaded: when it waits for the local player's choice, open the list (true).
func open_local() -> bool:
	if not local_pending:
		return false
	open()
	GameBus.character_roster_intent.emit("list", {}, 0)
	return true

## Client: a menu join waits for the choice before its join intent; the list is asked for by the handshake.
func open_client() -> void:
	root._networking.awaiting_character = pick
	if pick:
		open()

## The menu's character list chose the local player's character: bind it and load its record, then the host
## boot places it.
func enter_local(character_id: String) -> void:
	if not local_pending:
		return
	local_pending = false
	root._persistence_wiring.bind_chosen_local_character(character_id)
	root._boot_host_as_character()

func open() -> void:
	if root._ui == null and root._is_server:
		return
	if panel != null:
		panel.visible = true
		return
	_layer = CanvasLayer.new()
	_layer.name = "CharacterList"
	_layer.layer = 45
	root.add_child(_layer)
	panel = CharacterListPanel.new()
	if root._character != null and root._character.has_method("palette_color"):
		panel.palette = root._character.palette_color
	panel.play_requested.connect(func(id: String) -> void: GameBus.character_chosen.emit(id))
	panel.create_requested.connect(func() -> void: _ask("create"))
	panel.delete_requested.connect(func(id: String, confirm: String) -> void: _ask("delete", id, confirm))
	panel.back_requested.connect(_back_to_menu)
	_layer.add_child(panel)

func _ask(op: String, id: String = "", confirm: String = "") -> void:
	GameBus.character_roster_intent.emit(op, { "id": id, "confirm": confirm }, 0)

func close() -> void:
	if _layer != null:
		_layer.queue_free()
	_layer = null
	panel = null

## This machine's own list arrived (peer 0): show it. A new character the host just made is entered at once.
func _on_roster_synced(peer_id: int, roster: Dictionary) -> void:
	if peer_id != 0:
		return
	var view := RosterView.sanitize(roster)
	if panel == null:
		# A client's join was refused (the character it chose is gone): back to the list, no join intent out.
		if not root._is_client or str(view["result"]["op"]) != "play" or str(view["result"]["reason"]) == "":
			return
		root._networking.awaiting_character = true
		root._networking.chosen_character = ""
		open()
	panel.set_view(view)
	var result: Dictionary = view["result"]
	if str(result["op"]) == "create" and str(result["reason"]) == "" and str(result["id"]) != "":
		GameBus.character_chosen.emit(str(result["id"]))

## The player picked a character: a listen host binds it and finishes its boot, a client joins with it. A client
## with no account yet joins with no choice, and the host makes its first character.
func _on_character_chosen(character_id: String) -> void:
	if panel == null:
		return
	if root._is_client:
		close()
		root._networking._m3.choose_character(character_id)
	elif local_pending and (character_id == "" or root._registry.roster.account_of(character_id) == root._registry.local_account):
		close()
		enter_local(character_id)

func _back_to_menu() -> void:
	close()
	GameBus.exit_to_menu_requested.emit()
