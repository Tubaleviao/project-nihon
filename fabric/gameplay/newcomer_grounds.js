const { defineEntity } = require('@newel/core')

// Phase 261 — newcomer grounds: a few large, gentle areas on the open continent where new characters
// start, instead of wherever a random search lands. Their centres are a pure function of the world seed.
// Inside one, only weak creatures spawn (an aggressive one turns back at the edge), loose stones and
// branches lie thick on the ground, and no structure may stand on the centre.

const GROUNDS = {
  count: 4,                                      // grounds on the open continent: players meet, do not crowd
  radiusMetres: 1000,                            // about 1 km
  biomes: ['TemperateForest', 'TemperateGrassland'], // trees, open ground and rock within reach
  allowedCreatures: ['ForestBoar'],              // the only creatures that may spawn inside
  allowedAggression: ['passive', 'neutral'],     // the aggression levels a ground tolerates
  maxCreatureTier: 1,                            // the danger cap (Creature.tier)
  looseDensityInside: 0.35,                      // chance, per 4 m tile inside a ground, of a loose item
  looseDensityOutside: 0.02,                     // the same, anywhere else
  looseRegrowSeconds: 180,                       // a picked item is back after this long
  pickReachMetres: 3,                            // how close a player stands to pick one up
  claimRadiusMetres: 24,                         // no structure within this of a ground's centre
  resourceRadiusMetres: 120,                     // within this of each spawn point: trees, rock, soil, items, creatures
  spawnRadiusMetres: 300,                        // a spawn lies within this of a ground's centre
}

function newcomerGroundsData() {
  return JSON.parse(JSON.stringify(GROUNDS))
}

/** The fabric's creatures and biomes in the plain shape the validator reads. */
function newcomerGroundsRefs() {
  const creatures = require('../world/creatures')
  const rows = {}
  for (const [k, e] of Object.entries(creatures)) {
    const f = (e && e.fields) || {}
    if (!f.aggressionLevel) continue
    rows[k] = { aggression: f.aggressionLevel.defaultValue, tier: Number(f.tier.defaultValue) }
  }
  return { creatures: rows, biomes: require('../world/creatures/shared').BIOME_KEYS }
}

/** Problems with the table, as strings. */
function newcomerGroundsProblems(d, refs) {
  const p = []
  if (!(Number.isInteger(d.count) && d.count >= 1)) p.push('count must be an integer >= 1')
  // The tutorial needs a tree, rock, soil, loose items and a first hunt within resourceRadiusMetres of a spawn.
  if (!(d.radiusMetres >= 500)) p.push(`radiusMetres ${d.radiusMetres} is below the 500 m the tutorial needs`)
  if (!(d.resourceRadiusMetres >= 40)) p.push('resourceRadiusMetres must be at least 40')
  if (!(d.resourceRadiusMetres <= d.radiusMetres)) p.push('resourceRadiusMetres must fit inside radiusMetres')
  if (!(d.spawnRadiusMetres > 0 && d.spawnRadiusMetres <= d.radiusMetres)) p.push('spawnRadiusMetres must be in (0, radiusMetres]')
  if (!(d.claimRadiusMetres > 0 && d.claimRadiusMetres < d.spawnRadiusMetres)) p.push('claimRadiusMetres must be in (0, spawnRadiusMetres)')
  for (const b of d.biomes || []) if (!refs.biomes.includes(b)) p.push(`biome ${b} is not a biome`)
  if (!(d.biomes || []).length) p.push('biomes is empty')
  if (!(d.allowedCreatures || []).length) p.push('allowedCreatures is empty: the first hunt needs a creature')
  for (const c of d.allowedCreatures || []) {
    const row = refs.creatures[c]
    if (!row) { p.push(`${c} is not a creature`); continue }
    if (!(d.allowedAggression || []).includes(row.aggression)) p.push(`${c}: ${row.aggression} creature is not allowed in a newcomer ground`)
    if (row.tier > d.maxCreatureTier) p.push(`${c}: tier ${row.tier} is above the cap ${d.maxCreatureTier}`)
  }
  for (const a of d.allowedAggression || []) if (a === 'aggressive' || a === 'territorial') p.push(`allowedAggression must not include ${a}`)
  if (!(d.looseDensityInside > 0 && d.looseDensityInside <= 1)) p.push('looseDensityInside must be in (0, 1]')
  if (!(d.looseDensityOutside >= 0 && d.looseDensityOutside < d.looseDensityInside)) p.push('looseDensityOutside must be below looseDensityInside')
  if (!(d.looseRegrowSeconds > 0)) p.push('looseRegrowSeconds must be positive')
  if (!(d.pickReachMetres > 0 && d.pickReachMetres <= 6)) p.push('pickReachMetres must be in (0, 6]')
  return p
}

function validateNewcomerGrounds(d, refs) {
  const problems = newcomerGroundsProblems(d, refs)
  if (problems.length) throw new Error('Newcomer grounds are invalid:\n  ' + problems.join('\n  '))
}

const NewcomerGrounds = defineEntity({
  tags: ['world-system'],
  description:
    'Where a new character starts: a few large, gentle grounds on the open continent with trees, rock and soil in reach, ' +
    'only weak creatures, loose stones and branches on the ground, and a protected centre.',
  goal: 'A newcomer lands in a place built for a first hour, never among whatever lives where a search landed (Phase 261)',
  fields: {
    id:                   { type: 'uuid', primaryKey: true },
    count:                { type: 'integer', description: 'Grounds on the open continent', defaultValue: GROUNDS.count },
    radiusMetres:         { type: 'decimal', description: 'Radius of a ground, m', defaultValue: GROUNDS.radiusMetres },
    biomes:               { type: 'json', description: 'Biomes a ground may sit in', defaultValue: GROUNDS.biomes },
    allowedCreatures:     { type: 'json', description: 'Creature keys that may spawn inside a ground', defaultValue: GROUNDS.allowedCreatures },
    allowedAggression:    { type: 'json', description: 'Aggression levels a ground tolerates', defaultValue: GROUNDS.allowedAggression },
    maxCreatureTier:      { type: 'integer', description: 'Danger cap: highest creature tier', defaultValue: GROUNDS.maxCreatureTier },
    looseDensityInside:   { type: 'decimal', description: 'Chance of a loose item per 4 m tile inside a ground', defaultValue: GROUNDS.looseDensityInside },
    looseDensityOutside:  { type: 'decimal', description: 'Chance of a loose item per 4 m tile elsewhere', defaultValue: GROUNDS.looseDensityOutside },
    looseRegrowSeconds:   { type: 'decimal', description: 'Seconds until a picked loose item is back', defaultValue: GROUNDS.looseRegrowSeconds },
    pickReachMetres:      { type: 'decimal', description: 'Reach for picking a loose item up, m', defaultValue: GROUNDS.pickReachMetres },
    claimRadiusMetres:    { type: 'decimal', description: 'No structure within this of a ground centre, m', defaultValue: GROUNDS.claimRadiusMetres },
    resourceRadiusMetres: { type: 'decimal', description: 'Resource guarantee radius around each spawn point, m', defaultValue: GROUNDS.resourceRadiusMetres },
    spawnRadiusMetres:    { type: 'decimal', description: 'A spawn lies within this of a ground centre, m', defaultValue: GROUNDS.spawnRadiusMetres },
  },
})

module.exports = { NewcomerGrounds, newcomerGroundsData, newcomerGroundsRefs, newcomerGroundsProblems, validateNewcomerGrounds }
