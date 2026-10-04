const { defineEntity } = require('@newel/core')
const { depositFields } = require('./deposit')

// Phase 49 — natural ground cover. Neither is ever a ground vein (empty depth band): Grass is the
// living top face of a biome's `surfaceMaterial`, Soil is what digging through it yields.
module.exports = {

  Grass: defineEntity({
    tags: ['material'],
    description:
      'Living turf that covers most temperate and twilight ground. It is the top face of ' +
      'natural land, tinted per biome; digging it turns it into Soil.',
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
      'Loose earth under the turf, down to the biome\'s topsoil depth. It is what mining ' +
      'natural grass-covered ground yields, and what farmland is made of.',
    goal: 'Give digging the surface a yield that is not rock',
    fields: {
      id:       { type: 'uuid', primaryKey: true },
      density:  { type: 'decimal', description: 'g/cm³', defaultValue: 1.5 },
      hardness: { type: 'decimal', description: 'Mohs equivalent 1–10', defaultValue: 1 },
      ...depositFields({ min: 0, max: 0, why: 'A topsoil layer, never a buried vein.' }),
    },
  }),

}
