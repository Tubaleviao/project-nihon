const { defineEntity } = require('@newel/core')

// Structured runtime recipe data consumed by CraftingSlice (src/crafting/).
// The relations/behaviors on each recipe carry the graph view used by the
// bible/wiki generators and the technology tree; this json field is the single
// source of truth for in-game crafting resolution — inputs (item key + quantity),
// outputs (item key + quantity), and skill guards (skill key + minimum tier).
// Inputs/outputs reference entity keys from GameData.ITEMS or GameData.MATERIALS.
function recipeData(recipe) {
  return {
    type: 'json',
    description:
      'Structured craft recipe: crafting domain, required station, input items with quantities, output items with quantities, and skill guards (skill key + minimum tier).',
    defaultValue: recipe,
  }
}

module.exports = { defineEntity, recipeData }
