const { defineEntity } = require('./shared')

module.exports = {

  // ─── RecipeFerriteIngot ───────────────────────────────────────────────────
  RecipeFerriteIngot: defineEntity({
    tags: ['recipe'],
    description: 'Smelt two raw ferrite ore into one refined ferrite ingot at a forge.',
    goal: 'Foundation smithing recipe; teaches the core smelt loop to new players',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      domain: { type: 'enum', values: ['smithing', 'alchemy', 'arcane', 'carpentry'], description: 'Crafting station required' },
      yield:  { type: 'integer', description: 'Number of output items produced per craft' },
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
      yield:  { type: 'integer', description: 'Number of output items produced per craft' },
    },
    relations: {
      inputFerrite:    { name: 'inputFerrite',    kind: 'hasOne', target: 'FerriteIngot' },
      inputAethermite: { name: 'inputAethermite', kind: 'hasOne', target: 'Aethermite' },
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
      yield:  { type: 'integer', description: 'Number of output items produced per craft' },
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
      yield:  { type: 'integer', description: 'Number of output items produced per craft' },
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
      yield:  { type: 'integer', description: 'Number of output items produced per craft' },
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
      yield:  { type: 'integer', description: 'Number of output items produced per craft' },
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

}
