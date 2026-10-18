class_name DeathPush
extends RefCounted
## Phase 157 — the throw a killing blow gives the body, and which death clip it plays.
##
## Pure and static: the host feeds in positions, the hit's damage and a walkable probe, and gets a
## landing spot back. The landing is decided on the host only and travels as a creature's
## authoritative position (or in `creature_died` / `player_died`); a client never reports one.

## Throw distance bounds in metres, and the step the path is probed at.
const MIN_PUSH_M := 0.5
const MAX_PUSH_M := 1.5
const PROBE_STEP_M := 0.1
## Attacker/target size ratio bounds, so a huge hit-and-run does not fling a body across the map.
const MIN_SIZE_RATIO := 0.5
const MAX_SIZE_RATIO := 2.0
## Dot-product cut between "from behind / in front" and "from the side".
const AXIS_DOT := 0.5

const DEATH_DEFAULT := "death"
const DEATH_BACK := "death_back"
const DEATH_FORWARD := "death_forward"
const DEATH_SIDE := "death_side"


## Metres thrown: a light hit gives MIN_PUSH_M, a hit that takes all of `max_hp` gives MAX_PUSH_M, and
## a bigger attacker (`size_ratio` above 1) throws further. Always within [MIN_PUSH_M, MAX_PUSH_M].
static func distance(damage: float, max_hp: float, size_ratio: float = 1.0) -> float:
	var share := clampf(damage / maxf(max_hp, 0.001), 0.0, 1.0)
	var base := MIN_PUSH_M + (MAX_PUSH_M - MIN_PUSH_M) * share
	return clampf(base * clampf(size_ratio, MIN_SIZE_RATIO, MAX_SIZE_RATIO), MIN_PUSH_M, MAX_PUSH_M)


## Where a body at `pos` lands when `killer_pos` kills it: pushed along the flat line away from the
## killer, stopping at the last walkable probe (a wall stops it short; a first probe that is already
## blocked leaves the body where it stood). A killer on top of the body pushes nothing.
static func landing(pos: Vector3, killer_pos: Vector3, damage: float, max_hp: float, size_ratio: float, walkable: Callable) -> Vector3:
	var dir := Vector3(pos.x - killer_pos.x, 0.0, pos.z - killer_pos.z)
	if dir.length_squared() < 0.000001:
		return pos
	dir = dir.normalized()
	var reach := distance(damage, max_hp, size_ratio)
	var best := pos
	var d := PROBE_STEP_M
	while d <= reach + 0.0001:
		var spot := pos + dir * minf(d, reach)
		if walkable.is_valid() and not bool(walkable.call(spot)):
			break
		best = spot
		d += PROBE_STEP_M
	return best


## The death clip for a body facing `facing_yaw` (radians about +Y, a -Z-forward model) hit along the
## flat direction `hit_dir` (killer to body): struck from behind it falls on its face, from the front it
## is thrown backwards, from the side it falls sideways. No direction (a zero vector) is plain `death`.
static func variant(hit_dir: Vector3, facing_yaw: float) -> String:
	var flat := Vector3(hit_dir.x, 0.0, hit_dir.z)
	if flat.length_squared() < 0.000001:
		return DEATH_DEFAULT
	var forward := Basis(Vector3.UP, facing_yaw) * Vector3(0.0, 0.0, -1.0)
	var dot := flat.normalized().dot(forward)
	if dot > AXIS_DOT:
		return DEATH_FORWARD
	if dot < -AXIS_DOT:
		return DEATH_BACK
	return DEATH_SIDE


## Height above the straight line from start to landing at fraction `t` (0..1) of the fall, a short arc.
static func arc_height(t: float, peak_m: float = 0.25) -> float:
	var u := clampf(t, 0.0, 1.0)
	return 4.0 * peak_m * u * (1.0 - u)
