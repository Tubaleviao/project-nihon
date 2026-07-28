const tools      = require('./tools')
const weapons    = require('./weapons')
const armor      = require('./armor')
const food       = require('./food')
const components = require('./components')
const magical    = require('./magical')

module.exports = {
  ...tools,
  ...weapons,
  ...armor,
  ...food,
  ...components,
  ...magical,
}
