const { defineConfig } = require('@newel/core')
const { BibleGenerator } = require('@newel/generator-bible')

module.exports = defineConfig({
  schema: './fabric.js',
  output: '.',
  generators: [new BibleGenerator()],
})
