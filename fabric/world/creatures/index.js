const { safeMerge } = require('../../shared')
const temperate = require('./temperate')
const volcanic  = require('./volcanic')
const twilight  = require('./twilight')
const void_     = require('./void')

module.exports = safeMerge('creature', temperate, volcanic, twilight, void_)
