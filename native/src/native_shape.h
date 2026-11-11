#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int64_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>

namespace godot {

// Phase 248. `WorldShape`'s seeded hash and value noise, batched, so the parity harness can compare
// native and GDScript on thousands of samples and later classes (the planet bake) share the code in
// `native_common.h`. Thread-safe: no state.
class NativeShape : public RefCounted {
	GDCLASS(NativeShape, RefCounted)

protected:
	static void _bind_methods();

public:
	int version() const;
	PackedStringArray functions() const;

	// `WorldShape._mix(seed, a[i], b[i], salt)` for each i (a and b must be the same length).
	PackedInt64Array mix_batch(int64_t p_seed, const PackedInt64Array &p_a, const PackedInt64Array &p_b, int64_t p_salt) const;
	// `WorldShape._noise(seed, x[i], z[i], w, cells_x, salt)` for each i.
	PackedFloat64Array noise_batch(int64_t p_seed, const PackedFloat64Array &p_x, const PackedFloat64Array &p_z, double p_w, int64_t p_cells_x, int64_t p_salt) const;
};

} // namespace godot
