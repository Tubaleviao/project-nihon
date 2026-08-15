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
covers visual customization, asset architecture, persistence, and multiplayer
state — ready to guide engine implementation and art production.

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
  - Animation system placeholder (to be expanded in a dedicated spec)
  - Data-driven content model
  - Asset compatibility and semantic tag system
  - Asset production pipeline checklist
  - Optimization decision order

**Open items to resolve before engine implementation:**
- Final palette size (recommended starting point: 256 entries)
- Animation system specification (state machines, blend trees, locomotion)
- Hitbox category definitions

**Acceptance criteria:**
- Every section has enough detail to guide an implementation decision
- Palette size is explicitly decided and documented
- The asset pipeline checklist is complete and agreed upon by art and engineering
- The animation system placeholder is acknowledged and a follow-up spec is
  scheduled

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
  deterministically per tile.
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

## Phase 13 — Technology unlock gates

**Goal:** Gate recipes behind the technology tree so progression
(`KnowledgeIsProgression`) is real, not text.

**Deliverables (proposed):**
- A technology/research slice holding per-player `TECHNOLOGIES` status
  (`locked → researching → unlocked`).
- Crafting checks the recipe's owning technology is unlocked (in addition to
  skill guards).
- Research consumes resources (materials from Phase 12) and takes time.

---

## Deferred (in priority order)

- **Creature AI / behavior** — implement the fabric state machines
  (`idle/alert/aggressive/fleeing/respawning`) so creatures move, aggro, attack
  back, and flee. Combat currently "works" but creatures are static.
- **Multiplayer world sync** — the ENet plumbing exists (host/join + state
  broadcast); full authoritative world sync is a large, high-risk lift. Defer
  until the single-player gather→craft→build loop is solid.
- **Chunk streaming / larger world** — single 32×32 chunk is enough until there
  is a reason to explore (resource distribution in Phase 12).
