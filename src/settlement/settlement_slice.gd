extends Node
## Settlement slice — player-founded places (Phase 140, designed in Phase 139).
##
## A settlement is a `Hearth` placed on free land: a claimed circle, members with roles and a shared
## stockpile. The host decides everything; clients mirror a view (`apply_view`). Rules come from the
## fabric's `Settlement` world system (`GameData.WORLD_SYSTEMS["Settlement"].rules`).
##
## Plug contract (GameBus):
##   IN  : settlement_intent(action, args, player_id)
##   OUT : settlement_resolved(player_id, action, ok, reason), settlements_changed(),
##         settlement_project_changed(settlement_id, project, what, player_id)
##
## Positions are ground metres as doubles (`chunk * CHUNK_METERS + local`), so a claim far from the
## origin stays exact. Time is Unix seconds from `now_sec`; a "day" is 86,400 s.
##
## Public API (all host-side; a client calls none of them):
##   rules() / tier_rules(status) / claim_radius(id) / tier_for(id, now)
##   found(player_id, name, xz, consume) -> String      "" when founded, else a reason code
##   invite(actor, target) / join(player, id) / set_role(actor, target, role) / leave(player)
##   deposit(player, item, qty) / withdraw(player, item, qty)
##   start_project(actor, key) / contribute(actor, key, item, qty, source) / labour(actor, key)   (Phase 198)
##   edit_blocker(player_id, xz) -> String             "" when the edit is allowed
##   settlement_of(player_id) -> String                id of the settlement the player belongs to
##   tick(now)                                         grow, abandon, decay and free settlements

const I18n := preload("res://src/core/i18n.gd")
const WorldPos := preload("res://src/terrain/world_pos.gd")
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const SeamWrap := preload("res://src/terrain/seam_wrap.gd")
const ProjectRules := preload("res://src/settlement/project_rules.gd")
const RaidRules := preload("res://src/settlement/raid_rules.gd")
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
## Phase 198 — labour counts only within this many metres of a project's site.
const SITE_RADIUS := 8.0
## Phase 198 — a labour beat credits at most this many seconds since the last; a longer gap restarts the clock.
const LABOUR_GAP_SEC := 2.5
## Phase 198 — the settlement record's format: 2 added `projects` (a format-1 record loads with none).
const DATA_FORMAT := 3
const ACTIONS := ["found", "invite", "join", "role", "leave", "deposit", "withdraw", "uninvite",
	"project_start", "project_give", "project_work"]
const ROLES := ["founder", "elder", "member", "guest"]

## Every refusal code an action can return.
const REASONS := ["unknown_player", "rate_limited", "bad_args", "no_hearth", "already_member", "too_close",
	"too_many", "not_member", "no_permission", "unknown_settlement", "not_invited", "full", "bad_role",
	"founder_locked", "not_in_claim", "no_stock", "over_limit", "no_inventory", "too_far", "unknown_action", "durable", "no_such_invite",
	"unknown_project", "project_exists", "tier_too_low", "too_many_projects", "project_done", "unknown_item", "too_much",
	"labour_done", "no_tool"]

const DEFAULT_RULES := {
	"hearthStation": "hearth", "hearthItem": "Hearth", "guildMaxSettlements": 1,
	"tiers": {
		"founded": { "claimRadius": 24, "minMembers": 1, "minDays": 0 },
		"growing": { "claimRadius": 48, "minMembers": 3, "minDays": 3 },
		"town": { "claimRadius": 96, "minMembers": 8, "minDays": 14 },
	},
	"roles": {
		"founder": { "build": true, "take": true, "invite": true, "withdrawLimit": 0 },
		"elder": { "build": true, "take": true, "invite": true, "withdrawLimit": 200 },
		"member": { "build": true, "take": true, "invite": false, "withdrawLimit": 50 },
		"guest": { "build": false, "take": false, "invite": false, "withdrawLimit": 0 },
	},
	"stockpile": { "founded": { "capacityStacks": 20 }, "growing": { "capacityStacks": 60 }, "town": { "capacityStacks": 160 } },
	"abandonAfterDays": 30, "decayRadiusPerDay": 2, "minSeparation": 200,
}
const TIER_ORDER := ["founded", "growing", "town"]

## Set by game_root.
var registry: Node = null
var now_sec: Callable = func() -> float: return Time.get_unix_time_from_system()
## Monotonic seconds for the intent rate limit (a wall-clock jump must not lock or free a player).
var mono_sec: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0
## `(station_id) -> void`, set by the wiring: a decayed settlement's hearth station goes with it.
var release_station: Callable = Callable()
## Test seam: `(player_id) -> Variant` the player's ground position as a `Vector2` of metres, or null.
var position_of: Callable = Callable()

## id -> { id, name, founder, members {pid: role}, invites {pid: true}, created, last_active, hx, hz,
##         status, abandoned_at, stock {item: n}, taken {pid: {day, n}}, hearth_station }
## `invites` maps an invited player to the `now_sec` the invite was made (it lapses after INVITE_TTL_SEC).
var _settlements: Dictionary = {}
var _next_id: int = 1
## The next default-name number. Monotonic: it never falls when a settlement decays, so no two repeat.
var _next_name: int = 1
var _last_intent: Dictionary = {}
## id -> claim radius last announced for an abandoned (decaying) settlement.
var _radius_pushed: Dictionary = {}
## Phase 198 — `(player_id) -> bool` whether the player holds a tool (labour needs one); set by the wiring.
var tool_in_hand: Callable = Callable()
## Phase 198 — `(id, key, site {x, z}) -> void` places a finished structure in the claim (site in ground metres
## as doubles); set by the wiring.
var place_structure: Callable = Callable()
## pid -> { id, key, at } the last labour beat (mono seconds).
var _labour_clock: Dictionary = {}
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
	_labour_clock.erase(player_id)
	_specialties.erase(player_id)

# ── rules ────────────────────────────────────────────────────────────────

## The merged rule table, built once per fabric resource (claim_at and placement checks call this hot).
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

## The tier a settlement has earned: the highest whose member count holds and whose age threshold, or
## (Phase 198, for a tier with `minProjects`) completed-project count, holds.
func tier_for(id: String, now: float) -> String:
	var s: Dictionary = _settlements.get(id, {})
	if s.is_empty():
		return ""
	var tiers: Dictionary = rules()["tiers"]
	var days: float = maxf(0.0, now - float(s["created"])) / DAY_SEC
	var built := ProjectRules.completed_count(s.get("projects", {}))
	var best: String = "founded"
	for name: String in TIER_ORDER:
		var t: Dictionary = tiers.get(name, {})
		var aged: bool = days >= float(t.get("minDays", 0)) or (t.has("minProjects") and built >= int(t["minProjects"]))
		if (s["members"] as Dictionary).size() >= int(t.get("minMembers", 1)) and aged:
			best = name
	return best

## Metres the claim reaches now: the tier's radius, less what an abandoned claim has decayed.
func claim_radius(id: String) -> float:
	var s: Dictionary = _settlements.get(id, {})
	if s.is_empty():
		return 0.0
	var r := rules()
	var status := str(s["status"])
	var tier: String = "founded" if status == "abandoned" else status
	var radius := float((r["tiers"] as Dictionary).get(tier, {}).get("claimRadius", 0.0))
	if status == "abandoned":
		radius = float(s.get("abandoned_radius", radius))
		var days := maxf(0.0, float(now_sec.call()) - float(s["abandoned_at"])) / DAY_SEC
		radius -= days * float(r["decayRadiusPerDay"])
	return maxf(radius, 0.0)

func capacity_stacks(id: String) -> int:
	var s: Dictionary = _settlements.get(id, {})
	if s.is_empty():
		return 0
	var status := str(s["status"])
	var tier: String = "founded" if status == "abandoned" else status
	return int((rules()["stockpile"] as Dictionary).get(tier, {}).get("capacityStacks", 0)) \
		+ int(project_effect(id, "stockpileCapacity"))

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

## The hearth's exact `{chunk, local}` (empty for a settlement founded without one).
func hearth_exact(id: String) -> Dictionary:
	var s: Dictionary = _settlements.get(id, {})
	return WorldPos.pos_from_wire(s["hearth"]) if s.has("hearth") else {}

func _hearth_xz(s: Dictionary) -> Vector2:
	return Vector2(float(s["hx"]), float(s["hz"]))

## The settlement whose claim covers `xz`, or "".
func claim_at(xz: Vector2) -> String:
	for id: String in ids():
		if dist_m(_hearth_xz(_settlements[id]), xz) <= claim_radius(id):
			return id
	return ""

func _player_xz(player_id: String) -> Variant:
	if position_of.is_valid():
		return position_of.call(player_id)
	if registry == null:
		return null
	var pos: Dictionary = registry.get_world_pos(player_id)
	if pos.is_empty():
		return null
	return xz_of_exact(pos)

## Phase 200 — read-only helpers for the raid scheduler.
func hearth_xz(id: String) -> Vector2:
	return _hearth_xz(_settlements[id]) if _settlements.has(id) else Vector2.ZERO

func is_member(player_id: String, id: String) -> bool:
	return role_of(_pid(player_id), id) != "" and role_of(_pid(player_id), id) != "guest"

func player_xz(player_id: String) -> Variant:
	return _player_xz(player_id)

func _pid(player_id: String) -> String:
	if player_id == "" and registry != null and "local_player_id" in registry:
		return str(registry.local_player_id)
	return player_id

func _inventory(player_id: String) -> Node:
	if registry != null and registry.has_method("get_inventory"):
		return registry.get_inventory(_pid(player_id))
	return null

# ── founding ─────────────────────────────────────────────────────────────

## Why a hearth cannot be set at `xz` ("" when the land is free): a hearth must stay `minSeparation`
## from every other, so no two claims overlap.
func founding_blocker(xz: Vector2) -> String:
	if _settlements.size() >= MAX_SETTLEMENTS:
		return "too_many"
	var sep := float(rules()["minSeparation"])
	for id: String in ids():
		if dist_m(_hearth_xz(_settlements[id]), xz) < sep:
			return "too_close"
	return ""

## Found a settlement for `player_id` at `xz`. `consume` takes the Hearth item from the pack (false when
## the station placement already did). `exact` is the hearth's `{chunk, local}` when the caller has it:
## `xz` is a float32 `Vector2`, coarse far from the origin, so the exact position is what is saved.
## `auto_name` gives the settlement no text name but a number (`name_n`) clients render as the localized
## default name ("Settlement 3"); the host never renders text in its own locale.
func found(player_id: String, sname: String, xz: Vector2, consume: bool = true, exact: Dictionary = {}, auto_name: bool = false) -> String:
	var pid := _pid(player_id)
	if pid == "":
		return "unknown_player"
	sname = "" if auto_name else sname.strip_edges().left(MAX_NAME)
	if sname == "" and not auto_name:
		return "bad_args"
	if settlement_of(pid) != "":
		return "already_member"
	var why := founding_blocker(xz)
	if why != "":
		return why
	if consume:
		var inv := _inventory(pid)
		var item := str(rules()["hearthItem"])
		if inv == null or not inv.has_method("consume_items") or inv.get_item_count(item) < 1 or not inv.consume_items({ item: 1 }):
			return "no_hearth"
		_push_inventory(pid)
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
		"abandoned_at": 0.0, "abandoned_radius": 0.0, "stock": {}, "taken": {}, "projects": {}, "raid": { "last_end": 0.0, "last_result": "" },
	}
	if WorldPos.is_plausible_pos(exact):
		_settlements[id]["hearth"] = WorldPos.pos_to_wire(exact)
		# Components stay doubles: a `Vector2` is float32 and would snap a far hearth to metres.
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

## The station that is `id`'s hearth, released with it when the settlement decays away.
func note_hearth_station(id: String, station_id: String) -> void:
	if _settlements.has(id):
		_settlements[id]["hearth_station"] = station_id

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

func _in_own_claim(pid: String, id: String) -> bool:
	var xz: Variant = _player_xz(pid)
	return xz is Vector2 and dist_m(_hearth_xz(_settlements[id]), xz as Vector2) <= claim_radius(id)

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
	if not _in_own_claim(pid, id):
		return "not_in_claim"
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
	if not _in_own_claim(pid, id):
		return "not_in_claim"
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
## while they stand in its claim. 0 otherwise.
func research_stock(player_id: String, item: String) -> int:
	var pid := _pid(player_id)
	var id := settlement_of(pid)
	if id == "" or not bool(role_rules(role_of(pid, id))["take"]) or not _in_own_claim(pid, id):
		return 0
	return int((_settlements[id]["stock"] as Dictionary).get(item, 0))

## Whether `player_id` stands at their settlement's hearth claim (a research site).
func at_research_site(player_id: String) -> bool:
	var pid := _pid(player_id)
	var id := settlement_of(pid)
	return id != "" and _in_own_claim(pid, id)

## Take research materials from the player's stockpile: all or nothing.
func consume_research(player_id: String, counts: Dictionary) -> bool:
	var pid := _pid(player_id)
	var id := settlement_of(pid)
	if id == "" or not at_research_site(pid):
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

# ── edits ────────────────────────────────────────────────────────────────

## "" when `player_id` may mine or place at ground point `xz`; else a reason. Land outside every claim is
## free; inside one, only a member whose role has `build` may edit. A pure query (the placement preview
## asks it too): the edit itself is recorded by `note_edit` once it succeeded.
func edit_blocker(player_id: String, xz: Vector2) -> String:
	var id := claim_at(xz)
	if id == "":
		return ""
	var role := role_of(_pid(player_id), id)
	if role == "" or not bool(role_rules(role)["build"]):
		return "no_permission"
	return ""

## A successful edit at `xz` by `player_id`: counts as activity for the claim it landed in.
func note_edit(player_id: String, xz: Vector2) -> void:
	var id := claim_at(xz)
	if id != "" and edit_blocker(player_id, xz) == "":
		_touch(id)

# ── projects (Phase 198) ─────────────────────────────────────────────────

## Standing projects' effect `kind` for settlement `id` (see ProjectRules.EFFECT_KINDS).
func project_effect(id: String, kind: String) -> float:
	return ProjectRules.effect_total(_settlements.get(id, {}).get("projects", {}), kind)

func projects_of(id: String) -> Dictionary:
	return (_settlements.get(id, {}).get("projects", {}) as Dictionary).duplicate(true)

## Start project `key` at the actor's feet (or at `site`, a host-side caller's ground point; an intent never
## names one). Needs a role with `invite`, the site in the claim, and the tier.
func start_project(actor: String, key: String, site: Variant = null) -> String:
	var pid := _pid(actor)
	var id := settlement_of(pid)
	if id == "":
		return "not_member"
	if not bool(role_rules(role_of(pid, id))["invite"]):
		return "no_permission"
	var xz: Variant = site if site is Vector2 else _player_xz(pid)
	if not (xz is Vector2) or dist_m(_hearth_xz(_settlements[id]), xz as Vector2) > claim_radius(id):
		return "not_in_claim"
	var s: Dictionary = _settlements[id]
	var tier: String = "founded" if str(s["status"]) == "abandoned" else str(s["status"])
	var why := ProjectRules.start_blocker(key, tier, s["projects"])
	if why != "":
		return why
	s["projects"][key] = { "key": key, "by": pid, "started": float(now_sec.call()), "site": { "x": (xz as Vector2).x, "z": (xz as Vector2).y },
		"given": {}, "work": 0.0, "status": "building", "done_at": 0.0, "contributors": {} }
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
	if not _in_own_claim(pid, id):
		return "not_in_claim"
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
	_credit(state, pid, "items", qty)
	_touch(id)
	GameBus.settlement_project_changed.emit(id, key, "contributed", pid)
	_maybe_complete(id, key)
	GameBus.settlements_changed.emit()
	return ""

## One labour beat on project `key`: the actor works at the site with a tool in hand. The first beat starts
## the clock; each next one within LABOUR_GAP_SEC credits the time since the last (at most LABOUR_GAP_SEC),
## so a client sending beats faster or slower earns no more than standing there. Work units are
## ProjectRules.work_units(seconds).
func labour(actor: String, key: String) -> String:
	var pid := _pid(actor)
	var id := settlement_of(pid)
	if id == "":
		return "not_member"
	if not bool(role_rules(role_of(pid, id))["build"]):
		return "no_permission"
	var s: Dictionary = _settlements[id]
	var state: Dictionary = (s["projects"] as Dictionary).get(key, {})
	var def := ProjectRules.def_of(key)
	if def.is_empty() or state.is_empty():
		return "unknown_project"
	if str(state["status"]) == "done":
		return "project_done"
	if float(state["work"]) >= ProjectRules.total_work(def):
		return "labour_done"
	var xz: Variant = _player_xz(pid)
	var site := Vector2(float(state["site"]["x"]), float(state["site"]["z"]))
	if not (xz is Vector2) or dist_m(site, xz as Vector2) > SITE_RADIUS:
		return "too_far"
	if not tool_in_hand.is_valid() or not bool(tool_in_hand.call(pid)):
		return "no_tool"
	var now := float(mono_sec.call())
	var clock: Dictionary = _labour_clock.get(pid, {})
	_labour_clock[pid] = { "id": id, "key": key, "at": now }
	if clock.is_empty() or str(clock["id"]) != id or str(clock["key"]) != key or now - float(clock["at"]) > LABOUR_GAP_SEC:
		return ""   # the clock starts: nothing credited yet
	var units := ProjectRules.work_units(minf(now - float(clock["at"]), LABOUR_GAP_SEC)) * labour_bonus(pid, def, float(state["work"]))
	units = minf(units, ProjectRules.total_work(def) - float(state["work"]))
	state["work"] = float(state["work"]) + units
	_credit(state, pid, "work", units)
	_touch(id)
	_maybe_complete(id, key)
	GameBus.settlements_changed.emit()
	return ""

## Labour multiplier for `pid` on the step `work` falls in. 1.0 until specialties (Phase 199).
func labour_bonus(pid: String, def: Dictionary, work: float) -> float:
	return SpecialtyRules.labour_multiplier(compute_specialty(pid), str(ProjectRules.current_step(def, work)["specialty"]))

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

func _credit(state: Dictionary, pid: String, field: String, n: float) -> void:
	var c: Dictionary = state["contributors"]
	if not c.has(pid):
		if c.size() >= ProjectRules.MAX_CONTRIBUTORS:
			return
		c[pid] = { "items": 0, "work": 0.0 }
	c[pid][field] = (int(c[pid][field]) + int(n)) if field == "items" else (float(c[pid][field]) + n)

## A project with every material and every step finishes: its structure is placed (`place_structure`) and
## its effects stand from now on.
func _maybe_complete(id: String, key: String) -> void:
	var state: Dictionary = _settlements[id]["projects"][key]
	if str(state["status"]) == "done" or not ProjectRules.is_complete(ProjectRules.def_of(key), state):
		return
	state["status"] = "done"
	state["done_at"] = float(now_sec.call())
	if place_structure.is_valid():
		place_structure.call(id, key, (state["site"] as Dictionary).duplicate())
	GameBus.settlement_project_changed.emit(id, key, "completed", "")
	tick(float(now_sec.call()))   # a completed project may promote the tier at once

# ── lifecycle ────────────────────────────────────────────────────────────

func _touch(id: String) -> void:
	var s: Dictionary = _settlements[id]
	if str(s["status"]) == "abandoned":
		_reclaim(s)
	s["last_active"] = float(now_sec.call())

func _reclaim(s: Dictionary) -> void:
	if claim_radius(str(s["id"])) <= 0.0:
		return
	s["status"] = "founded"
	s["abandoned_at"] = 0.0
	GameBus.settlements_changed.emit()

## Note that `player_id` is active at their settlement (standing in the claim).
func note_activity(player_id: String) -> void:
	var pid := _pid(player_id)
	var id := settlement_of(pid)
	if id != "" and _in_own_claim(pid, id):
		_touch(id)

## Grow, abandon, decay and free settlements as of `now`. Returns true when anything changed.
func tick(now: float) -> bool:
	var changed := false
	var r := rules()
	for id: String in ids():
		var s: Dictionary = _settlements[id]
		var status := str(s["status"])
		if _lapse_invites(s, now):
			changed = true
		if status == "abandoned":
			var radius := claim_radius(id)
			if radius <= 0.0:
				_settlements.erase(id)   # the land is free again
				_radius_pushed.erase(id)
				# Its hearth goes too, or a station would stand on free land owned by nobody.
				var hearth_id := str(s.get("hearth_station", ""))
				if hearth_id != "" and release_station.is_valid():
					release_station.call(hearth_id)
				changed = true
			elif int(radius) != int(_radius_pushed.get(id, radius)):
				changed = true   # the decaying claim shrank a whole metre: clients redraw it
			_radius_pushed[id] = radius
			continue
		if now - float(s["last_active"]) >= float(r["abandonAfterDays"]) * DAY_SEC:
			s["abandoned_radius"] = claim_radius(id)
			s["status"] = "abandoned"
			s["abandoned_at"] = now
			changed = true
			continue
		var tier := tier_for(id, now)
		if TIER_ORDER.find(tier) > TIER_ORDER.find(status):
			s["status"] = tier   # tiers never shrink: a settlement that lost members keeps what it earned
			changed = true
	if changed:
		GameBus.settlements_changed.emit()
	return changed

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
		"found":
			var xz: Variant = _player_xz(pid)
			if not (xz is Vector2):
				return "unknown_player"
			return found(pid, str(args.get("name", "")), xz as Vector2, true)
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
		"project_work":
			return labour(pid, str(args.get("project", "")).left(32))
	return "unknown_action"

## Items and materials both live in a pack (a mined material is an item there).
static func _known_item(item: String) -> bool:
	return GameData.ITEMS.has(item) or GameData.MATERIALS.has(item)

static func _qty(v: Variant) -> int:
	return int(v) if (v is int or v is float) else 0

# ── persistence ──────────────────────────────────────────────────────────

func to_data() -> Dictionary:
	return { "format": DATA_FORMAT, "next_id": _next_id, "next_name": _next_name, "settlements": _settlements.duplicate(true) }

## Restore from a saved world record. Malformed entries are skipped; numbers are clamped.
func from_data(data: Variant) -> void:
	_settlements.clear()
	_next_id = 1
	_next_name = 1
	if not (data is Dictionary):
		return
	_next_id = maxi(1, int((data as Dictionary).get("next_id", 1)))
	_next_name = maxi(1, int((data as Dictionary).get("next_name", 1)))
	_radius_pushed.clear()
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
			"status": status if (TIER_ORDER + ["abandoned"]).has(status) else "founded",
			"abandoned_at": float(s.get("abandoned_at", 0.0)), "abandoned_radius": float(s.get("abandoned_radius", 0.0)),
			"stock": stock, "taken": taken,
			# A format-1 (pre-198) record has no projects: it loads with none.
			"projects": _projects_from(s.get("projects", null)) if int((data as Dictionary).get("format", 1)) >= 2 else {},
			# A pre-200 record has no raid record: it loads as never raided.
			"raid": _raid_from(s.get("raid", null)) if int((data as Dictionary).get("format", 1)) >= 3 else { "last_end": 0.0, "last_result": "" },
		}
		if WorldPos.pos_from_wire(s.get("hearth", null)).size() > 0:
			_settlements[str(id).left(64)]["hearth"] = (s["hearth"] as Dictionary).duplicate(true)
		if s.get("hearth_station", null) is String:
			_settlements[str(id).left(64)]["hearth_station"] = str(s["hearth_station"]).left(64)
		_next_name = maxi(_next_name, int(_settlements[str(id).left(64)]["name_n"]) + 1)
		var suffix := str(id).trim_prefix("settlement_")
		if suffix.is_valid_int():
			_next_id = maxi(_next_id, int(suffix) + 1)   # never reuse a loaded id

## Phase 200 — the raid record of a settlement: { last_end (seconds, 0 = never raided), last_result "" | "defended" | "lost" }.
func raid_record(id: String) -> Dictionary:
	return (_settlements.get(id, {}).get("raid", { "last_end": 0.0, "last_result": "" }) as Dictionary).duplicate()

## Phase 200 — the raid ended: `defended` or lost. A lost raid takes the capped, defence-scaled share of the
## stockpile and of each unfinished project's contributed labour (RaidRules.losses). Records the end time (the
## cooldown) and the result. Returns { result, stock {item: n}, damage (labour units lost) }; {} for no such settlement.
func end_raid(id: String, defended: bool) -> Dictionary:
	if not _settlements.has(id):
		return {}
	var s: Dictionary = _settlements[id]
	var lost := RaidRules.losses(defended, s["stock"], project_effect(id, "raidDefence"))
	var damage := 0.0
	for item: String in lost["stock"]:
		s["stock"][item] = int(s["stock"][item]) - int(lost["stock"][item])
		if int(s["stock"][item]) <= 0:
			(s["stock"] as Dictionary).erase(item)
	if float(lost["project_damage"]) > 0.0:
		for key: String in s["projects"]:
			var p: Dictionary = s["projects"][key]
			if str(p["status"]) == "done":
				continue
			var cut := floorf(float(p["work"]) * float(lost["project_damage"]))
			p["work"] = float(p["work"]) - cut
			damage += cut
	s["raid"] = { "last_end": float(now_sec.call()), "last_result": "defended" if defended else "lost" }
	_touch(id)
	GameBus.settlements_changed.emit()
	return { "result": s["raid"]["last_result"], "stock": lost["stock"], "damage": damage }

## Saved raid record, checked.
static func _raid_from(raw: Variant) -> Dictionary:
	var out := { "last_end": 0.0, "last_result": "" }
	if raw is Dictionary:
		var res := str((raw as Dictionary).get("last_result", ""))
		if res in ["defended", "lost"]:
			out["last_result"] = res
		var t := float((raw as Dictionary).get("last_end", 0.0))
		out["last_end"] = t if is_finite(t) and t > 0.0 else 0.0
	return out

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
					contributors[str(c).left(64)] = { "items": maxi(0, int(e.get("items", 0))), "work": maxf(0.0, float(e.get("work", 0.0))) }
		var x := float(p["site"].get("x", 0.0))
		var z := float(p["site"].get("z", 0.0))
		if not is_finite(x) or not is_finite(z):
			continue
		out[str(k)] = { "key": str(k), "by": str(p.get("by", "")).left(64), "started": float(p.get("started", 0.0)), "site": { "x": x, "z": z },
			"given": given, "work": clampf(float(p.get("work", 0.0)), 0.0, ProjectRules.total_work(def)),
			"status": "done" if str(p.get("status", "")) == "done" else "building", "done_at": float(p.get("done_at", 0.0)),
			"contributors": contributors }
	return out

## A project as its members see it: what is needed, given and worked, the current step and who helped.
func _project_view(key: String, state: Dictionary) -> Dictionary:
	var def := ProjectRules.def_of(key)
	return { "key": key, "status": str(state["status"]), "need": ProjectRules.needed_materials(def), "given": (state["given"] as Dictionary).duplicate(),
		"work": float(state["work"]), "total_work": ProjectRules.total_work(def), "step": ProjectRules.current_step(def, float(state["work"]))["step"],
		"contributors": (state["contributors"] as Dictionary).duplicate(true), "x": float(state["site"]["x"]), "z": float(state["site"]["z"]) }

# ── views ────────────────────────────────────────────────────────────────

## Claims anyone may see: id, name, centre, radius, tier. Sent to every peer.
func public_claims() -> Array:
	var out: Array = []
	for id: String in ids():
		var s: Dictionary = _settlements[id]
		out.append({ "id": id, "name": str(s["name"]), "name_n": int(s["name_n"]), "x": float(s["hx"]), "z": float(s["hz"]),
			"radius": claim_radius(id), "status": str(s["status"]) })
	return out

## What one player may see beyond the claims: their own settlement's members, role and stockpile, and any
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
