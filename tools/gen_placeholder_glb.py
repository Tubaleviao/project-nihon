#!/usr/bin/env python3
"""Regenerate the committed placeholder rig (`assets/models/placeholder_rig.glb.raw`).

A blocky humanoid — a torso, a head, two arms and two legs, each a unit cube on its
own node — plus the seven clips the locomotion tree asks for (`idle`, `walk`, `run`,
`fall`, `land`, `attack`, `death`), packed as a binary glTF. The `.raw` suffix keeps
Godot's importer from claiming the file — see assets/README.md.

Why a BODY and not a single triangle (issue #112): this rig is what a public clone
renders as the LOCAL PLAYER. `game_root._finish_host_boot` calls
`CharacterSlice.attach_default_rig`, which prefers the private `models/player_rig.glb.raw`
and falls back to this public key, and `attach_rig` HIDES the procedural box body on
success. The first version of this placeholder was ONE flat, single-sided 1x1 triangle,
so the player's own character was invisible from behind and a gray sliver from the
front. Anything standing in for the player must render from any angle, so every part
here is a closed cube (thickness on BOTH horizontal axes), the figure spans a human
height with its feet on the root's ground plane, and every clip the tree looks up
exists so a fresh clone logs no "[RigTree] rig has no …".

The node layout is deliberately FLAT (every part a direct child of the "Body" root):
`RigTree.build_tree` needs an `AnimationPlayer`, not a skeleton, and a flat tree is what
the suite's AABB check reads without walking parent transforms.
"""
import json
import math
import struct
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "models" / "placeholder_rig.glb.raw"

# --- the unit cube every part is made of (half-extent 0.5, one normal per face) ----
CUBE_FACES = [
    ((0.0, 0.0, 1.0), [(-0.5, -0.5, 0.5), (0.5, -0.5, 0.5), (0.5, 0.5, 0.5), (-0.5, 0.5, 0.5)]),
    ((0.0, 0.0, -1.0), [(0.5, -0.5, -0.5), (-0.5, -0.5, -0.5), (-0.5, 0.5, -0.5), (0.5, 0.5, -0.5)]),
    ((1.0, 0.0, 0.0), [(0.5, -0.5, 0.5), (0.5, -0.5, -0.5), (0.5, 0.5, -0.5), (0.5, 0.5, 0.5)]),
    ((-1.0, 0.0, 0.0), [(-0.5, -0.5, -0.5), (-0.5, -0.5, 0.5), (-0.5, 0.5, 0.5), (-0.5, 0.5, -0.5)]),
    ((0.0, 1.0, 0.0), [(-0.5, 0.5, 0.5), (0.5, 0.5, 0.5), (0.5, 0.5, -0.5), (-0.5, 0.5, -0.5)]),
    ((0.0, -1.0, 0.0), [(-0.5, -0.5, -0.5), (0.5, -0.5, -0.5), (0.5, -0.5, 0.5), (-0.5, -0.5, 0.5)]),
]

# --- the body: node 0 is the root, every part hangs directly off it ---------------
# glTF links the hierarchy through each node's `children` array, so the root has to
# NAME its parts: a node defined but never listed there is an orphan (Godot's importer
# then drops its mesh and cannot resolve an animation channel targeting it).
# Feet land exactly on y=0 (leg centre 0.36 with half-height 0.36): the rig root IS
# the ground plane, which is what `CharacterSlice.sync_player_avatar` assumes.
NODES = [
    {"name": "Body"},
    {"name": "Torso", "mesh": 0, "translation": [0.0, 1.05, 0.0], "scale": [0.50, 0.70, 0.30]},
    {"name": "Head", "mesh": 0, "translation": [0.0, 1.58, 0.0], "scale": [0.28, 0.30, 0.28]},
    {"name": "ArmL", "mesh": 0, "translation": [-0.35, 1.15, 0.0], "scale": [0.14, 0.50, 0.16]},
    {"name": "ArmR", "mesh": 0, "translation": [0.35, 1.15, 0.0], "scale": [0.14, 0.50, 0.16]},
    {"name": "LegL", "mesh": 0, "translation": [-0.13, 0.36, 0.0], "scale": [0.18, 0.72, 0.20]},
    {"name": "LegR", "mesh": 0, "translation": [0.13, 0.36, 0.0], "scale": [0.18, 0.72, 0.20]},
]
NODES[0]["children"] = list(range(1, len(NODES)))
TORSO, HEAD, ARM_L, ARM_R, LEG_L, LEG_R = 1, 2, 3, 4, 5, 6

# --- the clips. `rot_x` is degrees about X per keyframe (a swing); `root_rot_x` tips
# the whole body. Key times are shared by every channel of one clip so the file
# carries ONE input accessor per clip.
CLIPS = [
    {
        "name": "idle",
        "times": [0.0, 1.0, 2.0],
        "rot_x": {TORSO: [0.0, 2.0, 0.0], HEAD: [0.0, -2.0, 0.0], ARM_L: [0.0, 4.0, 0.0], ARM_R: [0.0, -4.0, 0.0]},
    },
    {
        "name": "walk",
        "times": [0.0, 0.25, 0.5, 0.75, 1.0],
        "rot_x": {
            LEG_L: [0.0, 25.0, 0.0, -25.0, 0.0],
            LEG_R: [0.0, -25.0, 0.0, 25.0, 0.0],
            ARM_L: [0.0, -20.0, 0.0, 20.0, 0.0],
            ARM_R: [0.0, 20.0, 0.0, -20.0, 0.0],
        },
    },
    {
        "name": "run",
        "times": [0.0, 0.15, 0.3, 0.45, 0.6],
        "rot_x": {
            TORSO: [10.0, 13.0, 10.0, 13.0, 10.0],
            LEG_L: [0.0, 50.0, 0.0, -50.0, 0.0],
            LEG_R: [0.0, -50.0, 0.0, 50.0, 0.0],
            ARM_L: [0.0, -45.0, 0.0, 45.0, 0.0],
            ARM_R: [0.0, 45.0, 0.0, -45.0, 0.0],
        },
    },
    {
        "name": "fall",
        "times": [0.0, 0.4, 0.8],
        "rot_x": {
            ARM_L: [-70.0, -90.0, -70.0],
            ARM_R: [-70.0, -90.0, -70.0],
            LEG_L: [25.0, 10.0, 25.0],
            LEG_R: [-25.0, -10.0, -25.0],
        },
    },
    {
        "name": "land",
        "times": [0.0, 0.12, 0.25],
        "rot_x": {TORSO: [15.0, 8.0, 0.0], LEG_L: [40.0, 25.0, 0.0], LEG_R: [40.0, 25.0, 0.0]},
    },
    {
        "name": "attack",
        "times": [0.0, 0.15, 0.3, 0.5],
        "rot_x": {TORSO: [0.0, 8.0, 8.0, 0.0], ARM_R: [0.0, -130.0, -130.0, 0.0], ARM_L: [0.0, 25.0, 25.0, 0.0]},
    },
    {
        "name": "death",
        "times": [0.0, 0.4, 1.2],
        "rot_x": {ARM_L: [0.0, -30.0, -40.0], ARM_R: [0.0, -30.0, -40.0]},
        "root_rot_x": [0.0, -35.0, -88.0],
    },
]


def _quat_x(degrees: float) -> list:
    """A rotation of `degrees` about the X axis as a glTF quaternion (x, y, z, w)."""
    half = math.radians(degrees) / 2.0
    return [math.sin(half), 0.0, 0.0, math.cos(half)]


class Blob:
    """The glTF BIN chunk: every accessor gets its own 4-byte-aligned bufferView."""

    def __init__(self) -> None:
        self.data = bytearray()
        self.views: list = []

    def add(self, payload: bytes, target: int) -> int:
        while len(self.data) % 4:
            self.data.append(0)
        offset = len(self.data)
        self.data += payload
        view = {"buffer": 0, "byteOffset": offset, "byteLength": len(payload)}
        if target:
            view["target"] = target
        self.views.append(view)
        return len(self.views) - 1


def build() -> bytes:
    positions, normals, indices = [], [], []
    for normal, corners in CUBE_FACES:
        base = len(positions) // 3
        for corner in corners:
            positions.extend(corner)
            normals.extend(normal)
        indices.extend([base, base + 1, base + 2, base, base + 2, base + 3])

    blob = Blob()
    accessors: list = []
    mesh_views = [
        # target 34962 = ARRAY_BUFFER (vertex data), 34963 = ELEMENT_ARRAY_BUFFER
        blob.add(struct.pack("<%df" % len(positions), *positions), 34962),
        blob.add(struct.pack("<%df" % len(normals), *normals), 34962),
        blob.add(struct.pack("<%dH" % len(indices), *indices), 34963),
    ]
    accessors.extend([
        {"bufferView": mesh_views[0], "componentType": 5126, "count": len(positions) // 3, "type": "VEC3",
         "min": [-0.5, -0.5, -0.5], "max": [0.5, 0.5, 0.5]},
        {"bufferView": mesh_views[1], "componentType": 5126, "count": len(normals) // 3, "type": "VEC3"},
        {"bufferView": mesh_views[2], "componentType": 5123, "count": len(indices), "type": "SCALAR"},
    ])

    animations = []
    for clip in CLIPS:
        times = clip["times"]
        input_view = blob.add(struct.pack("<%df" % len(times), *times), 0)
        accessors.append({"bufferView": input_view, "componentType": 5126, "count": len(times), "type": "SCALAR",
                          "min": [min(times)], "max": [max(times)]})
        input_accessor = len(accessors) - 1

        channels = []
        samplers = []
        targets = list(clip["rot_x"].items())
        if "root_rot_x" in clip:
            targets.append((0, clip["root_rot_x"]))
        for node, degrees in targets:
            assert len(degrees) == len(times), "clip %s: %d keys for %d times" % (clip["name"], len(degrees), len(times))
            quats = []
            for degree in degrees:
                quats.extend(_quat_x(degree))
            output_view = blob.add(struct.pack("<%df" % len(quats), *quats), 0)
            accessors.append({"bufferView": output_view, "componentType": 5126, "count": len(times), "type": "VEC4"})
            samplers.append({"input": input_accessor, "output": len(accessors) - 1, "interpolation": "LINEAR"})
            channels.append({"sampler": len(samplers) - 1, "target": {"node": node, "path": "rotation"}})
        animations.append({"name": clip["name"], "samplers": samplers, "channels": channels})

    doc = {
        "asset": {"version": "2.0", "generator": "gen_placeholder_glb.py"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": NODES,
        "meshes": [{"name": "Part", "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1}, "indices": 2,
                                                     "mode": 4}]}],
        "buffers": [{"byteLength": len(blob.data)}],
        "bufferViews": blob.views,
        "accessors": accessors,
        "animations": animations,
    }
    js = _pad(json.dumps(doc, separators=(",", ":")).encode(), b" ")
    bn = _pad(bytes(blob.data), b"\x00")
    total = 12 + 8 + len(js) + 8 + len(bn)
    return (struct.pack("<4sII", b"glTF", 2, total)
            + struct.pack("<I4s", len(js), b"JSON") + js
            + struct.pack("<I4s", len(bn), b"BIN\x00") + bn)


def _pad(b: bytes, fill: bytes) -> bytes:
    return b + fill * ((4 - len(b) % 4) % 4)


if __name__ == "__main__":
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(build())
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")
