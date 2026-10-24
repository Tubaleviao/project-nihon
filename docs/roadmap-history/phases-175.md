# Roadmap history — Phase 175

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 175 — UI icons: dock, windows, skills and status from one generator

**Goal:** the window dock shows one letter per button (I, C, K, H, T…), and skills have no
pictures. Draw each window, skill and status effect as a small, readable icon: a bag for the
inventory, a globe for the map, a hammer and anvil for crafting. Use the Phase 152 pattern:
pure-Python, deterministic, and hand-polished later by the private repo over the same keys.

**Newel dependency:** NO.

**Depends on:** Phase 173.

**Deliverables:**
- `tools/gen_ui_icons.py` (new, pure Python, no Blender or GPU). It uses a small vector DSL
  (polygons, circles, arcs, strokes) rasterized at 128×128 and downsampled to 32×32 and 64×64,
  with a palette snap and a 1 px outline. The style follows the icon rules in
  `project-nihon-assets/STYLE.md`. `--check` and `--out DIR` work as in `gen_item_assets.py`.
- Window icons at `assets/icons/ui/window/<key>.png.raw` for every entry in `WindowDock`:
  inventory (bag), character (helmeted bust), skills (open book), crafting (hammer and anvil),
  technology (gear and flask), trade (two hands swapping), market (coin stack), map (globe),
  proposals (scroll and quill), settlement (house with a hearth), controls (keyboard).
- Skill icons at `assets/icons/skills/<Skill>.png.raw` for all 22 skills. Each one combines a
  category frame (combat, crafting, magic, exploration, social, survival) with a symbol for the
  skill (sword, bow, saw, anvil, rune, skinning knife…). The frames come from the fabric's
  category enum, so a new category without a frame fails `--check`. Today each skill file
  repeats its own copy of that enum, and 21 of the 22 copies lack `survival` (only
  `survival.js` has it). Define the enum once in `fabric/gameplay/skills/` and have every skill
  read it first.
- HUD icons for HP and each Phase 129 status effect. Attribute icons come later, in Phase 179,
  once Phase 177 has defined the attribute ids.
- The dock draws the icon with the shortcut letter as a small corner badge. The tooltip keeps the
  translated name. The skills window and the HUD status row use their icons.
- `assets/manifest.json` and `assets/README.md` list the new keys. The private repo gets a
  matching note (separate PR).

**Acceptance criteria:**
- [x] Every `WindowDock` entry, every skill in `GameData.SKILLS`, every status effect and HP has an
  icon at its key. No orphan icon exists.
- [x] Suite: every UI icon is 32×32 or 64×64 RGBA, has transparent corners and more than 40 opaque
  pixels, and no two are byte-identical.
- [x] Suite: a built dock button carries a texture and a badge with the shortcut letter, and no
  dock button's text is a bare letter.
- [x] CI: `python3 tools/gen_ui_icons.py --check` passes, and two runs are byte-identical.
- [x] Suite green on both boot paths.
