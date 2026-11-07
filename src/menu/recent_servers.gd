extends RefCounted
## Phase 223 — the servers the main menu's Join screen remembers, most recent first.
##
## `user://recent_servers.json` is `{"servers": [{"address", "friend", "last"}]}`. It is read back as
## untrusted input: an entry whose address or friend code would not pass the Join form is dropped.

const PlayerRegistry := preload("res://src/persistence/player_registry.gd")

const DEFAULT_PATH := "user://recent_servers.json"
const MAX_ENTRIES := 8
const ADDRESS_MAX := 253

## A literal IP or a plain hostname: no scheme, path or whitespace (the `--client` rule, Phase 32).
static func valid_address(addr: String) -> bool:
	if addr.is_empty() or addr.length() > ADDRESS_MAX:
		return false
	if addr.contains("://") or addr.contains("/") or addr.contains(" ") or addr.contains("\t"):
		return false
	return RegEx.create_from_string("^[A-Za-z0-9][A-Za-z0-9.:-]*$").search(addr) != null

## "" (no friend) or a well-formed friend code.
static func valid_friend(code: String) -> bool:
	return code == "" or PlayerRegistry.is_valid_friend_code(code)

static func load_list(path: String = DEFAULT_PATH) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var json := JSON.new()   # not JSON.parse_string: a corrupt file is untrusted input, not an engine error
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return []
	var parsed: Variant = json.data
	if not (parsed is Dictionary) or not ((parsed as Dictionary).get("servers", null) is Array):
		return []
	var out: Array = []
	for e in (parsed as Dictionary)["servers"]:
		if not (e is Dictionary):
			continue
		var addr := str(e.get("address", "")).strip_edges()
		var friend := str(e.get("friend", "")).strip_edges()
		if not valid_address(addr) or not valid_friend(friend):
			continue
		out.append({ "address": addr, "friend": friend, "last": int(e.get("last", 0)) })
		if out.size() >= MAX_ENTRIES:
			break
	return out

## Put `address` (with `friend`) at the top of the list, dropping its older entry and the overflow.
static func remember(address: String, friend: String, path: String = DEFAULT_PATH, now: int = -1) -> Array:
	var list := load_list(path)
	if not valid_address(address) or not valid_friend(friend):
		return list
	var kept: Array = [{ "address": address, "friend": friend,
		"last": now if now >= 0 else int(Time.get_unix_time_from_system()) }]
	for e in list:
		if str(e["address"]) != address and kept.size() < MAX_ENTRIES:
			kept.append(e)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({ "servers": kept }))
		f.close()
	return kept
