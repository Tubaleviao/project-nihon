#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/vector3i.hpp>

namespace godot {

// Phase 245 — the native twin of `PlanetBake` (the planet bake) and `TerrainCsg` (the terrain CSG
// helper). Integer maths only: every function returns what the GDScript reference returns, byte for
// byte (`planet_bake_tests.gd` and `terrain_csg_tests.gd` hold them equal). Stateless: any thread may call.
class NativeBake : public RefCounted {
	GDCLASS(NativeBake, RefCounted)

protected:
	static void _bind_methods();

public:
	int version() const;
	PackedStringArray functions() const;

	// `PlanetBake.bake`.
	Dictionary bake(const PackedInt32Array &p_base, int64_t p_w, int64_t p_h, int64_t p_sea_mm, int64_t p_river_flow, int64_t p_talus_mm, bool p_hydraulic) const;

	// `PlanetBake.erode`.
	PackedInt32Array erode(const PackedInt32Array &p_base, int64_t p_w, int64_t p_h, int64_t p_sea_mm, int64_t p_talus_mm) const;
	// `PlanetBake.hydraulic`.
	PackedInt32Array hydraulic(const PackedInt32Array &p_base, int64_t p_w, int64_t p_h, int64_t p_sea_mm, int64_t p_river_flow) const;

	// `TerrainCsg` operations and the shapes the bake's carve uses.
	int64_t isqrt(int64_t p_n) const;
	int64_t smooth_union(int64_t p_a, int64_t p_b, int64_t p_k) const;
	int64_t smooth_intersection(int64_t p_a, int64_t p_b, int64_t p_k) const;
	int64_t smooth_subtract(int64_t p_a, int64_t p_b, int64_t p_k) const;
	int64_t disc(const Vector2i &p_p, const Vector2i &p_c, int64_t p_r) const;
	int64_t box2(const Vector2i &p_p, const Vector2i &p_c, const Vector2i &p_h) const;
	int64_t polyline(const Vector2i &p_p, const Array &p_pts, const Array &p_radii, int64_t p_k) const;
	int64_t sphere(const Vector3i &p_p, const Vector3i &p_c, int64_t p_r) const;
	int64_t cylinder(const Vector3i &p_p, const Vector3i &p_c, int64_t p_r, int64_t p_hh) const;
	int64_t box3(const Vector3i &p_p, const Vector3i &p_c, const Vector3i &p_h) const;
	int64_t capsule3(const Vector3i &p_p, const Vector3i &p_a, const Vector3i &p_b, int64_t p_r) const;
	int64_t capsule2(const Vector2i &p_p, const Vector2i &p_a, const Vector2i &p_b, int64_t p_r) const;
};

} // namespace godot
