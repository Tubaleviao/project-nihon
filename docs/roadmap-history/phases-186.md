# Roadmap history — Phase 186

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 186 — The first-steps tutorial at runtime: one-time cards, a toggle, and no other in-UI tutorial ✅ Done

**Goal:** show the Phase 184 steps to a new player as small cards that each appear once and never
come back after they are completed or dismissed. A player who knows the game switches the tutorial
off. Every other teaching text in the UI goes away, so the tutorial is the one place that teaches.

**Newel dependency:** NO.

**Depends on:** Phases 184 and 185.

**Deliverables:**
- `src/tutorial/tutorial_rules.gd`: pure functions over the step table: the next eligible step
  (all `requires` done, not done, not dismissed), whether an event completes the current step, and
  the progress per chapter.
- `src/tutorial/tutorial_slice.gd` + `tutorial_wiring.gd`: listen to the bus events the client
  already gets (movement, `inventory_synced`, crafting and station results, `creature_killed`,
  `bed_synced`, window opens…) and complete steps. The tutorial is client-side only: it sends
  nothing to the host and changes no game state.
- A card in a screen corner that does not block play: chapter, title, body with the player's own
  bound keys, a step counter, **Dismiss** (this step) and **Turn off tutorial**. A completed step
  shows a short check and moves on. At most one card is on screen.
- State in `user://settings.json` (beside the locale, Phase 131): `tutorial.enabled` and the sets
  of done and dismissed step ids. It is per player on this machine, not per world, so joining a new
  server does not replay the tutorial. A done or dismissed step is never shown again.
- A toggle and a **Restart tutorial** button in the `?` panel beside the language button. Turning it
  off hides the card at once and shows nothing until it is turned on again.
- On first launch with existing progress (a pre-186 player), steps whose condition is already true
  (they own a tool, a station, a bed, have a kill…) are marked done silently, so a veteran is not
  taught to walk.
- Remove every other in-UI tutorial. The instructional parts of these strings move into tutorial
  steps, and what stays only names the thing:
  - `hotbar.empty`, `hotbar.more`, and the "middle-click to place" / "press its key to use" tails of
    `hotbar.hint_block` and `hotbar.hint_skill`;
  - the skills window title and the skill tooltip's "drag onto the bottom bar" line
    (`ui.skills_title`, `ui.skill_tip`);
  - the always-on map hint bar (`map.hint`, `map.hint_tip`) and the "right-click to delete" tail of
    `map.delete_hint`;
  - the "click … to …" prompts in the trade window (`trade.none`, `trade.open`);
  - the "Press Enter to chat" chat placeholder (`chat.placeholder`).
  The `?` controls panel stays: it is a key reference, not a tutorial, and the only help left for a
  player who turned the tutorial off. Tooltips that state what a thing is (name, durability,
  quantity) stay.
- The playtest bot runs with the tutorial on and asserts that its existing steps (walk, gather,
  craft, place, fight…) complete the matching tutorial steps.

**Acceptance criteria:**
- [x] Suite: `tutorial_rules` returns steps in fabric order, respects `requires`, never returns a
  done or dismissed step, and returns nothing when the tutorial is off.
- [x] Suite: each Phase 184 trigger kind completes its step from a synthetic bus event, and an
  unrelated event completes nothing.
- [x] Suite: dismissed and done sets survive a save and reload of `user://settings.json` (a fixture
  path); a corrupt or missing file loads as "tutorial on, nothing done".
- [x] Suite: a fixture player with a tool, a station and a bed starts with those steps marked done.
- [x] Suite (audit): the removed keys are gone from both catalog columns, and no `locale/ui.csv` key
  outside `tutorial.*` and `controls.*` contains an instruction verb (click, right-click, drag,
  press, hold, scroll, and the `pt_BR` equivalents).
- [x] Suite (audit): the tutorial slice emits no bus intent and no network message.
- [x] Playtest bot: a `tutorial` check after `fight` reports the moving, gathering, first-tools,
  first-stations and first-hunt chapters complete and saves a screenshot of a card.
- [x] Every new string is in both catalogs, and the i18n key check passes.
- [x] Suite green on both boot paths.
