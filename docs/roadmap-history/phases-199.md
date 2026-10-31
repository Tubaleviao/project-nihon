# Roadmap history — Phase 199

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 199 — Specialties at runtime: what each member is good at ✅ Done

**Goal:** each member gets a specialty from their skills and attributes. It shows on the roster
and makes their labour count for more on the project steps that match it, so a village gains from
members who do different things.

**Newel dependency:** NO.

**Depends on:** Phases 178 and 198.

**Deliverables:**
- `src/settlement/specialty_rules.gd`: pure scoring from the skill and attribute tables, ties
  broken in fabric order, and no specialty below the floor.
- The host recomputes a member's specialty when their skills or attributes change and syncs it to
  the settlement's members. Nothing is client-reported: the host reads its own skill and attribute
  records.
- Labour on a matching project step gets the fabric bonus.
- UI: the specialty on the roster and on the character sheet (Phase 179), with an icon from the
  Phase 175 generator.

**Acceptance criteria:**
- [x] Suite: fixture players with a high carpentry skill, a high combat skill and only base values
  get woodworker, hunter and no specialty; a tie resolves in fabric order.
- [x] Suite: a skill gain that changes the best score changes the specialty and emits one sync.
- [x] Suite: a matching specialty's labour adds the bonus, and a non-matching one adds the base.
- [x] Suite (audit): no specialty value is read from a client message.
- [x] Every new string is in both catalogs, and the i18n key check passes.
- [x] Suite green on both boot paths, harness green.
