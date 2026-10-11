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

module.exports = biomes
