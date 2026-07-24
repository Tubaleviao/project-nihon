const temperate = require('./temperate')
const volcanic  = require('./volcanic')
const twilight  = require('./twilight')
const voidrift  = require('./voidrift')

module.exports = { ...temperate, ...volcanic, ...twilight, ...voidrift }
