extends Node
## Structure slice (Phase 205) — who owns each placed block, and what it has left.
##
## A structure is a set of placed blocks assigned when built to its builder (`private`) or the builder's
## clan (`clan`), as the fabric's `Structure.ownership` decides (Phase 203). The host keeps the index: block to
## structure, structure to owner. A block is a cell of one tile (`VoxelConsts.TILE_SIZE`) by one step
## (`STEP_HEIGHT`), named by its canonical tile and its bottom in whole millimetres.
##
## Ownership is enforced on every edit: only the owner places on or reshapes a structure (for a clan
## structure, any member), and mining your own block dismantles it. Anyone else's mine is a hit: it lowers
## the block's durability (`StructureDurability`), and a block at zero is destroyed with nothing returned.
## A member's private structure inside their clan's territory (the circles of that clan's own structures)
## can be entered and dismantled, never edited, by any member of the clan.
##
## Every structure has a circle (`Structure.circle`), larger for a larger structure (Phase 206). No creature
## spawns inside any circle, and inside a clan's circles only that clan's members build. Circles are cached and
## bucketed on the ground (`BUCKET_M` squares): a block added or removed marks its structure, the next lookup
## recomputes only the marked ones, so a point query reads one or two buckets however dense the town. Ownership changes only when the
## blocks go: a structure whose last block is dismantled or destroyed is forgotten.
##
## Durability = base (the material's) × (1 − wear since the block was placed) − damage. Wear is per
## structure, a fraction of base, advanced from the clock's in-game hour when the structure is read or swept
## (`tick`), never by touching every block every frame: `loss.perDay` per day of age plus `loss.weather[state]`
## per hour of the weather rolled at the structure's anchor. Server downtime counts once, on load.
##
## Plug contract (GameBus):
##   IN  : structure_intent(action, args, player_id)   ("build_as" {mode}, "repair")
##   OUT : structure_resolved(player_id, action, ok, reason), block_damaged(position, fraction),
##         system_message("structure.*", ...) to the owners
## Everything here is host-side except `note_damage_seen` (the client's mirror of `block_damaged`).

const Rules := preload("res://src/structure/structure_rules.gd")
const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")
const WorldPos := preload("res://src/terrain/world_pos.gd")
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const SeamWrap := preload("res://src/terrain/seam_wrap.gd")
const WorkSkills := preload("res://src/character/work_skills.gd")

const DATA_FORMAT := 1
const OWNER_KINDS := ["private", "clan"]
## Memory bounds: every indexed block costs two dictionary entries. Past them a new structure (or block) is
## refused rather than placed unowned.
const MAX_STRUCTURES := 20000
const MAX_CELLS := 250000
## Weather samples per wear catch-up: a long gap (a reload, a structure no one read for days) is integrated
## from this many evenly spaced hours instead of every hour.
const WEATHER_SAMPLES := 24
## Structures `tick` advances per call: the sweep is bounded however large the world.
const SWEEP_PER_TICK := 64
## Blocks worn to nothing `tick` removes per call.
const COLLAPSE_PER_TICK := 32
## A structure's owners hear of damage at most once per this many seconds.
const NOTICE_GAP_SEC := 30.0
## Metres around the player `/repair` looks for a structure they own.
const REPAIR_REACH_M := 3.0
## Downtime counted on load is capped (a clock set wrong must not ruin every structure at once twice over).
const MAX_DOWNTIME_HOURS := 24.0 * 3650.0
const INTENT_INTERVAL := 0.25
## Seconds between one player's hits on someone else's blocks. The host keeps the pace, not the client:
## a client sending mine intents as fast as the network bucket allows would undo `offlineFactor`.
const HIT_INTERVAL := 0.25
## Side of one circle bucket in metres: a circle of `maxRadius` 128 m overlaps at most 6 × 6 of them.
const BUCKET_M := 64.0
## The most foreign circles one client is sent at a time (`foreign_circles_near`).
const MAX_VIEW_CIRCLES := 32
const REASONS := ["not_owner", "no_permission", "structures_full", "no_clan", "bad_args", "no_structure",
	"intact", "missing_materials", "no_inventory", "rate_limited", "unknown_action", "unknown_player", "foreign_circle"]

## Set by the wiring (host): the player registry (identity, packs, online, skills) and the clan slice.
var registry: Node = null
var clans: Node = null
var is_host: bool = true
## `() -> int` the clock's in-game hour (WeatherSlice.current_hour). Tests stub it.
var now_hour: Callable = func() -> int: return 0
## `(tile: Vector2i, hour: int) -> String` the weather state over `tile` at `hour`. Unset: always clear.
var weather_at: Callable = Callable()
## `(tile: Vector2i, bottom: float, top: float) -> void` removes one block from the world (a block worn away).
var remove_block: Callable = Callable()
var mono_sec: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0

## sid -> { id, kind, owner, builder, anchor: Vector2i, wear, wear_hour, credit {material: f},
##          cells { tile: { mm: [material, damage, wear_at_place] } }, count, hurt, sx, sz, levels }
## `hurt` is at least the largest damage / base of any of its blocks (never under it): the sweep reads a
## structure's blocks only once its wear could bring one to zero.
## `sx`/`sz` sum its columns' tile offsets from `anchor` (round the seam) and `levels` counts its blocks per
## bottom mm, kept as blocks come and go, so its circle is recomputed without reading its cells.
var _structures: Dictionary = {}
## tile -> { mm: sid }
var _tiles: Dictionary = {}
var _cell_count: int = 0
var _next_id: int = 1
## pid -> "private" | "clan": what that player's next new structure is assigned to.
var _build_mode: Dictionary = {}
var _notice_at: Dictionary = {}
var _last_intent: Dictionary = {}
## pid -> mono_sec of that player's last committed hit on someone else's block.
var _last_hit: Dictionary = {}
var _sweep_keys: Array = []
var _collapse: Array = []
## sid -> { center, radius } (`circle_of`); sid -> [bucket keys]; bucket key -> { sid: true }; sids whose blocks
## changed since their circle was computed.
var _circles: Dictionary = {}
var _circle_keys: Dictionary = {}
var _buckets: Dictionary = {}
var _circle_dirty: Dictionary = {}
## Client and host: the last `block_damaged` heard, and how many (the harness reads both peers').
var last_damage: Dictionary = {}
var damage_seen: int = 0

func _ready() -> void:
	GameBus.structure_intent.connect(_on_intent)
	GameBus.block_damaged.connect(note_damage_seen)
	GameBus.player_left.connect(forget_player)

func forget_player(player_id: String) -> void:
	_last_intent.erase(player_id)
	_last_hit.erase(player_id)

func is_authoritative() -> bool:
	return is_host

# ── identity ─────────────────────────────────────────────────────────────

func _pid(player_id: String) -> String:
	if player_id == "" and registry != null and "local_player_id" in registry:
		return str(registry.local_player_id)
	return player_id

func _clan_of(pid: String) -> String:
	return str(clans.clan_of(pid)) if clans != null and pid != "" else ""

func _members(clan_id: String) -> Array:
	if clans == null or clan_id == "":
		return []
	return (clans.get_clan(clan_id).get("members", {}) as Dictionary).keys()

func _online(pid: String) -> bool:
	return registry != null and registry.has_method("is_online") and bool(registry.is_online(pid))

# ── queries ──────────────────────────────────────────────────────────────

static func mm_of(y: float) -> int:
	return roundi(y * 1000.0)

static func canonical(tile: Vector2i) -> Vector2i:
	return VoxelConsts.canonical_tile(tile)

func count() -> int:
	return _structures.size()

func cell_count() -> int:
	return _cell_count

func get_structure(sid: int) -> Dictionary:
	return _structures.get(sid, {})

func ids() -> Array:
	var out: Array = _structures.keys()
	out.sort()
	return out

## `{ sid, tile, mm }` of the block in `tile` whose step holds height `y`, or {}.
func cell_at(tile: Vector2i, y: float) -> Dictionary:
	var t := canonical(tile)
	var col: Dictionary = _tiles.get(t, {})
	var step_mm := mm_of(VoxelConsts.STEP_HEIGHT)
	var at := mm_of(y)
	for mm: int in col:
		if at >= mm and at < mm + step_mm:
			return { "sid": int(col[mm]), "tile": t, "mm": mm }
	return {}

## The structure id owning the block at (`tile`, `y`), or 0.
func structure_at(tile: Vector2i, y: float) -> int:
	return int(cell_at(tile, y).get("sid", 0))

## Every player who owns `sid`: its builder for a private structure, every member for a clan's.
func owner_ids(sid: int) -> Array:
	var s: Dictionary = _structures.get(sid, {})
	if s.is_empty():
		return []
	return [str(s["owner"])] if str(s["kind"]) == "private" else _members(str(s["owner"]))

## Whether every owner of `sid` is offline (for a clan structure: every member).
func owners_offline(sid: int) -> bool:
	for pid: String in owner_ids(sid):
		if _online(pid):
			return false
	return true

## Whether `s` is a clan structure whose clan has no members left (`Structure.ownership.abandonedClan`).
func _abandoned(s: Dictionary) -> bool:
	return str(s["kind"]) == "clan" and clans != null and _members(str(s["owner"])).is_empty()

## May `player_id` place on, reshape or take stations on `sid`? The owner (any member for a clan structure);
## anyone for a clan structure whose clan has no members left.
func may_edit(player_id: String, sid: int) -> bool:
	var s: Dictionary = _structures.get(sid, {})
	var pid := _pid(player_id)
	if s.is_empty() or pid == "":
		return false
	if _abandoned(s):
		return true
	if str(s["kind"]) == "private":
		return str(s["owner"]) == pid
	return _clan_of(pid) == str(s["owner"])

## A member's private structure inside their clan's territory, seen by another member of that clan: they may
## enter and dismantle it, never edit it (`Structure.ownership.memberPrivateInTerritory`).
func _member_private_in_territory(pid: String, s: Dictionary) -> bool:
	if str(s["kind"]) != "private" or str(s["owner"]) == pid:
		return false
	var clan := _clan_of(pid)
	if clan == "" or _clan_of(str(s["owner"])) != clan:
		return false
	var rule: Dictionary = Rules.structure().get("ownership", {}).get("memberPrivateInTerritory", {})
	return in_clan_territory(int(s["id"]), clan) and (bool(rule.get("enter", false)) or bool(rule.get("dismantle", false)))

## May `player_id` take `sid` apart (and get materials back)? A private structure's owner; for a clan's, a
## member whose role may `dismantleClanStructures`; and a clan member for another member's private structure
## inside the clan's territory. Anyone, for a clan structure whose clan has no members left.
func may_dismantle(player_id: String, sid: int) -> bool:
	var s: Dictionary = _structures.get(sid, {})
	var pid := _pid(player_id)
	if s.is_empty() or pid == "":
		return false
	if _abandoned(s):
		return true
	if str(s["kind"]) == "clan":
		return _clan_of(pid) == str(s["owner"]) and (clans == null or bool(clans.may(pid, "dismantleClanStructures")))
	if str(s["owner"]) == pid:
		return true
	var rule: Dictionary = Rules.structure().get("ownership", {}).get("memberPrivateInTerritory", {})
	return bool(rule.get("dismantle", false)) and _member_private_in_territory(pid, s)

## May `player_id` go inside `sid` (doors, Phase 208, ask this): whoever may edit it, and a clan member for
## another member's private structure inside the clan's territory.
func may_enter(player_id: String, sid: int) -> bool:
	var s: Dictionary = _structures.get(sid, {})
	if s.is_empty():
		return false
	if may_edit(player_id, sid):
		return true
	var rule: Dictionary = Rules.structure().get("ownership", {}).get("memberPrivateInTerritory", {})
	return bool(rule.get("enter", false)) and _member_private_in_territory(_pid(player_id), s)

## `{ center: Vector2 (ground metres), radius }` of a structure's circle (`Structure.circle`): footprint is
## its columns' area, height its lowest to highest block. {} for an unknown structure.
func circle_of(sid: int) -> Dictionary:
	_flush_circles()
	return _circles.get(sid, {})

## From the running sums `_add_cell`/`_remove_cell` keep: the columns' mean (measured from `anchor` round the
## seam, so a structure across it is not averaged to the far side) and the lowest and highest block, in time
## that does not grow with the structure's size (a level count, not a block count).
func _compute_circle(s: Dictionary) -> Dictionary:
	var cols := (s["cells"] as Dictionary).size()
	var n := float(maxi(1, cols))
	var a: Vector2i = s["anchor"]
	var lo := 1 << 40
	var hi := -(1 << 40)
	for mm: int in s.get("levels", {}):
		lo = mini(lo, mm)
		hi = maxi(hi, mm + mm_of(VoxelConsts.STEP_HEIGHT))
	var footprint := n * VoxelConsts.TILE_SIZE * VoxelConsts.TILE_SIZE
	var height := maxf(0.0, float(hi - lo) / 1000.0) if cols > 0 else 0.0
	var center := Vector2(float(a.x) + float(s.get("sx", 0)) / n + 0.5, float(a.y) + float(s.get("sz", 0)) / n + 0.5) * VoxelConsts.TILE_SIZE
	center.x = SeamWrap.wrap_f(center.x, _lap_m())
	return { "center": center, "radius": Rules.circle_radius(footprint, height) }

## Add (`sign` 1) or take away (-1) column `tile` from `s`'s running sums.
static func _sum_column(s: Dictionary, tile: Vector2i, sign: int) -> void:
	var a: Vector2i = s["anchor"]
	var tiles_lap := SeamWrap.world_tiles(TerrainSlice.circumference_chunks(), VoxelConsts.CHUNK_SIZE)
	s["sx"] = int(s.get("sx", 0)) + sign * SeamWrap.delta(tile.x, a.x, tiles_lap)
	s["sz"] = int(s.get("sz", 0)) + sign * (tile.y - a.y)

## Whether the ground point `xz` lies in the circle at `center` of `radius` (metres, round the seam).
static func circle_holds(center: Vector2, radius: float, xz: Vector2) -> bool:
	return _dist_m(center, xz) <= radius

static func _lap_m() -> float:
	return float(TerrainSlice.circumference_chunks()) * WorldPos.CHUNK_METERS

static func _dist_m(a: Vector2, b: Vector2) -> float:
	return Vector2(SeamWrap.wrap_f(b.x - a.x, _lap_m()), b.y - a.y).length()

func _clear_circles() -> void:
	_circles.clear()
	_circle_keys.clear()
	_buckets.clear()
	_circle_dirty.clear()

## Recompute the circles of the structures whose blocks changed, and move them between buckets. A structure
## that is gone leaves its buckets: its circle is lifted.
func _flush_circles() -> void:
	if _circle_dirty.is_empty():
		return
	for sid: int in _circle_dirty:
		for key: Vector2i in _circle_keys.get(sid, []):
			var b: Dictionary = _buckets.get(key, {})
			b.erase(sid)
			if b.is_empty():
				_buckets.erase(key)
		_circle_keys.erase(sid)
		_circles.erase(sid)
		if not _structures.has(sid):
			continue
		var c := _compute_circle(_structures[sid])
		_circles[sid] = c
		var center: Vector2 = c["center"]
		var r := float(c["radius"])
		var keys: Array = []
		for bx in range(floori((center.x - r) / BUCKET_M), floori((center.x + r) / BUCKET_M) + 1):
			for bz in range(floori((center.y - r) / BUCKET_M), floori((center.y + r) / BUCKET_M) + 1):
				var key := Vector2i(bx, bz)
				if not _buckets.has(key):
					_buckets[key] = {}
				_buckets[key][sid] = true
				keys.append(key)
		_circle_keys[sid] = keys
	_circle_dirty.clear()

## The structures whose circle holds the ground point `xz` (world metres), by id. Centers lie in the canonical
## lap and a circle's buckets may run past the seam, so a point near it also reads the bucket a lap away.
func circles_at(xz: Vector2) -> Array:
	_flush_circles()
	var out: Array = []
	if _circles.is_empty():
		return out
	var lap := _lap_m()
	var x := SeamWrap.wrap_f(xz.x, lap)
	var reach := float(Rules.structure().get("circle", {}).get("maxRadius", 128.0))
	var xs: Array = [x]
	if x - reach < -lap * 0.5:
		xs.append(x + lap)
	if x + reach >= lap * 0.5:
		xs.append(x - lap)
	var bz := floori(xz.y / BUCKET_M)
	for qx: float in xs:
		var b: Dictionary = _buckets.get(Vector2i(floori(qx / BUCKET_M), bz), {})
		for sid: int in b:
			var c: Dictionary = _circles[sid]
			if not out.has(sid) and _dist_m(c["center"], xz) <= float(c["radius"]):
				out.append(sid)
	out.sort()
	return out

## The circles of clans `player_id` is not in that reach within `reach` metres of `xz`, as `[x, z, radius]`
## (at most `MAX_VIEW_CIRCLES`, nearest first): what a client needs to show where it may not build.
func foreign_circles_near(player_id: String, xz: Vector2, reach: float) -> Array:
	_flush_circles()
	var out: Array = []
	if _circles.is_empty():
		return out
	var mine := _clan_of(_pid(player_id))
	var lap := _lap_m()
	var x := SeamWrap.wrap_f(xz.x, lap)
	var span := reach + float(Rules.structure().get("circle", {}).get("maxRadius", 128.0))
	var xs: Array = [x]
	if absf(x) + span >= lap * 0.5:
		xs.append_array([x + lap, x - lap])
	var seen: Dictionary = {}
	for qx: float in xs:
		for bx in range(floori((qx - reach) / BUCKET_M), floori((qx + reach) / BUCKET_M) + 1):
			for bz in range(floori((xz.y - reach) / BUCKET_M), floori((xz.y + reach) / BUCKET_M) + 1):
				for sid: int in _buckets.get(Vector2i(bx, bz), {}):
					if seen.has(sid):
						continue
					seen[sid] = true
					var st: Dictionary = _structures[sid]
					if str(st["kind"]) != "clan" or str(st["owner"]) == mine or _abandoned(st):
						continue
					var c: Dictionary = _circles[sid]
					var d := _dist_m(c["center"], xz)
					if d <= reach + float(c["radius"]):
						out.append([d, c["center"].x, c["center"].y, float(c["radius"])])
	out.sort()
	var view: Array = []
	for e: Array in out.slice(0, MAX_VIEW_CIRCLES):
		view.append([e[1], e[2], e[3]])
	return view

## Whether a creature may not spawn at the ground point `xz` (world metres): it lies inside a circle.
func spawn_blocked(xz: Vector2) -> bool:
	return not circles_at(xz).is_empty()

## The clan structure whose circle holds `xz` and whose clan `player_id` is not in, or 0: inside it they may not
## build (`Structure.circle`). A clan with no members left keeps no one out (`abandonedClan`).
func foreign_circle_at(player_id: String, xz: Vector2) -> int:
	var mine := _clan_of(_pid(player_id))
	for sid: int in circles_at(xz):
		var s: Dictionary = _structures[sid]
		if str(s["kind"]) == "clan" and str(s["owner"]) != mine and not _abandoned(s):
			return sid
	return 0

## Whether `sid` stands in `clan_id`'s territory: its center inside the circle of a structure that clan owns.
func in_clan_territory(sid: int, clan_id: String) -> bool:
	var me := circle_of(sid)
	if me.is_empty() or clan_id == "":
		return false
	for other: int in circles_at(me["center"]):
		var o: Dictionary = _structures[other]
		if other != sid and str(o["kind"]) == "clan" and str(o["owner"]) == clan_id:
			return true
	return false

static func _tile_xz(tile: Vector2i) -> Vector2:
	return (Vector2(tile) + Vector2(0.5, 0.5)) * VoxelConsts.TILE_SIZE

# ── durability ───────────────────────────────────────────────────────────

func _weather_wear(anchor: Vector2i, from_hour: int, hours: float) -> float:
	if hours <= 0.0 or not weather_at.is_valid():
		return 0.0
	var n := mini(WEATHER_SAMPLES, maxi(1, ceili(hours)))
	var step := hours / float(n)
	var total := 0.0
	for i in n:
		total += Rules.weather_wear(str(weather_at.call(anchor, from_hour + floori(float(i) * step)))) * step
	return total

## Bring `s`'s wear up to the clock's hour.
func _advance(s: Dictionary) -> void:
	var now := int(now_hour.call())
	var hours := float(now - int(s["wear_hour"]))
	if hours <= 0.0:
		return
	s["wear"] = minf(2.0, float(s["wear"]) + Rules.age_wear(hours) + _weather_wear(s["anchor"], int(s["wear_hour"]), hours))
	s["wear_hour"] = now

## The block's durability now, and its base.
func _durability_of(s: Dictionary, cell: Array) -> float:
	var base := Rules.base_durability(str(cell[0]))
	var worn := maxf(0.0, float(s["wear"]) - float(cell[2]))
	return maxf(0.0, base * (1.0 - worn) - float(cell[1]))

## `{ durability, base, fraction }` of the block at (`tile`, `y`), or {} when no structure holds it.
func block_durability(tile: Vector2i, y: float) -> Dictionary:
	var hit := cell_at(tile, y)
	if hit.is_empty():
		return {}
	var s: Dictionary = _structures[hit["sid"]]
	_advance(s)
	var cell: Array = s["cells"][hit["tile"]][hit["mm"]]
	var base := Rules.base_durability(str(cell[0]))
	var d := _durability_of(s, cell)
	return { "durability": d, "base": base, "fraction": d / base if base > 0.0 else 0.0 }

# ── edits ────────────────────────────────────────────────────────────────

func _level_of(pid: String) -> int:
	if registry == null or not registry.has_method("get_skill_xp"):
		return 0
	var skill := Rules.dismantle_skill()
	return Rules.level_for_xp(skill, int(registry.get_skill_xp(pid, skill)))

## What a mine of the span [`bottom`, `top`] in `tile` by `player_id` with `method` would do. Pure:
##   free      no structure holds it (natural ground, or a block placed before structures existed)
##   dismantle the actor may take it apart: `quantity` units of `material` come back
##   damage    an outsider's hit: `points` off, the block stands at `fraction`
##   destroy   an outsider's hit that takes it to zero: it goes, nothing comes back
##   refused   `reason` (a clan member whose role may not dismantle the clan's structures, or an
##             outsider's hit sooner than `HIT_INTERVAL` after their last)
func plan_mine(player_id: String, tile: Vector2i, bottom: float, top: float, method: String) -> Dictionary:
	var hit := cell_at(tile, (bottom + top) * 0.5)
	if hit.is_empty():
		return { "verdict": "free" }
	var sid := int(hit["sid"])
	var s: Dictionary = _structures[sid]
	_advance(s)
	var cell: Array = s["cells"][hit["tile"]][hit["mm"]]
	var material := str(cell[0])
	var base := Rules.base_durability(material)
	var left := _durability_of(s, cell)
	var plan := { "sid": sid, "tile": hit["tile"], "mm": hit["mm"], "material": material, "player_id": _pid(player_id) }
	if may_dismantle(player_id, sid):
		var credit := float((s["credit"] as Dictionary).get(material, 0.0)) \
			+ Rules.dismantle_share(left / base if base > 0.0 else 0.0, _level_of(_pid(player_id)))
		var qty := floori(credit + 0.000001)
		plan.merge({ "verdict": "dismantle", "quantity": qty, "credit": maxf(0.0, credit - float(qty)) })
		return plan
	if may_edit(player_id, sid):
		plan.merge({ "verdict": "refused", "reason": "no_permission" })
		return plan
	if float(mono_sec.call()) - float(_last_hit.get(_pid(player_id), -1.0e12)) < HIT_INTERVAL:
		plan.merge({ "verdict": "refused", "reason": "rate_limited" })
		return plan
	var points := Rules.hit_damage(method, material, owners_offline(sid))
	var after := left - points
	plan.merge({ "verdict": "destroy" if after <= 0.0 else "damage", "points": points,
		"fraction": maxf(0.0, after) / base if base > 0.0 else 0.0 })
	return plan

## Apply a `plan_mine` result the world edit already followed (or, for `damage`, instead of one).
func commit_mine(plan: Dictionary) -> void:
	var sid := int(plan.get("sid", 0))
	if not _structures.has(sid):
		return
	var s: Dictionary = _structures[sid]
	var verdict := str(plan.get("verdict", ""))
	if verdict == "damage" or verdict == "destroy":
		_last_hit[str(plan.get("player_id", ""))] = float(mono_sec.call())
	match verdict:
		"dismantle":
			s["credit"][str(plan["material"])] = float(plan["credit"])
			_remove_cell(sid, plan["tile"], int(plan["mm"]))
		"damage":
			var cell: Array = s["cells"][plan["tile"]][int(plan["mm"])]
			cell[1] = float(cell[1]) + float(plan["points"])
			_note_hurt(s, cell)
			_notify(sid, "structure.damaged", NOTICE_GAP_SEC)
		"destroy":
			_remove_cell(sid, plan["tile"], int(plan["mm"]))
			_notify(sid, "structure.destroyed" if not _structures.has(sid) else "structure.damaged",
				0.0 if not _structures.has(sid) else NOTICE_GAP_SEC, s)

## The owner a new structure by `pid` gets: their build mode, falling back to private without a clan.
func _desired_owner(pid: String) -> Dictionary:
	if str(_build_mode.get(pid, "private")) == "clan" and _clan_of(pid) != "":
		return { "kind": "clan", "owner": _clan_of(pid) }
	return { "kind": "private", "owner": pid }

## The block a placement at [`bottom`, +STEP] in `tile` was made against: under it for a top-face click,
## above it for a ceiling, the neighbouring column's for a side click.
func _target_of(tile: Vector2i, bottom: float, normal: Vector3) -> Dictionary:
	var step := VoxelConsts.STEP_HEIGHT
	if normal.y > 0.5:
		return cell_at(tile, bottom - step * 0.5)
	if normal.y < -0.5:
		return cell_at(tile, bottom + step * 1.5)
	var back := Vector2i(-int(signf(normal.x)) if absf(normal.x) >= absf(normal.z) else 0,
		-int(signf(normal.z)) if absf(normal.z) > absf(normal.x) else 0)
	return cell_at(tile + back, bottom + step * 0.5)

## The structures touching the new block (above, below and the four columns beside it).
func _touching(tile: Vector2i, bottom: float) -> Array:
	var step := VoxelConsts.STEP_HEIGHT
	var out: Array = []
	for probe: Array in [[tile, bottom - step * 0.5], [tile, bottom + step * 1.5], [tile + Vector2i(1, 0), bottom + step * 0.5],
			[tile + Vector2i(-1, 0), bottom + step * 0.5], [tile + Vector2i(0, 1), bottom + step * 0.5], [tile + Vector2i(0, -1), bottom + step * 0.5]]:
		var sid := structure_at(probe[0], float(probe[1]))
		if sid != 0 and not out.has(sid):
			out.append(sid)
	return out

## The first structure `pid` may not edit with a block within `Structure.ownership.buffer` blocks of the new
## block at [`bottom`, +STEP] in `tile` (above, below, beside or diagonally), or 0.
func _foreign_near(pid: String, tile: Vector2i, bottom: float) -> int:
	var reach := maxi(1, int(Rules.structure().get("ownership", {}).get("buffer", 1)))
	var step_mm := mm_of(VoxelConsts.STEP_HEIGHT)
	var at := mm_of(bottom)
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			var col: Dictionary = _tiles.get(canonical(tile + Vector2i(dx, dz)), {})
			for mm: int in col:
				# Within `reach` blocks vertically: less than reach + 1 steps between the two bottoms.
				if absi(mm - at) < (reach + 1) * step_mm and not may_edit(pid, int(col[mm])):
					return int(col[mm])
	return 0

## What a placement of `material` at [`bottom`, +STEP] in `tile` by `player_id` would do. Pure:
##   join     the block joins `sid`, a touching structure with the owner the builder's mode names
##   new      the block starts a structure for `kind`/`owner`
##   refused  `reason`: placed against, or within `Structure.ownership.buffer` blocks of, a structure the actor
##            may not edit (`not_owner`); inside the circle of a clan the actor is not in (`foreign_circle`,
##            Phase 206: a new structure or a block added to one alike); or the index is full
## Where structures of different owners touch (a clan's and a member's own), each keeps its own blocks.
func plan_place(player_id: String, tile: Vector2i, bottom: float, normal: Vector3, material: String) -> Dictionary:
	var pid := _pid(player_id)
	var target := _target_of(tile, bottom, normal)
	if not target.is_empty() and not may_edit(pid, int(target["sid"])):
		return { "verdict": "refused", "reason": "not_owner", "player_id": pid }
	if _foreign_near(pid, tile, bottom) != 0:
		return { "verdict": "refused", "reason": "not_owner", "player_id": pid }
	if foreign_circle_at(pid, _tile_xz(tile)) != 0:
		return { "verdict": "refused", "reason": "foreign_circle", "player_id": pid }
	if _cell_count >= MAX_CELLS:
		return { "verdict": "refused", "reason": "structures_full", "player_id": pid }
	var want := _desired_owner(pid)
	var plan := { "tile": canonical(tile), "mm": mm_of(bottom), "material": material, "player_id": pid }
	for sid: int in _touching(tile, bottom):
		var s: Dictionary = _structures[sid]
		if str(s["kind"]) == want["kind"] and str(s["owner"]) == want["owner"]:
			plan.merge({ "verdict": "join", "sid": sid })
			return plan
	if _structures.size() >= MAX_STRUCTURES:
		return { "verdict": "refused", "reason": "structures_full", "player_id": pid }
	plan.merge({ "verdict": "new", "kind": want["kind"], "owner": want["owner"] })
	return plan

## Record a `plan_place` result the world edit followed. Returns the structure id (0 when nothing was recorded).
func commit_place(plan: Dictionary) -> int:
	var sid := int(plan.get("sid", 0))
	match str(plan.get("verdict", "")):
		"new":
			sid = _next_id
			_next_id += 1
			_structures[sid] = { "id": sid, "kind": str(plan["kind"]), "owner": str(plan["owner"]), "builder": str(plan["player_id"]),
				"anchor": plan["tile"], "wear": 0.0, "wear_hour": int(now_hour.call()), "credit": {}, "cells": {}, "count": 0 }
		"join":
			if not _structures.has(sid):
				return 0
		_:
			return 0
	var s: Dictionary = _structures[sid]
	_advance(s)
	_add_cell(sid, plan["tile"], int(plan["mm"]), [str(plan["material"]), 0.0, float(s["wear"])])
	return sid

## Index `cell` at (`tile`, `mm`) for `sid`. A block another structure still held there (a stale record) is
## taken from it first, so no two structures ever claim one block.
func _add_cell(sid: int, tile: Vector2i, mm: int, cell: Array) -> void:
	var prev := int((_tiles.get(tile, {}) as Dictionary).get(mm, 0))
	if prev != 0 and prev != sid and _structures.has(prev):
		_remove_cell(prev, tile, mm)
	var s: Dictionary = _structures[sid]
	_circle_dirty[sid] = true
	if not (s["cells"] as Dictionary).has(tile):
		s["cells"][tile] = {}
		_sum_column(s, tile, 1)
	if not (s["cells"][tile] as Dictionary).has(mm):
		s["count"] = int(s["count"]) + 1
		_cell_count += 1
		if not s.has("levels"):
			s["levels"] = {}
		s["levels"][mm] = int(s["levels"].get(mm, 0)) + 1
	s["cells"][tile][mm] = cell
	_note_hurt(s, cell)
	if not _tiles.has(tile):
		_tiles[tile] = {}
	_tiles[tile][mm] = sid

func _note_hurt(s: Dictionary, cell: Array) -> void:
	var base := Rules.base_durability(str(cell[0]))
	# A block of a material with no durability reads zero from the start: it falls on the first sweep.
	var frac := float(cell[1]) / base if base > 0.0 else 1.0
	if frac > float(s.get("hurt", 0.0)):
		s["hurt"] = frac

func _remove_cell(sid: int, tile: Vector2i, mm: int) -> void:
	var s: Dictionary = _structures[sid]
	_circle_dirty[sid] = true
	var col: Dictionary = s["cells"].get(tile, {})
	if col.erase(mm):
		s["count"] = int(s["count"]) - 1
		_cell_count -= 1
		var levels: Dictionary = s.get("levels", {})
		levels[mm] = int(levels.get(mm, 0)) - 1
		if int(levels[mm]) <= 0:
			levels.erase(mm)
	if col.is_empty() and (s["cells"] as Dictionary).erase(tile):
		_sum_column(s, tile, -1)
	var tcol: Dictionary = _tiles.get(tile, {})
	if int(tcol.get(mm, 0)) == sid:
		tcol.erase(mm)
	if tcol.is_empty():
		_tiles.erase(tile)
	if int(s["count"]) <= 0:
		_structures.erase(sid)

## The indexed blocks of `tile` whose bottoms lie in [`bottom`, `top`): `[[sid, mm], ...]`.
func _cells_in(tile: Vector2i, bottom: float, top: float) -> Array:
	var out: Array = []
	var col: Dictionary = _tiles.get(canonical(tile), {})
	var lo := mm_of(bottom)
	var hi := mm_of(top)
	for mm: int in col:
		if mm >= lo and mm < hi:
			out.append([int(col[mm]), mm])
	return out

## The world dropped the loose run [`from_bottom`, `from_top`) of `tile` to `to_bottom` (settling, host): the
## blocks it carried move with it, keeping their owner and durability.
func shift_span(tile: Vector2i, from_bottom: float, from_top: float, to_bottom: float) -> void:
	var t := canonical(tile)
	var delta := mm_of(to_bottom) - mm_of(from_bottom)
	if delta >= 0:
		return   # only a fall moves a run
	var cells := _cells_in(t, from_bottom, from_top)
	cells.sort_custom(func(x: Array, y: Array) -> bool: return int(x[1]) < int(y[1]))
	# Lowest first, each added at its new height before its old one goes: a falling block's new place is below
	# every block of the run still waiting, and a structure never empties (and vanishes) mid-move.
	for c: Array in cells:
		var sid := int(c[0])
		var mm := int(c[1])
		if not _structures.has(sid):
			continue
		_add_cell(sid, t, mm + delta, _structures[sid]["cells"][t][mm])
		_remove_cell(sid, t, mm)

## Forget any record of a block in [`bottom`, `top`) of `tile`: the world holds natural ground there (a record
## left behind by an edit the index never saw).
func drop_span(tile: Vector2i, bottom: float, top: float) -> void:
	var t := canonical(tile)
	for c: Array in _cells_in(t, bottom, top):
		_remove_cell(int(c[0]), t, int(c[1]))

## The world was regenerated (`/regen world`): every placed block is gone, so is every record of one.
func reset_world() -> void:
	_structures.clear()
	_tiles.clear()
	_cell_count = 0
	_sweep_keys.clear()
	_collapse.clear()
	_clear_circles()

## "" when `player_id` may put a station on (or fell a tree on) the ground at `pos`, else a reason: the block
## under it belongs to a structure they may not edit.
func edit_blocker(player_id: String, pos: Vector3) -> String:
	var tile := Vector2i(floori(pos.x / VoxelConsts.TILE_SIZE), floori(pos.z / VoxelConsts.TILE_SIZE))
	for y: float in [pos.y + VoxelConsts.STEP_HEIGHT * 0.5, pos.y - VoxelConsts.STEP_HEIGHT * 0.5]:
		var sid := structure_at(tile, y)
		if sid != 0 and not may_edit(player_id, sid):
			return "not_owner"
	return ""

## `edit_blocker`, and for a new station also the circle of a clan `player_id` is not in (`foreign_circle`).
func build_blocker(player_id: String, pos: Vector3) -> String:
	var why := edit_blocker(player_id, pos)
	if why == "" and foreign_circle_at(player_id, Vector2(pos.x, pos.z)) != 0:
		return "foreign_circle"
	return why

# ── repair ───────────────────────────────────────────────────────────────

## `{ material: units }` repairing `sid` to full costs: `repair.share` of each material's blocks times the
## fraction of their durability restored, rounded up.
func repair_cost(sid: int) -> Dictionary:
	var s: Dictionary = _structures.get(sid, {})
	if s.is_empty():
		return {}
	_advance(s)
	var missing: Dictionary = {}
	for t: Vector2i in s["cells"]:
		for mm: int in s["cells"][t]:
			var cell: Array = s["cells"][t][mm]
			var base := Rules.base_durability(str(cell[0]))
			if base > 0.0:
				missing[cell[0]] = float(missing.get(cell[0], 0.0)) + (base - _durability_of(s, cell)) / base
	var out: Dictionary = {}
	for m: String in missing:
		var n := ceili(Rules.repair_share() * float(missing[m]) - 0.000001)
		if n > 0:
			out[m] = n
	return out

## The owner restores `sid` to full durability, paying `repair_cost` from their own pack. All or nothing.
func repair(player_id: String, sid: int) -> String:
	var pid := _pid(player_id)
	if not _structures.has(sid):
		return "no_structure"
	if not may_edit(pid, sid):
		return "not_owner"
	var cost := repair_cost(sid)
	if cost.is_empty():
		return "intact"
	var inv: Node = registry.get_inventory(pid) if registry != null and registry.has_method("get_inventory") else null
	if inv == null or not inv.has_method("consume_items"):
		return "no_inventory"
	for m: String in cost:
		if inv.get_item_count(m) < int(cost[m]):
			return "missing_materials"
	if not inv.consume_items(cost):
		return "missing_materials"
	var s: Dictionary = _structures[sid]
	s["wear"] = 0.0
	s["hurt"] = 0.0
	for t: Vector2i in s["cells"]:
		for mm: int in s["cells"][t]:
			var cell: Array = s["cells"][t][mm]
			cell[1] = 0.0
			cell[2] = 0.0
			_note_hurt(s, cell)
	WorkSkills.grant(registry, pid, WorkSkills.row("repair"))   # Phase 207 — repairing grows the repairer's skill
	_push_inventory(pid)
	return ""

## The structure nearest `player_id` that they own, within REPAIR_REACH_M of where the host has them, or 0.
func owned_structure_near(player_id: String) -> int:
	var pid := _pid(player_id)
	if registry == null or not registry.has_method("get_world_pos"):
		return 0
	var pos: Dictionary = registry.get_world_pos(pid)
	if not WorldPos.is_plausible_pos(pos):
		return 0
	var c: Vector2i = pos["chunk"]
	var l: Vector3 = pos["local"]
	var x := float(c.x) * WorldPos.CHUNK_METERS + l.x
	var z := float(c.y) * WorldPos.CHUNK_METERS + l.z
	var r := ceili(REPAIR_REACH_M / VoxelConsts.TILE_SIZE)
	var at := Vector2i(floori(x / VoxelConsts.TILE_SIZE), floori(z / VoxelConsts.TILE_SIZE))
	var best := 0
	var best_d := INF
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var col: Dictionary = _tiles.get(canonical(at + Vector2i(dx, dz)), {})
			for mm: int in col:
				var sid := int(col[mm])
				var d := Vector3(dx, 0.0, dz).length() * VoxelConsts.TILE_SIZE + absf(float(mm) / 1000.0 - l.y)
				if d <= REPAIR_REACH_M * 2.0 and d < best_d and may_edit(pid, sid):
					best = sid
					best_d = d
	return best

# ── sweep ────────────────────────────────────────────────────────────────

## Host: advance a bounded slice of structures' wear, and remove blocks worn to nothing (their owners told).
func tick() -> void:
	if not is_host:
		return
	if _sweep_keys.is_empty():
		_sweep_keys = _structures.keys()
	for i in mini(SWEEP_PER_TICK, _sweep_keys.size()):
		var sid := int(_sweep_keys.pop_back())
		if not _structures.has(sid):
			continue
		var s: Dictionary = _structures[sid]
		_advance(s)
		# A block is at zero once worn ≥ 1 − damage / base; below that for its most damaged block, none is.
		if float(s["wear"]) < 1.0 - float(s.get("hurt", 0.0)):
			continue
		for t: Vector2i in s["cells"]:
			for mm: int in s["cells"][t]:
				if _durability_of(s, s["cells"][t][mm]) <= 0.0 and _collapse.size() < MAX_CELLS:
					_collapse.append([sid, t, mm])
	var removed := 0
	while removed < COLLAPSE_PER_TICK and not _collapse.is_empty():
		var c: Array = _collapse.pop_front()
		var sid := int(c[0])
		if not _structures.has(sid) or not (_structures[sid]["cells"].get(c[1], {}) as Dictionary).has(c[2]):
			continue
		var s: Dictionary = _structures[sid]
		_remove_cell(sid, c[1], int(c[2]))
		if remove_block.is_valid():
			remove_block.call(c[1], float(c[2]) / 1000.0, float(c[2]) / 1000.0 + VoxelConsts.STEP_HEIGHT)
		if not _structures.has(sid):
			_notify(sid, "structure.destroyed", 0.0, s)
		removed += 1

# ── notices ──────────────────────────────────────────────────────────────

## Tell `sid`'s owners (for a clan structure, its online members) with a keyed system line, at most once per
## `gap` seconds per structure. `s` is the record when the structure is already gone.
func _notify(sid: int, key: String, gap: float, s: Dictionary = {}) -> void:
	var rec: Dictionary = _structures.get(sid, s)
	if rec.is_empty():
		return
	var now := float(mono_sec.call())
	var tag := "%d:%s" % [sid, key]
	if gap > 0.0 and now - float(_notice_at.get(tag, -1.0e12)) < gap:
		return
	_notice_at[tag] = now
	if _notice_at.size() > 4096:
		_notice_at.clear()
	var a: Vector2i = rec["anchor"]
	var args := [roundi(float(a.x) * VoxelConsts.TILE_SIZE), roundi(float(a.y) * VoxelConsts.TILE_SIZE)]
	var to: Array = [str(rec["owner"])] if str(rec["kind"]) == "private" else _members(str(rec["owner"]))
	for pid: String in to:
		if _online(pid):
			GameBus.system_message.emit(key, args, pid)

## Client and host: a `block_damaged` heard (the harness reads it on both peers).
func note_damage_seen(position: Vector3, fraction: float) -> void:
	last_damage = { "position": position, "fraction": fraction }
	damage_seen += 1

# ── intents ──────────────────────────────────────────────────────────────

## `mode` is "private" or "clan": the owner of the structures `player_id` starts from now on.
func set_build_mode(player_id: String, mode: String) -> String:
	var pid := _pid(player_id)
	if pid == "":
		return "unknown_player"
	if not OWNER_KINDS.has(mode):
		return "bad_args"
	if mode == "clan" and _clan_of(pid) == "":
		return "no_clan"
	_build_mode[pid] = mode
	return ""

func build_mode(player_id: String) -> String:
	return str(_build_mode.get(_pid(player_id), "private"))

func _on_intent(action: String, args: Dictionary, player_id: String) -> void:
	if not is_host:
		return
	var pid := _pid(player_id)
	var reason := _resolve(action, args, pid)
	GameBus.structure_resolved.emit(pid, action, reason == "", reason)

func _resolve(action: String, args: Dictionary, pid: String) -> String:
	if pid == "":
		return "unknown_player"
	var now := float(mono_sec.call())
	if now - float(_last_intent.get(pid, -1.0e12)) < INTENT_INTERVAL:
		return "rate_limited"
	_last_intent[pid] = now
	match action:
		"build_as":
			return set_build_mode(pid, str(args.get("mode", "")).left(16))
		"repair":
			var sid := owned_structure_near(pid)
			return repair(pid, sid) if sid != 0 else "no_structure"
	return "unknown_action"

func _push_inventory(pid: String) -> void:
	if registry == null or not ("local_player_id" in registry) or pid == str(registry.local_player_id):
		return
	var inv: Node = registry.get_inventory(pid)
	if inv != null and inv.has_method("get_contents"):
		GameBus.inventory_synced.emit(pid, inv.get_contents(), inv.get_durability_data())

# ── persistence ──────────────────────────────────────────────────────────

func to_data() -> Dictionary:
	var list: Array = []
	for sid: int in ids():
		var s: Dictionary = _structures[sid]
		var cells: Array = []
		for t: Vector2i in s["cells"]:
			for mm: int in s["cells"][t]:
				var c: Array = s["cells"][t][mm]
				cells.append([t.x, t.y, mm, c[0], c[1], c[2]])
		var a: Vector2i = s["anchor"]
		list.append({ "id": sid, "kind": s["kind"], "owner": s["owner"], "builder": s["builder"], "anchor": [a.x, a.y],
			"wear": s["wear"], "wear_hour": s["wear_hour"], "credit": (s["credit"] as Dictionary).duplicate(), "cells": cells })
	return { "format": DATA_FORMAT, "next_id": _next_id, "structures": list, "modes": _build_mode.duplicate() }

## Load a saved index. `downtime_hours` is the in-game hours the server was down since the save: each
## structure wears for them once (age, and the weather rolled for those past hours at its anchor).
func from_data(data: Variant, downtime_hours: float = 0.0) -> void:
	_structures.clear()
	_tiles.clear()
	_cell_count = 0
	_sweep_keys.clear()
	_collapse.clear()
	_clear_circles()
	_build_mode.clear()
	_next_id = 1
	if not (data is Dictionary):
		return
	var d: Dictionary = data
	var list: Variant = d.get("structures", [])
	if list is Array:
		for raw: Variant in list:
			_load_one(raw)
	_next_id = maxi(_next_id, int(d.get("next_id", 1)) if (d.get("next_id") is int or d.get("next_id") is float) else 1)
	var modes: Variant = d.get("modes", {})
	if modes is Dictionary:
		for pid: Variant in modes:
			if pid is String and OWNER_KINDS.has(modes[pid]):
				_build_mode[pid] = modes[pid]
	var down := clampf(downtime_hours, 0.0, MAX_DOWNTIME_HOURS)
	if down > 0.0:
		var now := int(now_hour.call())
		for sid: int in _structures:
			var s: Dictionary = _structures[sid]
			s["wear"] = minf(2.0, float(s["wear"]) + Rules.age_wear(down) + _weather_wear(s["anchor"], now - ceili(down), down))

static func _num(v: Variant) -> bool:
	return v is int or v is float

func _load_one(raw: Variant) -> void:
	if not (raw is Dictionary) or _structures.size() >= MAX_STRUCTURES:
		return
	var r: Dictionary = raw
	if not _num(r.get("id")) or not OWNER_KINDS.has(r.get("kind")) or not (r.get("owner") is String) or str(r["owner"]) == "" \
			or not (r.get("cells") is Array) or not (r.get("anchor") is Array) or (r["anchor"] as Array).size() != 2:
		return
	var sid := int(r["id"])
	if sid <= 0 or _structures.has(sid):
		return
	var credit: Dictionary = {}
	if r.get("credit") is Dictionary:
		for m: Variant in r["credit"]:
			if m is String and _num(r["credit"][m]):
				credit[m] = clampf(float(r["credit"][m]), 0.0, 1.0)
	_structures[sid] = { "id": sid, "kind": str(r["kind"]), "owner": str(r["owner"]), "builder": str(r.get("builder", r["owner"])),
		"anchor": Vector2i(int(r["anchor"][0]), int(r["anchor"][1])), "wear": clampf(float(r.get("wear", 0.0)) if _num(r.get("wear")) else 0.0, 0.0, 2.0),
		"wear_hour": int(r.get("wear_hour", 0)) if _num(r.get("wear_hour")) else int(now_hour.call()), "credit": credit, "cells": {}, "count": 0 }
	for c: Variant in r["cells"]:
		if _cell_count >= MAX_CELLS:
			break
		if not (c is Array) or (c as Array).size() != 6 or not _num(c[0]) or not _num(c[1]) or not _num(c[2]) \
				or not GameData.MATERIALS.has(c[3]) or not _num(c[4]) or not _num(c[5]):
			continue
		var t := Vector2i(int(c[0]), int(c[1]))
		if int(_tiles.get(t, {}).get(int(c[2]), 0)) != 0:
			continue   # two records claim one block: the first keeps it
		_add_cell(sid, t, int(c[2]), [str(c[3]), maxf(0.0, float(c[4])), clampf(float(c[5]), 0.0, 2.0)])
	if int(_structures[sid]["count"]) <= 0:
		_structures.erase(sid)
		return
	_next_id = maxi(_next_id, sid + 1)
