# Project Nihon

An open-source sandbox MMORPG where players build a civilization. The world is persistent, expands over time, and evolves entirely through player interaction — no scripted quests, no scripted economies, no pay-to-win.

The entire game design bible — materials, skills, creatures, items, world systems — is authored as a [Newel](https://github.com/Tubaleviao/newel) fabric and generated into documentation, runtime assets, and Godot resources.

---

## Quick start

```bash
pnpm install
pnpm validate   # validate the fabric against the schema
pnpm inspect    # list all entities by name
pnpm generate   # generate the design bible into bible/
```

---

## Roadmap

| Phase | Title | Status |
|-------|-------|--------|
| 1 | Constitution fabric | Done |
| 2 | Materials and world primitives | Done |
| 3 | Skills and professions | Done |
| 4 | Items, recipes, and technology tree | Done |
| 5 | Creatures and combat systems | Done |
| 6 | `generator-bible` integration | Done |
| 7 | Character system specification | Done |
| 8 | `generator-godot` integration | Done |
| 9 | Public wiki | Done |
| 10 | Vertical slices — playable game loop with creature combat | Done |
| 11 | Crafting slice — fabric-driven recipe resolution | Done |
| 12 | Voxel mining and building | Done |
| 13 | Technology unlock gates | Done |
| 14 | Player UI (inventory, technology tree, crafting) | Done |

Deferred (in priority order): creature AI/behavior, multiplayer world sync,
chunk streaming / larger world.

See [ROADMAP.md](ROADMAP.md) for the full spec, deliverables, and acceptance criteria for each phase.

---

## Contributing

Major design decisions follow the community governance process described in the `CommunityOwnsTheFuture` principle — propose publicly, ratify by contributor consensus. See the constitution fabric for the full set of principles and current decisions.
