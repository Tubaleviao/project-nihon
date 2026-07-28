const { defineEntity, RARITIES, itemStateMachine } = require('./shared')

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
      condition: { type: 'enum', values: ['pristine', 'worn', 'damaged', 'broken'] },
      weight:    { type: 'decimal', description: 'kg per unit' },
      rarity:    { type: 'enum', values: RARITIES },
      stackable: { type: 'boolean', description: 'True; stacks up to 20 per slot' },
      durability: { type: 'integer', description: 'Freshness; hits 0 when spoiled' },
    },
    relations: {},
    stateMachine: itemStateMachine(),
    behaviors: {
      degrade: {
        description: 'Food freshness degrades over real time',
        rules: [
          'Stored in a cold-cellar structure: degradation rate halved',
          'When condition reaches broken the ration is spoiled and cannot be consumed',
        ],
        auth: { roles: ['maintainer'] },
      },
      repair: {
        description: 'Spoiled rations cannot be repaired; they must be discarded',
        rules: ['repair trigger is not applicable to food items — condition: broken is terminal for consumables'],
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
      condition: { type: 'enum', values: ['pristine', 'worn', 'damaged', 'broken'] },
      weight:    { type: 'decimal', description: 'kg per flask' },
      rarity:    { type: 'enum', values: RARITIES },
      stackable: { type: 'boolean', description: 'True; stacks up to 10 per slot' },
      durability: { type: 'integer', description: 'Potency; degrades as the potion ages' },
    },
    relations: {},
    stateMachine: itemStateMachine(),
    behaviors: {
      degrade: {
        description: 'Potency degrades over time; condition worsens across in-game seasons',
        rules: [
          'Potions stored in a cool, dark alchemist workshop degrade at half rate',
          'Broken-condition potions deal a mild poison effect instead of their intended benefit',
        ],
        auth: { roles: ['maintainer'] },
      },
      repair: {
        description: 'Aged potions cannot be restored; brew a fresh batch instead',
        rules: ['repair trigger is not applicable to potions — potency loss is irreversible'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
