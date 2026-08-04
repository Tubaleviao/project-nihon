const { safeMerge } = require('../../shared')
const smithing  = require('./smithing')
const alchemy   = require('./alchemy')
const arcane    = require('./arcane')
const carpentry = require('./carpentry')

module.exports = safeMerge('recipe', smithing, alchemy, arcane, carpentry)
