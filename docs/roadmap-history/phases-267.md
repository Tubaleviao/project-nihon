## Phase 267 — Names a player can read: localized names for items, recipes, technologies, skills and professions

The crafting and technology windows show entity ids ("RecipeAethermiteBow", "TechBasicSmithing") and
nothing in them is translated. Fabric content was deferred to Newel's catalog generator, which Newel's
roadmap no longer carries, so the game keeps its own content catalog instead.

- **A content catalog:** `locale/content.csv` with the same columns as `locale/ui.csv` (`en`,
  `pt_BR`), keyed by entity: `item.<Id>.name`, `item.<Id>.desc`, `recipe.<Id>.name` (falls back to
  its first output's name when absent), `tech.<Id>.name`, `tech.<Id>.desc`, `skill.<Id>.name`,
  `skill.<Id>.desc`, `profession.<Id>.name`, `station.<type>.name`. Adding a language stays a new column,
  no code change.
- **One lookup:** `I18n.content(kind, id, field)` returns the localized text, and in a debug build a
  visible `⟨id⟩` marker when the key is missing (never the bare id in a release build: the generic
  "Unknown" string instead). Every window that shows content (crafting, technology, skills, inventory
  tooltips, hotbar, chests, trade, toasts) goes through it.
- **A fabric gate:** `tools/check_content_locale.js` fails when a player-visible entity (every item,
  recipe, technology, skill, profession and placeable station in the fabric) has no name in every
  locale column, or the catalog holds a key for an entity that no longer exists. CI runs it.
- The Deferred entry "Localized fabric content" is replaced by this phase.

**Acceptance criteria**
- `node tools/check_content_locale.js` passes on the catalog and rejects a missing `pt_BR` name and a
  stale key (its own self-check, like the other `check_*.js`).
- Suite tests: every content key resolves in `en` and `pt_BR`; switching the locale changes a recipe's
  shown name; no label in the crafting, technology or skills window equals an entity id (an audit over
  each window's built tree).

**Delivered.** `locale/content.csv` names every item and material (creature drops included: any item id a
fabric table names), technology, skill, profession and placeable station in `en` and `pt_BR`, with
descriptions for items, technologies and skills; three potion recipes carry their own names and the rest
take their output's. `I18n.content(kind, id, field)` reads it (`⟨id⟩` in a debug build, "Unknown" in a
release build). Host notices that name content send `I18n.ref(kind, ids)` args and reason codes name their
station, profession or skill, so each client shows the names in its own locale. The `skill.<lowercase>` and
`station.carpentry_bench` keys moved from `ui.csv` to the content catalog. `tools/check_content_locale.js`
(CI step) proves it rejects a missing `pt_BR` name and a stale key; `content_locale_tests.gd` holds the
suite criteria and the window audit. The Deferred "Localized fabric content" entry had already left the
Deferred list when this phase was filed. Tree species in the chop prompt are not fabric entities and still
show their id.
