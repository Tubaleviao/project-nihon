// Phase 248 — the seeded hash and value noise `WorldShape` uses (`WorldShape._mix`, `WorldShape._noise`),
// shared by every native class that samples the world's shape. Bit-exact with the GDScript; the
// `NativeWorldShape` class exposes both so the suite holds them to it (`native_tests.gd`).
#pragma once

#include "base/nihon_math.h"

#include <cmath>
#include <cstdint>

namespace nihon {

// `WorldShape._mix(seed, a, b, salt)`: a non-negative 31-bit hash.
inline int64_t shape_mix(int64_t seed_v, int64_t a, int64_t b, int64_t salt) {
	int64_t h = add(add(add(mul(seed_v, 6364136223846793005LL), mul(a, 2654435761LL)), mul(b, 2246822519LL)), mul(salt, 3266489917LL));
	h = mul(h ^ (h >> 29), -4658895280553007687LL);
	h = h ^ (h >> 32);
	return h & 0x7fffffff;
}

// `WorldShape._noise(seed, x, z, w, cells_x, salt)`: smoothed value noise on a grid of `cells_x` cells
// around a lap of `w` metres, wrapping east-west, in [0, 1].
inline double shape_noise(int64_t seed_v, double x, double z, double w, int64_t cells_x, int64_t salt) {
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
