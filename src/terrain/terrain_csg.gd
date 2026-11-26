class_name TerrainCsg
extends RefCounted
## Terrain CSG helper (Phase 245): union, subtraction and intersection of signed distance shapes, and
## their smooth (polynomial `k`) forms, in integer millimetres so every machine gets the same bytes.
##
## The operation maths follows GDVoxelTerrain's `sdf_operations.h` (the polynomial smooth min/max).
## GDVoxelTerrain is MIT licensed, copyright its authors; see native/THIRD_PARTY.md. This file ports the
## algorithm, not the code, and replaces the float maths by integer maths.
##
## A distance is negative inside a shape, zero on its surface and positive outside, in mm. `k` is the
## smoothing width in mm; `k <= 0` is the sharp form. Shapes: 2D (disc, capsule, polyline, box) for
## height fields, 3D (sphere, cylinder, box, capsule) for run columns. Points are Vector2i / Vector3i
## in mm.

## Integer square root (floor), exact for any non-negative int below 2^62.
static func isqrt(n: int) -> int:
	if n <= 0:
		return 0
	var x := int(sqrt(float(n)))
	while x * x > n:
		x -= 1
	while (x + 1) * (x + 1) <= n:
		x += 1
	return x


static func length2(x: int, y: int) -> int:
	return isqrt(x * x + y * y)


static func length3(x: int, y: int, z: int) -> int:
	return isqrt(x * x + y * y + z * z)


# --- operations ---------------------------------------------------------------------------------

static func union(a: int, b: int) -> int:
	return mini(a, b)


static func intersection(a: int, b: int) -> int:
	return maxi(a, b)


## Subtract shape `b` from shape `a`.
static func subtract(a: int, b: int) -> int:
	return maxi(a, -b)


static func smooth_union(a: int, b: int, k: int) -> int:
	if k <= 0:
		return mini(a, b)
	var d := absi(a - b)
	if d >= k:
		return mini(a, b)
	var t := k - d
	return mini(a, b) - (t * t) / (4 * k)


static func smooth_intersection(a: int, b: int, k: int) -> int:
	if k <= 0:
		return maxi(a, b)
	var d := absi(a - b)
	if d >= k:
		return maxi(a, b)
	var t := k - d
	return maxi(a, b) + (t * t) / (4 * k)


static func smooth_subtract(a: int, b: int, k: int) -> int:
	return smooth_intersection(a, -b, k)


# --- 2D shapes (height fields) ------------------------------------------------------------------

static func disc(p: Vector2i, c: Vector2i, r: int) -> int:
	return length2(p.x - c.x, p.y - c.y) - r


static func capsule2(p: Vector2i, a: Vector2i, b: Vector2i, r: int) -> int:
	return length2(p.x - a.x, p.y - a.y) - r if a == b else _seg_dist2(p, a, b) - r


static func _seg_dist2(p: Vector2i, a: Vector2i, b: Vector2i) -> int:
	var ab := b - a
	var ap := p - a
	var len2 := ab.x * ab.x + ab.y * ab.y
	var dot := ap.x * ab.x + ap.y * ab.y
	if dot <= 0:
		return length2(ap.x, ap.y)
	if dot >= len2:
		return length2(p.x - b.x, p.y - b.y)
	# Closest point a + ab * dot / len2, with the division rounded down.
	var cx := a.x + _muldiv(ab.x, dot, len2)
	var cy := a.y + _muldiv(ab.y, dot, len2)
	return length2(p.x - cx, p.y - cy)


## A chain of capsules along `pts` (radius per point, linearly interpolated is the caller's job: pass
## `radii` with one radius per segment). Smooth union with `k` between segments.
static func polyline(p: Vector2i, pts: Array, radii: Array, k: int = 0) -> int:
	var best := 1 << 40
	for i in range(pts.size() - 1):
		var d := capsule2(p, pts[i], pts[i + 1], radii[i])
		best = d if i == 0 else smooth_union(best, d, k)
	return best


## Axis aligned box centred at `c` with half extents `h`.
static func box2(p: Vector2i, c: Vector2i, h: Vector2i) -> int:
	var qx := absi(p.x - c.x) - h.x
	var qy := absi(p.y - c.y) - h.y
	return length2(maxi(qx, 0), maxi(qy, 0)) + mini(maxi(qx, qy), 0)


# --- 3D shapes (run columns) --------------------------------------------------------------------

static func sphere(p: Vector3i, c: Vector3i, r: int) -> int:
	return length3(p.x - c.x, p.y - c.y, p.z - c.z) - r


## Vertical cylinder (axis along y) centred at `c`, radius `r`, half height `hh`.
static func cylinder(p: Vector3i, c: Vector3i, r: int, hh: int) -> int:
	var dx := length2(p.x - c.x, p.z - c.z) - r
	var dy := absi(p.y - c.y) - hh
	return length2(maxi(dx, 0), maxi(dy, 0)) + mini(maxi(dx, dy), 0)


static func box3(p: Vector3i, c: Vector3i, h: Vector3i) -> int:
	var qx := absi(p.x - c.x) - h.x
	var qy := absi(p.y - c.y) - h.y
	var qz := absi(p.z - c.z) - h.z
	return length3(maxi(qx, 0), maxi(qy, 0), maxi(qz, 0)) + mini(maxi(qx, maxi(qy, qz)), 0)


static func capsule3(p: Vector3i, a: Vector3i, b: Vector3i, r: int) -> int:
	var ab := b - a
	var ap := p - a
	var len2 := ab.x * ab.x + ab.y * ab.y + ab.z * ab.z
	var dot := ap.x * ab.x + ap.y * ab.y + ap.z * ab.z
	if len2 == 0 or dot <= 0:
		return length3(ap.x, ap.y, ap.z) - r
	if dot >= len2:
		return length3(p.x - b.x, p.y - b.y, p.z - b.z) - r
	var cx := a.x + _muldiv(ab.x, dot, len2)
	var cy := a.y + _muldiv(ab.y, dot, len2)
	var cz := a.z + _muldiv(ab.z, dot, len2)
	return length3(p.x - cx, p.y - cy, p.z - cz) - r


## floor(m * d / len2) without the product leaving int64 (m up to 2^21, 0 <= d < len2 < 2^43): d is split in
## 2^20 limbs and the high part is reduced by len2 first. Same split in `NativeBake`.
static func _muldiv(m: int, d: int, len2: int) -> int:
	var d1 := d >> 20
	var d0 := d & 0xFFFFF
	var t := m * d1
	var qt := _fdiv(t, len2)
	var rt := t - qt * len2
	return qt * 1048576 + _fdiv(rt * 1048576 + m * d0, len2)


## Floor division for ints of either sign (GDScript `/` truncates toward zero).
static func _fdiv(a: int, b: int) -> int:
	var q := a / b
	if (a % b != 0) and ((a < 0) != (b < 0)):
		q -= 1
	return q
