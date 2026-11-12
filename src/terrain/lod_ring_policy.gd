extends RefCounted
## Phase 243 — the LOD rings' boxes: which chunks each level of detail draws around the viewer.
##
## Level 0 is the voxel window (32 m chunks, built full or coarse by the chunk manager). Level k ≥ 1 is an
## LOD ring of chunks `32·2^k` m a side, each meshed from `CELLS`² columns (cells of 4, 8, 16… m), so the
## cost per ring stays about flat as the cell doubles. Each level has a BOX of its own chunks around the
## viewer (2D: chunks are full-height columns):
##   * the base box is the viewer's level-k chunk ± `distance(k)`, rounded outwards to even coordinates of
##     level k, so the next level's grid holds it exactly (no partial parent chunk, no gap);
##   * the neighbouring rule: the box grows to at least the finer level's box halved, padded by one chunk
##     and rounded to even again, so at least one chunk of each level separates the levels either side
##     of it (a ring never borders one two levels away);
##   * the box is made square (the shorter side grows by the even difference), so the distant ring's
##     square hole fits the outer box exactly.
## Ring k draws the chunks of box k that the finer level does not cover: box k−1 for k ≥ 2 (whole chunks,
## since box k−1 is even-aligned). Ring 1 draws every chunk of box 1, and the terrain shader's `lod_hole`
## (the window) cuts out the part under the window: the window moves a chunk at a time, and a ring-1 set
## that followed it would be rebuilt at every step.
## `still_holds` gives the plan a chunk of slack, so a viewer pacing over a chunk border does not re-plan.
## Level k reaches `(lod0 distance >> k) + LODN_DISTANCE` of its own chunks.
##
## Ported from godot_voxel's clipbox streaming (the algorithm: `get_base_box_in_chunks`,
## `get_minimal_box_for_parent_lod`, `enforce_neighboring_rule` in
## `terrain/variable_lod/voxel_lod_terrain_update_clipbox_streaming.cpp`, commit
## dfb0f81c7fd766f68d78715b2138f4e336cd9737):
##
##   MIT License. Copyright (c) 2016-2024 Marc Gilleron.
##   Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
##   associated documentation files (the "Software"), to deal in the Software without restriction,
##   including without limitation the rights to use, copy, modify, merge, publish, distribute,
##   sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
##   furnished to do so, subject to the following conditions: The above copyright notice and this
##   permission notice shall be included in all copies or substantial portions of the Software.
##   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
##   NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
##   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
##   OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
##   CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
##
## Pure and static: a test or a worker may call any of it.

## Level 0's chunk edge, in metres (the voxel window's chunk).
const CHUNK_METERS := 32.0
## Columns a side of every LOD chunk.
const CELLS := 16
## Chunks every level reaches past its share of the window's distance.
const LODN_DISTANCE := 4
## The project setting that sets how many LOD rings a client draws (the view distance; Phase 225 puts it
## in the options window). 0 draws none: the distant ring then starts at the window, as before Phase 243.
const RINGS_SETTING := "nihon/graphics/lod_rings"
const DEFAULT_RINGS := 5
const MAX_RINGS := 6
## The voxel window's reach in chunks (`ChunkManager.stream_radius()` at the default view distance 3 plus the
## standing prefetch 1): level 0's distance.
const WINDOW_RADIUS := 4

## The rings in effect: the project setting, clamped to [0, MAX_RINGS].
static func rings() -> int:
	return clampi(int(ProjectSettings.get_setting(RINGS_SETTING, DEFAULT_RINGS)), 0, MAX_RINGS)

## A level-k chunk's edge, in metres.
static func chunk_meters(level: int) -> float:
	return CHUNK_METERS * float(1 << level)

## A level-k cell's edge, in metres (4, 8, 16… for k = 1, 2, 3…).
static func cell_meters(level: int) -> float:
	return chunk_meters(level) / float(CELLS)

## The level-k chunk holding the world point `xz`.
static func level_chunk(xz: Vector2, level: int) -> Vector2i:
	var m := chunk_meters(level)
	return Vector2i(floori(xz.x / m), floori(xz.y / m))

static func floor_even(v: int) -> int:
	return v - posmod(v, 2)

static func ceil_even(v: int) -> int:
	return v + posmod(v, 2)

## `box` with its corners rounded outwards to even coordinates.
static func round_out(box: Rect2i) -> Rect2i:
	var lo := Vector2i(floor_even(box.position.x), floor_even(box.position.y))
	var hi := Vector2i(ceil_even(box.end.x), ceil_even(box.end.y))
	return Rect2i(lo, hi - lo)

## Level k's base box: the viewer's chunk ± `distance`, rounded out to even.
static func base_box(viewer: Vector2i, distance: int) -> Rect2i:
	return round_out(Rect2i(viewer - Vector2i(distance, distance), Vector2i(2 * distance + 1, 2 * distance + 1)))

## The smallest box of the next level that holds `child` (a box of the level below) with one chunk to
## spare on every side, rounded out to even (the neighbouring rule).
static func minimal_parent_box(child: Rect2i) -> Rect2i:
	var lo := Vector2i(floori(child.position.x / 2.0), floori(child.position.y / 2.0)) - Vector2i.ONE
	var hi := Vector2i(ceili(child.end.x / 2.0), ceili(child.end.y / 2.0)) + Vector2i.ONE
	return round_out(Rect2i(lo, hi - lo))

## `box` grown on its far side so both sides are as long as the longer one (both are even, so it stays
## even-aligned).
static func squared(box: Rect2i) -> Rect2i:
	var side := maxi(box.size.x, box.size.y)
	return Rect2i(box.position, Vector2i(side, side))

## The level-k reach in level-k chunks.
static func distance(level: int, lod0_distance: int) -> int:
	return (lod0_distance >> level) + LODN_DISTANCE

## The boxes of levels 0..`ring_count`, each in its own level's chunks (end exclusive). `window` is the
## voxel window in level-0 chunks; box 0 is it rounded out to even.
static func boxes(viewer_xz: Vector2, window: Rect2i, ring_count: int) -> Array[Rect2i]:
	var out: Array[Rect2i] = [round_out(window)]
	@warning_ignore("integer_division")
	var lod0 := maxi(window.size.x, window.size.y) / 2
	for k in range(1, ring_count + 1):
		var box := base_box(level_chunk(viewer_xz, k), distance(k, lod0))
		box = box.merge(minimal_parent_box(out[k - 1]))
		out.append(squared(box))
	return out

## The chunks ring `level` (≥ 1) draws, in its own level's coordinates: box `level` less what the finer
## level covers (see the header; `window` is unused, kept for the callers' symmetry). Ordered nearest
## the box centre first.
static func ring_chunks(all_boxes: Array[Rect2i], level: int, _window: Rect2i) -> Array[Vector2i]:
	var box: Rect2i = all_boxes[level]
	var inner: Rect2i = all_boxes[level - 1]
	var out: Array[Vector2i] = []
	for z in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var c := Vector2i(x, z)
			if level >= 2 and inner.encloses(Rect2i(c * 2, Vector2i(2, 2))):
				continue   # the finer ring draws it
			out.append(c)
	var mid := Vector2(box.position) + Vector2(box.size) * 0.5
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (Vector2(a) + Vector2(0.5, 0.5)).distance_squared_to(mid) < (Vector2(b) + Vector2(0.5, 0.5)).distance_squared_to(mid))
	return out

## True while `planned` (an earlier `boxes`) still serves a viewer at `viewer_xz` with `window`: box 1
## holds the window and each level's box holds the viewer's chunk ± one less than its distance. A new plan
## is only made once a level runs out of that one chunk of slack.
static func still_holds(planned: Array[Rect2i], viewer_xz: Vector2, window: Rect2i) -> bool:
	if planned.size() < 2:
		return false
	if not Rect2i(planned[1].position * 2, planned[1].size * 2).encloses(window):
		return false
	@warning_ignore("integer_division")
	var lod0 := maxi(window.size.x, window.size.y) / 2
	for k in range(1, planned.size()):
		var d := maxi(distance(k, lod0) - 1, 0)
		var c := level_chunk(viewer_xz, k)
		if not planned[k].encloses(Rect2i(c - Vector2i(d, d), Vector2i(2 * d + 1, 2 * d + 1))):
			return false
	return true

## Box `level` in metres (x, z).
static func box_rect_m(box: Rect2i, level: int) -> Rect2:
	var m := chunk_meters(level)
	return Rect2(Vector2(box.position) * m, Vector2(box.size) * m)

## The outer LOD radius: the least distance from a viewer to the outer box's edge, whatever its place
## in its chunk (the outer level's reach in whole chunks). The haze is fitted to it. With no rings, the
## window's own reach.
static func outer_radius_m(ring_count: int, lod0_distance: int) -> float:
	if ring_count <= 0:
		return float(lod0_distance) * CHUNK_METERS
	return float(distance(ring_count, lod0_distance)) * chunk_meters(ring_count)
