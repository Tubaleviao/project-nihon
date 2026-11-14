# Phase 259 — Work takes time: bare hands, tools and a progress bar

Mining a span and chopping a tree each finish on one click, so nothing tells a player that a pick is
better than a fist, and a tree refuses bare hands outright (`tree_slice.gd` `chop_tree`,
`axe_required`). Every gathering action becomes timed work: held, shown as progress, and faster with
the right tool.

- **Fabric (separate PR):** a `WorkTimes` table. Each material has a `workSeconds` base (soil and
  sand low, host rock higher, ores by tier, each wood by tree). Each action (`dig`, `mine`, `chop`)
  names the tool class that suits it (`shovel` digs soil, `pick` mines rock and ore, `axe` chops).
  Each tool item gets a `workSpeed` per class it serves; bare hands are a fixed slow factor (about
  4× the base, tuned so the first stone tool feels like a real step). A tool of the wrong class
  counts as bare hands. Ores above a tier refuse bare hands and tools below it, as deep seams do
  today. A `tools/check_work_times.js` rejects a material with no time, a tool with no speed for its
  own class, and bare hands faster than any tool.
- **Bare hands chop:** a tree no longer refuses an empty hand; it takes the bare-hands time. The
  `axe_required` refusal is removed (its locale keys go with it).
- **Hold to work:** pressing the gather input on a target starts the work; holding it fills
  progress; releasing, turning to another target, leaving reach or being hit cancels it and the
  progress is lost. On completion the existing `mine_block` / `chop_tree` run unchanged. Holding on
  after a completion starts the next target under the crosshair, so digging a trench is one hold.
- **The host times it (trust boundary):** the client sends a work start (target, action); the host
  checks reach and the held tool, records the start tick and the duration it computed itself, and
  completes the work when that time has passed while the player still holds it. A completion the
  client claims early is never accepted; a cancel is accepted at any time. Start intents are
  rate-limited like other gather intents.
- **The progress bar:** a small radial bar around the crosshair (or a thin bar under it) fills over
  the duration, with the target's name and a rough time left (`~3 s`, through `I18n.t`). A fist,
  pick, axe or shovel icon shows which tool is being used. A crack overlay on the targeted block
  and a shake on the tree mark the same progress in the world, for other players too.
- Skills (Phase 207) are granted as before, on completion.

**Acceptance criteria**
- `npm run validate` and `check-drift` pass; `tools/check_work_times.js` passes its own bad tables.
- Suite tests: a work time is a pure function of (material, action, held tool); bare hands on soil,
  rock and wood are slower than every tool of the right class; a wrong-class tool equals bare hands.
- Suite tests: a tree is chopped bare-handed; the host refuses a completion before the duration,
  completes on time with the input held, and cancels on release, retarget and leaving reach,
  spending no durability on a cancel.
- Net harness step: a client holds work on a span and the host completes it once, at the host's
  time, with a forged early completion dropped.
- The playtest `mine` and `gather` steps hold work instead of clicking and still pass, and record
  the time each work took.
- Every new string is in both `en` and `pt_BR` in `locale/ui.csv`.
