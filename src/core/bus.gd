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

# ---------------------------------------------------------------------------
# Battle — death signals
# ---------------------------------------------------------------------------

## Emitted by BattleSlice when a combatant's HP reaches zero.
## entity_id   : String   — creature key or "player"
## position    : Vector3  — world position of the death
## killer_id   : String   — entity_id of the killer ("" if environmental)
signal creature_died(entity_id: String, position: Vector3, killer_id: String)

## Emitted by CreatureSlice when a new creature instance enters the world.
## instance_id : String   — unique runtime identifier for this instance
## creature_id : String   — fabric key (e.g. "ForestBoar")
## position    : Vector3  — spawn world position
signal creature_spawned(instance_id: String, creature_id: String, position: Vector3)

## Request to attack the nearest creature (emitted by PlayerSlice on attack input).
## attacker_id : String — "player" or creature instance_id
signal attack_requested(attacker_id: String)

# ---------------------------------------------------------------------------
# Loot
# ---------------------------------------------------------------------------

## Emitted by LootSlice when a pickup appears in the world.
## pickup_id : String     — unique identifier for this loot instance
## item_id   : String     — GameData item key
## position  : Vector3    — world position of the pickup
## quantity  : int
signal loot_dropped(pickup_id: String, item_id: String, position: Vector3, quantity: int)

## Emitted by LootSlice when a pickup despawns without being collected.
signal loot_expired(pickup_id: String)

## Request to pick up a world pickup (emitted by PlayerSlice when the player
## aims at a pickup and clicks). Carries the LootSlice pickup id.
signal pickup_requested(pickup_id: String)

# ---------------------------------------------------------------------------
# Inventory
# ---------------------------------------------------------------------------

## Emitted by InventorySlice when a player picks up a world item.
## item_id  : String — GameData item key
## quantity : int
signal item_picked_up(item_id: String, quantity: int)

## Emitted by InventorySlice when the inventory reaches capacity.
signal inventory_full()

# ---------------------------------------------------------------------------
# Player
# ---------------------------------------------------------------------------

## Emitted by PlayerSlice every physics tick with authoritative position/health.
## payload : Dictionary — { "position": Vector3, "hp": float, "max_hp": float }
signal player_state_changed(payload: Dictionary)

## Networking: broadcast our player state to peers.
## payload : Dictionary — same schema as player_state_changed payload
signal player_state_sync_requested(payload: Dictionary)

# ---------------------------------------------------------------------------
# Character
# ---------------------------------------------------------------------------

## Emitted by CharacterSlice when a character instance is assembled in the world.
## instance_id : String   — unique runtime identifier
## skeleton_id : String   — skeleton key (e.g. "humanoid_01", "quadruped_01")
## position    : Vector3  — world position
signal character_spawned(instance_id: String, skeleton_id: String, position: Vector3)

## Emitted by CharacterSlice when an instance's appearance recipe is replaced.
## instance_id : String
## appearance  : Dictionary — the normalized appearance recipe
signal character_appearance_changed(instance_id: String, appearance: Dictionary)
