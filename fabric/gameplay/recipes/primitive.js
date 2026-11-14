const { defineEntity, recipeData } = require('./shared')

// Phase 260 — stone tools are lashed by hand: no station, a novice guard, a branch and a stone or two.
// The validator (../stone_tools.js) finds them by their outputs: every stone tool has one, and no other tool skips the bench.

function stoneRecipe({ output, branches, stones, description, rule }) {
  return defineEntity({
    tags: ['recipe'],
    description,
    goal: 'A first-hour tool with no station and no research cost (Phase 260)',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      domain: { type: 'enum', values: ['smithing', 'alchemy', 'arcane', 'carpentry'], description: 'Crafting station required' },
      outputCount:  { type: 'integer', description: 'Number of output items produced per craft' },
      recipe: recipeData({
        domain: 'carpentry',
        station: '',
        inputs: [{ item: 'Branch', quantity: branches }, { item: 'LooseStone', quantity: stones }],
        outputs: [{ item: output, quantity: 1 }],
        skillGuards: [{ skill: 'Carpentry', tier: 'novice' }],
      }),
    },
    relations: {
      inputBranch: { name: 'inputBranch', kind: 'hasOne', target: 'Branch' },
      inputStone:  { name: 'inputStone',  kind: 'hasOne', target: 'LooseStone' },
      output:      { name: 'output',      kind: 'hasOne', target: output },
    },
    behaviors: {
      craft: {
        description: 'Lash a stone to a branch anywhere, with no station',
        rules: ['Requires Carpentry: Novice', 'Needs no station', rule],
        auth: { roles: ['maintainer'] },
      },
    },
  })
}

module.exports = {
  RecipeStoneAxe: stoneRecipe({
    output: 'StoneAxe', branches: 1, stones: 1,
    description: 'Lash a knapped stone into a split branch: a stone axe.',
    rule: 'One branch and one stone yield one stone axe',
  }),
  RecipeStonePick: stoneRecipe({
    output: 'StonePick', branches: 1, stones: 2,
    description: 'Bind a pointed stone across a branch: a stone pick.',
    rule: 'One branch and two stones yield one stone pick',
  }),
  RecipeStoneShovel: stoneRecipe({
    output: 'StoneShovel', branches: 2, stones: 1,
    description: 'Tie a flat stone to a long branch: a stone shovel.',
    rule: 'Two branches and one stone yield one stone shovel',
  }),
  RecipeStoneHammer: stoneRecipe({
    output: 'StoneHammer', branches: 1, stones: 1,
    description: 'Bind a heavy round stone to a short branch: a stone hammer.',
    rule: 'One branch and one stone yield one stone hammer',
  }),
  RecipeStoneKnife: stoneRecipe({
    output: 'StoneKnife', branches: 1, stones: 1,
    description: 'Set a sharp stone flake in a branch grip: a stone knife.',
    rule: 'One branch and one stone yield one stone knife',
  }),
}
