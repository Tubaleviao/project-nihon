const { defineEntity } = require('@newel/core')

// Phase 300 — digging with a brush. A dig is one brush op { shape, centre, radius, op, k }: the held tool decides
// the shape, the radius and the materials it cuts; the host recomputes all three from this table and ignores
// anything a client sends. Yield is by volume: one unit of a material is `unitVolume[material]` m³, which
// defaults to one STEP_HEIGHT slab of one tile (0.5 m × 0.5 m × 0.125 m = 0.03125 m³) so today's recipe and trade
// quantities keep their meaning.

const SHAPES = ['sphere', 'cylinder', 'box']
const RADIUS_CAP = 1.5            // metres: no tool brush, at any skill level, is wider than this
const DEFAULT_UNIT_VOLUME = 0.03125 // m³, one slab
const SOFT = ['Grass', 'Soil', 'Sand', 'Snow']
const ROCK = ['Ashite', 'Lumenfite']
const ORE = ['Ferrite', 'Veilsteel', 'Aethermite', 'Voidite']

/** Held item ('' = bare hands) -> brush. `growth` is metres of radius per Mining skill level, up to `radiusMax`. */
const BRUSHES = {
  '':            { shape: 'sphere', radius: 0.3, radiusMax: 0.3, growth: 0,     materials: ['Grass', 'Soil', 'Sand'] },
  StoneShovel:   { shape: 'sphere', radius: 0.6, radiusMax: 1.0, growth: 0.004, materials: SOFT, speed: 1.2 },
  StonePick:     { shape: 'sphere', radius: 0.4, radiusMax: 0.6, growth: 0.002, materials: [...SOFT, ...ROCK, ...ORE], speed: 0.6 },
  FerritePick:   { shape: 'sphere', radius: 0.4, radiusMax: 0.7, growth: 0.002, materials: [...SOFT, ...ROCK, ...ORE], speed: 1.0 },
  VeilsteelPick: { shape: 'sphere', radius: 0.5, radiusMax: 0.8, growth: 0.002, materials: [...SOFT, ...ROCK, ...ORE], speed: 1.5 },
}

function digBrushData() {
  return JSON.parse(JSON.stringify({ shapes: SHAPES, radiusCap: RADIUS_CAP, defaultUnitVolume: DEFAULT_UNIT_VOLUME, unitVolume: {}, brushes: BRUSHES }))
}

/** The fabric's material and item keys, in the plain shape the validator reads. */
function digBrushRefs() {
  const materials = require('../world/materials')
  const items = require('./items')
  const mats = materials.MATERIALS || materials
  return { materials: Object.keys(mats).filter((k) => mats[k] && mats[k].fields), items: Object.keys(items) }
}

/** Problems with the dig-brush table against the fabric, as strings. */
function digBrushProblems(d, refs) {
  const p = []
  if (!(typeof d.radiusCap === 'number' && d.radiusCap > 0)) p.push('radiusCap must be a positive number')
  if (!(typeof d.defaultUnitVolume === 'number' && d.defaultUnitVolume > 0)) p.push('defaultUnitVolume must be positive')
  for (const [m, v] of Object.entries(d.unitVolume || {})) {
    if (!refs.materials.includes(m)) p.push(`unitVolume.${m}: not a terrain material`)
    if (!(typeof v === 'number' && v > 0)) p.push(`unitVolume.${m} must be positive`)
  }
  const entries = Object.entries(d.brushes || {})
  if (!entries.some(([k]) => k === '')) p.push('bare hands (key "") need a brush')
  for (const [tool, b] of entries) {
    const who = tool === '' ? 'bare hands' : tool
    if (tool !== '' && !refs.items.includes(tool)) p.push(`${who}: not an item`)
    if (!(d.shapes || []).includes(b.shape)) p.push(`${who}: shape ${b.shape} is not one of ${(d.shapes || []).join(', ')}`)
    if (!(typeof b.radius === 'number' && b.radius > 0)) p.push(`${who}: radius must be positive`)
    const max = typeof b.radiusMax === 'number' ? b.radiusMax : b.radius
    if (max < b.radius) p.push(`${who}: radiusMax ${max} is below radius ${b.radius}`)
    if (max > d.radiusCap) p.push(`${who}: radius ${max} is over the cap ${d.radiusCap}`)
    if (b.radius > d.radiusCap) p.push(`${who}: radius ${b.radius} is over the cap ${d.radiusCap}`)
    if (!(typeof b.growth === 'number' && b.growth >= 0)) p.push(`${who}: growth must be >= 0`)
    if (!Array.isArray(b.materials) || !b.materials.length) p.push(`${who}: materials must name at least one material`)
    for (const m of b.materials || []) if (!refs.materials.includes(m)) p.push(`${who}: ${m} is not a terrain material`)
  }
  return p
}

function validateDigBrush(d, refs) {
  const problems = digBrushProblems(d, refs)
  if (problems.length) throw new Error('Dig brushes are invalid:\n  ' + problems.join('\n  '))
}

const DigBrush = defineEntity({
  tags: ['world-system'],
  description:
    'What a dig removes (Phase 300): per held tool a brush shape, a radius that grows with the Mining skill up to a cap, and the materials it cuts, ' +
    'plus the volume of one yielded unit per material.',
  goal: 'A dig that moves a shovelful, not a slab, and yields the same however it is split',
  fields: {
    id:                { type: 'uuid', primaryKey: true },
    shapes:            { type: 'json', description: 'Brush shapes the rasteriser knows', defaultValue: SHAPES },
    radiusCap:         { type: 'decimal', description: 'Metres; no brush is wider, at any skill', defaultValue: RADIUS_CAP },
    defaultUnitVolume: { type: 'decimal', description: 'm³ of one yielded unit unless the material says otherwise', defaultValue: DEFAULT_UNIT_VOLUME },
    unitVolume:        { type: 'json', description: 'material -> m³ per yielded unit', defaultValue: {} },
    brushes:           { type: 'json', description: 'held item ("" = hands) -> { shape, radius, radiusMax, growth, materials }', defaultValue: BRUSHES },
  },
})

module.exports = { SHAPES, RADIUS_CAP, BRUSHES, digBrushData, digBrushRefs, digBrushProblems, validateDigBrush, DigBrush }
