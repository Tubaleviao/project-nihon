# Roadmap history — Phase 209

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 209 — Books and blueprints: research shared by writing ✅ Done

**Goal:** a technology is learnt by researching it or by reading a book about it. A structure or
station is learnt from a blueprint. Nothing is shared through a clan.

**Newel dependency:** NO.

**Depends on:** Phase 203.

**Deliverables:**
- Writing: a player who knows a technology or recipe writes a book or blueprint at a station, with
  the fabric's material cost. Reading teaches it and keeps the item, so it can be read again
  or lent.
- Research materials come from the researcher's own pack. The Phase 140 settlement stockpile source
  (`TechnologySlice.STOCKPILE_RESEARCH_HOLD`, which kept TechMasterForge on the stockpile after Phase 203
  removed `materialSource` from the fabric) is removed. The rules are `GameData.WRITINGS` (`Book`, `Blueprint`).

**Acceptance criteria:**
- [x] Suite: a player who reads a book unlocks its technology, and one who has not read it is
  unchanged. Writing about a technology the writer does not know is refused.
- [x] Suite: a blueprint teaches its recipe, and no research reads a shared stockpile.
- [x] Harness: a book handed to a client teaches the client, not the host's player.
- [x] Suite green on both boot paths, harness green.

**Shipped:**
- Fabric: `WRITING_ITEMS` in `gameplay/writing.js` names one written item per thing that can be written:
  `Book<Tech>` for each of the 7 technologies, `Blueprint<Recipe>` for the 4 station recipes (bed, chest,
  door, hearth) and `Blueprint<Project>` for the 4 settlement projects. The validator checks each list
  matches the fabric's technologies, station recipes and projects. `items/writings.js` defines the 15 items
  (stackable, `writing` / `teaches` / `teachesKind` fields, a tablet shape with its own rune per item), with
  placeholder models, icons and textures. A concrete item per content, not per-instance metadata, so trade,
  chests, drops and lending carry writings unchanged.
- `src/technology/writing_rules.gd` (pure reads of `GameData.WRITINGS` and the items) and `writing_slice.gd`
  (host): `write` checks that the writer knows the content (`TechnologySlice.knows`), stands within 8 m of the
  rule's station and holds the cost; it takes the cost and adds the item (refunded if the pack is full).
  `read` needs the item in the reader's pack and calls `TechnologySlice.learn`, which keeps the item. A book
  needs its technology's prerequisites (`prerequisite_locked`). Intents are rate-limited per player.
- `TechnologySlice.learn` unlocks a technology (with `technology_unlocked` and a `learnt` research result), or
  adds a recipe or project to the player's learnt set, which `is_recipe_unlocked` honours and the status
  snapshot carries under `_learnt` (bounded to known recipes and projects on load), so it persists and
  reaches the owner's client.
- Knowing a project, for writing its blueprint, means a learnt blueprint or being able to make every crafted
  material it needs. Starting a project is not gated by knowing it in this phase.
- Research takes materials from the researcher's pack only: `STOCKPILE_RESEARCH_HOLD`,
  `SettlementSlice.research_stock` / `consume_research` and the technology slice's settlement reference are gone.
- Network: `writing_intent` is forwarded by a client and bound to the sender's player on the host; results go
  back as keyed system lines. UI: a Read action on a writing in the pack, and a Writing section in the
  Technology window listing every writing the player can write with its cost and station.
- Harness step `book_teaches_client`: the host hands the client's player a book, the client reads it, the
  client's player learns the technology on both peers and the host's own player does not.
