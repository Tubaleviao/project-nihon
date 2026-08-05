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
      avgTemperature: { type: 'decimal', description: '°C; fluctuates wildly near active rifts' },
      avgRainfall:    { type: 'decimal', description: 'mm per in-game year; negligible' },
      soilFertility:  { type: 'decimal', description: '0–1; always zero — nothing biological grows near rifts; tile generation must set this to 0 and reject any non-zero value' },
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
          'RiftWarden: one instance per VoidRift zone; spawn weight 0.15; does not respawn until cooldown expires',
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
