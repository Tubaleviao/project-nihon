# Roadmap history — Phase 156

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 156 — Idle, attack and hit clips for everyone, on every swing

**Goal:** an avatar standing still looks frozen, and an attack shows no motion. The `idle` clip moves
the chest and arms by 2–5°, which is invisible at game distance. The `attack` clip exists, but
`CombatWiring` triggers it only for the local player and only when a combat round is *requested*,
so remote players and creatures never swing, and repeated hits in one round do not swing again. This
phase gives every body a visible idle, a swing on every hit and a flinch when hit.

**Newel dependency:** NO.

**Depends on:** Phase 155.

**Deliverables:**
- Idle: the placeholder `idle` clip becomes a visible breathing and weight-shift loop (chest ±6°,
  hips sway, head turn, about 3 s), plus one or two idle variants (`idle_look`, `idle_stretch`) that
  play once after the body has been idle for 6–12 s (a seeded random from the instance id, so tests
  are deterministic). Creature skeletons get the same treatment: quadruped head bob and tail sway,
  bird preen, serpent coil.
- Attack on every swing: the host's per-hit combat event (today `GameBus.combat_round_resolved`
  carries one result per round, so a per-hit signal such as `combat_hit_resolved` is added to
  `src/core/bus.gd` in this phase) drives the attacker's attack animation for **any** attacker id — the local
  player, a remote peer's avatar and a creature model. Remote clients get it from the existing
  synced combat result, so no new wire message is needed if the result already carries the attacker;
  otherwise one compact field is added and validated on the host.
- Attack variants by what is held: `attack_unarmed` (punch), `attack_1h` (overhead/side swing,
  alternating), `attack_tool` (the same swing used for mining and gathering, so `mine` and `gather`
  also animate). The variant is picked from the main-hand equipment category; a missing clip falls
  back to `attack` (the existing warn-once rule).
- Hit reaction: `hit` (a short flinch, 0.25 s, additive over locomotion through a OneShot node) on
  `player_damaged` and on creature damage. Knockback and stagger (Phase 129) play a longer `stagger`
  clip.
- Placeholder clips for all of the above in `tools/gen_placeholder_glb.py` (player and every
  creature skeleton), listed in `assets/manifest.json`. The private repo gets matching keys (Placeholder
  rule, separate PR in `project-nihon-assets`).

**Acceptance criteria:**
- [x] Suite: a creature's hit on the player plays `attack*` on that creature's model and `hit` on
  the player rig (read from the tree's playback / OneShot state after the bus event, no frames).
- [x] Suite: a remote peer's attack, delivered as the synced combat result, plays an attack clip on
  that peer's avatar on another client (harness step `peer_attack_animated`).
- [x] Suite: three hits in one round trigger three attack one-shots (fails today: one).
- [x] Suite: the attack variant follows the main hand: empty → `attack_unarmed`, a sword →
  `attack_1h`, a pick → `attack_tool`; mining a block also triggers `attack_tool`.
- [x] Suite: the idle variant plays after the seeded delay and never while moving.
- [x] Suite: every rig in the manifest has `idle`, `hit` and at least one attack clip, and every
  placeholder clip's peak joint rotation is at least 10° (so a clip cannot be "present but
  invisible").
- [x] Suite green on both boot paths, harness green.

---

**Shipped notes:**
- The hit flinch is a OneShot inside the `Locomotion` blend tree (additive), so it shows over idle, walk,
  run and a creature's moving states; during the `Attack` state itself the swing clip owns the pose.
- The idle variant is a second OneShot (replace mode), aborted as soon as the body leaves idle.
- A player's flinch is driven by `player_damaged` (so burns flinch too); `combat_hit_resolved` flinches
  creatures and remote avatars. The client gets the swing as a compact `combat_hit` packet (wire keys
  `p:<peer>` / `c:<id>`, outcome only), AOI-scoped; the hit packet carries no damage or health.
- Mining plays `attack_tool` for the local player; a remote player's mining swing is not synced (no
  packet for it), and stagger clips for creatures are not shipped (only `hit`).
- The private repo's `build_player_rig.py` needs the matching clip keys (separate PR in
  `project-nihon-assets`).
