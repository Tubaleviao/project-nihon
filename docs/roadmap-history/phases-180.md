# Roadmap history — Phase 180

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 180 — Character creation in the fabric: name, gender, hair and a chibi art style ✅ Done

**Goal:** a player never creates a character. They spawn with a default appearance and are known by
a handle. Model a small set of creation choices (name, gender, hair style, hair colour) so the
runtime screen in Phase 181 is generated from data, and set the character art style it uses.

**Newel dependency:** NO.

**Depends on:** Phase 177.

**Art direction:** characters are cute, chunky chibi figures in the spirit of Ragnarok Online:
a big head (about a third of the height), large expressive eyes, short limbs, big hands and boots,
and bold, chunky hair that carries most of the identity. They are our own designs, never copies:
no Ragnarok hair styles, outfits, palettes, names or proportions traced from it. Reference for the
mood: a 3D chibi novice in a plain leather outfit, framed alone on a dark, quiet backdrop.

**Deliverables:**
- `fabric/gameplay/characters/creation.js` (new): a `CharacterCreation` entity with:
  - name rules: 3–16 characters, Unicode letters from a single script (no Latin mixed with
    Cyrillic or Greek) plus a single inner space, hyphen or apostrophe, unique per server after
    case folding, accent folding and a confusables skeleton (Unicode TR39), so "Аlice" with a
    Cyrillic А collides with "Alice", and a reserved list;
  - gender: two options (masculine, feminine). Each maps to a fixed body preset in
    `appearances.js` (body, head, eyes, skin colour and chibi proportions), so the player does not
    pick those parts;
  - hair: a list of hair styles per gender and a curated hair colour list (palette indices);
  - a default creation (one gender, hair style and colour) and a starting kit per server rule
    (a plain novice outfit by default; no class kits, the sandbox has none).
  Attributes are not chosen at creation: every character starts at the Phase 177 base values.
- A `chibi` proportion preset in `appearances.js` (large `headScale`, short limbs) used by both
  gender presets, within the §8 bounds (widen the bounds if needed and say so in the bible).
- Public placeholders for both gender bodies, the novice outfit, at least six hair styles per
  gender and the hair colour list, at the same keys the private repo will fill (placeholder rule;
  `gen_placeholder_glb.py`). Each hair style also gets a UI icon (the picker grid shows hair, not
  names), drawn by `tools/gen_ui_icons.py`.
- `tools/check_creation.js`: every gender preset, hair style and colour refers to an existing
  part or palette index, each gender has at least one hair style, and the default is a valid
  creation.

**Acceptance criteria:**
- [x] `npm run validate`, `npm run check-drift` and `node tools/check_creation.js` pass.
- [x] Suite: every gender preset and hair option resolves through `AssetOverlay` in the public
  build, and every hair style has an icon.
- [x] Suite: the name rule accepts and rejects a fixture list, including accents, emoji, a
  reserved word, a case-folded duplicate and a mixed-script or confusable duplicate.
- [x] Suite: a creation with a hair style from the other gender, an unknown hair style or a hair
  colour outside the list is refused.
- [x] Suite: the default rig's head-to-height ratio is within the chibi preset range.

**Notes (as built):**
- `GameData.CREATIONS["CharacterCreation"]` (tag `creation`): `name` (the rule and its fold tables), `genders`,
  `hairStyles`, `hairColors`, `defaultCreation`, `startingKit`, `proportionPreset`, `headRatio` and `refusals`.
  `fabric/index.js` runs `validateCreation` at load, so a bad table fails `npm run validate`.
- Name rule: script groups are code point ranges (latin, greek, cyrillic, japanese; kana and kanji are one group).
  Godot has no NFD, so the accent fold table is built from the JS engine's NFD at generate time (plus ß, ø, æ,
  œ, þ…). The skeleton lower-cases first, then folds accents and drops combining marks, then maps confusables
  (lower-case Cyrillic and Greek look-alikes), drops separators and replaces "rn" → "m", "vv" → "w". Lower-casing
  first keeps "ВОВ" and "вов" on one skeleton. Edges are trimmed; a combining mark must follow a letter, at most `maxMarksPerLetter` (2) stack on one
  letter (no "Zalgo" names), and marks do not count toward the length. The reserved list is compared on skeletons.
- Runtime rules: `src/character/creation_rules.gd` (`name_refusal`, `skeleton`, `choice_refusal`,
  `creation_refusal`, `preset`, `head_ratio`). Refusal keys are `creation.refuse.<reason>`, gender labels
  `creation.gender.<id>`, in both locales.
- Gender presets are appearances `NoviceMasculine` and `NoviceFeminine` (body, head, eyes, skin, chibi
  proportions, the tunic worn). Chibi proportions: `headScale` 2.6, `legLength` 0.55, `armLength` 0.7, `height`
  0.8 (0.75 feminine), head ratio 0.34–0.35 against a 0.28–0.40 range. `CharacterSlice.BODY_PROP_BOUNDS` and
  characters.md §8 were widened (height ≥ 0.75, armLength ≥ 0.65, legLength ≥ 0.50, headScale ≤ 2.80).
- The starting kit is a new item, `NoviceTunic` (Chest, defense 1, Duskfiber, no recipe).
- Placeholders: `gen_placeholder_glb.py` writes `models/characters/bodies/chibi_body_{m,f}.glb.raw` (skinned to
  HumanoidSkeleton with every player clip), `models/characters/heads/chibi_head_{m,f}.glb.raw` and one
  `models/characters/hair/<id>.glb.raw` per style from its `shape`; `gen_placeholder.py` writes
  `textures/characters/eyes/chibi_eyes_{m,f}.png.raw` and the tunic sheets; `gen_ui_icons.py` writes
  `icons/hair/<id>.png.raw`. Six styles per gender, twelve colours (eight natural, four bold).
- `tools/check_creation.js` runs in CI; besides the data checks it requires a placeholder and a manifest entry for
  every preset part, hair style and kit item, and both catalog entries for every refusal and gender.
