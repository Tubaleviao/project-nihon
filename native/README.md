# Native chunk builder (Phase 144, in progress)

GDExtension (C++, godot-cpp pinned to Godot 4.7) that will port `heightmap_for`, `build_runs`
and `build_chunk_arrays`. It registers the class `NihonChunkBuilder` with
`build_chunk(chunk_pos, heightmap, gathered, local) -> Dictionary`.

`src/terrain/native_builder.gd` is the loader: it uses the class when it exists and falls back
to the GDScript reference otherwise, logging `[Terrain] chunk builder: native|gdscript` once.
Binaries are never committed.

Status: loader + fallback landed; the C++ sources, parity tests and CI builds are still to do.
