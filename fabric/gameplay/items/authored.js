// Phase 295 — the items as authored: no item declares a tool type. items/index.js adds the derived fields
// (the Phase 295 bridge); the equipment validator reads this map so it sees what was written, not what was derived.
const { safeMerge } = require('../../shared')
const tools      = require('./tools')
const weapons    = require('./weapons')
const armor      = require('./armor')
const food       = require('./food')
const components = require('./components')
const magical    = require('./magical')
const furniture  = require('./furniture')
const writings   = require('./writings')
const primitive  = require('./primitive')

module.exports = safeMerge('item', tools, weapons, armor, food, components, magical, furniture, writings, primitive)
