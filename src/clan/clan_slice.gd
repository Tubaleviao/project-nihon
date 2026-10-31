extends Node
## Clan slice (Phase 204, designed in Phase 203) — a name a player chose, invites, roles, one clan per player,
## and every member's skills in view of the clan's own peers.
##
## A clan has no hearth and claims no land: its settlements are where its buildings stand (Phase 205). The host
## decides everything; clients mirror a view (`apply_view`). Rules come from the fabric's `Clan` world system
## (`GameData.WORLD_SYSTEMS["Clan"].rules`).
##
## Plug contract (GameBus):
##   IN  : clan_intent(action, args, player_id)
##   OUT : clan_resolved(player_id, action, ok, reason), clans_changed()
##
## Public API (all host-side; a client calls none of them):
##   found(player, name) / invite(actor, target) / uninvite(actor, target) / join(player, id) / decline(player, id)
##   leave(player) / kick(actor, target) / set_role(actor, target, role)      "" when done, else a reason code
##   clan_of(player_id) -> String / role_of(player_id) -> String / may(player_id, permission) -> bool
##   private_view(player_id)        what one player may see: their own clan's roster with skills, and invites
##   migrate_settlements(data)      a saved world's settlements become clans (Clan.migration)
##   tick(now)                      lapse old invites

const I18n := preload("res://src/core/i18n.gd")
const CreationRules := preload("res://src/character/creation_rules.gd")
const SkillTiers := preload("res://src/core/skill_tiers.gd")

const DAY_SEC := 86400.0
const INTENT_INTERVAL := 0.25
## `_last_intent` entries are swept once it holds more than this many players.
const MAX_INTENT_ENTRIES := 256
## Host memory bounds. The fabric sets no member limit (`maxMembers` 0); these keep a hand-edited save or a
## flood of founders from growing the record without end.
const MAX_CLANS := 4096
const MAX_MEMBERS := 512
## Skills sent per member in the roster (the 22 fabric skills plus room for more).
const MAX_ROSTER_SKILLS := 48
## A skill change re-sends a clan's roster at most this often (an XP grant fires on every harvest swing).
const SKILL_PUSH_SEC := 5.0
## The clan record's format: 1 is the first (Phase 204).
const DATA_FORMAT := 1
const ACTIONS := ["found", "invite", "uninvite", "join", "decline", "leave", "kick", "role"]
## Roles from most to least trusted: an actor acts only on a member ranked below them.
const ROLE_ORDER := ["founder", "elder", "member", "guest"]
## Name refusals come from `CreationRules.name_refusal` with the clan's bounds.
const NAME_REASONS := ["name_length", "name_chars", "name_script", "name_separator", "name_reserved", "name_taken"]

## Every refusal code an action can return.
const REASONS := ["unknown_player", "rate_limited", "bad_args", "already_member", "too_many", "not_member",
	"no_permission", "unknown_clan", "not_invited", "full", "bad_role", "founder_locked", "no_such_invite",
	"unknown_action", "outranked", "self"] + NAME_REASONS

const DEFAULT_RULES := {
	"name": { "minLength": 3, "maxLength": 24, "maxSeparators": 3, "reserved": [] },
	"maxClansPerPlayer": 1, "maxMembers": 0, "founderRole": "founder",
	"roles": {
		"founder": { "invite": true, "kick": true, "setRole": true, "dismantleClanStructures": true },
		"elder": { "invite": true, "kick": true, "setRole": false, "dismantleClanStructures": true },
		"member": { "invite": false, "kick": false, "setRole": false, "dismantleClanStructures": true },
		"guest": { "invite": false, "kick": false, "setRole": false, "dismantleClanStructures": false },
	},
	"invites": { "ttlDays": 7, "maxPendingPerClan": 32 },
	"messages": { "maxLength": 280, "perMinute": 10 },
}

## Set by the wiring.
var registry: Node = null
var now_sec: Callable = func() -> float: return Time.get_unix_time_from_system()
## Monotonic seconds for the intent rate limit (a wall-clock jump must not lock or free a player).
var mono_sec: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0
var is_host: bool = true

## id -> { id, name, name_n, founder, members {pid: role}, invites {pid: unix time}, created, settlement }
## `name_n` > 0 is a migrated settlement's numbered default name (clients render it in their own locale);
## `settlement` is the id of the settlement a clan was migrated from ("" for a clan founded as one).
var _clans: Dictionary = {}
## pid -> clan id, rebuilt from `_clans` (one clan per player).
var _member_of: Dictionary = {}
## name skeleton -> clan id, for uniqueness.
var _taken: Dictionary = {}
var _next_id: int = 1
var _last_intent: Dictionary = {}
## Clan ids and player ids whose views changed since the wiring last pushed them.
var _dirty_clans: Dictionary = {}
var _dirty_players: Dictionary = {}
## Clan ids whose members' skills changed, held until `SKILL_PUSH_SEC` after that clan's last skill push.
var _skill_dirty: Dictionary = {}
var _skill_pushed: Dictionary = {}
## Client view: what the host last sent.
var _view: Dictionary = {}

func _ready() -> void:
	GameBus.clan_intent.connect(_on_intent)
	GameBus.player_left.connect(forget_player)

func forget_player(player_id: String) -> void:
	_last_intent.erase(player_id)

# ── rules ────────────────────────────────────────────────────────────────

static var _rules_cache: Dictionary = {}
static var _rules_source: Resource = null

## The merged rule table, built once per fabric resource. Callers must not mutate it.
func rules() -> Dictionary:
	return shared_rules()

## `rules()` for code without a slice (the chat's `/msg` limits read `messages` here).
static func shared_rules() -> Dictionary:
	var src: Resource = GameData.WORLD_SYSTEMS.get("Clan", null)
	if src == _rules_source and not _rules_cache.is_empty():
		return _rules_cache
	var out := DEFAULT_RULES.duplicate(true)
	var fab: Variant = src.get("rules") if src != null else null
	if fab is Dictionary:
		for k: String in out:
			if (fab as Dictionary).has(k) and typeof(fab[k]) == typeof(out[k]):
				out[k] = (fab[k] as Variant).duplicate(true) if fab[k] is Dictionary else fab[k]
	_rules_source = src
	_rules_cache = out
	return out

func role_rules(role: String) -> Dictionary:
	return (rules()["roles"] as Dictionary).get(role, {})

func founder_role() -> String:
	return str(rules()["founderRole"])

func _invite_ttl() -> float:
	return float((rules()["invites"] as Dictionary).get("ttlDays", 7)) * DAY_SEC

func _member_cap() -> int:
	var n := int(rules()["maxMembers"])
	return MAX_MEMBERS if n <= 0 else mini(n, MAX_MEMBERS)

## The name rule's bounds for `CreationRules.name_refusal`.
func _name_limits() -> Dictionary:
	var n: Dictionary = rules()["name"]
	return { "minLength": int(n.get("minLength", 3)), "maxLength": int(n.get("maxLength", 24)),
		"maxSeparators": int(n.get("maxSeparators", 3)), "reserved": n.get("reserved", []) }

## Why `raw` cannot be a new clan's name ("" when it can): the character-name rules with the clan's bounds,
## and unique by skeleton among clans.
func name_refusal(raw: String) -> String:
	return CreationRules.name_refusal(raw, _taken, _name_limits())

# ── queries ──────────────────────────────────────────────────────────────

func ids() -> Array:
	var out: Array = _clans.keys()
	out.sort()
	return out

func count() -> int:
	return _clans.size()

func get_clan(id: String) -> Dictionary:
	return _clans.get(id, {})

func clan_of(player_id: String) -> String:
	return str(_member_of.get(_pid(player_id), ""))

func role_of(player_id: String) -> String:
	var id := clan_of(player_id)
	return str(_clans[id]["members"].get(_pid(player_id), "")) if id != "" else ""

## Whether `player_id`'s role in their clan grants `permission` (invite, kick, setRole, dismantleClanStructures).
func may(player_id: String, permission: String) -> bool:
	return bool(role_rules(role_of(player_id)).get(permission, false))

## Whether two players are in the same clan.
func same_clan(a: String, b: String) -> bool:
	var id := clan_of(a)
	return id != "" and id == clan_of(b)

func _pid(player_id: String) -> String:
	if player_id == "" and registry != null and "local_player_id" in registry:
		return str(registry.local_player_id)
	return player_id

static func _rank(role: String) -> int:
	var i := ROLE_ORDER.find(role)
	return i if i >= 0 else ROLE_ORDER.size()

func _changed(id: String) -> void:
	_dirty_clans[id] = true
	GameBus.clans_changed.emit()

func _player_changed(pid: String) -> void:
	_dirty_players[pid] = true
	GameBus.clans_changed.emit()

## The players whose views must be pushed again, and forget the marks. Every member of a changed clan, every
## player marked on their own (an invitee, someone who just left).
func take_dirty() -> Array:
	var now := float(mono_sec.call())
	for id: String in _skill_dirty.keys():
		if now - float(_skill_pushed.get(id, -1.0e12)) >= SKILL_PUSH_SEC:
			_skill_dirty.erase(id)
			_skill_pushed[id] = now
			_dirty_clans[id] = true
	var out := {}
	for id: String in _dirty_clans:
		if _clans.has(id):
			for m: String in (_clans[id]["members"] as Dictionary):
				out[m] = true
			for p: String in (_clans[id]["invites"] as Dictionary):
				out[p] = true
	for p: String in _dirty_players:
		out[p] = true
	_dirty_clans.clear()
	_dirty_players.clear()
	return out.keys()

## A member's skill record changed on the host: their clan's roster is pushed again, at most once per
## `SKILL_PUSH_SEC` per clan.
func note_skills_changed(player_id: String) -> void:
	var id := clan_of(player_id)
	if id != "":
		_skill_dirty[id] = true

## A member came online or went offline: their clan's rosters show it on the next push.
func note_presence_changed(player_id: String) -> void:
	var id := clan_of(player_id)
	if id != "":
		_dirty_clans[id] = true

## A player opened a session (a reconnect included): they need their own view again.
func note_session(player_id: String) -> void:
	_dirty_players[player_id] = true
	note_presence_changed(player_id)

# ── membership ───────────────────────────────────────────────────────────

func found(player_id: String, cname: String) -> String:
	var pid := _pid(player_id)
	if pid == "":
		return "unknown_player"
	if clan_of(pid) != "":
		return "already_member"
	if _clans.size() >= MAX_CLANS:
		return "too_many"
	cname = CreationRules.normalize_name(cname.left(64))
	var why := name_refusal(cname)
	if why != "":
		return why
	var id := "clan_%d" % _next_id
	_next_id += 1
	_add_clan(id, { "id": id, "name": cname, "name_n": 0, "founder": pid, "members": { pid: founder_role() },
		"invites": {}, "created": float(now_sec.call()), "settlement": "" })
	# Invites to other clans lapse with the founding: a player belongs to at most one.
	_drop_invites_of(pid)
	_changed(id)
	return ""

func _add_clan(id: String, c: Dictionary) -> void:
	_clans[id] = c
	for m: String in (c["members"] as Dictionary):
		_member_of[m] = id
	if str(c["name"]) != "":
		_taken[CreationRules.skeleton(str(c["name"]))] = id

func _drop_invites_of(pid: String) -> void:
	for id: String in _clans:
		if (_clans[id]["invites"] as Dictionary).erase(pid):
			_dirty_clans[id] = true

## A target typed by a player: a member or invitee of clan `id` by id or handle (online or not), else a player
## id, else the handle of a player who is here. "" stays "": it never means the local player.
func _resolve_target(target: String, id: String = "") -> String:
	target = target.strip_edges().left(64)
	if target == "":
		return ""
	if _clans.has(id):
		var c: Dictionary = _clans[id]
		for p: String in (c["members"] as Dictionary).keys() + (c["invites"] as Dictionary).keys():
			if p == target or _handle(p) == target:
				return p
	if registry == null:
		return target
	if registry.has_method("has_player") and registry.has_player(target):
		return target
	if registry.has_method("player_id_for_handle"):
		var by_handle := str(registry.player_id_for_handle(target))
		if by_handle != "":
			return by_handle
	return target

func invite(actor: String, target: String) -> String:
	var pid := _pid(actor)
	var id := clan_of(pid)
	if id == "":
		return "not_member"
	if not may(pid, "invite"):
		return "no_permission"
	target = _resolve_target(target)
	if target == "":
		return "bad_args"
	if target == pid:
		return "self"
	if registry != null and registry.has_method("has_player") and not registry.has_player(target):
		return "unknown_player"
	if clan_of(target) != "":
		return "already_member"
	var c: Dictionary = _clans[id]
	_lapse_invites(c, float(now_sec.call()))
	var invites: Dictionary = c["invites"]
	if not invites.has(target) and invites.size() >= int((rules()["invites"] as Dictionary).get("maxPendingPerClan", 32)):
		return "full"
	if (c["members"] as Dictionary).size() >= _member_cap():
		return "full"
	invites[target] = float(now_sec.call())
	_changed(id)
	return ""

func uninvite(actor: String, target: String) -> String:
	var pid := _pid(actor)
	var id := clan_of(pid)
	if id == "":
		return "not_member"
	if not may(pid, "invite"):
		return "no_permission"
	target = _resolve_target(target, id)
	if target == "":
		return "bad_args"
	if not (_clans[id]["invites"] as Dictionary).erase(target):
		return "no_such_invite"
	_dirty_players[target] = true
	_changed(id)
	return ""

## Drop the invites of `c` older than the invite lifetime. True when one lapsed.
func _lapse_invites(c: Dictionary, now: float) -> bool:
	var inv: Dictionary = c["invites"]
	var lapsed := false
	for p: String in inv.keys():
		if now - float(inv[p]) >= _invite_ttl():
			inv.erase(p)
			_dirty_players[p] = true
			lapsed = true
	return lapsed

## A player accepts an invite and joins as a `member`. Refused while they are in a clan.
func join(player_id: String, id: String) -> String:
	var pid := _pid(player_id)
	if pid == "":
		return "unknown_player"
	if not _clans.has(id):
		return "unknown_clan"
	if clan_of(pid) != "":
		return "already_member"
	var c: Dictionary = _clans[id]
	if _lapse_invites(c, float(now_sec.call())):
		_changed(id)
	if not (c["invites"] as Dictionary).has(pid):
		return "not_invited"
	if (c["members"] as Dictionary).size() >= _member_cap():
		return "full"
	(c["invites"] as Dictionary).erase(pid)
	c["members"][pid] = "member"
	_member_of[pid] = id
	_drop_invites_of(pid)
	_changed(id)
	return ""

## A player turns an invite down.
func decline(player_id: String, id: String) -> String:
	var pid := _pid(player_id)
	if not _clans.has(id):
		return "unknown_clan"
	if not (_clans[id]["invites"] as Dictionary).erase(pid):
		return "no_such_invite"
	_dirty_players[pid] = true
	_changed(id)
	return ""

## Leave the clan. The founder may leave only as its last member, which disbands it.
func leave(player_id: String) -> String:
	var pid := _pid(player_id)
	var id := clan_of(pid)
	if id == "":
		return "not_member"
	var c: Dictionary = _clans[id]
	if pid == str(c["founder"]):
		if (c["members"] as Dictionary).size() > 1:
			return "founder_locked"
		_disband(id)
		_player_changed(pid)
		return ""
	_remove_member(id, pid)
	return ""

func _remove_member(id: String, pid: String) -> void:
	(_clans[id]["members"] as Dictionary).erase(pid)
	_member_of.erase(pid)
	_dirty_players[pid] = true   # their next view has no roster: they stop receiving the others' skills
	_changed(id)

func _disband(id: String) -> void:
	var c: Dictionary = _clans[id]
	for m: String in (c["members"] as Dictionary):
		_member_of.erase(m)
		_dirty_players[m] = true
	for p: String in (c["invites"] as Dictionary):
		_dirty_players[p] = true
	if str(c["name"]) != "" and str(_taken.get(CreationRules.skeleton(str(c["name"])), "")) == id:
		_taken.erase(CreationRules.skeleton(str(c["name"])))
	_clans.erase(id)
	_skill_dirty.erase(id)
	_skill_pushed.erase(id)

## Remove `target` from the actor's clan. The founder is never kicked, and an actor kicks only members ranked
## below them (an elder cannot kick an elder).
func kick(actor: String, target: String) -> String:
	var pid := _pid(actor)
	var id := clan_of(pid)
	if id == "":
		return "not_member"
	if not may(pid, "kick"):
		return "no_permission"
	target = _resolve_target(target, id)
	if target == "":
		return "bad_args"
	if target == pid:
		return "self"
	if clan_of(target) != id:
		return "not_member"
	if target == str(_clans[id]["founder"]):
		return "founder_locked"
	if _rank(role_of(target)) <= _rank(role_of(pid)):
		return "outranked"
	_remove_member(id, target)
	return ""

## Change `target`'s role. Only a role with `setRole` may, the founder role is never given or taken, and as with
## a kick an actor changes only a member ranked below them, to a role ranked below their own.
func set_role(actor: String, target: String, role: String) -> String:
	var pid := _pid(actor)
	var id := clan_of(pid)
	if id == "":
		return "not_member"
	if not role_rules(role).size() or role == founder_role():
		return "bad_role"
	if not may(pid, "setRole"):
		return "no_permission"
	target = _resolve_target(target, id)
	if target == "":
		return "bad_args"
	if target == pid:
		return "self"
	if clan_of(target) != id:
		return "not_member"
	if target == str(_clans[id]["founder"]):
		return "founder_locked"
	var own := _rank(role_of(pid))
	if _rank(role_of(target)) <= own or _rank(role) <= own:
		return "outranked"
	_clans[id]["members"][target] = role
	_changed(id)
	return ""

## Lapse old invites as of `now`. Returns true when anything changed.
func tick(now: float) -> bool:
	var changed := false
	for id: String in ids():
		if _lapse_invites(_clans[id], now):
			_dirty_clans[id] = true
			changed = true
	if changed:
		GameBus.clans_changed.emit()
	return changed

# ── intents ──────────────────────────────────────────────────────────────

func _on_intent(action: String, args: Dictionary, player_id: String) -> void:
	if not is_host:
		return
	var pid := _pid(player_id)
	var reason := _resolve(action, args, pid)
	GameBus.clan_resolved.emit(pid, action, reason == "", reason)

func _resolve(action: String, args: Dictionary, pid: String) -> String:
	if pid == "":
		return "unknown_player"
	var now := float(mono_sec.call())
	if now - float(_last_intent.get(pid, -1.0e12)) < INTENT_INTERVAL:
		return "rate_limited"
	_last_intent[pid] = now
	if _last_intent.size() > MAX_INTENT_ENTRIES:
		for k: String in _last_intent.keys():
			if now - float(_last_intent[k]) >= INTENT_INTERVAL:
				_last_intent.erase(k)
	match action:
		"found":
			return found(pid, _arg(args, "name"))
		"invite":
			return invite(pid, _arg(args, "target"))
		"uninvite":
			return uninvite(pid, _arg(args, "target"))
		"join":
			return join(pid, _arg(args, "id"))
		"decline":
			return decline(pid, _arg(args, "id"))
		"leave":
			return leave(pid)
		"kick":
			return kick(pid, _arg(args, "target"))
		"role":
			return set_role(pid, _arg(args, "target"), _arg(args, "role").left(16))
	return "unknown_action"

static func _arg(args: Dictionary, key: String) -> String:
	var v: Variant = args.get(key, "")
	return str(v).left(64) if v is String else ""

# ── migration (Clan.migration) ───────────────────────────────────────────

## Turn a saved world's settlements (`SettlementSlice.to_data()` shape) into clans with the same name, members
## and roles, for a world record written before clans existed. A player already in a clan, or in two
## settlements of a hand-edited record, keeps the first. A name another clan already holds (settlement names
## were never unique) gets a number. The hearth and stockpile stay with the settlement until Phases 205 and
## 208 remove them. Returns how many clans were made.
func migrate_settlements(data: Variant) -> int:
	if not (data is Dictionary) or not ((data as Dictionary).get("settlements", null) is Dictionary):
		return 0
	var raw: Dictionary = data["settlements"]
	var sids: Array = raw.keys()
	sids.sort_custom(func(a: Variant, b: Variant) -> bool: return _settlement_order(str(a)) < _settlement_order(str(b)))
	var made := 0
	for sid: Variant in sids:
		var s: Variant = raw[sid]
		if _clans.size() >= MAX_CLANS or not (s is Dictionary) or not (s.get("members", null) is Dictionary):
			continue
		var members := {}
		for p: Variant in (s["members"] as Dictionary):
			var who := str(p).left(64)
			var role := str(s["members"][p])
			if who != "" and clan_of(who) == "" and members.size() < _member_cap():
				members[who] = role if role_rules(role).size() > 0 else "guest"
		var founder := str(s.get("founder", "")).left(64)
		if not members.has(founder):
			continue   # the founder joined another clan first: this settlement has no one to lead it
		members[founder] = founder_role()
		var name_n := clampi(int(s.get("name_n", 0)), 0, 1000000)
		var cname := "" if name_n > 0 else _unique_name(str(s.get("name", "")).strip_edges().left(64))
		if cname == "" and name_n == 0:
			continue
		var invites := {}
		if s.get("invites", null) is Dictionary:
			for p: Variant in (s["invites"] as Dictionary):
				var at: Variant = s["invites"][p]
				if invites.size() < int((rules()["invites"] as Dictionary).get("maxPendingPerClan", 32)) and not members.has(str(p)):
					invites[str(p).left(64)] = float(at) if (at is float or at is int) and is_finite(float(at)) else float(now_sec.call())
		var id := "clan_%d" % _next_id
		_next_id += 1
		_add_clan(id, { "id": id, "name": cname, "name_n": name_n, "founder": founder, "members": members,
			"invites": invites, "created": float(s.get("created", now_sec.call())), "settlement": str(sid).left(64) })
		_dirty_clans[id] = true
		made += 1
	_drop_member_invites()
	if made > 0:
		GameBus.clans_changed.emit()
	return made

## Drop every invite naming a player who already belongs to a clan (a loaded or migrated record can hold one):
## it could never be accepted and would hold one of the clan's pending slots.
func _drop_member_invites() -> void:
	for id: String in _clans:
		var inv: Dictionary = _clans[id]["invites"]
		for p: String in inv.keys():
			if _member_of.has(p):
				inv.erase(p)
				_dirty_clans[id] = true

static func _settlement_order(sid: String) -> int:
	var suffix := sid.trim_prefix("settlement_")
	return int(suffix) if suffix.is_valid_int() else 1 << 30

## `cname`, or `cname 2`, `cname 3`… when another clan's name has the same skeleton.
func _unique_name(cname: String) -> String:
	if cname == "" or not _taken.has(CreationRules.skeleton(cname)):
		return cname
	for n in range(2, 1000):
		var candidate := "%s %d" % [cname, n]
		if not _taken.has(CreationRules.skeleton(candidate)):
			return candidate
	return ""

# ── persistence ──────────────────────────────────────────────────────────

func to_data() -> Dictionary:
	return { "format": DATA_FORMAT, "next_id": _next_id, "clans": _clans.duplicate(true) }

## Restore from a saved world record. Malformed entries are skipped, a player in two clans keeps the first, and
## a name whose skeleton another clan holds keeps the first holder's.
func from_data(data: Variant) -> void:
	_clans.clear()
	_member_of.clear()
	_taken.clear()
	_dirty_clans.clear()
	_dirty_players.clear()
	_skill_dirty.clear()
	_skill_pushed.clear()
	_next_id = 1
	if not (data is Dictionary):
		return
	_next_id = maxi(1, int((data as Dictionary).get("next_id", 1)))
	var raw: Variant = (data as Dictionary).get("clans", {})
	if not (raw is Dictionary):
		return
	var keys: Array = (raw as Dictionary).keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for k: Variant in keys:
		var c: Variant = raw[k]
		var id := str(k).left(64)
		if _clans.size() >= MAX_CLANS or not (c is Dictionary) or not (c.get("members", null) is Dictionary):
			continue
		var founder := str(c.get("founder", "")).left(64)
		var members := {}
		for p: Variant in (c["members"] as Dictionary):
			var who := str(p).left(64)
			var role := str(c["members"][p])
			if who != "" and not _member_of.has(who) and members.size() < MAX_MEMBERS:
				members[who] = role if role_rules(role).size() > 0 else "guest"
		if not members.has(founder):
			continue
		members[founder] = founder_role()
		var cname := str(c.get("name", "")).left(64)
		var name_n := clampi(int(c.get("name_n", 0)), 0, 1000000)
		if (cname == "" and name_n == 0) or (cname != "" and _taken.has(CreationRules.skeleton(cname))):
			continue
		var invites := {}
		if c.get("invites", null) is Dictionary:
			for p: Variant in (c["invites"] as Dictionary):
				var at: Variant = c["invites"][p]
				if invites.size() < MAX_MEMBERS and (at is float or at is int) and is_finite(float(at)):
					invites[str(p).left(64)] = float(at)
		_add_clan(id, { "id": id, "name": cname, "name_n": name_n, "founder": founder, "members": members,
			"invites": invites, "created": float(c.get("created", 0.0)) if is_finite(float(c.get("created", 0.0))) else 0.0,
			"settlement": str(c.get("settlement", "")).left(64) })
		var suffix := id.trim_prefix("clan_")
		if suffix.is_valid_int():
			_next_id = maxi(_next_id, int(suffix) + 1)   # never reuse a loaded id
	_drop_member_invites()
	_dirty_clans.clear()

# ── views ────────────────────────────────────────────────────────────────

## What one player may see: their own clan (name, their role, the roster with every member's skills) and the
## invites naming them. Sent to that player alone; an outsider's view never holds another clan's roster.
## Players are named by public handle only: a player id is a bearer token (see PlayerRegistry.public_handle).
## `rosters` (clan id -> roster) lets one push build each clan's roster once for all its members.
func private_view(player_id: String, rosters: Dictionary = {}) -> Dictionary:
	var pid := _pid(player_id)
	var out := { "mine": {}, "invites": [] }
	var id := clan_of(pid)
	if id != "":
		var c: Dictionary = _clans[id]
		if not rosters.has(id):
			var built: Array = []
			for m: String in (c["members"] as Dictionary):
				built.append(member_entry(m, str(c["members"][m])))
			rosters[id] = built
		var mine := { "id": id, "name": str(c["name"]), "name_n": int(c["name_n"]), "role": role_of(pid),
			"founder": _handle(str(c["founder"])), "roster": rosters[id], "invited": [] }
		if may(pid, "invite"):
			for p: String in (c["invites"] as Dictionary):
				(mine["invited"] as Array).append({ "handle": _handle(p), "name": _display_name(p) })
		out["mine"] = mine
	else:
		for cid: String in ids():
			if (_clans[cid]["invites"] as Dictionary).has(pid):
				(out["invites"] as Array).append({ "id": cid, "name": str(_clans[cid]["name"]), "name_n": int(_clans[cid]["name_n"]) })
	return out

## One roster row: display name, public handle (what `/msg`, kick and set-role take), role, whether online, and skills as
## { skill: { xp, tier } } from the host's own record (never from a message).
func member_entry(member: String, role: String) -> Dictionary:
	var skills := {}
	if registry != null and registry.has_method("get_record"):
		var rec: Dictionary = registry.get_record(member)
		var xp: Variant = rec.get("skill_xp", {})
		var tiers: Variant = rec.get("skills", {})
		if xp is Dictionary:
			for s: Variant in (xp as Dictionary):
				if skills.size() < MAX_ROSTER_SKILLS and s is String:
					skills[s] = { "xp": int(xp[s]), "tier": "" }
		if tiers is Dictionary:
			for s: Variant in (tiers as Dictionary):
				if s is String and (skills.has(s) or skills.size() < MAX_ROSTER_SKILLS):
					var e: Dictionary = skills.get(s, { "xp": 0, "tier": "" })
					e["tier"] = str(tiers[s]).left(16)
					skills[s] = e
	var online := registry != null and registry.has_method("is_online") and bool(registry.is_online(member))
	if registry != null and "local_player_id" in registry and member == str(registry.local_player_id):
		online = true
	return { "name": _display_name(member), "handle": _handle(member), "role": role, "online": online, "skills": skills }

func _display_name(pid: String) -> String:
	return str(registry.display_name(pid)) if registry != null and registry.has_method("display_name") else pid

func _handle(pid: String) -> String:
	return str(registry.public_handle(pid)) if registry != null and registry.has_method("public_handle") else pid

## A roster sorted by one skill, best first: higher XP, then higher tier, then name. "" sorts by role then name.
static func sort_roster(roster: Array, skill: String) -> Array:
	var out := roster.duplicate()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if skill != "":
			var sa: Dictionary = (a.get("skills", {}) as Dictionary).get(skill, {})
			var sb: Dictionary = (b.get("skills", {}) as Dictionary).get(skill, {})
			if int(sa.get("xp", 0)) != int(sb.get("xp", 0)):
				return int(sa.get("xp", 0)) > int(sb.get("xp", 0))
			# An unknown or missing tier ranks below novice.
			var ta := SkillTiers.TIER_ORDER.find(str(sa.get("tier", "")))
			var tb := SkillTiers.TIER_ORDER.find(str(sb.get("tier", "")))
			if ta != tb:
				return ta > tb
		else:
			var ra := _rank(str(a.get("role", "")))
			var rb := _rank(str(b.get("role", "")))
			if ra != rb:
				return ra < rb
		return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) < 0)
	return out

## A clan or invite entry's name in the active locale: its own text, or a migrated settlement's numbered default.
static func display_name(entry: Dictionary) -> String:
	var n := int(entry.get("name_n", 0))
	return I18n.t("settlement.default_name", [n]) if n > 0 else str(entry.get("name", ""))

func apply_view(view: Variant) -> void:
	_view = view if view is Dictionary else {}

func view() -> Dictionary:
	return _view
