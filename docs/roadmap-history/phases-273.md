## Phase 273 — Titles: professions unlock them, the player chooses one

Professions unlock by themselves from skill tiers (`locked → active → mastered` in the fabric,
several at once; the host stores them per player since Phase 118). Until Phase 271 puts them on the
wheel's rim no window shows them; this phase makes them the source of titles the player chooses to
show.

- **Fabric (separate PR, #663):** each profession names a title for `active` (for example "Blacksmith")
  and one for `mastered` ("Master Blacksmith"); each skill names a title for its master tier ("Master
  Smelter"); a built-in `Newcomer` title every character has from creation. Every title has a
  `title.<Id>.name` key in `locale/content.csv` (Phase 267); the validator rejects a title with no
  name in a locale and two sources that give the same title.
- **Unlock:** when the host records a profession transition or a skill reaching master, it adds the
  titles that unlocks to the player's unlocked set (durable in `player_registry.gd`, synced to its
  own player only) and sends a notice key the client shows as a toast ("New title: Master
  Smelter"); clicking it opens the title list.
- **Choosing:** the Character window lists the unlocked titles; the player picks one, or none. The
  request goes to the host, which refuses a title not in that player's unlocked set, stores the
  choice and syncs it to the peers that see that player, so it shows under the name on the nameplate
  and in the Character window. A new character wears `Newcomer` until they choose another.
- **Gates stay on professions:** recipe gates (`crafting_slice.gd` `_check_profession_gate`,
  `requires_profession:<id>`) keep checking unlocked professions, never the chosen title, so wearing
  a title never changes what a player can craft.

**Acceptance criteria**
- `npm run validate` and `check-drift` pass; the validator's self-check rejects a title with no
  `pt_BR` name and a duplicated title.
- Suite tests: a new character has exactly `Newcomer` unlocked and chosen; unlocking a profession and
  mastering a skill add their titles once and emit the toast; the host refuses a title that is not
  unlocked and accepts clearing it; the chosen title survives save and load; changing the title does
  not change a profession-gated recipe's result.
- Net harness step: a client chooses an unlocked title and the second client's nameplate shows it; a
  request for a locked title is refused.
- Every new string is in both locales.

**Done.** `fabric/gameplay/titles.js` (Titles table, validator, `tools/check_titles.js`), `src/character/title_rules.gd`
(pure rules), `title_wiring.gd` (host unlock + choose, client mirror), the record on `PlayerRegistry` (`titles`), the
title in the look so peers' nameplates show it (`TitleRules.nameplate`, in the viewer's locale), the title list in the
Character window and the "new title" toast (the toast text names the Character window; toasts are not clickable),
suite `title_tests.gd`, net harness step `title_choice`. A profession's `mastered` title is unlocked when every skill
of the profession reaches master (nothing else records that transition yet).
