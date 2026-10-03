#!/usr/bin/env python3
"""Regenerate the committed placeholder mesh + animation (`assets/models/*.glb.raw`).

One single-triangle mesh node ("Body") and one animation ("idle") that rotates it,
packed as a binary glTF. The `.raw` suffix keeps Godot's importer from claiming
the file — see assets/README.md.
"""
import json
import struct
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "models" / "placeholder_rig.glb.raw"


def _pad(b: bytes, fill: bytes) -> bytes:
    return b + fill * ((4 - len(b) % 4) % 4)


def build() -> bytes:
    pos = struct.pack("<9f", 0, 0, 0, 1, 0, 0, 0, 1, 0)
    idx = _pad(struct.pack("<3H", 0, 1, 2), b"\x00")
    times = struct.pack("<2f", 0.0, 1.0)
    # identity and a 90-degree turn about Y (x, y, z, w)
    rots = struct.pack("<8f", 0, 0, 0, 1, 0, 0.70710678, 0, 0.70710678)
    blob = pos + idx + times + rots
    o_idx, o_t, o_r = len(pos), len(pos) + len(idx), len(pos) + len(idx) + len(times)
    doc = {
        "asset": {"version": "2.0", "generator": "gen_placeholder_glb.py"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": "Body", "mesh": 0}],
        "meshes": [{"name": "Body", "primitives": [{"attributes": {"POSITION": 0}, "indices": 1}]}],
        "buffers": [{"byteLength": len(blob)}],
        "bufferViews": [
            {"buffer": 0, "byteOffset": 0, "byteLength": len(pos)},
            {"buffer": 0, "byteOffset": o_idx, "byteLength": 6},
            {"buffer": 0, "byteOffset": o_t, "byteLength": len(times)},
            {"buffer": 0, "byteOffset": o_r, "byteLength": len(rots)},
        ],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": 3, "type": "VEC3",
             "min": [0, 0, 0], "max": [1, 1, 0]},
            {"bufferView": 1, "componentType": 5123, "count": 3, "type": "SCALAR"},
            {"bufferView": 2, "componentType": 5126, "count": 2, "type": "SCALAR",
             "min": [0.0], "max": [1.0]},
            {"bufferView": 3, "componentType": 5126, "count": 2, "type": "VEC4"},
        ],
        "animations": [{
            "name": "idle",
            "samplers": [{"input": 2, "output": 3, "interpolation": "LINEAR"}],
            "channels": [{"sampler": 0, "target": {"node": 0, "path": "rotation"}}],
        }],
    }
    js = _pad(json.dumps(doc, separators=(",", ":")).encode(), b" ")
    bn = _pad(blob, b"\x00")
    total = 12 + 8 + len(js) + 8 + len(bn)
    return (struct.pack("<4sII", b"glTF", 2, total)
            + struct.pack("<I4s", len(js), b"JSON") + js
            + struct.pack("<I4s", len(bn), b"BIN\x00") + bn)


if __name__ == "__main__":
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(build())
    print(f"wrote {OUT}")
