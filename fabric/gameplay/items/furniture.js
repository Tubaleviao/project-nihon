const { defineEntity, RARITIES, DURABILITY_STATES, itemStateMachine, itemShape } = require('./shared')

module.exports = {

  // ─── Bed ──────────────────────────────────────────────────────────────────
  // Phase 184 — placed through the station path as station type `bed` (BedSpawn in gameplay/bed.js).
  Bed: defineEntity({
    tags: ['item', 'station'],
    description:
      'A plank frame with a straw pallet. Placed as a bed station; the bed a player places becomes the ' +
      'place they come back to after death. One bed per player.',
    goal: 'The first-hour item that turns a shelter into a home and a spawn point (Phases 184-185)',
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      condition: { type: 'enum', values: DURABILITY_STATES },
      weight:    { type: 'decimal', description: 'kg per bed', defaultValue: 15.0 },
      rarity:    { type: 'enum', values: RARITIES, defaultValue: 'common' },
      stackable: { type: 'boolean', description: 'False; one bed per slot', defaultValue: false },
      shape: itemShape({ archetype: 'bed', parts: { frame: 'Thornwood', mattress: 'Grass' } }),
      durability: { type: 'integer', description: 'Structural integrity', defaultValue: 300 },
    },
    relations: {
      plank: { name: 'plank', kind: 'hasOne', target: 'ThornwoodPlank' },
    },
    stateMachine: itemStateMachine(),
    behaviors: {
      degrade: {
        description: 'A bed does not wear while carried',
        rules: ['Normal inventory storage never degrades a bed'],
        auth: { roles: ['maintainer'] },
      },
      repair: {
        description: 'Re-lash a worn bed at a carpentry bench',
        rules: ['Requires a carpentry bench; no additional materials consumed'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),
}
