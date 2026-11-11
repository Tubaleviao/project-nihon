# Native library (Phases 166, 248)

A GDExtension (`godot-cpp`) holding the game's native classes. The GDScript is always the reference and
the game runs without this extension: `src/core/native_loader.gd` loads it once when the binary for this
platform and build is present, checks each class on its own, and logs one line per class at boot:

```
[Native] chunk builder: native (version 8)
[Native] world shape: native (version 1)
```

or `gdscript fallback (no native extension | native version N is older than M; rebuild native/ | --no-native)`.

| Class | What it holds | Routed by |
|---|---|---|
| `NativeChunkBuilder` | `heightmap_for` (Phase 167), `build_runs` (168), `build_chunk_arrays` (169), `build_coarse_arrays` (190) | `src/terrain/native_builder.gd` (a thin view of the loader) |
| `NativeWorldShape` | `mix` and `noise`, the seeded hash and value noise of `WorldShape` (Phase 248) | the parity suite; later ports call the shared header directly |

## Build

```bash
tools/fetch_godot_cpp.sh                      # pinned godot-cpp checkout into native/godot-cpp
pip install scons                             # or pipx install scons
cd native && scons platform=linux target=template_debug     # the editor and the suite load this one
cd native && scons platform=linux target=template_release   # release exports load this one
```

Binaries land in `native/bin/` (gitignored; CI builds Linux, Windows and macOS universal and a `v*` tag
attaches them to a GitHub Release). The loader picks the `debug` or `release` library by
`OS.is_debug_build()`: the editor binary and debug exports load `template_debug`, release exports
`template_release`. A local run with a library older than `native/src` falls back (the log says so);
rebuild before measuring.

An export needs either every binary the preset's platform lists or none: to export without the
extension (the GDScript fallback), delete `native/nihon_native.gdextension` first, as the
`export-check` CI job does.

## The shared base (`src/base/`)

Every class uses these headers instead of its own copy, so a port is bit-exact with GDScript by
construction:

- `base/nihon_math.h` — GDScript's `lerpf`, `smoothstep`, `fposmod`, `posmod`, `clampf`; wrapping
  64-bit `mul` / `add` (GDScript ints wrap; signed overflow in C++ is undefined); `f32` for a value
  GDScript holds in a `Vector2` / `Vector3` / `Color` component (float32).
- `base/world_hash.h` — `shape_mix` and `shape_noise`, `WorldShape._mix` and `WorldShape._noise`.
- `base/marshal.h` — `is_number`, `read_numbers` (an Array of exactly n numbers into a
  `std::vector<double>`, false on anything else) and `to_packed` (one bulk copy into a Packed array).

Write a new helper here when a second class needs it, never a second copy in a `.cpp`.

## Adding a class

1. `src/native_<thing>.h` / `.cpp`: a `RefCounted` with `version()` (start at 1) and `functions()`
   (the names this build implements), stateless so any worker thread may call it.
2. Register it in `src/register_types.cpp` (`GDREGISTER_CLASS`).
3. Add it to `CLASSES` in `src/core/native_loader.gd`: its required version and its log label.
   Nothing else in the loader changes.
4. Call sites route per function:

   ```gdscript
   if NativeLoader.use_native("NativeThing", "do_it"):
       return NativeLoader.instance("NativeThing").call("do_it", a, b)
   return _do_it_gd(a, b)   # the reference
   ```

## Adding a function

1. Implement and bind it, add its name to `functions()`, bump `version()`.
2. Raise its class's `required` in `NativeLoader.CLASSES` to that version (with a line in the history
   comment) when the GDScript side now needs it: an older binary then falls back instead of computing
   something else.
3. Keep the GDScript reference (`<name>_gd`) and route through `use_native`.

## Its parity test

Every native function has a bit-exact parity test through the shared harness in
`src/tests/test_support.gd`:

```gdscript
var cases := [[seed, x, z], [seed, -x, z]]          # one argument list per call
assert_native_parity("NativeThing", "do_it", cases, Reference._do_it_gd)
# or pass the routed wrapper as `native` when the caller adds glue around the native call:
assert_native_parity("NativeThing", "do_it", cases, Reference._do_it_gd, Reference.do_it)
```

It compares with `==` (bit-exact floats, ordered arrays; a Dictionary's `==` ignores order, so wrap
the result as `[d.keys(), d]` when the order matters), reports the first mismatches one by one, and
skips with one log line when the function is not routed native in this run. CI runs the suite with
the binary (`--expect-native`, the `native-suite` job) and without it (`godot-tests`, `export-check`).
Cover the edge cases the reference branches on (the wrap seam, the poles, records, negative and
overflowing ints), not just random inputs.

## The release build

The `release-flight` CI job exports the Linux preset with `template_release` and plays the playtest
`flight` step once on it, report only. Its numbers sit beside the editor run's in
`docs/perf/playtest-baseline.md` (Phase 248), which Phase 239 starts from.
