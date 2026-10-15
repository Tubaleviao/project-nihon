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

// Phase 116 / 126 — a chunk's tree budget is stored in its generation record as `t`, 0..GEN_TREE_MAX
// (src/persistence/region_store.gd). The density noise (TreeSlice.DENSITY_NOISE) can thicken a stand to
// (1 + DENSITY_NOISE) times the mean, so the mean is bounded by floor(GEN_TREE_MAX / (1 + DENSITY_NOISE));
// above that the budget would be silently clamped. Refuse it here.
const GEN_TREE_MAX = 64
const DENSITY_NOISE = 0.5
const MAX_TREE_DENSITY = Math.floor(GEN_TREE_MAX / (1 + DENSITY_NOISE))
for (const [key, entity] of Object.entries(biomes)) {
  const density = entity.fields && entity.fields.treeDensity && entity.fields.treeDensity.defaultValue
  if (density !== undefined && !(Number.isInteger(density) && density >= 0 && density <= MAX_TREE_DENSITY)) {
    throw new Error(`Biome ${key}: treeDensity ${density} is outside 0..${MAX_TREE_DENSITY} (floor(RegionStore.GEN_TREE_MAX / (1 + TreeSlice.DENSITY_NOISE)))`)
  }
}

module.exports = biomes
