// Phase 151 — item shapes. An item's shape is an archetype (a closed list) plus the fabric material
// each named part of that archetype is made of. Generators (Phases 152-153) build models and icons
// from it; the material palette (Phase 22) colours each part.

// archetype -> the named parts it has. A shape's `parts` keys must be a subset of these and must
// cover all of them.
const ARCHETYPES = {
  pick:       ['head', 'handle'],
  axe:        ['head', 'handle'],
  sword:      ['blade', 'grip'],
  longsword:  ['blade', 'grip'],
  bow:        ['limb', 'grip', 'tip'],
  shield:     ['face', 'rim'],
  helmet:     ['shell', 'trim'],
  chestplate: ['plate', 'under'],
  cloak:      ['body', 'trim'],
  ingot:      ['body'],
  shard:      ['body'],
  dust:       ['body'],
  plank:      ['body'],
  block:      ['body'],
  orb:        ['core', 'frame'],
  tablet:     ['slab', 'rune'],
  potion:     ['glass', 'liquid'],
  rations:    ['body', 'wrap'],
  hearth:     ['base', 'fuel'],
  waystone:   ['stone', 'glyph'],
}

// Materials an item's `hasOne` relations name but its shape deliberately does not draw (e.g. an
// axe's fibre lashing), keyed by the shape field. Kept off `defaultValue` so generated resources
// do not change; only the validator reads it.
const UNSHOWN = new WeakMap()

// Shape field for an item entity: `shape: itemShape({ archetype, parts, scale, unshown })`.
function itemShape({ archetype, parts, scale = 1, unshown = [] }) {
  const field = {
    type: 'json',
    description: 'Item shape: archetype, material per named part, and uniform scale (Phase 151)',
    defaultValue: { archetype, parts, scale },
  }
  UNSHOWN.set(field, unshown)
  return field
}

// Returns a list of problems for every entity tagged `item`. `materialNames` is the set of
// fabric material keys.
function shapeProblems(entities, materialNames) {
  const problems = []
  const mats = new Set(materialNames)
  for (const [name, ent] of Object.entries(entities)) {
    if (!(ent.tags || []).includes('item')) continue
    const field = ent.fields && ent.fields.shape
    const shape = field && field.defaultValue
    if (!shape) { problems.push(`${name}: item has no shape`); continue }
    const parts = ARCHETYPES[shape.archetype]
    if (!parts) { problems.push(`${name}: unknown archetype "${shape.archetype}"`); continue }
    if (!(typeof shape.scale === 'number' && shape.scale > 0)) problems.push(`${name}: scale must be a positive number`)
    const given = shape.parts || {}
    for (const part of Object.keys(given)) {
      if (!parts.includes(part)) problems.push(`${name}: part "${part}" is not in archetype "${shape.archetype}"`)
    }
    for (const part of parts) {
      const mat = given[part]
      if (mat === undefined) problems.push(`${name}: archetype "${shape.archetype}" part "${part}" has no material`)
      else if (!mats.has(mat)) problems.push(`${name}: parts.${part} names missing material "${mat}"`)
    }
    // A material the item is made of (a `hasOne` relation to a material) must be drawn by some
    // part or listed in `unshown`, so a changed relation cannot drift from the shape.
    const drawn = new Set(Object.values(given))
    const unshown = UNSHOWN.get(field) || []
    for (const rel of Object.values(ent.relations || {})) {
      if (rel.kind !== 'hasOne' || !mats.has(rel.target)) continue
      if (!drawn.has(rel.target) && !unshown.includes(rel.target)) {
        problems.push(`${name}: made of "${rel.target}" (hasOne ${rel.name}) but no part uses it; add it to a part or to unshown`)
      }
    }
    const related = new Set(Object.values(ent.relations || {}).filter(r => r.kind === 'hasOne').map(r => r.target))
    for (const mat of unshown) {
      if (drawn.has(mat)) problems.push(`${name}: unshown "${mat}" is drawn by a part`)
      if (!related.has(mat)) problems.push(`${name}: unshown "${mat}" is not a material this item is made of`)
    }
  }
  return problems
}

function validateShapes(entities, materialNames) {
  const problems = shapeProblems(entities, materialNames)
  if (problems.length) throw new Error('Item shape validation failed:\n  ' + problems.join('\n  '))
}

module.exports = { ARCHETYPES, itemShape, shapeProblems, validateShapes }
