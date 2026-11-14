## Phase 261 — The newcomer grounds: a large, gentle spawn area with loose stones and branches

A new character spawns wherever the spawn search seeded by the player id lands, among whatever lives
there. Newcomers get their own ground instead.

- **Fabric (separate PR):** a `NewcomerGrounds` entry in `WorldSystem`: how many grounds there are on
  the open continent (a few, so players meet but do not crowd), their radius (about 1 km), the
  biomes they may sit in (temperate forest and grassland edges: trees, open ground and rock in
  reach), the creatures allowed inside (passive or weak ones only, by a fabric level or danger
  cap), and the density of loose items.
- **Placement:** the grounds' centres are a pure function of the world seed (Phase 238), chosen on
  habitable land with trees and surface rock within each ground. The spawn search places a new
  character at a point inside one ground (picked by the player id, as now), never in water or on a
  steep slope.
- **Creatures:** spawning inside a ground draws only from its allowed list; an aggressive creature
  that wanders in turns back at the edge (a no-go zone for its AI, as structures' circles are since
  Phase 213). Enough weak creatures live there for the tutorial's first hunt.
- **Loose stones and branches:** small pickable props on the ground, denser inside the grounds and
  sparse elsewhere, placed as a pure function of (seed, tile) like trees (no world-gen change, so no
  `WORLDGEN_VERSION` bump). Picking one up is the interact input, instant, and grants the item.
  The host keeps which were taken and regrows them after a fabric delay, so the ground never runs
  dry for the next newcomer. They are drawn with the MultiMesh pool and synced like tree state.
- **Resources:** the guarantee is checked, not hoped for: every ground has, within a fabric radius of
  each spawn point, trees, surface rock, soil, loose items and the creatures the tutorial needs.
- Claims: no structure may be placed within a small radius of a ground's centre, so a newcomer's
  spawn is never walled in. Building elsewhere in the ground is allowed.

**Acceptance criteria**
- `npm run validate` and `check-drift` pass; a `check_*.js` rejects an aggressive creature in the
  allowed list and a radius below the tutorial's needs.
- Suite tests: the grounds' centres are identical for the same seed; a new character's spawn lies
  inside a ground on dry, walkable land; within the fabric radius of sampled spawn points there are
  trees, rock, soil, loose stones, branches and an allowed creature spawn.
- Suite tests: loose-item placement is identical for the same (seed, tile); a picked item is gone
  for every peer and regrows after the delay; a pick-up out of reach or of an item already taken is
  refused by the host.
- Suite test: no creature outside the allowed list spawns inside a ground, and placement within the
  protected radius is refused.
- Net harness step: a client picks up a loose stone and the second client sees it gone.
