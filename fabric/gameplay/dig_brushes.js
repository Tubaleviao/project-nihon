const { defineEntity } = require('@newel/core')
const work = require('./work')

// Phase 300 — tools decide the brush. A dig is one brush op (shape, radius, the materials it cuts) instead of one
// 0.5 m x 0.5 m x 0.125 m slab; the held item picks the brush, bare hands have the smallest. The host recomputes the
// brush from this table and the worker's Mining skill and ignores any shape or radius a client sends.
// Radius grows with skill by `skillRadiusPerTier` per Mining tier, never past `radiusCap`. A brush radius under
// `minRadius` is the old single slab. Yield is volume over `unitVolume` (one slab by default, so recipe and trade
// quantities keep their meaning), with optional per-material overrides.
const RADIUS_CAP = 1.5          // metres: the largest brush any tool and skill can reach
const SKILL_RADIUS_PER_TIER = 0.05
const BLEND = 0.25              // default smooth-blend k in metres
const MIN_RADIUS = 0.25         // below this a dig is the single slab (one tile)
// Mirrors VoxelConsts TILE_SIZE x TILE_SIZE x STEP_HEIGHT (src/terrain/voxel_consts.gd); fabric holds no such constants.
const UNIT_VOLUME = 0.5 * 0.5 * 0.125 // 0.03125 m3
const WORK_FACTOR = 0.1         // a brush costs this fraction of one slab's work time per slab-equivalent it removes
const SHAPES = ['sphere', 'cylinder', 'box']

/** Built (placed) materials: never part of a natural dig, so no brush cuts them. */
function builtMaterials() { return Object.keys(require('../world/materials/built')) }

/** Names of the natural materials (a future gravel material in the soil family would join the lists automatically) of the given families, from the material files so new ones join by themselves. */
function materialsOf(families) {
  const built = new Set(builtMaterials())
  return Object.keys(work.FAMILIES).filter((m) => families.includes(work.FAMILIES[m]) && !built.has(m))
}

/** Digging tool items: every item whose equipment category is a pick or a shovel. */
const DIG_CATEGORIES = ['pick', 'shovel']
function diggingItems() {
  const items = require('./items')
  const out = {}
  for (const [k, e] of Object.entries(items)) {
    const c = e && e.fields && e.fields.equipmentCategory && e.fields.equipmentCategory.defaultValue
    if (DIG_CATEGORIES.includes(c)) out[k] = c
  }
  return out
}

function brushesTable() {
  const soft = materialsOf(['soil'])
  const hard = materialsOf(['soil', 'stone', 'metal'])
  const byCategory = {
    shovel: { shape: 'sphere', radius: 0.75, cuts: soft },
    pick:   { shape: 'sphere', radius: 0.5,  cuts: hard },
  }
  const out = { hands: { shape: 'sphere', radius: 0.35, cuts: soft } }
  for (const [item, cat] of Object.entries(diggingItems())) out[item] = { ...byCategory[cat], cuts: [...byCategory[cat].cuts] }
  return out
}

function digBrushesData() {
  return JSON.parse(JSON.stringify({
    radiusCap: RADIUS_CAP, skillRadiusPerTier: SKILL_RADIUS_PER_TIER, blend: BLEND, minRadius: MIN_RADIUS, workFactor: WORK_FACTOR,
    brushes: brushesTable(), unitVolume: { default: UNIT_VOLUME, overrides: {} },
  }))
}

function digBrushesRefs() {
  const biomes = require('../world/biomes')
  const biomeSoil = [...new Set(Object.values(biomes)
    .map((e) => e && e.fields && e.fields.soilMaterial && e.fields.soilMaterial.defaultValue).filter(Boolean))]
  return {
    // Natural terrain materials only: what a natural column can yield. Built (Concrete, Steel, Leyframe) and wood
    // (trees, not ground) are never dug as terrain. Host rock per biome is chosen at runtime by OreField.host_material
    // (GDScript-only BIOME_BIAS, a transcription of the biome prose), so coverage is checked against every natural
    // stone and metal: any host rock or vein material is one of them.
    natural: materialsOf(['soil', 'stone', 'metal']),
    soft: materialsOf(['soil']),
    rock: materialsOf(['stone', 'metal']),
    biomeSoil,
    roles: { hands: 'hands', ...diggingItems() },
    diggingItems: Object.keys(diggingItems()),
  }
}

const BRUSH_KEYS = ['shape', 'radius', 'cuts']
const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v)

/** Problems with the dig-brush table, as strings. */
function digBrushesProblems(d, refs) {
  const p = []
  const pos = (v) => typeof v === 'number' && Number.isFinite(v) && v > 0
  if (!isObj(d)) return ['dig brushes must be an object']
  if (!pos(d.radiusCap)) p.push('radiusCap must be a number > 0')
  if (!pos(d.skillRadiusPerTier)) p.push('skillRadiusPerTier must be a number > 0')
  if (!(typeof d.blend === 'number' && Number.isFinite(d.blend) && d.blend >= 0)) p.push('blend must be a finite number >= 0')
  if (!pos(d.minRadius)) p.push('minRadius must be a number > 0')
  else if (pos(d.radiusCap) && d.minRadius >= d.radiusCap) p.push('minRadius must be under radiusCap')
  if (!pos(d.workFactor)) p.push('workFactor must be a number > 0')
  const brushes = isObj(d.brushes) ? d.brushes : {}
  if (!isObj(d.brushes)) p.push('brushes must be an object')
  if (!brushes.hands) p.push('brushes.hands is missing: bare hands dig too')
  for (const [name, b] of Object.entries(brushes)) {
    if (!isObj(b)) { p.push(`brushes.${name} must be an object`); continue }
    const role = name === 'hands' ? 'hands' : refs.roles[name]
    if (name !== 'hands' && !refs.diggingItems.includes(name)) p.push(`brushes.${name} is not a digging tool item`)
    for (const k of Object.keys(b)) if (!BRUSH_KEYS.includes(k)) p.push(`brushes.${name}.${k} is not a brush key`)
    if (!SHAPES.includes(b.shape)) p.push(`brushes.${name}.shape "${b.shape}" is not one of ${SHAPES.join(', ')}`)
    if (!pos(b.radius)) p.push(`brushes.${name}.radius must be > 0`)
    else if (b.radius > d.radiusCap) p.push(`brushes.${name}.radius ${b.radius} is over radiusCap ${d.radiusCap}`)
    else if (pos(d.minRadius) && b.radius < d.minRadius) p.push(`brushes.${name}.radius ${b.radius} is under minRadius ${d.minRadius}`)
    if (!Array.isArray(b.cuts) || !b.cuts.length) { p.push(`brushes.${name}.cuts must list at least one material`); continue }
    const allowed = role === 'pick' ? refs.natural : refs.soft
    const seen = new Set()
    for (const m of b.cuts) {
      if (seen.has(m)) p.push(`brushes.${name}.cuts lists "${m}" twice`)
      seen.add(m)
      if (!refs.natural.includes(m)) p.push(`brushes.${name}.cuts "${m}" is not a natural terrain material`)
      else if (!allowed.includes(m)) p.push(`brushes.${name}.cuts "${m}" is beyond a ${role} (${role === 'pick' ? 'soil, stone, metal' : 'soft ground only'})`)
    }
    // Coverage: everything a natural column can yield is dug by every tool of the right role.
    const need = role === 'pick' ? [...refs.biomeSoil, ...refs.rock] : refs.biomeSoil
    for (const m of need) if (!seen.has(m)) p.push(`brushes.${name}.cuts misses "${m}", which natural ground yields`)
  }
  for (const item of refs.diggingItems) if (!brushes[item]) p.push(`${item} is a digging tool with no brush`)
  const uv = isObj(d.unitVolume) ? d.unitVolume : {}
  if (!pos(uv.default)) p.push('unitVolume.default must be > 0')
  for (const [m, v] of Object.entries(uv.overrides || {})) {
    if (!refs.natural.includes(m)) p.push(`unitVolume.overrides.${m} is not a natural terrain material`)
    if (!pos(v)) p.push(`unitVolume.overrides.${m} must be > 0`)
  }
  return p
}

function validateDigBrushes(d, refs) {
  const problems = digBrushesProblems(d, refs)
  if (problems.length) throw new Error('Dig brushes are invalid:\n  ' + problems.join('\n  '))
}

const DigBrushes = defineEntity({
  tags: ['world-system'],
  description:
    'Which brush a dig makes: bare hands and each shovel or pick have a shape, a radius and the materials they cut; ' +
    'Mining skill grows the radius up to a cap; the rim is blended; yield is removed volume over a unit volume per material.',
  goal: 'A dig moves a shovelful, not a slab, and the tool decides what it can cut (Phase 300)',
  fields: {
    id:                 { type: 'uuid', primaryKey: true },
    radiusCap:          { type: 'decimal', description: 'Largest brush radius in metres, skill growth included', defaultValue: RADIUS_CAP },
    skillRadiusPerTier: { type: 'decimal', description: 'Metres of brush radius added per Mining skill tier', defaultValue: SKILL_RADIUS_PER_TIER },
    blend:              { type: 'decimal', description: 'Default smooth-blend k in metres for the rim of a dig', defaultValue: BLEND },
    minRadius:          { type: 'decimal', description: 'Under this radius a dig is the single slab (one tile)', defaultValue: MIN_RADIUS },
    workFactor:         { type: 'decimal', description: 'Work time of a brush dig: this fraction of a slab\'s time per slab-equivalent removed (Phase 259)', defaultValue: WORK_FACTOR },
    brushes:            { type: 'json', description: '{ hands | <tool item>: { shape: sphere|cylinder|box, radius, cuts: [material] } }', defaultValue: brushesTable() },
    unitVolume:         { type: 'json', description: '{ default: m3 per yielded unit, overrides: { <material>: m3 } }', defaultValue: { default: UNIT_VOLUME, overrides: {} } },
  },
})

module.exports = { RADIUS_CAP, SHAPES, digBrushesData, digBrushesRefs, digBrushesProblems, validateDigBrushes, DigBrushes }
