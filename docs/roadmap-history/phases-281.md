## Phase 281 — Work you can see: chopping, mining, digging, building and dissecting animations

Owner's playtest, 2026-11-19: holding the work input on a tree plays no animation. `work_hold.gd` emits
`tree_chop_requested` and nothing animates; mining plays `attack_tool` once, when the block breaks; digging,
building (placing a block, station or structure piece, `WorkSkills.SINGLE_KINDS` `build`) and dissecting a
carcass (Phase 259 harvest) play nothing or the same generic `attack_tool`. Every kind of work should have its
own animation that reads as that work.

- Each kind of work has its own clip, each a distinct motion that reads at gameplay distance:
  - `chop`: a side swing from the shoulder into the trunk at chest height, both hands on the haft.
  - `mine`: an overhead two-handed swing that drives the pick down and forward into the face, a small recoil after.
  - `dig`: the shovel pushed into the ground with a foot on the blade, levered back and the load tossed aside.
  - `build`: a short hammering loop (two to three strikes) facing the placed piece, the off hand steadying it.
  - `dissect`: kneeling by the carcass, a cutting loop with the knife low and in front.
- Holds (chopping, mining, digging, dissecting) loop their clip with one strike per work tick; a single action
  (building, dismantling, repairing) plays its clip once (`build` for all three until art splits them). A rig
  without the clip falls back to `attack_tool`. The clip choice is a fabric table (work kind → clip, loop or
  once), not code.
- The strike frame lines up with the tick that applies the work: the clip's `impact` marker (assets A41 adds it;
  the fallback uses 40% of the clip) is the moment the tick's chips, sound (Phase 276 `chop`/`dig` events) and
  progress bar step happen on the client.
- The character turns to face the target when the work starts. Releasing the hold or walking away blends back to
  idle/locomotion within 0.2 s; the `dissect` kneel stands back up through the same blend.
- Other players see the work: the host already knows a hold is running or a piece was placed; it syncs a
  `working` state (kind, target) to peers in range, and their copies play the same clip.
- New clip keys `chop`, `mine`, `dig`, `build`, `dissect` get placeholder clips on the public `player_rig` first,
  each with the motion above in rough form (not a copy of `attack_tool`), so the public game shows the
  difference without the art. Art: assets A41.

**Done.** Fabric `WorkClips` (`fabric/gameplay/work_clips.js`, `tools/check_work_clips.js`), placeholder clips in `tools/gen_placeholder_glb.py`, `src/character/work_anim{,_wiring}.gd`, `work_anim` packet (`send_work_anim`), suite `work_anim_tests.gd`, net harness step `work_anim_synced`, playtest bot `mine`/`gather`/`place` clip checks.

**Acceptance criteria**
- `npm run validate` / `check-drift` pass with the work-clip table; the validator rejects a clip name not on the
  rig contract and a work kind with no clip.
- Suite: a chop hold on a tree plays `chop` on loop; a mining hold plays `mine`; a digging hold plays `dig`; a
  carcass hold plays `dissect`; placing a block plays `build` once; a rig without the clip plays `attack_tool`;
  releasing the hold stops the loop; the strike signal fires once per work tick at the marker time.
- Suite: the five placeholder clips are pairwise different (their right-hand bone tracks differ by more than
  10 cm at some sampled time) and none equals `attack_tool`; `dissect` lowers the hips by at least 30 cm.
- Net harness step: client B's copy of client A plays `chop` while A chops and `build` when A places a block.
- Playtest bot `gather`, `mine` and `place` steps record the clip that played during the work and fail if it was
  not that work's clip.
