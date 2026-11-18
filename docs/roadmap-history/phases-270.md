## Phase 270 — The technology tree: nodes, lines, zoom

- **Layout as a pure function:** a technology's column is the length of its longest prerequisite
  chain (fabric `requires`), and rows within a column are ordered to reduce crossings (barycentre
  passes). The same fabric gives the same layout, so it can be tested and cached.
- **Drawing:** each technology is a node with an icon, its localized name and state (researched,
  available, locked), and a line runs from each prerequisite to it, highlighted when the prerequisite
  is researched. Selecting a node shows its description, cost in research points and materials, time,
  the recipes it unlocks (icons) and a Research button when available.
- **Navigation:** mouse wheel and pinch zoom around the cursor (clamped), drag to pan, a button to fit
  the whole tree, and the view centres on the newest available technology when the window opens.
- Research requests stay host-checked as now.

**Acceptance criteria**
- Suite tests: every technology's column is greater than each prerequisite's; the layout is identical
  across two runs; each `requires` edge is drawn exactly once; zoom stays within its clamp and zooms
  around the cursor; a node's state follows the player's research.
- No node or panel shows an entity id (Phase 267 audit).
- Every new string is in both locales.

**Delivered.** `src/ui/tech_tree_layout.gd` lays the tree out as a pure function of the fabric's
`requires`: a technology's column is its longest prerequisite chain, rows start in id order and six
barycentre sweeps (down, then up) keep the ordering with the fewest crossings; `for_fabric()` caches the
result. `src/ui/zoom_canvas.gd` is the reusable canvas (Phase 271's wheel will extend it): wheel and pinch
zoom around the cursor within `[min_zoom, max_zoom]`, a drag or two-finger pan moves it, and `fit(rect)` /
`center_on(point)` frame it. `src/ui/tech_tree_view.gd` extends it with one node per technology (the icon of
what it unlocks, its `I18n.content` name and a localized state: researched, researching, available or
locked) and one line per `requires` edge, lit when the prerequisite is researched; it centres on the newest
available technology (the deepest one in the tree) when the window opens, and a toolbar button fits the
whole tree. Selecting a node fills a detail panel with its description, cost in research points and
materials, time, prerequisites, the recipes it unlocks (icons named in their tooltips) and, when it is
available, a Research button that sends the same host-checked request as before. The old one-line-per-tech
list and its `ui.tech_line` key are gone; the books-and-blueprints list stays below the tree.
`src/tests/suites/tech_tree_tests.gd` holds the criteria, including an entity-id audit over every node and
every node's detail panel in `en` and `pt_BR`.
