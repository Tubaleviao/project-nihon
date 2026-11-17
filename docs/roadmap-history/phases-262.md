## Phase 262 — Starting with nothing, and a tutorial that begins from bare hands

Depends on Phases 259–261 and 268 (stations are crafted before this rewrite).

- `CharacterCreation.startingKit` becomes empty. The `NoviceTunic` stays an item that can be made
  (a cheap fibre or hide recipe) but is not handed out; a new character wears the base body's
  plain clothes, which are part of the appearance, not an item, so nobody is shown naked and nothing
  is given.
- The tutorial (`fabric/gameplay/tutorial.js`) is rewritten to start from nothing: move, look, pick
  up a branch and a stone, open the inventory, craft a stone axe (the crafting window), chop a tree,
  craft a stone pick and shovel, dig soil, mine stone, then crafting and placing the first stations (Phase 268), bed, shelter,
  first hunt (with a stone knife for the harvest), map and the rest. Each step's card names the
  input and, where it helps, the place (for example "loose stones lie on the ground nearby").
- `_first_hour_items` (`tutorial_tests.gd`) starts from an empty kit plus what bare hands, loose
  items and the newcomer grounds give, and still reaches the bed, the first ferrite pick and the
  first weapon.
- Stress and playtest bots, which relied on the starting kit (`stress_clan_bots.gd`), gather or
  craft what they need first, or are given items through a test-only path that real play cannot
  reach.

**Acceptance criteria**
- `npm run validate` and `check-drift` pass; the creation validator accepts an empty kit.
- Suite tests: a new character's bag and equipment are empty; the first-hour reach test passes from
  an empty kit; every tutorial step's requirements name earlier steps (as now).
- The playtest `create` step asserts an empty bag, and the `tutorial` step completes the moving,
  gathering, first-tools, first-stations and first-hunt chapters from bare hands.

Done: `CharacterCreation.startingKit` is empty (the validator accepts that); the tutorial starts from bare hands (pick up a branch and a stone, craft a stone axe, chop, craft a pick and shovel, dig, mine, craft and place the bench and forge, craft a hammer and a knife); the suite and the playtest `create` step assert an empty bag.
