const { defineEntity } = require('@newel/core')

module.exports = {

  TwilightGrove: defineEntity({
    role: 'biome',
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
    },
    behaviors: {
      evaluateSpawn: {
        description: 'Determine which materials and creatures spawn in a twilight grove tile',
        rules: [
          'Duskfiber is the dominant wood material at weight 0.9',
          'Lumenfite crystals in exposed cave faces at weight 0.5',
          'Aethermite trace amounts at ley-line intersections at weight 0.15',
          'Creature: GlimmerFox — placeholder until Phase 5 — spawn weight 0.7',
          'Creature: VeilStalker — placeholder until Phase 5 — spawn weight 0.3',
          'Day-night speed varies tile-to-tile; duskfiber thread luminosity varies accordingly',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
