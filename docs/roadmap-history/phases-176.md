# Roadmap history — Phase 176

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 176 — An icon for everything a player can hold

**Goal:** all 27 items have icons since Phase 152, but materials (Soil, Thornwood, Ferrite…),
harvest goods (hides, meat, bones, sigils) and carcasses still fall back to `item_glyph`, which
paints their first letter. Every stack a player can hold should have a picture.

**Newel dependency:** NO.

**Depends on:** Phase 175 (shares the rasterizer).

**Deliverables:**
- `tools/gen_holdable_icons.py` (item icons stay in `gen_item_assets.py`) draws an icon for every material from its palette
  and form (block, ore chunk, log, sheaf, pile) and for every harvest and loot output from its
  kind (hide, meat, bone, trophy).
- One source of truth for "every id that can sit in a slot": items, materials, harvest outputs,
  loot outputs and carcasses. The suite and the generator both read it.
- The technology tree and the crafting rows show the icon of what they unlock or produce. The
  market and trade rows show it too.
- The public build never shows the glyph fallback. It remains only as a debug guard.

**Acceptance criteria:**
- [x] Suite: every holdable id has an icon at its key, and no orphan icon exists.
- [x] Suite: building the inventory, hotbar, character, crafting, technology, market and trade
  rows for a fixture holding every holdable id never calls `item_glyph`.
- [x] CI: the generator's `--check` passes, and two runs are byte-identical.
- [x] Suite green on both boot paths.
