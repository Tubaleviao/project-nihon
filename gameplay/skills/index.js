const combat      = require('./combat')
const crafting    = require('./crafting')
const magic       = require('./magic')
const exploration = require('./exploration')
const social      = require('./social')

function safeMerge(...sources) {
  return sources.reduce((acc, src) => {
    for (const key of Object.keys(src)) {
      if (Object.hasOwn(acc, key)) throw new Error(`Duplicate skill entity key: "${key}"`)
      acc[key] = src[key]
    }
    return acc
  }, {})
}

module.exports = safeMerge(combat, crafting, magic, exploration, social)
