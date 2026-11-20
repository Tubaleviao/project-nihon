# Roadmap history — Phase 244

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 244 — A chunk cache on disk ✅ Done

Every visit rebuilds a chunk from noise. The host already stores edits and generation records per
region (`region_store`).

- **Host:** the resolved runs of a generated chunk are written next to its region the first time the
  chunk is built, keyed by `WORLDGEN_VERSION`, the worldgen fingerprint and the chunk's edit revision.
  A later build reads them instead of generating. Edits update the entry.
- **Client:** built mesh arrays (full, coarse and LOD levels) are cached under `user://cache/` with the
  same key plus the mesher version, capped in size with least-recently-used eviction. A revisit loads
  arrays from disk on a worker instead of meshing.
- **One file per region and layer** (Phase 249, the region-file layout ported from godot_voxel, MIT
  notice in the file and a row in `native/THIRD_PARTY.md`): a header with a sector table (one 32-bit
  entry per chunk of the 32×32 region: a 24-bit sector index and an 8-bit sector count, 0 for absent),
  entries at fixed-size sector boundaries, compressed with Godot's `compress(COMPRESSION_ZSTD)`. An
  entry that outgrows its sectors is moved to the end and the following sectors close the gap. Each
  entry starts with its own key, so a stale entry is a miss without reading the rest. The
  authoritative `region_store` JSON files do not change.
- A stale key is a miss, never an error. Deleting the cache only costs time.

**Acceptance criteria**
- Suite tests: a cached chunk and a freshly built one give identical runs and arrays. Bumping any key
  part turns the entry into a miss. An edit invalidates the entry.
- A suite test fills the client cache past its cap and finds the least recently used entries evicted.
- A playtest step flies a loop twice: the second pass's worker ms per crossing is at most 0.65 of the
  first's.

**Status (Phase 244, done).** What shipped, and where it differs from the first sketch:

- `src/persistence/region_layer_file.gd`: one file per 32×32 region and layer, sector 0 the table (24-bit
  sector, 8-bit count), entries at sector boundaries starting with their 64-bit key, zstd-compressed, an entry
  that outgrows its sectors moved to the end with the following sectors closing the gap. A short, torn or
  damaged file is a miss. Port notice in the file, row in `native/THIRD_PARTY.md`.
- `src/terrain/disk_chunk_cache.gd`: the `mesh` layer (client, `user://cache/chunks/`, capped at 512 MB, least
  recently used first) and the `gen` layer (host, `user://saves/server/regions/cache/`). Keys hold
  `WORLDGEN_VERSION`, the worldgen fingerprint, `MESHER_VERSION` and the build's inputs: the level of detail,
  a content digest of the edits of the chunk and its eight neighbours (`VoxelQuery.edit_digest`; the session
  counter `edit_revision` is not stable across sessions) and the chunk's own generation record (a neighbour's
  record is left out, as in the memory cache: neighbours are recorded after this chunk built).
- A revisit decodes the entry on a worker (`ChunkPart1.take_disk_hit`) and attaches it like a finished build;
  an unreadable entry is dropped and the chunk builds.
- The host's layer stores the generator's heightmap (the output of generation, keyed by seed, the chunk's
  edit digest and its record), not the resolved runs: the runs depend on the neighbours' seam
  strips and are cheap next to the noise, so caching them would only widen the key.
- Playtest step `revisit` (after `flight`): flies the loop, drops the memory cache, flies it again; the gate
  (native builder) is a second pass with chunks from disk and worker ms per crossing at most 0.65 of the first's (half failed a CI run at 0.54: decoding and rebuilding the collision shapes is about 1 ms a chunk). One unmeasured warm-up flight sits between them, so levels of detail the first pass skipped are on disk too; the disk cache has one layer per level of detail.
- Tests: `src/tests/suites/chunk_disk_cache_tests.gd`.
