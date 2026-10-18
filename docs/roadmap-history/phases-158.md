# Roadmap history — Phase 158

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 158 — Gestures in the fabric: sit, lie down, wave and friends

**Goal:** players cannot sit, lie down or make any gesture, so a group of players standing together
looks like mannequins. This phase models gestures in the fabric so the list, their rules and their
animation names have one source. It is the fabric half of Phase 159 (separate PR, per CLAUDE.md).

**Newel dependency:** NO (new entities with existing field types).

**Depends on:** none.

**Deliverables:**
- `fabric/gameplay/gestures.js` (new) — a `Gesture` entity per gesture: `Sit`, `SitGround`,
  `LieDown`, `Wave`, `Point`, `Bow`, `Cheer`, `Shrug`, `Clap`, `Kneel`. Fields: `clip` (rig clip
  name), `kind` (`pose`: held until cancelled, or `oneShot`), `cancelOnMove` and `cancelOnDamage`
  (bool), `requiresGround` (bool), `restRegen` (a multiplier for HP/stamina regeneration while held,
  1.0 for none; sitting and lying give a small bonus, which makes them useful as well as social),
  `chatCommand` (`/sit`, `/lie`, `/wave`, …), and a translation key for its name.
- `validate` rejects a gesture with an unknown `kind`, a duplicate `chatCommand`, or a
  `restRegen` below 1.0.
- Generated `godot/` resources carry the gestures. `npm run generate` and `check-drift` are clean.
- `locale/` catalogs: the gesture names in `en` and `pt_BR`.

**Acceptance criteria:**
- [x] `pnpm validate` passes, and fails on a fixture gesture with `kind: 'dance-party'` and on two
  gestures sharing `/sit`.
- [x] Suite: `GameData` lists every gesture with its clip and chat command.
- [x] Suite: every gesture name key exists in both the `en` and `pt_BR` catalogs.
- [x] `check-drift` clean.
