const { defineEntity } = require('@newel/core')
const { depositFields } = require('./deposit')
const { structuralFields } = require('./structural')

// Phase 212 — the materials above stone. None is ever a ground vein (empty depth band): each is made, at a
// bench or a forge, and placed as its block item (ConcreteBlock, SteelBeam, LeyframePanel). With them every
// structural class has a material a player can make: concrete carries 10 floors, steel 40 and the composite
// the full 163. The composite is woven with aethermite, which forms only near a ley line (leyGated), so the
// tallest towers need the ley lines (validated by Structure's craftable-class check).
module.exports = {

  // ─── Concrete ─────────────────────────────────────────────────────────────
  Concrete: defineEntity({
    tags: ['material'],
    description:
      'Grey poured stone of ground ashite and soil, cast into blocks at a masonry bench. ' +
      'Heavy and plain; it carries ten floors where dressed stone carries five.',
    goal: 'The first material past stone: a ten-floor building from common ingredients',
    fields: {
      id:           { type: 'uuid', primaryKey: true },
      density:      { type: 'decimal', description: 'g/cm³', defaultValue: 2.4 },
      hardness:     { type: 'decimal', description: 'Mohs equivalent 1–10', defaultValue: 4.0 },
      conductivity: { type: 'decimal', description: 'Thermal conductivity rating 0–1', defaultValue: 0.3 },
      magicAffinity: { type: 'decimal', description: 'Capacity to hold enchantment 0–1', defaultValue: 0.02 },
      ...depositFields({ min: 0, max: 0, why: 'Cast at a bench from ashite and soil: no concrete lies in the ground.' }),
      ...structuralFields({ rarity: 'common', durability: 300, structuralClass: 'concrete', why: 'Cast stone: as tough as crude iron.' }),
    },
  }),

  // ─── Steel ────────────────────────────────────────────────────────────────
  Steel: defineEntity({
    tags: ['material'],
    description:
      'Ferrite refined twice over a master forge into rolled beams. ' +
      'The frame of every building taller than ten floors, up to forty.',
    goal: 'The frame metal: a forty-floor building from worked ferrite',
    fields: {
      id:           { type: 'uuid', primaryKey: true },
      density:      { type: 'decimal', description: 'g/cm³', defaultValue: 7.8 },
      hardness:     { type: 'decimal', description: 'Mohs equivalent 1–10', defaultValue: 6.0 },
      conductivity: { type: 'decimal', description: 'Thermal conductivity rating 0–1', defaultValue: 0.45 },
      magicAffinity: { type: 'decimal', description: 'Capacity to hold enchantment 0–1', defaultValue: 0.08 },
      ...depositFields({ min: 0, max: 0, why: 'Rolled from ferrite ingots at a master forge: no steel ore exists.' }),
      ...structuralFields({ rarity: 'uncommon', durability: 340, structuralClass: 'steel', why: 'Rolled beams: tougher than cast stone.' }),
    },
  }),

  // ─── Leyframe ─────────────────────────────────────────────────────────────
  Leyframe: defineEntity({
    tags: ['material'],
    description:
      'A composite of steel lattice bound with aethermite shards at an arcane forge, light and ' +
      'nearly unbending. The only material that carries a building to 163 floors; its aethermite ' +
      'forms only near ley lines.',
    goal: 'The top structural class: the tallest towers need steel, an arcane forge and the ley lines',
    fields: {
      id:           { type: 'uuid', primaryKey: true },
      density:      { type: 'decimal', description: 'g/cm³', defaultValue: 3.1 },
      hardness:     { type: 'decimal', description: 'Mohs equivalent 1–10', defaultValue: 7.5 },
      conductivity: { type: 'decimal', description: 'Thermal conductivity rating 0–1', defaultValue: 0.5 },
      magicAffinity: { type: 'decimal', description: 'Capacity to hold enchantment 0–1', defaultValue: 0.6 },
      ...depositFields({ min: 0, max: 0, why: 'Woven at an arcane forge: no leyframe lies in the ground.' }),
      ...structuralFields({ rarity: 'epic', durability: 1000, structuralClass: 'composite', why: 'A ley-bound lattice: stronger than any alloy.' }),
    },
  }),

}
