#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

// Phase 166 scaffold. The GDScript chunk builder stays the reference; later phases
// (167 heightmap_for, 168 build_runs, 169 build_chunk_arrays) add methods here one at a time.
class NativeChunkBuilder : public RefCounted {
	GDCLASS(NativeChunkBuilder, RefCounted)

protected:
	static void _bind_methods();

public:
	// Bumped whenever a ported function changes behaviour.
	int version() const;
	// Names of the functions this build implements natively. Empty in the scaffold.
	PackedStringArray functions() const;
};

} // namespace godot
