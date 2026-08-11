const { safeMerge } = require('../../shared')
const metals = require('./metals')
const woods  = require('./woods')
const stones = require('./stones')

module.exports = safeMerge('material', metals, woods, stones)
