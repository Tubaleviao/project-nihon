extends RefCounted
## Phase 245 — the terrain CSG helper: union, subtraction and intersection of signed distances, sharp and smooth
## (polynomial `k`), after GDVoxelTerrain's `sdf_operations.h` (MIT, Copyright (c) Marc Gilleron / Zylann; the
## notice lives in native/THIRD_PARTY.md once the native twin lands). Phases 232, 300, 301 and 235 reuse it.
##
## Everything is integer fixed point so every machine gets the same bytes: lengths are `ONE` (1024) units a metre.
## A distance is negative inside a shape. `k` is the blend width in the same units; `k <= 0` is the sharp form.

const ONE := 1024
const SHIFT := 10

static func to_fixed(metres: float) -> int:
	return roundi(metres * float(ONE))

static func to_metres(v: int) -> float:
	return float(v) / float(ONE)

## Floor of the square root of a non-negative integer (exact: the float estimate is corrected).
static func isqrt(n: int) -> int:
	if n <= 0:
		return 0
	var r := int(sqrt(float(n)))
	while r * r > n:
		r -= 1
	while (r + 1) * (r + 1) <= n:
		r += 1
	return r

# ---------------------------------------------------------------------------
# Operations on two distances
# ---------------------------------------------------------------------------

static func op_union(a: int, b: int) -> int:
	return mini(a, b)

static func op_subtract(a: int, b: int) -> int:
	return maxi(a, -b)

static func op_intersect(a: int, b: int) -> int:
	return maxi(a, b)

## Blend term: h = max(k - |a - b|, 0) / k in Q10, the correction h² · k / 4 in distance units.
static func _blend(a: int, b: int, k: int) -> int:
	var h := maxi(k - absi(a - b), 0)
	if h == 0:
		return 0
	var hq := (h << SHIFT) / k
	return (hq * hq * k) >> (2 * SHIFT + 2)

static func smooth_union(a: int, b: int, k: int) -> int:
	if k <= 0:
		return op_union(a, b)
	return mini(a, b) - _blend(a, b, k)

static func smooth_subtract(a: int, b: int, k: int) -> int:
	if k <= 0:
		return op_subtract(a, b)
	return maxi(a, -b) + _blend(a, -b, k)

static func smooth_intersect(a: int, b: int, k: int) -> int:
	if k <= 0:
		return op_intersect(a, b)
	return maxi(a, b) + _blend(a, b, k)

# ---------------------------------------------------------------------------
# 2D shapes (height fields): signed distance of the point (px, pz)
# ---------------------------------------------------------------------------

static func disc(px: int, pz: int, cx: int, cz: int, radius: int) -> int:
	var dx := px - cx
	var dz := pz - cz
	return isqrt(dx * dx + dz * dz) - radius

static func capsule(px: int, pz: int, ax: int, az: int, bx: int, bz: int, radius: int) -> int:
	var abx := bx - ax
	var abz := bz - az
	var len2 := abx * abx + abz * abz
	var t_q := 0   # position along the segment, Q10, clamped to [0, ONE]
	if len2 > 0:
		t_q = clampi((((px - ax) * abx + (pz - az) * abz) << SHIFT) / len2, 0, ONE)
	var qx := ax + ((abx * t_q) >> SHIFT)
	var qz := az + ((abz * t_q) >> SHIFT)
	return disc(px, pz, qx, qz, radius)

## Distance to a chain of capsules along `pts` (Array of Vector2i, fixed point), the smallest of the segments.
static func polyline(px: int, pz: int, pts: Array, radius: int) -> int:
	if pts.is_empty():
		return 1 << 40
	if pts.size() == 1:
		return disc(px, pz, (pts[0] as Vector2i).x, (pts[0] as Vector2i).y, radius)
	var best := 1 << 40
	for i in pts.size() - 1:
		var a: Vector2i = pts[i]
		var b: Vector2i = pts[i + 1]
		best = mini(best, capsule(px, pz, a.x, a.y, b.x, b.y, radius))
	return best

## Axis-aligned box centred on (cx, cz) with half extents (hx, hz).
static func box(px: int, pz: int, cx: int, cz: int, hx: int, hz: int) -> int:
	var qx := absi(px - cx) - hx
	var qz := absi(pz - cz) - hz
	var outside := isqrt(maxi(qx, 0) * maxi(qx, 0) + maxi(qz, 0) * maxi(qz, 0))
	return outside + mini(maxi(qx, qz), 0)

# ---------------------------------------------------------------------------
# 3D shapes (run columns)
# ---------------------------------------------------------------------------

static func sphere(px: int, py: int, pz: int, cx: int, cy: int, cz: int, radius: int) -> int:
	var dx := px - cx
	var dy := py - cy
	var dz := pz - cz
	return isqrt(dx * dx + dy * dy + dz * dz) - radius

## Vertical cylinder: radius in x/z, half height `half_h` about cy.
static func cylinder(px: int, py: int, pz: int, cx: int, cy: int, cz: int, radius: int, half_h: int) -> int:
	var dr := isqrt((px - cx) * (px - cx) + (pz - cz) * (pz - cz)) - radius
	var dy := absi(py - cy) - half_h
	var outside := isqrt(maxi(dr, 0) * maxi(dr, 0) + maxi(dy, 0) * maxi(dy, 0))
	return outside + mini(maxi(dr, dy), 0)

static func box3(px: int, py: int, pz: int, cx: int, cy: int, cz: int, hx: int, hy: int, hz: int) -> int:
	var qx := absi(px - cx) - hx
	var qy := absi(py - cy) - hy
	var qz := absi(pz - cz) - hz
	var ox := maxi(qx, 0)
	var oy := maxi(qy, 0)
	var oz := maxi(qz, 0)
	return isqrt(ox * ox + oy * oy + oz * oz) + mini(maxi(qx, maxi(qy, qz)), 0)

static func capsule3(px: int, py: int, pz: int, ax: int, ay: int, az: int, bx: int, by: int, bz: int, radius: int) -> int:
	var abx := bx - ax
	var aby := by - ay
	var abz := bz - az
	var len2 := abx * abx + aby * aby + abz * abz
	var t_q := 0
	if len2 > 0:
		t_q = clampi((((px - ax) * abx + (py - ay) * aby + (pz - az) * abz) << SHIFT) / len2, 0, ONE)
	return sphere(px, py, pz, ax + ((abx * t_q) >> SHIFT), ay + ((aby * t_q) >> SHIFT), az + ((abz * t_q) >> SHIFT), radius)
