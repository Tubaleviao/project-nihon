extends RefCounted
## Phase 54 — the world's clock, day length, seasons and sun.
##
## Time is one number: `time_days`, the in-game days elapsed since the world began (day 0,
## midnight, spring equinox). The HOST owns it: it advances with real time, is saved on the
## world record, rides the join snapshot and is corrected by a periodic tick. A CLIENT runs the
## same advance locally (so it needs no per-frame traffic) and applies each host sample with
## `apply_host_time`: a small error is slewed away, a large one snaps, so the two clocks stay
## within a second of each other however long the session runs.
##
## Everything derived from the time (sun angle, daylight, season, seasonal temperature, tint,
## growth and spawn multipliers) is a static pure function of (time, latitude, fabric values),
## so the suite pins it without a scene tree.
##
## Conventions: year fraction 0 is the northern spring equinox, 0.25 the northern summer
## solstice. A day starts at midnight, so day phase 0.5 is solar noon. "Warmth" is the season's
## position on [-1 (depth of winter), +1 (height of summer)] for a latitude: the southern
## hemisphere is half a year out of phase, and the seasons fade to nothing at the equator.

const WORLD_SYSTEM_KEY := "WorldSystem"

## Latitude (degrees) at which the seasons reach full strength; between the equator and here
## the warmth swing scales down linearly.
const FULL_SEASON_LATITUDE := 30.0
## Real seconds of error a client slews away over `SLEW_SECONDS`; beyond `SNAP_SECONDS` it jumps.
const SNAP_SECONDS := 2.0
const SLEW_SECONDS := 4.0
## Seconds between the host's clock ticks.
const TICK_SECONDS := 5.0

const SEASONS := ["spring", "summer", "autumn", "winter"]

## In-game days since the world began.
var time_days: float = 0.0
var day_length_minutes: float = 24.0
var year_length_days: float = 32.0
var axial_tilt: float = 23.5
## Pending slew (in-game days) a client is still working off.
var _slew_days: float = 0.0

func _init() -> void:
	load_fabric()

## Read the fabric's `WorldSystem` fields (the defaults above are the fallbacks for a rig
## without the resource).
func load_fabric() -> void:
	var ws: Variant = GameData.WORLD_SYSTEMS.get(WORLD_SYSTEM_KEY, null)
	if ws == null:
		return
	if ws.get("dayLengthMinutes") != null and float(ws.get("dayLengthMinutes")) > 0.0:
		day_length_minutes = float(ws.get("dayLengthMinutes"))
	if ws.get("yearLengthDays") != null and float(ws.get("yearLengthDays")) > 0.0:
		year_length_days = float(ws.get("yearLengthDays"))
	if ws.get("axialTilt") != null:
		axial_tilt = float(ws.get("axialTilt"))

## Real seconds one in-game day lasts.
func day_seconds() -> float:
	return day_length_minutes * 60.0

## Advance by `delta` real seconds. A pending client slew is paid out alongside, at the rate
## that clears it in `SLEW_SECONDS`.
func advance(delta: float) -> void:
	time_days += delta / day_seconds()
	if _slew_days != 0.0:
		var step: float = _slew_days * minf(delta / SLEW_SECONDS, 1.0)
		time_days += step
		_slew_days -= step
		if absf(_slew_days) < 1e-9:
			_slew_days = 0.0

## CLIENT: take a host sample (`host_days` is the host's time_days when it sent the tick).
## Within `SNAP_SECONDS` of error the difference is slewed in; beyond it the clock jumps.
func apply_host_time(host_days: float) -> void:
	var error_days := host_days - (time_days + _slew_days)
	if absf(error_days) * day_seconds() > SNAP_SECONDS:
		time_days = host_days
		_slew_days = 0.0
	else:
		_slew_days = error_days + _slew_days

## Seconds the local clock is off `host_days`, signed (positive = behind). For the harness.
func error_seconds(host_days: float) -> float:
	return (host_days - (time_days + _slew_days)) * day_seconds()

func to_data() -> Dictionary:
	return { "time_days": time_days }

func from_data(data: Variant) -> void:
	if data is Dictionary and (data as Dictionary).has("time_days"):
		var t: float = float((data as Dictionary)["time_days"])
		if not is_nan(t) and not is_inf(t) and t >= 0.0:
			time_days = t
			_slew_days = 0.0

# ---------------------------------------------------------------------------
# Pure projections
# ---------------------------------------------------------------------------

## Fraction of the day elapsed, [0, 1): 0 midnight, 0.5 solar noon.
static func day_phase(t_days: float) -> float:
	return fposmod(t_days, 1.0)

## Whole day of the year, 1-based.
static func day_of_year(t_days: float, year_days: float) -> int:
	return int(floorf(fposmod(t_days, year_days))) + 1

## Fraction of the year elapsed, [0, 1): 0 the northern spring equinox.
static func year_fraction(t_days: float, year_days: float) -> float:
	return fposmod(t_days, year_days) / year_days

## Sun's declination in degrees: +tilt at the northern summer solstice, -tilt at the winter one.
static func declination_deg(year_frac: float, tilt_deg: float) -> float:
	return tilt_deg * sin(TAU * year_frac)

## Share of the 24 hours the sun is above the horizon at `lat_deg`, in [0, 1]. 0.5 on the
## equator all year; 1 in polar day and 0 in polar night.
static func daylight_fraction(lat_deg: float, decl_deg: float) -> float:
	var x: float = -tan(deg_to_rad(lat_deg)) * tan(deg_to_rad(decl_deg))
	if x <= -1.0:
		return 1.0
	if x >= 1.0:
		return 0.0
	return acos(x) / PI

## Sun elevation above the horizon in degrees (negative below it).
static func sun_elevation_deg(lat_deg: float, decl_deg: float, phase: float) -> float:
	var h: float = (phase - 0.5) * TAU
	var lat := deg_to_rad(lat_deg)
	var decl := deg_to_rad(decl_deg)
	return rad_to_deg(asin(clampf(sin(lat) * sin(decl) + cos(lat) * cos(decl) * cos(h), -1.0, 1.0)))

## Sun azimuth swing for rendering: the hour angle in degrees from solar noon (-180..180).
static func hour_angle_deg(phase: float) -> float:
	return (phase - 0.5) * 360.0

## Season strength on [-1, +1] for a latitude: +1 the height of that hemisphere's summer, -1
## the depth of its winter, 0 at an equinox (and always ~0 on the equator).
static func warmth(lat_deg: float, year_frac: float) -> float:
	return sin(TAU * year_frac) * clampf(lat_deg / FULL_SEASON_LATITUDE, -1.0, 1.0)

## "spring" | "summer" | "autumn" | "winter" for a latitude and year fraction. The southern
## hemisphere reads the same calendar half a year later.
static func season_of(lat_deg: float, year_frac: float) -> String:
	var yf: float = year_frac if lat_deg >= 0.0 else fposmod(year_frac + 0.5, 1.0)
	if yf >= 0.125 and yf < 0.375:
		return "summer"
	if yf >= 0.375 and yf < 0.625:
		return "autumn"
	if yf >= 0.625 and yf < 0.875:
		return "winter"
	return "spring"

## Seasonal temperature in °C: the biome's annual average plus its swing scaled by the warmth.
static func seasonal_temperature(avg_c: float, swing_c: float, warmth_v: float) -> float:
	return avg_c + swing_c * warmth_v

## Snow lies where the seasonal temperature is below freezing.
static func is_snowing_ground(temp_c: float) -> bool:
	return temp_c < 0.0

## Position of a warmth value between winter (0) and summer (1).
static func summer_share(warmth_v: float) -> float:
	return clampf((warmth_v + 1.0) * 0.5, 0.0, 1.0)

## The biome's foliage/ground multiplier colour for a warmth.
static func season_tint(biome: Variant, warmth_v: float) -> Color:
	if biome == null or biome.get("summerTint") == null:
		return Color.WHITE
	var summer := Color.from_string(str(biome.get("summerTint")), Color.WHITE)
	var winter := Color.from_string(str(biome.get("winterTint")), Color.WHITE)
	return winter.lerp(summer, summer_share(warmth_v))

## Linear blend of a `{summer, winter}` fabric pair for a warmth; 1.0 when absent.
static func seasonal_multiplier(pair: Variant, warmth_v: float) -> float:
	if not (pair is Dictionary):
		return 1.0
	var d: Dictionary = pair
	var s: float = float(d.get("summer", 1.0))
	var w: float = float(d.get("winter", 1.0))
	return lerpf(w, s, summer_share(warmth_v))

## Tree regrowth speed multiplier of a biome for a warmth (fabric `seasonGrowth`).
static func growth_multiplier(biome: Variant, warmth_v: float) -> float:
	if biome == null:
		return 1.0
	return maxf(seasonal_multiplier(biome.get("seasonGrowth"), warmth_v), 0.05)

## Creature spawn-chance multiplier of a biome for a warmth (fabric `seasonSpawn`).
static func spawn_multiplier(biome: Variant, warmth_v: float) -> float:
	if biome == null:
		return 1.0
	return maxf(seasonal_multiplier(biome.get("seasonSpawn"), warmth_v), 0.0)

## The Twilight Grove's `dayNightSpeed` against the global clock: how deep the biome's night
## runs. `daylight` is the global 0..1 light level; speed 1 follows it, 0 stays at dusk (0.5).
static func biome_daylight(daylight: float, night_speed: float) -> float:
	return clampf(lerpf(0.5, daylight, clampf(night_speed, 0.0, 1.0)), 0.0, 1.0)

## 0..1 light level from the sun elevation: dark below -6° (past civil twilight), full by +25°.
static func daylight_level(elevation_deg: float) -> float:
	return clampf((elevation_deg + 6.0) / 31.0, 0.0, 1.0)

## The HUD line: "Day 12 · 14:30 · Summer".
static func hud_text(t_days: float, year_days: float, lat_deg: float) -> String:
	var phase := day_phase(t_days)
	var minutes_total: int = int(floorf(phase * 1440.0))
	var yf := year_fraction(t_days, year_days)
	var s := season_of(lat_deg, yf)
	return "Day %d · %02d:%02d · %s" % [day_of_year(t_days, year_days),
			minutes_total / 60, minutes_total % 60, s.capitalize()]

## Convenience on the instance: this clock's text and season for a latitude.
func text_for(lat_deg: float) -> String:
	return hud_text(time_days, year_length_days, lat_deg)

func warmth_at(lat_deg: float) -> float:
	return warmth(lat_deg, year_fraction(time_days, year_length_days))

func season_at(lat_deg: float) -> String:
	return season_of(lat_deg, year_fraction(time_days, year_length_days))

func declination() -> float:
	return declination_deg(year_fraction(time_days, year_length_days), axial_tilt)

func sun_elevation_at(lat_deg: float) -> float:
	return sun_elevation_deg(lat_deg, declination(), day_phase(time_days))
