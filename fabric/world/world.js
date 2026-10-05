const { defineEntity } = require('@newel/core')

module.exports = {

  WorldSystem: defineEntity({
    tags: ['world-system'],
    description:
      'The planet as a fact of the fabric. The world takes globe semantics on a flat chunk grid: ' +
      'X wraps around the circumference, Z is latitude bounded by impassable polar ice, and players ' +
      'locate each other by latitude, longitude and altitude. Terrain is seed-deterministic, so only ' +
      'player edits are ever stored.',
    goal: 'Make one persistent, Earth-sized world whose size is a design fact rather than a code constant',
    fields: {
      id:              { type: 'uuid', primaryKey: true },
      circumferenceKm: { type: 'decimal', description: 'Length of the equator in km; X wraps after this distance (Phase 50)', defaultValue: 40000 },
      polarLatitude:   { type: 'decimal', description: 'Degrees of latitude at which impassable polar ice begins (north and south); the world spans pole to pole at 90 (Phase 50)', defaultValue: 85 },
      seaLevel:        { type: 'decimal', description: 'World Y in metres of the ocean surface (used by Phase 51)', defaultValue: 0 },
    },
  }),

}
