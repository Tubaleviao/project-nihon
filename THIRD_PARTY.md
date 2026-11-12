# Third-party material

Project Nihon is released under the [MIT licence](LICENSE). This file lists the material in or
used by the repository that comes from elsewhere, and the terms it comes under. The private
`assets-prod/` submodule is not covered by the repository's licence and is not listed here.

## Code

| Material | Where | Licence | Notes |
|---|---|---|---|
| [godot-cpp](https://github.com/godotengine/godot-cpp) | `native/godot-cpp` | MIT | Fetched at build time by `tools/fetch_godot_cpp.sh` (gitignored), not distributed in this repository. |
| [Zylann/godot_voxel](https://github.com/Zylann/godot_voxel) | `src/terrain/lod_ring_policy.gd`, `src/terrain/voxel_smooth.gd` | MIT, © 2016-2024 Marc Gilleron | Algorithms ported, not code copied; the notice is in each file. Source commits and per-file rows are in [native/THIRD_PARTY.md](native/THIRD_PARTY.md). |
| [Newel](https://github.com/Tubaleviao/newel) (`@newel/*`) | `node_modules/` | see each package | Build-time tooling for the fabric. Installed by `npm ci`, not distributed in this repository. |
| [Godot Engine](https://godotengine.org/) 4.7 | not in the repository | MIT | The engine the game runs on. Downloaded by CI and by contributors. |

## Textures

The seven terrain material sets in `assets/textures/terrain/` (grass, dirt, moss, rock, sand, snow,
mud) come from [ambientCG](https://ambientcg.com) and are released under
[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). Each set's source page is listed in
[assets/README.md](assets/README.md#terrain-textures-phase-242). They were re-encoded (JPEG, 1024×1024).

## Everything else

The fabric (`fabric/`), the generated design bible (`bible/`), the wiki (`wiki/`), the Godot
resources (`godot/`) and the public placeholder assets in `assets/` are original work of the
project's contributors and come under the MIT licence.

A phase that ports or adopts code, or adds a texture, model, sound or font from another source,
adds a row here in the same pull request, with the source, the licence and the commit or URL.
