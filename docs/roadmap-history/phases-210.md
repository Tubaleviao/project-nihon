# Roadmap history — Phase 210

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 210 — Clan tiers from buildings and material rarity ✅ Done

**Goal:** a clan rises in tier by owning more buildings of rarer materials, and falls when they are
dismantled or destroyed.

**Newel dependency:** NO.

**Depends on:** Phases 205 and 206.

**Deliverables:**
- The clan score from the structure index (every clan building wherever it stands, and its
  material rarity), recomputed incrementally when a clan structure is built, loses blocks or is destroyed.
- Tier changes are synced to members with a keyed notice. A tier gives nothing yet (clan skills
  come later, see Deferred).
- UI: the clan's tier and score on the roster.

**Acceptance criteria:**
- [x] Suite: adding a stone building raises a clan's score more than a wood one, wherever it stands,
  and crossing a threshold changes its tier once.
- [x] Suite: destroying the building that held a clan above a threshold drops its tier.
- [x] Suite (audit): no score or tier is read from a client message.
- [x] Suite green on both boot paths, harness green.

**Shipped:**
- `StructureRules.score_points(material)`: one block's base durability × `ClanTiers.rarityWeight[rarity]`, in
  whole points (score = points / `durabilityUnit`), so adding and taking blocks away never drifts.
- `StructureSlice` keeps each clan's points, changed by every block a clan structure gains or loses
  (`_add_cell` / `_remove_cell`, so placement, dismantling, destruction, collapse and settling all count),
  wherever the building stands. `flush_clan_scores` (run by the host's structure tick) sends each clan whose
  points moved over `GameBus.clan_score_changed`; after a load or `/regen world` it sends every clan, so one
  whose buildings are gone falls back. `recount_clan_scores` is the full recount the suite holds the running
  sums to.
- `ClanSlice.set_score` (host only) sets the score and the tier (`tier_for`: the highest `minScore` reached).
  A tier change tells the clan's online members once with `clan.rank_up.<tier>` / `clan.rank_down.<tier>`
  and pushes their views; a score change alone re-sends the roster at most once per `SKILL_PUSH_SEC`. The
  last tier is saved with the clan, so a load that scores the same tells no one again. A tier gives nothing.
- A member's view carries `tier` and `score`; the clan window shows them above the roster
  (`clan.standing`, `clan.rank.<tier>`, en and pt_BR).
- Suite: `clan tier:` tests in `structure_tests.gd` (stone over wood, far buildings count the same, a
  threshold crossed once, destruction and wear drop the tier, load and regen) and the audit (no clan intent,
  client slice or network path sets a score or tier).
