// Phase 112 — self-test for the biome adjacency validation. Each scratch table below is broken in
// one way and `adjacencyProblems` must report it; the real table must pass.
// Usage: node tools/check_biome_adjacency.js
const { ADJACENCY, adjacencyProblems } = require('../fabric/world/biomes/adjacency')
const biomes = require('../fabric/world/biomes')

const keys = Object.keys(biomes)
const clone = () => JSON.parse(JSON.stringify(ADJACENCY))
let failed = 0
function expect(label, problems, needle) {
  const ok = needle === null ? problems.length === 0 : problems.some((p) => p.includes(needle))
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ': ' + JSON.stringify(problems)}`)
  if (!ok) failed++
}

expect('real table is valid', adjacencyProblems(ADJACENCY, keys), null)

let t = clone()
t.Tundra.forbiddenNeighbours.push('Atlantis')
expect('unknown key is rejected', adjacencyProblems(t, keys), 'unknown biome "Atlantis"')

t = clone()
t.Beach.forbiddenNeighbours.push('Alpine')
expect('asymmetric pair is rejected', adjacencyProblems(t, keys), 'asymmetric pair')

t = clone()
t.Tundra.transition = ''
expect('forbidden pair without a transition is rejected', adjacencyProblems(t, keys), 'no transition')

t = clone()
t.Tundra.transition = 'Desert'
expect('transition that is itself forbidden is rejected', adjacencyProblems(t, keys), 'forbidden')

process.exit(failed ? 1 : 0)
