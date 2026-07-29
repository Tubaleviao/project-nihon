const temperate = require('./temperate')
const volcanic  = require('./volcanic')
const twilight  = require('./twilight')
const void_     = require('./void')

function safeMerge(...sources) {
  return sources.reduce((acc, src) => {
    for (const key of Object.keys(src)) {
      if (Object.hasOwn(acc, key)) throw new Error(`Duplicate creature entity key: "${key}"`)
      acc[key] = src[key]
    }
    return acc
  }, {})
}

module.exports = safeMerge(temperate, volcanic, twilight, void_)
