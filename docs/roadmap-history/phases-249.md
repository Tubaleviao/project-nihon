# Roadmap history — Phase 249

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 249 — What to reuse from Zylann's godot_voxel ✅ Done

[Zylann/godot_voxel](https://github.com/Zylann/godot_voxel) (MIT) is a mature voxel engine for Godot:
smooth meshing (Transvoxel), LOD, streaming, region files, generators and instancing. It ships mainly
as a C++ engine module (a custom Godot build), with a GDExtension build in progress. This project has
its own run-based voxel storage, a headless authoritative server, the stable-world rule and a
GDScript reference for every native function, so the engine as a whole does not fit, but parts of it
may save Phases 240–244 a lot of work.

- **Review** (`docs/research/godot-voxel.md`): for each of Transvoxel and its LOD seams, the LOD
  octree/clipmap, streaming and task scheduling, region/block storage and compression, mesh
  instancing for ground cover, and the SDF/edit tools, say what it does, which open phase it touches
  (239–244, 247), whether it fits (Godot 4.7, GDExtension rather than a custom engine, deterministic
  and safe on a worker, works on runs, headless server) and the verdict: adopt the code, port the
  algorithm, or skip.
- **Then implement what passes**, on the Phase 248 base, each part with its GDScript reference or
  parity test as this project requires. Code taken from the project keeps its MIT notice
  (`native/THIRD_PARTY.md` or equivalent). If a verdict changes how a later phase is built, update
  that phase's spec in this file in the same PR.
- If nothing fits, the review is the deliverable and the phase is done.

**Acceptance criteria**
- `docs/research/godot-voxel.md` exists with a verdict and its reason for each part listed above.
- Every adopted file carries its licence notice, and `native/THIRD_PARTY.md` lists its source commit.
- Each adopted part has a parity test (GDScript against native) or a suite test per behaviour it adds.
- The suite, the harness and the playtest pass.

**Done.** Review in [docs/research/godot-voxel.md](../research/godot-voxel.md) (godot_voxel at
`dfb0f81`, MIT). No code adopted: the engine as a whole, Transvoxel as the mesher, its transition
cells, octree streaming, the task scheduler and the SDF edit tools are skipped, each with its reason.
Four algorithms are ported later, in the phase that builds the feature, and those specs now say so:
normals from the density gradient and sample padding (240), clipbox ring boxes (243), a region file
with a sector table (244) and ground cover emitted on the built mesh (247). Phase 241 no longer
mentions adopted Transvoxel code. `native/THIRD_PARTY.md` lists the reviewed commit and the pending
ports. The acceptance criteria on licence notices and parity tests apply to those later ports; no
code changed, so the suite, harness and playtest are unchanged from `main`.
