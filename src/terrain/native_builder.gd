extends RefCounted
## Phase 144 — picks the chunk builder. The GDScript builder (`VoxelSlice`) is the reference; a
## GDExtension class `NihonChunkBuilder` (see `native/`) is used only when it loaded. Without the
## extension (no binary for the platform, public build) every call falls back to GDScript.

const NATIVE_CLASS := "NihonChunkBuilder"
const VoxelBuilder := preload("res://src/terrain/voxel_slice.gd")

static var _logged := false
## Test hook: forces the fallback even when the extension is loaded.
static var force_fallback := false

static func native_available() -> bool:
	return not force_fallback and ClassDB.class_exists(NATIVE_CLASS)

## "native" or "gdscript"; logs which builder is in use once per process.
static func backend() -> String:
	var name := "native" if native_available() else "gdscript"
	if not _logged:
		_logged = true
		print("[Terrain] chunk builder: %s" % name)
	return name

## Resolve + mesh one chunk. Same result as `build_chunk_arrays(build_runs(...))` in GDScript.
static func build_chunk(chunk_pos: Vector2i, heightmap: Array, gathered: Dictionary, local: bool = true) -> Dictionary:
	if backend() == "native":
		var b: Object = ClassDB.instantiate(NATIVE_CLASS)
		if b != null and b.has_method("build_chunk"):
			return b.call("build_chunk", chunk_pos, heightmap, gathered, local)
	return VoxelBuilder.build_chunk_arrays(chunk_pos, heightmap,
		VoxelBuilder.build_runs(chunk_pos, heightmap, gathered), local)
