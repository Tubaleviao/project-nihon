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
      treeDensity:    { type: 'integer', description: 'Mean trees per chunk before the density noise and clearing roll (0 = no trees grow here)', defaultValue: 8 },
      surfaceMaterial: { type: 'string', description: 'Topsoil cover of unedited natural ground (Phase 49)', defaultValue: 'Grass' },
      surfaceTint:    { type: 'string', description: 'Hex colour of the natural top face', defaultValue: '#4f8a3a' },
      soilTint:       { type: 'string', description: 'Hex colour of the side wall down to topsoilDepth; rock below', defaultValue: '#6b4a2e' },
      topsoilDepth:   { type: 'decimal', description: 'World units of soil under the surface before rock shows on a wall', defaultValue: 3 },
      temperature:    { type: 'json', description: 'Climate envelope, normalised 0 (coldest) to 1 (hottest): the climate field selects this biome where its temperature lies in [min, max] (Phase 49)', defaultValue: { min: 0.3, max: 0.7 } },
      moisture:       { type: 'json', description: 'Climate envelope, normalised 0 (driest) to 1 (wettest), as for temperature', defaultValue: { min: 0.5, max: 1 } },
      surfaceVeinChance: { type: 'decimal', description: 'Fraction of veins that reach the surface and break through it; the rest stay buried (Phase 49)', defaultValue: 0.2 },
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
      treeDensity:    { type: 'integer', description: 'Mean trees per chunk before the density noise and clearing roll (0 = no trees grow here)', defaultValue: 2 },
      surfaceMaterial: { type: 'string', description: 'Topsoil cover of unedited natural ground (Phase 49)', defaultValue: 'Grass' },
      surfaceTint:    { type: 'string', description: 'Hex colour of the natural top face', defaultValue: '#7aa23f' },
      soilTint:       { type: 'string', description: 'Hex colour of the side wall down to topsoilDepth; rock below', defaultValue: '#6b4a2e' },
      topsoilDepth:   { type: 'decimal', description: 'World units of soil under the surface before rock shows on a wall', defaultValue: 4 },
      temperature:    { type: 'json', description: 'Climate envelope, normalised 0 (coldest) to 1 (hottest): the climate field selects this biome where its temperature lies in [min, max] (Phase 49)', defaultValue: { min: 0.3, max: 0.7 } },
      moisture:       { type: 'json', description: 'Climate envelope, normalised 0 (driest) to 1 (wettest), as for temperature', defaultValue: { min: 0, max: 0.5 } },
      surfaceVeinChance: { type: 'decimal', description: 'Fraction of veins that reach the surface and break through it; the rest stay buried (Phase 49)', defaultValue: 0.2 },
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
