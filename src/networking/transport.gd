extends RefCounted
## Phase 119 — the wire as the networking slice sees it: who is connected, how to send one packet to
## one peer, and a poll hook. `EnetTransport` carries it over the engine's multiplayer peer in the game;
## `MemoryTransport` records it in the suite. The slice owns sequencing, rate limits and routing; a
## transport only moves a finished packet dictionary.

## Ids of the peers a host would fan out to.
func peers() -> Array:
	return []

## True while the wire is up (a connected peer, or an in-memory stand-in).
func is_up() -> bool:
	return false

## Deliver `msg` to `peer`.
func send(_peer: int, _msg: Dictionary) -> void:
	pass

## Pump inbound traffic. The engine polls ENet itself, so this is a no-op there.
func poll() -> void:
	pass

## True when the slice should stamp a per-type `seq` on packets before sending (a real wire reorders
## and drops; an in-memory one does not).
func stamps_seq() -> bool:
	return true
