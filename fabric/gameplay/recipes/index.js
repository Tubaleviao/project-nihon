const { safeMerge } = require('../../shared')
const smithing  = require('./smithing')
const alchemy   = require('./alchemy')
const arcane    = require('./arcane')
const carpentry = require('./carpentry')
const primitive = require('./primitive')
const stations  = require('./stations')

module.exports = safeMerge('recipe', smithing, alchemy, arcane, carpentry, primitive, stations)
