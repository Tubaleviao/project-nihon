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

  // ─── Chest ────────────────────────────────────────────────────────────────
  // Phase 208 — placed through the station path as station type `chest` (ChestsAndDoors in gameplay/chests.js).
  Chest: defineEntity({
    tags: ['item', 'station'],
    description:
      'A plank box with a ferrite band and lock. Placed as a chest station that holds items; its owner sets ' +
      'who may open it: the owner, their clan or everyone.',
    goal: 'Keep a house\'s things safe without making them unbreakable (Phase 208)',
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      condition: { type: 'enum', values: DURABILITY_STATES },
      weight:    { type: 'decimal', description: 'kg per empty chest', defaultValue: 12.0 },
      rarity:    { type: 'enum', values: RARITIES, defaultValue: 'common' },
      stackable: { type: 'boolean', description: 'False; one chest per slot', defaultValue: false },
      shape: itemShape({ archetype: 'chest', parts: { box: 'Thornwood', band: 'Ferrite' } }),
      durability: { type: 'integer', description: 'Structural integrity', defaultValue: 300 },
    },
    relations: {
      plank:   { name: 'plank',   kind: 'hasOne', target: 'ThornwoodPlank' },
      ferrite: { name: 'ferrite', kind: 'hasOne', target: 'FerriteIngot' },
    },
    stateMachine: itemStateMachine(),
    behaviors: {
      degrade: {
        description: 'A chest does not wear while carried',
        rules: ['Normal inventory storage never degrades a chest'],
        auth: { roles: ['maintainer'] },
      },
      repair: {
        description: 'Re-join a worn chest at a carpentry bench',
        rules: ['Requires a carpentry bench; no additional materials consumed'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── Door ─────────────────────────────────────────────────────────────────
  // Phase 208 — placed through the station path as station type `door` (ChestsAndDoors).
  Door: defineEntity({
    tags: ['item', 'station'],
    description:
      'A plank door on ferrite hinges with a lock. Placed as a door station; its owner sets who may pass: ' +
      'the owner, their clan or everyone.',
    goal: 'Close a house to everyone its owner does not let in (Phase 208)',
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      condition: { type: 'enum', values: DURABILITY_STATES },
      weight:    { type: 'decimal', description: 'kg per door', defaultValue: 10.0 },
      rarity:    { type: 'enum', values: RARITIES, defaultValue: 'common' },
      stackable: { type: 'boolean', description: 'False; one door per slot', defaultValue: false },
      shape: itemShape({ archetype: 'door', parts: { panel: 'Thornwood', hinge: 'Ferrite' } }),
      durability: { type: 'integer', description: 'Structural integrity', defaultValue: 300 },
    },
    relations: {
      plank:   { name: 'plank',   kind: 'hasOne', target: 'ThornwoodPlank' },
      ferrite: { name: 'ferrite', kind: 'hasOne', target: 'FerriteIngot' },
    },
    stateMachine: itemStateMachine(),
    behaviors: {
      degrade: {
        description: 'A door does not wear while carried',
        rules: ['Normal inventory storage never degrades a door'],
        auth: { roles: ['maintainer'] },
      },
      repair: {
        description: 'Re-join a worn door at a carpentry bench',
        rules: ['Requires a carpentry bench; no additional materials consumed'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),
}
