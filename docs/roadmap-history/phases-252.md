# Roadmap history — Phase 252

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 252 — A licence and a contributor's front door ✅ Done

The README, `package.json` and the constitution call the project open-source, and the repository is
public, but there is no `LICENSE` file and GitHub reports no licence. By default that is "all rights
reserved": nobody may legally fork, build on or redistribute the code, and no contribution has a
licence to be accepted under. There is also no `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md` or
`SECURITY.md`, so the `CommunityOwnsTheFuture` principle has no door.

- **Licence** (the owner's choice; MIT or Apache-2.0 fit a code base that already vendors MIT and CC0
  work): `LICENSE` at the root, `"license"` in `package.json`, a licence line in the README, and
  `native/THIRD_PARTY.md` extended to the whole repository (`THIRD_PARTY.md` at the root: godot-cpp,
  the CC0 textures with their sources, any other borrowed code). The fabric, bible and wiki are
  covered by the same licence unless the owner chooses a documentation licence for them; the private
  `assets-prod/` submodule is not covered and the README says so.
- **Front door:** `CONTRIBUTING.md` (how to build, test and open a PR, pointing at
  `docs/DEVELOPMENT.md`; the fabric-first rule; the trust-boundary rule; the i18n rule),
  `CODE_OF_CONDUCT.md` and `SECURITY.md` (how to report a host exploit privately).
- **Branch protection on `main`:** pull requests only, the `fabric` and suite checks required. This
  is a repository setting, not a file, so it is filed as a GitHub issue for the owner and the phase
  records its number.

**Acceptance criteria**
- `LICENSE`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md` and `THIRD_PARTY.md` exist at
  the root; a CI step (`tools/check_front_door.sh`) fails when any is missing or empty, and when
  `package.json` has no `license` field or it differs from the `LICENSE` file's SPDX identifier.
- The README's first screen names the licence and links `CONTRIBUTING.md`.
- A GitHub issue asks the owner to enable branch protection; this phase records its number.

**Done (2026-11-12).** The licence is MIT (the roadmap offered MIT or Apache-2.0; the owner may still
change it, and `tools/check_front_door.sh` accepts either). The copyright line reads "Project Nihon
contributors". `tools/check_front_door.sh` has a `--self-test` that proves it rejects each missing
or empty file, a missing `license` field, a field that differs from the `LICENSE` text, and a
`LICENSE` it does not recognise; CI runs both in the `fabric` job. The five root files were added
to the light-CI path list, not to `paths-ignore`, so deleting one still runs the check. Branch
protection is issue #620.

