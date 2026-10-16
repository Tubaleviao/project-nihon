extends RefCounted
## Base for the per-system wiring modules (Phase 132).
##
## A module owns the `GameBus` handlers (and the glue they call) for one system. `wire(ctx)` connects
## them through `connect_bus`, which remembers every connection so `unwire()` disconnects exactly what
## `wire` connected. `root` is the GameRoot that owns the slices.

const GameRoot := preload("res://src/core/game_root.gd")

var root: GameRoot = null
var _connections: Array = []

func wire(ctx: GameRoot) -> void:
	root = ctx

func connect_bus(sig: Signal, handler: Callable) -> void:
	sig.connect(handler)
	_connections.append([sig, handler])

## Number of bus handlers this module currently holds connected.
func connection_count() -> int:
	return _connections.size()

func unwire() -> void:
	for pair: Array in _connections:
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if sig.is_connected(handler):
			sig.disconnect(handler)
	_connections.clear()
