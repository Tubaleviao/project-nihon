# Project Nihon

An open-source sandbox MMORPG where players build a civilization. The world is persistent, expands over time, and evolves entirely through player interaction — no scripted quests, no scripted economies, no pay-to-win.

The entire game design bible — materials, skills, creatures, items, world systems — is authored as a [Newel](https://github.com/Tubaleviao/newel) fabric and generated into documentation, runtime assets, and Godot resources.

---

## Quick start

```bash
pnpm install
pnpm validate   # validate the fabric against the schema
pnpm inspect    # list all entities by name
```

---

## Implemented phases

| Phase | Title | Status |
|-------|-------|--------|
| 1 | Constitution fabric | Done |
| 2 | Materials and world primitives | Done |
| 3 | Skills and professions | Done |
| 4 | Items, recipes, and technology tree | Done |
| 5 | Creatures and combat systems | Done |
| 6 | `generator-bible` integration | Planned |
| 7 | `generator-godot` integration | Planned |
| 8 | Public wiki | Planned |

See [ROADMAP.md](ROADMAP.md) for the full spec, deliverables, and acceptance criteria for each phase.

---

## Phase summaries

### Phase 1 — Constitution fabric
Encodes the game's foundational decisions as a fabric so every subsequent definition can reference them.

- `constitution/principles.js` — ten core design principles as named behaviors
- `constitution/decisions.js` — current architecture decisions with a state machine (`proposed → accepted → superseded`)
- `constitution/monetization.js` — monetization rules as a named system block

### Phase 2 — Materials and world primitives
Defines the fictional materials that underpin crafting and the physical simulation, plus the biomes and weather systems.

- `world/materials/` — metals (Ferrite, Veilsteel, Aethermite, Voidite), woods (Thornwood, Duskfiber), stones (Ashite, Lumenfite)
- `world/biomes/` — Temperate Forest, Temperate Grassland, Volcanic Badlands, Twilight Grove, Void Rift
- `world/weather.js` — weather system with rules and parameters

### Phase 3 — Skills and professions
Defines every player skill and how skills combine into professions.

- `gameplay/skills/` — 20 skills across five domains:
  - **Combat** — Swordsmanship, Archery, Shieldcraft, Unarmed
  - **Crafting** — Smithing, Carpentry, Alchemy, Arcane Forging, Void Smithing
  - **Magic** — Elemental Magic, Void Magic, Restoration Magic, Enchanting
  - **Exploration** — Cartography, Tracking, Stealth, Navigation
  - **Social** — Diplomacy, Trade, Speechcraft, Leadership
- `gameplay/professions/` — 8 professions: Blacksmith, Arcanist, Ranger, Warrior, Alchemist, Merchant, Pathfinder, Void Touched
- Each skill follows a five-tier state machine: `novice → apprentice → journeyman → expert → master`
- Professions declare required skills via relations and unlock when prerequisite tiers are met

### Phase 4 — Items, recipes, and technology tree
Models every craftable item, the recipes that produce them, and the technology progression that unlocks recipes.

- `gameplay/items/` — 16 items across six categories:
  - **Tools** — FerritePick, VeilsteelPick, CarpenterAxe
  - **Weapons** — FerriteShortSword, VeilsteelLongsword, AethermiteBow, VoiditeEdge
  - **Armor** — FerriteHelmet, VeilsteelChestplate, DuskfiberCloak
  - **Food** — FieldRations, AlchemyPotion
  - **Components** — FerriteIngot, VeilsteelIngot, ThornwoodPlank, AethermiteDust, AshiteBlock
  - **Magical** — EnchantedAethermiteShard, VoidRuneTablet, LumenfiteOrb
- `gameplay/recipes/` — 16 recipes across smithing, alchemy, arcane, and carpentry domains
- `gameplay/technology/` — 7 technology nodes: BasicSmithing, MasterForge, BasicCarpentry, TextileWeaving, ArcaneForging, Alchemy, VoidMastery
- Items follow a durability state machine: `pristine → worn → damaged → broken`
- Technology nodes follow a research state machine: `locked → researching → unlocked`

### Phase 5 — Creatures and combat systems
Defines the world's fauna and the combat rules governing all player–creature and player–player interactions.

- `world/creatures/` — 10 creatures across four biome families:
  - **Temperate** — ForestBoar, GraywolfPack, SteppeBison, RidgeHawk
  - **Volcanic** — LavaSlug, CinderGargoyle
  - **Twilight** — GlimmerFox, VeilStalker
  - **Void** — VoidSerpent, RiftWarden
- Each creature has a complete state machine: `idle → alert → aggressive → fleeing → dead → respawning`
- Creatures with taming interactions: GraywolfPack (wolf companion, Ranger flag), GlimmerFox (reagent harvest without killing)
- `gameplay/combat.js` — CombatSystem entity with rules for hit calculation, critical strikes, status effects, magic interactions, structure damage, and PvP
- All five biomes back-filled with real creature relations (placeholder strings removed)
- Combat system rules fulfil the `MagicBalancedWithMartial` and `DestructibleBuildings` constitution decisions

---

## Project structure

```
fabric.js                  # root fabric entry point
constitution/
  principles.js            # ten core design principles
  decisions.js             # architecture decisions with state machines
  monetization.js          # monetization rules
world/
  materials/               # fictional materials (metals, woods, stones)
  biomes/                  # biome definitions with spawn tables and creature relations
  weather.js               # weather system
  creatures/               # creature definitions by biome family
gameplay/
  skills/                  # skill definitions by domain
  professions/             # profession definitions
  items/                   # item definitions by category
  recipes/                 # recipe definitions by crafting domain
  technology/              # technology tree nodes
  combat.js                # combat system rules
```

---

## Contributing

Major design decisions follow the community governance process described in the `CommunityOwnsTheFuture` principle — propose publicly, ratify by contributor consensus. See the constitution fabric for the full set of principles and current decisions.
