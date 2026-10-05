const { safeMerge } = require('../../shared')
const metals = require('./metals')
const woods  = require('./woods')
const stones = require('./stones')
const soils  = require('./soils')

module.exports = safeMerge('material', metals, woods, stones, soils)
