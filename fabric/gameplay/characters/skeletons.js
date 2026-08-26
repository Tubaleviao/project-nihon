const { defineEntity, SKELETON_FAMILIES, SEMANTIC_TAGS } = require('./shared')

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton definitions (characters.md §3, §4, §5)
//
// A SkeletonDefinition describes a character type's bone structure. `bones` is
// an ordered chain [{ name, parent }] (parents precede children); `sockets` maps
// a semantic attachment point to a bone. A weapon attaches to `socket_weapon_r`,
// never to a raw bone name (§5). Characters sharing a family can share
// animations, equipment, poses, emotes, and combat systems (§3).
// ─────────────────────────────────────────────────────────────────────────────

module.exports = {

  HumanoidSkeleton: defineEntity({
    tags: ['skeleton'],
    description:
      'Bipedal humanoid bone structure with two arms, two legs, and a head. ' +
      'The shared rig for humans and humanoid races; carries the full set of ' +
      'equipment sockets (head, face, chest, back, cape, weapon, shield, hips, mount).',
    goal: 'Provide a rig that supports the complete humanoid equipment and attachment set',
    fields: {
      family: { type: 'string', description: 'Skeleton family', defaultValue: 'humanoid' },
      bones: {
        type: 'json',
        description: 'Ordered bone chain [{ name, parent }]; parents precede children',
        defaultValue: [
          { name: 'Root', parent: '' },
          { name: 'Hips', parent: 'Root' },
          { name: 'Spine', parent: 'Hips' },
          { name: 'Chest', parent: 'Spine' },
          { name: 'Neck', parent: 'Chest' },
          { name: 'Head', parent: 'Neck' },
          { name: 'Shoulder_L', parent: 'Chest' },
          { name: 'Arm_L', parent: 'Shoulder_L' },
          { name: 'Forearm_L', parent: 'Arm_L' },
          { name: 'Hand_L', parent: 'Forearm_L' },
          { name: 'Shoulder_R', parent: 'Chest' },
          { name: 'Arm_R', parent: 'Shoulder_R' },
          { name: 'Forearm_R', parent: 'Arm_R' },
          { name: 'Hand_R', parent: 'Forearm_R' },
          { name: 'Leg_L', parent: 'Hips' },
          { name: 'Foot_L', parent: 'Leg_L' },
          { name: 'Leg_R', parent: 'Hips' },
          { name: 'Foot_R', parent: 'Leg_R' },
        ],
      },
      sockets: {
        type: 'json',
        description: 'Semantic attachment points mapped to bones',
        defaultValue: {
          socket_head: 'Head',
          socket_face: 'Head',
          socket_back: 'Chest',
          socket_cape: 'Chest',
          socket_chest: 'Chest',
          socket_weapon_r: 'Hand_R',
          socket_weapon_l: 'Hand_L',
          socket_shield: 'Hand_L',
          socket_hip_r: 'Hips',
          socket_hip_l: 'Hips',
          socket_mount: 'Hips',
        },
      },
      restPose: {
        type: 'json',
        description:
          'Unscaled local rest position [x, y, z] per bone, applied by SkeletonRig ' +
          'when building the Skeleton3D (characters.md §4)',
        defaultValue: {
          Root:       [0.0, 0.0, 0.0],
          Hips:       [0.0, 0.95, 0.0],
          Spine:      [0.0, 0.15, 0.0],
          Chest:      [0.0, 0.30, 0.0],
          Neck:       [0.0, 0.25, 0.0],
          Head:       [0.0, 0.18, 0.0],
          Shoulder_L: [-0.20, 0.18, 0.0],
          Arm_L:      [-0.05, -0.18, 0.0],
          Forearm_L:  [0.0, -0.28, 0.0],
          Hand_L:     [0.0, -0.26, 0.0],
          Shoulder_R: [0.20, 0.18, 0.0],
          Arm_R:      [0.05, -0.18, 0.0],
          Forearm_R:  [0.0, -0.28, 0.0],
          Hand_R:     [0.0, -0.26, 0.0],
          Leg_L:      [-0.10, -0.40, 0.0],
          Foot_L:     [0.0, -0.45, 0.0],
          Leg_R:      [0.10, -0.40, 0.0],
          Foot_R:     [0.0, -0.45, 0.0],
        },
      },
      bodyShapeCoefficients: {
        type: 'json',
        description:
          'Placeholder body-shape coefficients shared by the visual assembly, socket ' +
          'offsets, and foot IK so all three derive the same landmarks and stay in ' +
          'sync as proportions change (characters.md §9)',
        defaultValue: {
          torsoHeightFactor: 0.62,
          hipHeightFactor: 0.38,
          headSizeFactor: 0.30,
          chestYFactor: 0.6,
          handXFactor: 0.42,
          handYArmFactor: 0.05,
          weaponForwardOffset: 0.15,
          hipSideOffset: 0.2,
          backForwardOffset: -0.25,
          capeUpOffset: 0.15,
          legReachMargin: 0.05,
          footSideFactor: 0.12,
        },
      },
      turnSpeed: { type: 'float', description: 'Facing turn rate in radians/second, applied when binding the avatar to a live controller (§37)', defaultValue: 8.0 },
      semanticTags: { type: 'json', description: 'Semantic compatibility tags (§40)', defaultValue: ['humanoid', 'has_head', 'has_hands', 'has_back_socket', 'can_wield_weapon', 'can_wear_helmet'] },
    },
  }),

  QuadrupedSkeleton: defineEntity({
    tags: ['skeleton'],
    description:
      'Four-legged skeleton (fore and hind legs, spine, neck, head, tail). ' +
      'Shared rig for mounts, domesticated creatures, and quadruped monsters.',
    goal: 'Provide a rig for quadruped creatures and mounts',
    fields: {
      family: { type: 'string', description: 'Skeleton family', defaultValue: 'quadruped' },
      bones: {
        type: 'json',
        description: 'Ordered bone chain [{ name, parent }]',
        defaultValue: [
          { name: 'Root', parent: '' },
          { name: 'Hips', parent: 'Root' },
          { name: 'Spine', parent: 'Hips' },
          { name: 'Chest', parent: 'Spine' },
          { name: 'Neck', parent: 'Chest' },
          { name: 'Head', parent: 'Neck' },
          { name: 'Leg_FL', parent: 'Chest' },
          { name: 'Leg_FR', parent: 'Chest' },
          { name: 'Leg_BL', parent: 'Hips' },
          { name: 'Leg_BR', parent: 'Hips' },
          { name: 'Tail', parent: 'Hips' },
        ],
      },
      sockets: {
        type: 'json',
        description: 'Semantic attachment points mapped to bones',
        defaultValue: {
          socket_head: 'Head',
          socket_face: 'Head',
          socket_back: 'Spine',
          socket_mount: 'Spine',
        },
      },
      restPose: {
        type: 'json',
        description:
          'Unscaled local rest position [x, y, z] per bone, applied by SkeletonRig ' +
          'when building the Skeleton3D (characters.md §4)',
        defaultValue: {
          Root:   [0.0, 0.0, 0.0],
          Hips:   [0.0, 0.55, -0.3],
          Spine:  [0.0, 0.05, 0.35],
          Chest:  [0.0, 0.05, 0.35],
          Neck:   [0.0, 0.05, 0.25],
          Head:   [0.0, 0.05, 0.2],
          Leg_FL: [-0.25, -0.1, 0.0],
          Leg_FR: [0.25, -0.1, 0.0],
          Leg_BL: [-0.25, -0.1, 0.0],
          Leg_BR: [0.25, -0.1, 0.0],
          Tail:   [0.0, 0.0, -0.3],
        },
      },
      turnSpeed: { type: 'float', description: 'Facing turn rate in radians/second, applied when binding the avatar to a live controller (§37)', defaultValue: 4.0 },
      semanticTags: { type: 'json', description: 'Semantic compatibility tags (§40)', defaultValue: ['quadruped', 'has_head', 'has_back_socket'] },
    },
  }),

  BirdSkeleton: defineEntity({
    tags: ['skeleton'],
    description:
      'Bipedal avian skeleton with wings, legs, spine, neck, and head. ' +
      'Shared rig for flying creatures and raptors.',
    goal: 'Provide a rig for avian creatures',
    fields: {
      family: { type: 'string', description: 'Skeleton family', defaultValue: 'bird' },
      bones: {
        type: 'json',
        description: 'Ordered bone chain [{ name, parent }]',
        defaultValue: [
          { name: 'Root', parent: '' },
          { name: 'Spine', parent: 'Root' },
          { name: 'Neck', parent: 'Spine' },
          { name: 'Head', parent: 'Neck' },
          { name: 'Wing_L', parent: 'Spine' },
          { name: 'Wing_R', parent: 'Spine' },
          { name: 'Leg_L', parent: 'Root' },
          { name: 'Leg_R', parent: 'Root' },
        ],
      },
      sockets: {
        type: 'json',
        description: 'Semantic attachment points mapped to bones',
        defaultValue: {
          socket_head: 'Head',
          socket_face: 'Head',
          socket_back: 'Spine',
          socket_mount: 'Spine',
        },
      },
      restPose: {
        type: 'json',
        description:
          'Unscaled local rest position [x, y, z] per bone, applied by SkeletonRig ' +
          'when building the Skeleton3D (characters.md §4)',
        defaultValue: {
          Root:    [0.0, 0.0, 0.0],
          Spine:   [0.0, 0.4, 0.0],
          Neck:    [0.0, 0.15, 0.1],
          Head:    [0.0, 0.12, 0.05],
          Wing_L:  [-0.2, 0.05, 0.0],
          Wing_R:  [0.2, 0.05, 0.0],
          Leg_L:   [-0.08, -0.35, 0.0],
          Leg_R:   [0.08, -0.35, 0.0],
        },
      },
      turnSpeed: { type: 'float', description: 'Facing turn rate in radians/second, applied when binding the avatar to a live controller (§37)', defaultValue: 5.0 },
      semanticTags: { type: 'json', description: 'Semantic compatibility tags (§40)', defaultValue: ['bird', 'has_head', 'has_back_socket'] },
    },
  }),

  SerpentSkeleton: defineEntity({
    tags: ['skeleton'],
    description:
      'Limbless serpentine skeleton built from a segmented spine ending in a head. ' +
      'Shared rig for serpent monsters and worm-like creatures.',
    goal: 'Provide a rig for limbless serpentine creatures',
    fields: {
      family: { type: 'string', description: 'Skeleton family', defaultValue: 'serpent' },
      bones: {
        type: 'json',
        description: 'Ordered bone chain [{ name, parent }]',
        defaultValue: [
          { name: 'Root', parent: '' },
          { name: 'Spine_1', parent: 'Root' },
          { name: 'Spine_2', parent: 'Spine_1' },
          { name: 'Spine_3', parent: 'Spine_2' },
          { name: 'Neck', parent: 'Spine_3' },
          { name: 'Head', parent: 'Neck' },
        ],
      },
      sockets: {
        type: 'json',
        description: 'Semantic attachment points mapped to bones',
        defaultValue: {
          socket_head: 'Head',
          socket_face: 'Head',
        },
      },
      restPose: {
        type: 'json',
        description:
          'Unscaled local rest position [x, y, z] per bone, applied by SkeletonRig ' +
          'when building the Skeleton3D (characters.md §4)',
        defaultValue: {
          Root:    [0.0, 0.0, 0.0],
          Spine_1: [0.0, 0.1, 0.3],
          Spine_2: [0.0, 0.0, 0.3],
          Spine_3: [0.0, 0.0, 0.3],
          Neck:    [0.0, 0.0, 0.2],
          Head:    [0.0, 0.0, 0.15],
        },
      },
      turnSpeed: { type: 'float', description: 'Facing turn rate in radians/second, applied when binding the avatar to a live controller (§37)', defaultValue: 3.0 },
      semanticTags: { type: 'json', description: 'Semantic compatibility tags (§40)', defaultValue: ['serpent', 'has_head'] },
    },
  }),

}
