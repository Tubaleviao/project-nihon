// Phase 245 — NativeBake: the C++ twin of `src/terrain/planet_bake.gd` and `src/terrain/terrain_csg.gd`.
// The GDScript is the reference; every statement below follows it so the results are identical.
#include "native_bake.h"

#include <godot_cpp/variant/packed_int32_array.hpp>

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <set>
#include <vector>

using namespace godot;

namespace {

constexpr int DX[8] = { -1, 0, 1, -1, 1, -1, 0, 1 };
constexpr int DZ[8] = { -1, -1, -1, 0, 0, 1, 1, 1 };

int64_t key_of(int64_t height, int64_t index) {
	return height * 16777216 + index;   // `(height << 24) | index`, index < 2^24
}

int64_t isqrt_i(int64_t n) {
	if (n <= 0) {
		return 0;
	}
	int64_t x = int64_t(std::sqrt(double(n)));
	while (x * x > n) {
		x -= 1;
	}
	while ((x + 1) * (x + 1) <= n) {
		x += 1;
	}
	return x;
}

int64_t length2(int64_t x, int64_t y) {
	return isqrt_i(x * x + y * y);
}

// Floor division (GDScript `/` truncates toward zero).
int64_t fdiv(int64_t a, int64_t b) {
	int64_t q = a / b;
	if ((a % b != 0) && ((a < 0) != (b < 0))) {
		q -= 1;
	}
	return q;
}

int64_t smooth_union_i(int64_t a, int64_t b, int64_t k) {
	if (k <= 0) {
		return std::min(a, b);
	}
	int64_t d = std::llabs(a - b);
	if (d >= k) {
		return std::min(a, b);
	}
	int64_t t = k - d;
	return std::min(a, b) - (t * t) / (4 * k);
}

int64_t smooth_intersection_i(int64_t a, int64_t b, int64_t k) {
	if (k <= 0) {
		return std::max(a, b);
	}
	int64_t d = std::llabs(a - b);
	if (d >= k) {
		return std::max(a, b);
	}
	int64_t t = k - d;
	return std::max(a, b) + (t * t) / (4 * k);
}

int64_t seg_dist2(int64_t px, int64_t py, int64_t ax, int64_t ay, int64_t bx, int64_t by) {
	int64_t abx = bx - ax, aby = by - ay;
	int64_t apx = px - ax, apy = py - ay;
	int64_t len2 = abx * abx + aby * aby;
	int64_t dot = apx * abx + apy * aby;
	if (dot <= 0) {
		return length2(apx, apy);
	}
	if (dot >= len2) {
		return length2(px - bx, py - by);
	}
	int64_t cx = ax + fdiv(abx * dot, len2);
	int64_t cy = ay + fdiv(aby * dot, len2);
	return length2(px - cx, py - cy);
}

constexpr int ERODE_PASSES = 6;
constexpr int64_t ERODE_TALUS_MM = 2400;
constexpr int64_t ERODE_SHARE = 8;

// `PlanetBake.erode`.
PackedInt32Array erode(const PackedInt32Array &base, int64_t w, int64_t h, int64_t sea) {
	int64_t n = w * h;
	std::vector<int32_t> cur(n), delta(n);
	for (int64_t i = 0; i < n; i++) {
		cur[i] = base[i];
	}
	constexpr int KX[4] = { -1, 1, 0, 0 };
	constexpr int KZ[4] = { 0, 0, -1, 1 };
	for (int pass = 0; pass < ERODE_PASSES; pass++) {
		std::fill(delta.begin(), delta.end(), 0);
		for (int64_t z = 0; z < h; z++) {
			for (int64_t x = 0; x < w; x++) {
				int64_t i = z * w + x;
				if (cur[i] <= sea) {
					continue;
				}
				for (int k = 0; k < 4; k++) {
					int64_t nx = x + KX[k], nz = z + KZ[k];
					if (nx < 0 || nz < 0 || nx >= w || nz >= h) {
						continue;
					}
					int64_t j = nz * w + nx;
					if (cur[j] <= sea) {
						continue;
					}
					int64_t drop = int64_t(cur[i]) - cur[j];
					if (drop > ERODE_TALUS_MM) {
						int32_t amount = int32_t((drop - ERODE_TALUS_MM) / ERODE_SHARE);
						delta[i] -= amount;
						delta[j] += amount;
					}
				}
			}
		}
		for (int64_t i = 0; i < n; i++) {
			cur[i] += delta[i];
		}
	}
	PackedInt32Array out;
	out.resize(n);
	for (int64_t i = 0; i < n; i++) {
		out[i] = cur[i];
	}
	return out;
}

std::vector<int32_t> fill(const PackedInt32Array &base, int64_t w, int64_t h, int64_t sea) {
	int64_t n = w * h;
	std::vector<int32_t> out(n);
	std::vector<uint8_t> done(n, 0);
	for (int64_t i = 0; i < n; i++) {
		out[i] = base[i];
	}
	std::set<int64_t> heap;
	for (int64_t i = 0; i < n; i++) {
		int64_t x = i % w, z = i / w;
		if (base[i] <= sea || x == 0 || z == 0 || x == w - 1 || z == h - 1) {
			done[i] = 1;
			heap.insert(base[i] <= sea ? key_of(std::max<int64_t>(base[i], sea), i) : key_of(base[i], i));
		}
	}
	while (!heap.empty()) {
		int64_t key = *heap.begin();
		heap.erase(heap.begin());
		int64_t c = key & 0xFFFFFF;
		int64_t ch = key >> 24;
		int64_t cx = c % w, cz = c / w;
		for (int k = 0; k < 8; k++) {
			int64_t nx = cx + DX[k], nz = cz + DZ[k];
			if (nx < 0 || nz < 0 || nx >= w || nz >= h) {
				continue;
			}
			int64_t j = nz * w + nx;
			if (done[j] == 1) {
				continue;
			}
			done[j] = 1;
			if (out[j] <= ch) {
				out[j] = int32_t(ch + 1);
			}
			heap.insert(key_of(out[j], j));
		}
	}
	return out;
}

int64_t steepest(const std::vector<int32_t> &f, int64_t w, int64_t h, int64_t i, int64_t sea) {
	if (f[i] <= sea) {
		return -1;
	}
	int64_t x = i % w, z = i / w;
	int64_t best = -1, best_drop = 0;
	for (int k = 0; k < 8; k++) {
		int64_t nx = x + DX[k], nz = z + DZ[k];
		if (nx < 0 || nz < 0 || nx >= w || nz >= h) {
			continue;
		}
		int64_t j = nz * w + nx;
		int64_t den = (DX[k] != 0 && DZ[k] != 0) ? 1414 : 1000;
		int64_t drop = f[i] > f[j] ? ((int64_t(f[i]) - f[j]) * 1000 + den - 1) / den : 0;
		if (drop > best_drop) {
			best_drop = drop;
			best = j;
		}
	}
	return best;
}

} // namespace

void NativeBake::_bind_methods() {
	ClassDB::bind_method(D_METHOD("version"), &NativeBake::version);
	ClassDB::bind_method(D_METHOD("functions"), &NativeBake::functions);
	ClassDB::bind_method(D_METHOD("bake", "base", "w", "h", "sea_mm", "river_flow"), &NativeBake::bake);
	ClassDB::bind_method(D_METHOD("erode", "base", "w", "h", "sea_mm"), &NativeBake::erode);
	ClassDB::bind_method(D_METHOD("isqrt", "n"), &NativeBake::isqrt);
	ClassDB::bind_method(D_METHOD("smooth_union", "a", "b", "k"), &NativeBake::smooth_union);
	ClassDB::bind_method(D_METHOD("smooth_intersection", "a", "b", "k"), &NativeBake::smooth_intersection);
	ClassDB::bind_method(D_METHOD("smooth_subtract", "a", "b", "k"), &NativeBake::smooth_subtract);
	ClassDB::bind_method(D_METHOD("capsule2", "p", "a", "b", "r"), &NativeBake::capsule2);
}

int NativeBake::version() const {
	return 2;   // 1 = Phase 245: bake and the CSG operations; 2 = thermal erosion
}

PackedStringArray NativeBake::functions() const {
	PackedStringArray out;
	out.push_back("bake");
	out.push_back("erode");
	out.push_back("isqrt");
	out.push_back("smooth_union");
	out.push_back("smooth_intersection");
	out.push_back("smooth_subtract");
	out.push_back("capsule2");
	return out;
}

Dictionary NativeBake::bake(const PackedInt32Array &p_base, int64_t p_w, int64_t p_h, int64_t p_sea_mm, int64_t p_river_flow) const {
	int64_t n = p_w * p_h;
	std::vector<int32_t> filled = fill(erode(p_base, p_w, p_h, p_sea_mm), p_w, p_h, p_sea_mm);
	std::vector<int32_t> dir(n);
	for (int64_t i = 0; i < n; i++) {
		dir[i] = int32_t(steepest(filled, p_w, p_h, i, p_sea_mm));
	}
	std::vector<int64_t> order(n);
	for (int64_t i = 0; i < n; i++) {
		order[i] = key_of(filled[i], i);
	}
	std::sort(order.begin(), order.end());
	std::vector<int32_t> flow(n, 1);
	for (int64_t k = n - 1; k >= 0; k--) {
		int64_t c = order[k] & 0xFFFFFF;
		int32_t d = dir[c];
		if (d != -1) {
			flow[d] += flow[c];
		}
	}
	std::vector<int32_t> river(n, 0);
	for (int64_t i = 0; i < n; i++) {
		if (flow[i] < p_river_flow || filled[i] <= p_sea_mm) {
			continue;
		}
		int64_t c = i;
		while (dir[c] != -1 && filled[c] > p_sea_mm) {
			c = dir[c];
		}
		river[i] = int32_t(c + 1);
	}
	PackedInt32Array ph, pd, pf, pr;
	ph.resize(n);
	pd.resize(n);
	pf.resize(n);
	pr.resize(n);
	for (int64_t i = 0; i < n; i++) {
		ph[i] = filled[i];
		pd[i] = dir[i];
		pf[i] = flow[i];
		pr[i] = river[i];
	}
	Dictionary d;
	d["w"] = p_w;
	d["h"] = p_h;
	d["sea_mm"] = p_sea_mm;
	d["height"] = ph;
	d["dir"] = pd;
	d["flow"] = pf;
	d["river"] = pr;
	return d;
}

PackedInt32Array NativeBake::erode(const PackedInt32Array &p_base, int64_t p_w, int64_t p_h, int64_t p_sea_mm) const {
	return ::erode(p_base, p_w, p_h, p_sea_mm);
}

int64_t NativeBake::isqrt(int64_t p_n) const {
	return isqrt_i(p_n);
}

int64_t NativeBake::smooth_union(int64_t p_a, int64_t p_b, int64_t p_k) const {
	return smooth_union_i(p_a, p_b, p_k);
}

int64_t NativeBake::smooth_intersection(int64_t p_a, int64_t p_b, int64_t p_k) const {
	return smooth_intersection_i(p_a, p_b, p_k);
}

int64_t NativeBake::smooth_subtract(int64_t p_a, int64_t p_b, int64_t p_k) const {
	return smooth_intersection_i(p_a, -p_b, p_k);
}

int64_t NativeBake::capsule2(const Vector2i &p_p, const Vector2i &p_a, const Vector2i &p_b, int64_t p_r) const {
	if (p_a == p_b) {
		return length2(p_p.x - p_a.x, p_p.y - p_a.y) - p_r;
	}
	return seg_dist2(p_p.x, p_p.y, p_a.x, p_a.y, p_b.x, p_b.y) - p_r;
}
