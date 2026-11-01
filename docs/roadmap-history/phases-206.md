# Roadmap history — Phase 206

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 206 — The circle around every building: no spawns, no foreign building ✅ Done

**Goal:** creatures never spawn near a building, and only a clan's own members build inside its
circles. A bigger building has a bigger circle, and destroying it lifts both effects.

**Newel dependency:** NO.

**Depends on:** Phase 205.

**Deliverables:**
- A spatial lookup over the structure index's circles, so a dense town does not slow spawning or
  placement checks.
- The creature spawner skips points inside any circle. Creatures that walk in are not removed.
- The host refuses a new structure, clan or private, by anyone who is not a member of the clan
  whose circle it falls in. A circle shrinks as its structure loses blocks and goes when it is
  destroyed.

**Acceptance criteria:**
- [x] Suite: over a simulated day, no creature spawns inside any circle, and spawns continue
  outside.
- [x] Suite: an outsider's structure inside a clan building's circle is refused, and the same
  placement succeeds once that building is destroyed. A member's private house there is allowed.
- [x] Suite: a larger structure has a larger circle, between the fabric's minimum and maximum.
- [x] Playtest: walk/craft/fight stay within budget with a village of structures near spawn.
- [x] Suite green on both boot paths, harness green.

**As built:**
- `StructureSlice` caches each structure's circle and buckets it on the ground (64 m squares). A placed or
  removed block marks its structure, and the next lookup recomputes only marked structures, from running
  sums (column offsets from the anchor, blocks per level) rather than its cells, so building a large
  structure block by block does not grow quadratically. A point query
  reads one bucket, or two near the world seam. A structure that spans the seam is now centred at the seam,
  where before the average put its center on the far side of the world.
- Inside a clan's circle, an outsider's block is refused (`foreign_circle`). This covers a new structure and a
  block added to one the outsider already has there, so nobody can extend into the circle from outside it.
  Stations are refused the same way (`build_blocker`), and so is a settlement project started there (its
  blocks and stations are also skipped at completion if a circle has come over them since). A clan with no
  members left keeps no one out. A refused block tells its builder why (`structure.refused.foreign_circle`),
  a bed says so (`bed.refuse_circle`), and the host sends each client the foreign circles within 64 m when
  they change, so a client's station ghost turns red where the host would refuse.
- The spawner skips any pack member whose spot is inside a circle, so the pack there is smaller. A dead
  creature whose spawn point a circle now covers stays dead, keeping its deadline, until the structure is gone.
  A creature that walks into a circle is left alone. Kept-out members are retried on the deferred-pack timer,
  so a building taken down brings the pack back without a chunk reload. A tamed companion is not held.
- The Phase 205 wear sweep read every block of every worn structure once a second, which cost 28 ms per sweep
  for the playtest village (24 houses, 11.6k blocks). A structure now records its worst damage fraction
  (`hurt`), and the sweep reads its blocks only once its wear could bring one to zero. That sweep now costs 0.1 ms.
- The playtest bot seeds a village before its steps: 24 private houses of other players, on a ring 40 to 120 m
  from the spawn, recorded in the structure index only, 4 km above the ground so no step meets one.
