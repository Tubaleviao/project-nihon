const temperate = require('./temperate')
const volcanic  = require('./volcanic')
const twilight  = require('./twilight')
const voidrift  = require('./voidrift')

function safeMerge(...sources) {
  return sources.reduce((acc, src) => {
    for (const key of Object.keys(src)) {
      if (key in acc) throw new Error(`Duplicate biome entity key: "${key}"`)
      acc[key] = src[key]
    }
    return acc
  }, {})
}

module.exports = safeMerge(temperate, volcanic, twilight, voidrift)
