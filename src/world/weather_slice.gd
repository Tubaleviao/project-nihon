extends Node
## Weather slice — the fabric's `WeatherSystem` runs (Phase 128). Weather is a deterministic function of
## the world seed, the weather cell, the cell's biome, the season and the in-game hour bucket, so every
## host and client computes the same state with no per-tile sync. The host owns overrides (an admin
## `/weather`): a cell → { state, end_hour } table, saved with `world.json` and pushed to clients on join
## and on every change.
##
## Plug contract (GameBus):
##   IN  : (none — the host's `/weather` command calls `set_override` directly)
##   OUT : weather_overrides_synced(overrides), weather_changed(state)
##
## Public API:
##   rules() -> Dictionary                         the fabric table (with defaults)
##   state_ids() -> Array                          sorted state ids
##   cell_of(chunk) -> Vector2i                    the weather cell a chunk is in (X wrapped on the planet)
##   allowed_states(biome, temperature_c) -> Array the states a biome may roll at a seasonal temperature
##   rolled_state(cell, hour) -> String            the state with no override
##   weather_at(chunk, hour) -> String             the state, override included
##   current_for(position) -> String               the state under a world position at the clock's hour
##   move_factor(state) / visibility_factor(state) -> float
##   set_override(cell, state, hours) -> String    "" when set, else a reason code (host)
##   to_data() / from_data(data) / apply_view(list)

const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const WorldClock := preload("res://src/world/world_clock.gd")

const DEFAULT_RULES := {
	"cellSizeChunks": 64, "hoursPerRoll": 6, "overrideMaxHours": 48,
	"states": {
		"clear": { "moveSpeedFactor": 1.0, "visibilityFactor": 1.0, "minTemperature": -100.0, "maxTemperature": 100.0, "minRainfall": 0.0, "weight": 1.0, "biomes": [], "exceptBiomes": [] },
	},
	"climate": {},
}

## Every refusal code `set_override` can return.
const REASONS := ["unknown_state", "bad_hours", "too_long", "bad_cell"]
## Most overrides held at once; the oldest-ending is dropped past it, so memory stays bounded.
const MAX_OVERRIDES := 256
const SALT_A := 0x1E3779B97F4A7C15
const SALT_B := 0x3F58476D1CE4E5B9
const SALT_C := 0x14D049BB133111EB

## Set by game_root.
var clock: RefCounted = null
## `() -> int` the world seed; `(chunk: Vector2i) -> String` the biome of a chunk. Defaults to 0 / "" (clear).
var seed_of: Callable = Callable()
var biome_of: Callable = Callable()

## "cx,cy" → { "cell": Vector2i, "state": String, "end_hour": int }.
var _overrides: Dictionary = {}
var _rules_cache: Dictionary = {}
var _last_local: String = ""
## Bumped whenever the override table changes; keys the one-entry `weather_at` cache.
var _revision: int = 0
var _memo_key: Array = []
var _memo_state: String = ""

## The fabric table merged over the defaults; cached after the first read.
func rules() -> Dictionary:
	if not _rules_cache.is_empty():
		return _rules_cache
	var out := DEFAULT_RULES.duplicate(true)
	var res: Resource = GameData.WORLD_SYSTEMS.get("WeatherSystem", null)
	if res != null:
		var r: Variant = res.get("rules")
		if r is Dictionary and not (r as Dictionary).is_empty():
			out.merge(r, true)
	_rules_cache = out
	return out

func state_ids() -> Array:
	var ids: Array = (rules()["states"] as Dictionary).keys()
	ids.sort()
	return ids

func _state(id: String) -> Dictionary:
	var s: Variant = (rules()["states"] as Dictionary).get(id, null)
	return s if s is Dictionary else {}

func move_factor(state: String) -> float:
	return float(_state(state).get("moveSpeedFactor", 1.0))

func visibility_factor(state: String) -> float:
	return float(_state(state).get("visibilityFactor", 1.0))

func cell_size() -> int:
	return maxi(1, int(rules()["cellSizeChunks"]))

func hours_per_roll() -> int:
	return maxi(1, int(rules()["hoursPerRoll"]))

func override_max_hours() -> int:
	return maxi(1, int(rules()["overrideMaxHours"]))

## The weather cell holding `chunk`: X is wrapped onto one lap of the planet first, so a chunk and the
## same chunk one lap along share a cell.
func cell_of(chunk: Vector2i) -> Vector2i:
	var cs := cell_size()
	var x := posmod(chunk.x, TerrainSlice.circumference_chunks())
	return Vector2i(x / cs, floori(float(chunk.y) / float(cs)))

## The chunk at the middle of a cell (its biome and latitude stand for the whole cell).
func cell_center(cell: Vector2i) -> Vector2i:
	var cs := cell_size()
	return Vector2i(cell.x * cs + cs / 2, cell.y * cs + cs / 2)

## One splitmix64 round (64-bit wrapping arithmetic; right shifts are masked to stay logical).
static func _mix1(x: int) -> int:
	x += SALT_A
	x = (x ^ ((x >> 30) & 0x3FFFFFFFF)) * SALT_B
	x = (x ^ ((x >> 27) & 0x1FFFFFFFFF)) * SALT_C
	return x ^ ((x >> 31) & 0x1FFFFFFFF)

## The integer mix of a seed, a cell and an hour bucket. Pinned by golden values in the suite.
static func mix(seed_v: int, cell_x: int, cell_y: int, bucket: int) -> int:
	return _mix1(_mix1(_mix1(_mix1(seed_v) ^ cell_x) ^ cell_y) ^ bucket)

## The climate of a biome as { temperature, rainfall, swing }: the fabric's `climate` override, else the biome's own.
func climate_of(biome: String) -> Dictionary:
	var b: Variant = GameData.BIOMES.get(biome, null)
	var swing := 0.0
	var temp := 0.0
	var rain := 0.0
	if b != null:
		swing = float(b.get("seasonSwing")) if b.get("seasonSwing") != null else 0.0
		temp = float(b.get("avgTemperature")) if b.get("avgTemperature") != null else 0.0
		rain = float(b.get("avgRainfall")) if b.get("avgRainfall") != null else 0.0
	var over: Variant = (rules()["climate"] as Dictionary).get(biome, null)
	if over is Dictionary:
		temp = float(over.get("temperature", temp))
		rain = float(over.get("rainfall", rain))
	return { "temperature": temp, "rainfall": rain, "swing": swing }

## The state ids `biome` may roll at a seasonal temperature (°C), sorted. "clear" is always among them
## unless a table removes it.
func allowed_states(biome: String, temperature_c: float) -> Array:
	var rain: float = climate_of(biome)["rainfall"]
	var out: Array = []
	for id in state_ids():
		var s := _state(id)
		if float(s.get("weight", 0.0)) <= 0.0:
			continue
		var only: Array = s.get("biomes", [])
		if not only.is_empty() and not (biome in only):
			continue
		if biome in (s.get("exceptBiomes", []) as Array):
			continue
		if temperature_c < float(s.get("minTemperature", -100.0)) or temperature_c > float(s.get("maxTemperature", 100.0)) or rain < float(s.get("minRainfall", 0.0)):
			continue
		out.append(id)
	return out

## Seasonal temperature (°C) of `biome` at latitude `lat` and in-game `hour`.
func temperature_at(biome: String, lat: float, hour: int) -> float:
	var c := climate_of(biome)
	var year_days: float = clock.year_length_days if clock != null else 32.0
	var yf := WorldClock.year_fraction(float(hour) / 24.0, year_days)
	return WorldClock.seasonal_temperature(c["temperature"], c["swing"], WorldClock.warmth(lat, yf))

func _seed() -> int:
	return int(seed_of.call()) if seed_of.is_valid() else 0

func _biome(chunk: Vector2i) -> String:
	return str(biome_of.call(chunk)) if biome_of.is_valid() else ""

## The state a cell rolls for the hour bucket holding `hour`, ignoring overrides.
func rolled_state(cell: Vector2i, hour: int) -> String:
	var center := cell_center(cell)
	var biome := _biome(center)
	var lat := TerrainSlice.latitude_of(center.y)
	var allowed := allowed_states(biome, temperature_at(biome, lat, hour))
	if allowed.is_empty():
		return "clear"
	var total := 0.0
	for id in allowed:
		total += float(_state(id)["weight"])
	var bucket := floori(float(hour) / float(hours_per_roll()))
	var r := float(mix(_seed(), cell.x, cell.y, bucket) & 0xFFFFFF) / float(0x1000000) * total
	for id in allowed:
		r -= float(_state(id)["weight"])
		if r < 0.0:
			return id
	return allowed[-1]

## The weather in `chunk` at in-game `hour` (whole hours since day 0): an unexpired override wins.
func weather_at(chunk: Vector2i, hour: int) -> String:
	var cell := cell_of(chunk)
	var key := [cell, hour, _revision]
	if key == _memo_key:
		return _memo_state
	var o: Variant = _overrides.get(_key(cell), null)
	var state := str(o["state"]) if o is Dictionary and hour < int(o["end_hour"]) else rolled_state(cell, hour)
	_memo_key = key
	_memo_state = state
	return state

## The in-game hour the clock reads now.
func current_hour() -> int:
	return floori(clock.time_days * 24.0) if clock != null else 0

## The weather under a world position (metres) at the clock's hour.
func current_for(position: Vector3) -> String:
	var cm := TerrainSlice.CHUNK_METERS
	return weather_at(Vector2i(floori(position.x / cm), floori(position.z / cm)), current_hour())

static func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

# ---------------------------------------------------------------------------
# Overrides (host)
# ---------------------------------------------------------------------------

## True for a cell some chunk can be in: X within one lap, Y within the planet's height.
func _valid_cell(cell: Vector2i) -> bool:
	var circ := TerrainSlice.circumference_chunks()
	return cell.x >= 0 and cell.x <= cell_of(Vector2i(circ - 1, 0)).x \
		and absi(cell.y) <= circ / cell_size() + 1

## The hour an override of `hours` whole hours from the clock's exact time ends: rounded up, so it never
## lasts less than asked.
func _end_hour_for(hours: int) -> int:
	return ceili(clock.time_days * 24.0) + hours if clock != null else hours

## Override `cell` to `state` for `hours` in-game hours from now. "" when set, else a `REASONS` code.
func set_override(cell: Vector2i, state: String, hours: int) -> String:
	if not (rules()["states"] as Dictionary).has(state):
		return "unknown_state"
	if hours < 1:
		return "bad_hours"
	if hours > override_max_hours():
		return "too_long"
	if not _valid_cell(cell):
		return "bad_cell"
	_revision += 1
	_overrides[_key(cell)] = { "cell": cell, "state": state, "end_hour": _end_hour_for(hours) }
	_prune(current_hour())
	print("[Weather] override cell %s -> %s for %d h (until hour %d)" % [cell, state, hours, _end_hour_for(hours)])
	GameBus.weather_overrides_synced.emit(to_data())
	return ""

## Drop expired overrides, then the soonest-ending ones past `MAX_OVERRIDES`. True when any went.
func _prune(hour: int) -> bool:
	var dropped := false
	for k in _overrides.keys():
		if hour >= int(_overrides[k]["end_hour"]):
			_overrides.erase(k)
			dropped = true
	while _overrides.size() > MAX_OVERRIDES:
		var oldest := ""
		for k in _overrides:
			if oldest == "" or int(_overrides[k]["end_hour"]) < int(_overrides[oldest]["end_hour"]):
				oldest = k
		_overrides.erase(oldest)
		dropped = true
	if dropped:
		_revision += 1
	return dropped

## Host: expire finished overrides and tell clients when any went.
func tick() -> void:
	if _prune(current_hour()):
		GameBus.weather_overrides_synced.emit(to_data())

func override_count() -> int:
	return _overrides.size()

## The overrides as `[[cell_x, cell_y, state, end_hour], ...]`, sorted — the save and wire form.
func to_data() -> Array:
	var out: Array = []
	for k in _overrides:
		var o: Dictionary = _overrides[k]
		out.append([(o["cell"] as Vector2i).x, (o["cell"] as Vector2i).y, str(o["state"]), int(o["end_hour"])])
	out.sort()
	return out

## Replace the table from a saved or wired list. A malformed entry or an unknown state is dropped; the
## count is bounded. Reached from the network, so every field is checked.
func from_data(data: Variant) -> void:
	_overrides.clear()
	_revision += 1
	if not (data is Array):
		return
	var states: Dictionary = rules()["states"]
	var now := current_hour()
	for e in (data as Array):
		if _overrides.size() >= MAX_OVERRIDES:
			break
		if not (e is Array) or (e as Array).size() != 4:
			continue
		var a: Array = e
		if not (a[0] is int or a[0] is float) or not (a[1] is int or a[1] is float) or not (a[3] is int or a[3] is float) or not (a[2] is String):
			continue
		if not states.has(a[2]):
			continue
		var cell := Vector2i(int(a[0]), int(a[1]))
		var end_hour := int(a[3])
		if not _valid_cell(cell) or end_hour <= now or end_hour > now + override_max_hours() + 1:
			continue
		_overrides[_key(cell)] = { "cell": cell, "state": str(a[2]), "end_hour": end_hour }

## CLIENT: adopt the host's list.
func apply_view(data: Variant) -> void:
	from_data(data)

# ---------------------------------------------------------------------------
# Local player
# ---------------------------------------------------------------------------

## Emit `weather_changed` when the state in `chunk` differs from the last one reported.
## Returns the current state.
func update_local(chunk: Vector2i) -> String:
	var s := weather_at(chunk, current_hour())
	if s != _last_local:
		_last_local = s
		GameBus.weather_changed.emit(s)
	return s
