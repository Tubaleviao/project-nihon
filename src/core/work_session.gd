extends RefCounted
## Phase 259 — the host's record of timed work in progress, one session per worker. The host records the start
## time and the duration it computed itself (`WorkTime.seconds`); a client never supplies either. A completion
## is accepted only once the duration has passed, on the same target, with the input still held and the target
## in reach. A cancel (release, retarget, leaving reach, a hit) is accepted at any time and costs nothing: no
## durability is spent until the completion runs the existing `mine_block` / `chop_tree`.

## `{ player_id: { target: String, action: String, started: float, duration: float } }`
var _sessions: Dictionary = {}

## Begins work for `player_id` on `target`. A session on another target is dropped (retarget cancels). A
## repeated start on the same target keeps the original start time, so re-sending a start never shortens it.
## `duration` <= 0 is refused (an unknown material has no time).
func start(player_id: String, target: String, action: String, duration: float, now: float) -> bool:
	if player_id == "" or target == "" or duration <= 0.0:
		return false
	var cur: Dictionary = _sessions.get(player_id, {})
	if not cur.is_empty() and cur["target"] == target and cur["action"] == action:
		return true
	_sessions[player_id] = { "target": target, "action": action, "started": now, "duration": duration }
	return true

func has_session(player_id: String) -> bool:
	return _sessions.has(player_id)

func session(player_id: String) -> Dictionary:
	return (_sessions.get(player_id, {}) as Dictionary).duplicate()

## Progress 0..1 of a session (0 when none).
func progress(player_id: String, now: float) -> float:
	var s: Dictionary = _sessions.get(player_id, {})
	if s.is_empty():
		return 0.0
	return clampf((now - float(s["started"])) / float(s["duration"]), 0.0, 1.0)

## Cancels a session; always accepted. Returns whether one existed.
func cancel(player_id: String) -> bool:
	return _sessions.erase(player_id)

## Asks to complete. True (and the session ends) only when the target matches, the duration has passed, the
## input is still held and the target is in reach; an early claim leaves the session running, a claim made
## while released or out of reach cancels it.
func try_complete(player_id: String, target: String, now: float, held: bool, in_reach: bool) -> bool:
	var s: Dictionary = _sessions.get(player_id, {})
	if s.is_empty() or s["target"] != target:
		return false
	if not held or not in_reach:
		_sessions.erase(player_id)
		return false
	if now < float(s["started"]) + float(s["duration"]):
		return false
	_sessions.erase(player_id)
	return true
