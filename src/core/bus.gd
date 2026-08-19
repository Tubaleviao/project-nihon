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

## Emitted by CreatureSlice when a dead creature instance respawns.
## instance_id : String   — unique runtime identifier for this instance
## creature_id : String   — fabric key (e.g. "ForestBoar")
signal creature_respawned(instance_id: String, creature_id: String)

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

## Emitted by InventorySlice whenever contents change (add/drop/consume/pickup).
## The UI slice listens to refresh the inventory window.
signal inventory_changed()

# ---------------------------------------------------------------------------
# Crafting
# ---------------------------------------------------------------------------

## Request to craft a recipe (emitted by the player/UI or any system).
## recipe_id : String — key from GameData.RECIPES (e.g. "RecipeFerritePick")
signal craft_requested(recipe_id: String)

## Emitted by CraftingSlice with the outcome of a craft attempt.
## result : Dictionary — { recipe_id, success, outputs: [{ item, quantity }], reason }
signal craft_resolved(result: Dictionary)

# ---------------------------------------------------------------------------
# Mining / building
# ---------------------------------------------------------------------------

## Request to mine the voxel block under the given world position (PlayerSlice
## on right-click). normal is the hit face normal, used to disambiguate which
## column to mine when the ray strikes a side face. VoxelSlice lowers the
## column and yields a material.
signal block_mine_requested(position: Vector3, normal: Vector3)

## Request to place a voxel block against the hit face (PlayerSlice on
## middle-click). normal is the face normal used to pick the target column.
signal block_place_requested(position: Vector3, normal: Vector3)

## Request to advance the build material selection (PlayerSlice on R).
signal block_cycle_material_requested()

## Emitted by VoxelSlice when a block is mined and its material enters the inventory.
signal block_mined(material: String, quantity: int, position: Vector3)

## Emitted by VoxelSlice when a block is placed.
signal block_placed(material: String, position: Vector3)

## Emitted by VoxelSlice when the build material selection changes.
signal block_place_material_changed(material: String)

# ---------------------------------------------------------------------------
# Technology / research
# ---------------------------------------------------------------------------

## Request to begin researching a technology (emitted by the player/UI or any
## system). tech_id : String — key from GameData.TECHNOLOGIES (e.g. "TechBasicSmithing").
signal research_requested(tech_id: String)

## Emitted by TechnologySlice with the outcome of a research attempt.
## result : Dictionary — { tech_id, success, reason, status }
signal research_resolved(result: Dictionary)

## Emitted by TechnologySlice when research completes and a technology unlocks.
## tech_id : String — key from GameData.TECHNOLOGIES
signal technology_unlocked(tech_id: String)

# ---------------------------------------------------------------------------
# Player
# ---------------------------------------------------------------------------

## Emitted by BattleSlice when a creature's attack lands on the player.
## damage      : float   — amount of damage dealt this round
## attacker_id : String  — creature instance_id that attacked
signal player_damaged(damage: float, attacker_id: String)

## Emitted by PlayerSlice when the player's HP reaches zero.
## position  : Vector3 — world position at time of death
## killer_id : String  — attacker entity_id ("" if environmental)
signal player_died(position: Vector3, killer_id: String)

## Emitted by PlayerSlice when the player dies and then respawns.
signal player_respawned(position: Vector3)

## Emitted by CreatureAI when it detects the player (idle→alert transition).
## instance_id : String — which creature instance entered alert state
signal creature_alert(instance_id: String)

## Emitted by CreatureAI when a creature switches to aggressive state.
signal creature_aggressive(instance_id: String)

## Emitted by CreatureAI when a creature flees (HP < flee threshold).
signal creature_fleeing(instance_id: String)

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

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Disconnect every GameBus connection whose bound object is `target`. Used by
## the test suite to detach queued-for-free slices (queue_free is deferred to
## end of frame) so they stop answering production bus emissions during the same
## boot frame — otherwise a stale PersistenceSlice re-saves/re-loads the world
## and stale VoxelSlice/CraftingSlice instances rebuild chunks and spam logs.
func disconnect_all_from(target: Object) -> void:
	for sig in get_signal_list():
		var signal_name: String = sig["name"]
		for conn in get_signal_connection_list(signal_name):
			if conn["callable"].get_object() == target:
				disconnect(signal_name, conn["callable"])
