# Contributing to Project Nihon

Thank you for helping. Project Nihon is an open-source sandbox MMORPG, and its design is meant to
be owned by the people who build and play it. By taking part you agree to follow the
[Code of Conduct](CODE_OF_CONDUCT.md). Contributions are accepted under the project's
[MIT licence](LICENSE).

Report a security problem privately, as described in [SECURITY.md](SECURITY.md), not as an issue.

## Build, test and open a pull request

Everything about building, testing and the workflow is in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).
In short:

```bash
npm ci
npm run validate && npm run generate && npm run check-drift   # the fabric
GODOT=/path/to/Godot_v4.7-stable_linux.x86_64
$GODOT --headless --path . --quit -- --run-tests              # the unit suite
```

1. Pick an open phase in [ROADMAP.md](ROADMAP.md) (the priority order near the top says which is
   next) or an issue, and say so on it before you start.
2. Branch from `main`: `feat/<system>`, `fix/<area>`, `docs/<topic>` or `fabric/<topic>`.
3. Open a pull request titled `feat(<system>): <short description>`. CI must be green.

Acceptance criteria in the roadmap are decidable by the automated gates. A check that needs a person
playing the game becomes a GitHub issue rather than a criterion.

## Rules that every change follows

- **Fabric first.** A game system is designed in `fabric/` before any GDScript. Run
  `npm run generate` and commit the result. Never edit `godot/`, `bible/`, `wiki/`,
  `newel.ir-snapshot.json` or `newel.manifest.json` by hand. A fabric design change and its
  implementation are separate pull requests.
- **The host is the authority.** Never rely on the client to enforce a rule, and never trust
  client-reported state the host could check. Validate and rate-limit all network input on the host,
  scope syncs per owner, and bound memory. A review finding of this kind is fixed in the same pull
  request, not deferred.
- **Every player-facing string is translated.** Go through `I18n.t()` with keys in both the `en` and
  `pt_BR` columns of `locale/ui.csv`. Hosts send keys and parameters, never prose. Do not add
  hard-coded user-facing text.
- **Tests.** Each acceptance criterion gets a test in the matching `src/tests/suites/` file, and the
  suite must pass with no orphan nodes.
- **Placeholders.** The public game must build and play without the private `assets-prod/`
  submodule. Every production asset key has a placeholder in `assets/`.
- **Credit what you borrow.** Code, textures or other material from another source gets a row in
  [THIRD_PARTY.md](THIRD_PARTY.md) in the same pull request, and a compatible licence.

## Design decisions

Major design decisions follow the `CommunityOwnsTheFuture` principle: propose them publicly, and
they are ratified by contributor consensus. Open an issue describing the change before writing a
large fabric or gameplay pull request.
