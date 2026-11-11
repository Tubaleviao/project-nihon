# Native chunk builder (Phase 166)

A GDExtension (`godot-cpp`) holding `NativeChunkBuilder`. The GDScript builder is the reference and the
game runs without this extension: `src/terrain/native_builder.gd` picks native when the binary loads
and logs `[Native] chunk builder: native|gdscript fallback`.

```bash
tools/fetch_godot_cpp.sh                      # pinned godot-cpp checkout into native/godot-cpp
pip install scons                             # or pipx install scons
cd native && scons platform=linux target=template_debug
cd native && scons platform=linux target=template_release
```

Binaries land in `native/bin/` (gitignored; CI builds Linux, Windows and macOS universal and a `v*` tag
attaches them to a GitHub Release).

An export needs either every binary the preset's platform lists or none: to export without the
extension (the GDScript fallback), delete `native/nihon_native.gdextension` first, as the
`export-check` CI job does.

Ported so far: `heightmap_for` (Phase 167), `build_runs` (Phase 168), `build_chunk_arrays` (Phase 169) and `build_coarse_arrays` (Phase 190). `functions()` lists what a build
implements and the loader routes only those. `src/tests/suites/native_tests.gd` holds the bit-exact parity check against the
GDScript reference; it runs with `--expect-native` in CI and skips with one log line otherwise.

## The shared base (Phase 248)

Every native class builds on one base so a new port adds a class and a test, not a loader.

- `src/native_common.h` (header-only, namespace `nihon`): GDScript's arithmetic as the engine does it
  (`mul`/`add` wrapping 64-bit, `posmod`, `fposmod`, `lerpf`, `smoothstep`, `clampf`) and the seeded hash
  and value noise `WorldShape` uses (`shape_mix` = `_mix`, `value_noise` = `_noise`), bit-exact with
  GDScript. Include it instead of re-declaring helpers in an anonymous namespace.
- Every class is a `RefCounted` that reports `version()` (bump when a ported function changes behaviour)
  and `functions()` (the names this build implements). `NativeChunkBuilder` is the terrain builder;
  `NativeShape` batches the hash and noise (`mix_batch`, `noise_batch`) and is the parity target for the
  shared code.
- `src/core/native_loader.gd` is the one loader. It loads the extension once, vets every class in its
  `REQUIRED` table (class name -> oldest acceptable version) and answers `use_native(class, fn)`: true
  only when the extension loaded, the class is registered, its version is current and `functions()` lists
  `fn`. A class below its version, a missing class or an unlisted function runs the GDScript reference.
  `src/terrain/native_builder.gd` is the chunk builder's wrapper on top (its log line and `--no-native`).

### Adding a class, a function and its parity test

1. Write the C++ (`native/src/native_<name>.{h,cpp}`), include `native_common.h`, bind `version()` and
   `functions()`, and `GDREGISTER_CLASS` it in `register_types.cpp`. `SConstruct` globs `src/*.cpp`.
2. Add the class to `NativeLoader.REQUIRED` with its version.
3. Keep the GDScript implementation as the reference; at the call site, branch on
   `NativeLoader.use_native("NativeName", "function")`.
4. Add the parity test: `assert_native_parity(cls, fn, inputs, reference, native)` in
   `test_support.gd` runs both callables over the inputs, asserts identical results (`==`, floats
   bit-exact) and skips with one log line when the function is not native in that run. See
   `_test_native_shape_parity` in `src/tests/suites/native_tests.gd` (10,000 seeded samples).

### Release build

`release.yml` compiles `template_release` for the tagged binaries. CI's `release-export` job exports the
Linux preset with `--export-release` and the release library and plays the playtest `flight` step on the
exported binary once (report only; an export writes its report to `user://playtest`). Numbers:
`docs/perf/playtest-baseline.md`.
