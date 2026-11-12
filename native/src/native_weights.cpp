// Phase 242 — NativeChunkBuilder::terrain_weights, the port of `TerrainWeights.apply_gd`: each natural
// vertex's terrain-material weights (biome blend, wetness, snow line, slope), packed into two RGBA8
// arrays, one channel per layer. The GDScript is the reference; the order of every float operation
// follows it so the bytes match exactly (`_test_native_parity` in terrain_material_tests.gd).
#include "native_chunk_builder.h"

#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

#include <algorithm>
#include <cmath>
#include <limits>

using namespace godot;

namespace {

constexpr int SLOTS = 4;
constexpr int LAYERS = 8;
constexpr double PI_D = 3.1415926535897932384626433833;

struct Entry {
	int key;
	double w;
};

// A small insertion-ordered map, as a GDScript Dictionary iterates.
struct OrderedMap {
	Entry e[16];
	int n = 0;
	int find(int k) const {
		for (int i = 0; i < n; i++) {
			if (e[i].key == k) {
				return i;
			}
		}
		return -1;
	}
	double get(int k) const {
		int i = find(k);
		return i < 0 ? 0.0 : e[i].w;
	}
	void add(int k, double w) {
		int i = find(k);
		if (i < 0) {
			if (n < 16) {
				e[n++] = { k, w };
			}
		} else {
			e[i].w += w;
		}
	}
};

double smoothstep(double from, double to, double s) {
	if (std::abs(from - to) < 1e-5) {   // Math::is_equal_approx's tolerance for small values
		return from > to ? (s <= to ? 1.0 : 0.0) : (s < from ? 0.0 : 1.0);
	}
	double t = std::clamp((s - from) / (to - from), 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t);
}

double chance(double d, double band) {
	if (d >= band || band <= 0.0) {
		return 0.0;
	}
	return 0.5 * (1.0 - std::max(d, 0.0) / band);
}

struct Params {
	Vector2i chunk;
	bool local = false;
	double extent = 32.0, tile = 0.5, band = 4.0, sea = 0.0;
	PackedInt32Array grid, layer;
	PackedFloat64Array snow_line, lakes, segs;
	int rock = -1, snow = -1, wet = -1;
	double rock_slope = 90.0, wet_dist = 0.0, snow_band = 15.0, slope_band = 8.0, no_line = 100000.0;

	// Biome id of chunk (cx, cz), or -1 when it is outside the 5x5 or not in the gathered map.
	int biome_at(int64_t cx, int64_t cz) const {
		int64_t gx = cx - chunk.x + 2;
		int64_t gz = cz - chunk.y + 2;
		if (gx < 0 || gx > 4 || gz < 0 || gz > 4) {
			return -1;
		}
		return grid[int(gz * 5 + gx)];
	}
};

// `TerrainWeights.biome_weights`, keyed by biome id. `wx`, `wz` are the float32 world position.
void biome_weights(const Params &p, float wx, float wz, OrderedMap &out) {
	const double x = double(wx);
	const double z = double(wz);
	const int64_t cx = int64_t(std::floor(x / p.extent));
	const int64_t cz = int64_t(std::floor(z / p.extent));
	int own = p.biome_at(cx, cz);
	if (own < 0) {
		own = 0;   // DEFAULT_BIOME
	}
	const double lx = x - double(cx) * p.extent;
	const double lz = z - double(cz) * p.extent;
	const double dx = std::min(lx, p.extent - lx) / p.tile;
	const double dz = std::min(lz, p.extent - lz) / p.tile;
	if (std::min(dx, dz) >= p.band) {
		out.add(own, 1.0);
		return;
	}
	const int sx = lx < p.extent - lx ? -1 : 1;
	const int sz = lz < p.extent - lz ? -1 : 1;
	const int64_t ccx[3] = { cx + sx, cx, cx + sx };
	const int64_t ccz[3] = { cz, cz + sz, cz + sz };
	const double cw[3] = { chance(dx, p.band), chance(dz, p.band), chance(std::max(dx, dz), p.band) };
	double top = 0.0;
	for (int i = 0; i < 3; i++) {
		int b = p.biome_at(ccx[i], ccz[i]);
		if (b < 0) {
			b = own;
		}
		if (cw[i] <= 0.0 || b == own) {
			continue;
		}
		out.add(b, cw[i]);
		top = std::max(top, cw[i]);
	}
	out.add(own, 1.0 - top);
	double sum = 0.0;
	for (int i = 0; i < out.n; i++) {
		sum += out.e[i].w;
	}
	for (int i = 0; i < out.n; i++) {
		out.e[i].w = out.e[i].w / sum;
	}
}

void take(OrderedMap &w, int layer, double f) {
	if (f <= 0.0) {
		return;
	}
	for (int i = 0; i < w.n; i++) {
		w.e[i].w = w.e[i].w * (1.0 - f);
	}
	w.add(layer, f);
}

double water_distance(const Params &p, double x, double z) {
	double best = std::numeric_limits<double>::infinity();
	const double *lk = p.lakes.ptr();
	for (int64_t i = 0; i + 2 < p.lakes.size(); i += 3) {
		const double dx = x - lk[i];
		const double dz = z - lk[i + 1];
		best = std::min(best, std::sqrt(dx * dx + dz * dz) - lk[i + 2]);
	}
	const double *sg = p.segs.ptr();
	for (int64_t i = 0; i + 5 < p.segs.size(); i += 6) {
		const double ax = sg[i];
		const double az = sg[i + 1];
		const double abx = sg[i + 2] - ax;
		const double abz = sg[i + 3] - az;
		const double len2 = abx * abx + abz * abz;
		const double t = len2 > 0.0 ? std::clamp(((x - ax) * abx + (z - az) * abz) / len2, 0.0, 1.0) : 0.0;
		const double px = ax + abx * t - x;
		const double pz = az + abz * t - z;
		const double half = sg[i + 5] + (sg[i + 4] - sg[i + 5]) * t;   // lerpf(sg[7], sg[6], t)
		best = std::min(best, std::sqrt(px * px + pz * pz) - half);
	}
	return std::max(best, 0.0);
}

// `TerrainWeights.weights` then `_top` then `pack`, writing vertex `vi`'s eight channels.
void weigh_and_pack(const Params &p, const OrderedMap &ground, double slope, double altitude, double wd, uint8_t *w0, uint8_t *w1, int64_t vi) {
	OrderedMap w;
	double line = 0.0;
	for (int i = 0; i < ground.n; i++) {
		const double g = ground.e[i].w;
		const int b = ground.e[i].key;
		const int layer = b < p.layer.size() ? p.layer[b] : 0;
		w.add(layer, g);
		line += g * (b < p.snow_line.size() ? p.snow_line[b] : p.no_line);
	}
	if (p.wet >= 0 && wd < p.wet_dist) {
		take(w, p.wet, 1.0 - smoothstep(0.0, p.wet_dist, std::max(wd, 0.0)));
	}
	if (p.snow >= 0 && line < p.no_line) {
		take(w, p.snow, smoothstep(line - p.snow_band, line + p.snow_band, altitude));
	}
	if (p.rock >= 0) {
		take(w, p.rock, smoothstep(p.rock_slope - p.slope_band, p.rock_slope + p.slope_band, slope));
	}
	// _top: the heaviest SLOTS, ties to the lower layer, renormalised.
	Entry keys[16];
	int nk = 0;
	for (int i = 0; i < w.n; i++) {
		if (w.e[i].w > 0.0) {
			keys[nk++] = w.e[i];
		}
	}
	std::sort(keys, keys + nk, [](const Entry &a, const Entry &b) {
		return a.w > b.w || (a.w == b.w && a.key < b.key);
	});
	nk = std::min(nk, SLOTS);
	double sum = 0.0;
	for (int i = 0; i < nk; i++) {
		sum += keys[i].w;
	}
	// pack
	const int64_t o = vi * 4;
	int left = 255;
	int heavy = -1;
	double heavy_w = 0.0;
	for (int i = 0; i < nk; i++) {
		const int layer = keys[i].key;
		const double wt = keys[i].w / sum;
		if (layer < 0 || layer >= LAYERS) {
			continue;
		}
		const int b = int(std::clamp<int64_t>(int64_t(std::round(wt * 255.0)), 0, left));
		if (heavy < 0 || wt > heavy_w) {
			heavy = layer;
			heavy_w = wt;
		}
		(layer < 4 ? w0[o + layer] : w1[o + layer - 4]) = uint8_t(b);
		left -= b;
	}
	if (heavy >= 0 && left > 0) {
		uint8_t &cell = heavy < 4 ? w0[o + heavy] : w1[o + heavy - 4];
		cell = uint8_t(cell + left);
	}
}

} // namespace

Array NativeChunkBuilder::terrain_weights(const PackedVector3Array &p_vertices, const PackedVector3Array &p_normals, int64_t p_natural, const Dictionary &p_params) const {
	Array empty;
	Params p;
	ERR_FAIL_COND_V(p_params.get("chunk", Variant()).get_type() != Variant::VECTOR2I, empty);
	p.chunk = p_params["chunk"];
	p.local = bool(p_params.get("local", false));
	p.extent = double(p_params.get("extent", 32.0));
	p.tile = double(p_params.get("tile", 0.5));
	p.band = double(p_params.get("band", 4.0));
	p.sea = double(p_params.get("sea", 0.0));
	p.grid = p_params.get("grid", PackedInt32Array());
	p.layer = p_params.get("layer", PackedInt32Array());
	p.snow_line = p_params.get("snow_line", PackedFloat64Array());
	p.lakes = p_params.get("lakes", PackedFloat64Array());
	p.segs = p_params.get("segs", PackedFloat64Array());
	p.rock = int(p_params.get("rock", -1));
	p.rock_slope = double(p_params.get("rock_slope", 90.0));
	p.snow = int(p_params.get("snow", -1));
	p.wet = int(p_params.get("wet", -1));
	p.wet_dist = double(p_params.get("wet_dist", 0.0));
	p.snow_band = double(p_params.get("snow_band", 15.0));
	p.slope_band = double(p_params.get("slope_band", 8.0));
	p.no_line = double(p_params.get("no_line", 100000.0));
	ERR_FAIL_COND_V(p.grid.size() != 25 || p.layer.size() < 1 || p.layer.size() != p.snow_line.size(), empty);
	for (int64_t i = 0; i < 25; i++) {
		ERR_FAIL_COND_V(p.grid[i] >= p.layer.size(), empty);
	}

	const int64_t n = p_vertices.size();
	PackedByteArray w0;
	PackedByteArray w1;
	w0.resize(n * 4);
	w1.resize(n * 4);
	w0.fill(0);
	w1.fill(0);
	const int64_t natural = std::clamp<int64_t>(p_natural, 0, n);
	if (natural > 0) {
		uint8_t *o0 = w0.ptrw();
		uint8_t *o1 = w1.ptrw();
		const Vector3 *v = p_vertices.ptr();
		const Vector3 *nr = p_normals.ptr();
		const int64_t nn = p_normals.size();
		// Vector2(chunk_pos) * extent: float32, as the GDScript computes it.
		const float corner_x = p.local ? float(p.chunk.x) * float(p.extent) : 0.0f;
		const float corner_z = p.local ? float(p.chunk.y) * float(p.extent) : 0.0f;
		const bool dry = p.lakes.size() == 0 && p.segs.size() == 0;
		int own_id = p.biome_at(p.chunk.x, p.chunk.y);
		if (own_id < 0) {
			own_id = 0;
		}
		OrderedMap own;
		own.add(own_id, 1.0);
		const double lo = p.band * p.tile;
		const double hi = p.extent - lo;
		for (int64_t i = 0; i < natural; i++) {
			const double x = double(v[i].x) + double(corner_x);
			const double z = double(v[i].z) + double(corner_z);
			const double lx = p.local ? double(v[i].x) : x - std::floor(x / p.extent) * p.extent;
			const double lz = p.local ? double(v[i].z) : z - std::floor(z / p.extent) * p.extent;
			const bool inner = lx > lo && lx < hi && lz > lo && lz < hi;
			OrderedMap ground;
			if (inner) {
				ground = own;
			} else {
				biome_weights(p, float(x), float(z), ground);
			}
			const double slope = i < nn ? std::acos(std::clamp(double(nr[i].y), -1.0, 1.0)) * (180.0 / PI_D) : 0.0;
			const double wd = dry ? std::numeric_limits<double>::infinity() : water_distance(p, x, z);
			weigh_and_pack(p, ground, slope, double(v[i].y) - p.sea, wd, o0, o1, i);
		}
	}
	Array out;
	out.push_back(w0);
	out.push_back(w1);
	return out;
}
