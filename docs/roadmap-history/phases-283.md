## Phase 283 — Trees that look like trees: closed faces, a trunk and a real crown

Owner's playtest, 2026-11-19: the upper part of a tree can be seen into and does not look good. Trees are two boxes
(`tree_slice.gd` `_tree_mesh()`, `MeshUtil.add_box`) in one MultiMesh. `MeshUtil` winds faces counter-clockwise
seen from outside, which Godot 4 treats as back faces; with the default culling, the outside faces are culled and
the inside shows. The voxel terrain hides the same winding with `CULL_DISABLED`; the tree material does not.

- Fix `MeshUtil.add_box` and `MeshUtil.add_box_arrays` (both built from the shared `_box_faces`) and any other
  `MeshUtil` builder to Godot's front-face winding, and check every user still renders outward: trees, the
  loose-item fallback, the rare-vein deposit markers (`add_box_arrays` in `voxel_mesh.gd` and `voxel_smooth.gd`),
  and any debug or placeholder boxes. The terrain's
  `CULL_DISABLED` stays only where a mesh is truly two-sided.
- Trees come from a model per tree species (`models/trees/<species>.glb.raw`, the species from the fabric's
  biome/flora tables), with up to two variants per species, chosen by the tree's seed. Placeholders for every
  species key are generated in the public repo: a tapered trunk and a crown of several overlapping closed lumps
  (not one box), coloured per species.
- The procedural mesh stays as the fallback when a key fails to load, with the fixed winding.
- Trees get a gentle wind sway in the vertex shader (crown only, weighted by height), off on the low graphics path.
- No world-gen change (positions and species are untouched), so no `WORLDGEN_VERSION` bump. Art: assets A42.

**Acceptance criteria**
- Suite: every triangle `MeshUtil.add_box` and `MeshUtil.add_box_arrays` emit has its face normal (from the winding
  Godot uses) pointing away from the box centre; same for the tree fallback mesh and a chunk's deposit markers.
- Suite: each fabric tree species has a placeholder model at its key; a tree uses its species' model when it loads
  and the fallback otherwise; the variant pick is stable for a given tree seed.
- Suite: the placeholder crown is closed (every edge shared by two triangles).
- Playtest bot `travel` and `horizon` steps stay within their frame budgets with the new trees.
