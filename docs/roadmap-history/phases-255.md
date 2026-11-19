# Roadmap history — Phase 255

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 255 — The first release: `v0.1.0` from the release workflow ✅ Done

`release.yml` builds the native library on three platforms and attaches Linux, Windows and macOS
exports to a GitHub Release when a `v*` tag is pushed. It has never run: the repository has no tags.
Nobody but the owner has ever run a build, Phase 251 has nothing to hand a tester, and the
"public game must build and be fully playable without the submodule" rule has never been checked
by a player.

- A `CHANGELOG.md` with a `v0.1.0` entry (the arcs shipped, in a paragraph each) and a release
  checklist in `docs/DEVELOPMENT.md`: bump `config/version` in `project.godot`, write the changelog
  entry, tag, push, watch the workflow, smoke-test each download.
- `project.godot` gains `application/config/version` and the main menu shows it in a corner.
- The README's first screen gets a **Download** line pointing at the latest release, with the
  placeholder-art caveat.
- The release workflow runs the playtest bot's `create`, `walk` and `mine` steps against the Linux
  export under xvfb before publishing, so a broken export never becomes a release.
- Tag `v0.1.0` on the merge commit of this phase.

**Status (2026-11-13):** the version (`0.1.0`) and its menu label, `CHANGELOG.md` with `tools/check_changelog.sh` in
the `fabric` job, the release checklist, the README download line and the release workflow's dry run (manual or
on a PR touching anything a release depends on, with `create`, `walk` and `mine` played on the Linux export
through `tools/run_export_playtest.sh`, shared with CI's release-flight job) are in. Only the tag-only publish
job has a write token; the tag check runs before the native builds. 

**Done (2026-11-19):** `v0.1.0` tagged on `96992078` (main, CI green) and the release workflow published
[the release](https://github.com/Tubaleviao/project-nihon/releases/tag/v0.1.0) with the Linux, Windows and macOS
exports (plus the native libraries). The README download line points at `releases/latest`, which resolves to it.
The Linux export was downloaded and started headless with a production `assets.pck` beside it: the pack mounted
without an AssetOverlay warning.

**Acceptance criteria**
- A suite test reads `application/config/version` and asserts it parses as `major.minor.patch`.
- The release workflow has a `workflow_dispatch` dry run (no tag, no publish) that CI exercises on
  pull requests touching it, and it runs the three playtest steps on the export.
- `CHANGELOG.md` exists and a CI step fails when the version in `project.godot` has no entry.
- A GitHub Release `v0.1.0` exists with three assets; the README download link resolves to it.
