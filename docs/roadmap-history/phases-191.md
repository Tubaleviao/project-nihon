# Roadmap history — Phase 191

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 191 — Fast flight IV: a recent-chunk cache, no holes, and a /speed cap of 30 on a slow machine ✅ Done

**Goal:** turning back rebuilds ground that was built seconds ago, and a chunk not yet built shows as
empty space. With Phases 187–190 in place, raise the admin speed cap and prove it holds on a slow
machine.

**Newel dependency:** NO.

**Depends on:** Phase 190.

**Deliverables:**
- An LRU cache of recently built chunk arrays (bounded by memory), keyed by chunk and revision, so a
  return trip attaches without a rebuild. An edit invalidates it.
- The distant ring draws under any chunk of the window that is not built yet, so the player sees coarse
  ground, never a hole.
- `AdminRules.SPEED_MAX` 10 → 30 (flying: 270 m/s). The playtest bot's `flight` step runs at the new
  top speed.
- CI runs the `flight` step a second time with the worker pool limited to 2 threads (the slow-machine
  case) at the old 90 m/s.

**Acceptance criteria:**
- [x] Suite: a cached chunk attaches without a dispatch; an edit invalidates its entry; the cache
  stays within its bound.
- [x] Suite: the distant ring covers an unbuilt window chunk and leaves a built one to the voxel mesh.
- [x] Playtest bot (CI): `flight` at 270 m/s keeps the ground under the body built in ≥ 90% of samples.
- [x] Playtest bot (CI, 2 worker threads): `flight` at 90 m/s keeps it in ≥ 90% of samples.
- [x] `/speed` accepts 30 and refuses 31, in `admin_tests`; catalog strings updated in `en` and `pt_BR`.
- [x] Suite green on both boot paths, net harness green.

**Implementation notes:**
- `src/terrain/chunk_cache.gd`: an LRU of worker results (`arrays` + `heightmap`) per chunk, bounded to 96
  entries and 192 MB of packed arrays. Entries carry a signature: the level of detail, the edit revisions of
  the chunk and its eight neighbours, and the hash of the chunk's generation record. A lookup under another
  signature drops the entry; `request_rebuild` drops it at once (also for a chunk that is not loaded), and
  `restream` and `discard_pending_records` (`/regen world`) empty the cache. A dedicated server (no render) caches nothing.
- `ChunkManager._attach_built` is the attach half of `_apply_build_entry`, shared with the cache path:
  `dispatch_worker_noise_build` attaches a hit at once instead of adding a task (`cache_attaches` counts them).
- `DistantTerrain.set_unbuilt` keeps an 8×8-quad patch under every unbuilt chunk of the local window
  (`ChunkManager.unbuilt_window_chunks`, fed each frame by `game_root`), 0.5 m below the voxel ground and
  freed when the chunk is built; at most 3 new patches per call.
- `AdminRules.SPEED_MAX` is 30 (flying 270 m/s). The `flight` step flies at 270 m/s and measured 100% under
  the body locally; `--playtest-only flight --playtest-flight-speed 10` plus an `override.cfg` limiting the
  worker pool to 2 threads is the slow-machine CI step (90 m/s, 100% locally).

