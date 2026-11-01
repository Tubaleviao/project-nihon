# Roadmap history — Phase 205

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 205 — Owned structures instead of claims: private or clan, durability, dismantling and destruction ✅ Done

**Goal:** the host knows who owns each structure and enforces it everywhere. A structure wears with
weather and time, comes apart with effort, and gives back what its condition and its dismantler's
skill allow. The hearth claim is gone.

**Newel dependency:** NO.

**Depends on:** Phase 204.

**Deliverables:**
- A host-side structure index: block to structure, structure to owner (player or clan), kept as
  blocks are placed, joined or destroyed, saved with the world, bounded in memory. The builder
  picks private or clan when placing.
- `edit_blocker` on the voxel, station and tree guards checks the structure under the edit, not a
  claim. A non-owner's damage lowers durability, and a block at zero is destroyed.
- Durability per block: base from its material, lowered by weather, age and damage. Age and weather
  loss is computed from timestamps when a block is read or ticked, not by touching every block
  every frame, and days with the server down count once on boot.
- Dismantling by the owner (or, for a member's private house in clan territory, any clan member)
  returns the Phase 203 share to the dismantler. Forced destruction returns nothing and is slowed
  by the method's offline factor while every owner is offline. Repair spends the Phase 203 share of
  build materials. The owner (and online clan members) are told when a structure is damaged or
  destroyed.
- A player command and a menu button to kill your own character and respawn, rate-limited.
- Phase 204 holds to finish here: a migrated settlement keeps its hearth and its settlement record (the
  clan's `settlement` field names it) until this phase removes the hearth and returns it to its founder
  as a `Hearth` item (`Clan.migration.hearth`). Settlement membership (invite, join, roles) still runs
  beside clans until the settlement code goes, and the Settlement window (L) with it.
- The claim, hearth, raid and upkeep code is removed: `claim_radius`, `claim_at`, tier radii,
- Phase 203 holds to remove with it: the claim radii, `decayRadiusPerDay` and `minSeparation` now
  come only from `SettlementSlice.DEFAULT_RULES` (the fabric has none), and project effects only
  from `ProjectRules.LABOUR_HOLD`.
  `at_research_site`, claim decay and project effects.

**Acceptance criteria:**
- [x] Suite: a private structure's owner can edit it far from any hearth, and a clan member cannot.
  A clan structure can be edited by any member and by no outsider.
- [x] Suite: an outsider's damage destroys a block once its durability is gone, and a rarer
  material takes more damage.
- [x] Suite: dismantling at full durability returns 50% with no building skill and 100% with a very
  high one, and less after a simulated year of rain.
- [x] Suite: ownership is unchanged by anything but dismantling or destruction.
- [x] Suite: a clan member can enter and dismantle another member's private house inside the
  clan's territory, but cannot edit it. Outside the territory they can do neither.
- [x] Suite: a destroyer receives no materials. Destroying a structure whose owners are all offline
  takes the method's offline factor longer than with an owner online.
- [x] Suite: a repair restores durability and consumes its share of build materials, and a
  non-owner's repair is refused.
- [x] Harness: a client walled in by the host's structure kills its character and respawns outside.
- [x] Harness: a client's damage to the host's structure reaches both peers, and its placement on it
  is refused.
- [x] Suite (audit): no owner, clan, durability or skill value is read from a client message.
- [x] Suite green on both boot paths, harness green.

**Implementation notes:**
- `src/structure/structure_slice.gd` (host) is the structure index: a block is a cell of one tile by one step,
  keyed by its canonical tile and its bottom in millimetres, mapped to a structure `{ kind, owner, builder,
  cells, wear }`. `structure_rules.gd` reads `Structure`, `StructureDurability` and `SelfRespawn`;
  `structure_wiring.gd` hands the index to the voxel slice (`VoxelSlice.structures`), the station and tree
  guards (`structure_guard`, `StructureSlice.edit_blocker`), and feeds it the clock's hour and the weather.
  Bounded at 20,000 structures and 250,000 blocks; past them a placement is refused, never left unowned.
- Every mine and place asks `plan_mine` / `plan_place` before anything is spent and records the result after
  the edit. A placement made against a block the actor may not edit is refused. Otherwise the block joins a
  touching structure whose owner matches the builder's mode (`/buildas private|clan`, or the Character
  window's buttons), or it starts a new one. Where owners differ, each keeps their own blocks. The owner's
  mine dismantles; anyone else's mine is a hit by the held tool's method (pick, axe or bare hands). A hit
  that leaves the block standing is broadcast as `block_damaged` to the peers in range.
- Dismantling credits the dismantler `dismantle_share(durability fraction, Building level)` of the block's
  material, and carries the fractional remainder per structure and material. Ten blocks at full durability
  return 5 with no skill and 10 at level 10.
- Wear is per structure, a fraction of base durability, and is advanced from the in-game hour when the
  structure is read or swept: `loss.perDay` plus `loss.weather` for the weather rolled at its anchor. A long
  gap is integrated from 24 sampled hours. Each block keeps the wear its structure had when it was placed.
  Server downtime (real seconds since the record's `timestamp`, at the clock's day length) is worn once on
  load. The sweep removes blocks worn to nothing, at most 32 a second, and tells the owners.
- At the fabric's rates a block loses 73% of its base to age in 365 in-game days (`perDay` 0.002). A year of
  steady rain (`rain` 0.0005 an hour) wears it away entirely, so the suite checks that a month of rain
  returns less than full and a year less still. An in-game day is 24 real minutes, so an untouched building
  wears away in about 500 in-game days (about 8 real days). This is a tuning question for the fabric, and it
  is filed as a follow-up.
- A member's private structure is "in the clan's territory" when its centre lies inside the circle
  (`Structure.circle`) of a structure that clan owns. A circle has a 0.5 m² footprint per column and a height
  from its lowest to its highest block. `may_enter` exists for Phase 208's doors. A clan structure is
  dismantled by members whose role may `dismantleClanStructures` (every role but guest).
- `/respawn` (and the Character window's Respawn button, which sends it) kills the speaker's own character
  with the attacker id `self`, at most once per `SelfRespawn.cooldownSeconds`. `/repair` repairs the
  structure the speaker owns within 3 m. It costs `repair.share` × the durability restored per material,
  rounded up, paid from their pack.
- The claim is gone. Settlements keep members, roles, the stockpile, research and projects, used within a
  fixed `SettlementSlice.SITE_REACH` (24 m) of the site, until Phases 207–209 move them to clans. No
  settlement decays, is abandoned or is founded by a player (no `found` intent; `found` stays host-side). A
  saved hearth station is removed on load, and its founder is owed a `Hearth` item, handed over once they are
  online (`hearth_returns`, saved). The Hearth stays a placeable station that founds nothing. Project effects
  and `ProjectRules.EFFECT_KINDS` are removed. Settlement projects' finished blocks
  (`place_structure_block`) are not indexed; Phase 207 decides their owner with clan projects.
- World format 4 (`PersistenceSlice.WORLD_FORMAT_VERSION`) carries `structures`. A block placed before it is
  unowned and free to anyone, as before.
- Harness: `structure_damage` (the host's Ferrite block takes the client's hit, `block_damaged` reaches both
  peers, and the client's Ashite placement on it is refused with its pack unchanged) and `self_respawn` (the
  client steps 24 m away, the host walls it in with a ring of Ashite columns, the client sends `/respawn` and
  ends up outside the ring).
