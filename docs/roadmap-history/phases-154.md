# Roadmap history — Phase 154

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 154 — Split the biggest slices

**Goal:** four files hold a large share of the game: `src/terrain/voxel_slice.gd` (~3.3k lines),
`src/networking/networking_slice.gd` (~2.4k), `src/ui/ui_slice.gd` (~1.8k) and
`src/character/character_slice.gd` (~1.8k). They mix several jobs, which makes reviews slow and
merge conflicts common between the autopilot's parallel branches. Phase 132 already did this for
wiring. This phase does the same for the slices, with no change in behaviour.

**Newel dependency:** NO.

**Depends on:** Phases 147–150 (they touch the same files; split after, to avoid conflicts).

**Deliverables:**
- `voxel_slice.gd` → edit/authority, settle, mesh build and persistence modules. The slice stays the
  public facade.
- `networking_slice.gd` → transport/emulator, peer registry, intent validation and AOI/delta modules.
- `ui_slice.gd` → one module per window (inventory, crafting, research, character, map), plus a
  shared `item_rows` helper.
- `character_slice.gd` → equipment, appearance/palette and limb animation modules.
- One PR per slice. Each moves code without changing what it does, and the public API of the
  slice is unchanged.
- A suite size audit: no non-test `.gd` file under `src/` is over 1500 lines, apart from an
  explicit allow-list that this phase empties.

**Acceptance criteria:**
- [x] The four files are each at most 1500 lines, and the size audit passes with an empty allow-list.
- [x] The size audit fails on a fixture file over the limit.
- [x] No test file changes except import paths (a behaviour-preserving split).
- [x] Suite green on both boot paths, harness green, playtest bot green.

**Done:** modules `voxel_runs/mesh/consts/persist/edit/build/query`, `net_part_*`, `ui_part_*`, `character_part_*`, `chunk_part_1`; each moved method keeps a forwarder on its slice, so the public API is unchanged. The size audit is `Runner.oversized_source_files` (`MAX_SOURCE_LINES` 1500, empty allow-list).
