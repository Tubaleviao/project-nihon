# Roadmap history — Phase 248

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 248 — The native library base and a release build ✅ Done

`native/` holds one GDExtension class, `NativeChunkBuilder` (Phases 166–169, 190), and
`src/terrain/native_builder.gd` loads it and routes the functions its `functions()` lists. CI and
`release.yml` already compile `template_release` beside `template_debug`, but nothing runs or measures
a release export: the playtest and its budgets use the editor binary with the debug library. Phases
241 (smooth mesher), 245 (planet bake) and whatever Phase 249 adopts all add native code, so they
should share one base instead of each growing `NativeChunkBuilder`.

- **One base for every native port:** shared headers for fixed-point and integer arithmetic, the
  seeded hash and noise `WorldShape` uses (bit-exact with GDScript), and run/array marshalling, used
  by `NativeChunkBuilder` and every later class. Each native class reports `version()` and
  `functions()`.
- **One loader:** `native_builder.gd` becomes a general loader (`src/core/native_loader.gd` or
  equivalent) that loads the extension once, checks each class's required version and routes per
  function, so a new class needs no new loader. The chunk builder keeps its log line and fallback.
- **One parity harness:** `native_tests.gd`'s bit-exact GDScript-versus-native check becomes a helper
  any suite can call with a function name and a list of inputs.
- **Release build, measured:** a CI job exports a release Linux build with the release library and
  runs the playtest `flight` step once, report-only. The budget table (`docs/perf/playtest-baseline.md`)
  records the release numbers beside the editor ones. Phase 239 uses them.
- Document the base in `native/README.md` (how to add a class, a function and its parity test).

**Acceptance criteria**
- [x] The suite passes with and without the native extension (`--expect-native` in CI, fallback in the
  `export-check` job), and the chunk builder's parity tests run through the shared harness.
- [x] A suite test on the loader: a class below its required version, a missing class and a function not
  in `functions()` each fall back to GDScript; a present one routes native.
- [x] A parity test on the shared hash and noise: native and GDScript give identical values for 10,000
  seeded samples.
- [x] The CI release-export job runs the `flight` step and writes its numbers to the report;
  `docs/perf/playtest-baseline.md` has a release column.

**What shipped**

- `native/src/base/`: `nihon_math.h` (GDScript's `lerpf`, `smoothstep`, `fposmod`, `posmod`, `clampf`,
  wrapping `mul` / `add`, `f32`), `world_hash.h` (`shape_mix`, `shape_noise`: `WorldShape._mix` / `_noise`)
  and `marshal.h` (`is_number`, `read_numbers`, `to_packed`). The four `NativeChunkBuilder` sources
  dropped their private copies and use them; the refactored binary passed the old per-case parity tests
  before they moved to the harness.
- `NativeWorldShape` (version 1): `mix` and `noise` bound from the shared header, the second class the
  loader routes.
- `src/core/native_loader.gd`: loads the extension once, resolves every class in `CLASSES` (required
  version, log label) and routes per class and function (`use_native`, `instance`, `version`, `memo`).
  `src/terrain/native_builder.gd` is now a thin view of it for `NativeChunkBuilder`; its call sites and
  the `[Native] chunk builder: native|gdscript fallback` line are unchanged, and a `--no-native` run
  now says `(--no-native)`.
- `assert_native_parity(class, function, cases, reference, native?)` in `src/tests/test_support.gd`;
  the four chunk-builder parity tests use it.
- The release build: a "Linux Playtest" export preset (the `playtest` feature tag;
  `BootWiring.playtest_allowed`) because a release build ignores `--playtest-bot`, the `release-flight`
  CI job and `tools/flight_report.py`. The numbers are in `docs/perf/playtest-baseline.md` (Phase 248
  section): locally the release build attached 228 chunks at 2.66 ms each against the editor's 145 at
  4.46 ms.

Tests: `native_tests.gd` — the loader with stand-in classes (current, old, missing, unlisted function),
10,000-sample hash and noise parity, the CI job and preset wiring.
