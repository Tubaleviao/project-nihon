const metals = require('./metals')
const woods  = require('./woods')
const stones = require('./stones')

module.exports = { ...metals, ...woods, ...stones }
