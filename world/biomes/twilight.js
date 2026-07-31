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
