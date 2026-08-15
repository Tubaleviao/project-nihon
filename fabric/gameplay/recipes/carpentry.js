const { defineEntity } = require('./shared')

module.exports = {

  // ─── RecipeThornwoodPlank ─────────────────────────────────────────────────
  RecipeThornwoodPlank: defineEntity({
    tags: ['recipe'],
    description: 'Mill two thornwood logs into three thornwood planks at a carpentry bench.',
    goal: 'Foundation carpentry recipe; converts raw lumber into the primary wood component',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      domain: { type: 'enum', values: ['smithing', 'alchemy', 'arcane', 'carpentry'], description: 'Crafting station required' },
      outputCount:  { type: 'integer', description: 'Number of output items produced per craft' },
    },
    relations: {
      inputThornwood: { name: 'inputThornwood', kind: 'hasOne', target: 'Thornwood' },
      output:         { name: 'output',         kind: 'hasOne', target: 'ThornwoodPlank' },
    },
    behaviors: {
      craft: {
        description: 'Saw and plane logs into planks at a carpentry bench',
        rules: [
          'Requires Carpentry: Novice',
          'Requires a carpentry bench structure',
          'Two thornwood logs yield three planks',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── RecipeCarpenterAxe ───────────────────────────────────────────────────
  RecipeCarpenterAxe: defineEntity({
    tags: ['recipe'],
    description:
      'Assemble a carpenter axe from one ferrite ingot, one thornwood plank, and one duskfiber strand.',
    goal: 'First real carpentry tool; reward for investing in both smithing and carpentry simultaneously',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      domain: { type: 'enum', values: ['smithing', 'alchemy', 'arcane', 'carpentry'], description: 'Crafting station required' },
      outputCount:  { type: 'integer', description: 'Number of output items produced per craft' },
    },
    relations: {
      inputIngot:    { name: 'inputIngot',    kind: 'hasOne', target: 'FerriteIngot' },
      inputPlank:    { name: 'inputPlank',    kind: 'hasOne', target: 'ThornwoodPlank' },
      inputDuskfiber: { name: 'inputDuskfiber', kind: 'hasOne', target: 'Duskfiber' },
      output:        { name: 'output',        kind: 'hasOne', target: 'CarpenterAxe' },
    },
    behaviors: {
      craft: {
        description: 'Assemble axe head and handle at a carpentry bench with a forge nearby for the head',
        rules: [
          'Requires Carpentry: Apprentice',
          'Requires Smithing: Novice',
          'Requires both a carpentry bench and a functional forge within the same workshop',
          'One ferrite ingot, one thornwood plank, and one duskfiber strand yield one carpenter axe',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── RecipeDuskfiberCloak ─────────────────────────────────────────────────
  RecipeDuskfiberCloak: defineEntity({
    tags: ['recipe'],
    description: 'Weave three duskfiber strands into a duskfiber cloak at a carpentry bench.',
    goal: 'Light armour recipe for stealth builds; drives demand for duskfiber from Twilight Grove',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      domain: { type: 'enum', values: ['smithing', 'alchemy', 'arcane', 'carpentry'], description: 'Crafting station required' },
      outputCount:  { type: 'integer', description: 'Number of output items produced per craft' },
    },
    relations: {
      inputDuskfiber: { name: 'inputDuskfiber', kind: 'hasOne', target: 'Duskfiber' },
      output:         { name: 'output',         kind: 'hasOne', target: 'DuskfiberCloak' },
    },
    behaviors: {
      craft: {
        description: 'Weave duskfiber at a carpentry bench',
        rules: [
          'Requires Carpentry: Apprentice',
          'Three duskfiber strands yield one cloak',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── RecipeAshiteBlock ────────────────────────────────────────────────────
  RecipeAshiteBlock: defineEntity({
    tags: ['recipe'],
    description:
      'Cut and shape raw ashite stone into standard building blocks at a masonry bench.',
    goal: 'Construction component recipe; links volcanic biome exploration to building progression',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      domain: { type: 'enum', values: ['smithing', 'alchemy', 'arcane', 'carpentry'], description: 'Crafting station required' },
      outputCount:  { type: 'integer', description: 'Number of output items produced per craft' },
    },
    relations: {
      inputAshite: { name: 'inputAshite', kind: 'hasOne', target: 'Ashite' },
      output:      { name: 'output',      kind: 'hasOne', target: 'AshiteBlock' },
    },
    behaviors: {
      craft: {
        description: 'Cut and dress raw ashite at a masonry bench',
        rules: [
          'Requires Carpentry: Journeyman',
          'Requires a masonry bench structure',
          'Three raw ashite ore yield two ashite blocks',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
