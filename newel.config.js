const { defineConfig } = require('@newel/core')
const { BibleGenerator } = require('@newel/generator-bible')
const { GodotGenerator } = require('@newel/generator-godot')

module.exports = defineConfig({
  schema: './fabric.js',
  output: '.',
  generators: [new BibleGenerator(), new GodotGenerator()],
})
