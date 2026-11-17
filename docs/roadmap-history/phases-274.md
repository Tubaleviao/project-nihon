## Phase 274 — Gathering: Mining, Woodcutting, Foraging and Skinning are their own skills

Today gathering raises crafting skills (`fabric/gameplay/work.js` `gather`): mined ore gives
Smithing, stone and soil give Building, wood gives Carpentry, plants give Alchemy. A player can
reach master Smithing without touching a forge, and nothing records that they are a miner. The
`survival` category holds one skill, Skinning.

- **Fabric (separate PR):** a `gathering` category replaces `survival` in `SKILL_CATEGORIES`
  (`skills/shared.js`) and in the attribute weights (`attributes.js` `categories`, today's
  `survival` weights move to it). Three new skills join Skinning in it: **Mining**, **Woodcutting**
  and **Foraging**, each with an XP curve in `SKILL_CURVES` and the shared `TIER_XP`. Skinning moves
  to the category unchanged. `skills/survival.js` becomes `skills/gathering.js`. `gathering` takes `survival`'s place (index 5)
  in the list, because skill resources load the category as an index.
- **Work goes by tool:** the `gather` rows become pick (`stone`, `metal`) and shovel (`soil`) →
  Mining, axe (`wood`) → Woodcutting, `plant` → Foraging, `carcass` → Skinning, with today's XP per
  unit. Crafting skills grow only from crafting (`craft` rows), and Building only from placing,
  dismantling and repairing. The XP curves of Smithing, Carpentry, Alchemy and Building are
  rebalanced in the same PR so their tiers are still reached in play, and the Phase 213 tower step
  still passes.
- **Each tier gives something** (Phase 271 needs a node per tier): Mining, Woodcutting and Foraging
  tiers lower that work's time (Phase 259, on top of the tool's speed) or raise its yield; the
  fabric names the bonus per tier.
- **No profession changes:** gathering skills name no profession, so profession unlocks and mastery
  (Phase 118, "all constituent skills at master") stay as they are, and on the wheel (Phase 271)
  they sit in the centre disc as skills anyone uses. Their master tiers give titles once Phase 273
  lands ("Master Miner").
- **Code reads the fabric:** `attribute_rules.gd`'s hard-coded `SKILL_CATEGORIES` is read from
  `GameData` instead, so a category change is data-only; the suite's copy
  (`attribute_tests.gd` `SKILL_CATEGORIES`) is read the same way. The village `forager` specialty
  (`settlement.js`) weighs Foraging instead of Tracking, Navigation and Alchemy.
- **Saves:** XP already earned stays in the skill it was earned in; no migration (the game is in
  playtest).
- New skill and category names have keys in both locales (Phase 267).
- Fishing and Farming will join this category with their systems (see Deferred).

**Acceptance criteria**
- `npm run validate` and `check-drift` pass; the validator rejects a skill whose category is not in
  `SKILL_CATEGORIES` and a `gather` row naming a skill outside `gathering`; its self-check proves
  both.
- Suite tests: mining stone, ore and soil grants Mining XP and no Building or Smithing XP; chopping
  grants Woodcutting, foraging grants Foraging, skinning grants Skinning; crafting still grants its
  crafting skill; a Mining tier lowers mining time as the fabric says; `attribute_rules.gd`'s
  categories equal the fabric's; a save with old Smithing XP loads with it unchanged.
- The playtest bot's mine, gather, craft and tower steps pass.
- Every new string is in both locales.

**Delivered.** The fabric and the runtime landed in one PR. `SKILL_CATEGORIES` ends in `gathering` (index 5,
where `survival` was), its attribute weights are `survival`'s, and `skills/gathering.js` holds Mining,
Woodcutting and Foraging (XP curves in `WorkSkills.curves`, the shared `TIER_XP`) beside an unchanged
Skinning. The `gather` rows grow Mining (stone, ore, soil), Woodcutting (wood), Foraging (plants) and Skinning
(carcasses) at the old XP per unit; to keep the crafting tiers reachable without gathering, the smithing,
carpentry and alchemy craft rows grant 12 XP (8 before), a placed block 2 Building XP (1 before), and
Building's level curve is 35 l² (50 l² before). `WorkSkills.bonuses` names what each tier gives: Mining
(mine, dig) and Woodcutting (chop) a work-speed factor of 1, 1.1, 1.2, 1.35 and 1.5 on top of the tool's,
Foraging a yield factor of 1, 1.15, 1.3, 1.5 and 1.75 (plants have no runtime gather action yet, so the
Foraging row is data until one exists). `WorkHost` times work with the worker's recorded tier from the
host's registry. `AttributeRules` reads the categories from `AttributeSystem.skillCategories`, and the suite
reads them the same way; the village `forager` specialty weighs Foraging alone. `tools/check_work.js` proves
the validator rejects a gather row naming a non-gathering skill, a skill whose category is not in
`SKILL_CATEGORIES`, a missing or flat tier bonus and a bonus on unknown work. Skill names and descriptions and
a `category.<id>.name` for every category are in `locale/content.csv` (en, pt_BR; `check_content_locale.js`
now requires the category names), and the three skills have icons (`gen_ui_icons.py`). The suite criteria are in
`gathering_skills_tests.gd`. Saves keep their XP where it was earned (no migration).
