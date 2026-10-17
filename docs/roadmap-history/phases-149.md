# Roadmap history — Phase 149

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 149 — Review follow-ups III: world, terrain and persistence

**Goal:** clear the world-side review items: settling sand that is lost on quit, flying creatures
glued to the ground, creatures stuck at the end of a partial path, tree-clear records that can drop
or hit the wrong tree, and persistence edge cases in the save journal and region streaks.

**Newel dependency:** NO.

**Depends on:** none.

**Deliverables:**
- #365: the `_settle` queue (queued and parked columns) is saved with the region and re-queued on
  load. `settle_column` and `moves` share one support walk. The client checks that the material
  is granular in `_apply_settle`.
- #363: a fabric `movement` field on creatures (`ground`, `flying`, `swimming`); flyers are not
  snapped to the surface and keep a hover band above it. `_walk_path` retries a partial path on a
  timer. The harness measures the stored and mirrored positions, not a re-set one.
- #367: tree-clear spots are held by index, not geometry, so a clear never removes a neighbour.
  Spot eviction never drops a persisted clear. `SaveTxn.commit` with `ERR_BUSY` keeps the staged
  ops. The generation fingerprint stamp keeps the original. `ends_streaks` only resets a region that
  was actually written.
- #369: `warm_polar_caches` calls `WorldShape.warm()`. The PR #368 description note about
  `WORLDGEN_VERSION` is corrected on the PR.
- #354: `_airborne` counts only while falling, so a long jump does not snap to the fall pose at
  its apex. The elbow bend follows the forward swing.

**Acceptance criteria:**
- [x] Suite: undermine a sand column, save and quit before it settles, reload: the column finishes
  settling and nothing floats.
- [x] Suite: a `flying` creature keeps its hover height across 100 AI ticks. A `ground` creature
  stays on the surface.
- [x] Suite: a creature at the end of a partial path to a fixed goal retries within the retry
  interval.
- [x] Suite: clearing one of two trees 0.2 m apart and reloading keeps the other tree.
- [x] Suite: `ERR_BUSY` from `commit` leaves the staged ops intact for a retry.
- [x] Suite: a jump that lasts longer than the fall threshold does not enter `fall` before its apex.
- [x] Every in-scope item of #354, #363, #365, #367 and #369 is ticked on its issue.
- [x] Suite green on both boot paths, harness green.

**Implementation notes:** the settle queue is not stored: every edited column read from disk is queued
again (a settled column is a no-op), which covers queued and parked columns without a region schema
change. The fingerprint stamp keeps Phase 138's single-notice refresh (its tests pin it). Still open:
nothing in code. The `net_harness` creature check measures the stored position as it is (hover band for flyers); creatures have no client mirror to measure. Issue items for the work above are ticked on #354, #363, #365, #367 and #369; items outside this phase's deliverables (private rig bones, chunk_manager deferred stamp, harness probe waits, seam-wrap audit, tree-spot release hook) and the deliberately kept fingerprint-stamp refresh stay open on their issues.
