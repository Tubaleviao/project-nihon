const smithing  = require('./smithing')
const alchemy   = require('./alchemy')
const arcane    = require('./arcane')
const carpentry = require('./carpentry')

function safeMerge(...sources) {
  return sources.reduce((acc, src) => {
    for (const key of Object.keys(src)) {
      if (Object.hasOwn(acc, key)) throw new Error(`Duplicate recipe entity key: "${key}"`)
      acc[key] = src[key]
    }
    return acc
  }, {})
}

module.exports = safeMerge(smithing, alchemy, arcane, carpentry)
