extends "res://src/core/wiring.gd"
## Weather wiring (Phase 132) — World clock, sun, season and weather look.
## Moved out of game_root.gd; `root` is the GameRoot that owns the slices.

const TerrainSlice     := preload("res://src/terrain/terrain_slice.gd")
const WorldClock       := preload("res://src/world/world_clock.gd")

## Phase 164 — the sky and the haze. The sky's horizon and ground colours ARE the haze (fog) colour, so
## the far ring fades into the sky at the horizon with no edge; the sun drives both through
## `apply_sky_look`, and weather only thickens the fog on top of the clear-weather base.
const SKY_TOP_DAY := Color(0.3, 0.5, 0.82)
const SKY_TOP_NIGHT := Color(0.01, 0.015, 0.04)
const HAZE_DAY := Color(0.66, 0.74, 0.84)
const HAZE_NIGHT := Color(0.02, 0.03, 0.08)
const HAZE_DENSITY := 0.00015   ## clear-weather exponential fog: ~14% at 1 km, ~95% at 20 km
const HAZE_AERIAL := 0.5        ## how much the fog takes its colour from the sky behind it

## Seconds since the host last ticked status effects / sent a world-clock tick (module-only state).
var _status_tick_elapsed: float = 0.0
var _clock_tick_elapsed: float = 0.0

func _connect_all() -> void:
	connect_bus(GameBus.weather_overrides_synced, _on_weather_overrides_synced)
	connect_bus(GameBus.world_clock_received, _on_world_clock_received)

## Phase 54 — advance the clock, tick it to clients (host), and drive the sun, the season tint
## and the HUD line (anything with a renderer). A server runs no renderer, so it only advances,
## saves and ticks.
func tick_world_clock(delta: float) -> void:
	root._clock.advance(delta)
	if not root._is_client:
		root._weather.tick()
		_status_tick_elapsed += delta
		if _status_tick_elapsed >= root.STATUS_TICK_SECONDS:
			_status_tick_elapsed = 0.0
			root._combat_wiring.tick_status_effects()
	if not root._is_client and root._networking != null and root._networking.is_host():
		_clock_tick_elapsed += delta
		if _clock_tick_elapsed >= root.clock_tick_seconds:
			_clock_tick_elapsed = 0.0
			root.clock_ticks_sent += 1
			root._networking.broadcast_world_clock(root._clock.time_days)
	if root._is_server or root._player == null:
		return
	var ppos: Vector3 = root._player.get_position()
	var lat: float = TerrainSlice.latitude_at(ppos.z)
	apply_sun(lat, _night_speed_at(ppos))
	_apply_season_look(lat)
	var chunk: Vector2i = root._player.get_world_pos()["chunk"]
	var weather_state := root._weather.update_local(chunk)
	_apply_weather_look(weather_state)
	var text := root._clock.text_for(lat)
	if weather_state != "clear":
		text += " · " + weather_state.replace("_", " ").capitalize()
	if text != root._last_clock_text:
		root._last_clock_text = text
		if root._minimap != null:
			root._minimap.clock_text = text
			root._minimap.queue_redraw()

## Phase 128 — thicken the fog as the state's `visibilityFactor` falls (a client with a renderer only).
## Phase 164 — on top of the clear-weather haze; the fog's colour stays the sky's (`apply_sky_look`).
func _apply_weather_look(state: String) -> void:
	var env_node := root.get_node_or_null("Environment") as WorldEnvironment
	if env_node == null or env_node.environment == null:
		return
	apply_weather_fog(env_node.environment, root._weather.visibility_factor(state), root.WEATHER_FOG_DENSITY)

## Phase 164 — the fog for a weather `vis` (visibilityFactor, 1 = clear): the haze base plus the
## weather's share, and in thick weather the sky is fogged too (with the same colour as its horizon).
static func apply_weather_fog(env: Environment, vis: float, weather_density: float) -> void:
	var v := clampf(vis, 0.0, 1.0)
	env.fog_enabled = true
	env.fog_density = HAZE_DENSITY + (1.0 - v) * weather_density
	env.fog_sky_affect = 1.0 - v

## Phase 164 — the haze colour at a `daylight` level (0 night .. 1 day).
static func haze_color(daylight: float) -> Color:
	return HAZE_NIGHT.lerp(HAZE_DAY, clampf(daylight, 0.0, 1.0))

## Phase 164 — the renderer's environment: a procedural sky whose horizon and ground are the haze,
## exponential fog over it with aerial perspective, and the ambient fill the sun scales.
static func make_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.ambient_light_energy = 0.5
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_aerial_perspective = HAZE_AERIAL
	apply_weather_fog(env, 1.0, 0.0)
	apply_sky_look(env, 1.0)
	return env

## Phase 164 — the sky and the haze for a `daylight` level, set together so they never disagree: the
## sky's horizon, ground horizon and ground bottom and the fog are one colour.
static func apply_sky_look(env: Environment, daylight: float) -> void:
	var haze := haze_color(daylight)
	env.fog_light_color = haze
	env.background_color = haze
	var mat := env.sky.sky_material as ProceduralSkyMaterial if env.sky != null else null
	if mat == null:
		return
	mat.sky_top_color = SKY_TOP_NIGHT.lerp(SKY_TOP_DAY, clampf(daylight, 0.0, 1.0))
	mat.sky_horizon_color = haze
	mat.ground_horizon_color = haze
	mat.ground_bottom_color = haze

## Phase 164 — the colour the sky shows at the horizon (null-safe: the background colour without a sky).
static func sky_horizon_color(env: Environment) -> Color:
	var mat := env.sky.sky_material as ProceduralSkyMaterial if env.sky != null else null
	return mat.sky_horizon_color if mat != null else env.background_color

## Phase 128 — the host's override table changed: a host sends it to every client, a client adopts it.
func _on_weather_overrides_synced(overrides: Array) -> void:
	if root._is_client:
		root._weather.apply_view(overrides)
	elif root._networking != null and root._networking.is_host():
		root._networking.broadcast_weather_overrides(overrides)

func _on_world_clock_received(host_days: float) -> void:
	if not root._is_client:
		return
	root.clock_ticks_received += 1
	root._clock.apply_host_time(host_days)

## The sun follows the clock: elevation from latitude, declination and the hour of day; azimuth
## swings east to west with the hour angle. It dims and warms toward the horizon and the sky
## and ambient light fall with it at night. `night_speed` is the `dayNightSpeed` of the biome the
## player stands in (1 follows the clock, 0 stays at dusk — see `WorldClock.biome_daylight`).
func apply_sun(lat: float, night_speed: float = 1.0) -> void:
	var sun := root.get_node_or_null("Sun") as DirectionalLight3D
	if sun == null:
		return
	var elev: float = root._clock.sun_elevation_at(lat)
	var daylight: float = WorldClock.biome_daylight(WorldClock.daylight_level(elev), night_speed)
	var hour: float = WorldClock.hour_angle_deg(WorldClock.day_phase(root._clock.time_days))
	sun.rotation_degrees = Vector3(-clampf(elev, 2.0, 90.0), 90.0 + hour + (180.0 if root._sun_turned else 0.0), 0.0)
	sun.light_energy = 1.4 * daylight
	sun.visible = elev > -6.0
	var low: float = clampf(1.0 - elev / 40.0, 0.0, 1.0)
	sun.light_color = Color(1.0, 0.95, 0.85).lerp(Color(1.0, 0.6, 0.35), low * low)
	var env_node := root.get_node_or_null("Environment") as WorldEnvironment
	if env_node != null and env_node.environment != null:
		apply_sky_look(env_node.environment, daylight)
		env_node.environment.ambient_light_energy = lerpf(0.08, 0.5, daylight)

## `dayNightSpeed` of the biome under `ppos` (1.0 when it declares none, or the biome is unknown).
func _night_speed_at(ppos: Vector3) -> float:
	if root._terrain == null:
		return 1.0
	var chunk := Vector2i(floori(ppos.x / TerrainSlice.CHUNK_METERS), floori(ppos.z / TerrainSlice.CHUNK_METERS))
	var biome: Variant = GameData.BIOMES.get(root._terrain.get_biome_at_chunk(chunk), null)
	if biome == null or biome.get("dayNightSpeed") == null:
		return 1.0
	return float(biome.get("dayNightSpeed"))

## Season look: every biome gets its own tint for the season at this latitude (snow-white where
## that biome's seasonal temperature is below freezing), and each chunk wears its own biome's
## tint — a freezing biome whitens its own chunks and not its temperate neighbours.
func _apply_season_look(lat: float) -> void:
	var w: float = root._clock.warmth_at(lat)
	if is_equal_approx(w, root._season_warmth):
		return   # the tints are a pure function of warmth: nothing to recompute or re-apply
	root._season_warmth = w
	var tints: Dictionary = {}
	for key in GameData.BIOMES:
		tints[key] = WorldClock.season_look(GameData.BIOMES[key], w)
	root._voxel.set_season_tints(tints)
