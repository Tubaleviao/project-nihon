const { defineEntity, RARITIES, DURABILITY_STATES, itemStateMachine, itemShape } = require('./shared')

// Phase 268 — a crafting station is an item too: crafted, carried in the pack and placed from the hotbar as its
// station type (StationPlacement in gameplay/stations.js). Picking a placed one up gives the item back.
function stationItem({ type, description, goal, weight, archetype, parts, relations }) {
  return defineEntity({
    tags: ['item', 'station'],
    description: `${description} Placed from the hotbar as a ${type} station; its owner can pick it up again.`,
    goal,
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      condition: { type: 'enum', values: DURABILITY_STATES },
      weight:    { type: 'decimal', description: `kg per ${type}`, defaultValue: weight },
      rarity:    { type: 'enum', values: RARITIES, defaultValue: 'common' },
      stackable: { type: 'boolean', description: `False; one ${type} per slot`, defaultValue: false },
      shape: itemShape({ archetype, parts }),
      durability: { type: 'integer', description: 'Structural integrity', defaultValue: 400 },
    },
    relations: Object.fromEntries(relations.map((m) => [m.toLowerCase(), { name: m.toLowerCase(), kind: 'hasOne', target: m }])),
    stateMachine: itemStateMachine(),
    behaviors: {
      degrade: {
        description: `A ${type} does not wear while carried`,
        rules: [`Normal inventory storage never degrades a ${type}`],
        auth: { roles: ['maintainer'] },
      },
      repair: {
        description: `Re-join a worn ${type} at a carpentry bench`,
        rules: ['Requires a carpentry bench; no additional materials consumed'],
        auth: { roles: ['maintainer'] },
      },
    },
  })
}

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

  // ─── Crafting stations (Phase 268) ─────────────────────────────────────────
  CarpentryBench: stationItem({
    type: 'carpentry bench', weight: 20.0, archetype: 'chest', parts: { box: 'Thornwood', band: 'Ashite' }, relations: ['Thornwood', 'Ashite'],
    description: 'A work top of lashed branches on stone feet, where logs become planks.',
    goal: 'The first station: made by hand from what the newcomer grounds give (Phase 268)',
  }),
  Forge: stationItem({
    type: 'forge', weight: 40.0, archetype: 'hearth', parts: { base: 'Ashite', fuel: 'Thornwood' }, relations: ['Ashite', 'Thornwood'],
    description: 'A stone hearth with a plank bellows, hot enough to smelt ferrite.',
    goal: 'The smithing station, built at a carpentry bench (Phase 268)',
  }),
  MasonryBench: stationItem({
    type: 'masonry bench', weight: 30.0, archetype: 'chest', parts: { box: 'Ashite', band: 'Thornwood' }, relations: ['Ashite', 'Thornwood'],
    description: 'A stone slab on a plank frame for cutting blocks and mixing cement.',
    goal: 'The masonry station, built at a carpentry bench (Phase 268)',
  }),
  AlchemyBench: stationItem({
    type: 'alchemy bench', weight: 18.0, archetype: 'chest', parts: { box: 'Thornwood', band: 'Aethermite' }, relations: ['Thornwood', 'Aethermite'],
    description: 'A plank table set with aethermite-lined bowls for brewing.',
    goal: 'The alchemy station, built at a carpentry bench (Phase 268)',
  }),
  MasterForge: stationItem({
    type: 'master forge', weight: 60.0, archetype: 'hearth', parts: { base: 'Ferrite', fuel: 'Ashite' }, relations: ['Ferrite', 'Ashite'],
    description: 'A ferrite-clad forge on cut stone that holds the heat veilsteel needs.',
    goal: 'The master smithing station, built at a forge (Phase 268)',
  }),
  ArcaneForge: stationItem({
    type: 'arcane forge', weight: 50.0, archetype: 'hearth', parts: { base: 'Ferrite', fuel: 'Aethermite' }, relations: ['Ferrite', 'Aethermite'],
    description: 'A ferrite forge fed with aethermite, for binding magic into metal.',
    goal: 'The arcane forging station, built at a forge (Phase 268)',
  }),
  VoidShieldedWorkshop: stationItem({
    type: 'void-shielded workshop', weight: 70.0, archetype: 'chest', parts: { box: 'Veilsteel', band: 'Voidite' }, relations: ['Veilsteel', 'Voidite'],
    description: 'A veilsteel cabinet lined with refined voidite, shielded for void work.',
    goal: 'The void smithing station, built at an arcane forge (Phase 268)',
  }),
}
