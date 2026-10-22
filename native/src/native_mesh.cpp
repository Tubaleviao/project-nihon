// Phase 169 — NativeChunkBuilder::build_chunk_arrays, the port of `VoxelMesh.build_chunk_arrays`: the
// greedy mesher. Every face a run exposes is grouped by direction, plane, span and colour, each group's
// cells are merged into rectangles and each rectangle becomes two triangles (plus the same two in the
// collision soup). The GDScript is the reference and its output order is defined by dictionary
// insertion order (directions in first-seen order, groups in first-seen order within one), which
// this port reproduces exactly so the arrays come out equal element for element.
#include "native_chunk_builder.h"

#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <cmath>
#include <map>
#include <tuple>
#include <utility>
#include <vector>

using namespace godot;

namespace {

const int CHUNK_SIZE = 64;
const double TILE_SIZE = 0.5;
const double STEP_HEIGHT = 0.125;
const double BEDROCK_DEPTH = -96.0;
const double EPS = 0.000001;

struct Run {
	double bottom, top;
	Color color, top_color, soil_color;
	double soil_depth;
};
typedef std::vector<Run> Column;

enum Dir { UP = 0, DOWN, NORTH, SOUTH, WEST, EAST, DIR_COUNT };

struct Group {
	double plane, bottom, top;
	Color color;
	std::vector<bool> cells = std::vector<bool>(CHUNK_SIZE * CHUNK_SIZE, false);
	int count = 0;
};

typedef std::tuple<int32_t, int32_t, int32_t, uint32_t> GroupKey;

struct DirBucket {
	std::map<GroupKey, size_t> index;
	std::vector<Group> groups; // first-seen order
};

struct Mesh {
	std::vector<Vector3> vertices, normals, collision;
	std::vector<Color> colors;
	std::vector<int32_t> indices;
};

struct Ctx {
	int64_t circ = 4;
	Color fallback;
	Vector2i chunk;
	const Array *heightmap = nullptr;
	Dictionary runs;
	// Columns parsed once per tile of the chunk and its one-tile ring: index (tz+1)*66 + (tx+1).
	std::vector<Column> cols = std::vector<Column>((CHUNK_SIZE + 2) * (CHUNK_SIZE + 2));
	std::vector<char> parsed = std::vector<char>((CHUNK_SIZE + 2) * (CHUNK_SIZE + 2), 0);

	static int64_t posmod(int64_t a, int64_t b) {
		int64_t v = a % b;
		if ((v < 0 && b > 0) || (v > 0 && b < 0)) {
			v += b;
		}
		return v;
	}
	String tile_key(int64_t gx, int64_t gz) const {
		int64_t lap = circ * CHUNK_SIZE;
		int64_t x = posmod(gx + lap / 2, lap) - lap / 2;
		return String::num_int64(x) + "," + String::num_int64(gz);
	}

	// `_column_for_cell` for inside tiles, `_column_for_tile` (UNKNOWN neighbour = empty) outside.
	const Column &column(int tx, int tz) {
		size_t i = (size_t)(tz + 1) * (CHUNK_SIZE + 2) + (size_t)(tx + 1);
		if (parsed[i]) {
			return cols[i];
		}
		parsed[i] = 1;
		Column &col = cols[i];
		bool inside = tx >= 0 && tx < CHUNK_SIZE && tz >= 0 && tz < CHUNK_SIZE;
		String key = tile_key((int64_t)chunk.x * CHUNK_SIZE + tx, (int64_t)chunk.y * CHUNK_SIZE + tz);
		if (runs.has(key)) {
			Array arr = runs[key];
			for (int r = 0; r < arr.size(); r++) {
				Dictionary d = arr[r];
				Run run;
				run.bottom = (double)d["bottom"];
				run.top = (double)d["top"];
				run.color = d.has("color") ? (Color)d["color"] : fallback;
				run.top_color = d.has("top_color") ? (Color)d["top_color"] : run.color;
				run.soil_color = d.has("soil_color") ? (Color)d["soil_color"] : run.color;
				run.soil_depth = d.has("soil_depth") ? (double)d["soil_depth"] : 0.0;
				col.push_back(run);
			}
			return col;
		}
		if (!inside) {
			return col;
		}
		double h = (double)(*heightmap)[tz * CHUNK_SIZE + tx];
		double top = std::floor(h / STEP_HEIGHT) * STEP_HEIGHT;
		if (top <= BEDROCK_DEPTH) {
			return col;
		}
		Run run;
		run.bottom = BEDROCK_DEPTH;
		run.top = top;
		run.color = run.top_color = run.soil_color = fallback;
		run.soil_depth = 0.0;
		col.push_back(run);
		return col;
	}
};

bool covers_y(const Column &col, double y) {
	for (const Run &r : col) {
		if (r.bottom - EPS <= y && y < r.top - EPS) {
			return true;
		}
	}
	return false;
}

struct Seg {
	double bottom, top;
};

// VoxelRuns.subtract_runs
std::vector<Seg> subtract_runs(const Run &run, const Column &others) {
	std::vector<Seg> segs{ { run.bottom, run.top } };
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

inline int32_t quant(double v) {
	return (int32_t)(int64_t)std::round(v * 10000.0);
}

void group_cell(std::vector<DirBucket> &buckets, std::vector<int> &dir_order, Dir dir, double plane, double bottom, double top, const Color &color, int tx, int tz) {
	DirBucket &b = buckets[dir];
	if (b.groups.empty() && b.index.empty()) {
		dir_order.push_back(dir);
	}
	GroupKey key(quant(plane), quant(bottom), quant(top), color.to_rgba32());
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
	size_t idx = (size_t)tz * CHUNK_SIZE + tx;
	if (!g.cells[idx]) {
		g.cells[idx] = true;
		g.count++;
	}
}

double wall_plane(const Vector2i &chunk, Dir dir, int tx, int tz) {
	double cx = (double)((int64_t)chunk.x * CHUNK_SIZE) * TILE_SIZE;
	double cz = (double)((int64_t)chunk.y * CHUNK_SIZE) * TILE_SIZE;
	switch (dir) {
		case NORTH: return cz + tz * TILE_SIZE;
		case SOUTH: return cz + (tz + 1) * TILE_SIZE;
		case WEST: return cx + tx * TILE_SIZE;
		default: return cx + (tx + 1) * TILE_SIZE;
	}
}

struct Rect {
	int tx, tz, w, h;
};

// merge_rects: row-major sweep of the group's cells.
std::vector<Rect> merge_rects(const std::vector<bool> &cells) {
	std::vector<Rect> out;
	std::vector<bool> used(CHUNK_SIZE * CHUNK_SIZE, false);
	for (int idx = 0; idx < CHUNK_SIZE * CHUNK_SIZE; idx++) {
		if (!cells[idx] || used[idx]) {
			continue;
		}
		int tx = idx % CHUNK_SIZE;
		int tz = (idx - tx) / CHUNK_SIZE;
		int w = 1;
		while (tx + w < CHUNK_SIZE && cells[tz * CHUNK_SIZE + tx + w] && !used[tz * CHUNK_SIZE + tx + w]) {
			w++;
		}
		int h = 1;
		while (tz + h < CHUNK_SIZE) {
			bool complete = true;
			for (int dx = 0; dx < w; dx++) {
				int probe = (tz + h) * CHUNK_SIZE + tx + dx;
				if (!cells[probe] || used[probe]) {
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
				used[(tz + dz) * CHUNK_SIZE + tx + dx] = true;
			}
		}
		out.push_back({ tx, tz, w, h });
	}
	return out;
}

void emit_rect(Mesh &m, Dir dir, const Group &g, const Rect &r, double origin_x, double origin_z, double plane_dx, double plane_dz) {
	double bottom = g.bottom, top = g.top, plane = g.plane;
	if (dir == NORTH || dir == SOUTH) {
		plane -= plane_dz;
	} else if (dir == WEST || dir == EAST) {
		plane -= plane_dx;
	}
	double x0 = origin_x + r.tx * TILE_SIZE;
	double x1 = x0 + r.w * TILE_SIZE;
	double z0 = origin_z + r.tz * TILE_SIZE;
	double z1 = z0 + r.h * TILE_SIZE;
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
	int32_t base = (int32_t)m.vertices.size();
	for (const Vector3 &v : { a, b, c, d }) {
		m.vertices.push_back(v);
		m.normals.push_back(normal);
		m.colors.push_back(g.color);
	}
	for (int32_t off : { 0, 1, 2, 0, 2, 3 }) {
		m.indices.push_back(base + off);
	}
	for (const Vector3 &v : { a, b, c, a, c, d }) {
		m.collision.push_back(v);
	}
}

template <typename T, typename A>
A to_packed(const std::vector<T> &v) {
	A out;
	out.resize((int64_t)v.size());
	for (size_t i = 0; i < v.size(); i++) {
		out.set((int64_t)i, v[i]);
	}
	return out;
}

// MeshUtil.add_box_arrays: six faces, each two flat-shaded triangles.
void add_box(Mesh &m, const Vector3 &center, const Vector3 &size, const Color &color) {
	Vector3 h = size * 0.5;
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
		for (const auto &t : tris) {
			int32_t base = (int32_t)m.vertices.size();
			for (int k = 0; k < 3; k++) {
				m.vertices.push_back(p[t[k]]);
				m.normals.push_back(f.n);
				m.colors.push_back(color);
			}
			m.indices.push_back(base);
			m.indices.push_back(base + 1);
			m.indices.push_back(base + 2);
		}
	}
}

} // namespace

Dictionary NativeChunkBuilder::build_chunk_arrays(const Vector2i &p_chunk, const Array &p_heightmap, const Dictionary &p_resolved, bool p_local, const Dictionary &p_cfg) const {
	Ctx ctx;
	ctx.circ = (int64_t)p_cfg.get("circumference_chunks", 4);
	ctx.fallback = p_cfg.get("fallback_color", Color(0.35, 0.60, 0.28));
	ctx.chunk = p_chunk;
	ctx.heightmap = &p_heightmap;
	ctx.runs = p_resolved.get("runs", Dictionary());
	Array deposits = p_resolved.get("deposits", Array());

	double corner_x = (double)((int64_t)p_chunk.x * CHUNK_SIZE) * TILE_SIZE;
	double corner_z = (double)((int64_t)p_chunk.y * CHUNK_SIZE) * TILE_SIZE;
	double origin_x = p_local ? 0.0 : corner_x;
	double origin_z = p_local ? 0.0 : corner_z;

	std::vector<DirBucket> buckets(DIR_COUNT);
	std::vector<int> dir_order;

	const int nx[4] = { 0, 0, -1, 1 };
	const int nz[4] = { -1, 1, 0, 0 };
	const Dir wall_dirs[4] = { NORTH, SOUTH, WEST, EAST };

	for (int tz = 0; tz < CHUNK_SIZE; tz++) {
		for (int tx = 0; tx < CHUNK_SIZE; tx++) {
			const Column &col = ctx.column(tx, tz);
			if (col.empty()) {
				continue;
			}
			for (const Run &run : col) {
				if (!covers_y(col, run.top + STEP_HEIGHT * 0.5)) {
					group_cell(buckets, dir_order, UP, run.top, run.top, run.top, run.top_color, tx, tz);
				}
				if (run.bottom > BEDROCK_DEPTH && !covers_y(col, run.bottom - STEP_HEIGHT * 0.5)) {
					group_cell(buckets, dir_order, DOWN, run.bottom, run.bottom, run.bottom, run.color, tx, tz);
				}
				double soil_line = run.top - run.soil_depth;
				for (int k = 0; k < 4; k++) {
					const Column &neighbour = ctx.column(tx + nx[k], tz + nz[k]);
					for (const Seg &seg : subtract_runs(run, neighbour)) {
						if (seg.top <= seg.bottom) {
							continue;
						}
						double plane = wall_plane(p_chunk, wall_dirs[k], tx, tz);
						if (std::isinf(soil_line) || seg.top <= soil_line) {
							group_cell(buckets, dir_order, wall_dirs[k], plane, seg.bottom, seg.top, run.color, tx, tz);
						} else if (seg.bottom >= soil_line) {
							group_cell(buckets, dir_order, wall_dirs[k], plane, seg.bottom, seg.top, run.soil_color, tx, tz);
						} else {
							group_cell(buckets, dir_order, wall_dirs[k], plane, seg.bottom, soil_line, run.color, tx, tz);
							group_cell(buckets, dir_order, wall_dirs[k], plane, soil_line, seg.top, run.soil_color, tx, tz);
						}
					}
				}
			}
		}
	}

	Mesh m;
	int64_t quad_count = 0, cell_count = 0;
	for (int dir : dir_order) {
		for (const Group &g : buckets[dir].groups) {
			cell_count += g.count;
			for (const Rect &r : merge_rects(g.cells)) {
				emit_rect(m, (Dir)dir, g, r, origin_x, origin_z, corner_x - origin_x, corner_z - origin_z);
				quad_count++;
			}
		}
	}

	Mesh dep;
	for (int i = 0; i < deposits.size(); i++) {
		Dictionary d = deposits[i];
		add_box(dep, (Vector3)d[p_local ? "local_position" : "position"], (Vector3)d["size"], (Color)d["color"]);
	}

	Dictionary out;
	out["vertices"] = to_packed<Vector3, PackedVector3Array>(m.vertices);
	out["normals"] = to_packed<Vector3, PackedVector3Array>(m.normals);
	out["colors"] = to_packed<Color, PackedColorArray>(m.colors);
	out["indices"] = to_packed<int32_t, PackedInt32Array>(m.indices);
	out["collision"] = to_packed<Vector3, PackedVector3Array>(m.collision);
	out["quad_count"] = quad_count;
	out["cell_count"] = cell_count;
	out["deposit_vertices"] = to_packed<Vector3, PackedVector3Array>(dep.vertices);
	out["deposit_normals"] = to_packed<Vector3, PackedVector3Array>(dep.normals);
	out["deposit_colors"] = to_packed<Color, PackedColorArray>(dep.colors);
	out["deposit_indices"] = to_packed<int32_t, PackedInt32Array>(dep.indices);
	out["local"] = p_local;
	return out;
}
