extends RefCounted
## Phase 63 — slash commands typed in chat. Pure and static: the UI asks, the answer is a string.
## Phase 85 — the admin command set. Parsing, spelling and argument validation live here (pure, so the
## suite pins them without a tree); `ChatSlice` owns the effects and decides who may run them.

const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const WorldPos := preload("res://src/terrain/world_pos.gd")
const I18n := preload("res://src/core/i18n.gd")
const GestureRules := preload("res://src/character/gesture_rules.gd")
const SeamWrap := preload("res://src/terrain/seam_wrap.gd")

const WHERE_NAME := "where"
const WHERE := "/" + WHERE_NAME
## Phase 159 — the gesture commands (`/sit`, `/wave`, ...) come from the fabric; /help lists them as one line.
const GESTURES_NAME := "gestures"
const GESTURES := "/" + GESTURES_NAME

## Longest chat line accepted, in characters. The wire cap (`MAX_CLIENT_PACKET_BYTES`) is far above it.
const MAX_MESSAGE_CHARS := 240
## Largest coordinate a `/tp` may name: the planet wraps (X is folded onto one lap in `parse_position`), so beyond it is a typo.
const MAX_TP_COORD := 1.0e9
## Largest quantity one `/give` may grant.
const MAX_GIVE_QUANTITY := 10000

## Commands any player may run / only admins may run. The one place the names are listed.
const PLAYER_COMMANDS := ["help", "players"]
const ADMIN_COMMANDS := ["say", "tp", "bring", "give", "kill", "weather", "time", "speed", "fly", "heal", "regen"]

## Catalog key of the one line of usage per command, for `/help` (see `locale/ui.csv`).
const USAGE := {
	"help":    "chat.usage.help",
	"players": "chat.usage.players",
	WHERE_NAME: "chat.usage.where",
	GESTURES_NAME: "chat.usage.gestures",
	"say":     "chat.usage.say",
	"tp":      "chat.usage.tp",
	"bring":   "chat.usage.bring",
	"give":    "chat.usage.give",
	"kill":    "chat.usage.kill",
	"weather": "chat.usage.weather",
	"time":    "chat.usage.time",
	"speed":   "chat.usage.speed",
	"fly":     "chat.usage.fly",
	"heal":    "chat.usage.heal",
	"regen":   "chat.usage.regen",
}

## True when `text` is a command this module answers.
static func is_command(text: String) -> bool:
	return _command_of(text) != ""

## The reply to `text` for a player standing at `world_pos`, or "" when it is not a command.
static func run(text: String, world_pos: Vector3) -> String:
	match _command_of(text):
		WHERE:
			return TerrainSlice.where_text(world_pos)
		GESTURES:
			# The commands themselves (`/sit, /wave`) are the answer, so no prose needs translating.
			var cmds: Array = []
			for word in GestureRules.commands(GameData.GESTURES):
				if word != "":
					cmds.append(word)   # the fabric stores it with its slash ("/sit")
			return ", ".join(cmds)
	return ""

## Phase 159 — the fabric gesture id a line like `/sit` starts ("" when it names none). Pure; the chat box
## turns it into a `gesture_intent`, so a gesture never travels as chat text.
static func gesture_id(text: String, table: Dictionary = GameData.GESTURES) -> String:
	return GestureRules.id_for_command(text, table) if is_slash(text) else ""

## The command `text` names ("" when it names none): the one place the known commands are listed.
static func _command_of(text: String) -> String:
	var typed := text.strip_edges().to_lower()
	return typed if typed in [WHERE, GESTURES] else ""

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
	return name in PLAYER_COMMANDS or name in ADMIN_COMMANDS or name == WHERE_NAME or name == GESTURES_NAME

## The `/help` usage keys for a caller; admins also see the admin set.
static func help_lines(admin: bool) -> Array:
	var lines: Array = []
	for name in PLAYER_COMMANDS:
		lines.append(USAGE[name])
	lines.append(USAGE[WHERE_NAME])
	lines.append(USAGE[GESTURES_NAME])
	if admin:
		for name in ADMIN_COMMANDS:
			lines.append(USAGE[name])
	return lines

## Three coordinates from `args[start..start+2]`: `{ ok, pos, world, error }`. Rejects non-numbers, NaN,
## inf, anything beyond `MAX_TP_COORD`, a Y past the wire's local limit (`WorldPos.LOCAL_LIMIT`) and a Z past the poles; X is wrapped onto one lap of the planet.
## `pos` is the exact `{chunk, local}` record, built from the doubles typed — never through a `Vector3`,
## whose float32 X loses metres a million chunks out. `world` is the wrapped `[x, y, z]` for display.
static func parse_position(args: Array, start: int = 0) -> Dictionary:
	var fail := func(key: String, msg_args: Array = []) -> Dictionary:
		return { "ok": false, "pos": {}, "world": [], "error": I18n.msg(key, msg_args) }
	if args.size() < start + 3:
		return fail.call("chat.err.need_three")
	var v: Array = []
	for i in 3:
		var s := str(args[start + i])
		if not s.is_valid_float():
			return fail.call("chat.err.not_number", [s])
		var f := s.to_float()
		if is_nan(f) or is_inf(f) or absf(f) > MAX_TP_COORD:
			return fail.call("chat.err.out_of_range", [s])
		v.append(f)
	if absf(v[1]) > WorldPos.LOCAL_LIMIT:
		return fail.call("chat.err.y_limit", [int(WorldPos.LOCAL_LIMIT)])
	var pole_m := float(TerrainSlice.pole_chunks()) * TerrainSlice.CHUNK_METERS
	if absf(v[2]) > pole_m:
		return fail.call("chat.err.z_limit", [int(pole_m)])
	var lap := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	var x: float = SeamWrap.wrap_f(float(v[0]), lap)
	var z: float = v[2]
	var pos := WorldPos.from_world(x, v[1], z)
	return { "ok": true, "pos": pos, "world": [x, v[1], z], "error": {} }

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
