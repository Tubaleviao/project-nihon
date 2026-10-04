const { defineEntity } = require('@newel/core')

module.exports = {

  TwilightGrove: defineEntity({
    tags: ['biome'],
    description:
      'Eerie glades where day-night cycles run at an accelerated, unpredictable rate, ' +
      'bathing the land in perpetual half-light. Duskwood trees dominate the canopy; ' +
      'lumenfite crystals stud shallow cave walls. Politically neutral zones prized by ' +
      'traders and magic-users.',
    goal: 'Introduce a distinctive environment that rewards exploration and alchemical knowledge',
    fields: {
      id:             { type: 'uuid', primaryKey: true },
      avgTemperature: { type: 'decimal', description: '°C annual average; mild' },
      avgRainfall:    { type: 'decimal', description: 'mm per in-game year; moderate' },
      soilFertility:  { type: 'decimal', description: '0–1; moderate; unusual flora' },
      treeDensity:    { type: 'integer', description: 'Mean trees per chunk before the density noise and clearing roll (0 = no trees grow here)', defaultValue: 8 },
      surfaceMaterial: { type: 'string', description: 'Topsoil cover of unedited natural ground (Phase 49)', defaultValue: 'Moss' },
      surfaceTint:    { type: 'string', description: 'Hex colour of the natural top face', defaultValue: '#3f7a6a' },
      soilTint:       { type: 'string', description: 'Hex colour of the side wall down to topsoilDepth; rock below', defaultValue: '#3b3a4a' },
      topsoilDepth:   { type: 'decimal', description: 'World units of soil under the surface before rock shows on a wall', defaultValue: 2 },
      temperature:    { type: 'json', description: 'Climate envelope, normalised 0 (coldest) to 1 (hottest): the climate field selects this biome where its temperature lies in [min, max] (Phase 49)', defaultValue: { min: 0, max: 0.3 } },
      moisture:       { type: 'json', description: 'Climate envelope, normalised 0 (driest) to 1 (wettest), as for temperature', defaultValue: { min: 0.4, max: 1 } },
      surfaceVeinChance: { type: 'decimal', description: 'Fraction of veins that reach the surface and break through it; the rest stay buried (Phase 49)', defaultValue: 0.2 },
      dayNightSpeed:  { type: 'decimal', description: 'Multiplier on the global day-night cycle (1 = normal); varies per tile; drives weather pattern selection and duskfiber luminosity' },
    },
    relations: {
      spawnGlimmerFox:  { name: 'spawnGlimmerFox',  kind: 'hasMany', target: 'GlimmerFox' },
      spawnVeilStalker: { name: 'spawnVeilStalker', kind: 'hasMany', target: 'VeilStalker' },
    },
    behaviors: {
      evaluateSpawn: {
        description: 'Determine which materials and creatures spawn in a twilight grove tile',
        rules: [
          'Duskfiber is the dominant fibre material at weight 0.9',
          'Lumenfite crystals in exposed cave faces at weight 0.5',
          'Aethermite trace amounts at ley-line intersections at weight 0.15',
          'GlimmerFox spawn weight 0.7',
          'VeilStalker spawn weight 0.3',
          'Day-night speed varies tile-to-tile; duskfiber thread luminosity varies accordingly',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
