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
      soilMaterial:   { type: 'string', description: 'Material a mined slice of this biome\'s topsoil yields, within topsoilDepth of the surface (Phase 49). The surface-material → soil-material mapping, authored here so no GDScript branch decides it', defaultValue: 'Soil' },
      temperature:    { type: 'json', description: 'Climate envelope, normalised 0 (coldest) to 1 (hottest): the climate field selects this biome where its temperature lies in [min, max] (Phase 49)', defaultValue: { min: 0.15, max: 0.45 } },
      moisture:       { type: 'json', description: 'Climate envelope, normalised 0 (driest) to 1 (wettest), as for temperature', defaultValue: { min: 0.4, max: 1 } },
      altitude:       { type: 'json', description: 'Altitude envelope in metres above sea level: the climate field selects this biome where the ground height lies in [min, max] (Phase 51)', defaultValue: { min: 1.5, max: 250 } },
      rarity:         { type: 'decimal', description: 'Share of the world where this biome may appear: 1 = anywhere its envelope fits; below 1 it is a rare climate niche, eligible only where a low-frequency niche field falls under this value (Phase 51)', defaultValue: 0.08 },
      surfaceVeinChance: { type: 'decimal', description: 'Share of this biome\'s top-cell veins that break the surface and keep their deposit marker (Phase 49); the rest are pushed out of view. Authored from the biome prose — its metals sit in shallow CAVE systems and cliff faces, so few veins crop out through the ground', defaultValue: 0.1 },
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
