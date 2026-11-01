const { defineEntity, recipeData } = require('./shared')

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
      recipe: recipeData({
        domain: 'carpentry',
        station: 'carpentry bench',
        inputs: [{ item: 'Thornwood', quantity: 2 }],
        outputs: [{ item: 'ThornwoodPlank', quantity: 3 }],
        skillGuards: [{ skill: 'Carpentry', tier: 'novice' }],
      }),
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

  // ─── RecipeWaystone ───────────────────────────────────────────────────────
  RecipeWaystone: defineEntity({
    tags: ['recipe'],
    description: 'Cut a waystone from four thornwood planks and two ferrite ingots at a carpentry bench.',
    goal: 'Make the fast-travel network something a player builds (Phase 125)',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      domain: { type: 'enum', values: ['smithing', 'alchemy', 'arcane', 'carpentry'], description: 'Crafting station required' },
      outputCount:  { type: 'integer', description: 'Number of output items produced per craft' },
      recipe: recipeData({
        domain: 'carpentry',
        station: 'carpentry bench',
        inputs: [{ item: 'ThornwoodPlank', quantity: 4 }, { item: 'FerriteIngot', quantity: 2 }],
        outputs: [{ item: 'Waystone', quantity: 1 }],
        skillGuards: [{ skill: 'Carpentry', tier: 'apprentice' }],
      }),
    },
    relations: {
      inputPlank:  { name: 'inputPlank',  kind: 'hasOne', target: 'ThornwoodPlank' },
      inputIngot:  { name: 'inputIngot',  kind: 'hasOne', target: 'FerriteIngot' },
      output:      { name: 'output',      kind: 'hasOne', target: 'Waystone' },
    },
    behaviors: {
      craft: {
        description: 'Cut and fit a marker stone at a carpentry bench',
        rules: [
          'Requires Carpentry: Apprentice',
          'Requires a carpentry bench structure',
          'Four planks and two ferrite ingots yield one waystone',
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
      recipe: recipeData({
        domain: 'carpentry',
        station: 'carpentry bench',
        inputs: [{ item: 'FerriteIngot', quantity: 1 }, { item: 'ThornwoodPlank', quantity: 1 }, { item: 'Duskfiber', quantity: 1 }],
        outputs: [{ item: 'CarpenterAxe', quantity: 1 }],
        skillGuards: [{ skill: 'Carpentry', tier: 'apprentice' }, { skill: 'Smithing', tier: 'novice' }],
      }),
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
      recipe: recipeData({
        domain: 'carpentry',
        station: 'carpentry bench',
        inputs: [{ item: 'Duskfiber', quantity: 3 }],
        outputs: [{ item: 'DuskfiberCloak', quantity: 1 }],
        skillGuards: [{ skill: 'Carpentry', tier: 'apprentice' }],
      }),
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

  // ─── RecipeNoviceTunic ────────────────────────────────────────────────────
  // Phase 207 — the first `tailoring` (sewing) recipe: sewing grows Tailoring (WorkSkills.craft.tailoring).
  RecipeNoviceTunic: defineEntity({
    tags: ['recipe'],
    description: 'Sew two duskfiber strands into a plain tunic at a carpentry bench.',
    goal: 'The first sewing recipe, so sewing makes a better sewer (SkillsGrowFromWork, Phase 207)',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      domain: { type: 'enum', values: ['smithing', 'alchemy', 'arcane', 'carpentry', 'tailoring'], description: 'Crafting station required' },
      outputCount:  { type: 'integer', description: 'Number of output items produced per craft' },
      recipe: recipeData({
        domain: 'tailoring',
        station: 'carpentry bench',
        inputs: [{ item: 'Duskfiber', quantity: 2 }],
        outputs: [{ item: 'NoviceTunic', quantity: 1 }],
        skillGuards: [{ skill: 'Tailoring', tier: 'novice' }],
      }),
    },
    relations: {
      inputDuskfiber: { name: 'inputDuskfiber', kind: 'hasOne', target: 'Duskfiber' },
      output:         { name: 'output',         kind: 'hasOne', target: 'NoviceTunic' },
    },
    behaviors: {
      craft: {
        description: 'Sew duskfiber into a tunic at a carpentry bench',
        rules: [
          'Requires Tailoring: Novice',
          'Two duskfiber strands yield one tunic',
          'Grows the sewer\'s own Tailoring skill',
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
      recipe: recipeData({
        domain: 'carpentry',
        station: 'masonry bench',
        inputs: [{ item: 'Ashite', quantity: 3 }],
        outputs: [{ item: 'AshiteBlock', quantity: 2 }],
        skillGuards: [{ skill: 'Carpentry', tier: 'journeyman' }],
      }),
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

  // ─── RecipeBed ────────────────────────────────────────────────────────────
  // Phase 184 — no station, so a bed is reachable in the first hour: planks come from the first
  // carpentry bench, and Basic Carpentry has no prerequisite and no research-point cost.
  RecipeBed: defineEntity({
    tags: ['recipe'],
    description: 'Lash six thornwood planks into a bed frame with a straw pallet, by hand.',
    goal: 'A first-hour spawn point: the bed a new player places in their first shelter (Phase 184)',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      domain: { type: 'enum', values: ['smithing', 'alchemy', 'arcane', 'carpentry'], description: 'Crafting station required' },
      outputCount:  { type: 'integer', description: 'Number of output items produced per craft' },
      recipe: recipeData({
        domain: 'carpentry',
        station: '',
        inputs: [{ item: 'ThornwoodPlank', quantity: 6 }],
        outputs: [{ item: 'Bed', quantity: 1 }],
        skillGuards: [{ skill: 'Carpentry', tier: 'novice' }],
      }),
    },
    relations: {
      inputPlank: { name: 'inputPlank', kind: 'hasOne', target: 'ThornwoodPlank' },
      output:     { name: 'output',     kind: 'hasOne', target: 'Bed' },
    },
    behaviors: {
      craft: {
        description: 'Lash planks into a bed anywhere, with no station',
        rules: [
          'Requires Carpentry: Novice',
          'Needs no station',
          'Six planks yield one bed',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
