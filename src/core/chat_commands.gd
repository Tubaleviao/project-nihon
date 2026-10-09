extends RefCounted
## Phase 63 — slash commands typed in chat. Pure and static: the UI asks, the answer is a string.
## Phase 85 — the admin command set. Parsing, spelling and argument validation live here (pure, so the
## suite pins them without a tree); `ChatSlice` owns the effects and decides who may run them.

const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")

const WHERE := "/where"

## Longest chat line accepted, in characters. The wire cap (`MAX_CLIENT_PACKET_BYTES`) is far above it.
const MAX_MESSAGE_CHARS := 240
## Largest coordinate a `/tp` may name: the planet wraps (`WorldPos.wrap_world`), so beyond it is a typo.
const MAX_TP_COORD := 1.0e9
## Largest quantity one `/give` may grant.
const MAX_GIVE_QUANTITY := 10000

## Commands any player may run / only admins may run. The one place the names are listed.
const PLAYER_COMMANDS := ["help", "players"]
const ADMIN_COMMANDS := ["say", "tp", "bring", "give", "kill"]

## One line of usage per command, for `/help`.
const USAGE := {
	"help":    "/help — list commands",
	"players": "/players — who is online",
	"where":   "/where — your position",
	"say":     "/say <message> — global announcement",
	"tp":      "/tp <x> <y> <z> | /tp <player> — teleport yourself",
	"bring":   "/bring <player> — teleport a player to you",
	"give":    "/give <item> [quantity] [player] — create items",
	"kill":    "/kill [player] — kill a player",
}

## True when `text` is a command this module answers.
static func is_command(text: String) -> bool:
	return _command_of(text) != ""

## The reply to `text` for a player standing at `world_pos`, or "" when it is not a command.
static func run(text: String, world_pos: Vector3) -> String:
	match _command_of(text):
		WHERE:
			return TerrainSlice.where_text(world_pos)
	return ""

## The command `text` names ("" when it names none): the one place the known commands are listed.
static func _command_of(text: String) -> String:
	var typed := text.strip_edges().to_lower()
	return typed if typed in [WHERE] else ""

## `text` with control characters dropped and the length capped; "" when nothing printable is left.
static func sanitize(text: String) -> String:
	var out := ""
	for i in text.length():
		var code := text.unicode_at(i)
		if code >= 32 and code != 127:
			out += text[i]
	return out.strip_edges().substr(0, MAX_MESSAGE_CHARS)

## True when `text` is typed as a slash command (known or not).
static func is_slash(text: String) -> bool:
	return text.strip_edges().begins_with("/")

## `{ name, args }` for a slash line: `name` lower-cased without the slash, `args` the whitespace-split
## rest. A line that is not a slash command parses to an empty name.
static func parse(text: String) -> Dictionary:
	var typed := text.strip_edges()
	if not typed.begins_with("/"):
		return { "name": "", "args": [] }
	var parts := typed.substr(1).split(" ", false)
	if parts.is_empty():
		return { "name": "", "args": [] }
	var args: Array = []
	for i in range(1, parts.size()):
		args.append(parts[i])
	return { "name": parts[0].to_lower(), "args": args }

static func is_admin_command(name: String) -> bool:
	return name in ADMIN_COMMANDS

static func is_known(name: String) -> bool:
	return name in PLAYER_COMMANDS or name in ADMIN_COMMANDS or ("/" + name) == WHERE

## The `/help` text for a caller; admins also see the admin set.
static func help_lines(admin: bool) -> Array:
	var lines: Array = []
	for name in PLAYER_COMMANDS:
		lines.append(USAGE[name])
	lines.append(USAGE["where"])
	if admin:
		for name in ADMIN_COMMANDS:
			lines.append(USAGE[name])
	return lines

## Three coordinates from `args[start..start+2]`: `{ ok, pos, error }`. Rejects non-numbers, NaN, inf and
## anything beyond `MAX_TP_COORD`.
static func parse_position(args: Array, start: int = 0) -> Dictionary:
	if args.size() < start + 3:
		return { "ok": false, "pos": Vector3.ZERO, "error": "need three numbers: x y z" }
	var v: Array = []
	for i in 3:
		var s := str(args[start + i])
		if not s.is_valid_float():
			return { "ok": false, "pos": Vector3.ZERO, "error": "'%s' is not a number" % s }
		var f := s.to_float()
		if is_nan(f) or is_inf(f) or absf(f) > MAX_TP_COORD:
			return { "ok": false, "pos": Vector3.ZERO, "error": "'%s' is out of range" % s }
		v.append(f)
	return { "ok": true, "pos": Vector3(v[0], v[1], v[2]), "error": "" }

## A `/give` quantity from `s`: a positive whole number up to `MAX_GIVE_QUANTITY`, else 0.
static func parse_quantity(s: String) -> int:
	if not s.is_valid_int():
		return 0
	var n := s.to_int()
	return n if n >= 1 and n <= MAX_GIVE_QUANTITY else 0

## The canonical id of the item `typed` names among `known_ids`, case-insensitively; "" when none does.
static func match_item(typed: String, known_ids: Array) -> String:
	var want := typed.to_lower()
	for id in known_ids:
		if str(id).to_lower() == want:
			return str(id)
	return ""
