# Roadmap history — Phase 166

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 166 — Native builder scaffold: GDExtension, loader, fallback, CI binaries and releases

**Goal:** a chunk still costs a worker about 200 ms of GDScript (resolve + mesh arrays). Bigger
mountains and a wider view make that worse. This phase moves the per-tile loops to native code
before the world gets taller, without making the public build depend on a native binary.

**Split (decided 2026-10-17).** Phase 144 is split into four steps, each one a whole PR with a
working build: **166** scaffold, loader, fallback, CI binaries and releases; **167** `heightmap_for`;
**168** `build_runs`; **169** `build_chunk_arrays` and the speed target. Each is a full roadmap step
for the review rules: its PR closes every box in its own section. The optional compute-shader
heightmap path is Phase 170.

**Decisions that apply to Phases 166–169:**
- **Noise:** native code calls Godot's own `FastNoiseLite` through `godot-cpp` (a `Ref<FastNoiseLite>`
  configured exactly as the GDScript one). Do not vendor `FastNoiseLite.h`. Using the engine's class
  makes noise bit-exact by construction, so parity failures always point at the ported logic.
- **Binaries:** built by CI for Linux x86_64, Windows x86_64 and macOS universal. They are uploaded
  as workflow artifacts on every run and attached to a GitHub Release when a `v*` tag is pushed.
  Never committed to git or LFS. A platform without a binary runs the GDScript fallback.
- **macOS:** unsigned universal binary plus a macOS export preset. No signing or notarization (that
  needs an Apple developer account; tracked as a human issue if ever wanted).
- **Verification of non-Linux builds is CI's job.** The Windows and macOS binaries are proven by the
  PR's `windows-latest` / `macos-latest` CI jobs, not locally. A run on Linux builds and tests the
  Linux binary locally (`g++` is installed; get SCons with `pipx install scons`), pushes, and
  lets CI decide the other two. "Could not verify Windows/macOS here" is not a reason to skip or
  block: push and read the CI result.

**Newel dependency:** NO.

**Depends on:** Phase 142.

**Deliverables:**
- `native/` — a GDExtension (C++, `godot-cpp` pinned to the Godot 4.7 tag as a git submodule or a
  pinned CI checkout, SConstruct, `.gdextension` file). It exposes a `NativeChunkBuilder` class
  whose methods exist but are not yet used for any real chunk work (a `version()` call is enough).
- The GDScript builder stays the reference. A loader picks the native builder when the extension
  loads and falls back to GDScript otherwise, with one log line saying which is in use. A per-function
  switch lets later steps route one function at a time through native code.
- CI: a matrix job builds the extension on `ubuntu-latest` (Linux x86_64), `windows-latest` (Windows
  x86_64) and `macos-latest` (macOS universal), with a cache for `godot-cpp`. The binaries are
  uploaded as artifacts and bundled into the export builds (Linux, Windows, and a new macOS export
  preset).
- `.github/workflows/release.yml` (or a job in `ci.yml`) creates a GitHub Release on a `v*` tag and
  attaches the three binaries and the export builds.
- `.gitignore` keeps built binaries out of git.

**Acceptance criteria:**
- [x] CI: the three platform binaries build in the PR's CI run.
- [x] Suite: with the extension present the loader reports native; with it absent the loader reports
  the GDScript fallback and the game boots. Both paths are tested.
- [x] CI: an export without the binaries boots on the fallback.
- [x] A release workflow triggered by `v*` tags exists and passes `actionlint` in CI (pushing a real
  tag is not required).
- [x] Suite green on both boot paths, harness green.

**Implementation notes.** `godot-cpp` has no 4.7 tag, so it is pinned to `godot-4.5-stable` by `tools/fetch_godot_cpp.sh` (a CI checkout, cached) and the extension declares `compatibility_minimum = "4.5"`; it loads in 4.7. The loader is `src/terrain/native_builder.gd`; the suite runs with `--expect-fallback` (no binary) and, in the `native-suite` job, `--expect-native`. macOS binaries are `.dylib` files named in `native/nihon_native.gdextension`.
