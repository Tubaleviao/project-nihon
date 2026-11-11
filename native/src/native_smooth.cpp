// Phase 240 — NativeChunkBuilder::build_smooth_arrays, the port of `VoxelSmooth.build_natural_arrays`:
// the surface-nets mesher over the natural runs. Phase 241 — `mesh_coarse_columns`, the port of
// `VoxelSmooth.mesh_coarse_columns`: the same mesher on a coarse build's columns (every spacing scaled by
// the step, the padding repeating the edge columns), with skirts down to bedrock under the chunk's edge. The GDScript (src/terrain/voxel_smooth.gd) is the
// reference and every expression mirrors it, including where a value is narrowed to float32 (a
// PackedFloat32Array sample, a Vector3 component) and the order vertices are made in, so the parity
// test can compare the arrays exactly.
//
// The corner-gradient normals and the sample padding follow godot_voxel's Transvoxel mesher
// (meshers/transvoxel/transvoxel.cpp, commit dfb0f81c7fd766f68d78715b2138f4e336cd9737). The algorithm
// is ported, not the code. MIT License, Copyright (c) 2016-2024 Marc Gilleron: permission is granted
// to use, copy, modify, merge, publish, distribute, sublicense and sell copies, provided this notice
// is kept. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
#include "native_chunk_builder.h"

#include "base/marshal.h"
#include "base/nihon_math.h"

#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <algorithm>
#include <cmath>
#include <unordered_map>
#include <unordered_set>
#include <vector>

using namespace godot;

namespace {

using namespace nihon;

const int CHUNK_SIZE = 64;
const double TILE_SIZE = 0.5;
const double STEP_HEIGHT = 0.125;
const double BEDROCK_DEPTH = -96.0;
const double GRID = 0.5;
const double CLAMP = 1.5;
const double INSIDE_MIN = 0.0001;
const int PAD = 2;
const int SPAN = CHUNK_SIZE + 2 * PAD;
const double TOP_BAND = 0.3;
const int64_t LEVEL_OFFSET = 1024;

const int EDGES[12][2] = { { 0, 1 }, { 2, 3 }, { 4, 5 }, { 6, 7 }, { 0, 2 }, { 1, 3 }, { 4, 6 }, { 5, 7 }, { 0, 4 }, { 1, 5 }, { 2, 6 }, { 3, 7 } };

struct SRun {
	double bottom = 0.0;
	double top = 0.0;
	Color color;
	Color top_color;
	Color soil_color;
	double soil_depth = 0.0;
};

struct SKeys {
	Variant bottom = String("bottom");
	Variant top = String("top");
	Variant material = String("material");
	Variant color = String("color");
	Variant top_color = String("top_color");
	Variant soil_color = String("soil_color");
	Variant soil_depth = String("soil_depth");
};

inline int64_t floori(double x) { return (int64_t)std::floor(x); }
inline int64_t ceili(double x) { return (int64_t)std::ceil(x); }
inline int64_t roundi(double x) { return (int64_t)std::round(x); }

const uint8_t SIDE_WEST = 1;
const uint8_t SIDE_EAST = 2;
const uint8_t SIDE_NORTH = 4;
const uint8_t SIDE_SOUTH = 8;

class Smooth {
public:
	SKeys k;
	// The grid (see `_Mesher` in voxel_smooth.gd): step 1 for a full build.
	int n = CHUNK_SIZE;
	int span = SPAN;
	double cell = TILE_SIZE;
	double grid = GRID;
	double clamp_d = CLAMP;
	bool skirted = false;
	Vector2i chunk;
	int64_t lap_tiles = 0;
	Color fallback;
	double origin_x = 0.0;
	double origin_z = 0.0;
	std::vector<double> hm;
	const Dictionary *runs = nullptr;

	std::vector<std::vector<SRun>> col_runs;
	std::vector<uint8_t> col_known;
	std::vector<int64_t> col_lo;
	std::vector<std::vector<float>> col_vals;
	std::unordered_map<int64_t, int32_t> cells;
	std::unordered_map<int64_t, Vector3> grads;
	std::vector<Vector3> vertices, normals, collision;
	std::vector<Color> colors;
	std::vector<int32_t> indices;
	std::vector<uint8_t> sides;
	int64_t quads = 0;

	void set_step(int step) {
		n = CHUNK_SIZE / step;
		span = n + 2 * PAD;
		cell = TILE_SIZE * double(step);
		grid = GRID * double(step);
		clamp_d = CLAMP * double(step);
	}

	String tile_key(int64_t gx, int64_t gz) const {
		int64_t half = lap_tiles / 2;
		int64_t x = posmod(gx + half, lap_tiles) - half;
		return String::num_int64(x) + "," + String::num_int64(gz);
	}

	// Reads one column's runs; `natural` keeps those with no material. False on a malformed table.
	bool read_column(const Variant &v, std::vector<SRun> &natural, bool &any) const {
		if (v.get_type() != Variant::ARRAY) {
			return false;
		}
		Array a = v;
		any = a.size() > 0;
		for (int i = 0; i < a.size(); i++) {
			if (a[i].get_type() != Variant::DICTIONARY) {
				return false;
			}
			Dictionary d = a[i];
			Variant b = d.get(k.bottom, Variant());
			Variant t = d.get(k.top, Variant());
			if (!is_number(b) || !is_number(t)) {
				return false;
			}
			Variant m = d.get(k.material, String());
			if (String(m) != String()) {
				continue;
			}
			SRun r;
			r.bottom = double(b);
			r.top = double(t);
			Variant c = d.get(k.color, fallback);
			if (c.get_type() != Variant::COLOR) {
				return false;
			}
			r.color = c;
			Variant tc = d.get(k.top_color, r.color);
			Variant sc = d.get(k.soil_color, r.color);
			Variant sd = d.get(k.soil_depth, 0.0);
			if (tc.get_type() != Variant::COLOR || sc.get_type() != Variant::COLOR || !is_number(sd)) {
				return false;
			}
			r.top_color = tc;
			r.soil_color = sc;
			r.soil_depth = double(sd);
			natural.push_back(r);
		}
		return true;
	}

	void alloc() {
		col_runs.assign(span * span, std::vector<SRun>());
		col_known.assign(span * span, 0);
		col_lo.assign(span * span, 0);
		col_vals.assign(span * span, std::vector<float>());
	}

	// A coarse build's columns: one run from bedrock to each cell's top (none at or below bedrock); the
	// padding repeats the nearest edge column.
	void load_columns(const PackedFloat64Array &tops, const PackedColorArray &c_colors, const PackedColorArray &top_colors,
			const PackedColorArray &soil_colors, const PackedFloat64Array &soil_depths) {
		alloc();
		for (int tz = 0; tz < n; tz++) {
			for (int tx = 0; tx < n; tx++) {
				int i = tz * n + tx;
				int ci = (tz + PAD) * span + (tx + PAD);
				if (tops[i] > BEDROCK_DEPTH) {
					SRun r;
					r.bottom = BEDROCK_DEPTH;
					r.top = tops[i];
					r.color = c_colors[i];
					r.top_color = top_colors[i];
					r.soil_color = soil_colors[i];
					r.soil_depth = soil_depths[i];
					col_runs[ci].push_back(r);
				}
				col_known[ci] = 1;
				sample_column(ci);
			}
		}
		for (int tz = -PAD; tz < n + PAD; tz++) {
			for (int tx = -PAD; tx < n + PAD; tx++) {
				if (tx >= 0 && tx < n && tz >= 0 && tz < n) {
					continue;
				}
				int ci = (tz + PAD) * span + (tx + PAD);
				int src = (std::clamp(tz, 0, n - 1) + PAD) * span + (std::clamp(tx, 0, n - 1) + PAD);
				col_runs[ci] = col_runs[src];
				col_known[ci] = col_known[src];
				col_lo[ci] = col_lo[src];
				col_vals[ci] = col_vals[src];
			}
		}
	}

	bool load() {
		alloc();
		for (int tz = -PAD; tz < CHUNK_SIZE + PAD; tz++) {
			for (int tx = -PAD; tx < CHUNK_SIZE + PAD; tx++) {
				int ci = (tz + PAD) * span + (tx + PAD);
				bool inside = tx >= 0 && tx < CHUNK_SIZE && tz >= 0 && tz < CHUNK_SIZE;
				Variant key = tile_key(int64_t(chunk.x) * CHUNK_SIZE + tx, int64_t(chunk.y) * CHUNK_SIZE + tz);
				bool any = false;
				if (runs->has(key)) {
					if (!read_column(runs->get(key, Variant()), col_runs[ci], any)) {
						return false;
					}
				} else if (inside) {
					double top = std::floor(hm[tz * CHUNK_SIZE + tx] / STEP_HEIGHT) * STEP_HEIGHT;
					if (top > BEDROCK_DEPTH) {
						SRun r;
						r.bottom = BEDROCK_DEPTH;
						r.top = top;
						r.color = r.top_color = r.soil_color = fallback;
						col_runs[ci].push_back(r);
						any = true;
					}
				}
				col_known[ci] = any ? 1 : 0;
				sample_column(ci);
			}
		}
		return true;
	}

	static double density(const std::vector<SRun> &rs, double y, double limit) {
		double best = limit;
		for (const SRun &r : rs) {
			bool floor_open = r.bottom > BEDROCK_DEPTH;
			if (y < r.top && (y >= r.bottom || !floor_open)) {
				double d = r.top - y;
				if (floor_open) {
					d = std::min(d, y - r.bottom);
				}
				return -std::clamp(d, INSIDE_MIN, limit);
			}
			if (y >= r.top) {
				best = std::min(best, y - r.top);
			} else if (floor_open && y < r.bottom) {
				best = std::min(best, r.bottom - y);
			}
		}
		return best;
	}

	void sample_column(int ci) {
		const std::vector<SRun> &rs = col_runs[ci];
		double lo_y = INFINITY;
		double hi_y = -INFINITY;
		for (const SRun &r : rs) {
			lo_y = std::min(lo_y, r.top);
			hi_y = std::max(hi_y, r.top);
			if (r.bottom > BEDROCK_DEPTH) {
				lo_y = std::min(lo_y, r.bottom);
				hi_y = std::max(hi_y, r.bottom);
			}
		}
		std::vector<float> &vals = col_vals[ci];
		if (lo_y == INFINITY) {
			col_lo[ci] = 0;
			vals.push_back(float(clamp_d));
			return;
		}
		int64_t lo = floori((lo_y - clamp_d) / grid) - 1;
		int64_t hi = ceili((hi_y + clamp_d) / grid) + 1;
		col_lo[ci] = lo;
		vals.resize(hi - lo + 1);
		for (int64_t j = lo; j <= hi; j++) {
			vals[j - lo] = float(density(rs, double(j) * grid, clamp_d));
		}
	}

	double s(int tx, int tz, int64_t j) const {
		int ci = (tz + PAD) * span + (tx + PAD);
		const std::vector<float> &vals = col_vals[ci];
		return double(vals[std::clamp<int64_t>(j - col_lo[ci], 0, int64_t(vals.size()) - 1)]);
	}

	// x = lo, y = hi; an unknown column has none (lo > hi).
	void range(int ci, int64_t &lo, int64_t &hi) const {
		if (col_known[ci] == 0) {
			lo = 1;
			hi = 0;
			return;
		}
		lo = col_lo[ci];
		hi = col_lo[ci] + int64_t(col_vals[ci].size()) - 1;
	}

	void build() {
		for (int tz = 0; tz < n; tz++) {
			for (int tx = 0; tx < n; tx++) {
				int ci = (tz + PAD) * span + (tx + PAD);
				int64_t olo, ohi;
				range(ci, olo, ohi);
				const std::vector<float> &vals = col_vals[ci];
				int64_t lo = col_lo[ci];
				for (int64_t j = olo; j < ohi; j++) {
					if ((double(vals[j - lo]) < 0.0) != (double(vals[j + 1 - lo]) < 0.0)) {
						y_quad(tx, tz, j);
					}
				}
				side_edges(tx, tz, ci, ci + 1, olo, ohi, 0);
				side_edges(tx, tz, ci, ci + span, olo, ohi, 1);
			}
		}
	}

	void side_edges(int tx, int tz, int ci, int ni, int64_t olo, int64_t ohi, int axis) {
		int64_t xlo, xhi;
		range(ni, xlo, xhi);
		int64_t lo = olo;
		int64_t hi = ohi;
		if (xlo <= xhi) {
			lo = olo <= ohi ? std::min(lo, xlo) : xlo;
			hi = olo <= ohi ? std::max(hi, xhi) : xhi;
		}
		if (lo > hi) {
			return;
		}
		const std::vector<float> &a_vals = col_vals[ci];
		int64_t a_lo = col_lo[ci];
		int64_t a_n = int64_t(a_vals.size()) - 1;
		const std::vector<float> &b_vals = col_vals[ni];
		int64_t b_lo = col_lo[ni];
		int64_t b_n = int64_t(b_vals.size()) - 1;
		for (int64_t j = lo; j <= hi; j++) {
			double a = a_vals[std::clamp<int64_t>(j - a_lo, 0, a_n)];
			double b = b_vals[std::clamp<int64_t>(j - b_lo, 0, b_n)];
			if ((a < 0.0) != (b < 0.0)) {
				if (axis == 0) {
					x_quad(tx, tz, j, a < 0.0);
				} else {
					z_quad(tx, tz, j, a < 0.0);
				}
			}
		}
	}

	Vector3 pos(int sx, int sz, int64_t j) const {
		return Vector3((sx + 0.5) * cell, double(j) * grid, (sz + 0.5) * cell);
	}

	Vector3 gradient(int sx, int sz, int64_t j) {
		int64_t key = ((j + LEVEL_OFFSET) * span + (sz + PAD)) * span + (sx + PAD);
		auto it = grads.find(key);
		if (it != grads.end()) {
			return it->second;
		}
		int ci = (sz + PAD) * span + (sx + PAD);
		const std::vector<float> &vals = col_vals[ci];
		int64_t lo = col_lo[ci];
		int64_t last = int64_t(vals.size()) - 1;
		Vector3 g(
				s(sx + 1, sz, j) - s(sx - 1, sz, j),
				double(vals[std::clamp<int64_t>(j + 1 - lo, 0, last)]) - double(vals[std::clamp<int64_t>(j - 1 - lo, 0, last)]),
				s(sx, sz + 1, j) - s(sx, sz - 1, j));
		grads[key] = g;
		return g;
	}

	static Vector3 corner(int c) {
		return Vector3(c & 1, (c >> 1) & 1, (c >> 2) & 1);
	}

	int32_t add_vertex(const Vector3 &p, const Vector3 &g, const Color &color, uint8_t side = 0) {
		vertices.push_back(Vector3(double(p.x) + origin_x, p.y, double(p.z) + origin_z));
		normals.push_back(double(g.length_squared()) > 1e-12 ? g.normalized() : Vector3(0, 1, 0));
		colors.push_back(color);
		if (skirted) {
			sides.push_back(side);
		}
		return int32_t(vertices.size()) - 1;
	}

	static Color color_at(const std::vector<SRun> &rs, double y) {
		const SRun *best = &rs[0];
		double best_d = INFINITY;
		for (const SRun &r : rs) {
			double d = std::max(std::max(r.bottom - y, y - r.top), 0.0);
			if (d < best_d) {
				best_d = d;
				best = &r;
			}
		}
		if (y >= best->top - TOP_BAND) {
			return best->top_color;
		}
		if (y >= best->top - best->soil_depth) {
			return best->soil_color;
		}
		return best->color;
	}

	Color cell_color(int cx, int cz, const Vector3 &p, const Vector3 &u) const {
		int rx = int(roundi(double(u.x)));
		int rz = int(roundi(double(u.z)));
		const int order[4][2] = { { rx, rz }, { rx, 1 - rz }, { 1 - rx, rz }, { 1 - rx, 1 - rz } };
		for (const auto &o : order) {
			const std::vector<SRun> &rs = col_runs[(cz + o[1] + PAD) * span + (cx + o[0] + PAD)];
			if (!rs.empty()) {
				return color_at(rs, double(p.y));
			}
		}
		return fallback;
	}

	int32_t vertex(int cx, int cz, int64_t j) {
		int64_t key = ((j + LEVEL_OFFSET) * span + (cz + PAD)) * span + (cx + PAD);
		auto it = cells.find(key);
		if (it != cells.end()) {
			return it->second;
		}
		double v[8];
		for (int c = 0; c < 8; c++) {
			v[c] = s(cx + (c & 1), cz + ((c >> 2) & 1), j + ((c >> 1) & 1));
		}
		Vector3 sum;
		int count = 0;
		for (const auto &e : EDGES) {
			int a = e[0];
			int b = e[1];
			if ((v[a] < 0.0) == (v[b] < 0.0)) {
				continue;
			}
			double t = v[a] / (v[a] - v[b]);
			sum += corner(a).lerp(corner(b), real_t(t));
			count++;
		}
		Vector3 u = count > 0 ? sum / real_t(count) : Vector3(0.5, 0.5, 0.5);
		Vector3 p = pos(cx, cz, j) + Vector3(double(u.x) * cell, double(u.y) * grid, double(u.z) * cell);
		if (skirted) {
			// Coarse: pinned to the shared cell corner, as high as the tallest cell round it (see `_vertex`).
			double cap = double(p.y);
			for (int c = 0; c < 4; c++) {
				for (const SRun &r : col_runs[(cz + (c >> 1) + PAD) * span + (cx + (c & 1) + PAD)]) {
					cap = std::max(cap, r.top);
				}
			}
			p = Vector3((cx + 1) * cell, cap, (cz + 1) * cell);
		}
		Vector3 g;
		for (int c = 0; c < 8; c++) {
			int dx = c & 1;
			int dy = (c >> 1) & 1;
			int dz = (c >> 2) & 1;
			double w = (dx == 1 ? double(u.x) : 1.0 - double(u.x)) * (dy == 1 ? double(u.y) : 1.0 - double(u.y)) * (dz == 1 ? double(u.z) : 1.0 - double(u.z));
			if (w > 0.0) {
				g += gradient(cx + dx, cz + dz, j + dy) * real_t(w);
			}
		}
		Color color = cell_color(cx, cz, p, u);
		uint8_t side = 0;
		if (skirted) {
			if (cx == -1) {
				side |= SIDE_WEST;
			} else if (cx == n - 1) {
				side |= SIDE_EAST;
			}
			if (cz == -1) {
				side |= SIDE_NORTH;
			} else if (cz == n - 1) {
				side |= SIDE_SOUTH;
			}
		}
		int32_t idx = add_vertex(p, g, color, side);
		cells[key] = idx;
		return idx;
	}

	void tri(int32_t a, int32_t b, int32_t c) {
		if (skirted && (vertices[a] == vertices[b] || vertices[b] == vertices[c] || vertices[a] == vertices[c])) {
			return; // a coarse cliff's collapsed quad
		}
		indices.push_back(a);
		indices.push_back(b);
		indices.push_back(c);
		collision.push_back(vertices[a]);
		collision.push_back(vertices[b]);
		collision.push_back(vertices[c]);
	}

	void y_quad(int tx, int tz, int64_t j) {
		double below = s(tx, tz, j);
		double above = s(tx, tz, j + 1);
		bool up = below < 0.0;
		const std::vector<SRun> &rs = col_runs[(tz + PAD) * span + (tx + PAD)];
		double y0 = double(j) * grid;
		double y = y0 + grid * (below / (below - above));
		Color color = fallback;
		int found = 0;
		for (const SRun &r : rs) {
			double b = up ? r.top : r.bottom;
			if (b > y0 && b <= y0 + grid && (up || b > BEDROCK_DEPTH)) {
				found++;
				y = b;
				color = up ? r.top_color : r.color;
			}
		}
		if (found != 1) {
			color = rs.empty() ? fallback : color_at(rs, y);
		}
		double t = std::clamp((y - y0) / grid, 0.0, 1.0);
		Vector3 g0 = gradient(tx, tz, j);
		Vector3 g1 = gradient(tx, tz, j + 1);
		Vector3 g = g0.lerp(g1, real_t(t));
		int32_t centre = add_vertex(Vector3((tx + 0.5) * cell, y, (tz + 0.5) * cell), g, color);
		int32_t ring[4];
		ring[0] = vertex(tx - 1, tz - 1, j);
		ring[1] = vertex(tx, tz - 1, j);
		ring[2] = vertex(tx, tz, j);
		ring[3] = vertex(tx - 1, tz, j);
		if (up) {
			std::reverse(ring, ring + 4);
		}
		for (int c = 0; c < 4; c++) {
			tri(centre, ring[c], ring[(c + 1) % 4]);
		}
		quads++;
	}

	void quad(int32_t *ring) {
		tri(ring[0], ring[1], ring[2]);
		tri(ring[0], ring[2], ring[3]);
		quads++;
	}

	void x_quad(int tx, int tz, int64_t j, bool solid_first) {
		int32_t ring[4];
		ring[0] = vertex(tx, tz - 1, j - 1);
		ring[1] = vertex(tx, tz, j - 1);
		ring[2] = vertex(tx, tz, j);
		ring[3] = vertex(tx, tz - 1, j);
		if (solid_first) {
			std::reverse(ring, ring + 4);
		}
		quad(ring);
	}

	void z_quad(int tx, int tz, int64_t j, bool solid_first) {
		int32_t ring[4];
		ring[0] = vertex(tx - 1, tz, j - 1);
		ring[1] = vertex(tx, tz, j - 1);
		ring[2] = vertex(tx, tz, j);
		ring[3] = vertex(tx - 1, tz, j);
		if (!solid_first) {
			std::reverse(ring, ring + 4);
		}
		quad(ring);
	}

	// Phase 241 — the skirts (see `add_skirts` in voxel_smooth.gd). Returns the skirt quads made.
	int64_t add_skirts() {
		int64_t made = 0;
		std::unordered_set<int64_t> seen;
		size_t tri_end = indices.size();
		int64_t vcount = int64_t(vertices.size());
		static const uint8_t order[4] = { SIDE_WEST, SIDE_EAST, SIDE_NORTH, SIDE_SOUTH };
		for (size_t t = 0; t < tri_end; t += 3) {
			for (int e = 0; e < 3; e++) {
				int32_t a = indices[t + e];
				int32_t b = indices[t + (e + 1) % 3];
				uint8_t common = sides[a] & sides[b];
				if (common == 0) {
					continue;
				}
				for (uint8_t side : order) {
					if ((common & side) == 0) {
						continue;
					}
					int64_t key = (int64_t(std::min(a, b)) * vcount + int64_t(std::max(a, b))) * 16 + side;
					if (!seen.insert(key).second) {
						continue;
					}
					if (skirt(a, b, side)) {
						made++;
					}
				}
			}
		}
		return made;
	}

	bool skirt(int32_t a, int32_t b, uint8_t side) {
		Vector3 pa = vertices[a];
		Vector3 pb = vertices[b];
		bool along_z = side == SIDE_WEST || side == SIDE_EAST;
		double along = along_z ? double(pb.z) - double(pa.z) : double(pb.x) - double(pa.x);
		if (std::abs(along) < 1e-6) {
			return false;
		}
		bool flip = along < 0.0;
		if (side == SIDE_WEST || side == SIDE_SOUTH) {
			flip = !flip;
		}
		if (flip) {
			std::swap(pa, pb);
			std::swap(a, b);
		}
		Vector3 normal = side == SIDE_WEST ? Vector3(-1, 0, 0) : (side == SIDE_EAST ? Vector3(1, 0, 0) : (side == SIDE_NORTH ? Vector3(0, 0, -1) : Vector3(0, 0, 1)));
		Color color = double(pa.y) >= double(pb.y) ? colors[a] : colors[b];
		int32_t base = int32_t(vertices.size());
		const Vector3 quad_pts[4] = {
			pa, pb,
			Vector3(pb.x, BEDROCK_DEPTH, pb.z), Vector3(pa.x, BEDROCK_DEPTH, pa.z)
		};
		for (const Vector3 &p : quad_pts) {
			vertices.push_back(p);
			normals.push_back(normal);
			colors.push_back(color);
			sides.push_back(0);
		}
		tri(base, base + 1, base + 2);
		tri(base, base + 2, base + 3);
		quads++;
		return true;
	}
};

} // namespace

Dictionary NativeChunkBuilder::build_smooth_arrays(const Vector2i &p_chunk, const Array &p_heightmap, const Dictionary &p_resolved, bool p_local, const Dictionary &p_cfg) const {
	Dictionary empty;
	ERR_FAIL_COND_V(p_heightmap.size() != CHUNK_SIZE * CHUNK_SIZE, empty);
	Variant runs_v = p_resolved.get("runs", Dictionary());
	ERR_FAIL_COND_V(runs_v.get_type() != Variant::DICTIONARY, empty);
	Dictionary runs = runs_v;
	int64_t circumference = (int64_t)p_cfg.get("circumference_chunks", 0);
	ERR_FAIL_COND_V(circumference <= 0, empty);
	Variant fb = p_cfg.get("fallback_color", Variant());
	ERR_FAIL_COND_V(fb.get_type() != Variant::COLOR, empty);

	Smooth m;
	m.chunk = p_chunk;
	m.lap_tiles = circumference * CHUNK_SIZE;
	m.fallback = fb;
	m.runs = &runs;
	if (!p_local) {
		m.origin_x = double(int64_t(p_chunk.x) * CHUNK_SIZE) * TILE_SIZE;
		m.origin_z = double(int64_t(p_chunk.y) * CHUNK_SIZE) * TILE_SIZE;
	}
	ERR_FAIL_COND_V(!read_numbers(p_heightmap, CHUNK_SIZE * CHUNK_SIZE, m.hm), empty);
	if (!m.load()) {
		return empty;
	}
	m.build();

	Dictionary out;
	out["vertices"] = to_packed<PackedVector3Array>(m.vertices);
	out["normals"] = to_packed<PackedVector3Array>(m.normals);
	out["colors"] = to_packed<PackedColorArray>(m.colors);
	out["indices"] = to_packed<PackedInt32Array>(m.indices);
	out["collision"] = to_packed<PackedVector3Array>(m.collision);
	out["quad_count"] = m.quads;
	out["cell_count"] = int64_t(m.cells.size());
	out["local"] = p_local;
	return out;
}

Dictionary NativeChunkBuilder::mesh_coarse_columns(const Vector2i &p_chunk, const Dictionary &p_cols, int64_t p_step, bool p_local, const Color &p_fallback) const {
	Dictionary empty;
	ERR_FAIL_COND_V(p_step < 1 || CHUNK_SIZE % p_step != 0, empty);
	const int n = CHUNK_SIZE / int(p_step);
	// Phase 194 (#509) — const: a non-const packed array's operator[] goes through ptrw() (copy-on-write).
	const PackedFloat64Array tops = p_cols.get("tops", PackedFloat64Array());
	const PackedColorArray colors = p_cols.get("colors", PackedColorArray());
	const PackedColorArray top_colors = p_cols.get("top_colors", PackedColorArray());
	const PackedColorArray soil_colors = p_cols.get("soil_colors", PackedColorArray());
	const PackedFloat64Array soil_depths = p_cols.get("soil_depths", PackedFloat64Array());
	const int64_t cells = int64_t(n) * n;
	ERR_FAIL_COND_V(tops.size() != cells || colors.size() != cells || top_colors.size() != cells || soil_colors.size() != cells || soil_depths.size() != cells, empty);

	Smooth m;
	m.chunk = p_chunk;
	m.fallback = p_fallback;
	m.skirted = true;
	m.set_step(int(p_step));
	if (!p_local) {
		m.origin_x = double(int64_t(p_chunk.x) * CHUNK_SIZE) * TILE_SIZE;
		m.origin_z = double(int64_t(p_chunk.y) * CHUNK_SIZE) * TILE_SIZE;
	}
	m.load_columns(tops, colors, top_colors, soil_colors, soil_depths);
	m.build();
	int64_t skirts = m.add_skirts();

	Dictionary out;
	out["vertices"] = to_packed<PackedVector3Array>(m.vertices);
	out["normals"] = to_packed<PackedVector3Array>(m.normals);
	out["colors"] = to_packed<PackedColorArray>(m.colors);
	out["indices"] = to_packed<PackedInt32Array>(m.indices);
	out["collision"] = to_packed<PackedVector3Array>(m.collision);
	out["quad_count"] = m.quads;
	out["cell_count"] = int64_t(m.cells.size());
	out["skirt_quads"] = skirts;
	out["local"] = p_local;
	out["lod"] = p_step;
	return out;
}
