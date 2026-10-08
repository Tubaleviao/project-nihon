# Roadmap history — Phases 1–19

Completed phases, archived unchanged from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 1 — Constitution fabric ✅ Done

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

## Phase 2 — Materials and world primitives ✅ Done

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

## Phase 3 — Skills and professions ✅ Done

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

## Phase 4 — Items, recipes, and technology tree ✅ Done

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

## Phase 5 — Creatures and combat systems ✅ Done

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

## Phase 6 — `generator-bible` integration ✅ Done

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

## Phase 7 — Character system specification ✅ Done

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
- The asset pipeline checklist is complete (sign-offs recorded in `characters.md` §41.1; the
  art/engineering agreement itself is a human judgement and is not an automated criterion)

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
