extends RefCounted
## Phase 163 — host: the position relays, batched per recipient and thinned by distance.
##
## The Phase 162 crowd report ranked `remote_player_state` first: every peer got one packet per neighbour
## per report, each with its own type name, seq and keys, and the mover got its own report echoed back.
## Now a report is only `offer`ed; every `FLUSH_MS` `build` turns the reports since into one flat list per
## recipient (`[subject, pk, subject, pk, …]`), sent as one `player_states` packet. A pair is relayed by
## `due`: a neighbour within `NEAR_RADIUS` gets every report, a farther one inside the AOI at most one per
## `FAR_GAP_MS`, and a position that did not change only as a `KEEPALIVE_MS` refresh. With the client's
## 0.5 s report interval every pair in the AOI still hears at least once a second.

const PACKET_TYPE := "player_states"
## Metres between recipient and subject inside which every report is relayed.
const NEAR_RADIUS := 24.0
## Least gap between two relays of a moving subject to a recipient beyond `NEAR_RADIUS`.
const FAR_GAP_MS := 750.0
## Longest gap between two relays of the same pair: an unchanged position is resent this often.
const KEEPALIVE_MS := 1000.0
## Least gap between two flushes (`NetworkingSlice.flush_relays`): a report waits at most this long, and
## a peer gets at most 10 relay packets a second however many neighbours report.
const FLUSH_MS := 100.0
## Most subjects in one packet (a client refuses more); a longer list goes out in several packets.
const BATCH_MAX := 256
## Longest compact position text a client accepts in a batch entry.
const PK_MAX := 64

## subject -> [pk, position]: the latest report of each subject since the last flush.
var _pending: Dictionary = {}
## When the last flush ran (ms; the slice's pacing reads it).
var flushed_ms := -INF
## recipient -> { subject -> [ms, pk] }: the last relay of each pair. Dropped with either peer.
var _last: Dictionary = {}
## Counters for the suite: AOI queries run and pair relays queued by `build`, since construction.
var scans := 0
var relays := 0

## True when a report of a subject `dist` metres from the recipient goes out: `changed` is false when the
## pair's last relay carried the same position, `since_ms` is the time since that relay (INF if none). Pure.
static func due(dist: float, changed: bool, since_ms: float) -> bool:
	if since_ms >= KEEPALIVE_MS:
		return true
	if not changed:
		return false
	return dist <= NEAR_RADIUS or since_ms >= FAR_GAP_MS

## Queue `subject`'s report for this frame's batch; a later report in the same frame replaces it.
func offer(subject: int, pk: String, position: Vector3) -> void:
	_pending[subject] = [pk, position]

func has_pending() -> bool:
	return not _pending.is_empty()

## Turn the frame's reports into recipient -> flat `[subject, pk, …]` and clear them (all but a change
## still owed to a far recipient, which waits for a later flush). `connected` is the
## set of live peers (id -> true), `recipients_of(position)` the peer ids whose AOI holds `position` (one
## spatial query per subject), `center_of(peer)` a recipient's AOI centre. A subject is never relayed to
## itself: its own client already knows where it is.
func build(now_ms: float, connected: Dictionary, recipients_of: Callable, center_of: Callable) -> Dictionary:
	var out := {}
	# A changed report held back from a far recipient (`FAR_GAP_MS`) stays queued until it is due: the
	# subject may not report again (a dead body stops ticking after its death push), and the far peer
	# would keep the stale position for good.
	var held := {}
	for subject: int in _pending:
		var entry: Array = _pending[subject]
		var pk: String = entry[0]
		var pos: Vector3 = entry[1]
		scans += 1
		for r in recipients_of.call(pos):
			var rid := int(r)
			if rid == subject or not connected.has(rid):
				continue
			var seen: Dictionary = _last.get(rid, {})
			var prev = seen.get(subject, null)
			var since := INF if prev == null else now_ms - float(prev[0])
			var changed := prev == null or str(prev[1]) != pk
			var dist: float = (center_of.call(rid) as Vector3).distance_to(pos)
			if not due(dist, changed, since):
				if changed:
					held[subject] = entry
				continue
			seen[subject] = [now_ms, pk]
			_last[rid] = seen
			if not out.has(rid):
				out[rid] = []
			(out[rid] as Array).append_array([subject, pk])
			relays += 1
	_pending = held
	return out

## Split one recipient's flat list into packets of at most `BATCH_MAX` subjects.
static func packets(flat: Array) -> Array:
	var out: Array = []
	var step := BATCH_MAX * 2
	for i in range(0, flat.size(), step):
		out.append({ "type": PACKET_TYPE, "s": flat.slice(i, i + step) })
	return out

## Client: the `[subject, pk]` pairs of a `player_states` packet, or [] when it is malformed (not a flat
## even list, too long, a subject that is not a positive whole number or a position text that is not a
## short string). One bad entry refuses the whole packet: the host never writes one.
static func decode(payload: Dictionary) -> Array:
	var s = payload.get("s", null)
	if not s is Array or (s as Array).size() % 2 != 0 or (s as Array).size() > BATCH_MAX * 2:
		return []
	var out: Array = []
	for i in range(0, (s as Array).size(), 2):
		var id = s[i]
		var pk = s[i + 1]
		if not (id is float or id is int) or float(id) != floorf(float(id)) or float(id) < 1.0 or float(id) > 2147483647.0:
			return []
		if not pk is String or (pk as String).length() > PK_MAX:
			return []
		out.append([int(id), pk])
	return out

## Forget a peer that left, as a recipient and as a subject.
func forget(peer: int) -> void:
	_pending.erase(peer)
	_last.erase(peer)
	for r in _last:
		(_last[r] as Dictionary).erase(peer)

## Pairs remembered (the stress run's orphan audit and the suite read it).
func pair_count() -> int:
	var n := 0
	for r in _last:
		n += (_last[r] as Dictionary).size()
	return n
