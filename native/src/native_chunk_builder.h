#pragma once

#include <godot_cpp/classes/fast_noise_lite.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2i.hpp>

namespace godot {

// The GDScript chunk builder stays the reference; each phase ports one function here
// (167 heightmap_for, 168 build_runs, 169 build_chunk_arrays) and `functions()` lists what this
// build implements so the loader routes only those.
class NativeChunkBuilder : public RefCounted {
	GDCLASS(NativeChunkBuilder, RefCounted)

protected:
	static void _bind_methods();

public:
	// Bumped whenever a ported function changes behaviour.
	int version() const;
	// Names of the functions this build implements natively.
	PackedStringArray functions() const;

	// Phase 167. Port of `TerrainSlice.heightmap_for(pos, seed, noise)`: the 64x64 tile heights of
	// chunk `pos`, row-major, as an Array of floats. `cfg` carries what the GDScript side resolves
	// (see `TerrainSlice._native_cfg`): circumference_chunks, sea, min_height, max_height,
	// ridge_amplitude, spline, and `records` ({Vector2i cell: PackedFloat64Array corners} for
	// recorded cells the chunk reads). Thread-safe: no state is kept between calls.
	Array heightmap_for(const Vector2i &p_pos, int64_t p_seed, const Ref<FastNoiseLite> &p_noise, const Dictionary &p_cfg) const;
};

} // namespace godot
