const { defineEntity } = require('@newel/core')

// ─────────────────────────────────────────────────────────────────────────────
// Character system — shared enumerations (characters.md)
//
// These lists are the design source of truth for the character domain. Scalar
// enumerable fields (equipmentSlot, deformationMode, family, metalTone) are
// declared as `string` rather than `enum` so the generated .tres stores the
// human-readable value instead of an integer index — the character slice reads
// entities generically from GameData and needs the string directly. These
// arrays are referenced from field descriptions and used to build json
// defaults; they remain authoritative for content authors.
// ─────────────────────────────────────────────────────────────────────────────

// Skeleton families (characters.md §3).
const SKELETON_FAMILIES = ['humanoid', 'quadruped', 'bird', 'serpent', 'custom']

// Equipment slots — "what is equipped?" (characters.md §6, §15).
const EQUIPMENT_SLOTS = ['Head', 'Chest', 'Hands', 'Legs', 'Feet', 'Cape', 'Back', 'MainHand', 'OffHand']

// Attachment states — "where is it visually attached?" (characters.md §7).
const ATTACHMENT_STATES = ['Equipped', 'Stored', 'Sheathed', 'Hidden', 'Dropped']

// Equipment deformation modes (characters.md §10).
const DEFORMATION_MODES = ['SKINNED', 'RIGID', 'HYBRID']

// Semantic compatibility tags (characters.md §39, §40).
const SEMANTIC_TAGS = [
  'humanoid',
  'quadruped',
  'has_hands',
  'has_head',
  'can_wield_weapon',
  'can_wear_helmet',
  'has_back_socket',
]

module.exports = {
  defineEntity,
  SKELETON_FAMILIES,
  EQUIPMENT_SLOTS,
  ATTACHMENT_STATES,
  DEFORMATION_MODES,
  SEMANTIC_TAGS,
}
