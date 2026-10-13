#!/usr/bin/env python3
"""Regenerate the committed placeholder rigs: `assets/models/placeholder_rig.glb.raw` and
`assets/models/player_rig.glb.raw` (the second is described above `build_player_rig`).

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


def _quat_x(degrees: float) -> list:
    """A rotation of `degrees` about the X axis as a glTF quaternion (x, y, z, w)."""
    half = math.radians(degrees) / 2.0
    return [math.sin(half), 0.0, 0.0, math.cos(half)]


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
# left at -X). They are not the fabric `restPose` offsets, which put `Leg_*` at the
# ankle; the private rig uses the same positions.

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
    "Foot_L": (-0.10, 0.09, 0.0),
    "Leg_R": (0.10, 0.92, 0.0),
    "Foot_R": (0.10, 0.09, 0.0),
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
        ("Leg_" + _side, (_sx * 0.10, 0.50, 0.0), (0.14, 0.84, 0.15)),
        ("Foot_" + _side, (_sx * 0.10, 0.04, -0.05), (0.11, 0.08, 0.23)),
    ]

# Clips as {joint: [(x, y, z) degrees per key]}, rotations about the joint's parent axes
# (every rest rotation is identity). A hanging limb swings forward (-Z) with +X; an
# upright bone leans back with +X; an arm lifts sideways with -Z (left) / +Z (right).
# walk and run share a stride phase: left leg forward at t=0, right leg forward at half.


def _stride(leg: float, arm: float) -> dict:
    phase = [1.0, 0.0, -1.0, 0.0, 1.0]
    return {
        "Leg_L": [(leg * p, 0, 0) for p in phase], "Leg_R": [(-leg * p, 0, 0) for p in phase],
        "Arm_L": [(-arm * p, 0, 0) for p in phase], "Arm_R": [(arm * p, 0, 0) for p in phase],
    }


PLAYER_CLIPS = [
    ("idle", [0.0, 1.0, 2.0], {
        "Chest": [(0, 0, 0), (-2, 0, 0), (0, 0, 0)], "Head": [(0, 0, 0), (2, 0, 0), (0, 0, 0)],
        "Arm_L": [(0, 0, -3), (0, 0, -5), (0, 0, -3)], "Arm_R": [(0, 0, 3), (0, 0, 5), (0, 0, 3)]}),
    ("walk", [0.0, 0.25, 0.5, 0.75, 1.0], dict(_stride(25, 20),
        Forearm_L=[(15, 0, 0)] * 5, Forearm_R=[(15, 0, 0)] * 5)),
    ("run", [0.0, 0.15, 0.3, 0.45, 0.6], dict(_stride(45, 50),
        Spine=[(-8, 0, 0)] * 5, Forearm_L=[(70, 0, 0)] * 5, Forearm_R=[(70, 0, 0)] * 5)),
    ("fall", [0.0, 0.4, 0.8], {
        "Arm_L": [(0, 0, -70), (0, 0, -90), (0, 0, -70)], "Arm_R": [(0, 0, 70), (0, 0, 90), (0, 0, 70)],
        "Leg_L": [(20, 0, 0), (8, 0, 0), (20, 0, 0)], "Leg_R": [(-10, 0, 0), (-4, 0, 0), (-10, 0, 0)]}),
    ("land", [0.0, 0.12, 0.25], {
        "Spine": [(-20, 0, 0), (-10, 0, 0), (0, 0, 0)],
        "Arm_L": [(25, 0, 0), (12, 0, 0), (0, 0, 0)], "Arm_R": [(25, 0, 0), (12, 0, 0), (0, 0, 0)]}),
    ("attack", [0.0, 0.15, 0.3, 0.5], {
        "Chest": [(0, 0, 0), (0, 15, 0), (-8, -15, 0), (0, 0, 0)],
        "Arm_R": [(0, 0, 0), (160, 0, 0), (40, 0, 0), (0, 0, 0)],
        "Arm_L": [(0, 0, 0), (-15, 0, 0), (15, 0, 0), (0, 0, 0)]}),
    ("death", [0.0, 0.4, 1.2], {
        "Root": [(0, 0, 0), (30, 0, 0), (85, 0, 0)],
        "Arm_L": [(0, 0, 0), (0, 0, -30), (0, 0, -60)], "Arm_R": [(0, 0, 0), (0, 0, 30), (0, 0, 60)]}),
]


def fabric_bones() -> list:
    """[(name, parent)] of the fabric HumanoidSkeleton, in order (parents first)."""
    match = re.search(r"^bones = (\[.*\])$", SKELETON_TRES.read_text(encoding="utf-8"), re.M)
    if not match:
        raise SystemExit(f"{SKELETON_TRES}: no `bones = [...]` line")
    return [(b["name"], b["parent"]) for b in json.loads(match.group(1))]


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


def build_player_rig() -> bytes:
    bones = fabric_bones()
    names = [n for n, _ in bones]
    if sorted(names) != sorted(JOINTS):
        raise SystemExit(f"JOINTS {sorted(JOINTS)} do not match the fabric bones {sorted(names)}")
    index = {n: i for i, n in enumerate(names)}

    # Nodes: 0 the scene root, 1 the skinned mesh, then one per joint in fabric order.
    # A joint's translation is relative to its parent joint (Root's to the scene root).
    nodes = [{"name": "PlayerRig", "children": [1, 2 + index["Root"]]}, {"name": "Body", "mesh": 0, "skin": 0}]
    for name, parent in bones:
        x, y, z = JOINTS[name]
        px, py, pz = JOINTS[parent] if parent else (0.0, 0.0, 0.0)
        node = {"name": name, "translation": [x - px, y - py, z - pz]}
        children = [2 + i for i, (_, p) in enumerate(bones) if p == name]
        if children:
            node["children"] = children
        nodes.append(node)

    positions, normals, joints, weights, indices = [], [], [], [], []
    for joint, centre, size in PARTS:
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
    # Every rest rotation is identity, so a joint's inverse bind matrix is the translation
    # back from its rest position (column-major, translation in the last column).
    ibm = []
    for name in names:
        x, y, z = JOINTS[name]
        ibm.extend([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -x, -y, -z, 1])
    ibm_accessor = add(struct.pack("<%df" % len(ibm), *ibm), 0, 0, componentType=5126,
                       count=len(names), type="MAT4")

    animations = []
    for clip, times, channels_by_joint in PLAYER_CLIPS:
        input_accessor = add(struct.pack("<%df" % len(times), *times), 0, 0, componentType=5126,
                             count=len(times), type="SCALAR", min=[min(times)], max=[max(times)])
        samplers, channels = [], []
        for joint, keys in channels_by_joint.items():
            assert len(keys) == len(times), "clip %s: %d keys for %d times on %s" % (clip, len(keys), len(times), joint)
            quats = [c for key in keys for c in _quat_euler(key)]
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
        "skins": [{"name": "HumanoidSkeleton", "joints": [2 + i for i in range(len(names))],
                   "skeleton": 2 + index["Root"], "inverseBindMatrices": ibm_accessor}],
        "buffers": [{"byteLength": len(blob.data)}],
        "bufferViews": blob.views,
        "accessors": accessors,
        "animations": animations,
    }
    return _glb(doc, blob)


if __name__ == "__main__":
    for path, data in ((OUT, build()), (PLAYER_OUT, build_player_rig())):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        print(f"wrote {path} ({path.stat().st_size} bytes)")
