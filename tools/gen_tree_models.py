#!/usr/bin/env python3
"""Placeholder tree models (Phase 283): `assets/models/trees/<Species>.glb.raw` plus a `_v1` variant.

One model per fabric tree species (`TreeSlice.TREES_BY_BIOME`, species in `SPECIES` below; the suite
checks the two lists agree), two variants each, chosen by the tree's seed. Each is one closed mesh:
a tapered trunk (an 8-sided frustum) under a crown of several overlapping closed lumps (low UV spheres),
coloured per species with a vertex colour. Origin at the trunk's foot, +Y up, about 3.8 m tall (the crown top;
`TreeMaterial.SWAY_TO` matches it), standing where the procedural fallback mesh stands. The private repo overrides each key by name.

    python3 tools/gen_tree_models.py           # write the files and the manifest entries
    python3 tools/gen_tree_models.py --check   # fail when a file is stale, missing or orphaned
"""
import json
import math
import random
import struct
import sys
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_placeholder_glb import Blob, _glb  # noqa: E402
import gen_item_assets as g  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
MODEL_DIR = Path("assets/models/trees")
MANIFEST = Path("assets/manifest.json")
VARIANTS = ("", "_v1")

# species -> (trunk sRGB, crown sRGB); the species names are TreeSlice.TREES_BY_BIOME' values.
SPECIES = {
    "Thornwood": ((115, 82, 51), (77, 140, 64)),
    "Duskwood": ((107, 77, 133), (89, 71, 140)),
}


def _lumps(rng, variant: int):
    """Crown lump centres/radii: one big lump plus four to five around and above it."""
    out = [((0.0, 2.75, 0.0), 1.0)]
    n = 4 + variant
    for i in range(n):
        ang = 2 * math.pi * (i + rng.random() * 0.4) / n
        r = 0.55 + rng.random() * 0.25
        out.append(((math.cos(ang) * 0.7, 2.45 + rng.random() * 0.5, math.sin(ang) * 0.7), r))
    out.append(((rng.uniform(-0.2, 0.2), 3.3, rng.uniform(-0.2, 0.2)), 0.6))
    return out


def build_tree(species: str, variant: int):
    """-> [(rgb, triangles)] outward-wound, in metres."""
    rng = random.Random(zlib.crc32(f"{species}{variant}".encode()))
    trunk_rgb, crown_rgb = SPECIES[species]
    parts = [(trunk_rgb, g.cylinder(1, 0.0, 2.6, (0.0, 0.0), 0.32, 0.18, n=8))]
    for c, r in _lumps(rng, variant):
        parts.append((crown_rgb, g.sphere(c, r, rings=4, segs=8, squash=0.85)))
    return [(rgb, [tuple(tuple(g._r5(v) for v in p) for p in t) for t in tris]) for rgb, tris in parts]


def build_glb(parts) -> bytes:
    positions, normals, colors, indices = [], [], [], []
    for rgb, tris in parts:
        rgba = bytes([g._linear_byte(c) for c in rgb] + [255])
        for a, b, c in tris:
            n = g._norm(g._cross(g._sub(b, a), g._sub(c, a)))
            for p in (a, b, c):
                indices.append(len(positions) // 3)
                positions.extend(p)
                normals.extend(g._r5(v) for v in n)
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
        "asset": {"version": "2.0", "generator": "gen_tree_models.py"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": "Tree", "children": [1]}, {"name": "Model", "mesh": 0}],
        "meshes": [{"name": "Tree", "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "COLOR_0": 2},
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


def keys() -> list:
    return [f"models/trees/{s}{v}.glb.raw" for s in sorted(SPECIES) for v in VARIANTS]


def outputs() -> dict:
    files = {}
    for s in sorted(SPECIES):
        for i, v in enumerate(VARIANTS):
            files[MODEL_DIR / f"{s}{v}.glb.raw"] = build_glb(build_tree(s, i))
    return files


def manifest_text() -> str:
    manifest = json.loads((ROOT / MANIFEST).read_text())
    meshes = {k: v for k, v in manifest["meshes"].items() if not k.startswith("models/trees/")}
    for k in keys():
        meshes[k] = k
    manifest["meshes"] = meshes
    return json.dumps(manifest, indent=2) + "\n"


def main() -> int:
    files = outputs()
    if sys.argv[1:] == ["--check"]:
        problems = []
        for rel, data in files.items():
            if not (ROOT / rel).exists():
                problems.append(f"missing {rel}")
            elif (ROOT / rel).read_bytes() != data:
                problems.append(f"{rel} differs from the generator output")
        want = {p.name for p in files}
        for f in sorted((ROOT / MODEL_DIR).glob("*.glb.raw")):
            if f.name not in want:
                problems.append(f"orphan {MODEL_DIR / f.name}")
        if (ROOT / MANIFEST).read_text() != manifest_text():
            problems.append(f"{MANIFEST} tree entries are stale")
        for p in problems:
            print("FAIL", p)
        if problems:
            print("tree models are stale: run `python3 tools/gen_tree_models.py` and commit the result")
            return 1
        print(f"ok: {len(files)} tree models current")
        return 0
    for rel, data in files.items():
        (ROOT / rel).parent.mkdir(parents=True, exist_ok=True)
        (ROOT / rel).write_bytes(data)
    (ROOT / MANIFEST).write_text(manifest_text())
    print(f"wrote {len(files)} tree models")
    return 0


if __name__ == "__main__":
    sys.exit(main())
