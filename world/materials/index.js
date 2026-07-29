const metals = require('./metals')
const woods  = require('./woods')
const stones = require('./stones')

function safeMerge(...sources) {
  return sources.reduce((acc, src) => {
    for (const key of Object.keys(src)) {
      if (Object.hasOwn(acc, key)) throw new Error(`Duplicate material entity key: "${key}"`)
      acc[key] = src[key]
    }
    return acc
  }, {})
}

module.exports = safeMerge(metals, woods, stones)
