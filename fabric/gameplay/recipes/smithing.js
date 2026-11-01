const { defineEntity, recipeData } = require('./shared')

module.exports = {

  // ─── RecipeFerriteIngot ───────────────────────────────────────────────────
  RecipeFerriteIngot: defineEntity({
    tags: ['recipe'],
    description: 'Smelt two raw ferrite ore into one refined ferrite ingot at a forge.',
    goal: 'Foundation smithing recipe; teaches the core smelt loop to new players',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      domain: { type: 'enum', values: ['smithing', 'alchemy', 'arcane', 'carpentry'], description: 'Crafting station required' },
      outputCount:  { type: 'integer', description: 'Number of output items produced per craft' },
      recipe: recipeData({
        domain: 'smithing',
        station: 'forge',
        inputs: [{ item: 'Ferrite', quantity: 2 }],
        outputs: [{ item: 'FerriteIngot', quantity: 1 }],
        skillGuards: [{ skill: 'Smithing', tier: 'novice' }],
      }),
    },
    relations: {
      inputFerrite: { name: 'inputFerrite', kind: 'hasOne', target: 'Ferrite' },
      output:       { name: 'output',       kind: 'hasOne', target: 'FerriteIngot' },
    },
    behaviors: {
      craft: {
        description: 'Execute the recipe at a forge to produce ferrite ingots',
        rules: [
          'Requires Smithing: Novice',
          'Requires a functional forge structure',
          'Two raw ferrite ore yield one refined ingot',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── RecipeVeilsteelIngot ─────────────────────────────────────────────────
  RecipeVeilsteelIngot: defineEntity({
    tags: ['recipe'],
    description: 'Alloy three ferrite ingots and one refined aethermite shard into one veilsteel ingot at a master forge.',
    goal: 'Mid-tier alloying recipe; prerequisite step before any veilsteel gear can be crafted',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      domain: { type: 'enum', values: ['smithing', 'alchemy', 'arcane', 'carpentry'], description: 'Crafting station required' },
      outputCount:  { type: 'integer', description: 'Number of output items produced per craft' },
      recipe: recipeData({
        domain: 'smithing',
        station: 'master forge',
        inputs: [{ item: 'FerriteIngot', quantity: 3 }, { item: 'AethermiteShard', quantity: 1 }],
        outputs: [{ item: 'VeilsteelIngot', quantity: 1 }],
        skillGuards: [{ skill: 'Smithing', tier: 'journeyman' }],
      }),
    },
    relations: {
      inputFerrite:    { name: 'inputFerrite',    kind: 'hasOne', target: 'FerriteIngot' },
      inputAethermite: { name: 'inputAethermite', kind: 'hasOne', target: 'AethermiteShard' },
      output:          { name: 'output',          kind: 'hasOne', target: 'VeilsteelIngot' },
    },
    behaviors: {
      craft: {
        description: 'Execute the alloying recipe at a master forge to produce veilsteel ingots',
        rules: [
          'Requires Smithing: Journeyman',
          'Requires a master forge (ashite-lined)',
          'Three ferrite ingots and one refined aethermite shard (form = shard; dust is not accepted) yield one veilsteel ingot — the shard is consumed as a crafting ingredient, not a catalyst; Aethermite.consume is not invoked',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── RecipeFerriteShortSword ──────────────────────────────────────────────
  RecipeFerriteShortSword: defineEntity({
    tags: ['recipe'],
    description: 'Forge a ferrite short sword from one refined ferrite ingot.',
    goal: 'Entry weapon recipe; first meaningful combat item a player can self-produce',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      domain: { type: 'enum', values: ['smithing', 'alchemy', 'arcane', 'carpentry'], description: 'Crafting station required' },
      outputCount:  { type: 'integer', description: 'Number of output items produced per craft' },
      recipe: recipeData({
        domain: 'smithing',
        station: 'forge',
        inputs: [{ item: 'FerriteIngot', quantity: 1 }],
        outputs: [{ item: 'FerriteShortSword', quantity: 1 }],
        skillGuards: [{ skill: 'Smithing', tier: 'novice' }],
      }),
    },
    relations: {
      inputIngot: { name: 'inputIngot', kind: 'hasOne', target: 'FerriteIngot' },
      output:     { name: 'output',     kind: 'hasOne', target: 'FerriteShortSword' },
    },
    behaviors: {
      craft: {
        description: 'Smith the blade at a forge',
        rules: [
          'Requires Smithing: Novice',
          'Requires a functional forge',
          'One ferrite ingot yields one short sword',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── RecipeFerritePick ────────────────────────────────────────────────────
  RecipeFerritePick: defineEntity({
    tags: ['recipe'],
    description: 'Craft a ferrite mining pick from two ferrite ingots and one thornwood plank.',
    goal: 'First mining tool recipe; pushes early players toward both smithing and carpentry',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      domain: { type: 'enum', values: ['smithing', 'alchemy', 'arcane', 'carpentry'], description: 'Crafting station required' },
      outputCount:  { type: 'integer', description: 'Number of output items produced per craft' },
      recipe: recipeData({
        domain: 'smithing',
        station: 'forge',
        inputs: [{ item: 'FerriteIngot', quantity: 2 }, { item: 'ThornwoodPlank', quantity: 1 }],
        outputs: [{ item: 'FerritePick', quantity: 1 }],
        skillGuards: [{ skill: 'Smithing', tier: 'novice' }],
      }),
    },
    relations: {
      inputIngot:  { name: 'inputIngot',  kind: 'hasOne', target: 'FerriteIngot' },
      inputPlank:  { name: 'inputPlank',  kind: 'hasOne', target: 'ThornwoodPlank' },
      output:      { name: 'output',      kind: 'hasOne', target: 'FerritePick' },
    },
    behaviors: {
      craft: {
        description: 'Assemble pick head and handle at a forge',
        rules: [
          'Requires Smithing: Novice',
          'Requires a functional forge',
          'Two ferrite ingots and one thornwood plank yield one pick',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── RecipeVeilsteelLongsword ─────────────────────────────────────────────
  RecipeVeilsteelLongsword: defineEntity({
    tags: ['recipe'],
    description:
      'Forge a veilsteel longsword from two veilsteel ingots and one ashite block at a master forge.',
    goal: 'Mid-tier weapon recipe gated behind Smithing: Journeyman and master forge construction',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      domain: { type: 'enum', values: ['smithing', 'alchemy', 'arcane', 'carpentry'], description: 'Crafting station required' },
      outputCount:  { type: 'integer', description: 'Number of output items produced per craft' },
      recipe: recipeData({
        domain: 'smithing',
        station: 'master forge',
        inputs: [{ item: 'VeilsteelIngot', quantity: 2 }, { item: 'AshiteBlock', quantity: 1 }],
        outputs: [{ item: 'VeilsteelLongsword', quantity: 1 }],
        skillGuards: [{ skill: 'Smithing', tier: 'journeyman' }],
      }),
    },
    relations: {
      inputVeilsteel: { name: 'inputVeilsteel', kind: 'hasOne', target: 'VeilsteelIngot' },
      inputAshite:    { name: 'inputAshite',    kind: 'hasOne', target: 'AshiteBlock' },
      output:         { name: 'output',         kind: 'hasOne', target: 'VeilsteelLongsword' },
    },
    behaviors: {
      craft: {
        description: 'Forge the longsword at a master forge using veilsteel and ashite quench block',
        rules: [
          'Requires Smithing: Journeyman',
          'Requires a master forge (ashite-lined); standard forges cannot reach required temperature',
          'Two veilsteel ingots and one ashite block yield one longsword',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── RecipeVeilsteelChestplate ────────────────────────────────────────────
  RecipeVeilsteelChestplate: defineEntity({
    tags: ['recipe'],
    description:
      'Forge a veilsteel chestplate from four veilsteel ingots and two ferrite ingots.',
    goal: 'Signature mid-tier armour recipe for Warriors; demands sustained smithing investment',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      domain: { type: 'enum', values: ['smithing', 'alchemy', 'arcane', 'carpentry'], description: 'Crafting station required' },
      outputCount:  { type: 'integer', description: 'Number of output items produced per craft' },
      recipe: recipeData({
        domain: 'smithing',
        station: 'master forge',
        inputs: [{ item: 'VeilsteelIngot', quantity: 4 }, { item: 'FerriteIngot', quantity: 2 }],
        outputs: [{ item: 'VeilsteelChestplate', quantity: 1 }],
        skillGuards: [{ skill: 'Smithing', tier: 'journeyman' }],
      }),
    },
    relations: {
      inputVeilsteel: { name: 'inputVeilsteel', kind: 'hasOne', target: 'VeilsteelIngot' },
      inputFerrite:   { name: 'inputFerrite',   kind: 'hasOne', target: 'FerriteIngot' },
      output:         { name: 'output',         kind: 'hasOne', target: 'VeilsteelChestplate' },
    },
    behaviors: {
      craft: {
        description: 'Beat and shape veilsteel plates at a master forge over a ferrite frame',
        rules: [
          'Requires Smithing: Journeyman',
          'Requires a master forge',
          'Four veilsteel ingots and two ferrite ingots yield one chestplate',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),


  // ─── RecipeRefinedVoiditeShard ────────────────────────────────────────────
  RecipeRefinedVoiditeShard: defineEntity({
    tags: ['recipe'],
    description:
      'Stabilise one raw voidite crystal into a refined voidite shard at a forge. The refining can fail with a void burst.',
    goal: 'Entry point of the void progression chain; surviving a burst grants the voidBurstSurvivor flag',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      domain: { type: 'enum', values: ['smithing', 'alchemy', 'arcane', 'carpentry'], description: 'Crafting station required' },
      outputCount:  { type: 'integer', description: 'Number of output items produced per craft' },
      recipe: recipeData({
        domain: 'smithing',
        station: 'forge',
        inputs: [{ item: 'Voidite', quantity: 1 }],
        outputs: [{ item: 'RefinedVoiditeShard', quantity: 1 }],
        skillGuards: [{ skill: 'Smithing', tier: 'journeyman' }],
        burst: { chance: 0.15, damage: 40, grantsFlag: 'voidBurstSurvivor' },
      }),
    },
    relations: {
      inputVoidite: { name: 'inputVoidite', kind: 'hasOne', target: 'Voidite' },
      output:       { name: 'output',       kind: 'hasOne', target: 'RefinedVoiditeShard' },
    },
    behaviors: {
      craft: {
        description: 'Stabilise raw voidite through void-tuned smelting in a forge',
        rules: [
          'Requires Smithing: Journeyman',
          'Requires a player-built forge',
          'One raw voidite crystal yields one refined shard',
          'Each attempt may end in a void burst: the input is consumed, no shard is produced and the crafter takes burst damage; a crafter who survives gains the voidBurstSurvivor flag',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── RecipeSkinningKnife ──────────────────────────────────────────
  RecipeSkinningKnife: defineEntity({
    tags: ['recipe'],
    description: 'Craft a skinning knife from one ferrite ingot and one thornwood plank.',
    goal: 'First harvest tool recipe; every hunter can make one early',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      domain: { type: 'enum', values: ['smithing', 'alchemy', 'arcane', 'carpentry'], description: 'Crafting station required' },
      outputCount:  { type: 'integer', description: 'Number of output items produced per craft' },
      recipe: recipeData({
        domain: 'smithing',
        station: 'forge',
        inputs: [{ item: 'FerriteIngot', quantity: 1 }, { item: 'ThornwoodPlank', quantity: 1 }],
        outputs: [{ item: 'SkinningKnife', quantity: 1 }],
        skillGuards: [{ skill: 'Smithing', tier: 'novice' }],
      }),
    },
    relations: {
      inputFerriteIngot: { name: 'inputFerriteIngot', kind: 'hasOne', target: 'FerriteIngot' },
      inputThornwoodPlank: { name: 'inputThornwoodPlank', kind: 'hasOne', target: 'ThornwoodPlank' },
      output: { name: 'output', kind: 'hasOne', target: 'SkinningKnife' },
    },
    behaviors: {
      craft: {
        description: 'Forge the blade and fit the grip',
        rules: ['Requires Smithing: Novice', 'Requires a functional forge'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── RecipeBoneSaw ────────────────────────────────────────────────
  RecipeBoneSaw: defineEntity({
    tags: ['recipe'],
    description: 'Craft a bone saw from two ferrite ingots and one thornwood plank.',
    goal: 'Second harvest tool recipe; bones cost more metal than a knife',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      domain: { type: 'enum', values: ['smithing', 'alchemy', 'arcane', 'carpentry'], description: 'Crafting station required' },
      outputCount:  { type: 'integer', description: 'Number of output items produced per craft' },
      recipe: recipeData({
        domain: 'smithing',
        station: 'forge',
        inputs: [{ item: 'FerriteIngot', quantity: 2 }, { item: 'ThornwoodPlank', quantity: 1 }],
        outputs: [{ item: 'BoneSaw', quantity: 1 }],
        skillGuards: [{ skill: 'Smithing', tier: 'novice' }],
      }),
    },
    relations: {
      inputFerriteIngot: { name: 'inputFerriteIngot', kind: 'hasOne', target: 'FerriteIngot' },
      inputThornwoodPlank: { name: 'inputThornwoodPlank', kind: 'hasOne', target: 'ThornwoodPlank' },
      output: { name: 'output', kind: 'hasOne', target: 'BoneSaw' },
    },
    behaviors: {
      craft: {
        description: 'Forge the blade and fit the grip',
        rules: ['Requires Smithing: Novice', 'Requires a functional forge'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── RecipeLockpick ───────────────────────────────────────────────────────────
  // Phase 208 — the lockpicking tool, from the first forge
  RecipeLockpick: defineEntity({
    tags: ['recipe'],
    description: 'Draw a ferrite ingot into a lockpick on a thornwood grip.',
    goal: 'the lockpicking tool, from the first forge',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      domain: { type: 'enum', values: ['smithing', 'alchemy', 'arcane', 'carpentry'], description: 'Crafting station required' },
      outputCount:  { type: 'integer', description: 'Number of output items produced per craft' },
      recipe: recipeData({
        domain: 'smithing',
        station: 'forge',
        inputs: [{ item: 'FerriteIngot', quantity: 1 }, { item: 'ThornwoodPlank', quantity: 1 }],
        outputs: [{ item: 'Lockpick', quantity: 1 }],
        skillGuards: [{ skill: 'Smithing', tier: 'novice' }],
      }),
    },
    relations: {
      inputFerriteIngot: { name: 'inputFerriteIngot', kind: 'hasOne', target: 'FerriteIngot' },
      inputThornwoodPlank: { name: 'inputThornwoodPlank', kind: 'hasOne', target: 'ThornwoodPlank' },
      output: { name: 'output', kind: 'hasOne', target: 'Lockpick' },
    },
    behaviors: {
      craft: {
        description: 'Draw the pin and fit the grip',
        rules: ['Requires Smithing: Novice', 'Requires a functional forge'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),
}
