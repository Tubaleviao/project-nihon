extends RefCounted
## Creature body contact (Phase 192) — pure functions shared by the host AI and the client models.
##
## Creatures are records, not physics bodies, so nothing stopped two of them (or a creature and a
## player) from standing in the same spot. Each creature type has a footprint circle on the ground
## (fabric `bodyRadiusMetres`) and a give (fabric `squash`). The host's `CreatureAI` pushes overlapping
## footprints apart once per tick (`pair_push`, `push_out`); `CreatureVisuals` squashes a model along
## the contact (`contact`, `squash_basis`), driven by a spring so a bump wobbles and settles.

## Fallbacks for a type without the fabric fields.
const DEFAULT_RADIUS := 0.5
const DEFAULT_SQUASH := 0.2
## Widest footprint the fabric allows (`BODY_RADIUS_MAX` in fabric/world/creatures/shared.js): the
## neighbour query reach.
const MAX_RADIUS := 2.0
## A player's footprint (the collision capsule's radius, `PlayerSlice._build_body`).
const PLAYER_RADIUS := 0.25
## Two bodies further apart than this vertically (a flyer over a walker) do not touch.
const VERTICAL_REACH := 1.8
## Share of an overlap resolved per tick: under 1 so a crowd relaxes over a few frames instead of
## jittering, and a pack spawned on top of itself fans out instead of popping.
const RELAX := 0.5
## Most a body is shoved in one tick (metres), so a deep overlap does not read as a teleport.
const MAX_SHOVE := 0.25
## A model starts to give a little before the footprints meet, so resting contact shows.
const CONTACT_MARGIN := 1.1
## Squash spring: stiffness (1/s²) and damping (1/s). Under-damped, so a bump overshoots once.
const SPRING_K := 220.0
const SPRING_C := 14.0

## Footprint radius (metres) of a creature type.
static func radius_of(creature_id: String) -> float:
	var res: Resource = GameData.CREATURES.get(creature_id, null)
	var v: Variant = res.get("bodyRadiusMetres") if res != null else null
	return float(v) if v != null and float(v) > 0.0 else DEFAULT_RADIUS

## How far a creature type's model gives on contact (fraction of its length).
static func squash_of(creature_id: String) -> float:
	var res: Resource = GameData.CREATURES.get(creature_id, null)
	var v: Variant = res.get("squash") if res != null else null
	return clampf(float(v), 0.0, 0.5) if v != null else DEFAULT_SQUASH

## Unit horizontal direction from `b` to `a`. Coincident bodies get a direction from `seed`, so the
## pair splits the same way on every host.
static func _apart(a: Vector3, b: Vector3, seed: String) -> Vector3:
	var d := Vector3(a.x - b.x, 0.0, a.z - b.z)
	if d.length_squared() > 1e-8:
		return d.normalized()
	var ang := float(absi(hash(seed)) % 3600) / 3600.0 * TAU
	return Vector3(cos(ang), 0.0, sin(ang))

## Pure: the relative shove (applied +half to `a`, -half to `b`) that relaxes `RELAX` of one pair's
## overlap; zero when they do not touch. Coincident bodies split along a direction from `seed`.
static func pair_push(a: Vector3, ra: float, b: Vector3, rb: float, seed: String = "") -> Vector3:
	if absf(a.y - b.y) > VERTICAL_REACH:
		return Vector3.ZERO
	var reach := ra + rb
	var flat := Vector2(a.x - b.x, a.z - b.z)
	var dist := flat.length()
	if dist >= reach:
		return Vector3.ZERO
	return _apart(a, b, seed) * (reach - dist) * RELAX

## Pure: the shove that moves a creature at `pos` (radius `r`) out of an immovable body at `other`
## (radius `ro`, a player): the whole overlap, capped at `MAX_SHOVE`. Zero when they do not touch.
static func push_out(pos: Vector3, r: float, other: Vector3, ro: float, seed: String = "") -> Vector3:
	if absf(pos.y - other.y) > VERTICAL_REACH:
		return Vector3.ZERO
	var reach := r + ro
	var dist := Vector2(pos.x - other.x, pos.z - other.z).length()
	if dist >= reach:
		return Vector3.ZERO
	return (_apart(pos, other, seed) * (reach - dist)).limit_length(MAX_SHOVE)

## Pure: the strongest contact on a body at `pos` (radius `r`) from `others` ([[position, radius], ...]):
## { dir: unit horizontal vector from the body toward the contact, depth: 0..1 }. Depth 0 when nothing is
## within `CONTACT_MARGIN` of touching; 1 when the footprints overlap by half their combined radius.
static func contact(pos: Vector3, r: float, others: Array) -> Dictionary:
	var best := {"dir": Vector3.ZERO, "depth": 0.0}
	for o in others:
		var op: Vector3 = o[0]
		var reach := r + float(o[1])
		if absf(pos.y - op.y) > VERTICAL_REACH:
			continue
		var flat := Vector3(op.x - pos.x, 0.0, op.z - pos.z)
		var dist := flat.length()
		var depth := clampf((reach * CONTACT_MARGIN - dist) / (reach * 0.5), 0.0, 1.0)
		if depth > float(best["depth"]) and dist > 1e-4:
			best = {"dir": flat / dist, "depth": depth}
	return best

## Pure: one spring step toward `target`. `state` is [value, velocity]; returns the new pair.
static func spring_step(state: Vector2, target: float, delta: float) -> Vector2:
	var x := state.x
	var v := state.y
	# Sub-step so a long frame does not blow the under-damped spring up.
	var steps := maxi(1, ceili(delta / 0.01))
	var h := delta / float(steps)
	for _i in steps:
		v += (SPRING_K * (target - x) - SPRING_C * v) * h
		x += v * h
	return Vector2(clampf(x, -0.6, 0.6), v)

## Pure: the basis that squashes a model by `amount` (fraction, may be negative for the stretch of a
## rebound) along the horizontal unit `dir`, bulging the other two axes so the volume is kept. Identity
## for no squash or no direction.
static func squash_basis(dir: Vector3, amount: float) -> Basis:
	if absf(amount) < 1e-4 or dir.length_squared() < 1e-6:
		return Basis()
	var along := 1.0 - amount
	var across := 1.0 / sqrt(maxf(along, 0.05))
	var x := Vector3(dir.x, 0.0, dir.z).normalized()
	var frame := Basis(x, Vector3.UP, x.cross(Vector3.UP))
	return frame * Basis.from_scale(Vector3(along, across, across)) * frame.transposed()
