# Roadmap history — Phase 157

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 157 — Deaths that read as deaths: a push, a fall and a body that stays

**Goal:** when a creature or a player dies, it lies down calmly, as if going to sleep. A death should
look like the hit that caused it: the body is thrown back a little from the killer, falls, and
settles. The body should also stay in the world long enough to be harvested (Phase 161), instead of
vanishing after `CORPSE_SECONDS` (8 s).

**Newel dependency:** NO.

**Depends on:** Phase 155. Uses Phase 129's knockback helper. Reads `corpseSeconds` from Phase 160
when it has landed; until then the corpse lifetime stays the `CORPSE_SECONDS` constant.

**Deliverables:**
- Host-decided death push: when the host resolves a killing blow it computes a short throw
  (0.5–1.5 m, scaled by the killing hit's damage relative to max HP and by the attacker/target
  size ratio) away from the killer, landing on a walkable spot found by
  `StatusEffects.knockback_target`. The landing position is part of the death event
  (`creature_died` / `player_died` gain `landing: Vector3` — the host value, never the client's).
  The body's authoritative position becomes the landing spot.
  The signature change touches every existing listener, updated in this phase:
  `CreatureSlice._on_creature_died`, `CreatureAI._on_creature_died`, `LootSlice._on_creature_died`,
  `CombatWiring._on_player_died` / `_on_status_player_died`, the emitters in
  `BattleSlice` and `PlayerSlice._die`, and the suite tests that emit either signal.
- Client-side fall: the visual body travels from its position to `landing` over about 0.35 s on a
  short arc (no physics ragdoll, so the headless server stays deterministic), while the death clip
  plays. Two or more death variants per skeleton, picked by the hit direction relative to the
  body's facing: `death_back` (thrown backwards), `death_forward` (falls on its face), `death_side`.
  A missing variant falls back to `death`.
- The death clip ends in a pose that lies on the ground (the rig's lowest point at ground height
  within 5 cm), so a corpse does not float or sink.
- Corpse lifetime: creature corpses stay until harvested or until `corpseSeconds` (fabric value,
  Phase 160) elapses, instead of the hard-coded 8 s. Until Phase 161 lands, the old loot drop still
  happens on death, so nothing is lost in between.
- Player death uses the same push and variants. Respawn resets the rig as today.

**Acceptance criteria:**
- [x] Suite: a killing blow from the west puts the creature's landing spot east of where it stood, at
  a distance in [0.5, 1.5] m, on a walkable tile; a killing blow against a wall lands it short of the
  wall (never inside a solid voxel).
- [x] Suite: the landing spot is computed on the host only. A client-reported landing in a
  `creature_died`-shaped message is ignored (trust boundary).
- [x] Suite: a hit from behind the target picks `death_forward`, from the front `death_back`, from
  the side `death_side`.
- [x] Suite: after the death clip's last key, the lowest bone of every placeholder rig is within
  5 cm of the ground plane.
- [x] Harness: a creature killed on the host lands at the same `landing` position on the client.
- [x] Suite green on both boot paths, harness green.
