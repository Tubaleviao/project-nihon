## Phase 289 — Hold to work, told and shown: the work bar in view, and the tutorial says hold

Owner's playtest, 2026-11-19: the chopping, digging and mining progress bar shows in the upper-left corner of the
game window, often cut in half, and the tutorial does not say the work input must be held until the work
finishes. The bar is built in `src/player/work_hold.gd` `_ready`: a zero-size `Control` calls
`set_anchors_preset(PRESET_CENTER)`, which moves the anchors but keeps the control where it was (offsets are
recomputed to keep its position, at the top-left), and the bar and label are placed at negative x offsets from
that point, so half of each is off screen.

- The work bar sits centred below the crosshair (about 12% of the screen height under it), clear of the hotbar,
  the minimap and the chat, at every window size and UI scale: the control is laid out with
  `set_anchors_and_offsets_preset(PRESET_CENTER)` (or a full-rect parent with a centred container), and it is
  re-placed when the viewport resizes.
- The bar is wider (220 px) and taller (12 px) with the label (material, seconds left, tool) above it, and it
  shows only while a hold runs.
- While a hold runs, the label adds "Keep holding <input>" (the input name from `InputLabels`, a param); if the
  hold is released before the end, a short "Released too early: hold until the bar fills" hint shows for 2 s.
  Both are new keys in `locale/ui.csv` with en and pt_BR text.
- The tutorial's work steps say to hold: `tutorial.chop.body`, `tutorial.dig.body`, `tutorial.mine_stone.body`
  (and any other step that asks for timed work, such as carcass work) state that the button must be held until
  the bar fills, naming the input through a param, not a literal. Both locales.

**Acceptance criteria**
- Suite: at viewport sizes 1280×720, 1920×1080 and 800×600 the work bar's global rect lies fully inside the
  viewport, horizontally centred (±2 px) and below the screen centre; after a viewport resize it stays inside.
- Suite: an early release shows the hint and it hides after 2 s (explicit time steps); a completed hold does not.
- Suite: the en and pt_BR texts of the chop, dig and mine tutorial steps contain the hold wording key's text
  (the steps reference a shared `tutorial.hold_hint` param or string); locale check passes.
- Playtest bot `mine` step screenshot is taken mid-hold and the step checks the bar's rect is inside the viewport.
