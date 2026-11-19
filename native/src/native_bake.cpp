// Phase 245 — NativeChunkBuilder::planet_bake, the port of `PlanetBake.bake` after the base heights: thermal and
// hydraulic erosion, priority-flood fill, steepest descent, flow accumulation and river ids, all integer
// arithmetic. The GDScript (`src/terrain/planet_bake.gd`) is the reference; `_test_native_parity` in
// planet_bake_tests.gd compares the bytes.
#include "native_chunk_builder.h"

#include <godot_cpp/variant/packed_int32_array.hpp>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <functional>
#include <queue>
#include <vector>

using namespace godot;

namespace {

constexpr int TALUS = 12;
constexpr int RIVER_MIN_FLOW = 24;
constexpr int ERODE_SHIFT = 4;
constexpr int64_t KEY = int64_t(1) << 24;
const int NX[8] = { -1, 1, 0, 0, -1, 1, -1, 1 };
const int NZ[8] = { 0, 0, -1, 1, -1, -1, 1, 1 };

inline int nbr(int i, int k, int cols, int rows) {
	int x = i % cols, z = i / cols;
	int nz = z + NZ[k];
	if (nz < 0 || nz >= rows) {
		return -1;
	}
	int nx = ((x + NX[k]) % cols + cols) % cols;
	return nz * cols + nx;
}

int isqrt(int v) {
	if (v <= 0) {
		return 0;
	}
	int64_t r = (int64_t)std::sqrt((double)v);
	while (r * r > v) {
		r--;
	}
	while ((r + 1) * (r + 1) <= v) {
		r++;
	}
	return (int)r;
}

void thermal(std::vector<int> &h, int cols, int rows, int sea) {
	std::vector<int> delta(h.size(), 0);
	for (int i = 0; i < (int)h.size(); i++) {
		if (h[i] <= sea) {
			continue;
		}
		int best = -1;
		for (int k = 0; k < 8; k++) {
			int j = nbr(i, k, cols, rows);
			if (j >= 0 && (best < 0 || h[j] < h[best] || (h[j] == h[best] && j < best))) {
				best = j;
			}
		}
		if (best >= 0 && h[i] - h[best] > TALUS) {
			int t = (h[i] - h[best] - TALUS) >> 3;
			delta[i] -= t;
			delta[best] += t;
		}
	}
	for (int i = 0; i < (int)h.size(); i++) {
		h[i] = h[i] <= sea ? h[i] + delta[i] : std::max(h[i] + delta[i], sea + 1);
	}
}

std::vector<int> fill(const std::vector<int> &h, int cols, int rows, int sea) {
	int n = (int)h.size();
	std::vector<int> f(n, 0);
	std::vector<uint8_t> done(n, 0);
	std::priority_queue<int64_t, std::vector<int64_t>, std::greater<int64_t>> heap;
	bool any = false;
	for (int i = 0; i < n; i++) {
		if (h[i] <= sea) {
			f[i] = h[i];
			done[i] = 1;
			heap.push((int64_t)(h[i] + 40000) * KEY + i);
			any = true;
		}
	}
	if (!any) {
		int lo = 0;
		for (int i = 0; i < n; i++) {
			if (h[i] < h[lo]) {
				lo = i;
			}
		}
		f[lo] = h[lo];
		done[lo] = 1;
		heap.push((int64_t)(h[lo] + 40000) * KEY + lo);
	}
	while (!heap.empty()) {
		int c = (int)(heap.top() % KEY);
		heap.pop();
		for (int k = 0; k < 8; k++) {
			int j = nbr(c, k, cols, rows);
			if (j < 0 || done[j]) {
				continue;
			}
			done[j] = 1;
			f[j] = std::max(h[j], f[c] + 1);
			heap.push((int64_t)(f[j] + 40000) * KEY + j);
		}
	}
	return f;
}

struct Flow {
	std::vector<int> down, flow, order;
};

Flow flow_of(const std::vector<int> &f, int cols, int rows, int sea) {
	int n = (int)f.size();
	Flow r;
	r.down.assign(n, -1);
	r.flow.assign(n, 1);
	for (int i = 0; i < n; i++) {
		if (f[i] <= sea) {
			continue;
		}
		int best = -1;
		for (int k = 0; k < 8; k++) {
			int j = nbr(i, k, cols, rows);
			if (j >= 0 && f[j] < f[i] && (best < 0 || f[j] < f[best] || (f[j] == f[best] && j < best))) {
				best = j;
			}
		}
		r.down[i] = best;
	}
	std::vector<int64_t> keys(n);
	for (int i = 0; i < n; i++) {
		keys[i] = (int64_t)(f[i] + 40000) * KEY + i;
	}
	std::sort(keys.begin(), keys.end(), std::greater<int64_t>());
	r.order.resize(n);
	for (int q = 0; q < n; q++) {
		int i = (int)(keys[q] % KEY);
		r.order[q] = i;
		if (r.down[i] >= 0) {
			r.flow[r.down[i]] += r.flow[i];
		}
	}
	return r;
}

PackedInt32Array to_packed(const std::vector<int> &v) {
	PackedInt32Array out;
	out.resize((int64_t)v.size());
	for (size_t i = 0; i < v.size(); i++) {
		out.set((int64_t)i, v[i]);
	}
	return out;
}

} // namespace

Dictionary NativeChunkBuilder::planet_bake(const PackedInt32Array &p_heights, int64_t p_cols, int64_t p_rows, int64_t p_sea, int64_t p_passes) const {
	Dictionary out;
	int cols = (int)p_cols, rows = (int)p_rows, sea = (int)p_sea;
	if (cols <= 0 || rows <= 0 || p_heights.size() != (int64_t)cols * rows) {
		return out;
	}
	int n = cols * rows;
	std::vector<int> h(n);
	for (int i = 0; i < n; i++) {
		h[i] = p_heights[i];
	}
	for (int p = 0; p < p_passes; p++) {
		thermal(h, cols, rows, sea);
		std::vector<int> f = fill(h, cols, rows, sea);
		Flow fl = flow_of(f, cols, rows, sea);
		for (int i = 0; i < n; i++) {
			if (h[i] > sea && fl.flow[i] > 1) {
				h[i] = std::max(h[i] - (isqrt(fl.flow[i]) >> ERODE_SHIFT) - (fl.flow[i] >= RIVER_MIN_FLOW ? 1 : 0), sea + 1);
			}
		}
	}
	std::vector<int> f = fill(h, cols, rows, sea);
	Flow fr = flow_of(f, cols, rows, sea);
	std::vector<int> id(n, 0), best(n, 0), flags(n, 0);
	for (int q = 0; q < n; q++) {
		int i = fr.order[q];
		if (f[i] <= sea || fr.flow[i] < RIVER_MIN_FLOW) {
			continue;
		}
		if (id[i] == 0) {
			id[i] = (i % 65535) + 1;
		}
		int d = fr.down[i];
		if (d >= 0 && f[d] > sea && fr.flow[d] >= RIVER_MIN_FLOW && fr.flow[i] > best[d]) {
			best[d] = fr.flow[i];
			id[d] = id[i];
		}
	}
	for (int i = 0; i < n; i++) {
		int bits = 0;
		if (f[i] <= sea) {
			bits |= 4;
		} else if (f[i] > h[i]) {
			bits |= 1;
		}
		if (id[i] != 0) {
			bits |= 2;
		}
		flags[i] = bits;
	}
	out["height"] = to_packed(f);
	out["flow"] = to_packed(fr.flow);
	out["down"] = to_packed(fr.down);
	out["river"] = to_packed(id);
	out["flags"] = to_packed(flags);
	return out;
}
