const { defineEntity } = require('@newel/core')

module.exports = {

  VoidRift: defineEntity({
    tags: ['biome'],
    description:
      'Fractured terrain surrounding permanent rifts in the fabric of reality. ' +
      'Reality distortions warp physics: gravity is inconsistent, time stutters, ' +
      'and unprotected players suffer void corruption over time. ' +
      'Voidite crystals are abundant here — and so is mortal danger.',
    goal: 'Cap-content biome requiring full equipment, team co-ordination, and void-specific knowledge',
    fields: {
      id:             { type: 'uuid', primaryKey: true },
      seasonSwing:    { type: 'decimal', description: '°C the biome\'s temperature rises above and falls below its annual average over the year, at full seasonal latitude (Phase 54)', defaultValue: 10 },
      summerTint:     { type: 'string', description: 'Hex multiplier on the ground and foliage colour at the height of summer (Phase 54)', defaultValue: '#ffffff' },
      winterTint:     { type: 'string', description: 'Hex multiplier on the ground and foliage colour at the depth of winter (Phase 54)', defaultValue: '#c9d3dc' },
      seasonGrowth:   { type: 'json', description: 'Multiplier on tree regrowth speed (and growth rates) at the height of summer and the depth of winter; it varies linearly between (Phase 54)', defaultValue: { summer: 1.25, winter: 0.5 } },
      seasonSpawn:    { type: 'json', description: 'Multiplier on creature spawn chance at the height of summer and the depth of winter (Phase 54)', defaultValue: { summer: 1.15, winter: 0.7 } },
      avgTemperature: { type: 'decimal', description: '°C; fluctuates wildly near active rifts' },
      avgRainfall:    { type: 'decimal', description: 'mm per in-game year; negligible' },
      soilFertility:  { type: 'decimal', description: '0–1; always zero — nothing biological grows near rifts; tile generation must set this to 0 and reject any non-zero value' },
      treeDensity:    { type: 'integer', description: 'Mean trees per chunk before the density noise and clearing roll (0 = no trees grow here)', defaultValue: 0 },
      surfaceMaterial: { type: 'string', description: 'Topsoil cover of unedited natural ground (Phase 49)', defaultValue: 'Void' },
      surfaceTint:    { type: 'string', description: 'Hex colour of the natural top face', defaultValue: '#2a1f3a' },
      soilTint:       { type: 'string', description: 'Hex colour of the side wall down to topsoilDepth; rock below', defaultValue: '#1e1630' },
      topsoilDepth:   { type: 'decimal', description: 'World units of soil under the surface before rock shows on a wall', defaultValue: 1 },
      soilMaterial:   { type: 'string', description: 'Material a mined slice of this biome\'s topsoil yields, within topsoilDepth of the surface (Phase 49). The surface-material → soil-material mapping, authored here so no GDScript branch decides it', defaultValue: 'Soil' },
      temperature:    { type: 'json', description: 'Climate envelope, normalised 0 (coldest) to 1 (hottest): the climate field selects this biome where its temperature lies in [min, max] (Phase 49)', defaultValue: { min: 0.1, max: 0.4 } },
      moisture:       { type: 'json', description: 'Climate envelope, normalised 0 (driest) to 1 (wettest), as for temperature', defaultValue: { min: 0, max: 0.4 } },
      altitude:       { type: 'json', description: 'Altitude envelope in metres above sea level: the climate field selects this biome where the ground height lies in [min, max] (Phase 51)', defaultValue: { min: 1.5, max: 250 } },
      rarity:         { type: 'decimal', description: 'Share of the world where this biome may appear: 1 = anywhere its envelope fits; below 1 it is a rare climate niche, eligible only where a low-frequency niche field falls under this value (Phase 51)', defaultValue: 0.05 },
      surfaceVeinChance: { type: 'decimal', description: 'Share of this biome\'s top-cell veins that break the surface and keep their deposit marker (Phase 49); the rest are pushed out of view. Authored from the biome prose — voidite shows in STABILISED sections only, so its rifts stay mostly closed ground', defaultValue: 0.05 },
    },
    relations: {
      spawnVoidSerpent: { name: 'spawnVoidSerpent', kind: 'hasMany', target: 'VoidSerpent' },
      spawnRiftWarden:  { name: 'spawnRiftWarden',  kind: 'hasOne',  target: 'RiftWarden' },
    },
    behaviors: {
      evaluateSpawn: {
        description: 'Determine which materials and creatures spawn in a void rift tile',
        rules: [
          'Voidite crystals are abundant at weight 0.7 — but refining them here risks a void burst',
          'Ferrite ore appears at weight 0.3 in stabilised sections near the rift edge',
          'No conventional wood or stone spawns within the rift boundary',
          'VoidSerpent spawn weight 0.5',
          'RiftWarden: one instance per VoidRift zone; does not respawn until cooldown expires (no probabilistic spawn weight — singleton, managed by zone controller)',
        ],
        auth: { roles: ['maintainer'] },
      },
      applyHazards: {
        description: 'Apply persistent environmental hazards to players and structures in a void rift tile',
        rules: [
          'Players accumulate void corruption at 1 point per minute without void-lined armour; void-lined armour is crafted from refined voidite plate',
          'Corruption above 80 triggers involuntary void-pulse AoE damaging nearby allies',
          'A void burst event (triggered by failed voidite refining or corruption overflow inside a VoidRift tile) is survivable; surviving one grants the player the voidBurstSurvivor flag required to learn enchanting voidite — void bursts triggered during refining outside a VoidRift tile (see Voidite.refine) also grant this flag',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
