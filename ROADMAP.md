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
- `quoin.config.ts` wired up with `BibleGenerator`
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

## Phase 8 — `generator-godot` integration

**Goal:** Generate Godot 4.x-ready resource files from the same fabric.

**Newel dependency:** Newel Phase 14 (`generator-godot`) must be released.

**Deliverables:**
- `quoin.config.ts` updated with `GodotGenerator`
- `godot/` output folder with `.tres` files per item, material, creature
- `godot/autoload/GameData.gd` singleton
- State machine states available as GDScript enums

**Acceptance criteria:**
- Generated files load in a Godot 4.x project without errors
- `GameData.ITEMS`, `GameData.CREATURES`, etc. are accessible at runtime
- Any IR change triggers drift detection (`pnpm check-drift`) before Godot
  import

---

## Phase 9 — Public wiki

**Goal:** Publish a player-facing wiki generated from the same fabric.

**Newel dependency:** Newel Phase 13 (`generator-wiki`) must be released.

**Deliverables:**
- `quoin.config.ts` updated with `WikiGenerator`
- Wiki deployed as a static site (VitePress or equivalent)
- Internal design notes (rules, guards written as implementation details)
  suppressed via patches

**Acceptance criteria:**
- Wiki is publicly accessible
- No internal field names or implementation-detail rules are visible to players
- Wiki updates automatically on every fabric change via CI
