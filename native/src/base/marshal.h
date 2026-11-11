// Phase 248 — moving data between Variants and C++ containers, shared by every native port.
#pragma once

#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <algorithm>
#include <vector>

namespace nihon {

// True for a GDScript int or float.
inline bool is_number(const godot::Variant &v) {
	return v.get_type() == godot::Variant::FLOAT || v.get_type() == godot::Variant::INT;
}

// Read `a` (exactly `n` numbers) into `out`. False, with `out` unspecified, on a wrong size or a
// non-number: the caller rejects the input and the GDScript reference runs instead.
inline bool read_numbers(const godot::Array &a, int64_t n, std::vector<double> &out) {
	if (a.size() != n) {
		return false;
	}
	out.resize((size_t)n);
	for (int64_t i = 0; i < n; i++) {
		const godot::Variant &v = a[i];
		if (!is_number(v)) {
			return false;
		}
		out[(size_t)i] = double(v);
	}
	return true;
}

// One bulk copy into a Packed array: a push_back per element is an engine call each, and a chunk
// carries tens of thousands of vertices.
template <typename P, typename T>
P to_packed(const std::vector<T> &v) {
	P out;
	out.resize((int64_t)v.size());
	if (!v.empty()) {
		std::copy(v.begin(), v.end(), out.ptrw());
	}
	return out;
}

} // namespace nihon
