#include "native_shape.h"

#include "native_common.h"

using namespace godot;

void NativeShape::_bind_methods() {
	ClassDB::bind_method(D_METHOD("version"), &NativeShape::version);
	ClassDB::bind_method(D_METHOD("functions"), &NativeShape::functions);
	ClassDB::bind_method(D_METHOD("mix_batch", "seed", "a", "b", "salt"), &NativeShape::mix_batch);
	ClassDB::bind_method(D_METHOD("noise_batch", "seed", "x", "z", "w", "cells_x", "salt"), &NativeShape::noise_batch);
}

int NativeShape::version() const {
	return 1;
}

PackedStringArray NativeShape::functions() const {
	PackedStringArray out;
	out.push_back("mix_batch");
	out.push_back("noise_batch");
	return out;
}

PackedInt64Array NativeShape::mix_batch(int64_t p_seed, const PackedInt64Array &p_a, const PackedInt64Array &p_b, int64_t p_salt) const {
	PackedInt64Array out;
	ERR_FAIL_COND_V(p_a.size() != p_b.size(), out);
	out.resize(p_a.size());
	for (int64_t i = 0; i < p_a.size(); i++) {
		out.set(i, nihon::shape_mix(p_seed, p_a[i], p_b[i], p_salt));
	}
	return out;
}

PackedFloat64Array NativeShape::noise_batch(int64_t p_seed, const PackedFloat64Array &p_x, const PackedFloat64Array &p_z, double p_w, int64_t p_cells_x, int64_t p_salt) const {
	PackedFloat64Array out;
	ERR_FAIL_COND_V(p_x.size() != p_z.size() || p_cells_x <= 0 || p_w <= 0.0, out);
	out.resize(p_x.size());
	for (int64_t i = 0; i < p_x.size(); i++) {
		out.set(i, nihon::value_noise(p_seed, p_x[i], p_z[i], p_w, p_cells_x, p_salt));
	}
	return out;
}
