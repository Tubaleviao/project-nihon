const { defineEntity } = require('@newel/core')

module.exports = {

  VolcanicBadlands: defineEntity({
    tags: ['biome'],
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
      treeDensity:    { type: 'integer', description: 'Mean trees per chunk before the density noise and clearing roll (0 = no trees grow here)', defaultValue: 0 },
      surfaceMaterial: { type: 'string', description: 'Topsoil cover of unedited natural ground (Phase 49)', defaultValue: 'Ash' },
      surfaceTint:    { type: 'string', description: 'Hex colour of the natural top face', defaultValue: '#3a3a3e' },
      soilTint:       { type: 'string', description: 'Hex colour of the side wall down to topsoilDepth; rock below', defaultValue: '#2c2a2c' },
      topsoilDepth:   { type: 'decimal', description: 'World units of soil under the surface before rock shows on a wall', defaultValue: 1 },
      soilMaterial:   { type: 'string', description: 'Material a mined slice of this biome\'s topsoil yields, within topsoilDepth of the surface (Phase 49). The surface-material → soil-material mapping, authored here so no GDScript branch decides it', defaultValue: 'Soil' },
      temperature:    { type: 'json', description: 'Climate envelope, normalised 0 (coldest) to 1 (hottest): the climate field selects this biome where its temperature lies in [min, max] (Phase 49)', defaultValue: { min: 0.7, max: 1 } },
      moisture:       { type: 'json', description: 'Climate envelope, normalised 0 (driest) to 1 (wettest), as for temperature', defaultValue: { min: 0, max: 1 } },
      surfaceVeinChance: { type: 'decimal', description: 'Share of this biome\'s top-cell veins that break the surface and keep their deposit marker (Phase 49); the rest are pushed out of view. Authored from the biome prose — aethermite rides ley-line VENTS, and a vent is a surface breach, so its ground shows more of them', defaultValue: 0.25 },
    },
    relations: {
      spawnLavaSlug:      { name: 'spawnLavaSlug',      kind: 'hasMany', target: 'LavaSlug' },
      spawnCinderGargoyle: { name: 'spawnCinderGargoyle', kind: 'hasMany', target: 'CinderGargoyle' },
    },
    behaviors: {
      evaluateSpawn: {
        description: 'Determine which materials and creatures spawn in a volcanic tile',
        rules: [
          'Ashite is the dominant surface material at weight 0.9',
          'Aethermite veins near ley-line vents at weight 0.2 — higher near eruption events',
          'Ferrite ore in deep lava tubes at weight 0.1; requires tier-2 mining tools',
          'LavaSlug spawn weight 0.6',
          'CinderGargoyle spawn weight 0.2; weight increases to 0.6 during eruption events',
        ],
        auth: { roles: ['maintainer'] },
      },
      applyHazards: {
        description: 'Apply persistent environmental hazards to players and structures in a volcanic tile',
        rules: [
          'Player structures take ongoing heat damage without ashite insulation',
          'Ash-fall (evaluated by WeatherSystem.evaluateWeather on eruption days) reduces visibility by 50% and disables all outdoor forges; ash-fall is a weather event handled by the WeatherSystem, not a persistent biome hazard',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
