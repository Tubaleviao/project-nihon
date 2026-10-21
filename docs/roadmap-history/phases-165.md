# Roadmap history — Phase 165

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 165 — Mountains on the horizon: distant bands out to the visibility limit

**Goal:** a mountain should be seen from far away, as on Earth: a 500 m peak clears the horizon of
a player standing on the plain from about 80 km. Phase 164's ring ends near the eye-height horizon
(a few km), and the large-scale shape already has 400 m ridges (Phase 51, `ridgeAmplitude`), so
anything tall beyond a few km is cut off today. This phase adds coarser bands outside the ring, out
to the distance where the tallest terrain can still clear the horizon, so ranges rise over the
curved ground from far away and stay put as the player walks. Taller and more varied mountains
come in their own world-gen phases; this one makes whatever the shape holds visible from afar.

**Newel dependency:** NO.

**Depends on:** Phase 164.

**Deliverables:**
- `src/terrain/distant_terrain.gd` (or a new `distant_bands.gd` beside it) — nested circular bands
  in the clipmap style: each band's cell is a multiple of the one inside it and it re-centres only
  when the player moves a whole cell of that band, so the far bands rebuild rarely. The outermost
  radius is `horizon_distance(eye_h) + horizon_distance(WorldShape.max_height())` (≈ 85 km at the
  default 512 m), from `horizon.gd`. Bands beyond the near ring sample `WorldShape` only (no detail
  noise) and keep peaks: a band vertex takes the highest shape height in its cell, so a ridge never
  vanishes between two samples.
- Recorded chunks keep winning where they exist (the ring's `ChunkRecords` snapshot is used for the
  near band; far bands read the plain shape, as `DistantTerrain` does today for unrecorded land).
- The bands wrap at the antimeridian and fold over the poles like the ring (`seam_wrap.gd`), and
  every build runs on a worker with the Phase 120 request lifecycle; a band swap never blocks a
  frame.
- Colours: rock and snow by altitude as today, so far ranges read as rock and white caps through
  the Phase 164 haze; the bands use the same curvature shader as the ring.
- Camera `far` follows the outermost radius; depth precision is checked at that range (Godot 4's
  reverse-Z), and the bands sit `RING_DROP` below the ring so the seams between bands never
  z-fight.

**Acceptance criteria:**
- [x] Suite: the outermost band radius equals the closed form for the default eye height and the
  fabric's `maxHeight`, and changes when `maxHeight` does.
- [x] Suite: on a fixture shape with a single 500 m peak, the peak's band vertex is within 5 m of
  the peak height at 20 km, 50 km and 80 km, and `visible_over_horizon` agrees with whether the
  vertex, after `curvature_drop`, is above the eye line.
- [x] Suite: walking one near-band cell rebuilds only the near band; a far band rebuilds only after
  a whole far-band cell; no band build runs on the main thread.
- [x] Suite: bands across the antimeridian and past a pole match the shape sampled at the wrapped
  position; adjacent bands share their boundary heights (no cracks) to within `RING_DROP`.
- [x] Suite: the bands carry no collision body, and the total distant vertex count stays within a
  fixed budget at the default view distance.
- [x] Playtest bot: a `far_peak` step stands 60 km from a known ridge on the default seed and finds
  rock or snow pixels above the skyline in its direction; the step reports frame time and fails over
  the existing hitch limit.
- [x] Suite green on both boot paths, harness green.

**Implementation notes:** `src/terrain/distant_bands.gd` (square annuli of cell `256 · 2^k`, the outer edge of band k
is the hole of band k+1 and takes its heights, so the seams have no crack and no overlap; band 0's hole lies under the ring);
`DistantTerrain.make_bands` / `reach_m` wire it in (the camera's far follows `reach_m`); suite `bands_tests.gd`;
playtest step `far_peak` (`_find_far_peak`, `rock_pixels_above`).

