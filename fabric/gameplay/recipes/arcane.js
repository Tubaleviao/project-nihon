const { defineEntity } = require('./shared')

module.exports = {

  // ─── RecipeEnchantedAethermiteShard ───────────────────────────────────────
  RecipeEnchantedAethermiteShard: defineEntity({
    tags: ['recipe'],
    description:
      'Imbue a refined aethermite shard with magical energy at an arcane forge to produce an enchanted catalyst.',
    goal: 'Primary enchanting-catalyst production recipe; gates the enchanting economy',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      domain: { type: 'enum', values: ['smithing', 'alchemy', 'arcane', 'carpentry'], description: 'Crafting station required' },
      outputCount:  { type: 'integer', description: 'Number of output items produced per craft' },
    },
    relations: {
      inputShard: { name: 'inputShard', kind: 'hasOne', target: 'Aethermite' },
      output:     { name: 'output',     kind: 'hasOne', target: 'EnchantedAethermiteShard' },
    },
    behaviors: {
      craft: {
        description: 'Channel magical energy into the shard at an arcane forge',
        rules: [
          'Requires Arcane Forging: Journeyman',
          'Requires a player-built arcane forge',
          'Input must be a refined aethermite shard (form = shard); dust is not accepted',
          'One refined shard yields one enchanted shard',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── RecipeAethermiteBow ──────────────────────────────────────────────────
  RecipeAethermiteBow: defineEntity({
    tags: ['recipe'],
    description:
      'Treat a thornwood bow stave with aethermite and restring with duskfiber to produce an aethermite bow.',
    goal: 'Bridge recipe linking carpentry, arcane forging, and archery progression paths',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      domain: { type: 'enum', values: ['smithing', 'alchemy', 'arcane', 'carpentry'], description: 'Crafting station required' },
      outputCount:  { type: 'integer', description: 'Number of output items produced per craft' },
    },
    relations: {
      inputPlank:    { name: 'inputPlank',    kind: 'hasOne', target: 'ThornwoodPlank' },
      inputAethermite: { name: 'inputAethermite', kind: 'hasOne', target: 'AethermiteDust' },
      inputDuskfiber: { name: 'inputDuskfiber', kind: 'hasOne', target: 'Duskfiber' },
      output:        { name: 'output',        kind: 'hasOne', target: 'AethermiteBow' },
    },
    behaviors: {
      craft: {
        description: 'Treat and assemble the bow at an arcane forge',
        rules: [
          'Requires Carpentry: Apprentice',
          'Requires Arcane Forging: Apprentice',
          'One thornwood plank, one aethermite dust, and one duskfiber strand yield one aethermite bow',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── RecipeLumenfiteOrb ────────────────────────────────────────────────────
  RecipeLumenfiteOrb: defineEntity({
    tags: ['recipe'],
    description:
      'Polish a lumenfite stone into a charged spell-focus orb at an arcane forge.',
    goal: 'Arcanist utility recipe; drives demand for twilight-biome lumenfite stone',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      domain: { type: 'enum', values: ['smithing', 'alchemy', 'arcane', 'carpentry'], description: 'Crafting station required' },
      outputCount:  { type: 'integer', description: 'Number of output items produced per craft' },
    },
    relations: {
      inputLumenfite: { name: 'inputLumenfite', kind: 'hasOne', target: 'Lumenfite' },
      inputShard:     { name: 'inputShard',     kind: 'hasOne', target: 'EnchantedAethermiteShard' },
      output:         { name: 'output',         kind: 'hasOne', target: 'LumenfiteOrb' },
    },
    behaviors: {
      craft: {
        description: 'Polish and charge the lumenfite stone at an arcane forge using an enchanted shard as a catalyst',
        rules: [
          'Requires Enchanting: Journeyman',
          'Requires Arcane Forging: Apprentice',
          'One lumenfite stone and one enchanted aethermite shard yield one lumenfite orb; the shard is consumed',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── RecipeVoidRuneTablet ─────────────────────────────────────────────────
  RecipeVoidRuneTablet: defineEntity({
    tags: ['recipe'],
    description:
      'Etch stabilisation runes into a refined voidite slab at a void-shielded workshop.',
    goal: 'Endgame arcane recipe; gated behind Void Smithing: Expert and VoidTouched profession',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      domain: { type: 'enum', values: ['smithing', 'alchemy', 'arcane', 'carpentry'], description: 'Crafting station required' },
      outputCount:  { type: 'integer', description: 'Number of output items produced per craft' },
    },
    relations: {
      inputVoidite:  { name: 'inputVoidite',  kind: 'hasOne', target: 'Voidite' },
      inputOrb:      { name: 'inputOrb',      kind: 'hasOne', target: 'LumenfiteOrb' },
      output:        { name: 'output',        kind: 'hasOne', target: 'VoidRuneTablet' },
    },
    behaviors: {
      craft: {
        description: 'Etch runes into voidite using a lumenfite orb as a focusing lens',
        rules: [
          'Requires Void Smithing: Expert',
          'Requires the VoidTouched profession',
          'Workshop must be void-shielded',
          'One refined voidite shard and one lumenfite orb yield one void rune tablet; the orb is consumed',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
