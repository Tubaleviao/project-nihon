const { defineEntity, recipeData } = require('./shared')

// Phase 268 — every crafting station is made before it is placed. The carpentry bench is lashed by hand from the
// branches and loose stones the newcomer grounds give; every later station is built at an earlier one, as its
// `station` says. The validator (../stations.js) walks this chain from the hand-made bench.

const DOMAINS = ['smithing', 'alchemy', 'arcane', 'carpentry']
const relKey = (item) => 'input' + item

function stationRecipe({ output, domain, station, requiredTier, inputs, skillGuards, description, rule }) {
  return defineEntity({
    tags: ['recipe'],
    description,
    goal: 'A station is an item: crafted, carried and placed from the hotbar (Phase 268)',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      domain: { type: 'enum', values: DOMAINS, description: 'Crafting station required' },
      outputCount:  { type: 'integer', description: 'Number of output items produced per craft' },
      recipe: recipeData({
        domain,
        station,
        requiredTier,
        inputs: inputs.map(([item, quantity]) => ({ item, quantity })),
        outputs: [{ item: output, quantity: 1 }],
        skillGuards: skillGuards.map(([skill, tier]) => ({ skill, tier })),
      }),
    },
    relations: {
      ...Object.fromEntries(inputs.map(([item]) => [relKey(item), { name: relKey(item), kind: 'hasOne', target: item }])),
      output: { name: 'output', kind: 'hasOne', target: output },
    },
    behaviors: {
      craft: {
        description: station ? `Build it at a ${station}` : 'Lash it together anywhere, with no station',
        rules: [
          ...skillGuards.map(([skill, tier]) => `Requires ${skill}: ${tier.charAt(0).toUpperCase() + tier.slice(1)}`),
          station ? `Requires a ${station} structure` : 'Needs no station',
          rule,
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  })
}

module.exports = {
  RecipeCarpentryBench: stationRecipe({
    output: 'CarpentryBench', domain: 'carpentry', station: '', requiredTier: 'novice',
    inputs: [['Branch', 4], ['LooseStone', 2]], skillGuards: [['Carpentry', 'novice']],
    description: 'Lash four branches onto two loose stones into a carpentry bench, by hand.',
    rule: 'Four branches and two loose stones yield one carpentry bench',
  }),
  RecipeForge: stationRecipe({
    output: 'Forge', domain: 'smithing', station: 'carpentry bench', requiredTier: 'novice',
    inputs: [['LooseStone', 8], ['ThornwoodPlank', 2]], skillGuards: [['Smithing', 'novice']],
    description: 'Stack eight loose stones into a hearth and fit a plank bellows at a carpentry bench.',
    rule: 'Eight loose stones and two planks yield one forge',
  }),
  RecipeMasonryBench: stationRecipe({
    output: 'MasonryBench', domain: 'carpentry', station: 'carpentry bench', requiredTier: 'novice',
    inputs: [['ThornwoodPlank', 4], ['LooseStone', 4]], skillGuards: [['Carpentry', 'apprentice']],
    description: 'Set a slab of loose stones on a four-plank frame at a carpentry bench.',
    rule: 'Four planks and four loose stones yield one masonry bench',
  }),
  RecipeAlchemyBench: stationRecipe({
    output: 'AlchemyBench', domain: 'alchemy', station: 'carpentry bench', requiredTier: 'novice',
    inputs: [['ThornwoodPlank', 4], ['AethermiteDust', 2]], skillGuards: [['Alchemy', 'novice']],
    description: 'Build a plank table and line its bowls with aethermite dust at a carpentry bench.',
    rule: 'Four planks and two aethermite dust yield one alchemy bench',
  }),
  RecipeMasterForge: stationRecipe({
    output: 'MasterForge', domain: 'smithing', station: 'forge', requiredTier: 'novice',
    inputs: [['FerriteIngot', 6], ['AshiteBlock', 4]], skillGuards: [['Smithing', 'apprentice']],
    description: 'Clad a cut-stone hearth in six ferrite ingots at a forge.',
    rule: 'Six ferrite ingots and four ashite blocks yield one master forge',
  }),
  RecipeArcaneForge: stationRecipe({
    output: 'ArcaneForge', domain: 'arcane', station: 'forge', requiredTier: 'novice',
    inputs: [['FerriteIngot', 4], ['Aethermite', 4]], skillGuards: [['ArcaneForging', 'novice']],
    description: 'Forge a ferrite hearth that burns aethermite, at a forge.',
    rule: 'Four ferrite ingots and four aethermite yield one arcane forge',
  }),
  RecipeVoidShieldedWorkshop: stationRecipe({
    output: 'VoidShieldedWorkshop', domain: 'arcane', station: 'arcane forge', requiredTier: 'apprentice',
    inputs: [['VeilsteelIngot', 4], ['RefinedVoiditeShard', 2]], skillGuards: [['VoidSmithing', 'apprentice']],
    description: 'Line a veilsteel cabinet with refined voidite at an arcane forge.',
    rule: 'Four veilsteel ingots and two refined voidite shards yield one void-shielded workshop',
  }),
}
