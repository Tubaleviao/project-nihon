const { defineEntity, RARITIES, DURABILITY_STATES, consumableStateMachine } = require('./shared')

module.exports = {

  // ─── FieldRations ─────────────────────────────────────────────────────────
  FieldRations: defineEntity({
    tags: ['item'],
    description:
      'Dried grain-and-herb ration pack prepared from temperate grassland crops. ' +
      'Restores a modest amount of stamina and prevents hunger debuff for several in-game hours.',
    goal: 'Basic consumable food; encourages players to invest in agriculture as a supply chain',
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      condition: { type: 'enum', values: DURABILITY_STATES },
      weight:    { type: 'decimal', description: 'kg per unit', defaultValue: 0.3 },
      rarity:    { type: 'enum', values: RARITIES, defaultValue: 'common' },
      stackable: { type: 'boolean', description: 'True; stacks up to 20 per slot', defaultValue: true },
      durability: { type: 'integer', description: 'Freshness; hits 0 when spoiled', defaultValue: 100 },
    },
    relations: {},
    stateMachine: consumableStateMachine(),
    behaviors: {
      degrade: {
        description: 'Food freshness degrades over real time',
        rules: [
          'Stored in a cold-cellar structure: degradation rate halved',
          'When condition reaches broken the ration is spoiled and cannot be consumed',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── AlchemyPotion ────────────────────────────────────────────────────────
  AlchemyPotion: defineEntity({
    tags: ['item'],
    description:
      'Sealed glass flask containing an Alchemist-brewed reagent. ' +
      'The specific effect depends on the recipe; common variants restore health, cure status effects, ' +
      'or temporarily enhance a single attribute.',
    goal: 'Primary consumable output of the Alchemist profession; creates a sustainable crafting economy',
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      condition: { type: 'enum', values: DURABILITY_STATES },
      weight:    { type: 'decimal', description: 'kg per flask', defaultValue: 0.2 },
      rarity:    { type: 'enum', values: RARITIES, defaultValue: 'uncommon' },
      stackable: { type: 'boolean', description: 'True; stacks up to 10 per slot', defaultValue: true },
      durability: { type: 'integer', description: 'Potency; degrades as the potion ages', defaultValue: 100 },
    },
    relations: {},
    stateMachine: consumableStateMachine(),
    behaviors: {
      degrade: {
        description: 'Potency degrades over time; condition worsens across in-game seasons',
        rules: [
          'Potions stored in a cool, dark alchemist workshop degrade at half rate',
          'Broken-condition potions deal a mild poison effect instead of their intended benefit',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
