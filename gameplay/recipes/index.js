const smithing  = require('./smithing')
const alchemy   = require('./alchemy')
const arcane    = require('./arcane')
const carpentry = require('./carpentry')

module.exports = {
  ...smithing,
  ...alchemy,
  ...arcane,
  ...carpentry,
}
