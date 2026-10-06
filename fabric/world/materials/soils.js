const { defineEntity } = require('@newel/core')
const { depositFields } = require('./deposit')

// Phase 49 — natural ground cover. Neither is ever a ground vein (empty depth band): Grass is one
// of the covers a biome's `surfaceMaterial` can name, and Soil is what mining a slice of a biome's
// topsoil yields — the mapping is the biome's own `soilMaterial`, not a Grass-only rule.
module.exports = {

  Grass: defineEntity({
    tags: ['material'],
    description:
      'Living turf that covers temperate ground (forest and grassland). It is the top face of ' +
      'natural land, tinted per biome; what digging it yields is the biome\'s own `soilMaterial`, ' +
      'so a verbatim `Grass` cover is not what decides Soil.',
    goal: 'Make natural ground read as ground, and give the surface layer a name the biomes can point at',
    fields: {
      id:       { type: 'uuid', primaryKey: true },
      density:  { type: 'decimal', description: 'g/cm³; loose, root-bound', defaultValue: 1.1 },
      hardness: { type: 'decimal', description: 'Mohs equivalent 1–10', defaultValue: 0.5 },
      ...depositFields({ min: 0, max: 0, why: 'A surface cover, never a buried vein.' }),
    },
  }),

  Soil: defineEntity({
    tags: ['material'],
    description:
      'Loose earth under a biome\'s cover, down to its `topsoilDepth`. It is what mining a ' +
      'slice of natural topsoil yields, whatever cover (`surfaceMaterial`) it wears — Grass, ' +
      'Moss, Ash and Void ground alike — and what farmland is made of.',
    goal: 'Give digging the surface a yield that is not rock',
    fields: {
      id:       { type: 'uuid', primaryKey: true },
      density:  { type: 'decimal', description: 'g/cm³', defaultValue: 1.5 },
      hardness: { type: 'decimal', description: 'Mohs equivalent 1–10', defaultValue: 1 },
      ...depositFields({ min: 0, max: 0, why: 'A topsoil layer, never a buried vein.' }),
    },
  }),

  Sand: defineEntity({
    tags: ['material'],
    description: 'Loose grains that cover beaches, deserts and the sea floor. Digging it yields Soil. A surface cover named by a biome\'s `surfaceMaterial` (Phase 51).',
    goal: 'Let the new Earth-like biomes wear a cover that is not turf',
    fields: {
      id:       { type: 'uuid', primaryKey: true },
      density:  { type: 'decimal', description: 'g/cm³', defaultValue: 1.6 },
      hardness: { type: 'decimal', description: 'Mohs equivalent 1–10', defaultValue: 0.5 },
      ...depositFields({ min: 0, max: 0, why: 'A surface cover, never a buried vein.' }),
    },
  }),

  Snow: defineEntity({
    tags: ['material'],
    description: 'Packed snow that caps alpine peaks and the polar ground. Digging it yields Soil. A surface cover named by a biome\'s `surfaceMaterial` (Phase 51).',
    goal: 'Let the new Earth-like biomes wear a cover that is not turf',
    fields: {
      id:       { type: 'uuid', primaryKey: true },
      density:  { type: 'decimal', description: 'g/cm³', defaultValue: 0.3 },
      hardness: { type: 'decimal', description: 'Mohs equivalent 1–10', defaultValue: 0.5 },
      ...depositFields({ min: 0, max: 0, why: 'A surface cover, never a buried vein.' }),
    },
  }),

}
