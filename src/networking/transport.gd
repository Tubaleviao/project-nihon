extends RefCounted
## Phase 119 — the wire as the networking slice sees it: who is connected, how to send one packet to
## one peer. `EnetTransport` carries it over the engine's multiplayer peer in the game;
## `MemoryTransport` records it in the suite. The slice owns sequencing, rate limits and routing; a
## transport only moves a finished packet dictionary.

## Ids of the peers a host would fan out to.
func peers() -> Array:
	return []

## Phase 195 — `peers()` as a set (peer id -> true), cached and read-only (#444, #531): the AOI fan-out asks for it
## once per relayed packet, and building it per call was a dictionary per creature delta. A transport whose peer list
## changes only through events (`watches_peers`) reuses the set until `invalidate_peer_set`; any other compares
## `peers()` with the list the set was built from, so a list edited in place is still seen as changed. The returned
## dictionary is shared and locked: copy it to edit.
func peer_set() -> Dictionary:
	if watches_peers() and not _set_stale:
		return _set
	var now := peers()
	if _set_stale or now != _set_of:
		_set_of = now.duplicate()
		_set = {}
		_set_stale = false
		for p in now:
			_set[int(p)] = true
		_set.make_read_only()
		_set_rebuilt()
	return _set

## True when the transport calls `invalidate_peer_set` on every change to `peers()` (so `peer_set` need not ask).
func watches_peers() -> bool:
	return false

func invalidate_peer_set() -> void:
	_set_stale = true

## Called after each rebuild of the set (a hook for a test spy; the production base keeps no counters).
func _set_rebuilt() -> void:
	pass

var _set_of: Array = []
var _set: Dictionary = {}
var _set_stale := true

## True while the wire is up (a connected peer, or an in-memory stand-in).
func is_up() -> bool:
	return false

## Deliver `msg` to `peer`.
func send(_peer: int, _msg: Dictionary) -> void:
	pass

## True when the slice should stamp a per-type `seq` on packets and route them through the emulator
## before sending (a real wire reorders and drops; an in-memory one does not). The one flag that tells the
## two kinds of transport apart; the engine polls ENet itself, so there is no poll hook.
var stamps_seq := true
