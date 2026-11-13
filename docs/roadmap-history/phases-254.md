# Roadmap history — Phase 254

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 254 — Repository hygiene: `.uid` files tracked, one lockfile, nothing stray ✅ Done

Found in the working tree on 2026-11-12: `.claude/` (600 MB, thirteen agent worktrees) not in
`.gitignore`, one `git add -A` from being committed; eight `.uid` files untracked and
`lod_rings_tests.gd` with none at all (Godot 4.4+ keys scripts by `.uid`, so an untracked one is
regenerated differently on every clone and the editor rewrites references); both `package-lock.json`
and `pnpm-lock.yaml` tracked while the README says `npm ci` and this file says `pnpm`; and the
`assets-prod` submodule pointer rewound three commits with modified content, which the next commit
touching it would publish as a regression.

- `.gitignore` gains `.claude/` and `*.uid` is never ignored.
- Every `.gd`, `.gdshader` and `.tscn` under `src/`, `godot/`, `tools/` and the root has its `.uid`
  tracked. A CI step (`tools/check_uids.sh`) lists tracked scripts without a tracked `.uid` and fails
  on any; the generator's `godot/` output includes its `.uid` files already and the check covers
  them too.
- One lockfile. The README and CI use `npm ci`, so `package-lock.json` stays and `pnpm-lock.yaml`
  goes; this file's gate names (`pnpm validate`, `pnpm check-drift`) become `npm run …`.
- The submodule pointer is set on purpose: either back to the commit `main` records or forward to
  the current head of `assets-prod` with the change named in the PR. `tools/check_submodule.sh`
  fails CI when the recorded pointer is not an ancestor-or-equal of the previous commit's, unless the
  PR title carries `assets-prod:`.

**Acceptance criteria**
- `tools/check_uids.sh` and `tools/check_submodule.sh` run in the `fabric` CI job; each has a fixture
  it rejects (an untracked `.uid`; a rewound pointer without the title marker).
- `git ls-files | grep -c lock` is 1 for the package manager's lockfile; `npm ci` succeeds in CI.
- `git check-ignore .claude` succeeds.

**Status (2026-11-13):** `.claude/` is ignored; the eleven scripts and shaders that lacked a `.uid` have one tracked
(`.tscn` files carry their uid in the header and have no sidecar, so `tools/check_uids.sh` checks `.gd` and
`.gdshader`); `pnpm-lock.yaml` is gone; `tools/check_uids.sh` and `tools/check_submodule.sh` (each with a
`--self-test` that rejects its fixture) run in the `fabric` CI job. The submodule pointer stays at the commit
`main` records. `check_submodule.sh` fails a moved pointer without the `assets-prod:` title marker, and,
where the submodule is checked out, a pointer that does not descend from the old one (CI has no submodule).
