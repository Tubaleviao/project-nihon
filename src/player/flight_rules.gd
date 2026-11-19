extends RefCounted
## Phase 237 — flight that handles like flight. Pure: no node, no physics frame.
##
## `step` eases a flying body's velocity toward what the keys ask for: W/S along the camera's forward
## vector (pitch included), A/D across it, Space/Ctrl up and down. Releasing the keys lets drag bleed
## the speed off instead of stopping the body at once.

## Rates (1/s) of the exponential ease: 95% of the way in 3 / rate seconds.
const ACCEL_RATE := 4.6   ## top speed in about 0.65 s
const DRAG_RATE := 3.0    ## a stop from top speed (below 5%) in about 1 s
## The camera trails the body by this many seconds of its horizontal velocity, at most LAG_MAX metres.
const CAMERA_LAG_SECS := 0.05
const CAMERA_LAG_MAX := 4.0
const CAMERA_LAG_RATE := 6.0
## The camera's FOV opens by up to this many degrees at top speed.
const FOV_BOOST_MAX := 12.0
const FOV_RATE := 4.0

## The default tuning for a body whose horizontal top speed is `top_speed` and vertical speed `vertical_speed` (m/s).
static func params(top_speed: float, vertical_speed: float) -> Dictionary:
	return { "top_speed": top_speed, "vertical_speed": vertical_speed, "accel": ACCEL_RATE, "drag": DRAG_RATE }

## The velocity after `delta` seconds. `wish`: x strafe (+ right), y vertical (+ up), z walk (-1 forward, +1
## back), each in -1..1 (the keys). `look_basis`: the camera's basis (forward is -Z, pitched).
static func step(velocity: Vector3, wish: Vector3, look_basis: Basis, delta: float, p: Dictionary) -> Vector3:
	var horizontal: Vector3 = look_basis.x * wish.x + look_basis.z * wish.z
	if horizontal.length_squared() > 1.0:
		horizontal = horizontal.normalized()
	var target: Vector3 = horizontal * float(p["top_speed"]) + Vector3.UP * clampf(wish.y, -1.0, 1.0) * float(p["vertical_speed"])
	var rate: float = float(p["accel"]) if wish != Vector3.ZERO else float(p["drag"])
	var keep := exp(-rate * maxf(delta, 0.0))
	return target + (velocity - target) * keep

## A collision kills only the velocity into the surface: `normal` is the surface's outward normal.
static func slide(velocity: Vector3, normal: Vector3) -> Vector3:
	var into := velocity.dot(normal)
	return velocity - normal * into if into < 0.0 else velocity

## The camera's horizontal lag offset (world axes) eased toward a trail behind `velocity`.
static func lag_target(velocity: Vector3) -> Vector3:
	var flat := Vector3(velocity.x, 0.0, velocity.z) * -CAMERA_LAG_SECS
	return flat.limit_length(CAMERA_LAG_MAX)

## The FOV widening in degrees for a body at `speed` of `top_speed`.
static func fov_boost(speed: float, top_speed: float) -> float:
	if top_speed <= 0.0:
		return 0.0
	return FOV_BOOST_MAX * clampf(speed / top_speed, 0.0, 1.0)

## Frame-rate independent ease of `current` toward `target`.
static func ease_to(current: float, target: float, rate: float, delta: float) -> float:
	return target + (current - target) * exp(-rate * maxf(delta, 0.0))

## Phase 237 — ease the flight camera: a horizontal trail on the arm and a widened FOV. `st` holds the eased
## `lag` and `boost`; `top` is 0 when not flying, which eases both back to nothing.
static func update_camera(camera: Camera3D, arm: Node3D, pivot: Node3D, st: Dictionary, velocity: Vector3, top: float, delta: float, base_fov: float) -> void:
	if camera == null or arm == null or pivot == null:
		return
	var lag: Vector3 = lag_target(velocity) if top > 0.0 else Vector3.ZERO
	st["lag"] = (st["lag"] as Vector3).lerp(lag, 1.0 - exp(-CAMERA_LAG_RATE * delta))
	st["boost"] = ease_to(float(st["boost"]), fov_boost(velocity.length(), top), FOV_RATE, delta)
	var local: Vector3 = pivot.global_transform.basis.inverse() * (st["lag"] as Vector3)
	arm.position.x = local.x
	arm.position.z = local.z
	camera.fov = base_fov + float(st["boost"])
