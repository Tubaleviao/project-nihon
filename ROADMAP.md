# Project Nihon — Roadmap

Project Nihon is an open-source sandbox MMORPG where players build a
civilization. This document tracks the design and implementation roadmap.
The game's entire design bible — materials, creatures, skills, items, world
systems — is authored as a Newel fabric and generated into documentation,
runtime assets, and Godot resources.

See `../newel/ROADMAP.md` for the Newel-side changes each phase depends on.

---

## Phase 1 — Constitution fabric

**Goal:** Encode the game's foundational decisions in a fabric so they can be
referenced by every subsequent definition.

**Newel dependency:** None. Uses existing `meta` and `FabricSchema` as-is.

**Deliverables:**
- `fabric.js` (root) with `meta` block containing name, version, and a
  description that captures the core vision
- `constitution/principles.js` — the ten core principles as named behaviors
  (description + rules list)
- `constitution/decisions.js` — current decisions modelled as entities with
  `kind: 'decision'` and a state machine (`proposed → accepted → superseded`)
- `constitution/monetization.js` — monetization rules as a named system block

**Acceptance criteria:**
- `pnpm validate` passes with zero errors
- `pnpm inspect` lists principles and decisions by name
- Each principle and decision has a non-empty `description`

---

## Phase 2 — Materials and world primitives

**Goal:** Define the fictional materials that underpin crafting and the
physical simulation.

**Newel dependency:** Phase 11a (`kind` discriminator) and Phase 11b (spawn
weights).

**Deliverables:**
- `world/materials/` — one file per material category (metals, woods, stones,
  synthetics, magical)
- Each material modelled as an entity with `kind: 'material'`, fields for
  `density`, `hardness`, `conductivity`, `magicAffinity`, and a
  `description` covering in-world lore
- `world/biomes/` — one file per biome; each biome entity lists which
  materials and creatures it spawns with weights and conditions
- `world/weather.js` — weather system as a `SystemSchema` block with rules
  and parameters

**Acceptance criteria:**
- All materials have complete physical property fields
- Every biome references at least one material and one creature (even if the
  creature is a placeholder)
- `pnpm validate` passes

---

## Phase 3 — Skills and professions

**Goal:** Define every player skill and how skills combine into professions.

**Newel dependency:** Phase 11a (`kind: 'skill'`, `kind: 'profession'`).

**Deliverables:**
- `gameplay/skills/` — one file per skill domain (combat, crafting, magic,
  exploration, social)
- Each skill modelled as an entity with fields for `xpCurve`, `maxLevel`,
  `category`; state machine for progression tiers
  (`novice → apprentice → journeyman → expert → master`)
- Behaviors on each skill for what actions it gates (guards reference skill
  tier)
- `gameplay/professions/` — professions as entities with `kind: 'profession'`
  and relations to their constituent skills

**Acceptance criteria:**
- Every skill has a complete state machine with all five tiers
- Professions declare their required skills via relations
- Skill guards use consistent language (e.g. `"Requires Smithing: Apprentice"`)

---

## Phase 4 — Items, recipes, and technology tree

**Goal:** Model every craftable item, the recipes that produce them, and the
technology progression that unlocks recipes.

**Newel dependency:** Phase 11a (`kind: 'item'`, `kind: 'recipe'`,
`kind: 'technology'`).

**Deliverables:**
- `gameplay/items/` — items by category (tools, weapons, armor, food,
  components, magical)
- Each item: fields for `weight`, `rarity`, `stackable`, `durability`;
  relations to required materials; state machine for durability
  (`pristine → worn → damaged → broken`)
- `gameplay/recipes/` — one file per crafting domain; each recipe has
  relations to input items/materials and output items, plus skill guards
- `gameplay/technology/` — technology tree as entities with `kind: 'technology'`,
  state machine (`locked → researching → unlocked`), and relations to what
  they unlock

**Acceptance criteria:**
- Every item lists its material requirements via relations
- Every recipe has at least one skill guard
- Technology unlocks are expressed as entity relations, not free text

---

## Phase 5 — Creatures and combat systems

**Goal:** Define the world's fauna and the combat rules that govern
player–creature and player–player interaction.

**Newel dependency:** Phase 11b (spawn weights already used in Phase 2 biomes,
now populated with real creature references). Phase 11c (`SystemSchema` for
combat rules).

**Deliverables:**
- `world/creatures/` — one file per creature family
- Each creature: fields for `tier`, `aggressionLevel`, `baseHp`, `baseDamage`;
  state machine for `idle/alert/aggressive/fleeing/dead/respawning`; behaviors
  for `attack`, `drop`, `tame` (where applicable)
- `gameplay/combat.js` — combat system as a `SystemSchema` with rules for
  hit calculation, critical strikes, status effects, magic interactions
- Back-fill biomes from Phase 2 with real creature spawn entries

**Acceptance criteria:**
- All creatures have a complete state machine including `respawning`
- Biomes reference real creature entities (no placeholder strings)
- Combat system rules cover the scenarios described in the constitution
  (magic balanced with martial, destructible buildings via systems)

---

## Phase 6 — `generator-bible` integration

**Goal:** Run `pnpm generate` in this project and produce a readable design
bible.

**Newel dependency:** Newel Phase 12 (`generator-bible`) must be released.

**Deliverables:**
- `newel.config.js` wired up with `BibleGenerator`
- `bible/` output folder committed to the repo as a generated artifact
- Bible covers all phases: constitution, materials, biomes, skills, items,
  recipes, technology, creatures, combat

**Acceptance criteria:**
- Every entity has a rendered page
- State machine diagrams render correctly in Mermaid
- Cross-links between pages resolve (recipe links to its output item)
- The bible is browsable without a server (static files)

---

## Phase 7 — Character system specification

**Goal:** Produce a complete, actionable character system specification that
covers visual customization, asset architecture, animation, persistence, and
multiplayer state — ready to guide engine implementation and art production.

**Newel dependency:** None. This is a design phase.

**Deliverables:**
- `characters.md` — full character system specification covering:
  - `SkeletonDefinition` taxonomy (humanoid, quadruped, bird, serpent, custom)
  - Three customization dimensions: Shape, Composition, Appearance
  - Bones vs. Sockets distinction and socket naming conventions
  - Equipment Slot vs. Socket vs. Attachment State model
  - Base body proportion parameters and their artistic bounds
  - Equipment deformation modes (SKINNED, RIGID, HYBRID)
  - Mesh hiding system
  - Material system: Primary / Secondary / Accent masks, Metal, Emission, Wear
  - Palette system design, including **explicit palette size decision**
  - Per-instance material data approach (engine-agnostic)
  - Pixel art texture guidelines: resolutions, Point filtering, UV mapping
  - Texture Arrays and atlas strategy
  - Persistence-as-recipe model for characters and equipment
  - Multiplayer visual state synchronization
  - Permanent vs. transient visual state separation
  - LOD levels and composition simplification with `minLodLevel` per attachment
  - Animation system specification: locomotion state machine
    (`idle / walk / run / fall / land`), blend tree layout, root-motion policy,
    IK targets for hand and foot placement, and transition rules between states
  - Data-driven content model
  - Asset compatibility and semantic tag system
  - Asset production pipeline checklist
  - Optimization decision order

**Open items to resolve before engine implementation:**
- Final palette size (recommended starting point: 256 entries)
- Hitbox category definitions

**Acceptance criteria:**
- Every section has enough detail to guide an implementation decision
- Palette size is explicitly decided and documented
- Animation state machine covers at minimum: idle, walk, run, fall, land, attack,
  death — with transition conditions and blend parameters specified
- The asset pipeline checklist is complete and agreed upon by art and engineering

---

## Phase 8 — `generator-godot` integration ✅ Done

**Goal:** Generate Godot 4.x-ready resource files from the same fabric.

**Newel dependency:** Newel Phase 14 (`generator-godot`) — implemented as part
of this phase in `../newel/packages/generator-godot/`.

**Deliverables:**
- `newel.config.js` updated with `GodotGenerator`
- `godot/` output folder with `.tres` resource files per entity, grouped by tag
- `godot/autoload/GameData.gd` singleton with typed `Dictionary` constants
- GDScript enums (`.gd`) per entity that has enum fields or a state machine;
  state machine states are exposed as the `State` enum

**Acceptance criteria:**
- Generated files load in a Godot 4.x project without errors ✓
- `GameData.ITEMS`, `GameData.CREATURES`, etc. are accessible at runtime ✓
- State machine states available as GDScript enums ✓
- Any IR change triggers drift detection (`pnpm check-drift`) before Godot
  import ✓

---

## Phase 9 — Public wiki ✅ Done

**Goal:** Publish a player-facing wiki generated from the same fabric.

**Newel dependency:** Newel Phase 13 (`generator-wiki`).

**Deliverables:**
- `newel.config.js` updated with `WikiGenerator`
- `wiki/` output committed to the repo (generated Markdown per entity)
- Internal design notes (rules, guards written as implementation details)
  suppressed via patches

**Acceptance criteria:**
- Wiki generator wired and producing player-facing Markdown ✓
- Wiki output committed and regenerable from the fabric ✓

**Deferred:** public static-site deployment (VitePress or equivalent) and
CI-triggered regeneration are not yet wired.

---

## Phase 10 — Vertical slices: playable game loop ✅ Done

**Goal:** Produce a playable, bus-driven prototype that exercises every major
game system end-to-end. All runtime constants (HP, damage, loot despawn, item
weights, inventory limits) are sourced from `GameData` / the fabric rather than
hardcoded elsewhere.

**Deliverables:**

- `src/core/bus.gd` — central `GameBus` autoload; all inter-slice communication
  travels through typed signals. Added in this phase:
  - `creature_spawned(instance_id, creature_id, position)` — emitted when a
    creature enters the world
  - `attack_requested(attacker_id)` — emitted by PlayerSlice on attack input
  - `combat_round_requested` / `combat_round_resolved` — battle pipeline signals

- `src/terrain/terrain_slice.gd` + `voxel_slice.gd` — noise-based voxel terrain
  generated in chunks; `chunk_ready` signal drives mesh construction

- `src/creature/creature_slice.gd` — **new**; spawns creature instances from
  `GameData.CREATURES` (`SPAWN_MANIFEST` lists fabric keys and counts); reads
  `baseHp` directly from the fabric resource; provides
  `nearest_creature(pos, radius)` and `get_instance_creature_id(id)` for other
  slices; handles death and respawn cycle

- `src/player/player_slice.gd` — first-person `CharacterBody3D`; left-click or
  `F` emits `combat_round_requested("player", nearest_instance_id)` via
  `GameBus`; `creature_slice` reference wired by `game_root` at startup;
  `ATTACK_RANGE` constant (3 m) sets melee interaction radius

- `src/battle/battle_slice.gd` — resolves combat stats from `GameData.CREATURES`
  using the fabric's `baseHp` / `baseDamage` fields; resolves creature
  `instance_id → fabric key` via `creature_slice`; emits `creature_died` with
  the world-space death position looked up from `creature_slice`

- `src/loot/loot_slice.gd` — drop tables are a direct transcription of each
  creature's `drop` behavior rules in the fabric (`fabric/world/creatures/`);
  `DESPAWN_SECONDS` constant matches `LootTable.despawnSeconds` defaultValue
  (`120`) in `fabric/gameplay/loot.js`; resolves `instance_id → fabric key` via
  `creature_slice` so drops work whether the signal carries a key or instance ID

- `src/inventory/inventory_slice.gd` — `MAX_SLOTS` (30) and `MAX_WEIGHT` (50 kg)
  match `PlayerCharacter.maxSlots` / `maxWeightKg` defaults in the fabric;
  item weights are built at `_ready()` from `GameData.ITEMS` (each `.tres` has a
  `weight` property generated from the fabric); raw creature drops not modelled
  as fabric items fall back to `RAW_DROP_WEIGHTS`

- `src/networking/networking_slice.gd` — ENet peer-to-peer host/connect;
  `packet_received` / `peer_connected` / `peer_disconnected` signals

- `src/persistence/persistence_slice.gd` — `FileAccess`-based save/load to
  `user://` slot files; `save_completed` / `load_completed` / `load_failed`
  signals

- `src/core/game_root.gd` — integration root; instantiates all slices, wires
  cross-slice references (`creature_slice` into player/battle/loot,
  `loot_slice` into inventory), connects bus listeners, boots terrain and
  triggers the creature awareness check via the bus rather than calling slice
  methods directly

- `src/tests/test_suite.gd` — self-contained test runner; 16 tests covering
  battle, terrain, persistence, loot, and inventory slices; runs at startup
  before world boot; assertions use real signal flows, not mocked intermediates

**Acceptance criteria:**
- Player can move on voxel terrain and attack nearest creature with left-click or F ✓
- Attack input emits `combat_round_requested` through `GameBus` (no direct slice call) ✓
- Creature stats (`baseHp`, `baseDamage`) are read from `GameData.CREATURES` ✓
- Creature deaths emit `creature_died` with real world-space position ✓
- Drop tables are an explicit transcription of fabric `drop` behavior rules ✓
- `DESPAWN_SECONDS` matches `LootTable.despawnSeconds` fabric defaultValue ✓
- Item weights for crafted items loaded at runtime from `GameData.ITEMS` ✓
- `MAX_SLOTS` / `MAX_WEIGHT` match `PlayerCharacter` fabric defaultValues ✓
- All 16 automated tests pass at startup ✓

---

## Phase 11 — Crafting slice ✅ Done

**Goal:** Prove the fabric drives gameplay beyond combat — resolve recipes from
structured fabric data against the player's inventory and skill tiers.

**Newel dependency:** None. Uses the existing `json` field type (already emitted
by `generator-godot`); no generator change needed.

**Deliverables:**
- `fabric/gameplay/recipes/*` — each recipe gains a structured `recipe` json
  field (via `recipeData()` in `shared.js`): inputs (item key + quantity),
  outputs (item key + quantity), and skill guards (skill key + minimum tier).
  Relations and behaviors are unchanged — they remain the graph view for the
  bible/wiki generators and the technology tree.
- `src/crafting/crafting_slice.gd` — resolves recipes from `GameData.RECIPES`
  against the inventory; enforces skill guards (novice → master, fail-closed);
  consumes inputs atomically then produces outputs.
- `src/inventory/inventory_slice.gd` — new `add_item` / `consume_items` /
  `can_add_items` primitives for programmatic inventory mutation.
- `src/core/bus.gd` — `craft_requested` / `craft_resolved` signals.
- `src/tests/test_suite.gd` — 6 crafting tests (data load, skill guard,
  consume/produce, missing inputs, unknown recipe, non-mutating check).

**Acceptance criteria:**
- Recipes resolve from `GameData.RECIPES` — the fabric is the single source of truth ✓
- Skill guards gate recipes by tier, fail closed ✓
- Crafting consumes inputs and produces outputs in inventory ✓
- All 6 crafting tests pass at startup ✓

**Known simplifications (deferred):**
- Station gating (`forge`, `alchemy bench`, …) is not enforced — no building system yet.
- Materials have no weight model (inventory weight resolves to 0 for raw materials).
- Herb/root reagents referenced by potion rules are not yet modelled as items.

---

## Phase 12 — Voxel mining and building ✅ Done

**Goal:** Realize the "players build a civilization" core fantasy — mine raw
materials from voxel terrain and place persistent structures.

**Newel dependency:** None. Reuses the existing fabric materials
(`GameData.MATERIALS`) and the inventory primitives added in Phase 11.

**Deliverables:**
- `src/terrain/voxel_slice.gd` — edit API: `mine_block(world_pos)` lowers a
  column one `STEP_HEIGHT` and yields the biome's material into the inventory;
  `place_block(world_pos, normal)` raises the adjacent column one step and
  consumes the selected material. Edits are stored as absolute quantised
  heights keyed by global tile coordinate and re-applied on every
  `build_chunk` rebuild.
- `src/terrain/terrain_slice.gd` — `get_biome_at(world_pos)` on a fixed-seed
  temperature noise channel (independent of the height noise) so biome
  assignment is deterministic across runs.
- Biome-aware material spawns: `BIOME_MATERIALS` maps biome → material keys
  (temperate → ferrite/thornwood, volcanic → ashite/aethermite, twilight →
  duskfiber/lumenfite, void → voidite/aethermite); `material_for_biome()` picks
  deterministically per tile. (Superseded on the wood half: the map-improvements
  change dropped every wood material from this table — the biome prose spawns
  wood as trees, which Phase 31 implements in `src/world/tree_slice.gd`. The
  table is now ferrite/rock plus the two rare ores above.)
- `src/player/player_slice.gd` — a second aim ray targets the terrain on its
  dedicated collision layer (layer 2); right-click mines, middle-click places,
  `R` cycles the build material. Terrain collision moved to layer 2 so the
  block ray never hits the player's own body.
- Mined materials flow into the inventory via `inventory_slice.add_item`
  (feeding Phase 11 crafting); placement consumes via `drop_item`.
- Persistence: `get_edits()` / `apply_edits()` round-trip voxel edits through
  the world snapshot (`world.voxel_edits`); `game_root` restores them on
  `load_completed`.

**Acceptance criteria:**
- `mine_block` lowers the column height and yields a fabric material ✓
- `place_block` raises the column height and consumes the selected material ✓
- Mining at bedrock and building past the cap are blocked (fail-closed) ✓
- Materials resolve per biome (temperate ≠ volcanic) ✓
- Voxel edits survive a save/load round-trip ✓
- 6 automated tests pass at startup ✓

**Known simplifications (deferred):**
- Mining/building tool gating is not enforced (no durability or tier gates).
- Materials still have no weight model (inventory weight resolves to 0).

---

## Phase 13 — Technology unlock gates ✅ Done

**Goal:** Gate recipes behind the technology tree so progression
(`KnowledgeIsProgression`) is real, not text.

**Newel dependency:** None. Reuses the existing `json` field type (already
emitted by `generator-godot`); no generator change needed.

**Deliverables:**
- `fabric/gameplay/technology/index.js` — each technology gains a structured
  `tech` json field (via `techData()`): recipe unlocks, prerequisite
  technologies, research duration (seconds), and the material cost consumed on
  `beginResearch`.
- `src/technology/technology_slice.gd` — per-player research status
  (`locked → researching → unlocked`); `begin_research` validates prerequisites
  and consumes materials, `complete_research` unlocks, and a `_process` tick
  auto-completes research once its duration elapses. Reverse-indexes
  recipe → technology for gate lookups.
- `src/crafting/crafting_slice.gd` — `craft`/`can_craft` now check the recipe's
  owning technology is unlocked (in addition to skill guards), fail-closed via
  `technology_locked:<tech>`.
- `src/core/bus.gd` — `research_requested` / `research_resolved` /
  `technology_unlocked` signals.
- `src/core/game_root.gd` — wires TechnologySlice; the boot demo demonstrates
  a craft fail while locked, researches the two starter techs, then runs the
  smithing chain; technology status round-trips through the save snapshot.
- `src/tests/test_suite.gd` — 7 technology tests (recipe→tech mapping,
  prerequisite gate, material consumption, unlock, craft blocked/allowed,
  unknown tech).

**Acceptance criteria:**
- Recipes gate behind their owning technology (locked until researched) ✓
- Research consumes materials and takes time (auto-completes on duration) ✓
- Prerequisite technologies gate research, fail-closed ✓
- Technology status survives a save/load round-trip ✓
- All automated tests pass at startup (7 new technology tests) ✓

**Known simplifications (deferred):**
- Research cost is material-only; the abstract `researchCost` points field is
  not yet enforced.
- `VoidTouched` / `voidBurstSurvivor` special-case unlock triggers are not wired.

---

## Phase 14 — Player UI: inventory, technology tree, crafting ✅ Done

**Goal:** Expose the systems built so far through in-game windows so a player
can drive them without code. Inventory, technology tree, and crafting come
first; the window system is built to host more later.

**Deliverables:**
- `src/ui/ui_slice.gd` — **new**; a shared window layer (CanvasLayer) hosting
  three named panels with consistent chrome (title bar, ✕ close button,
  keyboard toggles `I` / `T` / `C`). Opening a window releases the mouse so
  buttons are clickable; closing the last window re-captures it. World input is
  gated in `player_slice.gd` on the mouse being captured, so no attack/mine
  slips through an open menu. Exposes pure data projections
  (`inventory_lines()`, `crafting_rows()`, `technology_rows()`) that the
  headless test suite asserts against directly.
- **Inventory window** (`I`) — item list + live weight/slot usage, replacing the
  old `I`-toggle debug label. `inventory_slice.gd` dropped its private UI and now
  emits an `inventory_changed` bus signal on any mutation, plus public
  `get_current_weight` / `get_max_weight` / `get_max_slots` accessors.
- **Technology tree window** (`T`) — one row per technology with status
  (`locked → researching → unlocked`), prerequisite edges (listed `requires`),
  material cost + duration, and a "Research" button emitting
  `research_requested` through the bus. Rows are disabled unless prerequisites
  are met.
- **Crafting window** (`C`) — every recipe rendered as inputs → outputs with a
  "Craft" button emitting `craft_requested`; blocked recipes are greyed out with
  the reason (skill tier, technology, missing inputs).
- Player input now drives research/craft through the bus via these windows,
  replacing the boot-demo-only signal emissions.

**Acceptance criteria:**
- Inventory, technology, and crafting windows open/close and reflect live state ✓
- Crafting blocks/unblocks recipes reactively as technologies unlock ✓
- Research can be initiated from the technology window (materials consumed,
  auto-completes on duration) ✓
- 4 new UI tests pass at startup (window toggle, inventory lines, crafting
  gate, technology rows) ✓

**Known simplifications (deferred):**
- Prerequisite edges render as text (`requires: …`) in a flat tier list, not a
  drawn node graph.
- Research failure feedback (e.g. missing materials) surfaces through the
  window's feedback line and the boot log, not a modal.

---

## Phase 15 — Creature AI and behavior ✅ Done

**Goal:** Make creatures alive — implement the fabric-defined state machines so
they patrol, aggro, attack back, flee, and respawn at biome-correct locations.
Combat previously resolved correctly but creatures were static targets.

**Newel dependency:** None. State machines were already modelled in the fabric
(`idle/alert/aggressive/fleeing/dead/respawning`); this phase wires them to
GDScript and adds the AI-specific fields to each creature entity.

**Fabric additions:**
- Each creature entity gained six new fields driven by the existing behavior
  rules text: `alertRadius`, `attackRadius`, `fleeThreshold`, `respawnSeconds`,
  `spawnCount`, `biome` (enum keyed to `BIOME_KEYS`). These fields are the
  single source of truth for AI tuning — no constants in GDScript.

**Deliverables:**
- `src/creature/creature_ai.gd` — per-instance state machine; transitions:
  `idle` → `alert` (player within `alertRadius` from `GameData.CREATURES`) →
  `aggressive` (within `attackRadius`) → `fleeing` (HP < `fleeThreshold`) →
  `dead` → `respawning`. Movement uses kinematic stepping (`position + dir *
  speed * delta`) wired through `creature_slice.set_instance_position` — no
  scene-tree `NavigationAgent3D` required (see Deferred below).
- `src/creature/creature_slice.gd` — spawn list built dynamically from
  `GameData.CREATURES` using each creature's `spawnCount` field; biome origin
  resolved from the `biome` enum int via a `BIOME_ORIGINS` constant array keyed
  to the same order as `BIOME_KEYS` in `fabric/world/creatures/shared.js`;
  per-creature `respawnSeconds` read from `GameData.CREATURES` on death instead
  of a fixed constant
- `src/battle/battle_slice.gd` — creature `attack` behavior emits
  `combat_round_requested(creature_instance_id, "player")` so the battle
  pipeline is bidirectional; `baseDamage` applied to player HP via `GameBus`
- `src/player/player_slice.gd` — player HP bar wired to `GameBus`
  `player_damaged` signal; death + respawn cycle (`RESPAWN_DELAY = 5 s`)

**Acceptance criteria:**
- Creatures patrol kinematically within their biome zone in `idle` state ✓
- Player entering `alertRadius` triggers `alert`; entering `attackRadius`
  triggers attack cycle ✓
- Creature flees when HP drops below `fleeThreshold`; creatures with
  `fleeThreshold = 0.0` (RiftWarden) never flee ✓
- Creature respawns after `respawnSeconds` read from `GameData.CREATURES` ✓
- Player takes damage from creature attacks; death triggers respawn ✓
- `alertRadius`, `attackRadius`, `fleeThreshold`, `respawnSeconds`,
  `spawnCount`, and `biome` are fabric fields — GDScript reads them from
  `GameData.CREATURES`, not from hardcoded constants ✓

**Known simplifications deferred to later:**
- Pack / herd behavior (creatures alerting nearby allies)
- Taming (`tame` behavior modelled in fabric but not wired when this phase
  landed; wired in Phase 35)
- `NavigationAgent3D` path-finding — movement currently uses direct kinematic
  stepping; a proper nav-mesh baked from the voxel terrain and
  `NavigationAgent3D` per creature instance will be added in a later phase

---

## Phase 16 — Station-gated crafting and tool durability ✅ Done

**Goal:** Close two long-standing "Known simplifications": enforce crafting
station requirements and give tools a durability lifecycle.

**Newel dependency:** None. Station tags already exist on recipes via the
`station` field in each recipe's structured `recipe` json; durability state
machines are in the item fabric (`pristine → worn → damaged → broken`).

**Deliverables:**
- `src/world/station_slice.gd` — tracks placed crafting stations (forge, master
  forge, arcane forge, alchemy bench, carpentry bench, masonry bench,
  void-shielded workshop) as world entities; exposes
  `nearest_station(pos, type, radius)` for the crafting gate check
- `src/crafting/crafting_slice.gd` — `craft` / `can_craft` check the recipe's
  `station` field against `station_slice`; surfaced in the crafting UI as a new
  block reason `station_required:<type>`
- Tool durability: `inventory_slice.gd` tracks durability per item;
  `use_item` decrements durability by action type; `broken` tools block their
  action and emit `item_broke` on the bus
- `src/ui/ui_slice.gd` — durability bar per tool in the inventory window;
  crafting rows show station requirement inline
- `src/tests/test_suite.gd` — tests for station gate (blocked without station,
  allowed when nearby), durability decrement, and item-broke signal

**Acceptance criteria:**
- Recipes with `station` cannot be crafted without a nearby station ✓
- Tool durability decrements on use and breaks at 0 ✓
- Broken tools cannot be used until repaired ✓
- Station requirement visible in crafting UI ✓
- All new automated tests pass ✓

**Known simplifications deferred:**
- Station placement UI (stations currently spawned via console/test harness)
- Per-instance durability: stacks of a durable item share one durability value
  (the inventory models item_id → quantity, not per-slot item instances)

---

## Phase 17 — Chunk streaming and world expansion ✅ Done

**Goal:** Replace the fixed 32×32 chunk with a streaming world so players can
explore beyond the starting area and encounter resource distribution that makes
the gather→craft→build loop meaningful at scale.

**Newel dependency:** None.

**Deliverables:**
- `src/terrain/chunk_manager.gd` — loads/unloads `VoxelSlice` chunks as the
  player moves; view distance configurable (default 3 chunks); `chunk_loaded` /
  `chunk_unloaded` signals on the bus
- `src/terrain/terrain_slice.gd` — world coordinate system: chunks addressed by
  `(cx, cz)` int pair; biome assignment is now per-chunk, seeded by `(cx, cz)`
  so biome borders are stable across sessions
- `src/persistence/persistence_slice.gd` — per-chunk voxel edit storage; only
  dirty chunks written to disk; save slot stores a chunk manifest
- `src/creature/creature_slice.gd` — creature spawn budget per loaded chunk; on
  chunk load, spawn quota creatures at biome-appropriate positions; despawn on
  chunk unload if not engaged
- Minimap stub: `src/ui/minimap.gd` — top-down 2D overlay showing loaded chunks,
  biome color-coding, and player position

**Acceptance criteria:**
- World chunks load/unload as player moves; no visible pop-in within view distance ✓
- Biome assignment is stable (same seed, same coordinate → same biome) ✓
- Voxel edits in one chunk do not affect adjacent chunks ✓
- Creature populations scale with loaded area ✓
- Minimap renders loaded chunk outlines and player dot ✓
- Save/load round-trip preserves edits across all visited chunks ✓

---

## Phase 18 — Multiplayer world sync (core) ✅ Done

**Goal:** Promote the ENet plumbing (Phase 10) to a real authoritative
host/client model so two or more players share the same world state.

**Newel dependency:** None. Character sync spec is already drafted in
`characters.md`.

**Deliverables:**
- `src/networking/networking_slice.gd` — full rewrite: host runs authoritative
  simulation; clients send input packets, receive world-state deltas; RPCs for
  `player_moved`, `block_changed`, `creature_state_changed`, `inventory_delta`
- `src/core/game_root.gd` — boot path branches on host vs. client; clients defer
  slice initialization until the host sends the initial world snapshot
- `src/player/player_slice.gd` — remote player ghosts: `CharacterBody3D` driven
  by interpolated snapshots rather than local input
- `src/terrain/voxel_slice.gd` — block edits validated server-side; clients
  receive authoritative `block_changed` events and apply them locally
- `src/creature/creature_slice.gd` — creature AI runs on host only; client
  receives state broadcast (position + state enum) at a fixed tick rate
- Dead-reckoning for player movement; rollback for mining/placing (reject if
  server disagrees within 200 ms)

**Acceptance criteria:**
- Two clients on localhost share terrain, inventory events, and creature state ✓
- Block mines/places are authoritative (server rejects conflicting edits) ✓
- Remote player ghosts render with < 100 ms interpolation lag at 60 Hz ✓
- Save snapshots are host-side only; clients re-sync on reconnect ✓
- All single-player automated tests still pass (host mode = single-player mode) ✓

**Implementation notes:**
- Authority is per-slice via an `is_authoritative` flag (default true = host /
  single-player). A client sets voxel, creature, and creature-AI slices to
  non-authoritative, so edits are forwarded as `block_edit_intent` and applied
  only from the host's `block_changed`; creatures are seeded from host state
  broadcasts rather than spawned locally.
- Block-edit authority uses forward-and-apply rather than optimistic prediction
  + rollback: a client never mutates terrain locally, so there is nothing to
  roll back — it applies the host's authoritative result. This is a strict
  superset of the 200 ms reject guarantee (conflicting edits never happen
  client-side). Dead-reckoning is implemented as snapshot interpolation in
  `PlayerSlice` (`GHOST_INTERP_TIME = 0.1 s`).
- Client role is selected via `godot -- --client <addr>`; without args the game
  boots as a host (single-player mode unchanged).

**Known simplifications (deferred to Phase 19):**
- No packet-loss simulation or jitter tolerance — only tested on a clean loopback
  connection where delivery is guaranteed and latency is near-zero.
- No network-condition emulation tooling.

---

## Phase 19 — Multiplayer chaos resilience ✅ Done

**Goal:** Harden the Phase 18 authoritative model against real network
conditions: jitter, packet loss, reordering, and abrupt disconnects.

**Newel dependency:** None.

**Deliverables:**
- `src/networking/networking_slice.gd` — configurable network emulator layer:
  artificial jitter (`emulator_jitter_ms`, ±N ms), packet-loss rate
  (`emulator_loss_rate`, 0–30 %), and out-of-order delivery
  (`emulator_reorder`), all gated behind an `emulate_network` export flag that
  is disabled by default (zero overhead in production)
- Jitter buffer for incoming remote-player snapshots (`jitter_buffer_ms`): hold
  N ms of snapshots and interpolate between them on a fixed playback delay;
  configurable buffer depth
- Sequence-numbered packets with gap detection (`_dedup`): duplicate and
  out-of-order packets discarded gracefully, forward gaps logged not blocking
- Disconnect / reconnect cycle: host persists last-known player state
  (`remember_player_state` / `get_last_known_states`); rejoining client
  receives a full world snapshot and resumes from last authoritative position
- Snapshot chunk reassembly made idempotent so emulator re-delivery cannot
  corrupt a chunked world snapshot
- `src/tests/test_suite.gd` — 9 new tests: seq monotonicity, duplicate /
  out-of-order discard, emulator loss rate, jitter bounds, zero-overhead when
  disabled, jitter-buffer interpolation, and reconnect inventory / last-known
  state

**Acceptance criteria:**
- Gameplay remains playable at 15 % packet loss and ±50 ms jitter on localhost
  simulation ✓
- No inventory duplication or block-state desync after a reconnect cycle ✓
- Network emulator layer adds zero overhead when disabled ✓
- All Phase 18 acceptance criteria continue to hold ✓

**Implementation notes:**
- All outbound traffic flows through `_deliver(peer_id, payload)`, which
  attaches a monotonic `seq` and either sends immediately (emulation disabled)
  or routes through the emulator queue (`_pending`, drained by `_process`).
- Loss / jitter / reorder are pure decisions (`_should_drop`,
  `_jitter_delay_ms`, `_maybe_reorder`) over a seedable `RandomNumberGenerator`
  so the unit tests are deterministic.
- The emulator and jitter buffer only run when `emulate_network` is set — the
  disabled path adds no queue, no timer, and no RNG roll.
- `remote_player_state` on a client is buffered and replayed on a fixed
  `jitter_buffer_ms` delay when emulation is on; otherwise the Phase 18 path
  is unchanged.

**Known simplifications (deferred):**
- Wide-area network (WAN) testing — all validation is loopback or LAN.
- Bandwidth cap / throttle budgeting for snapshot deltas.
- The 15 %-loss / 10 s no-desync scenario is covered by deterministic unit
  tests of the loss, dedup, and jitter-buffer mechanisms; a live two-instance
  loopback soak test is not yet automated.

---

## Phase 20 — Skeleton rig and animation ✅ Done

**Goal:** Bring the animation spec from `characters.md` to life: a rigged
humanoid skeleton with a locomotion decision layer driven by the player
controller's real speed every frame, with per-family facing rate (`turnSpeed`)
sourced from the fabric.

**Newel dependency:** None. Animation spec is complete from Phase 7.

**Deliverables:**
- Base humanoid skeleton rig (`CharacterBody3D` + `Skeleton3D`) with standard
  bone hierarchy matching the `SkeletonDefinition` taxonomy in `characters.md`
- `src/character/character_slice.gd` — wires fabric `GameData.CHARACTERS`
  (skeletons, appearances) to runtime `MeshInstance3D` + `Skeleton3D`
  construction; exposes `apply_equipment(slot, item_key)` and
  `clear_equipment(slot)`
- Socket attachment system: equipment meshes attached at named sockets; SKINNED /
  RIGID / HYBRID deformation modes
- A locomotion decision layer (`characters.md` §37) — state machine
  (`idle / walk / run / fall / land / attack / death`) plus a continuous
  idle↔walk↔run blend curve — driven by the player controller's real speed
  every frame; a real `AnimationTree`/authored clips are asset-production work
  this layer is designed to plug into, not yet built
- Approximate foot IK: terrain-sampled whole-body vertical offset (not a
  per-leg bone solver — see Known simplifications)
- Per-family `turnSpeed` facing: the body rotates to face its movement
  direction at a fabric-defined rate instead of snapping or strafing

**Acceptance criteria:**
- Player character animates through idle → walk → run transitions based on speed ✓
- Attack and death animations play on the correct bus signals ✓
- Foot IK keeps feet approximately flush with terrain (whole-body offset, not
  per-leg placement — see Known simplifications) ✓
- Socket-attached equipment deforms correctly in SKINNED mode, stays rigid in
  RIGID mode ✓

**Implementation notes:**
- `src/character/locomotion.gd` — a pure, headless-testable locomotion state
  machine (`IDLE / WALK / RUN / FALL / LAND / ATTACK / DEATH`) mapping horizontal
  speed → state with timed attack/land one-shots and a terminal death state. A
  real `AnimationTree` would consume `get_state()` + `get_blend_weight()` to pick
  and blend skeletal clips — no such node exists yet; the decision logic lives
  here so transitions are unit-testable without a renderer.
- `src/character/skeleton_rig.gd` — builds a real `Skeleton3D` from the fabric
  `SkeletonDefinition` (`bones` ordered chain, parents precede children), reading
  `restPose`, `bodyShapeCoefficients`, and `turnSpeed` from the resource (not
  hardcoded) and scaling each bone's rest offset per its bone group (legs by
  `legLength`, arms by `armLength`, head by `headScale`, etc. — `characters.md`
  §8) instead of a single uniform height factor. Resolves sockets → bones
  (§5) and attaches equipment with deformation modes (§10): SKINNED/HYBRID
  follow the socket's bone via `BoneAttachment3D`, RIGID stays a rig-root child.
  `SkeletonRig.compute_landmarks()` centralizes the body-shape math (torso
  height, hip height, hand/socket offsets, leg reach) so the placeholder mesh,
  socket offsets, and foot IK all derive the same landmarks from one source
  instead of three independently-drifting copies.
- `character_slice.gd` now assembles every character with a `Skeleton3D` rig,
  exposes `apply_equipment(slot, item_key)` / `clear_equipment(slot)`, drives the
  per-instance locomotion state machine, and emits `character_state_changed`.
  `sync_player_avatar()` binds the player's own visual avatar to the real
  `PlayerSlice` controller every frame — position, facing (turnSpeed-limited
  rotation toward horizontal velocity), locomotion state, and foot IK — instead
  of the avatar spawning at a fixed offset and never moving. `game_root` forwards
  the player's combat (`combat_round_requested`) and death (`player_died`) into
  `character_attack_requested` / `character_death_requested`.
- Foot IK (`SkeletonRig.compute_foot_targets`) samples terrain under both feet
  and clamps each to the terrain surface within leg reach — pure and
  headless-testable against a `Callable` terrain sampler. `sync_player_avatar`
  uses the higher foot to offset the whole body vertically (not a per-leg
  solver — see Known simplifications) and stashes both foot targets as root
  metadata for a future real IK pass to consume.
- Body (chest/legs, or the generic non-humanoid body box) and head are skinned
  to the skeleton via `BoneAttachment3D`, so they deform with the bone chain.
  Hair and beard remain rig-root placeholder `BoxMesh` children (not bone-
  attached) pending real mesh + `Skin` asset production.

**Known simplifications (deferred to Phase 22):**
- Palette and material system not yet wired (placeholder albedo only).
- LOD simplification not yet applied (full-detail mesh at all distances).
- No blend-shape facial customization.
- No authored animation clips / `AnimationPlayer` / `AnimationTree` playback —
  the state machine and blend curve drive transitions and cross-fade weights,
  but no clip data or blend-tree node exists; that is asset-production work.
- No root motion — the player controller drives `CharacterBody3D.velocity`
  directly from input, not from extracted animation displacement.
- Foot IK is a whole-body vertical offset from the higher sampled foot, not an
  independent per-leg two-bone solver; legs do not visibly bend to match
  terrain slope.
- No sheathe/draw clips, dual-wield/two-handed upper-body layer, or emotes yet
  — `characters.md` §37.6–§37.8 specify the intended design, not a built
  system.

---

## Phase 21 — Asset separation and public placeholders ✅ Done

**Goal:** Keep production art private while the public repo clones and runs
clean. A private asset submodule (Git LFS) is packed into a `.pck` that mounts
over `res://` at startup and replaces the committed placeholders — the same
mechanism that will carry paid DLC packs later.

**Newel dependency:** None.

**Deliverables:**
- Production art lives in a private repo (`project-nihon-assets`), added to this
  repo as the `assets-prod/` git submodule (HTTPS remote, so
  `--recurse-submodules` doesn't require SSH credentials); large binaries are
  tracked with Git LFS inside that repo, which also carries a `.gdignore` so
  Godot's scanner never touches it in place.
- `assets/` — ugly placeholders committed at canonical `.raw`-suffixed paths
  (`assets/textures/placeholder_character.png.raw`) so a public clone resolves
  every asset reference with no missing-resource errors. The `.raw` suffix
  keeps Godot's importer from claiming the file, so its bytes survive a real
  export and are readable via `FileAccess` — a plain `.png` would not be.
- `tools/build_pck.sh` — stages a plain copy of `assets-prod/` into a
  disposable pack-only project (`tools/pack_project/`) and calls Godot's own
  exporter (`godot --export-pack`) over it, producing `assets.pck` with
  entries under `res://_overlay/…` (a `.pck` is the unit of optional
  content — the DLC monetization model). Exits non-zero on any packing
  failure — there is no separate custom packer script to silently swallow one.
- `export_presets.cfg` — "Linux"/"Windows Desktop" presets exclude both
  `assets-prod/*` and `_overlay/*` from the shipped game, splitting the
  public/Steam build from the private-asset-adjacent build tooling.
- `src/core/asset_overlay.gd` (autoload) — mounts `assets.pck` over `res://` at
  startup; `resolve_path(rel)`/`load_texture(rel)` prefer the mounted
  `res://_overlay/<rel>` override, falling back to the public placeholder at
  `res://assets/<rel>`. `character_slice.gd` is wired to `load_texture()` as
  the first real runtime consumer.
- `tools/gen_placeholder.py` — deterministically regenerates placeholder art.
- Build policy: Steam/release bundles `assets.pck` (mounted from next to the
  binary); the public/GitHub build ships placeholders only.
- No code references a private-only path — production art is addressed only via
  the public `res://assets/…` prefix and the pack's own `res://_overlay/…`
  namespace, both safe to ship; `_test_asset_no_private_paths_hardcoded`
  recursively scans `src/` to enforce this.

**Acceptance criteria:**
- A fresh `git clone --recurse-submodules` of the public repo opens and runs in
  Godot — placeholders present, no missing-resource errors ✓
- Production art is absent from the public repo (only the submodule pointer) ✓
- `assets.pck` is gitignored and never committed ✓
- `_test_asset_pck_round_trip_override` builds a fixture pck with `PCKPacker`,
  mounts it, and asserts the override is actually served — not just that the
  relevant constants look right ✓

Resolved: the import-pipeline limitation described in earlier drafts of this
phase (raw overlay files not working for recognized resource types) is fixed
by the `.raw` suffix convention above, rather than deferred to Phase 22. See
`assets/README.md` for the full mechanism.

---

## Phase 22 — Material and palette pipeline ✅ Done

**Goal:** Implement the pixel-art material system from `characters.md`: Primary /
Secondary / Accent masks, Metal + Emission + Wear channels, and per-instance
palette swaps without extra draw calls.

**Newel dependency:** None. The palette was already authored in the fabric
(`GameData.PALETTES`, one `DefaultPalette` with 256 hex entries).

**Deliverables:**
- `src/character/character_material.gdshader` — a custom spatial `ShaderMaterial`
  that samples a shared `256×1` palette texture by per-instance colour index.
  Primary / Secondary / Accent regions are driven by a `color_mask_tex`
  (R/G/B); Metal / Emission / Wear channels are driven by a `channel_tex`
  (R/G/B), each max()'d with a per-instance scalar so the placeholder build
  (no authored masks) still works — scalars now, authored masks later, one
  shader.
- `src/character/character_material.gd` — builds the shared palette
  `ImageTexture` (256×1, no mip-maps) and ONE shared `ShaderMaterial`, and
  exposes `set_index` / `get_index` for per-instance palette swaps (§20) via
  `set_instance_shader_parameter`.
- `src/character/character_slice.gd` — `_make_box` / equipment assembly now
  reference the shared `ShaderMaterial` and write per-instance palette indices +
  channel scalars instead of a per-part `StandardMaterial3D` albedo tint;
  `get_part_material`, `get_part_shader_parameter`, `get_palette_texture`, and
  `apply_palette_index` expose the pipeline to tests and tooling. Metal tones
  resolve to a metals-region palette index (§21, region bounds read from the
  generated palette's `regions` field); wear derives from the durability tiers
  (§23); emission resolves a palette index in the emission region from the
  per-item `emissionColor` field (§22); roughness varies by metal tone + wear
  (§21).
- Pixel-art texture constraints enforced on the shader's samplers
  (`filter_nearest`, `repeat_disable`, no mip-maps) rather than import presets —
  Point filtering is guaranteed independent of per-machine texture-filter
  settings.
- `characters.md` extended with §41.1 production checklist sign-offs:
  resolution table, Point filtering settings, UV mapping guide.
- `src/tests/test_suite.gd` — 5 new tests: shared 256×1 palette texture,
  palette-swap shader-parameter round-trip, shared shader resource, wear
  derived from durability, and palette-driven metal channel.

**Acceptance criteria:**
- Palette swap changes character color without creating a new texture asset ✓
- Two characters with different palettes share ONE `ShaderMaterial` + palette
  texture (per-instance shader parameters, no new material per character) ✓
- Parts with identical geometry share ONE `BoxMesh` per distinct size ✓
- Pixel-art textures render without bilinear blurring (Point filter enforced on
  the shader samplers) ✓
- Wear channel visually degrades equipment as durability decreases (wear derived
  from the §23 durability tiers) ✓

**Implementation notes:**
- The palette lives in `GameData.PALETTES` (tag `palette`), not
  `GameData.CHARACTERS` — the earlier roadmap draft named the wrong group. The
  fabric `DefaultPalette` is fixed at 256 entries and `_color_index` /
  `CharacterMaterial._idx` clamp indices to `[0, 255]`, so the one-byte palette
  cap (§19) holds without a generator change.
- The placeholder build authors no mask textures, so `color_mask_tex` and
  `channel_tex` default to black: parts render their `base_index` colour and
  channels fall back to the per-instance scalars. A real asset binds a mask
  texture and the same shader composites it — the pipeline is the point, not
  the placeholder art.

**Known simplifications (deferred to Phase 23):**
- LOD mesh switching not yet tied to this material system.
- Emission colour is palette-driven (per-item `emissionColor` index) but static;
  dynamic glow (e.g. enchantments) deferred.
- Authored mask textures (Primary/Secondary/Accent/Metal/Emission/Wear) are not
  yet produced — the placeholder drives colour through per-instance scalars.
- The fragment shader mixes palette samples and multiplies by the detail texture
  and wear desaturation in continuous RGB space, so the rendered colour can
  drift off-palette (§19); snapping the output to the nearest palette entry is
  deferred.

---

## Phase 23 — LOD and composition simplification ✅ Done

**Goal:** Apply the `minLodLevel` attachment rules from `characters.md` so
character rendering scales gracefully with draw distance and player count.

**Newel dependency:** None.

**Deliverables:**
- `src/character/character_slice.gd` — LOD manager: at runtime, evaluate each
  `CharacterBody3D`'s screen-space size or world distance and set the active LOD
  level (0 = full, 1 = medium, 2 = impostor)
- Per-attachment `minLodLevel` respected: accessories and high-poly details hidden
  at LOD 1; full socket set collapsed to body-only at LOD 2
- Simplified meshes at distance > 20 m (LOD 1 threshold) and > 60 m (LOD 2 /
  impostor billboard)
- Impostor billboard: a camera-facing coloured quad rendered in place of the full
  rig at LOD 2 (a placeholder for the deferred pre-baked sprite, see below)
- `src/tests/test_suite.gd` — tests: LOD level transitions at distance thresholds,
  attachment visibility toggling, impostor swap correctness

**Acceptance criteria:**
- Full-detail rig renders within 20 m; simplified mesh between 20–60 m; impostor
  beyond 60 m ✓
- `minLodLevel` attachments are hidden at their specified threshold (no earlier) ✓
- Impostor billboard uses the correct palette for the character instance ✓
- Frame time with 20 remote characters at 60 m is measurably lower than 20 full
  rigs ✓ (delivered by the impostor swap — 20 rigs collapse to 20 flat
  billboards; not benchmarked headless, see Implementation notes)

**Implementation notes:**
- LOD levels collapse to the Phase 23 three-tier model (0 = full, 1 = medium,
  2 = impostor); `MAX_LOD` is now 2 and `IMPOSTOR_LOD` is 2. The `characters.md`
  §35 table's LOD3 (extreme distance) folds into the impostor tier.
- Per-part LOD is stored as `max_lod` — the COARSEST level at which a part still
  renders (`node.visible = lod <= max_lod`), so the name reads as a max, not a
  min. Fine detail (hair, beard) is `max_lod` 0 (hidden at LOD 1); coarse body
  geometry is `max_lod` `MAX_LOD` (visible through the impostor tier). The fabric
  `minLodLevel` field carries the same "coarsest level" semantics on the old 0–3
  scale and defaults to `MAX_LOD` when absent.
- `CharacterSlice.update_lod(viewer_pos)` switches to distance-driven (`LOD_AUTO`)
  evaluation and is called every frame from `game_root._process` with the player
  position. `set_lod(level)` applies a manual level immediately (`LOD_MANUAL`)
  for the test suite and debug tooling, but it is NOT a persistent override — the
  next `update_lod` call re-asserts distance-driven mode. `lod_level_for_distance()`
  is the threshold function (≤20 m → 0, ≤60 m → 1, else 2) with a `LOD_HYSTERESIS`
  (2 m) dead-zone: dropping to a finer level only commits once inside the margin,
  preventing boundary flicker. `_apply_lod` early-outs when neither the resolved
  level nor the hideRegions hidden set changed since the last frame.
- The impostor is a camera-facing `QuadMesh` (`billboard_mode` enabled, unshaded)
  tinted to the character's skin palette colour via `palette_color()`. The colour
  is resolved ONCE at creation (a baked colour), so a palette-texture swap is NOT
  reflected here — a true pre-baked sprite impostor is deferred (see below). The
  quad mesh is cached by size and the material by skin colour. `_apply_lod` shows
  the impostor and force-hides every part at `IMPOSTOR_LOD`, regardless of each
  part's `max_lod`.

**Known simplifications (deferred):**
- LOD mesh generation is manual (artist-authored); no automatic mesh decimation.
- Pre-baked sprite impostor — the billboard is a coloured-quad placeholder, not a
  pre-baked render of the rig; palette-swap applied to the billboard texture and
  runtime re-bake on palette change are deferred.
- No per-platform LOD bias (mobile vs. desktop thresholds are identical).

---

## Phase 24 — Social systems and player economy ✅ Done

**Goal:** Ground the `CommunityOwnsTheFuture` and `EconomyIsPlayerDriven`
constitution principles in real game mechanics: trade, social skills, and
community governance hooks.

**Newel dependency:** None. Social skill tree already defined in
`fabric/gameplay/skills/social.js`.

**Deliverables:**
- `src/trade/trade_slice.gd` — player-to-player trade: propose trade (items +
  quantities), counter-offer, accept/reject; secured via host authority in
  multiplayer; emits `trade_completed` on the bus
- `src/world/market_slice.gd` — persistent world market: players list items at
  a price; other players browse and buy; listings expire after configurable
  duration; market data is part of the world save snapshot
- Social skill effects wired: `Trade` skill tier sets the trade broker fee;
  `Leadership` unlocks guild formation; `Lore` unlocks advanced wiki entries
- `src/governance/proposal_slice.gd` — in-game proposal system mirroring the
  constitution's `CommunityOwnsTheFuture` principle: players submit proposals,
  others vote within a window; ratification requires a quorum of distinct voters
  and a threshold fraction in favour (authors cannot self-vote); accepted
  proposals emit a fabric decision event (the fabric decision state machine:
  `proposed → accepted → superseded`)
- UI panels for trade, market, and proposals wired into `ui_slice.gd`

**Acceptance criteria:**
- Two players can complete a trade; inventory reflects the exchange on both sides ✓
- Market listings persist across save/load ✓
- Social skill tier visibly affects a trade or leadership action ✓
- Proposal system allows submission, voting, and ratification; accepted proposals
  update a runtime decisions log ✓

**Implementation notes:**
- **Trade broker fee** is the concrete Trade effect: the local player's Trade
  tier determines the fraction of received goods withheld as a broker fee
  (fabric `TradeSystem.brokerFee`: novice 10% → master 0%). Diplomacy is scoped
  to NPC factions in the fabric and does not affect player-to-player trade.
  Balance numbers live in `fabric/gameplay/economy.js`, not hardcoded constants.
- **`Lore` skill does not exist in the fabric** — `fabric/gameplay/skills/social.js`
  defines only `Diplomacy`, `Trade`, `Speechcraft`, and `Leadership`. The
  `Lore`-unlocks-wiki hook is therefore deferred until a `Lore` skill is
  authored (see Known simplifications).
- **`Leadership` guild-formation gate** is implemented as
  `ProposalSlice.can_form_guild(tier)` (apprentice or higher). Guild formation
  itself (the guild entity, roster, permissions) is deferred — only the skill
  gate is wired.
- **No currency model exists yet.** Market `price` is an abstract numeric value
  recorded on the listing; a buy transfers the item to the buyer and removes
  the listing, but no currency changes hands. Currency exchange is deferred
  until the fabric defines an economy token.
- **Trade resolution is inventory-symmetric** via a pluggable party-inventory
  map (`set_party_inventory`): the local player uses `inventory_slice`; tests
  inject a second `InventorySlice` to model the remote side, so "both sides"
  exchange is asserted directly.
- **Market expiry** is wall-clock: `get_listings` filters by `expires_at` (a
  Unix-epoch timestamp, not process uptime), and a runtime tick calls
  `expire_listings()` to remove lapsed listings, refund their escrow to the
  seller, and emit `market_listing_expired`. The save snapshot carries
  `listed_at`/`expires_at`, so a restored listing keeps its real deadline
  across sessions. The default lifetime is fabric
  `MarketSystem.defaultExpirySeconds`.
- **Ratification** requires quorum + threshold + window (fabric
  `GovernanceSystem.ratification`: threshold 0.6, quorum 3, window 86400 s): a
  proposal ratifies only once at least `quorum` distinct voters have cast
  ballots within the voting window and the for-fraction reaches the threshold.
  The author cannot vote on their own proposal, so a single author cannot
  self-ratify. A ratified proposal records into the runtime decisions log and
  emits `proposal_ratified`.

**Known simplifications (deferred):**
- **Currency exchange** — `price` is metadata only; no economy token is
  transferred on buy/sell (no currency model in the fabric yet).
- **`Lore` skill** — not authored in the fabric; the "Lore unlocks advanced
  wiki entries" hook needs a `Lore` skill entity first.
- **Full guild system** — `can_form_guild` gates formation, but guild entity,
  roster, and permissions are not built.
- **Trade UI** — a single-player demo flow (a seeded merchant) lets a player
  start and complete a trade; a full two-player / NPC negotiation UI is still
  deferred.
- **Market listing escrow** — listings now escrow the seller's goods (debited on
  list, transferred on buy, refunded on expiry); a listing is still not an
  escrowed *currency* reserve because there is no currency model.
- **Delta-based state sync** — the market, governance, and trade slices
  broadcast their *full* state (`market_synced` / `governance_synced` /
  `trade_synced`) on every mutation. That is simple and correct for now, but a
  populated world will outgrow it — full-state broadcasts should be replaced
  with per-mutation deltas (or a dirty-field diff) once lists grow.
- **Per-peer inventory** — multiplayer has a single shared inventory: the host's
  `inventory_slice` is synced to every client (`inventory_synced` /
  `replace_contents`). Party identity is now peer-scoped (a client's
  "player" resolves to `peer_<id>` on the host, never the host's own
  inventory), so a remote client's market purchase / trade fails closed rather
  than crediting the host. Actually delivering to a remote player needs a
  per-peer inventory store + per-peer sync, which is still deferred.

---

## Phase 25 — Tool and equipment repair ✅ Done

**Goal:** Close the last Phase 16 "Known simplification": broken tools could not
be repaired. Repairable equipment now has a fabric-authored repair spec and a
runtime repair flow that consumes materials, gates on skill + station, and
restores the item to pristine.

**Newel dependency:** None. Reuses the existing `json` field type (already
emitted by `generator-godot`); no generator change needed.

**Deliverables:**
- `fabric/gameplay/items/shared.js` — a `repairData()` helper returning a
  structured `repair` json field: `{ station, materials: [{item, quantity}],
  skillGuards: [{skill, tier}] }`. This mirrors `recipeData()` and makes the
  repair cost a fabric value, not a GDScript constant.
- `fabric/gameplay/items/{tools,weapons,armor}.js` — every non-stackable
  equipment item gains a `repair` field transcribed from its prose `repair`
  behavior rules (e.g. FerritePick → `forge` + 1 FerriteIngot + Smithing novice;
  VeilsteelLongsword → `master forge` + 1 VeilsteelIngot + Smithing journeyman;
  AethermiteBow → `arcane forge` + ThornwoodPlank + AethermiteDust + ArcaneForging
  apprentice).
- `src/inventory/inventory_slice.gd` — `repair_item(item_id)` restores a held
  durable item's durability to its fabric maximum (pristine), failing closed for
  non-durable / un-held items.
- `src/crafting/crafting_slice.gd` — `repair(item_id)` / `can_repair(item_id)` /
  `get_repair_spec(item_id)`. Reuses the existing skill-guard and station-gate
  checkers (`_check_skill_guards` / `_check_station_gate`) so repair obeys the
  same fail-closed gates as crafting: `not_repairable` / `no_inventory` /
  `no_item` / `already_pristine` / `skill_requirement:<skill>:<tier>` /
  `station_required:<type>` / `missing_inputs`. Materials are consumed atomically,
  then durability is restored.
- `src/core/bus.gd` — `repair_requested(item_id)` / `repair_resolved(result)`
  signals.
- `src/ui/ui_slice.gd` — a "Repairs" section in the crafting window listing held,
  repairable, non-pristine items with a Repair button wired through the bus;
  `repair_rows()` is a pure, headless-testable projection.
- `src/tests/test_suite.gd` — 8 repair tests (spec load, restore-to-pristine,
  material consumption, skill guard, station gate, pristine rejection,
  non-durable rejection, broken-tool-via-bus).

**Acceptance criteria:**
- Repair cost/station/skill come from the fabric `repair` field, not hardcoded ✓
- A worn/broken tool is restored to pristine by consuming its repair materials ✓
- Repair obeys the same skill + station gates as crafting, fail-closed ✓
- A pristine item is not repairable (no wasted materials) ✓
- Repair is reachable through the bus (`repair_requested` → `repair_resolved`) ✓
- All 8 repair tests pass at startup ✓

**Durability model (final, do NOT revert):** the per-instance durability array
**is** the durable stack — `InventorySlice._durability[item_id]` holds one
entry per held instance, and its `.size()` is the held quantity. Non-durable
(stackable) items keep their count in `_contents`; durable items live ONLY in
`_durability`. There is no separate per-item shared value, so the earlier
"one shared value per item_id × stack_count" design must not be reintroduced
(repair cost and wear both derive from the per-instance array). Cross-slice
transfers use the static `InventorySlice.transfer(src, dst, counts)`, which
carries the exact removed per-instance values; `replace_contents` resolves a
durable item's array via `_worst_values` (keep the worst instances on a shrink,
pad a short payload with its carried value, warn + grant fresh when a payload
omits a durable item).

**Known simplifications (deferred):**
- **VoiditeEdge / VoidRuneTablet repair** — their prose repair rules reference a
  "refined voidite shard" (not modelled as an item/material) and gate on the
  VoidTouched profession (not wired). They carry no `repair` field and return
  `not_repairable` until those entities exist.
- **Per-condition-tier cost** — the fabric prose says e.g. "one ingot per
  condition tier restored"; the structured spec collapses this to a flat
  full-repair cost (restore straight to pristine for a fixed material spend).
- **AethermiteBow multi-tier repair** — the prose offers a separate string-only
  repair and a full stave repair; the spec models the full stave repair only.

---

## Phase 26 — Client-side rendering instancing ✅ Done

**Goal:** Collapse the per-entity scene-tree nodes and draw calls (one
`MeshInstance3D` + `StandardMaterial3D` + `Node3D` per creature / remote
player) into shared `MultiMeshInstance3D` renders so client rendering scales
with entity count instead of dying at a few hundred nodes.

**Newel dependency:** None.

**Deliverables:**
- `src/creature/creature_slice.gd` — creatures render through a single shared
  `MultiMesh` keyed by creature type. Each creature is one instance transform +
  a per-instance `COLOR` custom-data entry (the type tint, replacing the
  per-node `StandardMaterial3D` albedo). Death hides the instance (zero-scale
  transform) instead of `body.visible = false`; movement updates the instance
  transform instead of a `Node3D.position`. The `body` field in an instance
  record becomes an opaque `transform index`, not a live `Node3D`.
- `src/player/player_slice.gd` — remote player ghosts render through a shared
  `MultiMesh` (one instance per peer) rather than a `CapsuleMesh` node each.
- A `MultimeshPool` helper (or per-slice equivalent) that owns the
  `MultiMeshInstance3D` + material per entity type and maps instance index ↔
  entity id, so callers never touch raw `MultiMesh` internals.

**Acceptance criteria:**
- N creatures of one type produce ONE draw call (one `MultiMeshInstance3D`), not N ✓
- Per-type tint survives the swap (per-instance `COLOR`, no new material per creature) ✓
- Creature movement + death hide round-trip through instance transforms ✓
- Remote player ghosts share one `MultiMesh` ✓
- All existing creature/ghost tests pass unchanged ✓

**Implementation notes:**
- Per-instance colour uses `MultiMesh` custom-data (`INSTANCE_CUSTOM` →
  `COLOR`) with a single shared `StandardMaterial3D` whose
  `vertex_color_use_as_albedo` is on, mirroring the per-column vertex-colour
  terrain pattern (SKILL.md). This is the `MultiMesh` analogue of the Phase 22
  palette `instance uniform` — one material, per-instance data.
- The pool is the seam for the Phase 27 headless server: a headless server
  builds NO `MultiMeshInstance3D` (the pool is a no-op), so the same
  `creature_slice` data model drives both a rendered client and a bare sim.

**Known simplifications (deferred):**
- Creature animation (idle/walk cycles) via `MultiMesh` is not modelled — the
  current box placeholders are static; per-instance animation would need a
  `MultiMesh` custom-data shader or a per-type animation texture.

---

## Phase 27 — Headless data-oriented server ✅ Done

**Goal:** Decouple the authoritative simulation from rendering so a dedicated
server process can run the whole world — creatures, AI, combat, voxel, economy —
as plain data with no `SceneTree` visual nodes, no viewport, and no
`MeshInstance3D`/`Skeleton3D` construction. This is the structural change that
must land before the population grows, because every later scale feature
(spatial hashing, interest management, sharding) assumes the sim no longer
drags a render graph behind it.

**Newel dependency:** None.

**Deliverables:**
- A simulation/rendering split flag (e.g. `GameRoot.headless_server`) selected
  by a `--server` command-line arg. When set, `game_root` skips building the
  player avatar, character rigs, lighting, and environment, and does NOT spawn
  the local `CharacterBody3D` + camera.
- `creature_slice` stores entity state data-oriented (parallel arrays / a flat
  record dict with NO `body: Node3D`), and the Phase 26 `MultimeshPool` is the
  only renderer — null on a headless server. Movement/AI/death mutate the data
  record; a client-side pool mirrors it visually.
- `player_slice` remote-player state is pure data on the server (no ghost
  bodies); the client builds ghost `MultiMesh` instances from host snapshots.
- Server lifecycle: `--server` boots `networking_slice.host()` and runs the
  authoritative `_process` ticks (creature sync, market/proposal expiry,
  respawn) with no renderer — verified under `--headless`.

**Acceptance criteria:**
- `godot --headless --server` boots the full authoritative sim and reports the
  same `Results: N/N passed` without constructing a single visual node ✓
- A host client and a headless server drive identical creature/AI/combat state
  (same simulation, one with a renderer, one without) ✓
- Entity state no longer holds live `Node3D` references — `get_all_instances()`
  / `get_snapshot_creatures()` return pure data ✓
- Single-player and client renders are unchanged (the pool is the only visual path) ✓

**Implementation notes:**
- `--headless` (Godot flag) already drops the renderer; the work is making the
  *code* stop building visual nodes in headless mode — today
  `creature_slice._make_visual`, `player_slice._build_body`, and
  `character_slice` construct meshes unconditionally. The `MultimeshPool`
  (Phase 26) is the clean seam: guard its construction behind `not headless`.
- "Data-oriented" here means the entity record is a flat dictionary of
  primitives (position, state, hp, respawn_at) — no `Node`/`MeshInstance3D`
  fields — so a server holds millions of records as cheap arrays, not scene
  nodes.

**Known simplifications (deferred):**
- A true SoA (structure-of-arrays) `PackedVector3Array`/`PackedInt32Array`
  layout is not yet adopted — records are still dictionaries (contiguous enough
  for now, but a later SoA pass can drop per-record allocs).
- Server-side only: no client-auth/anti-cheat yet (a later hardening phase).

---

## Phase 28 — Spatial hashing ✅ Done

**Goal:** Replace every O(N) linear scan over the entity population
(`creature_slice.nearest_creature`, AI neighbour checks, combat target
resolution) with an O(1) spatial hash grid so query cost stops growing with
world population.

**Newel dependency:** None.

**Deliverables:**
- `src/core/spatial_hash.gd` — a grid keyed by cell coordinate (`floor(pos /
  cell_size)`), storing entity id → cell, with `insert` / `remove` / `update`
  / `query_radius(pos, radius)` / `nearest(pos)`.
- `creature_slice.nearest_creature` and `creature_ai` neighbour lookups route
  through the hash instead of iterating `_instances`.
- Re-hash on entity move (AI kinematic stepping updates the cell).

**Acceptance criteria:**
- `nearest_creature` cost is independent of total population (a populated grid
  returns the same nearest result as the linear scan, in ~O(radius²) cells) ✓
- Insert/update/remove keep the grid consistent with `_instances` ✓
- Pure projection is headless-testable (query correctness, cell boundaries) ✓

**Implementation notes:**
- `src/core/spatial_hash.gd` is a `RefCounted` grid keyed by `floor(pos.x /
  cell_size)` × `floor(pos.z / cell_size)` (2D XZ — the world is a
  heightfield). Cells hold an id→true set; a parallel `id → cell` map gives
  O(1) remove/re-hash, and `id → position` serves radius/nearest without an
  external lookup. `query_radius` scans only the cells overlapping the query's
  AABB and filters on full 3D distance; `nearest` doubles the probe radius
  until a candidate is found (cost bounded by local density, with a linear
  fallback for a pathologically sparse population). Default `cell_size` 8.0
  puts the 3 m attack range and most AI alert radii in a single cell.
- `creature_slice` keeps the hash in lockstep with `_instances`: `insert` on
  spawn and on client first-sight, `update` in `set_instance_position` (AI
  kinematic stepping) and `apply_creature_state`, `remove` in
  `despawn_for_chunk`. `nearest_creature` now iterates
  `_spatial.query_radius(...)` (dead-state filtered) instead of scanning the
  whole population — the O(N) → O(radius²)-cells win. `creatures_in_radius`
  is the public neighbour-query primitive the AI (pack/herd, deferred) will
  consume.
- The AI's per-frame `_process` still iterates `get_all_instances()` because it
  must tick *every* creature's state machine — that is an inherent O(N) tick
  loop, not a spatial query, so it is not routed through the hash. There is no
  creature-to-creature neighbour lookup in the AI yet (pack/herd behaviour is
  deferred from Phase 15); `creatures_in_radius` exists for when it lands.

---

## Phase 29 — Interest management (area of interest) ✅ Done

**Goal:** Stop broadcasting every entity delta to every client (the current
`_broadcast` / `_broadcast_creature_states` N×M blowup). Only entities within a
client's area of interest are sent, so network traffic scales with what each
player can actually see, not the whole world.

**Newel dependency:** None (builds on Phase 28's spatial hash).

**Deliverables:**
- Per-peer AOI: a radius (`networking_slice.AOI_RADIUS`, 96 units = 3 chunks)
  per connected client, keyed on the peer's last-known position (a freshly
  connected peer defaults to the spawn point).
- `networking_slice` filters creature/player/voxel broadcasts to peers whose
  AOI contains the entity — a client only receives state for nearby entities.
  Spatial deltas route through `_broadcast_aoi`; a `_peer_spatial` hash makes
  the interest query O(cells) instead of O(peers).
- The world snapshot a joining client receives is AOI-scoped (`_build_snapshot`
  filters creatures and players via `_scoped_creatures`), and a client moving
  into a new AOI grid cell triggers a re-scoped snapshot.

**Acceptance criteria:**
- A client receives creature/player deltas only for entities within its AOI ✓
- Network traffic grows with local density, not total world population ✓
- Deterministic headless tests: a far client receives nothing, a near client
  receives the delta ✓

**Known simplifications (deferred):**
- Economy state (market/governance/trade) is global, non-spatial replicated
  state and remains full-broadcast — every client needs the full market view.
- Re-scope granularity is one AOI grid cell (96 units), so entities entering
  AOI mid-cell appear on the next boundary crossing, not instantly.

---

## Phase 30 — Pack and herd behavior ✅ Done

**Goal:** Close the last creature-AI "Known simplification" deferred from Phase
15: creatures alerting nearby allies. Predator packs coordinate an attack;
prey herds stampede together — group tactics that make a lone wolf manageable
but a pack deadly, and a bison herd lethal when panicked.

**Newel dependency:** None. Reuses the existing `enum` and `decimal` field
types (already emitted by `generator-godot`); no generator change needed.

**Deliverables:**
- `fabric/world/creatures/shared.js` — a `GROUP_BEHAVIORS` enum
  (`none` / `pack` / `herd`).
- `fabric/world/creatures/temperate.js` — `GraywolfPack` gains
  `groupBehavior: 'pack'` + `packRadius: 20.0`; `SteppeBison` gains
  `groupBehavior: 'herd'` + `packRadius: 20.0`. Solitary creatures omit both
  fields entirely (the runtime treats an absent field as `none` / `0.0`).
- `src/creature/creature_ai.gd` — `_propagate_group_state` / `_escalate_neighbor`
  fire when a member enters a threat state: a **pack** shares `alert` +
  `aggressive` (a coordinated attack), a **herd** shares `fleeing` (a
  stampede). Propagation is same-species only, escalation-only (never
  downgrades a more-threatened neighbour), and non-recursive (bounded).
- `src/creature/creature_slice.gd` — pack/herd members **cluster** around a
  single deterministic pack centre at spawn (small per-index offsets) so their
  coordination actually fires in practice instead of spawning scattered out of
  `packRadius`. Solitary creatures keep their per-index scattered positions.

**Acceptance criteria:**
- A wolf detecting the player drags its pack-mates into `aggressive` ✓
- A bison fleeing below its threshold drags the herd into `fleeing` ✓
- A solitary creature (no `groupBehavior`) never drags a neighbour ✓
- `groupBehavior` / `packRadius` are fabric fields read from `GameData.CREATURES`,
  not hardcoded GDScript constants ✓
- 4 new automated tests pass at startup ✓

**Implementation notes:**
- `groupBehavior` is an enum field (stored as an int index in `.tres`:
  `0` none, `1` pack, `2` herd); `packRadius` is a `decimal` field. The AI reads
  both via `_group_behavior(res)` / `_pack_radius(res)` helpers that default to
  `GROUP_NONE` / `0.0` when the field is absent, so the eight solitary creatures
  need no field entries.
- Propagation lives in `_transition` (which now takes the triggering instance
  and a `propagate` flag): the *original* transition propagates to neighbours,
  but a propagated transition passes `propagate = false`, so a pack flood is
  bounded and longer chains resolve over subsequent frames as each member ticks.
- `_escalate_neighbor` escalates `idle → alert → aggressive` (pack) or any live
  state `→ fleeing` (herd) and never downgrades; dead/respawning neighbours are
  skipped.
- Pack/herd spawn clustering keys on the creature's `groupBehavior`; the pack
  centre is the existing `_deterministic_chunk_position(..., spawn_index = 0)`
  and members fan out by `_pack_member_offset(spawn_index)`, so spawn layout
  stays deterministic across runs.

**Known simplifications (deferred):**
- No inter-species coordination — a wolf pack never alerts a nearby bison herd,
  and vice versa (the fabric models each species as an independent group).
- No explicit "pack leader" role: any member can trigger the group; the fabric
  prose's "lead wolf dies → pack disbands" rule is not yet a distinct mechanic
  (a dead member simply stops propagating and the survivors keep coordinating).
- Group coordination is instantaneous; no signal-propagation delay or
  distance-falloff within `packRadius`.

---

## Phase 31 — Trees and resource appearance ✅ Done

**Goal:** Source wood materials from trees instead of the bare ground, and give
surface resources a distinct visual identity so the world reads as "mostly
plain dirt/rock with sparse, valuable veins" rather than a uniform resource
field.

**Newel dependency:** None. Reuses existing material entities (`Thornwood`,
`Duskfiber`); trees are a new world feature modelled in GDScript first, with a
fabric `world-system`/entity to follow once the runtime shape is settled.

**Deliverables:**
- `src/world/tree_slice.gd` — trees spawn deterministically per biome, derived
  from the chunk coordinate, species, and index, so a host and a client place
  the same trees with no snapshot. Density follows the biome prose: temperate
  forest 8 per chunk (weight 0.8), grassland 2 (isolated copses, 0.1), twilight
  grove 8 (Duskwood); the volcanic badlands and the void rift prose grants no
  conventional wood, so they grow none. Trees stand on the terrain surface like
  creatures and stream with their chunk.
- Chopping a tree yields its wood material (`Thornwood` / `Duskfiber`) into the
  inventory, replacing the removed ground-wood distribution (wood no longer
  mines from the ground — see Phase 12's `BIOME_MATERIALS`). A chop requires a
  held axe (the fabric discriminator `toolType: 'axe'`), spends one point of its
  durability, leaves a stump, and the stump regrows after a cooldown.
- Distinct visual treatment for resource veins: the common ground renders as
  plain dirt/rock, while rarer materials (Aethermite, Lumenfite, Voidite) are
  tinted and given a small raised/deposited shape (`vein_deposits()` in
  `voxel_slice.gd`) so a vein is recognizable from a distance.

**Acceptance criteria:**
- [x] `BIOME_MATERIALS` no longer lists any wood material (already true as of the
  map-improvements change; wood comes only from trees).
- [x] Chopping a tree yields its wood and the tree respawns on a cooldown.
- [x] A rare-material vein is visually distinguishable from the surrounding
  ground.

**Known simplifications (deferred):**
- Tree state is not persisted — a restart restores standing trees. Creature
  death/respawn persistence is Phase 33's work, and trees travel with it then.
- A tree's trunk collision exists to be an aim target, not an obstacle: the
  player still walks through a trunk (the player's `collision_mask` is
  untouched, which keeps tree spawning from needing spawn-clearance rules).
- Tree density and the regrowth cooldown are GDScript constants
  (`TREES_BY_BIOME`, `RESPAWN_SECONDS`) — they move to the fabric `world-system`
  entity the Newel-dependency note above describes.
- Resource deposits have no depth/quantity model yet (mining still yields one
  unit per `STEP_HEIGHT` slice).

---

## Phase 32 — One authoritative boot path ✅ Done

**Goal:** Make the host path a superset of the server path — `_boot_host()` calls
`_boot_server()` for the authoritative half, then layers local presentation
(player spawn, avatars, lighting, UI) on top. One authoritative boot means the
dedicated server and the listen host can never drift apart. Cheap and
mechanical; touches no gameplay.

**Newel dependency:** None.

**Why this is its own phase:** there were three boot paths and the authoritative
half was duplicated (the state this phase removed). `_boot_world()` branched:
client → `_boot_client()`, server → `_boot_server()`, else the host path was
inlined in `_boot_world()` itself (player spawn, chunk streaming, the demo craft
sequence, the save/load snapshot, `_networking.host()`). There was **no
`_boot_host()` function at all** before this phase; the drift is already visible
in code: the host path hardcoded
`_networking.host(_networking.DEFAULT_PORT, 1)` while `_boot_server()` passes
`DEFAULT_MAX_CLIENTS` (64). Until the server path is the single authoritative
boot, every Phase 33 persistence change has to be written and verified twice —
which is why this landed first, as its own commit.

**Deliverables:**
- Extract the inlined host path from `_boot_world()` into `_boot_host()`.
  `_boot_host()` calls `_boot_server()` for the authoritative half, then layers
  local presentation on top: player spawn, avatar/character visuals, lighting,
  HUD/UI, minimap, and the `DEBUG`-gated demo sequence.
- `_boot_world()` becomes a three-line role dispatch
  (`_is_client` → `_boot_client()`, `_is_server` → `_boot_server()`, else
  `_boot_host()`).
- Raise the default `max_clients` off 1: the host path passes
  `_networking.DEFAULT_MAX_CLIENTS` (64), not a literal `1`.
- Add a CI job to `.github/workflows/ci.yml` that boots `--server --headless`
  and asserts the server comes up clean.

**Acceptance criteria:**
- [x] `_boot_world()` contains no inlined host logic — it only dispatches.
- [x] A listen host and a dedicated server share the identical authoritative
  half (same `chunk_manager.start()` / `refresh()` + `networking.host()` calls).
  Both boots print the same line — `[Server] listening on port 7777,
  max_clients 64` — as the delivered record.
- [x] The host still renders: `render_visuals` is decided by `_is_server` in
  `_ready()`, so a host calling `_boot_server()` must still build the player,
  avatars, lighting, and UI. (Lighting was already behind `not _is_server`; the
  review that closed this phase found the minimap overlay and the UI slice were
  **not** — both were built on every role, dedicated server included — and moved
  them behind the same guard. Nothing clears them on a host.)
- [x] `max_clients` is 64 on the host path, not 1.
- [x] The new CI job fails on a `SCRIPT ERROR` / `Parse Error` / `Compile Error`
  in the server boot log (`.github/workflows/ci.yml` job `server-boot`), and
  additionally asserts the listening line is present rather than only that the
  boot failed to crash.
- [x] Headless suite count is unchanged (this step adds behaviours, not tests of
  the suite's existing assertions). 6695 passed before and after.

**Implementation notes:**
- **Order the authoritative half before the player spawn.** `_boot_server()`
  streams the chunk window around the *origin*; the host path places the player
  at the spawn point first and then refreshes so the window centres on spawn. A
  `_boot_host()` that calls `_boot_server()` first must therefore re-`refresh()`
  the chunk manager after spawning, or `_boot_server()` must expose its two
  authoritative steps separately. Do not silently regress the spawn-centred
  window — that is the Phase 17/31 behaviour.
- **`--server` is a *user* arg, so it goes after `--`.** `OS.get_cmdline_user_args()`
  returns only what follows the separator; the CI job must invoke
  `godot --headless --path . --quit -- --server`, not `--server` among the engine
  args (it would be silently ignored and the job would boot a host instead).
- **Assert positively, not just by absence of errors.** Today the server path
  prints no line on success, so the only assertable fact is the absence of
  `SCRIPT ERROR` / `Parse Error` / `Compile Error`. Add one boot line (e.g.
  `[Server] listening on <port>, max_clients <n>`) so the job can assert the
  server actually came up rather than merely failed to crash.
- Keep the CI job cheap: reuse the `godot-tests` job's Godot 4.7 download step
  and run `--quit` (without it the headless main loop never exits).

**Known simplifications (deferred):**
- The authoritative half is shared; the presentation layer is not. Only the host
  runs the `DEBUG`-gated demo sequence, the player spawn, and the visual build,
  so a dedicated server is authoritative but presentation-free — that is the
  intended Phase 27 sim/visual split, not a gap. Note the tail also holds the
  *unconditional* boot demos (mine + place, 4 Ashite, one combat round) and the
  boot save/load, and those mutate authoritative state — so the two boots share
  the same authoritative calls, not the same world state.
- `--server` gains no graceful termination hook here; the save-on-termination
  lifecycle is Phase 33's work.

---

## Phase 33 — Player identity and server-side persistence ✅ Done

**Goal:** Give each player a connection-independent id owning their inventory,
HP, position, and appearance, then write a real save lifecycle — load on server
boot, autosave, save on disconnect and shutdown. Today the dedicated server
(Phase 27) boots empty and discards the world: `_boot_server()` calls neither
save nor load, and every piece of player state is keyed on `peer_id`, which ENet
reassigns on every connection. Builds on Phase 32: by the time this phase starts
there is exactly one authoritative boot (`_boot_server()`), shared by the
listen host.

**Newel dependency:** `PlayerIdentityModel` — a new `decision` entity in
`fabric/constitution/decisions.js` (the ratified decision on whether identity is
a server-issued local UUID or an account-backed id). No generator change: the
`uuid` + `enum` field types and the `proposed → accepted → superseded` decision
state machine are already emitted. Run `pnpm validate` → `pnpm generate` →
`pnpm check-drift` after adding it.

**Deliverables:**
- Add a stable player id that survives reconnect; `peer_id` can't be the key.
  Mint a `player_id` on first join, persist it, and send it to the client so a
  reconnect re-binds to the same record (`networking_slice` keeps only the
  transport mapping `peer_id → player_id`).
- Make inventory per-player, preserving the Phase 25 per-instance
  durability-array invariant: a durable item's per-instance `Array` *is* the
  stack, and `get_durability_data()` / `replace_contents()` round-trip per
  player — no shared inventory across peers.
- Restore `player.position` and `player.hp` in `_on_load_completed` — the boot
  snapshot already writes both (`player` → `position` / `hp` in `game_root`),
  but load restores only inventory / technology / market / governance / trade.
- Add stations and creature state (deaths, respawn timers) to the snapshot.
  `station_slice` has no `get_station_data()` / `apply_station_data()` pair at
  all, and `creature_slice.get_snapshot_creatures()` carries only
  `{instance_id, creature_id, state, position}` — no `hp`, no `respawn_at`.
- Load the world in `_boot_server` — Phase 32's shared authoritative half — which
  currently calls neither save nor load (it only runs `chunk_manager.start()` /
  `refresh()` and `host()`). Loading there means the listen host inherits it.
- Autosave on an interval; save on peer disconnect.
- Save on shutdown: handle `WM_CLOSE_REQUEST` and `SIGTERM` — servers are
  killed, not closed, so the window-close path alone never fires. The WM-close
  half needs `get_tree().auto_accept_quit = false` before saving.
- Use the existing dirty-chunk tracking for incremental voxel saves, not full
  rewrites: `_on_save_completed` already calls `clear_dirty_chunks()`, so an
  autosave must rewrite only `get_dirty_chunk_keys()`'s manifests.
- Replace the single JSON slot with per-player records under a server save dir:
  `persistence_slice` writes one `user://saves/slot_NN.json` today; move to a
  world record (chunks / stations / creatures) plus one record per player under
  a server save dir, keeping `save` / `load_slot` working for the existing
  tests and the client-side legacy path.
- Ratify identity model (local UUID vs account) as a fabric decision entity:
  `PlayerIdentityModel` in `fabric/constitution/decisions.js`, accepted through
  the same decision state machine the other constitution decisions use.

**Acceptance criteria:** *(met — see the verification notes below)*
- [x] A restart round-trip (save → fresh boot → load) reproduces player
  position, HP, inventory with per-instance durability, stations, and creature
  death / respawn state.
- [x] Reconnecting with a new connection keeps the same inventory — the id
  survives the reconnect and the `peer_id` change.
- [x] A disconnect mid-craft leaves the inventory consistent after save: no
  half-consumed materials, no duplicated output.
- [x] A spoofed id is rejected — a client cannot claim or write into another
  player's record.
- [x] `_boot_server` loads the world on boot and autosave runs on its interval
  (host/authoritative only).
- [x] `pnpm validate` + `pnpm check-drift` clean (543 generated files match the
  manifest), headless suite green with the 4 new tests.

**Tasks / tests:**
- `identity: restart round-trip restores the world` — save → drop every slice →
  fresh slices → load: voxel edits (incl. the incrementally-merged chunk),
  station (id + type), creature state + wall-clock deadline, player position /
  HP / inventory durability / appearance recipe.
- `identity: reconnect keeps the inventory` — first join mints an id, disconnect
  drops the transport mapping, a NEW connection claiming the cached id re-binds
  to the same record and the same inventory.
- `identity: disconnect mid-craft stays consistent` — a craft, then the
  disconnect-time record write, then a restored inventory: exactly one craft's
  inputs consumed, the output present exactly once, the record equal to the live
  inventory.
- `identity: spoofed id is rejected` — a claim on a LIVE identity is refused and
  cannot read or write the victim's record; an unknown claimed id is discarded;
  a non-authoritative (client) registry mints nothing.

**Verification (headless, on this machine):**
- Suite: `6695/6695` before the phase → `6761/6761` after (the 4 new tests plus
  the two respawn tests moved to wall-clock deadlines).
- Dedicated server, no save: `[Server] no world record at
  user://saves/server/world.json — booting a fresh world` then
  `[Server] listening on port 7777, max_clients 64`.
- Listen host: writes `saves/server/world.json` +
  `saves/server/player_<player_id>.json`.
- Dedicated server again: `[Server] world loaded from …/world.json` and
  `[Server] restored 1 player record(s)`.
- Clean shutdown on a HEADLESS server (a signal cannot do this — see notes):
  with `user://shutdown_requested` present the server prints
  `[Server] shutdown requested — saving before quit`, writes
  `world saved (incremental) — 0 chunk manifest(s), 169 creature(s)`, deletes the
  request file and exits. `world.json`'s mtime moves; the process is gone.
- Identity handshake over a real socket (loopback, twice):
  `[Server] joined player 'player_1790181748_1_812e' as peer_506044089`, client
  caches `{"player_id": "player_1790181748_1_812e"}`, and on the second
  connection — a different peer id — `[Server] reconnected player
  'player_1790181748_1_812e' as peer_1148372338`. Two record files land in the
  save dir (the local player and the remote peer).

**Implementation notes:**
- **Respawn timers became wall-clock.** `creature_slice` used
  `Time.get_ticks_msec() + respawn_secs * 1000.0` — *process uptime*, so a saved
  deadline meant nothing after a restart. Deadlines are now Unix-epoch seconds
  (`Time.get_unix_time_from_system()`), matching the Phase 24 market/proposal and
  Phase 31 tree conventions. The two existing tests that faked an elapsed
  deadline with `get_ticks_msec()` were moved to the same clock (they had been
  passing *accidentally*: a ticks_msec deadline is always in the past for an
  epoch comparison).
- **`SIGTERM` cannot be intercepted by Godot 4.7 — verified, not assumed.** A
  probe (a throwaway project with a `_notification` print, run headless) showed
  the process dies on `SIGTERM` with **no** notification at all; `SIGINT` *is*
  caught but goes through the `auto_accept_quit` gate rather than reaching the
  scene tree. So the phase does all of: (a) `get_tree().auto_accept_quit = false`
  plus a `NOTIFICATION_WM_CLOSE_REQUEST` handler that saves then quits (the
  windowed path, authoritative roles only); (b) autosave on the fabric interval;
  (c) a polled `user://shutdown_requested` file that saves and quits — the
  headless shutdown hook, and the one the verification above exercises. The
  interval is what bounds the loss for a plain `kill -TERM`.
- **Creature instance ids are now deterministic** — `creature_<cx>_<cz>_<species>_<i>`
  instead of a `_next_id` counter. Persisting and replicating creature state by
  instance id makes the counter-id shape a correctness bug (a peer that streamed
  chunks in a different order named the same creature differently, and a chunk
  reload renumbered survivors): the same defect Phase 31 fixed for tree ids. An
  engaged creature kept alive across a despawn can still shift an index, so the
  state of a mid-fight chunk is not guaranteed to re-attach — noted in the
  function.
- **Load order in `_boot_server` matters.** Load the records, then
  `chunk_manager.start()` / `refresh()`, then re-apply the recorded creature
  state: `spawn_for_chunk()` builds fresh instance records and would otherwise
  wipe the restored death/respawn state.
- **Only the world-record save resets dirty-chunk tracking, and it does so by key.**
  `_on_save_completed` (the legacy `slot_NN` path) deliberately does not clear
  anything: the slot file is a single-file sample and not what a server loads, so
  letting it clear the dirty set dropped pre-slot edits from the next world save.
  The authoritative save clears exactly the keys it serialized
  (`clear_dirty_chunk_keys()`), because the write is off-thread (see the review
  notes below) — an edit made while the worker writes re-marks its chunk instead of
  being swallowed, and a FAILED write re-marks its keys (`mark_dirty_chunks()`).
- **Incremental saves carry only the dirty manifests.**
  `PersistenceSlice.dirty_chunk_subset(manifest, keys)` is the shared pure
  implementation (runtime + test), and `save_world(..., incremental)` merges it
  over the record on disk, so an autosave no longer re-serializes ~49 chunk
  manifests.
- **Id authority sits on the server.** The client presents a cached id at join;
  the host honours it only when it owns that record AND no live peer holds it —
  otherwise a fresh id is minted. That single rule gives both the reconnect
  re-bind and the spoof rejection. `resolve_identity` on a non-authoritative
  registry is a no-op, so a client can never mint.
- **Gate the lifecycle on `is_authoritative`.** A client neither loads a world
  nor autosaves; it receives state from the host (Phase 29's AOI-scoped snapshot
  stays the client's only view) and only caches its player id.
- **Writes are atomic.** `make_dir_recursive_absolute` + temp file + rename, so a
  kill during a save leaves either the old record or the new one, never a
  truncated file.
- Autosave interval, save-dir layout, record file names, the shutdown-request
  path and the atomic-write switch all live in the fabric `PersistenceSystem`
  (`fabric/gameplay/persistence.js`), not as bare GDScript constants.
- **`PlayerCharacter`'s per-player inventory is a registry-owned
  `InventorySlice`**; the local player's is the game's own `_inventory`
  (registered via `set_local_player`), which is what makes inventory per-player
  without touching any existing call site. `_build_snapshot` ships the CONNECTING
  peer's own contents instead of the host's, and `networking._peer_party` now
  resolves a client's `"player"` self-reference to its player id, so a peer's
  market/trade actions land on its own record — and keep landing there after a
  reconnect, which `peer_<id>` could not do.

**Known simplifications (deferred):**
- No account or auth service: identity is the server-issued local UUID the
  ratified `PlayerIdentityModel` decision lands on; account binding / login is
  out of scope.
- No world-shard handoff of a player record between servers — see Deferred →
  server sharding.
- Autosave is a plain interval timer; only ONLINE players' records are rewritten
  (an offline record cannot have changed), but a rewritten record is still whole —
  no field-level diffing.
- **Crafting is per-crafter now, not host-scoped.** `crafting_slice` resolves a
  recipe against `inventory_for(player_id)` — the PlayerRegistry's per-player
  inventory — so a remote peer's craft consumes and produces against ITS OWN
  persisted inventory. A client does not resolve crafts at all: it emits
  `craft_intent(recipe_id, "")`, the networking slice forwards it, and the host
  re-emits it with the identity it bound to that connection (`craft_intent`'s c2h
  arm refuses an un-handshaked peer and never trusts a payload-supplied id). Repair
  and technology research are still host-scoped: same plumbing, not yet moved.
- Appearance is persisted for the LOCAL player's record and rebuilt on boot;
  other players' appearances are not replicated to clients (clients still render
  their own avatar plus position-only ghosts).
- A headless server's clean shutdown needs the `shutdown_requested` file (or an
  autosave tick), because `SIGTERM` cannot be intercepted — see the notes above.

### Phase 33 — review fixes (durable state is not live state, twice over)

A post-implementation review of the branch found 19 defects. They cluster into
four shapes, each worth remembering:

- **A durable record treated as a live feed.** An incremental world save replaced
  the recorded `creatures` list wholesale, but the payload only carries the
  population the process holds (the streamed chunks), so a death in a chunk that
  was not in view was dropped — walk away from a corpse, save, walk back, and the
  creature was alive again. `PersistenceSlice.merge_creature_states()` folds the
  list per `instance_id`. Same shape twice more: a remote peer's position and HP
  were folded into its record only at disconnect (a hard kill restored it at the
  origin, at full health — they are folded on every autosave now, with
  `_last_known_hp` as the HP store), and `despawn_for_chunk` erased a dead
  creature outright so a chunk reload respawned it alive (`_dead_state` keeps the
  death, `_spawn` re-applies it, `get_snapshot_creatures` carries it, and the boot
  replay holds a death for an unstreamed chunk instead of skipping it).
- **A sentinel indistinguishable from a real value.** `apply_creature_state`'s
  optional `respawn_at` was assigned unconditionally, so the 4-argument per-tick
  delta wrote its `-1.0` default over a real wall-clock deadline and the creature
  never came back; `-1.0` now means "unchanged", exactly as `hp` already did.
  `get_last_known_state()`/`get_last_known_hp()` keep the `has_*()` discriminators
  for the same reason.
- **A credential that is not guessable.** `player_id` is a BEARER token —
  `resolve_identity` hands the record to whoever presents it — and it carried
  `randi() & 0xFFFF`: 65 536 guesses, brute-forceable in one connect flood. It is
  now 128 bits from `Crypto.generate_random_bytes(16)`, and `player_path()`
  SANITIZES the id before interpolating it into a filesystem path
  (`save_player`/`load_player` refuse a non-canonical id rather than silently
  reading a different record).
- **An authority gap on the local player.** A listen host never binds its own
  player to a peer id, so a peer-map lookup answered "offline" and
  `resolve_identity`'s rule — "the record exists and is not online" — handed the
  host's inventory and position to whichever client claimed the id first.
  `is_online()` counts the local player, and the id is refused explicitly.
  The spoof test now covers this third case (it had live-victim and
  never-issued, i.e. exactly the two claims that were already safe).

Plus the operational half:

- **The save no longer serializes on the main thread.** `_save_everything()`
  collects the payload (the part that reads live slice state) and hands a deep
  copy to a `Thread` running `PersistenceSlice.write_job()`, which does JSON +
  FileAccess with no signals and no node access. Dirty chunks are cleared by key
  at COLLECTION time (re-marked if the write fails), which is what makes the
  deferred clear exact; shutdown paths (`WM_CLOSE_REQUEST`, the polled
  shutdown-request file, `_exit_tree`) call `_flush_save()` so they cannot outrun
  their own write.
- **`file_exists(shutdown_request_path)` ran every frame** for a file written at
  most once — it is polled on the autosave tick now. The interval also falls back
  to 300 s when the fabric value is 0 instead of silently disabling the autosave
  (a headless server has no other save hook), and `dirty_chunks` was dropped from
  the world record: it was written and never read back.
- **Boot no longer loads every record on disk.** The registry never evicts, so a
  long-lived server held every player who had ever joined; a record is pulled in
  lazily by the claim that needs it (`set_record_loader`). The autosave writes
  only the ONLINE players' records for the same reason.
- **The reconnect snapshot was sent twice** (`peer_connected`, then
  `player_joined`) — and the first was the useless one, built before the identity
  existed so it carried no own-record. `send_snapshot` now has exactly two call
  sites: the handshake join and an AOI re-scope.
- **The atomic write has a documented limit**: temp file + rename is atomic
  against the PROCESS dying, but nothing is `fsync`ed, so a machine power loss can
  still lose the record. Godot 4.7 exposes no fsync, so this is stated rather than
  fixed.

Verification for this pass: headless host / `--server` / `--client` boots green at
`Results: 6894/6894 passed (0 failed)` (was 6776; +17 registered cases), a
throwaway-copy lifecycle probe with the cadence shortened to 1 s showing threaded
autosaves landing and a shutdown request consumed on the tick with the save
complete before exit, a real server+client pair showing `reconnected player
'<128-bit id>'` (the lazy load path over the wire), and a `send_snapshot` call-site
count of 3 → 2 against `HEAD`.

### Phase 33 — review pass 2 (a restart that waits, a failure that hides, a client that gives up)

A second review of the same branch found five more defects. Two are the same shape
as before ("a bound that is really unbounded"), one is a trust boundary in the
wrong direction, and two are lifecycle gaps:

- **The shutdown poll was gated behind the autosave tick.** The
  `shutdown_requested` file was only checked once `autosaveIntervalSeconds` (300 s)
  had elapsed, so a restart request sat unread for up to five minutes. An
  orchestrator that writes the request and `SIGKILL`s after a short grace period
  killed the server *before* it saved — losing up to a full autosave interval on
  every restart. The poll now has its own fabric cadence,
  `shutdownPollSeconds` (default 5 s), resolved exactly like the autosave interval
  (a non-positive value falls back rather than meaning "never notice a restart"),
  and `PersistenceSlice.poll_due()` is the shared rule behind both. It is still
  not a per-frame `FileAccess.file_exists()` — the "don't stat every frame" fix
  stands, only the latency bound changed from *the autosave interval* to *the
  shutdown poll interval*.
- **A failed save was discovered one interval late, after the edits were already
  un-marked.** Dirty chunks are cleared at COLLECTION time (that is what makes the
  deferred clear exact), and the only reaper ran at the *start of the next*
  `_save_everything()`. So a write that failed was reported up to 300 s later,
  while its chunks read as clean: in that window the edits looked saved and were
  not, and a process that died inside it lost them with no error at all.
  `_poll_save_completion()` now reaps the worker as soon as `Thread.is_alive()` is
  false — one bool per frame, reusing the single `_finish_save()` result path, so
  the failure and the dirty-chunk re-mark land within a frame.
- **The handshake was fire-and-forget.** The client sent `join_intent` once on
  `connected_to_server`. Lose that packet (or the snapshot that answers it) and the
  client sat connected with no identity, no world, and no way to ask again — the
  snapshot-pending timer just gave up after 10 s. The client now re-presents the
  intent (`NetworkingSlice.request_handshake()`) every `HANDSHAKE_RETRY_SECS` up to
  `MAX_HANDSHAKE_RETRIES`, and each retry carries a fresh `seq` so the receiver's
  dedup passes it. The host half was also broken: `resolve_identity` returned early
  for an already-bound peer *without* emitting `player_joined`, so a retry would
  have produced no snapshot at all — it now re-answers idempotently.
- **A remote peer's HP was client-declared AND persisted.** The host kept the HP
  it received in the peer's own `player_moved` packet and folded it into the
  durable record, so `hp: 9999` on the wire became 9999 HP across a reconnect, a
  restart, and every later save — persistence as a cheat engine. Only the LOCAL
  player's host-simulated HP may be written (`PlayerRegistry.record_hp` refuses
  anything else, via the pure `hp_is_authoritative_locally()`), the remote fold
  call site is gone, and the now-consumerless `_last_known_hp` store was deleted
  rather than left as write-only state. The honest trade: a remote peer's HP is no
  longer durable, so a peer hard-killed mid-session resumes at its last
  *host-authored* HP instead of its last declared one.
- **Records and inventory nodes were never evicted.** The registry only ever grew:
  every player who had EVER connected kept a record plus a live `InventorySlice`
  node for the whole session. Now that the record is durable on disk and the
  registry holds a loader, `PlayerRegistry.evict_player()` releases both on
  disconnect (never the local player, never an online one, and only a node the
  registry itself parented — the local player's is the game's own `_inventory`).
  The reconnect claim re-loads from disk, so eviction costs one read and loses
  nothing. Consequences handled in the same pass: trade/market hold a raw node per
  party, and a freed node is not null, so both gained
  `clear_party_inventory()` (called on disconnect) and a `_inventory_for()` that
  treats a freed binding as "no inventory"; `game_root._peer_aoi_regions` is
  cleared for the peer id too, so a reused ENet id cannot have its first re-scope
  snapshot suppressed.

Verification for this pass: headless host / `--server` / `--client` boots green at
`Results: 6940/6940 passed (0 failed)` (was 6894; 7 registered cases replaced 1),
a throwaway-copy `--server` probe that wrote `user://shutdown_requested` mid-run
exiting **5.3 s later** with `[Server] shutdown requested — saving before quit`
followed by a completed world save (the old code needed up to 300 s, so the same
probe would still have been running), and a real server+client pair whose client
was `SIGKILL`ed mid-session: the disconnect wrote the client's record, left no
`SCRIPT ERROR` / `previously freed` / `Invalid` line in the server log, and a later
`shutdown_requested` saved `world.json` plus both player records.

---

## Phase 34 — Per-player repair and research ✅ Done

**Goal:** Finish the per-player authority Phase 33 started. Two player-scoped
actions still resolve against the host's own state: `CraftingSlice.repair()`
reads `inventory_slice` directly, and `TechnologySlice` keeps ONE
process-wide status dictionary whose material cost also comes off
`inventory_slice`. So on a host a research unlocks the technology for every
player at once and spends the host's materials — a peer can hand the whole
server a free technology tree — and neither repair nor research has any wire
path at all, so a client's attempt dies on the client. Phase 34 keys both on
the server-issued `player_id`, forwards them as intents, and pushes the peer
its own record slice back when the host resolves one on its behalf.

**Newel dependency:** None. The technology tree, the repair specs and the player
identity all already exist in the fabric; this phase changes who *owns* the
runtime state, not what the fabric describes, so no `pnpm validate` /
`generate` / `check-drift` step is involved.

**Deliverables:**
- `TechnologySlice` becomes per-player: `_status` and `_research_end_at` keyed
  on `player_id`, `inventory_for(player_id)` from the PlayerRegistry, plus
  `is_authoritative`. Every API takes `player_id := ""`, where "" resolves to
  this machine's local player (`begin_research`, `complete_research`,
  `is_unlocked`, `is_recipe_unlocked`, `get_status`, `get_statuses`,
  `apply_statuses`).
- `CraftingSlice` repair becomes per-player: `repair(item_id, player_id)`,
  `can_repair(item_id, spec, player_id)` and `_resolve_repair(...)` — with
  `_condition_tiers_to_restore` / `_refund` — resolve against
  `inventory_for(player_id)` instead of a fixed `inventory_slice`.
- The craft technology gate asks about the crafter:
  `_check_tech_gate(recipe_id, player_id)`.
- Repair and research travel as intents: new `repair_intent(item_id,
  player_id)` / `research_intent(tech_id, player_id)` bus signals, a
  non-authoritative slice forwarding its own request signal as an intent (the
  shape `craft_intent` set), and `networking_slice` c2h arms that require the
  handshake and re-emit with the identity bound to the CONNECTION.
- The host hands the peer its own record slice back: a new host→client
  `own_state_synced` payload (inventory contents + per-instance durability +
  technology) sent by `networking_slice.send_own_state(peer_id, data)` to that
  peer alone, driven by `game_root._sync_peer_own_state` after a craft, repair
  or research the host resolved for a remote peer.
- Persist per player: `record_technology(pid, get_statuses(pid))` when a
  research resolves and on save, and the record's technology applied to the
  player's OWN bucket on join.
- Results and events name their player: `technology_unlocked(tech_id,
  player_id)`, plus a `player_id` on every craft / repair / research result.
- Seven new test cases (per-player research + craft gate, client research
  forwarding, per-player repair, client repair forwarding, intent identity
  binding, own-state push scoping, client research never auto-completes).

**Acceptance criteria:** *(met — see the verification notes below)*
- [x] One player's research consumes only THEIR materials and moves only THEIR
  statuses; another player's tree stays locked, and a prerequisite is per-player.
  (`technology: tree and materials are per-player`: alice researching moves her
  stack and her status, bob's `Ferrite` stays 4 and his status `locked`; bob's
  `TechMasterForge` answers `prerequisite_locked` until HE holds
  `TechBasicSmithing`, and two players then hold the same technology
  independently.)
- [x] A remote peer's repair consumes the repair materials from and restores the
  durability of ITS OWN inventory; the host's is untouched.
  (`repair: resolves against the repairer's inventory`: alice's pick goes
  `worn` → `pristine` and her `FerriteIngot` 3 → 2 while bob's stays worn at the
  same durability with all 3 ingots.)
- [x] A client never resolves a repair or research locally: it forwards an
  intent, and its own state changes only through the host's `own_state_synced`.
  (`technology: client forwards research intent`, `repair: client forwards
  intent, mutates nothing` and `technology: client does not resolve research`:
  one intent, an empty `player_id`, nothing consumed or restored locally — and
  the slice's own auto-complete tick is authority-gated, so a status restored
  mid-research never completes on the client's clock.)
- [x] An un-handshaked peer's repair / research intent is dropped, and a
  `player_id` inside the payload is ignored — the identity comes from the
  connection. (`net: player intents bind connection identity`: no signal before
  the handshake, then both intents arrive carrying `player_7_1_deadbeef`, the id
  bound to the connection, not the `player_victim` the payload named.)
- [x] `technology_unlocked` names the player whose tree moved, and the listen
  host's own UI does not report a remote peer's outcome. (`technology_unlocked`
  now carries `player_id`, and `UiSlice._belongs_to_local_player` gates the
  craft / repair / research feedback labels on it — including the repair
  feedback that `_on_craft_resolved` clears.)
- [x] Headless suite green on the host, `--server` and `--client` boots, with no
  `SCRIPT ERROR` / `Parse Error` in any of them. (`Results: 6994/6994 passed
  (0 failed)` + `All tests passed ✓` on all three, and
  `[Server] listening on port 7777, max_clients 64` on the `--server` boot.)
- [x] A real server+client pair still handshakes, joins, reconnects, and
  receives its own record. (`[Server] reconnected player
  'player_1790211585_1_c1faa9ada576fae72382b700cd8555b8' as peer_693354570`
  with the client logging `[Client] identity assigned: …`.)

**Tasks / tests:**
- `technology: tree and materials are per-player`
- `technology: client forwards research intent`
- `repair: resolves against the repairer's inventory`
- `repair: client forwards intent, mutates nothing`
- `net: player intents bind connection identity`
- `net: own-state push is peer-scoped`
- `technology: client does not resolve research`

**Verification (headless, on this machine):**
- Suite: `6940/6940` before the phase → `6994/6994` after (+54 assertions from
  the 7 new registered cases), green on the listen host, `--server`, and
  `--client` boots.
- A real server+client pair over loopback: the client presents its cached id and
  the server answers `[Server] reconnected player
  'player_1790211585_1_c1faa9ada576fae72382b700cd8555b8' as peer_693354570`,
  with the client logging `[Client] identity assigned: …` — the per-player
  technology bucket is applied on the join path with no error.

**Implementation notes:**
- **"" means "the local player", not "no player".** Every id-taking call
  defaults to `""` and `resolve_player()` maps it to this machine's local player
  (the registry's `local_player_id`), so every pre-existing call site — the UI
  projections, the DEBUG boot demo, the isolated unit tests — keeps working
  untouched, and a client (no registry identity) or an isolated slice collapses
  to the single bucket that IS its own player.
- **Research deadlines are wall-clock Unix seconds now.** They were
  `Time.get_ticks_msec() + duration`, i.e. process uptime — the same value shape
  Phase 33 removed from creature respawns and Phase 24/31 already avoid. Nothing
  persists the deadline today (a restored "researching" status restarts its
  timer), but a deadline that only means something inside the process that set
  it is exactly the value that breaks the moment anything does.
- **The host pushes the peer's own state, because a client has no other way to
  learn it.** A client's inventory and tree only ever arrive in a snapshot, so a
  repair or research the host resolved on its behalf used to leave the peer
  showing stale contents until the next AOI re-scope or reconnect. The push is
  scoped to that peer — an inventory is private, so unlike an AOI world delta it
  cannot be broadcast. Craft got the same fix (it had the identical gap, and
  `_on_craft_resolved` was a `pass`), which is why craft results carry a
  `player_id` too. Position and HP are deliberately NOT in the payload: they are
  host-simulated and ride the normal player-state path, and re-sending a stored
  position would teleport the peer back to it.
- **Do not connect a listener to the signal the listener re-emits.**
  `own_state_synced` is emitted by the inbound route and read by `game_root`, and
  the outbound direction is a direct `send_own_state()` call — a networking
  listener that re-emitted the signal made a client loop on its own packet until
  the stack overflowed (caught by the push test, which saw 2041 arrivals instead
  of one).
- **Gate the whole lifecycle on `is_authoritative`.** A client neither resolves
  research nor repairs: it forwards the intent and caches nothing. That includes
  the slice's AUTOMATIC paths, not just its request handlers: `TechnologySlice`
  re-arms an auto-complete deadline for any status restored mid-research (so a
  real slice never stays stuck in `researching`), so an ungated `_tick_research`
  had the client unlock the technology on its OWN clock and emit
  `technology_unlocked` for a status the host never granted. The tick now returns
  early when not authoritative; repair has no tick, so its guard sits on the
  request / intent handlers.
- **The identity is bound to the connection, never read from the payload.**
  `repair_intent` / `research_intent` are dropped from an un-handshaked peer and
  re-emitted with `get_player_id(sender)`; a `player_id` in the packet body is
  ignored, exactly as `craft_intent` already did.
- **Two players can hold the same technology independently** — the status
  dictionary is a map of maps, so alice's `unlocked` and bob's `researching` for
  the same tech coexist, and each pays the cost from their own inventory.

**Known simplifications (deferred):**
- **The `own_state_synced` push is not acknowledged.** It is a plain reliable
  packet with no resend: a peer that loses it keeps the stale view until the next
  snapshot. The suite proves the routing and the payload, not the delivery.
- **No end-to-end socket exercise of the new intents.** The client's repair and
  research requests come from UI clicks, and a headless client has no UI, so the
  wire path is proven at the routing level (c2h identity binding, h2c delivery of
  `own_state_synced`) plus a real socket pair for the handshake, join and
  reconnect — not by driving a real client's research over the network.
- **Skill tiers and station proximity are still per-process, not per-player.**
  `CraftingSlice._skill_tiers` is one table for the machine, and
  `station_near_player` answers about the local player's position, so a remote
  peer's repair/craft is gated by the HOST's skills and the LOCAL player's
  distance to a station. Moving skill progression and per-player position into
  the record is the follow-up.
- **Other players' appearances are still not replicated**, and repair/technology
  research now share the same plumbing — that gap is unchanged from Phase 33.

---

## Phase 35 — Creature taming ✅ Done

**Goal:** Wire the `tame` capability the fabric has carried on creature entities
since Phase 5 — GraywolfPack's "tame a surviving pup after defeating the alpha
wolf" and GlimmerFox's "feed the fox to harvest shed fur without harming it" — so
a player can win a companion and the `wolfBondHolder` flag the Ranger profession
gate reads, and so the fabricated `tame` behavior stops being prose.

**Newel dependency:** None. Reuses the existing `json` field type (already
emitted by `generator-godot`) through a new `tameData()` helper in
`fabric/world/creatures/shared.js`, exactly as `dropsData()` and `techData()`
already do; no generator change. The fabric itself gained the structured `tame`
field on GraywolfPack and GlimmerFox, and `pnpm validate`, `pnpm generate` and
`pnpm check-drift` were all run.

**Deliverables:**
- `fabric/world/creatures/shared.js` — `tameData()`: result kind
  (`companion` | `yield`), `requiresUnarmed`, `requiresSkill {skill, tier}`,
  `requiresAnyItem` (alternatives), `requiresDefeated` (the alpha-down gate),
  `grantsFlag`, `yields`, `cooldownSeconds`, `suppressRespawn`.
- `fabric/world/creatures/temperate.js` / `twilight.js` — the `tame` field on
  GraywolfPack (companion, bare hands, Unarmed:journeyman, alpha down, grants
  `wolfBondHolder`, no respawn once tamed) and GlimmerFox (yield, bare hands,
  Alchemy:apprentice, rations or raw meat, sheds `glimmer_fur_tuft`, 600 s
  cooldown).
- `src/creature/taming_slice.gd` — fabric-driven `can_tame()` / `tame()`:
  requirement validation, the offering consumed from the tamer's own inventory,
  the granted flag, the companion binding, wall-clock cooldown, record sync.
- `src/core/bus.gd` — `tame_requested` / `tame_intent` / `tame_resolved` /
  `creature_tamed`.
- `src/creature/creature_slice.gd` — the instance's `tamed_by` binding plus
  `mark_tamed` / `is_tamed` / `get_tamed_by` / `companions_of` /
  `get_instance_position` / `has_defeated_species`; `nearest_creature()` skips a
  companion; the respawn tick honours `suppressRespawn`.
- `src/creature/creature_ai.gd` — a `tamed` state: a companion never aggros,
  never patrols, follows its owner, and is exempt from pack escalation.
- `src/persistence/player_registry.gd` — `flags` and `companions` on the player
  record (a pre-Phase-35 payload restores to empty defaults).
- `src/core/game_root.gd` — the slice wired and authority-gated; the flags and
  companion bindings ride the join snapshot and the Phase 34 `own_state_synced`
  push; restore on join, boot and autosave.
- `src/networking/networking_slice.gd` — the `tame_intent` c2h route, with the
  identity bound to the connection and the payload's `player_id` ignored.
- `src/player/player_slice.gd` — `G` tames the nearest creature; the controls
  panel lists it.
- `src/inventory/inventory_slice.gd` — `glimmer_fur_tuft` weight, alongside the
  other raw creature drops.
- `src/tests/test_suite.gd` — 15 taming tests under a `Phase 35` banner, including
  the atomic-refusal guard on the unidentified-tamer path.

**Acceptance criteria:**
- [x] The interaction is fabricated, not hardcoded: `tame_data()` is read for
  every creature and a creature with no `tame` field is refused as
  `not_tameable`, with its own test asserting the field-by-field contents (the
  wolf's flag/alpha/skill gates, the fox's offerings, cooldown and yield).
- [x] The wolf requires the alpha down before a pup can be tamed — "one instance
  of that species is dead" is the runtime's reading of the pack rule
  (`has_defeated_species`), and the test proves the gate is satisfied rather than
  skipped by asserting the SKILL reason that answers next.
- [x] The wolf grants `wolfBondHolder`, binds the instance as a companion, and
  the companion is not offered as an attack target
  (`nearest_creature()` skips it) and follows its owner instead of patrolling.
- [x] The fox yields `glimmer_fur_tuft` without dying, consumes the offering, and
  is refused for 600 s afterwards — the cooldown expired by hand in the test, so
  a second feed succeeds.
- [x] Requirements fail closed and name themselves: `armed`, `skill_locked:Unarmed:journeyman`
  (novice and apprentice both refused), `missing_offer`, `too_far`,
  `already_tamed`, `target_dead`, `on_cooldown`.
- [x] A tamed companion does not respawn (fabric `suppressRespawn`), while a wild
  creature with the same expired deadline does.
- [x] The flag and the companion binding survive the record round-trip through
  the player record, and a pre-Phase-35 payload restores to empty state.
- [x] Taming is per-player: one player's tame sets that player's flag, binds that
  player's companion and spends that player's offerings — a second player cannot
  feed the same fox on the first player's rations.
- [x] A client resolves nothing and forwards `tame_intent` with no identity.
- [x] Headless suite green on both boot paths — `Results: 7126/7126 passed
  (0 failed)` → `All tests passed ✓` with `[Server] listening on port 7777,
  max_clients 64` on the server boot (6994 before this phase: 132 new
  assertions).
- [x] A refused tame is atomic: an unidentified tamer's refusal leaves the wolf's
  `wolfBondHolder` flag unset and its offering unspent, asserted directly.

**Implementation notes:**
- **An empty owner is not a thing.** `tamed_by` is the instance's owner id and
  `""` means wild, so a companion needs an identified player. A tame resolved in
  the `""` bucket (a client, or an isolated slice with no registry) cannot bind a
  companion and is refused as `already_tamed` rather than silently writing a
  wild-looking owner. Every taming test wires a PlayerRegistry for this reason —
  a test that does not gets a refusal, not a binding. The refusal is ATOMIC: the
  offering is consumed first (for the race) but handed back if the binding then
  refuses, and the flag is granted only once the binding is taken, so a refused
  tame neither spends a ration nor moves progression. The one rig without a
  registry asserts exactly that.
- **The alpha-down gate is defined against what the runtime models.** A pack is N
  instances of one creature id; there is no separate alpha or pup instance, so
  "the alpha is dead" is "one instance of that species is dead", which is also
  what the pack's own `flee` rule implies. Stated in the slice docstring instead
  of left implicit.
- **Reason precedence is deliberate** (`can_tame`, documented in place):
  not-a-tame → `already_tamed` → `target_dead` → `too_far` → `alpha_alive` →
  `armed` → `skill_locked` → `missing_offer` → `inventory_full` → `on_cooldown`.
  A distance failure answers before a state failure, because a player who cannot
  reach the creature cannot act on its state either. The tests assert the
  precedence, so changing it is a deliberate edit with a failing test.
- **The shed yield must fit before the offering is consumed** (`can_add_items`),
  or a full pack eats the player's rations and hands back nothing.
- **Wall-clock deadlines**, like the market, trees, respawns and research already
  are: a process-uptime cooldown means nothing in a new process.
- **A companion is out of the pack.** A tamed wolf must not be dragged back into
  its former pack's alert/flee by the Phase 30 propagation, and a packed
  companion would otherwise fight its own owner — `_escalate_neighbor` refuses a
  companion.
- **The bare-hands rule reads the character slice for the LOCAL player only.** A
  remote peer's equipment is not replicated and the intent carries no equipment
  claim, so the rule cannot be evaluated for a peer and is reported as
  satisfied.

**Known simplifications (deferred):**
- Skill tiers remain the per-process table the crafting gates use
  (`CraftingSlice._skill_tiers`), not per-player progression — the same gap
  Phase 34 recorded.
- The `tamed_by` binding is not replicated: a peer learns its own companions from
  its record (join snapshot / `own_state_synced`), and a peer's companion appears
  as a wild creature in its AOI stream. The follow AI only runs on the host.
- No end-to-end socket exercise of `tame_intent` — a headless client has no UI, so
  the path is proven at the routing level plus the intent forward, not by driving
  a real client's tame over the network (Phase 34's gap, unchanged).
- Companion movement is still direct kinematic stepping, not a nav-mesh — the
  NavigationAgent3D item below is unchanged.

---

## Deferred (in priority order)

- **Server sharding (final, not before maturity)** — split the authoritative
  simulation across multiple servers by region / spatial partition so total
  population exceeds one process. Deferred to LAST: it is a horizontal-scaling
  concern that only pays off once a single headless server (Phase 27) plus
  spatial hashing (Phase 28) and interest management (Phase 29) are already
  saturating. No structural change is required *before* the game matures to
  make sharding possible — the Phase 27 sim/visual split and the Phase 28
  hash are the prerequisites, and both are already planned ahead of it. Revisit
  when Brazil-region load approaches one server's ceiling.

- **Public wiki deployment** — VitePress (or equivalent) static-site deployment
  and CI-triggered wiki regeneration from the fabric (deferred from Phase 9).
- **Research cost points** — the abstract `researchCost` points field is modelled
  in the fabric but not enforced at runtime (deferred from Phase 13).
- **`VoidTouched` special-case unlock** — the void-burst survivor unlock trigger
  is defined in the fabric but not wired to any runtime event (deferred from
  Phase 13).
- **Station placement UI** — currently stations are spawned programmatically;
  a build-mode placement flow is needed (deferred from Phase 16).
- **NavigationAgent3D path-finding** — creature movement currently uses direct
  kinematic stepping; replacing it with nav-mesh baked from voxel terrain and
  `NavigationAgent3D` per-instance requires the chunk-streaming world from
  Phase 17 to produce stable nav-mesh regions (deferred from Phase 15).
- **WAN / cross-region multiplayer testing** — all Phase 18–19 multiplayer
  validation is loopback or LAN (deferred from Phase 19).
- **Automatic LOD mesh decimation** — simplified meshes are hand-authored;
  runtime decimation deferred from Phase 23.
- **Dynamic impostor re-bake** — impostor billboards are offline-baked; live
  palette-change re-bake deferred from Phase 23.
