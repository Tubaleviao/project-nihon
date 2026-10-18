const { safeMerge } = require('../../shared')
const combat      = require('./combat')
const crafting    = require('./crafting')
const magic       = require('./magic')
const exploration = require('./exploration')
const social      = require('./social')
const survival    = require('./survival')

module.exports = safeMerge('skill', combat, crafting, magic, exploration, social, survival)
