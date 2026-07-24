const { defineEntity } = require('@newel/core')

module.exports = {

  VoidRift: defineEntity({
    role: 'biome',
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
      soilFertility:  { type: 'decimal', description: '0–1; zero — nothing biological grows near rifts' },
    },
    behaviors: {
      evaluateSpawn: {
        description: 'Determine which materials and creatures spawn in a void rift tile',
        rules: [
          'Voidite crystals are abundant at weight 0.7 — but refining them here risks a void burst',
          'Veilsteel ore appears at weight 0.3 in stabilised sections near the rift edge',
          'No conventional wood or stone spawns within the rift boundary',
          'Creature: VoidSerpent — placeholder until Phase 5 — spawn weight 0.5',
          'Creature: RiftWarden — placeholder until Phase 5 — spawn weight 0.15',
          'Players accumulate void corruption at 1 point per minute without void-lined armour',
          'Corruption above 80 triggers involuntary void-pulse AoE damaging nearby allies',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
