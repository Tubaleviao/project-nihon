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

## Emitted by ChunkManager when a chunk enters the loaded set (Phase 17).
## chunk_pos : Vector2i  — grid coordinates of the chunk
signal chunk_loaded(chunk_pos: Vector2i)

## Emitted by ChunkManager when a chunk leaves the loaded set (Phase 17).
## chunk_pos : Vector2i  — grid coordinates of the chunk
signal chunk_unloaded(chunk_pos: Vector2i)

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

## Authoritative world sync (Phase 18) — host validates and broadcasts world
## state; clients apply it locally instead of simulating.
## ---------------------------------------------------------------------------

## Emitted by the host when a client connects and needs the initial world state.
## peer_id : int — the peer to send the snapshot to.
signal world_snapshot_requested(peer_id: int)

## Emitted on a client when the host's initial world snapshot arrives.
## data : Dictionary — { chunks, edits, creatures, players }
signal world_snapshot_received(data: Dictionary)

## Client → host: a player wants to mine/place a block. The host re-runs the
## edit authoritatively and broadcasts the result via block_changed.
## action : String — "mine" or "place"
signal block_edit_intent(action: String, position: Vector3, normal: Vector3, material: String)

## Host → clients: authoritative result of a block edit, applied via
## VoxelSlice.apply_block_change().
signal block_changed(action: String, position: Vector3, normal: Vector3, material: String)

## Host → clients: authoritative creature state delta (position + state enum).
signal creature_state_changed(instance_id: String, creature_id: String, state: String, position: Vector3)

## Remote player position update for ghost interpolation (host → clients).
signal remote_player_state(peer_id: int, position: Vector3)

## Host → clients: authoritative inventory contents (replace local state), plus
## the per-instance durability map (item_id -> Array) so worn tools don't come
## back pristine after a sync.
##
## Phase 37 — an inventory belongs to ONE player, so the sync NAMES that owner and
## every InventorySlice decides whether it is the addressee (see
## InventorySlice.owner_id). Without it the signal was global: one process can hold
## several inventories at once (the local player's, one per connected peer created
## by the registry, the demo merchant's), and every one of them replaced its
## contents with whatever was synced — a peer's sync clobbered the host's own pack
## and the merchant's stock.
##
## owner_id : String — the player whose inventory this is. "" and the literal
##                     "player" both mean THIS machine's own player (the Phase 34
##                     `resolve_player` convention); any other value is a player id.
signal inventory_synced(owner_id: String, contents: Dictionary, durabilities: Dictionary)

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
# Player identity + authoritative records (Phase 33)
# ---------------------------------------------------------------------------

## Client → host: a joining player presents a cached player_id (empty on a first
## join). The host resolves it — honouring a known id that no live peer holds,
## minting a fresh one otherwise — so a reconnect re-binds to the same record.
## peer_id    : int    — the connection the id belongs to (transport only)
## claimed_id : String — the client's cached id ("" when it has none)
signal player_join_intent(peer_id: int, claimed_id: String)

## Host → client: the server-issued player_id for this connection. The client
## caches it so a reconnect can claim the same record.
signal player_identity_assigned(player_id: String)

## Host-side: an identity was bound to a connection (first join or reconnect).
## peer_id     : int    — the connection the id was bound to (transport only)
## player_id   : String — the server-issued id
## reconnected : bool   — true when the connection claimed an existing record
signal player_joined(peer_id: int, player_id: String, reconnected: bool)

## Host-side: a connection dropped and its record was written. The record is
## retained, so the player_id is still valid for a later reconnect.
signal player_left(player_id: String)

## Emitted by PersistenceSlice when the authoritative world record is written.
signal world_saved()

## Emitted by PersistenceSlice when a world save fails.
signal world_save_failed(reason: String)

## Emitted by PersistenceSlice when one player record is written.
signal player_saved(player_id: String)

## Host → one client (Phase 34): the peer's OWN record slice, re-sent when the host
## changed something inside it on that peer's behalf — its inventory after a
## remote repair/craft, or its technology statuses after a remote research. Scope is
## the peer alone: an inventory is private, so this cannot ride a broadcast the way
## an AOI-scoped world delta can. `data` mirrors the like-named keys of the join
## snapshot: { inventory, inventory_durability, technology }.
signal own_state_synced(data: Dictionary)

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

## Emitted by InventorySlice when a durable item's condition reaches broken
## (durability hits 0) and its action is blocked.
## item_id : String — GameData item key (e.g. "FerritePick")
signal item_broke(item_id: String)

# ---------------------------------------------------------------------------
# Crafting
# ---------------------------------------------------------------------------

## Request to craft a recipe (emitted by the player/UI or any system).
## recipe_id : String — key from GameData.RECIPES (e.g. "RecipeFerritePick")
signal craft_requested(recipe_id: String)

## Phase 33 — a craft intent carrying WHO is crafting, so crafting is per-player.
## A client emits it with an empty player_id ("me"); the networking slice forwards
## it to the host, which re-emits it with the identity it resolved for that
## connection, and CraftingSlice resolves the recipe against that player's own
## inventory. Host-local crafting stays on `craft_requested`.
## recipe_id : String — key from GameData.RECIPES
## player_id : String — the crafter; "" means "the local player"
signal craft_intent(recipe_id: String, player_id: String)

## Emitted by CraftingSlice with the outcome of a craft attempt.
## result : Dictionary — { recipe_id, success, outputs: [{ item, quantity }], reason }
signal craft_resolved(result: Dictionary)

## Request to repair a held durable item (emitted by the player/UI or any system).
## item_id : String — key from GameData.ITEMS (e.g. "FerritePick")
signal repair_requested(item_id: String)

## Phase 34 — a repair intent carrying WHO is repairing, so repair is per-player
## like crafting. A client emits it with an empty player_id ("me"); the networking
## slice forwards it to the host, which re-emits it with the identity it resolved
## for that connection, and CraftingSlice consumes the materials from and restores
## the durability of that player's own inventory. Host-local repair stays on
## `repair_requested`.
## item_id   : String — key from GameData.ITEMS
## player_id : String — the repairing player; "" means "the local player"
signal repair_intent(item_id: String, player_id: String)

## Emitted by CraftingSlice with the outcome of a repair attempt.
## result : Dictionary — { item_id, success, reason, player_id }
signal repair_resolved(result: Dictionary)

# ---------------------------------------------------------------------------
# Stations
# ---------------------------------------------------------------------------

## Emitted by StationSlice when a crafting station is placed in the world.
## station_id : String  — unique runtime identifier
## type       : String  — station type (e.g. "forge", "alchemy bench")
## position   : Vector3 — world position
signal station_placed(station_id: String, type: String, position: Vector3)

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

## Phase 34 — a research intent carrying WHO is researching. The technology tree is
## per-player state now (one status set per player), so a client cannot resolve a
## research locally: it emits this with an empty player_id ("me"), networking
## forwards it, and the host re-emits it with the identity bound to that connection
## so the materials come off that player's own inventory and only that player's
## status moves. Host-local research stays on `research_requested`.
## tech_id   : String — key from GameData.TECHNOLOGIES
## player_id : String — the researcher; "" means "the local player"
signal research_intent(tech_id: String, player_id: String)

## Emitted by TechnologySlice with the outcome of a research attempt.
## result : Dictionary — { tech_id, success, reason, status, player_id }
signal research_resolved(result: Dictionary)

## Emitted by TechnologySlice when research completes and a technology unlocks.
## The player matters: a host research that unlocks for ONE player must not read as
## a world-wide unlock. `player_id` is "" when no player registry is wired.
## tech_id   : String — key from GameData.TECHNOLOGIES
## player_id : String — whose tree gained the technology
signal technology_unlocked(tech_id: String, player_id: String)

# ---------------------------------------------------------------------------
# Trees (Phase 31)
# ---------------------------------------------------------------------------

## Request to fell a standing tree (emitted by PlayerSlice on a chop input, or
## forwarded by a client to the host). Handled by TreeSlice.
## tree_id : String — TreeSlice tree id (carried as metadata on the trunk body)
signal tree_chop_requested(tree_id: String)

## Emitted by TreeSlice with the authoritative result of a chop. A client applies
## this instead of chopping locally.
## tree_id    : String — TreeSlice tree id
## wood       : String — the wood material felled (e.g. "Thornwood")
## state      : String — the tree's state after the chop ("stump")
## respawn_at : float  — wall-clock Unix seconds the stump regrows
signal tree_chopped(tree_id: String, wood: String, state: String, respawn_at: float)

## Emitted by TreeSlice when a stump regrows into a standing tree.
## tree_id : String — TreeSlice tree id
signal tree_respawned(tree_id: String)

# ---------------------------------------------------------------------------
# Player
# ---------------------------------------------------------------------------

## Emitted by BattleSlice when a creature's attack lands on a player.
## damage      : float   — amount of damage dealt this round
## attacker_id : String  — creature instance_id that attacked
## target_id   : String  — WHICH player took the hit: the literal "player" for this
##                         machine's own body, or a remote peer's player id (Phase
##                         37 — upstream, `combat_round_requested` names the player
##                         the creature actually engaged, so the round is routed by
##                         that target instead of being opened for the local body
##                         only). The host forwards a remote target's damage over
##                         the wire; the machine that simulates that body applies it.
signal player_damaged(damage: float, attacker_id: String, target_id: String)

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

## Request the attack animation on a character instance (ROADMAP Phase 20).
## Wired from game_root when the player attacks (combat_round_requested with
## attacker == "player").
signal character_attack_requested(instance_id: String)

## Request the death animation on a character instance (ROADMAP Phase 20).
## Wired from game_root on player death.
signal character_death_requested(instance_id: String)

## Request to toggle all equipment slots on/off at once (vanity/debug — inspect
## the "naked" body under the gear). Wired from PlayerSlice on a hotkey; the
## player's own character is resolved by CharacterSlice.
signal character_equipment_toggle_requested()

## Emitted by CharacterSlice when a character instance's locomotion state
## changes (ROADMAP Phase 20). state is the Locomotion.State name string
## ("IDLE", "WALK", "RUN", "FALL", "LAND", "ATTACK", "DEATH").
signal character_state_changed(instance_id: String, state: String)

# ---------------------------------------------------------------------------
# Trade (Phase 24)
# ---------------------------------------------------------------------------

## Emitted by TradeSlice when a two-party trade resolves (both accepted and the
## exchange committed). trade is the full trade record.
signal trade_completed(trade: Dictionary)

## Client → host (Phase 24 authority): a non-authoritative slice wants to open
## a trade between two parties.
signal trade_start_intent(party_a: String, party_b: String)

## Client → host: a non-authoritative slice wants to set or replace an offer
## (covers both propose and counter-offer).
signal trade_propose_intent(trade_id: String, party: String, give: Dictionary, want: Dictionary)

## Client → host: a non-authoritative slice wants to accept a trade.
signal trade_accept_intent(trade_id: String, party: String)

## Client → host: a non-authoritative slice wants to reject a trade.
signal trade_reject_intent(trade_id: String, party: String)

## Host → clients: authoritative trade state (all active trade sessions).
signal trade_synced(data: Dictionary)

# ---------------------------------------------------------------------------
# Market (Phase 24)
# ---------------------------------------------------------------------------

## Emitted by MarketSlice when a listing is created.
signal market_listing_created(listing_id: String, seller: String, item_id: String, quantity: int, price: float)

## Emitted by MarketSlice when a listing is purchased.
signal market_listing_purchased(listing_id: String, buyer: String, item_id: String, quantity: int)

## Emitted by MarketSlice when a listing expires without a buyer.
signal market_listing_expired(listing_id: String)

## Client → host (Phase 24 authority): a non-authoritative slice wants to list.
signal market_list_intent(seller: String, item_id: String, quantity: int, price: float)

## Client → host: a non-authoritative slice wants to buy a listing.
signal market_buy_intent(listing_id: String, buyer: String)

## Host → clients: authoritative market state (full listing data).
signal market_synced(data: Dictionary)

# ---------------------------------------------------------------------------
# Governance / proposals (Phase 24)
# ---------------------------------------------------------------------------

## Emitted by ProposalSlice when a proposal is submitted for community vote.
signal proposal_submitted(proposal_id: String)

## Emitted by ProposalSlice when a proposal reaches ratification threshold.
signal proposal_ratified(proposal_id: String, title: String)

## Client → host (Phase 24 authority): a non-authoritative slice wants to submit.
signal proposal_submit_intent(author: String, title: String, body: String)

## Client → host: a non-authoritative slice wants to cast a vote.
signal proposal_vote_intent(proposal_id: String, voter: String, verdict: String)

## Client → host: a non-authoritative slice wants to supersede a proposal with
## a ratified replacement.
signal proposal_supersede_intent(proposal_id: String, replacement_id: String)

## Host → clients: authoritative governance state (proposals + decisions log).
signal governance_synced(data: Dictionary)

# ---------------------------------------------------------------------------
# Taming (Phase 35)
# ---------------------------------------------------------------------------

## Request to tame a creature instance (emitted by PlayerSlice on a tame input,
## or any host-side system). The interaction is resolved against the creature's
## structured `tame` field in the fabric (fabric/world/creatures/*.js) — the
## requirements, the granted flag, the shed items and the cooldown all come from
## there, never from a table in GDScript.
## instance_id : String — CreatureSlice instance id
signal tame_requested(instance_id: String)

## Client → host (Phase 34/35 identity rule): a non-authoritative slice cannot
## resolve a tame, because the companion binding, the granted player flag and the
## consumed offering all belong to a player record the host owns. The client emits
## this with an empty player_id ("me"); networking forwards it, and the host
## re-emits it with the identity bound to that connection, so the offering comes
## off that player's own inventory and only that player's flags move. Host-local
## taming stays on `tame_requested`.
##
## `unarmed` is the client's claim about its OWN hands (Phase 36), which is the only
## equipment evidence a host can have for a peer: a body's worn gear is not
## replicated, so the bare-hands requirement (`requiresUnarmed` in the fabric)
## cannot be evaluated from the host's own state. It is a CLAIM — client-declared,
## never persisted, and consumed by the resolution it accompanies — and a peer that
## claims nothing fails the requirement closed instead of passing it for free.
## instance_id : String — CreatureSlice instance id
## player_id   : String — the tamer; "" means "the local player"
## unarmed     : bool — the tamer's claim that its hands are empty (see above)
signal tame_intent(instance_id: String, player_id: String, unarmed: bool)

## Emitted by TamingSlice with the outcome of a tame attempt.
## result : Dictionary — { instance_id, creature_id, success, reason, result,
##          player_id, flag, yields }
signal tame_resolved(result: Dictionary)

## Emitted by TamingSlice when an instance becomes a player's companion.
## instance_id : String — CreatureSlice instance id
## creature_id : String — fabric key (e.g. "GraywolfPack")
## player_id   : String — the companion's owner
signal creature_tamed(instance_id: String, creature_id: String, player_id: String)
