extends Node
## Settlement slice — player-founded places (Phase 140, designed in Phase 139).
##
## A settlement is members with roles, a site and a shared stockpile. Phase 205 removed its claim, its
## hearth and its decay: what a player builds is owned by its structure (`StructureSlice`), not by land, and no
## new settlement is founded by players (clans replace them; `found` stays for the host and tests). The site is
## where its stockpile, research and projects are used, within SITE_REACH, until Phases 207–209 move them. The host decides everything; clients mirror a view (`apply_view`). Rules come from the
## fabric's `Settlement` world system (`GameData.WORLD_SYSTEMS["Settlement"].rules`).
##
## Plug contract (GameBus):
##   IN  : settlement_intent(action, args, player_id)
##   OUT : settlement_resolved(player_id, action, ok, reason), settlements_changed(),
##         settlement_project_changed(settlement_id, project, what, player_id)
##
## Positions are ground metres as doubles (`chunk * CHUNK_METERS + local`), so a site far from the
## origin stays exact. Time is Unix seconds from `now_sec`; a "day" is 86,400 s.
##
## Public API (all host-side; a client calls none of them):
##   rules() / tier_for(id, now)
##   found(player_id, name, xz) -> String               "" when founded, else a reason code
##   invite(actor, target) / join(player, id) / set_role(actor, target, role) / leave(player)
##   deposit(player, item, qty) / withdraw(player, item, qty)
##   start_project(actor, key) / contribute(actor, key, item, qty, source)   (Phase 198; no labour since Phase 207)
##   settlement_of(player_id) -> String                id of the settlement the player belongs to
##   tick(now)                                         grow tiers, lapse invites, return migrated hearths

const I18n := preload("res://src/core/i18n.gd")
const WorldPos := preload("res://src/terrain/world_pos.gd")
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const SeamWrap := preload("res://src/terrain/seam_wrap.gd")
const ProjectRules := preload("res://src/settlement/project_rules.gd")
const SpecialtyRules := preload("res://src/settlement/specialty_rules.gd")

const DAY_SEC := 86400.0
## Items per stockpile stack.
const STACK_SIZE := 100
const INTENT_INTERVAL := 0.25
const MAX_NAME := 32
const MAX_MEMBERS := 64
## An invite nobody accepted lapses after this long, so stale invites cannot fill the list for good.
const INVITE_TTL_SEC := 7.0 * DAY_SEC
## `_last_intent` entries are swept once it holds more than this many players.
const MAX_INTENT_ENTRIES := 256
const MAX_SETTLEMENTS := 512
const MAX_QTY := 10000
## Phase 198 — the settlement record's format: 2 added `projects` (a format-1 record loads with none).
const DATA_FORMAT := 2
const ACTIONS := ["invite", "join", "role", "leave", "deposit", "withdraw", "uninvite",
	"project_start", "project_give"]
const ROLES := ["founder", "elder", "member", "guest"]

## Every refusal code an action can return.
const REASONS := ["unknown_player", "rate_limited", "bad_args", "already_member",
	"too_many", "not_member", "no_permission", "unknown_settlement", "not_invited", "full", "bad_role",
	"founder_locked", "no_stock", "over_limit", "no_inventory", "too_far", "unknown_action", "durable", "no_such_invite",
	"unknown_project", "project_exists", "tier_too_low", "too_many_projects", "project_done", "unknown_item", "too_much",
	"foreign_circle"]

const DEFAULT_RULES := {
	"hearthStation": "hearth", "hearthItem": "Hearth", "guildMaxSettlements": 1,
	"tiers": {
		"founded": { "minMembers": 1, "minDays": 0 },
		"growing": { "minMembers": 3, "minDays": 3 },
		"town": { "minMembers": 8, "minDays": 14 },
	},
	"roles": {
		"founder": { "build": true, "take": true, "invite": true, "withdrawLimit": 0 },
		"elder": { "build": true, "take": true, "invite": true, "withdrawLimit": 200 },
		"member": { "build": true, "take": true, "invite": false, "withdrawLimit": 50 },
		"guest": { "build": false, "take": false, "invite": false, "withdrawLimit": 0 },
	},
	"stockpile": { "founded": { "capacityStacks": 20 }, "growing": { "capacityStacks": 60 }, "town": { "capacityStacks": 160 } },
}
## Phase 205 — metres from a settlement's site within which its stockpile, research and projects are used (the
## old founded-tier claim radius; it guards nothing and never decays).
const SITE_REACH := 24.0
const TIER_ORDER := ["founded", "growing", "town"]

## Set by game_root.
var registry: Node = null
var now_sec: Callable = func() -> float: return Time.get_unix_time_from_system()
## Monotonic seconds for the intent rate limit (a wall-clock jump must not lock or free a player).
var mono_sec: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0
## `(station_id) -> void`, set by the wiring: a migrated settlement's hearth station is removed with it.
var release_station: Callable = Callable()
## Phase 205 — founder -> Hearth items owed back (a saved settlement's hearth, removed on load), handed over
## by `tick` once the founder is online with a pack that has room.
var _hearth_returns: Dictionary = {}
## Test seam: `(player_id) -> Variant` the player's ground position as a `Vector2` of metres, or null.
var position_of: Callable = Callable()

## id -> { id, name, founder, members {pid: role}, invites {pid: true}, created, last_active, hx, hz (the site),
##         status, stock {item: n}, taken {pid: {day, n}}, projects }
## `invites` maps an invited player to the `now_sec` the invite was made (it lapses after INVITE_TTL_SEC).
var _settlements: Dictionary = {}
var _next_id: int = 1
## The next default-name number. Monotonic: it never falls when a settlement decays, so no two repeat.
var _next_name: int = 1
var _last_intent: Dictionary = {}
## Phase 198 — `(id, key, site {x, z}) -> void` places a finished structure at its site (site in ground metres
## as doubles); set by the wiring.
var place_structure: Callable = Callable()
## Phase 206 — `(player_id, xz: Vector2) -> bool` whether `xz` (ground metres) lies inside the circle of a
## clan the player is not in, where they may not build; set by the structure wiring (host). Unset: nowhere.
var build_blocked: Callable = Callable()
## Phase 207 — [settlement id, project key] of loaded projects with every material in, finished by the next tick.
var _finish_on_tick: Array = []
## Phase 199 — pid -> the specialty last announced for that player (absent = none).
var _specialties: Dictionary = {}
## Client view: what the host last sent.
var _view: Dictionary = {}

func _ready() -> void:
	GameBus.settlement_intent.connect(_on_intent)
	GameBus.player_left.connect(forget_player)

## A player left: their rate-limit entry goes with them.
func forget_player(player_id: String) -> void:
	_last_intent.erase(player_id)
	_specialties.erase(player_id)

# ── rules ────────────────────────────────────────────────────────────────

## The merged rule table, built once per fabric resource.
## Callers must not mutate it.
var _rules_cache: Dictionary = {}
var _rules_source: Resource = null

func rules() -> Dictionary:
	var res: Resource = GameData.WORLD_SYSTEMS.get("Settlement", null)
	if not _rules_cache.is_empty() and res == _rules_source:
		return _rules_cache
	var out: Dictionary = DEFAULT_RULES.duplicate(true)
	if res != null:
		var r: Variant = res.get("rules")
		if r is Dictionary:
			out.merge(r, true)
	_rules_cache = out
	_rules_source = res
	return out

func role_rules(role: String) -> Dictionary:
	return (rules()["roles"] as Dictionary).get(role, { "build": false, "take": false, "invite": false, "withdrawLimit": 0 })

## The tier a settlement has earned: the highest whose member count and age thresholds hold. Completed
## projects count toward no tier (Phase 207).
func tier_for(id: String, now: float) -> String:
	var s: Dictionary = _settlements.get(id, {})
	if s.is_empty():
		return ""
	var tiers: Dictionary = rules()["tiers"]
	var days: float = maxf(0.0, now - float(s["created"])) / DAY_SEC
	var best: String = "founded"
	for name: String in TIER_ORDER:
		var t: Dictionary = tiers.get(name, {})
		if (s["members"] as Dictionary).size() >= int(t.get("minMembers", 1)) and days >= float(t.get("minDays", 0)):
			best = name
	return best

func capacity_stacks(id: String) -> int:
	var s: Dictionary = _settlements.get(id, {})
	if s.is_empty():
		return 0
	return int((rules()["stockpile"] as Dictionary).get(str(s["status"]), {}).get("capacityStacks", 0))

func used_stacks(id: String) -> int:
	var n := 0
	for item: String in (_settlements.get(id, {}).get("stock", {}) as Dictionary):
		n += ceili(float(_settlements[id]["stock"][item]) / float(STACK_SIZE))
	return n

# ── queries ──────────────────────────────────────────────────────────────

func ids() -> Array:
	var out: Array = _settlements.keys()
	out.sort()
	return out

func count() -> int:
	return _settlements.size()

func get_settlement(id: String) -> Dictionary:
	return (_settlements.get(id, {}) as Dictionary).duplicate(true)

func settlement_of(player_id: String) -> String:
	var pid := _pid(player_id)
	for id: String in ids():
		if (_settlements[id]["members"] as Dictionary).has(pid):
			return id
	return ""

func role_of(player_id: String, id: String) -> String:
	return str((_settlements.get(id, {}).get("members", {}) as Dictionary).get(player_id, ""))

func stock_of(id: String) -> Dictionary:
	return (_settlements.get(id, {}).get("stock", {}) as Dictionary).duplicate()

## Ground metres between two points, the short way round the planet.
static func dist_m(a: Vector2, b: Vector2) -> float:
	var lap := float(TerrainSlice.circumference_chunks()) * WorldPos.CHUNK_METERS
	var dx := SeamWrap.wrap_f(b.x - a.x, lap)
	return Vector2(dx, b.y - a.y).length()

static func xz_of_exact(pos: Dictionary) -> Vector2:
	var c: Vector2i = pos["chunk"]
	var l: Vector3 = pos["local"]
	return Vector2(float(c.x) * WorldPos.CHUNK_METERS + l.x, float(c.y) * WorldPos.CHUNK_METERS + l.z)

## The site's exact `{chunk, local}` (empty for a settlement founded without one; saved as `hearth`).
func site_exact(id: String) -> Dictionary:
	var s: Dictionary = _settlements.get(id, {})
	return WorldPos.pos_from_wire(s["hearth"]) if s.has("hearth") else {}

func _site_xz(s: Dictionary) -> Vector2:
	return Vector2(float(s["hx"]), float(s["hz"]))

func _player_xz(player_id: String) -> Variant:
	if position_of.is_valid():
		return position_of.call(player_id)
	if registry == null:
		return null
	var pos: Dictionary = registry.get_world_pos(player_id)
	if pos.is_empty():
		return null
	return xz_of_exact(pos)

func _pid(player_id: String) -> String:
	if player_id == "" and registry != null and "local_player_id" in registry:
		return str(registry.local_player_id)
	return player_id

func _inventory(player_id: String) -> Node:
	if registry != null and registry.has_method("get_inventory"):
		return registry.get_inventory(_pid(player_id))
	return null

# ── founding ─────────────────────────────────────────────────────────────

## Found a settlement for `player_id` with its site at `xz` (host and tests only: no intent founds one since
## Phase 205). `exact` is the site's `{chunk, local}` when the caller has it:
## `xz` is a float32 `Vector2`, coarse far from the origin, so the exact position is what is saved.
## `auto_name` gives the settlement no text name but a number (`name_n`) clients render as the localized
## default name ("Settlement 3"); the host never renders text in its own locale.
func found(player_id: String, sname: String, xz: Vector2, exact: Dictionary = {}, auto_name: bool = false) -> String:
	var pid := _pid(player_id)
	if pid == "":
		return "unknown_player"
	sname = "" if auto_name else sname.strip_edges().left(MAX_NAME)
	if sname == "" and not auto_name:
		return "bad_args"
	if settlement_of(pid) != "":
		return "already_member"
	if _settlements.size() >= MAX_SETTLEMENTS:
		return "too_many"
	var now := float(now_sec.call())
	var id := "settlement_%d" % _next_id
	_next_id += 1
	var name_n := 0
	if auto_name:
		name_n = _next_name
		_next_name += 1
	_settlements[id] = {
		"id": id, "name": sname, "name_n": name_n, "founder": pid, "members": { pid: "founder" }, "invites": {},
		"created": now, "last_active": now, "hx": xz.x, "hz": xz.y, "status": "founded",
		"stock": {}, "taken": {}, "projects": {},
	}
	if WorldPos.is_plausible_pos(exact):
		_settlements[id]["hearth"] = WorldPos.pos_to_wire(exact)
		# Components stay doubles: a `Vector2` is float32 and would snap a far site to metres.
		var c: Vector2i = exact["chunk"]
		var l: Vector3 = exact["local"]
		_settlements[id]["hx"] = float(c.x) * WorldPos.CHUNK_METERS + l.x
		_settlements[id]["hz"] = float(c.y) * WorldPos.CHUNK_METERS + l.z
	GameBus.settlements_changed.emit()
	return ""

# ── membership ───────────────────────────────────────────────────────────

func invite(actor: String, target: String) -> String:
	var pid := _pid(actor)
	var id := settlement_of(pid)
	if id == "":
		return "not_member"
	if not bool(role_rules(role_of(pid, id))["invite"]):
		return "no_permission"
	target = target.strip_edges().left(64)
	if target == "" or target == pid:
		return "bad_args"
	var s: Dictionary = _settlements[id]
	if (s["members"] as Dictionary).has(target):
		return "already_member"
	if _lapse_invites(s, float(now_sec.call())):
		GameBus.settlements_changed.emit()
	if (s["invites"] as Dictionary).size() >= MAX_MEMBERS:
		return "full"
	s["invites"][target] = float(now_sec.call())
	GameBus.settlements_changed.emit()
	return ""

## Withdraw `target`'s invite to the actor's settlement (anyone who may invite may withdraw one).
func uninvite(actor: String, target: String) -> String:
	var pid := _pid(actor)
	var id := settlement_of(pid)
	if id == "":
		return "not_member"
	if not bool(role_rules(role_of(pid, id))["invite"]):
		return "no_permission"
	target = target.strip_edges().left(64)
	var s: Dictionary = _settlements[id]
	if _lapse_invites(s, float(now_sec.call())):
		GameBus.settlements_changed.emit()
	if not (s["invites"] as Dictionary).has(target):
		return "no_such_invite"
	(s["invites"] as Dictionary).erase(target)
	GameBus.settlements_changed.emit()
	return ""

## Drop the invites of `s` older than INVITE_TTL_SEC. True when one lapsed.
func _lapse_invites(s: Dictionary, now: float) -> bool:
	var inv: Dictionary = s["invites"]
	var lapsed := false
	for p: String in inv.keys():
		if now - float(inv[p]) >= INVITE_TTL_SEC:
			inv.erase(p)
			lapsed = true
	return lapsed

## A player accepts an invite: they join as a `member`.
func join(player_id: String, id: String) -> String:
	var pid := _pid(player_id)
	if not _settlements.has(id):
		return "unknown_settlement"
	if settlement_of(pid) != "":
		return "already_member"
	var s: Dictionary = _settlements[id]
	if _lapse_invites(s, float(now_sec.call())):
		GameBus.settlements_changed.emit()   # the lapsed invite leaves the invitee's cached view
	if not (s["invites"] as Dictionary).has(pid):
		return "not_invited"
	if (s["members"] as Dictionary).size() >= MAX_MEMBERS:
		return "full"
	(s["invites"] as Dictionary).erase(pid)
	s["members"][pid] = "member"
	GameBus.settlements_changed.emit()
	return ""

## Change `target`'s role. The founder alone makes elders; anyone with `invite` sets member and guest;
## the founder's own role never changes.
func set_role(actor: String, target: String, role: String) -> String:
	var pid := _pid(actor)
	var id := settlement_of(pid)
	if id == "":
		return "not_member"
	if not ROLES.has(role) or role == "founder":
		return "bad_role"
	var s: Dictionary = _settlements[id]
	if not (s["members"] as Dictionary).has(target):
		return "not_member"
	var mine := role_of(pid, id)
	if not bool(role_rules(mine)["invite"]) or (role == "elder" and mine != "founder") \
			or (role_of(target, id) == "elder" and mine != "founder"):
		return "no_permission"
	if target == str(s["founder"]):
		return "founder_locked"
	s["members"][target] = role
	GameBus.settlements_changed.emit()
	return ""

func leave(player_id: String) -> String:
	var pid := _pid(player_id)
	var id := settlement_of(pid)
	if id == "":
		return "not_member"
	if pid == str(_settlements[id]["founder"]):
		return "founder_locked"
	(_settlements[id]["members"] as Dictionary).erase(pid)
	GameBus.settlements_changed.emit()
	return ""

# ── stockpile ────────────────────────────────────────────────────────────

func _at_site(pid: String, id: String) -> bool:
	var xz: Variant = _player_xz(pid)
	return xz is Vector2 and dist_m(_site_xz(_settlements[id]), xz as Vector2) <= SITE_REACH

## Move `qty` of `item` from the player's pack into the stockpile. All or nothing.
func deposit(player_id: String, item: String, qty: int) -> String:
	var pid := _pid(player_id)
	var id := settlement_of(pid)
	if id == "":
		return "not_member"
	if item == "" or item.length() > 64 or qty < 1 or qty > MAX_QTY or not _known_item(item):
		return "bad_args"
	var rr := role_rules(role_of(pid, id))
	if not (bool(rr["build"]) or bool(rr["take"])):
		return "no_permission"
	if not _at_site(pid, id):
		return "too_far"
	var inv := _inventory(pid)
	if inv == null or not inv.has_method("consume_items"):
		return "no_inventory"
	if inv.has_method("is_durable") and inv.is_durable(item):
		return "durable"   # the stockpile counts units, so wear would be lost: a worn tool comes back new
	if inv.get_item_count(item) < qty:
		return "no_stock"
	var s: Dictionary = _settlements[id]
	var before := used_stacks(id)
	var stock: Dictionary = s["stock"]
	var had := int(stock.get(item, 0))
	var after_stacks := before - ceili(float(had) / STACK_SIZE) + ceili(float(had + qty) / STACK_SIZE)
	if after_stacks > capacity_stacks(id):
		return "full"
	if not inv.consume_items({ item: qty }):
		return "no_stock"
	stock[item] = had + qty
	_touch(id)
	_push_inventory(pid)
	GameBus.settlements_changed.emit()
	return ""

## Move `qty` of `item` from the stockpile into the player's pack, within the role's daily limit.
func withdraw(player_id: String, item: String, qty: int) -> String:
	var pid := _pid(player_id)
	var id := settlement_of(pid)
	if id == "":
		return "not_member"
	if item == "" or item.length() > 64 or qty < 1 or qty > MAX_QTY:
		return "bad_args"
	var role := role_of(pid, id)
	var rr := role_rules(role)
	if not bool(rr["take"]):
		return "no_permission"
	if not _at_site(pid, id):
		return "too_far"
	var s: Dictionary = _settlements[id]
	var stock: Dictionary = s["stock"]
	if int(stock.get(item, 0)) < qty:
		return "no_stock"
	var day := floori(float(now_sec.call()) / DAY_SEC)
	var taken: Dictionary = (s["taken"] as Dictionary).get(pid, { "day": day, "n": 0 })
	if int(taken["day"]) != day:
		taken = { "day": day, "n": 0 }
	if role != "founder" and int(taken["n"]) + qty > int(rr["withdrawLimit"]):
		return "over_limit"
	var inv := _inventory(pid)
	if inv == null or not inv.has_method("add_item"):
		return "no_inventory"
	if not inv.add_item(item, qty):
		return "full"
	stock[item] = int(stock[item]) - qty
	if int(stock[item]) <= 0:
		stock.erase(item)
	taken["n"] = int(taken["n"]) + qty
	s["taken"][pid] = taken
	_touch(id)
	_push_inventory(pid)
	GameBus.settlements_changed.emit()
	return ""

## Units of `item` the player may draw for research: the stockpile of the settlement they belong to,
## while they stand at its site. 0 otherwise.
func research_stock(player_id: String, item: String) -> int:
	var pid := _pid(player_id)
	var id := settlement_of(pid)
	if id == "" or not bool(role_rules(role_of(pid, id))["take"]) or not _at_site(pid, id):
		return 0
	return int((_settlements[id]["stock"] as Dictionary).get(item, 0))

## Take research materials from the player's stockpile: all or nothing.
func consume_research(player_id: String, counts: Dictionary) -> bool:
	var pid := _pid(player_id)
	var id := settlement_of(pid)
	if id == "" or not _at_site(pid, id):
		return false
	var stock: Dictionary = _settlements[id]["stock"]
	for item: String in counts:
		if int(stock.get(item, 0)) < int(counts[item]):
			return false
	for item: String in counts:
		stock[item] = int(stock[item]) - int(counts[item])
		if int(stock[item]) <= 0:
			stock.erase(item)
	_touch(id)
	GameBus.settlements_changed.emit()
	return true

func _push_inventory(pid: String) -> void:
	if registry == null or not ("local_player_id" in registry) or pid == str(registry.local_player_id):
		return
	var inv := _inventory(pid)
	if inv != null and inv.has_method("get_contents"):
		GameBus.inventory_synced.emit(pid, inv.get_contents(), inv.get_durability_data())

# ── projects (Phase 198) ─────────────────────────────────────────────────

func projects_of(id: String) -> Dictionary:
	return (_settlements.get(id, {}).get("projects", {}) as Dictionary).duplicate(true)

## Start project `key` at the actor's feet (or at `site`, a host-side caller's ground point; an intent never
## names one). Needs a role with `invite`, the project site within SITE_REACH of the settlement's, and the tier.
func start_project(actor: String, key: String, site: Variant = null) -> String:
	var pid := _pid(actor)
	var id := settlement_of(pid)
	if id == "":
		return "not_member"
	if not bool(role_rules(role_of(pid, id))["invite"]):
		return "no_permission"
	var xz: Variant = site if site is Vector2 else _player_xz(pid)
	if not (xz is Vector2) or dist_m(_site_xz(_settlements[id]), xz as Vector2) > SITE_REACH:
		return "too_far"
	if build_blocked.is_valid() and bool(build_blocked.call(pid, xz as Vector2)):
		return "foreign_circle"
	var s: Dictionary = _settlements[id]
	var tier: String = str(s["status"])
	var why := ProjectRules.start_blocker(key, tier, s["projects"])
	if why != "":
		return why
	s["projects"][key] = { "key": key, "by": pid, "started": float(now_sec.call()), "site": { "x": (xz as Vector2).x, "z": (xz as Vector2).y },
		"given": {}, "status": "building", "done_at": 0.0, "contributors": {} }
	_touch(id)
	GameBus.settlement_project_changed.emit(id, key, "started", pid)
	GameBus.settlements_changed.emit()
	return ""

## Bring `qty` of `item` to project `key`, from the contributor's pack (`source` "bag") or from the
## stockpile ("stock", counted against the role's daily `withdrawLimit` like a withdrawal). All or nothing.
func contribute(actor: String, key: String, item: String, qty: int, source: String = "bag") -> String:
	var pid := _pid(actor)
	var id := settlement_of(pid)
	if id == "":
		return "not_member"
	if item == "" or item.length() > 64 or qty < 1 or qty > MAX_QTY or not (source in ["bag", "stock"]):
		return "bad_args"
	var role := role_of(pid, id)
	var rr := role_rules(role)
	if not bool(rr["build"]):
		return "no_permission"
	var s: Dictionary = _settlements[id]
	var state: Dictionary = (s["projects"] as Dictionary).get(key, {})
	var why := ProjectRules.contribution_blocker(ProjectRules.def_of(key), state, item, qty)
	if why != "":
		return why
	if not _at_site(pid, id):
		return "too_far"
	if source == "stock":
		var day := floori(float(now_sec.call()) / DAY_SEC)
		var taken: Dictionary = (s["taken"] as Dictionary).get(pid, { "day": day, "n": 0 })
		if int(taken["day"]) != day:
			taken = { "day": day, "n": 0 }
		why = ProjectRules.stock_draw_blocker(role, rr, int(taken["n"]), qty)
		if why != "":
			return why
		var stock: Dictionary = s["stock"]
		if int(stock.get(item, 0)) < qty:
			return "no_stock"
		stock[item] = int(stock[item]) - qty
		if int(stock[item]) <= 0:
			stock.erase(item)
		taken["n"] = int(taken["n"]) + qty
		s["taken"][pid] = taken
	else:
		var inv := _inventory(pid)
		if inv == null or not inv.has_method("consume_items"):
			return "no_inventory"
		if inv.get_item_count(item) < qty or not inv.consume_items({ item: qty }):
			return "no_stock"
		_push_inventory(pid)
	state["given"][item] = int(state["given"].get(item, 0)) + qty
	_credit_items(state, pid, qty)
	_touch(id)
	GameBus.settlement_project_changed.emit(id, key, "contributed", pid)
	_maybe_complete(id, key)
	GameBus.settlements_changed.emit()
	return ""

## Phase 199 — the specialty the host's own skill and attribute records give `player_id` ("" for none).
## Nothing here is client-reported.
func compute_specialty(player_id: String) -> String:
	if registry == null or not registry.has_method("get_skill_tier") or not registry.has_method("get_attributes"):
		return ""
	var pid := _pid(player_id)
	var tbl := SpecialtyRules.table()
	var tiers := {}
	for key: String in tbl["specialties"]:
		for skill: String in tbl["specialties"][key].get("skills", {}):
			tiers[skill] = str(registry.get_skill_tier(pid, skill)) if str(registry.get_skill_tier(pid, skill)) != "" else "novice"
	return SpecialtyRules.specialty_for(tiers, registry.get_attributes(pid), tbl)

## The last specialty announced for a player ("" until one is).
func specialty_of(player_id: String) -> String:
	return str(_specialties.get(_pid(player_id), ""))

## Recompute a player's specialty after their skills or attributes changed. A change emits one
## `specialty_changed` and a settlements_changed so the members' views refresh; no change emits nothing.
func refresh_specialty(player_id: String) -> bool:
	var pid := _pid(player_id)
	var now := compute_specialty(pid)
	if now == specialty_of(pid):
		return false
	if now == "":
		_specialties.erase(pid)
	else:
		_specialties[pid] = now
	GameBus.specialty_changed.emit(pid, now)
	GameBus.settlements_changed.emit()
	return true

func _credit_items(state: Dictionary, pid: String, qty: int) -> void:
	var c: Dictionary = state["contributors"]
	if not c.has(pid):
		if c.size() >= ProjectRules.MAX_CONTRIBUTORS:
			return
		c[pid] = { "items": 0 }
	c[pid]["items"] = int(c[pid]["items"]) + qty

## A project with every material in finishes: its structure is placed (`place_structure`). Nothing else
## changes (Phase 207): no tier, no clan value, no credit to anyone.
func _maybe_complete(id: String, key: String) -> void:
	var state: Dictionary = _settlements[id]["projects"][key]
	if str(state["status"]) == "done" or not ProjectRules.is_complete(ProjectRules.def_of(key), state):
		return
	state["status"] = "done"
	state["done_at"] = float(now_sec.call())
	if place_structure.is_valid():
		place_structure.call(id, key, (state["site"] as Dictionary).duplicate())
	GameBus.settlement_project_changed.emit(id, key, "completed", "")

# ── lifecycle ────────────────────────────────────────────────────────────

func _touch(id: String) -> void:
	_settlements[id]["last_active"] = float(now_sec.call())

## Grow tiers, lapse invites, complete the loaded projects `_finish_on_tick` names and hand back migrated hearths
## as of `now`. Returns true when anything changed.
## Since Phase 205 a settlement neither decays nor is abandoned: it lasts while it has members.
func tick(now: float) -> bool:
	var changed := false
	for id: String in ids():
		var s: Dictionary = _settlements[id]
		if _lapse_invites(s, now):
			changed = true
		var tier := tier_for(id, now)
		if TIER_ORDER.find(tier) > TIER_ORDER.find(str(s["status"])):
			s["status"] = tier   # tiers never shrink: a settlement that lost members keeps what it earned
			changed = true
	if not _finish_on_tick.is_empty():
		changed = _finish_loaded() or changed
	_return_hearths()
	if changed:
		GameBus.settlements_changed.emit()
	return changed

## Phase 207 — complete the projects a load found with every material in (saved with labour still to do).
func _finish_loaded() -> bool:
	var due := _finish_on_tick
	_finish_on_tick = []
	var done := false
	for pair: Array in due:
		var id := str(pair[0])
		if _settlements.has(id) and (_settlements[id]["projects"] as Dictionary).has(pair[1]):
			_maybe_complete(id, str(pair[1]))
			done = true
	return done

## Phase 205 — the Hearth items owed to founders whose saved hearth was removed, as a `{ founder: n }` copy.
func hearth_returns() -> Dictionary:
	return _hearth_returns.duplicate()

## Hand each owed Hearth to its founder once they are online and their pack takes it.
func _return_hearths() -> void:
	if _hearth_returns.is_empty() or registry == null:
		return
	var item := str(rules()["hearthItem"])
	for pid: String in _hearth_returns.keys():
		if registry.has_method("is_online") and not registry.is_online(pid):
			continue
		var inv := _inventory(pid)
		if inv == null or not inv.has_method("add_item") or not inv.add_item(item, int(_hearth_returns[pid])):
			continue
		_hearth_returns.erase(pid)
		_push_inventory(pid)

# ── intents ──────────────────────────────────────────────────────────────

func _on_intent(action: String, args: Dictionary, player_id: String) -> void:
	if not is_authoritative():
		return
	var pid := _pid(player_id)
	var reason := _resolve(action, args, pid)
	GameBus.settlement_resolved.emit(pid, action, reason == "", reason)

var is_host: bool = true
func is_authoritative() -> bool:
	return is_host

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
		"invite":
			return invite(pid, str(args.get("target", "")))
		"uninvite":
			return uninvite(pid, str(args.get("target", "")).left(64))
		"join":
			return join(pid, str(args.get("id", "")).left(64))
		"role":
			return set_role(pid, str(args.get("target", "")).left(64), str(args.get("role", "")).left(16))
		"leave":
			return leave(pid)
		"deposit":
			return deposit(pid, str(args.get("item", "")), _qty(args.get("qty", 0)))
		"withdraw":
			return withdraw(pid, str(args.get("item", "")), _qty(args.get("qty", 0)))
		"project_start":
			return start_project(pid, str(args.get("project", "")).left(32))
		"project_give":
			return contribute(pid, str(args.get("project", "")).left(32), str(args.get("item", "")), _qty(args.get("qty", 0)),
				str(args.get("from", "bag")).left(8))
	return "unknown_action"

## Items and materials both live in a pack (a mined material is an item there).
static func _known_item(item: String) -> bool:
	return GameData.ITEMS.has(item) or GameData.MATERIALS.has(item)

static func _qty(v: Variant) -> int:
	return int(v) if (v is int or v is float) else 0

# ── persistence ──────────────────────────────────────────────────────────

func to_data() -> Dictionary:
	return { "format": DATA_FORMAT, "next_id": _next_id, "next_name": _next_name, "settlements": _settlements.duplicate(true),
		"hearth_returns": _hearth_returns.duplicate() }

## Restore from a saved world record. Malformed entries are skipped; numbers are clamped.
func from_data(data: Variant) -> void:
	_settlements.clear()
	_hearth_returns.clear()
	_finish_on_tick.clear()
	_next_id = 1
	_next_name = 1
	if not (data is Dictionary):
		return
	_next_id = maxi(1, int((data as Dictionary).get("next_id", 1)))
	_next_name = maxi(1, int((data as Dictionary).get("next_name", 1)))
	var owed: Variant = (data as Dictionary).get("hearth_returns", {})
	if owed is Dictionary:
		for p: Variant in owed:
			if p is String and (owed[p] is int or owed[p] is float) and int(owed[p]) > 0 and _hearth_returns.size() < MAX_SETTLEMENTS:
				_hearth_returns[p] = clampi(int(owed[p]), 1, MAX_SETTLEMENTS)
	var raw: Variant = (data as Dictionary).get("settlements", {})
	if not (raw is Dictionary):
		return
	for id: Variant in (raw as Dictionary).keys():
		var s: Variant = raw[id]
		if _settlements.size() >= MAX_SETTLEMENTS or not (s is Dictionary) or not (s.get("members", null) is Dictionary):
			continue
		var members := {}
		for p: Variant in (s["members"] as Dictionary).keys():
			var role := str(s["members"][p])
			if members.size() < MAX_MEMBERS:
				members[str(p).left(64)] = role if ROLES.has(role) else "guest"
		var status := str(s.get("status", "founded"))
		var stock := {}
		if s.get("stock", null) is Dictionary:
			for item: Variant in (s["stock"] as Dictionary).keys():
				var n := int(s["stock"][item])
				if n > 0 and _known_item(str(item)):
					stock[str(item)] = mini(n, MAX_QTY * 100)
		var invites := {}
		if s.get("invites", null) is Dictionary:
			for p: Variant in (s["invites"] as Dictionary).keys():
				var at: Variant = s["invites"][p]
				if invites.size() < MAX_MEMBERS:
					# A legacy `true` (no time) starts its lapse clock at load.
					invites[str(p).left(64)] = float(at) if (at is float or at is int) and is_finite(float(at)) else float(now_sec.call())
		var taken := {}
		if s.get("taken", null) is Dictionary:
			for p: Variant in (s["taken"] as Dictionary).keys():
				var t: Variant = s["taken"][p]
				if t is Dictionary and taken.size() < MAX_MEMBERS:
					taken[str(p).left(64)] = { "day": int(t.get("day", 0)), "n": maxi(0, int(t.get("n", 0))) }
		if members.is_empty() or not is_finite(float(s.get("hx", 0.0))) or not is_finite(float(s.get("hz", 0.0))):
			continue
		_settlements[str(id).left(64)] = {
			"id": str(id).left(64), "name": str(s.get("name", "")).left(MAX_NAME), "name_n": clampi(int(s.get("name_n", 0)), 0, 1000000), "founder": str(s.get("founder", "")).left(64),
			"members": members, "invites": invites, "created": float(s.get("created", 0.0)),
			"last_active": float(s.get("last_active", now_sec.call())), "hx": float(s.get("hx", 0.0)), "hz": float(s.get("hz", 0.0)),
			# Phase 205 — an abandoned (decaying) settlement of an older save is founded again: nothing decays now.
			"status": status if TIER_ORDER.has(status) else "founded",
			"stock": stock, "taken": taken,
			# A format-1 (pre-198) record has no projects: it loads with none.
			"projects": _projects_from(s.get("projects", null)) if int((data as Dictionary).get("format", 1)) >= 2 else {},
		}
		# Phase 207 — a project saved with labour still to do and every material in completes on the first tick
		# (when the world can take its structure), found once here rather than looked for on every tick.
		for key: String in _settlements[str(id).left(64)]["projects"]:
			var p: Dictionary = _settlements[str(id).left(64)]["projects"][key]
			if str(p["status"]) != "done" and ProjectRules.is_complete(ProjectRules.def_of(key), p):
				_finish_on_tick.append([str(id).left(64), key])
		if WorldPos.pos_from_wire(s.get("hearth", null)).size() > 0:
			_settlements[str(id).left(64)]["hearth"] = (s["hearth"] as Dictionary).duplicate(true)
		# Phase 205 — a saved hearth is removed, and its founder is owed it back as a Hearth item
		# (`Clan.migration.hearth`, "returnToFounder").
		if s.get("hearth_station", null) is String and str(s["hearth_station"]) != "":
			if release_station.is_valid():
				release_station.call(str(s["hearth_station"]).left(64))
			var founder := str(s.get("founder", "")).left(64)
			if founder != "" and _hearth_returns.size() < MAX_SETTLEMENTS:
				_hearth_returns[founder] = int(_hearth_returns.get(founder, 0)) + 1
		_next_name = maxi(_next_name, int(_settlements[str(id).left(64)]["name_n"]) + 1)
		var suffix := str(id).trim_prefix("settlement_")
		if suffix.is_valid_int():
			_next_id = maxi(_next_id, int(suffix) + 1)   # never reuse a loaded id

## Saved projects, checked: unknown keys and materials dropped, counts clamped to what the project needs.
func _projects_from(raw: Variant) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		return out
	for k: Variant in (raw as Dictionary).keys():
		var p: Variant = raw[k]
		var def := ProjectRules.def_of(str(k))
		if def.is_empty() or not (p is Dictionary) or not (p.get("site", null) is Dictionary):
			continue
		var need := ProjectRules.needed_materials(def)
		var given := {}
		if p.get("given", null) is Dictionary:
			for item: Variant in (p["given"] as Dictionary).keys():
				if need.has(str(item)):
					given[str(item)] = clampi(int(p["given"][item]), 0, int(need[str(item)]))
		var contributors := {}
		if p.get("contributors", null) is Dictionary:
			for c: Variant in (p["contributors"] as Dictionary).keys():
				var e: Variant = p["contributors"][c]
				if e is Dictionary and contributors.size() < ProjectRules.MAX_CONTRIBUTORS:
					contributors[str(c).left(64)] = { "items": maxi(0, int(e.get("items", 0))) }
		var x := float(p["site"].get("x", 0.0))
		var z := float(p["site"].get("z", 0.0))
		if not is_finite(x) or not is_finite(z):
			continue
		out[str(k)] = { "key": str(k), "by": str(p.get("by", "")).left(64), "started": float(p.get("started", 0.0)), "site": { "x": x, "z": z },
			"given": given, "status": "done" if str(p.get("status", "")) == "done" else "building", "done_at": float(p.get("done_at", 0.0)),
			"contributors": contributors }
	return out

## A project as its members see it: what is needed and given, and who helped.
func _project_view(key: String, state: Dictionary) -> Dictionary:
	var def := ProjectRules.def_of(key)
	return { "key": key, "status": str(state["status"]), "need": ProjectRules.needed_materials(def), "given": (state["given"] as Dictionary).duplicate(),
		"contributors": (state["contributors"] as Dictionary).duplicate(true), "x": float(state["site"]["x"]), "z": float(state["site"]["z"]) }

# ── views ────────────────────────────────────────────────────────────────

## Sites anyone may see: id, name, centre, the SITE_REACH its stockpile and projects work within, tier. Sent to
## every peer (as `claims`, the view key since Phase 140; nothing is claimed since Phase 205).
func public_claims() -> Array:
	var out: Array = []
	for id: String in ids():
		var s: Dictionary = _settlements[id]
		out.append({ "id": id, "name": str(s["name"]), "name_n": int(s["name_n"]), "x": float(s["hx"]), "z": float(s["hz"]),
			"radius": SITE_REACH, "status": str(s["status"]) })
	return out

## What one player may see beyond the sites: their own settlement's members, role and stockpile, and any
## invites naming them. Sent to that player alone.
func private_view(player_id: String) -> Dictionary:
	var pid := _pid(player_id)
	var out := { "claims": public_claims(), "mine": {}, "invites": [] }
	var id := settlement_of(pid)
	if id != "":
		var s: Dictionary = _settlements[id]
		out["mine"] = { "id": id, "role": role_of(pid, id), "members": (s["members"] as Dictionary).duplicate(),
			"stock": stock_of(id), "capacity": capacity_stacks(id), "used": used_stacks(id), "names": _member_names(s), "specialties": _member_specialties(s), "specialty": compute_specialty(pid),
			"projects": (s["projects"] as Dictionary).keys().map(func(k: String) -> Dictionary: return _project_view(k, s["projects"][k])) }
	for sid: String in ids():
		if (_settlements[sid]["invites"] as Dictionary).has(pid):
			(out["invites"] as Array).append({ "id": sid, "name": str(_settlements[sid]["name"]), "name_n": int(_settlements[sid]["name_n"]) })
	return out

## Phase 181 — each member's display name ({ member key: name }), from the registry when it can tell.
func _member_names(s: Dictionary) -> Dictionary:
	var out := {}
	for m: Variant in (s["members"] as Dictionary).keys():
		if registry != null and registry.has_method("display_name"):
			out[m] = str(registry.display_name(str(m)))
	return out

## Phase 199 — each member's specialty ({ member key: specialty }), members with none left out.
func _member_specialties(s: Dictionary) -> Dictionary:
	var out := {}
	for m: Variant in (s["members"] as Dictionary).keys():
		var sp := compute_specialty(str(m))
		if sp != "":
			out[m] = sp
	return out

## A claim or invite entry's name in the active locale: its own text, or the numbered default.
static func display_name(entry: Dictionary) -> String:
	var n := int(entry.get("name_n", 0))
	return I18n.t("settlement.default_name", [n]) if n > 0 else str(entry.get("name", ""))

func apply_view(view: Variant) -> void:
	_view = view if view is Dictionary else {}

func view() -> Dictionary:
	return _view
