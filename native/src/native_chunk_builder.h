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
	// Phase 168. Port of `VoxelSlice.build_runs(chunk_pos, heightmap, input)` -> { runs, deposits }.
	// `cfg` carries the tables the GDScript side owns (see `VoxelSlice._native_runs_cfg`): the
	// circumference, material colours, biome host rocks and surface styles, the ore field's depth
	// bands and a callable for `OreField.vein_in_cell`. Thread-safe: no state between calls.
	Dictionary build_runs(const Vector2i &p_chunk, const Array &p_heightmap, const Dictionary &p_input, const Dictionary &p_cfg) const;

	// Phase 169. Port of `VoxelMesh.build_chunk_arrays(chunk_pos, heightmap, resolved, local)`: the
	// greedy mesher. `cfg` carries circumference_chunks and fallback_color. An input it cannot read
	// comes back as an empty Dictionary and the caller runs the GDScript reference. Thread-safe.
	Dictionary build_chunk_arrays(const Vector2i &p_chunk, const Array &p_heightmap, const Dictionary &p_resolved, bool p_local, const Dictionary &p_cfg) const;

	// Phase 240. Port of `VoxelSmooth.build_natural_arrays(chunk_pos, heightmap, resolved, local)`: the
	// surface-nets mesher over the natural runs (two-tile ring). `cfg` is `build_chunk_arrays`'s. Empty
	// on an input it cannot read; the caller then runs the GDScript reference. Thread-safe.
	Dictionary build_smooth_arrays(const Vector2i &p_chunk, const Array &p_heightmap, const Dictionary &p_resolved, bool p_local, const Dictionary &p_cfg) const;

	// Phase 190. Port of `VoxelCoarse.build_coarse_arrays(chunk_pos, heightmap, input, step, local)`: the
	// coarse build (one column per `step`x`step` tiles meshed smooth, skirts on the chunk edge, a conservative collision soup). `cfg` is the
	// `build_runs` cfg. Empty on an input it cannot read; the caller then runs the GDScript reference.
	Dictionary build_coarse_arrays(const Vector2i &p_chunk, const Array &p_heightmap, const Dictionary &p_input, int64_t p_step, bool p_local, const Dictionary &p_cfg) const;
	// Its first half, `VoxelCoarse.coarse_columns` (not bound): the resolved column of each cell.
	Dictionary coarse_columns(const Vector2i &p_chunk, const Array &p_heightmap, const Dictionary &p_input, int64_t p_step, const Dictionary &p_cfg) const;
	// Phase 241. Its second half, `VoxelSmooth.mesh_coarse_columns` (not bound, native_smooth.cpp): the
	// columns meshed smooth on the scaled grid, skirted to bedrock under the chunk's edge.
	Dictionary mesh_coarse_columns(const Vector2i &p_chunk, const Dictionary &p_cols, int64_t p_step, bool p_local, const Color &p_fallback) const;

	Array heightmap_for(const Vector2i &p_pos, int64_t p_seed, const Ref<FastNoiseLite> &p_noise, const Dictionary &p_cfg) const;
	// Phase 241 review. Port of `TerrainSlice.heightmap_strip_for_gd`: only the `depth` rows of chunk `pos`
	// along edge `side` (each component -1..1, 0 = every row/column), null elsewhere, uncarved like
	// `heightmap_for`. A coarse build's seam strips are 64 samples per neighbour, too slow in GDScript.
	Array heightmap_strip_for(const Vector2i &p_pos, const Vector2i &p_side, int64_t p_depth, int64_t p_seed, const Ref<FastNoiseLite> &p_noise, const Dictionary &p_cfg) const;

private:
	Array heightmap_range(const Vector2i &p_pos, int64_t p_seed, const Ref<FastNoiseLite> &p_noise, const Dictionary &p_cfg, int p_x0, int p_x1, int p_z0, int p_z1) const;
};

} // namespace godot
