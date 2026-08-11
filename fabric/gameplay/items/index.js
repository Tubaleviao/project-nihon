const { safeMerge } = require('../../shared')
const tools      = require('./tools')
const weapons    = require('./weapons')
const armor      = require('./armor')
const food       = require('./food')
const components = require('./components')
const magical    = require('./magical')

module.exports = safeMerge('item', tools, weapons, armor, food, components, magical)
