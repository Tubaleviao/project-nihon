## Phase 263 — Digging that shows at once: a predicted edit and a priority remesh

A dig waits for the host to apply it, then for the chunk's rebuild to come out of the worker queue
behind streaming work. The ground should change the frame the work completes.

- **Measure first:** the playtest `mine` step records, per edit, the time from completion to the
  edited mesh on screen, split into network, queue wait and build, on the listen host and on a
  client under `lan` and `wan_br`.
- **A priority remesh:** an edited chunk (and the neighbour whose seam it touches) jumps the build
  queue, ahead of streaming. If the build is short enough (native smooth mesher), it runs on the
  main thread at once for that one chunk; otherwise it takes the next worker. Collision follows the
  same path, so the player never falls into a hole they cannot see, or stands on one they can.
- **Prediction on the client:** when the host's timer (Phase 259) is about to complete, the client
  applies the edit to its own copy and remeshes as above, marked pending. The host's
  `block_changed` confirms it; a refusal (or no answer within a timeout) rolls the chunk back and
  shows the refusal. Inventory and durability stay host-only: the item appears when the host says
  so.
- Placement gets the same path.

**Acceptance criteria**
- Suite tests: an edited chunk is built before every queued streaming chunk; a predicted edit is
  applied to the client's voxel data and rolled back on a host refusal, leaving the chunk byte-equal
  to before; inventory never changes on prediction alone.
- The playtest `mine` step reports edit-to-visible time; its p95 on the listen host is at most two
  frames at the target frame rate, gated in `docs/perf/playtest-budget.json`.
- The net harness's `wan_br` run shows a client's predicted edit visible before the host's
  confirmation arrives, and a refused edit rolled back.

**Delivered.** `src/terrain/edit_remesh.gd` (owned by `ChunkPart1`): `ChunkManager.request_rebuild(chunk, priority)`
takes an `EditRemesh` level. The local player's own dig or placement (the host's own player, a client's prediction or
its rollback) asks `PRIMARY` for the edited tile's chunk; another player's edit (a remote actor on the host, a replayed
`block_changed` on a client) and every seam neighbour ask `NEIGHBOUR`. A `PRIMARY` chunk is attached on the main thread
at once only when that is cheap: its build was made ahead (below), or the chunk's last full-detail build took at most
`MAX_SYNC_JOB_USEC` (6 ms; one per frame). Everything else waits in the edit line, drained before `_rebuild_queue` and
`_load_queue` and outside the frame's pump budget, dispatches at high priority, and attaches ahead of the attach budget.
Each edit rebuild is timed (queue wait, build, the main-thread job, total, frames, prebuilt or not).
`src/terrain/edit_prebuild.gd` (PR #648 review): a whole native chunk build is 30–40 ms, so building the dug chunk on
the main thread at completion made a 50–70 ms frame. The dig is known earlier: when this machine's player starts work on
a block (`work_start_requested`, Phase 259), `VoxelEdit.prebuild_edit` applies the dig to the voxel data for a moment,
gathers the chunk's build input, puts the data back and runs the build on a worker. At completion the held build is
attached as is only when the chunk's input gathered then is the very input it was built from (op logs, depletion,
biomes and seed by value; heightmaps by identity), so it is the edit's own build; anything else is a miss and takes the
ordinary path. `VoxelBuild.reuse_shapes` keeps a rebuilt chunk's unchanged collision quadrants, so the physics server
builds only the quadrant the dig changed.
`src/terrain/edit_prediction.gd` (owned by `VoxelSlice`): a client applies its own mine or place to its voxel data
(the same `_apply_edit` the host's `block_changed` runs) and sends `block_edit_intent` with a prediction number
(`edit_seq` on the wire). The host echoes it on the `block_changed` it applies (with the asker's peer id and the span it
resolved) or answers `block_edit_refused` (out of reach, no work timer, refused by the slice). PR #648 review: the
predictions sit on top of the host's state. The host's op log of every tile a pending prediction wrote is kept, and any
host change (another player's edit on the tile, a vein depleted anywhere, the confirmation of a later prediction)
rebuilds the data from it: the tracked tiles go back to the host's logs, the change goes on, and the pending
predictions are made again. A refusal or timeout takes out that one prediction the same way (only its own depletion
goes), and shows `edit.rolled_back.refused|timeout`. A confirmation compares the host's span with the prediction's and
with the one derived on the host's state, and applies the host's when they differ. A re-scope snapshot or `/regen world`
drops every prediction. A mine of a placed block is not predicted (the host may only damage it). A placement is
predicted only for a material the client's pack shows; the pack itself only changes on the host's sync. The playtest
`mine` step holds work for the timed dig and five more beside it and reports `edit_visible`, gated on the p95 TIME
(2 frames at 60 Hz, 33.3 ms: `edit_visible` in `docs/perf/playtest-budget.json`, by the bot and by
`tools/check_playtest_budget.py`); a CI job runs the harness under `wan_br` with the native builder, where the
`predicted_edit` step requires the edited mesh before the confirmation.

Measured locally (native, the spawn village). Before the review fixes, every dig showed in the frame it completed, but
that frame carried the whole chunk build: 50–70 ms (native resolve about 13 ms, mesh and collision about 18 ms, the
attach with Jolt's shape build about 12 ms). After them, the rendered playtest (`xvfb`, opengl3, three runs of
`create,mine`) showed all 6 digs prebuilt and attached on the main thread, with an edit-to-visible p95 of 5.1, 4.8 and
6.4 ms (1 frame), against the 33.3 ms budget. Headless, it was 5.2 ms. In the net harness, the client's predicted dig
was on screen 7.7 ms after its completion on loopback (55/55 steps), and 7.9 ms after it under `wan_br` (55/55),
while the host's confirmation came 124.5 ms after it.
