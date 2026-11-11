'use strict'
// Phase 238 — validator for WorldSystem.worldSeed, circumferenceKm and the continents list.

// Surface position in km on the flat chunk grid: x wraps at the circumference, z is latitude
// (90 degrees = a quarter of the circumference, pole to equator).
function toKm(c, circ) {
  return { x: (c.longitude / 360) * circ, z: (c.latitude / 90) * (circ / 4) }
}

// Distance in km between two continents' centres, wrapping X around the circumference.
function distanceKm(a, b, circ) {
  const pa = toKm(a, circ), pb = toKm(b, circ)
  let dx = Math.abs(pa.x - pb.x) % circ
  if (dx > circ / 2) dx = circ - dx
  return Math.hypot(dx, pa.z - pb.z)
}

function worldShapeProblems(w) {
  const out = []
  if (!w) return ['WorldSystem is missing']
  const bad = (k, why) => out.push(`WorldSystem.${k} ${why}`)
  if (!Number.isInteger(w.worldSeed)) bad('worldSeed', 'must be an integer')
  const circ = w.circumferenceKm
  if (!(typeof circ === 'number' && circ > 0)) bad('circumferenceKm', 'must be positive')
  const cs = w.continents
  if (!Array.isArray(cs)) { bad('continents', 'must be a list'); return out }
  const ids = new Set()
  cs.forEach((c, i) => {
    const at = `continents[${i}]`
    if (!c || typeof c !== 'object') return bad(at, 'must be an object')
    if (typeof c.id !== 'string' || !c.id) bad(at, 'needs an id')
    else if (ids.has(c.id)) bad(at, `repeats the id ${c.id}`)
    else ids.add(c.id)
    if (!(typeof c.latitude === 'number' && Math.abs(c.latitude) <= 90)) bad(at, 'latitude must be within ±90')
    if (!(typeof c.longitude === 'number' && c.longitude >= -180 && c.longitude <= 180)) bad(at, 'longitude must be within ±180')
    if (!(typeof c.radiusKm === 'number' && c.radiusKm > 0)) bad(at, 'radiusKm must be positive')
    if (typeof c.open !== 'boolean') bad(at, 'open must be true or false')
  })
  if (cs.length && !cs.some((c) => c && c.open === true)) bad('continents', 'needs at least one open continent')
  if (!cs.length) bad('continents', 'needs at least one open continent')
  if (typeof circ === 'number' && circ > 0) {
    for (let i = 0; i < cs.length; i++) for (let j = i + 1; j < cs.length; j++) {
      const a = cs[i], b = cs[j]
      if (![a, b].every((c) => c && typeof c.latitude === 'number' && typeof c.longitude === 'number' && typeof c.radiusKm === 'number')) continue
      if (distanceKm(a, b, circ) < a.radiusKm + b.radiusKm) bad('continents', `${a.id} and ${b.id} overlap`)
    }
  }
  return out
}

function validateWorldShape(w) {
  const problems = worldShapeProblems(w)
  if (problems.length) throw new Error(problems.join('\n'))
}

module.exports = { worldShapeProblems, validateWorldShape, distanceKm }
