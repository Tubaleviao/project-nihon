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

// floor(m * d / len2) without the product leaving int64 (see TerrainCsg._muldiv).
int64_t muldiv(int64_t m, int64_t d, int64_t len2) {
	int64_t d1 = d >> 20;
	int64_t d0 = d & 0xFFFFF;
	int64_t t = m * d1;
	int64_t qt = fdiv(t, len2);
	int64_t rt = t - qt * len2;
	return qt * 1048576 + fdiv(rt * 1048576 + m * d0, len2);
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
	int64_t cx = ax + muldiv(abx, dot, len2);
	int64_t cy = ay + muldiv(aby, dot, len2);
	return length2(px - cx, py - cy);
}

constexpr int ERODE_PASSES = 6;
constexpr int64_t ERODE_SHARE = 8;

// `PlanetBake.erode`.
PackedInt32Array erode(const PackedInt32Array &base, int64_t w, int64_t h, int64_t sea, int64_t talus, bool wrap) {
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
					if (wrap) {
						nx = ((nx % w) + w) % w;
					}
					if (nx < 0 || nz < 0 || nx >= w || nz >= h) {
						continue;
					}
					int64_t j = nz * w + nx;
					if (cur[j] <= sea) {
						continue;
					}
					int64_t drop = int64_t(cur[i]) - cur[j];
					if (drop > talus) {
						int32_t amount = int32_t((drop - talus) / ERODE_SHARE);
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

std::vector<int32_t> fill(const PackedInt32Array &base, int64_t w, int64_t h, int64_t sea, bool wrap) {
	int64_t n = w * h;
	std::vector<int32_t> out(n);
	std::vector<uint8_t> done(n, 0);
	for (int64_t i = 0; i < n; i++) {
		out[i] = base[i];
	}
	std::set<int64_t> heap;
	for (int64_t i = 0; i < n; i++) {
		int64_t x = i % w, z = i / w;
		if (base[i] <= sea || z == 0 || z == h - 1 || (!wrap && (x == 0 || x == w - 1))) {
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
			if (wrap) {
				nx = ((nx % w) + w) % w;
			}
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

int64_t steepest(const std::vector<int32_t> &f, int64_t w, int64_t h, int64_t i, int64_t sea, bool wrap) {
	if (f[i] <= sea) {
		return -1;
	}
	int64_t x = i % w, z = i / w;
	int64_t best = -1, best_drop = 0;
	for (int k = 0; k < 8; k++) {
		int64_t nx = x + DX[k], nz = z + DZ[k];
		if (wrap) {
			nx = ((nx % w) + w) % w;
		}
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

constexpr int HYDRO_PASSES = 4;
constexpr int64_t HYDRO_CUT_MM = 600;
constexpr int64_t HYDRO_MAX_CUT_MM = 6000;

// Flow accumulation: each cell counts itself and passes its count down its drain, highest cell first.
std::vector<int32_t> accumulate(const std::vector<int32_t> &f, const std::vector<int32_t> &dir) {
	int64_t n = int64_t(f.size());
	std::vector<int64_t> order(n);
	for (int64_t i = 0; i < n; i++) {
		order[i] = key_of(f[i], i);
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
	return flow;
}

// `PlanetBake.hydraulic`.
PackedInt32Array hydraulic(const PackedInt32Array &base, int64_t w, int64_t h, int64_t sea, int64_t river_flow, bool wrap) {
	int64_t n = w * h;
	std::vector<int32_t> cur(n);
	for (int64_t i = 0; i < n; i++) {
		cur[i] = base[i];
	}
	for (int pass = 0; pass < HYDRO_PASSES; pass++) {
		PackedInt32Array cur_arr;
		cur_arr.resize(n);
		for (int64_t i = 0; i < n; i++) {
			cur_arr[i] = cur[i];
		}
		std::vector<int32_t> f = fill(cur_arr, w, h, sea, wrap);
		std::vector<int32_t> dir(n);
		for (int64_t i = 0; i < n; i++) {
			dir[i] = int32_t(steepest(f, w, h, i, sea, wrap));
		}
		std::vector<int32_t> flow = accumulate(f, dir);
		std::vector<int32_t> next = cur;
		for (int64_t i = 0; i < n; i++) {
			int32_t d = dir[i];
			if (d == -1 || flow[i] < river_flow || cur[i] <= sea) {
				continue;
			}
			int64_t floor_mm = std::max<int64_t>(int64_t(cur[d]) + 1, sea + 1);
			int64_t cut = std::min<int64_t>(HYDRO_CUT_MM * flow[i] / river_flow, HYDRO_MAX_CUT_MM);
			cut = std::min<int64_t>(cut, int64_t(cur[i]) - floor_mm);
			if (cut > 0) {
				next[i] = int32_t(cur[i] - cut);
			}
		}
		cur = next;
	}
	PackedInt32Array out;
	out.resize(n);
	for (int64_t i = 0; i < n; i++) {
		out[i] = cur[i];
	}
	return out;
}

int64_t length3(int64_t x, int64_t y, int64_t z) {
	return isqrt_i(x * x + y * y + z * z);
}

int64_t capsule2_i(const Vector2i &p, const Vector2i &a, const Vector2i &b, int64_t r) {
	if (a == b) {
		return length2(p.x - a.x, p.y - a.y) - r;
	}
	return seg_dist2(p.x, p.y, a.x, a.y, b.x, b.y) - r;
}

} // namespace

void NativeBake::_bind_methods() {
	ClassDB::bind_method(D_METHOD("disc", "p", "c", "r"), &NativeBake::disc);
	ClassDB::bind_method(D_METHOD("box2", "p", "c", "h"), &NativeBake::box2);
	ClassDB::bind_method(D_METHOD("polyline", "p", "pts", "radii", "k"), &NativeBake::polyline);
	ClassDB::bind_method(D_METHOD("sphere", "p", "c", "r"), &NativeBake::sphere);
	ClassDB::bind_method(D_METHOD("cylinder", "p", "c", "r", "hh"), &NativeBake::cylinder);
	ClassDB::bind_method(D_METHOD("box3", "p", "c", "h"), &NativeBake::box3);
	ClassDB::bind_method(D_METHOD("capsule3", "p", "a", "b", "r"), &NativeBake::capsule3);
	ClassDB::bind_method(D_METHOD("version"), &NativeBake::version);
	ClassDB::bind_method(D_METHOD("functions"), &NativeBake::functions);
	ClassDB::bind_method(D_METHOD("bake", "base", "w", "h", "sea_mm", "river_flow", "talus_mm", "hydraulic", "wrap"), &NativeBake::bake, DEFVAL(false));
	ClassDB::bind_method(D_METHOD("erode", "base", "w", "h", "sea_mm", "talus_mm", "wrap"), &NativeBake::erode, DEFVAL(false));
	ClassDB::bind_method(D_METHOD("hydraulic", "base", "w", "h", "sea_mm", "river_flow", "wrap"), &NativeBake::hydraulic, DEFVAL(false));
	ClassDB::bind_method(D_METHOD("cut_cells", "op", "columns"), &NativeBake::cut_cells);
	ClassDB::bind_method(D_METHOD("isqrt", "n"), &NativeBake::isqrt);
	ClassDB::bind_method(D_METHOD("smooth_union", "a", "b", "k"), &NativeBake::smooth_union);
	ClassDB::bind_method(D_METHOD("smooth_intersection", "a", "b", "k"), &NativeBake::smooth_intersection);
	ClassDB::bind_method(D_METHOD("smooth_subtract", "a", "b", "k"), &NativeBake::smooth_subtract);
	ClassDB::bind_method(D_METHOD("capsule2", "p", "a", "b", "r"), &NativeBake::capsule2);
}

int NativeBake::version() const {
	return 8;   // 8 = Phase 300 `cut_cells` (the dig brush rasteriser);  1 = Phase 245: bake and the CSG operations; 2 = thermal erosion; 3 = every CSG shape; 4 = hydraulic erosion (Phase 302); 5 = thermal talus 500 m per cell; 6 = the bake profile (talus, hydraulic on/off) as parameters, so a worldgen-14 world bakes its Phase 245 bytes; 7 = the east-west wrap (Phase 232) as a parameter
}

PackedStringArray NativeBake::functions() const {
	PackedStringArray out;
	out.push_back("bake");
	out.push_back("erode");
	out.push_back("hydraulic");
	out.push_back("isqrt");
	out.push_back("smooth_union");
	out.push_back("smooth_intersection");
	out.push_back("smooth_subtract");
	out.push_back("capsule2");
	out.push_back("cut_cells");
	for (const char *f : { "disc", "box2", "polyline", "sphere", "cylinder", "box3", "capsule3" }) {
		out.push_back(f);
	}
	return out;
}

Dictionary NativeBake::bake(const PackedInt32Array &p_base, int64_t p_w, int64_t p_h, int64_t p_sea_mm, int64_t p_river_flow, int64_t p_talus_mm, bool p_hydraulic, bool p_wrap) const {
	int64_t n = p_w * p_h;
	PackedInt32Array eroded = ::erode(p_base, p_w, p_h, p_sea_mm, p_talus_mm, p_wrap);
	std::vector<int32_t> filled = fill(p_hydraulic ? ::hydraulic(eroded, p_w, p_h, p_sea_mm, p_river_flow, p_wrap) : eroded, p_w, p_h, p_sea_mm, p_wrap);
	std::vector<int32_t> dir(n);
	for (int64_t i = 0; i < n; i++) {
		dir[i] = int32_t(steepest(filled, p_w, p_h, i, p_sea_mm, p_wrap));
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

PackedInt32Array NativeBake::erode(const PackedInt32Array &p_base, int64_t p_w, int64_t p_h, int64_t p_sea_mm, int64_t p_talus_mm, bool p_wrap) const {
	return ::erode(p_base, p_w, p_h, p_sea_mm, p_talus_mm, p_wrap);
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

int64_t NativeBake::disc(const Vector2i &p_p, const Vector2i &p_c, int64_t p_r) const {
	return length2(int64_t(p_p.x) - p_c.x, int64_t(p_p.y) - p_c.y) - p_r;
}

int64_t NativeBake::box2(const Vector2i &p_p, const Vector2i &p_c, const Vector2i &p_h) const {
	int64_t qx = std::llabs(int64_t(p_p.x) - p_c.x) - p_h.x;
	int64_t qy = std::llabs(int64_t(p_p.y) - p_c.y) - p_h.y;
	return length2(std::max<int64_t>(qx, 0), std::max<int64_t>(qy, 0)) + std::min<int64_t>(std::max(qx, qy), 0);
}

int64_t NativeBake::polyline(const Vector2i &p_p, const Array &p_pts, const Array &p_radii, int64_t p_k) const {
	int64_t best = int64_t(1) << 40;
	for (int64_t i = 0; i + 1 < p_pts.size(); i++) {
		int64_t d = capsule2_i(p_p, p_pts[i], p_pts[i + 1], int64_t(p_radii[i]));
		best = i == 0 ? d : smooth_union_i(best, d, p_k);
	}
	return best;
}

int64_t NativeBake::sphere(const Vector3i &p_p, const Vector3i &p_c, int64_t p_r) const {
	return length3(int64_t(p_p.x) - p_c.x, int64_t(p_p.y) - p_c.y, int64_t(p_p.z) - p_c.z) - p_r;
}

int64_t NativeBake::cylinder(const Vector3i &p_p, const Vector3i &p_c, int64_t p_r, int64_t p_hh) const {
	int64_t dx = length2(int64_t(p_p.x) - p_c.x, int64_t(p_p.z) - p_c.z) - p_r;
	int64_t dy = std::llabs(int64_t(p_p.y) - p_c.y) - p_hh;
	return length2(std::max<int64_t>(dx, 0), std::max<int64_t>(dy, 0)) + std::min<int64_t>(std::max(dx, dy), 0);
}

int64_t NativeBake::box3(const Vector3i &p_p, const Vector3i &p_c, const Vector3i &p_h) const {
	int64_t qx = std::llabs(int64_t(p_p.x) - p_c.x) - p_h.x;
	int64_t qy = std::llabs(int64_t(p_p.y) - p_c.y) - p_h.y;
	int64_t qz = std::llabs(int64_t(p_p.z) - p_c.z) - p_h.z;
	return length3(std::max<int64_t>(qx, 0), std::max<int64_t>(qy, 0), std::max<int64_t>(qz, 0)) + std::min<int64_t>(std::max(qx, std::max(qy, qz)), 0);
}

int64_t NativeBake::capsule3(const Vector3i &p_p, const Vector3i &p_a, const Vector3i &p_b, int64_t p_r) const {
	int64_t abx = int64_t(p_b.x) - p_a.x, aby = int64_t(p_b.y) - p_a.y, abz = int64_t(p_b.z) - p_a.z;
	int64_t apx = int64_t(p_p.x) - p_a.x, apy = int64_t(p_p.y) - p_a.y, apz = int64_t(p_p.z) - p_a.z;
	int64_t len2 = abx * abx + aby * aby + abz * abz;
	int64_t dot = apx * abx + apy * aby + apz * abz;
	if (len2 == 0 || dot <= 0) {
		return length3(apx, apy, apz) - p_r;
	}
	if (dot >= len2) {
		return length3(int64_t(p_p.x) - p_b.x, int64_t(p_p.y) - p_b.y, int64_t(p_p.z) - p_b.z) - p_r;
	}
	int64_t cx = p_a.x + muldiv(abx, dot, len2);
	int64_t cy = p_a.y + muldiv(aby, dot, len2);
	int64_t cz = p_a.z + muldiv(abz, dot, len2);
	return length3(int64_t(p_p.x) - cx, int64_t(p_p.y) - cy, int64_t(p_p.z) - cz) - p_r;
}

PackedInt32Array NativeBake::hydraulic(const PackedInt32Array &p_base, int64_t p_w, int64_t p_h, int64_t p_sea_mm, int64_t p_river_flow, bool p_wrap) const {
	return ::hydraulic(p_base, p_w, p_h, p_sea_mm, p_river_flow, p_wrap);
}

// `DigBrush.cut_cells`: tiles tx ascending then tz ascending, a run's cells bottom to top.
Array NativeBake::cut_cells(const Dictionary &p_op, const Dictionary &p_columns) const {
	constexpr int64_t TILE_MM = 500, STEP_MM = 125, SAMPLE_Y = 62, BEDROCK_MM = -96000;
	Array out;
	const Array c = p_op["centre"];
	const int64_t r = p_op["radius"];
	const int64_t k = p_op["k"];
	const int32_t cx = int32_t(int64_t(c[0])), cy32 = int32_t(int64_t(c[1])), cz = int32_t(int64_t(c[2]));
	const int64_t cy = int64_t(c[1]);
	const String shape = String(p_op["shape"]);
	const int kind = shape == "cylinder" ? 1 : (shape == "box" ? 2 : 0);
	const Vector3i cv(cx, cy32, cz);
	const int64_t tx0 = fdiv(int64_t(cx) - r, TILE_MM), tx1 = fdiv(int64_t(cx) + r, TILE_MM);
	const int64_t tz0 = fdiv(int64_t(cz) - r, TILE_MM), tz1 = fdiv(int64_t(cz) + r, TILE_MM);
	const int64_t y_lo = cy - r - STEP_MM;
	const int64_t y_hi = cy + r;
	// The keys come back out of the Dictionary (a Vector2i built here does not hash like GDScript's): the ones
	// inside the brush bounds, tx then tz ascending.
	struct Tile {
		int64_t tx, tz;
		Variant key;
	};
	std::vector<Tile> tiles;
	const Array all = p_columns.keys();
	for (int64_t i = 0; i < all.size(); i++) {
		const Vector2i kv = all[i];
		if (kv.x >= tx0 && kv.x <= tx1 && kv.y >= tz0 && kv.y <= tz1) {
			tiles.push_back({ kv.x, kv.y, all[i] });
		}
	}
	std::sort(tiles.begin(), tiles.end(), [](const Tile &a, const Tile &b) { return a.tx != b.tx ? a.tx < b.tx : a.tz < b.tz; });
	for (const Tile &t : tiles) {
		const int64_t tx = t.tx, tz = t.tz;
		{
			const int32_t px = int32_t(tx * TILE_MM + TILE_MM / 2);
			const int32_t pz = int32_t(tz * TILE_MM + TILE_MM / 2);
			const PackedInt32Array runs = p_columns[t.key];
			PackedInt32Array cells;
			for (int64_t i = 0; i + 1 < runs.size(); i += 2) {
				const int64_t rb = runs[i], rt = runs[i + 1];
				const int64_t from = std::max(std::max(rb, BEDROCK_MM), y_lo);
				const int64_t to = std::min(rt, y_hi);
				int64_t cb = from - (((from % STEP_MM) + STEP_MM) % STEP_MM);
				if (cb < from) {
					cb += STEP_MM;
				}
				while (cb + STEP_MM <= rt && cb < to) {
					const int64_t py = cb + SAMPLE_Y;
					const int64_t solid = -std::min(py - rb, rt - py);
					const Vector3i pv(px, int32_t(py), pz);
					int64_t sd;
					if (kind == 1) {
						sd = cylinder(pv, cv, r, r);
					} else if (kind == 2) {
						sd = box3(pv, cv, Vector3i(int32_t(r), int32_t(r), int32_t(r)));
					} else {
						sd = sphere(pv, cv, r);
					}
					if (smooth_intersection_i(sd, solid, k) < 0) {
						cells.push_back(int32_t(cb));
					}
					cb += STEP_MM;
				}
			}
			if (!cells.is_empty()) {
				Array e;
				e.push_back(int64_t(tx));
				e.push_back(int64_t(tz));
				e.push_back(cells);
				out.push_back(e);
			}
		}
	}
	return out;
}
