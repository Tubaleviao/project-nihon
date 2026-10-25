#include "native_chunk_builder.h"

#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <cmath>
#include <vector>

using namespace godot;

namespace {

// Mirrors of the GDScript constants (terrain_slice.gd, world_shape.gd).
const int CHUNK_SIZE = 64;
const double TILE_SIZE = 0.5;
const double CHUNK_METERS = CHUNK_SIZE * TILE_SIZE;
const double HEIGHT_SCALE = 5.0;
const int WRAP_BLEND_CHUNKS = 8;
const double ICE_SHELF_LAT = 80.0;
const double ICE_SHELF_M = 0.5;
const double ICE_RELIEF_M = 2.0;
const double ICE_RELIEF_CELL_M = 64.0;
const double POLE_FIELD_INNER_M = 2500.0;
const double POLE_FIELD_OUTER_M = 5000.0;
const double POLE_SNOW_M = 3.0;
const double NOISE_SPAN = 65536.0;
const double NOISE_BLEND = 64.0;
const double NOISE_OFFSET_RANGE = 4096.0;
const int CONTINENT_CELLS[3] = { 16, 44, 128 };
const double CONTINENT_WEIGHTS[3] = { 0.55, 0.3, 0.15 };
const int EROSION_CELLS = 64;
const int RIDGE_CELLS = 1600;   // worldgen 10 (Phase 188): 25 km ranges, were 125 km
const double RIDGE_SHARPNESS = 10.0;
const double CONTRAST = 1.9;
const double SPAWN_CENTER_X = 16.0;
const double SPAWN_CENTER_Z = 16.0;
const double SPAWN_HEIGHT = 2.0;   // the plain's floor; the plain itself comes in `Cfg::spawn_plain` (worldgen 9)
const double SPAWN_PLAIN_M = 1500.0;
const double SPAWN_EASE_M = 4000.0;

// GDScript `lerpf`, `smoothstep`, `fposmod` and `posmod`, written as the engine does.
inline double lerpf(double a, double b, double t) {
	return a + (b - a) * t;
}

inline double smoothstep(double from, double to, double x) {
	if (Math::is_equal_approx(from, to)) {
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

// 64-bit wrapping arithmetic with GDScript's arithmetic right shift.
inline int64_t mul(int64_t a, int64_t b) {
	return (int64_t)((uint64_t)a * (uint64_t)b);
}
inline int64_t add(int64_t a, int64_t b) {
	return (int64_t)((uint64_t)a + (uint64_t)b);
}

struct Cfg {
	int64_t circumference_chunks = 4;
	double sea = 0.0;
	double min_h = -64.0;
	double max_h = 512.0;
	double ridge_amp = 400.0;
	double spawn_plain = SPAWN_HEIGHT;   // `WorldShape.spawn_plain_height` for this seed, computed in GDScript
	std::vector<double> spline_x;
	std::vector<double> spline_y;
	Dictionary records;
};

// WorldShape ---------------------------------------------------------------------------------

int64_t shape_mix(int64_t seed_v, int64_t a, int64_t b, int64_t salt) {
	int64_t h = add(add(add(mul(seed_v, 6364136223846793005LL), mul(a, 2654435761LL)), mul(b, 2246822519LL)), mul(salt, 3266489917LL));
	h = mul(h ^ (h >> 29), -4658895280553007687LL);
	h = h ^ (h >> 32);
	return h & 0x7fffffff;
}

double shape_noise(int64_t seed_v, double x, double z, double w, int64_t cells_x, int64_t salt) {
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

double continentalness(int64_t seed_v, double x, double z, double w) {
	double v = 0.0;
	for (int i = 0; i < 3; i++) {
		v += CONTINENT_WEIGHTS[i] * shape_noise(seed_v, x, z, w, CONTINENT_CELLS[i], 21 + i);
	}
	return clampf(0.5 + (v - 0.5) * CONTRAST, 0.0, 1.0);
}

double ridges(int64_t seed_v, double x, double z, double w) {
	double n = shape_noise(seed_v, x, z, w, RIDGE_CELLS, 41) * 0.7 + shape_noise(seed_v, x, z, w, RIDGE_CELLS * 3, 42) * 0.3;
	return std::pow(1.0 - std::fabs(n * 2.0 - 1.0), RIDGE_SHARPNESS);
}

double spline_height(const Cfg &cfg, double c) {
	size_t n = cfg.spline_x.size();
	if (c <= cfg.spline_x[0]) {
		return cfg.spline_y[0];
	}
	for (size_t i = 1; i < n; i++) {
		double x1 = cfg.spline_x[i];
		if (c <= x1) {
			double x0 = cfg.spline_x[i - 1];
			double t = (c - x0) / std::fmax(x1 - x0, 0.000001);
			return lerpf(cfg.spline_y[i - 1], cfg.spline_y[i], t);
		}
	}
	return cfg.spline_y[n - 1];
}

double shape_height(const Cfg &cfg, int64_t seed_v, double x, double z, double w) {
	double c = continentalness(seed_v, x, z, w);
	double e = shape_noise(seed_v, x, z, w, EROSION_CELLS, 31);
	double base = spline_height(cfg, c);
	double inland = smoothstep(0.68, 0.9, c);
	double rugged = 1.0 - smoothstep(0.35, 0.8, e);
	double peaks = ridges(seed_v, x, z, w) * cfg.ridge_amp * inland * rugged;
	double h = clampf(base + peaks, cfg.min_h, cfg.max_h);
	double d = Vector2(x - SPAWN_CENTER_X, z - SPAWN_CENTER_Z).length();   // float32, as GDScript's Vector2
	if (d < SPAWN_EASE_M) {
		h = lerpf(cfg.spawn_plain, h, smoothstep(SPAWN_PLAIN_M, SPAWN_EASE_M, d));
	}
	return h;
}

// Corner heights of the chunk cell (ix, iz): the record's when the cell is recorded.
struct Corners {
	int64_t ix, iz;
	double c[4];
};

struct ShapeSampler {
	const Cfg &cfg;
	int64_t seed_v;
	double w;
	std::vector<Corners> memo;

	ShapeSampler(const Cfg &p_cfg, int64_t p_seed, double p_w) :
			cfg(p_cfg), seed_v(p_seed), w(p_w) {}

	const Corners &corners(int64_t ix, int64_t iz) {
		for (const Corners &k : memo) {
			if (k.ix == ix && k.iz == iz) {
				return k;
			}
		}
		Corners k;
		k.ix = ix;
		k.iz = iz;
		Variant rec = cfg.records.get(Vector2i((int32_t)ix, (int32_t)iz), Variant());
		if (rec.get_type() == Variant::PACKED_FLOAT64_ARRAY && PackedFloat64Array(rec).size() == 4) {
			PackedFloat64Array a = rec;
			for (int i = 0; i < 4; i++) {
				k.c[i] = a[i];
			}
		} else {
			double x0 = double(ix) * CHUNK_METERS;
			double z0 = double(iz) * CHUNK_METERS;
			k.c[0] = shape_height(cfg, seed_v, x0, z0, w);
			k.c[1] = shape_height(cfg, seed_v, x0 + CHUNK_METERS, z0, w);
			k.c[2] = shape_height(cfg, seed_v, x0, z0 + CHUNK_METERS, w);
			k.c[3] = shape_height(cfg, seed_v, x0 + CHUNK_METERS, z0 + CHUNK_METERS, w);
		}
		memo.push_back(k);
		return memo.back();
	}

	double shape_at(double x, double z) {
		double gx = x / CHUNK_METERS;
		double gz = z / CHUNK_METERS;
		int64_t ix = (int64_t)std::floor(gx);
		int64_t iz = (int64_t)std::floor(gz);
		Corners k = corners(ix, iz);
		double fx = gx - double(ix);
		double fz = gz - double(iz);
		return lerpf(lerpf(k.c[0], k.c[1], fx), lerpf(k.c[2], k.c[3], fx), fz);
	}
};

// Detail noise (TerrainSlice.detail_of) -------------------------------------------------------

struct AxisCells {
	int64_t cell;
	double weight;
	int64_t neighbour;
};

AxisCells axis_cells(double v) {
	int64_t c = (int64_t)std::floor((v + NOISE_SPAN) / (2.0 * NOISE_SPAN));
	double local = v - double(c) * 2.0 * NOISE_SPAN;
	if (local > NOISE_SPAN - NOISE_BLEND) {
		return { c, 0.5 * (local - (NOISE_SPAN - NOISE_BLEND)) / NOISE_BLEND, c + 1 };
	}
	if (local < -NOISE_SPAN + NOISE_BLEND) {
		return { c, 0.5 * (1.0 - (local + NOISE_SPAN) / NOISE_BLEND), c - 1 };
	}
	return { c, 0.0, c };
}

Vector2 cell_offset(int64_t seed_v, int64_t cx, int64_t cz) {
	if (cx == 0 && cz == 0) {
		return Vector2();
	}
	int64_t h = mul(seed_v, 73856093) ^ mul(cx, 19349663) ^ mul(cz, 83492791);
	h = mul(h ^ (h >> 15), 0x2c1b3c6d) & 0x7fffffff;
	h = mul(h ^ (h >> 12), 0x297a2d39) & 0x7fffffff;
	h = h ^ (h >> 15);
	int64_t span = (int64_t)(NOISE_OFFSET_RANGE * 8.0);
	double ox = double((h & 0xffff) % span) / 8.0 - NOISE_OFFSET_RANGE * 0.5;
	double oz = double(((h >> 15) & 0xffff) % span) / 8.0 - NOISE_OFFSET_RANGE * 0.5;
	return Vector2(ox, oz);
}

double detail_of(const Ref<FastNoiseLite> &n, int64_t seed_v, double x, double z) {
	AxisCells ax = axis_cells(x);
	AxisCells az = axis_cells(z);
	double total = 0.0;
	for (int i = 0; i < 2; i++) {
		double wx = i == 1 ? ax.weight : 1.0 - ax.weight;
		if (wx <= 0.0) {
			continue;
		}
		for (int j = 0; j < 2; j++) {
			double wz = j == 1 ? az.weight : 1.0 - az.weight;
			if (wz <= 0.0) {
				continue;
			}
			int64_t cx = i == 1 ? ax.neighbour : ax.cell;
			int64_t cz = j == 1 ? az.neighbour : az.cell;
			double lx = x - double(cx) * 2.0 * NOISE_SPAN;
			double lz = z - double(cz) * 2.0 * NOISE_SPAN;
			Vector2 off = cell_offset(seed_v, cx, cz);
			total += wx * wz * n->get_noise_2d(lx + off.x, lz + off.y);
		}
	}
	return (total + 1.0) * 0.5 * HEIGHT_SCALE;
}

// Polar ice (TerrainSlice.polar_ground) -------------------------------------------------------

double fold_latitude(double lat) {
	if (lat > 90.0) {
		return 180.0 - lat;
	}
	if (lat < -90.0) {
		return -180.0 - lat;
	}
	return lat;
}

struct PolarRow {
	bool valid = false;
	double z = 0.0;
	double t = 0.0;
	double field = 0.0;
};

double polar_ground(const Cfg &cfg, int64_t seed_v, double h, double x, double z, double w, PolarRow &row) {
	int64_t pole_chunks = cfg.circumference_chunks / 4;
	double row_lat = std::fabs(fold_latitude((double((int64_t)std::floor(z / CHUNK_METERS)) + 0.5) * 90.0 / double(pole_chunks)));
	if (row_lat < ICE_SHELF_LAT) {
		return h;
	}
	if (h < cfg.sea + ICE_SHELF_M + ICE_RELIEF_M) {
		int64_t cells = std::max<int64_t>(1, (int64_t)std::llround(w / ICE_RELIEF_CELL_M));
		double shelf = cfg.sea + ICE_SHELF_M + ICE_RELIEF_M * shape_noise(seed_v, x, z, w, cells, 61);
		h = std::fmax(h, shelf);
	}
	if (!row.valid || row.z != z) {
		double lat = fold_latitude(z / CHUNK_METERS * 90.0 / double(pole_chunks));
		double from_pole = (90.0 - std::fabs(lat)) * double(pole_chunks) * CHUNK_METERS / 90.0;
		row.t = 0.0;
		row.field = 0.0;
		if (from_pole < POLE_FIELD_OUTER_M) {
			row.t = 1.0 - smoothstep(POLE_FIELD_INNER_M, POLE_FIELD_OUTER_M, from_pole);
			row.field = cfg.sea + ICE_SHELF_M + POLE_SNOW_M;
		}
		row.z = z;
		row.valid = true;
	}
	if (row.t == 0.0) {
		return h;
	}
	return lerpf(h, row.field, row.t);
}

// Heights (TerrainSlice.raw_height_in / height_wrapped_in) -------------------------------------

struct Ctx {
	const Cfg &cfg;
	int64_t seed_v;
	const Ref<FastNoiseLite> &noise;
	double w;
	ShapeSampler shape;
	PolarRow row;

	Ctx(const Cfg &p_cfg, int64_t p_seed, const Ref<FastNoiseLite> &p_noise, double p_w) :
			cfg(p_cfg), seed_v(p_seed), noise(p_noise), w(p_w), shape(p_cfg, p_seed, p_w) {}

	double raw_height(double x, double z) {
		double s = shape.shape_at(x, z);
		double detail = detail_of(noise, seed_v, x, z);
		double h = clampf(s + detail, cfg.min_h, cfg.max_h);
		return polar_ground(cfg, seed_v, h, x, z, w, row);
	}

	double height_wrapped(double x, double z) {
		double half_w = w * 0.5;
		double wx = fposmod(x + w * 0.5, w) - w * 0.5;
		double band = WRAP_BLEND_CHUNKS * CHUNK_METERS;
		if (wx > half_w - band) {
			double t = (wx - (half_w - band)) / band;
			t = t * t * (3.0 - 2.0 * t);
			double a = raw_height(wx, z);
			double b = raw_height(wx - w, z);
			return lerpf(a, b, t);
		}
		return raw_height(wx, z);
	}
};

} // namespace

void NativeChunkBuilder::_bind_methods() {
	ClassDB::bind_method(D_METHOD("version"), &NativeChunkBuilder::version);
	ClassDB::bind_method(D_METHOD("functions"), &NativeChunkBuilder::functions);
	ClassDB::bind_method(D_METHOD("heightmap_for", "pos", "seed", "noise", "cfg"), &NativeChunkBuilder::heightmap_for);
	ClassDB::bind_method(D_METHOD("build_runs", "chunk_pos", "heightmap", "input", "cfg"), &NativeChunkBuilder::build_runs);
	ClassDB::bind_method(D_METHOD("build_chunk_arrays", "chunk_pos", "heightmap", "resolved", "local", "cfg"), &NativeChunkBuilder::build_chunk_arrays);
}

int NativeChunkBuilder::version() const {
	return 6;   // 6 = worldgen 10 ridges (Phase 188); 5 = heightmap_for reads the spawn plain from `cfg.spawn_plain` (worldgen 9)
}

PackedStringArray NativeChunkBuilder::functions() const {
	PackedStringArray out;
	out.push_back("heightmap_for");
	out.push_back("build_runs");
	out.push_back("build_chunk_arrays");
	return out;
}

Array NativeChunkBuilder::heightmap_for(const Vector2i &p_pos, int64_t p_seed, const Ref<FastNoiseLite> &p_noise, const Dictionary &p_cfg) const {
	Array out;
	ERR_FAIL_COND_V(p_noise.is_null(), out);
	Cfg cfg;
	cfg.circumference_chunks = (int64_t)p_cfg.get("circumference_chunks", 4);
	cfg.sea = p_cfg.get("sea", 0.0);
	cfg.min_h = p_cfg.get("min_height", -64.0);
	cfg.max_h = p_cfg.get("max_height", 512.0);
	cfg.ridge_amp = p_cfg.get("ridge_amplitude", 400.0);
	cfg.spawn_plain = p_cfg.get("spawn_plain", SPAWN_HEIGHT);
	cfg.records = p_cfg.get("records", Dictionary());
	Array spline = p_cfg.get("spline", Array());
	for (int i = 0; i < spline.size(); i++) {
		Array pt = spline[i];
		cfg.spline_x.push_back(pt[0]);
		cfg.spline_y.push_back(pt[1]);
	}
	ERR_FAIL_COND_V(cfg.spline_x.size() < 2, out);

	double w = double(cfg.circumference_chunks) * CHUNK_METERS;
	double origin_x = double(p_pos.x * CHUNK_SIZE) * TILE_SIZE;
	double origin_z = double(p_pos.y * CHUNK_SIZE) * TILE_SIZE;
	Ctx ctx(cfg, p_seed, p_noise, w);
	out.resize(CHUNK_SIZE * CHUNK_SIZE);
	for (int ty = 0; ty < CHUNK_SIZE; ty++) {
		for (int tx = 0; tx < CHUNK_SIZE; tx++) {
			out[ty * CHUNK_SIZE + tx] = ctx.height_wrapped(origin_x + tx * TILE_SIZE, origin_z + ty * TILE_SIZE);
		}
	}
	return out;
}
