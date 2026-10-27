// Phase 168 — NativeChunkBuilder::build_runs, the port of `VoxelSlice.build_runs`: every tile of the
// chunk's one-tile ring resolved to coloured runs (edits replayed over the natural column, ore-field
// colour, topsoil, biome dither) plus the chunk's vein deposit markers. The GDScript is the
// reference; every expression below mirrors it, including the float32 narrowing GDScript applies
// when a position goes through a `Vector2` / `Vector3` / `Color`.
#include "native_chunk_builder.h"

#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/vector3i.hpp>

#include <algorithm>
#include <cmath>
#include <map>
#include <tuple>
#include <utility>
#include <vector>

using namespace godot;

namespace {

const int CHUNK_SIZE = 64;
const double TILE_SIZE = 0.5;
const double CHUNK_METERS = CHUNK_SIZE * TILE_SIZE;
const double STEP_HEIGHT = 0.125;
const double BEDROCK_DEPTH = -96.0;
const double BLEND_TILES = 4.0;
const double BLEND_MAX_CHANCE = 0.5;
const double ICE_START_LAT = 72.0;
const double ICE_FULL_LAT = 80.0;
const double ICE_STEPS = 8.0;
const double VEIN_DEPOSIT_HEIGHT = 0.22;
const double VEIN_DEPOSIT_INSET = 0.16;

// OreField constants.
const int CELL_TILES = 16;
const int CELL_OFFSET_TILES = 8;
const double CELL_DEPTH = 4.0;
const double SHAPE_NOISE = 0.3;
const double SHAPE_WAVELENGTH_TILES = 3.0;
const double SHAPE_WAVELENGTH_DEPTH = 1.0;
const double LEY_WAVELENGTH = 40.0;
const double LEY_THRESHOLD = 0.8;
const int64_t SALT_SHAPE = 10;
const int64_t SALT_LEY = 11;

inline int64_t mul(int64_t a, int64_t b) {
	return (int64_t)((uint64_t)a * (uint64_t)b);
}
inline int64_t add(int64_t a, int64_t b) {
	return (int64_t)((uint64_t)a + (uint64_t)b);
}
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
inline int64_t posmod(int64_t a, int64_t b) {
	int64_t v = a % b;
	if ((v < 0 && b > 0) || (v > 0 && b < 0)) {
		v += b;
	}
	return v;
}
inline int64_t floor_div64(int64_t x) {
	return (int64_t)std::floor(double(x) / double(CHUNK_SIZE));
}
// A value stored in a Vector2 / Vector3 / Color component: GDScript holds it as float32.
inline double f32(double v) {
	return (double)(float)v;
}
inline double voxel_height(double raw) {
	return std::floor(raw / STEP_HEIGHT) * STEP_HEIGHT;
}

// ----- ore field ------------------------------------------------------------------------------

int64_t ore_mix(int64_t seed_v, int64_t a, int64_t b, int64_t c, int64_t salt) {
	int64_t h = add(add(add(add(mul(seed_v, 0x9E3779B1LL), mul(a, 0x85EBCA77LL)), mul(b, 0xC2B2AE3DLL)), mul(c, 0x27D4EB2FLL)), mul(salt, 0x165667B1LL));
	h = mul(h ^ (h >> 15), 0x2C1B3C6DLL);
	h = mul(h ^ (h >> 12), 0x297A2D39LL);
	h = h ^ (h >> 15);
	return h & 0x7FFFFFFF;
}
inline double ore_unit(int64_t h) {
	return double(h) / 2147483648.0;
}
inline double ore_corner(int64_t seed_v, int64_t x, int64_t y, int64_t z) {
	return ore_unit(ore_mix(seed_v, x, y, z, 0)) * 2.0 - 1.0;
}
inline double ore_smooth(double t) {
	return t * t * (3.0 - 2.0 * t);
}
double value_noise_2d(int64_t seed_v, double x, double z) {
	int64_t x0 = (int64_t)std::floor(x);
	int64_t z0 = (int64_t)std::floor(z);
	double tx = ore_smooth(x - double(x0));
	double tz = ore_smooth(z - double(z0));
	double a = lerpf(ore_corner(seed_v, x0, 0, z0), ore_corner(seed_v, x0 + 1, 0, z0), tx);
	double b = lerpf(ore_corner(seed_v, x0, 0, z0 + 1), ore_corner(seed_v, x0 + 1, 0, z0 + 1), tx);
	return lerpf(a, b, tz);
}
double value_noise_3d(int64_t seed_v, double x, double y, double z) {
	int64_t x0 = (int64_t)std::floor(x);
	int64_t y0 = (int64_t)std::floor(y);
	int64_t z0 = (int64_t)std::floor(z);
	double tx = ore_smooth(x - double(x0));
	double ty = ore_smooth(y - double(y0));
	double tz = ore_smooth(z - double(z0));
	double lo_a = lerpf(ore_corner(seed_v, x0, y0, z0), ore_corner(seed_v, x0 + 1, y0, z0), tx);
	double lo_b = lerpf(ore_corner(seed_v, x0, y0, z0 + 1), ore_corner(seed_v, x0 + 1, y0, z0 + 1), tx);
	double hi_a = lerpf(ore_corner(seed_v, x0, y0 + 1, z0), ore_corner(seed_v, x0 + 1, y0 + 1, z0), tx);
	double hi_b = lerpf(ore_corner(seed_v, x0, y0 + 1, z0 + 1), ore_corner(seed_v, x0 + 1, y0 + 1, z0 + 1), tx);
	return lerpf(lerpf(lo_a, lo_b, tz), lerpf(hi_a, hi_b, tz), ty);
}

struct Band {
	double min_d = 0.0;
	double max_d = 0.0;
	bool ley = false;
};

struct Vein {
	bool present = false;
	String id;
	String material;
	int64_t reserve = 0;
	double cx = 0.0, cy = 0.0, cz = 0.0;
	double radius = 1.0;
	double half_height = 1.0;
};

struct Style {
	Color top;
	Color soil;
	double depth = 0.0;
};

struct Run {
	double bottom;
	double top;
	String material;
};
typedef std::vector<Run> Runs;

typedef std::pair<int64_t, int64_t> TileId;
typedef std::tuple<int64_t, int64_t, int64_t> CellId;

// The run-entry keys, built once per call instead of once per entry.
struct Keys {
	Variant bottom = String("bottom");
	Variant top = String("top");
	Variant material = String("material");
	Variant color = String("color");
	Variant top_color = String("top_color");
	Variant soil_color = String("soil_color");
	Variant soil_depth = String("soil_depth");
};

struct Ctx {
	Keys k;
	int64_t seed_v = 0;
	int64_t circ = 4;
	int64_t pole = 1;
	Dictionary edits, neighbours, biomes, depleted;
	Dictionary colors, host, styles_in, bands_in;
	Color fallback_color;
	Callable vein_cell;
	Color ice_color;

	std::map<String, Band> bands;
	std::map<String, Style> styles;
	std::map<String, String> host_map;
	std::map<String, Color> color_map;
	std::map<CellId, Vein> veins;
	std::map<TileId, Runs> columns;
	// The biome table read once per chunk: a lookup per tile built a String key and hashed it.
	struct BiomeEntry {
		bool known = false;
		String biome;
	};
	mutable std::map<std::pair<int64_t, int64_t>, BiomeEntry> biome_cache;

	// --- wrapping and keys
	int64_t wrap_x_tile(int64_t x) const {
		int64_t lap = circ * CHUNK_SIZE;
		return posmod(x + lap / 2, lap) - lap / 2;
	}
	int64_t wrap_chunk_x(int64_t x) const {
		return posmod(x + circ / 2, circ) - circ / 2;
	}
	String tile_key(int64_t gx, int64_t gz) const {
		return String::num_int64(wrap_x_tile(gx)) + "," + String::num_int64(gz);
	}
	String chunk_key(int64_t cx, int64_t cz) const {
		return String::num_int64(wrap_chunk_x(cx)) + "," + String::num_int64(cz);
	}

	// --- materials and colours
	Color material_color(const String &m) const {
		auto it = color_map.find(m);
		return it == color_map.end() ? fallback_color : it->second;
	}
	String host_material(const String &biome) const {
		auto it = host_map.find(biome);
		return it == host_map.end() ? String("Ferrite") : it->second;
	}
	const BiomeEntry &biome_entry(int64_t cx, int64_t cz) const {
		std::pair<int64_t, int64_t> id(wrap_chunk_x(cx), cz);
		auto it = biome_cache.find(id);
		if (it != biome_cache.end()) {
			return it->second;
		}
		BiomeEntry e;
		Variant key = chunk_key(cx, cz);
		if (biomes.has(key)) {
			e.known = true;
			e.biome = String(biomes[key]);
		}
		return biome_cache.emplace(id, e).first->second;
	}
	// The chunk's biome, or `fallback` when the table does not hold it.
	String biome_or(int64_t cx, int64_t cz, const String &fallback) const {
		const BiomeEntry &e = biome_entry(cx, cz);
		return e.known ? e.biome : fallback;
	}
	String biome_of(double wx, double wz) const {
		double extent = CHUNK_METERS;
		return biome_or((int64_t)std::floor(wx / extent), (int64_t)std::floor(wz / extent), String("TemperateForest"));
	}
	double latitude_at(double world_z) const {
		double lat = world_z / CHUNK_METERS * 90.0 / double(pole);
		if (lat > 90.0) {
			return 180.0 - lat;
		}
		if (lat < -90.0) {
			return -180.0 - lat;
		}
		return lat;
	}
	Color icy(const Color &c, double world_z) const {
		double lat = std::fabs(latitude_at(world_z));
		if (lat <= ICE_START_LAT) {
			return c;
		}
		double t = Math::snapped(smoothstep(ICE_START_LAT, ICE_FULL_LAT, lat), 1.0 / ICE_STEPS);
		return c.lerp(ice_color, (float)t);
	}

	// --- ore field
	bool near_ley_line(double wx, double wz) const {
		double n = value_noise_2d(ore_mix(seed_v, SALT_LEY, 0, 0, 0), wx / LEY_WAVELENGTH, wz / LEY_WAVELENGTH);
		return 1.0 - std::fabs(n) >= LEY_THRESHOLD;
	}
	bool allows(const String &material, double depth, double wx, double wz) const {
		auto it = bands.find(material);
		Band b;
		if (it != bands.end()) {
			b = it->second;
		}
		if (depth < b.min_d || depth >= b.max_d) {
			return false;
		}
		if (b.ley && !near_ley_line(wx, wz)) {
			return false;
		}
		return true;
	}
	const Vein &vein_in_cell(int64_t cx, int64_t cy, int64_t cz) {
		CellId id(cx, cy, cz);
		auto it = veins.find(id);
		if (it != veins.end()) {
			return it->second;
		}
		Vein v;
		Variant r = vein_cell.call(seed_v, Vector3i((int32_t)cx, (int32_t)cy, (int32_t)cz), Dictionary());
		Dictionary d = r;
		if (!d.is_empty()) {
			v.present = true;
			v.id = String(d["id"]);
			v.material = String(d["material"]);
			v.reserve = (int64_t)d["reserve"];
			Vector3 c = d["center"];
			v.cx = c.x;
			v.cy = c.y;
			v.cz = c.z;
			v.radius = d["radius"];
			v.half_height = d["half_height"];
		}
		return veins.emplace(id, v).first->second;
	}
	// The vein at a global tile and depth, or nullptr.
	const Vein *vein_at(int64_t gx, int64_t gz, double depth) {
		int64_t cx = (int64_t)std::floor(double(gx + CELL_OFFSET_TILES) / double(CELL_TILES));
		int64_t cy = (int64_t)std::floor(depth / CELL_DEPTH);
		int64_t cz = (int64_t)std::floor(double(gz + CELL_OFFSET_TILES) / double(CELL_TILES));
		const Vein &vein = vein_in_cell(cx, cy, cz);
		if (!vein.present) {
			return nullptr;
		}
		double px = double(gx) + 0.5;
		double pz = double(gz) + 0.5;
		double dx = (px - vein.cx) / vein.radius;
		double dz = (pz - vein.cz) / vein.radius;
		double dy = (depth - vein.cy) / vein.half_height;
		double d = std::sqrt(dx * dx + dy * dy + dz * dz);
		if (d >= 1.0 + SHAPE_NOISE) {
			return nullptr;
		}
		if (d > 1.0 - SHAPE_NOISE) {
			double n = value_noise_3d(ore_mix(seed_v, SALT_SHAPE, 0, 0, 0), px / SHAPE_WAVELENGTH_TILES, depth / SHAPE_WAVELENGTH_DEPTH, pz / SHAPE_WAVELENGTH_TILES);
			if (d + n * SHAPE_NOISE >= 1.0) {
				return nullptr;
			}
		}
		if (!allows(vein.material, depth, f32(px * TILE_SIZE), f32(pz * TILE_SIZE))) {
			return nullptr;
		}
		return &vein;
	}
	bool is_live(const Vein &v) const {
		int64_t taken = (int64_t)depleted.get(v.id, 0);
		return std::max<int64_t>(v.reserve - taken, 0) > 0;
	}
	const Vein *live_vein_at(double wx, double wz, double depth) {
		int64_t gx = (int64_t)std::floor(wx / TILE_SIZE);
		int64_t gz = (int64_t)std::floor(wz / TILE_SIZE);
		const Vein *v = vein_at(gx, gz, depth);
		if (v == nullptr || !is_live(*v)) {
			return nullptr;
		}
		return v;
	}
	String material_for_biome(const String &biome, double wx, double wz, double depth) {
		const Vein *v = live_vein_at(wx, wz, depth);
		return v != nullptr ? v->material : host_material(biome);
	}

	// --- run algebra
	static bool run_less(const Run &a, const Run &b) {
		if (a.bottom != b.bottom) {
			return a.bottom < b.bottom;
		}
		if (a.top != b.top) {
			return a.top < b.top;
		}
		return a.material < b.material;
	}
	static void add_span(Runs &runs, double bottom, double top, const String &material) {
		runs.push_back({ bottom, top, material });
		std::stable_sort(runs.begin(), runs.end(), run_less);
		Runs merged;
		for (const Run &run : runs) {
			if (merged.empty()) {
				merged.push_back(run);
				continue;
			}
			Run &prev = merged.back();
			bool touches = run.bottom <= prev.top + 0.000001;
			if (touches && prev.material == run.material) {
				prev.top = std::max(prev.top, run.top);
			} else {
				merged.push_back(run);
			}
		}
		runs = merged;
	}
	static void remove_span(Runs &runs, double bottom, double top) {
		Runs out;
		for (const Run &run : runs) {
			if (top <= run.bottom || bottom >= run.top) {
				out.push_back(run);
				continue;
			}
			if (run.bottom < bottom) {
				out.push_back({ run.bottom, bottom, run.material });
			}
			if (run.top > top) {
				out.push_back({ top, run.top, run.material });
			}
		}
		runs = out;
	}
	static void apply_ops(Runs &runs, const Array &ops) {
		for (int i = 0; i < ops.size(); i++) {
			if (ops[i].get_type() != Variant::DICTIONARY) {
				continue;
			}
			Dictionary o = ops[i];
			double bottom = o.get("bottom", 0.0);
			double top = o.get("top", 0.0);
			if (top <= bottom) {
				continue;
			}
			String kind = o.get("op", "");
			if (kind == "add") {
				add_span(runs, bottom, top, String(o.get("material", "")));
			} else if (kind == "remove") {
				remove_span(runs, bottom, top);
			}
		}
	}

	const Runs &column_runs(const Array &hm, int64_t cpx, int64_t cpz, int64_t tx, int64_t tz) {
		int64_t gx = cpx * CHUNK_SIZE + tx;
		int64_t gz = cpz * CHUNK_SIZE + tz;
		TileId id(wrap_x_tile(gx), gz);
		auto it = columns.find(id);
		if (it != columns.end()) {
			return it->second;
		}
		double top = voxel_height((double)hm[tz * CHUNK_SIZE + tx]);
		Runs runs;
		if (top > BEDROCK_DEPTH) {
			runs.push_back({ BEDROCK_DEPTH, top, String() });
		}
		if (!edits.is_empty()) {
			Variant ops = edits.get(tile_key(gx, gz), Variant());
			if (ops.get_type() == Variant::ARRAY) {
				apply_ops(runs, ops);
			}
		}
		return columns.emplace(id, runs).first->second;
	}
	// The ring neighbour's runs; empty when its chunk is unknown.
	Runs neighbour_runs(const Array &hm, int64_t cpx, int64_t cpz, int64_t tx, int64_t tz) {
		if (tx >= 0 && tx < CHUNK_SIZE && tz >= 0 && tz < CHUNK_SIZE) {
			return column_runs(hm, cpx, cpz, tx, tz);
		}
		int64_t gx = cpx * CHUNK_SIZE + tx;
		int64_t gz = cpz * CHUNK_SIZE + tz;
		int64_t cx = floor_div64(gx);
		int64_t cz = floor_div64(gz);
		String ckey = chunk_key(cx, cz);
		if (!neighbours.has(ckey)) {
			return Runs();
		}
		Array nhm = neighbours[ckey];
		return column_runs(nhm, cx, cz, gx - cx * CHUNK_SIZE, gz - cz * CHUNK_SIZE);
	}
	double natural_top(const Array &hm, int64_t cpx, int64_t cpz, int64_t tx, int64_t tz) const {
		if (tx >= 0 && tx < CHUNK_SIZE && tz >= 0 && tz < CHUNK_SIZE) {
			return voxel_height((double)hm[tz * CHUNK_SIZE + tx]);
		}
		int64_t gx = cpx * CHUNK_SIZE + tx;
		int64_t gz = cpz * CHUNK_SIZE + tz;
		int64_t cx = floor_div64(gx);
		int64_t cz = floor_div64(gz);
		Variant nhm = neighbours.get(chunk_key(cx, cz), Variant());
		if (nhm.get_type() != Variant::ARRAY) {
			return std::nan("");
		}
		Array a = nhm;
		return voxel_height((double)a[(gz - cz * CHUNK_SIZE) * CHUNK_SIZE + (gx - cx * CHUNK_SIZE)]);
	}

	// --- biome dither
	static double roll(int64_t gx, int64_t gz) {
		return double((mul(gx, 73856093) ^ mul(gz, 19349663)) & 0xffff) / 65536.0;
	}
	static double chance(double d, double band) {
		if (d >= band || band <= 0.0) {
			return 0.0;
		}
		return BLEND_MAX_CHANCE * (1.0 - std::max(d, 0.0) / band);
	}
	static bool wears_neighbour(int64_t gx, int64_t gz, double d, double band) {
		return roll(gx, gz) < chance(d, band);
	}
	String blended_biome(double wx, double wz, const String &own) const {
		double extent = CHUNK_METERS;
		int64_t cx = (int64_t)std::floor(wx / extent);
		int64_t cz = (int64_t)std::floor(wz / extent);
		double lx = wx - double(cx) * extent;
		double lz = wz - double(cz) * extent;
		double dx = std::min(lx, extent - lx) / TILE_SIZE;
		double dz = std::min(lz, extent - lz) / TILE_SIZE;
		if (std::min(dx, dz) >= BLEND_TILES) {
			return own;
		}
		int sx = lx < extent - lx ? -1 : 1;
		int sz = lz < extent - lz ? -1 : 1;
		int64_t gx = (int64_t)std::floor(wx / TILE_SIZE);
		int64_t gz = (int64_t)std::floor(wz / TILE_SIZE);
		String bx = biome_or(cx + sx, cz, own);
		String bz = biome_or(cx, cz + sz, own);
		String bd = biome_or(cx + sx, cz + sz, own);
		double dd = std::max(dx, dz);
		if (dd < BLEND_TILES && bd != own && 0.5 * (roll(gx, gz) + roll(gz, gx)) < 0.5 * chance(dd, BLEND_TILES)) {
			return bd;
		}
		bool wx_ = bx != own && wears_neighbour(gx, gz, dx, BLEND_TILES);
		bool wz_ = bz != own && wears_neighbour(gz, gx, dz, BLEND_TILES);
		if (wx_ && wz_) {
			if (dx < dz) {
				return bx;
			}
			if (dz < dx) {
				return bz;
			}
			return bd != own ? bd : bx;
		}
		if (wx_) {
			return bx;
		}
		if (wz_) {
			return bz;
		}
		return own;
	}

	// --- colour
	Color run_color(const Run &run, double wx, double wz, double surface) {
		if (!run.material.is_empty()) {
			return material_color(run.material);
		}
		double depth = std::isnan(surface) ? 0.0 : surface - (run.top - STEP_HEIGHT * 0.5);
		String material = material_for_biome(biome_of(wx, wz), wx, wz, depth);
		return icy(material_color(material), wz);
	}
	void apply_topsoil(Dictionary &entry, const Run &run, double wx, double wz, double surface) {
		if (!run.material.is_empty() || std::isnan(surface) || std::fabs(run.top - surface) > STEP_HEIGHT * 0.25) {
			return;
		}
		String biome = biome_of(wx, wz);
		String shown = blended_biome(wx, wz, biome);
		auto it = styles.find(shown);
		if (it == styles.end()) {
			return;
		}
		if (material_for_biome(biome, wx, wz, 0.0) != host_material(biome)) {
			return;
		}
		entry[k.top_color] = icy(it->second.top, wz);
		entry[k.soil_color] = icy(it->second.soil, wz);
		entry[k.soil_depth] = it->second.depth;
	}
};

// Fill `ctx` from a build input and the runs cfg (`VoxelSlice.native_runs_cfg`). False on a cfg it cannot read.
bool load_ctx(Ctx &ctx, const Dictionary &p_input, const Dictionary &p_cfg) {
	ctx.seed_v = (int64_t)p_input.get("seed", 0);
	ctx.edits = p_input.get("edits", Dictionary());
	ctx.neighbours = p_input.get("neighbour_heightmaps", Dictionary());
	ctx.biomes = p_input.get("biomes", Dictionary());
	ctx.depleted = p_input.get("depleted", Dictionary());
	ctx.circ = (int64_t)p_cfg.get("circumference_chunks", 4);
	ctx.pole = ctx.circ / 4;
	ctx.fallback_color = p_cfg.get("fallback_color", Color());
	ctx.ice_color = p_cfg.get("ice_color", Color());
	ctx.vein_cell = p_cfg.get("vein_cell", Callable());
	if (!ctx.vein_cell.is_valid()) {
		return false;
	}
	Dictionary colors = p_cfg.get("colors", Dictionary());
	Array keys = colors.keys();
	for (int i = 0; i < keys.size(); i++) {
		ctx.color_map[String(keys[i])] = colors[keys[i]];
	}
	Dictionary host = p_cfg.get("host", Dictionary());
	keys = host.keys();
	for (int i = 0; i < keys.size(); i++) {
		ctx.host_map[String(keys[i])] = String(host[keys[i]]);
	}
	Dictionary styles = p_cfg.get("styles", Dictionary());
	keys = styles.keys();
	for (int i = 0; i < keys.size(); i++) {
		Dictionary s = styles[keys[i]];
		Style st;
		st.top = s["top"];
		st.soil = s["soil"];
		st.depth = s["depth"];
		ctx.styles[String(keys[i])] = st;
	}
	Dictionary bands = p_cfg.get("bands", Dictionary());
	keys = bands.keys();
	for (int i = 0; i < keys.size(); i++) {
		Dictionary b = bands[keys[i]];
		Band band;
		band.min_d = b["min"];
		band.max_d = b["max"];
		band.ley = b["ley"];
		ctx.bands[String(keys[i])] = band;
	}
	return true;
}

} // namespace

Dictionary NativeChunkBuilder::build_runs(const Vector2i &p_chunk, const Array &p_heightmap, const Dictionary &p_input, const Dictionary &p_cfg) const {
	Dictionary result;
	ERR_FAIL_COND_V(p_heightmap.size() != CHUNK_SIZE * CHUNK_SIZE, result);
	Ctx ctx;
	ERR_FAIL_COND_V(!load_ctx(ctx, p_input, p_cfg), result);

	const int64_t cpx = p_chunk.x;
	const int64_t cpz = p_chunk.y;
	Dictionary out;
	for (int64_t tz = -1; tz < CHUNK_SIZE + 1; tz++) {
		for (int64_t tx = -1; tx < CHUNK_SIZE + 1; tx++) {
			int64_t gx = cpx * CHUNK_SIZE + tx;
			int64_t gz = cpz * CHUNK_SIZE + tz;
			double wx = f32(double(gx) * TILE_SIZE + TILE_SIZE * 0.5);
			double wz = f32(double(gz) * TILE_SIZE + TILE_SIZE * 0.5);
			double surface = ctx.natural_top(p_heightmap, cpx, cpz, tx, tz);
			Runs runs = ctx.neighbour_runs(p_heightmap, cpx, cpz, tx, tz);
			Array coloured;
			for (const Run &run : runs) {
				Dictionary entry;
				entry[ctx.k.bottom] = run.bottom;
				entry[ctx.k.top] = run.top;
				entry[ctx.k.material] = run.material;
				entry[ctx.k.color] = ctx.run_color(run, wx, wz, surface);
				ctx.apply_topsoil(entry, run, wx, wz, surface);
				coloured.push_back(entry);
			}
			out[ctx.tile_key(gx, gz)] = coloured;
		}
	}

	// Vein deposit markers: the chunk's own columns only.
	Array deposits;
	Vector3 deposit_size((real_t)(TILE_SIZE - VEIN_DEPOSIT_INSET * 2.0), (real_t)VEIN_DEPOSIT_HEIGHT, (real_t)(TILE_SIZE - VEIN_DEPOSIT_INSET * 2.0));
	for (int64_t tz = 0; tz < CHUNK_SIZE; tz++) {
		for (int64_t tx = 0; tx < CHUNK_SIZE; tx++) {
			const Runs &runs = ctx.column_runs(p_heightmap, cpx, cpz, tx, tz);
			if (runs.empty()) {
				continue;
			}
			const Run &surface = runs.back();
			if (!surface.material.is_empty()) {
				continue;
			}
			double h = surface.top;
			double wx = f32(double(cpx * CHUNK_SIZE + tx) * TILE_SIZE + TILE_SIZE * 0.5);
			double wz = f32(double(cpz * CHUNK_SIZE + tz) * TILE_SIZE + TILE_SIZE * 0.5);
			double nat = voxel_height((double)p_heightmap[tz * CHUNK_SIZE + tx]);
			double depth = nat - (surface.top - STEP_HEIGHT * 0.5);
			const Vein *vein = ctx.live_vein_at(wx, wz, depth);
			if (vein == nullptr) {
				continue;
			}
			Dictionary d;
			d["position"] = Vector3((real_t)wx, (real_t)(h + VEIN_DEPOSIT_HEIGHT * 0.5), (real_t)wz);
			d["local_position"] = Vector3((real_t)((double(tx) + 0.5) * TILE_SIZE), (real_t)(h + VEIN_DEPOSIT_HEIGHT * 0.5), (real_t)((double(tz) + 0.5) * TILE_SIZE));
			d["size"] = deposit_size;
			d["color"] = ctx.material_color(vein->material);
			deposits.push_back(d);
		}
	}
	result["runs"] = out;
	result["deposits"] = deposits;
	return result;
}

// Phase 190 — `VoxelCoarse.coarse_columns`: one resolved column per cell of `step`x`step` tiles, at the
// highest natural top of the cell (first in row-major order on a tie), coloured by that tile's biome: its
// host rock and the topsoil of the biome it shows (no ore field). Empty on an input it cannot read.
Dictionary NativeChunkBuilder::coarse_columns(const Vector2i &p_chunk, const Array &p_heightmap, const Dictionary &p_input, int64_t p_step, const Dictionary &p_cfg) const {
	Dictionary result;
	ERR_FAIL_COND_V(p_heightmap.size() != CHUNK_SIZE * CHUNK_SIZE, result);
	ERR_FAIL_COND_V(p_step < 1 || CHUNK_SIZE % p_step != 0, result);
	Ctx ctx;
	ERR_FAIL_COND_V(!load_ctx(ctx, p_input, p_cfg), result);
	std::vector<double> hm(CHUNK_SIZE * CHUNK_SIZE);
	for (int i = 0; i < CHUNK_SIZE * CHUNK_SIZE; i++) {
		Variant h = p_heightmap[i];
		ERR_FAIL_COND_V(h.get_type() != Variant::FLOAT && h.get_type() != Variant::INT, result);
		hm[i] = double(h);
	}
	const int64_t n = CHUNK_SIZE / p_step;
	PackedFloat64Array tops, soil_depths;
	PackedColorArray colors, top_colors, soil_colors;
	tops.resize(n * n);
	soil_depths.resize(n * n);
	colors.resize(n * n);
	top_colors.resize(n * n);
	soil_colors.resize(n * n);
	for (int64_t cz = 0; cz < n; cz++) {
		for (int64_t cx = 0; cx < n; cx++) {
			double best = -INFINITY;
			int64_t btx = 0, btz = 0;
			for (int64_t dz = 0; dz < p_step; dz++) {
				for (int64_t dx = 0; dx < p_step; dx++) {
					int64_t tx = cx * p_step + dx;
					int64_t tz = cz * p_step + dz;
					double h = voxel_height(hm[tz * CHUNK_SIZE + tx]);
					if (h > best) {
						best = h;
						btx = tx;
						btz = tz;
					}
				}
			}
			int64_t i = cz * n + cx;
			tops.set(i, best);
			if (best <= BEDROCK_DEPTH) {
				colors.set(i, ctx.fallback_color);
				top_colors.set(i, ctx.fallback_color);
				soil_colors.set(i, ctx.fallback_color);
				soil_depths.set(i, 0.0);
				continue;
			}
			int64_t gx = int64_t(p_chunk.x) * CHUNK_SIZE + btx;
			int64_t gz = int64_t(p_chunk.y) * CHUNK_SIZE + btz;
			double wx = f32(double(gx) * TILE_SIZE + TILE_SIZE * 0.5);
			double wz = f32(double(gz) * TILE_SIZE + TILE_SIZE * 0.5);
			String biome = ctx.biome_of(wx, wz);
			Color color = ctx.icy(ctx.material_color(ctx.host_material(biome)), wz);
			colors.set(i, color);
			auto st = ctx.styles.find(ctx.blended_biome(wx, wz, biome));
			if (st == ctx.styles.end()) {
				top_colors.set(i, color);
				soil_colors.set(i, color);
				soil_depths.set(i, 0.0);
			} else {
				top_colors.set(i, ctx.icy(st->second.top, wz));
				soil_colors.set(i, ctx.icy(st->second.soil, wz));
				soil_depths.set(i, st->second.depth);
			}
		}
	}
	result["tops"] = tops;
	result["colors"] = colors;
	result["top_colors"] = top_colors;
	result["soil_colors"] = soil_colors;
	result["soil_depths"] = soil_depths;
	return result;
}
