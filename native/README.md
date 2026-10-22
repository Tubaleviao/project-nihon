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
