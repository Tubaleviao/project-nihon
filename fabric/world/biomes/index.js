const { safeMerge } = require('../../shared')
const temperate = require('./temperate')
const volcanic  = require('./volcanic')
const twilight  = require('./twilight')
const voidrift  = require('./voidrift')

module.exports = safeMerge('biome', temperate, volcanic, twilight, voidrift)
