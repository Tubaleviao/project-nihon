#pragma once

// Phase 248 — the shared base of every native port: GDScript's arithmetic written as the engine does
// it (wrapping 64-bit integers, posmod/fposmod, lerpf, smoothstep) and the seeded hash and value noise
// `WorldShape` uses (`_mix`, `_noise`), bit-exact with GDScript. Header-only so any class includes it.

#include <godot_cpp/core/math.hpp>

#include <cmath>
#include <cstdint>

namespace nihon {

inline double lerpf(double a, double b, double t) {
	return a + (b - a) * t;
}

inline double smoothstep(double from, double to, double x) {
	if (godot::Math::is_equal_approx(from, to)) {
		return from;
	}
	double s = (x - from) / (to - from);
	s = s < 0.0 ? 0.0 : (s > 1.0 ? 1.0 : s);
	return s * s * (3.0 - 2.0 * s);
}

inline double fposmod(double x, double y) {
	double value = std::fmod(x, y);
	if ((value < 0 && y > 0) || (value > 0 && y < 0)) {
		value += y;
	}
	return value + 0.0;
}

inline int64_t posmod(int64_t a, int64_t b) {
	int64_t value = a % b;
	if ((value < 0 && b > 0) || (value > 0 && b < 0)) {
		value += b;
	}
	return value;
}

inline double clampf(double v, double lo, double hi) {
	return v < lo ? lo : (v > hi ? hi : v);
}

// 64-bit wrapping arithmetic.
inline int64_t mul(int64_t a, int64_t b) {
	return (int64_t)((uint64_t)a * (uint64_t)b);
}
inline int64_t add(int64_t a, int64_t b) {
	return (int64_t)((uint64_t)a + (uint64_t)b);
}

// `WorldShape._mix`: the seeded 64-bit hash, 31 bits out.
inline int64_t shape_mix(int64_t seed_v, int64_t a, int64_t b, int64_t salt) {
	int64_t h = add(add(add(mul(seed_v, 6364136223846793005LL), mul(a, 2654435761LL)), mul(b, 2246822519LL)), mul(salt, 3266489917LL));
	h = mul(h ^ (h >> 29), -4658895280553007687LL);
	h = h ^ (h >> 32);
	return h & 0x7fffffff;
}

// `WorldShape._noise`: smooth value noise in [0, 1], periodic in x over `cells_x` cells of width `w`.
inline double value_noise(int64_t seed_v, double x, double z, double w, int64_t cells_x, int64_t salt) {
	double cell = w / double(cells_x);
	double qx = x / cell;
	double qz = z / cell;
	int64_t ix = (int64_t)std::floor(qx);
	int64_t iz = (int64_t)std::floor(qz);
	double fx = qx - double(ix);
	double fz = qz - double(iz);
	fx = fx * fx * (3.0 - 2.0 * fx);
	fz = fz * fz * (3.0 - 2.0 * fz);
	int64_t x0 = posmod(ix, cells_x);
	int64_t x1 = posmod(ix + 1, cells_x);
	double v00 = double(shape_mix(seed_v, x0, iz, salt) % 10000) / 9999.0;
	double v10 = double(shape_mix(seed_v, x1, iz, salt) % 10000) / 9999.0;
	double v01 = double(shape_mix(seed_v, x0, iz + 1, salt) % 10000) / 9999.0;
	double v11 = double(shape_mix(seed_v, x1, iz + 1, salt) % 10000) / 9999.0;
	return lerpf(lerpf(v00, v10, fx), lerpf(v01, v11, fx), fz);
}

} // namespace nihon
