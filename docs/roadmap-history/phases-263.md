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
takes an `EditRemesh` level, and a dig or placement (`VoxelEdit` mine/place, host and client) asks it for the edited
tile's own chunk (`PRIMARY`) and for the neighbours whose seam it touches (`NEIGHBOUR`). A primary chunk at full detail
is built on the main thread at once when the native builder is loaded (one per frame, reusing the chunk's built
heightmap), and attached with its collision; the rest wait in their own line, drained before `_rebuild_queue` and
`_load_queue` and outside the frame's pump budget, dispatch at high priority, and attach ahead of the attach budget.
Each edit rebuild is timed (queue wait, build, the main-thread job, total, frames).
`src/terrain/edit_prediction.gd` (owned by `VoxelSlice`): a client applies its own mine or place to its voxel data
(the same `_apply_edit` the host's `block_changed` runs) and sends `block_edit_intent` with a prediction number
(`edit_seq` on the wire). The host echoes it on the `block_changed` it applies (with the asker's peer id) or answers
`block_edit_refused` (out of reach, no work timer, refused by the slice); the client keeps or rolls back the touched
op logs, vein depletion and partial marks byte for byte (every later prediction with it), and shows
`edit.rolled_back.refused|timeout`. A placement is predicted only for a material the client's pack shows; the pack
itself only changes on the host's sync. The playtest `mine` step digs five more blocks after the timed one and
reports `edit_visible` (gated at 2 frames in `docs/perf/playtest-budget.json` under `edit_visible_frames`, by the bot
and by `tools/check_playtest_budget.py`); a new CI job runs the harness under `wan_br` with the native builder, where
the `predicted_edit` step requires the edited mesh before the confirmation.

Measured locally (native, headless, the spawn village): every dig showed in the frame it completed (1 frame p95),
but that frame carries the whole chunk build, 50–70 ms (the native runs resolve about 13 ms and the mesh with its
collision about 18 ms of it, plus the attach). Under `wan_br` (local harness, 55/55 steps) the client's dig was on
screen 53 ms after its completion, in 1 frame on the main thread, and the host's confirmation came 248 ms after it.
The frame criterion holds; the frame is long. A remesh of only the
edited tiles is the follow-up.
