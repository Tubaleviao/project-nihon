extends RefCounted
## Phase 119 — the wire as the networking slice sees it: who is connected, how to send one packet to
## one peer. `EnetTransport` carries it over the engine's multiplayer peer in the game;
## `MemoryTransport` records it in the suite. The slice owns sequencing, rate limits and routing; a
## transport only moves a finished packet dictionary.

## Ids of the peers a host would fan out to.
func peers() -> Array:
	return []

## Phase 195 — `peers()` as a set (peer id -> true), rebuilt only when the peer list changed (#444): the
## AOI fan-out asks for it once per relayed packet, and building it per call was a dictionary per creature
## delta. The list is compared to a copy, so a list edited in place is still seen as changed.
func peer_set() -> Dictionary:
	var now := peers()
	if now != _set_of:
		_set_of = now.duplicate()
		_set = {}
		peer_set_builds += 1
		for p in now:
			_set[int(p)] = true
	return _set

var _set_of: Array = []
var _set: Dictionary = {}
## Times `peer_set` rebuilt the set (the suite pins that an unchanged list reuses it).
var peer_set_builds := 0

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
