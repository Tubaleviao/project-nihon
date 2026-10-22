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
  `report.json` shows no step with a hitch over 50 ms (the bot does not fail on hitches, so this is
  read from the report, not from the exit code).
- [x] Suite green on both boot paths, harness green.

**Shipped:** `NativeChunkBuilder.build_chunk_arrays(chunk_pos, heightmap, resolved, local, cfg)` (version 4,
`native/src/native_mesh.cpp`) ports the greedy mesher: the per-direction face groups, the row-major rectangle
merge, the two triangles and collision soup per rectangle, and the deposit boxes. The reference's output order
is dictionary insertion order (directions, then groups, in first-seen order), which Godot guarantees, so it was
already deterministic; the port keeps first-seen order explicitly. `VoxelMesh.build_chunk_arrays` routes through
the loader and `build_chunk_arrays_gd` is the reference and fallback. The suite compares every result key `==`
(bit-exact) on ten chunks x three resolve variants x `local` on and off, plus the natural-column fallback.
With Phases 167 and 168, the whole chunk build runs native when the extension loads.

Playtest: the report carries `builder` and a per-step `chunk_build_rate`; the `stream` step times only its waits
for chunk builds, so its fixed pauses do not dilute a faster builder. The `--no-native` user arg forces the
GDScript builder. CI runs the bot once per builder (`playtest` matrix, same commit) and `playtest-compare` runs
`tools/check_native_speedup.py`: native `stream` rate at least 2x the fallback's and no native step with a hitch
over 50 ms.
