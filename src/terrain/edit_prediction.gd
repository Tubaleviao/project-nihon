extends RefCounted
## Phase 263 — a client's own dig or placement, predicted. The work timer (Phase 259) completes on the client
## when the host's does; the host's answer then takes a round trip, and the ground used to wait for it. Now the
## client applies the edit to its own copy of the voxel data at once (the same `_apply_edit` the host's
## `block_changed` runs, so both derive the same tile and span), remeshes it ahead of streaming (`EditRemesh`)
## and keeps it PENDING under a number the intent carries to the host:
##
## * the host's `block_changed` for it comes tagged with that number (`block_edit_acked(seq, true)` just before
##   it): the prediction stands, and that `block_changed` is not applied a second time (`consume_confirmed`);
## * a refusal (`block_edit_acked(seq, false)`), or no answer within `TIMEOUT_MSEC`, rolls it back: the touched
##   tiles' op logs, the vein depletion and the partial-chunk marks return to what they were, byte for byte,
##   the chunk is remeshed the same way, and the player is told (a keyed system line). Every LATER prediction is
##   rolled back with it, newest first, because each was made on top of the ones before; an answer that still
##   arrives for one of them is then applied as an ordinary host edit.
##
## Inventory and durability are never touched here: the item appears when the host says so.

const TIMEOUT_MSEC := 5000
const MAX_PENDING := 64
const MAX_SAMPLES := 64

var s: Node   # the VoxelSlice
## `{ seq, action, accepted, network_ms }` per answered prediction (the round trip to the host's answer), oldest first.
var samples: Array = []
## Clocks; a test may stub them.
var clock_msec: Callable = func() -> int: return Time.get_ticks_msec()
var clock_usec: Callable = func() -> int: return Time.get_ticks_usec()

var _next_seq := 0
var _pending: Dictionary = {}   # seq -> { action, tile, snap, veins, partial, sent_usec, deadline }
var _confirmed: Array = []   # [action, tile] of confirmed predictions whose block_changed is still to come

func _init(slice: Node) -> void:
	s = slice

func pending_count() -> int:
	return _pending.size()

func is_pending(seq: int) -> bool:
	return _pending.has(seq)

## Apply `action` ("mine" or "place") at the aimed point to this client's voxel data and return its number, or 0
## when there is nothing to predict (no span to mine, a full cell, no material): the intent still goes to the host.
func predict(action: String, position: Vector3, normal: Vector3, material: String) -> int:
	if s.is_authoritative or _pending.size() >= MAX_PENDING:
		return 0
	var tile: Vector2i = s._resolve_edit_tile(action, position, normal)["tile"]
	var runs: Array = s.get_runs_at_tile(tile)
	var keys: Array = [s._tile_key(tile)]
	if action == "mine":
		var span: Dictionary = s._mine_span(runs, position, normal)
		if span.is_empty():
			return 0
		if str(span["material"]) == "":
			var vein: Dictionary = s._natural_yield(tile, span)["vein"]
			if not vein.is_empty() and not keys.has(s._tile_key(vein["anchor"])):
				keys.append(s._tile_key(vein["anchor"]))   # the depletion op rides the vein's anchor tile
	elif action == "place":
		if material == "" or not GameData.MATERIALS.has(material) or s._place_span(runs, position, normal).is_empty():
			return 0
	else:
		return 0
	var snap: Dictionary = {}
	for k in keys:
		snap[k] = (s._edits[k] as Array).duplicate(true) if s._edits.has(k) else null
	var entry := {
		"action": action, "tile": tile, "snap": snap,
		"veins": s._vein_taken.duplicate(), "partial": s._partial_chunks.duplicate(),
		"sent_usec": int(clock_usec.call()), "deadline": int(clock_msec.call()) + TIMEOUT_MSEC,
	}
	if not bool(s._apply_edit(action, position, normal, material).get("applied", false)):
		_restore(entry, false)
		return 0
	_next_seq += 1
	_pending[_next_seq] = entry
	return _next_seq

## The host's answer to prediction `seq` (`block_edit_acked`): kept, or rolled back as refused.
func on_acked(seq: int, accepted: bool) -> void:
	if not _pending.has(seq):
		return
	if not accepted:
		rollback(seq, "refused")
		return
	var e: Dictionary = _pending[seq]
	_pending.erase(seq)
	_note(seq, e, true)
	_confirmed.append([str(e["action"]), e["tile"]])
	while _confirmed.size() > MAX_PENDING:
		_confirmed.pop_front()

## True (and forgotten) when this `block_changed` is the host's copy of a prediction it just confirmed.
func consume_confirmed(action: String, position: Vector3, normal: Vector3) -> bool:
	if _confirmed.is_empty():
		return false
	var tile: Vector2i = s._resolve_edit_tile(action, position, normal)["tile"]
	for i in _confirmed.size():
		if str(_confirmed[i][0]) == action and _confirmed[i][1] == tile:
			_confirmed.remove_at(i)
			return true
	return false

## Per frame on a client: a prediction the host has not answered in `TIMEOUT_MSEC` is rolled back.
func tick() -> void:
	if _pending.is_empty():
		return
	var now := int(clock_msec.call())
	var seqs: Array = _pending.keys()
	seqs.sort()
	for seq in seqs:
		if now >= int(_pending[seq]["deadline"]):
			rollback(int(seq), "timeout")
			return

## Undo prediction `seq` and every later one, newest first, and tell the player (`reason`: refused | timeout).
func rollback(seq: int, reason: String) -> void:
	if not _pending.has(seq):
		return
	var action := str(_pending[seq]["action"])
	_note(seq, _pending[seq], false)
	var later: Array = _pending.keys().filter(func(q: int) -> bool: return q >= seq)
	later.sort()
	later.reverse()
	for q in later:
		_restore(_pending[q], true)
		_pending.erase(q)
	GameBus.block_edit_rolled_back.emit(action, reason)
	GameBus.system_message.emit("edit.rolled_back.%s" % reason, [], "")

func _restore(entry: Dictionary, remesh: bool) -> void:
	var snap: Dictionary = entry["snap"]
	for k in snap:
		var ops: Variant = snap[k]
		s._set_edit_ops(k, (ops as Array).duplicate(true) if ops != null else [])
	s._vein_taken = (entry["veins"] as Dictionary).duplicate()
	s._partial_chunks = (entry["partial"] as Dictionary).duplicate()
	if remesh:
		for k in snap:
			s._rebuild_chunk_at_tile(s._key_to_tile(k), true)

func _note(seq: int, entry: Dictionary, accepted: bool) -> void:
	samples.append({ "seq": seq, "action": str(entry["action"]), "accepted": accepted,
		"network_ms": float(int(clock_usec.call()) - int(entry["sent_usec"])) / 1000.0 })
	if samples.size() > MAX_SAMPLES:
		samples.pop_front()
