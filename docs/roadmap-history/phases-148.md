# Roadmap history — Phase 148

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 148 — Review follow-ups II: i18n leftovers

**Goal:** the i18n rule in the workspace CLAUDE.md says no hard-coded user-facing strings. Review
issues list several that are still there: settlement refusal strings, raw `reason` codes in the
craft, repair and research rows, the status-effect HUD line, coordinates formatted on the host, and
settlement names rendered in the host's locale. This phase moves all of them to keys and params.

**Newel dependency:** NO (item and creature *names* stay deferred under "Localized fabric content").

**Depends on:** none.

**Deliverables:**
- #374: `StationSlice.placement_blocker` returns reason codes ("inside a settlement claim", "too
  close to a settlement", "already in a settlement" become keys). A settlement's default name is
  stored as key + params and rendered on the client. Its number comes from a monotonic counter.
- #351: every `reason` code a slice can return to the UI has a catalog key in `en` and `pt_BR`.
  `UiSlice` renders the key and never the raw code. `I18n.ensure_loaded` logs one error when the
  catalog is missing or empty and stays unloaded so a later call retries. `fill` supports
  multi-digit placeholders. Chat lines carry numbers as params and the client formats them with
  its locale. Join lines are throttled per peer on reconnect.
- #346: `PlayerSlice.status_line` builds the HUD text from effect keys.
- A suite audit for hard-coded strings: no string literal is passed to a `Label.text`,
  `Button.text`, `tooltip_text` or a chat/notice emit in `src/` outside `I18n`, except entries on an
  explicit allow-list (debug-only overlays).

**Acceptance criteria:**
- [x] Suite: every reason code returned by `placement_blocker`, the craft, repair and research paths
  and the settlement paths has a key in every locale catalog.
- [x] Suite: with locale `pt_BR`, a chat line carrying the coordinates 1234.5 renders `1.234,5`; with
  `en`, it renders `1,234.5`.
- [x] Suite: `fill("{10} {1}", ...)` replaces both placeholders.
- [x] Suite: the hard-coded-string audit passes and fails on a fixture file that sets
  `label.text = "Hello"`.
- [x] Suite: catalogs have the same key set (existing check) after the new keys.
- [x] Every i18n item of #346, #351 and #374 is ticked on its issue.
- [x] Suite green on both boot paths, harness green.
