// Phase 248 — NativeWorldShape: the shared hash and noise, bound. See native_world_shape.h.
#include "native_world_shape.h"

#include "base/world_hash.h"

using namespace godot;

void NativeWorldShape::_bind_methods() {
	ClassDB::bind_method(D_METHOD("version"), &NativeWorldShape::version);
	ClassDB::bind_method(D_METHOD("functions"), &NativeWorldShape::functions);
	ClassDB::bind_method(D_METHOD("mix", "seed", "a", "b", "salt"), &NativeWorldShape::mix);
	ClassDB::bind_method(D_METHOD("noise", "seed", "x", "z", "w", "cells_x", "salt"), &NativeWorldShape::noise);
}

int NativeWorldShape::version() const {
	return 1;   // 1 = Phase 248: mix and noise
}

PackedStringArray NativeWorldShape::functions() const {
	PackedStringArray out;
	out.push_back("mix");
	out.push_back("noise");
	return out;
}

int64_t NativeWorldShape::mix(int64_t p_seed, int64_t p_a, int64_t p_b, int64_t p_salt) const {
	return nihon::shape_mix(p_seed, p_a, p_b, p_salt);
}

double NativeWorldShape::noise(int64_t p_seed, double p_x, double p_z, double p_w, int64_t p_cells_x, int64_t p_salt) const {
	if (p_cells_x <= 0) {
		return 0.0;   // GDScript would divide by zero; never reached by WorldShape's fixed cell counts
	}
	return nihon::shape_noise(p_seed, p_x, p_z, p_w, p_cells_x, p_salt);
}
