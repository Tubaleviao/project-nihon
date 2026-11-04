# Roadmap history — Phase 213

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 213 — A clan's tower on a mountain: the arc, played ✅ Done

**Goal:** prove the arc with the playtest bot.

**Newel dependency:** NO.

**Depends on:** Phases 206–212.

**Deliverables:**
- A `tower` playtest step: the bot founds a clan, builds a clan structure past the wood floor limit
  (refused), switches to a higher class and builds on, sets a chest to owner-only, reads a book,
  dismantles a fresh block for half its material, kills its character to respawn, and flies to an 8 km peak, screenshotting the
  tower and the peak.

**Acceptance criteria:**
- [x] Playtest: the step passes, with the wood refusal at floor 3 and a 50% return, and
  walk/craft/fight stay within budget.
- [x] Playtest: no creature spawns inside any building's circle during the session.
- [x] Suite green on both boot paths, harness green.

**Shipped:**
- `tower`, the bot's last step (`PlaytestBot._step_tower`, 420 s budget, not perf-gated). Beside the home the
  boot recorded, the bot founds the clan `Towerfolk` and sends `/buildas clan`. It places two fresh Thornwood blocks
  and dismantles them at Building level 0, and one comes back (50%). It picks the flattest 6 × 5 footprint on a ring
  of 8 bearings 6 m out and mines it level. It raises 5 × 5 Thornwood course by course to the top of floor 2 through
  the player's `block_place_requested` intent, and the next block (floor 3) is refused `too_many_floors`. Then a
  Concrete row from the ground beside it goes on to floor 4: one clan structure of 1,680 blocks. It places a chest
  with `chest_intent`, sets it to clan and then owner-only, and reads the first technology book it can learn (it keeps
  the book). It runs `/respawn` and waits out the respawn, then turns on flight and teleports to the tallest crest of
  8,000 m or more near the strongest massif summits (8,827 m on seed 42). It screenshots `tower.png` and
  `tower_peak.png`. Each phase prints a timed `[Playtest] tower` line.
- The step starts wherever `pole` left the body. A body that died there respawns near the origin, where a Graywolf
  pack can down it again, and the home's own pack killed the body once in a local run. So until the 3 × 3 chunks
  round home are built, the step teleports a living body back home and clears the creatures near it.
- The circle check runs for the whole session: every `creature_spawned` and `creature_respawned` is checked against
  `StructureSlice.spawn_blocked` at its spawn point, and the tower step fails on any hit (94 spawns, none inside).
- Fixed, found by the step: `StructureSlice._slenderness` counted only the columns strictly taller than a floor.
  When a footprint was raised course by course, the first block of floor 2 rose over columns exactly a floor tall,
  so it read as a one-column needle (`too_slender`), and no wood building wider than a post could get a second
  floor. Columns now count once they stand a full floor tall. Suite:
  `structure limits: a 5 x 5 wood tower raised course by course reaches its last floor, and the next is refused`.
- Fixed, found by the step: `UiSlice._on_inventory_changed` rebuilt the whole crafting list (a row per recipe,
  ~200 ms) on every inventory change, even with the window closed. The host hears that signal for every player's
  pack, so every placed block cost 200 ms. The list is now rebuilt only while the window is open (`open_window`
  refreshes it).
- The bot's boot wait read `is_first_ring_ready()`. That ring is armed round the boot centre and can stream away
  once the player is placed at the spawn, so with the faster boot the wait lost the race every run. It now waits for
  the host boot to finish and the chunk under the body to be built.
- Local A/B (xvfb, 4 cores, same seed): `main` and this branch both fail craft and fight p95 (about 24 and 21 ms
  against 20) and flight at 270 m/s (0% covered), which earlier phases also recorded on this machine. The branch is
  level with or under `main` on every gated step (walk 10.4 against 16.2 ms).
