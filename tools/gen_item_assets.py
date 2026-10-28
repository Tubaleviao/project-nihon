#!/usr/bin/env python3
"""Item art from one generator: a low-poly model and a 32x32 icon per item (Phase 152).

Reads each item's ``shape`` (archetype + material per named part) from the generated item data
(``godot/items/*.tres``) and writes, for every item in ``GameData.ITEMS``:

* ``assets/models/items/<ItemId>.glb.raw`` - one closed mesh (<= 300 tris), origin at the grip, a
  ``grip`` node, +Z forward, one colour per part (``COLOR_0``) taken from the part's material;
* ``assets/icons/items/<ItemId>.png.raw`` - a software render of the same triangles: orthographic
  camera 30 degrees down and 45 degrees around, one sun from the top left with one highlight and
  one shadow band, transparent background, 128x128 with a z-buffer, downsampled to 32x32 by block
  mode (a palette snap), plus a 1 px outline in the darkest value of the dominant part;
* ``assets/models/items/shapes.lock.json`` - a hash of each item's shape and palette inputs, and
  each archetype's bounds, which the suite and ``--check`` read.

Pure Python, no Blender, no GPU: CI and a fresh clone run it as is. Output is deterministic (the
same fabric gives the same glb and the same pixels; the PNG container bytes also depend on the
local zlib build).

    python3 tools/gen_item_assets.py              # write everything
    python3 tools/gen_item_assets.py --out DIR    # write the same tree under DIR (CI diffs two runs)
    python3 tools/gen_item_assets.py --check      # fail if shapes.lock.json or the files are stale

The private repo's A4/A5/A8 phases hand-polish over the same keys (``project-nihon-assets``).
"""
import hashlib
import json
import math
import random
import re
import struct
import sys
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import holdables  # noqa: E402
from gen_placeholder import _png  # noqa: E402
from gen_placeholder_glb import Blob, _glb  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
ITEMS_TRES = ROOT / "godot/items"
MODEL_DIR = Path("assets/models/items")
ICON_DIR = Path("assets/icons/items")
LOCK_NAME = "shapes.lock.json"
MANIFEST = Path("assets/manifest.json")
GENERATOR_VERSION = 1
MAX_TRIS = 300

# Material -> sRGB base colour. Each part is drawn from a four-step ramp of its material
# (outline, shadow, base, highlight), so an icon only ever uses palette colours.
MATERIAL_COLORS = {
    "Ferrite": (107, 111, 118),
    "Thornwood": (122, 85, 43),
    "Veilsteel": (74, 95, 138),
    "Duskfiber": (122, 95, 143),
    "Aethermite": (56, 201, 192),
    "Sand": (216, 192, 138),
    "Ashite": (75, 69, 64),
    "Grass": (95, 154, 72),
    "Lumenfite": (240, 216, 96),
    "Voidite": (91, 47, 138),
}

# Archetype -> maximum AABB size (x, y, z) in metres at scale 1.
ARCHETYPE_BOUNDS = {
    "pick": (0.12, 0.80, 0.60), "axe": (0.10, 0.80, 0.40), "sword": (0.20, 0.75, 0.08),
    "longsword": (0.22, 1.15, 0.10), "knife": (0.06, 0.40, 0.08), "saw": (0.10, 0.55, 0.14), "bow": (0.10, 1.15, 0.35), "shield": (0.60, 0.60, 0.12),
    "helmet": (0.40, 0.40, 0.40), "chestplate": (0.70, 0.60, 0.35), "cloak": (0.70, 0.90, 0.20),
    "ingot": (0.30, 0.12, 0.16), "shard": (0.20, 0.34, 0.20), "dust": (0.30, 0.14, 0.30),
    "plank": (0.14, 0.06, 0.60), "block": (0.34, 0.34, 0.34), "orb": (0.25, 0.30, 0.25),
    "tablet": (0.34, 0.44, 0.10), "potion": (0.18, 0.30, 0.18), "rations": (0.22, 0.12, 0.18),
    "hearth": (0.70, 0.30, 0.70), "waystone": (0.50, 1.20, 0.40), "bed": (0.60, 0.40, 1.00),
}


# ---------------------------------------------------------------------------
# Geometry: closed primitives as lists of triangles ((x, y, z) * 3), outward winding.
# ---------------------------------------------------------------------------
def _sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _norm(v):
    n = math.sqrt(_dot(v, v)) or 1.0
    return (v[0] / n, v[1] / n, v[2] / n)


def _volume(tris) -> float:
    """Signed volume; positive when the triangles wind outward."""
    return sum(_dot(a, _cross(b, c)) for a, b, c in tris) / 6.0


def _outward(tris):
    return tris if _volume(tris) >= 0 else [(a, c, b) for a, b, c in tris]


def _quad(a, b, c, d):
    return [(a, b, c), (a, c, d)]


def _hexa(bottom, top):
    """Closed prism between two quads given in matching order."""
    tris = _quad(*bottom[::-1]) + _quad(*top)
    for i in range(4):
        j = (i + 1) % 4
        tris += _quad(bottom[i], bottom[j], top[j], top[i])
    return _outward(tris)


def _place(axis, a, u, v):
    p = [0.0, 0.0, 0.0]
    p[axis] = a
    p[(axis + 1) % 3] = u
    p[(axis + 2) % 3] = v
    return tuple(p)


def prism(axis, a0, a1, c, s0, s1=None):
    """A rectangular section swept along `axis` from a0 to a1; `c` is the centre on the other two
    axes (in cyclic order), `s0`/`s1` the half sizes there at each end (a box, or a taper)."""
    s1 = s1 or s0

    def ring(a, s):
        return [_place(axis, a, c[0] + du * s[0], c[1] + dv * s[1]) for du, dv in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    return _hexa(ring(a0, s0), ring(a1, s1))


def cylinder(axis, a0, a1, c, r0, r1=None, n=8):
    """An n-gon prism (or cone frustum) along `axis` with fan caps."""
    r1 = r1 if r1 is not None else r0
    pts0, pts1 = [], []
    for i in range(n):
        ang = 2 * math.pi * i / n
        du, dv = math.cos(ang), math.sin(ang)
        pts0.append(_place(axis, a0, c[0] + du * r0, c[1] + dv * r0))
        pts1.append(_place(axis, a1, c[0] + du * r1, c[1] + dv * r1))
    c0, c1 = _place(axis, a0, c[0], c[1]), _place(axis, a1, c[0], c[1])
    tris = []
    for i in range(n):
        j = (i + 1) % n
        tris += [(c0, pts0[j], pts0[i]), (c1, pts1[i], pts1[j])]
        tris += _quad(pts0[i], pts0[j], pts1[j], pts1[i])
    return _outward(tris)


def sphere(c, r, rings=5, segs=8, squash=1.0):
    """A low-res UV sphere (poles on Y)."""
    def at(ring, seg):
        phi = math.pi * ring / rings
        ang = 2 * math.pi * seg / segs
        return (c[0] + r * math.sin(phi) * math.cos(ang), c[1] + r * squash * math.cos(phi),
                c[2] + r * math.sin(phi) * math.sin(ang))
    tris = []
    for s in range(segs):
        t = (s + 1) % segs
        tris.append((at(0, 0), at(1, s), at(1, t)))
        tris.append((at(rings, 0), at(rings - 1, t), at(rings - 1, s)))
        for k in range(1, rings - 1):
            tris += _quad(at(k, s), at(k + 1, s), at(k + 1, t), at(k, t))
    return _outward(tris)


def beam(p0, p1, half):
    """A square beam from p0 to p1 (any direction), cross-section `half` wide, side axis X."""
    d = _norm(_sub(p1, p0))
    side = (1.0, 0.0, 0.0) if abs(d[0]) < 0.9 else (0.0, 1.0, 0.0)
    n = _norm(_cross(d, side))

    def ring(p):
        return [tuple(p[i] + side[i] * su * half + n[i] * sv * half for i in range(3))
                for su, sv in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    return _hexa(ring(p0), ring(p1))


def bipyramid(c, radii, top, bottom, rng):
    """A jittered crystal: a ring of points around the centre, apex above and below."""
    n = len(radii)
    ring = []
    for i, r in enumerate(radii):
        ang = 2 * math.pi * i / n + rng.uniform(-0.15, 0.15)
        ring.append((c[0] + r * math.cos(ang), c[1], c[2] + r * math.sin(ang)))
    up, down = (c[0], c[1] + top, c[2]), (c[0], c[1] - bottom, c[2])
    tris = []
    for i in range(n):
        j = (i + 1) % n
        tris += [(up, ring[j], ring[i]), (down, ring[i], ring[j])]
    return _outward(tris)


def _scaled(tris, k):
    return [tuple(tuple(v * k for v in p) for p in tri) for tri in tris]


def _shifted(tris, d):
    return [tuple(tuple(p[i] + d[i] for i in range(3)) for p in tri) for tri in tris]


# ---------------------------------------------------------------------------
# Archetypes: (shape parts, seed rng) -> {part: triangles}, grip at the origin.
# ---------------------------------------------------------------------------
def _pick(rng):
    return {"handle": cylinder(1, -0.1, 0.55, (0, 0), 0.025, n=6),
            "head": prism(2, -0.14, 0.14, (0, 0.53), (0.025, 0.035))
            + prism(2, 0.14, 0.26, (0, 0.53), (0.025, 0.035), (0.008, 0.008))
            + prism(2, -0.26, -0.14, (0, 0.53), (0.008, 0.008), (0.025, 0.035))}


def _axe(rng):
    return {"handle": cylinder(1, -0.1, 0.55, (0, 0), 0.025, n=6),
            "head": prism(2, 0.0, 0.2, (0, 0.47), (0.016, 0.05), (0.01, 0.12))
            + prism(2, -0.07, 0.0, (0, 0.5), (0.02, 0.04))}


def _blade_weapon(length):
    def build(rng):
        return {"grip": cylinder(1, -0.1, 0.08, (0, 0), 0.02, n=6),
                "blade": prism(0, -0.08, 0.08, (0.095, 0), (0.015, 0.02))
                + prism(1, 0.11, length - 0.1, (0, 0), (0.008, 0.03))
                + prism(1, length - 0.1, length, (0, 0), (0.008, 0.03), (0.004, 0.004))}
    return build


def _knife(rng):
    return {"grip": cylinder(1, -0.08, 0.06, (0, 0), 0.02, n=6),
            "blade": prism(1, 0.06, 0.26, (0, 0), (0.006, 0.025), (0.003, 0.004))}


def _saw(rng):
    teeth = []
    for k in range(6):
        teeth += prism(0, -0.005, 0.005, (0.12 + 0.06 * k, 0.05), (0.012, 0.008))
    return {"grip": cylinder(1, -0.08, 0.06, (0, 0), 0.02, n=6),
            "blade": prism(1, 0.06, 0.46, (0, 0), (0.006, 0.045), (0.005, 0.035)) + teeth}


def _bow(rng):
    pts = [(0.08, 0.0), (0.28, 0.06), (0.5, 0.18)]
    limb = []
    for sgn in (1, -1):
        for a, b in zip(pts, pts[1:]):
            limb += beam((0, sgn * a[0], a[1]), (0, sgn * b[0], b[1]), 0.012)
    tip = [t for sgn in (1, -1) for t in prism(1, sgn * 0.5 - 0.02, sgn * 0.5 + 0.02, (0.18, 0), (0.014, 0.014))]
    return {"grip": cylinder(1, -0.08, 0.08, (0, 0), 0.02, n=6), "limb": limb, "tip": tip}


def _shield(rng):
    return {"rim": cylinder(2, -0.03, -0.005, (0, 0), 0.27),
            "face": cylinder(2, -0.005, 0.03, (0, 0), 0.24)}


def _helmet(rng):
    return {"shell": sphere((0, 0.15, 0), 0.15, 5, 8, 0.95), "trim": cylinder(1, 0.0, 0.05, (0, 0), 0.155)}


def _chestplate(rng):
    return {"plate": prism(1, 0.06, 0.45, (0, 0), (0.1, 0.2), (0.11, 0.25))
            + prism(1, 0.4, 0.5, (0, -0.25), (0.1, 0.07)) + prism(1, 0.4, 0.5, (0, 0.25), (0.1, 0.07)),
            "under": prism(1, 0.0, 0.06, (0, 0), (0.115, 0.21))}


def _cloak(rng):
    return {"body": prism(1, 0.06, 0.8, (0, 0), (0.05, 0.3), (0.03, 0.18)),
            "trim": prism(1, 0.0, 0.06, (0, 0), (0.06, 0.31))}


def _ingot(rng):
    return {"body": prism(1, 0.0, 0.06, (0, 0), (0.05, 0.1), (0.04, 0.08))}


def _shard(rng):
    radii = [rng.uniform(0.05, 0.09) for _ in range(6)]
    return {"body": bipyramid((0, 0.1, 0), radii, rng.uniform(0.16, 0.22), rng.uniform(0.04, 0.08), rng)}


def _dust(rng):
    out = []
    for _ in range(3):
        out += sphere((rng.uniform(-0.08, 0.08), 0.03, rng.uniform(-0.08, 0.08)), rng.uniform(0.05, 0.08), 3, 6, 0.6)
    return {"body": out}


def _plank(rng):
    return {"body": prism(2, -0.25, 0.25, (0, 0.015), (0.05, 0.015))}


def _block(rng):
    return {"body": prism(1, 0.0, 0.3, (0, 0), (0.15, 0.15), (0.14, 0.14))}


def _orb(rng):
    prongs = []
    for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        prongs += prism(1, 0.04, 0.17, (dz * 0.085, dx * 0.085), (0.01, 0.01))
    return {"core": sphere((0, 0.13, 0), 0.09, 5, 8), "frame": cylinder(1, 0.0, 0.04, (0, 0), 0.07) + prongs}


def _tablet(rng):
    return {"slab": prism(1, 0.0, 0.4, (0, 0), (0.02, 0.14)),
            "rune": prism(2, 0.02, 0.032, (0, 0.2), (0.08, 0.05))}


def _potion(rng):
    return {"glass": cylinder(1, 0.0, 0.14, (0, 0), 0.06) + cylinder(1, 0.14, 0.22, (0, 0), 0.025),
            "liquid": cylinder(1, 0.03, 0.1, (0, 0), 0.064)}


def _rations(rng):
    return {"body": prism(1, 0.0, 0.08, (0, 0), (0.06, 0.08)),
            "wrap": prism(2, -0.02, 0.02, (0, 0.04), (0.085, 0.045))}


def _hearth(rng):
    logs = []
    for k in range(3):
        ang = k * math.pi / 3
        c, s = math.cos(ang), math.sin(ang)
        logs += beam((-0.22 * c, 0.14, -0.22 * s), (0.22 * c, 0.14, 0.22 * s), 0.035)
    return {"base": cylinder(1, 0.0, 0.1, (0, 0), 0.3), "fuel": logs}


def _waystone(rng):
    return {"stone": prism(1, 0.0, 0.9, (0, 0), (0.15, 0.2), (0.1, 0.12)) + prism(1, 0.9, 1.1, (0, 0), (0.1, 0.12), (0.02, 0.02)),
            "glyph": prism(2, 0.113, 0.137, (0, 0.5), (0.05, 0.12))}


def _bed(rng):
    legs = []
    for dz, dx in ((-0.42, -0.24), (-0.42, 0.24), (0.42, -0.24), (0.42, 0.24)):
        legs += prism(1, 0.0, 0.12, (dz, dx), (0.03, 0.03))
    frame = prism(1, 0.12, 0.2, (0, 0), (0.46, 0.27)) + prism(1, 0.2, 0.36, (-0.44, 0), (0.02, 0.27)) + legs
    return {"frame": frame, "mattress": prism(1, 0.2, 0.28, (0.04, 0), (0.38, 0.23))}


ARCHETYPES = {
    "pick": _pick, "axe": _axe, "sword": _blade_weapon(0.58), "longsword": _blade_weapon(0.9),
    "knife": _knife, "saw": _saw, "bow": _bow,
    "shield": _shield, "helmet": _helmet, "chestplate": _chestplate, "cloak": _cloak, "ingot": _ingot,
    "shard": _shard, "dust": _dust, "plank": _plank, "block": _block, "orb": _orb, "tablet": _tablet,
    "potion": _potion, "rations": _rations, "hearth": _hearth, "waystone": _waystone,
    "bed": _bed,
}


def _r5(x):
    """Round away libm last-bit differences so the bytes agree across machines."""
    return round(x, 5) + 0.0


def build_item(item_id: str, shape: dict):
    """-> [(part, material, triangles)] with the shape's scale applied."""
    rng = random.Random(zlib.crc32(item_id.encode()))
    parts = ARCHETYPES[shape["archetype"]](rng)
    out = []
    for part, tris in parts.items():
        tris = _scaled(tris, shape.get("scale", 1))
        tris = [tuple(tuple(_r5(v) for v in p) for p in tri) for tri in tris]
        out.append((part, shape["parts"][part], tris))
    return out


# ---------------------------------------------------------------------------
# glb
# ---------------------------------------------------------------------------
def _linear_byte(c: int) -> int:
    x = c / 255.0
    x = x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4
    return min(255, max(0, round(x * 255)))


def build_glb(built) -> bytes:
    positions, normals, colors, indices = [], [], [], []
    for _part, material, tris in built:
        rgba = bytes([_linear_byte(c) for c in MATERIAL_COLORS[material]] + [255])
        for a, b, c in tris:
            n = _norm(_cross(_sub(b, a), _sub(c, a)))
            for p in (a, b, c):
                indices.append(len(positions) // 3)
                positions.extend(p)
                normals.extend(_r5(v) for v in n)
                colors.append(rgba)
    count = len(positions) // 3
    lo = [min(positions[i::3]) for i in range(3)]
    hi = [max(positions[i::3]) for i in range(3)]
    blob = Blob()
    views = [
        blob.add(struct.pack("<%df" % len(positions), *positions), 34962, 12),
        blob.add(struct.pack("<%df" % len(normals), *normals), 34962, 12),
        blob.add(b"".join(colors), 34962, 4),
        blob.add(struct.pack("<%dH" % len(indices), *indices), 34963),
    ]
    doc = {
        "asset": {"version": "2.0", "generator": "gen_item_assets.py"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": "Item", "children": [1, 2]}, {"name": "Model", "mesh": 0}, {"name": "grip"}],
        "meshes": [{"name": "Item", "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "COLOR_0": 2},
                                                     "indices": 3, "mode": 4}]}],
        "buffers": [{"byteLength": len(blob.data)}],
        "bufferViews": blob.views,
        "accessors": [
            {"bufferView": views[0], "componentType": 5126, "count": count, "type": "VEC3", "min": lo, "max": hi},
            {"bufferView": views[1], "componentType": 5126, "count": count, "type": "VEC3"},
            {"bufferView": views[2], "componentType": 5121, "normalized": True, "count": count, "type": "VEC4"},
            {"bufferView": views[3], "componentType": 5123, "count": count, "type": "SCALAR"},
        ],
    }
    return _glb(doc, blob)


# ---------------------------------------------------------------------------
# icon: software render
# ---------------------------------------------------------------------------
RENDER = 128
ICON = 32
BOX = 112          # the silhouette fits this box, centred in the 128 canvas (1 px outline margin left)
YAW, PITCH = math.radians(45), math.radians(30)
SUN = _norm((-0.5, 0.6, 0.62))   # view space: from the top left, towards the viewer


def ramp(material):
    """(outline, shadow, base, highlight) sRGB for a material."""
    base = MATERIAL_COLORS[material]
    out = lambda k: tuple(min(255, round(c * k)) for c in base)  # noqa: E731
    high = tuple(round(c + (255 - c) * 0.4) for c in base)
    return (out(0.3), out(0.62), base, high)


def _view(p):
    x, y, z = p
    x, z = x * math.cos(YAW) + z * math.sin(YAW), -x * math.sin(YAW) + z * math.cos(YAW)
    y, z = y * math.cos(PITCH) - z * math.sin(PITCH), y * math.sin(PITCH) + z * math.cos(PITCH)
    return (x, y, z)


def render_icon(built) -> bytes:
    tris = []  # (view points, band-ramp index, part material)
    for _part, material, ts in built:
        for t in ts:
            v = [_view(p) for p in t]
            n = _norm(_cross(_sub(v[1], v[0]), _sub(v[2], v[0])))
            tris.append((v, n, material))
    xs = [p[0] for v, _, _ in tris for p in v]
    ys = [p[1] for v, _, _ in tris for p in v]
    k = BOX / max(max(xs) - min(xs), max(ys) - min(ys))
    ox = RENDER / 2 - k * (max(xs) + min(xs)) / 2
    oy = RENDER / 2 + k * (max(ys) + min(ys)) / 2
    depth = [[-1e18] * RENDER for _ in range(RENDER)]
    pix = [[None] * RENDER for _ in range(RENDER)]  # (color, material)
    for v, n, material in tris:
        d = _dot(n, SUN)
        shade = 3 if d >= 0.8 else 2 if d >= 0.25 else 1
        color = ramp(material)[shade]
        pts = [(ox + k * p[0], oy - k * p[1], p[2]) for p in v]
        x0 = max(0, int(math.floor(min(p[0] for p in pts))))
        x1 = min(RENDER - 1, int(math.ceil(max(p[0] for p in pts))))
        y0 = max(0, int(math.floor(min(p[1] for p in pts))))
        y1 = min(RENDER - 1, int(math.ceil(max(p[1] for p in pts))))
        (ax, ay, az), (bx, by, bz), (cx, cy, cz) = pts
        area = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
        if abs(area) < 1e-9:
            continue
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                px, py = x + 0.5, y + 0.5
                w1 = ((px - ax) * (cy - ay) - (py - ay) * (cx - ax)) / area
                w2 = ((bx - ax) * (py - ay) - (by - ay) * (px - ax)) / area
                w0 = 1 - w1 - w2
                if w0 < -1e-9 or w1 < -1e-9 or w2 < -1e-9:
                    continue
                z = w0 * az + w1 * bz + w2 * cz
                if z > depth[y][x]:
                    depth[y][x] = z
                    pix[y][x] = (color, material)
    step = RENDER // ICON
    img = [[None] * ICON for _ in range(ICON)]
    mats = {}
    for y in range(ICON):
        for x in range(ICON):
            block = [pix[y * step + j][x * step + i] for j in range(step) for i in range(step)]
            hits = [b for b in block if b is not None]
            if len(hits) * 2 < len(block):
                continue
            counts = {}
            for b in hits:
                counts[b] = counts.get(b, 0) + 1
            best = max(counts.items(), key=lambda kv: (kv[1], kv[0]))[0]
            img[y][x] = best[0]
            mats[best[1]] = mats.get(best[1], 0) + 1
    if not mats:
        raise ValueError("icon has no block with 50% coverage; shape too thin")
    dominant = max(mats.items(), key=lambda kv: (kv[1], kv[0]))[0]
    edge = ramp(dominant)[0]
    out = [row[:] for row in img]
    for y in range(ICON):
        for x in range(ICON):
            if img[y][x] is None and any(
                    0 <= y + dy < ICON and 0 <= x + dx < ICON and img[y + dy][x + dx] is not None
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out[y][x] = edge
    return _png(ICON, ICON, lambda x, y: (*out[y][x], 255) if out[y][x] is not None else (0, 0, 0, 0))


# ---------------------------------------------------------------------------
# items, lock, output
# ---------------------------------------------------------------------------
def read_items(tres_dir: Path = ITEMS_TRES) -> dict:
    """item id -> shape dict, from the generated item resources."""
    items = {}
    for gd in sorted(tres_dir.glob("*.gd")):
        m = re.search(r"^class_name (\w+)Data$", gd.read_text(), re.M)
        tres = gd.with_suffix(".tres")
        if not m or not tres.exists():
            continue
        s = re.search(r"^shape = (\{.*\})$", tres.read_text(), re.M)
        if not s:
            sys.exit(f"{tres}: item has no shape")
        items[m.group(1)] = json.loads(s.group(1))
    return items


def shape_hash(item_id: str, shape: dict) -> str:
    colors = {m: MATERIAL_COLORS[m] for m in sorted(set(shape["parts"].values()))}
    blob = json.dumps({"v": GENERATOR_VERSION, "id": item_id, "shape": shape, "colors": colors}, sort_keys=True)
    return hashlib.sha256(blob.encode()).hexdigest()[:16]


def lock_data(items: dict) -> dict:
    return {
        "generator": GENERATOR_VERSION,
        "maxTris": MAX_TRIS,
        "archetypeBounds": {k: list(v) for k, v in sorted(ARCHETYPE_BOUNDS.items())},
        "items": {i: {"archetype": s["archetype"], "scale": s.get("scale", 1), "hash": shape_hash(i, s)}
                  for i, s in sorted(items.items())},
    }


def _validate(items: dict) -> None:
    for item_id, shape in items.items():
        if shape["archetype"] not in ARCHETYPES:
            sys.exit(f"{item_id}: no builder for archetype {shape['archetype']}")
        for material in shape["parts"].values():
            if material not in MATERIAL_COLORS:
                sys.exit(f"{item_id}: material {material} has no palette colour in gen_item_assets.py")


def outputs(items: dict) -> dict:
    """relative path -> bytes for every generated file."""
    _validate(items)
    files = {}
    for item_id, shape in sorted(items.items()):
        built = build_item(item_id, shape)
        tris = sum(len(t) for _, _, t in built)
        if tris > MAX_TRIS:
            sys.exit(f"{item_id}: {tris} tris, budget is {MAX_TRIS}")
        files[MODEL_DIR / f"{item_id}.glb.raw"] = build_glb(built)
        files[ICON_DIR / f"{item_id}.png.raw"] = render_icon(built)
    files[MODEL_DIR / LOCK_NAME] = (json.dumps(lock_data(items), indent=2) + "\n").encode()
    return files


def manifest_text(items: dict, root: Path) -> str:
    manifest = json.loads((root / MANIFEST).read_text())
    meshes = {k: v for k, v in manifest["meshes"].items() if not k.startswith("models/items/")}
    for item_id in sorted(items):
        key = f"models/items/{item_id}.glb.raw"
        meshes[key] = key
    manifest["meshes"] = meshes
    return json.dumps(manifest, indent=2) + "\n"


def _other_holdables() -> set:
    """Materials and harvest outputs: their icons share this directory but come from gen_holdable_icons.py."""
    return {i for i, k in holdables.holdable_kinds().items() if k != "item"}


def write(items: dict, root: Path) -> None:
    for rel, data in outputs(items).items():
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    if (root / MANIFEST).exists():
        (root / MANIFEST).write_text(manifest_text(items, root))
    keep = {f"{i}.glb.raw" for i in items} | {LOCK_NAME}
    for stale in (root / MODEL_DIR).glob("*.glb.raw"):
        if stale.name not in keep:
            stale.unlink()
    keep = {f"{i}.png.raw" for i in items} | {f"{i}.png.raw" for i in _other_holdables()}
    for stale in (root / ICON_DIR).glob("*.png.raw"):
        if stale.name not in keep:
            stale.unlink()
    print(f"wrote {len(items)} item models and icons under {root}")


def check(items: dict) -> int:
    problems = []
    _validate(items)
    lock_path = ROOT / MODEL_DIR / LOCK_NAME
    lock = json.loads(lock_path.read_text()) if lock_path.exists() else {}
    want = lock_data(items)
    if lock != want:
        for i in sorted(set(want["items"]) | set(lock.get("items", {}))):
            if want["items"].get(i) != lock.get("items", {}).get(i):
                problems.append(f"{LOCK_NAME} is stale for {i}")
        if lock.get("archetypeBounds") != want["archetypeBounds"] or lock.get("generator") != want["generator"]:
            problems.append(f"{LOCK_NAME} bounds or generator version differ")
    for rel, data in outputs(items).items():
        if not (ROOT / rel).exists():
            problems.append(f"missing {rel}")
        elif (ROOT / rel).read_bytes() != data:
            problems.append(f"{rel} differs from the generator output")
    for d, suffix in ((MODEL_DIR, ".glb.raw"), (ICON_DIR, ".png.raw")):
        for f in sorted((ROOT / d).glob("*" + suffix)):
            if f.name[: -len(suffix)] not in items and not (suffix == ".png.raw" and f.name[: -len(suffix)] in _other_holdables()):
                problems.append(f"orphan {d / f.name}: not an item")
    manifest = json.loads((ROOT / MANIFEST).read_text())
    for i in items:
        if f"models/items/{i}.glb.raw" not in manifest["meshes"]:
            problems.append(f"{MANIFEST} does not list the {i} model")
    for p in problems:
        print("FAIL", p)
    if problems:
        print("item art is stale: run `python3 tools/gen_item_assets.py` and commit the result")
        return 1
    print(f"ok: {len(items)} items, lock and files current")
    return 0


def main() -> None:
    args = sys.argv[1:]
    items = read_items()
    if args == ["--check"]:
        sys.exit(check(items))
    if args == []:
        write(items, ROOT)
    elif len(args) == 2 and args[0] == "--out":
        out = Path(args[1])
        out.mkdir(parents=True, exist_ok=True)
        (out / MANIFEST.parent).mkdir(parents=True, exist_ok=True)
        (out / MANIFEST).write_text((ROOT / MANIFEST).read_text())
        write(items, out)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
