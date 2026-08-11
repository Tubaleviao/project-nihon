const { defineEntity } = require('@newel/core')

module.exports = {

  TemperateForest: defineEntity({
    tags: ['biome'],
    description:
      'Broad mixed-leaf forests covering most mid-latitude landmass. ' +
      'Moderate rainfall, seasonal temperature shifts, and rich soil make this the ' +
      'most hospitable starting biome — also the most contested by player factions.',
    goal: 'Provide new players a gentle entry environment with abundant basic materials and manageable creatures',
    fields: {
      id:             { type: 'uuid', primaryKey: true },
      avgTemperature: { type: 'decimal', description: '°C annual average' },
      avgRainfall:    { type: 'decimal', description: 'mm per in-game year' },
      soilFertility:  { type: 'decimal', description: '0–1; affects crop growth rates' },
    },
    relations: {
      spawnForestBoar:   { name: 'spawnForestBoar',   kind: 'hasMany', target: 'ForestBoar' },
      spawnGraywolfPack: { name: 'spawnGraywolfPack', kind: 'hasMany', target: 'GraywolfPack' },
    },
    behaviors: {
      evaluateSpawn: {
        description: 'Determine which materials and creatures spawn in a generated forest tile',
        rules: [
          'Ferrite veins spawn in surface outcrops at weight 0.6',
          'Thornwood trees are the dominant wood source at weight 0.8',
          'ForestBoar spawn weight 0.7',
          'GraywolfPack spawn weight 0.4',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  TemperateGrassland: defineEntity({
    tags: ['biome'],
    description:
      'Open rolling plains ideal for large settlements, agriculture, and mounted travel. ' +
      'Sparse tree cover means lumber is scarce but soil fertility is highest.',
    goal: 'Push players toward inter-biome trade for lumber while rewarding agricultural investment',
    fields: {
      id:             { type: 'uuid', primaryKey: true },
      avgTemperature: { type: 'decimal', description: '°C annual average' },
      avgRainfall:    { type: 'decimal', description: 'mm per in-game year' },
      soilFertility:  { type: 'decimal', description: '0–1; highest of all biomes' },
    },
    relations: {
      spawnSteppeBison: { name: 'spawnSteppeBison', kind: 'hasMany', target: 'SteppeBison' },
      spawnRidgeHawk:   { name: 'spawnRidgeHawk',   kind: 'hasMany', target: 'RidgeHawk' },
    },
    behaviors: {
      evaluateSpawn: {
        description: 'Determine which materials and creatures spawn in a generated grassland tile',
        rules: [
          'Ferrite veins in shallow subsurface deposits at weight 0.4',
          'Thornwood is rare; only isolated copses at weight 0.1',
          'SteppeBison spawn weight 0.8',
          'RidgeHawk spawn weight 0.5',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
