const { safeMerge } = require('../../shared')
const combat      = require('./combat')
const crafting    = require('./crafting')
const magic       = require('./magic')
const exploration = require('./exploration')
const social      = require('./social')

module.exports = safeMerge('skill', combat, crafting, magic, exploration, social)
