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
| 15 | Creature AI and behavior | Done |
| 16 | Station-gated crafting and tool durability | Done |
| 17 | Chunk streaming and world expansion | Done |
| 18 | Multiplayer world sync (core) | Done |
| 19 | Multiplayer chaos resilience (jitter + packet loss) | Done |
| 20 | Skeleton rig and animation | Done |
| 21 | Asset separation and public placeholders | Done |
| 22 | Material and palette pipeline | Done |
| 23 | LOD and composition simplification | Done |
| 24 | Social systems and player economy | Done |

See [ROADMAP.md](ROADMAP.md) for the full spec, deliverables, and acceptance criteria for each phase.

Production art lives in a private `assets-prod/` git submodule (Git LFS); the
public repo ships placeholders. See [assets/README.md](assets/README.md).

---

## Development life-cycle

Project Nihon follows a **fabric-first** discipline: every gameplay system is defined in the Newel fabric before it is implemented in GDScript. The flow is:

```
fabric/ (design)  →  pnpm generate  →  godot/  (Godot resources)
                                    →  bible/  (design bible)
                                    →  wiki/   (player wiki)
```

### Phases and slices

Each roadmap phase ships as one or more **slices** — self-contained GDScript autoloads that communicate exclusively through `GameBus` typed signals. A slice owns its data and exposes pure-function projections for the test suite and the UI layer. No slice calls another slice's methods directly.

### Adding a new system

1. **Model it in the fabric** — add entities, fields, state machines, and behaviors in `fabric/`. Run `pnpm validate` before touching any GDScript.
2. **Generate** — run `pnpm generate` to emit updated `.tres` resources into `godot/` and regenerate `bible/` and `wiki/`.
3. **Check drift** — run `pnpm check-drift` to confirm the IR snapshot is up-to-date before importing in Godot.
4. **Implement the slice** — add `src/<system>/<system>_slice.gd`; wire it in `src/core/game_root.gd`; add bus signals in `src/core/bus.gd`.
5. **Write tests** — extend `src/tests/test_suite.gd` with at least one test per acceptance criterion before marking the phase done.
6. **Open a PR** — phases ship as pull requests; titles follow `feat(<system>): <short description>`. PRs for design changes to the fabric are separate from implementation PRs.

### Branching strategy

| Branch prefix | Purpose |
|---|---|
| `feat/<system>` | New phase implementation |
| `fix/<area>` | Bug fix in an existing slice |
| `docs/<topic>` | Roadmap, wiki, or bible updates |
| `fabric/<topic>` | Fabric-only changes (no GDScript) |

`main` is the stable branch. All work goes through pull requests; direct pushes to `main` are not permitted except for generated artifact updates (`bible/`, `wiki/`, `godot/`).

### Design decisions

Major design decisions follow the community governance process described in the `CommunityOwnsTheFuture` constitution principle. Proposals are tracked as fabric entities in `fabric/constitution/decisions.js` with a state machine (`proposed → accepted → superseded`). Significant decisions must be ratified by contributor consensus before implementation begins.

---

## Contributing

Major design decisions follow the community governance process described in the `CommunityOwnsTheFuture` principle — propose publicly, ratify by contributor consensus. See the constitution fabric for the full set of principles and current decisions.
