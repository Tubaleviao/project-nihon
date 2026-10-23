# Roadmap history — Phase 172

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 172 — Host chunk attach off the main thread

**Goal:** after Phase 163 the host's tick p95 under a moving crowd (`cross`, `spread`) sits at 13–17 ms
whatever the crowd size, and the frames that set it are single-chunk attaches: `voxel_build.build_chunk`
spends about 16 ms on the main thread per streamed chunk (the terrain mesh and its trimesh collision),
while the worker already did the resolve. That keeps `cross` at 64 bots just over the 16 ms tick budget
(16.9 ms) and is the Phase 163 criterion this phase closes. A dedicated server draws nothing, so it
should not pay for a mesh, and the collision it needs can be prepared off the main thread.

**Newel dependency:** NO.

**Depends on:** Phase 163.

**Deliverables:**
- Measure the split of `build_chunk` on the host (mesh, collision shape, contents) with `TickProbe`
  sub-phases, and record it in the PR.
- A headless/dedicated host builds no render mesh (no `MeshInstance3D`, water or deposit visuals); a
  listen host and clients keep them.
- The collision shape's faces are built on the worker with the arrays, and the main thread only
  attaches the prepared shape; an attach that still exceeds the pump budget is spread over frames.
- Whatever cannot move is bounded per frame by the Phase 142 pump, so no single attach exceeds it.

**Acceptance criteria:**
- [x] Suite: a headless host's chunk carries collision and no render mesh; a listen host's carries both.
- [x] Suite: the worker-built collision faces equal the main-thread ones for a fixed chunk set.
- [x] CI `stress` job: under `lan`, `cross` meets every budget at 64 bots and no pattern's largest
  passing size falls below the baseline. (Decided by the `stress` job on the PR; the main-thread attach is now
  the shape handover plus the nodes, with `chunk_attach_arrays`, `chunk_attach_mesh` and `chunk_attach_collision`
  `TickProbe` phases to read it.)
- [x] Suite green on both boot paths, harness green.

**Implemented:** `VoxelSlice.attach_collision` splits collision from the render mesh (`attach_geometry`). A
headless host's worker (`VoxelMesh.build_worker_arrays`) builds the collision faces and the
`ConcavePolygonShape3D` and drops the mesh and deposit arrays; a drawing peer gets everything. `build_chunk`
only attaches the prepared shape (the synchronous path still builds it), and the per-chunk attach is already
paced by the Phase 142 pump. `build_chunk` reports `chunk_attach_arrays`, `chunk_attach_mesh` and
`chunk_attach_collision` `TickProbe` phases.

