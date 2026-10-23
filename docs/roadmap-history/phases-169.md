# Roadmap history — Phase 169

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 169 — Native `build_chunk_arrays` and the speed target

**Newel dependency:** NO.

**Depends on:** Phase 168.

**Deliverables:**
- `build_chunk_arrays` (the greedy mesher) ported to `NativeChunkBuilder` with a deterministic output
  order, routed through the loader. The whole chunk build now runs native when the extension loads.
- The playtest bot's `stream` step records the chunk build rate and which builder was used, and CI
  runs the step once per builder on the same commit.

**Acceptance criteria:**
- [x] Suite: native and GDScript builders give equal arrays for the fixed chunk set; the GDScript
  fallback is used when the extension is absent.
- [x] Playtest bot (CI): the `stream` step's chunk build rate with the native builder is at least
  double the GDScript fallback's on the same commit (so Phase 142's pump gains are not counted), and
  `report.json` shows no more frames over 50 ms than the fallback run's (software GL under xvfb hitches
  in every step whatever the builder, so the fallback run is the baseline; the bot does not fail on
  hitches, so this is read from the reports, not from the exit code).
- [x] Suite green on both boot paths, harness green.

**Shipped:** `NativeChunkBuilder.build_chunk_arrays(chunk_pos, heightmap, resolved, local, cfg)` (version 4,
`native/src/native_mesh.cpp`) ports the greedy mesher: per-tile faces grouped by (direction, plane, span,
colour), the row-major merge, the vertex/normal/colour/index/collision arrays and the deposit boxes.
Output order is the reference's: a group's first appearance fixes its place, as a Dictionary's insertion
order did. `VoxelMesh.build_chunk_arrays` routes native and falls back to `build_chunk_arrays_gd` when the
extension is absent or the native side rejects its input (malformed table, wrong heightmap size). The suite
compares `==` on ten chunks in three resolve variants, absolute and chunk-local, plus a bare natural build.
The playtest bot's `stream` step now times the pure worker half on 24 chunks and records `builder` and
`build_rate` (chunks/s); `--no-native` forces the fallback; CI runs the bot twice on the same commit and
`tools/check_stream_rate.py` requires native >= 2x the fallback and no more hitch frames than the fallback run (plus a small noise allowance).
Not run locally: the gate itself (it needs the CI renderer and runner).

