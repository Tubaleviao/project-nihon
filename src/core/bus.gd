extends Node
## Central event bus — add to Project → Autoload as "GameBus".
##
## Each slice registers itself on _ready() and communicates exclusively
## through these signals. Slices never hold direct references to each other,
## so any slice can be replaced or hot-swapped without touching the others.

# ---------------------------------------------------------------------------
# Terrain
# ---------------------------------------------------------------------------

## Emitted by TerrainSlice when a chunk finishes generating.
## chunk_pos : Vector2i  — grid coordinates of the chunk
## heightmap  : Array    — flat Array[float] of length chunk_size²
signal chunk_ready(chunk_pos: Vector2i, heightmap: Array)

# ---------------------------------------------------------------------------
# Battle
# ---------------------------------------------------------------------------

## Emitted by BattleSlice to broadcast the outcome of one combat round.
## result : Dictionary  — { attacker, defender, damage, outcome }
signal combat_round_resolved(result: Dictionary)

## Request a combat round (any system can fire this).
## attacker_id : String — entity key from GameData.CREATURES or "player"
## defender_id : String — entity key from GameData.CREATURES or "player"
signal combat_round_requested(attacker_id: String, defender_id: String)

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

## Emitted by NetworkingSlice when a remote peer connects.
signal peer_connected(peer_id: int)

## Emitted by NetworkingSlice when a remote peer disconnects.
signal peer_disconnected(peer_id: int)

## Emitted by NetworkingSlice when a packet arrives from a peer.
## peer_id : int   — source peer
## payload : Dictionary — deserialized message
signal packet_received(peer_id: int, payload: Dictionary)

## Request to send a packet to a peer (any system can fire this).
signal packet_send_requested(peer_id: int, payload: Dictionary)

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

## Emitted by PersistenceSlice when a save completes successfully.
signal save_completed(slot: int)

## Emitted by PersistenceSlice when a load completes successfully.
## data : Dictionary — the loaded world state
signal load_completed(slot: int, data: Dictionary)

## Emitted by PersistenceSlice when a load fails (file missing, unreadable, or corrupt).
signal load_failed(slot: int, reason: String)

## Request a save/load (any system can fire these).
signal save_requested(slot: int, data: Dictionary)
signal load_requested(slot: int)
