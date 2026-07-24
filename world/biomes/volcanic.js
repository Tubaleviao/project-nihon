const { defineEntity } = require('@newel/core')

module.exports = {

  VolcanicBadlands: defineEntity({
    role: 'biome',
    description:
      'Barren, heat-scorched terrain surrounding active or dormant volcanic calderas. ' +
      'The surface is covered in ashite rock and cooled lava flows. ' +
      'Harsh for survival but rich in rare metallic ores; a magnet for advanced crafters.',
    goal: 'Create a high-risk, high-reward biome that demands infrastructure investment before exploitation',
    fields: {
      id:             { type: 'uuid', primaryKey: true },
      avgTemperature: { type: 'decimal', description: '°C annual average; extreme heat' },
      avgRainfall:    { type: 'decimal', description: 'mm per in-game year; near zero' },
      soilFertility:  { type: 'decimal', description: '0–1; near zero; no conventional farming' },
    },
    behaviors: {
      evaluateSpawn: {
        description: 'Determine which materials and creatures spawn in a volcanic tile',
        rules: [
          'Ashite is the dominant surface material at weight 0.9',
          'Aethermite veins near ley-line vents at weight 0.2 — higher near eruption events',
          'Ferrite ore in deep lava tubes at weight 0.1; requires tier-2 mining tools',
          'Creature: LavaSlug — placeholder until Phase 5 — spawn weight 0.6',
          'Creature: CinderGargoyle — placeholder until Phase 5 — spawn weight 0.2',
        ],
        auth: { roles: ['maintainer'] },
      },
      applyHazards: {
        description: 'Apply persistent environmental hazards to players and structures in a volcanic tile',
        rules: [
          'Player structures take ongoing heat damage without ashite insulation',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
