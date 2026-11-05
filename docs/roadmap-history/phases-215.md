# Roadmap history — Phase 215

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 215 — Chibi body sheets: public placeholders, the colour mask bound to skin, and the novice outfit region ✅ Done

**Closes:** #559.

**Goal:** the private art repo can ship the chibi bodies' texture sheets. Today
`models/characters/bodies/chibi_body_{m,f}.glb.raw` exist in `assets/`, but their sheets do not, so
the placeholder rule forbids the art repo from adding them, and the game binds only the old
`textures/characters/player*` sheets to every rig.

**Newel dependency:** NO.

**Deliverables:**
- `tools/gen_placeholder.py` makes `assets/textures/characters/bodies/chibi_body_{m,f}.png.raw`,
  `chibi_body_{m,f}_color_mask.png.raw` and `chibi_body_{m,f}_channel.png.raw` (64×64; mask R/G/B =
  Primary/Secondary/Accent, channel R/G/B = Metal/Emission/Wear, as the `player*` sheets), listed under
  `textures` in `assets/manifest.json`.
- `CharacterSlice` picks the sheet set by the rig's body key (the gender's chibi body), falling back to
  the `player*` sheets for any body without its own, and binds them through
  `CharacterMaterial.bind_rig_textures`. Skin colour from the look is driven through the mask's skin
  channel, not a separate material.
- The novice outfit occupies a documented UV region of the sheet (`assets/README.md` and the
  characters bible section), so the art repo paints it in place.

**Acceptance criteria:**
- [x] Suite: every new key exists in `assets/`, is in `assets/manifest.json`, is 64×64 and decodes;
  the placeholder-rule audit passes.
- [x] Suite: a male and a female look bind their own body's `detail_tex`, `color_mask_tex` and
  `channel_tex`; a body key with no sheets binds the `player*` sheets.
- [x] Suite: changing a look's skin colour changes the material parameter the mask's skin channel
  reads, on both genders.
- [x] Suite green on both boot paths, harness green; the `--playtest-bot` character_sheet and create
  steps still pass.

**Done:** placeholders landed in #560; `CharacterSlice` binds per-body sheets through `CharacterMaterial.body_material`, with the `player*` fallback; the novice region is `CharacterMaterial.NOVICE_OUTFIT_REGION`, documented in `assets/README.md` and `characters.md`; tests in `creation_tests.gd`.
