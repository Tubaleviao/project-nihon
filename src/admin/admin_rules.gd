extends RefCounted
## Admin rules (Phase 182) — the pure half of the admin tools: what `/time`, `/speed` and `/fly`
## accept, and what flying does to the body. The chat slice runs the commands on the host; the player
## slice applies the moves it is sent. No state lives here.

## `/speed` bounds: a multiplier on walking (and flying) speed.
const SPEED_MIN := 0.1
const SPEED_MAX := 30.0
## Flying: horizontal speed is the walking speed times this (before `/speed`), and Space / Ctrl climb and
## sink at FLY_VERTICAL_SPEED (m/s, also scaled by `/speed`).
const FLY_SPEED_FACTOR := 2.0
const FLY_VERTICAL_SPEED := 6.0
## `/time +h` may skip at most this many in-game hours at once.
const TIME_SKIP_MAX_HOURS := 240

## `{ ok, days, error, args }` for a `/time` argument at clock time `now_days`: "hh:mm" (or "hh") moves
## to the next time the clock shows that hour (today when it is still ahead, else tomorrow), and "+h"
## skips h whole hours. The clock only runs forward, so growth, respawn and weather timers never rewind.
static func parse_time(arg: String, now_days: float) -> Dictionary:
	var s := arg.strip_edges()
	if s.begins_with("+"):
		var h := s.substr(1)
		if not h.is_valid_int() or h.to_int() < 1 or h.to_int() > TIME_SKIP_MAX_HOURS:
			return _fail("chat.time_bad_skip", [TIME_SKIP_MAX_HOURS])
		return { "ok": true, "days": now_days + float(h.to_int()) / 24.0, "error": "", "args": [] }
	var parts := s.split(":")
	if parts.size() > 2 or not parts[0].is_valid_int() or (parts.size() == 2 and not parts[1].is_valid_int()):
		return _fail("chat.time_bad", [])
	var hh := parts[0].to_int()
	var mm := parts[1].to_int() if parts.size() == 2 else 0
	if hh < 0 or hh > 23 or mm < 0 or mm > 59:
		return _fail("chat.time_bad", [])
	var want := (float(hh) * 60.0 + float(mm)) / 1440.0
	var day := floorf(now_days)
	var target := day + want
	if target <= now_days:
		target += 1.0
	return { "ok": true, "days": target, "error": "", "args": [] }

## The multiplier a `/speed` argument names, or -1.0 when it is not a number within the bounds.
static func parse_speed(arg: String) -> float:
	var s := arg.strip_edges()
	if not s.is_valid_float():
		return -1.0
	var f := s.to_float()
	if is_nan(f) or f < SPEED_MIN - 1e-9 or f > SPEED_MAX + 1e-9:
		return -1.0
	return clampf(f, SPEED_MIN, SPEED_MAX)

## A speed factor that arrived over the wire, made safe to apply.
static func sanitize_speed(f: float) -> float:
	if is_nan(f) or is_inf(f):
		return 1.0
	return clampf(f, SPEED_MIN, SPEED_MAX)

## The vertical velocity of a flying body: `up` / `down` held (both or neither: hover), times `/speed`.
static func fly_vertical_velocity(up: bool, down: bool, speed_factor: float) -> float:
	var dir := (1.0 if up else 0.0) - (1.0 if down else 0.0)
	return dir * FLY_VERTICAL_SPEED * speed_factor

static func _fail(key: String, args: Array) -> Dictionary:
	return { "ok": false, "days": 0.0, "error": key, "args": args }
