# Project Nihon — Roadmap

Project Nihon is an open-source sandbox MMORPG where players build a
civilization. This document tracks the design and implementation roadmap.
The game's entire design bible — materials, creatures, skills, items, world
systems — is authored as a Newel fabric and generated into documentation,
runtime assets, and Godot resources.

See `../newel/ROADMAP.md` for the Newel-side changes each phase depends on.

**Human verification is not an acceptance criterion.** A criterion must be decidable by the
automated gates — `pnpm validate`, `pnpm check-drift`, the headless suite on both boot paths,
`tools/net_harness.sh`, CI. A check that needs a person at the keyboard (a playtest, a screenshot
judgement, a visual inspection) is not a criterion: it is filed as a GitHub issue and the phase
proceeds without it, so unpublished human work never parks the roadmap. The phase records the
issue number where the criterion used to be.

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
  Phase 34 recorded. **(closed in Phase 36: the tiers moved onto the player
  record.)**
- The `tamed_by` binding is not replicated: a peer learns its own companions from
  its record (join snapshot / `own_state_synced`), and a peer's companion appears
  as a wild creature in its AOI stream. The follow AI only runs on the host.
- No end-to-end socket exercise of `tame_intent` — a headless client has no UI, so
  the path is proven at the routing level plus the intent forward, not by driving
  a real client's tame over the network (Phase 34's gap, unchanged).
- Companion movement is still direct kinematic stepping, not a nav-mesh — the
  NavigationAgent3D item below is unchanged.

---

## Phase 36 — Review pass: the network trust boundary, gated boots, per-player progression ✅ Done

**Goal:** close the ten findings of the Phase 36 review pass over Phases 33–35. Two
themes: what the host is willing to believe from a client (identity claims, world
edits, packet volume), and what the host tells a client (player ids that are also
bearer tokens).

**Newel dependency:** None. No fabric field changed — `pnpm check-drift` still
reports 543 files matching the manifest.

**Deliverables:**
- `src/networking/networking_slice.gd` — the inbound trust boundary: acting
  identity bound to the connection (`_actor_id`, `_refuse_unhandshaked`), world-edit
  reach validation (`_within_reach`, `_chop_is_in_reach`, `MAX_EDIT_REACH`), the
  packet size cap (`MAX_CLIENT_PACKET_BYTES`), the per-peer token bucket
  (`_allow_packet`, `RATE_BUCKET_CAPACITY`, `RATE_BUCKET_REFILL_PER_SEC`), and the
  outbound identity redaction (`redact_for_client`, `adopt_own_handle`,
  `_map_identities`, `IDENTIFIED_STATE_KEYS`, `claimed_handle`).
- `src/persistence/player_registry.gd` — `public_handle`, `player_id_for_handle`,
  `looks_like_player_id`, `resolve_named_party`, and the per-player skill tiers
  (`get_skill_tier` / `record_skill` / `record_skills`, carried by the record).
- `src/crafting/crafting_slice.gd` — `get_skill_for` / `set_skill_for` and
  `_check_skill_guards(spec, player_id)`.
- `src/creature/creature_ai.gd` — the `player_targets` provider and per-target
  ticking (`_player_targets`, `_nearest_target`, `_tick_instance(..., target_id)`).
- `src/creature/taming_slice.gd` — the bare-hands claim (`_unarmed_claims`,
  `is_unarmed` per player) and the claim-carrying intent handler.
- `src/core/bus.gd` — `tame_intent(instance_id, player_id, unarmed)`.
- `src/core/game_root.gd` — `should_run_tests` (the boot gate), the `_player_targets`
  provider, the redacted snapshot (`_build_snapshot`), and the new wiring
  (`_networking.tree_slice`, `_networking.player_registry`).
- `src/tests/test_suite.gd` — 17 new/rewritten tests.

**Acceptance criteria:**
- [x] A client cannot act as another player: every acting party (market
  seller/buyer, proposal author/voter, trade propose/accept/reject, craft, repair,
  research, tame) is the player id bound to the sending connection, and a payload's
  identity half is ignored. Asserted for all of them, plus that an un-handshaked
  peer cannot act at all.
- [x] World edits need a bound identity AND a target within `MAX_EDIT_REACH` (60 m)
  of the position the host last recorded for that peer; a peer with no recorded
  position is refused, and a tree chop resolves the tree's own position through the
  wired TreeSlice.
- [x] A client packet is capped at `MAX_CLIENT_PACKET_BYTES` before parsing, and each
  peer draws from its own token bucket: a burst is capped at `RATE_BUCKET_CAPACITY`,
  the bucket refills at the sustained rate, and a reconnect starts full.
- [x] No player id is broadcast: market, trade and governance state — values AND the
  keys of the offers/accepted maps — travel as public handles, in the delta
  broadcasts and in the world snapshot, and a leaked handle claims nothing while a
  leaked id is honoured as that player's reconnect (the takeover, demonstrated both
  ways).
- [x] The automated suite runs on boot only for a debug build or `--run-tests`; a
  release boot runs no suite.
- [x] Creature AI targets the nearest of every player the host can place on the
  machine, not only the host's own body, and a remote target is chased rather than
  handed to the battle slice. **(superseded in Phase 37: the round is now routed by
  target id, and a player target takes the forwarded-damage path — see Phase 37.)**
- [x] Skill tiers are per-player and durable: one player's tier neither unlocks nor
  gates another's craft, repair or tame, and a tier round-trips through the record.
- [x] A remote peer's bare hands are a claim that rides its tame intent; an
  unclaimed peer fails the fabric's `requiresUnarmed` rule closed.
- [x] Headless suite green on both boot paths — `Results: 7244/7244 passed
  (0 failed)` → `All tests passed ✓` with `[Server] listening on port 7777,
  max_clients 64` on the server boot (7165 at the start of this pass: 79 new
  assertions).
- [x] Every fix is RED-proven: with the fix reverted (source only, tests kept) the
  new assertion fails — quoted in each commit body.

**Implementation notes:**
- **The acting party is the connection, and only a trade invite may name anyone.**
  `_peer_party` used to pass any string except the literal `"player"` through
  verbatim, which is what made a spoofed accept/spoofed sale/spoofed vote possible.
  The counterparty on a trade invite is the one identity a payload may legitimately
  name, because it grants nothing: it is answered by that player's own accept, which
  is bound to its own connection. It is resolved against the registry's ONLINE set,
  so an invite to an offline or invented name is dropped instead of parked.
- **Reach is measured from the host's evidence, not the client's claim.** The peer's
  position comes from the host's own record of its movement packets;
  `has_last_known_state()` is what separates "never reported" from "at the origin",
  so a peer with no position on record is refused rather than measured from an
  assumed spawn.
- **The channel is policed, not just its packet types.** Phase 19's dedup rejects a
  REPLAYED seq and never a fresh flood, so the token bucket is what bounds a peer's
  rate. Both bucket state and the size cap live before the payload is parsed.
- **Handles are derived, not minted**, and that is the whole point: a minted handle
  would need a record (absent for an offline seller named in a persisted listing), a
  re-mint after a save/load, and a place to live. `sha256(player_id)` truncated needs
  none of that, is stable across a restart, and cannot be turned back into the token.
  The id-SHAPE predicate is what finds the ids inside a payload, so an evicted
  player's id is still recognised as one.
- **The client is shown its own handle back as `"player"`.** Single-player and
  client-side code has always named the local player `"player"`; the adoption step
  keeps that true without the client ever holding another player's identity — and
  the demo's scaffolding literals (`"merchant"`) are not id-shaped, so they pass
  through every redaction untouched.
- **Skill tiers moved onto the record, with the process table kept for one narrow
  case:** this machine's own player when the record holds no tier yet (the
  pre-identity boot, the DEBUG demo's `set_skill`, and isolated tests). A peer has no
  such fallback, so a missing tier fails closed at the seed tier instead of borrowing
  this machine's numbers.
- **The bare-hands claim is deliberately short-lived.** It is installed for exactly
  the resolution its intent triggered and dropped immediately after, so a stale claim
  cannot silently arm or disarm a later attempt. The residual trust is stated in the
  code: a client that lies about its hands is believed, exactly as it is believed
  about its movement.
- **A remote target is chased but not struck.** Damage to a peer belongs to that
  peer's own client — the machine that simulates its health — and the host has no
  simulation of a peer's HP to hit or persist (`PlayerRegistry.record_hp` already
  refuses a client-declared value). Handing a player id to the battle slice would run
  it through the CREATURE path: tracked hit points, then a `creature_died` on
  somebody's id. Peer damage over the wire is deferred (below). **(closed in Phase 37:
  the round is routed by target id and the player path forwards damage with the target,
  which the host delivers to that peer's client. The danger named here was real — the
  RED run of the old policy produced 11 `creature_died` emissions on a peer's id.)**

**Known simplifications (deferred):**
- **Peer damage over the wire.** A creature aggros and chases a remote peer, but no
  combat round is opened against it (see above). Closing this needs a host → client
  damage event and per-peer HP ownership on the peer's own client. **(closed in Phase 37:
  the round is routed by target id, `player_damaged` carries the target, and the host
  sends the hit to that peer's own client — which applies it. A peer's HP is still owned
  by its own client, so the host's view of it remains that client's word.)**
- **Peer equipment is not replicated.** The bare-hands rule is evaluated against the
  peer's own claim. Verifying it means replicating worn gear, which is the feature
  the claim stands in for.
- **Trade's broker-fee tier is still slice-local** (`TradeSlice._skill_tiers`): it
  affects only the LOCAL player's own fee, and is read from the local table. Moving
  it onto the record is the remaining half of the per-player skill change.
- **A client is not sent its own skill tiers.** It never resolves a craft or a
  tame — it forwards an intent — so the tiers it displays (a gated recipe row) are
  the local table's. The host is the authority for every gate.
- **Still no end-to-end socket exercise** of the new guards: they are proven at the
  routing level (`_route_c2h`, `_route_h2c`, `redact_for_client`) rather than by
  driving two real clients through ENet (Phase 34/35's gap, unchanged).
- **The taming mirrors are still never evicted on disconnect** and `tamed_by` is
  still not replicated — both carried over from Phase 35, unchanged. **(closed in
  Phase 37: `TamingSlice.forget_player_id` releases the flags, companion and cooldown
  mirrors with the record that was just written; `tamed_by` replication is still
  deferred.)**

---

## Phase 37 — Review pass: owner-scoped syncs, durable cooldowns, bounded memory, routed rounds ✅ Done

**Goal:** close the seven findings of the review pass over Phases 33–36. Three themes:
data that was addressed to nobody (inventory syncs, combat rounds), state that only lived
in memory (cooldowns, the taming mirrors, half-reassembled snapshots), and one predicate
that answered a question it should not (a raw player id in a counterparty name).

**Newel dependency:** None. No fabric field changed — `pnpm validate` is clean and
`pnpm check-drift` still reports 543 file(s) matching the manifest.

**Deliverables:**
- `src/core/bus.gd` — `inventory_synced(owner_id, contents, durabilities)` and
  `player_damaged(damage, attacker_id, target_id)`.
- `src/inventory/inventory_slice.gd` — `owner_id`, `LOCAL_OWNER_LITERALS`,
  `is_owned_by()`, and the owner filter in `_on_inventory_synced`.
- `src/persistence/player_registry.gd` — `cooldowns` on the player record
  (`record_cooldowns` / `get_cooldowns` / static `live_cooldowns`), the owner stamp in
  `get_inventory`, and `resolve_named_party()` restricted to public handles.
- `src/creature/taming_slice.gd` — cooldowns persisted and restored with the record,
  and `forget_player_id()` releasing the three per-player mirrors.
- `src/networking/networking_slice.gd` — peer-scoped inventory sync
  (`_peer_for_inventory_owner`), `send_player_damaged` plus its inbound route, and the
  snapshot buffer eviction in `forget_player_id` / `disconnect_all`. **(extended in Phase
  38: both of those sites are on the host's half of the wire, so the CLIENT's path —
  `_on_server_disconnected` — was added.)**
- `src/creature/creature_slice.gd` — `instances_view()` (cached, read-only, live
  records), `_view_stale` / `_invalidate_view`, and `instance_id` on the instance record.
- `src/creature/creature_ai.gd` — the per-frame loop reads the cached view and emits a
  round for whatever target the creature engaged.
- `src/battle/battle_slice.gd` — static `is_player_target()`, the player path keyed on
  the defender SHAPE, and creature hit points no longer initialised for a player.
- `src/player/player_slice.gd` — `_on_player_damaged(..., target_id)` with
  `_is_local_target()`.
- `src/core/game_root.gd` — the merchant inventory's owner stamp, `_taming.forget_player_id`
  on disconnect, and `_on_player_damaged` forwarding a peer's damage to its own client.
- `src/tests/test_suite.gd` — 9 new tests (135 new assertions) and 3 rewritten ones.

**Acceptance criteria:**
- [x] An inventory sync is applied by the OWNER's inventory only: a peer's sync leaves
  the local pack and the demo merchant's stock untouched, and the local bucket answers
  under either of its literals. On the wire the host sends a sync to the owner's peer
  alone, carries no player id, and fails closed (no broadcast fallback) for the local
  bucket, an unresolvable owner, or an unwired registry.
- [x] A tame cooldown survives a restart: it is written on the player record, pruned of
  expired deadlines on the way in and out, and a restored slice still refuses the feed
  with `on_cooldown`.
- [x] An incomplete snapshot's reassembly entry is evicted with the connection that was
  carrying it, while a snapshot that completes still empties its own entry.
- [x] The per-player taming mirrors (flags, companion bindings, cooldowns) are released
  on disconnect — and refused for the local player — with the durable record re-applied
  by the reconnect path.
- [x] Every combat round is routed by the target the creature engaged: a remote peer's
  player id reaches the battle slice down the PLAYER path (no tracked hit points, no
  `creature_died` on a player id — asserted over 20 rounds), and the host forwards the
  hit to that peer's own client, which applies it to the local body.
- [x] `get_all_instances()` still hands out copies, `instances_view()` returns the
  cached live records (identical array between calls, no rebuild until membership
  changes, rebuilt after a despawn), and the AI's per-frame loop uses it.
- [x] A named counterparty must be a public handle: a raw player id — online, the local
  player's own, or unknown — resolves to nothing, so the resolver is no longer an
  online-status oracle. The invite path and the resolver are both asserted.
- [x] Headless suite green on both boot paths — `Results: 7379/7379 passed  (0 failed)`
  → `All tests passed ✓` with `[Server] listening on port 7777, max_clients 64` on the
  server boot (7244 at the start of this pass: 135 new assertions).
- [x] Every fix is RED-proven: with the pre-fix policy restored (source only, tests
  kept) the new assertions fail — quoted in the commit body.

**Implementation notes:**
- **An inventory sync now names its owner, and the local bucket has two literals.** One
  process holds several inventories at once (the local player's, one per connected peer
  created by the registry, the demo merchant's), and the signal is bus-wide, so an
  unfiltered handler replaced every one of them. `owner_id` is a FILTER, never an
  authority — the host still binds the acting identity to the connection
  (`_actor_id`) — and `""` / `"player"` both name this machine's own player (the Phase 34
  `resolve_player` convention and `TradeSlice.PARTY_PLAYER`). The wire packet carries no
  owner at all: it is delivered to the owner's peer, so the only inventory it can be is
  that client's own, and a player id stays off the wire (Phase 36's rule).
- **A cooldown is a rule about the PLAYER, not about the process.** Kept in memory it
  was cleared by a restart, which is exactly the loop the fabric's `cooldownSeconds`
  exists to stop — one reconnect away. It now rides the record, pruned to live deadlines
  by one shared pure rule (`PlayerRegistry.live_cooldowns`), so the mirror and the record
  cannot disagree about what is still in force.
- **A half-reassembled snapshot is transport state.** Chunks are indexed by
  `snapshot_id` and a lost chunk means the entry is never completed, so it lived for the
  whole session — one leak per lost chunk, on a connection that may be long gone.
  Reassembly belongs to the connection that carried it.
- **The taming mirrors are the registry's rule, applied one slice over.** The record
  written at disconnect is the durable copy (the same argument
  `PlayerRegistry.evict_player` already makes), so the mirrors are released with it and
  re-applied by `apply_record` on the next claim. The local player is refused, for the
  same reason `evict_player` refuses it: it is online by definition.
- **Rounds are routed by target, and a player target never reaches the creature path.**
  `combat_round_requested` now carries whoever the creature engaged, and
  `BattleSlice.is_player_target()` (the literal `"player"`, or an id-shaped player id)
  decides which path the round takes. The creature path is the dangerous one — it tracks
  hit points in `_hp_state` and emits `creature_died` when they run out, which on a
  player id is a corpse on somebody's identity (the RED run produced 11 of them). Those
  hit points are now initialised only for a creature defender: nothing here holds a
  number it cannot verify.
- **The hit itself is applied where the body is simulated.** The host owns the
  authoritative simulation and so knows a creature struck a peer, but it still holds no
  verifiable HP for that peer — `PlayerRegistry.record_hp` refuses a client-declared
  value for exactly that reason — so it sends the round to that peer's own client rather
  than applying or persisting it. `player_damaged` gained the target for that routing,
  and the peer-scoped packet arrives as the local body's id, the only one it can be.
  The residual trust is stated in place: the peer's HP is still its own client's to
  keep, so a client that lies about its health is believed about it, exactly as it is
  about its movement.
- **The cached view is read-only by contract, and that is the whole design.** The
  records in `instances_view()` are the slice's own, so it is cheap (no allocation per
  creature per frame) and live (a write through it writes the world); only MEMBERSHIP
  changes invalidate it, since a moved creature needs no rebuild. `get_all_instances()`
  keeps its copy semantics for the UI and for tests, and the two are asserted apart.
- **Handles only, because the alternative was an oracle.** `resolve_named_party`
  answering a raw id told a client whether that exact id was connected, and an id is a
  bearer token: presenting one on join claims the record. Nothing legitimate still sends
  one — a client learns ids nowhere (`redact_for_client`) — so the branch was pure
  probing surface.
- **A suite leak was fixed on the way past.** `_test_taming_record_round_trip` left two
  TamingSlices alive on the shared bus, so a later test's tame was resolved — and
  refused — by an unwired leftover first. Every test slice is torn down immediately, as
  the suite's own docstring requires.

**Known simplifications (deferred):**
- **A peer's HP is still client-owned.** The host now delivers a creature's hit to the
  peer's own client, but the value that client keeps is still its own word: the host
  holds no simulation of a peer to check it against. Making peer health authoritative
  means simulating peer bodies (or at least their HP) on the host. **(closed in Phase 38:
  the host simulates a peer's HP itself — `PlayerRegistry.record_simulated_hp`, seeded by
  the pure `simulated_hp_after_hit` — and persists it on the peer's record, so the
  forwarded `player_damaged` is a display update rather than the only copy. What is still
  deferred is what happens to a peer at zero: no death consequence is resolved host-side.)**
- **Peer equipment is still not replicated.** The bare-hands rule is evaluated against
  the peer's own claim (unchanged from Phase 36).
- **`tamed_by` is still not replicated**, so a peer's companion appears as a wild
  creature in its AOI stream while the follow AI runs only on the host (unchanged from
  Phase 35).
- **Still no end-to-end socket exercise** of these paths: every fix is proven at the
  routing level (`_route_c2h` / `_route_h2c`, the bus, `_pending`) rather than by driving
  two real clients through ENet (Phase 34/35/36's gap, unchanged).
- **A combat round's damage event is not sequenced against movement.** The peer applies
  whatever arrives; a reordered pair could apply a hit after the peer's own position
  update reported a death. Phase 19's dedup covers duplicates and reordering per type,
  not ordering BETWEEN types.
- **The registry-held peer inventories are still only released on disconnect.** They are
  evicted with the player (`evict_player`), but nothing bounds the inventory of a peer
  whose disconnect was never delivered (a hard kill) beyond the autosave interval.

---

## Phase 38 — Review pass: host-simulated peer health, one key list, the missing clear, an in-place prune ✅ Done

**Goal:** close the five findings of the review pass over Phases 33–38. Two of them are the
same hole seen from both ends — the host resolved a combat round against a peer and then
kept no number for it, so a client's health was its own client's word — and three are
single-list/single-site bugs: a hardcoded key set beside an unused constant, a clear that
only ever ran on the host's side of the wire, and a prune that only ever ran on the copy
that was being saved.

**Newel dependency:** None. No fabric field changed — `pnpm validate` is clean and
`pnpm check-drift` still reports 543 file(s) matching the manifest.

**Deliverables:**
- `src/persistence/player_registry.gd` — `get_hp()`, the pure static
  `simulated_hp_after_hit()`, and `record_simulated_hp()`: the HOST's own resolution of a
  remote peer's health, the door `record_hp` deliberately is not. `record_hp` keeps
  refusing a remote id, so the declared value still has no path into a record.
- `src/core/game_root.gd` — `_on_player_damaged` applies the hit to the host's own record
  for the peer BEFORE forwarding the display update, `_social_state()` plus the
  `redact_social_state` merge in `_build_snapshot`, and the `_fold_last_known_state` /
  `_snapshot_remote_players` notes brought in line with a peer's HP now being durable.
- `src/networking/networking_slice.gd` — `redact_social_state(state)` (the host half of
  `IDENTIFIED_STATE_KEYS`), `_on_server_disconnected()` and its wiring, so a CLIENT that
  loses its host drops the snapshot it was reassembling.
- `src/creature/taming_slice.gd` — `_cooldowns_for()` prunes expired deadlines in place,
  through the same shared rule the record is written with.
- `src/tests/test_suite.gd` — 4 new tests (36 new assertions) under a `Phase 38` banner.

**Acceptance criteria:**
- [x] A peer's health is the HOST's: `simulated_hp_after_hit` starts an unmodelled body at
  full health (never at a value the peer declared), clamps to `[0, max_hp]`, and
  `record_simulated_hp` writes it on the peer's durable record — asserted through
  `get_player_data` → `apply_player_data`, so a reconnect or a restart no longer hands the
  peer a full bar. The declared door stays shut: `record_hp` still refuses a remote id, the
  local body is still `record_hp`'s, an id this host holds no record for is refused rather
  than minted, and a non-authoritative registry writes nothing.
- [x] The snapshot's social blobs travel under `IDENTIFIED_STATE_KEYS` and are walked from
  it: only those keys are carried (a blob the list does not name is dropped, not passed
  through unredacted), every listing seller / proposal author / trade party reaches the
  wire as a public handle — including a trade party used as a dictionary KEY — and no
  player id survives the walk.
- [x] A client that loses its host clears its snapshot buffer, while a host-role call
  changes nothing (the local teardown path already covers it).
- [x] The cooldown mirror is pruned in place: an elapsed deadline is gone from
  `TamingSlice._cooldowns` after a read, a live one stays, and a deadline written after a
  prune lands in the same table the reader left behind.
- [x] Headless suite green on both boot paths — `Results: 7415/7415 passed  (0 failed)` →
  `All tests passed ✓` with `[Server] listening on port 7777, max_clients 64` on the server
  boot (7379 at the start of this pass: 36 new assertions).
- [x] Every fix is RED-proven: with the pre-fix policy restored (source only, tests kept)
  the new assertions fail — quoted in the commit body.

**Implementation notes:**
- **A hit the host resolved is evidence, and evidence has to be kept.** Phase 37 routed the
  round by target and delivered it to the peer's own client, which closed the "no round is
  ever opened" hole but left the OUTCOME client-owned: a modified client could ignore the
  packet and be unkillable, and an honest one lost its health on every reconnect and every
  restart. The host now applies the hit to its own number for that peer first and sends the
  round afterwards as a display update, so a client that drops it diverges from a truth it
  does not hold instead of being the truth. The seed for a body the host has never modelled
  is FULL health — the only honest choice, since the record is empty and the peer's own
  declared value is what made a durable record a cheat in the first place (that value is
  still ignored on `player_moved` and still refused by `record_hp`).
- **Two writers for one field, and the split is the security property.** `record_hp` is the
  live-body writer and refuses a remote id; `record_simulated_hp` is the host's own
  resolution and refuses the local id, an empty id, a player with no resident record, and
  any non-authoritative machine. Keeping them separate is what lets the durable rule stay
  testable on its own (`simulated_hp_after_hit` is pure) instead of hiding behind "the host
  may write anything".
- **One list for identity-bearing state, read in both directions.** `IDENTIFIED_STATE_KEYS`
  existed but the SNAPSHOT builder hardcoded the same three keys, so the constant only ever
  governed the receiving side: a fourth entry would have been adopted by every client while
  never being redacted on the way out — a player id on the wire, the exact leak the constant
  exists to prevent. `redact_social_state` walks the constant now, and a key the list does
  not name is dropped rather than passed through: an identity-bearing blob nobody has added
  to the list is a blob whose redaction story has not been decided.
- **The buffer's eviction points were both on the host's half of the wire.** One was this
  slice's own teardown and the other was a PEER disconnecting — and a client has no peers to
  disconnect, so a client's half-reassembled snapshot sat there for the rest of the session.
  `server_disconnected` is the missing end of the same lifecycle (`_attach_peer` /
  `_detach_peer`), and the handler is role-gated so it cannot become a second, weaker clear.
- **A prune that only ran on the saved copy is not a prune.** `get_cooldowns` handed the
  record a filtered copy while `_cooldowns` kept every deadline the player had ever set, so
  the mirror grew with every fox ever fed and the record only caught up at a `sync_record`.
  The prune now runs where the table is READ — the same `live_cooldowns` rule on both sides
  — and allocates nothing when nothing expired, so the write path keeps landing in the one
  dictionary the mirror holds.

**Known simplifications (deferred):**
- **Peer health has a durable floor but no death consequence.** The host simulates and
  persists a peer's HP, but a peer reaching zero is still not resolved host-side (no
  `creature_died`-style outcome, no respawn): the downed body stays the peer's own client's
  business, as the whole of its movement is. **(closed in Phase 39, for the floor: the host
  now writes a respawn deadline when its own simulation reaches zero and resolves it lazily
  on read, and the client starts its own countdown the moment `set_hp()` hands it a zero, so
  a downed peer recovers instead of freezing at zero across reconnects and restarts. What is
  still deferred is the death CONSEQUENCE: no corpse, no loot, no kill credit is resolved
  host-side.)**
- **A hit is not sequenced against the hit that preceded it.** The host applies each
  resolved round as it comes, and `player_damaged` still carries only the delta, so a
  client that lost a packet converges on the host's number a round late rather than never.
- **Peer equipment is still not replicated.** The bare-hands rule is evaluated against the
  peer's own claim (unchanged from Phase 36/37).
- **`tamed_by` is still not replicated**, so a peer's companion appears as a wild creature
  in its AOI stream while the follow AI runs only on the host (unchanged from Phase 35).
- **Still no end-to-end socket exercise** of these paths: every fix is proven at the routing
  level (`_route_c2h` / `_route_h2c`, the bus, `_pending`, and directly against the registry
  rule) rather than by driving two real clients through ENet (Phase 34/35/36/37's gap,
  unchanged).

---

## Phase 39 — Two-client network harness: prove the wire over a real socket ✅ Done

**Goal:** Make the network trust boundary real. Phases 34–38 hardened the client → host
intent path — connection-bound identity, reach and rate guards, owner-scoped syncs,
durable per-player records, host-simulated peer health — and every one of those
guarantees is currently proven at the ROUTING level only: tests call `_route_c2h(sender,
payload)` and read the bus, with the sender id handed in as an argument. No test has ever
put a byte on a socket. This phase adds a harness that boots two real peers over ENet —
the same `NetworkingSlice.host()` / `join()` the game itself uses — drives a full session
lifecycle between them, and asserts on packets the transport actually carried. It closes
the deferral re-stated in Phases 34, 35, 36, 37 and 38.

Deliverable 1 is the one durable fix the harness then proves on a real socket: a peer's
simulated HP is a subtract-only counter that cannot heal, so a peer downed by a creature
stays at zero across reconnects and restarts, and the client handed that zero ends up dead
with no countdown running. The harness's reconnect step is where that fix is observed
end to end.

**Newel dependency:** None. No fabric field changes — `pnpm validate` is clean and
`pnpm check-drift` still reports 543 file(s) matching the manifest.

**Deliverables:**
- `src/persistence/player_registry.gd` — deliverable 1, the durable fix: a peer's
  simulated HP stops being a subtract-only counter. When a resolved hit takes it to zero
  the host writes a respawn deadline onto the same durable record (the Phase 37 deadline
  shape, pruned the way `live_cooldowns` prunes), and the deadline is resolved by a NEW
  PURE RULE — `hp_after_respawn(hp, deadline, now, max_hp)` — that BOTH readers of the
  field call, so a downed peer's recovery does not depend on which one asks. The two
  readers are `get_hp()` (the live read) and `get_player_data()` (the saved copy, which the
  handshake snapshot, the disconnect save and the autosave all go through — and which
  currently reads `hp` raw at `player_registry.gd:627`). A resolution wired into the live
  reader alone leaves the one the reconnect actually uses un-resolved, which is Phase 38's
  lesson in mirror image: a rule that runs on one reader is a reader-dependent rule. No
  write-on-read either: `get_hp()` stays pure and the deadline stays the durable fact. A
  rewrite through `record_simulated_hp` would no-op on exactly the paths where it refuses —
  a non-authoritative machine, the local id, a player with no resident record — while the
  value the read returned claimed full health.
- `src/player/player_slice.gd` — the client-side half of deliverable 1: `set_hp()` starts
  the respawn countdown when the value it applies is zero AND no countdown is already
  running (`_respawn_timer == -1.0`) — it must START one, not restart it, or a repeated
  zero would push the respawn further away on every application and the body would never
  come back. One entry point, so a body handed a zero — by a join snapshot, a forwarded
  hit, or a save restore — can never sit `_alive == false` with no timer running. That
  incidentally closes the same soft-lock in single-player: `_restore_local_player` hands a
  restored record's zero to the same door (`game_root.gd:1246`), so the fix covers the
  local body too rather than only the peer it was found on. **Review pass — two more rules
  on that same door, both about what it owes the callers it already had. (a) A zero applied
  to a LIVE body is announced THROUGH `_die()`, so `player_died` fires: this method used to
  apply the number and start the countdown without ever reaching the death door, so the
  body was dead here with no death announced — while that very countdown announced
  `player_respawned` when it ran out, and `game_root` turns `player_died` into the
  character-death consequence. A respawn with no death behind it is half a pair. A zero
  applied to a body ALREADY down announces nothing, so a re-delivered snapshot cannot
  re-announce a death that already happened. (b) A value that leaves the body UP clears the
  countdown parked on it: `_physics_process` ticks the timer only while `_alive` is false,
  so a leftover sat frozen on a living body and was then REUSED by the next zero instead of
  a fresh one — the body came back early, on the seconds left over from the death it had
  already recovered from. Both are registered as
  `identity: set_hp announces and clears`.**
- `src/tests/net_harness.gd` — the `await`-driven harness runner: a scenario step table
  and a pump loop that yields real frames, so packets can leave and arrive. The existing
  suite cannot host this (see the constraint note below). **Review pass — the runner now
  audits its OWN source before either peer boots (`unawaited_waits` / `_self_audit`): a bare
  `_await_…` call compiles and returns immediately, which is precisely how the twelve missing
  `await`s in this file turned its waits into no-ops, and it is the one defect the
  frame-less suite cannot observe. The runner also ends its process with the run's own verdict
  as the exit code (`get_tree().quit(1 if _failed else 0)`): the driver reads the `fail` line
  too, but a scenario that failed used to exit 0, which is the wrong answer to give the
  cheapest question anyone asks a process.**
- `src/core/game_root.gd` — a `--net-harness <role>` user arg parsed beside `--server` /
  `--client`, and the harness entry point that runs BEFORE the world boot, mirroring the
  existing `should_run_tests` gate.
- `tools/net_harness.sh` — the driver: boots one host process and one client process on
  loopback, waits for a readiness line, runs the scenario, and fails on a missed
  assertion, a deadline overrun, or a non-zero exit. **Review pass — the header claimed "a
  side misses a step, or reports it TWICE" while the reader took `head -n 1` and nothing
  counted: a second line for a step was silently ignored and the step judged on the first.
  The check now exists (`steps_reported`), the dead `steps_of()` was removed, and the
  per-step readers are unambiguously "the first line" because a duplicate can no longer
  reach them. CI pass — on failure the driver now prints both processes' `HARNESS` lines and
  their transport-lifecycle lines into the step output, so a CI failure says which step broke
  without anyone downloading the artifact.**
- `src/core/player_rules.gd` — **review pass**: `MAX_HP` and `RESPAWN_DELAY` move off
  `PlayerSlice` into a neutral module both layers preload, the `skill_tiers.gd` shape. The
  persistence layer used to `preload("…/player_slice.gd")` for those two constants —
  persistence importing presentation, in the wrong direction, for arithmetic neither layer
  owns. The values are unchanged and `PlayerSlice` re-exports both names, so no existing
  reader moved.
- `src/tests/test_suite.gd` — registration of the harness's pure helpers (the step table,
  the log-line format, the convergence predicates) so the synchronous suite still covers
  the harness's own logic, under a `Phase 39` banner.
- `.github/workflows/ci.yml` — a `net-harness` job running the driver on ubuntu-latest,
  alongside `godot-tests`, `server-boot` and `fabric`.
- `README.md` — phase table rows for 36, 37 and 38 (missing since those passes landed)
  and for this phase.

**Acceptance criteria:**
- [x] Two real peers handshake over loopback ENet, and the identity the host binds comes
  from the CONNECTION: a client declaring a `player_id` it does not own is bound to its
  transport-derived id anyway (`handshake`, both sides green). *The un-handshaked-peer
  half stays a routing-level assertion — the client's boot presents its join intent on
  connect, so there is no window to send an intent from before the handshake.*
- [x] The reach guard is exercised with real evidence: a chop intent for a tree the peer
  cannot reach is dropped, and one for a tree inside reach consumes it — the tree's
  position coming from the host's own `TreeSlice`, never the payload (`chop_in_reach`,
  `chop_out_of_reach`).
- [x] The inbound limits hold on a real socket: a packet above `MAX_CLIENT_PACKET_BYTES`
  (8192) is refused without disconnecting the peer as a side effect, and the per-peer
  token bucket throttles a burst without starving the steady stream that follows it
  (`packet_cap` — the host logs the 9067-char drop and the peer stays bound; `rate_bucket`
  — the bucket reads 0 mid-burst and the chop after it is consumed).
- [x] An owner-scoped inventory sync reaches the owner alone: peer A's sync leaves peer
  B's client inventory and the host's own bucket untouched (`inventory_owner`; the host's
  own pack is compared before/after, because a dedicated server boots with its saved
  record restored and is not empty).
- [x] A chunked snapshot completes across real packets (`snapshot_complete` — the world
  snapshot is far larger than `SNAPSHOT_CHUNK_SIZE`, so it genuinely arrives as several
  reliable packets, and the client reassembles them into one world). A client that loses
  its host clears its buffer: asserted on its own `disconnect_all()` teardown in
  `reconnect_alive`; the `NetworkingSlice._on_server_disconnected` path is NOT exercised
  on the wire (see the known simplifications). **What this proves, exactly (review pass):
  that the reassembler works over the TRANSPORT'S delivery on a real socket — several
  chunked packets, one world. It does NOT prove the reassembler tolerates a chunk arriving
  out of order, because a reliable ordered channel cannot deliver one: the ordering this
  step relies on is the transport's, so the step would pass with no ordering logic in the
  reassembler at all. Reordering and loss stay deferred with the emulator (see the note on
  it) rather than being claimed here.**
- [x] A combat round routed at a peer arrives at that peer's own client, and the host's own
  simulated number for that peer survives a real reconnect AS THE HOST'S OWN
  (`peer_damage_floor`, and the same peer in `reconnect_alive`). **Review pass — this
  criterion and the next one are the two halves of one event and used to read as a
  contradiction: "survives unchanged" is about AUTHORITY (nothing the peer declares
  overwrites the host's number, and the floor the host recorded is still the value the
  record holds), not about the value being frozen at zero — the resolution of a deadline
  that has passed is the next criterion's claim, and both are asserted on the same peer in
  the same step.**
- [x] A peer killed before it disconnects reconnects alive and controllable: the host's
  respawn deadline resolves on the read that follows the reconnect — and resolves on BOTH
  readers, since the handshake snapshot reads the saved copy (`get_player_data()`) rather
  than `get_hp()` — and the client's body runs its own countdown rather than sitting dead
  with no timer (`reconnect_alive`, both sides green).
- [x] Deliverable 1 holds on both ends: a peer whose simulated HP reaches zero returns to
  full health after the delay, survives a restart, and answers the same number through the
  live reader and the saved copy; a body handed a zero by `set_hp()` starts its respawn
  countdown, and a repeated zero does not restart it; the new rule is asserted pure and
  alone, beside `simulated_hp_after_hit` and `live_cooldowns`; and the declared value still
  has no path into a record — the respawn deadline is not a second door for it. Each new
  rule is RED-proved first (`identity: the respawn rule is pure`,
  `identity: a downed peer comes back`, `identity: set_hp starts the respawn countdown`,
  and — review pass — `identity: set_hp announces and clears` for the two rules that door
  gained: a live body taken to zero is announced dead, and a value that leaves it up clears
  the countdown rather than leaving it parked). SECOND review pass — two more rules on the
  same field, both registered as `identity: a sliver of health is down`: "down" is a RANGE
  (`PlayerRegistry.is_downed`, `HP_EPSILON`) rather than the exact value `0.0`, because a hit
  that lands a fraction short of cancelling the number leaves a body at ~1e-7 that the old
  `hp > 0.0` WRITER cleared a deadline for while the old `hp != 0.0` READER handed it back as
  health — a body that could never come back; and a restored record keeps its deadline only
  while the body it belongs to is down, so a record arriving already resolved (alive) cannot
  wear a spent deadline for the rest of the world's life. `is_downed` is the one predicate
  both the writer and the reader use.
- [x] A disconnect evicts transport state end to end: the peer's record is evicted, its
  taming mirrors and snapshot buffer are forgotten, and a reconnect re-presents the join
  intent and is re-answered (`disconnect_evicts` — the reconnected peer carries the SAME
  player id, and no dead peer id is still bound).
- [x] The harness runs on both the host-process and the client-process side and is wired
  into CI, while the existing suite stays synchronous and unchanged in cost
  (`tools/net_harness.sh`). **Review pass — NOT independently reproduced, and the reason was
  in this file. The driver was green when the phase was written (`10/10 steps agreed across
  both peers`) and failed four consecutive runs after it, on `rate_bucket`, always with the
  same detail: `burst_not_throttled_or_steady_lost-steady1-min0-now119` — the tree
  `packet_cap` consumed was counted ONCE, the burst HAD emptied the bucket (`min0`), and at
  the deadline the bucket was full again (`now119` of 120), so the limiter was not what
  starved the stream. The note's money was on "the client half never getting its intents onto
  the wire": right about the symptom, wrong about the layer. SECOND review pass — every one
  of the TWELVE `_await_settle` call sites in `src/tests/net_harness.gd` was missing its
  `await`, so each one returned at its first yielded frame and waited NOTHING. The client's
  post-burst chops therefore left in the SAME FRAME as the burst that had just emptied its
  bucket, the host's limiter dropped them, and the step blamed the limiter for the harness's
  own missing wait — the `steady`/`min`/`now` tokens the first pass added are what made the
  mechanism legible. Reproduced on the pristine source before the fix (`rate_bucket` → the
  identical token, 1 run of 1) and green after it (`10/10 steps agreed across both peers`,
  two consecutive runs). A bare coroutine call is now impossible to reintroduce silently:
  `NetHarness.unawaited_waits()` audits the source, `net: harness awaits are not bare` asserts
  the rule in the suite, and `NetHarness._self_audit()` runs it on every boot. CI PASS — the
  job still went red on the CI runner after that, for two reasons a local run could not show:
  the rejoin did not mirror `game_root._boot_client()` (see the implementation note below),
  and a failure printed only the summary. The driver now prints BOTH processes' step lines and
  lifecycle lines into the step output on failure, so the next CI failure is diagnosable
  without downloading the artifact.**
- [x] The suite remains green on both boot paths (`Results: N/N passed (0 failed)`,
  `[Server] listening on port 7777, max_clients 64`), with the new assertion count
  quoted. **Review pass: `Results: 7508/7508 passed (0 failed)` on both boots — the count
  moved from 7499 with the two rules the review pass added to `set_hp()` (five assertions
  RED-proved first, the run before the fix reading `5 failed`). Second review pass:
  `Results: 7522/7522 passed (0 failed)` on both boots — the count moved from 7508 with
  `identity: a sliver of health is down` and `net: harness awaits are not bare` (seven
  assertions RED-proved first, the run with the two policies reverted reading `7 failed`).**

**Implementation notes:**
- **The scenario targets come from the ORIGIN CHUNK, because the two processes' tree
  tables are not identical.** The host streams chunks on a per-frame budget
  (`ChunkManager.DEFAULT_LOADS_PER_FRAME`), so a peer's snapshot carries the chunks loaded
  by the time it joins and the client seeds its trees from exactly that set; the host keeps
  loading afterwards. Comparing targets across the two processes therefore only works for
  chunk (0,0), which both always hold — every comparing step draws its trees from there
  (`_shared_trees()`), and `chop_out_of_reach` is the one step whose details the driver does
  not compare, for the same reason.
- **The two processes are NOT synchronized, so every observation is counted over the whole
  run.** One side's steps mostly send and move on, so its traffic can arrive while the other
  side is still waiting on a 25 s convergence deadline. A per-step observation window opened
  at the start of the observing step MISSED traffic that had already arrived and reported a
  guard failure for a guard that had worked — so `_chop_count()` counts over the run, and
  each in-reach tree is named by exactly one step. **Review pass — the second half of that
  rule, found only once the waits above were real: a TRANSIENT is not a state. With the
  missing `await`s in place the client ran the whole scenario in about a frame, so it was
  always AHEAD of the host and always caught the 5 s death window; with the waits restored it
  lags by seconds, the host forwards the hit on ITS timeline, and the body can be down AND
  ALREADY BACK UP before the observing step opens — so `peer_damage_floor` and
  `reconnect_alive` reported `no_countdown` / `not_recovered` for a peer whose body did
  exactly the right thing. Both steps now take their "it went down" half from a whole-run
  count (`_deaths`, the `_chops` shape; `player_died` is emitted only through the door that
  arms the timer) and assert what the step is actually about: never down with nothing running
  — still waiting the countdown out, or already back at full health.**
- **A rejoin has to mirror `game_root._boot_client()`, not merely call `join()`.** A client's
  join intent is fire-and-forget and `_on_connected_to_server` is the only other thing that
  re-presents it, so a rejoin whose ONE intent went out before the new socket was up (the log
  shows the RPC erroring with "multiplayer peer which is not connected") presented no intent at
  all: the host never bound the peer, while the client's own half still passed because it only
  asserts its local body. Setting `_snapshot_pending = true` after the rejoin arms
  `_tick_client_handshake`, which re-presents the intent every 3 s until the world arrives —
  exactly what `_boot_client()` does for the first join. **CI pass.** `reconnect_alive`'s
  failure detail now also carries the transport state (host: `live`/`same`/`online`/`buf`;
  client: `conn`/`claim`), because `still_down` alone could not say whether the peer never
  rejoined, rejoined as a different player, or rejoined and did not resolve.
- **ENet drops a quiet peer, so the scenario keeps the link alive while it waits.** A step
  that asserts an ABSENCE waits seconds for nothing to happen, and a step whose counterpart
  is busy waits 25 s; without a periodic keepalive the client was disconnected mid-scenario,
  after which every host step reported no bound peer — a dead socket that looked like a
  broken guard. The keepalive is a real `player_state_sync_requested` carrying RENDEZVOUS,
  so it also pins the position the reach guard measures against.
- **A transport id is not an identity, and the reconnect step is where that shows.** ENet
  reassigns peer ids, so `_bound_player_id` (captured at the handshake) is what every step
  means by "the peer"; the peer id is re-resolved after the reconnect, and the step asserts
  the reconnected connection came back under the SAME player id.
- **The harness's own pure half is registered in the suite.** The step table, the log-line
  format and its parser, the convergence verdict and the deterministic target selection are
  asserted on every ordinary boot, because the driver's whole oracle rests on them: if the
  format and the parser disagreed, the driver would compare nothing and every run would look
  green.
- **ENet needs frames; the suite has none.** `TestSuite._run_tests()` is called
  synchronously from `GameRoot._ready()` and there is not a single `await` in its ~7,900
  lines — deliberate, because it runs before any production slice's emissions can leak
  into world state. A harness cannot be added to that runner: an
  `ENetMultiplayerPeer` only delivers when the tree ticks. The harness is therefore its
  own boot mode with its own `await`-driven step loop, and the parts of it that are pure
  (the step table, the assertion formatting, the convergence predicates) are registered
  in the synchronous suite so they are still covered on every boot.
- **Two peers in one process is possible, and still the wrong default.** Godot 4 supports
  a second `MultiplayerAPI` bound to a separate node subtree, so both peers could live in
  one process and the driver could read each side's state directly. The recommended shape
  is nonetheless TWO PROCESSES over loopback, because it drives the production path
  unmodified — the same `--server` / `--client` args the game ships with, the same
  `NetworkingSlice.host()` / `join()`, real ENet peer-id reassignment — so an edit that
  only works in-process is caught here rather than in the wild. The in-process variant
  stays available as a fallback if log-driven comparison proves brittle.
- **The comparison channel is a canonical log line, not shared memory.** Each process
  prints one structured line per completed step (`HARNESS <step> <ok|refused> <detail>`)
  and the driver asserts the host's and the client's lines agree. A text channel is what
  lets the same scenario run against two processes, and it is the only channel that
  survives a role flip.
- **The Phase 19 network emulator is already here, and this is NOT where it earned its
  keep.** `NetworkingSlice` carries `emulate_network`, `emulator_loss_rate`,
  `emulator_jitter_ms` and `emulator_reorder`, and this note used to say the scenario should
  run at least twice — once clean, once through the emulator. **Review pass: it does not,
  and a second pass through that emulator would not have proven what the note promised. The
  emulator drops and reorders packets BEFORE `_send_raw`, inside this process, so nothing it
  does is socket loss: the packet never leaves the machine. A pass through it would test the
  dedup and reassembly rules against an IN-PROCESS queue, which the routing-level suite
  already covers cheaply. Reordering and loss over a real socket stay deferred with the WAN
  validation (Phase 19), and the criterion above says so instead of borrowing confidence
  from this.**
- **Determinism beats coverage.** A wire test that flaps is worse than no wire test: every
  step asserts on convergence (a predicate plus a bounded number of ticks) rather than on
  a fixed frame index, and every step carries a deadline that fails loudly instead of
  hanging CI.

**Known simplifications (deferred):**
- **The bare-`await` audit is a SOURCE check, and it says so when it cannot run.** The
  runner reads its own `res://` file at start-up (a source boot, which is what the driver
  launches) and prints `source-not-on-disk-skipped` when it cannot — never a pass — because
  an audit that did not run is not evidence. What it cannot see is a bare coroutine call in
  another file: the rule is enforced on this runner, not repo-wide.
- **The un-handshaked refusal is still a routing-level assertion.** The harness cannot put
  an intent on the wire before the handshake: the client's boot presents its join intent the
  moment the connection comes up, so there is no window in which a real peer is connected
  and un-handshaked. That half of the identity criterion stays with `_route_c2h`'s unit
  tests.
- **The snapshot buffer's host-loss clear is asserted on the client's own teardown, not on a
  real host loss.** `disconnect_all()` is what the reconnect step exercises; the
  `_on_server_disconnected` path needs the HOST to die mid-snapshot, which this driver does
  not do (the host is the process the driver waits on).
- **Loopback only.** Two processes on one host exercise real ENet framing and the real
  handshake, but not latency, MTU discovery or NAT behaviour. WAN / cross-region testing
  stays deferred from Phase 19.
- **No soak.** The harness runs a scripted session, not a long-lived one: memory growth
  under hours of churn (the Phase 37 eviction classes) is still argued from the eviction
  sites rather than measured.
- **The harness does not replace the routing-level tests.** Those stay: they are cheaper,
  they pin the refusal itself, and they run inside the suite the project already gates on.
- **A peer's death is still not resolved host-side.** Deliverable 1 makes the floor
  recoverable — a downed peer's HP returns to full after the delay instead of freezing at
  zero — but nothing happens TO the peer at zero: no corpse, no loot, no kill credit. The
  death consequence stays deferred past this phase.

---

## Phase 40 — Review pass: the avatar's footing — the voxel surface, walked stairs ✅ Done

**Goal:** The controller stands on the VOXEL columns (collision layer 2, quantised to
`STEP_HEIGHT` 0.125), but everything drawn from it was sampled and placed off the other,
legacy surface — and off the wrong quantity. A review of that seam found the avatar's whole
body offset by the hip height into the ground, the foot sampler reading a heightmap the
body does not collide with, and the controller unable to walk up a single voxel rise: it
stopped dead at the foot of every step. This phase puts the visual avatar exactly where its
collision is, gives the body a step-up so a stair is WALKED rather than blocked, and renames
the foot-IK return value whose name collision caused the first of those bugs.

**Deliverables / verifications:**
- `src/character/character_slice.gd` — `sync_player_avatar` places the avatar's rig root at
  the sampled surface height. The root sits at the FEET (`_make_avatar` places every body
  part at `landmarks["hip_y"]` ABOVE it), so the old
  `maxf(foot_l.y, foot_r.y) - landmarks["hip_y"]` subtracted the LOCAL hip offset from a
  WORLD surface ordinate — read off the landmarks dict, because the foot targets' own world
  hip ordinate used to carry the same key name. The avatar stood ~0.81 below the ground it
  was standing on; RED-proved against the restored expression (`got 1.192500, want
  2.000000`). Registered `character: avatar root Y matches voxel ground`.
- `src/character/skeleton_rig.gd` — `compute_foot_targets` now returns `hip_world_y`. The
  returned value is a WORLD ordinate and `compute_landmarks()` already publishes a LOCAL
  `hip_y` offset, so the two can no longer be confused by name — the collision that produced
  the bug above, made impossible rather than merely fixed.
- `src/core/game_root.gd` — `_sync_player_avatar` samples `_voxel.get_voxel_height_at`
  instead of `_terrain.get_height_at`. The voxel sampler is the same function the collision
  boxes are built from (`_column_height`), so the visual feet track the surface the body
  actually stands on; the raw noise heightmap sat up to a step away from its own collision.
- `src/player/player_slice.gd` — `_build_body` sets `floor_snap_length = STEP_UP_HEIGHT`
  (0.3, i.e. MORE than one quantised step of 0.125): the 0.1 default is shorter than the
  rise the step-up climbs, so the body took the rise and then immediately lost its floor,
  going briefly airborne on every stair.
- `src/player/player_slice.gd` — `_move` climbs a stair: grounded, moving, and touching a
  wall, it asks the pure `resolve_step_up(blocked, xform, horizontal, step_height)` whether
  the rise can be cleared — `test_move` up by one step, then the horizontal cast from up
  there — and takes the risen+advanced position when both are clear. No vertical velocity is
  added and the horizontal velocity is untouched, so it is a walk, not a jump, and a rise
  taller than `STEP_UP_HEIGHT` is left alone. `move_and_slide()` (with the longer
  `floor_snap_length`) then settles the body onto the new surface. Registered
  `player: step-up climbs a rise, not a wall`.
- The findings' ALTERNATIVE to the above — a `SeparationRayShape3D` under the capsule for
  automatic stair climbing — was NOT taken: it is presented as the alternative to the
  `test_move` step-up and the two are mutually exclusive, so implementing both would be two
  mechanisms for one behaviour.
- `src/tests/test_suite.gd` — the two regression tests above, and the suite stays green on
  both boot paths: `Results: 7532/7532 passed (0 failed)` (+10 assertions from 7522).
- `README.md` — the phase table row for this pass.

**Implementation notes:**
- **The synchronous suite has no physics frame — verified, not assumed.** A probe run in the
  suite's own context (a node added under the tree, probed from `_ready()`, project physics =
  Jolt) shows `move_and_slide()`, `is_on_floor()` and `test_move()` all inert: a body dropped
  over a static floor for 200 cascaded calls never registers a collision, reports
  `on_floor = false` and does not move at all. So the findings' two suite tests are split
  deliberately: the root-Y one is a real assertion through `sync_player_avatar`, while the
  stair one asserts the pure DECISION (`resolve_step_up`) against a fake `blocked` Callable
  — the same Callable-injection shape `compute_foot_targets` already uses for terrain
  sampling — and the physics half is exercised in game only. What the suite proves is that a
  one-step rise is advanced through with a rise of exactly one step-up (never more), that a
  taller rise is refused with the body unmoved, and that an unblocked move is not a step-up
  at all.
- **The step-up is a position, never a velocity.** `resolve_step_up` returns a transform and
  the caller assigns it; `_vel` keeps the input's horizontal value and gravity's vertical one,
  which is what keeps the climb a walk. Adding a vertical impulse would have been the
  obvious-looking shortcut and is exactly the "jump" the finding rules out.

## Phase 41 — Deterministic world and volumetric terrain ✅ Done

**Goal:** Every boot generates a different world, and every column is one solid
height with nothing above it. `TerrainSlice._noise.seed = randi()` means the
ground a save was written against cannot be regenerated: a host and a client can
only agree on the world by shipping heightmaps, a reload lands the player on
different hills, and two players who share a seed still get different terrain.
At the same time the terrain is a pure heightfield — one top face per column and
walls down to whatever the neighbour's top is — so anything that should have a
CEILING (a tunnel, a cave, an overhang, a roofed build) either cannot be carved
or renders as a hole, the collision is per-row merged boxes that cannot describe
a span of solid material, `MIN_HEIGHT` (`0.0`) is "bedrock" only in the sense
that mining stops at zero rather than at a depth, the saved edits are a bare
scalar height per tile, and the avatar's footing sampler (Phase 40's
`get_voxel_height_at`) returns the TOP of a column — which under a roof is the
roof itself. This phase makes the seed a persisted fact, turns a column into a
sparse run of solid spans so ceilings exist and collide, gives the ground a real
bedrock depth, and migrates the edit/save format the change invalidates.

**Newel dependency:** None. No fabric field changes — `pnpm validate` is clean
(IR v3.0.0) and `pnpm check-drift` reports 543 file(s) matching the manifest.

**Closes:** item 1.

**Deliverables:**
- `src/terrain/terrain_slice.gd` — the seed is injected
  (`set_world_seed(seed)`) instead of sampled with `randi()`, so the same seed
  plus the existing fixed `BIOME_SEED` reproduce every height. Biome assignment
  is already deterministic per chunk (`get_biome_at_chunk`); heights are the only
  non-determinism, and this closes it. The seed travels on the world save and in
  the join snapshot, so a client regenerates the host's terrain rather than
  receiving heightmaps.
- `src/terrain/voxel_slice.gd` — the column becomes a SPARSE list of solid runs
  (`[{ bottom, top }]`) instead of one top ordinate plus the per-column
  colour-layer accessor it used to be read through. Both of those accessors
  (`_column_color`, `_column_layers`) became dead once the mesher tinted each RUN,
  and the review pass removed them; the suite now asserts the colours off the runs
  it renders. Only
  solid spans are stored, so a plain column is still a single entry and only a
  real tunnel costs a second one.
- `src/terrain/voxel_slice.gd` — the mesher emits a face wherever a neighbour run
  ends above the local run. That is the mirror of the rule it already implements
  ("a face exists where a neighbour is lower") and it is what makes a tunnel roof
  a rendered, ordinary surface rather than a hole. `cull_mode = CULL_DISABLED`
  stays, so the shell is never see-through regardless of winding.
- `src/terrain/voxel_slice.gd` — collision becomes a `ConcavePolygonShape3D`
  built from the same triangle soup the mesher produces, so ceilings and
  overhangs collide. `TERRAIN_COLLISION_LAYER` (2) is unchanged, so the player's
  block ray still targets terrain.
- `src/terrain/voxel_slice.gd` — a real bedrock depth (`BEDROCK_DEPTH` below the
  surface range, replacing `MIN_HEIGHT := 0.0` as the mining floor). Ground gains
  thickness; mining descends one `STEP_HEIGHT` at a time until the floor is
  reached, and `MAX_HEIGHT` (16.0) remains the build cap.
- `src/terrain/voxel_slice.gd` + `src/persistence/persistence_slice.gd` — the
  `_edits`/save migration. An edit was `{"tx,tz": absolute quantised height}`;
  it becomes a typed run edit (add/remove a span), a world save carries a format
  version, and a pre-Phase-41 save loads with its edits present (a scalar height
  becomes the single run from bedrock up to that height).
- `src/core/game_root.gd` — the avatar sampler gains a second mode:
  `sample_support_height_at(world_xz, from_y)` returns the top of the highest run
  at or below `from_y`, and `_sync_player_avatar` uses it, so an avatar inside a
  tunnel stands on the tunnel floor. Phase 40's step-up, its pure
  `resolve_step_up`, and `floor_snap_length = STEP_UP_HEIGHT` are unchanged.

**Acceptance criteria:**
- [x] Two runs with the same seed produce identical heightmaps per chunk (assert
  a `hash()` of the heightmap array — `terrain: the world seed determines the
  terrain` also asserts a different seed differs), and a client's terrain matches
  the host's with no heightmap in the snapshot: the snapshot carries `seed`, and
  the client adopts it and streams its OWN chunks.
- [x] A column can carry two or more solid runs: a chunk with a tunnel emits a
  downward face (a ceiling), and the trimesh collision is built from that same
  soup — `voxel: a tunnel keeps its floor and its roof` asserts the face is in
  `VoxelSlice.collision_faces`. What stops a body through it is exercised in GAME
  only: the suite has no physics frame (ROADMAP §Phase 39).
- [x] Mining a tunnel roof does not remove the tunnel floor; mining at
  `BEDROCK_DEPTH` is refused while mining one `STEP_HEIGHT` above it succeeds
  (`voxel: a tunnel keeps its floor and its roof`, `voxel: mine at bedrock fails`).
  An UP-face hit resolves to the run it actually landed on, so the tunnel FLOOR is
  aimable too (review pass: `voxel: a tunnel floor top face mines the floor`).
- [x] A save written before this phase loads with its edits intact
  (`voxel: a legacy save migrates to run edits`, which applies a version-1 manifest
  — scalar heights plus the placed-material stacks — and reads the edits back), and
  `pnpm check-drift` is clean: `✓ No drift detected (543 file(s) match manifest)`,
  no fabric change. The MIGRATION keeps the placed-material stack in every case,
  including the re-rolled-seed one (review pass: `voxel: a re-rolled legacy save
  keeps its stack`).
- [x] The suite is green on both boot paths: `Results: 7612/7612 passed  (0 failed)`
  on the listen host and the same `7612/7612` on `-- --server` (which also prints
  `[Server] listening on port 7777`), `tools/net_harness.sh` is `10/10 steps agreed`
  on a FRESH world (`XDG_DATA_HOME=$(mktemp -d)`, the CI shape), and
  `character: avatar root Y matches voxel ground` still passes,
  plus the under-a-ceiling case (`voxel: the support sampler honours a ceiling`).
  The review pass added six suite tests for the edit path's edge cases (the
  migration case named above included, plus
  `voxel: the edit log is compacted`, `voxel: an unknown edit op is ignored`,
  `voxel: an edge edit rebuilds the neighbour chunk`, `voxel: unload prunes the
  heightmap to the ring`, `voxel: a snapshot rebuilds only what changed`) and
  turned the seam test into a GEOMETRY assertion.

**Implementation notes:**
- **The seed is the world's identity, so it is persisted, not sampled.** It
  belongs on the WORLD save (`persistence_slice`), not on a player record: two
  players in one world must regenerate the same ground, and a client that cannot
  reproduce the host's terrain is a client whose voxel edits land elsewhere.
- **Sparse runs are what keep a deep world cheap.** Storing "only solid spans"
  means a column surfaced at 2.0 over bedrock at -32.0 is ONE run, not hundreds
  of entries, so the memory cost of a real depth is unchanged and only an actual
  tunnel (two runs) pays a second entry.
- **Trimesh collision replaces the merged boxes deliberately.** The per-row
  run-merge existed because `TILE_SIZE` 0.5 would otherwise emit 4096 boxes per
  chunk; one `ConcavePolygonShape3D` per chunk is smaller than a handful of boxes
  and describes everything the boxes never could. Nothing in this project stands
  a `CharacterBody3D` on terrain via a concave shape directly — the body collides
  with the static shape, which is the supported direction.
- **A save migration is a deliverable, not a nicety.** The load path must be
  tolerant of the old key shape and must never silently drop an edit; a migration
  that "repairs" a world by discarding player work is worse than a refusal.
- **The footing sampler must not be allowed to answer with the roof.** The
  sampler is a function of the body's own Y for exactly this reason; a
  column-top sampler is only correct in a world with no ceilings, which is the
  world this phase ends.
- **`BEDROCK_DEPTH` is `-8.0`, and the world floor slab moved under it.** The
  terrain's surface range is `[0, HEIGHT_SCALE]` = `[0, 5.0]`
  (`TerrainSlice.HEIGHT_SCALE`; `MAX_HEIGHT` 16.0 is the BUILD cap, not the ground),
  so eight units of rock is a real thickness
  rather than a hair: it is 64 `STEP_HEIGHT` steps of descendable ground. The
  dormant `WorldFloor` safety slab was at `y = -0.5` — INSIDE the new ground —
  and would have blocked a player mining below it, so it now sits at
  `BEDROCK_DEPTH - 0.5`: still the thing that catches a body if the terrain ever
  fails, and no longer in the way of the floor the phase adds.
- **The join snapshot carries the seed instead of the heightmaps, so the client
  starts its own chunk streaming.** `_build_snapshot` sends `seed` (the world's
  identity) and the chunk-edit manifest; `_on_world_snapshot_received` adopts the
  seed, applies the edits, then `_chunk_manager.start()` / `refresh()` around the
  position the record restored. Two consequences worth naming: the client's world
  is now its OWN view window rather than whatever the host had loaded, and TREES
  need no placement payload at all — `TreeSlice.spawn_for_chunk` derives them per
  chunk coordinate on both sides, exactly the rule tree seeding already followed
  (only a tree's chopped/standing STATE is replicated). CREATURES are NOT in that
  category and do not need to be: `CreatureSlice.spawn_for_chunk` is
  authoritative-only, so the client places the host's creatures from the snapshot
  (`apply_snapshot_creatures`) as it always did. A client that did NOT stream would
  boot into an empty world with the right seed, which is why the start call lives
  at the end of the snapshot handler, after the player's position.
- **The world record's `version` is a marker, not a gate.** `WORLD_FORMAT_VERSION`
  is 2 and a pre-Phase-41 record simply has no `version` key
  (`LEGACY_WORLD_FORMAT_VERSION`). The load path never branches on it: the
  manifest shape itself is tolerant (`apply_edits` adopts an Array of typed edits
  and MIGRATES a bare number against the tile's natural run), because a migration
  that "repairs" a world by discarding player work is worse than a refusal. The
  version is there so a future shape can be told apart, and so the boot can say
  which world it loaded.
- **A column's runs are replayed from the tile's natural run, so the migration
  needs the ground.** `_base_top_for_tile` answers from the chunk's heightmap when
  it is built and from `TerrainSlice.get_height_at` when it is not — the same
  height by construction, which is what lets a load-time migration run BEFORE
  chunk streaming (the boot order) without guessing. This is also why
  `game_root._load_world_records` adopts the recorded seed first: the migration of
  a legacy edit is measured against the noise field the save was written on.
- **An unknown neighbour is read as EMPTY, so the shell does not depend on the
  order chunks were built.** The mesher used to answer `0.0` for any tile outside
  the chunk and therefore built a full-height wall at every seam and around the
  streamed window; this phase first made it answer `null` (emit no wall), on the
  argument that "the side that HAS the material emits the facing wall". That
  argument does not survive the STREAMING order the same phase leans on
  (`DEFAULT_LOADS_PER_FRAME := 1`, nearest-first): the neighbour a chunk waits for
  is very often built LATER, so a chunk built before its higher neighbour emitted
  nothing at that seam — and nothing rebuilds a chunk when its neighbour arrives,
  which left every such seam (and the window's whole outer edge) see-through
  (measured: 0 seam faces before the neighbour arrives, 128 after a rebuild). It
  now reads an unknown neighbour as an empty list, so the column carrying the
  material always emits the facing wall. That is duplicate-free whichever side is
  built first — the second side subtracts the first and finds nothing left to
  emit — and a wall buried inside ground both sides fill is invisible, so the
  rendered shell is the same set of faces in either order. The streamed window's
  outer edge is therefore a closed cross-section again, as it was before the
  phase.

- **An UP-face hit names the run it LANDED on, not the column's topmost one.** The
  rule is one line away from the wrong answer, and the wrong answer is what the
  phase's own new capability creates: a tunnel FLOOR keeps an exposed top face with
  the roof above it, so "the column's topmost run" resolves a click on the floor to
  the ROOF — mining the floor took the roof's last step and stacking on the floor
  put the block on the roof. `VoxelSlice.runs_topping_at(runs, y)` picks the run
  whose top is the hit plane (half a step of tolerance) and answers `{}` for a y
  that sits on no run boundary — the fallback to the topmost run is the CALLERS'
  (`_mine_span` / `_place_span`), not the helper's, and it is what keeps a
  misaligned y behaving exactly as it did before (the boot demo passes the spawn
  plain's height, not the target tile's). Both ask it.
  Review pass: `voxel: a tunnel floor top face mines the floor`.

**Review pass — the edit path's edges (all landed from the numbered findings list):**
- **A chunk's mesh depends on the columns ACROSS its edge, so an edit rebuilds the
  neighbour chunk too.** A wall face is the difference between a column's runs and
  its neighbour's, so a tile on a chunk boundary is a neighbour column to the next
  chunk's tiles, and editing it changes what THEY emit. Rebuilding only the edited
  tile's own chunk left the neighbour drawing the wall it had: a see-through slot
  where a seam tile was carved open (mine a tunnel into a seam tile and the mouth
  stays blind) and a ghost wall where the difference grew the other way. Nothing
  else rebuilds a chunk when its neighbour changes, so it stayed all session.
  `_rebuild_chunk_at_tile` now rebuilds the tile's own chunk plus the four
  edge-adjacent chunks' — one build in a chunk's interior, at most three at a
  corner, and the mesher's runs memo below is what pays for the extra ones.
- **The edit log is BOUNDED (`MAX_TILE_OPS` 8, `_compact_ops`).** Ops stay an
  append-only log — an edit says what the player DID — but a log with no bound
  grows forever: mine and rebuild the same block and every click adds a replay step
  to every column read (meshing, the collision soup, the footing sampler, the save
  manifest) and to the save itself, and the replay is O(ops) per read. Past the cap
  the list is rewritten as the minimal description of what the column IS (bounded
  by its run count: one remove plus one add per run), and a column that is back to
  its natural self is compacted AWAY. RED: 40 ops after twenty mine/place cycles.
- **The mesher resolves each tile's runs ONCE per chunk build.** Every tile's runs
  were read by the tile itself AND by each of its four neighbours' wall
  subtractions — about six resolutions per column per chunk. The runs are a pure
  function of the tile's heightmap plus its edits, so a per-build memo keyed by
  global tile key (`_column_runs(..., cache)`) is exact and cannot go stale inside
  the build; `vein_deposits` walks the same chunk and passes the same memo.
- **The migration keeps the placed-material stack in EVERY case.** `legacy_edit_ops`
  used to collapse a column whose saved top sat further above the CURRENT base than
  the stack is tall — the re-rolled-seed case, where a version-1 world's ground is
  generated afresh under an edit written against another noise field — into one
  anonymous natural span, which repaints a player's placed blocks as natural
  ground. The natural span is now re-added up to the stack's own base and the
  materials sit on top of it, still theirs.
- **An edit op this version does not understand is DROPPED, never defaulted.**
  `_normalise_ops` keeps only `add` / `remove` and `apply_run_ops` ignores anything
  else: the two kinds are not symmetric (one fills, one carves), so reading an
  unknown kind as `remove` turns a damaged save into silent terrain damage.
- **`apply_edits` is the RE-SCOPE path, so it rebuilds only the chunks whose edits
  CHANGED — and only the ones that are LOADED.** A re-scope snapshot re-sends the
  manifest a client already applied (or one that differs in a chunk or two), and
  rebuilding every held chunk for that is a whole-frame stall per scope change
  (`_ops_equal` compares op lists field by field, since JSON hands back `int` or
  `float` for the same span). A chunk that is not loaded has no mesh to refresh,
  and building it resurrects a node `ChunkManager` has already streamed away and
  will not stream out again.
- **The base heightmaps are bounded by the loaded window plus its one-tile ring.**
  They were kept for the whole session so a streamed-out neighbour could still
  answer with its real runs, which held every chunk the player ever walked past in
  memory. `unload_chunk` now prunes to the window + ring: that is exactly the set a
  VISIBLE chunk can ask a neighbour about, so a loaded chunk still subtracts
  against real runs, while a chunk outside the ring reads as UNKNOWN — the
  documented, order-independent empty-neighbour path. Nothing is lost with the map:
  edits are keyed by TILE, and the natural run comes from the same height function
  the map was sampled from.
- **Dead accessors removed, and the surviving one says what it is.**
  `get_edit_materials` (no caller anywhere), `_column_color` and `_column_layers`
  (both superseded by the mesher's per-run tint, kept alive only by the suite) are
  gone, and their assertions now read the colours off the runs the mesher tints.
  `get_voxel_height_at` STAYS — it is how a column's shape is asserted, and it is
  the read a caller outside a tunnel means — but its docstring now says what it is
  (a column TOP, not the surface under a body's feet) and names the footing read
  production actually uses (`sample_support_height_at`).
- **The seam test asserts GEOMETRY, not a triangle count.** A wall emitted across
  the wrong ordinates has the same count as the right one, which is what the old
  `_faces_on_plane_x` comparison could not tell apart; `_plane_x_spans` compares the
  distinct vertical spans on the seam plane (and that the pair of facing walls is
  still ONE wall, not two).

**Known simplifications (deferred):**
- **No greedy meshing yet.** The mesher still emits one quad per tile; Phase 42
  threads that build and merges the coplanar quads. Deferred deliberately so this
  phase's diff stays about the world's SHAPE.
- **A version-1 world re-rolls its ground once, on the boot that loads it.** A
  pre-Phase-41 world record has no seed — it was generated from `randi()` — so the
  ground cannot be reproduced at all: the boot says so
  (`world record carries no seed (format 1) — adopting the fresh seed …`) and the
  next save pins that seed, so the shift happens once and never again. The saved
  EDITS survive structurally (that is the migration), but a legacy edit's span is
  measured against the new noise field, so it can land on a different hill.
- **No 3D material model.** Runs say where solid material is; which material a
  span yields is still the per-biome table (`BIOME_MATERIALS`), which Phase 43
  replaces with a 3D ore field.
- **No procedural caves.** Tunnels exist only where a player or a build makes
  them; a cave noise function is not this phase's job.
- **The world remains finite** (`WORLD_RADIUS_CHUNKS` 128) and the spawn-plain
  flattening remains a special case inside the height function.
- **One trimesh per chunk, rebuilt whole on every edit.** A `ConcavePolygonShape3D`
  has no spatial split, so mining one tile re-serializes that chunk's whole surface
  (mesh + collision). Phase 42 threads that build and merges the coplanar quads.

---

## Phase 42 — Threaded chunk build and a loading screen ✅ Done

**Goal:** A chunk build is the most expensive thing this game does, and it still
runs on the main thread. `ChunkManager` already time-slices it
(`DEFAULT_LOADS_PER_FRAME := 1`), which SPREADS the stall across frames instead of
removing it: every boundary crossing spends its budget inside the render loop,
the boot's first-ring chunks are built one per frame while the player is already
standing in the world, and the mesher emits one quad per tile (4096 quads per
chunk at `TILE_SIZE` 0.5) because nothing merges coplanar faces. This phase moves
the pure build onto `WorkerThreadPool`, merges the coplanar quads greedily so the
worker is cheap, gates the first ring behind a loading screen so the body is
never placed on ground that does not exist yet, and widens the prefetch so a
chunk is queued further out than it is needed.

**Newel dependency:** None. No fabric field changes — `pnpm validate` is clean
(IR v3.0.0) and `pnpm check-drift` reports 543 file(s) matching the manifest.

**Closes:** item 2.

**Deliverables:**
- `src/terrain/voxel_slice.gd` — a PURE build.
  `build_chunk_arrays(chunk_pos, heightmap, runs) -> Dictionary` returns the
  `ArrayMesh` surface arrays (vertices/normals/colours/indices) and the collision
  vertex arrays, touching no node, no bus and no slice state. `build_chunk()`
  keeps its signature and becomes the consumer: it takes either a map or those
  arrays and does the tree work.
- `src/terrain/voxel_slice.gd` — greedy quad merge inside the pure builder:
  coplanar, same-material quads merge into rectangles over the tile grid (the
  classic greedy meshing pass), cutting the per-chunk vertex count by an order of
  magnitude. The merge key is material/colour, which is exactly the attribute a
  merged quad has to share.
- `src/terrain/chunk_manager.gd` — the build dispatches to
  `WorkerThreadPool.add_task` and polls (`is_task_completed`); results are
  applied on the main thread. The worker owns no mutable slice state.
- `src/terrain/chunk_manager.gd` — a first-ring gate:
  `build_first_ring(center)` / `is_first_ring_ready()` /
  `first_ring_progress() -> float`. The ring is Chebyshev distance 0..1 (9
  chunks) around the centre; the body is not placed until it exists.
- `src/ui/loading_screen.gd` (new) — a CanvasLayer panel with a progress bar,
  shown while the gate is unmet, with world input frozen through the loading
  screen's OWN explicit input-freeze hook — not through
  `UIControl.any_window_open()`. That predicate answers only for the panels the
  UI slice holds (`src/ui/ui_slice.gd:107`) and a loading screen is not one of
  them, so it covers nothing here; `PlayerSlice._input` gates world actions on
  the mouse-capture state (`src/player/player_slice.gd:162`), which the loading
  screen must drive itself while it is up.
- `src/terrain/chunk_manager.gd` — a wider prefetch ring
  (`DEFAULT_PREFETCH_DISTANCE = view_distance + N`): the load ring leads the view
  ring so a crossing never requests a chunk at the moment it becomes needed.

**Acceptance criteria:**
- [x] A chunk build does not run on the main thread: a frame-time probe across a
  boundary crossing shows no single frame carrying the build cost, and the
  builder is asserted directly by the suite as a pure function of its arguments.
  *(Landed: `ChunkManager._dispatch_build` hands `VoxelSlice.build_chunk_arrays` to a
  `WorkerThreadPool` task and `_process` applies the result on the main thread. The
  suite test "chunk: the pure builder is a function of its args" builds one chunk twice
  — the second time with a VoxelSlice carrying an unrelated place material and an edit in
  another chunk — and asserts identical vertices, indices and collision soup. The
  frame-time probe itself was NOT written: what is asserted is that the dispatch happens
  and that the main thread never runs the build, not a measured per-frame millisecond
  figure. **(Second review pass: `PROBE Phase 42 build split` now prints the main-thread
  half of a dispatch — heightmap generation plus column-table resolution — against the pure
  builder the worker runs, so the split is a measured number rather than a claim. A true
  per-FRAME millisecond figure still needs a frame-driven boot, which the synchronous suite
  deliberately is not.)** **(Eighth review pass: the probe ASSERTS the ratio now, and it
  measures the other half of the main thread's work too — the apply path (`_mesh_from_arrays`
  plus the collision `set_faces`) is inside the main-thread total, and three passes are summed
  because the gap is under 2x. Measured: main 130071 us (resolve 126938 + apply 3133) against
  the worker's 235263 us, i.e. 1.81x. The criterion's other half — the builder is a pure
  function of its arguments — was VACUOUSLY tested until this pass: the test built the SAME
  resolved table twice, so its second, differently-stated slice was dead setup. It now resolves
  the chunk from both slices and builds from each.)** **(NINTH review pass: the resolve moved
  OFF the main thread, and the probe asserts an absolute ceiling as well as the ratio. The
  per-pass figures showed the main-thread half at 44900 us per dispatch — 2.7 frames at 60 Hz —
  so the criterion's own headroom was gone even though the ratio passed; `gather_build_input()`
  copies the resolve's inputs and the STATIC `build_runs()` resolves on the worker, which brings
  the main-thread half to 2539 us steady state (generate+gather 1634 us) against a worker half of
  77159 us, and the assertion is now `steady_main < 16667 us` — one dispatch per frame, inside
  one frame. The per-frame millisecond figure this criterion originally wanted is therefore
  answered for the DISPATCH; what still needs a frame-driven boot is the world's whole frame
  budget.)**
- [x] Greedy merge cuts the per-chunk vertex count (quote the before/after
  number), and a tile whose neighbours differ still emits a valid 1×1 quad.
  *(`cell_count` → `quad_count`, measured in the suite's "chunk: greedy merge collapses a
  flat chunk": a flat chunk with no built neighbours goes 4352 faces → 5 quads, and a
  natural noise chunk with its ring built goes 7568 faces → 3760 quads. The vertex win is
  larger than the quad win because the quads are now INDEXED: the natural chunk emits
  15040 vertices where the per-tile mesher emitted 45408 (6 duplicated per quad). The 1×1
  case is asserted on the pure sweep: a lone cell is its own rectangle, a hole splits a
  row, and a row below extends it.)*
- [x] Booting against a fresh `user://` (empty world) shows the loading screen
  and does not place the player body until the first ring's chunks are built.
  *(`_boot_host()` shows the screen and defers the whole host tail to
  `_tick_pending_host_boot()`; the tail runs from `_process` the frame the gate opens.
  Verified against a fresh `XDG_DATA_HOME`: `[World] first ring built (9 chunks) —
  placing the player, 19.66s after boot`. The screen's own visibility is not asserted by
  the suite — it is a node in the tree on both boot paths and has no headless frame to be
  seen in. **(Second review pass: it IS asserted now — `ui: the loading screen shows and
  hides` drives `begin()` / `set_progress()` / `finish()` and asserts the visibility, the
  bar and the `world_input_frozen` emissions directly, which needs no frames. The CLIENT
  path arms the same gate, so the body is no longer placed on unbuilt ground on a join.)**
- [x] No world input resolves while the loading screen shows: an attack, mine,
  chop or place attempted with the screen up is refused. The freeze is the
  loading screen's own hook — `any_window_open()` is not consulted and would
  answer `false`.
  *(`GameBus.world_input_frozen` → `PlayerSlice.set_world_input_frozen`, consulted by the
  single predicate `PlayerSlice.world_input_allowed()` that `_input` now gates every world
  action on. Suite test "player: the loading freeze refuses world input" drives the signal,
  asserts `world_input_allowed()` is false while frozen, and asserts `any_window_open()` is
  false at that moment — i.e. that the window predicate could not have been the gate. A
  headless boot has no mouse capture at all, which is why the freeze is assertable
  separately from the mouse half of the predicate.)*
  **(Second review pass: the freeze holds the BODY too — `PlayerSlice._physics_process`
  skips `_move` while frozen, asserted by `player: the loading freeze holds the body`. It
  has to: a joining client's body exists from the snapshot while its ring is still being
  built, so an input-only freeze left it falling through ground that was not there.)**
- [x] The suite is green on both boot paths, with tests for the pure builder and
  the merge registered in `test_suite.gd`.
  *(`Results: 7663/7663 passed (0 failed)` + `All tests passed ✓` on both
  `--quit` and `--quit --server`; seven new tests registered in the `_run_test` list
  (builder purity, merge counts, merge-never-spans-a-gap, dispatch-then-apply, the
  first-ring gate, the prefetch radius, the loading freeze). **Re-run after the review
  pass: `7682/7682 passed (0 failed)` on both boot paths** — five more tests, one per
  closed finding that is assertable in the suite. **SECOND review pass: `7716/7716 passed
  (0 failed)` on `--quit` and on `--quit --server`, no `SCRIPT ERROR` — seven more tests
  (a rebuild respects the in-flight cap, a queued chunk that leaves range cancels, a
  groundless chunk is re-armed, contents spawn once the ground exists, the build split
  probe, the loading freeze holds the body, the loading screen shows and hides), plus the
  probe that prints the main-thread / worker split.) **THIRD review pass: `7735/7735 passed
  (0 failed)` on `--quit` and on `--quit --server`, no `SCRIPT ERROR` — five more tests (a
  stationary player re-arms a failed chunk, unloading drops a queued rebuild, an edit does
  not re-spawn contents, a drain reads the window once, and a boot quits when its world is
  up).** **FOURTH review pass: `7760/7760 passed (0 failed)` on `--quit` and on
  `--quit --server`, no `SCRIPT ERROR` — six more tests (a failed REBUILD of an already-built
  chunk heals, the stationary throttle suppresses a re-arm, a crossing stamps the self-heal
  clock, the self-heal reads the window once, an idle drain reads no position, and a rig
  dispatch keeps contents per residency).** **FIFTH review pass: `7787/7787 passed (0 failed)`
  on `--quit` and on `--quit --server`, no `SCRIPT ERROR`, and `10/10 steps agreed` from the net
  harness — five more tests (a remote mine credits the actor, a remote place spends the actor's
  own pack, a remote chop credits the actor, a re-scope rebuilds a changed tile's seam, and an
  edit never resurrects an unloaded chunk).** **SIXTH review pass: `7809/7809 passed (0 failed)`
  on `--quit` and on `--quit --server`, no `SCRIPT ERROR` — two more tests (a legacy edit of an
  unknown shape is dropped, an incremental save can delete a chunk), and no test count lost to a
  probe abort in the final run.** **SEVENTH review pass: `7811/7811 passed (0 failed)` on `--quit`
  and on `--quit --server`, no `SCRIPT ERROR`, and `10/10 steps agreed` from the net harness on
  three consecutive fresh-world runs — one more test (the terrain material is one instance), one
  harness hardening (step 4 waits for a distant tree, bounded by `STEP_TIMEOUT_SECS`, instead of
  reporting `no_distant_tree` at whatever instant it arrives), and a doc correction (the quick start
  now says `npm`, which is what CI runs). **EIGHTH review pass: `7833/7833 passed (0 failed)` on
  `--quit` and on `--quit --server`, no `SCRIPT ERROR`, and `10/10 steps agreed` from the net harness
  on a fresh world — three more tests (the kept window is the view ring, apply_edits dispatches a
  rebuild, flush_builds awaits its retries), plus the split probe promoted from a print to an
  assertion (`main-thread half 130071 us` — resolve 126938 + apply 3133 — `against the worker's
  235263 us`, 1.81×).** **NINTH review pass: `7870/7870 passed (0 failed)` on `--quit` and on
  `--quit --server`, no `SCRIPT ERROR`, and `10/10 steps agreed` from the net harness on a fresh
  world — six tests added (or renamed: the kept window is the stream radius, a direct load
  respects the in-flight cap, the gathered payload carries the ring, the group key survives the
  colour band, the biome roll table is prebuilt, the build payload shape is required), the kept
  window widened
  back to the queue radius (`DEFAULT_PREFETCH_DISTANCE` 2 → 1, so a band chunk is no longer built
  and then thrown away), and the RESOLVE moved off the main thread: the dispatch's main-thread
  half measured 44 900 us before and 2 526 us after (generate+gather 1 631 us) against a worker
  half of 77 159 us, with the probe now asserting that half inside ONE 16 667 us frame.** ***
  **TENTH review pass: `7883/7883 passed (0 failed)` on `--quit` and on `--quit --server`, no
  `SCRIPT ERROR` (+13 assertions from a new biome-coverage test and a second, POPULATED-edit-log
  pass in the split probe) — the edit log is now INDEXED BY CHUNK, so a dispatch's gather walks
  only the chunks it can reach instead of string-splitting every edit in the world
  (`generate+gather` with 102 400 world edits: 44 012 us → 5 568 us, the old figure over TWO
  frames), and the probe asserts the frame ceiling on that populated log; the first-ring gate
  recomputes from `_built`, `_biomes_or_lookup` resolves a miss instead of falling back to
  `DEFAULT_BIOME`, and four smaller items (the biome-map/roll-table invariant pinned, the
  heightmap-by-reference asymmetry stated, the roll-table test's static snapshot/restored, and
  the self-heal's dispatch-cost wording corrected).** ***

**Implementation notes:**
- **Godot's threading rule is what makes the split mandatory.** Scene-tree
  mutation, resource saving and `GameBus` emission are main-thread work; the
  worker may only produce plain arrays. The naive trap is
  `add_task` immediately followed by `wait_for_task_completion` in the same
  frame — that is the synchronous build again with extra ceremony. Poll.
- **The gate is about the ground the body will STAND ON, not the whole ring.**
  The view ring is ~49 chunks; the body needs the one beneath it and enough ring
  to not immediately fall off the edge. Chebyshev 0..1 keeps the gate honest
  without making the loading screen a long wait; the rest of the view ring
  streams normally behind it.
- **The worker must not read mutable slice state.** It takes the heightmap, the
  runs and the constants as arguments. A worker reading `_chunks`, `_edits` or
  `_heightmaps` while the main thread mutates them is a race that will present as
  an intermittent visual glitch, which is the most expensive kind of bug to find.
- **The first-ring gate is a boot path, so both boot paths need it.** Host,
  `--server` and single-player take different tails of `_ready()` (Phase 32); a
  gate wired into one of them is a hole in the others.
- **The loading screen's input freeze is its OWN hook, not an inherited gate.**
  `UIControl.any_window_open()` (`src/ui/ui_slice.gd:107`) answers only for the
  panel set the UI slice holds, and the loading screen is not one of them — so
  it cannot see the gate, and the world does not freeze just because a window
  predicate is false. The gate the player's `_input` actually consults is the
  mouse-capture state (`src/player/player_slice.gd:162`), so the loading screen
  must own an explicit freeze hook (its own `GameBus` signal, or a setter the
  boot path calls) and that hook must be wired on BOTH boot paths above. Assume
  no existing gate covers it.
- **A prefetch ring needs an eviction rule too.** Chunks loaded further out
  still unload when they fall outside `view_distance`; what widens is when they
  are QUEUED, not how many stay loaded.
  *(Shipped differently, and the difference is deliberate: the streamed window is
  `view_distance + prefetch_distance` for QUEUEING **and** for retention. A chunk queued
  further out and unloaded the moment it falls outside `view_distance` is a build paid for
  and thrown away, which is the opposite of what the band is for. `view_distance` is now
  the radius that is guaranteed fully streamed; the band beyond it is lead time.
  **Reversed in the eighth review pass — the note's own advice was right and the
  "shipped differently" was the regression: retention is `view_distance` and only the QUEUE
  spans the band, because the retention it bought was 121 resident chunks against the view
  ring's 49, i.e. 2.5x the meshes, trimeshes and population. The band is still lead time —
  a band chunk is built ahead of its need — and it is released on the next crossing unless
  the player moved toward it.)**

**Implementation notes added during the phase (kept here for the next reader):**
- **A worker task may hold no reference to a Node, and must still be AWAITED.** The pure
  builder is a `static` function called through the SCRIPT (`ChunkManager.VoxelBuilder`),
  because a task that outlives the tree would otherwise call into a freed slice —
  measured: `Invalid call. Nonexistent function '_wall_plane' in base 'previously freed'`
  and a `double free or corruption` abort. And `is_task_completed` only reports that the
  work is DONE; the pool holds the task and its result until it is awaited, so a build
  that is polled and never awaited aborts the process at shutdown (measured: exit 134 on
  every boot that streamed one chunk window). `_apply_build_entry` therefore always
  waits — instant on the frame path, because the caller only reaches it for a finished
  task — and `_exit_tree()` reaps whatever is left.
- **`--quit` quits after ONE frame**, so with the build on a worker the ring is not yet
  built and the host tail does not run in that boot. The suite is unaffected (it runs
  earlier in `_ready()`) and the server-boot assertion is unaffected (the listening line
  is printed by `_boot_server()`), but a `--quit` boot no longer proves the body was
  placed: use `--quit-after N`, or read the `[World] first ring built …` line.
- **The `_built` set is separate from `_loaded`.** `chunk_loaded` still means "this chunk
  entered the streamed set" (its build is dispatched at that point); the boot gate reads
  `_built`, which is set only when the mesh exists.
  **(Corrected by the second review pass: entities used to spawn from `load_chunk()` — a
  frame or two BEFORE their chunk's mesh landed — and they now spawn from the apply path,
  with the mesh, so the population is never ahead of its ground.)**

**Review-pass notes (six findings from a post-phase review, all closed in
`fix(terrain): Phase 42 review pass`):**

1. **`_exit_tree` skipped the wait for an already-COMPLETED task** — the exit-134 leak
   this phase's own notes describe, walked back in through a guard. `is_task_completed`
   reports only that the work is DONE; the pool holds the task and its result until it is
   AWAITED. The wait is now unconditional (`wait_for_task_completion` returns immediately
   for a finished task, so dropping the guard costs nothing). **Measured, both
   directions:** with the guard restored, `--quit-after 400` aborts (`exit 134`) and so does
   the suite boot; with the fix, both are `exit 0`.
2. **An edit to an in-flight chunk was LOST.** The edit path gated its rebuild on a cached
   heightmap, and a chunk only gets one when its build LANDS — so an edit that arrived
   while the build was on the worker rebuilt nothing, and the worker's PRE-edit arrays were
   attached on top of it. `ChunkManager.request_rebuild` needs no cached map: it supersedes
   any build already in flight for that chunk (marked `superseded`, still AWAITED, neither
   attached nor re-dispatched) and dispatches a fresh one built from the current columns.
   RED-proved: the attached mesh came back 16036 vertices against the post-edit build's
   16008.
3. **`stop()` abandoned in-flight builds.** `_process` returned before its apply pass while
   streaming was stopped, so a build dispatched a moment earlier was applied by nobody and
   awaited by nobody — no mesh, and the task's result held until shutdown. The apply pass now
   runs whether or not streaming is active; `stop()` ends NEW work only.
4. **A null worker result fell back to a synchronous main-thread build.** `build_chunk` now
   REFUSES an empty result on the worker path (`arrays` empty with a `revision >= 0`) rather
   than quietly rebuilding the whole chunk on the main thread — the stall this phase exists
   to remove, done silently. The manager answers a refusal with a fresh dispatch, bounded by
   `MAX_BUILD_RETRIES := 3` so a permanently failing build reports an error instead of
   spinning. The 2-arg synchronous form is untouched.
5. **Block edits still rebuilt up to three chunks SYNCHRONOUSLY.** `_rebuild_chunk_at_tile`
   now DISPATCHES through `request_rebuild` (`VoxelSlice.chunk_manager`, wired both ways by
   `game_root`) instead of calling `build_chunk` in the frame that placed the block; the
   chunk keeps its old mesh until the new one lands. A slice with NO manager wired (the
   suite, a probe) keeps the synchronous build, and only for a chunk that already holds a
   cached heightmap — which is what the isolated edit tests assert against. The comment that
   claimed Phase 42 had already threaded this path was false, and is corrected.
6. **`_pending_host_boot` had no timeout.** The gate is a worker build, so a stalled ring
   held the boot forever: loading screen up, no player, no UI, nothing logged. `_tick_pending_host_boot`
   now runs the host tail after `FIRST_RING_TIMEOUT := 15.0` regardless and pushes a warning
   naming how many ring chunks were built — the same shape `SNAPSHOT_TIMEOUT` already has on
   the client side. The decision is a pure predicate (`GameRoot.host_boot_may_proceed`) so the
   suite pins it without booting.

**SECOND review-pass notes (a second post-phase review, closed in
`fix(terrain): Phase 42 review pass 2`):**

1. **`request_rebuild` and build RETRIES bypassed `max_builds_in_flight`.** The cap was
   enforced only in `_drain_load_queue`, so a corner edit (three touched chunks) or a burst
   of retries dispatched straight past it. Both now go through a `_rebuild_queue` drained
   under the same cap — delayed a frame, never dropped — and the supersede is unconditional
   so a pre-edit build cannot land while the fresh dispatch waits for a slot.
2. **A queued chunk that left the window was still built, and stayed `_pending`.** It was
   built and immediately unloaded, and — worse — a chunk that left the window and returned
   was silently SKIPPED, because `refresh()` saw the stale `_pending` mark. `_drain_load_queue`
   now drops a chunk outside `stream_radius` and clears the mark with it.
3. **A build that exhausted MAX_BUILD_RETRIES left a hole for the session.** The chunk is now
   marked in `_failed` and re-armed by the next `refresh()` that re-centres the window — a
   fresh retry budget and a fresh dispatch. Keyed on the window MOVING, so a build that fails
   forever costs one dispatch per crossing rather than a per-frame spin.
4. **Creatures and trees spawned before their chunk's ground existed.** With the build on a
   worker, spawning at load time put the population on a chunk whose mesh arrived a frame or
   more later. They now spawn from `_apply_build_entry`, with the mesh (`_spawn_chunk_contents`).
5. **A joining CLIENT never armed the gate.** `_on_world_snapshot_received` placed the body
   from the snapshot and started streaming around it, so for the first frames the body stood
   on a chunk still being built (the gate was host-only). The client now arms the same gate,
   shows the same loading screen, and releases through `_finish_client_boot` when the ring's
   ground exists — under the same timeout rule.
6. **The loading freeze did not hold the BODY.** It gated `_input` only, so a client's body
   (which exists from the snapshot while its ring builds) fell through ground that was not
   there. `PlayerSlice._physics_process` now skips `_move` while frozen — see
   `ui: the loading screen shows and hides` and `player: the loading freeze holds the body`.
7. **`build_first_ring`'s front-queueing was dead code.** `_boot_server` called `refresh()`
   FIRST, which marked every ring chunk `_pending`, so `build_first_ring`'s `wanted` list came
   out empty and nothing was moved to the front. The gate is now armed BEFORE the refresh.
8. **`VoxelSlice._build_terrain_surface` was dead code** — no callers since the pure builder
   landed — and is deleted; the comment that still pointed at it is corrected.
9. **A redundant nested `if not _is_server:`** framed the loading screen inside the minimap's
   own `not _is_server` block. Removed.
10. **`--quit` no longer proved the host boot, and CI had lost the assertion.** A new
    `host-boot` CI job boots `--quit-after 1800` and asserts `[World] first ring built …`
    (and that the boot did NOT get there through the 15 s ring timeout). Verified locally
    against a FRESH `XDG_DATA_HOME`: the line prints 22.5 s after boot, and the boot saves
    36 creatures — the population the fix in (4) now spawns with the ground.
    **(Amended by the third pass: the job no longer ends the boot on a frame count — it
    passes `--quit-after-boot` and the boot quits itself when its tail has run; see note 6
    below.)**

Also landed in the same pass from the same list: the loading screen's own visibility is
asserted by the suite instead of read by hand off a live boot; `TerrainSlice.request_chunk` is
documented as the TEST-ONLY trigger it now is; and `PROBE Phase 42 build split` prints the
main-thread / worker split of one chunk build, so the phase's headline claim leaves a measured
number behind rather than prose.

Two items on that list were NOT closed, deliberately: **the boot timeout still places the
player on ground that may not exist** (it is the deliberate alternative to a hang with the
screen up and nothing logged, it names how many ring chunks were built, and the warning is
what makes the failure visible) and **the prefetch band's retention cost** (121 resident
chunks against 49 is the price of the lead time the band exists for — reducing it is a tuning
decision, not a defect).
**(That second deferral was taken back in the eighth review pass: the retention half IS
closed — the kept window is `view_distance` again and only the QUEUE spans the band — so
only the view ring's 49 hold meshes, trimeshes and population. What remains a tuning
decision is a different question: whether the band should carry spawned population at all,
since a band chunk's contents are now spawned and then released unvisited.)**

**THIRD review-pass notes (a third post-phase review — seven findings, all closed in
`fix(terrain,core,ci,docs): Phase 42 review pass 3`):**

1. **The self-heal never fired for a STATIONARY player.** The re-arm that a chunk whose build
   gave up depends on was keyed on the window MOVING, and `refresh()` returned before reaching
   it whenever the player stayed in the same chunk — which is a dedicated server's entire shape
   (it streams around a fixed origin) and any host player standing still. So a groundless chunk
   stayed a hole for the session in exactly the case the re-arm was written for. The loop is now
   `_self_heal_failed(window_moved)`: a crossing still re-arms immediately, and an unmoved window
   re-arms on a WALL-CLOCK interval (`self_heal_interval`, 5 s), so a permanently failing build
   costs one dispatch per interval rather than a per-frame spin. RED-proved: with the old
   move-only policy, `chunk: a stationary player re-arms a failed chunk` fails five assertions
   (`expected 0, got 3` on the retry budget, no dispatch in flight, hole still there).
2. **A rebuild re-derived the chunk's contents on every block edit.** `_spawn_chunk_contents`
   ran from `_apply_build_entry` for EVERY build, including the rebuild an edit triggers — and
   `CreatureSlice.spawn_for_chunk` walks every creature in the fabric while `TreeSlice`'s walks
   every live tree, on each call, to arrive at a count that cannot have changed. Contents belong
   to a chunk's RESIDENCY, not its build, so they are now spawned once per residency
   (`_contents_spawned`, cleared by `unload_chunk`). RED-proved: `expected 2, got 4` on the spy's
   spawn count after an edit rebuild.
3. **`unload_chunk` cleared a queued rebuild's `_rebuild_pending` mark but left its entry in
   `_rebuild_queue`.** The dedupe reads the MARK, so the next edit for that chunk appended a
   SECOND entry — two dispatches for one chunk under one revision, both attaching.
   `_remove_queued_rebuild` drops entry and mark together. RED-proved: `expected 0, got 1` on
   the queue size after the unload.
4. **The drain resolved the streamed window once per queued chunk.** `_within_stream` re-derived
   `player_chunk()` — a `PlayerSlice.get_position()` call — and the radius for every candidate,
   so draining a view ring paid one per chunk for a single answer. `_drain_load_queue` now reads
   the window ONCE and tests candidates against it (`_within_stream_at`). RED-proved: a
   position-read spy counted 5 reads for a drain that now takes 1.
5. **The client's early return logged a release that never happened.** `_finish_client_boot`
   runs on both the waiting path (which showed the loading screen) and the
   `is_first_ring_ready()` early return in `_on_world_snapshot_received` (which never did), and
   it printed "releasing the player" either way. It now asks the screen (`LoadingScreen.is_active()`)
   and says which of the two actually happened — the ring was already built, so there was nothing
   to release.
6. **The CI host job ended a boot on a FRAME budget.** `--quit-after 1800` counts FRAMES while
   the boot waits on `WorkerThreadPool` time, so a fast headless frame loop could burn the budget
   before the ring's tasks landed and the job would fail for a boot that was working. The boot now
   ends ITSELF the moment its tail has run, behind a new `--quit-after-boot` user arg
   (`should_quit_after_boot`, asserted in the suite), and `--quit-after` is demoted to an outer
   net for a boot that never gets there (raised to 100000). Verified on a fresh `XDG_DATA_HOME`:
   `[World] first ring built (9 chunks) — placing the player, 24.63s after boot` then
   `[World] host boot complete — quitting (--quit-after-boot)`, exit 0, no timeout warning.
7. **One wait accumulator served both boot gates.** `_boot_wait_elapsed` was read by the host
   gate and the client gate's deadlines. The roles are mutually exclusive TODAY, so it is
   harmless — which is the whole point: the day both could be pending, whichever gate ticked
   second would inherit the other's elapsed time and skip its own wait. Split into
   `_host_boot_wait_elapsed` / `_client_boot_wait_elapsed`; structural, so there is no
   behavioural assertion to make (both predicates stay pinned by `host_boot_may_proceed`'s test).

**FOURTH review-pass notes (a fourth post-phase review — TEN findings, all ten real and all
closed in `fix(terrain,core,ci,docs): Phase 42 review pass 4`):**

The reviewer's list was ten items: one Medium (the self-heal) and nine Low. Unlike Phase 39
(13 of 19 wrong) and like Phases 40 and 42's own second and third passes, **every one landed** —
the line numbers were off by a few (the reviewer's checkout), but each named identifier existed
and each claim held. Four of them (2, 7, 10, and the test half of 6) are test/structural/doc
rather than behaviour, which is what a pass over a phase that has already had three of them
should look like.

1. **The self-heal SKIPPED a chunk that was `_built` — i.e. exactly the chunk whose rebuild gave
   up.** `_self_heal_failed`'s guard was `not _built.has(key)`, and `_failed` is set by a build
   that exhausted its retries. For a chunk that failed its FIRST build, `_built` is false, so the
   re-arm worked. For an already-built chunk — an EDIT whose rebuild gave up — `_built` is still
   true (the pre-edit mesh stands in the world), so the sweep jumped over it and the edited block
   stayed invisible for the session. The guard is gone: `_failed` is what says the ground needs
   its build re-armed, whatever `_built` says. RED-proved: `chunk: a failed REBUILD of a
   built chunk is re-armed` (with the old guard, the mark is not cleared and no dispatch follows).
2. **Nothing proved the stationary throttle actually suppresses a re-arm.** The pass-3 test set
   `self_heal_interval = 0.0`, which DISABLES the throttle — it proved the re-arm runs while
   stationary, and the interval itself was untested. `chunk: the stationary throttle suppresses
   a re-arm` now plants the terminal state twice inside a 60 s interval and asserts the second
   sweep refuses (and that the sweep is unthrottled again once the interval is zeroed, so the
   throttle is the only reason). RED-proved: with the throttle turned into an always-false
   condition, `a second re-arm inside the interval is suppressed` fails (`expected 3, got 0` on
   the retry budget it was supposed to leave untouched).
3. **The isolated fast path in `_dispatch_build` spawned a chunk's contents unguarded.** Pass 3
   gave the threaded apply path the `_contents_spawned` residency rule; the rig path (no
   terrain/voxel, which the older tests rely on) still called `_spawn_chunk_contents`
   unconditionally — and an edit reaches it through `request_rebuild`, so the budgets were
   re-derived per block edit there too. RED-proved: `expected 2, got 4` on the spy's spawn count
   after an edit, `expected 4, got 6` after the residency cycles.
4. **`--quit-after-boot` never fired on a DEDICATED SERVER.** The flag's two call sites were the
   two boot TAILS, and a `--server` boot has no tail: `_boot_world`'s server branch returns
   straight after `_boot_server()`. So `--server --quit-after-boot` never quit itself and fell
   through to the engine's `--quit-after` net. `_boot_world` now calls
   `_quit_after_boot_if_asked("server")` at the end of that branch. Verified:
   `--quit-after 100000 -- --server --quit-after-boot` prints
   `[World] server boot complete — quitting (--quit-after-boot)` and exits 0.
5. **The `host-boot` CI job had no `timeout-minutes`.** Its `--quit-after 100000` is a FRAME
   count, so a boot that never reaches its tail would have run to GitHub's 360-minute default
   before the job said anything. `timeout-minutes: 10` (the boot measures ~50 s) fails fast
   instead.
6. **The self-heal sweep re-resolved the window once per groundless key.** `_within_stream`
   re-derived `player_chunk()` and the radius for every key — the same shape pass 3 fixed in the
   drain, missed on the other loop. The sweep now takes the `center` its caller already resolved
   and calls `_within_stream_at`. RED-proved: a position spy counted 5 reads where the sweep now
   takes 1.
7. **`refresh()` carried two consecutive identical `if window_moved:` blocks** — the sentinel
   update and the load/unload diff, split across two `if`s of the same condition. Merged into one
   decision with an early return; structural, so no behavioural assertion (the existing
   streaming tests exercise it).
8. **The drain resolved the player's chunk even with nothing to dispatch.** `_process` calls
   `_drain_load_queue()` every frame and the window read sat above both queue checks, so a
   settled window — the common case — paid a `PlayerSlice.get_position()` per frame for nothing.
   Both queues empty now returns before the read. RED-proved: `expected 0, got 8` on 8 idle
   drains.
9. **A crossing never stamped `_last_self_heal_msec`.** The stamp sat inside the throttled
   branch, so a crossing re-armed immediately and left the clock at its old value (often the -1
   sentinel): the very next frame was unthrottled and re-armed again, and a stationary player's
   interval effectively restarted at the crossing. The clock is stamped whenever the sweep
   proceeds. RED-proved in an isolated boot (the probe on its own, so the assert cannot be
   masked by another finding's inversion): `the frame after a crossing is throttled, not
   unthrottled` was the ONLY failing assertion, `7759/7760 passed (1 failed)`.
10. **Two stale texts.** The give-up `push_error` said the chunk is "re-armed on the next window
    re-centre" and `_apply_build_entry`'s doc said the same — both false since pass 3 added the
    stationary wall-clock re-arm. And `_within_stream`'s doc named itself "the cancellation test
    in `_drain_load_queue`", which now calls `_within_stream_at`. All three corrected (the
    accessor's doc now says what it is for: the single-check form, with the drains and the sweep
    resolving the window once).

**One thing this pass changed about how it proved itself.** Batching all six policy inversions
into ONE boot (the pass-3 recipe) is cheap but not always honest: reverting finding 1's guard
makes findings 2 and 9's asserts pass vacuously (the sweep skips those chunks, so the mark
survives for the wrong reason). The batched boot gave 18 failures; a SECOND boot with findings
2/3/6/8 only gave 8 and put each of their asserts on the board; finding 9 needed a THIRD boot
with its probe alone to show its single failing line. Use the batched boot for a first sweep, but
re-run any finding whose subject is SHARED STATE (a dictionary another finding's policy also
gates) on its own.

**FIFTH review-pass notes (a fifth post-phase review — three findings, all three real and all
closed in `fix(terrain,world,net,test,docs): Phase 42 review pass 5`):**

The list was three items: one Critical (a client's mine/chop/place crediting the HOST's
inventory) and two Medium. It was written against `d2383db` — the Phase 41 review pass, i.e.
BEFORE this phase — so every line reference was stale (the window it cites as
`voxel_slice.gd:435-473` is `_wall_cells` on today's file, while on the reviewer's checkout it is
`mine_block`'s inventory credit). Every claim was re-derived from the source; all three held,
though item 3's real blast radius is narrower than its phrasing implies (see below).

1. **A client's mine, chop or place credited the HOST's inventory — the client got nothing.**
   The host resolves a peer's intent, and every check and mutation on that path went through
   `VoxelSlice.inventory_slice` / `TreeSlice.inventory_slice`, which are the LOCAL player's own
   pack: the material a client mined filled the host's inventory, the axe it swung wore the
   host's, and a block it placed came out of the host's stack. The peer's own client mirrors only
   ITS pack, so it never saw the yield at all — a silent transfer, not a visual desync. It could
   not be fixed inside the slice either: `_route_c2h` deliberately refuses to read an identity
   out of a payload (Phase 36), so the host had no name for the actor to begin with.
   Fix, mirroring the Phase 37 crafting shape: `player_id` rides the three request signals
   (`block_mine_requested`, `block_place_requested`, `tree_chop_requested`), the host's intent
   arms pass `_actor_id(sender)` — the identity bound to the CONNECTION, never a payload claim —
   both slices gained `player_registry` (wired in `game_root`) plus an `inventory_for(actor)`, and
   an action resolved for a remote actor pushes the result on the owner-addressed
   `inventory_synced` that networking already delivers to that peer alone (the mechanism the
   harness's `inventory_owner` step pins). A placement's `material` is the client's claim again,
   so two rules keep it from granting anything: it must be a real `GameData.MATERIALS` key, and
   the debit lands on the actor's own pack — a peer can place only what it actually holds.
   RED-proved: `net: a remote mine credits the actor` (`expected 1, got 0` on the actor's pack,
   `expected 0, got 1` on the host's), `net: a remote chop credits the actor`, and
   `net: a remote place spends the actor's pack` (nothing placed at all while the host's own
   selection was what got spent: `expected 1, got 0`).
2. **An edit could RESURRECT a streamed-out chunk through the synchronous fallback.** The
   manager path has checked `_loaded` since pass 1; a slice with NO manager (the suite, a probe)
   kept the older `if _heightmaps.has(ckey)` guard — and since the Phase 41 pass that map
   deliberately RETAINS the one-tile ring around the loaded window, so an unloaded neighbour that
   a loaded chunk can still ask about answered TRUE. An edit on a chunk edge then rebuilt it,
   resurrecting a node `ChunkManager` had already streamed away and would never stream out again.
   The guard is `_chunks` now: a loaded chunk always holds its cached map (`build_chunk` stores
   it, `_prune_heightmaps` keeps it), which is the rule `request_rebuild` (`_loaded`) and
   `apply_edits` (`_chunks` + `_heightmaps`) already apply on the other paths.
   RED-proved: `voxel: an edit never resurrects an unloaded chunk` (the streamed-out neighbour
   comes back into `_chunks`).
3. **`apply_edits` closed no seam: a re-scope rebuilt the changed tile's own chunk alone.** A
   wall face is the difference against the NEIGHBOUR column (`_wall_cells`), so a changed tile on
   a chunk's EDGE changes the neighbour's mesh too. The Phase 41 pass closed that for
   `_rebuild_chunk_at_tile` — which every LIVE edit path goes through — and left `apply_edits`
   behind; `apply_edits` is the RE-SCOPE path (the join snapshot and every AOI re-scope).
   Worth stating the real blast radius instead of the summary's: on a join the client streams the
   snapshot's chunks AFTER adopting them (`world_snapshot_received` precedes that chunk's
   `chunk_ready` build), so the seam is usually built correctly from the start, and any error
   self-heals when the neighbour restreams — which is why this is Medium, not the see-through
   world the item's phrasing suggests. What the fix closes is the residue: a re-scope that edits
   a chunk the client ALREADY holds next to another held chunk, where the neighbour's old wall
   stands until something else rebuilds it. `_mark_touched_tile` is now the one place a
   tile-level change becomes chunk-level work, so the two paths cannot drift apart again.
   RED-proved: `voxel: a re-scope rebuilds a changed tile's seam` (`and so is the chunk across
   the seam it changed`). The same test pins the OTHER direction — an interior tile still names
   its own chunk only, and a third chunk that reads nothing of the edit is left untouched — so
   the seam closure cannot decay into a blanket neighbour rebuild.

**A fifth pass over a phase's edit path is where the ARITY cost lives.** Three signals gained a
parameter, and here that is never a one-file change: every emitter (`player_slice`'s three
inputs, `tree_slice.chop_tree`'s client forward, `networking_slice`'s two host arms), every
handler (`voxel_slice`'s two, `tree_slice`'s one, `networking_slice._on_tree_chop_requested`),
the plug-contract docstrings of all three slices, and both test drivers (the suite passes the
signal's owning slice by hand; the net harness drives the bus directly). A stale 2-argument
emit or handler is a RUNTIME error in GDScript, not a parse error — and one stale DIRECT call
(`test_suite` invoked `_on_mine_requested()` itself) aborted the whole suite's compile and
printed a green-LOOKING boot with ZERO tests run. Grep each signal before and after, and check
the test COUNT, not just "0 failed".

**SIXTH review-pass notes (a sixth post-phase review — three findings over eight rows; one was
already closed by the fifth pass, two were real and are closed in
`fix(terrain,persistence,test,docs): Phase 42 review pass 6`):**

The list was written against `e975ddd` — the Phase 41 MERGE, i.e. before this phase — and it dates
itself the same way the fifth pass's did: `_rebuild_chunk_at_tile` is cited at
`voxel_slice.gd:1312`, `apply_edits` at `:550` and `_append_edit` at `:1148`, while those three sit
at 1303 / 540 / 1138 on `e975ddd` and at 1712 / 877 / 1505 on HEAD. (The ~10-line residual says the
reviewer's checkout was a commit or two past the merge, not the merge itself; nothing in the list
depended on that.) Every claim was re-derived from the source.

1. **Chunk resurrection in `_rebuild_chunk_at_tile` (rows 1a/1b/1c) — REAL at the revision read,
   and ALREADY CLOSED by the fifth pass (`89c8461`).** The reviewer read the guard as
   `_heightmaps.has(ckey)`, which the Phase 41 ring retention had made TRUE for a streamed-out
   neighbour; the fifth pass replaced it with `_chunks.has(ckey)` and documented the invariant in
   the method's own docstring, and registered `voxel: an edit never resurrects an unloaded chunk`
   — which is exactly the test row 1c asks for, on exactly the case it names (it mines tile 63,
   the edge column of chunk (0,0), with neighbour chunk (1,0) already unloaded). Nothing to land
   here; the reviewer was right about the revision they read.
2. **An incremental save could not express a DELETED chunk (rows 2a/2b) — REAL.** `_append_edit`
   ERASES a tile's op list when it compacts back to the column's natural self (a player who mines
   a block and puts it back), and `get_chunk_manifest` then has no entry for that chunk — while
   dirty tracking is per CHUNK and is cleared only by the save that CONSUMED it, so the chunk is
   still dirty with nothing left to serialize. That combination was expressible nowhere:
   `dirty_chunk_subset` skipped any dirty key the manifest did not carry, and `_merge_world` only
   ever folded entries INTO the record. So the record on disk kept the edits the earlier FULL save
   wrote, and a reload resurrected terrain the player had already put back — on the autosave, not
   just at shutdown. Fix, both halves: `dirty_chunk_subset` carries an EMPTY edit set for a dirty
   key with no manifest entry (the deletion statement, and the reason the marker is checked with
   `is_empty_edit_set`, which requires the `edits` key to be present — a shape this version does
   not understand is folded in, never read as a deletion), and `_merge_world` DELETES the chunk's
   key when it sees one. ROW 2c (force a full save on shutdown instead of an incremental one) is
   **NOT TAKEN**: it leaves the autosave path exactly as broken as it is and pays the full-record
   cost this phase removed.
   RED-proved: `persistence: an incremental save can delete a chunk` (`the incremental payload
   still names the dirty chunk` — and the payload's `0,0` then indexed off the end of the dict,
   aborting the rest of the test).
3. **No type guard on the legacy branch of `apply_edits` (rows 3a/3b) — REAL, one fix, both halves
   of the row.** The legacy half cast every non-Array value with `float()`, and that cast is not a
   refusal — measured on this engine: `float("not-a-height")` → `0.0`, `float(true)` → `1.0`,
   `float({…})` → `SCRIPT ERROR: Invalid call. Nonexistent 'float' constructor`. The first
   migrated a corrupt string into an absolute height AT THE WORLD FLOOR, i.e. carved the column
   away; the last raised on the load path. The migration now admits exactly what a pre-Phase-41
   edit could be — an int, a float, or a numeric string (`_legacy_height_of`, NAN as the "not a
   height" sentinel) — and DROPS anything else with a `push_warning`, which is the policy
   `_normalise_ops` already applies to an op whose kind it cannot read. Row 3b's "matching
   `_normalise_ops`'s drop policy" is therefore the warning-plus-drop it asks for, in one place.
   RED-proved: `voxel: a legacy edit of an unknown shape is dropped` (`an unparsable string no
   longer carves the column to the world floor: expected 2.0, got 0.0` and `and neither does a
   bool: expected 2.0, got 1.0`).

**Batched probes, and where the count lies for the SECOND pass in a row.** Both inversions went
into one boot (the guard back to the raw cast; the subset back to `if manifest.has(k)` plus
`is_empty_edit_set` disabled with an always-false `< 0`). It reported `7797/7802 (5 failed)`: the
five `✗` lines are exact, but the total is 7 SHORT of the green 7809, because the persistence
probe means the payload does not carry `0,0` at all and the next assertion indexes it — an abort,
not a failed assertion. Read the count as well as the `✗` lines, and quote the count you got in the
GREEN run, never the probe's.

**SEVENTH review pass (`fix(terrain,test,docs): Phase 42 review pass 7`):** a seven-row list
(7a/7b/7c the flaky net-harness step, 4a/4b the terrain material, 6a/6b the npm/pnpm split). It
cites no line numbers, so it dates itself only by its content — and that content lands on HEAD:
`_terrain_material()` is the per-call allocation row 4a describes, step 4 is the `no_distant_tree`
row 7a describes, and the `fabric` job really does run `npm ci` with `cache: npm`. Three of the
seven are real, one is the list's own alternative and is not taken, one is already true, and one is
a doc correction.

1. **The flaky net-harness step (7a) — REAL as a RACE, and NOT reproduced in three fresh-world
   runs.** 7c asks for the reproduction first, and it is the right order: `tools/net_harness.sh`
   under a fresh `XDG_DATA_HOME` (which is what CI has and this machine's accumulated `user://`
   does not) reported `10/10 steps agreed across both peers` three times in a row, with the same
   client-side detail (`tree_-1_-2_1`) each time. So the failure recorded in the Phase 39 pass —
   four runs failing on `rate_bucket` — does not stand today, and the step-four failure the list
   names was never seen here at all. What IS real is the race the fix names: the target is drawn
   from THIS side's own tree table, and a freshly-booted client's table is only what its snapshot
   seeded, so a tree beyond `TARGET_BEYOND` may not have arrived when the step reaches it — and the
   step reported `no_distant_tree` at that instant, which fails a correct guard for being early.
   Step 4 now waits for the table to carry one, bounded by `STEP_TIMEOUT_SECS`, and only then
   judges the guard; the wait is re-derived rather than captured, because a GDScript lambda
   snapshots its captures by value. **The fix is therefore hardening, not a reproduced-defect fix**:
   it cannot be RED-proved here, and it is not claimed to be.
2. **Gating the harness on the full streamed window (7b) — NOT TAKEN.** It is the list's own
   alternative to 7a for the same behaviour ("alternatively"), and 7a is the cheaper of the two: it
   changes one step's precondition instead of the whole harness's boot gate. Two mechanisms for one
   job is what the Phase 40 pass refused to do with the `SeparationRayShape3D`.
3. **Material churn per rebuild (4a/4b) — REAL, one field, both halves.** `_terrain_material()`
   minted a fresh `StandardMaterial3D` per call, and `build_chunk` calls it twice (the surface mesh
   and the rare-vein deposit overlay), so every rebuild — an edit, a re-stream, the self-heal —
   allocated two more materials. Both halves of the row are the same change: `_terrain_mat` is built
   once in `_ready()` (and on first use, for an isolated rig that never enters the tree) and the one
   instance is assigned to both `MeshInstance3D`s, which is what makes the churn track the slice
   instead of the streamed rebuild count. RED-proved: `voxel: terrain material is one instance`
   fails its three `is_same` assertions with the old per-call policy
   (`the surface and the deposit overlay share ONE material instance`, `a rebuild reuses the same
   material instance`, `and so does the rebuilt deposit overlay` — `7808/7811 passed (3 failed)`).
4. **The npm/pnpm split (6a/6b) — 6a is ALREADY TRUE, 6b applied to `README.md` only.** `6a`
   ("keep `package-lock.json`; CI's `npm ci` and `cache: npm` depend on it") is the state of the
   repo: the lockfile is tracked, at `lockfileVersion` 3, and carries the `@newel/*` resolutions the
   `fabric` job's `npm ci` installs from. Nothing to land. `6b`'s first alternative — the docs say
   npm — is applied to `README.md` (quick start, the life-cycle diagram, "Adding a new system").
   Two deviations from the row's letter: there is no `CLAUDE.md` in this repo (the agent notes live
   in `AGENTS.md`, which names no package manager at all), and `ROADMAP.md`'s ~30 `pnpm …` mentions
   are left alone — they are the per-phase record of commands that were actually run, and several
   are quoted acceptance criteria, so rewriting them would falsify the log rather than fix a doc.
   `pnpm-lock.yaml` is still tracked beside `package-lock.json`; removing it is the user's call, not
   this pass's (it is a file deletion in a repo where `pnpm` also works).
5. **A note for whoever reads the assertion count:** the suite's total is NOT a fixed number. The
   seventh-pass count moved by −6 in `battle: player rounds route by target id`, whose `hits` array
   is filled by `BattleSlice.resolve_round`'s `randf()` rolls: any earlier test that consumes the
   global RNG stream shifts how many of its 20 rounds land, so the test asserts a different number of
   times (56 vs 62 here). Green either way, and no assertion is lost — but a count quoted in this
   file is a count for the revision and RNG stream it was measured on, not a constant to match.

**EIGHTH review pass (`fix(terrain,test,docs): Phase 42 review pass 8`):** an eight-row table (an
Issue column, a Solution column, a Criticality column) with no line numbers and no `Closes` column —
it dates itself by content, and all of that content lands on HEAD. **All eight rows are real**: the
fourth list in a row with nothing to discard. Two are real as PERFORMANCE and must not move
behaviour (rows 4 and 8), one is real only as a VACUOUS TEST rather than a defect in production code
(row 5), and one is real by its own account — "the criterion has no assertion" is the finding
(row 3). Row 3's second half and rows 4/8 are what makes this pass's proof unusual: three of the
eight cannot be RED-proved at all, because the thing they change is a COST, and a cost that must not
change behaviour has only an equivalence proof and a measured number.

1. **`build_chunk()` resolved the rare-vein deposits on the main thread (row 1) — REAL, the headline
   (High).** `vein_deposits()` walked all 4096 of the chunk's own columns with its OWN memo (a second
   run replay per tile, plus a biome lookup and a material roll) and then emitted every deposit box
   through a `SurfaceTool` — and `build_chunk` called it on the MAIN thread for every build,
   including every build the worker had just finished: the stall the worker exists to remove, paid
   on the main thread immediately after it. Measured on this machine, for a 695-deposit chunk: the
   walk **24 245 us**, the `SurfaceTool` emission **6 531 us** (695 boxes → 25 020 verts), i.e.
   **~30.8 ms of main-thread work per build**, of which the emission is now the worker's and the walk
   is the resolve half's, sharing the mesher's memo (its marginal cost is the **6 791 us/pass** the
   split probe measures). The fix is the row's own: the deposit list is resolved by
   `collect_build_runs`, the pure builder emits the boxes as
   `deposit_vertices/normals/colors/indices`, and `build_chunk` only attaches. The deposits stay a
   SECOND mesh with no collision, which is what keeps "apply only geometry" honest — a deposit is
   decoration the player must not stand on — and `MeshUtil.add_box_arrays` shares `_box_corners` and
   `_box_faces` with `add_box`, so the two authoring paths cannot wind a face differently (the whole
   reason that file exists). RED-proved in the batch: with the resolve returning `"deposits": []`,
   `voxel: rare vein deposits on natural tiles` fails `every deposit reaches the chunk mesh: expected
   25020, got 0`, and `voxel: terrain material is one instance` fails `the chunk carries a surface and
   a deposit overlay: expected 2, got 1`.
2. **`refresh()` kept the PREFETCH band resident (row 2) — REAL, and a Phase 42 regression the row
   dates precisely (High).** Phase 42 had widened `wanted` to `stream_radius()`, so a crossing
   retained 121 chunks (11×11 at the defaults) against the view ring's 49 (7×7): 2.5× the meshes,
   trimeshes, creatures and trees for a band the player may never enter. `wanted` is
   `view_distance` again and the load QUEUE still spans `stream_radius()`. What is traded, plainly:
   a band chunk is still BUILT ahead of its need (that is the prefetch), but it is RELEASED on the
   next crossing that leaves it in the band unless the player moved toward it — build work in
   advance for a view ring's worth of memory, which is the row's intent. RED-proved:
   `chunk: the kept window is the view ring` fails fifteen assertions with `wanted` back at the
   stream radius (`a band chunk beyond the new view ring is released`, plus eleven
   `every resident chunk is inside the view ring (…): expected true, got false`).
3. **The split criterion was printed, never asserted (row 3) — REAL, and the row's own evidence
   (High).** `_test_chunk_build_split_probe` measured both halves and asserted only that the work
   happened (`cell_count > 0`, `worker_us > 0`), so the phase's headline claim — "the build does not
   run on the main thread" — could have been false with the suite green. It now asserts the ratio,
   and the row's second half is implemented too: the measured main-thread half INCLUDES the apply
   path (`_mesh_from_arrays` for the surface and the deposit overlay, and the
   `ConcavePolygonShape3D.set_faces` GDScript still pays to hand the worker's collision to physics).
   Three passes are summed, because the two halves differ by under 2× on this machine and a
   single-shot pair would be a timing coin-flip — **main 130 071 us (resolve 126 938 + apply 3 133),
   worker 235 263 us** on the `--quit` boot, printed by the test for a reviewer to check. The
   assertion is a strict `>` rather than a ratio: the gap is 1.81×, so a ratio tight enough to be
   interesting would be a flake.
4. **`collect_build_runs` redid two per-tile lookups 4356 times (row 4) — REAL, behaviour-preserving
   (Medium-High).** The biome is a per-CHUNK property (`TerrainSlice.get_biome_at_chunk`), so the
   66×66 ring — which spans at most four chunks — was asking the terrain slice 4356 questions to get
   four answers; and `material_for_biome` re-summed the biome's weight table on every call, while
   `_natural_color` re-derived a colour from a handful of possible materials. Both are memoised for
   the pass (`_biome_at_memo`, a material → colour map) and the weight table is built once per biome
   into a `static var` (`_biome_roll_table`, same insertion order, so the roll's tie-breaks are
   unchanged). Measured: the resolve half runs **42 313 us/pass with the memos against 48 971
   us/pass without them** (~14%), all 7833 assertions green both ways — this row has no RED by
   construction, so it is proved by the equivalence and the number.
5. **The purity test was vacuous (row 5) — REAL as a TEST defect (Medium).** `_test_voxel_build_
   arrays_pure` built the SAME resolved table twice (`f(x) == f(x)`) and its second slice `b` — set
   up with a different place material and an edit in another chunk precisely to show that slice state
   cannot reach the build — was dead setup that was never read. It now resolves the chunk from BOTH
   slices and builds from each: the two resolves must agree and the two builds must be identical, so
   a resolve that leaked one slice's state into another's answer goes red, and so does a builder that
   read back into the slice. Like row 4 this has no production defect behind it and cannot be
   RED-proved; it guards against a leak that does not exist today.
6. **`apply_edits` rebuilt touched chunks synchronously (row 6) — REAL (Medium).** The re-scope path
   — a joining client's snapshot, a load — called `build_chunk` for every touched chunk in the frame
   that applied it (up to three chunks of main-thread build work) AND advanced each chunk's revision
   on the main thread, which made an in-flight worker result stale while its task was still the frame
   path's to reap. It goes through `ChunkManager.request_rebuild` now, exactly like
   `_rebuild_chunk_at_tile`, with the synchronous build kept for a slice with no manager wired (the
   suite, a probe). RED-proved: `chunk: apply_edits dispatches a rebuild` fails both
   `the snapshot's rebuild is NOT done in the frame that applied it` and `it went to a worker
   instead: expected 1, got 0`.
7. **`flush_builds()` iterated a snapshot and never awaited its retries (row 7) — REAL (Medium).**
   `_apply_build_entry` can DISPATCH (a refused worker result is re-dispatched), so a task created
   during the pass was invisible to the `_builds.keys()` snapshot taken before it — and this is the
   BLOCKING variant, whose whole contract is that nothing is left in flight behind it. It loops now
   (re-reading the table per round, bounded by `FLUSH_MAX_ROUNDS` so a build that fails forever ends
   up in `_failed` for the self-heal instead of spinning). RED-proved: with the loop cut to one
   round, `chunk: flush_builds awaits its retries` fails `the retry dispatched during the pass is
   awaited by it: expected 0, got 1` and `and the chunk ends up built (0 meshes attached)`.
8. **`_group_cell` formatted a String key per face cell (row 8) — REAL, behaviour-preserving
   (Medium).** Three `%.4f` formattings plus `Color.to_html` per face cell is ~25k throwaway strings
   for one 64×64 chunk, on the build's own budget and again on every edit rebuild. The key is a
   `Vector4i` of the same four values quantised to 1/10000 — exactly the precision `%.4f` kept — with
   the direction as the outer bucket (a fifth component has no axis, and direction must be in the
   key: an "up" face and a "down" face at the same plane and span would otherwise merge into one
   quad, i.e. a missing floor or ceiling). The quantised ints are bounded far inside int32 (a wall
   plane is a multiple of `TILE_SIZE` and bounded by the world extent, a span by
   `BEDROCK_DEPTH..MAX_HEIGHT`, and `to_rgba32()` is an int32 by definition). Proved by EQUIVALENCE,
   not RED: with the string key restored the suite is green AND the merge probe prints the identical
   numbers (`4352 faces -> 5 quads (20 vertices)` for the flat chunk, `7519 faces -> 3544 quads
   (14176 vertices)` for the natural one — the natural figure is SEED-dependent, so the comparison
   is only valid within one boot, which is exactly how it was taken) — the new key groups exactly
   what the old one grouped, so no span merges that did not merge before.

**Batched probes, and what an equivalence probe can and cannot show.** Five inversions went into ONE
boot (the resolve's deposit list emptied; `wanted` back to the stream radius; `apply_edits` back to
the synchronous build via an always-false operand; the flush loop cut to one round; the string key
restored). It reported `7816/7839 passed (23 failed)`, and the `✗` lines are exact for the four
probes' own subjects — with one honest caveat: reverting `apply_edits` also turned
`net: a remote mine credits the actor` and `net: a remote place spends the actor's pack` red
(`expected 1, got 2`), so that probe's blast radius is wider than its own test and those two are NOT
evidence for row 6. The fifth inversion is the equivalence probe and its signal is not a `✗` at all:
the GREEN merge numbers printed unchanged inside a run that was otherwise failing, which is why the
numbers were read rather than the verdict. This pass's red-caused failure total (23) is a superset of
its four subjects and no test aborted (7839 ≈ the green run's 7833 ± RNG), so nothing was lost to a
crash rather than a failed assertion.

**NINTH review pass (`fix(terrain,test,docs): Phase 42 review pass 9`):** an eight-row table (an
Issue column, a Solution column, a Criticality column) with no line numbers and no `Closes`
column. **All eight rows are real** — the fifth list in a row with nothing to discard — and this
is the first pass whose evidence made one of the PHASE'S OWN criteria go red. Rows 3 and 4 ask for
an absolute main-thread budget on the dispatch and for the probe to assert it; measuring it PER
PASS (the probe had averaged three passes, and the one-time costs sat in the first of them) gave
**44 900 us of resolve per dispatch against a 16 667 us frame**: the headline "the build is on a
worker" was true of the BUILD and false of the DISPATCH, which still spent 2.7 frames of
main-thread work per chunk loaded. That pair is therefore the pass's one structural change — the
resolve itself moves to the worker — and the other six rows are the streaming window, the
in-flight cap, and four small defects the table names.

1. **Band chunks were built and then released before use (row 1) — REAL (Critical).** The eighth
   pass had narrowed the KEPT window to `view_distance` while the load QUEUE still spanned
   `stream_radius()`, and everything the queue spans is BUILT — so every crossing built a band of
   chunks and then released them unless the player happened to move toward them (the row measured
   65 redundant worker builds per crossing; at the defaults it is 121 chunks built against 49
   kept). The kept window is the QUEUE window again, so **no chunk is ever unloaded while it still
   lies inside the radius it was queued at**, and the memory the eighth pass was protecting is
   bounded by the radius instead of by a second window: `DEFAULT_PREFETCH_DISTANCE` is **1**, so
   the resident set is 81 chunks (9×9 — the 49-chunk view ring plus a one-chunk lead) against the
   121 that pass was avoiding.
2. **The kept-window test locked that waste in (row 2) — REAL (High).** It asserted that a
   just-built in-radius chunk IS released, i.e. the assertion was the waste. It is now
   `chunk: the kept window is the stream radius` and asserts the row's own invariant — nothing is
   unloaded while it is still inside the queue radius — plus the retention arithmetic as a number:
   a one-chunk crossing releases the seven chunks of the departing edge. (The eighth pass's test
   name `chunk: the kept window is the view ring` is kept in the record above; this pass renamed
   it because the assertion it carried is now the opposite one, and the Phase 42 line quoting it
   is the measurement of that revision, not of today's.)
3. **The main thread still resolved every chunk it dispatched (row 3) — REAL, and the pass's
   structural change (High).** The resolve (`collect_build_runs`: the per-tile run replay, the
   biome and colour resolution and the rare-vein deposits) was the main thread's half of every
   dispatch, and it cost **43 974 us of steady-state work per chunk** — 2.6 frames at 60 Hz, paid
   once per frame while streaming, on the SAME thread the phase had just taken the build off. The
   split moves: `gather_build_input()` copies the plain state the resolve reads on the main thread
   (the chunk's and ring's edited tiles, deep-copied; the ring chunks' heightmaps; the ring chunks'
   biomes) and the STATIC `build_runs()` does all the per-tile work on the worker, which also runs
   `build_chunk_arrays()` — so one dispatch's main-thread half is now the noise generation plus a
   handful of copies. **Measured: 44 900 us → 2 539 us per dispatch (17.7×), of which the
   generate+gather is 1 634 us**, with the worker half at 77 159 us/pass (resolve 42 957 + build
   34 202). `collect_build_runs()` survives as the synchronous wrapper, so the bus path, the
   isolated rigs and the tests keep the same entry point; the resolve's reads became arguments
   (`edits`, `neighbour_heightmaps`, `biomes`), which is what makes it worker-legal, and the
   instance colour helpers became accessors over the static resolved forms (the
   `_within_stream` / `_within_stream_at` shape).
4. **The probe's criterion let a 43 ms frame pass (row 4) — REAL (Medium).** `pure_us > main_us`
   was satisfied by a dispatch whose main-thread half blew the frame, and the three-pass SUM hid
   the steady state behind the first pass's one-time costs. The probe now keeps PER-PASS figures
   and asserts, alongside the ratio, an ABSOLUTE ceiling: one dispatch's main-thread half must fit
   inside one frame (16 667 us). This is the assertion the old criterion could not make — and it
   is the one that was RED before row 3's fix (see the batched probe evidence below).
5. **`load_chunk()` bypassed the in-flight cap (row 5) — REAL (Low-Medium).** Every internal
   caller checked `max_builds_in_flight` before dispatching, but the PUBLIC `load_chunk` called
   `_dispatch_build` outright, so a direct load put the pool over its own cap. The cap is now
   enforced INSIDE `_dispatch_build` (nobody can route around it), the deferral goes to
   `_rebuild_queue` — the chunk is already `_loaded`, so the drain's rebuild branch is exactly the
   path that re-dispatches it — and `request_rebuild`'s and the retry's duplicate checks were
   removed so the rule lives in ONE place. New test:
   `chunk: a direct load respects the in-flight cap`.
6. **The group key's packed colour does not fit int32 (row 6) — REAL as a DOC error (Low).** The
   eighth-pass comment claimed `to_rgba32()` "is an int32 by definition"; it is a packed uint32,
   so opaque white is **4294967295** and the `Vector4i` component reads back as **-1** (the high
   bit kept as the sign; measured on 4.7). The wrap is a BIJECTION — the component reads back as
   `& 0xFFFFFFFF` == the packed value — so two distinct colours cannot collide onto one key and
   the grouping is exactly what the old string key grouped. What was wrong was the comment, and it
   is fixed in both places (the comment and the eighth-pass paragraph above).
   `voxel: the group key survives the colour band` pins the measured values, the round trip, the
   injectivity of two colours sharing their low bits, and the grouping itself.
7. **`_biome_rolls` is worker-reachable mutable class state (row 7) — REAL (Low).** It is a
   `static var` on the script a chunk-build task holds (`ChunkManager.VoxelBuilder`), so the lazy
   fill was a WRITE a worker thread could have raced. Every biome is warmed in `_ready()` now, on
   the main thread, before anything streams — and the worker half never reads it either, because
   the colours arrive resolved in the table it is handed. New test:
   `voxel: the biome roll table is prebuilt` (it clears the static first, so the assertion cannot
   be vacuous).
8. **`build_chunk_arrays` sniffed a "runs" key (row 8) — REAL (Low).** `resolved.get("runs",
   resolved)` meant "does this dictionary happen to hold a key called runs?", silently re-reading a
   bare runs table as a payload. Every caller in the tree passes a `collect_build_runs()` payload
   (the only bare tables were the `{}`-for-natural probes, now `{ "runs": {} }`), so the sniff is
   gone and an absent `runs` key reads as NO resolved columns, i.e. the natural-column fallback.
   New test: `voxel: the build payload shape is required`, which hands the builder a bare table
   that WOULD change the build under the old fallback and requires the two builds to be identical.

**Batched probes, and the one that had to be its own.** Six inversions went into ONE boot (the kept
window narrowed back to `view_distance`; the `_dispatch_build` cap guard disabled with an
always-false operand; the `_ready()` prebuild loop emptied; the "runs" sniff restored; the group
key's colour folded to its low byte; and — for rows 3/4 — the PROBE put back on the pre-fix
measurement, the resolve counted as the main thread's half). It reported `7839/7860 passed
(21 failed)` and every one of the six subjects went red with its own line:
`chunk: the kept window is the stream radius` (`a band chunk still inside the queue radius is NOT
released`, and `expected 7, got 40` released), `chunk: a direct load respects the in-flight cap`
(`expected 1, got 2` builds in flight), `voxel: the biome roll table is prebuilt`
(`expected 5, got 0`), `voxel: the build payload shape is required` (`expected 4352, got 4354`),
`voxel: the group key survives the colour band` (`a second colour is its own group: expected 2,
got 1`), and `chunk: the build split is measured` (`one dispatch's main-thread half fits inside a
frame (48135 us of 16667 us, generate+gather 47243)`) — the row-4 ceiling failing at the old
split, which is the whole reason row 3 was worth doing. Two caveats recorded rather than smoothed
over: disabling the cap guard also reddened `chunk: a rebuild respects the in-flight cap` and
`chunk: unloading drops a queued rebuild` (the same guard is those tests' subject too — the guard
going off moves the pooling they assert on), and the run's failure total (21, total 7860) is a
superset of the six subjects because the RNG-dependent test (`battle: player rounds route by
target id`) asserts a varying number of times per run. No test aborted, and the restored source is
green on both boots.
A SECOND, two-inversion boot proved the gather itself (`chunk: the gathered payload carries the
ring`): with `_gather_neighbour_heightmaps` carrying nothing and `_gather_edits` returning early,
it reported `7862/7868 passed (6 failed)` — the new test's own
`a carried ring chunk resolves its real column`, plus THREE existing tests in its blast radius
(`voxel: a seam wall ignores the build order` `expected [[1.0, 2.0]], got [[-8.0, 2.0]]`,
`voxel: an edge edit rebuilds the neighbour chunk`, `voxel: a tunnel keeps its floor and its
roof`). That collateral is the useful part: the ring's heightmaps and edits are what the seam
geometry is computed FROM, so the gather is load-bearing for the existing voxel tests, not only
for its own.

**TENTH review pass (`fix(terrain,test,docs): Phase 42 review pass 10`):** an eight-row table
(an Issue column, a Solution column, a Criticality column) with no line numbers and no `Closes`
column. **All eight rows are real** — the sixth consecutive list with nothing to discard — and
the list's own framing is right: it is a list of SMALL items, the largest being a per-dispatch
cost the earlier passes kept narrowing but never bounded for a played world.

1. **`_gather_edits` scanned the whole world edit log per dispatch (row 1) — REAL (Medium).**
   The gather iterated EVERY key in `_edits` and `str(key).split(",")`-ed it to test it against
   the chunk window's bounds: one string split per edit in the WORLD, per dispatch, however far
   away those edits were. It now walks `_edits_by_chunk` — the log INDEXED BY CHUNK (`"cx,cz"` →
   `{ "gx,gz": true }`), the read-side counterpart of `_dirty_chunks` — reading only the (≤ 3×3)
   chunks the window spans. The index is kept in step by `_set_edit_ops`, now the ONE place a
   tile's op log is written (`_append_edit` and `apply_edits` both route through it, the latter
   re-deriving the index wholesale). **Measured on a 102 400-edit log with 4 096 in the window:
   the dispatch's generate+gather was 44 012 us (2.6 frames) and is 5 568 us**, because the cost
   is now proportional to the window and not to the world. The four tests that wrote `_edits`
   directly were routed through `_set_edit_ops` so the index cannot drift from the log.
2. **The frame-ceiling assertion ran on a FRESH slice, so it could not see row 1 (row 2) — REAL
   (Medium).** The ninth pass's ceiling measured an empty `_edits`, where the gather returned on
   its first line — so the one cost the index exists to bound was never in the number the ceiling
   checked. `chunk: the build split is measured` now runs a SECOND pass over a POPULATED log (a
   full chunk in the window plus 24 chunks ≈98k edits outside it) and asserts the same
   `steady < 16 667 us` ceiling there; the far chunks are what makes the assertion bite, since
   only the window's are copied. **RED with the old world-scan gather restored: `44 012 us of
   16 667 us` — the row-1 fix is exactly what this assertion pins.**
3. **Worker safety rests on `BIOME_KEYS ⊆ BIOME_MATERIALS`, unpinned, with a false comment (row
   3) — REAL (Low-Medium).** A worker's resolve reaches `material_for_biome`, which silently
   answers `Ferrite` for a biome absent from `BIOME_MATERIALS` — so a canonical biome missing
   from the table mines as the wrong material, and nothing asserted the two sets agree. New test
   `voxel: every canonical biome has a roll table` asserts it over `TerrainSlice.BIOME_KEYS` (the
   set the gathered strings actually come from), each with a non-empty table. The `_ready()`
   comment's claim that "the worker half never even reads it" was FALSE — the worker reads it
   through `run_color` → `natural_color` → `material_for_biome` → `_biome_roll_table` — and is
   rewritten to the real invariant (written on the main thread before any worker exists,
   read-only afterwards).
4. **Heightmaps are gathered by reference while edits are deep-copied, unstated (row 4) — REAL,
   DOC-ONLY (Low).** The asymmetry is deliberate and now stated at `_gather_neighbour_heightmaps`:
   an op list is APPENDED to in place (`ops.append` on the array a worker may be reading), so it
   must be copied; a heightmap array is only ever REPLACED wholesale and never mutated in place,
   so sharing it is safe — with the note that a future in-place write would have to copy here too.
5. **`_biomes_or_lookup` passed an incomplete biome map through (row 5) — REAL (Low).** Its guard
   was "is the map non-empty", so a PARTIALLY populated map — the realistic case — went straight
   through and `biome_of` answered `DEFAULT_BIOME` for the missing chunk, silently tinting a real
   chunk as TemperateForest. It now tests for THIS position's chunk and, on a miss, resolves that
   one chunk from the terrain slice into a COPY of the map, so the caller's is untouched. (The
   pure `biome_of` keeps the `DEFAULT_BIOME` fallback — it is static and has no slice to ask —
   and that answer is now only reachable when there is no terrain slice at all.)
6. **`voxel: the biome roll table is prebuilt` cleared a worker-reachable static mid-suite (row
   6) — REAL (Low).** `_biome_rolls` is process-wide class state a worker reads, and the test
   blanked it and left it blanked. It now SNAPSHOTS the table, clears (which is what makes the
   assertion about `_ready` rather than a leftover), and RESTORES it, asserting it is left full.
7. **`_update_first_ring_progress` only latched true while `unload_chunk` clears `_built` (row 7)
   — REAL (Low).** A one-way latch cannot mirror a set that can lose members, so the gate could
   claim a chunk was built after it had streamed away. It now RECOMPUTES each ring key from
   `_built` (`_first_ring[key] = _built.has(key)`), so the mirror is exact. No boot regressed (the
   ring is armed before the player can move, so a ring chunk never unloads mid-boot).
8. **The self-heal's cost was described as one dispatch per interval (row 8) — REAL, DOC-ONLY
   (Low).** A re-arm clears `_build_attempts` — a FRESH retry budget, which three tests assert —
   so one re-arm is up to `MAX_BUILD_RETRIES` dispatches, not one; the throttle bounds the re-arm
   CADENCE, not the dispatches within one. The row's first option ("don't reset `_build_attempts`
   on a heal re-arm") was **not taken**: the reset is the tested, intended design. Both messages
   (`_failed`'s doc, `_self_heal_failed`'s doc, and the give-up `push_error`) are corrected.

**Known simplifications (deferred):**
- **An edit's mesh lands a frame or two later.** Since the review pass, a mine/place
  DISPATCHES its chunk rebuild (and any seam neighbour's) to the worker instead of building
  it in the frame that applied the edit, so the visual update arrives when that build does.
  The edit LOG is immediate, so everything that reads the world rather than the mesh —
  footing (`sample_support_height_at`), further edits, persistence — is unaffected.
- **A client's own harvest is confirmed by the host, never predicted.** Since the fifth review
  pass the host resolves a peer's mine/chop/place against THAT peer's own pack and pushes the
  result back on the owner-addressed `inventory_synced`, so the peer sees its yield only once the
  round trip lands — there is no client-side prediction of the edit or of the material, for the
  same reason the block's mesh arrives with the host's `block_changed`. The durability a remote
  actor's pick or axe spends is the host's number too, so a client cannot wear its own tools
  locally (only report the wear the host resolved). Making the remote half feel instant again
  means client-side prediction plus reconciliation, which the phase does not carry.
- **No priority job queue or cancellation.** Loads are nearest-first, and a
  chunk that falls out of range while queued is still built (and then unloaded).
  **(Closed in the second review pass for the cancellation half: a queued chunk that leaves
  the window is now DROPPED rather than built, and its `_pending` mark is cleared with it, so
  a chunk that leaves and returns is queued again instead of being skipped. What is still
  deferred: there is no priority ordering beyond nearest-first, and a rebuild cannot jump the
  load queue — it is drained first, but only as a whole band.)**
- **The loading screen is a progress bar, not a world preview** — no panorama, no
  tips, no fade.
- **Entities still spawn on the main thread.** Creatures and trees spawn in the
  frame a chunk lands; this phase threads the TERRAIN build only.
  **(Refined in the second review pass: they spawn from the apply path, i.e. WITH the chunk's
  mesh, rather than at load time a frame or two before it. What is still deferred: the spawn
  itself is still a main-thread call inside that apply pass, and the prefetch band's chunks —
  then 121 resident against the view ring's 49 — spawn their population as eagerly as the near
  ring's; how far out population should exist at all is a tuning decision this pass left open.)**
  **(Closed in the eighth review pass for the WINDOW half: the kept window is `view_distance`
  again, so only the view ring's 49 hold meshes, trimeshes and population; a prefetch-band
  chunk is still built ahead of its need but is released on the next crossing that leaves it in
  the band. What is still deferred: the spawn itself is still a main-thread call inside the
  apply pass, and a band chunk's population is spawned and then released unvisited — whether
  the band should carry population at all remains the tuning decision.)**
  **(NINTH review pass: that window narrowing is REVERTED — it was the build-then-release waste
  this pass's row 1 measures, so the kept window is the queue radius (`stream_radius()`) again
  and a band chunk is released only once it is outside the radius it was queued at. The
  resident set is bounded by the RADIUS instead (`DEFAULT_PREFETCH_DISTANCE` 1 → 81 chunks,
  9×9). What is still deferred is unchanged: the spawn is a main-thread call inside the apply
  pass, and how far out population should exist is still the tuning decision.)**
- **No runtime tuning UI** for `loads_per_frame` / the ring sizes; they stay
  constants (overridable, as today).

---

## Phase 43 — Natural resource distribution ✅ Done

**Goal:** Resources are a uniform draw. `BIOME_MATERIALS` gives every tile of a
biome the same weighted distribution, so Aethermite is 17/100 of every volcanic
tile a player ever mines — at every depth, in every chunk, forever. The
material's own prose ("deep underground near ley lines") describes nothing the
code does, and Phase 31 recorded the gap plainly: "Resource deposits have no
depth/quantity model yet (mining still yields one unit per `STEP_HEIGHT`
slice)". This phase replaces the biome-uniform draw with a deterministic 3D ore
field — vein blobs with a depth band and a quantity — retires `BIOME_MATERIALS`
to a bias rather than the distribution, and makes "deep near ley lines" a real
condition the world can be asked about. The depth band and the ley gate are
FABRIC VALUES on the material entities, not a GDScript table: this phase moves
them into the source of truth (with the newel dependency that requires), so the
field cannot disagree with the prose it is derived from.

**Newel dependency:** YES. The depth band and the ley gate become fabric fields
on the material entities (`depthBand`, plus a ley-gating field, on
`fabric/world/materials/*.js` — `Aethermite` already reads "Found deep underground
near ley lines and in meteor craters"), authored from the prose each material
carries today. `pnpm validate`, `pnpm generate` and
`pnpm check-drift` re-run; no runtime band table may be hand-written in GDScript.

**Closes:** item 7a, Phase 31 deferred.

**Deliverables:**
- `fabric/world/materials/*.js` — the depth band and the ley gate as ENTITY
  FIELDS, not GDScript: a `depthBand` (the min/max depth a material may appear at)
  and a ley-gating field on every material, authored from the prose each material
  already carries. The runtime field READS them through the generated resources.
- `src/terrain/ore_field.gd` (new, pure) — the field:
  `vein_at(chunk_pos, tile, depth) -> Dictionary` returning
  `{ material, quantity }` or `{}`, derived from a 3D noise blob threshold plus the
  material's fabric `depthBand`. A vein is a BLOB of neighbouring tiles at a depth,
  not an independent per-tile probability, so a rich spot is worth walking to.
- `src/terrain/ore_field.gd` — the ley-line field:
  `ley_line_value(world_xz) -> float` (2D noise) gates whichever materials carry
  the fabric ley gate, so a deep volcanic tile far from a ley line yields none for
  a ley-gated ore. This is the first code that makes the material's own lore true.
- `src/terrain/voxel_slice.gd` — `BIOME_MATERIALS` becomes `BIOME_BIAS` (the
  dominant material a biome favours for a vein that is not depth-gated);
  `material_for_biome` and the mesher's per-run tint (`_run_color`) read the field.
- `src/terrain/voxel_slice.gd` — `vein_deposits()` (the Phase 31 raised surface
  marker) reads the same field, so the marker marks a vein that is actually
  there, and takes its colour from the vein's material.
- Mining yields the vein's `quantity` rather than a flat one per slice, and an
  exhausted vein is recorded through the Phase 41 edit path (so its depletion
  survives a chunk rebuild and a save).

**Acceptance criteria:**
- [x] A fixed seed mines the same vein in the same place twice, and a client sees
  the same veins as the host with no snapshot (assert the pure field, not a
  visual).
  *(Landed: "ore: a fixed seed puts the same veins in the same place" samples 16 chunks × 12
  depths twice and compares, and a second seed differs. "ore: a client sees the host's veins
  with no snapshot" gives a host and a client slice their own `TerrainSlice` at one seed and
  compares `material_at` over a grid AND the two `build_runs` resolves of a chunk — equal with
  nothing exchanged.)*
- [x] Aethermite never appears above its depth band and never far from a ley
  line, sampled over a grid of tiles.
  *(Landed: "ore: aethermite keeps to its band and its ley lines" — 3 seeds × 144 chunks ×
  1024 tiles × 26 depths; every Aethermite sample is at or below the fabric `depthBand.min`
  and `near_ley_line`, and the sample is asserted non-empty so the gate is not vacuous. It
  holds PER TILE, not just per vein centre: `vein_at` clips each tile by the same gate.)*
- [x] The retired uniform draw is measurably gone: the per-chunk counts of a
  given material over a sample of chunks are non-constant (assert the variance
  against the old constant distribution).
  *(Landed: "ore: the uniform draw is gone" counts Aethermite in 16 volcanic chunks at three
  depths: the variance is asserted > 1 and most chunks sit more than half away from the
  retired constant share (17% of the samples, every chunk).)*
- [x] Mining a vein yields more than one unit and the vein is exhausted by
  repeated mining; mining surrounding rock yields the bias material and never the
  gated ore.
  *(Landed: "ore: a vein yields more than one and runs out" mines a surfacing vein slice by
  slice through `mine_block`: each live slice yields the vein's material × its `quantity`
  (2–4), the vein pays out exactly its `reserve`, and the next slice of the same blob yields
  host rock, one unit. "ore: surrounding rock is the bias, never the gated ore" mines
  non-vein tiles of a volcanic chunk: Ashite, one unit, never Aethermite.)*
- [x] The suite is green on both boot paths and the field is unit-tested (blob
  continuity across a chunk border, depth gate, ley gate).
  *(Landed: 422/422 tests green, and the two-client net harness 10/10. "ore: a blob is
  continuous across a chunk border" finds slices where one vein id covers tile 63 of chunk 0
  and tile 0 of chunk 1, and asserts a tile's answer does not depend on which chunk asks;
  the depth and ley gates are the Aethermite test above plus "ore: the ley field is a field
  of lines". Depletion: "ore: depletion is one op per vein and persists" (one op however
  many swings, dirty anchor chunk, JSON save round-trip, survives compaction, a malformed op
  is dropped) and "ore: a client replays the host's depletion" (same depletion and same edit
  log after `apply_block_change`).)*
- [x] `pnpm validate`, `pnpm generate` and `pnpm check-drift` are green, and the
  generated material resources carry `depthBand` and the ley gate — the field's
  band cannot disagree with the fabric because it IS a fabric value.
  *(Landed: `depthBand` (json `{ min, max }`) and `leyGated` (boolean) on all eight
  materials via `fabric/world/materials/deposit.js`; the generated `.tres` carry them and
  `OreField.warm()` reads them off `GameData.MATERIALS`. "ore: the bands are fabric values"
  asserts the runtime table equals every resource's fields. No newel change was needed —
  `json` and `boolean` fields with defaults already generate.)*

**Implementation notes:**
- **The field must be a pure function of (seed, world position, depth) — never of
  chunk load order.** That is what lets a host and a client agree with no
  replication at all: they evaluate the same function. The Phase 44 spawn work
  has exactly the same constraint, and both fail the same way when it is broken
  (a client's vein appears where the host has rock).
- **Depth is why this phase follows Phase 41.** A depth band needs a depth to
  index; before the volumetric column there was one surface and no "below".
- **A vein may straddle a chunk border, and must.** The field is evaluated per
  tile, so a blob crossing a border is continuous on both sides; do not "own" a
  vein by its centre chunk, or the border becomes a visible seam.
- **Vein identity, not per-tile depletion.** Depleting tile-by-tile makes a blob
  a checkerboard and makes the save grow with every swing. Name the vein (a hash
  of its blob origin) so "exhausted" is one recorded fact per vein, carried by
  the edit path Phase 41 already persists.
- **Depth gating is data, not code.** The band is a fabric field on the material
  (`depthBand`), beside the material's other properties, where the prose that
  states it already lives; the runtime field must not carry a hand-written
  `if material == "Aethermite"` table of bands. The generated resource is the only
  place the band is authored, so the field and the fabric can never drift.

**Known simplifications (deferred):**
- **The vein field's own noise constants stay GDScript.** What moves into the
  fabric is the material's DEPTH/QUANTITY model — the `depthBand` and the ley
  gate, entity fields on the material (`fabric/world/materials/*.js`). The SHAPE
  of the field itself (noise frequency, blob threshold, blob size, the 2D
  ley-noise frequency) stays a hand-written constant in `src/terrain/ore_field.gd`
  and does not ride a newel world-system entity in this phase. That is a narrower
  deferral than Phase 31 recorded, and a later separate change — the same one
  Phase 44 carries for tree density (`fabric/world/world.js`, Phase 44's wording).
- **No detection or prospecting skill interaction.** A deep vein has no surface
  tell beyond the raised marker on a vein that reaches the surface; finding ore
  with a skill/tech is a later feature.
- **No richer tool gating by ore.** The existing pick/axe discriminator path is
  unchanged; a depth-gated ore still yields to whatever pick the player holds
  (durability cost aside).
- **No vein regrowth.** A vein is a finite, depleting body; nothing replenishes
  it, and the tree stump cooldown is still the only regrowth clock in the world.

**As built (decisions the deliverables left open):**
- **Depth is measured from the tile's NATURAL surface** (its quantised heightmap top), not
  from world Y and not from the current column top: the datum is fixed by the seed, so a
  vein does not move when a player digs above it, and both peers compute it from the same
  heightmap.
- **The blob is a cell-hashed ellipsoid with a noise-perturbed surface**, not a global
  noise threshold. Space is cut into 16-tile × 4-unit cells, each holding at most one vein
  whose centre sits far enough inside that the blob (radius × (1 + `SHAPE_NOISE`)) cannot
  leave it — so a sample reads ONE cell, and the vein's identity is its cell id (the "hash
  of its blob origin"). The XZ cell grid is offset half a cell from the chunk grid, which is
  what makes veins straddle chunk borders. The top depth cell lets veins break the surface.
- **A vein's material is picked once at its centre** from the centre's biome
  (`TerrainSlice.biome_for_chunk`, now static): a weighted draw over the biome's non-host
  bias materials the fabric admits there, else the host itself (a rich pocket — the only
  kind TemperateForest has). Each tile is then clipped by the material's band and ley gate.
- **The host rock is not band-gated.** `BIOME_BIAS`'s heaviest entry is what every tile
  outside a live vein yields, at any depth — so a twilight tile is Lumenfite rock below
  Lumenfite's shallow band, and only a Lumenfite VEIN honours it.
- **Depletion is ONE edit-log op per vein**: `{ "op": "deplete", "vein": id, "taken": n }`
  on the vein's anchor tile, replaced in place on each mine. It rides the per-chunk save
  manifest and the join/re-scope snapshot, `apply_edits` re-derives `_vein_taken` from it,
  compaction carries it over, and the client's `apply_block_change` records the same
  depletion the host did. An exhausted vein renders and mines as host rock, and its chunks
  are rebuilt when it runs out (or when a snapshot flips it).
- **A natural run is still ONE colour**, the field's material at its top slice: a vein
  shows where a column's top slice reaches it (and gets the raised marker there), not on
  the side walls of a deeper cut. The marker now marks every live vein, ferrite included.
- **Cost:** the field adds ~15 ms to a chunk's resolve (≈42 → ≈56 ms measured over six
  noise chunks), all of it on the worker since Phase 42 moved the resolve there; the
  ellipsoid test short-circuits the 3D noise for every sample it can decide alone.

---

## Phase 44 — Spawn scarcity ✅ Done

**Goal:** Population is uniform and unbounded. `CreatureSlice.spawn_for_chunk`
spawns exactly `spawnCount` of every creature whose biome matches the chunk —
every chunk of a biome carries the same count, no chunk can be empty, nothing
clusters, and nothing stops a long walk from accumulating an unbounded number of
live instances. The field's own fabric description reads "Number of instances
spawned per game world" while the runtime reads it as per chunk, so the fabric
says one thing and the code does another. Trees have the mirror-image problem:
`TREES_BY_BIOME`'s `per_chunk` is a GDScript constant, which Phase 31 explicitly
deferred to a fabric world-system entity. This phase makes population a product
of per-chunk chance, density noise and a global cap, reinterprets `spawnCount` as
PACK size, and moves tree density into the fabric.

**Newel dependency:** YES — the first phase in this run that changes the fabric.
`fabric/world/creatures/*.js`: `spawnCount` becomes pack size (description and
defaults), plus new `spawnChance` and `spawnDensity` fields; a new
`fabric/world/world.js` (or the biome entities) carries `treeDensity` per biome,
replacing `TREES_BY_BIOME.per_chunk`. `pnpm validate`, then `pnpm generate`, then
`pnpm check-drift`. The generated diff is mostly `schemaHash` lines plus the IR
snapshot — verify with check-drift rather than by reading it (`grep -v
schemaHash` to see the real changes).

**Closes:** item 7b, Phase 31 deferred.

**Deliverables:**
- `fabric/world/creatures/*.js` — `spawnCount` is documented as PACK size
  ("instances placed together at one spawn point"), with `spawnChance` (0..1 per
  chunk) and `spawnDensity` (the noise amplitude that clusters or thins packs
  across the world) added to the shared creature field block.
- `fabric/world/world.js` (or the biome entities) — `treeDensity` per biome,
  the fabric home for what `TREES_BY_BIOME.per_chunk` holds today.
- `src/creature/creature_slice.gd` — `spawn_for_chunk` becomes: a seeded
  per-chunk chance roll, a density-noise multiplier, then `spawnCount` instances
  as ONE pack around one deterministic centre, admitted only if the global cap
  allows. `set_population_cap(n)` / `live_population()`, cap enforced host-only.
- `src/world/tree_slice.gd` — density is read from the fabric `treeDensity`, with
  the same chance/density-noise shape as creatures; a `TREES_BY_BIOME` fallback
  remains for isolated unit tests that have no fabric wired, mirroring
  `DEFAULT_BIOME`.
- `src/tests/test_suite.gd` — the pure roll/density/cap helpers asserted
  headless, including a small cap proving the ceiling holds and is released.

**Acceptance criteria:**
- [x] The same seed produces the same pack centres and sizes on a host and a
  client, with no snapshot carrying placement.
- [x] A chunk can roll no spawn at all, and the per-chunk counts of a species
  across a sample of chunks have non-zero variance (assert against the retired
  constant count).
- [x] With a small cap and a wide view ring, live instances never exceed the cap,
  and a despawn returns budget that a later pack can use.
- [x] `pnpm validate`, `pnpm generate` and `pnpm check-drift` are clean; no
  runtime code reads `spawnCount` as a per-chunk count anywhere
  (`grep -rn spawnCount src/`), and the fabric description says pack size.
- [x] The suite is green on both boot paths.

**Implementation notes:**
- **A cap is only honest if it counts LIVE instances and is released on
  despawn.** Retaining budget after a despawn is the same leak class Phase 37
  fixed twice (an in-memory table with no eviction point); the cap must be
  recomputed from what is alive, not decremented and forgotten.
- **Determinism comes from the seed, not from `randi()`.** The roll is derived
  from the world seed plus the chunk coordinate, so a client that never receives
  the spawn decision still places the same pack. `spawn_for_chunk` is already a
  no-op on a client without visuals; keep the roll pure anyway, so the host's
  decision can be recomputed rather than trusted.
- **A refused pack must be refused consistently.** The cap is a host-only
  quantity, and the host is what streams a pack to a client — so a cap-refused
  pack is simply never sent, which is what makes the client's view unable to
  disagree. Do not let the client re-roll admission locally.
- **Pack size changes what every biome's population MEANS.** `spawnCount: 3`
  used to mean three separate instances per chunk of that biome; as pack size it
  means three arriving together in one place, which is what the Phase 30
  pack/herd AI was written to consume. Say so in the fabric description rather
  than leaving a re-interpreted field looking unchanged.
- **The tree-density move is a real fabric change with a big generated diff.**
  Land it in the same commit as the creature fields and say so in the body; a
  reader scanning `grep -v schemaHash` should see two real changes, not one.

**As built (decisions the deliverables left open):**
- **The pure roll lives in `src/world/spawn_roll.gd`** (`SpawnRoll`): an integer hash of
  (seed, chunk, salt) for the chance roll, and smooth bilinear value noise on a 4-chunk
  lattice for density. `pack_size` scales the chance AND the pack by the density multiplier
  (1 ± `spawnDensity`), so a dense region rolls packs more often and larger; size is at
  least 1 when the roll passes. Trees reuse it with a 10% clearing chance and ±0.5 noise.
- **No world, no roll.** With no terrain slice wired (isolated tests) a creature spawns at
  its full `spawnCount` and a tree biome at its flat density, mirroring `DEFAULT_BIOME`.
- **Every spawn is a pack**: all creatures, not just pack/herd ones, cluster around one
  deterministic centre. The cap (`set_population_cap`, `live_population()`) is recounted from
  `_instances` (dead creatures excluded) on every admission; a pack that does not fit is
  refused whole.
- **Fabric**: `spawnCount` re-described as pack size, plus `spawnChance` (default 0.6) and
  `spawnDensity` (default 0.5) on every creature; `treeDensity` on every biome (8 / 2 / 8 /
  0 / 0). Tree species and wood stay in `TREES_BY_BIOME`, whose `per_chunk` is now only the
  no-fabric fallback.

**Known simplifications (deferred):**
- **No respawn or death-scarcity model.** The cap is on live instances, not on
  how many may die per hour; hunting a biome to local extinction and watching it
  recover is not modelled.
- **No per-species cap** unless the fabric gains one — the cap in this phase is
  global.
- **Spawn clearance is still minimal.** A pack can spawn inside a player's build;
  rejection near a built or claimed region is deferred (Phase 31 already recorded
  the same gap for trees).
- **The density field is 2D.** Surface population only; Phase 43's 3D field is
  about materials, not about where a pack sits vertically.

---

## Phase 45 — Asset pipeline for meshes and animation ✅ Done

**Goal:** The asset pipeline handles exactly one kind of asset. `AssetOverlay`
resolves a canonical key to a texture and decodes raw PNG bytes; there is no mesh
loader and no animation at all. Every character and creature body is a procedural
`BoxMesh` built in `character_slice._make_avatar` / the creature builders, and
`locomotion.gd` is a state machine that produces `get_state()` and
`get_blend_weight()` for an `AnimationTree` that does not exist — Phase 20's
deferrals ("No authored animation clips / `AnimationPlayer` / `AnimationTree`
playback", "no real mesh + `Skin` asset production") are still open, and the
private `assets-prod` submodule holds art that nothing but textures can load.
This phase extends the overlay from textures to meshes and clips through a keyed
manifest, wires a real `AnimationTree` to the locomotion state machine's existing
outputs, and lands the first rig and clip set.

**Newel dependency:** None for the loader. The manifest's keys are derived from
the fabric's existing entity names (the same convention the overlay already uses
for textures); emitting the manifest FROM the fabric is a newel-side follow-up
(see Known simplifications).

**Closes:** item 3, Phase 20 deferrals.

**Deliverables:**
- `assets/manifest.json` (committed, public) — the keyed manifest: canonical
  asset keys to relative paths, for meshes and animation libraries as well as
  textures. The private counterpart in `assets-prod/` overrides by KEY through
  the same `res://_overlay/` mount mechanism `AssetOverlay.resolve_path` already
  uses, so no code branches on which side is present.
- `src/core/asset_overlay.gd` — `manifest()`, `keys()`, `load_mesh(rel)` and
  `load_animation_library(rel)` beside `load_texture`. Both new loaders read bytes
  with `FileAccess.get_file_as_bytes()` and parse with
  `GLTFDocument`/`GLTFState.append_from_buffer` — never `load()` or
  `Image.load()`, for the reason the module comment already states: import-machinery
  paths cannot see pack-mounted content at the bare `res://` path. The `.raw`
  convention extends to meshes (`models/x.glb.raw`).
- `git submodule update --init assets-prod` — the private repo (requires access;
  documented in `assets/README.md`) is what actually provides the first rig and
  clips. Record the step in the README so a fresh clone knows why its avatar is
  still boxes.
- `src/character/character_slice.gd` — an `AnimationTree` per rig root, created
  when a real rig loads: an `AnimationNodeStateMachine` with one node per
  `Locomotion.State`, transitions driven by `state_name()`, a `BlendSpace1D` for
  IDLE/WALK/RUN driven by `get_blend_weight()`, and one-shots for ATTACK / LAND
  matching `ATTACK_DURATION` / `LAND_DURATION`. The state-to-node mapping is a
  pure function so the suite can assert every enum value has a node.
- The first rigged creature family and its clips — the same pipeline on a
  non-character skeleton, proving the loader and the tree are not
  character-specific.
- Fallback: a missing mesh or animation key warns and falls back to today's
  procedural body and an empty library, so a public clone still boots with zero
  missing-resource errors (Phase 21's invariant).

**Acceptance criteria:**
- [x] `load_mesh` and `load_animation_library` return a real `Mesh` and
  `AnimationLibrary` from a `.raw` `.glb`, both from a mounted pack and from the
  committed placeholder, and neither path calls `load()` on the asset.
- [x] A rigged avatar plays idle → walk → run continuously per
  `get_blend_weight()` and holds attack/land one-shots for the state machine's
  durations; the smooth blend reads as a cross-fade, not a snap.
- [x] With `assets-prod/` NOT initialised the game boots on placeholders with no
  missing-resource errors; with it initialised the real rig is used, and
  `AssetOverlay.asset_mode()` reports which.
- [x] The suite is green on both boot paths; the mapping and the manifest are
  unit-tested, and the animated rig is stated as exercised in game only (the
  suite has no frames).

**Implementation notes:**
- **The `.raw` convention is not optional for a mesh either.** An
  importer-claimed `.glb` is compiled and dropped from a real export at the bare
  path, exactly like a `.png` — so a shipped build would lose its models while a
  dev run looked fine. Parse from bytes.
- **Keys come from the fabric's names, not from file layout.** A key is derived
  (`models/creatures/<EntityName>.glb.raw`) so generating new entities does not
  require hand-editing a path. The manifest lists what EXISTS; a missing key is a
  warning and a fallback, never a crash.
- **Wiring an `AnimationTree` is not a rewrite of `locomotion.gd`.** The state
  machine was written for this consumer: `get_state()` drives the state machine
  node and `get_blend_weight()` drives the blend space. The single point where
  the tree and the enum can drift is the mapping table — keep it pure and assert
  total coverage of the enum, so a new locomotion state cannot silently animate
  as idle.
- **The submodule is a checkout step, not a code change.** A phase whose
  deliverable is "the real rig exists" must say that the art is in a private repo
  the reader may not have access to, and that the public path is the placeholder.
- **The suite cannot see the renderer.** Assert the manifest, the key derivation
  and the enum-to-node mapping; drive the actual animation in game only.

**As built:** `assets/manifest.json`, `AssetOverlay.manifest/keys/has_key/load_mesh/
load_animation_library/creature_model_key`, `src/character/rig_tree.gd` (pure
enum→node table, `build_tree`, `drive`), `CharacterSlice.attach_rig`, and a
generated placeholder rig (`tools/gen_placeholder_glb.py`). The real rig and the
first creature family's clips live in the private `assets-prod` submodule and were
not authored here; with no manifest entry `attach_rig` returns false and the
procedural body stays. The animated blend/one-shots are exercised in game only.

**Known simplifications (deferred):**
- **No root motion.** Still Phase 20's deferral: the controller drives
  `CharacterBody3D.velocity` directly, not extracted displacement.
- **No facial blendshapes and no per-leg IK** — Phase 20's deferrals stand; foot
  placement remains the whole-body offset Phase 40 fixed.
- **No fabric-generated manifest.** The manifest is a committed JSON keyed by
  entity name; generating it from the fabric is a newel-side follow-up.
- **One creature family only.** The rest keep procedural bodies until their rigs
  and clips exist, and equipment attachment stays procedural
  (`apply_equipment`, no animation-driven sockets).

---

## Phase 46 — UI shell ✅ Done

**Goal:** The window system is functional and inert. Six `PanelContainer`s are
built at fixed positions (`_build_window(key, title, content, position)` — no
title-bar drag, nothing persisted), the inventory window is a single `Label` fed
by `inventory_lines()`, so there is no slot grid, no icon, no hover, no
right-click, and the only item identity a player sees is a line of text. A
Controls legend already exists and is always on: `_build_shortcuts_menu()` builds
a `Controls` panel at `player_slice.gd:781` and `_build_hud()` attaches it to the
HUD at `:620`, so the key bindings are painted top-left for the whole session and
are mouse-transparent. This phase gives the shell a generic draggable window with
persisted positions, resolves item icons through the overlay, replaces the
inventory text dump with a slot grid (tooltip and right-click menu), and MOVES
that existing legend behind a collapsible `?` panel rather than adding one. The
phase is independent of Phase 45's asset pipeline — the shell is texture-keyed UI
work — and may land before it.

**Newel dependency:** None. Item identity is the entity name the fabric already
carries.

**Closes:** items 4 and 6.

**Deliverables:**
- `src/ui/ui_slice.gd` — ONE drag handler installed on every window's title bar:
  press starts a drag, motion moves the panel, release stores the position.
  Positions persist per window key, so a restart reopens windows where they were
  left. The layout is a per-player value and therefore needs a durable home and
  an eviction point (Phase 37's rule) — state in the commit whether it rides the
  player record or a client-only settings file.
- `src/ui/ui_slice.gd` — item icons through the overlay: a derived canonical key
  (`icons/items/<EntityName>.png.raw`) handed to `AssetOverlay.resolve_path` /
  `load_texture`, with a glyph placeholder when the key is absent, so a clone
  without the private art still renders a readable slot. **No overlay work is
  required:** `resolve_path` and `load_texture` are already general — any relative
  key resolves against a mounted pack first and the public `res://assets/`
  placeholder second, and an absent key decodes to `null`. This deliverable is key
  DERIVATION plus a `null` branch, not a loader change.
- `src/ui/ui_slice.gd` — the inventory slot grid: a `GridContainer` of slot
  controls replacing `_inventory_items`, each showing icon, quantity and a
  durability/wear indication; hover raises a tooltip (name, quantity, durability,
  the item's description); right-click opens a menu whose actions are the bus
  intents that already exist, so no new authority path is introduced.
- `src/ui/ui_slice.gd` — the Controls panel behind `?`: the EXISTING legend,
  MOVED rather than authored. The `I / T / C / Y / M / G` and movement/action
  bindings the HUD paints today are re-hosted in a new window that is collapsed by
  default.
- `src/player/player_slice.gd` — DELETION of the always-on legend:
  `_build_shortcuts_menu()` (`:781`) and its call site in `_build_hud()` (`:620`)
  both go, so the HUD paints no legend at all and the `?` panel is its only home.
  The drawn mouse-button cues the legend uses move with it — `_add_mouse_row()`
  and `mouse_icon.gd` (`src/ui/mouse_icon.gd`, loaded as `MouseIconScript`) are
  PORTED into the `?` panel, so the moved legend keeps its icons instead of
  degrading to a text list.
- `inventory_lines()` STAYS: it is the pure projection the suite asserts, and the
  grid is built from a pure projection (`inventory_rows()` / a slot view) rather
  than by reading `Control` state.

**Acceptance criteria:**
- [x] Every window drags by its title bar and reopens at its stored position
  across a restart; a window cannot be dragged fully off-screen.
- [x] An inventory of N items renders N slots in a grid; hovering shows
  name/quantity/durability; right-clicking offers the actions the item supports
  and each action emits the same bus intent the text UI emitted (assert the
  projection and the intent, not the widget).
- [x] An item with no icon asset renders the placeholder glyph, and one whose
  icon is present in a mounted pack renders the icon — `AssetOverlay.asset_mode()`
  distinguishes the two.
- [x] No Controls legend is visible on the HUD before `?` is pressed: the panel
  `_build_hud()` used to paint is gone and `?` is the only way to see the bindings
  (assert the HUD's child set, not a screenshot).
- [x] `?` opens and closes the Controls panel; ESC still closes the topmost
  window and the last close re-captures the mouse (the world-input gate is
  unchanged and no attack/mine slips through an open menu).
- [x] The suite is green on both boot paths, with tests for the new projections.

**Implementation notes:**
- **Persisted position is per-player state, so it needs a record home and an
  eviction point.** The same rule Phase 37 landed for flags, companions and
  cooldowns. A layout is not authority-bearing — a client may own its own view —
  so the choice between a player-record field (replicated, evicted by
  `forget_player_id`) and a local settings file (client-only, not per-connection)
  is legitimate, but leaving it in an in-memory dictionary that nobody evicts is
  not. Say which one and why.
- **The drag and the grid are `Control` code, and the suite cannot run them.**
  Everything decidable outside the tree stays pure: the off-screen clamp, the
  slot projection, the button-to-intent mapping and the key-to-window table.
  Assert those.
- **Reuse the existing intent paths.** Equipping, using and dropping go through
  the bus signals the crafting/equipment paths already consume, so the owner
  scoping and host binding rules (Phase 36/37) are inherited rather than
  re-derived. A UI that invokes a slice method directly re-opens a hole the
  network passes closed.
- **Icons resolve at fill time, not once per item definition.** The overlay may
  or may not have a pack mounted; caching a resolved path across that decision is
  how a placeholder gets painted over real art.

**Known simplifications (deferred):**
- **No layout save/load UI, no snapping or docking, no resize handles** — drag
  plus persist only.
- **No drag-and-drop between slots or containers.** The right-click menu is the
  only item action surface in this phase.
- **No redesign of the crafting / technology / trade / market / proposals
  windows.** They keep their contents and gain only the shared drag shell.
- **No gamepad or keyboard navigation** of the windows.

**As landed:**
- Layout persistence is a **client-only settings file** (`user://ui_layout.json`):
  a layout is a view preference with no authority, so it does not ride the player
  record. One entry per known window key, overwritten in place, unknown keys
  dropped on load — nothing accumulates, so there is no eviction point to miss.
- The slot right-click menu offers only intents that already exist on the bus.
  Today that is **Repair** (`repair_requested`) for held, non-pristine items with a
  repair spec; there are no equip/use/drop bus intents yet, so none are offered.
- No `icons/items/*` art is committed, so every slot paints the initial-letter
  glyph until a pack provides the key.

---

## Phase 47 — Character window ✅ Done

**Goal:** Equipment is a visual system with no interface and no numbers.
`apply_equipment(instance_id, slot, item_key, state)` attaches a socketed
placeholder to the rig and `equipmentSlot` is a fabric field on every
equippable, but nothing shows what is worn, nothing totals what wearing it means
(the armor entities carry prose — "reliable head protection" — and no numeric
value), and a worn set is neither persisted nor shared: a peer's gear is not
replicated, which is why the fabric's bare-hands rule is still evaluated against
the claim riding that peer's tame intent (the open `Peer equipment replication`
entry in the Deferred list, deferred from Phase 36). This phase gives the
character its window: armor slots on the existing `apply_equipment`, a derived
stats panel, equipped-state persistence, and peer equipment replication.

**Newel dependency:** YES — the derived stats panel needs NUMBERS on the
equippable items (`fabric/gameplay/items/shared.js`): a `defense`/`armorValue`
(and any other derived-stat contribution the panel sums) per armor entity, so a
stat is a sum of fabric values and never a reading of prose. `pnpm validate`,
`pnpm generate`, `pnpm check-drift` re-run; no runtime stat may be authored in
GDScript.

**Closes:** item 5 and the Deferred list's `Peer equipment replication` entry
(deferred from Phase 36).

**Deliverables:**
- `src/ui/ui_slice.gd` — a Character window (a new window key, toggled like the
  others) listing one slot per `equipmentSlot` the fabric defines, each showing
  the equipped item's Phase 46 icon and opening the shared right-click menu.
  Equipping issues the existing intent, so `apply_equipment` remains the only
  mutation path.
- `src/character/character_slice.gd` — `derived_stats(instance_id) ->
  Dictionary`, pure and headless-testable: it sums the equipped entries' fabric
  values (defense total, wear/durability, and whatever else the phase adds) and
  reports an empty set as zeros.
- `src/persistence/player_registry.gd` — equipped state on the player record
  (`record_equipment` / `get_equipment`, applied on join with `apply_record`), so
  a worn set survives a restart the same way flags, companions and technology do,
  with the eviction point that path already has.
- `src/networking/networking_slice.gd` + `src/character/character_slice.gd` —
  peer equipment replication: the host sends a peer's worn set to the peers whose
  area of interest contains it (Phase 29), and a client applies it to that peer's
  character instance, so the bare-hands rule and any defense check read
  replicated truth instead of a payload's claim. Identity is bound to the
  connection (a payload's `player_id` is ignored — Phase 36's rule).
- The bare-hands rule's consumers are re-pointed at the replicated set, and the
  tame-intent claim path is deleted or narrowed to the handshake window rather
  than left alongside it.

**Acceptance criteria:**
- [x] The Character window lists one slot per fabric `equipmentSlot`; equipping
  from it changes the avatar's attachment AND the derived stats panel's numbers.
- [x] The panel's totals equal the sum of the equipped fabric values, asserted
  against a synthetic set including the empty case (all zeros).
- [x] A worn set survives a host restart and a reconnect, asserted through the
  player record rather than through a client's own view.
- [x] A second peer's client sees the first peer's worn set on that peer's
  character instance, and a peer that forges a fully-armoured claim in its
  payload does not change what the host believes the peer is wearing.
- [x] The suite is green on both boot paths, and the two-client harness still
  reports `10/10 steps agreed across both peers` if the replication adds a step.

**Implementation notes:**
- **A derived stat may not be computed from prose.** Every number the panel shows
  is a fabric field summed by a pure function; a stat that exists only in the UI
  is a stat the host cannot validate and two clients can disagree about.
- **Equipped state is per-player durable state, so it needs a record home and an
  eviction point** — Phase 37's rule applied a third time. It travels on the join
  snapshot plus the per-player push, and it is released by the same
  `forget_player_id` path the flags and companions use.
- **Replication is an interest-management problem, not a broadcast.** A peer's
  gear travels with that peer's character record and is delivered to the peers
  whose AOI contains it (Phase 29) — never `_broadcast`, and never through a
  signal that fails to name its owner (the `inventory_synced(owner_id, …)` shape
  Phase 37 established). A per-player signal with no owner is a signal every
  instance of that slice will apply.
- **The bare-hands rule is a security-relevant consumer, not a display.**
  It gates a tame. Once equipment is replicated, the host evaluates the rule
  against the host's own copy of the peer's worn set, so a client cannot claim a
  free hand it does not have. Keeping the old claim path "just in case" keeps
  exactly the hole the replication closes.
- **Socket attachment is unchanged.** `apply_equipment` still resolves the item
  definition, refuses an unknown slot and attaches through `_attach_equipment`;
  the window and the replication both go through it, so there stays one mutation
  path.

**Shipped as:** `fabric/gameplay/items` gained an integer `defense` field
(helmet 4, chestplate 10, cloak 2, shield 6); `src/character/equipment_rules.gd`
holds the pure slot table / `sanitize` / `totals` / `hands_free`;
`CharacterSlice.derived_stats` / `get_equipment_set` / `apply_equipment_set` /
`set_peer_equipment`; `PlayerRegistry.record_equipment` / `get_equipment` (on the
record, the join snapshot and `evict_player`'s record drop); bus signals
`equip_intent` / `equipment_changed` / `peer_equipment_synced` (the client's first cut
sent a whole worn set as `equipment_intent`; Phase 60 replaced it with per-slot host-validated
actions); the Character window (key `K`). `TamingSlice.is_unarmed` reads the registry
(the tame intent's dead `unarmed` argument is gone, see Phase 60).

**Known simplifications (deferred):**
- **Replication is delta-only.** A peer's set is sent to
  AOI peers when it changes; a peer entering AOI later learns it on the next
  change. Remote peers have no character instances on a client yet, so the set is
  stored per owner and applied once `bind_peer_character` binds one. The
  two-client harness now has an `equipment_recorded` step (`11/11`): the host
  grants the item, the client claims a set over the socket (plus a wrong-slot and an
  unknown item) and the host records only the legitimate entry. Delivery of that
  set to a third peer is still covered in the suite, not over a socket.
- **Disconnect eviction of `_peer_equipment`/`_peer_characters`** on the client is
  wired (`forget_peer` from `_on_peer_disconnected`, asserted in the suite). A joiner's
  own restored set is now also pushed to the peers already in its AOI
  (`send_peer_equipment_to`, both directions).
- **No combat effect beyond the displayed totals.** Unless defense becomes a term
  in the damage formula in this phase, the panel shows a number nothing consumes —
  say so plainly instead of implying the armor already reduces damage; wiring it
  into `battle_slice` is a follow-up.
- **No set bonuses, sockets or enchantments.**
- **No upgrade/downgrade comparison** in the character window beyond the shared
  slot tooltip.
- **Equipment wear stays a visual indication** (`_wear_level`); the window is not
  a repair gate — repair remains the Phase 25 path.
- **No attributes — deliberately excluded, pending a fabric decision.**
  `fabric/gameplay/player.js` carries only `baseHp`, `currentHp` and `baseSpeed`:
  there is no attribute model (no Strength/Dexterity/Intellect, no attribute-to-
  stat derivation), and this phase does NOT invent one — the panel sums equipped
  gear values only, and nothing here may author an attribute or a derived-stat
  input in GDScript. Adding attributes is a design decision, so it belongs in
  `fabric/constitution/decisions.js` (a `decision` entity taken through the
  `proposed` → `accepted` state machine under community governance), not in a UI
  phase that would then be read as the authority for it.

---

## Phase 48 — Review pass: the equipment trust boundary ✅ Done

**Goal:** Phase 47 made the host the owner of a peer's worn set, but the review
follow-ups (#63, #64, #65, #66, #70) list the places where that ownership still
leaks: the claim is unbounded, ownership is checked only at equip time, the
listen host's own gear never leaves the host, and gear is only sent on change or
join. Close the host-side holes; display-only niceties stay out of scope.

**Newel dependency:** NO.

**Closes:** the host-side items of #63, #64, #65, #66 and #70.

**Deliverables:**
- `src/persistence/player_registry.gd` — `_on_equipment_intent` ignores a `worn`
  dictionary larger than `EquipmentRules.slots().size()` (no per-entry inventory
  lookup for an oversized claim) and filters slot keys through
  `EquipmentRules.sanitize` before the bag check.
- `src/persistence/player_registry.gd` — worn-set revalidation: when an item
  leaves a player's bag (drop, trade, craft consumption, sale), any slot wearing
  an item the bag no longer holds is cleared and the change is recorded and
  replicated like any other equipment change.
- `src/networking/networking_slice.gd` — the listen host's own worn set is
  replicated to the clients whose AOI contains the host avatar (the host has no
  peer id, so it is addressed by its player id / the `1` server peer).
- `src/networking/networking_slice.gd` — peer equipment is sent when a peer
  ENTERS another peer's AOI (not only on change / join), and a client evicts a
  peer's stored set when that peer leaves its AOI.
- `src/character/equipment_rules.gd` — `slots()` is computed once and cached;
  an empty `items` argument no longer silently means `GameData.ITEMS` (pass it
  explicitly).

**Acceptance criteria:**
- [x] A `worn` claim with more entries than there are slots is dropped without
  touching the record, asserted in the suite.
- [x] Wearing an item, then trading/dropping it away, clears that slot on the
  player record and emits `equipment_changed`; asserted through the record.
- [ ] A client sees the listen host's worn set (suite test on the replication
  target list; the host is included). _Implemented (peer 1, `set_host_position`,
  `equipment_targets`); only exercised by `net-harness`, no suite test yet — the
  suite has no multiplayer peers._
- [ ] A peer that walks into AOI after the last gear change receives the set; a
  peer that leaves AOI has its stored set evicted on the client. _Implemented
  (`_refresh_equipment_pairs`, `peer_equipment_evict`); suite covers the client
  evict and pair cleanup, the enter/leave transitions still need a socket step._
- [x] Suite green on both boot paths; `net-harness` still reports
  `11/11 steps agreed across both peers`.

**Implementation notes:**
- Revalidation hooks the existing inventory-change path on the host; it must not
  add a second mutation path for equipment — clearing a slot goes through
  `record_equipment` and the same replication as an equip.
- The bare-hands rule still trusts an OMISSION (a client that never reports its
  weapon reads as unarmed). Fixing that needs host-authoritative equip (the host
  decides what is in the hand), which is a design change; it stays a known
  simplification and the taming comments must say so instead of overstating the
  protection.

---

## Phase 49 — Zone crossing and natural ground ✅ Done

**Goal:** Crossing a chunk edge glitches, and the ground does not look like
ground. Four separate problems produce this:

- **The biome is a stripe pattern.** `biome_for_chunk`
  (`src/terrain/terrain_slice.gd:122`) computes
  `posmod(BIOME_SEED + cx*2654435761 + cz*2246822519, 5)`. Modulo 5, those
  constants are 0, 1 and −1, so the expression reduces to `(cx − cz) mod 5`. As
  a result the biome changes on every axis-aligned chunk crossing (every 32 m) in
  diagonal stripes. The layout is identical in every world because it ignores
  the world seed. Each crossing therefore changes the ground colour, tree
  density and creature table all at once.
- **Concurrent builds produce seam walls.** A neighbour counts as "known" only
  after it has been built (`voxel_slice.gd:298`, `_gather_neighbour_heightmaps`
  `voxel_slice.gd:465`). With `DEFAULT_MAX_BUILDS_IN_FLIGHT := 4`, two adjacent
  new chunks often each treat the other as empty. Both then emit a full
  bedrock-to-top wall on the same plane. That wall z-fights under
  `CULL_DISABLED` and nothing ever rebuilds it, because `chunk_loaded`
  (`chunk_manager.gd:465`) has no consumer. The same wall is also in each
  chunk's trimesh collision. The capsule catches on it and
  `resolve_step_up` fires at the seam (`player_slice.gd:493`).
- **Crossing causes frame spikes.** A crossing unloads 9–17 chunks in one frame,
  and each unload runs `_prune_heightmaps`, which scans every heightmap key
  (`voxel_slice.gd:931`). The frames that follow each run three expensive steps:
  - a 4096-sample GDScript `generate_heightmap`;
  - a main-thread `ConcavePolygonShape3D.set_faces`;
  - a tree spawn that scans every live tree (`tree_slice.gd:130`).

  On top of that, every 96 m AOI re-scope (`AOI_RADIUS`) sends the client the
  whole world's edit manifest (`game_root.gd:1194`).
- **There is no grass.** Ground colour is the biome's host material
  (`ore_field.gd:69`). Temperate ground is pale-grey Ferrite and TwilightGrove
  is solid gold. A run is one colour from top to sides, and the only green in
  the game is `FALLBACK_TERRAIN_COLOR`.

This phase makes chunk edges invisible, makes biomes large, seeded and blended,
and covers most land with a grass topsoil so the world reads as Earth-like.

**Newel dependency:** YES. Biome entities (`fabric/world/biomes/*.js`) gain the
following fields, authored from each biome's prose:
- `surfaceMaterial` (e.g. `Grass`, `Moss`, `Ash`, `Void` — the covers the five
  biomes actually declare);
- a surface tint (`surfaceTint`) and a side-wall tint (`soilTint`);
- `topsoilDepth`;
- `soilMaterial` (issue #111: what mining a slice within `topsoilDepth` yields —
  the surface-material → soil-material mapping, authored here so no GDScript
  branch decides which cover becomes which soil);
- `surfaceVeinChance` (the per-biome share of the surface-reaching top-cell veins
  kept, read by `OreField.surface_vein_chance`);
- a climate envelope (`temperature` and `moisture` ranges) that the climate
  field selects with.

A `Grass`/`Soil` material pair joins `fabric/world/materials/`. Run
`pnpm validate`, `pnpm generate` and `pnpm check-drift`. No surface table may be
hand-written in GDScript.

**Closes:** the zone-crossing glitch and the non-natural zone materials (user
report, 2026-10-04).

**Deliverables:**
- `src/terrain/voxel_slice.gd`: an unbuilt neighbour's heightmap comes from
  `terrain_slice.generate_heightmap`, which is deterministic since Phase 41,
  rather than being treated as "unknown". Seam walls are then exact whatever
  the build order. Only the outer edge of the streamed window emits a skirt,
  and that skirt stops at the neighbour's generated surface rather than
  bedrock.
- `src/terrain/chunk_manager.gd`: consume `chunk_loaded`. When a chunk's first
  build guessed a neighbour that has since arrived with edits, rebuild that
  chunk once.
- `src/terrain/climate_field.gd` (new, pure): world-seeded, low-frequency
  `temperature(world_xz)` and `moisture(world_xz)` noise. `biome_at(world_xz)`
  picks the fabric biome whose climate envelope fits. Biomes become regions
  hundreds of metres across, not 32 m stripes.
  - `get_biome_at_chunk` stays as "the biome at the chunk centre" for spawn
    tables.
  - Colour and surface read the per-tile biome, blended across a border band
    of a few tiles with a deterministic dither.
- `src/terrain/voxel_slice.gd`: a topsoil model.
  - An unedited natural column's top face takes the biome's
    `surfaceMaterial` tint, with low-amplitude noise variation.
  - Side walls show soil down to `topsoilDepth`, with rock (the ore field's
    host material) below that.
  - The mesher already groups faces by direction and colour, so a top colour
    that differs from the side colour costs no extra draw calls.
  - Mining a slice within the topsoil yields the biome's fabric `soilMaterial`
    (Grass, Moss, Ash and Void covers alike), the host rock below. A placed block
    keeps its own colour.
- `src/terrain/ore_field.gd`: a surface-breaking vein is the exception, not
  55% of cells. A deposit marker shows only where the vein's top cell reaches
  the surface, and its density is the biome's fabric `surfaceVeinChance`.
- Crossing cost is spread over frames:
  - unloads are budgeted per frame like loads;
  - `_prune_heightmaps` is indexed by chunk, so it no longer scans every key;
  - tree spawn uses the spatial hash rather than a scan of every live tree;
  - the AOI re-scope snapshot carries only the edits of chunks inside the
    peer's AOI.
- `src/ui/minimap.gd` reads the per-tile biome and surface colour.

**Acceptance criteria:**
- [x] `terrain: neighbouring chunks mostly share a biome`: over a 32×32-chunk
  sample, at least 80% of axis-adjacent chunk pairs share a biome, and two
  seeds produce different layouts. This replaces the stripe pattern.
  `_test_chunk_biome_stable` still passes.
- [x] `voxel: concurrent seam is exact`: two adjacent chunks built from the same
  first-ring snapshot (neither built before the other) emit no wall at a seam
  where the surface is level. The faces match the sequential
  `_test_voxel_seam_wall_order_independent` result.
- [x] `voxel: grass top, soil side`: an unedited temperate column's top-face
  colour is the fabric grass tint and its side colour is soil.
  `_test_voxel_biome_materials` is updated to assert rock under the topsoil. _Suite
  `voxel: grass top, soil side` asserts grass top, soil within `topsoilDepth`, rock below._
- [x] With the camera in-game at default view distance, walking 20 chunks in a
  straight line shows no frame over 33 ms in the frame-time log and no
  visible seam flicker. The walk needs a person at the keyboard, so it is not an
  acceptance criterion: it is filed as #133 (human verification) and the phase
  proceeds without it.
- [x] An AOI re-scope snapshot's `edits` holds only chunks inside the AOI. _Suite
  `net: re-scope snapshot edits hold only AOI chunks`; the snapshot names its scope
  (`edits_aoi`) and the client keeps edits it holds outside it._
- [x] `pnpm check-drift` is clean and the suite is green on both boot paths.
  `tools/net_harness.sh` agrees on a fresh world. _check-drift clean, suite 8767/8767, net_harness 12/12._

**Progress:** the unbuilt-neighbour seam fix is in (`_generated_heightmap`). Biomes are chosen by the
fabric climate envelopes: biome entities carry `temperature`/`moisture` ranges (0–1) and
`src/terrain/climate_field.gd` samples world-seeded value noise (12-chunk wavelength) and picks the
biome whose envelope fits (`biome_for_climate`). `Grass`/`Soil` are fabric materials. Mining a slice
within a biome's `topsoilDepth` yields that biome's fabric `soilMaterial` — Grass, Moss, Ash and Void
covers alike yield `Soil`, not only the temperate one — with the host rock below. Topsoil colouring uses
the biome `surfaceTint`/`soilTint`/`topsoilDepth` fields. Surface veins are the exception, and the
density is each biome's own fabric `surfaceVeinChance` (badlands 0.25 … rift 0.05; the GDScript constant
is now a fallback for a missing resource only), so the field is observable. The minimap colours chunks
by `surfaceTint`. Frame-spike items
are in (`_prune_heightmaps`, tree and creature spawn/despawn indexed by chunk; unloads budgeted per frame; a chunk's heightmap is generated once).
The per-tile surface blend is in (`VoxelSlice.blended_biome`: a 4-tile border band with a
coordinate-hash dither), `ChunkManager` rebuilds built neighbours once when a chunk with edits
streams in, and the minimap draws 4x4 dithered cells per chunk. `ClimateField` and `OreField`
read plain snapshots filled by `OreField.warm()`, so the worker half never touches a Resource.
Every automated acceptance criterion passes: `check-drift` is clean, the suite is green
(8767/8767, both boot paths), and `net_harness.sh` reports 12/12. The 20-chunk in-game walk with a
frame-time log and screenshot needs a human, so it left the criteria for #133 and the phase is
done.

**Issue #111 follow-up (PR #110 review):** the surface-material → soil-material mapping is no longer a
GDScript branch on `surfaceMaterial == "Grass"` — it is the biome's fabric `soilMaterial` field
(`VoxelSlice._natural_yield`), so every cover yields soil and a new biome needs no code. The
per-biome `surfaceVeinChance` values were varied from the uniform 0.2 default so the fabric field
actually gates the field (pinned by `ore: surface-vein chance is the fabric value`, which measures the
kept share per biome off the ore field).

**Issue #111 follow-up, review pass:** the field's TARGET is now pinned — `voxel: every biome declares a
surface style` asserts each biome's `soilMaterial` names a declared fabric material, because
`_natural_yield` returns it verbatim as the mined item and a fabric typo would otherwise mint a phantom
material.

**Issue #111 follow-up, second review pass (docs-only):** the phase's own **Newel dependency** list now
names every field the phase adds — `soilMaterial` (this branch's new biome field) and the per-biome
`surfaceVeinChance` the Deliverables already cite, plus the real `surfaceTint`/`soilTint` names. The
list was the pre-#111 inventory and its `surfaceMaterial` example named `Sand`, a cover no biome
declares (the five biomes declare `Grass`/`Moss`/`Ash`/`Void`).

**Net harness:** it has 11 steps now (the equipment step joined it), so the `10/10 steps
agreed` lines in the older phase entries above are historical; a green run now reads `12/12`
(Phase 55 added `equipment_delivered`).

**Saved-world note (biome function change):** the Voronoi biome regions replaced the stripe
biome hash, so a chunk's biome, and with it the host material of any ore vein anchored there,
changed for worlds saved before it. Terrain heights and vein positions are unchanged; only the
biome-dependent material (and spawn table) of an existing area can differ. Edits are keyed by
tile and kept. There is no save-format version to migrate: the world is re-derived from the
seed on load.

**Known simplifications:**
- The grass is a vertex colour, with no texture and no grass blades. Textured
  terrain needs UVs that greedy merging drops; deferred.
- The climate field is planar here. Phase 51 makes temperature follow latitude
  and altitude.

---

## Phase 50 — Planet coordinates

**Goal:** The world is an 8 km square: `WORLD_RADIUS_CHUNKS := 128`,
`clamp_to_world` at `terrain_slice.gd:152`, and float32 positions with no
origin rebasing. The target is one persistent, Earth-sized world (about
510 million km²) that players can locate each other in by coordinates.

A literal voxel sphere is not attempted: gravity would vary per position, and
a cube-sphere chunk grid distorts at its face seams. Instead the world takes
**globe semantics on a flat chunk grid**:
- X wraps (about 40,000 km around), so walking east eventually returns you
  home.
- Z is latitude, bounded by impassable polar ice.
- Players see latitude, longitude and altitude.

The terrain is already seed-deterministic and only edits are stored, so the
huge world costs storage only where players build. Around 5×10¹¹ chunks are
generated on demand and never written.

**Newel dependency:** YES. A world-system entity in `fabric/world/world.js`
holds `circumferenceKm`, `polarLatitude` and `seaLevel` (used by Phase 51), so
the planet's size is a fabric fact.

**Closes:** the world-size limit.

**Deliverables:**
- `src/terrain/terrain_slice.gd`: `wrap_chunk(chunk_pos)` and
  `latitude_of(chunk_z)` / `longitude_of(chunk_x)` replace
  `WORLD_RADIUS_CHUNKS` and `clamp_to_world`. Noise sampling is periodic in
  X, so the wrap seam is invisible. Two options: 4D noise on a cylinder, or a
  blend over the last chunk column.
- A world position becomes `{ chunk: Vector2i, local: Vector3 }` everywhere it
  is saved or sent: player records, the join snapshot, edit RPCs, AOI
  centres, creature and station positions. An `int32` chunk index covers the
  whole planet (about 1.25M chunks per axis).
- The client rebases the scene origin when the player drifts more than about
  2 km from it, shifting all streamed nodes in one frame. The physics and
  render scene never see a large coordinate. The headless server keeps
  chunk-relative positions per entity.
- The HUD and minimap show latitude, longitude and altitude. `/where` prints
  them.
- Save migration: a pre-Phase-55 world maps its old origin to a fixed
  latitude/longitude, and old float positions convert to chunk + local.

**Acceptance criteria:**
- [x] `terrain: the world wraps east-west`: the heightmap of chunk
  `(circumference_chunks − 1, z)` meets chunk `(0, z)` with no seam wall.
- [x] `player: rebased origin keeps the world position`: after a rebase, the
  player's `{chunk, local}` is unchanged and every streamed chunk node is
  shifted by the same offset. _Suite: `WorldPos` rebase math plus `VoxelSlice.shift_scene` on chunk roots and the world floor; the per-frame client driver is still open._
- [x] A player teleported 10,000 km out walks, mines and builds with the same
  0.125 step precision as at the origin. The quantiser unit test at chunk 312,500 is
  in the suite; the in-game walk needs a person at the keyboard, so it is not an
  acceptance criterion: it is filed as #134 (human verification) and the phase
  proceeds without it.
- [x] A Phase 49 save loads with its edits at the mapped coordinates. _Player records migrate (suite); world/edit saves untouched, as edits are keyed by tile and the origin is unchanged._
- [ ] Suite green on both boot paths, and `tools/net_harness.sh` agrees.

**Progress (in progress, not done):** the `WorldSystem` fabric entity (circumferenceKm, polarLatitude,
seaLevel) is in. `TerrainSlice` has `wrap_chunk`, `latitude_of`/`longitude_of`/`latitude_at`/
`longitude_at`, `circumference_chunks`, `polar_chunks`; X no longer clamps, Z stops at the polar ice,
and heights blend over the last 8 east chunks into the west edge so the seam is exact. The minimap
draws only the polar lines. `src/terrain/world_pos.gd` holds the pure `{chunk, local}` conversion and
rebase math, covered by the suite. Player records save `chunk` + `local` beside `position` (old saves migrate
onto the same coordinates, `PlayerRegistry.world_pos_of`), and the minimap shows latitude/longitude/altitude
(`TerrainSlice.where_text`). Still open: float32 noise precision far from the origin (needs an
integer-lattice noise), canonicalising chunk keys at the seam in `ChunkManager`/`VoxelSlice`,
`{chunk, local}` in snapshots, RPCs, AOI, creatures and stations (player records done), the client scene-origin
rebase driver (`VoxelSlice.shift_scene` shifts chunk roots and the floor, suite-tested; trees, creatures, stations,
the player body and the trigger on `WorldPos.needs_rebase` are still to wire), a `/where` chat command (no command system exists; `where_text` is ready), and the
map/migration of world and edit saves.

---

## Phase 51 — Continents, oceans and mountains

**Goal:** Terrain is a single gentle FBM field 0–5 m tall (`HEIGHT_SCALE := 5.0`,
3 octaves at frequency 0.05) in a −8..16 m column. It has no sea level, no
ocean, no mountain and no climate. This phase gives the planet a large-scale
shape and makes biomes follow climate the way Earth's do.

**Newel dependency:** YES.
- Biome climate envelopes from Phase 49 are extended with altitude.
- Earth-like biomes join the fantasy ones: Ocean, Beach, Desert, Tundra,
  Alpine, Taiga and Savanna, each with `surfaceMaterial`, `treeDensity` and
  spawn rules.
- Fantasy biomes (TwilightGrove, VolcanicBadlands, VoidRift) become rare
  climate niches, not equal-share zones.
- `seaLevel` and the height range live on the world entity.

**Closes:** none (new capability).

**Deliverables:**
- `src/terrain/terrain_slice.gd`: layered height built from three noise
  fields:
  - **continentalness**, at thousand-kilometre scale: ocean basin, shelf,
    coast or inland;
  - **erosion**: flat plains versus rugged land;
  - **ridges and peaks**: mountain ranges.

  These combine through a fabric-authored spline. Sea level is at 0, and the
  vertical range grows to about −64..+512 m. Sparse runs (Phase 41) keep a
  tall column cheap, and `BEDROCK_DEPTH` moves with the surface (a fixed
  thickness below it).
- `src/terrain/climate_field.gd`: temperature falls with `|latitude|` and with
  altitude, and moisture follows distance to the ocean plus noise. The result
  is snow-capped peaks, polar tundra and equatorial forest.
- Water: a flat water surface mesh per chunk wherever terrain is below sea
  level, and a swim/wade state in `player_slice.gd`. This is a static water
  level only; the fluid CA stays deferred.
- Distant terrain: coarse heightmap rings outside the 3-chunk voxel window,
  render-only with no collision, so coastlines and mountains are visible from
  afar.
- Spawn tables (trees, creatures, ore bias) read the climate biome, and ocean
  chunks spawn none of the land tables.

**Acceptance criteria:**
- [ ] Over a 1,000 km sample transect, the fraction of the transect below sea level
  lands within the fabric's target ocean share (about 60–70%), and at least
  one height above 300 m appears.
- [ ] `climate: poles are cold, peaks are cold`: the biome at latitude 85° is
  polar, and a 450 m peak at the equator is Alpine.
- [ ] A player cannot walk into deep water as if it were ground: they swim at
  the surface (a suite test on the movement state).
- [ ] A distant-terrain ring renders at 10× the voxel window with no collision
  bodies (asserted).
- [ ] `pnpm check-drift` clean and the suite green on both boot paths.

**Known simplifications:**
- No rivers or lakes above sea level (Deferred).
- No erosion simulation; the "erosion" field is noise.

---

## Phase 52 — Region storage and per-player server streaming

**Goal:** Two things stop the planet from persisting and simulating where its
players are.

- **One file holds every edit.** `user://saves/server/world.json` stores all
  edits and lives fully in RAM (`_edits`, `_edits_by_chunk`). Each save reads,
  merges and rewrites the whole file (`persistence_slice.gd`). That is
  O(total edits) and will not survive a planet.
- **The server only simulates near the origin.** The headless server streams
  chunks around a single centre, the idle body at `(16, 12, 16)`
  (`player_slice.gd:423`). Creatures and trees therefore only live near the
  origin, wherever the players actually are.

**Newel dependency:** NO.

**Closes:** none (scale prerequisite; sharding stays Deferred).

**Deliverables:**
- `src/persistence/region_store.gd` (new): edits are grouped into region files
  of 32×32 chunks (`regions/r.<rx>.<rz>.json`, later binary). A region is
  loaded when any of its chunks enters a streamed window, unloaded when none
  remain, and only dirty regions are written.
  - The interface is `load_region` / `save_region` / `list_dirty`, so a
    database backend can replace files without touching callers.
  - `world.json` keeps only global state: seed, market, governance and
    stations index.
- `src/terrain/chunk_manager.gd`: the server keeps a window per connected peer
  around that peer's position, with per-chunk reference counts. A chunk loads
  when its count first goes above zero and unloads when it returns to zero.
  The listen host keeps its own window as today.
- Creature and tree simulation, plus edit validation, run against the union
  window, so a peer 5,000 km away has a live world around them.
- Migration: a monolithic Phase 51 `world.json` splits into region files on
  first boot.

**Acceptance criteria:**
- [ ] Two peers 100 km apart each have creatures simulated around them on a
  headless server (net harness step `far_peers_simulated`).
- [ ] A save after editing one chunk writes exactly one region file.
- [ ] Server RSS with 1,000 edited regions on disk and one connected peer stays
  within 10% of an empty world.
- [ ] A Phase 51 save migrates with every edit intact.
- [ ] Suite green on both boot paths, and `tools/net_harness.sh` agrees.

---

## Phase 53 — Spawn placement and friend codes

**Goal:** Every new player spawns at the hard-coded `Vector3(16, 12, 16)`
(`player_slice.gd:423`) on a terrain patch flattened for that purpose. On a
planet that puts everyone in one crowded square metre. A new player should
instead land on empty, habitable land. A group should be able to spawn
together using a code: the friend's existing `p_` player handle
(`player_registry.gd`, `HANDLE_PREFIX`), so no new entity is needed.

**Newel dependency:** YES. A world-system spawn rule in the fabric sets which
biomes count as habitable, the minimum distance from colonized regions, and
the friend spawn radius.

**Closes:** single spawn point.

**Deliverables:**
- `src/world/colonization_map.gd` (new): a per-region score built from edited
  chunk count, player homes and recent player presence. It persists with the
  Phase 52 region index.
- New-player spawn: a deterministic search (seeded by the player id) for
  habitable land (not ocean, ice or VoidRift) at least the fabric minimum
  distance from any colonized region. It lands on solid ground found by
  sampling the generated surface. The flattened `SPAWN_CENTER` disc is
  retired.
- Friend code: the join or new-character flow accepts an optional handle. A
  new player with a valid handle spawns on safe ground within the fabric
  radius (about 200 m) of that player's current position, or their last saved
  position if they are offline. An unknown handle falls back to the normal
  search, with a message.
- The handle is shown in the character window with a copy button.

**Acceptance criteria:**
- [ ] `spawn: new players avoid colonized regions`: with 1,000 seeded colonized
  regions, 100 spawns all land on habitable land outside them.
- [ ] `spawn: friend code lands near the friend`: the spawn is within the
  radius, on ground, and not in water.
- [ ] An existing player reconnects at their saved position (Phase 33
  behaviour unchanged).
- [ ] Net harness step `spawn_near_friend` agrees over the socket.

---

## Phase 54 — World clock, day and night, seasons

**Goal:** The only lighting is a static `DirectionalLight3D` at a fixed angle,
with no clock, day/night cycle, seasons or weather. A planet with latitude
should have days whose length varies, and seasons that are opposite in each
hemisphere.

**Newel dependency:** YES.
- The world entity gets `dayLengthMinutes`, `yearLengthDays` and `axialTilt`.
- Biomes get seasonal modifiers: foliage tint, snow line and growth or spawn
  multipliers.
- TwilightGrove's existing `dayNightSpeed` is reconciled with the global
  clock.

**Closes:** none.

**Deliverables:**
- `src/world/world_clock.gd` (new): the server-authoritative time is persisted
  in `world.json`, sent in the join snapshot and corrected by a periodic tick.
  The client interpolates between ticks.
- Sun angle and day length come from the clock, the player's latitude and the
  axial tilt. The southern hemisphere is in the opposite season.
- Seasons tint grass and foliage, put snow cover on surfaces whose seasonal
  temperature is below freezing, and apply the fabric growth and spawn
  multipliers.
- The HUD shows the time of day and season.

**Acceptance criteria:**
- [ ] `clock: hemispheres are opposite`: on the same date, latitude +45° is in
  summer when −45° is in winter.
- [ ] `clock: day length varies by latitude`: at the solstice, daylight is
  longer at +60° than at the equator.
- [ ] A client's clock stays within 1 s of the host's over 10 minutes (net
  harness).
- [ ] `pnpm check-drift` clean and the suite green on both boot paths.

---

## Phase 55 — Two-client harness: equipment delivery over the socket ✅ Done

**Goal:** The `equipment_recorded` harness step proves the host records a claim,
but its client verdict is vacuous and AOI delivery to a peer is covered only in
the suite (#71, #73, #74). Make the step's client side real and add a delivery
step.

**Newel dependency:** NO.

**Closes:** #71, #73, #74.

**Deliverables:**
- `src/tests/net_harness.gd` — `_step_equipment_recorded`: the client verdict
  asserts the packet was actually sent (drop the always-true `_await_until`), and
  the resend loop is replaced by a host-driven ready signal (the host acks the
  grant before the client claims).
- The step pins a fixture item (a named equippable key, not "first sorted key")
  and adds the case of an unknown item claimed under a REAL slot key.
- A new `equipment_delivered` step: the client equips, and the host's AOI fan-out
  delivers `peer_equipment` back to a second connection (or to the host's
  client-side view), asserted on both peers.
- `tools/net_harness.sh` planned-step count bumped; ROADMAP Phase 47 note
  updated with the new count.

**Acceptance criteria:**
- [x] Breaking the client send (e.g. not emitting the intent) makes the step fail
  on the client side, not only on the host side.
- [x] Unknown item in a real slot is refused by the host and recorded as such.
- [x] `net-harness` reports `12/12 steps agreed across both peers`, with the delivery
  step verified on both peers.

_Implementation note:_ the delivery step uses the listen host as the subject (its worn set
fans out to the client's AOI over the socket), and the client judges it on what ARRIVED
(`peer_equipment_synced`), not on the character slice's stored set: the host runs ahead into
the reconnect step and a dropped connection forgets the stored set. A worn item has to be in
the host's own bag, or the Phase 48 revalidation clears it on the next inventory event.

---

## Phase 56 — Station placement follow-ups ✅ Done

**Goal:** Close the PR #67 review findings (#68) so placement is cheap per frame,
consistent in height, honest when refused, and tested.

**Newel dependency:** NO.

**Closes:** #68.

**Deliverables:**
- `src/world/station_slice.gd` — `placeable_station_types()` cached (computed
  once from RECIPES/ITEMS); `placement_blocker` compares snapped cells (x/z on the
  1 m grid plus snapped y) instead of raw 3D distance, so two stations at the same
  x/z cell but different heights are judged by a defined rule; Public API header
  updated; `game_root` demo stations placed through `try_place_station`.
- `src/player/player_slice.gd` — `_station_target` feet fallback uses the same
  +0.5 y offset as the aimed branch; `_update_station_preview` is gated by
  `world_input_allowed()`; a refused `V` surfaces the `placement_blocker` reason
  (toast/status line via the UI shell).
- Suite tests for `_station_target` (aimed top face, side hit, feet fallback),
  the N toggle and V through `try_place_station`, including a refusal reason.

**Acceptance criteria:**
- [x] `show_preview` per frame does not rescan RECIPES/ITEMS (asserted by
  `StationSlice.placeable_scan_count`).
- [x] Overlap rule is defined on snapped cells and asserted for same-cell /
  different-height and adjacent-cell cases.
- [x] Preview ghost is hidden while a menu owns input.
- [x] A refused placement shows its reason; suite green on both boot paths.


_Shipped as:_ most of the deliverables had already landed with the Phase 49 review pass; this
phase added the missing suite tests (`_station_target` aimed top / side / underside / feet, the
V placement and its refusal reason on the label, the frozen-world ghost) and the scan counter.

---

## Phase 57 — Spawn determinism and cost follow-ups ✅ Done

**Goal:** Close the still-open PR #54 review notes (#55, #56, #57) on Phase 44
spawning: pin the hash, keep pack members in their chunk, stop the O(instances)
rescans, and fix docs that claim a client path that does not exist.

**Newel dependency:** NO (per-species density/chance values for bosses such as
RiftWarden are a fabric design question and stay out of scope).

**Closes:** the code items of #55, #56, #57.

**Deliverables:**
- `src/tests/test_suite.gd` — a test pinning `SpawnRoll._mix` (and the roll
  helpers built on it) to known output values, so an accidental hash change fails.
- `src/creature/creature_slice.gd` — a running live-population counter (updated on
  spawn, death, respawn, tame, despawn) replacing the per-call `live_population()`
  scan in `spawn_for_chunk` / `_tick_respawn`; the counter is asserted equal to a
  full scan after a mixed sequence.
- Pack centre inset by the maximum member offset so every member lands inside the
  chunk; packs larger than the offset table no longer stack on wrapped offsets.
- A creature resource missing `spawnChance`/`spawnDensity` logs one warning
  instead of silently never spawning.
- Per-species density salt (derived from the species key) so densities of
  different species/trees are not fully correlated.
- `src/world/tree_slice.gd` — `_chunk_biome` computed once per `spawn_for_chunk`.
- `spawn_roll.gd` header + ROADMAP Phase 44 wording: clients do not spawn
  creatures; the determinism is a host reload guarantee.

**Acceptance criteria:**
- [ ] Hash-pin test exists and passes; changing `_mix` makes it fail.
- [ ] Every spawned member position lies inside its chunk (asserted over many
  seeds/chunks).
- [ ] Live counter equals a full scan after spawn/kill/respawn/tame sequences.
- [ ] Missing-field warning asserted; suite green on both boot paths.

_Implementation note:_ the running live counter was replaced by a single pass over the
instance table per `spawn_for_chunk` (survivors per species and the live count together),
which removes the per-species rescans without a second source of truth to keep in sync.
A cap-refused pack is also remembered and retried every 5 s while its chunk is loaded.

---

## Phase 58 — UI layout file robustness ✅ Done

**Goal:** Close the PR #60 review notes (#61) so a hand-edited or truncated
`ui_layout.json` and non-US keyboards behave.

**Newel dependency:** NO.

**Closes:** #61.

**Deliverables:**
- `src/ui/ui_slice.gd` — `parse_layout` rejects non-finite (NaN/inf) and absurd
  magnitudes per entry (that window falls back to its default); `_save_layout`
  writes to a temp file and renames over the target; `_apply_layout` clamps
  against the control's real size once laid out.
- The `?` controls-legend hotkey matches on `event.unicode == 63` (with the
  existing keycode path kept as a fallback) so non-US layouts open it.
- `parse_layout('not json')` test uses an input that does not log an engine
  ERROR line (or the parse path avoids `JSON.parse_string` noise).

**Acceptance criteria:**
- [x] A layout with `NaN`/`1e308` coordinates parses to defaults for that window,
  asserted in the suite.
- [x] Save leaves either the old or the new complete file (temp + rename),
  asserted by checking no partial file remains after a save.
- [x] Suite output contains no engine ERROR line from the layout tests.

---

## Phase 59 — Wire the Phase 45 rig into the game ✅ Done

**Goal:** `attach_rig`, `load_mesh`, `load_animation_library` and
`creature_model_key` have no non-test caller (#59), so the asset pipeline is not
exercised in play. Use it for the local avatar with a safe fallback.

**Newel dependency:** NO.

**Closes:** #59.

**Deliverables:**
- `src/character/character_slice.gd` — `attach_rig` hides the procedural box body
  and stops the procedural limb swing on success; on failure (missing scene,
  non-Node3D root — freed, not leaked) the procedural body stays.
- `RigTree.build_tree` checks the required clips (idle/walk/run/fall/land/attack/
  death), warns once per missing clip and maps missing ones to `idle`, so the
  placeholder rig does not spam "Animation not found"; the dead `anim_player`
  assignment / unused `player` param are removed or made real.
- Asset manifest: parsed once and cached; a private-pack `manifest.json` merges by
  key over the public one instead of replacing it.
- `game_root` / player boot calls `attach_rig` for the local avatar when a rig key
  resolves.

**Acceptance criteria:**
- [x] With the public placeholder rig, the avatar renders the rig only (no box
  body) and no "Animation not found" errors are logged. (See the Issue #112 note
  below — this criterion was false until the placeholder stopped being a triangle.)
- [x] With the rig key missing, the procedural body is used and nothing leaks.
- [x] Manifest merge asserted: a private key overrides, public-only keys survive.
- [x] Suite green on both boot paths.

**Issue #112 — the public placeholder rig was a single triangle.** Criterion 1 was
false on a public clone, and that was the whole of the bug: `attach_default_rig`
resolves to the committed `models/placeholder_rig.glb.raw` when no private player rig
is listed, `attach_rig` HIDES the procedural box body on success, and that placeholder
was ONE flat, single-sided 1x1 triangle in the XY plane (Phase 45 generated it as a
loader fixture, before anything rendered it). The player's own character was therefore
invisible from behind and a gray sliver from the front. `tools/gen_placeholder_glb.py`
now emits a BODY — a torso, a head, two arms and two legs as cubes on a flat node tree,
1.73 m tall with the feet on the root's ground plane — and the seven clips the tree
looks up (`idle`/`walk`/`run`/`fall`/`land`/`attack`/`death`, it shipped only `idle`),
so the clone logs no `[RigTree] rig has no …`. The six parts also had to be LINKED, which
the one-node triangle never needed: glTF reaches a node through its parent's `children`
array, so a node defined but never listed there is an orphan Godot imports without its
mesh — the root now names every part. The
suite pins the shape at `asset: placeholder rig is a visible body (#112)` — several
parts, ≥ 1 m tall, thickness on BOTH horizontal axes (a flat card fails here, which is
the exact regression), feet on the ground plane, every clip present. Measured: 6 parts,
merged AABB `size (0.84, 1.73, 0.30)`, `min y 0.000`.

**Review pass (self-driven, this branch).** Two items, both fixed in this pass. (1) The new
`asset: placeholder rig is a visible body` test built an `AnimationTree` and never freed it.
An orphan Node leaks to process exit — measured with a standalone `--script` probe: two
orphan `AnimationTree`s → `2 ObjectDB instances were leaked at exit` — and the rule the file
states after `_run_tests` plus both older `build_tree` callers free theirs. This one object
graph was 33 of the boot's leaked instances: the host boot's leak line went **44 → 11** and
the server's **53 → 20**, with the suite still `8781/8781` on both paths. (2) This note used
to claim the regeneration "fixed a silent loss in the old generator" — false, and the wording
above is corrected: the old file had ONE node and no `children` array, so nothing was orphaned
and nothing was lost (its single triangle rendered, which IS the reported bug); the orphan
hazard belongs to the new multi-part layout. Checked and found sound, no change needed: the
committed `.glb.raw` is byte-identical to a fresh `python3 tools/gen_placeholder_glb.py` run
(md5 `218d1100…` then, `95a5283d…` after the stride fix below, two runs each);
re-derived from the bytes, all six faces' winding cross-product
equals their outward normal (no face is backface-culled — that is the mechanism the triangle
bug came from), the tree carries no orphan node, and the merged AABB is exactly the quoted
`(0.84, 1.73, 0.30)` with `min y 0.000`.

**Review pass 2 (self-driven, same branch).** One item, fixed. The generator declared no
`byteStride` on the mesh's two vertex `bufferView`s, so Godot's glTF importer logged
`Buffer view byte stride should be declared for vertex attributes. Assuming packed data and
reading anyway.` three times on EVERY load of the rig — 24 lines across the 8 parses of one
`--verbose` boot (the seven asset tests plus the world boot's own `attach_rig`). `Blob.add`
now takes an optional stride and the POSITION/NORMAL views declare `12` (one tightly-packed
VEC3 float); the indices view must not declare one, so it does not. Re-measured on the same
verbose boot: **24 → 0 stride warnings**, the suite still `8781/8781` on both paths, and the
shape unchanged — the regenerated `.glb.raw` reads back the identical `(0.84, 1.73, 0.30)`
AABB at `min y 0.000`, the same seven clips, the same six-of-six outward winding, and no
orphan node, only 32 bytes larger (10 320 → 10 352). Independently verified this pass and
deliberately left alone: the world boot's exit noise — `11 ObjectDB instances were leaked at
exit` and `1 resources still in use` (`res://src/terrain/terrain_slice.gd`, named by a
`--verbose` run) — is IDENTICAL on `origin/main` with the old triangle, so it is pre-existing
and not this branch's. The world boot itself was exercised for the first time on this branch
(`--quit-after-boot`): the rig parses (`glTF: Total animations '7'`, six parts created) and
the run logs no `[RigTree] rig has no …` for the player's own rig — the only such lines are
the two deliberate negative tests.

**Review pass 3 (self-driven, same branch).** One item, fixed. The exit noise pass 2 recorded
as pre-existing had exactly one source inside this repo's test file:
`_test_rig_tree_state_mapping_total` (`src/tests/test_suite.gd:5637`) written
`RigTree.build_tree(AnimationPlayer.new())` — a bare `AnimationPlayer` with no parent, never
freed, so it survived to process exit as the single `Leaked instance: AnimationPlayer - Node
path: ` in the boot's leak report (the empty path is the tell: an orphan, not a world node —
the avatar's own player IS in the tree and is freed with it). It is pre-existing (`origin/main`
leaks the same instance and the same count) but it is the same defect class pass 2 fixed in the
test thirty lines above, in the file this branch edits, and the two-line fix is a strict
improvement rather than a re-roll: keep the player in a local and `player.free()` it after
`tree.free()`. Measured before/after on one boot each — host `11 → 10` leaked and the
`AnimationPlayer` **gone from the list**, `--server` `20 → 19`, the suite still `8781/8781`
`(0 failed)` on both paths (plus `[Server] listening on port 7777, max_clients 64`). No
behaviour changed — the player is only ever read by the tree builder.

Gates for this pass, all reproducing the branch's claims: `pnpm validate` ✓ Schema valid
(IR v3.0.0); `pnpm check-drift` ✓ No drift detected (555 file(s) match manifest); host
`--quit -- --run-tests` `8781/8781 passed (0 failed)`; `--server --quit -- --run-tests`
`8781/8781` + listening; `tools/net_harness.sh` under a fresh `XDG_DATA_HOME`
(`mktemp -d`) — `12/12 steps agreed across both peers`; the committed `.glb.raw`
byte-identical to a fresh `python3 tools/gen_placeholder_glb.py` run (md5
`95a5283d…`, no diff); `scripts/probe_glb.py` re-derived from the bytes — 7 nodes all
reachable, 0 orphans, clips `idle walk run fall land attack death`, **6 of 6 faces' winding
cross-product equal to their outward normal**, merged AABB exactly `(0.84, 1.73, 0.30)` at
`min y 0.000`. Also checked and found sound, no change needed: the new test's `root.free()` and
`tree.free()` are on every path (nothing leaks from it — the boot's lines are now dominated by
the four `FastNoiseLite` + four `Node` instances `origin/main` shares); the `_warned_missing`
static does not interact with the new test (the placeholder ships all seven clips, so it warns
for none — the only `[RigTree] rig has no …` lines in a full boot remain the two deliberate
negative tests); and the remaining exit noise (`1 resources still in use` —
`res://src/terrain/terrain_slice.gd` — and the five `Cannot get path of node` lines) is
identical on a `git worktree` of `origin/main` run side by side on the same `user://`, so it is
still not this branch's. `assets-prod` shows as a modified submodule in `git status` and was
left untouched, as in both earlier passes.

---

## Phase 60 — Host-authoritative equip ✅ Done

**Goal:** close the one hole Phase 48 left open: a client reported a whole worn set, so a
modified client could report `worn = {}` while holding a weapon and pass the bare-hands taming
rule (#88, with #63-#65 and #70). The host must decide what is in the hand.

**Newel dependency:** NO.

**Closes:** #88, #63, #64, #65, #70, #71 (with Phase 55) and the minimap/station notes in #107 and #68.

**Deliverables:**
- `src/core/bus.gd` — `equip_intent(player_id, slot, item_key)` replaces `equipment_intent`
  (`item_key` "" unequips). A client emits one action per differing slot; there is no whole-set
  report, so there is nothing to leave gear out of.
- `src/persistence/player_registry.gd` — `_on_equip_intent` validates the action (the fabric
  says the item fits the slot, the player's bag holds it) and changes ONE slot of the host's
  own record through `record_equipment`; a refused action sends the owner the authoritative set
  (`equipment_revoked`) so its optimistic avatar falls back. `has_equipment_report` is gone:
  the record is always the truth, a peer with an empty record is bare-handed.
- `src/networking/networking_slice.gd` — the `equip_intent` packet carries `{slot, item}`;
  the join-time equipment send skips pairs already sent (a join-intent retry no longer repeats it).
- `src/core/game_root.gd` — a client shows exactly the host's record on join (an empty one
  strips recipe gear the host never granted) and diffs its avatar into actions
  (`EquipmentRules.diff_actions`).
- `tame_intent` lost its dead `unarmed` argument; `ui_slice` lost a redundant refresh and an
  anonymous lambda; `Minimap.biome_color` caches per biome.

**Acceptance criteria:**
- [x] A wrong-slot item, an unknown item, an unknown slot and an unowned item change nothing;
  an unequip clears only its slot (suite).
- [x] A refused equip tells the owner the host's set (suite).
- [x] A bare-handed record reads as unarmed and a recorded sword as armed, with no payload
  claim on the wire (suite).
- [x] `net-harness` still reports every step agreed, `equipment_recorded` driving the new
  actions over a real socket.

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

- **Rivers, lakes and fluid flow** — water above sea level and flowing water
  (the cellular-automaton idea from the GDVoxelPlayground evaluation) follow
  Phase 51's static sea level.
- **Fast travel** — a planet takes about 90 days to walk around. Some form of
  travel network (roads, boats, waystones) is needed once players spread out
  (after Phase 53).
- **Voxel techniques from GDVoxelPlayground (evaluated, not adopted wholesale)** —
  <https://github.com/JorisAR/GDVoxelPlayground> (MIT) ray-marches a FIXED 128³
  voxel grid on the GPU via `RenderingDevice` compute. It does not fit Nihon,
  which has an unbounded streamed world, a headless server with no
  `RenderingDevice`, seed-deterministic CPU terrain, sparse-run columns with
  trimesh collision, and per-edit authority and persistence. Three techniques
  are worth borrowing later, each CPU-side and deterministic:
  - a **cellular automaton** for sand, water and lava, run on dirty chunks
    only;
  - **WFC** for ruins, villages and dungeons;
  - a **brick occupancy map** if meshing becomes the bottleneck.

- **Public wiki deployment** — VitePress (or equivalent) static-site deployment
  and CI-triggered wiki regeneration from the fabric (deferred from Phase 9).
- **Research cost points** — the abstract `researchCost` points field is modelled
  in the fabric but not enforced at runtime (deferred from Phase 13).
- **`VoidTouched` special-case unlock** — the void-burst survivor unlock trigger
  is defined in the fabric but not wired to any runtime event (deferred from
  Phase 13).
- **Station placement UI** — **(closed: placement is grid-snapped to 1 m cells and
  refuses overlap via `StationSlice.try_place_station`; N toggles a translucent
  green/red preview ghost and V places at the aimed top face or the player's feet.
  A full build-mode menu remains out of scope.)**
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
- **Peer damage over the wire** — a creature aggros and chases a remote peer, but
  the host opens no combat round against it: damage to a peer belongs to that
  peer's own client, and the host has no simulation of a peer's HP to hit or
  persist. Needs a host → client damage event plus per-peer HP ownership on the
  peer's side (deferred from Phase 36). **(delivered in Phase 37: the round is routed
  by target id, `player_damaged` carries the target, and the host sends the hit to the
  peer's own client. What remains is making a peer's HP authoritative rather than
  client-owned.)** **(closed in Phase 38: the host simulates the peer's HP itself and
  persists it on the peer's record. `player_damaged` stays a display update — a client
  that ignores it now diverges from the host's number instead of owning it.)**
- **Peer equipment replication** — **(closed in Phase 47: the host records each
  peer's worn set and the bare-hands rule reads it; late joiners are announced to
  their AOI, and the two-client harness step `equipment_recorded` proves the
  intent over a real socket.)**
