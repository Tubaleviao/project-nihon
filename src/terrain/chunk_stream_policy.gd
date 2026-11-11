extends RefCounted
## Phase 239 — the pure streaming policy: worker cap and lead by speed.

const DEFAULT_PREFETCH_DISTANCE := 1

## Phase 239 — adaptive workers. The steady in-flight cap starts at half the cores (at least 2) and moves
## inside [WORKER_MIN, cores − 1]: up one step while the queue is long or the ground under the body is
## missing, down one step after WORKER_IDLE_MSEC with an empty queue. Fewer busy cores at rest keeps the fans down.
const WORKER_MIN := 2
const WORKER_IDLE_MSEC := 4000
const WORKER_QUEUE_PER_WORKER := 2

## The cap a fresh manager starts at: half the cores, at least WORKER_MIN, never over the ceiling.
static func starting_builds(cores: int) -> int:
	return clampi(cores / 2, WORKER_MIN, worker_ceiling(cores))

## The most workers the cap may reach: every core but one, never under WORKER_MIN. Pure.
static func worker_ceiling(cores: int) -> int:
	return maxi(WORKER_MIN, cores - 1)

## The next steady cap (pure). Rises by one while `queue_len` exceeds WORKER_QUEUE_PER_WORKER per worker or
## `ground_missing`; falls by one once `idle_msec` (time with an empty queue) reaches WORKER_IDLE_MSEC; always
## inside [WORKER_MIN, worker_ceiling(cores)].
static func next_worker_cap(current: int, cores: int, queue_len: int, ground_missing: bool, idle_msec: int) -> int:
	var hi := worker_ceiling(cores)
	var cap := clampi(current, WORKER_MIN, hi)
	if ground_missing or queue_len > cap * WORKER_QUEUE_PER_WORKER:
		cap += 1
	elif queue_len == 0 and idle_msec >= WORKER_IDLE_MSEC:
		cap -= 1
	return clampi(cap, WORKER_MIN, hi)

## Phase 239 — lead by speed. A standing body keeps today's window (DEFAULT_PREFETCH_DISTANCE); a moving one
## prefetches `ceil(speed × LEAD_SECONDS / 32 m)` chunks, capped at LEAD_MAX, but only inside the cone along its
## velocity (`in_lead_cone`). Pure.
const LEAD_SECONDS := 1.5
const LEAD_MAX := 6
const LEAD_CONE_COS := 0.7071   # 45° either side of the heading

static func lead_prefetch(speed_mps: float) -> int:
	if speed_mps <= 0.0:
		return DEFAULT_PREFETCH_DISTANCE
	var chunks := int(ceil(speed_mps * LEAD_SECONDS / 32.0))
	return clampi(chunks, DEFAULT_PREFETCH_DISTANCE, LEAD_MAX)

## True when `rel` (a chunk offset from the body) lies in the cone around `heading` (a unit vector in chunks;
## zero means no cone). The offset itself (zero) counts as inside. Pure.
static func in_lead_cone(rel: Vector2i, heading: Vector2) -> bool:
	if heading == Vector2.ZERO:
		return false
	if rel == Vector2i.ZERO:
		return true
	return Vector2(rel).normalized().dot(heading) >= LEAD_CONE_COS

## The extra chunks (beyond `base_radius`, up to base_radius + lead − DEFAULT_PREFETCH_DISTANCE) that a body at
## `center` moving at `velocity` (m/s, x/z) prefetches. Empty when standing or slower than the standing lead. Pure.
static func lead_chunks(center: Vector2i, velocity: Vector2, base_radius: int) -> Array:
	var speed := velocity.length()
	var extra := lead_prefetch(speed) - DEFAULT_PREFETCH_DISTANCE
	var out: Array = []
	if extra <= 0:
		return out
	var heading := velocity / speed
	var r := base_radius + extra
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			if maxi(absi(dx), absi(dz)) <= base_radius:
				continue
			if in_lead_cone(Vector2i(dx, dz), heading):
				out.append(center + Vector2i(dx, dz))
	return out

