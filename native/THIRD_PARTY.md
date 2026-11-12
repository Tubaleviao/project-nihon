# Third-party code in `native/` and `src/`

Code taken or ported from another project keeps its licence notice in the file, and gets a row here
with its source commit. `native/godot-cpp` is fetched by `tools/fetch_godot_cpp.sh` and is not listed.

## Reviewed sources

| Source | Licence | Commit reviewed | Review |
|---|---|---|---|
| [Zylann/godot_voxel](https://github.com/Zylann/godot_voxel) | MIT, © 2016-2024 Marc Gilleron | `dfb0f81c7fd766f68d78715b2138f4e336cd9737` (2026-11-07) | [docs/research/godot-voxel.md](../docs/research/godot-voxel.md) (Phase 249) |

## Ported or adopted files

| File | Ports | Source path | Commit | Licence |
|---|---|---|---|---|
| `src/terrain/lod_ring_policy.gd` (Phase 243) | Clipbox ring boxes: the base box rounded outwards to even coordinates, the minimal parent box (halved, padded by one chunk), the neighbouring rule, the distance per level (the algorithm, not the code) | `terrain/variable_lod/voxel_lod_terrain_update_clipbox_streaming.cpp` | `dfb0f81c7fd766f68d78715b2138f4e336cd9737` | MIT, © 2016-2024 Marc Gilleron (notice in the file) |
| `src/terrain/voxel_smooth.gd` (Phase 240) | Normals from the density gradient at cell corners, interpolated to the vertex; sample padding so both chunks at a border compute the same normals (the algorithm, not the code) | `meshers/transvoxel/transvoxel.cpp` | `dfb0f81c7fd766f68d78715b2138f4e336cd9737` | MIT, © 2016-2024 Marc Gilleron (notice in the file) |

Phase 249 adopted no code. Its algorithm ports land in the phases below, which add a row above for
each file they port:

| Phase | Ports | Source path |
|---|---|---|
| 240 | Normals from the density gradient at cell corners; sample padding | `meshers/transvoxel/transvoxel.cpp` |
| 243 | Clipbox ring boxes: even alignment and the neighbouring rule | `terrain/variable_lod/voxel_lod_terrain_update_clipbox_streaming.cpp` |
| 244 | Region file with a sector table | `streams/region/region_file.cpp` |
| 247 | Ground cover emitted on the built mesh, per-item LOD | `terrain/instancing/voxel_instance_generator.cpp` |
