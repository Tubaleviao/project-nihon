const { defineEntity } = require('@newel/core')

// Phase 51 — the Earth-like biomes. Each is a climate envelope (temperature, moisture, altitude)
// plus the same ground facts the fantasy biomes carry. Altitude is metres above sea level; the
// land default is [1.5, 250], so Ocean sits below the sea surface, Beach on the first metre and a
// half of shore, and Alpine above the tree line.
function earthBiome({ description, goal, treeDensity, surfaceMaterial, surfaceTint, soilTint, topsoilDepth,
  temperature, moisture, altitude, avgTemperature, avgRainfall, soilFertility, surfaceVeinChance, rules, season = {} }) {
  const S = { swing: 10, summer: '#ffffff', winter: '#c9d3dc', growth: { summer: 1.25, winter: 0.5 }, spawn: { summer: 1.15, winter: 0.7 }, ...season }
  return defineEntity({
    tags: ['biome'],
    description,
    goal,
    fields: {
      id:             { type: 'uuid', primaryKey: true },
      seasonSwing:    { type: 'decimal', description: '°C the biome\'s temperature rises above and falls below its annual average over the year, at full seasonal latitude (Phase 54)', defaultValue: S.swing },
      summerTint:     { type: 'string', description: 'Hex multiplier on the ground and foliage colour at the height of summer (Phase 54)', defaultValue: S.summer },
      winterTint:     { type: 'string', description: 'Hex multiplier on the ground and foliage colour at the depth of winter (Phase 54)', defaultValue: S.winter },
      seasonGrowth:   { type: 'json', description: 'Multiplier on tree regrowth speed (and growth rates) at the height of summer and the depth of winter; it varies linearly between (Phase 54)', defaultValue: S.growth },
      seasonSpawn:    { type: 'json', description: 'Multiplier on creature spawn chance at the height of summer and the depth of winter (Phase 54)', defaultValue: S.spawn },
      avgTemperature: { type: 'decimal', description: '°C annual average', defaultValue: avgTemperature },
      avgRainfall:    { type: 'decimal', description: 'mm per in-game year', defaultValue: avgRainfall },
      soilFertility:  { type: 'decimal', description: '0–1; affects crop growth rates', defaultValue: soilFertility },
      treeDensity:    { type: 'integer', description: 'Mean trees per chunk before the density noise and clearing roll (0 = no trees grow here)', defaultValue: treeDensity },
      surfaceMaterial: { type: 'string', description: 'Topsoil cover of unedited natural ground (Phase 49)', defaultValue: surfaceMaterial },
      surfaceTint:    { type: 'string', description: 'Hex colour of the natural top face', defaultValue: surfaceTint },
      soilTint:       { type: 'string', description: 'Hex colour of the side wall down to topsoilDepth; rock below', defaultValue: soilTint },
      topsoilDepth:   { type: 'decimal', description: 'World units of soil under the surface before rock shows on a wall', defaultValue: topsoilDepth },
      soilMaterial:   { type: 'string', description: 'Material a mined slice of this biome\'s topsoil yields, within topsoilDepth of the surface (Phase 49)', defaultValue: 'Soil' },
      temperature:    { type: 'json', description: 'Climate envelope, normalised 0 (coldest) to 1 (hottest): the climate field selects this biome where its temperature lies in [min, max] (Phase 49)', defaultValue: temperature },
      moisture:       { type: 'json', description: 'Climate envelope, normalised 0 (driest) to 1 (wettest), as for temperature', defaultValue: moisture },
      altitude:       { type: 'json', description: 'Altitude envelope in metres above sea level: the climate field selects this biome where the ground height lies in [min, max] (Phase 51)', defaultValue: altitude },
      rarity:         { type: 'decimal', description: 'Share of the world where this biome may appear: 1 = anywhere its envelope fits (Phase 51)', defaultValue: 1 },
      surfaceVeinChance: { type: 'decimal', description: 'Share of this biome\'s top-cell veins that break the surface and keep their deposit marker (Phase 49)', defaultValue: surfaceVeinChance },
    },
    behaviors: {
      evaluateSpawn: {
        description: 'Determine which materials, trees and creatures spawn in a generated tile of this biome',
        rules,
        auth: { roles: ['maintainer'] },
      },
    },
  })
}

const ALL = { min: 0, max: 1 }
const LAND = { min: 1.5, max: 250 }

module.exports = {

  Ocean: earthBiome({
    description: 'Open water over the continental shelf and the deep basins. The sea floor is sand and silt; ' +
      'the surface sits at the world\'s sea level and a player wades or swims it.',
    goal: 'Give the planet its oceans: the barrier between continents',
    treeDensity: 0, surfaceMaterial: 'Sand', surfaceTint: '#c9b97a', soilTint: '#8a7d55', topsoilDepth: 6,
    temperature: ALL, moisture: ALL, altitude: { min: -10000, max: 0 },
    avgTemperature: 12, avgRainfall: 0, soilFertility: 0, surfaceVeinChance: 0.05,
    rules: ['No land creature, tree or ore-surface table spawns in an Ocean chunk', 'The sea floor is sand and silt, with ore only deep in the bedrock'],
  }),

  Beach: earthBiome({
    description: 'The first metre and a half of shore above the waterline: pale sand and no trees.',
    goal: 'Make coasts readable where land meets sea',
    treeDensity: 0, surfaceMaterial: 'Sand', surfaceTint: '#e3d49b', soilTint: '#b3a36d', topsoilDepth: 3,
    temperature: ALL, moisture: ALL, altitude: { min: 0, max: 1.5 },
    avgTemperature: 18, avgRainfall: 600, soilFertility: 0.1, surfaceVeinChance: 0.1,
    rules: ['No trees grow on a beach', 'Creature spawns come from the inland biome, not the shore'],
  }),

  Desert: earthBiome({
    description: 'Hot, dry sand and rock: the dry half of the tropics.',
    goal: 'A sparse, hostile low-latitude biome that rewards travel with exposed ore',
    treeDensity: 0, surfaceMaterial: 'Sand', surfaceTint: '#d8b768', soilTint: '#a8844a', topsoilDepth: 2,
    temperature: { min: 0.65, max: 1 }, moisture: { min: 0, max: 0.25 }, altitude: LAND,
    avgTemperature: 34, avgRainfall: 80, soilFertility: 0.05, surfaceVeinChance: 0.3,
    rules: ['No trees grow in a desert', 'Ferrite veins outcrop at weight 0.5 on bare rock'],
  }),

  Tundra: earthBiome({
    description: 'Frozen, treeless plains at the high latitudes, down to the polar ice.',
    goal: 'The cold pole of the climate: cold ground with little to harvest',
    treeDensity: 0, surfaceMaterial: 'Snow', surfaceTint: '#dfe8ea', soilTint: '#7d7a6e', topsoilDepth: 1.5,
    temperature: { min: 0, max: 0.2 }, moisture: ALL, altitude: LAND,
    season: { swing: 14 }, avgTemperature: -12, avgRainfall: 250, soilFertility: 0.05, surfaceVeinChance: 0.2,
    rules: ['No trees grow on the tundra', 'Ferrite veins outcrop at weight 0.3'],
  }),

  Alpine: earthBiome({
    description: 'Snow-capped peaks above the tree line, at any latitude.',
    goal: 'Make mountains a biome of their own: cold, bare and high',
    treeDensity: 0, surfaceMaterial: 'Snow', surfaceTint: '#f2f6f7', soilTint: '#8c8c93', topsoilDepth: 1,
    temperature: ALL, moisture: ALL, altitude: { min: 250, max: 100000 },
    season: { swing: 14 }, avgTemperature: -5, avgRainfall: 900, soilFertility: 0, surfaceVeinChance: 0.4,
    rules: ['No trees grow above the tree line', 'Ferrite and Aethermite veins outcrop at weight 0.5 on bare peaks'],
  }),

  Taiga: earthBiome({
    description: 'Cold, wet conifer forest between the tundra and the temperate belt.',
    goal: 'A northern timber biome: thinner stands than the temperate forest',
    treeDensity: 5, surfaceMaterial: 'Grass', surfaceTint: '#3f6b4a', soilTint: '#5a4632', topsoilDepth: 2.5,
    temperature: { min: 0.15, max: 0.35 }, moisture: { min: 0.3, max: 1 }, altitude: LAND,
    avgTemperature: 0, avgRainfall: 600, soilFertility: 0.3, surfaceVeinChance: 0.15,
    rules: ['Thornwood trees grow at about two thirds of the temperate forest\'s density', 'Ferrite veins outcrop at weight 0.3'],
  }),

  Savanna: earthBiome({
    description: 'Warm grassland with scattered trees in the seasonal tropics.',
    goal: 'The warm counterpart of the temperate grassland',
    treeDensity: 1, surfaceMaterial: 'Grass', surfaceTint: '#b3a64a', soilTint: '#7a5a36', topsoilDepth: 3,
    temperature: { min: 0.6, max: 1 }, moisture: { min: 0.25, max: 0.55 }, altitude: LAND,
    avgTemperature: 26, avgRainfall: 700, soilFertility: 0.5, surfaceVeinChance: 0.2,
    rules: ['Thornwood grows only as isolated trees', 'Ferrite veins in shallow subsurface deposits at weight 0.4'],
  }),

}
