# Roadmap history — Phase 232

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 232 — Water that holds up: lake shores, the river seam and mounts at fords

Phase 217 put lakes and rivers on unrecorded land, and #589 fixed half of its review notes. The rest
are visible in play (a lake edge hanging as a wall of water, rivers jumping 512 m at the X seam,
water stopping dead at an older recorded chunk) or cost frame time (fresh water meshed on the main
thread for every chunk). Mounts still refuse any river, even a stream their own creature fords.

- **Lake shores:** `Hydrology.lake_of_cell` samples the ground with detail noise and massifs, not the
  shape alone, and the surface is clamped so no ground outside the disc lies below it. The basin is
  then carved with Phase 245's terrain CSG helper (revised 2026-11-25, from GDVoxelTerrain's
  composable SDF ops): the ground inside the shore is smooth-subtracted by a bowl (a flattened
  ellipsoid at the lake's depth), and where the rim sits less than a freeboard (fabric, about 0.5 m)
  above the surface it is smooth-unioned up into a low natural levee, so the water always meets a
  sloping bank instead of a wall. A lake whose levee would have to rise more than a fabric maximum
  (about 3 m) is dropped.
- **River seam:** the river cell wrap period is an exact divisor of the circumference (or rivers are
  traced in seam-wrapped coordinates, `seam_wrap.gd`), so a river crossing the X seam continues on
  the other side. Phase 245 now runs first and replaces the local trace with baked rivers, so check
  the seam on the baked rivers; if the bake already wraps, this bullet reduces to its test.
- **Frontier:** a lake or river that reaches a recorded chunk of an older generator ends at a shore,
  not a cut: `frontier.gd` eases the water surface down to the recorded ground over `BLEND_CHUNKS`,
  as it already eases heights.
- **Spawn plain:** lake discs and river segments are excluded by their full extent, not their centre
  or vertices.
- **Build cost:** `voxel_build.build_chunk` skips fresh water when the chunk has no features, and
  builds the fresh-water surface on the worker thread with the rest of the chunk.
- **Mounts at fords:** `MountWiring._in_water` uses `CreaturePath.blocks_water(width,
  CreatureAI.FORD_WIDTH_M)`, so a ground mount carries its rider across a stream its creature would
  ford, and still refuses a wide river or a lake.
- Any change to world-gen output bumps `TerrainSlice.WORLDGEN_VERSION` with a history line and
  updates `_test_worldgen_golden`.

**Done (2026-11-27):** lake shores (the surface is clamped under the ground around the disc, the basin is a smooth-subtracted CSG bowl, and a bank and levee rise from the fabric `lakeFreeboard` / `lakeMaxLevee`), the frontier water ease (`Hydrology._eased`, `Frontier.water_weight`), the spawn plain excluded by full extent (lake discs, river segments and widths), fresh water skipped on chunks without features and built on the worker thread, mounts fording streams (`MountWiring._in_water`, #593), and the planet bake wrapping east-west (bake 18, `NativeBake` version 7), so a river crosses the X seam. Lake and river changes are gated by the chunk record version, and the bake version follows the world's recorded worldgen version. Worldgen 18. Known limit: a lake that the old rule kept but the new one drops (ring clamp under sea level plus 3 m, levee over the maximum, pole gap, the plain by disc) stays as the recorded chunk has it and ends at that chunk's edge in unrecorded land (a wall of water), since the unrecorded side has no lake to ease.

**Closes:** #573, #593

**Acceptance criteria**
- #573 (lake edge): a suite test samples the rim of 50 lakes on the pinned seed and finds no ground
  sample outside a disc below its surface, and no shore step (adjacent tiles across the waterline)
  over 0.5 m.
- #573 (river seam): a suite test traces a river across the X seam and finds its two ends within one
  river width of each other.
- #573 (frontier): a suite test records an older-version chunk beside a lake and asserts the water
  surface meets the recorded ground with no vertical step over 0.5 m.
- #573 (spawn plain): a suite test asserts no lake disc or river segment overlaps the spawn plain on
  20 seeds.
- #573 (build cost): a suite test builds a chunk with no features and asserts no fresh-water node is
  made; the playtest `flight` step's worker and main-thread budgets still pass.
- #573: the items fixed by #589 (cache reset, record changes, crossing width, ice material) keep
  their tests; the issue's checklist is ticked in full.
- #593: a suite test calls the real `MountWiring._in_water` against a wired `CreatureSlice` (no
  stub): a stream narrower than `FORD_WIDTH_M` is not water, a wide river and a lake are.
- `WORLDGEN_VERSION` bumped and golden values updated if world-gen output changed; suite, both boot
  paths and `tools/net_harness.sh` green.
