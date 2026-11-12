// Phase 190 — NativeChunkBuilder::build_coarse_arrays, the port of `VoxelCoarse.build_coarse_arrays`: the
// coarse build of a chunk beyond the near ring. `coarse_columns` (native_runs.cpp) resolves one column per
// cell; Phase 241 meshes them smooth with `mesh_coarse_columns` (native_smooth.cpp), where the greedy
// column mesher used to be. The GDScript is the reference.
#include "native_chunk_builder.h"

#include <godot_cpp/variant/color.hpp>

using namespace godot;

Dictionary NativeChunkBuilder::build_coarse_arrays(const Vector2i &p_chunk, const Array &p_heightmap, const Dictionary &p_input, int64_t p_step, bool p_local, const Dictionary &p_cfg) const {
	Dictionary empty;
	Dictionary cols = coarse_columns(p_chunk, p_heightmap, p_input, p_step, p_cfg);
	if (cols.is_empty()) {
		return empty;
	}
	Variant fb = p_cfg.get("fallback_color", Variant());
	ERR_FAIL_COND_V(fb.get_type() != Variant::COLOR, empty);
	return mesh_coarse_columns(p_chunk, cols, p_step, p_local, fb);
}
