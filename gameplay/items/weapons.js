const { defineEntity, RARITIES, DURABILITY_STATES, itemStateMachine } = require('./shared')

module.exports = {

  // ─── FerriteShortSword ────────────────────────────────────────────────────
  FerriteShortSword: defineEntity({
    tags: ['item'],
    description:
      'Standard single-edged blade forged from a refined ferrite ingot. ' +
      'Lightweight and quick; chips against armoured opponents but reliable for unarmoured targets.',
    goal: 'Entry-level sidearm; every new player can craft one with basic smithing knowledge',
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      condition: { type: 'enum', values: DURABILITY_STATES },
      weight:    { type: 'decimal', description: 'kg' },
      rarity:    { type: 'enum', values: RARITIES },
      stackable: { type: 'boolean', description: 'Always false for weapons' },
      durability: { type: 'integer', description: 'Remaining durability points before condition degrades' },
    },
    relations: {
      ferrite: { name: 'ferrite', kind: 'hasOne', target: 'Ferrite' },
    },
    stateMachine: itemStateMachine(),
    behaviors: {
      degrade: {
        description: 'Condition worsens with combat use',
        rules: [
          'Parrying another weapon degrades the blade faster than striking flesh',
          'Striking veilsteel armour degrades the blade at three times normal rate',
        ],
        auth: { roles: ['maintainer'] },
      },
      repair: {
        description: 'Re-edge and temper the blade at a forge',
        rules: ['Requires one ferrite ingot; Smithing: Novice sufficient'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── VeilsteelLongsword ───────────────────────────────────────────────────
  VeilsteelLongsword: defineEntity({
    tags: ['item'],
    description:
      'Two-handed longsword of veilsteel. Heavy and slow but capable of cracking enchanted armour. ' +
      'Its anti-magic properties suppress active enchantments on struck targets for several seconds.',
    goal: 'Mid-tier anti-mage weapon; demands Smithing investment to craft and Swordsmanship to use effectively',
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      condition: { type: 'enum', values: DURABILITY_STATES },
      weight:    { type: 'decimal', description: 'kg' },
      rarity:    { type: 'enum', values: RARITIES },
      stackable: { type: 'boolean', description: 'Always false for weapons' },
      durability: { type: 'integer', description: 'Remaining durability points before condition degrades' },
    },
    relations: {
      veilsteel: { name: 'veilsteel', kind: 'hasOne', target: 'Veilsteel' },
      ashite:    { name: 'ashite',    kind: 'hasOne', target: 'Ashite' },
    },
    stateMachine: itemStateMachine(),
    behaviors: {
      degrade: {
        description: 'Condition worsens with combat use',
        rules: [
          'Veilsteel is highly durable; degrades at half the rate of ferrite weapons',
          'Void-type attacks corrode the blade faster',
        ],
        auth: { roles: ['maintainer'] },
      },
      repair: {
        description: 'Reforge at a master forge',
        rules: [
          'Requires Smithing: Journeyman',
          'Repair costs one veilsteel ingot',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── AethermiteBow ────────────────────────────────────────────────────────
  AethermiteBow: defineEntity({
    tags: ['item'],
    description:
      'Recurve bow with an aethermite-treated thornwood stave and duskfiber string. ' +
      'Arrows fired from this bow carry a faint magical charge; enchanted arrows deal bonus elemental damage.',
    goal: 'Mid-tier ranged weapon bridging physical archery and magical combat',
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      condition: { type: 'enum', values: DURABILITY_STATES },
      weight:    { type: 'decimal', description: 'kg' },
      rarity:    { type: 'enum', values: RARITIES },
      stackable: { type: 'boolean', description: 'Always false for weapons' },
      durability: { type: 'integer', description: 'Remaining durability points before condition degrades' },
    },
    relations: {
      thornwood:  { name: 'thornwood',  kind: 'hasOne', target: 'Thornwood' },
      aethermite: { name: 'aethermite', kind: 'hasOne', target: 'Aethermite' },
      duskfiber:  { name: 'duskfiber',  kind: 'hasOne', target: 'Duskfiber' },
    },
    stateMachine: itemStateMachine(),
    behaviors: {
      degrade: {
        description: 'Condition worsens with use',
        rules: [
          'String (duskfiber) degrades faster than the stave; tracked separately in durability',
          'Firing in rain at damaged condition risks string snap',
        ],
        auth: { roles: ['maintainer'] },
      },
      repair: {
        description: 'Re-treat stave and replace string',
        rules: [
          'String repair: one duskfiber strand; Carpentry: Novice',
          'Full stave repair: one thornwood plank and one aethermite dust; Arcane Forging: Apprentice',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── VoiditeEdge ──────────────────────────────────────────────────────────
  VoiditeEdge: defineEntity({
    tags: ['item'],
    description:
      'Jagged single-edged blade carved from a stabilised voidite shard. ' +
      'The only weapon that deals true void damage — bypasses veilsteel armour entirely. ' +
      'Corrodes rapidly if the wielder has not undergone void exposure.',
    goal: 'Endgame sidearm for VoidTouched players; deliberately inaccessible without deep void progression',
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      condition: { type: 'enum', values: DURABILITY_STATES },
      weight:    { type: 'decimal', description: 'kg' },
      rarity:    { type: 'enum', values: RARITIES },
      stackable: { type: 'boolean', description: 'Always false for weapons' },
      durability: { type: 'integer', description: 'Remaining durability points before condition degrades' },
    },
    relations: {
      voidite: { name: 'voidite', kind: 'hasOne', target: 'Voidite' },
    },
    stateMachine: itemStateMachine(),
    behaviors: {
      degrade: {
        description: 'Condition worsens with use; instability accelerates degradation without void immunity',
        rules: [
          'Without voidBurstSurvivor flag the blade degrades at triple rate',
          'Striking lumenfite surfaces causes a void crack — instant jump to damaged state',
        ],
        auth: { roles: ['maintainer'] },
      },
      repair: {
        description: 'Restabilise at a void-shielded forge',
        rules: [
          'Requires Void Smithing: Expert',
          'Repair costs one refined voidite shard; only the VoidTouched profession can attempt repair',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
