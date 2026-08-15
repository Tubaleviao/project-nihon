const { defineConfig } = require('@newel/core')
const { BibleGenerator } = require('@newel/generator-bible')
const { GodotGenerator } = require('@newel/generator-godot')
const { WikiGenerator } = require('@newel/generator-wiki')

module.exports = defineConfig({
  schema: './fabric/index.js',
  output: '.',
  generators: [new BibleGenerator(), new GodotGenerator(), new WikiGenerator()],
})
