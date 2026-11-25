## Phase 282 — A felled tree falls, then goes

Owner's playtest, 2026-11-19: a felled tree squashes into a dark stump in place (scale 0.7/0.18/0.7,
`tree_slice.gd` `_stump_transform`) and stays until it regrows. It should topple, and then disappear completely.

- On the felled event, clients play a fall: the tree rotates about its base, away from the feller, to the ground
  over about 2.5 s with an ease-in (a falling tree speeds up), a short bounce, then sinks and fades over 1.5 s
  and is removed. The fall is client-side presentation only; the host's state is "felled at time t".
- After the fall nothing of the tree remains (no stump), until it regrows on the existing timer. Regrowth shows a
  sapling growing to full size over its first stretch of time rather than popping in.
- A client that loads the chunk after the fall (or joins late) sees no tree and no fall; a client that loads it
  mid-fall sees the tree already gone (no half-fall replays).
- The falling tree is a single instance taken out of the MultiMesh into its own node for the fall, then freed;
  the MultiMesh slot is hidden. No collision during the fall (it never hits players).
- The fall direction is chosen by the host (away from the feller's position at the felling) and carried in the
  felled sync: `GameBus.tree_chopped(tree_id, wood, state, respawn_at)` carries no feller or position today, so it
  gains a `fall_yaw` (radians) that clients use as-is, never computing it from their local copy of the feller.
- No world-gen change (placement is untouched), so no `WORLDGEN_VERSION` bump.

**Acceptance criteria**
- Suite (driving the fall with explicit time steps): after the felled event the tree's node tilts toward the side
  away from the feller and reaches at least 85° by 2.5 s; by 4 s it is freed and its MultiMesh slot hidden; no
  stump instance exists; orphan audit clean.
- Suite: a chunk built with a tree already felled shows no tree; regrowth scales from sapling to full over the
  regrow window.
- Suite (host): the felled sync's `fall_yaw` points away from the feller's position.
- Net harness step: both clients see the tree removed after A fells it, and both received the same `fall_yaw`.
