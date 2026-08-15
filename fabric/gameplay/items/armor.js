const { defineEntity, RARITIES, DURABILITY_STATES, itemStateMachine, equipmentVisualFields } = require('./shared')

module.exports = {

  // ─── FerriteHelmet ────────────────────────────────────────────────────────
  FerriteHelmet: defineEntity({
    tags: ['item'],
    description:
      'Simple open-faced helmet shaped from ferrite plate. ' +
      'Offers reliable head protection against blunt and slashing attacks at early-game cost.',
    goal: 'Entry-level head armour; accessible to any player who reaches Smithing: Novice',
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      condition: { type: 'enum', values: DURABILITY_STATES },
      weight:    { type: 'decimal', description: 'kg', defaultValue: 2.1 },
      rarity:    { type: 'enum', values: RARITIES, defaultValue: 'common' },
      stackable: { type: 'boolean', description: 'Always false for armour pieces', defaultValue: false },
      durability: { type: 'integer', description: 'Remaining durability points before condition degrades', defaultValue: 120 },
      ...equipmentVisualFields({
        slot: 'Head',
        deformationMode: 'RIGID',
        masks: { primary: true, secondary: true, accent: true, metal: true, emission: false, wear: true },
        hideRegions: ['Hair'],
        attachments: { equipped: 'socket_head', stored: 'socket_back' },
        minLodLevel: 3,
        size: [0.34, 0.34, 0.34],
        metalTone: 'ferrite',
        compatibleTags: ['humanoid', 'can_wear_helmet'],
      }),
    },
    relations: {
      ferrite: { name: 'ferrite', kind: 'hasOne', target: 'Ferrite' },
    },
    stateMachine: itemStateMachine(),
    behaviors: {
      degrade: {
        description: 'Condition worsens when struck in combat',
        rules: ['Critical hits degrade armour two condition steps instead of one'],
        auth: { roles: ['maintainer'] },
      },
      repair: {
        description: 'Hammer back to shape at a forge',
        rules: ['Requires one ferrite ingot; Smithing: Novice'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── VeilsteelChestplate ──────────────────────────────────────────────────
  VeilsteelChestplate: defineEntity({
    tags: ['item'],
    description:
      'Full torso armour forged from veilsteel plates over a ferrite under-layer. ' +
      'Exceptional physical protection; its anti-magic properties passively drain spell effects applied to the wearer.',
    goal: 'Signature mid-tier armour for Warriors; counters mage-heavy group compositions',
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      condition: { type: 'enum', values: DURABILITY_STATES },
      weight:    { type: 'decimal', description: 'kg', defaultValue: 9.8 },
      rarity:    { type: 'enum', values: RARITIES, defaultValue: 'uncommon' },
      stackable: { type: 'boolean', description: 'Always false for armour pieces', defaultValue: false },
      durability: { type: 'integer', description: 'Remaining durability points before condition degrades', defaultValue: 250 },
      ...equipmentVisualFields({
        slot: 'Chest',
        deformationMode: 'HYBRID',
        masks: { primary: true, secondary: true, accent: true, metal: true, emission: false, wear: true },
        hideRegions: ['BodyChest', 'BodyShoulders'],
        attachments: { equipped: 'socket_chest', stored: 'socket_back' },
        minLodLevel: 3,
        size: [0.70, 0.55, 0.42],
        metalTone: 'veilsteel',
        compatibleTags: ['humanoid', 'has_hands'],
      }),
    },
    relations: {
      veilsteel: { name: 'veilsteel', kind: 'hasOne', target: 'Veilsteel' },
      ferrite:   { name: 'ferrite',   kind: 'hasOne', target: 'Ferrite' },
    },
    stateMachine: itemStateMachine(),
    behaviors: {
      degrade: {
        description: 'Condition worsens when struck in combat',
        rules: [
          'Void-damage attacks bypass physical resistance and degrade veilsteel at double rate',
          'Standard physical strikes degrade at half the rate of ferrite armour',
        ],
        auth: { roles: ['maintainer'] },
      },
      repair: {
        description: 'Reforge at a master forge',
        rules: [
          'Requires Smithing: Journeyman',
          'Repair costs one veilsteel ingot and one ferrite ingot',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── DuskfiberCloak ───────────────────────────────────────────────────────
  DuskfiberCloak: defineEntity({
    tags: ['item'],
    description:
      'Hooded cloak woven from duskfiber bast. Provides minimal physical protection but grants ' +
      'a passive stealth bonus in low-light conditions and dampens magical signature detection.',
    goal: 'Light armour option for Pathfinders and stealth-focused players; tradeoff: protection for concealment',
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      condition: { type: 'enum', values: DURABILITY_STATES },
      weight:    { type: 'decimal', description: 'kg', defaultValue: 0.6 },
      rarity:    { type: 'enum', values: RARITIES, defaultValue: 'uncommon' },
      stackable: { type: 'boolean', description: 'Always false for armour pieces', defaultValue: false },
      durability: { type: 'integer', description: 'Remaining durability points before condition degrades', defaultValue: 80 },
      ...equipmentVisualFields({
        slot: 'Cape',
        deformationMode: 'SKINNED',
        masks: { primary: true, secondary: false, accent: false, metal: false, emission: false, wear: true },
        hideRegions: [],
        attachments: { equipped: 'socket_cape', stored: 'socket_back' },
        minLodLevel: 2,
        size: [0.70, 0.90, 0.14],
        metalTone: 'none',
        compatibleTags: ['has_back_socket'],
      }),
    },
    relations: {
      duskfiber: { name: 'duskfiber', kind: 'hasOne', target: 'Duskfiber' },
    },
    stateMachine: itemStateMachine(),
    behaviors: {
      degrade: {
        description: 'Condition worsens from physical damage and prolonged exposure to fire or acid',
        rules: ['Fire damage instantly jumps condition from worn to broken'],
        auth: { roles: ['maintainer'] },
      },
      repair: {
        description: 'Re-weave tears at a crafting bench',
        rules: [
          'Requires two duskfiber strands per condition tier restored',
          'Carpentry: Apprentice',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── FerriteShield ────────────────────────────────────────────────────────
  FerriteShield: defineEntity({
    tags: ['item'],
    description:
      'Round shield of ferrite-plated hardwood. Blocks melee and missile strikes ' +
      'at the cost of mobility; the standard off-hand defence for early-game fighters.',
    goal: 'Provide an entry-level off-hand defensive option for shield-wielding characters',
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      condition: { type: 'enum', values: DURABILITY_STATES },
      weight:    { type: 'decimal', description: 'kg', defaultValue: 5.5 },
      rarity:    { type: 'enum', values: RARITIES, defaultValue: 'common' },
      stackable: { type: 'boolean', description: 'Always false for shields', defaultValue: false },
      durability: { type: 'integer', description: 'Remaining durability points before condition degrades', defaultValue: 180 },
      ...equipmentVisualFields({
        slot: 'OffHand',
        deformationMode: 'RIGID',
        masks: { primary: true, secondary: false, accent: true, metal: true, emission: false, wear: true },
        hideRegions: [],
        attachments: { equipped: 'socket_shield', stored: 'socket_back' },
        minLodLevel: 2,
        size: [0.55, 0.75, 0.08],
        metalTone: 'ferrite',
        compatibleTags: ['has_hands', 'can_wield_weapon'],
      }),
    },
    relations: {
      ferrite: { name: 'ferrite', kind: 'hasOne', target: 'Ferrite' },
    },
    stateMachine: itemStateMachine(),
    behaviors: {
      degrade: {
        description: 'Condition worsens as the shield absorbs blows',
        rules: ['Blocking heavy or void attacks degrades the shield at double rate'],
        auth: { roles: ['maintainer'] },
      },
      repair: {
        description: 'Re-plate and re-band the shield at a forge',
        rules: ['Requires one ferrite ingot; Smithing: Novice'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
