# Roadmap history — Phase 192

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 192 — Creature bodies: creatures collide with each other and the player, and squash on contact ✅ Done

**Goal:** creatures are records, not physics bodies, so two of them could stand in the same spot and
a creature could walk through the player. Give each creature a footprint that other creatures and
players keep out of, and make its model squash a little when it bumps into something.

**Newel dependency:** NO.

**Depends on:** Phase 136 (ground movement), Phase 143 (creature models).

**Deliverables:**
- Fabric: every creature declares `bodyRadiusMetres` (0.2–2.0) and `squash` (0–0.5) through
  `bodyFields()`; `validateBodyFields` fails `npm run validate` on a missing or out-of-range value, and
  `tools/check_bodies.js` (CI) proves it.
- Host: once per AI tick, live creatures near a player push overlapping footprints apart, and a creature
  standing in a player is moved out of them. A chaser stops when its body meets the player's.
- Clients: a modelled creature squashes along its strongest contact (another model or the local
  player), driven by a spring, so a bump presses in, rebounds into a small stretch and settles.

**Acceptance criteria:**
- [x] `npm run validate` and `check-drift` pass; `node tools/check_bodies.js` rejects a missing field,
  a footprint out of range and a squash out of range.
- [x] Suite: two or more creatures on one spot fan out until they only touch.
- [x] Suite: a creature in a player is moved out of them, the player is not moved, and a chaser ends
  against the player, not inside them.
- [x] Suite: a push never carries a ground creature up a ledge taller than it can step.
- [x] Suite: the squash basis keeps volume and presses along the contact; the spring reaches its
  target, overshoots when released and settles.
- [x] Suite green; listen-host boot builds its first ring.

**Implementation notes:**
- `src/creature/creature_body.gd`: pure functions shared by the AI and the models (`pair_push`,
  `push_out`, `contact`, `spring_step`, `squash_basis`). A pair resolves half its overlap per tick
  (`RELAX`), and one body moves at most `MAX_SHOVE` (0.25 m) per tick, so a crowd relaxes over a few
  frames instead of jittering. Coincident bodies split along a direction seeded by their ids.
- `CreatureAI.separate_bodies` runs after every creature has stepped, over creatures within
  `BODY_ACTIVE_RANGE` (96 m) of a player, using the slice's spatial hash for neighbours. Bodies more
  than 1.8 m apart vertically (a flyer over a walker) do not touch. A player is never pushed: creatures
  have no collider, and the host does not move a player's body.
- Squash is visual only and runs on every machine from the synced positions, so nothing new goes on the
  wire. Pool boxes (creatures out of model range) do not squash.
