# Roadmap history — Phase 152

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 152 — Item models and icons from one generator

**Goal:** turn each item's shape into a low-poly model and a 32×32 icon drawn from that same model,
so the two always match and every item has both. The output replaces today's coloured-square icons
and textured boxes as the **public placeholders**. The private repo's phases A4, A5 and A8
(`project-nihon-assets/ROADMAP.md`) then hand-polish over the same keys with no code change.

The pattern is the one `dumb_engine/tools/make_robot.py` and
`project-nihon-assets/tools/build_player_rig.py` use: every part and material built from code,
nothing hand-placed. But it runs in pure Python like `tools/gen_placeholder_glb.py`, so CI and a
fresh clone need no Blender, GPU or Rust toolchain.

**Newel dependency:** NO.

**Depends on:** Phase 151.

**Deliverables:**
- `tools/gen_item_assets.py` (new) — reads each item's `shape` from the generated item data. For
  each archetype it assembles parametric parts (boxes, bevelled prisms, cylinders, wedges, low-res
  spheres) and gives each part its material's palette colour. It writes:
  - `assets/models/items/<ItemId>.glb.raw` — one closed mesh within the `STYLE.md` held-item budget
    (≤ 300 tris), origin at the grip, with a `grip` node and a `+Z` forward axis that the equipment
    sockets read.
  - `assets/icons/items/<ItemId>.png.raw` — a software render of the same triangles: orthographic
    camera 30° down and 45° around, one sun from the top left with one highlight and one shadow band,
    a transparent background, rendered at 128×128 with a z-buffer, downsampled to 32×32 with a
    palette snap, and a 1 px outline in the darkest palette value of the dominant part.
    This follows the icon rules in `project-nihon-assets/STYLE.md`.
- Output is deterministic: the same fabric gives byte-identical files.
  `assets/models/items/shapes.lock.json` records a hash of each item's shape and palette inputs.
- `tools/gen_placeholder.py` stops writing item icons (`ITEM_IDS` removed), and
  `gen_placeholder_glb.py` stops writing `ITEM_BOXES`. One tool owns item art.
- `assets/manifest.json` lists every item model. `assets/README.md` describes the generator.
- `project-nihon-assets/ROADMAP.md` (separate PR in that repo): A4/A5/A8 note that their
  placeholders and starting renders come from this generator. `icon_rig.blend` can be the same
  camera and light, exported from these parameters.

**Acceptance criteria:**
- [x] Every item in `GameData.ITEMS` has `models/items/<ItemId>.glb.raw` and
  `icons/items/<ItemId>.png.raw`. No orphan file exists for an id that is not an item.
- [x] Suite: every item model parses through `AssetOverlay`, has a `grip` node, is at most 300 tris,
  and its AABB fits its archetype's bounds.
- [x] Suite: every icon is 32×32 RGBA, its corners are transparent, it has more than 40 opaque
  pixels, and no two items share a byte-identical icon.
- [x] CI (no Blender): `python3 tools/gen_item_assets.py --check` recomputes the shape hashes and
  fails when `shapes.lock.json` is stale, so a fabric shape change without regenerated art fails
  the build.
- [x] Running the generator twice gives identical bytes (CI runs it into a temp dir and diffs).
- [x] Suite green on both boot paths.

**As built:** `tools/gen_item_assets.py` (pure Python; `--out DIR` for the determinism diff, `--check` for CI). `shapes.lock.json` also carries the triangle budget and each archetype's bounds, which the suite reads. Items with identical shapes (the two aethermite shards) differ through a per-id seeded facet jitter. The generated glb carries `COLOR_0` per part, no UVs; the five `textures/items/` sheets stay for the private art.
