const { safeMerge } = require('../../shared')
const metals = require('./metals')
const woods  = require('./woods')
const stones = require('./stones')
const soils  = require('./soils')
const built  = require('./built')

module.exports = safeMerge('material', metals, woods, stones, soils, built)
