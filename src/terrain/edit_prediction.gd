extends RefCounted
## Phase 263 — a client's own dig or placement, predicted. The work timer (Phase 259) completes on the client
## when the host's does; the host's answer then takes a round trip, and the ground used to wait for it. Now the
## client applies the edit to its own copy of the voxel data at once (the same `_apply_edit` the host's
## `block_changed` runs, so both derive the same tile and span), remeshes it ahead of streaming (`EditRemesh`)
## and keeps it PENDING under a number the intent carries to the host.
##
## PR #648 review — the predictions sit on top of the host's state, never in place of it. The op log of every tile
## a pending prediction wrote is also kept as the host has it (`_auth`), and each prediction keeps what it needs
## to be made again (its aim). Whenever the host's state moves under them, the voxel data is REBUILT: the tracked
## tiles go back to the host's logs (and each touched vein's depletion is read back off its anchor's log, so a
## vein mined anywhere else keeps its depletion), the host's change goes on, and the predictions still pending
## are applied again, oldest first. Only the tiles whose logs really changed are remeshed. That covers:
##
## * a `block_changed` from the host (another player's edit, here or anywhere; `on_host_edit`): applied to the
##   host's state, under the predictions;
## * the host's `block_changed` for a prediction (`block_edit_acked(seq, true, span)` just before it): that edit
##   becomes host state and leaves the pending set. The host's own span rides the answer: when it differs from
##   the span this client derives on the host's state (the two copies disagree), the host's span is applied as
##   is (`resyncs`); when the prediction's own span differed (the host ordered another edit first), the tile is
##   remeshed from the host's state (`mismatches`);
## * a refusal (`block_edit_acked(seq, false)`), or no answer within `TIMEOUT_MSEC` (a packet the host's rate
##   limit dropped is never answered): that prediction alone is taken out, and the player is told (a keyed
##   system line). The later ones stay pending, made again on the host's state, because the host answers each
##   intent on its own; a confirmed later one is host state already and stays.
##
## A re-scope snapshot or `/regen world` replaces the edit log wholesale: every prediction is dropped (`clear`),
## and an answer that still arrives is applied as an ordinary host edit.
##
## A mine of a placed block is never predicted: the host decides whether a hit on it removes it (the owner
## taking it apart) or only damages it (someone else's), and the client cannot tell. Inventory and durability
## are never touched here: the item appears when the host says so.

const EditRemesh := preload("res://src/terrain/edit_remesh.gd")

const TIMEOUT_MSEC := 5000
const MAX_PENDING := 64
const MAX_SAMPLES := 64

var s: Node   # the VoxelSlice
## `{ seq, action, accepted, network_ms }` per answered prediction (the round trip to the host's answer), oldest first.
var samples: Array = []
## Confirmations whose predicted span was not the host's (remeshed from the host's state), and those whose host
## span this client could not derive on its own copy of the host's state (the host's span applied as is).
var mismatches := 0
var resyncs := 0
## Clocks; a test may stub them.
var clock_msec: Callable = func() -> int: return Time.get_ticks_msec()
var clock_usec: Callable = func() -> int: return Time.get_ticks_usec()

var _next_seq := 0
## seq -> { action, position, normal, material, tile, keys, vein, partial, span, sent_usec, deadline }
var _pending: Dictionary = {}
## tile key -> that tile's op log as the host has it, for every tile a pending prediction wrote.
var _auth: Dictionary = {}
## The confirmation whose `block_changed` comes next: `{ seq, span }`.
var _confirming: Dictionary = {}

func _init(slice: Node) -> void:
	s = slice

func pending_count() -> int:
	return _pending.size()

func is_pending(seq: int) -> bool:
	return _pending.has(seq)

## Apply `action` ("mine" or "place") at the aimed point to this client's voxel data and return its number, or 0
## when there is nothing to predict (no span to mine, a placed block, a full cell, no material): the intent still
## goes to the host.
func predict(action: String, position: Vector3, normal: Vector3, material: String) -> int:
	if s.is_authoritative or _pending.size() >= MAX_PENDING:
		return 0
	if action == "place" and (material == "" or not GameData.MATERIALS.has(material)):
		return 0
	if action != "mine" and action != "place":
		return 0
	var e := {
		"action": action, "position": position, "normal": normal, "material": material,
		"sent_usec": int(clock_usec.call()), "deadline": int(clock_msec.call()) + TIMEOUT_MSEC,
	}
	if not _apply(e, EditRemesh.PRIMARY):
		_untrack_unused()
		return 0
	_next_seq += 1
	_pending[_next_seq] = e
	return _next_seq

## The host's answer to prediction `seq` (`block_edit_acked`): kept, or taken out as refused. A kept one is
## settled by the `block_changed` that follows (`on_host_edit`), with the host's `span` (`{ tile, bottom, top }`).
func on_acked(seq: int, accepted: bool, span: Dictionary = {}) -> void:
	if not _pending.has(seq):
		return
	if not accepted:
		rollback(seq, "refused")
		return
	_note(seq, _pending[seq], true)
	_confirming = { "seq": seq, "span": span }

## A `block_changed` from the host while predictions are pending: applied to the host's state under them, the
## pending ones made again on top (see the header). False (nothing done) when nothing is pending: the caller
## applies it as usual.
func on_host_edit(action: String, position: Vector3, normal: Vector3, material: String) -> bool:
	var conf := _confirming
	_confirming = {}
	if _pending.is_empty():
		return false
	var own: Dictionary = _pending.get(int(conf.get("seq", 0)), {})
	var host_span: Dictionary = conf.get("span", {})
	var tile: Vector2i = s._resolve_edit_tile(action, position, normal)["tile"]
	var watch: Array = _auth.keys()
	for k in [s._tile_key(tile)] + ([s._tile_key(host_span["tile"])] if not host_span.is_empty() else []):
		if not watch.has(k):
			watch.append(k)
	var before := _logs(watch)
	var veins_before: Dictionary = s._vein_taken.duplicate()
	s._build.sink = {}
	_rewind()
	if not own.is_empty():
		_pending.erase(int(conf["seq"]))
	# The host's edit, on the host's state.
	var derived := _span_at(action, tile, position, normal)
	if not host_span.is_empty() and not _same_span(derived, host_span, tile):
		resyncs += 1
		_apply_host_span(action, host_span, derived, material)
	else:
		s._apply_edit(action, position, normal, material)
	if not own.is_empty() and not _same_span(own.get("span", {}), derived if host_span.is_empty() else host_span, tile):
		mismatches += 1
	var host_chunks: Dictionary = s._build.sink
	for k in _auth.keys():
		_auth[k] = _log(k)
	s._build.sink = {}
	_replay()
	s._build.sink = null
	_untrack_unused()
	var changed := _changed(before, _logs(watch))
	if not own.is_empty() and changed.is_empty() and s._vein_taken == veins_before:
		return true   # the host's edit is the prediction it confirmed: the ground already shows it
	var level := EditRemesh.PRIMARY if not own.is_empty() else EditRemesh.NEIGHBOUR
	var done: Dictionary = {}
	for k in changed:
		for c in s._touched_chunks(s._key_to_tile(k)):
			done[c] = true
		s._rebuild_chunk_at_tile(s._key_to_tile(k), level)
	for c in host_chunks:
		if not done.has(c):
			s._rebuild_chunk(c, mini(int(host_chunks[c]), EditRemesh.NEIGHBOUR))
	return true

## Per frame on a client: a prediction the host has not answered in `TIMEOUT_MSEC` is taken out.
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

## Take prediction `seq` out (the voxel data rebuilt from the host's state and the other pending ones) and tell
## the player (`reason`: refused | timeout).
func rollback(seq: int, reason: String) -> void:
	if not _pending.has(seq):
		return
	var action := str(_pending[seq]["action"])
	_note(seq, _pending[seq], false)
	var watch: Array = _auth.keys()
	var before := _logs(watch)
	s._build.sink = {}
	_rewind()
	_pending.erase(seq)
	_replay()
	s._build.sink = null
	_untrack_unused()
	for k in _changed(before, _logs(watch)):
		s._rebuild_chunk_at_tile(s._key_to_tile(k), EditRemesh.PRIMARY)
	GameBus.block_edit_rolled_back.emit(action, reason)
	GameBus.system_message.emit("edit.rolled_back.%s" % reason, [], "")

## Drop every prediction (the edit log was replaced: a re-scope snapshot, `/regen world`).
func clear() -> void:
	_pending.clear()
	_auth.clear()
	_confirming = {}

# --- the voxel data -----------------------------------------------------------

## Make prediction `e` on the voxel data as it is now (rebuilds at `level`, or into the sink while one is set).
## Its tiles are tracked first, so their host logs are known. False when there was nothing to apply.
func _apply(e: Dictionary, level: int) -> bool:
	var action := str(e["action"])
	var tile: Vector2i = s._resolve_edit_tile(action, e["position"], e["normal"])["tile"]
	var keys: Array = s._edit._edit_keys(action, tile, e["position"], e["normal"])
	e["tile"] = tile
	e["keys"] = keys
	e["span"] = {}
	e["vein"] = ""
	e["partial"] = []
	if keys.is_empty():
		return false
	for k in keys:
		if not _auth.has(k):
			_auth[k] = _log(k)
	var span := _span_at(action, tile, e["position"], e["normal"])
	if action == "mine" and str(span.get("material", "x")) == "":
		var vein: Dictionary = s._natural_yield(tile, span)["vein"]
		e["vein"] = str(vein.get("id", "")) if not vein.is_empty() else ""
	var marks: Dictionary = s._partial_chunks.duplicate()
	if not bool(s._apply_edit(action, e["position"], e["normal"], str(e["material"]), level).get("applied", false)):
		return false
	e["span"] = span
	e["partial"] = s._partial_chunks.keys().filter(func(c) -> bool: return not marks.has(c))
	return true

## Every tracked tile back to the host's log; the depletion of each vein a pending prediction mined read back off
## its anchor's log; the partial marks the predictions added dropped.
func _rewind() -> void:
	for k in _auth:
		s._set_edit_ops(k, (_auth[k] as Array).duplicate(true))
	for e in _pending.values():
		for c in e.get("partial", []):
			s._partial_chunks.erase(c)
		if str(e.get("vein", "")) == "":
			continue
		var id := str(e["vein"])
		var taken := 0
		for k in e["keys"]:
			for op in s._edits.get(k, []):
				if str(op.get("op", "")) == "deplete" and str(op.get("vein", "")) == id:
					taken = int(op.get("taken", 0))
		if taken > 0:
			s._vein_taken[id] = taken
		else:
			s._vein_taken.erase(id)

## The pending predictions again, oldest first, on the voxel data as it is now.
func _replay() -> void:
	var seqs: Array = _pending.keys()
	seqs.sort()
	for q in seqs:
		_apply(_pending[q], EditRemesh.PRIMARY)

## Forget the host logs no pending prediction needs.
func _untrack_unused() -> void:
	if _pending.is_empty():
		_auth.clear()
		return
	var used: Dictionary = {}
	for e in _pending.values():
		for k in e.get("keys", []):
			used[k] = true
	for k in _auth.keys():
		if not used.has(k):
			_auth.erase(k)

## The host's span applied as it is: the client's copy could not derive it (`derived` is what it did derive).
func _apply_host_span(action: String, hs: Dictionary, derived: Dictionary, material: String) -> void:
	var tile: Vector2i = hs["tile"]
	var span := { "bottom": float(hs["bottom"]), "top": float(hs["top"]), "material": str(derived.get("material", "")) }
	if action == "mine":
		var yielded: Dictionary = s._natural_yield(tile, span) if str(span["material"]) == "" else {}
		s._append_edit(tile, { "op": "remove", "bottom": span["bottom"], "top": span["top"] })
		if not yielded.is_empty() and not (yielded["vein"] as Dictionary).is_empty():
			s._record_depletion(yielded["vein"], int(yielded["quantity"]))
	else:
		s._append_edit(tile, { "op": "add", "bottom": span["bottom"], "top": span["top"], "material": material })
	s._rebuild_chunk_at_tile(tile, EditRemesh.NEIGHBOUR)

func _span_at(action: String, tile: Vector2i, position: Vector3, normal: Vector3) -> Dictionary:
	var runs: Array = s.get_runs_at_tile(tile)
	return s._mine_span(runs, position, normal) if action == "mine" else s._place_span(runs, position, normal)

static func _same_span(a: Dictionary, b: Dictionary, tile: Vector2i) -> bool:
	if a.is_empty() or b.is_empty():
		return a.is_empty() and b.is_empty()
	if b.has("tile") and b["tile"] != tile:
		return false
	return is_equal_approx(float(a["bottom"]), float(b["bottom"])) and is_equal_approx(float(a["top"]), float(b["top"]))

func _log(k: String) -> Array:
	return (s._edits[k] as Array).duplicate(true) if s._edits.has(k) else []

func _logs(keys: Array) -> Dictionary:
	var out: Dictionary = {}
	for k in keys:
		out[k] = _log(k)
	return out

static func _changed(before: Dictionary, after: Dictionary) -> Array:
	return before.keys().filter(func(k) -> bool: return before[k] != after[k])

func _note(seq: int, entry: Dictionary, accepted: bool) -> void:
	samples.append({ "seq": seq, "action": str(entry["action"]), "accepted": accepted,
		"network_ms": float(int(clock_usec.call()) - int(entry["sent_usec"])) / 1000.0 })
	if samples.size() > MAX_SAMPLES:
		samples.pop_front()
