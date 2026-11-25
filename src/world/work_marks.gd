extends RefCounted
## #629 — the in-world marks of timed work (Phase 259): a crack overlay on the block being worked and a shake on the
## tree being chopped, seen by every player in range, not only the worker.
##
## The host records a mark when its `WorkHost` starts a session and drops it when the session ends (completion,
## release, retarget, a hit). It sends `{ key, duration }` to the peers in range of the worker; a duration of 0 is a
## stop. A mark is named by the work target's own key (`tree:<tree id>` or `block:<tx>,<tz>,<bottom>`, see
## `WorkHost.tree_key` and `VoxelEdit.work_target`), so a viewer finds the tree or block itself and the wire carries
## no position. This file is the pure half: the key and duration rules (a packet from the host is still validated)
## and the store each viewer keeps. `work_marks_view.gd` draws it.

## The longest key the wire may carry; a longer one is dropped.
const MAX_KEY_LEN := 64
## The most marks a viewer keeps (oldest dropped first): bounded however many workers are in range.
const MAX_MARKS := 64
## The longest work a mark may claim, in seconds; a longer one is refused as malformed.
const MAX_DURATION := 120.0
## A mark nobody stopped is dropped this long after its work would have ended (a lost stop packet never leaves a
## crack forever).
const GRACE_SECONDS := 1.5
## How many crack stages the overlay draws over a job.
const CRACK_STAGES := 4
## The tree shake: peak tilt and how many sways a second.
const SHAKE_DEGREES := 2.0
const SHAKE_HZ := 5.0

## `{ key: { started, duration } }`, in insertion order (the oldest first).
var _marks: Dictionary = {}

## A target key → `{ kind: "tree", tree_id }` or `{ kind: "block", tile: Vector2i, bottom: float }`; `{}` for anything
## malformed (another type, too long, another prefix, a tile or height that does not parse or is not finite).
static func parse_key(key: Variant) -> Dictionary:
	if not key is String:
		return {}
	var k: String = key
	if k.length() > MAX_KEY_LEN:
		return {}
	if k.begins_with("tree:"):
		var tid := k.substr(5)
		if tid.is_empty() or tid.contains(":"):
			return {}
		return { "kind": "tree", "tree_id": tid }
	if k.begins_with("block:"):
		var parts := k.substr(6).split(",")
		if parts.size() != 3 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_float():
			return {}
		var bottom := parts[2].to_float()
		if not is_finite(bottom):
			return {}
		return { "kind": "block", "tile": Vector2i(parts[0].to_int(), parts[1].to_int()), "bottom": bottom }
	return {}

## A duration off the wire: the seconds of a start (0 < d <= MAX_DURATION), 0.0 for a stop, -1.0 when malformed.
static func parse_duration(d: Variant) -> float:
	if not (d is float or d is int):
		return -1.0
	var v := float(d)
	if not is_finite(v) or v < 0.0 or v > MAX_DURATION:
		return -1.0
	return v

## The crack stage of a job `progress` (0..1) through: 0 before it starts, then 1..CRACK_STAGES.
static func crack_stage(progress: float) -> int:
	if progress <= 0.0:
		return 0
	return clampi(ceili(progress * CRACK_STAGES), 1, CRACK_STAGES)

## The tree's tilt (radians) `elapsed` seconds into a chop: a sway that grows a little as the job goes on.
static func shake_angle(elapsed: float, progress: float) -> float:
	if elapsed <= 0.0:
		return 0.0
	return deg_to_rad(SHAKE_DEGREES) * (0.5 + 0.5 * clampf(progress, 0.0, 1.0)) * sin(elapsed * TAU * SHAKE_HZ)

## The centre of the top face of a worked cell, in the voxel world frame.
static func block_top(tile: Vector2i, bottom: float, tile_size: float, step_height: float) -> Vector3:
	return Vector3((float(tile.x) + 0.5) * tile_size, bottom + step_height, (float(tile.y) + 0.5) * tile_size)

## Apply a host message: a start records (or restarts) the mark, a stop drops it. Returns false (and changes
## nothing) for a malformed key or duration.
func apply(key: Variant, duration: Variant, now: float) -> bool:
	if parse_key(key).is_empty():
		return false
	var d := parse_duration(duration)
	if d < 0.0:
		return false
	if d == 0.0:
		_marks.erase(key)
		return true
	_marks.erase(key)   # a restart moves the mark to the newest end
	while _marks.size() >= MAX_MARKS:
		_marks.erase(_marks.keys()[0])
	_marks[key] = { "started": now, "duration": d }
	return true

func has(key: String) -> bool:
	return _marks.has(key)

func keys() -> Array:
	return _marks.keys()

func size() -> int:
	return _marks.size()

## How far `key`'s job is (0..1; 0 for no mark).
func progress(key: String, now: float) -> float:
	var m: Dictionary = _marks.get(key, {})
	if m.is_empty():
		return 0.0
	return clampf((now - float(m["started"])) / float(m["duration"]), 0.0, 1.0)

## Seconds since `key`'s job started (0 for no mark).
func elapsed(key: String, now: float) -> float:
	var m: Dictionary = _marks.get(key, {})
	return maxf(0.0, now - float(m["started"])) if not m.is_empty() else 0.0

## Drop every mark past its work plus GRACE_SECONDS. Returns the keys dropped.
func expire(now: float) -> Array:
	var gone: Array = []
	for k in _marks.keys():
		var m: Dictionary = _marks[k]
		if now > float(m["started"]) + float(m["duration"]) + GRACE_SECONDS:
			gone.append(k)
	for k in gone:
		_marks.erase(k)
	return gone

func clear() -> void:
	_marks.clear()
