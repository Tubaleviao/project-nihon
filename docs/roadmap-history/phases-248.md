## Phase 248 — The native library base and a release build

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
- The suite passes with and without the native extension (`--expect-native` in CI, fallback in the
  `export-check` job), and the chunk builder's parity tests run through the shared harness.
- A suite test on the loader: a class below its required version, a missing class and a function not
  in `functions()` each fall back to GDScript; a present one routes native.
- A parity test on the shared hash and noise: native and GDScript give identical values for 10,000
  seeded samples.
- The CI release-export job runs the `flight` step and writes its numbers to the report;
  `docs/perf/playtest-baseline.md` has a release column.

**Done:** `native/src/native_common.h` (namespace `nihon`) holds GDScript's wrapping 64-bit arithmetic,
`posmod`/`fposmod`/`lerpf`/`smoothstep`/`clampf` and `WorldShape`'s seeded hash and value noise
(`shape_mix`, `value_noise`); `NativeChunkBuilder` now uses them instead of its own copies. A second
class, `NativeShape` (`mix_batch`, `noise_batch`; version 1), reports `version()` and `functions()` and
is the parity target. `src/core/native_loader.gd` is the one loader (a `REQUIRED` class -> version table,
`use_native(class, fn)`); `NativeBuilder` is a thin wrapper keeping the chunk builder's log line and
`--no-native`. `assert_native_parity(cls, fn, inputs, reference, native)` in `test_support.gd` is the
shared parity helper. CI's `release-export` job exports the release Linux build with the release library
and plays `--playtest-only flight` on it once, report only (an exported build writes its report to
`user://playtest`, `PlaytestBot.out_dir()`); `docs/perf/playtest-baseline.md` has a "Release build"
section whose numbers come from that job's summary. `native/README.md` documents the base and how to add
a class, a function and its parity test. Tests: `src/tests/suites/native_tests.gd`
(`_test_native_loader_routing`, `_test_native_shape_parity`, `_test_native_parity_helper`,
`_test_native_release_export_job`).
