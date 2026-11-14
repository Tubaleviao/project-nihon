extends RefCounted
## Phase 261 — newcomer grounds: a few large, gentle areas on the open continent where new characters
## start, read from the fabric's `NewcomerGrounds` world system. The centres are a pure function of the
## world seed (and the seed's own terrain), so every peer and every run agrees; this file holds only pure
## functions, the spawn search that uses them lives in `spawn_finder.gd`.
##
## Cyclic preloads are avoided by passing the standable test in as a Callable
## (`SpawnFinder.is_standable` bound to the habitable biomes).
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const WorldShape := preload("res://src/terrain/world_shape.gd")

const MAX_ATTEMPTS := 4000
const FALLBACK := {
	"count": 4, "radiusMetres": 1000.0, "biomes": ["TemperateForest", "TemperateGrassland"],
	"allowedCreatures": ["ForestBoar"], "allowedAggression": ["passive", "neutral"], "maxCreatureTier": 1,
	"looseDensityInside": 0.35, "looseDensityOutside": 0.02, "looseRegrowSeconds": 180.0,
	"pickReachMetres": 3.0, "claimRadiusMetres": 24.0, "resourceRadiusMetres": 120.0, "spawnRadiusMetres": 300.0,
}

## seed -> Array of Vector2 centres (world X/Z). Filled by `centres`.
static var _cache: Dictionary = {}

## The table `rule()` read last, and the resource it was read from (rebuilt when GameData holds another one).
static var _rule: Dictionary = {}
static var _rule_from: Variant = null

## The fabric's table (defaults for a rig without generated resources). Read once per resource and shared: it is
## asked on every creature step and loose-item tile, so callers must not change the dictionary.
static func rule() -> Dictionary:
	var res: Resource = GameData.WORLD_SYSTEMS.get("NewcomerGrounds", null)
	if not _rule.is_empty() and _rule_from == res:
		return _rule
	var out: Dictionary = FALLBACK.duplicate(true)
	if res != null:
		for k in out.keys():
			var v: Variant = res.get(k)
			if v != null:
				out[k] = v
	_rule = out
	_rule_from = res
	return out

static func clear_cache() -> void:
	_cache.clear()
	_rule = {}
	_rule_from = null

static func _circumference() -> float:
	return float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS

## Horizontal distance on the wrapping planet: X wraps around the circumference.
static func wrapped_distance(a: Vector2, b: Vector2) -> float:
	var w := _circumference()
	var dx := absf(a.x - b.x)
	dx = minf(dx, w - dx) if w > 0.0 else dx
	return Vector2(dx, a.y - b.y).length()

## The grounds' centres for `world_seed`: `count` standable points at least four radii apart. `standable` is a
## Callable(x, z) -> bool (dry, flat, in the ground biomes). Cached per seed; empty when none can be found.
static func centres(world_seed: int, standable: Callable = Callable()) -> Array:
	if _cache.has(world_seed):
		return _cache[world_seed]
	if not standable.is_valid():
		return []
	var r := rule()
	var w := _circumference()
	var half_z := float(TerrainSlice.polar_chunks()) * TerrainSlice.CHUNK_METERS * 0.9
	var out: Array = []
	var radius := float(r["radiusMetres"])
	for i in int(r["count"]):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("newcomer_ground#%d#%d" % [world_seed, i])
		for _a in MAX_ATTEMPTS:
			var p := Vector2((rng.randf() - 0.5) * w, (rng.randf() * 2.0 - 1.0) * half_z)
			var apart := true
			for c in out:
				if wrapped_distance(p, c) < radius * 4.0:
					apart = false
					break
			if apart and standable.call(p.x, p.y):
				out.append(p)
				break
	_cache[world_seed] = out
	return out

## Index of the ground whose circle holds (x, z), or -1. Uses the cached centres (none cached: -1).
static func ground_at(world_seed: int, x: float, z: float) -> int:
	var cs: Array = _cache.get(world_seed, [])
	var radius := float(rule()["radiusMetres"])
	for i in cs.size():
		if wrapped_distance(Vector2(x, z), cs[i]) <= radius:
			return i
	return -1

const LEVELS := ["passive", "neutral", "aggressive", "territorial"]

## Whether `world_seed` has any grounds cached (false until `centres` ran for it).
static func cached(world_seed: int) -> bool:
	return _cache.has(world_seed)

static func has_grounds(world_seed: int) -> bool:
	return not (_cache.get(world_seed, []) as Array).is_empty()

static func inside(world_seed: int, x: float, z: float) -> bool:
	return ground_at(world_seed, x, z) >= 0

## True when (x, z) is within the protected claim radius of a ground's centre.
static func in_claim_zone(world_seed: int, x: float, z: float) -> bool:
	var cs: Array = _cache.get(world_seed, [])
	var claim := float(rule()["claimRadiusMetres"])
	for c in cs:
		if wrapped_distance(Vector2(x, z), c) <= claim:
			return true
	return false

## Whether creature `key` may spawn inside a ground (it is on the fabric's allowed list).
static func creature_allowed(key: String) -> bool:
	return (rule()["allowedCreatures"] as Array).has(key)

## Whether a creature of aggression `level` may wander into a ground; an aggressive one turns back at the edge.
static func aggression_allowed(level: String) -> bool:
	return (rule()["allowedAggression"] as Array).has(level)

## A spawn point for `player_id` inside one of the grounds, or null. The ground is picked by the player id;
## `standable` is as for `centres`, `height_fn` gives the ground height at a Vector2. `blocked` (optional,
## `(Vector2) -> bool`) refuses a point inside a structure's circle: the claim radius keeps only the centre free, so
## a point among buildings is skipped, and when every candidate is blocked the spawn falls back to the protected
## centre, which no structure may hold (a newcomer is never walled in).
static func spawn_for(world_seed: int, player_id: String, standable: Callable, height_fn: Callable, blocked: Callable = Callable()) -> Variant:
	var cs := centres(world_seed, standable)
	if cs.is_empty():
		return null
	var r := rule()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s#newcomer" % player_id)
	var centre: Vector2 = cs[posmod(hash(player_id), cs.size())]
	var spawn_r := float(r["spawnRadiusMetres"])
	var claim := float(r["claimRadiusMetres"])
	for _i in 600:
		var d := claim + 6.0 + sqrt(rng.randf()) * (spawn_r - claim - 6.0)
		var a := rng.randf() * TAU
		var p := centre + Vector2(cos(a), sin(a)) * d
		if standable.call(p.x, p.y) and not (blocked.is_valid() and bool(blocked.call(p))):
			return Vector3(p.x, float(height_fn.call(p)) + 1.0, p.y)
	if blocked.is_valid():
		for _i in 64:
			var p := centre + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * (claim - 2.0)
			if standable.call(p.x, p.y):
				return Vector3(p.x, float(height_fn.call(p)) + 1.0, p.y)
	return null
