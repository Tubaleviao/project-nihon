# Roadmap history — Phase 155

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 155 — Animation tempo: looping clips, stride-matched walk and snappier transitions

**Goal:** the game looks slow, and the walk is broken. Holding a move key makes the avatar stretch
its left leg toward the move direction and glide with it held there. The cause is in the clips, not
the input: the runtime glTF import leaves every clip at `Animation.LOOP_NONE` (only `death` is set
explicitly, in `CreatureVisuals`, and nothing sets the others), and `tools/gen_placeholder_glb.py`
keys `walk` and `run` so that both the first and last keys are "left leg forward". So one stride
plays, the clip stops on its last key, and the body slides with the left leg out. The same happens
to `idle`, `run` and `fall`, and to every creature model from Phase 143. This phase fixes the loop,
matches the stride to the ground speed and tightens the timings so movement reads as quick.

**Newel dependency:** NO.

**Depends on:** none.

**Deliverables:**
- One place sets clip loop modes for every rig, player and creature: `RigTree.prepare_library(player)`
  (new), called by `CharacterSlice.attach_rig` and `CreatureVisuals._template`. `idle`, `walk`,
  `run` and `fall` get `LOOP_LINEAR`; `land`, `attack`, `death` and any one-shot clip (Phases
  156–159) get `LOOP_NONE`. The loop table lives in `RigTree` next to `node_for_state`, so a new clip
  must be listed there.
- Stride-matched playback: the locomotion blend space plays at a time scale of
  `ground_speed / clip_stride_m`, where each clip's stride length (metres per cycle) is a constant
  in `RigTree` (and a per-creature value read from the creature model, defaulting by skeleton). Feet
  stop sliding, and a faster character visibly steps faster instead of gliding.
- `RigTree.drive` stops calling `travel()` on every tick when the node has not changed (the
  creature path already does this). Re-travelling to the same node restarts nothing today, but the
  call is per frame per avatar and hides real transition bugs.
- Transition cross-fades: each state machine transition gets an explicit `xfade_time` (locomotion
  0.12 s, into attack 0.05 s, into death 0.08 s, out of land 0.1 s), instead of the engine default
  of 0, which pops between poses.
- Tempo pass: `Locomotion.ATTACK_DURATION` matches the attack clip length (one source: the clip's
  length when a rig is attached, the constant otherwise), `LAND_DURATION` drops to 0.18 s, and the
  creature speed smoothing (`lerpf(..., delta * 8.0)`) is raised so a creature stops and starts
  without a visible lag. The procedural box-body walk (`ANIM_FREQ`) uses the same stride constant
  as the rig, so both paths step at the same rate.
- `tools/gen_placeholder_glb.py`: the `walk`/`run` clips (player and every creature gait) are keyed
  as one closed cycle (the last key equals the first, and the clip length equals that key time), so
  a looped clip has no hitch at the seam. The private repo's `build_player_rig.py` gets the same
  rule (separate PR in `project-nihon-assets`).

**Acceptance criteria:**
- [x] Suite: after `attach_rig`, the player rig's `idle`, `walk`, `run` and `fall` clips are
  `LOOP_LINEAR` and `land`, `attack` and `death` are `LOOP_NONE`. Same for every creature model in
  `assets/manifest.json`.
- [x] Suite: a test that advances an `AnimationPlayer` on the `walk` clip by 3 clip lengths (by
  `advance()`, no frames) reads `Leg_L`'s pose at three different phases and gets three different
  rotations (fails today: the clip holds its last key).
- [x] Suite: every placeholder loop clip's last key equals its first, for every joint
  (`gen_placeholder_glb.py --check` in CI).
- [x] Suite: at walk speed and at run speed, the blend space time scale times the clip stride equals
  the ground speed within 5%.
- [x] Suite: `RigTree.drive` called twice with the same state issues one `travel()` (counted with a
  fake playback object).
- [x] Suite: every transition in `build_tree` has a non-zero `xfade_time`.
- [x] Playtest bot: the `walk` step records the left and right foot heights over 2 s of held
  movement and asserts each foot spends between 30% and 70% of the time in front of the other
  (fails today: the left foot is in front almost the whole time).
- [x] Suite green on both boot paths.
