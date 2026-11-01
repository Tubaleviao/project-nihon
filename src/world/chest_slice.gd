extends Node
## Chest slice (Phase 208) — the host's chests and doors: who owns each one, its access mode, a chest's items,
## its lock, timed lock picks, and breaking one open. The fabric's `ChestsAndDoors` table (`ChestRules`) sets
## the numbers. A chest or door is a placed station (`StationSlice`) of a `ChestRules.station_types()` type;
## this slice keeps the rest by station id.
##
## Access (`may_open`): the owner always (for a clan's: every member); mode `clan` adds the owner's clan's
## members; `everyone` adds anyone. A door also lets in whoever `StructureSlice.may_enter` lets into the
## structure it stands on (a clan member at another member's private house in the clan's territory). A
## picked lock lets its picker in until they close it or walk away. Only an owner changes the mode.
##
## Breaking: a hit takes `StructureRules.hit_damage` (the held tool's method against the lock material,
## slowed while every owner is offline) off the lock's durability (`ChestRules.lock_durability`). At zero the
## station is removed and a chest spills everything it held for anyone to take. A destroyer gets nothing else.
##
## Every refusal is a code in REASONS (`chest.refused.<code>` in the catalog).

const ChestRules := preload("res://src/world/chest_rules.gd")
const StructureRules := preload("res://src/structure/structure_rules.gd")
const WorkSkills := preload("res://src/character/work_skills.gd")
const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")

const DATA_FORMAT := 1
const REASONS := ["no_lock", "far", "locked", "not_owner", "bad_mode", "bad_args", "no_stock", "full", "durable",
	"no_tool", "busy", "not_locked", "rate", "no_inventory", "not_open", "blocked"]
## Metres from a chest or door at which a player may use, pick or hit it.
const REACH_M := 3.0
## A pick is cancelled when its picker moves this far from where they started.
const MOVE_CANCEL_M := 1.0
## Seconds between two hits of one player (a held key cannot outrun the host).
const HIT_GAP_SEC := 0.4
## A cap on chests and doors in one world and on an item count in one move.
const MAX_LOCKS := 65536
const MAX_QTY := 100000
const STACK_SIZE := 100

## Set by the wiring (host). `registry`: inventories, skills and who is online; `clans`: clan membership;
## `structures`: the structure index doors ask about.
var registry: Object = null
var clans: Object = null
var structures: Object = null
## `(player_id, tech) -> bool`: whether the player knows a technology (the lock they place uses the best).
var tech_known: Callable = Callable()
## `(player_id) -> Variant`: the player's float world position (Vector3), or null.
var position_of: Callable = Callable()
## `(player_id) -> String`: "private" or "clan", who owns what that player builds (`StructureSlice.build_mode`).
var build_mode_of: Callable = Callable()
## `(item, qty, position)`: a stack on the ground for anyone (`LootSlice.spawn_pickup`).
var spill: Callable = Callable()
## `(station_id)`: take the station out of the world (`StationSlice.remove_station`).
var remove_station: Callable = Callable()
## `(player_id, type, offset: Vector3) -> String`: place a chest or door for a client (the wiring's `place_for`).
var place_for: Callable = Callable()
## `() -> float` in [0, 1): the roll a failed pick's tool break is decided by. Test seam.
var roll: Callable = Callable()
## `() -> float` monotonic seconds. Test seam.
var mono_sec: Callable = Callable()
var is_host: bool = true

## station id -> { type, kind ("private" | "clan"), owner (pid | clan id), mode, items {item: n}, material,
##                 tech, hp, max_hp, pos (Vector3) }
var _locks: Dictionary = {}
## station id -> { pid: true }: players a picked lock lets in until they close it or walk away.
var _grants: Dictionary = {}
## pid -> { id, remaining, origin (Vector3), diff, tool }: picks in progress.
var _picks: Dictionary = {}
var _last_hit: Dictionary = {}
## pid -> station id the player has open (the window's chest), for pushing views and walking away.
var _open: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	if not GameBus.chest_intent.is_connected(_on_intent):
		GameBus.chest_intent.connect(_on_intent)

func _exit_tree() -> void:
	if GameBus.chest_intent.is_connected(_on_intent):
		GameBus.chest_intent.disconnect(_on_intent)

func _now() -> float:
	return float(mono_sec.call()) if mono_sec.is_valid() else Time.get_ticks_msec() / 1000.0

func _roll() -> float:
	return float(roll.call()) if roll.is_valid() else _rng.randf()

func _pid(player_id: String) -> String:
	if player_id == "" and registry != null and "local_player_id" in registry:
		return str(registry.local_player_id)
	return player_id

func _clan_of(pid: String) -> String:
	return str(clans.clan_of(pid)) if clans != null and pid != "" else ""

func _inventory(pid: String) -> Node:
	return registry.get_inventory(pid) if registry != null and registry.has_method("get_inventory") else null

func _pos_of(pid: String) -> Variant:
	return position_of.call(pid) if position_of.is_valid() else null

# ── queries ──────────────────────────────────────────────────────────────

func has_lock(id: String) -> bool:
	return _locks.has(id)

func get_lock(id: String) -> Dictionary:
	return _locks.get(id, {})

func ids() -> Array:
	var out: Array = _locks.keys()
	out.sort()
	return out

func items_of(id: String) -> Dictionary:
	return (_locks.get(id, {}).get("items", {}) as Dictionary).duplicate()

func used_stacks(id: String) -> int:
	var n := 0
	var items: Dictionary = _locks.get(id, {}).get("items", {})
	for item: String in items:
		n += ceili(float(items[item]) / STACK_SIZE)
	return n

## Every player who owns `id`: its placer for a private one, every member for a clan's.
func owner_ids(id: String) -> Array:
	var l: Dictionary = _locks.get(id, {})
	if l.is_empty():
		return []
	if str(l["kind"]) == "private":
		return [str(l["owner"])]
	return (clans.get_clan(str(l["owner"])).get("members", {}) as Dictionary).keys() if clans != null else []

func is_owner(player_id: String, id: String) -> bool:
	var l: Dictionary = _locks.get(id, {})
	var pid := _pid(player_id)
	if l.is_empty() or pid == "":
		return false
	if str(l["kind"]) == "private":
		return str(l["owner"]) == pid
	return _clan_of(pid) == str(l["owner"])

func _owners_offline(id: String) -> bool:
	for pid: String in owner_ids(id):
		if registry != null and registry.has_method("is_online") and bool(registry.is_online(pid)):
			return false
	return true

## Whether `player_id` may open (a chest) or pass (a door) `id` by its access mode, the door rule or a grant.
func may_open(player_id: String, id: String) -> bool:
	var l: Dictionary = _locks.get(id, {})
	var pid := _pid(player_id)
	if l.is_empty() or pid == "":
		return false
	if is_owner(pid, id) or (_grants.get(id, {}) as Dictionary).has(pid):
		return true
	match str(l["mode"]):
		"everyone":
			return true
		"clan":
			var clan := _clan_of(pid)
			var owner_clan := str(l["owner"]) if str(l["kind"]) == "clan" else _clan_of(str(l["owner"]))
			if clan != "" and clan == owner_clan:
				return true
	return not ChestRules.holds_items(str(l["type"])) and _may_enter_under(pid, l)

## A door: whether the structure it stands on lets `pid` in (`StructureSlice.may_enter`).
func _may_enter_under(pid: String, l: Dictionary) -> bool:
	if structures == null or not structures.has_method("structure_at"):
		return false
	var pos: Vector3 = l["pos"]
	var tile := Vector2i(floori(pos.x / VoxelConsts.TILE_SIZE), floori(pos.z / VoxelConsts.TILE_SIZE))
	var sid := int(structures.structure_at(tile, pos.y - VoxelConsts.STEP_HEIGHT * 0.5))
	return sid != 0 and bool(structures.may_enter(pid, sid))

## The lock's difficulty (`ChestRules.difficulty` of its material and technology).
func difficulty(id: String) -> float:
	var l: Dictionary = _locks.get(id, {})
	return ChestRules.difficulty(str(l.get("material", "")), str(l.get("tech", "none"))) if not l.is_empty() else 0.0

## The nearest chest or door within REACH_M of `pos`, or "".
func nearest(pos: Vector3, reach: float = REACH_M) -> String:
	var best := ""
	var best_d := reach
	for id: String in _locks:
		var d := pos.distance_to(_locks[id]["pos"] as Vector3)
		if d <= best_d:
			best_d = d
			best = id
	return best

func _within(pid: String, id: String) -> bool:
	var here: Variant = _pos_of(pid)
	return here is Vector3 and (here as Vector3).distance_to(_locks[id]["pos"] as Vector3) <= REACH_M

func pick_of(player_id: String) -> Dictionary:
	return (_picks.get(_pid(player_id), {}) as Dictionary).duplicate()

func open_of(player_id: String) -> String:
	return str(_open.get(_pid(player_id), ""))

# ── placing and removing ─────────────────────────────────────────────────

## Host: a station of a chest or door type was placed by `player_id` at `pos`: it becomes theirs (or their
## clan's when they build for their clan), in the default mode, with the lock of the best technology they know.
func register(id: String, type: String, pos: Vector3, player_id: String) -> bool:
	var pid := _pid(player_id)
	if not ChestRules.is_lock_type(type) or pid == "" or _locks.has(id) or _locks.size() >= MAX_LOCKS:
		return false
	var kind := "private"
	var owner := pid
	if build_mode_of.is_valid() and str(build_mode_of.call(pid)) == "clan" and _clan_of(pid) != "":
		kind = "clan"
		owner = _clan_of(pid)
	var tech := ChestRules.best_technology(func(t: String) -> bool: return tech_known.is_valid() and bool(tech_known.call(pid, t)))
	_add(id, type, kind, owner, ChestRules.default_mode(), {}, tech, pos)
	return true

## Host: a clan chest holding `items` at `pos` (a migrated settlement's stockpile, `Clan.migration.stockpile`).
func register_clan_chest(id: String, type: String, pos: Vector3, clan_id: String, items: Dictionary) -> bool:
	if not ChestRules.holds_items(type) or clan_id == "" or _locks.has(id) or _locks.size() >= MAX_LOCKS:
		return false
	_add(id, type, "clan", clan_id, ChestRules.default_mode(), _clean_items(items), "none", pos)
	return true

func _add(id: String, type: String, kind: String, owner: String, mode: String, items: Dictionary, tech: String, pos: Vector3, hp: float = -1.0) -> void:
	var material := ChestRules.lock_material(type)
	var max_hp := ChestRules.lock_durability(material, tech)
	_locks[id] = { "type": type, "kind": kind, "owner": owner, "mode": mode, "items": items, "material": material,
		"tech": tech, "max_hp": max_hp, "hp": max_hp if hp < 0.0 else clampf(hp, 0.0, max_hp), "pos": pos }

## Host: the station `id` left the world. A chest's items are never lost: they spill where it stood.
func forget(id: String) -> void:
	if not _locks.has(id):
		return
	var l: Dictionary = _locks[id]
	_spill(l)
	_locks.erase(id)
	_grants.erase(id)
	for pid: String in _picks.keys():
		if str(_picks[pid]["id"]) == id:
			_picks.erase(pid)
	for pid: String in _open.keys():
		if str(_open[pid]) == id:
			_open.erase(pid)

func _spill(l: Dictionary) -> void:
	var items: Dictionary = l["items"]
	if spill.is_valid():
		for item: String in items:
			if int(items[item]) > 0:
				spill.call(item, int(items[item]), l["pos"])
	items.clear()

## `/regen world` replaced the ground: every chest and door is gone with it.
func clear_all() -> void:
	_locks.clear()
	_grants.clear()
	_picks.clear()
	_open.clear()

# ── actions ──────────────────────────────────────────────────────────────

## Open the chest `id` (or pass the door `id`). "" when allowed.
func open(player_id: String, id: String) -> String:
	var pid := _pid(player_id)
	if not _locks.has(id):
		return "no_lock"
	if not _within(pid, id):
		return "far"
	if not may_open(pid, id):
		return "locked"
	if ChestRules.holds_items(str(_locks[id]["type"])) or is_owner(pid, id):
		_open[pid] = id
	elif (_grants.get(id, {}) as Dictionary).has(pid):
		(_grants[id] as Dictionary).erase(pid)   # a picked door lets its picker through once
	return ""

## Close what `player_id` has open; a picked lock locks behind its picker.
func close(player_id: String) -> void:
	var pid := _pid(player_id)
	var id := str(_open.get(pid, ""))
	_open.erase(pid)
	if _grants.has(id):
		(_grants[id] as Dictionary).erase(pid)

## Only an owner sets the mode, to one of `ChestRules.modes()`.
func set_mode(player_id: String, id: String, mode: String) -> String:
	var pid := _pid(player_id)
	if not _locks.has(id):
		return "no_lock"
	if not is_owner(pid, id):
		return "not_owner"
	if not ChestRules.modes().has(mode):
		return "bad_mode"
	_locks[id]["mode"] = mode
	return ""

## Move `qty` of `item` from the player's pack into the chest. All or nothing.
func put(player_id: String, id: String, item: String, qty: int) -> String:
	var pid := _pid(player_id)
	var why := _may_use_items(pid, id, item, qty)
	if why != "":
		return why
	var inv := _inventory(pid)
	if inv.has_method("is_durable") and inv.is_durable(item):
		return "durable"   # a chest counts units, so wear would be lost: a worn tool would come back new
	if int(inv.get_item_count(item)) < qty:
		return "no_stock"
	var items: Dictionary = _locks[id]["items"]
	var had := int(items.get(item, 0))
	var after := used_stacks(id) - ceili(float(had) / STACK_SIZE) + ceili(float(had + qty) / STACK_SIZE)
	if after > ChestRules.capacity_stacks(str(_locks[id]["type"])):
		return "full"
	if not inv.consume_items({ item: qty }):
		return "no_stock"
	items[item] = had + qty
	return ""

## Move `qty` of `item` from the chest into the player's pack. All or nothing.
func take(player_id: String, id: String, item: String, qty: int) -> String:
	var pid := _pid(player_id)
	var why := _may_use_items(pid, id, item, qty)
	if why != "":
		return why
	var items: Dictionary = _locks[id]["items"]
	if int(items.get(item, 0)) < qty:
		return "no_stock"
	if not _inventory(pid).add_item(item, qty):
		return "full"
	items[item] = int(items[item]) - qty
	if int(items[item]) <= 0:
		items.erase(item)
	return ""

func _may_use_items(pid: String, id: String, item: String, qty: int) -> String:
	if not _locks.has(id) or not ChestRules.holds_items(str(_locks[id]["type"])):
		return "no_lock"
	if item == "" or item.length() > 64 or qty < 1 or qty > MAX_QTY:
		return "bad_args"
	if not _within(pid, id):
		return "far"
	if not may_open(pid, id):
		return "locked"
	if str(_open.get(pid, "")) != id:
		return "not_open"
	var inv := _inventory(pid)
	if inv == null or not inv.has_method("consume_items") or not inv.has_method("add_item"):
		return "no_inventory"
	return ""

## Start picking the lock of `id` with a tool of `ChestRules.tool_type()` from the pack. Takes
## `ChestRules.pick_seconds` (harder locks longer, a better Lockpicking level shorter); `tick` finishes it.
func start_pick(player_id: String, id: String) -> String:
	var pid := _pid(player_id)
	if not _locks.has(id):
		return "no_lock"
	if _picks.has(pid):
		return "busy"
	if not _within(pid, id):
		return "far"
	if may_open(pid, id):
		return "not_locked"
	var inv := _inventory(pid)
	var tool := str(inv.find_tool(ChestRules.tool_type())) if inv != null and inv.has_method("find_tool") else ""
	if tool == "":
		return "no_tool"
	var diff := difficulty(id)
	var skill := str(WorkSkills.row("lockpick").get("skill", "Lockpicking"))
	var xp := int(registry.get_skill_xp(pid, skill)) if registry != null and registry.has_method("get_skill_xp") else 0
	var s: Resource = GameData.SKILLS.get(skill, null)
	var cap := int(s.get("levelCap")) if s != null and s.get("levelCap") != null else 1
	_picks[pid] = { "id": id, "remaining": ChestRules.pick_seconds(diff, StructureRules.level_for_xp(skill, xp), cap),
		"origin": _pos_of(pid), "diff": diff, "tool": tool }
	GameBus.lock_pick_started.emit(pid, id, float(_picks[pid]["remaining"]))
	return ""

## Seconds the pick `pid` started needs (0 for none).
func pick_seconds_left(player_id: String) -> float:
	return float((_picks.get(_pid(player_id), {}) as Dictionary).get("remaining", 0.0))

## Stop `pid`'s pick: a failure (`reason`), which breaks the tool with `ChestRules.break_chance`. The owners
## are told.
func cancel_pick(player_id: String, reason: String) -> void:
	var pid := _pid(player_id)
	if not _picks.has(pid):
		return
	var p: Dictionary = _picks[pid]
	_picks.erase(pid)
	var broke := false
	var inv := _inventory(pid)
	if inv != null and _roll() < ChestRules.break_chance(float(p["diff"])) and inv.has_method("consume_items"):
		broke = bool(inv.consume_items({ str(p["tool"]): 1 }))
	_notify(str(p["id"]), "lock.pick_failed")
	GameBus.lock_pick_resolved.emit(pid, str(p["id"]), reason, broke)

func tick(delta: float) -> void:
	for pid: String in _picks.keys():
		var p: Dictionary = _picks[pid]
		var id := str(p["id"])
		if not _locks.has(id):
			_picks.erase(pid)
			continue
		var here: Variant = _pos_of(pid)
		if not (here is Vector3) or not (p["origin"] is Vector3) or (here as Vector3).distance_to(p["origin"]) > MOVE_CANCEL_M:
			cancel_pick(pid, "moved")
			continue
		p["remaining"] = float(p["remaining"]) - delta
		if float(p["remaining"]) > 0.0:
			continue
		_picks.erase(pid)
		if not _grants.has(id):
			_grants[id] = {}
		(_grants[id] as Dictionary)[pid] = true
		WorkSkills.grant(registry, pid, WorkSkills.row("lockpick"))
		_notify(id, "lock.picked")
		GameBus.lock_pick_resolved.emit(pid, id, "", false)
	for pid: String in _open.keys():
		var id := str(_open[pid])
		if not _locks.has(id) or not _within(pid, id):
			close(pid)

## One hit on the lock of `id` with `method` (`StructureRules.METHODS`). At zero durability the chest or door
## is destroyed and a chest spills its items. Returns "" for a hit that landed.
func hit(player_id: String, id: String, method: String) -> String:
	var pid := _pid(player_id)
	if not _locks.has(id):
		return "no_lock"
	if not _within(pid, id):
		return "far"
	var now := _now()
	if now - float(_last_hit.get(pid, -1.0e12)) < HIT_GAP_SEC:
		return "rate"
	_last_hit[pid] = now
	if _last_hit.size() > 4096:
		_last_hit.clear()
	var l: Dictionary = _locks[id]
	l["hp"] = float(l["hp"]) - StructureRules.hit_damage(method, str(l["material"]), _owners_offline(id))
	if float(l["hp"]) > 0.0:
		return ""
	_notify(id, "lock.destroyed")
	if remove_station.is_valid():
		remove_station.call(id)   # station_removed -> forget(id): the chest spills
	forget(id)
	return ""

## The destruction method a hit of `pid` is, from their own pack (never from the client): a pick, else an axe,
## else bare hands. With `wear` the tool wears as it would mining.
func held_method(pid: String, wear: bool) -> String:
	var inv := _inventory(pid)
	if inv == null or not inv.has_method("find_tool"):
		return "hand"
	for pair: Array in [["pick", "mine"], ["axe", "chop"]]:
		var tool := str(inv.find_tool(pair[0]))
		if tool != "":
			if wear and inv.has_method("use_item"):
				inv.use_item(tool, pair[1])
			return str(pair[0])
	return "hand"

## Hits `method` needs to break a lock of `id` from full (the destroy time the suite compares).
func hits_to_break(id: String, method: String) -> int:
	var l: Dictionary = _locks.get(id, {})
	if l.is_empty():
		return 0
	var dmg := StructureRules.hit_damage(method, str(l["material"]), false)
	return ceili(float(l["max_hp"]) / dmg) if dmg > 0.0 else 0

func _notify(id: String, key: String) -> void:
	var l: Dictionary = _locks.get(id, {})
	if l.is_empty():
		return
	var pos: Vector3 = l["pos"]
	for pid: String in owner_ids(id):
		if registry != null and registry.has_method("is_online") and bool(registry.is_online(pid)):
			GameBus.system_message.emit(key, [roundi(pos.x), roundi(pos.z)], pid)

# ── views ────────────────────────────────────────────────────────────────

## What `player_id` sees of the chest or door they have open: {} when nothing is open.
func view(player_id: String) -> Dictionary:
	var pid := _pid(player_id)
	var id := str(_open.get(pid, ""))
	var l: Dictionary = _locks.get(id, {})
	if l.is_empty():
		return {}
	return { "id": id, "type": str(l["type"]), "kind": str(l["kind"]), "mode": str(l["mode"]), "owner": is_owner(pid, id),
		"items": (l["items"] as Dictionary).duplicate(), "used": used_stacks(id), "capacity": ChestRules.capacity_stacks(str(l["type"])),
		"hp": roundi(float(l["hp"])), "max_hp": roundi(float(l["max_hp"])) }

# ── intents ──────────────────────────────────────────────────────────────

func _on_intent(action: String, args: Dictionary, player_id: String) -> void:
	if not is_host or registry == null or not bool(registry.get("is_authoritative")):
		return
	var pid := _pid(player_id)
	var reason := resolve(action, args, pid)
	GameBus.chest_resolved.emit(pid, action, reason == "", reason)

## The host's answer to one intent: "" when it was done, else a REASONS code. `use`, `pick` and `hit` act on
## the nearest chest or door; `take`, `put`, `mode` on the one the player has open.
func resolve(action: String, args: Dictionary, pid: String) -> String:
	if pid == "":
		return "bad_args"
	var here: Variant = _pos_of(pid)
	var near := nearest(here) if here is Vector3 else ""
	match action:
		"use":
			return open(pid, near) if near != "" else "no_lock"
		"close":
			close(pid)
			return ""
		"mode":
			return set_mode(pid, open_of(pid), str(args.get("mode", "")).left(16))
		"put", "take":
			var qty := int(args.get("qty", 0)) if (args.get("qty", 0) is int or args.get("qty", 0) is float) else 0
			var item := str(args.get("item", "")).left(64)
			return put(pid, open_of(pid), item, qty) if action == "put" else take(pid, open_of(pid), item, qty)
		"pick":
			return start_pick(pid, near) if near != "" else "no_lock"
		"cancel":
			if not _picks.has(pid):
				return "bad_args"
			cancel_pick(pid, "cancelled")
			return ""
		"place":
			var off := Vector3.ZERO
			for i in 3:
				var v: Variant = args.get(["ox", "oy", "oz"][i], null)
				if not ((v is float or v is int) and is_finite(float(v))):
					return "bad_args"
				off[i] = float(v)
			return str(place_for.call(pid, str(args.get("type", "")).left(16), off)) if place_for.is_valid() else "bad_args"
		"hit":
			if near == "":
				return "no_lock"
			var why := hit(pid, near, held_method(pid, false))
			if why == "":
				held_method(pid, true)
			return why
	return "bad_args"

# ── persistence ──────────────────────────────────────────────────────────

func to_data() -> Dictionary:
	var out := {}
	for id: String in _locks:
		var l: Dictionary = _locks[id]
		var p: Vector3 = l["pos"]
		out[id] = { "type": l["type"], "kind": l["kind"], "owner": l["owner"], "mode": l["mode"], "items": (l["items"] as Dictionary).duplicate(),
			"tech": l["tech"], "hp": float(l["hp"]), "pos": [p.x, p.y, p.z] }
	return { "format": DATA_FORMAT, "locks": out }

## Load a saved record, keeping only well-formed entries whose station `has_station(id) -> bool` still stands.
func from_data(data: Variant, has_station: Callable = Callable()) -> void:
	clear_all()
	if not (data is Dictionary) or not ((data as Dictionary).get("locks", null) is Dictionary):
		return
	var raw: Dictionary = data["locks"]
	for key: Variant in raw:
		var id := str(key).left(64)
		var e: Variant = raw[key]
		if _locks.size() >= MAX_LOCKS or not (e is Dictionary) or (has_station.is_valid() and not bool(has_station.call(id))):
			continue
		var type := str(e.get("type", ""))
		var kind := str(e.get("kind", ""))
		var mode := str(e.get("mode", ""))
		var owner := str(e.get("owner", "")).left(64)
		var p: Variant = e.get("pos", null)
		if not ChestRules.is_lock_type(type) or not ["private", "clan"].has(kind) or owner == "" or not (p is Array) or (p as Array).size() != 3:
			continue
		if not (p as Array).all(func(v: Variant) -> bool: return (v is float or v is int) and is_finite(float(v))):
			continue
		var tech := str(e.get("tech", "none"))
		if not ChestRules.technologies().has(tech):
			tech = "none"
		var hp: Variant = e.get("hp", -1.0)
		_add(id, type, kind, owner, mode if ChestRules.modes().has(mode) else ChestRules.default_mode(),
			_clean_items(e.get("items", {})) if ChestRules.holds_items(type) else {}, tech, Vector3(float(p[0]), float(p[1]), float(p[2])),
			float(hp) if (hp is float or hp is int) and is_finite(float(hp)) else -1.0)

static func _clean_items(raw: Variant) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		return out
	for k: Variant in raw:
		var v: Variant = raw[k]
		var n := int(v) if (v is int or v is float) and is_finite(float(v)) else 0
		if str(k) != "" and n > 0 and out.size() < 256:
			out[str(k).left(64)] = mini(n, MAX_QTY * 10)
	return out
