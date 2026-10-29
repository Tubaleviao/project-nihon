// Phase 190 — NativeChunkBuilder::build_coarse_arrays, the port of `VoxelCoarse.build_coarse_arrays`: the
// coarse build of a chunk beyond the near ring. `coarse_columns` (native_runs.cpp) resolves one
// column per cell; this greedy-meshes them on the n x n grid. The GDScript is the reference; the grouping
// order, the merge sweep and the float32 narrowing of a Vector3 / Color mirror it.
#include "native_chunk_builder.h"

#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
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
const double BEDROCK_DEPTH = -96.0;

enum Dir { NORTH, SOUTH, WEST, EAST, UP, DIR_COUNT };

struct Group {
	double plane = 0.0;
	double bottom = 0.0;
	double top = 0.0;
	Color color;
	std::vector<int> cells;
};

typedef std::tuple<int32_t, int32_t, int32_t, uint32_t> GroupKey;

struct Bucket {
	std::map<GroupKey, size_t> index;
	std::vector<Group> groups;   // insertion order
};

struct Grouper {
	std::array<Bucket, DIR_COUNT> buckets;
	std::vector<int> dir_order;   // dirs in the order their first group appeared

	void add(int dir, double plane, double bottom, double top, const Color &color, int idx) {
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
		b.groups[gi].cells.push_back(idx);
	}
};

struct Rect {
	int tx, tz, w, h;
};

std::vector<Rect> merge_rects(std::vector<int> &cells, int n) {
	std::vector<Rect> out;
	std::sort(cells.begin(), cells.end());
	cells.erase(std::unique(cells.begin(), cells.end()), cells.end());
	std::vector<uint8_t> mark(n * n, 0);   // 1 present, 2 used
	for (int idx : cells) {
		mark[idx] = 1;
	}
	for (int idx : cells) {
		if (mark[idx] != 1) {
			continue;
		}
		int tx = idx % n;
		int tz = idx / n;
		int w = 1;
		while (tx + w < n && mark[tz * n + tx + w] == 1) {
			w++;
		}
		int h = 1;
		while (tz + h < n) {
			bool complete = true;
			for (int dx = 0; dx < w; dx++) {
				if (mark[(tz + h) * n + tx + dx] != 1) {
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
				mark[(tz + dz) * n + tx + dx] = 2;
			}
		}
		out.push_back({ tx, tz, w, h });
	}
	return out;
}

template <typename P, typename T>
P to_packed(const std::vector<T> &v) {
	P out;
	out.resize((int64_t)v.size());
	if (!v.empty()) {
		std::copy(v.begin(), v.end(), out.ptrw());
	}
	return out;
}

} // namespace

Dictionary NativeChunkBuilder::build_coarse_arrays(const Vector2i &p_chunk, const Array &p_heightmap, const Dictionary &p_input, int64_t p_step, bool p_local, const Dictionary &p_cfg) const {
	Dictionary empty;
	Dictionary cols = coarse_columns(p_chunk, p_heightmap, p_input, p_step, p_cfg);
	if (cols.is_empty()) {
		return empty;
	}
	const int n = CHUNK_SIZE / (int)p_step;
	const double cell = TILE_SIZE * double(p_step);
	const double origin_x = p_local ? 0.0 : double(int64_t(p_chunk.x) * CHUNK_SIZE) * TILE_SIZE;
	const double origin_z = p_local ? 0.0 : double(int64_t(p_chunk.y) * CHUNK_SIZE) * TILE_SIZE;
	// Phase 194 (#509) — const: a non-const packed array's operator[] goes through ptrw() (copy-on-write).
	const PackedFloat64Array tops = cols["tops"];
	const PackedColorArray colors = cols["colors"];
	const PackedColorArray top_colors = cols["top_colors"];
	const PackedColorArray soil_colors = cols["soil_colors"];
	const PackedFloat64Array soil_depths = cols["soil_depths"];

	Grouper grp;
	static const int dirs[4] = { NORTH, SOUTH, WEST, EAST };
	static const int ddx[4] = { 0, 0, -1, 1 };
	static const int ddz[4] = { -1, 1, 0, 0 };
	for (int cz = 0; cz < n; cz++) {
		for (int cx = 0; cx < n; cx++) {
			int i = cz * n + cx;
			double top = tops[i];
			if (top <= BEDROCK_DEPTH) {
				continue;
			}
			grp.add(UP, top, top, top, top_colors[i], i);
			double soil_line = top - soil_depths[i];
			for (int k = 0; k < 4; k++) {
				int nx = cx + ddx[k];
				int nz = cz + ddz[k];
				double bottom = BEDROCK_DEPTH;
				if (nx >= 0 && nx < n && nz >= 0 && nz < n) {
					bottom = std::max(BEDROCK_DEPTH, (double)tops[nz * n + nx]);
				}
				if (top <= bottom) {
					continue;
				}
				double plane;
				switch (dirs[k]) {
					case NORTH: plane = origin_z + cz * cell; break;
					case SOUTH: plane = origin_z + (cz + 1) * cell; break;
					case WEST: plane = origin_x + cx * cell; break;
					default: plane = origin_x + (cx + 1) * cell; break;
				}
				if (top <= soil_line) {
					grp.add(dirs[k], plane, bottom, top, colors[i], i);
				} else if (bottom >= soil_line) {
					grp.add(dirs[k], plane, bottom, top, soil_colors[i], i);
				} else {
					grp.add(dirs[k], plane, bottom, soil_line, colors[i], i);
					grp.add(dirs[k], plane, soil_line, top, soil_colors[i], i);
				}
			}
		}
	}

	std::vector<Vector3> vertices, normals, collision;
	std::vector<Color> out_colors;
	std::vector<int32_t> indices;
	int64_t quad_count = 0;
	int64_t cell_count = 0;
	for (int dir : grp.dir_order) {
		for (Group &g : grp.buckets[dir].groups) {
			// Phase 194 (#509) — `merge_rects` sorts and dedups the cells in place: count them after, one sort a group.
			const std::vector<Rect> rects = merge_rects(g.cells, n);
			cell_count += (int64_t)g.cells.size();
			for (const Rect &rect : rects) {
				double x0 = origin_x + rect.tx * cell;
				double x1 = x0 + rect.w * cell;
				double z0 = origin_z + rect.tz * cell;
				double z1 = z0 + rect.h * cell;
				double plane = g.plane, bottom = g.bottom, top = g.top;
				Vector3 a, b, c, d, normal(0, 1, 0);
				switch (dir) {
					case UP:
						a = Vector3(x0, plane, z0); b = Vector3(x0, plane, z1);
						c = Vector3(x1, plane, z1); d = Vector3(x1, plane, z0);
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
					out_colors.push_back(g.color);
				}
				indices.push_back(base); indices.push_back(base + 1); indices.push_back(base + 2);
				indices.push_back(base); indices.push_back(base + 2); indices.push_back(base + 3);
				collision.push_back(a); collision.push_back(b); collision.push_back(c);
				collision.push_back(a); collision.push_back(c); collision.push_back(d);
				quad_count++;
			}
		}
	}

	Dictionary out;
	out["vertices"] = to_packed<PackedVector3Array>(vertices);
	out["normals"] = to_packed<PackedVector3Array>(normals);
	out["colors"] = to_packed<PackedColorArray>(out_colors);
	out["indices"] = to_packed<PackedInt32Array>(indices);
	out["collision"] = to_packed<PackedVector3Array>(collision);
	out["quad_count"] = quad_count;
	out["cell_count"] = cell_count;
	out["local"] = p_local;
	out["lod"] = p_step;
	return out;
}
