# Roadmap history — Phase 189

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 189 — Fast flight II: collision and contents only near the body

**Goal:** after Phase 187 the build threads keep up at 90 m/s, but each attached chunk costs the main
thread about 17–30 ms. Most of that is ground no one touches: collision for a chunk four rings out, and
creatures spawned under a player who is gone a second later. Pay only for the ground that is reached.

**Newel dependency:** NO.

**Depends on:** Phase 187.

**Deliverables:**
- Collision is built only for chunks within Chebyshev 1 of a body (walking), and for the chunk below a
  flying body. A chunk entering that ring gets its collision then (from the worker's arrays, kept or
  rebuilt). A host keeps collision wherever a creature or peer needs it (dedicated server unchanged).
- Creatures and trees of a chunk spawn when its body slows below a threshold or the chunk enters the
  near ring, not at the moment its mesh attaches. Host authority and determinism are unchanged: the same
  ids and positions spawn, later.
- The playtest bot's `flight` step records main-thread ms per attached chunk (TickProbe phases).

**Acceptance criteria:**
- [x] Suite: a chunk outside the near ring has no collision shape, and gets one when it enters; a
  flying body's chunk below has one.
- [x] Suite: a chunk's contents spawn once, with the same ids, whether they spawn on attach or on
  slowing down.
- [x] Playtest bot (CI): `flight` main-thread ms per attached chunk at most half of Phase 187's record.
- [x] Net harness green (peers' windows still have collision where their bodies are).
- [x] Suite green on both boot paths.

**Shipped:** `ChunkManager.defer_far_work` (on in every rendering boot, off on a dedicated server): the voxel
slice's `collision_gate` withholds a built chunk's collision body outside Chebyshev 1 of any window centre
(the local body's or a peer's), keeping the worker's shape in `_pending_collision` until
`serve_deferred_work` attaches it on entering the ring. Creatures and trees wait in `_contents_waiting` and
spawn on entering the ring or, one chunk a frame, once the local window has been still for
`CONTENTS_SETTLE_MSEC`; `_contents_spawned` keeps it once per residency, so ids and positions are unchanged.
The playtest `flight` step reports main-thread ms per attached chunk (gated at half of the Phase 187 record
of about 25 ms, native builder only). Local headless GDScript-builder run: 20.7 → 16.9 ms per chunk (headless
has no real collision cost, so CI's native run is the gate).
