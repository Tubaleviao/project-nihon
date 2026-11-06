'use strict'
// Phase 217 — validator for the WorldSystem hydrology fields (static lakes and rivers).
const { BIOME_KEYS } = require('./creatures/shared')

// Phase 217 — static lakes and rivers on unrecorded land. Validated by hydrologyProblems (npm run validate).
function hydrologyProblems(w) {
  const out = []
  if (!w) return ['WorldSystem is missing']
  const num = (k) => w[k]
  const bad = (k, why) => out.push(`WorldSystem.${k} ${why}`)
  const lf = num('lakeFrequency'), ld = num('lakeMinDepth'), rs = num('riverSourceHeight')
  const w0 = num('riverWidthMin'), w1 = num('riverWidthMax'), cm = num('riverCatchmentSteps')
  if (!(typeof lf === 'number' && lf >= 0 && lf <= 1)) bad('lakeFrequency', 'must be between 0 and 1')
  if (!(typeof ld === 'number' && ld >= 1)) bad('lakeMinDepth', 'must be at least 1 m')
  if (!(typeof rs === 'number' && rs > num('seaLevel'))) bad('riverSourceHeight', 'must be above seaLevel')
  if (!(typeof rs === 'number' && rs < num('maxHeight'))) bad('riverSourceHeight', 'must be below maxHeight')
  if (!(typeof w0 === 'number' && w0 >= 2)) bad('riverWidthMin', 'must be at least 2 m')
  if (!(typeof w1 === 'number' && w1 >= w0)) bad('riverWidthMax', 'must not be below riverWidthMin')
  if (!(Number.isInteger(cm) && cm >= 1)) bad('riverCatchmentSteps', 'must be a positive integer')
  const bl = num('riverBlockedBiomes')
  if (!Array.isArray(bl) || bl.some((b) => typeof b !== 'string' || !b)) bad('riverBlockedBiomes', 'must be a list of biome names')
  else if (bl.some((b) => !BIOME_KEYS.includes(b))) bad('riverBlockedBiomes', 'names an unknown biome')
  else if (new Set(bl).size !== bl.length) bad('riverBlockedBiomes', 'must not repeat a biome')
  return out
}

function validateHydrology(w) {
  const problems = hydrologyProblems(w)
  if (problems.length) throw new Error(problems.join('\n'))
}

// The shipped fabric's WorldSystem field defaults, as a plain object.
function shippedWorld() {
  const f = require('./world').WorldSystem.fields
  const out = {}
  for (const k of Object.keys(f)) out[k] = f[k].defaultValue
  return out
}

module.exports = { hydrologyProblems, validateHydrology, shippedWorld }
