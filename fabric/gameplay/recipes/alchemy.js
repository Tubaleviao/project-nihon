const { defineEntity } = require('./shared')

module.exports = {

  // ─── RecipeHealthPotion ───────────────────────────────────────────────────
  RecipeHealthPotion: defineEntity({
    tags: ['recipe'],
    description:
      'Brew a health-restoring potion from aethermite dust and harvested herbs at an alchemy bench.',
    goal: 'Entry alchemy recipe; establishes the potion supply chain for combat groups',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      domain: { type: 'enum', values: ['smithing', 'alchemy', 'arcane', 'carpentry'], description: 'Crafting station required' },
      yield:  { type: 'integer', description: 'Number of output items produced per craft' },
    },
    relations: {
      inputDust:   { name: 'inputDust',   kind: 'hasOne', target: 'AethermiteDust' },
      output:      { name: 'output',      kind: 'hasOne', target: 'AlchemyPotion' },
    },
    behaviors: {
      craft: {
        description: 'Brew at an alchemy bench by combining reagents under controlled heat',
        rules: [
          'Requires Alchemy: Novice',
          'Requires an alchemy bench structure',
          'One aethermite dust and herb reagents yield two health potions',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── RecipeStaminaPotion ──────────────────────────────────────────────────
  RecipeStaminaPotion: defineEntity({
    tags: ['recipe'],
    description:
      'Brew a stamina-restoring potion from aethermite dust and root reagents. ' +
      'Used by explorers and miners for extended field operations.',
    goal: 'Utility consumable; drives demand for aethermite dust among non-combat players',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      domain: { type: 'enum', values: ['smithing', 'alchemy', 'arcane', 'carpentry'], description: 'Crafting station required' },
      yield:  { type: 'integer', description: 'Number of output items produced per craft' },
    },
    relations: {
      inputDust: { name: 'inputDust', kind: 'hasOne', target: 'AethermiteDust' },
      output:    { name: 'output',    kind: 'hasOne', target: 'AlchemyPotion' },
    },
    behaviors: {
      craft: {
        description: 'Brew at an alchemy bench',
        rules: [
          'Requires Alchemy: Novice',
          'Requires an alchemy bench',
          'One aethermite dust and root reagents yield one stamina potion',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── RecipeVoidResistPotion ───────────────────────────────────────────────
  RecipeVoidResistPotion: defineEntity({
    tags: ['recipe'],
    description:
      'Brew a void-resist potion from refined voidite shard dust and aethermite dust. ' +
      'Temporarily suppresses void-damage intake; required for extended void-rift operations.',
    goal: 'High-tier utility consumable; makes void zones survivable without VoidTouched profession',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      domain: { type: 'enum', values: ['smithing', 'alchemy', 'arcane', 'carpentry'], description: 'Crafting station required' },
      yield:  { type: 'integer', description: 'Number of output items produced per craft' },
    },
    relations: {
      inputVoidite:   { name: 'inputVoidite',   kind: 'hasOne', target: 'Voidite' },
      inputAethermite: { name: 'inputAethermite', kind: 'hasOne', target: 'AethermiteDust' },
      output:          { name: 'output',          kind: 'hasOne', target: 'AlchemyPotion' },
    },
    behaviors: {
      craft: {
        description: 'Brew at an alchemy bench in a void-shielded room',
        rules: [
          'Requires Alchemy: Expert',
          'Requires Arcane Forging: Journeyman',
          'Brewing room must be void-shielded; failure without shielding causes void burst',
          'One refined voidite shard and two aethermite dust yield one void-resist potion',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
