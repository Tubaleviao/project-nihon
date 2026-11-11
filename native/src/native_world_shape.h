#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>

namespace godot {

// Phase 248 — the shared seeded hash and noise (`native/src/base/world_hash.h`) bound to GDScript, so
// the suite holds them bit-exact with `WorldShape._mix` / `WorldShape._noise`, and the second class
// the general loader (`src/core/native_loader.gd`) routes. Stateless: any thread may call it.
class NativeWorldShape : public RefCounted {
	GDCLASS(NativeWorldShape, RefCounted)

protected:
	static void _bind_methods();

public:
	// Bumped whenever a bound function changes behaviour.
	int version() const;
	// Names of the functions this build implements natively.
	PackedStringArray functions() const;

	// `WorldShape._mix(seed, a, b, salt)`.
	int64_t mix(int64_t p_seed, int64_t p_a, int64_t p_b, int64_t p_salt) const;
	// `WorldShape._noise(seed, x, z, w, cells_x, salt)`.
	double noise(int64_t p_seed, double p_x, double p_z, double p_w, int64_t p_cells_x, int64_t p_salt) const;
};

} // namespace godot
