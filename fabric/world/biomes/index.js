const { safeMerge } = require('../../shared')
const { ADJACENCY, validateAdjacency } = require('./adjacency')
const temperate = require('./temperate')
const volcanic  = require('./volcanic')
const twilight  = require('./twilight')
const voidrift  = require('./voidrift')
const earth     = require('./earth')

const biomes = safeMerge('biome', temperate, volcanic, twilight, voidrift, earth)

// Phase 112 — the adjacency table must name only real biomes, be symmetric and carry a transition.
// Throwing here makes `npm run validate` (which loads the fabric) fail.
validateAdjacency(ADJACENCY, Object.keys(biomes))

// Phase 116 — a chunk's tree budget is stored in its generation record as `t`, 0..GEN_TREE_MAX
// (src/persistence/region_store.gd), so a density above that would be silently clamped. Refuse it here.
const GEN_TREE_MAX = 64
for (const [key, entity] of Object.entries(biomes)) {
  const density = entity.fields && entity.fields.treeDensity && entity.fields.treeDensity.defaultValue
  if (density !== undefined && !(Number.isInteger(density) && density >= 0 && density <= GEN_TREE_MAX)) {
    throw new Error(`Biome ${key}: treeDensity ${density} is outside 0..${GEN_TREE_MAX} (RegionStore.GEN_TREE_MAX)`)
  }
}

module.exports = biomes
