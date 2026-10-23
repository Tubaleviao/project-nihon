// Phase 169 — NativeChunkBuilder::build_chunk_arrays, the port of `VoxelMesh.build_chunk_arrays`:
// the greedy mesher. The GDScript is the reference; every expression mirrors it, including the
// order faces are grouped in (a group's first appearance fixes its place in the output, as a
// GDScript Dictionary's insertion order does) and the float32 narrowing of a Vector3 / Color.
#include "native_chunk_builder.h"

#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <algorithm>
#include <array>
#include <cmath>
#include <map>
#include <tuple>
#include <vector>

using namespace godot;

namespace {

const int CHUNK_SIZE = 64;
const double TILE_SIZE = 0.5;
const double STEP_HEIGHT = 0.125;
const double BEDROCK_DEPTH = -96.0;

struct Run {
	double bottom = 0.0;
	double top = 0.0;
	Color color;
	Color top_color;
	Color soil_color;
	double soil_depth = 0.0;
};

typedef std::vector<Run> Column;

enum Dir { NORTH, SOUTH, WEST, EAST, UP, DOWN, DIR_COUNT };

struct Group {
	double plane = 0.0;
	double bottom = 0.0;
	double top = 0.0;
	Color color;
	std::vector<int> cells;   // tile indices (tz * CHUNK_SIZE + tx), each once
	int cell_count = 0;
};

typedef std::tuple<int32_t, int32_t, int32_t, uint32_t> GroupKey;

struct Bucket {
	std::map<GroupKey, size_t> index;
	std::vector<Group> groups;   // insertion order
};

inline int64_t posmod(int64_t a, int64_t b) {
	int64_t v = a % b;
	if ((v < 0 && b > 0) || (v > 0 && b < 0)) {
		v += b;
	}
	return v;
}

inline double voxel_height(double raw) {
	return std::floor(raw / STEP_HEIGHT) * STEP_HEIGHT;
}

bool runs_cover_y(const Column &col, double y) {
	for (const Run &r : col) {
		if (r.bottom - 0.000001 <= y && y < r.top - 0.000001) {
			return true;
		}
	}
	return false;
}

struct Seg {
	double bottom;
	double top;
};

std::vector<Seg> subtract_runs(const Run &run, const Column &others) {
	std::vector<Seg> segs;
	segs.push_back({ run.bottom, run.top });
	for (const Run &o : others) {
		std::vector<Seg> next;
		for (const Seg &s : segs) {
			if (o.top <= s.bottom || o.bottom >= s.top) {
				next.push_back(s);
				continue;
			}
			if (s.bottom < o.bottom) {
				next.push_back({ s.bottom, o.bottom });
			}
			if (s.top > o.top) {
				next.push_back({ o.top, s.top });
			}
		}
		segs = next;
	}
	return segs;
}

class Mesher {
public:
	Vector2i chunk;
	int64_t lap_tiles = 0;   // circumference in tiles
	Color fallback;
	std::vector<double> hm;
	const Dictionary *runs = nullptr;
	// The 66x66 ring (tile -1..64 in each axis); an empty Column stands for an unknown neighbour.
	std::vector<Column> ring;
	std::array<Bucket, DIR_COUNT> buckets;
	std::vector<int> dir_order;   // dirs in the order their first group appeared

	static int ring_idx(int tx, int tz) {
		return (tz + 1) * (CHUNK_SIZE + 2) + (tx + 1);
	}

	String tile_key(int64_t gx, int64_t gz) const {
		int64_t half = lap_tiles / 2;
		int64_t x = posmod(gx + half, lap_tiles) - half;
		return String::num_int64(x) + "," + String::num_int64(gz);
	}

	// False when the table holds something this port does not understand (caller falls back).
	bool read_column(const Variant &v, Column &out) const {
		if (v.get_type() != Variant::ARRAY) {
			return false;
		}
		Array a = v;
		out.clear();
		out.reserve(a.size());
		for (int i = 0; i < a.size(); i++) {
			if (a[i].get_type() != Variant::DICTIONARY) {
				return false;
			}
			Dictionary d = a[i];
			Run r;
			Variant b = d.get("bottom", Variant());
			Variant t = d.get("top", Variant());
			if ((b.get_type() != Variant::FLOAT && b.get_type() != Variant::INT) || (t.get_type() != Variant::FLOAT && t.get_type() != Variant::INT)) {
				return false;
			}
			r.bottom = double(b);
			r.top = double(t);
			Variant c = d.get("color", fallback);
			if (c.get_type() != Variant::COLOR) {
				return false;
			}
			r.color = c;
			Variant tc = d.get("top_color", r.color);
			Variant sc = d.get("soil_color", r.color);
			if (tc.get_type() != Variant::COLOR || sc.get_type() != Variant::COLOR) {
				return false;
			}
			r.top_color = tc;
			r.soil_color = sc;
			Variant sd = d.get("soil_depth", 0.0);
			if (sd.get_type() != Variant::FLOAT && sd.get_type() != Variant::INT) {
				return false;
			}
			r.soil_depth = double(sd);
			out.push_back(r);
		}
		return true;
	}

	bool load_ring() {
		ring.assign((CHUNK_SIZE + 2) * (CHUNK_SIZE + 2), Column());
		for (int tz = -1; tz <= CHUNK_SIZE; tz++) {
			for (int tx = -1; tx <= CHUNK_SIZE; tx++) {
				bool inside = tx >= 0 && tx < CHUNK_SIZE && tz >= 0 && tz < CHUNK_SIZE;
				if (!inside && (tx == -1 || tx == CHUNK_SIZE) && (tz == -1 || tz == CHUNK_SIZE)) {
					continue;   // a corner is never read: walls look at the four edge neighbours
				}
				int64_t gx = int64_t(chunk.x) * CHUNK_SIZE + tx;
				int64_t gz = int64_t(chunk.y) * CHUNK_SIZE + tz;
				Variant key = tile_key(gx, gz);
				Column &col = ring[ring_idx(tx, tz)];
				if (runs->has(key)) {
					if (!read_column(runs->get(key, Variant()), col)) {
						return false;
					}
				} else if (inside) {
					double top = voxel_height(hm[tz * CHUNK_SIZE + tx]);
					if (top > BEDROCK_DEPTH) {
						Run r;
						r.bottom = BEDROCK_DEPTH;
						r.top = top;
						r.color = r.top_color = r.soil_color = fallback;
						col.push_back(r);
					}
				}   // else the UNKNOWN neighbour: an empty list
			}
		}
		return true;
	}

	void group_cell(int dir, double plane, double bottom, double top, const Color &color, int tx, int tz) {
		// roundi() gives an int64 and Vector4i keeps the low 32 bits, as here.
		GroupKey key((int32_t)(int64_t)std::round(plane * 10000.0), (int32_t)(int64_t)std::round(bottom * 10000.0),
				(int32_t)(int64_t)std::round(top * 10000.0), color.to_rgba32());
		Bucket &b = buckets[dir];
		if (b.groups.empty()) {
			dir_order.push_back(dir);
		}
		auto it = b.index.find(key);
		size_t gi;
		if (it == b.index.end()) {
			gi = b.groups.size();
			b.index[key] = gi;
			b.groups.emplace_back();
			Group &g = b.groups.back();
			g.plane = plane;
			g.bottom = bottom;
			g.top = top;
			g.color = color;
		} else {
			gi = it->second;
		}
		Group &g = b.groups[gi];
		int idx = tz * CHUNK_SIZE + tx;
		// Callers add a tile at most once per group: runs in a column differ in bottom/top.
		g.cells.push_back(idx);
		g.cell_count++;
	}

	double wall_plane(int dir, int tx, int tz) const {
		switch (dir) {
			case NORTH: return double(int64_t(chunk.y) * CHUNK_SIZE) * TILE_SIZE + tz * TILE_SIZE;
			case SOUTH: return double(int64_t(chunk.y) * CHUNK_SIZE) * TILE_SIZE + (tz + 1) * TILE_SIZE;
			case WEST: return double(int64_t(chunk.x) * CHUNK_SIZE) * TILE_SIZE + tx * TILE_SIZE;
			default: return double(int64_t(chunk.x) * CHUNK_SIZE) * TILE_SIZE + (tx + 1) * TILE_SIZE;
		}
	}

	void wall_cells(int tx, int tz, const Run &run) {
		const Color &color = run.color;
		const Color &soil_color = run.soil_color;
		double soil_line = run.top - run.soil_depth;
		static const int dirs[4] = { NORTH, SOUTH, WEST, EAST };
		static const int dx[4] = { 0, 0, -1, 1 };
		static const int dz[4] = { -1, 1, 0, 0 };
		for (int i = 0; i < 4; i++) {
			const Column &neighbour = ring[ring_idx(tx + dx[i], tz + dz[i])];
			for (const Seg &seg : subtract_runs(run, neighbour)) {
				if (seg.top <= seg.bottom) {
					continue;
				}
				double plane = wall_plane(dirs[i], tx, tz);
				if (seg.top <= soil_line) {
					group_cell(dirs[i], plane, seg.bottom, seg.top, color, tx, tz);
				} else if (seg.bottom >= soil_line) {
					group_cell(dirs[i], plane, seg.bottom, seg.top, soil_color, tx, tz);
				} else {
					group_cell(dirs[i], plane, seg.bottom, soil_line, color, tx, tz);
					group_cell(dirs[i], plane, soil_line, seg.top, soil_color, tx, tz);
				}
			}
		}
	}

	void collect() {
		for (int tz = 0; tz < CHUNK_SIZE; tz++) {
			for (int tx = 0; tx < CHUNK_SIZE; tx++) {
				const Column &col = ring[ring_idx(tx, tz)];
				for (const Run &run : col) {
					if (!runs_cover_y(col, run.top + STEP_HEIGHT * 0.5)) {
						group_cell(UP, run.top, run.top, run.top, run.top_color, tx, tz);
					}
					if (run.bottom > BEDROCK_DEPTH && !runs_cover_y(col, run.bottom - STEP_HEIGHT * 0.5)) {
						group_cell(DOWN, run.bottom, run.bottom, run.bottom, run.color, tx, tz);
					}
					wall_cells(tx, tz, run);
				}
			}
		}
	}
};

struct Rect {
	int tx, tz, w, h;
};

// Scratch marks for merge_rects, reused across groups so a group costs O(its cells), not O(chunk).
// A tile is "present" when mark == stamp and "used" when mark == stamp + 1; stamps advance by 2.
struct MergeScratch {
	std::vector<uint32_t> mark = std::vector<uint32_t>(CHUNK_SIZE * CHUNK_SIZE, 0);
	uint32_t stamp = 0;
};

std::vector<Rect> merge_rects(std::vector<int> cells, MergeScratch &sc) {
	std::vector<Rect> out;
	std::sort(cells.begin(), cells.end());
	if (sc.stamp > 0xFFFFFFF0u) {
		std::fill(sc.mark.begin(), sc.mark.end(), 0);
		sc.stamp = 0;
	}
	sc.stamp += 2;
	const uint32_t present = sc.stamp;
	const uint32_t used = sc.stamp + 1;
	std::vector<uint32_t> &mark = sc.mark;
	for (int idx : cells) {
		mark[idx] = present;
	}
	for (int idx : cells) {
		if (mark[idx] != present) {
			continue;
		}
		int tx = idx % CHUNK_SIZE;
		int tz = idx / CHUNK_SIZE;
		int w = 1;
		while (tx + w < CHUNK_SIZE && mark[tz * CHUNK_SIZE + tx + w] == present) {
			w++;
		}
		int h = 1;
		while (tz + h < CHUNK_SIZE) {
			bool complete = true;
			for (int dx = 0; dx < w; dx++) {
				if (mark[(tz + h) * CHUNK_SIZE + tx + dx] != present) {
					complete = false;
					break;
				}
			}
			if (!complete) {
				break;
			}
			h++;
		}
		for (int dz = 0; dz < h; dz++) {
			for (int dx = 0; dx < w; dx++) {
				mark[(tz + dz) * CHUNK_SIZE + tx + dx] = used;
			}
		}
		out.push_back({ tx, tz, w, h });
	}
	return out;
}

} // namespace

Dictionary NativeChunkBuilder::build_chunk_arrays(const Vector2i &p_chunk, const Array &p_heightmap, const Dictionary &p_resolved, bool p_local, const Dictionary &p_cfg) const {
	Dictionary empty;
	ERR_FAIL_COND_V(p_heightmap.size() != CHUNK_SIZE * CHUNK_SIZE, empty);
	Variant runs_v = p_resolved.get("runs", Dictionary());
	Variant deposits_v = p_resolved.get("deposits", Array());
	ERR_FAIL_COND_V(runs_v.get_type() != Variant::DICTIONARY || deposits_v.get_type() != Variant::ARRAY, empty);
	Dictionary runs = runs_v;
	Array deposits = deposits_v;
	int64_t circumference = (int64_t)p_cfg.get("circumference_chunks", 0);
	ERR_FAIL_COND_V(circumference <= 0, empty);
	Variant fb = p_cfg.get("fallback_color", Variant());
	ERR_FAIL_COND_V(fb.get_type() != Variant::COLOR, empty);

	Mesher m;
	m.chunk = p_chunk;
	m.lap_tiles = circumference * CHUNK_SIZE;
	m.fallback = fb;
	m.runs = &runs;
	m.hm.resize(CHUNK_SIZE * CHUNK_SIZE);
	for (int i = 0; i < CHUNK_SIZE * CHUNK_SIZE; i++) {
		Variant h = p_heightmap[i];
		ERR_FAIL_COND_V(h.get_type() != Variant::FLOAT && h.get_type() != Variant::INT, empty);
		m.hm[i] = double(h);
	}
	if (!m.load_ring()) {
		return empty;
	}
	m.collect();

	double corner_x = double(int64_t(p_chunk.x) * CHUNK_SIZE) * TILE_SIZE;
	double corner_z = double(int64_t(p_chunk.y) * CHUNK_SIZE) * TILE_SIZE;
	double origin_x = p_local ? 0.0 : corner_x;
	double origin_z = p_local ? 0.0 : corner_z;
	double plane_dx = corner_x - origin_x;
	double plane_dz = corner_z - origin_z;

	PackedVector3Array vertices, normals, collision;
	PackedColorArray colors;
	PackedInt32Array indices;
	int64_t quad_count = 0;
	int64_t cell_count = 0;
	MergeScratch scratch;

	for (int dir : m.dir_order) {
		for (const Group &g : m.buckets[dir].groups) {
			cell_count += g.cell_count;
			for (const Rect &rect : merge_rects(g.cells, scratch)) {
				double plane = g.plane;
				if (dir == NORTH || dir == SOUTH) {
					plane -= plane_dz;
				} else if (dir == WEST || dir == EAST) {
					plane -= plane_dx;
				}
				double bottom = g.bottom;
				double top = g.top;
				double x0 = origin_x + rect.tx * TILE_SIZE;
				double x1 = x0 + rect.w * TILE_SIZE;
				double z0 = origin_z + rect.tz * TILE_SIZE;
				double z1 = z0 + rect.h * TILE_SIZE;
				Vector3 a, b, c, d, normal(0, 1, 0);
				switch (dir) {
					case UP:
						a = Vector3(x0, plane, z0); b = Vector3(x0, plane, z1);
						c = Vector3(x1, plane, z1); d = Vector3(x1, plane, z0);
						break;
					case DOWN:
						normal = Vector3(0, -1, 0);
						a = Vector3(x0, plane, z0); b = Vector3(x1, plane, z0);
						c = Vector3(x1, plane, z1); d = Vector3(x0, plane, z1);
						break;
					case NORTH:
						normal = Vector3(0, 0, -1);
						a = Vector3(x0, top, plane); b = Vector3(x1, top, plane);
						c = Vector3(x1, bottom, plane); d = Vector3(x0, bottom, plane);
						break;
					case SOUTH:
						normal = Vector3(0, 0, 1);
						a = Vector3(x1, top, plane); b = Vector3(x0, top, plane);
						c = Vector3(x0, bottom, plane); d = Vector3(x1, bottom, plane);
						break;
					case WEST:
						normal = Vector3(-1, 0, 0);
						a = Vector3(plane, top, z1); b = Vector3(plane, top, z0);
						c = Vector3(plane, bottom, z0); d = Vector3(plane, bottom, z1);
						break;
					default:
						normal = Vector3(1, 0, 0);
						a = Vector3(plane, top, z0); b = Vector3(plane, top, z1);
						c = Vector3(plane, bottom, z1); d = Vector3(plane, bottom, z0);
						break;
				}
				int32_t base = (int32_t)vertices.size();
				const Vector3 vs[4] = { a, b, c, d };
				for (const Vector3 &v : vs) {
					vertices.push_back(v);
					normals.push_back(normal);
					colors.push_back(g.color);
				}
				indices.push_back(base); indices.push_back(base + 1); indices.push_back(base + 2);
				indices.push_back(base); indices.push_back(base + 2); indices.push_back(base + 3);
				collision.push_back(a); collision.push_back(b); collision.push_back(c);
				collision.push_back(a); collision.push_back(c); collision.push_back(d);
				quad_count++;
			}
		}
	}

	// Deposit boxes (MeshUtil.add_box_arrays): geometry only, never collision.
	PackedVector3Array dep_vertices, dep_normals;
	PackedColorArray dep_colors;
	PackedInt32Array dep_indices;
	for (int i = 0; i < deposits.size(); i++) {
		Variant dv = deposits[i];
		ERR_FAIL_COND_V(dv.get_type() != Variant::DICTIONARY, empty);
		Dictionary dep = dv;
		Variant pos = dep.get(p_local ? "local_position" : "position", Variant());
		Variant size = dep.get("size", Variant());
		Variant col = dep.get("color", Variant());
		ERR_FAIL_COND_V(pos.get_type() != Variant::VECTOR3 || size.get_type() != Variant::VECTOR3 || col.get_type() != Variant::COLOR, empty);
		Vector3 center = pos;
		Vector3 sz = size;
		Color color = col;
		Vector3 h = sz * 0.5f;
		Vector3 p[8] = {
			center + Vector3(-h.x, -h.y, -h.z), center + Vector3(h.x, -h.y, -h.z),
			center + Vector3(h.x, -h.y, h.z), center + Vector3(-h.x, -h.y, h.z),
			center + Vector3(-h.x, h.y, -h.z), center + Vector3(h.x, h.y, -h.z),
			center + Vector3(h.x, h.y, h.z), center + Vector3(-h.x, h.y, h.z),
		};
		struct Face {
			int a, b, c, d;
			Vector3 n;
		};
		const Face faces[6] = {
			{ 4, 7, 6, 5, Vector3(0, 1, 0) }, { 0, 1, 2, 3, Vector3(0, -1, 0) },
			{ 3, 2, 6, 7, Vector3(0, 0, 1) }, { 0, 4, 5, 1, Vector3(0, 0, -1) },
			{ 1, 5, 6, 2, Vector3(1, 0, 0) }, { 0, 3, 7, 4, Vector3(-1, 0, 0) },
		};
		for (const Face &f : faces) {
			const int tris[2][3] = { { f.a, f.b, f.c }, { f.a, f.c, f.d } };
			for (const auto &tri : tris) {
				int32_t base = (int32_t)dep_vertices.size();
				for (int k = 0; k < 3; k++) {
					dep_vertices.push_back(p[tri[k]]);
					dep_normals.push_back(f.n);
					dep_colors.push_back(color);
				}
				dep_indices.push_back(base); dep_indices.push_back(base + 1); dep_indices.push_back(base + 2);
			}
		}
	}

	Dictionary out;
	out["vertices"] = vertices;
	out["normals"] = normals;
	out["colors"] = colors;
	out["indices"] = indices;
	out["collision"] = collision;
	out["quad_count"] = quad_count;
	out["cell_count"] = cell_count;
	out["deposit_vertices"] = dep_vertices;
	out["deposit_normals"] = dep_normals;
	out["deposit_colors"] = dep_colors;
	out["deposit_indices"] = dep_indices;
	out["local"] = p_local;
	return out;
}
