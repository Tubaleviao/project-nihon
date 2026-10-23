# Roadmap history — Phase 171

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 171 — Creatures in exact coordinates: no float32 metres far from the origin

**Goal:** creature records (`CreatureSlice._instances`, `_dead_state`, the wire and the save) hold
their position as a float32 world `Vector3`. At x ≈ 2e7 m (half a lap from the origin) a float32 has
about 2 m between values, so a creature's range checks, model placement (`CreatureVisuals`) and AI
steps are metres-coarse there, and a model can jitter. Players, waystones and hearths already use
exact `{chunk, local}` positions; creatures should too. Split out of review follow-ups #380 and #392.

**Newel dependency:** NO.

**Depends on:** Phase 154 (it splits the files this phase touches).

**Deliverables:**
- `CreatureSlice` keeps each instance's position as `{chunk, local}` (`WorldPos`), with the
  `Vector3` world metres derived only near the camera or the player (scene-relative, like
  `WorldPos.to_scene`). `creature_state_changed`, snapshots and the world record carry the exact form;
  a legacy float position still loads.
- `CreatureVisuals.reselect` and `_update_model` place models from camera-relative positions computed
  from the exact form, never from a float32 world `Vector3`.
- `CreatureAI` paths and `creatures_in_radius` / the spatial hash work in the local frame of the chunk
  window, so a step far from the origin is the same size as one near it.
- The fold log (`_fold_log`, Phase 145) folds exact positions.

**Acceptance criteria:**
- [x] Suite: a creature at x ≈ 2e7 m moved by 0.1 m keeps the 0.1 m in its record, on the wire and
  after save and load.
- [x] Suite: its model's scene position is within 1 cm of the record, seen from a camera beside it.
- [x] Suite: a legacy float-position creature record still loads.
- [x] Harness: a creature delta far from the origin lands within 1 cm on the client.
- [x] Suite green on both boot paths, harness green.

**Shipped:** `CreatureSlice` records carry `pos` (`{chunk, local}`); `position` is the Vector3 derived from it
(`_store_pos`) for near-origin readers. `set_instance_pos`, `move_instance` (a metre delta added to `local`) and
`get_instance_pos` are the exact accessors; `set_instance_position` / `apply_creature_state` stay as Vector3
wrappers. Spawns are placed from the chunk plus a small local offset, respawn returns to `spawn_exact`.
`creature_state_changed` now carries the exact position (the packet `pk` was already exact), snapshots and the
world record write `{chunk, local}`, and a legacy `[x, y, z]` entry is split on load. `CreatureAI` steps with
`move_instance`, and its path walk measures the tile centre against the exact position. `CreatureVisuals` places
models from `scene_of(inst)` (`frame_chunk` + `frame_shift`, moved by `shift_scene`; the node itself no longer
moves) and picks models by the exact camera-to-creature offset. Suite: far step, far model, legacy load;
harness step `creature_far_delta`.
Not done: the MultiMesh box pool and the AI's target (player) positions are still float world metres, and the
fold path (`fold_contents`, `_fold_log`) still folds through float world positions; none of these is a model or
a record.
