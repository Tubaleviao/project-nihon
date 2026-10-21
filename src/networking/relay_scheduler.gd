class_name RelayScheduler
extends RefCounted
## Phase 163 — decides when the host relays one player's position to one neighbour.
##
## A neighbour close by gets every report; one further out gets fewer, down to once per `FAR_MS`;
## a position the neighbour already holds is not sent again until `HEARTBEAT_MS` has passed. A report
## held back stays pending and is released once its interval is over, so a player who stops still
## ends up at its last position on every neighbour. Pure: the caller passes the clock.

const NEAR_M := 24.0
const MID_M := 56.0
const NEAR_MS := 0.0
const MID_MS := 200.0
const FAR_MS := 400.0
## A neighbour is told a still player's position at least this often, so it can tell "stopped" from "lost".
const HEARTBEAT_MS := 1000.0

## recipient -> { subject -> { "at": last sent ms, "sent": last sent pk, "pend": pending pk, "due": ms } }
var _pairs: Dictionary = {}
var offered := 0
var sent := 0

static func interval_ms(distance: float) -> float:
	if distance <= NEAR_M:
		return NEAR_MS
	if distance <= MID_M:
		return MID_MS
	return FAR_MS

## A new report of `subject` at `pk`, `distance` metres from `recipient`. True when it should go out now.
func offer(recipient: int, subject: int, pk: String, distance: float, now_ms: float) -> bool:
	offered += 1
	var row: Dictionary = _pairs.get(recipient, {})
	_pairs[recipient] = row
	var e: Dictionary = row.get(subject, {})
	if e.is_empty():
		row[subject] = { "at": now_ms, "sent": pk, "pend": "", "due": now_ms }
		sent += 1
		return true
	var age: float = now_ms - float(e["at"])
	if pk == e["sent"] and age < HEARTBEAT_MS:
		e["pend"] = ""
		return false
	var wait := interval_ms(distance)
	if age >= wait:
		e["at"] = now_ms
		e["sent"] = pk
		e["pend"] = ""
		sent += 1
		return true
	e["pend"] = pk
	e["due"] = float(e["at"]) + wait
	return false

## Held-back reports whose interval is over, as `[recipient, subject, pk]`. They count as sent.
func release_due(now_ms: float) -> Array:
	var out: Array = []
	for recipient in _pairs:
		for subject in _pairs[recipient]:
			var e: Dictionary = _pairs[recipient][subject]
			if e["pend"] != "" and now_ms >= float(e["due"]):
				e["at"] = now_ms
				e["sent"] = e["pend"]
				e["pend"] = ""
				sent += 1
				out.append([recipient, subject, e["sent"]])
	return out

## A peer left: drop it as a recipient and as a subject.
func forget(peer_id: int) -> void:
	_pairs.erase(peer_id)
	for recipient in _pairs:
		_pairs[recipient].erase(peer_id)

func pair_count() -> int:
	var n := 0
	for recipient in _pairs:
		n += _pairs[recipient].size()
	return n
