class_name WaystoneSlice
extends Node
## Waystone slice — a first fast-travel network (Phase 125). A waystone is a placed station of the
## fabric's `WaystoneTravel.stationType`. A player attunes to a stone by standing within the attune
## radius of it; they may then travel from a stone they stand at to any other stone they are attuned
## to, paying `costPerThousandKm` of `costItem` per 1,000 km, once per cooldown.
##
## The host decides everything. Attunements live on the player record (PlayerRegistry.waystones), so
## they survive a save and a reconnect; the cooldown and the intent rate limit are in-memory.
##
## Plug contract (GameBus):
##   IN  : waystone_travel_intent(from_id, to_id, player_id)
##   OUT : waystone_travel_resolved(player_id, ok, reason), waystones_synced(player_id, station_ids)
##
## Public API:
##   rules() -> Dictionary                      the fabric table (with defaults)
##   is_waystone(station_id) -> bool
##   waystone_ids() -> Array                    sorted station ids of every standing waystone
##   exact_pos(station_id) -> Dictionary        the stone's `{chunk, local}` (empty when gone)
##   attuned(player_id) -> Array                sorted station ids still standing
##   try_attune(player_id, station_id) -> String   "" when attuned, else a reason code
##   travel_cost(from_id, to_id) -> int
##   travel(from_id, to_id, player_id) -> String   "" when the player was moved, else a reason code

const WorldPos := preload("res://src/terrain/world_pos.gd")
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const Diag := preload("res://src/core/diag.gd")

## Every refusal code `travel` can return.
const REASONS := ["unknown_player", "rate_limited", "same_stone", "missing_stone", "not_attuned_from",
	"not_attuned_to", "too_far", "cooldown", "no_cost", "unreachable"]

## Seconds a player must wait between two intents, whatever their outcome.
const INTENT_INTERVAL := 0.5
## Seconds between host sweeps that attune players standing at a stone.
const ATTUNE_SWEEP_SEC := 1.0

const DEFAULT_RULES := {
	"stationType": "waystone", "attuneRadius": 4.0, "cooldownSeconds": 30,
	"costItem": "AethermiteShard", "costPerThousandKm": 1,
}

## Set by game_root.
var station_slice: Node = null
var registry: Node = null
## `(player_id: String, pos: Dictionary) -> bool` moves the player's body; true when it was applied or sent.
var teleporter: Callable = Callable()
var now_sec: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0
## Test seam: `(player_id) -> Dictionary` overrides where a player stands (an exact `{chunk, local}`).
var position_of: Callable = Callable()
## Exact `{chunk, local}` per station, recorded when a stone is placed with one (see `note_exact`).
var _exact: Dictionary = {}
var _cooldown_until: Dictionary = {}   # player id -> seconds
var _last_intent: Dictionary = {}      # player id -> seconds
var _sweep_clock: float = 0.0
## Client view: the stones this machine's player is attuned to, as the host last said.
var _view: Array = []

func _ready() -> void:
	GameBus.waystone_travel_intent.connect(_on_travel_intent)

func rules() -> Dictionary:
	var out := DEFAULT_RULES.duplicate()
	var res: Resource = GameData.WORLD_SYSTEMS.get("WaystoneTravel", null)
	if res != null:
		var r: Variant = res.get("rules")
		if r is Dictionary:
			out.merge(r, true)
	return out

func station_type() -> String:
	return str(rules()["stationType"])

func is_waystone(station_id: String) -> bool:
	if station_slice == null:
		return false
	var st: Dictionary = station_slice.get_station(station_id)
	return not st.is_empty() and str(st.get("type", "")) == station_type()

func waystone_ids() -> Array:
	var out: Array = []
	if station_slice == null:
		return out
	for st in station_slice.get_all_stations():
		if str(st.get("type", "")) == station_type():
			out.append(str(st["id"]))
	out.sort()
	return out

## Record the exact position of a stone placed far from the origin, where a `Vector3` is coarse.
func note_exact(station_id: String, pos: Dictionary) -> void:
	_exact[station_id] = pos

func exact_pos(station_id: String) -> Dictionary:
	if not is_waystone(station_id):
		_exact.erase(station_id)
		return {}
	if _exact.has(station_id):
		return _exact[station_id]
	var p: Vector3 = station_slice.get_station(station_id)["position"]
	return WorldPos.from_world(p.x, p.y, p.z)

func _player_pos(player_id: String) -> Dictionary:
	if position_of.is_valid():
		return position_of.call(player_id)
	if registry == null:
		return {}
	return registry.get_world_pos(player_id)

## Ground metres between two exact positions (height is ignored: a body settling onto the ground is
## still at the stone), going the short way round the planet.
static func distance_m(a: Dictionary, b: Dictionary) -> float:
	var lap: int = TerrainSlice.circumference_chunks()
	var dc: Vector2i = b["chunk"] - a["chunk"]
	dc.x = posmod(dc.x + lap / 2, lap) - lap / 2
	var d := Vector3(float(dc.x) * WorldPos.CHUNK_METERS, 0.0, float(dc.y) * WorldPos.CHUNK_METERS) \
		+ (b["local"] as Vector3) - (a["local"] as Vector3)
	d.y = 0.0
	return d.length()

func travel_cost(from_id: String, to_id: String) -> int:
	var per_k: int = int(rules()["costPerThousandKm"])
	if per_k <= 0:
		return 0
	var km := distance_m(exact_pos(from_id), exact_pos(to_id)) / 1000.0
	return maxi(1, int(ceil(km / 1000.0 * per_k)))

## The stones `player_id` is attuned to that still stand. On a client, the host's last word.
func attuned(player_id: String) -> Array:
	var raw: Array = _view if registry == null or not registry.is_authoritative else registry.get_waystones(player_id)
	var out: Array = []
	for id in raw:
		if is_waystone(str(id)):
			out.append(str(id))
	return out

## Attune `player_id` to `station_id` when they stand within the attune radius. "" on success.
func try_attune(player_id: String, station_id: String) -> String:
	if registry == null or player_id == "" or not registry.has_player(player_id):
		return "unknown_player"
	if not is_waystone(station_id):
		return "missing_stone"
	var pos := _player_pos(player_id)
	if pos.is_empty() or distance_m(pos, exact_pos(station_id)) > float(rules()["attuneRadius"]):
		return "too_far"
	var have: Array = registry.get_waystones(player_id)
	if have.has(station_id):
		return ""
	have.append(station_id)
	registry.record_waystones(player_id, have)
	GameBus.waystones_synced.emit(player_id, registry.get_waystones(player_id))
	return ""

## Host: attune every online player standing at a stone, at most once per `ATTUNE_SWEEP_SEC`.
func _process(delta: float) -> void:
	_sweep_clock += delta
	if _sweep_clock < ATTUNE_SWEEP_SEC:
		return
	_sweep_clock = 0.0
	sweep_attunements()

func sweep_attunements() -> void:
	if registry == null or station_slice == null or not registry.is_authoritative:
		return
	var stones := waystone_ids()
	if stones.is_empty():
		return
	for pid in registry.get_online_player_ids():
		for sid in stones:
			try_attune(str(pid), str(sid))

## Host: move `player_id` from the stone they stand at to another they are attuned to. Returns "" when
## the player was moved, else one of `REASONS`; the cost is paid only when the move happened.
func travel(from_id: String, to_id: String, player_id: String) -> String:
	if registry == null or player_id == "" or not registry.has_player(player_id):
		return "unknown_player"
	var now: float = now_sec.call()
	if now - float(_last_intent.get(player_id, -INF)) < INTENT_INTERVAL:
		return "rate_limited"
	_last_intent[player_id] = now
	if _last_intent.size() > 1024:
		_prune(now)
	if from_id == to_id:
		return "same_stone"
	if not is_waystone(from_id) or not is_waystone(to_id):
		return "missing_stone"
	var have: Array = registry.get_waystones(player_id)
	if not have.has(from_id):
		return "not_attuned_from"
	if not have.has(to_id):
		return "not_attuned_to"
	var here := _player_pos(player_id)
	if here.is_empty() or distance_m(here, exact_pos(from_id)) > float(rules()["attuneRadius"]):
		return "too_far"
	if now < float(_cooldown_until.get(player_id, -INF)):
		return "cooldown"
	var cost := travel_cost(from_id, to_id)
	var item := str(rules()["costItem"])
	var inv: Node = registry.get_inventory(player_id)
	if cost > 0 and (inv == null or inv.get_item_count(item) < cost):
		return "no_cost"
	if cost > 0 and not inv.consume_items({ item: cost }):
		return "no_cost"
	if not teleporter.is_valid() or not bool(teleporter.call(player_id, exact_pos(to_id))):
		if cost > 0:
			inv.add_item(item, cost)
		return "unreachable"
	_cooldown_until[player_id] = now + float(rules()["cooldownSeconds"])
	return ""

func _prune(now: float) -> void:
	for pid in _last_intent.keys():
		if now - float(_last_intent[pid]) > 60.0:
			_last_intent.erase(pid)
	for pid in _cooldown_until.keys():
		if now >= float(_cooldown_until[pid]):
			_cooldown_until.erase(pid)

func _on_travel_intent(from_id: String, to_id: String, player_id: String) -> void:
	if registry == null or not registry.is_authoritative:
		return
	var pid: String = player_id if player_id != "" else str(registry.local_player_id)
	var reason := travel(from_id, to_id, pid)
	if reason != "":
		Diag.warn("WaystoneSlice: travel %s -> %s for %s refused: %s" % [from_id, to_id, pid, reason])
	GameBus.waystone_travel_resolved.emit(pid, reason == "", reason)

## Client: remember the host's attunement list for the map.
func apply_view(station_ids: Array) -> void:
	_view = registry.sanitize_waystones(station_ids) if registry != null else station_ids.duplicate()
