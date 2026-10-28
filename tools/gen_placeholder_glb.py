#!/usr/bin/env python3
"""Regenerate the committed placeholder rigs: `assets/models/placeholder_rig.glb.raw` and
`assets/models/player_rig.glb.raw` (the second is described above `build_player_rig`).

A blocky humanoid — a torso, a head, two arms and two legs, each a unit cube on its
own node — plus the seven clips the locomotion tree asks for (`idle`, `walk`, `run`,
`fall`, `land`, `attack`, `death`), packed as a binary glTF. The `.raw` suffix keeps
Godot's importer from claiming the file — see assets/README.md.

Why a BODY and not a single triangle (issue #112): this rig is what a public clone
renders as the LOCAL PLAYER. `game_root._finish_host_boot` calls
`CharacterSlice.attach_default_rig`, which tries `models/player_rig.glb.raw` first and
this key second, and `attach_rig` HIDES the procedural box body on success. The public
manifest now lists a `player_rig` placeholder too, so this key renders only when a
manifest leaves `player_rig` out. The first version of this placeholder was ONE flat, single-sided 1x1 triangle,
so the player's own character was invisible from behind and a gray sliver from the
front. Anything standing in for the player must render from any angle, so every part
here is a closed cube (thickness on BOTH horizontal axes), the figure spans a human
height with its feet on the root's ground plane, and every clip the tree looks up
exists so a fresh clone logs no "[RigTree] rig has no …".

The node layout is deliberately FLAT (every part a direct child of the "Body" root):
`RigTree.build_tree` needs an `AnimationPlayer`, not a skeleton, and a flat tree is what
the suite's AABB check reads without walking parent transforms.
"""
import sys
import json
import math
import re
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


def _quat_mul(a: list, b: list) -> list:
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return [aw * bx + ax * bw + ay * bz - az * by,
            aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw,
            aw * bw - ax * bx - ay * by - az * bz]


def _quat_euler(degrees: tuple) -> list:
    """X, then Y, then Z (each about the parent's axes), as a glTF quaternion."""
    q = [0.0, 0.0, 0.0, 1.0]
    for axis, d in enumerate(degrees):
        half = math.radians(d) / 2.0
        r = [0.0, 0.0, 0.0, math.cos(half)]
        r[axis] = math.sin(half)
        q = _quat_mul(r, q)
    return q


class Blob:
    """The glTF BIN chunk: every accessor gets its own 4-byte-aligned bufferView."""

    def __init__(self) -> None:
        self.data = bytearray()
        self.views: list = []

    def add(self, payload: bytes, target: int, stride: int = 0) -> int:
        while len(self.data) % 4:
            self.data.append(0)
        offset = len(self.data)
        self.data += payload
        view = {"buffer": 0, "byteOffset": offset, "byteLength": len(payload)}
        if target:
            view["target"] = target
        if stride:
            # A vertex view must declare its stride or Godot's glTF importer warns
            # ("Buffer view byte stride should be declared for vertex attributes")
            # on EVERY load of this rig. The indices view must NOT declare one
            # (glTF forbids byteStride on an ELEMENT_ARRAY_BUFFER view).
            view["byteStride"] = stride
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
        # target 34962 = ARRAY_BUFFER (vertex data), 34963 = ELEMENT_ARRAY_BUFFER.
        # stride 12 = one tightly-packed VEC3 float, declared explicitly; see Blob.add.
        blob.add(struct.pack("<%df" % len(positions), *positions), 34962, 12),
        blob.add(struct.pack("<%df" % len(normals), *normals), 34962, 12),
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
                quats.extend(_quat_euler((degree, 0.0, 0.0)))
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
    return _glb(doc, blob)


def _glb(doc: dict, blob: Blob) -> bytes:
    """`doc` and `blob` packed as one binary glTF."""
    js = _pad(json.dumps(doc, separators=(",", ":")).encode(), b" ")
    bn = _pad(bytes(blob.data), b"\x00")
    total = 12 + 8 + len(js) + 8 + len(bn)
    return (struct.pack("<4sII", b"glTF", 2, total)
            + struct.pack("<I4s", len(js), b"JSON") + js
            + struct.pack("<I4s", len(bn), b"BIN\x00") + bn)


def _pad(b: bytes, fill: bytes) -> bytes:
    return b + fill * ((4 - len(b) % 4) % 4)


# ---------------------------------------------------------------------------
# The player rig placeholder: `assets/models/player_rig.glb.raw`
# ---------------------------------------------------------------------------
# The public stand-in for the private player rig (asset roadmap Phase A2). It carries
# the same contract as the art: a real glTF skin whose joints are the fabric
# HumanoidSkeleton bones (names and parents, read from the generated .tres so the two
# cannot drift), one skinned mesh of boxes each bound rigidly to one joint, and the
# seven clips as joint rotations. Code that reads bones works on it as on the art.
#
# Joint positions are where a body bends (glTF axes: +Y up, facing -Z, the figure's
# left at -X): `Leg_*` at the hip, `Shin_*` at the knee, `Forearm_*` at the elbow. They
# are not the fabric `restPose` offsets, which put `Leg_*` at the knee and `Shin_*` at
# the ankle; the private rig must use the same positions (and carry the `Shin_*` knees).
#
# Rest orientations match the private rig too (Blender's convention: a bone's +Y points
# at its child, so `Leg_*` rests turned 180 degrees about X and `Arm_*` hang down). With
# identity rests the bone-local axes would differ from the art's, and a bone attachment
# offset, IK target or procedural pose tuned on a public clone would land wrong once
# assets-prod is mounted.

SKELETON_TRES = Path(__file__).resolve().parent.parent / "godot" / "skeletons" / "humanoidskeleton.tres"
PLAYER_OUT = OUT.parent / "player_rig.glb.raw"

JOINTS = {
    "Root": (0.0, 0.0, 0.0),
    "Hips": (0.0, 0.95, 0.0),
    "Spine": (0.0, 1.08, 0.0),
    "Chest": (0.0, 1.25, 0.0),
    "Neck": (0.0, 1.50, 0.0),
    "Head": (0.0, 1.58, 0.0),
    "Shoulder_L": (-0.04, 1.44, 0.0),
    "Arm_L": (-0.20, 1.44, 0.0),
    "Forearm_L": (-0.23, 1.16, 0.0),
    "Hand_L": (-0.25, 0.90, 0.0),
    "Shoulder_R": (0.04, 1.44, 0.0),
    "Arm_R": (0.20, 1.44, 0.0),
    "Forearm_R": (0.23, 1.16, 0.0),
    "Hand_R": (0.25, 0.90, 0.0),
    "Leg_L": (-0.10, 0.92, 0.0),
    "Shin_L": (-0.10, 0.50, 0.0),
    "Foot_L": (-0.10, 0.09, 0.0),
    "Leg_R": (0.10, 0.92, 0.0),
    "Shin_R": (0.10, 0.50, 0.0),
    "Foot_R": (0.10, 0.09, 0.0),
}

# Local rest rotation (glTF x, y, z, w) per joint, relative to its parent; identity
# when absent. Copied from the private rig's joints, rounded. `Shin_*` (the knee) rests
# in line with its thigh, so it needs none.
REST = {
    "Shoulder_L": (-0.5, 0.5, 0.5, 0.5),
    "Arm_L": (-0.4972, 0.4972, -0.4467, 0.5533),
    "Forearm_L": (-0.0014, 0.015, -0.0149, 0.9998),
    "Hand_L": (0.0006, -0.0069, 0.0069, 1.0),
    "Shoulder_R": (-0.5, -0.5, -0.5, 0.5),
    "Arm_R": (-0.4972, -0.4972, 0.4467, 0.5533),
    "Forearm_R": (-0.0014, -0.015, 0.0149, 0.9998),
    "Hand_R": (0.0006, 0.0069, -0.0069, 1.0),
    "Leg_L": (1.0, 0.0, 0.0, 0.0),
    "Foot_L": (0.5473, 0.0, 0.0, 0.8369),
    "Leg_R": (1.0, 0.0, 0.0, 0.0),
    "Foot_R": (0.5473, 0.0, 0.0, 0.8369),
}

# (joint, centre, size): one box per body part, in the figure's rest space.
PARTS = [
    ("Hips", (0.0, 0.92, 0.0), (0.32, 0.16, 0.20)),
    ("Spine", (0.0, 1.15, 0.0), (0.30, 0.20, 0.20)),
    ("Chest", (0.0, 1.37, 0.0), (0.40, 0.26, 0.24)),
    ("Neck", (0.0, 1.53, 0.0), (0.10, 0.08, 0.10)),
    ("Head", (0.0, 1.68, 0.0), (0.22, 0.22, 0.24)),
]
for _side, _sx in (("L", -1.0), ("R", 1.0)):
    PARTS += [
        ("Arm_" + _side, (_sx * 0.215, 1.30, 0.0), (0.10, 0.30, 0.11)),
        ("Forearm_" + _side, (_sx * 0.24, 1.03, 0.0), (0.08, 0.26, 0.09)),
        ("Hand_" + _side, (_sx * 0.255, 0.845, 0.0), (0.06, 0.11, 0.09)),
        ("Leg_" + _side, (_sx * 0.10, 0.71, 0.0), (0.14, 0.44, 0.15)),
        ("Shin_" + _side, (_sx * 0.10, 0.29, 0.0), (0.12, 0.42, 0.13)),
        ("Foot_" + _side, (_sx * 0.10, 0.04, -0.05), (0.11, 0.08, 0.23)),
    ]

# Clips as {joint: [(x, y, z) degrees per key]}, rotations about the figure's axes
# applied at the joint on top of its rest (`build_player_rig` turns them into local
# joint rotations, so they read the same whatever the rests are). A hanging limb swings forward (-Z) with +X; an
# upright bone leans back with +X; an arm lifts sideways with -Z (left) / +Z (right).
# walk and run share a stride phase: left leg forward at t=0, right leg forward at half.
# Knees (`Shin_*`) bend with -X (the foot swings back) and fold most while the leg swings
# through under the body; elbows (`Forearm_*`) bend with +X and fold most as the arm
# swings forward.


def _stride(leg: float, arm: float, knee: list, elbow: list) -> dict:
    """One stride over five keys. `knee` and `elbow` are the left limb's bend per key; the
    right limb plays them half a stride later."""
    phase = [1.0, 0.0, -1.0, 0.0, 1.0]
    half = lambda keys: keys[2:4] + keys[0:3]
    return {
        "Leg_L": [(leg * p, 0, 0) for p in phase], "Leg_R": [(-leg * p, 0, 0) for p in phase],
        "Arm_L": [(-arm * p, 0, 0) for p in phase], "Arm_R": [(arm * p, 0, 0) for p in phase],
        "Shin_L": [(-k, 0, 0) for k in knee], "Shin_R": [(-k, 0, 0) for k in half(knee)],
        "Forearm_L": [(e, 0, 0) for e in elbow], "Forearm_R": [(e, 0, 0) for e in half(elbow)],
    }


PLAYER_CLIPS = [
    # A breathing and weight-shift loop: chest +-6 degrees, hips sway, a slow head turn (about 3 s).
    ("idle", [0.0, 0.75, 1.5, 2.25, 3.0], {
        "Chest": [(0, 0, 0), (-6, 0, 0), (0, 0, 0), (6, 0, 0), (0, 0, 0)],
        "Hips": [(0, 0, 0), (0, 0, 4), (0, 0, 0), (0, 0, -4), (0, 0, 0)],
        "Head": [(0, 0, 0), (0, 12, 0), (0, 0, 0), (0, -12, 0), (0, 0, 0)],
        "Arm_L": [(0, 0, -3), (0, 0, -6), (0, 0, -3), (0, 0, -6), (0, 0, -3)],
        "Arm_R": [(0, 0, 3), (0, 0, 6), (0, 0, 3), (0, 0, 6), (0, 0, 3)]}),
    # Variants that play once after a long idle.
    ("idle_look", [0.0, 0.6, 1.8, 2.4], {
        "Head": [(0, 0, 0), (0, 35, 0), (0, -35, 0), (0, 0, 0)],
        "Neck": [(0, 0, 0), (0, 15, 0), (0, -15, 0), (0, 0, 0)],
        "Chest": [(0, 0, 0), (0, 8, 0), (0, -8, 0), (0, 0, 0)]}),
    ("idle_stretch", [0.0, 0.8, 1.8, 2.6], {
        "Arm_L": [(0, 0, 0), (0, 0, -150), (0, 0, -150), (0, 0, 0)],
        "Arm_R": [(0, 0, 0), (0, 0, 150), (0, 0, 150), (0, 0, 0)],
        "Chest": [(0, 0, 0), (-12, 0, 0), (-12, 0, 0), (0, 0, 0)],
        "Head": [(0, 0, 0), (-15, 0, 0), (-15, 0, 0), (0, 0, 0)]}),
    ("walk", [0.0, 0.25, 0.5, 0.75, 1.0], _stride(25, 20, [5, 12, 20, 55, 5], [10, 20, 35, 20, 10])),
    ("run", [0.0, 0.15, 0.3, 0.45, 0.6], dict(_stride(45, 50, [15, 35, 30, 100, 15], [60, 75, 90, 75, 60]),
        Spine=[(-8, 0, 0)] * 5)),
    ("fall", [0.0, 0.4, 0.8], {
        "Arm_L": [(0, 0, -70), (0, 0, -90), (0, 0, -70)], "Arm_R": [(0, 0, 70), (0, 0, 90), (0, 0, 70)],
        "Forearm_L": [(20, 0, 0), (30, 0, 0), (20, 0, 0)], "Forearm_R": [(20, 0, 0), (30, 0, 0), (20, 0, 0)],
        "Leg_L": [(20, 0, 0), (8, 0, 0), (20, 0, 0)], "Leg_R": [(-10, 0, 0), (-4, 0, 0), (-10, 0, 0)],
        "Shin_L": [(-30, 0, 0), (-15, 0, 0), (-30, 0, 0)], "Shin_R": [(-15, 0, 0), (-8, 0, 0), (-15, 0, 0)]}),
    ("land", [0.0, 0.12, 0.25], {
        "Spine": [(-20, 0, 0), (-10, 0, 0), (0, 0, 0)],
        "Arm_L": [(25, 0, 0), (12, 0, 0), (0, 0, 0)], "Arm_R": [(25, 0, 0), (12, 0, 0), (0, 0, 0)],
        "Leg_L": [(12, 0, 0), (6, 0, 0), (0, 0, 0)], "Leg_R": [(12, 0, 0), (6, 0, 0), (0, 0, 0)],
        "Shin_L": [(-24, 0, 0), (-12, 0, 0), (0, 0, 0)], "Shin_R": [(-24, 0, 0), (-12, 0, 0), (0, 0, 0)]}),
    ("attack", [0.0, 0.15, 0.3, 0.5], {
        "Chest": [(0, 0, 0), (0, 15, 0), (-8, -15, 0), (0, 0, 0)],
        "Arm_R": [(0, 0, 0), (160, 0, 0), (40, 0, 0), (0, 0, 0)],
        "Arm_L": [(0, 0, 0), (-15, 0, 0), (15, 0, 0), (0, 0, 0)]}),
    # Variants by what the main hand holds (the rig picks one; `attack` is the fallback).
    ("attack_unarmed", [0.0, 0.1, 0.2, 0.4], {
        "Chest": [(0, 0, 0), (0, 20, 0), (-6, -20, 0), (0, 0, 0)],
        "Arm_R": [(0, 0, 0), (-40, 0, 0), (100, 0, 0), (0, 0, 0)],
        "Forearm_R": [(0, 0, 0), (60, 0, 0), (5, 0, 0), (0, 0, 0)],
        "Arm_L": [(0, 0, 0), (-20, 0, 0), (10, 0, 0), (0, 0, 0)]}),
    ("attack_1h", [0.0, 0.15, 0.3, 0.5], {
        "Chest": [(0, 0, 0), (0, 25, 0), (-10, -25, 0), (0, 0, 0)],
        "Arm_R": [(0, 0, 0), (0, 0, 130), (60, 0, 20), (0, 0, 0)],
        "Forearm_R": [(0, 0, 0), (50, 0, 0), (10, 0, 0), (0, 0, 0)],
        "Arm_L": [(0, 0, 0), (-15, 0, 0), (15, 0, 0), (0, 0, 0)]}),
    ("attack_tool", [0.0, 0.2, 0.35, 0.5], {
        "Spine": [(0, 0, 0), (-12, 0, 0), (18, 0, 0), (0, 0, 0)],
        "Arm_R": [(0, 0, 0), (170, 0, 0), (30, 0, 0), (0, 0, 0)],
        "Arm_L": [(0, 0, 0), (150, 0, 0), (25, 0, 0), (0, 0, 0)],
        "Forearm_R": [(0, 0, 0), (40, 0, 0), (10, 0, 0), (0, 0, 0)]}),
    # A short flinch, played additively over locomotion; `stagger` is the longer knockback version.
    ("hit", [0.0, 0.08, 0.25], {
        "Spine": [(0, 0, 0), (-14, 0, 0), (0, 0, 0)],
        "Head": [(0, 0, 0), (-12, 0, 0), (0, 0, 0)],
        "Chest": [(0, 0, 0), (-8, 6, 0), (0, 0, 0)]}),
    ("stagger", [0.0, 0.15, 0.5, 0.8], {
        "Spine": [(0, 0, 0), (-25, 0, 0), (-10, 0, 0), (0, 0, 0)],
        "Head": [(0, 0, 0), (-20, 0, 0), (-8, 0, 0), (0, 0, 0)],
        "Arm_L": [(0, 0, 0), (0, 0, -40), (0, 0, -15), (0, 0, 0)],
        "Arm_R": [(0, 0, 0), (0, 0, 40), (0, 0, 15), (0, 0, 0)]}),
    ("death", [0.0, 0.4, 1.2], {
        "Root": [(0, 0, 0), (30, 0, 0), (85, 0, 0)],
        "Arm_L": [(0, 0, 0), (0, 0, -30), (0, 0, -60)], "Arm_R": [(0, 0, 0), (0, 0, 30), (0, 0, 60)]}),
]


def fabric_bones(tres: Path = SKELETON_TRES) -> list:
    """[(name, parent)] of a fabric skeleton (default HumanoidSkeleton), in order (parents first)."""
    text = tres.read_text(encoding="utf-8")
    match = re.search(r"^bones = ", text, re.M)
    if not match:
        raise SystemExit(f"{tres}: no `bones = [...]` property")
    # raw_decode reads the one JSON array that starts there, however it is wrapped.
    bones, _ = json.JSONDecoder().raw_decode(text, match.end())
    return [(b["name"], b["parent"]) for b in bones]


def _quat_conj(q: list) -> list:
    """The inverse of unit quaternion `q`."""
    return [-q[0], -q[1], -q[2], q[3]]


def _quat_rotate(q: list, v: tuple) -> list:
    """`v` rotated by unit quaternion `q`."""
    return _quat_mul(_quat_mul(q, [v[0], v[1], v[2], 0.0]), _quat_conj(q))[:3]


def _norm(q: tuple) -> list:
    length = math.sqrt(sum(c * c for c in q))
    return [c / length for c in q]


def build_skinned_rig(tres: Path, skin_name: str, joint_pos: dict, rest_rot: dict, parts: list, clips: list,
                      root_name: str = "PlayerRig") -> bytes:
    """A skinned box rig for one fabric skeleton: joints, rests, boxes and clips as the player rig's tables."""
    bones = fabric_bones(tres)
    names = [n for n, _ in bones]
    if sorted(names) != sorted(joint_pos):
        raise SystemExit(f"JOINTS {sorted(joint_pos)} do not match the fabric bones {sorted(names)}")
    index = {n: i for i, n in enumerate(names)}

    # Nodes: 0 the scene root, 1 the skinned mesh, then one per joint in fabric order.
    # A joint's translation and rotation are relative to its parent joint (Root's to the
    # scene root), so the translation is the offset expressed in the parent's rest axes.
    # `world` is each joint's rest rotation in figure space (fabric order is parents first).
    nodes = [{"name": root_name, "children": [1, 2 + index["Root"]]}, {"name": "Body", "mesh": 0, "skin": 0}]
    rest = {n: _norm(rest_rot.get(n, (0.0, 0.0, 0.0, 1.0))) for n in names}
    world: dict = {}
    for name, parent in bones:
        x, y, z = joint_pos[name]
        px, py, pz = joint_pos[parent] if parent else (0.0, 0.0, 0.0)
        pw = world[parent] if parent else [0.0, 0.0, 0.0, 1.0]
        world[name] = _quat_mul(pw, rest[name])
        local = _quat_rotate(_quat_conj(pw), (x - px, y - py, z - pz))
        node = {"name": name, "translation": [round(c, 6) for c in local]}
        if name in rest_rot:
            node["rotation"] = rest[name]
        children = [2 + i for i, (_, p) in enumerate(bones) if p == name]
        if children:
            node["children"] = children
        nodes.append(node)

    positions, normals, joints, weights, indices = [], [], [], [], []
    for joint, centre, size in parts:
        for normal, corners in CUBE_FACES:
            base = len(positions) // 3
            for corner in corners:
                positions.extend(c + s * k for c, s, k in zip(centre, size, corner))
                normals.extend(normal)
                joints.extend([index[joint], 0, 0, 0])
                weights.extend([1.0, 0.0, 0.0, 0.0])
            indices.extend([base, base + 1, base + 2, base, base + 2, base + 3])
    xs, ys, zs = positions[0::3], positions[1::3], positions[2::3]

    blob = Blob()
    accessors: list = []

    def add(payload: bytes, target: int, stride: int, **accessor) -> int:
        accessor["bufferView"] = blob.add(payload, target, stride)
        accessors.append(accessor)
        return len(accessors) - 1

    count = len(positions) // 3
    attributes = {
        "POSITION": add(struct.pack("<%df" % len(positions), *positions), 34962, 12, componentType=5126,
                        count=count, type="VEC3", min=[min(xs), min(ys), min(zs)], max=[max(xs), max(ys), max(zs)]),
        "NORMAL": add(struct.pack("<%df" % len(normals), *normals), 34962, 12, componentType=5126,
                      count=count, type="VEC3"),
        # 5121 = UNSIGNED_BYTE: 18 joints fit, and Godot reads byte joints.
        "JOINTS_0": add(struct.pack("<%dB" % len(joints), *joints), 34962, 4, componentType=5121,
                        count=count, type="VEC4"),
        "WEIGHTS_0": add(struct.pack("<%df" % len(weights), *weights), 34962, 16, componentType=5126,
                         count=count, type="VEC4"),
    }
    index_accessor = add(struct.pack("<%dH" % len(indices), *indices), 34963, 0, componentType=5123,
                         count=len(indices), type="SCALAR")
    # A joint's inverse bind matrix undoes its rest in figure space: rotation R^T, translation
    # -R^T p (column-major, translation in the last column). R^T's columns are R's rows,
    # i.e. the figure axes seen in the joint's frame.
    ibm = []
    for name in names:
        inv = _quat_conj(world[name])
        cols = [_quat_rotate(inv, axis) for axis in ((1, 0, 0), (0, 1, 0), (0, 0, 1))]
        t = _quat_rotate(inv, joint_pos[name])
        ibm.extend([*cols[0], 0.0, *cols[1], 0.0, *cols[2], 0.0, -t[0], -t[1], -t[2], 1.0])
    ibm_accessor = add(struct.pack("<%df" % len(ibm), *ibm), 0, 0, componentType=5126,
                       count=len(names), type="MAT4")

    animations = []
    for clip, times, channels_by_joint in clips:
        input_accessor = add(struct.pack("<%df" % len(times), *times), 0, 0, componentType=5126,
                             count=len(times), type="SCALAR", min=[min(times)], max=[max(times)])
        samplers, channels = [], []
        for joint, keys in channels_by_joint.items():
            assert len(keys) == len(times), "clip %s: %d keys for %d times on %s" % (clip, len(keys), len(times), joint)
            # A figure-space turn D at the joint, on top of its rest: P^-1 D P R, with P the
            # parent's rest in figure space and R the joint's local rest.
            if joint.endswith(":t"):
                # A translation channel ("Root:t"): metres added to the joint's rest offset.
                name = joint[:-2]
                base = nodes[2 + index[name]]["translation"]
                offsets = [c for key in keys for c in (round(base[i] + key[i], 6) for i in range(3))]
                output = add(struct.pack("<%df" % len(offsets), *offsets), 0, 0, componentType=5126,
                             count=len(times), type="VEC3")
                samplers.append({"input": input_accessor, "output": output, "interpolation": "LINEAR"})
                channels.append({"sampler": len(samplers) - 1,
                                 "target": {"node": 2 + index[name], "path": "translation"}})
                continue
            pw = world[bones[index[joint]][1]] if bones[index[joint]][1] else [0.0, 0.0, 0.0, 1.0]
            quats = [c for key in keys
                     for c in _quat_mul(_quat_mul(_quat_conj(pw), _quat_mul(_quat_euler(key), pw)), rest[joint])]
            output = add(struct.pack("<%df" % len(quats), *quats), 0, 0, componentType=5126,
                         count=len(times), type="VEC4")
            samplers.append({"input": input_accessor, "output": output, "interpolation": "LINEAR"})
            channels.append({"sampler": len(samplers) - 1, "target": {"node": 2 + index[joint], "path": "rotation"}})
        animations.append({"name": clip, "samplers": samplers, "channels": channels})

    doc = {
        "asset": {"version": "2.0", "generator": "gen_placeholder_glb.py"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": nodes,
        "meshes": [{"name": "Body", "primitives": [{"attributes": attributes, "indices": index_accessor, "mode": 4}]}],
        "skins": [{"name": skin_name, "joints": [2 + i for i in range(len(names))],
                   "skeleton": 2 + index["Root"], "inverseBindMatrices": ibm_accessor}],
        "buffers": [{"byteLength": len(blob.data)}],
        "bufferViews": blob.views,
        "accessors": accessors,
        "animations": animations,
    }
    return _glb(doc, blob)


def build_player_rig() -> bytes:
    return build_skinned_rig(SKELETON_TRES, "HumanoidSkeleton", JOINTS, REST, PARTS, PLAYER_CLIPS)


# ---------------------------------------------------------------------------
# The GraywolfPack placeholder: `assets/models/creatures/GraywolfPack.glb.raw`
# ---------------------------------------------------------------------------
# Skinned to the fabric QuadrupedSkeleton (same bone names and parents, read from the
# generated .tres). Like the private wolf it faces -Z (head at -z, tail at +z); the fabric
# restPose offsets put the head at +z, so game code must pick one before attaching creature
# models. Joints rest with identity rotations. Clips: the seven the locomotion tree asks for.

QUAD_TRES = SKELETON_TRES.parent / "quadrupedskeleton.tres"
WOLF_OUT = OUT.parent / "creatures" / "GraywolfPack.glb.raw"

WOLF_JOINTS = {
    "Root": (0.0, 0.0, 0.0),
    "Hips": (0.0, 0.62, 0.30),
    "Spine": (0.0, 0.66, 0.05),
    "Chest": (0.0, 0.68, -0.20),
    "Neck": (0.0, 0.72, -0.40),
    "Head": (0.0, 0.78, -0.55),
    "Leg_FL": (-0.12, 0.55, -0.22),
    "Leg_FR": (0.12, 0.55, -0.22),
    "Leg_BL": (-0.12, 0.55, 0.30),
    "Leg_BR": (0.12, 0.55, 0.30),
    "Tail": (0.0, 0.64, 0.45),
}

WOLF_PARTS = [
    ("Hips", (0.0, 0.62, 0.30), (0.24, 0.26, 0.30)),
    ("Spine", (0.0, 0.66, 0.05), (0.22, 0.26, 0.22)),
    ("Chest", (0.0, 0.66, -0.20), (0.26, 0.30, 0.30)),
    ("Neck", (0.0, 0.74, -0.42), (0.14, 0.18, 0.18)),
    ("Head", (0.0, 0.78, -0.62), (0.16, 0.16, 0.22)),
    ("Tail", (0.0, 0.58, 0.58), (0.07, 0.07, 0.30)),
]
for _name, _x, _z in (("FL", -0.12, -0.22), ("FR", 0.12, -0.22), ("BL", -0.12, 0.30), ("BR", 0.12, 0.30)):
    WOLF_PARTS.append(("Leg_" + _name, (_x, 0.27, _z), (0.09, 0.54, 0.10)))


def _gait(swing: float) -> dict:
    """Diagonal pairs swing together: FL+BR against FR+BL."""
    phase = [1.0, 0.0, -1.0, 0.0, 1.0]
    return {"Leg_FL": [(swing * p, 0, 0) for p in phase], "Leg_BR": [(swing * p, 0, 0) for p in phase],
            "Leg_FR": [(-swing * p, 0, 0) for p in phase], "Leg_BL": [(-swing * p, 0, 0) for p in phase]}


WOLF_CLIPS = [
    # Head bob and tail sway.
    ("idle", [0.0, 0.75, 1.5, 2.25, 3.0], {
        "Head": [(0, 0, 0), (12, 0, 0), (0, 0, 0), (12, 0, 0), (0, 0, 0)],
        "Tail": [(0, 0, 0), (0, 18, 0), (0, 0, 0), (0, -18, 0), (0, 0, 0)]}),
    ("idle_look", [0.0, 0.6, 1.8, 2.4], {
        "Head": [(0, 0, 0), (0, 40, 0), (0, -40, 0), (0, 0, 0)],
        "Neck": [(0, 0, 0), (0, 15, 0), (0, -15, 0), (0, 0, 0)]}),
    ("walk", [0.0, 0.25, 0.5, 0.75, 1.0], _gait(20)),
    ("run", [0.0, 0.15, 0.3, 0.45, 0.6], dict(_gait(40), Spine=[(-6, 0, 0)] * 5)),
    ("fall", [0.0, 0.4, 0.8], {"Leg_FL": [(-30, 0, 0)] * 3, "Leg_FR": [(-30, 0, 0)] * 3,
                                "Leg_BL": [(30, 0, 0)] * 3, "Leg_BR": [(30, 0, 0)] * 3}),
    ("land", [0.0, 0.12, 0.25], {"Spine": [(14, 0, 0), (7, 0, 0), (0, 0, 0)]}),
    ("attack", [0.0, 0.15, 0.3, 0.5], {"Head": [(0, 0, 0), (-25, 0, 0), (20, 0, 0), (0, 0, 0)],
                                        "Neck": [(0, 0, 0), (-15, 0, 0), (10, 0, 0), (0, 0, 0)]}),
    ("hit", [0.0, 0.08, 0.25], {"Spine": [(0, 0, 0), (-14, 0, 0), (0, 0, 0)],
                                "Head": [(0, 0, 0), (-18, 0, 0), (0, 0, 0)]}),
    ("death", [0.0, 0.4, 1.2], {"Root": [(0, 0, 0), (0, 0, 30), (0, 0, 85)]}),
]


def build_wolf_rig() -> bytes:
    return build_skinned_rig(QUAD_TRES, "QuadrupedSkeleton", WOLF_JOINTS, {}, WOLF_PARTS, WOLF_CLIPS, "WolfRig")


# ---------------------------------------------------------------------------
# The rest of the creature roster (phase A7 of project-nihon-assets)
# ---------------------------------------------------------------------------
# The fabric names no skeleton family on a creature entity; these families are assumed:
# Quadruped (the wolf rig, reused) for ForestBoar, SteppeBison, GlimmerFox, VeilStalker and
# RiftWarden, Bird for RidgeHawk and CinderGargoyle, Serpent for VoidSerpent and LavaSlug.
# Every rig carries the seven locomotion clips: idle, walk, run, fall, land, attack, death.

CREATURES_DIR = OUT.parent / "creatures"
QUADRUPED_CREATURES = ["ForestBoar", "SteppeBison", "GlimmerFox", "VeilStalker", "RiftWarden"]
BIRD_CREATURES = ["RidgeHawk", "CinderGargoyle"]
SERPENT_CREATURES = ["VoidSerpent", "LavaSlug"]

BIRD_TRES = SKELETON_TRES.parent / "birdskeleton.tres"
SERPENT_TRES = SKELETON_TRES.parent / "serpentskeleton.tres"

# Bird faces -Z like the wolf; wings spread along X.
BIRD_JOINTS = {
    "Root": (0.0, 0.0, 0.0),
    "Spine": (0.0, 0.50, 0.0),
    "Neck": (0.0, 0.62, -0.18),
    "Head": (0.0, 0.70, -0.30),
    "Wing_L": (-0.12, 0.58, -0.02),
    "Wing_R": (0.12, 0.58, -0.02),
    "Leg_L": (-0.07, 0.38, 0.04),
    "Leg_R": (0.07, 0.38, 0.04),
}

BIRD_PARTS = [
    ("Spine", (0.0, 0.50, 0.04), (0.20, 0.20, 0.38)),
    ("Neck", (0.0, 0.64, -0.20), (0.08, 0.14, 0.08)),
    ("Head", (0.0, 0.72, -0.32), (0.12, 0.12, 0.14)),
    ("Wing_L", (-0.34, 0.58, 0.0), (0.44, 0.04, 0.26)),
    ("Wing_R", (0.34, 0.58, 0.0), (0.44, 0.04, 0.26)),
    ("Leg_L", (-0.07, 0.19, 0.04), (0.05, 0.38, 0.05)),
    ("Leg_R", (0.07, 0.19, 0.04), (0.05, 0.38, 0.05)),
]

_FLAP = [0.0, 0.25, 0.5, 0.75, 1.0]
BIRD_CLIPS = [
    # Preen: the head turns to each wing in turn.
    ("idle", [0.0, 0.75, 1.5, 2.25, 3.0], {
        "Head": [(0, 0, 0), (0, 30, 0), (0, 0, 0), (0, -30, 0), (0, 0, 0)],
        "Wing_L": [(0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 12), (0, 0, 0)],
        "Wing_R": [(0, 0, 0), (0, 0, -12), (0, 0, 0), (0, 0, 0), (0, 0, 0)]}),
    ("idle_look", [0.0, 0.5, 1.5, 2.0], {"Head": [(0, 0, 0), (0, 45, 0), (0, -45, 0), (0, 0, 0)]}),
    ("walk", [0.0, 0.25, 0.5, 0.75, 1.0], {"Leg_L": [(20 * p, 0, 0) for p in (1, 0, -1, 0, 1)],
                                           "Leg_R": [(-20 * p, 0, 0) for p in (1, 0, -1, 0, 1)]}),
    ("run", [0.0, 0.15, 0.3, 0.45, 0.6], {"Leg_L": [(35 * p, 0, 0) for p in (1, 0, -1, 0, 1)],
                                          "Leg_R": [(-35 * p, 0, 0) for p in (1, 0, -1, 0, 1)]}),
    ("fall", _FLAP, {"Wing_L": [(0, 0, a) for a in (-40, 40, -40, 40, -40)],
                     "Wing_R": [(0, 0, -a) for a in (-40, 40, -40, 40, -40)]}),
    ("land", [0.0, 0.12, 0.25], {"Spine": [(14, 0, 0), (7, 0, 0), (0, 0, 0)]}),
    ("attack", [0.0, 0.15, 0.3, 0.5], {"Head": [(0, 0, 0), (-30, 0, 0), (20, 0, 0), (0, 0, 0)],
                                        "Neck": [(0, 0, 0), (-15, 0, 0), (10, 0, 0), (0, 0, 0)]}),
    ("hit", [0.0, 0.08, 0.25], {"Spine": [(0, 0, 0), (-14, 0, 0), (0, 0, 0)],
                                "Head": [(0, 0, 0), (-20, 0, 0), (0, 0, 0)]}),
    ("death", [0.0, 0.4, 1.2], {"Root": [(0, 0, 0), (0, 0, 30), (0, 0, 85)]}),
]

# Serpent lies along Z, head at -z, each spine segment a box.
SERPENT_JOINTS = {
    "Root": (0.0, 0.0, 0.0),
    "Spine_1": (0.0, 0.15, 0.50),
    "Spine_2": (0.0, 0.15, 0.10),
    "Spine_3": (0.0, 0.15, -0.30),
    "Neck": (0.0, 0.20, -0.65),
    "Head": (0.0, 0.25, -0.85),
}

SERPENT_PARTS = [
    ("Spine_1", (0.0, 0.15, 0.30), (0.26, 0.26, 0.42)),
    ("Spine_2", (0.0, 0.15, -0.10), (0.24, 0.24, 0.42)),
    ("Spine_3", (0.0, 0.15, -0.48), (0.20, 0.20, 0.36)),
    ("Neck", (0.0, 0.22, -0.75), (0.14, 0.16, 0.20)),
    ("Head", (0.0, 0.26, -0.95), (0.16, 0.14, 0.22)),
]


def _slither(amp: float) -> dict:
    """Spine segments sway left and right in a travelling wave."""
    return {"Spine_1": [(0, a, 0) for a in (amp, 0, -amp, 0, amp)],
            "Spine_2": [(0, a, 0) for a in (0, -amp, 0, amp, 0)],
            "Spine_3": [(0, a, 0) for a in (-amp, 0, amp, 0, -amp)]}


SERPENT_CLIPS = [
    # A slow coil: the body sways and the head weaves.
    ("idle", [0.0, 0.75, 1.5, 2.25, 3.0], dict(
        _slither(12), Head=[(0, 0, 0), (0, 25, 0), (0, 0, 0), (0, -25, 0), (0, 0, 0)])),
    ("idle_look", [0.0, 0.5, 1.5, 2.0], {"Head": [(0, 0, 0), (0, 40, 0), (0, -40, 0), (0, 0, 0)],
                                         "Neck": [(0, 0, 0), (-15, 0, 0), (-15, 0, 0), (0, 0, 0)]}),
    ("walk", [0.0, 0.25, 0.5, 0.75, 1.0], _slither(15)),
    ("run", [0.0, 0.15, 0.3, 0.45, 0.6], _slither(25)),
    ("fall", [0.0, 0.4, 0.8], {"Spine_2": [(10, 0, 0), (35, 0, 0), (10, 0, 0)]}),
    ("land", [0.0, 0.12, 0.25], {"Spine_2": [(14, 0, 0), (7, 0, 0), (0, 0, 0)]}),
    ("attack", [0.0, 0.15, 0.3, 0.5], {"Neck": [(0, 0, 0), (-30, 0, 0), (25, 0, 0), (0, 0, 0)],
                                        "Head": [(0, 0, 0), (-20, 0, 0), (15, 0, 0), (0, 0, 0)]}),
    ("hit", [0.0, 0.08, 0.25], {"Neck": [(0, 0, 0), (-18, 0, 0), (0, 0, 0)],
                                "Head": [(0, 0, 0), (-20, 0, 0), (0, 0, 0)]}),
    ("death", [0.0, 0.4, 1.2], {"Root": [(0, 0, 0), (0, 0, 30), (0, 0, 85)]}),
]


def creature_rigs() -> dict:
    """{GLB path: bytes} for the roster beyond GraywolfPack."""
    quad = build_wolf_rig()
    bird = build_skinned_rig(BIRD_TRES, "BirdSkeleton", BIRD_JOINTS, {}, BIRD_PARTS, BIRD_CLIPS, "BirdRig")
    serpent = build_skinned_rig(SERPENT_TRES, "SerpentSkeleton", SERPENT_JOINTS, {}, SERPENT_PARTS, SERPENT_CLIPS, "SerpentRig")
    rigs = {}
    for names, data in ((QUADRUPED_CREATURES, quad), (BIRD_CREATURES, bird), (SERPENT_CREATURES, serpent)):
        for name in names:
            rigs[CREATURES_DIR / f"{name}.glb.raw"] = data
    return rigs


# Phase 157 — the death variants every rig carries, picked by the hit direction: `death_back` (thrown
# backwards), `death_forward` (falls on its face), `death_side`. Each ends lying 85 degrees down with
# Root lifted DEATH_LIFT_M, so the lowest bone rests within 5 cm of the ground instead of sinking.
DEATH_LIFT_M = 0.045
DEATH_TIMES = [0.0, 0.3, 0.9]


def _death(axis: int, sign: float) -> dict:
    keys = [(0, 0, 0), tuple(sign * 30 if i == axis else 0 for i in range(3)),
            tuple(sign * 85 if i == axis else 0 for i in range(3))]
    return {"Root": keys, "Root:t": [(0, 0, 0), (0, DEATH_LIFT_M / 2, 0), (0, DEATH_LIFT_M, 0)]}


DEATH_VARIANTS = [("death_back", DEATH_TIMES, _death(0, 1)),
                  ("death_forward", DEATH_TIMES, _death(0, -1)),
                  ("death_side", DEATH_TIMES, _death(2, 1))]


def _grounded_death(clips: list) -> None:
    """Lift the plain `death` to rest on the ground too, then add the variants."""
    for name, _times, channels in clips:
        if name == "death":
            channels["Root:t"] = [(0, 0, 0), (0, DEATH_LIFT_M / 2, 0), (0, DEATH_LIFT_M, 0)]
    clips.extend(DEATH_VARIANTS)


for _clips in (PLAYER_CLIPS, WOLF_CLIPS, BIRD_CLIPS, SERPENT_CLIPS):
    _grounded_death(_clips)

# Phase 159 — one clip per fabric Gesture (`fabric/gameplay/gestures.js`), on the player rig only. Poses
# (sit, sit_ground, lie_down, kneel) end in the held position and the runtime holds the last key; the
# one-shots return to locomotion. Joint angles are degrees; "Root:t" is metres. The thigh swings forward
# with +X and the knee bends with -X (as in `land`), the raised arm is +X forward / +-Z out to the side.
def _both(left, right=None):
    return {"Leg_L": left, "Leg_R": right or left}


GESTURE_CLIPS = [
    ("sit", [0.0, 0.4, 0.8], {
        "Root:t": [(0, 0, 0), (0, -0.25, 0), (0, -0.5, 0)],
        **_both([(0, 0, 0), (55, 0, 0), (90, 0, 0)]),
        "Shin_L": [(0, 0, 0), (-55, 0, 0), (-90, 0, 0)], "Shin_R": [(0, 0, 0), (-55, 0, 0), (-90, 0, 0)],
        "Arm_L": [(0, 0, 0), (20, 0, 0), (35, 0, 0)], "Arm_R": [(0, 0, 0), (20, 0, 0), (35, 0, 0)],
        "Forearm_L": [(0, 0, 0), (30, 0, 0), (60, 0, 0)], "Forearm_R": [(0, 0, 0), (30, 0, 0), (60, 0, 0)]}),
    ("sit_ground", [0.0, 0.5, 1.0], {
        "Root:t": [(0, 0, 0), (0, -0.45, 0), (0, -0.82, 0)],
        **_both([(0, 0, 0), (50, 0, 0), (88, 0, 0)]),
        "Shin_L": [(0, 0, 0), (-20, 0, 0), (-8, 0, 0)], "Shin_R": [(0, 0, 0), (-20, 0, 0), (-8, 0, 0)],
        "Spine": [(0, 0, 0), (5, 0, 0), (10, 0, 0)],
        "Arm_L": [(0, 0, 0), (15, 0, 0), (25, 0, 0)], "Arm_R": [(0, 0, 0), (15, 0, 0), (25, 0, 0)]}),
    ("lie_down", [0.0, 0.6, 1.4], {
        "Root": [(0, 0, 0), (-35, 0, 0), (-88, 0, 0)],
        "Root:t": [(0, 0, 0), (0, 0.02, 0), (0, 0.045, 0)],
        "Arm_L": [(0, 0, 0), (0, 0, -10), (0, 0, -15)], "Arm_R": [(0, 0, 0), (0, 0, 10), (0, 0, 15)]}),
    ("wave", [0.0, 0.3, 0.55, 0.8, 1.05, 1.3, 1.6], {
        "Arm_R": [(0, 0, 0), (0, 0, 150), (0, 0, 150), (0, 0, 150), (0, 0, 150), (0, 0, 150), (0, 0, 0)],
        "Forearm_R": [(0, 0, 0), (-10, 0, 0), (-40, 0, 0), (10, 0, 0), (-40, 0, 0), (10, 0, 0), (0, 0, 0)],
        "Head": [(0, 0, 0), (0, 10, 0), (0, 10, 0), (0, 10, 0), (0, 10, 0), (0, 10, 0), (0, 0, 0)]}),
    ("point", [0.0, 0.3, 1.0, 1.4], {
        "Arm_R": [(0, 0, 0), (85, 0, 0), (85, 0, 0), (0, 0, 0)],
        "Chest": [(0, 0, 0), (0, -12, 0), (0, -12, 0), (0, 0, 0)],
        "Head": [(0, 0, 0), (0, -15, 0), (0, -15, 0), (0, 0, 0)]}),
    ("bow", [0.0, 0.5, 1.1, 1.6], {
        "Spine": [(0, 0, 0), (35, 0, 0), (35, 0, 0), (0, 0, 0)],
        "Chest": [(0, 0, 0), (20, 0, 0), (20, 0, 0), (0, 0, 0)],
        "Head": [(0, 0, 0), (15, 0, 0), (15, 0, 0), (0, 0, 0)],
        "Arm_L": [(0, 0, 0), (10, 0, 0), (10, 0, 0), (0, 0, 0)], "Arm_R": [(0, 0, 0), (10, 0, 0), (10, 0, 0), (0, 0, 0)]}),
    ("cheer", [0.0, 0.3, 0.6, 0.9, 1.2, 1.5], {
        "Arm_L": [(0, 0, 0), (0, 0, -160), (0, 0, -150), (0, 0, -160), (0, 0, -150), (0, 0, 0)],
        "Arm_R": [(0, 0, 0), (0, 0, 160), (0, 0, 150), (0, 0, 160), (0, 0, 150), (0, 0, 0)],
        "Spine": [(0, 0, 0), (-8, 0, 0), (-4, 0, 0), (-8, 0, 0), (-4, 0, 0), (0, 0, 0)],
        "Root:t": [(0, 0, 0), (0, 0.05, 0), (0, 0, 0), (0, 0.05, 0), (0, 0, 0), (0, 0, 0)]}),
    ("shrug", [0.0, 0.3, 0.9, 1.2], {
        "Shoulder_L": [(0, 0, 0), (0, 0, 15), (0, 0, 15), (0, 0, 0)], "Shoulder_R": [(0, 0, 0), (0, 0, -15), (0, 0, -15), (0, 0, 0)],
        "Forearm_L": [(0, 0, 0), (45, 0, 0), (45, 0, 0), (0, 0, 0)], "Forearm_R": [(0, 0, 0), (45, 0, 0), (45, 0, 0), (0, 0, 0)],
        "Head": [(0, 0, 0), (0, 0, 12), (0, 0, 12), (0, 0, 0)]}),
    ("clap", [0.0, 0.25, 0.45, 0.65, 0.85, 1.05], {
        "Arm_L": [(0, 0, 0), (70, 0, 20), (70, 0, 5), (70, 0, 20), (70, 0, 5), (0, 0, 0)],
        "Arm_R": [(0, 0, 0), (70, 0, -20), (70, 0, -5), (70, 0, -20), (70, 0, -5), (0, 0, 0)],
        "Forearm_L": [(0, 0, 0), (50, 0, 0), (50, 0, 0), (50, 0, 0), (50, 0, 0), (0, 0, 0)],
        "Forearm_R": [(0, 0, 0), (50, 0, 0), (50, 0, 0), (50, 0, 0), (50, 0, 0), (0, 0, 0)]}),
    ("kneel", [0.0, 0.4, 0.9], {
        "Root:t": [(0, 0, 0), (0, -0.25, 0), (0, -0.48, 0)],
        "Leg_L": [(0, 0, 0), (40, 0, 0), (80, 0, 0)], "Leg_R": [(0, 0, 0), (-5, 0, 0), (-10, 0, 0)],
        "Shin_L": [(0, 0, 0), (-40, 0, 0), (-80, 0, 0)], "Shin_R": [(0, 0, 0), (-90, 0, 0), (-150, 0, 0)],
        "Head": [(0, 0, 0), (10, 0, 0), (20, 0, 0)]}),
]
PLAYER_CLIPS.extend(GESTURE_CLIPS)

# ---------------------------------------------------------------------------
# Phase 180 — character creation: chibi bodies, heads and hair
# ---------------------------------------------------------------------------
# `models/characters/bodies/<body>.glb.raw`: the two gender bodies of the creation presets
# (fabric/gameplay/characters/appearances.js), skinned to HumanoidSkeleton with every player clip, like
# player_rig. Chibi: about 1.1 m tall, a 0.40 m head (a third of the height), short limbs, big hands
# and boots. `models/characters/heads/<head>.glb.raw`: the head alone, origin at the Head joint.
# `models/characters/hair/<hair>.glb.raw`: one static mesh of boxes per hair style of
# fabric/gameplay/characters/creation.js, origin at the Head joint, drawn from the style's `shape`.
CHAR_DIR = OUT.parent / "characters"
CREATION_JS = Path(__file__).resolve().parent.parent / "fabric" / "gameplay" / "characters" / "creation.js"


def _chibi_tables(shoulder: float, hip: float) -> tuple:
    """(joints, parts) of a chibi body; `shoulder` and `hip` scale the half-widths."""
    joints = {
        "Root": (0.0, 0.0, 0.0), "Hips": (0.0, 0.42, 0.0), "Spine": (0.0, 0.50, 0.0),
        "Chest": (0.0, 0.58, 0.0), "Neck": (0.0, 0.68, 0.0), "Head": (0.0, 0.70, 0.0),
    }
    parts = [
        ("Hips", (0.0, 0.40, 0.0), (0.26 * hip, 0.10, 0.18)),
        ("Spine", (0.0, 0.50, 0.0), (0.24, 0.12, 0.17)),
        ("Chest", (0.0, 0.60, 0.0), (0.30 * shoulder, 0.14, 0.20)),
        ("Neck", (0.0, 0.68, 0.0), (0.08, 0.04, 0.08)),
        ("Head", (0.0, 0.90, 0.0), (0.44, 0.40, 0.42)),
    ]
    for side, sx in (("L", -1.0), ("R", 1.0)):
        joints.update({
            "Shoulder_" + side: (sx * 0.03, 0.64, 0.0), "Arm_" + side: (sx * 0.14 * shoulder, 0.64, 0.0),
            "Forearm_" + side: (sx * 0.155 * shoulder, 0.52, 0.0), "Hand_" + side: (sx * 0.165 * shoulder, 0.43, 0.0),
            "Leg_" + side: (sx * 0.07 * hip, 0.38, 0.0), "Shin_" + side: (sx * 0.07 * hip, 0.21, 0.0),
            "Foot_" + side: (sx * 0.07 * hip, 0.05, 0.0),
        })
        parts += [
            ("Arm_" + side, (sx * 0.15 * shoulder, 0.58, 0.0), (0.09, 0.13, 0.09)),
            ("Forearm_" + side, (sx * 0.16 * shoulder, 0.475, 0.0), (0.08, 0.10, 0.08)),
            ("Hand_" + side, (sx * 0.17 * shoulder, 0.39, 0.0), (0.10, 0.09, 0.11)),
            ("Leg_" + side, (sx * 0.07 * hip, 0.30, 0.0), (0.11, 0.17, 0.12)),
            ("Shin_" + side, (sx * 0.07 * hip, 0.14, 0.0), (0.10, 0.14, 0.11)),
            ("Foot_" + side, (sx * 0.07 * hip, 0.04, -0.03), (0.13, 0.08, 0.21)),
        ]
    return joints, parts


CHIBI_BODIES = {"chibi_body_m": (1.0, 1.0), "chibi_body_f": (0.9, 1.08)}
CHIBI_HEADS = {"chibi_head_m": (0.44, 0.40, 0.42), "chibi_head_f": (0.42, 0.40, 0.40)}

# Hair shapes as boxes (centre, size) in head space: origin at the Head joint, the head box spans
# x +-0.22, y 0..0.40, z +-0.21, the face looks down -Z. Every shape starts from a cap.
_CAP = [((0.0, 0.37, 0.01), (0.48, 0.10, 0.46))]
_BACK = [((0.0, 0.24, 0.225), (0.47, 0.24, 0.06))]
_FRINGE = [((0.0, 0.31, -0.225), (0.46, 0.08, 0.05))]
_SIDES = [((sx * 0.245, 0.20, 0.0), (0.05, 0.30, 0.44)) for sx in (-1.0, 1.0)]
HAIR_BOXES = {
    "crop": _CAP + [((0.0, 0.27, 0.215), (0.46, 0.16, 0.05))],
    "spiky": _CAP + _BACK + [((x, 0.47, z), (0.09, 0.14, 0.09))
                             for x, z in ((0.0, 0.0), (-0.14, -0.08), (0.14, -0.08), (-0.12, 0.12), (0.12, 0.12))],
    "swept": _CAP + _BACK + [((-0.07, 0.33, -0.225), (0.34, 0.10, 0.06)), ((-0.20, 0.42, 0.0), (0.10, 0.08, 0.30))],
    "mop": [((0.0, 0.37, 0.0), (0.52, 0.14, 0.50))] + _SIDES + _FRINGE + _BACK,
    "topknot": _CAP + _BACK + [((0.0, 0.48, 0.06), (0.13, 0.13, 0.13))],
    "mohawk": [((0.0, 0.46, 0.02), (0.09, 0.18, 0.44)), ((0.0, 0.34, 0.215), (0.09, 0.14, 0.05))],
    "bob": _CAP + _SIDES + _FRINGE + [((0.0, 0.20, 0.23), (0.48, 0.32, 0.06))],
    "long": _CAP + _FRINGE + [((sx * 0.245, 0.10, 0.02), (0.05, 0.50, 0.40)) for sx in (-1.0, 1.0)]
            + [((0.0, 0.02, 0.235), (0.48, 0.72, 0.07))],
    "twintails": _CAP + _FRINGE + _BACK + [((sx * 0.30, 0.04, 0.12), (0.10, 0.46, 0.10)) for sx in (-1.0, 1.0)]
                 + [((sx * 0.27, 0.30, 0.12), (0.08, 0.08, 0.08)) for sx in (-1.0, 1.0)],
    "ponytail": _CAP + _FRINGE + _BACK + [((0.0, 0.12, 0.30), (0.11, 0.42, 0.11)), ((0.0, 0.34, 0.27), (0.08, 0.08, 0.08))],
    "bun": _CAP + _FRINGE + _BACK + [((0.0, 0.40, 0.25), (0.19, 0.17, 0.15))],
    "braid": _CAP + _FRINGE + _BACK + [((0.17, -0.04, 0.14), (0.08, 0.56, 0.08)), ((0.17, -0.34, 0.14), (0.11, 0.06, 0.11))],
}


def read_hair_styles() -> dict:
    """hair id -> shape, from creation.js (`HAIR_STYLES`)."""
    m = re.search(r"const HAIR_STYLES = \{(.*?)^\}", CREATION_JS.read_text(), re.M | re.S)
    if not m:
        raise SystemExit(f"{CREATION_JS}: HAIR_STYLES not found")
    styles = dict(re.findall(r"^\s+(\w+):\s*\{[^}]*shape:\s*'(\w+)'", m.group(1), re.M))
    missing = sorted({sh for sh in styles.values() if sh not in HAIR_BOXES})
    if missing:
        raise SystemExit(f"hair shapes without boxes in gen_placeholder_glb.py: {missing}")
    return styles


def build_static(boxes: list, name: str) -> bytes:
    """One static mesh of boxes ((centre, size) pairs), on one node named `name`."""
    positions, normals, indices = [], [], []
    for (cx, cy, cz), (sx, sy, sz) in boxes:
        for normal, corners in CUBE_FACES:
            base = len(positions) // 3
            for x, y, z in corners:
                positions.extend([round(cx + x * sx, 6), round(cy + y * sy, 6), round(cz + z * sz, 6)])
                normals.extend(normal)
            indices.extend([base, base + 1, base + 2, base, base + 2, base + 3])
    blob = Blob()
    views = [
        blob.add(struct.pack("<%df" % len(positions), *positions), 34962, 12),
        blob.add(struct.pack("<%df" % len(normals), *normals), 34962, 12),
        blob.add(struct.pack("<%dH" % len(indices), *indices), 34963),
    ]
    xs, ys, zs = positions[0::3], positions[1::3], positions[2::3]
    accessors = [
        {"bufferView": views[0], "componentType": 5126, "count": len(xs), "type": "VEC3",
         "min": [min(xs), min(ys), min(zs)], "max": [max(xs), max(ys), max(zs)]},
        {"bufferView": views[1], "componentType": 5126, "count": len(xs), "type": "VEC3"},
        {"bufferView": views[2], "componentType": 5123, "count": len(indices), "type": "SCALAR"},
    ]
    doc = {
        "asset": {"version": "2.0", "generator": "gen_placeholder_glb.py"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": name, "mesh": 0}],
        "meshes": [{"name": name, "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1}, "indices": 2, "mode": 4}]}],
        "buffers": [{"byteLength": len(blob.data)}],
        "bufferViews": blob.views,
        "accessors": accessors,
    }
    return _glb(doc, blob)


def character_parts() -> dict:
    """{GLB path: bytes} for the creation bodies, heads and hair styles."""
    out = {}
    for body, (shoulder, hip) in CHIBI_BODIES.items():
        joints, parts = _chibi_tables(shoulder, hip)
        out[CHAR_DIR / "bodies" / f"{body}.glb.raw"] = build_skinned_rig(
            SKELETON_TRES, "HumanoidSkeleton", joints, REST, parts, PLAYER_CLIPS, "ChibiRig")
    for head, size in CHIBI_HEADS.items():
        out[CHAR_DIR / "heads" / f"{head}.glb.raw"] = build_static([((0.0, 0.20, 0.0), size)], "Head")
    for hair, shape in sorted(read_hair_styles().items()):
        out[CHAR_DIR / "hair" / f"{hair}.glb.raw"] = build_static(HAIR_BOXES[shape], "Hair")
    return out


LOOP_CLIPS = ("idle", "walk", "run", "fall")
MIN_PEAK_DEGREES = 10.0
RIGS = lambda: {"player": PLAYER_CLIPS, "wolf": WOLF_CLIPS, "bird": BIRD_CLIPS, "serpent": SERPENT_CLIPS}


def check_loops() -> list:
    """Problems found in the loop clips of every placeholder rig: a looped clip must end where it
    starts, for every joint, or it hitches at the seam. Empty when all close."""
    problems = []
    for rig, clips in RIGS().items():
        for name, times, joints in clips:
            if name not in LOOP_CLIPS:
                continue
            if len(times) < 2 or times[-1] <= times[0]:
                problems.append(f"{rig}/{name}: key times {times} do not span a cycle")
            for joint, keys in joints.items():
                if len(keys) != len(times):
                    problems.append(f"{rig}/{name}/{joint}: {len(keys)} keys for {len(times)} times")
                elif tuple(keys[0]) != tuple(keys[-1]):
                    problems.append(f"{rig}/{name}/{joint}: last key {keys[-1]} != first {keys[0]}")
    return problems


def check_peaks() -> list:
    """Clips whose largest joint rotation is under MIN_PEAK_DEGREES: present but invisible."""
    problems = []
    for rig, clips in RIGS().items():
        for name, _times, joints in clips:
            peak = max((abs(v) for joint, keys in joints.items() if not joint.endswith(":t") for key in keys for v in key), default=0.0)
            if peak < MIN_PEAK_DEGREES:
                problems.append(f"{rig}/{name}: peak rotation {peak} degrees is under {MIN_PEAK_DEGREES}")
    return problems


if __name__ == "__main__":
    if "--check" in sys.argv:
        found = check_loops() + check_peaks()
        for line in found:
            print(line)
        sys.exit(1 if found else 0)
    outputs = {OUT: build(), PLAYER_OUT: build_player_rig(), WOLF_OUT: build_wolf_rig(), **creature_rigs(), **character_parts()}
    for path, data in outputs.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        print(f"wrote {path} ({path.stat().st_size} bytes)")
