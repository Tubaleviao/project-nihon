const { defineEntity, RARITIES, itemStateMachine } = require('./shared')

module.exports = {

  // ─── EnchantedAethermiteShard ─────────────────────────────────────────────
  EnchantedAethermiteShard: defineEntity({
    tags: ['item'],
    description:
      'A refined aethermite shard that has been fully imbued at an arcane forge. ' +
      'Emits a faint silver glow; consumed as a single-use catalyst when enchanting metals or imbuing equipment.',
    goal: 'Primary enchanting catalyst; creates scarcity that balances the enchanting economy',
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      condition: { type: 'enum', values: ['pristine', 'worn', 'damaged', 'broken'] },
      weight:    { type: 'decimal', description: 'kg per shard' },
      rarity:    { type: 'enum', values: RARITIES },
      stackable: { type: 'boolean', description: 'True; stacks up to 10 per slot' },
      durability: { type: 'integer', description: 'Charge level; 0 means the shard is spent' },
    },
    relations: {
      aethermite: { name: 'aethermite', kind: 'hasOne', target: 'Aethermite' },
    },
    stateMachine: itemStateMachine(),
    behaviors: {
      degrade: {
        description: 'Charge dissipates slowly when not stored in a magical container',
        rules: ['Exposed to sunlight: charge degrades one tier per in-game day'],
        auth: { roles: ['maintainer'] },
      },
      repair: {
        description: 'A fully discharged shard can be recharged at an arcane forge',
        rules: [
          'Requires Arcane Forging: Journeyman',
          'Recharging costs one aethermite dust and restores condition to pristine',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── VoidRuneTablet ───────────────────────────────────────────────────────
  VoidRuneTablet: defineEntity({
    tags: ['item'],
    description:
      'Flat voidite slab etched with stabilisation runes by a Void Smithing expert. ' +
      'Grants the holder controlled access to void-magic casting in a limited area. ' +
      'Extremely rare; each tablet is unique to its etching session.',
    goal: 'Endgame magical item tying void material progression to knowledge-based unlocks',
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      condition: { type: 'enum', values: ['pristine', 'worn', 'damaged', 'broken'] },
      weight:    { type: 'decimal', description: 'kg per tablet' },
      rarity:    { type: 'enum', values: RARITIES },
      stackable: { type: 'boolean', description: 'False; each tablet is unique' },
      durability: { type: 'integer', description: 'Rune integrity; corrupts under anti-magic fields' },
    },
    relations: {
      voidite: { name: 'voidite', kind: 'hasOne', target: 'Voidite' },
    },
    stateMachine: itemStateMachine(),
    behaviors: {
      degrade: {
        description: 'Rune integrity degrades when the tablet enters an anti-magic field or veilsteel zone',
        rules: [
          'Each second inside a veilsteel-armoured structure degrades the tablet by one durability point',
          'Condition broken means all runes are erased; the tablet reverts to an inert voidite slab',
        ],
        auth: { roles: ['maintainer'] },
      },
      repair: {
        description: 'Re-etch damaged runes at a void-shielded workshop',
        rules: [
          'Requires Void Smithing: Expert',
          'The VoidTouched profession is required to re-etch; runes cannot be restored by other professions',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── LumenfiteOrb ─────────────────────────────────────────────────────────
  LumenfiteOrb: defineEntity({
    tags: ['item'],
    description:
      'A polished lumenfite sphere charged with stored magical energy by an Arcanist. ' +
      'Serves as a portable light source, a spell-focus amplifier, and a key reagent in ' +
      'high-tier enchanting recipes.',
    goal: 'Versatile magical utility item for Arcanists; drives demand for twilight-biome lumenfite',
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      condition: { type: 'enum', values: ['pristine', 'worn', 'damaged', 'broken'] },
      weight:    { type: 'decimal', description: 'kg per orb' },
      rarity:    { type: 'enum', values: RARITIES },
      stackable: { type: 'boolean', description: 'True; stacks up to 5 per slot' },
      durability: { type: 'integer', description: 'Charge; depletes with use' },
    },
    relations: {
      lumenfite: { name: 'lumenfite', kind: 'hasOne', target: 'Lumenfite' },
    },
    stateMachine: itemStateMachine(),
    behaviors: {
      degrade: {
        description: 'Charge depletes with each spell amplification use',
        rules: [
          'As a light source the charge depletes at a negligible rate',
          'As a spell-focus amplifier each use costs 5 durability points',
        ],
        auth: { roles: ['maintainer'] },
      },
      repair: {
        description: 'Recharge at an arcane forge',
        rules: [
          'Requires Enchanting: Apprentice',
          'Recharging costs one aethermite dust; restores 50 durability points',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
