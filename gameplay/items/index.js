const tools      = require('./tools')
const weapons    = require('./weapons')
const armor      = require('./armor')
const food       = require('./food')
const components = require('./components')
const magical    = require('./magical')

function safeMerge(...sources) {
  return sources.reduce((acc, src) => {
    for (const key of Object.keys(src)) {
      if (Object.hasOwn(acc, key)) throw new Error(`Duplicate item entity key: "${key}"`)
      acc[key] = src[key]
    }
    return acc
  }, {})
}

module.exports = safeMerge(tools, weapons, armor, food, components, magical)
