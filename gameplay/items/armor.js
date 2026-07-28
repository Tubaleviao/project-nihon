const { defineEntity, RARITIES, itemStateMachine } = require('./shared')

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
      condition: { type: 'enum', values: ['pristine', 'worn', 'damaged', 'broken'] },
      weight:    { type: 'decimal', description: 'kg' },
      rarity:    { type: 'enum', values: RARITIES },
      stackable: { type: 'boolean', description: 'Always false for armour pieces' },
      durability: { type: 'integer', description: 'Remaining durability points before condition degrades' },
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
      condition: { type: 'enum', values: ['pristine', 'worn', 'damaged', 'broken'] },
      weight:    { type: 'decimal', description: 'kg' },
      rarity:    { type: 'enum', values: RARITIES },
      stackable: { type: 'boolean', description: 'Always false for armour pieces' },
      durability: { type: 'integer', description: 'Remaining durability points before condition degrades' },
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
      condition: { type: 'enum', values: ['pristine', 'worn', 'damaged', 'broken'] },
      weight:    { type: 'decimal', description: 'kg' },
      rarity:    { type: 'enum', values: RARITIES },
      stackable: { type: 'boolean', description: 'Always false for armour pieces' },
      durability: { type: 'integer', description: 'Remaining durability points before condition degrades' },
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

}
