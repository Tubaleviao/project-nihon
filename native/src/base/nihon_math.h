// Phase 248 — the shared arithmetic every native port uses. Each function is written as the GDScript
// builtin it mirrors, so a port that calls these is bit-exact with the reference by construction.
#pragma once

#include <godot_cpp/core/math.hpp>

#include <cmath>
#include <cstdint>

namespace nihon {

// GDScript `lerpf`.
inline double lerpf(double a, double b, double t) {
	return a + (b - a) * t;
}

// GDScript `smoothstep`, including its `is_equal_approx` early-out.
inline double smoothstep(double from, double to, double x) {
	if (godot::Math::is_equal_approx(from, to)) {
		return from;
	}
	double s = (x - from) / (to - from);
	s = s < 0.0 ? 0.0 : (s > 1.0 ? 1.0 : s);
	return s * s * (3.0 - 2.0 * s);
}

// GDScript `fposmod` (the `+ 0.0` turns -0.0 into 0.0, as the engine does).
inline double fposmod(double x, double y) {
	double value = std::fmod(x, y);
	if ((value < 0 && y > 0) || (value > 0 && y < 0)) {
		value += y;
	}
	return value + 0.0;
}

// GDScript `posmod` on ints.
inline int64_t posmod(int64_t a, int64_t b) {
	int64_t value = a % b;
	if ((value < 0 && b > 0) || (value > 0 && b < 0)) {
		value += b;
	}
	return value;
}

// GDScript `clampf`.
inline double clampf(double v, double lo, double hi) {
	return v < lo ? lo : (v > hi ? hi : v);
}

// GDScript int arithmetic: 64-bit, wrapping on overflow (signed overflow is undefined in C++, so it
// goes through uint64_t). `>>` on int64_t is arithmetic on every compiler we build with, as in GDScript.
inline int64_t mul(int64_t a, int64_t b) {
	return (int64_t)((uint64_t)a * (uint64_t)b);
}
inline int64_t add(int64_t a, int64_t b) {
	return (int64_t)((uint64_t)a + (uint64_t)b);
}

// A value stored in a Vector2 / Vector3 / Color component: GDScript holds it as float32.
inline double f32(double v) {
	return (double)(float)v;
}

} // namespace nihon
