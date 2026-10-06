const { safeMerge } = require('../../shared')
const temperate = require('./temperate')
const volcanic  = require('./volcanic')
const twilight  = require('./twilight')
const voidrift  = require('./voidrift')
const earth     = require('./earth')

module.exports = safeMerge('biome', temperate, volcanic, twilight, voidrift, earth)
