extends RefCounted
## Spawn placement (Phase 53): where a new player lands. Pure and deterministic — every search is
## seeded by the player id, so the same player in the same world gets the same answer, and a test
## can replay it.
##
## `find_new` looks for habitable land far from every colonized region; `find_near` looks for safe
## ground within a radius of a friend. Both return a world Vector3 standing on the generated
## surface (`height_fn` is the terrain's sampled ground), or `null` when nothing qualifies.
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const WorldShape := preload("res://src/terrain/world_shape.gd")
const ColonizationMap := preload("res://src/world/colonization_map.gd")

const MAX_ATTEMPTS := 6000
## Metres above the sampled ground the body is placed, so it never starts inside the surface.
const GROUND_CLEARANCE := 1.0
## Dry land is at least this far above sea level.
const MIN_LAND_ALTITUDE := 0.5
## The ground must be this flat across the sampled neighbours (metres of rise within ±3 m).
const MAX_STEP := 2.5
## Biomes a friend spawn refuses even though a friend stands near them.
const UNSAFE_BIOMES := ["Ocean", "VoidRift"]
const FALLBACK_HABITABLE := ["TemperateForest", "TemperateGrassland", "Savanna", "Taiga", "Desert", "Tundra"]

## The fabric's spawn rule as one dictionary (defaults for a rig without generated resources).
static func rule() -> Dictionary:
	var out := {
		"habitable": FALLBACK_HABITABLE,
		"min_colonized_distance": 2000.0,
		"colonized_score": 1.0,
		"friend_radius": 200.0,
	}
	var ws: Variant = GameData.WORLD_SYSTEMS.get("WorldSystem", null)
	if ws != null:
		var b: Variant = ws.get("spawnHabitableBiomes")
		if b is Array and not (b as Array).is_empty():
			out["habitable"] = b
		var v: Variant = ws.get("spawnMinColonizedDistance")
		if v != null:
			out["min_colonized_distance"] = float(v)
		v = ws.get("colonizedScore")
		if v != null:
			out["colonized_score"] = float(v)
		v = ws.get("friendSpawnRadius")
		if v != null:
			out["friend_radius"] = float(v)
	return out

static func _rng(player_id: String, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s#%d" % [player_id, salt])
	return rng

## True when world (x, z) is dry land, flat enough to stand on, and in one of `biomes`.
static func is_standable(world_seed: int, x: float, z: float, biomes: Array, height_fn: Callable) -> bool:
	var w := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	if WorldShape.altitude(world_seed, x, z, w) < MIN_LAND_ALTITUDE:
		return false
	var chunk := Vector2i(floori(x / TerrainSlice.CHUNK_METERS), floori(z / TerrainSlice.CHUNK_METERS))
	if not biomes.has(TerrainSlice.biome_for_chunk(TerrainSlice.wrap_chunk(chunk), world_seed)):
		return false
	var h: float = height_fn.call(Vector2(x, z))
	if h < WorldShape.sea_level() + 1.0:
		return false
	for off in [Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
		if absf(float(height_fn.call(Vector2(x, z) + off)) - h) > MAX_STEP:
			return false
	return true

## A new player's spawn: habitable standable land at least `min_colonized_distance` from every
## colonized region. Searches the whole planet between the polar ice caps; `null` when
## `MAX_ATTEMPTS` candidates all fail (a fully colonized world).
static func find_new(world_seed: int, player_id: String, colonization: ColonizationMap, height_fn: Callable, now: float = 0.0) -> Variant:
	var r := rule()
	var w := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	var half_z := float(TerrainSlice.polar_chunks()) * TerrainSlice.CHUNK_METERS * 0.9
	var rng := _rng(player_id, 1)
	for _i in MAX_ATTEMPTS:
		var x := (rng.randf() - 0.5) * w
		var z := (rng.randf() * 2.0 - 1.0) * half_z
		if colonization != null and colonization.is_near_colonized(x, z, float(r["min_colonized_distance"]), float(r["colonized_score"]), now):
			continue
		if not is_standable(world_seed, x, z, r["habitable"], height_fn):
			continue
		return Vector3(x, float(height_fn.call(Vector2(x, z))) + GROUND_CLEARANCE, z)
	return null

## A friend-code spawn: safe ground within `radius` of `center` (world XZ). The ground must be
## dry and flat, and not Ocean or VoidRift; it need not be a habitable biome (a friend in the
## tundra is joined in the tundra). `null` when no candidate qualifies.
static func find_near(world_seed: int, player_id: String, center: Vector2, radius: float, height_fn: Callable) -> Variant:
	var safe: Array = []
	for b in TerrainSlice.BIOME_KEYS:
		if not UNSAFE_BIOMES.has(b) and b != "Beach":
			safe.append(b)
	var rng := _rng(player_id, 2)
	for _i in MAX_ATTEMPTS / 4:
		var d := sqrt(rng.randf()) * radius
		var a := rng.randf() * TAU
		var p := center + Vector2(cos(a), sin(a)) * d
		if not is_standable(world_seed, p.x, p.y, safe, height_fn):
			continue
		return Vector3(p.x, float(height_fn.call(p)) + GROUND_CLEARANCE, p.y)
	return null
